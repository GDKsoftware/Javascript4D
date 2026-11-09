unit JS4D.Interpreter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.StrUtils,
  System.SyncObjs,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.AST,
  JS4D.Errors,
  JS4D.Builtins,
  JS4D.ObjectScope,
  JS4D.GlobalScope,
  JS4D.PropertyDescriptors,
  JS4D.ArrayIteration,
  JS4D.Operators;

type
  TJSScope = class(TInterfacedObject, IJSScope)
  private
    FVariables: TDictionary<string, TJSValue>;
    FParent: IJSScope;

  protected
    function GetParent: IJSScope;

  public
    constructor Create(const Parent: IJSScope);
    destructor Destroy; override;

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;

    property Parent: IJSScope read GetParent;
  end;

  EJSControlFlowSignal = class(EAbort);

  TJSJumpSignal = class(EJSControlFlowSignal)
  private
    FTargetLabel: string;

  public
    constructor Create(const TargetLabel: string);

    function IsLabelled: Boolean;
    function AppliesTo(const OwnLabels: TArray<string>): Boolean;

    property TargetLabel: string read FTargetLabel;
  end;

  TJSBreakSignal = class(TJSJumpSignal);
  TJSContinueSignal = class(TJSJumpSignal);

  TJSReturnSignal = class(EJSControlFlowSignal)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

  TJSThrowSignal = class(Exception)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

  TJSProgramParser = reference to function(const Source: string; const IsStrictContext: Boolean): TJSProgram;

  TJSBoundFunction = record
    Target: IJSFunction;
    Arguments: TArray<TJSValue>;
  end;

  TJSMemberReference = record
    Base: TJSValue;
    Key: TJSValue;
    KeyText: string;
    HasKeyText: Boolean;
  end;

  TJSInterpreter = class(TJSCallHandler)
  private
    FGlobalScope: IJSScope;
    FCurrentScope: IJSScope;
    FThisValue: IJSObject;
    FStrictMode: Boolean;
    FGlobalObject: IJSObject;
    FObjectPrototype: IJSObject;
    FArrayPrototype: IJSObject;
    FFunctionPrototype: IJSObject;
    FThrowTypeError: IJSFunction;
    FRegExpPrototype: IJSObject;
    FStringPrototype: IJSObject;
    FNumberPrototype: IJSObject;
    FBooleanPrototype: IJSObject;
    FFunctionRegistry: TList<IJSFunction>;
    FScopeRegistry: TList<IJSScope>;
    FFunctionPrograms: TDictionary<Pointer, TObject>;
    FBoundFunctions: TDictionary<Pointer, TJSBoundFunction>;
    FCurrentProgram: TObject;
    FCancelRequested: Int64;
    FExecutionDepth: Integer;
    FStepBudget: Int64;
    FStepsCompleted: Int64;
    FStepSlice: Integer;
    FStepsUntilCheck: Integer;
    FLimits: TJSLimits;
    FCallDepth: Integer;
    FProgramParser: TJSProgramParser;
    FEvalFunction: IJSFunction;
    FDirectEvalCall: Boolean;
    FEvalVariableScope: IJSScope;
    FLoopLabels: TArray<string>;

    procedure SetFunctionPrototype(const Value: IJSObject);
    procedure PushScope;
    procedure PopScope;
    procedure RegisterScope(const Scope: IJSScope);
    procedure AttachPrototype(const Func: IJSFunction);
    function ReferencesArguments(const Func: IJSFunction): Boolean;
    function CreateArgumentsObject(const Args: TArray<TJSValue>; const Func: IJSFunction): IJSObject;
    function CreateThrowTypeError: IJSFunction;
    function CreateCalleeDescriptor: TJSPropertyDescriptor;
    procedure DetachProperties(const Func: IJSFunction);
    function IsInPrototypeChain(const Instance: IJSObject; const Constructor_: IJSFunction): Boolean;
    function CreateInstanceFor(const Constructor_: IJSFunction): IJSObject;
    function PrimitivePrototypeFor(const Value: TJSValue): IJSObject;

    procedure BeginExecution;
    procedure ConsumeStep; inline;
    procedure ReachStepCheckpoint;
    procedure OpenStepSlice;
    function IsCancelRequested: Boolean;
    function GetStepCount: Int64;
    function ExecuteStatement(const Node: TJSStatement): TJSValue;
    procedure GCMark(const Item: IInterface; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
    procedure GCMarkValue(const Value: TJSValue; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
    procedure GCMarkOwnProperties(const Obj: IJSObject; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
    function ErrorConstructorName(const Error: Exception): string;
    function CreateErrorValue(const Error: Exception): TJSValue;

    function Visit(const Node: TJSASTNode): TJSValue;

    function VisitProgram(const Node: TJSProgram): TJSValue;
    procedure HoistDeclarations(const Node: TJSASTNode);
    function VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
    function VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
    procedure DeclareFunction(const Node: TJSFunctionDeclaration);
    function VisitExpressionStatement(const Node: TJSExpressionStatement): TJSValue;
    function VisitIfStatement(const Node: TJSIfStatement): TJSValue;
    function VisitWhileStatement(const Node: TJSWhileStatement): TJSValue;
    function VisitDoWhileStatement(const Node: TJSDoWhileStatement): TJSValue;
    function VisitWithStatement(const Node: TJSWithStatement): TJSValue;
    procedure GuardStrictAssignmentTarget(const Node: TJSAssignmentExpression);
    procedure GuardGlobalFunctionDeclarations(const Node: TJSProgram);
    procedure GuardGlobalFunctionDeclaration(const Declaration: TJSFunctionDeclaration);
    function VisitLabeledStatement(const Node: TJSLabeledStatement): TJSValue;
    function TakeLoopLabels: TArray<string>;
    function ToScopeObject(const Value: TJSValue): IJSObject;
    function WithArrayPrototype(const Value: TJSValue): TJSValue;
    function WithObjectFor(const Callee: TJSExpression): IJSObject;
    function VisitForStatement(const Node: TJSForStatement): TJSValue;
    function VisitForInStatement(const Node: TJSForInStatement): TJSValue;
    function VisitReturnStatement(const Node: TJSReturnStatement): TJSValue;
    function VisitBreakStatement(const Node: TJSBreakStatement): TJSValue;
    function VisitContinueStatement(const Node: TJSContinueStatement): TJSValue;
    function VisitSwitchStatement(const Node: TJSSwitchStatement): TJSValue;
    function VisitThrowStatement(const Node: TJSThrowStatement): TJSValue;
    function RunProgramBody(const Node: TJSProgram): TJSValue;
    function EvaluateSource(const Source: string; const IsDirect: Boolean): TJSValue;
    function EvaluateProgram(const Program_: TJSProgram; const IsDirect: Boolean): TJSValue;
    function CreateEvalScope(const IsDirect: Boolean; const IsStrictSource: Boolean): IJSScope;
    function IsDirectEvalCall(const Callee: TJSExpression; const Func: IJSFunction): Boolean;
    function CallDirectEval(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
    function VisitTryStatement(const Node: TJSTryStatement): TJSValue;
    function VisitCatchClause(const Handler: TJSCatchClause; const Thrown: TJSValue): TJSValue;
    procedure RunFinalizer(const Node: TJSTryStatement);

    function VisitIdentifier(const Node: TJSIdentifier): TJSValue;
    function VisitLiteral(const Node: TJSLiteral): TJSValue;
    function VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
    function VisitObjectExpression(const Node: TJSObjectExpression): TJSValue;
    procedure DefineLiteralProperty(const Target: IJSObject; const Prop: TJSObjectProperty);
    procedure DefineLiteralAccessor(const Target: IJSObject; const Name: string; const Prop: TJSObjectProperty);
    function VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
    function VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
    function VisitDeleteExpression(const Node: TJSUnaryExpression): TJSValue;
    function DeleteMember(const Node: TJSUnaryExpression; const MemberExpr: TJSMemberExpression): TJSValue;
    function IsUndeclaredIdentifier(const Node: TJSExpression): Boolean;
    function DeleteIdentifier(const Name: string): Boolean;
    procedure DeclareBinding(const Name: string; const Value: TJSValue);
    function VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
    function VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
    function VisitAssignmentExpression(const Node: TJSAssignmentExpression): TJSValue;
    function AssignToIdentifier(const Node: TJSAssignmentExpression): TJSValue;
    function AssignToMember(const Node: TJSAssignmentExpression): TJSValue;
    function VisitUpdateExpression(const Node: TJSUpdateExpression): TJSValue;
    function UpdateIdentifier(const Node: TJSUpdateExpression): TJSValue;
    function UpdateMember(const Node: TJSUpdateExpression): TJSValue;
    function VisitConditionalExpression(const Node: TJSConditionalExpression): TJSValue;
    function VisitCallExpression(const Node: TJSCallExpression): TJSValue;
    function VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
    procedure RequireObjectCoercible(const Value: TJSValue; const PropName: string);
    function ResolveMemberReference(const Node: TJSMemberExpression): TJSMemberReference;
    function DescribeReferenceKey(const Reference: TJSMemberReference): string;
    function ToPropertyKey(const Key: TJSValue): string;
    procedure ResolveReferenceKey(var Reference: TJSMemberReference);
    function GetReferenceValue(var Reference: TJSMemberReference): TJSValue;
    procedure PutReferenceValue(var Reference: TJSMemberReference; const Value: TJSValue);
    function ReadMember(const Base: TJSValue; const PropName: string): TJSValue;
    procedure WriteMember(const Base: TJSValue; const PropName: string; const Value: TJSValue);
    procedure WriteArrayMember(const Target: IJSArray; const PropName: string; const Value: TJSValue;
                               out IsHandled: Boolean);
    function VisitNewExpression(const Node: TJSNewExpression): TJSValue;
    function Construct(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
    function VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
    function VisitThisExpression(const Node: TJSThisExpression): TJSValue;

    function ToText(const Value: TJSValue): string;
    function VisitText(const Node: TJSASTNode): string;
    function StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    procedure AssignArrayLength(const Target: IJSArray; const Value: TJSValue);
    procedure DeleteArrayElement(const Target: IJSObject; const PropName: string);
    function CreateCallbackExecutor(const MethodName: string; const Args: TArray<TJSValue>): TJSCallbackExecutor;
    function AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    function GetCalleeDescription(const Callee: TJSASTNode; const CalleeValue: TJSValue): string;
    function BoundLength(const Target: IJSFunction; const BoundArgumentCount: Integer): Integer;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Program_: TJSProgram): TJSValue;
    function CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue; override;
    procedure Cancel;
    procedure RegisterFunction(const Func: IJSFunction);
    procedure RegisterNativeFunction(const Name: string; const Func: TNativeFunction);
    procedure RegisterEval(const ProgramParser: TJSProgramParser);
    function CreateFunctionFromSource(const Source: string): TJSValue;
    function ThrowTypeErrorFunction: IJSFunction;
    procedure SetGlobalVariable(const Name: string; const Value: TJSValue);
    procedure SetGlobalConstant(const Name: string; const Value: TJSValue);
    function GetGlobalVariable(const Name: string): TJSValue;
    procedure CollectGarbage;
    function LivePrograms: TArray<TObject>;
    function ExecuteFunctionMethod(const Func: IJSFunction; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteArrayIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function WrapPrimitive(const Value: TJSValue): IJSObject;
    function ThisObjectFor(const Func: IJSFunction; const ThisValue: TJSValue): IJSObject;

    property GlobalScope: IJSScope read FGlobalScope;
    property ObjectPrototype: IJSObject read FObjectPrototype write FObjectPrototype;
    property ArrayPrototype: IJSObject read FArrayPrototype write FArrayPrototype;
    property FunctionPrototype: IJSObject read FFunctionPrototype write SetFunctionPrototype;
    property RegExpPrototype: IJSObject read FRegExpPrototype write FRegExpPrototype;
    property StringPrototype: IJSObject read FStringPrototype write FStringPrototype;
    property NumberPrototype: IJSObject read FNumberPrototype write FNumberPrototype;
    property BooleanPrototype: IJSObject read FBooleanPrototype write FBooleanPrototype;
    property Limits: TJSLimits read FLimits;
    property StepBudget: Int64 read FStepBudget write FStepBudget;
    property StepCount: Int64 read GetStepCount;
    property MaxCallDepth: Integer read FLimits.MaxCallDepth write FLimits.MaxCallDepth;
    property MaxStringLength: Integer read FLimits.MaxStringLength write FLimits.MaxStringLength;
    property MaxArrayLength: Integer read FLimits.MaxArrayLength write FLimits.MaxArrayLength;
  end;

implementation

const
  NULL_OR_UNDEFINED_TO_OBJECT = 'Cannot convert undefined or null to object';
  UNDEFINED_TYPE = 'undefined';
  OBJECT_TYPE = 'object';
  BOOLEAN_TYPE = 'boolean';
  NUMBER_TYPE = 'number';
  STRING_TYPE = 'string';
  FUNCTION_TYPE = 'function';
  LENGTH_PROPERTY = 'length';
  PROTOTYPE_PROPERTY = 'prototype';
  CONSTRUCTOR_PROPERTY = 'constructor';
  ARGUMENTS_NAME = 'arguments';
  READ_ONLY_LENGTH = 'Cannot assign to read only property ''length''';
  EVAL_NAME = 'eval';
  CANNOT_ACCESS_PROPERTY = 'Cannot access property ''%s'' of undefined or null';
  CANNOT_ASSIGN_PROPERTY = 'Cannot assign to property ''%s'' in strict mode';
  OBJECT_KEY_DESCRIPTION = '[object]';
  POISONED_PROPERTY = 'Restricted property cannot be accessed in strict mode';
  CALLEE_PROPERTY = 'callee';
  EMPTY_NAME = '';
  INVALID_FUNCTION_SOURCE = 'Invalid function parameters or body';
  METHOD_CALL = 'call';
  METHOD_APPLY = 'apply';
  METHOD_BIND = 'bind';

  CONSTRUCTOR_ERROR = 'Error';
  CONSTRUCTOR_TYPE_ERROR = 'TypeError';
  CONSTRUCTOR_RANGE_ERROR = 'RangeError';
  CONSTRUCTOR_REFERENCE_ERROR = 'ReferenceError';
  CONSTRUCTOR_SYNTAX_ERROR = 'SyntaxError';
  CONSTRUCTOR_URI_ERROR = 'URIError';
  CONSTRUCTOR_EVAL_ERROR = 'EvalError';
  CONSTRUCTOR_ARRAY = 'Array';
  CONSTRUCTOR_FUNCTION = 'Function';
  CONSTRUCTOR_REGEXP = 'RegExp';
  CONSTRUCTOR_DATE = 'Date';

  STEP_CHECK_INTERVAL = 1024;

{ TJSScope }

constructor TJSScope.Create(const Parent: IJSScope);
begin
  inherited Create;
  FVariables := TDictionary<string, TJSValue>.Create;
  FParent := Parent;
end;

function TJSScope.GetParent: IJSScope;
begin
  Result := FParent;
end;

destructor TJSScope.Destroy;
begin
  Clear;
  FVariables.Free;
  inherited;
end;

procedure TJSScope.Clear;
begin
  for var Pair in FVariables do
  begin
    if Pair.Value.IsFunction then
    begin
      var Func: IJSFunction;
      if Supports(Pair.Value.ToObject, IJSFunction, Func) then
        Func.ClosureScope := nil;
    end;
  end;

  FVariables.Clear;
  FParent := nil;
end;

function TJSScope.GetOwnVariables: TArray<TJSValue>;
begin
  SetLength(Result, FVariables.Count);
  var Index := 0;
  for var Pair in FVariables do
  begin
    Result[Index] := Pair.Value;
    Inc(Index);
  end;
end;

procedure TJSScope.ReleaseReferences;
begin
  FVariables.Clear;
  FParent := nil;
end;

function TJSScope.HasVariable(const Name: string): Boolean;
begin
  Result := FVariables.ContainsKey(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSScope.GetVariable(const Name: string): TJSValue;
begin
  if FVariables.TryGetValue(Name, Result) then
    Exit;

  if Assigned(FParent) then
    Exit(FParent.GetVariable(Name));

  Result := TJSValue.CreateUndefined;
end;

procedure TJSScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  const ResolvedScope = Resolve(Name);

  if Assigned(ResolvedScope) then
    ResolvedScope.DeclareVariable(Name, Value)
  else if Assigned(FParent) then
    FParent.SetVariable(Name, Value)
  else
    FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareDeletableVariable(const Name: string; const Value: TJSValue);
begin
  DeclareVariable(Name, Value);
end;

function TJSScope.DeleteVariable(const Name: string): Boolean;
begin
  Result := not FVariables.ContainsKey(Name);
end;

function TJSScope.Resolve(const Name: string): IJSScope;
begin
  if FVariables.ContainsKey(Name) then
    Exit(Self);

  if Assigned(FParent) then
    Exit(FParent.Resolve(Name));

  Result := nil;
end;

{ TJSJumpSignal }

constructor TJSJumpSignal.Create(const TargetLabel: string);
begin
  inherited Create('');
  FTargetLabel := TargetLabel;
end;

function TJSJumpSignal.IsLabelled: Boolean;
begin
  Result := not FTargetLabel.IsEmpty;
end;

function TJSJumpSignal.AppliesTo(const OwnLabels: TArray<string>): Boolean;
begin
  Result := (not IsLabelled) or MatchStr(FTargetLabel, OwnLabels);
end;

{ TJSReturnSignal }

constructor TJSReturnSignal.Create(const Value: TJSValue);
begin
  inherited Create('');
  FValue := Value;
end;

{ TJSThrowSignal }

constructor TJSThrowSignal.Create(const Value: TJSValue);
begin
  var Msg := Value.ToString;

  if Value.IsObject then
  begin
    var Error: IJSError;

    if Supports(Value.AsObject, IJSError, Error) then
      Msg := Error.Message;
  end;

  inherited Create(Msg);
  FValue := Value;
end;

{ TJSInterpreter }

constructor TJSInterpreter.Create;
begin
  inherited Create;
  FFunctionRegistry := TList<IJSFunction>.Create;
  FScopeRegistry := TList<IJSScope>.Create;
  FFunctionPrograms := TDictionary<Pointer, TObject>.Create;
  FBoundFunctions := TDictionary<Pointer, TJSBoundFunction>.Create;
  FCurrentProgram := nil;
  FCancelRequested := 0;
  FExecutionDepth := 0;
  FStepBudget := 0;
  FStepsCompleted := 0;
  FStepSlice := 0;
  FStepsUntilCheck := 0;
  FLimits := TJSLimits.Default;
  FCallDepth := 0;
  FGlobalObject := TJSObject.Create;
  FGlobalScope := TJSGlobalScope.Create(FGlobalObject);
  FScopeRegistry.Add(FGlobalScope);
  FCurrentScope := FGlobalScope;
  FThisValue := nil;
end;

destructor TJSInterpreter.Destroy;
begin
  if Assigned(FThrowTypeError) then
    FThrowTypeError.Prototype := nil;

  for var Func in FFunctionRegistry do
  begin
    Func.ClosureScope := nil;
    Func.NativeFunction := nil;
    Func.Prototype := nil;
    DetachProperties(Func);
  end;
  FFunctionRegistry.Free;

  for var Scope in FScopeRegistry do
  begin
    Scope.Clear;
  end;
  FScopeRegistry.Free;
  FFunctionPrograms.Free;
  FBoundFunctions.Free;
  FEvalVariableScope := nil;
  FEvalFunction := nil;
  FThrowTypeError := nil;
  FProgramParser := nil;

  FCurrentScope := nil;
  FGlobalScope := nil;
  FGlobalObject := nil;
  FThisValue := nil;
  FObjectPrototype := nil;
  FArrayPrototype := nil;
  FFunctionPrototype := nil;
  FRegExpPrototype := nil;
  inherited;
end;

procedure TJSInterpreter.SetFunctionPrototype(const Value: IJSObject);
begin
  FFunctionPrototype := Value;

  for var Func in FFunctionRegistry do
  begin
    const IsPrototypeItself = (Pointer(Func as IInterface) = Pointer(Value as IInterface));
    const NeedsPrototype = (not Assigned(Func.Prototype)) and (not IsPrototypeItself);
    if NeedsPrototype then
      Func.Prototype := Value;
  end;
end;

procedure TJSInterpreter.RegisterFunction(const Func: IJSFunction);
begin
  Func.CallHandler := Self;

  if not FFunctionRegistry.Contains(Func) then
    FFunctionRegistry.Add(Func);
  FFunctionPrograms.AddOrSetValue(Pointer(Func as IInterface), FCurrentProgram);
end;

procedure TJSInterpreter.RegisterScope(const Scope: IJSScope);
begin
  if not FScopeRegistry.Contains(Scope) then
    FScopeRegistry.Add(Scope);
end;

procedure TJSInterpreter.AttachPrototype(const Func: IJSFunction);
begin
  const PrototypeObj: IJSObject = TJSObject.Create;
  PrototypeObj.Prototype := FObjectPrototype;

  var ConstructorDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func as IJSObject));
  ConstructorDescriptor.Enumerable := False;
  PrototypeObj.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);

  var PrototypeDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(PrototypeObj));
  PrototypeDescriptor.Enumerable := False;
  PrototypeDescriptor.Configurable := False;
  Func.DefineProperty(PROTOTYPE_PROPERTY, PrototypeDescriptor);
end;

function TJSInterpreter.CreateThrowTypeError: IJSFunction;
begin
  Result := TJSFunction.CreateNative(EMPTY_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      raise TJSErrorFactory.TypeError(POISONED_PROPERTY);
    end);
  Result.IsConstructor := False;
  Result.Prototype := FFunctionPrototype;

  var LengthDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(0));
  LengthDescriptor.Writable := False;
  LengthDescriptor.Enumerable := False;
  LengthDescriptor.Configurable := False;
  Result.DefineProperty(LENGTH_PROPERTY, LengthDescriptor);

  RegisterFunction(Result);
  Result.Freeze;
end;

function TJSInterpreter.ThrowTypeErrorFunction: IJSFunction;
begin
  if not Assigned(FThrowTypeError) then
    FThrowTypeError := CreateThrowTypeError;

  Result := FThrowTypeError;
end;

function TJSInterpreter.CreateCalleeDescriptor: TJSPropertyDescriptor;
begin
  const Poison = TJSValue.CreateObject(ThrowTypeErrorFunction);

  Result := TJSPropertyDescriptor.Create(TJSValue.CreateUndefined);
  Result.IsAccessor := True;
  Result.Getter := Poison;
  Result.Setter := Poison;
  Result.Enumerable := False;
  Result.Configurable := False;
end;

function TJSInterpreter.ReferencesArguments(const Func: IJSFunction): Boolean;
begin
  const Body = TObject(Func.BodyNode);

  Result := (not (Body is TJSBlockStatement)) or TJSBlockStatement(Body).ReferencesArguments;
end;

function TJSInterpreter.CreateArgumentsObject(const Args: TArray<TJSValue>; const Func: IJSFunction): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := FObjectPrototype;

  for var Index := 0 to Length(Args) - 1 do
  begin
    Result.DefineProperty(IntToStr(Index), TJSPropertyDescriptor.Create(Args[Index]));
  end;

  var LengthDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(Length(Args)));
  LengthDescriptor.Enumerable := False;
  Result.DefineProperty(LENGTH_PROPERTY, LengthDescriptor);

  if Func.IsStrict then
    Result.DefineProperty(CALLEE_PROPERTY, CreateCalleeDescriptor);
end;

procedure TJSInterpreter.DetachProperties(const Func: IJSFunction);
begin
  for var PropName in Func.GetOwnPropertyNames do
  begin
    Func.DeleteProperty(PropName);
  end;
end;

function TJSInterpreter.IsInPrototypeChain(const Instance: IJSObject; const Constructor_: IJSFunction): Boolean;
begin
  Result := False;

  const PrototypeValue = Constructor_.GetProperty(PROTOTYPE_PROPERTY);
  if not PrototypeValue.IsObject then
    Exit;

  const TargetPrototype = PrototypeValue.ToObject;
  var Current := Instance.Prototype;
  while Assigned(Current) do
  begin
    if (Current as IInterface) = (TargetPrototype as IInterface) then
      Exit(True);

    Current := Current.Prototype;
  end;
end;

function TJSInterpreter.CreateInstanceFor(const Constructor_: IJSFunction): IJSObject;
begin
  Result := TJSObject.Create;

  const PrototypeValue = Constructor_.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsObject then
    Result.Prototype := PrototypeValue.ToObject
  else
    Result.Prototype := FObjectPrototype;
end;

function TJSInterpreter.PrimitivePrototypeFor(const Value: TJSValue): IJSObject;
begin
  if Value.IsString then
    Result := FStringPrototype
  else if Value.IsNumber then
    Result := FNumberPrototype
  else if Value.IsBoolean then
    Result := FBooleanPrototype
  else
    Result := nil;
end;

function TJSInterpreter.WrapPrimitive(const Value: TJSValue): IJSObject;
begin
  Result := TJSPrimitiveWrapper.Create(Value);
  Result.Prototype := PrimitivePrototypeFor(Value);
end;

function TJSInterpreter.BoundLength(const Target: IJSFunction; const BoundArgumentCount: Integer): Integer;
begin
  const TargetLength = Target.GetProperty(LENGTH_PROPERTY);
  if not TargetLength.IsNumber then
    Exit(0);

  const LengthNumber = TargetLength.AsNumber;
  const IsUsableLength = not (IsNaN(LengthNumber) or IsInfinite(LengthNumber));
  if not IsUsableLength then
    Exit(0);

  Result := Max(0, Trunc(LengthNumber) - BoundArgumentCount);
end;

function TJSInterpreter.ThisObjectFor(const Func: IJSFunction; const ThisValue: TJSValue): IJSObject;
begin
  if ThisValue.IsObject then
    Exit(ThisValue.ToObject);

  const IsPrimitive = not ThisValue.IsNullOrUndefined;
  const SeesObjectThis = Func.IsNative or (not Func.IsStrict);
  if IsPrimitive and SeesObjectThis then
    Exit(WrapPrimitive(ThisValue));

  Result := nil;
end;

procedure TJSInterpreter.PushScope;
begin
  FCurrentScope := TJSScope.Create(FCurrentScope);
  RegisterScope(FCurrentScope);
end;

procedure TJSInterpreter.PopScope;
begin
  FCurrentScope := FCurrentScope.Parent;
end;

procedure TJSInterpreter.BeginExecution;
begin
  FStepsCompleted := 0;
  OpenStepSlice;
end;

procedure TJSInterpreter.ConsumeStep;
begin
  if FStepsUntilCheck <= 0 then
    ReachStepCheckpoint;

  Dec(FStepsUntilCheck);
end;

procedure TJSInterpreter.ReachStepCheckpoint;
begin
  FStepsCompleted := GetStepCount;
  FStepSlice := 0;
  FStepsUntilCheck := 0;

  if IsCancelRequested then
    raise EJSExecutionCancelled.Create;

  if (FStepBudget > 0) and (FStepsCompleted >= FStepBudget) then
    raise EJSStepBudgetExceeded.Create(FStepBudget);

  OpenStepSlice;
end;

procedure TJSInterpreter.OpenStepSlice;
begin
  var Slice: Int64 := STEP_CHECK_INTERVAL;

  if FStepBudget > 0 then
  begin
    const StepsLeft = FStepBudget - FStepsCompleted;

    if StepsLeft < Slice then
      Slice := StepsLeft;
  end;

  FStepSlice := Integer(Slice);
  FStepsUntilCheck := FStepSlice;
end;

procedure TJSInterpreter.Cancel;
begin
  TInterlocked.Exchange(FCancelRequested, 1);
end;

function TJSInterpreter.IsCancelRequested: Boolean;
begin
  Result := TInterlocked.Read(FCancelRequested) <> 0;
end;

function TJSInterpreter.GetStepCount: Int64;
begin
  Result := FStepsCompleted + (FStepSlice - FStepsUntilCheck);
end;

function TJSInterpreter.Execute(const Program_: TJSProgram): TJSValue;
begin
  if FExecutionDepth = 0 then
    BeginExecution;

  Inc(FExecutionDepth);
  try
    FCurrentProgram := Program_;
    Result := Visit(Program_);
  finally
    Dec(FExecutionDepth);
  end;
end;

function TJSInterpreter.ExecuteStatement(const Node: TJSStatement): TJSValue;
begin
  ConsumeStep;
  Result := Visit(Node);
end;

function TJSInterpreter.Visit(const Node: TJSASTNode): TJSValue;
begin
  if Node = nil then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  case Node.NodeType of
    TJSASTNodeType.Program_:
      Result := VisitProgram(TJSProgram(Node));
    TJSASTNodeType.BlockStatement:
      Result := VisitBlockStatement(TJSBlockStatement(Node));
    TJSASTNodeType.VariableDeclaration:
      Result := VisitVariableDeclaration(TJSVariableDeclaration(Node));
    TJSASTNodeType.FunctionDeclaration:
      Result := TJSValue.CreateUndefined;
    TJSASTNodeType.ExpressionStatement:
      Result := VisitExpressionStatement(TJSExpressionStatement(Node));
    TJSASTNodeType.IfStatement:
      Result := VisitIfStatement(TJSIfStatement(Node));
    TJSASTNodeType.WhileStatement:
      Result := VisitWhileStatement(TJSWhileStatement(Node));
    TJSASTNodeType.DoWhileStatement:
      Result := VisitDoWhileStatement(TJSDoWhileStatement(Node));
    TJSASTNodeType.WithStatement:
      Result := VisitWithStatement(TJSWithStatement(Node));
    TJSASTNodeType.LabeledStatement:
      Result := VisitLabeledStatement(TJSLabeledStatement(Node));
    TJSASTNodeType.ForStatement:
      Result := VisitForStatement(TJSForStatement(Node));
    TJSASTNodeType.ForInStatement:
      Result := VisitForInStatement(TJSForInStatement(Node));
    TJSASTNodeType.ReturnStatement:
      Result := VisitReturnStatement(TJSReturnStatement(Node));
    TJSASTNodeType.BreakStatement:
      Result := VisitBreakStatement(TJSBreakStatement(Node));
    TJSASTNodeType.ContinueStatement:
      Result := VisitContinueStatement(TJSContinueStatement(Node));
    TJSASTNodeType.SwitchStatement:
      Result := VisitSwitchStatement(TJSSwitchStatement(Node));
    TJSASTNodeType.ThrowStatement:
      Result := VisitThrowStatement(TJSThrowStatement(Node));
    TJSASTNodeType.TryStatement:
      Result := VisitTryStatement(TJSTryStatement(Node));
    TJSASTNodeType.EmptyStatement:
      Result := TJSValue.CreateUndefined;
    TJSASTNodeType.DebuggerStatement:
      Result := TJSValue.CreateUndefined;
    TJSASTNodeType.Identifier:
      Result := VisitIdentifier(TJSIdentifier(Node));
    TJSASTNodeType.Literal:
      Result := VisitLiteral(TJSLiteral(Node));
    TJSASTNodeType.ArrayExpression:
      Result := VisitArrayExpression(TJSArrayExpression(Node));
    TJSASTNodeType.ObjectExpression:
      Result := VisitObjectExpression(TJSObjectExpression(Node));
    TJSASTNodeType.FunctionExpression:
      Result := VisitFunctionExpression(TJSFunctionExpression(Node));
    TJSASTNodeType.UnaryExpression:
      Result := VisitUnaryExpression(TJSUnaryExpression(Node));
    TJSASTNodeType.BinaryExpression:
      Result := VisitBinaryExpression(TJSBinaryExpression(Node));
    TJSASTNodeType.LogicalExpression:
      Result := VisitLogicalExpression(TJSLogicalExpression(Node));
    TJSASTNodeType.AssignmentExpression:
      Result := VisitAssignmentExpression(TJSAssignmentExpression(Node));
    TJSASTNodeType.UpdateExpression:
      Result := VisitUpdateExpression(TJSUpdateExpression(Node));
    TJSASTNodeType.ConditionalExpression:
      Result := VisitConditionalExpression(TJSConditionalExpression(Node));
    TJSASTNodeType.CallExpression:
      Result := VisitCallExpression(TJSCallExpression(Node));
    TJSASTNodeType.MemberExpression:
      Result := VisitMemberExpression(TJSMemberExpression(Node));
    TJSASTNodeType.NewExpression:
      Result := VisitNewExpression(TJSNewExpression(Node));
    TJSASTNodeType.SequenceExpression:
      Result := VisitSequenceExpression(TJSSequenceExpression(Node));
    TJSASTNodeType.ThisExpression:
      Result := VisitThisExpression(TJSThisExpression(Node));
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitProgram(const Node: TJSProgram): TJSValue;
begin
  FStrictMode := Node.IsStrict;
  Result := RunProgramBody(Node);
end;

procedure TJSInterpreter.GuardGlobalFunctionDeclarations(const Node: TJSProgram);
begin
  const IsGlobalCode = (FCurrentScope = FGlobalScope);
  if not IsGlobalCode then
    Exit;

  for var Statement in Node.Body do
  begin
    if Statement is TJSFunctionDeclaration then
      GuardGlobalFunctionDeclaration(TJSFunctionDeclaration(Statement));
  end;
end;

procedure TJSInterpreter.GuardGlobalFunctionDeclaration(const Declaration: TJSFunctionDeclaration);
begin
  var Descriptor: TJSPropertyDescriptor;
  const IsExisting = FGlobalObject.TryGetPropertyDescriptor(Declaration.Id.Name, Descriptor);
  if not IsExisting then
    Exit;

  const IsReplaceable = (Descriptor.Configurable or
                         (Descriptor.Writable and Descriptor.Enumerable and not Descriptor.IsAccessor));
  if IsReplaceable then
    Exit;

  const Message = Format('Cannot declare global function %s', [Declaration.Id.Name]);
  raise TJSErrorFactory.TypeError(Message, Declaration.Line, Declaration.Column);
end;

function TJSInterpreter.RunProgramBody(const Node: TJSProgram): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  GuardGlobalFunctionDeclarations(Node);

  for var Statement in Node.Body do
  begin
    HoistDeclarations(Statement);
  end;

  for var Statement in Node.Body do
  begin
    Result := ExecuteStatement(Statement);
  end;
end;

function TJSInterpreter.EvaluateSource(const Source: string; const IsDirect: Boolean): TJSValue;
begin
  const IsStrictContext = (IsDirect and FStrictMode);
  Result := EvaluateProgram(FProgramParser(Source, IsStrictContext), IsDirect);
end;

function TJSInterpreter.CreateFunctionFromSource(const Source: string): TJSValue;
begin
  const Program_ = FProgramParser(Source, False);

  const HasSingleStatement = (Program_.Body.Count = 1);
  const IsExpressionStatement = HasSingleStatement and (Program_.Body[0] is TJSExpressionStatement);
  const IsFunctionSource = IsExpressionStatement and
                           (TJSExpressionStatement(Program_.Body[0]).Expression is TJSFunctionExpression);
  if not IsFunctionSource then
    raise TJSErrorFactory.SyntaxError(INVALID_FUNCTION_SOURCE);

  Result := EvaluateProgram(Program_, False);
end;

function TJSInterpreter.EvaluateProgram(const Program_: TJSProgram; const IsDirect: Boolean): TJSValue;
begin
  const IsStrictSource = (Program_.IsStrict or (IsDirect and FStrictMode));

  const OldScope = FCurrentScope;
  const OldThis = FThisValue;
  const OldStrictMode = FStrictMode;
  const OldProgram = FCurrentProgram;
  const OldEvalVariableScope = FEvalVariableScope;
  FCurrentScope := CreateEvalScope(IsDirect, IsStrictSource);
  FEvalVariableScope := FCurrentScope;
  FStrictMode := IsStrictSource;
  FCurrentProgram := Program_;
  if not IsDirect then
    FThisValue := FGlobalObject;
  try
    Result := RunProgramBody(Program_);
  finally
    FCurrentProgram := OldProgram;
    FEvalVariableScope := OldEvalVariableScope;
    FStrictMode := OldStrictMode;
    FThisValue := OldThis;
    FCurrentScope := OldScope;
  end;
end;

function TJSInterpreter.CreateEvalScope(const IsDirect: Boolean; const IsStrictSource: Boolean): IJSScope;
begin
  var OuterScope: IJSScope := FGlobalScope;
  if IsDirect then
    OuterScope := FCurrentScope;

  if not IsStrictSource then
    Exit(OuterScope);

  Result := TJSScope.Create(OuterScope);
  RegisterScope(Result);
end;

function TJSInterpreter.IsDirectEvalCall(const Callee: TJSExpression; const Func: IJSFunction): Boolean;
begin
  const IsNamedEval = (Callee is TJSIdentifier) and (TJSIdentifier(Callee).Name = EVAL_NAME);
  Result := IsNamedEval and (Func = FEvalFunction);
end;

function TJSInterpreter.CallDirectEval(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
begin
  FDirectEvalCall := True;
  try
    Result := CallFunction(Func, Args, nil);
  finally
    FDirectEvalCall := False;
  end;
end;

procedure TJSInterpreter.HoistDeclarations(const Node: TJSASTNode);
begin
  if Node = nil then
    Exit;

  case Node.NodeType of
    TJSASTNodeType.VariableDeclaration:
      for var Declarator in TJSVariableDeclaration(Node).Declarations do
      begin
        if FCurrentScope.Resolve(Declarator.Id.Name) <> FCurrentScope then
          DeclareBinding(Declarator.Id.Name, TJSValue.CreateUndefined);
      end;
    TJSASTNodeType.FunctionDeclaration:
      DeclareFunction(TJSFunctionDeclaration(Node));
    TJSASTNodeType.BlockStatement:
      for var Statement in TJSBlockStatement(Node).Body do
      begin
        HoistDeclarations(Statement);
      end;
    TJSASTNodeType.IfStatement:
      begin
        HoistDeclarations(TJSIfStatement(Node).Consequent);
        HoistDeclarations(TJSIfStatement(Node).Alternate);
      end;
    TJSASTNodeType.WhileStatement:
      HoistDeclarations(TJSWhileStatement(Node).Body);
    TJSASTNodeType.DoWhileStatement:
      HoistDeclarations(TJSDoWhileStatement(Node).Body);
    TJSASTNodeType.WithStatement:
      HoistDeclarations(TJSWithStatement(Node).Body);
    TJSASTNodeType.LabeledStatement:
      HoistDeclarations(TJSLabeledStatement(Node).Body);
    TJSASTNodeType.ForStatement:
      begin
        HoistDeclarations(TJSForStatement(Node).Init);
        HoistDeclarations(TJSForStatement(Node).Body);
      end;
    TJSASTNodeType.ForInStatement:
      begin
        HoistDeclarations(TJSForInStatement(Node).Left);
        HoistDeclarations(TJSForInStatement(Node).Body);
      end;
    TJSASTNodeType.TryStatement:
      begin
        const TryNode = TJSTryStatement(Node);
        HoistDeclarations(TryNode.Block);

        if Assigned(TryNode.Handler) then
          HoistDeclarations(TryNode.Handler.Body);

        HoistDeclarations(TryNode.Finalizer);
      end;
    TJSASTNodeType.SwitchStatement:
      for var SwitchCase in TJSSwitchStatement(Node).Cases do
      begin
        for var Statement in SwitchCase.Consequent do
        begin
          HoistDeclarations(Statement);
        end;
      end;
  end;
end;

function TJSInterpreter.VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  for var Statement in Node.Body do
  begin
    Result := ExecuteStatement(Statement);
  end;
end;

function TJSInterpreter.VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
begin
  for var Declarator in Node.Declarations do
  begin
    if Assigned(Declarator.Init) then
      FCurrentScope.SetVariable(Declarator.Id.Name, Visit(Declarator.Init));
  end;

  Result := TJSValue.CreateUndefined;
end;

procedure TJSInterpreter.DeclareFunction(const Node: TJSFunctionDeclaration);
begin
  const Func = TJSFunction.Create;
  Func.Prototype := FFunctionPrototype;
  Func.Name := Node.Id.Name;
  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;
  Func.ClosureScope := FCurrentScope;

  var Params: TArray<string>;
  SetLength(Params, Node.Params.Count);

  for var Index := 0 to Node.Params.Count - 1 do
  begin
    Params[Index] := Node.Params[Index].Name;
  end;

  Func.Parameters := Params;
  RegisterFunction(Func);
  AttachPrototype(Func);

  DeclareBinding(Node.Id.Name, TJSValue.CreateObject(Func));
end;

function TJSInterpreter.VisitExpressionStatement(const Node: TJSExpressionStatement): TJSValue;
begin
  Result := Visit(Node.Expression);
end;

function TJSInterpreter.VisitIfStatement(const Node: TJSIfStatement): TJSValue;
begin
  const TestValue = Visit(Node.Test);

  if TestValue.ToBoolean then
    Result := Visit(Node.Consequent)
  else if Assigned(Node.Alternate) then
    Result := Visit(Node.Alternate)
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.ToScopeObject(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_OR_UNDEFINED_TO_OBJECT);

  if Value.IsObject then
    Exit(Value.ToObject);

  Result := WrapPrimitive(Value);
end;

function TJSInterpreter.VisitWithStatement(const Node: TJSWithStatement): TJSValue;
begin
  if FStrictMode then
    raise TJSErrorFactory.SyntaxError('with statement is not allowed in strict mode', Node.Line, Node.Column);

  const TargetValue = Visit(Node.Target);
  const ScopeObject = ToScopeObject(TargetValue);
  const OuterScope = FCurrentScope;

  FCurrentScope := TJSObjectScope.Create(OuterScope, ScopeObject);
  RegisterScope(FCurrentScope);
  try
    Result := ExecuteStatement(Node.Body);
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.WithObjectFor(const Callee: TJSExpression): IJSObject;
begin
  Result := nil;

  if not (Callee is TJSIdentifier) then
    Exit;

  const CalleeName = TJSIdentifier(Callee).Name;
  const DeclaringScope = FCurrentScope.Resolve(CalleeName);
  var ObjectScope: IJSObjectScope;
  if Supports(DeclaringScope, IJSObjectScope, ObjectScope) then
    Result := ObjectScope.BindingObject;
end;

function TJSInterpreter.VisitLabeledStatement(const Node: TJSLabeledStatement): TJSValue;
begin
  const BodyIsLoop = (Node.Body.NodeType in [TJSASTNodeType.WhileStatement,
                                             TJSASTNodeType.DoWhileStatement,
                                             TJSASTNodeType.ForStatement,
                                             TJSASTNodeType.ForInStatement]);
  const BodyIsLabeled = (Node.Body.NodeType = TJSASTNodeType.LabeledStatement);

  if BodyIsLoop or BodyIsLabeled then
    FLoopLabels := FLoopLabels + [Node.LabelName]
  else
    FLoopLabels := nil;

  Result := TJSValue.CreateUndefined;
  try
    try
      Result := ExecuteStatement(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        const IsAddressedToOtherLabel = (Signal.TargetLabel <> Node.LabelName);
        if IsAddressedToOtherLabel then
          raise;
      end;
    end;
  finally
    FLoopLabels := nil;
  end;
end;

function TJSInterpreter.TakeLoopLabels: TArray<string>;
begin
  Result := FLoopLabels;
  FLoopLabels := nil;
end;

function TJSInterpreter.VisitWhileStatement(const Node: TJSWhileStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  while Visit(Node.Test).ToBoolean do
  begin
    try
      Result := ExecuteStatement(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        if Signal.IsLabelled then
          raise;

        Break;
      end;
      on Signal: TJSContinueSignal do
      begin
        if not Signal.AppliesTo(OwnLabels) then
          raise;

        Continue;
      end;
    end;
  end;
end;

function TJSInterpreter.VisitDoWhileStatement(const Node: TJSDoWhileStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  repeat
    try
      Result := ExecuteStatement(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        if Signal.IsLabelled then
          raise;

        Break;
      end;
      on Signal: TJSContinueSignal do
      begin
        if not Signal.AppliesTo(OwnLabels) then
          raise;

        Continue;
      end;
    end;
  until not Visit(Node.Test).ToBoolean;
end;

function TJSInterpreter.VisitForStatement(const Node: TJSForStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  if Assigned(Node.Init) then
    Visit(Node.Init);

  while True do
  begin
    if Assigned(Node.Test) then
    begin
      const TestValue = Visit(Node.Test);

      if not TestValue.ToBoolean then
        Break;
    end;

    try
      Result := ExecuteStatement(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        if Signal.IsLabelled then
          raise;

        Break;
      end;
      on Signal: TJSContinueSignal do
      begin
        if not Signal.AppliesTo(OwnLabels) then
          raise;

        if Assigned(Node.Update) then
          Visit(Node.Update);

        Continue;
      end;
    end;

    if Assigned(Node.Update) then
      Visit(Node.Update);
  end;
end;

function TJSInterpreter.VisitForInStatement(const Node: TJSForInStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  const RightValue = Visit(TJSExpression(Node.Right));

  if not RightValue.IsObject then
    Exit;

  const Obj = RightValue.ToObject;
  const PropertyNames = Obj.GetOwnPropertyNames;

  for var PropName in PropertyNames do
  begin
    const Descriptor = Obj.GetOwnPropertyDescriptor(PropName);
    if not Descriptor.Enumerable then
      Continue;

    if Node.Left is TJSVariableDeclaration then
    begin
      const VarDecl = TJSVariableDeclaration(Node.Left);

      if VarDecl.Declarations.Count > 0 then
        FCurrentScope.SetVariable(VarDecl.Declarations[0].Id.Name, TJSValue.CreateString(PropName));
    end
    else if Node.Left is TJSIdentifier then
    begin
      const Identifier = TJSIdentifier(Node.Left);
      FCurrentScope.SetVariable(Identifier.Name, TJSValue.CreateString(PropName));
    end;

    try
      Result := ExecuteStatement(Node.Body);
    except
      on Signal: TJSBreakSignal do
      begin
        if Signal.IsLabelled then
          raise;

        Break;
      end;
      on Signal: TJSContinueSignal do
      begin
        if not Signal.AppliesTo(OwnLabels) then
          raise;

        Continue;
      end;
    end;
  end;
end;

function TJSInterpreter.VisitReturnStatement(const Node: TJSReturnStatement): TJSValue;
begin
  var ReturnValue: TJSValue;

  if Assigned(Node.Argument) then
    ReturnValue := Visit(Node.Argument)
  else
    ReturnValue := TJSValue.CreateUndefined;

  raise TJSReturnSignal.Create(ReturnValue);
end;

function TJSInterpreter.VisitBreakStatement(const Node: TJSBreakStatement): TJSValue;
begin
  var TargetLabel := '';
  if Assigned(Node.LabelId) then
    TargetLabel := Node.LabelId.Name;

  raise TJSBreakSignal.Create(TargetLabel);
end;

function TJSInterpreter.VisitContinueStatement(const Node: TJSContinueStatement): TJSValue;
begin
  var TargetLabel := '';
  if Assigned(Node.LabelId) then
    TargetLabel := Node.LabelId.Name;

  raise TJSContinueSignal.Create(TargetLabel);
end;

function TJSInterpreter.VisitSwitchStatement(const Node: TJSSwitchStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const DiscriminantValue = Visit(Node.Discriminant);
  var Matched := False;
  var DefaultCaseIndex := -1;

  for var CaseIndex := 0 to Node.Cases.Count - 1 do
  begin
    const SwitchCase = Node.Cases[CaseIndex];

    if SwitchCase.Test = nil then
    begin
      DefaultCaseIndex := CaseIndex;
      Continue;
    end;

    const TestValue = Visit(SwitchCase.Test);

    if StrictEquals(DiscriminantValue, TestValue) then
    begin
      Matched := True;

      try
        for var StatementIndex := CaseIndex to Node.Cases.Count - 1 do
        begin
          const CurrentCase = Node.Cases[StatementIndex];

          for var Statement in CurrentCase.Consequent do
          begin
            Result := ExecuteStatement(Statement);
          end;
        end;
      except
        on Signal: TJSBreakSignal do
        begin
          if Signal.IsLabelled then
            raise;

          Exit;
        end;
      end;

      Break;
    end;
  end;

  const ShouldRunDefault = (not Matched) and (DefaultCaseIndex >= 0);
  if ShouldRunDefault then
  begin
    try
      for var StatementIndex := DefaultCaseIndex to Node.Cases.Count - 1 do
      begin
        const CurrentCase = Node.Cases[StatementIndex];

        for var Statement in CurrentCase.Consequent do
        begin
          Result := ExecuteStatement(Statement);
        end;
      end;
    except
      on Signal: TJSBreakSignal do
      begin
        if Signal.IsLabelled then
          raise;

        Exit;
      end;
    end;
  end;
end;

function TJSInterpreter.VisitThrowStatement(const Node: TJSThrowStatement): TJSValue;
begin
  const Value = Visit(Node.Argument);
  raise TJSThrowSignal.Create(Value);
end;

function TJSInterpreter.VisitTryStatement(const Node: TJSTryStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    try
      Result := Visit(Node.Block);
    except
      on EJSExecutionInterrupted do
        raise;
      on EJSControlFlowSignal do
        raise;
      on E: TJSThrowSignal do
      begin
        if Assigned(Node.Handler) then
          Result := VisitCatchClause(Node.Handler, E.Value)
        else
          raise;
      end;
      on E: Exception do
      begin
        if Assigned(Node.Handler) then
          Result := VisitCatchClause(Node.Handler, CreateErrorValue(E))
        else
          raise;
      end;
    end;
  except
    on EJSExecutionInterrupted do
      raise;
    on Exception do
    begin
      RunFinalizer(Node);
      raise;
    end;
  end;

  RunFinalizer(Node);
end;

function TJSInterpreter.ErrorConstructorName(const Error: Exception): string;
begin
  Result := '';

  if Error is EJSTypeError then
    Result := CONSTRUCTOR_TYPE_ERROR
  else if Error is EJSReferenceError then
    Result := CONSTRUCTOR_REFERENCE_ERROR
  else if Error is EJSRangeError then
    Result := CONSTRUCTOR_RANGE_ERROR
  else if Error is EJSSyntaxError then
    Result := CONSTRUCTOR_SYNTAX_ERROR
  else if Error is EJSURIError then
    Result := CONSTRUCTOR_URI_ERROR
  else if Error is EJSEvalError then
    Result := CONSTRUCTOR_EVAL_ERROR;
end;

function TJSInterpreter.CreateErrorValue(const Error: Exception): TJSValue;
begin
  const ErrorName = ErrorConstructorName(Error);
  const IsKnownError = (not ErrorName.IsEmpty) and FGlobalScope.HasVariable(ErrorName);
  if not IsKnownError then
    Exit(TJSValue.CreateString(Error.Message));

  var Func: IJSFunction;
  const ConstructorValue = FGlobalScope.GetVariable(ErrorName);
  const IsCallable = ConstructorValue.IsFunction and Supports(ConstructorValue.ToObject, IJSFunction, Func);
  if not IsCallable then
    Exit(TJSValue.CreateString(Error.Message));

  const Prefix = ErrorName + ': ';
  var Message := Error.Message;
  if Message.StartsWith(Prefix) then
    Message := Message.Substring(Length(Prefix));

  Result := CallFunction(Func, [TJSValue.CreateString(Message)], nil);
end;

function TJSInterpreter.VisitCatchClause(const Handler: TJSCatchClause; const Thrown: TJSValue): TJSValue;
begin
  PushScope;
  try
    FCurrentScope.DeclareVariable(Handler.Param.Name, Thrown);
    Result := Visit(Handler.Body);
  finally
    PopScope;
  end;
end;

procedure TJSInterpreter.RunFinalizer(const Node: TJSTryStatement);
begin
  if Assigned(Node.Finalizer) then
    Visit(Node.Finalizer);
end;

function TJSInterpreter.VisitIdentifier(const Node: TJSIdentifier): TJSValue;
begin
  if not FCurrentScope.HasVariable(Node.Name) then
    raise TJSErrorFactory.UndefinedVariable(Node.Name, Node.Line, Node.Column);

  Result := FCurrentScope.GetVariable(Node.Name);
end;

function TJSInterpreter.VisitLiteral(const Node: TJSLiteral): TJSValue;
begin
  case Node.LiteralType of
    TJSLiteralType.Undefined:
      Result := TJSValue.CreateUndefined;
    TJSLiteralType.Null:
      Result := TJSValue.CreateNull;
    TJSLiteralType.Boolean:
      Result := TJSValue.CreateBoolean(Node.BooleanValue);
    TJSLiteralType.Number:
      Result := TJSValue.CreateNumber(Node.NumberValue);
    TJSLiteralType.String_:
      Result := TJSValue.CreateString(Node.StringValue);
    TJSLiteralType.RegExp:
      begin
        const RegExpObj: IJSRegExp = TJSRegExp.Create(Node.RegExpPattern, Node.RegExpFlags);
        RegExpObj.Prototype := FRegExpPrototype;

        var TestFunc: IJSFunction := TJSFunction.CreateNative('test',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) and (Length(Args) > 0) then
            begin
              const Subject = ToText(Args[0]);

              Result := TJSValue.CreateBoolean(RE.Test(Subject));
            end
            else
              Result := TJSValue.CreateBoolean(False);
          end);
        RegisterFunction(TestFunc);
        RegExpObj.SetProperty('test', TJSValue.CreateObject(TestFunc));

        var ExecFunc: IJSFunction := TJSFunction.CreateNative('exec',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) and (Length(Args) > 0) then
            begin
              const Subject = ToText(Args[0]);

              Result := RE.Exec(Subject);
            end
            else
              Result := TJSValue.CreateNull;
          end);
        RegisterFunction(ExecFunc);
        RegExpObj.SetProperty('exec', TJSValue.CreateObject(ExecFunc));

        var ToStringFunc: IJSFunction := TJSFunction.CreateNative('toString',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) then
              Result := TJSValue.CreateString('/' + RE.Pattern + '/' + RE.Flags)
            else
              Result := TJSValue.CreateString('/(?:)/');
          end);
        RegisterFunction(ToStringFunc);
        RegExpObj.SetProperty('toString', TJSValue.CreateObject(ToStringFunc));

        Result := TJSValue.CreateObject(RegExpObj);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
begin
  FLimits.EnsureArrayLength(Node.Elements.Count);

  const Arr = TJSArray.Create;
  Arr.Prototype := FArrayPrototype;

  for var Element in Node.Elements do
  begin
    if Assigned(Element) then
    begin
      Arr.Push(Visit(Element));
    end
    else
    begin
      Arr.Push(TJSValue.CreateUndefined);
      Arr.DeleteElement(Arr.Length - 1);
    end;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

function TJSInterpreter.VisitObjectExpression(const Node: TJSObjectExpression): TJSValue;
begin
  const Obj = TJSObject.Create;
  Obj.Prototype := FObjectPrototype;

  for var Prop in Node.Properties do
  begin
    DefineLiteralProperty(Obj, Prop);
  end;

  Result := TJSValue.CreateObject(Obj);
end;

procedure TJSInterpreter.DefineLiteralProperty(const Target: IJSObject; const Prop: TJSObjectProperty);
begin
  var KeyName: string;

  if Prop.Key is TJSIdentifier then
    KeyName := TJSIdentifier(Prop.Key).Name
  else
    KeyName := VisitText(Prop.Key);

  const IsAccessor = (Prop.Kind <> TJSPropertyKind.Data);
  if IsAccessor then
  begin
    DefineLiteralAccessor(Target, KeyName, Prop);
    Exit;
  end;

  const Value = Visit(Prop.Value);
  Target.DefineProperty(KeyName, TJSPropertyDescriptor.Create(Value));
end;

procedure TJSInterpreter.DefineLiteralAccessor(const Target: IJSObject; const Name: string;
                                               const Prop: TJSObjectProperty);
begin
  var Definition := Default(TJSPropertyDefinition);
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  const Accessor = Visit(Prop.Value);
  const IsGetter = (Prop.Kind = TJSPropertyKind.Getter);
  if IsGetter then
  begin
    Definition.HasGetter := True;
    Definition.Getter := Accessor;
  end
  else
  begin
    Definition.HasSetter := True;
    Definition.Setter := Accessor;
  end;

  Target.DefineOwnProperty(Name, Definition);
end;

function TJSInterpreter.VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
begin
  const Func = TJSFunction.Create;
  Func.Prototype := FFunctionPrototype;

  if Assigned(Node.Id) then
    Func.Name := Node.Id.Name;

  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;
  Func.ClosureScope := FCurrentScope;

  var Params: TArray<string>;
  SetLength(Params, Node.Params.Count);

  for var Index := 0 to Node.Params.Count - 1 do
  begin
    Params[Index] := Node.Params[Index].Name;
  end;

  Func.Parameters := Params;
  RegisterFunction(Func);
  AttachPrototype(Func);

  Result := TJSValue.CreateObject(Func);
end;

function TJSInterpreter.VisitDeleteExpression(const Node: TJSUnaryExpression): TJSValue;
begin
  if Node.Argument is TJSIdentifier then
  begin
    if FStrictMode then
      raise TJSErrorFactory.SyntaxError('Delete of an unqualified identifier in strict mode',
        Node.Line, Node.Column);

    const IdentifierName = TJSIdentifier(Node.Argument).Name;
    const IsDeleted = DeleteIdentifier(IdentifierName);
    Exit(TJSValue.CreateBoolean(IsDeleted));
  end;

  const IsMemberReference = Node.Argument is TJSMemberExpression;
  if not IsMemberReference then
  begin
    Visit(Node.Argument);
    Exit(TJSValue.CreateBoolean(True));
  end;

  Result := DeleteMember(Node, TJSMemberExpression(Node.Argument));
end;

function TJSInterpreter.DeleteMember(const Node: TJSUnaryExpression; const MemberExpr: TJSMemberExpression): TJSValue;
begin
  const ObjValue = Visit(MemberExpr.Object_);
  if ObjValue.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_OR_UNDEFINED_TO_OBJECT, Node.Line, Node.Column);

  if not ObjValue.IsObject then
    Exit(TJSValue.CreateBoolean(False));

  var PropName: string;

  if MemberExpr.Computed then
    PropName := VisitText(MemberExpr.Property_)
  else
    PropName := TJSIdentifier(MemberExpr.Property_).Name;

  const Obj = ObjValue.ToObject;

  const OwnDescriptor = Obj.GetOwnPropertyDescriptor(PropName);
  const IsLocked = Obj.HasOwnProperty(PropName) and (not OwnDescriptor.Configurable);
  if IsLocked and FStrictMode then
    raise TJSErrorFactory.TypeError(Format('Cannot delete property ''%s'' of object', [PropName]),
      Node.Line, Node.Column);

  if IsLocked then
    Exit(TJSValue.CreateBoolean(False));

  DeleteArrayElement(Obj, PropName);
  Obj.DeleteProperty(PropName);
  Result := TJSValue.CreateBoolean(True);
end;

function TJSInterpreter.VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
begin
  if Node.Operator = TJSUnaryOperator.Delete then
    Exit(VisitDeleteExpression(Node));

  const IsTypeOfUndeclared = ((Node.Operator = TJSUnaryOperator.TypeOf) and
                              IsUndeclaredIdentifier(Node.Argument));
  if IsTypeOfUndeclared then
  begin
    Result := TJSValue.CreateString(UNDEFINED_TYPE);
    Exit;
  end;

  const Arg = Visit(Node.Argument);

  case Node.Operator of
    TJSUnaryOperator.Minus:
      begin
        const Number = TJSOperators.ToNumber(Arg);
        Result := TJSValue.CreateNumber(-Number);
      end;
    TJSUnaryOperator.Plus:
      begin
        const Number = TJSOperators.ToNumber(Arg);
        Result := TJSValue.CreateNumber(Number);
      end;
    TJSUnaryOperator.LogicalNot:
      Result := TJSValue.CreateBoolean(not Arg.ToBoolean);
    TJSUnaryOperator.BitwiseNot:
      begin
        const Integer32 = TJSOperators.ToInt32(Arg);
        Result := TJSValue.CreateNumber(not Integer32);
      end;
    TJSUnaryOperator.TypeOf:
      begin
        case Arg.ValueType of
          TJSValueType.Undefined:
            Result := TJSValue.CreateString(UNDEFINED_TYPE);
          TJSValueType.Null:
            Result := TJSValue.CreateString(OBJECT_TYPE);
          TJSValueType.Boolean_:
            Result := TJSValue.CreateString(BOOLEAN_TYPE);
          TJSValueType.Number:
            Result := TJSValue.CreateString(NUMBER_TYPE);
          TJSValueType.String_:
            Result := TJSValue.CreateString(STRING_TYPE);
          TJSValueType.Function_:
            Result := TJSValue.CreateString(FUNCTION_TYPE);
          else
            Result := TJSValue.CreateString(OBJECT_TYPE);
        end;
      end;
    TJSUnaryOperator.Void:
      Result := TJSValue.CreateUndefined;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

procedure TJSInterpreter.DeclareBinding(const Name: string; const Value: TJSValue);
begin
  const IsEvalDeclaration = Assigned(FEvalVariableScope) and (FCurrentScope = FEvalVariableScope);
  if IsEvalDeclaration then
    FCurrentScope.DeclareDeletableVariable(Name, Value)
  else
    FCurrentScope.DeclareVariable(Name, Value);
end;

function TJSInterpreter.DeleteIdentifier(const Name: string): Boolean;
begin
  const DeclaringScope = FCurrentScope.Resolve(Name);
  const IsResolvable = Assigned(DeclaringScope);
  if not IsResolvable then
    Exit(True);

  Result := DeclaringScope.DeleteVariable(Name);
end;

function TJSInterpreter.IsUndeclaredIdentifier(const Node: TJSExpression): Boolean;
begin
  if not (Node is TJSIdentifier) then
    Exit(False);

  const Name = TJSIdentifier(Node).Name;
  Result := not FCurrentScope.HasVariable(Name);
end;

function TJSInterpreter.VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
begin
  const Left = Visit(Node.Left);
  const Right = Visit(Node.Right);

  case Node.Operator of
    TJSBinaryOperator.Add,
    TJSBinaryOperator.Subtract,
    TJSBinaryOperator.Multiply,
    TJSBinaryOperator.Divide,
    TJSBinaryOperator.Modulo,
    TJSBinaryOperator.LessThan,
    TJSBinaryOperator.LessThanOrEqual,
    TJSBinaryOperator.GreaterThan,
    TJSBinaryOperator.GreaterThanOrEqual,
    TJSBinaryOperator.BitwiseAnd,
    TJSBinaryOperator.BitwiseOr,
    TJSBinaryOperator.BitwiseXor,
    TJSBinaryOperator.LeftShift,
    TJSBinaryOperator.RightShift,
    TJSBinaryOperator.UnsignedRightShift:
      Result := TJSOperators.Apply(Node.Operator, Left, Right, FLimits);
    TJSBinaryOperator.Equal:
      Result := TJSValue.CreateBoolean(AbstractEquals(Left, Right));
    TJSBinaryOperator.NotEqual:
      Result := TJSValue.CreateBoolean(not AbstractEquals(Left, Right));
    TJSBinaryOperator.StrictEqual:
      Result := TJSValue.CreateBoolean(StrictEquals(Left, Right));
    TJSBinaryOperator.StrictNotEqual:
      Result := TJSValue.CreateBoolean(not StrictEquals(Left, Right));
    TJSBinaryOperator.InstanceOf:
      begin
        if not Left.IsObject then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;

        if not Right.IsFunction then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;

        const LeftObj = Left.ToObject;
        var RightFunc: IJSFunction;
        if not Supports(Right.ToObject, IJSFunction, RightFunc) then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;
        const RightName = RightFunc.Name;

        if IsInPrototypeChain(LeftObj, RightFunc) then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        var ErrorIntf: IJSError;
        if Supports(LeftObj, IJSError, ErrorIntf) then
        begin
          if RightName = CONSTRUCTOR_ERROR then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_TYPE_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.TypeError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_RANGE_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.RangeError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_REFERENCE_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.ReferenceError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_SYNTAX_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.SyntaxError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_URI_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.URIError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = CONSTRUCTOR_EVAL_ERROR) and (ErrorIntf.ErrorType = TJSErrorType.EvalError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        end;

        if Supports(LeftObj, IJSArray) and (RightName = CONSTRUCTOR_ARRAY) then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSFunction) and (RightName = CONSTRUCTOR_FUNCTION) then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSRegExp) and (RightName = CONSTRUCTOR_REGEXP) then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSDate) and (RightName = CONSTRUCTOR_DATE) then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        Result := TJSValue.CreateBoolean(False);
      end;
    TJSBinaryOperator.In_:
      begin
        if Right.IsObject then
        begin
          const PropertyName = ToText(Left);

          Result := TJSValue.CreateBoolean(Right.ToObject.HasProperty(PropertyName));
        end
        else
          Result := TJSValue.CreateBoolean(False);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
begin
  const Left = Visit(Node.Left);

  case Node.Operator of
    TJSLogicalOperator.And_:
      begin
        if not Left.ToBoolean then
          Exit(Left);

        Result := Visit(Node.Right);
      end;
    TJSLogicalOperator.Or_:
      begin
        if Left.ToBoolean then
          Exit(Left);

        Result := Visit(Node.Right);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

procedure TJSInterpreter.GuardStrictAssignmentTarget(const Node: TJSAssignmentExpression);
begin
  const IsStrictIdentifierTarget = FStrictMode and (Node.Left is TJSIdentifier);
  if not IsStrictIdentifierTarget then
    Exit;

  const TargetName = TJSIdentifier(Node.Left).Name;
  const IsRestrictedName = (TargetName = 'eval') or (TargetName = ARGUMENTS_NAME);
  if IsRestrictedName then
    raise TJSErrorFactory.SyntaxError('Assignment to ' + TargetName + ' in strict mode', Node.Line, Node.Column);

  const IsDeclared = FCurrentScope.HasVariable(TargetName);
  if not IsDeclared then
    raise TJSErrorFactory.ReferenceError('Assignment to undeclared variable ' + TargetName, Node.Line, Node.Column);
end;

function TJSInterpreter.VisitAssignmentExpression(const Node: TJSAssignmentExpression): TJSValue;
begin
  GuardStrictAssignmentTarget(Node);

  if Node.Left is TJSIdentifier then
  begin
    Result := AssignToIdentifier(Node);
    Exit;
  end;

  if Node.Left is TJSMemberExpression then
  begin
    Result := AssignToMember(Node);
    Exit;
  end;

  raise TJSErrorFactory.InvalidLeftHandSide(Node.Line, Node.Column);
end;

function TJSInterpreter.AssignToIdentifier(const Node: TJSAssignmentExpression): TJSValue;
begin
  const Identifier = TJSIdentifier(Node.Left);

  var NewValue: TJSValue;
  if Node.Operator = TJSAssignmentOperator.Assign then
  begin
    NewValue := Visit(Node.Right);
  end
  else
  begin
    if not FCurrentScope.HasVariable(Identifier.Name) then
      raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Node.Line, Node.Column);

    const Current = FCurrentScope.GetVariable(Identifier.Name);
    const Right = Visit(Node.Right);
    const BinaryOperator = TJSOperators.BinaryOperatorFor(Node.Operator);
    NewValue := TJSOperators.Apply(BinaryOperator, Current, Right, FLimits);
  end;

  FCurrentScope.SetVariable(Identifier.Name, NewValue);
  Result := NewValue;
end;

function TJSInterpreter.AssignToMember(const Node: TJSAssignmentExpression): TJSValue;
begin
  var Reference := ResolveMemberReference(TJSMemberExpression(Node.Left));

  var NewValue: TJSValue;
  if Node.Operator = TJSAssignmentOperator.Assign then
  begin
    NewValue := Visit(Node.Right);
  end
  else
  begin
    const Current = GetReferenceValue(Reference);
    const Right = Visit(Node.Right);
    const BinaryOperator = TJSOperators.BinaryOperatorFor(Node.Operator);
    NewValue := TJSOperators.Apply(BinaryOperator, Current, Right, FLimits);
  end;

  PutReferenceValue(Reference, NewValue);
  Result := NewValue;
end;

function TJSInterpreter.VisitUpdateExpression(const Node: TJSUpdateExpression): TJSValue;
begin
  if Node.Argument is TJSIdentifier then
  begin
    Result := UpdateIdentifier(Node);
    Exit;
  end;

  if Node.Argument is TJSMemberExpression then
  begin
    Result := UpdateMember(Node);
    Exit;
  end;

  raise TJSErrorFactory.InvalidLeftHandSide(Node.Line, Node.Column);
end;

function TJSInterpreter.UpdateIdentifier(const Node: TJSUpdateExpression): TJSValue;
begin
  const Identifier = TJSIdentifier(Node.Argument);
  const OldValue = FCurrentScope.GetVariable(Identifier.Name);
  const OldNumber = TJSOperators.ToNumber(OldValue);

  var NewNumber := OldNumber - 1;
  if Node.Operator = TJSUpdateOperator.Increment then
    NewNumber := OldNumber + 1;

  const NewValue = TJSValue.CreateNumber(NewNumber);
  FCurrentScope.SetVariable(Identifier.Name, NewValue);

  if Node.Prefix then
    Result := NewValue
  else
    Result := TJSValue.CreateNumber(OldNumber);
end;

function TJSInterpreter.UpdateMember(const Node: TJSUpdateExpression): TJSValue;
begin
  var Reference := ResolveMemberReference(TJSMemberExpression(Node.Argument));
  const OldValue = GetReferenceValue(Reference);
  const OldNumber = TJSOperators.ToNumber(OldValue);

  var NewNumber := OldNumber - 1;
  if Node.Operator = TJSUpdateOperator.Increment then
    NewNumber := OldNumber + 1;

  const NewValue = TJSValue.CreateNumber(NewNumber);
  PutReferenceValue(Reference, NewValue);

  if Node.Prefix then
    Result := NewValue
  else
    Result := TJSValue.CreateNumber(OldNumber);
end;

function TJSInterpreter.VisitConditionalExpression(const Node: TJSConditionalExpression): TJSValue;
begin
  const TestValue = Visit(Node.Test);

  if TestValue.ToBoolean then
    Result := Visit(Node.Consequent)
  else
    Result := Visit(Node.Alternate);
end;

function TJSInterpreter.VisitCallExpression(const Node: TJSCallExpression): TJSValue;
begin
  var ThisObj: IJSObject := nil;
  var ThisValue := TJSValue.CreateUndefined;
  var Args: TArray<TJSValue>;
  var ArgsEvaluated := False;

  if Node.Callee is TJSMemberExpression then
  begin
    const MemberExpr = TJSMemberExpression(Node.Callee);
    const ObjValue = Visit(MemberExpr.Object_);
    ThisValue := ObjValue;

    var MethodName: string;

    if MemberExpr.Computed then
      MethodName := VisitText(MemberExpr.Property_)
    else
      MethodName := TJSIdentifier(MemberExpr.Property_).Name;

    SetLength(Args, Node.Arguments.Count);
    for var Index := 0 to Node.Arguments.Count - 1 do
      Args[Index] := Visit(Node.Arguments[Index]);
    ArgsEvaluated := True;

    if ObjValue.IsArray and TJSBuiltins.HasArrayMethod(MethodName) then
    begin
      var ArrIntf: IJSArray;
      if Supports(ObjValue.ToObject, IJSArray, ArrIntf) then
        Exit(ExecuteArrayMethod(ArrIntf, MethodName, Args));
    end;

    if ObjValue.IsFunction and TJSBuiltins.HasFunctionMethod(MethodName) then
    begin
      var FuncIntf: IJSFunction;
      if Supports(ObjValue.ToObject, IJSFunction, FuncIntf) then
        Exit(ExecuteFunctionMethod(FuncIntf, MethodName, Args));
    end;

    if ObjValue.IsObject and TJSBuiltins.HasObjectMethod(MethodName) then
      Exit(TJSBuiltins.CallObjectMethod(ObjValue.ToObject, MethodName, Args, FLimits));

    if ObjValue.IsObject then
      ThisObj := ObjValue.ToObject;
  end;

  const CalleeValue = Visit(Node.Callee);

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  if not ArgsEvaluated then
  begin
    SetLength(Args, Node.Arguments.Count);
    for var Index := 0 to Node.Arguments.Count - 1 do
      Args[Index] := Visit(Node.Arguments[Index]);
  end;

  if IsDirectEvalCall(Node.Callee, Func) then
    Exit(CallDirectEval(Func, Args));

  if not Assigned(ThisObj) then
    ThisObj := WithObjectFor(Node.Callee);

  if not Assigned(ThisObj) then
    ThisObj := ThisObjectFor(Func, ThisValue);

  Result := CallFunction(Func, Args, ThisObj);
end;

procedure TJSInterpreter.RequireObjectCoercible(const Value: TJSValue; const PropName: string);
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ACCESS_PROPERTY, [PropName]));
end;

function TJSInterpreter.VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
begin
  var Reference := ResolveMemberReference(Node);

  Result := GetReferenceValue(Reference);
end;

function TJSInterpreter.ResolveMemberReference(const Node: TJSMemberExpression): TJSMemberReference;
begin
  Result.Base := Visit(Node.Object_);
  Result.HasKeyText := not Node.Computed;

  if Node.Computed then
    Result.Key := Visit(Node.Property_)
  else
    Result.KeyText := TJSIdentifier(Node.Property_).Name;
end;

function TJSInterpreter.DescribeReferenceKey(const Reference: TJSMemberReference): string;
begin
  if Reference.HasKeyText then
    Exit(Reference.KeyText);

  if Reference.Key.IsObject then
    Exit(OBJECT_KEY_DESCRIPTION);

  Result := ToText(Reference.Key);
end;

function TJSInterpreter.ToPropertyKey(const Key: TJSValue): string;
begin
  const NeedsConversion = Key.IsObject and (not Key.IsArray);
  if NeedsConversion then
  begin
    const Primitive = Key.ToPrimitive(True);
    Result := ToText(Primitive);
    Exit;
  end;

  Result := ToText(Key);
end;

procedure TJSInterpreter.ResolveReferenceKey(var Reference: TJSMemberReference);
begin
  if Reference.HasKeyText then
    Exit;

  Reference.KeyText := ToPropertyKey(Reference.Key);
  Reference.HasKeyText := True;
end;

function TJSInterpreter.GetReferenceValue(var Reference: TJSMemberReference): TJSValue;
begin
  RequireObjectCoercible(Reference.Base, DescribeReferenceKey(Reference));
  ResolveReferenceKey(Reference);

  Result := ReadMember(Reference.Base, Reference.KeyText);
end;

procedure TJSInterpreter.PutReferenceValue(var Reference: TJSMemberReference; const Value: TJSValue);
begin
  RequireObjectCoercible(Reference.Base, DescribeReferenceKey(Reference));
  ResolveReferenceKey(Reference);

  WriteMember(Reference.Base, Reference.KeyText, Value);
end;

function TJSInterpreter.ReadMember(const Base: TJSValue; const PropName: string): TJSValue;
begin
  if Base.IsArray then
  begin
    var ArrIntf: IJSArray;
    if Supports(Base.ToObject, IJSArray, ArrIntf) then
    begin
      if PropName = LENGTH_PROPERTY then
      begin
        Result := TJSValue.CreateNumber(ArrIntf.Length);
        Exit;
      end;

      var Index: Integer;

      const IsPlainElement = TryStrToInt(PropName, Index) and ArrIntf.HasElement(Index);
      if IsPlainElement then
      begin
        Result := ArrIntf[Index];
        Exit;
      end;
    end;
  end;

  if Base.IsString then
  begin
    const Str = Base.AsString;

    if PropName = LENGTH_PROPERTY then
    begin
      Result := TJSValue.CreateNumber(Length(Str));
      Exit;
    end;

    var Index: Integer;

    if TryStrToInt(PropName, Index) then
    begin
      if (Index >= 0) and (Index < Length(Str)) then
      begin
        Result := TJSValue.CreateString(Str[Index + 1]);
        Exit;
      end;
    end;
  end;

  if Base.IsObject then
  begin
    Result := Base.ToObject.GetProperty(PropName);
    Exit;
  end;

  const PrimitivePrototype = PrimitivePrototypeFor(Base);
  if Assigned(PrimitivePrototype) then
  begin
    Result := PrimitivePrototype.GetProperty(PropName);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.VisitNewExpression(const Node: TJSNewExpression): TJSValue;
begin
  const CalleeValue = Visit(Node.Callee);

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  if not Func.IsConstructor then
    raise TJSErrorFactory.NotAConstructor(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  var Args: TArray<TJSValue>;
  SetLength(Args, Node.Arguments.Count);

  for var Index := 0 to Node.Arguments.Count - 1 do
  begin
    Args[Index] := Visit(Node.Arguments[Index]);
  end;

  Result := Construct(Func, Args);
end;

function TJSInterpreter.Construct(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
begin
  var Bound: TJSBoundFunction;
  if FBoundFunctions.TryGetValue(Pointer(Func as IInterface), Bound) then
    Exit(Construct(Bound.Target, Bound.Arguments + Args));

  const NewObj = CreateInstanceFor(Func);
  const ReturnValue = CallFunction(Func, Args, NewObj);

  if ReturnValue.IsObject then
    Result := ReturnValue
  else
    Result := TJSValue.CreateObject(NewObj);
end;

function TJSInterpreter.VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  for var Expr in Node.Expressions do
  begin
    Result := Visit(Expr);
  end;
end;

function TJSInterpreter.VisitThisExpression(const Node: TJSThisExpression): TJSValue;
begin
  if Assigned(FThisValue) then
    Result := TJSValue.CreateObject(FThisValue)
  else if FStrictMode and (FCallDepth > 0) then
    Result := TJSValue.CreateUndefined
  else
    Result := TJSValue.CreateObject(FGlobalObject);
end;

function TJSInterpreter.ToText(const Value: TJSValue): string;
begin
  Result := Value.ToLimitedString(FLimits);
end;

function TJSInterpreter.VisitText(const Node: TJSASTNode): string;
begin
  const Value = Visit(Node);

  Result := ToText(Value);
end;

function TJSInterpreter.WithArrayPrototype(const Value: TJSValue): TJSValue;
begin
  Result := Value;

  var Arr: IJSArray;
  const IsArray = Value.IsArray and Supports(Value.ToObject, IJSArray, Arr);
  if not IsArray then
    Exit;

  const HasPrototype = Assigned(Arr.Prototype);
  if not HasPrototype then
    Arr.Prototype := FArrayPrototype;
end;

function TJSInterpreter.CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
begin
  ConsumeStep;

  if Func.IsNative then
    Exit(WithArrayPrototype(Func.NativeFunction(ThisObj, Args)));

  if (FLimits.MaxCallDepth > 0) and (FCallDepth >= FLimits.MaxCallDepth) then
    raise EJSCallDepthExceeded.Create(FLimits.MaxCallDepth);

  const OldThis = FThisValue;
  const OldStrictMode = FStrictMode;
  const OldScope = FCurrentScope;
  FThisValue := ThisObj;
  FStrictMode := Func.IsStrict;

  var ParentScope: IJSScope;
  if Assigned(Func.ClosureScope) then
    ParentScope := Func.ClosureScope
  else
    ParentScope := FGlobalScope;

  FCurrentScope := TJSScope.Create(ParentScope);
  RegisterScope(FCurrentScope);
  Inc(FCallDepth);
  try
    if ReferencesArguments(Func) then
    begin
      FCurrentScope.DeclareVariable(ARGUMENTS_NAME, TJSValue.CreateObject(CreateArgumentsObject(Args, Func)));
    end;

    for var Index := 0 to Length(Func.Parameters) - 1 do
    begin
      if Index < Length(Args) then
        FCurrentScope.DeclareVariable(Func.Parameters[Index], Args[Index])
      else
        FCurrentScope.DeclareVariable(Func.Parameters[Index], TJSValue.CreateUndefined);
    end;

    HoistDeclarations(TJSASTNode(Func.BodyNode));

    try
      Visit(TJSASTNode(Func.BodyNode));
      Result := TJSValue.CreateUndefined;
    except
      on E: TJSReturnSignal do
        Result := E.Value;
    end;
  finally
    Dec(FCallDepth);
    FCurrentScope := OldScope;
    FThisValue := OldThis;
    FStrictMode := OldStrictMode;
  end;
end;

function TJSInterpreter.CreateCallbackExecutor(const MethodName: string; const Args: TArray<TJSValue>): TJSCallbackExecutor;
begin
  const HasThisArg = TJSBuiltins.TakesCallbackThis(MethodName) and (Length(Args) > 1);
  var ThisValue := TJSValue.CreateUndefined;
  if HasThisArg then
    ThisValue := Args[1];

  Result :=
    function(const Func: IJSFunction; const CallbackArgs: TArray<TJSValue>): TJSValue
    begin
      const ThisArg = ThisObjectFor(Func, ThisValue);
      Result := CallFunction(Func, CallbackArgs, ThisArg);
    end;
end;

function TJSInterpreter.ExecuteArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSArrayIteration.Handles(MethodName) then
    Exit(ExecuteArrayIterationMethod(Arr, MethodName, Args));

  if not TJSBuiltins.RequiresCallback(MethodName) then
    Exit(WithArrayPrototype(TJSBuiltins.CallArrayMethod(Arr, MethodName, Args, FLimits)));

  const Executor = CreateCallbackExecutor(MethodName, Args);
  Result := WithArrayPrototype(TJSBuiltins.CallArrayMethodWithCallback(Arr, MethodName, Args, Executor, FLimits));
end;

function TJSInterpreter.ExecuteArrayIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Executor = CreateCallbackExecutor(MethodName, Args);
  Result := TJSArrayIteration.Call(Target, MethodName, Args, Executor, FArrayPrototype);
end;

function TJSInterpreter.ExecuteFunctionMethod(const Func: IJSFunction; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_CALL then
  begin
    var ThisArg: IJSObject := nil;
    if Length(Args) > 0 then
      ThisArg := ThisObjectFor(Func, Args[0]);

    var FuncArgs: TArray<TJSValue>;
    if Length(Args) > 1 then
    begin
      SetLength(FuncArgs, Length(Args) - 1);
      for var Index := 1 to Length(Args) - 1 do
      begin
        FuncArgs[Index - 1] := Args[Index];
      end;
    end;

    Exit(CallFunction(Func, FuncArgs, ThisArg));
  end;

  if MethodName = METHOD_APPLY then
  begin
    var ThisArg: IJSObject := nil;
    if Length(Args) > 0 then
      ThisArg := ThisObjectFor(Func, Args[0]);

    var FuncArgs: TArray<TJSValue>;
    const HasArgsArray = (Length(Args) > 1) and Args[1].IsArray;
    if HasArgsArray then
    begin
      var ArgsArrayIntf: IJSArray;
      if Supports(Args[1].ToObject, IJSArray, ArgsArrayIntf) then
      begin
        SetLength(FuncArgs, ArgsArrayIntf.Length);
        for var Index := 0 to ArgsArrayIntf.Length - 1 do
        begin
          FuncArgs[Index] := ArgsArrayIntf[Index];
        end;
      end;
    end;

    Exit(CallFunction(Func, FuncArgs, ThisArg));
  end;

  if MethodName = METHOD_BIND then
  begin
    var BoundThis: IJSObject := nil;
    if Length(Args) > 0 then
      BoundThis := ThisObjectFor(Func, Args[0]);

    var BoundArgs: TArray<TJSValue>;
    if Length(Args) > 1 then
    begin
      SetLength(BoundArgs, Length(Args) - 1);
      for var Index := 1 to Length(Args) - 1 do
        BoundArgs[Index - 1] := Args[Index];
    end;

    const OriginalFunc = Func;
    const CapturedThis = BoundThis;
    const CapturedArgs = BoundArgs;
    const Interp = Self;

    const BoundFunc: IJSFunction = TJSFunction.CreateNative('bound',
      function(const This: IJSObject; const CallArgs: TArray<TJSValue>): TJSValue
      begin
        var AllArgs: TArray<TJSValue>;
        SetLength(AllArgs, Length(CapturedArgs) + Length(CallArgs));

        for var Index := 0 to Length(CapturedArgs) - 1 do
          AllArgs[Index] := CapturedArgs[Index];

        for var Index := 0 to Length(CallArgs) - 1 do
          AllArgs[Length(CapturedArgs) + Index] := CallArgs[Index];

        Result := Interp.CallFunction(OriginalFunc, AllArgs, CapturedThis);
      end);

    BoundFunc.ClosureScope := nil;
    BoundFunc.IsConstructor := OriginalFunc.IsConstructor;
    TJSFunction.DefineLength(BoundFunc, BoundLength(OriginalFunc, Length(CapturedArgs)));
    RegisterFunction(BoundFunc);
    var BoundInfo: TJSBoundFunction;
    BoundInfo.Target := OriginalFunc;
    BoundInfo.Arguments := CapturedArgs;
    FBoundFunctions.Add(Pointer(BoundFunc as IInterface), BoundInfo);
    Result := TJSValue.CreateObject(BoundFunc);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

procedure TJSInterpreter.WriteMember(const Base: TJSValue; const PropName: string; const Value: TJSValue);
begin
  if not Base.IsObject then
  begin
    if FStrictMode then
      raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [PropName]));

    Exit;
  end;

  var ArrIntf: IJSArray;
  if Base.IsArray and Supports(Base.ToObject, IJSArray, ArrIntf) then
  begin
    var IsHandled: Boolean;
    WriteArrayMember(ArrIntf, PropName, Value, IsHandled);
    if IsHandled then
      Exit;
  end;

  const Target = Base.ToObject;
  const IsRejected = FStrictMode and (not TJSPropertyDescriptors.CanPut(Target, PropName));
  if IsRejected then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [PropName]));

  Target.SetProperty(PropName, Value);
end;

procedure TJSInterpreter.WriteArrayMember(const Target: IJSArray; const PropName: string; const Value: TJSValue;
                                          out IsHandled: Boolean);
begin
  IsHandled := True;

  if PropName = LENGTH_PROPERTY then
  begin
    AssignArrayLength(Target, Value);
    Exit;
  end;

  var Index: Integer;
  if not TJSArray.TryParseIndex(PropName, Index) then
  begin
    IsHandled := False;
    Exit;
  end;

  const IsWritablePlainElement = Target.HasElement(Index) and (not Target.IsFrozen);
  if IsWritablePlainElement then
  begin
    Target[Index] := Value;
    Exit;
  end;

  const LengthDescriptor = Target.GetOwnPropertyDescriptor(LENGTH_PROPERTY);
  const LengthAllowsIndex = (Index < Target.Length) or LengthDescriptor.Writable;
  const CanWrite = LengthAllowsIndex and TJSPropertyDescriptors.CanPut(Target, PropName);
  if not CanWrite then
  begin
    if FStrictMode then
      raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [PropName]));

    Exit;
  end;

  FLimits.EnsureArrayLength(Int64(Index) + 1);
  Target.SetProperty(PropName, Value);
end;

procedure TJSInterpreter.AssignArrayLength(const Target: IJSArray; const Value: TJSValue);
begin
  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Value;

  const CheckedDefinition = TJSPropertyDescriptors.WithCheckedLength(Target, LENGTH_PROPERTY, Definition, FLimits);
  const IsAssigned = Target.DefineOwnProperty(LENGTH_PROPERTY, CheckedDefinition);
  if (not IsAssigned) and FStrictMode then
    raise TJSErrorFactory.TypeError(READ_ONLY_LENGTH);
end;

procedure TJSInterpreter.DeleteArrayElement(const Target: IJSObject; const PropName: string);
begin
  var TargetArray: IJSArray;
  var Index: Integer;

  const IsElement = Supports(Target, IJSArray, TargetArray) and TryStrToInt(PropName, Index);
  if IsElement then
    TargetArray.DeleteElement(Index);
end;

function TJSInterpreter.StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
begin
  Result := Left.StrictEquals(Right);
end;

function TJSInterpreter.AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
begin
  if Left.ValueType = Right.ValueType then
    Exit(StrictEquals(Left, Right));

  const BothNullOrUndefined = (Left.IsNullOrUndefined and Right.IsNullOrUndefined);
  if BothNullOrUndefined then
    Exit(True);

  const IsLeftNumRightStr = (Left.IsNumber and Right.IsString);
  if IsLeftNumRightStr then
    Exit(Left.AsNumber = Right.ToNumber);

  const IsLeftStrRightNum = (Left.IsString and Right.IsNumber);
  if IsLeftStrRightNum then
    Exit(Left.ToNumber = Right.AsNumber);

  if Left.IsBoolean then
    Exit(AbstractEquals(TJSValue.CreateNumber(Left.ToNumber), Right));

  if Right.IsBoolean then
    Exit(AbstractEquals(Left, TJSValue.CreateNumber(Right.ToNumber)));

  const IsObjectAgainstPrimitive = Left.IsObject and (Right.IsString or Right.IsNumber);
  if IsObjectAgainstPrimitive then
  begin
    const LeftPrimitive = TJSOperators.ToPrimitive(Left);
    Exit(AbstractEquals(LeftPrimitive, Right));
  end;

  const IsPrimitiveAgainstObject = Right.IsObject and (Left.IsString or Left.IsNumber);
  if IsPrimitiveAgainstObject then
  begin
    const RightPrimitive = TJSOperators.ToPrimitive(Right);
    Exit(AbstractEquals(Left, RightPrimitive));
  end;

  Result := False;
end;

function TJSInterpreter.GetCalleeDescription(const Callee: TJSASTNode; const CalleeValue: TJSValue): string;
begin
  if Callee is TJSIdentifier then
    Result := TJSIdentifier(Callee).Name
  else if Callee is TJSMemberExpression then
  begin
    const MemberExpr = TJSMemberExpression(Callee);

    if MemberExpr.Property_ is TJSIdentifier then
      Result := TJSIdentifier(MemberExpr.Property_).Name
    else
      Result := ToText(CalleeValue);
  end
  else
    Result := ToText(CalleeValue);
end;

procedure TJSInterpreter.RegisterNativeFunction(const Name: string; const Func: TNativeFunction);
begin
  const JSFunc: IJSFunction = TJSFunction.CreateNative(Name, Func);
  RegisterFunction(JSFunc);
  SetGlobalVariable(Name, TJSValue.CreateObject(JSFunc));
end;

procedure TJSInterpreter.RegisterEval(const ProgramParser: TJSProgramParser);
begin
  FProgramParser := ProgramParser;

  RegisterNativeFunction(EVAL_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const IsDirect = FDirectEvalCall;
      FDirectEvalCall := False;

      const HasSource = (Length(Args) > 0) and Args[0].IsString;
      if HasSource then
        Result := EvaluateSource(Args[0].AsString, IsDirect)
      else if Length(Args) > 0 then
        Result := Args[0]
      else
        Result := TJSValue.CreateUndefined;
    end);

  Supports(FGlobalScope.GetVariable(EVAL_NAME).ToObject, IJSFunction, FEvalFunction);
end;

procedure TJSInterpreter.SetGlobalVariable(const Name: string; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Enumerable := False;
  FGlobalObject.DefineProperty(Name, Descriptor);
end;

procedure TJSInterpreter.SetGlobalConstant(const Name: string; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  FGlobalObject.DefineProperty(Name, Descriptor);
end;

function TJSInterpreter.GetGlobalVariable(const Name: string): TJSValue;
begin
  Result := FGlobalScope.GetVariable(Name);
end;

procedure TJSInterpreter.GCMark(const Item: IInterface; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
begin
  if Item = nil then
    Exit;

  const Id = Pointer(Item as IInterface);
  if Live.ContainsKey(Id) then
    Exit;

  Live.Add(Id, 0);
  Work.Add(Item);
end;

procedure TJSInterpreter.GCMarkValue(const Value: TJSValue; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
begin
  if Value.IsObject then
    GCMark(Value.ToObject, Live, Work);
end;

procedure TJSInterpreter.GCMarkOwnProperties(const Obj: IJSObject; const Live: TDictionary<Pointer, Byte>; const Work: TList<IInterface>);
begin
  for var PropName in Obj.GetOwnPropertyNames do
  begin
    const Descriptor = Obj.GetOwnPropertyDescriptor(PropName);

    GCMarkValue(Descriptor.Value, Live, Work);
    GCMarkValue(Descriptor.Getter, Live, Work);
    GCMarkValue(Descriptor.Setter, Live, Work);
  end;
end;

procedure TJSInterpreter.CollectGarbage;
begin
  const Live = TDictionary<Pointer, Byte>.Create;
  const Work = TList<IInterface>.Create;
  try
    GCMark(FGlobalScope, Live, Work);
    GCMark(FCurrentScope, Live, Work);
    GCMark(FThisValue, Live, Work);
    GCMark(FGlobalObject, Live, Work);
    for var Func in FFunctionRegistry do
      if Func.IsNative then
        GCMark(Func, Live, Work);

    while Work.Count > 0 do
    begin
      const Item = Work.Last;
      Work.Delete(Work.Count - 1);

      var Scope: IJSScope;
      var Func: IJSFunction;
      var Arr: IJSArray;
      var Obj: IJSObject;

      if Supports(Item, IJSScope, Scope) then
      begin
        GCMark(Scope.Parent, Live, Work);
        for var Value in Scope.GetOwnVariables do
          GCMarkValue(Value, Live, Work);
      end
      else if Supports(Item, IJSFunction, Func) then
      begin
        GCMark(Func.ClosureScope, Live, Work);
        GCMark(Func.Prototype, Live, Work);
        GCMarkOwnProperties(Func, Live, Work);
      end
      else if Supports(Item, IJSArray, Arr) then
      begin
        for var ElementIndex := 0 to Arr.Length - 1 do
          GCMarkValue(Arr.Elements[ElementIndex], Live, Work);
        GCMark(Arr.Prototype, Live, Work);
        GCMarkOwnProperties(Arr, Live, Work);
      end
      else if Supports(Item, IJSObject, Obj) then
      begin
        GCMark(Obj.Prototype, Live, Work);
        GCMarkOwnProperties(Obj, Live, Work);
      end;
    end;

    for var Index := FFunctionRegistry.Count - 1 downto 0 do
    begin
      const Func = FFunctionRegistry[Index];
      if not Live.ContainsKey(Pointer(Func as IInterface)) then
      begin
        FFunctionPrograms.Remove(Pointer(Func as IInterface));
        Func.ClosureScope := nil;
        Func.NativeFunction := nil;
        DetachProperties(Func);
        FFunctionRegistry.Delete(Index);
      end;
    end;

    for var Index := FScopeRegistry.Count - 1 downto 0 do
    begin
      const Scope = FScopeRegistry[Index];
      if not Live.ContainsKey(Pointer(Scope as IInterface)) then
      begin
        Scope.ReleaseReferences;
        FScopeRegistry.Delete(Index);
      end;
    end;
  finally
    Work.Free;
    Live.Free;
  end;
end;

function TJSInterpreter.LivePrograms: TArray<TObject>;
begin
  SetLength(Result, 0);
  const Seen = TDictionary<TObject, Byte>.Create;
  try
    for var Pair in FFunctionPrograms do
      if (Pair.Value <> nil) and not Seen.ContainsKey(Pair.Value) then
      begin
        Seen.Add(Pair.Value, 0);
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := Pair.Value;
      end;
  finally
    Seen.Free;
  end;
end;

end.
