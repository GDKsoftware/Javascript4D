unit JS4D.NumericBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  TJSNumericBuiltins = class
  private
    type
      TUnaryMathOperation = reference to function(const Value: Double): Double;
      TNumberPredicate = reference to function(const Value: Double): Boolean;

    const
      EPSILON_NAME = 'EPSILON';
      MAX_SAFE_INTEGER_NAME = 'MAX_SAFE_INTEGER';
      MIN_SAFE_INTEGER_NAME = 'MIN_SAFE_INTEGER';
      PARSE_FLOAT_NAME = 'parseFloat';
      PARSE_INT_NAME = 'parseInt';
      EPSILON_VALUE = 2.220446049250313e-16;
      MAX_SAFE_INTEGER_VALUE = 9007199254740991.0;

    class function ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue; static;
    class function ArgumentAsNumber(const Args: TArray<TJSValue>; const Index: Integer): Double; static;
    class procedure DefineMethod(const Target: IJSObject; const Name: string; const Method: TNativeFunction); static;
    class procedure DefineConstant(const Target: IJSObject; const Name: string; const Value: Double); static;
    class procedure DefineUnaryMath(const MathObject: IJSObject; const Name: string;
                                    const Operation: TUnaryMathOperation); static;
    class procedure DefineNumberPredicate(const NumberObject: IJSObject; const Name: string;
                                          const Predicate: TNumberPredicate); static;
    class procedure DefineHypot(const MathObject: IJSObject); static;
    class procedure DefineImul(const MathObject: IJSObject); static;
    class procedure DefineClz32(const MathObject: IJSObject); static;

  public
    class procedure RegisterMath(const MathObject: IJSObject); static;
    class procedure RegisterNumber(const NumberObject: IJSObject; const ParseInt, ParseFloat: TJSValue); static;
  end;

implementation

uses
  System.Math,
  JS4D.MathFunctions,
  JS4D.Operators;

class function TJSNumericBuiltins.ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
begin
  if Index < Length(Args) then
    Exit(Args[Index]);

  Result := TJSValue.CreateUndefined;
end;

class function TJSNumericBuiltins.ArgumentAsNumber(const Args: TArray<TJSValue>; const Index: Integer): Double;
begin
  Result := TJSOperators.ToNumber(ArgumentAt(Args, Index));
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

class procedure TJSNumericBuiltins.DefineNumberPredicate(const NumberObject: IJSObject; const Name: string;
                                                         const Predicate: TNumberPredicate);
begin
  DefineMethod(NumberObject, Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = ArgumentAt(Args, 0);
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
        Numbers[Index] := TJSOperators.ToNumber(Args[Index]);
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
      const LeftArgument = ArgumentAt(Args, 0);
      const RightArgument = ArgumentAt(Args, 1);
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
      const Argument = ArgumentAt(Args, 0);
      const Value = TJSOperators.ToUint32(Argument);
      const LeadingZeros = TJSMathFunctions.Clz32(Value);

      Result := TJSValue.CreateNumber(LeadingZeros);
    end);
end;

class procedure TJSNumericBuiltins.RegisterMath(const MathObject: IJSObject);
begin
  DefineUnaryMath(MathObject, 'cbrt', TJSMathFunctions.Cbrt);
  DefineUnaryMath(MathObject, 'log2', TJSMathFunctions.Log2);
  DefineUnaryMath(MathObject, 'log10', TJSMathFunctions.Log10);
  DefineUnaryMath(MathObject, 'log1p', TJSMathFunctions.Log1p);
  DefineUnaryMath(MathObject, 'expm1', TJSMathFunctions.Expm1);
  DefineUnaryMath(MathObject, 'sinh', TJSMathFunctions.Sinh);
  DefineUnaryMath(MathObject, 'cosh', TJSMathFunctions.Cosh);
  DefineUnaryMath(MathObject, 'tanh', TJSMathFunctions.Tanh);
  DefineUnaryMath(MathObject, 'asinh', TJSMathFunctions.Asinh);
  DefineUnaryMath(MathObject, 'acosh', TJSMathFunctions.Acosh);
  DefineUnaryMath(MathObject, 'atanh', TJSMathFunctions.Atanh);
  DefineUnaryMath(MathObject, 'fround', TJSMathFunctions.Fround);
  DefineHypot(MathObject);
  DefineImul(MathObject);
  DefineClz32(MathObject);
end;

class procedure TJSNumericBuiltins.RegisterNumber(const NumberObject: IJSObject; const ParseInt, ParseFloat: TJSValue);
begin
  DefineConstant(NumberObject, EPSILON_NAME, EPSILON_VALUE);
  DefineConstant(NumberObject, MAX_SAFE_INTEGER_NAME, MAX_SAFE_INTEGER_VALUE);
  DefineConstant(NumberObject, MIN_SAFE_INTEGER_NAME, -MAX_SAFE_INTEGER_VALUE);

  DefineNumberPredicate(NumberObject, 'isFinite',
    function(const Value: Double): Boolean
    begin
      Result := not (IsNaN(Value) or IsInfinite(Value));
    end);
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
