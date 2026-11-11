unit JS4D.Tests.NumberFormat;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TNumberFormatTests = class
  private
    FEngine: TJSEngine;

    function StringOf(const Expression: string): string;
    function ErrorNameOf(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Integer', '123|123', '|')]
    [TestCase('NegativeInteger', '-45|-45', '|')]
    [TestCase('Fraction', '1.5|1.5', '|')]
    [TestCase('PointOne', '0.1|0.1', '|')]
    [TestCase('Sum', '0.1 + 0.2|0.30000000000000004', '|')]
    [TestCase('TwentyOneDigits', '100000000000000000000|100000000000000000000', '|')]
    [TestCase('TwentyTwoDigits', '1e21|1e+21', '|')]
    [TestCase('LargeFraction', '1.5e300|1.5e+300', '|')]
    [TestCase('SmallestPlain', '0.000001|0.000001', '|')]
    [TestCase('FirstExponential', '0.0000001|1e-7', '|')]
    [TestCase('MantissaWithFraction', '1.2345e-9|1.2345e-9', '|')]
    [TestCase('MaxValue', 'Number.MAX_VALUE|1.7976931348623157e+308', '|')]
    [TestCase('MinValue', 'Number.MIN_VALUE|5e-324', '|')]
    [TestCase('NegativeZero', '-0|0', '|')]
    [TestCase('ThirdFraction', '1 / 3|0.3333333333333333', '|')]
    [TestCase('BeyondExactInteger', '9007199254740993|9007199254740992', '|')]
    [TestCase('NineteenDigitsBelowLimit', '999999999999999900000|999999999999999900000', '|')]
    [TestCase('SingleDenormalLiteral', '2.059411001342953e-38|2.059411001342953e-38', '|')]
    [TestCase('DoubleDenormalLiteral', '2.254739805726094e-307|2.254739805726094e-307', '|')]
    [TestCase('LongLiteralRoundsToNeighbour', '0.12345678901234567890|0.12345678901234568', '|')]
    [TestCase('LargestPowerProduct', 'Math.pow(2, 52) * Math.pow(2, 971)|8.98846567431158e+307', '|')]
    [TestCase('MaxValueLiteral', '1.7976931348623157e308|1.7976931348623157e+308', '|')]
    [TestCase('SquareRootEqualsLiteral', 'Math.sqrt(0.00812479431693535) === 0.09013764095501585|true', '|')]
    procedure ToString_Number_UsesShortestRoundTrip(const Expression: string; const Expected: string);

    [Test]
    [TestCase('Rounds', '1.005|2|1.00', '|')]
    [TestCase('HalfGoesUp', '2.5|0|3', '|')]
    [TestCase('Padded', '1|3|1.000', '|')]
    [TestCase('Carry', '0.999|2|1.00', '|')]
    [TestCase('BelowOne', '0.5|0|1', '|')]
    [TestCase('ZeroFraction', '0.4|0|0', '|')]
    [TestCase('Negative', '-1.55|1|-1.6', '|')]
    [TestCase('NegativeRoundsToZero', '-0.0001|2|-0.00', '|')]
    [TestCase('ExactBinary', '1000000000000000128|0|1000000000000000128', '|')]
    [TestCase('TooLarge', '1e21|2|1e+21', '|')]
    [TestCase('NotANumber', 'NaN|2|NaN', '|')]
    [TestCase('InfinityValue', 'Infinity|2|Infinity', '|')]
    [TestCase('MaximumDigits', '0.5|20|0.50000000000000000000', '|')]
    [TestCase('HundredDigits', '3|100|3.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', '|')]
    [TestCase('BeyondTwentyDigits', '0.5|25|0.5000000000000000000000000', '|')]
    [TestCase('ExactBeyondTwentyDigits', '0.1|25|0.1000000000000000055511151', '|')]
    [TestCase('ArrayDigits', '1.5|[1]|1.5', '|')]
    [TestCase('StringDigits', '1.5|"1"|1.5', '|')]
    procedure ToFixed_Digits_RoundsExactValue(const Value: string; const Digits: string; const Expected: string);

    [Test]
    [TestCase('Default', '123456|undefined|1.23456e+5', '|')]
    [TestCase('Zero', '123.456|0|1e+2', '|')]
    [TestCase('Padded', '1|3|1.000e+0', '|')]
    [TestCase('Rounded', '12345|2|1.23e+4', '|')]
    [TestCase('Carry', '9.99|1|1.0e+1', '|')]
    [TestCase('Small', '0.00015|1|1.5e-4', '|')]
    [TestCase('ZeroValue', '0|2|0.00e+0', '|')]
    [TestCase('ZeroDefault', '0|undefined|0e+0', '|')]
    [TestCase('Negative', '-1234|1|-1.2e+3', '|')]
    [TestCase('NotANumber', 'NaN|2|NaN', '|')]
    [TestCase('NegativeInfinity', '-Infinity|2|-Infinity', '|')]
    [TestCase('FractionOfOne', '123.456|1.9|1.2e+2', '|')]
    [TestCase('ArrayDigits', '123.456|[2]|1.23e+2', '|')]
    [TestCase('StringDigits', '123.456|"2"|1.23e+2', '|')]
    [TestCase('EmptyStringDigits', '123.456|""|1e+2', '|')]
    [TestCase('BooleanDigits', '123.456|true|1.2e+2', '|')]
    [TestCase('HundredDigits', '1|100|1.0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000e+0', '|')]
    procedure ToExponential_Digits_FormatsMantissaAndExponent(const Value: string; const Digits: string; const Expected: string);

    [Test]
    [TestCase('Default', '123.456|undefined|123.456', '|')]
    [TestCase('Rounded', '123.456|4|123.5', '|')]
    [TestCase('Padded', '7|2|7.0', '|')]
    [TestCase('ExponentialLarge', '123456|2|1.2e+5', '|')]
    [TestCase('ExponentialAtPrecision', '10|1|1e+1', '|')]
    [TestCase('ExponentialSmall', '0.0000001234|2|1.2e-7', '|')]
    [TestCase('PlainSmall', '0.000001234|2|0.0000012', '|')]
    [TestCase('ZeroValue', '0|3|0.00', '|')]
    [TestCase('Carry', '9.99|2|10', '|')]
    [TestCase('Negative', '-1.25|2|-1.3', '|')]
    [TestCase('NotANumber', 'NaN|3|NaN', '|')]
    [TestCase('InfinityValue', 'Infinity|3|Infinity', '|')]
    [TestCase('TruncatesPrecision', '123|1.9|1e+2', '|')]
    [TestCase('ArrayPrecision', '123.456|[2]|1.2e+2', '|')]
    [TestCase('StringPrecision', '123.456|"2"|1.2e+2', '|')]
    [TestCase('BooleanPrecision', '123.456|true|1e+2', '|')]
    [TestCase('HundredPrecision', '1|100|1.000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000', '|')]
    procedure ToPrecision_Digits_ChoosesNotation(const Value: string; const Digits: string; const Expected: string);

    [Test]
    [TestCase('FixedNegative', '(1).toFixed(-1)')]
    [TestCase('FixedTooLarge', '(1).toFixed(101)')]
    [TestCase('FixedInfinity', '(1).toFixed(Infinity)')]
    [TestCase('ExponentialNegative', '(1).toExponential(-1)')]
    [TestCase('ExponentialTooLarge', '(1).toExponential(101)')]
    [TestCase('PrecisionZero', '(1).toPrecision(0)')]
    [TestCase('PrecisionTooLarge', '(1).toPrecision(101)')]
    [TestCase('RadixTooSmall', '(1).toString(1)')]
    [TestCase('RadixTooLarge', '(1).toString(37)')]
    [TestCase('RadixTooSmallForInfinity', 'Infinity.toString(1)')]
    [TestCase('RadixTooLargeForNaN', 'NaN.toString(37)')]
    procedure Format_DigitsOutOfRange_ThrowsRangeError(const Expression: string);

    [Test]
    [TestCase('Undefined', 'undefined|255', '|')]
    [TestCase('Binary', '2|11111111', '|')]
    [TestCase('Hexadecimal', '16|ff', '|')]
    [TestCase('Fractional', '16.9|ff', '|')]
    procedure ToString_Radix_ConvertsInteger(const Radix: string; const Expected: string);

    [Test]
    [TestCase('NoArguments', '(255).toLocaleString()|255', '|')]
    [TestCase('LocaleAndOptions', '1234.5.toLocaleString("nl-NL", { minimumFractionDigits: 2 })|1234.5', '|')]
    procedure ToLocaleString_Arguments_AreNotUsedAsRadix(const Expression: string; const Expected: string);

    [Test]
    procedure ToExponential_InfiniteValueWithBadDigits_ReturnsInfinity;
  end;

implementation

const
  NoError = 'none';
  RangeErrorName = 'RangeError';

procedure TNumberFormatTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TNumberFormatTests.TearDown;
begin
  FEngine.Free;
end;

function TNumberFormatTests.StringOf(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).AsString;
end;

function TNumberFormatTests.ErrorNameOf(const Expression: string): string;
begin
  const Script = Format('var name = ''%s''; try { %s; } catch (e) { name = e.name; } name',
                        [NoError, Expression]);

  Result := FEngine.Evaluate(Script).AsString;
end;

procedure TNumberFormatTests.ToString_Number_UsesShortestRoundTrip(const Expression: string; const Expected: string);
begin
  const Actual = StringOf(Expression);

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.ToFixed_Digits_RoundsExactValue(const Value: string; const Digits: string; const Expected: string);
begin
  const Actual = StringOf(Format('(%s).toFixed(%s)', [Value, Digits]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.ToExponential_Digits_FormatsMantissaAndExponent(const Value: string; const Digits: string;
                                                                             const Expected: string);
begin
  const Actual = StringOf(Format('(%s).toExponential(%s)', [Value, Digits]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.ToPrecision_Digits_ChoosesNotation(const Value: string; const Digits: string; const Expected: string);
begin
  const Actual = StringOf(Format('(%s).toPrecision(%s)', [Value, Digits]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.Format_DigitsOutOfRange_ThrowsRangeError(const Expression: string);
begin
  const Actual = ErrorNameOf(Expression);

  Assert.AreEqual(RangeErrorName, Actual);
end;

procedure TNumberFormatTests.ToString_Radix_ConvertsInteger(const Radix: string; const Expected: string);
begin
  const Actual = StringOf(Format('(255).toString(%s)', [Radix]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.ToLocaleString_Arguments_AreNotUsedAsRadix(const Expression: string; const Expected: string);
begin
  const Actual = StringOf(Expression);

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberFormatTests.ToExponential_InfiniteValueWithBadDigits_ReturnsInfinity;
begin
  const Actual = StringOf('Infinity.toExponential(1000)');

  Assert.AreEqual('Infinity', Actual);
end;

end.
