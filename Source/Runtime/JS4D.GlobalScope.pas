unit JS4D.GlobalScope;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.ObjectScope;

type
  TJSGlobalScope = class(TInterfacedObject, IJSScope)
  private
    FGlobalObject: IJSObject;

  public
    constructor Create(const GlobalObject: IJSObject);

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
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
end;

function TJSGlobalScope.HasVariable(const Name: string): Boolean;
begin
  Result := FGlobalObject.HasProperty(Name);
end;

function TJSGlobalScope.GetVariable(const Name: string): TJSValue;
begin
  Result := FGlobalObject.GetProperty(Name);
end;

procedure TJSGlobalScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  FGlobalObject.SetProperty(Name, Value);
end;

procedure TJSGlobalScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  const IsNewBinding = not FGlobalObject.HasOwnProperty(Name);
  if not IsNewBinding then
  begin
    FGlobalObject.SetProperty(Name, Value);
    Exit;
  end;

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
  FGlobalObject := nil;
end;

end.
