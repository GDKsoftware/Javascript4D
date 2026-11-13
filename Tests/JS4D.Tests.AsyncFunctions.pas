unit JS4D.Tests.AsyncFunctions;

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
  TAsyncFunctionTests = class
  private
    FEngine: TJSEngine;

    function RunAndRead(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Call returns a promise', 'async function f() { } var r = (f() instanceof Promise) + "," + typeof f().then;~true,function', '~')]
    [TestCase('Return value resolves the promise', 'async function f() { return 7; } var r; f().then(function (v) { r = v; });~7', '~')]
    [TestCase('Without return the promise resolves with undefined', 'async function f() { } var r; f().then(function (v) { r = typeof v; });~undefined', '~')]
    [TestCase('The body runs synchronously up to the first await', 'var log = []; async function f() { log.push("body"); await 0; log.push("after"); } f(); log.push("sync"); var r; Promise.resolve().then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { r = log.join(); });~body,sync,after', '~')]
    [TestCase('Await on a non promise gives the value', 'var r; async function f() { return await 5; } f().then(function (v) { r = v; });~5', '~')]
    [TestCase('Await on a promise gives its value', 'var r; async function f() { var v = await Promise.resolve("p"); return v + "!"; } f().then(function (v) { r = v; });~p!', '~')]
    [TestCase('Await on a thenable', 'var r; async function f() { return await { then: function (res) { res("t"); } }; } f().then(function (v) { r = v; });~t', '~')]
    [TestCase('A rejected promise throws at the await', 'var r; async function f() { try { await Promise.reject("e"); } catch (x) { r = "caught " + x; } } f();~caught e', '~')]
    [TestCase('An uncaught rejection rejects the result', 'var r; async function f() { await Promise.reject("e"); } f().catch(function (x) { r = "rejected " + x; });~rejected e', '~')]
    [TestCase('A throw before any await rejects the result', 'var r; async function f() { throw new RangeError("t"); } f().catch(function (x) { r = x.name; });~RangeError', '~')]
    [TestCase('The call itself never throws', 'async function f() { null.x; } var r; try { f(); r = "no throw"; } catch (e) { r = "threw"; }~no throw', '~')]
    [TestCase('Finally runs after an await', 'var log = []; async function f() { try { await 1; log.push("try"); } finally { log.push("finally"); } } f(); var r; Promise.resolve().then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { r = log.join(); });~try,finally', '~')]
    [TestCase('Await inside finally', 'var log = []; async function f() { try { throw "x"; } catch (e) { log.push("catch " + e); } finally { await 0; log.push("finally"); } return "done"; } var r; f().then(function (v) { log.push(v); r = log.join(); });~catch x,finally,done', '~')]
    [TestCase('Return inside try with a finally that awaits keeps the value', 'async function f() { try { return "kept"; } finally { await 0; } } var r; f().then(function (v) { r = v; });~kept', '~')]
    [TestCase('Returning a promise adopts it', 'var r; async function f() { return Promise.resolve("inner"); } f().then(function (v) { r = v; });~inner', '~')]
    [TestCase('Returning a rejected promise rejects', 'var r; async function f() { return Promise.reject("no"); } f().catch(function (v) { r = v; });~no', '~')]
    [TestCase('Await takes one turn for a native promise', 'var log = []; async function f() { await Promise.resolve(); log.push("f"); } f(); Promise.resolve().then(function () { log.push(1); }).then(function () { log.push(2); }); var r; Promise.resolve().then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { r = log.join(); });~f,1,2', '~')]
    [TestCase('Await of a non promise takes one turn', 'var log = []; async function f() { await 1; log.push("f"); } f(); Promise.resolve().then(function () { log.push(1); }).then(function () { log.push(2); }); var r; Promise.resolve().then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { r = log.join(); });~f,1,2', '~')]
    [TestCase('Two async functions interleave at their awaits', 'var log = []; async function a() { log.push("a1"); await 0; log.push("a2"); await 0; log.push("a3"); } async function b() { log.push("b1"); await 0; log.push("b2"); } a(); b(); var r; Promise.resolve().then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { }).then(function () { r = log.join(); });~a1,b1,a2,b2,a3', '~')]
    [TestCase('Await in a loop', 'async function f() { var s = 0; for (var i = 1; i <= 5; i++) { s += await i; } return s; } var r; f().then(function (v) { r = v; });~15', '~')]
    [TestCase('Await in a for of loop over an array', 'async function f() { var out = []; for (var x of [1, 2, 3]) { out.push(await x * 2); } return out.join(); } var r; f().then(function (v) { r = v; });~2,4,6', '~')]
    [TestCase('A loop of many awaits completes', 'async function f() { var n = 0; for (var i = 0; i < 20000; i++) { n += await i; } return n; } var r; f().then(function (v) { r = v; });~199990000', '~')]
    [TestCase('Await in a while condition', 'async function f() { var n = 0; while (await n < 3) { n++; } return n; } var r; f().then(function (v) { r = v; });~3', '~')]
    [TestCase('Await in a switch', 'async function f(x) { switch (await x) { case 1: return "one"; default: return "other"; } } var r; f(1).then(function (a) { f(2).then(function (b) { r = a + b; }); });~oneother', '~')]
    [TestCase('Await in an if', 'async function f(c) { if (await c) { return "yes"; } else { return await "no"; } } var r; f(false).then(function (v) { r = v; });~no', '~')]
    [TestCase('Await inside an expression keeps the operands before it', 'var log = []; function n(x) { log.push(x); return x; } async function f() { return n(1) + await n(2) + n(3); } var r; f().then(function (v) { r = log.join() + ":" + v; });~1,2,3:6', '~')]
    [TestCase('Await as a call argument', 'function add(a, b) { return a + b; } async function f() { return add(await 1, await 2); } var r; f().then(function (v) { r = v; });~3', '~')]
    [TestCase('Await in a template literal and an object literal', 'async function f() { var o = { a: await 1, [await "k"]: await 2 }; return `${await "x"}${o.a}${o.k}`; } var r; f().then(function (v) { r = v; });~x12', '~')]
    [TestCase('Await in a destructuring source', 'async function f() { var [a, b] = await [1, 2]; let { c } = await { c: 3 }; return a + b + c; } var r; f().then(function (v) { r = v; });~6', '~')]
    [TestCase('Await binds like a unary operator', 'async function f() { return (await 2) ** 3 + await 1 * 2; } var r; f().then(function (v) { r = v; });~10', '~')]
    [TestCase('Arguments and this reach the body', 'async function f(a, b) { await 0; return this.x + arguments.length + a + b; } var r; f.call({ x: 10 }, 1, 2).then(function (v) { r = v; });~15', '~')]
    [TestCase('Parameters see their defaults', 'async function f(a, b = a * 2) { await 0; return b; } var r; f(4).then(function (v) { r = v; });~8', '~')]
    [TestCase('An error in a parameter default rejects', 'async function f(a = (function () { throw new RangeError("p"); })()) { } var r; try { f().catch(function (e) { r = e.name; }); } catch (e) { r = "threw"; }~RangeError', '~')]
    [TestCase('Closures keep the scope across awaits', 'async function f() { var n = 0; var inc = function () { return ++n; }; await 0; inc(); await 0; return inc(); } var r; f().then(function (v) { r = v; });~2', '~')]
    [TestCase('Async function declarations are hoisted', 'var r; g().then(function (v) { r = v; }); async function g() { return "hoisted"; }~hoisted', '~')]
    [TestCase('Async function expressions', 'var f = async function () { return await 1; }; var r; f().then(function (v) { r = v; });~1', '~')]
    [TestCase('Named async function expression sees its name', 'var f = async function me() { return typeof me; }; var r; f().then(function (v) { r = v; });~function', '~')]
    [TestCase('Await is an identifier outside async functions', 'var await = 5; function f() { return await; } var r = f();~5', '~')]
    [TestCase('Await is an identifier in a function inside an async function', 'async function f() { function g() { var await = 3; return await; } return g(); } var r; f().then(function (v) { r = v; });~3', '~')]
    [TestCase('Async is an identifier', 'var async = 4; var r = async + 1;~5', '~')]
    [TestCase('Async can be called as a function', 'function async(x) { return x * 2; } var r = async(4);~8', '~')]
    [TestCase('Async functions are not constructors', 'async function f() { } var r; try { new f(); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('Async functions have no prototype property', 'async function f() { } var r = f.hasOwnProperty("prototype") + "," + (f.prototype === undefined);~false,true', '~')]
    [TestCase('Async functions have a name and a length', 'async function f(a, b) { } var r = f.name + "," + f.length;~f,2', '~')]
    [TestCase('Prototype chain of async functions', 'async function f() { } var AF = Object.getPrototypeOf(f); var r = [AF === Function.prototype, Object.getPrototypeOf(AF) === Function.prototype, AF[Symbol.toStringTag], AF.constructor.name, AF.constructor.length].join();~false,true,AsyncFunction,AsyncFunction,1', '~')]
    [TestCase('AsyncFunction constructor builds async functions', 'var AF = Object.getPrototypeOf(async function () { }).constructor; var f = new AF("a", "b", "return await a + b;"); var r; f(1, 2).then(function (v) { r = v + "," + f.name; });~3,anonymous', '~')]
    [TestCase('AsyncFunction can be called without new', 'var AF = Object.getPrototypeOf(async function () { }).constructor; var f = AF("return await 1;"); var r; f().then(function (v) { r = v; });~1', '~')]
    [TestCase('Source text of async functions', 'async function f(a) { await a; } var g = async (x) => x; var o = { async m() { } }; var r = [f.toString(), g.toString(), o.m.toString()].join("|");~async function f(a) { await a; }|async (x) => x|async m() { }', '~')]
    [TestCase('Object prototype tag', 'async function f() { } var r = Object.prototype.toString.call(f) + Object.prototype.toString.call(f());~[object AsyncFunction][object Promise]', '~')]
    procedure Async_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('Arrow with parentheses', 'var f = async (a, b) => a + await b; var r; f(1, 2).then(function (v) { r = v; });~3', '~')]
    [TestCase('Arrow with a single parameter', 'var f = async a => await a * 2; var r; f(4).then(function (v) { r = v; });~8', '~')]
    [TestCase('Arrow with a block body', 'var f = async () => { await 0; return "block"; }; var r; f().then(function (v) { r = v; });~block', '~')]
    [TestCase('Arrow without parameters and expression body', 'var f = async () => 1; var r; f().then(function (v) { r = v; });~1', '~')]
    [TestCase('Arrow keeps this', 'var o = { v: "t", m: function () { return (async () => { await 0; return this.v; })(); } }; var r; o.m().then(function (v) { r = v; });~t', '~')]
    [TestCase('Arrow keeps arguments of the surrounding function', 'function f() { return (async () => arguments[0])(); } var r; f("a").then(function (v) { r = v; });~a', '~')]
    [TestCase('Arrow with destructured parameters and defaults', 'var f = async ({ a }, [b] = [2], ...rest) => a + b + rest.length; var r; f({ a: 1 }, undefined, 0, 0).then(function (v) { r = v; });~5', '~')]
    [TestCase('Arrows are not constructors and have no prototype', 'var f = async () => 1; var r; try { new f(); } catch (e) { r = e.name; } r += "," + f.hasOwnProperty("prototype");~TypeError,false', '~')]
    [TestCase('Arrow has the async function prototype', 'var f = async () => 1; var r = Object.getPrototypeOf(f) === Object.getPrototypeOf(async function () { });~true', '~')]
    [TestCase('A call to a function named async with arrow looking arguments', 'function async(f) { return f(); } var r = async(() => "called");~called', '~')]
    [TestCase('Async arrow in an argument list', 'var r; Promise.resolve(2).then(async v => v * 3).then(function (v) { r = v; });~6', '~')]
    [TestCase('Async arrow in a conditional', 'var f = true ? async () => "a" : null; var r; f().then(function (v) { r = v; });~a', '~')]
    [TestCase('Nested async arrows', 'var f = async () => { var g = async () => await 1; return await g() + 1; }; var r; f().then(function (v) { r = v; });~2', '~')]
    [TestCase('A non async arrow in an async function can use await as a name', 'async function f() { var g = () => { var await = 1; return await; }; return g(); } var r; f().then(function (v) { r = v; });~1', '~')]
    procedure AsyncArrow_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('Object literal method', 'var o = { async m(a) { return await a; } }; var r; o.m(3).then(function (v) { r = v; });~3', '~')]
    [TestCase('Object literal method sees this', 'var o = { v: "o", async m() { await 0; return this.v; } }; var r; o.m().then(function (v) { r = v; });~o', '~')]
    [TestCase('Computed and string keys', 'var o = { async ["c" + 1]() { return 1; }, async "s"() { return 2; }, async 3() { return 3; } }; var r = [typeof o.c1, typeof o.s, typeof o[3]].join();~function,function,function', '~')]
    [TestCase('Async as a property name', 'var o = { async: 1, async() { return 2; } }; var r = typeof o.async;~function', '~')]
    [TestCase('Async as a shorthand property', 'var async = 7; var o = { async }; var r = o.async;~7', '~')]
    [TestCase('Async methods are not constructors', 'var o = { async m() { } }; var r; try { new o.m(); } catch (e) { r = e.name; } r += "," + o.m.hasOwnProperty("prototype");~TypeError,false', '~')]
    [TestCase('Async method name', 'var o = { async m() { } }; var r = o.m.name;~m', '~')]
    [TestCase('Class method', 'class C { async m(a) { return await a + 1; } } var r; new C().m(1).then(function (v) { r = v; });~2', '~')]
    [TestCase('Static class method', 'class C { static async m() { return "static"; } } var r; C.m().then(function (v) { r = v; });~static', '~')]
    [TestCase('Class method named async', 'class C { async() { return "named"; } static async async() { return "both"; } } var r = new C().async() + ",";~named,', '~')]
    [TestCase('Super in an async method', 'class A { m() { return "a"; } } class B extends A { async m() { await 0; return super.m() + "b"; } } var r; new B().m().then(function (v) { r = v; });~ab', '~')]
    [TestCase('Super property in an async method of an object', 'var base = { v: "base" }; var o = { __proto__: base, async m() { await 0; return super.v; } }; var r; o.m().then(function (v) { r = v; });~base', '~')]
    [TestCase('Async method with new target', 'class C { async m() { return new.target; } } var r; new C().m().then(function (v) { r = typeof v; });~undefined', '~')]
    [TestCase('Async method toString', 'class C { async m() { } static async s() { } } var r = [C.prototype.m.toString(), C.s.toString()].join("|");~async m() { }|async s() { }', '~')]
    procedure AsyncMethod_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('Await in a parameter default', 'async function f(a = await 1) { }')]
    [TestCase('Await in an async arrow parameter', 'var f = async (a = await 1) => 1;')]
    [TestCase('Await as a parameter name', 'async function f(await) { }')]
    [TestCase('Await as an async arrow parameter name', 'var f = async await => 1;')]
    [TestCase('Await as a variable name in an async function', 'async function f() { var await; }')]
    [TestCase('Await as a function name of an async function expression', 'var f = async function await() { };')]
    [TestCase('Await without an operand', 'async function f() { await; }')]
    [TestCase('Await before an exponent', 'async function f() { await 1 ** 2; }')]
    [TestCase('Await in a plain function', 'function f() { await 1; }')]
    [TestCase('Await in a function inside an async function', 'async function f() { function g() { await 1; } }')]
    [TestCase('Await in a non async arrow inside an async function', 'async function f() { var g = () => await 1; }')]
    [TestCase('Await with an escape', 'async function f() { '#92'u0061wait 1; }')]
    [TestCase('Async function as a statement body', 'if (1) async function f() { }')]
    [TestCase('Async function after a label', 'a: async function f() { }')]
    [TestCase('Line break after async', 'async\nfunction f() { await 1; }')]
    [TestCase('Line break before the arrow', 'var f = async ()\n=> 1;')]
    [TestCase('Async generator declaration', 'async function* g() { }')]
    [TestCase('Async generator method', 'var o = { async *m() { } };')]
    [TestCase('Async class constructor', 'class C { async constructor() { } }')]
    [TestCase('Async getter', 'class C { async get m() { } }')]
    [TestCase('Async method without a body', 'var o = { async m: 1 };')]
    [TestCase('Duplicate parameters of an async arrow', 'var f = async (a, a) => 1;')]
    [TestCase('Use strict with a default parameter', 'async function f(a = 1) { "use strict"; }')]
    procedure Parse_RejectsMisplacedAsync(const Script: string);

    [Test]
    procedure Call_WithDeepRecursionThroughAwait_EndsWithTheCallDepthLimit;

    [Test]
    procedure Call_WithEndlessLoopInTheBody_EndsWithTheStepBudget;

    [Test]
    procedure Call_WithEndlessLoopAfterAnAwait_EndsWithTheStepBudget;

    [Test]
    procedure CollectGarbage_WithAsyncFunctionsAwaitingAPendingPromise_KeepsTheirScopes;

    [Test]
    procedure Free_WithAsyncFunctionsStillAwaiting_ReleasesEverything;
  end;

implementation

procedure TAsyncFunctionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TAsyncFunctionTests.TearDown;
begin
  FEngine.Free;
end;

function TAsyncFunctionTests.RunAndRead(const Script: string): string;
begin
  FEngine.Execute(Script);

  Result := FEngine.Evaluate('String(r)').ToString;
end;

procedure TAsyncFunctionTests.Async_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TAsyncFunctionTests.AsyncArrow_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TAsyncFunctionTests.AsyncMethod_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TAsyncFunctionTests.Parse_RejectsMisplacedAsync(const Script: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSSyntaxError);
end;

procedure TAsyncFunctionTests.Call_WithDeepRecursionThroughAwait_EndsWithTheCallDepthLimit;
begin
  FEngine.MaxCallDepth := 200;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('async function f(n) { await f(n + 1); } f(0);');
    end,
    EJSCallDepthExceeded);

  Assert.AreEqual('3', FEngine.Evaluate('1 + 2').ToString);
end;

procedure TAsyncFunctionTests.Call_WithEndlessLoopInTheBody_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := 100000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('async function f() { while (true) { } } f();');
    end,
    EJSStepBudgetExceeded);
end;

procedure TAsyncFunctionTests.Call_WithEndlessLoopAfterAnAwait_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := 100000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('async function f() { await 0; while (true) { } } f();');
    end,
    EJSStepBudgetExceeded);
end;

procedure TAsyncFunctionTests.CollectGarbage_WithAsyncFunctionsAwaitingAPendingPromise_KeepsTheirScopes;
begin
  FEngine.Execute('var release; var out = "waiting"; ' +
                  'async function f() { var keep = { v: "alive" }; var g = function () { return keep.v; }; ' +
                  'await new Promise(function (res) { release = res; }); out = g(); } f();');

  FEngine.CollectGarbage;
  FEngine.Execute('release();');

  Assert.AreEqual('alive', FEngine.Evaluate('out').ToString);
end;

procedure TAsyncFunctionTests.Free_WithAsyncFunctionsStillAwaiting_ReleasesEverything;
begin
  FEngine.Execute('var gate = new Promise(function () { }); var self = {}; ' +
                  'async function f() { self.p = f; await gate; } self.result = f(); ' +
                  'var h = (async () => { await h; })();');

  Assert.AreEqual('object', FEngine.Evaluate('typeof self.result').ToString);
end;

end.
