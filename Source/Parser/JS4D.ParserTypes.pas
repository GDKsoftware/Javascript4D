unit JS4D.ParserTypes;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.AST,
  JS4D.SourceContext;

type
  TJSBindingKind = (Var_, Lexical, Parameter, SimpleParameter, Catch);

  TJSLabelInfo = record
    Name: string;
    LabelsIteration: Boolean;

    class function Create(const Name: string; const LabelsIteration: Boolean): TJSLabelInfo; static;
  end;

  TJSFunctionContext = (Ordinary, Method, DerivedConstructor);

  TJSFunctionState = record
    Context: TJSSourceContext;
    InGenerator: Boolean;
    YieldForbidden: Boolean;
    InAsync: Boolean;
    AwaitForbidden: Boolean;
  end;

  TJSBodyState = record
    StrictMode: Boolean;
    LabelScopeStart: Integer;
    LoopDepth: Integer;
    SwitchDepth: Integer;
  end;

  TJSDirectivePrologue = record
    HasUseStrict: Boolean;
    HasLegacyLiteral: Boolean;
  end;

  TJSCoverMark = record
    Initializers: Integer;
    DuplicatePrototypes: Integer;
  end;

  TJSParsedKey = record
    Expression: TJSExpression;
    Computed: Boolean;
  end;

  TJSFunctionHead = record
    SourceStart: Integer;
    IsGenerator: Boolean;
  end;

  TJSObjectMemberHead = record
    SourceStart: Integer;
    IsGenerator: Boolean;
    IsAsync: Boolean;
    KeyIsIdentifier: Boolean;
    KeyText: string;

    function HasModifier: Boolean;
  end;

  TJSClassMemberHead = record
    KeyText: string;
    IsStatic: Boolean;
    IsGenerator: Boolean;
    IsAsync: Boolean;
    Computed: Boolean;
    Kind: TJSPropertyKind;
    SourceStart: Integer;

    function IsConstructor: Boolean;
  end;

  TJSForKind = (ClassicLoop, InLoop, OfLoop);

  TJSForHead = record
    Kind: TJSForKind;
    Left: TJSASTNode;
    Right: TJSExpression;
    Update: TJSExpression;

    class function Classic(const Init: TJSASTNode; const Test: TJSExpression;
                           const Update: TJSExpression): TJSForHead; static;
    class function ForIn(const Left: TJSASTNode; const Right: TJSExpression): TJSForHead; static;
    class function ForOf(const Left: TJSASTNode; const Right: TJSExpression): TJSForHead; static;

    function OwnedNodes: TArray<TObject>;
    function CreateStatement(const Body: TJSStatement): TJSScopedLoopStatement;
  end;

  TJSBinaryOperatorEntry = record
    Precedence: Integer;
    IsLogical: Boolean;
    BinaryOperator: TJSBinaryOperator;
    LogicalOperator: TJSLogicalOperator;

    class function Binary(const Precedence: Integer;
                          const BinaryOperator: TJSBinaryOperator): TJSBinaryOperatorEntry; static;
    class function Logical(const Precedence: Integer;
                           const LogicalOperator: TJSLogicalOperator): TJSBinaryOperatorEntry; static;

    function CreateExpression(const Left: TJSExpression; const Right: TJSExpression): TJSExpression;
  end;

  TJSOperandParser = function: TJSExpression of object;

implementation

uses
  JS4D.ParserConstants;

{ TJSLabelInfo }

class function TJSLabelInfo.Create(const Name: string; const LabelsIteration: Boolean): TJSLabelInfo;
begin
  Result.Name := Name;
  Result.LabelsIteration := LabelsIteration;
end;

{ TJSObjectMemberHead }

function TJSObjectMemberHead.HasModifier: Boolean;
begin
  Result := (IsGenerator or IsAsync);
end;

{ TJSClassMemberHead }

function TJSClassMemberHead.IsConstructor: Boolean;
begin
  Result := ((not IsStatic) and (KeyText = CONSTRUCTOR_NAME));
end;

{ TJSForHead }

class function TJSForHead.Classic(const Init: TJSASTNode; const Test: TJSExpression;
                                  const Update: TJSExpression): TJSForHead;
begin
  Result.Kind := TJSForKind.ClassicLoop;
  Result.Left := Init;
  Result.Right := Test;
  Result.Update := Update;
end;

class function TJSForHead.ForIn(const Left: TJSASTNode; const Right: TJSExpression): TJSForHead;
begin
  Result.Kind := TJSForKind.InLoop;
  Result.Left := Left;
  Result.Right := Right;
  Result.Update := nil;
end;

class function TJSForHead.ForOf(const Left: TJSASTNode; const Right: TJSExpression): TJSForHead;
begin
  Result.Kind := TJSForKind.OfLoop;
  Result.Left := Left;
  Result.Right := Right;
  Result.Update := nil;
end;

function TJSForHead.OwnedNodes: TArray<TObject>;
begin
  Result := [Left, Right, Update];
end;

function TJSForHead.CreateStatement(const Body: TJSStatement): TJSScopedLoopStatement;
begin
  case Kind of
    TJSForKind.ClassicLoop : Result := TJSForStatement.Create(Left, Right, Update, Body);
    TJSForKind.InLoop      : Result := TJSForInStatement.Create(Left, Right, Body);
    TJSForKind.OfLoop      : Result := TJSForOfStatement.Create(Left, Right, Body);
  else
    raise ENotSupportedException.CreateFmt('Unsupported loop kind: %d', [Ord(Kind)]);
  end;
end;

{ TJSBinaryOperatorEntry }

class function TJSBinaryOperatorEntry.Binary(const Precedence: Integer;
                                             const BinaryOperator: TJSBinaryOperator): TJSBinaryOperatorEntry;
begin
  Result := Default(TJSBinaryOperatorEntry);
  Result.Precedence := Precedence;
  Result.BinaryOperator := BinaryOperator;
end;

class function TJSBinaryOperatorEntry.Logical(const Precedence: Integer;
                                              const LogicalOperator: TJSLogicalOperator): TJSBinaryOperatorEntry;
begin
  Result := Default(TJSBinaryOperatorEntry);
  Result.Precedence := Precedence;
  Result.IsLogical := True;
  Result.LogicalOperator := LogicalOperator;
end;

function TJSBinaryOperatorEntry.CreateExpression(const Left: TJSExpression;
                                                 const Right: TJSExpression): TJSExpression;
begin
  if IsLogical then
    Result := TJSLogicalExpression.Create(LogicalOperator, Left, Right)
  else
    Result := TJSBinaryExpression.Create(BinaryOperator, Left, Right);
end;

end.
