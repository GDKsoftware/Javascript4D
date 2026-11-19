unit JS4D.Tests.BuiltinAttributes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TBuiltinAttributeTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure FunctionLength_DeclaredFunction_CountsFormalParameters;

    [Test]
    procedure FunctionLength_FunctionExpression_CountsFormalParameters;

    [Test]
    procedure FunctionLength_Descriptor_IsOwnReadOnlyNonEnumerable;

    [Test]
    procedure FunctionLength_Assignment_IsIgnored;

    [Test]
    procedure FunctionLength_FunctionConstructor_CountsParametersOfAllArguments;

    [Test]
    procedure FunctionLength_BoundFunction_SubtractsBoundArguments;

    [Test]
    procedure FunctionLength_BoundFunction_NeverNegative;

    [Test]
    procedure FunctionName_DeclaredFunction_IsDeclaredName;

    [Test]
    procedure FunctionName_AnonymousFunctionExpression_IsEmptyString;

    [Test]
    procedure FunctionName_Descriptor_IsOwnReadOnlyNonEnumerable;

    [Test]
    procedure FunctionName_Assignment_IsIgnored;

    [Test]
    procedure NativeName_MethodsAndConstructors_MatchPropertyKey;

    [Test]
    procedure NativeName_Descriptor_IsOwnReadOnlyNonEnumerable;

    [Test]
    procedure NativeLength_ArrayPrototypeMethods_MatchSpecification;

    [Test]
    procedure NativeLength_ObjectAndFunctionMethods_MatchSpecification;

    [Test]
    procedure NativeLength_MathFunctions_MatchSpecification;

    [Test]
    procedure NativeLength_StringAndNumberMethods_MatchSpecification;

    [Test]
    procedure NativeLength_Constructors_MatchSpecification;

    [Test]
    procedure NativeLength_GlobalFunctions_MatchSpecification;

    [Test]
    procedure NativeLength_Descriptor_IsNonEnumerableAndNotWritable;

    [Test]
    procedure PrototypeMethods_Descriptor_AreNonEnumerable;

    [Test]
    procedure ConstructorProperties_Descriptor_AreNonEnumerable;

    [Test]
    procedure MathAndJson_Properties_AreNonEnumerable;

    [Test]
    [TestCase('MathMethod', 'Math.cos')]
    [TestCase('ArrayStatic', 'Array.isArray')]
    [TestCase('PrototypeMethod', 'Array.prototype.join')]
    [TestCase('ObjectStatic', 'Object.keys')]
    procedure BuiltinMethods_NewOnMethod_IsNotAConstructor(const Method: string);

    [Test]
    procedure PrototypeMethods_Descriptor_AreWritableAndConfigurable;
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

const
  OK_DECLARATION = 'var ok = true;';
  CONSTRUCTOR_LIST_DECLARATION = 'var constructors = [Array, Object, Function, String, Number, Boolean, Date, RegExp, Error];';
  CONSTRUCTOR_LOOP_HEAD = 'for (var i = 0; i < constructors.length; i++) {';

procedure TBuiltinAttributeTests.FunctionLength_DeclaredFunction_CountsFormalParameters;
begin
  const Actual = EvaluateNumber('function f(a, b, c) {} f.length');

  Assert.AreEqual(3.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_FunctionExpression_CountsFormalParameters;
begin
  const Actual = EvaluateNumber('(function (a, b) {}).length');

  Assert.AreEqual(2.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_Descriptor_IsOwnReadOnlyNonEnumerable;
begin
  const Script =
    'function f(a) {}' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(f, "length");' + sLineBreak +
    'f.hasOwnProperty("length") && d.value === 1 && !d.writable && !d.enumerable && d.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_Assignment_IsIgnored;
begin
  const Actual = EvaluateNumber('function f(a, b) {} f.length = 9; f.length');

  Assert.AreEqual(2.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_FunctionConstructor_CountsParametersOfAllArguments;
begin
  const Actual = EvaluateNumber('new Function("a,b,c", "d,e", "").length');

  Assert.AreEqual(5.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_BoundFunction_SubtractsBoundArguments;
begin
  const Actual = EvaluateNumber('(function (a, b, c) {}).bind(null, 1, 2).length');

  Assert.AreEqual(1.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionLength_BoundFunction_NeverNegative;
begin
  const Actual = EvaluateNumber('(function (a) {}).bind(null, 1, 2, 3).length');

  Assert.AreEqual(0.0, Actual);
end;

procedure TBuiltinAttributeTests.FunctionName_DeclaredFunction_IsDeclaredName;
begin
  const Actual = EvaluateBoolean('function foo() {} foo.name === "foo"');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.FunctionName_AnonymousFunctionExpression_IsEmptyString;
begin
  const Actual = EvaluateBoolean('(function () {}).hasOwnProperty("name") && (function () {}).name === ""');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.FunctionName_Descriptor_IsOwnReadOnlyNonEnumerable;
begin
  const Script =
    'function foo() {}' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(foo, "name");' + sLineBreak +
    'foo.hasOwnProperty("name") && d.value === "foo" && !d.writable && !d.enumerable && d.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.FunctionName_Assignment_IsIgnored;
begin
  const Actual = EvaluateBoolean('function foo() {} foo.name = "bar"; foo.name === "foo"');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeName_MethodsAndConstructors_MatchPropertyKey;
begin
  const Script =
    'Array.prototype.join.name === "join" && Array.name === "Array" && Math.max.name === "max" &&' +
    ' parseInt.name === "parseInt" && TypeError.name === "TypeError" && Date.UTC.name === "UTC" &&' +
    ' String.prototype.split.name === "split" && Object.defineProperty.name === "defineProperty"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeName_Descriptor_IsOwnReadOnlyNonEnumerable;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype.join, "name");' + sLineBreak +
    'd.value === "join" && !d.writable && !d.enumerable && d.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_ArrayPrototypeMethods_MatchSpecification;
begin
  const Script =
    'var expected = { concat: 1, join: 1, pop: 0, push: 1, reverse: 0, shift: 0, slice: 2, sort: 1,' +
    ' splice: 2, unshift: 1, indexOf: 1, lastIndexOf: 1, every: 1, some: 1, forEach: 1, map: 1,' +
    ' filter: 1, reduce: 1, reduceRight: 1, toString: 0, toLocaleString: 0 };' + sLineBreak +
    OK_DECLARATION + sLineBreak +
    'for (var name in expected) { if (Array.prototype[name].length !== expected[name]) ok = false; }' + sLineBreak +
    'ok';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_ObjectAndFunctionMethods_MatchSpecification;
begin
  const Script =
    'Object.defineProperty.length === 3 && Object.defineProperties.length === 2 &&' +
    ' Object.create.length === 2 && Object.keys.length === 1 &&' +
    ' Object.getOwnPropertyDescriptor.length === 2 && Object.prototype.hasOwnProperty.length === 1 &&' +
    ' Object.prototype.toString.length === 0 && Function.prototype.call.length === 1 &&' +
    ' Function.prototype.apply.length === 2 && Function.prototype.bind.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_MathFunctions_MatchSpecification;
begin
  const Script =
    'Math.abs.length === 1 && Math.atan2.length === 2 && Math.max.length === 2 &&' +
    ' Math.min.length === 2 && Math.pow.length === 2 && Math.random.length === 0 && Math.floor.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_StringAndNumberMethods_MatchSpecification;
begin
  const Script =
    'String.prototype.charAt.length === 1 && String.prototype.replace.length === 2 &&' +
    ' String.prototype.split.length === 2 && String.prototype.substring.length === 2 &&' +
    ' String.prototype.toUpperCase.length === 0 && String.fromCharCode.length === 1 &&' +
    ' Number.prototype.toString.length === 1 && Number.prototype.toFixed.length === 1 &&' +
    ' Number.prototype.valueOf.length === 0 && Boolean.prototype.toString.length === 0';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_Constructors_MatchSpecification;
begin
  const Script =
    'Object.length === 1 && Function.length === 1 && Array.length === 1 && String.length === 1 &&' +
    ' Number.length === 1 && Boolean.length === 1 && Date.length === 7 && RegExp.length === 2 &&' +
    ' Error.length === 1 && TypeError.length === 1 && Date.UTC.length === 7 && Date.parse.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_GlobalFunctions_MatchSpecification;
begin
  const Script =
    'parseInt.length === 2 && parseFloat.length === 1 && isNaN.length === 1 && isFinite.length === 1 &&' +
    ' eval.length === 1 && decodeURI.length === 1 && encodeURIComponent.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.NativeLength_Descriptor_IsNonEnumerableAndNotWritable;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype.join, "length");' + sLineBreak +
    'd.value === 1 && !d.writable && !d.enumerable && d.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.PrototypeMethods_Descriptor_AreNonEnumerable;
begin
  const Script =
    CONSTRUCTOR_LIST_DECLARATION + sLineBreak +
    OK_DECLARATION + sLineBreak +
    CONSTRUCTOR_LOOP_HEAD + sLineBreak +
    '  var proto = constructors[i].prototype;' + sLineBreak +
    '  for (var key in proto) { ok = false; }' + sLineBreak +
    '}' + sLineBreak +
    'ok';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.ConstructorProperties_Descriptor_AreNonEnumerable;
begin
  const Script =
    CONSTRUCTOR_LIST_DECLARATION + sLineBreak +
    OK_DECLARATION + sLineBreak +
    CONSTRUCTOR_LOOP_HEAD + sLineBreak +
    '  for (var key in constructors[i]) { ok = false; }' + sLineBreak +
    '}' + sLineBreak +
    'ok';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.MathAndJson_Properties_AreNonEnumerable;
begin
  const Script =
    OK_DECLARATION + sLineBreak +
    'for (var key in Math) { ok = false; }' + sLineBreak +
    'for (var key in JSON) { ok = false; }' + sLineBreak +
    'ok';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.PrototypeMethods_Descriptor_AreWritableAndConfigurable;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype, "join");' + sLineBreak +
    'd.writable && d.configurable && !d.enumerable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinAttributeTests.BuiltinMethods_NewOnMethod_IsNotAConstructor(const Method: string);
begin
  const Script = Format('var caught = ""; try { new %s(); } catch (e) { caught = e.name; } caught', [Method]);

  const Actual = EvaluateText(Script);

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

end.
