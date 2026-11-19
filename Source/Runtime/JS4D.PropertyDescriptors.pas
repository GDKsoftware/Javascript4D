unit JS4D.PropertyDescriptors;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.Errors;

type
  TJSPropertyDescriptors = class
  private
    type
      TPendingDefinition = record
        Name: TJSPropertyKey;
        Definition: TJSPropertyDefinition;
      end;

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
      LENGTH_NAME = 'length';

    class function ReadAccessor(const Source: IJSObject; const Name: string; out Accessor: TJSValue): Boolean; static;
    class function TryReadFlag(const Source: IJSObject; const Name: string; out Flag: Boolean): Boolean; static;

  public
    class function ToDefinition(const Value: TJSValue): TJSPropertyDefinition; static;
    class function ToDescriptorObject(const Descriptor: TJSPropertyDescriptor;
                                      const ObjectPrototype: IJSObject): IJSObject; static;
    class function WithCheckedLength(const Target: IJSObject; const Name: TJSPropertyKey;
                                     const Definition: TJSPropertyDefinition;
                                     const Limits: TJSLimits): TJSPropertyDefinition; static;
    class procedure Define(const Target: IJSObject; const Name: TJSPropertyKey;
                           const Definition: TJSPropertyDefinition; const Limits: TJSLimits); static;
    class procedure DefineAll(const Target: IJSObject; const Properties: TJSValue; const Limits: TJSLimits); static;
    class function CanPut(const Target: IJSObject; const Name: TJSPropertyKey): Boolean; static;
  end;

implementation

uses
  JS4D.ObjectOperations,
  JS4D.ArrayLike;

class function TJSPropertyDescriptors.TryReadFlag(const Source: IJSObject; const Name: string;
                                                  out Flag: Boolean): Boolean;
begin
  Result := Source.HasProperty(Name);
  Flag := False;
  if not Result then
    Exit;

  const FlagValue = Source.GetProperty(Name);
  Flag := FlagValue.ToBoolean;
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
  Result.HasEnumerable := TryReadFlag(Source, ATTRIBUTE_ENUMERABLE, Result.Enumerable);
  Result.HasConfigurable := TryReadFlag(Source, ATTRIBUTE_CONFIGURABLE, Result.Configurable);
  Result.HasWritable := TryReadFlag(Source, ATTRIBUTE_WRITABLE, Result.Writable);

  Result.HasValue := Source.HasProperty(ATTRIBUTE_VALUE);
  if Result.HasValue then
    Result.Value := Source.GetProperty(ATTRIBUTE_VALUE);

  Result.HasGetter := ReadAccessor(Source, ATTRIBUTE_GET, Result.Getter);
  Result.HasSetter := ReadAccessor(Source, ATTRIBUTE_SET, Result.Setter);

  if Result.IsAccessorDefinition and Result.IsDataDefinition then
    raise TJSErrorFactory.TypeError(MIXED_DESCRIPTOR);
end;

class function TJSPropertyDescriptors.ToDescriptorObject(const Descriptor: TJSPropertyDescriptor;
                                                         const ObjectPrototype: IJSObject): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := ObjectPrototype;

  if Descriptor.IsAccessor then
  begin
    Result.SetProperty(ATTRIBUTE_GET, Descriptor.Getter);
    Result.SetProperty(ATTRIBUTE_SET, Descriptor.Setter);
  end
  else
  begin
    const WritableValue = TJSValue.CreateBoolean(Descriptor.Writable);

    Result.SetProperty(ATTRIBUTE_VALUE, Descriptor.Value);
    Result.SetProperty(ATTRIBUTE_WRITABLE, WritableValue);
  end;

  const EnumerableValue = TJSValue.CreateBoolean(Descriptor.Enumerable);
  const ConfigurableValue = TJSValue.CreateBoolean(Descriptor.Configurable);

  Result.SetProperty(ATTRIBUTE_ENUMERABLE, EnumerableValue);
  Result.SetProperty(ATTRIBUTE_CONFIGURABLE, ConfigurableValue);
end;

class function TJSPropertyDescriptors.WithCheckedLength(const Target: IJSObject; const Name: TJSPropertyKey;
                                                        const Definition: TJSPropertyDefinition;
                                                        const Limits: TJSLimits): TJSPropertyDefinition;
begin
  Result := Definition;

  const IsArray = Supports(Target, IJSArray);

  var ElementIndex: Integer;
  const DefinesArrayElement = IsArray and TJSArray.TryParseIndex(Name, ElementIndex);
  if DefinesArrayElement then
  begin
    const RequiredLength = Int64(ElementIndex) + 1;

    Limits.EnsureArrayLength(RequiredLength);
  end;

  const IsLengthName = (Name = LENGTH_NAME);
  const SetsArrayLength = (Definition.HasValue and IsLengthName and IsArray);
  if not SetsArrayLength then
    Exit;

  const RequestedLength = TJSArray.CoerceLength(Definition.Value);
  Result.Value := TJSValue.CreateNumber(RequestedLength);

  Limits.EnsureArrayLength(RequestedLength);
end;

class procedure TJSPropertyDescriptors.Define(const Target: IJSObject; const Name: TJSPropertyKey;
                                              const Definition: TJSPropertyDefinition;
                                              const Limits: TJSLimits);
begin
  const CheckedDefinition = WithCheckedLength(Target, Name, Definition, Limits);

  const IsDefined = Target.DefineOwnProperty(Name, CheckedDefinition);
  if not IsDefined then
    raise TJSErrorFactory.CannotRedefineProperty(Name.Text);
end;

class procedure TJSPropertyDescriptors.DefineAll(const Target: IJSObject; const Properties: TJSValue;
                                                 const Limits: TJSLimits);
begin
  if Properties.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  if not Properties.IsObject then
    Exit;

  const Source = Properties.ToObject;
  const Pending = TList<TPendingDefinition>.Create;
  try
    for var Name in TJSObjectOperations.OwnKeys(Source) do
    begin
      const Descriptor = Source.GetOwnPropertyDescriptor(Name);
      if not Descriptor.Enumerable then
        Continue;

      const DescriptorValue = Source.GetProperty(Name);

      var Entry: TPendingDefinition;
      Entry.Name := Name;
      Entry.Definition := ToDefinition(DescriptorValue);
      Pending.Add(Entry);
    end;

    for var Entry in Pending do
    begin
      Define(Target, Entry.Name, Entry.Definition, Limits);
    end;
  finally
    Pending.Free;
  end;
end;

class function TJSPropertyDescriptors.CanPut(const Target: IJSObject; const Name: TJSPropertyKey): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  if not Target.TryGetPropertyDescriptor(Name, Descriptor) then
  begin
    Result := Target.IsExtensible or TJSIntegerIndexedKeys.IsInvalidIndexKey(Target, Name);
    Exit;
  end;

  if Descriptor.IsAccessor then
    Exit(Descriptor.Setter.IsFunction);

  if not Descriptor.Writable then
    Exit(False);

  Result := Target.HasOwnProperty(Name) or Target.IsExtensible;
end;

end.
