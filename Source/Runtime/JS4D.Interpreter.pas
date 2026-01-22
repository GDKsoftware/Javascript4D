unit JS4D.Interpreter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.AST,
  JS4D.Errors,
  JS4D.Builtins;

type
  TJSScope = class
  private
    FVariables: TDictionary<string, TJSValue>;
    FParent: TJSScope;

  public
    constructor Create(const Parent: TJSScope);
    destructor Destroy; override;

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    function Resolve(const Name: string): TJSScope;

    property Parent: TJSScope read FParent;
  end;

  TJSBreakSignal = class(Exception);
  TJSContinueSignal = class(Exception);

  TJSReturnSignal = class(Exception)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

  TJSThrowSignal = class(Exception)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

  TJSInterpreter = class
  private
    FGlobalScope: TJSScope;
    FCurrentScope: TJSScope;
    FThisValue: IJSObject;
    FStrictMode: Boolean;
    FGlobalObject: IJSObject;

    procedure PushScope;
    procedure PopScope;

    function Visit(const Node: TJSASTNode): TJSValue;

    function VisitProgram(const Node: TJSProgram): TJSValue;
    function VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
    function VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
    function VisitFunctionDeclaration(const Node: TJSFunctionDeclaration): TJSValue;
    function VisitExpressionStatement(const Node: TJSExpressionStatement): TJSValue;
    function VisitIfStatement(const Node: TJSIfStatement): TJSValue;
    function VisitWhileStatement(const Node: TJSWhileStatement): TJSValue;
    function VisitDoWhileStatement(const Node: TJSDoWhileStatement): TJSValue;
    function VisitForStatement(const Node: TJSForStatement): TJSValue;
    function VisitForInStatement(const Node: TJSForInStatement): TJSValue;
    function VisitReturnStatement(const Node: TJSReturnStatement): TJSValue;
    function VisitBreakStatement(const Node: TJSBreakStatement): TJSValue;
    function VisitContinueStatement(const Node: TJSContinueStatement): TJSValue;
    function VisitSwitchStatement(const Node: TJSSwitchStatement): TJSValue;
    function VisitThrowStatement(const Node: TJSThrowStatement): TJSValue;
    function VisitTryStatement(const Node: TJSTryStatement): TJSValue;

    function VisitIdentifier(const Node: TJSIdentifier): TJSValue;
    function VisitLiteral(const Node: TJSLiteral): TJSValue;
    function VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
    function VisitObjectExpression(const Node: TJSObjectExpression): TJSValue;
    function VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
    function VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
    function VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
    function VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
    function VisitAssignmentExpression(const Node: TJSAssignmentExpression): TJSValue;
    function VisitUpdateExpression(const Node: TJSUpdateExpression): TJSValue;
    function VisitConditionalExpression(const Node: TJSConditionalExpression): TJSValue;
    function VisitCallExpression(const Node: TJSCallExpression): TJSValue;
    function VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
    function VisitNewExpression(const Node: TJSNewExpression): TJSValue;
    function VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
    function VisitThisExpression(const Node: TJSThisExpression): TJSValue;

    function CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
    function ExecuteFunctionMethod(const Func: IJSFunction; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    procedure SetMemberValue(const Node: TJSMemberExpression; const Value: TJSValue);
    function StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
    function AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Program_: TJSProgram): TJSValue;
    procedure RegisterNativeFunction(const Name: string; const Func: TNativeFunction);
    procedure SetGlobalVariable(const Name: string; const Value: TJSValue);
    function GetGlobalVariable(const Name: string): TJSValue;

    property GlobalScope: TJSScope read FGlobalScope;
  end;

implementation

const
  UNDEFINED_TYPE = 'undefined';
  OBJECT_TYPE = 'object';
  BOOLEAN_TYPE = 'boolean';
  NUMBER_TYPE = 'number';
  STRING_TYPE = 'string';
  FUNCTION_TYPE = 'function';
  LENGTH_PROPERTY = 'length';
  METHOD_CALL = 'call';
  METHOD_APPLY = 'apply';
  METHOD_BIND = 'bind';

constructor TJSScope.Create(const Parent: TJSScope);
begin
  inherited Create;
  FVariables := TDictionary<string, TJSValue>.Create;
  FParent := Parent;
end;

destructor TJSScope.Destroy;
begin
  FVariables.Free;
  inherited;
end;

function TJSScope.HasVariable(const Name: string): Boolean;
begin
  Result := FVariables.ContainsKey(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSScope.GetVariable(const Name: string): TJSValue;
begin
  if FVariables.TryGetValue(Name, Result) then
    Exit;

  if Assigned(FParent) then
    Exit(FParent.GetVariable(Name));

  Result := TJSValue.CreateUndefined;
end;

procedure TJSScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  const ResolvedScope = Resolve(Name);

  if Assigned(ResolvedScope) then
    ResolvedScope.FVariables.AddOrSetValue(Name, Value)
  else
    FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  FVariables.AddOrSetValue(Name, Value);
end;

function TJSScope.Resolve(const Name: string): TJSScope;
begin
  if FVariables.ContainsKey(Name) then
    Exit(Self);

  if Assigned(FParent) then
    Exit(FParent.Resolve(Name));

  Result := nil;
end;

constructor TJSReturnSignal.Create(const Value: TJSValue);
begin
  inherited Create('');
  FValue := Value;
end;

constructor TJSThrowSignal.Create(const Value: TJSValue);
begin
  var Msg := Value.ToString;

  if Value.IsObject then
  begin
    var Error: IJSError;

    if Supports(Value.AsObject, IJSError, Error) then
      Msg := Error.Message;
  end;

  inherited Create(Msg);
  FValue := Value;
end;

constructor TJSInterpreter.Create;
begin
  inherited Create;
  FGlobalScope := TJSScope.Create(nil);
  FCurrentScope := FGlobalScope;
  FThisValue := nil;
  FGlobalObject := TJSObject.Create;
end;

destructor TJSInterpreter.Destroy;
begin
  FGlobalScope.Free;
  inherited;
end;

procedure TJSInterpreter.PushScope;
begin
  FCurrentScope := TJSScope.Create(FCurrentScope);
end;

procedure TJSInterpreter.PopScope;
begin
  const OldScope = FCurrentScope;
  FCurrentScope := FCurrentScope.Parent;
  OldScope.Free;
end;

function TJSInterpreter.Execute(const Program_: TJSProgram): TJSValue;
begin
  Result := Visit(Program_);
end;

function TJSInterpreter.Visit(const Node: TJSASTNode): TJSValue;
begin
  if Node = nil then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  case Node.NodeType of
    TJSASTNodeType.Program_:
      Result := VisitProgram(TJSProgram(Node));
    TJSASTNodeType.BlockStatement:
      Result := VisitBlockStatement(TJSBlockStatement(Node));
    TJSASTNodeType.VariableDeclaration:
      Result := VisitVariableDeclaration(TJSVariableDeclaration(Node));
    TJSASTNodeType.FunctionDeclaration:
      Result := VisitFunctionDeclaration(TJSFunctionDeclaration(Node));
    TJSASTNodeType.ExpressionStatement:
      Result := VisitExpressionStatement(TJSExpressionStatement(Node));
    TJSASTNodeType.IfStatement:
      Result := VisitIfStatement(TJSIfStatement(Node));
    TJSASTNodeType.WhileStatement:
      Result := VisitWhileStatement(TJSWhileStatement(Node));
    TJSASTNodeType.DoWhileStatement:
      Result := VisitDoWhileStatement(TJSDoWhileStatement(Node));
    TJSASTNodeType.ForStatement:
      Result := VisitForStatement(TJSForStatement(Node));
    TJSASTNodeType.ForInStatement:
      Result := VisitForInStatement(TJSForInStatement(Node));
    TJSASTNodeType.ReturnStatement:
      Result := VisitReturnStatement(TJSReturnStatement(Node));
    TJSASTNodeType.BreakStatement:
      Result := VisitBreakStatement(TJSBreakStatement(Node));
    TJSASTNodeType.ContinueStatement:
      Result := VisitContinueStatement(TJSContinueStatement(Node));
    TJSASTNodeType.SwitchStatement:
      Result := VisitSwitchStatement(TJSSwitchStatement(Node));
    TJSASTNodeType.ThrowStatement:
      Result := VisitThrowStatement(TJSThrowStatement(Node));
    TJSASTNodeType.TryStatement:
      Result := VisitTryStatement(TJSTryStatement(Node));
    TJSASTNodeType.EmptyStatement:
      Result := TJSValue.CreateUndefined;
    TJSASTNodeType.DebuggerStatement:
      Result := TJSValue.CreateUndefined;
    TJSASTNodeType.Identifier:
      Result := VisitIdentifier(TJSIdentifier(Node));
    TJSASTNodeType.Literal:
      Result := VisitLiteral(TJSLiteral(Node));
    TJSASTNodeType.ArrayExpression:
      Result := VisitArrayExpression(TJSArrayExpression(Node));
    TJSASTNodeType.ObjectExpression:
      Result := VisitObjectExpression(TJSObjectExpression(Node));
    TJSASTNodeType.FunctionExpression:
      Result := VisitFunctionExpression(TJSFunctionExpression(Node));
    TJSASTNodeType.UnaryExpression:
      Result := VisitUnaryExpression(TJSUnaryExpression(Node));
    TJSASTNodeType.BinaryExpression:
      Result := VisitBinaryExpression(TJSBinaryExpression(Node));
    TJSASTNodeType.LogicalExpression:
      Result := VisitLogicalExpression(TJSLogicalExpression(Node));
    TJSASTNodeType.AssignmentExpression:
      Result := VisitAssignmentExpression(TJSAssignmentExpression(Node));
    TJSASTNodeType.UpdateExpression:
      Result := VisitUpdateExpression(TJSUpdateExpression(Node));
    TJSASTNodeType.ConditionalExpression:
      Result := VisitConditionalExpression(TJSConditionalExpression(Node));
    TJSASTNodeType.CallExpression:
      Result := VisitCallExpression(TJSCallExpression(Node));
    TJSASTNodeType.MemberExpression:
      Result := VisitMemberExpression(TJSMemberExpression(Node));
    TJSASTNodeType.NewExpression:
      Result := VisitNewExpression(TJSNewExpression(Node));
    TJSASTNodeType.SequenceExpression:
      Result := VisitSequenceExpression(TJSSequenceExpression(Node));
    TJSASTNodeType.ThisExpression:
      Result := VisitThisExpression(TJSThisExpression(Node));
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitProgram(const Node: TJSProgram): TJSValue;
begin
  FStrictMode := Node.IsStrict;
  Result := TJSValue.CreateUndefined;

  for var Statement in Node.Body do
  begin
    Result := Visit(Statement);
  end;
end;

function TJSInterpreter.VisitBlockStatement(const Node: TJSBlockStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  PushScope;
  try
    for var Statement in Node.Body do
    begin
      Result := Visit(Statement);
    end;
  finally
    PopScope;
  end;
end;

function TJSInterpreter.VisitVariableDeclaration(const Node: TJSVariableDeclaration): TJSValue;
begin
  for var Declarator in Node.Declarations do
  begin
    var InitValue: TJSValue;

    if Assigned(Declarator.Init) then
      InitValue := Visit(Declarator.Init)
    else
      InitValue := TJSValue.CreateUndefined;

    FCurrentScope.DeclareVariable(Declarator.Id.Name, InitValue);
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.VisitFunctionDeclaration(const Node: TJSFunctionDeclaration): TJSValue;
begin
  const Func = TJSFunction.Create;
  Func.Name := Node.Id.Name;
  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;

  var Params: TArray<string>;
  SetLength(Params, Node.Params.Count);

  for var Index := 0 to Node.Params.Count - 1 do
  begin
    Params[Index] := Node.Params[Index].Name;
  end;

  Func.Parameters := Params;

  FCurrentScope.DeclareVariable(Node.Id.Name, TJSValue.CreateObject(Func));

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.VisitExpressionStatement(const Node: TJSExpressionStatement): TJSValue;
begin
  Result := Visit(Node.Expression);
end;

function TJSInterpreter.VisitIfStatement(const Node: TJSIfStatement): TJSValue;
begin
  const TestValue = Visit(Node.Test);

  if TestValue.ToBoolean then
    Result := Visit(Node.Consequent)
  else if Assigned(Node.Alternate) then
    Result := Visit(Node.Alternate)
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.VisitWhileStatement(const Node: TJSWhileStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  while Visit(Node.Test).ToBoolean do
  begin
    try
      Result := Visit(Node.Body);
    except
      on TJSBreakSignal do
        Break;
      on TJSContinueSignal do
        Continue;
    end;
  end;
end;

function TJSInterpreter.VisitDoWhileStatement(const Node: TJSDoWhileStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  repeat
    try
      Result := Visit(Node.Body);
    except
      on TJSBreakSignal do
        Break;
      on TJSContinueSignal do
        Continue;
    end;
  until not Visit(Node.Test).ToBoolean;
end;

function TJSInterpreter.VisitForStatement(const Node: TJSForStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  PushScope;
  try
    if Assigned(Node.Init) then
      Visit(Node.Init);

    while True do
    begin
      if Assigned(Node.Test) then
      begin
        const TestValue = Visit(Node.Test);

        if not TestValue.ToBoolean then
          Break;
      end;

      try
        Result := Visit(Node.Body);
      except
        on TJSBreakSignal do
          Break;
        on TJSContinueSignal do
          begin
            if Assigned(Node.Update) then
              Visit(Node.Update);

            Continue;
          end;
      end;

      if Assigned(Node.Update) then
        Visit(Node.Update);
    end;
  finally
    PopScope;
  end;
end;

function TJSInterpreter.VisitForInStatement(const Node: TJSForInStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const RightValue = Visit(TJSExpression(Node.Right));

  if not RightValue.IsObject then
    Exit;

  const Obj = RightValue.ToObject;
  const PropertyNames = Obj.GetOwnPropertyNames;

  PushScope;
  try
    for var PropName in PropertyNames do
    begin
      if Node.Left is TJSVariableDeclaration then
      begin
        const VarDecl = TJSVariableDeclaration(Node.Left);

        if VarDecl.Declarations.Count > 0 then
          FCurrentScope.DeclareVariable(VarDecl.Declarations[0].Id.Name, TJSValue.CreateString(PropName));
      end
      else if Node.Left is TJSIdentifier then
      begin
        const Identifier = TJSIdentifier(Node.Left);
        FCurrentScope.SetVariable(Identifier.Name, TJSValue.CreateString(PropName));
      end;

      try
        Result := Visit(Node.Body);
      except
        on TJSBreakSignal do
          Break;
        on TJSContinueSignal do
          Continue;
      end;
    end;
  finally
    PopScope;
  end;
end;

function TJSInterpreter.VisitReturnStatement(const Node: TJSReturnStatement): TJSValue;
begin
  var ReturnValue: TJSValue;

  if Assigned(Node.Argument) then
    ReturnValue := Visit(Node.Argument)
  else
    ReturnValue := TJSValue.CreateUndefined;

  raise TJSReturnSignal.Create(ReturnValue);
end;

function TJSInterpreter.VisitBreakStatement(const Node: TJSBreakStatement): TJSValue;
begin
  raise TJSBreakSignal.Create('');
end;

function TJSInterpreter.VisitContinueStatement(const Node: TJSContinueStatement): TJSValue;
begin
  raise TJSContinueSignal.Create('');
end;

function TJSInterpreter.VisitSwitchStatement(const Node: TJSSwitchStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  const DiscriminantValue = Visit(Node.Discriminant);
  var Matched := False;
  var DefaultCaseIndex := -1;

  for var CaseIndex := 0 to Node.Cases.Count - 1 do
  begin
    const SwitchCase = Node.Cases[CaseIndex];

    if SwitchCase.Test = nil then
    begin
      DefaultCaseIndex := CaseIndex;
      Continue;
    end;

    const TestValue = Visit(SwitchCase.Test);

    if StrictEquals(DiscriminantValue, TestValue) then
    begin
      Matched := True;

      try
        for var StatementIndex := CaseIndex to Node.Cases.Count - 1 do
        begin
          const CurrentCase = Node.Cases[StatementIndex];

          for var Statement in CurrentCase.Consequent do
          begin
            Result := Visit(Statement);
          end;
        end;
      except
        on TJSBreakSignal do
          Exit;
      end;

      Break;
    end;
  end;

  const ShouldRunDefault = (not Matched) and (DefaultCaseIndex >= 0);
  if ShouldRunDefault then
  begin
    try
      for var StatementIndex := DefaultCaseIndex to Node.Cases.Count - 1 do
      begin
        const CurrentCase = Node.Cases[StatementIndex];

        for var Statement in CurrentCase.Consequent do
        begin
          Result := Visit(Statement);
        end;
      end;
    except
      on TJSBreakSignal do
        Exit;
    end;
  end;
end;

function TJSInterpreter.VisitThrowStatement(const Node: TJSThrowStatement): TJSValue;
begin
  const Value = Visit(Node.Argument);
  raise TJSThrowSignal.Create(Value);
end;

function TJSInterpreter.VisitTryStatement(const Node: TJSTryStatement): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  try
    Result := Visit(Node.Block);
  except
    on E: TJSThrowSignal do
    begin
      if Assigned(Node.Handler) then
      begin
        PushScope;
        try
          FCurrentScope.DeclareVariable(Node.Handler.Param.Name, E.Value);
          Result := Visit(Node.Handler.Body);
        finally
          PopScope;
        end;
      end
      else
        raise;
    end;
    on E: Exception do
    begin
      if Assigned(Node.Handler) then
      begin
        PushScope;
        try
          FCurrentScope.DeclareVariable(Node.Handler.Param.Name, TJSValue.CreateString(E.Message));
          Result := Visit(Node.Handler.Body);
        finally
          PopScope;
        end;
      end
      else
        raise;
    end;
  end;

  if Assigned(Node.Finalizer) then
    Visit(Node.Finalizer);
end;

function TJSInterpreter.VisitIdentifier(const Node: TJSIdentifier): TJSValue;
begin
  if not FCurrentScope.HasVariable(Node.Name) then
    raise TJSErrorFactory.UndefinedVariable(Node.Name, Node.Line, Node.Column);

  Result := FCurrentScope.GetVariable(Node.Name);
end;

function TJSInterpreter.VisitLiteral(const Node: TJSLiteral): TJSValue;
begin
  case Node.LiteralType of
    TJSLiteralType.Undefined:
      Result := TJSValue.CreateUndefined;
    TJSLiteralType.Null:
      Result := TJSValue.CreateNull;
    TJSLiteralType.Boolean:
      Result := TJSValue.CreateBoolean(Node.BooleanValue);
    TJSLiteralType.Number:
      Result := TJSValue.CreateNumber(Node.NumberValue);
    TJSLiteralType.String_:
      Result := TJSValue.CreateString(Node.StringValue);
    TJSLiteralType.RegExp:
      begin
        const RegExpObj: IJSRegExp = TJSRegExp.Create(Node.RegExpPattern, Node.RegExpFlags);

        RegExpObj.SetProperty('test', TJSValue.CreateObject(TJSFunction.CreateNative('test',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) and (Length(Args) > 0) then
              Result := TJSValue.CreateBoolean(RE.Test(Args[0].ToString))
            else
              Result := TJSValue.CreateBoolean(False);
          end)));

        RegExpObj.SetProperty('exec', TJSValue.CreateObject(TJSFunction.CreateNative('exec',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) and (Length(Args) > 0) then
              Result := RE.Exec(Args[0].ToString)
            else
              Result := TJSValue.CreateNull;
          end)));

        RegExpObj.SetProperty('toString', TJSValue.CreateObject(TJSFunction.CreateNative('toString',
          function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
          begin
            var RE: IJSRegExp;
            if Supports(This, IJSRegExp, RE) then
              Result := TJSValue.CreateString('/' + RE.Pattern + '/' + RE.Flags)
            else
              Result := TJSValue.CreateString('/(?:)/');
          end)));

        Result := TJSValue.CreateObject(RegExpObj);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitArrayExpression(const Node: TJSArrayExpression): TJSValue;
begin
  const Arr = TJSArray.Create;

  for var Element in Node.Elements do
  begin
    if Assigned(Element) then
    begin
      Arr.Push(Visit(Element));
    end
    else
    begin
      Arr.Push(TJSValue.CreateUndefined);
    end;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

function TJSInterpreter.VisitObjectExpression(const Node: TJSObjectExpression): TJSValue;
begin
  const Obj = TJSObject.Create;

  for var Prop in Node.Properties do
  begin
    var KeyName: string;

    if Prop.Key is TJSIdentifier then
      KeyName := TJSIdentifier(Prop.Key).Name
    else if Prop.Key is TJSLiteral then
      KeyName := Visit(Prop.Key).ToString
    else
      KeyName := Visit(Prop.Key).ToString;

    const Value = Visit(Prop.Value);
    Obj.SetProperty(KeyName, Value);
  end;

  Result := TJSValue.CreateObject(Obj);
end;

function TJSInterpreter.VisitFunctionExpression(const Node: TJSFunctionExpression): TJSValue;
begin
  const Func = TJSFunction.Create;

  if Assigned(Node.Id) then
    Func.Name := Node.Id.Name;

  Func.BodyNode := Node.Body;
  Func.IsStrict := FStrictMode or Node.IsStrict;

  var Params: TArray<string>;
  SetLength(Params, Node.Params.Count);

  for var Index := 0 to Node.Params.Count - 1 do
  begin
    Params[Index] := Node.Params[Index].Name;
  end;

  Func.Parameters := Params;

  Result := TJSValue.CreateObject(Func);
end;

function TJSInterpreter.VisitUnaryExpression(const Node: TJSUnaryExpression): TJSValue;
begin
  const Arg = Visit(Node.Argument);

  case Node.Operator of
    TJSUnaryOperator.Minus:
      Result := TJSValue.CreateNumber(-Arg.ToNumber);
    TJSUnaryOperator.Plus:
      Result := TJSValue.CreateNumber(Arg.ToNumber);
    TJSUnaryOperator.LogicalNot:
      Result := TJSValue.CreateBoolean(not Arg.ToBoolean);
    TJSUnaryOperator.BitwiseNot:
      Result := TJSValue.CreateNumber(not Trunc(Arg.ToNumber));
    TJSUnaryOperator.TypeOf:
      begin
        case Arg.ValueType of
          TJSValueType.Undefined:
            Result := TJSValue.CreateString(UNDEFINED_TYPE);
          TJSValueType.Null:
            Result := TJSValue.CreateString(OBJECT_TYPE);
          TJSValueType.Boolean_:
            Result := TJSValue.CreateString(BOOLEAN_TYPE);
          TJSValueType.Number:
            Result := TJSValue.CreateString(NUMBER_TYPE);
          TJSValueType.String_:
            Result := TJSValue.CreateString(STRING_TYPE);
          TJSValueType.Function_:
            Result := TJSValue.CreateString(FUNCTION_TYPE);
          else
            Result := TJSValue.CreateString(OBJECT_TYPE);
        end;
      end;
    TJSUnaryOperator.Void:
      Result := TJSValue.CreateUndefined;
    TJSUnaryOperator.Delete:
      begin
        if Node.Argument is TJSIdentifier then
        begin
          if FStrictMode then
            raise TJSErrorFactory.SyntaxError('Delete of an unqualified identifier in strict mode',
              Node.Line, Node.Column);

          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;

        if Node.Argument is TJSMemberExpression then
        begin
          const MemberExpr = TJSMemberExpression(Node.Argument);
          const ObjValue = Visit(MemberExpr.Object_);

          if ObjValue.IsObject then
          begin
            var PropName: string;

            if MemberExpr.Computed then
              PropName := Visit(MemberExpr.Property_).ToString
            else
              PropName := TJSIdentifier(MemberExpr.Property_).Name;

            const Obj = ObjValue.ToObject;

            if FStrictMode and Obj.HasProperty(PropName) and not Obj.IsPropertyConfigurable(PropName) then
              raise TJSErrorFactory.TypeError('Cannot delete property ''' + PropName + ''' of object',
                Node.Line, Node.Column);

            Obj.DeleteProperty(PropName);
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        end;

        Result := TJSValue.CreateBoolean(False);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitBinaryExpression(const Node: TJSBinaryExpression): TJSValue;
begin
  const Left = Visit(Node.Left);
  const Right = Visit(Node.Right);

  case Node.Operator of
    TJSBinaryOperator.Add:
      begin
        const IsStringConcat = (Left.IsString or Right.IsString);
        if IsStringConcat then
          Result := TJSValue.CreateString(Left.ToString + Right.ToString)
        else
          Result := TJSValue.CreateNumber(Left.ToNumber + Right.ToNumber);
      end;
    TJSBinaryOperator.Subtract:
      Result := TJSValue.CreateNumber(Left.ToNumber - Right.ToNumber);
    TJSBinaryOperator.Multiply:
      Result := TJSValue.CreateNumber(Left.ToNumber * Right.ToNumber);
    TJSBinaryOperator.Divide:
      begin
        const RightNum = Right.ToNumber;

        if RightNum = 0 then
        begin
          const LeftNum = Left.ToNumber;

          if LeftNum > 0 then
            Result := TJSValue.CreateInfinity(False)
          else if LeftNum < 0 then
            Result := TJSValue.CreateInfinity(True)
          else
            Result := TJSValue.CreateNaN;
        end
        else
          Result := TJSValue.CreateNumber(Left.ToNumber / RightNum);
      end;
    TJSBinaryOperator.Modulo:
      begin
        const RightNum = Right.ToNumber;

        if RightNum = 0 then
          Result := TJSValue.CreateNaN
        else
          Result := TJSValue.CreateNumber(FMod(Left.ToNumber, RightNum));
      end;
    TJSBinaryOperator.Equal:
      Result := TJSValue.CreateBoolean(AbstractEquals(Left, Right));
    TJSBinaryOperator.NotEqual:
      Result := TJSValue.CreateBoolean(not AbstractEquals(Left, Right));
    TJSBinaryOperator.StrictEqual:
      Result := TJSValue.CreateBoolean(StrictEquals(Left, Right));
    TJSBinaryOperator.StrictNotEqual:
      Result := TJSValue.CreateBoolean(not StrictEquals(Left, Right));
    TJSBinaryOperator.LessThan:
      Result := TJSValue.CreateBoolean(Left.ToNumber < Right.ToNumber);
    TJSBinaryOperator.LessThanOrEqual:
      Result := TJSValue.CreateBoolean(Left.ToNumber <= Right.ToNumber);
    TJSBinaryOperator.GreaterThan:
      Result := TJSValue.CreateBoolean(Left.ToNumber > Right.ToNumber);
    TJSBinaryOperator.GreaterThanOrEqual:
      Result := TJSValue.CreateBoolean(Left.ToNumber >= Right.ToNumber);
    TJSBinaryOperator.BitwiseAnd:
      Result := TJSValue.CreateNumber(Trunc(Left.ToNumber) and Trunc(Right.ToNumber));
    TJSBinaryOperator.BitwiseOr:
      Result := TJSValue.CreateNumber(Trunc(Left.ToNumber) or Trunc(Right.ToNumber));
    TJSBinaryOperator.BitwiseXor:
      Result := TJSValue.CreateNumber(Trunc(Left.ToNumber) xor Trunc(Right.ToNumber));
    TJSBinaryOperator.LeftShift:
      Result := TJSValue.CreateNumber(Trunc(Left.ToNumber) shl Trunc(Right.ToNumber));
    TJSBinaryOperator.RightShift:
      Result := TJSValue.CreateNumber(Trunc(Left.ToNumber) shr Trunc(Right.ToNumber));
    TJSBinaryOperator.UnsignedRightShift:
      Result := TJSValue.CreateNumber(Cardinal(Trunc(Left.ToNumber)) shr Trunc(Right.ToNumber));
    TJSBinaryOperator.InstanceOf:
      begin
        if not Left.IsObject then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;

        if not Right.IsFunction then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;

        const LeftObj = Left.ToObject;
        var RightFunc: IJSFunction;
        if not Supports(Right.ToObject, IJSFunction, RightFunc) then
        begin
          Result := TJSValue.CreateBoolean(False);
          Exit;
        end;
        const RightName = RightFunc.Name;

        var ErrorIntf: IJSError;
        if Supports(LeftObj, IJSError, ErrorIntf) then
        begin
          if RightName = 'Error' then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'TypeError') and (ErrorIntf.ErrorType = TJSErrorType.TypeError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'RangeError') and (ErrorIntf.ErrorType = TJSErrorType.RangeError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'ReferenceError') and (ErrorIntf.ErrorType = TJSErrorType.ReferenceError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'SyntaxError') and (ErrorIntf.ErrorType = TJSErrorType.SyntaxError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'URIError') and (ErrorIntf.ErrorType = TJSErrorType.URIError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;

          if (RightName = 'EvalError') and (ErrorIntf.ErrorType = TJSErrorType.EvalError) then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        end;

        if Supports(LeftObj, IJSArray) and (RightName = 'Array') then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSFunction) and (RightName = 'Function') then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSRegExp) and (RightName = 'RegExp') then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        if Supports(LeftObj, IJSDate) and (RightName = 'Date') then
        begin
          Result := TJSValue.CreateBoolean(True);
          Exit;
        end;

        Result := TJSValue.CreateBoolean(False);
      end;
    TJSBinaryOperator.In_:
      begin
        if Right.IsObject then
          Result := TJSValue.CreateBoolean(Right.ToObject.HasProperty(Left.ToString))
        else
          Result := TJSValue.CreateBoolean(False);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitLogicalExpression(const Node: TJSLogicalExpression): TJSValue;
begin
  const Left = Visit(Node.Left);

  case Node.Operator of
    TJSLogicalOperator.And_:
      begin
        if not Left.ToBoolean then
          Exit(Left);

        Result := Visit(Node.Right);
      end;
    TJSLogicalOperator.Or_:
      begin
        if Left.ToBoolean then
          Exit(Left);

        Result := Visit(Node.Right);
      end;
    else
      Result := TJSValue.CreateUndefined;
  end;
end;

function TJSInterpreter.VisitAssignmentExpression(const Node: TJSAssignmentExpression): TJSValue;
begin
  const Right = Visit(Node.Right);

  if Node.Left is TJSIdentifier then
  begin
    const Identifier = TJSIdentifier(Node.Left);

    if FStrictMode then
    begin
      if (Identifier.Name = 'eval') or (Identifier.Name = 'arguments') then
        raise TJSErrorFactory.SyntaxError('Assignment to ' + Identifier.Name + ' in strict mode',
          Node.Line, Node.Column);

      if not FCurrentScope.HasVariable(Identifier.Name) then
        raise TJSErrorFactory.ReferenceError('Assignment to undeclared variable ' + Identifier.Name,
          Node.Line, Node.Column);
    end;

    var NewValue: TJSValue;

    if Node.Operator = TJSAssignmentOperator.Assign then
      NewValue := Right
    else
    begin
      const Current = FCurrentScope.GetVariable(Identifier.Name);

      case Node.Operator of
        TJSAssignmentOperator.AddAssign:
          begin
            const IsStringConcat = (Current.IsString or Right.IsString);
            if IsStringConcat then
              NewValue := TJSValue.CreateString(Current.ToString + Right.ToString)
            else
              NewValue := TJSValue.CreateNumber(Current.ToNumber + Right.ToNumber);
          end;
        TJSAssignmentOperator.SubtractAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber - Right.ToNumber);
        TJSAssignmentOperator.MultiplyAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber * Right.ToNumber);
        TJSAssignmentOperator.DivideAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber / Right.ToNumber);
        TJSAssignmentOperator.ModuloAssign:
          NewValue := TJSValue.CreateNumber(FMod(Current.ToNumber, Right.ToNumber));
        TJSAssignmentOperator.BitwiseAndAssign:
          NewValue := TJSValue.CreateNumber(Trunc(Current.ToNumber) and Trunc(Right.ToNumber));
        TJSAssignmentOperator.BitwiseOrAssign:
          NewValue := TJSValue.CreateNumber(Trunc(Current.ToNumber) or Trunc(Right.ToNumber));
        TJSAssignmentOperator.BitwiseXorAssign:
          NewValue := TJSValue.CreateNumber(Trunc(Current.ToNumber) xor Trunc(Right.ToNumber));
        TJSAssignmentOperator.LeftShiftAssign:
          NewValue := TJSValue.CreateNumber(Trunc(Current.ToNumber) shl Trunc(Right.ToNumber));
        TJSAssignmentOperator.RightShiftAssign:
          NewValue := TJSValue.CreateNumber(Trunc(Current.ToNumber) shr Trunc(Right.ToNumber));
        TJSAssignmentOperator.UnsignedRightShiftAssign:
          NewValue := TJSValue.CreateNumber(Cardinal(Trunc(Current.ToNumber)) shr Trunc(Right.ToNumber));
        else
          NewValue := Right;
      end;
    end;

    FCurrentScope.SetVariable(Identifier.Name, NewValue);
    Result := NewValue;
  end
  else if Node.Left is TJSMemberExpression then
  begin
    var NewValue: TJSValue;

    if Node.Operator = TJSAssignmentOperator.Assign then
      NewValue := Right
    else
    begin
      const Current = Visit(Node.Left);

      case Node.Operator of
        TJSAssignmentOperator.AddAssign:
          begin
            const IsStringConcat = (Current.IsString or Right.IsString);
            if IsStringConcat then
              NewValue := TJSValue.CreateString(Current.ToString + Right.ToString)
            else
              NewValue := TJSValue.CreateNumber(Current.ToNumber + Right.ToNumber);
          end;
        TJSAssignmentOperator.SubtractAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber - Right.ToNumber);
        TJSAssignmentOperator.MultiplyAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber * Right.ToNumber);
        TJSAssignmentOperator.DivideAssign:
          NewValue := TJSValue.CreateNumber(Current.ToNumber / Right.ToNumber);
        TJSAssignmentOperator.ModuloAssign:
          NewValue := TJSValue.CreateNumber(FMod(Current.ToNumber, Right.ToNumber));
        else
          NewValue := Right;
      end;
    end;

    SetMemberValue(TJSMemberExpression(Node.Left), NewValue);
    Result := NewValue;
  end
  else
    raise TJSErrorFactory.InvalidLeftHandSide(Node.Line, Node.Column);
end;

function TJSInterpreter.VisitUpdateExpression(const Node: TJSUpdateExpression): TJSValue;
begin
  if Node.Argument is TJSIdentifier then
  begin
    const Identifier = TJSIdentifier(Node.Argument);
    const Current = FCurrentScope.GetVariable(Identifier.Name);
    const CurrentNum = Current.ToNumber;

    var NewNum: Double;

    if Node.Operator = TJSUpdateOperator.Increment then
      NewNum := CurrentNum + 1
    else
      NewNum := CurrentNum - 1;

    const NewValue = TJSValue.CreateNumber(NewNum);
    FCurrentScope.SetVariable(Identifier.Name, NewValue);

    if Node.Prefix then
      Result := NewValue
    else
      Result := TJSValue.CreateNumber(CurrentNum);
  end
  else if Node.Argument is TJSMemberExpression then
  begin
    const MemberExpr = TJSMemberExpression(Node.Argument);
    const Current = Visit(MemberExpr);
    const CurrentNum = Current.ToNumber;

    var NewNum: Double;

    if Node.Operator = TJSUpdateOperator.Increment then
      NewNum := CurrentNum + 1
    else
      NewNum := CurrentNum - 1;

    const NewValue = TJSValue.CreateNumber(NewNum);
    SetMemberValue(MemberExpr, NewValue);

    if Node.Prefix then
      Result := NewValue
    else
      Result := TJSValue.CreateNumber(CurrentNum);
  end
  else
    raise TJSErrorFactory.InvalidLeftHandSide(Node.Line, Node.Column);
end;

function TJSInterpreter.VisitConditionalExpression(const Node: TJSConditionalExpression): TJSValue;
begin
  const TestValue = Visit(Node.Test);

  if TestValue.ToBoolean then
    Result := Visit(Node.Consequent)
  else
    Result := Visit(Node.Alternate);
end;

function TJSInterpreter.VisitCallExpression(const Node: TJSCallExpression): TJSValue;
begin
  var ThisObj: IJSObject := nil;

  if Node.Callee is TJSMemberExpression then
  begin
    const MemberExpr = TJSMemberExpression(Node.Callee);
    const ObjValue = Visit(MemberExpr.Object_);

    var MethodName: string;

    if MemberExpr.Computed then
      MethodName := Visit(MemberExpr.Property_).ToString
    else
      MethodName := TJSIdentifier(MemberExpr.Property_).Name;

    var Args: TArray<TJSValue>;
    SetLength(Args, Node.Arguments.Count);

    for var Index := 0 to Node.Arguments.Count - 1 do
    begin
      Args[Index] := Visit(Node.Arguments[Index]);
    end;

    if ObjValue.IsArray and TJSBuiltins.HasArrayMethod(MethodName) then
    begin
      var ArrIntf: IJSArray;
      if Supports(ObjValue.ToObject, IJSArray, ArrIntf) then
      begin
        if TJSBuiltins.RequiresCallback(MethodName) then
        begin
          const Executor: TJSCallbackExecutor =
            function(const Func: IJSFunction; const CallbackArgs: TArray<TJSValue>): TJSValue
            begin
              Result := CallFunction(Func, CallbackArgs, nil);
            end;
          Exit(TJSBuiltins.CallArrayMethodWithCallback(ArrIntf, MethodName, Args, Executor));
        end
        else
          Exit(TJSBuiltins.CallArrayMethod(ArrIntf, MethodName, Args));
      end;
    end;

    if ObjValue.IsString and TJSBuiltins.HasStringMethod(MethodName) then
      Exit(TJSBuiltins.CallStringMethod(ObjValue.AsString, MethodName, Args));

    if ObjValue.IsNumber and TJSBuiltins.HasNumberMethod(MethodName) then
      Exit(TJSBuiltins.CallNumberMethod(ObjValue.AsNumber, MethodName, Args));

    if ObjValue.IsFunction and TJSBuiltins.HasFunctionMethod(MethodName) then
    begin
      var FuncIntf: IJSFunction;
      if Supports(ObjValue.ToObject, IJSFunction, FuncIntf) then
        Exit(ExecuteFunctionMethod(FuncIntf, MethodName, Args));
    end;

    if ObjValue.IsObject then
      ThisObj := ObjValue.ToObject;
  end;

  const CalleeValue = Visit(Node.Callee);

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction('', Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction('', Node.Line, Node.Column);

  var Args: TArray<TJSValue>;
  SetLength(Args, Node.Arguments.Count);

  for var Index := 0 to Node.Arguments.Count - 1 do
  begin
    Args[Index] := Visit(Node.Arguments[Index]);
  end;

  Result := CallFunction(Func, Args, ThisObj);
end;

function TJSInterpreter.VisitMemberExpression(const Node: TJSMemberExpression): TJSValue;
begin
  const ObjValue = Visit(Node.Object_);

  var PropName: string;

  if Node.Computed then
    PropName := Visit(Node.Property_).ToString
  else
    PropName := TJSIdentifier(Node.Property_).Name;

  if ObjValue.IsArray then
  begin
    var ArrIntf: IJSArray;
    if Supports(ObjValue.ToObject, IJSArray, ArrIntf) then
    begin
      if PropName = LENGTH_PROPERTY then
      begin
        Result := TJSValue.CreateNumber(ArrIntf.Length);
        Exit;
      end;

      var Index: Integer;

      if TryStrToInt(PropName, Index) then
      begin
        Result := ArrIntf[Index];
        Exit;
      end;
    end;
  end;

  if ObjValue.IsString then
  begin
    const Str = ObjValue.AsString;

    if PropName = LENGTH_PROPERTY then
    begin
      Result := TJSValue.CreateNumber(Length(Str));
      Exit;
    end;

    var Index: Integer;

    if TryStrToInt(PropName, Index) then
    begin
      if (Index >= 0) and (Index < Length(Str)) then
      begin
        Result := TJSValue.CreateString(Str[Index + 1]);
        Exit;
      end;
    end;
  end;

  if ObjValue.IsObject then
  begin
    Result := ObjValue.ToObject.GetProperty(PropName);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSInterpreter.VisitNewExpression(const Node: TJSNewExpression): TJSValue;
begin
  const CalleeValue = Visit(Node.Callee);

  if not CalleeValue.IsFunction then
    raise TJSErrorFactory.NotAFunction('', Node.Line, Node.Column);

  var Func: IJSFunction;
  if not Supports(CalleeValue.ToObject, IJSFunction, Func) then
    raise TJSErrorFactory.NotAFunction('', Node.Line, Node.Column);

  const NewObj: IJSObject = TJSObject.Create;

  var Args: TArray<TJSValue>;
  SetLength(Args, Node.Arguments.Count);

  for var Index := 0 to Node.Arguments.Count - 1 do
  begin
    Args[Index] := Visit(Node.Arguments[Index]);
  end;

  const ReturnValue = CallFunction(Func, Args, NewObj);

  if ReturnValue.IsObject then
    Result := ReturnValue
  else
    Result := TJSValue.CreateObject(NewObj);
end;

function TJSInterpreter.VisitSequenceExpression(const Node: TJSSequenceExpression): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  for var Expr in Node.Expressions do
  begin
    Result := Visit(Expr);
  end;
end;

function TJSInterpreter.VisitThisExpression(const Node: TJSThisExpression): TJSValue;
begin
  if Assigned(FThisValue) then
    Result := TJSValue.CreateObject(FThisValue)
  else if FStrictMode then
    Result := TJSValue.CreateUndefined
  else
    Result := TJSValue.CreateObject(FGlobalObject);
end;

function TJSInterpreter.CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>; const ThisObj: IJSObject): TJSValue;
begin
  if Func.IsNative then
    Exit(Func.NativeFunction(ThisObj, Args));

  const OldThis = FThisValue;
  const OldStrictMode = FStrictMode;
  FThisValue := ThisObj;
  FStrictMode := Func.IsStrict;

  PushScope;
  try
    for var Index := 0 to Length(Func.Parameters) - 1 do
    begin
      if Index < Length(Args) then
        FCurrentScope.DeclareVariable(Func.Parameters[Index], Args[Index])
      else
        FCurrentScope.DeclareVariable(Func.Parameters[Index], TJSValue.CreateUndefined);
    end;

    try
      Visit(TJSASTNode(Func.BodyNode));
      Result := TJSValue.CreateUndefined;
    except
      on E: TJSReturnSignal do
        Result := E.Value;
    end;
  finally
    PopScope;
    FThisValue := OldThis;
    FStrictMode := OldStrictMode;
  end;
end;

function TJSInterpreter.ExecuteFunctionMethod(const Func: IJSFunction; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_CALL then
  begin
    var ThisArg: IJSObject := nil;
    const HasObjectArg = (Length(Args) > 0) and Args[0].IsObject;
    if HasObjectArg then
      ThisArg := Args[0].ToObject;

    var FuncArgs: TArray<TJSValue>;
    if Length(Args) > 1 then
    begin
      SetLength(FuncArgs, Length(Args) - 1);
      for var Index := 1 to Length(Args) - 1 do
      begin
        FuncArgs[Index - 1] := Args[Index];
      end;
    end;

    Exit(CallFunction(Func, FuncArgs, ThisArg));
  end;

  if MethodName = METHOD_APPLY then
  begin
    var ThisArg: IJSObject := nil;
    const HasObjectArg = (Length(Args) > 0) and Args[0].IsObject;
    if HasObjectArg then
      ThisArg := Args[0].ToObject;

    var FuncArgs: TArray<TJSValue>;
    const HasArgsArray = (Length(Args) > 1) and Args[1].IsArray;
    if HasArgsArray then
    begin
      var ArgsArrayIntf: IJSArray;
      if Supports(Args[1].ToObject, IJSArray, ArgsArrayIntf) then
      begin
        SetLength(FuncArgs, ArgsArrayIntf.Length);
        for var Index := 0 to ArgsArrayIntf.Length - 1 do
        begin
          FuncArgs[Index] := ArgsArrayIntf[Index];
        end;
      end;
    end;

    Exit(CallFunction(Func, FuncArgs, ThisArg));
  end;

  if MethodName = METHOD_BIND then
  begin
    var BoundThis: IJSObject := nil;
    const HasObjectArg = (Length(Args) > 0) and Args[0].IsObject;
    if HasObjectArg then
      BoundThis := Args[0].ToObject;

    var BoundArgs: TArray<TJSValue>;
    if Length(Args) > 1 then
    begin
      SetLength(BoundArgs, Length(Args) - 1);
      for var Index := 1 to Length(Args) - 1 do
      begin
        BoundArgs[Index - 1] := Args[Index];
      end;
    end;

    const OriginalFunc = Func;
    const CapturedThis = BoundThis;
    const CapturedArgs = BoundArgs;
    const Interp = Self;

    const BoundFunc: IJSFunction = TJSFunction.CreateNative('bound',
      function(const This: IJSObject; const CallArgs: TArray<TJSValue>): TJSValue
      begin
        var AllArgs: TArray<TJSValue>;
        SetLength(AllArgs, Length(CapturedArgs) + Length(CallArgs));

        for var Index := 0 to Length(CapturedArgs) - 1 do
        begin
          AllArgs[Index] := CapturedArgs[Index];
        end;

        for var Index := 0 to Length(CallArgs) - 1 do
        begin
          AllArgs[Length(CapturedArgs) + Index] := CallArgs[Index];
        end;

        Result := Interp.CallFunction(OriginalFunc, AllArgs, CapturedThis);
      end);

    Result := TJSValue.CreateObject(BoundFunc);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

procedure TJSInterpreter.SetMemberValue(const Node: TJSMemberExpression; const Value: TJSValue);
begin
  const ObjValue = Visit(Node.Object_);

  var PropName: string;

  if Node.Computed then
    PropName := Visit(Node.Property_).ToString
  else
    PropName := TJSIdentifier(Node.Property_).Name;

  if ObjValue.IsArray then
  begin
    var ArrIntf: IJSArray;
    if Supports(ObjValue.ToObject, IJSArray, ArrIntf) then
    begin
      var Index: Integer;

      if TryStrToInt(PropName, Index) then
      begin
        ArrIntf[Index] := Value;
        Exit;
      end;
    end;
  end;

  if ObjValue.IsObject then
    ObjValue.ToObject.SetProperty(PropName, Value);
end;

function TJSInterpreter.StrictEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
begin
  if Left.ValueType <> Right.ValueType then
    Exit(False);

  case Left.ValueType of
    TJSValueType.Undefined:
      Result := True;
    TJSValueType.Null:
      Result := True;
    TJSValueType.Boolean_:
      Result := Left.AsBoolean = Right.AsBoolean;
    TJSValueType.Number:
      begin
        const HasNaN = (Left.IsNaN or Right.IsNaN);
        if HasNaN then
          Exit(False);

        Result := Left.AsNumber = Right.AsNumber;
      end;
    TJSValueType.String_:
      Result := Left.AsString = Right.AsString;
    else
      Result := Left.ToObject = Right.ToObject;
  end;
end;

function TJSInterpreter.AbstractEquals(const Left: TJSValue; const Right: TJSValue): Boolean;
begin
  if Left.ValueType = Right.ValueType then
    Exit(StrictEquals(Left, Right));

  const BothNullOrUndefined = (Left.IsNullOrUndefined and Right.IsNullOrUndefined);
  if BothNullOrUndefined then
    Exit(True);

  const IsLeftNumRightStr = (Left.IsNumber and Right.IsString);
  if IsLeftNumRightStr then
    Exit(Left.AsNumber = Right.ToNumber);

  const IsLeftStrRightNum = (Left.IsString and Right.IsNumber);
  if IsLeftStrRightNum then
    Exit(Left.ToNumber = Right.AsNumber);

  if Left.IsBoolean then
    Exit(AbstractEquals(TJSValue.CreateNumber(Left.ToNumber), Right));

  if Right.IsBoolean then
    Exit(AbstractEquals(Left, TJSValue.CreateNumber(Right.ToNumber)));

  Result := False;
end;

procedure TJSInterpreter.RegisterNativeFunction(const Name: string; const Func: TNativeFunction);
begin
  const JSFunc: IJSFunction = TJSFunction.CreateNative(Name, Func);
  FGlobalScope.DeclareVariable(Name, TJSValue.CreateObject(JSFunc));
end;

procedure TJSInterpreter.SetGlobalVariable(const Name: string; const Value: TJSValue);
begin
  FGlobalScope.DeclareVariable(Name, Value);
end;

function TJSInterpreter.GetGlobalVariable(const Name: string): TJSValue;
begin
  Result := FGlobalScope.GetVariable(Name);
end;

end.
