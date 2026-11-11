unit JS4D.Engine;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.DateUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.Lexer,
  JS4D.Parser,
  JS4D.AST,
  JS4D.Interpreter,
  JS4D.Operators,
  JS4D.Builtins,
  JS4D.ArrayIteration,
  JS4D.ArrayIterator,
  JS4D.ArrayGeneric,
  JS4D.ArrayLike,
  JS4D.PropertyDescriptors,
  JS4D.PrototypeMethods,
  JS4D.DateBuiltins,
  JS4D.BuiltinAttributes,
  JS4D.Json,
  JS4D.JsonSyntax,
  JS4D.JsonReader,
  JS4D.JsonReviver,
  JS4D.ObjectKeys,
  JS4D.ObjectOperations,
  JS4D.Symbols,
  JS4D.SymbolRegistry,
  JS4D.SymbolBuiltins,
  JS4D.Conversions,
  JS4D.IteratorBuiltins,
  JS4D.CollectionBuiltins,
  JS4D.BinaryBuiltins,
  JS4D.ProxyBuiltins,
  JS4D.ReflectBuiltins,
  JS4D.RegExpProtocol,
  JS4D.ObjectBuiltins,
  JS4D.StringPatternMethods,
  JS4D.UriCoding,
  JS4D.MathFunctions,
  JS4D.NumericBuiltins,
  JS4D.NumberParse,
  JS4D.Errors;

type
  TConsoleOutputHandler = reference to procedure(const Output: string);
  TUriTransform = reference to function(const Text: string): string;

  TJSEngine = class
  private
    FInterpreter: TJSInterpreter;
    FPrototypeMethods: TJSPrototypeMethods;
    FDateBuiltins: TJSDateBuiltins;
    FSymbolBuiltins: TJSSymbolBuiltins;
    FIteratorBuiltins: TJSIteratorBuiltins;
    FCollectionBuiltins: TJSCollectionBuiltins;
    FBinaryBuiltins: TJSBinaryBuiltins;
    FProxyBuiltins: TJSProxyBuiltins;
    FReflectBuiltins: TJSReflectBuiltins;
    FRegExpProtocol: TJSRegExpProtocol;
    FObjectBuiltins: TJSObjectBuiltins;
    FStringPatternMethods: TJSStringPatternMethods;
    FArrayIteratorPrototype: IJSObject;
    FPrograms: TList<TJSProgram>;
    FOnConsoleOutput: TConsoleOutputHandler;

    function ToText(const Value: TJSValue): string;
    function ToKeyText(const Value: TJSValue): string;
    class function ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue; static;
    function HasSameRegExpConstructor(const Pattern: TJSValue; const PrototypeObj: IJSObject): Boolean;
    procedure ReadRegExpSource(const Args: TArray<TJSValue>; const PatternIsRegExp: Boolean;
                               out Pattern: string; out Flags: string);
    function GetStepBudget: Int64;
    procedure SetStepBudget(const Value: Int64);
    function GetStepCount: Int64;
    function GetMaxCallDepth: Integer;
    procedure SetMaxCallDepth(const Value: Integer);
    function GetMaxStringLength: Integer;
    procedure SetMaxStringLength(const Value: Integer);
    function GetMaxArrayLength: Integer;
    procedure SetMaxArrayLength(const Value: Integer);

    function ParseProgram(const Source: string; const IsStrictContext: Boolean): TJSProgram;
    procedure RegisterBuiltInFunctions;
    procedure RegisterUriFunction(const Name: string; const Transform: TUriTransform);
    procedure RegisterStringRaw(const StringFunc: IJSFunction);
    procedure RegisterStringFromCodePoint(const StringFunc: IJSFunction);
    function CodePointsToString(const Args: TArray<TJSValue>): string;
    function ConcatenateRawStrings(const Args: TArray<TJSValue>): string;
    function CoerceToObject(const Value: TJSValue): IJSObject;
    class function IsEnumerableOwn(const Source: IJSObject; const Name: string): Boolean; static;
    class procedure PutChecked(const Target: IJSObject; const Name: string; const Value: TJSValue); static;
    procedure CopyEnumerableOwn(const Source: IJSObject; const Target: IJSObject);
    procedure RegisterConsole;
    procedure RegisterMath;
    procedure RegisterObject;
    procedure RegisterJSON;
    procedure RegisterArray;
    procedure RegisterArrayIterators(const PrototypeObj: IJSObject);
    procedure RegisterDate;
    procedure RegisterErrors;
    function CreateErrorConstructor(const ErrorType: TJSErrorType; const ErrorName: string): TJSFunction;
    function ConstructError(const ErrorType: TJSErrorType; const PrototypeObj: IJSObject;
                            const Args: TArray<TJSValue>): TJSValue;
    class procedure DefineHiddenProperty(const Target: IJSObject; const Name: string;
                                         const Value: TJSValue); static;
    class procedure DefineConstant(const Target: IJSObject; const Name: string;
                                   const Value: TJSValue); static;
    procedure RegisterRegExp;
    procedure RegisterFunctionObject;
    procedure RegisterPrototypeMethods;
    procedure AttachPrototypeObject(const Constructor_: IJSFunction; const PrototypeObj: IJSObject);
    function GlobalPrototype(const ConstructorName: string): IJSObject;
    procedure LinkIntrinsicPrototypes;
    procedure AssignMissingFunctionPrototypes;
    procedure AssignFunctionPrototype(const Target: IJSObject; const Pending: TStack<IJSObject>);
    procedure QueueMemberObjects(const Target: IJSObject; const Name: string; const Pending: TStack<IJSObject>);
    procedure ApplyBuiltinAttributes;
    procedure DefineRestrictedFunctionProperties(const PrototypeObj: IJSObject);

    function CreateDynamicFunction(const Args: TArray<TJSValue>): TJSValue;
    function CreateFunctionPrototypeMethod(const MethodName: string): IJSFunction;
    function CreateArrayPrototypeMethod(const MethodName: string): IJSFunction;
    function CreateArrayStaticMethod(const MethodName: string): IJSFunction;
    function CreateArrayIteratorFactory(const MethodName: string; const Kind: TJSArrayIteratorKind;
                                        const IteratorPrototype: IJSObject): IJSFunction;
    function CreateObjectPrototypeMethod(const MethodName: string): IJSFunction;
    function ConstructArray(const Args: TArray<TJSValue>; const PrototypeObj: IJSObject): TJSValue;
    function ConstructObject(const Args: TArray<TJSValue>; const PrototypeObj: IJSObject): TJSValue;
    function IsValidArrayLength(const Value: Double): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Source: string): TJSValue;
    function Evaluate(const Expression: string): TJSValue;
    procedure Cancel;
    procedure CollectGarbage;

    procedure RegisterFunction(const Name: string; const Func: TNativeFunction);
    procedure SetVariable(const Name: string; const Value: TJSValue);
    function GetVariable(const Name: string): TJSValue;

    procedure SetNumber(const Name: string; const Value: Double);
    procedure SetString(const Name: string; const Value: string);
    procedure SetBoolean(const Name: string; const Value: Boolean);

    function GetNumber(const Name: string): Double;
    function GetString(const Name: string): string;
    function GetBoolean(const Name: string): Boolean;

    property OnConsoleOutput: TConsoleOutputHandler read FOnConsoleOutput write FOnConsoleOutput;
    property StepBudget: Int64 read GetStepBudget write SetStepBudget;
    property StepCount: Int64 read GetStepCount;
    property MaxCallDepth: Integer read GetMaxCallDepth write SetMaxCallDepth;
    property MaxStringLength: Integer read GetMaxStringLength write SetMaxStringLength;
    property MaxArrayLength: Integer read GetMaxArrayLength write SetMaxArrayLength;
  end;

implementation

const
  CONSOLE_LOG = 'log';
  CONSOLE_ERROR = 'error';
  CONSOLE_WARN = 'warn';
  CONSOLE_INFO = 'info';
  MATH_PI = 'PI';
  MATH_E = 'E';
  MATH_LN2 = 'LN2';
  MATH_LN10 = 'LN10';
  MATH_LOG2E = 'LOG2E';
  MATH_LOG10E = 'LOG10E';
  MATH_SQRT2 = 'SQRT2';
  MATH_SQRT1_2 = 'SQRT1_2';
  MATH_ABS = 'abs';
  MATH_FLOOR = 'floor';
  MATH_CEIL = 'ceil';
  MATH_ROUND = 'round';
  MATH_SQRT = 'sqrt';
  MATH_POW = 'pow';
  MATH_MIN = 'min';
  MATH_MAX = 'max';
  MATH_RANDOM = 'random';
  MATH_SIN = 'sin';
  MATH_COS = 'cos';
  MATH_TAN = 'tan';
  MATH_ASIN = 'asin';
  MATH_ACOS = 'acos';
  MATH_ATAN = 'atan';
  MATH_ATAN2 = 'atan2';
  MATH_EXP = 'exp';
  MATH_LOG = 'log';
  MATH_TRUNC = 'trunc';
  MATH_SIGN = 'sign';
  CONSOLE_NAME = 'console';
  MATH_NAME = 'Math';
  OBJECT_NAME = 'Object';
  REGEXP_NAME = 'RegExp';
  SOURCE_PROPERTY = 'source';
  FROM_CODE_POINT_NAME = 'fromCodePoint';
  INVALID_CODE_POINT = 'Invalid code point %s';
  MAX_CODE_POINT = $10FFFF;
  FIRST_SUPPLEMENTARY_CODE_POINT = $10000;
  HIGH_SURROGATE_BASE = $D800;
  LOW_SURROGATE_BASE = $DC00;
  FLAGS_PROPERTY = 'flags';
  FUNCTION_NAME = 'Function';
  ANONYMOUS_NAME = '';
  PROTOTYPE_PROPERTY = 'prototype';
  CONSTRUCTOR_PROPERTY = 'constructor';
  LENGTH_PROPERTY = 'length';
  RAW_PROPERTY = 'raw';
  NULL_OR_UNDEFINED_TO_OBJECT = 'Cannot convert undefined or null to object';
  CANNOT_ASSIGN_READ_ONLY = 'Cannot assign to read only property ''%s''';
  FUNCTION_CALL = 'call';
  FUNCTION_APPLY = 'apply';
  FUNCTION_BIND = 'bind';
  FUNCTION_CALLER = 'caller';
  FUNCTION_ARGUMENTS = 'arguments';
  FUNCTION_SOURCE_FORMAT = '(function (%s' + sLineBreak + ') {' + sLineBreak + '%s' + sLineBreak + '})';
  FUNCTION_TEXT_FORMAT = 'function anonymous(%s'#10') {'#10'%s'#10'}';
  DYNAMIC_FUNCTION_NAME = 'anonymous';
  NOT_CALLED_ON_FUNCTION = 'Function.prototype.%s called on a value that is not a function';
  NOT_CALLED_ON_ARRAY = 'Array.prototype.%s called on a value that is not an array';
  NOT_CALLED_ON_OBJECT = 'Object.prototype.%s called on undefined or null';
  JSON_NAME = 'JSON';
  ARRAY_NAME = 'Array';
  NUMBER_NAME = 'Number';
  STRING_FUNC_NAME = 'String';
  BOOLEAN_FUNC_NAME = 'Boolean';
  PARSE_INT_NAME = 'parseInt';
  PARSE_FLOAT_NAME = 'parseFloat';
  IS_NAN_NAME = 'isNaN';
  IS_FINITE_NAME = 'isFinite';
  ENCODE_URI_NAME = 'encodeURI';
  DECODE_URI_NAME = 'decodeURI';
  ENCODE_URI_COMPONENT_NAME = 'encodeURIComponent';
  DECODE_URI_COMPONENT_NAME = 'decodeURIComponent';
  NAN_NAME = 'NaN';
  INFINITY_NAME = 'Infinity';
  UNDEFINED_NAME = 'undefined';
  OBJECT_KEYS = 'keys';
  OBJECT_VALUES = 'values';
  OBJECT_ENTRIES = 'entries';
  OBJECT_ASSIGN = 'assign';
  OBJECT_FREEZE = 'freeze';
  OBJECT_IS_FROZEN = 'isFrozen';
  OBJECT_SEAL = 'seal';
  OBJECT_IS_SEALED = 'isSealed';
  OBJECT_PREVENT_EXTENSIONS = 'preventExtensions';
  OBJECT_IS_EXTENSIBLE = 'isExtensible';
  OBJECT_GET_PROTOTYPE_OF = 'getPrototypeOf';
  OBJECT_GET_OWN_PROPERTY_NAMES = 'getOwnPropertyNames';
  OBJECT_GET_OWN_PROPERTY_SYMBOLS = 'getOwnPropertySymbols';
  OBJECT_GET_OWN_PROPERTY_DESCRIPTOR = 'getOwnPropertyDescriptor';
  OBJECT_GET_OWN_PROPERTY_DESCRIPTORS = 'getOwnPropertyDescriptors';
  OBJECT_IS = 'is';
  GLOBAL_THIS_NAME = 'globalThis';
  OBJECT_DEFINE_PROPERTY = 'defineProperty';
  OBJECT_DEFINE_PROPERTIES = 'defineProperties';
  OBJECT_CREATE = 'create';
  OBJECT_HAS_OWN_PROPERTY = 'hasOwnProperty';
  JSON_PARSE = 'parse';
  INVALID_JSON_TEXT = 'Unexpected token in JSON';
  JSON_STRINGIFY = 'stringify';
  ARRAY_IS_ARRAY = 'isArray';
  ARRAY_TO_LOCALE_STRING = 'toLocaleString';
  ARRAY_FROM = 'from';
  ARRAY_OF = 'of';
  ARRAY_KEYS = 'keys';
  ARRAY_VALUES = 'values';
  ARRAY_ENTRIES = 'entries';
  ITERATOR_NEXT = 'next';
  ITERATOR_NOT_AN_ARRAY_ITERATOR = 'next method called on an object that is not an array iterator';
  DATE_NAME = 'Date';
  ERROR_NAME = 'Error';
  TYPE_ERROR_NAME = 'TypeError';
  RANGE_ERROR_NAME = 'RangeError';
  REFERENCE_ERROR_NAME = 'ReferenceError';
  SYNTAX_ERROR_NAME = 'SyntaxError';
  URI_ERROR_NAME = 'URIError';
  EVAL_ERROR_NAME = 'EvalError';
  ERROR_MESSAGE = 'message';
  ERROR_NAME_PROP = 'name';
  ERROR_STACK = 'stack';
  ERROR_TO_STRING = 'toString';
  OBJECT_METHOD_CALLED_ON_NON_OBJECT = 'Object method called on a value that is not an object';
  OBJECT_PROTOTYPE_MUST_BE_OBJECT_OR_NULL = 'Object prototype may only be an Object or null';

{ TJSEngine }

constructor TJSEngine.Create;
begin
  inherited Create;
  FInterpreter := TJSInterpreter.Create;
  FPrototypeMethods := TJSPrototypeMethods.Create(FInterpreter);
  FPrograms := TList<TJSProgram>.Create;
  FOnConsoleOutput := nil;
  FInterpreter.RegisterEval(ParseProgram);
  RegisterBuiltInFunctions;
end;

destructor TJSEngine.Destroy;
begin
  FOnConsoleOutput := nil;

  for var Program_ in FPrograms do
    Program_.Free;

  FPrograms.Free;

  if Assigned(FCollectionBuiltins) then
    FCollectionBuiltins.ReleaseCollections;

  FInterpreter.Free;
  FPrototypeMethods.Free;
  FDateBuiltins.Free;
  FIteratorBuiltins.Free;
  FReflectBuiltins.Free;
  FProxyBuiltins.Free;
  FBinaryBuiltins.Free;
  FCollectionBuiltins.Free;
  FRegExpProtocol.Free;
  FObjectBuiltins.Free;
  FStringPatternMethods.Free;
  FSymbolBuiltins.Free;
  FArrayIteratorPrototype := nil;
  inherited;
end;

function TJSEngine.ParseProgram(const Source: string; const IsStrictContext: Boolean): TJSProgram;
begin
  const Parser = TJSParser.Create(Source);
  try
    Result := Parser.Parse(IsStrictContext);
    FPrograms.Add(Result);
  finally
    Parser.Free;
  end;
end;

function TJSEngine.Execute(const Source: string): TJSValue;
begin
  Result := FInterpreter.Execute(ParseProgram(Source, False));
end;

procedure TJSEngine.CollectGarbage;
begin
  FInterpreter.CollectGarbage;

  const LiveSet = TDictionary<TObject, Byte>.Create;
  try
    for var LiveProgram in FInterpreter.LivePrograms do
      LiveSet.AddOrSetValue(LiveProgram, 0);

    for var Index := FPrograms.Count - 1 downto 0 do
    begin
      const Program_ = FPrograms[Index];
      if not LiveSet.ContainsKey(Program_) then
      begin
        Program_.Free;
        FPrograms.Delete(Index);
      end;
    end;
  finally
    LiveSet.Free;
  end;
end;

function TJSEngine.Evaluate(const Expression: string): TJSValue;
begin
  Result := Execute(Expression);
end;

procedure TJSEngine.Cancel;
begin
  FInterpreter.Cancel;
end;

class function TJSEngine.ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
begin
  if Index < Length(Args) then
    Result := Args[Index]
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSEngine.ToText(const Value: TJSValue): string;
begin
  const IsArray = (Value.ValueType = TJSValueType.Array_);
  if IsArray then
  begin
    Result := Value.ToLimitedString(FInterpreter.Limits);
    Exit;
  end;

  const Primitive = Value.ToPrimitive(True);
  Result := Primitive.ToLimitedString(FInterpreter.Limits);
end;

function TJSEngine.ToKeyText(const Value: TJSValue): string;
begin
  Result := Value.ToPropertyKey(FInterpreter.Limits);
end;

function TJSEngine.GetStepBudget: Int64;
begin
  Result := FInterpreter.StepBudget;
end;

procedure TJSEngine.SetStepBudget(const Value: Int64);
begin
  FInterpreter.StepBudget := Value;
end;

function TJSEngine.GetStepCount: Int64;
begin
  Result := FInterpreter.StepCount;
end;

function TJSEngine.GetMaxCallDepth: Integer;
begin
  Result := FInterpreter.MaxCallDepth;
end;

procedure TJSEngine.SetMaxCallDepth(const Value: Integer);
begin
  FInterpreter.MaxCallDepth := Value;
end;

function TJSEngine.GetMaxStringLength: Integer;
begin
  Result := FInterpreter.MaxStringLength;
end;

procedure TJSEngine.SetMaxStringLength(const Value: Integer);
begin
  FInterpreter.MaxStringLength := Value;
end;

function TJSEngine.GetMaxArrayLength: Integer;
begin
  Result := FInterpreter.MaxArrayLength;
end;

procedure TJSEngine.SetMaxArrayLength(const Value: Integer);
begin
  FInterpreter.MaxArrayLength := Value;
end;

procedure TJSEngine.RegisterFunction(const Name: string; const Func: TNativeFunction);
begin
  FInterpreter.RegisterNativeFunction(Name, Func);
end;

procedure TJSEngine.SetVariable(const Name: string; const Value: TJSValue);
begin
  FInterpreter.SetGlobalVariable(Name, Value);
end;

function TJSEngine.GetVariable(const Name: string): TJSValue;
begin
  Result := FInterpreter.GetGlobalVariable(Name);
end;

procedure TJSEngine.SetNumber(const Name: string; const Value: Double);
begin
  SetVariable(Name, TJSValue.CreateNumber(Value));
end;

procedure TJSEngine.SetString(const Name: string; const Value: string);
begin
  SetVariable(Name, TJSValue.CreateString(Value));
end;

procedure TJSEngine.SetBoolean(const Name: string; const Value: Boolean);
begin
  SetVariable(Name, TJSValue.CreateBoolean(Value));
end;

function TJSEngine.GetNumber(const Name: string): Double;
begin
  Result := GetVariable(Name).ToNumber;
end;

function TJSEngine.GetString(const Name: string): string;
begin
  Result := GetVariable(Name).ToString;
end;

function TJSEngine.GetBoolean(const Name: string): Boolean;
begin
  Result := GetVariable(Name).ToBoolean;
end;

procedure TJSEngine.RegisterBuiltInFunctions;
begin
  FInterpreter.SetGlobalConstant(NAN_NAME, TJSValue.CreateNaN);
  FInterpreter.SetGlobalConstant(INFINITY_NAME, TJSValue.CreateInfinity);
  FInterpreter.SetGlobalConstant(UNDEFINED_NAME, TJSValue.CreateUndefined);

  FInterpreter.RegisterNativeFunction(PARSE_INT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Text = ToText(ArgumentAt(Args, 0));
      const Radix = TJSOperators.ToInt32(ArgumentAt(Args, 1));

      Result := TJSValue.CreateNumber(TJSNumberParse.ParseInt(Text, Radix));
    end);

  FInterpreter.RegisterNativeFunction(PARSE_FLOAT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Text = ToText(ArgumentAt(Args, 0));

      Result := TJSValue.CreateNumber(TJSNumberParse.ParseFloat(Text));
    end);

  FInterpreter.RegisterNativeFunction(IS_NAN_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Num = TJSOperators.ToNumber(ArgumentAt(Args, 0));

      Result := TJSValue.CreateBoolean(System.Math.IsNaN(Num));
    end);

  FInterpreter.RegisterNativeFunction(IS_FINITE_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Num = TJSOperators.ToNumber(ArgumentAt(Args, 0));
      const IsFiniteNumber = (not System.Math.IsNaN(Num)) and (not System.Math.IsInfinite(Num));

      Result := TJSValue.CreateBoolean(IsFiniteNumber);
    end);
  const NumberPrototype: IJSObject = TJSPrimitiveWrapper.Create(TJSValue.CreateNumber(0));

  const NumberFunc = TJSFunction.CreateNative(NUMBER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var NumberValue := TJSValue.CreateNumber(0);

      if Length(Args) > 0 then
        NumberValue := TJSValue.CreateNumber(TJSOperators.ToNumber(Args[0]));

      if TJSPrototypeMethods.IsConstructCall(This, NumberPrototype) then
      begin
        const Wrapper = FInterpreter.WrapPrimitive(NumberValue);
        Exit(TJSValue.CreateObject(Wrapper));
      end;

      Result := NumberValue;
    end);

  FInterpreter.SetGlobalVariable(NUMBER_NAME, TJSValue.CreateObject(NumberFunc));

  DefineConstant(NumberFunc, 'MAX_VALUE', TJSValue.CreateNumber(1.7976931348623157e+308));
  DefineConstant(NumberFunc, 'MIN_VALUE', TJSValue.CreateNumber(5e-324));
  DefineConstant(NumberFunc, 'NaN', TJSValue.CreateNaN);
  DefineConstant(NumberFunc, 'POSITIVE_INFINITY', TJSValue.CreateInfinity(False));
  DefineConstant(NumberFunc, 'NEGATIVE_INFINITY', TJSValue.CreateInfinity(True));
  TJSNumericBuiltins.RegisterNumber(NumberFunc,
                                    FInterpreter.GetGlobalVariable(PARSE_INT_NAME),
                                    FInterpreter.GetGlobalVariable(PARSE_FLOAT_NAME));

  AttachPrototypeObject(NumberFunc, NumberPrototype);

  const StringPrototype: IJSObject = TJSPrimitiveWrapper.Create(TJSValue.CreateString(''));

  const StringFunc = TJSFunction.CreateNative(STRING_FUNC_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var StringValue := TJSValue.CreateString('');

      const IsSymbolConversion = (Length(Args) > 0) and Args[0].IsSymbol and
                                 (not TJSPrototypeMethods.IsConstructCall(This, StringPrototype));
      if IsSymbolConversion then
        Exit(TJSValue.CreateString(Args[0].SymbolDescriptiveString));

      if Length(Args) > 0 then
        StringValue := TJSValue.CreateString(ToText(Args[0]));

      if TJSPrototypeMethods.IsConstructCall(This, StringPrototype) then
      begin
        const Wrapper = FInterpreter.WrapPrimitive(StringValue);
        Exit(TJSValue.CreateObject(Wrapper));
      end;

      Result := StringValue;
    end);

  StringFunc.SetProperty('fromCharCode', TJSValue.CreateObject(TJSFunction.CreateNative('fromCharCode',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var OutputChars := '';

      for var Arg in Args do
      begin
        const CharCode = Trunc(Arg.ToNumber) and $FFFF;
        OutputChars := OutputChars + Char(CharCode);
      end;

      Result := TJSValue.CreateString(OutputChars);
    end)));

  RegisterStringRaw(StringFunc);
  RegisterStringFromCodePoint(StringFunc);

  FInterpreter.SetGlobalVariable(STRING_FUNC_NAME, TJSValue.CreateObject(StringFunc));
  AttachPrototypeObject(StringFunc, StringPrototype);

  const BooleanPrototype: IJSObject = TJSPrimitiveWrapper.Create(TJSValue.CreateBoolean(False));

  const BooleanFunc = TJSFunction.CreateNative(BOOLEAN_FUNC_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const BooleanValue = TJSValue.CreateBoolean((Length(Args) > 0) and Args[0].ToBoolean);

      if TJSPrototypeMethods.IsConstructCall(This, BooleanPrototype) then
      begin
        const Wrapper = FInterpreter.WrapPrimitive(BooleanValue);
        Exit(TJSValue.CreateObject(Wrapper));
      end;

      Result := BooleanValue;
    end);

  FInterpreter.SetGlobalVariable(BOOLEAN_FUNC_NAME, TJSValue.CreateObject(BooleanFunc));
  AttachPrototypeObject(BooleanFunc, BooleanPrototype);

  RegisterUriFunction(ENCODE_URI_NAME, TJSUriCoding.EncodeURI);
  RegisterUriFunction(DECODE_URI_NAME, TJSUriCoding.DecodeURI);
  RegisterUriFunction(ENCODE_URI_COMPONENT_NAME, TJSUriCoding.EncodeURIComponent);
  RegisterUriFunction(DECODE_URI_COMPONENT_NAME, TJSUriCoding.DecodeURIComponent);

  DefineHiddenProperty(FInterpreter.GlobalObject, GLOBAL_THIS_NAME,
                       TJSValue.CreateObject(FInterpreter.GlobalObject));

  RegisterConsole;
  RegisterMath;
  RegisterObject;
  RegisterJSON;
  RegisterArray;
  RegisterDate;
  RegisterErrors;
  RegisterRegExp;
  RegisterFunctionObject;
  RegisterPrototypeMethods;
  LinkIntrinsicPrototypes;

  FRegExpProtocol := TJSRegExpProtocol.Create(FInterpreter);
  FRegExpProtocol.Register;

  FStringPatternMethods := TJSStringPatternMethods.Create(FInterpreter);
  FStringPatternMethods.Register;

  FObjectBuiltins := TJSObjectBuiltins.Create(FInterpreter);
  FObjectBuiltins.Register;

  ApplyBuiltinAttributes;

  FSymbolBuiltins := TJSSymbolBuiltins.Create(FInterpreter);
  FSymbolBuiltins.Register;

  FIteratorBuiltins := TJSIteratorBuiltins.Create(FInterpreter, FArrayIteratorPrototype);
  FIteratorBuiltins.Register;

  FCollectionBuiltins := TJSCollectionBuiltins.Create(FInterpreter);
  FCollectionBuiltins.Register;

  FProxyBuiltins := TJSProxyBuiltins.Create(FInterpreter);
  FProxyBuiltins.Register;

  FReflectBuiltins := TJSReflectBuiltins.Create(FInterpreter);
  FReflectBuiltins.Register;

  FBinaryBuiltins := TJSBinaryBuiltins.Create(FInterpreter);
  FBinaryBuiltins.Register;

  AssignMissingFunctionPrototypes;
end;

function TJSEngine.CodePointsToString(const Args: TArray<TJSValue>): string;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Arg in Args do
    begin
      const Number = TJSConversions.ToNumber(Arg);

      const IsInteger = (not System.Math.IsNaN(Number)) and (not System.Math.IsInfinite(Number)) and
                        (Number = Int(Number));
      const IsValidCodePoint = IsInteger and (Number >= 0) and (Number <= MAX_CODE_POINT);
      if not IsValidCodePoint then
        raise TJSErrorFactory.RangeError(Format(INVALID_CODE_POINT, [Arg.ToString]));

      const CodePoint = Trunc(Number);
      if CodePoint < FIRST_SUPPLEMENTARY_CODE_POINT then
      begin
        Builder.Append(Char(CodePoint));
        Continue;
      end;

      const Offset = CodePoint - FIRST_SUPPLEMENTARY_CODE_POINT;
      Builder.Append(Char(HIGH_SURROGATE_BASE + (Offset shr 10)));
      Builder.Append(Char(LOW_SURROGATE_BASE + (Offset and $3FF)));
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

procedure TJSEngine.RegisterStringFromCodePoint(const StringFunc: IJSFunction);
begin
  StringFunc.SetProperty(FROM_CODE_POINT_NAME, TJSValue.CreateObject(TJSFunction.CreateNative(FROM_CODE_POINT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateString(CodePointsToString(Args));
    end)));
end;

procedure TJSEngine.RegisterStringRaw(const StringFunc: IJSFunction);
begin
  const RawFunc = TJSFunction.CreateNative(RAW_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateString(ConcatenateRawStrings(Args));
    end);

  RawFunc.IsConstructor := False;
  FInterpreter.RegisterFunction(RawFunc);
  StringFunc.SetProperty(RAW_PROPERTY, TJSValue.CreateObject(RawFunc));
end;

function TJSEngine.ConcatenateRawStrings(const Args: TArray<TJSValue>): string;
begin
  const Cooked = CoerceToObject(ArgumentAt(Args, 0));
  const Raw = CoerceToObject(Cooked.GetProperty(RAW_PROPERTY));
  const SegmentCount = TJSArrayLike.ToLength(Raw);

  Result := '';

  for var Index: Int64 := 0 to SegmentCount - 1 do
  begin
    const SegmentName = TJSArrayLike.IndexName(Index);
    const Segment = Raw.GetProperty(SegmentName);
    Result := Result + ToText(Segment);

    const IsLastSegment = (Index = SegmentCount - 1);
    const HasSubstitution = (Index + 1 < Length(Args));
    if (not IsLastSegment) and HasSubstitution then
      Result := Result + ToText(Args[Index + 1]);
  end;
end;

function TJSEngine.CoerceToObject(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_OR_UNDEFINED_TO_OBJECT);

  if Value.IsObject then
    Exit(Value.ToObject);

  Result := FInterpreter.WrapPrimitive(Value);
end;

class function TJSEngine.IsEnumerableOwn(const Source: IJSObject; const Name: string): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := TJSObjectOperations.TryGetOwnProperty(Source, Name, Descriptor) and Descriptor.Enumerable;
end;

class procedure TJSEngine.PutChecked(const Target: IJSObject; const Name: string; const Value: TJSValue);
begin
  if not TJSPropertyDescriptors.CanPut(Target, Name) then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_READ_ONLY, [Name]));

  Target.SetProperty(Name, Value);
end;

procedure TJSEngine.CopyEnumerableOwn(const Source: IJSObject; const Target: IJSObject);
begin
  for var PropName in TJSObjectKeys.All(Source) do
  begin
    if IsEnumerableOwn(Source, PropName) then
      PutChecked(Target, PropName, Source.GetProperty(PropName));
  end;
end;

procedure TJSEngine.RegisterUriFunction(const Name: string; const Transform: TUriTransform);
begin
  const UriFunction = TJSFunction.CreateNative(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Argument := TJSValue.CreateUndefined;
      if Length(Args) > 0 then
        Argument := Args[0];

      const Text = ToText(Argument);
      const Transformed = Transform(Text);
      Result := TJSValue.CreateString(Transformed);
    end);

  UriFunction.IsConstructor := False;
  FInterpreter.RegisterFunction(UriFunction);
  FInterpreter.SetGlobalVariable(Name, TJSValue.CreateObject(UriFunction));
end;
procedure TJSEngine.ApplyBuiltinAttributes;
begin
  const Attributes = TJSBuiltinAttributes.Create(FInterpreter);
  try
    Attributes.Apply;
  finally
    Attributes.Free;
  end;
end;

procedure TJSEngine.RegisterConsole;
begin
  const ConsoleObj = TJSObject.Create;
  const Engine = Self;

  const LogFunc = TJSFunction.CreateNative(CONSOLE_LOG,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Output := '';

      for var Index := 0 to Length(Args) - 1 do
      begin
        if Index > 0 then
          Output := Output + ' ';

        if Args[Index].IsSymbol then
          Output := Output + Args[Index].SymbolDescriptiveString
        else
          Output := Output + ToText(Args[Index]);
      end;

      if Assigned(Engine.FOnConsoleOutput) then
        Engine.FOnConsoleOutput(Output)
      else
        WriteLn(Output);

      Result := TJSValue.CreateUndefined;
    end);

  ConsoleObj.SetProperty(CONSOLE_LOG, TJSValue.CreateObject(LogFunc));
  ConsoleObj.SetProperty(CONSOLE_ERROR, TJSValue.CreateObject(LogFunc));
  ConsoleObj.SetProperty(CONSOLE_WARN, TJSValue.CreateObject(LogFunc));
  ConsoleObj.SetProperty(CONSOLE_INFO, TJSValue.CreateObject(LogFunc));

  FInterpreter.SetGlobalVariable(CONSOLE_NAME, TJSValue.CreateObject(ConsoleObj));
end;

procedure TJSEngine.RegisterMath;
begin
  const MathObj: IJSObject = TJSObject.Create;

  DefineConstant(MathObj, MATH_PI, TJSValue.CreateNumber(Pi));
  DefineConstant(MathObj, MATH_E, TJSValue.CreateNumber(Exp(1)));
  DefineConstant(MathObj, MATH_LN2, TJSValue.CreateNumber(Ln(2)));
  DefineConstant(MathObj, MATH_LN10, TJSValue.CreateNumber(Ln(10)));
  DefineConstant(MathObj, MATH_LOG2E, TJSValue.CreateNumber(1 / Ln(2)));
  DefineConstant(MathObj, MATH_LOG10E, TJSValue.CreateNumber(1 / Ln(10)));
  DefineConstant(MathObj, MATH_SQRT2, TJSValue.CreateNumber(Sqrt(2)));
  DefineConstant(MathObj, MATH_SQRT1_2, TJSValue.CreateNumber(Sqrt(0.5)));

  MathObj.SetProperty(MATH_ABS, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ABS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Abs(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_FLOOR, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_FLOOR,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Floor(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_CEIL, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_CEIL,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Ceil(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_ROUND, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ROUND,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Round(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_SQRT, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_SQRT,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Num = Args[0].ToNumber;

      if Num < 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Sqrt(Num));
    end)));

  MathObj.SetProperty(MATH_POW, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_POW,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) < 2 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Power(Args[0].ToNumber, Args[1].ToNumber));
    end)));

  MathObj.SetProperty(MATH_MIN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_MIN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateInfinity(False);
        Exit;
      end;

      var MinValue := Args[0].ToNumber;

      for var Index := 1 to Length(Args) - 1 do
      begin
        const Value = Args[Index].ToNumber;

        if System.Math.IsNaN(Value) then
        begin
          Result := TJSValue.CreateNaN;
          Exit;
        end;

        MinValue := TJSMathFunctions.Smaller(MinValue, Value);
      end;

      Result := TJSValue.CreateNumber(MinValue);
    end)));

  MathObj.SetProperty(MATH_MAX, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_MAX,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateInfinity(True);
        Exit;
      end;

      var MaxValue := Args[0].ToNumber;

      for var Index := 1 to Length(Args) - 1 do
      begin
        const Value = Args[Index].ToNumber;

        if System.Math.IsNaN(Value) then
        begin
          Result := TJSValue.CreateNaN;
          Exit;
        end;

        MaxValue := TJSMathFunctions.Larger(MaxValue, Value);
      end;

      Result := TJSValue.CreateNumber(MaxValue);
    end)));

  MathObj.SetProperty(MATH_RANDOM, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_RANDOM,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateNumber(Random);
    end)));

  MathObj.SetProperty(MATH_SIN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_SIN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Sin(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_COS, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_COS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Cos(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_TAN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_TAN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Tan(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_ASIN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ASIN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Num = Args[0].ToNumber;

      if (Num < -1) or (Num > 1) then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(ArcSin(Num));
    end)));

  MathObj.SetProperty(MATH_ACOS, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ACOS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Num = Args[0].ToNumber;

      if (Num < -1) or (Num > 1) then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(ArcCos(Num));
    end)));

  MathObj.SetProperty(MATH_ATAN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ATAN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(ArcTan(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_ATAN2, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ATAN2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) < 2 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(ArcTan2(Args[0].ToNumber, Args[1].ToNumber));
    end)));

  MathObj.SetProperty(MATH_EXP, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_EXP,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Exp(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_LOG, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_LOG,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Num = Args[0].ToNumber;

      if Num <= 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Ln(Num));
    end)));

  MathObj.SetProperty(MATH_TRUNC, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_TRUNC,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Trunc(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_SIGN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_SIGN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(TJSMathFunctions.Sign(Args[0].ToNumber));
    end)));

  TJSNumericBuiltins.RegisterMath(MathObj);

  FInterpreter.SetGlobalVariable(MATH_NAME, TJSValue.CreateObject(MathObj));
end;

procedure TJSEngine.RegisterObject;
begin
  const PrototypeObj = TJSObject.Create;

  const ObjectObj = TJSFunction.CreateNative(OBJECT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructObject(Args, PrototypeObj);
    end);

  ObjectObj.SetProperty(OBJECT_KEYS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_KEYS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const ResultArr: IJSArray = TJSArray.Create;

      for var PropName in Obj.GetOwnPropertyNames do
      begin
        if IsEnumerableOwn(Obj, PropName) then
          ResultArr.Push(TJSValue.CreateString(PropName));
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_VALUES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_VALUES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const ResultArr: IJSArray = TJSArray.Create;

      for var PropName in Obj.GetOwnPropertyNames do
      begin
        if IsEnumerableOwn(Obj, PropName) then
          ResultArr.Push(Obj.GetProperty(PropName));
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_ENTRIES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_ENTRIES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const ResultArr: IJSArray = TJSArray.Create;

      for var PropName in Obj.GetOwnPropertyNames do
      begin
        if IsEnumerableOwn(Obj, PropName) then
        begin
          const EntryArr: IJSArray = TJSArray.Create;
          EntryArr.Prototype := FInterpreter.ArrayPrototype;
          EntryArr.Push(TJSValue.CreateString(PropName));
          EntryArr.Push(Obj.GetProperty(PropName));
          ResultArr.Push(TJSValue.CreateObject(EntryArr));
        end;
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_ASSIGN, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_ASSIGN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = CoerceToObject(ArgumentAt(Args, 0));

      for var Index := 1 to Length(Args) - 1 do
      begin
        if not Args[Index].IsNullOrUndefined then
          CopyEnumerableOwn(CoerceToObject(Args[Index]), Target);
      end;

      Result := TJSValue.CreateObject(Target);
    end)));

  ObjectObj.SetProperty(OBJECT_CREATE, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_CREATE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasPrototypeArg = (Length(Args) > 0) and (Args[0].IsObject or Args[0].IsNull);
      if not HasPrototypeArg then
        raise TJSErrorFactory.TypeError(OBJECT_PROTOTYPE_MUST_BE_OBJECT_OR_NULL);

      const NewObj = TJSObject.Create;

      if Args[0].IsObject then
        NewObj.Prototype := Args[0].ToObject;

      const HasProperties = (Length(Args) > 1) and (not Args[1].IsUndefined);
      if HasProperties then
        TJSPropertyDescriptors.DefineAll(NewObj, Args[1], FInterpreter.Limits);

      Result := TJSValue.CreateObject(NewObj);
    end)));

  ObjectObj.SetProperty(OBJECT_DEFINE_PROPERTIES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_DEFINE_PROPERTIES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasTarget = (Length(Args) > 0) and Args[0].IsObject;
      if not HasTarget then
        raise TJSErrorFactory.TypeError(OBJECT_METHOD_CALLED_ON_NON_OBJECT);

      var Properties := TJSValue.CreateUndefined;
      if Length(Args) > 1 then
        Properties := Args[1];

      TJSPropertyDescriptors.DefineAll(Args[0].ToObject, Properties, FInterpreter.Limits);

      Result := Args[0];
    end)));

  ObjectObj.SetProperty(OBJECT_GET_PROTOTYPE_OF, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_PROTOTYPE_OF,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const Proto = Obj.Prototype;

      if Proto = nil then
        Result := TJSValue.CreateNull
      else
        Result := TJSValue.CreateObject(Proto);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_OWN_PROPERTY_NAMES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_OWN_PROPERTY_NAMES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const ResultArr: IJSArray = TJSArray.Create;

      for var PropName in Obj.GetOwnPropertyNames do
        ResultArr.Push(TJSValue.CreateString(PropName));

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_OWN_PROPERTY_SYMBOLS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_OWN_PROPERTY_SYMBOLS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));
      const ResultArr: IJSArray = TJSArray.Create;

      for var SymbolKey in Obj.GetOwnSymbolKeys do
      begin
        const Found: IJSSymbol = TJSSymbolImpl(TJSSymbolRegistry.Find(SymbolKey));
        const SymbolValue = TJSValue.CreateSymbol(Found);
        ResultArr.Push(SymbolValue);
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_FREEZE, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_FREEZE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = ArgumentAt(Args, 0);
      if not Target.IsObject then
        Exit(Target);

      Target.ToObject.Freeze;
      Result := Target;
    end)));

  ObjectObj.SetProperty(OBJECT_IS_FROZEN, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_IS_FROZEN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateBoolean(True);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(Args[0].ToObject.IsFrozen);
    end)));

  ObjectObj.SetProperty(OBJECT_SEAL, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_SEAL,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = ArgumentAt(Args, 0);
      if not Target.IsObject then
        Exit(Target);

      Target.ToObject.Seal;
      Result := Target;
    end)));

  ObjectObj.SetProperty(OBJECT_IS_SEALED, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_IS_SEALED,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateBoolean(True);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(Args[0].ToObject.IsSealed);
    end)));

  ObjectObj.SetProperty(OBJECT_PREVENT_EXTENSIONS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_PREVENT_EXTENSIONS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = ArgumentAt(Args, 0);
      if not Target.IsObject then
        Exit(Target);

      Target.ToObject.PreventExtensions;
      Result := Target;
    end)));

  ObjectObj.SetProperty(OBJECT_IS_EXTENSIBLE, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_IS_EXTENSIBLE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(Args[0].ToObject.IsExtensible);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_OWN_PROPERTY_DESCRIPTOR, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_OWN_PROPERTY_DESCRIPTOR,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Obj = CoerceToObject(ArgumentAt(Args, 0));

      var PropName := UNDEFINED_NAME;
      if Length(Args) > 1 then
        PropName := ToKeyText(Args[1]);

      var Descriptor: TJSPropertyDescriptor;
      if not TJSObjectOperations.TryGetOwnProperty(Obj, PropName, Descriptor) then
        Exit(TJSValue.CreateUndefined);

      const DescObj = TJSPropertyDescriptors.ToDescriptorObject(Descriptor, FInterpreter.ObjectPrototype);
      Result := TJSValue.CreateObject(DescObj);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_OWN_PROPERTY_DESCRIPTORS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_OWN_PROPERTY_DESCRIPTORS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = ArgumentAt(Args, 0);
      const Source = CoerceToObject(Target);

      const Descriptors = TJSObject.Create;
      Descriptors.Prototype := PrototypeObj;

      for var PropName in TJSObjectKeys.All(Source) do
      begin
        var Descriptor: TJSPropertyDescriptor;
        if not TJSObjectOperations.TryGetOwnProperty(Source, PropName, Descriptor) then
          Continue;

        const DescObj = TJSPropertyDescriptors.ToDescriptorObject(Descriptor, FInterpreter.ObjectPrototype);
        Descriptors.SetProperty(PropName, TJSValue.CreateObject(DescObj));
      end;

      Result := TJSValue.CreateObject(Descriptors);
    end)));

  ObjectObj.SetProperty(OBJECT_IS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_IS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Left = ArgumentAt(Args, 0);
      const Right = ArgumentAt(Args, 1);

      Result := TJSValue.CreateBoolean(Left.SameValue(Right));
    end)));

  ObjectObj.SetProperty(OBJECT_DEFINE_PROPERTY, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_DEFINE_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasTarget = (Length(Args) > 0) and Args[0].IsObject;
      if not HasTarget then
        raise TJSErrorFactory.TypeError(OBJECT_METHOD_CALLED_ON_NON_OBJECT);

      var PropName := UNDEFINED_NAME;
      var Description := TJSValue.CreateUndefined;
      if Length(Args) > 1 then
        PropName := ToKeyText(Args[1]);
      if Length(Args) > 2 then
        Description := Args[2];

      const Definition = TJSPropertyDescriptors.ToDefinition(Description);
      TJSPropertyDescriptors.Define(Args[0].ToObject, PropName, Definition, FInterpreter.Limits);

      Result := Args[0];
    end)));

  for var MethodName in TJSBuiltins.ObjectMethodNames do
  begin
    const Method = CreateObjectPrototypeMethod(MethodName);
    PrototypeObj.SetProperty(MethodName, TJSValue.CreateObject(Method));
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.ObjectMethod, MethodName, Method);
  end;

  AttachPrototypeObject(ObjectObj, PrototypeObj);

  FInterpreter.SetGlobalVariable(OBJECT_NAME, TJSValue.CreateObject(ObjectObj));
end;

procedure TJSEngine.RegisterJSON;
begin
  const JSONObj = TJSObject.Create;

  JSONObj.SetProperty(JSON_PARSE, TJSValue.CreateObject(TJSFunction.CreateNative(JSON_PARSE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const JSONString = ToText(ArgumentAt(Args, 0));

      const IsValidJSON = TJSJsonSyntax.IsValid(JSONString);
      if not IsValidJSON then
        raise TJSErrorFactory.SyntaxError(INVALID_JSON_TEXT);

      Result := TJSJsonReader.Read(JSONString, FInterpreter.ObjectPrototype, FInterpreter.ArrayPrototype);

      var Reviver: IJSFunction;
      const ReviverArgument = ArgumentAt(Args, 1);
      const HasReviver = (ReviverArgument.IsFunction and Supports(ReviverArgument.ToObject, IJSFunction, Reviver));
      if HasReviver then
        Result := TJSJsonReviver.Revive(Result, Reviver, FInterpreter.ObjectPrototype);
    end)));

  JSONObj.SetProperty(JSON_STRINGIFY, TJSValue.CreateObject(TJSFunction.CreateNative(JSON_STRINGIFY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Writer = TJSJsonWriter.Create(FInterpreter.Limits, FInterpreter.ObjectPrototype);
      try
        var JSONText: string;
        const HasText = Writer.TryStringify(ArgumentAt(Args, 0), ArgumentAt(Args, 1), ArgumentAt(Args, 2), JSONText);

        if HasText then
          Result := TJSValue.CreateString(JSONText)
        else
          Result := TJSValue.CreateUndefined;
      finally
        Writer.Free;
      end;
    end)));

  FInterpreter.SetGlobalVariable(JSON_NAME, TJSValue.CreateObject(JSONObj));
end;

procedure TJSEngine.RegisterArray;
begin
  const PrototypeObj: IJSObject = TJSArray.Create;

  const ArrayObj = TJSFunction.CreateNative(ARRAY_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructArray(Args, PrototypeObj);
    end);

  ArrayObj.SetProperty(ARRAY_IS_ARRAY, TJSValue.CreateObject(TJSFunction.CreateNative(ARRAY_IS_ARRAY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(TJSObjectOperations.IsArray(Args[0]));
    end)));

  for var StaticName in [ARRAY_OF, ARRAY_FROM] do
  begin
    const StaticMethod = CreateArrayStaticMethod(StaticName);
    ArrayObj.SetProperty(StaticName, TJSValue.CreateObject(StaticMethod));
  end;

  for var MethodName in TJSBuiltins.ArrayMethodNames do
  begin
    const Method = CreateArrayPrototypeMethod(MethodName);
    PrototypeObj.SetProperty(MethodName, TJSValue.CreateObject(Method));
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.ArrayMethod, MethodName, Method);
  end;

  const LocaleStringMethod = CreateArrayPrototypeMethod(ARRAY_TO_LOCALE_STRING);
  PrototypeObj.SetProperty(ARRAY_TO_LOCALE_STRING, TJSValue.CreateObject(LocaleStringMethod));

  RegisterArrayIterators(PrototypeObj);

  AttachPrototypeObject(ArrayObj, PrototypeObj);

  FInterpreter.SetGlobalVariable(ARRAY_NAME, TJSValue.CreateObject(ArrayObj));
end;

procedure TJSEngine.RegisterFunctionObject;
begin
  const FunctionObj = TJSFunction.CreateNative(FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateDynamicFunction(Args);
    end);

  const PrototypeObj: IJSFunction = TJSFunction.CreateNative(ANONYMOUS_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
    end);
  PrototypeObj.IsConstructor := False;
  TJSFunction.DefineLength(PrototypeObj, 0);
  FInterpreter.RegisterFunction(PrototypeObj);

  for var MethodName in [FUNCTION_CALL, FUNCTION_APPLY, FUNCTION_BIND] do
  begin
    const Method = CreateFunctionPrototypeMethod(MethodName);
    PrototypeObj.SetProperty(MethodName, TJSValue.CreateObject(Method));
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.FunctionMethod, MethodName, Method);
  end;

  AttachPrototypeObject(FunctionObj, PrototypeObj);

  FInterpreter.SetGlobalVariable(FUNCTION_NAME, TJSValue.CreateObject(FunctionObj));
end;

function TJSEngine.CreateDynamicFunction(const Args: TArray<TJSValue>): TJSValue;
begin
  var Body := '';
  var Parameters := '';

  const HasArguments = (Length(Args) > 0);
  if HasArguments then
  begin
    for var Index := 0 to High(Args) - 1 do
    begin
      if Index > 0 then
        Parameters := Parameters + ',';

      Parameters := Parameters + ToText(Args[Index]);
    end;

    Body := ToText(Args[High(Args)]);
  end;

  const ParsedSource = Format(FUNCTION_SOURCE_FORMAT, [Parameters, Body]);
  Result := FInterpreter.CreateFunctionFromSource(ParsedSource);

  var Func: IJSFunction;
  const IsFunction = Supports(Result.ToObject, IJSFunction, Func);
  if IsFunction then
  begin
    Func.Name := DYNAMIC_FUNCTION_NAME;
    Func.SourceText := Format(FUNCTION_TEXT_FORMAT, [Parameters, Body]);
  end;
end;

function TJSEngine.CreateFunctionPrototypeMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Target: IJSFunction;
      const IsFunction = Supports(This, IJSFunction, Target);
      if not IsFunction then
        raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_FUNCTION, [MethodName]));

      Result := FInterpreter.ExecuteFunctionMethod(Target, MethodName, Args);
    end);
end;

procedure TJSEngine.RegisterArrayIterators(const PrototypeObj: IJSObject);
begin
  const IteratorPrototype: IJSObject = TJSObject.Create;
  IteratorPrototype.Prototype := FInterpreter.ObjectPrototype;
  DefineHiddenProperty(IteratorPrototype, ITERATOR_NEXT, TJSValue.CreateObject(TJSFunction.CreateNative(ITERATOR_NEXT,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Iterator: IJSArrayIterator;
      if not Supports(This, IJSArrayIterator, Iterator) then
        raise TJSErrorFactory.TypeError(ITERATOR_NOT_AN_ARRAY_ITERATOR);

      Result := Iterator.NextResult;
    end)));
  FArrayIteratorPrototype := IteratorPrototype;

  const KeysMethod = CreateArrayIteratorFactory(ARRAY_KEYS, TJSArrayIteratorKind.Keys, IteratorPrototype);
  const ValuesMethod = CreateArrayIteratorFactory(ARRAY_VALUES, TJSArrayIteratorKind.Values, IteratorPrototype);
  const EntriesMethod = CreateArrayIteratorFactory(ARRAY_ENTRIES, TJSArrayIteratorKind.Entries, IteratorPrototype);

  PrototypeObj.SetProperty(ARRAY_KEYS, TJSValue.CreateObject(KeysMethod));
  PrototypeObj.SetProperty(ARRAY_VALUES, TJSValue.CreateObject(ValuesMethod));
  PrototypeObj.SetProperty(ARRAY_ENTRIES, TJSValue.CreateObject(EntriesMethod));
end;

function TJSEngine.CreateArrayStaticMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FInterpreter.ExecuteArrayStaticMethod(This, MethodName, Args);
    end);
end;

function TJSEngine.CreateArrayIteratorFactory(const MethodName: string; const Kind: TJSArrayIteratorKind;
                                              const IteratorPrototype: IJSObject): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if not Assigned(This) then
        raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_OBJECT, [MethodName]));

      const Iterator = TJSArrayIterator.Create(This, Kind, FInterpreter.ArrayPrototype, FInterpreter.ObjectPrototype);
      Iterator.Prototype := IteratorPrototype;
      Result := TJSValue.CreateObject(Iterator);
    end);
end;

function TJSEngine.CreateArrayPrototypeMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if MethodName = ARRAY_TO_LOCALE_STRING then
        Exit(FInterpreter.ExecuteGenericArrayMethod(This, MethodName, Args));

      if TJSArrayIteration.Handles(MethodName) then
        Exit(FInterpreter.ExecuteArrayIterationMethod(This, MethodName, Args));

      var Target: IJSArray;
      const IsArray = Supports(This, IJSArray, Target);
      if IsArray then
        Exit(FInterpreter.ExecuteArrayMethod(Target, MethodName, Args));

      if TJSArrayGeneric.Handles(MethodName) then
        Exit(FInterpreter.ExecuteGenericArrayMethod(This, MethodName, Args));

      raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_ARRAY, [MethodName]));
    end);
end;

function TJSEngine.CreateObjectPrototypeMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if not Assigned(This) then
      begin
        const TakesPropertyKey = TJSBuiltins.HasObjectMethod(MethodName) and (Length(Args) > 0);
        if TakesPropertyKey then
          ToKeyText(Args[0]);

        raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_OBJECT, [MethodName]));
      end;

      Result := TJSBuiltins.CallObjectMethod(This, MethodName, Args, FInterpreter.Limits);
    end);
end;

function TJSEngine.ConstructArray(const Args: TArray<TJSValue>; const PrototypeObj: IJSObject): TJSValue;
begin
  const ResultArr: IJSArray = TJSArray.Create;
  ResultArr.Prototype := PrototypeObj;

  const IsLengthForm = (Length(Args) = 1) and Args[0].IsNumber;
  if IsLengthForm then
  begin
    const RequestedLength = Args[0].AsNumber;
    if not IsValidArrayLength(RequestedLength) then
      raise TJSErrorFactory.InvalidArrayLength;

    const ElementCount = Trunc(RequestedLength);
    FInterpreter.Limits.EnsureArrayLength(ElementCount);

    var LengthDefinition := Default(TJSPropertyDefinition);
    LengthDefinition.HasValue := True;
    LengthDefinition.Value := TJSValue.CreateNumber(ElementCount);
    ResultArr.DefineOwnProperty(LENGTH_PROPERTY, LengthDefinition);
  end
  else
  begin
    for var Arg in Args do
      ResultArr.Push(Arg);
  end;

  Result := TJSValue.CreateObject(ResultArr);
end;

function TJSEngine.ConstructObject(const Args: TArray<TJSValue>; const PrototypeObj: IJSObject): TJSValue;
begin
  const HasObjectArgument = (Length(Args) > 0) and Args[0].IsObject;
  if HasObjectArgument then
    Exit(Args[0]);

  const HasPrimitiveArgument = (Length(Args) > 0) and (not Args[0].IsNullOrUndefined);
  if HasPrimitiveArgument then
  begin
    const Wrapper = FInterpreter.WrapPrimitive(Args[0]);
    Exit(TJSValue.CreateObject(Wrapper));
  end;

  const NewObj = TJSObject.Create;
  NewObj.Prototype := PrototypeObj;

  Result := TJSValue.CreateObject(NewObj);
end;

function TJSEngine.IsValidArrayLength(const Value: Double): Boolean;
const
  MAX_ARRAY_LENGTH = 4294967295.0;
begin
  const IsWholeNumber = (not System.Math.IsNaN(Value)) and (Frac(Value) = 0);

  Result := IsWholeNumber and (Value >= 0) and (Value <= MAX_ARRAY_LENGTH);
end;

procedure TJSEngine.RegisterDate;
begin
  const PrototypeObj: IJSObject = TJSObject.Create;

  FDateBuiltins := TJSDateBuiltins.Create(PrototypeObj);
  const DateFunc = FDateBuiltins.CreateConstructor;

  FInterpreter.SetGlobalVariable(DATE_NAME, TJSValue.CreateObject(DateFunc as IJSObject));
  AttachPrototypeObject(DateFunc, PrototypeObj);
end;

procedure TJSEngine.AttachPrototypeObject(const Constructor_: IJSFunction; const PrototypeObj: IJSObject);
begin
  var ConstructorDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Constructor_ as IJSObject));
  ConstructorDescriptor.Enumerable := False;
  PrototypeObj.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);

  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, TJSValue.CreateObject(PrototypeObj));
  FInterpreter.RegisterFunction(Constructor_);
end;

class procedure TJSEngine.DefineHiddenProperty(const Target: IJSObject; const Name: string;
                                               const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Enumerable := False;
  Target.DefineProperty(Name, Descriptor);
end;

class procedure TJSEngine.DefineConstant(const Target: IJSObject; const Name: string; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Name, Descriptor);
end;

function TJSEngine.ConstructError(const ErrorType: TJSErrorType; const PrototypeObj: IJSObject;
                                  const Args: TArray<TJSValue>): TJSValue;
begin
  const HasMessage = (Length(Args) > 0) and (not Args[0].IsUndefined);

  var MessageText := '';
  if HasMessage then
    MessageText := ToText(Args[0]);

  const ErrorObj: IJSError = TJSError.Create(ErrorType, MessageText);
  ErrorObj.Prototype := PrototypeObj;

  if HasMessage then
  begin
    const MessageValue = TJSValue.CreateString(MessageText);
    DefineHiddenProperty(ErrorObj, ERROR_MESSAGE, MessageValue);
  end;

  Result := TJSValue.CreateObject(ErrorObj);
end;

function TJSEngine.CreateErrorConstructor(const ErrorType: TJSErrorType; const ErrorName: string): TJSFunction;
begin
  const PrototypeObj: IJSObject = TJSObject.Create;
  const NameValue = TJSValue.CreateString(ErrorName);
  const EmptyMessage = TJSValue.CreateString('');
  DefineHiddenProperty(PrototypeObj, ERROR_NAME_PROP, NameValue);
  DefineHiddenProperty(PrototypeObj, ERROR_MESSAGE, EmptyMessage);

  Result := TJSFunction.CreateNative(ErrorName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructError(ErrorType, PrototypeObj, Args);
    end);

  AttachPrototypeObject(Result, PrototypeObj);
end;

procedure TJSEngine.RegisterErrors;
begin
  FInterpreter.SetGlobalVariable(ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.Error, ERROR_NAME)));

  FInterpreter.SetGlobalVariable(TYPE_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.TypeError, TYPE_ERROR_NAME)));

  FInterpreter.SetGlobalVariable(RANGE_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.RangeError, RANGE_ERROR_NAME)));

  FInterpreter.SetGlobalVariable(REFERENCE_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.ReferenceError, REFERENCE_ERROR_NAME)));

  FInterpreter.SetGlobalVariable(SYNTAX_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.SyntaxError, SYNTAX_ERROR_NAME)));

  FInterpreter.SetGlobalVariable(URI_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.URIError, URI_ERROR_NAME)));

  FInterpreter.SetGlobalVariable(EVAL_ERROR_NAME, TJSValue.CreateObject(
    CreateErrorConstructor(TJSErrorType.EvalError, EVAL_ERROR_NAME)));
end;

function TJSEngine.HasSameRegExpConstructor(const Pattern: TJSValue; const PrototypeObj: IJSObject): Boolean;
begin
  const PatternConstructor = Pattern.ToObject.GetProperty(CONSTRUCTOR_PROPERTY);
  const RegExpConstructor = PrototypeObj.GetProperty(CONSTRUCTOR_PROPERTY);

  Result := PatternConstructor.StrictEquals(RegExpConstructor);
end;

procedure TJSEngine.ReadRegExpSource(const Args: TArray<TJSValue>; const PatternIsRegExp: Boolean;
                                     out Pattern: string; out Flags: string);
begin
  const PatternArg = ArgumentAt(Args, 0);
  const FlagsArg = ArgumentAt(Args, 1);

  var SourceValue := PatternArg;
  var FlagsValue := FlagsArg;

  var BuiltIn: IJSRegExp;
  if PatternArg.IsObject and Supports(PatternArg.ToObject, IJSRegExp, BuiltIn) then
  begin
    SourceValue := TJSValue.CreateString(BuiltIn.Pattern);
    if FlagsArg.IsUndefined then
      FlagsValue := TJSValue.CreateString(BuiltIn.Flags);
  end
  else if PatternIsRegExp then
  begin
    SourceValue := PatternArg.ToObject.GetProperty(SOURCE_PROPERTY);
    if FlagsArg.IsUndefined then
      FlagsValue := PatternArg.ToObject.GetProperty(FLAGS_PROPERTY);
  end;

  Pattern := '';
  if not SourceValue.IsUndefined then
    Pattern := ToText(SourceValue);

  Flags := '';
  if not FlagsValue.IsUndefined then
    Flags := ToText(FlagsValue);
end;

procedure TJSEngine.RegisterRegExp;
begin
  const PrototypeObj: IJSObject = TJSObject.Create;

  const RegExpFunc = TJSFunction.CreateNative(REGEXP_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const IsCall = not TJSPrototypeMethods.IsConstructCall(This, PrototypeObj);
      const PatternIsRegExp = TJSConversions.IsRegExp(ArgumentAt(Args, 0));
      const HasFlags = not ArgumentAt(Args, 1).IsUndefined;
      if IsCall and PatternIsRegExp and (not HasFlags) and HasSameRegExpConstructor(Args[0], PrototypeObj) then
        Exit(Args[0]);

      var Pattern: string;
      var Flags: string;
      ReadRegExpSource(Args, PatternIsRegExp, Pattern, Flags);

      const RegExpObj: IJSRegExp = TJSRegExp.Create(Pattern, Flags);
      RegExpObj.Prototype := PrototypeObj;
      Result := TJSValue.CreateObject(RegExpObj);
    end);

  FInterpreter.SetGlobalVariable(REGEXP_NAME, TJSValue.CreateObject(RegExpFunc));
  AttachPrototypeObject(RegExpFunc, PrototypeObj);
end;

procedure TJSEngine.RegisterPrototypeMethods;
begin
  const MathObject = FInterpreter.GetGlobalVariable(MATH_NAME).ToObject;
  const JSONObject = FInterpreter.GetGlobalVariable(JSON_NAME).ToObject;

  FPrototypeMethods.RegisterObjectMethods(GlobalPrototype(OBJECT_NAME), MathObject, JSONObject);
  FPrototypeMethods.RegisterStringMethods(GlobalPrototype(STRING_FUNC_NAME));
  FPrototypeMethods.RegisterNumberMethods(GlobalPrototype(NUMBER_NAME));
  FPrototypeMethods.RegisterBooleanMethods(GlobalPrototype(BOOLEAN_FUNC_NAME));
  FPrototypeMethods.RegisterErrorMethods(GlobalPrototype(ERROR_NAME));
  FPrototypeMethods.RegisterRegExpMethods(GlobalPrototype(REGEXP_NAME));
  FPrototypeMethods.RegisterFunctionMethods(GlobalPrototype(FUNCTION_NAME));

  FInterpreter.StringPrototype := GlobalPrototype(STRING_FUNC_NAME);
  FInterpreter.NumberPrototype := GlobalPrototype(NUMBER_NAME);
  FInterpreter.BooleanPrototype := GlobalPrototype(BOOLEAN_FUNC_NAME);
end;

function TJSEngine.GlobalPrototype(const ConstructorName: string): IJSObject;
begin
  Result := nil;

  const ConstructorValue = FInterpreter.GetGlobalVariable(ConstructorName);
  if not ConstructorValue.IsObject then
    Exit;

  const PrototypeValue = ConstructorValue.ToObject.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsObject then
    Result := PrototypeValue.ToObject;
end;

procedure TJSEngine.LinkIntrinsicPrototypes;
begin
  const ObjectPrototype = GlobalPrototype(OBJECT_NAME);
  const ErrorPrototype = GlobalPrototype(ERROR_NAME);
  const ErrorConstructor = FInterpreter.GetGlobalVariable(ERROR_NAME).ToObject;

  for var ConstructorName in [ERROR_NAME, ARRAY_NAME, FUNCTION_NAME, DATE_NAME, REGEXP_NAME, NUMBER_NAME,
                              STRING_FUNC_NAME, BOOLEAN_FUNC_NAME] do
  begin
    const Prototype = GlobalPrototype(ConstructorName);
    Prototype.Prototype := ObjectPrototype;
  end;

  for var ConstructorName in [TYPE_ERROR_NAME, RANGE_ERROR_NAME, REFERENCE_ERROR_NAME, SYNTAX_ERROR_NAME,
                              URI_ERROR_NAME, EVAL_ERROR_NAME] do
  begin
    const Prototype = GlobalPrototype(ConstructorName);
    Prototype.Prototype := ErrorPrototype;

    const NativeErrorConstructor = FInterpreter.GetGlobalVariable(ConstructorName).ToObject;
    NativeErrorConstructor.Prototype := ErrorConstructor;
  end;

  for var GlobalName in [MATH_NAME, JSON_NAME] do
  begin
    const GlobalValue = FInterpreter.GetGlobalVariable(GlobalName);
    GlobalValue.ToObject.Prototype := ObjectPrototype;
  end;

  FInterpreter.GlobalObject.Prototype := ObjectPrototype;
  FInterpreter.ObjectPrototype := ObjectPrototype;
  FInterpreter.ArrayPrototype := GlobalPrototype(ARRAY_NAME);
  FInterpreter.FunctionPrototype := GlobalPrototype(FUNCTION_NAME);
  FInterpreter.RegExpPrototype := GlobalPrototype(REGEXP_NAME);

  DefineRestrictedFunctionProperties(GlobalPrototype(FUNCTION_NAME));
end;

procedure TJSEngine.AssignMissingFunctionPrototypes;
begin
  const Pending = TStack<IJSObject>.Create;
  const Visited = THashSet<Pointer>.Create;
  try
    Pending.Push(FInterpreter.GlobalObject);
    if Assigned(FArrayIteratorPrototype) then
      Pending.Push(FArrayIteratorPrototype);

    while Pending.Count > 0 do
    begin
      const Target = Pending.Pop;

      const IsFirstVisit = Visited.Add(Pointer(Target as IInterface));
      if IsFirstVisit then
        AssignFunctionPrototype(Target, Pending);
    end;
  finally
    Visited.Free;
    Pending.Free;
  end;
end;

procedure TJSEngine.AssignFunctionPrototype(const Target: IJSObject; const Pending: TStack<IJSObject>);
begin
  const IsFunctionPrototype = (Pointer(Target as IInterface) = Pointer(FInterpreter.FunctionPrototype as IInterface));
  const NeedsPrototype = Supports(Target, IJSFunction) and (not Assigned(Target.Prototype)) and
                         (not IsFunctionPrototype);
  if NeedsPrototype then
    Target.Prototype := FInterpreter.FunctionPrototype;

  if Assigned(Target.Prototype) then
    Pending.Push(Target.Prototype);

  for var Name in Target.GetOwnPropertyNames do
  begin
    QueueMemberObjects(Target, Name, Pending);
  end;

  for var Key in Target.GetOwnSymbolKeys do
  begin
    QueueMemberObjects(Target, Key, Pending);
  end;
end;

procedure TJSEngine.QueueMemberObjects(const Target: IJSObject; const Name: string; const Pending: TStack<IJSObject>);
begin
  const Descriptor = Target.GetOwnPropertyDescriptor(Name);

  for var Member in [Descriptor.Value, Descriptor.Getter, Descriptor.Setter] do
  begin
    if Member.IsObject then
      Pending.Push(Member.AsObject);
  end;
end;

procedure TJSEngine.DefineRestrictedFunctionProperties(const PrototypeObj: IJSObject);
begin
  const Poison = TJSValue.CreateObject(FInterpreter.ThrowTypeErrorFunction);

  for var PropertyName in [FUNCTION_CALLER, FUNCTION_ARGUMENTS] do
  begin
    var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateUndefined);
    Descriptor.IsAccessor := True;
    Descriptor.Getter := Poison;
    Descriptor.Setter := Poison;
    Descriptor.Enumerable := False;
    PrototypeObj.DefineProperty(PropertyName, Descriptor);
  end;
end;

end.
