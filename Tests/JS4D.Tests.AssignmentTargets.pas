unit JS4D.Tests.AssignmentTargets;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TAssignmentTargetsTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToSyntaxError(const Source: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Literal', '1 = 1')]
    [TestCase('This', 'this = 1')]
    [TestCase('Binary', 'a + b = 1')]
    [TestCase('Unary', 'void 1 = 1')]
    [TestCase('Logical', 'a && b = 1')]
    [TestCase('Parenthesized binary', '(a + b) = 1')]
    [TestCase('Parenthesized assignment', '(a = 1) = 2')]
    [TestCase('Postfix update', 'a++ = 1')]
    [TestCase('Prefix update', '++a = 1')]
    [TestCase('Object literal', '({}) = 1')]
    [TestCase('Function expression', '(function() {}) = 1')]
    [TestCase('New expression', 'new a = 1')]
    [TestCase('Compound literal', '1 += 1')]
    [TestCase('Compound binary', 'a + b *= 1')]
    [TestCase('Compound unary', 'typeof a >>>= 1')]
    [TestCase('Compound parenthesized binary', '(a + b) -= 1')]
    [TestCase('Literal postfix', '1++')]
    [TestCase('Literal prefix', '--1')]
    [TestCase('Binary postfix', '(a + b)++')]
    [TestCase('Unary prefix', '++(-a)')]
    [TestCase('Postfix this', 'this++')]
    [TestCase('For in literal', 'for (1 in {}) {}')]
    [TestCase('For in binary', 'for (a + b in {}) {}')]
    [TestCase('For in this', 'for (this in {}) {}')]
    [TestCase('Strict call assignment', '"use strict"; function f() {} f() = 1')]
    [TestCase('Strict call compound', '"use strict"; function f() {} f() += 1')]
    [TestCase('Strict call postfix', '"use strict"; function f() {} f()++')]
    [TestCase('Strict call for in', '"use strict"; function f() {} for (f() in {}) {}')]
    procedure Source_WithInvalidAssignmentTarget_IsSyntaxError(const Source: string);

    [Test]
    procedure Assignment_ToSequenceTarget_IsSyntaxError;

    [Test]
    [TestCase('Identifier', 'var a; a = 1')]
    [TestCase('Parenthesized identifier', 'var a; (a) = 1')]
    [TestCase('Double parenthesized identifier', 'var a; ((a)) = 1')]
    [TestCase('Member', 'var a = {}; a.b = 1')]
    [TestCase('Computed member', 'var a = []; a[0] = 1')]
    [TestCase('Parenthesized member', 'var a = {}; (a.b) = 1')]
    [TestCase('Compound', 'var a = 1; a += 1')]
    [TestCase('Postfix', 'var a = 1; a++')]
    [TestCase('Prefix on member', 'var a = {b: 1}; ++a.b')]
    [TestCase('Conditional with assignment inside', 'var a, b; true ? a = 1 : b = 2')]
    [TestCase('For in identifier', 'var k; for (k in {x: 1}) {}')]
    [TestCase('For in member', 'var o = {}; for (o.k in {x: 1}) {}')]
    procedure Assignment_ToReference_IsAccepted(const Source: string);

    [Test]
    procedure Assignment_ToCallResult_ThrowsReferenceErrorAtRuntime;

    [Test]
    procedure ForIn_WithIdentifierTarget_EnumeratesKeys;

    [Test]
    procedure ForInit_InOperatorInsideParentheses_IsRelationalOperator;

    [Test]
    procedure ForInit_InOperatorInsideBrackets_IsRelationalOperator;

    [Test]
    procedure ForInit_InOperatorInsideFunctionBody_IsRelationalOperator;

    [Test]
    procedure Assignment_ToNonReferenceInsideEval_ThrowsSyntaxErrorCatchableByScript;
  end;

implementation

procedure TAssignmentTargetsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TAssignmentTargetsTests.TearDown;
begin
  FEngine.Free;
end;

function TAssignmentTargetsTests.EvaluatesToSyntaxError(const Source: string): Boolean;
begin
  const Escaped = Source.Replace('"', '\"');
  const Wrapper = Format('var caught = false; try { eval("%s"); } catch (e) { caught = e instanceof SyntaxError; }',
                         [Escaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsBoolean;
end;

procedure TAssignmentTargetsTests.Source_WithInvalidAssignmentTarget_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TAssignmentTargetsTests.Assignment_ToSequenceTarget_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('var a, b; (a, b) = 1'));
end;

procedure TAssignmentTargetsTests.Assignment_ToReference_IsAccepted(const Source: string);
begin
  Assert.IsFalse(EvaluatesToSyntaxError(Source));
end;

procedure TAssignmentTargetsTests.Assignment_ToCallResult_ThrowsReferenceErrorAtRuntime;
begin
  FEngine.Execute('var caught = ""; function f() { return 1; } try { f() = 1; } catch (e) { caught = e.name; }');

  Assert.AreEqual('ReferenceError', FEngine.Evaluate('caught').AsString);
end;

procedure TAssignmentTargetsTests.ForIn_WithIdentifierTarget_EnumeratesKeys;
begin
  FEngine.Execute('var k; var keys = ""; for (k in {a: 1, b: 2}) { keys += k; }');

  Assert.AreEqual('ab', FEngine.Evaluate('keys').AsString);
end;

procedure TAssignmentTargetsTests.ForInit_InOperatorInsideParentheses_IsRelationalOperator;
begin
  FEngine.Execute('var n = 0; for (var i = ("a" in {a: 1}) ? 1 : 0; i < 3; i++) { n++; }');

  Assert.AreEqual(2.0, FEngine.Evaluate('n').AsNumber);
end;

procedure TAssignmentTargetsTests.ForInit_InOperatorInsideBrackets_IsRelationalOperator;
begin
  FEngine.Execute('var n = 0; var t = [true, false]; for (var i = t["a" in {a: 1} ? 0 : 1] ? 1 : 3; i < 3; i++) { n++; }');

  Assert.AreEqual(2.0, FEngine.Evaluate('n').AsNumber);
end;

procedure TAssignmentTargetsTests.ForInit_InOperatorInsideFunctionBody_IsRelationalOperator;
begin
  FEngine.Execute('var n = 0; for (var f = function() { return "a" in {a: 1}; }; n < 1; n++) { }');

  Assert.AreEqual(1.0, FEngine.Evaluate('n').AsNumber);
end;

procedure TAssignmentTargetsTests.Assignment_ToNonReferenceInsideEval_ThrowsSyntaxErrorCatchableByScript;
begin
  FEngine.Execute('var reached = false; try { eval("1 = 1; reached = true;"); } catch (e) { }');

  Assert.IsFalse(FEngine.Evaluate('reached').AsBoolean);
end;

end.
