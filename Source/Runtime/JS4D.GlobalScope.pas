unit JS4D.GlobalScope;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.AST,
  JS4D.ObjectScope;

type
  TJSGlobalScope = class(TInterfacedObject, IJSScope)
  private
    FGlobalObject: IJSObject;
    FGlobalStorage: TJSObjectImpl;

  public
    constructor Create(const GlobalObject: IJSObject);

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    function TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
    function FindOwnSlot(var Cache: TJSBindingCache; const Name: string): PJSPropertyDescriptor;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;

    property Parent: IJSScope read GetParent;
  end;

implementation

constructor TJSGlobalScope.Create(const GlobalObject: IJSObject);
begin
  inherited Create;
  FGlobalObject := GlobalObject;
  FGlobalStorage := (GlobalObject as TObject) as TJSObjectImpl;
end;

function TJSGlobalScope.HasVariable(const Name: string): Boolean;
begin
  Result := FGlobalObject.HasProperty(Name);
end;

function TJSGlobalScope.GetVariable(const Name: string): TJSValue;
begin
  Result := FGlobalObject.GetProperty(Name);
end;

function TJSGlobalScope.TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := FGlobalObject.TryGetPropertyDescriptor(Name, Descriptor);

  if not Result then
    Exit;

  if Descriptor.IsAccessor then
    Value := FGlobalObject.GetProperty(Name)
  else
    Value := Descriptor.Value;
end;

function TJSGlobalScope.FindOwnSlot(var Cache: TJSBindingCache; const Name: string): PJSPropertyDescriptor;
begin
  const IsCacheCurrent = (Cache.Owner = FGlobalStorage) and
                         (Cache.LayoutVersion = FGlobalStorage.PropertyLayoutVersion);
  if IsCacheCurrent then
    Exit(Cache.Slot);

  if not FGlobalStorage.TryGetOwnSlot(Name, Result) then
    Exit(nil);

  Cache.Owner         := FGlobalStorage;
  Cache.LayoutVersion := FGlobalStorage.PropertyLayoutVersion;
  Cache.Slot          := Result;
end;

procedure TJSGlobalScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  FGlobalObject.SetProperty(Name, Value);
end;

procedure TJSGlobalScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  if FGlobalObject.TryAssignOwnProperty(Name, Value) then
    Exit;

  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Configurable := False;
  FGlobalObject.DefineProperty(Name, Descriptor);
end;

procedure TJSGlobalScope.DeclareDeletableVariable(const Name: string; const Value: TJSValue);
begin
  FGlobalObject.SetProperty(Name, Value);
end;

function TJSGlobalScope.DeleteVariable(const Name: string): Boolean;
begin
  Result := TJSObjectScope.DeleteBinding(FGlobalObject, Name);
end;

function TJSGlobalScope.Resolve(const Name: string): IJSScope;
begin
  Result := nil;

  if FGlobalObject.HasProperty(Name) then
    Result := Self;
end;

function TJSGlobalScope.GetParent: IJSScope;
begin
  Result := nil;
end;

procedure TJSGlobalScope.Clear;
begin
  for var Name in FGlobalObject.GetOwnPropertyNames do
  begin
    FGlobalObject.DeleteProperty(Name);
  end;

  ReleaseReferences;
end;

function TJSGlobalScope.GetOwnVariables: TArray<TJSValue>;
begin
  Result := [TJSValue.CreateObject(FGlobalObject)];
end;

procedure TJSGlobalScope.ReleaseReferences;
begin
  FGlobalStorage := nil;
  FGlobalObject := nil;
end;

end.
