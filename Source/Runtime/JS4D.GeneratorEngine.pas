unit JS4D.GeneratorEngine;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.AST,
  JS4D.Errors,
  JS4D.IteratorProtocol,
  JS4D.ObjectOperations,
  JS4D.GeneratorObjects,
  JS4D.ControlFlow,
  JS4D.StatementFrame,
  JS4D.ResumableExecution,
  JS4D.PropertyNames,
  JS4D.Interpreter;

type
  TJSGeneratorEngine = class(TJSResumableExecution)
  private
    FInterpreter: TJSInterpreter;

    function GeneratorPrototypeFor(const Func: IJSFunction): IJSObject;
    function CreateSuspendedBody(const Func: IJSFunction): IJSGenerator;
    procedure RejectAsyncStart(const ResultPromise: IJSObject; const Error: Exception);
    procedure RaiseSuspension(const Node: TJSASTNode; const Value: TJSValue; const IsResult: Boolean);
    procedure ApplyKindPrototype(const Func: IJSFunction; const KindPrototype: IJSObject);
    function CreateIterationResult(const Value: TJSValue; const IsDone: Boolean): TJSValue;
    function ResumeUnstartedGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                      const Value: TJSValue): TJSValue;
    function ResumeCompletedGenerator(const Mode: TJSResumeMode; const Value: TJSValue): TJSValue;
    function RunGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                          const Value: TJSValue): TJSValue;
    function AdvanceGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                              const Value: TJSValue): TJSBodyResult;
    function RunGeneratorBody(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                              const Value: TJSValue; const IsResuming: Boolean): TJSBodyResult;
    function SuspendGenerator(const Generator: TJSGeneratorObject; const Signal: TJSYieldSignal): TJSBodyResult;
    procedure EnterGeneratorContext(const Generator: TJSGeneratorObject);
    procedure DepositResumption(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                const Value: TJSValue);
    function ConsumeResumption(const Entry: TJSResumption): TJSValue;
    function VisitYieldDelegate(const Node: TJSYieldExpression): TJSValue;
    function DelegateStep(const Node: TJSYieldExpression; const Frame: TJSStatementFrame): TJSValue;
    procedure OpenDelegate(const Iterable: TJSValue; const Frame: TJSStatementFrame);
    function FindDelegateMethod(const Frame: TJSStatementFrame; const Name: string): IJSFunction;
    function DelegateResultObject(const Frame: TJSStatementFrame): IJSObject;
    function CallDelegateNext(const Frame: TJSStatementFrame): TJSValue;
    function CallDelegateThrow(const Frame: TJSStatementFrame): TJSValue;
    function CallDelegateReturn(const Frame: TJSStatementFrame): TJSValue;
    procedure CloseDelegate(const Frame: TJSStatementFrame);
    procedure RunRemembering(const Action: TProc);
    function EvaluateRemembering(const Node: TJSExpression): TJSValue;
    function ResumableExec(const Node: TJSStatement): TJSValue;
    procedure EnterFrameScope(const Frame: TJSStatementFrame; const ScopeInfo: TJSScopeInfo; const NeedsScope: Boolean);
    function ResumableStatement(const Node: TJSStatement): TJSValue;
    function ResumableReturn(const Node: TJSReturnStatement): TJSValue;
    function ResumableThrow(const Node: TJSThrowStatement): TJSValue;
    function ResumableBlock(const Node: TJSBlockStatement): TJSValue;
    function ResumableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
    function ResumableIf(const Node: TJSIfStatement): TJSValue;
    function ResumableWhile(const Node: TJSWhileStatement): TJSValue;
    function ResumableDoWhile(const Node: TJSDoWhileStatement): TJSValue;
    function ResumableFor(const Node: TJSForStatement): TJSValue;
    procedure RunForHead(const Node: TJSForStatement; const Frame: TJSStatementFrame; const IsLexical: Boolean);
    function PassesForTest(const Node: TJSForStatement; const Frame: TJSStatementFrame): Boolean;
    procedure CopyForScope(const Node: TJSForStatement; const Frame: TJSStatementFrame; const IsLexical: Boolean);
    function RunForBody(const Node: TJSForStatement; const Frame: TJSStatementFrame;
                        const IsLexical: Boolean): TJSValue;
    function EvaluateLoopSubject(const Node: TJSForInStatement; const Frame: TJSStatementFrame): TJSValue;
    procedure BindLoopVariable(const Node: TJSForInStatement; const Frame: TJSStatementFrame);
    function RunLoopIteration(const Body: TJSStatement; const Frame: TJSStatementFrame;
                              const Previous: TJSValue): TJSIterationResult;
    function ResumableForIn(const Node: TJSForInStatement): TJSValue;
    function RunForInIterations(const Node: TJSForInStatement; const Frame: TJSStatementFrame): TJSValue;
    function ResumableForOf(const Node: TJSForOfStatement): TJSValue;
    function RunForOfIterations(const Node: TJSForOfStatement; const Frame: TJSStatementFrame): TJSValue;
    function RunForOfLoop(const Node: TJSForOfStatement; const Frame: TJSStatementFrame): TJSValue;
    function ResumableSwitch(const Node: TJSSwitchStatement): TJSValue;
    procedure SelectSwitchCase(const Node: TJSSwitchStatement; const Frame: TJSStatementFrame);
    function RunSwitchCases(const Node: TJSSwitchStatement; const Frame: TJSStatementFrame): TJSValue;
    function ResumableLabeled(const Node: TJSLabeledStatement): TJSValue;
    function ResumableWith(const Node: TJSWithStatement): TJSValue;
    function ResumableTry(const Node: TJSTryStatement): TJSValue;
    function RunTryBlock(const Node: TJSTryStatement; const Frame: TJSStatementFrame): TJSValue;
    procedure RunCatchClause(const Node: TJSTryStatement; const Frame: TJSStatementFrame);
    procedure BindCatchParameter(const Handler: TJSCatchClause; const Frame: TJSStatementFrame);
    procedure RunFinalizerBlock(const Node: TJSTryStatement; const Frame: TJSStatementFrame);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure AttachGeneratorPrototype(const Func: IJSFunction); override;
    function CaptureExecutionState: TJSExecutionState; override;
    procedure ConvertToAsyncFunction(const Func: IJSFunction); override;
    procedure ConvertToGeneratorFunction(const Func: IJSFunction); override;
    function CreateGeneratorObject(const Func: IJSFunction): TJSValue; override;
    procedure DefinePrototypeProperty(const Func: IJSFunction; const PrototypeObject: IJSObject;
                                      const IsWritable: Boolean); override;
    function FrameFor(const Node: TJSASTNode): TJSStatementFrame; override;
    procedure InitializeDeclarator(const Node: TJSVariableDeclaration; const Declarator: TJSVariableDeclarator); override;
    procedure RestoreExecutionState(const State: TJSExecutionState); override;
    function StartAsyncFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                const Body: TJSBlockStatement): TJSValue; override;
    function VisitAwait(const Node: TJSAwaitExpression): TJSValue; override;
    function VisitRemembered(const Node: TJSASTNode): TJSValue; override;
    function VisitYield(const Node: TJSYieldExpression): TJSValue; override;
    function ResumeGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                             const Value: TJSValue): TJSValue; override;
    function AdvanceBody(const Body: IJSGenerator; const Mode: TJSResumeMode; const Value: TJSValue): TJSBodyResult; override;
  end;

implementation

const
  GENERATOR_RUNNING = 'Generator is already running';
  UNSUPPORTED_GENERATOR_STATE = 'Unsupported generator state: %d';
  UNSUPPORTED_BODY_OUTCOME = 'Unsupported body outcome: %d';
  ASYNC_UNAVAILABLE = 'Async functions need the Promise built-ins';
  UNSUPPORTED_RESUME_MODE = 'Unsupported resume mode: %d';
  DELEGATE_NOT_ITERABLE = 'The operand of yield* is not iterable';
  DELEGATE_METHOD_NOT_CALLABLE = 'The iterator''s %s method is not a function';
  DELEGATE_RESULT_NOT_AN_OBJECT = 'The result of an iterator method is not an object';
  DELEGATE_WITHOUT_THROW = 'The iterator does not provide a throw method';
  DELEGATE_THROW_PROPERTY = 'throw';
  DELEGATE_RETURN_PROPERTY = 'return';

{ TJSGeneratorEngine }

constructor TJSGeneratorEngine.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
end;

procedure TJSGeneratorEngine.AttachGeneratorPrototype(const Func: IJSFunction);
begin
  const PrototypeObject: IJSObject = TJSObject.Create;
  PrototypeObject.Prototype := FInterpreter.GeneratorPrototype;

  DefinePrototypeProperty(Func, PrototypeObject, True);
end;

procedure TJSGeneratorEngine.DefinePrototypeProperty(const Func: IJSFunction; const PrototypeObject: IJSObject;
                                                     const IsWritable: Boolean);
begin
  const PrototypeValue = TJSValue.CreateObject(PrototypeObject);
  var PrototypeDescriptor := TJSPropertyDescriptor.Create(PrototypeValue);
  PrototypeDescriptor.Writable := IsWritable;
  PrototypeDescriptor.Enumerable := False;
  PrototypeDescriptor.Configurable := False;
  Func.DefineProperty(PROTOTYPE_PROPERTY, PrototypeDescriptor);
end;

function TJSGeneratorEngine.GeneratorPrototypeFor(const Func: IJSFunction): IJSObject;
begin
  const PrototypeValue = Func.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsObject then
  begin
    Result := PrototypeValue.ToObject;
    Exit;
  end;

  Result := FInterpreter.GeneratorPrototype;
end;

function TJSGeneratorEngine.CreateGeneratorObject(const Func: IJSFunction): TJSValue;
begin
  const Suspended = CreateSuspendedBody(Func);
  Suspended.Prototype := GeneratorPrototypeFor(Func);

  Result := TJSValue.CreateObject(Suspended);
end;

function TJSGeneratorEngine.CreateSuspendedBody(const Func: IJSFunction): IJSGenerator;
begin
  const Generator = TJSGeneratorObject.Create(FInterpreter.Generators);
  Result := Generator;

  Generator.FunctionObject := Func;
  Generator.Scope := FInterpreter.CurrentScope;
  Generator.VarScope := FInterpreter.VarScope;
  Generator.ThisObject := FInterpreter.ThisValue;
  Generator.IsStrict := FInterpreter.StrictMode;
  Generator.Callee := FInterpreter.ActiveCallee;
  Generator.NewTarget := FInterpreter.ActiveNewTarget;
  Generator.Binding := FInterpreter.ActiveBinding;
end;

function TJSGeneratorEngine.StartAsyncFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                               const Body: TJSBlockStatement): TJSValue;
begin
  const Host = FInterpreter.AsyncHost;
  if not Assigned(Host) then
    raise TJSErrorFactory.TypeError(ASYNC_UNAVAILABLE);

  const ResultPromise = Host.CreateResult;
  Result := TJSValue.CreateObject(ResultPromise);

  var Suspended: IJSGenerator;
  try
    FInterpreter.BindFunctionParameters(Func, Args, Body);
    Suspended := CreateSuspendedBody(Func);
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      RejectAsyncStart(ResultPromise, Error);
      Exit;
    end;
  end;

  Host.Start(ResultPromise, Suspended);
end;

procedure TJSGeneratorEngine.RejectAsyncStart(const ResultPromise: IJSObject; const Error: Exception);
begin
  const Host = FInterpreter.AsyncHost;
  const Reason = FInterpreter.ExceptionToValue(Error);

  Host.Reject(ResultPromise, Reason);
end;

function TJSGeneratorEngine.VisitAwait(const Node: TJSAwaitExpression): TJSValue;
begin
  const Operand = FInterpreter.Visit(Node.Argument);

  RaiseSuspension(Node, Operand, False);
end;

procedure TJSGeneratorEngine.RaiseSuspension(const Node: TJSASTNode; const Value: TJSValue; const IsResult: Boolean);
begin
  const Active = FInterpreter.Generator;
  if Assigned(Active) then
    Active.IsSuspending := True;

  raise TJSYieldSignal.Create(Node, Value, IsResult);
end;

procedure TJSGeneratorEngine.ConvertToAsyncFunction(const Func: IJSFunction);
begin
  ApplyKindPrototype(Func, FInterpreter.AsyncFunctionPrototype);
end;

procedure TJSGeneratorEngine.ApplyKindPrototype(const Func: IJSFunction; const KindPrototype: IJSObject);
begin
  if Assigned(KindPrototype) then
    Func.Prototype := KindPrototype;

  Func.IsConstructor := False;
end;

function TJSGeneratorEngine.AdvanceBody(const Body: IJSGenerator; const Mode: TJSResumeMode;
                                        const Value: TJSValue): TJSBodyResult;
begin
  const BodyObject = Body as TObject;
  const Generator = BodyObject as TJSGeneratorObject;

  Result := AdvanceGenerator(Generator, Mode, Value);
end;

function TJSGeneratorEngine.CreateIterationResult(const Value: TJSValue; const IsDone: Boolean): TJSValue;
begin
  Result := TJSIteratorResults.CreateResult(FInterpreter.ObjectPrototype, Value, IsDone);
end;

function TJSGeneratorEngine.ResumeGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                            const Value: TJSValue): TJSValue;
begin
  case Generator.State of
    TJSGeneratorState.Executing:
      raise TJSErrorFactory.TypeError(GENERATOR_RUNNING);
    TJSGeneratorState.Completed:
      Result := ResumeCompletedGenerator(Mode, Value);
    TJSGeneratorState.SuspendedStart:
      Result := ResumeUnstartedGenerator(Generator, Mode, Value);
    TJSGeneratorState.SuspendedYield:
      Result := RunGenerator(Generator, Mode, Value);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_GENERATOR_STATE, [Ord(Generator.State)]);
  end;
end;

function TJSGeneratorEngine.ResumeUnstartedGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                                     const Value: TJSValue): TJSValue;
begin
  const EndsBeforeStarting = (Mode <> TJSResumeMode.Next);
  if EndsBeforeStarting then
  begin
    Generator.Finish;
    Result := ResumeCompletedGenerator(Mode, Value);
  end
  else
  begin
    Result := RunGenerator(Generator, Mode, Value);
  end;
end;

function TJSGeneratorEngine.ResumeCompletedGenerator(const Mode: TJSResumeMode; const Value: TJSValue): TJSValue;
begin
  case Mode of
    TJSResumeMode.Next:
      Result := CreateIterationResult(TJSValue.CreateUndefined, True);
    TJSResumeMode.Return:
      Result := CreateIterationResult(Value, True);
    TJSResumeMode.Throw:
      raise TJSThrowSignal.Create(Value);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_RESUME_MODE, [Ord(Mode)]);
  end;
end;

function TJSGeneratorEngine.RunGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                         const Value: TJSValue): TJSValue;
begin
  const Advanced = AdvanceGenerator(Generator, Mode, Value);

  case Advanced.Outcome of
    TJSBodyOutcome.Yielded   : Result := CreateIterationResult(Advanced.Value, False);
    TJSBodyOutcome.Delegated : Result := Advanced.Value;
    TJSBodyOutcome.Finished  : Result := CreateIterationResult(Advanced.Value, True);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_BODY_OUTCOME, [Ord(Advanced.Outcome)]);
  end;
end;

function TJSGeneratorEngine.CaptureExecutionState: TJSExecutionState;
begin
  Result.ThisValue := FInterpreter.ThisValue;
  Result.ThisPrimitive := FInterpreter.ThisPrimitive;
  Result.StrictMode := FInterpreter.StrictMode;
  Result.Scope := FInterpreter.CurrentScope;
  Result.VarScope := FInterpreter.VarScope;
  Result.Context := FInterpreter.Context;
  Result.Generator := FInterpreter.Generator;
end;

procedure TJSGeneratorEngine.RestoreExecutionState(const State: TJSExecutionState);
begin
  FInterpreter.Generator := State.Generator;
  FInterpreter.CurrentScope := State.Scope;
  FInterpreter.VarScope := State.VarScope;
  FInterpreter.ThisValue := State.ThisValue;
  FInterpreter.ThisPrimitive := State.ThisPrimitive;
  FInterpreter.StrictMode := State.StrictMode;
  FInterpreter.Context := State.Context;
end;

function TJSGeneratorEngine.AdvanceGenerator(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                             const Value: TJSValue): TJSBodyResult;
begin
  FInterpreter.EnsureCallDepthAvailable;

  const SavedState = CaptureExecutionState;
  const IsResuming = (Generator.State = TJSGeneratorState.SuspendedYield);

  FInterpreter.ThisValue := Generator.ThisObject;
  FInterpreter.StrictMode := Generator.IsStrict;
  FInterpreter.ThisPrimitive := FInterpreter.StrictPrimitiveThis(FInterpreter.ThisValue, FInterpreter.StrictMode);
  FInterpreter.CurrentScope := Generator.Scope;
  FInterpreter.VarScope := Generator.VarScope;
  EnterGeneratorContext(Generator);
  FInterpreter.Generator := Generator;
  Generator.State := TJSGeneratorState.Executing;
  FInterpreter.CallDepth := FInterpreter.CallDepth + 1;
  try
    Result := RunGeneratorBody(Generator, Mode, Value, IsResuming);
  finally
    FInterpreter.CallDepth := FInterpreter.CallDepth - 1;
    RestoreExecutionState(SavedState);
  end;
end;

function TJSGeneratorEngine.RunGeneratorBody(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                             const Value: TJSValue; const IsResuming: Boolean): TJSBodyResult;
begin
  try
    if IsResuming then
      DepositResumption(Generator, Mode, Value);

    ResumableExec(TJSBlockStatement(Generator.FunctionObject.BodyNode));

    Generator.Finish;
    Result.Outcome := TJSBodyOutcome.Finished;
    Result.Value := TJSValue.CreateUndefined;
  except
    on Signal: TJSYieldSignal do
    begin
      Result := SuspendGenerator(Generator, Signal);
    end;
    on Signal: TJSReturnSignal do
    begin
      Generator.Finish;
      Result.Outcome := TJSBodyOutcome.Finished;
      Result.Value := Signal.Value;
    end;
    on Exception do
    begin
      Generator.Finish;
      raise;
    end;
  end;
end;

function TJSGeneratorEngine.SuspendGenerator(const Generator: TJSGeneratorObject;
                                             const Signal: TJSYieldSignal): TJSBodyResult;
begin
  Generator.IsSuspending := False;
  Generator.State := TJSGeneratorState.SuspendedYield;
  Generator.SuspendedAt := Signal.Node;

  Result.Value := Signal.Value;
  if Signal.IsResult then
  begin
    Result.Outcome := TJSBodyOutcome.Delegated;
  end
  else
  begin
    Result.Outcome := TJSBodyOutcome.Yielded;
  end;
end;

procedure TJSGeneratorEngine.EnterGeneratorContext(const Generator: TJSGeneratorObject);
begin
  const HasContext = Assigned(Generator.Callee) or Assigned(Generator.NewTarget) or Assigned(Generator.Binding);
  if HasContext then
  begin
    FInterpreter.SetContext(Generator.Callee, Generator.NewTarget, Generator.Binding);
  end
  else
  begin
    FInterpreter.Context := Default(TJSCallContext);
  end;
end;

procedure TJSGeneratorEngine.DepositResumption(const Generator: TJSGeneratorObject; const Mode: TJSResumeMode;
                                               const Value: TJSValue);
begin
  var Resumption: TJSResumption;
  Resumption.Mode := Mode;
  Resumption.Value := Value;

  const Node = Generator.SuspendedAt;
  const IsDelegate = (Node is TJSYieldExpression) and TJSYieldExpression(Node).IsDelegate;
  if not IsDelegate then
  begin
    Generator.AddResumption(Node, Resumption);
    Exit;
  end;

  const Frame = Generator.FindFrame(Node);
  if Assigned(Frame) then
    TJSStatementFrame(Frame).Received := Resumption;
end;

function TJSGeneratorEngine.VisitRemembered(const Node: TJSASTNode): TJSValue;
begin
  const Active = FInterpreter.Generator;
  var Entry: TJSResumption;
  if Active.TryFindResumption(Node, Entry) then
  begin
    Result := ConsumeResumption(Entry);
    Exit;
  end;

  FInterpreter.BypassNode := Node;
  Result := FInterpreter.Visit(Node);

  Entry.Mode := TJSResumeMode.Next;
  Entry.Value := Result;
  Active.AddResumption(Node, Entry);
end;

function TJSGeneratorEngine.ConsumeResumption(const Entry: TJSResumption): TJSValue;
begin
  case Entry.Mode of
    TJSResumeMode.Next:
      Result := Entry.Value;
    TJSResumeMode.Throw:
      raise TJSThrowSignal.Create(Entry.Value);
    TJSResumeMode.Return:
      raise TJSReturnSignal.Create(Entry.Value);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_RESUME_MODE, [Ord(Entry.Mode)]);
  end;
end;

function TJSGeneratorEngine.VisitYield(const Node: TJSYieldExpression): TJSValue;
begin
  if Node.IsDelegate then
  begin
    Result := VisitYieldDelegate(Node);
    Exit;
  end;

  var Operand := TJSValue.CreateUndefined;
  if Assigned(Node.Argument) then
    Operand := FInterpreter.Visit(Node.Argument);

  RaiseSuspension(Node, Operand, False);
end;

function TJSGeneratorEngine.VisitYieldDelegate(const Node: TJSYieldExpression): TJSValue;
begin
  const Frame = FrameFor(Node);

  try
    Result := DelegateStep(Node, Frame);
  finally
    const Active = FInterpreter.Generator;
    Active.ReleaseFrame(Node);
  end;
end;

function TJSGeneratorEngine.DelegateStep(const Node: TJSYieldExpression; const Frame: TJSStatementFrame): TJSValue;
begin
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    const Iterable = FInterpreter.Visit(Node.Argument);
    OpenDelegate(Iterable, Frame);
    Frame.Received.Mode := TJSResumeMode.Next;
    Frame.Received.Value := TJSValue.CreateUndefined;
    Frame.MoveTo(TJSFrameStage.Delegating);
  end;

  const ResultObject = DelegateResultObject(Frame);
  const IsDone = ResultObject.GetProperty(DONE_PROPERTY).ToBoolean;
  if IsDone then
  begin
    Result := ResultObject.GetProperty(VALUE_PROPERTY);
    const IsReturning = (Frame.Received.Mode = TJSResumeMode.Return);
    if IsReturning then
      raise TJSReturnSignal.Create(Result);

    Exit;
  end;

  const DelegatedResult = TJSValue.CreateObject(ResultObject);
  RaiseSuspension(Node, DelegatedResult, True);
end;

procedure TJSGeneratorEngine.OpenDelegate(const Iterable: TJSValue; const Frame: TJSStatementFrame);
begin
  var IteratorFunction: IJSFunction;
  if not FInterpreter.FindIteratorMethod(Iterable, IteratorFunction) then
    raise TJSErrorFactory.TypeError(DELEGATE_NOT_ITERABLE);

  const IteratorReceiver = FInterpreter.ThisObjectFor(IteratorFunction, Iterable);
  const IteratorValue = FInterpreter.CallFunction(IteratorFunction, nil, IteratorReceiver);
  if not IteratorValue.IsObject then
    raise TJSErrorFactory.TypeError(ITERATOR_NOT_AN_OBJECT);

  Frame.Iterator := IteratorValue.ToObject;
  Frame.NextMethod := Frame.Iterator.GetProperty(ITERATOR_NEXT_PROPERTY);
end;

function TJSGeneratorEngine.FindDelegateMethod(const Frame: TJSStatementFrame; const Name: string): IJSFunction;
begin
  Result := nil;

  const Method = Frame.Iterator.GetProperty(Name);
  if Method.IsNullOrUndefined then
    Exit;

  const MethodObject = Method.ToObject;
  const IsCallable = (Method.IsFunction and Supports(MethodObject, IJSFunction, Result));
  if not IsCallable then
  begin
    const Message = Format(DELEGATE_METHOD_NOT_CALLABLE, [Name]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSGeneratorEngine.DelegateResultObject(const Frame: TJSStatementFrame): IJSObject;
begin
  var Outcome: TJSValue;

  case Frame.Received.Mode of
    TJSResumeMode.Next:
      Outcome := CallDelegateNext(Frame);
    TJSResumeMode.Throw:
      Outcome := CallDelegateThrow(Frame);
    TJSResumeMode.Return:
      Outcome := CallDelegateReturn(Frame);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_RESUME_MODE, [Ord(Frame.Received.Mode)]);
  end;

  if not Outcome.IsObject then
    raise TJSErrorFactory.TypeError(DELEGATE_RESULT_NOT_AN_OBJECT);

  Result := Outcome.ToObject;
end;

function TJSGeneratorEngine.CallDelegateNext(const Frame: TJSStatementFrame): TJSValue;
begin
  var NextFunction: IJSFunction;
  const NextObject = Frame.NextMethod.ToObject;
  const IsCallable = (Frame.NextMethod.IsFunction and Supports(NextObject, IJSFunction, NextFunction));
  if not IsCallable then
  begin
    const Message = Format(DELEGATE_METHOD_NOT_CALLABLE, [ITERATOR_NEXT_PROPERTY]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := FInterpreter.CallFunction(NextFunction, [Frame.Received.Value], Frame.Iterator);
end;

function TJSGeneratorEngine.CallDelegateThrow(const Frame: TJSStatementFrame): TJSValue;
begin
  const ThrowMethod = FindDelegateMethod(Frame, DELEGATE_THROW_PROPERTY);
  if Assigned(ThrowMethod) then
  begin
    Result := FInterpreter.CallFunction(ThrowMethod, [Frame.Received.Value], Frame.Iterator);
    Exit;
  end;

  CloseDelegate(Frame);
  raise TJSErrorFactory.TypeError(DELEGATE_WITHOUT_THROW);
end;

function TJSGeneratorEngine.CallDelegateReturn(const Frame: TJSStatementFrame): TJSValue;
begin
  const ReturnMethod = FindDelegateMethod(Frame, DELEGATE_RETURN_PROPERTY);
  if not Assigned(ReturnMethod) then
    raise TJSReturnSignal.Create(Frame.Received.Value);

  Result := FInterpreter.CallFunction(ReturnMethod, [Frame.Received.Value], Frame.Iterator);
end;

procedure TJSGeneratorEngine.CloseDelegate(const Frame: TJSStatementFrame);
begin
  const ReturnMethod = FindDelegateMethod(Frame, DELEGATE_RETURN_PROPERTY);
  if not Assigned(ReturnMethod) then
    Exit;

  const Outcome = FInterpreter.CallFunction(ReturnMethod, nil, Frame.Iterator);
  if not Outcome.IsObject then
    raise TJSErrorFactory.TypeError(DELEGATE_RESULT_NOT_AN_OBJECT);
end;

function TJSGeneratorEngine.FrameFor(const Node: TJSASTNode): TJSStatementFrame;
begin
  const Active = FInterpreter.Generator;
  const Existing = Active.FindFrame(Node);
  if Assigned(Existing) then
  begin
    Result := TJSStatementFrame(Existing);
    Exit;
  end;

  Result := TJSStatementFrame.Create;
  Active.AddFrame(Node, Result);
end;

procedure TJSGeneratorEngine.RunRemembering(const Action: TProc);
begin
  try
    Action;
  finally
    const Active = FInterpreter.Generator;
    Active.ReleaseResumptions;
  end;
end;

function TJSGeneratorEngine.EvaluateRemembering(const Node: TJSExpression): TJSValue;
begin
  const NeedsResumption = (Assigned(Node) and Node.ContainsSuspension);
  if not NeedsResumption then
  begin
    Result := FInterpreter.Visit(Node);
    Exit;
  end;

  var Evaluated := TJSValue.CreateUndefined;
  RunRemembering(
    procedure
    begin
      Evaluated := FInterpreter.Visit(Node);
    end);

  Result := Evaluated;
end;

function TJSGeneratorEngine.ResumableExec(const Node: TJSStatement): TJSValue;
begin
  const NeedsResumption = (Assigned(Node) and Node.ContainsSuspension);
  if not NeedsResumption then
  begin
    Result := FInterpreter.ExecuteStatement(Node);
    Exit;
  end;

  FInterpreter.ConsumeStep;

  try
    Result := ResumableStatement(Node);
  finally
    const Active = FInterpreter.Generator;
    Active.ReleaseFrame(Node);
  end;
end;

procedure TJSGeneratorEngine.EnterFrameScope(const Frame: TJSStatementFrame; const ScopeInfo: TJSScopeInfo;
                                             const NeedsScope: Boolean);
begin
  Frame.OuterScope := FInterpreter.CurrentScope;
  if not NeedsScope then
    Exit;

  FInterpreter.EnterLexicalScope(ScopeInfo);
  Frame.Scope := FInterpreter.CurrentScope;
end;

function TJSGeneratorEngine.ResumableStatement(const Node: TJSStatement): TJSValue;
begin
  case Node.NodeType of
    TJSASTNodeType.BlockStatement:
      Result := ResumableBlock(TJSBlockStatement(Node));
    TJSASTNodeType.VariableDeclaration:
      Result := ResumableDeclaration(TJSVariableDeclaration(Node));
    TJSASTNodeType.ExpressionStatement:
      Result := EvaluateRemembering(TJSExpressionStatement(Node).Expression);
    TJSASTNodeType.IfStatement:
      Result := ResumableIf(TJSIfStatement(Node));
    TJSASTNodeType.WhileStatement:
      Result := ResumableWhile(TJSWhileStatement(Node));
    TJSASTNodeType.DoWhileStatement:
      Result := ResumableDoWhile(TJSDoWhileStatement(Node));
    TJSASTNodeType.ForStatement:
      Result := ResumableFor(TJSForStatement(Node));
    TJSASTNodeType.ForInStatement:
      Result := ResumableForIn(TJSForInStatement(Node));
    TJSASTNodeType.ForOfStatement:
      Result := ResumableForOf(TJSForOfStatement(Node));
    TJSASTNodeType.ReturnStatement:
      Result := ResumableReturn(TJSReturnStatement(Node));
    TJSASTNodeType.ThrowStatement:
      Result := ResumableThrow(TJSThrowStatement(Node));
    TJSASTNodeType.SwitchStatement:
      Result := ResumableSwitch(TJSSwitchStatement(Node));
    TJSASTNodeType.TryStatement:
      Result := ResumableTry(TJSTryStatement(Node));
    TJSASTNodeType.LabeledStatement:
      Result := ResumableLabeled(TJSLabeledStatement(Node));
    TJSASTNodeType.WithStatement:
      Result := ResumableWith(TJSWithStatement(Node));
  else
    Result := FInterpreter.ExecuteStatement(Node);
  end;
end;

function TJSGeneratorEngine.ResumableReturn(const Node: TJSReturnStatement): TJSValue;
begin
  var ReturnValue := TJSValue.CreateUndefined;
  if Assigned(Node.Argument) then
    ReturnValue := EvaluateRemembering(Node.Argument);

  raise TJSReturnSignal.Create(ReturnValue);
end;

function TJSGeneratorEngine.ResumableThrow(const Node: TJSThrowStatement): TJSValue;
begin
  const ThrownValue = EvaluateRemembering(Node.Argument);

  raise TJSThrowSignal.Create(ThrownValue);
end;

function TJSGeneratorEngine.ResumableBlock(const Node: TJSBlockStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  const NeedsScope = Assigned(Node.ScopeInfo) and (not Node.IsFunctionBody);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.MoveTo(TJSFrameStage.BlockRunning);
    EnterFrameScope(Frame, Node.ScopeInfo, NeedsScope);
  end
  else if NeedsScope then
  begin
    FInterpreter.CurrentScope := Frame.Scope;
  end;

  try
    while Frame.Index < Node.Body.Count do
    begin
      Result := ResumableExec(Node.Body[Frame.Index]);
      Inc(Frame.Index);
    end;
  finally
    if NeedsScope then
      FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

function TJSGeneratorEngine.ResumableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  while Frame.Index < Node.Declarations.Count do
  begin
    const Declarator = Node.Declarations[Frame.Index];

    if Declarator.ContainsSuspension then
    begin
      RunRemembering(
        procedure
        begin
          InitializeDeclarator(Node, Declarator);
        end);
    end
    else
    begin
      InitializeDeclarator(Node, Declarator);
    end;

    Inc(Frame.Index);
  end;
end;

procedure TJSGeneratorEngine.InitializeDeclarator(const Node: TJSVariableDeclaration;
                                                  const Declarator: TJSVariableDeclarator);
begin
  const IsLexical = (Node.Kind <> TJSDeclarationKind.Var_);

  if Assigned(Declarator.Pattern) then
  begin
    if (not IsLexical) and (not Assigned(Declarator.Init)) then
      Exit;

    const BoundValue = FInterpreter.Visit(Declarator.Init);
    if IsLexical then
      FInterpreter.BindTarget(Declarator.Pattern, BoundValue, TJSBindingMode.Lexical)
    else
      FInterpreter.BindTarget(Declarator.Pattern, BoundValue, TJSBindingMode.Variable);

    Exit;
  end;

  if not IsLexical then
  begin
    if Assigned(Declarator.Init) then
    begin
      const InitialValue = FInterpreter.VisitNamed(Declarator.Init, Declarator.Id.Name);
      const Scope = FInterpreter.CurrentScope;
      Scope.SetVariable(Declarator.Id.Name, InitialValue);
    end;

    Exit;
  end;

  var InitialValue := TJSValue.CreateUndefined;
  if Assigned(Declarator.Init) then
    InitialValue := FInterpreter.VisitNamed(Declarator.Init, Declarator.Id.Name);

  const LexicalScope = FInterpreter.CurrentScope;
  LexicalScope.InitializeLexical(Declarator.Id.Name, InitialValue);
end;

function TJSGeneratorEngine.ResumableIf(const Node: TJSIfStatement): TJSValue;
begin
  const Frame = FrameFor(Node);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    const TestValue = EvaluateRemembering(Node.Test);
    if TestValue.ToBoolean then
      Frame.MoveTo(TJSFrameStage.IfConsequent)
    else
      Frame.MoveTo(TJSFrameStage.IfAlternate);
  end;

  if Frame.IsAt(TJSFrameStage.IfConsequent) then
  begin
    Result := ResumableExec(Node.Consequent);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
  if Assigned(Node.Alternate) then
    Result := ResumableExec(Node.Alternate);
end;

function TJSGeneratorEngine.ResumableWhile(const Node: TJSWhileStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Labels := FInterpreter.TakeLoopLabels;
    Frame.MoveTo(TJSFrameStage.WhileTesting);
  end;

  while True do
  begin
    if Frame.IsAt(TJSFrameStage.WhileTesting) then
    begin
      const TestValue = EvaluateRemembering(Node.Test);
      if not TestValue.ToBoolean then
        Break;

      Frame.MoveTo(TJSFrameStage.WhileBody);
    end;

    const Iteration = RunLoopIteration(Node.Body, Frame, Result);
    Result := Iteration.Value;
    if not Iteration.KeepLooping then
      Break;

    Frame.MoveTo(TJSFrameStage.WhileTesting);
  end;
end;

function TJSGeneratorEngine.ResumableDoWhile(const Node: TJSDoWhileStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Labels := FInterpreter.TakeLoopLabels;
    Frame.MoveTo(TJSFrameStage.DoWhileBody);
  end;

  while True do
  begin
    if Frame.IsAt(TJSFrameStage.DoWhileBody) then
    begin
      const Iteration = RunLoopIteration(Node.Body, Frame, Result);
      Result := Iteration.Value;
      if not Iteration.KeepLooping then
        Break;

      Frame.MoveTo(TJSFrameStage.DoWhileTesting);
    end;

    const TestValue = EvaluateRemembering(Node.Test);
    if not TestValue.ToBoolean then
      Break;

    Frame.MoveTo(TJSFrameStage.DoWhileBody);
  end;
end;

function TJSGeneratorEngine.ResumableFor(const Node: TJSForStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  const IsLexical = FInterpreter.IsLexicalDeclaration(Node.Init);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Labels := FInterpreter.TakeLoopLabels;
    Frame.OuterScope := FInterpreter.CurrentScope;
    Frame.MoveTo(TJSFrameStage.ForHead);

    if IsLexical then
    begin
      FInterpreter.EnterLoopScope(Node.MayCaptureScope, TJSVariableDeclaration(Node.Init));
      Frame.Scope := FInterpreter.CurrentScope;
    end;
  end
  else if IsLexical then
  begin
    FInterpreter.CurrentScope := Frame.Scope;
  end;

  try
    RunForHead(Node, Frame, IsLexical);
    Result := RunForBody(Node, Frame, IsLexical);
  finally
    if IsLexical then
      FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

procedure TJSGeneratorEngine.RunForHead(const Node: TJSForStatement; const Frame: TJSStatementFrame;
                                        const IsLexical: Boolean);
begin
  if (not Frame.IsAt(TJSFrameStage.ForHead)) then
    Exit;

  if Node.Init is TJSStatement then
    ResumableExec(TJSStatement(Node.Init))
  else if Node.Init is TJSExpression then
    EvaluateRemembering(TJSExpression(Node.Init));

  if IsLexical and Node.MayCaptureScope then
  begin
    FInterpreter.CopyIterationScope;
    Frame.Scope := FInterpreter.CurrentScope;
  end;

  Frame.MoveTo(TJSFrameStage.ForTesting);
end;

function TJSGeneratorEngine.RunForBody(const Node: TJSForStatement; const Frame: TJSStatementFrame;
                                       const IsLexical: Boolean): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  while True do
  begin
    if not PassesForTest(Node, Frame) then
      Break;

    if Frame.IsAt(TJSFrameStage.ForBody) then
    begin
      const Iteration = RunLoopIteration(Node.Body, Frame, Result);
      Result := Iteration.Value;
      if not Iteration.KeepLooping then
        Break;

      Frame.MoveTo(TJSFrameStage.ForCopyingScope);
    end;

    CopyForScope(Node, Frame, IsLexical);

    if Assigned(Node.Update) then
      EvaluateRemembering(Node.Update);

    Frame.MoveTo(TJSFrameStage.ForTesting);
  end;
end;

function TJSGeneratorEngine.PassesForTest(const Node: TJSForStatement; const Frame: TJSStatementFrame): Boolean;
begin
  Result := True;
  if not Frame.IsAt(TJSFrameStage.ForTesting) then
    Exit;

  const HasTest = Assigned(Node.Test);
  if HasTest then
  begin
    const TestValue = EvaluateRemembering(Node.Test);
    Result := TestValue.ToBoolean;
  end;

  if Result then
    Frame.MoveTo(TJSFrameStage.ForBody);
end;

procedure TJSGeneratorEngine.CopyForScope(const Node: TJSForStatement; const Frame: TJSStatementFrame;
                                          const IsLexical: Boolean);
begin
  if not Frame.IsAt(TJSFrameStage.ForCopyingScope) then
    Exit;

  if IsLexical and Node.MayCaptureScope then
  begin
    FInterpreter.CopyIterationScope;
    Frame.Scope := FInterpreter.CurrentScope;
  end;

  Frame.MoveTo(TJSFrameStage.ForUpdating);
end;

function TJSGeneratorEngine.EvaluateLoopSubject(const Node: TJSForInStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  const IsLexical = FInterpreter.IsLexicalDeclaration(Node.Left);
  if not IsLexical then
  begin
    Result := EvaluateRemembering(TJSExpression(Node.Right));
    Exit;
  end;

  if not Assigned(Frame.Scope) then
  begin
    FInterpreter.CurrentScope := Frame.OuterScope;
    FInterpreter.EnterLoopScope(Node.MayCaptureScope, TJSVariableDeclaration(Node.Left));
    Frame.Scope := FInterpreter.CurrentScope;
  end
  else
  begin
    FInterpreter.CurrentScope := Frame.Scope;
  end;

  try
    Result := EvaluateRemembering(TJSExpression(Node.Right));
  finally
    FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

procedure TJSGeneratorEngine.BindLoopVariable(const Node: TJSForInStatement; const Frame: TJSStatementFrame);
begin
  if Node.Left.ContainsSuspension then
  begin
    RunRemembering(
      procedure
      begin
        FInterpreter.AssignLoopVariable(Node, Frame.OuterScope, Frame.Current);
      end);
  end
  else
  begin
    FInterpreter.AssignLoopVariable(Node, Frame.OuterScope, Frame.Current);
  end;

  Frame.Scope := FInterpreter.CurrentScope;
end;

function TJSGeneratorEngine.RunLoopIteration(const Body: TJSStatement; const Frame: TJSStatementFrame;
                                             const Previous: TJSValue): TJSIterationResult;
begin
  Result.KeepLooping := True;
  Result.Value := Previous;

  try
    Result.Value := ResumableExec(Body);
  except
    on Signal: TJSJumpSignal do
    begin
      const Jump = FInterpreter.ResolveLoopJump(Signal, Frame.Labels);
      const MustPropagate = (Jump = TJSLoopJump.Propagate);
      if MustPropagate then
        raise;

      Result.KeepLooping := (Jump <> TJSLoopJump.Stop);
    end;
  end;
end;

function TJSGeneratorEngine.ResumableForIn(const Node: TJSForInStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Labels := FInterpreter.TakeLoopLabels;
    Frame.OuterScope := FInterpreter.CurrentScope;
    Frame.MoveTo(TJSFrameStage.ForInSubject);
  end;

  try
    if Frame.IsAt(TJSFrameStage.ForInSubject) then
    begin
      Frame.Subject := EvaluateLoopSubject(Node, Frame);
      Frame.Scope := nil;
      Frame.MoveTo(TJSFrameStage.ForInKeys);
    end;

    if Frame.IsAt(TJSFrameStage.ForInKeys) then
    begin
      if Frame.Subject.IsNullOrUndefined then
        Exit;

      const Subject = FInterpreter.ToScopeObject(Frame.Subject);
      Frame.Subject := TJSValue.CreateObject(Subject);
      Frame.Keys := FInterpreter.CollectEnumerableKeys(Subject);
      Frame.MoveTo(TJSFrameStage.ForInNextKey);
    end;

    Result := RunForInIterations(Node, Frame);
  finally
    FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

function TJSGeneratorEngine.RunForInIterations(const Node: TJSForInStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Subject = Frame.Subject.ToObject;
  const IsProxy = TJSObjectOperations.IsProxy(Subject);

  while Frame.Index < Length(Frame.Keys) do
  begin
    if Frame.IsAt(TJSFrameStage.ForInNextKey) then
    begin
      const PropName = Frame.Keys[Frame.Index];
      const IsDeleted = (not IsProxy) and (not Subject.HasProperty(PropName));
      if IsDeleted then
      begin
        Inc(Frame.Index);
        Continue;
      end;

      FInterpreter.CurrentScope := Frame.OuterScope;
      Frame.Current := TJSValue.CreateString(PropName);
      BindLoopVariable(Node, Frame);
      Frame.MoveTo(TJSFrameStage.ForInBody);
    end
    else
    begin
      FInterpreter.CurrentScope := Frame.Scope;
    end;

    const Iteration = RunLoopIteration(Node.Body, Frame, TJSValue.CreateUndefined);
    Result := Iteration.Value;
    if not Iteration.KeepLooping then
      Break;

    Inc(Frame.Index);
    Frame.MoveTo(TJSFrameStage.ForInNextKey);
  end;
end;

function TJSGeneratorEngine.ResumableForOf(const Node: TJSForOfStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Labels := FInterpreter.TakeLoopLabels;
    Frame.OuterScope := FInterpreter.CurrentScope;
    Frame.MoveTo(TJSFrameStage.ForOfSubject);
  end;

  try
    if Frame.IsAt(TJSFrameStage.ForOfSubject) then
    begin
      Frame.Subject := EvaluateLoopSubject(Node, Frame);
      Frame.Scope := nil;
      Frame.MoveTo(TJSFrameStage.ForOfOpening);
    end;

    if Frame.IsAt(TJSFrameStage.ForOfOpening) then
    begin
      if not FInterpreter.TryOpenIterationSource(Frame.Subject, Frame.Source) then
        raise TJSErrorFactory.TypeError(NOT_ITERABLE_LOOP);

      Frame.MoveTo(TJSFrameStage.ForOfNextValue);
    end;

    Result := RunForOfIterations(Node, Frame);
  finally
    FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

function TJSGeneratorEngine.RunForOfIterations(const Node: TJSForOfStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  try
    Result := RunForOfLoop(Node, Frame);
  except
    on TJSYieldSignal do
      raise;
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      Frame.Source.CloseForException(Error);
      raise;
    end;
  end;
end;

function TJSGeneratorEngine.RunForOfLoop(const Node: TJSForOfStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  while True do
  begin
    if Frame.IsAt(TJSFrameStage.ForOfNextValue) then
    begin
      if not Frame.Source.HasNext then
        Break;

      FInterpreter.CurrentScope := Frame.OuterScope;
      Frame.Current := Frame.Source.Next;
      Frame.MoveTo(TJSFrameStage.ForOfBinding);
    end;

    if Frame.IsAt(TJSFrameStage.ForOfBinding) then
    begin
      BindLoopVariable(Node, Frame);
      Frame.MoveTo(TJSFrameStage.ForOfBody);
    end
    else
    begin
      FInterpreter.CurrentScope := Frame.Scope;
    end;

    const Iteration = RunLoopIteration(Node.Body, Frame, TJSValue.CreateUndefined);
    Result := Iteration.Value;
    if not Iteration.KeepLooping then
    begin
      Frame.Source.Close;
      Break;
    end;

    Frame.MoveTo(TJSFrameStage.ForOfNextValue);
  end;
end;

function TJSGeneratorEngine.ResumableSwitch(const Node: TJSSwitchStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  const HasScope = Assigned(Node.ScopeInfo);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.Subject := EvaluateRemembering(Node.Discriminant);
    Frame.DefaultCaseIndex := NO_CASE;
    Frame.MoveTo(TJSFrameStage.SwitchSelecting);
    EnterFrameScope(Frame, Node.ScopeInfo, HasScope);
  end
  else if HasScope then
  begin
    FInterpreter.CurrentScope := Frame.Scope;
  end;

  try
    if Frame.IsAt(TJSFrameStage.SwitchSelecting) then
      SelectSwitchCase(Node, Frame);

    if Frame.IsAt(TJSFrameStage.SwitchRunning) then
      Result := RunSwitchCases(Node, Frame);
  finally
    if HasScope then
      FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

procedure TJSGeneratorEngine.SelectSwitchCase(const Node: TJSSwitchStatement; const Frame: TJSStatementFrame);
begin
  while Frame.Index < Node.Cases.Count do
  begin
    const SwitchCase = Node.Cases[Frame.Index];

    if not Assigned(SwitchCase.Test) then
    begin
      Frame.DefaultCaseIndex := Frame.Index;
      Inc(Frame.Index);
      Continue;
    end;

    const TestValue = EvaluateRemembering(SwitchCase.Test);
    if FInterpreter.StrictEquals(Frame.Subject, TestValue) then
    begin
      Frame.MoveTo(TJSFrameStage.SwitchRunning);
      Exit;
    end;

    Inc(Frame.Index);
  end;

  const HasDefaultCase = (Frame.DefaultCaseIndex <> NO_CASE);
  if HasDefaultCase then
  begin
    Frame.Index := Frame.DefaultCaseIndex;
    Frame.MoveTo(TJSFrameStage.SwitchRunning);
  end
  else
  begin
    Frame.MoveTo(TJSFrameStage.SwitchSkipped);
  end;
end;

function TJSGeneratorEngine.RunSwitchCases(const Node: TJSSwitchStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    while Frame.Index < Node.Cases.Count do
    begin
      const Consequent = Node.Cases[Frame.Index].Consequent;

      while Frame.ConsequentIndex < Consequent.Count do
      begin
        Result := ResumableExec(Consequent[Frame.ConsequentIndex]);
        Inc(Frame.ConsequentIndex);
      end;

      Inc(Frame.Index);
      Frame.ConsequentIndex := 0;
    end;
  except
    on Signal: TJSBreakSignal do
    begin
      if Signal.IsLabelled then
        raise;
    end;
  end;
end;

function TJSGeneratorEngine.ResumableLabeled(const Node: TJSLabeledStatement): TJSValue;
begin
  const Frame = FrameFor(Node);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.MoveTo(TJSFrameStage.LabeledEntered);

    const BodyIsLoop = (Node.Body.NodeType in LABELED_LOOP_TYPES);
    if BodyIsLoop then
      FInterpreter.LoopLabels := FInterpreter.LoopLabels + [Node.LabelName]
    else
      FInterpreter.LoopLabels := nil;
  end;

  Result := TJSValue.CreateUndefined;
  try
    try
      Result := ResumableExec(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        const IsAddressedToOtherLabel = (Signal.TargetLabel <> Node.LabelName);
        if IsAddressedToOtherLabel then
          raise;
      end;
    end;
  finally
    FInterpreter.LoopLabels := nil;
  end;
end;

function TJSGeneratorEngine.ResumableWith(const Node: TJSWithStatement): TJSValue;
begin
  FInterpreter.EnsureWithAllowed(Node);

  const Frame = FrameFor(Node);

  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    const TargetValue = EvaluateRemembering(Node.Target);

    Frame.OuterScope := FInterpreter.CurrentScope;
    FInterpreter.EnterWithScope(TargetValue);
    Frame.Scope := FInterpreter.CurrentScope;
    Frame.MoveTo(TJSFrameStage.WithEntered);
  end
  else
  begin
    FInterpreter.CurrentScope := Frame.Scope;
  end;

  try
    Result := ResumableExec(Node.Body);
  finally
    FInterpreter.CurrentScope := Frame.OuterScope;
  end;
end;

function TJSGeneratorEngine.ResumableTry(const Node: TJSTryStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const Frame = FrameFor(Node);
  if Frame.IsAt(TJSFrameStage.Fresh) then
  begin
    Frame.OuterScope := FInterpreter.CurrentScope;
    Frame.MoveTo(TJSFrameStage.TryBlock);
  end;

  if Frame.IsAt(TJSFrameStage.TryBlock) then
    Result := RunTryBlock(Node, Frame);

  if Frame.IsAt(TJSFrameStage.TryCatch) then
    RunCatchClause(Node, Frame);

  if Frame.IsAt(TJSFrameStage.TryFinally) then
    RunFinalizerBlock(Node, Frame);
end;

function TJSGeneratorEngine.RunTryBlock(const Node: TJSTryStatement; const Frame: TJSStatementFrame): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    Result := ResumableExec(Node.Block);
    Frame.MoveTo(TJSFrameStage.TryFinally);
  except
    on TJSYieldSignal do
      raise;
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      FInterpreter.CurrentScope := Frame.OuterScope;

      const IsCatchable = Assigned(Node.Handler) and (not (Error is EJSControlFlowSignal));
      if IsCatchable then
      begin
        Frame.Thrown := FInterpreter.ExceptionToValue(Error);
        Frame.MoveTo(TJSFrameStage.TryCatch);
      end
      else
      begin
        Frame.Pending := AcquireExceptionObject as Exception;
        Frame.MoveTo(TJSFrameStage.TryFinally);
      end;
    end;
  end;
end;

procedure TJSGeneratorEngine.RunCatchClause(const Node: TJSTryStatement; const Frame: TJSStatementFrame);
begin
  try
    if not Frame.IsCatchBound then
    begin
      BindCatchParameter(Node.Handler, Frame);
      Frame.IsCatchBound := True;
    end
    else
    begin
      FInterpreter.CurrentScope := Frame.Scope;
    end;

    ResumableExec(Node.Handler.Body);
    FInterpreter.CurrentScope := Frame.OuterScope;
    Frame.MoveTo(TJSFrameStage.TryFinally);
  except
    on TJSYieldSignal do
      raise;
    on EJSExecutionInterrupted do
      raise;
    on Exception do
    begin
      FInterpreter.CurrentScope := Frame.OuterScope;
      Frame.Pending := AcquireExceptionObject as Exception;
      Frame.MoveTo(TJSFrameStage.TryFinally);
    end;
  end;
end;

procedure TJSGeneratorEngine.BindCatchParameter(const Handler: TJSCatchClause; const Frame: TJSStatementFrame);
begin
  FInterpreter.PushScope;
  Frame.Scope := FInterpreter.CurrentScope;

  FInterpreter.DeclareCatchBinding(Handler, Frame.Thrown);
end;

procedure TJSGeneratorEngine.RunFinalizerBlock(const Node: TJSTryStatement; const Frame: TJSStatementFrame);
begin
  if Assigned(Node.Finalizer) then
  begin
    FInterpreter.CurrentScope := Frame.OuterScope;

    try
      ResumableExec(Node.Finalizer);
    except
      on TJSYieldSignal do
        raise;
      else
      begin
        FreeAndNil(Frame.Pending);
        raise;
      end;
    end;
  end;

  if Assigned(Frame.Pending) then
  begin
    const Pending = Frame.Pending;
    Frame.Pending := nil;
    raise Pending;
  end;
end;

procedure TJSGeneratorEngine.ConvertToGeneratorFunction(const Func: IJSFunction);
begin
  ApplyKindPrototype(Func, FInterpreter.GeneratorFunctionPrototype);
end;

end.
