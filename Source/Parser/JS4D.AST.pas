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
    ReturnStatement,
    BreakStatement,
    ContinueStatement,
    SwitchStatement,
    SwitchCase,
    ThrowStatement,
    TryStatement,
    EmptyStatement,
    WithStatement,
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
    ThisExpression
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

  TJSExpression = class(TJSASTNode);

  TJSStatement = class(TJSASTNode);

  TJSProgram = class(TJSASTNode)
  private
    FBody: TObjectList<TJSStatement>;
    FIsStrict: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    property Body: TObjectList<TJSStatement> read FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
  end;

  TJSIdentifier = class(TJSExpression)
  private
    FName: string;

  public
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
    FIsOctal: Boolean;

  public
    class function CreateUndefined: TJSLiteral;
    class function CreateNull: TJSLiteral;
    class function CreateBoolean(const Value: Boolean): TJSLiteral;
    class function CreateNumber(const Value: Double): TJSLiteral;
    class function CreateOctalNumber(const Value: Double): TJSLiteral;
    class function CreateString(const Value: string): TJSLiteral;
    class function CreateRegExp(const Pattern: string; const Flags: string): TJSLiteral;

    property LiteralType: TJSLiteralType read FLiteralType;
    property BooleanValue: Boolean read FBooleanValue;
    property NumberValue: Double read FNumberValue;
    property StringValue: string read FStringValue;
    property RegExpPattern: string read FRegExpPattern;
    property RegExpFlags: string read FRegExpFlags;
    property IsOctal: Boolean read FIsOctal;
  end;

  TJSArrayExpression = class(TJSExpression)
  private
    FElements: TObjectList<TJSExpression>;

  public
    constructor Create;
    destructor Destroy; override;

    property Elements: TObjectList<TJSExpression> read FElements;
  end;

  TJSObjectProperty = class(TJSASTNode)
  private
    FKey: TJSExpression;
    FValue: TJSExpression;
    FComputed: Boolean;

  public
    constructor Create(const Key: TJSExpression; const Value: TJSExpression; const Computed: Boolean = False);
    destructor Destroy; override;

    property Key: TJSExpression read FKey;
    property Value: TJSExpression read FValue;
    property Computed: Boolean read FComputed;
  end;

  TJSObjectExpression = class(TJSExpression)
  private
    FProperties: TObjectList<TJSObjectProperty>;

  public
    constructor Create;
    destructor Destroy; override;

    property Properties: TObjectList<TJSObjectProperty> read FProperties;
  end;

  TJSFunctionExpression = class(TJSExpression)
  private
    FId: TJSIdentifier;
    FParams: TObjectList<TJSIdentifier>;
    FBody: TJSStatement;
    FIsStrict: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    property Id: TJSIdentifier read FId write FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property Body: TJSStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
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

  public
    constructor Create(const Callee: TJSExpression);
    destructor Destroy; override;

    property Callee: TJSExpression read FCallee;
    property Arguments: TObjectList<TJSExpression> read FArguments;
  end;

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

  public
    constructor Create(const Callee: TJSExpression);
    destructor Destroy; override;

    property Callee: TJSExpression read FCallee;
    property Arguments: TObjectList<TJSExpression> read FArguments;
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

  TJSBlockStatement = class(TJSStatement)
  private
    FBody: TObjectList<TJSStatement>;

  public
    constructor Create;
    destructor Destroy; override;

    property Body: TObjectList<TJSStatement> read FBody;
  end;

  TJSVariableDeclarator = class(TJSASTNode)
  private
    FId: TJSIdentifier;
    FInit: TJSExpression;

  public
    constructor Create(const Id: TJSIdentifier; const Init: TJSExpression);
    destructor Destroy; override;

    property Id: TJSIdentifier read FId;
    property Init: TJSExpression read FInit;
  end;

  TJSVariableDeclaration = class(TJSStatement)
  private
    FDeclarations: TObjectList<TJSVariableDeclarator>;

  public
    constructor Create;
    destructor Destroy; override;

    property Declarations: TObjectList<TJSVariableDeclarator> read FDeclarations;
  end;

  TJSFunctionDeclaration = class(TJSStatement)
  private
    FId: TJSIdentifier;
    FParams: TObjectList<TJSIdentifier>;
    FBody: TJSBlockStatement;
    FIsStrict: Boolean;

  public
    constructor Create(const Id: TJSIdentifier);
    destructor Destroy; override;

    property Id: TJSIdentifier read FId;
    property Params: TObjectList<TJSIdentifier> read FParams;
    property Body: TJSBlockStatement read FBody write FBody;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
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

  public
    constructor Create(const Init: TJSASTNode; const Test: TJSExpression; const Update: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Init: TJSASTNode read FInit;
    property Test: TJSExpression read FTest;
    property Update: TJSExpression read FUpdate;
    property Body: TJSStatement read FBody;
  end;

  TJSForInStatement = class(TJSStatement)
  private
    FLeft: TJSASTNode;
    FRight: TJSExpression;
    FBody: TJSStatement;

  public
    constructor Create(const Left: TJSASTNode; const Right: TJSExpression; const Body: TJSStatement);
    destructor Destroy; override;

    property Left: TJSASTNode read FLeft;
    property Right: TJSExpression read FRight;
    property Body: TJSStatement read FBody;
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

  public
    constructor Create(const Discriminant: TJSExpression);
    destructor Destroy; override;

    property Discriminant: TJSExpression read FDiscriminant;
    property Cases: TObjectList<TJSSwitchCase> read FCases;
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
    FBody: TJSBlockStatement;

  public
    constructor Create(const Param: TJSIdentifier; const Body: TJSBlockStatement);
    destructor Destroy; override;

    property Param: TJSIdentifier read FParam;
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
end;

{ TJSProgram }

constructor TJSProgram.Create;
begin
  inherited Create(TJSASTNodeType.Program_);
  FBody := TObjectList<TJSStatement>.Create(True);
end;

destructor TJSProgram.Destroy;
begin
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
  Result.FIsOctal := False;
end;

class function TJSLiteral.CreateOctalNumber(const Value: Double): TJSLiteral;
begin
  Result := TJSLiteral.Create(TJSASTNodeType.Literal);
  Result.FLiteralType := TJSLiteralType.Number;
  Result.FNumberValue := Value;
  Result.FIsOctal := True;
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

{ TJSObjectProperty }

constructor TJSObjectProperty.Create(const Key: TJSExpression; const Value: TJSExpression; const Computed: Boolean);
begin
  inherited Create(TJSASTNodeType.ObjectProperty);
  FKey := Key;
  FValue := Value;
  FComputed := Computed;
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
  FBody.Free;
  inherited;
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

{ TJSBlockStatement }

constructor TJSBlockStatement.Create;
begin
  inherited Create(TJSASTNodeType.BlockStatement);
  FBody := TObjectList<TJSStatement>.Create(True);
end;

destructor TJSBlockStatement.Destroy;
begin
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

destructor TJSVariableDeclarator.Destroy;
begin
  FId.Free;
  FInit.Free;
  inherited;
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
  inherited Create(TJSASTNodeType.ForInStatement);
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

destructor TJSCatchClause.Destroy;
begin
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
