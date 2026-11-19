unit JS4D.GlobalScope;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.AST,
  JS4D.ObjectScope,
  JS4D.LexicalStates;

type
  TJSGlobalScope = class(TInterfacedObject, IJSScope)
  private
    FGlobalObject: IJSObject;
    FGlobalStorage: TJSObjectImpl;
    FLexicalValues: TDictionary<string, TJSValue>;
    FLexicalStates: TJSLexicalStates;
    FHasLexicals: Boolean;

    function TryGetLexical(const Name: string; out Value: TJSValue): Boolean;
    procedure SetGlobalProperty(const Name: string; const Value: TJSValue);
    function CacheOwnSlot(const Cache: PJSBindingCache; const Name: string): PJSPropertyDescriptor;
    procedure DefineGlobalProperty(const Name: string; const Value: TJSValue; const IsDeletable: Boolean);
    procedure DefineGlobal(const Name: string; const Value: TJSValue; const IsDeletable: Boolean);

  public
    constructor Create(const GlobalObject: IJSObject);
    destructor Destroy; override;

    function HasLexical(const Name: string): Boolean;
    function CanDeclareVariable(const Name: string): Boolean;
    function CanDeclareFunction(const Name: string): Boolean;
    function IsReadOnlyData(const Name: string): Boolean;
    procedure DeclareFunctionBinding(const Name: string; const Value: TJSValue; const IsDeletable: Boolean);

    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    function TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
    function FindOwnSlot(const Cache: PJSBindingCache; const Name: string): PJSPropertyDescriptor;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    procedure AssignOrDeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareLexical(const Name: string; const IsConstant: Boolean);
    procedure InitializeLexical(const Name: string; const Value: TJSValue);
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;

    property HasLexicals: Boolean read FHasLexicals;
    property Parent: IJSScope read GetParent;
  end;

implementation

uses
  System.SysUtils;

const
  GLOBAL_OBJECT_NOT_SUPPORTED = 'The global object must be a TJSObjectImpl';

constructor TJSGlobalScope.Create(const GlobalObject: IJSObject);
begin
  inherited Create;

  const StorageObject = GlobalObject as TObject;
  const IsSupportedObject = (StorageObject is TJSObjectImpl);
  if not IsSupportedObject then
    raise EArgumentException.Create(GLOBAL_OBJECT_NOT_SUPPORTED);

  FGlobalObject := GlobalObject;
  FGlobalStorage := TJSObjectImpl(StorageObject);
end;

destructor TJSGlobalScope.Destroy;
begin
  FLexicalStates.Free;
  FLexicalValues.Free;
  inherited;
end;

function TJSGlobalScope.HasLexical(const Name: string): Boolean;
begin
  Result := FHasLexicals and (FLexicalValues.ContainsKey(Name) or FLexicalStates.Contains(Name));
end;

function TJSGlobalScope.CanDeclareVariable(const Name: string): Boolean;
begin
  Result := FGlobalObject.HasOwnProperty(Name) or FGlobalObject.IsExtensible;
end;

function TJSGlobalScope.CanDeclareFunction(const Name: string): Boolean;
begin
  var Slot: PJSPropertyDescriptor;
  const IsExisting = FGlobalStorage.TryGetOwnSlot(Name, Slot);
  if not IsExisting then
    Exit(FGlobalObject.IsExtensible);

  const IsPlainData = (not Slot.IsAccessor) and Slot.Writable and Slot.Enumerable;
  Result := Slot.Configurable or IsPlainData;
end;

function TJSGlobalScope.IsReadOnlyData(const Name: string): Boolean;
begin
  var Slot: PJSPropertyDescriptor;
  const IsExisting = FGlobalStorage.TryGetOwnSlot(Name, Slot);
  Result := IsExisting and (not Slot.IsAccessor) and (not Slot.Writable);
end;

procedure TJSGlobalScope.DeclareFunctionBinding(const Name: string; const Value: TJSValue;
                                                const IsDeletable: Boolean);
begin
  var Slot: PJSPropertyDescriptor;
  const IsExisting = FGlobalStorage.TryGetOwnSlot(Name, Slot);
  const IsReplaceable = (not IsExisting) or Slot.Configurable;
  if not IsReplaceable then
  begin
    FGlobalObject.TryAssignOwnProperty(Name, Value);
    Exit;
  end;

  DefineGlobalProperty(Name, Value, IsDeletable);
end;

procedure TJSGlobalScope.DefineGlobalProperty(const Name: string; const Value: TJSValue;
                                              const IsDeletable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Configurable := IsDeletable;
  FGlobalObject.DefineProperty(Name, Descriptor);
end;

procedure TJSGlobalScope.DefineGlobal(const Name: string; const Value: TJSValue; const IsDeletable: Boolean);
begin
  if FGlobalObject.TryAssignOwnProperty(Name, Value) then
    Exit;

  DefineGlobalProperty(Name, Value, IsDeletable);
end;

function TJSGlobalScope.TryGetLexical(const Name: string; out Value: TJSValue): Boolean;
begin
  if not FHasLexicals then
    Exit(False);

  Result := FLexicalValues.TryGetValue(Name, Value);
  if not Result then
    FLexicalStates.EnsureInitialized(Name);
end;

function TJSGlobalScope.HasVariable(const Name: string): Boolean;
begin
  Result := HasLexical(Name) or FGlobalObject.HasProperty(Name);
end;

function TJSGlobalScope.GetVariable(const Name: string): TJSValue;
begin
  if TryGetLexical(Name, Result) then
    Exit;

  Result := FGlobalObject.GetProperty(Name);
end;

function TJSGlobalScope.TryGetVariable(const Name: string; out Value: TJSValue): Boolean;
begin
  if TryGetLexical(Name, Value) then
    Exit(True);

  var Descriptor: TJSPropertyDescriptor;
  Result := FGlobalObject.TryGetPropertyDescriptor(Name, Descriptor);

  if not Result then
    Exit;

  if Descriptor.IsAccessor then
    Value := FGlobalObject.GetProperty(Name)
  else
    Value := Descriptor.Value;
end;

function TJSGlobalScope.FindOwnSlot(const Cache: PJSBindingCache; const Name: string): PJSPropertyDescriptor;
begin
  const IsCacheCurrent = ((Cache.Owner = FGlobalStorage) and
                          (Cache.LayoutVersion = FGlobalStorage.PropertyLayoutVersion));
  if IsCacheCurrent then
    Exit(Cache.Slot);

  Result := CacheOwnSlot(Cache, Name);
end;

function TJSGlobalScope.CacheOwnSlot(const Cache: PJSBindingCache; const Name: string): PJSPropertyDescriptor;
begin
  if not FGlobalStorage.TryGetOwnSlot(Name, Result) then
    Exit(nil);

  Cache.Owner         := FGlobalStorage;
  Cache.LayoutVersion := FGlobalStorage.PropertyLayoutVersion;
  Cache.Slot          := Result;
end;

procedure TJSGlobalScope.SetGlobalProperty(const Name: string; const Value: TJSValue);
begin
  var Slot: PJSPropertyDescriptor;
  const HasSlot = FGlobalStorage.TryGetOwnSlot(Name, Slot);
  const IsWritableData = (HasSlot and (not Slot.IsAccessor) and Slot.Writable);

  if IsWritableData then
    Slot.Value := Value
  else
    FGlobalObject.SetProperty(Name, Value);
end;

procedure TJSGlobalScope.SetVariable(const Name: string; const Value: TJSValue);
begin
  if HasLexical(Name) then
    AssignOrDeclareVariable(Name, Value)
  else
    SetGlobalProperty(Name, Value);
end;

procedure TJSGlobalScope.AssignOrDeclareVariable(const Name: string; const Value: TJSValue);
begin
  if HasLexical(Name) then
  begin
    FLexicalStates.EnsureAssignable(Name);
    FLexicalValues.AddOrSetValue(Name, Value);
    Exit;
  end;

  DeclareVariable(Name, Value);
end;

procedure TJSGlobalScope.DeclareLexical(const Name: string; const IsConstant: Boolean);
begin
  if not FHasLexicals then
  begin
    FLexicalValues := TDictionary<string, TJSValue>.Create;
    FLexicalStates := TJSLexicalStates.Create;
    FHasLexicals := True;
  end;

  FLexicalStates.Declare(Name, IsConstant);
end;

procedure TJSGlobalScope.InitializeLexical(const Name: string; const Value: TJSValue);
begin
  FLexicalValues.AddOrSetValue(Name, Value);
  FLexicalStates.MarkInitialized(Name);
end;

procedure TJSGlobalScope.DeclareVariable(const Name: string; const Value: TJSValue);
begin
  DefineGlobal(Name, Value, False);
end;

procedure TJSGlobalScope.DeclareDeletableVariable(const Name: string; const Value: TJSValue);
begin
  DefineGlobal(Name, Value, True);
end;

function TJSGlobalScope.DeleteVariable(const Name: string): Boolean;
begin
  if HasLexical(Name) then
    Exit(False);

  Result := TJSObjectScope.DeleteBinding(FGlobalObject, Name);
end;

function TJSGlobalScope.Resolve(const Name: string): IJSScope;
begin
  Result := nil;

  if HasLexical(Name) or FGlobalObject.HasProperty(Name) then
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
  const GlobalValue = TJSValue.CreateObject(FGlobalObject);
  if not FHasLexicals then
  begin
    SetLength(Result, 1);
    Result[0] := GlobalValue;
    Exit;
  end;

  SetLength(Result, FLexicalValues.Count + 1);
  Result[0] := GlobalValue;

  var Index := 1;
  for var Value in FLexicalValues.Values do
  begin
    Result[Index] := Value;
    Inc(Index);
  end;
end;

procedure TJSGlobalScope.ReleaseReferences;
begin
  if FHasLexicals then
  begin
    FLexicalValues.Clear;
    FLexicalStates.Clear;
  end;

  FGlobalStorage := nil;
  FGlobalObject := nil;
end;

end.
