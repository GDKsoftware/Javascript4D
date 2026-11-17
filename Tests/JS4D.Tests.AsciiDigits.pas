unit JS4D.Tests.AsciiDigits;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.AsciiDigits;

type
  [TestFixture]
  TAsciiDigitsTests = class
  public
    [Test]
    [TestCase('Zero', '0,0')]
    [TestCase('Nine', '9,9')]
    [TestCase('LowerLetter', 'a,10')]
    [TestCase('UpperLetter', 'Z,35')]
    [TestCase('Punctuation', '-,-1')]
    procedure DigitValue_OfCharacter_ReturnsValueInLargestRadix(const Text: string; const Expected: Integer);

    [Test]
    [TestCase('Decimal', '7,10,True')]
    [TestCase('AboveRadix', '7,7,False')]
    [TestCase('Letter', 'f,16,True')]
    [TestCase('LetterAboveRadix', 'g,16,False')]
    procedure IsDigitInRadix_WithRadix_ChecksTheRange(const Text: string; const Radix: Integer;
                                                      const Expected: Boolean);

    [Test]
    [TestCase('Digit', '8,8')]
    [TestCase('LowerLetter', 'e,14')]
    [TestCase('UpperLetter', 'F,15')]
    [TestCase('LetterBeyondHex', 'G,-1')]
    [TestCase('Dash', '-,-1')]
    procedure HexValue_OfCharacter_ReturnsHexDigitValue(const Text: string; const Expected: Integer);

    [Test]
    [TestCase('Unit', '0041,1,4,True,65')]
    [TestCase('Mixed', 'xx1aF,3,3,True,431')]
    [TestCase('NotHex', '00G1,1,4,False,0')]
    [TestCase('TooShort', '00,1,4,False,0')]
    [TestCase('BeforeStart', '0041,0,4,False,0')]
    procedure TryParseHex_WithText_ParsesWhenAllDigitsAreHex(const Text: string; const Start: Integer;
                                                             const Count: Integer; const Expected: Boolean;
                                                             const ExpectedValue: Integer);

    [Test]
    procedure TryParseHex_WithManyDigits_SaturatesAboveTheLastCodePoint;
  end;

implementation

procedure TAsciiDigitsTests.DigitValue_OfCharacter_ReturnsValueInLargestRadix(const Text: string;
                                                                              const Expected: Integer);
begin
  Assert.AreEqual(Expected, TJSAsciiDigits.DigitValue(Text[1]));
end;

procedure TAsciiDigitsTests.IsDigitInRadix_WithRadix_ChecksTheRange(const Text: string; const Radix: Integer;
                                                                    const Expected: Boolean);
begin
  Assert.AreEqual(Expected, TJSAsciiDigits.IsDigitInRadix(Text[1], Radix));
end;

procedure TAsciiDigitsTests.HexValue_OfCharacter_ReturnsHexDigitValue(const Text: string; const Expected: Integer);
begin
  Assert.AreEqual(Expected, TJSAsciiDigits.HexValue(Text[1]));
end;

procedure TAsciiDigitsTests.TryParseHex_WithText_ParsesWhenAllDigitsAreHex(const Text: string; const Start: Integer;
                                                                           const Count: Integer;
                                                                           const Expected: Boolean;
                                                                           const ExpectedValue: Integer);
begin
  var Value: Integer;
  const IsParsed = TJSAsciiDigits.TryParseHex(Text, Start, Count, Value);

  Assert.AreEqual(Expected, IsParsed);
  if Expected then
    Assert.AreEqual(ExpectedValue, Value);
end;

procedure TAsciiDigitsTests.TryParseHex_WithManyDigits_SaturatesAboveTheLastCodePoint;
begin
  var Value: Integer;
  const IsParsed = TJSAsciiDigits.TryParseHex('FFFFFFFFFFFFFFFFFFFF', 1, 20, Value);

  Assert.IsTrue(IsParsed);
  Assert.IsTrue(Value > $10FFFF);
end;

end.
