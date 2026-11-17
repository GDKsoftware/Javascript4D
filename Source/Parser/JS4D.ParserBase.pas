unit JS4D.ParserBase;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.AST,
  JS4D.SourceContext,
  JS4D.ParserScope,
  JS4D.ParserRules,
  JS4D.ParserLookahead,
  JS4D.PatternConverter,
  JS4D.Errors,
  JS4D.ParserConstants,
  JS4D.ParserTypes;

type
  TJSParserBase = class
  protected
    FLexer: TJSLexer;
    FOwnsLexer: Boolean;
    FLookahead: TJSLookahead;
    FCoverMarks: TJSCoverGrammarMarks;
    FPatterns: TJSPatternConverter;
    FSuspendableBodies: TList<TJSBlockStatement>;
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
    FInLiteralElement: Boolean;
    FCoverInitializerCount: Integer;
    FDuplicatePrototypeCount: Integer;
    FContext: TJSSourceContext;
    FNestingDepth: Integer;
    FStackFloor: NativeUInt;
    FInGenerator: Boolean;
    FYieldForbidden: Boolean;
    FInAsync: Boolean;
    FAwaitForbidden: Boolean;

    function ParseProgram: TJSProgram; virtual; abstract;
    procedure EnterNesting;
    procedure LeaveNesting; inline;
    function SaveFunctionState: TJSFunctionState;
    procedure RestoreFunctionState(const State: TJSFunctionState);
    function SaveBodyState: TJSBodyState;
    procedure RestoreBodyState(const State: TJSBodyState);
    procedure EnterFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean; const IsAsync: Boolean);
    function EnterScope(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                        const CatchBinding: TJSCatchBinding): Integer;
    function LeaveScope(const ClosureMark: Integer): TJSScopeInfo;
    function CoverGrammarMark: TJSCoverMark;
    procedure RejectCoverGrammarOwning(const Mark: TJSCoverMark; const Node: TJSASTNode);
    function UnexpectedTokenError: Exception;
    function SyntaxErrorAtToken(const Message: string; const Token: TJSToken): Exception;
    procedure RaiseUnexpectedToken;
    procedure RaiseAtToken(const Message: string; const Token: TJSToken);
    procedure RaiseAtCurrentToken(const Message: string);
    procedure RaiseRedeclaration(const Name: string);
    procedure RejectAsyncGenerator(const IsGenerator: Boolean; const IsAsync: Boolean);
    procedure SetPosition(const Node: TJSASTNode; const Token: TJSToken);
    function ParseNested(const ParseOperand: TJSOperandParser): TJSExpression;
    function ParseWithInOperator(const ParseOperand: TJSOperandParser): TJSExpression;
    function ParseWithInOperatorSetTo(const Allowed: Boolean; const ParseOperand: TJSOperandParser): TJSExpression;
    procedure DeclareClassName(const Name: string);
    function CurrentToken: TJSToken;
    function PeekType(const Offset: Integer): TJSTokenType;
    procedure Advance;
    function Match(const TokenType: TJSTokenType): Boolean;
    function Check(const TokenType: TJSTokenType): Boolean;
    function CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
    procedure Expect(const TokenType: TJSTokenType);
    procedure ExpectOwning(const TokenType: TJSTokenType; const Owned: array of TObject);
    function ClosesStatement: Boolean;
    procedure ExpectSemicolon;
    procedure ExpectSemicolonOwning(const Owned: array of TObject);
    function IsAtEnd: Boolean;
    function IsInsideBlock: Boolean;
    function IsContextualWord(const Name: string): Boolean;
    procedure DeclareBindingName(const Name: string; const Kind: TJSBindingKind);
    procedure DeclareVarName(const Name: string);
    procedure DeclareLexicalName(const Name: string; const IsFunction: Boolean; const AllowFunctionDuplicate: Boolean);
    procedure CheckLexicalBindingName(const Name: string);
    procedure FreeOwned(const Owned: array of TObject);
    function BoundParameterNames(const Params: TObjectList<TJSIdentifier>;
                                 const ParameterInfo: TJSParameterInfo): TArray<string>;
    function ReferencesArgumentsSince(const StartTokenIndex: Integer): Boolean;
    function DirectiveEndsAt(const Offset: Integer): Boolean;
    function ScanDirectivePrologue(const FirstTokenOffset: Integer): TJSDirectivePrologue;
    procedure RejectLegacyDirectives(const Prologue: TJSDirectivePrologue);
    procedure RejectLegacyLiteralInStrictMode(const Token: TJSToken);
    procedure MarkSuspendableBody(const Body: TJSBlockStatement; const IsGenerator: Boolean;
                                  const IsAsync: Boolean = False);
    function SourceTextFrom(const StartOffset: Integer): string;
    function IsPatternStart: Boolean;
    procedure CheckBindingName(const Name: string; const Kind: TJSBindingKind);
    procedure CheckStrictModeReservedWord(const Name: string);
    procedure CheckContextualIdentifier(const Name: string);
    procedure CheckReservedIdentifier(const Name: string);
    function IsRestrictedStrictName(const Name: string): Boolean;
    procedure CheckRestrictedBindingName(const Name: string);
    procedure CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                        const ParameterInfo: TJSParameterInfo);
    procedure RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
    procedure RejectRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);

  public
    constructor Create(const Source: string); overload;
    constructor Create(const Lexer: TJSLexer); overload;
    destructor Destroy; override;

    function Parse: TJSProgram; overload;
    function Parse(const IsStrictContext: Boolean): TJSProgram; overload;
    function Parse(const IsStrictContext: Boolean; const Context: TJSSourceContext): TJSProgram; overload;

    property SuspendableBodies: TList<TJSBlockStatement> read FSuspendableBodies;
  end;

implementation

uses
  JS4D.StackGuard;

{ TJSParserBase }

constructor TJSParserBase.Create(const Source: string);
begin
  inherited Create;
  FLexer := TJSLexer.Create(Source);
  FOwnsLexer := True;
  FLexer.Tokenize;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
  FLookahead := TJSLookahead.Create(FLexer);
  FCoverMarks := TJSCoverGrammarMarks.Create;
  FPatterns := TJSPatternConverter.Create(FCoverMarks);
  FSuspendableBodies := TList<TJSBlockStatement>.Create;
end;

constructor TJSParserBase.Create(const Lexer: TJSLexer);
begin
  inherited Create;
  FLexer := Lexer;
  FOwnsLexer := False;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
  FLookahead := TJSLookahead.Create(FLexer);
  FCoverMarks := TJSCoverGrammarMarks.Create;
  FPatterns := TJSPatternConverter.Create(FCoverMarks);
  FSuspendableBodies := TList<TJSBlockStatement>.Create;
end;

destructor TJSParserBase.Destroy;
begin
  FSuspendableBodies.Free;
  FPatterns.Free;
  FCoverMarks.Free;
  FLookahead.Free;
  FScopes.Free;
  FActiveLabels.Free;

  if FOwnsLexer then
    FLexer.Free;

  inherited;
end;

function TJSParserBase.CurrentToken: TJSToken;
begin
  Result := FLexer.CurrentToken;
end;

function TJSParserBase.PeekType(const Offset: Integer): TJSTokenType;
begin
  Result := FLookahead.PeekType(Offset);
end;

procedure TJSParserBase.Advance;
begin
  FPreviousTokenLine := CurrentToken.Line;
  FLexer.NextToken;
end;

function TJSParserBase.Match(const TokenType: TJSTokenType): Boolean;
begin
  Result := Check(TokenType);

  if Result then
    Advance;
end;

function TJSParserBase.Check(const TokenType: TJSTokenType): Boolean;
begin
  Result := (CurrentToken.TokenType = TokenType);
end;

function TJSParserBase.CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
begin
  for var TokenType in TokenTypes do
  begin
    if Check(TokenType) then
      Exit(True);
  end;

  Result := False;
end;

function TJSParserBase.IsContextualWord(const Name: string): Boolean;
begin
  Result := TJSLookahead.IsContextualWord(CurrentToken, Name);
end;

function TJSParserBase.UnexpectedTokenError: Exception;
begin
  Result := TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParserBase.SyntaxErrorAtToken(const Message: string; const Token: TJSToken): Exception;
begin
  Result := TJSErrorFactory.SyntaxError(Message, Token.Line, Token.Column);
end;

procedure TJSParserBase.RaiseUnexpectedToken;
begin
  raise UnexpectedTokenError;
end;

procedure TJSParserBase.RaiseAtToken(const Message: string; const Token: TJSToken);
begin
  raise SyntaxErrorAtToken(Message, Token);
end;

procedure TJSParserBase.RaiseAtCurrentToken(const Message: string);
begin
  RaiseAtToken(Message, CurrentToken);
end;

procedure TJSParserBase.RaiseRedeclaration(const Name: string);
begin
  const Message = Format(REDECLARATION_MESSAGE, [Name]);
  RaiseAtCurrentToken(Message);
end;

procedure TJSParserBase.SetPosition(const Node: TJSASTNode; const Token: TJSToken);
begin
  Node.Line := Token.Line;
  Node.Column := Token.Column;
end;

procedure TJSParserBase.Expect(const TokenType: TJSTokenType);
begin
  if not Match(TokenType) then
    RaiseUnexpectedToken;
end;

procedure TJSParserBase.ExpectOwning(const TokenType: TJSTokenType; const Owned: array of TObject);
begin
  try
    Expect(TokenType);
  except
    FreeOwned(Owned);
    raise;
  end;
end;

function TJSParserBase.ClosesStatement: Boolean;
begin
  Result := CheckAny([TJSTokenType.Semicolon, TJSTokenType.RightBrace, TJSTokenType.EndOfFile]);
end;

procedure TJSParserBase.ExpectSemicolon;
begin
  if Match(TJSTokenType.Semicolon) then
    Exit;

  const CanInsertSemicolon = (ClosesStatement or CurrentToken.LineTerminatorBefore);
  if not CanInsertSemicolon then
    RaiseUnexpectedToken;
end;

procedure TJSParserBase.ExpectSemicolonOwning(const Owned: array of TObject);
begin
  try
    ExpectSemicolon;
  except
    FreeOwned(Owned);
    raise;
  end;
end;

function TJSParserBase.IsAtEnd: Boolean;
begin
  Result := Check(TJSTokenType.EndOfFile);
end;

function TJSParserBase.IsInsideBlock: Boolean;
begin
  Result := ((not Check(TJSTokenType.RightBrace)) and (not IsAtEnd));
end;

function TJSParserBase.EnterScope(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                              const CatchBinding: TJSCatchBinding): Integer;
begin
  FScopes.Enter(Kind, Parameters, CatchBinding);
  Result := FClosureCount;
end;

function TJSParserBase.LeaveScope(const ClosureMark: Integer): TJSScopeInfo;
begin
  Result := FScopes.Leave;

  if Assigned(Result) then
    Result.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

function TJSParserBase.CoverGrammarMark: TJSCoverMark;
begin
  Result.Initializers := FCoverInitializerCount;
  Result.DuplicatePrototypes := FDuplicatePrototypeCount;
end;

procedure TJSParserBase.RejectCoverGrammarOwning(const Mark: TJSCoverMark; const Node: TJSASTNode);
begin
  const HasInitializer = (FCoverInitializerCount <> Mark.Initializers);
  const HasDuplicatePrototype = (FDuplicatePrototypeCount <> Mark.DuplicatePrototypes);
  if not (HasInitializer or HasDuplicatePrototype) then
    Exit;

  Node.Free;

  if HasInitializer then
    RaiseAtCurrentToken(COVER_INITIALIZER_MESSAGE)
  else
    RaiseAtCurrentToken(DUPLICATE_PROTOTYPE_MESSAGE);
end;

function TJSParserBase.Parse: TJSProgram;
begin
  Result := ParseProgram;
end;

function TJSParserBase.Parse(const IsStrictContext: Boolean): TJSProgram;
begin
  FStrictMode := IsStrictContext;
  Result := ParseProgram;
end;

function TJSParserBase.Parse(const IsStrictContext: Boolean; const Context: TJSSourceContext): TJSProgram;
begin
  FContext := Context;
  Result := Parse(IsStrictContext);
end;

procedure TJSParserBase.DeclareVarName(const Name: string);
begin
  if not FScopes.TryDeclareVar(Name) then
    RaiseRedeclaration(Name);
end;

procedure TJSParserBase.DeclareLexicalName(const Name: string; const IsFunction: Boolean;
                                       const AllowFunctionDuplicate: Boolean);
begin
  if not FScopes.TryDeclareLexical(Name, IsFunction, AllowFunctionDuplicate) then
    RaiseRedeclaration(Name);
end;

procedure TJSParserBase.DeclareBindingName(const Name: string; const Kind: TJSBindingKind);
begin
  const IsVarBinding = (Kind = TJSBindingKind.Var_);
  if IsVarBinding then
    DeclareVarName(Name)
  else
    DeclareLexicalName(Name, NOT_A_FUNCTION_NAME, NO_FUNCTION_DUPLICATE);
end;

procedure TJSParserBase.CheckLexicalBindingName(const Name: string);
begin
  const IsLetName = (Name = LET_NAME);
  if IsLetName then
    RaiseAtCurrentToken(LET_BINDING_NAME_MESSAGE);

  CheckReservedIdentifier(Name);
  CheckRestrictedBindingName(Name);
end;

function TJSParserBase.SourceTextFrom(const StartOffset: Integer): string;
begin
  const LastConsumed = FLexer.PeekToken(-1);
  Result := FLexer.SourceSlice(StartOffset, LastConsumed.EndOffset);
end;

function TJSParserBase.DirectiveEndsAt(const Offset: Integer): Boolean;
begin
  const DirectiveToken = FLexer.PeekToken(Offset);
  const IsStringLiteral = (DirectiveToken.TokenType = TJSTokenType.StringLiteral);
  if not IsStringLiteral then
    Exit(False);

  const EndToken = FLexer.PeekToken(Offset + 1);
  const EndsStatement = (EndToken.TokenType in [TJSTokenType.Semicolon, TJSTokenType.RightBrace,
                                                TJSTokenType.EndOfFile]);

  Result := (EndsStatement or EndToken.LineTerminatorBefore);
end;

function TJSParserBase.ScanDirectivePrologue(const FirstTokenOffset: Integer): TJSDirectivePrologue;
begin
  Result := Default(TJSDirectivePrologue);
  var Offset := FirstTokenOffset;

  while DirectiveEndsAt(Offset) do
  begin
    const DirectiveToken = FLexer.PeekToken(Offset);
    const IsUseStrict = ((DirectiveToken.Value = USE_STRICT_DIRECTIVE) and (not DirectiveToken.HasEscape));
    if IsUseStrict then
      Result.HasUseStrict := True;

    if DirectiveToken.IsLegacyLiteral then
      Result.HasLegacyLiteral := True;

    const EndsWithSemicolon = (PeekType(Offset + 1) = TJSTokenType.Semicolon);
    Inc(Offset);
    if EndsWithSemicolon then
      Inc(Offset);
  end;
end;

procedure TJSParserBase.RejectLegacyDirectives(const Prologue: TJSDirectivePrologue);
begin
  const IsLegacyInStrictPrologue = (Prologue.HasUseStrict and Prologue.HasLegacyLiteral);
  if IsLegacyInStrictPrologue then
    RaiseAtCurrentToken(LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE);
end;

procedure TJSParserBase.RejectLegacyLiteralInStrictMode(const Token: TJSToken);
begin
  const IsLegacyInStrictMode = (FStrictMode and Token.IsLegacyLiteral);
  if IsLegacyInStrictMode then
    RaiseAtToken(LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE, Token);
end;

function TJSParserBase.SaveBodyState: TJSBodyState;
begin
  Result.StrictMode := FStrictMode;
  Result.LabelScopeStart := FLabelScopeStart;
  Result.LoopDepth := FLoopDepth;
  Result.SwitchDepth := FSwitchDepth;
end;

procedure TJSParserBase.RestoreBodyState(const State: TJSBodyState);
begin
  FStrictMode := State.StrictMode;
  FLabelScopeStart := State.LabelScopeStart;
  FLoopDepth := State.LoopDepth;
  FSwitchDepth := State.SwitchDepth;
end;

function TJSParserBase.BoundParameterNames(const Params: TObjectList<TJSIdentifier>;
                                       const ParameterInfo: TJSParameterInfo): TArray<string>;
begin
  if Assigned(ParameterInfo) then
    Result := ParameterInfo.BoundNames
  else
    Result := TJSParserRules.ParameterNames(Params);
end;

function TJSParserBase.ReferencesArgumentsSince(const StartTokenIndex: Integer): Boolean;
begin
  Result := FLexer.HasIdentifierBetween(StartTokenIndex, FLexer.TokenIndex, [ARGUMENTS_NAME, EVAL_NAME]);
end;

procedure TJSParserBase.FreeOwned(const Owned: array of TObject);
begin
  for var Node in Owned do
  begin
    Node.Free;
  end;
end;

function TJSParserBase.ParseWithInOperatorSetTo(const Allowed: Boolean;
                                            const ParseOperand: TJSOperandParser): TJSExpression;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := Allowed;
  try
    Result := ParseOperand;
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

procedure TJSParserBase.EnterNesting;
begin
  const IsStackFloorUnset = (FStackFloor = 0);
  if IsStackFloorUnset then
    FStackFloor := TJSStackGuard.CurrentFloor;

  var StackMarker: Byte;
  const IsStackExhausted = (NativeUInt(@StackMarker) < FStackFloor);
  const IsTooDeep = (FNestingDepth >= MAX_NESTING_DEPTH);
  if IsStackExhausted or IsTooDeep then
    raise TJSErrorFactory.RangeError(NESTING_TOO_DEEP_MESSAGE, CurrentToken.Line, CurrentToken.Column);

  Inc(FNestingDepth);
end;

procedure TJSParserBase.LeaveNesting;
begin
  Dec(FNestingDepth);
end;

function TJSParserBase.ParseNested(const ParseOperand: TJSOperandParser): TJSExpression;
begin
  EnterNesting;
  try
    Result := ParseOperand;
  finally
    LeaveNesting;
  end;
end;

function TJSParserBase.ParseWithInOperator(const ParseOperand: TJSOperandParser): TJSExpression;
begin
  EnterNesting;
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := IN_OPERATOR_ALLOWED;
  try
    Result := ParseOperand;
  finally
    FInOperatorAllowed := PreviousAllowed;
    LeaveNesting;
  end;
end;

procedure TJSParserBase.DeclareClassName(const Name: string);
begin
  DeclareLexicalName(Name, NOT_A_FUNCTION_NAME, NO_FUNCTION_DUPLICATE);
end;

procedure TJSParserBase.MarkSuspendableBody(const Body: TJSBlockStatement; const IsGenerator: Boolean;
                                        const IsAsync: Boolean);
begin
  if not (IsGenerator or IsAsync) then
    Exit;

  Body.IsGeneratorBody := IsGenerator;
  Body.IsAsyncBody := IsAsync;
  FSuspendableBodies.Add(Body);
end;

function TJSParserBase.SaveFunctionState: TJSFunctionState;
begin
  Result.Context := FContext;
  Result.InGenerator := FInGenerator;
  Result.YieldForbidden := FYieldForbidden;
  Result.InAsync := FInAsync;
  Result.AwaitForbidden := FAwaitForbidden;
end;

procedure TJSParserBase.RestoreFunctionState(const State: TJSFunctionState);
begin
  FContext := State.Context;
  FInGenerator := State.InGenerator;
  FYieldForbidden := State.YieldForbidden;
  FInAsync := State.InAsync;
  FAwaitForbidden := State.AwaitForbidden;
end;

procedure TJSParserBase.EnterFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                  const IsAsync: Boolean);
begin
  FContext.AllowNewTarget := True;
  FContext.AllowSuperProperty := (Context <> TJSFunctionContext.Ordinary);
  FContext.AllowSuperCall := (Context = TJSFunctionContext.DerivedConstructor);

  FInGenerator := IsGenerator;
  FYieldForbidden := IsGenerator;
  FInAsync := IsAsync;
  FAwaitForbidden := IsAsync;
end;

procedure TJSParserBase.RejectAsyncGenerator(const IsGenerator: Boolean; const IsAsync: Boolean);
begin
  const IsAsyncGenerator = (IsGenerator and IsAsync);
  if IsAsyncGenerator then
    RaiseAtCurrentToken(ASYNC_GENERATOR_MESSAGE);
end;

function TJSParserBase.IsPatternStart: Boolean;
begin
  Result := CheckAny([TJSTokenType.LeftBracket, TJSTokenType.LeftBrace]);
end;

procedure TJSParserBase.CheckBindingName(const Name: string; const Kind: TJSBindingKind);
begin
  case Kind of
    TJSBindingKind.Lexical:
      CheckLexicalBindingName(Name);
    TJSBindingKind.SimpleParameter:
      CheckReservedIdentifier(Name);
    TJSBindingKind.Var_,
    TJSBindingKind.Parameter,
    TJSBindingKind.Catch:
      begin
        CheckReservedIdentifier(Name);
        CheckRestrictedBindingName(Name);
      end;
  else
    raise ENotSupportedException.CreateFmt('Unsupported binding kind: %d', [Ord(Kind)]);
  end;
end;

procedure TJSParserBase.CheckStrictModeReservedWord(const Name: string);
begin
  const IsReserved = (FStrictMode and TJSParserRules.IsStrictReservedWord(Name));
  if not IsReserved then
    Exit;

  const Message = Format(STRICT_RESERVED_WORD_MESSAGE, [Name]);
  RaiseAtCurrentToken(Message);
end;

procedure TJSParserBase.CheckContextualIdentifier(const Name: string);
begin
  const IsYieldInGenerator = (FInGenerator and (Name = YIELD_NAME));
  if IsYieldInGenerator then
    RaiseAtCurrentToken(YIELD_IDENTIFIER_MESSAGE);

  const IsAwaitInAsync = (FInAsync and (Name = AWAIT_NAME));
  if IsAwaitInAsync then
    RaiseAtCurrentToken(AWAIT_IDENTIFIER_MESSAGE);
end;

procedure TJSParserBase.CheckReservedIdentifier(const Name: string);
begin
  CheckStrictModeReservedWord(Name);
  CheckContextualIdentifier(Name);
end;

function TJSParserBase.IsRestrictedStrictName(const Name: string): Boolean;
begin
  Result := (FStrictMode and TJSParserRules.IsRestrictedName(Name));
end;

procedure TJSParserBase.CheckRestrictedBindingName(const Name: string);
begin
  if not IsRestrictedStrictName(Name) then
    Exit;

  const Message = Format(RESTRICTED_BINDING_NAME_MESSAGE, [Name]);
  RaiseAtCurrentToken(Message);
end;

procedure TJSParserBase.CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                              const ParameterInfo: TJSParameterInfo);
begin
  if not FStrictMode then
    Exit;

  CheckReservedIdentifier(FuncName);
  CheckRestrictedBindingName(FuncName);

  for var Parameter in Params do
  begin
    CheckReservedIdentifier(Parameter.Name);
  end;

  const HasRest = (Assigned(ParameterInfo) and Assigned(ParameterInfo.Rest));
  if HasRest then
    CheckRestrictedBindingName(ParameterInfo.Rest.Name);

  RejectDuplicateParameters(Params);
  RejectRestrictedParameterNames(Params);
end;

procedure TJSParserBase.RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  const ParameterNames = TJSParserRules.ParameterNames(Params);
  const DuplicateIndex = TJSParserRules.FindDuplicateIndex(ParameterNames);
  const HasNoDuplicate = (DuplicateIndex = NO_DUPLICATE);
  if HasNoDuplicate then
    Exit;

  const Duplicate = Params[DuplicateIndex];
  raise TJSErrorFactory.SyntaxError(DUPLICATE_STRICT_PARAMETER_MESSAGE, Duplicate.Line, Duplicate.Column);
end;

procedure TJSParserBase.RejectRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);
begin
  for var Parameter in Params do
  begin
    if TJSParserRules.IsRestrictedName(Parameter.Name) then
    begin
      const Message = Format(RESTRICTED_PARAMETER_NAME_MESSAGE, [Parameter.Name]);
      raise TJSErrorFactory.SyntaxError(Message, Parameter.Line, Parameter.Column);
    end;
  end;
end;

end.
