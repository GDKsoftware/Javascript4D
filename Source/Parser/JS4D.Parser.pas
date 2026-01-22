unit JS4D.Parser;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.AST,
  JS4D.Errors;

type
  TJSParser = class
  private
    FLexer: TJSLexer;
    FOwnsLexer: Boolean;
    FStrictMode: Boolean;

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
    function ParseBlockStatement: TJSBlockStatement;
    function ParseVariableDeclaration: TJSVariableDeclaration;
    function ParseFunctionDeclaration: TJSFunctionDeclaration;
    function ParseExpressionStatement: TJSExpressionStatement;
    function ParseIfStatement: TJSIfStatement;
    function ParseWhileStatement: TJSWhileStatement;
    function ParseDoWhileStatement: TJSDoWhileStatement;
    function ParseForStatement: TJSStatement;
    function ParseReturnStatement: TJSReturnStatement;
    function ParseBreakStatement: TJSBreakStatement;
    function ParseContinueStatement: TJSContinueStatement;
    function ParseSwitchStatement: TJSSwitchStatement;
    function ParseThrowStatement: TJSThrowStatement;
    function ParseTryStatement: TJSTryStatement;
    function ParseEmptyStatement: TJSEmptyStatement;
    function ParseDebuggerStatement: TJSDebuggerStatement;

    function ParseExpression: TJSExpression;
    function ParseAssignmentExpression: TJSExpression;
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
    function ParseMemberExpression: TJSExpression;
    function ParseNewExpression: TJSExpression;
    function ParsePrimaryExpression: TJSExpression;
    function ParseArrayExpression: TJSArrayExpression;
    function ParseObjectExpression: TJSObjectExpression;
    function ParseFunctionExpression: TJSFunctionExpression;
    function ParseArguments: TObjectList<TJSExpression>;

    function IsAssignmentOperator(const TokenType: TJSTokenType): Boolean;
    function TokenToAssignmentOperator(const TokenType: TJSTokenType): TJSAssignmentOperator;

    function IsUseStrictDirective(const Statement: TJSStatement): Boolean;
    function IsStrictModeReservedWord(const Name: string): Boolean;
    procedure CheckStrictModeReservedWord(const Name: string);
    procedure CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);

  public
    constructor Create(const Source: string); overload;
    constructor Create(const Lexer: TJSLexer); overload;
    destructor Destroy; override;

    function Parse: TJSProgram;
  end;

implementation

const
  TRUE_VALUE = 'true';

{ TJSParser }

constructor TJSParser.Create(const Source: string);
begin
  inherited Create;
  FLexer := TJSLexer.Create(Source);
  FLexer.Tokenize;
  FOwnsLexer := True;
end;

constructor TJSParser.Create(const Lexer: TJSLexer);
begin
  inherited Create;
  FLexer := Lexer;
  FOwnsLexer := False;
end;

destructor TJSParser.Destroy;
begin
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
  if Check(TJSTokenType.Semicolon) then
  begin
    Advance;
    Exit;
  end;

  if Check(TJSTokenType.RightBrace) or Check(TJSTokenType.EndOfFile) then
    Exit;
end;

function TJSParser.IsAtEnd: Boolean;
begin
  Result := Check(TJSTokenType.EndOfFile);
end;

function TJSParser.Parse: TJSProgram;
begin
  Result := ParseProgram;
end;

function TJSParser.ParseProgram: TJSProgram;
begin
  Result := TJSProgram.Create;

  try
    while not IsAtEnd do
    begin
      const Statement = ParseStatement;
      Result.Body.Add(Statement);

      if (Result.Body.Count = 1) and IsUseStrictDirective(Statement) then
      begin
        FStrictMode := True;
        Result.IsStrict := True;
      end;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseStatement: TJSStatement;
begin
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
  Expect(TJSTokenType.LeftBrace);

  Result := TJSBlockStatement.Create;

  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      const Statement = ParseStatement;
      Result.Body.Add(Statement);
    end;

    Expect(TJSTokenType.RightBrace);
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
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const IdName = CurrentToken.Value;
      CheckStrictModeReservedWord(IdName);
      Advance;

      const Identifier = TJSIdentifier.Create(IdName);
      var InitExpr: TJSExpression := nil;

      if Match(TJSTokenType.Assign) then
        InitExpr := ParseAssignmentExpression;

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
  Advance;

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
    Result.Body := ParseBlockStatement;

    if (Result.Body.Body.Count > 0) and IsUseStrictDirective(Result.Body.Body[0]) then
    begin
      Result.IsStrict := True;
      FStrictMode := True;
      CheckDuplicateParameters(Result.Params);
      FStrictMode := OldStrictMode;
    end
    else
    begin
      CheckDuplicateParameters(Result.Params);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseExpressionStatement: TJSExpressionStatement;
begin
  const Expression = ParseExpression;
  ExpectSemicolon;
  Result := TJSExpressionStatement.Create(Expression);
end;

function TJSParser.ParseIfStatement: TJSIfStatement;
begin
  Expect(TJSTokenType.KeywordIf);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  Expect(TJSTokenType.RightParen);

  const Consequent = ParseStatement;
  var Alternate: TJSStatement := nil;

  if Match(TJSTokenType.KeywordElse) then
    Alternate := ParseStatement;

  Result := TJSIfStatement.Create(Test, Consequent, Alternate);
end;

function TJSParser.ParseWhileStatement: TJSWhileStatement;
begin
  Expect(TJSTokenType.KeywordWhile);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  Expect(TJSTokenType.RightParen);

  const Body = ParseStatement;

  Result := TJSWhileStatement.Create(Test, Body);
end;

function TJSParser.ParseDoWhileStatement: TJSDoWhileStatement;
begin
  Expect(TJSTokenType.KeywordDo);

  const Body = ParseStatement;

  Expect(TJSTokenType.KeywordWhile);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  Expect(TJSTokenType.RightParen);
  ExpectSemicolon;

  Result := TJSDoWhileStatement.Create(Body, Test);
end;

function TJSParser.ParseForStatement: TJSStatement;
begin
  Expect(TJSTokenType.KeywordFor);
  Expect(TJSTokenType.LeftParen);

  var Init: TJSASTNode := nil;

  if Check(TJSTokenType.KeywordVar) then
  begin
    Expect(TJSTokenType.KeywordVar);

    if not Check(TJSTokenType.Identifier) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    const VarName = CurrentToken.Value;
    Advance;

    if Match(TJSTokenType.KeywordIn) then
    begin
      const VarId = TJSIdentifier.Create(VarName);
      const VarDecl = TJSVariableDeclaration.Create;
      const Declarator = TJSVariableDeclarator.Create(VarId, nil);
      VarDecl.Declarations.Add(Declarator);

      const Right = ParseExpression;
      Expect(TJSTokenType.RightParen);

      const Body = ParseStatement;

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
    const Expr = ParseExpression;

    if Match(TJSTokenType.KeywordIn) then
    begin
      const Right = ParseExpression;
      Expect(TJSTokenType.RightParen);

      const Body = ParseStatement;

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

  const Body = ParseStatement;

  Result := TJSForStatement.Create(Init, Test, Update, Body);
end;

function TJSParser.ParseReturnStatement: TJSReturnStatement;
begin
  const Token = CurrentToken;
  Expect(TJSTokenType.KeywordReturn);

  var Argument: TJSExpression := nil;

  const HasNewLine = (CurrentToken.Line > Token.Line);
  const IsEndOfStatement = (Check(TJSTokenType.Semicolon) or Check(TJSTokenType.RightBrace) or Check(TJSTokenType.EndOfFile));

  if (not HasNewLine) and (not IsEndOfStatement) then
    Argument := ParseExpression;

  ExpectSemicolon;

  Result := TJSReturnStatement.Create(Argument);
end;

function TJSParser.ParseBreakStatement: TJSBreakStatement;
begin
  Expect(TJSTokenType.KeywordBreak);

  var LabelId: TJSIdentifier := nil;

  if Check(TJSTokenType.Identifier) then
  begin
    const LabelName = CurrentToken.Value;
    Advance;
    LabelId := TJSIdentifier.Create(LabelName);
  end;

  ExpectSemicolon;

  Result := TJSBreakStatement.Create(LabelId);
end;

function TJSParser.ParseContinueStatement: TJSContinueStatement;
begin
  Expect(TJSTokenType.KeywordContinue);

  var LabelId: TJSIdentifier := nil;

  if Check(TJSTokenType.Identifier) then
  begin
    const LabelName = CurrentToken.Value;
    Advance;
    LabelId := TJSIdentifier.Create(LabelName);
  end;

  ExpectSemicolon;

  Result := TJSContinueStatement.Create(LabelId);
end;

function TJSParser.ParseSwitchStatement: TJSSwitchStatement;
begin
  Expect(TJSTokenType.KeywordSwitch);
  Expect(TJSTokenType.LeftParen);

  const Discriminant = ParseExpression;

  Expect(TJSTokenType.RightParen);
  Expect(TJSTokenType.LeftBrace);

  Result := TJSSwitchStatement.Create(Discriminant);

  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      var Test: TJSExpression := nil;

      if Match(TJSTokenType.KeywordCase) then
        Test := ParseExpression
      else
        Expect(TJSTokenType.KeywordDefault);

      Expect(TJSTokenType.Colon);

      const SwitchCase = TJSSwitchCase.Create(Test);
      Result.Cases.Add(SwitchCase);

      while (not Check(TJSTokenType.KeywordCase)) and
            (not Check(TJSTokenType.KeywordDefault)) and
            (not Check(TJSTokenType.RightBrace)) and
            (not IsAtEnd) do
      begin
        const Statement = ParseStatement;
        SwitchCase.Consequent.Add(Statement);
      end;
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseThrowStatement: TJSThrowStatement;
begin
  Expect(TJSTokenType.KeywordThrow);

  const Argument = ParseExpression;
  ExpectSemicolon;

  Result := TJSThrowStatement.Create(Argument);
end;

function TJSParser.ParseTryStatement: TJSTryStatement;
begin
  Expect(TJSTokenType.KeywordTry);

  const Block = ParseBlockStatement;
  var Handler: TJSCatchClause := nil;
  var Finalizer: TJSBlockStatement := nil;

  if Match(TJSTokenType.KeywordCatch) then
  begin
    Expect(TJSTokenType.LeftParen);

    if not Check(TJSTokenType.Identifier) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    const ParamName = CurrentToken.Value;
    Advance;

    const Param = TJSIdentifier.Create(ParamName);

    Expect(TJSTokenType.RightParen);

    const CatchBody = ParseBlockStatement;
    Handler := TJSCatchClause.Create(Param, CatchBody);
  end;

  if Match(TJSTokenType.KeywordFinally) then
    Finalizer := ParseBlockStatement;

  if (Handler = nil) and (Finalizer = nil) then
    raise TJSErrorFactory.SyntaxError('Missing catch or finally after try', CurrentToken.Line, CurrentToken.Column);

  Result := TJSTryStatement.Create(Block, Handler, Finalizer);
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

    while Match(TJSTokenType.Comma) do
    begin
      const NextExpr = ParseAssignmentExpression;
      SeqExpr.Expressions.Add(NextExpr);
    end;

    Exit(SeqExpr);
  end;

  Result := Expr;
end;

function TJSParser.ParseAssignmentExpression: TJSExpression;
begin
  const Left = ParseConditionalExpression;

  if IsAssignmentOperator(CurrentToken.TokenType) then
  begin
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
    const Consequent = ParseAssignmentExpression;
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

  while CheckAny([TJSTokenType.LessThan, TJSTokenType.GreaterThan, TJSTokenType.LessThanOrEqual,
                  TJSTokenType.GreaterThanOrEqual, TJSTokenType.KeywordInstanceof, TJSTokenType.KeywordIn]) do
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

    Exit(TJSUpdateExpression.Create(Op, Argument, True));
  end;

  const Argument = ParseCallExpression;

  if CheckAny([TJSTokenType.Increment, TJSTokenType.Decrement]) then
  begin
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
    Exit(ParseNewExpression);

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
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const PropName = CurrentToken.Value;
      Advance;

      const Prop = TJSIdentifier.Create(PropName);
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseExpression;
      Expect(TJSTokenType.RightBracket);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else
      Break;
  end;
end;

function TJSParser.ParseMemberExpression: TJSExpression;
begin
  Result := ParsePrimaryExpression;

  while True do
  begin
    if Match(TJSTokenType.Dot) then
    begin
      if not Check(TJSTokenType.Identifier) then
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      const PropName = CurrentToken.Value;
      Advance;

      const Prop = TJSIdentifier.Create(PropName);
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseExpression;
      Expect(TJSTokenType.RightBracket);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else
      Break;
  end;
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
        Advance;
        Exit(TJSIdentifier.Create(Name));
      end;

    TJSTokenType.NumberLiteral:
      begin
        const Value = CurrentToken.NumberValue;
        const IsOctal = CurrentToken.IsOctal;

        if FStrictMode and IsOctal then
          raise TJSErrorFactory.SyntaxError('Octal literals are not allowed in strict mode',
            CurrentToken.Line, CurrentToken.Column);

        Advance;

        if IsOctal then
          Exit(TJSLiteral.CreateOctalNumber(Value))
        else
          Exit(TJSLiteral.CreateNumber(Value));
      end;

    TJSTokenType.StringLiteral:
      begin
        const Value = CurrentToken.Value;
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
        Advance;

        const SlashPos = Value.LastIndexOf('/');
        const Pattern = Value.Substring(0, SlashPos);
        const Flags = Value.Substring(SlashPos + 1);

        Exit(TJSLiteral.CreateRegExp(Pattern, Flags));
      end;

    TJSTokenType.KeywordThis:
      begin
        Advance;
        Exit(TJSThisExpression.Create);
      end;

    TJSTokenType.LeftParen:
      begin
        Advance;
        const Expr = ParseExpression;
        Expect(TJSTokenType.RightParen);
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
        const Element = ParseAssignmentExpression;
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
    while not Check(TJSTokenType.RightBrace) do
    begin
      var Key: TJSExpression;
      var Computed := False;

      if Check(TJSTokenType.StringLiteral) then
      begin
        Key := TJSLiteral.CreateString(CurrentToken.Value);
        Advance;
      end
      else if Check(TJSTokenType.NumberLiteral) then
      begin
        Key := TJSLiteral.CreateNumber(CurrentToken.NumberValue);
        Advance;
      end
      else if Check(TJSTokenType.Identifier) then
      begin
        Key := TJSIdentifier.Create(CurrentToken.Value);
        Advance;
      end
      else if Check(TJSTokenType.LeftBracket) then
      begin
        Advance;
        Key := ParseAssignmentExpression;
        Expect(TJSTokenType.RightBracket);
        Computed := True;
      end
      else
        raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

      Expect(TJSTokenType.Colon);

      const Value = ParseAssignmentExpression;
      const Prop = TJSObjectProperty.Create(Key, Value, Computed);
      Result.Properties.Add(Prop);

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
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
    const Body = ParseBlockStatement;
    Result.Body := Body;

    if (Body.Body.Count > 0) and IsUseStrictDirective(Body.Body[0]) then
    begin
      Result.IsStrict := True;
      FStrictMode := True;
      CheckDuplicateParameters(Result.Params);
      FStrictMode := OldStrictMode;
    end
    else
    begin
      CheckDuplicateParameters(Result.Params);
    end;
  except
    Result.Free;
    raise;
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
        const Arg = ParseAssignmentExpression;
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

function TJSParser.IsUseStrictDirective(const Statement: TJSStatement): Boolean;
begin
  Result := False;

  if not (Statement is TJSExpressionStatement) then
    Exit;

  const ExprStmt = TJSExpressionStatement(Statement);

  if not (ExprStmt.Expression is TJSLiteral) then
    Exit;

  const Literal = TJSLiteral(ExprStmt.Expression);

  if Literal.LiteralType <> TJSLiteralType.String_ then
    Exit;

  Result := (Literal.StringValue = 'use strict');
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

procedure TJSParser.CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  if not FStrictMode then
    Exit;

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

end.
