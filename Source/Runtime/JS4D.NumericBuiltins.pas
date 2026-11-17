unit JS4D.NumericBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSNumericBuiltins = class
  private
    type
      TUnaryMathOperation = reference to function(const Value: Double): Double;
      TBinaryMathOperation = reference to function(const Left, Right: Double): Double;
      TNumberPredicate = reference to function(const Value: Double): Boolean;

    const
      EPSILON_NAME = 'EPSILON';
      MAX_SAFE_INTEGER_NAME = 'MAX_SAFE_INTEGER';
      MIN_SAFE_INTEGER_NAME = 'MIN_SAFE_INTEGER';
      PARSE_FLOAT_NAME = 'parseFloat';
      PARSE_INT_NAME = 'parseInt';
      EPSILON_VALUE = 2.220446049250313e-16;
      MAX_DOUBLE_NAME = 'MAX_VALUE';
      MIN_DOUBLE_NAME = 'MIN_VALUE';
      MIN_DOUBLE_VALUE = 5e-324;
      POSITIVE_INFINITY_NAME = 'POSITIVE_INFINITY';
      NEGATIVE_INFINITY_NAME = 'NEGATIVE_INFINITY';
      MATH_POW_NAME = 'pow';
      MATH_ATAN2_NAME = 'atan2';
      MATH_MIN_NAME = 'min';
      MATH_MAX_NAME = 'max';
      MATH_RANDOM_NAME = 'random';
      MATH_E_VALUE = 2.718281828459045;
      MATH_LN2_VALUE = 0.6931471805599453;
      MATH_LN10_VALUE = 2.302585092994046;
      MATH_LOG2E_VALUE = 1.4426950408889634;
      MATH_LOG10E_VALUE = 0.4342944819032518;
      MATH_SQRT2_VALUE = 1.4142135623730951;
      MATH_SQRT1_2_VALUE = 0.7071067811865476;
      RANDOM_SCALE = 1.1102230246251565e-16;
      RANDOM_FALLBACK_SEED = UInt64($9E3779B97F4A7C15);
      RANDOM_WARM_UP_STEPS = 8;
      RANDOM_DISCARDED_BITS = 11;

    class function NumberOf(const Value: TJSValue): Double; static;
    class function ArgumentAsNumber(const Args: TArray<TJSValue>; const Index: Integer): Double; static;
    class procedure DefineMethod(const Target: IJSObject; const Name: string; const Method: TNativeFunction); static;
    class procedure DefineConstant(const Target: IJSObject; const Name: string; const Value: Double); static;
    class procedure DefineUnaryMath(const MathObject: IJSObject; const Name: string;
                                    const Operation: TUnaryMathOperation); static;
    class procedure DefineNumberPredicate(const NumberObject: IJSObject; const Name: string;
                                          const Predicate: TNumberPredicate); static;
    class procedure DefineBinaryMath(const MathObject: IJSObject; const Name: string;
                                     const Operation: TBinaryMathOperation); static;
    class procedure DefineExtremum(const MathObject: IJSObject; const Name: string; const EmptyResult: Double;
                                   const Choose: TBinaryMathOperation); static;
    class procedure DefineRandom(const MathObject: IJSObject); static;
    class function NextRandomState(const State: UInt64): UInt64; static;
    class function SeedRandomState(const MathObject: IJSObject): UInt64; static;
    class procedure DefineMathConstants(const MathObject: IJSObject); static;
    class procedure DefineRoundingFunctions(const MathObject: IJSObject); static;
    class procedure DefineTrigonometricFunctions(const MathObject: IJSObject); static;
    class procedure DefineHyperbolicFunctions(const MathObject: IJSObject); static;
    class procedure DefineLogarithmicFunctions(const MathObject: IJSObject); static;
    class procedure DefineRootAndSignFunctions(const MathObject: IJSObject); static;
    class procedure DefineHypot(const MathObject: IJSObject); static;
    class procedure DefineImul(const MathObject: IJSObject); static;
    class procedure DefineClz32(const MathObject: IJSObject); static;

  public
    class procedure RegisterMath(const MathObject: IJSObject); static;
    class procedure RegisterNumberConstants(const NumberObject: IJSObject); static;
    class procedure RegisterNumber(const NumberObject: IJSObject; const ParseInt, ParseFloat: TJSValue); static;
  end;

implementation

uses
  JS4D.Conversions,
  JS4D.ArrayLike,
  System.Math,
  System.Diagnostics,
  JS4D.BuiltinSupport,
  JS4D.MathFunctions,
  JS4D.NumberText,
  JS4D.Operators;

class function TJSNumericBuiltins.NumberOf(const Value: TJSValue): Double;
begin
  if Value.IsNumber then
    Result := Value.AsNumber
  else
    Result := TJSConversions.ToNumber(Value);
end;

class function TJSNumericBuiltins.ArgumentAsNumber(const Args: TArray<TJSValue>; const Index: Integer): Double;
begin
  const Argument = TJSArrayLike.Argument(Args, Index);
  if Argument.IsUndefined then
    Result := NaN
  else
    Result := NumberOf(Argument);
end;

class procedure TJSNumericBuiltins.DefineMethod(const Target: IJSObject; const Name: string;
                                                const Method: TNativeFunction);
begin
  const Func = TJSFunction.CreateNative(Name, Method);
  Func.IsConstructor := False;

  Target.SetProperty(Name, TJSValue.CreateObject(Func));
end;

class procedure TJSNumericBuiltins.DefineConstant(const Target: IJSObject; const Name: string; const Value: Double);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(Value));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Name, Descriptor);
end;

class procedure TJSNumericBuiltins.DefineUnaryMath(const MathObject: IJSObject; const Name: string;
                                                   const Operation: TUnaryMathOperation);
begin
  DefineMethod(MathObject, Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = ArgumentAsNumber(Args, 0);
      const Calculated = Operation(Argument);

      Result := TJSValue.CreateNumber(Calculated);
    end);
end;

class procedure TJSNumericBuiltins.DefineBinaryMath(const MathObject: IJSObject; const Name: string;
                                                    const Operation: TBinaryMathOperation);
begin
  DefineMethod(MathObject, Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Left = ArgumentAsNumber(Args, 0);
      const Right = ArgumentAsNumber(Args, 1);
      const Calculated = Operation(Left, Right);

      Result := TJSValue.CreateNumber(Calculated);
    end);
end;

class procedure TJSNumericBuiltins.DefineExtremum(const MathObject: IJSObject; const Name: string;
                                                  const EmptyResult: Double; const Choose: TBinaryMathOperation);
begin
  DefineMethod(MathObject, Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Extremum := EmptyResult;
      var SawNaN := False;

      for var Argument in Args do
      begin
        const Value = NumberOf(Argument);
        if IsNaN(Value) then
          SawNaN := True
        else
          Extremum := Choose(Extremum, Value);
      end;

      if SawNaN then
        Result := TJSValue.CreateNaN
      else
        Result := TJSValue.CreateNumber(Extremum);
    end);
end;

class function TJSNumericBuiltins.NextRandomState(const State: UInt64): UInt64;
begin
  Result := State xor (State shl 13);
  Result := Result xor (Result shr 7);
  Result := Result xor (Result shl 17);
end;

class function TJSNumericBuiltins.SeedRandomState(const MathObject: IJSObject): UInt64;
begin
  const ObjectAddress = UInt64(NativeUInt(Pointer(MathObject)));
  Result := UInt64(TStopwatch.GetTimeStamp) xor (ObjectAddress shl 32) xor ObjectAddress;
  if Result = 0 then
    Result := RANDOM_FALLBACK_SEED;

  for var Step := 1 to RANDOM_WARM_UP_STEPS do
  begin
    Result := NextRandomState(Result);
  end;
end;

class procedure TJSNumericBuiltins.DefineRandom(const MathObject: IJSObject);
begin
  var State := SeedRandomState(MathObject);

  DefineMethod(MathObject, MATH_RANDOM_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      State := NextRandomState(State);
      const Fraction = (State shr RANDOM_DISCARDED_BITS) * RANDOM_SCALE;

      Result := TJSValue.CreateNumber(Fraction);
    end);
end;

class procedure TJSNumericBuiltins.DefineMathConstants(const MathObject: IJSObject);
begin
  DefineConstant(MathObject, 'PI', Pi);
  DefineConstant(MathObject, 'E', MATH_E_VALUE);
  DefineConstant(MathObject, 'LN2', MATH_LN2_VALUE);
  DefineConstant(MathObject, 'LN10', MATH_LN10_VALUE);
  DefineConstant(MathObject, 'LOG2E', MATH_LOG2E_VALUE);
  DefineConstant(MathObject, 'LOG10E', MATH_LOG10E_VALUE);
  DefineConstant(MathObject, 'SQRT2', MATH_SQRT2_VALUE);
  DefineConstant(MathObject, 'SQRT1_2', MATH_SQRT1_2_VALUE);
end;

class procedure TJSNumericBuiltins.DefineRoundingFunctions(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'floor', TJSMathFunctions.Floor);
  DefineUnaryMath(MathObject, 'ceil', TJSMathFunctions.Ceil);
  DefineUnaryMath(MathObject, 'round', TJSMathFunctions.Round);
  DefineUnaryMath(MathObject, 'trunc', TJSMathFunctions.Trunc);
  DefineUnaryMath(MathObject, 'fround', TJSMathFunctions.Fround);
end;

class procedure TJSNumericBuiltins.DefineTrigonometricFunctions(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'sin', TJSMathFunctions.Sin);
  DefineUnaryMath(MathObject, 'cos', TJSMathFunctions.Cosine);
  DefineUnaryMath(MathObject, 'tan', TJSMathFunctions.Tan);
  DefineUnaryMath(MathObject, 'asin', TJSMathFunctions.ArcSine);
  DefineUnaryMath(MathObject, 'acos', TJSMathFunctions.ArcCosine);
  DefineUnaryMath(MathObject, 'atan', TJSMathFunctions.ArcTangent);
end;

class procedure TJSNumericBuiltins.DefineHyperbolicFunctions(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'sinh', TJSMathFunctions.Sinh);
  DefineUnaryMath(MathObject, 'cosh', TJSMathFunctions.Cosh);
  DefineUnaryMath(MathObject, 'tanh', TJSMathFunctions.Tanh);
  DefineUnaryMath(MathObject, 'asinh', TJSMathFunctions.Asinh);
  DefineUnaryMath(MathObject, 'acosh', TJSMathFunctions.Acosh);
  DefineUnaryMath(MathObject, 'atanh', TJSMathFunctions.Atanh);
end;

class procedure TJSNumericBuiltins.DefineLogarithmicFunctions(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'exp', TJSMathFunctions.Exponential);
  DefineUnaryMath(MathObject, 'expm1', TJSMathFunctions.Expm1);
  DefineUnaryMath(MathObject, 'log', TJSMathFunctions.NaturalLogarithm);
  DefineUnaryMath(MathObject, 'log2', TJSMathFunctions.Log2);
  DefineUnaryMath(MathObject, 'log10', TJSMathFunctions.Log10);
  DefineUnaryMath(MathObject, 'log1p', TJSMathFunctions.Log1p);
end;

class procedure TJSNumericBuiltins.DefineRootAndSignFunctions(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'abs', TJSMathFunctions.AbsoluteValue);
  DefineUnaryMath(MathObject, 'sign', TJSMathFunctions.Sign);
  DefineUnaryMath(MathObject, 'sqrt', TJSMathFunctions.SquareRoot);
  DefineUnaryMath(MathObject, 'cbrt', TJSMathFunctions.Cbrt);
end;

class procedure TJSNumericBuiltins.DefineNumberPredicate(const NumberObject: IJSObject; const Name: string;
                                                         const Predicate: TNumberPredicate);
begin
  DefineMethod(NumberObject, Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Matches = (Argument.IsNumber and Predicate(Argument.ToNumber));

      Result := TJSValue.CreateBoolean(Matches);
    end);
end;

class procedure TJSNumericBuiltins.DefineHypot(const MathObject: IJSObject);
begin
  DefineMethod(MathObject, 'hypot',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Numbers: TArray<Double>;
      SetLength(Numbers, Length(Args));
      for var Index := 0 to High(Args) do
      begin
        Numbers[Index] := TJSConversions.ToNumber(Args[Index]);
      end;

      const Magnitude = TJSMathFunctions.Hypot(Numbers);

      Result := TJSValue.CreateNumber(Magnitude);
    end);
end;

class procedure TJSNumericBuiltins.DefineImul(const MathObject: IJSObject);
begin
  DefineMethod(MathObject, 'imul',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const LeftArgument = TJSArrayLike.Argument(Args, 0);
      const RightArgument = TJSArrayLike.Argument(Args, 1);
      const Left = TJSOperators.ToInt32(LeftArgument);
      const Right = TJSOperators.ToInt32(RightArgument);
      const Product = TJSMathFunctions.Imul(Left, Right);

      Result := TJSValue.CreateNumber(Product);
    end);
end;

class procedure TJSNumericBuiltins.DefineClz32(const MathObject: IJSObject);
begin
  DefineMethod(MathObject, 'clz32',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Value = TJSOperators.ToUint32(Argument);
      const LeadingZeros = TJSMathFunctions.Clz32(Value);

      Result := TJSValue.CreateNumber(LeadingZeros);
    end);
end;

class procedure TJSNumericBuiltins.RegisterMath(const MathObject: IJSObject);
begin
  DefineMathConstants(MathObject);

  DefineRoundingFunctions(MathObject);
  DefineTrigonometricFunctions(MathObject);
  DefineHyperbolicFunctions(MathObject);
  DefineLogarithmicFunctions(MathObject);
  DefineRootAndSignFunctions(MathObject);
  DefineBinaryMath(MathObject, MATH_POW_NAME, TJSMathFunctions.Power);
  DefineBinaryMath(MathObject, MATH_ATAN2_NAME, TJSMathFunctions.ArcTangent2);
  DefineExtremum(MathObject, MATH_MIN_NAME, Infinity, TJSMathFunctions.Smaller);
  DefineExtremum(MathObject, MATH_MAX_NAME, NegInfinity, TJSMathFunctions.Larger);
  DefineRandom(MathObject);
  DefineHypot(MathObject);
  DefineImul(MathObject);
  DefineClz32(MathObject);
end;

class procedure TJSNumericBuiltins.RegisterNumberConstants(const NumberObject: IJSObject);
begin
  DefineConstant(NumberObject, MAX_DOUBLE_NAME, MaxDouble);
  DefineConstant(NumberObject, MIN_DOUBLE_NAME, MIN_DOUBLE_VALUE);
  DefineConstant(NumberObject, NAN_TEXT, NaN);
  DefineConstant(NumberObject, POSITIVE_INFINITY_NAME, Infinity);
  DefineConstant(NumberObject, NEGATIVE_INFINITY_NAME, NegInfinity);
end;

class procedure TJSNumericBuiltins.RegisterNumber(const NumberObject: IJSObject; const ParseInt, ParseFloat: TJSValue);
begin
  RegisterNumberConstants(NumberObject);
  DefineConstant(NumberObject, EPSILON_NAME, EPSILON_VALUE);
  DefineConstant(NumberObject, MAX_SAFE_INTEGER_NAME, MAX_SAFE_INTEGER);
  DefineConstant(NumberObject, MIN_SAFE_INTEGER_NAME, -MAX_SAFE_INTEGER);

  DefineNumberPredicate(NumberObject, 'isFinite', TJSMathFunctions.IsFiniteNumber);
  DefineNumberPredicate(NumberObject, 'isNaN',
    function(const Value: Double): Boolean
    begin
      Result := IsNaN(Value);
    end);
  DefineNumberPredicate(NumberObject, 'isInteger', TJSMathFunctions.IsInteger);
  DefineNumberPredicate(NumberObject, 'isSafeInteger', TJSMathFunctions.IsSafeInteger);

  NumberObject.SetProperty(PARSE_FLOAT_NAME, ParseFloat);
  NumberObject.SetProperty(PARSE_INT_NAME, ParseInt);
end;

end.
