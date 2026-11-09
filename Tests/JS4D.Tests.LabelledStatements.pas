unit JS4D.Tests.LabelledStatements;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TLabelledStatementTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOfEval(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Break_WithLabel_LeavesOuterLoop;

    [Test]
    procedure Continue_WithLabel_ContinuesOuterLoop;

    [Test]
    procedure Continue_WithLabelInForLoop_RunsUpdateOfOuterLoop;

    [Test]
    procedure Continue_WithLabelOnWhileDoWhileAndForIn_ContinuesLabelledLoop;

    [Test]
    procedure Break_WithLabelOnBlock_LeavesBlock;

    [Test]
    procedure Break_WithLabelOnIfStatement_LeavesStatement;

    [Test]
    procedure Break_WithLabelInsideSwitch_LeavesLabelledLoop;

    [Test]
    procedure Label_StackedOnOneLoop_EachLabelCanContinueIt;

    [Test]
    procedure Break_WithLabelThroughTryFinally_RunsFinally;

    [Test]
    procedure Label_SameNameInSeparateFunctions_IsAllowed;

    [Test]
    procedure Label_SameNameSequentially_IsAllowed;

    [Test]
    procedure Label_NameSharedWithVariable_DoesNotClash;

    [Test]
    procedure Break_LabelFollowedByLineTerminator_IsPlainBreak;

    [Test]
    [TestCase('UnknownBreakLabel', 'a: for (;;) { break b; }')]
    [TestCase('UnknownContinueLabel', 'a: for (;;) { continue b; }')]
    [TestCase('ContinueLabelOfBlock', 'a: { for (;;) { continue a; } }')]
    [TestCase('DuplicateNestedLabel', 'a: a: ;')]
    [TestCase('DuplicateLabelInside', 'a: { a: ; }')]
    [TestCase('BreakOutsideLoop', 'break;')]
    [TestCase('ContinueOutsideLoop', 'continue;')]
    [TestCase('ContinueInsideSwitchOnly', 'switch (1) { case 1: continue; }')]
    [TestCase('LabelCrossesFunction', 'a: for (;;) { (function () { break a; }); }')]
    [TestCase('BreakInsideFunctionInLoop', 'for (;;) { (function () { break; }); }')]
    [TestCase('ReservedWordAsLabel', 'if: ;')]
    [TestCase('FunctionDeclarationAsBody', 'a: function f() {}')]
    [TestCase('ConstDeclarationAsBody', 'a: const x = 1;')]    procedure Eval_InvalidLabelUsage_IsSyntaxError(const Source: string);
  end;

implementation

const
  SyntaxErrorName = 'SyntaxError';

procedure TLabelledStatementTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TLabelledStatementTests.TearDown;
begin
  FEngine.Free;
end;

function TLabelledStatementTests.ErrorNameOfEval(const Source: string): string;
begin
  const Script = Format('var name = "none"; try { eval("%s"); } catch (e) { name = e.name; } name', [Source]);

  Result := FEngine.Evaluate(Script).AsString;
end;

procedure TLabelledStatementTests.Break_WithLabel_LeavesOuterLoop;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'outer: for (var i = 0; i < 3; i++) {' + sLineBreak +
    '  for (var j = 0; j < 3; j++) {' + sLineBreak +
    '    if (j === 1) break outer;' + sLineBreak +
    '    count++;' + sLineBreak +
    '  }' + sLineBreak +
    '}' + sLineBreak +
    'count * 10 + i';

  Assert.AreEqual(10.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Continue_WithLabel_ContinuesOuterLoop;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'outer: for (var i = 0; i < 3; i++) {' + sLineBreak +
    '  for (var j = 0; j < 3; j++) {' + sLineBreak +
    '    if (j === 1) continue outer;' + sLineBreak +
    '    count++;' + sLineBreak +
    '  }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Continue_WithLabelInForLoop_RunsUpdateOfOuterLoop;
begin
  const Script =
    'var visited = "";' + sLineBreak +
    'outer: for (var i = 0; i < 3; i++) {' + sLineBreak +
    '  visited += i;' + sLineBreak +
    '  while (true) { continue outer; }' + sLineBreak +
    '}' + sLineBreak +
    'visited';

  Assert.AreEqual('012', FEngine.Evaluate(Script).AsString);
end;

procedure TLabelledStatementTests.Continue_WithLabelOnWhileDoWhileAndForIn_ContinuesLabelledLoop;
begin
  const Script =
    'var log = "";' + sLineBreak +
    'var n = 0;' + sLineBreak +
    'w: while (n < 2) { n++; for (;;) { log += "w"; continue w; } }' + sLineBreak +
    'var m = 0;' + sLineBreak +
    'd: do { m++; for (;;) { log += "d"; continue d; } } while (m < 2);' + sLineBreak +
    'f: for (var k in {a: 1, b: 2}) { for (;;) { log += "f"; continue f; } }' + sLineBreak +
    'log';

  Assert.AreEqual('wwddff', FEngine.Evaluate(Script).AsString);
end;

procedure TLabelledStatementTests.Break_WithLabelOnBlock_LeavesBlock;
begin
  const Script =
    'var r = 0;' + sLineBreak +
    'blk: { r = 1; break blk; r = 2; }' + sLineBreak +
    'r';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Break_WithLabelOnIfStatement_LeavesStatement;
begin
  const Script =
    'var r = 0;' + sLineBreak +
    'cond: if (true) { r = 1; break cond; }' + sLineBreak +
    'r + 10';

  Assert.AreEqual(11.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Break_WithLabelInsideSwitch_LeavesLabelledLoop;
begin
  const Script =
    'var r = "";' + sLineBreak +
    'loop: for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  switch (i) {' + sLineBreak +
    '    case 0: r += "a"; break;' + sLineBreak +
    '    case 1: r += "b"; continue loop;' + sLineBreak +
    '    case 2: r += "c"; break loop;' + sLineBreak +
    '  }' + sLineBreak +
    '  r += "-";' + sLineBreak +
    '}' + sLineBreak +
    'r';

  Assert.AreEqual('a-bc', FEngine.Evaluate(Script).AsString);
end;

procedure TLabelledStatementTests.Label_StackedOnOneLoop_EachLabelCanContinueIt;
begin
  const Script =
    'var n = 0;' + sLineBreak +
    'first: second: for (var i = 0; i < 4; i++) {' + sLineBreak +
    '  for (;;) { if (i % 2) continue first; n++; continue second; }' + sLineBreak +
    '}' + sLineBreak +
    'n';

  Assert.AreEqual(2.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Break_WithLabelThroughTryFinally_RunsFinally;
begin
  const Script =
    'var r = "";' + sLineBreak +
    'lbl: try { r += "t"; break lbl; } finally { r += "f"; }' + sLineBreak +
    'r';

  Assert.AreEqual('tf', FEngine.Evaluate(Script).AsString);
end;

procedure TLabelledStatementTests.Label_SameNameInSeparateFunctions_IsAllowed;
begin
  const Script =
    'function f() { a: for (;;) { break a; } return 1; }' + sLineBreak +
    'function g() { a: for (;;) { break a; } return 2; }' + sLineBreak +
    'a: for (;;) { break a; }' + sLineBreak +
    'f() + g()';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Label_SameNameSequentially_IsAllowed;
begin
  Assert.AreEqual('none', ErrorNameOfEval('a: ; a: ;'));
end;

procedure TLabelledStatementTests.Label_NameSharedWithVariable_DoesNotClash;
begin
  const Script =
    'var a = 5;' + sLineBreak +
    'a: while (true) { a++; break a; }' + sLineBreak +
    'a';

  Assert.AreEqual(6.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Break_LabelFollowedByLineTerminator_IsPlainBreak;
begin
  const Script =
    'var r = 0;' + sLineBreak +
    'var a = 7;' + sLineBreak +
    'a: while (true) { break' + sLineBreak +
    'a; }' + sLineBreak +
    'r = 1; r';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLabelledStatementTests.Eval_InvalidLabelUsage_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

end.
