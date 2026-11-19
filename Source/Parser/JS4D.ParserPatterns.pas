unit JS4D.ParserPatterns;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Tokens,
  JS4D.AST,
  JS4D.ParserRules,
  JS4D.ParserConstants,
  JS4D.ParserTypes,
  JS4D.ParserBase;

type
  TJSPatternParser = class(TJSParserBase)
  protected
    function ParseNestedAssignmentExpression: TJSExpression; virtual; abstract;
    function ParseAssignmentExpression: TJSExpression; virtual; abstract;
    procedure ParseBinding(const Declaration: TJSVariableDeclaration; const Kind: TJSBindingKind;
                           const AllowIn: Boolean; const RequireInitializer: Boolean);
    function ParseDeclaredIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
    function ParseBindingInitializer(const AllowIn: Boolean; const RequireInitializer: Boolean): TJSExpression;
    procedure DeclarePatternNames(const Pattern: TJSExpression; const Kind: TJSBindingKind);
    procedure RejectMissingPatternInitializers(const Declaration: TJSVariableDeclaration);
    procedure RejectMissingInitializers(const Declaration: TJSVariableDeclaration);
    function ParseIdentifierName: TJSIdentifier;
    function ParsePropertyKey: TJSParsedKey;
    function ParseBindingName(const Kind: TJSBindingKind): string;
    function ParseBindingIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
    function ParseBindingTarget(const Kind: TJSBindingKind): TJSExpression;
    function ParseBindingElement(const Kind: TJSBindingKind): TJSExpression;
    function ParseArrayBindingPattern(const Kind: TJSBindingKind): TJSArrayPattern;
    function ParseObjectBindingPattern(const Kind: TJSBindingKind): TJSObjectPattern;
    function ParseBindingProperty(const Kind: TJSBindingKind): TJSObjectProperty;
    function ParseShorthandBinding(const Key: TJSExpression; const KeyText: string;
                                   const Kind: TJSBindingKind): TJSObjectProperty;
    function ConvertToAssignmentPatternOwning(const Node: TJSExpression): TJSExpression;
    function IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
    procedure EnsureAssignmentTargetOwning(const Target: TJSExpression);
  end;

implementation

{ TJSPatternParser }

procedure TJSPatternParser.DeclarePatternNames(const Pattern: TJSExpression; const Kind: TJSBindingKind);
begin
  for var Name in TJSPatternNames.NamesOf(Pattern) do
  begin
    DeclareBindingName(Name, Kind);
  end;
end;

function TJSPatternParser.ParseDeclaredIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
begin
  if not Check(TJSTokenType.Identifier) then
    RaiseUnexpectedToken;

  const Name = CurrentToken.Value;
  CheckBindingName(Name, Kind);
  DeclareBindingName(Name, Kind);
  Advance;

  Result := TJSIdentifier.Create(Name);
end;

function TJSPatternParser.ParseBindingInitializer(const AllowIn: Boolean;
                                                  const RequireInitializer: Boolean): TJSExpression;
begin
  Result := nil;

  if Match(TJSTokenType.Assign) then
  begin
    Result := ParseWithInOperatorSetTo(AllowIn, ParseAssignmentExpression);
    Exit;
  end;

  if RequireInitializer then
    RaiseAtCurrentToken(MISSING_CONST_INITIALIZER_MESSAGE);
end;

procedure TJSPatternParser.ParseBinding(const Declaration: TJSVariableDeclaration; const Kind: TJSBindingKind;
                                 const AllowIn: Boolean; const RequireInitializer: Boolean);
begin
  const IsPattern = IsPatternStart;
  var Identifier: TJSIdentifier := nil;
  var Pattern: TJSExpression := nil;

  if IsPattern then
    Pattern := ParseBindingTarget(Kind)
  else
    Identifier := ParseDeclaredIdentifier(Kind);

  var Initializer: TJSExpression;
  try
    if IsPattern then
      DeclarePatternNames(Pattern, Kind);

    Initializer := ParseBindingInitializer(AllowIn, (RequireInitializer and (not IsPattern)));
  except
    Pattern.Free;
    Identifier.Free;
    raise;
  end;

  if IsPattern then
  begin
    const PatternDeclarator = TJSVariableDeclarator.CreateWithPattern(Pattern, Initializer);
    Declaration.Declarations.Add(PatternDeclarator);
  end
  else
  begin
    const NamedDeclarator = TJSVariableDeclarator.Create(Identifier, Initializer);
    Declaration.Declarations.Add(NamedDeclarator);
  end;
end;

procedure TJSPatternParser.RejectMissingPatternInitializers(const Declaration: TJSVariableDeclaration);
begin
  for var Declarator in Declaration.Declarations do
  begin
    const IsMissingInitializer = (Assigned(Declarator.Pattern) and (not Assigned(Declarator.Init)));
    if IsMissingInitializer then
      RaiseAtCurrentToken(MISSING_PATTERN_INITIALIZER_MESSAGE);
  end;
end;

procedure TJSPatternParser.RejectMissingInitializers(const Declaration: TJSVariableDeclaration);
begin
  const IsConst = (Declaration.Kind = TJSDeclarationKind.Const_);

  for var Declarator in Declaration.Declarations do
  begin
    const IsMissingConstInitializer = (IsConst and (not Assigned(Declarator.Init)));
    if IsMissingConstInitializer then
      RaiseAtCurrentToken(MISSING_CONST_INITIALIZER_MESSAGE);
  end;

  RejectMissingPatternInitializers(Declaration);
end;

function TJSPatternParser.ParseIdentifierName: TJSIdentifier;
begin
  if not TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
    RaiseUnexpectedToken;

  Result := TJSIdentifier.Create(CurrentToken.Value);
  Advance;
end;

function TJSPatternParser.ParsePropertyKey: TJSParsedKey;
begin
  Result.Computed := False;

  if Check(TJSTokenType.StringLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result.Expression := TJSLiteral.CreateString(CurrentToken.Value);
    Advance;
  end
  else if Check(TJSTokenType.NumberLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result.Expression := TJSLiteral.CreateNumber(CurrentToken.NumberValue);
    Advance;
  end
  else if TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
  begin
    Result.Expression := ParseIdentifierName;
  end
  else if Check(TJSTokenType.LeftBracket) then
  begin
    Advance;
    Result.Expression := ParseNestedAssignmentExpression;
    Result.Computed := True;
    try
      Expect(TJSTokenType.RightBracket);
    except
      Result.Expression.Free;
      raise;
    end;
  end
  else
  begin
    raise UnexpectedTokenError;
  end;
end;

function TJSPatternParser.ParseBindingName(const Kind: TJSBindingKind): string;
begin
  if not Check(TJSTokenType.Identifier) then
    RaiseUnexpectedToken;

  Result := CurrentToken.Value;
  CheckBindingName(Result, Kind);
  Advance;
end;

function TJSPatternParser.ParseBindingIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
begin
  const Name = ParseBindingName(Kind);

  Result := TJSIdentifier.Create(Name);
end;

function TJSPatternParser.ParseBindingTarget(const Kind: TJSBindingKind): TJSExpression;
begin
  const IsArrayPattern = Check(TJSTokenType.LeftBracket);
  if not IsPatternStart then
  begin
    Result := ParseBindingIdentifier(Kind);
    Exit;
  end;

  EnterNesting;
  try
    if IsArrayPattern then
      Result := ParseArrayBindingPattern(Kind)
    else
      Result := ParseObjectBindingPattern(Kind);
  finally
    LeaveNesting;
  end;
end;

function TJSPatternParser.ParseBindingElement(const Kind: TJSBindingKind): TJSExpression;
begin
  const Target = ParseBindingTarget(Kind);
  if not Check(TJSTokenType.Assign) then
  begin
    Result := Target;
    Exit;
  end;

  try
    Advance;
    const DefaultValue = ParseNestedAssignmentExpression;
    Result := TJSAssignmentPattern.Create(Target, DefaultValue);
  except
    Target.Free;
    raise;
  end;
end;

function TJSPatternParser.ParseArrayBindingPattern(const Kind: TJSBindingKind): TJSArrayPattern;
begin
  Expect(TJSTokenType.LeftBracket);

  Result := TJSArrayPattern.Create;

  try
    while not Check(TJSTokenType.RightBracket) do
    begin
      if Check(TJSTokenType.Comma) then
      begin
        Result.Elements.Add(nil);
        Advance;
        Continue;
      end;

      if Match(TJSTokenType.Ellipsis) then
      begin
        const RestTarget = ParseBindingTarget(Kind);
        const RestElement = TJSSpreadElement.Create(RestTarget);
        Result.Elements.Add(RestElement);

        if not Check(TJSTokenType.RightBracket) then
          RaiseAtCurrentToken(REST_ELEMENT_LAST_MESSAGE);

        Break;
      end;

      const Element = ParseBindingElement(Kind);
      Result.Elements.Add(Element);

      if not Check(TJSTokenType.RightBracket) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBracket);
  except
    Result.Free;
    raise;
  end;
end;

function TJSPatternParser.ParseObjectBindingPattern(const Kind: TJSBindingKind): TJSObjectPattern;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSObjectPattern.Create;

  try
    while not Check(TJSTokenType.RightBrace) do
    begin
      if Match(TJSTokenType.Ellipsis) then
      begin
        Result.Rest := ParseBindingIdentifier(Kind);

        if not Check(TJSTokenType.RightBrace) then
          RaiseAtCurrentToken(REST_ELEMENT_LAST_MESSAGE);

        Break;
      end;

      const Member = ParseBindingProperty(Kind);
      Result.Properties.Add(Member);

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSPatternParser.ParseBindingProperty(const Kind: TJSBindingKind): TJSObjectProperty;
begin
  const KeyIsIdentifier = Check(TJSTokenType.Identifier);
  const KeyText = CurrentToken.Value;

  const Key = ParsePropertyKey;
  try
    if Match(TJSTokenType.Colon) then
    begin
      const Value = ParseBindingElement(Kind);
      Result := TJSObjectProperty.Create(Key.Expression, Value, Key.Computed);
    end
    else
    begin
      const IsShorthand = (KeyIsIdentifier and (not Key.Computed));
      if not IsShorthand then
        raise UnexpectedTokenError;

      Result := ParseShorthandBinding(Key.Expression, KeyText, Kind);
    end;
  except
    Key.Expression.Free;
    raise;
  end;
end;

function TJSPatternParser.ParseShorthandBinding(const Key: TJSExpression; const KeyText: string;
                                         const Kind: TJSBindingKind): TJSObjectProperty;
begin
  CheckBindingName(KeyText, Kind);

  var Value: TJSExpression := TJSIdentifier.Create(KeyText);
  if Match(TJSTokenType.Assign) then
  begin
    try
      const DefaultValue = ParseNestedAssignmentExpression;
      Value := TJSAssignmentPattern.Create(Value, DefaultValue);
    except
      Value.Free;
      raise;
    end;
  end;

  Result := TJSObjectProperty.Create(Key, Value, PLAIN_KEY, TJSPropertyKind.Shorthand);
end;

function TJSPatternParser.ConvertToAssignmentPatternOwning(const Node: TJSExpression): TJSExpression;
begin
  Result := FPatterns.Convert(Node, FStrictMode, CurrentToken.Line, CurrentToken.Column);

  Dec(FCoverInitializerCount, FPatterns.ConsumedCoverInitializers);
  Dec(FDuplicatePrototypeCount, FPatterns.ConsumedDuplicatePrototypes);
end;

function TJSPatternParser.IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
begin
  if Target is TJSTaggedTemplateExpression then
  begin
    Result := False;
    Exit;
  end;

  case Target.NodeType of
    TJSASTNodeType.CallExpression:
      Result := (not FStrictMode);
    TJSASTNodeType.Identifier:
      Result := (not IsRestrictedStrictName(TJSIdentifier(Target).Name));
    TJSASTNodeType.MemberExpression:
      Result := True;
  else
    Result := False;
  end;
end;

procedure TJSPatternParser.EnsureAssignmentTargetOwning(const Target: TJSExpression);
begin
  if IsValidAssignmentTarget(Target) then
    Exit;

  Target.Free;
  RaiseAtCurrentToken(INVALID_ASSIGNMENT_TARGET_MESSAGE);
end;

end.
