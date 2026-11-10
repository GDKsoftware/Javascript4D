unit JS4D.Parser;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.AST,
  JS4D.ParserScope,
  JS4D.Errors,
  JS4D.RegExpSyntax;

type
  TJSLabelInfo = record
    Name: string;
    LabelsIteration: Boolean;
  end;

  TJSParser = class
  private
    FLexer: TJSLexer;
    FOwnsLexer: Boolean;
    FPreviousTokenLine: Integer;
    FStrictMode: Boolean;
    FInOperatorAllowed: Boolean;
    FActiveLabels: TList<TJSLabelInfo>;
    FLabelScopeStart: Integer;
    FLoopDepth: Integer;
    FSwitchDepth: Integer;
    FFunctionDepth: Integer;
    FScopes: TJSScopeTracker;
    FClosureCount: Integer;
    FAllowLabelledFunction: Boolean;

    function CurrentToken: TJSToken;
    procedure Advance;
    function Match(const TokenType: TJSTokenType): Boolean;
    function Check(const TokenType: TJSTokenType): Boolean;
    function CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
    procedure Expect(const TokenType: TJSTokenType);
    procedure ExpectSemicolon;
    function IsAtEnd: Boolean;

    function ParseProgram: TJSProgram;
    function ParseStatement: TJSStatement;
    function ParseStatementListItem: TJSStatement;
    function ParseBlockStatement: TJSBlockStatement;
    function ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                              const CatchParameter: string): TJSBlockStatement;
    function ParseVariableDeclaration: TJSVariableDeclaration;
    function ParseLexicalDeclaration: TJSVariableDeclaration;
    procedure ParseLexicalBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean;
                                  const RequireInitializer: Boolean);
    function ParseLexicalForStatement: TJSStatement;
    function ParseLexicalForHeadAndBody(const Declaration: TJSVariableDeclaration): TJSStatement;
    function ParseIfBranch: TJSStatement;
    function StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
    procedure DeclareVarName(const Name: string);
    procedure DeclareLexicalName(const Name: string; const IsFunction: Boolean; const AllowFunctionDuplicate: Boolean);
    procedure CheckLexicalBindingName(const Name: string);
    function ParseFunctionDeclaration: TJSFunctionDeclaration;
    function ParseExpressionStatement: TJSExpressionStatement;
    function ParseIfStatement: TJSIfStatement;
    function ParseWhileStatement: TJSWhileStatement;
    function ParseDoWhileStatement: TJSDoWhileStatement;
    function ParseLoopBody(const Owned: array of TObject): TJSStatement;
    procedure RejectFunctionDeclarationBody(const Owned: array of TObject);
    procedure FreeOwned(const Owned: array of TObject);
    function ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
    function LabelsIterationStatement: Boolean;
    function FindActiveLabel(const LabelName: string): Integer;
    function ParseJumpLabel(const KeywordToken: TJSToken): string;
    function ParseWithStatement: TJSWithStatement;
    function ParseWithBody: TJSStatement;
    function StartsWithDeclaration: Boolean;
    function ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>): TJSBlockStatement;
    function PrologueDeclaresStrictMode(const FirstTokenOffset: Integer): Boolean;
    procedure RejectLegacyLiteralInStrictMode(const Token: TJSToken);
    function ParseForStatement: TJSStatement;
    function ParseReturnStatement: TJSReturnStatement;
    function ParseBreakStatement: TJSBreakStatement;
    function ParseContinueStatement: TJSContinueStatement;
    function ParseSwitchStatement: TJSSwitchStatement;
    function ParseThrowStatement: TJSThrowStatement;
    function ParseTryStatement: TJSTryStatement;
    function ParseCatchClause: TJSCatchClause;
    function ParseEmptyStatement: TJSEmptyStatement;
    function ParseDebuggerStatement: TJSDebuggerStatement;

    function ParseExpression: TJSExpression;
    function ParseAssignmentExpression: TJSExpression;
    function ParseExpressionWithoutIn: TJSExpression;
    function ParseNestedExpression: TJSExpression;
    function ParseNestedAssignmentExpression: TJSExpression;
    function ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement;
    function ParseConditionalExpression: TJSExpression;
    function ParseLogicalOrExpression: TJSExpression;
    function ParseLogicalAndExpression: TJSExpression;
    function ParseBitwiseOrExpression: TJSExpression;
    function ParseBitwiseXorExpression: TJSExpression;
    function ParseBitwiseAndExpression: TJSExpression;
    function ParseEqualityExpression: TJSExpression;
    function ParseRelationalExpression: TJSExpression;
    function ParseShiftExpression: TJSExpression;
    function ParseAdditiveExpression: TJSExpression;
    function ParseMultiplicativeExpression: TJSExpression;
    function ParseUnaryExpression: TJSExpression;
    function ParseUpdateExpression: TJSExpression;
    function ParseCallExpression: TJSExpression;
    function ParseIdentifierName: TJSIdentifier;
    function ParseMemberExpression: TJSExpression;
    function ParseNewExpression: TJSExpression;
    function IsTemplateStart: Boolean;
    function ParseTemplateLiteral: TJSTemplateLiteral;
    function ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
    procedure ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
                                const Expressions: TObjectList<TJSExpression>);
    function CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
    function ParsePrimaryExpression: TJSExpression;
    function ParseArrayExpression: TJSArrayExpression;
    function ParseObjectExpression: TJSObjectExpression;
    function ParseObjectMember: TJSObjectProperty;
    function ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
    function ParseMethodProperty(const Key: TJSExpression; const Computed: Boolean): TJSObjectProperty;
    function StartsAccessorProperty: Boolean;
    function ParsePropertyKey(out Computed: Boolean): TJSExpression;
    function ParseAccessorProperty: TJSObjectProperty;
    function ParseAccessorFunction(const Kind: TJSPropertyKind): TJSFunctionExpression;
    function ParseFunctionExpression: TJSFunctionExpression;
    procedure ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression);
    function StartsArrowFunction: Boolean;
    function ParseArrowFunction: TJSFunctionExpression;
    procedure ParseArrowParameters(const Func: TJSFunctionExpression);
    procedure ParseArrowParameter(const Func: TJSFunctionExpression);
    procedure ParseArrowBody(const Func: TJSFunctionExpression);
    function ParseConciseBody: TJSBlockStatement;
    procedure RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
    function ParseArguments: TObjectList<TJSExpression>;

    function IsAssignmentOperator(const TokenType: TJSTokenType): Boolean;
    function IsRelationalOperator: Boolean;
    function IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
    procedure EnsureAssignmentTarget(const Target: TJSExpression);
    function TokenToAssignmentOperator(const TokenType: TJSTokenType): TJSAssignmentOperator;

    function IsStrictModeReservedWord(const Name: string): Boolean;
    procedure CheckStrictModeReservedWord(const Name: string);
    function IsRestrictedStrictName(const Name: string): Boolean;
    procedure CheckRestrictedBindingName(const Name: string);
    procedure CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>);
    procedure CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
    procedure RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
    procedure CheckRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);

  public
    constructor Create(const Source: string); overload;
    constructor Create(const Lexer: TJSLexer); overload;
    destructor Destroy; override;

    function Parse: TJSProgram; overload;
    function Parse(const IsStrictContext: Boolean): TJSProgram; overload;
  end;

implementation

const
  TRUE_VALUE = 'true';
  USE_STRICT_DIRECTIVE = 'use strict';
  LegacyLiteralInStrictModeMessage = 'Octal literals and escape sequences are not allowed in strict mode';
  ARGUMENTS_NAME = 'arguments';
  EVAL_NAME = 'eval';
  SUPER_NAME = 'super';
  KEYWORD_GET = 'get';
  KEYWORD_SET = 'set';
  ACCESSOR_PARAMETER_COUNT = 'Getter must not have parameters and setter must have exactly one';
  DUPLICATE_PROTOTYPE_MESSAGE = 'Duplicate __proto__ fields are not allowed in object literals';
  RestrictedParameterNameMessage = 'Parameter name ''%s'' is not allowed in strict mode';
  RestrictedBindingNameMessage = '''%s'' cannot be declared in strict mode';
  DeleteIdentifierMessage = 'Delete of an unqualified identifier in strict mode';
  UndefinedLabelMessage = 'Undefined label ''%s''';
  DuplicateLabelMessage = 'Label ''%s'' has already been declared';
  ContinueTargetNotLoopMessage = 'Label ''%s'' does not label an iteration statement';
  IllegalReturnMessage = 'Illegal return statement';
  IllegalThrowNewlineMessage = 'Illegal newline after throw';
  DuplicateDefaultMessage = 'More than one default clause in switch statement';
  FunctionDeclarationBodyMessage = 'Function declaration is not allowed as the body of a statement';
  LexicalDeclarationBodyMessage = 'Lexical declaration cannot appear in a single-statement context';
  RedeclarationMessage = 'Identifier ''%s'' has already been declared';
  MissingConstInitializerMessage = 'Missing initializer in const declaration';
  LetBindingNameMessage = 'let is disallowed as a lexically bound name';
  ForInInitializerMessage = 'for-in loop variable declaration may not have an initializer';
  DuplicateArrowParameterMessage = 'Duplicate parameter name not allowed in arrow functions';
  InvalidTemplateEscapeMessage = 'Invalid escape sequence in template literal';
  LET_NAME = 'let';

{ TJSParser }

constructor TJSParser.Create(const Source: string);
begin
  inherited Create;
  FLexer := TJSLexer.Create(Source);
  FOwnsLexer := True;
  FLexer.Tokenize;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
end;

constructor TJSParser.Create(const Lexer: TJSLexer);
begin
  inherited Create;
  FLexer := Lexer;
  FOwnsLexer := False;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
end;

destructor TJSParser.Destroy;
begin
  FScopes.Free;
  FActiveLabels.Free;

  if FOwnsLexer then
    FLexer.Free;

  inherited;
end;

function TJSParser.CurrentToken: TJSToken;
begin
  Result := FLexer.CurrentToken;
end;

procedure TJSParser.Advance;
begin
  FPreviousTokenLine := CurrentToken.Line;
  FLexer.NextToken;
end;

function TJSParser.Match(const TokenType: TJSTokenType): Boolean;
begin
  Result := Check(TokenType);

  if Result then
    Advance;
end;

function TJSParser.Check(const TokenType: TJSTokenType): Boolean;
begin
  Result := (CurrentToken.TokenType = TokenType);
end;

function TJSParser.CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
begin
  for var TokenType in TokenTypes do
  begin
    if Check(TokenType) then
      Exit(True);
  end;

  Result := False;
end;

procedure TJSParser.Expect(const TokenType: TJSTokenType);
begin
  if not Match(TokenType) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.ExpectSemicolon;
begin
  if Match(TJSTokenType.Semicolon) then
    Exit;

  const CanInsertSemicolon = (Check(TJSTokenType.RightBrace) or
                              Check(TJSTokenType.EndOfFile) or
                              CurrentToken.LineTerminatorBefore);
  if not CanInsertSemicolon then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.IsAtEnd: Boolean;
begin
  Result := Check(TJSTokenType.EndOfFile);
end;

function TJSParser.Parse: TJSProgram;
begin
  Result := ParseProgram;
end;

function TJSParser.Parse(const IsStrictContext: Boolean): TJSProgram;
begin
  FStrictMode := IsStrictContext;
  Result := ParseProgram;
end;

function TJSParser.ParseProgram: TJSProgram;
begin
  Result := TJSProgram.Create;
  FScopes.Enter(TJSParserScopeKind.Function_, nil);
  const ClosureMark = FClosureCount;

  try
    if PrologueDeclaresStrictMode(0) then
    begin
      FStrictMode := True;
      Result.IsStrict := True;
    end;

    while not IsAtEnd do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Result.ScopeInfo := FScopes.Leave;
  except
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

function TJSParser.ParseStatementListItem: TJSStatement;
begin
  if Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(True) then
    Exit(ParseLexicalDeclaration);

  FAllowLabelledFunction := True;
  Result := ParseStatement;
end;

function TJSParser.ParseStatement: TJSStatement;
begin
  const AllowLabelledFunction = FAllowLabelledFunction;
  FAllowLabelledFunction := False;

  const StartsLexicalDeclaration = (Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(False));
  if StartsLexicalDeclaration then
    raise TJSErrorFactory.SyntaxError(LexicalDeclarationBodyMessage, CurrentToken.Line, CurrentToken.Column);

  const StartsLabel = (Check(TJSTokenType.Identifier) and
                       (FLexer.PeekToken(1).TokenType = TJSTokenType.Colon));
  if StartsLabel then
  begin
    Result := ParseLabeledStatement(AllowLabelledFunction);
    Exit;
  end;

  case CurrentToken.TokenType of
    TJSTokenType.LeftBrace:
      Result := ParseBlockStatement;
    TJSTokenType.KeywordVar:
      Result := ParseVariableDeclaration;
    TJSTokenType.KeywordFunction:
      Result := ParseFunctionDeclaration;
    TJSTokenType.KeywordIf:
      Result := ParseIfStatement;
    TJSTokenType.KeywordWhile:
      Result := ParseWhileStatement;
    TJSTokenType.KeywordDo:
      Result := ParseDoWhileStatement;
    TJSTokenType.KeywordWith:
      Result := ParseWithStatement;
    TJSTokenType.KeywordFor:
      Result := ParseForStatement;
    TJSTokenType.KeywordReturn:
      Result := ParseReturnStatement;
    TJSTokenType.KeywordBreak:
      Result := ParseBreakStatement;
    TJSTokenType.KeywordContinue:
      Result := ParseContinueStatement;
    TJSTokenType.KeywordSwitch:
      Result := ParseSwitchStatement;
    TJSTokenType.KeywordThrow:
      Result := ParseThrowStatement;
    TJSTokenType.KeywordTry:
      Result := ParseTryStatement;
    TJSTokenType.Semicolon:
      Result := ParseEmptyStatement;
    TJSTokenType.KeywordDebugger:
      Result := ParseDebuggerStatement;
    else
      Result := ParseExpressionStatement;
  end;
end;

function TJSParser.ParseBlockStatement: TJSBlockStatement;
begin
  Result := ParseScopedBlock(TJSParserScopeKind.Block, nil, '');
end;

function TJSParser.ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                                    const CatchParameter: string): TJSBlockStatement;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := (Kind = TJSParserScopeKind.Function_);
  FScopes.Enter(Kind, Parameters);
  FScopes.SetCatchParameter(CatchParameter);
  const ClosureMark = FClosureCount;

  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Expect(TJSTokenType.RightBrace);
    Result.ScopeInfo := FScopes.Leave;
  except
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

procedure TJSParser.DeclareVarName(const Name: string);
begin
  if not FScopes.TryDeclareVar(Name) then
    raise TJSErrorFactory.SyntaxError(Format(RedeclarationMessage, [Name]), CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.DeclareLexicalName(const Name: string; const IsFunction: Boolean;
                                       const AllowFunctionDuplicate: Boolean);
begin
  if not FScopes.TryDeclareLexical(Name, IsFunction, AllowFunctionDuplicate) then
    raise TJSErrorFactory.SyntaxError(Format(RedeclarationMessage, [Name]), CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.CheckLexicalBindingName(const Name: string);
begin
  if Name = LET_NAME then
    raise TJSErrorFactory.SyntaxError(LetBindingNameMessage, CurrentToken.Line, CurrentToken.Column);

  CheckStrictModeReservedWord(Name);
  CheckRestrictedBindingName(Name);
end;

function TJSParser.StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
begin
  const IsLetWord = (Check(TJSTokenType.Identifier) and (CurrentToken.Value = LET_NAME) and
                     (not CurrentToken.HasEscape));
  if not IsLetWord then
    Exit(False);

  const FollowingToken = FLexer.PeekToken(1);
  const IsAllowedPosition = (AllowLineBreak or (FollowingToken.Line = CurrentToken.Line));
  const FollowedByBinding = (FollowingToken.TokenType in [TJSTokenType.Identifier, TJSTokenType.LeftBrace]);
  const FollowedByPattern = (FollowingToken.TokenType = TJSTokenType.LeftBracket);

  Result := FollowedByPattern or (FollowedByBinding and IsAllowedPosition);
end;

function TJSParser.ParseLexicalDeclaration: TJSVariableDeclaration;
begin
  Result := TJSVariableDeclaration.Create;

  try
    if Check(TJSTokenType.KeywordConst) then
      Result.Kind := TJSDeclarationKind.Const_
    else
      Result.Kind := TJSDeclarationKind.Let;

    Advance;

    repeat
      ParseLexicalBinding(Result, True, Result.Kind = TJSDeclarationKind.Const_);
    until not Match(TJSTokenType.Comma);

    ExpectSemicolon;
    FScopes.AddDeclaration(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseLexicalBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean;
                                        const RequireInitializer: Boolean);
begin
  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const BindingName = CurrentToken.Value;
  CheckLexicalBindingName(BindingName);
  DeclareLexicalName(BindingName, False, False);
  Advance;

  var InitExpr: TJSExpression := nil;

  if Match(TJSTokenType.Assign) then
  begin
    const PreviousAllowed = FInOperatorAllowed;
    FInOperatorAllowed := AllowIn;
    try
      InitExpr := ParseAssignmentExpression;
    finally
      FInOperatorAllowed := PreviousAllowed;
    end;
  end
  else if RequireInitializer then
  begin
    raise TJSErrorFactory.SyntaxError(MissingConstInitializerMessage, CurrentToken.Line, CurrentToken.Column);
  end;

  const Identifier = TJSIdentifier.Create(BindingName);
  const Declarator = TJSVariableDeclarator.Create(Identifier, InitExpr);
  Declaration.Declarations.Add(Declarator);
end;

function TJSParser.ParseVariableDeclaration: TJSVariableDeclaration;
begin
  Expect(TJSTokenType.KeywordVar);

  Result := TJSVariableDeclaration.Create;

  try
    repeat
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const IdName = CurrentToken.Value;
      CheckStrictModeReservedWord(IdName);
      CheckRestrictedBindingName(IdName);
      DeclareVarName(IdName);
      Advance;

      var InitExpr: TJSExpression := nil;

      if Match(TJSTokenType.Assign) then
        InitExpr := ParseAssignmentExpression;

      const Identifier = TJSIdentifier.Create(IdName);
      const Declarator = TJSVariableDeclarator.Create(Identifier, InitExpr);
      Result.Declarations.Add(Declarator);
    until not Match(TJSTokenType.Comma);

    ExpectSemicolon;
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseFunctionDeclaration: TJSFunctionDeclaration;
begin
  Expect(TJSTokenType.KeywordFunction);

  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const FuncName = CurrentToken.Value;
  CheckStrictModeReservedWord(FuncName);

  const IsStrictContext = FStrictMode;
  const IsFunctionLevel = FScopes.IsFunctionLevel;
  if IsFunctionLevel then
    DeclareVarName(FuncName)
  else
    DeclareLexicalName(FuncName, True, not IsStrictContext);

  Advance;
  Inc(FClosureCount);

  const Identifier = TJSIdentifier.Create(FuncName);
  Result := TJSFunctionDeclaration.Create(Identifier);

  try
    Expect(TJSTokenType.LeftParen);

    if not Check(TJSTokenType.RightParen) then
    begin
      repeat
        if not Check(TJSTokenType.Identifier) then
          raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

        const ParamName = CurrentToken.Value;
        CheckStrictModeReservedWord(ParamName);
        Advance;

        const Param = TJSIdentifier.Create(ParamName);
        Result.Params.Add(Param);
      until not Match(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightParen);

    const OldStrictMode = FStrictMode;
    Result.Body := ParseFunctionBodyBlock(Result.Params);

    if Result.Body.DeclaresStrictMode then
    begin
      Result.IsStrict := True;
      FStrictMode := True;
    end;

    CheckStrictFunctionHeader(FuncName, Result.Params);
    FStrictMode := OldStrictMode;
  except
    Result.Free;
    raise;
  end;

  if not IsFunctionLevel then
  begin
    FScopes.AddDeclaration(Result);

    if not IsStrictContext then
      FScopes.AddFunctionCandidate(Result);
  end;
end;

function TJSParser.ParseExpressionStatement: TJSExpressionStatement;
begin
  const Expression = ParseExpression;
  try
    ExpectSemicolon;
  except
    Expression.Free;
    raise;
  end;

  Result := TJSExpressionStatement.Create(Expression);
end;

function TJSParser.ParseIfStatement: TJSIfStatement;
begin
  Expect(TJSTokenType.KeywordIf);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;
  var Consequent: TJSStatement := nil;
  var Alternate: TJSStatement := nil;

  try
    Expect(TJSTokenType.RightParen);

    if FStrictMode then
      RejectFunctionDeclarationBody([]);

    Consequent := ParseIfBranch;

    if Match(TJSTokenType.KeywordElse) then
    begin
      if FStrictMode then
        RejectFunctionDeclarationBody([]);

      Alternate := ParseIfBranch;
    end;
  except
    FreeOwned([Test, Consequent, Alternate]);
    raise;
  end;

  Result := TJSIfStatement.Create(Test, Consequent, Alternate);
end;

function TJSParser.ParseIfBranch: TJSStatement;
begin
  if not Check(TJSTokenType.KeywordFunction) then
    Exit(ParseStatement);

  const Block = TJSBlockStatement.Create;
  FScopes.Enter(TJSParserScopeKind.Block, nil);

  try
    Block.Body.Add(ParseFunctionDeclaration);
    Block.ScopeInfo := FScopes.Leave;
  except
    Block.Free;
    raise;
  end;

  Block.ScopeInfo.MayCaptureScope := True;
  Result := Block;
end;

function TJSParser.ParseWhileStatement: TJSWhileStatement;
begin
  Expect(TJSTokenType.KeywordWhile);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  Expect(TJSTokenType.RightParen);

  const Body = ParseLoopBody([Test]);

  Result := TJSWhileStatement.Create(Test, Body);
end;

function TJSParser.ParseWithStatement: TJSWithStatement;
begin
  if FStrictMode then
    raise TJSErrorFactory.SyntaxError('with statement is not allowed in strict mode',
      CurrentToken.Line, CurrentToken.Column);

  Expect(TJSTokenType.KeywordWith);
  Expect(TJSTokenType.LeftParen);

  const Target = ParseExpression;

  try
    Expect(TJSTokenType.RightParen);

    const Body = ParseWithBody;

    Result := TJSWithStatement.Create(Target, Body);
  except
    Target.Free;
    raise;
  end;
end;

function TJSParser.ParseWithBody: TJSStatement;
begin
  if StartsWithDeclaration then
    raise TJSErrorFactory.SyntaxError('Declaration is not allowed as the body of a with statement',
      CurrentToken.Line, CurrentToken.Column);

  Result := ParseStatement;
end;

function TJSParser.StartsWithDeclaration: Boolean;
begin
  if Check(TJSTokenType.KeywordFunction) or Check(TJSTokenType.KeywordConst) then
    Exit(True);

  if not Check(TJSTokenType.Identifier) then
    Exit(False);

  if StartsLetDeclaration(False) then
    Exit(True);

  const FollowedByName = (FLexer.PeekToken(1).TokenType = TJSTokenType.Identifier);

  Result := (CurrentToken.Value = 'class') and FollowedByName;
end;

function TJSParser.PrologueDeclaresStrictMode(const FirstTokenOffset: Integer): Boolean;
begin
  Result := False;
  var HasLegacyDirective := False;
  var Offset := FirstTokenOffset;

  while True do
  begin
    const DirectiveToken = FLexer.PeekToken(Offset);
    if DirectiveToken.TokenType <> TJSTokenType.StringLiteral then
      Break;

    const EndToken = FLexer.PeekToken(Offset + 1);
    const EndsWithSemicolon = (EndToken.TokenType = TJSTokenType.Semicolon);
    const EndsDirective = (EndsWithSemicolon or
                           (EndToken.TokenType in [TJSTokenType.RightBrace, TJSTokenType.EndOfFile]) or
                           (EndToken.Line <> DirectiveToken.Line));
    if not EndsDirective then
      Break;

    const IsUseStrict = (DirectiveToken.Value = USE_STRICT_DIRECTIVE) and (not DirectiveToken.HasEscape);
    if IsUseStrict then
      Result := True;

    if DirectiveToken.IsLegacyLiteral then
      HasLegacyDirective := True;

    Inc(Offset);
    if EndsWithSemicolon then
      Inc(Offset);
  end;

  if Result and HasLegacyDirective then
    raise TJSErrorFactory.SyntaxError(LegacyLiteralInStrictModeMessage,
      CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.RejectLegacyLiteralInStrictMode(const Token: TJSToken);
begin
  if FStrictMode and Token.IsLegacyLiteral then
    raise TJSErrorFactory.SyntaxError(LegacyLiteralInStrictModeMessage, Token.Line, Token.Column);
end;

function TJSParser.ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>): TJSBlockStatement;
begin
  var ParameterNames: TArray<string>;
  SetLength(ParameterNames, Params.Count);

  for var Index := 0 to Params.Count - 1 do
  begin
    ParameterNames[Index] := Params[Index].Name;
  end;

  const OldStrictMode = FStrictMode;
  const OuterLabelScopeStart = FLabelScopeStart;
  const OuterLoopDepth = FLoopDepth;
  const OuterSwitchDepth = FSwitchDepth;

  Inc(FFunctionDepth);

  const DeclaresStrictMode = Check(TJSTokenType.LeftBrace) and PrologueDeclaresStrictMode(1);
  if DeclaresStrictMode then
    FStrictMode := True;

  FLabelScopeStart := FActiveLabels.Count;
  FLoopDepth := 0;
  FSwitchDepth := 0;
  try
    const StartPosition = FLexer.Position;
    Result := ParseNestedBlockStatement(ParameterNames);
    Result.DeclaresStrictMode := DeclaresStrictMode;
    Result.ReferencesArguments := FLexer.HasIdentifierBetween(StartPosition, FLexer.Position,
                                                              [ARGUMENTS_NAME, EVAL_NAME]);
  finally
    Dec(FFunctionDepth);
    FStrictMode := OldStrictMode;
    FLabelScopeStart := OuterLabelScopeStart;
    FLoopDepth := OuterLoopDepth;
    FSwitchDepth := OuterSwitchDepth;
  end;
end;

function TJSParser.ParseDoWhileStatement: TJSDoWhileStatement;
begin
  Expect(TJSTokenType.KeywordDo);

  const Body = ParseLoopBody([]);

  Expect(TJSTokenType.KeywordWhile);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  Expect(TJSTokenType.RightParen);
  Match(TJSTokenType.Semicolon);

  Result := TJSDoWhileStatement.Create(Body, Test);
end;

function TJSParser.ParseForStatement: TJSStatement;
begin
  Expect(TJSTokenType.KeywordFor);
  Expect(TJSTokenType.LeftParen);

  const IsLexicalHead = (Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(True));
  if IsLexicalHead then
    Exit(ParseLexicalForStatement);

  var Init: TJSASTNode := nil;

  if Check(TJSTokenType.KeywordVar) then
  begin
    Expect(TJSTokenType.KeywordVar);

    if not Check(TJSTokenType.Identifier) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    const VarName = CurrentToken.Value;
    CheckStrictModeReservedWord(VarName);
    CheckRestrictedBindingName(VarName);
    DeclareVarName(VarName);
    Advance;

    if Match(TJSTokenType.KeywordIn) then
    begin
      const VarId = TJSIdentifier.Create(VarName);
      const VarDecl = TJSVariableDeclaration.Create;
      const Declarator = TJSVariableDeclarator.Create(VarId, nil);
      VarDecl.Declarations.Add(Declarator);

      const Right = ParseExpression;
      Expect(TJSTokenType.RightParen);

      const Body = ParseLoopBody([VarDecl, Right]);

      Exit(TJSForInStatement.Create(VarDecl, Right, Body));
    end;

    const VarDecl = TJSVariableDeclaration.Create;
    const VarId = TJSIdentifier.Create(VarName);
    var InitExpr: TJSExpression := nil;

    if Match(TJSTokenType.Assign) then
      InitExpr := ParseAssignmentExpression;

    const Declarator = TJSVariableDeclarator.Create(VarId, InitExpr);
    VarDecl.Declarations.Add(Declarator);

    while Match(TJSTokenType.Comma) do
    begin
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const NextVarName = CurrentToken.Value;
      CheckStrictModeReservedWord(NextVarName);
      CheckRestrictedBindingName(NextVarName);
      DeclareVarName(NextVarName);
      Advance;

      const NextVarId = TJSIdentifier.Create(NextVarName);
      var NextInitExpr: TJSExpression := nil;

      if Match(TJSTokenType.Assign) then
        NextInitExpr := ParseAssignmentExpression;

      const NextDeclarator = TJSVariableDeclarator.Create(NextVarId, NextInitExpr);
      VarDecl.Declarations.Add(NextDeclarator);
    end;

    Init := VarDecl;
  end
  else if not Check(TJSTokenType.Semicolon) then
  begin
    const Expr = ParseExpressionWithoutIn;

    if Match(TJSTokenType.KeywordIn) then
    begin
      EnsureAssignmentTarget(Expr);

      const Right = ParseExpression;
      Expect(TJSTokenType.RightParen);

      const Body = ParseLoopBody([Expr, Right]);

      Exit(TJSForInStatement.Create(Expr, Right, Body));
    end;

    Init := TJSExpressionStatement.Create(Expr);
  end;

  Expect(TJSTokenType.Semicolon);

  var Test: TJSExpression := nil;
  if not Check(TJSTokenType.Semicolon) then
    Test := ParseExpression;

  Expect(TJSTokenType.Semicolon);

  var Update: TJSExpression := nil;
  if not Check(TJSTokenType.RightParen) then
    Update := ParseExpression;

  Expect(TJSTokenType.RightParen);

  const Body = ParseLoopBody([Init, Test, Update]);

  Result := TJSForStatement.Create(Init, Test, Update, Body);
end;

function TJSParser.ParseLexicalForStatement: TJSStatement;
begin
  FScopes.Enter(TJSParserScopeKind.Block, nil);
  const ClosureMark = FClosureCount;

  const Declaration = TJSVariableDeclaration.Create;
  if Check(TJSTokenType.KeywordConst) then
    Declaration.Kind := TJSDeclarationKind.Const_
  else
    Declaration.Kind := TJSDeclarationKind.Let;

  Advance;

  try
    Result := ParseLexicalForHeadAndBody(Declaration);
  except
    const AbandonedScopeInfo = FScopes.Leave;
    AbandonedScopeInfo.Free;
    raise;
  end;

  const ForScopeInfo = FScopes.Leave;
  ForScopeInfo.Free;

  const MayCaptureScope = (FClosureCount <> ClosureMark);
  if Result is TJSForInStatement then
    TJSForInStatement(Result).MayCaptureScope := MayCaptureScope
  else
    TJSForStatement(Result).MayCaptureScope := MayCaptureScope;
end;

function TJSParser.ParseLexicalForHeadAndBody(const Declaration: TJSVariableDeclaration): TJSStatement;
begin
  var Right: TJSExpression := nil;
  var Test: TJSExpression := nil;
  var Update: TJSExpression := nil;

  try
    ParseLexicalBinding(Declaration, False, False);

    if Match(TJSTokenType.KeywordIn) then
    begin
      if Assigned(Declaration.Declarations[0].Init) then
        raise TJSErrorFactory.SyntaxError(ForInInitializerMessage, CurrentToken.Line, CurrentToken.Column);

      Right := ParseExpression;
    end
    else
    begin
      while Match(TJSTokenType.Comma) do
      begin
        ParseLexicalBinding(Declaration, False, False);
      end;

      for var Declarator in Declaration.Declarations do
      begin
        const IsMissingConstInitializer = (Declaration.Kind = TJSDeclarationKind.Const_) and (Declarator.Init = nil);
        if IsMissingConstInitializer then
          raise TJSErrorFactory.SyntaxError(MissingConstInitializerMessage, CurrentToken.Line, CurrentToken.Column);
      end;

      Expect(TJSTokenType.Semicolon);

      if not Check(TJSTokenType.Semicolon) then
        Test := ParseExpression;

      Expect(TJSTokenType.Semicolon);

      if not Check(TJSTokenType.RightParen) then
        Update := ParseExpression;
    end;

    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Declaration, Right, Test, Update]);
    raise;
  end;

  const IsForIn = Assigned(Right);
  if IsForIn then
  begin
    const ForInBody = ParseLoopBody([Declaration, Right]);
    Result := TJSForInStatement.Create(Declaration, Right, ForInBody);
  end
  else
  begin
    const ForBody = ParseLoopBody([Declaration, Test, Update]);
    Result := TJSForStatement.Create(Declaration, Test, Update, ForBody);
  end;
end;

function TJSParser.ParseReturnStatement: TJSReturnStatement;
begin
  const Token = CurrentToken;
  if FFunctionDepth = 0 then
    raise TJSErrorFactory.SyntaxError(IllegalReturnMessage, Token.Line, Token.Column);

  Expect(TJSTokenType.KeywordReturn);

  var Argument: TJSExpression := nil;

  const HasNewLine = (CurrentToken.Line > Token.Line);
  const IsEndOfStatement = (Check(TJSTokenType.Semicolon) or Check(TJSTokenType.RightBrace) or Check(TJSTokenType.EndOfFile));

  if (not HasNewLine) and (not IsEndOfStatement) then
    Argument := ParseExpression;

  try
    ExpectSemicolon;
  except
    Argument.Free;
    raise;
  end;

  Result := TJSReturnStatement.Create(Argument);
end;

function TJSParser.ParseBreakStatement: TJSBreakStatement;
begin
  const KeywordToken = CurrentToken;
  Expect(TJSTokenType.KeywordBreak);

  const LabelName = ParseJumpLabel(KeywordToken);
  const HasLabel = not LabelName.IsEmpty;
  const IsInsideBreakable = ((FLoopDepth > 0) or (FSwitchDepth > 0));
  if (not HasLabel) and (not IsInsideBreakable) then
    raise TJSErrorFactory.SyntaxError('Illegal break statement', KeywordToken.Line, KeywordToken.Column);

  ExpectSemicolon;

  var LabelId: TJSIdentifier := nil;
  if HasLabel then
    LabelId := TJSIdentifier.Create(LabelName);

  Result := TJSBreakStatement.Create(LabelId);
end;

function TJSParser.ParseContinueStatement: TJSContinueStatement;
begin
  const KeywordToken = CurrentToken;
  Expect(TJSTokenType.KeywordContinue);

  const LabelName = ParseJumpLabel(KeywordToken);
  const HasLabel = not LabelName.IsEmpty;
  if HasLabel then
  begin
    const LabelIndex = FindActiveLabel(LabelName);
    const LabelsLoop = FActiveLabels[LabelIndex].LabelsIteration;
    if not LabelsLoop then
      raise TJSErrorFactory.SyntaxError(Format(ContinueTargetNotLoopMessage, [LabelName]),
        KeywordToken.Line, KeywordToken.Column);
  end
  else if FLoopDepth = 0 then
  begin
    raise TJSErrorFactory.SyntaxError('Illegal continue statement', KeywordToken.Line, KeywordToken.Column);
  end;

  ExpectSemicolon;

  var LabelId: TJSIdentifier := nil;
  if HasLabel then
    LabelId := TJSIdentifier.Create(LabelName);

  Result := TJSContinueStatement.Create(LabelId);
end;

function TJSParser.ParseJumpLabel(const KeywordToken: TJSToken): string;
begin
  Result := '';

  const IsLabelOnSameLine = (Check(TJSTokenType.Identifier) and (CurrentToken.Line = KeywordToken.Line));
  if not IsLabelOnSameLine then
    Exit;

  Result := CurrentToken.Value;

  const IsDeclared = (FindActiveLabel(Result) >= 0);
  if not IsDeclared then
    raise TJSErrorFactory.SyntaxError(Format(UndefinedLabelMessage, [Result]),
      CurrentToken.Line, CurrentToken.Column);

  Advance;
end;

function TJSParser.FindActiveLabel(const LabelName: string): Integer;
begin
  for var Index := FActiveLabels.Count - 1 downto FLabelScopeStart do
  begin
    if FActiveLabels[Index].Name = LabelName then
      Exit(Index);
  end;

  Result := -1;
end;

function TJSParser.LabelsIterationStatement: Boolean;
begin
  var Offset := 0;

  while (FLexer.PeekToken(Offset).TokenType = TJSTokenType.Identifier) and
        (FLexer.PeekToken(Offset + 1).TokenType = TJSTokenType.Colon) do
  begin
    Inc(Offset, 2);
  end;

  Result := (FLexer.PeekToken(Offset).TokenType in [TJSTokenType.KeywordFor,
                                                   TJSTokenType.KeywordWhile,
                                                   TJSTokenType.KeywordDo]);
end;

function TJSParser.ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
begin
  const LabelToken = CurrentToken;
  CheckStrictModeReservedWord(LabelToken.Value);

  const IsDuplicate = (FindActiveLabel(LabelToken.Value) >= 0);
  if IsDuplicate then
    raise TJSErrorFactory.SyntaxError(Format(DuplicateLabelMessage, [LabelToken.Value]),
      LabelToken.Line, LabelToken.Column);

  var Info: TJSLabelInfo;
  Info.Name := LabelToken.Value;
  Info.LabelsIteration := LabelsIterationStatement;

  Advance;
  Expect(TJSTokenType.Colon);

  const IsAllowedFunction = (AllowFunction and Check(TJSTokenType.KeywordFunction) and (not FStrictMode));
  if StartsWithDeclaration and (not IsAllowedFunction) then
    raise TJSErrorFactory.SyntaxError('Declaration is not allowed as the body of a labelled statement',
      CurrentToken.Line, CurrentToken.Column);

  FActiveLabels.Add(Info);
  try
    FAllowLabelledFunction := AllowFunction;
    const Body = ParseStatement;
    Result := TJSLabeledStatement.Create(Info.Name, Body);
  finally
    FActiveLabels.Delete(FActiveLabels.Count - 1);
  end;
end;

procedure TJSParser.RejectFunctionDeclarationBody(const Owned: array of TObject);
begin
  if not Check(TJSTokenType.KeywordFunction) then
    Exit;

  FreeOwned(Owned);

  raise TJSErrorFactory.SyntaxError(FunctionDeclarationBodyMessage, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.FreeOwned(const Owned: array of TObject);
begin
  for var Node in Owned do
  begin
    Node.Free;
  end;
end;

function TJSParser.ParseLoopBody(const Owned: array of TObject): TJSStatement;
begin
  RejectFunctionDeclarationBody(Owned);

  Inc(FLoopDepth);
  try
    try
      Result := ParseStatement;
    except
      FreeOwned(Owned);
      raise;
    end;
  finally
    Dec(FLoopDepth);
  end;
end;

function TJSParser.ParseSwitchStatement: TJSSwitchStatement;
begin
  Expect(TJSTokenType.KeywordSwitch);
  Expect(TJSTokenType.LeftParen);

  const Discriminant = ParseExpression;

  Expect(TJSTokenType.RightParen);
  Expect(TJSTokenType.LeftBrace);

  Result := TJSSwitchStatement.Create(Discriminant);

  var HasDefaultClause := False;

  FScopes.Enter(TJSParserScopeKind.Block, nil);
  const ClosureMark = FClosureCount;

  Inc(FSwitchDepth);
  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      var Test: TJSExpression := nil;

      if Match(TJSTokenType.KeywordCase) then
      begin
        Test := ParseExpression;
      end
      else
      begin
        if HasDefaultClause then
          raise TJSErrorFactory.SyntaxError(DuplicateDefaultMessage, CurrentToken.Line, CurrentToken.Column);

        HasDefaultClause := True;
        Expect(TJSTokenType.KeywordDefault);
      end;

      Expect(TJSTokenType.Colon);

      const SwitchCase = TJSSwitchCase.Create(Test);
      Result.Cases.Add(SwitchCase);

      while (not Check(TJSTokenType.KeywordCase)) and
            (not Check(TJSTokenType.KeywordDefault)) and
            (not Check(TJSTokenType.RightBrace)) and
            (not IsAtEnd) do
      begin
        const Statement = ParseStatementListItem;
        SwitchCase.Consequent.Add(Statement);
      end;
    end;

    Expect(TJSTokenType.RightBrace);
    Result.ScopeInfo := FScopes.Leave;
    Dec(FSwitchDepth);
  except
    Dec(FSwitchDepth);
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

function TJSParser.ParseThrowStatement: TJSThrowStatement;
begin
  Expect(TJSTokenType.KeywordThrow);

  if CurrentToken.LineTerminatorBefore then
    raise TJSErrorFactory.SyntaxError(IllegalThrowNewlineMessage, CurrentToken.Line, CurrentToken.Column);

  const Argument = ParseExpression;
  try
    ExpectSemicolon;
  except
    Argument.Free;
    raise;
  end;

  Result := TJSThrowStatement.Create(Argument);
end;

function TJSParser.ParseTryStatement: TJSTryStatement;
begin
  Expect(TJSTokenType.KeywordTry);

  const Block = ParseBlockStatement;
  var Handler: TJSCatchClause := nil;
  var Finalizer: TJSBlockStatement := nil;

  try
    if Match(TJSTokenType.KeywordCatch) then
      Handler := ParseCatchClause;

    if Match(TJSTokenType.KeywordFinally) then
      Finalizer := ParseBlockStatement;

    if (Handler = nil) and (Finalizer = nil) then
      raise TJSErrorFactory.SyntaxError('Missing catch or finally after try', CurrentToken.Line, CurrentToken.Column);
  except
    Block.Free;
    Handler.Free;
    Finalizer.Free;
    raise;
  end;

  Result := TJSTryStatement.Create(Block, Handler, Finalizer);
end;

function TJSParser.ParseCatchClause: TJSCatchClause;
begin
  Expect(TJSTokenType.LeftParen);

  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const ParamName = CurrentToken.Value;
  CheckStrictModeReservedWord(ParamName);
  CheckRestrictedBindingName(ParamName);
  Advance;

  const Param = TJSIdentifier.Create(ParamName);
  var CatchBody: TJSBlockStatement;
  try
    Expect(TJSTokenType.RightParen);
    CatchBody := ParseScopedBlock(TJSParserScopeKind.Block, nil, ParamName);
  except
    Param.Free;
    raise;
  end;

  Result := TJSCatchClause.Create(Param, CatchBody);
end;

function TJSParser.ParseEmptyStatement: TJSEmptyStatement;
begin
  Expect(TJSTokenType.Semicolon);
  Result := TJSEmptyStatement.Create;
end;

function TJSParser.ParseDebuggerStatement: TJSDebuggerStatement;
begin
  Expect(TJSTokenType.KeywordDebugger);
  ExpectSemicolon;
  Result := TJSDebuggerStatement.Create;
end;

function TJSParser.ParseExpression: TJSExpression;
begin
  const Expr = ParseAssignmentExpression;

  if Check(TJSTokenType.Comma) then
  begin
    const SeqExpr = TJSSequenceExpression.Create;
    SeqExpr.Expressions.Add(Expr);

    try
      while Match(TJSTokenType.Comma) do
      begin
        const NextExpr = ParseAssignmentExpression;
        SeqExpr.Expressions.Add(NextExpr);
      end;
    except
      SeqExpr.Free;
      raise;
    end;

    Exit(SeqExpr);
  end;

  Result := Expr;
end;

function TJSParser.ParseExpressionWithoutIn: TJSExpression;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := False;
  try
    Result := ParseExpression;
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

function TJSParser.ParseNestedExpression: TJSExpression;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := True;
  try
    Result := ParseExpression;
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

function TJSParser.ParseNestedAssignmentExpression: TJSExpression;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := True;
  try
    Result := ParseAssignmentExpression;
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

function TJSParser.ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := True;
  try
    Result := ParseScopedBlock(TJSParserScopeKind.Function_, Parameters, '');
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

function TJSParser.ParseAssignmentExpression: TJSExpression;
begin
  if StartsArrowFunction then
    Exit(ParseArrowFunction);

  const Left = ParseConditionalExpression;

  if IsAssignmentOperator(CurrentToken.TokenType) then
  begin
    EnsureAssignmentTarget(Left);

    const Op = TokenToAssignmentOperator(CurrentToken.TokenType);
    Advance;

    const Right = ParseAssignmentExpression;

    Exit(TJSAssignmentExpression.Create(Op, Left, Right));
  end;

  Result := Left;
end;

function TJSParser.ParseConditionalExpression: TJSExpression;
begin
  const Test = ParseLogicalOrExpression;

  if Match(TJSTokenType.Question) then
  begin
    const Consequent = ParseNestedAssignmentExpression;
    Expect(TJSTokenType.Colon);
    const Alternate = ParseAssignmentExpression;

    Exit(TJSConditionalExpression.Create(Test, Consequent, Alternate));
  end;

  Result := Test;
end;

function TJSParser.ParseLogicalOrExpression: TJSExpression;
begin
  Result := ParseLogicalAndExpression;

  while Match(TJSTokenType.LogicalOr) do
  begin
    const Right = ParseLogicalAndExpression;
    Result := TJSLogicalExpression.Create(TJSLogicalOperator.Or_, Result, Right);
  end;
end;

function TJSParser.ParseLogicalAndExpression: TJSExpression;
begin
  Result := ParseBitwiseOrExpression;

  while Match(TJSTokenType.LogicalAnd) do
  begin
    const Right = ParseBitwiseOrExpression;
    Result := TJSLogicalExpression.Create(TJSLogicalOperator.And_, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseOrExpression: TJSExpression;
begin
  Result := ParseBitwiseXorExpression;

  while Match(TJSTokenType.BitwiseOr) do
  begin
    const Right = ParseBitwiseXorExpression;
    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseOr, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseXorExpression: TJSExpression;
begin
  Result := ParseBitwiseAndExpression;

  while Match(TJSTokenType.BitwiseXor) do
  begin
    const Right = ParseBitwiseAndExpression;
    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseXor, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseAndExpression: TJSExpression;
begin
  Result := ParseEqualityExpression;

  while Match(TJSTokenType.BitwiseAnd) do
  begin
    const Right = ParseEqualityExpression;
    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseAnd, Result, Right);
  end;
end;

function TJSParser.ParseEqualityExpression: TJSExpression;
begin
  Result := ParseRelationalExpression;

  while CheckAny([TJSTokenType.Equal, TJSTokenType.NotEqual, TJSTokenType.StrictEqual, TJSTokenType.StrictNotEqual]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.Equal:
        Op := TJSBinaryOperator.Equal;
      TJSTokenType.NotEqual:
        Op := TJSBinaryOperator.NotEqual;
      TJSTokenType.StrictEqual:
        Op := TJSBinaryOperator.StrictEqual;
      else
        Op := TJSBinaryOperator.StrictNotEqual;
    end;

    Advance;

    const Right = ParseRelationalExpression;
    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseRelationalExpression: TJSExpression;
begin
  Result := ParseShiftExpression;

  while IsRelationalOperator do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LessThan:
        Op := TJSBinaryOperator.LessThan;
      TJSTokenType.GreaterThan:
        Op := TJSBinaryOperator.GreaterThan;
      TJSTokenType.LessThanOrEqual:
        Op := TJSBinaryOperator.LessThanOrEqual;
      TJSTokenType.GreaterThanOrEqual:
        Op := TJSBinaryOperator.GreaterThanOrEqual;
      TJSTokenType.KeywordInstanceof:
        Op := TJSBinaryOperator.InstanceOf;
      else
        Op := TJSBinaryOperator.In_;
    end;

    Advance;

    const Right = ParseShiftExpression;
    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseShiftExpression: TJSExpression;
begin
  Result := ParseAdditiveExpression;

  while CheckAny([TJSTokenType.LeftShift, TJSTokenType.RightShift, TJSTokenType.UnsignedRightShift]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LeftShift:
        Op := TJSBinaryOperator.LeftShift;
      TJSTokenType.RightShift:
        Op := TJSBinaryOperator.RightShift;
      else
        Op := TJSBinaryOperator.UnsignedRightShift;
    end;

    Advance;

    const Right = ParseAdditiveExpression;
    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseAdditiveExpression: TJSExpression;
begin
  Result := ParseMultiplicativeExpression;

  while CheckAny([TJSTokenType.Plus, TJSTokenType.Minus]) do
  begin
    var Op: TJSBinaryOperator;

    if CurrentToken.TokenType = TJSTokenType.Plus then
      Op := TJSBinaryOperator.Add
    else
      Op := TJSBinaryOperator.Subtract;

    Advance;

    const Right = ParseMultiplicativeExpression;
    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseMultiplicativeExpression: TJSExpression;
begin
  Result := ParseUnaryExpression;

  while CheckAny([TJSTokenType.Multiply, TJSTokenType.Divide, TJSTokenType.Modulo]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.Multiply:
        Op := TJSBinaryOperator.Multiply;
      TJSTokenType.Divide:
        Op := TJSBinaryOperator.Divide;
      else
        Op := TJSBinaryOperator.Modulo;
    end;

    Advance;

    const Right = ParseUnaryExpression;
    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseUnaryExpression: TJSExpression;
begin
  if CheckAny([TJSTokenType.LogicalNot, TJSTokenType.BitwiseNot, TJSTokenType.Plus, TJSTokenType.Minus,
               TJSTokenType.KeywordTypeof, TJSTokenType.KeywordVoid, TJSTokenType.KeywordDelete]) then
  begin
    var Op: TJSUnaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LogicalNot:
        Op := TJSUnaryOperator.LogicalNot;
      TJSTokenType.BitwiseNot:
        Op := TJSUnaryOperator.BitwiseNot;
      TJSTokenType.Plus:
        Op := TJSUnaryOperator.Plus;
      TJSTokenType.Minus:
        Op := TJSUnaryOperator.Minus;
      TJSTokenType.KeywordTypeof:
        Op := TJSUnaryOperator.TypeOf;
      TJSTokenType.KeywordVoid:
        Op := TJSUnaryOperator.Void;
      else
        Op := TJSUnaryOperator.Delete;
    end;

    Advance;

    const Argument = ParseUnaryExpression;

    const IsStrictIdentifierDelete = (Op = TJSUnaryOperator.Delete) and FStrictMode and
                                     (Argument is TJSIdentifier);
    if IsStrictIdentifierDelete then
    begin
      Argument.Free;
      raise TJSErrorFactory.SyntaxError(DeleteIdentifierMessage, CurrentToken.Line, CurrentToken.Column);
    end;

    Exit(TJSUnaryExpression.Create(Op, Argument, True));
  end;

  Result := ParseUpdateExpression;
end;

function TJSParser.ParseUpdateExpression: TJSExpression;
begin
  if CheckAny([TJSTokenType.Increment, TJSTokenType.Decrement]) then
  begin
    var Op: TJSUpdateOperator;

    if CurrentToken.TokenType = TJSTokenType.Increment then
      Op := TJSUpdateOperator.Increment
    else
      Op := TJSUpdateOperator.Decrement;

    Advance;

    const Argument = ParseCallExpression;
    EnsureAssignmentTarget(Argument);

    Exit(TJSUpdateExpression.Create(Op, Argument, True));
  end;

  const Argument = ParseCallExpression;

  const IsUpdateToken = CheckAny([TJSTokenType.Increment, TJSTokenType.Decrement]);
  const IsOnSameLine = (CurrentToken.Line = FPreviousTokenLine);
  if IsUpdateToken and IsOnSameLine then
  begin
    EnsureAssignmentTarget(Argument);

    var Op: TJSUpdateOperator;

    if CurrentToken.TokenType = TJSTokenType.Increment then
      Op := TJSUpdateOperator.Increment
    else
      Op := TJSUpdateOperator.Decrement;

    Advance;

    Exit(TJSUpdateExpression.Create(Op, Argument, False));
  end;

  Result := Argument;
end;

function TJSParser.ParseCallExpression: TJSExpression;
begin
  if Check(TJSTokenType.KeywordNew) then
    Result := ParseNewExpression
  else
    Result := ParseMemberExpression;

  while True do
  begin
    if Check(TJSTokenType.LeftParen) then
    begin
      const CallExpr = TJSCallExpression.Create(Result);
      const Args = ParseArguments;

      for var Arg in Args do
        CallExpr.Arguments.Add(Arg);

      Args.OwnsObjects := False;
      Args.Free;

      Result := CallExpr;
    end
    else if Match(TJSTokenType.Dot) then
    begin
      const Prop = ParseIdentifierName;
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseNestedExpression;
      Expect(TJSTokenType.RightBracket);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else if IsTemplateStart then
      Result := ParseTaggedTemplate(Result)
    else
      Break;
  end;
end;

function TJSParser.ParseIdentifierName: TJSIdentifier;
begin
  if not TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  Result := TJSIdentifier.Create(CurrentToken.Value);
  Advance;
end;

function TJSParser.ParseMemberExpression: TJSExpression;
begin
  Result := ParsePrimaryExpression;

  while True do
  begin
    if Match(TJSTokenType.Dot) then
    begin
      const Prop = ParseIdentifierName;
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseNestedExpression;
      Expect(TJSTokenType.RightBracket);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else if IsTemplateStart then
      Result := ParseTaggedTemplate(Result)
    else
      Break;
  end;
end;

function TJSParser.IsTemplateStart: Boolean;
begin
  Result := Check(TJSTokenType.TemplateChunk) and CurrentToken.IsTemplateHead;
end;

function TJSParser.ParseTemplateLiteral: TJSTemplateLiteral;
begin
  Result := TJSTemplateLiteral.Create;
  Result.Line := CurrentToken.Line;
  Result.Column := CurrentToken.Column;

  try
    ReadTemplateParts(False, Result.Parts, Result.Expressions);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
begin
  const Site = TJSTemplateObject.Create;
  Site.Line := CurrentToken.Line;
  Site.Column := CurrentToken.Column;

  Result := TJSTaggedTemplateExpression.Create(Tag);
  Result.Line := Site.Line;
  Result.Column := Site.Column;
  Result.Arguments.Add(Site);

  try
    ReadTemplateParts(True, Site.Parts, Result.Arguments);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
                                      const Expressions: TObjectList<TJSExpression>);
begin
  var Chunk := CurrentToken;

  while True do
  begin
    const Part = CreateTemplatePart(Chunk, IsTagged);
    Parts.Add(Part);
    Advance;

    if Chunk.IsTemplateTail then
      Exit;

    const Substitution = ParseNestedExpression;
    Expressions.Add(Substitution);

    Chunk := CurrentToken;
    const ContinuesTemplate = (Chunk.TokenType = TJSTokenType.TemplateChunk) and (not Chunk.IsTemplateHead);
    if not ContinuesTemplate then
      raise TJSErrorFactory.UnexpectedToken(Chunk.Value, Chunk.Line, Chunk.Column);
  end;
end;

function TJSParser.CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
begin
  const IsRejected = Chunk.HasInvalidEscape and (not IsTagged);
  if IsRejected then
    raise TJSErrorFactory.SyntaxError(InvalidTemplateEscapeMessage, Chunk.Line, Chunk.Column);

  Result.Cooked := Chunk.Value;
  Result.Raw := Chunk.RawValue;
  Result.HasCooked := not Chunk.HasInvalidEscape;
end;

function TJSParser.ParseNewExpression: TJSExpression;
begin
  Expect(TJSTokenType.KeywordNew);

  const Callee = ParseMemberExpression;
  const NewExpr = TJSNewExpression.Create(Callee);

  if Check(TJSTokenType.LeftParen) then
  begin
    const Args = ParseArguments;

    for var Arg in Args do
      NewExpr.Arguments.Add(Arg);

    Args.OwnsObjects := False;
    Args.Free;
  end;

  Result := NewExpr;
end;

function TJSParser.ParsePrimaryExpression: TJSExpression;
begin
  case CurrentToken.TokenType of
    TJSTokenType.Identifier:
      begin
        const Name = CurrentToken.Value;
        CheckStrictModeReservedWord(Name);

        if Name = SUPER_NAME then
          raise TJSErrorFactory.UnexpectedToken(Name, CurrentToken.Line, CurrentToken.Column);

        if Name = EVAL_NAME then
          Inc(FClosureCount);

        Advance;
        Exit(TJSIdentifier.Create(Name));
      end;

    TJSTokenType.NumberLiteral:
      begin
        const Value = CurrentToken.NumberValue;
        RejectLegacyLiteralInStrictMode(CurrentToken);
        Advance;
        Exit(TJSLiteral.CreateNumber(Value));
      end;

    TJSTokenType.StringLiteral:
      begin
        const Value = CurrentToken.Value;
        RejectLegacyLiteralInStrictMode(CurrentToken);
        Advance;
        Exit(TJSLiteral.CreateString(Value));
      end;

    TJSTokenType.BooleanLiteral:
      begin
        const Value = (CurrentToken.Value = TRUE_VALUE);
        Advance;
        Exit(TJSLiteral.CreateBoolean(Value));
      end;

    TJSTokenType.NullLiteral:
      begin
        Advance;
        Exit(TJSLiteral.CreateNull);
      end;

    TJSTokenType.RegExpLiteral:
      begin
        const Value = CurrentToken.Value;
        const Line = CurrentToken.Line;
        const Column = CurrentToken.Column;
        Advance;

        const SlashPos = Value.LastIndexOf('/');
        const Pattern = Value.Substring(0, SlashPos);
        const Flags = Value.Substring(SlashPos + 1);

        TJSRegExpSyntax.ValidateFlags(Flags, Line, Column);
        TJSRegExpSyntax.ValidatePattern(Pattern, Flags, Line, Column);

        Exit(TJSLiteral.CreateRegExp(Pattern, Flags));
      end;

    TJSTokenType.KeywordThis:
      begin
        Advance;
        Exit(TJSThisExpression.Create);
      end;

    TJSTokenType.TemplateChunk:
      begin
        if not CurrentToken.IsTemplateHead then
          raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

        Exit(ParseTemplateLiteral);
      end;

    TJSTokenType.LeftParen:
      begin
        Advance;
        const Expr = ParseNestedExpression;
        Expect(TJSTokenType.RightParen);

        if Expr is TJSIdentifier then
          TJSIdentifier(Expr).IsParenthesized := True;

        Exit(Expr);
      end;

    TJSTokenType.LeftBracket:
      Exit(ParseArrayExpression);

    TJSTokenType.LeftBrace:
      Exit(ParseObjectExpression);

    TJSTokenType.KeywordFunction:
      Exit(ParseFunctionExpression);

    else
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
  end;
end;

function TJSParser.ParseArrayExpression: TJSArrayExpression;
begin
  Expect(TJSTokenType.LeftBracket);

  Result := TJSArrayExpression.Create;

  try
    while not Check(TJSTokenType.RightBracket) do
    begin
      if Check(TJSTokenType.Comma) then
      begin
        Result.Elements.Add(nil);
        Advance;
      end
      else
      begin
        const Element = ParseNestedAssignmentExpression;
        Result.Elements.Add(Element);

        if not Check(TJSTokenType.RightBracket) then
          Expect(TJSTokenType.Comma);
      end;
    end;

    Expect(TJSTokenType.RightBracket);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseObjectExpression: TJSObjectExpression;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSObjectExpression.Create;

  try
    var HasPrototypeSetter := False;

    while not Check(TJSTokenType.RightBrace) do
    begin
      const Member = ParseObjectMember;
      Result.Properties.Add(Member);

      const IsDuplicatePrototype = Member.SetsPrototype and HasPrototypeSetter;
      if IsDuplicatePrototype then
        raise TJSErrorFactory.SyntaxError(DUPLICATE_PROTOTYPE_MESSAGE, CurrentToken.Line, CurrentToken.Column);

      HasPrototypeSetter := HasPrototypeSetter or Member.SetsPrototype;

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseObjectMember: TJSObjectProperty;
begin
  if StartsAccessorProperty then
    Exit(ParseAccessorProperty);

  const KeyIsIdentifier = Check(TJSTokenType.Identifier);
  const KeyText = CurrentToken.Value;

  var Computed: Boolean;
  const Key = ParsePropertyKey(Computed);
  try
    if Match(TJSTokenType.Colon) then
    begin
      const Value = ParseNestedAssignmentExpression;
      Result := TJSObjectProperty.Create(Key, Value, Computed);
      Exit;
    end;

    if Check(TJSTokenType.LeftParen) then
    begin
      Result := ParseMethodProperty(Key, Computed);
      Exit;
    end;

    const EndsMember = Check(TJSTokenType.Comma) or Check(TJSTokenType.RightBrace);
    const IsShorthand = KeyIsIdentifier and (not Computed) and EndsMember;
    if IsShorthand then
    begin
      Result := ParseShorthandProperty(Key, KeyText);
      Exit;
    end;

    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
  except
    Key.Free;
    raise;
  end;
end;

function TJSParser.ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
begin
  CheckStrictModeReservedWord(Name);

  const IsEval = (Name = EVAL_NAME);
  if IsEval then
    Inc(FClosureCount);

  const Value = TJSIdentifier.Create(Name);
  Result := TJSObjectProperty.Create(Key, Value, False, TJSPropertyKind.Shorthand);
end;

function TJSParser.ParseMethodProperty(const Key: TJSExpression; const Computed: Boolean): TJSObjectProperty;
begin
  const Func = TJSFunctionExpression.Create;
  try
    ParseFunctionSignatureAndBody(Func);
    RejectDuplicateParameters(Func.Params);
  except
    Func.Free;
    raise;
  end;

  Result := TJSObjectProperty.Create(Key, Func, Computed, TJSPropertyKind.Method);
end;

function TJSParser.StartsAccessorProperty: Boolean;
begin
  const IsGetOrSet = Check(TJSTokenType.Identifier) and (not CurrentToken.HasEscape) and
                     ((CurrentToken.Value = KEYWORD_GET) or (CurrentToken.Value = KEYWORD_SET));
  if not IsGetOrSet then
    Exit(False);

  const FollowingType = FLexer.PeekToken(1).TokenType;
  Result := not (FollowingType in [TJSTokenType.Colon, TJSTokenType.LeftParen,
                                   TJSTokenType.Comma, TJSTokenType.RightBrace]);
end;

function TJSParser.ParsePropertyKey(out Computed: Boolean): TJSExpression;
begin
  Computed := False;

  if Check(TJSTokenType.StringLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result := TJSLiteral.CreateString(CurrentToken.Value);
    Advance;
  end
  else if Check(TJSTokenType.NumberLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result := TJSLiteral.CreateNumber(CurrentToken.NumberValue);
    Advance;
  end
  else if TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
  begin
    Result := ParseIdentifierName;
  end
  else if Check(TJSTokenType.LeftBracket) then
  begin
    Advance;
    Result := ParseNestedAssignmentExpression;
    Computed := True;
    try
      Expect(TJSTokenType.RightBracket);
    except
      Result.Free;
      raise;
    end;
  end
  else
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.ParseAccessorProperty: TJSObjectProperty;
begin
  var Kind := TJSPropertyKind.Getter;
  const IsSetter = (CurrentToken.Value = KEYWORD_SET);
  if IsSetter then
    Kind := TJSPropertyKind.Setter;
  Advance;

  var Computed: Boolean;
  const Key = ParsePropertyKey(Computed);
  try
    const Func = ParseAccessorFunction(Kind);
    Result := TJSObjectProperty.Create(Key, Func, Computed, Kind);
  except
    Key.Free;
    raise;
  end;
end;

function TJSParser.ParseAccessorFunction(const Kind: TJSPropertyKind): TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;

  try
    const AccessorLine = CurrentToken.Line;
    const AccessorColumn = CurrentToken.Column;

    ParseFunctionSignatureAndBody(Result);

    const ExpectedParamCount = Ord(Kind = TJSPropertyKind.Setter);
    const HasExpectedParams = (Result.Params.Count = ExpectedParamCount);
    if not HasExpectedParams then
      raise TJSErrorFactory.SyntaxError(ACCESSOR_PARAMETER_COUNT, AccessorLine, AccessorColumn);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseFunctionExpression: TJSFunctionExpression;
begin
  Expect(TJSTokenType.KeywordFunction);

  Result := TJSFunctionExpression.Create;

  try
    if Check(TJSTokenType.Identifier) then
    begin
      const FuncName = CurrentToken.Value;
      CheckStrictModeReservedWord(FuncName);
      Advance;
      Result.Id := TJSIdentifier.Create(FuncName);
    end;

    ParseFunctionSignatureAndBody(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression);
begin
  Expect(TJSTokenType.LeftParen);

  if not Check(TJSTokenType.RightParen) then
  begin
    repeat
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const ParamName = CurrentToken.Value;
      CheckStrictModeReservedWord(ParamName);
      Advance;

      const Param = TJSIdentifier.Create(ParamName);
      Func.Params.Add(Param);
    until not Match(TJSTokenType.Comma);
  end;

  Expect(TJSTokenType.RightParen);

  Inc(FClosureCount);

  const OldStrictMode = FStrictMode;
  const Body = ParseFunctionBodyBlock(Func.Params);
  Func.Body := Body;

  if Body.DeclaresStrictMode then
  begin
    Func.IsStrict := True;
    FStrictMode := True;
  end;

  var FuncName := '';
  if Assigned(Func.Id) then
    FuncName := Func.Id.Name;

  CheckStrictFunctionHeader(FuncName, Func.Params);
  FStrictMode := OldStrictMode;
end;

function TJSParser.StartsArrowFunction: Boolean;
begin
  if Check(TJSTokenType.Identifier) then
  begin
    const NextToken = FLexer.PeekToken(1);
    Exit(NextToken.TokenType = TJSTokenType.Arrow);
  end;

  if not Check(TJSTokenType.LeftParen) then
    Exit(False);

  var Offset := 1;
  while FLexer.PeekToken(Offset).TokenType = TJSTokenType.Identifier do
  begin
    Inc(Offset);

    const SeparatorToken = FLexer.PeekToken(Offset);
    const HasMoreParameters = (SeparatorToken.TokenType = TJSTokenType.Comma);
    if not HasMoreParameters then
      Break;

    Inc(Offset);
  end;

  const ClosingToken = FLexer.PeekToken(Offset);
  const TokenAfterClosing = FLexer.PeekToken(Offset + 1);
  const ClosesParameters = (ClosingToken.TokenType = TJSTokenType.RightParen);
  Result := ClosesParameters and (TokenAfterClosing.TokenType = TJSTokenType.Arrow);
end;

function TJSParser.ParseArrowFunction: TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;
  Result.IsArrow := True;

  try
    ParseArrowParameters(Result);

    const HasLineBreakBeforeArrow = CurrentToken.LineTerminatorBefore;
    if HasLineBreakBeforeArrow then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    Expect(TJSTokenType.Arrow);
    Inc(FClosureCount);

    ParseArrowBody(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseArrowParameters(const Func: TJSFunctionExpression);
begin
  const IsParenthesized = Match(TJSTokenType.LeftParen);
  if not IsParenthesized then
  begin
    ParseArrowParameter(Func);
    Exit;
  end;

  if not Check(TJSTokenType.RightParen) then
  begin
    repeat
      ParseArrowParameter(Func);
    until (not Match(TJSTokenType.Comma)) or Check(TJSTokenType.RightParen);
  end;

  Expect(TJSTokenType.RightParen);
  RejectDuplicateArrowParameters(Func.Params);
end;

procedure TJSParser.ParseArrowParameter(const Func: TJSFunctionExpression);
begin
  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const ParamName = CurrentToken.Value;
  CheckStrictModeReservedWord(ParamName);
  Advance;

  const Parameter = TJSIdentifier.Create(ParamName);
  Func.Params.Add(Parameter);
end;

procedure TJSParser.ParseArrowBody(const Func: TJSFunctionExpression);
begin
  const OldStrictMode = FStrictMode;

  if Check(TJSTokenType.LeftBrace) then
  begin
    const Body = ParseFunctionBodyBlock(Func.Params);
    Func.Body := Body;

    if Body.DeclaresStrictMode then
    begin
      Func.IsStrict := True;
      FStrictMode := True;
    end;
  end
  else
  begin
    Func.Body := ParseConciseBody;
  end;

  CheckStrictFunctionHeader('', Func.Params);
  FStrictMode := OldStrictMode;
end;

function TJSParser.ParseConciseBody: TJSBlockStatement;
begin
  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := True;

  try
    const Argument = ParseAssignmentExpression;
    const ReturnStatement = TJSReturnStatement.Create(Argument);
    Result.Body.Add(ReturnStatement);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
begin
  for var Index := 1 to Params.Count - 1 do
  begin
    for var EarlierIndex := 0 to Index - 1 do
    begin
      const IsDuplicate = (Params[EarlierIndex].Name = Params[Index].Name);
      if IsDuplicate then
        raise TJSErrorFactory.SyntaxError(DuplicateArrowParameterMessage, Params[Index].Line, Params[Index].Column);
    end;
  end;
end;

function TJSParser.ParseArguments: TObjectList<TJSExpression>;
begin
  Expect(TJSTokenType.LeftParen);

  Result := TObjectList<TJSExpression>.Create(True);

  try
    if not Check(TJSTokenType.RightParen) then
    begin
      repeat
        const Arg = ParseNestedAssignmentExpression;
        Result.Add(Arg);
      until not Match(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightParen);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.IsAssignmentOperator(const TokenType: TJSTokenType): Boolean;
begin
  Result := TokenType in [
    TJSTokenType.Assign,
    TJSTokenType.PlusAssign,
    TJSTokenType.MinusAssign,
    TJSTokenType.MultiplyAssign,
    TJSTokenType.DivideAssign,
    TJSTokenType.ModuloAssign,
    TJSTokenType.BitwiseAndAssign,
    TJSTokenType.BitwiseOrAssign,
    TJSTokenType.BitwiseXorAssign,
    TJSTokenType.LeftShiftAssign,
    TJSTokenType.RightShiftAssign,
    TJSTokenType.UnsignedRightShiftAssign
  ];
end;

function TJSParser.IsRelationalOperator: Boolean;
begin
  const IsInKeyword = Check(TJSTokenType.KeywordIn);
  if IsInKeyword then
    Exit(FInOperatorAllowed);

  Result := CheckAny([TJSTokenType.LessThan, TJSTokenType.GreaterThan, TJSTokenType.LessThanOrEqual,
                      TJSTokenType.GreaterThanOrEqual, TJSTokenType.KeywordInstanceof]);
end;

function TJSParser.IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
begin
  if Target is TJSTaggedTemplateExpression then
    Exit(False);

  const IsCall = (Target.NodeType = TJSASTNodeType.CallExpression);
  if IsCall then
    Exit(not FStrictMode);

  const IsIdentifier = (Target.NodeType = TJSASTNodeType.Identifier);
  if IsIdentifier then
  begin
    const IdentifierName = TJSIdentifier(Target).Name;
    Exit(not IsRestrictedStrictName(IdentifierName));
  end;

  Result := (Target.NodeType = TJSASTNodeType.MemberExpression);
end;

procedure TJSParser.EnsureAssignmentTarget(const Target: TJSExpression);
begin
  if IsValidAssignmentTarget(Target) then
    Exit;

  Target.Free;
  raise TJSErrorFactory.SyntaxError('Invalid left-hand side in assignment', CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.TokenToAssignmentOperator(const TokenType: TJSTokenType): TJSAssignmentOperator;
begin
  case TokenType of
    TJSTokenType.Assign:
      Result := TJSAssignmentOperator.Assign;
    TJSTokenType.PlusAssign:
      Result := TJSAssignmentOperator.AddAssign;
    TJSTokenType.MinusAssign:
      Result := TJSAssignmentOperator.SubtractAssign;
    TJSTokenType.MultiplyAssign:
      Result := TJSAssignmentOperator.MultiplyAssign;
    TJSTokenType.DivideAssign:
      Result := TJSAssignmentOperator.DivideAssign;
    TJSTokenType.ModuloAssign:
      Result := TJSAssignmentOperator.ModuloAssign;
    TJSTokenType.BitwiseAndAssign:
      Result := TJSAssignmentOperator.BitwiseAndAssign;
    TJSTokenType.BitwiseOrAssign:
      Result := TJSAssignmentOperator.BitwiseOrAssign;
    TJSTokenType.BitwiseXorAssign:
      Result := TJSAssignmentOperator.BitwiseXorAssign;
    TJSTokenType.LeftShiftAssign:
      Result := TJSAssignmentOperator.LeftShiftAssign;
    TJSTokenType.RightShiftAssign:
      Result := TJSAssignmentOperator.RightShiftAssign;
    TJSTokenType.UnsignedRightShiftAssign:
      Result := TJSAssignmentOperator.UnsignedRightShiftAssign;
    else
      Result := TJSAssignmentOperator.Assign;
  end;
end;

function TJSParser.IsStrictModeReservedWord(const Name: string): Boolean;
begin
  Result := ((Name = 'implements') or (Name = 'interface') or (Name = 'let') or
             (Name = 'package') or (Name = 'private') or (Name = 'protected') or
             (Name = 'public') or (Name = 'static') or (Name = 'yield'));
end;

procedure TJSParser.CheckStrictModeReservedWord(const Name: string);
begin
  if FStrictMode and IsStrictModeReservedWord(Name) then
    raise TJSErrorFactory.SyntaxError('Use of future reserved word in strict mode: ' + Name,
      CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.IsRestrictedStrictName(const Name: string): Boolean;
begin
  const IsEvalOrArguments = (Name = EVAL_NAME) or (Name = ARGUMENTS_NAME);
  Result := FStrictMode and IsEvalOrArguments;
end;

procedure TJSParser.CheckRestrictedBindingName(const Name: string);
begin
  if IsRestrictedStrictName(Name) then
  begin
    const Message = Format(RestrictedBindingNameMessage, [Name]);
    raise TJSErrorFactory.SyntaxError(Message, CurrentToken.Line, CurrentToken.Column);
  end;
end;

procedure TJSParser.CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>);
begin
  if not FStrictMode then
    Exit;

  CheckStrictModeReservedWord(FuncName);
  CheckRestrictedBindingName(FuncName);

  for var Param in Params do
  begin
    CheckStrictModeReservedWord(Param.Name);
  end;

  CheckDuplicateParameters(Params);
  CheckRestrictedParameterNames(Params);
end;

procedure TJSParser.CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  if FStrictMode then
    RejectDuplicateParameters(Params);
end;

procedure TJSParser.RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  var ParamNames: TArray<string>;
  SetLength(ParamNames, Params.Count);

  for var I := 0 to Params.Count - 1 do
  begin
    const ParamName = Params[I].Name;

    for var J := 0 to I - 1 do
    begin
      if ParamNames[J] = ParamName then
        raise TJSErrorFactory.SyntaxError('Duplicate parameter name not allowed in strict mode',
          Params[I].Line, Params[I].Column);
    end;

    ParamNames[I] := ParamName;
  end;
end;

procedure TJSParser.CheckRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);
begin
  if not FStrictMode then
    Exit;

  for var Param in Params do
  begin
    const IsRestricted = (Param.Name = EVAL_NAME) or (Param.Name = ARGUMENTS_NAME);
    if IsRestricted then
    begin
      const Message = Format(RestrictedParameterNameMessage, [Param.Name]);
      raise TJSErrorFactory.SyntaxError(Message, Param.Line, Param.Column);
    end;
  end;
end;

end.
