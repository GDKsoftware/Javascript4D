unit JS4D.Tests.RegExpSyntax;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TRegExpSyntaxTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOfConstructing(const Pattern: string; const Flags: string = ''): string;
    function ErrorNameOfEval(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure Constructor_InvalidFlags_ThrowsSyntaxError(const Pattern: string; const Flags: string);

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
    procedure Literal_InvalidRegExp_IsEarlySyntaxError(const Source: string);

    [Test]
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
    procedure Constructor_InvalidPatternWithUnicodeFlag_ThrowsSyntaxError(const Pattern: string; const Flags: string);

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
    [TestCase('IdentityEscape', '/\M/u', ';')]
    [TestCase('LoneBrace', '/{/u', ';')]
    [TestCase('OutOfBoundsEscape', '/\8/u', ';')]
    [TestCase('ClassRange', '/[\d-a]/u', ';')]
    [TestCase('BracedEscape', '/\u{110000}/u', ';')]
    procedure Literal_InvalidUnicodePattern_IsEarlySyntaxError(const Source: string);

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

const
  SyntaxErrorName = 'SyntaxError';
  NoError = 'none';

procedure TRegExpSyntaxTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpSyntaxTests.TearDown;
begin
  FEngine.Free;
end;

function TRegExpSyntaxTests.ErrorNameOfConstructing(const Pattern: string; const Flags: string): string;
begin
  FEngine.SetString('pattern', Pattern);
  FEngine.SetString('flags', Flags);

  Result := FEngine.Evaluate(
    'var name = "none"; try { new RegExp(pattern, flags); } catch (e) { name = e.name; } name').AsString;
end;

function TRegExpSyntaxTests.ErrorNameOfEval(const Source: string): string;
begin
  FEngine.SetString('source', Source);

  Result := FEngine.Evaluate(
    'var name = "none"; try { eval(source); } catch (e) { name = e.name; } name').AsString;
end;

procedure TRegExpSyntaxTests.Constructor_InvalidPattern_ThrowsSyntaxError(const Pattern: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfConstructing(Pattern));
end;

procedure TRegExpSyntaxTests.Constructor_ValidPattern_DoesNotThrow(const Pattern: string);
begin
  Assert.AreEqual(NoError, ErrorNameOfConstructing(Pattern));
end;

procedure TRegExpSyntaxTests.Constructor_InvalidFlags_ThrowsSyntaxError(const Pattern: string; const Flags: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfConstructing(Pattern, Flags));
end;

procedure TRegExpSyntaxTests.Constructor_ValidFlags_DoesNotThrow;
begin
  Assert.AreEqual(NoError, ErrorNameOfConstructing('a', 'gim'));
end;

procedure TRegExpSyntaxTests.Literal_InvalidRegExp_IsEarlySyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TRegExpSyntaxTests.Constructor_InvalidPatternWithUnicodeFlag_ThrowsSyntaxError(const Pattern: string; const Flags: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfConstructing(Pattern, Flags));
end;

procedure TRegExpSyntaxTests.Constructor_ValidPatternWithUnicodeFlag_DoesNotThrow(const Pattern: string; const Flags: string);
begin
  Assert.AreEqual(NoError, ErrorNameOfConstructing(Pattern, Flags));
end;

procedure TRegExpSyntaxTests.Literal_InvalidUnicodePattern_IsEarlySyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TRegExpSyntaxTests.Literal_ValidRegExp_StillMatches;
begin
  Assert.IsTrue(FEngine.Evaluate('/a{2}[b-d]+(?:x|y)$/.test("aacdy")').AsBoolean);
end;

procedure TRegExpSyntaxTests.Literal_ContainingLineSeparator_IsSyntaxError;
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval('/a' + #$2028 + 'b/'));
end;

procedure TRegExpSyntaxTests.Literal_ContainingParagraphSeparator_IsSyntaxError;
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval('/a' + #$2029 + 'b/'));
end;

procedure TRegExpSyntaxTests.Literal_InvalidRegExpAfterStatement_RunsNothing;
begin
  const Script = 'var reached = false; try { eval("reached = true; /a**/;"); } catch (e) {} reached';

  Assert.IsFalse(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TRegExpSyntaxTests.Constructor_RegExpArgument_CopiesSourceAndFlags;
begin
  const Script = 'var copy = new RegExp(/a+b/gi); copy.source + "|" + copy.global + "|" + copy.ignoreCase';

  Assert.AreEqual('a+b|true|true', FEngine.Evaluate(Script).AsString);
end;

procedure TRegExpSyntaxTests.Constructor_RegExpArgumentWithFlags_UsesGivenFlags;
begin
  const Script = 'var copy = new RegExp(/a+b/gi, "m"); copy.source + "|" + copy.global + "|" + copy.multiline';

  Assert.AreEqual('a+b|false|true', FEngine.Evaluate(Script).AsString);
end;

procedure TRegExpSyntaxTests.Constructor_UndefinedPattern_MatchesEmptyPattern;
begin
  Assert.IsTrue(FEngine.Evaluate('new RegExp(undefined).test("anything")').AsBoolean);
end;

procedure TRegExpSyntaxTests.Constructor_FlagsObject_UsesItsStringValue;
begin
  const Script = 'var re = new RegExp("a", { toString: function () { return "g"; } }); re.global';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TRegExpSyntaxTests.Constructor_AstralRangeWithUnicodeFlag_DoesNotThrow;
begin
  const Pattern = '[' + #$D83D#$DCA9 + '-' + #$D83D#$DCAB + ']';

  Assert.AreEqual(NoError, ErrorNameOfConstructing(Pattern, 'u'));
end;

procedure TRegExpSyntaxTests.Constructor_AstralRangeWithoutUnicodeFlag_ThrowsSyntaxError;
begin
  const Pattern = '[' + #$D83D#$DCA9 + '-' + #$D83D#$DCAB + ']';

  Assert.AreEqual(SyntaxErrorName, ErrorNameOfConstructing(Pattern));
end;

procedure TRegExpSyntaxTests.Match_UndefinedArgument_MatchesEmptyString;
begin
  const Script = 'var found = "undefined".match(undefined); found[0].length + "|" + found.index';

  Assert.AreEqual('0|0', FEngine.Evaluate(Script).AsString);
end;

end.
