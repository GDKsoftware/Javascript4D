unit JS4D.NumberFormat;

{$SCOPEDENUMS ON}

interface

type
  TJSNumberFormat = class
  private
    type
      TDecimalDigits = record
        Digits: string;
        PointPosition: Integer;
      end;

    const
      INFINITY_TEXT = 'Infinity';
      NEGATIVE_INFINITY_TEXT = '-Infinity';
      NAN_TEXT = 'NaN';
      MAX_ROUND_TRIP_PRECISION = 17;
      MAX_PLAIN_POINT = 21;
      MIN_PLAIN_POINT = -6;
      MAX_FIXED_VALUE = 1e21;
      MAX_EXACT_INTEGER_TEXT = 1e15;
      MAX_FRACTION_DIGITS = 100;
      MAX_PRECISION = 100;
      DECIMAL_BASE = 10;
      EXPONENT_BIAS = 1075;
      DENORMAL_EXPONENT = -1074;
      IMPLICIT_BIT = UInt64(1) shl 52;

    class function ExactDigits(const Value: Double): TDecimalDigits; static;
    class function MultiplyDigits(const Number: TArray<Byte>; const Factor: Integer): TArray<Byte>; static;
    class function ShortestDigits(const Value: Double): TDecimalDigits; static;
    class function RoundToCount(const Source: TDecimalDigits; const Count: Integer): TDecimalDigits; static;
    class function RoundTrips(const Digits: TDecimalDigits; const Value: Double): Boolean; static;
    class function ZeroDigits(const Count: Integer): TDecimalDigits; static;
    class function PadDigits(const Digits: string; const Count: Integer): string; static;
    class function ExponentSuffix(const Exponent: Integer): string; static;
    class function PositionalText(const Digits: TDecimalDigits): string; static;
    class function ExponentialText(const Digits: TDecimalDigits): string; static;
    class function TryGetSpecialText(const Value: Double; out Text: string): Boolean; static;

  public
    class function ToDecimalString(const Value: Double): string; static;
    class function ToFixed(const Value: Double; const FractionDigits: Integer): string; static;
    class function ToExponential(const Value: Double; const FractionDigits: Integer): string; static;
    class function ToShortestExponential(const Value: Double): string; static;
    class function ToPrecision(const Value: Double; const Precision: Integer): string; static;

    class function IsFractionDigitsInRange(const FractionDigits: Integer): Boolean; static;
    class function IsPrecisionInRange(const Precision: Integer): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Math,
  JS4D.DecimalConversion;

{ TJSNumberFormat }

class function TJSNumberFormat.IsFractionDigitsInRange(const FractionDigits: Integer): Boolean;
begin
  Result := (FractionDigits >= 0) and (FractionDigits <= MAX_FRACTION_DIGITS);
end;

class function TJSNumberFormat.IsPrecisionInRange(const Precision: Integer): Boolean;
begin
  Result := (Precision >= 1) and (Precision <= MAX_PRECISION);
end;

class function TJSNumberFormat.TryGetSpecialText(const Value: Double; out Text: string): Boolean;
begin
  Result := True;

  if IsNan(Value) then
    Text := NAN_TEXT
  else if IsInfinite(Value) then
    Text := IfThen(Value < 0, NEGATIVE_INFINITY_TEXT, INFINITY_TEXT)
  else
    Result := False;
end;

class function TJSNumberFormat.MultiplyDigits(const Number: TArray<Byte>; const Factor: Integer): TArray<Byte>;
begin
  var Carry := 0;
  Result := Copy(Number);

  for var Position := 0 to High(Result) do
  begin
    const Product = (Result[Position] * Factor) + Carry;
    Result[Position] := Product mod DECIMAL_BASE;
    Carry := Product div DECIMAL_BASE;
  end;

  while Carry > 0 do
  begin
    Result := Result + [Byte(Carry mod DECIMAL_BASE)];
    Carry := Carry div DECIMAL_BASE;
  end;
end;

class function TJSNumberFormat.ExactDigits(const Value: Double): TDecimalDigits;
begin
  const BiasedExponent = Integer(Value.Exp);
  const IsDenormal = (BiasedExponent = 0);
  var Mantissa: UInt64 := Value.Frac;
  if not IsDenormal then
    Mantissa := Mantissa or IMPLICIT_BIT;

  const Exponent = IfThen(IsDenormal, DENORMAL_EXPONENT, BiasedExponent - EXPONENT_BIAS);

  var Number: TArray<Byte> := [];
  while Mantissa > 0 do
  begin
    Number := Number + [Byte(Mantissa mod DECIMAL_BASE)];
    Mantissa := Mantissa div DECIMAL_BASE;
  end;

  const Factor = IfThen(Exponent >= 0, 2, 5);
  for var Step := 1 to Abs(Exponent) do
  begin
    Number := MultiplyDigits(Number, Factor);
  end;

  var Text := '';
  SetLength(Text, Length(Number));
  for var Position := 0 to High(Number) do
  begin
    Text[Length(Number) - Position] := Chr(Ord('0') + Number[Position]);
  end;

  Result.PointPosition := Length(Text) - IfThen(Exponent < 0, -Exponent, 0);
  Result.Digits := Text.TrimRight(['0']);
end;

class function TJSNumberFormat.ZeroDigits(const Count: Integer): TDecimalDigits;
begin
  Result.Digits := StringOfChar('0', Count);
  Result.PointPosition := 1;
end;

class function TJSNumberFormat.PadDigits(const Digits: string; const Count: Integer): string;
begin
  Result := Digits + StringOfChar('0', Max(0, Count - Length(Digits)));
end;

class function TJSNumberFormat.RoundToCount(const Source: TDecimalDigits; const Count: Integer): TDecimalDigits;
begin
  Result.PointPosition := Source.PointPosition;

  if Count >= Length(Source.Digits) then
  begin
    Result.Digits := PadDigits(Source.Digits, Count);
    Exit;
  end;

  if Count < 0 then
  begin
    Result.Digits := '';
    Exit;
  end;

  var Kept := Copy(Source.Digits, 1, Count);
  const RoundUp = (Source.Digits[Count + 1] >= '5');
  if not RoundUp then
  begin
    Result.Digits := Kept;
    Exit;
  end;

  var Position := Count;
  while (Position >= 1) and (Kept[Position] = '9') do
  begin
    Kept[Position] := '0';
    Dec(Position);
  end;

  if Position >= 1 then
  begin
    Kept[Position] := Chr(Ord(Kept[Position]) + 1);
    Result.Digits := Kept;
  end
  else
  begin
    Inc(Result.PointPosition);
    Result.Digits := Copy('1' + Kept, 1, Max(1, Count));
  end;
end;

class function TJSNumberFormat.RoundTrips(const Digits: TDecimalDigits; const Value: Double): Boolean;
begin
  const Scale = Digits.PointPosition - Length(Digits.Digits);
  const Parsed = TJSDecimalConversion.ToDouble(Digits.Digits, Scale);

  Result := (Parsed = Value);
end;

class function TJSNumberFormat.ShortestDigits(const Value: Double): TDecimalDigits;
begin
  const Exact = ExactDigits(Value);
  var Lowest := 1;
  var Highest := MAX_ROUND_TRIP_PRECISION;

  while Lowest < Highest do
  begin
    const Middle = (Lowest + Highest) div 2;
    const Candidate = RoundToCount(Exact, Middle);
    if RoundTrips(Candidate, Value) then
      Highest := Middle
    else
      Lowest := Middle + 1;
  end;

  Result := RoundToCount(Exact, Lowest);
  Result.Digits := Result.Digits.TrimRight(['0']);
end;

class function TJSNumberFormat.ExponentSuffix(const Exponent: Integer): string;
begin
  Result := Format('e%s%d', [IfThen(Exponent < 0, '-', '+'), Abs(Exponent)]);
end;

class function TJSNumberFormat.PositionalText(const Digits: TDecimalDigits): string;
begin
  const Count = Length(Digits.Digits);
  const Point = Digits.PointPosition;

  if Point >= Count then
    Result := Digits.Digits + StringOfChar('0', Point - Count)
  else if Point > 0 then
    Result := Format('%s.%s', [Copy(Digits.Digits, 1, Point), Copy(Digits.Digits, Point + 1, Count)])
  else
    Result := Format('0.%s%s', [StringOfChar('0', -Point), Digits.Digits]);
end;

class function TJSNumberFormat.ExponentialText(const Digits: TDecimalDigits): string;
begin
  const Leading = Copy(Digits.Digits, 1, 1);
  const Remaining = Copy(Digits.Digits, 2, Length(Digits.Digits));
  const Mantissa = IfThen(Remaining.IsEmpty, Leading, Format('%s.%s', [Leading, Remaining]));

  const Suffix = ExponentSuffix(Digits.PointPosition - 1);

  Result := Mantissa + Suffix;
end;

class function TJSNumberFormat.ToDecimalString(const Value: Double): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const IsShortInteger = (Frac(Value) = 0) and (Abs(Value) < MAX_EXACT_INTEGER_TEXT);
  if IsShortInteger then
    Exit(IntToStr(Trunc(Value)));

  if Value < 0 then
    Exit(Format('-%s', [ToDecimalString(-Value)]));

  const Digits = ShortestDigits(Value);
  const IsPlain = (Digits.PointPosition > MIN_PLAIN_POINT) and (Digits.PointPosition <= MAX_PLAIN_POINT);
  if IsPlain then
    Result := PositionalText(Digits)
  else
    Result := ExponentialText(Digits);
end;

class function TJSNumberFormat.ToFixed(const Value: Double; const FractionDigits: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  if Value < 0 then
    Exit(Format('-%s', [ToFixed(-Value, FractionDigits)]));

  if Value >= MAX_FIXED_VALUE then
    Exit(ToDecimalString(Value));

  var Scaled := '';
  if Value > 0 then
  begin
    const Exact = ExactDigits(Value);
    const Rounded = RoundToCount(Exact, Exact.PointPosition + FractionDigits);
    Scaled := PadDigits(Rounded.Digits, Rounded.PointPosition + FractionDigits);
  end;

  const MinimumLength = FractionDigits + 1;
  Scaled := StringOfChar('0', Max(0, MinimumLength - Length(Scaled))) + Scaled;

  const SplitAt = Length(Scaled) - FractionDigits;
  Result := Copy(Scaled, 1, SplitAt);
  if FractionDigits > 0 then
    Result := Format('%s.%s', [Result, Copy(Scaled, SplitAt + 1, FractionDigits)]);
end;

class function TJSNumberFormat.ToExponential(const Value: Double; const FractionDigits: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  if Value < 0 then
    Exit(Format('-%s', [ToExponential(-Value, FractionDigits)]));

  var Digits := ZeroDigits(FractionDigits + 1);
  if Value > 0 then
  begin
    const Exact = ExactDigits(Value);
    Digits := RoundToCount(Exact, FractionDigits + 1);
  end;

  Result := ExponentialText(Digits);
end;

class function TJSNumberFormat.ToShortestExponential(const Value: Double): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  if Value < 0 then
    Exit(Format('-%s', [ToShortestExponential(-Value)]));

  var Digits := ZeroDigits(1);
  if Value > 0 then
    Digits := ShortestDigits(Value);

  Result := ExponentialText(Digits);
end;

class function TJSNumberFormat.ToPrecision(const Value: Double; const Precision: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  if Value < 0 then
    Exit(Format('-%s', [ToPrecision(-Value, Precision)]));

  var Digits := ZeroDigits(Precision);
  if Value > 0 then
  begin
    const Exact = ExactDigits(Value);
    Digits := RoundToCount(Exact, Precision);
  end;

  const Exponent = Digits.PointPosition - 1;
  const NeedsExponent = (Exponent < MIN_PLAIN_POINT) or (Exponent >= Precision);
  if NeedsExponent then
    Result := ExponentialText(Digits)
  else
    Result := PositionalText(Digits);
end;

end.
