unit JS4D.PromiseOperations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BinarySupport,
  JS4D.PromiseObjects;

type
  TJSPromiseJobKind = (Reaction, ResolveThenable);

  TJSPromiseJob = record
    Kind: TJSPromiseJobKind;
    Reaction: TJSPromiseReaction;
    Argument: TJSValue;
    IsRejection: Boolean;
    Promise: IJSPromise;
    Thenable: TJSValue;
    ThenFunction: TJSValue;
  end;

  // The abstract operations of promises and the queue of jobs that their reactions wait in.
  TJSPromiseOperations = class
  private
    const
      THEN_PROPERTY = 'then';
      CONSTRUCTOR_PROPERTY = 'constructor';
      CHAINING_CYCLE = 'Chaining cycle detected for promise';
      NOT_A_CONSTRUCTOR = 'The value is not a constructor';
      NOT_A_FUNCTION = '%s is not a function';
      EXECUTOR_ALREADY_CALLED = 'Promise executor has already been invoked with non-undefined arguments';
      CAPABILITY_NOT_CALLABLE = 'Promise resolve or reject function is not callable';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBinarySupport;
      FRegistry: TJSPromiseRegistry;
      FJobs: TQueue<TJSPromiseJob>;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function IsIntrinsicConstructor(const Candidate: IJSFunction): Boolean;
    function CreateGenericCapability(const Constructor_: IJSFunction): TJSPromiseCapability;
    procedure SettlePromise(const Promise: IJSPromise; const State: TJSPromiseState; const Value: TJSValue);
    procedure EnqueueReaction(const Reaction: TJSPromiseReaction; const IsRejection: Boolean;
                              const Argument: TJSValue);
    procedure AddReaction(const Promise: IJSPromise; const Reaction: TJSPromiseReaction);
    procedure EnqueueThenable(const Promise: IJSPromise; const Thenable: TJSValue; const ThenFunction: TJSValue);
    procedure RunJob(const Job: TJSPromiseJob);
    procedure RunReaction(const Job: TJSPromiseJob);
    procedure RunThenable(const Job: TJSPromiseJob);
    procedure FinishReaction(const Capability: TJSPromiseCapability; const IsNormal: Boolean;
                             const Outcome: TJSValue);
    procedure MarkJob(const Job: TJSPromiseJob; const MarkValue: TProc<TJSValue>);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport);
    destructor Destroy; override;

    procedure Install(const Prototype: IJSObject; const Constructor_: IJSFunction);

    function CreatePromise(const Prototype: IJSObject): IJSPromise;
    function CreateFunction(const ParameterCount: Integer; const Method: TNativeFunction): IJSFunction;
    procedure CreateResolvingFunctions(const Promise: IJSPromise; out Resolve: IJSFunction; out Reject: IJSFunction);
    procedure ResolvePromise(const Promise: IJSPromise; const Resolution: TJSValue);
    procedure RejectPromise(const Promise: IJSPromise; const Reason: TJSValue);
    function NewCapability(const Constructor_: TJSValue; const NeedsFunctions: Boolean): TJSPromiseCapability;
    procedure ResolveCapability(const Capability: TJSPromiseCapability; const Value: TJSValue);
    procedure RejectCapability(const Capability: TJSPromiseCapability; const Reason: TJSValue);
    function PromiseResolve(const Constructor_: TJSValue; const Value: TJSValue): TJSValue;
    function Invoke(const Target: TJSValue; const Name: string; const Args: TArray<TJSValue>): TJSValue;
    procedure PerformThen(const Promise: IJSPromise; const OnFulfilled: TJSValue; const OnRejected: TJSValue;
                          const Capability: TJSPromiseCapability; const HasCapability: Boolean);
    procedure PerformAwait(const Promise: IJSPromise; const Continuation: IJSPromiseContinuation);
    function TryCall(const Func: IJSFunction; const Args: TArray<TJSValue>; const This: IJSObject;
                     out Outcome: TJSValue): Boolean;
    function TypeErrorValue(const Message: string): TJSValue;

    procedure RunJobs;
    procedure DiscardJobs;
    procedure ReleasePromises;
    procedure MarkRoots(const MarkValue: TProc<TJSValue>);

    property Prototype: IJSObject read FPrototype;
    property Constructor_: IJSFunction read FConstructor;
  end;

implementation

uses
  JS4D.Errors;

constructor TJSPromiseOperations.Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
  FRegistry := TJSPromiseRegistry.Create;
  FJobs := TQueue<TJSPromiseJob>.Create;
end;

destructor TJSPromiseOperations.Destroy;
begin
  FJobs.Free;
  FRegistry.Free;
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

procedure TJSPromiseOperations.Install(const Prototype: IJSObject; const Constructor_: IJSFunction);
begin
  FPrototype := Prototype;
  FConstructor := Constructor_;
end;

function TJSPromiseOperations.IsIntrinsicConstructor(const Candidate: IJSFunction): Boolean;
begin
  Result := Assigned(FConstructor) and ((Candidate as IInterface) = (FConstructor as IInterface));
end;

function TJSPromiseOperations.CreatePromise(const Prototype: IJSObject): IJSPromise;
begin
  const Promise = TJSPromiseObject.Create(FRegistry);
  Promise.Prototype := Prototype;

  Result := Promise;
end;

function TJSPromiseOperations.CreateFunction(const ParameterCount: Integer;
                                             const Method: TNativeFunction): IJSFunction;
begin
  Result := FSupport.CreateMethod('', ParameterCount, Method);
end;

function TJSPromiseOperations.TryCall(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                      const This: IJSObject; out Outcome: TJSValue): Boolean;
begin
  try
    Outcome := FInterpreter.CallFunction(Func, Args, This);
    Result := True;
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      Outcome := FInterpreter.ExceptionToValue(Error);
      Result := False;
    end;
  end;
end;

function TJSPromiseOperations.TypeErrorValue(const Message: string): TJSValue;
begin
  const Error = TJSErrorFactory.TypeError(Message);
  try
    Result := FInterpreter.ExceptionToValue(Error);
  finally
    Error.Free;
  end;
end;

procedure TJSPromiseOperations.CreateResolvingFunctions(const Promise: IJSPromise; out Resolve: IJSFunction;
                                                        out Reject: IJSFunction);
begin
  var IsAlreadyResolved := False;

  Resolve := CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsAlreadyResolved then
        Exit;

      IsAlreadyResolved := True;
      ResolvePromise(Promise, TJSBinarySupport.Argument(Args, 0));
    end);

  Reject := CreateFunction(1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
      if IsAlreadyResolved then
        Exit;

      IsAlreadyResolved := True;
      RejectPromise(Promise, TJSBinarySupport.Argument(Args, 0));
    end);
end;

procedure TJSPromiseOperations.SettlePromise(const Promise: IJSPromise; const State: TJSPromiseState;
                                             const Value: TJSValue);
begin
  const IsPending = (Promise.State = TJSPromiseState.Pending);
  if not IsPending then
    Exit;

  const IsRejection = (State = TJSPromiseState.Rejected);
  const Reactions = Promise.Settle(State, Value);
  for var Reaction in Reactions do
  begin
    EnqueueReaction(Reaction, IsRejection, Value);
  end;
end;

procedure TJSPromiseOperations.RejectPromise(const Promise: IJSPromise; const Reason: TJSValue);
begin
  SettlePromise(Promise, TJSPromiseState.Rejected, Reason);
end;

procedure TJSPromiseOperations.ResolvePromise(const Promise: IJSPromise; const Resolution: TJSValue);
begin
  if not Resolution.IsObject then
  begin
    SettlePromise(Promise, TJSPromiseState.Fulfilled, Resolution);
    Exit;
  end;

  const IsSelfResolution = (Resolution.ToObject as IInterface) = (Promise as IInterface);
  if IsSelfResolution then
  begin
    RejectPromise(Promise, TypeErrorValue(CHAINING_CYCLE));
    Exit;
  end;

  var ThenValue: TJSValue;
  try
    ThenValue := Resolution.ToObject.GetProperty(THEN_PROPERTY);
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      RejectPromise(Promise, FInterpreter.ExceptionToValue(Error));
      Exit;
    end;
  end;

  var ThenFunction: IJSFunction;
  const HasThen = TJSBinarySupport.AsFunction(ThenValue, ThenFunction);
  if HasThen then
    EnqueueThenable(Promise, Resolution, ThenValue)
  else
    SettlePromise(Promise, TJSPromiseState.Fulfilled, Resolution);
end;

function TJSPromiseOperations.CreateGenericCapability(const Constructor_: IJSFunction): TJSPromiseCapability;
begin
  var ResolveValue := TJSValue.CreateUndefined;
  var RejectValue := TJSValue.CreateUndefined;

  const Executor = FSupport.CreateMethod('', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const IsUsed = (not ResolveValue.IsUndefined) or (not RejectValue.IsUndefined);
      if IsUsed then
        raise TJSErrorFactory.TypeError(EXECUTOR_ALREADY_CALLED);

      ResolveValue := TJSBinarySupport.Argument(Args, 0);
      RejectValue := TJSBinarySupport.Argument(Args, 1);
      Result := TJSValue.CreateUndefined;
    end);

  const Created = FInterpreter.Construct(Constructor_, [TJSValue.CreateObject(Executor)]);

  var Ignored: IJSFunction;
  const AreCallable = TJSBinarySupport.AsFunction(ResolveValue, Ignored) and
                      TJSBinarySupport.AsFunction(RejectValue, Ignored);
  if not AreCallable then
    raise TJSErrorFactory.TypeError(CAPABILITY_NOT_CALLABLE);

  Result := Default(TJSPromiseCapability);
  Result.Promise := Created;
  Result.Resolve := ResolveValue;
  Result.Reject := RejectValue;
end;

function TJSPromiseOperations.NewCapability(const Constructor_: TJSValue;
                                            const NeedsFunctions: Boolean): TJSPromiseCapability;
begin
  var ConstructorFunction: IJSFunction;
  if not TJSBinarySupport.AsConstructor(Constructor_, ConstructorFunction) then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);

  if not IsIntrinsicConstructor(ConstructorFunction) then
    Exit(CreateGenericCapability(ConstructorFunction));

  const Promise = CreatePromise(FPrototype);
  Result := Default(TJSPromiseCapability);
  Result.Promise := TJSValue.CreateObject(Promise);

  if not NeedsFunctions then
  begin
    Result.IsInternal := True;
    Exit;
  end;

  var Resolve: IJSFunction;
  var Reject: IJSFunction;
  CreateResolvingFunctions(Promise, Resolve, Reject);
  Result.Resolve := TJSValue.CreateObject(Resolve);
  Result.Reject := TJSValue.CreateObject(Reject);
end;

procedure TJSPromiseOperations.ResolveCapability(const Capability: TJSPromiseCapability; const Value: TJSValue);
begin
  if Capability.IsInternal then
  begin
    var Promise: IJSPromise;
    if Supports(Capability.Promise.ToObject, IJSPromise, Promise) then
      ResolvePromise(Promise, Value);

    Exit;
  end;

  var Func: IJSFunction;
  TJSBinarySupport.AsFunction(Capability.Resolve, Func);
  FInterpreter.CallFunction(Func, [Value], nil);
end;

procedure TJSPromiseOperations.RejectCapability(const Capability: TJSPromiseCapability; const Reason: TJSValue);
begin
  if Capability.IsInternal then
  begin
    var Promise: IJSPromise;
    if Supports(Capability.Promise.ToObject, IJSPromise, Promise) then
      RejectPromise(Promise, Reason);

    Exit;
  end;

  var Func: IJSFunction;
  TJSBinarySupport.AsFunction(Capability.Reject, Func);
  FInterpreter.CallFunction(Func, [Reason], nil);
end;

function TJSPromiseOperations.PromiseResolve(const Constructor_: TJSValue; const Value: TJSValue): TJSValue;
begin
  var Existing: IJSPromise;
  const IsPromise = Value.IsObject and Supports(Value.ToObject, IJSPromise, Existing);
  if IsPromise then
  begin
    const ValueConstructor = Value.ToObject.GetProperty(CONSTRUCTOR_PROPERTY);
    const HasSameConstructor = ValueConstructor.StrictEquals(Constructor_);
    if HasSameConstructor then
      Exit(Value);
  end;

  const Capability = NewCapability(Constructor_, False);
  ResolveCapability(Capability, Value);

  Result := Capability.Promise;
end;

function TJSPromiseOperations.Invoke(const Target: TJSValue; const Name: string;
                                    const Args: TArray<TJSValue>): TJSValue;
begin
  const Holder = FSupport.ToObject(Target);
  const Method = Holder.GetProperty(Name);

  var Func: IJSFunction;
  if not TJSBinarySupport.AsFunction(Method, Func) then
    raise TJSErrorFactory.TypeError(Format(NOT_A_FUNCTION, [Name]));

  const ThisObj = FInterpreter.ThisObjectFor(Func, Target);

  Result := FInterpreter.CallFunction(Func, Args, ThisObj);
end;

procedure TJSPromiseOperations.PerformThen(const Promise: IJSPromise; const OnFulfilled: TJSValue;
                                           const OnRejected: TJSValue; const Capability: TJSPromiseCapability;
                                           const HasCapability: Boolean);
begin
  var Ignored: IJSFunction;
  var Reaction := Default(TJSPromiseReaction);
  Reaction.Capability := Capability;
  Reaction.HasCapability := HasCapability;
  Reaction.OnFulfilled := TJSValue.CreateUndefined;
  Reaction.OnRejected := TJSValue.CreateUndefined;

  if TJSBinarySupport.AsFunction(OnFulfilled, Ignored) then
    Reaction.OnFulfilled := OnFulfilled;

  if TJSBinarySupport.AsFunction(OnRejected, Ignored) then
    Reaction.OnRejected := OnRejected;

  AddReaction(Promise, Reaction);
end;

procedure TJSPromiseOperations.PerformAwait(const Promise: IJSPromise; const Continuation: IJSPromiseContinuation);
begin
  var Reaction := Default(TJSPromiseReaction);
  Reaction.OnFulfilled := TJSValue.CreateUndefined;
  Reaction.OnRejected := TJSValue.CreateUndefined;
  Reaction.Continuation := Continuation;

  AddReaction(Promise, Reaction);
end;

procedure TJSPromiseOperations.AddReaction(const Promise: IJSPromise; const Reaction: TJSPromiseReaction);
begin
  case Promise.State of
    TJSPromiseState.Pending   : Promise.AddReaction(Reaction);
    TJSPromiseState.Fulfilled : EnqueueReaction(Reaction, False, Promise.Result);
    TJSPromiseState.Rejected  : EnqueueReaction(Reaction, True, Promise.Result);
  else
    raise ENotSupportedException.CreateFmt('Unsupported promise state: %d', [Ord(Promise.State)]);
  end;

  Promise.IsHandled := True;
end;

procedure TJSPromiseOperations.EnqueueReaction(const Reaction: TJSPromiseReaction; const IsRejection: Boolean;
                                               const Argument: TJSValue);
begin
  var Job := Default(TJSPromiseJob);
  Job.Kind := TJSPromiseJobKind.Reaction;
  Job.Reaction := Reaction;
  Job.IsRejection := IsRejection;
  Job.Argument := Argument;

  FJobs.Enqueue(Job);
end;

procedure TJSPromiseOperations.EnqueueThenable(const Promise: IJSPromise; const Thenable: TJSValue;
                                               const ThenFunction: TJSValue);
begin
  var Job := Default(TJSPromiseJob);
  Job.Kind := TJSPromiseJobKind.ResolveThenable;
  Job.Promise := Promise;
  Job.Thenable := Thenable;
  Job.ThenFunction := ThenFunction;

  FJobs.Enqueue(Job);
end;

procedure TJSPromiseOperations.RunJobs;
begin
  while FJobs.Count > 0 do
  begin
    FInterpreter.ChargeStep;
    RunJob(FJobs.Dequeue);
  end;
end;

procedure TJSPromiseOperations.DiscardJobs;
begin
  FJobs.Clear;
end;

procedure TJSPromiseOperations.ReleasePromises;
begin
  FJobs.Clear;
  FRegistry.ClearAll;
end;

procedure TJSPromiseOperations.RunJob(const Job: TJSPromiseJob);
begin
  case Job.Kind of
    TJSPromiseJobKind.Reaction         : RunReaction(Job);
    TJSPromiseJobKind.ResolveThenable  : RunThenable(Job);
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
  if TJSBinarySupport.AsFunction(Handler, HandlerFunction) then
    IsNormal := TryCall(HandlerFunction, [Job.Argument], nil, Outcome);

  if Job.Reaction.HasCapability then
    FinishReaction(Job.Reaction.Capability, IsNormal, Outcome);
end;

procedure TJSPromiseOperations.FinishReaction(const Capability: TJSPromiseCapability; const IsNormal: Boolean;
                                              const Outcome: TJSValue);
begin
  try
    if IsNormal then
      ResolveCapability(Capability, Outcome)
    else
      RejectCapability(Capability, Outcome);
  except
    on EJSExecutionInterrupted do
      raise;
    on Exception do
      ;
  end;
end;

procedure TJSPromiseOperations.RunThenable(const Job: TJSPromiseJob);
begin
  var Resolve: IJSFunction;
  var Reject: IJSFunction;
  CreateResolvingFunctions(Job.Promise, Resolve, Reject);

  var ThenFunction: IJSFunction;
  TJSBinarySupport.AsFunction(Job.ThenFunction, ThenFunction);

  var Outcome: TJSValue;
  const Args: TArray<TJSValue> = [TJSValue.CreateObject(Resolve), TJSValue.CreateObject(Reject)];
  const IsNormal = TryCall(ThenFunction, Args, Job.Thenable.ToObject, Outcome);
  if not IsNormal then
    FInterpreter.CallFunction(Reject, [Outcome], nil);
end;

procedure TJSPromiseOperations.MarkJob(const Job: TJSPromiseJob; const MarkValue: TProc<TJSValue>);
begin
  MarkValue(Job.Reaction.Capability.Promise);
  MarkValue(Job.Reaction.Capability.Resolve);
  MarkValue(Job.Reaction.Capability.Reject);
  MarkValue(Job.Reaction.OnFulfilled);
  MarkValue(Job.Reaction.OnRejected);

  if Assigned(Job.Reaction.Continuation) then
    Job.Reaction.Continuation.EnumerateReferences(MarkValue);

  MarkValue(Job.Argument);
  MarkValue(Job.Thenable);
  MarkValue(Job.ThenFunction);

  if Assigned(Job.Promise) then
    MarkValue(TJSValue.CreateObject(Job.Promise));
end;

procedure TJSPromiseOperations.MarkRoots(const MarkValue: TProc<TJSValue>);
begin
  FRegistry.EnumerateValues(MarkValue);

  for var Job in FJobs do
  begin
    MarkJob(Job, MarkValue);
  end;
end;

end.
