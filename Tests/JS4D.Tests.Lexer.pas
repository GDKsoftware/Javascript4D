unit JS4D.Tests.Lexer;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tokens,
  JS4D.Lexer;

type
  [TestFixture]
  TLexerTests = class
  private
    FLexer: TJSLexer;

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

  Assert.AreEqual(TJSTokenType.KeywordVar, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordFunction, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordReturn, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordIf, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordElse, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordWhile, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.KeywordFor, FLexer.NextToken.TokenType);
end;

procedure TLexerTests.Tokenize_Operators_ReturnsOperatorTokens;
begin
  FLexer := TJSLexer.Create('a + b - c * d / e % f');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Plus, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Minus, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Multiply, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Divide, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Modulo, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
end;

procedure TLexerTests.Tokenize_Punctuation_ReturnsPunctuationTokens;
begin
  FLexer := TJSLexer.Create('( ) { } [ ] ; , : .');
  FLexer.Tokenize;

  Assert.AreEqual(TJSTokenType.LeftParen, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.RightParen, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.LeftBrace, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.RightBrace, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.LeftBracket, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.RightBracket, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Semicolon, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Comma, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Colon, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Dot, FLexer.NextToken.TokenType);
end;

procedure TLexerTests.Tokenize_HexNumber_ReturnsCorrectValue;
begin
  FLexer := TJSLexer.Create('0xFF');
  FLexer.Tokenize;

  const Token = FLexer.NextToken;

  Assert.AreEqual(TJSTokenType.NumberLiteral, Token.TokenType);
  Assert.AreEqual(Double(255), Token.NumberValue);
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

  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.PlusAssign, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.MinusAssign, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.MultiplyAssign, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.DivideAssign, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Increment, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Decrement, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Equal, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.StrictEqual, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.NotEqual, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.Identifier, FLexer.NextToken.TokenType);
  Assert.AreEqual(TJSTokenType.StrictNotEqual, FLexer.NextToken.TokenType);
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

initialization
  TDUnitX.RegisterTestFixture(TLexerTests);

end.
