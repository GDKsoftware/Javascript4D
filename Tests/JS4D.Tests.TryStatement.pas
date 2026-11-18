unit JS4D.Tests.TryStatement;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TTryStatementTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Return_InsideTryBlock_ReturnsValueWithoutRunningCatch;

    [Test]
    procedure Return_InsideTryBlock_RunsFinalizer;

    [Test]
    procedure Return_InsideCatchBlock_RunsFinalizer;

    [Test]
    procedure Break_InsideTryBlock_LeavesLoopWithoutRunningCatch;

    [Test]
    procedure Continue_InsideTryBlock_SkipsToNextIterationWithoutRunningCatch;

    [Test]
    procedure Throw_InsideTryWithoutCatch_RunsFinalizerBeforePropagating;

    [Test]
    procedure Return_InsideFinalizer_OverridesTryResult;

    [Test]
    procedure Throw_InsideTryWithCatch_RunsCatchThenFinalizer;
  end;

implementation

const
  LOG_DECLARATION = 'var log = 0;';

procedure TTryStatementTests.Return_InsideTryBlock_ReturnsValueWithoutRunningCatch;
begin
  const Script =
    'function f() { try { return 1; } catch (e) { return 2; } }' + sLineBreak +
    'f()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TTryStatementTests.Return_InsideTryBlock_RunsFinalizer;
begin
  const Script =
    LOG_DECLARATION + sLineBreak +
    'function f() { try { return 1; } finally { log = 5; } }' + sLineBreak +
    'f() + log';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(6.0, Actual);
end;

procedure TTryStatementTests.Return_InsideCatchBlock_RunsFinalizer;
begin
  const Script =
    LOG_DECLARATION + sLineBreak +
    'function f() { try { throw 1; } catch (e) { return 2; } finally { log = 5; } }' + sLineBreak +
    'f() + log';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(7.0, Actual);
end;

procedure TTryStatementTests.Break_InsideTryBlock_LeavesLoopWithoutRunningCatch;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  try { if (i === 2) { break; } count++; } catch (e) { count = 100; }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TTryStatementTests.Continue_InsideTryBlock_SkipsToNextIterationWithoutRunningCatch;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  try { if (i === 2) { continue; } count++; } catch (e) { count = 100; }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(4.0, Actual);
end;

procedure TTryStatementTests.Throw_InsideTryWithoutCatch_RunsFinalizerBeforePropagating;
begin
  const Script =
    LOG_DECLARATION + sLineBreak +
    'try { try { throw 1; } finally { log = 7; } } catch (e) { }' + sLineBreak +
    'log';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(7.0, Actual);
end;

procedure TTryStatementTests.Return_InsideFinalizer_OverridesTryResult;
begin
  const Script =
    'function f() { try { return 1; } finally { return 3; } }' + sLineBreak +
    'f()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(3.0, Actual);
end;

procedure TTryStatementTests.Throw_InsideTryWithCatch_RunsCatchThenFinalizer;
begin
  const Script =
    LOG_DECLARATION + sLineBreak +
    'try { throw 4; } catch (e) { log = e; } finally { log = log * 2; }' + sLineBreak +
    'log';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(8.0, Actual);
end;

end.
