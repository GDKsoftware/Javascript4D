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
      SHIFT_COUNT_MASK = 31;


    class function Divide(const Dividend: Double; const Divisor: Double): Double; static;
    class function Remainder(const Dividend: Double; const Divisor: Double): Double; static;
    class function ToAddOperand(const Value: TJSValue; const Limits: TJSLimits): TJSValue; static;
    class function Add(const Left: TJSValue; const Right: TJSValue; const Limits: TJSLimits): TJSValue; static;
    class function RelationHolds(const BinaryOperator: TJSBinaryOperator; const Left: Double;
                                 const Right: Double): Boolean; static;
    class function Compare(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                           const Right: TJSValue): Boolean; static;
    class function ShiftRightKeepingSign(const Value: Integer; const Count: Byte): Integer; static;
    class function ApplyArithmetic(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                   const Right: TJSValue): TJSValue; static;
    class function Shift(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                         const Right: TJSValue): TJSValue; static;
    class function Bitwise(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                           const Right: TJSValue): TJSValue; static;

  public
    class function ToPrimitive(const Value: TJSValue): TJSValue; static;
    class function ToUint32(const Value: TJSValue): Cardinal; static;
    class function ToInt32(const Value: TJSValue): Integer; static;
    class function BinaryOperatorFor(const AssignmentOperator: TJSAssignmentOperator): TJSBinaryOperator; static;
    class function Apply(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue; const Right: TJSValue;
                         const Limits: TJSLimits): TJSValue; static;
  end;

implementation

uses
  JS4D.Conversions;

const
  NO_BINARY_FORM = 'Assignment operator has no binary form: %d';
  NOT_AN_ARITHMETIC_OPERATOR = 'Operator is not an arithmetic operator: %d';
  NOT_A_RELATIONAL_OPERATOR = 'Operator is not a relational operator: %d';
  NOT_A_BITWISE_OPERATOR = 'Operator is not a bitwise operator: %d';
  NOT_A_SHIFT_OPERATOR = 'Operator is not a shift operator: %d';

class function TJSOperators.ToPrimitive(const Value: TJSValue): TJSValue;
begin
  Result := Value.ToPrimitiveWithHint(TJSPrimitiveHint.Default);
end;

class function TJSOperators.ToUint32(const Value: TJSValue): Cardinal;
begin
  const Converted = TJSConversions.ToUint32(Value);

  Result := Cardinal(Converted);
end;

class function TJSOperators.ToInt32(const Value: TJSValue): Integer;
begin
  const Converted = ToUint32(Value);

  Result := Integer(Converted);
end;

class function TJSOperators.BinaryOperatorFor(const AssignmentOperator: TJSAssignmentOperator): TJSBinaryOperator;
begin
  case AssignmentOperator of
    TJSAssignmentOperator.AddAssign                : Result := TJSBinaryOperator.Add;
    TJSAssignmentOperator.SubtractAssign           : Result := TJSBinaryOperator.Subtract;
    TJSAssignmentOperator.MultiplyAssign           : Result := TJSBinaryOperator.Multiply;
    TJSAssignmentOperator.DivideAssign             : Result := TJSBinaryOperator.Divide;
    TJSAssignmentOperator.ModuloAssign             : Result := TJSBinaryOperator.Modulo;
    TJSAssignmentOperator.ExponentAssign           : Result := TJSBinaryOperator.Exponent;
    TJSAssignmentOperator.BitwiseAndAssign         : Result := TJSBinaryOperator.BitwiseAnd;
    TJSAssignmentOperator.BitwiseOrAssign          : Result := TJSBinaryOperator.BitwiseOr;
    TJSAssignmentOperator.BitwiseXorAssign         : Result := TJSBinaryOperator.BitwiseXor;
    TJSAssignmentOperator.LeftShiftAssign          : Result := TJSBinaryOperator.LeftShift;
    TJSAssignmentOperator.RightShiftAssign         : Result := TJSBinaryOperator.RightShift;
    TJSAssignmentOperator.UnsignedRightShiftAssign : Result := TJSBinaryOperator.UnsignedRightShift;
  else
    raise ENotSupportedException.CreateFmt(NO_BINARY_FORM, [Ord(AssignmentOperator)]);
  end;
end;

class function TJSOperators.ApplyArithmetic(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                            const Right: TJSValue): TJSValue;
begin
  const LeftNumber = TJSConversions.ToNumber(Left);
  const RightNumber = TJSConversions.ToNumber(Right);

  var Outcome: Double;
  case BinaryOperator of
    TJSBinaryOperator.Subtract : Outcome := LeftNumber - RightNumber;
    TJSBinaryOperator.Multiply : Outcome := LeftNumber * RightNumber;
    TJSBinaryOperator.Divide   : Outcome := Divide(LeftNumber, RightNumber);
    TJSBinaryOperator.Modulo   : Outcome := Remainder(LeftNumber, RightNumber);
    TJSBinaryOperator.Exponent : Outcome := TJSMathFunctions.Power(LeftNumber, RightNumber);
  else
    raise ENotSupportedException.CreateFmt(NOT_AN_ARITHMETIC_OPERATOR, [Ord(BinaryOperator)]);
  end;

  Result := TJSValue.CreateNumber(Outcome);
end;

class function TJSOperators.Apply(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                  const Right: TJSValue; const Limits: TJSLimits): TJSValue;
begin
  case BinaryOperator of
    TJSBinaryOperator.Add:
      Result := Add(Left, Right, Limits);
    TJSBinaryOperator.Subtract,
    TJSBinaryOperator.Multiply,
    TJSBinaryOperator.Divide,
    TJSBinaryOperator.Modulo,
    TJSBinaryOperator.Exponent:
      Result := ApplyArithmetic(BinaryOperator, Left, Right);
    TJSBinaryOperator.LessThan,
    TJSBinaryOperator.LessThanOrEqual,
    TJSBinaryOperator.GreaterThan,
    TJSBinaryOperator.GreaterThanOrEqual:
      begin
        const IsOrdered = Compare(BinaryOperator, Left, Right);
        Result := TJSValue.CreateBoolean(IsOrdered);
      end;
    TJSBinaryOperator.BitwiseAnd,
    TJSBinaryOperator.BitwiseOr,
    TJSBinaryOperator.BitwiseXor:
      Result := Bitwise(BinaryOperator, Left, Right);
    TJSBinaryOperator.LeftShift,
    TJSBinaryOperator.RightShift,
    TJSBinaryOperator.UnsignedRightShift:
      Result := Shift(BinaryOperator, Left, Right);
  else
    raise ENotSupportedException.CreateFmt(NOT_AN_ARITHMETIC_OPERATOR, [Ord(BinaryOperator)]);
  end;
end;

class function TJSOperators.Divide(const Dividend: Double; const Divisor: Double): Double;
begin
  const IsDivisionByZero = (Divisor = 0);
  if not IsDivisionByZero then
    Exit(Dividend / Divisor);

  const IsIndeterminate = (IsNaN(Dividend) or (Dividend = 0));
  if IsIndeterminate then
    Exit(NaN);

  const IsNegativeResult = ((Dividend < 0) xor Divisor.Sign);
  if IsNegativeResult then
    Result := NegInfinity
  else
    Result := Infinity;
end;

class function TJSOperators.Remainder(const Dividend: Double; const Divisor: Double): Double;
begin
  const IsUndefinedRemainder = ((Divisor = 0) or IsNaN(Divisor) or IsNaN(Dividend) or IsInfinite(Dividend));
  if IsUndefinedRemainder then
    Exit(NaN);

  if IsInfinite(Divisor) then
    Exit(Dividend);

  const Modulus = FMod(Dividend, Divisor);

  Result := TJSMathFunctions.KeepZeroSign(Modulus, Dividend);
end;

class function TJSOperators.ToAddOperand(const Value: TJSValue; const Limits: TJSLimits): TJSValue;
begin
  const IsPlainArray = (Value.IsArray and Value.HasUntouchedArrayConversion(TJSPrimitiveHint.Default));
  if IsPlainArray then
  begin
    const Text = Value.ToUntouchedArrayText(Limits);
    Result := TJSValue.CreateString(Text);
    Exit;
  end;

  Result := ToPrimitive(Value);
end;

class function TJSOperators.Add(const Left: TJSValue; const Right: TJSValue; const Limits: TJSLimits): TJSValue;
begin
  const LeftPrimitive = ToAddOperand(Left, Limits);
  const RightPrimitive = ToAddOperand(Right, Limits);

  const IsStringConcat = (LeftPrimitive.IsString or RightPrimitive.IsString);
  if not IsStringConcat then
  begin
    const Sum = LeftPrimitive.ToNumber + RightPrimitive.ToNumber;

    Result := TJSValue.CreateNumber(Sum);
    Exit;
  end;

  const LeftText = LeftPrimitive.ToLimitedString(Limits);
  const RightText = RightPrimitive.ToLimitedString(Limits);
  const CombinedLength = Int64(Length(LeftText)) + Length(RightText);
  Limits.EnsureStringLength(CombinedLength);

  const Combined = LeftText + RightText;

  Result := TJSValue.CreateString(Combined);
end;

class function TJSOperators.RelationHolds(const BinaryOperator: TJSBinaryOperator; const Left: Double;
                                          const Right: Double): Boolean;
begin
  case BinaryOperator of
    TJSBinaryOperator.LessThan           : Result := (Left < Right);
    TJSBinaryOperator.LessThanOrEqual    : Result := (Left <= Right);
    TJSBinaryOperator.GreaterThan        : Result := (Left > Right);
    TJSBinaryOperator.GreaterThanOrEqual : Result := (Left >= Right);
  else
    raise ENotSupportedException.CreateFmt(NOT_A_RELATIONAL_OPERATOR, [Ord(BinaryOperator)]);
  end;
end;

class function TJSOperators.Compare(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                    const Right: TJSValue): Boolean;
begin
  const LeftPrimitive = Left.ToPrimitive(False);
  const RightPrimitive = Right.ToPrimitive(False);

  const AreStrings = (LeftPrimitive.IsString and RightPrimitive.IsString);
  if AreStrings then
  begin
    const LeftText = LeftPrimitive.AsString;
    const RightText = RightPrimitive.AsString;
    const Order = CompareStr(LeftText, RightText);

    Result := RelationHolds(BinaryOperator, Order, 0);
    Exit;
  end;

  const LeftNumber = LeftPrimitive.ToNumber;
  const RightNumber = RightPrimitive.ToNumber;

  Result := RelationHolds(BinaryOperator, LeftNumber, RightNumber);
end;

class function TJSOperators.Bitwise(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                    const Right: TJSValue): TJSValue;
begin
  const LeftInteger = ToInt32(Left);
  const RightInteger = ToInt32(Right);

  case BinaryOperator of
    TJSBinaryOperator.BitwiseAnd : Result := TJSValue.CreateNumber(LeftInteger and RightInteger);
    TJSBinaryOperator.BitwiseOr  : Result := TJSValue.CreateNumber(LeftInteger or RightInteger);
    TJSBinaryOperator.BitwiseXor : Result := TJSValue.CreateNumber(LeftInteger xor RightInteger);
  else
    raise ENotSupportedException.CreateFmt(NOT_A_BITWISE_OPERATOR, [Ord(BinaryOperator)]);
  end;
end;

class function TJSOperators.ShiftRightKeepingSign(const Value: Integer; const Count: Byte): Integer;
begin
  const IsNonNegative = (Value >= 0);
  if IsNonNegative then
    Exit(Value shr Count);

  Result := not ((not Value) shr Count);
end;

class function TJSOperators.Shift(const BinaryOperator: TJSBinaryOperator; const Left: TJSValue;
                                  const Right: TJSValue): TJSValue;
begin
  const LeftInteger = ToInt32(Left);
  const Count = Byte(ToUint32(Right) and SHIFT_COUNT_MASK);

  const LeftBits = Cardinal(LeftInteger);

  var Shifted: Double;
  case BinaryOperator of
    TJSBinaryOperator.LeftShift          : Shifted := Integer(LeftBits shl Count);
    TJSBinaryOperator.RightShift         : Shifted := ShiftRightKeepingSign(LeftInteger, Count);
    TJSBinaryOperator.UnsignedRightShift : Shifted := LeftBits shr Count;
  else
    raise ENotSupportedException.CreateFmt(NOT_A_SHIFT_OPERATOR, [Ord(BinaryOperator)]);
  end;

  Result := TJSValue.CreateNumber(Shifted);
end;

end.
