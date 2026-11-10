unit JS4D.Tests.SlashContext;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  [TestFixture]
  TSlashContextTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('AfterBlock', 'var r = "no"; {}/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterNonEmptyBlock', 'var r = "no"; { r = "a"; }/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterNestedBlock', 'var r = "no"; { {} }/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterBlockOnNextLine', 'var r = "no"; {}' + #10 + '/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterIfBlock', 'var r = "no"; if (true) {}/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterElseBlock', 'var r = "no"; if (false) {} else {}/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterTryBlocks', 'var r = "no"; try {} catch (e) {} finally {}/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterFunctionDeclaration', 'var r = "no"; function f() {}/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterFunctionDeclarationInBlock', 'var r = "no"; { function f() {} }/1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterIfCondition', 'var r = "no"; if (true) /1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterWhileCondition', 'var r = "no"; var n = 0; while (n++ < 1) /1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterForHead', 'var r = "no"; for (var i = 0; i < 1; i++) /1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterForInHead', 'var r = "no"; for (var k in {a: 1}) /1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('AfterWithHead', 'var r = "no"; with ({}) /1/.test("1") && (r = "yes"); r|yes', '|')]
    [TestCase('InsideEval', 'var r = "no"; eval("{}/1/.test(\"1\") && (r = \"yes\")"); r|yes', '|')]
    procedure Regex_AfterStatementEnd(const Source: string; const Expected: string);

    [Test]
    [TestCase('ObjectLiteralMember', 'var o = {a: 8}.a / 2 / 2; o|2', '|')]
    [TestCase('ObjectLiteralInParens', '({a: 6}).a / 2 / 1|3', '|')]
    [TestCase('ObjectLiteralInArray', '[{a: 6}][0].a / 2 / 1|3', '|')]
    [TestCase('FunctionExpressionAssigned', 'var f = function () { return 6; } / 2; String(f)|NaN', '|')]
    [TestCase('FunctionExpressionInvoked', '(function () { return 6; })() / 2 / 1|3', '|')]
    [TestCase('FunctionExpressionInArgument', 'function id(x) { return x; } id(function () {} / 2) + ""|NaN', '|')]
    [TestCase('AfterReturnedObject', 'function f() { return {a: 6}.a / 2 / 1; } f()|3', '|')]
    [TestCase('AfterCallResult', 'function g() { return 6; } g() / 2 / 1|3', '|')]
    [TestCase('AfterParenthesizedIf', 'var x = 4; (x) / 2 / 1|2', '|')]
    [TestCase('AfterIncrement', 'var x = 4; x++ / 2 / 1|2', '|')]
    [TestCase('AfterBlockThenIdentifier', 'var x = 4; { x = 8; } x / 2 / 1|4', '|')]
    [TestCase('AfterTemplateSubstitution', '`${ {a: 6}.a / 2 / 1 }`|3', '|')]
    procedure Division_AfterExpressionEnd(const Source: string; const Expected: string);
  end;

implementation

procedure TSlashContextTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TSlashContextTests.TearDown;
begin
  FEngine.Free;
end;

procedure TSlashContextTests.Regex_AfterStatementEnd(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TSlashContextTests.Division_AfterExpressionEnd(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

end.
