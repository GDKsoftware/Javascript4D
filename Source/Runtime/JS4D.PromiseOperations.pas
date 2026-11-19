unit JS4D.PromiseOperations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BuiltinSupport,
  JS4D.ObjectRegistry,
  JS4D.PromiseObjects,
  JS4D.PromiseJobQueue;

type
  TJSResolvingFunctions = record
    Resolve: IJSFunction;
    Reject: IJSFunction;
  end;

  TJSPromiseOperations = class
  private
    const
      CHAINING_CYCLE = 'Chaining cycle detected for promise';
      NOT_A_CONSTRUCTOR = 'The value is not a constructor';
      CAPABILITY_NOT_CALLABLE = 'Promise resolve or reject function is not callable';
      IS_FULFILLMENT = False;
      IS_REJECTION = True;

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FRegistry: TJSObjectRegistry;
      FJobs: TJSPromiseJobQueue;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    class function NewReaction: TJSPromiseReaction; static;

    function IsIntrinsicConstructor(const Candidate: IJSFunction): Boolean;
    function RequireConstructor(const ConstructorValue: TJSValue): IJSFunction;
    function CreateInternalCapability: TJSPromiseCapability;
    function CreateIntrinsicCapability: TJSPromiseCapability;
    function CreateGenericCapability(const ConstructorFunction: IJSFunction): TJSPromiseCapability;
    function InternalPromiseOf(const Capability: TJSPromiseCapability): IJSPromise;
    procedure CallCapabilityFunction(const Target: TJSValue; const Argument: TJSValue);
    function LookUpThen(const Resolution: TJSValue): TJSCallOutcome;
    procedure SettlePromise(const Promise: IJSPromise; const State: TJSPromiseState; const Value: TJSValue);
    procedure SubscribeReaction(const Promise: IJSPromise; const Reaction: TJSPromiseReaction);
    procedure RunJob(const Job: TJSPromiseJob);
    procedure RunReaction(const Job: TJSPromiseJob);
    procedure RunThenable(const Job: TJSPromiseJob);
    procedure SettleCapabilityIgnoringFailure(const Capability: TJSPromiseCapability; const IsNormal: Boolean;
                                              const Outcome: TJSValue);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);
    destructor Destroy; override;

    procedure Install(const Prototype: IJSObject; const PromiseConstructor: IJSFunction);

    function CreatePromise(const Prototype: IJSObject): IJSPromise;
    function CreateResolvingFunctions(const Promise: IJSPromise): TJSResolvingFunctions;
    procedure ResolvePromise(const Promise: IJSPromise; const Resolution: TJSValue);
    procedure RejectPromise(const Promise: IJSPromise; const Reason: TJSValue);
    function NewCapability(const ConstructorValue: TJSValue): TJSPromiseCapability;
    function NewCapabilityWithFunctions(const ConstructorValue: TJSValue): TJSPromiseCapability;
    procedure ResolveCapability(const Capability: TJSPromiseCapability; const Value: TJSValue);
    procedure RejectCapability(const Capability: TJSPromiseCapability; const Reason: TJSValue);
    function PromiseResolve(const ConstructorValue: TJSValue; const Value: TJSValue): TJSValue;
    function RejectedPromise(const ConstructorValue: TJSValue; const Reason: TJSValue): TJSValue;
    procedure PerformThen(const Promise: IJSPromise; const OnFulfilled: TJSValue; const OnRejected: TJSValue;
                          const Capability: TJSPromiseCapability);
    procedure PerformAwait(const Promise: IJSPromise; const Continuation: IJSPromiseContinuation);

    procedure RunJobs;
    procedure DiscardJobs;
    procedure ReleasePromises;
    procedure MarkRoots(const MarkValue: TJSValueVisitor);

    property Prototype: IJSObject read FPrototype;
    property PromiseConstructor: IJSFunction read FConstructor;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.PropertyKey,
  JS4D.Errors,
  JS4D.ObjectOperations,
  JS4D.PropertyNames,
  JS4D.CapabilityExecutor;

constructor TJSPromiseOperations.Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
  FRegistry := TJSObjectRegistry.Create;
  FJobs := TJSPromiseJobQueue.Create;
end;

destructor TJSPromiseOperations.Destroy;
begin
  FJobs.Free;
  FRegistry.Free;
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

procedure TJSPromiseOperations.Install(const Prototype: IJSObject; const PromiseConstructor: IJSFunction);
begin
  FPrototype := Prototype;
  FConstructor := PromiseConstructor;
end;

class function TJSPromiseOperations.NewReaction: TJSPromiseReaction;
begin
  Result := Default(TJSPromiseReaction);
  Result.OnFulfilled := TJSValue.CreateUndefined;
  Result.OnRejected := TJSValue.CreateUndefined;
end;

function TJSPromiseOperations.IsIntrinsicConstructor(const Candidate: IJSFunction): Boolean;
begin
  Result := (Assigned(FConstructor) and TJSObjectOperations.IsSameObject(Candidate, FConstructor));
end;

function TJSPromiseOperations.CreatePromise(const Prototype: IJSObject): IJSPromise;
begin
  const Promise = TJSPromiseObject.Create(FRegistry);
  Promise.Prototype := Prototype;

  Result := Promise;
end;

function TJSPromiseOperations.CreateResolvingFunctions(const Promise: IJSPromise): TJSResolvingFunctions;
begin
  var IsAlreadyResolved := False;

  Result.Resolve := FSupport.CreateMethod('', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsAlreadyResolved then
        Exit;

      IsAlreadyResolved := True;
      const Resolution = TJSArrayLike.Argument(Args, 0);
      ResolvePromise(Promise, Resolution);
    end);

  Result.Reject := FSupport.CreateMethod('', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsAlreadyResolved then
        Exit;

      IsAlreadyResolved := True;
      const Reason = TJSArrayLike.Argument(Args, 0);
      RejectPromise(Promise, Reason);
    end);
end;

procedure TJSPromiseOperations.SettlePromise(const Promise: IJSPromise; const State: TJSPromiseState;
                                             const Value: TJSValue);
begin
  const IsPending = (Promise.State = TJSPromiseState.Pending);
  if not IsPending then
    Exit;

  const IsRejection = (State = TJSPromiseState.Rejected);
  const Reactions = Promise.SettleAndTakeReactions(State, Value);
  for var Reaction in Reactions do
  begin
    FJobs.EnqueueReaction(Reaction, IsRejection, Value);
  end;
end;

procedure TJSPromiseOperations.RejectPromise(const Promise: IJSPromise; const Reason: TJSValue);
begin
  SettlePromise(Promise, TJSPromiseState.Rejected, Reason);
end;

function TJSPromiseOperations.LookUpThen(const Resolution: TJSValue): TJSCallOutcome;
begin
  Result := FSupport.Capture(
    function: TJSValue
    begin
      const Target = Resolution.ToObject;
      Result := Target.GetProperty(THEN_PROPERTY);
    end);
end;

procedure TJSPromiseOperations.ResolvePromise(const Promise: IJSPromise; const Resolution: TJSValue);
begin
  if not Resolution.IsObject then
  begin
    SettlePromise(Promise, TJSPromiseState.Fulfilled, Resolution);
    Exit;
  end;

  const IsSelfResolution = TJSObjectOperations.IsSameObject(Resolution.ToObject, Promise);
  if IsSelfResolution then
  begin
    const CycleError = FSupport.TypeErrorValue(CHAINING_CYCLE);
    RejectPromise(Promise, CycleError);
    Exit;
  end;

  const ThenLookup = LookUpThen(Resolution);
  if not ThenLookup.IsNormal then
  begin
    RejectPromise(Promise, ThenLookup.Value);
    Exit;
  end;

  const HasThen = TJSBuiltinSupport.IsCallable(ThenLookup.Value);
  if HasThen then
    FJobs.EnqueueThenable(Promise, Resolution, ThenLookup.Value)
  else
    SettlePromise(Promise, TJSPromiseState.Fulfilled, Resolution);
end;

function TJSPromiseOperations.RequireConstructor(const ConstructorValue: TJSValue): IJSFunction;
begin
  const IsConstructor = ConstructorValue.TryGetConstructor(Result);
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);
end;

function TJSPromiseOperations.NewCapability(const ConstructorValue: TJSValue): TJSPromiseCapability;
begin
  const ConstructorFunction = RequireConstructor(ConstructorValue);

  if IsIntrinsicConstructor(ConstructorFunction) then
    Result := CreateInternalCapability
  else
    Result := CreateGenericCapability(ConstructorFunction);
end;

function TJSPromiseOperations.NewCapabilityWithFunctions(const ConstructorValue: TJSValue): TJSPromiseCapability;
begin
  const ConstructorFunction = RequireConstructor(ConstructorValue);

  if IsIntrinsicConstructor(ConstructorFunction) then
    Result := CreateIntrinsicCapability
  else
    Result := CreateGenericCapability(ConstructorFunction);
end;

function TJSPromiseOperations.CreateInternalCapability: TJSPromiseCapability;
begin
  const Promise = CreatePromise(FPrototype);

  Result := Default(TJSPromiseCapability);
  Result.Promise := TJSValue.CreateObject(Promise);
  Result.IsInternal := True;
end;

function TJSPromiseOperations.CreateIntrinsicCapability: TJSPromiseCapability;
begin
  const Promise = CreatePromise(FPrototype);
  const Resolving = CreateResolvingFunctions(Promise);

  Result := Default(TJSPromiseCapability);
  Result.Promise := TJSValue.CreateObject(Promise);
  Result.Resolve := TJSValue.CreateObject(Resolving.Resolve);
  Result.Reject := TJSValue.CreateObject(Resolving.Reject);
end;

function TJSPromiseOperations.CreateGenericCapability(const ConstructorFunction: IJSFunction): TJSPromiseCapability;
begin
  const Slots: IJSCapabilityExecutor = TJSCapabilityExecutor.Create;

  const Executor = FSupport.CreateMethod('', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Slots.Execute(Args);
    end);

  const ExecutorValue = TJSValue.CreateObject(Executor);
  const Created = FInterpreter.Construct(ConstructorFunction, [ExecutorValue]);

  const IsResolveCallable = TJSBuiltinSupport.IsCallable(Slots.Resolve);
  const IsRejectCallable = TJSBuiltinSupport.IsCallable(Slots.Reject);
  const AreCallable = (IsResolveCallable and IsRejectCallable);
  if not AreCallable then
    raise TJSErrorFactory.TypeError(CAPABILITY_NOT_CALLABLE);

  Result := Default(TJSPromiseCapability);
  Result.Promise := Created;
  Result.Resolve := Slots.Resolve;
  Result.Reject := Slots.Reject;
end;

function TJSPromiseOperations.InternalPromiseOf(const Capability: TJSPromiseCapability): IJSPromise;
begin
  const PromiseObject = Capability.Promise.ToObject;
  if not Supports(PromiseObject, IJSPromise, Result) then
    Result := nil;
end;

procedure TJSPromiseOperations.CallCapabilityFunction(const Target: TJSValue; const Argument: TJSValue);
begin
  var Func: IJSFunction;
  const IsFunction = Target.TryGetFunction(Func);
  if not IsFunction then
    raise TJSErrorFactory.TypeError(CAPABILITY_NOT_CALLABLE);

  const Args: TArray<TJSValue> = [Argument];
  FInterpreter.CallFunction(Func, Args, nil);
end;

procedure TJSPromiseOperations.ResolveCapability(const Capability: TJSPromiseCapability; const Value: TJSValue);
begin
  if not Capability.IsInternal then
  begin
    CallCapabilityFunction(Capability.Resolve, Value);
    Exit;
  end;

  const Promise = InternalPromiseOf(Capability);
  if Assigned(Promise) then
    ResolvePromise(Promise, Value);
end;

procedure TJSPromiseOperations.RejectCapability(const Capability: TJSPromiseCapability; const Reason: TJSValue);
begin
  if not Capability.IsInternal then
  begin
    CallCapabilityFunction(Capability.Reject, Reason);
    Exit;
  end;

  const Promise = InternalPromiseOf(Capability);
  if Assigned(Promise) then
    RejectPromise(Promise, Reason);
end;

function TJSPromiseOperations.PromiseResolve(const ConstructorValue: TJSValue; const Value: TJSValue): TJSValue;
begin
  var Existing: IJSPromise;
  const IsPromise = (Value.IsObject and Supports(Value.ToObject, IJSPromise, Existing));
  if IsPromise then
  begin
    const ValueConstructor = Value.ToObject.GetProperty(CONSTRUCTOR_PROPERTY);
    const HasSameConstructor = ValueConstructor.StrictEquals(ConstructorValue);
    if HasSameConstructor then
      Exit(Value);
  end;

  const Capability = NewCapability(ConstructorValue);
  ResolveCapability(Capability, Value);

  Result := Capability.Promise;
end;

function TJSPromiseOperations.RejectedPromise(const ConstructorValue: TJSValue; const Reason: TJSValue): TJSValue;
begin
  const Capability = NewCapability(ConstructorValue);
  RejectCapability(Capability, Reason);

  Result := Capability.Promise;
end;

procedure TJSPromiseOperations.PerformThen(const Promise: IJSPromise; const OnFulfilled: TJSValue;
                                           const OnRejected: TJSValue; const Capability: TJSPromiseCapability);
begin
  var Reaction := NewReaction;
  Reaction.Capability := Capability;
  Reaction.HasCapability := True;

  if TJSBuiltinSupport.IsCallable(OnFulfilled) then
    Reaction.OnFulfilled := OnFulfilled;

  if TJSBuiltinSupport.IsCallable(OnRejected) then
    Reaction.OnRejected := OnRejected;

  SubscribeReaction(Promise, Reaction);
end;

procedure TJSPromiseOperations.PerformAwait(const Promise: IJSPromise; const Continuation: IJSPromiseContinuation);
begin
  var Reaction := NewReaction;
  Reaction.Continuation := Continuation;

  SubscribeReaction(Promise, Reaction);
end;

procedure TJSPromiseOperations.SubscribeReaction(const Promise: IJSPromise; const Reaction: TJSPromiseReaction);
begin
  case Promise.State of
    TJSPromiseState.Pending   : Promise.AddReaction(Reaction);
    TJSPromiseState.Fulfilled : FJobs.EnqueueReaction(Reaction, IS_FULFILLMENT, Promise.Result);
    TJSPromiseState.Rejected  : FJobs.EnqueueReaction(Reaction, IS_REJECTION, Promise.Result);
  else
    raise ENotSupportedException.CreateFmt('Unsupported promise state: %d', [Ord(Promise.State)]);
  end;
end;

procedure TJSPromiseOperations.RunJobs;
begin
  while not FJobs.IsEmpty do
  begin
    FInterpreter.ConsumeStep;
    RunJob(FJobs.Dequeue);
  end;
end;

procedure TJSPromiseOperations.DiscardJobs;
begin
  FJobs.Clear;
end;

procedure TJSPromiseOperations.ReleasePromises;
begin
  DiscardJobs;
  FRegistry.ReleaseAll;
end;

procedure TJSPromiseOperations.RunJob(const Job: TJSPromiseJob);
begin
  case Job.Kind of
    TJSPromiseJobKind.Reaction        : RunReaction(Job);
    TJSPromiseJobKind.ResolveThenable : RunThenable(Job);
  else
    raise ENotSupportedException.CreateFmt('Unsupported promise job: %d', [Ord(Job.Kind)]);
  end;
end;

procedure TJSPromiseOperations.RunReaction(const Job: TJSPromiseJob);
begin
  if Assigned(Job.Reaction.Continuation) then
  begin
    Job.Reaction.Continuation.Resume(Job.IsRejection, Job.Argument);
    Exit;
  end;

  var Handler: TJSValue;
  if Job.IsRejection then
    Handler := Job.Reaction.OnRejected
  else
    Handler := Job.Reaction.OnFulfilled;

  var Outcome := Job.Argument;
  var IsNormal := (not Job.IsRejection);

  var HandlerFunction: IJSFunction;
  const HasHandler = Handler.TryGetFunction(HandlerFunction);
  if HasHandler then
  begin
    const HandlerArgs: TArray<TJSValue> = [Job.Argument];
    const Called = FSupport.CallCapturingThrow(HandlerFunction, HandlerArgs, nil);
    IsNormal := Called.IsNormal;
    Outcome := Called.Value;
  end;

  if Job.Reaction.HasCapability then
    SettleCapabilityIgnoringFailure(Job.Reaction.Capability, IsNormal, Outcome);
end;

procedure TJSPromiseOperations.SettleCapabilityIgnoringFailure(const Capability: TJSPromiseCapability;
                                                               const IsNormal: Boolean;
                                                               const Outcome: TJSValue);
begin
  FSupport.AttemptIgnoringFailure(
    procedure
    begin
      if IsNormal then
        ResolveCapability(Capability, Outcome)
      else
        RejectCapability(Capability, Outcome);
    end);
end;

procedure TJSPromiseOperations.RunThenable(const Job: TJSPromiseJob);
begin
  const Resolving = CreateResolvingFunctions(Job.Promise);

  var ThenFunction: IJSFunction;
  const HasThen = Job.ThenFunction.TryGetFunction(ThenFunction);
  if not HasThen then
    raise TJSErrorFactory.TypeError(CAPABILITY_NOT_CALLABLE);

  const ResolveValue = TJSValue.CreateObject(Resolving.Resolve);
  const RejectValue = TJSValue.CreateObject(Resolving.Reject);
  const Args: TArray<TJSValue> = [ResolveValue, RejectValue];
  const Receiver = Job.Thenable.ToObject;

  const Called = FSupport.CallCapturingThrow(ThenFunction, Args, Receiver);
  if not Called.IsNormal then
  begin
    const RejectArgs: TArray<TJSValue> = [Called.Value];
    FInterpreter.CallFunction(Resolving.Reject, RejectArgs, nil);
  end;
end;

procedure TJSPromiseOperations.MarkRoots(const MarkValue: TJSValueVisitor);
begin
  for var Entry in FRegistry do
  begin
    const Promise = (Entry as TJSPromiseObject);
    Promise.EnumerateValues(MarkValue);
  end;

  FJobs.EnumerateValues(MarkValue);
end;

end.
