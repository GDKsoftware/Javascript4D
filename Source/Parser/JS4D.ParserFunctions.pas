unit JS4D.ParserFunctions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.AST,
  JS4D.ParserRules,
  JS4D.Errors,
  JS4D.ParserConstants,
  JS4D.ParserTypes,
  JS4D.ParserBase,
  JS4D.ParserExpressions;

type
  TJSFunctionParser = class(TJSExpressionParser)
  protected
    function ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement; virtual; abstract;
    function ParseClass(const RequireName: Boolean): TJSClassExpression; override;
    function ParseClassDefinition(const RequireName: Boolean; const SourceStart: Integer): TJSClassExpression;
    procedure ParseClassHeritage(const Target: TJSClassExpression);
    procedure ParseClassBody(const Target: TJSClassExpression);
    procedure ParseClassMember(const Target: TJSClassExpression);
    function ParseClassMemberKind(const HasModifier: Boolean): TJSPropertyKind;
    function KeyTextOf(const Key: TJSParsedKey): string;
    procedure ValidateClassMember(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
    procedure ValidateClassMemberName(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
    class function ClassFunctionContext(const IsConstructor: Boolean;
                                        const HasSuperClass: Boolean): TJSFunctionContext; static;
    function ParseClassMemberFunction(const Target: TJSClassExpression;
                                      const Head: TJSClassMemberHead): TJSFunctionExpression;
    procedure AddClassMember(const Target: TJSClassExpression; const Key: TJSParsedKey;
                             const Func: TJSFunctionExpression; const Head: TJSClassMemberHead);
    function ParseMethodFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                 const IsAsync: Boolean; const SourceStart: Integer): TJSFunctionExpression; override;
    function ParseFunctionHead(const IsAsync: Boolean; const AllowGenerator: Boolean): TJSFunctionHead;
    function ParseFunctionBodyAndHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                        const ParameterInfo: TJSParameterInfo; const IsGenerator: Boolean;
                                        const IsAsync: Boolean; const HeaderInAsync: Boolean): TJSBlockStatement;
    function ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>;
                                    const ParameterInfo: TJSParameterInfo): TJSBlockStatement;
    function ParseAccessorFunction(const Kind: TJSPropertyKind; const SourceStart: Integer;
                                   const Context: TJSFunctionContext = TJSFunctionContext.Method):
                                   TJSFunctionExpression; override;
    function ParseFunctionExpression(const IsAsync: Boolean = False): TJSFunctionExpression; override;
    procedure CheckFunctionExpressionName(const FuncName: string; const IsGenerator: Boolean;
                                          const IsAsync: Boolean);
    procedure ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression;
                                            const Context: TJSFunctionContext = TJSFunctionContext.Ordinary;
                                            const IsGenerator: Boolean = False;
                                            const IsAsync: Boolean = False);
    procedure ParseSignatureAndBodyInContext(const Func: TJSFunctionExpression; const IsGenerator: Boolean;
                                             const IsAsync: Boolean);
    function ParseArrowFunction(const IsAsync: Boolean = False): TJSFunctionExpression; override;
    procedure ParseArrowParameters(const Func: TJSFunctionExpression);
    procedure ParseArrowParameter(const Func: TJSFunctionExpression);
    function ParseFormalParameters(const Params: TObjectList<TJSIdentifier>): TJSParameterInfo;
    procedure ParseFormalParameter(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
    procedure ParseRestParameter(const Info: TJSParameterInfo);
    procedure RejectDuplicateNonSimpleParameters(const Info: TJSParameterInfo);
    procedure CollectBoundNames(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
    procedure ParseArrowBody(const Func: TJSFunctionExpression);
    procedure ParseArrowBlockBody(const Func: TJSFunctionExpression);
    procedure ParseArrowConciseBody(const Func: TJSFunctionExpression);
    function ParseConciseBody: TJSBlockStatement;
    procedure RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
  end;

implementation

{ TJSFunctionParser }

function TJSFunctionParser.ParseFunctionHead(const IsAsync: Boolean; const AllowGenerator: Boolean): TJSFunctionHead;
begin
  Result.SourceStart := CurrentToken.StartOffset;
  if IsAsync then
    Advance;

  Expect(TJSTokenType.KeywordFunction);

  Result.IsGenerator := Match(TJSTokenType.Multiply);
  const IsRejectedGenerator = (Result.IsGenerator and (not AllowGenerator));
  if IsRejectedGenerator then
    RaiseAtCurrentToken(GENERATOR_DECLARATION_BODY_MESSAGE);

  RejectAsyncGenerator(Result.IsGenerator, IsAsync);
end;

function TJSFunctionParser.ParseFunctionBodyAndHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                              const ParameterInfo: TJSParameterInfo; const IsGenerator: Boolean;
                                              const IsAsync: Boolean; const HeaderInAsync: Boolean): TJSBlockStatement;
begin
  FYieldForbidden := False;
  FAwaitForbidden := False;
  Inc(FClosureCount);

  const OuterStrictMode = FStrictMode;
  Result := ParseFunctionBodyBlock(Params, ParameterInfo);

  try
    MarkSuspendableBody(Result, IsGenerator, IsAsync);

    if Result.DeclaresStrictMode then
      FStrictMode := True;

    FInAsync := HeaderInAsync;
    CheckStrictFunctionHeader(FuncName, Params, ParameterInfo);
  except
    Result.Free;
    raise;
  end;

  FStrictMode := OuterStrictMode;
end;

function TJSFunctionParser.ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>;
                                          const ParameterInfo: TJSParameterInfo): TJSBlockStatement;
begin
  const ParameterNames = BoundParameterNames(Params, ParameterInfo);
  const OuterState = SaveBodyState;

  var DeclaresStrictMode := False;
  if Check(TJSTokenType.LeftBrace) then
  begin
    const Prologue = ScanDirectivePrologue(FUNCTION_BODY_FIRST_TOKEN_OFFSET);
    RejectLegacyDirectives(Prologue);
    DeclaresStrictMode := Prologue.HasUseStrict;
  end;

  Inc(FFunctionDepth);

  if DeclaresStrictMode then
    FStrictMode := True;

  FLabelScopeStart := FActiveLabels.Count;
  FLoopDepth := 0;
  FSwitchDepth := 0;
  try
    const HasNonSimpleParameters = Assigned(ParameterInfo);
    if DeclaresStrictMode and HasNonSimpleParameters then
      RaiseAtCurrentToken(STRICT_NON_SIMPLE_PARAMETERS_MESSAGE);

    const StartTokenIndex = FLexer.TokenIndex;
    Result := ParseNestedBlockStatement(ParameterNames);
    Result.DeclaresStrictMode := DeclaresStrictMode;
    Result.ParameterInfo := ParameterInfo;
    Result.ReferencesArguments := (ReferencesArgumentsSince(StartTokenIndex) or
                                   (HasNonSimpleParameters and ParameterInfo.ReferencesArguments));
  finally
    Dec(FFunctionDepth);
    RestoreBodyState(OuterState);
  end;
end;

function TJSFunctionParser.ParseMethodFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                       const IsAsync: Boolean; const SourceStart: Integer): TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;
  try
    ParseFunctionSignatureAndBody(Result, Context, IsGenerator, IsAsync);
    RejectDuplicateParameters(Result.Params);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

function TJSFunctionParser.ParseAccessorFunction(const Kind: TJSPropertyKind; const SourceStart: Integer;
                                         const Context: TJSFunctionContext): TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;

  try
    const AccessorToken = CurrentToken;

    ParseFunctionSignatureAndBody(Result, Context);

    var ExpectedParamCount := GETTER_PARAMETER_COUNT;
    const IsSetter = (Kind = TJSPropertyKind.Setter);
    if IsSetter then
      ExpectedParamCount := SETTER_PARAMETER_COUNT;

    const Info = Result.ParameterInfo;
    const HasRest = (Assigned(Info) and Assigned(Info.Rest));
    const HasExpectedParams = ((Result.Params.Count = ExpectedParamCount) and (not HasRest));
    if not HasExpectedParams then
      RaiseAtToken(ACCESSOR_PARAMETER_COUNT_MESSAGE, AccessorToken);

    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

function TJSFunctionParser.ParseClass(const RequireName: Boolean): TJSClassExpression;
begin
  const SourceStart = CurrentToken.StartOffset;
  Expect(TJSTokenType.KeywordClass);
  EnterNesting;

  const OuterStrictMode = FStrictMode;
  FStrictMode := True;
  try
    Result := ParseClassDefinition(RequireName, SourceStart);
  finally
    FStrictMode := OuterStrictMode;
    LeaveNesting;
  end;
end;

function TJSFunctionParser.ParseClassDefinition(const RequireName: Boolean;
                                                const SourceStart: Integer): TJSClassExpression;
begin
  Result := TJSClassExpression.Create;
  try
    const HasName = Check(TJSTokenType.Identifier);
    const IsMissingName = (RequireName and (not HasName));
    if IsMissingName then
      RaiseUnexpectedToken;

    if HasName then
    begin
      const Name = CurrentToken.Value;
      CheckLexicalBindingName(Name);

      if RequireName then
        DeclareClassName(Name);

      Result.Id := TJSIdentifier.Create(Name);
      Advance;
    end;

    Inc(FClosureCount);
    ParseClassHeritage(Result);
    ParseClassBody(Result);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSFunctionParser.ParseClassHeritage(const Target: TJSClassExpression);
begin
  if Match(TJSTokenType.KeywordExtends) then
    Target.SuperClass := ParseCallExpression;
end;

procedure TJSFunctionParser.ParseClassBody(const Target: TJSClassExpression);
begin
  Expect(TJSTokenType.LeftBrace);

  while not Check(TJSTokenType.RightBrace) do
  begin
    ParseClassMember(Target);
  end;

  Expect(TJSTokenType.RightBrace);
end;

function TJSFunctionParser.ParseClassMemberKind(const HasModifier: Boolean): TJSPropertyKind;
begin
  const IsAccessor = ((not HasModifier) and FLookahead.StartsAccessorProperty);
  if not IsAccessor then
  begin
    Result := TJSPropertyKind.Method;
    Exit;
  end;

  Result := AccessorKindOfCurrentToken;
  Advance;
end;

function TJSFunctionParser.KeyTextOf(const Key: TJSParsedKey): string;
begin
  if Key.Computed then
    Result := ''
  else
    Result := TJSObjectProperty.KeyName(Key.Expression);
end;

procedure TJSFunctionParser.ParseClassMember(const Target: TJSClassExpression);
begin
  if Match(TJSTokenType.Semicolon) then
    Exit;

  var Head := Default(TJSClassMemberHead);
  Head.IsStatic := FLookahead.StartsStaticModifier;
  if Head.IsStatic then
    Advance;

  Head.SourceStart := CurrentToken.StartOffset;
  Head.IsAsync := FLookahead.StartsAsyncModifier;
  if Head.IsAsync then
    Advance;

  Head.IsGenerator := Match(TJSTokenType.Multiply);
  RejectAsyncGenerator(Head.IsGenerator, Head.IsAsync);

  const HasModifier = (Head.IsGenerator or Head.IsAsync);
  Head.Kind := ParseClassMemberKind(HasModifier);

  const Key = ParsePropertyKey;
  Head.Computed := Key.Computed;
  Head.KeyText := KeyTextOf(Key);

  var Func: TJSFunctionExpression;
  try
    ValidateClassMember(Target, Head);
    Func := ParseClassMemberFunction(Target, Head);
  except
    Key.Expression.Free;
    raise;
  end;

  AddClassMember(Target, Key, Func, Head);
end;

procedure TJSFunctionParser.ValidateClassMember(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
begin
  const IsField = (not Check(TJSTokenType.LeftParen));
  if IsField then
    RaiseAtCurrentToken(CLASS_FIELD_MESSAGE);

  ValidateClassMemberName(Target, Head);

  const IsSpecialConstructor = (Head.IsConstructor and (Head.IsGenerator or Head.IsAsync));
  if IsSpecialConstructor then
    RaiseAtCurrentToken(CONSTRUCTOR_NOT_PLAIN_MESSAGE);
end;

procedure TJSFunctionParser.ValidateClassMemberName(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
begin
  const IsPlainMethod = (Head.Kind = TJSPropertyKind.Method);
  const IsSpecialConstructor = (Head.IsConstructor and (not IsPlainMethod));
  if IsSpecialConstructor then
    RaiseAtCurrentToken(SPECIAL_CONSTRUCTOR_MESSAGE);

  const IsDuplicateConstructor = (Head.IsConstructor and Assigned(Target.Constructor_));
  if IsDuplicateConstructor then
    RaiseAtCurrentToken(DUPLICATE_CONSTRUCTOR_MESSAGE);

  const IsStaticPrototype = (Head.IsStatic and (Head.KeyText = PROTOTYPE_NAME));
  if IsStaticPrototype then
    RaiseAtCurrentToken(STATIC_PROTOTYPE_MESSAGE);
end;

class function TJSFunctionParser.ClassFunctionContext(const IsConstructor: Boolean;
                                              const HasSuperClass: Boolean): TJSFunctionContext;
begin
  const IsDerivedConstructor = (IsConstructor and HasSuperClass);
  if IsDerivedConstructor then
    Result := TJSFunctionContext.DerivedConstructor
  else
    Result := TJSFunctionContext.Method;
end;

function TJSFunctionParser.ParseClassMemberFunction(const Target: TJSClassExpression;
                                            const Head: TJSClassMemberHead): TJSFunctionExpression;
begin
  const IsAccessor = (Head.Kind <> TJSPropertyKind.Method);
  if IsAccessor then
  begin
    Result := ParseAccessorFunction(Head.Kind, Head.SourceStart);
    Exit;
  end;

  const HasSuperClass = Assigned(Target.SuperClass);
  const Context = ClassFunctionContext(Head.IsConstructor, HasSuperClass);

  Result := ParseMethodFunction(Context, Head.IsGenerator, Head.IsAsync, Head.SourceStart);
end;

procedure TJSFunctionParser.AddClassMember(const Target: TJSClassExpression; const Key: TJSParsedKey;
                                   const Func: TJSFunctionExpression; const Head: TJSClassMemberHead);
begin
  if Head.IsConstructor then
  begin
    Target.Constructor_ := Func;
    Key.Expression.Free;
    Exit;
  end;

  const Member = TJSClassMember.Create(Key.Expression, Func, Head.Computed, Head.IsStatic, Head.Kind);
  Target.Members.Add(Member);
end;

function TJSFunctionParser.ParseFunctionExpression(const IsAsync: Boolean): TJSFunctionExpression;
begin
  const Head = ParseFunctionHead(IsAsync, GENERATOR_ALLOWED);

  Result := TJSFunctionExpression.Create;

  try
    if Check(TJSTokenType.Identifier) then
    begin
      const FuncName = CurrentToken.Value;
      CheckFunctionExpressionName(FuncName, Head.IsGenerator, IsAsync);

      Advance;
      Result.Id := TJSIdentifier.Create(FuncName);
    end;

    ParseFunctionSignatureAndBody(Result, TJSFunctionContext.Ordinary, Head.IsGenerator, IsAsync);
    Result.SourceText := SourceTextFrom(Head.SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSFunctionParser.CheckFunctionExpressionName(const FuncName: string; const IsGenerator: Boolean;
                                                const IsAsync: Boolean);
begin
  const OuterState = SaveFunctionState;
  FInGenerator := IsGenerator;
  FInAsync := IsAsync;
  try
    CheckReservedIdentifier(FuncName);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSFunctionParser.ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression;
                                                  const Context: TJSFunctionContext;
                                                  const IsGenerator: Boolean; const IsAsync: Boolean);
begin
  const OuterState = SaveFunctionState;
  EnterFunction(Context, IsGenerator, IsAsync);
  Func.IsGenerator := IsGenerator;
  Func.IsAsync := IsAsync;
  try
    ParseSignatureAndBodyInContext(Func, IsGenerator, IsAsync);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSFunctionParser.ParseSignatureAndBodyInContext(const Func: TJSFunctionExpression;
                                                           const IsGenerator: Boolean;
                                                           const IsAsync: Boolean);
begin
  Func.ParameterInfo := ParseFormalParameters(Func.Params);

  var FuncName := '';
  if Assigned(Func.Id) then
    FuncName := Func.Id.Name;

  const Body = ParseFunctionBodyAndHeader(FuncName, Func.Params, Func.ParameterInfo, IsGenerator, IsAsync, IsAsync);
  Func.Body := Body;
  Func.IsStrict := Body.DeclaresStrictMode;
end;

function TJSFunctionParser.ParseFormalParameters(const Params: TObjectList<TJSIdentifier>): TJSParameterInfo;
begin
  Expect(TJSTokenType.LeftParen);

  const StartTokenIndex = FLexer.TokenIndex;
  const Info = TJSParameterInfo.Create;
  try
    while not Check(TJSTokenType.RightParen) do
    begin
      if Check(TJSTokenType.Ellipsis) then
      begin
        ParseRestParameter(Info);
        Break;
      end;

      ParseFormalParameter(Params, Info);

      if not Check(TJSTokenType.RightParen) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightParen);

    const IsSimple = ((not Info.HasDefaults) and (not Info.HasPatterns) and (not Assigned(Info.Rest)));
    if IsSimple then
    begin
      Info.Free;
      Result := nil;
      Exit;
    end;

    CollectBoundNames(Params, Info);
    RejectDuplicateNonSimpleParameters(Info);
    Info.ReferencesArguments := ReferencesArgumentsSince(StartTokenIndex);
    Result := Info;
  except
    Info.Free;
    raise;
  end;
end;

procedure TJSFunctionParser.ParseFormalParameter(const Params: TObjectList<TJSIdentifier>;
                                                 const Info: TJSParameterInfo);
begin
  if IsPatternStart then
  begin
    const Pattern = ParseBindingTarget(TJSBindingKind.Parameter);
    Info.Patterns.Add(Pattern);
    Info.HasPatterns := True;

    const PlaceholderName = Format(PATTERN_PARAMETER_FORMAT, [Params.Count]);
    const Placeholder = TJSIdentifier.Create(PlaceholderName);
    Params.Add(Placeholder);
  end
  else
  begin
    const ParameterName = ParseBindingName(TJSBindingKind.SimpleParameter);

    const Parameter = TJSIdentifier.Create(ParameterName);
    Info.Patterns.Add(nil);
    Params.Add(Parameter);
  end;

  const HasDefault = Match(TJSTokenType.Assign);
  if not HasDefault then
  begin
    Info.Defaults.Add(nil);
    if not Info.HasDefaults then
      Info.ExpectedArgumentCount := Info.ExpectedArgumentCount + 1;
    Exit;
  end;

  Info.HasDefaults := True;
  const DefaultValue = ParseNestedAssignmentExpression;
  Info.Defaults.Add(DefaultValue);
end;

procedure TJSFunctionParser.ParseRestParameter(const Info: TJSParameterInfo);
begin
  Expect(TJSTokenType.Ellipsis);

  if IsPatternStart then
  begin
    Info.RestPattern := ParseBindingTarget(TJSBindingKind.Parameter);
    Info.HasPatterns := True;
    Info.Rest := TJSIdentifier.Create(REST_PATTERN_NAME);
  end
  else
  begin
    const RestName = ParseBindingName(TJSBindingKind.SimpleParameter);
    Info.Rest := TJSIdentifier.Create(RestName);
  end;

  const ClosesParameters = Check(TJSTokenType.RightParen);
  if not ClosesParameters then
    RaiseAtCurrentToken(REST_PARAMETER_NOT_LAST_MESSAGE);
end;

procedure TJSFunctionParser.CollectBoundNames(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
begin
  const Names = TList<string>.Create;
  try
    for var Index := 0 to Params.Count - 1 do
    begin
      const Pattern = Info.Patterns[Index];
      if Assigned(Pattern) then
        TJSPatternNames.Collect(Pattern, Names)
      else
        Names.Add(Params[Index].Name);
    end;

    if Assigned(Info.RestPattern) then
      TJSPatternNames.Collect(Info.RestPattern, Names)
    else if Assigned(Info.Rest) then
      Names.Add(Info.Rest.Name);

    Info.BoundNames := Names.ToArray;
  finally
    Names.Free;
  end;
end;

procedure TJSFunctionParser.RejectDuplicateNonSimpleParameters(const Info: TJSParameterInfo);
begin
  const DuplicateIndex = TJSParserRules.FindDuplicateIndex(Info.BoundNames);
  const HasDuplicate = (DuplicateIndex <> NO_DUPLICATE);
  if HasDuplicate then
    RaiseAtCurrentToken(DUPLICATE_NON_SIMPLE_PARAMETER_MESSAGE);
end;

function TJSFunctionParser.ParseArrowFunction(const IsAsync: Boolean): TJSFunctionExpression;
begin
  const SourceStart = CurrentToken.StartOffset;
  if IsAsync then
    Advance;

  Result := TJSFunctionExpression.Create;
  Result.IsArrow := True;
  Result.IsAsync := IsAsync;

  try
    ParseArrowParameters(Result);

    const HasLineBreakBeforeArrow = CurrentToken.LineTerminatorBefore;
    if HasLineBreakBeforeArrow then
      RaiseUnexpectedToken;

    Expect(TJSTokenType.Arrow);
    Inc(FClosureCount);

    ParseArrowBody(Result);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSFunctionParser.ParseArrowParameters(const Func: TJSFunctionExpression);
begin
  const OuterState = SaveFunctionState;
  FInAsync := (FInAsync or Func.IsAsync);
  FAwaitForbidden := FInAsync;
  try
    if Check(TJSTokenType.LeftParen) then
    begin
      FYieldForbidden := FInGenerator;
      Func.ParameterInfo := ParseFormalParameters(Func.Params);
    end
    else
    begin
      ParseArrowParameter(Func);
    end;
  finally
    RestoreFunctionState(OuterState);
  end;

  RejectDuplicateArrowParameters(Func.Params);
end;

procedure TJSFunctionParser.ParseArrowParameter(const Func: TJSFunctionExpression);
begin
  const ParameterName = ParseBindingName(TJSBindingKind.SimpleParameter);
  const Parameter = TJSIdentifier.Create(ParameterName);
  Func.Params.Add(Parameter);
end;

procedure TJSFunctionParser.ParseArrowBody(const Func: TJSFunctionExpression);
begin
  const OldStrictMode = FStrictMode;
  const OuterState = SaveFunctionState;
  FInGenerator := False;
  FInAsync := Func.IsAsync;
  FAwaitForbidden := False;
  try
    const HasBlockBody = Check(TJSTokenType.LeftBrace);
    if HasBlockBody then
      ParseArrowBlockBody(Func)
    else
      ParseArrowConciseBody(Func);

    CheckStrictFunctionHeader('', Func.Params, Func.ParameterInfo);
  finally
    FStrictMode := OldStrictMode;
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSFunctionParser.ParseArrowBlockBody(const Func: TJSFunctionExpression);
begin
  const Body = ParseFunctionBodyBlock(Func.Params, Func.ParameterInfo);
  Func.Body := Body;
  MarkSuspendableBody(Body, NOT_A_GENERATOR, Func.IsAsync);

  if Body.DeclaresStrictMode then
  begin
    Func.IsStrict := True;
    FStrictMode := True;
  end;
end;

procedure TJSFunctionParser.ParseArrowConciseBody(const Func: TJSFunctionExpression);
begin
  const Body = ParseConciseBody;
  Body.ParameterInfo := Func.ParameterInfo;
  Func.Body := Body;
  MarkSuspendableBody(Body, NOT_A_GENERATOR, Func.IsAsync);
end;

function TJSFunctionParser.ParseConciseBody: TJSBlockStatement;
begin
  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := True;

  try
    const Argument = ParseAssignmentOperand;
    const ReturnStatement = TJSReturnStatement.Create(Argument);
    Result.Body.Add(ReturnStatement);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSFunctionParser.RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
begin
  const ParameterNames = TJSParserRules.ParameterNames(Params);
  const DuplicateIndex = TJSParserRules.FindDuplicateIndex(ParameterNames);
  const HasNoDuplicate = (DuplicateIndex = NO_DUPLICATE);
  if HasNoDuplicate then
    Exit;

  const Duplicate = Params[DuplicateIndex];
  raise TJSErrorFactory.SyntaxError(DUPLICATE_ARROW_PARAMETER_MESSAGE, Duplicate.Line, Duplicate.Column);
end;

end.
