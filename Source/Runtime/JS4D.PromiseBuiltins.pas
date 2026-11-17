unit JS4D.PromiseBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.ControlFlow,
  JS4D.Interpreter,
  JS4D.BuiltinSupport,
  JS4D.AggregateErrorBuiltins,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations,
  JS4D.PromiseCombinators;

type
  TJSPromiseBuiltins = class
  private
    const
      PROMISE_NAME = 'Promise';
      CATCH_NAME = 'catch';
      FINALLY_NAME = 'finally';
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
      FSupport: TJSBuiltinSupport;
      FAggregateErrors: TJSAggregateErrorBuiltins;
      FOperations: TJSPromiseOperations;
      FCombinators: TJSPromiseCombinators;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
    function RequirePromise(const This: IJSObject; const MethodName: string): IJSPromise;
    function RequireObject(const This: IJSObject; const MethodName: string): TJSValue;
    function ThenMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CatchMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function FinallyMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function RunFinally(const OnFinally: IJSFunction; const ConstructorValue: TJSValue): TJSValue;
    function CreateValueThunk(const Value: TJSValue): IJSFunction;
    function CreateThrower(const Reason: TJSValue): IJSFunction;
    function CreateThenFinally(const OnFinally: IJSFunction; const ConstructorValue: TJSValue): IJSFunction;
    function CreateCatchFinally(const OnFinally: IJSFunction; const ConstructorValue: TJSValue): IJSFunction;
    function ResolveMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function RejectMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function WithResolversMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function TryMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CallTryCallback(const Args: TArray<TJSValue>): TJSCallOutcome;
    procedure DefineCombinator(const Name: string; const Kind: TJSCombinatorKind);
    procedure DefinePrototypeMembers;
    procedure DefineStaticMembers;

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
    procedure ReleasePromises;

    property Operations: TJSPromiseOperations read FOperations;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.PropertyKey,
  JS4D.Errors,
  JS4D.PropertyNames;

constructor TJSPromiseBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
  FAggregateErrors := TJSAggregateErrorBuiltins.Create(Interpreter, FSupport);
  FOperations := TJSPromiseOperations.Create(Interpreter, FSupport);
  FCombinators := TJSPromiseCombinators.Create(Interpreter, FSupport, FOperations, FAggregateErrors);
end;

destructor TJSPromiseBuiltins.Destroy;
begin
  FSupport.UnlinkConstructor(FPrototype);

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
  const ExecutorValue = TJSArrayLike.Argument(Args, 0);
  var Executor: IJSFunction;
  const IsCallable = TJSBuiltinSupport.TryGetFunction(ExecutorValue, Executor);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(RESOLVER_NOT_CALLABLE);

  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);
  const Promise = FOperations.CreatePromise(Prototype);
  const Resolving = FOperations.CreateResolvingFunctions(Promise);

  const ResolveValue = TJSValue.CreateObject(Resolving.Resolve);
  const RejectValue = TJSValue.CreateObject(Resolving.Reject);
  const ExecutorArgs: TArray<TJSValue> = [ResolveValue, RejectValue];
  const Called = FSupport.CallCapturingThrow(Executor, ExecutorArgs, nil);
  if not Called.IsNormal then
  begin
    const RejectArgs: TArray<TJSValue> = [Called.Value];
    FInterpreter.CallFunction(Resolving.Reject, RejectArgs, nil);
  end;

  Result := TJSValue.CreateObject(Promise);
end;

function TJSPromiseBuiltins.RequirePromise(const This: IJSObject; const MethodName: string): IJSPromise;
begin
  const IsPromise = (Assigned(This) and Supports(This, IJSPromise, Result));
  if not IsPromise then
  begin
    const Message = Format(INCOMPATIBLE_RECEIVER, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSPromiseBuiltins.RequireObject(const This: IJSObject; const MethodName: string): TJSValue;
begin
  if not Assigned(This) then
  begin
    const Message = Format(NOT_AN_OBJECT, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := TJSValue.CreateObject(This);
end;

function TJSPromiseBuiltins.ThenMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Promise = RequirePromise(This, THEN_PROPERTY);
  const Species = FSupport.SpeciesConstructor(This, FConstructor);
  const ConstructorValue = TJSValue.CreateObject(Species);
  const Capability = FOperations.NewCapability(ConstructorValue);

  const OnFulfilled = TJSArrayLike.Argument(Args, 0);
  const OnRejected = TJSArrayLike.Argument(Args, 1);
  FOperations.PerformThen(Promise, OnFulfilled, OnRejected, Capability);

  Result := Capability.Promise;
end;

function TJSPromiseBuiltins.CatchMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Receiver = RequireObject(This, CATCH_NAME);
  const Undefined = TJSValue.CreateUndefined;
  const OnRejected = TJSArrayLike.Argument(Args, 0);
  const ThenArgs: TArray<TJSValue> = [Undefined, OnRejected];

  Result := FSupport.Invoke(Receiver, THEN_PROPERTY, ThenArgs);
end;

function TJSPromiseBuiltins.RunFinally(const OnFinally: IJSFunction; const ConstructorValue: TJSValue): TJSValue;
begin
  const NoArguments: TArray<TJSValue> = [];
  const Returned = FInterpreter.CallFunction(OnFinally, NoArguments, nil);

  Result := FOperations.PromiseResolve(ConstructorValue, Returned);
end;

function TJSPromiseBuiltins.CreateValueThunk(const Value: TJSValue): IJSFunction;
begin
  Result := FSupport.CreateMethod('', 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Value;
    end);
end;

function TJSPromiseBuiltins.CreateThrower(const Reason: TJSValue): IJSFunction;
begin
  Result := FSupport.CreateMethod('', 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      raise TJSThrowSignal.Create(Reason);
    end);
end;

function TJSPromiseBuiltins.CreateThenFinally(const OnFinally: IJSFunction;
                                              const ConstructorValue: TJSValue): IJSFunction;
begin
  Result := FSupport.CreateMethod('', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Value = TJSArrayLike.Argument(Args, 0);
      const Promise = RunFinally(OnFinally, ConstructorValue);

      const ValueThunk = CreateValueThunk(Value);
      const ThunkValue = TJSValue.CreateObject(ValueThunk);
      const ThenArgs: TArray<TJSValue> = [ThunkValue];

      Result := FSupport.Invoke(Promise, THEN_PROPERTY, ThenArgs);
    end);
end;

function TJSPromiseBuiltins.CreateCatchFinally(const OnFinally: IJSFunction;
                                               const ConstructorValue: TJSValue): IJSFunction;
begin
  Result := FSupport.CreateMethod('', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Reason = TJSArrayLike.Argument(Args, 0);
      const Promise = RunFinally(OnFinally, ConstructorValue);

      const Thrower = CreateThrower(Reason);
      const ThrowerValue = TJSValue.CreateObject(Thrower);
      const ThenArgs: TArray<TJSValue> = [ThrowerValue];

      Result := FSupport.Invoke(Promise, THEN_PROPERTY, ThenArgs);
    end);
end;

function TJSPromiseBuiltins.FinallyMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Receiver = RequireObject(This, FINALLY_NAME);
  const Species = FSupport.SpeciesConstructor(This, FConstructor);
  const ConstructorValue = TJSValue.CreateObject(Species);

  const OnFinallyValue = TJSArrayLike.Argument(Args, 0);
  var OnFinally: IJSFunction;
  var OnFulfilled := OnFinallyValue;
  var OnRejected := OnFinallyValue;
  const IsCallable = TJSBuiltinSupport.TryGetFunction(OnFinallyValue, OnFinally);
  if IsCallable then
  begin
    const ThenFinally = CreateThenFinally(OnFinally, ConstructorValue);
    const CatchFinally = CreateCatchFinally(OnFinally, ConstructorValue);
    OnFulfilled := TJSValue.CreateObject(ThenFinally);
    OnRejected := TJSValue.CreateObject(CatchFinally);
  end;

  const ThenArgs: TArray<TJSValue> = [OnFulfilled, OnRejected];

  Result := FSupport.Invoke(Receiver, THEN_PROPERTY, ThenArgs);
end;

function TJSPromiseBuiltins.ResolveMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ConstructorValue = RequireObject(This, RESOLVE_PROPERTY);
  const Resolution = TJSArrayLike.Argument(Args, 0);

  Result := FOperations.PromiseResolve(ConstructorValue, Resolution);
end;

function TJSPromiseBuiltins.RejectMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ConstructorValue = RequireObject(This, REJECT_PROPERTY);
  const Reason = TJSArrayLike.Argument(Args, 0);

  Result := FOperations.RejectedPromise(ConstructorValue, Reason);
end;

function TJSPromiseBuiltins.WithResolversMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ConstructorValue = RequireObject(This, WITH_RESOLVERS_NAME);
  const Capability = FOperations.NewCapabilityWithFunctions(ConstructorValue);

  const Entries = TJSObject.Create;
  Entries.Prototype := FInterpreter.ObjectPrototype;
  Entries.SetProperty(PROMISE_PROPERTY, Capability.Promise);
  Entries.SetProperty(RESOLVE_PROPERTY, Capability.Resolve);
  Entries.SetProperty(REJECT_PROPERTY, Capability.Reject);

  Result := TJSValue.CreateObject(Entries);
end;

function TJSPromiseBuiltins.CallTryCallback(const Args: TArray<TJSValue>): TJSCallOutcome;
begin
  const CallbackValue = TJSArrayLike.Argument(Args, 0);
  var Callback: IJSFunction;
  const IsCallable = TJSBuiltinSupport.TryGetFunction(CallbackValue, Callback);
  if IsCallable then
  begin
    const CallbackArgs = TJSBuiltinSupport.ArgumentsFrom(Args, 1);
    Result := FSupport.CallCapturingThrow(Callback, CallbackArgs, nil);
  end
  else
  begin
    Result.IsNormal := False;
    Result.Value := FSupport.TypeErrorValue(RESOLVER_NOT_CALLABLE);
  end;
end;

function TJSPromiseBuiltins.TryMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ConstructorValue = RequireObject(This, TRY_NAME);
  const Outcome = CallTryCallback(Args);

  if Outcome.IsNormal then
    Result := FOperations.PromiseResolve(ConstructorValue, Outcome.Value)
  else
    Result := FOperations.RejectedPromise(ConstructorValue, Outcome.Value);
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
  FSupport.DefineMethod(FPrototype, THEN_PROPERTY, 2, ThenMethod);
  FSupport.DefineMethod(FPrototype, CATCH_NAME, 1, CatchMethod);
  FSupport.DefineMethod(FPrototype, FINALLY_NAME, 1, FinallyMethod);
  FSupport.DefineToStringTag(FPrototype, PROMISE_NAME);
end;

procedure TJSPromiseBuiltins.DefineStaticMembers;
begin
  FSupport.DefineMethod(FConstructor, RESOLVE_PROPERTY, 1, ResolveMethod);
  FSupport.DefineMethod(FConstructor, REJECT_PROPERTY, 1, RejectMethod);
  FSupport.DefineMethod(FConstructor, WITH_RESOLVERS_NAME, 0, WithResolversMethod);
  FSupport.DefineMethod(FConstructor, TRY_NAME, 1, TryMethod);

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

  const PromiseValue = TJSValue.CreateObject(FConstructor);
  FInterpreter.SetGlobalVariable(PROMISE_NAME, PromiseValue);

  FInterpreter.JobRunner := FOperations.RunJobs;
  FInterpreter.JobDiscarder := FOperations.DiscardJobs;
  FInterpreter.GCRootProvider := FOperations.MarkRoots;
end;

end.
