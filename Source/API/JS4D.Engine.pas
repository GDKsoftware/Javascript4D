unit JS4D.Engine;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.JSON,
  System.DateUtils,
  System.NetEncoding,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.Lexer,
  JS4D.Parser,
  JS4D.AST,
  JS4D.Interpreter,
  JS4D.Errors;

type
  TConsoleOutputHandler = reference to procedure(const Output: string);

  TJSEngine = class
  private
    FInterpreter: TJSInterpreter;
    FPrograms: TList<TJSProgram>;
    FOnConsoleOutput: TConsoleOutputHandler;

    class function ConvertJSONToJSValue(const JSONValue: TJSONValue): TJSValue; static;
    class function ConvertJSValueToJSON(const Value: TJSValue): TJSONValue; static;

    procedure RegisterBuiltInFunctions;
    procedure RegisterConsole;
    procedure RegisterMath;
    procedure RegisterObject;
    procedure RegisterJSON;
    procedure RegisterArray;
    procedure RegisterDate;
    procedure RegisterErrors;
    procedure RegisterRegExp;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Source: string): TJSValue;
    function Evaluate(const Expression: string): TJSValue;

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
  OBJECT_GET_OWN_PROPERTY_DESCRIPTOR = 'getOwnPropertyDescriptor';
  OBJECT_DEFINE_PROPERTY = 'defineProperty';
  OBJECT_CREATE = 'create';
  OBJECT_HAS_OWN_PROPERTY = 'hasOwnProperty';
  JSON_PARSE = 'parse';
  JSON_STRINGIFY = 'stringify';
  ARRAY_IS_ARRAY = 'isArray';
  ARRAY_FROM = 'from';
  DATE_NAME = 'Date';
  DATE_NOW = 'now';
  DATE_PARSE = 'parse';
  DATE_GET_TIME = 'getTime';
  DATE_GET_FULL_YEAR = 'getFullYear';
  DATE_GET_MONTH = 'getMonth';
  DATE_GET_DATE = 'getDate';
  DATE_GET_DAY = 'getDay';
  DATE_GET_HOURS = 'getHours';
  DATE_GET_MINUTES = 'getMinutes';
  DATE_GET_SECONDS = 'getSeconds';
  DATE_GET_MILLISECONDS = 'getMilliseconds';
  DATE_TO_ISO_STRING = 'toISOString';
  DATE_TO_STRING = 'toString';
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
  DESC_VALUE = 'value';
  DESC_WRITABLE = 'writable';
  DESC_ENUMERABLE = 'enumerable';
  DESC_CONFIGURABLE = 'configurable';

{ TJSEngine }

class function TJSEngine.ConvertJSONToJSValue(const JSONValue: TJSONValue): TJSValue;
begin
  if JSONValue is TJSONNull then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  if JSONValue is TJSONBool then
  begin
    Result := TJSValue.CreateBoolean(TJSONBool(JSONValue).AsBoolean);
    Exit;
  end;

  if JSONValue is TJSONNumber then
  begin
    Result := TJSValue.CreateNumber(TJSONNumber(JSONValue).AsDouble);
    Exit;
  end;

  if JSONValue is TJSONString then
  begin
    Result := TJSValue.CreateString(TJSONString(JSONValue).Value);
    Exit;
  end;

  if JSONValue is TJSONArray then
  begin
    const Arr = TJSArray.Create;

    for var Index := 0 to TJSONArray(JSONValue).Count - 1 do
    begin
      Arr.Push(ConvertJSONToJSValue(TJSONArray(JSONValue).Items[Index]));
    end;

    Result := TJSValue.CreateObject(Arr);
    Exit;
  end;

  if JSONValue is TJSONObject then
  begin
    const Obj = TJSObject.Create;

    for var Pair in TJSONObject(JSONValue) do
    begin
      Obj.SetProperty(Pair.JsonString.Value, ConvertJSONToJSValue(Pair.JsonValue));
    end;

    Result := TJSValue.CreateObject(Obj);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSEngine.ConvertJSValueToJSON(const Value: TJSValue): TJSONValue;
begin
  if Value.IsUndefined then
    Exit(TJSONNull.Create);

  if Value.IsNull then
    Exit(TJSONNull.Create);

  if Value.IsBoolean then
    Exit(TJSONBool.Create(Value.AsBoolean));

  if Value.IsNumber then
  begin
    const Num = Value.AsNumber;

    if System.Math.IsNaN(Num) or System.Math.IsInfinite(Num) then
      Exit(TJSONNull.Create);

    Exit(TJSONNumber.Create(Num));
  end;

  if Value.IsString then
    Exit(TJSONString.Create(Value.AsString));

  if Value.IsArray then
  begin
    const JSONArray = TJSONArray.Create;
    var ArrIntf: IJSArray;
    if Supports(Value.ToObject, IJSArray, ArrIntf) then
    begin
      for var Index := 0 to ArrIntf.Length - 1 do
      begin
        JSONArray.AddElement(ConvertJSValueToJSON(ArrIntf[Index]));
      end;
    end;

    Exit(JSONArray);
  end;

  if Value.IsFunction then
    Exit(TJSONNull.Create);

  if Value.IsObject then
  begin
    const JSONObject = TJSONObject.Create;
    const Obj = Value.ToObject;
    const PropertyNames = Obj.GetOwnPropertyNames;

    for var PropName in PropertyNames do
    begin
      const PropValue = Obj.GetProperty(PropName);

      if not PropValue.IsFunction then
        JSONObject.AddPair(PropName, ConvertJSValueToJSON(PropValue));
    end;

    Exit(JSONObject);
  end;

  Result := TJSONNull.Create;
end;

constructor TJSEngine.Create;
begin
  inherited Create;
  FInterpreter := TJSInterpreter.Create;
  FPrograms := TList<TJSProgram>.Create;
  FOnConsoleOutput := nil;
  RegisterBuiltInFunctions;
end;

destructor TJSEngine.Destroy;
begin
  for var Program_ in FPrograms do
  begin
    Program_.Free;
  end;

  FPrograms.Free;
  FInterpreter.Free;
  inherited;
end;

function TJSEngine.Execute(const Source: string): TJSValue;
begin
  const Parser = TJSParser.Create(Source);
  try
    const Program_ = Parser.Parse;
    FPrograms.Add(Program_);
    Result := FInterpreter.Execute(Program_);
  finally
    Parser.Free;
  end;
end;

function TJSEngine.Evaluate(const Expression: string): TJSValue;
begin
  Result := Execute(Expression);
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
  FInterpreter.SetGlobalVariable(NAN_NAME, TJSValue.CreateNaN);
  FInterpreter.SetGlobalVariable(INFINITY_NAME, TJSValue.CreateInfinity);
  FInterpreter.SetGlobalVariable(UNDEFINED_NAME, TJSValue.CreateUndefined);

  FInterpreter.RegisterNativeFunction(PARSE_INT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Str = Trim(Args[0].ToString);
      var Radix := 10;

      if Length(Args) > 1 then
        Radix := Trunc(Args[1].ToNumber);

      if (Radix < 2) or (Radix > 36) then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      var IntValue: Int64;

      if (Radix = 10) and TryStrToInt64(Str, IntValue) then
      begin
        Result := TJSValue.CreateNumber(IntValue);
        Exit;
      end;

      if (Radix = 16) and (Str.StartsWith('0x', True) or Str.StartsWith('0X', True)) then
      begin
        if TryStrToInt64('$' + Str.Substring(2), IntValue) then
        begin
          Result := TJSValue.CreateNumber(IntValue);
          Exit;
        end;
      end;

      Result := TJSValue.CreateNaN;
    end);

  FInterpreter.RegisterNativeFunction(PARSE_FLOAT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Str = Trim(Args[0].ToString);
      var FloatValue: Double;

      if TryStrToFloat(Str, FloatValue, TFormatSettings.Invariant) then
      begin
        Result := TJSValue.CreateNumber(FloatValue);
        Exit;
      end;

      Result := TJSValue.CreateNaN;
    end);

  FInterpreter.RegisterNativeFunction(IS_NAN_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateBoolean(True);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(System.Math.IsNaN(Args[0].ToNumber));
    end);

  FInterpreter.RegisterNativeFunction(IS_FINITE_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      const Num = Args[0].ToNumber;
      Result := TJSValue.CreateBoolean((not System.Math.IsNaN(Num)) and (not System.Math.IsInfinite(Num)));
    end);

  const NumberFunc = TJSFunction.CreateNative(NUMBER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNumber(0);
        Exit;
      end;

      Result := TJSValue.CreateNumber(Args[0].ToNumber);
    end);

  NumberFunc.SetProperty('MAX_VALUE', TJSValue.CreateNumber(1.7976931348623157e+308));
  NumberFunc.SetProperty('MIN_VALUE', TJSValue.CreateNumber(5e-324));
  NumberFunc.SetProperty('NaN', TJSValue.CreateNaN);
  NumberFunc.SetProperty('POSITIVE_INFINITY', TJSValue.CreateInfinity(False));
  NumberFunc.SetProperty('NEGATIVE_INFINITY', TJSValue.CreateInfinity(True));

  FInterpreter.SetGlobalVariable(NUMBER_NAME, TJSValue.CreateObject(NumberFunc));

  const StringFunc = TJSFunction.CreateNative(STRING_FUNC_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateString('');
        Exit;
      end;

      Result := TJSValue.CreateString(Args[0].ToString);
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

  FInterpreter.SetGlobalVariable(STRING_FUNC_NAME, TJSValue.CreateObject(StringFunc));

  FInterpreter.RegisterNativeFunction(BOOLEAN_FUNC_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(Args[0].ToBoolean);
    end);

  FInterpreter.RegisterNativeFunction(ENCODE_URI_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    const
      URIReserved = [';', ',', '/', '?', ':', '@', '&', '=', '+', '$', '#'];
      URIUnescaped = ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '!', '~', '*', '''', '(', ')'];
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Str = Args[0].ToString;
      var EncodedString := '';
      var CharIndex := 1;

      while CharIndex <= Length(Str) do
      begin
        const Ch = Str[CharIndex];

        if CharInSet(Ch, URIReserved + URIUnescaped) then
          EncodedString := EncodedString + Ch
        else
        begin
          const Bytes = TEncoding.UTF8.GetBytes(Ch);
          for var ByteValue in Bytes do
            EncodedString := EncodedString + '%' + IntToHex(ByteValue, 2);
        end;

        Inc(CharIndex);
      end;

      Result := TJSValue.CreateString(EncodedString);
    end);

  FInterpreter.RegisterNativeFunction(DECODE_URI_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Str = Args[0].ToString;
      Result := TJSValue.CreateString(TNetEncoding.URL.Decode(Str));
    end);

  FInterpreter.RegisterNativeFunction(ENCODE_URI_COMPONENT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    const
      URIUnescaped = ['A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '!', '~', '*', '''', '(', ')'];
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Str = Args[0].ToString;
      var EncodedString := '';
      var CharIndex := 1;

      while CharIndex <= Length(Str) do
      begin
        const Ch = Str[CharIndex];

        if CharInSet(Ch, URIUnescaped) then
          EncodedString := EncodedString + Ch
        else
        begin
          const Bytes = TEncoding.UTF8.GetBytes(Ch);
          for var ByteValue in Bytes do
            EncodedString := EncodedString + '%' + IntToHex(ByteValue, 2);
        end;

        Inc(CharIndex);
      end;

      Result := TJSValue.CreateString(EncodedString);
    end);

  FInterpreter.RegisterNativeFunction(DECODE_URI_COMPONENT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Str = Args[0].ToString;
      Result := TJSValue.CreateString(TNetEncoding.URL.Decode(Str));
    end);

  RegisterConsole;
  RegisterMath;
  RegisterObject;
  RegisterJSON;
  RegisterArray;
  RegisterDate;
  RegisterErrors;
  RegisterRegExp;
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

        Output := Output + Args[Index].ToString;
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
  const MathObj = TJSObject.Create;

  MathObj.SetProperty(MATH_PI, TJSValue.CreateNumber(Pi));
  MathObj.SetProperty(MATH_E, TJSValue.CreateNumber(Exp(1)));
  MathObj.SetProperty(MATH_LN2, TJSValue.CreateNumber(Ln(2)));
  MathObj.SetProperty(MATH_LN10, TJSValue.CreateNumber(Ln(10)));
  MathObj.SetProperty(MATH_LOG2E, TJSValue.CreateNumber(1 / Ln(2)));
  MathObj.SetProperty(MATH_LOG10E, TJSValue.CreateNumber(1 / Ln(10)));
  MathObj.SetProperty(MATH_SQRT2, TJSValue.CreateNumber(Sqrt(2)));
  MathObj.SetProperty(MATH_SQRT1_2, TJSValue.CreateNumber(Sqrt(0.5)));

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

      Result := TJSValue.CreateNumber(Floor(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_CEIL, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_CEIL,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Ceil(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_ROUND, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_ROUND,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      Result := TJSValue.CreateNumber(Round(Args[0].ToNumber));
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

      Result := TJSValue.CreateNumber(Power(Args[0].ToNumber, Args[1].ToNumber));
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

        if Value < MinValue then
          MinValue := Value;
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

        if Value > MaxValue then
          MaxValue := Value;
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

      Result := TJSValue.CreateNumber(Sin(Args[0].ToNumber));
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

      Result := TJSValue.CreateNumber(Tan(Args[0].ToNumber));
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

      Result := TJSValue.CreateNumber(Trunc(Args[0].ToNumber));
    end)));

  MathObj.SetProperty(MATH_SIGN, TJSValue.CreateObject(TJSFunction.CreateNative(MATH_SIGN,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Num = Args[0].ToNumber;

      if System.Math.IsNaN(Num) then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      if Num > 0 then
      begin
        Result := TJSValue.CreateNumber(1);
        Exit;
      end;

      if Num < 0 then
      begin
        Result := TJSValue.CreateNumber(-1);
        Exit;
      end;

      Result := TJSValue.CreateNumber(0);
    end)));

  FInterpreter.SetGlobalVariable(MATH_NAME, TJSValue.CreateObject(MathObj));
end;

procedure TJSEngine.RegisterObject;
begin
  const ObjectObj = TJSObject.Create;

  ObjectObj.SetProperty(OBJECT_KEYS, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_KEYS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const ResultArr: IJSArray = TJSArray.Create;

      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateObject(ResultArr);
        Exit;
      end;

      const Obj = Args[0].ToObject;

      var ArrIntf: IJSArray;
      if Supports(Obj, IJSArray, ArrIntf) then
      begin
        for var Index := 0 to ArrIntf.Length - 1 do
          ResultArr.Push(TJSValue.CreateString(IntToStr(Index)));
      end
      else
      begin
        const PropertyNames = Obj.GetOwnPropertyNames;

        for var PropName in PropertyNames do
          ResultArr.Push(TJSValue.CreateString(PropName));
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_VALUES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_VALUES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const ResultArr: IJSArray = TJSArray.Create;

      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateObject(ResultArr);
        Exit;
      end;

      const Obj = Args[0].ToObject;

      var ArrIntf: IJSArray;
      if Supports(Obj, IJSArray, ArrIntf) then
      begin
        for var Index := 0 to ArrIntf.Length - 1 do
          ResultArr.Push(ArrIntf[Index]);
      end
      else
      begin
        const PropertyNames = Obj.GetOwnPropertyNames;

        for var PropName in PropertyNames do
          ResultArr.Push(Obj.GetProperty(PropName));
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_ENTRIES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_ENTRIES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const ResultArr: IJSArray = TJSArray.Create;

      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateObject(ResultArr);
        Exit;
      end;

      const Obj = Args[0].ToObject;

      var ArrIntf: IJSArray;
      if Supports(Obj, IJSArray, ArrIntf) then
      begin
        for var Index := 0 to ArrIntf.Length - 1 do
        begin
          const EntryArr: IJSArray = TJSArray.Create;
          EntryArr.Push(TJSValue.CreateString(IntToStr(Index)));
          EntryArr.Push(ArrIntf[Index]);
          ResultArr.Push(TJSValue.CreateObject(EntryArr));
        end;
      end
      else
      begin
        const PropertyNames = Obj.GetOwnPropertyNames;

        for var PropName in PropertyNames do
        begin
          const EntryArr: IJSArray = TJSArray.Create;
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
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Target = Args[0].ToObject;

      for var Index := 1 to Length(Args) - 1 do
      begin
        if Args[Index].IsObject then
        begin
          const Source = Args[Index].ToObject;
          const PropertyNames = Source.GetOwnPropertyNames;

          for var PropName in PropertyNames do
            Target.SetProperty(PropName, Source.GetProperty(PropName));
        end;
      end;

      Result := TJSValue.CreateObject(Target);
    end)));

  ObjectObj.SetProperty(OBJECT_CREATE, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_CREATE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const NewObj = TJSObject.Create;

      if (Length(Args) > 0) and Args[0].IsObject then
        NewObj.Prototype := Args[0].ToObject;

      Result := TJSValue.CreateObject(NewObj);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_PROTOTYPE_OF, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_PROTOTYPE_OF,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateNull;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      const Proto = Obj.Prototype;

      if Proto = nil then
        Result := TJSValue.CreateNull
      else
        Result := TJSValue.CreateObject(Proto);
    end)));

  ObjectObj.SetProperty(OBJECT_GET_OWN_PROPERTY_NAMES, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_GET_OWN_PROPERTY_NAMES,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const ResultArr: IJSArray = TJSArray.Create;

      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateObject(ResultArr);
        Exit;
      end;

      const Obj = Args[0].ToObject;
      const PropertyNames = Obj.GetOwnPropertyNames;

      for var PropName in PropertyNames do
        ResultArr.Push(TJSValue.CreateString(PropName));

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  ObjectObj.SetProperty(OBJECT_FREEZE, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_FREEZE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      Obj.Freeze;
      Result := TJSValue.CreateObject(Obj);
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
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      Obj.Seal;
      Result := TJSValue.CreateObject(Obj);
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
      if (Length(Args) = 0) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      Obj.PreventExtensions;
      Result := TJSValue.CreateObject(Obj);
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
      if (Length(Args) < 2) or (not Args[0].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      const PropName = Args[1].ToString;

      if not Obj.HasOwnProperty(PropName) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Descriptor = Obj.GetOwnPropertyDescriptor(PropName);
      const DescObj: IJSObject = TJSObject.Create;

      DescObj.SetProperty(DESC_VALUE, Descriptor.Value);
      DescObj.SetProperty(DESC_WRITABLE, TJSValue.CreateBoolean(Descriptor.Writable));
      DescObj.SetProperty(DESC_ENUMERABLE, TJSValue.CreateBoolean(Descriptor.Enumerable));
      DescObj.SetProperty(DESC_CONFIGURABLE, TJSValue.CreateBoolean(Descriptor.Configurable));

      Result := TJSValue.CreateObject(DescObj);
    end)));

  ObjectObj.SetProperty(OBJECT_DEFINE_PROPERTY, TJSValue.CreateObject(TJSFunction.CreateNative(OBJECT_DEFINE_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if (Length(Args) < 3) or (not Args[0].IsObject) or (not Args[2].IsObject) then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const Obj = Args[0].ToObject;
      const PropName = Args[1].ToString;
      const DescObj = Args[2].ToObject;

      var Descriptor: TJSPropertyDescriptor;
      Descriptor.Value := DescObj.GetProperty(DESC_VALUE);
      Descriptor.Writable := DescObj.GetProperty(DESC_WRITABLE).ToBoolean;
      Descriptor.Enumerable := DescObj.GetProperty(DESC_ENUMERABLE).ToBoolean;
      Descriptor.Configurable := DescObj.GetProperty(DESC_CONFIGURABLE).ToBoolean;

      Obj.DefineProperty(PropName, Descriptor);

      Result := TJSValue.CreateObject(Obj);
    end)));

  const PrototypeObj = TJSObject.Create;
  ObjectObj.SetNonConfigurableProperty('prototype', TJSValue.CreateObject(PrototypeObj));

  FInterpreter.SetGlobalVariable(OBJECT_NAME, TJSValue.CreateObject(ObjectObj));
end;

procedure TJSEngine.RegisterJSON;
begin
  const JSONObj = TJSObject.Create;

  JSONObj.SetProperty(JSON_PARSE, TJSValue.CreateObject(TJSFunction.CreateNative(JSON_PARSE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const JSONString = Args[0].ToString;

      try
        const JSONValue = TJSONObject.ParseJSONValue(JSONString);

        if JSONValue = nil then
        begin
          Result := TJSValue.CreateUndefined;
          Exit;
        end;

        try
          Result := ConvertJSONToJSValue(JSONValue);
        finally
          JSONValue.Free;
        end;
      except
        on E: Exception do
          Result := TJSValue.CreateUndefined;
      end;
    end)));

  JSONObj.SetProperty(JSON_STRINGIFY, TJSValue.CreateObject(TJSFunction.CreateNative(JSON_STRINGIFY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateUndefined;
        Exit;
      end;

      const JSONValue = ConvertJSValueToJSON(Args[0]);
      try
        Result := TJSValue.CreateString(JSONValue.ToJSON);
      finally
        JSONValue.Free;
      end;
    end)));

  FInterpreter.SetGlobalVariable(JSON_NAME, TJSValue.CreateObject(JSONObj));
end;

procedure TJSEngine.RegisterArray;
begin
  const ArrayObj = TJSObject.Create;

  ArrayObj.SetProperty(ARRAY_IS_ARRAY, TJSValue.CreateObject(TJSFunction.CreateNative(ARRAY_IS_ARRAY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      Result := TJSValue.CreateBoolean(Args[0].IsArray);
    end)));

  ArrayObj.SetProperty(ARRAY_FROM, TJSValue.CreateObject(TJSFunction.CreateNative(ARRAY_FROM,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const ResultArr: IJSArray = TJSArray.Create;

      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateObject(ResultArr);
        Exit;
      end;

      const Source = Args[0];

      if Source.IsArray then
      begin
        var SourceArr: IJSArray;
        if Supports(Source.ToObject, IJSArray, SourceArr) then
        begin
          for var Index := 0 to SourceArr.Length - 1 do
          begin
            ResultArr.Push(SourceArr[Index]);
          end;
        end;
      end
      else if Source.IsString then
      begin
        const Str = Source.AsString;

        for var Index := 1 to Length(Str) do
        begin
          ResultArr.Push(TJSValue.CreateString(Str[Index]));
        end;
      end
      else if Source.IsObject then
      begin
        const Obj = Source.ToObject;
        const LengthValue = Obj.GetProperty('length');

        if LengthValue.IsNumber then
        begin
          const Len = Trunc(LengthValue.ToNumber);

          for var Index := 0 to Len - 1 do
          begin
            ResultArr.Push(Obj.GetProperty(IntToStr(Index)));
          end;
        end;
      end;

      Result := TJSValue.CreateObject(ResultArr);
    end)));

  FInterpreter.SetGlobalVariable(ARRAY_NAME, TJSValue.CreateObject(ArrayObj));
end;

procedure TJSEngine.RegisterDate;
const
  UNIX_EPOCH: TDateTime = 25569.0;
begin
  const DateFunc = TJSFunction.CreateNative(DATE_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var DateObj: TJSDate;

      if Length(Args) = 0 then
        DateObj := TJSDate.Create
      else if Length(Args) = 1 then
      begin
        const Arg = Args[0];

        if Arg.IsNumber then
          DateObj := TJSDate.Create(Arg.AsNumber)
        else if Arg.IsString then
        begin
          try
            const ParsedDate = ISO8601ToDate(Arg.AsString, False);
            const Timestamp = (ParsedDate - UNIX_EPOCH) * 86400000.0;
            DateObj := TJSDate.Create(Timestamp);
          except
            on E: Exception do
              DateObj := TJSDate.Create(System.Math.NaN);
          end;
        end
        else
          DateObj := TJSDate.Create;
      end
      else
      begin
        const Year = Trunc(Args[0].ToNumber);
        const Month = Trunc(Args[1].ToNumber);
        var Day := 1;
        var Hours := 0;
        var Minutes := 0;
        var Seconds := 0;
        var Milliseconds := 0;

        if Length(Args) > 2 then Day := Trunc(Args[2].ToNumber);
        if Length(Args) > 3 then Hours := Trunc(Args[3].ToNumber);
        if Length(Args) > 4 then Minutes := Trunc(Args[4].ToNumber);
        if Length(Args) > 5 then Seconds := Trunc(Args[5].ToNumber);
        if Length(Args) > 6 then Milliseconds := Trunc(Args[6].ToNumber);

        DateObj := TJSDate.Create(Year, Month, Day, Hours, Minutes, Seconds, Milliseconds);
      end;

      DateObj.SetProperty('getTime', TJSValue.CreateObject(TJSFunction.CreateNative('getTime',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('getFullYear', TJSValue.CreateObject(TJSFunction.CreateNative('getFullYear',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetFullYear);
        end)));

      DateObj.SetProperty('getMonth', TJSValue.CreateObject(TJSFunction.CreateNative('getMonth',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetMonth);
        end)));

      DateObj.SetProperty('getDate', TJSValue.CreateObject(TJSFunction.CreateNative('getDate',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetDate);
        end)));

      DateObj.SetProperty('getDay', TJSValue.CreateObject(TJSFunction.CreateNative('getDay',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetDay);
        end)));

      DateObj.SetProperty('getHours', TJSValue.CreateObject(TJSFunction.CreateNative('getHours',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetHours);
        end)));

      DateObj.SetProperty('getMinutes', TJSValue.CreateObject(TJSFunction.CreateNative('getMinutes',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetMinutes);
        end)));

      DateObj.SetProperty('getSeconds', TJSValue.CreateObject(TJSFunction.CreateNative('getSeconds',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetSeconds);
        end)));

      DateObj.SetProperty('getMilliseconds', TJSValue.CreateObject(TJSFunction.CreateNative('getMilliseconds',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetMilliseconds);
        end)));

      DateObj.SetProperty('getUTCFullYear', TJSValue.CreateObject(TJSFunction.CreateNative('getUTCFullYear',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetUTCFullYear);
        end)));

      DateObj.SetProperty('getTimezoneOffset', TJSValue.CreateObject(TJSFunction.CreateNative('getTimezoneOffset',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateNumber(DateObj.GetTimezoneOffset);
        end)));

      DateObj.SetProperty('setFullYear', TJSValue.CreateObject(TJSFunction.CreateNative('setFullYear',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetFullYear(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('setMonth', TJSValue.CreateObject(TJSFunction.CreateNative('setMonth',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetMonth(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('setDate', TJSValue.CreateObject(TJSFunction.CreateNative('setDate',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetDate(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('setHours', TJSValue.CreateObject(TJSFunction.CreateNative('setHours',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetHours(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('setMinutes', TJSValue.CreateObject(TJSFunction.CreateNative('setMinutes',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetMinutes(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('setSeconds', TJSValue.CreateObject(TJSFunction.CreateNative('setSeconds',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          if Length(Args) > 0 then
            DateObj.SetSeconds(Trunc(Args[0].ToNumber));
          Result := TJSValue.CreateNumber(DateObj.GetTime);
        end)));

      DateObj.SetProperty('toISOString', TJSValue.CreateObject(TJSFunction.CreateNative('toISOString',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateString(DateObj.ToISOString);
        end)));

      DateObj.SetProperty('toDateString', TJSValue.CreateObject(TJSFunction.CreateNative('toDateString',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateString(DateObj.ToDateString);
        end)));

      DateObj.SetProperty('toTimeString', TJSValue.CreateObject(TJSFunction.CreateNative('toTimeString',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateString(DateObj.ToTimeString);
        end)));

      DateObj.SetProperty('toString', TJSValue.CreateObject(TJSFunction.CreateNative('toString',
        function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
        begin
          Result := TJSValue.CreateString(DateObj.ToLocaleString);
        end)));

      Result := TJSValue.CreateObject(DateObj);
    end);

  DateFunc.SetProperty(DATE_NOW, TJSValue.CreateObject(TJSFunction.CreateNative(DATE_NOW,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateNumber((Now - UNIX_EPOCH) * 86400000.0);
    end)));

  DateFunc.SetProperty(DATE_PARSE, TJSValue.CreateObject(TJSFunction.CreateNative(DATE_PARSE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const DateStr = Args[0].ToString;

      try
        const ParsedDate = ISO8601ToDate(DateStr, True);
        Result := TJSValue.CreateNumber((ParsedDate - UNIX_EPOCH) * 86400000.0);
      except
        on E: Exception do
          Result := TJSValue.CreateNaN;
      end;
    end)));

  DateFunc.SetProperty('UTC', TJSValue.CreateObject(TJSFunction.CreateNative('UTC',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) < 2 then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Year = Trunc(Args[0].ToNumber);
      const Month = Trunc(Args[1].ToNumber);
      var Day := 1;
      var Hours := 0;
      var Minutes := 0;
      var Seconds := 0;
      var Milliseconds := 0;

      if Length(Args) > 2 then Day := Trunc(Args[2].ToNumber);
      if Length(Args) > 3 then Hours := Trunc(Args[3].ToNumber);
      if Length(Args) > 4 then Minutes := Trunc(Args[4].ToNumber);
      if Length(Args) > 5 then Seconds := Trunc(Args[5].ToNumber);
      if Length(Args) > 6 then Milliseconds := Trunc(Args[6].ToNumber);

      const UTCDate = EncodeDateTime(Year, Month + 1, Day, Hours, Minutes, Seconds, Milliseconds);
      Result := TJSValue.CreateNumber((UTCDate - UNIX_EPOCH) * 86400000.0);
    end)));

  FInterpreter.SetGlobalVariable(DATE_NAME, TJSValue.CreateObject(DateFunc));
end;

procedure TJSEngine.RegisterErrors;

  function CreateErrorConstructor(const ErrorType: TJSErrorType; const ErrorName: string): TJSObject;
  begin
    Result := TJSFunction.CreateNative(ErrorName,
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        var Msg := '';

        if Length(Args) > 0 then
          Msg := Args[0].ToString;

        const ErrorObj = TJSError.Create(ErrorType, Msg);

        ErrorObj.SetProperty(ERROR_TO_STRING, TJSValue.CreateObject(TJSFunction.CreateNative(ERROR_TO_STRING,
          function(const This: IJSObject; const ToStringArgs: TArray<TJSValue>): TJSValue
          begin
            const Name = ErrorObj.GetErrorName;
            const Msg = ErrorObj.Message;

            if Msg = '' then
              Result := TJSValue.CreateString(Name)
            else
              Result := TJSValue.CreateString(Name + ': ' + Msg);
          end)));

        Result := TJSValue.CreateObject(ErrorObj);
      end);
  end;

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

procedure TJSEngine.RegisterRegExp;
const
  REGEXP_NAME = 'RegExp';
begin
  const RegExpFunc = TJSFunction.CreateNative(REGEXP_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Pattern := '';
      var Flags := '';

      if Length(Args) > 0 then
        Pattern := Args[0].ToString;

      if Length(Args) > 1 then
        Flags := Args[1].ToString;

      const RegExpObj: IJSRegExp = TJSRegExp.Create(Pattern, Flags);

      RegExpObj.SetProperty('test', TJSValue.CreateObject(TJSFunction.CreateNative('test',
        function(const This: IJSObject; const TestArgs: TArray<TJSValue>): TJSValue
        begin
          var RE: IJSRegExp;
          if Supports(This, IJSRegExp, RE) and (Length(TestArgs) > 0) then
            Result := TJSValue.CreateBoolean(RE.Test(TestArgs[0].ToString))
          else
            Result := TJSValue.CreateBoolean(False);
        end)));

      RegExpObj.SetProperty('exec', TJSValue.CreateObject(TJSFunction.CreateNative('exec',
        function(const This: IJSObject; const ExecArgs: TArray<TJSValue>): TJSValue
        begin
          var RE: IJSRegExp;
          if Supports(This, IJSRegExp, RE) and (Length(ExecArgs) > 0) then
            Result := RE.Exec(ExecArgs[0].ToString)
          else
            Result := TJSValue.CreateNull;
        end)));

      RegExpObj.SetProperty('toString', TJSValue.CreateObject(TJSFunction.CreateNative('toString',
        function(const This: IJSObject; const ToStringArgs: TArray<TJSValue>): TJSValue
        begin
          var RE: IJSRegExp;
          if Supports(This, IJSRegExp, RE) then
            Result := TJSValue.CreateString('/' + RE.Pattern + '/' + RE.Flags)
          else
            Result := TJSValue.CreateString('/(?:)/');
        end)));

      Result := TJSValue.CreateObject(RegExpObj);
    end);

  FInterpreter.SetGlobalVariable(REGEXP_NAME, TJSValue.CreateObject(RegExpFunc));
end;

end.
