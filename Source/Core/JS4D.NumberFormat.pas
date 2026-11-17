unit JS4D.NumberFormat;

interface

type
  TJSRoundedDecimal = record
    IntegerDigits: string;
    FractionDigits: string;
  end;

  TJSNumberFormat = class
  private
    type
      TDecimalDigits = record
        Digits: string;
        PointPosition: Integer;
      end;

      TDigitBuffer = record
        Digits: TArray<Byte>;
        Count: Integer;
        procedure Append(const Digit: Byte);
        procedure MultiplyBy(const Factor: Integer);
        procedure ScaleByBinaryExponent(const Exponent: Integer);
      end;

    const
      MAX_ROUND_TRIP_PRECISION = 17;
      MAX_PLAIN_POINT = 21;
      MIN_PLAIN_POINT = -6;
      MAX_FIXED_VALUE = 1e21;
      MAX_EXACT_INTEGER_TEXT = 1e15;
      MAX_FRACTION_DIGITS = 100;
      MAX_PRECISION = 100;
      DECIMAL_BASE = 10;
      BINARY_FACTOR = 2;
      DECIMAL_FACTOR = 5;
      INITIAL_DIGIT_CAPACITY = 64;

    class function MantissaDigits(const Mantissa: UInt64): TDigitBuffer; static;
    class function DigitsToText(const Number: TDigitBuffer): string; static;
    class function ExactDigits(const Value: Double): TDecimalDigits; static;
    class function DigitsOf(const Magnitude: Double; const Count: Integer): TDecimalDigits; static;
    class function ShortestDigits(const Value: Double): TDecimalDigits; static;
    class function RoundToCount(const Source: TDecimalDigits; const Count: Integer): TDecimalDigits; static;
    class function RoundTrips(const Digits: TDecimalDigits; const Value: Double): Boolean; static;
    class function ZeroDigits(const Count: Integer): TDecimalDigits; static;
    class function ExponentSuffix(const Exponent: Integer): string; static;
    class function PositionalText(const Digits: TDecimalDigits): string; static;
    class function ExponentialText(const Digits: TDecimalDigits): string; static;
    class function FixedText(const Magnitude: Double; const FractionDigits: Integer): string; static;
    class function SignedText(const Value: Double; const MagnitudeText: string): string; static;
    class function TryGetSpecialText(const Value: Double; out Text: string): Boolean; static;

  public
    class function ToDecimalString(const Value: Double): string; static;
    class function ToFixed(const Value: Double; const FractionDigits: Integer): string; static;
    class function ToExponential(const Value: Double; const FractionDigits: Integer): string; static;
    class function ToShortestExponential(const Value: Double): string; static;
    class function ToPrecision(const Value: Double; const Precision: Integer): string; static;
    class function ToRoundedDecimal(const Magnitude: Double; const FractionDigits: Integer;
                                    const PointShift: Integer = 0): TJSRoundedDecimal; static;

    class function IsFractionDigitsInRange(const FractionDigits: Integer): Boolean; static;
    class function IsPrecisionInRange(const Precision: Integer): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  System.Math,
  JS4D.Binary64,
  JS4D.DecimalConversion,
  JS4D.NumberText;

{ TJSNumberFormat.TDigitBuffer }

procedure TJSNumberFormat.TDigitBuffer.Append(const Digit: Byte);
begin
  const IsFull = (Count = Length(Digits));
  if IsFull then
    SetLength(Digits, Length(Digits) * 2);

  Digits[Count] := Digit;
  Inc(Count);
end;

procedure TJSNumberFormat.TDigitBuffer.MultiplyBy(const Factor: Integer);
begin
  var Carry := 0;

  for var Position := 0 to Count - 1 do
  begin
    const Product = (Digits[Position] * Factor) + Carry;
    Digits[Position] := Product mod DECIMAL_BASE;
    Carry := Product div DECIMAL_BASE;
  end;

  while Carry > 0 do
  begin
    Append(Carry mod DECIMAL_BASE);
    Carry := Carry div DECIMAL_BASE;
  end;
end;

procedure TJSNumberFormat.TDigitBuffer.ScaleByBinaryExponent(const Exponent: Integer);
begin
  const IsMultiplyingByTwo = (Exponent >= 0);
  const Factor = IfThen(IsMultiplyingByTwo, BINARY_FACTOR, DECIMAL_FACTOR);

  for var Step := 1 to Abs(Exponent) do
  begin
    MultiplyBy(Factor);
  end;
end;

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

class function TJSNumberFormat.SignedText(const Value: Double; const MagnitudeText: string): string;
begin
  const IsNegative = (Value < 0);
  if IsNegative then
    Result := Format('%s%s', [MINUS_SIGN, MagnitudeText])
  else
    Result := MagnitudeText;
end;

class function TJSNumberFormat.MantissaDigits(const Mantissa: UInt64): TDigitBuffer;
begin
  Result.Count := 0;
  SetLength(Result.Digits, INITIAL_DIGIT_CAPACITY);

  var Remaining := Mantissa;
  while Remaining > 0 do
  begin
    Result.Append(Remaining mod DECIMAL_BASE);
    Remaining := Remaining div DECIMAL_BASE;
  end;
end;

class function TJSNumberFormat.DigitsToText(const Number: TDigitBuffer): string;
begin
  SetLength(Result, Number.Count);

  for var Position := 0 to Number.Count - 1 do
  begin
    Result[Number.Count - Position] := Chr(Ord('0') + Number.Digits[Position]);
  end;
end;

class function TJSNumberFormat.ExactDigits(const Value: Double): TDecimalDigits;
begin
  const BiasedExponent = Integer(Value.Exp);
  const IsDenormal = (BiasedExponent = 0);
  var Mantissa: UInt64 := Value.Frac;
  if not IsDenormal then
    Mantissa := Mantissa or HIDDEN_BIT;

  const Exponent = IfThen(IsDenormal, DENORMAL_EXPONENT, BiasedExponent - EXPONENT_BIAS);

  var Number := MantissaDigits(Mantissa);
  Number.ScaleByBinaryExponent(Exponent);

  const Text = DigitsToText(Number);
  const IsFractional = (Exponent < 0);
  const DecimalShift = IfThen(IsFractional, -Exponent, 0);

  Result.PointPosition := Length(Text) - DecimalShift;
  Result.Digits := Text.TrimRight(['0']);
end;

class function TJSNumberFormat.ZeroDigits(const Count: Integer): TDecimalDigits;
begin
  Result.Digits := StringOfChar('0', Count);
  Result.PointPosition := 1;
end;

class function TJSNumberFormat.DigitsOf(const Magnitude: Double; const Count: Integer): TDecimalDigits;
begin
  const IsZero = (Magnitude = 0);
  if IsZero then
  begin
    Result := ZeroDigits(Count);
    Exit;
  end;

  const Exact = ExactDigits(Magnitude);
  Result := RoundToCount(Exact, Count);
end;

class function TJSNumberFormat.RoundToCount(const Source: TDecimalDigits; const Count: Integer): TDecimalDigits;
begin
  Result.PointPosition := Source.PointPosition;

  const KeepsAllDigits = (Count >= Length(Source.Digits));
  if KeepsAllDigits then
  begin
    Result.Digits := TJSNumberText.PadRight(Source.Digits, Count);
    Exit;
  end;

  const KeepsNoDigits = (Count < 0);
  if KeepsNoDigits then
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

  const HasDigitToIncrement = (Position >= 1);
  if HasDigitToIncrement then
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

  var HasRangeLeft := (Lowest < Highest);
  while HasRangeLeft do
  begin
    const Middle = (Lowest + Highest) div 2;
    const Candidate = RoundToCount(Exact, Middle);
    if RoundTrips(Candidate, Value) then
      Highest := Middle
    else
      Lowest := Middle + 1;

    HasRangeLeft := (Lowest < Highest);
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

  const IsWholeNumber = (Point >= Count);
  const HasIntegerPart = (Point > 0);
  if IsWholeNumber then
    Result := Digits.Digits + StringOfChar('0', Point - Count)
  else if HasIntegerPart then
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

class function TJSNumberFormat.FixedText(const Magnitude: Double; const FractionDigits: Integer): string;
begin
  var Scaled := '';
  const HasMagnitude = (Magnitude > 0);
  if HasMagnitude then
  begin
    const Exact = ExactDigits(Magnitude);
    const Rounded = RoundToCount(Exact, Exact.PointPosition + FractionDigits);
    Scaled := TJSNumberText.PadRight(Rounded.Digits, Rounded.PointPosition + FractionDigits);
  end;

  const MinimumLength = FractionDigits + 1;
  Scaled := TJSNumberText.PadLeft(Scaled, MinimumLength);

  const SplitAt = Length(Scaled) - FractionDigits;
  Result := Copy(Scaled, 1, SplitAt);

  const HasFraction = (FractionDigits > 0);
  if HasFraction then
    Result := Format('%s.%s', [Result, Copy(Scaled, SplitAt + 1, FractionDigits)]);
end;

class function TJSNumberFormat.ToDecimalString(const Value: Double): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const IsShortInteger = (Frac(Value) = 0) and (Abs(Value) < MAX_EXACT_INTEGER_TEXT);
  if IsShortInteger then
  begin
    const Whole = Trunc(Value);
    Result := IntToStr(Whole);
    Exit;
  end;

  const Digits = ShortestDigits(Abs(Value));
  const IsPlain = (Digits.PointPosition > MIN_PLAIN_POINT) and (Digits.PointPosition <= MAX_PLAIN_POINT);
  var Text: string;
  if IsPlain then
    Text := PositionalText(Digits)
  else
    Text := ExponentialText(Digits);

  Result := SignedText(Value, Text);
end;

class function TJSNumberFormat.ToFixed(const Value: Double; const FractionDigits: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const Magnitude = Abs(Value);
  const IsTooLargeForFixed = (Magnitude >= MAX_FIXED_VALUE);
  if IsTooLargeForFixed then
  begin
    Result := ToDecimalString(Value);
    Exit;
  end;

  const Fixed = FixedText(Magnitude, FractionDigits);
  Result := SignedText(Value, Fixed);
end;

class function TJSNumberFormat.ToExponential(const Value: Double; const FractionDigits: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const Digits = DigitsOf(Abs(Value), FractionDigits + 1);
  const Text = ExponentialText(Digits);

  Result := SignedText(Value, Text);
end;

class function TJSNumberFormat.ToShortestExponential(const Value: Double): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const Magnitude = Abs(Value);
  var Digits := ZeroDigits(1);
  const HasMagnitude = (Magnitude > 0);
  if HasMagnitude then
    Digits := ShortestDigits(Magnitude);

  const Text = ExponentialText(Digits);

  Result := SignedText(Value, Text);
end;

class function TJSNumberFormat.ToPrecision(const Value: Double; const Precision: Integer): string;
begin
  if TryGetSpecialText(Value, Result) then
    Exit;

  const Digits = DigitsOf(Abs(Value), Precision);
  const Exponent = Digits.PointPosition - 1;
  const NeedsExponent = (Exponent < MIN_PLAIN_POINT) or (Exponent >= Precision);
  var Text: string;
  if NeedsExponent then
    Text := ExponentialText(Digits)
  else
    Text := PositionalText(Digits);

  Result := SignedText(Value, Text);
end;

class function TJSNumberFormat.ToRoundedDecimal(const Magnitude: Double; const FractionDigits: Integer;
                                                 const PointShift: Integer): TJSRoundedDecimal;
begin
  Result.IntegerDigits := '0';
  Result.FractionDigits := '';

  const IsZero = (Magnitude = 0);
  if IsZero then
    Exit;

  var Digits := ShortestDigits(Magnitude);
  Digits.PointPosition := Digits.PointPosition + PointShift;

  const KeptCount = Digits.PointPosition + FractionDigits;
  const IsBelowPrecision = (KeptCount < 0);
  if IsBelowPrecision then
    Exit;

  const Rounded = RoundToCount(Digits, KeptCount);
  const HasIntegerDigits = (Rounded.PointPosition > 0);
  if HasIntegerDigits then
  begin
    const Padded = TJSNumberText.PadRight(Rounded.Digits, Rounded.PointPosition);
    const Fraction = Copy(Padded, Rounded.PointPosition + 1, Length(Padded));

    Result.IntegerDigits := Copy(Padded, 1, Rounded.PointPosition);
    Result.FractionDigits := Fraction.TrimRight(['0']);
  end
  else
  begin
    const Fraction = StringOfChar('0', -Rounded.PointPosition) + Rounded.Digits;

    Result.FractionDigits := Fraction.TrimRight(['0']);
  end;
end;

end.
