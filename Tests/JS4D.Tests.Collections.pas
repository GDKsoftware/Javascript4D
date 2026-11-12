unit JS4D.Tests.Collections;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TCollectionTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Get returns the stored value', '(function () { var m = new Map(); m.set("a", 1); return m.get("a"); })()#1', '#')]
    [TestCase('Get of a missing key is undefined', 'new Map().get("a")#undefined', '#')]
    [TestCase('Set returns the map', '(function () { var m = new Map(); return m.set(1, 2) === m; })()#true', '#')]
    [TestCase('Size counts the entries', '(function () { var m = new Map([[1, 1], [2, 2], [1, 3]]); return m.size; })()#2', '#')]
    [TestCase('Setting an existing key keeps its position', '(function () { var m = new Map([[1, "a"], [2, "b"]]); m.set(1, "c"); return [...m.keys()].join() + m.get(1); })()#1,2c', '#')]
    [TestCase('NaN is the same key as NaN', '(function () { var m = new Map(); m.set(NaN, 1); return m.get(NaN) + "," + m.has(0/0); })()#1,true', '#')]
    [TestCase('Positive and negative zero are the same key', '(function () { var m = new Map(); m.set(-0, "z"); return m.get(0) + "," + (1 / [...m.keys()][0]); })()#z,Infinity', '#')]
    [TestCase('Strings and numbers are different keys', '(function () { var m = new Map([["1", "s"], [1, "n"]]); return m.size + m.get("1") + m.get(1); })()#2sn', '#')]
    [TestCase('Objects are keys by identity', '(function () { var a = {}, b = {}; var m = new Map([[a, 1]]); return m.has(a) + "," + m.has(b) + "," + m.has({}); })()#true,false,false', '#')]
    [TestCase('Symbols are keys by identity', '(function () { var s = Symbol(); var m = new Map([[s, 1]]); return m.get(s) + "," + m.has(Symbol()); })()#1,false', '#')]
    [TestCase('Undefined and null are keys', '(function () { var m = new Map([[undefined, 1], [null, 2]]); return m.get(undefined) + "," + m.get(null); })()#1,2', '#')]
    [TestCase('Booleans are keys', '(function () { var m = new Map([[true, 1], [false, 2]]); return m.get(true) + "," + m.get(false) + "," + m.has(1); })()#1,2,false', '#')]
    [TestCase('Delete reports whether the key existed', '(function () { var m = new Map([[1, 1]]); return m.delete(1) + "," + m.delete(1) + "," + m.size; })()#true,false,0', '#')]
    [TestCase('Clear empties the map', '(function () { var m = new Map([[1, 1], [2, 2]]); var r = m.clear(); return r + "," + m.size + "," + m.has(1); })()#undefined,0,false', '#')]
    [TestCase('The constructor accepts a generator-free iterable', '(function () { var it = { [Symbol.iterator]() { var i = 0; return { next() { return { done: i > 1, value: [i, i++ * 10] }; } }; } }; return [...new Map(it)].join("|"); })()#0,0|1,10', '#')]
    [TestCase('The constructor reads entries with indexes', '(function () { var m = new Map([{ 0: "k", 1: "v" }]); return m.get("k"); })()#v', '#')]
    [TestCase('The constructor calls a replaced set', '(function () { var n = 0; var set = Map.prototype.set; Map.prototype.set = function (k, v) { n++; return set.call(this, k, v); }; var m = new Map([[1, 1], [2, 2]]); Map.prototype.set = set; return n + "," + m.size; })()#2,2', '#')]
    [TestCase('Map has length 0 and a name', 'Map.length + Map.name#0Map', '#')]
    [TestCase('Methods have their lengths', '[Map.prototype.get, Map.prototype.set, Map.prototype.has, Map.prototype.delete, Map.prototype.clear, Map.prototype.forEach, Map.prototype.keys].map(function (f) { return f.length; }).join("")#1211010', '#')]
    [TestCase('The size accessor is a getter', '(function () { var d = Object.getOwnPropertyDescriptor(Map.prototype, "size"); return typeof d.get + "," + d.set + "," + d.enumerable + "," + d.configurable + "," + d.get.name; })()#function,undefined,false,true,get size', '#')]
    [TestCase('Methods are not enumerable', 'Object.keys(Map.prototype).length#0', '#')]
    [TestCase('The tag is Map', 'Object.prototype.toString.call(new Map())#[object Map]', '#')]
    [TestCase('Symbol.iterator is entries', 'Map.prototype[Symbol.iterator] === Map.prototype.entries#true', '#')]
    [TestCase('Species is the constructor', 'Map[Symbol.species] === Map#true', '#')]
    [TestCase('The species getter is named', 'Object.getOwnPropertyDescriptor(Map, Symbol.species).get.name#get [Symbol.species]', '#')]
    [TestCase('The prototype is not writable', '(function () { "use strict"; try { Map.prototype = {}; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The constructor property is the constructor', 'Map.prototype.constructor === Map#true', '#')]
    [TestCase('Instances inherit from the prototype', 'Object.getPrototypeOf(new Map()) === Map.prototype#true', '#')]
    [TestCase('The global is not enumerable', 'Object.getOwnPropertyDescriptor(this, "Map").enumerable#false', '#')]
    procedure Map_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Add returns the set', '(function () { var s = new Set(); return s.add(1) === s; })()#true', '#')]
    [TestCase('Duplicates are ignored', 'new Set([1, 2, 1, 2, 3]).size#3', '#')]
    [TestCase('The constructor accepts a string', '[...new Set("abca")].join("")#abc', '#')]
    [TestCase('NaN is the same value as NaN', 'new Set([NaN, NaN]).size#1', '#')]
    [TestCase('Zero is stored as positive zero', '(function () { var s = new Set([-0]); return 1 / [...s][0]; })()#Infinity', '#')]
    [TestCase('Entries pairs a value with itself', '[...new Set([1, 2]).entries()].join("|")#1,1|2,2', '#')]
    [TestCase('Keys is values', 'Set.prototype.keys === Set.prototype.values#true', '#')]
    [TestCase('Symbol.iterator is values', 'Set.prototype[Symbol.iterator] === Set.prototype.values#true', '#')]
    [TestCase('Has and delete work by value', '(function () { var s = new Set([1]); return s.has(1) + "," + s.delete(1) + "," + s.has(1) + "," + s.delete(1); })()#true,true,false,false', '#')]
    [TestCase('Clear empties the set', '(function () { var s = new Set([1, 2]); s.clear(); return s.size; })()#0', '#')]
    [TestCase('The constructor calls a replaced add', '(function () { var n = 0; var add = Set.prototype.add; Set.prototype.add = function (v) { n++; return add.call(this, v); }; new Set([1, 2, 3]); Set.prototype.add = add; return n; })()#3', '#')]
    [TestCase('The tag is Set', 'Object.prototype.toString.call(new Set())#[object Set]', '#')]
    [TestCase('Set has length 0', 'Set.length#0', '#')]
    [TestCase('Add has length 1', 'Set.prototype.add.length#1', '#')]
    [TestCase('Species is the constructor', 'Set[Symbol.species] === Set#true', '#')]
    [TestCase('Set methods reject a map receiver', '(function () { try { Set.prototype.add.call(new Map(), 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Map methods reject a set receiver', '(function () { try { Map.prototype.get.call(new Set(), 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('The prototype object is not a set', '(function () { try { Set.prototype.size; } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Set_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('A weak map stores objects', '(function () { var k = {}; var m = new WeakMap([[k, 1]]); return m.get(k) + "," + m.has(k) + "," + m.has({}); })()#1,true,false', '#')]
    [TestCase('A weak map deletes', '(function () { var k = {}; var m = new WeakMap(); m.set(k, 1); return m.delete(k) + "," + m.has(k) + "," + m.delete(k); })()#true,false,false', '#')]
    [TestCase('A weak map rejects primitive keys', '(function () { try { new WeakMap().set(1, 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A weak map rejects symbol keys', '(function () { try { new WeakMap().set(Symbol(), 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A weak map ignores primitive lookups', '(function () { var m = new WeakMap(); return m.get(1) + "," + m.has("a") + "," + m.delete(null); })()#undefined,false,false', '#')]
    [TestCase('A weak map accepts functions and arrays', '(function () { var f = function () {}, a = []; var m = new WeakMap([[f, 1], [a, 2]]); return m.get(f) + m.get(a); })()#3', '#')]
    [TestCase('A weak set stores objects', '(function () { var k = {}; var s = new WeakSet([k]); return s.has(k) + "," + s.has({}) + "," + s.delete(k) + "," + s.has(k); })()#true,false,true,false', '#')]
    [TestCase('A weak set rejects primitive values', '(function () { try { new WeakSet().add("a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A weak set constructor rejects primitive values', '(function () { try { new WeakSet([1]); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Weak collections are not iterable', 'typeof WeakMap.prototype.forEach + typeof WeakSet.prototype.clear + typeof WeakMap.prototype.size#undefinedundefinedundefined', '#')]
    [TestCase('Weak collections have no species', 'WeakMap[Symbol.species] + "," + WeakSet[Symbol.species]#undefined,undefined', '#')]
    [TestCase('Weak tags', 'Object.prototype.toString.call(new WeakMap()) + Object.prototype.toString.call(new WeakSet())#[object WeakMap][object WeakSet]', '#')]
    [TestCase('Weak method lengths', '[WeakMap.prototype.get, WeakMap.prototype.set, WeakSet.prototype.add].map(function (f) { return f.length; }).join("")#121', '#')]
    [TestCase('Weak receivers are checked', '(function () { try { WeakMap.prototype.get.call(new Map(), {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Weak_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('ForEach visits in insertion order', '(function () { var out = []; new Map([[1, "a"], [2, "b"]]).forEach(function (v, k, m) { out.push(k + v + (m instanceof Map)); }); return out.join(); })()#1atrue,2btrue', '#')]
    [TestCase('ForEach passes the this argument', '(function () { var t = {}; var r; new Set([1]).forEach(function () { r = this === t; }, t); return r; })()#true', '#')]
    [TestCase('Set forEach passes the value twice', '(function () { var out = []; new Set(["x"]).forEach(function (v, k) { out.push(v + k); }); return out.join(); })()#xx', '#')]
    [TestCase('ForEach rejects a non-callable callback', '(function () { try { new Map().forEach({}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('ForEach sees additions', '(function () { var m = new Map([[1, 1]]); var out = []; m.forEach(function (v, k) { out.push(k); if (k < 4) { m.set(k + 1, 1); } }); return out.join(); })()#1,2,3,4', '#')]
    [TestCase('ForEach skips deleted entries', '(function () { var s = new Set([1, 2, 3]); var out = []; s.forEach(function (v) { out.push(v); if (v === 1) { s.delete(2); } }); return out.join(); })()#1,3', '#')]
    [TestCase('ForEach visits a deleted and re-added entry again', '(function () { var s = new Set([1, 2]); var out = []; s.forEach(function (v) { out.push(v); if (out.length === 1) { s.delete(1); s.add(1); } }); return out.join(); })()#1,2,1', '#')]
    [TestCase('ForEach after clear sees new entries', '(function () { var s = new Set([1, 2]); var out = []; s.forEach(function (v) { out.push(v); if (v === 1) { s.clear(); s.add(9); } }); return out.join(); })()#1,9', '#')]
    [TestCase('An iterator sees additions made before it ends', '(function () { var m = new Map([[1, 1]]); var it = m.keys(); it.next(); m.set(2, 2); return JSON.stringify(it.next()); })()#{"value":2,"done":false}', '#')]
    [TestCase('An iterator skips deleted entries', '(function () { var s = new Set([1, 2, 3]); var it = s.values(); it.next(); s.delete(2); return it.next().value; })()#3', '#')]
    [TestCase('An exhausted iterator stays exhausted', '(function () { var s = new Set([1]); var it = s.values(); it.next(); it.next(); s.add(2); return JSON.stringify(it.next()); })()#{"done":true}', '#')]
    [TestCase('An iterator survives compaction', '(function () { var m = new Map(); for (var i = 0; i < 100; i++) { m.set(i, i); } var it = m.keys(); for (var j = 0; j < 10; j++) { it.next(); } for (var k = 0; k < 90; k++) { m.delete(k); } return it.next().value + "," + it.next().value; })()#90,91', '#')]
    [TestCase('An iterator at a deleted position continues after compaction', '(function () { var m = new Map(); for (var i = 0; i < 100; i++) { m.set(i, i); } var it = m.keys(); for (var j = 0; j < 50; j++) { it.next(); } for (var k = 0; k < 60; k++) { m.delete(k); } m.set("new", 1); return [...it].join(); })()#60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,new', '#')]
    [TestCase('Map entries are arrays', '(function () { var e = new Map([[1, 2]]).entries().next().value; return Array.isArray(e) + "," + e.join(); })()#true,1,2', '#')]
    [TestCase('Map values and keys', '(function () { var m = new Map([[1, "a"], [2, "b"]]); return [...m.keys()].join("") + [...m.values()].join(""); })()#12ab', '#')]
    [TestCase('A map is spread as entries', '[...new Map([[1, "a"]])].join()#1,a', '#')]
    [TestCase('For-of over a map destructures entries', '(function () { var out = []; for (var [k, v] of new Map([[1, "a"], [2, "b"]])) { out.push(k + v); } return out.join(); })()#1a,2b', '#')]
    [TestCase('Array.from accepts a set', 'Array.from(new Set([3, 4])).join()#3,4', '#')]
    [TestCase('Iterator results are plain objects', '(function () { var r = new Set([1]).values().next(); return Object.keys(r).join(); })()#value,done', '#')]
    [TestCase('The map iterator tag', 'Object.prototype.toString.call(new Map().entries())#[object Map Iterator]', '#')]
    [TestCase('The set iterator tag', 'Object.prototype.toString.call(new Set().values())#[object Set Iterator]', '#')]
    [TestCase('The iterator prototype chain', '(function () { var p = Object.getPrototypeOf(new Map().keys()); var i = Object.getPrototypeOf(p); return (i === Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]()))) + "," + (p !== Object.getPrototypeOf(new Set().keys())); })()#true,true', '#')]
    [TestCase('The iterator is iterable', '(function () { var it = new Set([1]).values(); return it[Symbol.iterator]() === it; })()#true', '#')]
    [TestCase('Next has length 0 and a name', '(function () { var n = Object.getPrototypeOf(new Map().keys()).next; return n.length + n.name; })()#0next', '#')]
    [TestCase('A map iterator rejects a set iterator receiver', '(function () { try { Object.getPrototypeOf(new Map().keys()).next.call(new Set().values()); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Next on the prototype throws', '(function () { try { Object.getPrototypeOf(new Set().values()).next(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Iteration_IsLive(const Expression, Expected: string);

    [Test]
    [TestCase('Calling Map without new throws', '(function () { try { Map(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Calling Set without new throws', '(function () { try { Set(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Calling WeakMap without new throws', '(function () { try { WeakMap(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A non-iterable argument throws', '(function () { try { new Map(1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Null and undefined arguments make an empty collection', 'new Map(null).size + new Set(undefined).size#0', '#')]
    [TestCase('A non-object entry throws', '(function () { try { new Map([1]); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('A non-callable adder throws', '(function () { var set = Map.prototype.set; Map.prototype.set = 1; try { new Map([]); } catch (e) { return e instanceof TypeError; } finally { Map.prototype.set = set; } return false; })()#true', '#')]
    [TestCase('An empty argument does not read the adder', '(function () { var set = Map.prototype.set; Map.prototype.set = 1; try { return new Map().size; } finally { Map.prototype.set = set; } })()#0', '#')]
    [TestCase('A failing adder closes the iterator', '(function () { var closed = false; var it = { [Symbol.iterator]() { return { next() { return { done: false, value: 1 }; }, return() { closed = true; return {}; } }; } }; try { new Map(it); } catch (e) {} return closed; })()#true', '#')]
    [TestCase('An exception from the adder propagates', '(function () { var set = Set.prototype.add; Set.prototype.add = function () { throw new RangeError("x"); }; try { new Set([1]); } catch (e) { return e instanceof RangeError; } finally { Set.prototype.add = set; } })()#true', '#')]
    procedure Constructors_ValidateArguments(const Expression, Expected: string);

    [Test]
    procedure Map_WithManyEntries_StaysFast;

    [Test]
    procedure Map_ReusesDeletedCapacity;
  end;

implementation

procedure TCollectionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TCollectionTests.TearDown;
begin
  FEngine.Free;
end;

function TCollectionTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TCollectionTests.Map_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TCollectionTests.Set_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TCollectionTests.Weak_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TCollectionTests.Iteration_IsLive(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TCollectionTests.Constructors_ValidateArguments(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TCollectionTests.Map_WithManyEntries_StaysFast;
begin
  const Script = '(function () { var m = new Map(); for (var i = 0; i < 100000; i++) { m.set("k" + i, i); } ' +
                 'var sum = 0; for (var j = 0; j < 100000; j++) { sum += m.get("k" + j); } return sum + "," + m.size; })()';

  Assert.AreEqual('4999950000,100000', Evaluate(Script));
end;

procedure TCollectionTests.Map_ReusesDeletedCapacity;
begin
  const Script = '(function () { var m = new Map(); for (var i = 0; i < 50000; i++) { m.set(i, i); m.delete(i - 5); } ' +
                 'return m.size + "," + [...m.keys()].join(); })()';

  Assert.AreEqual('5,49995,49996,49997,49998,49999', Evaluate(Script));
end;

end.
