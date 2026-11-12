unit JS4D.ObjectScope;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.Errors,
  JS4D.SymbolRegistry;

type
  IJSObjectScope = interface
    ['{3C6E1B52-8F0A-4D77-9B1E-5A2D7C4E9F10}']
    function GetBindingObject: IJSObject;
    function GetBindingValue(const Name: string; const IsStrict: Boolean): TJSValue;
    procedure SetMutableBinding(const Name: string; const Value: TJSValue; const IsStrict: Boolean);
    property BindingObject: IJSObject read GetBindingObject;
  end;

  TJSObjectScope = class(TInterfacedObject, IJSScope, IJSObjectScope)
  private
    FBindingObject: IJSObject;
    FParent: IJSScope;
    FStrictModeFlag: PBoolean;

    function HasBinding(const Name: string): Boolean;
    function IsStrictCodeRunning: Boolean;

  public
    class function DeleteBinding(const BindingObject: IJSObject; const Name: string): Boolean; static;

    constructor Create(const Parent: IJSScope; const BindingObject: IJSObject; const StrictModeFlag: PBoolean);

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    function TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    procedure AssignVariable(const Name: string; const Value: TJSValue);
    procedure DeclareLexical(const Name: string; const IsConstant: Boolean);
    procedure InitializeLexical(const Name: string; const Value: TJSValue);
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;
    function GetBindingObject: IJSObject;
    function GetBindingValue(const Name: string; const IsStrict: Boolean): TJSValue;
    procedure SetMutableBinding(const Name: string; const Value: TJSValue; const IsStrict: Boolean);

    property Parent: IJSScope read GetParent;
  end;

implementation

class function TJSObjectScope.DeleteBinding(const BindingObject: IJSObject; const Name: string): Boolean;
begin
  const IsOwnBinding = BindingObject.HasOwnProperty(Name);
  if not IsOwnBinding then
    Exit(True);

  Result := BindingObject.IsPropertyConfigurable(Name);
  if Result then
    BindingObject.DeleteProperty(Name);
end;

constructor TJSObjectScope.Create(const Parent: IJSScope; const BindingObject: IJSObject; const StrictModeFlag: PBoolean);
begin
  inherited Create;
  FParent := Parent;
  FBindingObject := BindingObject;
  FStrictModeFlag := StrictModeFlag;
end;

function TJSObjectScope.IsStrictCodeRunning: Boolean;
begin
  Result := Assigned(FStrictModeFlag) and FStrictModeFlag^;
end;

function TJSObjectScope.GetBindingValue(const Name: string; const IsStrict: Boolean): TJSValue;
begin
  const StillExists = FBindingObject.HasProperty(Name);
  if StillExists then
    Exit(FBindingObject.GetProperty(Name));

  if IsStrict then
    raise TJSErrorFactory.UndefinedVariable(Name);

  Result := TJSValue.CreateUndefined;
end;

procedure TJSObjectScope.SetMutableBinding(const Name: string; const Value: TJSValue; const IsStrict: Boolean);
begin
  const StillExists = FBindingObject.HasProperty(Name);
  if IsStrict and (not StillExists) then
    raise TJSErrorFactory.ReferenceError('Assignment to undeclared variable ' + Name);

  FBindingObject.SetProperty(Name, Value);
end;

function TJSObjectScope.HasBinding(const Name: string): Boolean;
begin
  Result := FBindingObject.HasProperty(Name);
  if not Result then
    Exit;

  const Unscopables = FBindingObject.GetProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Unscopables));
  if not Unscopables.IsObject then
    Exit;

  const IsBlocked = Unscopables.ToObject.GetProperty(Name).ToBoolean;
  Result := not IsBlocked;
end;

function TJSObjectScope.HasVariable(const Name: string): Boolean;
begin
  Result := HasBinding(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSObjectScope.GetVariable(const Name: string): TJSValue;
begin
  if HasBinding(Name) then
    Exit(GetBindingValue(Name, IsStrictCodeRunning));

  if Assigned(FParent) then
    Exit(FParent.GetVariable(Name));

  Result := TJSValue.CreateUndefined;
end;

function TJSObjectScope.TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
begin
  Result := HasBinding(Name);

  if Result then
  begin
    Value := GetBindingValue(Name, IsStrictCodeRunning);
    Exit;
  end;

  if Assigned(FParent) then
    Result := FParent.TryGetVariable(Name, Value);
end;

procedure TJSObjectScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  if HasBinding(Name) then
    SetMutableBinding(Name, Value, IsStrictCodeRunning)
  else if Assigned(FParent) then
    FParent.SetVariable(Name, Value);
end;

procedure TJSObjectScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  FBindingObject.SetProperty(Name, Value);
end;

procedure TJSObjectScope.DeclareDeletableVariable(const Name: string; const Value: TJSValue);
begin
  DeclareVariable(Name, Value);
end;

procedure TJSObjectScope.AssignVariable(const Name: string; const Value: TJSValue);
begin
  DeclareVariable(Name, Value);
end;

procedure TJSObjectScope.DeclareLexical(const Name: string; const IsConstant: Boolean);
begin
end;

procedure TJSObjectScope.InitializeLexical(const Name: string; const Value: TJSValue);
begin
  DeclareVariable(Name, Value);
end;

function TJSObjectScope.DeleteVariable(const Name: string): Boolean;
begin
  Result := DeleteBinding(FBindingObject, Name);
end;

function TJSObjectScope.Resolve(const Name: string): IJSScope;
begin
  if HasBinding(Name) then
    Exit(Self);

  if Assigned(FParent) then
    Exit(FParent.Resolve(Name));

  Result := nil;
end;

function TJSObjectScope.GetParent: IJSScope;
begin
  Result := FParent;
end;

procedure TJSObjectScope.Clear;
begin
  ReleaseReferences;
end;

function TJSObjectScope.GetOwnVariables: TArray<TJSValue>;
begin
  Result := [TJSValue.CreateObject(FBindingObject)];
end;

procedure TJSObjectScope.ReleaseReferences;
begin
  FBindingObject := nil;
  FParent := nil;
end;

function TJSObjectScope.GetBindingObject: IJSObject;
begin
  Result := FBindingObject;
end;

end.
