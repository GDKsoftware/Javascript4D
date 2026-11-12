unit JS4D.Tests.Generators;

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
  TGeneratorTests = class
  private
    FEngine: TJSEngine;

    function RunAndRead(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Yields in order', 'function* g() { yield 1; yield 2; yield 3; } var r = [...g()].join();~1,2,3', '~')]
    [TestCase('Return value ends the iteration', 'function* g() { yield 1; return 2; } var it = g(); var a = it.next(); var b = it.next(); var c = it.next(); var r = JSON.stringify([a, b, c]);~[{"value":1,"done":false},{"value":2,"done":true},{"done":true}]', '~')]
    [TestCase('Nothing runs before the first next', 'var log = []; function* g() { log.push("body"); yield 1; } var it = g(); log.push("created"); it.next(); var r = log.join();~created,body', '~')]
    [TestCase('The sent value is the result of yield', 'function* g() { var a = yield 1; var b = yield a + 1; return a + b; } var it = g(); it.next(); it.next(10); var last = it.next(5); var r = last.value + "," + last.done;~15,true', '~')]
    [TestCase('The first next argument is ignored', 'function* g() { var a = yield 1; return a; } var it = g(); it.next("ignored"); var r = it.next("kept").value;~kept', '~')]
    [TestCase('Yield without operand yields undefined', 'function* g() { var x = yield; return x; } var it = g(); var a = it.next(); var b = it.next(7); var r = String(a.value) + b.value;~undefined7', '~')]
    [TestCase('Generator expression', 'var g = function* () { yield "a"; yield "b"; }; var r = Array.from(g()).join("");~ab', '~')]
    [TestCase('Named generator expression sees its name', 'var g = function* me() { yield typeof me; }; var r = g().next().value;~function', '~')]
    [TestCase('Arguments and this reach the body', 'function* g(a, b) { yield this.x; yield arguments.length; yield a + b; } var it = g.call({ x: "t" }, 1, 2); var r = [...it].join();~t,2,3', '~')]
    [TestCase('Parameters are bound when the generator is called', 'var log = []; function* g(a = log.push("default")) { log.push("body"); } var it = g(); log.push("called"); it.next(); var r = log.join();~default,called,body', '~')]
    [TestCase('A parameter error is thrown by the call', 'function* g(a = (function () { throw new RangeError("p"); })()) { } var r; try { g(); } catch (e) { r = e.name; }~RangeError', '~')]
    [TestCase('Closures keep the generator scope', 'function* g() { var n = 0; while (true) { var f = function () { return n; }; n = yield f; } } var it = g(); var f1 = it.next().value; var f2 = it.next(5).value; var r = f1() + "," + f2();~5,5', '~')]
    [TestCase('Generator object prototype is the prototype of the function', 'function* g() { } var r = Object.getPrototypeOf(g()) === g.prototype;~true', '~')]
    [TestCase('Prototype of the generator object falls back when the property is no object', 'function* g() { } g.prototype = null; var r = Object.getPrototypeOf(g()) === Object.getPrototypeOf(function* () { }).prototype;~true', '~')]
    [TestCase('Prototype chain of generators', 'function* g() { } var GP = Object.getPrototypeOf(g); var r = [typeof GP.prototype.next, typeof GP.prototype.return, typeof GP.prototype.throw, GP.prototype[Symbol.toStringTag], GP[Symbol.toStringTag]].join();~function,function,function,Generator,GeneratorFunction', '~')]
    [TestCase('Generator objects are iterators', 'function* g() { yield 1; } var it = g(); var r = (it[Symbol.iterator]() === it) + "," + Object.prototype.toString.call(it);~true,[object Generator]', '~')]
    [TestCase('Generator function has no own constructor on its prototype', 'function* g() { } var r = g.prototype.hasOwnProperty("constructor") + "," + (Object.getPrototypeOf(g.prototype) === Object.getPrototypeOf(function* () { }).prototype);~false,true', '~')]
    [TestCase('Generator functions are not constructors', 'function* g() { } var r; try { new g(); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('Generator methods are not constructors', 'var o = { *m() { } }; var r; try { new o.m(); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('GeneratorFunction constructor builds generators', 'var GF = Object.getPrototypeOf(function* () { }).constructor; var g = new GF("a", "yield a; yield a * 2;"); var r = [...g(4)].join() + "," + GF.name;~4,8,GeneratorFunction', '~')]
    [TestCase('Generators have the name of the declaration', 'function* gen() { } var r = gen.name + "," + gen.length;~gen,0', '~')]
    procedure Generator_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('A generator that runs its own body while evaluating a remembered expression', 'function* g(n) { return (n > 0 ? g(n - 1).next().value : 0) + (yield n); } var it = g(2); var a = it.next().value; var b = it.next(10).value; var r = a + "," + b;~2,11', '~')]
    [TestCase('Yield inside a binary expression', 'function* g() { var x = 1 + (yield 1) * 2; return x; } var it = g(); it.next(); var r = it.next(5).value;~11', '~')]
    [TestCase('Operands before the yield are not evaluated again', 'var log = []; function f(n) { log.push(n); return n; } function* g() { return f(1) + (yield f(2)) + f(3); } var it = g(); it.next(); var v = it.next(10).value; var r = log.join() + ":" + v;~1,2,3:14', '~')]
    [TestCase('The left operand keeps its value', 'var x = 1; function* g() { return x + (yield); } var it = g(); it.next(); x = 100; var r = it.next(1).value;~2', '~')]
    [TestCase('Two yields in one expression', 'function* g() { return (yield 1) + (yield 2); } var it = g(); var a = it.next().value; var b = it.next(10).value; var c = it.next(20); var r = [a, b, c.value, c.done].join();~1,2,30,true', '~')]
    [TestCase('Yield as a call argument', 'function add(a, b) { return a + b; } function* g() { return add(yield 1, yield 2); } var it = g(); it.next(); it.next(3); var r = it.next(4).value;~7', '~')]
    [TestCase('Yield as a method call argument keeps this', 'var o = { v: 5, m: function (a) { return this.v + a; } }; function* g() { return o.m(yield); } var it = g(); it.next(); var r = it.next(1).value;~6', '~')]
    [TestCase('Yield in an array literal', 'function* g() { return [1, yield "a", 3, yield "b"]; } var it = g(); it.next(); it.next("x"); var r = it.next("y").value.join();~1,x,3,y', '~')]
    [TestCase('Yield in an object literal', 'function* g() { return { a: yield 1, [yield 2]: "k", c: 3 }; } var it = g(); it.next(); it.next("A"); var o = it.next("key").value; var r = [o.a, o.key, o.c].join();~A,k,3', '~')]
    [TestCase('Yield in a conditional', 'function* g() { return (yield 1) ? yield 2 : yield 3; } var it = g(); it.next(); var a = it.next(false).value; var b = it.next("alt").value; var r = a + "," + b;~3,alt', '~')]
    [TestCase('Yield in a logical expression', 'function* g() { var a = (yield 1) || (yield 2); return a; } var it = g(); it.next(); it.next(0); var r = it.next("second").value;~second', '~')]
    [TestCase('Logical expression short circuits', 'function* g() { var a = (yield 1) && (yield 2); return a; } var it = g(); it.next(); var x = it.next(0); var r = x.value + "," + x.done;~0,true', '~')]
    [TestCase('Yield in an assignment target position', 'var o = {}; function* g() { o[yield "k"] = yield "v"; } var it = g(); it.next(); it.next("key"); it.next("value"); var r = o.key;~value', '~')]
    [TestCase('Yield in a compound assignment', 'function* g() { var x = 10; x += yield; return x; } var it = g(); it.next(); var r = it.next(5).value;~15', '~')]
    [TestCase('Yield in a template literal', 'function* g() { return `a${yield 1}b${yield 2}c`; } var it = g(); it.next(); it.next("X"); var r = it.next("Y").value;~aXbYc', '~')]
    [TestCase('Yield in a sequence expression', 'function* g() { return (yield 1, yield 2); } var it = g(); it.next(); it.next("a"); var r = it.next("b").value;~b', '~')]
    [TestCase('Yield in a unary expression', 'function* g() { return -(yield) + typeof (yield); } var it = g(); it.next(); it.next(3); var r = it.next("s").value;~-3string', '~')]
    [TestCase('Yield in new arguments', 'function P(a) { this.a = a; } function* g() { return new P(yield).a; } var it = g(); it.next(); var r = it.next("n").value;~n', '~')]
    [TestCase('Yield in a spread argument', 'function* g() { return Math.max(...(yield)); } var it = g(); it.next(); var r = it.next([1, 5, 2]).value;~5', '~')]
    [TestCase('Yield in a computed member', 'var a = ["x", "y"]; function* g() { return a[yield]; } var it = g(); it.next(); var r = it.next(1).value;~y', '~')]
    [TestCase('Yield in a computed class member', 'function* g() { class C { [yield "k"]() { return "m"; } } return new C().key(); } var it = g(); it.next(); var r = it.next("key").value;~m', '~')]
    [TestCase('Yield in a class heritage', 'function* g() { class C extends (yield) { } return new C().x; } var it = g(); it.next(); var r = it.next(function () { this.x = "hx"; }).value;~hx', '~')]
    [TestCase('Yield in a variable initializer', 'function* g() { let a = yield 1, b = yield 2; const c = a + b; return c; } var it = g(); it.next(); it.next(1); var r = it.next(2).value;~3', '~')]
    [TestCase('Yield in a destructuring source', 'function* g() { var [a, b] = yield; let { c } = yield; return a + b + c; } var it = g(); it.next(); it.next([1, 2]); var r = it.next({ c: 3 }).value;~6', '~')]
    [TestCase('Yield in a destructuring default', 'function* g() { var [a = yield "need a"] = []; return a; } var it = g(); var first = it.next().value; var r = first + "," + it.next("got").value;~need a,got', '~')]
    [TestCase('Arrow function inside a generator body', 'function* g() { var f = () => 1; yield f(); } var r = g().next().value;~1', '~')]
    procedure Yield_InExpressions(const Script, Expected: string);

    [Test]
    [TestCase('Yield in a while loop', 'function* g() { var i = 0; while (i < 3) { yield i++; } } var r = [...g()].join();~0,1,2', '~')]
    [TestCase('Yield in a do while loop', 'function* g() { var i = 0; do { yield i; } while (++i < 3); } var r = [...g()].join();~0,1,2', '~')]
    [TestCase('Yield in the head of a while loop', 'function* g() { var n = 0; while (yield n++) { } return n; } var it = g(); it.next(); it.next(true); it.next(true); var x = it.next(false); var r = x.value + "," + x.done;~3,true', '~')]
    [TestCase('Yield in a for loop', 'function* g() { for (var i = 0; i < 3; i++) { yield i * i; } } var r = [...g()].join();~0,1,4', '~')]
    [TestCase('Yield in every part of a for loop', 'function* g() { for (var i = yield "init"; (yield "test") < 5; i += yield "update") { return i; } } var it = g(); it.next(); it.next(1); var x = it.next(2); var r = x.value + "," + x.done;~1,true', '~')]
    [TestCase('For loop with a lexical binding gives closures their own value', 'function* g() { for (let i = 0; i < 3; i++) { yield function () { return i; }; } } var fs = [...g()]; var r = fs.map(function (f) { return f(); }).join();~0,1,2', '~')]
    [TestCase('Yield in a for of loop', 'function* g() { for (var x of [1, 2, 3]) { yield x * 2; } } var r = [...g()].join();~2,4,6', '~')]
    [TestCase('For of loop over a generator', 'function* inner() { yield "a"; yield "b"; } function* g() { for (const c of inner()) { yield c + c; } } var r = [...g()].join();~aa,bb', '~')]
    [TestCase('Yield in a for in loop', 'function* g() { for (var k in { a: 1, b: 2 }) { yield k; } } var r = [...g()].join();~a,b', '~')]
    [TestCase('Yield in the head of a for of loop', 'function* g() { for (var x of yield) { yield x; } } var it = g(); it.next(); var r = [it.next([7, 8]).value, it.next().value].join();~7,8', '~')]
    [TestCase('Break leaves a loop with a yield', 'function* g() { for (var i = 0; ; i++) { if (i == 2) break; yield i; } yield "end"; } var r = [...g()].join();~0,1,end', '~')]
    [TestCase('Continue skips to the next iteration', 'function* g() { for (var i = 0; i < 4; i++) { if (i % 2) continue; yield i; } } var r = [...g()].join();~0,2', '~')]
    [TestCase('Labelled break and continue', 'function* g() { outer: for (var i = 0; i < 3; i++) { for (var j = 0; j < 3; j++) { if (j == 1) continue outer; if (i == 2) break outer; yield i + "" + j; } } } var r = [...g()].join();~00,10', '~')]
    [TestCase('Yield in a switch', 'function* g(x) { switch (x) { case 1: yield "one"; case 2: yield "two"; break; default: yield "other"; } yield "after"; } var r = [...g(1)].join() + "|" + [...g(3)].join();~one,two,after|other,after', '~')]
    [TestCase('Yield in a switch case test', 'function* g() { switch (2) { case yield "t": return "match"; default: return "none"; } } var it = g(); it.next(); var r = it.next(2).value;~match', '~')]
    [TestCase('Yield in an if branch', 'function* g(c) { if (c) { yield "yes"; } else { yield "no"; } } var r = [...g(true)].join() + [...g(false)].join();~yesno', '~')]
    [TestCase('Yield in a block with lexical declarations', 'function* g() { { let a = 1; yield a; { let a = 2; yield a; } yield a; } } var r = [...g()].join();~1,2,1', '~')]
    [TestCase('Yield in a labelled block', 'function* g() { a: { yield 1; break a; } yield 2; } var r = [...g()].join();~1,2', '~')]
    [TestCase('Yield in a with statement', 'function* g() { with ({ v: "w" }) { yield v; yield typeof v; } } var r = [...g()].join();~w,string', '~')]
    [TestCase('Function declarations in a generator body are hoisted', 'function* g() { yield f(); function f() { return "hoisted"; } } var r = g().next().value;~hoisted', '~')]
    [TestCase('Recursion through yield star', 'function* walk(t) { if (t) { yield* walk(t.l); yield t.v; yield* walk(t.r); } } var tree = { v: 2, l: { v: 1 }, r: { v: 3 } }; var r = [...walk(tree)].join();~1,2,3', '~')]
    [TestCase('A loop of many yields completes', 'function* g() { for (var i = 0; i < 20000; i++) { yield i; } } var n = 0; for (var x of g()) { n += x; } var r = n;~199990000', '~')]
    procedure Yield_InStatements(const Script, Expected: string);

    [Test]
    [TestCase('Try catch around a yield', 'function* g() { try { yield 1; } catch (e) { yield "caught " + e; } } var it = g(); it.next(); var r = it.throw("boom").value;~caught boom', '~')]
    [TestCase('A thrown error inside the body is caught inside', 'function* g() { try { null.x; } catch (e) { yield e.name; } } var r = g().next().value;~TypeError', '~')]
    [TestCase('Throw that nobody catches reaches the caller', 'function* g() { yield 1; } var it = g(); it.next(); var r; try { it.throw(new RangeError("t")); } catch (e) { r = e.name; } r += "," + it.next().done;~RangeError,true', '~')]
    [TestCase('Finally runs on normal completion', 'var log = []; function* g() { try { yield 1; } finally { log.push("f"); } } var it = g(); it.next(); it.next(); var r = log.join();~f', '~')]
    [TestCase('Return runs the finally block', 'var log = []; function* g() { try { yield 1; yield 2; } finally { log.push("f"); } } var it = g(); it.next(); var x = it.return("done"); var r = log.join() + "," + x.value + "," + x.done;~f,done,true', '~')]
    [TestCase('A finally block can yield during return', 'function* g() { try { yield 1; } finally { yield "cleanup"; } } var it = g(); it.next(); var a = it.return("r"); var b = it.next(); var r = [a.value, a.done, b.value, b.done].join();~cleanup,false,r,true', '~')]
    [TestCase('A finally block can override the return value', 'function* g() { try { yield 1; } finally { return "override"; } } var it = g(); it.next(); var r = it.return("r").value;~override', '~')]
    [TestCase('A finally block can swallow a throw', 'function* g() { try { yield 1; } finally { return "swallowed"; } } var it = g(); it.next(); var r = it.throw(new Error("x")).value;~swallowed', '~')]
    [TestCase('Nested finally blocks run inner first', 'var log = []; function* g() { try { try { yield; } finally { log.push("inner"); } } finally { log.push("outer"); } } var it = g(); it.next(); it.return(); var r = log.join();~inner,outer', '~')]
    [TestCase('Return inside try with finally that yields keeps the completion', 'var log = []; function* g() { try { return "a"; } finally { log.push("f1"); yield "y"; log.push("f2"); } } var it = g(); var first = it.next(); var second = it.next(); var r = [first.value, first.done, second.value, second.done, log.join("+")].join();~y,false,a,true,f1+f2', '~')]
    [TestCase('Break through finally runs the finally', 'var log = []; function* g() { for (var i = 0; i < 3; i++) { try { if (i == 1) break; yield i; } finally { log.push("f" + i); } } } var r = [...g()].join() + "," + log.join();~0,f0,f1', '~')]
    [TestCase('Catch binding is scoped to the catch block', 'function* g() { try { throw 1; } catch (e) { yield e; } try { yield typeof e; } finally { } } var r = [...g()].join();~1,undefined', '~')]
    [TestCase('Throw at the start throws without running the body', 'var ran = false; function* g() { ran = true; yield 1; } var it = g(); var r; try { it.throw("early"); } catch (e) { r = e; } r += "," + ran + "," + it.next().done;~early,false,true', '~')]
    [TestCase('Return at the start completes the generator', 'var ran = false; function* g() { ran = true; yield 1; } var it = g(); var x = it.return("early"); var r = x.value + "," + x.done + "," + ran + "," + it.next().done;~early,true,false,true', '~')]
    [TestCase('After completion next is done and return passes the value', 'function* g() { } var it = g(); it.next(); var a = it.next(); var b = it.return(5); var r = [a.done, String(a.value), b.value, b.done].join();~true,undefined,5,true', '~')]
    [TestCase('After completion throw throws', 'function* g() { } var it = g(); it.next(); var r; try { it.throw("late"); } catch (e) { r = e; }~late', '~')]
    [TestCase('A generator that threw is completed', 'function* g() { throw "oops"; } var it = g(); var r; try { it.next(); } catch (e) { r = e; } r += "," + it.next().done;~oops,true', '~')]
    [TestCase('A running generator cannot be resumed', 'var it; function* g() { try { it.next(); } catch (e) { yield e.name; } } it = g(); var r = it.next().value;~TypeError', '~')]
    [TestCase('Methods reject receivers that are no generators', 'function* g() { } var next = g.prototype.next; var r = []; try { next.call({}); } catch (e) { r.push(e.name); } try { next.call(undefined); } catch (e) { r.push(e.name); } r = r.join();~TypeError,TypeError', '~')]
    [TestCase('Return method of a delegate is called when returning', 'var log = []; var inner = { [Symbol.iterator]() { return this; }, next() { return { value: 1, done: false }; }, return(v) { log.push("closed " + v); return { value: v, done: true }; } }; function* g() { yield* inner; } var it = g(); it.next(); var x = it.return("bye"); var r = log.join() + "," + x.value + "," + x.done;~closed bye,bye,true', '~')]
    [TestCase('For of closes the generator on break', 'var log = []; function* g() { try { yield 1; yield 2; } finally { log.push("closed"); } } for (var x of g()) { break; } var r = log.join();~closed', '~')]
    [TestCase('For of closes the generator when the body throws', 'var log = []; function* g() { try { yield 1; } finally { log.push("closed"); } } try { for (var x of g()) { throw "e"; } } catch (e) { } var r = log.join();~closed', '~')]
    [TestCase('A generator closes an iterator it iterates when it is returned', 'var log = []; function* inner() { try { yield 1; yield 2; } finally { log.push("inner done"); } } function* outer() { for (var x of inner()) { yield x; } } var it = outer(); it.next(); it.return(); var r = log.join();~inner done', '~')]
    procedure Generator_HandlesAbruptCompletion(const Script, Expected: string);

    [Test]
    [TestCase('Assignment pattern reads the iterator once across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b; [a, b = yield] = src; yield a + "," + b; } var gen = g(); gen.next(); var x = gen.next(7).value; var r = x + "|" + log.join("-");~5,7|next-next-return', '~')]
    [TestCase('Declaration pattern reads the iterator once across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var [a, b = yield] = src; yield a + "," + b; } var gen = g(); gen.next(); var x = gen.next(7).value; var r = x + "|" + log.join("-");~5,7|next-next-return', '~')]
    [TestCase('Lexical pattern reads the iterator once across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { const [a, b = yield] = src; yield a + "," + b; } var gen = g(); gen.next(); var x = gen.next(7).value; var r = x + "|" + log.join("-");~5,7|next-next-return', '~')]
    [TestCase('For of head pattern reads the iterator once across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; var out = []; function* g() { var a, b; for ([a, b = yield] of [src]) { out.push(a + "," + b); } } var gen = g(); gen.next(); gen.next(7); var r = out.join() + "|" + log.join("-");~5,7|next-next-return', '~')]
    [TestCase('Rest element keeps the values it collected across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b, c; [a, ...[b = yield, c]] = [1, undefined, 3]; yield [a, b, c].join(); } var gen = g(); gen.next(); var r = gen.next(7).value;~1,7,3', '~')]
    [TestCase('Nested pattern keeps its own position across a yield', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b, c; [[a, b = yield], c] = [src, 4]; yield [a, b, c].join(); } var gen = g(); gen.next(); var r = gen.next(7).value + "|" + log.join("-");~5,7,4|next-next-return', '~')]
    procedure Yield_InDestructuringPatterns(const Script, Expected: string);

    [Test]
    [TestCase('Return while suspended in a pattern closes the iterator', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b; [a, b = yield] = src; } var gen = g(); gen.next(); var x = gen.return(3); var r = x.value + "," + x.done + "|" + log.join("-");~3,true|next-next-return', '~')]
    [TestCase('Return while suspended in a for of head pattern closes the iterator', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b; for ([a, b = yield] of [src]) { } } var gen = g(); gen.next(); gen.return(3); var r = log.join("-");~next-next-return', '~')]
    [TestCase('Return while suspended in a pattern passes on an error of the return method', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; src.return = function () { throw "boom"; }; function* g() { var a, b; [a, b = yield] = src; } var gen = g(); gen.next(); var r; try { gen.return(3); } catch (e) { r = e; }~boom', '~')]
    [TestCase('Return while suspended in a pattern rejects a return result that is no object', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; src.return = function () { return null; }; function* g() { var a, b; [a, b = yield] = src; } var gen = g(); gen.next(); var r; try { gen.return(3); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('Throw while suspended in a pattern closes the iterator and keeps the thrown error', 'var log = []; var src = { [Symbol.iterator]() { return this; }, i: 0, next() { log.push("next"); return { value: [5, undefined, 8][this.i++], done: false }; }, return() { log.push("return"); return {}; } }; function* g() { var a, b; [a, b = yield] = src; } var gen = g(); gen.next(); var r; try { gen.throw("bad"); } catch (e) { r = e + "|" + log.join("-"); }~bad|next-next-return', '~')]
    procedure Return_WhileSuspendedInDestructuringPattern(const Script, Expected: string);

    [Test]
    [TestCase('Delegating yields every value of the inner iterable', 'function* g() { yield 0; yield* [1, 2]; yield 3; } var r = [...g()].join();~0,1,2,3', '~')]
    [TestCase('The value of yield star is the return value of the inner generator', 'function* inner() { yield 1; return "ret"; } function* g() { var v = yield* inner(); yield v; } var r = [...g()].join();~1,ret', '~')]
    [TestCase('Sent values reach the inner generator', 'function* inner() { var a = yield "i1"; var b = yield "i2"; return a + b; } function* g() { return yield* inner(); } var it = g(); it.next(); it.next("A"); var x = it.next("B"); var r = x.value + "," + x.done;~AB,true', '~')]
    [TestCase('Yield star over a string', 'function* g() { yield* "ab"; } var r = [...g()].join();~a,b', '~')]
    [TestCase('Throw is forwarded to the inner iterator', 'function* inner() { try { yield 1; } catch (e) { yield "inner caught " + e; } } function* g() { yield* inner(); } var it = g(); it.next(); var r = it.throw("T").value;~inner caught T', '~')]
    [TestCase('Throw without a throw method closes the inner iterator and throws a TypeError', 'var log = []; var inner = { [Symbol.iterator]() { return this; }, next() { return { value: 1, done: false }; }, return() { log.push("closed"); return {}; } }; function* g() { yield* inner; } var it = g(); it.next(); var r; try { it.throw("x"); } catch (e) { r = e.name; } r += "," + log.join();~TypeError,closed', '~')]
    [TestCase('Return is forwarded to the inner iterator', 'var log = []; function* inner() { try { yield 1; } finally { log.push("inner finally"); } } function* g() { yield* inner(); } var it = g(); it.next(); var x = it.return("R"); var r = log.join() + "," + x.value + "," + x.done;~inner finally,R,true', '~')]
    [TestCase('Return without a return method on the delegate completes', 'var inner = { [Symbol.iterator]() { return this; }, next() { return { value: 1, done: false }; } }; function* g() { yield* inner; } var it = g(); it.next(); var x = it.return("R"); var r = x.value + "," + x.done;~R,true', '~')]
    [TestCase('Yield star passes the inner result object on', 'var res = { value: "v", done: false, extra: "e" }; var inner = { [Symbol.iterator]() { return this; }, next() { return res; } }; function* g() { yield* inner; } var r = (g().next() === res);~true', '~')]
    [TestCase('Yield star reads next only once', 'var reads = 0; var inner = { [Symbol.iterator]() { var n = 0; return { get next() { reads++; return function () { return { done: n++ > 3, value: 1 }; }; } }; } }; function* g() { yield* inner; } [...g()]; var r = reads;~1', '~')]
    [TestCase('Yield star over something that is not iterable throws', 'function* g() { yield* 5; } var r; try { g().next(); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('Yield star requires an object from next', 'var inner = { [Symbol.iterator]() { return this; }, next() { return 1; } }; function* g() { yield* inner; } var r; try { g().next(); } catch (e) { r = e.name; }~TypeError', '~')]
    [TestCase('Nested delegation passes values through every level', 'function* a() { return (yield "a") + "!"; } function* b() { return yield* a(); } function* c() { return yield* b(); } var it = c(); it.next(); var x = it.next("v"); var r = x.value + "," + x.done;~v!,true', '~')]
    procedure YieldStar_FollowsSpecification(const Script, Expected: string);

    [Test]
    [TestCase('Spread of a generator', 'function* g() { yield 1; yield 2; } var r = Math.max(...g(), 0) + "," + [...g(), ...g()].length;~2,4', '~')]
    [TestCase('Array destructuring takes only what it needs and closes the generator', 'var log = []; function* g() { try { yield 1; yield 2; yield 3; } finally { log.push("closed"); } } var [a, b] = g(); var r = a + "," + b + "," + log.join();~1,2,closed', '~')]
    [TestCase('Rest in array destructuring drains the generator', 'function* g() { yield 1; yield 2; yield 3; } var [a, ...rest] = g(); var r = a + ":" + rest.join();~1:2,3', '~')]
    [TestCase('Array from, Map and Set accept generators', 'function* g() { yield [1, "a"]; yield [2, "b"]; } var m = new Map(g()); var s = new Set((function* () { yield 1; yield 1; yield 2; })()); var r = m.get(2) + "," + s.size + "," + Array.from(g(), function (p) { return p[0]; }).join("");~b,2,12', '~')]
    [TestCase('Generator methods in object literals', 'var o = { *items() { yield 1; yield 2; }, *[Symbol.iterator]() { yield* this.items(); } }; var r = [...o].join();~1,2', '~')]
    [TestCase('Generator methods in classes', 'class C { constructor() { this.v = [1, 2, 3]; } *[Symbol.iterator]() { for (const x of this.v) yield x; } static *count(n) { for (var i = 0; i < n; i++) yield i; } } var r = [...new C()].join() + "|" + [...C.count(3)].join();~1,2,3|0,1,2', '~')]
    [TestCase('Generator methods can use super', 'class A { *items() { yield "a"; } } class B extends A { *items() { yield* super.items(); yield "b"; } } var r = [...new B().items()].join();~a,b', '~')]
    [TestCase('Arrow functions inside a generator keep this and arguments', 'function* g() { var f = () => this.v + arguments[0]; yield f(); } var r = g.call({ v: 1 }, 2).next().value;~3', '~')]
    [TestCase('A generator can run another generator step by step', 'function* a() { yield 1; yield 2; } function* b() { var it = a(); yield it.next().value; yield it.next().value; yield 3; } var r = [...b()].join();~1,2,3', '~')]
    [TestCase('Strict mode generators have an undefined this', 'function* g() { "use strict"; yield this; } var r = String(g.call(undefined).next().value);~undefined', '~')]
    [TestCase('Yield is an identifier outside generators in sloppy code', 'var yield = 5; function f() { return yield; } var r = f();~5', '~')]
    [TestCase('Generators can be defined inside generators', 'function* outer() { function* inner() { yield "i"; } yield* inner(); yield "o"; } var r = [...outer()].join();~i,o', '~')]
    [TestCase('Fibonacci', 'function* fib() { var a = 0, b = 1; for (;;) { yield a; var t = a + b; a = b; b = t; } } var out = []; for (var x of fib()) { if (x > 50) break; out.push(x); } var r = out.join();~0,1,1,2,3,5,8,13,21,34', '~')]
    procedure Generator_WorksWithTheRestOfTheLanguage(const Script, Expected: string);

    [Test]
    [TestCase('Yield in a parameter default', 'function* g(a = yield) { }')]
    [TestCase('Yield as a binary operand', 'function* g() { 1 + yield; }')]
    [TestCase('Yield as a binding name', 'function* g() { var yield; }')]
    [TestCase('Yield as a label', 'function* g() { yield: 1; }')]
    [TestCase('Yield in an arrow parameter', 'function* g() { (a = yield) => 1; }')]
    [TestCase('Yield star without operand', 'function* g() { yield*; }')]
    [TestCase('Yield star after a line break', 'function* g() { yield\n* 1; }')]
    [TestCase('Yield in strict mode code', '"use strict"; function f() { var yield = 1; }')]
    [TestCase('Yield as the name of a generator expression', '(function* yield() { });')]
    [TestCase('Generator declaration as a statement body', 'if (1) function* g() { }')]
    [TestCase('Generator with a use strict directive and a default parameter', 'function* g(a = 1) { "use strict"; }')]
    [TestCase('Generator getter', 'class C { get *g() { } }')]
    [TestCase('Generator constructor', 'class C { *constructor() { } }')]
    procedure Parse_RejectsMisplacedYield(const Script: string);

    [Test]
    procedure Next_WhenEngineHasManyLiveGenerators_KeepsEachStateApart;

    [Test]
    procedure Next_WithDeepRecursionThroughYieldStar_EndsWithTheCallDepthLimit;

    [Test]
    procedure Next_WithEndlessGeneratorLoop_EndsWithTheStepBudget;

    [Test]
    procedure CollectGarbage_WithSuspendedGenerators_KeepsTheirScopes;

    [Test]
    procedure Free_WithGeneratorsSuspendedInsideTheirOwnObjects_ReleasesEverything;
  end;

implementation

procedure TGeneratorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TGeneratorTests.TearDown;
begin
  FEngine.Free;
end;

function TGeneratorTests.RunAndRead(const Script: string): string;
begin
  FEngine.Execute(Script);

  Result := FEngine.Evaluate('String(r)').ToString;
end;

procedure TGeneratorTests.Generator_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Yield_InExpressions(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Yield_InStatements(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Generator_HandlesAbruptCompletion(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Yield_InDestructuringPatterns(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Return_WhileSuspendedInDestructuringPattern(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.YieldStar_FollowsSpecification(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Generator_WorksWithTheRestOfTheLanguage(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, RunAndRead(Script));
end;

procedure TGeneratorTests.Parse_RejectsMisplacedYield(const Script: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSSyntaxError);
end;

procedure TGeneratorTests.Next_WhenEngineHasManyLiveGenerators_KeepsEachStateApart;
begin
  const Script = 'function* g(id) { var n = 0; for (;;) { yield id * 1000 + n++; } } ' +
                 'var gens = []; for (var i = 0; i < 200; i++) { gens.push(g(i)); } ' +
                 'var ok = true; for (var round = 0; round < 3; round++) { for (var i = 0; i < 200; i++) { ' +
                 'if (gens[i].next().value !== i * 1000 + round) { ok = false; } } } var r = ok;';

  Assert.AreEqual('true', RunAndRead(Script));
end;

procedure TGeneratorTests.Next_WithDeepRecursionThroughYieldStar_EndsWithTheCallDepthLimit;
begin
  FEngine.MaxCallDepth := 200;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('function* g(n) { yield* g(n + 1); } g(0).next();');
    end,
    EJSCallDepthExceeded);

  Assert.AreEqual('3', FEngine.Evaluate('1 + 2').ToString);
end;

procedure TGeneratorTests.Next_WithEndlessGeneratorLoop_EndsWithTheStepBudget;
begin
  FEngine.StepBudget := 100000;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('function* g() { while (true) { } } g().next();');
    end,
    EJSStepBudgetExceeded);
end;

procedure TGeneratorTests.CollectGarbage_WithSuspendedGenerators_KeepsTheirScopes;
begin
  FEngine.Execute('function* g() { var keep = { v: "alive" }; var f = function () { return keep.v; }; yield 1; yield f(); } ' +
                  'var it = g(); it.next();');

  FEngine.CollectGarbage;

  Assert.AreEqual('alive', FEngine.Evaluate('it.next().value').ToString);
end;

procedure TGeneratorTests.Free_WithGeneratorsSuspendedInsideTheirOwnObjects_ReleasesEverything;
begin
  FEngine.Execute('var it; function* g() { var self = { it: it }; yield self; yield [self]; } it = g(); it.next(); ' +
                  'var h = (function* () { yield { h: h }; })(); h.next();');

  Assert.AreEqual('object', FEngine.Evaluate('typeof it').ToString);
end;

end.
