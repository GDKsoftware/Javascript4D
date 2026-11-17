unit JS4D.SuspensionAnalysis;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.AST;

type
  TJSSuspensionAnalysis = class
  private
    class function MarkStatement(const Node: TJSASTNode): Boolean; static;
    class function MarkExpression(const Node: TJSASTNode): Boolean; static;
    class procedure MarkOperand(const Node: TJSASTNode); static;
    class function MarkExpressions(const Nodes: TObjectList<TJSExpression>): Boolean; static;
    class function MarkStatements(const Nodes: TObjectList<TJSStatement>): Boolean; static;
    class function MarkProperties(const Properties: TObjectList<TJSObjectProperty>): Boolean; static;
    class function MarkExpressionRoot(const Node: TJSASTNode): Boolean; static;
    class function MarkHead(const Node: TJSASTNode): Boolean; static;

    class function MarkBlock(const Node: TJSBlockStatement): Boolean; static;
    class function MarkExpressionStatement(const Node: TJSExpressionStatement): Boolean; static;
    class function MarkDeclaration(const Node: TJSVariableDeclaration): Boolean; static;
    class function MarkIf(const Node: TJSIfStatement): Boolean; static;
    class function MarkWhile(const Node: TJSWhileStatement): Boolean; static;
    class function MarkDoWhile(const Node: TJSDoWhileStatement): Boolean; static;
    class function MarkWith(const Node: TJSWithStatement): Boolean; static;
    class function MarkFor(const Node: TJSForStatement): Boolean; static;
    class function MarkForIn(const Node: TJSForInStatement): Boolean; static;
    class function MarkReturn(const Node: TJSReturnStatement): Boolean; static;
    class function MarkThrow(const Node: TJSThrowStatement): Boolean; static;
    class function MarkLabeled(const Node: TJSLabeledStatement): Boolean; static;
    class function MarkSwitch(const Node: TJSSwitchStatement): Boolean; static;
    class function MarkTry(const Node: TJSTryStatement): Boolean; static;

    class function MarkChildren(const Node: TJSASTNode): Boolean; static;
    class function MarkArray(const Node: TJSArrayExpression): Boolean; static;
    class function MarkArrayPattern(const Node: TJSArrayPattern): Boolean; static;
    class function MarkObject(const Node: TJSObjectExpression): Boolean; static;
    class function MarkObjectPattern(const Node: TJSObjectPattern): Boolean; static;
    class function MarkSpread(const Node: TJSSpreadElement): Boolean; static;
    class function MarkAssignmentPattern(const Node: TJSAssignmentPattern): Boolean; static;
    class function MarkUnary(const Node: TJSUnaryExpression): Boolean; static;
    class function MarkUpdate(const Node: TJSUpdateExpression): Boolean; static;
    class function MarkAssignment(const Node: TJSAssignmentExpression): Boolean; static;
    class function MarkConditional(const Node: TJSConditionalExpression): Boolean; static;
    class function MarkNew(const Node: TJSNewExpression): Boolean; static;
    class function MarkSequence(const Node: TJSSequenceExpression): Boolean; static;
    class function MarkTemplate(const Node: TJSTemplateLiteral): Boolean; static;
    class function MarkClass(const Node: TJSClassExpression): Boolean; static;
    class function MarkYield(const Node: TJSYieldExpression): Boolean; static;
    class function MarkAwait(const Node: TJSAwaitExpression): Boolean; static;

    class function IsChainLink(const Node: TJSExpression): Boolean; static;
    class function MarkChain(const Node: TJSExpression): Boolean; static;
    class function MarkLinkOperands(const Link: TJSExpression; const ChainHoldsSuspension: Boolean): Boolean; static;

    class procedure Remember(const Node: TJSASTNode); static;
    class procedure RememberAll(const Nodes: TObjectList<TJSExpression>); static;
    class procedure RememberProperties(const Properties: TObjectList<TJSObjectProperty>); static;
    class procedure RememberChildren(const Node: TJSASTNode); static;
    class procedure RememberArray(const Node: TJSArrayExpression); static;
    class procedure RememberArrayPattern(const Node: TJSArrayPattern); static;
    class procedure RememberObject(const Node: TJSObjectExpression); static;
    class procedure RememberObjectPattern(const Node: TJSObjectPattern); static;
    class procedure RememberSpread(const Node: TJSSpreadElement); static;
    class procedure RememberAssignmentPattern(const Node: TJSAssignmentPattern); static;
    class procedure RememberUnary(const Node: TJSUnaryExpression); static;
    class procedure RememberUpdate(const Node: TJSUpdateExpression); static;
    class procedure RememberAssignment(const Node: TJSAssignmentExpression); static;
    class procedure RememberConditional(const Node: TJSConditionalExpression); static;
    class procedure RememberNew(const Node: TJSNewExpression); static;
    class procedure RememberSequence(const Node: TJSSequenceExpression); static;
    class procedure RememberTemplate(const Node: TJSTemplateLiteral); static;
    class procedure RememberClass(const Node: TJSClassExpression); static;
    class procedure RememberYield(const Node: TJSYieldExpression); static;
    class procedure RememberAwait(const Node: TJSAwaitExpression); static;
    class procedure RememberChain(const Node: TJSExpression); static;
    class procedure RememberLinkOperands(const Link: TJSExpression); static;

  public
    class procedure Mark(const Body: TJSBlockStatement); static;
  end;

implementation

class procedure TJSSuspensionAnalysis.Mark(const Body: TJSBlockStatement);
begin
  const BodyHoldsSuspension = MarkBlock(Body);
  Body.ContainsSuspension := BodyHoldsSuspension;
end;

class function TJSSuspensionAnalysis.MarkStatement(const Node: TJSASTNode): Boolean;
begin
  if not Assigned(Node) then
    Exit(False);

  case Node.NodeType of
    TJSASTNodeType.BlockStatement      : Result := MarkBlock(TJSBlockStatement(Node));
    TJSASTNodeType.VariableDeclaration : Result := MarkDeclaration(TJSVariableDeclaration(Node));
    TJSASTNodeType.ExpressionStatement : Result := MarkExpressionStatement(TJSExpressionStatement(Node));
    TJSASTNodeType.IfStatement         : Result := MarkIf(TJSIfStatement(Node));
    TJSASTNodeType.WhileStatement      : Result := MarkWhile(TJSWhileStatement(Node));
    TJSASTNodeType.DoWhileStatement    : Result := MarkDoWhile(TJSDoWhileStatement(Node));
    TJSASTNodeType.WithStatement       : Result := MarkWith(TJSWithStatement(Node));
    TJSASTNodeType.ForStatement        : Result := MarkFor(TJSForStatement(Node));
    TJSASTNodeType.ForInStatement,
    TJSASTNodeType.ForOfStatement      : Result := MarkForIn(TJSForInStatement(Node));
    TJSASTNodeType.ReturnStatement     : Result := MarkReturn(TJSReturnStatement(Node));
    TJSASTNodeType.ThrowStatement      : Result := MarkThrow(TJSThrowStatement(Node));
    TJSASTNodeType.SwitchStatement     : Result := MarkSwitch(TJSSwitchStatement(Node));
    TJSASTNodeType.TryStatement        : Result := MarkTry(TJSTryStatement(Node));
    TJSASTNodeType.LabeledStatement    : Result := MarkLabeled(TJSLabeledStatement(Node));
  else
    Result := False;
  end;

  Node.ContainsSuspension := Result;
end;

class function TJSSuspensionAnalysis.MarkBlock(const Node: TJSBlockStatement): Boolean;
begin
  Result := MarkStatements(Node.Body);
end;

class function TJSSuspensionAnalysis.MarkExpressionStatement(const Node: TJSExpressionStatement): Boolean;
begin
  Result := MarkExpressionRoot(Node.Expression);
end;

class function TJSSuspensionAnalysis.MarkReturn(const Node: TJSReturnStatement): Boolean;
begin
  Result := MarkExpressionRoot(Node.Argument);
end;

class function TJSSuspensionAnalysis.MarkThrow(const Node: TJSThrowStatement): Boolean;
begin
  Result := MarkExpressionRoot(Node.Argument);
end;

class function TJSSuspensionAnalysis.MarkLabeled(const Node: TJSLabeledStatement): Boolean;
begin
  Result := MarkStatement(Node.Body);
end;

class function TJSSuspensionAnalysis.MarkIf(const Node: TJSIfStatement): Boolean;
begin
  const TestHoldsSuspension = MarkExpressionRoot(Node.Test);
  const ConsequentHoldsSuspension = MarkStatement(Node.Consequent);
  const AlternateHoldsSuspension = MarkStatement(Node.Alternate);
  Result := (TestHoldsSuspension or ConsequentHoldsSuspension or AlternateHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkWhile(const Node: TJSWhileStatement): Boolean;
begin
  const TestHoldsSuspension = MarkExpressionRoot(Node.Test);
  const BodyHoldsSuspension = MarkStatement(Node.Body);
  Result := (TestHoldsSuspension or BodyHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkDoWhile(const Node: TJSDoWhileStatement): Boolean;
begin
  const TestHoldsSuspension = MarkExpressionRoot(Node.Test);
  const BodyHoldsSuspension = MarkStatement(Node.Body);
  Result := (TestHoldsSuspension or BodyHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkWith(const Node: TJSWithStatement): Boolean;
begin
  const TargetHoldsSuspension = MarkExpressionRoot(Node.Target);
  const BodyHoldsSuspension = MarkStatement(Node.Body);
  Result := (TargetHoldsSuspension or BodyHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkFor(const Node: TJSForStatement): Boolean;
begin
  const InitHoldsSuspension = MarkHead(Node.Init);
  const TestHoldsSuspension = MarkExpressionRoot(Node.Test);
  const UpdateHoldsSuspension = MarkExpressionRoot(Node.Update);
  const BodyHoldsSuspension = MarkStatement(Node.Body);
  Result := (InitHoldsSuspension or TestHoldsSuspension or UpdateHoldsSuspension or BodyHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkForIn(const Node: TJSForInStatement): Boolean;
begin
  const LeftHoldsSuspension = MarkHead(Node.Left);
  const RightHoldsSuspension = MarkExpressionRoot(Node.Right);
  const BodyHoldsSuspension = MarkStatement(Node.Body);
  Result := (LeftHoldsSuspension or RightHoldsSuspension or BodyHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkStatements(const Nodes: TObjectList<TJSStatement>): Boolean;
begin
  Result := False;

  for var Node in Nodes do
  begin
    const HoldsSuspension = MarkStatement(Node);
    Result := (Result or HoldsSuspension);
  end;
end;

class function TJSSuspensionAnalysis.MarkDeclaration(const Node: TJSVariableDeclaration): Boolean;
begin
  Result := False;

  for var Declarator in Node.Declarations do
  begin
    const PatternHoldsSuspension = MarkExpressionRoot(Declarator.Pattern);
    const InitHoldsSuspension = MarkExpressionRoot(Declarator.Init);
    Declarator.ContainsSuspension := (PatternHoldsSuspension or InitHoldsSuspension);
    Result := (Result or Declarator.ContainsSuspension);
  end;
end;

class function TJSSuspensionAnalysis.MarkSwitch(const Node: TJSSwitchStatement): Boolean;
begin
  Result := MarkExpressionRoot(Node.Discriminant);

  for var SwitchCase in Node.Cases do
  begin
    const TestHoldsSuspension = MarkExpressionRoot(SwitchCase.Test);
    const ConsequentHoldsSuspension = MarkStatements(SwitchCase.Consequent);
    SwitchCase.ContainsSuspension := (TestHoldsSuspension or ConsequentHoldsSuspension);
    Result := (Result or SwitchCase.ContainsSuspension);
  end;
end;

class function TJSSuspensionAnalysis.MarkTry(const Node: TJSTryStatement): Boolean;
begin
  Result := MarkStatement(Node.Block);

  const HasHandler = Assigned(Node.Handler);
  if HasHandler then
  begin
    const PatternHoldsSuspension = MarkExpressionRoot(Node.Handler.Pattern);
    const BodyHoldsSuspension = MarkStatement(Node.Handler.Body);
    Node.Handler.ContainsSuspension := (PatternHoldsSuspension or BodyHoldsSuspension);
    Result := (Result or Node.Handler.ContainsSuspension);
  end;

  const FinalizerHoldsSuspension = MarkStatement(Node.Finalizer);
  Result := (Result or FinalizerHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkExpressionRoot(const Node: TJSASTNode): Boolean;
begin
  const IsExpression = (Node is TJSExpression);
  if not IsExpression then
    Exit(False);

  Result := MarkExpression(Node);
  if Result then
    Remember(Node);
end;

class function TJSSuspensionAnalysis.MarkHead(const Node: TJSASTNode): Boolean;
begin
  const IsExpression = (Node is TJSExpression);
  if IsExpression then
    Result := MarkExpressionRoot(Node)
  else
    Result := MarkStatement(Node);
end;

class function TJSSuspensionAnalysis.MarkExpression(const Node: TJSASTNode): Boolean;
begin
  if not Assigned(Node) then
    Exit(False);

  Result := MarkChildren(Node);
  Node.ContainsSuspension := Result;
end;

class procedure TJSSuspensionAnalysis.MarkOperand(const Node: TJSASTNode);
begin
  if not Assigned(Node) then
    Exit;

  const HoldsSuspension = MarkExpression(Node);
  Node.ContainsSuspension := HoldsSuspension;
end;

class function TJSSuspensionAnalysis.MarkExpressions(const Nodes: TObjectList<TJSExpression>): Boolean;
begin
  Result := False;

  for var Node in Nodes do
  begin
    const HoldsSuspension = MarkExpression(Node);
    Result := (Result or HoldsSuspension);
  end;
end;

class function TJSSuspensionAnalysis.MarkProperties(const Properties: TObjectList<TJSObjectProperty>): Boolean;
begin
  Result := False;

  for var Prop in Properties do
  begin
    var HoldsSuspension := MarkExpression(Prop.Value);
    if Prop.Computed then
    begin
      const KeyHoldsSuspension = MarkExpression(Prop.Key);
      HoldsSuspension := (HoldsSuspension or KeyHoldsSuspension);
    end;

    Prop.ContainsSuspension := HoldsSuspension;
    Result := (Result or HoldsSuspension);
  end;
end;

class function TJSSuspensionAnalysis.MarkClass(const Node: TJSClassExpression): Boolean;
begin
  Result := MarkExpression(Node.SuperClass);

  for var Member in Node.Members do
  begin
    if Member.Computed then
    begin
      const HoldsSuspension = MarkExpression(Member.Key);
      Member.ContainsSuspension := HoldsSuspension;
      Result := (Result or HoldsSuspension);
    end;
  end;
end;

class function TJSSuspensionAnalysis.MarkChildren(const Node: TJSASTNode): Boolean;
begin
  case Node.NodeType of
    TJSASTNodeType.ArrayExpression       : Result := MarkArray(TJSArrayExpression(Node));
    TJSASTNodeType.ArrayPattern          : Result := MarkArrayPattern(TJSArrayPattern(Node));
    TJSASTNodeType.ObjectExpression      : Result := MarkObject(TJSObjectExpression(Node));
    TJSASTNodeType.ObjectPattern         : Result := MarkObjectPattern(TJSObjectPattern(Node));
    TJSASTNodeType.SpreadElement         : Result := MarkSpread(TJSSpreadElement(Node));
    TJSASTNodeType.AssignmentPattern     : Result := MarkAssignmentPattern(TJSAssignmentPattern(Node));
    TJSASTNodeType.UnaryExpression       : Result := MarkUnary(TJSUnaryExpression(Node));
    TJSASTNodeType.UpdateExpression      : Result := MarkUpdate(TJSUpdateExpression(Node));
    TJSASTNodeType.BinaryExpression,
    TJSASTNodeType.LogicalExpression,
    TJSASTNodeType.CallExpression,
    TJSASTNodeType.MemberExpression      : Result := MarkChain(TJSExpression(Node));
    TJSASTNodeType.AssignmentExpression  : Result := MarkAssignment(TJSAssignmentExpression(Node));
    TJSASTNodeType.ConditionalExpression : Result := MarkConditional(TJSConditionalExpression(Node));
    TJSASTNodeType.NewExpression         : Result := MarkNew(TJSNewExpression(Node));
    TJSASTNodeType.SequenceExpression    : Result := MarkSequence(TJSSequenceExpression(Node));
    TJSASTNodeType.TemplateLiteral       : Result := MarkTemplate(TJSTemplateLiteral(Node));
    TJSASTNodeType.ClassExpression       : Result := MarkClass(TJSClassExpression(Node));
    TJSASTNodeType.YieldExpression       : Result := MarkYield(TJSYieldExpression(Node));
    TJSASTNodeType.AwaitExpression       : Result := MarkAwait(TJSAwaitExpression(Node));
  else
    Result := False;
  end;
end;

class function TJSSuspensionAnalysis.MarkArray(const Node: TJSArrayExpression): Boolean;
begin
  Result := MarkExpressions(Node.Elements);
end;

class function TJSSuspensionAnalysis.MarkArrayPattern(const Node: TJSArrayPattern): Boolean;
begin
  Result := MarkExpressions(Node.Elements);
end;

class function TJSSuspensionAnalysis.MarkObject(const Node: TJSObjectExpression): Boolean;
begin
  Result := MarkProperties(Node.Properties);
end;

class function TJSSuspensionAnalysis.MarkObjectPattern(const Node: TJSObjectPattern): Boolean;
begin
  const PropertiesHoldSuspension = MarkProperties(Node.Properties);
  const RestHoldsSuspension = MarkExpression(Node.Rest);
  Result := (PropertiesHoldSuspension or RestHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkSpread(const Node: TJSSpreadElement): Boolean;
begin
  Result := MarkExpression(Node.Argument);
end;

class function TJSSuspensionAnalysis.MarkAssignmentPattern(const Node: TJSAssignmentPattern): Boolean;
begin
  const TargetHoldsSuspension = MarkExpression(Node.Target);
  const DefaultHoldsSuspension = MarkExpression(Node.Default);
  Result := (TargetHoldsSuspension or DefaultHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkUnary(const Node: TJSUnaryExpression): Boolean;
begin
  Result := MarkExpression(Node.Argument);
end;

class function TJSSuspensionAnalysis.MarkUpdate(const Node: TJSUpdateExpression): Boolean;
begin
  Result := MarkExpression(Node.Argument);
end;

class function TJSSuspensionAnalysis.MarkAssignment(const Node: TJSAssignmentExpression): Boolean;
begin
  const LeftHoldsSuspension = MarkExpression(Node.Left);
  const RightHoldsSuspension = MarkExpression(Node.Right);
  Result := (LeftHoldsSuspension or RightHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkConditional(const Node: TJSConditionalExpression): Boolean;
begin
  const TestHoldsSuspension = MarkExpression(Node.Test);
  const ConsequentHoldsSuspension = MarkExpression(Node.Consequent);
  const AlternateHoldsSuspension = MarkExpression(Node.Alternate);
  Result := (TestHoldsSuspension or ConsequentHoldsSuspension or AlternateHoldsSuspension);
end;

class function TJSSuspensionAnalysis.MarkNew(const Node: TJSNewExpression): Boolean;
begin
  const CalleeHoldsSuspension = MarkExpression(Node.Callee);
  const ArgumentsHoldSuspension = MarkExpressions(Node.Arguments);
  Result := (CalleeHoldsSuspension or ArgumentsHoldSuspension);
end;

class function TJSSuspensionAnalysis.MarkSequence(const Node: TJSSequenceExpression): Boolean;
begin
  Result := MarkExpressions(Node.Expressions);
end;

class function TJSSuspensionAnalysis.MarkTemplate(const Node: TJSTemplateLiteral): Boolean;
begin
  Result := MarkExpressions(Node.Expressions);
end;

class function TJSSuspensionAnalysis.MarkYield(const Node: TJSYieldExpression): Boolean;
begin
  MarkOperand(Node.Argument);
  Result := True;
end;

class function TJSSuspensionAnalysis.MarkAwait(const Node: TJSAwaitExpression): Boolean;
begin
  MarkOperand(Node.Argument);
  Result := True;
end;

class function TJSSuspensionAnalysis.IsChainLink(const Node: TJSExpression): Boolean;
begin
  Result := (Node.ChainKind <> TJSChainKind.None);
end;

class function TJSSuspensionAnalysis.MarkChain(const Node: TJSExpression): Boolean;
begin
  const Links = TList<TJSExpression>.Create;
  try
    var Link := Node;
    while True do
    begin
      Links.Add(Link);

      const Next = Link.ChainChild;
      const ContinuesChain = (Assigned(Next) and IsChainLink(Next));
      if not ContinuesChain then
        Break;

      Link := Next;
    end;

    const Base = Link.ChainChild;
    Result := MarkExpression(Base);
    for var Index := Links.Count - 1 downto 0 do
    begin
      Result := MarkLinkOperands(Links[Index], Result);

      const IsRoot = (Index = 0);
      if not IsRoot then
        Links[Index].ContainsSuspension := Result;
    end;
  finally
    Links.Free;
  end;
end;

class function TJSSuspensionAnalysis.MarkLinkOperands(const Link: TJSExpression;
                                                      const ChainHoldsSuspension: Boolean): Boolean;
begin
  var OperandsHoldSuspension := False;

  case Link.NodeType of
    TJSASTNodeType.BinaryExpression:
      begin
        const BinaryLink = TJSBinaryExpression(Link);
        OperandsHoldSuspension := MarkExpression(BinaryLink.Right);
      end;
    TJSASTNodeType.LogicalExpression:
      begin
        const LogicalLink = TJSLogicalExpression(Link);
        OperandsHoldSuspension := MarkExpression(LogicalLink.Right);
      end;
    TJSASTNodeType.CallExpression:
      begin
        const CallLink = TJSCallExpression(Link);
        OperandsHoldSuspension := MarkExpressions(CallLink.Arguments);
      end;
    TJSASTNodeType.MemberExpression:
      begin
        const MemberLink = TJSMemberExpression(Link);
        if MemberLink.Computed then
          OperandsHoldSuspension := MarkExpression(MemberLink.Property_);
      end;
  else
    OperandsHoldSuspension := False;
  end;

  Result := (ChainHoldsSuspension or OperandsHoldSuspension);
end;

class procedure TJSSuspensionAnalysis.Remember(const Node: TJSASTNode);
begin
  if not Assigned(Node) then
    Exit;

  Node.IsRemembered := True;
  RememberChildren(Node);
end;

class procedure TJSSuspensionAnalysis.RememberAll(const Nodes: TObjectList<TJSExpression>);
begin
  for var Node in Nodes do
  begin
    Remember(Node);
  end;
end;

class procedure TJSSuspensionAnalysis.RememberProperties(const Properties: TObjectList<TJSObjectProperty>);
begin
  for var Prop in Properties do
  begin
    Remember(Prop.Value);
    if Prop.Computed then
      Remember(Prop.Key);
  end;
end;

class procedure TJSSuspensionAnalysis.RememberChildren(const Node: TJSASTNode);
begin
  case Node.NodeType of
    TJSASTNodeType.ArrayExpression       : RememberArray(TJSArrayExpression(Node));
    TJSASTNodeType.ArrayPattern          : RememberArrayPattern(TJSArrayPattern(Node));
    TJSASTNodeType.ObjectExpression      : RememberObject(TJSObjectExpression(Node));
    TJSASTNodeType.ObjectPattern         : RememberObjectPattern(TJSObjectPattern(Node));
    TJSASTNodeType.SpreadElement         : RememberSpread(TJSSpreadElement(Node));
    TJSASTNodeType.AssignmentPattern     : RememberAssignmentPattern(TJSAssignmentPattern(Node));
    TJSASTNodeType.UnaryExpression       : RememberUnary(TJSUnaryExpression(Node));
    TJSASTNodeType.UpdateExpression      : RememberUpdate(TJSUpdateExpression(Node));
    TJSASTNodeType.BinaryExpression,
    TJSASTNodeType.LogicalExpression,
    TJSASTNodeType.CallExpression,
    TJSASTNodeType.MemberExpression      : RememberChain(TJSExpression(Node));
    TJSASTNodeType.AssignmentExpression  : RememberAssignment(TJSAssignmentExpression(Node));
    TJSASTNodeType.ConditionalExpression : RememberConditional(TJSConditionalExpression(Node));
    TJSASTNodeType.NewExpression         : RememberNew(TJSNewExpression(Node));
    TJSASTNodeType.SequenceExpression    : RememberSequence(TJSSequenceExpression(Node));
    TJSASTNodeType.TemplateLiteral       : RememberTemplate(TJSTemplateLiteral(Node));
    TJSASTNodeType.ClassExpression       : RememberClass(TJSClassExpression(Node));
    TJSASTNodeType.YieldExpression       : RememberYield(TJSYieldExpression(Node));
    TJSASTNodeType.AwaitExpression       : RememberAwait(TJSAwaitExpression(Node));
  else
    Exit;
  end;
end;

class procedure TJSSuspensionAnalysis.RememberArray(const Node: TJSArrayExpression);
begin
  RememberAll(Node.Elements);
end;

class procedure TJSSuspensionAnalysis.RememberArrayPattern(const Node: TJSArrayPattern);
begin
  RememberAll(Node.Elements);
end;

class procedure TJSSuspensionAnalysis.RememberObject(const Node: TJSObjectExpression);
begin
  RememberProperties(Node.Properties);
end;

class procedure TJSSuspensionAnalysis.RememberObjectPattern(const Node: TJSObjectPattern);
begin
  RememberProperties(Node.Properties);
  Remember(Node.Rest);
end;

class procedure TJSSuspensionAnalysis.RememberSpread(const Node: TJSSpreadElement);
begin
  Remember(Node.Argument);
end;

class procedure TJSSuspensionAnalysis.RememberAssignmentPattern(const Node: TJSAssignmentPattern);
begin
  Remember(Node.Target);
  Remember(Node.Default);
end;

class procedure TJSSuspensionAnalysis.RememberUnary(const Node: TJSUnaryExpression);
begin
  Remember(Node.Argument);
end;

class procedure TJSSuspensionAnalysis.RememberUpdate(const Node: TJSUpdateExpression);
begin
  Remember(Node.Argument);
end;

class procedure TJSSuspensionAnalysis.RememberAssignment(const Node: TJSAssignmentExpression);
begin
  Remember(Node.Left);
  Remember(Node.Right);
end;

class procedure TJSSuspensionAnalysis.RememberConditional(const Node: TJSConditionalExpression);
begin
  Remember(Node.Test);
  Remember(Node.Consequent);
  Remember(Node.Alternate);
end;

class procedure TJSSuspensionAnalysis.RememberNew(const Node: TJSNewExpression);
begin
  Remember(Node.Callee);
  RememberAll(Node.Arguments);
end;

class procedure TJSSuspensionAnalysis.RememberSequence(const Node: TJSSequenceExpression);
begin
  RememberAll(Node.Expressions);
end;

class procedure TJSSuspensionAnalysis.RememberTemplate(const Node: TJSTemplateLiteral);
begin
  RememberAll(Node.Expressions);
end;

class procedure TJSSuspensionAnalysis.RememberClass(const Node: TJSClassExpression);
begin
  Remember(Node.SuperClass);

  for var Member in Node.Members do
  begin
    if Member.Computed then
      Remember(Member.Key);
  end;
end;

class procedure TJSSuspensionAnalysis.RememberYield(const Node: TJSYieldExpression);
begin
  Remember(Node.Argument);
end;

class procedure TJSSuspensionAnalysis.RememberAwait(const Node: TJSAwaitExpression);
begin
  Remember(Node.Argument);
end;

class procedure TJSSuspensionAnalysis.RememberChain(const Node: TJSExpression);
begin
  var Link := Node;
  while True do
  begin
    RememberLinkOperands(Link);

    const Next = Link.ChainChild;
    const ContinuesChain = (Assigned(Next) and IsChainLink(Next));
    if not ContinuesChain then
      Break;

    Next.IsRemembered := True;
    Link := Next;
  end;

  Remember(Link.ChainChild);
end;

class procedure TJSSuspensionAnalysis.RememberLinkOperands(const Link: TJSExpression);
begin
  case Link.NodeType of
    TJSASTNodeType.BinaryExpression:
      begin
        const BinaryLink = TJSBinaryExpression(Link);
        Remember(BinaryLink.Right);
      end;
    TJSASTNodeType.LogicalExpression:
      begin
        const LogicalLink = TJSLogicalExpression(Link);
        Remember(LogicalLink.Right);
      end;
    TJSASTNodeType.CallExpression:
      begin
        const CallLink = TJSCallExpression(Link);
        RememberAll(CallLink.Arguments);
      end;
    TJSASTNodeType.MemberExpression:
      begin
        const MemberLink = TJSMemberExpression(Link);
        if MemberLink.Computed then
          Remember(MemberLink.Property_);
      end;
  else
    Exit;
  end;
end;

end.
