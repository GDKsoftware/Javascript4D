unit JS4D.Tests.TryStatement;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TTryStatementTests = class
  private
    FEngine: TJSEngine;

    function EvaluateNumber(const Script: string): Double;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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

procedure TTryStatementTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TTryStatementTests.TearDown;
begin
  FEngine.Free;
end;

function TTryStatementTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).AsNumber;
end;

procedure TTryStatementTests.Return_InsideTryBlock_ReturnsValueWithoutRunningCatch;
begin
  const Script =
    'function f() { try { return 1; } catch (e) { return 2; } }' + sLineBreak +
    'f()';

  Assert.AreEqual(1.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Return_InsideTryBlock_RunsFinalizer;
begin
  const Script =
    'var log = 0;' + sLineBreak +
    'function f() { try { return 1; } finally { log = 5; } }' + sLineBreak +
    'f() + log';

  Assert.AreEqual(6.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Return_InsideCatchBlock_RunsFinalizer;
begin
  const Script =
    'var log = 0;' + sLineBreak +
    'function f() { try { throw 1; } catch (e) { return 2; } finally { log = 5; } }' + sLineBreak +
    'f() + log';

  Assert.AreEqual(7.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Break_InsideTryBlock_LeavesLoopWithoutRunningCatch;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  try { if (i === 2) { break; } count++; } catch (e) { count = 100; }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  Assert.AreEqual(2.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Continue_InsideTryBlock_SkipsToNextIterationWithoutRunningCatch;
begin
  const Script =
    'var count = 0;' + sLineBreak +
    'for (var i = 0; i < 5; i++) {' + sLineBreak +
    '  try { if (i === 2) { continue; } count++; } catch (e) { count = 100; }' + sLineBreak +
    '}' + sLineBreak +
    'count';

  Assert.AreEqual(4.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Throw_InsideTryWithoutCatch_RunsFinalizerBeforePropagating;
begin
  const Script =
    'var log = 0;' + sLineBreak +
    'try { try { throw 1; } finally { log = 7; } } catch (e) { }' + sLineBreak +
    'log';

  Assert.AreEqual(7.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Return_InsideFinalizer_OverridesTryResult;
begin
  const Script =
    'function f() { try { return 1; } finally { return 3; } }' + sLineBreak +
    'f()';

  Assert.AreEqual(3.0, EvaluateNumber(Script));
end;

procedure TTryStatementTests.Throw_InsideTryWithCatch_RunsCatchThenFinalizer;
begin
  const Script =
    'var log = 0;' + sLineBreak +
    'try { throw 4; } catch (e) { log = e; } finally { log = log * 2; }' + sLineBreak +
    'log';

  Assert.AreEqual(8.0, EvaluateNumber(Script));
end;

end.
