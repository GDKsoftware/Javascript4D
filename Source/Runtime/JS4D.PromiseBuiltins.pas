unit JS4D.PromiseBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BinarySupport,
  JS4D.AggregateErrorBuiltins,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations,
  JS4D.PromiseCombinators;

type
  // Promise, its prototype methods, its static methods and the job queue that runs the reactions.
  TJSPromiseBuiltins = class
  private
    const
      PROMISE_NAME = 'Promise';
      THEN_NAME = 'then';
      CATCH_NAME = 'catch';
      FINALLY_NAME = 'finally';
      RESOLVE_NAME = 'resolve';
      REJECT_NAME = 'reject';
      ALL_NAME = 'all';
      ALL_SETTLED_NAME = 'allSettled';
      ANY_NAME = 'any';
      RACE_NAME = 'race';
      WITH_RESOLVERS_NAME = 'withResolvers';
      TRY_NAME = 'try';
      PROMISE_PROPERTY = 'promise';
      REQUIRES_NEW = 'Promise constructor cannot be invoked without ''new''';
      RESOLVER_NOT_CALLABLE = 'Promise resolver is not a function';
      INCOMPATIBLE_RECEIVER = 'Method Promise.prototype.%s called on an incompatible receiver';
      NOT_AN_OBJECT = 'Promise.%s called on a value that is not an object';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBinarySupport;
      FAggregateErrors: TJSAggregateErrorBuiltins;
      FOperations: TJSPromiseOperations;
      FCombinators: TJSPromiseCombinators;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
    function RequirePromise(const This: IJSObject; const MethodName: string): IJSPromise;
    function RequireObject(const This: IJSObject; const MethodName: string): TJSValue;
    function Then_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Catch_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Finally_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateThenFinally(const OnFinally: IJSFunction; const Constructor_: TJSValue): IJSFunction;
    function CreateCatchFinally(const OnFinally: IJSFunction; const Constructor_: TJSValue): IJSFunction;
    function Resolve_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Reject_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function WithResolvers(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Try_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    class function CallbackArguments(const Args: TArray<TJSValue>): TArray<TJSValue>; static;
    procedure DefineCombinator(const Name: string; const Kind: TJSCombinatorKind);
    procedure DefinePrototypeMembers;
    procedure DefineStaticMembers;

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
    procedure ReleasePromises;
  end;

implementation

uses
  JS4D.Errors;

constructor TJSPromiseBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBinarySupport.Create(Interpreter);
  FAggregateErrors := TJSAggregateErrorBuiltins.Create(Interpreter, FSupport);
  FOperations := TJSPromiseOperations.Create(Interpreter, FSupport);
  FCombinators := TJSPromiseCombinators.Create(Interpreter, FOperations, FAggregateErrors);
end;

destructor TJSPromiseBuiltins.Destroy;
begin
  FCombinators.Free;
  FAggregateErrors.Free;
  FOperations.Free;
  FSupport.Free;
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

procedure TJSPromiseBuiltins.ReleasePromises;
begin
  FOperations.ReleasePromises;
end;

function TJSPromiseBuiltins.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  var Executor: IJSFunction;
  if not TJSBinarySupport.AsFunction(TJSBinarySupport.Argument(Args, 0), Executor) then
    raise TJSErrorFactory.TypeError(RESOLVER_NOT_CALLABLE);

  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);
  const Promise = FOperations.CreatePromise(Prototype);

  var Resolve: IJSFunction;
  var Reject: IJSFunction;
  FOperations.CreateResolvingFunctions(Promise, Resolve, Reject);

  var Outcome: TJSValue;
  const ExecutorArgs: TArray<TJSValue> = [TJSValue.CreateObject(Resolve), TJSValue.CreateObject(Reject)];
  const IsNormal = FOperations.TryCall(Executor, ExecutorArgs, nil, Outcome);
  if not IsNormal then
    FInterpreter.CallFunction(Reject, [Outcome], nil);

  Result := TJSValue.CreateObject(Promise);
end;

function TJSPromiseBuiltins.RequirePromise(const This: IJSObject; const MethodName: string): IJSPromise;
begin
  const IsPromise = Assigned(This) and Supports(This, IJSPromise, Result);
  if not IsPromise then
    raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_RECEIVER, [MethodName]));
end;

function TJSPromiseBuiltins.RequireObject(const This: IJSObject; const MethodName: string): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(NOT_AN_OBJECT, [MethodName]));

  Result := TJSValue.CreateObject(This);
end;

function TJSPromiseBuiltins.Then_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Promise = RequirePromise(This, THEN_NAME);
  const Constructor_ = FSupport.SpeciesConstructor(This, FConstructor);
  const Capability = FOperations.NewCapability(TJSValue.CreateObject(Constructor_), False);

  FOperations.PerformThen(Promise, TJSBinarySupport.Argument(Args, 0), TJSBinarySupport.Argument(Args, 1),
                          Capability, True);

  Result := Capability.Promise;
end;

function TJSPromiseBuiltins.Catch_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Receiver = RequireObject(This, CATCH_NAME);
  const ThenArgs: TArray<TJSValue> = [TJSValue.CreateUndefined, TJSBinarySupport.Argument(Args, 0)];

  Result := FOperations.Invoke(Receiver, THEN_NAME, ThenArgs);
end;

function TJSPromiseBuiltins.CreateThenFinally(const OnFinally: IJSFunction;
                                              const Constructor_: TJSValue): IJSFunction;
begin
  Result := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Value = TJSBinarySupport.Argument(Args, 0);
      const Returned = FInterpreter.CallFunction(OnFinally, [], nil);
      const Promise = FOperations.PromiseResolve(Constructor_, Returned);

      const ValueThunk = FOperations.CreateFunction(0,
        function(const ThunkThis: IJSObject; const ThunkArgs: TArray<TJSValue>): TJSValue
        begin
          Result := Value;
        end);

      Result := FOperations.Invoke(Promise, THEN_NAME, [TJSValue.CreateObject(ValueThunk)]);
    end);
end;

function TJSPromiseBuiltins.CreateCatchFinally(const OnFinally: IJSFunction;
                                               const Constructor_: TJSValue): IJSFunction;
begin
  Result := FOperations.CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Reason = TJSBinarySupport.Argument(Args, 0);
      const Returned = FInterpreter.CallFunction(OnFinally, [], nil);
      const Promise = FOperations.PromiseResolve(Constructor_, Returned);

      const Thrower = FOperations.CreateFunction(0,
        function(const ThrowerThis: IJSObject; const ThrowerArgs: TArray<TJSValue>): TJSValue
        begin
          raise TJSThrowSignal.Create(Reason);
        end);

      Result := FOperations.Invoke(Promise, THEN_NAME, [TJSValue.CreateObject(Thrower)]);
    end);
end;

function TJSPromiseBuiltins.Finally_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Receiver = RequireObject(This, FINALLY_NAME);
  const Constructor_ = TJSValue.CreateObject(FSupport.SpeciesConstructor(This, FConstructor));

  const OnFinallyValue = TJSBinarySupport.Argument(Args, 0);
  var OnFinally: IJSFunction;
  var OnFulfilled := OnFinallyValue;
  var OnRejected := OnFinallyValue;
  if TJSBinarySupport.AsFunction(OnFinallyValue, OnFinally) then
  begin
    OnFulfilled := TJSValue.CreateObject(CreateThenFinally(OnFinally, Constructor_));
    OnRejected := TJSValue.CreateObject(CreateCatchFinally(OnFinally, Constructor_));
  end;

  Result := FOperations.Invoke(Receiver, THEN_NAME, [OnFulfilled, OnRejected]);
end;

function TJSPromiseBuiltins.Resolve_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireObject(This, RESOLVE_NAME);

  Result := FOperations.PromiseResolve(Constructor_, TJSBinarySupport.Argument(Args, 0));
end;

function TJSPromiseBuiltins.Reject_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireObject(This, REJECT_NAME);
  const Capability = FOperations.NewCapability(Constructor_, False);
  FOperations.RejectCapability(Capability, TJSBinarySupport.Argument(Args, 0));

  Result := Capability.Promise;
end;

function TJSPromiseBuiltins.WithResolvers(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireObject(This, WITH_RESOLVERS_NAME);
  const Capability = FOperations.NewCapability(Constructor_, True);

  const Entries = TJSObject.Create;
  Entries.Prototype := FInterpreter.ObjectPrototype;
  Entries.SetProperty(PROMISE_PROPERTY, Capability.Promise);
  Entries.SetProperty(RESOLVE_NAME, Capability.Resolve);
  Entries.SetProperty(REJECT_NAME, Capability.Reject);

  Result := TJSValue.CreateObject(Entries);
end;

class function TJSPromiseBuiltins.CallbackArguments(const Args: TArray<TJSValue>): TArray<TJSValue>;
begin
  const HasArguments = (Length(Args) > 1);
  if HasArguments then
    Result := Copy(Args, 1, Length(Args) - 1)
  else
    Result := nil;
end;

function TJSPromiseBuiltins.Try_(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireObject(This, TRY_NAME);

  var Callback: IJSFunction;
  var Outcome: TJSValue;
  var IsNormal: Boolean;
  if TJSBinarySupport.AsFunction(TJSBinarySupport.Argument(Args, 0), Callback) then
    IsNormal := FOperations.TryCall(Callback, CallbackArguments(Args), nil, Outcome)
  else
  begin
    Outcome := FOperations.TypeErrorValue(RESOLVER_NOT_CALLABLE);
    IsNormal := False;
  end;

  if IsNormal then
    Exit(FOperations.PromiseResolve(Constructor_, Outcome));

  const Capability = FOperations.NewCapability(Constructor_, False);
  FOperations.RejectCapability(Capability, Outcome);

  Result := Capability.Promise;
end;

procedure TJSPromiseBuiltins.DefineCombinator(const Name: string; const Kind: TJSCombinatorKind);
begin
  FSupport.DefineMethod(FConstructor, Name, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FCombinators.Combine(Kind, This, Args);
    end);
end;

procedure TJSPromiseBuiltins.DefinePrototypeMembers;
begin
  FSupport.DefineMethod(FPrototype, THEN_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Then_(This, Args);
    end);

  FSupport.DefineMethod(FPrototype, CATCH_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Catch_(This, Args);
    end);

  FSupport.DefineMethod(FPrototype, FINALLY_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Finally_(This, Args);
    end);

  FSupport.DefineToStringTag(FPrototype, PROMISE_NAME);
end;

procedure TJSPromiseBuiltins.DefineStaticMembers;
begin
  FSupport.DefineMethod(FConstructor, RESOLVE_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Resolve_(This, Args);
    end);

  FSupport.DefineMethod(FConstructor, REJECT_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Reject_(This, Args);
    end);

  FSupport.DefineMethod(FConstructor, WITH_RESOLVERS_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := WithResolvers(This, Args);
    end);

  FSupport.DefineMethod(FConstructor, TRY_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Try_(This, Args);
    end);

  DefineCombinator(ALL_NAME, TJSCombinatorKind.All);
  DefineCombinator(ALL_SETTLED_NAME, TJSCombinatorKind.AllSettled);
  DefineCombinator(ANY_NAME, TJSCombinatorKind.Any);
  DefineCombinator(RACE_NAME, TJSCombinatorKind.Race);
  FSupport.DefineSpeciesGetter(FConstructor);
end;

procedure TJSPromiseBuiltins.Register;
begin
  FAggregateErrors.Register;

  FPrototype := TJSObject.Create;
  FPrototype.Prototype := FInterpreter.ObjectPrototype;

  FConstructor := FSupport.CreateConstructor(PROMISE_NAME, 1, REQUIRES_NEW, Construct);
  FSupport.LinkConstructor(FConstructor, FPrototype);
  FOperations.Install(FPrototype, FConstructor);

  DefinePrototypeMembers;
  DefineStaticMembers;

  FInterpreter.SetGlobalVariable(PROMISE_NAME, TJSValue.CreateObject(FConstructor));

  FInterpreter.JobRunner := FOperations.RunJobs;
  FInterpreter.JobDiscarder := FOperations.DiscardJobs;
  FInterpreter.GCRootProvider := FOperations.MarkRoots;
end;

end.
