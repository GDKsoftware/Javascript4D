unit JS4D.Tests.BuiltinAttributes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TBuiltinAttributeTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;
    function EvaluateNumber(const Script: string): Double;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FunctionLength_DeclaredFunction_CountsFormalParameters;

    [Test]
    procedure FunctionLength_FunctionExpression_CountsFormalParameters;

    [Test]
    procedure FunctionLength_IsOwnReadOnlyNonEnumerableProperty;

    [Test]
    procedure FunctionLength_AssignmentIsIgnored;

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
    procedure FunctionName_IsOwnReadOnlyNonEnumerableProperty;

    [Test]
    procedure FunctionName_AssignmentIsIgnored;

    [Test]
    procedure NativeName_MethodsAndConstructors_MatchPropertyKey;

    [Test]
    procedure NativeName_IsOwnReadOnlyNonEnumerableProperty;

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
    procedure NativeLength_IsNonEnumerableAndNotWritable;

    [Test]
    procedure PrototypeMethods_AreNonEnumerable;

    [Test]
    procedure ConstructorProperties_AreNonEnumerable;

    [Test]
    procedure MathAndJson_PropertiesAreNonEnumerable;

    [Test]
    procedure PrototypeMethods_AreStillWritableAndConfigurable;
  end;

implementation

procedure TBuiltinAttributeTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TBuiltinAttributeTests.TearDown;
begin
  FEngine.Free;
end;

function TBuiltinAttributeTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

function TBuiltinAttributeTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).AsNumber;
end;

procedure TBuiltinAttributeTests.FunctionLength_DeclaredFunction_CountsFormalParameters;
begin
  Assert.AreEqual(3.0, EvaluateNumber('function f(a, b, c) {} f.length'));
end;

procedure TBuiltinAttributeTests.FunctionLength_FunctionExpression_CountsFormalParameters;
begin
  Assert.AreEqual(2.0, EvaluateNumber('(function (a, b) {}).length'));
end;

procedure TBuiltinAttributeTests.FunctionLength_IsOwnReadOnlyNonEnumerableProperty;
begin
  const Script =
    'function f(a) {}' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(f, "length");' + sLineBreak +
    'f.hasOwnProperty("length") && d.value === 1 && !d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.FunctionLength_AssignmentIsIgnored;
begin
  Assert.AreEqual(2.0, EvaluateNumber('function f(a, b) {} f.length = 9; f.length'));
end;

procedure TBuiltinAttributeTests.FunctionLength_FunctionConstructor_CountsParametersOfAllArguments;
begin
  Assert.AreEqual(5.0, EvaluateNumber('new Function("a,b,c", "d,e", "").length'));
end;

procedure TBuiltinAttributeTests.FunctionLength_BoundFunction_SubtractsBoundArguments;
begin
  Assert.AreEqual(1.0, EvaluateNumber('(function (a, b, c) {}).bind(null, 1, 2).length'));
end;

procedure TBuiltinAttributeTests.FunctionLength_BoundFunction_NeverNegative;
begin
  Assert.AreEqual(0.0, EvaluateNumber('(function (a) {}).bind(null, 1, 2, 3).length'));
end;

procedure TBuiltinAttributeTests.FunctionName_DeclaredFunction_IsDeclaredName;
begin
  Assert.IsTrue(EvaluateBoolean('function foo() {} foo.name === "foo"'));
end;

procedure TBuiltinAttributeTests.FunctionName_AnonymousFunctionExpression_IsEmptyString;
begin
  Assert.IsTrue(EvaluateBoolean('(function () {}).hasOwnProperty("name") && (function () {}).name === ""'));
end;

procedure TBuiltinAttributeTests.FunctionName_IsOwnReadOnlyNonEnumerableProperty;
begin
  const Script =
    'function foo() {}' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(foo, "name");' + sLineBreak +
    'foo.hasOwnProperty("name") && d.value === "foo" && !d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.FunctionName_AssignmentIsIgnored;
begin
  Assert.IsTrue(EvaluateBoolean('function foo() {} foo.name = "bar"; foo.name === "foo"'));
end;

procedure TBuiltinAttributeTests.NativeName_MethodsAndConstructors_MatchPropertyKey;
begin
  const Script =
    'Array.prototype.join.name === "join" && Array.name === "Array" && Math.max.name === "max" &&' +
    ' parseInt.name === "parseInt" && TypeError.name === "TypeError" && Date.UTC.name === "UTC" &&' +
    ' String.prototype.split.name === "split" && Object.defineProperty.name === "defineProperty"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeName_IsOwnReadOnlyNonEnumerableProperty;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype.join, "name");' + sLineBreak +
    'd.value === "join" && !d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_ArrayPrototypeMethods_MatchSpecification;
begin
  const Script =
    'var expected = { concat: 1, join: 1, pop: 0, push: 1, reverse: 0, shift: 0, slice: 2, sort: 1,' +
    ' splice: 2, unshift: 1, indexOf: 1, lastIndexOf: 1, every: 1, some: 1, forEach: 1, map: 1,' +
    ' filter: 1, reduce: 1, reduceRight: 1, toString: 0, toLocaleString: 0 };' + sLineBreak +
    'var ok = true;' + sLineBreak +
    'for (var name in expected) { if (Array.prototype[name].length !== expected[name]) ok = false; }' + sLineBreak +
    'ok';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_ObjectAndFunctionMethods_MatchSpecification;
begin
  const Script =
    'Object.defineProperty.length === 3 && Object.defineProperties.length === 2 &&' +
    ' Object.create.length === 2 && Object.keys.length === 1 &&' +
    ' Object.getOwnPropertyDescriptor.length === 2 && Object.prototype.hasOwnProperty.length === 1 &&' +
    ' Object.prototype.toString.length === 0 && Function.prototype.call.length === 1 &&' +
    ' Function.prototype.apply.length === 2 && Function.prototype.bind.length === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_MathFunctions_MatchSpecification;
begin
  const Script =
    'Math.abs.length === 1 && Math.atan2.length === 2 && Math.max.length === 2 &&' +
    ' Math.min.length === 2 && Math.pow.length === 2 && Math.random.length === 0 && Math.floor.length === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_StringAndNumberMethods_MatchSpecification;
begin
  const Script =
    'String.prototype.charAt.length === 1 && String.prototype.replace.length === 2 &&' +
    ' String.prototype.split.length === 2 && String.prototype.substring.length === 2 &&' +
    ' String.prototype.toUpperCase.length === 0 && String.fromCharCode.length === 1 &&' +
    ' Number.prototype.toString.length === 1 && Number.prototype.toFixed.length === 1 &&' +
    ' Number.prototype.valueOf.length === 0 && Boolean.prototype.toString.length === 0';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_Constructors_MatchSpecification;
begin
  const Script =
    'Object.length === 1 && Function.length === 1 && Array.length === 1 && String.length === 1 &&' +
    ' Number.length === 1 && Boolean.length === 1 && Date.length === 7 && RegExp.length === 2 &&' +
    ' Error.length === 1 && TypeError.length === 1 && Date.UTC.length === 7 && Date.parse.length === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_GlobalFunctions_MatchSpecification;
begin
  const Script =
    'parseInt.length === 2 && parseFloat.length === 1 && isNaN.length === 1 && isFinite.length === 1 &&' +
    ' eval.length === 1 && decodeURI.length === 1 && encodeURIComponent.length === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.NativeLength_IsNonEnumerableAndNotWritable;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype.join, "length");' + sLineBreak +
    'd.value === 1 && !d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.PrototypeMethods_AreNonEnumerable;
begin
  const Script =
    'var constructors = [Array, Object, Function, String, Number, Boolean, Date, RegExp, Error];' + sLineBreak +
    'var ok = true;' + sLineBreak +
    'for (var i = 0; i < constructors.length; i++) {' + sLineBreak +
    '  var proto = constructors[i].prototype;' + sLineBreak +
    '  for (var key in proto) { ok = false; }' + sLineBreak +
    '}' + sLineBreak +
    'ok';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.ConstructorProperties_AreNonEnumerable;
begin
  const Script =
    'var constructors = [Array, Object, Function, String, Number, Boolean, Date, RegExp, Error];' + sLineBreak +
    'var ok = true;' + sLineBreak +
    'for (var i = 0; i < constructors.length; i++) {' + sLineBreak +
    '  for (var key in constructors[i]) { ok = false; }' + sLineBreak +
    '}' + sLineBreak +
    'ok';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.MathAndJson_PropertiesAreNonEnumerable;
begin
  const Script =
    'var ok = true;' + sLineBreak +
    'for (var key in Math) { ok = false; }' + sLineBreak +
    'for (var key in JSON) { ok = false; }' + sLineBreak +
    'ok';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TBuiltinAttributeTests.PrototypeMethods_AreStillWritableAndConfigurable;
begin
  const Script =
    'var d = Object.getOwnPropertyDescriptor(Array.prototype, "join");' + sLineBreak +
    'd.writable && d.configurable && !d.enumerable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
