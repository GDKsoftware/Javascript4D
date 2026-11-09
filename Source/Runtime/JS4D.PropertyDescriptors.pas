unit JS4D.PropertyDescriptors;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.Errors;

type
  TJSPropertyDescriptors = class
  private
    const
      ATTRIBUTE_VALUE = 'value';
      ATTRIBUTE_WRITABLE = 'writable';
      ATTRIBUTE_GET = 'get';
      ATTRIBUTE_SET = 'set';
      ATTRIBUTE_ENUMERABLE = 'enumerable';
      ATTRIBUTE_CONFIGURABLE = 'configurable';
      DESCRIPTOR_NOT_AN_OBJECT = 'Property description must be an object';
      ACCESSOR_NOT_CALLABLE = 'Getter and setter must be functions or undefined';
      MIXED_DESCRIPTOR = 'Invalid property descriptor. Cannot both specify accessors and a value or writable attribute';
      CANNOT_REDEFINE = 'Cannot redefine property: %s';
      PROPERTIES_NOT_AN_OBJECT = 'Cannot convert undefined or null to object';
      LENGTH_NAME = 'length';

    class function ReadAccessor(const Source: IJSObject; const Name: string; out Accessor: TJSValue): Boolean; static;
    class function ReadFlag(const Source: IJSObject; const Name: string; out Flag: Boolean): Boolean; static;

  public
    class function ToDefinition(const Value: TJSValue): TJSPropertyDefinition; static;
    class function ToDescriptorObject(const Descriptor: TJSPropertyDescriptor): IJSObject; static;
    class function WithCheckedLength(const Target: IJSObject; const Name: string;
                                     const Definition: TJSPropertyDefinition;
                                     const Limits: TJSLimits): TJSPropertyDefinition; static;
    class procedure Define(const Target: IJSObject; const Name: string;
                           const Definition: TJSPropertyDefinition; const Limits: TJSLimits); static;
    class procedure DefineAll(const Target: IJSObject; const Properties: TJSValue; const Limits: TJSLimits); static;
  end;

implementation

class function TJSPropertyDescriptors.ReadFlag(const Source: IJSObject; const Name: string; out Flag: Boolean): Boolean;
begin
  Result := Source.HasProperty(Name);
  Flag := Result and Source.GetProperty(Name).ToBoolean;
end;

class function TJSPropertyDescriptors.ReadAccessor(const Source: IJSObject; const Name: string;
                                                   out Accessor: TJSValue): Boolean;
begin
  Result := Source.HasProperty(Name);
  Accessor := TJSValue.CreateUndefined;
  if not Result then
    Exit;

  Accessor := Source.GetProperty(Name);

  const IsValid = Accessor.IsUndefined or Accessor.IsFunction;
  if not IsValid then
    raise TJSErrorFactory.TypeError(ACCESSOR_NOT_CALLABLE);
end;

class function TJSPropertyDescriptors.ToDefinition(const Value: TJSValue): TJSPropertyDefinition;
begin
  if not Value.IsObject then
    raise TJSErrorFactory.TypeError(DESCRIPTOR_NOT_AN_OBJECT);

  const Source = Value.ToObject;

  Result := Default(TJSPropertyDefinition);
  Result.HasEnumerable := ReadFlag(Source, ATTRIBUTE_ENUMERABLE, Result.Enumerable);
  Result.HasConfigurable := ReadFlag(Source, ATTRIBUTE_CONFIGURABLE, Result.Configurable);
  Result.HasWritable := ReadFlag(Source, ATTRIBUTE_WRITABLE, Result.Writable);

  Result.HasValue := Source.HasProperty(ATTRIBUTE_VALUE);
  if Result.HasValue then
    Result.Value := Source.GetProperty(ATTRIBUTE_VALUE);

  Result.HasGetter := ReadAccessor(Source, ATTRIBUTE_GET, Result.Getter);
  Result.HasSetter := ReadAccessor(Source, ATTRIBUTE_SET, Result.Setter);

  if Result.IsAccessorDefinition and Result.IsDataDefinition then
    raise TJSErrorFactory.TypeError(MIXED_DESCRIPTOR);
end;

class function TJSPropertyDescriptors.ToDescriptorObject(const Descriptor: TJSPropertyDescriptor): IJSObject;
begin
  Result := TJSObject.Create;

  if Descriptor.IsAccessor then
  begin
    Result.SetProperty(ATTRIBUTE_GET, Descriptor.Getter);
    Result.SetProperty(ATTRIBUTE_SET, Descriptor.Setter);
  end
  else
  begin
    Result.SetProperty(ATTRIBUTE_VALUE, Descriptor.Value);
    Result.SetProperty(ATTRIBUTE_WRITABLE, TJSValue.CreateBoolean(Descriptor.Writable));
  end;

  Result.SetProperty(ATTRIBUTE_ENUMERABLE, TJSValue.CreateBoolean(Descriptor.Enumerable));
  Result.SetProperty(ATTRIBUTE_CONFIGURABLE, TJSValue.CreateBoolean(Descriptor.Configurable));
end;

class function TJSPropertyDescriptors.WithCheckedLength(const Target: IJSObject; const Name: string;
                                                        const Definition: TJSPropertyDefinition;
                                                        const Limits: TJSLimits): TJSPropertyDefinition;
begin
  Result := Definition;

  const SetsArrayLength = Definition.HasValue and (Name = LENGTH_NAME) and Supports(Target, IJSArray);
  if not SetsArrayLength then
    Exit;

  const RequestedLength = Definition.Value.ToNumber;
  Result.Value := TJSValue.CreateNumber(RequestedLength);

  const IsStorableLength = (not IsNaN(RequestedLength)) and (RequestedLength >= 0) and (RequestedLength <= MaxInt);
  if IsStorableLength then
    Limits.EnsureArrayLength(Trunc(RequestedLength));
end;

class procedure TJSPropertyDescriptors.Define(const Target: IJSObject; const Name: string;
                                              const Definition: TJSPropertyDefinition;
                                              const Limits: TJSLimits);
begin
  const CheckedDefinition = WithCheckedLength(Target, Name, Definition, Limits);

  if not Target.DefineOwnProperty(Name, CheckedDefinition) then
    raise TJSErrorFactory.TypeError(Format(CANNOT_REDEFINE, [Name]));
end;

class procedure TJSPropertyDescriptors.DefineAll(const Target: IJSObject; const Properties: TJSValue;
                                                 const Limits: TJSLimits);
begin
  if Properties.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(PROPERTIES_NOT_AN_OBJECT);

  if not Properties.IsObject then
    Exit;

  const Source = Properties.ToObject;
  var Names: TArray<string> := nil;
  var Definitions: TArray<TJSPropertyDefinition> := nil;

  for var Name in Source.GetOwnPropertyNames do
  begin
    const Descriptor = Source.GetOwnPropertyDescriptor(Name);
    if not Descriptor.Enumerable then
      Continue;

    const Definition = ToDefinition(Source.GetProperty(Name));
    Names := Names + [Name];
    Definitions := Definitions + [Definition];
  end;

  for var Index := 0 to Length(Names) - 1 do
  begin
    Define(Target, Names[Index], Definitions[Index], Limits);
  end;
end;

end.
