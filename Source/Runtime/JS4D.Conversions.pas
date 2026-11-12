unit JS4D.Conversions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types;

type
  TJSConversions = class
  private
    const
      MAX_SAFE_LENGTH = 9007199254740991.0;
      UINT32_RANGE = 4294967296.0;
      NOT_CALLABLE = 'The value of property ''%s'' is not a function';
      CANNOT_ASSIGN_PROPERTY = 'Cannot assign to read only property ''%s''';

  public
    class function ToText(const Value: TJSValue; const Limits: TJSLimits): string; static;
    class function ToNumber(const Value: TJSValue): Double; static;
    class function ToIntegerOrInfinity(const Value: TJSValue): Double; static;
    class function ToLength(const Value: TJSValue): Int64; static;
    class function ToUint32(const Value: TJSValue): Int64; static;
    class function IsCallable(const Value: TJSValue): Boolean; static;
    class function AsFunction(const Value: TJSValue): IJSFunction; static;
    class function IsRegExp(const Value: TJSValue): Boolean; static;
    class function FindMethod(const Source: TJSValue; const Key: string): IJSFunction; static;
    class procedure PutProperty(const Target: IJSObject; const Key: string; const Value: TJSValue); static;
  end;

implementation

uses
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

  Result := Trunc(EnsureRange(Number, 0, MAX_SAFE_LENGTH));
end;

class function TJSConversions.ToUint32(const Value: TJSValue): Int64;
begin
  const Number = ToNumber(Value);
  if System.Math.IsNaN(Number) or System.Math.IsInfinite(Number) then
    Exit(0);

  const Whole = Int(Number);

  Result := Trunc(Whole - UINT32_RANGE * Floor(Whole / UINT32_RANGE));
end;

class function TJSConversions.IsCallable(const Value: TJSValue): Boolean;
begin
  Result := Value.IsFunction;
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
    Exit(Matcher.ToBoolean);

  Result := Supports(Value.ToObject, IJSRegExp);
end;

class function TJSConversions.FindMethod(const Source: TJSValue; const Key: string): IJSFunction;
begin
  const Method = Source.ToObject.GetProperty(Key);
  if Method.IsNullOrUndefined then
    Exit(nil);

  Result := AsFunction(Method);
  if not Assigned(Result) then
    raise TJSErrorFactory.TypeError(Format(NOT_CALLABLE, [Key]));
end;

class procedure TJSConversions.PutProperty(const Target: IJSObject; const Key: string; const Value: TJSValue);
begin
  if not TJSPropertyDescriptors.CanPut(Target, Key) then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [Key]));

  Target.SetProperty(Key, Value);
end;

end.
