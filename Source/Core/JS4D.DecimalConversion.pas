unit JS4D.DecimalConversion;

interface

uses
  JS4D.BigNatural,
  JS4D.Binary64;

type
  TJSDecimalConversion = class
  private
    type
      TQuotient = record
        Mantissa: UInt64;
        Remainder: TJSBigNatural;
        Divisor: TJSBigNatural;
      end;

      TDecimalLiteral = record
        Digits: string;
        Scale: Integer;
        function Magnitude: Integer;
      end;

      TRatio = record
        Numerator: TJSBigNatural;
        Denominator: TJSBigNatural;
      end;

    const
      MAX_FAST_DIGITS = 15;
      MAX_FAST_POWER = 22;
      MAX_DECIMAL_MAGNITUDE = 309;
      MIN_DECIMAL_MAGNITUDE = -323;
      MAX_SHIFT = -DENORMAL_EXPONENT;
      HIDDEN_BIT_OVERFLOW = HIDDEN_BIT shl 1;
      POWERS_OF_TEN: array[0..MAX_FAST_POWER] of Double = (
        1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
        1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22);

    class function NormalizeLiteral(const Digits: string; const Exponent: Integer): TDecimalLiteral; static;
    class function TryGetSaturatedValue(const Literal: TDecimalLiteral; out Value: Double): Boolean; static;
    class function TryConvertExactly(const Literal: TDecimalLiteral; out Value: Double): Boolean; static;
    class function BuildRatio(const Literal: TDecimalLiteral): TRatio; static;
    class function Divide(const Ratio: TRatio; const Shift: Integer): TQuotient; static;
    class function DivideRounded(const Ratio: TRatio): Double; static;
    class function ComposeDouble(const Mantissa: UInt64; const Shift: Integer): Double; static;

  public
    class function ToDouble(const Digits: string; const Exponent: Integer): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

{ TJSDecimalConversion.TDecimalLiteral }

function TJSDecimalConversion.TDecimalLiteral.Magnitude: Integer;
begin
  Result := Length(Digits) + Scale;
end;

{ TJSDecimalConversion }

class function TJSDecimalConversion.ToDouble(const Digits: string; const Exponent: Integer): Double;
begin
  const Literal = NormalizeLiteral(Digits, Exponent);
  const IsZero = Literal.Digits.IsEmpty;
  if IsZero then
    Exit(0);

  if TryGetSaturatedValue(Literal, Result) then
    Exit;

  if TryConvertExactly(Literal, Result) then
    Exit;

  const Ratio = BuildRatio(Literal);

  Result := DivideRounded(Ratio);
end;

class function TJSDecimalConversion.NormalizeLiteral(const Digits: string;
                                                     const Exponent: Integer): TDecimalLiteral;
begin
  const Significant = Digits.TrimLeft(['0']);

  Result.Digits := Significant.TrimRight(['0']);
  Result.Scale := Exponent + (Length(Significant) - Length(Result.Digits));
end;

class function TJSDecimalConversion.TryGetSaturatedValue(const Literal: TDecimalLiteral;
                                                         out Value: Double): Boolean;
begin
  const Magnitude = Literal.Magnitude;
  const IsTooLarge = (Magnitude > MAX_DECIMAL_MAGNITUDE);
  const IsTooSmall = (Magnitude < MIN_DECIMAL_MAGNITUDE);

  Result := IsTooLarge or IsTooSmall;
  if IsTooLarge then
    Value := Infinity
  else
    Value := 0;
end;

class function TJSDecimalConversion.TryConvertExactly(const Literal: TDecimalLiteral;
                                                      out Value: Double): Boolean;
begin
  const IsShort = (Length(Literal.Digits) <= MAX_FAST_DIGITS);
  const IsNearUnity = (Abs(Literal.Scale) <= MAX_FAST_POWER);
  Result := IsShort and IsNearUnity;
  if not Result then
    Exit;

  const Whole = StrToInt64(Literal.Digits);
  const IsMultiplied = (Literal.Scale >= 0);
  if IsMultiplied then
    Value := Whole * POWERS_OF_TEN[Literal.Scale]
  else
    Value := Whole / POWERS_OF_TEN[-Literal.Scale];
end;

class function TJSDecimalConversion.BuildRatio(const Literal: TDecimalLiteral): TRatio;
begin
  Result.Numerator := TJSBigNatural.FromDigits(Literal.Digits);
  Result.Denominator := TJSBigNatural.FromWord(1);

  const IsMultiplied = (Literal.Scale >= 0);
  if IsMultiplied then
    Result.Numerator.MultiplyByPowerOfTen(Literal.Scale)
  else
    Result.Denominator.MultiplyByPowerOfTen(-Literal.Scale);
end;

class function TJSDecimalConversion.Divide(const Ratio: TRatio; const Shift: Integer): TQuotient;
begin
  Result.Remainder := Ratio.Numerator.Duplicate;
  Result.Divisor := Ratio.Denominator.Duplicate;

  const IsShiftingNumerator = (Shift >= 0);
  if IsShiftingNumerator then
    Result.Remainder.ShiftLeft(Shift)
  else
    Result.Divisor.ShiftLeft(-Shift);

  var Scaled := Result.Divisor.Duplicate;
  Scaled.ShiftLeft(MANTISSA_BITS);

  Result.Mantissa := 0;
  for var Bit := MANTISSA_BITS downto 0 do
  begin
    const Fits = Result.Remainder.TrySubtract(Scaled);
    if Fits then
      Result.Mantissa := Result.Mantissa or (UInt64(1) shl Bit);

    Scaled.ShiftRightOne;
  end;
end;

class function TJSDecimalConversion.ComposeDouble(const Mantissa: UInt64; const Shift: Integer): Double;
begin
  var Composed: TJSDoubleBits;

  const IsSubnormal = (Mantissa < HIDDEN_BIT);
  if IsSubnormal then
  begin
    Composed.Bits := Mantissa;
    Exit(Composed.Value);
  end;

  const BiasedExponent = EXPONENT_BIAS - Shift;
  const IsOverflowing = (BiasedExponent >= MAX_BIASED_EXPONENT);
  if IsOverflowing then
    Exit(Infinity);

  Composed.Bits := (UInt64(BiasedExponent) shl MANTISSA_BITS) or (Mantissa and MANTISSA_MASK);
  Result := Composed.Value;
end;

class function TJSDecimalConversion.DivideRounded(const Ratio: TRatio): Double;
begin
  const SizeDifference = Ratio.Numerator.BitLength - Ratio.Denominator.BitLength;
  var Shift := Min(MANTISSA_BITS - SizeDifference, MAX_SHIFT);

  var Quotient := Divide(Ratio, Shift);

  const IsTooSmall = (Quotient.Mantissa < HIDDEN_BIT) and (Shift < MAX_SHIFT);
  if IsTooSmall then
  begin
    Inc(Shift);
    Quotient := Divide(Ratio, Shift);
  end;

  var Mantissa := Quotient.Mantissa;
  Quotient.Remainder.ShiftLeft(1);
  const Comparison = Quotient.Remainder.CompareTo(Quotient.Divisor);
  const IsOdd = ((Mantissa and 1) = 1);
  const RoundsUp = (Comparison > 0) or ((Comparison = 0) and IsOdd);
  if RoundsUp then
    Inc(Mantissa);

  const HasOverflowed = (Mantissa = HIDDEN_BIT_OVERFLOW);
  if HasOverflowed then
  begin
    Mantissa := HIDDEN_BIT;
    Dec(Shift);
  end;

  Result := ComposeDouble(Mantissa, Shift);
end;

end.
