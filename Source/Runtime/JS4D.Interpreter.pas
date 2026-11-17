unit JS4D.Interpreter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.StrUtils,
  System.SyncObjs,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolObject,
  JS4D.RegExpObject,
  JS4D.ArrayObject,
  JS4D.ObjectHeap,
  JS4D.AST,
  JS4D.SourceContext,
  JS4D.Errors,
  JS4D.Builtins,
  JS4D.ObjectScope,
  JS4D.ArgumentsObject,
  JS4D.GlobalScope,
  JS4D.PropertyDescriptors,
  JS4D.ArrayIteration,
  JS4D.IteratorProtocol,
  JS4D.StringIterator,
  JS4D.ArrayStatics,
  JS4D.ArrayGeneric,
  JS4D.ArrayLike,
  JS4D.ObjectKeys,
  JS4D.ObjectOperations,
  JS4D.BinaryData,
  JS4D.ProxyObjects,
  JS4D.ConstructorFunction,
  JS4D.SymbolRegistry,
  JS4D.GeneratorObjects,
  JS4D.AsyncHost,
  JS4D.ObjectRegistry,
  JS4D.Operators,
  JS4D.StrictThis,
  JS4D.StackGuard,
  JS4D.Scope,
  JS4D.ControlFlow,
  JS4D.IterationSource,
  JS4D.StatementFrame,
  JS4D.IntrinsicCache,
  JS4D.ResumableExecution,
  JS4D.ClassEvaluation;

type
  PJSValue = ^TJSValue;

  TJSProgramParser = reference to function(const Source: string; const IsStrictContext: Boolean;
                                           const Context: TJSSourceContext): TJSProgram;

  TJSGCRootProvider = reference to procedure(const MarkValue: TJSValueVisitor);

  TJSBoundFunction = record
    Target: IJSFunction;
    Arguments: TArray<TJSValue>;
  end;

  TJSInterpreter = class;

  TJSMemberReference = record
    Base: TJSValue;
    Key: TJSValue;
    NamedKey: PJSPropertyKey;
    ComputedKey: TJSPropertyKey;
    HasKeyText: Boolean;
    IsSuper: Boolean;
    SuperBaseObject: IJSObject;

    function KeyPointer: PJSPropertyKey; inline;
    procedure ResolveKey(const Limits: TJSLimits); inline;
    procedure Prepare(const Interpreter: TJSInterpreter);
  end;

  TJSEvaluatedKey = record
    Key: TJSPropertyKey;
    LiveSymbol: TJSValue;
  end;

  TJSBindingMode = (Assign, Variable, Lexical);

  TJSPatternTarget = record
    Target: TJSExpression;
    Default: TJSExpression;
    Binding: IJSScope;
    Reference: TJSMemberReference;
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
    FPushCache: TJSMutatorCache;
    FPopCache: TJSMutatorCache;
    FArrayValuesSlot: TJSIntrinsicSlot;
    FArrayNextSlot: TJSIntrinsicSlot;
    FStringIteratorSlot: TJSIntrinsicSlot;
    FStringNextSlot: TJSIntrinsicSlot;
    FOrdinaryHasInstance: IJSFunction;
    FArrayConstructor: IJSFunction;
    FArraySpeciesGetter: IJSFunction;
    FHeap: TJSHeap;
    FHeapEntries: Integer;
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
    FStackFloor: NativeUInt;
    FProgramParser: TJSProgramParser;
    FGCRootProvider: TJSGCRootProvider;
    FJobRunner: TProc;
    FJobDiscarder: TProc;
    FEvalFunction: IJSFunction;
    FDirectEvalCall: Boolean;
    FEvalVariableScope: IJSScope;
    FVarScope: IJSScope;
    FIsGuardingGlobalVariables: Boolean;
    FEvalCallerScope: IJSScope;
    FParameterInitScope: IJSScope;
    FLoopLabels: TArray<string>;
    FContext: TJSCallContext;
    FGenerator: TJSGeneratorObject;
    FBypassNode: TJSASTNode;
    FGenerators: TJSObjectRegistry;
    FGeneratorFunctionPrototype: IJSObject;
    FGeneratorPrototype: IJSObject;
    FAsyncFunctionPrototype: IJSObject;
    FAsyncHost: TJSAsyncHost;
    FGeneratorEngine: TJSResumableExecution;
    FClassBuilder: TJSClassEvaluation;

    procedure SetFunctionPrototype(const Value: IJSObject);
    procedure PopScope;
    procedure AttachPrototype(const Func: IJSFunction);
    function ReferencesArguments(const Func: IJSFunction): Boolean;
    function CreateArgumentsObject(const Args: TArray<TJSValue>; const Func: IJSFunction): IJSObject;
    procedure DefineArgumentsIterator(const ArgumentsObject: IJSObject);
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
    function ResolvePatternTarget(const Element: TJSExpression; const Mode: TJSBindingMode): TJSPatternTarget;
    procedure StorePatternTarget(const Target: TJSPatternTarget; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure StoreIdentifier(const Target: TJSPatternTarget; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindArrayPattern(const Pattern: TJSArrayPattern; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindResumableArrayPattern(const Pattern: TJSArrayPattern; const Value: TJSValue;
                                        const Mode: TJSBindingMode);
    procedure BindResumableElements(const Pattern: TJSArrayPattern; const Frame: TJSStatementFrame;
                                    const Mode: TJSBindingMode);
    procedure BindObjectPattern(const Pattern: TJSObjectPattern; const Value: TJSValue; const Mode: TJSBindingMode);
    procedure BindArrayElements(const Pattern: TJSArrayPattern; var Source: TJSIterationSource;
                                const Mode: TJSBindingMode);
    function OpenIterationSource(const Value: TJSValue): TJSIterationSource;
    function TryOpenFastSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function TryOpenProtocolSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function OpenProtocolSource(const Value: TJSValue; const IteratorFunction: IJSFunction): TJSIterationSource;
    function IsIntrinsicProperty(const Start: IJSObject; const Key: TJSPropertyKey; const Original: IInterface): Boolean;
    function InheritsKeyFromArrayPrototype(const Target: IJSObject; const Key: TJSPropertyKey): Boolean;
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
    function InvokeFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject;
                            const NewTarget: IJSFunction; const Binding: IJSThisBinding): TJSValue;
    procedure EnterContext(const Func: IJSFunction; const NewTarget: IJSFunction; const Binding: IJSThisBinding);
    function CaptureFrame: IJSFrame;
    function CurrentThisValue: TJSValue;
    function ReadBoundThis(const Binding: IJSThisBinding): TJSValue;
    function VisitNewTargetExpression: TJSValue;
    function CurrentSourceContext: TJSSourceContext;
    procedure RequireSuperHome;
    function SuperBase: IJSObject;
    function ReadSuperMember(const Reference: TJSMemberReference): TJSValue;
    procedure WriteSuperMember(const Reference: TJSMemberReference; const Value: TJSValue);
    function CallSuperMethod(const Node: TJSCallExpression; const MemberExpr: TJSMemberExpression): TJSValue;
    function VisitSuperCall(const Node: TJSCallExpression): TJSValue;
    function ConstructScript(const Func: IJSFunction; const Args: TArray<TJSValue>;
                             const NewTarget: IJSFunction): TJSValue;
    function ConstructBase(const Func: IJSFunction; const Args: TArray<TJSValue>;
                           const NewTarget: IJSFunction): TJSValue;
    function ConstructDerived(const Func: IJSFunction; const Args: TArray<TJSValue>;
                              const NewTarget: IJSFunction): TJSValue;
    function ConstructThroughParent(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                    const NewTarget: IJSFunction): TJSValue;
    function ConstructNative(const Func: IJSFunction; const Args: TArray<TJSValue>;
                             const NewTarget: IJSFunction): TJSValue;
    procedure AdoptNewTargetPrototype(const Instance: IJSObject; const NewTarget: IJSFunction);
    function ParentConstructorOf(const Func: IJSFunction): IJSFunction;
    function CallFromHost(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
    function CallNative(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
    procedure RejectClassConstructorCall(const Func: IJSFunction);
    function CallBoundTarget(const Target: IJSFunction; const Args: TArray<TJSValue>; const BoundThis: IJSObject): TJSValue;
    function ConstructBoundTarget(const Target: IJSFunction; const Args: TArray<TJSValue>;
                                  const NewTarget: IJSFunction): TJSValue;
    procedure RequireLiveProxy(const Constructor_: IJSFunction);
    function PrimitivePrototypeFor(const Value: TJSValue): IJSObject;
    function ArgumentsFromList(const ArgumentList: TJSValue): TArray<TJSValue>;
    function UnwrapBoundFunction(const Func: IJSFunction): IJSFunction;
    function CreateBoundFunction(const Target: IJSFunction; const BoundThis: IJSObject;
                                 const BoundArgs: TArray<TJSValue>): IJSFunction;

    procedure BeginExecution;
    procedure DrainJobs;
    procedure DiscardPendingJobs;
    procedure ReachStepCheckpoint;
    procedure OpenStepSlice;
    function IsCancelRequested: Boolean;
    function GetStepCount: Int64;
    function ErrorConstructorName(const Error: Exception): string;
    function CreateErrorValue(const Error: Exception): TJSValue;



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
    function FindSwitchStart(const Node: TJSSwitchStatement; const DiscriminantValue: TJSValue): Integer;
    function RunSwitchFrom(const Node: TJSSwitchStatement; const StartIndex: Integer): TJSValue;
    function VisitScopedBlock(const Node: TJSBlockStatement): TJSValue;
    function CreateFunctionObject(const Node: TJSFunctionDeclaration): IJSFunction;
    function VisitFunctionDeclaration(const Node: TJSFunctionDeclaration): TJSValue;
    function VisitLexicalForStatement(const Node: TJSForStatement; const OwnLabels: TArray<string>): TJSValue;
    function RunForLoop(const Node: TJSForStatement; const OwnLabels: TArray<string>;
                        const CopiesIterationScope: Boolean): TJSValue;
    procedure AdvanceForLoop(const Node: TJSForStatement; const CopiesIterationScope: Boolean);
    function EvaluateForInSubject(const Node: TJSForInStatement): TJSValue;
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
    procedure DefineLiteralData(const Target: IJSObject; const Name: TJSPropertyKey; const Prop: TJSObjectProperty);
    procedure DefineLiteralMethod(const Target: IJSObject; const Name: TJSPropertyKey; const Prop: TJSObjectProperty);
    procedure DefineLiteralAccessor(const Target: IJSObject; const Name: TJSPropertyKey; const Prop: TJSObjectProperty);
    procedure AssignLiteralPrototype(const Target: IJSObject; const Prop: TJSObjectProperty);
    function VisitAssigned(const Value: TJSExpression; const Target: TJSIdentifier): TJSValue;
    function IsAnonymousFunctionDefinition(const Node: TJSExpression): Boolean;
    function CreateOrdinaryFunction(const Node: TJSFunctionExpression): IJSFunction;
    function VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
    function VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
    function VisitDeleteExpression(const Node: TJSUnaryExpression): TJSValue;
    function DeleteMember(const Node: TJSUnaryExpression; const MemberExpr: TJSMemberExpression): TJSValue;
    function DeleteProxyMember(const Node: TJSUnaryExpression; const Proxy: IJSProxy;
                               const PropName: TJSPropertyKey): TJSValue;
    function IsUndeclaredIdentifier(const Node: TJSExpression): Boolean;
    function DeleteIdentifier(const Name: string): Boolean;
    procedure DeclareBinding(const Name: string; const Value: TJSValue);
    function VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
    function VisitBinaryChain(const Node: TJSBinaryExpression): TJSValue;
    function ApplyBinary(const Node: TJSBinaryExpression; const Left: TJSValue; const Right: TJSValue): TJSValue;
    function VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
    function VisitLogicalChain(const Node: TJSLogicalExpression): TJSValue;
    function ApplyLogical(const Node: TJSLogicalExpression; const Left: TJSValue): TJSValue;
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
    function EvaluateCall(const Node: TJSCallExpression; const Base: PJSValue): TJSValue;
    function OperandOrBase(const Operand: TJSExpression; const Base: PJSValue): TJSValue; inline;
    function VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
    function VisitValueChain(const Node: TJSExpression; const ChainLength: Integer): TJSValue;
    function ChainOperand(const Link: TJSExpression): TJSExpression;
    function IsChainLink(const Node: TJSExpression): Boolean;
    function CreateMemberReference(const Node: TJSMemberExpression; const Base: TJSValue;
                                   const IsSuper: Boolean): TJSMemberReference; inline;
    procedure RaiseStackExhausted;
    procedure RequireObjectCoercible(const Value: TJSValue; const PropName: string);
    procedure RequireCoercibleBase(const Reference: TJSMemberReference);
    function ResolveMemberReference(const Node: TJSMemberExpression): TJSMemberReference;
    function DescribeReferenceKey(const Reference: TJSMemberReference): string;
    function ToPropertyKey(const Key: TJSValue): TJSPropertyKey;
    function GetReferenceValue(const Reference: TJSMemberReference): TJSValue;
    procedure PutReferenceValue(const Reference: TJSMemberReference; const Value: TJSValue);
    function ReadMember(const Base: TJSValue; const PropName: TJSPropertyKey): TJSValue;
    function ReadPrimitiveMember(const Base: TJSValue; const PrimitivePrototype: IJSObject;
                                 const PropName: TJSPropertyKey): TJSValue;
    procedure RaiseCannotAssign(const PropName: TJSPropertyKey);
    procedure RaiseCannotDelete(const Node: TJSUnaryExpression; const PropName: TJSPropertyKey);
    procedure RequireBoundThis;
    function CollectChain(const First: TJSExpression; const ChainLength: Integer): TArray<TJSExpression>;
    function NextChainLink(const Link: TJSExpression): TJSExpression;
    function EvaluateChainLinks(const Links: TArray<TJSExpression>; const FirstLink: Integer;
                                const Start: TJSValue): TJSValue;
    function ConstructBound(const Bound: TJSBoundFunction; const Args: TArray<TJSValue>; const Func: IJSFunction;
                            const NewTarget: IJSFunction): TJSValue;
    function ConstructNativeFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                     const NewTarget: IJSFunction): TJSValue;
    procedure EnterArrowContext(const Func: IJSFunction);
    procedure ReleaseFunctionContents(const Func: IJSFunction);
    class function IsLongChain(const ChainLength: Integer): Boolean; static; inline;
    procedure WriteMember(const Base: TJSValue; const PropName: TJSPropertyKey; const Value: TJSValue);
    procedure WriteArrayMember(const Target: IJSArray; const PropName: TJSPropertyKey; const Value: TJSValue;
                               out IsHandled: Boolean);
    function VisitNewExpression(const Node: TJSNewExpression): TJSValue;
    function VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
    function VisitThisExpression(const Node: TJSThisExpression): TJSValue;
    function VisitTemplateLiteral(const Node: TJSTemplateLiteral): TJSValue;
    function VisitTemplateObject(const Node: TJSTemplateObject): TJSValue;
    function CreateTemplateObject(const Node: TJSTemplateObject): IJSArray;
    function CurrentThisObject: IJSObject;
    function CreateArrowFunction(const Node: TJSFunctionExpression): IJSFunction;

    function ToText(const Value: TJSValue): string;
    function VisitText(const Node: TJSASTNode): string;
    procedure AssignArrayLength(const Target: IJSArray; const Value: TJSValue);
    procedure DeleteArrayElement(const Target: IJSObject; const PropName: TJSPropertyKey);
    function CreateCallbackExecutor(const MethodName: string; const Args: TArray<TJSValue>): TJSCallbackExecutor;
    function AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    function CallsReplacedJoin(const Arr: IJSArray; const MethodName: string): Boolean;
    function ExecuteArrayMethodCore(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteArrayIterationMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                                             const BeforeElements: TProc): TJSValue;
    function ExecuteSpeciesIterationMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function ExecuteGenericArrayMethodCore(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
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
    procedure RunPendingJobs;
    function ExceptionToValue(const Error: Exception): TJSValue;
    function CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue; override;
    function EnterHeap: TJSHeap;
    procedure LeaveHeap(const Previous: TJSHeap);
    procedure Cancel;
    procedure RegisterFunction(const Func: IJSFunction);
    procedure RegisterIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string; const Method: IJSObject);
    function IsIntrinsicMethod(const Group: TJSIntrinsicGroup; const Name: string; const Callee: TJSValue): Boolean;
    function CallMutator(const Cache: TJSMutatorCache; const StoresNewElements: Boolean; const Arr: IJSArray;
                         const Name: string; const Args: TArray<TJSValue>): TJSValue;
    function TryCallRegisteredMethod(const Arr: IJSArray; const Name: string; const Args: TArray<TJSValue>;
                                     out Value: TJSValue): Boolean;
    function TryCallUntouchedArrayMethod(const Target: TJSValue; const Name: string; const Args: TArray<TJSValue>;
                                         out Value: TJSValue): Boolean;
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
    function ToStringCoerced(const Value: TJSValue): string;
    function ThisObjectFor(const Func: IJSFunction; const ThisValue: TJSValue): IJSObject;
    function InvokeMethod(const Target: TJSValue; const MethodName: string): TJSValue;

    function ActiveBinding: IJSThisBinding;
    function ActiveCallee: IJSFunction;
    function ActiveNewTarget: IJSFunction;
    procedure AssignLoopVariable(const Node: TJSForInStatement; const OuterScope: IJSScope; const Value: TJSValue);
    procedure BindFunctionParameters(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                     const Body: TJSBlockStatement);
    procedure BindTarget(const Target: TJSExpression; const Value: TJSValue; const Mode: TJSBindingMode);
    function CollectEnumerableKeys(const Subject: IJSObject): TArray<string>;
    procedure CopyIterationScope;
    procedure DeclareCatchBinding(const Handler: TJSCatchClause; const Thrown: TJSValue);
    procedure EnsureCallDepthAvailable;
    procedure EnsureWithAllowed(const Node: TJSWithStatement);
    procedure EnterLexicalScope(const ScopeInfo: TJSScopeInfo);
    procedure EnterLoopScope(const MayCaptureScope: Boolean; const Declaration: TJSVariableDeclaration);
    procedure EnterWithScope(const Target: TJSValue);
    function ExecuteStatement(const Node: TJSStatement): TJSValue;
    function FindIteratorMethod(const Value: TJSValue; out IteratorFunction: IJSFunction): Boolean;
    function IsLexicalDeclaration(const Node: TJSASTNode): Boolean;
    procedure PushScope;
    function ResolveLoopJump(const Signal: TJSJumpSignal; const OwnLabels: TArray<string>): TJSLoopJump;
    procedure SetContext(const Callee: IJSFunction; const NewTarget: IJSFunction; const Binding: IJSThisBinding);
    function StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    function StrictPrimitiveThis(const ThisObj: IJSObject; const IsStrict: Boolean): TJSStrictThis;
    function TakeLoopLabels: TArray<string>;
    function ToScopeObject(const Value: TJSValue): IJSObject;
    function TryOpenIterationSource(const Value: TJSValue; out Source: TJSIterationSource): Boolean;
    function Visit(const Node: TJSASTNode): TJSValue;
    function VisitNamed(const Node: TJSExpression; const Name: string): TJSValue;

    property BypassNode: TJSASTNode read FBypassNode write FBypassNode;
    property CallDepth: Integer read FCallDepth write FCallDepth;
    property Context: TJSCallContext read FContext write FContext;
    property CurrentScope: IJSScope read FCurrentScope write FCurrentScope;
    property Generator: TJSGeneratorObject read FGenerator write FGenerator;
    property Generators: TJSObjectRegistry read FGenerators write FGenerators;
    property LoopLabels: TArray<string> read FLoopLabels write FLoopLabels;
    property StrictMode: Boolean read FStrictMode write FStrictMode;
    property ThisPrimitive: TJSStrictThis read FThisPrimitive write FThisPrimitive;
    property ThisValue: IJSObject read FThisValue write FThisValue;
    property VarScope: IJSScope read FVarScope write FVarScope;
    property GeneratorEngine: TJSResumableExecution read FGeneratorEngine;
    procedure AssignParameters(const Func: TJSFunction; const Params: TObjectList<TJSIdentifier>;
                               const Info: TJSParameterInfo);
    function CreateMethodFunction(const Node: TJSFunctionExpression; const Name: string): IJSFunction;
    function EvaluatePropertyKey(const Computed: Boolean; const KeyNode: TJSASTNode): TJSEvaluatedKey;
    class function FunctionNameForKey(const Key: TJSPropertyKey): string; static;
    procedure RegisterScope(const Scope: IJSScope);

    property ClassBuilder: TJSClassEvaluation read FClassBuilder;
    property GeneratorFunctionPrototype: IJSObject read FGeneratorFunctionPrototype write FGeneratorFunctionPrototype;
    property GeneratorPrototype: IJSObject read FGeneratorPrototype write FGeneratorPrototype;
    property AsyncFunctionPrototype: IJSObject read FAsyncFunctionPrototype write FAsyncFunctionPrototype;
    property AsyncHost: TJSAsyncHost read FAsyncHost write FAsyncHost;
    property GCRootProvider: TJSGCRootProvider read FGCRootProvider write FGCRootProvider;
    property JobRunner: TProc read FJobRunner write FJobRunner;
    property JobDiscarder: TProc read FJobDiscarder write FJobDiscarder;
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
    procedure ConsumeStep; inline;

    property Limits: TJSLimits read FLimits;
    property StepBudget: Int64 read FStepBudget write FStepBudget;
    property StepCount: Int64 read GetStepCount;
    property MaxCallDepth: Integer read FLimits.MaxCallDepth write FLimits.MaxCallDepth;
    property MaxStringLength: Integer read FLimits.MaxStringLength write FLimits.MaxStringLength;
    property MaxArrayLength: Integer read FLimits.MaxArrayLength write FLimits.MaxArrayLength;
  end;

implementation

uses
  JS4D.GarbageMarker,
  JS4D.PropertyNames,
  JS4D.CallFrames,
  JS4D.GeneratorEngine,
  JS4D.ClassBuilder;

const
  ITERATIVE_CHAIN_LENGTH = 64;
  ARRAY_TO_STRING_METHOD = 'toString';
  UNDEFINED_TYPE = 'undefined';
  SYMBOL_TYPE = 'symbol';
  OBJECT_TYPE = 'object';
  BOOLEAN_TYPE = 'boolean';
  NUMBER_TYPE = 'number';
  STRING_TYPE = 'string';
  FUNCTION_TYPE = 'function';
  LENGTH_PROPERTY = 'length';
  BOUND_NAME_PREFIX = 'bound ';
  SYMBOL_FUNCTION_NAME = '[%s]';
  METHOD_PUSH = 'push';
  METHOD_POP = 'pop';
  METHOD_FILTER = 'filter';
  METHOD_CONCAT = 'concat';
  METHOD_FLAT = 'flat';
  METHOD_FLAT_MAP = 'flatMap';
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

  CANNOT_DELETE_PROPERTY = 'Cannot delete property ''%s'' of object';
  WITH_IN_STRICT_MODE = 'with statement is not allowed in strict mode';

  CONSTRUCTOR_ARRAY = 'Array';
  CONSTRUCTOR_FUNCTION = 'Function';
  CONSTRUCTOR_REGEXP = 'RegExp';
  CONSTRUCTOR_DATE = 'Date';

  STEP_CHECK_INTERVAL = 1024;
  OPERATORS_OF_NUMBERS = [TJSBinaryOperator.Add,
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
                          TJSBinaryOperator.UnsignedRightShift];

  EMPTY_COMPLETION_NODES = [TJSASTNodeType.VariableDeclaration,
                            TJSASTNodeType.FunctionDeclaration,
                            TJSASTNodeType.EmptyStatement];
  REDECLARED_IDENTIFIER = 'Identifier ''%s'' has already been declared';
  CANNOT_DECLARE_GLOBAL_FUNCTION = 'Cannot declare global function %s';
  CANNOT_DECLARE_GLOBAL_VARIABLE = 'Cannot declare global variable %s';
  ASSIGN_TO_READ_ONLY_GLOBAL = 'Cannot assign to read only global variable %s';
  NOT_ITERABLE = 'Spread syntax requires an iterable value';
  INSTANCEOF_NOT_OBJECT = 'Right-hand side of instanceof is not an object';
  INSTANCEOF_NOT_CALLABLE = 'Right-hand side of instanceof is not callable';
  HAS_INSTANCE_NOT_CALLABLE = 'Symbol.hasInstance is not a function';
  INSTANCEOF_PROTOTYPE_NOT_OBJECT = 'Function has non-object prototype in instanceof check';
  IN_NOT_OBJECT = 'Cannot use the in operator to search for a property in a non-object';
  PATTERN_NOT_ITERABLE = 'Value is not iterable and cannot be destructured';
  ITERATOR_METHOD_NOT_CALLABLE = 'The Symbol.iterator property is not a function';
  CANNOT_DESTRUCTURE = 'Cannot destructure a value that is %s';
  CLASS_CONSTRUCTOR_CALL = 'Class constructor %s cannot be invoked without ''new''';
  THIS_BEFORE_SUPER = 'Must call super constructor in derived class before accessing ''this'' or returning from ' +
                      'derived constructor';
  SUPER_CALLED_TWICE = 'Super constructor may only be called once';
  SUPER_NOT_CONSTRUCTOR = 'Super constructor is not a constructor';
  SUPER_OUTSIDE_METHOD = '''super'' keyword unexpected here';
  SUPER_BASE_NOT_OBJECT = 'Cannot read properties of the super base, which is null';
  DELETE_SUPER_REFERENCE = 'Unsupported reference to ''super''';
  DERIVED_RETURN_VALUE = 'Derived constructors may only return object or undefined';

{ TJSInterpreter }

constructor TJSInterpreter.Create;
begin
  inherited Create;
  FHeap := TJSHeap.Create;
  FFunctionRegistry := TList<IJSFunction>.Create;
  FScopeRegistry := TList<IJSScope>.Create;
  FGenerators := TJSObjectRegistry.Create;
  FGeneratorEngine := TJSGeneratorEngine.Create(Self);
  FClassBuilder := TJSClassBuilder.Create(Self);
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
  FStackFloor := TJSStackGuard.CurrentFloor;
  const PreviousHeap = EnterHeap;
  try
    FGlobalObject := TJSObject.Create;
    FGlobalBindings := TJSGlobalScope.Create(FGlobalObject);
  finally
    LeaveHeap(PreviousHeap);
  end;

  FGlobalScope := FGlobalBindings;
  FScopeRegistry.Add(FGlobalScope);
  FCurrentScope := FGlobalScope;
  FVarScope := FGlobalScope;
  FThisValue := nil;
end;

destructor TJSInterpreter.Destroy;
begin
  FGenerator := nil;
  FGenerators.ReleaseAll;

  if Assigned(FThrowTypeError) then
    FThrowTypeError.Prototype := nil;

  for var Func in FFunctionRegistry do
  begin
    Func.Prototype := nil;
    ReleaseFunctionContents(Func);
  end;
  FFunctionRegistry.Free;

  for var Scope in FScopeRegistry do
  begin
    Scope.Clear;
  end;
  FScopeRegistry.Free;
  FGenerators.Free;
  FGeneratorEngine.Free;
  FClassBuilder.Free;
  FFunctionPrograms.Free;
  FBoundFunctions.Free;
  FGeneratorFunctionPrototype := nil;
  FGeneratorPrototype := nil;
  FAsyncFunctionPrototype := nil;
  FAsyncHost := nil;
  FEvalVariableScope := nil;
  FEvalFunction := nil;
  FThrowTypeError := nil;
  FProgramParser := nil;
  FGCRootProvider := nil;
  FJobRunner := nil;
  FJobDiscarder := nil;

  FCurrentScope := nil;
  FVarScope := nil;
  FEvalCallerScope := nil;
  FGlobalBindings := nil;
  FGlobalScope := nil;
  FGlobalObject := nil;
  FThisValue := nil;
  FObjectPrototype := nil;
  FArrayPrototype := nil;
  FPushCache := Default(TJSMutatorCache);
  FPopCache := Default(TJSMutatorCache);
  FFunctionPrototype := nil;
  FRegExpPrototype := nil;
  FSymbolPrototype := nil;
  FStringPrototype := nil;
  FNumberPrototype := nil;
  FBooleanPrototype := nil;
  FParameterInitScope := nil;
  FIteration := Default(TJSIterationIntrinsics);
  for var Group := Low(TJSIntrinsicGroup) to High(TJSIntrinsicGroup) do
  begin
    FIntrinsicMethods[Group].Free;
  end;
  FOrdinaryHasInstance := nil;
  FArrayConstructor := nil;
  FArraySpeciesGetter := nil;
  FHeap.ReleaseAll;
  FHeap.Free;
  inherited;
end;

procedure TJSInterpreter.SetFunctionPrototype(const Value: IJSObject);
begin
  FFunctionPrototype := Value;

  for var Func in FFunctionRegistry do
  begin
    const IsPrototypeItself = TJSObjectOperations.IsSameObject(Func, Value);
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
  FFunctionPrograms.AddOrSetValue(TJSObjectOperations.IdentityOf(Func), FCurrentProgram);
end;

procedure TJSInterpreter.RegisterScope(const Scope: IJSScope);
begin
  FScopeRegistry.Add(Scope);
end;

procedure TJSInterpreter.AttachPrototype(const Func: IJSFunction);
begin
  const PrototypeObject: IJSObject = TJSObject.Create;
  PrototypeObject.Prototype := FObjectPrototype;

  const FunctionValue = TJSValue.CreateObject(Func as IJSObject);
  var ConstructorDescriptor := TJSPropertyDescriptor.Create(FunctionValue);
  ConstructorDescriptor.Enumerable := False;
  PrototypeObject.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);

  FGeneratorEngine.DefinePrototypeProperty(Func, PrototypeObject, True);
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
  begin
    Result := EvaluateSpreadArguments(Nodes);
    Exit;
  end;

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
  const ArrayLiteral: IJSArray = TJSArray.Create;
  ArrayLiteral.Prototype := FArrayPrototype;

  const Spread = TList<TJSValue>.Create;
  try
    for var Element in Node.Elements do
    begin
      if not Assigned(Element) then
      begin
        ArrayLiteral.Push(TJSValue.CreateUndefined);
        ArrayLiteral.DeleteElement(ArrayLiteral.Length - 1);
      end
      else if Element is TJSSpreadElement then
      begin
        Spread.Clear;
        AppendSpreadValues(Visit(TJSSpreadElement(Element).Argument), Spread);
        FLimits.EnsureArrayLength(ArrayLiteral.Length + Spread.Count);

        for var Value in Spread do
        begin
          ArrayLiteral.Push(Value);
        end;
      end
      else
      begin
        ArrayLiteral.Push(Visit(Element));
      end;
    end;
  finally
    Spread.Free;
  end;

  Result := TJSValue.CreateObject(ArrayLiteral);
end;

procedure TJSInterpreter.DetachProperties(const Func: IJSFunction);
begin
  for var PropName in TJSObjectOperations.OwnKeys(Func) do
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
    if TJSObjectOperations.IsSameObject(Current, TargetPrototype) then
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
  begin
    Result := ThisValue.ToObject;
    Exit;
  end;

  if Func.ReceivesRawThis then
  begin
    if ThisValue.IsUndefined then
      Exit(nil);

    Result := TJSStrictThis.Create(ThisValue);
    Exit;
  end;

  const SeesObjectThis = Func.IsNative or (not Func.IsStrict);
  if SeesObjectThis then
  begin
    const IsPrimitive = not ThisValue.IsNullOrUndefined;
    if IsPrimitive then
    begin
      Result := WrapPrimitive(ThisValue);
      Exit;
    end;

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
  FStackFloor := TJSStackGuard.CurrentFloor;
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

  const OuterState = FGeneratorEngine.CaptureExecutionState;

  Inc(FExecutionDepth);
  const PreviousHeap = EnterHeap;
  FCurrentScope := FGlobalScope;
  FVarScope := FGlobalScope;
  FThisValue := nil;
  FThisPrimitive := nil;
  FContext := Default(TJSCallContext);
  try
    FCurrentProgram := Program_;
    try
      Result := Visit(Program_);
    except
      on EJSExecutionInterrupted do
      begin
        DiscardPendingJobs;
        raise;
      end;
      on Exception do
      begin
        DrainJobs;
        raise;
      end;
    end;

    DrainJobs;
  finally
    FGeneratorEngine.RestoreExecutionState(OuterState);
    LeaveHeap(PreviousHeap);
    Dec(FExecutionDepth);
  end;
end;

procedure TJSInterpreter.DrainJobs;
begin
  const IsOutermostScript = (FExecutionDepth = 1);
  if (not IsOutermostScript) or (not Assigned(FJobRunner)) then
    Exit;

  try
    FJobRunner;
  except
    on EJSExecutionInterrupted do
    begin
      DiscardPendingJobs;
      raise;
    end;
  end;
end;

procedure TJSInterpreter.DiscardPendingJobs;
begin
  if Assigned(FJobDiscarder) then
    FJobDiscarder;
end;

procedure TJSInterpreter.RunPendingJobs;
begin
  const IsScriptRunning = (FExecutionDepth > 0);
  if IsScriptRunning or (not Assigned(FJobRunner)) then
    Exit;

  BeginExecution;
  Inc(FExecutionDepth);
  const PreviousHeap = EnterHeap;
  try
    DrainJobs;
  finally
    LeaveHeap(PreviousHeap);
    Dec(FExecutionDepth);
  end;
end;

function TJSInterpreter.ExceptionToValue(const Error: Exception): TJSValue;
begin
  if Error is TJSThrowSignal then
  begin
    Result := TJSThrowSignal(Error).Value;
    Exit;
  end;

  Result := CreateErrorValue(Error);
end;

function TJSInterpreter.ExecuteStatement(const Node: TJSStatement): TJSValue;
begin
  ConsumeStep;
  Result := Visit(Node);
end;

function TJSInterpreter.Visit(const Node: TJSASTNode): TJSValue;
begin
  const ParameterStackAddress = NativeUInt(@Node);
  const IsStackExhausted = (ParameterStackAddress < FStackFloor);
  if IsStackExhausted then
    RaiseStackExhausted;

  if Node = nil then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  var Kind := Node.DispatchType;

  repeat
    case Kind of
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
      TJSASTNodeType.ClassExpression:
        Result := FClassBuilder.VisitClassExpression(TJSClassExpression(Node), EMPTY_NAME);
      TJSASTNodeType.NewTargetExpression:
        Result := VisitNewTargetExpression;
      TJSASTNodeType.TemplateLiteral:
        Result := VisitTemplateLiteral(TJSTemplateLiteral(Node));
      TJSASTNodeType.TemplateObject:
        Result := VisitTemplateObject(TJSTemplateObject(Node));
      TJSASTNodeType.YieldExpression:
        Result := FGeneratorEngine.VisitYield(TJSYieldExpression(Node));
      TJSASTNodeType.AwaitExpression:
        Result := FGeneratorEngine.VisitAwait(TJSAwaitExpression(Node));
      TJSASTNodeType.Remembered:
        begin
          const IsBypassed = (Node = FBypassNode);
          if IsBypassed then
          begin
            FBypassNode := nil;
            Kind := Node.NodeType;
            Continue;
          end;

          Result := FGeneratorEngine.VisitRemembered(Node);
        end;
      else
        Result := TJSValue.CreateUndefined;
    end;

    Break;
  until False;
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

  var Context := Default(TJSSourceContext);
  if IsDirect then
    Context := CurrentSourceContext;

  Result := EvaluateProgram(FProgramParser(Source, IsStrictContext, Context), IsDirect);
end;

function TJSInterpreter.CurrentSourceContext: TJSSourceContext;
begin
  const Callee = ActiveCallee;
  const HasCallee = Assigned(Callee);

  Result.AllowNewTarget := (FCallDepth > 0);
  Result.AllowSuperProperty := HasCallee and Assigned(Callee.HomeObject);
  Result.AllowSuperCall := HasCallee and (Callee.Kind = TJSFunctionKind.DerivedConstructor);
end;

function TJSInterpreter.CreateFunctionFromSource(const Source: string): TJSValue;
begin
  const EvalContext = Default(TJSSourceContext);
  const Program_ = FProgramParser(Source, False, EvalContext);

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

  const OldState = FGeneratorEngine.CaptureExecutionState;
  const OldProgram = FCurrentProgram;
  const OldEvalVariableScope = FEvalVariableScope;
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
    FContext := Default(TJSCallContext);
  end;
  try
    Result := RunProgramBody(Program_);
  finally
    FGeneratorEngine.RestoreExecutionState(OldState);
    FCurrentProgram := OldProgram;
    FEvalVariableScope := OldEvalVariableScope;
    FEvalCallerScope := OldEvalCallerScope;
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

  const IsGlobalScope = (FVarScope = FGlobalScope);
  const IsDeclared = (IsGlobalScope and FGlobalObject.HasOwnProperty(Name)) or
                     ((not IsGlobalScope) and (FVarScope.Resolve(Name) = FVarScope));
  if not IsDeclared then
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

procedure TJSInterpreter.EnterLoopScope(const MayCaptureScope: Boolean; const Declaration: TJSVariableDeclaration);
begin
  FCurrentScope := TJSScope.Create(FCurrentScope);
  if MayCaptureScope then
    RegisterScope(FCurrentScope);

  DeclareLexicalNames(Declaration);
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

  for var Declarator in Node.Declarations do
  begin
    FGeneratorEngine.InitializeDeclarator(Node, Declarator);
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

  if Node.IsGenerator then
  begin
    FGeneratorEngine.ConvertToGeneratorFunction(Func);
    FGeneratorEngine.AttachGeneratorPrototype(Func);
  end
  else if Node.IsAsync then
  begin
    FGeneratorEngine.ConvertToAsyncFunction(Func);
  end
  else
  begin
    AttachPrototype(Func);
  end;

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
    raise TJSErrorFactory.NotCoercibleToObject;

  if Value.IsObject then
  begin
    Result := Value.ToObject;
    Exit;
  end;

  Result := WrapPrimitive(Value);
end;

function TJSInterpreter.VisitWithStatement(const Node: TJSWithStatement): TJSValue;
begin
  EnsureWithAllowed(Node);

  const TargetValue = Visit(Node.Target);
  const OuterScope = FCurrentScope;

  EnterWithScope(TargetValue);
  try
    Result := ExecuteStatement(Node.Body);
  finally
    FCurrentScope := OuterScope;
  end;
end;

procedure TJSInterpreter.EnsureWithAllowed(const Node: TJSWithStatement);
begin
  if FStrictMode then
    raise TJSErrorFactory.SyntaxError(WITH_IN_STRICT_MODE, Node.Line, Node.Column);
end;

procedure TJSInterpreter.EnterWithScope(const Target: TJSValue);
begin
  const ScopeObject = ToScopeObject(Target);

  FCurrentScope := TJSObjectScope.Create(FCurrentScope, ScopeObject, @FStrictMode);
  RegisterScope(FCurrentScope);
end;

function TJSInterpreter.VisitCalleeIdentifier(const Identifier: TJSIdentifier; out ThisObj: IJSObject): TJSValue;
begin
  ThisObj := nil;

  const IsGlobalCode = (FCurrentScope = FGlobalScope);
  if IsGlobalCode then
  begin
    Result := VisitIdentifier(Identifier);
    Exit;
  end;

  const DeclaringScope = FCurrentScope.Resolve(Identifier.Name);
  if not Assigned(DeclaringScope) then
    raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);

  var ObjectScope: IJSObjectScope;
  if Supports(DeclaringScope, IJSObjectScope, ObjectScope) then
  begin
    ThisObj := ObjectScope.BindingObject;
    Result := ObjectScope.GetBindingValue(Identifier.Name, FStrictMode);
    Exit;
  end;

  if not DeclaringScope.TryGetVariable(Identifier.Name, Result) then
    raise TJSErrorFactory.UndefinedVariable(Identifier.Name, Identifier.Line, Identifier.Column);
end;

function TJSInterpreter.VisitLabeledStatement(const Node: TJSLabeledStatement): TJSValue;
begin
  const BodyIsLoop = (Node.Body.NodeType in LABELED_LOOP_TYPES);

  if BodyIsLoop then
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
      on Signal: TJSJumpSignal do
      begin
        const Jump = ResolveLoopJump(Signal, OwnLabels);
        const MustPropagate = (Jump = TJSLoopJump.Propagate);
        if MustPropagate then
          raise;

        const MustStop = (Jump = TJSLoopJump.Stop);
        if MustStop then
          Break;
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
      on Signal: TJSJumpSignal do
      begin
        const Jump = ResolveLoopJump(Signal, OwnLabels);
        const MustPropagate = (Jump = TJSLoopJump.Propagate);
        if MustPropagate then
          raise;

        const MustStop = (Jump = TJSLoopJump.Stop);
        if MustStop then
          Break;
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

  try
    EnterLoopScope(Node.MayCaptureScope, Declaration);
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
      on Signal: TJSJumpSignal do
      begin
        const Jump = ResolveLoopJump(Signal, OwnLabels);
        const MustPropagate = (Jump = TJSLoopJump.Propagate);
        if MustPropagate then
          raise;

        const MustStop = (Jump = TJSLoopJump.Stop);
        if MustStop then
          Break;
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

  try
    EnterLoopScope(Node.MayCaptureScope, TJSVariableDeclaration(Node.Left));
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
    on Signal: TJSJumpSignal do
    begin
      const Jump = ResolveLoopJump(Signal, OwnLabels);
      const MustPropagate = (Jump = TJSLoopJump.Propagate);
      if MustPropagate then
        raise;

      KeepLooping := (Jump <> TJSLoopJump.Stop);
    end;
  end;
end;

function TJSInterpreter.ResolveLoopJump(const Signal: TJSJumpSignal; const OwnLabels: TArray<string>): TJSLoopJump;
begin
  const IsBreak = (Signal is TJSBreakSignal);
  if IsBreak then
  begin
    if Signal.IsLabelled then
      Result := TJSLoopJump.Propagate
    else
      Result := TJSLoopJump.Stop;

    Exit;
  end;

  if Signal.AppliesTo(OwnLabels) then
    Result := TJSLoopJump.Proceed
  else
    Result := TJSLoopJump.Propagate;
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

    const Subject = ToScopeObject(RightValue);

    var Proxy: IJSProxy;
    const IsProxy = TJSObjectOperations.AsProxy(Subject, Proxy);

    for var PropName in CollectEnumerableKeys(Subject) do
    begin
      const IsDeleted = (not IsProxy) and (not Subject.HasProperty(PropName));
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
    on Error: Exception do
    begin
      Source.CloseForException(Error);
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
  const StartIndex = FindSwitchStart(Node, DiscriminantValue);
  const HasStart = (StartIndex <> NO_CASE);
  if not HasStart then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := RunSwitchFrom(Node, StartIndex);
end;

function TJSInterpreter.FindSwitchStart(const Node: TJSSwitchStatement; const DiscriminantValue: TJSValue): Integer;
begin
  var DefaultCaseIndex := NO_CASE;

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
      Result := CaseIndex;
      Exit;
    end;
  end;

  Result := DefaultCaseIndex;
end;

function TJSInterpreter.RunSwitchFrom(const Node: TJSSwitchStatement; const StartIndex: Integer): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    for var CaseIndex := StartIndex to Node.Cases.Count - 1 do
    begin
      for var Statement in Node.Cases[CaseIndex].Consequent do
      begin
        Result := ExecuteStatement(Statement);
      end;
    end;
  except
    on Signal: TJSBreakSignal do
    begin
      if Signal.IsLabelled then
        raise;
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
      on E: Exception do
      begin
        if Assigned(Node.Handler) then
          Result := VisitCatchClause(Node.Handler, ExceptionToValue(E))
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
    Result := TJSErrorType.TypeError.Name
  else if Error is EJSReferenceError then
    Result := TJSErrorType.ReferenceError.Name
  else if Error is EJSRangeError then
    Result := TJSErrorType.RangeError.Name
  else if Error is EJSSyntaxError then
    Result := TJSErrorType.SyntaxError.Name
  else if Error is EJSURIError then
    Result := TJSErrorType.URIError.Name
  else if Error is EJSEvalError then
    Result := TJSErrorType.EvalError.Name;
end;

function TJSInterpreter.CreateErrorValue(const Error: Exception): TJSValue;
begin
  const ErrorName = ErrorConstructorName(Error);
  const IsKnownError = (not ErrorName.IsEmpty) and FGlobalScope.HasVariable(ErrorName);
  if not IsKnownError then
  begin
    Result := TJSValue.CreateString(Error.Message);
    Exit;
  end;

  var Func: IJSFunction;
  const ConstructorValue = FGlobalScope.GetVariable(ErrorName);
  const IsCallable = ConstructorValue.IsFunction and Supports(ConstructorValue.ToObject, IJSFunction, Func);
  if not IsCallable then
  begin
    Result := TJSValue.CreateString(Error.Message);
    Exit;
  end;

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
    DeclareCatchBinding(Handler, Thrown);

    Result := Visit(Handler.Body);
  finally
    PopScope;
  end;
end;

procedure TJSInterpreter.DeclareCatchBinding(const Handler: TJSCatchClause; const Thrown: TJSValue);
begin
  if not Assigned(Handler.Pattern) then
  begin
    FCurrentScope.DeclareVariable(Handler.Param.Name, Thrown);
    Exit;
  end;

  for var Name in TJSPatternNames.NamesOf(Handler.Pattern) do
  begin
    FCurrentScope.DeclareLexical(Name, False);
  end;

  BindTarget(Handler.Pattern, Thrown, TJSBindingMode.Lexical);
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
  begin
    Result := GlobalSlot.Value;
    Exit;
  end;

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
        const RegExpObject: IJSRegExp = TJSRegExp.Create(Node.RegExpPattern, Node.RegExpFlags);
        RegExpObject.Prototype := FRegExpPrototype;
        Result := TJSValue.CreateObject(RegExpObject);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
begin
  if Node.HasSpread then
  begin
    Result := VisitArrayWithSpread(Node);
    Exit;
  end;

  FLimits.EnsureArrayLength(Node.Elements.Count);

  const ArrayLiteral: IJSArray = TJSArray.Create;
  ArrayLiteral.Prototype := FArrayPrototype;

  for var Element in Node.Elements do
  begin
    if Assigned(Element) then
    begin
      ArrayLiteral.Push(Visit(Element));
    end
    else
    begin
      ArrayLiteral.Push(TJSValue.CreateUndefined);
      ArrayLiteral.DeleteElement(ArrayLiteral.Length - 1);
    end;
  end;

  Result := TJSValue.CreateObject(ArrayLiteral);
end;

function TJSInterpreter.VisitObjectExpression(const Node: TJSObjectExpression): TJSValue;
begin
  const ObjectLiteral: IJSObject = TJSObject.Create;
  ObjectLiteral.Prototype := FObjectPrototype;

  for var Prop in Node.Properties do
  begin
    DefineLiteralProperty(ObjectLiteral, Prop);
  end;

  Result := TJSValue.CreateObject(ObjectLiteral);
end;

procedure TJSInterpreter.DefineLiteralProperty(const Target: IJSObject; const Prop: TJSObjectProperty);
begin
  const IsSpread = (Prop.Kind = TJSPropertyKind.Spread);
  if IsSpread then
  begin
    const SpreadSource = Visit(Prop.Value);
    CopyDataProperties(Target, SpreadSource, nil);
    Exit;
  end;

  const Evaluated = EvaluatePropertyKey(Prop.Computed, Prop.Key);

  case Prop.Kind of
    TJSPropertyKind.Getter,
    TJSPropertyKind.Setter : DefineLiteralAccessor(Target, Evaluated.Key, Prop);
    TJSPropertyKind.Method : DefineLiteralMethod(Target, Evaluated.Key, Prop);
  else
    if Prop.SetsPrototype then
      AssignLiteralPrototype(Target, Prop)
    else
      DefineLiteralData(Target, Evaluated.Key, Prop);
  end;
end;

function TJSInterpreter.EvaluatePropertyKey(const Computed: Boolean; const KeyNode: TJSASTNode): TJSEvaluatedKey;
begin
  Result.LiveSymbol := TJSValue.CreateUndefined;

  if Computed then
  begin
    Result.LiveSymbol := Visit(KeyNode);
    Result.Key := ToPropertyKey(Result.LiveSymbol);
  end
  else if KeyNode is TJSIdentifier then
  begin
    Result.Key := TJSIdentifier(KeyNode).Name;
  end
  else
  begin
    Result.Key := VisitText(KeyNode);
  end;
end;

class function TJSInterpreter.FunctionNameForKey(const Key: TJSPropertyKey): string;
begin
  Result := Key.Text;

  if not Key.IsSymbol then
    Exit;

  const Found = TJSSymbolRegistry.Find(Key.SymbolId);
  const IsLiveSymbol = Found is TJSSymbolImpl;
  const HasDescription = IsLiveSymbol and TJSSymbolImpl(Found).HasDescription;
  if HasDescription then
    Result := Format(SYMBOL_FUNCTION_NAME, [TJSSymbolImpl(Found).Description])
  else
    Result := '';
end;

procedure TJSInterpreter.DefineLiteralData(const Target: IJSObject; const Name: TJSPropertyKey;
                                           const Prop: TJSObjectProperty);
begin
  const Value = VisitNamed(Prop.Value, FunctionNameForKey(Name));
  Target.DefineProperty(Name, TJSPropertyDescriptor.Create(Value));
end;

procedure TJSInterpreter.DefineLiteralMethod(const Target: IJSObject; const Name: TJSPropertyKey;
                                             const Prop: TJSObjectProperty);
begin
  const Method = CreateMethodFunction(TJSFunctionExpression(Prop.Value), FunctionNameForKey(Name));
  FClassBuilder.BindHomeObject(Method, Target);
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
  const IsAnonymousClass = (Node.NodeType = TJSASTNodeType.ClassExpression) and
                           (not Assigned(TJSClassExpression(Node).Id));
  if IsAnonymousClass then
  begin
    Result := FClassBuilder.VisitClassExpression(TJSClassExpression(Node), Name);
    Exit;
  end;

  Result := Visit(Node);

  if IsAnonymousFunctionDefinition(Node) then
  begin
    const Func = Result.ToObject as IJSFunction;
    Func.Name := Name;
  end;
end;

procedure TJSInterpreter.DefineLiteralAccessor(const Target: IJSObject; const Name: TJSPropertyKey;
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
  FClassBuilder.BindHomeObject(AccessorFunction, Target);
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
  if Node.IsAsync then
    FGeneratorEngine.ConvertToAsyncFunction(Func);

  Func.LexicalThis := CurrentThisObject;
  Func.Frame := CaptureFrame;

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
  if Node.IsGenerator then
    FGeneratorEngine.AttachGeneratorPrototype(Func)
  else if not Node.IsAsync then
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

  if Node.IsGenerator then
    FGeneratorEngine.ConvertToGeneratorFunction(Func)
  else if Node.IsAsync then
    FGeneratorEngine.ConvertToAsyncFunction(Func);

  Result := Func;
end;

function TJSInterpreter.CreateMethodFunction(const Node: TJSFunctionExpression; const Name: string): IJSFunction;
begin
  Result := CreateOrdinaryFunction(Node);
  Result.IsConstructor := False;
  Result.Name := Name;

  if Node.IsGenerator then
    FGeneratorEngine.AttachGeneratorPrototype(Result);
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
  if MemberExpr.IsSuper then
  begin
    RequireBoundThis;
    raise TJSErrorFactory.ReferenceError(DELETE_SUPER_REFERENCE, Node.Line, Node.Column);
  end;

  const ObjValue = Visit(MemberExpr.Object_);
  if ObjValue.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject(Node.Line, Node.Column);

  if not ObjValue.IsObject then
    Exit(TJSValue.CreateBoolean(False));

  var PropName: TJSPropertyKey;

  if MemberExpr.Computed then
    PropName := ToPropertyKey(Visit(MemberExpr.Property_))
  else
    PropName := TJSIdentifier(MemberExpr.Property_).Name;

  const Target = ObjValue.ToObject;

  var Proxy: IJSProxy;
  if TJSObjectOperations.AsProxy(Target, Proxy) then
    Exit(DeleteProxyMember(Node, Proxy, PropName));

  const OwnDescriptor = Target.GetOwnPropertyDescriptor(PropName);
  const IsLocked = Target.HasOwnProperty(PropName) and ((not OwnDescriptor.Configurable) or
                                                     TJSBinaryKeys.IsElementKey(Target, PropName));
  if IsLocked and FStrictMode then
    RaiseCannotDelete(Node, PropName);

  if IsLocked then
    Exit(TJSValue.CreateBoolean(False));

  DeleteArrayElement(Target, PropName);
  Target.DeleteProperty(PropName);
  Result := TJSValue.CreateBoolean(True);
end;

procedure TJSInterpreter.RaiseCannotDelete(const Node: TJSUnaryExpression; const PropName: TJSPropertyKey);
begin
  const Message = Format(CANNOT_DELETE_PROPERTY, [PropName.Text]);

  raise TJSErrorFactory.TypeError(Message, Node.Line, Node.Column);
end;

class function TJSInterpreter.IsLongChain(const ChainLength: Integer): Boolean;
begin
  Result := (ChainLength >= ITERATIVE_CHAIN_LENGTH);
end;

procedure TJSInterpreter.ReleaseFunctionContents(const Func: IJSFunction);
begin
  Func.ClosureScope := nil;
  Func.LexicalThis := nil;
  Func.NativeFunction := nil;
  Func.ReleaseCapturedContext;
  DetachProperties(Func);
end;

procedure TJSInterpreter.RequireBoundThis;
begin
  const HasBinding = Assigned(FContext.Binding);
  const IsUnbound = (HasBinding and (not Assigned(ActiveBinding.Value)));
  if IsUnbound then
    raise TJSErrorFactory.ReferenceError(THIS_BEFORE_SUPER);
end;

function TJSInterpreter.DeleteProxyMember(const Node: TJSUnaryExpression; const Proxy: IJSProxy;
                                          const PropName: TJSPropertyKey): TJSValue;
begin
  const IsRemoved = Proxy.DeleteOwnProperty(PropName);
  if (not IsRemoved) and FStrictMode then
    RaiseCannotDelete(Node, PropName);

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

  const IsBaseErrorConstructor = (ConstructorName = TJSErrorType.Error.Name);
  const IsOwnErrorConstructor = (ConstructorName = ErrorIntf.ErrorType.Name);
  Result := (IsBaseErrorConstructor or IsOwnErrorConstructor);
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

    const IsOrdinary = Assigned(FOrdinaryHasInstance) and TJSObjectOperations.IsSameObject(HandlerFunc, FOrdinaryHasInstance);
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
  if IsLongChain(Node.ChainLength) then
  begin
    Result := VisitBinaryChain(Node);
    Exit;
  end;

  const Left = Visit(Node.Left);
  const Right = Visit(Node.Right);

  const IsNumberOperator = (Node.Operator in OPERATORS_OF_NUMBERS);
  if IsNumberOperator then
  begin
    Result := TJSOperators.Apply(Node.Operator, Left, Right, FLimits);
  end
  else
  begin
    Result := ApplyBinary(Node, Left, Right);
  end;
end;

function TJSInterpreter.CollectChain(const First: TJSExpression; const ChainLength: Integer): TArray<TJSExpression>;
begin
  SetLength(Result, ChainLength + 1);

  var Count := 0;
  var Link := First;
  while Assigned(Link) do
  begin
    Result[Count] := Link;
    Inc(Count);

    Link := NextChainLink(Link);
  end;

  SetLength(Result, Count);
end;

function TJSInterpreter.NextChainLink(const Link: TJSExpression): TJSExpression;
begin
  const IsAccessLink = (Link.ChainKind = TJSChainKind.Access);
  if IsAccessLink then
  begin
    const Operand = ChainOperand(Link);
    const ContinuesAccessChain = (Assigned(Operand) and IsChainLink(Operand));
    if ContinuesAccessChain then
      Result := Operand
    else
      Result := nil;

    Exit;
  end;

  const Next = Link.ChainChild;
  const ContinuesChain = (Assigned(Next) and (Next.ChainKind = Link.ChainKind) and (not Next.IsRemembered));
  if ContinuesChain then
    Result := Next
  else
    Result := nil;
end;

function TJSInterpreter.VisitBinaryChain(const Node: TJSBinaryExpression): TJSValue;
begin
  const Links = CollectChain(Node, Node.ChainLength);

  const LastLink = TJSBinaryExpression(Links[High(Links)]);
  Result := Visit(LastLink.Left);
  for var Index := High(Links) downto 0 do
  begin
    const Current = TJSBinaryExpression(Links[Index]);
    const Right = Visit(Current.Right);
    Result := ApplyBinary(Current, Result, Right);
  end;
end;

function TJSInterpreter.ApplyBinary(const Node: TJSBinaryExpression; const Left: TJSValue;
                                    const Right: TJSValue): TJSValue;
begin
  const IsNumberOperator = (Node.Operator in OPERATORS_OF_NUMBERS);
  if IsNumberOperator then
  begin
    Result := TJSOperators.Apply(Node.Operator, Left, Right, FLimits);
    Exit;
  end;

  case Node.Operator of
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
  if IsLongChain(Node.ChainLength) then
  begin
    Result := VisitLogicalChain(Node);
    Exit;
  end;

  const Left = Visit(Node.Left);

  Result := ApplyLogical(Node, Left);
end;

function TJSInterpreter.VisitLogicalChain(const Node: TJSLogicalExpression): TJSValue;
begin
  const Links = CollectChain(Node, Node.ChainLength);

  const LastLink = TJSLogicalExpression(Links[High(Links)]);
  Result := Visit(LastLink.Left);
  for var Index := High(Links) downto 0 do
  begin
    Result := ApplyLogical(TJSLogicalExpression(Links[Index]), Result);
  end;
end;

function TJSInterpreter.ApplyLogical(const Node: TJSLogicalExpression; const Left: TJSValue): TJSValue;
begin
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
    TJSLogicalOperator.Nullish:
      begin
        if not Left.IsNullOrUndefined then
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
    Result.Default := TJSAssignmentPattern(Element).DefaultValue;
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
        Reference.Prepare(Self);
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
  const IsResumable = Assigned(FGenerator) and Pattern.ContainsSuspension;
  if IsResumable then
  begin
    BindResumableArrayPattern(Pattern, Value, Mode);
    Exit;
  end;

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

procedure TJSInterpreter.BindResumableArrayPattern(const Pattern: TJSArrayPattern; const Value: TJSValue;
                                                   const Mode: TJSBindingMode);
begin
  const Frame = FGeneratorEngine.FrameFor(Pattern);
  try
    if Frame.IsAt(TJSFrameStage.Fresh) then
    begin
      Frame.Source := OpenIterationSource(Value);
      Frame.MoveTo(TJSFrameStage.PatternElement);
    end;

    try
      BindResumableElements(Pattern, Frame, Mode);
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

    Frame.Source.Close;
  finally
    FGenerator.ReleaseFrame(Pattern);
  end;
end;

procedure TJSInterpreter.BindResumableElements(const Pattern: TJSArrayPattern; const Frame: TJSStatementFrame;
                                               const Mode: TJSBindingMode);
begin

  while Frame.Index < Pattern.Elements.Count do
  begin
    const Element = Pattern.Elements[Frame.Index];
    const IsHole = (Element = nil);
    if IsHole then
    begin
      Frame.Source.Next;
      Inc(Frame.Index);
      Continue;
    end;

    const IsRest = (Element is TJSSpreadElement);
    var Target := Element;
    if IsRest then
      Target := TJSSpreadElement(Element).Argument;

    const Resolved = ResolvePatternTarget(Target, Mode);
    if (not Frame.IsAt(TJSFrameStage.PatternValueFetched)) then
    begin
      if IsRest then
      begin
        const RemainingValues = Frame.Source.Remaining;
        Frame.Current := CreateRestArray(RemainingValues, 0);
      end
      else
      begin
        Frame.Current := Frame.Source.Next;
      end;

      Frame.MoveTo(TJSFrameStage.PatternValueFetched);
    end;

    StorePatternTarget(Resolved, Frame.Current, Mode);
    Frame.MoveTo(TJSFrameStage.PatternElement);
    Inc(Frame.Index);

    if IsRest then
      Break;
  end;
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

function TJSInterpreter.IsIntrinsicProperty(const Start: IJSObject; const Key: TJSPropertyKey;
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
    begin
      Result := TJSIntrinsicSlot.IsIntrinsic(Slot, Original);
      Exit;
    end;

    Current := Current.Prototype;
  end;
end;

function TJSInterpreter.InheritsKeyFromArrayPrototype(const Target: IJSObject; const Key: TJSPropertyKey): Boolean;
begin
  Result := False;

  const HasArrayPrototype = (Target.Prototype = FArrayPrototype);
  if not (HasArrayPrototype and (Target is TJSObjectImpl)) then
    Exit;

  Result := not TJSObjectImpl(Target).HasOwnSlot(Key);
end;

function TJSInterpreter.HasUntouchedArrayIteration(const Target: IJSObject): Boolean;
begin
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  const IsOriginalValues = (InheritsKeyFromArrayPrototype(Target, IteratorKey) and
                            FArrayValuesSlot.Holds(FArrayPrototype, IteratorKey, FIteration.ArrayValues)) or
                           IsIntrinsicProperty(Target, IteratorKey, FIteration.ArrayValues);

  Result := IsOriginalValues and
            FArrayNextSlot.Holds(FIteration.ArrayIteratorPrototype, ITERATOR_NEXT_PROPERTY,
                                 FIteration.ArrayIteratorNext);
end;

function TJSInterpreter.HasUntouchedStringIteration: Boolean;
begin
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  Result := FStringIteratorSlot.Holds(FStringPrototype, IteratorKey, FIteration.StringIterator) and
            FStringNextSlot.Holds(FIteration.StringIteratorPrototype, ITERATOR_NEXT_PROPERTY,
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
      const Evaluated = EvaluatePropertyKey(Prop.Computed, Prop.Key);
      if Assigned(Excluded) then
        Excluded.Add(Evaluated.Key.Stored);

      const Resolved = ResolvePatternTarget(Prop.Value, Mode);
      const PropertyValue = ReadMember(Value, Evaluated.Key);
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

  const SourceObject = Source.ToObject;

  for var PropName in TJSObjectOperations.OwnKeys(SourceObject) do
  begin
    const IsExcluded = Assigned(Excluded) and Excluded.Contains(PropName.Stored);
    if IsExcluded or (not SourceObject.GetOwnPropertyDescriptor(PropName).Enumerable) then
      Continue;

    const PropertyValue = SourceObject.GetProperty(PropName);
    Target.DefineProperty(PropName, TJSPropertyDescriptor.Create(PropertyValue));
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
  begin
    Result := Binding.GetVariable(Name);
    Exit;
  end;

  var ObjectScope: IJSObjectScope;
  if Supports(Binding, IJSObjectScope, ObjectScope) then
  begin
    Result := ObjectScope.GetBindingValue(Name, FStrictMode);
    Exit;
  end;

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
    Reference.Prepare(Self);
  end
  else
  begin
    Reference.Prepare(Self);
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
  Reference.Prepare(Self);
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
  if IsLongChain(Node.ChainLength) then
  begin
    Result := VisitValueChain(Node, Node.ChainLength);
    Exit;
  end;

  Result := EvaluateCall(Node, nil);
end;

function TJSInterpreter.OperandOrBase(const Operand: TJSExpression; const Base: PJSValue): TJSValue;
begin
  if Assigned(Base) then
    Result := Base^
  else
    Result := Visit(Operand);
end;

function TJSInterpreter.EvaluateCall(const Node: TJSCallExpression; const Base: PJSValue): TJSValue;
begin
  var ThisObj: IJSObject := nil;
  var ThisValue := TJSValue.CreateUndefined;
  var Args: TArray<TJSValue>;
  var ArgsEvaluated := False;
  var CalleeValue := TJSValue.CreateUndefined;
  var MethodName := '';
  var MethodKey: TJSPropertyKey;

  const IsMemberCall = Node.Callee is TJSMemberExpression;
  if IsMemberCall then
  begin
    const MemberExpr = TJSMemberExpression(Node.Callee);
    if MemberExpr.IsSuper then
    begin
      Result := CallSuperMethod(Node, MemberExpr);
      Exit;
    end;

    const ObjValue = OperandOrBase(MemberExpr.Object_, Base);
    ThisValue := ObjValue;

    if MemberExpr.Computed then
      MethodKey := ToPropertyKey(Visit(MemberExpr.Property_))
    else
      MethodKey := TJSIdentifier(MemberExpr.Property_).Key;

    MethodName := MethodKey.Text;

    Args := EvaluateArguments(Node.Arguments, Node.HasSpread);
    ArgsEvaluated := True;

    RequireObjectCoercible(ObjValue, MethodName);

    var ArrayResult: TJSValue;
    if TryCallUntouchedArrayMethod(ObjValue, MethodName, Args, ArrayResult) then
      Exit(ArrayResult);

    CalleeValue := ReadMember(ObjValue, MethodKey);

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
  else if Node.Callee is TJSSuperExpression then
  begin
    Result := VisitSuperCall(Node);
    Exit;
  end
  else
  begin
    CalleeValue := OperandOrBase(Node.Callee, Base);
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

// Calls an array method without reading it as a property first, as long as the array inherits it
// straight from Array.prototype and the method there is still the built-in one.
function TJSInterpreter.TryCallUntouchedArrayMethod(const Target: TJSValue; const Name: string;
                                                    const Args: TArray<TJSValue>; out Value: TJSValue): Boolean;
begin
  Result := False;

  if not Target.IsArray then
    Exit;

  var Arr: IJSArray;
  const TargetObject = Target.ToObject;
  const IsPlainArray = Supports(TargetObject, IJSArray, Arr) and InheritsKeyFromArrayPrototype(Arr, Name);
  if not IsPlainArray then
    Exit;

  const ArrayMethods = FIntrinsicMethods[TJSIntrinsicGroup.ArrayMethod];

  if Name = METHOD_PUSH then
  begin
    Result := FPushCache.Holds(Name, FArrayPrototype, ArrayMethods);
    if Result then
    begin
      Value := CallMutator(FPushCache, True, Arr, Name, Args);
    end;

    Exit;
  end;

  if Name = METHOD_POP then
  begin
    Result := FPopCache.Holds(Name, FArrayPrototype, ArrayMethods);
    if Result then
    begin
      Value := CallMutator(FPopCache, False, Arr, Name, Args);
    end;

    Exit;
  end;

  Result := TryCallRegisteredMethod(Arr, Name, Args, Value);
end;

function TJSInterpreter.TryCallRegisteredMethod(const Arr: IJSArray; const Name: string; const Args: TArray<TJSValue>;
                                                out Value: TJSValue): Boolean;
begin
  Result := False;

  const Methods = FIntrinsicMethods[TJSIntrinsicGroup.ArrayMethod];
  var Method: IJSObject;
  const IsKnownMethod = Assigned(Methods) and Methods.TryGetValue(Name, Method) and (FArrayPrototype is TJSObjectImpl);
  if not IsKnownMethod then
    Exit;

  var Slot: PJSPropertyDescriptor;
  const HoldsMethod = TJSObjectImpl(FArrayPrototype).TryGetOwnSlot(Name, Slot) and (not Slot.IsAccessor) and
                      Slot.Value.IsObject and (Slot.Value.ToObject = Method);
  if not HoldsMethod then
    Exit;

  Value := ExecuteArrayMethod(Arr, Name, Args);
  Result := True;
end;

// push and pop on a dense array need none of the species, callback and property-level checks, which
// would otherwise cost more than the operation itself.
function TJSInterpreter.CallMutator(const Cache: TJSMutatorCache; const StoresNewElements: Boolean;
                                    const Arr: IJSArray; const Name: string;
                                    const Args: TArray<TJSValue>): TJSValue;
begin
  const WouldStoreIntoPrototype = StoresNewElements and Assigned(Cache.PrototypeElements) and
                                  (Cache.PrototypeElements.Length > 0);
  const IsPlainPush = (Arr.IsDenseAndMutable and (not WouldStoreIntoPrototype));

  if IsPlainPush then
  begin
    Result := TJSBuiltins.CallArrayMethod(Arr, Name, Args, FLimits);
  end
  else
  begin
    Result := ExecuteArrayMethod(Arr, Name, Args);
  end;
end;

procedure TJSInterpreter.RequireObjectCoercible(const Value: TJSValue; const PropName: string);
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ACCESS_PROPERTY, [PropName]));
end;

function TJSMemberReference.KeyPointer: PJSPropertyKey;
begin
  if Assigned(NamedKey) then
    Exit(NamedKey);

  Result := @ComputedKey;
end;

procedure TJSMemberReference.ResolveKey(const Limits: TJSLimits);
begin
  if HasKeyText then
    Exit;

  ComputedKey := Key.ToPropertyKey(Limits);
  HasKeyText := True;
end;

procedure TJSMemberReference.Prepare(const Interpreter: TJSInterpreter);
begin
  if IsSuper then
  begin
    SuperBaseObject := Interpreter.SuperBase;
  end
  else
  begin
    Interpreter.RequireCoercibleBase(Self);
  end;

  ResolveKey(Interpreter.Limits);
end;

procedure TJSInterpreter.RequireCoercibleBase(const Reference: TJSMemberReference);
begin
  if Reference.Base.IsNullOrUndefined then
  begin
    const KeyDescription = DescribeReferenceKey(Reference);
    RequireObjectCoercible(Reference.Base, KeyDescription);
  end;
end;

function TJSInterpreter.CreateMemberReference(const Node: TJSMemberExpression; const Base: TJSValue;
                                              const IsSuper: Boolean): TJSMemberReference;
begin
  Result.IsSuper := IsSuper;
  Result.Base := Base;
  Result.HasKeyText := not Node.Computed;

  if Node.Computed then
  begin
    Result.NamedKey := nil;
    Result.Key := Visit(Node.Property_);
  end
  else
  begin
    Result.NamedKey := TJSIdentifier(Node.Property_).KeyPointer;
  end;
end;

function TJSInterpreter.VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
begin
  if IsLongChain(Node.ChainLength) then
  begin
    Result := VisitValueChain(Node, Node.ChainLength);
    Exit;
  end;

  var Reference := ResolveMemberReference(Node);
  Reference.Prepare(Self);

  Result := GetReferenceValue(Reference);
end;

function TJSInterpreter.VisitValueChain(const Node: TJSExpression; const ChainLength: Integer): TJSValue;
begin
  const Links = CollectChain(Node, ChainLength);

  const LastLink = Links[High(Links)];
  const FirstOperand = ChainOperand(LastLink);

  var FirstLink := High(Links);
  var Start: TJSValue;
  if Assigned(FirstOperand) then
  begin
    Start := Visit(FirstOperand);
  end
  else
  begin
    Start := EvaluateCall(TJSCallExpression(LastLink), nil);
    Dec(FirstLink);
  end;

  Result := EvaluateChainLinks(Links, FirstLink, Start);
end;

function TJSInterpreter.EvaluateChainLinks(const Links: TArray<TJSExpression>; const FirstLink: Integer;
                                           const Start: TJSValue): TJSValue;
begin
  Result := Start;

  for var Index := FirstLink downto 0 do
  begin
    const Current = Links[Index];
    var Previous := Result;
    if Current is TJSCallExpression then
    begin
      Result := EvaluateCall(TJSCallExpression(Current), @Previous);
    end
    else
    begin
      var Reference := CreateMemberReference(TJSMemberExpression(Current), Previous, False);
      Reference.Prepare(Self);

      Result := GetReferenceValue(Reference);
    end;
  end;
end;

function TJSInterpreter.ChainOperand(const Link: TJSExpression): TJSExpression;
begin
  if Link is TJSMemberExpression then
  begin
    Result := TJSMemberExpression(Link).Object_;
    Exit;
  end;

  const Callee = TJSCallExpression(Link).Callee;
  if Callee is TJSCallExpression then
    Exit(Callee);

  const IsMemberCallee = (Callee is TJSMemberExpression) and IsChainLink(Callee);
  if IsMemberCallee then
  begin
    Result := TJSMemberExpression(Callee).Object_;
    Exit;
  end;

  Result := nil;
end;

function TJSInterpreter.IsChainLink(const Node: TJSExpression): Boolean;
begin
  if Node.IsRemembered then
    Exit(False);

  if Node is TJSMemberExpression then
  begin
    Result := not TJSMemberExpression(Node).IsSuper;
    Exit;
  end;

  Result := Node is TJSCallExpression;
end;

function TJSInterpreter.ResolveMemberReference(const Node: TJSMemberExpression): TJSMemberReference;
begin
  var Base: TJSValue;
  if Node.IsSuper then
  begin
    Base := CurrentThisValue;
  end
  else
  begin
    Base := Visit(Node.Object_);
  end;

  Result := CreateMemberReference(Node, Base, Node.IsSuper);
end;

procedure TJSInterpreter.RaiseStackExhausted;
begin
  raise TJSErrorFactory.StackExhausted;
end;

procedure TJSInterpreter.RequireSuperHome;
begin
  const Callee = ActiveCallee;
  const HasHome = Assigned(Callee) and Assigned(Callee.HomeObject);
  if not HasHome then
    raise TJSErrorFactory.SyntaxError(SUPER_OUTSIDE_METHOD);
end;

function TJSInterpreter.SuperBase: IJSObject;
begin
  RequireSuperHome;

  Result := ActiveCallee.HomeObject.Prototype;
end;

function TJSInterpreter.ReadSuperMember(const Reference: TJSMemberReference): TJSValue;
begin
  const Base = Reference.SuperBaseObject;

  if not Assigned(Base) then
    raise TJSErrorFactory.TypeError(SUPER_BASE_NOT_OBJECT);

  Result := TJSObjectOperations.GetWithReceiver(Base, Reference.KeyPointer^, Reference.Base);
end;

procedure TJSInterpreter.WriteSuperMember(const Reference: TJSMemberReference; const Value: TJSValue);
begin
  const Base = Reference.SuperBaseObject;

  if not Assigned(Base) then
    raise TJSErrorFactory.TypeError(SUPER_BASE_NOT_OBJECT);

  const IsStored = TJSObjectOperations.SetWithReceiver(Base, Reference.KeyPointer^, Value, Reference.Base);
  if (not IsStored) and FStrictMode then
    RaiseCannotAssign(Reference.KeyPointer^);
end;

function TJSInterpreter.CallSuperMethod(const Node: TJSCallExpression;
                                        const MemberExpr: TJSMemberExpression): TJSValue;
begin
  var Reference := ResolveMemberReference(MemberExpr);
  Reference.Prepare(Self);
  const CalleeValue = GetReferenceValue(Reference);
  const Args = EvaluateArguments(Node.Arguments, Node.HasSpread);

  var Func: IJSFunction;
  const CalleeObject = CalleeValue.ToObject;
  const IsCallable = (CalleeValue.IsFunction and Supports(CalleeObject, IJSFunction, Func));
  if not IsCallable then
  begin
    const CalleeDescription = GetCalleeDescription(Node.Callee, CalleeValue);
    raise TJSErrorFactory.NotAFunction(CalleeDescription, Node.Line, Node.Column);
  end;

  const Receiver = ThisObjectFor(Func, Reference.Base);
  Result := CallFunction(Func, Args, Receiver);
end;

function TJSInterpreter.VisitSuperCall(const Node: TJSCallExpression): TJSValue;
begin
  const Callee = ActiveCallee;
  const Binding = ActiveBinding;
  const NewTarget = ActiveNewTarget;
  const HasSuperContext = (Assigned(Callee) and Assigned(Binding) and Assigned(NewTarget));
  if not HasSuperContext then
    raise TJSErrorFactory.SyntaxError(SUPER_OUTSIDE_METHOD);

  const ParentFunction = ParentConstructorOf(Callee);
  const Args = EvaluateArguments(Node.Arguments, Node.HasSpread);

  if not Assigned(ParentFunction) then
    raise TJSErrorFactory.TypeError(SUPER_NOT_CONSTRUCTOR, Node.Line, Node.Column);

  const Created = Construct(ParentFunction, Args, NewTarget);

  if Assigned(Binding.Value) then
    raise TJSErrorFactory.ReferenceError(SUPER_CALLED_TWICE);

  Binding.Value := Created.ToObject;
  Result := Created;
end;

function TJSInterpreter.DescribeReferenceKey(const Reference: TJSMemberReference): string;
begin
  if Reference.HasKeyText then
  begin
    Result := Reference.KeyPointer.Text;
    Exit;
  end;

  if Reference.Key.IsObject then
    Exit(OBJECT_KEY_DESCRIPTION);

  if Reference.Key.IsSymbol then
    Exit(Reference.Key.SymbolDescriptiveString);

  Result := ToText(Reference.Key);
end;

function TJSInterpreter.ToPropertyKey(const Key: TJSValue): TJSPropertyKey;
begin
  Result := Key.ToPropertyKey(FLimits);
end;

function TJSInterpreter.GetReferenceValue(const Reference: TJSMemberReference): TJSValue;
begin
  if Reference.IsSuper then
  begin
    Result := ReadSuperMember(Reference);
  end
  else
  begin
    Result := ReadMember(Reference.Base, Reference.KeyPointer^);
  end;
end;

procedure TJSInterpreter.PutReferenceValue(const Reference: TJSMemberReference; const Value: TJSValue);
begin
  if Reference.IsSuper then
  begin
    WriteSuperMember(Reference, Value);
  end
  else
  begin
    WriteMember(Reference.Base, Reference.KeyPointer^, Value);
  end;
end;

function TJSInterpreter.ReadMember(const Base: TJSValue; const PropName: TJSPropertyKey): TJSValue;
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

      const IsPlainElement = TJSArray.TryParseIndex(PropName, Index) and ArrIntf.HasElement(Index);
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

    if TJSArray.TryParseIndex(PropName, Index) then
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
                                            const PropName: TJSPropertyKey): TJSValue;
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
  if FBoundFunctions.TryGetValue(TJSObjectOperations.IdentityOf(Func), Bound) then
  begin
    Result := ConstructBound(Bound, Args, Func, NewTarget);
    Exit;
  end;

  if Func.IsNative then
  begin
    Result := ConstructNativeFunction(Func, Args, NewTarget);
    Exit;
  end;

  Result := ConstructScript(Func, Args, NewTarget);
end;

function TJSInterpreter.ConstructBound(const Bound: TJSBoundFunction; const Args: TArray<TJSValue>;
                                       const Func: IJSFunction; const NewTarget: IJSFunction): TJSValue;
begin
  const AllArguments = Bound.Arguments + Args;

  var ForwardedTarget := NewTarget;
  if TJSObjectOperations.IsSameObject(NewTarget, Func) then
  begin
    ForwardedTarget := Bound.Target;
  end;

  Result := ConstructBoundTarget(Bound.Target, AllArguments, ForwardedTarget);
end;

function TJSInterpreter.ConstructNativeFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                                const NewTarget: IJSFunction): TJSValue;
begin
  var NativeConstructor: IJSNativeConstructor;
  if Supports(Func, IJSNativeConstructor, NativeConstructor) then
  begin
    Result := NativeConstructor.ConstructWith(Args, NewTarget);
  end
  else
  begin
    Result := ConstructNative(Func, Args, NewTarget);
  end;
end;

function TJSInterpreter.ConstructScript(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                        const NewTarget: IJSFunction): TJSValue;
begin
  const IsDerived = (Func.Kind = TJSFunctionKind.DerivedConstructor);
  if IsDerived then
  begin
    Result := ConstructDerived(Func, Args, NewTarget);
    Exit;
  end;

  const IsBase = (Func.Kind = TJSFunctionKind.BaseConstructor);
  if IsBase then
  begin
    Result := ConstructBase(Func, Args, NewTarget);
    Exit;
  end;

  const Instance = CreateInstanceFor(NewTarget);
  const ReturnValue = InvokeFunction(Func, Args, Instance, NewTarget, nil);

  if ReturnValue.IsObject then
    Result := ReturnValue
  else
    Result := TJSValue.CreateObject(Instance);
end;

function TJSInterpreter.ConstructBase(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                      const NewTarget: IJSFunction): TJSValue;
begin
  const Instance = CreateInstanceFor(NewTarget);
  if Func.IsDefaultConstructor then
  begin
    Result := TJSValue.CreateObject(Instance);
    Exit;
  end;

  const ReturnValue = InvokeFunction(Func, Args, Instance, NewTarget, nil);
  if ReturnValue.IsObject then
    Result := ReturnValue
  else
    Result := TJSValue.CreateObject(Instance);
end;

function TJSInterpreter.ConstructDerived(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                         const NewTarget: IJSFunction): TJSValue;
begin
  if Func.IsDefaultConstructor then
  begin
    Result := ConstructThroughParent(Func, Args, NewTarget);
    Exit;
  end;

  const Binding: IJSThisBinding = TJSThisBinding.Create;
  const ReturnValue = InvokeFunction(Func, Args, nil, NewTarget, Binding);
  if ReturnValue.IsObject then
  begin
    Result := ReturnValue;
    Exit;
  end;

  if not ReturnValue.IsUndefined then
    raise TJSErrorFactory.TypeError(DERIVED_RETURN_VALUE);

  const BoundThis = Binding.Value;
  if not Assigned(BoundThis) then
    raise TJSErrorFactory.ReferenceError(THIS_BEFORE_SUPER);

  Result := TJSValue.CreateObject(BoundThis);
end;

function TJSInterpreter.ParentConstructorOf(const Func: IJSFunction): IJSFunction;
begin
  Result := nil;

  const Parent = Func.Prototype;
  var ParentFunction: IJSFunction;
  const IsConstructor = Assigned(Parent) and Supports(Parent, IJSFunction, ParentFunction) and
                        ParentFunction.IsConstructor;
  if IsConstructor then
    Result := ParentFunction;
end;

function TJSInterpreter.ConstructThroughParent(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                               const NewTarget: IJSFunction): TJSValue;
begin
  ConsumeStep;
  EnsureCallDepthAvailable;

  const Parent = ParentConstructorOf(Func);
  if not Assigned(Parent) then
    raise TJSErrorFactory.TypeError(SUPER_NOT_CONSTRUCTOR);

  Inc(FCallDepth);
  try
    Result := Construct(Parent, Args, NewTarget);
  finally
    Dec(FCallDepth);
  end;
end;

function TJSInterpreter.ConstructNative(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                        const NewTarget: IJSFunction): TJSValue;
begin
  const Instance = CreateInstanceFor(Func);
  const ReturnValue = InvokeFunction(Func, Args, Instance, nil, nil);

  const IsOwnTarget = TJSObjectOperations.IsSameObject(NewTarget, Func);
  if IsOwnTarget then
  begin
    if ReturnValue.IsObject then
      Result := ReturnValue
    else
      Result := TJSValue.CreateObject(Instance);

    Exit;
  end;

  const IsReplacementObject = (ReturnValue.IsObject and (not TJSObjectOperations.IsSameObject(ReturnValue.ToObject, Instance)));
  const IsObjectConstructor = TJSObjectOperations.IsSameObject(Instance.Prototype, FObjectPrototype);
  var Subject := Instance;
  if IsReplacementObject and (not IsObjectConstructor) then
    Subject := ReturnValue.ToObject;

  AdoptNewTargetPrototype(Subject, NewTarget);
  Result := TJSValue.CreateObject(Subject);
end;

procedure TJSInterpreter.AdoptNewTargetPrototype(const Instance: IJSObject; const NewTarget: IJSFunction);
begin
  const Candidate = NewTarget.GetProperty(PROTOTYPE_PROPERTY);
  if Candidate.IsObject then
    Instance.Prototype := Candidate.ToObject
  else
    RequireLiveProxy(NewTarget);
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
  Result := CurrentThisValue;
end;

function TJSInterpreter.ReadBoundThis(const Binding: IJSThisBinding): TJSValue;
begin
  const Value = Binding.Value;
  if not Assigned(Value) then
    raise TJSErrorFactory.ReferenceError(THIS_BEFORE_SUPER);

  Result := TJSValue.CreateObject(Value);
end;

function TJSInterpreter.VisitNewTargetExpression: TJSValue;
begin
  const NewTarget = ActiveNewTarget;
  if Assigned(NewTarget) then
    Result := TJSValue.CreateObject(NewTarget)
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.CurrentThisValue: TJSValue;
begin
  if Assigned(FContext.Binding) then
  begin
    Result := ReadBoundThis(ActiveBinding);
    Exit;
  end;

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
    const Chunk = Node.Parts[Index + 1].Cooked;
    FLimits.EnsureStringLength(Int64(Length(Text)) + Length(Substitution) + Length(Chunk));
    Text := Text + Substitution + Chunk;
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
  if Value.IsArray then
  begin
    Result := Value.ToLimitedString(FLimits);
    Exit;
  end;

  const Primitive = Value.ToPrimitive(True);
  Result := Primitive.ToLimitedString(FLimits);
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

function TJSInterpreter.EnterHeap: TJSHeap;
begin
  Result := TJSHeap.Switch(FHeap);
  Inc(FHeapEntries);
end;

procedure TJSInterpreter.LeaveHeap(const Previous: TJSHeap);
begin
  Dec(FHeapEntries);
  TJSHeap.Switch(Previous);
end;

function TJSInterpreter.CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
begin
  const IsCalledByHost = (FHeapEntries = 0);
  if IsCalledByHost then
  begin
    Result := CallFromHost(Func, Args, ThisObj);
    Exit;
  end;

  if Func.IsNative then
  begin
    Result := CallNative(Func, Args, ThisObj);
    Exit;
  end;

  RejectClassConstructorCall(Func);
  Result := InvokeFunction(Func, Args, ThisObj, nil, nil);
end;

function TJSInterpreter.CallNative(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                   const ThisObj: IJSObject): TJSValue;
begin
  ConsumeStep;

  const NativeResult = Func.NativeFunction(ThisObj, Args);
  Result := WithArrayPrototype(NativeResult);
end;

function TJSInterpreter.CallFromHost(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                     const ThisObj: IJSObject): TJSValue;
begin
  const PreviousHeap = EnterHeap;
  try
    Result := CallFunction(Func, Args, ThisObj);
  finally
    LeaveHeap(PreviousHeap);
  end;
end;

procedure TJSInterpreter.RejectClassConstructorCall(const Func: IJSFunction);
begin
  const IsClassConstructor = Func.Kind in [TJSFunctionKind.BaseConstructor, TJSFunctionKind.DerivedConstructor];
  if IsClassConstructor then
  begin
    const Message = Format(CLASS_CONSTRUCTOR_CALL, [Func.Name]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

procedure TJSInterpreter.EnsureCallDepthAvailable;
begin
  const IsDepthLimited = (FLimits.MaxCallDepth > 0);
  const IsDepthExhausted = (IsDepthLimited and (FCallDepth >= FLimits.MaxCallDepth));
  if IsDepthExhausted then
    raise EJSCallDepthExceeded.Create(FLimits.MaxCallDepth);
end;

function TJSInterpreter.CallBoundTarget(const Target: IJSFunction; const Args: TArray<TJSValue>;
                                        const BoundThis: IJSObject): TJSValue;
begin
  EnsureCallDepthAvailable;

  Inc(FCallDepth);
  try
    Result := CallFunction(Target, Args, BoundThis);
  finally
    Dec(FCallDepth);
  end;
end;

function TJSInterpreter.ConstructBoundTarget(const Target: IJSFunction; const Args: TArray<TJSValue>;
                                             const NewTarget: IJSFunction): TJSValue;
begin
  EnsureCallDepthAvailable;

  Inc(FCallDepth);
  try
    Result := Construct(Target, Args, NewTarget);
  finally
    Dec(FCallDepth);
  end;
end;

procedure TJSInterpreter.EnterContext(const Func: IJSFunction; const NewTarget: IJSFunction;
                                      const Binding: IJSThisBinding);
begin
  const NeedsContext = (Func.Kind <> TJSFunctionKind.Plain) or Assigned(NewTarget) or Assigned(Binding);
  if NeedsContext then
  begin
    SetContext(Func, NewTarget, Binding);
  end
  else
  begin
    FContext := Default(TJSCallContext);
  end;
end;

procedure TJSInterpreter.SetContext(const Callee: IJSFunction; const NewTarget: IJSFunction;
                                    const Binding: IJSThisBinding);
begin
  FContext.Callee := Pointer(Callee);
  FContext.NewTarget := Pointer(NewTarget);
  FContext.Binding := Pointer(Binding);
end;

procedure TJSInterpreter.EnterArrowContext(const Func: IJSFunction);
begin
  FThisValue := Func.LexicalThis;

  const Captured = Func.Frame;
  if Assigned(Captured) then
  begin
    SetContext(Captured.Callee, Captured.NewTarget, Captured.ThisBinding);
  end
  else
  begin
    FContext := Default(TJSCallContext);
  end;
end;

function TJSInterpreter.ActiveCallee: IJSFunction;
begin
  Result := IJSFunction(FContext.Callee);
end;

function TJSInterpreter.ActiveNewTarget: IJSFunction;
begin
  Result := IJSFunction(FContext.NewTarget);
end;

function TJSInterpreter.ActiveBinding: IJSThisBinding;
begin
  Result := IJSThisBinding(FContext.Binding);
end;

function TJSInterpreter.CaptureFrame: IJSFrame;
begin
  const HasContext = Assigned(FContext.Callee) or Assigned(FContext.NewTarget) or Assigned(FContext.Binding);
  if HasContext then
    Result := TJSFrame.Create(ActiveCallee, ActiveNewTarget, ActiveBinding)
  else
    Result := nil;
end;

function TJSInterpreter.InvokeFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject;
                                       const NewTarget: IJSFunction; const Binding: IJSThisBinding): TJSValue;
begin
  ConsumeStep;

  if Func.IsNative then
    Exit(WithArrayPrototype(Func.NativeFunction(ThisObj, Args)));

  EnsureCallDepthAvailable;

  const OldThis = FThisValue;
  const OldThisPrimitive = FThisPrimitive;
  const OldStrictMode = FStrictMode;
  const OldScope = FCurrentScope;
  const OldVarScope = FVarScope;
  const OldContext = FContext;
  const IsArrow = Func.IsArrow;
  if IsArrow then
  begin
    EnterArrowContext(Func);
  end
  else
  begin
    FThisValue := ThisObj;
    EnterContext(Func, NewTarget, Binding);
  end;
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
    if FunctionBody.IsAsyncBody then
    begin
      Result := FGeneratorEngine.StartAsyncFunction(Func, Args, FunctionBody);
      Exit;
    end;

    BindFunctionParameters(Func, Args, FunctionBody);

    if FunctionBody.IsGeneratorBody then
    begin
      Result := FGeneratorEngine.CreateGeneratorObject(Func);
      Exit;
    end;

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
    FContext := OldContext;
  end;
end;

procedure TJSInterpreter.BindFunctionParameters(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                                const Body: TJSBlockStatement);
begin
  const ParameterInfo = Body.ParameterInfo;
  var ParameterScope: IJSScope := nil;

  if Assigned(ParameterInfo) then
  begin
    ParameterScope := BindParametersWithExpressions(Func, Args, ParameterInfo);
  end
  else
  begin
    for var Index := 0 to Length(Func.Parameters) - 1 do
    begin
      const HasArgument = (Index < Length(Args));
      if HasArgument then
        FCurrentScope.DeclareVariable(Func.Parameters[Index], Args[Index])
      else
        FCurrentScope.DeclareVariable(Func.Parameters[Index], TJSValue.CreateUndefined);
    end;
  end;

  InstantiateTopLevel(Body.Body, Body.ScopeInfo);

  if Assigned(ParameterScope) then
    CopyParametersToBodyScope(Func, ParameterScope, ParameterInfo);
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
  var Definition := TJSPropertyDefinition.ForDataProperty(TJSValue.CreateUndefined);

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

function TJSInterpreter.CallsReplacedJoin(const Arr: IJSArray; const MethodName: string): Boolean;
begin
  Result := (MethodName = ARRAY_TO_STRING_METHOD) and
            (not TJSValue.CreateObject(Arr).HasUntouchedArrayConversion(TJSPrimitiveHint.String_));
end;

function TJSInterpreter.ExecuteArrayMethodCore(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSArrayIteration.Handles(MethodName) then
    Exit(ExecuteArrayIterationMethodCore(Arr, MethodName, Args, nil));

  const UsesPropertySemantics = (not Arr.IsDenseAndMutable) or TJSArrayGeneric.AlwaysUsesPropertySemantics(MethodName) or
                                CallsReplacedJoin(Arr, MethodName) or
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
      Result := Interp.CallBoundTarget(Target, AllArgs, BoundThis);
    end);

  Result.ClosureScope := nil;
  Result.IsConstructor := Target.IsConstructor;
  Result.Prototype := FFunctionPrototype;
  TJSFunction.DefineLength(Result, BoundLength(Target, Length(BoundArgs)));
  RegisterFunction(Result);

  var BoundInfo: TJSBoundFunction;
  BoundInfo.Target := Target;
  BoundInfo.Arguments := BoundArgs;
  FBoundFunctions.Add(TJSObjectOperations.IdentityOf(Result), BoundInfo);
end;

function TJSInterpreter.UnwrapBoundFunction(const Func: IJSFunction): IJSFunction;
begin
  Result := Func;

  var Bound: TJSBoundFunction;
  while FBoundFunctions.TryGetValue(TJSObjectOperations.IdentityOf(Result), Bound) do
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

procedure TJSInterpreter.RaiseCannotAssign(const PropName: TJSPropertyKey);
begin
  const Message = Format(CANNOT_ASSIGN_PROPERTY, [PropName.Text]);

  raise TJSErrorFactory.TypeError(Message);
end;

procedure TJSInterpreter.WriteMember(const Base: TJSValue; const PropName: TJSPropertyKey; const Value: TJSValue);
begin
  if not Base.IsObject then
  begin
    if FStrictMode then
      RaiseCannotAssign(PropName);

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
      RaiseCannotAssign(PropName);

    Exit;
  end;

  const IsRejected = FStrictMode and (not TJSPropertyDescriptors.CanPut(Target, PropName));
  if IsRejected then
    RaiseCannotAssign(PropName);

  Target.SetProperty(PropName, Value);
end;

procedure TJSInterpreter.WriteArrayMember(const Target: IJSArray; const PropName: TJSPropertyKey; const Value: TJSValue;
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
      RaiseCannotAssign(PropName);

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

  const Definition = TJSPropertyDefinition.ForValue(Value);

  const CheckedDefinition = TJSPropertyDescriptors.WithCheckedLength(Target, LENGTH_PROPERTY, Definition, FLimits);
  const IsAssigned = Target.DefineOwnProperty(LENGTH_PROPERTY, CheckedDefinition);
  if (not IsAssigned) and FStrictMode then
    raise TJSErrorFactory.TypeError(READ_ONLY_LENGTH);
end;

procedure TJSInterpreter.DeleteArrayElement(const Target: IJSObject; const PropName: TJSPropertyKey);
begin
  var TargetArray: IJSArray;
  var Index: Integer;

  const IsElement = Supports(Target, IJSArray, TargetArray) and TJSArray.TryParseIndex(PropName, Index);
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

procedure TJSInterpreter.CollectGarbage;
begin
  const Marker = TJSGarbageMarker.Create;
  try
    Marker.Mark(FGlobalScope);
    Marker.Mark(FCurrentScope);
    Marker.Mark(FVarScope);
    Marker.MarkGenerator(FGenerator);
    Marker.Mark(FThisValue);
    Marker.Mark(FGlobalObject);
    Marker.Mark(ActiveCallee);
    Marker.Mark(ActiveNewTarget);
    Marker.MarkBinding(ActiveBinding);
    if Assigned(FGCRootProvider) then
    begin
      FGCRootProvider(
        procedure(const Value: TJSValue)
        begin
          Marker.MarkValue(Value);
        end);
    end;

    for var Func in FFunctionRegistry do
      if Func.IsNative then
        Marker.Mark(Func);

    Marker.TraceReferences;

    for var Index := FFunctionRegistry.Count - 1 downto 0 do
    begin
      const Func = FFunctionRegistry[Index];
      if not Marker.IsLive(Func) then
      begin
        FFunctionPrograms.Remove(TJSObjectOperations.IdentityOf(Func));
        ReleaseFunctionContents(Func);
        FFunctionRegistry.Delete(Index);
      end;
    end;

    for var Index := FScopeRegistry.Count - 1 downto 0 do
    begin
      const Scope = FScopeRegistry[Index];
      if not Marker.IsLive(Scope) then
      begin
        Scope.ReleaseReferences;
        FScopeRegistry.Delete(Index);
      end;
    end;
  finally
    Marker.Free;
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
