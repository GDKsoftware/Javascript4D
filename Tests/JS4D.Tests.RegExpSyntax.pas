unit JS4D.Tests.RegExpSyntax;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TRegExpSyntaxTests = class(TJSEngineTestCase)
  private
    function ErrorNameOfConstructing(const Pattern: string; const Flags: string = ''): string;

  public
    [Test]
    [TestCase('DoubleStar', 'a**', ';')]
    [TestCase('TripleLazyPlus', 'a+++', ';')]
    [TestCase('LeadingPlus', '+a', ';')]
    [TestCase('LeadingStar', '*a', ';')]
    [TestCase('LeadingQuestion', '?a', ';')]
    [TestCase('QuantifierAfterGroupOpen', '(*a)', ';')]
    [TestCase('QuantifierAfterAlternation', 'a|*b', ';')]
    [TestCase('QuantifierAfterBoundary', '\b+', ';')]
    [TestCase('QuantifierAfterCaret', '^*', ';')]
    [TestCase('QuantifierAfterDollar', '$+', ';')]
    [TestCase('LazyThenGreedy', 'a??*', ';')]
    [TestCase('BracedAfterBraced', 'x{1,2}{1}', ';')]
    [TestCase('BracedWithoutAtom', '{1}', ';')]
    [TestCase('BracedOutOfOrder', 'a{2,1}', ';')]
    [TestCase('UnclosedGroup', '(a', ';')]
    [TestCase('UnmatchedClosingParen', 'a)', ';')]
    [TestCase('UnclosedClass', '[a', ';')]
    [TestCase('UnknownGroupType', '(?a)', ';')]
    [TestCase('TrailingBackslash', 'a\', ';')]
    [TestCase('RangeOutOfOrder', '[b-a]', ';')]
    [TestCase('RangeOutOfOrderAfterEscape', '[ad-G]', ';')]
    [TestCase('RangeOutOfOrderHex', '[\x62-\x61]', ';')]
    procedure Constructor_InvalidPattern_ThrowsSyntaxError(const Pattern: string);

    [Test]
    [TestCase('Plain', 'abc', ';')]
    [TestCase('Alternation', 'a|b|', ';')]
    [TestCase('Groups', '(a)(?:b)(?=c)(?!d)', ';')]
    [TestCase('QuantifiedLookahead', '(?=a)*', ';')]
    [TestCase('Quantifiers', 'a*b+c?d{2}e{2,}f{1,3}g*?', ';')]
    [TestCase('LiteralOpeningBrace', 'a{', ';')]
    [TestCase('LiteralBracedText', 'a{,5}', ';')]
    [TestCase('LiteralClosingBrace', 'a}', ';')]
    [TestCase('LiteralClosingBracket', 'a]', ';')]
    [TestCase('BareOpeningBrace', '{', ';')]
    [TestCase('Escapes', '\d\D\s\S\w\W\b\B\n\r\t\f\v\0\1\cA\x41A\/\.', ';')]
    [TestCase('IdentityEscapes', '\a\z\-\e', ';')]
    [TestCase('IncompleteHexEscape', '\x4', ';')]
    [TestCase('ControlWithoutLetter', '\c1', ';')]
    [TestCase('Class', '[a-z0-9_]', ';')]
    [TestCase('NegatedClass', '[^abc]', ';')]
    [TestCase('EmptyClass', '[]', ';')]
    [TestCase('EmptyNegatedClass', '[^]', ';')]
    [TestCase('ClassWithEscapes', '[\d\s\-\]\\]', ';')]
    [TestCase('ClassWithTrailingDash', '[a-]', ';')]
    [TestCase('ClassWithLeadingDash', '[-a]', ';')]
    [TestCase('ClassSetInRange', '[\d-a]', ';')]
    [TestCase('ClassSetEndOfRange', '[a-\d]', ';')]
    [TestCase('ClassEqualRange', '[a-a]', ';')]
    [TestCase('ClassBackspaceRange', '[\b-a]', ';')]
    procedure Constructor_ValidPattern_DoesNotThrow(const Pattern: string);

    [Test]
    [TestCase('UnknownFlag', 'a;x', ';')]
    [TestCase('RepeatedFlag', 'a;gg', ';')]
    [TestCase('RepeatedAmongOthers', 'a;gmg', ';')]
    [TestCase('UpperCaseFlag', 'a;G', ';')]
    [TestCase('LoneOpeningBrace', '{;u', ';')]
    [TestCase('LoneClosingBrace', '};u', ';')]
    [TestCase('LoneClosingBracket', '];u', ';')]
    [TestCase('IncompleteQuantifier', 'a{;u', ';')]
    [TestCase('IncompleteQuantifierWithComma', 'a{1,;u', ';')]
    [TestCase('QuantifiedLookahead', '(?=.)*;u', ';')]
    [TestCase('QuantifiedNegativeLookahead', '(?!.)?;u', ';')]
    [TestCase('BracedLookahead', '(?=.){2,3};u', ';')]
    [TestCase('IdentityEscapeLetter', '\M;u', ';')]
    [TestCase('IdentityEscapeSpace', '\ ;u', ';')]
    [TestCase('IdentityEscapeDash', '\-;u', ';')]
    [TestCase('IncompleteHexEscape', '\x;u', ';')]
    [TestCase('IncompleteHexEscapeOneDigit', '\x4;u', ';')]
    [TestCase('IncompleteUnicodeEscape', '\u;u', ';')]
    [TestCase('IncompleteUnicodeEscapeThreeDigits', '\u123;u', ';')]
    [TestCase('BracedUnicodeEscapeWithComma', '\u{1,};u', ';')]
    [TestCase('BracedUnicodeEscapeEmpty', '\u{};u', ';')]
    [TestCase('BracedUnicodeEscapeUnclosed', '\u{1;u', ';')]
    [TestCase('BracedUnicodeEscapeTooLarge', '\u{110000};u', ';')]
    [TestCase('ControlEscapeWithoutLetter', '\c;u', ';')]
    [TestCase('ControlEscapeWithDigit', '\c0;u', ';')]
    [TestCase('LegacyOctalEscape', '\1;u', ';')]
    [TestCase('OutOfBoundsBackReference', '(a)\2;u', ';')]
    [TestCase('OutOfBoundsDecimalEscape', '\8;u', ';')]
    [TestCase('NullEscapeFollowedByDigit', '\00;u', ';')]
    [TestCase('ClassSetThenDashThenLetter', '[\d-a];u', ';')]
    [TestCase('ClassSetThenDashThenSet', '[\s-\d];u', ';')]
    [TestCase('ClassLetterThenDashThenSet', '[%-\d];u', ';')]
    [TestCase('ClassDashThenDashThenSet', '[--\d];u', ';')]
    [TestCase('ClassIdentityEscape', '[\M];u', ';')]
    [TestCase('ClassLegacyOctalEscape', '[\1];u', ';')]
    [TestCase('ClassControlEscapeWithDigit', '[\c0];u', ';')]
    [TestCase('ClassNonBoundaryEscape', '[\B];u', ';')]
    procedure Constructor_InvalidInput_ThrowsSyntaxError(const Pattern: string; const Flags: string);

    [Test]
    procedure Constructor_ValidFlags_DoesNotThrow;

    [Test]
    [TestCase('Star', '/a**/', ';')]
    [TestCase('LeadingPlus', '/+a/', ';')]
    [TestCase('OutOfOrderBraced', '/a{2,1}/', ';')]
    [TestCase('OutOfOrderRange', '/[b-a]/', ';')]
    [TestCase('UnclosedGroup', '/(a/', ';')]
    [TestCase('UnmatchedParen', '/a)/', ';')]
    [TestCase('BadFlag', '/a/x', ';')]
    [TestCase('DuplicateFlag', '/a/gg', ';')]
    [TestCase('IdentityEscape', '/\M/u', ';')]
    [TestCase('LoneBrace', '/{/u', ';')]
    [TestCase('OutOfBoundsEscape', '/\8/u', ';')]
    [TestCase('ClassRange', '/[\d-a]/u', ';')]
    [TestCase('BracedEscape', '/\u{110000}/u', ';')]
    procedure Literal_InvalidSource_IsEarlySyntaxError(const Source: string);

    [Test]
    [TestCase('Escapes', '\d\D\s\S\w\W\b\B\n\r\t\f\v\0\cA\x41A;u', ';')]
    [TestCase('SyntaxCharacterEscapes', '\^\$\\.\*\+\?\(\)\[\]\{\}\|\/;u', ';')]
    [TestCase('BracedUnicodeEscape', '\u{0}\u{3f}\u{000000003f}\u{10FFFF};u', ';')]
    [TestCase('SurrogatePairEscape', '\uD83D\uDE00;u', ';')]
    [TestCase('BackReference', '(a)\1;u', ';')]
    [TestCase('NamedBackReference', '(?<n>a)\k<n>;u', ';')]
    [TestCase('ClassEscapes', '[\d\-\b\n\x41A\u{41}\cA\0\^\]];u', ';')]
    [TestCase('ClassRanges', '[a-z\u{61}-\u{7a}\0-\x41];u', ';')]
    [TestCase('Quantifiers', 'a*b+c?d{2}e{2,}f{1,3}g*?;u', ';')]
    [TestCase('Lookbehind', '(?<=a)b;u', ';')]
    [TestCase('Groups', '(a)(?:b)(?=c)(?!d);u', ';')]
    [TestCase('LegacyEscapesWithoutUnicodeFlag', '\1[\1\c0]\M{];g', ';')]
    procedure Constructor_ValidPatternWithUnicodeFlag_DoesNotThrow(const Pattern: string; const Flags: string);

    [Test]
    procedure Literal_ValidRegExp_StillMatches;

    [Test]
    procedure Literal_ContainingLineSeparator_IsSyntaxError;

    [Test]
    procedure Literal_ContainingParagraphSeparator_IsSyntaxError;

    [Test]
    procedure Literal_InvalidRegExpAfterStatement_RunsNothing;

    [Test]
    procedure Constructor_RegExpArgument_CopiesSourceAndFlags;

    [Test]
    procedure Constructor_RegExpArgumentWithFlags_UsesGivenFlags;

    [Test]
    procedure Constructor_UndefinedPattern_MatchesEmptyPattern;

    [Test]
    procedure Constructor_FlagsObject_UsesItsStringValue;

    [Test]
    procedure Constructor_AstralRangeWithUnicodeFlag_DoesNotThrow;

    [Test]
    procedure Constructor_AstralRangeWithoutUnicodeFlag_ThrowsSyntaxError;

    [Test]
    procedure Match_UndefinedArgument_MatchesEmptyString;
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

const
  ASTRAL_RANGE_PATTERN = '[' + #$D83D#$DCA9 + '-' + #$D83D#$DCAB + ']';

function TRegExpSyntaxTests.ErrorNameOfConstructing(const Pattern: string; const Flags: string): string;
begin
  FEngine.SetString('pattern', Pattern);
  FEngine.SetString('flags', Flags);

  Result := ThrownErrorNameOf('new RegExp(pattern, flags);');
end;

procedure TRegExpSyntaxTests.Constructor_InvalidPattern_ThrowsSyntaxError(const Pattern: string);
begin
  const Actual = ErrorNameOfConstructing(Pattern);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Constructor_ValidPattern_DoesNotThrow(const Pattern: string);
begin
  const Actual = ErrorNameOfConstructing(Pattern);

  Assert.AreEqual(NO_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Constructor_InvalidInput_ThrowsSyntaxError(const Pattern: string; const Flags: string);
begin
  const Actual = ErrorNameOfConstructing(Pattern, Flags);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Constructor_ValidFlags_DoesNotThrow;
begin
  const Actual = ErrorNameOfConstructing('a', 'gim');

  Assert.AreEqual(NO_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Literal_InvalidSource_IsEarlySyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Constructor_ValidPatternWithUnicodeFlag_DoesNotThrow(const Pattern: string; const Flags: string);
begin
  const Actual = ErrorNameOfConstructing(Pattern, Flags);

  Assert.AreEqual(NO_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Literal_ValidRegExp_StillMatches;
begin
  const Matches = EvaluateBoolean('/a{2}[b-d]+(?:x|y)$/.test("aacdy")');

  Assert.IsTrue(Matches);
end;

procedure TRegExpSyntaxTests.Literal_ContainingLineSeparator_IsSyntaxError;
begin
  const Actual = ErrorNameOf('/a' + #$2028 + 'b/');

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Literal_ContainingParagraphSeparator_IsSyntaxError;
begin
  const Actual = ErrorNameOf('/a' + #$2029 + 'b/');

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Literal_InvalidRegExpAfterStatement_RunsNothing;
begin
  const Script = 'var reached = false; try { eval("reached = true; /a**/;"); } catch (e) {} reached';

  const Reached = EvaluateBoolean(Script);

  Assert.IsFalse(Reached);
end;

procedure TRegExpSyntaxTests.Constructor_RegExpArgument_CopiesSourceAndFlags;
begin
  const Script = 'var copy = new RegExp(/a+b/gi); copy.source + "|" + copy.global + "|" + copy.ignoreCase';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('a+b|true|true', Actual);
end;

procedure TRegExpSyntaxTests.Constructor_RegExpArgumentWithFlags_UsesGivenFlags;
begin
  const Script = 'var copy = new RegExp(/a+b/gi, "m"); copy.source + "|" + copy.global + "|" + copy.multiline';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('a+b|false|true', Actual);
end;

procedure TRegExpSyntaxTests.Constructor_UndefinedPattern_MatchesEmptyPattern;
begin
  const Matches = EvaluateBoolean('new RegExp(undefined).test("anything")');

  Assert.IsTrue(Matches);
end;

procedure TRegExpSyntaxTests.Constructor_FlagsObject_UsesItsStringValue;
begin
  const Script = 'var re = new RegExp("a", { toString: function () { return "g"; } }); re.global';

  const IsGlobal = EvaluateBoolean(Script);

  Assert.IsTrue(IsGlobal);
end;

procedure TRegExpSyntaxTests.Constructor_AstralRangeWithUnicodeFlag_DoesNotThrow;
begin
  const Actual = ErrorNameOfConstructing(ASTRAL_RANGE_PATTERN, 'u');

  Assert.AreEqual(NO_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Constructor_AstralRangeWithoutUnicodeFlag_ThrowsSyntaxError;
begin
  const Actual = ErrorNameOfConstructing(ASTRAL_RANGE_PATTERN);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TRegExpSyntaxTests.Match_UndefinedArgument_MatchesEmptyString;
begin
  const Script = 'var found = "undefined".match(undefined); found[0].length + "|" + found.index';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('0|0', Actual);
end;

end.
