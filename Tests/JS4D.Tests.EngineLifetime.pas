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
    procedure RunScript(const Script: string; const ErrorExpected: Boolean);
    function BytesLeakedByEngines(const Script: string; const ErrorExpected: Boolean): Int64;

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
    [TestCase('Block binding holding an eval closure', '{ let g = eval("(function () { return g; })"); g(); }', '#')]
    [TestCase('Loop binding holding an eval closure', 'for (let g = eval("() => g"); false;) { }', '#')]
    [TestCase('Block binding holding a function', '{ let g = function () { return g; }; const h = () => h; }', '#')]
    [TestCase('Function declaration in a block', '{ function g() { return g; } g(); }', '#')]
    [TestCase('Per-iteration binding holding a function', 'for (let g = function () { return g; }, i = 0; i < 2; i++) { g(); }', '#')]
    [TestCase('For-of binding holding a function', 'for (const g of [function () { return g; }]) { }', '#')]
    [TestCase('Tagged template', 'function t(s) { return s; } for (var i = 0; i < 2; i++) { t`a${i}b`; }', '#')]
    [TestCase('Object literal with accessors and methods', 'let o = { get a() { return o; }, set a(v) { o = v; }, m() { return o; }, [''k'' + 1]: () => o };', '#')]
    [TestCase('Destructuring with defaults', 'let { a = () => a, b: [c = () => c] = [] } = {};', '#')]
    [TestCase('Rest parameter and spread', 'function f(...r) { return () => r; } let g = f(...[1, 2], ...''ab'');', '#')]
    [TestCase('Function constructor', 'var f = new Function("a", "b", "return () => a + b");  f(1, 2)();', '#')]
    procedure Engine_AfterDestruction_ReleasesAllMemory(const Script: string);

    [Test]
    [TestCase('Duplicate let in a block', '{ let a; let a; }', '#')]
    [TestCase('Duplicate let after closures', 'var f = () => 1; { let a = () => a; let a; }', '#')]
    [TestCase('Let conflicting with a parameter', 'function f(a) { let a; }', '#')]
    [TestCase('Misplaced let in a loop head', 'for (let [a, a] = [1, 2]; false;) { }', '#')]
    [TestCase('Unterminated block with let', '{ let a = () => a;', '#')]
    [TestCase('Unterminated for-of', 'for (let a of [() => a]', '#')]
    [TestCase('Invalid destructuring target', 'let { a = () => a, 1 } = {};', '#')]
    [TestCase('Error thrown in a block', '{ let a = () => a; throw new Error("x"); }', '#')]
    [TestCase('Error thrown in a loop body', 'for (let i = 0; i < 2; i++) { let g = () => g; null.x; }', '#')]
    [TestCase('Error thrown in a for-of body', 'for (const v of [() => v]) { undefinedFunction(); }', '#')]
    [TestCase('Error thrown in a switch', 'switch (1) { case 1: let a = () => a; throw 1; }', '#')]
    [TestCase('Temporal dead zone access', '{ let g = () => g; g; let h = h; }', '#')]
    [TestCase('Assignment to a constant', 'const c = () => c; c = 1;', '#')]
    [TestCase('Error in a default parameter', 'function f(a = () => a, b = null.x) { } f();', '#')]
    [TestCase('Error in an arrow parameter', 'var f = (a = () => a, [b] = null) => 1; f();', '#')]
    [TestCase('Error in tagged template', 'function t(s) { throw s; } t`a${() => 1}b`;', '#')]
    procedure Engine_AfterScriptError_ReleasesAllMemory(const Script: string);
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

procedure TEngineLifetimeTests.RunScript(const Script: string; const ErrorExpected: Boolean);
begin
  const Engine = TJSEngine.Create;
  try
    try
      Engine.Execute(Script);
    except
      on Exception do
      begin
        if not ErrorExpected then
          raise;
      end;
    end;
  finally
    Engine.Free;
  end;
end;

function TEngineLifetimeTests.BytesLeakedByEngines(const Script: string; const ErrorExpected: Boolean): Int64;
begin
  for var Run := 1 to WARM_UP_RUNS do
  begin
    RunScript(Script, ErrorExpected);
  end;

  const Before = AllocatedBytes;

  for var Run := 1 to MEASURED_RUNS do
  begin
    RunScript(Script, ErrorExpected);
  end;

  Result := AllocatedBytes - Before;
end;

procedure TEngineLifetimeTests.Engine_AfterDestruction_ReleasesAllMemory(const Script: string);
begin
  const LeakedBytes = BytesLeakedByEngines(Script, False);

  Assert.IsTrue(LeakedBytes < TOLERATED_BYTES, Format('Leaked %d bytes', [LeakedBytes]));
end;

procedure TEngineLifetimeTests.Engine_AfterScriptError_ReleasesAllMemory(const Script: string);
begin
  const LeakedBytes = BytesLeakedByEngines(Script, True);

  Assert.IsTrue(LeakedBytes < TOLERATED_BYTES, Format('Leaked %d bytes', [LeakedBytes]));
end;

end.
