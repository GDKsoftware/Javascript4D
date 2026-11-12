unit JS4D.Tests.Promises;

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
  TPromiseTests = class
  private
    FEngine: TJSEngine;

    function RunAndRead(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Callbacks run before Execute returns', 'var r = "no"; Promise.resolve(1).then(function (v) { r = "v" + v; });~v1', '~')]
    [TestCase('Callbacks run after the script', 'var r = []; Promise.resolve().then(function () { r.push("then"); }); r.push("sync");~sync,then', '~')]
    [TestCase('Jobs run in the order they were queued', 'var r = []; Promise.resolve().then(function () { r.push(1); }); Promise.resolve().then(function () { r.push(2); }); Promise.resolve().then(function () { r.push(3); });~1,2,3', '~')]
    [TestCase('A job queued by a job runs after the waiting ones', 'var r = []; Promise.resolve().then(function () { r.push("a1"); Promise.resolve().then(function () { r.push("a2"); }); }); Promise.resolve().then(function () { r.push("b1"); });~a1,b1,a2', '~')]
    [TestCase('Chained callbacks pass their results on', 'var r; Promise.resolve(1).then(function (v) { return v + 1; }).then(function (v) { return v * 10; }).then(function (v) { r = v; });~20', '~')]
    [TestCase('A returned promise is followed', 'var r; Promise.resolve(1).then(function () { return Promise.resolve("inner"); }).then(function (v) { r = v; });~inner', '~')]
    [TestCase('Returning a promise takes two extra turns', 'var r = []; var p = Promise.resolve(); Promise.resolve().then(function () { return p; }).then(function () { r.push("A"); }); p.then(function () { r.push(1); }).then(function () { r.push(2); }).then(function () { r.push(3); });~1,2,3,A', '~')]
    [TestCase('A thenable is assimilated', 'var r; Promise.resolve({ then: function (res) { res("t"); } }).then(function (v) { r = v; });~t', '~')]
    [TestCase('A thenable that throws after resolving is ignored', 'var r; Promise.resolve({ then: function (res) { res("first"); throw new Error("late"); } }).then(function (v) { r = v; });~first', '~')]
    [TestCase('A thenable that throws rejects', 'var r; Promise.resolve({ then: function () { throw "boom"; } }).catch(function (e) { r = e; });~boom', '~')]
    [TestCase('A failing then getter rejects', 'var r; var o = {}; Object.defineProperty(o, "then", { get: function () { throw "g"; } }); Promise.resolve(o).catch(function (e) { r = e; });~g', '~')]
    [TestCase('Reject calls the rejection callback', 'var r; Promise.reject("no").then(function () { r = "fulfilled"; }, function (e) { r = "rejected " + e; });~rejected no', '~')]
    [TestCase('Catch receives the reason', 'var r; Promise.reject(new Error("x")).catch(function (e) { r = e.message; });~x', '~')]
    [TestCase('A rejection skips fulfilment callbacks', 'var r; Promise.reject(1).then(function () { r = "wrong"; }).catch(function (e) { r = "caught " + e; });~caught 1', '~')]
    [TestCase('An executor that throws rejects', 'var r; new Promise(function () { throw "ex"; }).catch(function (e) { r = e; });~ex', '~')]
    [TestCase('An executor that throws after resolving is ignored', 'var r; new Promise(function (res) { res("ok"); throw "late"; }).then(function (v) { r = v; });~ok', '~')]
    [TestCase('A promise settles once', 'var r = []; new Promise(function (res, rej) { res(1); res(2); rej(3); }).then(function (v) { r.push(v); }, function (e) { r.push("e" + e); });~1', '~')]
    [TestCase('A throwing callback rejects the derived promise', 'var r; Promise.resolve(1).then(function () { throw "t"; }).then(null, function (e) { r = e; });~t', '~')]
    [TestCase('Callbacks that are no functions are skipped', 'var r; Promise.resolve("p").then(1).then(undefined).then(function (v) { r = v; });~p', '~')]
    [TestCase('Resolving a promise with itself rejects', 'var r; var res; var p = new Promise(function (a) { res = a; }); res(p); p.catch(function (e) { r = e instanceof TypeError; });~true', '~')]
    [TestCase('Returning the derived promise rejects', 'var r; var p = Promise.resolve().then(function () { return p; }); p.catch(function (e) { r = e instanceof TypeError; });~true', '~')]
    [TestCase('Callbacks get undefined as this', 'var r; Promise.resolve().then(function () { "use strict"; r = String(this); });~undefined', '~')]
    [TestCase('Resolving later runs the callbacks', 'var r = "waiting"; var res; new Promise(function (a) { res = a; }).then(function (v) { r = v; }); res("done");~done', '~')]
    procedure Then_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('Finally keeps the value', 'var r = []; Promise.resolve("v").finally(function () { r.push("f"); return "ignored"; }).then(function (v) { r.push(v); });~f,v', '~')]
    [TestCase('Finally keeps the reason', 'var r = []; Promise.reject("e").finally(function () { r.push("f"); }).catch(function (e) { r.push(e); });~f,e', '~')]
    [TestCase('Finally that throws replaces the result', 'var r; Promise.resolve(1).finally(function () { throw "fin"; }).catch(function (e) { r = e; });~fin', '~')]
    [TestCase('Finally waits for a returned promise', 'var r = []; Promise.resolve(1).finally(function () { return Promise.resolve().then(function () { r.push("inner"); }); }).then(function () { r.push("after"); });~inner,after', '~')]
    [TestCase('Finally without a function passes both', 'var r; Promise.resolve(2).finally(5).then(function (v) { r = v; });~2', '~')]
    [TestCase('Finally gets no arguments', 'var r; Promise.resolve(2).finally(function () { r = arguments.length; });~0', '~')]
    procedure Finally_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('All collects the values in order', 'var r; Promise.all([1, Promise.resolve(2), { then: function (res) { res(3); } }]).then(function (v) { r = v.join(); });~1,2,3', '~')]
    [TestCase('All of nothing is an empty array', 'var r; Promise.all([]).then(function (v) { r = v.length; });~0', '~')]
    [TestCase('All rejects with the first rejection', 'var r; Promise.all([Promise.resolve(1), Promise.reject("bad")]).catch(function (e) { r = e; });~bad', '~')]
    [TestCase('All keeps the order of late values', 'var r; var res1; var p1 = new Promise(function (res) { res1 = res; }); Promise.all([p1, 2]).then(function (v) { r = v.join(); }); res1("one");~one,2', '~')]
    [TestCase('All rejects for a value that is not iterable', 'var r; Promise.all(5).catch(function (e) { r = e instanceof TypeError; });~true', '~')]
    [TestCase('All accepts a string', 'var r; Promise.all("ab").then(function (v) { r = v.join(); });~a,b', '~')]
    [TestCase('All calls resolve of the constructor', 'var r = 0; var resolve = Promise.resolve; Promise.resolve = function (v) { r++; return resolve.call(this, v); }; Promise.all([1, 2, 3]);~3', '~')]
    [TestCase('All rejects for a resolve that is no function', 'var r; var resolve = Promise.resolve; Promise.resolve = 1; Promise.all([]).catch(function (e) { r = e instanceof TypeError; }); Promise.resolve = resolve;~true', '~')]
    [TestCase('All closes the iterator when a step fails', 'var r = []; var it = { [Symbol.iterator]() { return { next() { return { done: false, value: 1 }; }, return() { r.push("closed"); return {}; } }; } }; var resolve = Promise.resolve; Promise.resolve = function () { throw "stop"; }; Promise.all(it).catch(function (e) { r.push(e); }); Promise.resolve = resolve;~closed,stop', '~')]
    [TestCase('Race settles with the first settled', 'var r; Promise.race([new Promise(function () {}), Promise.resolve("w"), Promise.reject("l")]).then(function (v) { r = v; });~w', '~')]
    [TestCase('Race of nothing stays pending', 'var r = "pending"; Promise.race([]).then(function () { r = "settled"; });~pending', '~')]
    [TestCase('AllSettled describes every outcome', 'var r; Promise.allSettled([1, Promise.reject("x")]).then(function (v) { r = JSON.stringify(v); });~[{"status":"fulfilled","value":1},{"status":"rejected","reason":"x"}]', '~')]
    [TestCase('Any takes the first fulfilment', 'var r; Promise.any([Promise.reject(1), Promise.resolve(2), Promise.resolve(3)]).then(function (v) { r = v; });~2', '~')]
    [TestCase('Any rejects with an AggregateError', 'var r; Promise.any([Promise.reject("a"), Promise.reject("b")]).catch(function (e) { r = (e.constructor === AggregateError) + e.errors.join() + e.name; });~truea,bAggregateError', '~')]
    [TestCase('Any of nothing rejects', 'var r; Promise.any([]).catch(function (e) { r = e.errors.length + e.name; });~0AggregateError', '~')]
    procedure Combinators_FollowSpecification(const Script, Expected: string);

    [Test]
    [TestCase('WithResolvers exposes the resolving functions', 'var r; var w = Promise.withResolvers(); w.promise.then(function (v) { r = v; }); w.resolve("wr");~wr', '~')]
    [TestCase('Try catches synchronous errors', 'var r = []; Promise.try(function (a, b) { return a + b; }, 1, 2).then(function (v) { r.push(v); }); Promise.try(function () { throw "t"; }).catch(function (e) { r.push(e); });~3,t', '~')]
    [TestCase('Resolve returns the same promise', 'var p = Promise.resolve(1); var r = (Promise.resolve(p) === p);~true', '~')]
    [TestCase('Resolve wraps a value', 'var r; Promise.resolve(7).then(function (v) { r = v; });~7', '~')]
    [TestCase('The constructor needs new', 'var r; try { Promise(function () {}); } catch (e) { r = e instanceof TypeError; }~true', '~')]
    [TestCase('The executor must be callable', 'var r; try { new Promise(1); } catch (e) { r = e instanceof TypeError; }~true', '~')]
    [TestCase('Then needs a promise', 'var r; try { Promise.prototype.then.call({}, function () {}); } catch (e) { r = e instanceof TypeError; }~true', '~')]
    [TestCase('Static methods need an object', 'var r = []; [Promise.resolve, Promise.reject, Promise.all, Promise.race].forEach(function (f) { try { f.call(1, 1); } catch (e) { r.push(e instanceof TypeError); } });~true,true,true,true', '~')]
    [TestCase('The members have their lengths and names', 'var r = [Promise.length, Promise.name, Promise.prototype.then.length, Promise.all.length, Promise.withResolvers.length, Object.prototype.toString.call(Promise.resolve())].join();~1,Promise,2,1,0,[object Promise]', '~')]
    [TestCase('The prototype is not writable', 'var d = Object.getOwnPropertyDescriptor(Promise, "prototype"); var r = [d.writable, d.enumerable, d.configurable].join();~false,false,false', '~')]
    [TestCase('Species is the constructor', 'var r = (Promise[Symbol.species] === Promise);~true', '~')]
    [TestCase('Resolving functions have a length and a name', 'var f; new Promise(function (res, rej) { f = [res, rej]; }); var r = [f[0].length, f[1].length, f[0].name === "", f[0].hasOwnProperty("prototype")].join();~1,1,true,false', '~')]
    [TestCase('Resolving functions are no constructors', 'var f; new Promise(function (res) { f = res; }); var r; try { new f(); } catch (e) { r = e instanceof TypeError; }~true', '~')]
    [TestCase('A subclass keeps its type', 'class P extends Promise {} var p = P.resolve(1); var q = p.then(function () {}); var r = (p instanceof P) + "," + (q instanceof P) + "," + (P.all([]) instanceof P);~true,true,true', '~')]
    [TestCase('A subclass constructor sees the executor', 'var n = 0; class P extends Promise { constructor(ex) { n++; super(ex); } } P.resolve(1).then(function () {}); var r = n;~2', '~')]
    [TestCase('Species can pick another constructor', 'function C(ex) { ex(function () {}, function () {}); } var p = Promise.resolve(1); p.constructor = { [Symbol.species]: C }; var q = p.then(function () {}); var r = (q instanceof C);~true', '~')]
    [TestCase('A species that is no constructor throws', 'var p = Promise.resolve(1); p.constructor = { [Symbol.species]: 5 }; var r; try { p.then(function () {}); } catch (e) { r = e instanceof TypeError; }~true', '~')]
    [TestCase('Unhandled rejections do not escape', 'var r = "ran"; Promise.reject(new Error("unhandled")); new Promise(function () { throw 1; }); Promise.all([Promise.reject(2)]);~ran', '~')]
    [TestCase('AggregateError holds the errors', 'var e = new AggregateError([1, 2], "m"); var r = [e.errors.join(), e.message, e instanceof Error, e.name, Object.keys(e).length, AggregateError.length].join();~1,2,m,true,AggregateError,0,2', '~')]
    procedure Promise_FollowsSpecification(const Script, Expected: string);

    [Test]
    procedure Execute_WhenTheScriptThrows_StillRunsTheJobs;

    [Test]
    procedure Execute_WhenTheStepBudgetRunsOut_StopsTheJobs;

    [Test]
    procedure Execute_WithJobsThatLoopForever_EndsWithTheStepBudget;

    [Test]
    procedure RunPendingJobs_WithoutJobs_DoesNothing;

    [Test]
    procedure Execute_WithALongPromiseChain_Completes;

    [Test]
    procedure Execute_WithAThenableThatNeverResolves_LeavesThePromisePending;

    [Test]
    procedure CollectGarbage_WithPendingReactions_KeepsTheCallbacks;

    [Test]
    procedure Execute_WithManyCombinedPromises_Completes;
  end;

implementation

procedure TPromiseTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPromiseTests.TearDown;
begin
  FEngine.Free;
end;

function TPromiseTests.RunAndRead(const Script: string): string;
begin
  FEngine.Execute(Script);

  Result := FEngine.Evaluate('String(r)').ToString;
end;

procedure TPromiseTests.Then_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TPromiseTests.Finally_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TPromiseTests.Combinators_FollowSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TPromiseTests.Promise_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TPromiseTests.Execute_WhenTheScriptThrows_StillRunsTheJobs;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var r = "no"; Promise.resolve().then(function () { r = "yes"; }); throw new Error("script");');
    end);

  Assert.AreEqual('yes', FEngine.Evaluate('r').ToString);
end;

procedure TPromiseTests.Execute_WhenTheStepBudgetRunsOut_StopsTheJobs;
begin
  FEngine.StepBudget := 2000;
  FEngine.Execute('var r = "no"; Promise.resolve().then(function () { r = "yes"; });');
  Assert.AreEqual('yes', FEngine.Evaluate('r').ToString);

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('Promise.resolve().then(function () { r = "queued"; }); while (true) { }');
    end,
    EJSStepBudgetExceeded);

  FEngine.RunPendingJobs;
  Assert.AreEqual('yes', FEngine.Evaluate('r').ToString);
end;

procedure TPromiseTests.Execute_WithJobsThatLoopForever_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := 100000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var f = function () { Promise.resolve().then(f); }; f();');
    end,
    EJSStepBudgetExceeded);

  FEngine.StepBudget := 100000;
  Assert.AreEqual('3', FEngine.Evaluate('1 + 2').ToString);
end;

procedure TPromiseTests.RunPendingJobs_WithoutJobs_DoesNothing;
begin
  FEngine.RunPendingJobs;
  FEngine.Execute('var r = 1;');
  FEngine.RunPendingJobs;

  Assert.AreEqual('1', FEngine.Evaluate('r').ToString);
end;

procedure TPromiseTests.Execute_WithALongPromiseChain_Completes;
begin
  const Script = 'var r = 0; var p = Promise.resolve(0); for (var i = 0; i < 100000; i++) { p = p.then(function (v) { return v + 1; }); } ' +
                 'p.then(function (v) { r = v; });';

  Assert.AreEqual('100000', RunAndRead(Script));
end;

procedure TPromiseTests.Execute_WithAThenableThatNeverResolves_LeavesThePromisePending;
begin
  const Script = 'var r = "pending"; Promise.resolve({ then: function () { } }).then(function () { r = "settled"; });';

  Assert.AreEqual('pending', RunAndRead(Script));
end;

procedure TPromiseTests.CollectGarbage_WithPendingReactions_KeepsTheCallbacks;
begin
  FEngine.Execute('var r = "no"; var res; new Promise(function (a) { res = a; }).then(function (v) { r = "ok" + v; });');

  FEngine.CollectGarbage;
  FEngine.Execute('res(1);');

  Assert.AreEqual('ok1', FEngine.Evaluate('r').ToString);
end;

procedure TPromiseTests.Execute_WithManyCombinedPromises_Completes;
begin
  const Script = 'var r = 0; var items = []; for (var i = 0; i < 20000; i++) { items.push(Promise.resolve(i)); } ' +
                 'Promise.all(items).then(function (v) { r = v.length; });';

  Assert.AreEqual('20000', RunAndRead(Script));
end;

end.
