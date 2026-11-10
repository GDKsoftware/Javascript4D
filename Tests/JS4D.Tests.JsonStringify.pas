unit JS4D.Tests.JsonStringify;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TJsonStringifyTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Integer', 'JSON.stringify(123)@123', '@')]
    [TestCase('Fraction', 'JSON.stringify({"a":1.5})@{"a":1.5}', '@')]
    [TestCase('NegativeZero', 'JSON.stringify(-0)@0', '@')]
    [TestCase('LargeExponent', 'JSON.stringify(1e21)@1e+21', '@')]
    [TestCase('NotFinite', 'JSON.stringify([NaN, Infinity, -Infinity])@[null,null,null]', '@')]
    [TestCase('Strings', 'JSON.stringify("a\"b\\c")@"a\"b\\c"', '@')]
    [TestCase('ControlCharacters', 'JSON.stringify("\u0001\b\f\n\r\t")@"\u0001\b\f\n\r\t"', '@')]
    [TestCase('BooleanAndNull', 'JSON.stringify([true, false, null])@[true,false,null]', '@')]
    procedure Stringify_Primitive_ReturnsJsonText(const Script, Expected: string);

    [Test]
    [TestCase('Undefined', 'String(JSON.stringify(undefined))@undefined', '@')]
    [TestCase('Function', 'String(JSON.stringify(function () {}))@undefined', '@')]
    [TestCase('NoArguments', 'String(JSON.stringify())@undefined', '@')]
    [TestCase('ArrayElement', 'JSON.stringify([undefined, function () {}])@[null,null]', '@')]
    [TestCase('ObjectMember', 'JSON.stringify({"a":undefined,"b":function () {},"c":1})@{"c":1}', '@')]
    procedure Stringify_NotSerializable_ReturnsUndefinedOrNull(const Script, Expected: string);

    [Test]
    [TestCase('Number', 'JSON.stringify(new Number(8.5))@8.5', '@')]
    [TestCase('String', 'JSON.stringify(new String("str"))@"str"', '@')]
    [TestCase('Boolean', 'JSON.stringify(new Boolean(true))@true', '@')]
    [TestCase('NumberValueOf', 'var n = new Number(1); n.valueOf = function () { return 7; }; JSON.stringify(n)@7', '@')]
    [TestCase('StringToString', 'var s = new String("a"); s.toString = function () { return "b"; }; JSON.stringify(s)@"b"', '@')]
    procedure Stringify_PrimitiveWrapper_UsesPrimitiveValue(const Script, Expected: string);

    [Test]
    [TestCase('ToJson', 'JSON.stringify({"toJSON": function (k) { return "x" + k; }})@"x"', '@')]
    [TestCase('ToJsonMember', 'JSON.stringify({"a": {"toJSON": function (k) { return k + "!"; }}})@{"a":"a!"}', '@')]
    [TestCase('ToJsonOnPrimitiveWrapper', 'Number.prototype.toJSON = function () { return "n"; }; JSON.stringify(new Number(1))@"n"', '@')]
    [TestCase('ToJsonNotReadFromPrimitive', 'Number.prototype.toJSON = function () { return "n"; }; JSON.stringify(1)@1', '@')]
    [TestCase('ToJsonNotFunction', 'JSON.stringify({"toJSON": 1})@{"toJSON":1}', '@')]
    [TestCase('Date', 'JSON.stringify(new Date(0))@"1970-01-01T00:00:00.000Z"', '@')]
    procedure Stringify_ToJson_ReplacesValue(const Script, Expected: string);

    [Test]
    [TestCase('Doubles', 'JSON.stringify({"a":1,"b":2}, function (k, v) { return typeof v === "number" ? v * 2 : v; })@{"a":2,"b":4}', '@')]
    [TestCase('WrapperHolder', 'var seen; JSON.stringify(1, function (k, v) { seen = typeof this + ":" + k; return v; }); seen@object:', '@')]
    [TestCase('HolderIsParent', 'var out = []; JSON.stringify({"a":{"b":1}}, function (k, v) { out.push(k); return v; }); out.join(",")@,a,b', '@')]
    [TestCase('ReturnUndefinedDropsMember', 'JSON.stringify({"a":1,"b":2}, function (k, v) { return k === "a" ? undefined : v; })@{"b":2}', '@')]
    [TestCase('ReturnUndefinedTopLevel', 'String(JSON.stringify(1, function () {}))@undefined', '@')]
    [TestCase('ReplacesObject', 'JSON.stringify({"a":1}, function (k, v) { return k === "" ? [1, 2] : v; })@[1,2]', '@')]
    [TestCase('ToJsonBeforeReplacer', 'JSON.stringify({"toJSON": function () { return 1; }}, function (k, v) { return v + 1; })@2', '@')]
    [TestCase('DeletedProperty', 'JSON.stringify({"a":1,"b":2}, function (k, v) { if (k === "a") { delete this.b; } return v; })@{"a":1}', '@')]
    procedure Stringify_ReplacerFunction_TransformsValues(const Script, Expected: string);

    [Test]
    [TestCase('Order', 'JSON.stringify({"a":1,"b":2,"c":3}, ["c", "a"])@{"c":3,"a":1}', '@')]
    [TestCase('Empty', 'JSON.stringify({"a":1,"b":2}, [])@{}', '@')]
    [TestCase('Duplicates', 'JSON.stringify({"a":1,"b":2}, ["a", "a", "b"])@{"a":1,"b":2}', '@')]
    [TestCase('Numbers', 'JSON.stringify({"1":"x","a":2}, [1])@{"1":"x"}', '@')]
    [TestCase('Wrappers', 'JSON.stringify({"1":1,"s":2,"t":3}, [new Number(1), new String("s")])@{"1":1,"s":2}', '@')]
    [TestCase('IgnoresOtherTypes', 'JSON.stringify({"undefined":1,"null":2,"true":3}, [undefined, null, true, {}])@{}', '@')]
    [TestCase('AppliesToNestedObjects', 'JSON.stringify({"a":{"a":1,"b":2},"b":3}, ["a"])@{"a":{"a":1}}', '@')]
    [TestCase('NotAppliedToArrays', 'JSON.stringify([{"a":1,"b":2}], ["a"])@[{"a":1}]', '@')]
    procedure Stringify_ReplacerArray_FiltersAndOrdersKeys(const Script, Expected: string);

    [Test]
    [TestCase('Number', 'JSON.stringify({"a":[1]}, null, 2).split("\n").join("/")@{/  "a": [/    1/  ]/}', '@')]
    [TestCase('String', 'JSON.stringify({"a":1}, null, "--").split("\n").join("/")@{/--"a": 1/}', '@')]
    [TestCase('NumberClamped', 'JSON.stringify([1], null, 99).split("\n")[1].length@11', '@')]
    [TestCase('StringClamped', 'JSON.stringify([1], null, "abcdefghijklmnop").split("\n")[1].length@11', '@')]
    [TestCase('NumberObject', 'JSON.stringify([1], null, new Number(1)).split("\n").join("/")@[/ 1/]', '@')]
    [TestCase('StringObject', 'JSON.stringify([1], null, new String("x")).split("\n").join("/")@[/x1/]', '@')]
    [TestCase('Fractional', 'JSON.stringify([1], null, 1.9).split("\n").join("/")@[/ 1/]', '@')]
    [TestCase('ZeroGap', 'JSON.stringify({"a":1}, null, 0)@{"a":1}', '@')]
    [TestCase('EmptyGap', 'JSON.stringify({"a":1}, null, "")@{"a":1}', '@')]
    [TestCase('IgnoredType', 'JSON.stringify({"a":1}, null, true)@{"a":1}', '@')]
    [TestCase('EmptyContainers', 'JSON.stringify({"a":[],"b":{}}, null, 1).split("\n").join("/")@{/ "a": [],/ "b": {}/}', '@')]
    procedure Stringify_Space_IndentsOutput(const Script, Expected: string);

    [Test]
    [TestCase('Object', 'var o = {}; o.self = o; try { JSON.stringify(o) } finally { o.self = null }', '@')]
    [TestCase('Array', 'var a = []; a[0] = a; try { JSON.stringify(a) } finally { a[0] = null }', '@')]
    [TestCase('ThroughReplacer', 'var o = {"a":1}; JSON.stringify(o, function (k, v) { return k === "a" ? o : v; })', '@')]
    procedure Stringify_Circular_ThrowsTypeError(const Script: string);

    [Test]
    procedure Stringify_ToJsonThrows_PropagatesError;

    [Test]
    procedure Stringify_ReplacerFunctionThrows_PropagatesError;

    [Test]
    procedure Stringify_ReplacerArrayElementThrows_PropagatesError;

    [Test]
    procedure Stringify_SpaceConversionThrows_PropagatesError;

    [Test]
    procedure Stringify_SkipsNonEnumerableMembers;

    [Test]
    procedure Stringify_KeepsPropertyOrder;
  end;

implementation

procedure TJsonStringifyTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TJsonStringifyTests.TearDown;
begin
  FEngine.Free;
end;

function TJsonStringifyTests.Evaluate(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

procedure TJsonStringifyTests.Stringify_Primitive_ReturnsJsonText(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_NotSerializable_ReturnsUndefinedOrNull(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_PrimitiveWrapper_UsesPrimitiveValue(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_ToJson_ReplacesValue(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_ReplacerFunction_TransformsValues(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_ReplacerArray_FiltersAndOrdersKeys(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_Space_IndentsOutput(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_Circular_ThrowsTypeError(const Script: string);
begin
  const Guarded = Format('(function () { try { %s; return "no error"; } catch (e) { return (e instanceof TypeError) ? "TypeError" : "other"; } })()', [Script]);

  Assert.AreEqual('TypeError', Evaluate(Guarded));
end;

procedure TJsonStringifyTests.Stringify_ToJsonThrows_PropagatesError;
begin
  const Script = '(function () { try { JSON.stringify({"toJSON": function () { throw "boom"; }}); return "none"; } catch (e) { return e; } })()';

  Assert.AreEqual('boom', Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_ReplacerFunctionThrows_PropagatesError;
begin
  const Script = '(function () { try { JSON.stringify({}, function () { throw "boom"; }); return "none"; } catch (e) { return e; } })()';

  Assert.AreEqual('boom', Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_ReplacerArrayElementThrows_PropagatesError;
begin
  const Script = 'var bad = new String("a"); bad.toString = function () { throw "boom"; }; ' +
                 '(function () { try { JSON.stringify({}, [bad]); return "none"; } catch (e) { return e; } })()';

  Assert.AreEqual('boom', Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_SpaceConversionThrows_PropagatesError;
begin
  const Script = 'var bad = new Number(1); bad.valueOf = function () { throw "boom"; }; ' +
                 '(function () { try { JSON.stringify({}, null, bad); return "none"; } catch (e) { return e; } })()';

  Assert.AreEqual('boom', Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_SkipsNonEnumerableMembers;
begin
  const Script = 'var o = {"a":1}; Object.defineProperty(o, "hidden", {"value": 2, "enumerable": false}); JSON.stringify(o)';

  Assert.AreEqual('{"a":1}', Evaluate(Script));
end;

procedure TJsonStringifyTests.Stringify_KeepsPropertyOrder;
begin
  const Script = 'var o = {}; o.b = 1; o.a = 2; JSON.stringify(o)';

  Assert.AreEqual('{"b":1,"a":2}', Evaluate(Script));
end;

end.
