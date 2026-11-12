unit JS4D.Tests.NumberParsing;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TNumberParsingTests = class
  private
    FEngine: TJSEngine;

    function StringOf(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Padded', '"  12  "|12', '|')]
    [TestCase('NoBreakSpace', '"\u00A012\u00A0"|12', '|')]
    [TestCase('ByteOrderMark', '"\uFEFF12"|12', '|')]
    [TestCase('LineSeparator', '"\u202812\u2029"|12', '|')]
    [TestCase('IdeographicSpace', '"\u300012"|12', '|')]
    [TestCase('OnlyWhiteSpace', '" \t\n "|0', '|')]
    [TestCase('Empty', '""|0', '|')]
    [TestCase('Hexadecimal', '"0x1F"|31', '|')]
    [TestCase('HexadecimalUpper', '"0XaB"|171', '|')]
    [TestCase('HexadecimalWithoutDigits', '"0x"|NaN', '|')]
    [TestCase('SignedHexadecimal', '"-0x1"|NaN', '|')]
    [TestCase('Binary', '"0b101"|5', '|')]
    [TestCase('BinaryUpper', '"0B11"|3', '|')]
    [TestCase('BinaryWithoutDigits', '"0b"|NaN', '|')]
    [TestCase('BinaryWithInvalidDigit', '"0b12"|NaN', '|')]
    [TestCase('SignedBinary', '"-0b1"|NaN', '|')]
    [TestCase('Octal', '"0o17"|15', '|')]
    [TestCase('OctalUpper', '"0O7"|7', '|')]
    [TestCase('OctalWithInvalidDigit', '"0o8"|NaN', '|')]
    [TestCase('Infinity', '"Infinity"|Infinity', '|')]
    [TestCase('PlusInfinity', '"+Infinity"|Infinity', '|')]
    [TestCase('MinusInfinity', '"-Infinity"|-Infinity', '|')]
    [TestCase('LowerCaseInfinity', '"infinity"|NaN', '|')]
    [TestCase('TrailingGarbage', '"12px"|NaN', '|')]
    [TestCase('LeadingPoint', '".5"|0.5', '|')]
    [TestCase('TrailingPoint', '"5."|5', '|')]
    [TestCase('LonePoint', '"."|NaN', '|')]
    [TestCase('Exponent', '"1e3"|1000', '|')]
    [TestCase('ExponentWithoutDigits', '"1e"|NaN', '|')]
    [TestCase('ExponentOverflow', '"10e10000"|Infinity', '|')]
    [TestCase('NegativeExponentOverflow', '"-10e10000"|-Infinity', '|')]
    [TestCase('ExponentUnderflow', '"10e-10000"|0', '|')]
    [TestCase('ObjectWithValueOf', '{valueOf: function () { return "7"; }}|7', '|')]
    [TestCase('ObjectWithToString', '{toString: function () { return "8"; }}|8', '|')]
    [TestCase('ObjectWithValueOfObject', '{valueOf: function () { return {}; }, toString: function () { return "9"; }}|9', '|')]
    procedure Number_Argument_ConvertsPerStringNumericLiteral(const Argument: string; const Expected: string);

    [Test]
    [TestCase('Literal', '10e10000|Infinity', '|')]
    [TestCase('NegativeLiteral', '-10e10000|-Infinity', '|')]
    [TestCase('Underflow', '10e-10000|0', '|')]
    procedure Literal_OutOfRange_BecomesInfinityOrZero(const Expression: string; const Expected: string);

    [Test]
    [TestCase('AboveLargestMidpoint', '1.797693134862315808e+308|Infinity', '|')]
    [TestCase('BelowLargestMidpoint', '1.797693134862315807e+308|1.7976931348623157e+308', '|')]
    [TestCase('LongFraction', '0.12345678901234567890|0.12345678901234568', '|')]
    [TestCase('SmallestDenormal', '5e-324|5e-324', '|')]
    [TestCase('BelowHalfOfSmallestDenormal', '2.4703282292062327e-324|0', '|')]
    [TestCase('AboveHalfOfSmallestDenormal', '2.4703282292062328e-324|5e-324', '|')]
    [TestCase('TieRoundsToEven', '9007199254740993|9007199254740992', '|')]
    [TestCase('TieRoundsUpToEven', '9007199254740995|9007199254740996', '|')]
    [TestCase('PowerOfTen', '1e23|1e+23', '|')]
    [TestCase('ManyDigits', '123456789012345678901234567890|1.2345678901234568e+29', '|')]
    [TestCase('ManyLeadingZeros', '0.000000000000000000000000000001|1e-30', '|')]
    [TestCase('HugeDigitsWithExponent', '1000000000000000000000000000000e-11|10000000000000000000', '|')]
    procedure Number_DecimalText_RoundsToNearestDouble(const Text: string; const Expected: string);

    [Test]
    [TestCase('Decimal', '"11"|undefined|11', '|')]
    [TestCase('FalseRadix', '"11"|false|11', '|')]
    [TestCase('ZeroRadixString', '"11"|"0"|11', '|')]
    [TestCase('NaNRadix', '"11"|NaN|11', '|')]
    [TestCase('RadixWraps', '"11"|4294967296|11', '|')]
    [TestCase('Binary', '"101"|2|5', '|')]
    [TestCase('Hexadecimal', '"ff"|16|255', '|')]
    [TestCase('Base36', '"zz"|36|1295', '|')]
    [TestCase('HexPrefixAutomatic', '"0x1F"|undefined|31', '|')]
    [TestCase('HexPrefixWithRadix16', '"0X1f"|16|31', '|')]
    [TestCase('HexPrefixWithOtherRadix', '"0x1"|10|0', '|')]
    [TestCase('DigitsStopAtInvalid', '"0123456789"|2|1', '|')]
    [TestCase('DollarStops', '"10$1"|2|2', '|')]
    [TestCase('NoDigits', '"$1"|10|NaN', '|')]
    [TestCase('RadixTooSmall', '"11"|1|NaN', '|')]
    [TestCase('RadixTooLarge', '"11"|37|NaN', '|')]
    [TestCase('Negative', '"-1"|2|-1', '|')]
    [TestCase('LeadingWhiteSpace', '"  1"|undefined|1', '|')]
    [TestCase('LeadingNoBreakSpace', '"\u00A01"|undefined|1', '|')]
    [TestCase('Fraction', '"1.9"|undefined|1', '|')]
    [TestCase('Zero', '"0"|0|0', '|')]
    [TestCase('BigDecimal', '"-10000000000000000000"|10|-10000000000000000000', '|')]
    [TestCase('BigHexadecimal', '"0x10000000000000000"|16|18446744073709552000', '|')]
    procedure ParseInt_Arguments_FollowsSpecification(const Text: string; const Radix: string;
                                                      const Expected: string);

    [Test]
    procedure ParseInt_ThrowingValueOfInRadix_Propagates;

    [Test]
    [TestCase('Plain', '"1.5"|1.5', '|')]
    [TestCase('Leading', '"   2.5"|2.5', '|')]
    [TestCase('LineSeparator', '"\u20281.1"|1.1', '|')]
    [TestCase('Infinity', '"Infinity"|Infinity', '|')]
    [TestCase('TrailingInfinity', '"Infinity1"|Infinity', '|')]
    [TestCase('NegativeInfinity', '"-Infinityx"|-Infinity', '|')]
    [TestCase('InfinityValue', 'Infinity|Infinity', '|')]
    [TestCase('Prefix', '"-11.string"|-11', '|')]
    [TestCase('PlusPoint', '"+.1string"|0.1', '|')]
    [TestCase('DanglingExponent', '"1ex"|1', '|')]
    [TestCase('Exponent', '"1e2x"|100', '|')]
    [TestCase('HexIsNotRecognised', '"0x10"|0', '|')]
    [TestCase('NoDigits', '"abc"|NaN', '|')]
    [TestCase('LonePoint', '"."|NaN', '|')]
    [TestCase('Empty', '""|NaN', '|')]
    procedure ParseFloat_Argument_ReadsLongestPrefix(const Text: string; const Expected: string);

    [Test]
    [TestCase('Space', '" "|""', '|')]
    [TestCase('NullIsNotWhiteSpace', '"\u0000a\u0000"|"\u0000a\u0000"', '|')]
    [TestCase('NoBreakSpace', '"\u00A0a\u00A0"|"a"', '|')]
    [TestCase('ByteOrderMark', '"\uFEFFa\uFEFF"|"a"', '|')]
    [TestCase('LineTerminators', '"  a\r\n\u2028\u2029"|"a"', '|')]
    [TestCase('OghamSpace', '"\u1680a\u3000"|"a"', '|')]
    [TestCase('MongolianVowelSeparator', '"\u180Ea"|"\u180Ea"', '|')]
    procedure Trim_Text_RemovesOnlyEcmaScriptWhiteSpace(const Text: string; const Expected: string);

    [Test]
    [TestCase('IsNaNObject', 'isNaN({valueOf: function () { return 1; }})|false', '|')]
    [TestCase('IsNaNInfinityString', 'isNaN("Infinity")|false', '|')]
    [TestCase('IsNaNArray', 'isNaN([1])|false', '|')]
    [TestCase('IsFiniteObject', 'isFinite({valueOf: function () { return 1; }})|true', '|')]
    [TestCase('IsFiniteArray', 'isFinite([1])|true', '|')]
    [TestCase('IsFiniteInfinityString', 'isFinite("Infinity")|false', '|')]
    procedure GlobalPredicate_ObjectArgument_ConvertsThroughToNumber(const Expression: string;
                                                                     const Expected: string);

    [Test]
    [TestCase('IsNaN', 'isNaN({valueOf: function () { throw new Error("x"); }})', '|')]
    [TestCase('IsFinite', 'isFinite({valueOf: function () { throw new Error("x"); }})', '|')]
    procedure GlobalPredicate_ThrowingValueOf_Propagates(const Expression: string);
  end;

implementation

procedure TNumberParsingTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TNumberParsingTests.TearDown;
begin
  FEngine.Free;
end;

function TNumberParsingTests.StringOf(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).AsString;
end;

procedure TNumberParsingTests.Number_Argument_ConvertsPerStringNumericLiteral(const Argument: string;
                                                                              const Expected: string);
begin
  const Actual = StringOf(Format('Number(%s)', [Argument]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberParsingTests.Literal_OutOfRange_BecomesInfinityOrZero(const Expression: string;
                                                                       const Expected: string);
begin
  const Actual = StringOf(Expression);

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberParsingTests.Number_DecimalText_RoundsToNearestDouble(const Text: string; const Expected: string);
begin
  const FromString = StringOf(Format('Number("%s")', [Text]));
  const FromLiteral = StringOf(Text);

  Assert.AreEqual(Expected, FromString);
  Assert.AreEqual(Expected, FromLiteral);
end;

procedure TNumberParsingTests.ParseInt_Arguments_FollowsSpecification(const Text: string;
                                                                      const Radix: string;
                                                                      const Expected: string);
begin
  const Actual = StringOf(Format('parseInt(%s, %s)', [Text, Radix]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberParsingTests.ParseInt_ThrowingValueOfInRadix_Propagates;
begin
  const Script = 'var caught = "none"; ' +
                 'try { parseInt("1", {valueOf: function () { throw "boom"; }}); } catch (e) { caught = e; } ' +
                 'caught';

  const Actual = FEngine.Evaluate(Script).AsString;

  Assert.AreEqual('boom', Actual);
end;

procedure TNumberParsingTests.ParseFloat_Argument_ReadsLongestPrefix(const Text: string; const Expected: string);
begin
  const Actual = StringOf(Format('parseFloat(%s)', [Text]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberParsingTests.Trim_Text_RemovesOnlyEcmaScriptWhiteSpace(const Text: string; const Expected: string);
begin
  const IsExpected = FEngine.Evaluate(Format('(%s).trim() === %s', [Text, Expected])).AsBoolean;

  Assert.IsTrue(IsExpected);
end;

procedure TNumberParsingTests.GlobalPredicate_ObjectArgument_ConvertsThroughToNumber(const Expression: string;
                                                                                     const Expected: string);
begin
  const Actual = StringOf(Expression);

  Assert.AreEqual(Expected, Actual);
end;

procedure TNumberParsingTests.GlobalPredicate_ThrowingValueOf_Propagates(const Expression: string);
begin
  const Script = Format('var thrown = false; try { %s; } catch (e) { thrown = true; } thrown', [Expression]);

  const HasThrown = FEngine.Evaluate(Script).AsBoolean;

  Assert.IsTrue(HasThrown);
end;

end.
