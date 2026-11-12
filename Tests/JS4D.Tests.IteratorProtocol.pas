unit JS4D.Tests.IteratorProtocol;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TIteratorProtocolTests = class
  private
    const
      ITERABLE = 'var iterable = { [Symbol.iterator]() { var i = 0; return { next() { ' +
                 'return i < 3 ? { value: i++, done: false } : { value: undefined, done: true }; } }; } }; ';
      CLOSABLE = 'var log = []; var endless = { [Symbol.iterator]() { return { next() { ' +
                 'return { value: 1, done: false }; }, return() { log.push("r"); return {}; } }; } }; ';

    var
      FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;
    procedure AssertEvaluatesTo(const Expected: string; const Source: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('ArrayHasIterator', 'typeof [][Symbol.iterator]|function', '|')]
    [TestCase('ArrayIteratorIsValues', 'Array.prototype[Symbol.iterator] === Array.prototype.values|true', '|')]
    [TestCase('ArrayIteratorDescriptor', 'var d = Object.getOwnPropertyDescriptor(Array.prototype, Symbol.iterator); d.writable + "," + d.enumerable + "," + d.configurable|true,false,true', '|')]
    [TestCase('StringIteratorName', 'String.prototype[Symbol.iterator].name|[Symbol.iterator]', '|')]
    [TestCase('StringIteratorLength', 'String.prototype[Symbol.iterator].length|0', '|')]
    [TestCase('StringIteratorDescriptor', 'var d = Object.getOwnPropertyDescriptor(String.prototype, Symbol.iterator); d.writable + "," + d.enumerable + "," + d.configurable|true,false,true', '|')]
    [TestCase('ArgumentsIterator', '(function () { return arguments[Symbol.iterator] === Array.prototype.values; })()|true', '|')]
    [TestCase('ArgumentsIteratorIsNotEnumerable', '(function () { return Object.keys(arguments).join(); })(5, 6)|0,1', '|')]
    [TestCase('StrictArgumentsIterator', '(function () { "use strict"; return arguments[Symbol.iterator] === Array.prototype.values; })()|true', '|')]
    [TestCase('ArrayIteratorTag', 'Object.prototype.toString.call([][Symbol.iterator]())|[object Array Iterator]', '|')]
    [TestCase('StringIteratorTag', 'Object.prototype.toString.call(""[Symbol.iterator]())|[object String Iterator]', '|')]
    [TestCase('TagDescriptor', 'var p = Object.getPrototypeOf([][Symbol.iterator]()); var d = Object.getOwnPropertyDescriptor(p, Symbol.toStringTag); d.writable + "," + d.enumerable + "," + d.configurable|false,false,true', '|')]
    [TestCase('IteratorPrototypeReturnsThis', 'var it = [][Symbol.iterator](); it[Symbol.iterator]() === it|true', '|')]
    [TestCase('IteratorPrototypeIsShared', 'var a = Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]())); var s = Object.getPrototypeOf(Object.getPrototypeOf(""[Symbol.iterator]())); a === s|true', '|')]
    [TestCase('IteratorPrototypeMethodName', 'var a = Object.getPrototypeOf(Object.getPrototypeOf([][Symbol.iterator]())); a[Symbol.iterator].name|[Symbol.iterator]', '|')]
    [TestCase('ArrayIteratorNextIsHidden', 'Object.keys(Object.getPrototypeOf([][Symbol.iterator]())).length|0', '|')]
    [TestCase('StringIteratorSteps', 'var it = "a'#$D83D#$DE00'b"[Symbol.iterator](); var r = []; var s; while (!(s = it.next()).done) r.push(s.value.length); r.join() + "," + it.next().done|1,2,1,true', '|')]
    [TestCase('StringIteratorResultShape', 'var s = "x"[Symbol.iterator]().next(); Object.keys(s).join() + s.value + s.done|value,donexfalse', '|')]
    [TestCase('StringIteratorOfNumberCoercion', 'String.prototype[Symbol.iterator].call(12).next().value|1', '|')]
    [TestCase('ArrayIteratorNextLength', 'Object.getPrototypeOf([][Symbol.iterator]()).next.length|0', '|')]
    [TestCase('ArrayIteratorNextIsNotAConstructor', 'try { new (Object.getPrototypeOf([][Symbol.iterator]()).next)(); } catch (e) { e.name }|TypeError', '|')]
    [TestCase('ArrayIteratorDone', 'var it = [1][Symbol.iterator](); it.next(); var s = it.next(); s.done + "," + s.value|true,undefined', '|')]
    procedure Intrinsics_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('ForOf', ITERABLE + 'var r = ""; for (var x of iterable) r += x; r|012', '|')]
    [TestCase('ForOfLetClosures', ITERABLE + 'var f = []; for (let x of iterable) f.push(() => x); f[0]() + "," + f[2]()|0,2', '|')]
    [TestCase('ArraySpread', ITERABLE + '[...iterable, 9].join()|0,1,2,9', '|')]
    [TestCase('CallSpread', ITERABLE + 'Math.max(...iterable)|2', '|')]
    [TestCase('NewSpread', ITERABLE + 'function C(a, b, c) { this.s = a + b + c; } new C(...iterable).s|3', '|')]
    [TestCase('BindingDestructuring', ITERABLE + 'var [a, b] = iterable; a + "," + b|0,1', '|')]
    [TestCase('BindingDestructuringRest', ITERABLE + 'var [a, ...b] = iterable; a + ":" + b.join()|0:1,2', '|')]
    [TestCase('BindingDestructuringHole', ITERABLE + 'var [, b] = iterable; b|1', '|')]
    [TestCase('BindingDestructuringDefault', ITERABLE + 'var [a, b, c, d = "d"] = iterable; d|d', '|')]
    [TestCase('AssignmentDestructuring', ITERABLE + 'var a, b; [a, b] = iterable; a + "," + b|0,1', '|')]
    [TestCase('ParameterDestructuring', ITERABLE + 'function f([a, b]) { return a + b; } f(iterable)|1', '|')]
    [TestCase('ArrayFrom', ITERABLE + 'Array.from(iterable).join()|0,1,2', '|')]
    [TestCase('ArrayFromConstructsBeforeOpeningTheIterator', 'var C = function () { throw new RangeError(); }; var items = {}; items[Symbol.iterator] = function () {}; try { Array.from.call(C, items); } catch (e) { e.name }|RangeError', '|')]
    [TestCase('ArrayFromMapper', ITERABLE + 'Array.from(iterable, x => x * 2).join()|0,2,4', '|')]
    [TestCase('ArrayFromWithConstructor', ITERABLE + 'function C() {} var r = Array.from.call(C, iterable); (r instanceof C) + "," + r.length|true,3', '|')]
    [TestCase('ArrayIteratorObject', 'var r = []; for (var x of [5, 6].values()) r.push(x); r.join()|5,6', '|')]
    [TestCase('EntriesIterator', 'var r = []; for (var [i, v] of ["a", "b"].entries()) r.push(i + v); r.join()|0a,1b', '|')]
    [TestCase('KeysSpread', '[...["a", "b"].keys()].join()|0,1', '|')]
    [TestCase('StringIteratorObject', 'var r = []; for (var c of ""[Symbol.iterator].call("xy")) r.push(c); r.join()|x,y', '|')]
    [TestCase('IteratorOfIterator', 'var it = [1, 2][Symbol.iterator](); it.next(); [...it].join()|2', '|')]
    [TestCase('StringWrapper', 'var r = []; for (var c of new String("ab")) r.push(c); r.join()|a,b', '|')]
    [TestCase('ArrayLikeWithIteratorMethod', 'var o = { length: 2, 0: "a", 1: "b", [Symbol.iterator]: Array.prototype[Symbol.iterator] }; [...o].join()|a,b', '|')]
    [TestCase('OwnIteratorOnArray', 'var a = [1, 2]; a[Symbol.iterator] = function () { return [9][Symbol.iterator](); }; [...a].join()|9', '|')]
    [TestCase('IteratorOnArrayPrototypeReplaced', 'var orig = Array.prototype[Symbol.iterator]; Array.prototype[Symbol.iterator] = function () { return orig.call([7]); }; var r = [...[1, 2]].join(); Array.prototype[Symbol.iterator] = orig; r|7', '|')]
    [TestCase('ArrayIteratorNextReplaced', 'var p = Object.getPrototypeOf([][Symbol.iterator]()); var orig = p.next; p.next = function () { return { done: true }; }; var r = [...[1, 2]].length; p.next = orig; r|0', '|')]
    [TestCase('StringIteratorReplaced', 'var orig = String.prototype[Symbol.iterator]; String.prototype[Symbol.iterator] = function () { return [1, 2][Symbol.iterator](); }; var r = [..."abc"].join(); String.prototype[Symbol.iterator] = orig; r|1,2', '|')]
    [TestCase('StringIteratorNextReplaced', 'var p = Object.getPrototypeOf(""[Symbol.iterator]()); var orig = p.next; p.next = function () { return { done: true }; }; var r = [..."abc"].length; p.next = orig; r|0', '|')]
    [TestCase('ArgumentsIteratorReplaced', '(function () { arguments[Symbol.iterator] = function () { return [3][Symbol.iterator](); }; return [...arguments].join(); })(1, 2)|3', '|')]
    [TestCase('DeletedIteratorMakesArrayNotIterable', 'var orig = Array.prototype[Symbol.iterator]; delete Array.prototype[Symbol.iterator]; var r; try { [...[1]]; r = "no"; } catch (e) { r = e.name; } Array.prototype[Symbol.iterator] = orig; r|TypeError', '|')]
    [TestCase('IteratorGetterObserved', 'var n = 0; var o = { get [Symbol.iterator]() { n++; return function () { return [1][Symbol.iterator](); }; } }; [...o]; n|1', '|')]
    [TestCase('IteratorMethodReceivesIterable', 'var self; var o = { [Symbol.iterator]() { self = this; return [][Symbol.iterator](); } }; [...o]; self === o|true', '|')]
    [TestCase('NextReceivesIterator', 'var self; var it = { next() { self = this; return { done: true }; } }; var o = { [Symbol.iterator]() { return it; } }; [...o]; self === it|true', '|')]
    [TestCase('NextReadOncePerIteration', 'var n = 0; var it = { get next() { n++; return function () { return { done: true }; }; } }; var o = { [Symbol.iterator]() { return it; } }; [...o]; [...o]; n|2', '|')]
    [TestCase('DoneIsConvertedToBoolean', 'var o = { [Symbol.iterator]() { return { next() { return { done: 1 }; } }; } }; [...o].length|0', '|')]
    [TestCase('ValueNotReadWhenDone', 'var read = false; var o = { [Symbol.iterator]() { return { next() { return { done: true, get value() { read = true; } }; } }; } }; [...o]; read|false', '|')]
    procedure Iterates_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('StringIteratorNextOnArrayIterator', 'Object.getPrototypeOf(""[Symbol.iterator]()).next.call([][Symbol.iterator]())|TypeError', '|')]
    [TestCase('ArrayIteratorNextOnStringIterator', 'Object.getPrototypeOf([][Symbol.iterator]()).next.call(""[Symbol.iterator]())|TypeError', '|')]
    [TestCase('ArrayIteratorNextOnObject', 'Object.getPrototypeOf([][Symbol.iterator]()).next.call({})|TypeError', '|')]
    [TestCase('StringIteratorOnNull', 'String.prototype[Symbol.iterator].call(null)|TypeError', '|')]
    [TestCase('StringIteratorOnUndefined', 'String.prototype[Symbol.iterator].call(undefined)|TypeError', '|')]
    [TestCase('StringIteratorIsNotAConstructor', 'new String.prototype[Symbol.iterator]()|TypeError', '|')]
    [TestCase('ForOfObject', 'for (var x of {}) {}|TypeError', '|')]
    [TestCase('SpreadNumber', '[...1]|TypeError', '|')]
    [TestCase('DestructureNull', 'var [a] = null|TypeError', '|')]
    [TestCase('ForOfUndefined', 'for (var x of undefined) {}|TypeError', '|')]
    [TestCase('IteratorNotCallable', 'for (var x of { [Symbol.iterator]: 1 }) {}|TypeError', '|')]
    [TestCase('IteratorNull', 'for (var x of { [Symbol.iterator]: null }) {}|TypeError', '|')]
    [TestCase('IteratorMethodReturnsPrimitive', 'for (var x of { [Symbol.iterator]() { return 1; } }) {}|TypeError', '|')]
    [TestCase('IteratorMethodReturnsUndefined', 'var [a] = { [Symbol.iterator]() {} }|TypeError', '|')]
    [TestCase('NextNotCallable', 'for (var x of { [Symbol.iterator]() { return { next: 1 }; } }) {}|TypeError', '|')]
    [TestCase('NextMissing', '[...{ [Symbol.iterator]() { return {}; } }]|TypeError', '|')]
    [TestCase('ResultNotObject', 'for (var x of { [Symbol.iterator]() { return { next() { return 1; } }; } }) {}|TypeError', '|')]
    [TestCase('ResultUndefined', 'Array.from({ [Symbol.iterator]() { return { next() {} }; } })|TypeError', '|')]
    [TestCase('NextThrows', 'for (var x of { [Symbol.iterator]() { return { next() { throw new RangeError(); } }; } }) {}|RangeError', '|')]
    [TestCase('DoneGetterThrows', 'var [a] = { [Symbol.iterator]() { return { next() { return { get done() { throw new RangeError(); } }; } }; } }|RangeError', '|')]
    [TestCase('ValueGetterThrows', '[...{ [Symbol.iterator]() { return { next() { return { done: false, get value() { throw new RangeError(); } }; } }; } }]|RangeError', '|')]
    [TestCase('BreakWithThrowingReturn', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw new RangeError(); } }; } }; for (var x of o) { break; }|RangeError', '|')]
    [TestCase('BreakWithPrimitiveReturnResult', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { return 1; } }; } }; for (var x of o) { break; }|TypeError', '|')]
    [TestCase('ReturnWithPrimitiveReturnResult', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { return 1; } }; } }; (function () { for (var x of o) { return; } })()|TypeError', '|')]
    [TestCase('ReturnNotCallable', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return: 1 }; } }; for (var x of o) { break; }|TypeError', '|')]
    [TestCase('DestructuringWithPrimitiveReturnResult', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { return 1; } }; } }; var [a] = o;|TypeError', '|')]
    [TestCase('BodyErrorWinsOverReturnError', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw new RangeError(); } }; } }; for (var x of o) { throw new EvalError(); }|EvalError', '|')]
    [TestCase('BodyErrorWinsOverPrimitiveReturnResult', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { return 1; } }; } }; for (var x of o) { throw new EvalError(); }|EvalError', '|')]
    [TestCase('DestructuringErrorWinsOverReturnError', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw new RangeError(); } }; } }; var [a = (function () { throw new EvalError(); })()] = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw new RangeError(); } }; } };|EvalError', '|')]
    [TestCase('ArrayFromMapperErrorWinsOverReturnError', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return() { throw new RangeError(); } }; } }; Array.from(o, function () { throw new EvalError(); });|EvalError', '|')]
    procedure Iterating_RaisesError(const Source: string; const Expected: string);

    [Test]
    [TestCase('Break', CLOSABLE + 'for (var x of endless) { break; } log.join()|r', '|')]
    [TestCase('Return', CLOSABLE + '(function () { for (var x of endless) { return 1; } })(); log.join()|r', '|')]
    [TestCase('Throw', CLOSABLE + 'try { for (var x of endless) { throw 1; } } catch (e) {} log.join()|r', '|')]
    [TestCase('ContinueOuterLoop', CLOSABLE + 'outer: for (var i of [1, 2]) { for (var x of endless) { continue outer; } } log.join()|r,r', '|')]
    [TestCase('BreakOuterLabel', CLOSABLE + 'outer: for (var i of [1]) { for (var x of endless) { break outer; } } log.join()|r', '|')]
    [TestCase('BreakOwnLabel', CLOSABLE + 'own: for (var x of endless) { break own; } log.join()|r', '|')]
    [TestCase('ContinueKeepsIterating', CLOSABLE + 'var n = 0; for (var x of endless) { if (++n == 3) break; continue; } log.join() + n|r3', '|')]
    [TestCase('ExhaustedIteratorIsNotClosed', CLOSABLE + 'var done = { [Symbol.iterator]() { return { next() { return { done: true }; }, return() { log.push("r"); return {}; } }; } }; for (var x of done) {} log.length|0', '|')]
    [TestCase('NestedBreakClosesBoth', CLOSABLE + 'for (var a of endless) { for (var b of endless) { break; } break; } log.join()|r,r', '|')]
    [TestCase('FinallyRunsBeforeClose', CLOSABLE + 'for (var x of endless) { try { break; } finally { log.push("f"); } } log.join()|f,r', '|')]
    [TestCase('ReturnMethodMissing', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; } }; } }; for (var x of o) { break; } 1|1', '|')]
    [TestCase('ReturnNullIsIgnored', 'var o = { [Symbol.iterator]() { return { next() { return { done: false }; }, return: null }; } }; for (var x of o) { break; } 1|1', '|')]
    [TestCase('ReturnReceivesIteratorAsThis', 'var self, it; var o = { [Symbol.iterator]() { it = { next() { return { done: false }; }, return() { self = this; return {}; } }; return it; } }; for (var x of o) { break; } self === it|true', '|')]
    [TestCase('LetHeadDestructuringErrorCloses', 'var log = []; var e = { [Symbol.iterator]() { return { next() { return { value: null, done: false }; }, return() { log.push("r"); return {}; } }; } }; try { for (let [a] of e) {} } catch (err) { log.push(err.name); } log.join()|r,TypeError', '|')]
    [TestCase('DestructuringOneOfEndless', CLOSABLE + 'var [a] = endless; log.join()|r', '|')]
    [TestCase('DestructuringNothingFromEndless', CLOSABLE + 'var [] = endless; log.join()|r', '|')]
    [TestCase('DestructuringHoleFromEndless', CLOSABLE + 'var [,] = endless; log.join()|r', '|')]
    [TestCase('AssignmentDestructuringCloses', CLOSABLE + 'var a; [a] = endless; log.join()|r', '|')]
    [TestCase('ParameterDestructuringCloses', CLOSABLE + '(function ([a]) {})(endless); log.join()|r', '|')]
    [TestCase('DestructuringRestIsNotClosed', CLOSABLE + 'var finite = { [Symbol.iterator]() { var n = 0; return { next() { return n++ < 2 ? { value: n, done: false } : { done: true }; }, return() { log.push("r"); return {}; } }; } }; var [a, ...b] = finite; log.length + ":" + b.join()|0:2', '|')]
    [TestCase('DestructuringExhaustedIsNotClosed', CLOSABLE + 'var done = { [Symbol.iterator]() { return { next() { return { done: true }; }, return() { log.push("r"); return {}; } }; } }; var [a, b] = done; log.length|0', '|')]
    [TestCase('DestructuringDefaultThrowCloses', CLOSABLE + 'var undef = { [Symbol.iterator]() { return { next() { return { value: undefined, done: false }; }, return() { log.push("r"); return {}; } }; } }; try { var [a = (function () { throw new RangeError(); })()] = undef; } catch (e) { log.push(e.name); } log.join()|r,RangeError', '|')]
    [TestCase('DestructuringTargetThrowCloses', CLOSABLE + 'try { [ (function () { throw new RangeError(); })().x ] = endless; } catch (e) { log.push(e.name); } log.join()|r,RangeError', '|')]
    [TestCase('NextThrowDoesNotClose', CLOSABLE + 'var bad = { [Symbol.iterator]() { return { next() { throw new RangeError(); }, return() { log.push("r"); return {}; } }; } }; try { var [a] = bad; } catch (e) {} log.length|0', '|')]
    [TestCase('NextThrowInForOfDoesNotClose', CLOSABLE + 'var bad = { [Symbol.iterator]() { return { next() { throw new RangeError(); }, return() { log.push("r"); return {}; } }; } }; try { for (var x of bad) {} } catch (e) {} log.length|0', '|')]
    [TestCase('ArrayFromMapperThrowCloses', CLOSABLE + 'try { Array.from(endless, function () { throw new RangeError(); }); } catch (e) { log.push(e.name); } log.join()|r,RangeError', '|')]
    [TestCase('ArrayFromExhaustedIsNotClosed', CLOSABLE + 'var done = { [Symbol.iterator]() { return { next() { return { done: true }; }, return() { log.push("r"); return {}; } }; } }; Array.from(done); log.length|0', '|')]
    procedure Closing_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('ForOfOverArguments', '(function () { var r = ""; for (var x of arguments) r += x; return r; })(1, 2, 3)|123', '|')]
    [TestCase('SpreadOfArguments', '(function () { return [...arguments].length; })(1, 2, 3)|3', '|')]
    [TestCase('ArrayFromArguments', '(function () { return Array.from(arguments).join(); })(1, 2)|1,2', '|')]
    [TestCase('DestructureArguments', '(function () { var [a, b] = arguments; return a + b; })(1, 2)|3', '|')]
    [TestCase('ArrayFromString', 'Array.from("a'#$D83D#$DE00'").length|2', '|')]
    [TestCase('ArrayFromArrayLike', 'Array.from({ length: 2, 0: "a", 1: "b" }).join()|a,b', '|')]
    [TestCase('SpreadWithHoles', '[...[1, , 3]].hasOwnProperty(1)|true', '|')]
    procedure FastPaths_Result(const Source: string; const Expected: string);
  end;

implementation

procedure TIteratorProtocolTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TIteratorProtocolTests.TearDown;
begin
  FEngine.Free;
end;

function TIteratorProtocolTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const Wrapper = Format('var caught = "none"; try { eval("%s"); } catch (e) { caught = e.name; }', [QuotesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TIteratorProtocolTests.AssertEvaluatesTo(const Expected: string; const Source: string);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).ToString);
end;

procedure TIteratorProtocolTests.Intrinsics_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TIteratorProtocolTests.Iterates_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TIteratorProtocolTests.Iterating_RaisesError(const Source: string; const Expected: string);
begin
  Assert.AreEqual(Expected, ErrorNameOf(Source));
end;

procedure TIteratorProtocolTests.Closing_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TIteratorProtocolTests.FastPaths_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

end.
