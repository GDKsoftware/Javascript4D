unit JS4D.YieldAnalysis;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.AST;

type
  // Finds the statements and expressions of a generator body that hold a yield. The interpreter suspends the
  // body at a yield by leaving the nodes that hold it, and enters them again when the generator resumes: it
  // uses ContainsYield to see which statements it has to run step by step, and IsRemembered to see which
  // nodes of an expression it must not evaluate twice.
  TJSYieldAnalysis = class
  private
    class function MarkStatement(const Node: TJSASTNode): Boolean; static;
    class function MarkExpression(const Node: TJSASTNode): Boolean; static;
    class function MarkExpressions(const Nodes: TObjectList<TJSExpression>): Boolean; static;
    class function MarkStatements(const Nodes: TObjectList<TJSStatement>): Boolean; static;
    class function MarkProperties(const Properties: TObjectList<TJSObjectProperty>): Boolean; static;
    class function MarkClass(const Node: TJSClassExpression): Boolean; static;
    class function MarkDeclaration(const Node: TJSVariableDeclaration): Boolean; static;
    class function MarkSwitch(const Node: TJSSwitchStatement): Boolean; static;
    class function MarkTry(const Node: TJSTryStatement): Boolean; static;
    class function MarkLoop(const Node: TJSASTNode): Boolean; static;
    class function MarkExpressionRoot(const Node: TJSASTNode): Boolean; static;
    class function MarkHead(const Node: TJSASTNode): Boolean; static;
    class function MarkChildren(const Node: TJSASTNode): Boolean; static;
    class function IsChainLink(const Node: TJSASTNode): Boolean; static;
    class function MarkChain(const Node: TJSExpression): Boolean; static;
    class function MarkLinkOperands(const Link: TJSExpression; const ChainHoldsYield: Boolean): Boolean; static;
    class procedure RememberChain(const Node: TJSExpression); static;
    class procedure RememberLinkOperands(const Link: TJSExpression); static;
    class procedure Remember(const Node: TJSASTNode); static;
    class procedure RememberAll(const Nodes: TObjectList<TJSExpression>); static;
    class procedure RememberProperties(const Properties: TObjectList<TJSObjectProperty>); static;

  public
    class procedure Mark(const Body: TJSBlockStatement); static;
  end;

implementation

class procedure TJSYieldAnalysis.Mark(const Body: TJSBlockStatement);
begin
  MarkStatement(Body);
end;

class function TJSYieldAnalysis.MarkStatement(const Node: TJSASTNode): Boolean;
begin
  if Node = nil then
    Exit(False);

  case Node.NodeType of
    TJSASTNodeType.BlockStatement:
      Result := MarkStatements(TJSBlockStatement(Node).Body);
    TJSASTNodeType.VariableDeclaration:
      Result := MarkDeclaration(TJSVariableDeclaration(Node));
    TJSASTNodeType.ExpressionStatement:
      Result := MarkExpressionRoot(TJSExpressionStatement(Node).Expression);
    TJSASTNodeType.IfStatement:
      begin
        const IfNode = TJSIfStatement(Node);
        const TestHoldsYield = MarkExpressionRoot(IfNode.Test);
        const ConsequentHoldsYield = MarkStatement(IfNode.Consequent);
        const AlternateHoldsYield = MarkStatement(IfNode.Alternate);
        Result := TestHoldsYield or ConsequentHoldsYield or AlternateHoldsYield;
      end;
    TJSASTNodeType.WhileStatement:
      begin
        const WhileNode = TJSWhileStatement(Node);
        const TestHoldsYield = MarkExpressionRoot(WhileNode.Test);
        const BodyHoldsYield = MarkStatement(WhileNode.Body);
        Result := TestHoldsYield or BodyHoldsYield;
      end;
    TJSASTNodeType.DoWhileStatement:
      begin
        const DoNode = TJSDoWhileStatement(Node);
        const TestHoldsYield = MarkExpressionRoot(DoNode.Test);
        const BodyHoldsYield = MarkStatement(DoNode.Body);
        Result := TestHoldsYield or BodyHoldsYield;
      end;
    TJSASTNodeType.WithStatement:
      begin
        const WithNode = TJSWithStatement(Node);
        const TargetHoldsYield = MarkExpressionRoot(WithNode.Target);
        const BodyHoldsYield = MarkStatement(WithNode.Body);
        Result := TargetHoldsYield or BodyHoldsYield;
      end;
    TJSASTNodeType.ForStatement,
    TJSASTNodeType.ForInStatement,
    TJSASTNodeType.ForOfStatement:
      Result := MarkLoop(Node);
    TJSASTNodeType.ReturnStatement:
      Result := MarkExpressionRoot(TJSReturnStatement(Node).Argument);
    TJSASTNodeType.ThrowStatement:
      Result := MarkExpressionRoot(TJSThrowStatement(Node).Argument);
    TJSASTNodeType.SwitchStatement:
      Result := MarkSwitch(TJSSwitchStatement(Node));
    TJSASTNodeType.TryStatement:
      Result := MarkTry(TJSTryStatement(Node));
    TJSASTNodeType.LabeledStatement:
      Result := MarkStatement(TJSLabeledStatement(Node).Body);
  else
    Result := False;
  end;

  Node.ContainsYield := Result;
end;

class function TJSYieldAnalysis.MarkStatements(const Nodes: TObjectList<TJSStatement>): Boolean;
begin
  Result := False;

  for var Node in Nodes do
  begin
    const HoldsYield = MarkStatement(Node);
    Result := Result or HoldsYield;
  end;
end;

class function TJSYieldAnalysis.MarkDeclaration(const Node: TJSVariableDeclaration): Boolean;
begin
  Result := False;

  for var Declarator in Node.Declarations do
  begin
    const PatternHoldsYield = MarkExpressionRoot(Declarator.Pattern);
    const InitHoldsYield = MarkExpressionRoot(Declarator.Init);
    Declarator.ContainsYield := PatternHoldsYield or InitHoldsYield;
    Result := Result or Declarator.ContainsYield;
  end;
end;

class function TJSYieldAnalysis.MarkLoop(const Node: TJSASTNode): Boolean;
begin
  if Node.NodeType = TJSASTNodeType.ForStatement then
  begin
    const ForNode = TJSForStatement(Node);
    const InitHoldsYield = MarkHead(ForNode.Init);
    const TestHoldsYield = MarkExpressionRoot(ForNode.Test);
    const UpdateHoldsYield = MarkExpressionRoot(ForNode.Update);
    const BodyHoldsYield = MarkStatement(ForNode.Body);
    Exit(InitHoldsYield or TestHoldsYield or UpdateHoldsYield or BodyHoldsYield);
  end;

  const InNode = TJSForInStatement(Node);
  const LeftHoldsYield = MarkHead(InNode.Left);
  const RightHoldsYield = MarkExpressionRoot(InNode.Right);
  const BodyHoldsYield = MarkStatement(InNode.Body);
  Result := LeftHoldsYield or RightHoldsYield or BodyHoldsYield;
end;

class function TJSYieldAnalysis.MarkSwitch(const Node: TJSSwitchStatement): Boolean;
begin
  Result := MarkExpressionRoot(Node.Discriminant);

  for var SwitchCase in Node.Cases do
  begin
    const TestHoldsYield = MarkExpressionRoot(SwitchCase.Test);
    const ConsequentHoldsYield = MarkStatements(SwitchCase.Consequent);
    SwitchCase.ContainsYield := TestHoldsYield or ConsequentHoldsYield;
    Result := Result or SwitchCase.ContainsYield;
  end;
end;

class function TJSYieldAnalysis.MarkTry(const Node: TJSTryStatement): Boolean;
begin
  Result := MarkStatement(Node.Block);

  if Assigned(Node.Handler) then
  begin
    const PatternHoldsYield = MarkExpressionRoot(Node.Handler.Pattern);
    const BodyHoldsYield = MarkStatement(Node.Handler.Body);
    Node.Handler.ContainsYield := PatternHoldsYield or BodyHoldsYield;
    Result := Result or Node.Handler.ContainsYield;
  end;

  const FinalizerHoldsYield = MarkStatement(Node.Finalizer);
  Result := Result or FinalizerHoldsYield;
end;

class function TJSYieldAnalysis.MarkExpressionRoot(const Node: TJSASTNode): Boolean;
begin
  if (Node = nil) or (not (Node is TJSExpression)) then
    Exit(False);

  Result := MarkExpression(Node);
  if Result then
    Remember(Node);
end;

class function TJSYieldAnalysis.MarkHead(const Node: TJSASTNode): Boolean;
begin
  if Node is TJSExpression then
    Result := MarkExpressionRoot(Node)
  else
    Result := MarkStatement(Node);
end;

class function TJSYieldAnalysis.MarkExpressions(const Nodes: TObjectList<TJSExpression>): Boolean;
begin
  Result := False;

  for var Node in Nodes do
  begin
    const HoldsYield = MarkExpression(Node);
    Result := Result or HoldsYield;
  end;
end;

class function TJSYieldAnalysis.MarkProperties(const Properties: TObjectList<TJSObjectProperty>): Boolean;
begin
  Result := False;

  for var Prop in Properties do
  begin
    var HoldsYield := MarkExpression(Prop.Value);
    if Prop.Computed then
      HoldsYield := MarkExpression(Prop.Key) or HoldsYield;

    Prop.ContainsYield := HoldsYield;
    Result := Result or HoldsYield;
  end;
end;

class function TJSYieldAnalysis.MarkClass(const Node: TJSClassExpression): Boolean;
begin
  Result := MarkExpression(Node.SuperClass);

  for var Member in Node.Members do
  begin
    if Member.Computed then
    begin
      const HoldsYield = MarkExpression(Member.Key);
      Member.ContainsYield := HoldsYield;
      Result := Result or HoldsYield;
    end;
  end;
end;

class function TJSYieldAnalysis.MarkChildren(const Node: TJSASTNode): Boolean;
begin
  Result := False;

  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      Result := MarkExpressions(TJSArrayExpression(Node).Elements);
    TJSASTNodeType.ArrayPattern:
      Result := MarkExpressions(TJSArrayPattern(Node).Elements);
    TJSASTNodeType.ObjectExpression:
      Result := MarkProperties(TJSObjectExpression(Node).Properties);
    TJSASTNodeType.ObjectPattern:
      begin
        const PatternNode = TJSObjectPattern(Node);
        const PropertiesHoldYield = MarkProperties(PatternNode.Properties);
        const RestHoldsYield = MarkExpression(PatternNode.Rest);
        Result := PropertiesHoldYield or RestHoldsYield;
      end;
    TJSASTNodeType.SpreadElement:
      Result := MarkExpression(TJSSpreadElement(Node).Argument);
    TJSASTNodeType.AssignmentPattern:
      begin
        const PatternNode = TJSAssignmentPattern(Node);
        const TargetHoldsYield = MarkExpression(PatternNode.Target);
        const DefaultHoldsYield = MarkExpression(PatternNode.Default);
        Result := TargetHoldsYield or DefaultHoldsYield;
      end;
    TJSASTNodeType.UnaryExpression:
      Result := MarkExpression(TJSUnaryExpression(Node).Argument);
    TJSASTNodeType.UpdateExpression:
      Result := MarkExpression(TJSUpdateExpression(Node).Argument);
    TJSASTNodeType.BinaryExpression,
    TJSASTNodeType.LogicalExpression,
    TJSASTNodeType.CallExpression,
    TJSASTNodeType.MemberExpression:
      Result := MarkChain(TJSExpression(Node));
    TJSASTNodeType.AssignmentExpression:
      begin
        const AssignmentNode = TJSAssignmentExpression(Node);
        const LeftHoldsYield = MarkExpression(AssignmentNode.Left);
        const RightHoldsYield = MarkExpression(AssignmentNode.Right);
        Result := LeftHoldsYield or RightHoldsYield;
      end;
    TJSASTNodeType.ConditionalExpression:
      begin
        const ConditionalNode = TJSConditionalExpression(Node);
        const TestHoldsYield = MarkExpression(ConditionalNode.Test);
        const ConsequentHoldsYield = MarkExpression(ConditionalNode.Consequent);
        const AlternateHoldsYield = MarkExpression(ConditionalNode.Alternate);
        Result := TestHoldsYield or ConsequentHoldsYield or AlternateHoldsYield;
      end;
    TJSASTNodeType.NewExpression:
      begin
        const NewNode = TJSNewExpression(Node);
        const CalleeHoldsYield = MarkExpression(NewNode.Callee);
        const ArgumentsHoldYield = MarkExpressions(NewNode.Arguments);
        Result := CalleeHoldsYield or ArgumentsHoldYield;
      end;
    TJSASTNodeType.SequenceExpression:
      Result := MarkExpressions(TJSSequenceExpression(Node).Expressions);
    TJSASTNodeType.TemplateLiteral:
      Result := MarkExpressions(TJSTemplateLiteral(Node).Expressions);
    TJSASTNodeType.ClassExpression:
      Result := MarkClass(TJSClassExpression(Node));
    TJSASTNodeType.YieldExpression:
      begin
        MarkExpression(TJSYieldExpression(Node).Argument);
        Result := True;
      end;
    TJSASTNodeType.AwaitExpression:
      begin
        MarkExpression(TJSAwaitExpression(Node).Argument);
        Result := True;
      end;
  end;
end;

class function TJSYieldAnalysis.IsChainLink(const Node: TJSASTNode): Boolean;
begin
  Result := Node.NodeType in [TJSASTNodeType.BinaryExpression, TJSASTNodeType.LogicalExpression,
                              TJSASTNodeType.CallExpression, TJSASTNodeType.MemberExpression];
end;

// A left-deep chain is marked from its first operand upwards in a loop, so that a chain of any length does not
// use the stack.
class function TJSYieldAnalysis.MarkChain(const Node: TJSExpression): Boolean;
begin
  const Links = TList<TJSExpression>.Create;
  try
    var Link := Node;
    while True do
    begin
      Links.Add(Link);

      const Next = Link.ChainChild;
      const ContinuesChain = Assigned(Next) and IsChainLink(Next);
      if not ContinuesChain then
        Break;

      Link := Next;
    end;

    Result := MarkExpression(Link.ChainChild);
    for var Index := Links.Count - 1 downto 0 do
    begin
      Result := MarkLinkOperands(Links[Index], Result);

      const IsRoot = (Index = 0);
      if not IsRoot then
        Links[Index].ContainsYield := Result;
    end;
  finally
    Links.Free;
  end;
end;

class function TJSYieldAnalysis.MarkLinkOperands(const Link: TJSExpression; const ChainHoldsYield: Boolean): Boolean;
begin
  var OperandsHoldYield := False;

  case Link.NodeType of
    TJSASTNodeType.BinaryExpression:
      OperandsHoldYield := MarkExpression(TJSBinaryExpression(Link).Right);
    TJSASTNodeType.LogicalExpression:
      OperandsHoldYield := MarkExpression(TJSLogicalExpression(Link).Right);
    TJSASTNodeType.CallExpression:
      OperandsHoldYield := MarkExpressions(TJSCallExpression(Link).Arguments);
    TJSASTNodeType.MemberExpression:
      begin
        if TJSMemberExpression(Link).Computed then
          OperandsHoldYield := MarkExpression(TJSMemberExpression(Link).Property_);
      end;
  end;

  Result := ChainHoldsYield or OperandsHoldYield;
end;

class function TJSYieldAnalysis.MarkExpression(const Node: TJSASTNode): Boolean;
begin
  if Node = nil then
    Exit(False);

  Result := MarkChildren(Node);
  Node.ContainsYield := Result;
end;

class procedure TJSYieldAnalysis.RememberAll(const Nodes: TObjectList<TJSExpression>);
begin
  for var Node in Nodes do
  begin
    Remember(Node);
  end;
end;

class procedure TJSYieldAnalysis.RememberProperties(const Properties: TObjectList<TJSObjectProperty>);
begin
  for var Prop in Properties do
  begin
    Remember(Prop.Value);
    if Prop.Computed then
      Remember(Prop.Key);
  end;
end;

class procedure TJSYieldAnalysis.RememberChain(const Node: TJSExpression);
begin
  var Link := Node;
  while True do
  begin
    RememberLinkOperands(Link);

    const Next = Link.ChainChild;
    const ContinuesChain = Assigned(Next) and IsChainLink(Next);
    if not ContinuesChain then
      Break;

    Next.IsRemembered := True;
    Link := Next;
  end;

  Remember(Link.ChainChild);
end;

class procedure TJSYieldAnalysis.RememberLinkOperands(const Link: TJSExpression);
begin
  case Link.NodeType of
    TJSASTNodeType.BinaryExpression:
      Remember(TJSBinaryExpression(Link).Right);
    TJSASTNodeType.LogicalExpression:
      Remember(TJSLogicalExpression(Link).Right);
    TJSASTNodeType.CallExpression:
      RememberAll(TJSCallExpression(Link).Arguments);
    TJSASTNodeType.MemberExpression:
      begin
        if TJSMemberExpression(Link).Computed then
          Remember(TJSMemberExpression(Link).Property_);
      end;
  end;
end;

class procedure TJSYieldAnalysis.Remember(const Node: TJSASTNode);
begin
  if Node = nil then
    Exit;

  Node.IsRemembered := True;

  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      RememberAll(TJSArrayExpression(Node).Elements);
    TJSASTNodeType.ArrayPattern:
      RememberAll(TJSArrayPattern(Node).Elements);
    TJSASTNodeType.ObjectExpression:
      RememberProperties(TJSObjectExpression(Node).Properties);
    TJSASTNodeType.ObjectPattern:
      begin
        RememberProperties(TJSObjectPattern(Node).Properties);
        Remember(TJSObjectPattern(Node).Rest);
      end;
    TJSASTNodeType.SpreadElement:
      Remember(TJSSpreadElement(Node).Argument);
    TJSASTNodeType.AssignmentPattern:
      begin
        Remember(TJSAssignmentPattern(Node).Target);
        Remember(TJSAssignmentPattern(Node).Default);
      end;
    TJSASTNodeType.UnaryExpression:
      Remember(TJSUnaryExpression(Node).Argument);
    TJSASTNodeType.UpdateExpression:
      Remember(TJSUpdateExpression(Node).Argument);
    TJSASTNodeType.BinaryExpression,
    TJSASTNodeType.LogicalExpression,
    TJSASTNodeType.CallExpression,
    TJSASTNodeType.MemberExpression:
      RememberChain(TJSExpression(Node));
    TJSASTNodeType.AssignmentExpression:
      begin
        Remember(TJSAssignmentExpression(Node).Left);
        Remember(TJSAssignmentExpression(Node).Right);
      end;
    TJSASTNodeType.ConditionalExpression:
      begin
        Remember(TJSConditionalExpression(Node).Test);
        Remember(TJSConditionalExpression(Node).Consequent);
        Remember(TJSConditionalExpression(Node).Alternate);
      end;
    TJSASTNodeType.NewExpression:
      begin
        Remember(TJSNewExpression(Node).Callee);
        RememberAll(TJSNewExpression(Node).Arguments);
      end;
    TJSASTNodeType.SequenceExpression:
      RememberAll(TJSSequenceExpression(Node).Expressions);
    TJSASTNodeType.TemplateLiteral:
      RememberAll(TJSTemplateLiteral(Node).Expressions);
    TJSASTNodeType.ClassExpression:
      begin
        Remember(TJSClassExpression(Node).SuperClass);
        for var Member in TJSClassExpression(Node).Members do
        begin
          if Member.Computed then
            Remember(Member.Key);
        end;
      end;
    TJSASTNodeType.YieldExpression:
      Remember(TJSYieldExpression(Node).Argument);
    TJSASTNodeType.AwaitExpression:
      Remember(TJSAwaitExpression(Node).Argument);
  end;
end;

end.
