unit JS4D.Tests.JsonReviver;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TJsonReviverTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('NegativeZero', '1 / JSON.parse("-0")@-Infinity', '@')]
    [TestCase('PaddedNegativeZero', '1 / JSON.parse(" \n-0\t")@-Infinity', '@')]
    [TestCase('NumberArgument', '1 / JSON.parse(-0)@Infinity', '@')]
    [TestCase('Exponent', 'JSON.parse("1.5e2")@150', '@')]
    [TestCase('HugeExponent', 'JSON.parse("1e999")@Infinity', '@')]
    [TestCase('Escapes', 'JSON.parse("\"\\u0041\\/\\t\"").length@3', '@')]
    [TestCase('Literals', 'JSON.parse("[true,false,null]").join("-")@true-false-', '@')]
    [TestCase('LastDuplicateWins', 'JSON.parse("{\"a\":1,\"a\":2}").a@2', '@')]
    procedure Parse_Text_ReturnsValue(const Script, Expected: string);

    [Test]
    [TestCase('ProtoBecomesOwnProperty', 'var o = JSON.parse("{\"__proto__\":[]}"); Object.getPrototypeOf(o) === Object.prototype@true', '@')]
    [TestCase('ProtoIsOwn', 'JSON.parse("{\"__proto__\":1}").hasOwnProperty("__proto__")@true', '@')]
    [TestCase('KeysAreEnumerable', 'Object.keys(JSON.parse("{\"b\":1,\"a\":2}")).join()@b,a', '@')]
    procedure Parse_ProtoKey_CreatesOwnDataProperty(const Script, Expected: string);

    [Test]
    [TestCase('Invalid', '(function () { try { JSON.parse("{a:1}"); return "none"; } catch (e) { return e instanceof SyntaxError; } })()@true', '@')]
    [TestCase('Empty', '(function () { try { JSON.parse(""); return "none"; } catch (e) { return e instanceof SyntaxError; } })()@true', '@')]
    procedure Parse_InvalidText_ThrowsSyntaxError(const Script, Expected: string);

    [Test]
    [TestCase('Doubles', 'JSON.stringify(JSON.parse("{\"a\":1,\"b\":[2,3]}", function (k, v) { return typeof v === "number" ? v * 2 : v; }))@{"a":2,"b":[4,6]}', '@')]
    [TestCase('DeletesObjectMember', 'JSON.stringify(JSON.parse("{\"a\":1,\"b\":2}", function (k, v) { return k === "a" ? undefined : v; }))@{"b":2}', '@')]
    [TestCase('DeletesArrayElement', 'JSON.parse("[1,2,3]", function (k, v) { return k === "1" ? undefined : v; }).hasOwnProperty("1")@false', '@')]
    [TestCase('RootHolder', 'var seen; JSON.parse("1", function (k, v) { seen = typeof this + ":" + k + ":" + this[""]; return v; }); seen@object::1', '@')]
    [TestCase('ChildrenBeforeParent', 'var order = []; JSON.parse("{\"a\":[1],\"b\":2}", function (k, v) { order.push(k); return v; }); order.join()@0,a,b,', '@')]
    [TestCase('ReplacesRoot', 'JSON.parse("[1]", function (k, v) { return k === "" ? "root" : v; })@root', '@')]
    [TestCase('NonFunctionIgnored', 'JSON.parse("[1]", 5).length@1', '@')]
    [TestCase('ReadsDeletedElementThroughPrototype', 'Array.prototype[1] = 9; var seen = []; JSON.parse("[0,1]", function (k, v) { if (k === "0") { delete this[1]; } seen.push(k + "=" + v); return v; }); delete Array.prototype[1]; seen.join()@0=0,1=9,=0,9', '@')]
    procedure Parse_Reviver_TransformsValues(const Script, Expected: string);

    [Test]
    [TestCase('ForwardModification', 'JSON.parse("{\"a\":1,\"b\":2}", function (k, v) { if (k === "a") { this.b = 5; } return v; }).b@5', '@')]
    [TestCase('NonConfigurableDelete', 'JSON.parse("{\"a\":1,\"b\":2}", function (k, v) { if (k === "a") { Object.defineProperty(this, "b", {"configurable": false}); } return k === "b" ? undefined : v; }).b@2', '@')]
    [TestCase('NonConfigurableMember','JSON.parse("[1,2]", function (k, v) { if (k === "0") { Object.defineProperty(this, "1", {"configurable": false}); } return k === "1" ? 9 : v; })[1]@2', '@')]
    procedure Parse_Reviver_RespectsObjectChanges(const Script, Expected: string);

    [Test]
    [TestCase('ProxyForArrayIsWalkedAsArray', 'var seen = false; var p = new Proxy([], {}); p.other = 0; JSON.parse("[null,null]", function (k, v) { if (k === "other") { seen = true; } this[1] = p; return v; }); seen@false', '@')]
    [TestCase('ProxyForObjectIsWalkedAsObject', 'var seen = false; var p = new Proxy({length: 0, other: 0}, {}); JSON.parse("[null,null]", function (k, v) { if (k === "other") { seen = true; } if (this !== p) { this[1] = p; } return v; }); seen@true', '@')]
    [TestCase('LengthGetThrows', '(function () { var bad = new Proxy([], { get: function (t, n) { if (n === "length") { throw "boom"; } } }); try { JSON.parse("[0,0]", function () { this[1] = bad; }); return "none"; } catch (e) { return e; } })()@boom', '@')]
    [TestCase('LengthCoercionThrows', '(function () { var bad = new Proxy([], { get: function (t, n) { return n === "length" ? { valueOf: function () { throw "boom"; } } : undefined; } }); try { JSON.parse("[0,0]", function () { this[1] = bad; }); return "none"; } catch (e) { return e; } })()@boom', '@')]
    procedure Parse_Reviver_WalksProxies(const Script, Expected: string);

    [Test]
    [TestCase('Parse', 'Object.defineProperty(Object.prototype, "", { set: function () { throw "setter called"; }, configurable: true }); var r = JSON.parse("2", function (k, v) { return v; }); delete Object.prototype[""]; r@2', '@')]
    [TestCase('Stringify', 'Object.defineProperty(Object.prototype, "", { set: function () { throw "setter called"; }, configurable: true }); var r = JSON.stringify(2, function (k, v) { return v; }); delete Object.prototype[""]; r@2', '@')]
    procedure Json_RootHolder_IgnoresInheritedSetter(const Script, Expected: string);

    [Test]
    procedure Parse_ReviverThrows_PropagatesError;
  end;

implementation

procedure TJsonReviverTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TJsonReviverTests.TearDown;
begin
  FEngine.Free;
end;

function TJsonReviverTests.Evaluate(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

procedure TJsonReviverTests.Parse_Text_ReturnsValue(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_ProtoKey_CreatesOwnDataProperty(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_InvalidText_ThrowsSyntaxError(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_Reviver_TransformsValues(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_Reviver_RespectsObjectChanges(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_Reviver_WalksProxies(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Json_RootHolder_IgnoresInheritedSetter(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Script));
end;

procedure TJsonReviverTests.Parse_ReviverThrows_PropagatesError;
begin
  const Script = '(function () { try { JSON.parse("[1]", function () { throw "boom"; }); return "none"; } catch (e) { return e; } })()';

  Assert.AreEqual('boom', Evaluate(Script));
end;

end.
