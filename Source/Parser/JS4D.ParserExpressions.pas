unit JS4D.ParserExpressions;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.AST,
  JS4D.ParserRules,
  JS4D.Errors,
  JS4D.RegExpSyntax,
  JS4D.ParserConstants,
  JS4D.ParserTypes,
  JS4D.ParserPatterns;

type
  TJSExpressionParser = class(TJSPatternParser)
  protected
    function ParseFunctionExpression(const IsAsync: Boolean = False): TJSFunctionExpression; virtual; abstract;
    function ParseArrowFunction(const IsAsync: Boolean = False): TJSFunctionExpression; virtual; abstract;
    function ParseClass(const RequireName: Boolean): TJSClassExpression; virtual; abstract;
    function ParseAccessorFunction(const Kind: TJSPropertyKind; const SourceStart: Integer;
                                   const Context: TJSFunctionContext = TJSFunctionContext.Method):
                                   TJSFunctionExpression; virtual; abstract;
    function ParseMethodFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                 const IsAsync: Boolean;
                                 const SourceStart: Integer): TJSFunctionExpression; virtual; abstract;
    function ParseMemberName(const Owner: TJSExpression): TJSIdentifier;
    function ParseComputedMember(const Owner: TJSExpression): TJSExpression;
    function IsSuperAllowedFor(const TokenType: TJSTokenType): Boolean;
    function ParseSuperExpression: TJSExpression;
    function ParseNewTarget: TJSExpression;
    function ParseExpression: TJSExpression;
    function ParseAssignmentExpression: TJSExpression; override;
    function ParseAssignmentTail(const Left: TJSExpression;
                                 const AssignmentOperator: TJSAssignmentOperator): TJSExpression;
    function ParseAssignmentOperand: TJSExpression;
    function ParseUnaryOperand: TJSExpression;
    function ParseExponentOperand: TJSExpression;
    function ParseNewOperand: TJSExpression;
    function ParseExpressionWithoutIn: TJSExpression;
    function ParseNestedExpression: TJSExpression;
    function ParseNestedAssignmentExpression: TJSExpression; override;
    function ParseConditionalExpression: TJSExpression;
    function ParseShortCircuitExpression: TJSExpression;
    function ParseNullishCoalesceExpression(const Head: TJSExpression): TJSExpression;
    function ParseBinaryExpression(const MinPrecedence: Integer): TJSExpression;
    function ParseExponentiationExpression: TJSExpression;
    function ParseUnaryExpression: TJSExpression;
    procedure RejectStrictIdentifierDelete(const UnaryOperator: TJSUnaryOperator; const Argument: TJSExpression);
    function ParseUpdateExpression: TJSExpression;
    function ParseCallExpression: TJSExpression;
    function ParseCallArguments(const Callee: TJSExpression): TJSExpression;
    function ParseMemberStep(const Owner: TJSExpression): TJSExpression;
    function ParseMemberExpression: TJSExpression;
    function ParseNewExpression: TJSExpression;
    function IsTemplateStart: Boolean;
    function ParseTemplateLiteral: TJSTemplateLiteral;
    function ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
    procedure ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
                                const Expressions: TObjectList<TJSExpression>);
    function CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
    function ParsePrimaryExpression: TJSExpression;
    procedure NoteIdentifierReference(const Name: string);
    function ParseIdentifierReference: TJSExpression;
    function ParseNumberLiteral: TJSExpression;
    function ParseStringLiteral: TJSExpression;
    function ParseBooleanLiteral: TJSExpression;
    function ParseRegExpLiteral: TJSExpression;
    function ParseArrayExpression: TJSArrayExpression;
    function ParseObjectExpression: TJSObjectExpression;
    function ParseObjectMember: TJSObjectProperty;
    function ParseSpreadProperty: TJSObjectProperty;
    function ParseObjectMemberHead: TJSObjectMemberHead;
    function ParseMethodOrShorthandMember(const Head: TJSObjectMemberHead;
                                          const Key: TJSParsedKey): TJSObjectProperty;
    function ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
    function ParseCoverInitializedProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
    function ParseMethodProperty(const Key: TJSParsedKey; const Head: TJSObjectMemberHead): TJSObjectProperty;
    function AccessorKindOfCurrentToken: TJSPropertyKind;
    function ParseAccessorProperty: TJSObjectProperty;
    function ParseYieldExpression: TJSExpression;
    function IsYieldKeyword: Boolean;
    function IsAwaitKeyword: Boolean;
    function ParseAwaitExpression: TJSExpression;
    function ParseSpreadOrAssignmentExpression: TJSExpression;
    function ParseArguments(const Target: TObjectList<TJSExpression>): Boolean;
    class function TryGetAssignmentOperator(const TokenType: TJSTokenType;
                                            out AssignmentOperator: TJSAssignmentOperator): Boolean; static;
    class function TryGetBinaryOperator(const TokenType: TJSTokenType;
                                        out Entry: TJSBinaryOperatorEntry): Boolean; static;
    class function TryGetUnaryOperator(const TokenType: TJSTokenType;
                                       out UnaryOperator: TJSUnaryOperator): Boolean; static;
    class function TryGetUpdateOperator(const TokenType: TJSTokenType;
                                        out UpdateOperator: TJSUpdateOperator): Boolean; static;
    function StartsUnaryOperator: Boolean;
  end;

implementation

{ TJSExpressionParser }

function TJSExpressionParser.ParseExpression: TJSExpression;
begin
  const First = ParseAssignmentExpression;

  if not Check(TJSTokenType.Comma) then
  begin
    Result := First;
    Exit;
  end;

  const Sequence = TJSSequenceExpression.Create;
  Sequence.Expressions.Add(First);

  try
    while Match(TJSTokenType.Comma) do
    begin
      const Following = ParseAssignmentExpression;
      Sequence.Expressions.Add(Following);
    end;
  except
    Sequence.Free;
    raise;
  end;

  Result := Sequence;
end;

function TJSExpressionParser.ParseExpressionWithoutIn: TJSExpression;
begin
  Result := ParseWithInOperatorSetTo(IN_OPERATOR_NOT_ALLOWED, ParseExpression);
end;

function TJSExpressionParser.ParseMemberName(const Owner: TJSExpression): TJSIdentifier;
begin
  try
    Result := ParseIdentifierName;
  except
    Owner.Free;
    raise;
  end;
end;

function TJSExpressionParser.ParseComputedMember(const Owner: TJSExpression): TJSExpression;
begin
  Result := nil;
  try
    Result := ParseNestedExpression;
    Expect(TJSTokenType.RightBracket);
  except
    FreeOwned([Result, Owner]);
    raise;
  end;
end;

function TJSExpressionParser.ParseAssignmentOperand: TJSExpression;
begin
  Result := ParseNested(ParseAssignmentExpression);
end;

function TJSExpressionParser.ParseUnaryOperand: TJSExpression;
begin
  Result := ParseNested(ParseUnaryExpression);
end;

function TJSExpressionParser.ParseExponentOperand: TJSExpression;
begin
  Result := ParseNested(ParseExponentiationExpression);
end;

function TJSExpressionParser.ParseNewOperand: TJSExpression;
begin
  Result := ParseNested(ParseNewExpression);
end;

function TJSExpressionParser.ParseNestedExpression: TJSExpression;
begin
  Result := ParseWithInOperator(ParseExpression);
end;

function TJSExpressionParser.ParseNestedAssignmentExpression: TJSExpression;
begin
  Result := ParseWithInOperator(ParseAssignmentExpression);
end;

function TJSExpressionParser.ParseAssignmentExpression: TJSExpression;
begin
  const IsLiteralElement = FInLiteralElement;
  FInLiteralElement := False;
  const Mark = CoverGrammarMark;

  var AssignmentOperator: TJSAssignmentOperator;
  if IsYieldKeyword then
  begin
    Result := ParseYieldExpression;
  end
  else if FLookahead.StartsAsyncArrowFunction then
  begin
    Result := ParseArrowFunction(ASYNC_FUNCTION);
  end
  else if FLookahead.StartsArrowFunction then
  begin
    Result := ParseArrowFunction(NOT_ASYNC);
  end
  else
  begin
    Result := ParseConditionalExpression;

    if TryGetAssignmentOperator(CurrentToken.TokenType, AssignmentOperator) then
      Result := ParseAssignmentTail(Result, AssignmentOperator);

    if not IsLiteralElement then
      RejectCoverGrammarOwning(Mark, Result);
  end;
end;

function TJSExpressionParser.ParseAssignmentTail(const Left: TJSExpression;
                                       const AssignmentOperator: TJSAssignmentOperator): TJSExpression;
begin
  var Target := Left;

  const IsPatternAssignment = (TJSParserRules.IsPatternLiteral(Left) and Check(TJSTokenType.Assign));
  if IsPatternAssignment then
    Target := ConvertToAssignmentPatternOwning(Left)
  else
    EnsureAssignmentTargetOwning(Left);

  Advance;

  var Right: TJSExpression;
  try
    Right := ParseAssignmentOperand;
  except
    Target.Free;
    raise;
  end;

  Result := TJSAssignmentExpression.Create(AssignmentOperator, Target, Right);
end;

function TJSExpressionParser.ParseConditionalExpression: TJSExpression;
begin
  const Test = ParseShortCircuitExpression;

  if not Match(TJSTokenType.Question) then
  begin
    Result := Test;
    Exit;
  end;

  var Consequent: TJSExpression := nil;
  var Alternate: TJSExpression := nil;
  try
    Consequent := ParseNestedAssignmentExpression;
    Expect(TJSTokenType.Colon);
    Alternate := ParseAssignmentOperand;
  except
    FreeOwned([Test, Consequent, Alternate]);
    raise;
  end;

  Result := TJSConditionalExpression.Create(Test, Consequent, Alternate);
end;

function TJSExpressionParser.ParseShortCircuitExpression: TJSExpression;
begin
  Result := ParseBinaryExpression(PRECEDENCE_LOGICAL_OR);

  const StartsNullishChain = Check(TJSTokenType.NullishCoalesce);
  if StartsNullishChain then
    Result := ParseNullishCoalesceExpression(Result);
end;

function TJSExpressionParser.ParseNullishCoalesceExpression(const Head: TJSExpression): TJSExpression;
begin
  const HeadIsBareLogical = ((Head is TJSLogicalExpression) and (not Head.IsParenthesized));
  if HeadIsBareLogical then
  begin
    Head.Free;
    RaiseAtCurrentToken(NULLISH_MIXED_WITH_LOGICAL_MESSAGE);
  end;

  Result := Head;

  while Match(TJSTokenType.NullishCoalesce) do
  begin
    var Right: TJSExpression;
    try
      Right := ParseBinaryExpression(PRECEDENCE_BITWISE_OR);
    except
      Result.Free;
      raise;
    end;

    Result := TJSLogicalExpression.Create(TJSLogicalOperator.Nullish, Result, Right);
  end;

  const IsMixedWithLogical = (Check(TJSTokenType.LogicalOr) or Check(TJSTokenType.LogicalAnd));
  if IsMixedWithLogical then
  begin
    Result.Free;
    RaiseAtCurrentToken(NULLISH_MIXED_WITH_LOGICAL_MESSAGE);
  end;
end;

class function TJSExpressionParser.TryGetBinaryOperator(const TokenType: TJSTokenType;
                                              out Entry: TJSBinaryOperatorEntry): Boolean;
begin
  Result := True;

  case TokenType of
    TJSTokenType.LogicalOr:
      Entry := TJSBinaryOperatorEntry.Logical(PRECEDENCE_LOGICAL_OR, TJSLogicalOperator.Or_);
    TJSTokenType.LogicalAnd:
      Entry := TJSBinaryOperatorEntry.Logical(PRECEDENCE_LOGICAL_AND, TJSLogicalOperator.And_);
    TJSTokenType.BitwiseOr:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_BITWISE_OR, TJSBinaryOperator.BitwiseOr);
    TJSTokenType.BitwiseXor:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_BITWISE_XOR, TJSBinaryOperator.BitwiseXor);
    TJSTokenType.BitwiseAnd:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_BITWISE_AND, TJSBinaryOperator.BitwiseAnd);
    TJSTokenType.Equal:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_EQUALITY, TJSBinaryOperator.Equal);
    TJSTokenType.NotEqual:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_EQUALITY, TJSBinaryOperator.NotEqual);
    TJSTokenType.StrictEqual:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_EQUALITY, TJSBinaryOperator.StrictEqual);
    TJSTokenType.StrictNotEqual:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_EQUALITY, TJSBinaryOperator.StrictNotEqual);
    TJSTokenType.LessThan:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.LessThan);
    TJSTokenType.GreaterThan:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.GreaterThan);
    TJSTokenType.LessThanOrEqual:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.LessThanOrEqual);
    TJSTokenType.GreaterThanOrEqual:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.GreaterThanOrEqual);
    TJSTokenType.KeywordInstanceof:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.InstanceOf);
    TJSTokenType.KeywordIn:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_RELATIONAL, TJSBinaryOperator.In_);
    TJSTokenType.LeftShift:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_SHIFT, TJSBinaryOperator.LeftShift);
    TJSTokenType.RightShift:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_SHIFT, TJSBinaryOperator.RightShift);
    TJSTokenType.UnsignedRightShift:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_SHIFT, TJSBinaryOperator.UnsignedRightShift);
    TJSTokenType.Plus:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_ADDITIVE, TJSBinaryOperator.Add);
    TJSTokenType.Minus:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_ADDITIVE, TJSBinaryOperator.Subtract);
    TJSTokenType.Multiply:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_MULTIPLICATIVE, TJSBinaryOperator.Multiply);
    TJSTokenType.Divide:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_MULTIPLICATIVE, TJSBinaryOperator.Divide);
    TJSTokenType.Modulo:
      Entry := TJSBinaryOperatorEntry.Binary(PRECEDENCE_MULTIPLICATIVE, TJSBinaryOperator.Modulo);
  else
    Entry := Default(TJSBinaryOperatorEntry);
    Result := False;
  end;
end;

function TJSExpressionParser.ParseBinaryExpression(const MinPrecedence: Integer): TJSExpression;
begin
  Result := ParseExponentiationExpression;

  var Entry: TJSBinaryOperatorEntry;
  while TryGetBinaryOperator(CurrentToken.TokenType, Entry) do
  begin
    const IsDisallowedIn = (Check(TJSTokenType.KeywordIn) and (not FInOperatorAllowed));
    const IsBelowMinimum = (Entry.Precedence < MinPrecedence);
    if IsDisallowedIn or IsBelowMinimum then
      Break;

    Advance;

    var Right: TJSExpression;
    try
      Right := ParseBinaryExpression(Entry.Precedence + 1);
    except
      Result.Free;
      raise;
    end;

    Result := Entry.CreateExpression(Result, Right);
  end;
end;

function TJSExpressionParser.StartsUnaryOperator: Boolean;
begin
  var UnaryOperator: TJSUnaryOperator;

  Result := TryGetUnaryOperator(CurrentToken.TokenType, UnaryOperator);
end;

function TJSExpressionParser.ParseExponentiationExpression: TJSExpression;
begin
  const StartsWithUnaryOperator = (StartsUnaryOperator or IsAwaitKeyword);

  Result := ParseUnaryExpression;

  if not Check(TJSTokenType.Exponent) then
    Exit;

  if StartsWithUnaryOperator then
  begin
    Result.Free;
    RaiseAtCurrentToken(UNARY_BEFORE_EXPONENT_MESSAGE);
  end;

  Advance;

  var Right: TJSExpression;
  try
    Right := ParseExponentOperand;
  except
    Result.Free;
    raise;
  end;

  Result := TJSBinaryExpression.Create(TJSBinaryOperator.Exponent, Result, Right);
end;

class function TJSExpressionParser.TryGetUnaryOperator(const TokenType: TJSTokenType;
                                             out UnaryOperator: TJSUnaryOperator): Boolean;
begin
  Result := True;

  case TokenType of
    TJSTokenType.LogicalNot    : UnaryOperator := TJSUnaryOperator.LogicalNot;
    TJSTokenType.BitwiseNot    : UnaryOperator := TJSUnaryOperator.BitwiseNot;
    TJSTokenType.Plus          : UnaryOperator := TJSUnaryOperator.Plus;
    TJSTokenType.Minus         : UnaryOperator := TJSUnaryOperator.Minus;
    TJSTokenType.KeywordTypeof : UnaryOperator := TJSUnaryOperator.TypeOf;
    TJSTokenType.KeywordVoid   : UnaryOperator := TJSUnaryOperator.Void;
    TJSTokenType.KeywordDelete : UnaryOperator := TJSUnaryOperator.Delete;
  else
    UnaryOperator := TJSUnaryOperator.Plus;
    Result := False;
  end;
end;

class function TJSExpressionParser.TryGetUpdateOperator(const TokenType: TJSTokenType;
                                              out UpdateOperator: TJSUpdateOperator): Boolean;
begin
  Result := True;

  case TokenType of
    TJSTokenType.Increment : UpdateOperator := TJSUpdateOperator.Increment;
    TJSTokenType.Decrement : UpdateOperator := TJSUpdateOperator.Decrement;
  else
    UpdateOperator := TJSUpdateOperator.Increment;
    Result := False;
  end;
end;

procedure TJSExpressionParser.RejectStrictIdentifierDelete(const UnaryOperator: TJSUnaryOperator;
                                                 const Argument: TJSExpression);
begin
  const IsStrictIdentifierDelete = ((UnaryOperator = TJSUnaryOperator.Delete) and FStrictMode and
                                    (Argument is TJSIdentifier));
  if not IsStrictIdentifierDelete then
    Exit;

  Argument.Free;
  RaiseAtCurrentToken(DELETE_IDENTIFIER_MESSAGE);
end;

function TJSExpressionParser.ParseUnaryExpression: TJSExpression;
begin
  var UnaryOperator: TJSUnaryOperator;

  if IsAwaitKeyword then
  begin
    Result := ParseAwaitExpression;
  end
  else if TryGetUnaryOperator(CurrentToken.TokenType, UnaryOperator) then
  begin
    Advance;

    const Argument = ParseUnaryOperand;
    RejectStrictIdentifierDelete(UnaryOperator, Argument);

    Result := TJSUnaryExpression.Create(UnaryOperator, Argument, PREFIX_OPERATOR);
  end
  else
  begin
    Result := ParseUpdateExpression;
  end;
end;

function TJSExpressionParser.ParseUpdateExpression: TJSExpression;
begin
  var UpdateOperator: TJSUpdateOperator;

  if TryGetUpdateOperator(CurrentToken.TokenType, UpdateOperator) then
  begin
    Advance;

    const Operand = ParseCallExpression;
    EnsureAssignmentTargetOwning(Operand);

    Result := TJSUpdateExpression.Create(UpdateOperator, Operand, PREFIX_OPERATOR);
    Exit;
  end;

  const Argument = ParseCallExpression;
  Result := Argument;

  const IsUpdateToken = TryGetUpdateOperator(CurrentToken.TokenType, UpdateOperator);
  const IsOnSameLine = (CurrentToken.Line = FPreviousTokenLine);
  if IsUpdateToken and IsOnSameLine then
  begin
    EnsureAssignmentTargetOwning(Argument);
    Advance;

    Result := TJSUpdateExpression.Create(UpdateOperator, Argument, POSTFIX_OPERATOR);
  end;
end;

function TJSExpressionParser.ParseCallArguments(const Callee: TJSExpression): TJSExpression;
begin
  const CallNode = TJSCallExpression.Create(Callee);
  try
    CallNode.HasSpread := ParseArguments(CallNode.Arguments);
  except
    CallNode.Free;
    raise;
  end;

  Result := CallNode;
end;

function TJSExpressionParser.ParseMemberStep(const Owner: TJSExpression): TJSExpression;
begin
  if Match(TJSTokenType.Dot) then
  begin
    const MemberName = ParseMemberName(Owner);
    Result := TJSMemberExpression.Create(Owner, MemberName, PLAIN_KEY);
  end
  else if Match(TJSTokenType.LeftBracket) then
  begin
    const MemberKey = ParseComputedMember(Owner);
    Result := TJSMemberExpression.Create(Owner, MemberKey, COMPUTED_KEY);
  end
  else if IsTemplateStart then
  begin
    Result := ParseTaggedTemplate(Owner);
  end
  else
  begin
    Result := nil;
  end;
end;

function TJSExpressionParser.ParseCallExpression: TJSExpression;
begin
  Result := ParseMemberExpression;

  while True do
  begin
    var NextExpression: TJSExpression;
    if Check(TJSTokenType.LeftParen) then
      NextExpression := ParseCallArguments(Result)
    else
      NextExpression := ParseMemberStep(Result);

    if not Assigned(NextExpression) then
      Break;

    Result := NextExpression;
  end;
end;

function TJSExpressionParser.ParseMemberExpression: TJSExpression;
begin
  if Check(TJSTokenType.KeywordNew) then
    Result := ParseNewOperand
  else
    Result := ParsePrimaryExpression;

  while True do
  begin
    const NextExpression = ParseMemberStep(Result);
    if not Assigned(NextExpression) then
      Break;

    Result := NextExpression;
  end;
end;

function TJSExpressionParser.IsTemplateStart: Boolean;
begin
  Result := (Check(TJSTokenType.TemplateChunk) and CurrentToken.IsTemplateHead);
end;

function TJSExpressionParser.ParseTemplateLiteral: TJSTemplateLiteral;
begin
  Result := TJSTemplateLiteral.Create;
  SetPosition(Result, CurrentToken);

  try
    ReadTemplateParts(UNTAGGED_TEMPLATE, Result.Parts, Result.Expressions);
  except
    Result.Free;
    raise;
  end;
end;

function TJSExpressionParser.ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
begin
  const Site = TJSTemplateObject.Create;
  SetPosition(Site, CurrentToken);

  Result := TJSTaggedTemplateExpression.Create(Tag);
  SetPosition(Result, CurrentToken);
  Result.Arguments.Add(Site);

  try
    ReadTemplateParts(TAGGED_TEMPLATE, Site.Parts, Result.Arguments);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSExpressionParser.ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
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
    const ContinuesTemplate = ((Chunk.TokenType = TJSTokenType.TemplateChunk) and (not Chunk.IsTemplateHead));
    if not ContinuesTemplate then
      raise TJSErrorFactory.UnexpectedToken(Chunk.Value, Chunk.Line, Chunk.Column);
  end;
end;

function TJSExpressionParser.CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
begin
  const IsRejected = (Chunk.HasInvalidEscape and (not IsTagged));
  if IsRejected then
    RaiseAtToken(INVALID_TEMPLATE_ESCAPE_MESSAGE, Chunk);

  Result.Cooked := Chunk.Value;
  Result.Raw := Chunk.RawValue;
  Result.HasCooked := not Chunk.HasInvalidEscape;
end;

function TJSExpressionParser.ParseNewExpression: TJSExpression;
begin
  Expect(TJSTokenType.KeywordNew);

  if Check(TJSTokenType.Dot) then
  begin
    Result := ParseNewTarget;
    Exit;
  end;

  const Callee = ParseMemberExpression;
  if Callee is TJSSuperExpression then
  begin
    Callee.Free;
    RaiseAtCurrentToken(NEW_SUPER_MESSAGE);
  end;

  const NewNode = TJSNewExpression.Create(Callee);

  if Check(TJSTokenType.LeftParen) then
  begin
    try
      NewNode.HasSpread := ParseArguments(NewNode.Arguments);
    except
      NewNode.Free;
      raise;
    end;
  end;

  Result := NewNode;
end;

procedure TJSExpressionParser.NoteIdentifierReference(const Name: string);
begin
  const IsEval = (Name = EVAL_NAME);
  if IsEval then
    Inc(FClosureCount);
end;

function TJSExpressionParser.ParseIdentifierReference: TJSExpression;
begin
  if FLookahead.StartsAsyncFunction then
  begin
    Result := ParseFunctionExpression(ASYNC_FUNCTION);
    Exit;
  end;

  const Name = CurrentToken.Value;
  CheckReservedIdentifier(Name);
  NoteIdentifierReference(Name);
  Advance;

  Result := TJSIdentifier.Create(Name);
end;

function TJSExpressionParser.ParseNumberLiteral: TJSExpression;
begin
  const Value = CurrentToken.NumberValue;
  RejectLegacyLiteralInStrictMode(CurrentToken);
  Advance;

  Result := TJSLiteral.CreateNumber(Value);
end;

function TJSExpressionParser.ParseStringLiteral: TJSExpression;
begin
  const Value = CurrentToken.Value;
  RejectLegacyLiteralInStrictMode(CurrentToken);
  Advance;

  Result := TJSLiteral.CreateString(Value);
end;

function TJSExpressionParser.ParseBooleanLiteral: TJSExpression;
begin
  const Value = (CurrentToken.Value = TRUE_NAME);
  Advance;

  Result := TJSLiteral.CreateBoolean(Value);
end;

function TJSExpressionParser.ParseRegExpLiteral: TJSExpression;
begin
  const Pattern = CurrentToken.Value;
  const Flags = CurrentToken.RawValue;
  const Position = TJSSourcePosition.At(CurrentToken.Line, CurrentToken.Column);
  Advance;

  TJSRegExpSyntax.ValidateFlags(Flags, Position);
  TJSRegExpSyntax.ValidatePattern(Pattern, Flags, Position);

  Result := TJSLiteral.CreateRegExp(Pattern, Flags);
end;

function TJSExpressionParser.ParsePrimaryExpression: TJSExpression;
begin
  case CurrentToken.TokenType of
    TJSTokenType.Identifier      : Result := ParseIdentifierReference;
    TJSTokenType.NumberLiteral   : Result := ParseNumberLiteral;
    TJSTokenType.StringLiteral   : Result := ParseStringLiteral;
    TJSTokenType.BooleanLiteral  : Result := ParseBooleanLiteral;
    TJSTokenType.RegExpLiteral   : Result := ParseRegExpLiteral;
    TJSTokenType.LeftBracket     : Result := ParseArrayExpression;
    TJSTokenType.LeftBrace       : Result := ParseObjectExpression;
    TJSTokenType.KeywordFunction : Result := ParseFunctionExpression;
    TJSTokenType.KeywordClass    : Result := ParseClass(NAME_OPTIONAL);
    TJSTokenType.KeywordSuper    : Result := ParseSuperExpression;
    TJSTokenType.NullLiteral:
      begin
        Advance;
        Result := TJSLiteral.CreateNull;
      end;
    TJSTokenType.KeywordThis:
      begin
        Advance;
        Result := TJSThisExpression.Create;
      end;
    TJSTokenType.TemplateChunk:
      begin
        if not CurrentToken.IsTemplateHead then
          raise UnexpectedTokenError;

        Result := ParseTemplateLiteral;
      end;
    TJSTokenType.LeftParen:
      begin
        Advance;
        Result := ParseNestedExpression;
        ExpectOwning(TJSTokenType.RightParen, [Result]);
        Result.IsParenthesized := True;
      end;
  else
    raise UnexpectedTokenError;
  end;
end;

function TJSExpressionParser.ParseArrayExpression: TJSArrayExpression;
begin
  Expect(TJSTokenType.LeftBracket);

  Result := TJSArrayExpression.Create;
  FCoverMarks.Forget(Result);

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
        FInLiteralElement := True;
        const Element = ParseSpreadOrAssignmentExpression;
        Result.Elements.Add(Element);

        const IsSpread = (Element is TJSSpreadElement);
        Result.HasSpread := (Result.HasSpread or IsSpread);

        const IsSpreadBeforeComma = (IsSpread and Check(TJSTokenType.Comma));
        if IsSpreadBeforeComma then
          FCoverMarks.MarkSpreadFollowedByComma(Result);

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

function TJSExpressionParser.ParseObjectExpression: TJSObjectExpression;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSObjectExpression.Create;
  FCoverMarks.Forget(Result);

  try
    var HasPrototypeSetter := False;

    while not Check(TJSTokenType.RightBrace) do
    begin
      const Member = ParseObjectMember;
      Result.Properties.Add(Member);

      const IsDuplicatePrototype = (Member.SetsPrototype and HasPrototypeSetter);
      const IsFirstDuplicate = (IsDuplicatePrototype and (not FCoverMarks.HasDuplicatePrototype(Result)));
      if IsFirstDuplicate then
      begin
        FCoverMarks.MarkDuplicatePrototype(Result);
        Inc(FDuplicatePrototypeCount);
      end;

      HasPrototypeSetter := (HasPrototypeSetter or Member.SetsPrototype);

      const IsSpreadBeforeComma = ((Member.Kind = TJSPropertyKind.Spread) and Check(TJSTokenType.Comma));
      if IsSpreadBeforeComma then
        FCoverMarks.MarkSpreadFollowedByComma(Result);

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSExpressionParser.ParseSpreadProperty: TJSObjectProperty;
begin
  const SpreadValue = ParseNestedAssignmentExpression;

  Result := TJSObjectProperty.Create(nil, SpreadValue, PLAIN_KEY, TJSPropertyKind.Spread);
end;

function TJSExpressionParser.ParseObjectMemberHead: TJSObjectMemberHead;
begin
  Result.SourceStart := CurrentToken.StartOffset;

  const IsAsync = FLookahead.StartsAsyncModifier;
  if IsAsync then
    Advance;

  const IsGenerator = Match(TJSTokenType.Multiply);
  RejectAsyncGenerator(IsGenerator, IsAsync);

  Result.IsAsync := IsAsync;
  Result.IsGenerator := IsGenerator;
  Result.KeyIsIdentifier := (Check(TJSTokenType.Identifier) and (not IsGenerator) and (not IsAsync));
  Result.KeyText := CurrentToken.Value;
end;

function TJSExpressionParser.ParseObjectMember: TJSObjectProperty;
begin
  if Match(TJSTokenType.Ellipsis) then
  begin
    Result := ParseSpreadProperty;
    Exit;
  end;

  if FLookahead.StartsAccessorProperty then
  begin
    Result := ParseAccessorProperty;
    Exit;
  end;

  const Head = ParseObjectMemberHead;
  const Key = ParsePropertyKey;
  try
    const IsModifierWithoutMethod = (Head.HasModifier and (not Check(TJSTokenType.LeftParen)));
    if IsModifierWithoutMethod then
      RaiseUnexpectedToken;

    if Match(TJSTokenType.Colon) then
    begin
      FInLiteralElement := True;
      const Value = ParseNestedAssignmentExpression;
      Result := TJSObjectProperty.Create(Key.Expression, Value, Key.Computed);
    end
    else
    begin
      Result := ParseMethodOrShorthandMember(Head, Key);
    end;
  except
    Key.Expression.Free;
    raise;
  end;
end;

function TJSExpressionParser.ParseMethodOrShorthandMember(const Head: TJSObjectMemberHead;
                                                const Key: TJSParsedKey): TJSObjectProperty;
begin
  if Check(TJSTokenType.LeftParen) then
  begin
    Result := ParseMethodProperty(Key, Head);
    Exit;
  end;

  const IsPlainIdentifierKey = (Head.KeyIsIdentifier and (not Key.Computed));

  const EndsMember = (Check(TJSTokenType.Comma) or Check(TJSTokenType.RightBrace));
  if IsPlainIdentifierKey and EndsMember then
  begin
    Result := ParseShorthandProperty(Key.Expression, Head.KeyText);
    Exit;
  end;

  const IsCoverInitializer = (IsPlainIdentifierKey and Check(TJSTokenType.Assign));
  if IsCoverInitializer then
  begin
    Result := ParseCoverInitializedProperty(Key.Expression, Head.KeyText);
    Exit;
  end;

  raise UnexpectedTokenError;
end;

function TJSExpressionParser.ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
begin
  CheckReservedIdentifier(Name);
  NoteIdentifierReference(Name);

  const Value = TJSIdentifier.Create(Name);
  Result := TJSObjectProperty.Create(Key, Value, PLAIN_KEY, TJSPropertyKind.Shorthand);
end;

function TJSExpressionParser.ParseCoverInitializedProperty(const Key: TJSExpression;
                                                           const Name: string): TJSObjectProperty;
begin
  CheckReservedIdentifier(Name);
  Expect(TJSTokenType.Assign);

  const DefaultValue = ParseNestedAssignmentExpression;
  const Target = TJSIdentifier.Create(Name);
  const Value = TJSAssignmentPattern.Create(Target, DefaultValue);

  Inc(FCoverInitializerCount);
  Result := TJSObjectProperty.Create(Key, Value, PLAIN_KEY, TJSPropertyKind.Shorthand);
end;

function TJSExpressionParser.ParseMethodProperty(const Key: TJSParsedKey;
                                                 const Head: TJSObjectMemberHead): TJSObjectProperty;
begin
  const Func = ParseMethodFunction(TJSFunctionContext.Method, Head.IsGenerator, Head.IsAsync, Head.SourceStart);

  Result := TJSObjectProperty.Create(Key.Expression, Func, Key.Computed, TJSPropertyKind.Method);
end;

function TJSExpressionParser.AccessorKindOfCurrentToken: TJSPropertyKind;
begin
  const IsSetter = (CurrentToken.Value = KEYWORD_SET);
  if IsSetter then
    Result := TJSPropertyKind.Setter
  else
    Result := TJSPropertyKind.Getter;
end;

function TJSExpressionParser.ParseAccessorProperty: TJSObjectProperty;
begin
  const SourceStart = CurrentToken.StartOffset;
  const Kind = AccessorKindOfCurrentToken;
  Advance;

  const Key = ParsePropertyKey;
  try
    const Func = ParseAccessorFunction(Kind, SourceStart);
    Result := TJSObjectProperty.Create(Key.Expression, Func, Key.Computed, Kind);
  except
    Key.Expression.Free;
    raise;
  end;
end;

function TJSExpressionParser.IsSuperAllowedFor(const TokenType: TJSTokenType): Boolean;
begin
  case TokenType of
    TJSTokenType.LeftParen:
      Result := FContext.AllowSuperCall;
    TJSTokenType.Dot,
    TJSTokenType.LeftBracket:
      Result := FContext.AllowSuperProperty;
  else
    Result := False;
  end;
end;

function TJSExpressionParser.ParseSuperExpression: TJSExpression;
begin
  const SuperToken = CurrentToken;
  Expect(TJSTokenType.KeywordSuper);

  const IsAllowed = IsSuperAllowedFor(CurrentToken.TokenType);
  if not IsAllowed then
    RaiseAtToken(SUPER_OUTSIDE_METHOD_MESSAGE, SuperToken);

  Result := TJSSuperExpression.Create;
end;

function TJSExpressionParser.ParseNewTarget: TJSExpression;
begin
  const DotToken = CurrentToken;
  Expect(TJSTokenType.Dot);

  if not IsContextualWord(TARGET_NAME) then
    RaiseUnexpectedToken;

  if not FContext.AllowNewTarget then
    RaiseAtToken(NEW_TARGET_OUTSIDE_FUNCTION_MESSAGE, DotToken);

  Advance;
  Result := TJSNewTargetExpression.Create;
end;

function TJSExpressionParser.IsYieldKeyword: Boolean;
begin
  Result := (FInGenerator and CurrentToken.IsIdentifierNamed(YIELD_NAME));
end;

function TJSExpressionParser.ParseYieldExpression: TJSExpression;
begin
  const YieldToken = CurrentToken;
  if FYieldForbidden then
    RaiseAtToken(YIELD_IN_PARAMETERS_MESSAGE, YieldToken);

  if YieldToken.HasEscape then
    RaiseAtToken(YIELD_ESCAPE_MESSAGE, YieldToken);

  Advance;

  var IsDelegate := False;
  var Argument: TJSExpression := nil;

  const HasLineBreak = CurrentToken.LineTerminatorBefore;
  const CanDelegate = (not HasLineBreak);
  if CanDelegate and Match(TJSTokenType.Multiply) then
  begin
    IsDelegate := True;
    Argument := ParseAssignmentOperand;
  end
  else if FLookahead.StartsYieldOperand then
  begin
    Argument := ParseAssignmentOperand;
  end;

  Result := TJSYieldExpression.Create(Argument, IsDelegate);
  SetPosition(Result, YieldToken);
end;

function TJSExpressionParser.IsAwaitKeyword: Boolean;
begin
  Result := (FInAsync and CurrentToken.IsIdentifierNamed(AWAIT_NAME));
end;

function TJSExpressionParser.ParseAwaitExpression: TJSExpression;
begin
  const AwaitToken = CurrentToken;
  if FAwaitForbidden then
    RaiseAtToken(AWAIT_IN_PARAMETERS_MESSAGE, AwaitToken);

  if AwaitToken.HasEscape then
    RaiseAtToken(AWAIT_ESCAPE_MESSAGE, AwaitToken);

  Advance;

  const Argument = ParseUnaryOperand;
  Result := TJSAwaitExpression.Create(Argument);
  SetPosition(Result, AwaitToken);
end;

function TJSExpressionParser.ParseArguments(const Target: TObjectList<TJSExpression>): Boolean;
begin
  Expect(TJSTokenType.LeftParen);

  Result := False;

  if not Check(TJSTokenType.RightParen) then
  begin
    repeat
      const HasTrailingComma = Check(TJSTokenType.RightParen);
      if HasTrailingComma then
        Break;

      const Argument = ParseSpreadOrAssignmentExpression;
      Target.Add(Argument);
      Result := (Result or (Argument is TJSSpreadElement));
    until not Match(TJSTokenType.Comma);
  end;

  Expect(TJSTokenType.RightParen);
end;

function TJSExpressionParser.ParseSpreadOrAssignmentExpression: TJSExpression;
begin
  const IsSpread = Match(TJSTokenType.Ellipsis);
  if not IsSpread then
  begin
    Result := ParseNestedAssignmentExpression;
    Exit;
  end;

  const Argument = ParseNestedAssignmentExpression;
  Result := TJSSpreadElement.Create(Argument);
end;

class function TJSExpressionParser.TryGetAssignmentOperator(const TokenType: TJSTokenType;
                                                  out AssignmentOperator: TJSAssignmentOperator): Boolean;
begin
  Result := True;

  case TokenType of
    TJSTokenType.Assign                  : AssignmentOperator := TJSAssignmentOperator.Assign;
    TJSTokenType.PlusAssign              : AssignmentOperator := TJSAssignmentOperator.AddAssign;
    TJSTokenType.MinusAssign             : AssignmentOperator := TJSAssignmentOperator.SubtractAssign;
    TJSTokenType.MultiplyAssign          : AssignmentOperator := TJSAssignmentOperator.MultiplyAssign;
    TJSTokenType.DivideAssign            : AssignmentOperator := TJSAssignmentOperator.DivideAssign;
    TJSTokenType.ModuloAssign            : AssignmentOperator := TJSAssignmentOperator.ModuloAssign;
    TJSTokenType.ExponentAssign          : AssignmentOperator := TJSAssignmentOperator.ExponentAssign;
    TJSTokenType.BitwiseAndAssign        : AssignmentOperator := TJSAssignmentOperator.BitwiseAndAssign;
    TJSTokenType.BitwiseOrAssign         : AssignmentOperator := TJSAssignmentOperator.BitwiseOrAssign;
    TJSTokenType.BitwiseXorAssign        : AssignmentOperator := TJSAssignmentOperator.BitwiseXorAssign;
    TJSTokenType.LeftShiftAssign         : AssignmentOperator := TJSAssignmentOperator.LeftShiftAssign;
    TJSTokenType.RightShiftAssign        : AssignmentOperator := TJSAssignmentOperator.RightShiftAssign;
    TJSTokenType.UnsignedRightShiftAssign: AssignmentOperator := TJSAssignmentOperator.UnsignedRightShiftAssign;
  else
    AssignmentOperator := TJSAssignmentOperator.Assign;
    Result := False;
  end;
end;

end.
