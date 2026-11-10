unit JS4D.Tests.Es2015Library;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TEs2015LibraryTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Cbrt', 'Math.cbrt(8)#2', '#')]
    [TestCase('CbrtNegative', 'Math.cbrt(-27)#-3', '#')]
    [TestCase('CbrtNegativeZero', '1 / Math.cbrt(-0)#-Infinity', '#')]
    [TestCase('CbrtInfinity', 'Math.cbrt(-Infinity)#-Infinity', '#')]
    [TestCase('Log2', 'Math.log2(8)#3', '#')]
    [TestCase('Log2OfZero', 'Math.log2(0)#-Infinity', '#')]
    [TestCase('Log2Negative', 'Math.log2(-1)#NaN', '#')]
    [TestCase('Log10', 'Math.log10(1000)#3', '#')]
    [TestCase('Log10OfOne', '1 / Math.log10(1)#Infinity', '#')]
    [TestCase('Log1p', 'Math.log1p(0)#0', '#')]
    [TestCase('Log1pNegativeZero', '1 / Math.log1p(-0)#-Infinity', '#')]
    [TestCase('Log1pMinusOne', 'Math.log1p(-1)#-Infinity', '#')]
    [TestCase('Log1pBelowMinusOne', 'Math.log1p(-2)#NaN', '#')]
    [TestCase('Expm1', 'Math.expm1(0)#0', '#')]
    [TestCase('Expm1NegativeZero', '1 / Math.expm1(-0)#-Infinity', '#')]
    [TestCase('Expm1NegativeInfinity', 'Math.expm1(-Infinity)#-1', '#')]
    [TestCase('Expm1Infinity', 'Math.expm1(Infinity)#Infinity', '#')]
    [TestCase('Sinh', 'Math.sinh(0)#0', '#')]
    [TestCase('SinhNegativeZero', '1 / Math.sinh(-0)#-Infinity', '#')]
    [TestCase('SinhNegativeInfinity', 'Math.sinh(-Infinity)#-Infinity', '#')]
    [TestCase('Cosh', 'Math.cosh(0)#1', '#')]
    [TestCase('CoshNegativeInfinity', 'Math.cosh(-Infinity)#Infinity', '#')]
    [TestCase('Tanh', 'Math.tanh(Infinity)#1', '#')]
    [TestCase('TanhNegativeInfinity', 'Math.tanh(-Infinity)#-1', '#')]
    [TestCase('TanhNegativeZero', '1 / Math.tanh(-0)#-Infinity', '#')]
    [TestCase('Asinh', 'Math.asinh(0)#0', '#')]
    [TestCase('AsinhNegativeZero', '1 / Math.asinh(-0)#-Infinity', '#')]
    [TestCase('AsinhNegativeInfinity', 'Math.asinh(-Infinity)#-Infinity', '#')]
    [TestCase('Acosh', 'Math.acosh(1)#0', '#')]
    [TestCase('AcoshBelowOne', 'Math.acosh(0.5)#NaN', '#')]
    [TestCase('AcoshInfinity', 'Math.acosh(Infinity)#Infinity', '#')]
    [TestCase('Atanh', 'Math.atanh(0)#0', '#')]
    [TestCase('AtanhNegativeZero', '1 / Math.atanh(-0)#-Infinity', '#')]
    [TestCase('AtanhOne', 'Math.atanh(1)#Infinity', '#')]
    [TestCase('AtanhNegativeOne', 'Math.atanh(-1)#-Infinity', '#')]
    [TestCase('AtanhOutOfRange', 'Math.atanh(1.5)#NaN', '#')]
    [TestCase('HypotNoArguments', 'Math.hypot()#0', '#')]
    [TestCase('HypotPythagoras', 'Math.hypot(3, 4)#5', '#')]
    [TestCase('HypotInfinityBeatsNaN', 'Math.hypot(NaN, Infinity)#Infinity', '#')]
    [TestCase('HypotNaN', 'Math.hypot(NaN, 1)#NaN', '#')]
    [TestCase('HypotNegativeZeros', '1 / Math.hypot(-0, -0)#Infinity', '#')]
    [TestCase('HypotAvoidsOverflow', 'Math.hypot(3e200, 4e200) > 4.99e200 && Math.hypot(3e200, 4e200) < 5.01e200#true', '#')]
    [TestCase('HypotCoercesAllArguments', 'Math.hypot(Infinity, {valueOf: function () { return 2; }})#Infinity', '#')]
    [TestCase('Fround', 'Math.fround(5.5)#5.5', '#')]
    [TestCase('FroundLosesPrecision', 'Math.fround(5.05)#5.050000190734863', '#')]
    [TestCase('FroundOverflow', 'Math.fround(3.5e38)#Infinity', '#')]
    [TestCase('FroundNegativeZero', '1 / Math.fround(-0)#-Infinity', '#')]
    [TestCase('FroundUnderflow', 'Math.fround(1e-50)#0', '#')]
    [TestCase('FroundNaN', 'Math.fround(NaN)#NaN', '#')]
    [TestCase('FroundTieRoundsToEven', 'Math.fround(1 + 5 / 16777216) === 1 + 4 / 16777216#true', '#')]
    [TestCase('FroundTieRoundsDownToEvenFirst', 'Math.fround(1 + 1 / 16777216) === 1#true', '#')]
    [TestCase('FroundOddTieRoundsUp', 'Math.fround(1 + 3 / 16777216) === 1 + 4 / 16777216#true', '#')]
    [TestCase('FroundNegativeTie', 'Math.fround(-1 - 5 / 16777216) === -1 - 4 / 16777216#true', '#')]
    [TestCase('FroundSubnormal', 'Math.fround(1e-45) * Math.pow(2, 149)#1', '#')]
    [TestCase('FroundSubnormalNegativeUnderflow', '1 / Math.fround(-1e-50)#-Infinity', '#')]
    [TestCase('Imul', 'Math.imul(2, 4)#8', '#')]
    [TestCase('ImulWrapsAround', 'Math.imul(0xffffffff, 5)#-5', '#')]
    [TestCase('ImulOverflow', 'Math.imul(0x7fffffff, 0x7fffffff)#1', '#')]
    [TestCase('ImulMissingArguments', 'Math.imul(3)#0', '#')]
    [TestCase('Clz32', 'Math.clz32(1)#31', '#')]
    [TestCase('Clz32OfZero', 'Math.clz32(0)#32', '#')]
    [TestCase('Clz32OfNegative', 'Math.clz32(-1)#0', '#')]
    [TestCase('Clz32WrapsToUint32', 'Math.clz32(4294967296)#32', '#')]
    [TestCase('Clz32OfNaN', 'Math.clz32(NaN)#32', '#')]
    procedure MathFunction_ES2015_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Cbrt', 'Math.cbrt.length#1', '#')]
    [TestCase('Hypot', 'Math.hypot.length#2', '#')]
    [TestCase('Imul', 'Math.imul.length#2', '#')]
    [TestCase('Name', 'Math.clz32.name#clz32', '#')]
    [TestCase('NotEnumerable', 'Object.keys(Math).length#0', '#')]
    procedure MathFunction_ES2015_HasBuiltinAttributes(const Expression, Expected: string);

    [Test]
    [TestCase('IsInteger', 'Number.isInteger(5)#true', '#')]
    [TestCase('IsIntegerFraction', 'Number.isInteger(5.5)#false', '#')]
    [TestCase('IsIntegerInfinity', 'Number.isInteger(Infinity)#false', '#')]
    [TestCase('IsIntegerNoCoercion', 'Number.isInteger("5")#false', '#')]
    [TestCase('IsIntegerBeyondInt64', 'Number.isInteger(1e300)#true', '#')]
    [TestCase('IsSafeInteger', 'Number.isSafeInteger(9007199254740991)#true', '#')]
    [TestCase('IsSafeIntegerTooLarge', 'Number.isSafeInteger(9007199254740992)#false', '#')]
    [TestCase('IsSafeIntegerFraction', 'Number.isSafeInteger(1.5)#false', '#')]
    [TestCase('IsFinite', 'Number.isFinite(1)#true', '#')]
    [TestCase('IsFiniteNoCoercion', 'Number.isFinite("1")#false', '#')]
    [TestCase('IsFiniteInfinity', 'Number.isFinite(-Infinity)#false', '#')]
    [TestCase('IsNaN', 'Number.isNaN(NaN)#true', '#')]
    [TestCase('IsNaNNoCoercion', 'Number.isNaN("abc")#false', '#')]
    [TestCase('IsNaNNoArguments', 'Number.isNaN()#false', '#')]
    [TestCase('Epsilon', 'Number.EPSILON#2.220446049250313e-16', '#')]
    [TestCase('MaxSafeInteger', 'Number.MAX_SAFE_INTEGER#9007199254740991', '#')]
    [TestCase('MinSafeInteger', 'Number.MIN_SAFE_INTEGER#-9007199254740991', '#')]
    [TestCase('ParseFloatIsGlobalFunction', 'Number.parseFloat === parseFloat#true', '#')]
    [TestCase('ParseIntIsGlobalFunction', 'Number.parseInt === parseInt#true', '#')]
    [TestCase('ConstantIsReadOnly', '(function () { Number.EPSILON = 1; return Number.EPSILON < 1; })()#true', '#')]
    [TestCase('IsIntegerLength', 'Number.isInteger.length#1', '#')]
    [TestCase('NotEnumerable', 'Object.keys(Number).length#0', '#')]
    procedure NumberStatic_ES2015_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Equal', 'Object.is(1, 1)#true', '#')]
    [TestCase('NaNIsNaN', 'Object.is(NaN, NaN)#true', '#')]
    [TestCase('ZerosDiffer', 'Object.is(0, -0)#false', '#')]
    [TestCase('StringsAndNumbersDiffer', 'Object.is("1", 1)#false', '#')]
    [TestCase('MissingArguments', 'Object.is()#true', '#')]
    [TestCase('SameObject', '(function () { var o = {}; return Object.is(o, o); })()#true', '#')]
    [TestCase('DifferentObjects', 'Object.is({}, {})#false', '#')]
    procedure ObjectIs_Values_UsesSameValue(const Expression, Expected: string);

    [Test]
    [TestCase('DataProperty', 'JSON.stringify(Object.getOwnPropertyDescriptors({a: 1}).a)#{"value":1,"writable":true,"enumerable":true,"configurable":true}', '#')]
    [TestCase('IncludesNonEnumerable', 'Object.keys(Object.getOwnPropertyDescriptors(Object.defineProperty({}, "h", {value: 1})))[0]#h', '#')]
    [TestCase('IgnoresInherited', 'Object.keys(Object.getOwnPropertyDescriptors(Object.create({inherited: 1}))).length#0', '#')]
    [TestCase('Accessor', 'typeof Object.getOwnPropertyDescriptors({get a() { return 1; }}).a.get#function', '#')]
    [TestCase('PrimitiveIsCoerced', 'Object.getOwnPropertyDescriptors("ab").length.value#2', '#')]
    [TestCase('Length', 'Object.getOwnPropertyDescriptors.length#1', '#')]
    procedure ObjectGetOwnPropertyDescriptors_Source_ReturnsDescriptors(const Expression, Expected: string);

    [Test]
    procedure ObjectGetOwnPropertyDescriptors_Undefined_RaisesTypeError;

    [Test]
    [TestCase('IsGlobalObject', 'globalThis === this#true', '#')]
    [TestCase('ExposesGlobalVariable', '(function () { var scoped = 1; return typeof globalThis.Math; })()#object', '#')]
    [TestCase('NotEnumerable', '(function () { for (var key in this) { if (key === "globalThis") { return "enumerable"; } } return "hidden"; })()#hidden', '#')]
    [TestCase('IsWritable', '(function () { globalThis = 1; var result = globalThis; return result; })()#1', '#')]
    procedure GlobalThis_Lookup_ReferencesGlobalObject(const Expression, Expected: string);
  end;

implementation

procedure TEs2015LibraryTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TEs2015LibraryTests.TearDown;
begin
  FEngine.Free;
end;

function TEs2015LibraryTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TEs2015LibraryTests.MathFunction_ES2015_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TEs2015LibraryTests.MathFunction_ES2015_HasBuiltinAttributes(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TEs2015LibraryTests.NumberStatic_ES2015_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TEs2015LibraryTests.ObjectIs_Values_UsesSameValue(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TEs2015LibraryTests.ObjectGetOwnPropertyDescriptors_Source_ReturnsDescriptors(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TEs2015LibraryTests.ObjectGetOwnPropertyDescriptors_Undefined_RaisesTypeError;
begin
  const ErrorName = Evaluate('(function () { try { Object.getOwnPropertyDescriptors(undefined); } catch (e) { return e.name; } })()');

  Assert.AreEqual('TypeError', ErrorName);
end;

procedure TEs2015LibraryTests.GlobalThis_Lookup_ReferencesGlobalObject(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
