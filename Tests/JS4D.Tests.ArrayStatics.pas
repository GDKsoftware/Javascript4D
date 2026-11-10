unit JS4D.Tests.ArrayStatics;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TArrayStaticsTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;
    function ErrorNameOf(const Statements: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Items', 'Array.of(1, 2, 3).join()#1,2,3', '#')]
    [TestCase('Empty', 'Array.of().length#0', '#')]
    [TestCase('SingleNumber', 'Array.of(7).length#1', '#')]
    [TestCase('KeepsUndefined', 'Array.of(undefined, null).length#2', '#')]
    [TestCase('IsArray', 'Array.isArray(Array.of(1))#true', '#')]
    [TestCase('Length', 'Array.of.length#0', '#')]
    [TestCase('Name', 'Array.of.name#of', '#')]
    [TestCase('NotEnumerable', 'Object.keys(Array).indexOf("of")#-1', '#')]
    [TestCase('CustomConstructor', 'function C() {} var r = Array.of.call(C, "a", "b"); "" + (r instanceof C) + r.length + r[1]#true2b', '#')]
    [TestCase('ConstructorReceivesCount', 'var n; function C(count) { n = count; } Array.of.call(C, 1, 2, 3); n#3', '#')]
    [TestCase('NonConstructorThis', 'Array.isArray(Array.of.call({}, 1, 2))#true', '#')]
    [TestCase('OverwritesReadOnlyIndex',
      'function C() { Object.defineProperty(this, "0", {value: 1, writable: false, configurable: true}); } ' +
      'var d = Object.getOwnPropertyDescriptor(Array.of.call(C, 2), "0"); d.value + "" + d.writable + d.enumerable#2truetrue', '#')]
    [TestCase('LengthSetterReceivesCount',
      'var seen; function C() { Object.defineProperty(this, "length", {set: function(v) { seen = v; }}); } ' +
      'Array.of.call(C, 1, 2, 3, 4); seen#4', '#')]
    procedure ArrayOf_Result(const Expression: string; const Expected: string);

    [Test]
    [TestCase('Array', 'Array.from([1, 2, 3]).join()#1,2,3', '#')]
    [TestCase('String', 'Array.from("abc").join("-")#a-b-c', '#')]
    [TestCase('SurrogatePair', 'Array.from("a\uD83D\uDE00b").length#3', '#')]
    [TestCase('ArrayLike', 'Array.from({0: "x", 1: "y", length: 2}).join()#x,y', '#')]
    [TestCase('ArrayLikeMissingLength', 'Array.from({0: "x"}).length#0', '#')]
    [TestCase('Number', 'Array.from(5).length#0', '#')]
    [TestCase('Arguments', '(function() { return Array.from(arguments).join(); })(4, 5)#4,5', '#')]
    [TestCase('HolesBecomeUndefined', 'var r = Array.from([1, , 3]); (1 in r) + "" + r.length#true3', '#')]
    [TestCase('MapFunction', 'Array.from([1, 2, 3], function(v, k) { return v * 10 + k; }).join()#10,21,32', '#')]
    [TestCase('MapFunctionOnArrayLike', 'Array.from({0: 1, 1: 2, length: 2}, function(v) { return v * 2; }).join()#2,4', '#')]
    [TestCase('MapThisArg', 'Array.from([1], function() { return this.tag; }, {tag: "t"})[0]#t', '#')]
    [TestCase('MapReceivesTwoArguments', 'Array.from([9], function() { return arguments.length; })[0]#2', '#')]
    [TestCase('SeesElementsRemovedDuringMapping', 'var a = [0, 1, 2, 3]; Array.from(a, function() { a.pop(); return 1; }).length#2', '#')]
    [TestCase('SeesElementsChangedDuringMapping', 'var a = [1, 2, 3]; Array.from(a, function(v, k) { if (k + 1 < a.length) a[k + 1] = 7; return v; }).join()#1,7,7', '#')]
    [TestCase('CustomConstructorForArrayLike',
      'function C(n) { this.got = n; } var r = Array.from.call(C, {length: 3}); (r instanceof C) + "" + r.got + r.length#true33', '#')]
    [TestCase('CustomConstructorForIterable',
      'function C() { this.got = arguments.length; } var r = Array.from.call(C, [5, 6]); r.got + "" + r.length + r[1]#026', '#')]
    [TestCase('ObjectAsConstructor', 'Array.from.call(Object, []).constructor === Object#true', '#')]
    [TestCase('Length', 'Array.from.length#1', '#')]
    [TestCase('FromArrayIterator', 'Array.from([5, 6].keys()).join()#0,1', '#')]
    procedure ArrayFrom_Result(const Expression: string; const Expected: string);

    [Test]
    [TestCase('Of_ThrowingConstructor', 'function C() { throw new RangeError(); } Array.of.call(C)#RangeError', '#')]
    [TestCase('Of_ThrowingLengthSetter',
      'function C() { Object.defineProperty(this, "length", {set: function() { throw new EvalError(); }}); } Array.of.call(C)#EvalError', '#')]
    [TestCase('From_Null', 'Array.from(null)#TypeError', '#')]
    [TestCase('From_Undefined', 'Array.from(undefined)#TypeError', '#')]
    [TestCase('From_MapNull', 'Array.from([], null)#TypeError', '#')]
    [TestCase('From_MapObject', 'Array.from([], {})#TypeError', '#')]
    [TestCase('From_MapNumber', 'Array.from([], 42)#TypeError', '#')]
    [TestCase('From_MapThrows', 'Array.from([1], function() { throw new URIError(); })#URIError', '#')]
    [TestCase('From_NonExtensibleResult',
      'function C() { this.length = 0; Object.preventExtensions(this); } Array.from.call(C, {length: 1})#TypeError', '#')]
    [TestCase('From_NonConfigurableIndex',
      'function C() { Object.defineProperty(this, "0", {writable: true, configurable: false}); } Array.from.call(C, {length: 1})#TypeError', '#')]
    procedure Statics_RaiseError(const Statements: string; const Expected: string);
  end;

implementation

procedure TArrayStaticsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayStaticsTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayStaticsTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Expression).ToString;
end;

function TArrayStaticsTests.ErrorNameOf(const Statements: string): string;
begin
  const Wrapper = Format('var caught = "none"; try { %s } catch (e) { caught = e.name; }', [Statements]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TArrayStaticsTests.ArrayOf_Result(const Expression: string; const Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TArrayStaticsTests.ArrayFrom_Result(const Expression: string; const Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TArrayStaticsTests.Statics_RaiseError(const Statements: string; const Expected: string);
begin
  Assert.AreEqual(Expected, ErrorNameOf(Statements));
end;

end.
