unit JS4D.Scope;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.SlotMap,
  JS4D.LexicalStates;

type
  TJSScope = class(TInterfacedObject, IJSScope)
  private
    FVariables: TJSSlotMap<TJSValue>;
    FParent: IJSScope;
    FLexicalStates: TJSLexicalStates;
    FDeletableNames: TDictionary<string, Byte>;

    function HasLexicalState(const Name: string): Boolean;
    function IsDeletableName(const Name: string): Boolean;

  protected
    function GetParent: IJSScope;

  public
    constructor Create(const Parent: IJSScope);
    destructor Destroy; override;

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    function TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    procedure AssignOrDeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareLexical(const Name: string; const IsConstant: Boolean);
    procedure InitializeLexical(const Name: string; const Value: TJSValue);
    function CloneForIteration: TJSScope;
    function IsLexicalBinding(const Name: string): Boolean;
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;

    property Parent: IJSScope read GetParent;
  end;

  TJSFunctionNameScope = class(TJSScope);

implementation

{ TJSScope }

constructor TJSScope.Create(const Parent: IJSScope);
begin
  inherited Create;
  FVariables := TJSSlotMap<TJSValue>.Create;
  FParent := Parent;
end;

function TJSScope.GetParent: IJSScope;
begin
  Result := FParent;
end;

destructor TJSScope.Destroy;
begin
  Clear;
  FVariables.Free;
  FLexicalStates.Free;
  FDeletableNames.Free;
  inherited;
end;

procedure TJSScope.Clear;
begin
  for var Position := 0 to FVariables.Count - 1 do
  begin
    const Value = FVariables.ValueAt(Position);
    if Value.IsFunction then
    begin
      var Func: IJSFunction;
      if Supports(Value.ToObject, IJSFunction, Func) then
        Func.ClosureScope := nil;
    end;
  end;

  FVariables.Clear;
  FParent := nil;
end;

function TJSScope.GetOwnVariables: TArray<TJSValue>;
begin
  SetLength(Result, FVariables.Count);
  for var Position := 0 to FVariables.Count - 1 do
  begin
    Result[Position] := FVariables.ValueAt(Position);
  end;
end;

procedure TJSScope.ReleaseReferences;
begin
  FVariables.Clear;

  if Assigned(FLexicalStates) then
    FLexicalStates.Clear;

  FParent := nil;
end;

function TJSScope.HasLexicalState(const Name: string): Boolean;
begin
  Result := Assigned(FLexicalStates) and FLexicalStates.Contains(Name);
end;

function TJSScope.HasVariable(const Name: string): Boolean;
begin
  Result := FVariables.ContainsKey(Name) or HasLexicalState(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSScope.GetVariable(const Name: string): TJSValue;
begin
  if FVariables.TryGetValue(Name, Result) then
    Exit;

  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureInitialized(Name);

  if Assigned(FParent) then
  begin
    Result := FParent.GetVariable(Name);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSScope.TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
begin
  Result := FVariables.TryGetValue(Name, Value);
  if Result then
    Exit;

  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureInitialized(Name);

  if Assigned(FParent) then
    Result := FParent.TryGetVariable(Name, Value);
end;

procedure TJSScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  const ResolvedScope = Resolve(Name);

  if Assigned(ResolvedScope) then
    ResolvedScope.AssignOrDeclareVariable(Name, Value)
  else if Assigned(FParent) then
    FParent.SetVariable(Name, Value)
  else
    FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareDeletableVariable(const Name: string; const Value: TJSValue);
begin
  const IsExisting = FVariables.ContainsKey(Name);
  DeclareVariable(Name, Value);
  if IsExisting then
    Exit;

  if not Assigned(FDeletableNames) then
    FDeletableNames := TDictionary<string, Byte>.Create;

  FDeletableNames.AddOrSetValue(Name, 0);
end;

procedure TJSScope.AssignOrDeclareVariable(const Name: string; const Value: TJSValue);
begin
  if Assigned(FLexicalStates) then
    FLexicalStates.EnsureAssignable(Name);

  FVariables.AddOrSetValue(Name, Value);
end;

procedure TJSScope.DeclareLexical(const Name: string; const IsConstant: Boolean);
begin
  if not Assigned(FLexicalStates) then
    FLexicalStates := TJSLexicalStates.Create;

  FLexicalStates.Declare(Name, IsConstant);
end;

procedure TJSScope.InitializeLexical(const Name: string; const Value: TJSValue);
begin
  FVariables.AddOrSetValue(Name, Value);

  if Assigned(FLexicalStates) then
    FLexicalStates.MarkInitialized(Name);
end;

function TJSScope.CloneForIteration: TJSScope;
begin
  Result := TJSScope.Create(FParent);

  for var Position := 0 to FVariables.Count - 1 do
  begin
    Result.FVariables.Add(FVariables.NameAt(Position), FVariables.ValueAt(Position));
  end;

  if Assigned(FLexicalStates) then
  begin
    Result.FLexicalStates := TJSLexicalStates.Create;
    Result.FLexicalStates.CopyFrom(FLexicalStates);
  end;
end;

function TJSScope.IsLexicalBinding(const Name: string): Boolean;
begin
  Result := HasLexicalState(Name);
end;

function TJSScope.IsDeletableName(const Name: string): Boolean;
begin
  Result := Assigned(FDeletableNames) and FDeletableNames.ContainsKey(Name);
end;

function TJSScope.DeleteVariable(const Name: string): Boolean;
begin
  if IsDeletableName(Name) then
  begin
    FDeletableNames.Remove(Name);
    FVariables.Remove(Name);
    Exit(True);
  end;

  Result := (not FVariables.ContainsKey(Name)) and (not HasLexicalState(Name));
end;

function TJSScope.Resolve(const Name: string): IJSScope;
begin
  if FVariables.ContainsKey(Name) or HasLexicalState(Name) then
    Exit(Self);

  if Assigned(FParent) then
  begin
    Result := FParent.Resolve(Name);
    Exit;
  end;

  Result := nil;
end;

end.
