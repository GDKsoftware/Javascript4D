unit JS4D.Tests.RegExpPatternSemantics;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TRegExpPatternSemanticsTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure UnicodeEscape_FourDigitCode_MatchesTheCharacter;

    [Test]
    procedure SurrogateEscapes_WithoutUnicodeFlag_MatchCodeUnits;

    [Test]
    procedure SurrogateEscapes_WithIgnoreCase_MatchCodeUnits;

    [Test]
    procedure Dot_WithoutUnicodeFlag_MatchesOneCodeUnit;

    [Test]
    procedure NonWhiteSpaceEscape_WithoutUnicodeFlag_MatchesLoneSurrogates;

    [Test]
    procedure SurrogateEscapes_WithUnicodeFlag_FormCodePoints;

    [Test]
    procedure BracketInClass_NestedBracket_IsLiteral;

    [Test]
    procedure HexEscape_TwoDigits_MatchesTheCharacter;

    [Test]
    procedure IncompleteEscapes_MissingDigits_MatchTheLetterLiterally;

    [Test]
    procedure EmptyClass_AnyInput_NeverMatches;

    [Test]
    procedure NegatedEmptyClass_LineTerminators_MatchesAnyCharacter;

    [Test]
    procedure ForwardBackReference_BeforeGroup_MatchesEmpty;

    [Test]
    procedure BackReferenceToUnsetGroup_MatchesEmpty;

    [Test]
    procedure BackReferenceInsideNegativeLookahead_MatchesEmptyWhenGroupIsUnset;

    [Test]
    procedure Dollar_BeforeFinalLineFeed_DoesNotMatch;

    [Test]
    procedure Dollar_Multiline_MatchesBeforeLineTerminator;

    [Test]
    [TestCase('NoBreakSpace', '\u00a0')]
    [TestCase('ByteOrderMark', '\ufeff')]
    [TestCase('LineSeparator', '\u2028')]
    [TestCase('ParagraphSeparator', '\u2029')]
    [TestCase('IdeographicSpace', '\u3000')]
    [TestCase('EnSpace', '\u2002')]
    [TestCase('VerticalTab', '\u000b')]
    procedure WhiteSpaceEscape_MatchesEcmaScriptWhiteSpace(const Character: string);

    [Test]
    [TestCase('Letter', 'a')]
    [TestCase('MongolianVowelSeparator', '\u180e')]
    [TestCase('ZeroWidthSpace', '\u200b')]
    [TestCase('NextLine', '\u0085')]
    procedure WhiteSpaceEscape_DoesNotMatchOtherCharacters(const Character: string);

    [Test]
    procedure NonWhiteSpaceEscape_Characters_MatchWhatWhiteSpaceDoesNot;

    [Test]
    procedure WhiteSpaceEscapes_InsideClasses_WorkAsOutside;

    [Test]
    procedure ControlEscape_Letter_MatchesTheControlCharacter;

    [Test]
    procedure ControlEscape_WithoutLetter_MatchesBackslashAndLetterLiterally;

    [Test]
    procedure RegExpConstructor_WithRegExpAndNoFlags_ReturnsTheSameObject;

    [Test]
    procedure RegExpConstructor_WithRegExpAndFlags_ReturnsNewObject;

    [Test]
    procedure RegExpConstructor_WithRegExpOfOtherConstructor_ReturnsNewObject;
  end;

implementation

uses
  System.SysUtils;

procedure TRegExpPatternSemanticsTests.UnicodeEscape_FourDigitCode_MatchesTheCharacter;
begin
  AssertChecksHold('',
    ['/\u0041/.test("A")',
     '!/\u0041/.test("B")',
     '/[\u0041-\u0043]/.test("B")']);
end;

procedure TRegExpPatternSemanticsTests.SurrogateEscapes_WithoutUnicodeFlag_MatchCodeUnits;
begin
  AssertChecksHold('',
    ['/\ud834/.test("\ud834\udf06")',
     '/\udf06/.test("\ud834\udf06")',
     '/^\ud834\udf06$/.test("\ud834\udf06")',
     '/[\ud800-\udbff]/.test("\ud834\udf06")',
     '!/\udf06\ud834/.test("\ud834\udf06")']);
end;

procedure TRegExpPatternSemanticsTests.SurrogateEscapes_WithIgnoreCase_MatchCodeUnits;
begin
  AssertChecksHold('',
    ['/\udf06/i.test("\ud834\udf06")',
     '/^\ud834\udf06$/i.test("\ud834\udf06")',
     '/\u00e9/i.test("\u00c9")']);
end;

procedure TRegExpPatternSemanticsTests.Dot_WithoutUnicodeFlag_MatchesOneCodeUnit;
begin
  AssertChecksHold('',
    ['"\ud834\udf06".match(/./g).length === 2',
     '!/^.$/.test("\ud834\udf06")',
     '/^.$/u.test("\ud834\udf06")',
     '"\ud834\udf06".match(/./gu).length === 1']);
end;

procedure TRegExpPatternSemanticsTests.NonWhiteSpaceEscape_WithoutUnicodeFlag_MatchesLoneSurrogates;
begin
  AssertChecksHold('',
    ['/^\S$/.test("\ud834")',
     '/^\S$/.test("\uffff")',
     '/^\S\S$/.test("\ud834\udf06")',
     '!/\S/.test("\u3000")']);
end;

procedure TRegExpPatternSemanticsTests.SurrogateEscapes_WithUnicodeFlag_FormCodePoints;
begin
  AssertChecksHold('',
    ['/^\ud834\udf06$/u.test("\ud834\udf06")',
     '/^[\ud834\udf06]$/u.test("\ud834\udf06")',
     '/\u{1d306}/u.test("\ud834\udf06")',
     '/\udf06/u.exec("\ud834\udf06") === null',
     '/\ud834/u.exec("\ud834\udf06") === null']);
end;

procedure TRegExpPatternSemanticsTests.BracketInClass_NestedBracket_IsLiteral;
begin
  AssertChecksHold('',
    ['/^[[.a.]]$/.test("a]")',
     '/^[[:a:]]$/.test("a]")',
     '"x".split(/[.-.]/).length === 1']);
end;

procedure TRegExpPatternSemanticsTests.HexEscape_TwoDigits_MatchesTheCharacter;
begin
  AssertChecksHold('',
    ['/\x41/.test("A")',
     '!/\x41/.test("B")',
     'new RegExp("\\x41").test("A")']);
end;

procedure TRegExpPatternSemanticsTests.IncompleteEscapes_MissingDigits_MatchTheLetterLiterally;
begin
  AssertChecksHold('',
    ['/\x4/.test("x4")',
     '/\u12/.test("u12")',
     '/\xg/.test("xg")']);
end;

procedure TRegExpPatternSemanticsTests.EmptyClass_AnyInput_NeverMatches;
begin
  AssertChecksHold('',
    ['!/[]/.test("a[]")',
     '!/[]a/.test("a")',
     '/[]|a/.test("a")']);
end;

procedure TRegExpPatternSemanticsTests.NegatedEmptyClass_LineTerminators_MatchesAnyCharacter;
begin
  AssertChecksHold('',
    ['/[^]/.exec("\n")[0] === "\n"',
     '/^[^]$/.test("\u2028")',
     '/a[^]c/.test("a\rc")']);
end;

procedure TRegExpPatternSemanticsTests.ForwardBackReference_BeforeGroup_MatchesEmpty;
begin
  AssertChecksHold('var m = /\1(A)/.exec("AA");',
    ['m !== null',
     'm[0] === "A"',
     'm[1] === "A"']);
end;

procedure TRegExpPatternSemanticsTests.BackReferenceToUnsetGroup_MatchesEmpty;
begin
  AssertChecksHold('var m = /(a)|b\1/.exec("b");',
    ['m !== null',
     'm[0] === "b"',
     'm[1] === undefined']);
end;

procedure TRegExpPatternSemanticsTests.BackReferenceInsideNegativeLookahead_MatchesEmptyWhenGroupIsUnset;
begin
  AssertChecksHold('var m = /(.*?)a(?!(a+)b\2c)\2(.*)/.exec("baaabaac");',
    ['m !== null',
     'm[0] === "baaabaac"',
     'm[1] === "ba"',
     'm[2] === undefined',
     'm[3] === "abaac"']);
end;

procedure TRegExpPatternSemanticsTests.Dollar_BeforeFinalLineFeed_DoesNotMatch;
begin
  AssertChecksHold('',
    ['!/a$/.test("a\n")',
     '/a$/.test("a")']);
end;

procedure TRegExpPatternSemanticsTests.Dollar_Multiline_MatchesBeforeLineTerminator;
begin
  AssertChecksHold('',
    ['/a$/m.test("a\nb")',
     '/a$/m.test("a\u2028b")']);
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscape_MatchesEcmaScriptWhiteSpace(const Character: string);
begin
  AssertChecksHold('', [Format('/^\s$/.test("%s")', [Character])]);
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscape_DoesNotMatchOtherCharacters(const Character: string);
begin
  AssertChecksHold('', [Format('!/\s/.test("%s")', [Character])]);
end;

procedure TRegExpPatternSemanticsTests.NonWhiteSpaceEscape_Characters_MatchWhatWhiteSpaceDoesNot;
begin
  AssertChecksHold('',
    ['/^\S$/.test("a")',
     '/^\S$/.test("\u180e")',
     '/^\S$/.test("\u0085")',
     '!/\S/.test("\u00a0")',
     '!/\S/.test("\ufeff")',
     '!/\S/.test(" \t\n")']);
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscapes_InsideClasses_WorkAsOutside;
begin
  AssertChecksHold('',
    ['/^[\s]$/.test("\u00a0")',
     '/^[a\s]$/.test("a")',
     '/^[\S]$/.test("x")',
     '!/[\S]/.test("\u3000")',
     '/^[^\s]$/.test("x")',
     '!/[^\s]/.test("\ufeff")']);
end;

procedure TRegExpPatternSemanticsTests.ControlEscape_Letter_MatchesTheControlCharacter;
begin
  AssertChecksHold('',
    ['/\cA/.test("\x01")',
     '/\cj/.test("\n")',
     '/[\cZ]/.test("\x1a")']);
end;

procedure TRegExpPatternSemanticsTests.ControlEscape_WithoutLetter_MatchesBackslashAndLetterLiterally;
begin
  AssertChecksHold('',
    ['/\c/.test("\\c")',
     '/\c1/.test("\\c1")',
     '/[\c]/.test("c")']);
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpAndNoFlags_ReturnsTheSameObject;
begin
  AssertChecksHold('var original = /x/i; var copy = RegExp(original);',
    ['copy === original',
     '(original.indicator = 1, copy.indicator === 1)']);
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpAndFlags_ReturnsNewObject;
begin
  AssertChecksHold('var original = /x/i; var copy = RegExp(original, "g");',
    ['copy !== original',
     'copy.global === true',
     'copy.source === "x"']);
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpOfOtherConstructor_ReturnsNewObject;
begin
  AssertChecksHold('var original = /x/; original.constructor = null; var copy = RegExp(original);',
    ['copy !== original',
     'copy.source === "x"']);
end;

end.
