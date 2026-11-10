unit JS4D.SlashContext;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.Tokens;

type
  TJSParenKind = (Plain, StatementHead, FunctionDeclaration, FunctionExpression);

  TJSSlashContext = class
  private
    FParens: TList<TJSParenKind>;
    FBraceEndsStatement: TList<Boolean>;
    FPreviousToken: TJSToken;
    FClosedParen: TJSParenKind;
    FPendingFunction: TJSParenKind;
    FRegExpAllowedAfterClose: Boolean;

    function ParenKindFor(const Previous: TJSToken): TJSParenKind;
    function BraceEndsStatement: Boolean;
    function FunctionKindFor(const Previous: TJSToken): TJSParenKind;
    function IsStatementBoundary(const Previous: TJSToken): Boolean;
    procedure OpenParen;
    procedure CloseParen;
    procedure OpenBrace;
    procedure CloseBrace;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Reset;
    procedure Observe(const Token: TJSToken);
    function IsDivisionNext: Boolean;
  end;

implementation

constructor TJSSlashContext.Create;
begin
  inherited Create;
  FParens := TList<TJSParenKind>.Create;
  FBraceEndsStatement := TList<Boolean>.Create;
end;

destructor TJSSlashContext.Destroy;
begin
  FBraceEndsStatement.Free;
  FParens.Free;
  inherited Destroy;
end;

procedure TJSSlashContext.Reset;
begin
  FParens.Clear;
  FBraceEndsStatement.Clear;
  FPreviousToken := nil;
  FClosedParen := TJSParenKind.Plain;
  FPendingFunction := TJSParenKind.Plain;
  FRegExpAllowedAfterClose := False;
end;

procedure TJSSlashContext.Observe(const Token: TJSToken);
begin
  const TokenType = Token.TokenType;

  if TokenType = TJSTokenType.KeywordFunction then
  begin
    FPendingFunction := FunctionKindFor(FPreviousToken);
  end
  else if TokenType = TJSTokenType.LeftParen then
  begin
    OpenParen;
  end
  else if TokenType = TJSTokenType.RightParen then
  begin
    CloseParen;
  end
  else if TokenType = TJSTokenType.LeftBrace then
  begin
    OpenBrace;
  end
  else if TokenType = TJSTokenType.RightBrace then
  begin
    CloseBrace;
  end;

  FPreviousToken := Token;
end;

function TJSSlashContext.IsDivisionNext: Boolean;
begin
  const HasPrevious = Assigned(FPreviousToken);
  if not HasPrevious then
    Exit(False);

  const PreviousType = FPreviousToken.TokenType;

  const EndsGroup = (PreviousType in [TJSTokenType.RightParen, TJSTokenType.RightBrace]);
  if EndsGroup then
    Exit(not FRegExpAllowedAfterClose);

  const EndsTemplate = (PreviousType = TJSTokenType.TemplateChunk) and FPreviousToken.IsTemplateTail;
  if EndsTemplate then
    Exit(True);

  Result := PreviousType in [
    TJSTokenType.Identifier,
    TJSTokenType.NumberLiteral,
    TJSTokenType.StringLiteral,
    TJSTokenType.BooleanLiteral,
    TJSTokenType.NullLiteral,
    TJSTokenType.RegExpLiteral,
    TJSTokenType.RightBracket,
    TJSTokenType.Increment,
    TJSTokenType.Decrement,
    TJSTokenType.KeywordThis
  ];
end;

function TJSSlashContext.IsStatementBoundary(const Previous: TJSToken): Boolean;
begin
  const HasPrevious = Assigned(Previous);
  if not HasPrevious then
    Exit(True);

  Result := Previous.TokenType in [
    TJSTokenType.Semicolon,
    TJSTokenType.LeftBrace,
    TJSTokenType.RightBrace,
    TJSTokenType.KeywordElse,
    TJSTokenType.KeywordDo,
    TJSTokenType.KeywordTry,
    TJSTokenType.KeywordFinally
  ];
end;

function TJSSlashContext.FunctionKindFor(const Previous: TJSToken): TJSParenKind;
begin
  const FollowsRightParen = Assigned(Previous) and (Previous.TokenType = TJSTokenType.RightParen);
  const StartsStatement = IsStatementBoundary(Previous) or FollowsRightParen;

  if StartsStatement then
    Result := TJSParenKind.FunctionDeclaration
  else
    Result := TJSParenKind.FunctionExpression;
end;

function TJSSlashContext.ParenKindFor(const Previous: TJSToken): TJSParenKind;
begin
  const HasPrevious = Assigned(Previous);
  const FollowsStatementKeyword = HasPrevious and (Previous.TokenType in [
    TJSTokenType.KeywordIf,
    TJSTokenType.KeywordWhile,
    TJSTokenType.KeywordFor,
    TJSTokenType.KeywordWith,
    TJSTokenType.KeywordSwitch,
    TJSTokenType.KeywordCatch
  ]);

  if FollowsStatementKeyword then
    Exit(TJSParenKind.StatementHead);

  Result := FPendingFunction;
end;

procedure TJSSlashContext.OpenParen;
begin
  const Kind = ParenKindFor(FPreviousToken);
  FParens.Add(Kind);
  FPendingFunction := TJSParenKind.Plain;
end;

procedure TJSSlashContext.CloseParen;
begin
  FClosedParen := TJSParenKind.Plain;

  const HasOpenParen = (FParens.Count > 0);
  if HasOpenParen then
  begin
    FClosedParen := FParens.Last;
    FParens.Delete(FParens.Count - 1);
  end;

  FRegExpAllowedAfterClose := (FClosedParen = TJSParenKind.StatementHead);
end;

function TJSSlashContext.BraceEndsStatement: Boolean;
begin
  const FollowsParen = Assigned(FPreviousToken) and (FPreviousToken.TokenType = TJSTokenType.RightParen);
  if FollowsParen then
    Exit(FClosedParen in [TJSParenKind.StatementHead, TJSParenKind.FunctionDeclaration]);

  Result := IsStatementBoundary(FPreviousToken);
end;

procedure TJSSlashContext.OpenBrace;
begin
  const EndsStatement = BraceEndsStatement;
  FBraceEndsStatement.Add(EndsStatement);
end;

procedure TJSSlashContext.CloseBrace;
begin
  FRegExpAllowedAfterClose := False;

  const HasOpenBrace = (FBraceEndsStatement.Count > 0);
  if HasOpenBrace then
  begin
    FRegExpAllowedAfterClose := FBraceEndsStatement.Last;
    FBraceEndsStatement.Delete(FBraceEndsStatement.Count - 1);
  end;
end;

end.
