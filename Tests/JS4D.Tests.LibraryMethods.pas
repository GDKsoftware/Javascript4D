unit JS4D.Tests.LibraryMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TLibraryMethodsTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('HasOwn own property', 'Object.hasOwn({ a: 1 }, "a")#true', '#')]
    [TestCase('HasOwn inherited property', 'Object.hasOwn({}, "toString")#false', '#')]
    [TestCase('HasOwn string index', 'Object.hasOwn("ab", 1)#true', '#')]
    [TestCase('HasOwn array length', 'Object.hasOwn([1], "length")#true', '#')]
    [TestCase('HasOwn symbol key', '(function () { var s = Symbol(); var o = {}; o[s] = 1; return Object.hasOwn(o, s); })()#true', '#')]
    [TestCase('HasOwn null throws', '(function () { try { Object.hasOwn(null, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('HasOwn has length 2', 'Object.hasOwn.length#2', '#')]
    [TestCase('HasOwn is not enumerable', 'Object.keys(Object).indexOf("hasOwn")#-1', '#')]
    [TestCase('SetPrototypeOf links the prototype', '(function () { var o = Object.setPrototypeOf({}, { x: 1 }); return o.x; })()#1', '#')]
    [TestCase('SetPrototypeOf returns the object', '(function () { var o = {}; return Object.setPrototypeOf(o, null) === o; })()#true', '#')]
    [TestCase('SetPrototypeOf null prototype', 'Object.getPrototypeOf(Object.setPrototypeOf({}, null))#null', '#')]
    [TestCase('SetPrototypeOf primitive is returned', 'Object.setPrototypeOf(1, null)#1', '#')]
    [TestCase('SetPrototypeOf cycle throws', '(function () { try { (function () { var a = {}; var b = Object.create(a); Object.setPrototypeOf(a, b); })(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('SetPrototypeOf non-extensible throws', '(function () { try { Object.setPrototypeOf(Object.preventExtensions({}), {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('SetPrototypeOf same prototype on non-extensible succeeds', '(function () { var o = Object.preventExtensions({}); return Object.setPrototypeOf(o, Object.prototype) === o; })()#true', '#')]
    [TestCase('SetPrototypeOf invalid prototype throws', '(function () { try { Object.setPrototypeOf({}, 1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('SetPrototypeOf undefined target throws', '(function () { try { Object.setPrototypeOf(undefined, {}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('SetPrototypeOf has length 2', 'Object.setPrototypeOf.length#2', '#')]
    [TestCase('FromEntries from arrays', 'JSON.stringify(Object.fromEntries([["a", 1], ["b", 2]]))#{"a":1,"b":2}', '#')]
    [TestCase('FromEntries from a custom iterable', 'JSON.stringify(Object.fromEntries({ [Symbol.iterator]() { var i = 0; return { next() { return { done: i++ > 0, value: ["k", "v"] }; } }; } }))#{"k":"v"}', '#')]
    [TestCase('FromEntries closes the iterator for a non-object entry', '(function () { var closed = false; var it = { [Symbol.iterator]() { return { next() { return { done: false, value: 1 }; }, return() { closed = true; return {}; } }; } }; try { Object.fromEntries(it); } catch (e) { return (e instanceof TypeError) + "," + closed; } })()#true,true', '#')]
    [TestCase('FromEntries does not close when next throws', '(function () { var closed = false; var it = { [Symbol.iterator]() { return { next() { throw 1; }, return() { closed = true; return {}; } }; } }; try { Object.fromEntries(it); } catch (e) { return e + "," + closed; } })()#1,false', '#')]
    [TestCase('FromEntries with a symbol key', '(function () { var s = Symbol(); return Object.fromEntries([[s, 1]])[s]; })()#1', '#')]
    [TestCase('FromEntries defines enumerable writable properties', 'JSON.stringify(Object.getOwnPropertyDescriptor(Object.fromEntries([["a", 1]]), "a"))#{"value":1,"writable":true,"enumerable":true,"configurable":true}', '#')]
    [TestCase('FromEntries without an argument throws', '(function () { try { Object.fromEntries(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('FromEntries from a non-iterable throws', '(function () { try { Object.fromEntries({}); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('FromEntries has length 1', 'Object.fromEntries.length#1', '#')]
    procedure ObjectStatic_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('At positive index', '[1, 2, 3].at(1)#2', '#')]
    [TestCase('At negative index', '[1, 2, 3].at(-1)#3', '#')]
    [TestCase('At out of range', '[1, 2, 3].at(5)#undefined', '#')]
    [TestCase('At truncates the index', '[1, 2, 3].at(1.7)#2', '#')]
    [TestCase('At on an array-like', 'Array.prototype.at.call({ length: 2, 0: "a", 1: "b" }, -1)#b', '#')]
    [TestCase('At has length 1', 'Array.prototype.at.length#1', '#')]
    [TestCase('Includes finds a value', '[1, 2, 3].includes(2)#true', '#')]
    [TestCase('Includes finds NaN', '[NaN].includes(NaN)#true', '#')]
    [TestCase('Includes treats a missing argument as undefined', '[undefined].includes()#true', '#')]
    [TestCase('Includes with a start index', '[1, 2, 3].includes(1, 1)#false', '#')]
    [TestCase('Includes with a negative start index', '[1, 2, 3].includes(3, -1)#true', '#')]
    [TestCase('Includes with an infinite start index', '[1].includes(1, Infinity)#false', '#')]
    [TestCase('Includes reads holes as undefined', '[, 1].includes(undefined)#true', '#')]
    [TestCase('Includes treats minus zero as zero', '[0].includes(-0)#true', '#')]
    [TestCase('Includes does not coerce', '["1"].includes(1)#false', '#')]
    [TestCase('Includes on an array-like', 'Array.prototype.includes.call({ length: 1, 0: "x" }, "x")#true', '#')]
    [TestCase('Flat one level', 'JSON.stringify([1, [2, [3]]].flat())#[1,2,[3]]', '#')]
    [TestCase('Flat infinite depth', 'JSON.stringify([1, [2, [3]]].flat(Infinity))#[1,2,3]', '#')]
    [TestCase('Flat depth zero', 'JSON.stringify([1, [2]].flat(0))#[1,[2]]', '#')]
    [TestCase('Flat skips holes', '[1, , 2].flat().length#2', '#')]
    [TestCase('Flat on an array-like', 'JSON.stringify(Array.prototype.flat.call({ length: 2, 0: [1], 1: 2 }))#[1,2]', '#')]
    [TestCase('Flat result is an array', 'Object.getPrototypeOf([1].flat()) === Array.prototype#true', '#')]
    [TestCase('Flat uses the species constructor', '(function () { function C() {} var a = [1]; a.constructor = { [Symbol.species]: C }; return a.flat() instanceof C; })()#true', '#')]
    [TestCase('Flat has length 0', 'Array.prototype.flat.length#0', '#')]
    [TestCase('FlatMap maps and flattens one level', 'JSON.stringify([1, 2].flatMap(function (x) { return [x, x * 2]; }))#[1,2,2,4]', '#')]
    [TestCase('FlatMap does not flatten deeper', 'JSON.stringify([1].flatMap(function (x) { return [[x]]; }))#[[1]]', '#')]
    [TestCase('FlatMap passes thisArg', '[1].flatMap(function () { return [this.v]; }, { v: 7 })[0]#7', '#')]
    [TestCase('FlatMap requires a function', '(function () { try { [1].flatMap(1); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('FlatMap has length 1', 'Array.prototype.flatMap.length#1', '#')]
    [TestCase('Unscopables lists at', 'Array.prototype[Symbol.unscopables].at#true', '#')]
    [TestCase('Find returns the element', '[1, 2, 3].find(function (x) { return x > 1; })#2', '#')]
    [TestCase('FindIndex returns the index', '[1, 2, 3].findIndex(function (x) { return x > 1; })#1', '#')]
    [TestCase('Fill fills a range', '[1, 2, 3].fill(0, 1).join()#1,0,0', '#')]
    [TestCase('CopyWithin copies a range', '[1, 2, 3, 4, 5].copyWithin(0, 3).join()#4,5,3,4,5', '#')]
    procedure ArrayMethod_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('At positive index', '"abc".at(1)#b', '#')]
    [TestCase('At negative index', '"abc".at(-1)#c', '#')]
    [TestCase('At out of range', '"abc".at(3)#undefined', '#')]
    [TestCase('At converts an object index with valueOf', '"abc".at({ valueOf() { return 1; } })#b', '#')]
    [TestCase('At has length 1', 'String.prototype.at.length#1', '#')]
    [TestCase('FromCodePoint of a supplementary code point', 'String.fromCodePoint(65, 128512).length#3', '#')]
    [TestCase('FromCodePoint produces a surrogate pair', 'String.fromCodePoint(128512).charCodeAt(0).toString(16)#d83d', '#')]
    [TestCase('FromCodePoint of a lone surrogate', 'String.fromCodePoint(55357).charCodeAt(0)#55357', '#')]
    [TestCase('FromCodePoint without arguments', 'String.fromCodePoint().length#0', '#')]
    [TestCase('FromCodePoint rejects a fraction', '(function () { try { String.fromCodePoint(1.5); } catch (e) { return e instanceof RangeError; } return false; })()#true', '#')]
    [TestCase('FromCodePoint rejects a code point above the range', '(function () { try { String.fromCodePoint(1114112); } catch (e) { return e instanceof RangeError; } return false; })()#true', '#')]
    [TestCase('FromCodePoint rejects a negative code point', '(function () { try { String.fromCodePoint(-1); } catch (e) { return e instanceof RangeError; } return false; })()#true', '#')]
    [TestCase('FromCodePoint rejects NaN', '(function () { try { String.fromCodePoint(NaN); } catch (e) { return e instanceof RangeError; } return false; })()#true', '#')]
    [TestCase('FromCodePoint converts strings to numbers', 'String.fromCodePoint("65")#A', '#')]
    [TestCase('FromCodePoint has length 1', 'String.fromCodePoint.length#1', '#')]
    [TestCase('StartsWith without arguments searches for undefined', '"abc".startsWith()#false', '#')]
    [TestCase('StartsWith finds the text undefined', '"undefined".startsWith()#true', '#')]
    [TestCase('StartsWith with a position', '"abc".startsWith("c", 2)#true', '#')]
    [TestCase('StartsWith clamps a negative position', '"abc".startsWith("a", -Infinity)#true', '#')]
    [TestCase('EndsWith with an end position', '"abc".endsWith("a", 1)#true', '#')]
    [TestCase('EndsWith clamps an infinite end position', '"abc".endsWith("c", Infinity)#true', '#')]
    [TestCase('EndsWith with an empty search and negative end', '"abc".endsWith("", -1)#true', '#')]
    [TestCase('Includes the empty string', '"abc".includes("")#true', '#')]
    [TestCase('Includes the empty string beyond the end', '"abc".includes("", Infinity)#true', '#')]
    [TestCase('Includes with an infinite position', '"abc".includes("c", Infinity)#false', '#')]
    [TestCase('Includes rejects a regexp', '(function () { try { "a".includes(/a/); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Includes accepts a regexp with a falsy match symbol', '(function () { var o = /a/; o[Symbol.match] = false; return "/a/".includes(o); })()#true', '#')]
    [TestCase('Includes rejects an object with a truthy match symbol', '(function () { try { (function () { var o = { toString() { return "a"; } }; o[Symbol.match] = true; "a".includes(o); })(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('PadStart pads on the left', '"5".padStart(3, "0")#005', '#')]
    [TestCase('PadEnd pads with a pattern', '"5".padEnd(4, "ab")#5aba', '#')]
    [TestCase('Repeat repeats the text', '"ab".repeat(2)#abab', '#')]
    [TestCase('Raw uses the raw strings', 'String.raw`a\n${1}b`#a\n1b', '#')]
    procedure StringMethod_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Epsilon is positive', 'Number.EPSILON > 0 && Number.EPSILON < 1e-15#true', '#')]
    [TestCase('Max safe integer', 'Number.MAX_SAFE_INTEGER#9007199254740991', '#')]
    [TestCase('IsSafeInteger accepts the max safe integer', 'Number.isSafeInteger(Number.MAX_SAFE_INTEGER)#true', '#')]
    [TestCase('IsSafeInteger rejects 2 to the 53', 'Number.isSafeInteger(Math.pow(2, 53))#false', '#')]
    [TestCase('Number.parseFloat is the global function', 'Number.parseFloat === parseFloat#true', '#')]
    [TestCase('Number.parseInt is the global function', 'Number.parseInt === parseInt#true', '#')]
    [TestCase('Object.is distinguishes minus zero', 'Object.is(0, -0)#false', '#')]
    [TestCase('Object.is treats NaN as equal', 'Object.is(NaN, NaN)#true', '#')]
    [TestCase('Object.assign copies symbol keys', '(function () { var s = Symbol(); var t = Object.assign({}, { [s]: 1 }); return t[s]; })()#1', '#')]
    [TestCase('Object.getOwnPropertySymbols lists symbols', '(function () { var s = Symbol(); return Object.getOwnPropertySymbols({ [s]: 1, a: 2 }).length; })()#1', '#')]
    [TestCase('Object.entries lists pairs', 'JSON.stringify(Object.entries({ a: 1 }))#[["a",1]]', '#')]
    [TestCase('Object.values lists values', 'Object.values({ a: 1, b: 2 }).join()#1,2', '#')]
    procedure NumberAndObjectLibrary_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Exponent', '2 ** 3#8', '#')]
    [TestCase('Exponent is right associative', '2 ** 3 ** 2#512', '#')]
    [TestCase('Exponent with a parenthesized unary operand', '(-2) ** 2#4', '#')]
    [TestCase('Exponent with a negative exponent', '2 ** -1#0.5', '#')]
    [TestCase('Exponent binds tighter than multiplication', '2 * 3 ** 2#18', '#')]
    [TestCase('Exponent of a prefix increment', '(function () { var a = 2; return ++a ** 2; })()#9', '#')]
    [TestCase('Exponent assignment', '(function () { var x = 2; x **= 3; return x; })()#8', '#')]
    [TestCase('Exponent assignment on a property', '(function () { var o = { x: 3 }; o.x **= 2; return o.x; })()#9', '#')]
    [TestCase('Exponent matches Math.pow', 'Math.pow(2, 0.5) === 2 ** 0.5#true', '#')]
    [TestCase('Exponent of one and infinity is NaN', '1 ** Infinity#NaN', '#')]
    [TestCase('Unary minus before an exponent is a syntax error', '(function () { try { eval("-2 ** 2"); } catch (e) { return e instanceof SyntaxError; } return false; })()#true', '#')]
    [TestCase('Typeof before an exponent is a syntax error', '(function () { try { eval("typeof 2 ** 2"); } catch (e) { return e instanceof SyntaxError; } return false; })()#true', '#')]
    [TestCase('Negated exponent in parentheses', '-(2 ** 2)#-4', '#')]
    procedure ExponentiationOperator_ReturnsSpecResult(const Expression, Expected: string);

  end;

implementation

procedure TLibraryMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TLibraryMethodsTests.TearDown;
begin
  FEngine.Free;
end;

function TLibraryMethodsTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TLibraryMethodsTests.ObjectStatic_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TLibraryMethodsTests.ArrayMethod_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TLibraryMethodsTests.StringMethod_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TLibraryMethodsTests.NumberAndObjectLibrary_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TLibraryMethodsTests.ExponentiationOperator_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
