unit JS4D.Tests.ProxyLimits;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TProxyLimitTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Proxy_GetPrototypeOfReturningTheProxy_ForInstanceofEndsWithTheStepBudget;

    [Test]
    procedure Proxy_GetPrototypeOfReturningTheProxy_ForIsPrototypeOfEndsWithTheStepBudget;

    [Test]
    procedure Proxy_NativeGetPrototypeOfTrapCycle_EndsWithTheStepBudget;

    [Test]
    procedure Proxy_TrapCalls_CountAsSteps;

    [Test]
    procedure Proxy_HostStaysUsableAfterTheLimit;
  end;

implementation

procedure TProxyLimitTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TProxyLimitTests.TearDown;
begin
  FEngine.Free;
end;

procedure TProxyLimitTests.Proxy_GetPrototypeOfReturningTheProxy_ForInstanceofEndsWithTheStepBudget;
begin
  FEngine.StepBudget := 1000000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var p = new Proxy({}, { getPrototypeOf: function () { return p; } }); p instanceof Function;');
    end,
    EJSStepBudgetExceeded);
end;

procedure TProxyLimitTests.Proxy_GetPrototypeOfReturningTheProxy_ForIsPrototypeOfEndsWithTheStepBudget;
begin
  FEngine.StepBudget := 1000000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var p = new Proxy({}, { getPrototypeOf: function () { return p; } }); Object.prototype.isPrototypeOf.call(Object.prototype, p);');
    end,
    EJSStepBudgetExceeded);
end;

procedure TProxyLimitTests.Proxy_NativeGetPrototypeOfTrapCycle_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := 1000000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var t = {}; var p = new Proxy(t, { getPrototypeOf: Reflect.getPrototypeOf }); Object.setPrototypeOf(t, p); p instanceof Function;');
    end,
    EJSStepBudgetExceeded);
end;

procedure TProxyLimitTests.Proxy_TrapCalls_CountAsSteps;
begin
  FEngine.StepBudget := 100000;
  FEngine.Execute('var p = new Proxy({}, { get: Reflect.get }); for (var i = 0; i < 100; i++) { p.x; }');
  const ProxySteps = FEngine.StepCount;

  FEngine.Execute('var q = {}; for (var j = 0; j < 100; j++) { q.x; }');
  const PlainSteps = FEngine.StepCount;

  Assert.IsTrue(ProxySteps > PlainSteps, 'Native trap calls must add steps to the count');
end;

procedure TProxyLimitTests.Proxy_HostStaysUsableAfterTheLimit;
begin
  FEngine.StepBudget := 100000;

  try
    FEngine.Execute('var t = {}; var p = new Proxy(t, { getPrototypeOf: Reflect.getPrototypeOf }); Object.setPrototypeOf(t, p); p instanceof Function;');
  except
    on EJSStepBudgetExceeded do;
  end;

  Assert.AreEqual('3', FEngine.Evaluate('String(1 + 2)').ToString);
end;

end.
