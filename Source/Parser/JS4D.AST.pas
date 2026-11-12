unit JS4D.AST;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

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
    AssignmentPattern
  );

  TJSASTNode = class
  private
    FNodeType: TJSASTNodeType;
    FLine: Integer;
    FColumn: Integer;

  public
    constructor Create(const NodeType: TJSASTNodeType);

    property NodeType: TJSASTNodeType read FNodeType;
    property Line: Integer read FLine write FLine;
    property Column: Integer read FColumn write FColumn;
  end;

  TJSExpression = class(TJSASTNode)
  private
    FIsParenthesized: Boolean;

  public
    property IsParenthesized: Boolean read FIsParenthesized write FIsParenthesized;
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

  TJSIdentifier = class(TJSExpression)
  private
    FName: string;

  public
    BindingCache: TJSBindingCache;

    constructor Create(const Name: string);

    property Name: string read FName;
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
    FElements: TObjectList<TJSExpression>;
    FHasSpread: Boolean;
    FSpreadFollowedByComma: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    property Elements: TObjectList<TJSExpression> read FElements;
    property HasSpread: Boolean read FHasSpread write FHasSpread;
    property SpreadFollowedByComma: Boolean read FSpreadFollowedByComma write FSpreadFollowedByComma;
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

  public
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
    FSpreadFollowedByComma: Boolean;
    FHasDuplicatePrototype: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    property Properties: TObjectList<TJSObjectProperty> read FProperties;
    property SpreadFollowedByComma: Boolean read FSpreadFollowedByComma write FSpreadFollowedByComma;
    property HasDuplicatePrototype: Boolean read FHasDuplicatePrototype write FHasDuplicatePrototype;
  end;

  TJSSpreadElement = class(TJSExpression)
  private
    FArgument: TJSExpression;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument write FArgument;
  end;

  TJSAssignmentPattern = class(TJSExpression)
  private
    FTarget: TJSExpression;
    FDefault: TJSExpression;

  public
    constructor Create(const Target: TJSExpression; const Default: TJSExpression);
    destructor Destroy; override;

    property Target: TJSExpression read FTarget;
    property Default: TJSExpression read FDefault;
  end;

  TJSArrayPattern = class(TJSExpression)
  private
    FElements: TObjectList<TJSExpression>;

  public
    constructor Create;
    destructor Destroy; override;

    property Elements: TObjectList<TJSExpression> read FElements;
  end;

  TJSObjectPattern = class(TJSExpression)
  private
    FProperties: TObjectList<TJSObjectProperty>;
    FRest: TJSExpression;

  public
    constructor Create;
    destructor Destroy; override;

    property Properties: TObjectList<TJSObjectProperty> read FProperties;
    property Rest: TJSExpression read FRest write FRest;
  end;

  TJSPatternNames = class
  public
    class procedure Collect(const Target: TJSASTNode; const Names: TList<string>); static;
    class function Of_(const Target: TJSASTNode): TArray<string>; static;
  end;

  // Default values and rest parameter of a function. Only created when a function has at least one
  // of them; Defaults has one entry per name in Params, nil where the parameter has no default.
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
    constructor Create;
    destructor Destroy; override;

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
    FSourceText: string;

  public
    constructor Create;
    destructor Destroy; override;

    property Id: TJSIdentifier read FId write FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property ParameterInfo: TJSParameterInfo read FParameterInfo write FParameterInfo;
    property Body: TJSStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property IsArrow: Boolean read FIsArrow write FIsArrow;
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

  public
    constructor Create(const Op: TJSBinaryOperator; const Left: TJSExpression; const Right: TJSExpression);
    destructor Destroy; override;

    property Operator: TJSBinaryOperator read FOperator;
    property Left: TJSExpression read FLeft;
    property Right: TJSExpression read FRight;
  end;

  TJSLogicalOperator = (
    And_,
    Or_
  );

  TJSLogicalExpression = class(TJSExpression)
  private
    FOperator: TJSLogicalOperator;
    FLeft: TJSExpression;
    FRight: TJSExpression;

  public
    constructor Create(const Op: TJSLogicalOperator; const Left: TJSExpression; const Right: TJSExpression);
    destructor Destroy; override;

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

  public
    constructor Create(const Callee: TJSExpression);
    destructor Destroy; override;

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

  public
    constructor Create(const Obj: TJSExpression; const Prop: TJSExpression; const Computed: Boolean);
    destructor Destroy; override;

    property Object_: TJSExpression read FObject_;
    property Property_: TJSExpression read FProperty_;
    property Computed: Boolean read FComputed;
  end;

  TJSNewExpression = class(TJSExpression)
  private
    FCallee: TJSExpression;
    FArguments: TObjectList<TJSExpression>;
    FHasSpread: Boolean;

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

  public
    constructor Create;
    destructor Destroy; override;

    property Expressions: TObjectList<TJSExpression> read FExpressions;
  end;

  TJSThisExpression = class(TJSExpression)
  public
    constructor Create;
  end;

  TJSTemplatePart = record
    Cooked: string;
    Raw: string;
    HasCooked: Boolean;
  end;

  TJSTemplateLiteral = class(TJSExpression)
  private
    FParts: TList<TJSTemplatePart>;
    FExpressions: TObjectList<TJSExpression>;

  public
    constructor Create;
    destructor Destroy; override;

    property Parts: TList<TJSTemplatePart> read FParts;
    property Expressions: TObjectList<TJSExpression> read FExpressions;
  end;

  TJSTemplateObject = class(TJSExpression)
  private
    FParts: TList<TJSTemplatePart>;
    FCachedObject: IInterface;

  public
    constructor Create;
    destructor Destroy; override;

    property Parts: TList<TJSTemplatePart> read FParts;
    property CachedObject: IInterface read FCachedObject write FCachedObject;
  end;

  TJSBlockStatement = class(TJSStatement)
  private
    FBody: TObjectList<TJSStatement>;
    FReferencesArguments: Boolean;
    FDeclaresStrictMode: Boolean;
    FIsFunctionBody: Boolean;
    FScopeInfo: TJSScopeInfo;
    FParameterInfo: TJSParameterInfo;

  public
    constructor Create;
    destructor Destroy; override;

    property Body: TObjectList<TJSStatement> read FBody;
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

  public
    constructor Create(const Id: TJSIdentifier; const Init: TJSExpression);
    constructor CreateWithPattern(const Pattern: TJSExpression; const Init: TJSExpression);
    destructor Destroy; override;

    function BoundNames: TArray<string>;

    property Id: TJSIdentifier read FId;
    property Pattern: TJSExpression read FPattern;
    property Init: TJSExpression read FInit;
  end;

  TJSVariableDeclaration = class(TJSStatement)
  private
    FDeclarations: TObjectList<TJSVariableDeclarator>;
    FKind: TJSDeclarationKind;

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
    FSourceText: string;

  public
    constructor Create(const Id: TJSIdentifier);
    destructor Destroy; override;

    property Id: TJSIdentifier read FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property ParameterInfo: TJSParameterInfo read FParameterInfo write FParameterInfo;
    property Body: TJSBlockStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property HoistsToVar: Boolean read FHoistsToVar write FHoistsToVar;
    property SourceText: string read FSourceText write FSourceText;
  end;

  TJSExpressionStatement = class(TJSStatement)
  private
    FExpression: TJSExpression;

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

  public
    constructor Create(const Body: TJSStatement; const Test: TJSExpression);
    destructor Destroy; override;

    property Test: TJSExpression read FTest;
    property Body: TJSStatement read FBody;
  end;

  TJSForStatement = class(TJSStatement)
  private
    FInit: TJSASTNode;
    FTest: TJSExpression;
    FUpdate: TJSExpression;
    FBody: TJSStatement;
    FMayCaptureScope: Boolean;

  public
    constructor Create(const Init: TJSASTNode; const Test: TJSExpression; const Update: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Init: TJSASTNode read FInit;
    property Test: TJSExpression read FTest;
    property Update: TJSExpression read FUpdate;
    property Body: TJSStatement read FBody;
    property MayCaptureScope: Boolean read FMayCaptureScope write FMayCaptureScope;
  end;

  TJSForInStatement = class(TJSStatement)
  private
    FLeft: TJSASTNode;
    FRight: TJSExpression;
    FBody: TJSStatement;
    FMayCaptureScope: Boolean;

  protected
    constructor CreateOfType(const NodeType: TJSASTNodeType; const Left: TJSASTNode; const Right: TJSExpression;
                             const Body: TJSStatement);

  public
    constructor Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Left: TJSASTNode read FLeft;
    property Right: TJSExpression read FRight;
    property Body: TJSStatement read FBody;
    property MayCaptureScope: Boolean read FMayCaptureScope write FMayCaptureScope;
  end;

  TJSForOfStatement = class(TJSForInStatement)
  public
    constructor Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
  end;

  TJSReturnStatement = class(TJSStatement)
  private
    FArgument: TJSExpression;

  public
    constructor Create(const Argument: TJSExpression);
    destructor Destroy; override;

    property Argument: TJSExpression read FArgument;
  end;

  TJSBreakStatement = class(TJSStatement)
  private
    FLabel: TJSIdentifier;

  public
    constructor Create(const LabelId: TJSIdentifier);
    destructor Destroy; override;

    property LabelId: TJSIdentifier read FLabel;
  end;

  TJSContinueStatement = class(TJSStatement)
  private
    FLabel: TJSIdentifier;

  public
    constructor Create(const LabelId: TJSIdentifier);
    destructor Destroy; override;

    property LabelId: TJSIdentifier read FLabel;
  end;

  TJSSwitchCase = class(TJSASTNode)
  private
    FTest: TJSExpression;
    FConsequent: TObjectList<TJSStatement>;

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

const
  PROTOTYPE_ACCESSOR_KEY = '__proto__';

{ TJSASTNode }

constructor TJSASTNode.Create(const NodeType: TJSASTNodeType);
begin
  inherited Create;
  FNodeType := NodeType;
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

{ TJSIdentifier }

constructor TJSIdentifier.Create(const Name: string);
begin
  inherited Create(TJSASTNodeType.Identifier);
  FName := Name;
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

{ TJSAssignmentPattern }

constructor TJSAssignmentPattern.Create(const Target: TJSExpression; const Default: TJSExpression);
begin
  inherited Create(TJSASTNodeType.AssignmentPattern);
  FTarget := Target;
  FDefault := Default;
end;

destructor TJSAssignmentPattern.Destroy;
begin
  FDefault.Free;
  FTarget.Free;
  inherited;
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

{ TJSPatternNames }

class procedure TJSPatternNames.Collect(const Target: TJSASTNode; const Names: TList<string>);
begin
  if Target = nil then
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
  end;
end;

class function TJSPatternNames.Of_(const Target: TJSASTNode): TArray<string>;
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

function TJSObjectProperty.IsPrototypeKey: Boolean;
begin
  if FKey is TJSIdentifier then
    Exit(TJSIdentifier(FKey).Name = PROTOTYPE_ACCESSOR_KEY);

  const IsStringKey = (FKey is TJSLiteral) and (TJSLiteral(FKey).LiteralType = TJSLiteralType.String_);
  Result := IsStringKey and (TJSLiteral(FKey).StringValue = PROTOTYPE_ACCESSOR_KEY);
end;

destructor TJSObjectProperty.Destroy;
begin
  FKey.Free;
  FValue.Free;
  inherited;
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

{ TJSParameterInfo }

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

{ TJSBinaryExpression }

constructor TJSBinaryExpression.Create(const Op: TJSBinaryOperator; const Left: TJSExpression; const Right: TJSExpression);
begin
  inherited Create(TJSASTNodeType.BinaryExpression);
  FOperator := Op;
  FLeft := Left;
  FRight := Right;
end;

destructor TJSBinaryExpression.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
end;

{ TJSLogicalExpression }

constructor TJSLogicalExpression.Create(const Op: TJSLogicalOperator; const Left: TJSExpression; const Right: TJSExpression);
begin
  inherited Create(TJSASTNodeType.LogicalExpression);
  FOperator := Op;
  FLeft := Left;
  FRight := Right;
end;

destructor TJSLogicalExpression.Destroy;
begin
  FLeft.Free;
  FRight.Free;
  inherited;
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

{ TJSCallExpression }

constructor TJSCallExpression.Create(const Callee: TJSExpression);
begin
  inherited Create(TJSASTNodeType.CallExpression);
  FCallee := Callee;
  FArguments := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSCallExpression.Destroy;
begin
  FCallee.Free;
  FArguments.Free;
  inherited;
end;

{ TJSMemberExpression }

constructor TJSMemberExpression.Create(const Obj: TJSExpression; const Prop: TJSExpression; const Computed: Boolean);
begin
  inherited Create(TJSASTNodeType.MemberExpression);
  FObject_ := Obj;
  FProperty_ := Prop;
  FComputed := Computed;
end;

destructor TJSMemberExpression.Destroy;
begin
  FObject_.Free;
  FProperty_.Free;
  inherited;
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

{ TJSThisExpression }

constructor TJSThisExpression.Create;
begin
  inherited Create(TJSASTNodeType.ThisExpression);
end;

{ TJSTemplateLiteral }

constructor TJSTemplateLiteral.Create;
begin
  inherited Create(TJSASTNodeType.TemplateLiteral);
  FParts := TList<TJSTemplatePart>.Create;
  FExpressions := TObjectList<TJSExpression>.Create(True);
end;

destructor TJSTemplateLiteral.Destroy;
begin
  FExpressions.Free;
  FParts.Free;
  inherited;
end;

{ TJSTemplateObject }

constructor TJSTemplateObject.Create;
begin
  inherited Create(TJSASTNodeType.TemplateObject);
  FParts := TList<TJSTemplatePart>.Create;
end;

destructor TJSTemplateObject.Destroy;
begin
  FParts.Free;
  inherited;
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

{ TJSVariableDeclarator }

constructor TJSVariableDeclarator.Create(const Id: TJSIdentifier; const Init: TJSExpression);
begin
  inherited Create(TJSASTNodeType.VariableDeclaration);
  FId := Id;
  FInit := Init;
end;

constructor TJSVariableDeclarator.CreateWithPattern(const Pattern: TJSExpression; const Init: TJSExpression);
begin
  inherited Create(TJSASTNodeType.VariableDeclaration);
  FPattern := Pattern;
  FInit := Init;
end;

destructor TJSVariableDeclarator.Destroy;
begin
  FId.Free;
  FPattern.Free;
  FInit.Free;
  inherited;
end;

function TJSVariableDeclarator.BoundNames: TArray<string>;
begin
  if Length(FBoundNames) = 0 then
  begin
    if Assigned(FId) then
      FBoundNames := [FId.Name]
    else
      FBoundNames := TJSPatternNames.Of_(FPattern);
  end;

  Result := FBoundNames;
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

{ TJSForInStatement }

constructor TJSForInStatement.Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
begin
  CreateOfType(TJSASTNodeType.ForInStatement, Left, Right, Body);
end;

constructor TJSForInStatement.CreateOfType(const NodeType: TJSASTNodeType; const Left: TJSASTNode;
                                           const Right: TJSExpression; const Body: TJSStatement);
begin
  inherited Create(NodeType);
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

{ TJSForOfStatement }

constructor TJSForOfStatement.Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
begin
  CreateOfType(TJSASTNodeType.ForOfStatement, Left, Right, Body);
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
