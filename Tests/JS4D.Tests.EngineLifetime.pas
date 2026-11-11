unit JS4D.Tests.EngineLifetime;

{$SCOPEDENUMS ON}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TEngineLifetimeTests = class
  private
    function AllocatedBytes: Int64;
    function BytesLeakedByEngines(const Script: string): Int64;

  public
    [Test]
    [TestCase('Empty program', '', '#')]
    [TestCase('Regular expression accessors', 'var re = /a/g; re.source + re.flags + re.global;', '#')]
    [TestCase('Closure in a block', '{ let a = 1; var f = function () { return a; }; }', '#')]
    [TestCase('Closures per loop iteration', 'var fs = []; for (let i = 0; i < 3; i++) { fs.push(function () { return i; }); }', '#')]
    [TestCase('Closures in for-in', 'var fs = []; for (let k in {a: 1, b: 2}) { fs.push(() => k); }', '#')]
    [TestCase('Closures in for-of', 'var fs = []; for (const v of [1, 2]) { fs.push(() => v); }', '#')]
    [TestCase('Arrow function capturing this', 'var o = { f: function () { return () => this; } }; var g = o.f(); g();', '#')]
    [TestCase('Named function expression', 'var f = function g() { return g; }; f();', '#')]
    [TestCase('Default parameter closure', 'function f(a, b = () => a) { var a; return b; } var r = f(1);', '#')]
    [TestCase('Closure created by eval in a block', '{ let a = 1; var f = eval("(function () { return a; })"); }', '#')]
    [TestCase('Closure created by eval in a loop', 'for (let i = 0; i < 2; i++) { var f = eval("() => i"); }', '#')]
    [TestCase('Catch parameter closure', 'try { throw 1; } catch (e) { var f = () => e; }', '#')]
    procedure Engine_AfterDestruction_ReleasesAllMemory(const Script: string);
  end;

implementation

const
  WARM_UP_RUNS = 2;
  MEASURED_RUNS = 5;
  TOLERATED_BYTES = 8 * 1024;

function TEngineLifetimeTests.AllocatedBytes: Int64;
begin
  var State: TMemoryManagerState;
  GetMemoryManagerState(State);

  Result := State.TotalAllocatedMediumBlockSize + State.TotalAllocatedLargeBlockSize;
  for var SmallBlockState in State.SmallBlockTypeStates do
  begin
    Result := Result + Int64(SmallBlockState.UseableBlockSize) * Int64(SmallBlockState.AllocatedBlockCount);
  end;
end;

function TEngineLifetimeTests.BytesLeakedByEngines(const Script: string): Int64;
begin
  for var Run := 1 to WARM_UP_RUNS do
  begin
    const WarmUpEngine = TJSEngine.Create;
    try
      WarmUpEngine.Execute(Script);
    finally
      WarmUpEngine.Free;
    end;
  end;

  const Before = AllocatedBytes;

  for var Run := 1 to MEASURED_RUNS do
  begin
    const Engine = TJSEngine.Create;
    try
      Engine.Execute(Script);
    finally
      Engine.Free;
    end;
  end;

  Result := AllocatedBytes - Before;
end;

procedure TEngineLifetimeTests.Engine_AfterDestruction_ReleasesAllMemory(const Script: string);
begin
  const LeakedBytes = BytesLeakedByEngines(Script);

  Assert.IsTrue(LeakedBytes < TOLERATED_BYTES, Format('Leaked %d bytes', [LeakedBytes]));
end;

end.
