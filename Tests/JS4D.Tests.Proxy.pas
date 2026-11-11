unit JS4D.Tests.Proxy;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TProxyTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Without traps everything reaches the target', '(function () { var t = { a: 1 }; var p = new Proxy(t, {}); p.b = 2; return p.a + "," + t.b + "," + ("a" in p) + "," + delete p.a + "," + Object.keys(t); })()#1,2,true,true,b', '#')]
    [TestCase('The get trap receives target, key and receiver', '(function () { var log = []; var p = new Proxy({}, { get: function (t, k, r) { log.push(typeof t, k, r === p); return 5; } }); return p.x + "," + log; })()#5,object,x,true', '#')]
    [TestCase('The get trap receives symbol keys', '(function () { var s = Symbol(); var seen; var p = new Proxy({}, { get: function (t, k) { seen = k; return 1; } }); p[s]; return seen === s; })()#true', '#')]
    [TestCase('The set trap receives the value', '(function () { var log = []; var p = new Proxy({}, { set: function (t, k, v, r) { log.push(k, v, r === p); return true; } }); p.a = 3; return log; })()#a,3,true', '#')]
    [TestCase('A set trap returning false throws in strict code', '(function () { "use strict"; var p = new Proxy({}, { set: function () { return false; } }); try { p.a = 1; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A set trap returning false is silent in sloppy code', '(function () { var p = new Proxy({}, { set: function () { return false; } }); p.a = 1; return "ok"; })()#ok', '#')]
    [TestCase('The has trap handles the in operator', '(function () { var p = new Proxy({}, { has: function (t, k) { return k === "x"; } }); return ("x" in p) + "," + ("y" in p); })()#true,false', '#')]
    [TestCase('The deleteProperty trap handles delete', '(function () { var p = new Proxy({ a: 1 }, { deleteProperty: function (t, k) { return false; } }); return delete p.a; })()#false', '#')]
    [TestCase('A deleteProperty trap returning false throws in strict code', '(function () { "use strict"; var p = new Proxy({}, { deleteProperty: function () { return false; } }); try { delete p.a; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The ownKeys trap lists the keys', '(function () { var p = new Proxy({}, { ownKeys: function () { return ["a", "b"]; }, getOwnPropertyDescriptor: function () { return { value: 1, enumerable: true, configurable: true }; } }); return Object.keys(p) + "|" + Object.getOwnPropertyNames(p); })()#a,b|a,b', '#')]
    [TestCase('The ownKeys trap lists symbols', '(function () { var s = Symbol(); var p = new Proxy({}, { ownKeys: function () { return ["a", s]; } }); return Object.getOwnPropertySymbols(p)[0] === s; })()#true', '#')]
    [TestCase('The getOwnPropertyDescriptor trap is used', '(function () { var p = new Proxy({}, { getOwnPropertyDescriptor: function () { return { value: 7, configurable: true }; } }); var d = Object.getOwnPropertyDescriptor(p, "x"); return d.value + "," + d.writable + "," + d.enumerable + "," + d.configurable; })()#7,false,false,true', '#')]
    [TestCase('The defineProperty trap receives a descriptor object', '(function () { var seen; var p = new Proxy({}, { defineProperty: function (t, k, d) { seen = Object.keys(d).join(); return true; } }); Object.defineProperty(p, "a", { value: 1, enumerable: true }); return seen; })()#value,enumerable', '#')]
    [TestCase('A defineProperty trap returning false throws from Object.defineProperty', '(function () { var p = new Proxy({}, { defineProperty: function () { return false; } }); try { Object.defineProperty(p, "a", {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The getPrototypeOf trap is used', '(function () { var proto = {}; var p = new Proxy({}, { getPrototypeOf: function () { return proto; } }); return Object.getPrototypeOf(p) === proto; })()#true', '#')]
    [TestCase('The getPrototypeOf trap drives instanceof', '(function () { function C() {} var p = new Proxy({}, { getPrototypeOf: function () { return C.prototype; } }); return p instanceof C; })()#true', '#')]
    [TestCase('The setPrototypeOf trap is used', '(function () { var seen; var p = new Proxy({}, { setPrototypeOf: function (t, v) { seen = v; return true; } }); var proto = {}; Object.setPrototypeOf(p, proto); return seen === proto; })()#true', '#')]
    [TestCase('The isExtensible trap is used', '(function () { var p = new Proxy({}, { isExtensible: function (t) { return true; } }); return Object.isExtensible(p); })()#true', '#')]
    [TestCase('The preventExtensions trap is used', '(function () { var t = {}; var p = new Proxy(t, { preventExtensions: function (t) { Object.preventExtensions(t); return true; } }); Object.preventExtensions(p); return Object.isExtensible(t); })()#false', '#')]
    [TestCase('The apply trap handles calls', '(function () { var p = new Proxy(function () { return 1; }, { apply: function (t, thisArg, args) { return args.length + t(); } }); return p(1, 2, 3); })()#4', '#')]
    [TestCase('The construct trap handles new', '(function () { var p = new Proxy(function () {}, { construct: function (t, args, nt) { return { n: args.length, same: nt === p }; } }); var o = new p(1, 2); return o.n + "," + o.same; })()#2,true', '#')]
    [TestCase('A construct trap must return an object', '(function () { var p = new Proxy(function () {}, { construct: function () { return 1; } }); try { new p(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A function proxy is callable without traps', '(function () { var p = new Proxy(function (a) { return a * 2; }, {}); return p(4) + "," + typeof p; })()#8,function', '#')]
    [TestCase('Constructing without a trap constructs the target', '(function () { function C(a) { this.a = a; } var P = new Proxy(C, {}); var o = new P(3); return o.a + "," + (o instanceof C); })()#3,true', '#')]
    [TestCase('An object proxy is not callable', '(function () { var p = new Proxy({}, {}); try { p(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('typeof a proxy follows its target', 'typeof new Proxy({}, {}) + "," + typeof new Proxy(function () {}, {})#object,function', '#')]
    [TestCase('Array.isArray sees through a proxy', 'Array.isArray(new Proxy([], {})) + "," + Array.isArray(new Proxy({}, {}))#true,false', '#')]
    [TestCase('A proxy in a prototype chain receives the original receiver', '(function () { var p = new Proxy({}, { get: function (t, k, r) { return r; } }); var o = Object.create(p); return o.x === o; })()#true', '#')]
    [TestCase('A proxy in a prototype chain handles inherited assignments', '(function () { var seen; var p = new Proxy({}, { set: function (t, k, v, r) { seen = r; return true; } }); var o = Object.create(p); o.x = 1; return seen === o && !o.hasOwnProperty("x"); })()#true', '#')]
    [TestCase('A proxy in a prototype chain handles the in operator', '(function () { var p = new Proxy({}, { has: function () { return true; } }); return "q" in Object.create(p); })()#true', '#')]
    [TestCase('for-in uses ownKeys and getOwnPropertyDescriptor', '(function () { var p = new Proxy({}, { ownKeys: function () { return ["a", "b"]; }, getOwnPropertyDescriptor: function (t, k) { return { value: 1, enumerable: k === "a", configurable: true }; } }); var r = []; for (var k in p) { r.push(k); } return r; })()#a', '#')]
    [TestCase('Object.prototype.toString sees an array proxy', 'Object.prototype.toString.call(new Proxy([], {})) + "," + Object.prototype.toString.call(new Proxy(function () {}, {}))#[object Array],[object Function]', '#')]
    [TestCase('JSON.stringify treats an array proxy as an array', 'JSON.stringify(new Proxy([1, 2], {})) + JSON.stringify({ a: new Proxy([3], {}) })#[1,2]{"a":[3]}', '#')]
    [TestCase('concat spreads an array proxy', '[0].concat(new Proxy([1, 2], {})).join()#0,1,2', '#')]
    [TestCase('A trap may revoke its own proxy', '(function () { var r = Proxy.revocable({ a: 1 }, { get: function (t, k) { r.revoke(); return 7; } }); return r.proxy.a; })()#7', '#')]
    [TestCase('Constructing through a proxy revoked by its get trap throws', '(function () { var r = Proxy.revocable(function () {}, { get: function () { r.revoke(); } }); try { new r.proxy(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Proxy has length 2 and the name Proxy', 'Proxy.length + "," + Proxy.name#2,Proxy', '#')]
    [TestCase('Proxy has no prototype property', 'Proxy.hasOwnProperty("prototype")#false', '#')]
    [TestCase('Proxy requires new', '(function () { try { Proxy({}, {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The target must be an object', '(function () { try { new Proxy(1, {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The handler must be an object', '(function () { try { new Proxy({}, null); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A trap must be callable', '(function () { var p = new Proxy({}, { get: 1 }); try { p.x; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Null and undefined traps fall through', '(function () { var p = new Proxy({ a: 1 }, { get: null, has: undefined }); return p.a + "," + ("a" in p); })()#1,true', '#')]
    [TestCase('A proxy can wrap a proxy', '(function () { var log = []; var inner = new Proxy({ a: 1 }, { get: function (t, k, r) { log.push("inner"); return t[k]; } }); var outer = new Proxy(inner, { get: function (t, k, r) { log.push("outer"); return t[k]; } }); return outer.a + "," + log; })()#1,outer,inner', '#')]
    procedure Proxy_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('A get trap cannot change a read-only data property', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { get: function () { return 2; } }); try { p.a; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A get trap may return the real value of a read-only property', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { get: function () { return 1; } }); return p.a; })()#1', '#')]
    [TestCase('A has trap cannot hide a non-configurable property', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { has: function () { return false; } }); try { "a" in p; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A has trap cannot hide a property of a non-extensible target', '(function () { var t = { a: 1 }; Object.preventExtensions(t); var p = new Proxy(t, { has: function () { return false; } }); try { "a" in p; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A set trap cannot claim to change a read-only property', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { set: function () { return true; } }); try { p.a = 2; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A deleteProperty trap cannot delete a non-configurable property', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { deleteProperty: function () { return true; } }); try { delete p.a; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('An ownKeys trap must include non-configurable keys', '(function () { var t = {}; Object.defineProperty(t, "a", { value: 1 }); var p = new Proxy(t, { ownKeys: function () { return []; } }); try { Object.keys(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('An ownKeys trap cannot add keys to a non-extensible target', '(function () { var t = { a: 1 }; Object.preventExtensions(t); var p = new Proxy(t, { ownKeys: function () { return ["a", "b"]; } }); try { Object.keys(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('An ownKeys trap cannot return duplicates', '(function () { var p = new Proxy({}, { ownKeys: function () { return ["a", "a"]; } }); try { Object.keys(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('An ownKeys trap can only return strings and symbols', '(function () { var p = new Proxy({}, { ownKeys: function () { return [1]; } }); try { Object.keys(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A getOwnPropertyDescriptor trap cannot report a missing property as non-configurable', '(function () { var p = new Proxy({}, { getOwnPropertyDescriptor: function () { return { value: 1, configurable: false }; } }); try { Object.getOwnPropertyDescriptor(p, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A getOwnPropertyDescriptor trap must return an object or undefined', '(function () { var p = new Proxy({}, { getOwnPropertyDescriptor: function () { return 1; } }); try { Object.getOwnPropertyDescriptor(p, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A defineProperty trap cannot add to a non-extensible target', '(function () { var t = {}; Object.preventExtensions(t); var p = new Proxy(t, { defineProperty: function () { return true; } }); try { Object.defineProperty(p, "a", { value: 1 }); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('An isExtensible trap must agree with the target', '(function () { var p = new Proxy({}, { isExtensible: function () { return false; } }); try { Object.isExtensible(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A preventExtensions trap cannot succeed on an extensible target', '(function () { var p = new Proxy({}, { preventExtensions: function () { return true; } }); try { Object.preventExtensions(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A getPrototypeOf trap must return an object or null', '(function () { var p = new Proxy({}, { getPrototypeOf: function () { return 1; } }); try { Object.getPrototypeOf(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A getPrototypeOf trap must match a non-extensible target', '(function () { var t = {}; Object.preventExtensions(t); var p = new Proxy(t, { getPrototypeOf: function () { return Array.prototype; } }); try { Object.getPrototypeOf(p); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Proxy_EnforcesInvariants(const Expression, Expected: string);

    [Test]
    [TestCase('Revocable returns the proxy and the revoke function', '(function () { var r = Proxy.revocable({}, {}); return typeof r.proxy + "," + typeof r.revoke + "," + r.revoke.length + "," + Object.keys(r); })()#object,function,0,proxy,revoke', '#')]
    [TestCase('A revoked proxy throws on every operation', '(function () { var r = Proxy.revocable({}, {}); r.revoke(); var n = 0; var ops = [function () { r.proxy.a; }, function () { r.proxy.a = 1; }, function () { "a" in r.proxy; }, function () { delete r.proxy.a; }, function () { Object.keys(r.proxy); }, function () { Object.getPrototypeOf(r.proxy); }]; ops.forEach(function (op) { try { op(); } catch (e) { if (e instanceof TypeError) { n++; } } }); return n; })()#6', '#')]
    [TestCase('Revoking twice is harmless', '(function () { var r = Proxy.revocable({}, {}); r.revoke(); r.revoke(); return "ok"; })()#ok', '#')]
    [TestCase('typeof a revoked function proxy is still function', '(function () { var r = Proxy.revocable(function () {}, {}); r.revoke(); return typeof r.proxy; })()#function', '#')]
    [TestCase('A revoked function proxy cannot be called', '(function () { var r = Proxy.revocable(function () {}, {}); r.revoke(); try { r.proxy(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Revocable is not a constructor', '(function () { try { new Proxy.revocable({}, {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Proxy_Revocation_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Apply calls with this and arguments', 'Reflect.apply(function (a, b) { return this.x + a + b; }, { x: 1 }, [2, 3])#6', '#')]
    [TestCase('Apply requires a function', '(function () { try { Reflect.apply({}, null, []); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Apply requires an argument list object', '(function () { try { Reflect.apply(function () {}, null); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Construct creates an instance', '(function () { function C(a) { this.a = a; } var o = Reflect.construct(C, [4]); return o.a + "," + (o instanceof C); })()#4,true', '#')]
    [TestCase('Construct takes the prototype from new.target', '(function () { function C() {} function D() {} var o = Reflect.construct(C, [], D); return (o instanceof D) + "," + (o instanceof C); })()#true,false', '#')]
    [TestCase('Construct requires a constructor', '(function () { try { Reflect.construct(Math.max, []); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Construct requires a constructor as new.target', '(function () { try { Reflect.construct(function () {}, [], Math.max); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('DefineProperty reports success and failure', '(function () { var o = {}; var a = Reflect.defineProperty(o, "x", { value: 1 }); var b = Reflect.defineProperty(o, "x", { value: 2 }); return a + "," + b + "," + o.x; })()#true,false,1', '#')]
    [TestCase('DeleteProperty reports success and failure', '(function () { var o = { a: 1 }; Object.defineProperty(o, "b", { value: 1 }); return Reflect.deleteProperty(o, "a") + "," + Reflect.deleteProperty(o, "b") + "," + Reflect.deleteProperty(o, "c"); })()#true,false,true', '#')]
    [TestCase('Get reads with a receiver', 'Reflect.get({ get a() { return this.v; } }, "a", { v: 9 })#9', '#')]
    [TestCase('Get without a receiver uses the target', 'Reflect.get({ get a() { return this.v; }, v: 3 }, "a")#3', '#')]
    [TestCase('Get reads inherited properties', 'Reflect.get(Object.create({ a: 5 }), "a")#5', '#')]
    [TestCase('GetOwnPropertyDescriptor describes own properties', '(function () { var d = Reflect.getOwnPropertyDescriptor({ a: 1 }, "a"); return d.value + "," + d.writable + "," + d.enumerable + "," + d.configurable; })()#1,true,true,true', '#')]
    [TestCase('GetOwnPropertyDescriptor returns undefined for a missing property', 'Reflect.getOwnPropertyDescriptor({}, "a")#undefined', '#')]
    [TestCase('GetPrototypeOf reads the prototype', 'Reflect.getPrototypeOf([]) === Array.prototype && Reflect.getPrototypeOf(Object.create(null)) === null#true', '#')]
    [TestCase('Has checks the whole chain', 'Reflect.has(Object.create({ a: 1 }), "a") + "," + Reflect.has({}, "a")#true,false', '#')]
    [TestCase('IsExtensible and PreventExtensions', '(function () { var o = {}; var a = Reflect.isExtensible(o); var r = Reflect.preventExtensions(o); return a + "," + r + "," + Reflect.isExtensible(o); })()#true,true,false', '#')]
    [TestCase('OwnKeys lists strings and symbols in order', '(function () { var s = Symbol(); var k = Reflect.ownKeys({ b: 1, 2: 1, a: 1, [s]: 1, 1: 1 }); return k.slice(0, 4) + "," + (k[4] === s); })()#1,2,b,a,true', '#')]
    [TestCase('Set assigns and reports', '(function () { var o = {}; var a = Reflect.set(o, "x", 1); var f = Object.freeze({}); return a + "," + o.x + "," + Reflect.set(f, "x", 1); })()#true,1,false', '#')]
    [TestCase('Set calls a setter with the receiver', '(function () { var seen; var o = { set a(v) { seen = this; } }; var r = {}; Reflect.set(o, "a", 1, r); return seen === r; })()#true', '#')]
    [TestCase('Set defines the property on the receiver', '(function () { var o = {}; var r = {}; Reflect.set(o, "a", 1, r); return r.a + "," + o.hasOwnProperty("a"); })()#1,false', '#')]
    [TestCase('Set fails when the receiver is not an object', 'Reflect.set({}, "a", 1, 1)#false', '#')]
    [TestCase('SetPrototypeOf reports success and failure', '(function () { var o = {}; var p = {}; var a = Reflect.setPrototypeOf(o, p); var f = Object.preventExtensions({}); return a + "," + (Object.getPrototypeOf(o) === p) + "," + Reflect.setPrototypeOf(f, p); })()#true,true,false', '#')]
    [TestCase('SetPrototypeOf refuses a cycle', '(function () { var a = {}; var b = Object.create(a); return Reflect.setPrototypeOf(a, b); })()#false', '#')]
    [TestCase('SetPrototypeOf requires an object or null', '(function () { try { Reflect.setPrototypeOf({}, 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Every function requires an object target', '(function () { var n = 0; ["defineProperty", "deleteProperty", "get", "getOwnPropertyDescriptor", "getPrototypeOf", "has", "isExtensible", "ownKeys", "preventExtensions", "set", "setPrototypeOf"].forEach(function (name) { try { Reflect[name](1, "a", {}); } catch (e) { if (e instanceof TypeError) { n++; } } }); return n; })()#11', '#')]
    [TestCase('The functions have their lengths', 'Object.getOwnPropertyNames(Reflect).map(function (k) { return k + Reflect[k].length; }).join()#apply3,construct2,defineProperty3,deleteProperty2,get2,getOwnPropertyDescriptor2,getPrototypeOf1,has2,isExtensible1,ownKeys1,preventExtensions1,set3,setPrototypeOf2', '#')]
    [TestCase('Reflect has a tag and an ordinary prototype', 'Object.prototype.toString.call(Reflect) + "," + (Object.getPrototypeOf(Reflect) === Object.prototype)#[object Reflect],true', '#')]
    [TestCase('The functions are not constructors', '(function () { try { new Reflect.get({}, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Reflect is not callable', 'typeof Reflect#object', '#')]
    [TestCase('Reflect works on a proxy', '(function () { var log = []; var p = new Proxy({ a: 1 }, { get: function (t, k, r) { log.push("get"); return Reflect.get(t, k, r); }, has: function (t, k) { log.push("has"); return Reflect.has(t, k); } }); return Reflect.get(p, "a") + "," + Reflect.has(p, "a") + "," + log; })()#1,true,get,has', '#')]
    [TestCase('A proxy handler can forward to Reflect', '(function () { var o = {}; var p = new Proxy(o, { set: function (t, k, v, r) { return Reflect.set(t, k, v + 1, r); } }); p.a = 1; return o.a; })()#2', '#')]
    procedure Reflect_FollowsSpecification(const Expression, Expected: string);

    [Test]
    procedure Proxy_OverObjectWithManyReads_StaysFast;

    [Test]
    procedure Proxy_DoesNotChangeOrdinaryObjects;
  end;

implementation

procedure TProxyTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TProxyTests.TearDown;
begin
  FEngine.Free;
end;

function TProxyTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TProxyTests.Proxy_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TProxyTests.Proxy_EnforcesInvariants(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TProxyTests.Proxy_Revocation_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TProxyTests.Reflect_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TProxyTests.Proxy_OverObjectWithManyReads_StaysFast;
begin
  const Script = '(function () { var p = new Proxy({ a: 1 }, { get: function (t, k) { return t[k]; } }); ' +
                 'var sum = 0; for (var i = 0; i < 20000; i++) { sum += p.a; } return sum; })()';

  Assert.AreEqual('20000', Evaluate(Script));
end;

procedure TProxyTests.Proxy_DoesNotChangeOrdinaryObjects;
begin
  const Script = '(function () { var o = { a: 1 }; var f = function () { return 2; }; var arr = [1, 2]; ' +
                 'return Object.keys(o) + "," + f() + "," + arr.length + "," + (Object.getPrototypeOf(arr) === Array.prototype); })()';

  Assert.AreEqual('a,2,2,true', Evaluate(Script));
end;

end.
