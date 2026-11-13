unit JS4D.Tests.EngineLifetime;

{$SCOPEDENUMS ON}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Errors,
  JS4D.Types,
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
    [TestCase('Number conversions', 'Number("1.797693134862315807e+308"); (0.1).toFixed(40); (123.456).toPrecision(30); 0.1 + 0.2 + ""; (255).toString(16);', '#')]
    [TestCase('Regular expression accessors', 'var re = /a/g; re.source + re.flags + re.global;', '#')]
    [TestCase('Closure in a block', '{ let a = 1; var f = function () { return a; }; }', '#')]
    [TestCase('Function shared with discarded objects', '(function () { var f = function () { return f; }; Object.keys({ x: f, y: {} }); Object.keys([f, {}]); Object.freeze({ get: f }); return f(); })();', '#')]
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
    [TestCase('Symbol registry', 'var a = Symbol.for("a"); Symbol.keyFor(a); Symbol("x").description; String(Symbol("y"));', '#')]
    [TestCase('Symbol keyed closure', 'var o = {}; var s = Symbol(); o[s] = function () { return o; }; o[s]();', '#')]
    [TestCase('Symbol keyed method holding its own key', 'var s = Symbol(); var o = { [s]() { return s; }, get [Symbol("g")]() { return o; } };', '#')]
    [TestCase('Symbol keyed property on a function', 'function f() {} f[Symbol()] = f; Object.getOwnPropertySymbols(f);', '#')]
    [TestCase('Symbol keyed array and wrapper', 'var s = Symbol("w"); var a = [s]; a[s] = [s]; Object(s)[s] = Object(s); JSON.stringify(a);', '#')]
    [TestCase('Well-known symbol hooks', 'var o = { [Symbol.toPrimitive]() { return 1; }, [Symbol.hasInstance]() { return true; }, [Symbol.toStringTag]: "T" }; +o; 1 instanceof o; Object.prototype.toString.call(o);', '#')]
    [TestCase('Array species through proxies', 'function C() {} var a = [1, [2]]; a.constructor = { [Symbol.species]: C }; var p = new Proxy(new Proxy(a, {}), {}); Array.prototype.map.call(p, function (x) { return x; }); Array.prototype.flat.call(p); Array.prototype.slice.call(p);', '#')]
    [TestCase('Array locale string', 'var o = { toLocaleString: function () { return o; } }; [o, 1, null].toLocaleString = 0; Array.prototype.toLocaleString.call({ length: 1, 0: { toLocaleString: function () { return "x"; } } });', '#')]
    [TestCase('Array prototype elements', 'Array.prototype[1] = function () { return Array.prototype; }; Object.defineProperty(Array.prototype, "0", { configurable: true, get: function () { return Array.prototype; }, set: function (v) { Array.prototype; } }); [].push(1); [].unshift(1); delete Array.prototype[0]; delete Array.prototype[1]; Array.prototype.length = 0;', '#')]
    [TestCase('Array species constructor','function C() {} var a = [1, 2]; a.constructor = { [Symbol.species]: C }; a.map(function (x) { return x; }); a.slice(); a.concat(a);', '#')]
    [TestCase('Proxy as with object', 'var p = new Proxy({ x: 1 }, {}); function f() { with (p) { x++; x += 1; return x; } } f();', '#')]
    [TestCase('Typed array in a prototype chain', 'var r = Object.create(new Int8Array(2)); r[5] = 1; r[1] = 2; r.x = 3;', '#')]
    [TestCase('Unscopables in with', 'var o = { x: 1, y: 2, [Symbol.unscopables]: { x: true } }; with (o) { y; }', '#')]
    [TestCase('Symbols copied between objects', 'var s = Symbol(); var a = { [s]: () => a }; var b = Object.assign({}, a); var { [s]: f, ...r } = { ...a };', '#')]
    [TestCase('Array iterators', 'var it = [1, 2][Symbol.iterator](); it.next(); [...it]; [...[1].entries()]; for (var x of [1, 2].keys()) {}', '#')]
    [TestCase('String iterators', 'var it = "ab"[Symbol.iterator](); it.next(); [...it]; for (var c of "xy") {}', '#')]
    [TestCase('Iterator prototype chain', 'var p = Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]())); p[Symbol.iterator](); Object.getPrototypeOf(""[Symbol.iterator]());', '#')]
    [TestCase('Arguments iterator', '(function () { var o = { f: arguments }; return [...arguments, ...o.f]; })(1, 2);', '#')]
    [TestCase('Custom iterable closing over itself', 'var o = { [Symbol.iterator]() { var i = 0; var self = this; return { next() { return { done: i++ > 1, value: self }; }, return() { return {}; } }; } }; for (var x of o) { break; } var [a] = o; Array.from(o); [...o];', '#')]
    [TestCase('Iterator replaced on built-in prototypes', 'var p = Object.getPrototypeOf([][Symbol.iterator]()); var n = p.next; p.next = function () { return n.call(this); }; [...[1, 2]]; p.next = n; var s = String.prototype[Symbol.iterator]; String.prototype[Symbol.iterator] = function () { return s.call(this); }; [..."ab"]; String.prototype[Symbol.iterator] = s;', '#')]
    [TestCase('Iterator error thrown while iterating', 'var o = { [Symbol.iterator]() { return { next() { throw new Error("x"); }, return() { return {}; } }; } }; try { for (var x of o) {} } catch (e) {} try { var [a] = o; } catch (e) {} var p = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw 1; } }; } }; try { for (var y of p) { break; } } catch (e) {}', '#')]
    [TestCase('RegExp protocol methods', 'var r = /a/g; "aXa".replace(r, "b"); "a,b".split(/,/); "ab".match(/a/g); "ab".search(/b/); r[Symbol.replace]("a", "b"); r[Symbol.match]("a"); r[Symbol.split]("a"); r.test("a");', '#')]
    [TestCase('RegExp protocol with a custom exec', 'var r = /a/; r.exec = function () { return null; }; r[Symbol.match]("a"); r.test("a"); "a".replace(r, function () { return r; });', '#')]
    [TestCase('RegExp species constructor', 'var r = /b/; r.constructor = { [Symbol.species]: RegExp }; "abc".split(r);', '#')]
    [TestCase('Custom symbol methods on search values', 'var o = {}; o[Symbol.replace] = function () { return o; }; o[Symbol.split] = function () { return o; }; "a".replace(o, "b"); "a".split(o); "a".replaceAll(o, "b");', '#')]
    [TestCase('Library methods', 'Object.fromEntries([["a", () => 1]]); Object.setPrototypeOf({}, {}); Object.hasOwn({}, "a"); [1, [2]].flat(); [1].flatMap(x => [x]); [1].at(0); [1].includes(1); "a".at(0); String.fromCodePoint(65); "a".replaceAll("a", "b"); 2 ** 3;', '#')]
    [TestCase('Map and Set', 'var m = new Map([[1, {}], ["a", []]]); var s = new Set([1, "a", NaN]); m.set(m, s); m.forEach(function () {}); [...m]; [...s.entries()]; m.delete(1); s.clear();', '#')]
    [TestCase('Map and Set containing themselves', 'var m = new Map(); m.set(m, m); var s = new Set(); s.add(s); s.add(m);', '#')]
    [TestCase('Map holding a closure over itself', 'var m = new Map(); m.set("f", function () { return m; }); m.get("f")();', '#')]
    [TestCase('Collections holding their own iterators', 'var m = new Map(); m.set("it", m.keys()); m.set("e", m.entries()); var s = new Set(); s.add(s.values()); var w = new WeakMap(); var k = {}; w.set(k, w.has(k)); k.it = s[Symbol.iterator]();', '#')]
    [TestCase('Typed arrays and views inside collections', 'var m = new Map(); var a = new Uint8Array(4); m.set(a, a.buffer); m.set(a.buffer, new DataView(a.buffer)); a.m = m; a.buffer.m = m;', '#')]
    [TestCase('Unfinished collection iterators','var s = new Set([1, 2, 3]); var it = s.values(); it.next(); var m = new Map([[1, 2]]); var e = m.entries(); var k = m.keys(); k.next(); k.next();', '#')]
    [TestCase('Weak collections referencing their keys', 'var w = new WeakMap(); var k = {}; k.w = w; w.set(k, k); var ws = new WeakSet(); ws.add(k); k.ws = ws; w.set(w, ws);', '#')]
    [TestCase('Collection species and iterator accessors', 'Map[Symbol.species]; Set[Symbol.species]; Set.prototype[Symbol.iterator]; Object.getPrototypeOf(new Map().keys()).next.call(new Map().keys());', '#')]
    [TestCase('Collection constructor with an erroring iterable', 'var o = { [Symbol.iterator]() { return { next() { return { done: false, value: 1 }; }, return() { return {}; } }; } }; try { new Map(o); } catch (e) {} try { new WeakSet(o); } catch (e) {}', '#')]
    [TestCase('Proxy with trap closures', 'var h = { get(t, k, r) { return h; }, has() { return true; }, set() { return true; } }; var p = new Proxy({}, h); p.x; p.y = 1; "a" in p; var q = new Proxy(p, h); q.z;', '#')]
    [TestCase('Proxy returned by its own trap', 'var p = new Proxy({}, { get() { return p; } }); p.x;', '#')]
    [TestCase('Revocable proxy', 'var r = Proxy.revocable({}, { get() { return 1; } }); r.proxy.a; r.revoke(); try { r.proxy.a; } catch (e) {} var s = Proxy.revocable(function () {}, {}); s.proxy; ', '#')]
    [TestCase('Function proxy', 'var f = new Proxy(function () { return 1; }, { apply(t, th, a) { return t(); }, construct(t, a, n) { return {}; } }); f(); new f(); f.call(null); f.bind(null)();', '#')]
    [TestCase('Proxy in a prototype chain', 'var p = new Proxy({}, { get(t, k, r) { return r; }, set(t, k, v, r) { return true; }, has() { return true; } }); var o = Object.create(p); o.x; o.y = 1; "z" in o;', '#')]
    [TestCase('Proxy with ownKeys and descriptors', 'var s = Symbol(); var p = new Proxy({}, { ownKeys() { return ["a", s]; }, getOwnPropertyDescriptor() { return { value: 1, configurable: true, enumerable: true }; } }); Object.keys(p); Object.getOwnPropertySymbols(p); for (var k in p) {} Object.assign({}, p);', '#')]
    [TestCase('Proxy wrapping a proxy', 'var a = new Proxy({}, {}); var b = new Proxy(a, {}); b.x = 1; b.x; Object.keys(b); Array.isArray(b);', '#')]
    [TestCase('Reflect', 'Reflect.ownKeys({a: 1, [Symbol()]: 2}); Reflect.get({get a() { return this; }}, "a", {}); Reflect.set({}, "a", 1, {}); Reflect.construct(function () {}, [], function () {}); Reflect.apply(Math.max, null, [1, 2]); Reflect.defineProperty({}, "a", { get() { return 1; } });', '#')]
    [TestCase('Array buffer and typed arrays', 'var b = new ArrayBuffer(16); var a = new Int16Array(b, 2, 4); a.fill(3); a.set([1, 2], 1); a.subarray(1).slice(1); new Float32Array(a).map(x => x * 2).filter(x => x > 1); [...a]; ArrayBuffer.isView(a); b.slice(4);', '#')]
    [TestCase('Typed array statics and species', 'Uint8Array.from([1, 2], x => x + 1); Float64Array.of(1, 2); var T = Object.getPrototypeOf(Int8Array); T[Symbol.species]; var a = new Int8Array(2); a.constructor = { [Symbol.species]: Uint8Array }; a.slice(); a.map(x => x);', '#')]
    [TestCase('Typed array iterators and sorting', 'var a = new Uint8Array([3, 1, 2]); a.sort((x, y) => y - x); a.reverse(); [...a.entries()]; for (var k of a.keys()) {} var it = a.values(); it.next(); a.join(); a.toLocaleString(); a.indexOf(1); a.includes(2);', '#')]
    [TestCase('Typed array property holding an arrow function', 'var a = new Int8Array(3); a.f = () => a;', '#')]
    [TestCase('Eval declarations', '(function () { eval("var x = function () { return x; }; delete x; function g() { return g; }"); })(); (0, eval)("function h() { return h; } var v = function () { return h; }");', '#')]
    [TestCase('Typed array element callbacks', 'var a = new Int8Array(3); a.forEach(function (v, i, o) { o.length; }); a.every(function (v) { return v === 0; });', '#')]
    [TestCase('Typed array reduce and find', 'var a = new Int8Array(3); a.reduce((x, y) => x + y, 0); a.find(x => x === 0);', '#')]
    [TestCase('Typed array accessor returning the array', 'var a = new Int8Array(3); Object.defineProperty(a, "x", { get() { return a; } });', '#')]
    [TestCase('Sparse arrays', 'var a = []; a[4294967294] = () => a; a[3000000000] = [a]; Object.getOwnPropertyNames(a); delete a[3000000000]; var b = [1]; b[3500000000] = b; b.length = 1;', '#')]
    [TestCase('Symbol and string keys that look alike', 'var s = Symbol("k"); var o = { [s]: () => o, "\uFDD0100": () => o }; o[s](); o["\uFDD0100"](); Object.keys(o); Object.getOwnPropertySymbols(o); JSON.stringify(JSON.parse(''{"\uFDD0101": 1}''));', '#')]
    [TestCase('Array with conversion hooks', 'var a = [1]; a.toString = function () { return String(a.length); }; a[Symbol.toPrimitive] = () => a.length; String(a); a + 1; var o = {}; o[a] = a; var b = [a]; b.join = () => typeof b; String(b);', '#')]
    [TestCase('Replaced array prototype conversions', 'var t = Array.prototype.toString; Array.prototype.toString = function () { return String(this.length); }; String([1, [2]]); Array.prototype.toString = t; Array.prototype.valueOf = function () { return this; }; [1] + 1; delete Array.prototype.valueOf;', '#')]
    [TestCase('Accessor for __proto__', 'var o = { __proto__: { f: () => o } }; o.__proto__ = { g: () => o }; o.__proto__.g(); var d = Object.getOwnPropertyDescriptor(Object.prototype, "__proto__"); d.set.call(o, null); d.get.call(o); ({}).__proto__.x;', '#')]
    [TestCase('Prototype chain of many objects', 'var f = () => o; var o = { f }; for (var i = 0; i < 20000; i++) { o = Object.create(o); } o.f; "f" in o; o.x = 1; for (var k in o) { break; }', '#')]
    [TestCase('Prototype chain of arrays and proxies', 'var a = [() => a]; for (var i = 0; i < 100; i++) { a = Object.create(i % 2 ? a : new Proxy(a, {})); } a[0]; "z" in a; a.q;', '#')]
    [TestCase('Proxy with a native getPrototypeOf trap', 'var t = {}; var p = new Proxy(t, { getPrototypeOf: Reflect.getPrototypeOf }); Object.setPrototypeOf(t, {}); p instanceof Function;', '#')]
    [TestCase('Data view', 'var v = new DataView(new ArrayBuffer(16), 4, 8); v.setFloat64(0, 1.5, true); v.setInt16(0, 7); v.getFloat64(0, true); v.getUint8(1); v.buffer; DataView.prototype.getInt32.call(v, 4);', '#')]
    [TestCase('Cached push and pop', 'var a = [1]; a.push(2); a.pop(); var p = Array.prototype.push; Array.prototype.push = function() { return a; }; a.push(3); Array.prototype.push = p; a.push(4); a.shared; Object.setPrototypeOf(a, null); a.push;', '#')]
    [TestCase('Typed array with an erroring source', 'try { new Int8Array({ length: 2, get 0() { throw 1; } }); } catch (e) {} try { new Int8Array(new ArrayBuffer(4), 8); } catch (e) {} try { new DataView(new ArrayBuffer(1)).getInt32(0); } catch (e) {} try { Int8Array.from([1], 1); } catch (e) {}', '#')]
    [TestCase('Class with methods', 'class A { m() { return A; } static s() { return A; } get g() { return this; } set g(v) { A; } } new A().m(); A.s(); new A().g;', '#')]
    [TestCase('Class expression naming itself', 'var C = class D { static d() { return D; } }; C.d(); var E = class { e() { return E; } }; new E().e();', '#')]
    [TestCase('Class holding itself', 'class A {} A.self = A; A.prototype.cb = () => A; A.prototype.cb(); new A().me = A;', '#')]
    [TestCase('Class with computed names', 'var s = Symbol("k"); class A { [s]() { return A; } static [Symbol.iterator]() { return s; } ["x" + 1]() { return this; } } new A()[s]();', '#')]
    [TestCase('Derived class with super', 'class A { m() { return this; } } class B extends A { m() { return super.m(); } constructor() { super(); this.f = () => super.m(); } } new B().m(); new B().f();', '#')]
    [TestCase('Default derived constructor', 'class A {} class B extends A {} class C extends B {} new C(); C.prototype.constructor;', '#')]
    [TestCase('Arrow capturing the this binding', 'class A {} class B extends A { constructor() { var f = () => this; super(); this.g = f; this.h = () => super.constructor; } } new B().g(); new B().h();', '#')]
    [TestCase('Arrow calling super in a constructor', 'class A { constructor() { this.v = 1; } } class B extends A { constructor() { var f = () => super(); f(); this.w = () => f; } } new B();', '#')]
    [TestCase('Arrow capturing new.target', 'function F() { this.t = () => new.target; this.u = new.target; } new F().t(); class A { constructor() { this.n = () => new.target; } } new A().n();', '#')]
    [TestCase('Object literal with super', 'var o = { __proto__: { m() { return 1; } }, m() { return super.m(); }, get g() { return super.m; }, f: () => o }; o.m(); o.g; o.f();', '#')]
    [TestCase('Built-in subclasses', 'class L extends Array {} class E extends Error {} class M extends Map {} class S extends Set {} class R extends RegExp {} new L(1, 2); new E("x"); new M([[1, 2]]); new S([1]); new R("a");', '#')]
    [TestCase('Subclass of a proxy', 'function F() { this.x = 1; } var P = new Proxy(F, {}); class A extends P {} new A();', '#')]
    [TestCase('Class extending null', 'class A extends null { static s() { return super.name; } } A.s();', '#')]
    [TestCase('Reflect construct with a new target', 'class A { constructor() { this.t = new.target; } } function G() {} G.prototype = A.prototype; Reflect.construct(A, [], G).t;', '#')]
    [TestCase('Eval inside a method', 'class A { f() { return this; } } class B extends A { m() { return eval("super.f()"); } n() { return eval("() => super.f()"); } } new B().m(); new B().n()();', '#')]
    [TestCase('Class created in a loop', 'var cs = []; for (let i = 0; i < 3; i++) { cs.push(class { static i() { return i; } }); }', '#')]
    [TestCase('Subclass chain of many classes', 'var C = class {}; for (var i = 0; i < 50; i++) { C = class extends C {}; } new C();', '#')]
    [TestCase('Promise with pending reactions', 'var p = new Promise(function () {}); p.then(function () { return p; }); p.catch(function () {}); p.finally(function () {});', '#')]
    [TestCase('Resolve functions kept by the script', 'var res, rej; var p = new Promise(function (a, b) { res = a; rej = b; }); p.then(function () { return res; }); p.self = p; p.res = res; p.rej = rej;', '#')]
    [TestCase('Settled promise holding itself', 'var p = Promise.resolve({}); p.then(function (v) { v.p = p; p.v = v; });', '#')]
    [TestCase('Promise chain', 'var p = Promise.resolve(1); for (var i = 0; i < 50; i++) { p = p.then(function (v) { return v; }); }', '#')]
    [TestCase('Long promise chain', 'var p = Promise.resolve(1); for (var i = 0; i < 100000; i++) { p = p.then(function (v) { return v; }); }', '#')]
    [TestCase('Long chain of pending promises', 'var r; var p = new Promise(function (res) { r = res; }); var q = p; for (var i = 0; i < 100000; i++) { q = q.then(function (v) { return v; }); }', '#')]
    [TestCase('Thenable resolving a promise', 'var t = { then: function (res) { res(1); }, p: null }; t.p = Promise.resolve(t); t.p.then(function () { return t; });', '#')]
    [TestCase('Promise combinators', 'Promise.all([1, new Promise(function () {})]); Promise.race([new Promise(function () {})]); Promise.allSettled([Promise.reject(1), 2]); Promise.any([Promise.resolve(1)]); Promise.any([]); Promise.all([Promise.resolve(1)]).then(function (v) { return v; });', '#')]
    [TestCase('Combinator that never settles', 'var p = new Promise(function () {}); var all = Promise.all([p, p]); all.q = all; var any = Promise.any([p]); any.q = [any, all];', '#')]
    [TestCase('Rejected combinators', 'Promise.all([Promise.reject(1)]).catch(function () {}); Promise.any([Promise.reject(1), Promise.reject(2)]).catch(function (e) { return e.errors; });', '#')]
    [TestCase('Promise subclass', 'class P extends Promise {} P.resolve(1).then(function () {}); new P(function (res) { res(1); }).finally(function () {}); P.all([1]);', '#')]
    [TestCase('Promise finally and with resolvers', 'Promise.resolve(1).finally(function () { return 2; }); Promise.reject(1).finally(function () {}).catch(function () {}); var w = Promise.withResolvers(); w.promise.then(function () {}); w.resolve(w);', '#')]
    [TestCase('Promise species constructor', 'function C(ex) { ex(function () {}, function () {}); } var p = Promise.resolve(1); p.constructor = { [Symbol.species]: C }; p.then(function () {});', '#')]
    [TestCase('Promise rejected with a closure over itself', 'var p = Promise.reject(function () { return p; }); p.catch(function (f) { return f; });', '#')]
    [TestCase('Promise reaction creating promises', 'var f = function () { return Promise.resolve(f); }; Promise.resolve().then(f).then(f);', '#')]
    [TestCase('Promise try', 'Promise.try(function () { return Promise; }); Promise.try(function () { throw 1; }).catch(function () {});', '#')]
    [TestCase('Suspended generator', 'function* g() { var a = {}; yield a; yield a; } var it = g(); it.next();', '#')]
    [TestCase('Generator that is its own value', 'var it; function* g() { yield { it: it }; } it = g(); it.next();', '#')]
    [TestCase('Generator handed to its own body', 'function* g() { var self = yield; yield function () { return self; }; } var it = g(); it.next(); it.next(it);', '#')]
    [TestCase('Generator suspended in loops, try and switch', 'function* g() { for (let i = 0; i < 3; i++) { try { switch (i) { case 0: yield () => i; } } finally { } } } var it = g(); it.next();', '#')]
    [TestCase('Generator suspended in for of and for in', 'function* g() { for (const x of [() => g]) { yield x; } for (let k in { a: 1 }) { yield () => k; } } var it = g(); it.next(); it.next(); it.next();', '#')]
    [TestCase('Delegating generators', 'function* a() { yield function () { return a; }; } function* b() { yield* a(); } var it = b(); it.next();', '#')]
    [TestCase('Generator suspended inside an expression', 'var o = {}; function* g() { return [o, yield o, function () { return o; }, { k: yield }]; } o.it = g(); o.it.next(); o.it.next(o);', '#')]
    [TestCase('Generator suspended in a finally block', 'function* g() { try { yield 1; } finally { yield function () { return g; }; } } var it = g(); it.next(); it.return(5);', '#')]
    [TestCase('Generator methods', 'class C { *m() { yield this; } static *s() { yield C; } } var c = new C(); c.it = c.m(); c.it.next(); C.it = C.s(); C.it.next(); var o = { *m() { yield o; } }; o.it = o.m(); o.it.next();', '#')]
    [TestCase('Generator suspended inside an array pattern', 'var src = { [Symbol.iterator]() { return this; }, next() { return { value: undefined, done: false }; }, return() { return {}; } }; function* g() { var a, b; [a, b = yield () => src] = src; } var it = g(); it.next();', '#')]
    [TestCase('Generator suspended inside an array pattern in a for of head', 'var src = { [Symbol.iterator]() { return this; }, next() { return { value: undefined, done: false }; }, return() { return {}; } }; function* g() { var a, b; for ([a, b = yield () => g] of [src]) { } } var it = g(); it.next();', '#')]
    [TestCase('GeneratorFunction constructor', 'var GF = Object.getPrototypeOf(function* () { }).constructor; var g = new GF("a", "yield a; yield () => a;"); var it = g(1); it.next(); it.next();', '#')]
    [TestCase('Many suspended generators', 'function* g(i) { var v = { i: i }; yield v; yield v; } var all = []; for (var i = 0; i < 500; i++) { var it = g(i); it.next(); all.push(it); }', '#')]
    [TestCase('Generator with a pending completion in a finally block', 'var log = []; function* g() { try { try { throw { f: function () { return g; } }; } finally { yield 1; } } catch (e) { log.push(e); } } var it = g(); it.next(); var it2 = g(); it2.next();', '#')]
    [TestCase('Generator iterated by a loop of another generator', 'function* inner() { yield () => inner; yield 2; } function* outer() { for (var x of inner()) { yield x; } } var it = outer(); it.next();', '#')]
    [TestCase('Generator iterated by spread and destructuring', 'function* g() { yield function () { return g; }; yield 2; yield 3; } var a = [...g()]; var [b, ...c] = g(); var [d] = g();', '#')]
    [TestCase('Async function awaiting a promise that never settles', 'var gate = new Promise(function () {}); async function f() { var a = {}; await gate; return a; } f(); f();', '#')]
    [TestCase('Async function whose promise holds itself', 'var gate = new Promise(function () {}); async function f(x) { var o = { f: f, x: x }; await gate; return o; } var p = f(0); p.me = p; p.then(function (o) { return o; });', '#')]
    [TestCase('Async arrow that captures its own promise', 'var gate = new Promise(function () {}); var p = (async () => { await gate; return p; })(); p.q = [p];', '#')]
    [TestCase('Async function resolved with a closure over itself', 'async function f() { return function () { return f; }; } f().then(function (g) { g.f = f; });', '#')]
    [TestCase('Async methods', 'var gate = new Promise(function () {}); class C { async m() { await gate; return this; } static async s() { await gate; return C; } } var c = new C(); c.p = c.m(); c.q = C.s(); var o = { async m() { await gate; return o; } }; o.p = o.m();', '#')]
    [TestCase('Async method using super', 'var gate = new Promise(function () {}); class A { m() { return A; } } class B extends A { async m() { await gate; return super.m(); } } new B().m();', '#')]
    [TestCase('Async function awaiting settled promises in a loop', 'async function f() { for (var i = 0; i < 200; i++) { await i; } var o = { f: f }; return o; } f().then(function (o) { return o; });', '#')]
    [TestCase('Async function awaiting a rejected promise', 'async function f() { try { await Promise.reject({ f: f }); } catch (e) { e.q = [e.f]; } } f(); async function g() { await Promise.reject(g); } g().catch(function (e) { return e; });', '#')]
    [TestCase('Async function with try catch finally and awaits', 'var gate = new Promise(function () {}); async function f() { try { try { await gate; } finally { await gate; } } catch (e) { await gate; } } f();', '#')]
    [TestCase('Async function awaiting inside loops and switch', 'var gate = new Promise(function () {}); async function f() { for (let i = 0; i < 3; i++) { switch (i) { case 0: await gate; } } for (const x of [() => f]) { await gate; } } f();', '#')]
    [TestCase('Async function awaiting a thenable', 'var t = { then: function (res) { res({ f: f }); } }; async function f() { return await t; } f();', '#')]
    [TestCase('Async function awaiting itself through a thenable', 'var gate = new Promise(function () {}); async function f() { await { then: function (res) { res(f); } }; await gate; } f();', '#')]
    [TestCase('Returned promise adopted by an async function', 'var gate = new Promise(function () {}); async function g() { return gate; } async function f() { return g(); } f(); f();', '#')]
    [TestCase('Async functions called from async functions', 'var gate = new Promise(function () {}); async function a(n) { if (n > 0) { await a(n - 1); } await gate; } a(20);', '#')]
    [TestCase('AsyncFunction constructor', 'var AF = Object.getPrototypeOf(async function () { }).constructor; var g = new AF("a", "await a; return () => a;"); g(1); var gate = new Promise(function () {}); new AF("await gate;")();', '#')]
    [TestCase('Many suspended async functions', 'var gate = new Promise(function () {}); async function f(i) { var v = { i: i }; await gate; return v; } var all = []; for (var i = 0; i < 500; i++) { all.push(f(i)); }', '#')]
    [TestCase('Async function handed its own result', 'var holder = {}; async function f() { await 0; return holder.p; } holder.p = f(); holder.p.then(function (v) { return v; });', '#')]
    [TestCase('Async function with a pending job at the end of the script', 'async function f() { await 1; await 2; await 3; } f(); f();', '#')]
    [TestCase('JSON reviver walking a proxy for an array', 'var p = new Proxy([], {}); p.other = 0; JSON.parse("[null,null]", function (k, v) { this[1] = p; return v; });', '#')]
    [TestCase('JSON reviver walking a proxy for an object', 'var p = new Proxy({ length: 0, other: 0 }, {}); JSON.parse("[null,null]", function (k, v) { if (this !== p) { this[1] = p; } return v; });', '#')]
    [TestCase('JSON reviver with a throwing proxy length', 'var bad = new Proxy([], { get: function (t, n) { if (n === "length") { throw 1; } } }); try { JSON.parse("[0,0]", function () { this[1] = bad; }); } catch (e) {}', '#')]
    [TestCase('JSON holder with an inherited setter', 'Object.defineProperty(Object.prototype, "", { set: function () { throw 1; }, configurable: true }); JSON.parse("2", function (k, v) { return v; }); JSON.stringify(2, function (k, v) { return v; }); delete Object.prototype[""];', '#')]
    [TestCase('AggregateError', 'var e = new AggregateError([1, {}], "m"); AggregateError([1]); e.errors;', '#')]
    [TestCase('Two objects referring to each other', 'var a = {}; var b = {}; a.b = b; b.a = a;', '#')]
    [TestCase('Object holding itself', 'var a = {}; a.a = a; a[Symbol.iterator] = a; Object.defineProperty(a, "g", { value: a });', '#')]
    [TestCase('Object cycle through an accessor pair', 'var a = {}; var g = {}; Object.defineProperty(a, "x", { get: function () { return 1; }, set: function (v) {}, configurable: true }); a.g = g; g.a = a;', '#')]
    [TestCase('Cycle through the prototype', 'var a = {}; var b = Object.create(a); a.child = b; var c = {}; c.__proto__ = a; a.c = c;', '#')]
    [TestCase('Object created without a prototype', 'var a = Object.create(null); var b = Object.create(a); a.b = b; b.a = a;', '#')]
    [TestCase('Array containing itself', 'var a = []; a.push(a);', '#')]
    [TestCase('Arrays referring to each other', 'var a = [1, 2]; var b = [a]; a[5] = b; a.length = 10; b.x = a; a.y = b;', '#')]
    [TestCase('Sparse array holding itself', 'var a = []; a[4294967294] = a; a[3000000000] = [a]; a[0] = a;', '#')]
    [TestCase('Array of objects pointing back', 'var a = []; for (var i = 0; i < 10; i++) { a.push({ list: a, i: i }); }', '#')]
    [TestCase('Map with itself as key and value', 'var m = new Map(); m.set(m, m);', '#')]
    [TestCase('Set and map in a cycle', 'var s = new Set(); var m = new Map(); s.add(m); m.set("s", s); m.set(s, [m, s]);', '#')]
    [TestCase('Weak collections in a cycle', 'var k = {}; var w = new WeakMap(); w.set(k, w); k.w = w; var ws = new WeakSet(); ws.add(ws); ws.add(k);', '#')]
    [TestCase('Proxy whose target refers back', 'var t = {}; var p = new Proxy(t, {}); t.p = p;', '#')]
    [TestCase('Proxy whose handler refers back', 'var h = {}; var p = new Proxy({}, h); h.p = p; h.get = function (t, k) { return p; };', '#')]
    [TestCase('Proxy that is its own target through an array', 'var a = []; var p = new Proxy(a, {}); a.push(p); p.push(p);', '#')]
    [TestCase('Revoked proxy in a cycle', 'var o = {}; var r = Proxy.revocable(o, o); o.p = r.proxy; o.r = r; r.revoke();', '#')]
    [TestCase('Typed array and buffer in a cycle', 'var a = new Uint8Array(4); a.self = a; a.buffer.owner = a; a.view = new DataView(a.buffer); a.view.a = a;', '#')]
    [TestCase('Error holding itself', 'var e = new Error("x"); e.self = e; e.cause = e; var a = new AggregateError([e]); e.a = a;', '#')]
    [TestCase('Date regular expression and wrappers holding themselves', 'var d = new Date(0); d.d = d; var r = /a/g; r.r = r; var n = new Number(1); n.n = n; var s = new String("a"); s.s = s; var b = new Boolean(true); b.b = b;', '#')]
    [TestCase('Arguments object holding itself', '(function () { arguments.a = arguments; arguments[5] = arguments; var o = { args: arguments }; arguments.o = o; })(1, 2);', '#')]
    [TestCase('Iterator holding its source', 'var a = [1]; var it = a[Symbol.iterator](); a.it = it; it.a = a; var m = new Map([[1, 2]]); var mi = m.keys(); m.mi = mi; mi.m = m; var si = "ab"[Symbol.iterator](); si.si = si;', '#')]
    [TestCase('Bound function in a cycle', 'var o = {}; var f = function () { return o; }.bind(o); o.f = f; f.o = o;', '#')]
    [TestCase('Large ring of objects', 'var first = {}; var prev = first; for (var i = 0; i < 100000; i++) { var o = {}; prev.next = o; prev = o; } prev.next = first;', '#')]
    [TestCase('Large ring of arrays', 'var first = []; var prev = first; for (var i = 0; i < 100000; i++) { var o = []; prev.push(o); prev = o; } prev.push(first);', '#')]
    [TestCase('Large doubly linked list', 'var head = { prev: null, next: null }; var tail = head; for (var i = 0; i < 100000; i++) { var n = { prev: tail, next: null }; tail.next = n; tail = n; }', '#')]
    [TestCase('Large graph of mixed objects', 'var all = []; for (var i = 0; i < 20000; i++) { var o = { i: i, list: all, m: new Map(), arr: [] }; o.m.set(o, o); o.arr.push(o); all.push(o); }', '#')]
    [TestCase('Cycle through closures and objects', 'function make() { var a = {}; var b = { a: a }; a.b = b; a.f = function () { return b; }; return b; } var r = make(); r.self = r; r.g = function () { return r; };', '#')]
    [TestCase('Cycle through a scope and a plain object', '(function () { var o = {}; var p = { o: o }; o.p = p; })(); { let a = {}; let b = [a]; a.b = b; }', '#')]
    [TestCase('Objects cycling through class instances', 'class A { constructor() { this.me = this; this.list = [this]; } } var a = new A(); a.other = new A(); a.other.other = a; a.other.back = a.constructor;', '#')]
    [TestCase('Subclass instances referring to each other', 'class A { constructor(n) { this.n = n; } } class B extends A { constructor() { super(1); this.self = this; } } var b = new B(); var c = new B(); b.c = c; c.b = b; B.prototype.inst = b; A.cache = [b, c];', '#')]
    [TestCase('Class with static members referring to instances', 'class A { static make() { return new A(); } } A.inst = A.make(); A.inst.cls = A; A.list = [A.inst, A];', '#')]
    [TestCase('Promise settled with a cycle', 'var o = {}; o.p = Promise.resolve(o); var q = Promise.reject(o); q.catch(function () {}); o.q = q;', '#')]
    [TestCase('Pending promise referring to its value', 'var o = {}; var p = new Promise(function () {}); o.p = p; p.o = o; p.then(function () { return o; });', '#')]
    [TestCase('Promises held by objects of a cycle', 'var a = {}; var b = {}; a.b = b; b.a = a; a.p = Promise.resolve(b); b.p = new Promise(function (res) { res(a); });', '#')]
    [TestCase('Suspended generator holding a cycle', 'function* g() { var a = {}; var b = [a]; a.b = b; yield a; yield b; } var it = g(); it.next(); it.o = it;', '#')]
    [TestCase('Generator objects in a cycle', 'function* g(o) { yield o; } var a = {}; var b = { a: a }; a.b = b; a.it = g(b); a.it.next(); b.it = g(a);', '#')]
    [TestCase('Cycle reachable from the global object', 'globalThis.self = globalThis; var g = { g: globalThis }; g.g.g = g;', '#')]
    [TestCase('Cycle hanging from Object prototype', 'var a = {}; a.a = a; Object.prototype.hook = a;', '#')]
    [TestCase('Cycle hanging from Array prototype', 'var b = [1]; b.push(b); Array.prototype.other = b;', '#')]
    [TestCase('Cycle hanging from Function prototype', 'var a = {}; a.a = a; Function.prototype.f = [a];', '#')]
    [TestCase('Cycle hanging from Map prototype', 'var a = {}; a.a = a; Map.prototype.m = new Map([[a, a]]);', '#')]
    [TestCase('Cycle hanging from Promise prototype', 'var a = {}; a.a = a; Promise.prototype.p = a;', '#')]
    [TestCase('Cycle through a built-in constructor', 'var a = {}; a.ctor = Array; Array.cache = a; a.proto = Object.getPrototypeOf(a); Object.cache = [a]; Error.cache = new Error("x");', '#')]
    [TestCase('Cycles hanging from every built-in after using the features', 'new Proxy({}, {}); new Proxy(function () {}, {}); Promise.resolve(1).then(function () {}); function* g() { yield 1; } g().next(); (async function () { await 1; })(); new Uint8Array(2); new DataView(new ArrayBuffer(2)); /a/g.exec("a"); new Date(); JSON.stringify({ a: [1] }); Reflect.ownKeys({}); Symbol("x"); "x".split(""); [].concat([1]).map(function (x) { return x; }); new Map([[1, 2]]).keys().next(); new Set([1]).entries().next(); new WeakMap(); (1).toFixed(2); String(true); var a = {}; a.a = a; var names = Object.getOwnPropertyNames(globalThis); for (var i = 0; i < names.length; i++) { var c = globalThis[names[i]]; if (typeof c === "function") { try { c.__cycle = [a]; if (c.prototype) { c.prototype.__cycle = [a]; } } catch (e) {} } } Object.getPrototypeOf(function* () {}).__cycle = a; Object.getPrototypeOf(async function () {}).__cycle = a; Object.getPrototypeOf([][Symbol.iterator]()).__cycle = a; Object.getPrototypeOf(new Map().keys()).__cycle = a; Object.getPrototypeOf(Int8Array).prototype.__cycle = a; String.prototype.__cycle = a; Number.prototype.__cycle = a; Boolean.prototype.__cycle = a; Symbol.prototype.__cycle = a;', '#')]
    [TestCase('Async function holding a cycle', 'var gate = new Promise(function () {}); async function f() { var a = {}; a.a = a; await gate; return a; } var o = { p: f() }; o.o = o;', '#')]
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
    [TestCase('Symbol conversion error', 'var s = Symbol("e"); var o = { [s]: () => o }; s + 1;', '#')]
    [TestCase('Error in a symbol hook', 'var o = { [Symbol.toPrimitive]() { throw new Error("x"); } }; +o;', '#')]
    [TestCase('Regular expression with surrogate escapes', '/\ud834\udf06/u.test("\ud834\udf06"); /[\ud800-\udbff]/i.test("a"); /^\S$/.exec("x");', '#')]
    [TestCase('Built-in functions share the function prototype', 'Object.getPrototypeOf(Math.max) === Function.prototype; String(Object.keys);', '#')]
    [TestCase('Replaced built-in methods', 'var a = [1]; a.push = function() { return a; }; a.push(2); Array.prototype.toString = Object.prototype.toString; String(a); var f = function() {}; f.call = function() { return f; }; f.call();', '#')]
    [TestCase('Derived constructor without super call', 'class A {} class B extends A { constructor() { this.f = () => B; } } new B();', '#')]
    [TestCase('Derived constructor using this in an arrow too early', 'class A {} class B extends A { constructor() { var f = () => this; f(); } } new B();', '#')]
    [TestCase('Derived constructor calling super twice', 'class A { constructor() { this.a = () => A; } } class B extends A { constructor() { super(); super(); } } new B();', '#')]
    [TestCase('Derived constructor returning a primitive', 'class A {} class B extends A { constructor() { super(); this.f = () => B; return 1; } } new B();', '#')]
    [TestCase('Class extending a non constructor', 'var o = { m() {} }; class A extends o.m {}', '#')]
    [TestCase('Class with a failing heritage', 'class A extends Missing { m() { return A; } }', '#')]
    [TestCase('Class with a failing computed name', 'class A { [null.x]() { return A; } }', '#')]
    [TestCase('Class with a static prototype member', 'class A { static ["prototype"]() { return A; } }', '#')]
    [TestCase('Class called without new', 'class A { m() { return A; } } A();', '#')]
    [TestCase('Class with an invalid method', 'class A { m() {} constructor() {} constructor() {} }', '#')]
    [TestCase('Super property of null', 'class A extends null { m() { return super.x; } } A.prototype.m.call({});', '#')]
    [TestCase('Super call to a non constructor', 'class A {} class B extends A { constructor() { super(); } } Object.setPrototypeOf(B, {}); new B();', '#')]
    [TestCase('Error thrown by a class constructor', 'class A { constructor() { this.f = () => A; throw new Error("x"); } } new A();', '#')]
    [TestCase('Error thrown by the parent constructor', 'class A { constructor() { throw new Error("x"); } } class B extends A { constructor() { var f = () => super(); f(); } } new B();', '#')]
    [TestCase('Promise jobs pending after a script error', 'Promise.resolve().then(function () { return Promise; }); new Promise(function (res) { res(1); }).then(function () {}); throw new Error("x");', '#')]
    [TestCase('Generator that throws', 'function* g() { yield 1; throw new Error("x"); } var it = g(); it.next(); it.next();', '#')]
    [TestCase('Generator suspended when the script fails', 'function* g() { try { yield { f: function () { return g; } }; } finally { yield 2; } } var it = g(); it.next(); it.return(1); throw new Error("x");', '#')]
    [TestCase('Async function awaiting when the script fails', 'var gate = new Promise(function () {}); async function f() { var o = { f: f }; await gate; return o; } f(); throw new Error("x");', '#')]
    [TestCase('Async function that throws', 'async function f() { var o = { f: f }; await 0; throw o; } f(); f().catch(function (e) { return e; });', '#')]
    [TestCase('Async function with a failing parameter default', 'async function f(a = () => f, b = null.x) { } f(); f().catch(function () { });', '#')]
    [TestCase('Binary operator without a right operand', 'for (var i = 0; i < 2000; i++) { try { eval("1 + "); } catch (e) { } }', '#')]
    [TestCase('Logical operator without a right operand', 'for (var i = 0; i < 2000; i++) { try { eval("a && "); } catch (e) { } }', '#')]
    [TestCase('Member access without a name', 'for (var i = 0; i < 2000; i++) { try { eval("var a; a."); } catch (e) { } }', '#')]
    [TestCase('Computed member access that is not closed', 'for (var i = 0; i < 2000; i++) { try { eval("var a; a[1"); } catch (e) { } }', '#')]
    [TestCase('Exponentiation without a right operand', 'for (var i = 0; i < 2000; i++) { try { eval("2 ** "); } catch (e) { } }', '#')]
    [TestCase('Long chain of additions', 'eval("1" + "+1".repeat(100000)); try { eval("1" + "+1".repeat(100000) + "+"); } catch (e) { }', '#')]
    [TestCase('Long chain of members and calls', 'var o = {}; o.b = function () { return o; }; try { eval("o" + ".b()".repeat(100000)); } finally { o.b = null; }', '#')]
    [TestCase('Long chain with a yield that is not resumed', 'var g = eval("(function* () { return (yield 1)" + "+1".repeat(100000) + "; })"); var it = g(); it.next();', '#')]
    [TestCase('Long chain with a yield that runs out of stack', 'var g = eval("(function* () { return (yield 1)" + "+1".repeat(100000) + "; })"); var it = g(); it.next(); try { it.next(1); } catch (e) { }', '#')]
    [TestCase('Long chain with a pending await', 'var f = eval("(async function () { return (await 1)" + "+1".repeat(100000) + "; })"); f();', '#')]
    [TestCase('Source that nests too deeply', 'for (var i = 0; i < 3; i++) { try { eval("{".repeat(100000) + "}".repeat(100000)); } catch (e) { } }', '#')]
    [TestCase('Statement nesting that is parsed', 'eval("if (1) ".repeat(900) + "1;");', '#')]
    [TestCase('Array conversions that change the prototype chain', 'for (var i = 0; i < 3; i++) { String([i]); Array.prototype.toString = function () { return "T"; }; String([i]); Object.setPrototypeOf(Array.prototype, { toString: Object.prototype.toString }); String([i]); }', '#')]
    [TestCase('Objects of a cycle when the script fails', 'var a = {}; var b = [a, new Map([[a, a]])]; a.b = b; var p = new Proxy(a, {}); a.p = p; throw new Error("x");', '#')]
    procedure Engine_AfterScriptError_ReleasesAllMemory(const Script: string);

    [Test]
    [TestCase('Objects', 'var a = null; (function () { for (var i = 0; i < n; i++) { a = { n: a }; } })();', '#')]
    [TestCase('Arrays', 'var a = null; (function () { for (var i = 0; i < n; i++) { a = [a]; } })();', '#')]
    [TestCase('Map values', 'var a = null; (function () { for (var i = 0; i < n; i++) { var m = new Map; m.set(1, a); a = m; } })();', '#')]
    [TestCase('Map keys', 'var a = null; (function () { for (var i = 0; i < n; i++) { var m = new Map; m.set(a, 1); a = m; } })();', '#')]
    [TestCase('Sets', 'var a = null; (function () { for (var i = 0; i < n; i++) { var s = new Set; s.add(a); a = s; } })();', '#')]
    [TestCase('Weak maps', 'var a = {}; (function () { for (var i = 0; i < n; i++) { var w = new WeakMap; w.set(a, a); a = w; } })();', '#')]
    [TestCase('Weak sets', 'var a = {}; (function () { for (var i = 0; i < n; i++) { var w = new WeakSet; w.add(a); a = w; } })();', '#')]
    [TestCase('Map iterators', 'var a = new Map; (function () { for (var i = 0; i < n; i++) { a = new Map([[1, a]]).values(); } })();', '#')]
    [TestCase('Array iterators', 'var a = []; (function () { for (var i = 0; i < n; i++) { a = [a][Symbol.iterator](); } })();', '#')]
    [TestCase('Proxy handlers', 'var a = {}; (function () { for (var i = 0; i < n; i++) { a = new Proxy({}, a); } })();', '#')]
    [TestCase('Proxy targets and handlers', 'var a = {}; (function () { for (var i = 0; i < n; i++) { a = new Proxy(i % 2 ? a : {}, i % 2 ? {} : a); } })();', '#')]
    [TestCase('Prototypes', 'var a = {}; (function () { for (var i = 0; i < n; i++) { a = Object.create(a); } })();', '#')]
    [TestCase('Promise results', 'var a = null; (function () { for (var i = 0; i < n; i++) { a = Promise.resolve({ n: a }); } })();', '#')]
    [TestCase('Closures', 'var a = null; (function () { for (var i = 0; i < n; i++) { a = (function (p) { return function () { return p; }; })(a); } })();', '#')]
    [TestCase('Generators', 'var a = null; (function () { function* g(p) { yield p; } for (var i = 0; i < n; i++) { a = g(a); a.next(); } })();', '#')]
    [TestCase('Mixed containers', 'var a = null; (function () { for (var i = 0; i < n; i++) { var m = new Map; m.set(1, [{ n: new Set([a]) }]); a = m; } })();', '#')]
    procedure Engine_DeepChainOfObjects_IsReleasedWithoutStackOverflow(const Script: string);

    [Test]
    [TestCase('Built-in function', 'Math.max', '#')]
    [TestCase('Bound built-in function', 'Math.max.bind(null, 1)', '#')]
    [TestCase('Script function', '(function (x) { return x + 1; })', '#')]
    [TestCase('Bound script function', '(function (x) { return x + 1; }).bind(null)', '#')]
    [TestCase('Arrow function', '((x) => x + 1)', '#')]
    [TestCase('Generator function', '(function* () { yield 1; })', '#')]
    [TestCase('Method of a built-in', 'Array.prototype.map', '#')]
    [TestCase('Proxied function', 'new Proxy(function () { return 1; }, {})', '#')]
    procedure Engine_HostHeldFunction_RaisesErrorInsteadOfCrashingWhenCalledAfterDestruction(const Script: string);

    [Test]
    procedure Engine_HostHeldHostFunction_RaisesErrorInsteadOfCrashingWhenCalledAfterDestruction;

    [Test]
    [TestCase('Map', 'var m = new Map([[1, { a: 1 }]]); m', '#')]
    [TestCase('Set', 'new Set([1, { a: 1 }])', '#')]
    [TestCase('Weak map', 'var k = {}; var w = new WeakMap([[k, 1]]); w.k = k; w', '#')]
    [TestCase('Map iterator', 'new Map([[1, 2]]).entries()', '#')]
    [TestCase('Array iterator', '[1, { a: 1 }][Symbol.iterator]()', '#')]
    [TestCase('Promise', 'Promise.resolve({ a: 1 })', '#')]
    [TestCase('Pending promise', 'new Promise(function () {})', '#')]
    [TestCase('Generator object', 'var g = (function* () { yield { a: 1 }; })(); g.next(); g', '#')]
    [TestCase('Typed array', 'new Uint8Array([1, 2, 3])', '#')]
    [TestCase('Array buffer', 'new ArrayBuffer(8)', '#')]
    [TestCase('Data view', 'new DataView(new ArrayBuffer(8))', '#')]
    [TestCase('Regular expression', '/a(b)/g', '#')]
    [TestCase('Date', 'new Date(0)', '#')]
    [TestCase('Error', 'new RangeError("x")', '#')]
    [TestCase('Arguments', '(function () { return arguments; })(1, { a: 1 })', '#')]
    [TestCase('Proxy with traps', 'new Proxy({ a: 1 }, { get: function (t, k) { return t[k]; } })', '#')]
    [TestCase('Proxy without traps', 'new Proxy({ a: 1 }, {})', '#')]
    [TestCase('Function proxy', 'new Proxy(function () {}, {})', '#')]
    [TestCase('Class', 'class A { static s() { return 1; } }; A', '#')]
    [TestCase('Class instance', 'class A { get v() { return 1; } }; new A()', '#')]
    [TestCase('Object with accessors', '({ get a() { return 1; }, set a(v) {}, b: [1] })', '#')]
    [TestCase('Boxed symbol', 'Object(Symbol("s"))', '#')]
    procedure Engine_HostHeldObject_ReadingPropertiesAfterDestruction_DoesNotCrash(const Script: string);

    [Test]
    procedure Engine_HostHeldObject_KeepsItsContentsAfterDestruction;

    [Test]
    procedure Engine_HostHeldCycle_KeepsItsContentsAfterDestruction;

    [Test]
    procedure Engine_HostHeldSelfReference_KeepsItsContentsAfterDestruction;

    [Test]
    procedure Engine_HostHeldArrayAndProxy_KeepTheirContentsAfterDestruction;
  end;

implementation

const
  WARM_UP_RUNS = 2;
  MEASURED_RUNS = 5;
  DEEP_CHAIN_LENGTH = 200000;

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

  Assert.IsTrue(LeakedBytes = 0, Format('Leaked %d bytes', [LeakedBytes]));
end;

procedure TEngineLifetimeTests.Engine_AfterScriptError_ReleasesAllMemory(const Script: string);
begin
  const LeakedBytes = BytesLeakedByEngines(Script, True);

  Assert.IsTrue(LeakedBytes = 0, Format('Leaked %d bytes', [LeakedBytes]));
end;

procedure TEngineLifetimeTests.Engine_DeepChainOfObjects_IsReleasedWithoutStackOverflow(const Script: string);
begin
  const Head = Format('var n = %d; %s', [DEEP_CHAIN_LENGTH, Script]);

  for var Release in [False, True] do
  begin
    const Engine = TJSEngine.Create;
    try
      Engine.Execute(Head);

      if Release then
        Engine.Execute('a = null;');
    finally
      Engine.Free;
    end;
  end;

  Assert.Pass;
end;

procedure TEngineLifetimeTests.Engine_HostHeldFunction_RaisesErrorInsteadOfCrashingWhenCalledAfterDestruction(const Script: string);
begin
  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Held := Engine.Evaluate(Script);
  finally
    Engine.Free;
  end;

  const Subject = Held.ToObject as IJSFunction;

  try
    Subject.Call(nil, [TJSValue.CreateNumber(1)]);
  except
    on EJSTypeError do
    begin
    end;
  end;

  Assert.Pass;
end;

procedure TEngineLifetimeTests.Engine_HostHeldHostFunction_RaisesErrorInsteadOfCrashingWhenCalledAfterDestruction;
begin
  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Engine.RegisterFunction('hostFunction',
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        Result := TJSValue.CreateNumber(1);
      end);
    Held := Engine.Evaluate('hostFunction');
  finally
    Engine.Free;
  end;

  const Subject = Held.ToObject as IJSFunction;

  try
    Subject.Call(nil, []);
  except
    on EJSTypeError do
    begin
    end;
  end;

  Assert.Pass;
end;

procedure TEngineLifetimeTests.Engine_HostHeldObject_ReadingPropertiesAfterDestruction_DoesNotCrash(const Script: string);
begin
  const Names: TArray<string> = ['size', 'length', 'a', 'k', 'n', 'b', 'v', 'byteLength', 'byteOffset', 'buffer',
                                 'lastIndex', 'source', 'flags', 'global', 'message', 'name', 'stack',
                                 'constructor', 'prototype', 'next', 'then', 'toString', 'valueOf', '0', '1'];

  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Held := Engine.Evaluate(Script);
  finally
    Engine.Free;
  end;

  const Subject = Held.ToObject;
  for var Name in Names do
  begin
    try
      Subject.GetProperty(Name).ToString;
      Subject.HasProperty(Name);
    except
      on EJSException do
      begin
      end;
    end;
  end;

  Assert.Pass;
end;

procedure TEngineLifetimeTests.Engine_HostHeldObject_KeepsItsContentsAfterDestruction;
begin
  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Held := Engine.Evaluate('({ name: "held", list: [1, 2, { deep: true }], next: { n: 5 } })');
  finally
    Engine.Free;
  end;

  const Subject = Held.ToObject;
  const List = Subject.GetProperty('list').ToObject;
  const Deep = List.GetProperty('2').ToObject;
  const Next = Subject.GetProperty('next').ToObject;

  Assert.AreEqual('held', Subject.GetProperty('name').ToString);
  Assert.AreEqual('3', List.GetProperty('length').ToString);
  Assert.AreEqual('true', Deep.GetProperty('deep').ToString);
  Assert.AreEqual('5', Next.GetProperty('n').ToString);
end;

procedure TEngineLifetimeTests.Engine_HostHeldCycle_KeepsItsContentsAfterDestruction;
begin
  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Held := Engine.Evaluate('var a = { id: 1 }; var b = { id: 2, a: a }; a.b = b; a');
  finally
    Engine.Free;
  end;

  const First = Held.ToObject;
  const Second = First.GetProperty('b').ToObject;
  const Back = Second.GetProperty('a').ToObject;

  Assert.AreEqual('2', Second.GetProperty('id').ToString);
  Assert.AreEqual('1', Back.GetProperty('id').ToString);

  First.SetProperty('b', TJSValue.CreateUndefined);
end;

procedure TEngineLifetimeTests.Engine_HostHeldSelfReference_KeepsItsContentsAfterDestruction;
begin
  var Held: TJSValue;
  const Engine = TJSEngine.Create;
  try
    Held := Engine.Evaluate('var a = { n: 1 }; a.a = a; a');
  finally
    Engine.Free;
  end;

  const Subject = Held.ToObject;
  const Itself = Subject.GetProperty('a').ToObject;

  Assert.AreEqual('1', Itself.GetProperty('n').ToString);

  Subject.SetProperty('a', TJSValue.CreateUndefined);
end;

procedure TEngineLifetimeTests.Engine_HostHeldArrayAndProxy_KeepTheirContentsAfterDestruction;
begin
  var HeldArray: TJSValue;
  var HeldProxy: TJSValue;
  const Engine = TJSEngine.Create;
  try
    HeldArray := Engine.Evaluate('[1, [2, 3], { k: "v" }]');
    HeldProxy := Engine.Evaluate('new Proxy({ x: 7 }, {})');
  finally
    Engine.Free;
  end;

  const Items = HeldArray.ToObject;
  const Inner = Items.GetProperty('1').ToObject;
  const Record_ = Items.GetProperty('2').ToObject;
  const Proxied = HeldProxy.ToObject;

  Assert.AreEqual('3', Items.GetProperty('length').ToString);
  Assert.AreEqual('3', Inner.GetProperty('1').ToString);
  Assert.AreEqual('v', Record_.GetProperty('k').ToString);
  Assert.AreEqual('7', Proxied.GetProperty('x').ToString);
end;

end.
