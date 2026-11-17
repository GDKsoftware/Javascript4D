unit JS4D.Tests.LabelledStatements;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TLabelledStatementTests = class(TJSEngineTestCase)
  public
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
    [TestCase('FunctionDeclarationAsBodyInStrictMode', '''use strict''; a: function f() {}')]
    [TestCase('FunctionDeclarationAsLoopBodyLabel', 'while (false) a: function f() {}')]
    [TestCase('ConstDeclarationAsBody', 'a: const x = 1;')]
    procedure Eval_InvalidLabelUsage_IsSyntaxError(const Source: string);
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

const
  RESULT_ZERO = 'var r = 0;';
  OUTER_LOOP_HEAD = 'outer: for (var i = 0; i < 3; i++) {';
  RESULT_EMPTY_TEXT = 'var r = "";';
  COUNTER_ZERO = 'var n = 0;';
  COUNT_ZERO = 'var count = 0;';
  INNER_LOOP_HEAD = '  for (var j = 0; j < 3; j++) {';

procedure TLabelledStatementTests.Break_WithLabel_LeavesOuterLoop;
begin
  const Script =
    COUNT_ZERO + sLineBreak +
    OUTER_LOOP_HEAD + sLineBreak +
    INNER_LOOP_HEAD + sLineBreak +
    '    if (j === 1) break outer;' + sLineBreak +
    '    count++;' + sLineBreak +
    '  }' + sLineBreak +
    '}' + sLineBreak +
    'count * 10 + i';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(10.0, Actual);
end;

procedure TLabelledStatementTests.Continue_WithLabel_ContinuesOuterLoop;
begin
  const Script =
    COUNT_ZERO + sLineBreak +
    OUTER_LOOP_HEAD + sLineBreak +
    INNER_LOOP_HEAD + sLineBreak +
    '    if (j === 1) continue outer;' + sLineBreak +
    '    count++;' + sLineBreak +
    '  }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(3.0, Actual);
end;

procedure TLabelledStatementTests.Continue_WithLabelInForLoop_RunsUpdateOfOuterLoop;
begin
  const Script =
    'var visited = "";' + sLineBreak +
    OUTER_LOOP_HEAD + sLineBreak +
    '  visited += i;' + sLineBreak +
    '  while (true) { continue outer; }' + sLineBreak +
    '}' + sLineBreak +
    'visited';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('012', Actual);
end;

procedure TLabelledStatementTests.Continue_WithLabelOnWhileDoWhileAndForIn_ContinuesLabelledLoop;
begin
  const Script =
    'var log = "";' + sLineBreak +
    COUNTER_ZERO + sLineBreak +
    'w: while (n < 2) { n++; for (;;) { log += "w"; continue w; } }' + sLineBreak +
    'var m = 0;' + sLineBreak +
    'd: do { m++; for (;;) { log += "d"; continue d; } } while (m < 2);' + sLineBreak +
    'f: for (var k in {a: 1, b: 2}) { for (;;) { log += "f"; continue f; } }' + sLineBreak +
    'log';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('wwddff', Actual);
end;

procedure TLabelledStatementTests.Break_WithLabelOnBlock_LeavesBlock;
begin
  const Script =
    RESULT_ZERO + sLineBreak +
    'blk: { r = 1; break blk; r = 2; }' + sLineBreak +
    'r';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TLabelledStatementTests.Break_WithLabelOnIfStatement_LeavesStatement;
begin
  const Script =
    RESULT_ZERO + sLineBreak +
    'cond: if (true) { r = 1; break cond; }' + sLineBreak +
    'r + 10';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(11.0, Actual);
end;

procedure TLabelledStatementTests.Break_WithLabelInsideSwitch_LeavesLabelledLoop;
begin
  const Script =
    RESULT_EMPTY_TEXT + sLineBreak +
    'loop: for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  switch (i) {' + sLineBreak +
    '    case 0: r += "a"; break;' + sLineBreak +
    '    case 1: r += "b"; continue loop;' + sLineBreak +
    '    case 2: r += "c"; break loop;' + sLineBreak +
    '  }' + sLineBreak +
    '  r += "-";' + sLineBreak +
    '}' + sLineBreak +
    'r';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('a-bc', Actual);
end;

procedure TLabelledStatementTests.Label_StackedOnOneLoop_EachLabelCanContinueIt;
begin
  const Script =
    COUNTER_ZERO + sLineBreak +
    'first: second: for (var i = 0; i < 4; i++) {' + sLineBreak +
    '  for (;;) { if (i % 2) continue first; n++; continue second; }' + sLineBreak +
    '}' + sLineBreak +
    'n';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TLabelledStatementTests.Break_WithLabelThroughTryFinally_RunsFinally;
begin
  const Script =
    RESULT_EMPTY_TEXT + sLineBreak +
    'lbl: try { r += "t"; break lbl; } finally { r += "f"; }' + sLineBreak +
    'r';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('tf', Actual);
end;

procedure TLabelledStatementTests.Label_SameNameInSeparateFunctions_IsAllowed;
begin
  const Script =
    'function f() { a: for (;;) { break a; } return 1; }' + sLineBreak +
    'function g() { a: for (;;) { break a; } return 2; }' + sLineBreak +
    'a: for (;;) { break a; }' + sLineBreak +
    'f() + g()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(3.0, Actual);
end;

procedure TLabelledStatementTests.Label_SameNameSequentially_IsAllowed;
begin
  const Actual = ErrorNameOf('a: ; a: ;');

  Assert.AreEqual('', Actual);
end;

procedure TLabelledStatementTests.Label_NameSharedWithVariable_DoesNotClash;
begin
  const Script =
    'var a = 5;' + sLineBreak +
    'a: while (true) { a++; break a; }' + sLineBreak +
    'a';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(6.0, Actual);
end;

procedure TLabelledStatementTests.Break_LabelFollowedByLineTerminator_IsPlainBreak;
begin
  const Script =
    RESULT_ZERO + sLineBreak +
    'var a = 7;' + sLineBreak +
    'a: while (true) { break' + sLineBreak +
    'a; }' + sLineBreak +
    'r = 1; r';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TLabelledStatementTests.Eval_InvalidLabelUsage_IsSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

end.
