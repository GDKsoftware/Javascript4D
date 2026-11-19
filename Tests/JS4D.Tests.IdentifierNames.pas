unit JS4D.Tests.IdentifierNames;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Errors,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.Tests.Support;

type
  TFirstToken = record
    TokenType: TJSTokenType;
    Value: string;
  end;

  [TestFixture]
  TIdentifierNamesTests = class(TJSEngineTestCase)
  private
    function FirstTokenOf(const Source: string): TFirstToken;

  public
    [Test]
    procedure Lexer_EscapedIdentifierStart_ReturnsIdentifierWithDecodedName;

    [Test]
    procedure Lexer_EscapedIdentifierPart_ReturnsIdentifierWithDecodedName;

    [Test]
    procedure Lexer_EscapedKeyword_IsNotAKeywordToken;

    [Test]
    procedure Lexer_EscapedNonReservedWord_IsAnIdentifier;

    [Test]
    procedure Lexer_UnicodeCombiningMarkInsideIdentifier_IsPartOfTheName;

    [Test]
    procedure Variable_DeclaredWithEscape_IsReachableByPlainName;

    [Test]
    procedure Variable_ReferencedWithEscape_ReadsPlainName;

    [Test]
    procedure PropertyName_EscapedKeywordInLiteral_IsAllowed;

    [Test]
    procedure PropertyName_KeywordInLiteral_IsAllowed;

    [Test]
    procedure PropertyName_KeywordAfterDot_IsAllowed;

    [Test]
    procedure PropertyName_EscapedKeywordAfterDot_IsAllowed;

    [Test]
    procedure PropertyName_LiteralsTrueAndNull_AreAllowed;

    [Test]
    procedure Identifier_EscapedKeywordAsVariable_IsSyntaxError;

    [Test]
    procedure Identifier_EscapedKeywordAsExpression_IsSyntaxError;

    [Test]
    procedure Identifier_EscapedFutureReservedWord_IsSyntaxError;

    [Test]
    procedure Identifier_EscapedStrictReservedWordInStrictCode_IsSyntaxError;

    [Test]
    procedure Identifier_EscapedStrictReservedWordInSloppyCode_IsAllowed;

    [Test]
    procedure Identifier_EscapedTrue_IsSyntaxError;

    [Test]
    procedure Lexer_CodePointEscapeInIdentifier_ReturnsDecodedName;

    [Test]
    procedure Lexer_AstralCodePointEscapeInIdentifier_ReturnsSurrogatePair;

    [Test]
    [TestCase('NotIdentifierCharacter', '\u{31}a')]
    [TestCase('AboveLastCodePoint', 'a\u{110000}')]
    [TestCase('Empty', 'a\u{}')]
    [TestCase('Unterminated', 'a\u{61')]
    [TestCase('BackslashWithoutUnicodeEscape', 'a\x41')]
    [TestCase('EscapedDigitAtStart', '\u0031a')]
    [TestCase('DirectlyAfterNumber', '0\u00620')]
    [TestCase('EscapeInRegExpFlags', '/./\u0067')]
    [TestCase('VerticalTilde', 'a\u2E2F')]
    [TestCase('AstralDigitAtStart', #$D835#$DFD8 + 'a')]
    [TestCase('OtherIdContinueAtStart', #$00B7 + 'a')]
    procedure Lexer_InvalidIdentifier_RaisesSyntaxError(const Source: string);

    [Test]
    procedure Lexer_AstralLetterAtIdentifierStart_IsPartOfTheName;

    [Test]
    procedure Lexer_AstralDigitInsideIdentifier_IsPartOfTheName;

    [Test]
    procedure Lexer_OtherIdStartCharacter_StartsAnIdentifier;

    [Test]
    procedure Lexer_OtherIdContinueCharacter_ContinuesAnIdentifier;

    [Test]
    [TestCase('Basic', '"\u{41}"|A', '|')]
    [TestCase('LeadingZeros', '"\u{0000041}"|A', '|')]
    [TestCase('AstralLength', '"\u{1F600}".length|2', '|')]
    [TestCase('AstralHighSurrogate', '"\u{1F600}".charCodeAt(0)|55357', '|')]
    procedure String_CodePointEscape_ProducesCodePoint(const Source: string; const Expected: string);

    [Test]
    [TestCase('Empty', '"\u{}"')]
    [TestCase('Unterminated', '"\u{41"')]
    [TestCase('TooLarge', '"\u{110000}"')]
    procedure String_InvalidCodePointEscape_IsSyntaxError(const Source: string);
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

function TIdentifierNamesTests.FirstTokenOf(const Source: string): TFirstToken;
begin
  const Lexer = TJSLexer.Create(Source);
  try
    Lexer.Tokenize;

    const Token = Lexer.NextToken;
    Result.TokenType := Token.TokenType;
    Result.Value := Token.Value;
  finally
    Lexer.Free;
  end;
end;

procedure TIdentifierNamesTests.Lexer_EscapedIdentifierStart_ReturnsIdentifierWithDecodedName;
begin
  const Token = FirstTokenOf('\u0061bc');

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual('abc', Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_EscapedIdentifierPart_ReturnsIdentifierWithDecodedName;
begin
  const Token = FirstTokenOf('ab\u0063\u0031');

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual('abc1', Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_EscapedKeyword_IsNotAKeywordToken;
begin
  const Token = FirstTokenOf('i\u0066');

  Assert.AreEqual(TJSTokenType.EscapedKeyword, Token.TokenType);
  Assert.AreEqual('if', Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_EscapedNonReservedWord_IsAnIdentifier;
begin
  const Token = FirstTokenOf('f\u006fo');

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
end;

procedure TIdentifierNamesTests.Lexer_UnicodeCombiningMarkInsideIdentifier_IsPartOfTheName;
begin
  const Source = 'a' + #$0301 + 'b';

  const Token = FirstTokenOf(Source);

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Source, Token.Value);
end;

procedure TIdentifierNamesTests.Variable_DeclaredWithEscape_IsReachableByPlainName;
begin
  FEngine.Execute('var \u0061bc = 5;');

  const Actual = EvaluateNumber('\u0061bc');

  Assert.AreEqual(5.0, Actual);
end;

procedure TIdentifierNamesTests.Variable_ReferencedWithEscape_ReadsPlainName;
begin
  FEngine.Execute('var total = 7;');

  const Actual = EvaluateNumber('tot\u0061l');

  Assert.AreEqual(7.0, Actual);
end;

procedure TIdentifierNamesTests.PropertyName_EscapedKeywordInLiteral_IsAllowed;
begin
  const Actual = EvaluateNumber('({ i\u0066: 42 })["if"]');

  Assert.AreEqual(42.0, Actual);
end;

procedure TIdentifierNamesTests.PropertyName_KeywordInLiteral_IsAllowed;
begin
  const Actual = EvaluateNumber('({ if: 1, var: 2 })["if"]');

  Assert.AreEqual(1.0, Actual);
end;

procedure TIdentifierNamesTests.PropertyName_KeywordAfterDot_IsAllowed;
begin
  const Actual = EvaluateNumber('({ "typeof": 3 }).typeof');

  Assert.AreEqual(3.0, Actual);
end;

procedure TIdentifierNamesTests.PropertyName_EscapedKeywordAfterDot_IsAllowed;
begin
  const Actual = EvaluateNumber('({ "if": 4 }).i\u0066');

  Assert.AreEqual(4.0, Actual);
end;

procedure TIdentifierNamesTests.PropertyName_LiteralsTrueAndNull_AreAllowed;
begin
  const FirstActual = EvaluateNumber('({ true: 5, null: 6 }).true');
  const SecondActual = EvaluateNumber('({ true: 5, null: 6 }).null');

  Assert.AreEqual(5.0, FirstActual);
  Assert.AreEqual(6.0, SecondActual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedKeywordAsVariable_IsSyntaxError;
begin
  const FirstActual = ErrorNameOf('var v\u0061r;');
  const SecondActual = ErrorNameOf('var i\u0066;');

  Assert.AreEqual(SYNTAX_ERROR_NAME, FirstActual);
  Assert.AreEqual(SYNTAX_ERROR_NAME, SecondActual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedKeywordAsExpression_IsSyntaxError;
begin
  const FirstActual = ErrorNameOf('th\u0069s;');
  const SecondActual = ErrorNameOf('var x = typ\u0065of 1;');

  Assert.AreEqual(SYNTAX_ERROR_NAME, FirstActual);
  Assert.AreEqual(SYNTAX_ERROR_NAME, SecondActual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedFutureReservedWord_IsSyntaxError;
begin
  const FirstActual = ErrorNameOf('var cl\u0061ss;');
  const SecondActual = ErrorNameOf('var \u0065num;');

  Assert.AreEqual(SYNTAX_ERROR_NAME, FirstActual);
  Assert.AreEqual(SYNTAX_ERROR_NAME, SecondActual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedStrictReservedWordInStrictCode_IsSyntaxError;
begin
  const Actual = ErrorNameOf('"use strict"; var l\u0065t;');

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedStrictReservedWordInSloppyCode_IsAllowed;
begin
  const Actual = ErrorNameOf('var l\u0065t = 1;');

  Assert.AreEqual('', Actual);
end;

procedure TIdentifierNamesTests.Identifier_EscapedTrue_IsSyntaxError;
begin
  const Actual = ErrorNameOf('var x = tru\u0065;');

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TIdentifierNamesTests.Lexer_CodePointEscapeInIdentifier_ReturnsDecodedName;
begin
  const Token = FirstTokenOf('\u{61}bc');

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual('abc', Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_AstralCodePointEscapeInIdentifier_ReturnsSurrogatePair;
begin
  const Expected = #$D801#$DC00 + 'x';

  const Token = FirstTokenOf('\u{10400}x');

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Expected, Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_InvalidIdentifier_RaisesSyntaxError(const Source: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf(Source);
    end,
    EJSSyntaxError);
end;

procedure TIdentifierNamesTests.Lexer_AstralLetterAtIdentifierStart_IsPartOfTheName;
begin
  const Source = #$D801#$DC00 + 'x';

  const Token = FirstTokenOf(Source);

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Source, Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_AstralDigitInsideIdentifier_IsPartOfTheName;
begin
  const Source = 'a' + #$D835#$DFD8 + 'b';

  const Token = FirstTokenOf(Source);

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Source, Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_OtherIdStartCharacter_StartsAnIdentifier;
begin
  const Source = #$2118 + 'a';

  const Token = FirstTokenOf(Source);

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Source, Token.Value);
end;

procedure TIdentifierNamesTests.Lexer_OtherIdContinueCharacter_ContinuesAnIdentifier;
begin
  const Source = 'a' + #$00B7 + 'b';

  const Token = FirstTokenOf(Source);

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual(Source, Token.Value);
end;

procedure TIdentifierNamesTests.String_CodePointEscape_ProducesCodePoint(const Source: string; const Expected: string);
begin
  const Actual = EvaluateText(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TIdentifierNamesTests.String_InvalidCodePointEscape_IsSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

end.
