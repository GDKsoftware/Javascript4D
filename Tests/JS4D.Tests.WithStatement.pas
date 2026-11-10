unit JS4D.Tests.WithStatement;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TWithStatementTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToError(const Source: string; const ErrorName: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure With_ReadsPropertyOfObject;

    [Test]
    procedure With_ReadsPropertyFromPrototypeChain;

    [Test]
    procedure With_UnknownNameFallsBackToOuterScope;

    [Test]
    procedure With_AssignmentToExistingPropertyWritesObject;

    [Test]
    procedure With_AssignmentToUnknownNameWritesOuterVariable;

    [Test]
    procedure With_CompoundAssignmentAndIncrementUseObjectProperty;

    [Test]
    procedure With_VarDeclarationWithInitializerWritesObjectProperty;

    [Test]
    procedure With_VarDeclarationIsHoistedToEnclosingFunction;

    [Test]
    procedure With_MethodCallUsesObjectAsThis;

    [Test]
    procedure With_ClosureKeepsObjectInScope;

    [Test]
    procedure With_PrimitiveIsConvertedToWrapperObject;

    [Test]
    procedure With_BreakAndReturnLeaveObjectScope;

    [Test]
    procedure With_TypeofOfObjectPropertyIsDefined;

    [Test]
    procedure With_NullOrUndefined_ThrowsTypeError;

    [Test]
    procedure With_InStrictMode_IsSyntaxError;

    [Test]
    procedure With_InsideFunctionWithUseStrictDirective_IsSyntaxError;

    [Test]
    procedure With_FunctionDeclarationAsBody_IsSyntaxError;

    [Test]
    procedure With_LetIdentifierFollowedByNewline_IsExpressionStatement;

    [Test]
    procedure With_AssignmentWritesBindingResolvedBeforeRightHandSide;

    [Test]
    procedure With_AssignmentRecreatesPropertyDeletedByRightHandSide;

    [Test]
    procedure With_CompoundAssignmentRecreatesPropertyDeletedByGetter;

    [Test]
    procedure With_IncrementRecreatesPropertyDeletedByGetter;

    [Test]
    procedure Assignment_WritesVariableResolvedBeforeEvalDeclaresShadow;
  end;

implementation

const
  SyntaxErrorName = 'SyntaxError';
  TypeErrorName = 'TypeError';

procedure TWithStatementTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TWithStatementTests.TearDown;
begin
  FEngine.Free;
end;

function TWithStatementTests.EvaluatesToError(const Source: string; const ErrorName: string): Boolean;
begin
  const Script = Format('var name = ""; try { %s } catch (e) { name = e.name; } name', [Source]);

  Result := (FEngine.Evaluate(Script).AsString = ErrorName);
end;

procedure TWithStatementTests.With_ReadsPropertyOfObject;
begin
  Assert.AreEqual(5.0, FEngine.Evaluate('var o = {a: 5}; var r; with (o) { r = a; } r').AsNumber);
end;

procedure TWithStatementTests.With_ReadsPropertyFromPrototypeChain;
begin
  const Script =
    'function P() {} P.prototype.inherited = 7;' + sLineBreak +
    'var o = new P(); var r; with (o) { r = inherited; } r';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_UnknownNameFallsBackToOuterScope;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('var outer = 3; var r; with ({}) { r = outer; } r').AsNumber);
end;

procedure TWithStatementTests.With_AssignmentToExistingPropertyWritesObject;
begin
  const Script = 'var a = 1; var o = {a: 2}; with (o) { a = 9; } o.a * 10 + a';

  Assert.AreEqual(91.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_AssignmentToUnknownNameWritesOuterVariable;
begin
  const Script = 'var x = 1; var o = {}; with (o) { x = 4; } x * 10 + (o.hasOwnProperty("x") ? 1 : 0)';

  Assert.AreEqual(40.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_CompoundAssignmentAndIncrementUseObjectProperty;
begin
  const Script = 'var n = 100; var o = {n: 1}; with (o) { n += 2; n++; } o.n * 1000 + n';

  Assert.AreEqual(4100.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_VarDeclarationWithInitializerWritesObjectProperty;
begin
  const Script = 'var o = {v: 1}; with (o) { var v = 5; } o.v * 10 + (v === undefined ? 1 : 0)';

  Assert.AreEqual(51.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_VarDeclarationIsHoistedToEnclosingFunction;
begin
  const Script =
    'function f() { with ({}) { var hoisted = 2; } return hoisted; }' + sLineBreak +
    'f()';

  Assert.AreEqual(2.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_MethodCallUsesObjectAsThis;
begin
  const Script =
    'var o = {k: 6, get: function() { return this.k; }};' + sLineBreak +
    'var r; with (o) { r = get(); } r';

  Assert.AreEqual(6.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_ClosureKeepsObjectInScope;
begin
  const Script =
    'var f; with ({z: 8}) { f = function() { return z; }; }' + sLineBreak +
    'f()';

  Assert.AreEqual(8.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_PrimitiveIsConvertedToWrapperObject;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('var r; with ("abc") { r = length; } r').AsNumber);
end;

procedure TWithStatementTests.With_BreakAndReturnLeaveObjectScope;
begin
  const Script =
    'var a = 1;' + sLineBreak +
    'function f() { with ({a: 2}) { return a; } }' + sLineBreak +
    'for (var i = 0; i < 1; i++) { with ({a: 3}) { break; } }' + sLineBreak +
    'f() * 10 + a';

  Assert.AreEqual(21.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_TypeofOfObjectPropertyIsDefined;
begin
  const Script = 'var r; with ({q: 1}) { r = typeof q; } r';

  Assert.AreEqual('number', FEngine.Evaluate(Script).AsString);
end;

procedure TWithStatementTests.With_NullOrUndefined_ThrowsTypeError;
begin
  Assert.IsTrue(EvaluatesToError('with (null) { }', TypeErrorName));
  Assert.IsTrue(EvaluatesToError('with (undefined) { }', TypeErrorName));
end;

procedure TWithStatementTests.With_InStrictMode_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToError('eval("\"use strict\"; with ({}) { }");', SyntaxErrorName));
end;

procedure TWithStatementTests.With_InsideFunctionWithUseStrictDirective_IsSyntaxError;
begin
  const Source = 'new Function("\"use strict\"; var o = {}; with (o) { }");';

  Assert.IsTrue(EvaluatesToError(Source, SyntaxErrorName));
end;

procedure TWithStatementTests.With_FunctionDeclarationAsBody_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToError('eval("with ({}) function f() { }");', SyntaxErrorName));
end;

procedure TWithStatementTests.With_LetIdentifierFollowedByNewline_IsExpressionStatement;
begin
  const Script = 'var let = 4; var r; with ({}) let' + sLineBreak + 'r = let; r';

  Assert.AreEqual(4.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_AssignmentWritesBindingResolvedBeforeRightHandSide;
begin
  const Script =
    'var outer = {x: 0}; var inner = {x: 1};' + sLineBreak +
    'with (outer) { with (inner) { x = (delete inner.x, 2); } }' + sLineBreak +
    'inner.x * 10 + outer.x';

  Assert.AreEqual(20.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_AssignmentRecreatesPropertyDeletedByRightHandSide;
begin
  const Script =
    'var x = 0; var scope = {x: 1};' + sLineBreak +
    'with (scope) { x = (delete scope.x, 5); }' + sLineBreak +
    'scope.x * 10 + x';

  Assert.AreEqual(50.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_CompoundAssignmentRecreatesPropertyDeletedByGetter;
begin
  const Script =
    'var x = 0; var scope = { get x() { delete this.x; return 2; } };' + sLineBreak +
    'with (scope) { x *= 3; }' + sLineBreak +
    'scope.x * 10 + x';

  Assert.AreEqual(60.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.With_IncrementRecreatesPropertyDeletedByGetter;
begin
  const Script =
    'var x = 0; var scope = { get x() { delete this.x; return 2; } };' + sLineBreak +
    'with (scope) { x++; }' + sLineBreak +
    'scope.x * 10 + x';

  Assert.AreEqual(30.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TWithStatementTests.Assignment_WritesVariableResolvedBeforeEvalDeclaresShadow;
begin
  const Script =
    'var x = 0;' + sLineBreak +
    'var innerX = (function() { x = (eval("var x = 2;"), 1); return x; })();' + sLineBreak +
    'innerX * 10 + x';

  Assert.AreEqual(21.0, FEngine.Evaluate(Script).AsNumber);
end;

end.
