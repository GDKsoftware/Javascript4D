unit JS4D.Tests.ObjectLiteralExtensions;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TObjectLiteralExtensionTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Shorthand', 'var a = 1; var o = { a }; o.a|1', '|')]
    [TestCase('ShorthandMixed', 'var a = 1, b = 2; var o = { a, c: 3, b }; o.a + o.b + o.c|6', '|')]
    [TestCase('ShorthandKeywordLikeName', 'var get = 4, set = 5; var o = { get, set }; o.get + o.set|9', '|')]
    [TestCase('ComputedKey', 'var k = "x"; var o = { [k]: 7 }; o.x|7', '|')]
    [TestCase('ComputedKeyExpression', 'var o = { ["a" + "b"]: 1 }; o.ab|1', '|')]
    [TestCase('ComputedKeyNumber', 'var o = { [1 + 1]: "two" }; o[2]|two', '|')]
    [TestCase('ComputedKeyToString', 'var o = { [{ toString: function() { return "q"; } }]: 3 }; o.q|3', '|')]
    [TestCase('ComputedGetter', 'var o = { get ["g" + 1]() { return 8; } }; o.g1|8', '|')]
    [TestCase('ComputedSetter', 'var r; var o = { set ["s"](v) { r = v; } }; o.s = 9; r|9', '|')]
    [TestCase('ComputedKeyOrder', 'var l = []; var o = { [(l.push("k"), "a")]: l.push("v") }; l.join()|k,v', '|')]
    [TestCase('ComputedKeyOverwrites', 'var o = { a: 1, ["a"]: 2 }; o.a|2', '|')]
    [TestCase('ConciseMethod', 'var o = { m() { return 5; } }; o.m()|5', '|')]
    [TestCase('ConciseMethodThis', 'var o = { v: 3, m() { return this.v; } }; o.m()|3', '|')]
    [TestCase('ConciseMethodParams', 'var o = { add(a, b) { return a + b; } }; o.add(1, 2)|3', '|')]
    [TestCase('ConciseMethodComputed', 'var o = { ["m" + 1]() { return 1; } }; o.m1()|1', '|')]
    [TestCase('ConciseMethodNumericName', 'var o = { 1() { return "one"; } }; o[1]()|one', '|')]
    [TestCase('ConciseMethodStringName', 'var o = { "a b"() { return 2; } }; o["a b"]()|2', '|')]
    [TestCase('MethodNamedGet', 'var o = { get() { return 1; } }; o.get()|1', '|')]
    [TestCase('MethodNamedSet', 'var o = { set() { return 2; } }; o.set()|2', '|')]
    [TestCase('MethodNameIsKey', 'var o = { m() {} }; o.m.name|m', '|')]
    [TestCase('MethodNameOfComputedKey', 'var o = { ["a" + "b"]() {} }; o.ab.name|ab', '|')]
    [TestCase('MethodLength', 'var o = { m(a, b) {} }; o.m.length|2', '|')]
    [TestCase('MethodIsEnumerable', 'var o = { m() {} }; Object.keys(o).join()|m', '|')]
    [TestCase('MethodHasNoPrototype', 'var o = { m() {} }; o.m.hasOwnProperty("prototype")|false', '|')]
    [TestCase('GetterName', 'var o = { get x() { return 1; } }; Object.getOwnPropertyDescriptor(o, "x").get.name|get x', '|')]
    [TestCase('SetterName', 'var o = { set x(v) {} }; Object.getOwnPropertyDescriptor(o, "x").set.name|set x', '|')]
    [TestCase('ComputedGetterName', 'var o = { get ["x" + 1]() { return 1; } }; Object.getOwnPropertyDescriptor(o, "x1").get.name|get x1', '|')]
    [TestCase('ProtoPlainSetsPrototype', 'var p = { z: 1 }; var o = { __proto__: p }; o.z + "," + o.hasOwnProperty("__proto__")|1,false', '|')]
    [TestCase('ProtoStringKey', 'var p = { z: 1 }; var o = { "__proto__": p }; Object.getPrototypeOf(o) === p|true', '|')]
    [TestCase('ProtoNullValue', 'var o = { __proto__: null }; Object.getPrototypeOf(o)|null', '|')]
    [TestCase('ProtoNonObjectIgnored', 'var o = { __proto__: 1 }; Object.getPrototypeOf(o) === Object.prototype|true', '|')]
    [TestCase('ProtoShorthandIsOwn', 'var __proto__ = 5; var o = { __proto__ }; o.hasOwnProperty("__proto__")|true', '|')]
    [TestCase('ProtoComputedIsOwn', 'var o = { ["__proto__"]: 5 }; o.hasOwnProperty("__proto__")|true', '|')]
    [TestCase('ProtoMethodIsOwn', 'var o = { __proto__() {} }; o.hasOwnProperty("__proto__")|true', '|')]
    [TestCase('ProtoDuplicateShorthandAllowed', 'var __proto__ = 1; var o = { __proto__: null, __proto__ }; o.hasOwnProperty("__proto__")|true', '|')]
    procedure Evaluate_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Variable', 'var f = function() {}; f.name|f', '|')]
    [TestCase('Let', 'let f = function() {}; f.name|f', '|')]
    [TestCase('Const', 'const f = () => 1; f.name|f', '|')]
    [TestCase('Assignment', 'var f; f = function() {}; f.name|f', '|')]
    [TestCase('ArrowAssignment', 'var f; f = () => 1; f.name|f', '|')]
    [TestCase('ObjectProperty', 'var o = { p: function() {} }; o.p.name|p', '|')]
    [TestCase('ObjectArrowProperty', 'var o = { p: () => 1 }; o.p.name|p', '|')]
    [TestCase('ObjectComputedProperty', 'var o = { ["a" + 1]: function() {} }; o.a1.name|a1', '|')]
    [TestCase('ObjectNumericProperty', 'var o = { 1: function() {} }; o[1].name|1', '|')]
    [TestCase('NamedExpressionKeepsName', 'var f = function g() {}; f.name|g', '|')]
    [TestCase('ParenthesizedExpression', 'var f = (function() {}); f.name|f', '|')]
    [TestCase('NotInferredThroughComma', 'var f = (0, function() {}); f.name|', '|')]
    [TestCase('NotInferredForMemberTarget', 'var o = {}; o.p = function() {}; o.p.name|', '|')]
    [TestCase('ProtoValueIsNotNamed', 'var o = { __proto__: function() {} }; Object.getPrototypeOf(o).name|', '|')]
    [TestCase('NotInferredForParenthesizedTarget', 'var f; (f) = function() {}; f.name|', '|')]
    [TestCase('NameIsNotWritable', 'var f = function() {}; f.name = "x"; f.name|f', '|')]
    procedure FunctionName_Result(const Source: string; const Expected: string);

    [Test]
    procedure Method_CannotBeConstructed;

    [Test]
    procedure Getter_CannotBeConstructed;

    [Test]
    procedure Method_HasNoOwnArgumentsOrCaller;

    [Test]
    procedure Method_InStrictCode_IsStrict;

    [Test]
    [TestCase('DuplicateProto', 'var o = { __proto__: null, __proto__: null };')]
    [TestCase('DuplicateProtoString', 'var o = { __proto__: null, "__proto__": null };')]
    [TestCase('ShorthandReservedWord', 'var o = { if };')]
    [TestCase('ShorthandLiteral', 'var o = { 1 };')]
    [TestCase('ShorthandString', 'var o = { "a" };')]
    [TestCase('ShorthandStrictReserved', '"use strict"; var o = { static };')]
    [TestCase('MethodDuplicateParameters', '"use strict"; var o = { m(a, a) {} };')]
    [TestCase('SloppyMethodDuplicateParameters', 'var o = { m(a, a) {} };')]
    [TestCase('SuperCallInMethod', 'var o = { m() { super(); } };')]
    [TestCase('ComputedWithoutKeyExpression', 'var o = { [] : 1 };')]
    [TestCase('ComputedWithoutValue', 'var o = { [a] };')]
    procedure Parse_RaisesSyntaxError(const Source: string);

    [Test]
    procedure ComputedKey_ThrowingToString_PropagatesError;

    [Test]
    procedure ComputedKey_UnresolvableReference_RaisesReferenceError;
  end;

implementation

procedure TObjectLiteralExtensionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TObjectLiteralExtensionTests.TearDown;
begin
  FEngine.Free;
end;

function TObjectLiteralExtensionTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [QuotesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TObjectLiteralExtensionTests.Evaluate_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TObjectLiteralExtensionTests.FunctionName_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TObjectLiteralExtensionTests.Method_CannotBeConstructed;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('var o = { m() {} }; new o.m();'));
end;

procedure TObjectLiteralExtensionTests.Getter_CannotBeConstructed;
begin
  const Script = 'var o = { get x() { return 1; } }; new (Object.getOwnPropertyDescriptor(o, "x").get)();';

  Assert.AreEqual('TypeError', ErrorNameOf(Script));
end;

procedure TObjectLiteralExtensionTests.Method_HasNoOwnArgumentsOrCaller;
begin
  const Script = 'var o = { m() {} }; o.m.hasOwnProperty("arguments") + "," + o.m.hasOwnProperty("caller")';

  Assert.AreEqual('false,false', FEngine.Evaluate(Script).AsString);
end;

procedure TObjectLiteralExtensionTests.Method_InStrictCode_IsStrict;
begin
  const Script = '"use strict"; var o = { m() { return this; } }; var f = o.m; f() === undefined';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TObjectLiteralExtensionTests.Parse_RaisesSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TObjectLiteralExtensionTests.ComputedKey_ThrowingToString_PropagatesError;
begin
  const Script = 'var k = { toString: function() { throw new RangeError("x"); } }; var o = { [k]: 1 };';

  Assert.AreEqual('RangeError', ErrorNameOf(Script));
end;

procedure TObjectLiteralExtensionTests.ComputedKey_UnresolvableReference_RaisesReferenceError;
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf('var o = { [notDefinedAnywhere]: 1 };'));
end;

end.
