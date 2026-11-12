unit JS4D.DecimalConversion;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.BigNatural;

type
  TJSDecimalConversion = class
  private
    type
      TDoubleBits = record
        case Boolean of
          False: (Bits: UInt64);
          True: (Value: Double);
      end;

    type
      TQuotient = record
        Mantissa: UInt64;
        Remainder: TJSBigNatural;
        Divisor: TJSBigNatural;
      end;

    const
      MAX_FAST_DIGITS = 15;
      MAX_FAST_POWER = 22;
      MAX_DECIMAL_MAGNITUDE = 309;
      MIN_DECIMAL_MAGNITUDE = -323;
      MANTISSA_BITS = 52;
      MAX_SHIFT = 1074;
      EXPONENT_BIAS = 1075;
      MAX_BIASED_EXPONENT = 2047;
      HIDDEN_BIT = UInt64(1) shl MANTISSA_BITS;
      HIDDEN_BIT_OVERFLOW = UInt64(1) shl (MANTISSA_BITS + 1);
      MANTISSA_MASK = HIDDEN_BIT - 1;
      POWERS_OF_TEN: array[0..MAX_FAST_POWER] of Double = (
        1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
        1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22);

    class function TryConvertExactly(const Digits: string; const Scale: Integer;
                                     out Value: Double): Boolean; static;
    class function Divide(const Numerator: TJSBigNatural; const Denominator: TJSBigNatural;
                          const Shift: Integer): TQuotient; static;
    class function DivideRounded(const Numerator: TJSBigNatural;
                                 const Denominator: TJSBigNatural): Double; static;
    class function ComposeDouble(const Mantissa: UInt64; const Shift: Integer): Double; static;

  public
    class function ToDouble(const Digits: string; const Exponent: Integer): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

{ TJSDecimalConversion }

class function TJSDecimalConversion.TryConvertExactly(const Digits: string; const Scale: Integer;
                                                      out Value: Double): Boolean;
begin
  const IsShort = (Length(Digits) <= MAX_FAST_DIGITS);
  const IsNearUnity = (Abs(Scale) <= MAX_FAST_POWER);
  Result := IsShort and IsNearUnity;
  if not Result then
    Exit;

  const Whole = StrToInt64(Digits);
  if Scale >= 0 then
    Value := Whole * POWERS_OF_TEN[Scale]
  else
    Value := Whole / POWERS_OF_TEN[-Scale];
end;

class function TJSDecimalConversion.Divide(const Numerator: TJSBigNatural;
                                           const Denominator: TJSBigNatural;
                                           const Shift: Integer): TQuotient;
begin
  Result.Remainder := Numerator.Duplicate;
  Result.Divisor := Denominator.Duplicate;
  if Shift >= 0 then
    Result.Remainder.ShiftLeft(Shift)
  else
    Result.Divisor.ShiftLeft(-Shift);

  Result.Mantissa := 0;
  for var Bit := MANTISSA_BITS downto 0 do
  begin
    var Scaled := Result.Divisor.Duplicate;
    Scaled.ShiftLeft(Bit);

    const Fits = (Result.Remainder.CompareTo(Scaled) >= 0);
    if Fits then
    begin
      Result.Remainder.Subtract(Scaled);
      Result.Mantissa := Result.Mantissa or (UInt64(1) shl Bit);
    end;
  end;
end;

class function TJSDecimalConversion.ComposeDouble(const Mantissa: UInt64; const Shift: Integer): Double;
begin
  var Composed: TDoubleBits;

  const IsSubnormal = (Mantissa < HIDDEN_BIT);
  if IsSubnormal then
  begin
    Composed.Bits := Mantissa;
    Exit(Composed.Value);
  end;

  const BiasedExponent = EXPONENT_BIAS - Shift;
  if BiasedExponent >= MAX_BIASED_EXPONENT then
    Exit(Infinity);

  Composed.Bits := (UInt64(BiasedExponent) shl MANTISSA_BITS) or (Mantissa and MANTISSA_MASK);
  Result := Composed.Value;
end;

class function TJSDecimalConversion.DivideRounded(const Numerator: TJSBigNatural;
                                                  const Denominator: TJSBigNatural): Double;
begin
  const SizeDifference = Numerator.BitLength - Denominator.BitLength;
  var Shift := Min(MANTISSA_BITS - SizeDifference, MAX_SHIFT);

  var Quotient := Divide(Numerator, Denominator, Shift);

  const IsTooSmall = (Quotient.Mantissa < HIDDEN_BIT) and (Shift < MAX_SHIFT);
  if IsTooSmall then
  begin
    Inc(Shift);
    Quotient := Divide(Numerator, Denominator, Shift);
  end;

  var Mantissa := Quotient.Mantissa;
  Quotient.Remainder.ShiftLeft(1);
  const Comparison = Quotient.Remainder.CompareTo(Quotient.Divisor);
  const IsOdd = ((Mantissa and 1) = 1);
  const RoundsUp = (Comparison > 0) or ((Comparison = 0) and IsOdd);
  if RoundsUp then
    Inc(Mantissa);

  if Mantissa = HIDDEN_BIT_OVERFLOW then
  begin
    Mantissa := HIDDEN_BIT;
    Dec(Shift);
  end;

  Result := ComposeDouble(Mantissa, Shift);
end;

class function TJSDecimalConversion.ToDouble(const Digits: string; const Exponent: Integer): Double;
begin
  const Significant = Digits.TrimLeft(['0']);
  if Significant.IsEmpty then
    Exit(0);

  const Trimmed = Significant.TrimRight(['0']);
  const Scale = Exponent + (Length(Significant) - Length(Trimmed));
  const Magnitude = Length(Trimmed) + Scale;
  if Magnitude > MAX_DECIMAL_MAGNITUDE then
    Exit(Infinity);

  if Magnitude < MIN_DECIMAL_MAGNITUDE then
    Exit(0);

  if TryConvertExactly(Trimmed, Scale, Result) then
    Exit;

  var Numerator := TJSBigNatural.FromDigits(Trimmed);
  var Denominator := TJSBigNatural.FromWord(1);
  if Scale >= 0 then
    Numerator.MultiplyByPowerOfTen(Scale)
  else
    Denominator.MultiplyByPowerOfTen(-Scale);

  Result := DivideRounded(Numerator, Denominator);
end;

end.
