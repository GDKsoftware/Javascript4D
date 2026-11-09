unit JS4D.Tests.IdentifierNames;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.Engine;

type
  [TestFixture]
  TIdentifierNamesTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToSyntaxError(const Source: string): Boolean;
    function FirstTokenOf(const Source: string): TJSTokenType;
    function FirstTokenValueOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Lexer_EscapedIdentifierStart_ReturnsIdentifierWithDecodedName;

    [Test]
    procedure Lexer_EscapedIdentifierPart_ReturnsIdentifierWithDecodedName;

    [Test]
    procedure Lexer_EscapedKeyword_IsNotAKeywordToken;

    [Test]
    procedure Lexer_EscapedNonReservedWord_IsAnIdentifier;

    [Test]
    procedure Lexer_BackslashWithoutUnicodeEscape_RaisesSyntaxError;

    [Test]
    procedure Lexer_EscapedDigitAtIdentifierStart_RaisesSyntaxError;

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
    procedure Lexer_IdentifierDirectlyAfterNumber_RaisesSyntaxError;

    [Test]
    procedure Lexer_EscapeInRegularExpressionFlags_RaisesSyntaxError;

    [Test]
    procedure Lexer_VerticalTilde_IsNotAnIdentifierCharacter;
  end;

implementation

function TIdentifierNamesTests.EvaluatesToSyntaxError(const Source: string): Boolean;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const Literal = BackslashesEscaped.Replace('"', '\"');
  const Wrapper = Format('var caught = false; try { eval("%s"); } catch (e) { caught = e instanceof SyntaxError; }',
                         [Literal]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsBoolean;
end;

function TIdentifierNamesTests.FirstTokenOf(const Source: string): TJSTokenType;
begin
  const Lexer = TJSLexer.Create(Source);
  try
    Lexer.Tokenize;
    Result := Lexer.NextToken.TokenType;
  finally
    Lexer.Free;
  end;
end;

function TIdentifierNamesTests.FirstTokenValueOf(const Source: string): string;
begin
  const Lexer = TJSLexer.Create(Source);
  try
    Lexer.Tokenize;
    Result := Lexer.NextToken.Value;
  finally
    Lexer.Free;
  end;
end;

procedure TIdentifierNamesTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TIdentifierNamesTests.TearDown;
begin
  FEngine.Free;
end;

procedure TIdentifierNamesTests.Lexer_EscapedIdentifierStart_ReturnsIdentifierWithDecodedName;
begin
  Assert.AreEqual(TJSTokenType.Identifier, FirstTokenOf('\u0061bc'));
  Assert.AreEqual('abc', FirstTokenValueOf('\u0061bc'));
end;

procedure TIdentifierNamesTests.Lexer_EscapedIdentifierPart_ReturnsIdentifierWithDecodedName;
begin
  Assert.AreEqual(TJSTokenType.Identifier, FirstTokenOf('ab\u0063\u0031'));
  Assert.AreEqual('abc1', FirstTokenValueOf('ab\u0063\u0031'));
end;

procedure TIdentifierNamesTests.Lexer_EscapedKeyword_IsNotAKeywordToken;
begin
  Assert.AreEqual(TJSTokenType.EscapedKeyword, FirstTokenOf('i\u0066'));
  Assert.AreEqual('if', FirstTokenValueOf('i\u0066'));
end;

procedure TIdentifierNamesTests.Lexer_EscapedNonReservedWord_IsAnIdentifier;
begin
  Assert.AreEqual(TJSTokenType.Identifier, FirstTokenOf('f\u006fo'));
end;

procedure TIdentifierNamesTests.Lexer_BackslashWithoutUnicodeEscape_RaisesSyntaxError;
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf('a\x41');
    end,
    EJSSyntaxError);
end;

procedure TIdentifierNamesTests.Lexer_EscapedDigitAtIdentifierStart_RaisesSyntaxError;
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf('\u0031a');
    end,
    EJSSyntaxError);
end;

procedure TIdentifierNamesTests.Lexer_UnicodeCombiningMarkInsideIdentifier_IsPartOfTheName;
begin
  const Source = 'a' + #$0301 + 'b';

  Assert.AreEqual(TJSTokenType.Identifier, FirstTokenOf(Source));
  Assert.AreEqual(Source, FirstTokenValueOf(Source));
end;

procedure TIdentifierNamesTests.Variable_DeclaredWithEscape_IsReachableByPlainName;
begin
  FEngine.Execute('var \u0061bc = 5;');

  Assert.AreEqual(5.0, FEngine.Evaluate('\u0061bc').AsNumber);
end;

procedure TIdentifierNamesTests.Variable_ReferencedWithEscape_ReadsPlainName;
begin
  FEngine.Execute('var total = 7;');

  Assert.AreEqual(7.0, FEngine.Evaluate('tot\u0061l').AsNumber);
end;

procedure TIdentifierNamesTests.PropertyName_EscapedKeywordInLiteral_IsAllowed;
begin
  Assert.AreEqual(42.0, FEngine.Evaluate('({ i\u0066: 42 })["if"]').AsNumber);
end;

procedure TIdentifierNamesTests.PropertyName_KeywordInLiteral_IsAllowed;
begin
  Assert.AreEqual(1.0, FEngine.Evaluate('({ if: 1, var: 2 })["if"]').AsNumber);
end;

procedure TIdentifierNamesTests.PropertyName_KeywordAfterDot_IsAllowed;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('({ "typeof": 3 }).typeof').AsNumber);
end;

procedure TIdentifierNamesTests.PropertyName_EscapedKeywordAfterDot_IsAllowed;
begin
  Assert.AreEqual(4.0, FEngine.Evaluate('({ "if": 4 }).i\u0066').AsNumber);
end;

procedure TIdentifierNamesTests.PropertyName_LiteralsTrueAndNull_AreAllowed;
begin
  Assert.AreEqual(5.0, FEngine.Evaluate('({ true: 5, null: 6 }).true').AsNumber);
  Assert.AreEqual(6.0, FEngine.Evaluate('({ true: 5, null: 6 }).null').AsNumber);
end;

procedure TIdentifierNamesTests.Identifier_EscapedKeywordAsVariable_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('var v\u0061r;'));
  Assert.IsTrue(EvaluatesToSyntaxError('var i\u0066;'));
end;

procedure TIdentifierNamesTests.Identifier_EscapedKeywordAsExpression_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('th\u0069s;'));
  Assert.IsTrue(EvaluatesToSyntaxError('var x = typ\u0065of 1;'));
end;

procedure TIdentifierNamesTests.Identifier_EscapedFutureReservedWord_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('var cl\u0061ss;'));
  Assert.IsTrue(EvaluatesToSyntaxError('var \u0065num;'));
end;

procedure TIdentifierNamesTests.Identifier_EscapedStrictReservedWordInStrictCode_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('"use strict"; var l\u0065t;'));
end;

procedure TIdentifierNamesTests.Identifier_EscapedStrictReservedWordInSloppyCode_IsAllowed;
begin
  Assert.IsFalse(EvaluatesToSyntaxError('var l\u0065t = 1;'));
end;

procedure TIdentifierNamesTests.Identifier_EscapedTrue_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('var x = tru\u0065;'));
end;

procedure TIdentifierNamesTests.Lexer_IdentifierDirectlyAfterNumber_RaisesSyntaxError;
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf('0\u00620');
    end,
    EJSSyntaxError);
end;

procedure TIdentifierNamesTests.Lexer_EscapeInRegularExpressionFlags_RaisesSyntaxError;
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf('/./\u0067');
    end,
    EJSSyntaxError);
end;

procedure TIdentifierNamesTests.Lexer_VerticalTilde_IsNotAnIdentifierCharacter;
begin
  Assert.WillRaise(
    procedure
    begin
      FirstTokenOf('a\u2E2F');
    end,
    EJSSyntaxError);
end;

end.
