unit JS4D.PromiseCombinators;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ArrayStatics,
  JS4D.BuiltinSupport,
  JS4D.AggregateErrorBuiltins,
  JS4D.Combination,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations;

type
  TJSCombinatorKind = (All, AllSettled, Any, Race);

  TJSElementHandlers = record
    OnFulfilled: TJSValue;
    OnRejected: TJSValue;
  end;

  TJSEntryBuilder = reference to function(const Value: TJSValue): TJSValue;

  TJSPromiseCombinators = class
  private
    const
      STATUS_PROPERTY = 'status';
      REASON_PROPERTY = 'reason';
      FULFILLED_STATUS = 'fulfilled';
      REJECTED_STATUS = 'rejected';
      NOT_CALLABLE = 'The resolve property of the promise constructor is not a function';
      NOT_ITERABLE = 'The value is not iterable';
      NOT_AN_OBJECT = 'Promise combinator called on a value that is not an object';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FOperations: TJSPromiseOperations;
      FAggregateErrors: TJSAggregateErrorBuiltins;

    class function KeepValue(const Value: TJSValue): TJSValue; static;

    function CreateSettledEntry(const Status: string; const ValueProperty: string; const Value: TJSValue): TJSValue;
    function CreateFulfilledEntry(const Value: TJSValue): TJSValue;
    function CreateRejectedEntry(const Value: TJSValue): TJSValue;
    function GetPromiseResolve(const ConstructorValue: TJSValue): IJSFunction;
    procedure Perform(const Kind: TJSCombinatorKind; const ConstructorValue: TJSValue;
                      const Capability: TJSPromiseCapability; const PromiseResolve: IJSFunction;
                      const Iterable: TJSValue);
    procedure SubscribeEach(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                            const Reader: TJSSequenceReader; const ConstructorValue: TJSValue;
                            const PromiseResolve: IJSFunction; const Capability: TJSPromiseCapability);
    procedure Subscribe(const Kind: TJSCombinatorKind; const Combination: IJSCombination; const Index: Integer;
                        const NextPromise: TJSValue; const Capability: TJSPromiseCapability);
    function CreateHandlers(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                            const Index: Integer; const Capability: TJSPromiseCapability): TJSElementHandlers;
    function CreateElement(const Kind: TJSCombinatorKind; const Combination: IJSCombination; const Index: Integer;
                           const Capability: TJSPromiseCapability;
                           const BuildEntry: TJSEntryBuilder): IJSFunction;
    procedure Finish(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                     const Capability: TJSPromiseCapability);
    procedure RejectWithAggregate(const Combination: IJSCombination; const Capability: TJSPromiseCapability);
    procedure ResolveWithSlots(const Combination: IJSCombination; const Capability: TJSPromiseCapability);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport;
                       const Operations: TJSPromiseOperations; const AggregateErrors: TJSAggregateErrorBuiltins);

    function Combine(const Kind: TJSCombinatorKind; const This: IJSObject;
                     const Args: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.PropertyKey,
  JS4D.Errors,
  JS4D.PropertyNames;

constructor TJSPromiseCombinators.Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport;
                                         const Operations: TJSPromiseOperations;
                                         const AggregateErrors: TJSAggregateErrorBuiltins);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
  FOperations := Operations;
  FAggregateErrors := AggregateErrors;
end;

class function TJSPromiseCombinators.KeepValue(const Value: TJSValue): TJSValue;
begin
  Result := Value;
end;

function TJSPromiseCombinators.CreateSettledEntry(const Status: string; const ValueProperty: string;
                                                  const Value: TJSValue): TJSValue;
begin
  const Entry = TJSObject.Create;
  Entry.Prototype := FInterpreter.ObjectPrototype;

  const StatusValue = TJSValue.CreateString(Status);
  Entry.SetProperty(STATUS_PROPERTY, StatusValue);
  Entry.SetProperty(ValueProperty, Value);

  Result := TJSValue.CreateObject(Entry);
end;

function TJSPromiseCombinators.CreateFulfilledEntry(const Value: TJSValue): TJSValue;
begin
  Result := CreateSettledEntry(FULFILLED_STATUS, VALUE_PROPERTY, Value);
end;

function TJSPromiseCombinators.CreateRejectedEntry(const Value: TJSValue): TJSValue;
begin
  Result := CreateSettledEntry(REJECTED_STATUS, REASON_PROPERTY, Value);
end;

function TJSPromiseCombinators.GetPromiseResolve(const ConstructorValue: TJSValue): IJSFunction;
begin
  const ConstructorObject = ConstructorValue.ToObject;
  const Candidate = ConstructorObject.GetProperty(RESOLVE_PROPERTY);

  const IsCallable = Candidate.TryGetFunction(Result);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);
end;

function TJSPromiseCombinators.Combine(const Kind: TJSCombinatorKind; const This: IJSObject;
                                       const Args: TArray<TJSValue>): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(NOT_AN_OBJECT);

  const ConstructorValue = TJSValue.CreateObject(This);
  const Capability = FOperations.NewCapabilityWithFunctions(ConstructorValue);
  const Iterable = TJSArrayLike.Argument(Args, 0);

  const Outcome = FSupport.Capture(
    function: TJSValue
    begin
      const PromiseResolve = GetPromiseResolve(ConstructorValue);
      Perform(Kind, ConstructorValue, Capability, PromiseResolve, Iterable);
      Result := TJSValue.CreateUndefined;
    end);

  if not Outcome.IsNormal then
    FOperations.RejectCapability(Capability, Outcome.Value);

  Result := Capability.Promise;
end;

procedure TJSPromiseCombinators.Perform(const Kind: TJSCombinatorKind; const ConstructorValue: TJSValue;
                                        const Capability: TJSPromiseCapability;
                                        const PromiseResolve: IJSFunction; const Iterable: TJSValue);
begin
  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  const IsIterable = FInterpreter.TryOpenSequenceReader(Iterable, Reader, Closer);
  if not IsIterable then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  const Combination: IJSCombination = TJSCombination.Create;
  try
    SubscribeEach(Kind, Combination, Reader, ConstructorValue, PromiseResolve, Capability);
  except
    on EJSExecutionInterrupted do
      raise;
    on Exception do
    begin
      Closer(True);
      raise;
    end;
  end;

  Finish(Kind, Combination, Capability);
end;

procedure TJSPromiseCombinators.SubscribeEach(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                              const Reader: TJSSequenceReader; const ConstructorValue: TJSValue;
                                              const PromiseResolve: IJSFunction;
                                              const Capability: TJSPromiseCapability);
begin
  const Receiver = ConstructorValue.ToObject;
  var Index := 0;
  var Item: TJSValue;

  while Reader(Item) do
  begin
    Combination.AddSlot;

    const ResolveArgs: TArray<TJSValue> = [Item];
    const NextPromise = FInterpreter.CallFunction(PromiseResolve, ResolveArgs, Receiver);
    Subscribe(Kind, Combination, Index, NextPromise, Capability);
    Inc(Index);
  end;
end;

procedure TJSPromiseCombinators.Subscribe(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                          const Index: Integer; const NextPromise: TJSValue;
                                          const Capability: TJSPromiseCapability);
begin
  const Handlers = CreateHandlers(Kind, Combination, Index, Capability);

  const IsCounting = (Kind <> TJSCombinatorKind.Race);
  if IsCounting then
    Combination.AddPending;

  const ThenArgs: TArray<TJSValue> = [Handlers.OnFulfilled, Handlers.OnRejected];
  FSupport.Invoke(NextPromise, THEN_PROPERTY, ThenArgs);
end;

function TJSPromiseCombinators.CreateHandlers(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                              const Index: Integer;
                                              const Capability: TJSPromiseCapability): TJSElementHandlers;
begin
  Result.OnFulfilled := Capability.Resolve;
  Result.OnRejected := Capability.Reject;

  case Kind of
    TJSCombinatorKind.All:
      begin
        const OnFulfilled = CreateElement(Kind, Combination, Index, Capability, KeepValue);
        Result.OnFulfilled := TJSValue.CreateObject(OnFulfilled);
      end;
    TJSCombinatorKind.AllSettled:
      begin
        const OnFulfilled = CreateElement(Kind, Combination, Index, Capability, CreateFulfilledEntry);
        const OnRejected = CreateElement(Kind, Combination, Index, Capability, CreateRejectedEntry);
        Result.OnFulfilled := TJSValue.CreateObject(OnFulfilled);
        Result.OnRejected := TJSValue.CreateObject(OnRejected);
      end;
    TJSCombinatorKind.Any:
      begin
        const OnRejected = CreateElement(Kind, Combination, Index, Capability, KeepValue);
        Result.OnRejected := TJSValue.CreateObject(OnRejected);
      end;
    TJSCombinatorKind.Race:
      Exit;
  else
    raise ENotSupportedException.CreateFmt('Unsupported promise combinator: %d', [Ord(Kind)]);
  end;
end;

function TJSPromiseCombinators.CreateElement(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                             const Index: Integer; const Capability: TJSPromiseCapability;
                                             const BuildEntry: TJSEntryBuilder): IJSFunction;
begin
  Result := FSupport.CreateMethod('', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;

      const IsFirstCall = Combination.TryClaimSlot(Index);
      if not IsFirstCall then
        Exit;

      const Argument = TJSArrayLike.Argument(Args, 0);
      const Entry = BuildEntry(Argument);
      Combination.FillSlot(Index, Entry);
      Finish(Kind, Combination, Capability);
    end);
end;

procedure TJSPromiseCombinators.Finish(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                       const Capability: TJSPromiseCapability);
begin
  const IsRace = (Kind = TJSCombinatorKind.Race);
  if IsRace then
    Exit;

  Combination.RemovePending;
  if not Combination.IsComplete then
    Exit;

  const IsAny = (Kind = TJSCombinatorKind.Any);
  if IsAny then
    RejectWithAggregate(Combination, Capability)
  else
    ResolveWithSlots(Combination, Capability);
end;

procedure TJSPromiseCombinators.RejectWithAggregate(const Combination: IJSCombination;
                                                    const Capability: TJSPromiseCapability);
begin
  const Errors = Combination.GetSlots;
  const AggregateError = FAggregateErrors.CreateFromList(Errors);

  FOperations.RejectCapability(Capability, AggregateError);
end;

procedure TJSPromiseCombinators.ResolveWithSlots(const Combination: IJSCombination;
                                                 const Capability: TJSPromiseCapability);
begin
  const Slots = Combination.GetSlots;
  const Values = FSupport.CreateArray(Slots);

  FOperations.ResolveCapability(Capability, Values);
end;

end.
