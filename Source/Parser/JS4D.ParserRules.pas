unit JS4D.ParserRules;

{$SCOPEDENUMS ON}

interface

uses
  System.StrUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.AST;

const
  ARGUMENTS_NAME = 'arguments';
  EVAL_NAME = 'eval';
  LET_NAME = 'let';
  STATIC_NAME = 'static';
  ASYNC_NAME = 'async';
  AWAIT_NAME = 'await';
  OF_NAME = 'of';
  KEYWORD_GET = 'get';
  KEYWORD_SET = 'set';
  INVALID_DESTRUCTURING_TARGET_MESSAGE = 'Invalid destructuring assignment target';
  REST_ELEMENT_LAST_MESSAGE = 'Rest element must be last element';
  NO_DUPLICATE = -1;

type
  TJSParserRules = class
  private
    class function FindDuplicateInSmallList(const Names: TArray<string>): Integer; static;
    class function FindDuplicateInLargeList(const Names: TArray<string>): Integer; static;

  public
    class function IsStrictReservedWord(const Name: string): Boolean; static;
    class function IsRestrictedName(const Name: string): Boolean; static;
    class function FindDuplicateIndex(const Names: TArray<string>): Integer; static;
    class function ParameterNames(const Params: TObjectList<TJSIdentifier>): TArray<string>; static;
    class function IsLiteralNode(const Node: TJSExpression): Boolean; static;
    class function IsPatternLiteral(const Node: TJSExpression): Boolean; static;
    class function IsDefaultedTarget(const Node: TJSExpression): Boolean; static;
  end;

implementation

const
  STRICT_RESERVED_WORDS: array[0..8] of string = ('implements', 'interface', LET_NAME, 'package', 'private',
                                                  'protected', 'public', STATIC_NAME, YIELD_NAME);
  SMALL_NAME_LIST_LENGTH = 16;

class function TJSParserRules.IsStrictReservedWord(const Name: string): Boolean;
begin
  Result := MatchStr(Name, STRICT_RESERVED_WORDS);
end;

class function TJSParserRules.IsRestrictedName(const Name: string): Boolean;
begin
  Result := ((Name = EVAL_NAME) or (Name = ARGUMENTS_NAME));
end;

class function TJSParserRules.FindDuplicateInSmallList(const Names: TArray<string>): Integer;
begin
  for var Index := 1 to Length(Names) - 1 do
  begin
    for var EarlierIndex := 0 to Index - 1 do
    begin
      const IsDuplicate = (Names[EarlierIndex] = Names[Index]);
      if IsDuplicate then
        Exit(Index);
    end;
  end;

  Result := NO_DUPLICATE;
end;

class function TJSParserRules.FindDuplicateInLargeList(const Names: TArray<string>): Integer;
begin
  const SeenNames = THashSet<string>.Create;
  try
    for var Index := 0 to Length(Names) - 1 do
    begin
      const IsNew = SeenNames.Add(Names[Index]);
      if not IsNew then
        Exit(Index);
    end;
  finally
    SeenNames.Free;
  end;

  Result := NO_DUPLICATE;
end;

class function TJSParserRules.FindDuplicateIndex(const Names: TArray<string>): Integer;
begin
  const IsSmallList = (Length(Names) <= SMALL_NAME_LIST_LENGTH);
  if IsSmallList then
    Result := FindDuplicateInSmallList(Names)
  else
    Result := FindDuplicateInLargeList(Names);
end;

class function TJSParserRules.ParameterNames(const Params: TObjectList<TJSIdentifier>): TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    for var Param in Params do
    begin
      Names.Add(Param.Name);
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

class function TJSParserRules.IsLiteralNode(const Node: TJSExpression): Boolean;
begin
  Result := ((Node is TJSArrayExpression) or (Node is TJSObjectExpression));
end;

class function TJSParserRules.IsPatternLiteral(const Node: TJSExpression): Boolean;
begin
  Result := (IsLiteralNode(Node) and (not Node.IsParenthesized));
end;

class function TJSParserRules.IsDefaultedTarget(const Node: TJSExpression): Boolean;
begin
  const IsAssignment = (Node.NodeType = TJSASTNodeType.AssignmentExpression);
  if not IsAssignment then
    Exit(False);

  const IsPlainAssign = (TJSAssignmentExpression(Node).Operator = TJSAssignmentOperator.Assign);

  Result := (IsPlainAssign and (not Node.IsParenthesized));
end;

end.
