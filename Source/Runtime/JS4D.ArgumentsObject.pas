unit JS4D.ArgumentsObject;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types;

type
  IJSArgumentsScope = interface
    ['{7B4E2A91-5D3C-4F68-A0B7-1E9C6D2F8A35}']
    function GetMappedScope: IJSScope;
    property MappedScope: IJSScope read GetMappedScope;
  end;

  // The arguments object of a non-strict function: elements below the parameter count share their
  // value with the parameter variable until the element is deleted, becomes an accessor or becomes
  // non-writable.
  TJSArgumentsObject = class(TJSObjectImpl, IJSArgumentsScope)
  private
    FScope: IJSScope;
    FMappedNames: TArray<string>;

    function IsParameterMapped(const ParameterName: string): Boolean;
    function TryGetMappedIndex(const PropertyName: string; out Index: Integer): Boolean;
    function TryGetMappedName(const PropertyName: string; out ParameterName: string): Boolean;
    procedure MapParameters(const ParameterNames: TArray<string>; const ArgumentCount: Integer);
    procedure Unmap(const Index: Integer);
    procedure SyncStoredValue(const PropertyName: string);
    procedure ApplyDefinitionToParameter(const PropertyName: string; const Definition: TJSPropertyDefinition);

  protected
    function GetMappedScope: IJSScope;

  public
    constructor Create(const Scope: IJSScope; const ParameterNames: TArray<string>; const ArgumentCount: Integer);

    procedure SetProperty(const Name: string; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: string); override;
    procedure Freeze; override;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; override;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; override;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; override;

    property MappedScope: IJSScope read GetMappedScope;
  end;

implementation

constructor TJSArgumentsObject.Create(const Scope: IJSScope; const ParameterNames: TArray<string>;
                                      const ArgumentCount: Integer);
begin
  inherited Create;

  FScope := Scope;
  MapParameters(ParameterNames, ArgumentCount);
end;

function TJSArgumentsObject.GetMappedScope: IJSScope;
begin
  Result := FScope;
end;

function TJSArgumentsObject.IsParameterMapped(const ParameterName: string): Boolean;
begin
  for var MappedName in FMappedNames do
  begin
    if MappedName = ParameterName then
      Exit(True);
  end;

  Result := False;
end;

procedure TJSArgumentsObject.MapParameters(const ParameterNames: TArray<string>; const ArgumentCount: Integer);
begin
  const MappedCount = Min(ArgumentCount, Length(ParameterNames));
  SetLength(FMappedNames, MappedCount);

  for var Index := MappedCount - 1 downto 0 do
  begin
    const ParameterName = ParameterNames[Index];
    if not IsParameterMapped(ParameterName) then
      FMappedNames[Index] := ParameterName;
  end;
end;

function TJSArgumentsObject.TryGetMappedIndex(const PropertyName: string; out Index: Integer): Boolean;
begin
  Result := TryStrToInt(PropertyName, Index) and (IntToStr(Index) = PropertyName);
  Result := Result and (Index >= 0) and (Index < Length(FMappedNames));
  Result := Result and (FMappedNames[Index] <> '');
end;

function TJSArgumentsObject.TryGetMappedName(const PropertyName: string; out ParameterName: string): Boolean;
begin
  var Index: Integer;
  Result := TryGetMappedIndex(PropertyName, Index);
  if Result then
    ParameterName := FMappedNames[Index];
end;

procedure TJSArgumentsObject.Unmap(const Index: Integer);
begin
  FMappedNames[Index] := '';
end;

procedure TJSArgumentsObject.SyncStoredValue(const PropertyName: string);
begin
  var ParameterName: string;
  if TryGetMappedName(PropertyName, ParameterName) then
    StoreOwnValue(PropertyName, FScope.GetVariable(ParameterName));
end;

procedure TJSArgumentsObject.SetProperty(const Name: string; const Value: TJSValue);
begin
  inherited SetProperty(Name, Value);

  var ParameterName: string;
  if TryGetMappedName(Name, ParameterName) then
    FScope.SetVariable(ParameterName, Value);
end;

procedure TJSArgumentsObject.DeleteProperty(const Name: string);
begin
  inherited DeleteProperty(Name);

  var Index: Integer;
  const IsRemovedMapping = TryGetMappedIndex(Name, Index) and (not HasOwnProperty(Name));
  if IsRemovedMapping then
    Unmap(Index);
end;

procedure TJSArgumentsObject.Freeze;
begin
  for var Index := 0 to Length(FMappedNames) - 1 do
  begin
    SyncStoredValue(IntToStr(Index));
    Unmap(Index);
  end;

  inherited Freeze;
end;

function TJSArgumentsObject.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  Result := inherited GetOwnPropertyDescriptor(Name);

  var ParameterName: string;
  if TryGetMappedName(Name, ParameterName) then
    Result.Value := FScope.GetVariable(ParameterName);
end;

function TJSArgumentsObject.TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := inherited TryGetPropertyDescriptor(Name, Descriptor);

  var ParameterName: string;
  if Result and TryGetMappedName(Name, ParameterName) then
    Descriptor.Value := FScope.GetVariable(ParameterName);
end;

function TJSArgumentsObject.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  SyncStoredValue(Name);

  Result := inherited DefineOwnProperty(Name, Definition);
  if Result then
    ApplyDefinitionToParameter(Name, Definition);
end;

procedure TJSArgumentsObject.ApplyDefinitionToParameter(const PropertyName: string;
                                                        const Definition: TJSPropertyDefinition);
begin
  var Index: Integer;
  if not TryGetMappedIndex(PropertyName, Index) then
    Exit;

  if Definition.IsAccessorDefinition then
  begin
    Unmap(Index);
    Exit;
  end;

  if Definition.HasValue then
    FScope.SetVariable(FMappedNames[Index], Definition.Value);

  const BecomesNonWritable = Definition.HasWritable and (not Definition.Writable);
  if BecomesNonWritable then
    Unmap(Index);
end;

end.
