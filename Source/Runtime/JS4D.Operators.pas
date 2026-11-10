unit JS4D.Operators;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.MathFunctions,
  JS4D.AST;

type
  TJSOperators = class
  private
    const
      TWO_POW_32 = 4294967296.0;
      SHIFT_COUNT_MASK = 31;

    class function IsDate(const Value: TJSValue): Boolean; static;
    class function Divide(const Dividend: Double; const Divisor: Double): Double; static;
    class function Remainder(const Dividend: Double; const Divisor: Double): Double; static;
    class function ToAddOperand(const Value: TJSValue; const Limits: TJSLimits): TJSValue; static;
    class function Add(const Left: TJSValue; const Right: TJSValue; const Limits: TJSLimits): TJSValue; static;
    class function Compare(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                           const Right: TJSValue): Boolean; static;
    class function ShiftRightKeepingSign(const Value: Integer; const Count: Byte): Integer; static;
    class function Shift(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                         const Right: TJSValue): TJSValue; static;
    class function Bitwise(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                           const Right: TJSValue): TJSValue; static;

  public
    class function ToPrimitive(const Value: TJSValue): TJSValue; static;
    class function ToNumber(const Value: TJSValue): Double; static;
    class function ToUint32(const Value: TJSValue): Cardinal; static;
    class function ToInt32(const Value: TJSValue): Integer; static;
    class function BinaryOperatorFor(const Operator_: TJSAssignmentOperator): TJSBinaryOperator; static;
    class function Apply(const Operator_: TJSBinaryOperator; const Left: TJSValue; const Right: TJSValue;
                         const Limits: TJSLimits): TJSValue; static;
  end;

implementation

class function TJSOperators.IsDate(const Value: TJSValue): Boolean;
begin
  var DateObject: IJSDate;

  Result := Value.IsObject and Supports(Value.ToObject, IJSDate, DateObject);
end;

class function TJSOperators.ToPrimitive(const Value: TJSValue): TJSValue;
begin
  Result := Value.ToPrimitive(IsDate(Value));
end;

class function TJSOperators.ToNumber(const Value: TJSValue): Double;
begin
  Result := Value.ToPrimitive(False).ToNumber;
end;

class function TJSOperators.ToUint32(const Value: TJSValue): Cardinal;
begin
  const Number = ToNumber(Value);

  const IsFiniteNumber = not (IsNaN(Number) or IsInfinite(Number));
  if not IsFiniteNumber then
    Exit(0);

  const Whole = Int(Number);
  const Wrapped = Whole - Floor(Whole / TWO_POW_32) * TWO_POW_32;
  Result := Cardinal(Trunc(Wrapped));
end;

class function TJSOperators.ToInt32(const Value: TJSValue): Integer;
begin
  Result := Integer(ToUint32(Value));
end;

class function TJSOperators.BinaryOperatorFor(const Operator_: TJSAssignmentOperator): TJSBinaryOperator;
begin
  case Operator_ of
    TJSAssignmentOperator.AddAssign                : Result := TJSBinaryOperator.Add;
    TJSAssignmentOperator.SubtractAssign           : Result := TJSBinaryOperator.Subtract;
    TJSAssignmentOperator.MultiplyAssign           : Result := TJSBinaryOperator.Multiply;
    TJSAssignmentOperator.DivideAssign             : Result := TJSBinaryOperator.Divide;
    TJSAssignmentOperator.ModuloAssign             : Result := TJSBinaryOperator.Modulo;
    TJSAssignmentOperator.BitwiseAndAssign         : Result := TJSBinaryOperator.BitwiseAnd;
    TJSAssignmentOperator.BitwiseOrAssign          : Result := TJSBinaryOperator.BitwiseOr;
    TJSAssignmentOperator.BitwiseXorAssign         : Result := TJSBinaryOperator.BitwiseXor;
    TJSAssignmentOperator.LeftShiftAssign          : Result := TJSBinaryOperator.LeftShift;
    TJSAssignmentOperator.RightShiftAssign         : Result := TJSBinaryOperator.RightShift;
    TJSAssignmentOperator.UnsignedRightShiftAssign : Result := TJSBinaryOperator.UnsignedRightShift;
  else
    raise ENotSupportedException.CreateFmt('Assignment operator has no binary form: %d', [Ord(Operator_)]);
  end;
end;

class function TJSOperators.Apply(const Operator_: TJSBinaryOperator; const Left: TJSValue; const Right: TJSValue;
                                  const Limits: TJSLimits): TJSValue;
begin
  case Operator_ of
    TJSBinaryOperator.Add:
      Result := Add(Left, Right, Limits);
    TJSBinaryOperator.Subtract:
      begin
        const LeftNumber = ToNumber(Left);
        const RightNumber = ToNumber(Right);
        Result := TJSValue.CreateNumber(LeftNumber - RightNumber);
      end;
    TJSBinaryOperator.Multiply:
      begin
        const LeftNumber = ToNumber(Left);
        const RightNumber = ToNumber(Right);
        Result := TJSValue.CreateNumber(LeftNumber * RightNumber);
      end;
    TJSBinaryOperator.Divide:
      begin
        const LeftNumber = ToNumber(Left);
        const RightNumber = ToNumber(Right);
        Result := TJSValue.CreateNumber(Divide(LeftNumber, RightNumber));
      end;
    TJSBinaryOperator.Modulo:
      begin
        const LeftNumber = ToNumber(Left);
        const RightNumber = ToNumber(Right);
        Result := TJSValue.CreateNumber(Remainder(LeftNumber, RightNumber));
      end;
    TJSBinaryOperator.LessThan,
    TJSBinaryOperator.LessThanOrEqual,
    TJSBinaryOperator.GreaterThan,
    TJSBinaryOperator.GreaterThanOrEqual:
      Result := TJSValue.CreateBoolean(Compare(Operator_, Left, Right));
    TJSBinaryOperator.BitwiseAnd,
    TJSBinaryOperator.BitwiseOr,
    TJSBinaryOperator.BitwiseXor:
      Result := Bitwise(Operator_, Left, Right);
    TJSBinaryOperator.LeftShift,
    TJSBinaryOperator.RightShift,
    TJSBinaryOperator.UnsignedRightShift:
      Result := Shift(Operator_, Left, Right);
  else
    raise ENotSupportedException.CreateFmt('Operator is not an arithmetic operator: %d', [Ord(Operator_)]);
  end;
end;

class function TJSOperators.Divide(const Dividend: Double; const Divisor: Double): Double;
begin
  if Divisor <> 0 then
    Exit(Dividend / Divisor);

  if IsNaN(Dividend) or (Dividend = 0) then
    Exit(NaN);

  const IsNegativeResult = ((Dividend < 0) xor Divisor.Sign);
  if IsNegativeResult then
    Result := NegInfinity
  else
    Result := Infinity;
end;

class function TJSOperators.Remainder(const Dividend: Double; const Divisor: Double): Double;
begin
  const IsUndefinedRemainder = (Divisor = 0) or IsNaN(Divisor) or IsNaN(Dividend) or IsInfinite(Dividend);
  if IsUndefinedRemainder then
    Exit(NaN);

  if IsInfinite(Divisor) then
    Exit(Dividend);

  const Remainder = FMod(Dividend, Divisor);

  Result := TJSMathFunctions.KeepZeroSign(Remainder, Dividend);
end;

class function TJSOperators.ToAddOperand(const Value: TJSValue; const Limits: TJSLimits): TJSValue;
begin
  if Value.IsArray then
  begin
    const Text = Value.ToLimitedString(Limits);
    Result := TJSValue.CreateString(Text);
    Exit;
  end;

  Result := ToPrimitive(Value);
end;

class function TJSOperators.Add(const Left: TJSValue; const Right: TJSValue; const Limits: TJSLimits): TJSValue;
begin
  const LeftPrimitive = ToAddOperand(Left, Limits);
  const RightPrimitive = ToAddOperand(Right, Limits);

  const IsStringConcat = LeftPrimitive.IsString or RightPrimitive.IsString;
  if not IsStringConcat then
    Exit(TJSValue.CreateNumber(LeftPrimitive.ToNumber + RightPrimitive.ToNumber));

  const LeftText = LeftPrimitive.ToLimitedString(Limits);
  const RightText = RightPrimitive.ToLimitedString(Limits);
  Limits.EnsureStringLength(Int64(Length(LeftText)) + Length(RightText));

  Result := TJSValue.CreateString(LeftText + RightText);
end;

class function TJSOperators.Compare(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                                    const Right: TJSValue): Boolean;
begin
  const LeftPrimitive = Left.ToPrimitive(False);
  const RightPrimitive = Right.ToPrimitive(False);

  if LeftPrimitive.IsString and RightPrimitive.IsString then
  begin
    const Order = CompareStr(LeftPrimitive.AsString, RightPrimitive.AsString);

    case Operator_ of
      TJSBinaryOperator.LessThan           : Exit(Order < 0);
      TJSBinaryOperator.LessThanOrEqual    : Exit(Order <= 0);
      TJSBinaryOperator.GreaterThan        : Exit(Order > 0);
      TJSBinaryOperator.GreaterThanOrEqual : Exit(Order >= 0);
    else
      raise ENotSupportedException.CreateFmt('Operator is not a relational operator: %d', [Ord(Operator_)]);
    end;
  end;

  const LeftNumber = LeftPrimitive.ToNumber;
  const RightNumber = RightPrimitive.ToNumber;

  case Operator_ of
    TJSBinaryOperator.LessThan           : Result := LeftNumber < RightNumber;
    TJSBinaryOperator.LessThanOrEqual    : Result := LeftNumber <= RightNumber;
    TJSBinaryOperator.GreaterThan        : Result := LeftNumber > RightNumber;
    TJSBinaryOperator.GreaterThanOrEqual : Result := LeftNumber >= RightNumber;
  else
    raise ENotSupportedException.CreateFmt('Operator is not a relational operator: %d', [Ord(Operator_)]);
  end;
end;

class function TJSOperators.Bitwise(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                                    const Right: TJSValue): TJSValue;
begin
  const LeftInteger = ToInt32(Left);
  const RightInteger = ToInt32(Right);

  case Operator_ of
    TJSBinaryOperator.BitwiseAnd : Result := TJSValue.CreateNumber(LeftInteger and RightInteger);
    TJSBinaryOperator.BitwiseOr  : Result := TJSValue.CreateNumber(LeftInteger or RightInteger);
    TJSBinaryOperator.BitwiseXor : Result := TJSValue.CreateNumber(LeftInteger xor RightInteger);
  else
    raise ENotSupportedException.CreateFmt('Operator is not a bitwise operator: %d', [Ord(Operator_)]);
  end;
end;

class function TJSOperators.ShiftRightKeepingSign(const Value: Integer; const Count: Byte): Integer;
begin
  if Value >= 0 then
    Exit(Value shr Count);

  Result := not ((not Value) shr Count);
end;

class function TJSOperators.Shift(const Operator_: TJSBinaryOperator; const Left: TJSValue;
                                  const Right: TJSValue): TJSValue;
begin
  const LeftInteger = ToInt32(Left);
  const Count = Byte(ToUint32(Right) and SHIFT_COUNT_MASK);

  case Operator_ of
    TJSBinaryOperator.LeftShift          : Result := TJSValue.CreateNumber(Integer(Cardinal(LeftInteger) shl Count));
    TJSBinaryOperator.RightShift         : Result := TJSValue.CreateNumber(ShiftRightKeepingSign(LeftInteger, Count));
    TJSBinaryOperator.UnsignedRightShift : Result := TJSValue.CreateNumber(Cardinal(LeftInteger) shr Count);
  else
    raise ENotSupportedException.CreateFmt('Operator is not a shift operator: %d', [Ord(Operator_)]);
  end;
end;

end.
