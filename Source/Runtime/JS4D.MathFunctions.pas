unit JS4D.MathFunctions;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Binary64;

type
  TJSMathFunctions = class
  private
    const
      TWO_POW52 = 4503599627370496.0;
      TWO_POW53 = 9007199254740992.0;
      TWO_POW28 = 268435456.0;
      LARGEST_SINGLE_BOUNDARY = 3.4028235677973366e+38;
      LARGEST_EXPONENT_FOR_EXP = 709.782712893384;
      LARGEST_EXPONENT_FOR_COSH = 710.4758600739439;
      LARGEST_EXPONENT_FOR_TANH = 20.0;
      SMALLEST_NORMAL_SINGLE = 1.1754943508222875e-38;
      SMALLEST_SINGLE_STEP = 1.401298464324817e-45;
      DROPPED_MANTISSA_BITS = MANTISSA_BITS - SINGLE_MANTISSA_BITS;
      LOW_32_BITS_MASK = $FFFFFFFF;

    class function IsWholeOrSpecial(const Value: Double): Boolean; static;
    class function IsOddInteger(const Value: Double): Boolean; static;
    class function IsNaNOrZero(const Value: Double): Boolean; static;
    class function IsNaNInfiniteOrZero(const Value: Double): Boolean; static;
    class function WithSignOf(const Magnitude, SignSource: Double): Double; static;
    class function LogInBase(const Value: Double; const Base: Integer): Double; static;
    class function ScaledRoot(const Values: TArray<Double>; const Largest: Double): Double; static;
    class function ZeroPower(const Base, Exponent: Double): Double; static;
    class function InfinitePower(const Base, Exponent: Double): Double; static;
    class function InfiniteBasePower(const Base, Exponent: Double): Double; static;
    class function SnapToWholePower(const Logarithm, Base, Argument: Double): Double; static;
    class function LogOfLargeValue(const Value: Double): Double; static;
    class function RoundToNormalSingle(const Value: Double): Double; static;
    class function RoundToSubnormalSingle(const Value: Double): Double; static;

  public
    class function NegativeZero: Double; static;
    class function KeepZeroSign(const Magnitude, SignSource: Double): Double; static;
    class function IsNegativeZero(const Value: Double): Boolean; static;
    class function JsFloor(const Value: Double): Double; static;
    class function JsCeil(const Value: Double): Double; static;
    class function JsRound(const Value: Double): Double; static;
    class function JsTrunc(const Value: Double): Double; static;
    class function JsSign(const Value: Double): Double; static;
    class function AbsoluteValue(const Value: Double): Double; static;
    class function JsSin(const Value: Double): Double; static;
    class function Cosine(const Value: Double): Double; static;
    class function ArcSine(const Value: Double): Double; static;
    class function ArcCosine(const Value: Double): Double; static;
    class function ArcTangent(const Value: Double): Double; static;
    class function ArcTangent2(const Y, X: Double): Double; static;
    class function Exponential(const Value: Double): Double; static;
    class function NaturalLogarithm(const Value: Double): Double; static;
    class function SquareRoot(const Value: Double): Double; static;
    class function JsTan(const Value: Double): Double; static;
    class function Larger(const Left, Right: Double): Double; static;
    class function Smaller(const Left, Right: Double): Double; static;
    class function Power(const Base, Exponent: Double): Double; static;
    class function Cbrt(const Value: Double): Double; static;
    class function Log2(const Value: Double): Double; static;
    class function Log10(const Value: Double): Double; static;
    class function Log1p(const Value: Double): Double; static;
    class function Expm1(const Value: Double): Double; static;
    class function Sinh(const Value: Double): Double; static;
    class function Cosh(const Value: Double): Double; static;
    class function Tanh(const Value: Double): Double; static;
    class function Asinh(const Value: Double): Double; static;
    class function Acosh(const Value: Double): Double; static;
    class function Atanh(const Value: Double): Double; static;
    class function Hypot(const Values: TArray<Double>): Double; static;
    class function Fround(const Value: Double): Double; static;
    class function Imul(const Left, Right: Integer): Integer; static;
    class function Clz32(const Value: Cardinal): Integer; static;
    class function IsFiniteNumber(const Value: Double): Boolean; static;
    class function IsInteger(const Value: Double): Boolean; static;
    class function IsSafeInteger(const Value: Double): Boolean; static;
  end;

implementation

uses
  JS4D.Types,
  System.SysUtils,
  System.Math;

class function TJSMathFunctions.NegativeZero: Double;
begin
  var Bits: TJSDoubleBits;
  Bits.Bits := NEGATIVE_ZERO_BITS;

  Result := Bits.Value;
end;

class function TJSMathFunctions.IsNegativeZero(const Value: Double): Boolean;
begin
  Result := ((Value = 0) and Value.Sign);
end;

class function TJSMathFunctions.KeepZeroSign(const Magnitude, SignSource: Double): Double;
begin
  const IsNegativeZeroResult = ((Magnitude = 0) and SignSource.Sign);
  if IsNegativeZeroResult then
    Exit(NegativeZero);

  Result := Magnitude;
end;

class function TJSMathFunctions.IsWholeOrSpecial(const Value: Double): Boolean;
begin
  Result := (IsNaN(Value) or IsInfinite(Value) or (Value = 0) or (Abs(Value) >= TWO_POW52));
end;

class function TJSMathFunctions.IsOddInteger(const Value: Double): Boolean;
begin
  const IsSafeInteger = ((Abs(Value) < TWO_POW53) and (Frac(Value) = 0));
  if not IsSafeInteger then
    Exit(False);

  const Magnitude = Abs(Value);
  const WholeMagnitude = System.Trunc(Magnitude);

  Result := Odd(WholeMagnitude);
end;

class function TJSMathFunctions.IsNaNOrZero(const Value: Double): Boolean;
begin
  Result := (IsNaN(Value) or (Value = 0));
end;

class function TJSMathFunctions.IsNaNInfiniteOrZero(const Value: Double): Boolean;
begin
  Result := (IsNaN(Value) or IsInfinite(Value) or (Value = 0));
end;

class function TJSMathFunctions.WithSignOf(const Magnitude, SignSource: Double): Double;
begin
  const IsNegative = (SignSource < 0);
  if IsNegative then
    Result := -Magnitude
  else
    Result := Magnitude;
end;

class function TJSMathFunctions.LogInBase(const Value: Double; const Base: Integer): Double;
begin
  const IsBelowDomain = (IsNaN(Value) or (Value < 0));
  if IsBelowDomain then
    Exit(NaN);

  const IsZero = (Value = 0);
  if IsZero then
    Exit(NegInfinity);

  if IsInfinite(Value) then
    Exit(Value);

  const NaturalLog = Ln(Value);
  const BaseLog = Ln(Base);
  const Logarithm = NaturalLog / BaseLog;

  Result := SnapToWholePower(Logarithm, Base, Value);
end;

class function TJSMathFunctions.JsFloor(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  Result := Int(Value);

  const IsAboveValue = (Result > Value);
  if IsAboveValue then
    Result := Result - 1;
end;

class function TJSMathFunctions.JsCeil(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  var Whole: Double := Int(Value);

  const IsBelowValue = (Whole < Value);
  if IsBelowValue then
    Whole := Whole + 1;

  Result := KeepZeroSign(Whole, Value);
end;

class function TJSMathFunctions.JsRound(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  var Whole := JsFloor(Value);

  const IsHalfOrMore = ((Value - Whole) >= 0.5);
  if IsHalfOrMore then
    Whole := Whole + 1;

  Result := KeepZeroSign(Whole, Value);
end;

class function TJSMathFunctions.JsTrunc(const Value: Double): Double;
begin
  const IsNegative = (Value < 0);
  if IsNegative then
    Result := JsCeil(Value)
  else
    Result := JsFloor(Value);
end;

class function TJSMathFunctions.JsSign(const Value: Double): Double;
begin
  if IsNaNOrZero(Value) then
    Exit(Value);

  const IsPositive = (Value > 0);
  if IsPositive then
    Result := 1
  else
    Result := -1;
end;

class function TJSMathFunctions.JsSin(const Value: Double): Double;
begin
  if IsNaNOrZero(Value) then
    Exit(Value);

  if IsInfinite(Value) then
    Exit(NaN);

  Result := System.Sin(Value);
end;

class function TJSMathFunctions.AbsoluteValue(const Value: Double): Double;
begin
  Result := System.Abs(Value);
end;

class function TJSMathFunctions.Cosine(const Value: Double): Double;
begin
  Result := System.Cos(Value);
end;

class function TJSMathFunctions.ArcSine(const Value: Double): Double;
begin
  const IsOutsideDomain = ((Value < -1) or (Value > 1));
  if IsOutsideDomain then
    Exit(NaN);

  Result := System.Math.ArcSin(Value);
end;

class function TJSMathFunctions.ArcCosine(const Value: Double): Double;
begin
  const IsOutsideDomain = ((Value < -1) or (Value > 1));
  if IsOutsideDomain then
    Exit(NaN);

  Result := System.Math.ArcCos(Value);
end;

class function TJSMathFunctions.ArcTangent(const Value: Double): Double;
begin
  Result := System.ArcTan(Value);
end;

class function TJSMathFunctions.ArcTangent2(const Y, X: Double): Double;
begin
  Result := System.Math.ArcTan2(Y, X);
end;

class function TJSMathFunctions.Exponential(const Value: Double): Double;
begin
  Result := System.Exp(Value);
end;

class function TJSMathFunctions.NaturalLogarithm(const Value: Double): Double;
begin
  const IsZero = (Value = 0);
  if IsZero then
    Exit(NegInfinity);

  const IsNegative = (Value < 0);
  if IsNegative then
    Exit(NaN);

  Result := System.Ln(Value);
end;

class function TJSMathFunctions.SquareRoot(const Value: Double): Double;
begin
  const IsNegative = (Value < 0);
  if IsNegative then
    Exit(NaN);

  Result := System.Sqrt(Value);
end;

class function TJSMathFunctions.JsTan(const Value: Double): Double;
begin
  if IsNaNOrZero(Value) then
    Exit(Value);

  if IsInfinite(Value) then
    Exit(NaN);

  Result := System.Math.Tan(Value);
end;

class function TJSMathFunctions.Larger(const Left, Right: Double): Double;
begin
  const AreZeros = ((Left = 0) and (Right = 0));
  if AreZeros then
  begin
    if Left.Sign then
      Exit(Right);

    Exit(Left);
  end;

  const IsRightLarger = (Right > Left);
  if IsRightLarger then
    Result := Right
  else
    Result := Left;
end;

class function TJSMathFunctions.Smaller(const Left, Right: Double): Double;
begin
  const AreZeros = ((Left = 0) and (Right = 0));
  if AreZeros then
  begin
    if Left.Sign then
      Exit(Left);

    Exit(Right);
  end;

  const IsRightSmaller = (Right < Left);
  if IsRightSmaller then
    Result := Right
  else
    Result := Left;
end;

class function TJSMathFunctions.ZeroPower(const Base, Exponent: Double): Double;
begin
  const IsNegativeOddPower = (Base.Sign and IsOddInteger(Exponent));

  const IsPositiveExponent = (Exponent > 0);
  if IsPositiveExponent then
  begin
    if IsNegativeOddPower then
      Exit(NegativeZero);

    Exit(0);
  end;

  if IsNegativeOddPower then
    Exit(NegInfinity);

  Result := Infinity;
end;

class function TJSMathFunctions.InfinitePower(const Base, Exponent: Double): Double;
begin
  const MagnitudeOfBase = Abs(Base);
  const IsUnitBase = (MagnitudeOfBase = 1);
  if IsUnitBase then
    Exit(NaN);

  const IsBaseAboveOne = (MagnitudeOfBase > 1);
  const IsExponentPositive = (Exponent > 0);
  const GrowsWithExponent = (IsBaseAboveOne = IsExponentPositive);
  if GrowsWithExponent then
    Result := Infinity
  else
    Result := 0;
end;

class function TJSMathFunctions.InfiniteBasePower(const Base, Exponent: Double): Double;
begin
  const IsNegativeOddPower = (Base.Sign and IsOddInteger(Exponent));

  const IsPositiveExponent = (Exponent > 0);
  if IsPositiveExponent then
  begin
    if IsNegativeOddPower then
      Exit(NegInfinity);

    Exit(Infinity);
  end;

  if IsNegativeOddPower then
    Exit(NegativeZero);

  Result := 0;
end;

class function TJSMathFunctions.Power(const Base, Exponent: Double): Double;
begin
  if IsNaN(Exponent) then
    Exit(NaN);

  const IsZeroExponent = (Exponent = 0);
  if IsZeroExponent then
    Exit(1);

  if IsNaN(Base) then
    Exit(NaN);

  if IsInfinite(Exponent) then
  begin
    Result := InfinitePower(Base, Exponent);
    Exit;
  end;

  const IsZeroBase = (Base = 0);
  if IsZeroBase then
  begin
    Result := ZeroPower(Base, Exponent);
    Exit;
  end;

  if IsInfinite(Base) then
  begin
    Result := InfiniteBasePower(Base, Exponent);
    Exit;
  end;

  Result := System.Math.Power(Base, Exponent);
end;

class function TJSMathFunctions.SnapToWholePower(const Logarithm, Base, Argument: Double): Double;
begin
  const Nearest = System.Round(Logarithm);
  const IsWholePower = (System.Math.Power(Base, Nearest) = Argument);
  if IsWholePower then
    Exit(Nearest);

  Result := Logarithm;
end;

class function TJSMathFunctions.LogOfLargeValue(const Value: Double): Double;
begin
  Result := Ln(Value) + Ln(2);
end;

class function TJSMathFunctions.Cbrt(const Value: Double): Double;
begin
  if IsNaNInfiniteOrZero(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  const Estimate = System.Math.Power(Magnitude, 1 / 3);
  const Root = Estimate - ((Estimate * Estimate * Estimate) - Magnitude) / (3 * Estimate * Estimate);

  Result := WithSignOf(Root, Value);
end;

class function TJSMathFunctions.Log2(const Value: Double): Double;
begin
  Result := LogInBase(Value, 2);
end;

class function TJSMathFunctions.Log10(const Value: Double): Double;
begin
  Result := LogInBase(Value, 10);
end;

class function TJSMathFunctions.Log1p(const Value: Double): Double;
begin
  const IsUnchanged = (IsNaN(Value) or (Value = 0) or (Value = Infinity));
  if IsUnchanged then
    Exit(Value);

  const IsBelowDomain = (Value < -1);
  if IsBelowDomain then
    Exit(NaN);

  const IsMinusOne = (Value = -1);
  if IsMinusOne then
    Exit(NegInfinity);

  const ShiftedValue = 1 + Value;
  const IsShiftLost = (ShiftedValue = 1);
  if IsShiftLost then
    Exit(Value);

  Result := Ln(ShiftedValue) * Value / (ShiftedValue - 1);
end;

class function TJSMathFunctions.Expm1(const Value: Double): Double;
begin
  const IsUnchanged = (IsNaN(Value) or (Value = 0) or (Value = Infinity));
  if IsUnchanged then
    Exit(Value);

  const IsNegativeInfinity = (Value = NegInfinity);
  if IsNegativeInfinity then
    Exit(-1);

  const Overflows = (Value > LARGEST_EXPONENT_FOR_EXP);
  if Overflows then
    Exit(Infinity);

  const Exponential = Exp(Value);
  const IsExponentialLost = (Exponential = 1);
  if IsExponentialLost then
    Exit(Value);

  const Decrement = Exponential - 1;
  const IsMinusOne = (Decrement = -1);
  if IsMinusOne then
    Exit(-1);

  Result := Decrement * Value / Ln(Exponential);
end;

class function TJSMathFunctions.Sinh(const Value: Double): Double;
begin
  if IsNaNInfiniteOrZero(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  const Overflows = (Magnitude > LARGEST_EXPONENT_FOR_COSH);
  if Overflows then
  begin
    Result := WithSignOf(Infinity, Value);
    Exit;
  end;

  const Growth = Expm1(Magnitude);
  const Half = (Growth + Growth / (Growth + 1)) / 2;

  Result := WithSignOf(Half, Value);
end;

class function TJSMathFunctions.Cosh(const Value: Double): Double;
begin
  if IsNaN(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  const Overflows = (Magnitude > LARGEST_EXPONENT_FOR_COSH);
  if Overflows then
    Exit(Infinity);

  const IsLarge = (Magnitude > LARGEST_EXPONENT_FOR_TANH);
  if IsLarge then
  begin
    const HalfRoot = Exp(Magnitude / 2);

    Exit(HalfRoot / 2 * HalfRoot);
  end;

  Result := (Exp(Magnitude) + Exp(-Magnitude)) / 2;
end;

class function TJSMathFunctions.Tanh(const Value: Double): Double;
begin
  if IsNaNOrZero(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  var Ratio: Double := 1;
  const IsBelowSaturation = (Magnitude <= LARGEST_EXPONENT_FOR_TANH);
  if IsBelowSaturation then
  begin
    const Growth = Expm1(2 * Magnitude);
    Ratio := Growth / (Growth + 2);
  end;

  Result := WithSignOf(Ratio, Value);
end;

class function TJSMathFunctions.Asinh(const Value: Double): Double;
begin
  if IsNaNInfiniteOrZero(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  const Square = Magnitude * Magnitude;

  var Area: Double;
  const IsLarge = (Magnitude > TWO_POW28);
  if IsLarge then
  begin
    Area := LogOfLargeValue(Magnitude);
  end
  else
  begin
    const RootOfSquare = Sqrt(1 + Square);

    Area := Log1p(Magnitude + Square / (1 + RootOfSquare));
  end;

  Result := WithSignOf(Area, Value);
end;

class function TJSMathFunctions.Acosh(const Value: Double): Double;
begin
  const IsOutsideDomain = (IsNaN(Value) or (Value < 1));
  if IsOutsideDomain then
    Exit(NaN);

  if IsInfinite(Value) then
    Exit(Value);

  const IsLarge = (Value > TWO_POW28);
  if IsLarge then
  begin
    Result := LogOfLargeValue(Value);
    Exit;
  end;

  const RootOfSquare = Sqrt(Value * Value - 1);

  Result := Ln(Value + RootOfSquare);
end;

class function TJSMathFunctions.Atanh(const Value: Double): Double;
begin
  const IsOutsideDomain = (IsNaN(Value) or (Abs(Value) > 1));
  if IsOutsideDomain then
    Exit(NaN);

  const IsOne = (Value = 1);
  if IsOne then
    Exit(Infinity);

  const IsMinusOne = (Value = -1);
  if IsMinusOne then
    Exit(NegInfinity);

  const IsZero = (Value = 0);
  if IsZero then
    Exit(Value);

  const Ratio = 2 * Value / (1 - Value);

  Result := Log1p(Ratio) / 2;
end;

class function TJSMathFunctions.Hypot(const Values: TArray<Double>): Double;
begin
  var HasNaN := False;
  var Largest: Double := 0;

  for var Value in Values do
  begin
    if IsInfinite(Value) then
      Exit(Infinity);

    if IsNaN(Value) then
    begin
      HasNaN := True;
    end
    else
    begin
      const Magnitude = Abs(Value);

      Largest := Larger(Largest, Magnitude);
    end;
  end;

  if HasNaN then
    Exit(NaN);

  const IsAllZero = (Largest = 0);
  if IsAllZero then
    Exit(0);

  Result := ScaledRoot(Values, Largest);
end;

class function TJSMathFunctions.ScaledRoot(const Values: TArray<Double>; const Largest: Double): Double;
begin
  var SumOfSquares: Double := 0;
  for var Value in Values do
  begin
    const Scaled = Value / Largest;
    SumOfSquares := SumOfSquares + Scaled * Scaled;
  end;

  Result := Sqrt(SumOfSquares) * Largest;
end;

class function TJSMathFunctions.Fround(const Value: Double): Double;
begin
  if IsNaNInfiniteOrZero(Value) then
    Exit(Value);

  const Magnitude = Abs(Value);
  const OverflowsSingle = (Magnitude >= LARGEST_SINGLE_BOUNDARY);
  if OverflowsSingle then
  begin
    Result := WithSignOf(Infinity, Value);
    Exit;
  end;

  const IsSubnormal = (Magnitude < SMALLEST_NORMAL_SINGLE);
  if IsSubnormal then
  begin
    Result := RoundToSubnormalSingle(Value);
    Exit;
  end;

  Result := RoundToNormalSingle(Value);
end;

class function TJSMathFunctions.RoundToNormalSingle(const Value: Double): Double;
begin
  const DroppedBitsCount = UInt64(DROPPED_MANTISSA_BITS);
  const KeptUnit = UInt64(1) shl DroppedBitsCount;
  const HalfUnit = KeptUnit shr 1;

  var Source: TJSDoubleBits;
  Source.Value := Value;

  const Remainder = Source.Bits and (KeptUnit - 1);
  var Rounded: UInt64 := Source.Bits - Remainder;

  const IsKeptOdd = (((Rounded shr DroppedBitsCount) and 1) = 1);
  const IsAboveHalf = ((Remainder > HalfUnit) or ((Remainder = HalfUnit) and IsKeptOdd));
  if IsAboveHalf then
    Rounded := Rounded + KeptUnit;

  var Target: TJSDoubleBits;
  Target.Bits := Rounded;

  Result := Target.Value;
end;

class function TJSMathFunctions.RoundToSubnormalSingle(const Value: Double): Double;
begin
  const Steps = System.Round(Value / SMALLEST_SINGLE_STEP);

  Result := KeepZeroSign(Steps * SMALLEST_SINGLE_STEP, Value);
end;

class function TJSMathFunctions.Imul(const Left, Right: Integer): Integer;
begin
  const Product: Int64 = Int64(Left) * Int64(Right);
  const LowWord = Cardinal(Product and LOW_32_BITS_MASK);

  Result := Integer(LowWord);
end;

class function TJSMathFunctions.Clz32(const Value: Cardinal): Integer;
begin
  Result := 32;

  var Remaining := Value;
  while Remaining <> 0 do
  begin
    Dec(Result);
    Remaining := Remaining shr 1;
  end;
end;

class function TJSMathFunctions.IsFiniteNumber(const Value: Double): Boolean;
begin
  Result := not (IsNaN(Value) or IsInfinite(Value));
end;

class function TJSMathFunctions.IsInteger(const Value: Double): Boolean;
begin
  Result := (IsFiniteNumber(Value) and (Frac(Value) = 0));
end;

class function TJSMathFunctions.IsSafeInteger(const Value: Double): Boolean;
begin
  Result := (IsInteger(Value) and (Abs(Value) <= MAX_SAFE_INTEGER));
end;

end.
