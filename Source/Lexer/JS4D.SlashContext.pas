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
    FParens: TStack<TJSParenKind>;
    FBraceEndsStatement: TStack<Boolean>;
    FPreviousToken: TJSToken;
    FClosedParen: TJSParenKind;
    FPendingFunction: TJSParenKind;
    FRegExpAllowedAfterClose: Boolean;
    FClassDeclarationDepth: Integer;

    function ParenKindForPrevious: TJSParenKind;
    function BraceEndsStatement: Boolean;
    function FunctionKindForPrevious: TJSParenKind;
    function IsStatementBoundary: Boolean;
    procedure OpenParen;
    procedure CloseParen;
    procedure StartClass;
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

const
  NO_CLASS_DECLARATION = -1;

constructor TJSSlashContext.Create;
begin
  inherited Create;
  FClassDeclarationDepth := NO_CLASS_DECLARATION;
  FParens := TStack<TJSParenKind>.Create;
  FBraceEndsStatement := TStack<Boolean>.Create;
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
  FClassDeclarationDepth := NO_CLASS_DECLARATION;
end;

procedure TJSSlashContext.Observe(const Token: TJSToken);
begin
  const TokenType = Token.TokenType;

  case TokenType of
    TJSTokenType.KeywordFunction : FPendingFunction := FunctionKindForPrevious;
    TJSTokenType.KeywordClass    : StartClass;
    TJSTokenType.LeftParen       : OpenParen;
    TJSTokenType.RightParen      : CloseParen;
    TJSTokenType.LeftBrace       : OpenBrace;
    TJSTokenType.RightBrace      : CloseBrace;
  else
    begin
    end;
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

  const EndsTemplate = ((PreviousType = TJSTokenType.TemplateChunk) and FPreviousToken.IsTemplateTail);
  if EndsTemplate then
    Exit(True);

  const IsYieldKeyword = (FPreviousToken.IsIdentifierNamed(YIELD_NAME) and (not FPreviousToken.HasEscape));
  if IsYieldKeyword then
    Exit(False);

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

function TJSSlashContext.IsStatementBoundary: Boolean;
begin
  const HasPrevious = Assigned(FPreviousToken);
  if not HasPrevious then
    Exit(True);

  Result := FPreviousToken.TokenType in [
    TJSTokenType.Semicolon,
    TJSTokenType.LeftBrace,
    TJSTokenType.RightBrace,
    TJSTokenType.KeywordElse,
    TJSTokenType.KeywordDo,
    TJSTokenType.KeywordTry,
    TJSTokenType.KeywordFinally
  ];
end;

function TJSSlashContext.FunctionKindForPrevious: TJSParenKind;
begin
  const FollowsRightParen = (Assigned(FPreviousToken) and (FPreviousToken.TokenType = TJSTokenType.RightParen));
  const StartsStatement = (IsStatementBoundary or FollowsRightParen);

  if StartsStatement then
    Result := TJSParenKind.FunctionDeclaration
  else
    Result := TJSParenKind.FunctionExpression;
end;

function TJSSlashContext.ParenKindForPrevious: TJSParenKind;
begin
  const HasPrevious = Assigned(FPreviousToken);
  const FollowsStatementKeyword = (HasPrevious and (FPreviousToken.TokenType in [
    TJSTokenType.KeywordIf,
    TJSTokenType.KeywordWhile,
    TJSTokenType.KeywordFor,
    TJSTokenType.KeywordWith,
    TJSTokenType.KeywordSwitch,
    TJSTokenType.KeywordCatch
  ]));

  if FollowsStatementKeyword then
    Exit(TJSParenKind.StatementHead);

  Result := FPendingFunction;
end;

procedure TJSSlashContext.OpenParen;
begin
  const Kind = ParenKindForPrevious;
  FParens.Push(Kind);
  FPendingFunction := TJSParenKind.Plain;
end;

procedure TJSSlashContext.CloseParen;
begin
  FClosedParen := TJSParenKind.Plain;

  const HasOpenParen = (FParens.Count > 0);
  if HasOpenParen then
    FClosedParen := FParens.Pop;

  FRegExpAllowedAfterClose := (FClosedParen = TJSParenKind.StatementHead);
end;

function TJSSlashContext.BraceEndsStatement: Boolean;
begin
  const FollowsParen = (Assigned(FPreviousToken) and (FPreviousToken.TokenType = TJSTokenType.RightParen));
  if FollowsParen then
    Exit(FClosedParen in [TJSParenKind.StatementHead, TJSParenKind.FunctionDeclaration]);

  Result := IsStatementBoundary;
end;

procedure TJSSlashContext.StartClass;
begin
  if IsStatementBoundary then
    FClassDeclarationDepth := FParens.Count;
end;

procedure TJSSlashContext.OpenBrace;
begin
  const IsClassBody = (FClassDeclarationDepth = FParens.Count);
  if IsClassBody then
    FClassDeclarationDepth := NO_CLASS_DECLARATION;

  const EndsStatement = (IsClassBody or BraceEndsStatement);
  FBraceEndsStatement.Push(EndsStatement);
end;

procedure TJSSlashContext.CloseBrace;
begin
  FRegExpAllowedAfterClose := False;

  const HasOpenBrace = (FBraceEndsStatement.Count > 0);
  if HasOpenBrace then
    FRegExpAllowedAfterClose := FBraceEndsStatement.Pop;
end;

end.
