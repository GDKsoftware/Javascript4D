unit JS4D.Conversions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSConversions = class
  private
    const
      NOT_CALLABLE = 'The value of property ''%s'' is not a function';
      CANNOT_ASSIGN_PROPERTY = 'Cannot assign to read only property ''%s''';
      CONSTRUCTOR_NOT_AN_OBJECT = 'The constructor property must be an object or undefined';
      SPECIES_NOT_A_CONSTRUCTOR = 'The species of a constructor must be a constructor, null or undefined';

    class function SpeciesOf(const ConstructorValue: TJSValue; const IntrinsicSpeciesGetter: IJSFunction): TJSValue;
      static;

  public
    class function ToText(const Value: TJSValue; const Limits: TJSLimits): string; static;
    class function ToNumber(const Value: TJSValue): Double; static;
    class function ToIntegerOrInfinity(const Value: TJSValue): Double; static;
    class function ToLength(const Value: TJSValue): Int64; static;
    class function ToUint32(const Value: TJSValue): Int64; static;
    class function AsFunction(const Value: TJSValue): IJSFunction; static;
    class function IsRegExp(const Value: TJSValue): Boolean; static;
    class function FindMethod(const Source: TJSValue; const Key: TJSPropertyKey): IJSFunction; static;
    class function SpeciesConstructor(const Source: IJSObject; const DefaultConstructor: IJSFunction;
                                      const IntrinsicSpeciesGetter: IJSFunction = nil): IJSFunction; static;
    class procedure PutProperty(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue); static;
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.Errors,
  JS4D.SymbolRegistry,
  JS4D.PropertyDescriptors;

class function TJSConversions.ToText(const Value: TJSValue; const Limits: TJSLimits): string;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.String_);

  Result := Primitive.ToLimitedString(Limits);
end;

class function TJSConversions.ToNumber(const Value: TJSValue): Double;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number);

  Result := Primitive.ToNumber;
end;

class function TJSConversions.ToIntegerOrInfinity(const Value: TJSValue): Double;
begin
  const Number = ToNumber(Value);
  if System.Math.IsNaN(Number) then
    Exit(0);

  Result := Int(Number);
end;

class function TJSConversions.ToLength(const Value: TJSValue): Int64;
begin
  const Number = ToIntegerOrInfinity(Value);

  Result := Trunc(EnsureRange(Number, 0, MAX_SAFE_INTEGER));
end;

class function TJSConversions.ToUint32(const Value: TJSValue): Int64;
begin
  const Number = ToNumber(Value);
  if System.Math.IsNaN(Number) or System.Math.IsInfinite(Number) then
    Exit(0);

  const Whole = Int(Number);

  Result := Trunc(Whole - UINT32_RANGE * Floor(Whole / UINT32_RANGE));
end;

class function TJSConversions.AsFunction(const Value: TJSValue): IJSFunction;
begin
  if not Value.IsFunction then
    Exit(nil);

  Supports(Value.ToObject, IJSFunction, Result);
end;

class function TJSConversions.IsRegExp(const Value: TJSValue): Boolean;
begin
  if not Value.IsObject then
    Exit(False);

  const MatcherKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Match);
  const Matcher = Value.ToObject.GetProperty(MatcherKey);
  if not Matcher.IsUndefined then
  begin
    Result := Matcher.ToBoolean;
    Exit;
  end;

  Result := Supports(Value.ToObject, IJSRegExp);
end;

class function TJSConversions.FindMethod(const Source: TJSValue; const Key: TJSPropertyKey): IJSFunction;
begin
  const Method = Source.ToObject.GetProperty(Key);
  if Method.IsNullOrUndefined then
    Exit(nil);

  Result := AsFunction(Method);
  if not Assigned(Result) then
    raise TJSErrorFactory.TypeError(Format(NOT_CALLABLE, [Key.Text]));
end;

class function TJSConversions.SpeciesOf(const ConstructorValue: TJSValue;
                                        const IntrinsicSpeciesGetter: IJSFunction): TJSValue;
begin
  const SpeciesKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);
  const ConstructorObject = ConstructorValue.ToObject;

  var Descriptor: TJSPropertyDescriptor;
  const IsIntrinsicGetter = Assigned(IntrinsicSpeciesGetter) and
                            ConstructorObject.TryGetPropertyDescriptor(SpeciesKey, Descriptor) and
                            Descriptor.IsAccessor and Descriptor.Getter.IsFunction and
                            ((Descriptor.Getter.ToObject as IInterface) = (IntrinsicSpeciesGetter as IInterface));
  if IsIntrinsicGetter then
    Exit(ConstructorValue);

  Result := ConstructorObject.GetProperty(SpeciesKey);
end;

class function TJSConversions.SpeciesConstructor(const Source: IJSObject; const DefaultConstructor: IJSFunction;
                                                 const IntrinsicSpeciesGetter: IJSFunction): IJSFunction;
begin
  const ConstructorValue = Source.GetProperty(CONSTRUCTOR_PROPERTY);
  if ConstructorValue.IsUndefined then
    Exit(DefaultConstructor);

  if not ConstructorValue.IsObject then
    raise TJSErrorFactory.TypeError(CONSTRUCTOR_NOT_AN_OBJECT);

  const Species = SpeciesOf(ConstructorValue, IntrinsicSpeciesGetter);
  if Species.IsNullOrUndefined then
    Exit(DefaultConstructor);

  if not Species.TryGetConstructor(Result) then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_CONSTRUCTOR);
end;

class procedure TJSConversions.PutProperty(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue);
begin
  if not TJSPropertyDescriptors.CanPut(Target, Key) then
  begin
    const Message = Format(CANNOT_ASSIGN_PROPERTY, [Key.Text]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Target.SetProperty(Key, Value);
end;

end.
