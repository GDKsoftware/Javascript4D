unit JS4D.Tests.ProxyLimits;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TProxyLimitTests = class
  private
    const
      LARGE_STEP_BUDGET = 1000000;
      SMALL_STEP_BUDGET = 100000;
      NATIVE_TRAP_CYCLE_SCRIPT = 'var t = {}; var p = new Proxy(t, { getPrototypeOf: Reflect.getPrototypeOf }); Object.setPrototypeOf(t, p); p instanceof Function;';
      BREAK_CYCLE_SCRIPT = 'Object.setPrototypeOf(t, null);';

    var
      FEngine: TJSEngine;

    procedure AssertStepBudgetEnds(const Script: string);
    procedure AssertNativeTrapCycleEnds;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Instanceof', 'var p = new Proxy({}, { getPrototypeOf: function () { return p; } }); p instanceof Function;', '#')]
    [TestCase('IsPrototypeOf', 'var p = new Proxy({}, { getPrototypeOf: function () { return p; } }); Object.prototype.isPrototypeOf.call(Object.prototype, p);', '#')]
    procedure Proxy_GetPrototypeOfReturningTheProxy_EndsWithTheStepBudget(const Script: string);

    [Test]
    procedure Proxy_NativeGetPrototypeOfTrapCycle_EndsWithTheStepBudget;

    [Test]
    procedure Execute_ProxyTrapCalls_CountAsSteps;

    [Test]
    procedure Execute_AfterTheStepBudgetEnded_HostStaysUsable;
  end;

implementation

uses
  System.SysUtils;

procedure TProxyLimitTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TProxyLimitTests.TearDown;
begin
  FEngine.Free;
end;

procedure TProxyLimitTests.AssertStepBudgetEnds(const Script: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSStepBudgetExceeded);
end;

procedure TProxyLimitTests.AssertNativeTrapCycleEnds;
begin
  AssertStepBudgetEnds(NATIVE_TRAP_CYCLE_SCRIPT);
  FEngine.Execute(BREAK_CYCLE_SCRIPT);
end;

procedure TProxyLimitTests.Proxy_GetPrototypeOfReturningTheProxy_EndsWithTheStepBudget(const Script: string);
begin
  FEngine.StepBudget := LARGE_STEP_BUDGET;

  AssertStepBudgetEnds(Script);
end;

procedure TProxyLimitTests.Proxy_NativeGetPrototypeOfTrapCycle_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := LARGE_STEP_BUDGET;

  AssertNativeTrapCycleEnds;
end;

procedure TProxyLimitTests.Execute_ProxyTrapCalls_CountAsSteps;
begin
  FEngine.StepBudget := SMALL_STEP_BUDGET;
  FEngine.Execute('var p = new Proxy({}, { get: Reflect.get }); for (var i = 0; i < 100; i++) { p.x; }');
  const ProxySteps = FEngine.StepCount;

  FEngine.Execute('var q = {}; for (var j = 0; j < 100; j++) { q.x; }');
  const PlainSteps = FEngine.StepCount;

  const ProxyCostsMoreSteps = (ProxySteps > PlainSteps);
  Assert.IsTrue(ProxyCostsMoreSteps, 'Native trap calls must add steps to the count');
end;

procedure TProxyLimitTests.Execute_AfterTheStepBudgetEnded_HostStaysUsable;
begin
  FEngine.StepBudget := SMALL_STEP_BUDGET;

  AssertNativeTrapCycleEnds;

  const Actual = FEngine.Evaluate('String(1 + 2)').ToString;
  Assert.AreEqual('3', Actual);
end;

end.
