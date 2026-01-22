unit JS4D.Tests.Parser;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.AST,
  JS4D.Parser;

type
  [TestFixture]
  TParserTests = class
  private
    FParser: TJSParser;
    FProgram: TJSProgram;

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Parse_NumberLiteral_CreatesLiteralNode;

    [Test]
    procedure Parse_StringLiteral_CreatesLiteralNode;

    [Test]
    procedure Parse_BinaryExpression_CreatesBinaryNode;

    [Test]
    procedure Parse_VariableDeclaration_CreatesVarNode;

    [Test]
    procedure Parse_FunctionDeclaration_CreatesFunctionNode;

    [Test]
    procedure Parse_IfStatement_CreatesIfNode;

    [Test]
    procedure Parse_WhileStatement_CreatesWhileNode;

    [Test]
    procedure Parse_ForStatement_CreatesForNode;

    [Test]
    procedure Parse_ReturnStatement_CreatesReturnNode;

    [Test]
    procedure Parse_ArrayLiteral_CreatesArrayNode;

    [Test]
    procedure Parse_ObjectLiteral_CreatesObjectNode;

    [Test]
    procedure Parse_FunctionCall_CreatesCallNode;

    [Test]
    procedure Parse_MemberExpression_CreatesMemberNode;

    [Test]
    procedure Parse_AssignmentExpression_CreatesAssignmentNode;

    [Test]
    procedure Parse_ConditionalExpression_CreatesConditionalNode;

    [Test]
    procedure Parse_UnaryExpression_CreatesUnaryNode;

    [Test]
    procedure Parse_UpdateExpression_CreatesUpdateNode;

    [Test]
    procedure Parse_BlockStatement_CreatesBlockNode;

    [Test]
    procedure Parse_TryCatch_CreatesTryNode;

    [Test]
    procedure Parse_SwitchStatement_CreatesSwitchNode;
  end;

implementation

procedure TParserTests.TearDown;
begin
  FProgram.Free;
  FParser.Free;
end;

procedure TParserTests.Parse_NumberLiteral_CreatesLiteralNode;
begin
  FParser := TJSParser.Create('42;');
  FProgram := FParser.Parse;

  Assert.AreEqual(1, Integer(FProgram.Body.Count));

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const Literal = ExprStmt.Expression as TJSLiteral;

  Assert.AreEqual(TJSLiteralType.Number, Literal.LiteralType);
  Assert.AreEqual(Double(42), Literal.NumberValue);
end;

procedure TParserTests.Parse_StringLiteral_CreatesLiteralNode;
begin
  FParser := TJSParser.Create('"Hello";');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const Literal = ExprStmt.Expression as TJSLiteral;

  Assert.AreEqual(TJSLiteralType.String_, Literal.LiteralType);
  Assert.AreEqual('Hello', Literal.StringValue);
end;

procedure TParserTests.Parse_BinaryExpression_CreatesBinaryNode;
begin
  FParser := TJSParser.Create('1 + 2;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const BinaryExpr = ExprStmt.Expression as TJSBinaryExpression;

  Assert.AreEqual(TJSBinaryOperator.Add, BinaryExpr.Operator);
  Assert.IsTrue(BinaryExpr.Left is TJSLiteral);
  Assert.IsTrue(BinaryExpr.Right is TJSLiteral);
end;

procedure TParserTests.Parse_VariableDeclaration_CreatesVarNode;
begin
  FParser := TJSParser.Create('var x = 10;');
  FProgram := FParser.Parse;

  const VarDecl = FProgram.Body[0] as TJSVariableDeclaration;

  Assert.AreEqual(1, Integer(VarDecl.Declarations.Count));
  Assert.AreEqual('x', VarDecl.Declarations[0].Id.Name);
  Assert.IsTrue(VarDecl.Declarations[0].Init is TJSLiteral);
end;

procedure TParserTests.Parse_FunctionDeclaration_CreatesFunctionNode;
begin
  FParser := TJSParser.Create('function add(a, b) { return a + b; }');
  FProgram := FParser.Parse;

  const FuncDecl = FProgram.Body[0] as TJSFunctionDeclaration;

  Assert.AreEqual('add', FuncDecl.Id.Name);
  Assert.AreEqual(2, Integer(FuncDecl.Params.Count));
  Assert.AreEqual('a', FuncDecl.Params[0].Name);
  Assert.AreEqual('b', FuncDecl.Params[1].Name);
  Assert.IsNotNull(FuncDecl.Body);
end;

procedure TParserTests.Parse_IfStatement_CreatesIfNode;
begin
  FParser := TJSParser.Create('if (x > 0) { y = 1; } else { y = 2; }');
  FProgram := FParser.Parse;

  const IfStmt = FProgram.Body[0] as TJSIfStatement;

  Assert.IsNotNull(IfStmt.Test);
  Assert.IsNotNull(IfStmt.Consequent);
  Assert.IsNotNull(IfStmt.Alternate);
end;

procedure TParserTests.Parse_WhileStatement_CreatesWhileNode;
begin
  FParser := TJSParser.Create('while (x > 0) { x--; }');
  FProgram := FParser.Parse;

  const WhileStmt = FProgram.Body[0] as TJSWhileStatement;

  Assert.IsNotNull(WhileStmt.Test);
  Assert.IsNotNull(WhileStmt.Body);
end;

procedure TParserTests.Parse_ForStatement_CreatesForNode;
begin
  FParser := TJSParser.Create('for (var i = 0; i < 10; i++) { sum += i; }');
  FProgram := FParser.Parse;

  const ForStmt = FProgram.Body[0] as TJSForStatement;

  Assert.IsNotNull(ForStmt.Init);
  Assert.IsNotNull(ForStmt.Test);
  Assert.IsNotNull(ForStmt.Update);
  Assert.IsNotNull(ForStmt.Body);
end;

procedure TParserTests.Parse_ReturnStatement_CreatesReturnNode;
begin
  FParser := TJSParser.Create('function f() { return 42; }');
  FProgram := FParser.Parse;

  const FuncDecl = FProgram.Body[0] as TJSFunctionDeclaration;
  const ReturnStmt = FuncDecl.Body.Body[0] as TJSReturnStatement;

  Assert.IsNotNull(ReturnStmt.Argument);
  Assert.IsTrue(ReturnStmt.Argument is TJSLiteral);
end;

procedure TParserTests.Parse_ArrayLiteral_CreatesArrayNode;
begin
  FParser := TJSParser.Create('[1, 2, 3];');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const ArrayExpr = ExprStmt.Expression as TJSArrayExpression;

  Assert.AreEqual(3, Integer(ArrayExpr.Elements.Count));
end;

procedure TParserTests.Parse_ObjectLiteral_CreatesObjectNode;
begin
  FParser := TJSParser.Create('var obj = { x: 1, y: 2 };');
  FProgram := FParser.Parse;

  const VarDecl = FProgram.Body[0] as TJSVariableDeclaration;
  const ObjectExpr = VarDecl.Declarations[0].Init as TJSObjectExpression;

  Assert.AreEqual(2, Integer(ObjectExpr.Properties.Count));
end;

procedure TParserTests.Parse_FunctionCall_CreatesCallNode;
begin
  FParser := TJSParser.Create('add(1, 2);');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const CallExpr = ExprStmt.Expression as TJSCallExpression;

  Assert.IsTrue(CallExpr.Callee is TJSIdentifier);
  Assert.AreEqual(2, Integer(CallExpr.Arguments.Count));
end;

procedure TParserTests.Parse_MemberExpression_CreatesMemberNode;
begin
  FParser := TJSParser.Create('obj.property;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const MemberExpr = ExprStmt.Expression as TJSMemberExpression;

  Assert.IsTrue(MemberExpr.Object_ is TJSIdentifier);
  Assert.IsTrue(MemberExpr.Property_ is TJSIdentifier);
  Assert.IsFalse(MemberExpr.Computed);
end;

procedure TParserTests.Parse_AssignmentExpression_CreatesAssignmentNode;
begin
  FParser := TJSParser.Create('x = 10;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const AssignExpr = ExprStmt.Expression as TJSAssignmentExpression;

  Assert.AreEqual(TJSAssignmentOperator.Assign, AssignExpr.Operator);
  Assert.IsTrue(AssignExpr.Left is TJSIdentifier);
  Assert.IsTrue(AssignExpr.Right is TJSLiteral);
end;

procedure TParserTests.Parse_ConditionalExpression_CreatesConditionalNode;
begin
  FParser := TJSParser.Create('x > 0 ? 1 : 0;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const CondExpr = ExprStmt.Expression as TJSConditionalExpression;

  Assert.IsNotNull(CondExpr.Test);
  Assert.IsNotNull(CondExpr.Consequent);
  Assert.IsNotNull(CondExpr.Alternate);
end;

procedure TParserTests.Parse_UnaryExpression_CreatesUnaryNode;
begin
  FParser := TJSParser.Create('-x;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const UnaryExpr = ExprStmt.Expression as TJSUnaryExpression;

  Assert.AreEqual(TJSUnaryOperator.Minus, UnaryExpr.Operator);
  Assert.IsTrue(UnaryExpr.Prefix);
end;

procedure TParserTests.Parse_UpdateExpression_CreatesUpdateNode;
begin
  FParser := TJSParser.Create('x++;');
  FProgram := FParser.Parse;

  const ExprStmt = FProgram.Body[0] as TJSExpressionStatement;
  const UpdateExpr = ExprStmt.Expression as TJSUpdateExpression;

  Assert.AreEqual(TJSUpdateOperator.Increment, UpdateExpr.Operator);
  Assert.IsFalse(UpdateExpr.Prefix);
end;

procedure TParserTests.Parse_BlockStatement_CreatesBlockNode;
begin
  FParser := TJSParser.Create('{ x = 1; y = 2; }');
  FProgram := FParser.Parse;

  const BlockStmt = FProgram.Body[0] as TJSBlockStatement;

  Assert.AreEqual(2, Integer(BlockStmt.Body.Count));
end;

procedure TParserTests.Parse_TryCatch_CreatesTryNode;
begin
  FParser := TJSParser.Create('try { x = 1; } catch (e) { y = 2; }');
  FProgram := FParser.Parse;

  const TryStmt = FProgram.Body[0] as TJSTryStatement;

  Assert.IsNotNull(TryStmt.Block);
  Assert.IsNotNull(TryStmt.Handler);
  Assert.AreEqual('e', TryStmt.Handler.Param.Name);
end;

procedure TParserTests.Parse_SwitchStatement_CreatesSwitchNode;
begin
  FParser := TJSParser.Create('switch (x) { case 1: y = 1; break; default: y = 0; }');
  FProgram := FParser.Parse;

  const SwitchStmt = FProgram.Body[0] as TJSSwitchStatement;

  Assert.IsNotNull(SwitchStmt.Discriminant);
  Assert.AreEqual(2, Integer(SwitchStmt.Cases.Count));
end;

initialization
  TDUnitX.RegisterTestFixture(TParserTests);

end.
