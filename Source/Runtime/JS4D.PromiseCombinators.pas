unit JS4D.PromiseCombinators;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ArrayStatics,
  JS4D.BinarySupport,
  JS4D.AggregateErrorBuiltins,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations;

type
  TJSCombinatorKind = (All, AllSettled, Any, Race);

  // The bookkeeping that the element functions of one call to all, allSettled or any share.
  IJSCombination = interface
    ['{4D7A2E91-C5B8-4F30-A619-E03B8D5C7F24}']
    function GetValues: TList<TJSValue>;
    function GetRemaining: Integer;
    procedure SetRemaining(const Value: Integer);
    property Values: TList<TJSValue> read GetValues;
    property Remaining: Integer read GetRemaining write SetRemaining;
  end;

  TJSCombination = class(TInterfacedObject, IJSCombination)
  private
    FValues: TList<TJSValue>;
    FRemaining: Integer;

    function GetValues: TList<TJSValue>;
    function GetRemaining: Integer;
    procedure SetRemaining(const Value: Integer);

  public
    constructor Create;
    destructor Destroy; override;
  end;

  // Promise.all, Promise.allSettled, Promise.any and Promise.race.
  TJSPromiseCombinators = class
  private
    const
      RESOLVE_PROPERTY = 'resolve';
      THEN_PROPERTY = 'then';
      STATUS_PROPERTY = 'status';
      VALUE_PROPERTY = 'value';
      REASON_PROPERTY = 'reason';
      FULFILLED_STATUS = 'fulfilled';
      REJECTED_STATUS = 'rejected';
      NOT_CALLABLE = 'The resolve property of the promise constructor is not a function';
      NOT_ITERABLE = 'The value is not iterable';
      NOT_AN_OBJECT = 'Promise combinator called on a value that is not an object';

    var
      FInterpreter: TJSInterpreter;
      FOperations: TJSPromiseOperations;
      FAggregateErrors: TJSAggregateErrorBuiltins;

    function CreateArray(const Items: TList<TJSValue>): TJSValue;
    function CreateSettledEntry(const IsFulfilled: Boolean; const Value: TJSValue): TJSValue;
    function FindPromiseResolve(const Constructor_: TJSValue): IJSFunction;
    procedure Perform(const Kind: TJSCombinatorKind; const Constructor_: TJSValue;
                      const Capability: TJSPromiseCapability; const PromiseResolve: IJSFunction;
                      const Iterable: TJSValue);
    procedure Subscribe(const Kind: TJSCombinatorKind; const Combination: IJSCombination; const Index: Integer;
                        const NextPromise: TJSValue; const Capability: TJSPromiseCapability);
    procedure Finish(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                     const Capability: TJSPromiseCapability);
    function CreateAllElement(const Combination: IJSCombination; const Index: Integer;
                              const Capability: TJSPromiseCapability): IJSFunction;
    function CreateAnyElement(const Combination: IJSCombination; const Index: Integer;
                              const Capability: TJSPromiseCapability): IJSFunction;
    procedure CreateSettledElements(const Combination: IJSCombination; const Index: Integer;
                                    const Capability: TJSPromiseCapability; out OnFulfilled: IJSFunction;
                                    out OnRejected: IJSFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations;
                       const AggregateErrors: TJSAggregateErrorBuiltins);

    function Combine(const Kind: TJSCombinatorKind; const This: IJSObject;
                     const Args: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.Errors;

{ TJSCombination }

constructor TJSCombination.Create;
begin
  inherited Create;

  FValues := TList<TJSValue>.Create;
  FRemaining := 1;
end;

destructor TJSCombination.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TJSCombination.GetValues: TList<TJSValue>;
begin
  Result := FValues;
end;

function TJSCombination.GetRemaining: Integer;
begin
  Result := FRemaining;
end;

procedure TJSCombination.SetRemaining(const Value: Integer);
begin
  FRemaining := Value;
end;

{ TJSPromiseCombinators }

constructor TJSPromiseCombinators.Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations;
                                         const AggregateErrors: TJSAggregateErrorBuiltins);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FOperations := Operations;
  FAggregateErrors := AggregateErrors;
end;

function TJSPromiseCombinators.CreateArray(const Items: TList<TJSValue>): TJSValue;
begin
  const List = TJSArray.Create;
  List.Prototype := FInterpreter.ArrayPrototype;
  for var Item in Items do
  begin
    List.Push(Item);
  end;

  Result := TJSValue.CreateObject(List);
end;

function TJSPromiseCombinators.CreateSettledEntry(const IsFulfilled: Boolean; const Value: TJSValue): TJSValue;
begin
  const Entry = TJSObject.Create;
  Entry.Prototype := FInterpreter.ObjectPrototype;

  if IsFulfilled then
  begin
    Entry.SetProperty(STATUS_PROPERTY, TJSValue.CreateString(FULFILLED_STATUS));
    Entry.SetProperty(VALUE_PROPERTY, Value);
  end
  else
  begin
    Entry.SetProperty(STATUS_PROPERTY, TJSValue.CreateString(REJECTED_STATUS));
    Entry.SetProperty(REASON_PROPERTY, Value);
  end;

  Result := TJSValue.CreateObject(Entry);
end;

function TJSPromiseCombinators.FindPromiseResolve(const Constructor_: TJSValue): IJSFunction;
begin
  const Candidate = Constructor_.ToObject.GetProperty(RESOLVE_PROPERTY);
  if not TJSBinarySupport.AsFunction(Candidate, Result) then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);
end;

function TJSPromiseCombinators.Combine(const Kind: TJSCombinatorKind; const This: IJSObject;
                                       const Args: TArray<TJSValue>): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(NOT_AN_OBJECT);

  const Constructor_ = TJSValue.CreateObject(This);
  const Capability = FOperations.NewCapability(Constructor_, True);

  try
    const PromiseResolve = FindPromiseResolve(Constructor_);
    Perform(Kind, Constructor_, Capability, PromiseResolve, TJSBinarySupport.Argument(Args, 0));
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      const Reason = FInterpreter.ExceptionToValue(Error);
      FOperations.RejectCapability(Capability, Reason);
    end;
  end;

  Result := Capability.Promise;
end;

procedure TJSPromiseCombinators.Perform(const Kind: TJSCombinatorKind; const Constructor_: TJSValue;
                                        const Capability: TJSPromiseCapability;
                                        const PromiseResolve: IJSFunction; const Iterable: TJSValue);
begin
  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if not FInterpreter.OpenSequenceReader(Iterable, Reader, Closer) then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  const Combination: IJSCombination = TJSCombination.Create;
  var Index := 0;
  var Item: TJSValue;
  try
    while Reader(Item) do
    begin
      Combination.Values.Add(TJSValue.CreateUndefined);

      const NextPromise = FInterpreter.CallFunction(PromiseResolve, [Item], Constructor_.ToObject);
      Subscribe(Kind, Combination, Index, NextPromise, Capability);
      Inc(Index);
    end;
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

procedure TJSPromiseCombinators.Subscribe(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                          const Index: Integer; const NextPromise: TJSValue;
                                          const Capability: TJSPromiseCapability);
begin
  var OnFulfilled: IJSFunction := nil;
  var OnRejected: IJSFunction := nil;
  var OnFulfilledValue := Capability.Resolve;
  var OnRejectedValue := Capability.Reject;

  case Kind of
    TJSCombinatorKind.All:
      begin
        OnFulfilled := CreateAllElement(Combination, Index, Capability);
        OnFulfilledValue := TJSValue.CreateObject(OnFulfilled);
      end;

    TJSCombinatorKind.AllSettled:
      begin
        CreateSettledElements(Combination, Index, Capability, OnFulfilled, OnRejected);
        OnFulfilledValue := TJSValue.CreateObject(OnFulfilled);
        OnRejectedValue := TJSValue.CreateObject(OnRejected);
      end;

    TJSCombinatorKind.Any:
      begin
        OnRejected := CreateAnyElement(Combination, Index, Capability);
        OnRejectedValue := TJSValue.CreateObject(OnRejected);
      end;

    TJSCombinatorKind.Race:
      ;
  else
    raise ENotSupportedException.CreateFmt('Unsupported promise combinator: %d', [Ord(Kind)]);
  end;

  const IsCounting = Kind <> TJSCombinatorKind.Race;
  if IsCounting then
    Combination.Remaining := Combination.Remaining + 1;

  FOperations.Invoke(NextPromise, THEN_PROPERTY, [OnFulfilledValue, OnRejectedValue]);
end;

procedure TJSPromiseCombinators.Finish(const Kind: TJSCombinatorKind; const Combination: IJSCombination;
                                       const Capability: TJSPromiseCapability);
begin
  if Kind = TJSCombinatorKind.Race then
    Exit;

  Combination.Remaining := Combination.Remaining - 1;
  const IsComplete = (Combination.Remaining = 0);
  if not IsComplete then
    Exit;

  if Kind = TJSCombinatorKind.Any then
  begin
    const Errors = Combination.Values.ToArray;
    const AggregateError = FAggregateErrors.CreateFromList(Errors);
    FOperations.RejectCapability(Capability, AggregateError);
  end
  else
  begin
    const Values = CreateArray(Combination.Values);
    FOperations.ResolveCapability(Capability, Values);
  end;
end;

function TJSPromiseCombinators.CreateAllElement(const Combination: IJSCombination; const Index: Integer;
                                                const Capability: TJSPromiseCapability): IJSFunction;
begin
  var IsCalled := False;

  Result := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsCalled then
        Exit;

      IsCalled := True;
      Combination.Values[Index] := TJSBinarySupport.Argument(Args, 0);
      Finish(TJSCombinatorKind.All, Combination, Capability);
    end);
end;

function TJSPromiseCombinators.CreateAnyElement(const Combination: IJSCombination; const Index: Integer;
                                                const Capability: TJSPromiseCapability): IJSFunction;
begin
  var IsCalled := False;

  Result := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsCalled then
        Exit;

      IsCalled := True;
      Combination.Values[Index] := TJSBinarySupport.Argument(Args, 0);
      Finish(TJSCombinatorKind.Any, Combination, Capability);
    end);
end;

procedure TJSPromiseCombinators.CreateSettledElements(const Combination: IJSCombination; const Index: Integer;
                                                      const Capability: TJSPromiseCapability;
                                                      out OnFulfilled: IJSFunction; out OnRejected: IJSFunction);
begin
  var IsCalled := False;

  OnFulfilled := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsCalled then
        Exit;

      IsCalled := True;
      Combination.Values[Index] := CreateSettledEntry(True, TJSBinarySupport.Argument(Args, 0));
      Finish(TJSCombinatorKind.AllSettled, Combination, Capability);
    end);

  OnRejected := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsCalled then
        Exit;

      IsCalled := True;
      Combination.Values[Index] := CreateSettledEntry(False, TJSBinarySupport.Argument(Args, 0));
      Finish(TJSCombinatorKind.AllSettled, Combination, Capability);
    end);
end;

end.
