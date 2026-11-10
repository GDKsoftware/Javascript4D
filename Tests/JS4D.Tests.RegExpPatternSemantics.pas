unit JS4D.Tests.RegExpPatternSemantics;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TRegExpPatternSemanticsTests = class
  private
    FEngine: TJSEngine;

    procedure AssertScript(const Script: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure UnicodeEscape_MatchesTheCharacter;

    [Test]
    procedure HexEscape_MatchesTheCharacter;

    [Test]
    procedure IncompleteEscapes_MatchTheLetterLiterally;

    [Test]
    procedure EmptyClass_NeverMatches;

    [Test]
    procedure NegatedEmptyClass_MatchesAnyCharacterIncludingLineTerminators;

    [Test]
    procedure ForwardBackReference_MatchesEmpty;

    [Test]
    procedure BackReferenceToUnsetGroup_MatchesEmpty;

    [Test]
    procedure BackReferenceInsideNegativeLookahead_MatchesEmptyWhenGroupIsUnset;

    [Test]
    procedure Dollar_DoesNotMatchBeforeFinalLineFeed;

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
    procedure NonWhiteSpaceEscape_MatchesWhatWhiteSpaceDoesNot;

    [Test]
    procedure WhiteSpaceEscapes_WorkInsideClasses;

    [Test]
    procedure ControlEscape_MatchesTheControlCharacter;

    [Test]
    procedure ControlEscapeWithoutLetter_MatchesBackslashAndLetterLiterally;

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

procedure TRegExpPatternSemanticsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpPatternSemanticsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TRegExpPatternSemanticsTests.AssertScript(const Script: string);
begin
  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean, Script);
end;

procedure TRegExpPatternSemanticsTests.UnicodeEscape_MatchesTheCharacter;
begin
  AssertScript('/\u0041/.test("A") && !/\u0041/.test("B") && /[\u0041-\u0043]/.test("B")');
end;

procedure TRegExpPatternSemanticsTests.HexEscape_MatchesTheCharacter;
begin
  AssertScript('/\x41/.test("A") && !/\x41/.test("B") && new RegExp("\\x41").test("A")');
end;

procedure TRegExpPatternSemanticsTests.IncompleteEscapes_MatchTheLetterLiterally;
begin
  AssertScript('/\x4/.test("x4") && /\u12/.test("u12") && /\xg/.test("xg")');
end;

procedure TRegExpPatternSemanticsTests.EmptyClass_NeverMatches;
begin
  AssertScript('!/[]/.test("a[]") && !/[]a/.test("a") && /[]|a/.test("a")');
end;

procedure TRegExpPatternSemanticsTests.NegatedEmptyClass_MatchesAnyCharacterIncludingLineTerminators;
begin
  AssertScript(
    '/[^]/.exec("\n")[0] === "\n" && /^[^]$/.test("\u2028") && /a[^]c/.test("a\rc")');
end;

procedure TRegExpPatternSemanticsTests.ForwardBackReference_MatchesEmpty;
begin
  AssertScript(
    'var m = /\1(A)/.exec("AA");' +
    'm !== null && m[0] === "A" && m[1] === "A"');
end;

procedure TRegExpPatternSemanticsTests.BackReferenceToUnsetGroup_MatchesEmpty;
begin
  AssertScript(
    'var m = /(a)|b\1/.exec("b");' +
    'm !== null && m[0] === "b" && m[1] === undefined');
end;

procedure TRegExpPatternSemanticsTests.BackReferenceInsideNegativeLookahead_MatchesEmptyWhenGroupIsUnset;
begin
  AssertScript(
    'var m = /(.*?)a(?!(a+)b\2c)\2(.*)/.exec("baaabaac");' +
    'm !== null && m[0] === "baaabaac" && m[1] === "ba" && m[2] === undefined && m[3] === "abaac"');
end;

procedure TRegExpPatternSemanticsTests.Dollar_DoesNotMatchBeforeFinalLineFeed;
begin
  AssertScript('!/a$/.test("a\n") && /a$/.test("a")');
end;

procedure TRegExpPatternSemanticsTests.Dollar_Multiline_MatchesBeforeLineTerminator;
begin
  AssertScript('/a$/m.test("a\nb") && /a$/m.test("a\u2028b")');
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscape_MatchesEcmaScriptWhiteSpace(const Character: string);
begin
  AssertScript(Format('/^\s$/.test("%s")', [Character]));
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscape_DoesNotMatchOtherCharacters(const Character: string);
begin
  AssertScript(Format('!/\s/.test("%s")', [Character]));
end;

procedure TRegExpPatternSemanticsTests.NonWhiteSpaceEscape_MatchesWhatWhiteSpaceDoesNot;
begin
  AssertScript(
    '/^\S$/.test("a") && /^\S$/.test("\u180e") && /^\S$/.test("\u0085") && ' +
    '!/\S/.test("\u00a0") && !/\S/.test("\ufeff") && !/\S/.test(" \t\n")');
end;

procedure TRegExpPatternSemanticsTests.WhiteSpaceEscapes_WorkInsideClasses;
begin
  AssertScript(
    '/^[\s]$/.test("\u00a0") && /^[a\s]$/.test("a") && /^[\S]$/.test("x") && ' +
    '!/[\S]/.test("\u3000") && /^[^\s]$/.test("x") && !/[^\s]/.test("\ufeff")');
end;

procedure TRegExpPatternSemanticsTests.ControlEscape_MatchesTheControlCharacter;
begin
  AssertScript('/\cA/.test("\x01") && /\cj/.test("\n") && /[\cZ]/.test("\x1a")');
end;

procedure TRegExpPatternSemanticsTests.ControlEscapeWithoutLetter_MatchesBackslashAndLetterLiterally;
begin
  AssertScript('/\c/.test("\\c") && /\c1/.test("\\c1") && /[\c]/.test("c")');
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpAndNoFlags_ReturnsTheSameObject;
begin
  AssertScript(
    'var original = /x/i; var copy = RegExp(original);' +
    'copy === original && (original.indicator = 1, copy.indicator === 1)');
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpAndFlags_ReturnsNewObject;
begin
  AssertScript(
    'var original = /x/i; var copy = RegExp(original, "g");' +
    'copy !== original && copy.global === true && copy.source === "x"');
end;

procedure TRegExpPatternSemanticsTests.RegExpConstructor_WithRegExpOfOtherConstructor_ReturnsNewObject;
begin
  AssertScript(
    'var original = /x/; original.constructor = null; var copy = RegExp(original);' +
    'copy !== original && copy.source === "x"');
end;

end.
