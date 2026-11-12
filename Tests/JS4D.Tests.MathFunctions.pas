unit JS4D.Tests.MathFunctions;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TMathFunctionsTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('CeilNegativeZero', '1 / Math.ceil(-0)#-Infinity', '#')]
    [TestCase('CeilSmallNegative', '1 / Math.ceil(-0.5)#-Infinity', '#')]
    [TestCase('CeilPositiveZero', '1 / Math.ceil(0)#Infinity', '#')]
    [TestCase('FloorNegativeZero', '1 / Math.floor(-0)#-Infinity', '#')]
    [TestCase('FloorSmallPositive', '1 / Math.floor(0.5)#Infinity', '#')]
    [TestCase('RoundNegativeZero', '1 / Math.round(-0)#-Infinity', '#')]
    [TestCase('RoundSmallNegative', '1 / Math.round(-0.4)#-Infinity', '#')]
    [TestCase('RoundNegativeHalf', '1 / Math.round(-0.5)#-Infinity', '#')]
    [TestCase('TruncSmallNegative', '1 / Math.trunc(-0.9)#-Infinity', '#')]
    [TestCase('SignNegativeZero', '1 / Math.sign(-0)#-Infinity', '#')]
    [TestCase('SinNegativeZero', '1 / Math.sin(-0)#-Infinity', '#')]
    [TestCase('TanNegativeZero', '1 / Math.tan(-0)#-Infinity', '#')]
    [TestCase('MaxNegativeThenPositiveZero', '1 / Math.max(-0, 0)#Infinity', '#')]
    [TestCase('MaxPositiveThenNegativeZero', '1 / Math.max(0, -0)#Infinity', '#')]
    [TestCase('MaxOfNegativeZeros', '1 / Math.max(-0, -0)#-Infinity', '#')]
    [TestCase('MinPositiveThenNegativeZero', '1 / Math.min(0, -0)#-Infinity', '#')]
    [TestCase('MinNegativeThenPositiveZero', '1 / Math.min(-0, 0)#-Infinity', '#')]
    [TestCase('MinOfPositiveZeros', '1 / Math.min(0, 0)#Infinity', '#')]
    [TestCase('PowNegativeZeroOddExponent', '1 / Math.pow(-0, 3)#-Infinity', '#')]
    [TestCase('PowNegativeZeroEvenExponent', '1 / Math.pow(-0, 2)#Infinity', '#')]
    [TestCase('PowNegativeZeroNegativeOddExponent', 'Math.pow(-0, -3)#-Infinity', '#')]
    [TestCase('PowPositiveZeroNegativeExponent', 'Math.pow(0, -1)#Infinity', '#')]
    [TestCase('RemainderNegativeDividend', '1 / (-1 % 1)#-Infinity', '#')]
    [TestCase('RemainderNegativeBoth', '1 / (-1 % -1)#-Infinity', '#')]
    [TestCase('RemainderPositiveDividend', '1 / (1 % -1)#Infinity', '#')]
    [TestCase('RemainderNegativeZeroDividend', '1 / (-0 % 5)#-Infinity', '#')]
    procedure Function_AtZero_KeepsSignOfZero(const Expression, Expected: string);

    [Test]
    [TestCase('FloorBeyondInt32', 'Math.floor(1e20)#100000000000000000000', '#')]
    [TestCase('FloorNegativeFraction', 'Math.floor(-1.5)#-2', '#')]
    [TestCase('FloorBeyondInt64', 'Math.floor(-3e19)#-30000000000000000000', '#')]
    [TestCase('CeilBeyondInt32', 'Math.ceil(5000000000.5)#5000000001', '#')]
    [TestCase('CeilNegativeFraction', 'Math.ceil(-1.5)#-1', '#')]
    [TestCase('RoundTieGoesUp', 'Math.round(2.5)#3', '#')]
    [TestCase('RoundNegativeTieGoesUp', 'Math.round(-2.5)#-2', '#')]
    [TestCase('RoundJustBelowHalf', 'Math.round(0.49999999999999994)#0', '#')]
    [TestCase('RoundBeyondInt32', 'Math.round(1e15 + 0.5)#1000000000000001', '#')]
    [TestCase('RoundInfinity', 'Math.round(-Infinity)#-Infinity', '#')]
    [TestCase('RoundNaN', 'Math.round(NaN)#NaN', '#')]
    [TestCase('PowOneToInfinity', 'Math.pow(1, Infinity)#NaN', '#')]
    [TestCase('PowTwoToInfinity', 'Math.pow(2, Infinity)#Infinity', '#')]
    [TestCase('PowHalfToInfinity', 'Math.pow(0.5, Infinity)#0', '#')]
    [TestCase('PowHalfToNegativeInfinity', 'Math.pow(0.5, -Infinity)#Infinity', '#')]
    [TestCase('PowNaNToZero', 'Math.pow(NaN, 0)#1', '#')]
    [TestCase('PowToNaN', 'Math.pow(2, NaN)#NaN', '#')]
    [TestCase('PowIntegers', 'Math.pow(2, 10)#1024', '#')]
    [TestCase('SinInfinity', 'Math.sin(Infinity)#NaN', '#')]
    [TestCase('TanInfinity', 'Math.tan(-Infinity)#NaN', '#')]
    [TestCase('MaxOfValues', 'Math.max(1, 3, 2)#3', '#')]
    [TestCase('MinOfValues', 'Math.min(3, 1, 2)#1', '#')]
    [TestCase('MaxWithNaN', 'Math.max(1, NaN, 2)#NaN', '#')]
    [TestCase('MinWithLeadingNaN', 'Math.min(NaN, 1)#NaN', '#')]
    [TestCase('LogPositiveZero', 'Math.log(0)#-Infinity', '#')]
    [TestCase('LogNegativeZero', 'Math.log(-0)#-Infinity', '#')]
    [TestCase('LogNegative', 'Math.log(-1)#NaN', '#')]
    [TestCase('LogNaN', 'Math.log(NaN)#NaN', '#')]
    [TestCase('LogOne', 'Math.log(1)#0', '#')]
    [TestCase('PowNegativeInfinityFraction', 'Math.pow(-Infinity, 0.5)#Infinity', '#')]
    [TestCase('PowNegativeInfinityOddPower', 'Math.pow(-Infinity, 3)#-Infinity', '#')]
    [TestCase('PowNegativeInfinityEvenPower', 'Math.pow(-Infinity, 2)#Infinity', '#')]
    [TestCase('PowNegativeInfinityNegativeFraction', '1 / Math.pow(-Infinity, -0.5)#Infinity', '#')]
    [TestCase('PowNegativeInfinityNegativeOddPower', '1 / Math.pow(-Infinity, -3)#-Infinity', '#')]
    [TestCase('PowPositiveInfinityNegativePower', 'Math.pow(Infinity, -2)#0', '#')]
    [TestCase('MaxConvertsEveryArgumentAfterNaN', '(function () { var c = 0; Math.max(NaN, { valueOf: function () { c++; return 1; } }); return c; })()#1', '#')]
    [TestCase('MinConvertsEveryArgumentAfterNaN', '(function () { var c = 0; Math.min(NaN, { valueOf: function () { c++; return 1; } }); return c; })()#1', '#')]
    procedure Function_OnOrdinaryValues_ReturnsSpecResult(const Expression, Expected: string);
  end;

implementation

procedure TMathFunctionsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TMathFunctionsTests.TearDown;
begin
  FEngine.Free;
end;

function TMathFunctionsTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TMathFunctionsTests.Function_AtZero_KeepsSignOfZero(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TMathFunctionsTests.Function_OnOrdinaryValues_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
