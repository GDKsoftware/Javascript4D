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
  JS4D.ArgumentsObject,
  JS4D.GlobalScope,
  JS4D.PropertyDescriptors,
  JS4D.LexicalStates,
  JS4D.ArrayIteration,
  JS4D.ArrayIterator,
  JS4D.IteratorProtocol,
  JS4D.StringIterator,
  JS4D.ArrayStatics,
  JS4D.ArrayGeneric,
  JS4D.ArrayLike,
  JS4D.ObjectKeys,
  JS4D.ObjectOperations,
  JS4D.BinaryData,
  JS4D.ProxyObjects,
  JS4D.SymbolRegistry,
  JS4D.Operators;

type
  TJSScope = class(TInterfacedObject, IJSScope)
  private
    FVariables: TDictionary<string, TJSValue>;
    FParent: IJSScope;
    FLexicalStates: TJSLexicalStates;
    FDeletableNames: TDictionary<string, Byte>;

    function HasLexicalState(const Name: string): Boolean;
    function IsDeletableName(const Name: string): Boolean;

  protected
    function GetParent: IJSScope;

  public
    constructor Create(const Parent: IJSScope);
    destructor Destroy; override;

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    function TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    procedure AssignVariable(const Name: string; const Value: TJSValue);
    procedure DeclareLexical(const Name: string; const IsConstant: Boolean);
    procedure InitializeLexical(const Name: string; const Value: TJSValue);
    function CloneForIteration: TJSScope;
    function IsLexicalBinding(const Name: string): Boolean;
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;

    property Parent: IJSScope read GetParent;
  end;

  TJSFunctionNameScope = class(TJSScope);

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

  TJSStrictThis = class(TJSObjectImpl)
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

  TJSBindingMode = (Assign, Variable, Lexical);

  // The groups of built-in methods that a call expression runs directly, as long as the method that the
  // property lookup finds is still the built-in one.
  TJSIntrinsicGroup = (ArrayMethod, FunctionMethod, ObjectMethod);

  TJSPatternTarget = record
    Target: TJSExpression;
    Default: TJSExpression;
    Binding: IJSScope;
    Reference: TJSMemberReference;
  end;

  // The built-in functions and prototypes that the iteration fast paths compare against, to see that a
  // script has not replaced the iterator protocol of arrays, arguments objects or strings.
  TJSIterationIntrinsics = record
    ArrayIteratorPrototype: IJSObject;
    ArrayValues: IInterface;
    ArrayIteratorNext: IInterface;
    StringIteratorPrototype: IJSObject;
    StringIterator: IInterface;
    StringIteratorNext: IInterface;
  end;

  // Remembers where a built-in method sits in the property storage of its holder, so that checking it again
  // costs no hash lookup while the holder keeps the same layout.
  TJSIntrinsicSlot = record
    Holder: TJSObjectImpl;
    Version: Cardinal;
    Slot: PJSPropertyDescriptor;
  end;

  // Where the values of an iterable come from: the elements of an array or arguments object and the code
  // points of a string are read directly, anything else goes through the iterator protocol.
  TJSIterationSource = record
    Elements: IJSArray;
    ArrayLike: IJSObject;
    Protocol: IJSIteratorRecord;
    Items: TArray<TJSValue>;
    Position: Integer;

    function HasNext: Boolean;
    function Next: TJSValue;
    function Remaining: TArray<TJSValue>;
    procedure Close;
    procedure CloseAfterThrow;
  end;

  TJSInterpreter = class(TJSCallHandler)
  private
    FGlobalScope: IJSScope;
    FGlobalBindings: TJSGlobalScope;
    FCurrentScope: IJSScope;
    FThisValue: IJSObject;
    FThisPrimitive: TJSStrictThis;
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
    FSymbolPrototype: IJSObject;
    FIteration: TJSIterationIntrinsics;
    FIntrinsicMethods: array[TJSIntrinsicGroup] of TDictionary<string, IJSObject>;
    FArrayValuesSlot: TJSIntrinsicSlot;
    FArrayNextSlot: TJSIntrinsicSlot;
    FStringIteratorSlot: TJSIntrinsicSlot;
    FStringNextSlot: TJSIntrinsicSlot;
    FOrdinaryHasInstance: IJSFunction;
    FArrayConstructor: IJSFunction;
    FArraySpeciesGetter: IJSFunction;
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
    FVarScope: IJSScope;
    FIsGuardingGlobalVariables: Boolean;
    FEvalCallerScope: IJSScope;
    FParameterInitScope: IJSScope;
    FLoopLabels: TArray<string>;

    procedure SetFunctionPrototype(const Value: IJSObject);
    procedure PushScope;
    procedure PopScope;
    procedure RegisterScope(const Scope: IJSScope);
    procedure AttachPrototype(const Func: IJSFunction);
    function ReferencesArguments(const Func: IJSFunction): Boolean;
    function CreateArgumentsObject(const Args: TArray<TJSValue>; const Func: IJSFunction): IJSObject;
    procedure DefineArgumentsIterator(const ArgumentsObject: IJSObject);
    procedure AssignParameters(const Func: TJSFunction; const Params: TObjectList<TJSIdentifier>;
                               const Info: TJSParameterInfo);
    function ParameterInfoOf(const Func: IJSFunction): TJSParameterInfo;
    function BindParametersWithExpressions(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                           const Info: TJSParameterInfo): IJSScope;
    procedure DeclareParameterBindings(const Func: IJSFunction; const Info: TJSParameterInfo);
    procedure InitializeParameterBindings(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                          const Info: TJSParameterInfo);
    procedure StoreParameter(const Name: string; const Value: TJSValue; const IsLexical: Boolean);
    function CreateRestArray(const Args: TArray<TJSValue>; const FirstIndex: Integer): TJSValue;
    procedure CopyParametersToBodyScope(const Func: IJSFunction; const ParameterScope: IJSScope;
                                        const Info: TJSParameterInfo);
    procedure CopyParameterToBodyScope(const Name: string; const ParameterScope: IJSScope);
    procedure BindTarget(const Target: TJSExpression; const Value: TJSValue; const Mode: TJSBindingMode);
    function ResolvePatternTarget(const Element: TJSExpression; const Mode: TJSBindingMode): TJSPatternTarget;
    procedure StorePatternTarget(const Target: TJSPatternTarget; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure StoreIdentifier(const Target: TJSPatternTarget; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindArrayPattern(const Pattern: TJSArrayPattern; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindObjectPattern(const Pattern: TJSObjectPattern; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindArrayElements(const Pattern: TJSArrayPattern; var Source: TJSIterationSource;
                                const Mode: TJSBindingMode);
    function OpenIterationSource(const Value: TJSValue): TJSIterationSource;
    function TryOpenIterationSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function TryOpenFastSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function TryOpenProtocolSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function FindIteratorMethod(const Value: TJSValue; out IteratorFunction: IJSFunction): Boolean;
    function OpenProtocolSource(const Value: TJSValue; const IteratorFunction: IJSFunction): TJSIterationSource;
    function IsIntrinsic(const Candidate: TJSValue; const Original: IInterface): Boolean;
    function IsIntrinsicProperty(const Start: IJSObject; const Key: string; const Original: IInterface): Boolean;
    function HoldsIntrinsic(var Cache: TJSIntrinsicSlot; const Holder: IJSObject; const Key: string;
                            const Original: IInterface): Boolean;
    function HasPlainArrayPrototype(const Target: IJSObject; const Key: string): Boolean;
    function HasUntouchedArrayIteration(const Target: IJSObject): Boolean;
    function HasUntouchedStringIteration: Boolean;
    function RunForOfLoop(const Node: TJSForOfStatement; const OuterScope: IJSScope;
                          const OwnLabels: TArray<string>; var Source: TJSIterationSource): TJSValue;
    function OpenStringSource(const Text: string): TJSIterationSource;
    function CopyRestProperties(const Source: TJSValue; const Excluded: TList<string>): TJSValue;
    procedure CopyDataProperties(const Target: IJSObject; const Source: TJSValue; const Excluded: TList<string>);
    function AssignToPattern(const Node: TJSAssignmentExpression): TJSValue;
    procedure DeclareLexicalBinding(const Declarator: TJSVariableDeclarator; const IsConstant: Boolean);
    procedure HoistDeclarator(const Declarator: TJSVariableDeclarator);
    function VisitArrayWithSpread(const Node: TJSArrayExpression): TJSValue;
    function EvaluateArguments(const Nodes: TObjectList<TJSExpression>; const HasSpread: Boolean): TArray<TJSValue>;
    function EvaluateSpreadArguments(const Nodes: TObjectList<TJSExpression>): TArray<TJSValue>;
    procedure AppendSpreadValues(const Source: TJSValue; const Target: TList<TJSValue>);
    procedure AppendStringValues(const Source: string; const Target: TList<TJSValue>);
    function CreateThrowTypeError: IJSFunction;
    function CreateCalleeDescriptor: TJSPropertyDescriptor;
    procedure DetachProperties(const Func: IJSFunction);
    function IsInPrototypeChain(const Instance: IJSObject; const Constructor_: IJSFunction): Boolean;
    function IsInstanceOfBuiltinConstructor(const Instance: IJSObject; const Constructor_: IJSFunction): Boolean;
    function IsInstanceOfErrorConstructor(const Instance: IJSObject; const ConstructorName: string): Boolean;
    function EvaluateInstanceOf(const Left: TJSValue; const Right: TJSValue; const Node: TJSBinaryExpression): Boolean;
    function EvaluateIn(const Left: TJSValue; const Right: TJSValue; const Node: TJSBinaryExpression): Boolean;
    function CreateInstanceFor(const Constructor_: IJSFunction): IJSObject;
    procedure RequireLiveProxy(const Constructor_: IJSFunction);
    function PrimitivePrototypeFor(const Value: TJSValue): IJSObject;
    function ArgumentsFromList(const ArgumentList: TJSValue): TArray<TJSValue>;
    function UnwrapBoundFunction(const Func: IJSFunction): IJSFunction;
    function CreateBoundFunction(const Target: IJSFunction; const BoundThis: IJSObject;
                                 const BoundArgs: TArray<TJSValue>): IJSFunction;

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
    procedure InstantiateTopLevel(const Statements: TObjectList<TJSStatement>; const ScopeInfo: TJSScopeInfo);
    procedure DeclareTopLevelLexicals(const ScopeInfo: TJSScopeInfo);
    procedure DeclareLexicalNames(const Declaration: TJSVariableDeclaration);
    procedure EnsureGlobalLexicalAvailable(const Name: string);
    procedure EnsureNoGlobalLexicalConflict(const Name: string);
    procedure HoistStatement(const Node: TJSStatement);
    procedure HoistVarNames(const Node: TJSASTNode);
    procedure HoistVariable(const Name: string);
    procedure EnsureNoEvalLexicalConflict(const Name: string);
    procedure EnterLexicalScope(const ScopeInfo: TJSScopeInfo);
    function VisitScopedBlock(const Node: TJSBlockStatement): TJSValue;
    function CreateFunctionObject(const Node: TJSFunctionDeclaration): IJSFunction;
    function VisitFunctionDeclaration(const Node: TJSFunctionDeclaration): TJSValue;
    function IsLexicalDeclaration(const Node: TJSASTNode): Boolean;
    function VisitLexicalForStatement(const Node: TJSForStatement; const OwnLabels: TArray<string>): TJSValue;
    function RunForLoop(const Node: TJSForStatement; const OwnLabels: TArray<string>;
                        const CopiesIterationScope: Boolean): TJSValue;
    procedure AdvanceForLoop(const Node: TJSForStatement; const CopiesIterationScope: Boolean);
    procedure CopyIterationScope;
    function EvaluateForInSubject(const Node: TJSForInStatement): TJSValue;
    function CollectEnumerableKeys(const Subject: IJSObject): TArray<string>;
    procedure AssignLoopVariable(const Node: TJSForInStatement; const OuterScope: IJSScope; const Value: TJSValue);
    procedure BindLexicalLoopVariable(const Node: TJSForInStatement; const Declaration: TJSVariableDeclaration;
                                      const OuterScope: IJSScope; const Value: TJSValue);
    function RunLoopBody(const Body: TJSStatement; const OwnLabels: TArray<string>; out KeepLooping: Boolean): TJSValue;
    function ExecuteSwitchCases(const Node: TJSSwitchStatement; const DiscriminantValue: TJSValue): TJSValue;
    function VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
    function VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
    procedure DeclareFunction(const Node: TJSFunctionDeclaration);
    function VisitExpressionStatement(const Node: TJSExpressionStatement): TJSValue;
    function VisitIfStatement(const Node: TJSIfStatement): TJSValue;
    function VisitWhileStatement(const Node: TJSWhileStatement): TJSValue;
    function VisitDoWhileStatement(const Node: TJSDoWhileStatement): TJSValue;
    function VisitWithStatement(const Node: TJSWithStatement): TJSValue;
    procedure GuardStrictAssignmentTarget(const Node: TJSAssignmentExpression);
    procedure GuardGlobalDeclarations(const Node: TJSProgram);
    procedure GuardGlobalFunctionDeclaration(const Declaration: TJSFunctionDeclaration);
    procedure GuardGlobalVariableDeclarations(const Node: TJSProgram);
    procedure DeclareGlobalFunction(const Name: string; const Value: TJSValue);
    function VisitLabeledStatement(const Node: TJSLabeledStatement): TJSValue;
    function TakeLoopLabels: TArray<string>;
    function ToScopeObject(const Value: TJSValue): IJSObject;
    function WithArrayPrototype(const Value: TJSValue): TJSValue;
    function VisitCalleeIdentifier(const Identifier: TJSIdentifier; out ThisObj: IJSObject): TJSValue;
    function VisitForStatement(const Node: TJSForStatement): TJSValue;
    function VisitForInStatement(const Node: TJSForInStatement): TJSValue;
    function VisitForOfStatement(const Node: TJSForOfStatement): TJSValue;
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
    function LiteralPropertyName(const Prop: TJSObjectProperty; out KeyHolder: TJSValue): string;
    class function FunctionNameForKey(const Key: string): string; static;
    procedure DefineLiteralData(const Target: IJSObject; const Name: string; const Prop: TJSObjectProperty);
    procedure DefineLiteralMethod(const Target: IJSObject; const Name: string; const Prop: TJSObjectProperty);
    procedure DefineLiteralAccessor(const Target: IJSObject; const Name: string; const Prop: TJSObjectProperty);
    procedure AssignLiteralPrototype(const Target: IJSObject; const Prop: TJSObjectProperty);
    function VisitNamed(const Node: TJSExpression; const Name: string): TJSValue;
    function VisitAssigned(const Value: TJSExpression; const Target: TJSIdentifier): TJSValue;
    function IsAnonymousFunctionDefinition(const Node: TJSExpression): Boolean;
    function CreateMethodFunction(const Node: TJSFunctionExpression; const Name: string): IJSFunction;
    function CreateOrdinaryFunction(const Node: TJSFunctionExpression): IJSFunction;
    function VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
    function VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
    function VisitDeleteExpression(const Node: TJSUnaryExpression): TJSValue;
    function DeleteMember(const Node: TJSUnaryExpression; const MemberExpr: TJSMemberExpression): TJSValue;
    function DeleteProxyMember(const Node: TJSUnaryExpression; const Proxy: IJSProxy;
                               const PropName: string): TJSValue;
    function IsUndeclaredIdentifier(const Node: TJSExpression): Boolean;
    function DeleteIdentifier(const Name: string): Boolean;
    procedure DeclareBinding(const Name: string; const Value: TJSValue);
    function VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
    function VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
    function VisitAssignmentExpression(const Node: TJSAssignmentExpression): TJSValue;
    function GlobalDataSlot(const Identifier: TJSIdentifier): PJSPropertyDescriptor;
    procedure StoreGlobalVariable(const Identifier: TJSIdentifier; const Value: TJSValue);
    function AssignToGlobalVariable(const Node: TJSAssignmentExpression; const Identifier: TJSIdentifier): TJSValue;
    function UpdateGlobalVariable(const Node: TJSUpdateExpression; const Identifier: TJSIdentifier): TJSValue;
    function AssignToIdentifier(const Node: TJSAssignmentExpression): TJSValue;
    function GetBindingValue(const Binding: IJSScope; const Name: string): TJSValue;
    procedure PutIdentifierValue(const Binding: IJSScope; const Name: string; const Value: TJSValue);
    procedure GuardBindingStillExists(const StillExists: Boolean; const Name: string);
    procedure GuardGlobalWritable(const Name: string);
    procedure RejectFunctionNameAssignment;
    procedure BindFunctionName(const Func: IJSFunction; const Name: string);
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
    function ReadPrimitiveMember(const Base: TJSValue; const PrimitivePrototype: IJSObject;
                                 const PropName: string): TJSValue;
    function StrictPrimitiveThis(const ThisObj: IJSObject; const IsStrict: Boolean): TJSStrictThis;
    procedure WriteMember(const Base: TJSValue; const PropName: string; const Value: TJSValue);
    procedure WriteArrayMember(const Target: IJSArray; const PropName: string; const Value: TJSValue;
                               out IsHandled: Boolean);
    function VisitNewExpression(const Node: TJSNewExpression): TJSValue;
    function VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
    function VisitThisExpression(const Node: TJSThisExpression): TJSValue;
    function VisitTemplateLiteral(const Node: TJSTemplateLiteral): TJSValue;
    function VisitTemplateObject(const Node: TJSTemplateObject): TJSValue;
    function CreateTemplateObject(const Node: TJSTemplateObject): IJSArray;
    function ToStringCoerced(const Value: TJSValue): string;
    function CurrentThisObject: IJSObject;
    function CreateArrowFunction(const Node: TJSFunctionExpression): IJSFunction;

    function ToText(const Value: TJSValue): string;
    function VisitText(const Node: TJSASTNode): string;
    function StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    procedure AssignArrayLength(const Target: IJSArray; const Value: TJSValue);
    procedure DeleteArrayElement(const Target: IJSObject; const PropName: string);
    function CreateCallbackExecutor(const MethodName: string; const Args: TArray<TJSValue>): TJSCallbackExecutor;
    function AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    function ExecuteArrayMethodCore(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteArrayIterationMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                                             const BeforeElements: TProc): TJSValue;
    function ExecuteSpeciesIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteGenericArrayMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function InvokeMethod(const Target: TJSValue; const MethodName: string): TJSValue;
    function PrototypeHoldsElements: Boolean;
    function CreatesSpeciesResult(const MethodName: string): Boolean;
    function ResolveArraySpecies(const Target: IJSObject; const MethodName: string): IJSFunction;
    function CopyToSpeciesResult(const Species: IJSFunction; const Plain: TJSValue; const MethodName: string): TJSValue;
    function GetCalleeDescription(const Callee: TJSASTNode; const CalleeValue: TJSValue): string;
    function BoundLength(const Target: IJSFunction; const BoundArgumentCount: Integer): Double;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Program_: TJSProgram): TJSValue;
    function CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue; override;
    procedure Cancel;
    procedure RegisterFunction(const Func: IJSFunction);
    procedure RegisterIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string; const Method: IJSObject);
    function IsIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string; const Callee: TJSValue): Boolean;
    function OrdinaryHasInstance(const Constructor_: IJSFunction; const Value: TJSValue;
                                 const Line: Integer = 0; const Column: Integer = 0): Boolean;
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
    function ExecuteGenericArrayMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteArrayStaticMethod(const ThisObj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function Construct(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue; overload;
    function Construct(const Func: IJSFunction; const Args: TArray<TJSValue>;
                       const NewTarget: IJSFunction): TJSValue; overload;
    function OpenSequenceReader(const Source: TJSValue; out Reader: TJSSequenceReader;
                                out Closer: TJSSequenceCloser): Boolean;
    function WrapPrimitive(const Value: TJSValue): IJSObject;
    function ThisObjectFor(const Func: IJSFunction; const ThisValue: TJSValue): IJSObject;

    property GlobalScope: IJSScope read FGlobalScope;
    property GlobalObject: IJSObject read FGlobalObject;
    property ObjectPrototype: IJSObject read FObjectPrototype write FObjectPrototype;
    property ArrayPrototype: IJSObject read FArrayPrototype write FArrayPrototype;
    property FunctionPrototype: IJSObject read FFunctionPrototype write SetFunctionPrototype;
    property RegExpPrototype: IJSObject read FRegExpPrototype write FRegExpPrototype;
    property StringPrototype: IJSObject read FStringPrototype write FStringPrototype;
    property NumberPrototype: IJSObject read FNumberPrototype write FNumberPrototype;
    property BooleanPrototype: IJSObject read FBooleanPrototype write FBooleanPrototype;
    property SymbolPrototype: IJSObject read FSymbolPrototype write FSymbolPrototype;
    property Iteration: TJSIterationIntrinsics read FIteration write FIteration;
    property OrdinaryHasInstanceFunction: IJSFunction read FOrdinaryHasInstance write FOrdinaryHasInstance;
    property ArrayConstructor: IJSFunction read FArrayConstructor write FArrayConstructor;
    property ArraySpeciesGetter: IJSFunction read FArraySpeciesGetter write FArraySpeciesGetter;
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
  SYMBOL_TYPE = 'symbol';
  OBJECT_TYPE = 'object';
  BOOLEAN_TYPE = 'boolean';
  NUMBER_TYPE = 'number';
  STRING_TYPE = 'string';
  FUNCTION_TYPE = 'function';
  LENGTH_PROPERTY = 'length';
  NAME_PROPERTY = 'name';
  BOUND_NAME_PREFIX = 'bound ';
  GETTER_NAME_FORMAT = 'get %s';
  SETTER_NAME_FORMAT = 'set %s';
  SYMBOL_FUNCTION_NAME = '[%s]';
  METHOD_FILTER = 'filter';
  METHOD_CONCAT = 'concat';
  METHOD_FLAT = 'flat';
  METHOD_FLAT_MAP = 'flatMap';
  RAW_PROPERTY = 'raw';
  PROTOTYPE_PROPERTY = 'prototype';
  CONSTRUCTOR_PROPERTY = 'constructor';
  ARGUMENTS_NAME = 'arguments';
  READ_ONLY_LENGTH = 'Cannot assign to read only property ''length''';
  EVAL_NAME = 'eval';
  CANNOT_ACCESS_PROPERTY = 'Cannot access property ''%s'' of undefined or null';
  REVOKED_CONSTRUCTOR = 'Cannot construct with a revoked proxy';
  CANNOT_ASSIGN_PROPERTY = 'Cannot assign to property ''%s'' in strict mode';
  OBJECT_KEY_DESCRIPTION = '[object]';
  POISONED_PROPERTY = 'Restricted property cannot be accessed in strict mode';
  FUNCTION_NAME_ASSIGNMENT = 'Assignment to the name of a function expression';
  CALLEE_PROPERTY = 'callee';
  EMPTY_NAME = '';
  INVALID_FUNCTION_SOURCE = 'Invalid function parameters or body';
  METHOD_CALL = 'call';
  METHOD_APPLY = 'apply';
  METHOD_BIND = 'bind';
  ARGUMENT_LIST_NOT_OBJECT = 'Function.prototype.apply requires an array-like object as argument list';

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
  EMPTY_COMPLETION_NODES = [TJSASTNodeType.VariableDeclaration,
                            TJSASTNodeType.FunctionDeclaration,
                            TJSASTNodeType.EmptyStatement];
  REDECLARED_IDENTIFIER = 'Identifier ''%s'' has already been declared';
  CANNOT_DECLARE_GLOBAL_FUNCTION = 'Cannot declare global function %s';
  CANNOT_DECLARE_GLOBAL_VARIABLE = 'Cannot declare global variable %s';
  ASSIGN_TO_READ_ONLY_GLOBAL = 'Cannot assign to read only global variable %s';
  NOT_ITERABLE = 'Spread syntax requires an iterable value';
  NOT_ITERABLE_LOOP = 'Value is not iterable';
  INSTANCEOF_NOT_OBJECT = 'Right-hand side of instanceof is not an object';
  INSTANCEOF_NOT_CALLABLE = 'Right-hand side of instanceof is not callable';
  HAS_INSTANCE_NOT_CALLABLE = 'Symbol.hasInstance is not a function';
  INSTANCEOF_PROTOTYPE_NOT_OBJECT = 'Function has non-object prototype in instanceof check';
  IN_NOT_OBJECT = 'Cannot use the in operator to search for a property in a non-object';
  PATTERN_NOT_ITERABLE = 'Value is not iterable and cannot be destructured';
  ITERATOR_METHOD_NOT_CALLABLE = 'The Symbol.iterator property is not a function';
  ITERATOR_NOT_AN_OBJECT = 'The Symbol.iterator method did not return an object';
  ITERATOR_NEXT_PROPERTY = 'next';
  CANNOT_DESTRUCTURE = 'Cannot destructure a value that is %s';

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
  FLexicalStates.Free;
  FDeletableNames.Free;
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

  if Assigned(FLexicalStates) then
    FLexicalStates.Clear;

  FParent := nil;
end;

function TJSScope.HasLexicalState(const Name: string): Boolean;
begin
  Result := Assigned(FLexicalStates) and FLexicalStates.Contains(Name);
end;

function TJSScope.HasVariable(const Name: string): Boolean;
begin
  Result := FVariables.ContainsKey(Name) or HasLexicalState(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSScope.GetVariable(const Name: string): TJSValue;
begin
  if FVariables.TryGetValue(Name, Result) then
    Exit;

  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureInitialized(Name);

  if Assigned(FParent) then
    Exit(FParent.GetVariable(Name));

  Result := TJSValue.CreateUndefined;
end;

function TJSScope.TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
begin
  Result := FVariables.TryGetValue(Name, Value);
  if Result then
    Exit;

  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureInitialized(Name);

  if Assigned(FParent) then
    Result := FParent.TryGetVariable(Name, Value);
end;

procedure TJSScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  const ResolvedScope = Resolve(Name);

  if Assigned(ResolvedScope) then
    ResolvedScope.AssignVariable(Name, Value)
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
  const IsExisting = FVariables.ContainsKey(Name);
  DeclareVariable(Name, Value);
  if IsExisting then
    Exit;

  if not Assigned(FDeletableNames) then
    FDeletableNames := TDictionary<string, Byte>.Create;

  FDeletableNames.AddOrSetValue(Name, 0);
end;

procedure TJSScope.AssignVariable(const Name: string; const Value: TJSValue);
begin
  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureAssignable(Name);

  FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareLexical(const Name: string; const IsConstant: Boolean);
begin
  if not Assigned(FLexicalStates) then
    FLexicalStates := TJSLexicalStates.Create;

  FLexicalStates.Declare(Name, IsConstant);
end;

procedure TJSScope.InitializeLexical(const Name: string; const Value: TJSValue);
begin
  FVariables.AddOrSetValue(Name, Value);

  if Assigned(FLexicalStates) then
    FLexicalStates.MarkInitialized(Name);
end;

function TJSScope.CloneForIteration: TJSScope;
begin
  Result := TJSScope.Create(FParent);

  for var Pair in FVariables do
  begin
    Result.FVariables.Add(Pair.Key, Pair.Value);
  end;

  if Assigned(FLexicalStates) then
  begin
    Result.FLexicalStates := TJSLexicalStates.Create;
    Result.FLexicalStates.CopyFrom(FLexicalStates);
  end;
end;

function TJSScope.IsLexicalBinding(const Name: string): Boolean;
begin
  Result := HasLexicalState(Name);
end;

function TJSScope.IsDeletableName(const Name: string): Boolean;
begin
  Result := Assigned(FDeletableNames) and FDeletableNames.ContainsKey(Name);
end;

function TJSScope.DeleteVariable(const Name: string): Boolean;
begin
  if IsDeletableName(Name) then
  begin
    FDeletableNames.Remove(Name);
    FVariables.Remove(Name);
    Exit(True);
  end;

  Result := (not FVariables.ContainsKey(Name)) and (not HasLexicalState(Name));
end;

function TJSScope.Resolve(const Name: string): IJSScope;
begin
  if FVariables.ContainsKey(Name) or HasLexicalState(Name) then
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

{ TJSStrictThis }

constructor TJSStrictThis.Create(const Value: TJSValue);
begin
  inherited Create;
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

{ TJSIterationSource }

function TJSIterationSource.HasNext: Boolean;
begin
  if Assigned(Protocol) then
    Exit(Protocol.HasNext);

  if Assigned(Elements) then
    Exit(Position < Elements.Length);

  if Assigned(ArrayLike) then
    Exit(Position < TJSArrayLike.ToLength(ArrayLike));

  Result := (Position < Length(Items));
end;

function TJSIterationSource.Next: TJSValue;
begin
  if Assigned(Protocol) then
    Exit(Protocol.Next);

  Result := TJSValue.CreateUndefined;

  if HasNext then
  begin
    if Assigned(Elements) then
    begin
      if Elements.HasElement(Position) then
        Result := Elements.GetElement(Position)
      else
        Result := Elements.GetProperty(TJSArrayLike.IndexName(Position));
    end
    else if Assigned(ArrayLike) then
    begin
      Result := ArrayLike.GetProperty(TJSArrayLike.IndexName(Position));
    end
    else
    begin
      Result := Items[Position];
    end;
  end;

  Inc(Position);
end;

function TJSIterationSource.Remaining: TArray<TJSValue>;
begin
  const Values = TList<TJSValue>.Create;
  try
    while HasNext do
    begin
      Values.Add(Next);
    end;

    Result := Values.ToArray;
  finally
    Values.Free;
  end;
end;

procedure TJSIterationSource.Close;
begin
  if Assigned(Protocol) then
    Protocol.Close;
end;

procedure TJSIterationSource.CloseAfterThrow;
begin
  if Assigned(Protocol) then
    Protocol.CloseAfterThrow;
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
  FGlobalBindings := TJSGlobalScope.Create(FGlobalObject);
  FGlobalScope := FGlobalBindings;
  FScopeRegistry.Add(FGlobalScope);
  FCurrentScope := FGlobalScope;
  FVarScope := FGlobalScope;
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
  FVarScope := nil;
  FEvalCallerScope := nil;
  FGlobalBindings := nil;
  FGlobalScope := nil;
  FGlobalObject := nil;
  FThisValue := nil;
  FObjectPrototype := nil;
  FArrayPrototype := nil;
  FFunctionPrototype := nil;
  FRegExpPrototype := nil;
  FSymbolPrototype := nil;
  FIteration := Default(TJSIterationIntrinsics);
  for var Group := Low(TJSIntrinsicGroup) to High(TJSIntrinsicGroup) do
  begin
    FIntrinsicMethods[Group].Free;
  end;
  FOrdinaryHasInstance := nil;
  FArrayConstructor := nil;
  FArraySpeciesGetter := nil;
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
  const IsRegistered = (Func.CallHandler = Self);
  Func.CallHandler := Self;

  if not IsRegistered then
    FFunctionRegistry.Add(Func);
  FFunctionPrograms.AddOrSetValue(Pointer(Func as IInterface), FCurrentProgram);
end;

procedure TJSInterpreter.RegisterScope(const Scope: IJSScope);
begin
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

procedure TJSInterpreter.DefineArgumentsIterator(const ArgumentsObject: IJSObject);
begin
  if not Assigned(FIteration.ArrayValues) then
    Exit;

  var IteratorDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(FIteration.ArrayValues as IJSObject));
  IteratorDescriptor.Enumerable := False;
  ArgumentsObject.DefineProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator), IteratorDescriptor);
end;

function TJSInterpreter.CreateArgumentsObject(const Args: TArray<TJSValue>; const Func: IJSFunction): IJSObject;
begin
  const IsUnmapped = (Func.IsStrict or Assigned(ParameterInfoOf(Func)));
  if IsUnmapped then
    Result := TJSArgumentsObject.Create(FCurrentScope, nil, Length(Args))
  else
    Result := TJSArgumentsObject.Create(FCurrentScope, Func.Parameters, Length(Args));

  Result.Prototype := FObjectPrototype;

  for var Index := 0 to Length(Args) - 1 do
  begin
    Result.DefineProperty(IntToStr(Index), TJSPropertyDescriptor.Create(Args[Index]));
  end;

  var LengthDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(Length(Args)));
  LengthDescriptor.Enumerable := False;
  Result.DefineProperty(LENGTH_PROPERTY, LengthDescriptor);

  DefineArgumentsIterator(Result);

  if Func.IsStrict then
  begin
    Result.DefineProperty(CALLEE_PROPERTY, CreateCalleeDescriptor);
  end
  else
  begin
    const CalleeValue = TJSValue.CreateObject(Func);
    var CalleeDescriptor := TJSPropertyDescriptor.Create(CalleeValue);
    CalleeDescriptor.Enumerable := False;
    Result.DefineProperty(CALLEE_PROPERTY, CalleeDescriptor);
  end;
end;

procedure TJSInterpreter.AssignParameters(const Func: TJSFunction; const Params: TObjectList<TJSIdentifier>;
                                          const Info: TJSParameterInfo);
begin
  var Names: TArray<string>;
  SetLength(Names, Params.Count);

  for var Index := 0 to Params.Count - 1 do
  begin
    Names[Index] := Params[Index].Name;
  end;

  Func.Parameters := Names;

  if Assigned(Info) then
    Func.SetExpectedArgumentCount(Info.ExpectedArgumentCount);
end;

function TJSInterpreter.ParameterInfoOf(const Func: IJSFunction): TJSParameterInfo;
begin
  const Body = TObject(Func.BodyNode);
  if not (Body is TJSBlockStatement) then
    Exit(nil);

  Result := TJSBlockStatement(Body).ParameterInfo;
end;

function TJSInterpreter.BindParametersWithExpressions(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                                      const Info: TJSParameterInfo): IJSScope;
begin
  Result := nil;

  if Info.NeedsParameterScope then
    DeclareParameterBindings(Func, Info);

  const OuterInitScope = FParameterInitScope;
  if Func.IsArrow then
    FParameterInitScope := nil
  else
    FParameterInitScope := FCurrentScope;
  try
    InitializeParameterBindings(Func, Args, Info);
  finally
    FParameterInitScope := OuterInitScope;
  end;

  if not Info.NeedsParameterScope then
    Exit;

  Result := FCurrentScope;
  FCurrentScope := TJSScope.Create(Result);
  FVarScope := FCurrentScope;
  RegisterScope(FCurrentScope);
end;

procedure TJSInterpreter.DeclareParameterBindings(const Func: IJSFunction; const Info: TJSParameterInfo);
begin
  for var Name in Info.BoundNames do
  begin
    FCurrentScope.DeclareLexical(Name, False);
  end;
end;

procedure TJSInterpreter.InitializeParameterBindings(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                                     const Info: TJSParameterInfo);
begin
  const Parameters = Func.Parameters;

  for var Index := 0 to Length(Parameters) - 1 do
  begin
    var Value := TJSValue.CreateUndefined;
    if Index < Length(Args) then
      Value := Args[Index];

    const DefaultNode = Info.Defaults[Index];
    const Pattern = Info.Patterns[Index];
    const UsesDefault = Value.IsUndefined and Assigned(DefaultNode);
    if UsesDefault and Assigned(Pattern) then
      Value := Visit(DefaultNode)
    else if UsesDefault then
      Value := VisitNamed(DefaultNode, Parameters[Index]);

    if Assigned(Pattern) then
      BindTarget(Pattern, Value, TJSBindingMode.Lexical)
    else
      StoreParameter(Parameters[Index], Value, Info.NeedsParameterScope);
  end;

  if not Assigned(Info.Rest) then
    Exit;

  const RestArray = CreateRestArray(Args, Length(Parameters));
  if Assigned(Info.RestPattern) then
    BindTarget(Info.RestPattern, RestArray, TJSBindingMode.Lexical)
  else
    StoreParameter(Info.Rest.Name, RestArray, Info.NeedsParameterScope);
end;

procedure TJSInterpreter.StoreParameter(const Name: string; const Value: TJSValue; const IsLexical: Boolean);
begin
  if IsLexical then
    FCurrentScope.InitializeLexical(Name, Value)
  else
    FCurrentScope.DeclareVariable(Name, Value);
end;

function TJSInterpreter.CreateRestArray(const Args: TArray<TJSValue>; const FirstIndex: Integer): TJSValue;
begin
  const Rest: IJSArray = TJSArray.Create;
  Rest.Prototype := FArrayPrototype;

  for var Index := FirstIndex to Length(Args) - 1 do
  begin
    Rest.Push(Args[Index]);
  end;

  Result := TJSValue.CreateObject(Rest);
end;

procedure TJSInterpreter.CopyParametersToBodyScope(const Func: IJSFunction; const ParameterScope: IJSScope;
                                                   const Info: TJSParameterInfo);
begin
  for var Name in Info.BoundNames do
  begin
    CopyParameterToBodyScope(Name, ParameterScope);
  end;
end;

procedure TJSInterpreter.CopyParameterToBodyScope(const Name: string; const ParameterScope: IJSScope);
begin
  const IsRedeclaredInBody = (FCurrentScope.Resolve(Name) = FCurrentScope);
  if not IsRedeclaredInBody then
    Exit;

  const IsHoistedOnly = FCurrentScope.GetVariable(Name).IsUndefined;
  if IsHoistedOnly then
    FCurrentScope.SetVariable(Name, ParameterScope.GetVariable(Name));
end;

function TJSInterpreter.EvaluateArguments(const Nodes: TObjectList<TJSExpression>;
                                          const HasSpread: Boolean): TArray<TJSValue>;
begin
  if HasSpread then
    Exit(EvaluateSpreadArguments(Nodes));

  SetLength(Result, Nodes.Count);

  for var Index := 0 to Nodes.Count - 1 do
  begin
    Result[Index] := Visit(Nodes[Index]);
  end;
end;

function TJSInterpreter.EvaluateSpreadArguments(const Nodes: TObjectList<TJSExpression>): TArray<TJSValue>;
begin
  const Values = TList<TJSValue>.Create;
  try
    for var Node in Nodes do
    begin
      if Node is TJSSpreadElement then
        AppendSpreadValues(Visit(TJSSpreadElement(Node).Argument), Values)
      else
        Values.Add(Visit(Node));
    end;

    Result := Values.ToArray;
  finally
    Values.Free;
  end;
end;

procedure TJSInterpreter.AppendSpreadValues(const Source: TJSValue; const Target: TList<TJSValue>);
begin
  var Values: TJSIterationSource;
  if not TryOpenIterationSource(Source, Values) then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  while Values.HasNext do
  begin
    FLimits.EnsureArrayLength(Target.Count + 1);
    Target.Add(Values.Next);
  end;
end;

procedure TJSInterpreter.AppendStringValues(const Source: string; const Target: TList<TJSValue>);
begin
  var Position := 1;

  while Position <= Length(Source) do
  begin
    const CodeUnitCount = TJSStringIterator.CodePointLength(Source, Position);

    Target.Add(TJSValue.CreateString(Copy(Source, Position, CodeUnitCount)));
    Inc(Position, CodeUnitCount);
  end;
end;

function TJSInterpreter.VisitArrayWithSpread(const Node: TJSArrayExpression): TJSValue;
begin
  const Arr: IJSArray = TJSArray.Create;
  Arr.Prototype := FArrayPrototype;

  const Spread = TList<TJSValue>.Create;
  try
    for var Element in Node.Elements do
    begin
      if not Assigned(Element) then
      begin
        Arr.Push(TJSValue.CreateUndefined);
        Arr.DeleteElement(Arr.Length - 1);
      end
      else if Element is TJSSpreadElement then
      begin
        Spread.Clear;
        AppendSpreadValues(Visit(TJSSpreadElement(Element).Argument), Spread);
        FLimits.EnsureArrayLength(Arr.Length + Spread.Count);

        for var Value in Spread do
        begin
          Arr.Push(Value);
        end;
      end
      else
      begin
        Arr.Push(Visit(Element));
      end;
    end;
  finally
    Spread.Free;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

procedure TJSInterpreter.DetachProperties(const Func: IJSFunction);
begin
  for var PropName in TJSObjectKeys.All(Func) do
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

procedure TJSInterpreter.RequireLiveProxy(const Constructor_: IJSFunction);
begin
  var Proxy: IJSProxy;
  const IsRevokedProxy = TJSObjectOperations.AsProxy(Constructor_, Proxy) and Proxy.IsRevoked;
  if IsRevokedProxy then
    raise TJSErrorFactory.TypeError(REVOKED_CONSTRUCTOR);
end;

function TJSInterpreter.CreateInstanceFor(const Constructor_: IJSFunction): IJSObject;
begin
  Result := TJSObject.Create;

  const PrototypeValue = Constructor_.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsObject then
    Result.Prototype := PrototypeValue.ToObject
  else
  begin
    RequireLiveProxy(Constructor_);
    Result.Prototype := FObjectPrototype;
  end;
end;

function TJSInterpreter.PrimitivePrototypeFor(const Value: TJSValue): IJSObject;
begin
  if Value.IsString then
    Result := FStringPrototype
  else if Value.IsNumber then
    Result := FNumberPrototype
  else if Value.IsBoolean then
    Result := FBooleanPrototype
  else if Value.IsSymbol then
    Result := FSymbolPrototype
  else
    Result := nil;
end;

function TJSInterpreter.WrapPrimitive(const Value: TJSValue): IJSObject;
begin
  Result := TJSPrimitiveWrapper.Create(Value);
  Result.Prototype := PrimitivePrototypeFor(Value);
end;

function TJSInterpreter.BoundLength(const Target: IJSFunction; const BoundArgumentCount: Integer): Double;
begin
  if not Target.HasOwnProperty(LENGTH_PROPERTY) then
    Exit(0);

  const TargetLength = Target.GetProperty(LENGTH_PROPERTY);
  if not TargetLength.IsNumber then
    Exit(0);

  const LengthNumber = TargetLength.AsNumber;
  const IsUsableLength = (not IsNaN(LengthNumber));
  if not IsUsableLength then
    Exit(0);

  const RemainingLength = Int(LengthNumber) - BoundArgumentCount;
  const HasRemainingLength = (RemainingLength > 0);
  if HasRemainingLength then
    Result := RemainingLength
  else
    Result := 0;
end;

function TJSInterpreter.ThisObjectFor(const Func: IJSFunction; const ThisValue: TJSValue): IJSObject;
begin
  if ThisValue.IsObject then
    Exit(ThisValue.ToObject);

  const SeesObjectThis = Func.IsNative or (not Func.IsStrict);
  if SeesObjectThis then
  begin
    const IsPrimitive = not ThisValue.IsNullOrUndefined;
    if IsPrimitive then
      Exit(WrapPrimitive(ThisValue));

    Exit(nil);
  end;

  if ThisValue.IsUndefined then
    Exit(nil);

  Result := TJSStrictThis.Create(ThisValue);
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

  const OuterScope = FCurrentScope;
  const OuterVarScope = FVarScope;
  const OuterThis = FThisValue;
  const OuterThisPrimitive = FThisPrimitive;
  const OuterStrictMode = FStrictMode;

  Inc(FExecutionDepth);
  FCurrentScope := FGlobalScope;
  FVarScope := FGlobalScope;
  FThisValue := nil;
  FThisPrimitive := nil;
  try
    FCurrentProgram := Program_;
    Result := Visit(Program_);
  finally
    FCurrentScope := OuterScope;
    FVarScope := OuterVarScope;
    FThisValue := OuterThis;
    FThisPrimitive := OuterThisPrimitive;
    FStrictMode := OuterStrictMode;
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
      Result := VisitFunctionDeclaration(TJSFunctionDeclaration(Node));
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
    TJSASTNodeType.ForOfStatement:
      Result := VisitForOfStatement(TJSForOfStatement(Node));
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
    TJSASTNodeType.TemplateLiteral:
      Result := VisitTemplateLiteral(TJSTemplateLiteral(Node));
    TJSASTNodeType.TemplateObject:
      Result := VisitTemplateObject(TJSTemplateObject(Node));
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitProgram(const Node: TJSProgram): TJSValue;
begin
  FStrictMode := Node.IsStrict;
  Result := RunProgramBody(Node);
end;

procedure TJSInterpreter.GuardGlobalDeclarations(const Node: TJSProgram);
begin
  const IsGlobalVarScope = (FVarScope = FGlobalScope);
  if not IsGlobalVarScope then
    Exit;

  for var Statement in Node.Body do
  begin
    if Statement is TJSFunctionDeclaration then
      GuardGlobalFunctionDeclaration(TJSFunctionDeclaration(Statement));
  end;

  GuardGlobalVariableDeclarations(Node);
end;

procedure TJSInterpreter.GuardGlobalFunctionDeclaration(const Declaration: TJSFunctionDeclaration);
begin
  if FGlobalBindings.CanDeclareFunction(Declaration.Id.Name) then
    Exit;

  const Message = Format(CANNOT_DECLARE_GLOBAL_FUNCTION, [Declaration.Id.Name]);
  raise TJSErrorFactory.TypeError(Message, Declaration.Line, Declaration.Column);
end;

procedure TJSInterpreter.GuardGlobalVariableDeclarations(const Node: TJSProgram);
begin
  FIsGuardingGlobalVariables := True;
  try
    for var Statement in Node.Body do
    begin
      HoistVarNames(Statement);
    end;
  finally
    FIsGuardingGlobalVariables := False;
  end;
end;

procedure TJSInterpreter.DeclareGlobalFunction(const Name: string; const Value: TJSValue);
begin
  EnsureNoGlobalLexicalConflict(Name);
  EnsureNoEvalLexicalConflict(Name);

  const IsEvalDeclaration = Assigned(FEvalVariableScope) and (FVarScope = FEvalVariableScope);
  FGlobalBindings.DeclareFunctionBinding(Name, Value, IsEvalDeclaration);
end;

function TJSInterpreter.RunProgramBody(const Node: TJSProgram): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  GuardGlobalDeclarations(Node);
  InstantiateTopLevel(Node.Body, Node.ScopeInfo);

  for var Statement in Node.Body do
  begin
    if Statement.NodeType in EMPTY_COMPLETION_NODES then
      ExecuteStatement(Statement)
    else
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
  const OldThisPrimitive = FThisPrimitive;
  const OldStrictMode = FStrictMode;
  const OldProgram = FCurrentProgram;
  const OldEvalVariableScope = FEvalVariableScope;
  const OldVarScope = FVarScope;
  const OldEvalCallerScope = FEvalCallerScope;
  FEvalCallerScope := nil;
  if IsDirect and (not IsStrictSource) then
    FEvalCallerScope := FCurrentScope;

  FCurrentScope := CreateEvalScope(IsDirect, IsStrictSource);

  if IsStrictSource then
    FVarScope := FCurrentScope
  else if not IsDirect then
    FVarScope := FGlobalScope;

  FEvalVariableScope := FVarScope;

  const NeedsLexicalScope = Assigned(Program_.ScopeInfo) and (not IsStrictSource);
  if NeedsLexicalScope then
  begin
    FCurrentScope := TJSScope.Create(FCurrentScope);

    if Program_.ScopeInfo.MayCaptureScope then
      RegisterScope(FCurrentScope);
  end;

  FStrictMode := IsStrictSource;
  FCurrentProgram := Program_;
  if not IsDirect then
  begin
    FThisValue := FGlobalObject;
    FThisPrimitive := nil;
  end;
  try
    Result := RunProgramBody(Program_);
  finally
    FCurrentProgram := OldProgram;
    FEvalVariableScope := OldEvalVariableScope;
    FVarScope := OldVarScope;
    FEvalCallerScope := OldEvalCallerScope;
    FStrictMode := OldStrictMode;
    FThisValue := OldThis;
    FThisPrimitive := OldThisPrimitive;
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

procedure TJSInterpreter.InstantiateTopLevel(const Statements: TObjectList<TJSStatement>; const ScopeInfo: TJSScopeInfo);
begin
  if Assigned(ScopeInfo) then
    DeclareTopLevelLexicals(ScopeInfo);

  for var Statement in Statements do
  begin
    HoistStatement(Statement);
  end;
end;

procedure TJSInterpreter.DeclareTopLevelLexicals(const ScopeInfo: TJSScopeInfo);
begin
  for var Declaration in ScopeInfo.Declarations do
  begin
    if not (Declaration is TJSVariableDeclaration) then
      Continue;

    for var Declarator in TJSVariableDeclaration(Declaration).Declarations do
    begin
      for var Name in Declarator.BoundNames do
      begin
        EnsureGlobalLexicalAvailable(Name);
      end;
    end;
  end;

  for var Declaration in ScopeInfo.Declarations do
  begin
    if Declaration is TJSVariableDeclaration then
      DeclareLexicalNames(TJSVariableDeclaration(Declaration));
  end;
end;

procedure TJSInterpreter.DeclareLexicalNames(const Declaration: TJSVariableDeclaration);
begin
  const IsConstant = (Declaration.Kind = TJSDeclarationKind.Const_);

  for var Declarator in Declaration.Declarations do
  begin
    DeclareLexicalBinding(Declarator, IsConstant);
  end;
end;

procedure TJSInterpreter.DeclareLexicalBinding(const Declarator: TJSVariableDeclarator; const IsConstant: Boolean);
begin
  if Assigned(Declarator.Id) then
  begin
    FCurrentScope.DeclareLexical(Declarator.Id.Name, IsConstant);
    Exit;
  end;

  for var Name in Declarator.BoundNames do
  begin
    FCurrentScope.DeclareLexical(Name, IsConstant);
  end;
end;

procedure TJSInterpreter.HoistDeclarator(const Declarator: TJSVariableDeclarator);
begin
  if Assigned(Declarator.Id) then
  begin
    HoistVariable(Declarator.Id.Name);
    Exit;
  end;

  for var Name in Declarator.BoundNames do
  begin
    HoistVariable(Name);
  end;
end;

procedure TJSInterpreter.EnsureGlobalLexicalAvailable(const Name: string);
begin
  if FCurrentScope <> FGlobalScope then
    Exit;

  const IsRedeclared = FGlobalBindings.HasLexical(Name);
  const IsRestricted = FGlobalObject.HasOwnProperty(Name) and (not FGlobalObject.IsPropertyConfigurable(Name));
  if IsRedeclared or IsRestricted then
    raise TJSErrorFactory.SyntaxError(Format(REDECLARED_IDENTIFIER, [Name]));
end;

procedure TJSInterpreter.EnsureNoGlobalLexicalConflict(const Name: string);
begin
  const IsGlobalVariable = (FVarScope = FGlobalScope);
  if IsGlobalVariable and FGlobalBindings.HasLexicals and FGlobalBindings.HasLexical(Name) then
    raise TJSErrorFactory.SyntaxError(Format(REDECLARED_IDENTIFIER, [Name]));
end;

procedure TJSInterpreter.HoistStatement(const Node: TJSStatement);
begin
  var Target := Node;

  while Target.NodeType = TJSASTNodeType.LabeledStatement do
  begin
    Target := TJSLabeledStatement(Target).Body;
  end;

  if Target.NodeType = TJSASTNodeType.FunctionDeclaration then
    DeclareFunction(TJSFunctionDeclaration(Target))
  else
    HoistVarNames(Node);
end;

procedure TJSInterpreter.EnsureNoEvalLexicalConflict(const Name: string);
begin
  const IsSloppyDirectEval = Assigned(FEvalCallerScope) and (FVarScope = FEvalVariableScope);
  if not IsSloppyDirectEval then
    Exit;

  const IsParameterInitializer = Assigned(FParameterInitScope) and (FEvalCallerScope = FParameterInitScope);
  if IsParameterInitializer and (Name = ARGUMENTS_NAME) then
    raise TJSErrorFactory.SyntaxError(Format(REDECLARED_IDENTIFIER, [Name]));

  var Scope := FEvalCallerScope;

  while Assigned(Scope) do
  begin
    const Candidate = Scope as TObject;
    if (Candidate is TJSScope) and TJSScope(Candidate).IsLexicalBinding(Name) then
      raise TJSErrorFactory.SyntaxError(Format(REDECLARED_IDENTIFIER, [Name]));

    if Scope = FVarScope then
      Break;

    Scope := Scope.Parent;
  end;
end;

procedure TJSInterpreter.HoistVariable(const Name: string);
begin
  if FIsGuardingGlobalVariables then
  begin
    if not FGlobalBindings.CanDeclareVariable(Name) then
      raise TJSErrorFactory.TypeError(Format(CANNOT_DECLARE_GLOBAL_VARIABLE, [Name]));

    Exit;
  end;

  EnsureNoGlobalLexicalConflict(Name);
  EnsureNoEvalLexicalConflict(Name);

  if FVarScope.Resolve(Name) <> FVarScope then
    DeclareBinding(Name, TJSValue.CreateUndefined);
end;

procedure TJSInterpreter.HoistVarNames(const Node: TJSASTNode);
begin
  if Node = nil then
    Exit;

  case Node.NodeType of
    TJSASTNodeType.VariableDeclaration:
      if TJSVariableDeclaration(Node).Kind = TJSDeclarationKind.Var_ then
      begin
        for var Declarator in TJSVariableDeclaration(Node).Declarations do
        begin
          HoistDeclarator(Declarator);
        end;
      end;
    TJSASTNodeType.FunctionDeclaration:
      if TJSFunctionDeclaration(Node).HoistsToVar then
        HoistVariable(TJSFunctionDeclaration(Node).Id.Name);
    TJSASTNodeType.BlockStatement:
      for var Statement in TJSBlockStatement(Node).Body do
      begin
        HoistVarNames(Statement);
      end;
    TJSASTNodeType.IfStatement:
      begin
        HoistVarNames(TJSIfStatement(Node).Consequent);
        HoistVarNames(TJSIfStatement(Node).Alternate);
      end;
    TJSASTNodeType.WhileStatement:
      HoistVarNames(TJSWhileStatement(Node).Body);
    TJSASTNodeType.DoWhileStatement:
      HoistVarNames(TJSDoWhileStatement(Node).Body);
    TJSASTNodeType.WithStatement:
      HoistVarNames(TJSWithStatement(Node).Body);
    TJSASTNodeType.LabeledStatement:
      HoistVarNames(TJSLabeledStatement(Node).Body);
    TJSASTNodeType.ForStatement:
      begin
        HoistVarNames(TJSForStatement(Node).Init);
        HoistVarNames(TJSForStatement(Node).Body);
      end;
    TJSASTNodeType.ForInStatement, TJSASTNodeType.ForOfStatement:
      begin
        HoistVarNames(TJSForInStatement(Node).Left);
        HoistVarNames(TJSForInStatement(Node).Body);
      end;
    TJSASTNodeType.TryStatement:
      begin
        const TryNode = TJSTryStatement(Node);
        HoistVarNames(TryNode.Block);

        if Assigned(TryNode.Handler) then
          HoistVarNames(TryNode.Handler.Body);

        HoistVarNames(TryNode.Finalizer);
      end;
    TJSASTNodeType.SwitchStatement:
      for var SwitchCase in TJSSwitchStatement(Node).Cases do
      begin
        for var Statement in SwitchCase.Consequent do
        begin
          HoistVarNames(Statement);
        end;
      end;
  end;
end;

procedure TJSInterpreter.EnterLexicalScope(const ScopeInfo: TJSScopeInfo);
begin
  FCurrentScope := TJSScope.Create(FCurrentScope);

  if ScopeInfo.MayCaptureScope then
    RegisterScope(FCurrentScope);

  for var Declaration in ScopeInfo.Declarations do
  begin
    if Declaration is TJSVariableDeclaration then
      DeclareLexicalNames(TJSVariableDeclaration(Declaration));
  end;

  for var Declaration in ScopeInfo.Declarations do
  begin
    if Declaration is TJSFunctionDeclaration then
    begin
      const FunctionNode = TJSFunctionDeclaration(Declaration);
      FCurrentScope.DeclareLexical(FunctionNode.Id.Name, False);
      FCurrentScope.InitializeLexical(FunctionNode.Id.Name, TJSValue.CreateObject(CreateFunctionObject(FunctionNode)));
    end;
  end;
end;

function TJSInterpreter.VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
begin
  const NeedsScope = Assigned(Node.ScopeInfo) and (not Node.IsFunctionBody);
  if NeedsScope then
  begin
    Result := VisitScopedBlock(Node);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;

  for var Statement in Node.Body do
  begin
    if Statement.NodeType in EMPTY_COMPLETION_NODES then
      ExecuteStatement(Statement)
    else
      Result := ExecuteStatement(Statement);
  end;
end;

function TJSInterpreter.VisitScopedBlock(const Node: TJSBlockStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const OuterScope = FCurrentScope;
  try
    EnterLexicalScope(Node.ScopeInfo);
    for var Statement in Node.Body do
    begin
      if Statement.NodeType in EMPTY_COMPLETION_NODES then
        ExecuteStatement(Statement)
      else
        Result := ExecuteStatement(Statement);
    end;
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  if Node.Kind <> TJSDeclarationKind.Var_ then
  begin
    for var Declarator in Node.Declarations do
    begin
      if Assigned(Declarator.Pattern) then
      begin
        const BoundValue = Visit(Declarator.Init);
        BindTarget(Declarator.Pattern, BoundValue, TJSBindingMode.Lexical);
        Continue;
      end;

      var InitialValue := TJSValue.CreateUndefined;

      if Assigned(Declarator.Init) then
        InitialValue := VisitNamed(Declarator.Init, Declarator.Id.Name);

      FCurrentScope.InitializeLexical(Declarator.Id.Name, InitialValue);
    end;

    Exit;
  end;

  for var Declarator in Node.Declarations do
  begin
    if not Assigned(Declarator.Init) then
      Continue;

    if Assigned(Declarator.Pattern) then
    begin
      const BoundValue = Visit(Declarator.Init);
      BindTarget(Declarator.Pattern, BoundValue, TJSBindingMode.Variable);
    end
    else
      FCurrentScope.SetVariable(Declarator.Id.Name, VisitNamed(Declarator.Init, Declarator.Id.Name));
  end;
end;

function TJSInterpreter.CreateFunctionObject(const Node: TJSFunctionDeclaration): IJSFunction;
begin
  const Func = TJSFunction.Create;
  Func.Prototype := FFunctionPrototype;
  Func.Name := Node.Id.Name;
  Func.SourceText := Node.SourceText;
  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;
  Func.ClosureScope := FCurrentScope;

  AssignParameters(Func, Node.Params, Node.ParameterInfo);
  RegisterFunction(Func);
  AttachPrototype(Func);

  Result := Func;
end;

procedure TJSInterpreter.DeclareFunction(const Node: TJSFunctionDeclaration);
begin
  const Value = TJSValue.CreateObject(CreateFunctionObject(Node));

  const IsGlobalFunction = (FVarScope = FGlobalScope);
  if IsGlobalFunction then
    DeclareGlobalFunction(Node.Id.Name, Value)
  else
    DeclareBinding(Node.Id.Name, Value);
end;

function TJSInterpreter.VisitFunctionDeclaration(const Node: TJSFunctionDeclaration): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  if Node.HoistsToVar then
    FVarScope.AssignVariable(Node.Id.Name, FCurrentScope.GetVariable(Node.Id.Name));
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

  FCurrentScope := TJSObjectScope.Create(OuterScope, ScopeObject, @FStrictMode);
  RegisterScope(FCurrentScope);
  try
    Result := ExecuteStatement(Node.Body);
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.VisitCalleeIdentifier(const Identifier: TJSIdentifier; out ThisObj: IJSObject): TJSValue;
begin
  ThisObj := nil;

  const IsGlobalCode = (FCurrentScope = FGlobalScope);
  if IsGlobalCode then
    Exit(VisitIdentifier(Identifier));

  const DeclaringScope = FCurrentScope.Resolve(Identifier.Name);
  if not Assigned(DeclaringScope) then
    raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);

  var ObjectScope: IJSObjectScope;
  if Supports(DeclaringScope, IJSObjectScope, ObjectScope) then
  begin
    ThisObj := ObjectScope.BindingObject;
    Exit(ObjectScope.GetBindingValue(Identifier.Name, FStrictMode));
  end;

  if not DeclaringScope.TryGetVariable(Identifier.Name, Result) then
    raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);
end;

function TJSInterpreter.VisitLabeledStatement(const Node: TJSLabeledStatement): TJSValue;
begin
  const BodyIsLoop = (Node.Body.NodeType in [TJSASTNodeType.WhileStatement,
                                             TJSASTNodeType.DoWhileStatement,
                                             TJSASTNodeType.ForStatement,
                                             TJSASTNodeType.ForInStatement,
                                             TJSASTNodeType.ForOfStatement]);
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

function TJSInterpreter.IsLexicalDeclaration(const Node: TJSASTNode): Boolean;
begin
  Result := (Node is TJSVariableDeclaration) and (TJSVariableDeclaration(Node).Kind <> TJSDeclarationKind.Var_);
end;

function TJSInterpreter.VisitForStatement(const Node: TJSForStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;

  if IsLexicalDeclaration(Node.Init) then
  begin
    Result := VisitLexicalForStatement(Node, OwnLabels);
    Exit;
  end;

  if Assigned(Node.Init) then
    Visit(Node.Init);

  Result := RunForLoop(Node, OwnLabels, False);
end;

function TJSInterpreter.VisitLexicalForStatement(const Node: TJSForStatement; const OwnLabels: TArray<string>): TJSValue;
begin
  const OuterScope = FCurrentScope;
  const Declaration = TJSVariableDeclaration(Node.Init);

  FCurrentScope := TJSScope.Create(OuterScope);
  if Node.MayCaptureScope then
    RegisterScope(FCurrentScope);

  try
    DeclareLexicalNames(Declaration);
    Visit(Declaration);

    if Node.MayCaptureScope then
      CopyIterationScope;

    Result := RunForLoop(Node, OwnLabels, Node.MayCaptureScope);
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.RunForLoop(const Node: TJSForStatement; const OwnLabels: TArray<string>;
                                   const CopiesIterationScope: Boolean): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

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

        AdvanceForLoop(Node, CopiesIterationScope);
        Continue;
      end;
    end;

    AdvanceForLoop(Node, CopiesIterationScope);
  end;
end;

procedure TJSInterpreter.AdvanceForLoop(const Node: TJSForStatement; const CopiesIterationScope: Boolean);
begin
  if CopiesIterationScope then
    CopyIterationScope;

  if Assigned(Node.Update) then
    Visit(Node.Update);
end;

procedure TJSInterpreter.CopyIterationScope;
begin
  const Source = (FCurrentScope as TObject) as TJSScope;

  FCurrentScope := Source.CloneForIteration;
  RegisterScope(FCurrentScope);
end;

function TJSInterpreter.EvaluateForInSubject(const Node: TJSForInStatement): TJSValue;
begin
  if not IsLexicalDeclaration(Node.Left) then
  begin
    Result := Visit(TJSExpression(Node.Right));
    Exit;
  end;

  const OuterScope = FCurrentScope;

  FCurrentScope := TJSScope.Create(OuterScope);
  if Node.MayCaptureScope then
    RegisterScope(FCurrentScope);

  try
    DeclareLexicalNames(TJSVariableDeclaration(Node.Left));
    Result := Visit(TJSExpression(Node.Right));
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.CollectEnumerableKeys(const Subject: IJSObject): TArray<string>;
begin
  const Keys = TList<string>.Create;
  const Visited = THashSet<string>.Create;
  try
    var Current := Subject;

    while Assigned(Current) do
    begin
      for var Name in Current.GetOwnPropertyNames do
      begin
        const IsShadowed = not Visited.Add(Name);
        if IsShadowed then
          Continue;

        if Current.GetOwnPropertyDescriptor(Name).Enumerable then
          Keys.Add(Name);
      end;

      Current := Current.Prototype;
    end;

    Result := Keys.ToArray;
  finally
    Visited.Free;
    Keys.Free;
  end;
end;

procedure TJSInterpreter.BindLexicalLoopVariable(const Node: TJSForInStatement; const Declaration: TJSVariableDeclaration;
                                                 const OuterScope: IJSScope; const Value: TJSValue);
begin
  const Declarator = Declaration.Declarations[0];

  FCurrentScope := TJSScope.Create(OuterScope);
  if Node.MayCaptureScope then
    RegisterScope(FCurrentScope);

  DeclareLexicalBinding(Declarator, Declaration.Kind = TJSDeclarationKind.Const_);

  if Assigned(Declarator.Pattern) then
    BindTarget(Declarator.Pattern, Value, TJSBindingMode.Lexical)
  else
    FCurrentScope.InitializeLexical(Declarator.Id.Name, Value);
end;

procedure TJSInterpreter.AssignLoopVariable(const Node: TJSForInStatement; const OuterScope: IJSScope;
                                            const Value: TJSValue);
begin
  if Node.Left is TJSVariableDeclaration then
  begin
    const Declaration = TJSVariableDeclaration(Node.Left);
    if Declaration.Declarations.Count = 0 then
      Exit;

    const Declarator = Declaration.Declarations[0];
    if Declaration.Kind <> TJSDeclarationKind.Var_ then
      BindLexicalLoopVariable(Node, Declaration, OuterScope, Value)
    else if Assigned(Declarator.Pattern) then
      BindTarget(Declarator.Pattern, Value, TJSBindingMode.Variable)
    else
      FCurrentScope.SetVariable(Declarator.Id.Name, Value);
  end
  else if Node.Left is TJSIdentifier then
  begin
    const Identifier = TJSIdentifier(Node.Left);
    const Binding = FCurrentScope.Resolve(Identifier.Name);

    const IsUndeclaredInStrictCode = FStrictMode and (not Assigned(Binding));
    if IsUndeclaredInStrictCode then
      raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);

    PutIdentifierValue(Binding, Identifier.Name, Value);
  end
  else if Node.Left is TJSExpression then
  begin
    BindTarget(TJSExpression(Node.Left), Value, TJSBindingMode.Assign);
  end;
end;

function TJSInterpreter.RunLoopBody(const Body: TJSStatement; const OwnLabels: TArray<string>;
                                    out KeepLooping: Boolean): TJSValue;
begin
  KeepLooping := True;
  Result := TJSValue.CreateUndefined;

  try
    Result := ExecuteStatement(Body);
  except
    on Signal: TJSBreakSignal do
    begin
      if Signal.IsLabelled then
        raise;

      KeepLooping := False;
    end;
    on Signal: TJSContinueSignal do
    begin
      if not Signal.AppliesTo(OwnLabels) then
        raise;
    end;
  end;
end;

function TJSInterpreter.VisitForInStatement(const Node: TJSForInStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  const OuterScope = FCurrentScope;
  try
    const RightValue = EvaluateForInSubject(Node);

    if RightValue.IsNullOrUndefined then
      Exit;

    const Obj = ToScopeObject(RightValue);

    var Proxy: IJSProxy;
    const IsProxy = TJSObjectOperations.AsProxy(Obj, Proxy);

    for var PropName in CollectEnumerableKeys(Obj) do
    begin
      const IsDeleted = (not IsProxy) and (not Obj.HasProperty(PropName));
      if IsDeleted then
        Continue;

      AssignLoopVariable(Node, OuterScope, TJSValue.CreateString(PropName));

      var KeepLooping: Boolean;
      Result := RunLoopBody(Node.Body, OwnLabels, KeepLooping);
      if not KeepLooping then
        Break;
    end;
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.VisitForOfStatement(const Node: TJSForOfStatement): TJSValue;
begin
  const OwnLabels = TakeLoopLabels;
  Result := TJSValue.CreateUndefined;

  const OuterScope = FCurrentScope;
  try
    const RightValue = EvaluateForInSubject(Node);

    var Source: TJSIterationSource;
    if not TryOpenIterationSource(RightValue, Source) then
      raise TJSErrorFactory.TypeError(NOT_ITERABLE_LOOP);

    Result := RunForOfLoop(Node, OuterScope, OwnLabels, Source);
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.RunForOfLoop(const Node: TJSForOfStatement; const OuterScope: IJSScope;
                                     const OwnLabels: TArray<string>; var Source: TJSIterationSource): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    while Source.HasNext do
    begin
      AssignLoopVariable(Node, OuterScope, Source.Next);

      var KeepLooping: Boolean;
      Result := RunLoopBody(Node.Body, OwnLabels, KeepLooping);
      if not KeepLooping then
      begin
        Source.Close;
        Break;
      end;
    end;
  except
    on EJSExecutionInterrupted do
      raise;
    on EJSControlFlowSignal do
    begin
      Source.Close;
      raise;
    end;
    on Exception do
    begin
      Source.CloseAfterThrow;
      raise;
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
  const DiscriminantValue = Visit(Node.Discriminant);
  if not Assigned(Node.ScopeInfo) then
  begin
    Result := ExecuteSwitchCases(Node, DiscriminantValue);
    Exit;
  end;

  const OuterScope = FCurrentScope;
  try
    EnterLexicalScope(Node.ScopeInfo);
    Result := ExecuteSwitchCases(Node, DiscriminantValue);
  finally
    FCurrentScope := OuterScope;
  end;
end;

function TJSInterpreter.ExecuteSwitchCases(const Node: TJSSwitchStatement; const DiscriminantValue: TJSValue): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

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
    if Assigned(Handler.Pattern) then
    begin
      for var Name in TJSPatternNames.Of_(Handler.Pattern) do
      begin
        FCurrentScope.DeclareLexical(Name, False);
      end;

      BindTarget(Handler.Pattern, Thrown, TJSBindingMode.Lexical);
    end
    else
    begin
      FCurrentScope.DeclareVariable(Handler.Param.Name, Thrown);
    end;

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
  const GlobalSlot = GlobalDataSlot(Node);
  if Assigned(GlobalSlot) then
    Exit(GlobalSlot.Value);

  if not FCurrentScope.TryGetVariable(Node.Name, Result) then
    raise TJSErrorFactory.UndefinedVariable(Node.Name, Node.Line, Node.Column);
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
        Result := TJSValue.CreateObject(RegExpObj);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
begin
  if Node.HasSpread then
    Exit(VisitArrayWithSpread(Node));

  FLimits.EnsureArrayLength(Node.Elements.Count);

  const Arr: IJSArray = TJSArray.Create;
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
  const Obj: IJSObject = TJSObject.Create;
  Obj.Prototype := FObjectPrototype;

  for var Prop in Node.Properties do
  begin
    DefineLiteralProperty(Obj, Prop);
  end;

  Result := TJSValue.CreateObject(Obj);
end;

procedure TJSInterpreter.DefineLiteralProperty(const Target: IJSObject; const Prop: TJSObjectProperty);
begin
  if Prop.Kind = TJSPropertyKind.Spread then
  begin
    const SpreadSource = Visit(Prop.Value);
    CopyDataProperties(Target, SpreadSource, nil);
    Exit;
  end;

  var KeyHolder: TJSValue;
  const KeyName = LiteralPropertyName(Prop, KeyHolder);

  case Prop.Kind of
    TJSPropertyKind.Getter,
    TJSPropertyKind.Setter : DefineLiteralAccessor(Target, KeyName, Prop);
    TJSPropertyKind.Method : DefineLiteralMethod(Target, KeyName, Prop);
  else
    if Prop.SetsPrototype then
      AssignLiteralPrototype(Target, Prop)
    else
      DefineLiteralData(Target, KeyName, Prop);
  end;
end;

function TJSInterpreter.LiteralPropertyName(const Prop: TJSObjectProperty; out KeyHolder: TJSValue): string;
begin
  KeyHolder := TJSValue.CreateUndefined;

  if Prop.Computed then
  begin
    // A symbol key stays registered only while the symbol lives, so the caller keeps it until the property exists.
    KeyHolder := Visit(Prop.Key);
    Exit(ToPropertyKey(KeyHolder));
  end;

  if Prop.Key is TJSIdentifier then
    Exit(TJSIdentifier(Prop.Key).Name);

  Result := VisitText(Prop.Key);
end;

class function TJSInterpreter.FunctionNameForKey(const Key: string): string;
begin
  Result := Key;

  if not TJSSymbolRegistry.IsKey(Key) then
    Exit;

  const Found = TJSSymbolRegistry.Find(Key);
  const IsLiveSymbol = Found is TJSSymbolImpl;
  const HasDescription = IsLiveSymbol and TJSSymbolImpl(Found).HasDescription;
  if HasDescription then
    Result := Format(SYMBOL_FUNCTION_NAME, [TJSSymbolImpl(Found).Description])
  else
    Result := '';
end;

procedure TJSInterpreter.DefineLiteralData(const Target: IJSObject; const Name: string;
                                           const Prop: TJSObjectProperty);
begin
  const Value = VisitNamed(Prop.Value, FunctionNameForKey(Name));
  Target.DefineProperty(Name, TJSPropertyDescriptor.Create(Value));
end;

procedure TJSInterpreter.DefineLiteralMethod(const Target: IJSObject; const Name: string;
                                             const Prop: TJSObjectProperty);
begin
  const Method = CreateMethodFunction(TJSFunctionExpression(Prop.Value), FunctionNameForKey(Name));
  Target.DefineProperty(Name, TJSPropertyDescriptor.Create(TJSValue.CreateObject(Method)));
end;

procedure TJSInterpreter.AssignLiteralPrototype(const Target: IJSObject; const Prop: TJSObjectProperty);
begin
  const Value = Visit(Prop.Value);

  if Value.IsNull then
    Target.Prototype := nil
  else if Value.IsObject then
    Target.Prototype := Value.ToObject;
end;

function TJSInterpreter.IsAnonymousFunctionDefinition(const Node: TJSExpression): Boolean;
begin
  Result := (Node is TJSFunctionExpression) and (not Assigned(TJSFunctionExpression(Node).Id));
end;

function TJSInterpreter.VisitAssigned(const Value: TJSExpression; const Target: TJSIdentifier): TJSValue;
begin
  if Target.IsParenthesized then
    Result := Visit(Value)
  else
    Result := VisitNamed(Value, Target.Name);
end;

function TJSInterpreter.VisitNamed(const Node: TJSExpression; const Name: string): TJSValue;
begin
  Result := Visit(Node);

  if IsAnonymousFunctionDefinition(Node) then
  begin
    const Func = Result.ToObject as IJSFunction;
    Func.Name := Name;
  end;
end;

procedure TJSInterpreter.DefineLiteralAccessor(const Target: IJSObject; const Name: string;
                                               const Prop: TJSObjectProperty);
begin
  var Definition := Default(TJSPropertyDefinition);
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  const IsGetter = (Prop.Kind = TJSPropertyKind.Getter);
  const NameFormat = IfThen(IsGetter, GETTER_NAME_FORMAT, SETTER_NAME_FORMAT);
  const AccessorName = Format(NameFormat, [FunctionNameForKey(Name)]);
  const AccessorFunction = CreateMethodFunction(TJSFunctionExpression(Prop.Value), AccessorName);
  const Accessor = TJSValue.CreateObject(AccessorFunction);

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

function TJSInterpreter.CurrentThisObject: IJSObject;
begin
  if Assigned(FThisValue) then
    Exit(FThisValue);

  const IsThisUndefined = (FStrictMode and (FCallDepth > 0));
  if IsThisUndefined then
    Exit(nil);

  Result := FGlobalObject;
end;

function TJSInterpreter.CreateArrowFunction(const Node: TJSFunctionExpression): IJSFunction;
begin
  const Func = TJSFunction.Create;
  Func.Prototype := FFunctionPrototype;
  Func.SourceText := Node.SourceText;
  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;
  Func.ClosureScope := FCurrentScope;
  Func.IsArrow := True;
  Func.IsConstructor := False;
  Func.LexicalThis := CurrentThisObject;

  AssignParameters(Func, Node.Params, Node.ParameterInfo);
  RegisterFunction(Func);

  Result := Func;
end;

function TJSInterpreter.VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
begin
  if Node.IsArrow then
  begin
    const ArrowFunction = CreateArrowFunction(Node);
    Exit(TJSValue.CreateObject(ArrowFunction));
  end;

  const Func = CreateOrdinaryFunction(Node);
  AttachPrototype(Func);

  if Assigned(Node.Id) then
    BindFunctionName(Func, Node.Id.Name);

  Result := TJSValue.CreateObject(Func);
end;

procedure TJSInterpreter.BindFunctionName(const Func: IJSFunction; const Name: string);
begin
  const NameScope = TJSFunctionNameScope.Create(FCurrentScope);
  NameScope.DeclareVariable(Name, TJSValue.CreateObject(Func));
  RegisterScope(NameScope);

  Func.ClosureScope := NameScope;
end;

function TJSInterpreter.CreateOrdinaryFunction(const Node: TJSFunctionExpression): IJSFunction;
begin
  const Func = TJSFunction.Create;
  Func.Prototype := FFunctionPrototype;

  if Assigned(Node.Id) then
    Func.Name := Node.Id.Name;

  Func.SourceText := Node.SourceText;
  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;
  Func.ClosureScope := FCurrentScope;

  AssignParameters(Func, Node.Params, Node.ParameterInfo);
  RegisterFunction(Func);

  Result := Func;
end;

function TJSInterpreter.CreateMethodFunction(const Node: TJSFunctionExpression; const Name: string): IJSFunction;
begin
  Result := CreateOrdinaryFunction(Node);
  Result.IsConstructor := False;
  Result.Name := Name;
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
    PropName := ToPropertyKey(Visit(MemberExpr.Property_))
  else
    PropName := TJSIdentifier(MemberExpr.Property_).Name;

  const Obj = ObjValue.ToObject;

  var Proxy: IJSProxy;
  if TJSObjectOperations.AsProxy(Obj, Proxy) then
    Exit(DeleteProxyMember(Node, Proxy, PropName));

  const OwnDescriptor = Obj.GetOwnPropertyDescriptor(PropName);
  const IsLocked = Obj.HasOwnProperty(PropName) and ((not OwnDescriptor.Configurable) or
                                                     TJSBinaryKeys.IsElementKey(Obj, PropName));
  if IsLocked and FStrictMode then
    raise TJSErrorFactory.TypeError(Format('Cannot delete property ''%s'' of object', [PropName]),
      Node.Line, Node.Column);

  if IsLocked then
    Exit(TJSValue.CreateBoolean(False));

  DeleteArrayElement(Obj, PropName);
  Obj.DeleteProperty(PropName);
  Result := TJSValue.CreateBoolean(True);
end;

function TJSInterpreter.DeleteProxyMember(const Node: TJSUnaryExpression; const Proxy: IJSProxy;
                                          const PropName: string): TJSValue;
begin
  const IsRemoved = Proxy.DeleteOwnProperty(PropName);
  if (not IsRemoved) and FStrictMode then
    raise TJSErrorFactory.TypeError(Format('Cannot delete property ''%s'' of object', [PropName]),
      Node.Line, Node.Column);

  Result := TJSValue.CreateBoolean(IsRemoved);
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
          TJSValueType.Symbol:
            Result := TJSValue.CreateString(SYMBOL_TYPE);
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
  EnsureNoGlobalLexicalConflict(Name);
  EnsureNoEvalLexicalConflict(Name);

  const IsEvalDeclaration = Assigned(FEvalVariableScope) and (FVarScope = FEvalVariableScope);
  if IsEvalDeclaration then
    FVarScope.DeclareDeletableVariable(Name, Value)
  else
    FVarScope.DeclareVariable(Name, Value);
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

function TJSInterpreter.IsInstanceOfErrorConstructor(const Instance: IJSObject; const ConstructorName: string): Boolean;
begin
  Result := False;

  var ErrorIntf: IJSError;
  if not Supports(Instance, IJSError, ErrorIntf) then
    Exit;

  const ErrorType = ErrorIntf.ErrorType;
  Result := (ConstructorName = CONSTRUCTOR_ERROR) or
            ((ConstructorName = CONSTRUCTOR_TYPE_ERROR) and (ErrorType = TJSErrorType.TypeError)) or
            ((ConstructorName = CONSTRUCTOR_RANGE_ERROR) and (ErrorType = TJSErrorType.RangeError)) or
            ((ConstructorName = CONSTRUCTOR_REFERENCE_ERROR) and (ErrorType = TJSErrorType.ReferenceError)) or
            ((ConstructorName = CONSTRUCTOR_SYNTAX_ERROR) and (ErrorType = TJSErrorType.SyntaxError)) or
            ((ConstructorName = CONSTRUCTOR_URI_ERROR) and (ErrorType = TJSErrorType.URIError)) or
            ((ConstructorName = CONSTRUCTOR_EVAL_ERROR) and (ErrorType = TJSErrorType.EvalError));
end;

function TJSInterpreter.IsInstanceOfBuiltinConstructor(const Instance: IJSObject;
                                                       const Constructor_: IJSFunction): Boolean;
begin
  const ConstructorName = Constructor_.Name;

  Result := IsInstanceOfErrorConstructor(Instance, ConstructorName) or
            (Supports(Instance, IJSArray) and (ConstructorName = CONSTRUCTOR_ARRAY)) or
            (Supports(Instance, IJSFunction) and (ConstructorName = CONSTRUCTOR_FUNCTION)) or
            (Supports(Instance, IJSRegExp) and (ConstructorName = CONSTRUCTOR_REGEXP)) or
            (Supports(Instance, IJSDate) and (ConstructorName = CONSTRUCTOR_DATE));
end;

function TJSInterpreter.EvaluateInstanceOf(const Left: TJSValue; const Right: TJSValue;
                                           const Node: TJSBinaryExpression): Boolean;
begin
  if not Right.IsObject then
    raise TJSErrorFactory.TypeError(INSTANCEOF_NOT_OBJECT, Node.Line, Node.Column);

  const RightObject = Right.ToObject;
  const Handler = RightObject.GetProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.HasInstance));
  if not Handler.IsNullOrUndefined then
  begin
    var HandlerFunc: IJSFunction;
    const IsCallable = Handler.IsFunction and Supports(Handler.ToObject, IJSFunction, HandlerFunc);
    if not IsCallable then
      raise TJSErrorFactory.TypeError(HAS_INSTANCE_NOT_CALLABLE, Node.Line, Node.Column);

    const IsOrdinary = Assigned(FOrdinaryHasInstance) and (HandlerFunc as IInterface = FOrdinaryHasInstance as IInterface);
    if not IsOrdinary then
    begin
      const Verdict = CallFunction(HandlerFunc, [Left], RightObject);
      Exit(Verdict.ToBoolean);
    end;
  end;

  var RightFunc: IJSFunction;
  const IsCallableTarget = Right.IsFunction and Supports(RightObject, IJSFunction, RightFunc);
  if not IsCallableTarget then
    raise TJSErrorFactory.TypeError(INSTANCEOF_NOT_CALLABLE, Node.Line, Node.Column);

  Result := OrdinaryHasInstance(RightFunc, Left, Node.Line, Node.Column);
end;

function TJSInterpreter.OrdinaryHasInstance(const Constructor_: IJSFunction; const Value: TJSValue;
                                            const Line: Integer; const Column: Integer): Boolean;
begin
  if not Value.IsObject then
    Exit(False);

  const RightFunc = UnwrapBoundFunction(Constructor_);
  const LeftObj = Value.ToObject;

  const IsInstance = IsInPrototypeChain(LeftObj, RightFunc) or IsInstanceOfBuiltinConstructor(LeftObj, RightFunc);
  if IsInstance then
    Exit(True);

  const PrototypeValue = RightFunc.GetProperty(PROTOTYPE_PROPERTY);
  const HasObjectPrototype = PrototypeValue.IsObject;
  if not HasObjectPrototype then
    raise TJSErrorFactory.TypeError(INSTANCEOF_PROTOTYPE_NOT_OBJECT, Line, Column);

  Result := False;
end;

function TJSInterpreter.EvaluateIn(const Left: TJSValue; const Right: TJSValue;
                                   const Node: TJSBinaryExpression): Boolean;
begin
  if not Right.IsObject then
    raise TJSErrorFactory.TypeError(IN_NOT_OBJECT, Node.Line, Node.Column);

  const PropertyName = ToPropertyKey(Left);

  Result := Right.ToObject.HasProperty(PropertyName);
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
    TJSBinaryOperator.Exponent,
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
      Result := TJSValue.CreateBoolean(EvaluateInstanceOf(Left, Right, Node));
    TJSBinaryOperator.In_:
      Result := TJSValue.CreateBoolean(EvaluateIn(Left, Right, Node));
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

  const IsPattern = (Node.Left is TJSArrayPattern) or (Node.Left is TJSObjectPattern);
  if IsPattern then
  begin
    Result := AssignToPattern(Node);
    Exit;
  end;

  raise TJSErrorFactory.InvalidLeftHandSide(Node.Line, Node.Column);
end;

function TJSInterpreter.AssignToPattern(const Node: TJSAssignmentExpression): TJSValue;
begin
  Result := Visit(Node.Right);
  BindTarget(Node.Left, Result, TJSBindingMode.Assign);
end;

procedure TJSInterpreter.BindTarget(const Target: TJSExpression; const Value: TJSValue; const Mode: TJSBindingMode);
begin
  const Resolved = ResolvePatternTarget(Target, Mode);
  StorePatternTarget(Resolved, Value, Mode);
end;

function TJSInterpreter.ResolvePatternTarget(const Element: TJSExpression;
                                             const Mode: TJSBindingMode): TJSPatternTarget;
begin
  Result := Default(TJSPatternTarget);
  Result.Target := Element;

  if Element is TJSAssignmentPattern then
  begin
    Result.Target := TJSAssignmentPattern(Element).Target;
    Result.Default := TJSAssignmentPattern(Element).Default;
  end;

  if Mode <> TJSBindingMode.Assign then
    Exit;

  if Result.Target is TJSIdentifier then
    Result.Binding := FCurrentScope.Resolve(TJSIdentifier(Result.Target).Name)
  else if Result.Target is TJSMemberExpression then
    Result.Reference := ResolveMemberReference(TJSMemberExpression(Result.Target));
end;

procedure TJSInterpreter.StorePatternTarget(const Target: TJSPatternTarget; const Value: TJSValue;
                                            const Mode: TJSBindingMode);
begin
  var StoredValue := Value;

  const UsesDefault = Value.IsUndefined and Assigned(Target.Default);
  if UsesDefault then
  begin
    const IsNamedTarget = (Target.Target is TJSIdentifier) and (not TJSIdentifier(Target.Target).IsParenthesized);
    if IsNamedTarget then
      StoredValue := VisitNamed(Target.Default, TJSIdentifier(Target.Target).Name)
    else
      StoredValue := Visit(Target.Default);
  end;

  case Target.Target.NodeType of
    TJSASTNodeType.Identifier:
      StoreIdentifier(Target, StoredValue, Mode);
    TJSASTNodeType.MemberExpression:
      begin
        var Reference := Target.Reference;
        PutReferenceValue(Reference, StoredValue);
      end;
    TJSASTNodeType.ArrayPattern:
      BindArrayPattern(TJSArrayPattern(Target.Target), StoredValue, Mode);
    TJSASTNodeType.ObjectPattern:
      BindObjectPattern(TJSObjectPattern(Target.Target), StoredValue, Mode);
  else
    raise TJSErrorFactory.InvalidLeftHandSide(Target.Target.Line, Target.Target.Column);
  end;
end;

procedure TJSInterpreter.StoreIdentifier(const Target: TJSPatternTarget; const Value: TJSValue;
                                         const Mode: TJSBindingMode);
begin
  const Identifier = TJSIdentifier(Target.Target);

  case Mode of
    TJSBindingMode.Variable:
      FCurrentScope.SetVariable(Identifier.Name, Value);
    TJSBindingMode.Lexical:
      FCurrentScope.InitializeLexical(Identifier.Name, Value);
  else
    const IsUndeclared = FStrictMode and (not FCurrentScope.HasVariable(Identifier.Name));
    if IsUndeclared then
      raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);

    PutIdentifierValue(Target.Binding, Identifier.Name, Value);
  end;
end;

procedure TJSInterpreter.BindArrayPattern(const Pattern: TJSArrayPattern; const Value: TJSValue;
                                          const Mode: TJSBindingMode);
begin
  var Source := OpenIterationSource(Value);

  try
    BindArrayElements(Pattern, Source, Mode);
  except
    on EJSExecutionInterrupted do
      raise;
    on EJSControlFlowSignal do
      raise;
    on Exception do
    begin
      Source.CloseAfterThrow;
      raise;
    end;
  end;

  Source.Close;
end;

procedure TJSInterpreter.BindArrayElements(const Pattern: TJSArrayPattern; var Source: TJSIterationSource;
                                           const Mode: TJSBindingMode);
begin
  for var Element in Pattern.Elements do
  begin
    const IsHole = (Element = nil);
    if IsHole then
    begin
      Source.Next;
      Continue;
    end;

    if Element is TJSSpreadElement then
    begin
      const RestTarget = ResolvePatternTarget(TJSSpreadElement(Element).Argument, Mode);
      const RemainingValues = Source.Remaining;
      const RestArray = CreateRestArray(RemainingValues, 0);
      StorePatternTarget(RestTarget, RestArray, Mode);
      Break;
    end;

    const Resolved = ResolvePatternTarget(Element, Mode);
    const NextValue = Source.Next;
    StorePatternTarget(Resolved, NextValue, Mode);
  end;
end;

function TJSInterpreter.OpenIterationSource(const Value: TJSValue): TJSIterationSource;
begin
  if not TryOpenIterationSource(Value, Result) then
    raise TJSErrorFactory.TypeError(PATTERN_NOT_ITERABLE);
end;

function TJSInterpreter.TryOpenIterationSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
begin
  Source := Default(TJSIterationSource);

  if Value.IsNullOrUndefined then
    Exit(False);

  Result := TryOpenFastSource(Value, Source) or TryOpenProtocolSource(Value, Source);
end;

function TJSInterpreter.TryOpenFastSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
begin
  Result := True;

  if Value.IsString then
  begin
    const IsUntouched = HasUntouchedStringIteration;
    if IsUntouched then
      Source := OpenStringSource(Value.ToString);

    Exit(IsUntouched);
  end;

  if not Value.IsObject then
    Exit(False);

  const Target = Value.ToObject;

  var SourceArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, SourceArray);
  const IsArguments = (not IsArray) and Supports(Target, IJSArgumentsScope);
  if not (IsArray or IsArguments) then
    Exit(False);

  const IsUntouched = HasUntouchedArrayIteration(Target);
  if not IsUntouched then
    Exit(False);

  if IsArray then
    Source.Elements := SourceArray
  else
    Source.ArrayLike := Target;
end;

function TJSInterpreter.TryOpenProtocolSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
begin
  var IteratorFunction: IJSFunction;
  Result := FindIteratorMethod(Value, IteratorFunction);
  if Result then
    Source := OpenProtocolSource(Value, IteratorFunction);
end;

function TJSInterpreter.FindIteratorMethod(const Value: TJSValue; out IteratorFunction: IJSFunction): Boolean;
begin
  IteratorFunction := nil;

  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);
  const Method = ReadMember(Value, IteratorKey);
  if Method.IsNullOrUndefined then
    Exit(False);

  const IsCallable = Method.IsFunction and Supports(Method.ToObject, IJSFunction, IteratorFunction);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(ITERATOR_METHOD_NOT_CALLABLE);

  Result := True;
end;

function TJSInterpreter.OpenProtocolSource(const Value: TJSValue; const IteratorFunction: IJSFunction): TJSIterationSource;
begin
  Result := Default(TJSIterationSource);

  const IteratorValue = CallFunction(IteratorFunction, nil, ThisObjectFor(IteratorFunction, Value));
  if not IteratorValue.IsObject then
    raise TJSErrorFactory.TypeError(ITERATOR_NOT_AN_OBJECT);

  Result.Protocol := TJSIteratorRecord.Create(Self, IteratorValue.ToObject);
end;

function TJSInterpreter.IsIntrinsic(const Candidate: TJSValue; const Original: IInterface): Boolean;
begin
  Result := Assigned(Original) and Candidate.IsObject and ((Candidate.ToObject as IInterface) = Original);
end;

function TJSInterpreter.IsIntrinsicProperty(const Start: IJSObject; const Key: string;
                                            const Original: IInterface): Boolean;
begin
  Result := False;
  if not Assigned(Original) then
    Exit;

  var Current := Start;
  while Assigned(Current) do
  begin
    const IsOrdinaryObject = Current is TJSObjectImpl;
    if not IsOrdinaryObject then
      Exit;

    var Slot: PJSPropertyDescriptor;
    if TJSObjectImpl(Current).TryGetOwnSlot(Key, Slot) then
      Exit((not Slot.IsAccessor) and IsIntrinsic(Slot.Value, Original));

    Current := Current.Prototype;
  end;
end;

function TJSInterpreter.HoldsIntrinsic(var Cache: TJSIntrinsicSlot; const Holder: IJSObject; const Key: string;
                                       const Original: IInterface): Boolean;
begin
  const IsOrdinaryObject = Assigned(Original) and (Holder is TJSObjectImpl);
  if not IsOrdinaryObject then
    Exit(False);

  const HolderObject = TJSObjectImpl(Holder);
  const IsCached = (Cache.Holder = HolderObject) and (Cache.Version = HolderObject.PropertyLayoutVersion);
  if not IsCached then
  begin
    Cache.Holder := nil;
    if not HolderObject.TryGetOwnSlot(Key, Cache.Slot) then
      Exit(False);

    Cache.Holder := HolderObject;
    Cache.Version := HolderObject.PropertyLayoutVersion;
  end;

  Result := (not Cache.Slot.IsAccessor) and IsIntrinsic(Cache.Slot.Value, Original);
end;

function TJSInterpreter.HasPlainArrayPrototype(const Target: IJSObject; const Key: string): Boolean;
begin
  Result := False;

  const HasArrayPrototype = (Target.Prototype = FArrayPrototype);
  if not (HasArrayPrototype and (Target is TJSObjectImpl)) then
    Exit;

  var OwnSlot: PJSPropertyDescriptor;
  Result := not TJSObjectImpl(Target).TryGetOwnSlot(Key, OwnSlot);
end;

function TJSInterpreter.HasUntouchedArrayIteration(const Target: IJSObject): Boolean;
begin
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  const IsOriginalValues = (HasPlainArrayPrototype(Target, IteratorKey) and
                            HoldsIntrinsic(FArrayValuesSlot, FArrayPrototype, IteratorKey, FIteration.ArrayValues)) or
                           IsIntrinsicProperty(Target, IteratorKey, FIteration.ArrayValues);

  Result := IsOriginalValues and
            HoldsIntrinsic(FArrayNextSlot, FIteration.ArrayIteratorPrototype, ITERATOR_NEXT_PROPERTY,
                           FIteration.ArrayIteratorNext);
end;

function TJSInterpreter.HasUntouchedStringIteration: Boolean;
begin
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  Result := HoldsIntrinsic(FStringIteratorSlot, FStringPrototype, IteratorKey, FIteration.StringIterator) and
            HoldsIntrinsic(FStringNextSlot, FIteration.StringIteratorPrototype, ITERATOR_NEXT_PROPERTY,
                           FIteration.StringIteratorNext);
end;

function TJSInterpreter.OpenStringSource(const Text: string): TJSIterationSource;
begin
  Result := Default(TJSIterationSource);

  const Items = TList<TJSValue>.Create;
  try
    AppendStringValues(Text, Items);
    Result.Items := Items.ToArray;
  finally
    Items.Free;
  end;
end;
procedure TJSInterpreter.BindObjectPattern(const Pattern: TJSObjectPattern; const Value: TJSValue;
                                           const Mode: TJSBindingMode);
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(Format(CANNOT_DESTRUCTURE, [ToText(Value)]));

  var Excluded: TList<string> := nil;
  try
    if Assigned(Pattern.Rest) then
      Excluded := TList<string>.Create;

    for var Prop in Pattern.Properties do
    begin
      var KeyHolder: TJSValue;
      const KeyName = LiteralPropertyName(Prop, KeyHolder);
      if Assigned(Excluded) then
        Excluded.Add(KeyName);

      const Resolved = ResolvePatternTarget(Prop.Value, Mode);
      const PropertyValue = ReadMember(Value, KeyName);
      StorePatternTarget(Resolved, PropertyValue, Mode);
    end;

    if Assigned(Pattern.Rest) then
    begin
      const RestTarget = ResolvePatternTarget(Pattern.Rest, Mode);
      const RestObject = CopyRestProperties(Value, Excluded);
      StorePatternTarget(RestTarget, RestObject, Mode);
    end;
  finally
    Excluded.Free;
  end;
end;

function TJSInterpreter.CopyRestProperties(const Source: TJSValue; const Excluded: TList<string>): TJSValue;
begin
  const Rest: IJSObject = TJSObject.Create;
  Rest.Prototype := FObjectPrototype;

  CopyDataProperties(Rest, Source, Excluded);

  Result := TJSValue.CreateObject(Rest);
end;

procedure TJSInterpreter.CopyDataProperties(const Target: IJSObject; const Source: TJSValue;
                                            const Excluded: TList<string>);
begin
  if Source.IsString then
  begin
    const Text = Source.ToString;

    for var Index := 1 to Length(Text) do
    begin
      const PropName = IntToStr(Index - 1);
      const IsCopied = (not Assigned(Excluded)) or (not Excluded.Contains(PropName));
      if IsCopied then
        Target.DefineProperty(PropName, TJSPropertyDescriptor.Create(TJSValue.CreateString(Text[Index])));
    end;

    Exit;
  end;

  if not Source.IsObject then
    Exit;

  const Obj = Source.ToObject;

  for var PropName in TJSObjectKeys.All(Obj) do
  begin
    const IsExcluded = Assigned(Excluded) and Excluded.Contains(PropName);
    if IsExcluded or (not Obj.GetOwnPropertyDescriptor(PropName).Enumerable) then
      Continue;

    Target.DefineProperty(PropName, TJSPropertyDescriptor.Create(Obj.GetProperty(PropName)));
  end;
end;

function TJSInterpreter.GlobalDataSlot(const Identifier: TJSIdentifier): PJSPropertyDescriptor;
begin
  Result := nil;

  if FCurrentScope <> FGlobalScope then
    Exit;

  if FGlobalBindings.HasLexicals and FGlobalBindings.HasLexical(Identifier.Name) then
    Exit;

  const Slot = FGlobalBindings.FindOwnSlot(Identifier.BindingCache, Identifier.Name);
  if Assigned(Slot) and (not Slot.IsAccessor) then
    Result := Slot;
end;

procedure TJSInterpreter.StoreGlobalVariable(const Identifier: TJSIdentifier; const Value: TJSValue);
begin
  const Slot = FGlobalBindings.FindOwnSlot(Identifier.BindingCache, Identifier.Name);
  const IsPlainWritable = Assigned(Slot) and (not Slot.IsAccessor) and Slot.Writable;

  if IsPlainWritable then
  begin
    Slot.Value := Value;
    Exit;
  end;

  const IsReadOnlyData = Assigned(Slot) and (not Slot.IsAccessor);
  if IsReadOnlyData and FStrictMode then
    raise TJSErrorFactory.TypeError(Format(ASSIGN_TO_READ_ONLY_GLOBAL, [Identifier.Name]),
                                    Identifier.Line, Identifier.Column);

  FGlobalScope.DeclareVariable(Identifier.Name, Value);
end;

function TJSInterpreter.AssignToGlobalVariable(const Node: TJSAssignmentExpression; const Identifier: TJSIdentifier): TJSValue;
begin
  if Node.Operator = TJSAssignmentOperator.Assign then
  begin
    Result := VisitAssigned(Node.Right, Identifier);
  end
  else
  begin
    const Current = GlobalDataSlot(Identifier).Value;
    const Right = Visit(Node.Right);
    const BinaryOperator = TJSOperators.BinaryOperatorFor(Node.Operator);
    Result := TJSOperators.Apply(BinaryOperator, Current, Right, FLimits);
  end;

  StoreGlobalVariable(Identifier, Result);
end;

function TJSInterpreter.AssignToIdentifier(const Node: TJSAssignmentExpression): TJSValue;
begin
  const Identifier = TJSIdentifier(Node.Left);

  const IsGlobalVariable = Assigned(GlobalDataSlot(Identifier));
  if IsGlobalVariable then
    Exit(AssignToGlobalVariable(Node, Identifier));

  const Binding = FCurrentScope.Resolve(Identifier.Name);

  const IsUndeclaredInStrictCode = FStrictMode and (not Assigned(Binding));
  if IsUndeclaredInStrictCode then
    raise TJSErrorFactory.ReferenceError('Assignment to undeclared variable ' + Identifier.Name, Node.Line, Node.Column);

  var NewValue: TJSValue;
  if Node.Operator = TJSAssignmentOperator.Assign then
  begin
    NewValue := VisitAssigned(Node.Right, Identifier);
  end
  else
  begin
    if not Assigned(Binding) then
      raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Node.Line, Node.Column);

    const Current = GetBindingValue(Binding, Identifier.Name);
    const Right = Visit(Node.Right);
    const BinaryOperator = TJSOperators.BinaryOperatorFor(Node.Operator);
    NewValue := TJSOperators.Apply(BinaryOperator, Current, Right, FLimits);
  end;

  PutIdentifierValue(Binding, Identifier.Name, NewValue);
  Result := NewValue;
end;

function TJSInterpreter.GetBindingValue(const Binding: IJSScope; const Name: string): TJSValue;
begin
  if not Assigned(Binding) then
    Exit(FCurrentScope.GetVariable(Name));

  const BindingObject = Binding as TObject;
  const IsPlainScope = (BindingObject.ClassType = TJSScope);
  if IsPlainScope then
    Exit(Binding.GetVariable(Name));

  var ObjectScope: IJSObjectScope;
  if Supports(Binding, IJSObjectScope, ObjectScope) then
    Exit(ObjectScope.GetBindingValue(Name, FStrictMode));

  Result := Binding.GetVariable(Name);
end;

procedure TJSInterpreter.PutIdentifierValue(const Binding: IJSScope; const Name: string; const Value: TJSValue);
begin
  if not Assigned(Binding) then
  begin
    FCurrentScope.SetVariable(Name, Value);
    Exit;
  end;

  const BindingObject = Binding as TObject;
  const IsPlainScope = (BindingObject.ClassType = TJSScope);
  if IsPlainScope then
  begin
    Binding.AssignVariable(Name, Value);
    Exit;
  end;

  if Binding is TJSFunctionNameScope then
  begin
    RejectFunctionNameAssignment;
    Exit;
  end;

  var ObjectScope: IJSObjectScope;
  if Supports(Binding, IJSObjectScope, ObjectScope) then
  begin
    ObjectScope.SetMutableBinding(Name, Value, FStrictMode);
    Exit;
  end;

  const IsGlobalBinding = (Binding = FGlobalScope);
  if FStrictMode and IsGlobalBinding then
  begin
    GuardBindingStillExists(FGlobalBindings.HasVariable(Name), Name);
    GuardGlobalWritable(Name);
  end;

  Binding.AssignVariable(Name, Value);
end;

procedure TJSInterpreter.RejectFunctionNameAssignment;
begin
  if FStrictMode then
    raise TJSErrorFactory.TypeError(FUNCTION_NAME_ASSIGNMENT);
end;

procedure TJSInterpreter.GuardGlobalWritable(const Name: string);
begin
  if FGlobalBindings.IsReadOnlyData(Name) then
    raise TJSErrorFactory.TypeError(Format(ASSIGN_TO_READ_ONLY_GLOBAL, [Name]));
end;

procedure TJSInterpreter.GuardBindingStillExists(const StillExists: Boolean; const Name: string);
begin
  if not StillExists then
    raise TJSErrorFactory.ReferenceError('Assignment to undeclared variable ' + Name);
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

function TJSInterpreter.UpdateGlobalVariable(const Node: TJSUpdateExpression; const Identifier: TJSIdentifier): TJSValue;
begin
  const OldNumber = TJSOperators.ToNumber(GlobalDataSlot(Identifier).Value);

  var NewNumber := OldNumber - 1;
  if Node.Operator = TJSUpdateOperator.Increment then
    NewNumber := OldNumber + 1;

  const NewValue = TJSValue.CreateNumber(NewNumber);
  StoreGlobalVariable(Identifier, NewValue);

  if Node.Prefix then
    Result := NewValue
  else
    Result := TJSValue.CreateNumber(OldNumber);
end;

function TJSInterpreter.UpdateIdentifier(const Node: TJSUpdateExpression): TJSValue;
begin
  const Identifier = TJSIdentifier(Node.Argument);

  const IsGlobalVariable = Assigned(GlobalDataSlot(Identifier));
  if IsGlobalVariable then
    Exit(UpdateGlobalVariable(Node, Identifier));

  const Binding = FCurrentScope.Resolve(Identifier.Name);
  const OldValue = GetBindingValue(Binding, Identifier.Name);
  const OldNumber = TJSOperators.ToNumber(OldValue);

  var NewNumber := OldNumber - 1;
  if Node.Operator = TJSUpdateOperator.Increment then
    NewNumber := OldNumber + 1;

  const NewValue = TJSValue.CreateNumber(NewNumber);
  PutIdentifierValue(Binding, Identifier.Name, NewValue);

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
  var CalleeValue := TJSValue.CreateUndefined;
  var MethodName := '';

  const IsMemberCall = Node.Callee is TJSMemberExpression;
  if IsMemberCall then
  begin
    const MemberExpr = TJSMemberExpression(Node.Callee);
    const ObjValue = Visit(MemberExpr.Object_);
    ThisValue := ObjValue;

    if MemberExpr.Computed then
      MethodName := ToPropertyKey(Visit(MemberExpr.Property_))
    else
      MethodName := TJSIdentifier(MemberExpr.Property_).Name;

    Args := EvaluateArguments(Node.Arguments, Node.HasSpread);
    ArgsEvaluated := True;

    RequireObjectCoercible(ObjValue, MethodName);
    CalleeValue := ReadMember(ObjValue, MethodName);

    if ObjValue.IsArray and IsIntrinsicMethod(TJSIntrinsicGroup.ArrayMethod, MethodName, CalleeValue) then
    begin
      var ArrIntf: IJSArray;
      if Supports(ObjValue.ToObject, IJSArray, ArrIntf) then
        Exit(ExecuteArrayMethod(ArrIntf, MethodName, Args));
    end;

    if ObjValue.IsFunction and IsIntrinsicMethod(TJSIntrinsicGroup.FunctionMethod, MethodName, CalleeValue) then
    begin
      var FuncIntf: IJSFunction;
      if Supports(ObjValue.ToObject, IJSFunction, FuncIntf) then
        Exit(ExecuteFunctionMethod(FuncIntf, MethodName, Args));
    end;

    if ObjValue.IsObject and IsIntrinsicMethod(TJSIntrinsicGroup.ObjectMethod, MethodName, CalleeValue) then
      Exit(TJSBuiltins.CallObjectMethod(ObjValue.ToObject, MethodName, Args, FLimits));

    if ObjValue.IsObject then
      ThisObj := ObjValue.ToObject;
  end
  else if Node.Callee is TJSIdentifier then
  begin
    CalleeValue := VisitCalleeIdentifier(TJSIdentifier(Node.Callee), ThisObj);
  end
  else
  begin
    CalleeValue := Visit(Node.Callee);
  end;

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  if not ArgsEvaluated then
    Args := EvaluateArguments(Node.Arguments, Node.HasSpread);

  if IsDirectEvalCall(Node.Callee, Func) then
    Exit(CallDirectEval(Func, Args));

  if not Assigned(ThisObj) then
    ThisObj := ThisObjectFor(Func, ThisValue);

  Result := CallFunction(Func, Args, ThisObj);
end;

procedure TJSInterpreter.RegisterIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string;
                                                 const Method: IJSObject);
begin
  if not Assigned(FIntrinsicMethods[Group]) then
    FIntrinsicMethods[Group] := TDictionary<string, IJSObject>.Create;

  FIntrinsicMethods[Group].AddOrSetValue(Name, Method);
end;

function TJSInterpreter.IsIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string;
                                          const Callee: TJSValue): Boolean;
begin
  Result := False;

  const Methods = FIntrinsicMethods[Group];
  if not (Assigned(Methods) and Callee.IsFunction) then
    Exit;

  var Method: IJSObject;
  Result := Methods.TryGetValue(Name, Method) and (Callee.ToObject = Method);
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

  if Reference.Key.IsSymbol then
    Exit(Reference.Key.SymbolDescriptiveString);

  Result := ToText(Reference.Key);
end;

function TJSInterpreter.ToPropertyKey(const Key: TJSValue): string;
begin
  Result := Key.ToPropertyKey(FLimits);
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
        Result := TJSValue.CreateNumber(ArrIntf.LogicalLength);
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
    Result := ReadPrimitiveMember(Base, PrimitivePrototype, PropName);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.ReadPrimitiveMember(const Base: TJSValue; const PrimitivePrototype: IJSObject;
                                            const PropName: string): TJSValue;
begin
  var Descriptor: TJSPropertyDescriptor;
  if not PrimitivePrototype.TryGetPropertyDescriptor(PropName, Descriptor) then
    Exit(TJSValue.CreateUndefined);

  if not Descriptor.IsAccessor then
    Exit(Descriptor.Value);

  var Getter: IJSFunction;
  const HasGetter = Descriptor.Getter.IsFunction and Supports(Descriptor.Getter.ToObject, IJSFunction, Getter);
  if not HasGetter then
    Exit(TJSValue.CreateUndefined);

  const Receiver = ThisObjectFor(Getter, Base);
  Result := CallFunction(Getter, nil, Receiver);
end;

function TJSInterpreter.VisitNewExpression(const Node: TJSNewExpression): TJSValue;
begin
  const CalleeValue = Visit(Node.Callee);
  const Args = EvaluateArguments(Node.Arguments, Node.HasSpread);

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  if not Func.IsConstructor then
    raise TJSErrorFactory.NotAConstructor(GetCalleeDescription(Node.Callee, CalleeValue), Node.Line, Node.Column);

  Result := Construct(Func, Args);
end;

function TJSInterpreter.Construct(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := Construct(Func, Args, Func);
end;

function TJSInterpreter.Construct(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                  const NewTarget: IJSFunction): TJSValue;
begin
  var Bound: TJSBoundFunction;
  if FBoundFunctions.TryGetValue(Pointer(Func as IInterface), Bound) then
  begin
    const IsOwnTarget = ((NewTarget as IInterface) = (Func as IInterface));
    if IsOwnTarget then
      Exit(Construct(Bound.Target, Bound.Arguments + Args, Bound.Target));

    Exit(Construct(Bound.Target, Bound.Arguments + Args, NewTarget));
  end;

  var NativeConstructor: IJSNativeConstructor;
  if Func.IsNative and Supports(Func, IJSNativeConstructor, NativeConstructor) then
    Exit(NativeConstructor.ConstructWith(Args, NewTarget));

  const NewObj = CreateInstanceFor(NewTarget);
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
  if Assigned(FThisPrimitive) then
    Result := FThisPrimitive.Value
  else if Assigned(FThisValue) then
    Result := TJSValue.CreateObject(FThisValue)
  else if FStrictMode and (FCallDepth > 0) then
    Result := TJSValue.CreateUndefined
  else
    Result := TJSValue.CreateObject(FGlobalObject);
end;

function TJSInterpreter.VisitTemplateLiteral(const Node: TJSTemplateLiteral): TJSValue;
begin
  var Text := Node.Parts[0].Cooked;

  for var Index := 0 to Node.Expressions.Count - 1 do
  begin
    const Substitution = ToStringCoerced(Visit(Node.Expressions[Index]));
    Text := Text + Substitution + Node.Parts[Index + 1].Cooked;
  end;

  Result := TJSValue.CreateString(Text);
end;

function TJSInterpreter.VisitTemplateObject(const Node: TJSTemplateObject): TJSValue;
begin
  var Strings: IJSArray;
  const IsCached = Supports(Node.CachedObject, IJSArray, Strings);
  if not IsCached then
  begin
    Strings := CreateTemplateObject(Node);
    Node.CachedObject := Strings;
  end;

  Result := TJSValue.CreateObject(Strings);
end;

function TJSInterpreter.CreateTemplateObject(const Node: TJSTemplateObject): IJSArray;
begin
  const Cooked = TJSArray.Create;
  Cooked.Prototype := FArrayPrototype;

  const Raw = TJSArray.Create;
  Raw.Prototype := FArrayPrototype;

  for var Part in Node.Parts do
  begin
    if Part.HasCooked then
      Cooked.Push(TJSValue.CreateString(Part.Cooked))
    else
      Cooked.Push(TJSValue.CreateUndefined);

    Raw.Push(TJSValue.CreateString(Part.Raw));
  end;

  Raw.Freeze;

  var RawDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Raw));
  RawDescriptor.Writable := False;
  RawDescriptor.Enumerable := False;
  RawDescriptor.Configurable := False;
  Cooked.DefineProperty(RAW_PROPERTY, RawDescriptor);
  Cooked.Freeze;

  Result := Cooked;
end;

function TJSInterpreter.ToStringCoerced(const Value: TJSValue): string;
begin
  const NeedsConversion = Value.IsObject and (not Value.IsArray);
  if NeedsConversion then
  begin
    const Primitive = Value.ToPrimitive(True);
    Exit(ToText(Primitive));
  end;

  Result := ToText(Value);
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
  const OldThisPrimitive = FThisPrimitive;
  const OldStrictMode = FStrictMode;
  const OldScope = FCurrentScope;
  const OldVarScope = FVarScope;
  const IsArrow = Func.IsArrow;
  if IsArrow then
    FThisValue := Func.LexicalThis
  else
    FThisValue := ThisObj;
  FStrictMode := Func.IsStrict;
  FThisPrimitive := StrictPrimitiveThis(FThisValue, Func.IsStrict);

  var ParentScope: IJSScope;
  if Assigned(Func.ClosureScope) then
    ParentScope := Func.ClosureScope
  else
    ParentScope := FGlobalScope;

  FCurrentScope := TJSScope.Create(ParentScope);
  FVarScope := FCurrentScope;
  RegisterScope(FCurrentScope);
  Inc(FCallDepth);
  try
    if (not IsArrow) and ReferencesArguments(Func) then
    begin
      FCurrentScope.DeclareVariable(ARGUMENTS_NAME, TJSValue.CreateObject(CreateArgumentsObject(Args, Func)));
    end;

    const FunctionBody = TJSBlockStatement(Func.BodyNode);
    const ParameterInfo = FunctionBody.ParameterInfo;
    var ParameterScope: IJSScope := nil;

    if Assigned(ParameterInfo) then
    begin
      ParameterScope := BindParametersWithExpressions(Func, Args, ParameterInfo);
    end
    else
    begin
      for var Index := 0 to Length(Func.Parameters) - 1 do
      begin
        if Index < Length(Args) then
          FCurrentScope.DeclareVariable(Func.Parameters[Index], Args[Index])
        else
          FCurrentScope.DeclareVariable(Func.Parameters[Index], TJSValue.CreateUndefined);
      end;
    end;

    InstantiateTopLevel(FunctionBody.Body, FunctionBody.ScopeInfo);

    if Assigned(ParameterScope) then
      CopyParametersToBodyScope(Func, ParameterScope, ParameterInfo);

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
    FVarScope := OldVarScope;
    FThisValue := OldThis;
    FThisPrimitive := OldThisPrimitive;
    FStrictMode := OldStrictMode;
  end;
end;

function TJSInterpreter.StrictPrimitiveThis(const ThisObj: IJSObject; const IsStrict: Boolean): TJSStrictThis;
begin
  Result := nil;

  const CanHoldPrimitive = IsStrict and Assigned(ThisObj);
  if CanHoldPrimitive and (ThisObj is TJSStrictThis) then
    Result := ThisObj as TJSStrictThis;
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

function TJSInterpreter.CreatesSpeciesResult(const MethodName: string): Boolean;
begin
  Result := TJSArrayGeneric.CreatesResultArray(MethodName) or TJSArrayIteration.CreatesResultArray(MethodName);
end;

function TJSInterpreter.ResolveArraySpecies(const Target: IJSObject; const MethodName: string): IJSFunction;
begin
  Result := nil;

  if CreatesSpeciesResult(MethodName) then
    Result := TJSArrayLike.SpeciesConstructor(Target, FArrayConstructor, FArraySpeciesGetter);
end;

function TJSInterpreter.CopyToSpeciesResult(const Species: IJSFunction; const Plain: TJSValue;
                                            const MethodName: string): TJSValue;
begin
  const Source = Plain.ToObject as IJSArray;
  const SourceLength = Source.Length;

  const SetsLength = TJSArrayGeneric.CreatesResultArray(MethodName);

  var InitialLength := SourceLength;
  const StartsEmpty = (MethodName = METHOD_FILTER) or (MethodName = METHOD_CONCAT) or
                      (MethodName = METHOD_FLAT) or (MethodName = METHOD_FLAT_MAP);
  if StartsEmpty then
    InitialLength := 0;

  Result := Construct(Species, [TJSValue.CreateNumber(InitialLength)]);

  const Created = Result.ToObject;
  var Definition := Default(TJSPropertyDefinition);
  Definition.HasWritable := True;
  Definition.Writable := True;
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;
  Definition.HasValue := True;

  for var Index := 0 to SourceLength - 1 do
  begin
    if not Source.HasElement(Index) then
      Continue;

    Definition.Value := Source[Index];
    TJSPropertyDescriptors.Define(Created, IntToStr(Index), Definition, FLimits);
  end;

  if SetsLength then
    TJSArrayLike.WriteLength(Created, SourceLength);
end;

function TJSInterpreter.ExecuteArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSArrayIteration.Handles(MethodName) then
    Exit(ExecuteArrayIterationMethod(Arr, MethodName, Args));

  const Species = ResolveArraySpecies(Arr, MethodName);

  Result := ExecuteArrayMethodCore(Arr, MethodName, Args);

  if Assigned(Species) then
    Result := CopyToSpeciesResult(Species, Result, MethodName);
end;

function TJSInterpreter.ExecuteArrayIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSArrayIteration.CreatesResultArray(MethodName) then
    Result := ExecuteSpeciesIterationMethod(Target, MethodName, Args)
  else
    Result := ExecuteArrayIterationMethodCore(Target, MethodName, Args, nil);
end;

function TJSInterpreter.ExecuteSpeciesIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Species: IJSFunction := nil;
  const FindSpecies: TProc =
    procedure
    begin
      Species := ResolveArraySpecies(Target, MethodName);
    end;

  Result := ExecuteArrayIterationMethodCore(Target, MethodName, Args, FindSpecies);

  if Assigned(Species) then
    Result := CopyToSpeciesResult(Species, Result, MethodName);
end;

function TJSInterpreter.ExecuteGenericArrayMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Species = ResolveArraySpecies(Target, MethodName);

  Result := ExecuteGenericArrayMethodCore(Target, MethodName, Args);

  if Assigned(Species) then
    Result := CopyToSpeciesResult(Species, Result, MethodName);
end;

function TJSInterpreter.ExecuteArrayMethodCore(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSArrayIteration.Handles(MethodName) then
    Exit(ExecuteArrayIterationMethodCore(Arr, MethodName, Args, nil));

  const UsesPropertySemantics = (not Arr.IsDenseAndMutable) or TJSArrayGeneric.AlwaysUsesPropertySemantics(MethodName) or
                                TJSArrayGeneric.ConcatsCustomItems(MethodName, Arr, Args) or
                                (TJSArrayGeneric.StoresNewElements(MethodName) and PrototypeHoldsElements);
  const NeedsPropertyLevelSemantics = UsesPropertySemantics and TJSArrayGeneric.Handles(MethodName);
  if NeedsPropertyLevelSemantics then
    Exit(ExecuteGenericArrayMethodCore(Arr, MethodName, Args));

  if not TJSBuiltins.RequiresCallback(MethodName) then
    Exit(WithArrayPrototype(TJSBuiltins.CallArrayMethod(Arr, MethodName, Args, FLimits)));

  const Executor = CreateCallbackExecutor(MethodName, Args);
  Result := WithArrayPrototype(TJSBuiltins.CallArrayMethodWithCallback(Arr, MethodName, Args, Executor, FLimits));
end;

function TJSInterpreter.ExecuteArrayIterationMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                                                        const BeforeElements: TProc): TJSValue;
begin
  const Executor = CreateCallbackExecutor(MethodName, Args);
  Result := TJSArrayIteration.Call(Target, MethodName, Args, Executor, FArrayPrototype, FLimits, BeforeElements);
end;

function TJSInterpreter.ExecuteGenericArrayMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Context: TJSArrayGenericContext;
  Context.ArrayPrototype := FArrayPrototype;
  Context.ObjectPrototype := FObjectPrototype;
  Context.Limits := FLimits;
  Context.Executor := CreateCallbackExecutor(MethodName, Args);
  Context.InvokeMethod := InvokeMethod;

  Result := TJSArrayGeneric.Call(Target, MethodName, Args, Context);
end;

function TJSInterpreter.PrototypeHoldsElements: Boolean;
begin
  var PrototypeArray: IJSArray;
  Result := Supports(FArrayPrototype, IJSArray, PrototypeArray) and (PrototypeArray.Length > 0);
end;

function TJSInterpreter.InvokeMethod(const Target: TJSValue; const MethodName: string): TJSValue;
begin
  const Callee = ReadMember(Target, MethodName);

  var Func: IJSFunction;
  const IsCallable = Callee.IsFunction and Supports(Callee.ToObject, IJSFunction, Func);
  if not IsCallable then
    raise TJSErrorFactory.NotAFunction(MethodName);

  Result := CallFunction(Func, nil, ThisObjectFor(Func, Target));
end;

function TJSInterpreter.ExecuteArrayStaticMethod(const ThisObj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Context: TJSArrayStaticsContext;
  Context.ArrayPrototype := FArrayPrototype;
  Context.Limits := FLimits;
  Context.Construct :=
    function(const Constructor_: IJSFunction; const ConstructorArgs: TArray<TJSValue>): TJSValue
    begin
      Result := Construct(Constructor_, ConstructorArgs);
    end;
  Context.CallMapper :=
    function(const Mapper: IJSFunction; const MapperArgs: TArray<TJSValue>; const ThisValue: TJSValue): TJSValue
    begin
      Result := CallFunction(Mapper, MapperArgs, ThisObjectFor(Mapper, ThisValue));
    end;
  Context.OpenSequence := OpenSequenceReader;

  Result := TJSArrayStatics.Call(MethodName, ThisObj, Args, Context);
end;

function TJSInterpreter.OpenSequenceReader(const Source: TJSValue; out Reader: TJSSequenceReader;
                                           out Closer: TJSSequenceCloser): Boolean;
begin
  if Source.IsNullOrUndefined then
    Exit(False);

  var Values := Default(TJSIterationSource);
  var IteratorFunction: IJSFunction := nil;
  var IsOpened := TryOpenFastSource(Source, Values);
  if (not IsOpened) and (not FindIteratorMethod(Source, IteratorFunction)) then
    Exit(False);

  Reader :=
    function(out Item: TJSValue): Boolean
    begin
      if not IsOpened then
      begin
        Values := OpenProtocolSource(Source, IteratorFunction);
        IsOpened := True;
      end;

      Result := Values.HasNext;
      if Result then
        Item := Values.Next;
    end;

  Closer :=
    procedure(const AfterThrow: Boolean)
    begin
      if AfterThrow then
        Values.CloseAfterThrow
      else
        Values.Close;
    end;

  Result := True;
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

    const ArgumentList = TJSArrayLike.Argument(Args, 1);
    const FuncArgs = ArgumentsFromList(ArgumentList);

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

    const BoundFunc = CreateBoundFunction(Func, BoundThis, BoundArgs);
    Exit(TJSValue.CreateObject(BoundFunc));
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.CreateBoundFunction(const Target: IJSFunction; const BoundThis: IJSObject;
                                            const BoundArgs: TArray<TJSValue>): IJSFunction;
begin
  const Interp = Self;

  const TargetName = Target.GetProperty(NAME_PROPERTY);
  var BoundName := BOUND_NAME_PREFIX;
  if TargetName.IsString then
    BoundName := BoundName + TargetName.AsString;

  Result := TJSFunction.CreateNative(BoundName,
    function(const This: IJSObject; const CallArgs: TArray<TJSValue>): TJSValue
    begin
      const AllArgs = BoundArgs + CallArgs;
      Result := Interp.CallFunction(Target, AllArgs, BoundThis);
    end);

  Result.ClosureScope := nil;
  Result.IsConstructor := Target.IsConstructor;
  Result.Prototype := FFunctionPrototype;
  TJSFunction.DefineLength(Result, BoundLength(Target, Length(BoundArgs)));
  RegisterFunction(Result);

  var BoundInfo: TJSBoundFunction;
  BoundInfo.Target := Target;
  BoundInfo.Arguments := BoundArgs;
  FBoundFunctions.Add(Pointer(Result as IInterface), BoundInfo);
end;

function TJSInterpreter.UnwrapBoundFunction(const Func: IJSFunction): IJSFunction;
begin
  Result := Func;

  var Bound: TJSBoundFunction;
  while FBoundFunctions.TryGetValue(Pointer(Result as IInterface), Bound) do
  begin
    Result := Bound.Target;
  end;
end;

function TJSInterpreter.ArgumentsFromList(const ArgumentList: TJSValue): TArray<TJSValue>;
begin
  if ArgumentList.IsNullOrUndefined then
    Exit(nil);

  if not ArgumentList.IsObject then
    raise TJSErrorFactory.TypeError(ARGUMENT_LIST_NOT_OBJECT);

  const Source = ArgumentList.ToObject;
  const Count = TJSArrayLike.ToLength(Source);
  FLimits.EnsureArrayLength(Count);

  SetLength(Result, Count);
  for var Index := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Source, Index, Element) then
      Result[Index] := Element
    else
      Result[Index] := TJSValue.CreateUndefined;
  end;
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

  var Proxy: IJSProxy;
  const IsStrictProxy = FStrictMode and TJSObjectOperations.AsProxy(Target, Proxy);
  if IsStrictProxy then
  begin
    if not Proxy.SetWithReceiver(PropName, Value, Base) then
      raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [PropName]));

    Exit;
  end;

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
  const LengthIsWritable = Target.GetOwnPropertyDescriptor(LENGTH_PROPERTY).Writable;
  if not LengthIsWritable then
  begin
    if FStrictMode then
      raise TJSErrorFactory.TypeError(READ_ONLY_LENGTH);

    Exit;
  end;

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

  const IsObjectAgainstPrimitive = Left.IsObject and (Right.IsString or Right.IsNumber or Right.IsSymbol);
  if IsObjectAgainstPrimitive then
  begin
    const LeftPrimitive = TJSOperators.ToPrimitive(Left);
    Exit(AbstractEquals(LeftPrimitive, Right));
  end;

  const IsPrimitiveAgainstObject = Right.IsObject and (Left.IsString or Left.IsNumber or Left.IsSymbol);
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
  FEvalFunction.IsConstructor := False;
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
  for var PropName in TJSObjectKeys.All(Obj) do
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
    GCMark(FVarScope, Live, Work);
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
      var Proxy: IJSProxy;
      var Arr: IJSArray;
      var Obj: IJSObject;

      if Supports(Item, IJSScope, Scope) then
      begin
        GCMark(Scope.Parent, Live, Work);
        for var Value in Scope.GetOwnVariables do
          GCMarkValue(Value, Live, Work);
      end
      else if Supports(Item, IJSProxy, Proxy) then
      begin
        GCMark(Proxy.ProxyTarget, Live, Work);
        GCMark(Proxy.ProxyHandler, Live, Work);
      end
      else if Supports(Item, IJSFunction, Func) then
      begin
        GCMark(Func.ClosureScope, Live, Work);
        GCMark(Func.LexicalThis, Live, Work);
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
        var ArgumentsScope: IJSArgumentsScope;
        if Supports(Obj, IJSArgumentsScope, ArgumentsScope) then
          GCMark(ArgumentsScope.MappedScope, Live, Work);

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
        Func.LexicalThis := nil;
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
