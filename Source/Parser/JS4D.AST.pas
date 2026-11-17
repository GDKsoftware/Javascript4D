unit JS4D.AST;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey;

type
  TJSASTNode = class;
  TJSExpression = class;
  TJSStatement = class;
  TJSProgram = class;

  TJSASTNodeType = (
    Program_,

    BlockStatement,
    VariableDeclaration,
    FunctionDeclaration,
    ExpressionStatement,
    IfStatement,
    WhileStatement,
    DoWhileStatement,
    ForStatement,
    ForInStatement,
    ForOfStatement,
    ReturnStatement,
    BreakStatement,
    ContinueStatement,
    SwitchStatement,
    SwitchCase,
    ThrowStatement,
    TryStatement,
    EmptyStatement,
    WithStatement,
    LabeledStatement,
    DebuggerStatement,

    Identifier,
    Literal,
    ArrayExpression,
    ObjectExpression,
    ObjectProperty,
    ClassMember,
    FunctionExpression,
    UnaryExpression,
    BinaryExpression,
    LogicalExpression,
    AssignmentExpression,
    UpdateExpression,
    ConditionalExpression,
    CallExpression,
    MemberExpression,
    NewExpression,
    SequenceExpression,
    ThisExpression,
    TemplateLiteral,
    TemplateObject,
    SpreadElement,
    ArrayPattern,
    ObjectPattern,
    AssignmentPattern,
    SuperExpression,
    NewTargetExpression,
    ClassExpression,
    YieldExpression,
    AwaitExpression,
    Remembered
  );

  TJSASTNode = class
  private
    FNodeType: TJSASTNodeType;
    FLine: Integer;
    FColumn: Integer;
    FContainsSuspension: Boolean;
    FIsRemembered: Boolean;
    FIsDetached: Boolean;
    FDispatchType: TJSASTNodeType;

    procedure SetIsRemembered(const Value: Boolean);
    class procedure ReleaseTree(const Root: TJSASTNode); static;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); virtual;
    class function Detach<T: TJSASTNode>(const Child: T; const Sink: TList<TJSASTNode>): T; static;
    class procedure DetachAll<T: TJSASTNode>(const Children: TObjectList<T>; const Sink: TList<TJSASTNode>); static;

  public
    constructor Create(const NodeType: TJSASTNodeType);
    procedure BeforeDestruction; override;

    property NodeType: TJSASTNodeType read FNodeType;
    property Line: Integer read FLine write FLine;
    property Column: Integer read FColumn write FColumn;
    property ContainsSuspension: Boolean read FContainsSuspension write FContainsSuspension;
    property IsRemembered: Boolean read FIsRemembered write SetIsRemembered;
    property DispatchType: TJSASTNodeType read FDispatchType;
  end;

  TJSChainKind = (
    None,
    Binary,
    Logical,
    Access
  );

  TJSExpression = class(TJSASTNode)
  private
    FIsParenthesized: Boolean;
    FChainKind: TJSChainKind;
    FChainLength: Integer;

  protected
    procedure ContinueChain(const Kind: TJSChainKind; const Operand: TJSExpression);

  public
    function ChainChild: TJSExpression; virtual;

    property IsParenthesized: Boolean read FIsParenthesized write FIsParenthesized;
    property ChainKind: TJSChainKind read FChainKind;
    property ChainLength: Integer read FChainLength;
  end;

  TJSStatement = class(TJSASTNode);

  TJSDeclarationKind = (
    Var_,
    Let,
    Const_
  );

  TJSScopeInfo = class
  private
    FDeclarations: TList<TJSStatement>;
    FMayCaptureScope: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    property Declarations: TList<TJSStatement> read FDeclarations;
    property MayCaptureScope: Boolean read FMayCaptureScope write FMayCaptureScope;
  end;

  TJSProgram = class(TJSASTNode)
  private
    FBody: TObjectList<TJSStatement>;
    FIsStrict: Boolean;
    FScopeInfo: TJSScopeInfo;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Body: TObjectList<TJSStatement> read FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property ScopeInfo: TJSScopeInfo read FScopeInfo write FScopeInfo;
  end;

  TJSBindingCache = record
    Owner: TObject;
    LayoutVersion: Cardinal;
    Slot: Pointer;
  end;

  PJSBindingCache = ^TJSBindingCache;

  TJSIdentifier = class(TJSExpression)
  private
    FName: string;
    FKey: TJSPropertyKey;
    FBindingCache: TJSBindingCache;

    function GetBindingCache: PJSBindingCache; inline;

  public
    constructor Create(const Name: string);
    function KeyPointer: PJSPropertyKey; inline;

    property BindingCache: PJSBindingCache read GetBindingCache;

    property Name: string read FName;
    property Key: TJSPropertyKey read FKey;
  end;

  TJSLiteralType = (
    Undefined,
    Null,
    Boolean,
    Number,
    String_,
    RegExp
  );

  TJSLiteral = class(TJSExpression)
  private
    FLiteralType: TJSLiteralType;
    FBooleanValue: Boolean;
    FNumberValue: Double;
    FStringValue: string;
    FRegExpPattern: string;
    FRegExpFlags: string;

  public
    class function CreateUndefined: TJSLiteral;
    class function CreateNull: TJSLiteral;
    class function CreateBoolean(const Value: Boolean): TJSLiteral;
    class function CreateNumber(const Value: Double): TJSLiteral;
    class function CreateString(const Value: string): TJSLiteral;
    class function CreateRegExp(const Pattern: string; const Flags: string): TJSLiteral;

    property LiteralType: TJSLiteralType read FLiteralType;
    property BooleanValue: Boolean read FBooleanValue;
    property NumberValue: Double read FNumberValue;
    property StringValue: string read FStringValue;
    property RegExpPattern: string read FRegExpPattern;
    property RegExpFlags: string read FRegExpFlags;
  end;

  TJSArrayExpression = class(TJSExpression)
  private
    FHasSpread: Boolean;
    FElements: TObjectList<TJSExpression>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Elements: TObjectList<TJSExpression> read FElements;
    property HasSpread: Boolean read FHasSpread write FHasSpread;
  end;

  TJSPropertyKind = (Data, Getter, Setter, Method, Shorthand, Spread);

  TJSObjectProperty = class(TJSASTNode)
  private
    FKey: TJSExpression;
    FValue: TJSExpression;
    FComputed: Boolean;
    FKind: TJSPropertyKind;
    FSetsPrototype: Boolean;

    function IsPrototypeKey: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    class function KeyName(const Key: TJSExpression): string; static;

    constructor Create(const Key: TJSExpression; const Value: TJSExpression; const Computed: Boolean = False;
                       const Kind: TJSPropertyKind = TJSPropertyKind.Data);
    destructor Destroy; override;

    property Key: TJSExpression read FKey;
    property Value: TJSExpression read FValue write FValue;
    property Computed: Boolean read FComputed;
    property Kind: TJSPropertyKind read FKind;
    property SetsPrototype: Boolean read FSetsPrototype;
  end;

  TJSObjectExpression = class(TJSExpression)
  private
    FProperties: TObjectList<TJSObjectProperty>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Properties: TObjectList<TJSObjectProperty> read FProperties;
  end;

  TJSSpreadElement = class(TJSExpression)
  private
    FArgument: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument write FArgument;
  end;

  TJSAssignmentPattern = class(TJSExpression)
  private
    FTarget: TJSExpression;
    FDefaultValue: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Target: TJSExpression; const DefaultValue: TJSExpression);
    destructor Destroy; override;

    property Target: TJSExpression read FTarget;
    property DefaultValue: TJSExpression read FDefaultValue;
  end;

  TJSArrayPattern = class(TJSExpression)
  private
    FElements: TObjectList<TJSExpression>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Elements: TObjectList<TJSExpression> read FElements;
  end;

  TJSObjectPattern = class(TJSExpression)
  private
    FProperties: TObjectList<TJSObjectProperty>;
    FRest: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Properties: TObjectList<TJSObjectProperty> read FProperties;
    property Rest: TJSExpression read FRest write FRest;
  end;

  TJSPatternNames = class
  public
    class procedure Collect(const Target: TJSASTNode; const Names: TList<string>); static;
    class function NamesOf(const Target: TJSASTNode): TArray<string>; static;
  end;

  TJSParameterInfo = class
  private
    FDefaults: TObjectList<TJSExpression>;
    FPatterns: TObjectList<TJSExpression>;
    FRest: TJSIdentifier;
    FRestPattern: TJSExpression;
    FBoundNames: TArray<string>;
    FExpectedArgumentCount: Integer;
    FHasDefaults: Boolean;
    FHasPatterns: Boolean;
    FReferencesArguments: Boolean;

    function GetNeedsParameterScope: Boolean;

  public
    class procedure DetachSignature(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo;
                                    const Sink: TList<TJSASTNode>); static;

    constructor Create;
    destructor Destroy; override;
    procedure DetachChildren(const Sink: TList<TJSASTNode>);

    property ReferencesArguments: Boolean read FReferencesArguments write FReferencesArguments;
    property Defaults: TObjectList<TJSExpression> read FDefaults;
    property Patterns: TObjectList<TJSExpression> read FPatterns;
    property Rest: TJSIdentifier read FRest write FRest;
    property RestPattern: TJSExpression read FRestPattern write FRestPattern;
    property BoundNames: TArray<string> read FBoundNames write FBoundNames;
    property ExpectedArgumentCount: Integer read FExpectedArgumentCount write FExpectedArgumentCount;
    property HasDefaults: Boolean read FHasDefaults write FHasDefaults;
    property HasPatterns: Boolean read FHasPatterns write FHasPatterns;
    property NeedsParameterScope: Boolean read GetNeedsParameterScope;
  end;

  TJSFunctionExpression = class(TJSExpression)
  private
    FId: TJSIdentifier;
    FParams: TObjectList<TJSIdentifier>;
    FParameterInfo: TJSParameterInfo;
    FBody: TJSStatement;
    FIsStrict: Boolean;
    FIsArrow: Boolean;
    FIsGenerator: Boolean;
    FIsAsync: Boolean;
    FSourceText: string;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Id: TJSIdentifier read FId write FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property ParameterInfo: TJSParameterInfo read FParameterInfo write FParameterInfo;
    property Body: TJSStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property IsArrow: Boolean read FIsArrow write FIsArrow;
    property IsGenerator: Boolean read FIsGenerator write FIsGenerator;
    property IsAsync: Boolean read FIsAsync write FIsAsync;
    property SourceText: string read FSourceText write FSourceText;
  end;

  TJSUnaryOperator = (
    Minus,
    Plus,
    LogicalNot,
    BitwiseNot,
    TypeOf,
    Void,
    Delete
  );

  TJSUnaryExpression = class(TJSExpression)
  private
    FOperator: TJSUnaryOperator;
    FArgument: TJSExpression;
    FPrefix: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Op: TJSUnaryOperator; const Argument: TJSExpression; const Prefix: Boolean = True);
    destructor Destroy; override;

    property Operator: TJSUnaryOperator read FOperator;
    property Argument: TJSExpression read FArgument;
    property Prefix: Boolean read FPrefix;
  end;

  TJSBinaryOperator = (
    Add,
    Subtract,
    Multiply,
    Divide,
    Modulo,
    Exponent,
    Equal,
    NotEqual,
    StrictEqual,
    StrictNotEqual,
    LessThan,
    LessThanOrEqual,
    GreaterThan,
    GreaterThanOrEqual,
    BitwiseAnd,
    BitwiseOr,
    BitwiseXor,
    LeftShift,
    RightShift,
    UnsignedRightShift,
    InstanceOf,
    In_
  );

  TJSBinaryExpression = class(TJSExpression)
  private
    FOperator: TJSBinaryOperator;
    FLeft: TJSExpression;
    FRight: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Op: TJSBinaryOperator; const Left: TJSExpression; const Right: TJSExpression);
    destructor Destroy; override;
    function ChainChild: TJSExpression; override;

    property Operator: TJSBinaryOperator read FOperator;
    property Left: TJSExpression read FLeft;
    property Right: TJSExpression read FRight;
  end;

  TJSLogicalOperator = (
    And_,
    Or_,
    Nullish
  );

  TJSLogicalExpression = class(TJSExpression)
  private
    FOperator: TJSLogicalOperator;
    FLeft: TJSExpression;
    FRight: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Op: TJSLogicalOperator; const Left: TJSExpression; const Right: TJSExpression);
    destructor Destroy; override;
    function ChainChild: TJSExpression; override;

    property Operator: TJSLogicalOperator read FOperator;
    property Left: TJSExpression read FLeft;
    property Right: TJSExpression read FRight;
  end;

  TJSAssignmentOperator = (
    Assign,
    AddAssign,
    SubtractAssign,
    MultiplyAssign,
    DivideAssign,
    ModuloAssign,
    ExponentAssign,
    BitwiseAndAssign,
    BitwiseOrAssign,
    BitwiseXorAssign,
    LeftShiftAssign,
    RightShiftAssign,
    UnsignedRightShiftAssign
  );

  TJSAssignmentExpression = class(TJSExpression)
  private
    FOperator: TJSAssignmentOperator;
    FLeft: TJSExpression;
    FRight: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Op: TJSAssignmentOperator; const Left: TJSExpression; const Right: TJSExpression);
    destructor Destroy; override;

    function TakeLeft: TJSExpression;
    function TakeRight: TJSExpression;

    property Operator: TJSAssignmentOperator read FOperator;
    property Left: TJSExpression read FLeft;
    property Right: TJSExpression read FRight;
  end;

  TJSUpdateOperator = (
    Increment,
    Decrement
  );

  TJSUpdateExpression = class(TJSExpression)
  private
    FOperator: TJSUpdateOperator;
    FArgument: TJSExpression;
    FPrefix: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Op: TJSUpdateOperator; const Argument: TJSExpression; const Prefix: Boolean);
    destructor Destroy; override;

    property Operator: TJSUpdateOperator read FOperator;
    property Argument: TJSExpression read FArgument;
    property Prefix: Boolean read FPrefix;
  end;

  TJSConditionalExpression = class(TJSExpression)
  private
    FTest: TJSExpression;
    FConsequent: TJSExpression;
    FAlternate: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Test: TJSExpression; const Consequent: TJSExpression; const Alternate: TJSExpression);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Consequent: TJSExpression read FConsequent;
    property Alternate: TJSExpression read FAlternate;
  end;

  TJSCallExpression = class(TJSExpression)
  private
    FCallee: TJSExpression;
    FArguments: TObjectList<TJSExpression>;
    FHasSpread: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Callee: TJSExpression);
    destructor Destroy; override;
    function ChainChild: TJSExpression; override;

    property Callee: TJSExpression read FCallee;
    property Arguments: TObjectList<TJSExpression> read FArguments;
    property HasSpread: Boolean read FHasSpread write FHasSpread;
  end;

  TJSTaggedTemplateExpression = class(TJSCallExpression);

  TJSMemberExpression = class(TJSExpression)
  private
    FObject_: TJSExpression;
    FProperty_: TJSExpression;
    FComputed: Boolean;
    FIsSuper: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Obj: TJSExpression; const Prop: TJSExpression; const Computed: Boolean);
    destructor Destroy; override;
    function ChainChild: TJSExpression; override;

    property Object_: TJSExpression read FObject_;
    property Property_: TJSExpression read FProperty_;
    property Computed: Boolean read FComputed;
    property IsSuper: Boolean read FIsSuper;
  end;

  TJSNewExpression = class(TJSExpression)
  private
    FCallee: TJSExpression;
    FArguments: TObjectList<TJSExpression>;
    FHasSpread: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Callee: TJSExpression);
    destructor Destroy; override;

    property Callee: TJSExpression read FCallee;
    property Arguments: TObjectList<TJSExpression> read FArguments;
    property HasSpread: Boolean read FHasSpread write FHasSpread;
  end;

  TJSSequenceExpression = class(TJSExpression)
  private
    FExpressions: TObjectList<TJSExpression>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Expressions: TObjectList<TJSExpression> read FExpressions;
  end;

  TJSThisExpression = class(TJSExpression)
  public
    constructor Create;
  end;

  TJSSuperExpression = class(TJSExpression)
  public
    constructor Create;
  end;

  TJSNewTargetExpression = class(TJSExpression)
  public
    constructor Create;
  end;

  TJSClassMember = class(TJSASTNode)
  private
    FKey: TJSExpression;
    FValue: TJSFunctionExpression;
    FComputed: Boolean;
    FIsStatic: Boolean;
    FKind: TJSPropertyKind;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Key: TJSExpression; const Value: TJSFunctionExpression; const Computed: Boolean;
                       const IsStatic: Boolean; const Kind: TJSPropertyKind);
    destructor Destroy; override;

    property Key: TJSExpression read FKey;
    property Value: TJSFunctionExpression read FValue;
    property Computed: Boolean read FComputed;
    property IsStatic: Boolean read FIsStatic;
    property Kind: TJSPropertyKind read FKind;
  end;

  TJSClassExpression = class(TJSExpression)
  private
    FId: TJSIdentifier;
    FSuperClass: TJSExpression;
    FConstructor: TJSFunctionExpression;
    FMembers: TObjectList<TJSClassMember>;
    FSourceText: string;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Id: TJSIdentifier read FId write FId;
    property SuperClass: TJSExpression read FSuperClass write FSuperClass;
    property Constructor_: TJSFunctionExpression read FConstructor write FConstructor;
    property Members: TObjectList<TJSClassMember> read FMembers;
    property SourceText: string read FSourceText write FSourceText;
  end;

  TJSYieldExpression = class(TJSExpression)
  private
    FArgument: TJSExpression;
    FIsDelegate: Boolean;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Argument: TJSExpression; const IsDelegate: Boolean);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument;
    property IsDelegate: Boolean read FIsDelegate;
  end;

  TJSAwaitExpression = class(TJSExpression)
  private
    FArgument: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument;
  end;

  TJSTemplatePart = record
    Cooked: string;
    Raw: string;
    HasCooked: Boolean;
  end;

  TJSTemplateParts = class(TJSExpression)
  private
    FParts: TList<TJSTemplatePart>;

  public
    constructor Create(const NodeType: TJSASTNodeType);
    destructor Destroy; override;

    property Parts: TList<TJSTemplatePart> read FParts;
  end;

  TJSTemplateLiteral = class(TJSTemplateParts)
  private
    FExpressions: TObjectList<TJSExpression>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Expressions: TObjectList<TJSExpression> read FExpressions;
  end;

  TJSTemplateObject = class(TJSTemplateParts)
  private
    FCachedObject: IInterface;

  public
    constructor Create;

    property CachedObject: IInterface read FCachedObject write FCachedObject;
  end;

  TJSBlockStatement = class(TJSStatement)
  private
    FBody: TObjectList<TJSStatement>;
    FReferencesArguments: Boolean;
    FDeclaresStrictMode: Boolean;
    FIsFunctionBody: Boolean;
    FIsGeneratorBody: Boolean;
    FIsAsyncBody: Boolean;
    FScopeInfo: TJSScopeInfo;
    FParameterInfo: TJSParameterInfo;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Body: TObjectList<TJSStatement> read FBody;
    property IsGeneratorBody: Boolean read FIsGeneratorBody write FIsGeneratorBody;
    property IsAsyncBody: Boolean read FIsAsyncBody write FIsAsyncBody;
    property ParameterInfo: TJSParameterInfo read FParameterInfo write FParameterInfo;
    property ReferencesArguments: Boolean read FReferencesArguments write FReferencesArguments;
    property DeclaresStrictMode: Boolean read FDeclaresStrictMode write FDeclaresStrictMode;
    property IsFunctionBody: Boolean read FIsFunctionBody write FIsFunctionBody;
    property ScopeInfo: TJSScopeInfo read FScopeInfo write FScopeInfo;
  end;

  TJSVariableDeclarator = class(TJSASTNode)
  private
    FId: TJSIdentifier;
    FPattern: TJSExpression;
    FInit: TJSExpression;
    FBoundNames: TArray<string>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Id: TJSIdentifier; const Init: TJSExpression);
    constructor CreateWithPattern(const Pattern: TJSExpression; const Init: TJSExpression);
    destructor Destroy; override;

    property BoundNames: TArray<string> read FBoundNames;
    property Id: TJSIdentifier read FId;
    property Pattern: TJSExpression read FPattern;
    property Init: TJSExpression read FInit;
  end;

  TJSVariableDeclaration = class(TJSStatement)
  private
    FDeclarations: TObjectList<TJSVariableDeclarator>;
    FKind: TJSDeclarationKind;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create;
    destructor Destroy; override;

    property Declarations: TObjectList<TJSVariableDeclarator> read FDeclarations;
    property Kind: TJSDeclarationKind read FKind write FKind;
  end;

  TJSFunctionDeclaration = class(TJSStatement)
  private
    FId: TJSIdentifier;
    FParams: TObjectList<TJSIdentifier>;
    FParameterInfo: TJSParameterInfo;
    FBody: TJSBlockStatement;
    FIsStrict: Boolean;
    FHoistsToVar: Boolean;
    FIsGenerator: Boolean;
    FIsAsync: Boolean;
    FSourceText: string;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Id: TJSIdentifier);
    destructor Destroy; override;

    property Id: TJSIdentifier read FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property ParameterInfo: TJSParameterInfo read FParameterInfo write FParameterInfo;
    property Body: TJSBlockStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property HoistsToVar: Boolean read FHoistsToVar write FHoistsToVar;
    property IsGenerator: Boolean read FIsGenerator write FIsGenerator;
    property IsAsync: Boolean read FIsAsync write FIsAsync;
    property SourceText: string read FSourceText write FSourceText;
  end;

  TJSExpressionStatement = class(TJSStatement)
  private
    FExpression: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Expression: TJSExpression);
    destructor Destroy; override;

    property Expression: TJSExpression read FExpression;
  end;

  TJSIfStatement = class(TJSStatement)
  private
    FTest: TJSExpression;
    FConsequent: TJSStatement;
    FAlternate: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Test: TJSExpression; const Consequent: TJSStatement; const Alternate: TJSStatement);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Consequent: TJSStatement read FConsequent;
    property Alternate: TJSStatement read FAlternate;
  end;

  TJSWhileStatement = class(TJSStatement)
  private
    FTest: TJSExpression;
    FBody: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Test: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Body: TJSStatement read FBody;
  end;

  TJSWithStatement = class(TJSStatement)
  private
    FTarget: TJSExpression;
    FBody: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Target: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Target: TJSExpression read FTarget;
    property Body: TJSStatement read FBody;
  end;

  TJSDoWhileStatement = class(TJSStatement)
  private
    FTest: TJSExpression;
    FBody: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Body: TJSStatement; const Test: TJSExpression);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Body: TJSStatement read FBody;
  end;

  TJSScopedLoopStatement = class(TJSStatement)
  private
    FMayCaptureScope: Boolean;

  public
    property MayCaptureScope: Boolean read FMayCaptureScope write FMayCaptureScope;
  end;

  TJSForStatement = class(TJSScopedLoopStatement)
  private
    FInit: TJSASTNode;
    FTest: TJSExpression;
    FUpdate: TJSExpression;
    FBody: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Init: TJSASTNode; const Test: TJSExpression; const Update: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Init: TJSASTNode read FInit;
    property Test: TJSExpression read FTest;
    property Update: TJSExpression read FUpdate;
    property Body: TJSStatement read FBody;
  end;

  TJSForInStatement = class(TJSScopedLoopStatement)
  private
    FLeft: TJSASTNode;
    FRight: TJSExpression;
    FBody: TJSStatement;

  protected
    class function LoopNodeType: TJSASTNodeType; virtual;
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Left: TJSASTNode read FLeft;
    property Right: TJSExpression read FRight;
    property Body: TJSStatement read FBody;
  end;

  TJSForOfStatement = class(TJSForInStatement)
  protected
    class function LoopNodeType: TJSASTNodeType; override;
  end;

  TJSReturnStatement = class(TJSStatement)
  private
    FArgument: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument;
  end;

  TJSBreakStatement = class(TJSStatement)
  private
    FLabel: TJSIdentifier;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const LabelId: TJSIdentifier);
    destructor Destroy; override;

    property LabelId: TJSIdentifier read FLabel;
  end;

  TJSContinueStatement = class(TJSStatement)
  private
    FLabel: TJSIdentifier;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const LabelId: TJSIdentifier);
    destructor Destroy; override;

    property LabelId: TJSIdentifier read FLabel;
  end;

  TJSSwitchCase = class(TJSASTNode)
  private
    FTest: TJSExpression;
    FConsequent: TObjectList<TJSStatement>;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Test: TJSExpression);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Consequent: TObjectList<TJSStatement> read FConsequent;
  end;

  TJSSwitchStatement = class(TJSStatement)
  private
    FDiscriminant: TJSExpression;
    FCases: TObjectList<TJSSwitchCase>;
    FScopeInfo: TJSScopeInfo;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Discriminant: TJSExpression);
    destructor Destroy; override;

    property Discriminant: TJSExpression read FDiscriminant;
    property Cases: TObjectList<TJSSwitchCase> read FCases;
    property ScopeInfo: TJSScopeInfo read FScopeInfo write FScopeInfo;
  end;

  TJSThrowStatement = class(TJSStatement)
  private
    FArgument: TJSExpression;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument;
  end;

  TJSCatchClause = class(TJSASTNode)
  private
    FParam: TJSIdentifier;
    FPattern: TJSExpression;
    FBody: TJSBlockStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Param: TJSIdentifier; const Body: TJSBlockStatement);
    constructor CreateWithPattern(const Pattern: TJSExpression; const Body: TJSBlockStatement);
    destructor Destroy; override;

    property Param: TJSIdentifier read FParam;
    property Pattern: TJSExpression read FPattern;
    property Body: TJSBlockStatement read FBody;
  end;

  TJSTryStatement = class(TJSStatement)
  private
    FBlock: TJSBlockStatement;
    FHandler: TJSCatchClause;
    FFinalizer: TJSBlockStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const Block: TJSBlockStatement; const Handler: TJSCatchClause; const Finalizer: TJSBlockStatement);
    destructor Destroy; override;

    property Block: TJSBlockStatement read FBlock;
    property Handler: TJSCatchClause read FHandler;
    property Finalizer: TJSBlockStatement read FFinalizer;
  end;

  TJSLabeledStatement = class(TJSStatement)
  private
    FLabelName: string;
    FBody: TJSStatement;

  protected
    procedure DetachChildren(const Sink: TList<TJSASTNode>); override;

  public
    constructor Create(const LabelName: string; const Body: TJSStatement);
    destructor Destroy; override;

    property LabelName: string read FLabelName;
    property Body: TJSStatement read FBody;
  end;

  TJSEmptyStatement = class(TJSStatement)
  public
    constructor Create;
  end;

  TJSDebuggerStatement = class(TJSStatement)
  public
    constructor Create;
  end;

implementation

{ TJSASTNode }

constructor TJSASTNode.Create(const NodeType: TJSASTNodeType);
begin
  inherited Create;
  FNodeType := NodeType;
  FDispatchType := NodeType;
end;

procedure TJSASTNode.SetIsRemembered(const Value: Boolean);
begin
  FIsRemembered := Value;

  if Value then
    FDispatchType := TJSASTNodeType.Remembered
  else
    FDispatchType := FNodeType;
end;

procedure TJSASTNode.BeforeDestruction;
begin
  inherited;

  if not FIsDetached then
    ReleaseTree(Self);
end;

class procedure TJSASTNode.ReleaseTree(const Root: TJSASTNode);
begin
  const Pending = TList<TJSASTNode>.Create;
  try
    Root.DetachChildren(Pending);

    while Pending.Count > 0 do
    begin
      const LastIndex = Pending.Count - 1;
      const Node = Pending[LastIndex];
      Pending.Delete(LastIndex);

      Node.DetachChildren(Pending);
      Node.FIsDetached := True;
      Node.Free;
    end;
  finally
    Pending.Free;
  end;
end;

procedure TJSASTNode.DetachChildren(const Sink: TList<TJSASTNode>);
begin
end;

class function TJSASTNode.Detach<T>(const Child: T; const Sink: TList<TJSASTNode>): T;
begin
  if Assigned(Child) then
    Sink.Add(Child);

  Result := nil;
end;

class procedure TJSASTNode.DetachAll<T>(const Children: TObjectList<T>; const Sink: TList<TJSASTNode>);
begin
  Children.OwnsObjects := False;
  try
    for var Child in Children do
    begin
      if Assigned(Child) then
        Sink.Add(Child);
    end;

    Children.Clear;
  finally
    Children.OwnsObjects := True;
  end;
end;

{ TJSScopeInfo }

constructor TJSScopeInfo.Create;
begin
  inherited Create;
  FDeclarations := TList<TJSStatement>.Create;
end;

destructor TJSScopeInfo.Destroy;
begin
  FDeclarations.Free;
  inherited;
end;

{ TJSProgram }

constructor TJSProgram.Create;
begin
  inherited Create(TJSASTNodeType.Program_);
  FBody := TObjectList<TJSStatement>.Create(True);
end;

destructor TJSProgram.Destroy;
begin
  FScopeInfo.Free;
  FBody.Free;
  inherited;
end;

procedure TJSProgram.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSStatement>(FBody, Sink);
end;

{ TJSExpression }

procedure TJSExpression.ContinueChain(const Kind: TJSChainKind; const Operand: TJSExpression);
begin
  FChainKind := Kind;

  const IsContinued = (Assigned(Operand) and (Operand.ChainKind = Kind));
  if IsContinued then
    FChainLength := Operand.ChainLength + 1;
end;

function TJSExpression.ChainChild: TJSExpression;
begin
  Result := nil;
end;

{ TJSIdentifier }

constructor TJSIdentifier.Create(const Name: string);
begin
  inherited Create(TJSASTNodeType.Identifier);
  FName := Name;
  FKey := Name;
end;

function TJSIdentifier.GetBindingCache: PJSBindingCache;
begin
  Result := @FBindingCache;
end;

function TJSIdentifier.KeyPointer: PJSPropertyKey;
begin
  Result := @FKey;
end;

{ TJSLiteral }

class function TJSLiteral.CreateUndefined: TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.Undefined;
end;

class function TJSLiteral.CreateNull: TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.Null;
end;

class function TJSLiteral.CreateBoolean(const Value: Boolean): TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.Boolean;
  Result.FBooleanValue := Value;
end;

class function TJSLiteral.CreateNumber(const Value: Double): TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.Number;
  Result.FNumberValue := Value;
end;

class function TJSLiteral.CreateString(const Value: string): TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.String_;
  Result.FStringValue := Value;
end;

class function TJSLiteral.CreateRegExp(const Pattern: string; const Flags: string): TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.RegExp;
  Result.FRegExpPattern := Pattern;
  Result.FRegExpFlags := Flags;
end;

{ TJSArrayExpression }

constructor TJSArrayExpression.Create;
begin
  inherited Create(TJSASTNodeType.ArrayExpression);
  FElements := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSArrayExpression.Destroy;
begin
  FElements.Free;
  inherited;
end;

procedure TJSArrayExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSExpression>(FElements, Sink);
end;

{ TJSAssignmentPattern }

constructor TJSAssignmentPattern.Create(const Target: TJSExpression; const DefaultValue: TJSExpression);
begin
  inherited Create(TJSASTNodeType.AssignmentPattern);
  FTarget := Target;
  FDefaultValue := DefaultValue;
end;

destructor TJSAssignmentPattern.Destroy;
begin
  FDefaultValue.Free;
  FTarget.Free;
  inherited;
end;

procedure TJSAssignmentPattern.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FDefaultValue := Detach(FDefaultValue, Sink);
  FTarget := Detach(FTarget, Sink);
end;

{ TJSArrayPattern }

constructor TJSArrayPattern.Create;
begin
  inherited Create(TJSASTNodeType.ArrayPattern);
  FElements := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSArrayPattern.Destroy;
begin
  FElements.Free;
  inherited;
end;

procedure TJSArrayPattern.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSExpression>(FElements, Sink);
end;

{ TJSObjectPattern }

constructor TJSObjectPattern.Create;
begin
  inherited Create(TJSASTNodeType.ObjectPattern);
  FProperties := TObjectList<TJSObjectProperty>.Create(True);
end;

destructor TJSObjectPattern.Destroy;
begin
  FRest.Free;
  FProperties.Free;
  inherited;
end;

procedure TJSObjectPattern.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FRest := Detach(FRest, Sink);
  DetachAll<TJSObjectProperty>(FProperties, Sink);
end;

{ TJSPatternNames }

class procedure TJSPatternNames.Collect(const Target: TJSASTNode; const Names: TList<string>);
begin
  if not Assigned(Target) then
    Exit;

  case Target.NodeType of
    TJSASTNodeType.Identifier:
      Names.Add(TJSIdentifier(Target).Name);
    TJSASTNodeType.AssignmentPattern:
      Collect(TJSAssignmentPattern(Target).Target, Names);
    TJSASTNodeType.SpreadElement:
      Collect(TJSSpreadElement(Target).Argument, Names);
    TJSASTNodeType.ArrayPattern:
      begin
        for var Element in TJSArrayPattern(Target).Elements do
        begin
          Collect(Element, Names);
        end;
      end;
    TJSASTNodeType.ObjectPattern:
      begin
        for var Prop in TJSObjectPattern(Target).Properties do
        begin
          Collect(Prop.Value, Names);
        end;

        Collect(TJSObjectPattern(Target).Rest, Names);
      end;
  else
    Exit;
  end;
end;

class function TJSPatternNames.NamesOf(const Target: TJSASTNode): TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    Collect(Target, Names);
    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

{ TJSObjectProperty }

constructor TJSObjectProperty.Create(const Key: TJSExpression; const Value: TJSExpression; const Computed: Boolean;
                                     const Kind: TJSPropertyKind);
begin
  inherited Create(TJSASTNodeType.ObjectProperty);
  FKey := Key;
  FValue := Value;
  FComputed := Computed;
  FKind := Kind;
  FSetsPrototype := (Kind = TJSPropertyKind.Data) and (not Computed) and IsPrototypeKey;
end;

class function TJSObjectProperty.KeyName(const Key: TJSExpression): string;
begin
  Result := '';

  if Key is TJSIdentifier then
  begin
    Result := TJSIdentifier(Key).Name;
    Exit;
  end;

  const IsStringKey = (Key is TJSLiteral) and (TJSLiteral(Key).LiteralType = TJSLiteralType.String_);
  if IsStringKey then
    Result := TJSLiteral(Key).StringValue;
end;

function TJSObjectProperty.IsPrototypeKey: Boolean;
begin
  Result := (KeyName(FKey) = PROTOTYPE_ACCESSOR_KEY);
end;

destructor TJSObjectProperty.Destroy;
begin
  FKey.Free;
  FValue.Free;
  inherited;
end;

procedure TJSObjectProperty.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FKey := Detach(FKey, Sink);
  FValue := Detach(FValue, Sink);
end;

{ TJSObjectExpression }

constructor TJSObjectExpression.Create;
begin
  inherited Create(TJSASTNodeType.ObjectExpression);
  FProperties := TObjectList<TJSObjectProperty>.Create(True);
end;

destructor TJSObjectExpression.Destroy;
begin
  FProperties.Free;
  inherited;
end;

procedure TJSObjectExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSObjectProperty>(FProperties, Sink);
end;

{ TJSFunctionExpression }

constructor TJSFunctionExpression.Create;
begin
  inherited Create(TJSASTNodeType.FunctionExpression);
  FParams := TObjectList<TJSIdentifier>.Create(True);
end;

destructor TJSFunctionExpression.Destroy;
begin
  FId.Free;
  FParams.Free;
  FParameterInfo.Free;
  FBody.Free;
  inherited;
end;

procedure TJSFunctionExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FId := Detach(FId, Sink);
  TJSParameterInfo.DetachSignature(FParams, FParameterInfo, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSYieldExpression }

constructor TJSYieldExpression.Create(const Argument: TJSExpression; const IsDelegate: Boolean);
begin
  inherited Create(TJSASTNodeType.YieldExpression);
  FArgument := Argument;
  FIsDelegate := IsDelegate;
end;

destructor TJSYieldExpression.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSYieldExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSAwaitExpression }

constructor TJSAwaitExpression.Create(const Argument: TJSExpression);
begin
  inherited Create(TJSASTNodeType.AwaitExpression);
  FArgument := Argument;
end;

destructor TJSAwaitExpression.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSAwaitExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSSpreadElement }

constructor TJSSpreadElement.Create(const Argument: TJSExpression);
begin
  inherited Create(TJSASTNodeType.SpreadElement);
  FArgument := Argument;
end;

destructor TJSSpreadElement.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSSpreadElement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSParameterInfo }

class procedure TJSParameterInfo.DetachSignature(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo;
                                                 const Sink: TList<TJSASTNode>);
begin
  TJSASTNode.DetachAll<TJSIdentifier>(Params, Sink);

  if Assigned(Info) then
    Info.DetachChildren(Sink);
end;

constructor TJSParameterInfo.Create;
begin
  inherited Create;
  FDefaults := TObjectList<TJSExpression>.Create(True);
  FPatterns := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSParameterInfo.Destroy;
begin
  FDefaults.Free;
  FPatterns.Free;
  FRestPattern.Free;
  FRest.Free;
  inherited;
end;

procedure TJSParameterInfo.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  TJSASTNode.DetachAll<TJSExpression>(FDefaults, Sink);
  TJSASTNode.DetachAll<TJSExpression>(FPatterns, Sink);
  FRestPattern := TJSASTNode.Detach(FRestPattern, Sink);
  FRest := TJSASTNode.Detach(FRest, Sink);
end;

function TJSParameterInfo.GetNeedsParameterScope: Boolean;
begin
  Result := FHasDefaults or FHasPatterns;
end;

{ TJSUnaryExpression }

constructor TJSUnaryExpression.Create(const Op: TJSUnaryOperator; const Argument: TJSExpression; const Prefix: Boolean);
begin
  inherited Create(TJSASTNodeType.UnaryExpression);
  FOperator := Op;
  FArgument := Argument;
  FPrefix := Prefix;
end;

destructor TJSUnaryExpression.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSUnaryExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSBinaryExpression }

constructor TJSBinaryExpression.Create(const Op: TJSBinaryOperator; const Left: TJSExpression; const Right: TJSExpression);
begin
  inherited Create(TJSASTNodeType.BinaryExpression);
  FOperator := Op;
  FLeft := Left;
  FRight := Right;
  ContinueChain(TJSChainKind.Binary, Left);
end;

destructor TJSBinaryExpression.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

procedure TJSBinaryExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLeft := Detach(FLeft, Sink);
  FRight := Detach(FRight, Sink);
end;

function TJSBinaryExpression.ChainChild: TJSExpression;
begin
  Result := FLeft;
end;

{ TJSLogicalExpression }

constructor TJSLogicalExpression.Create(const Op: TJSLogicalOperator; const Left: TJSExpression; const Right: TJSExpression);
begin
  inherited Create(TJSASTNodeType.LogicalExpression);
  FOperator := Op;
  FLeft := Left;
  FRight := Right;
  ContinueChain(TJSChainKind.Logical, Left);
end;

destructor TJSLogicalExpression.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

procedure TJSLogicalExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLeft := Detach(FLeft, Sink);
  FRight := Detach(FRight, Sink);
end;

function TJSLogicalExpression.ChainChild: TJSExpression;
begin
  Result := FLeft;
end;

{ TJSAssignmentExpression }

constructor TJSAssignmentExpression.Create(const Op: TJSAssignmentOperator; const Left: TJSExpression; const Right: TJSExpression);
begin
  inherited Create(TJSASTNodeType.AssignmentExpression);
  FOperator := Op;
  FLeft := Left;
  FRight := Right;
end;

function TJSAssignmentExpression.TakeLeft: TJSExpression;
begin
  Result := FLeft;
  FLeft := nil;
end;

function TJSAssignmentExpression.TakeRight: TJSExpression;
begin
  Result := FRight;
  FRight := nil;
end;

destructor TJSAssignmentExpression.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

procedure TJSAssignmentExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLeft := Detach(FLeft, Sink);
  FRight := Detach(FRight, Sink);
end;

{ TJSUpdateExpression }

constructor TJSUpdateExpression.Create(const Op: TJSUpdateOperator; const Argument: TJSExpression; const Prefix: Boolean);
begin
  inherited Create(TJSASTNodeType.UpdateExpression);
  FOperator := Op;
  FArgument := Argument;
  FPrefix := Prefix;
end;

destructor TJSUpdateExpression.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSUpdateExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSConditionalExpression }

constructor TJSConditionalExpression.Create(const Test: TJSExpression; const Consequent: TJSExpression; const Alternate: TJSExpression);
begin
  inherited Create(TJSASTNodeType.ConditionalExpression);
  FTest := Test;
  FConsequent := Consequent;
  FAlternate := Alternate;
end;

destructor TJSConditionalExpression.Destroy;
begin
  FTest.Free;
  FConsequent.Free;
  FAlternate.Free;
  inherited;
end;

procedure TJSConditionalExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTest := Detach(FTest, Sink);
  FConsequent := Detach(FConsequent, Sink);
  FAlternate := Detach(FAlternate, Sink);
end;

{ TJSCallExpression }

constructor TJSCallExpression.Create(const Callee: TJSExpression);
begin
  inherited Create(TJSASTNodeType.CallExpression);
  FCallee := Callee;
  FArguments := TObjectList<TJSExpression>.Create(True);
  ContinueChain(TJSChainKind.Access, Callee);
end;

destructor TJSCallExpression.Destroy;
begin
  FCallee.Free;
  FArguments.Free;
  inherited;
end;

procedure TJSCallExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FCallee := Detach(FCallee, Sink);
  DetachAll<TJSExpression>(FArguments, Sink);
end;

function TJSCallExpression.ChainChild: TJSExpression;
begin
  Result := FCallee;
end;

{ TJSMemberExpression }

constructor TJSMemberExpression.Create(const Obj: TJSExpression; const Prop: TJSExpression; const Computed: Boolean);
begin
  inherited Create(TJSASTNodeType.MemberExpression);
  FObject_ := Obj;
  FProperty_ := Prop;
  FComputed := Computed;
  FIsSuper := (Obj is TJSSuperExpression);
  ContinueChain(TJSChainKind.Access, Obj);
end;

destructor TJSMemberExpression.Destroy;
begin
  FObject_.Free;
  FProperty_.Free;
  inherited;
end;

procedure TJSMemberExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FObject_ := Detach(FObject_, Sink);
  FProperty_ := Detach(FProperty_, Sink);
end;

function TJSMemberExpression.ChainChild: TJSExpression;
begin
  Result := FObject_;
end;

{ TJSNewExpression }

constructor TJSNewExpression.Create(const Callee: TJSExpression);
begin
  inherited Create(TJSASTNodeType.NewExpression);
  FCallee := Callee;
  FArguments := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSNewExpression.Destroy;
begin
  FCallee.Free;
  FArguments.Free;
  inherited;
end;

procedure TJSNewExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FCallee := Detach(FCallee, Sink);
  DetachAll<TJSExpression>(FArguments, Sink);
end;

{ TJSSequenceExpression }

constructor TJSSequenceExpression.Create;
begin
  inherited Create(TJSASTNodeType.SequenceExpression);
  FExpressions := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSSequenceExpression.Destroy;
begin
  FExpressions.Free;
  inherited;
end;

procedure TJSSequenceExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSExpression>(FExpressions, Sink);
end;

{ TJSThisExpression }

constructor TJSThisExpression.Create;
begin
  inherited Create(TJSASTNodeType.ThisExpression);
end;

{ TJSSuperExpression }

constructor TJSSuperExpression.Create;
begin
  inherited Create(TJSASTNodeType.SuperExpression);
end;

{ TJSNewTargetExpression }

constructor TJSNewTargetExpression.Create;
begin
  inherited Create(TJSASTNodeType.NewTargetExpression);
end;

{ TJSClassMember }

constructor TJSClassMember.Create(const Key: TJSExpression; const Value: TJSFunctionExpression;
                                  const Computed: Boolean; const IsStatic: Boolean; const Kind: TJSPropertyKind);
begin
  inherited Create(TJSASTNodeType.ClassMember);
  FKey := Key;
  FValue := Value;
  FComputed := Computed;
  FIsStatic := IsStatic;
  FKind := Kind;
end;

destructor TJSClassMember.Destroy;
begin
  FKey.Free;
  FValue.Free;
  inherited;
end;

procedure TJSClassMember.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FKey := Detach(FKey, Sink);
  FValue := Detach(FValue, Sink);
end;

{ TJSClassExpression }

constructor TJSClassExpression.Create;
begin
  inherited Create(TJSASTNodeType.ClassExpression);
  FMembers := TObjectList<TJSClassMember>.Create(True);
end;

destructor TJSClassExpression.Destroy;
begin
  FId.Free;
  FSuperClass.Free;
  FConstructor.Free;
  FMembers.Free;
  inherited;
end;

procedure TJSClassExpression.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FId := Detach(FId, Sink);
  FSuperClass := Detach(FSuperClass, Sink);
  FConstructor := Detach(FConstructor, Sink);
  DetachAll<TJSClassMember>(FMembers, Sink);
end;

{ TJSTemplateParts }

constructor TJSTemplateParts.Create(const NodeType: TJSASTNodeType);
begin
  inherited Create(NodeType);
  FParts := TList<TJSTemplatePart>.Create;
end;

destructor TJSTemplateParts.Destroy;
begin
  FParts.Free;
  inherited;
end;

{ TJSTemplateLiteral }

constructor TJSTemplateLiteral.Create;
begin
  inherited Create(TJSASTNodeType.TemplateLiteral);
  FExpressions := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSTemplateLiteral.Destroy;
begin
  FExpressions.Free;
  inherited;
end;

procedure TJSTemplateLiteral.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSExpression>(FExpressions, Sink);
end;

{ TJSTemplateObject }

constructor TJSTemplateObject.Create;
begin
  inherited Create(TJSASTNodeType.TemplateObject);
end;

{ TJSBlockStatement }

constructor TJSBlockStatement.Create;
begin
  inherited Create(TJSASTNodeType.BlockStatement);
  FBody := TObjectList<TJSStatement>.Create(True);
  FReferencesArguments := True;
end;

destructor TJSBlockStatement.Destroy;
begin
  FScopeInfo.Free;
  FBody.Free;
  inherited;
end;

procedure TJSBlockStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSStatement>(FBody, Sink);
end;

{ TJSVariableDeclarator }

constructor TJSVariableDeclarator.Create(const Id: TJSIdentifier; const Init: TJSExpression);
begin
  inherited Create(TJSASTNodeType.VariableDeclaration);
  FId := Id;
  FInit := Init;
  FBoundNames := [Id.Name];
end;

constructor TJSVariableDeclarator.CreateWithPattern(const Pattern: TJSExpression; const Init: TJSExpression);
begin
  inherited Create(TJSASTNodeType.VariableDeclaration);
  FPattern := Pattern;
  FInit := Init;
  FBoundNames := TJSPatternNames.NamesOf(Pattern);
end;

destructor TJSVariableDeclarator.Destroy;
begin
  FId.Free;
  FPattern.Free;
  FInit.Free;
  inherited;
end;

procedure TJSVariableDeclarator.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FId := Detach(FId, Sink);
  FPattern := Detach(FPattern, Sink);
  FInit := Detach(FInit, Sink);
end;

{ TJSVariableDeclaration }

constructor TJSVariableDeclaration.Create;
begin
  inherited Create(TJSASTNodeType.VariableDeclaration);
  FDeclarations := TObjectList<TJSVariableDeclarator>.Create(True);
end;

destructor TJSVariableDeclaration.Destroy;
begin
  FDeclarations.Free;
  inherited;
end;

procedure TJSVariableDeclaration.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  DetachAll<TJSVariableDeclarator>(FDeclarations, Sink);
end;

{ TJSFunctionDeclaration }

constructor TJSFunctionDeclaration.Create(const Id: TJSIdentifier);
begin
  inherited Create(TJSASTNodeType.FunctionDeclaration);
  FId := Id;
  FParams := TObjectList<TJSIdentifier>.Create(True);
end;

destructor TJSFunctionDeclaration.Destroy;
begin
  FId.Free;
  FParams.Free;
  FParameterInfo.Free;
  FBody.Free;
  inherited;
end;

procedure TJSFunctionDeclaration.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FId := Detach(FId, Sink);
  TJSParameterInfo.DetachSignature(FParams, FParameterInfo, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSExpressionStatement }

constructor TJSExpressionStatement.Create(const Expression: TJSExpression);
begin
  inherited Create(TJSASTNodeType.ExpressionStatement);
  FExpression := Expression;
end;

destructor TJSExpressionStatement.Destroy;
begin
  FExpression.Free;
  inherited;
end;

procedure TJSExpressionStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FExpression := Detach(FExpression, Sink);
end;

{ TJSIfStatement }

constructor TJSIfStatement.Create(const Test: TJSExpression; const Consequent: TJSStatement; const Alternate: TJSStatement);
begin
  inherited Create(TJSASTNodeType.IfStatement);
  FTest := Test;
  FConsequent := Consequent;
  FAlternate := Alternate;
end;

destructor TJSIfStatement.Destroy;
begin
  FTest.Free;
  FConsequent.Free;
  FAlternate.Free;
  inherited;
end;

procedure TJSIfStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTest := Detach(FTest, Sink);
  FConsequent := Detach(FConsequent, Sink);
  FAlternate := Detach(FAlternate, Sink);
end;

{ TJSWhileStatement }

constructor TJSWhileStatement.Create(const Test: TJSExpression; const Body: TJSStatement);
begin
  inherited Create(TJSASTNodeType.WhileStatement);
  FTest := Test;
  FBody := Body;
end;

destructor TJSWhileStatement.Destroy;
begin
  FTest.Free;
  FBody.Free;
  inherited;
end;

procedure TJSWhileStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTest := Detach(FTest, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSWithStatement }

constructor TJSWithStatement.Create(const Target: TJSExpression; const Body: TJSStatement);
begin
  inherited Create(TJSASTNodeType.WithStatement);
  FTarget := Target;
  FBody := Body;
end;

destructor TJSWithStatement.Destroy;
begin
  FTarget.Free;
  FBody.Free;
  inherited;
end;

procedure TJSWithStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTarget := Detach(FTarget, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSDoWhileStatement }

constructor TJSDoWhileStatement.Create(const Body: TJSStatement; const Test: TJSExpression);
begin
  inherited Create(TJSASTNodeType.DoWhileStatement);
  FBody := Body;
  FTest := Test;
end;

destructor TJSDoWhileStatement.Destroy;
begin
  FTest.Free;
  FBody.Free;
  inherited;
end;

procedure TJSDoWhileStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTest := Detach(FTest, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSForStatement }

constructor TJSForStatement.Create(const Init: TJSASTNode; const Test: TJSExpression; const Update: TJSExpression; const Body: TJSStatement);
begin
  inherited Create(TJSASTNodeType.ForStatement);
  FInit := Init;
  FTest := Test;
  FUpdate := Update;
  FBody := Body;
end;

destructor TJSForStatement.Destroy;
begin
  FInit.Free;
  FTest.Free;
  FUpdate.Free;
  FBody.Free;
  inherited;
end;

procedure TJSForStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FInit := Detach(FInit, Sink);
  FTest := Detach(FTest, Sink);
  FUpdate := Detach(FUpdate, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSForInStatement }

class function TJSForInStatement.LoopNodeType: TJSASTNodeType;
begin
  Result := TJSASTNodeType.ForInStatement;
end;

constructor TJSForInStatement.Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
begin
  inherited Create(LoopNodeType);
  FLeft := Left;
  FRight := Right;
  FBody := Body;
end;

destructor TJSForInStatement.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  FBody.Free;
  inherited;
end;

procedure TJSForInStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLeft := Detach(FLeft, Sink);
  FRight := Detach(FRight, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSForOfStatement }

class function TJSForOfStatement.LoopNodeType: TJSASTNodeType;
begin
  Result := TJSASTNodeType.ForOfStatement;
end;

{ TJSReturnStatement }

constructor TJSReturnStatement.Create(const Argument: TJSExpression);
begin
  inherited Create(TJSASTNodeType.ReturnStatement);
  FArgument := Argument;
end;

destructor TJSReturnStatement.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSReturnStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSBreakStatement }

constructor TJSBreakStatement.Create(const LabelId: TJSIdentifier);
begin
  inherited Create(TJSASTNodeType.BreakStatement);
  FLabel := LabelId;
end;

destructor TJSBreakStatement.Destroy;
begin
  FLabel.Free;
  inherited;
end;

procedure TJSBreakStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLabel := Detach(FLabel, Sink);
end;

{ TJSContinueStatement }

constructor TJSContinueStatement.Create(const LabelId: TJSIdentifier);
begin
  inherited Create(TJSASTNodeType.ContinueStatement);
  FLabel := LabelId;
end;

destructor TJSContinueStatement.Destroy;
begin
  FLabel.Free;
  inherited;
end;

procedure TJSContinueStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FLabel := Detach(FLabel, Sink);
end;

{ TJSSwitchCase }

constructor TJSSwitchCase.Create(const Test: TJSExpression);
begin
  inherited Create(TJSASTNodeType.SwitchCase);
  FTest := Test;
  FConsequent := TObjectList<TJSStatement>.Create(True);
end;

destructor TJSSwitchCase.Destroy;
begin
  FTest.Free;
  FConsequent.Free;
  inherited;
end;

procedure TJSSwitchCase.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FTest := Detach(FTest, Sink);
  DetachAll<TJSStatement>(FConsequent, Sink);
end;

{ TJSSwitchStatement }

constructor TJSSwitchStatement.Create(const Discriminant: TJSExpression);
begin
  inherited Create(TJSASTNodeType.SwitchStatement);
  FDiscriminant := Discriminant;
  FCases := TObjectList<TJSSwitchCase>.Create(True);
end;

destructor TJSSwitchStatement.Destroy;
begin
  FScopeInfo.Free;
  FDiscriminant.Free;
  FCases.Free;
  inherited;
end;

procedure TJSSwitchStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FDiscriminant := Detach(FDiscriminant, Sink);
  DetachAll<TJSSwitchCase>(FCases, Sink);
end;

{ TJSThrowStatement }

constructor TJSThrowStatement.Create(const Argument: TJSExpression);
begin
  inherited Create(TJSASTNodeType.ThrowStatement);
  FArgument := Argument;
end;

destructor TJSThrowStatement.Destroy;
begin
  FArgument.Free;
  inherited;
end;

procedure TJSThrowStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FArgument := Detach(FArgument, Sink);
end;

{ TJSCatchClause }

constructor TJSCatchClause.Create(const Param: TJSIdentifier; const Body: TJSBlockStatement);
begin
  inherited Create(TJSASTNodeType.TryStatement);
  FParam := Param;
  FBody := Body;
end;

constructor TJSCatchClause.CreateWithPattern(const Pattern: TJSExpression; const Body: TJSBlockStatement);
begin
  inherited Create(TJSASTNodeType.TryStatement);
  FPattern := Pattern;
  FBody := Body;
end;

destructor TJSCatchClause.Destroy;
begin
  FPattern.Free;
  FParam.Free;
  FBody.Free;
  inherited;
end;

procedure TJSCatchClause.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FPattern := Detach(FPattern, Sink);
  FParam := Detach(FParam, Sink);
  FBody := Detach(FBody, Sink);
end;

{ TJSTryStatement }

constructor TJSTryStatement.Create(const Block: TJSBlockStatement; const Handler: TJSCatchClause; const Finalizer: TJSBlockStatement);
begin
  inherited Create(TJSASTNodeType.TryStatement);
  FBlock := Block;
  FHandler := Handler;
  FFinalizer := Finalizer;
end;

destructor TJSTryStatement.Destroy;
begin
  FBlock.Free;
  FHandler.Free;
  FFinalizer.Free;
  inherited;
end;

procedure TJSTryStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FBlock := Detach(FBlock, Sink);
  FHandler := Detach(FHandler, Sink);
  FFinalizer := Detach(FFinalizer, Sink);
end;

{ TJSLabeledStatement }

constructor TJSLabeledStatement.Create(const LabelName: string; const Body: TJSStatement);
begin
  inherited Create(TJSASTNodeType.LabeledStatement);
  FLabelName := LabelName;
  FBody := Body;
end;

destructor TJSLabeledStatement.Destroy;
begin
  FBody.Free;
  inherited;
end;

procedure TJSLabeledStatement.DetachChildren(const Sink: TList<TJSASTNode>);
begin
  FBody := Detach(FBody, Sink);
end;

{ TJSEmptyStatement }

constructor TJSEmptyStatement.Create;
begin
  inherited Create(TJSASTNodeType.EmptyStatement);
end;

{ TJSDebuggerStatement }

constructor TJSDebuggerStatement.Create;
begin
  inherited Create(TJSASTNodeType.DebuggerStatement);
end;

end.
