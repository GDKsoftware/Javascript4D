unit JS4D.Tests.Cancellation;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TCancellationTests = class
  private
    FEngine: TJSEngine;
    FScriptStarted: TEvent;

    procedure RegisterStartSignal;
    procedure RegisterCancelThenNest;
    function StartCancellingThread: TThread;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Execute_InfiniteLoopWithStepBudget_RaisesStepBudgetExceeded;

    [Test]
    procedure Execute_InfiniteRecursionWithStepBudget_RaisesStepBudgetExceeded;

    [Test]
    procedure Execute_ScriptCatchBlock_CannotSwallowStepBudgetExceeded;

    [Test]
    procedure Execute_CancelFromOtherThread_StopsInfiniteLoopQuickly;

    [Test]
    procedure Execute_CancelBeforeTheFirstRun_StopsThatRun;

    [Test]
    procedure Execute_CancelBetweenTwoRuns_StopsTheSecondRun;

    [Test]
    procedure Execute_NestedExecuteFromHostFunction_KeepsPendingCancel;

    [Test]
    procedure Execute_OrdinaryScriptWithGenerousBudget_RunsUnchanged;

    [Test]
    procedure Execute_OrdinaryScript_ReportsStepCount;

    [Test]
    procedure Execute_WithoutStepBudget_RunsLongLoopToCompletion;

    [Test]
    procedure Execute_AfterStepBudgetExceeded_EngineStaysUsable;

    [Test]
    procedure StepCount_SecondExecute_CountsOnlyThatRun;
  end;

implementation

const
  StartSignalName = 'signalStarted';
  CancelThenNestName = 'cancelThenNest';
  NestedScript = 'var nested = 1;';
  EndlessLoopScript = 'while (true) { }';
  SignallingEndlessLoopScript = 'signalStarted(); while (true) { }';
  CaughtEndlessLoopScript = 'try { while (true) { } } catch (e) { }';
  CancelThenNestLoopScript = 'cancelThenNest(); while (true) { }';
  RecursionDepthName = 'depth';
  EndlessRecursionScript = 'var depth = 0; function loop() { depth = depth + 1; return loop(); } loop();';
  FirstRunScript = 'var first = 1;';
  SummingLoopScript = 'var total = 0; for (var i = 1; i <= 10; i++) { total += i; }';
  LoopStepBudget = 5000;
  RecursionStepBudget = 200;
  RecursionDepthWithinBudget = 66;
  GenerousStepBudget = 1000000;
  MaximumCancelMilliseconds = 500;
  StartSignalTimeoutMilliseconds = 10000;

procedure TCancellationTests.Setup;
begin
  FEngine := TJSEngine.Create;
  FScriptStarted := TEvent.Create(nil, True, False, '');
  RegisterStartSignal;
end;

procedure TCancellationTests.TearDown;
begin
  FEngine.Free;
  FScriptStarted.Free;
end;

procedure TCancellationTests.RegisterStartSignal;
begin
  FEngine.RegisterFunction(StartSignalName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FScriptStarted.SetEvent;
      Result := TJSValue.CreateUndefined;
    end);
end;

procedure TCancellationTests.RegisterCancelThenNest;
begin
  FEngine.RegisterFunction(CancelThenNestName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FEngine.Cancel;
      FEngine.Execute(NestedScript);
      Result := TJSValue.CreateUndefined;
    end);
end;

function TCancellationTests.StartCancellingThread: TThread;
begin
  Result := TThread.CreateAnonymousThread(
    procedure
    begin
      FScriptStarted.WaitFor(StartSignalTimeoutMilliseconds);
      FEngine.Cancel;
    end);
  Result.FreeOnTerminate := False;
  Result.Start;
end;

procedure TCancellationTests.Execute_InfiniteLoopWithStepBudget_RaisesStepBudgetExceeded;
begin
  const Budget = Int64(LoopStepBudget);
  FEngine.StepBudget := Budget;

  try
    FEngine.Execute(EndlessLoopScript);
    Assert.Fail('An endless loop must not outlive its step budget');
  except
    on E: EJSStepBudgetExceeded do
    begin
      Assert.AreEqual(Budget, E.StepBudget, 'The exception must report the budget it exceeded');
      Assert.Contains(E.Message, IntToStr(Budget), 'The message must name the budget');
      Assert.AreEqual(Budget, FEngine.StepCount, 'Exactly the budgeted number of steps must have run');
    end;
  end;
end;

procedure TCancellationTests.Execute_InfiniteRecursionWithStepBudget_RaisesStepBudgetExceeded;
begin
  FEngine.StepBudget := RecursionStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(EndlessRecursionScript);
    end,
    EJSStepBudgetExceeded,
    'Endless recursion must run out of its step budget');

  Assert.AreEqual(Int64(RecursionStepBudget), FEngine.StepCount, 'Exactly the budgeted number of steps must have run');
  Assert.AreEqual(Double(RecursionDepthWithinBudget), FEngine.GetNumber(RecursionDepthName),
    Format('A level costs the call itself on top of its two statements, so %d steps reach depth %d',
      [RecursionStepBudget, RecursionDepthWithinBudget]));
end;

procedure TCancellationTests.Execute_ScriptCatchBlock_CannotSwallowStepBudgetExceeded;
begin
  FEngine.StepBudget := LoopStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(CaughtEndlessLoopScript);
    end,
    EJSStepBudgetExceeded,
    'A catch block in the script must not be able to keep the script alive');
end;

procedure TCancellationTests.Execute_CancelFromOtherThread_StopsInfiniteLoopQuickly;
begin
  const Canceller = StartCancellingThread;
  try
    const Started = TThread.GetTickCount64;

    Assert.WillRaise(
      procedure
      begin
        FEngine.Execute(SignallingEndlessLoopScript);
      end,
      EJSExecutionCancelled,
      'Cancel from another thread must end the running script');

    const Elapsed = TThread.GetTickCount64 - Started;
    Assert.IsTrue(Elapsed < MaximumCancelMilliseconds,
      Format('The script must stop within %d ms of the cancel, took %d ms', [MaximumCancelMilliseconds, Elapsed]));
  finally
    Canceller.WaitFor;
    Canceller.Free;
  end;
end;

procedure TCancellationTests.Execute_CancelBeforeTheFirstRun_StopsThatRun;
begin
  FEngine.Cancel;
  FEngine.StepBudget := LoopStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(EndlessLoopScript);
    end,
    EJSExecutionCancelled,
    'A cancel that arrives before the engine has run anything must stop the run that follows it');
end;

procedure TCancellationTests.Execute_CancelBetweenTwoRuns_StopsTheSecondRun;
begin
  FEngine.Execute(FirstRunScript);
  FEngine.Cancel;
  FEngine.StepBudget := LoopStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(EndlessLoopScript);
    end,
    EJSExecutionCancelled,
    'A cancel between two top-level runs must stop the second run, not be dropped by it');
end;

procedure TCancellationTests.Execute_NestedExecuteFromHostFunction_KeepsPendingCancel;
begin
  RegisterCancelThenNest;
  FEngine.StepBudget := LoopStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(CancelThenNestLoopScript);
    end,
    EJSExecutionCancelled,
    'A script a host function runs from inside a run must not clear the pending cancel');
end;

procedure TCancellationTests.Execute_OrdinaryScriptWithGenerousBudget_RunsUnchanged;
begin
  FEngine.StepBudget := GenerousStepBudget;

  const Result = FEngine.Evaluate(SummingLoopScript + ' total');

  Assert.AreEqual(Double(55), Result.ToNumber, 'A script that stays inside its budget must behave as before');
end;

procedure TCancellationTests.Execute_OrdinaryScript_ReportsStepCount;
begin
  FEngine.StepBudget := GenerousStepBudget;

  FEngine.Execute(SummingLoopScript);

  Assert.IsTrue(FEngine.StepCount > 10, Format('Ten loop iterations must count more than ten steps, got %d', [FEngine.StepCount]));
  Assert.IsTrue(FEngine.StepCount < FEngine.StepBudget, 'A script that completes must have stayed inside its budget');
end;

procedure TCancellationTests.Execute_WithoutStepBudget_RunsLongLoopToCompletion;
begin
  Assert.AreEqual(Int64(0), FEngine.StepBudget, 'The default budget must be unlimited');

  const Result = FEngine.Evaluate('var total = 0; for (var i = 0; i < 20000; i++) { total += 1; } total');

  Assert.AreEqual(Double(20000), Result.ToNumber, 'Without a budget a long loop must run to completion');
end;

procedure TCancellationTests.Execute_AfterStepBudgetExceeded_EngineStaysUsable;
begin
  FEngine.StepBudget := LoopStepBudget;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(EndlessLoopScript);
    end,
    EJSStepBudgetExceeded);

  FEngine.StepBudget := 0;

  const Result = FEngine.Evaluate('40 + 2');

  Assert.AreEqual(Double(42), Result.ToNumber, 'The engine must be usable again after a budget stopped a script');
end;

procedure TCancellationTests.StepCount_SecondExecute_CountsOnlyThatRun;
begin
  FEngine.Execute('var total = 0; for (var i = 0; i < 100; i++) { total += 1; }');
  const FirstCount = FEngine.StepCount;

  FEngine.Execute('var other = 1;');

  Assert.IsTrue(FEngine.StepCount < FirstCount, 'Each Execute must start counting from zero');
end;

initialization
  TDUnitX.RegisterTestFixture(TCancellationTests);

end.
