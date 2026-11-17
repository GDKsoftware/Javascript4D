unit JS4D.Tests.NumberHelpers;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.NumberParse,
  JS4D.NumberText,
  JS4D.SymbolRegistry;

type
  [TestFixture]
  TNumberHelpersTests = class
  public
    [Test]
    [TestCase('NoDigitsAfterMark', '1e,1')]
    [TestCase('NoDigitsAfterSign', '1e+,1')]
    [TestCase('NegativeExponent', '25e-1,2.5')]
    [TestCase('ManyLeadingZerosInExponent', '1e0000000000003,1000')]
    procedure DecimalToDouble_WithIncompleteExponent_UsesZeroExponent(const Literal: string; const Expected: string);

    [Test]
    [TestCase('Short', '12,5,00012')]
    [TestCase('Long', '12345,3,12345')]
    [TestCase('Empty', ',2,00')]
    procedure PadLeft_ToCount_AddsLeadingZeros(const Digits: string; const Count: Integer; const Expected: string);

    [Test]
    [TestCase('Short', '12,5,12000')]
    [TestCase('Long', '12345,3,12345')]
    [TestCase('Empty', ',2,00')]
    procedure PadRight_ToCount_AddsTrailingZeros(const Digits: string; const Count: Integer; const Expected: string);

    [Test]
    [TestCase('AsyncIterator', '0,Symbol.asyncIterator')]
    [TestCase('Iterator', '3,Symbol.iterator')]
    [TestCase('ToStringTag', '11,Symbol.toStringTag')]
    [TestCase('Unscopables', '12,Symbol.unscopables')]
    procedure WellKnownDescription_ForSymbol_NamesTheStaticProperty(const Ordinal: Integer; const Expected: string);
  end;

implementation

procedure TNumberHelpersTests.DecimalToDouble_WithIncompleteExponent_UsesZeroExponent(const Literal: string;
                                                                                      const Expected: string);
begin
  const Value = TJSNumberParse.DecimalToDouble(Literal);

  Assert.AreEqual(Expected, FloatToStr(Value, TFormatSettings.Invariant));
end;

procedure TNumberHelpersTests.PadLeft_ToCount_AddsLeadingZeros(const Digits: string; const Count: Integer;
                                                               const Expected: string);
begin
  Assert.AreEqual(Expected, TJSNumberText.PadLeft(Digits, Count));
end;

procedure TNumberHelpersTests.PadRight_ToCount_AddsTrailingZeros(const Digits: string; const Count: Integer;
                                                                 const Expected: string);
begin
  Assert.AreEqual(Expected, TJSNumberText.PadRight(Digits, Count));
end;

procedure TNumberHelpersTests.WellKnownDescription_ForSymbol_NamesTheStaticProperty(const Ordinal: Integer;
                                                                                    const Expected: string);
begin
  Assert.AreEqual(Expected, TJSSymbolRegistry.WellKnownDescription(TJSWellKnownSymbol(Ordinal)));
end;

end.
