unit JS4D.ParserLookahead;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.ParserRules;

type
  TJSLookahead = class
  private
    FLexer: TJSLexer;

    function CurrentToken: TJSToken;
    function Check(const TokenType: TJSTokenType): Boolean;
    function FindClosingParenthesisOffset(const OpenOffset: Integer): Integer;
    function StartsArrowAfterParenthesis(const OpenOffset: Integer): Boolean;
    function StartsParenthesizedArrow: Boolean;

  public
    constructor Create(const Lexer: TJSLexer);

    class function IsContextualWord(const Token: TJSToken; const Name: string): Boolean; static;

    function PeekType(const Offset: Integer): TJSTokenType;
    function IsAsyncWord: Boolean;
    function IsOfWord: Boolean;
    function IsAsyncOfHead: Boolean;
    function StartsLabel: Boolean;
    function LabelsIterationStatement: Boolean;
    function StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
    function StartsStaticModifier: Boolean;
    function StartsAccessorProperty: Boolean;
    function StartsAsyncModifier: Boolean;
    function StartsAsyncFunction: Boolean;
    function StartsAsyncArrowFunction: Boolean;
    function StartsArrowFunction: Boolean;
    function StartsYieldOperand: Boolean;
  end;

implementation

const
  NO_CLOSING_PARENTHESIS = -1;
  OPENING_TOKENS = [TJSTokenType.LeftParen, TJSTokenType.LeftBracket, TJSTokenType.LeftBrace];
  CLOSING_TOKENS = [TJSTokenType.RightParen, TJSTokenType.RightBracket, TJSTokenType.RightBrace];
  PATTERN_START_TOKENS = [TJSTokenType.LeftBracket, TJSTokenType.LeftBrace];
  PARAMETER_EXPRESSION_TOKENS = [TJSTokenType.Assign, TJSTokenType.Ellipsis];
  MEMBER_NAME_END_TOKENS = [TJSTokenType.LeftParen, TJSTokenType.Assign, TJSTokenType.RightBrace];
  ACCESSOR_NAME_END_TOKENS = MEMBER_NAME_END_TOKENS + [TJSTokenType.Colon, TJSTokenType.Comma];
  STATIC_NAME_END_TOKENS = MEMBER_NAME_END_TOKENS + [TJSTokenType.Semicolon];
  ASYNC_NAME_END_TOKENS = ACCESSOR_NAME_END_TOKENS + [TJSTokenType.Semicolon];
  EXPRESSION_END_TOKENS = [TJSTokenType.RightParen, TJSTokenType.RightBracket, TJSTokenType.RightBrace,
                           TJSTokenType.Comma, TJSTokenType.Semicolon, TJSTokenType.Colon,
                           TJSTokenType.EndOfFile, TJSTokenType.KeywordIn];
  LABELLED_LOOP_TOKENS = [TJSTokenType.KeywordFor, TJSTokenType.KeywordWhile, TJSTokenType.KeywordDo];

constructor TJSLookahead.Create(const Lexer: TJSLexer);
begin
  inherited Create;
  FLexer := Lexer;
end;

class function TJSLookahead.IsContextualWord(const Token: TJSToken; const Name: string): Boolean;
begin
  Result := (Token.IsIdentifierNamed(Name) and (not Token.HasEscape));
end;

function TJSLookahead.CurrentToken: TJSToken;
begin
  Result := FLexer.CurrentToken;
end;

function TJSLookahead.Check(const TokenType: TJSTokenType): Boolean;
begin
  Result := (CurrentToken.TokenType = TokenType);
end;

function TJSLookahead.PeekType(const Offset: Integer): TJSTokenType;
begin
  Result := FLexer.PeekToken(Offset).TokenType;
end;

function TJSLookahead.IsAsyncWord: Boolean;
begin
  Result := IsContextualWord(CurrentToken, ASYNC_NAME);
end;

function TJSLookahead.IsOfWord: Boolean;
begin
  Result := IsContextualWord(CurrentToken, OF_NAME);
end;

function TJSLookahead.IsAsyncOfHead: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const IsFollowedByOf = IsContextualWord(FLexer.PeekToken(1), OF_NAME);
  const IsArrowParameter = (PeekType(2) = TJSTokenType.Arrow);

  Result := (IsFollowedByOf and (not IsArrowParameter));
end;

function TJSLookahead.StartsLabel: Boolean;
begin
  Result := (Check(TJSTokenType.Identifier) and (PeekType(1) = TJSTokenType.Colon));
end;

function TJSLookahead.LabelsIterationStatement: Boolean;
begin
  var Offset := 0;

  while (PeekType(Offset) = TJSTokenType.Identifier) and (PeekType(Offset + 1) = TJSTokenType.Colon) do
  begin
    Inc(Offset, 2);
  end;

  Result := (PeekType(Offset) in LABELLED_LOOP_TOKENS);
end;

function TJSLookahead.StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
begin
  if not IsContextualWord(CurrentToken, LET_NAME) then
    Exit(False);

  const FollowingToken = FLexer.PeekToken(1);
  const IsAllowedPosition = (AllowLineBreak or (FollowingToken.Line = CurrentToken.Line));
  const FollowedByBinding = (FollowingToken.TokenType in [TJSTokenType.Identifier, TJSTokenType.LeftBrace]);
  const FollowedByPattern = (FollowingToken.TokenType = TJSTokenType.LeftBracket);

  Result := (FollowedByPattern or (FollowedByBinding and IsAllowedPosition));
end;

function TJSLookahead.StartsStaticModifier: Boolean;
begin
  if not IsContextualWord(CurrentToken, STATIC_NAME) then
    Exit(False);

  Result := not (PeekType(1) in STATIC_NAME_END_TOKENS);
end;

function TJSLookahead.StartsAccessorProperty: Boolean;
begin
  const IsGetOrSet = (IsContextualWord(CurrentToken, KEYWORD_GET) or IsContextualWord(CurrentToken, KEYWORD_SET));
  if not IsGetOrSet then
    Exit(False);

  Result := not (PeekType(1) in ACCESSOR_NAME_END_TOKENS);
end;

function TJSLookahead.StartsAsyncModifier: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);
  const EndsMemberName = (NextToken.TokenType in ASYNC_NAME_END_TOKENS);

  Result := ((not EndsMemberName) and (not NextToken.LineTerminatorBefore));
end;

function TJSLookahead.StartsAsyncFunction: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);

  Result := ((NextToken.TokenType = TJSTokenType.KeywordFunction) and (not NextToken.LineTerminatorBefore));
end;

function TJSLookahead.StartsAsyncArrowFunction: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);
  if NextToken.LineTerminatorBefore then
    Exit(False);

  case NextToken.TokenType of
    TJSTokenType.Identifier:
      Result := (PeekType(2) = TJSTokenType.Arrow);
    TJSTokenType.LeftParen:
      Result := StartsArrowAfterParenthesis(1);
  else
    Result := False;
  end;
end;

function TJSLookahead.FindClosingParenthesisOffset(const OpenOffset: Integer): Integer;
begin
  var Depth := 0;
  var Offset := OpenOffset;

  while True do
  begin
    const TokenType = PeekType(Offset);
    if TokenType = TJSTokenType.EndOfFile then
      Exit(NO_CLOSING_PARENTHESIS);

    if TokenType in OPENING_TOKENS then
      Inc(Depth)
    else if TokenType in CLOSING_TOKENS then
      Dec(Depth);

    if Depth = 0 then
      Exit(Offset);

    Inc(Offset);
  end;
end;

function TJSLookahead.StartsArrowAfterParenthesis(const OpenOffset: Integer): Boolean;
begin
  const ClosingOffset = FindClosingParenthesisOffset(OpenOffset);
  const HasClosingParenthesis = (ClosingOffset <> NO_CLOSING_PARENTHESIS);

  Result := (HasClosingParenthesis and (PeekType(ClosingOffset + 1) = TJSTokenType.Arrow));
end;

function TJSLookahead.StartsParenthesizedArrow: Boolean;
begin
  var Offset := 1;

  while PeekType(Offset) = TJSTokenType.Identifier do
  begin
    Inc(Offset);

    const HasParameterExpression = (PeekType(Offset) in PARAMETER_EXPRESSION_TOKENS);
    if HasParameterExpression then
    begin
      Result := StartsArrowAfterParenthesis(0);
      Exit;
    end;

    const HasMoreParameters = (PeekType(Offset) = TJSTokenType.Comma);
    if not HasMoreParameters then
      Break;

    Inc(Offset);
  end;

  const FollowingType = PeekType(Offset);
  const NeedsFullScan = ((FollowingType = TJSTokenType.Ellipsis) or (FollowingType in PATTERN_START_TOKENS));
  if NeedsFullScan then
  begin
    Result := StartsArrowAfterParenthesis(0);
    Exit;
  end;

  Result := ((FollowingType = TJSTokenType.RightParen) and (PeekType(Offset + 1) = TJSTokenType.Arrow));
end;

function TJSLookahead.StartsArrowFunction: Boolean;
begin
  case CurrentToken.TokenType of
    TJSTokenType.Identifier:
      Result := (PeekType(1) = TJSTokenType.Arrow);
    TJSTokenType.LeftParen:
      Result := StartsParenthesizedArrow;
  else
    Result := False;
  end;
end;

function TJSLookahead.StartsYieldOperand: Boolean;
begin
  if CurrentToken.LineTerminatorBefore then
    Exit(False);

  const EndsExpression = (CurrentToken.TokenType in EXPRESSION_END_TOKENS);
  const ContinuesTemplate = (Check(TJSTokenType.TemplateChunk) and (not CurrentToken.IsTemplateHead));

  Result := not (EndsExpression or ContinuesTemplate);
end;

end.
