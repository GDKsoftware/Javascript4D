unit JS4D.Tests.Lexer;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Errors,
  JS4D.Tokens,
  JS4D.Lexer;

type
  [TestFixture]
  TLexerTests = class
  private
    FLexer: TJSLexer;

    function NextTokenType: TJSTokenType;

  public
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Tokenize_NumberLiteral_ReturnsNumberToken;

    [Test]
    procedure Tokenize_StringLiteral_ReturnsStringToken;

    [Test]
    procedure Tokenize_Identifier_ReturnsIdentifierToken;

    [Test]
    procedure Tokenize_Keywords_ReturnsKeywordTokens;

    [Test]
    procedure Tokenize_Operators_ReturnsOperatorTokens;

    [Test]
    procedure Tokenize_Punctuation_ReturnsPunctuationTokens;

    [Test]
    procedure Tokenize_HexNumber_ReturnsCorrectValue;

    [Test]
    [TestCase('Binary lower', '0b101,5')]
    [TestCase('Binary upper', '0B11,3')]
    [TestCase('Binary leading zeros', '0b0011,3')]
    [TestCase('Octal lower', '0o17,15')]
    [TestCase('Octal upper', '0O777,511')]
    procedure Tokenize_RadixPrefixedNumber_ReturnsCorrectValue(const Source: string; const Expected: Integer);

    [Test]
    [TestCase('Binary without digits', '0b')]
    [TestCase('Binary with invalid digit', '0b12')]
    [TestCase('Octal without digits', '0o')]
    [TestCase('Octal with invalid digit', '0o8')]
    procedure Tokenize_InvalidRadixPrefixedNumber_RaisesSyntaxError(const Source: string);

    [Test]
    procedure Tokenize_FloatNumber_ReturnsCorrectValue;

    [Test]
    procedure Tokenize_EscapeSequences_ReturnsCorrectString;

    [Test]
    procedure Tokenize_SingleLineComment_SkipsComment;

    [Test]
    procedure Tokenize_MultiLineComment_SkipsComment;

    [Test]
    procedure Tokenize_CompoundOperators_ReturnsCorrectTokens;

    [Test]
    procedure Tokenize_BooleanLiterals_ReturnsBooleanTokens;

    [Test]
    procedure Tokenize_NullLiteral_ReturnsNullToken;
  end;

implementation

procedure TLexerTests.TearDown;
begin
  FLexer.Free;
end;

function TLexerTests.NextTokenType: TJSTokenType;
begin
  const Token = FLexer.NextToken;

  Result := Token.TokenType;
end;

procedure TLexerTests.Tokenize_NumberLiteral_ReturnsNumberToken;
begin
  FLexer := TJSLexer.Create('42');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NumberLiteral, Token.TokenType);
  Assert.AreEqual(Double(42), Token.NumberValue);
end;

procedure TLexerTests.Tokenize_StringLiteral_ReturnsStringToken;
begin
  FLexer := TJSLexer.Create('"Hello, World!"');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.StringLiteral, Token.TokenType);
  Assert.AreEqual('Hello, World!', Token.Value);
end;

procedure TLexerTests.Tokenize_Identifier_ReturnsIdentifierToken;
begin
  FLexer := TJSLexer.Create('myVariable');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.Identifier, Token.TokenType);
  Assert.AreEqual('myVariable', Token.Value);
end;

procedure TLexerTests.Tokenize_Keywords_ReturnsKeywordTokens;
begin
  FLexer := TJSLexer.Create('var function return if else while for');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.KeywordVar, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordFunction, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordReturn, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordIf, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordElse, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordWhile, NextTokenType);
  Assert.AreEqual(TJSTokenType.KeywordFor, NextTokenType);
end;

procedure TLexerTests.Tokenize_Operators_ReturnsOperatorTokens;
begin
  FLexer := TJSLexer.Create('a + b - c * d / e % f');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Plus, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Minus, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Multiply, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Divide, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Modulo, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
end;

procedure TLexerTests.Tokenize_Punctuation_ReturnsPunctuationTokens;
begin
  FLexer := TJSLexer.Create('( ) { } [ ] ; , : .');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.LeftParen, NextTokenType);
  Assert.AreEqual(TJSTokenType.RightParen, NextTokenType);
  Assert.AreEqual(TJSTokenType.LeftBrace, NextTokenType);
  Assert.AreEqual(TJSTokenType.RightBrace, NextTokenType);
  Assert.AreEqual(TJSTokenType.LeftBracket, NextTokenType);
  Assert.AreEqual(TJSTokenType.RightBracket, NextTokenType);
  Assert.AreEqual(TJSTokenType.Semicolon, NextTokenType);
  Assert.AreEqual(TJSTokenType.Comma, NextTokenType);
  Assert.AreEqual(TJSTokenType.Colon, NextTokenType);
  Assert.AreEqual(TJSTokenType.Dot, NextTokenType);
end;

procedure TLexerTests.Tokenize_HexNumber_ReturnsCorrectValue;
begin
  FLexer := TJSLexer.Create('0xFF');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NumberLiteral, Token.TokenType);
  Assert.AreEqual(Double(255), Token.NumberValue);
end;

procedure TLexerTests.Tokenize_RadixPrefixedNumber_ReturnsCorrectValue(const Source: string; const Expected: Integer);
begin
  FLexer := TJSLexer.Create(Source);
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NumberLiteral, Token.TokenType);
  Assert.AreEqual(Double(Expected), Token.NumberValue);
end;

procedure TLexerTests.Tokenize_InvalidRadixPrefixedNumber_RaisesSyntaxError(const Source: string);
begin
  FLexer := TJSLexer.Create(Source);

  Assert.WillRaise(
    procedure
    begin
      FLexer.Tokenize;
    end,
    EJSSyntaxError);
end;

procedure TLexerTests.Tokenize_FloatNumber_ReturnsCorrectValue;
begin
  FLexer := TJSLexer.Create('3.14159');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NumberLiteral, Token.TokenType);
  Assert.AreEqual(3.14159, Token.NumberValue, 0.00001);
end;

procedure TLexerTests.Tokenize_EscapeSequences_ReturnsCorrectString;
begin
  FLexer := TJSLexer.Create('"Hello\nWorld"');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.StringLiteral, Token.TokenType);
  Assert.AreEqual('Hello'#10'World', Token.Value);
end;

procedure TLexerTests.Tokenize_SingleLineComment_SkipsComment;
begin
  FLexer := TJSLexer.Create('42 // this is a comment' + #10 + '43');
  FLexer.Tokenize;

  var Token := FLexer.NextToken;
  Assert.AreEqual(Double(42), Token.NumberValue);

  Token := FLexer.NextToken;
  Assert.AreEqual(Double(43), Token.NumberValue);
end;

procedure TLexerTests.Tokenize_MultiLineComment_SkipsComment;
begin
  FLexer := TJSLexer.Create('42 /* this is a' + #10 + 'multi-line comment */ 43');
  FLexer.Tokenize;

  var Token := FLexer.NextToken;
  Assert.AreEqual(Double(42), Token.NumberValue);

  Token := FLexer.NextToken;
  Assert.AreEqual(Double(43), Token.NumberValue);
end;

procedure TLexerTests.Tokenize_CompoundOperators_ReturnsCorrectTokens;
begin
  FLexer := TJSLexer.Create('a += b -= c *= d /= e ++ f -- g == h === i != j !==');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.PlusAssign, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.MinusAssign, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.MultiplyAssign, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.DivideAssign, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Increment, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Decrement, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.Equal, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.StrictEqual, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.NotEqual, NextTokenType);
  Assert.AreEqual(TJSTokenType.Identifier, NextTokenType);
  Assert.AreEqual(TJSTokenType.StrictNotEqual, NextTokenType);
end;

procedure TLexerTests.Tokenize_BooleanLiterals_ReturnsBooleanTokens;
begin
  FLexer := TJSLexer.Create('true false');
  FLexer.Tokenize;

  var Token := FLexer.NextToken;
  Assert.AreEqual(TJSTokenType.BooleanLiteral, Token.TokenType);
  Assert.AreEqual('true', Token.Value);

  Token := FLexer.NextToken;
  Assert.AreEqual(TJSTokenType.BooleanLiteral, Token.TokenType);
  Assert.AreEqual('false', Token.Value);
end;

procedure TLexerTests.Tokenize_NullLiteral_ReturnsNullToken;
begin
  FLexer := TJSLexer.Create('null');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NullLiteral, Token.TokenType);
end;

end.
