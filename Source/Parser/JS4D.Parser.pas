unit JS4D.Parser;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Tokens,
  JS4D.AST,
  JS4D.ParserScope,
  JS4D.ParserRules,
  JS4D.ParserConstants,
  JS4D.ParserTypes,
  JS4D.ParserBase,
  JS4D.ParserFunctions;

type
  TJSParser = class(TJSFunctionParser)
  protected
    function ParseClassDeclaration: TJSVariableDeclaration;
    function ParseProgram: TJSProgram; override;
    function ParseStatement(const AllowLabelledFunction: Boolean): TJSStatement;
    function ParseStatementBody(const AllowLabelledFunction: Boolean): TJSStatement;
    function ParseAsyncOrExpressionStatement(const AllowLabelledFunction: Boolean): TJSStatement;
    function ParseStatementListItem: TJSStatement;
    function ParseBlockStatement: TJSBlockStatement;
    function ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                              const CatchBinding: TJSCatchBinding): TJSBlockStatement;
    function ParseVariableDeclaration: TJSVariableDeclaration;
    function ParseForVarDeclarations: TJSVariableDeclaration;
    function ParseForRightExpression(const IsForOf: Boolean): TJSExpression;
    procedure RejectForOfInitializer(const Declaration: TJSVariableDeclaration);
    procedure RejectForInInitializer(const Declaration: TJSVariableDeclaration);
    function MatchOf: Boolean;
    function ConvertForInTargetOwning(const Target: TJSExpression): TJSExpression;
    function ParseLexicalDeclaration: TJSVariableDeclaration;
    function CurrentDeclarationKind: TJSDeclarationKind;
    function ParseIfBranch: TJSStatement;
    function ParseFunctionDeclaration(const AllowGenerator: Boolean;
                                      const IsAsync: Boolean = False): TJSFunctionDeclaration;
    procedure DeclareFunctionName(const FuncName: string; const IsFunctionLevel: Boolean;
                                  const IsPlainFunction: Boolean);
    procedure ParseFunctionDeclarationBody(const Func: TJSFunctionDeclaration; const SourceStart: Integer);
    procedure RegisterBlockFunction(const Func: TJSFunctionDeclaration; const IsStrictContext: Boolean;
                                    const IsPlainFunction: Boolean);
    function ParseExpressionStatement: TJSExpressionStatement;
    function ParseIfStatement: TJSIfStatement;
    function ParseWhileStatement: TJSWhileStatement;
    function ParseDoWhileStatement: TJSDoWhileStatement;
    function ParseLoopBody(const Owned: array of TObject): TJSStatement;
    procedure RejectFunctionDeclarationBody;
    function ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
    procedure RejectDuplicateLabel(const LabelToken: TJSToken);
    procedure ValidateLabelledBody(const AllowFunction: Boolean);
    function FindActiveLabel(const LabelName: string): Integer;
    function ParseJumpLabel(const KeywordToken: TJSToken): string;
    function CreateLabelIdentifier(const LabelName: string): TJSIdentifier;
    function ParseWithStatement: TJSWithStatement;
    function ParseWithBody: TJSStatement;
    function StartsWithDeclaration: Boolean;
    function ParseForStatement: TJSStatement;
    function ParseForHead(const IsLexicalHead: Boolean): TJSForHead;
    function ParseLexicalForHead: TJSForHead;
    function ParseVarForHead: TJSForHead;
    function ParseExpressionForHead: TJSForHead;
    function ParseForTargetHead(const Expression: TJSExpression; const Mark: TJSCoverMark;
                                const IsForOf: Boolean; const StartsWithAsyncOf: Boolean): TJSForHead;
    function ParseForInHead(const Left: TJSASTNode): TJSForHead;
    function ParseForOfHead(const Left: TJSASTNode; const IsDeclaration: Boolean): TJSForHead;
    function ParseClassicForHead(const Init: TJSASTNode): TJSForHead;
    function ParseReturnStatement: TJSReturnStatement;
    function ParseBreakStatement: TJSBreakStatement;
    function ParseContinueStatement: TJSContinueStatement;
    function ParseSwitchStatement: TJSSwitchStatement;
    function ParseSwitchCaseLabel(const HasDefaultClause: Boolean): TJSSwitchCase;
    function EndsSwitchCaseBody: Boolean;
    function ParseThrowStatement: TJSThrowStatement;
    function ParseTryStatement: TJSTryStatement;
    function ParseCatchClause: TJSCatchClause;
    function ParseEmptyStatement: TJSEmptyStatement;
    function ParseDebuggerStatement: TJSDebuggerStatement;
    function ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement; override;
    function ParseCatchPattern: TJSCatchClause;
  end;

implementation

{ TJSParser }

function TJSParser.ParseProgram: TJSProgram;
begin
  Result := TJSProgram.Create;
  const ClosureMark = EnterScope(TJSParserScopeKind.Function_, nil, TJSCatchBinding.None);

  try
    const Prologue = ScanDirectivePrologue(PROGRAM_FIRST_TOKEN_OFFSET);
    RejectLegacyDirectives(Prologue);

    if Prologue.HasUseStrict then
    begin
      FStrictMode := True;
      Result.IsStrict := True;
    end;

    while not IsAtEnd do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Result.ScopeInfo := LeaveScope(ClosureMark);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseStatementListItem: TJSStatement;
begin
  const StartsLexicalDeclaration = (Check(TJSTokenType.KeywordConst) or
                                    FLookahead.StartsLetDeclaration(LINE_BREAK_ALLOWED));
  const StartsClassDeclaration = Check(TJSTokenType.KeywordClass);

  if StartsLexicalDeclaration then
  begin
    Result := ParseLexicalDeclaration;
  end
  else if StartsClassDeclaration then
  begin
    Result := ParseClassDeclaration;
  end
  else
  begin
    Result := ParseStatement(LABELLED_FUNCTION_ALLOWED);
  end;
end;

function TJSParser.ParseStatement(const AllowLabelledFunction: Boolean): TJSStatement;
begin
  EnterNesting;
  try
    Result := ParseStatementBody(AllowLabelledFunction);
  finally
    LeaveNesting;
  end;
end;

function TJSParser.ParseStatementBody(const AllowLabelledFunction: Boolean): TJSStatement;
begin
  const StartsLexicalDeclaration = (Check(TJSTokenType.KeywordConst) or
                                    FLookahead.StartsLetDeclaration(LINE_BREAK_NOT_ALLOWED));
  if StartsLexicalDeclaration then
    RaiseAtCurrentToken(LEXICAL_DECLARATION_BODY_MESSAGE);

  if FLookahead.StartsLabel then
  begin
    Result := ParseLabeledStatement(AllowLabelledFunction);
    Exit;
  end;

  case CurrentToken.TokenType of
    TJSTokenType.LeftBrace       : Result := ParseBlockStatement;
    TJSTokenType.KeywordVar      : Result := ParseVariableDeclaration;
    TJSTokenType.KeywordFunction : Result := ParseFunctionDeclaration(AllowLabelledFunction);
    TJSTokenType.KeywordClass    : raise SyntaxErrorAtToken(CLASS_DECLARATION_BODY_MESSAGE, CurrentToken);
    TJSTokenType.KeywordIf       : Result := ParseIfStatement;
    TJSTokenType.KeywordWhile    : Result := ParseWhileStatement;
    TJSTokenType.KeywordDo       : Result := ParseDoWhileStatement;
    TJSTokenType.KeywordWith     : Result := ParseWithStatement;
    TJSTokenType.KeywordFor      : Result := ParseForStatement;
    TJSTokenType.KeywordReturn   : Result := ParseReturnStatement;
    TJSTokenType.KeywordBreak    : Result := ParseBreakStatement;
    TJSTokenType.KeywordContinue : Result := ParseContinueStatement;
    TJSTokenType.KeywordSwitch   : Result := ParseSwitchStatement;
    TJSTokenType.KeywordThrow    : Result := ParseThrowStatement;
    TJSTokenType.KeywordTry      : Result := ParseTryStatement;
    TJSTokenType.Semicolon       : Result := ParseEmptyStatement;
    TJSTokenType.KeywordDebugger : Result := ParseDebuggerStatement;
  else
    Result := ParseAsyncOrExpressionStatement(AllowLabelledFunction);
  end;
end;

function TJSParser.ParseAsyncOrExpressionStatement(const AllowLabelledFunction: Boolean): TJSStatement;
begin
  if FLookahead.StartsAsyncFunction then
  begin
    if not AllowLabelledFunction then
      RaiseAtCurrentToken(ASYNC_DECLARATION_BODY_MESSAGE);

    Result := ParseFunctionDeclaration(AllowLabelledFunction, ASYNC_FUNCTION);
  end
  else
  begin
    Result := ParseExpressionStatement;
  end;
end;

function TJSParser.ParseBlockStatement: TJSBlockStatement;
begin
  Result := ParseScopedBlock(TJSParserScopeKind.Block, nil, TJSCatchBinding.None);
end;

function TJSParser.ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                                    const CatchBinding: TJSCatchBinding): TJSBlockStatement;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := (Kind = TJSParserScopeKind.Function_);
  const ClosureMark = EnterScope(Kind, Parameters, CatchBinding);

  try
    while IsInsideBlock do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Expect(TJSTokenType.RightBrace);
    Result.ScopeInfo := LeaveScope(ClosureMark);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.CurrentDeclarationKind: TJSDeclarationKind;
begin
  if Check(TJSTokenType.KeywordConst) then
    Result := TJSDeclarationKind.Const_
  else
    Result := TJSDeclarationKind.Let;
end;

function TJSParser.ParseLexicalDeclaration: TJSVariableDeclaration;
begin
  Result := TJSVariableDeclaration.Create;

  try
    Result.Kind := CurrentDeclarationKind;
    Advance;

    const RequiresInitializer = (Result.Kind = TJSDeclarationKind.Const_);

    repeat
      ParseBinding(Result, TJSBindingKind.Lexical, IN_OPERATOR_ALLOWED, RequiresInitializer);
    until not Match(TJSTokenType.Comma);

    RejectMissingPatternInitializers(Result);
    ExpectSemicolon;
    FScopes.AddDeclaration(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseVariableDeclaration: TJSVariableDeclaration;
begin
  Expect(TJSTokenType.KeywordVar);

  Result := TJSVariableDeclaration.Create;

  try
    repeat
      ParseBinding(Result, TJSBindingKind.Var_, FInOperatorAllowed, INITIALIZER_NOT_REQUIRED);
    until not Match(TJSTokenType.Comma);

    RejectMissingPatternInitializers(Result);
    ExpectSemicolon;
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseFunctionDeclaration(const AllowGenerator: Boolean;
                                            const IsAsync: Boolean): TJSFunctionDeclaration;
begin
  const Head = ParseFunctionHead(IsAsync, AllowGenerator);

  if not Check(TJSTokenType.Identifier) then
    RaiseUnexpectedToken;

  const FuncName = CurrentToken.Value;
  CheckReservedIdentifier(FuncName);

  const IsStrictContext = FStrictMode;
  const IsFunctionLevel = FScopes.IsFunctionLevel;
  const IsPlainFunction = ((not Head.IsGenerator) and (not IsAsync));
  DeclareFunctionName(FuncName, IsFunctionLevel, IsPlainFunction);

  Advance;

  const Identifier = TJSIdentifier.Create(FuncName);
  Result := TJSFunctionDeclaration.Create(Identifier);
  Result.IsGenerator := Head.IsGenerator;
  Result.IsAsync := IsAsync;

  try
    ParseFunctionDeclarationBody(Result, Head.SourceStart);
  except
    Result.Free;
    raise;
  end;

  if not IsFunctionLevel then
    RegisterBlockFunction(Result, IsStrictContext, IsPlainFunction);
end;

procedure TJSParser.DeclareFunctionName(const FuncName: string; const IsFunctionLevel: Boolean;
                                        const IsPlainFunction: Boolean);
begin
  if IsFunctionLevel then
  begin
    DeclareVarName(FuncName);
  end
  else
  begin
    const AllowFunctionDuplicate = ((not FStrictMode) and IsPlainFunction);
    DeclareLexicalName(FuncName, IsPlainFunction, AllowFunctionDuplicate);
  end;
end;

procedure TJSParser.ParseFunctionDeclarationBody(const Func: TJSFunctionDeclaration; const SourceStart: Integer);
begin
  const OuterState = SaveFunctionState;
  EnterFunction(TJSFunctionContext.Ordinary, Func.IsGenerator, Func.IsAsync);
  try
    Func.ParameterInfo := ParseFormalParameters(Func.Params);
    const Body = ParseFunctionBodyAndHeader(Func.Id.Name, Func.Params, Func.ParameterInfo, Func.IsGenerator,
                                            Func.IsAsync, OuterState.InAsync);
    Func.Body := Body;
    Func.IsStrict := Body.DeclaresStrictMode;
    Func.SourceText := SourceTextFrom(SourceStart);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSParser.RegisterBlockFunction(const Func: TJSFunctionDeclaration; const IsStrictContext: Boolean;
                                          const IsPlainFunction: Boolean);
begin
  FScopes.AddDeclaration(Func);

  const IsCandidate = ((not IsStrictContext) and IsPlainFunction);
  if IsCandidate then
    FScopes.AddFunctionCandidate(Func);
end;

function TJSParser.ParseExpressionStatement: TJSExpressionStatement;
begin
  const Expression = ParseExpression;
  ExpectSemicolonOwning([Expression]);

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
      RejectFunctionDeclarationBody;

    Consequent := ParseIfBranch;

    if Match(TJSTokenType.KeywordElse) then
    begin
      if FStrictMode then
        RejectFunctionDeclarationBody;

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
  begin
    Result := ParseStatement(LABELLED_FUNCTION_NOT_ALLOWED);
    Exit;
  end;

  const Block = TJSBlockStatement.Create;
  FScopes.Enter(TJSParserScopeKind.Block, nil, TJSCatchBinding.None);

  try
    const Declaration = ParseFunctionDeclaration(GENERATOR_NOT_ALLOWED);
    Block.Body.Add(Declaration);
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

  ExpectOwning(TJSTokenType.RightParen, [Test]);

  const Body = ParseLoopBody([Test]);

  Result := TJSWhileStatement.Create(Test, Body);
end;

function TJSParser.ParseWithStatement: TJSWithStatement;
begin
  if FStrictMode then
    RaiseAtCurrentToken(WITH_IN_STRICT_MODE_MESSAGE);

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
    RaiseAtCurrentToken(WITH_BODY_DECLARATION_MESSAGE);

  Result := ParseStatement(LABELLED_FUNCTION_NOT_ALLOWED);
end;

function TJSParser.StartsWithDeclaration: Boolean;
begin
  if CheckAny([TJSTokenType.KeywordFunction, TJSTokenType.KeywordConst, TJSTokenType.KeywordClass]) then
    Exit(True);

  if not Check(TJSTokenType.Identifier) then
    Exit(False);

  Result := FLookahead.StartsLetDeclaration(LINE_BREAK_NOT_ALLOWED);
end;

function TJSParser.ParseDoWhileStatement: TJSDoWhileStatement;
begin
  Expect(TJSTokenType.KeywordDo);

  const Body = ParseLoopBody([]);

  var Test: TJSExpression := nil;
  try
    Expect(TJSTokenType.KeywordWhile);
    Expect(TJSTokenType.LeftParen);
    Test := ParseExpression;
    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Body, Test]);
    raise;
  end;

  Match(TJSTokenType.Semicolon);

  Result := TJSDoWhileStatement.Create(Body, Test);
end;

function TJSParser.ParseForStatement: TJSStatement;
begin
  Expect(TJSTokenType.KeywordFor);
  Expect(TJSTokenType.LeftParen);

  const IsLexicalHead = (Check(TJSTokenType.KeywordConst) or FLookahead.StartsLetDeclaration(LINE_BREAK_ALLOWED));
  var ClosureMark := FClosureCount;
  if IsLexicalHead then
    ClosureMark := EnterScope(TJSParserScopeKind.Block, nil, TJSCatchBinding.None);

  var Loop: TJSScopedLoopStatement;
  try
    const Head = ParseForHead(IsLexicalHead);
    const Body = ParseLoopBody(Head.OwnedNodes);
    Loop := Head.CreateStatement(Body);
  except
    if IsLexicalHead then
      FScopes.Discard;

    raise;
  end;

  if IsLexicalHead then
  begin
    FScopes.Discard;
    Loop.MayCaptureScope := (FClosureCount <> ClosureMark);
  end;

  Result := Loop;
end;

function TJSParser.ParseForHead(const IsLexicalHead: Boolean): TJSForHead;
begin
  if IsLexicalHead then
    Result := ParseLexicalForHead
  else if Check(TJSTokenType.KeywordVar) then
    Result := ParseVarForHead
  else if Check(TJSTokenType.Semicolon) then
    Result := ParseClassicForHead(nil)
  else
    Result := ParseExpressionForHead;
end;

function TJSParser.ParseLexicalForHead: TJSForHead;
begin
  const Declaration = TJSVariableDeclaration.Create;
  Declaration.Kind := CurrentDeclarationKind;
  Advance;

  try
    ParseBinding(Declaration, TJSBindingKind.Lexical, IN_OPERATOR_NOT_ALLOWED, INITIALIZER_NOT_REQUIRED);

    if Match(TJSTokenType.KeywordIn) then
    begin
      RejectForInInitializer(Declaration);
      Result := ParseForInHead(Declaration);
    end
    else if MatchOf then
    begin
      Result := ParseForOfHead(Declaration, DECLARATION_HEAD);
    end
    else
    begin
      while Match(TJSTokenType.Comma) do
      begin
        ParseBinding(Declaration, TJSBindingKind.Lexical, IN_OPERATOR_NOT_ALLOWED, INITIALIZER_NOT_REQUIRED);
      end;

      RejectMissingInitializers(Declaration);
      Result := ParseClassicForHead(Declaration);
    end;
  except
    Declaration.Free;
    raise;
  end;
end;

function TJSParser.ParseVarForHead: TJSForHead;
begin
  Advance;
  const Declaration = ParseForVarDeclarations;

  try
    if Match(TJSTokenType.KeywordIn) then
      Result := ParseForInHead(Declaration)
    else if MatchOf then
      Result := ParseForOfHead(Declaration, DECLARATION_HEAD)
    else
      Result := ParseClassicForHead(Declaration);
  except
    Declaration.Free;
    raise;
  end;
end;

function TJSParser.ParseExpressionForHead: TJSForHead;
begin
  const Mark = CoverGrammarMark;
  FInLiteralElement := True;
  const StartsWithAsyncOf = FLookahead.IsAsyncOfHead;
  const Expression = ParseExpressionWithoutIn;

  const IsForIn = Match(TJSTokenType.KeywordIn);
  const IsForOf = ((not IsForIn) and MatchOf);
  if IsForIn or IsForOf then
  begin
    Result := ParseForTargetHead(Expression, Mark, IsForOf, StartsWithAsyncOf);
    Exit;
  end;

  RejectCoverGrammarOwning(Mark, Expression);

  const Init = TJSExpressionStatement.Create(Expression);
  try
    Result := ParseClassicForHead(Init);
  except
    Init.Free;
    raise;
  end;
end;

function TJSParser.ParseForTargetHead(const Expression: TJSExpression; const Mark: TJSCoverMark;
                                      const IsForOf: Boolean; const StartsWithAsyncOf: Boolean): TJSForHead;
begin
  const IsRejectedAsyncOf = (IsForOf and StartsWithAsyncOf);
  if IsRejectedAsyncOf then
  begin
    Expression.Free;
    RaiseAtCurrentToken(ASYNC_OF_HEAD_MESSAGE);
  end;

  const Target = ConvertForInTargetOwning(Expression);
  RejectCoverGrammarOwning(Mark, Target);

  try
    if IsForOf then
      Result := ParseForOfHead(Target, EXPRESSION_HEAD)
    else
      Result := ParseForInHead(Target);
  except
    Target.Free;
    raise;
  end;
end;

function TJSParser.ParseForRightExpression(const IsForOf: Boolean): TJSExpression;
begin
  if IsForOf then
    Result := ParseAssignmentExpression
  else
    Result := ParseExpression;

  try
    Expect(TJSTokenType.RightParen);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseForInHead(const Left: TJSASTNode): TJSForHead;
begin
  const Right = ParseForRightExpression(FOR_IN_LOOP);

  Result := TJSForHead.ForIn(Left, Right);
end;

function TJSParser.ParseForOfHead(const Left: TJSASTNode; const IsDeclaration: Boolean): TJSForHead;
begin
  if IsDeclaration then
    RejectForOfInitializer(TJSVariableDeclaration(Left));

  const Right = ParseForRightExpression(FOR_OF_LOOP);

  Result := TJSForHead.ForOf(Left, Right);
end;

function TJSParser.ParseClassicForHead(const Init: TJSASTNode): TJSForHead;
begin
  var Test: TJSExpression := nil;
  var Update: TJSExpression := nil;

  try
    Expect(TJSTokenType.Semicolon);

    if not Check(TJSTokenType.Semicolon) then
      Test := ParseExpression;

    Expect(TJSTokenType.Semicolon);

    if not Check(TJSTokenType.RightParen) then
      Update := ParseExpression;

    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Test, Update]);
    raise;
  end;

  Result := TJSForHead.Classic(Init, Test, Update);
end;

function TJSParser.ParseForVarDeclarations: TJSVariableDeclaration;
begin
  Result := TJSVariableDeclaration.Create;

  try
    ParseBinding(Result, TJSBindingKind.Var_, FInOperatorAllowed, INITIALIZER_NOT_REQUIRED);

    const StartsInOrOfHead = (Check(TJSTokenType.KeywordIn) or IsContextualWord(OF_NAME));
    if StartsInOrOfHead then
      Exit;

    while Match(TJSTokenType.Comma) do
    begin
      ParseBinding(Result, TJSBindingKind.Var_, FInOperatorAllowed, INITIALIZER_NOT_REQUIRED);
    end;

    RejectMissingPatternInitializers(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.MatchOf: Boolean;
begin
  Result := IsContextualWord(OF_NAME);

  if Result then
    Advance;
end;

procedure TJSParser.RejectForOfInitializer(const Declaration: TJSVariableDeclaration);
begin
  const IsSingleBinding = (Declaration.Declarations.Count = 1);
  const HasInitializer = (IsSingleBinding and Assigned(Declaration.Declarations[0].Init));
  const IsInvalidHead = ((not IsSingleBinding) or HasInitializer);
  if IsInvalidHead then
    RaiseAtCurrentToken(FOR_OF_HEAD_MESSAGE);
end;

procedure TJSParser.RejectForInInitializer(const Declaration: TJSVariableDeclaration);
begin
  const HasInitializer = Assigned(Declaration.Declarations[0].Init);
  if HasInitializer then
    RaiseAtCurrentToken(FOR_IN_INITIALIZER_MESSAGE);
end;

function TJSParser.ConvertForInTargetOwning(const Target: TJSExpression): TJSExpression;
begin
  if TJSParserRules.IsPatternLiteral(Target) then
  begin
    Result := ConvertToAssignmentPatternOwning(Target);
    Exit;
  end;

  EnsureAssignmentTargetOwning(Target);
  Result := Target;
end;

function TJSParser.ParseReturnStatement: TJSReturnStatement;
begin
  const ReturnToken = CurrentToken;
  const IsOutsideFunction = (FFunctionDepth = 0);
  if IsOutsideFunction then
    RaiseAtToken(ILLEGAL_RETURN_MESSAGE, ReturnToken);

  Expect(TJSTokenType.KeywordReturn);

  var Argument: TJSExpression := nil;

  const ReturnsValue = ((not CurrentToken.LineTerminatorBefore) and (not ClosesStatement));
  if ReturnsValue then
    Argument := ParseExpression;

  ExpectSemicolonOwning([Argument]);

  Result := TJSReturnStatement.Create(Argument);
end;

function TJSParser.CreateLabelIdentifier(const LabelName: string): TJSIdentifier;
begin
  Result := nil;

  if not LabelName.IsEmpty then
    Result := TJSIdentifier.Create(LabelName);
end;

function TJSParser.ParseBreakStatement: TJSBreakStatement;
begin
  const KeywordToken = CurrentToken;
  Expect(TJSTokenType.KeywordBreak);

  const LabelName = ParseJumpLabel(KeywordToken);
  const HasLabel = not LabelName.IsEmpty;
  const IsInsideBreakable = ((FLoopDepth > 0) or (FSwitchDepth > 0));
  const IsIllegalBreak = ((not HasLabel) and (not IsInsideBreakable));
  if IsIllegalBreak then
    RaiseAtToken(ILLEGAL_BREAK_MESSAGE, KeywordToken);

  ExpectSemicolon;

  const LabelId = CreateLabelIdentifier(LabelName);
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
    begin
      const Message = Format(CONTINUE_TARGET_NOT_LOOP_MESSAGE, [LabelName]);
      RaiseAtToken(Message, KeywordToken);
    end;
  end
  else
  begin
    const IsOutsideLoop = (FLoopDepth = 0);
    if IsOutsideLoop then
      RaiseAtToken(ILLEGAL_CONTINUE_MESSAGE, KeywordToken);
  end;

  ExpectSemicolon;

  const LabelId = CreateLabelIdentifier(LabelName);
  Result := TJSContinueStatement.Create(LabelId);
end;

function TJSParser.ParseJumpLabel(const KeywordToken: TJSToken): string;
begin
  Result := '';

  const IsLabelOnSameLine = (Check(TJSTokenType.Identifier) and (CurrentToken.Line = KeywordToken.Line));
  if not IsLabelOnSameLine then
    Exit;

  Result := CurrentToken.Value;

  const IsDeclared = (FindActiveLabel(Result) <> NO_LABEL);
  if not IsDeclared then
  begin
    const Message = Format(UNDEFINED_LABEL_MESSAGE, [Result]);
    RaiseAtCurrentToken(Message);
  end;

  Advance;
end;

function TJSParser.FindActiveLabel(const LabelName: string): Integer;
begin
  for var Index := FActiveLabels.Count - 1 downto FLabelScopeStart do
  begin
    const IsMatchingLabel = (FActiveLabels[Index].Name = LabelName);
    if IsMatchingLabel then
      Exit(Index);
  end;

  Result := NO_LABEL;
end;

procedure TJSParser.RejectDuplicateLabel(const LabelToken: TJSToken);
begin
  const IsDuplicate = (FindActiveLabel(LabelToken.Value) <> NO_LABEL);
  if not IsDuplicate then
    Exit;

  const Message = Format(DUPLICATE_LABEL_MESSAGE, [LabelToken.Value]);
  RaiseAtToken(Message, LabelToken);
end;

procedure TJSParser.ValidateLabelledBody(const AllowFunction: Boolean);
begin
  const IsLabelledGenerator = (Check(TJSTokenType.KeywordFunction) and
                               (PeekType(1) = TJSTokenType.Multiply));
  if IsLabelledGenerator then
    RaiseAtCurrentToken(GENERATOR_DECLARATION_BODY_MESSAGE);

  if FLookahead.StartsAsyncFunction then
    RaiseAtCurrentToken(ASYNC_DECLARATION_BODY_MESSAGE);

  const IsAllowedFunction = (AllowFunction and Check(TJSTokenType.KeywordFunction) and (not FStrictMode));
  const IsRejectedDeclaration = (StartsWithDeclaration and (not IsAllowedFunction));
  if IsRejectedDeclaration then
    RaiseAtCurrentToken(LABELLED_BODY_DECLARATION_MESSAGE);
end;

function TJSParser.ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
begin
  const LabelToken = CurrentToken;
  CheckReservedIdentifier(LabelToken.Value);
  RejectDuplicateLabel(LabelToken);

  const Info = TJSLabelInfo.Create(LabelToken.Value, FLookahead.LabelsIterationStatement);

  Advance;
  Expect(TJSTokenType.Colon);
  ValidateLabelledBody(AllowFunction);

  FActiveLabels.Add(Info);
  try
    const Body = ParseStatement(AllowFunction);
    Result := TJSLabeledStatement.Create(Info.Name, Body);
  finally
    FActiveLabels.Delete(FActiveLabels.Count - 1);
  end;
end;

procedure TJSParser.RejectFunctionDeclarationBody;
begin
  if Check(TJSTokenType.KeywordFunction) then
    RaiseAtCurrentToken(FUNCTION_DECLARATION_BODY_MESSAGE);
end;

function TJSParser.ParseLoopBody(const Owned: array of TObject): TJSStatement;
begin
  Inc(FLoopDepth);
  try
    try
      RejectFunctionDeclarationBody;
      Result := ParseStatement(LABELLED_FUNCTION_NOT_ALLOWED);
    except
      FreeOwned(Owned);
      raise;
    end;
  finally
    Dec(FLoopDepth);
  end;
end;

function TJSParser.EndsSwitchCaseBody: Boolean;
begin
  Result := (CheckAny([TJSTokenType.KeywordCase, TJSTokenType.KeywordDefault, TJSTokenType.RightBrace]) or
             IsAtEnd);
end;

function TJSParser.ParseSwitchCaseLabel(const HasDefaultClause: Boolean): TJSSwitchCase;
begin
  var Test: TJSExpression := nil;

  if Match(TJSTokenType.KeywordCase) then
  begin
    Test := ParseExpression;
  end
  else
  begin
    if HasDefaultClause then
      RaiseAtCurrentToken(DUPLICATE_DEFAULT_MESSAGE);

    Expect(TJSTokenType.KeywordDefault);
  end;

  ExpectOwning(TJSTokenType.Colon, [Test]);

  Result := TJSSwitchCase.Create(Test);
end;

function TJSParser.ParseSwitchStatement: TJSSwitchStatement;
begin
  Expect(TJSTokenType.KeywordSwitch);
  Expect(TJSTokenType.LeftParen);

  const Discriminant = ParseExpression;

  ExpectOwning(TJSTokenType.RightParen, [Discriminant]);
  ExpectOwning(TJSTokenType.LeftBrace, [Discriminant]);

  Result := TJSSwitchStatement.Create(Discriminant);

  var HasDefaultClause := False;
  const ClosureMark = EnterScope(TJSParserScopeKind.Block, nil, TJSCatchBinding.None);

  Inc(FSwitchDepth);
  try
    try
      while IsInsideBlock do
      begin
        const SwitchCase = ParseSwitchCaseLabel(HasDefaultClause);
        Result.Cases.Add(SwitchCase);
        HasDefaultClause := (HasDefaultClause or (not Assigned(SwitchCase.Test)));

        while not EndsSwitchCaseBody do
        begin
          const Statement = ParseStatementListItem;
          SwitchCase.Consequent.Add(Statement);
        end;
      end;

      Expect(TJSTokenType.RightBrace);
      Result.ScopeInfo := LeaveScope(ClosureMark);
    except
      Result.Free;
      raise;
    end;
  finally
    Dec(FSwitchDepth);
  end;
end;

function TJSParser.ParseThrowStatement: TJSThrowStatement;
begin
  Expect(TJSTokenType.KeywordThrow);

  if CurrentToken.LineTerminatorBefore then
    RaiseAtCurrentToken(ILLEGAL_THROW_NEWLINE_MESSAGE);

  const Argument = ParseExpression;
  ExpectSemicolonOwning([Argument]);

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

    const HasNoClause = ((not Assigned(Handler)) and (not Assigned(Finalizer)));
    if HasNoClause then
      RaiseAtCurrentToken(MISSING_CATCH_OR_FINALLY_MESSAGE);
  except
    FreeOwned([Block, Handler, Finalizer]);
    raise;
  end;

  Result := TJSTryStatement.Create(Block, Handler, Finalizer);
end;

function TJSParser.ParseCatchClause: TJSCatchClause;
begin
  Expect(TJSTokenType.LeftParen);

  if IsPatternStart then
  begin
    Result := ParseCatchPattern;
    Exit;
  end;

  const ParameterName = ParseBindingName(TJSBindingKind.Catch);
  const Parameter = TJSIdentifier.Create(ParameterName);
  var CatchBody: TJSBlockStatement;
  try
    Expect(TJSTokenType.RightParen);
    CatchBody := ParseScopedBlock(TJSParserScopeKind.Block, nil, TJSCatchBinding.Simple(ParameterName));
  except
    Parameter.Free;
    raise;
  end;

  Result := TJSCatchClause.Create(Parameter, CatchBody);
end;

function TJSParser.ParseCatchPattern: TJSCatchClause;
begin
  const Pattern = ParseBindingTarget(TJSBindingKind.Catch);
  var CatchBody: TJSBlockStatement;

  try
    const Names = TJSPatternNames.NamesOf(Pattern);
    const DuplicateIndex = TJSParserRules.FindDuplicateIndex(Names);
    const HasDuplicate = (DuplicateIndex <> NO_DUPLICATE);
    if HasDuplicate then
    begin
      const Message = Format(DUPLICATE_BINDING_MESSAGE, [Names[DuplicateIndex]]);
      RaiseAtCurrentToken(Message);
    end;

    Expect(TJSTokenType.RightParen);
    CatchBody := ParseScopedBlock(TJSParserScopeKind.Block, nil, TJSCatchBinding.Pattern(Names));
  except
    Pattern.Free;
    raise;
  end;

  Result := TJSCatchClause.CreateWithPattern(Pattern, CatchBody);
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

function TJSParser.ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement;
begin
  EnterNesting;
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := IN_OPERATOR_ALLOWED;
  try
    Result := ParseScopedBlock(TJSParserScopeKind.Function_, Parameters, TJSCatchBinding.None);
  finally
    FInOperatorAllowed := PreviousAllowed;
    LeaveNesting;
  end;
end;

function TJSParser.ParseClassDeclaration: TJSVariableDeclaration;
begin
  const ClassNode = ParseClass(NAME_REQUIRED);
  const DeclaredName = ClassNode.Id.Name;
  const ClassId = TJSIdentifier.Create(DeclaredName);
  const Declarator = TJSVariableDeclarator.Create(ClassId, ClassNode);

  Result := TJSVariableDeclaration.Create;
  Result.Kind := TJSDeclarationKind.Let;
  Result.Declarations.Add(Declarator);
  FScopes.AddDeclaration(Result);
end;

end.
