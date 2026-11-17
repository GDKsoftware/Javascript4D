unit JS4D.Tests.CaseMapping;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TCaseMappingTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('AsciiUpper', '"abc".toUpperCase() === "ABC"#true', '#')]
    [TestCase('AsciiLower', '"ABC".toLowerCase() === "abc"#true', '#')]
    [TestCase('SharpS', '"\u00DF".toUpperCase() === "SS"#true', '#')]
    [TestCase('LigatureFfi', '"\uFB03".toUpperCase() === "FFI"#true', '#')]
    [TestCase('ArmenianLigature', '"\u0587".toUpperCase() === "\u0535\u0552"#true', '#')]
    [TestCase('GreekIotaWithYpogegrammeni', '"\u1F80".toUpperCase() === "\u1F08\u0399"#true', '#')]
    [TestCase('DottedCapitalIUpperStaysTheSame', '"\u0130".toUpperCase() === "\u0130"#true', '#')]
    [TestCase('DottedCapitalILower', '"\u0130".toLowerCase() === "i\u0307"#true', '#')]
    [TestCase('LocaleUpperUsesSameMapping', '"\u00DF".toLocaleUpperCase() === "SS"#true', '#')]
    [TestCase('LocaleLowerUsesSameMapping', '"\u0130".toLocaleLowerCase() === "i\u0307"#true', '#')]
    [TestCase('DeseretUpper', '"\uD801\uDC28".toUpperCase() === "\uD801\uDC00"#true', '#')]
    [TestCase('DeseretLower', '"\uD801\uDC00".toLowerCase() === "\uD801\uDC28"#true', '#')]
    [TestCase('LoneSurrogateIsKept', '"\uD801a".toUpperCase() === "\uD801A"#true', '#')]
    [TestCase('LoneLowSurrogateIsKept', '"\uDC28a".toLowerCase() === "\uDC28a"#true', '#')]
    [TestCase('SigmaAlone', '"\u03A3".toLowerCase() === "\u03C3"#true', '#')]
    [TestCase('SigmaAfterLetter', '"A\u03A3".toLowerCase() === "a\u03C2"#true', '#')]
    [TestCase('SigmaBetweenLetters', '"A\u03A3B".toLowerCase() === "a\u03C3b"#true', '#')]
    [TestCase('SigmaAfterLetterAndFullStop', '"A.\u03A3".toLowerCase() === "a.\u03C2"#true', '#')]
    [TestCase('SigmaBeforeCaseIgnorableThenLetter', '"A\u03A3\u00ADB".toLowerCase() === "a\u03C3\u00ADb"#true', '#')]
    [TestCase('SigmaAfterSupplementaryCasedLetter', '"\uD835\uDCA2\u03A3".toLowerCase() === "\uD835\uDCA2\u03C2"#true', '#')]
    [TestCase('SigmaAfterCombiningMarkOnly', '"\u0345\u03A3".toLowerCase() === "\u0345\u03C3"#true', '#')]
    [TestCase('TitlecaseDigraphUpper', '"\u01C5".toUpperCase() === "\u01C4"#true', '#')]
    [TestCase('GeorgianMkhedruliUpper', '"\u10D0".toUpperCase() === "\u1C90"#true', '#')]
    [TestCase('CyrillicExtendedLower', '"\u0524".toLowerCase() === "\u0525"#true', '#')]
    [TestCase('MicroSignUpper', '"\u00B5".toUpperCase() === "\u039C"#true', '#')]
    [TestCase('UpperKeepsDigitsAndSymbols', '"a1-\u00E9".toUpperCase() === "A1-\u00C9"#true', '#')]
    procedure CaseMapping_OnScript_ReturnsExpected(const Expression, Expected: string);
  end;

implementation

procedure TCaseMappingTests.CaseMapping_OnScript_ReturnsExpected(const Expression, Expected: string);
begin
  const Actual = TextOf(Expression);

  Assert.AreEqual(Expected, Actual);
end;

end.