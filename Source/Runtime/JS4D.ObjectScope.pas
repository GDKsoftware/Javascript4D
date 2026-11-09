unit JS4D.ObjectScope;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  IJSObjectScope = interface
    ['{3C6E1B52-8F0A-4D77-9B1E-5A2D7C4E9F10}']
    function GetBindingObject: IJSObject;
    property BindingObject: IJSObject read GetBindingObject;
  end;

  TJSObjectScope = class(TInterfacedObject, IJSScope, IJSObjectScope)
  private
    FBindingObject: IJSObject;
    FParent: IJSScope;

  public
    constructor Create(const Parent: IJSScope; const BindingObject: IJSObject);

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;
    function GetBindingObject: IJSObject;

    property Parent: IJSScope read GetParent;
  end;

implementation

constructor TJSObjectScope.Create(const Parent: IJSScope; const BindingObject: IJSObject);
begin
  inherited Create;
  FParent := Parent;
  FBindingObject := BindingObject;
end;

function TJSObjectScope.HasVariable(const Name: string): Boolean;
begin
  Result := FBindingObject.HasProperty(Name);

  if (not Result) and Assigned(FParent) then
    Result := FParent.HasVariable(Name);
end;

function TJSObjectScope.GetVariable(const Name: string): TJSValue;
begin
  if FBindingObject.HasProperty(Name) then
    Exit(FBindingObject.GetProperty(Name));

  if Assigned(FParent) then
    Exit(FParent.GetVariable(Name));

  Result := TJSValue.CreateUndefined;
end;

procedure TJSObjectScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  if FBindingObject.HasProperty(Name) then
    FBindingObject.SetProperty(Name, Value)
  else if Assigned(FParent) then
    FParent.SetVariable(Name, Value);
end;

procedure TJSObjectScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  FBindingObject.SetProperty(Name, Value);
end;

function TJSObjectScope.Resolve(const Name: string): IJSScope;
begin
  if FBindingObject.HasProperty(Name) then
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
