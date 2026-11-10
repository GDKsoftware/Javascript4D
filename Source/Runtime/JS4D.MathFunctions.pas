unit JS4D.MathFunctions;

{$SCOPEDENUMS ON}

interface

type
  TJSMathFunctions = class
  private
    const
      TwoPow52 = 4503599627370496.0;
      TwoPow53 = 9007199254740992.0;

    class function IsWholeOrSpecial(const Value: Double): Boolean; static;
    class function IsOddInteger(const Value: Double): Boolean; static;
    class function ZeroPower(const Base, Exponent: Double): Double; static;
    class function InfinitePower(const Base, Exponent: Double): Double; static;

  public
    class function NegativeZero: Double; static;
    class function KeepZeroSign(const Magnitude, SignSource: Double): Double; static;
    class function Floor(const Value: Double): Double; static;
    class function Ceil(const Value: Double): Double; static;
    class function Round(const Value: Double): Double; static;
    class function Trunc(const Value: Double): Double; static;
    class function Sign(const Value: Double): Double; static;
    class function Sin(const Value: Double): Double; static;
    class function Tan(const Value: Double): Double; static;
    class function Larger(const Left, Right: Double): Double; static;
    class function Smaller(const Left, Right: Double): Double; static;
    class function Power(const Base, Exponent: Double): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

class function TJSMathFunctions.NegativeZero: Double;
begin
  var Zero: Double := 0;

  Result := -Zero;
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
  Result := (IsNaN(Value) or IsInfinite(Value) or (Value = 0) or (Abs(Value) >= TwoPow52));
end;

class function TJSMathFunctions.IsOddInteger(const Value: Double): Boolean;
begin
  const IsSafeInteger = ((Abs(Value) < TwoPow53) and (Frac(Value) = 0));
  if not IsSafeInteger then
    Exit(False);

  const Magnitude = System.Trunc(Abs(Value));

  Result := Odd(Magnitude);
end;

class function TJSMathFunctions.Floor(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  Result := Int(Value);

  const IsAboveValue = (Result > Value);
  if IsAboveValue then
    Result := Result - 1;
end;

class function TJSMathFunctions.Ceil(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  var Whole: Double := Int(Value);

  const IsBelowValue = (Whole < Value);
  if IsBelowValue then
    Whole := Whole + 1;

  Result := KeepZeroSign(Whole, Value);
end;

class function TJSMathFunctions.Round(const Value: Double): Double;
begin
  if IsWholeOrSpecial(Value) then
    Exit(Value);

  var Whole := Floor(Value);

  const IsHalfOrMore = ((Value - Whole) >= 0.5);
  if IsHalfOrMore then
    Whole := Whole + 1;

  Result := KeepZeroSign(Whole, Value);
end;

class function TJSMathFunctions.Trunc(const Value: Double): Double;
begin
  const IsNegative = (Value < 0);
  if IsNegative then
    Result := Ceil(Value)
  else
    Result := Floor(Value);
end;

class function TJSMathFunctions.Sign(const Value: Double): Double;
begin
  const IsSignless = (IsNaN(Value) or (Value = 0));
  if IsSignless then
    Exit(Value);

  const IsPositive = (Value > 0);
  if IsPositive then
    Result := 1
  else
    Result := -1;
end;

class function TJSMathFunctions.Sin(const Value: Double): Double;
begin
  const IsUnchanged = ((Value = 0) or IsNaN(Value));
  if IsUnchanged then
    Exit(Value);

  if IsInfinite(Value) then
    Exit(NaN);

  Result := System.Sin(Value);
end;

class function TJSMathFunctions.Tan(const Value: Double): Double;
begin
  const IsUnchanged = ((Value = 0) or IsNaN(Value));
  if IsUnchanged then
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
  if MagnitudeOfBase = 1 then
    Exit(NaN);

  const IsBaseAboveOne = (MagnitudeOfBase > 1);
  const IsExponentPositive = (Exponent > 0);
  const GrowsWithExponent = (IsBaseAboveOne = IsExponentPositive);
  if GrowsWithExponent then
    Result := Infinity
  else
    Result := 0;
end;

class function TJSMathFunctions.Power(const Base, Exponent: Double): Double;
begin
  if IsNaN(Exponent) then
    Exit(NaN);

  if Exponent = 0 then
    Exit(1);

  if IsNaN(Base) then
    Exit(NaN);

  if IsInfinite(Exponent) then
    Exit(InfinitePower(Base, Exponent));

  if Base = 0 then
    Exit(ZeroPower(Base, Exponent));

  Result := System.Math.Power(Base, Exponent);
end;

end.
