unit JS4D.PatternConverter;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.AST,
  JS4D.Errors,
  JS4D.ParserRules;

type
  TJSCoverGrammarMarks = class
  private
    FSpreadFollowedByComma: THashSet<TJSExpression>;
    FDuplicatePrototype: THashSet<TJSExpression>;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Forget(const Literal: TJSExpression);
    procedure MarkSpreadFollowedByComma(const Literal: TJSExpression);
    procedure MarkDuplicatePrototype(const Literal: TJSExpression);
    function HasSpreadFollowedByComma(const Literal: TJSExpression): Boolean;
    function HasDuplicatePrototype(const Literal: TJSExpression): Boolean;
  end;

  TJSPatternConverter = class
  private
    FMarks: TJSCoverGrammarMarks;
    FIsStrict: Boolean;
    FErrorLine: Integer;
    FErrorColumn: Integer;
    FConsumedCoverInitializers: Integer;
    FConsumedDuplicatePrototypes: Integer;

    procedure RaiseError(const Message: string);
    procedure RaiseInvalidTarget;
    procedure ValidateTarget(const Node: TJSExpression);
    procedure ValidateIdentifierTarget(const Node: TJSExpression);
    procedure ValidateElement(const Node: TJSExpression);
    procedure ValidateArrayPattern(const Source: TJSArrayExpression);
    procedure ValidateObjectPattern(const Source: TJSObjectExpression);
    procedure ValidateSpreadProperty(const Source: TJSObjectExpression; const Member: TJSObjectProperty);
    procedure ValidateShorthandProperty(const Member: TJSObjectProperty);
    function BuildTarget(const Node: TJSExpression): TJSExpression;
    function BuildElement(const Node: TJSExpression): TJSExpression;
    function BuildArrayPattern(const Source: TJSArrayExpression): TJSArrayPattern;
    function BuildObjectPattern(const Source: TJSObjectExpression): TJSObjectPattern;

  public
    constructor Create(const Marks: TJSCoverGrammarMarks);

    function Convert(const Node: TJSExpression; const IsStrict: Boolean; const ErrorLine: Integer;
                     const ErrorColumn: Integer): TJSExpression;

    property ConsumedCoverInitializers: Integer read FConsumedCoverInitializers;
    property ConsumedDuplicatePrototypes: Integer read FConsumedDuplicatePrototypes;
  end;

implementation

{ TJSCoverGrammarMarks }

constructor TJSCoverGrammarMarks.Create;
begin
  inherited Create;
  FSpreadFollowedByComma := THashSet<TJSExpression>.Create;
  FDuplicatePrototype := THashSet<TJSExpression>.Create;
end;

destructor TJSCoverGrammarMarks.Destroy;
begin
  FDuplicatePrototype.Free;
  FSpreadFollowedByComma.Free;
  inherited;
end;

procedure TJSCoverGrammarMarks.Forget(const Literal: TJSExpression);
begin
  FSpreadFollowedByComma.Remove(Literal);
  FDuplicatePrototype.Remove(Literal);
end;

procedure TJSCoverGrammarMarks.MarkSpreadFollowedByComma(const Literal: TJSExpression);
begin
  FSpreadFollowedByComma.Add(Literal);
end;

procedure TJSCoverGrammarMarks.MarkDuplicatePrototype(const Literal: TJSExpression);
begin
  FDuplicatePrototype.Add(Literal);
end;

function TJSCoverGrammarMarks.HasSpreadFollowedByComma(const Literal: TJSExpression): Boolean;
begin
  Result := FSpreadFollowedByComma.Contains(Literal);
end;

function TJSCoverGrammarMarks.HasDuplicatePrototype(const Literal: TJSExpression): Boolean;
begin
  Result := FDuplicatePrototype.Contains(Literal);
end;

{ TJSPatternConverter }

constructor TJSPatternConverter.Create(const Marks: TJSCoverGrammarMarks);
begin
  inherited Create;
  FMarks := Marks;
end;

procedure TJSPatternConverter.RaiseError(const Message: string);
begin
  raise TJSErrorFactory.SyntaxError(Message, FErrorLine, FErrorColumn);
end;

procedure TJSPatternConverter.RaiseInvalidTarget;
begin
  RaiseError(INVALID_DESTRUCTURING_TARGET_MESSAGE);
end;

function TJSPatternConverter.Convert(const Node: TJSExpression; const IsStrict: Boolean;
                                     const ErrorLine: Integer; const ErrorColumn: Integer): TJSExpression;
begin
  FIsStrict := IsStrict;
  FErrorLine := ErrorLine;
  FErrorColumn := ErrorColumn;
  FConsumedCoverInitializers := 0;
  FConsumedDuplicatePrototypes := 0;

  try
    ValidateTarget(Node);
  except
    Node.Free;
    raise;
  end;

  Result := BuildTarget(Node);
end;

procedure TJSPatternConverter.ValidateTarget(const Node: TJSExpression);
begin
  const IsParenthesizedLiteral = (TJSParserRules.IsLiteralNode(Node) and Node.IsParenthesized);
  if IsParenthesizedLiteral then
    RaiseInvalidTarget;

  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      ValidateArrayPattern(TJSArrayExpression(Node));
    TJSASTNodeType.ObjectExpression:
      ValidateObjectPattern(TJSObjectExpression(Node));
    TJSASTNodeType.Identifier:
      ValidateIdentifierTarget(Node);
    TJSASTNodeType.ArrayPattern,
    TJSASTNodeType.ObjectPattern,
    TJSASTNodeType.MemberExpression:
      ;
  else
    RaiseInvalidTarget;
  end;
end;

procedure TJSPatternConverter.ValidateIdentifierTarget(const Node: TJSExpression);
begin
  const IsRestricted = (FIsStrict and TJSParserRules.IsRestrictedName(TJSIdentifier(Node).Name));
  if IsRestricted then
    RaiseInvalidTarget;
end;

procedure TJSPatternConverter.ValidateElement(const Node: TJSExpression);
begin
  if TJSParserRules.IsDefaultedTarget(Node) then
    ValidateTarget(TJSAssignmentExpression(Node).Left)
  else
    ValidateTarget(Node);
end;

procedure TJSPatternConverter.ValidateArrayPattern(const Source: TJSArrayExpression);
begin
  for var Element in Source.Elements do
  begin
    if not Assigned(Element) then
      Continue;

    if Element is TJSSpreadElement then
    begin
      if FMarks.HasSpreadFollowedByComma(Source) then
        RaiseError(REST_ELEMENT_LAST_MESSAGE);

      ValidateTarget(TJSSpreadElement(Element).Argument);
    end
    else
    begin
      ValidateElement(Element);
    end;
  end;
end;

procedure TJSPatternConverter.ValidateObjectPattern(const Source: TJSObjectExpression);
begin
  for var Member in Source.Properties do
  begin
    case Member.Kind of
      TJSPropertyKind.Data:
        ValidateElement(Member.Value);
      TJSPropertyKind.Spread:
        ValidateSpreadProperty(Source, Member);
      TJSPropertyKind.Shorthand:
        ValidateShorthandProperty(Member);
    else
      RaiseInvalidTarget;
    end;
  end;
end;

procedure TJSPatternConverter.ValidateSpreadProperty(const Source: TJSObjectExpression;
                                                     const Member: TJSObjectProperty);
begin
  const IsLiteralTarget = TJSParserRules.IsLiteralNode(Member.Value);
  const IsNotLast = (FMarks.HasSpreadFollowedByComma(Source) or IsLiteralTarget);
  if IsNotLast then
    RaiseError(REST_ELEMENT_LAST_MESSAGE);

  ValidateTarget(Member.Value);
end;

procedure TJSPatternConverter.ValidateShorthandProperty(const Member: TJSObjectProperty);
begin
  const IsCoverInitializer = (Member.Value is TJSAssignmentPattern);
  if IsCoverInitializer then
    ValidateTarget(TJSAssignmentPattern(Member.Value).Target)
  else
    ValidateTarget(Member.Value);
end;

function TJSPatternConverter.BuildTarget(const Node: TJSExpression): TJSExpression;
begin
  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      Result := BuildArrayPattern(TJSArrayExpression(Node));
    TJSASTNodeType.ObjectExpression:
      Result := BuildObjectPattern(TJSObjectExpression(Node));
  else
    Result := Node;
  end;
end;

function TJSPatternConverter.BuildElement(const Node: TJSExpression): TJSExpression;
begin
  if not TJSParserRules.IsDefaultedTarget(Node) then
  begin
    Result := BuildTarget(Node);
    Exit;
  end;

  const Assignment = TJSAssignmentExpression(Node);
  const Target = Assignment.TakeLeft;
  const DefaultValue = Assignment.TakeRight;
  Assignment.Free;

  Result := TJSAssignmentPattern.Create(Target, DefaultValue);
end;

function TJSPatternConverter.BuildArrayPattern(const Source: TJSArrayExpression): TJSArrayPattern;
begin
  Result := TJSArrayPattern.Create;
  Result.Line := Source.Line;
  Result.Column := Source.Column;

  Source.Elements.OwnsObjects := False;

  for var Element in Source.Elements do
  begin
    if not Assigned(Element) then
    begin
      Result.Elements.Add(nil);
    end
    else if Element is TJSSpreadElement then
    begin
      const Rest = TJSSpreadElement(Element);
      Rest.Argument := BuildTarget(Rest.Argument);
      Result.Elements.Add(Rest);
    end
    else
    begin
      const Built = BuildElement(Element);
      Result.Elements.Add(Built);
    end;
  end;

  Source.Elements.Clear;
  FMarks.Forget(Source);
  Source.Free;
end;

function TJSPatternConverter.BuildObjectPattern(const Source: TJSObjectExpression): TJSObjectPattern;
begin
  Result := TJSObjectPattern.Create;
  Result.Line := Source.Line;
  Result.Column := Source.Column;

  Source.Properties.OwnsObjects := False;

  if FMarks.HasDuplicatePrototype(Source) then
  begin
    Inc(FConsumedDuplicatePrototypes);
    FMarks.Forget(Source);
  end;

  for var Member in Source.Properties do
  begin
    if Member.Kind = TJSPropertyKind.Spread then
    begin
      Result.Rest := Member.Value;
      Member.Value := nil;
      Member.Free;
      Continue;
    end;

    const IsCoverInitializer = (Member.Value is TJSAssignmentPattern);
    if IsCoverInitializer then
      Inc(FConsumedCoverInitializers)
    else
      Member.Value := BuildElement(Member.Value);

    Result.Properties.Add(Member);
  end;

  Source.Properties.Clear;
  Source.Free;
end;

end.
