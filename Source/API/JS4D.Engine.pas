unit JS4D.Engine;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.RegExpObject,
  JS4D.ArrayObject,
  JS4D.AST,
  JS4D.SourceContext,
  JS4D.ArrayIterator,
  JS4D.Interpreter,
  JS4D.BuiltinSet,
  JS4D.BuiltinSupport,
  JS4D.DynamicFunctions,
  JS4D.PrototypeMethods,
  JS4D.DateBuiltins,
  JS4D.CollectionBuiltins,
  JS4D.PromiseBuiltins;

type
  TConsoleOutputHandler = reference to procedure(const Output: string);
  TUriTransform = reference to function(const Text: string): string;

  TJSEngine = class
  private
    type
      TRegExpSource = record
        Pattern: string;
        Flags: string;
      end;

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FFunctionFactory: TJSDynamicFunctionFactory;
      FPrototypeMethods: TJSPrototypeMethods;
      FDateBuiltins: TJSDateBuiltins;
      FBuiltinSets: TObjectList<TJSBuiltinSet>;
      FCollectionBuiltins: TJSCollectionBuiltins;
      FPromiseBuiltins: TJSPromiseBuiltins;
      FArrayIteratorPrototype: IJSObject;
      FPrograms: TList<TJSProgram>;
      FOnConsoleOutput: TConsoleOutputHandler;

    class function ArrayIntrinsicRole(const MethodName: string): TJSIntrinsicRole; static;
    class function IsValidArrayLength(const Value: Double): Boolean; static;
    class procedure DefineFunction(const Target: IJSObject; const Name: string;
                                   const Native: TNativeFunction); static;

    function GetStepBudget: Int64;
    procedure SetStepBudget(const Value: Int64);
    function GetStepCount: Int64;
    function GetMaxCallDepth: Integer;
    procedure SetMaxCallDepth(const Value: Integer);
    function GetMaxStringLength: Integer;
    procedure SetMaxStringLength(const Value: Integer);
    function GetMaxArrayLength: Integer;
    procedure SetMaxArrayLength(const Value: Integer);

    function ParseProgram(const Source: string; const IsStrictContext: Boolean;
                          const Context: TJSSourceContext): TJSProgram;
    function ParseScript(const Source: string): TJSProgram;
    procedure FreeBuiltinSets;

    procedure RegisterBuiltInsInHeap;
    procedure RegisterBuiltInFunctions;
    procedure RegisterGlobalConstants;
    procedure RegisterGlobalFunctions;
    procedure RegisterUriFunctions;
    procedure RegisterCoreObjects;
    procedure RegisterCoreBuiltinSets;
    procedure RegisterExtendedBuiltinSets;
    procedure AddBuiltinSet(const BuiltinSet: TJSBuiltinSet);
    procedure ApplyBuiltinAttributes;

    function CreateBuiltinFunction(const Name: string; const Native: TNativeFunction): IJSFunction;
    procedure SetGlobalObject(const Name: string; const Value: IJSObject);
    function GlobalObjectNamed(const Name: string): IJSObject;
    function GlobalPrototype(const ConstructorName: string): IJSObject;
    procedure AttachPrototypeObject(const Constructor_: IJSFunction; const PrototypeObject: IJSObject);
    procedure DefineGlobalConstructor(const Name: string; const Constructor_: IJSFunction;
                                      const PrototypeObject: IJSObject);

    function GlobalParseInt(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GlobalParseFloat(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GlobalIsNaN(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GlobalIsFinite(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    procedure RegisterUriFunction(const Name: string; const Transform: TUriTransform);

    procedure RegisterNumber;
    procedure RegisterString;
    procedure RegisterStringStatics(const StringConstructor: IJSFunction);
    procedure RegisterBoolean;
    function CallNumber(const This: IJSObject; const Args: TArray<TJSValue>;
                        const PrototypeObject: IJSObject): TJSValue;
    function CallBoolean(const This: IJSObject; const Args: TArray<TJSValue>;
                         const PrototypeObject: IJSObject): TJSValue;
    function ConstructOrConvert(const This: IJSObject; const PrototypeObject: IJSObject;
                                const Primitive: TJSValue): TJSValue;
    function WrapPrimitive(const Primitive: TJSValue): TJSValue;
    function StringFromCharCode(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function StringFromCodePoint(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function StringRaw(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function ReadCodePoint(const Argument: TJSValue): Integer;
    function ConcatenateRawStrings(const Args: TArray<TJSValue>): string;

    procedure RegisterConsole;
    function ConsoleLog(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function ConsoleArgumentText(const Argument: TJSValue): string;
    procedure WriteConsoleLine(const Line: string);

    procedure RegisterMath;
    procedure RegisterObject;
    procedure RegisterObjectPrototypeMethods(const PrototypeObject: IJSObject);
    function CreateObjectPrototypeMethod(const MethodName: string): IJSFunction;
    procedure RaiseCalledWithoutThis(const MethodName: string; const Args: TArray<TJSValue>);
    procedure CoercePropertyKeyForSideEffects(const Value: TJSValue);
    function ConstructObject(const Args: TArray<TJSValue>; const PrototypeObject: IJSObject): TJSValue;

    procedure RegisterJSON;
    function JsonParse(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function JsonStringify(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;

    procedure RegisterArray;
    procedure RegisterArrayStatics(const ArrayConstructor: IJSFunction);
    procedure RegisterArrayPrototypeMethods(const PrototypeObject: IJSObject);
    procedure RegisterArrayIterators(const PrototypeObject: IJSObject);
    function ArrayIsArray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function ArrayIteratorNext(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateArrayStaticMethod(const MethodName: string): IJSFunction;
    function CreateArrayPrototypeMethod(const MethodName: string): IJSFunction;
    function CreateGenericArrayMethod(const MethodName: string): IJSFunction;
    function CreateIterationArrayMethod(const MethodName: string): IJSFunction;
    function CreateArrayOrGenericMethod(const MethodName: string): IJSFunction;
    function CreateArrayIteratorFactory(const MethodName: string; const Kind: TJSArrayIteratorKind;
                                        const IteratorPrototype: IJSObject): IJSFunction;
    function ConstructArray(const Args: TArray<TJSValue>; const PrototypeObject: IJSObject): TJSValue;

    procedure RegisterDate;

    procedure RegisterErrors;
    function CreateErrorConstructor(const ErrorType: TJSErrorType; const ErrorName: string): IJSFunction;
    function ConstructError(const ErrorType: TJSErrorType; const PrototypeObject: IJSObject;
                            const Args: TArray<TJSValue>): TJSValue;

    procedure RegisterRegExp;
    function CallRegExp(const This: IJSObject; const Args: TArray<TJSValue>;
                        const PrototypeObject: IJSObject): TJSValue;
    function HasSameRegExpConstructor(const Pattern: TJSValue; const PrototypeObject: IJSObject): Boolean;
    function ReadRegExpSource(const PatternArgument: TJSValue; const FlagsArgument: TJSValue;
                              const PatternIsRegExp: Boolean): TRegExpSource;

    procedure RegisterFunctionObject;
    function CreateFunctionPrototypeMethod(const MethodName: string): IJSFunction;
    procedure DefineRestrictedFunctionProperties(const PrototypeObject: IJSObject);

    procedure RegisterPrototypeMethods;
    procedure LinkIntrinsicPrototypes;
    procedure LinkErrorPrototypes;
    procedure LinkGlobalObjectPrototypes(const ObjectPrototype: IJSObject);
    procedure AssignMissingFunctionPrototypes;
    procedure AssignFunctionPrototype(const Target: IJSObject; const Pending: TStack<IJSObject>);
    procedure QueueMemberObjects(const Target: IJSObject; const Name: TJSPropertyKey;
                                 const Pending: TStack<IJSObject>);
    class function HasPendingTargets(const Pending: TStack<IJSObject>): Boolean; static;

  public
    constructor Create;
    destructor Destroy; override;

    function Execute(const Source: string): TJSValue;
    function Evaluate(const Expression: string): TJSValue;
    procedure Cancel;
    procedure CollectGarbage;
    procedure RunPendingJobs;

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

uses
  System.Math,
  System.Character,
  JS4D.Parser,
  JS4D.SuspensionAnalysis,
  JS4D.IntrinsicCache,
  JS4D.Operators,
  JS4D.Builtins,
  JS4D.ArrayIteration,
  JS4D.ArrayGeneric,
  JS4D.ArrayLike,
  JS4D.PropertyNames,
  JS4D.BuiltinAttributes,
  JS4D.JsonWriter,
  JS4D.JsonReader,
  JS4D.JsonReviver,
  JS4D.ObjectOperations,
  JS4D.ObjectStatics,
  JS4D.Conversions,
  JS4D.ParserRules,
  JS4D.MathFunctions,
  JS4D.SymbolBuiltins,
  JS4D.IteratorBuiltins,
  JS4D.BinaryBuiltins,
  JS4D.ProxyBuiltins,
  JS4D.GeneratorBuiltins,
  JS4D.AsyncFunctionBuiltins,
  JS4D.ReflectBuiltins,
  JS4D.RegExpProtocol,
  JS4D.ObjectBuiltins,
  JS4D.StringPatternMethods,
  JS4D.UriCoding,
  JS4D.Utf16,
  JS4D.NumericBuiltins,
  JS4D.NumberParse,
  JS4D.NumberText,
  JS4D.Errors;

const
  CONSOLE_LOG = 'log';
  CONSOLE_ERROR = 'error';
  CONSOLE_WARN = 'warn';
  CONSOLE_INFO = 'info';
  CONSOLE_NAME = 'console';
  CONSOLE_ARGUMENT_SEPARATOR = ' ';
  MATH_NAME = 'Math';
  OBJECT_NAME = 'Object';
  REGEXP_NAME = 'RegExp';
  SOURCE_PROPERTY = 'source';
  FLAGS_PROPERTY = 'flags';
  FROM_CHAR_CODE_NAME = 'fromCharCode';
  FROM_CODE_POINT_NAME = 'fromCodePoint';
  INVALID_CODE_POINT = 'Invalid code point %s';
  CHAR_CODE_MASK = $FFFF;
  FUNCTION_KEYWORD = 'function';
  FUNCTION_CALL = 'call';
  FUNCTION_APPLY = 'apply';
  FUNCTION_BIND = 'bind';
  FUNCTION_CALLER = 'caller';
  NOT_CALLED_ON_FUNCTION = 'Function.prototype.%s called on a value that is not a function';
  NOT_CALLED_ON_ARRAY = 'Array.prototype.%s called on a value that is not an array';
  NOT_CALLED_ON_OBJECT = 'Object.prototype.%s called on undefined or null';
  JSON_NAME = 'JSON';
  JSON_PARSE = 'parse';
  JSON_STRINGIFY = 'stringify';
  ARRAY_NAME = 'Array';
  NUMBER_NAME = 'Number';
  STRING_NAME = 'String';
  BOOLEAN_NAME = 'Boolean';
  PARSE_INT_NAME = 'parseInt';
  PARSE_FLOAT_NAME = 'parseFloat';
  IS_NAN_TEXT = 'isNaN';
  IS_FINITE_NAME = 'isFinite';
  ENCODE_URI_NAME = 'encodeURI';
  DECODE_URI_NAME = 'decodeURI';
  ENCODE_URI_COMPONENT_NAME = 'encodeURIComponent';
  DECODE_URI_COMPONENT_NAME = 'decodeURIComponent';
  UNDEFINED_NAME = 'undefined';
  GLOBAL_THIS_NAME = 'globalThis';
  ARRAY_IS_ARRAY = 'isArray';
  ARRAY_TO_LOCALE_STRING = 'toLocaleString';
  ARRAY_FROM = 'from';
  ARRAY_OF = 'of';
  ITERATOR_NEXT = 'next';
  ITERATOR_NOT_AN_ARRAY_ITERATOR = 'next method called on an object that is not an array iterator';
  DATE_NAME = 'Date';

{ TJSEngine }

class function TJSEngine.ArrayIntrinsicRole(const MethodName: string): TJSIntrinsicRole;
begin
  if MethodName = JOIN_METHOD then
  begin
    Result := TJSIntrinsicRole.ArrayJoin;
  end
  else if MethodName = TO_STRING_METHOD then
  begin
    Result := TJSIntrinsicRole.ArrayToString;
  end
  else
  begin
    Result := TJSIntrinsicRole.None;
  end;
end;

class function TJSEngine.IsValidArrayLength(const Value: Double): Boolean;
begin
  const IsWholeNumber = TJSMathFunctions.IsInteger(Value);

  Result := (IsWholeNumber and (Value >= 0) and (Value <= MAX_ARRAY_LENGTH));
end;

class procedure TJSEngine.DefineFunction(const Target: IJSObject; const Name: string;
                                         const Native: TNativeFunction);
begin
  const Func = TJSFunction.CreateNative(Name, Native);
  const FuncValue = TJSValue.CreateObject(Func);

  Target.SetProperty(Name, FuncValue);
end;

constructor TJSEngine.Create;
begin
  inherited Create;
  FInterpreter := TJSInterpreter.Create;
  FSupport := TJSBuiltinSupport.Create(FInterpreter);
  FFunctionFactory := TJSDynamicFunctionFactory.Create(FInterpreter, FUNCTION_KEYWORD);
  FPrototypeMethods := TJSPrototypeMethods.Create(FInterpreter);
  FBuiltinSets := TObjectList<TJSBuiltinSet>.Create(False);
  FPrograms := TList<TJSProgram>.Create;
  FOnConsoleOutput := nil;
  FInterpreter.RegisterEval(ParseProgram);

  RegisterBuiltInsInHeap;
end;

destructor TJSEngine.Destroy;
begin
  FOnConsoleOutput := nil;

  for var Program_ in FPrograms do
  begin
    Program_.Free;
  end;

  FPrograms.Free;

  if Assigned(FCollectionBuiltins) then
    FCollectionBuiltins.ReleaseCollections;

  if Assigned(FPromiseBuiltins) then
    FPromiseBuiltins.ReleasePromises;

  FPrototypeMethods.Free;
  FDateBuiltins.Free;
  FreeBuiltinSets;
  FFunctionFactory.Free;
  FSupport.Free;
  FArrayIteratorPrototype := nil;
  FInterpreter.Free;
  inherited;
end;

procedure TJSEngine.FreeBuiltinSets;
begin
  if not Assigned(FBuiltinSets) then
    Exit;

  for var Index := FBuiltinSets.Count - 1 downto 0 do
  begin
    FBuiltinSets[Index].Free;
  end;

  FBuiltinSets.Free;
end;

procedure TJSEngine.RegisterBuiltInsInHeap;
begin
  const PreviousHeap = FInterpreter.EnterHeap;
  try
    RegisterBuiltInFunctions;
  finally
    FInterpreter.LeaveHeap(PreviousHeap);
  end;
end;

function TJSEngine.ParseProgram(const Source: string; const IsStrictContext: Boolean;
                                const Context: TJSSourceContext): TJSProgram;
begin
  const Parser = TJSParser.Create(Source);
  try
    Result := Parser.Parse(IsStrictContext, Context);
    FPrograms.Add(Result);

    for var Body in Parser.SuspendableBodies do
    begin
      TJSSuspensionAnalysis.Mark(Body);
    end;
  finally
    Parser.Free;
  end;
end;

function TJSEngine.ParseScript(const Source: string): TJSProgram;
begin
  const ScriptContext = Default(TJSSourceContext);

  Result := ParseProgram(Source, False, ScriptContext);
end;

function TJSEngine.Execute(const Source: string): TJSValue;
begin
  const Script = ParseScript(Source);

  Result := FInterpreter.Execute(Script);
end;

procedure TJSEngine.RunPendingJobs;
begin
  FInterpreter.RunPendingJobs;
end;

procedure TJSEngine.CollectGarbage;
begin
  FInterpreter.CollectGarbage;

  const LiveSet = TDictionary<TObject, Byte>.Create;
  try
    for var LiveProgram in FInterpreter.LivePrograms do
    begin
      LiveSet.AddOrSetValue(LiveProgram, 0);
    end;

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
  const NumberValue = TJSValue.CreateNumber(Value);

  SetVariable(Name, NumberValue);
end;

procedure TJSEngine.SetString(const Name: string; const Value: string);
begin
  const StringValue = TJSValue.CreateString(Value);

  SetVariable(Name, StringValue);
end;

procedure TJSEngine.SetBoolean(const Name: string; const Value: Boolean);
begin
  const BooleanValue = TJSValue.CreateBoolean(Value);

  SetVariable(Name, BooleanValue);
end;

function TJSEngine.GetNumber(const Name: string): Double;
begin
  const Variable = GetVariable(Name);

  Result := Variable.ToNumber;
end;

function TJSEngine.GetString(const Name: string): string;
begin
  const Variable = GetVariable(Name);

  Result := Variable.ToString;
end;

function TJSEngine.GetBoolean(const Name: string): Boolean;
begin
  const Variable = GetVariable(Name);

  Result := Variable.ToBoolean;
end;

procedure TJSEngine.RegisterBuiltInFunctions;
begin
  RegisterGlobalConstants;
  RegisterGlobalFunctions;
  RegisterNumber;
  RegisterString;
  RegisterBoolean;
  RegisterUriFunctions;
  RegisterCoreObjects;
  RegisterCoreBuiltinSets;
  ApplyBuiltinAttributes;
  RegisterExtendedBuiltinSets;
  AssignMissingFunctionPrototypes;
end;

procedure TJSEngine.RegisterGlobalConstants;
begin
  const NotANumber = TJSValue.CreateNaN;
  const PositiveInfinity = TJSValue.CreateInfinity;
  const UndefinedValue = TJSValue.CreateUndefined;

  FInterpreter.SetGlobalConstant(NAN_TEXT, NotANumber);
  FInterpreter.SetGlobalConstant(INFINITY_TEXT, PositiveInfinity);
  FInterpreter.SetGlobalConstant(UNDEFINED_NAME, UndefinedValue);
end;

procedure TJSEngine.RegisterGlobalFunctions;
begin
  FInterpreter.RegisterNativeFunction(PARSE_INT_NAME, GlobalParseInt);
  FInterpreter.RegisterNativeFunction(PARSE_FLOAT_NAME, GlobalParseFloat);
  FInterpreter.RegisterNativeFunction(IS_NAN_TEXT, GlobalIsNaN);
  FInterpreter.RegisterNativeFunction(IS_FINITE_NAME, GlobalIsFinite);
end;

procedure TJSEngine.RegisterUriFunctions;
begin
  RegisterUriFunction(ENCODE_URI_NAME, TJSUriCoding.EncodeURI);
  RegisterUriFunction(DECODE_URI_NAME, TJSUriCoding.DecodeURI);
  RegisterUriFunction(ENCODE_URI_COMPONENT_NAME, TJSUriCoding.EncodeURIComponent);
  RegisterUriFunction(DECODE_URI_COMPONENT_NAME, TJSUriCoding.DecodeURIComponent);

  const GlobalThisValue = TJSValue.CreateObject(FInterpreter.GlobalObject);
  TJSObjectOperations.DefineHiddenData(FInterpreter.GlobalObject, GLOBAL_THIS_NAME, GlobalThisValue);
end;

procedure TJSEngine.RegisterCoreObjects;
begin
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
end;

procedure TJSEngine.RegisterCoreBuiltinSets;
begin
  const RegExpProtocol = TJSRegExpProtocol.Create(FInterpreter);
  AddBuiltinSet(RegExpProtocol);
  const StringPatternMethods = TJSStringPatternMethods.Create(FInterpreter);
  AddBuiltinSet(StringPatternMethods);
  const ObjectBuiltins = TJSObjectBuiltins.Create(FInterpreter);
  AddBuiltinSet(ObjectBuiltins);
end;

procedure TJSEngine.RegisterExtendedBuiltinSets;
begin
  const SymbolBuiltins = TJSSymbolBuiltins.Create(FInterpreter);
  AddBuiltinSet(SymbolBuiltins);
  const IteratorBuiltins = TJSIteratorBuiltins.Create(FInterpreter, FArrayIteratorPrototype);
  AddBuiltinSet(IteratorBuiltins);

  const GeneratorPrototype = FArrayIteratorPrototype.Prototype;
  const GeneratorBuiltins = TJSGeneratorBuiltins.Create(FInterpreter, GeneratorPrototype);
  AddBuiltinSet(GeneratorBuiltins);

  FCollectionBuiltins := TJSCollectionBuiltins.Create(FInterpreter);
  AddBuiltinSet(FCollectionBuiltins);

  const ProxyBuiltins = TJSProxyBuiltins.Create(FInterpreter);
  AddBuiltinSet(ProxyBuiltins);
  const ReflectBuiltins = TJSReflectBuiltins.Create(FInterpreter);
  AddBuiltinSet(ReflectBuiltins);
  const BinaryBuiltins = TJSBinaryBuiltins.Create(FInterpreter);
  AddBuiltinSet(BinaryBuiltins);

  FPromiseBuiltins := TJSPromiseBuiltins.Create(FInterpreter);
  AddBuiltinSet(FPromiseBuiltins);

  const AsyncFunctionBuiltins = TJSAsyncFunctionBuiltins.Create(FInterpreter, FPromiseBuiltins.Operations);
  AddBuiltinSet(AsyncFunctionBuiltins);
end;

procedure TJSEngine.AddBuiltinSet(const BuiltinSet: TJSBuiltinSet);
begin
  FBuiltinSets.Add(BuiltinSet);
  BuiltinSet.Register;
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

function TJSEngine.CreateBuiltinFunction(const Name: string; const Native: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Native);
  Result.IsConstructor := False;
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSEngine.SetGlobalObject(const Name: string; const Value: IJSObject);
begin
  const ObjectValue = TJSValue.CreateObject(Value);

  FInterpreter.SetGlobalVariable(Name, ObjectValue);
end;

function TJSEngine.GlobalObjectNamed(const Name: string): IJSObject;
begin
  const GlobalValue = FInterpreter.GetGlobalVariable(Name);

  Result := GlobalValue.ToObject;
end;

function TJSEngine.GlobalPrototype(const ConstructorName: string): IJSObject;
begin
  Result := nil;

  const ConstructorValue = FInterpreter.GetGlobalVariable(ConstructorName);
  if not ConstructorValue.IsObject then
    Exit;

  const ConstructorObject = ConstructorValue.ToObject;
  const PrototypeValue = ConstructorObject.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsObject then
    Result := PrototypeValue.ToObject;
end;

procedure TJSEngine.AttachPrototypeObject(const Constructor_: IJSFunction; const PrototypeObject: IJSObject);
begin
  const ConstructorValue = TJSValue.CreateObject(Constructor_);
  var ConstructorDescriptor := TJSPropertyDescriptor.Create(ConstructorValue);
  ConstructorDescriptor.Enumerable := False;
  PrototypeObject.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);

  const PrototypeValue = TJSValue.CreateObject(PrototypeObject);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, PrototypeValue);
  FInterpreter.RegisterFunction(Constructor_);
end;

procedure TJSEngine.DefineGlobalConstructor(const Name: string; const Constructor_: IJSFunction;
                                            const PrototypeObject: IJSObject);
begin
  SetGlobalObject(Name, Constructor_);
  AttachPrototypeObject(Constructor_, PrototypeObject);
end;

function TJSEngine.GlobalParseInt(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const TextArgument = TJSArrayLike.Argument(Args, 0);
  const RadixArgument = TJSArrayLike.Argument(Args, 1);
  const Text = FInterpreter.ToStringCoerced(TextArgument);
  const Radix = TJSOperators.ToInt32(RadixArgument);
  const Parsed = TJSNumberParse.ParseInt(Text, Radix);

  Result := TJSValue.CreateNumber(Parsed);
end;

function TJSEngine.GlobalParseFloat(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const TextArgument = TJSArrayLike.Argument(Args, 0);
  const Text = FInterpreter.ToStringCoerced(TextArgument);
  const Parsed = TJSNumberParse.ParseFloat(Text);

  Result := TJSValue.CreateNumber(Parsed);
end;

function TJSEngine.GlobalIsNaN(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Argument = TJSArrayLike.Argument(Args, 0);
  const Number = TJSConversions.ToNumber(Argument);

  const IsNotANumber = System.Math.IsNaN(Number);

  Result := TJSValue.CreateBoolean(IsNotANumber);
end;

function TJSEngine.GlobalIsFinite(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Argument = TJSArrayLike.Argument(Args, 0);
  const Number = TJSConversions.ToNumber(Argument);

  const IsFiniteValue = TJSMathFunctions.IsFiniteNumber(Number);

  Result := TJSValue.CreateBoolean(IsFiniteValue);
end;

procedure TJSEngine.RegisterUriFunction(const Name: string; const Transform: TUriTransform);
begin
  const UriFunction = CreateBuiltinFunction(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = FInterpreter.ToStringCoerced(Argument);
      const Transformed = Transform(Text);

      Result := TJSValue.CreateString(Transformed);
    end);

  SetGlobalObject(Name, UriFunction);
end;

procedure TJSEngine.RegisterNumber;
begin
  const ZeroValue = TJSValue.CreateNumber(0);
  const NumberPrototype: IJSObject = TJSPrimitiveWrapper.Create(ZeroValue);

  const NumberConstructor = TJSFunction.CreateNative(NUMBER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallNumber(This, Args, NumberPrototype);
    end);

  const ParseIntValue = FInterpreter.GetGlobalVariable(PARSE_INT_NAME);
  const ParseFloatValue = FInterpreter.GetGlobalVariable(PARSE_FLOAT_NAME);
  TJSNumericBuiltins.RegisterNumber(NumberConstructor, ParseIntValue, ParseFloatValue);

  DefineGlobalConstructor(NUMBER_NAME, NumberConstructor, NumberPrototype);
end;

procedure TJSEngine.RegisterString;
begin
  const EmptyValue = TJSValue.CreateString(EMPTY_TEXT);
  const StringPrototype: IJSObject = TJSPrimitiveWrapper.Create(EmptyValue);

  const StringConstructor = TJSFunction.CreateNative(STRING_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const IsConstruction = TJSPrototypeMethods.IsConstructCall(This, StringPrototype);
      const HasArgument = (Length(Args) > 0);

      const IsSymbolConversion = (HasArgument and Args[0].IsSymbol and (not IsConstruction));
      if IsSymbolConversion then
      begin
        Result := TJSValue.CreateString(Args[0].SymbolDescriptiveString);
        Exit;
      end;

      var Text := EMPTY_TEXT;
      if HasArgument then
        Text := FInterpreter.ToStringCoerced(Args[0]);

      Result := TJSValue.CreateString(Text);
      if IsConstruction then
        Result := WrapPrimitive(Result);
    end);

  RegisterStringStatics(StringConstructor);
  DefineGlobalConstructor(STRING_NAME, StringConstructor, StringPrototype);
end;

procedure TJSEngine.RegisterStringStatics(const StringConstructor: IJSFunction);
begin
  DefineFunction(StringConstructor, FROM_CHAR_CODE_NAME, StringFromCharCode);

  const RawFunction = CreateBuiltinFunction(RAW_PROPERTY, StringRaw);
  const RawValue = TJSValue.CreateObject(RawFunction);
  StringConstructor.SetProperty(RAW_PROPERTY, RawValue);

  DefineFunction(StringConstructor, FROM_CODE_POINT_NAME, StringFromCodePoint);
end;

procedure TJSEngine.RegisterBoolean;
begin
  const FalseValue = TJSValue.CreateBoolean(False);
  const BooleanPrototype: IJSObject = TJSPrimitiveWrapper.Create(FalseValue);

  const BooleanConstructor = TJSFunction.CreateNative(BOOLEAN_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallBoolean(This, Args, BooleanPrototype);
    end);

  DefineGlobalConstructor(BOOLEAN_NAME, BooleanConstructor, BooleanPrototype);
end;

function TJSEngine.CallNumber(const This: IJSObject; const Args: TArray<TJSValue>;
                              const PrototypeObject: IJSObject): TJSValue;
begin
  var NumberValue := TJSValue.CreateNumber(0);

  const HasArgument = (Length(Args) > 0);
  if HasArgument then
  begin
    const Converted = TJSConversions.ToNumber(Args[0]);
    NumberValue := TJSValue.CreateNumber(Converted);
  end;

  Result := ConstructOrConvert(This, PrototypeObject, NumberValue);
end;

function TJSEngine.CallBoolean(const This: IJSObject; const Args: TArray<TJSValue>;
                               const PrototypeObject: IJSObject): TJSValue;
begin
  var Truthiness := False;

  const HasArgument = (Length(Args) > 0);
  if HasArgument then
    Truthiness := Args[0].ToBoolean;

  const BooleanValue = TJSValue.CreateBoolean(Truthiness);

  Result := ConstructOrConvert(This, PrototypeObject, BooleanValue);
end;

function TJSEngine.ConstructOrConvert(const This: IJSObject; const PrototypeObject: IJSObject;
                                      const Primitive: TJSValue): TJSValue;
begin
  const IsConstruction = TJSPrototypeMethods.IsConstructCall(This, PrototypeObject);

  if IsConstruction then
    Result := WrapPrimitive(Primitive)
  else
    Result := Primitive;
end;

function TJSEngine.WrapPrimitive(const Primitive: TJSValue): TJSValue;
begin
  const Wrapper = FInterpreter.WrapPrimitive(Primitive);
  Result := TJSValue.CreateObject(Wrapper);
end;

function TJSEngine.StringFromCharCode(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var Characters: string;
  SetLength(Characters, Length(Args));

  for var Index := 0 to High(Args) do
  begin
    const CodeUnit = TJSOperators.ToUint32(Args[Index]) and CHAR_CODE_MASK;
    Characters[Index + 1] := Char(CodeUnit);
  end;

  Result := TJSValue.CreateString(Characters);
end;

function TJSEngine.StringFromCodePoint(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Builder = TStringBuilder.Create;
  try
    for var Argument in Args do
    begin
      const CodePoint = ReadCodePoint(Argument);

      const IsBasicPlane = (CodePoint < FIRST_SUPPLEMENTARY_CODE_POINT);
      if IsBasicPlane then
        Builder.Append(Char(CodePoint))
      else
        Builder.Append(Char.ConvertFromUtf32(CodePoint));
    end;

    Result := TJSValue.CreateString(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

function TJSEngine.ReadCodePoint(const Argument: TJSValue): Integer;
begin
  const Number = TJSConversions.ToNumber(Argument);

  const IsInRange = ((Number >= 0) and (Number <= MAX_CODE_POINT));
  const IsValidCodePoint = (TJSMathFunctions.IsInteger(Number) and IsInRange);
  if not IsValidCodePoint then
  begin
    const Message = Format(INVALID_CODE_POINT, [Argument.ToString]);
    raise TJSErrorFactory.RangeError(Message);
  end;

  Result := Trunc(Number);
end;

function TJSEngine.StringRaw(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const RawText = ConcatenateRawStrings(Args);

  Result := TJSValue.CreateString(RawText);
end;

function TJSEngine.ConcatenateRawStrings(const Args: TArray<TJSValue>): string;
begin
  const CookedArgument = TJSArrayLike.Argument(Args, 0);
  const Cooked = FSupport.ToObject(CookedArgument);
  const RawValue = Cooked.GetProperty(RAW_PROPERTY);
  const Raw = FSupport.ToObject(RawValue);
  const SegmentCount = TJSArrayLike.ToLength(Raw);
  FInterpreter.Limits.EnsureArrayLength(SegmentCount);

  const Builder = TStringBuilder.Create;
  try
    for var Index: Int64 := 0 to SegmentCount - 1 do
    begin
      const SegmentName = TJSArrayLike.IndexName(Index);
      const Segment = Raw.GetProperty(SegmentName);
      const SegmentText = FInterpreter.ToStringCoerced(Segment);
      Builder.Append(SegmentText);

      const IsLastSegment = (Index = SegmentCount - 1);
      const HasSubstitution = (Index + 1 < Length(Args));
      const NeedsSubstitution = ((not IsLastSegment) and HasSubstitution);
      if NeedsSubstitution then
      begin
        const SubstitutionText = FInterpreter.ToStringCoerced(Args[Index + 1]);
        Builder.Append(SubstitutionText);
      end;

      FInterpreter.Limits.EnsureStringLength(Builder.Length);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

procedure TJSEngine.RegisterConsole;
begin
  const ConsoleObject = TJSObject.Create;
  const LogFunction = TJSFunction.CreateNative(CONSOLE_LOG, ConsoleLog);
  const LogValue = TJSValue.CreateObject(LogFunction);

  ConsoleObject.SetProperty(CONSOLE_LOG, LogValue);
  ConsoleObject.SetProperty(CONSOLE_ERROR, LogValue);
  ConsoleObject.SetProperty(CONSOLE_WARN, LogValue);
  ConsoleObject.SetProperty(CONSOLE_INFO, LogValue);

  SetGlobalObject(CONSOLE_NAME, ConsoleObject);
end;

function TJSEngine.ConsoleLog(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var Parts: TArray<string>;
  SetLength(Parts, Length(Args));

  for var Index := 0 to High(Args) do
  begin
    Parts[Index] := ConsoleArgumentText(Args[Index]);
  end;

  WriteConsoleLine(string.Join(CONSOLE_ARGUMENT_SEPARATOR, Parts));

  Result := TJSValue.CreateUndefined;
end;

function TJSEngine.ConsoleArgumentText(const Argument: TJSValue): string;
begin
  if Argument.IsSymbol then
    Result := Argument.SymbolDescriptiveString
  else
    Result := FInterpreter.ToStringCoerced(Argument);
end;

procedure TJSEngine.WriteConsoleLine(const Line: string);
begin
  if Assigned(FOnConsoleOutput) then
    FOnConsoleOutput(Line)
  else
    WriteLn(Line);
end;

procedure TJSEngine.RegisterMath;
begin
  const MathObject: IJSObject = TJSObject.Create;
  TJSNumericBuiltins.RegisterMath(MathObject);

  SetGlobalObject(MATH_NAME, MathObject);
end;

procedure TJSEngine.RegisterObject;
begin
  const PrototypeObject = TJSObject.Create;
  PrototypeObject.HasImmutablePrototype := True;

  const ObjectConstructor = TJSFunction.CreateNative(OBJECT_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructObject(Args, PrototypeObject);
    end);

  SetGlobalObject(OBJECT_NAME, ObjectConstructor);
  const ObjectStatics = TJSObjectStatics.Create(FInterpreter);
  AddBuiltinSet(ObjectStatics);
  RegisterObjectPrototypeMethods(PrototypeObject);
  AttachPrototypeObject(ObjectConstructor, PrototypeObject);
end;

procedure TJSEngine.RegisterObjectPrototypeMethods(const PrototypeObject: IJSObject);
begin
  for var MethodName in TJSBuiltins.ObjectMethodNames do
  begin
    const Method = CreateObjectPrototypeMethod(MethodName);
    const MethodValue = TJSValue.CreateObject(Method);

    PrototypeObject.SetProperty(MethodName, MethodValue);
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.ObjectMethod, MethodName, Method);
  end;
end;

function TJSEngine.CreateObjectPrototypeMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if not Assigned(This) then
        RaiseCalledWithoutThis(MethodName, Args);

      Result := TJSBuiltins.CallObjectMethod(This, MethodName, Args, FInterpreter.Limits);
    end);
end;

procedure TJSEngine.RaiseCalledWithoutThis(const MethodName: string; const Args: TArray<TJSValue>);
begin
  const TakesPropertyKey = (TJSBuiltins.HasObjectMethod(MethodName) and (Length(Args) > 0));
  if TakesPropertyKey then
    CoercePropertyKeyForSideEffects(Args[0]);

  const Message = Format(NOT_CALLED_ON_OBJECT, [MethodName]);
  raise TJSErrorFactory.TypeError(Message);
end;

procedure TJSEngine.CoercePropertyKeyForSideEffects(const Value: TJSValue);
begin
  Value.ToPropertyKey(FInterpreter.Limits);
end;

function TJSEngine.ConstructObject(const Args: TArray<TJSValue>; const PrototypeObject: IJSObject): TJSValue;
begin
  const Argument = TJSArrayLike.Argument(Args, 0);

  if Argument.IsObject then
  begin
    Result := Argument;
    Exit;
  end;

  if not Argument.IsNullOrUndefined then
  begin
    const Wrapper = FInterpreter.WrapPrimitive(Argument);
    Result := TJSValue.CreateObject(Wrapper);
    Exit;
  end;

  const Created = TJSObject.Create;
  Created.Prototype := PrototypeObject;

  Result := TJSValue.CreateObject(Created);
end;

procedure TJSEngine.RegisterJSON;
begin
  const JsonObject = TJSObject.Create;

  DefineFunction(JsonObject, JSON_PARSE, JsonParse);
  DefineFunction(JsonObject, JSON_STRINGIFY, JsonStringify);

  SetGlobalObject(JSON_NAME, JsonObject);
end;

function TJSEngine.JsonParse(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const TextArgument = TJSArrayLike.Argument(Args, 0);
  const ReviverArgument = TJSArrayLike.Argument(Args, 1);
  const JsonText = FInterpreter.ToStringCoerced(TextArgument);

  Result := TJSJsonReader.Read(JsonText, FInterpreter.ObjectPrototype, FInterpreter.ArrayPrototype);

  var Reviver: IJSFunction;
  const HasReviver = ReviverArgument.TryGetFunction(Reviver);
  if HasReviver then
    Result := TJSJsonReviver.Revive(Result, Reviver, FInterpreter.ObjectPrototype, FInterpreter.Limits);
end;

function TJSEngine.JsonStringify(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Value = TJSArrayLike.Argument(Args, 0);
  const Replacer = TJSArrayLike.Argument(Args, 1);
  const Space = TJSArrayLike.Argument(Args, 2);

  const Writer = TJSJsonWriter.Create(FInterpreter.Limits, FInterpreter.ObjectPrototype);
  try
    var JsonText: string;
    const HasText = Writer.TryStringify(Value, Replacer, Space, JsonText);

    if HasText then
      Result := TJSValue.CreateString(JsonText)
    else
      Result := TJSValue.CreateUndefined;
  finally
    Writer.Free;
  end;
end;

procedure TJSEngine.RegisterArray;
begin
  const PrototypeObject: IJSObject = TJSArray.Create;

  const ArrayConstructor = TJSFunction.CreateNative(ARRAY_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructArray(Args, PrototypeObject);
    end);

  RegisterArrayStatics(ArrayConstructor);
  RegisterArrayPrototypeMethods(PrototypeObject);
  RegisterArrayIterators(PrototypeObject);

  AttachPrototypeObject(ArrayConstructor, PrototypeObject);
  SetGlobalObject(ARRAY_NAME, ArrayConstructor);
end;

procedure TJSEngine.RegisterArrayStatics(const ArrayConstructor: IJSFunction);
begin
  DefineFunction(ArrayConstructor, ARRAY_IS_ARRAY, ArrayIsArray);

  for var StaticName in [ARRAY_OF, ARRAY_FROM] do
  begin
    const StaticMethod = CreateArrayStaticMethod(StaticName);
    const StaticValue = TJSValue.CreateObject(StaticMethod);

    ArrayConstructor.SetProperty(StaticName, StaticValue);
  end;
end;

procedure TJSEngine.RegisterArrayPrototypeMethods(const PrototypeObject: IJSObject);
begin
  for var MethodName in TJSBuiltins.ArrayMethodNames do
  begin
    const Method = CreateArrayPrototypeMethod(MethodName);
    Method.IntrinsicRole := ArrayIntrinsicRole(MethodName);

    const MethodValue = TJSValue.CreateObject(Method);
    PrototypeObject.SetProperty(MethodName, MethodValue);
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.ArrayMethod, MethodName, Method);
  end;

  const LocaleStringMethod = CreateArrayPrototypeMethod(ARRAY_TO_LOCALE_STRING);
  const LocaleStringValue = TJSValue.CreateObject(LocaleStringMethod);
  PrototypeObject.SetProperty(ARRAY_TO_LOCALE_STRING, LocaleStringValue);
end;

procedure TJSEngine.RegisterArrayIterators(const PrototypeObject: IJSObject);
begin
  const IteratorPrototype: IJSObject = TJSObject.Create;
  IteratorPrototype.Prototype := FInterpreter.ObjectPrototype;

  const NextFunction = TJSFunction.CreateNative(ITERATOR_NEXT, ArrayIteratorNext);
  const NextValue = TJSValue.CreateObject(NextFunction);
  TJSObjectOperations.DefineHiddenData(IteratorPrototype, ITERATOR_NEXT, NextValue);
  FArrayIteratorPrototype := IteratorPrototype;

  const KeysMethod = CreateArrayIteratorFactory(KEYS_PROPERTY, TJSArrayIteratorKind.Keys, IteratorPrototype);
  const ValuesMethod = CreateArrayIteratorFactory(VALUES_PROPERTY, TJSArrayIteratorKind.Values, IteratorPrototype);
  const EntriesMethod = CreateArrayIteratorFactory(ENTRIES_PROPERTY, TJSArrayIteratorKind.Entries, IteratorPrototype);

  const KeysValue = TJSValue.CreateObject(KeysMethod);
  const ValuesValue = TJSValue.CreateObject(ValuesMethod);
  const EntriesValue = TJSValue.CreateObject(EntriesMethod);

  PrototypeObject.SetProperty(KEYS_PROPERTY, KeysValue);
  PrototypeObject.SetProperty(VALUES_PROPERTY, ValuesValue);
  PrototypeObject.SetProperty(ENTRIES_PROPERTY, EntriesValue);
end;

function TJSEngine.ArrayIsArray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Argument = TJSArrayLike.Argument(Args, 0);
  const IsArray = TJSObjectOperations.IsArray(Argument);

  Result := TJSValue.CreateBoolean(IsArray);
end;

function TJSEngine.ArrayIteratorNext(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var Iterator: IJSArrayIterator;
  const IsArrayIterator = Supports(This, IJSArrayIterator, Iterator);
  if not IsArrayIterator then
    raise TJSErrorFactory.TypeError(ITERATOR_NOT_AN_ARRAY_ITERATOR);

  Result := Iterator.NextResult;
end;

function TJSEngine.CreateArrayStaticMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FInterpreter.ExecuteArrayStaticMethod(This, MethodName, Args);
    end);
end;

function TJSEngine.CreateArrayPrototypeMethod(const MethodName: string): IJSFunction;
begin
  const IsLocaleString = (MethodName = ARRAY_TO_LOCALE_STRING);
  const IsIteration = TJSArrayIteration.Handles(MethodName);

  if IsLocaleString then
    Result := CreateGenericArrayMethod(MethodName)
  else if IsIteration then
    Result := CreateIterationArrayMethod(MethodName)
  else
    Result := CreateArrayOrGenericMethod(MethodName);
end;

function TJSEngine.CreateGenericArrayMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FInterpreter.ExecuteGenericArrayMethod(This, MethodName, Args);
    end);
end;

function TJSEngine.CreateIterationArrayMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FInterpreter.ExecuteArrayIterationMethod(This, MethodName, Args);
    end);
end;

function TJSEngine.CreateArrayOrGenericMethod(const MethodName: string): IJSFunction;
begin
  const SupportsGeneric = TJSArrayGeneric.Handles(MethodName);

  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Target: IJSArray;
      const IsArray = Supports(This, IJSArray, Target);

      if IsArray then
      begin
        Result := FInterpreter.ExecuteArrayMethod(Target, MethodName, Args);
      end
      else if SupportsGeneric then
      begin
        Result := FInterpreter.ExecuteGenericArrayMethod(This, MethodName, Args);
      end
      else
      begin
        const Message = Format(NOT_CALLED_ON_ARRAY, [MethodName]);
        raise TJSErrorFactory.TypeError(Message);
      end;
    end);
end;

function TJSEngine.CreateArrayIteratorFactory(const MethodName: string; const Kind: TJSArrayIteratorKind;
                                              const IteratorPrototype: IJSObject): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if not Assigned(This) then
      begin
        const Message = Format(NOT_CALLED_ON_OBJECT, [MethodName]);
        raise TJSErrorFactory.TypeError(Message);
      end;

      const Iterator = TJSArrayIterator.Create(This, Kind, FInterpreter.ArrayPrototype, FInterpreter.ObjectPrototype);
      Iterator.Prototype := IteratorPrototype;
      Result := TJSValue.CreateObject(Iterator);
    end);
end;

function TJSEngine.ConstructArray(const Args: TArray<TJSValue>; const PrototypeObject: IJSObject): TJSValue;
begin
  const Created: IJSArray = TJSArray.Create;
  Created.Prototype := PrototypeObject;

  const IsLengthForm = ((Length(Args) = 1) and Args[0].IsNumber);
  if IsLengthForm then
  begin
    const RequestedLength = Args[0].AsNumber;
    if not IsValidArrayLength(RequestedLength) then
      raise TJSErrorFactory.InvalidArrayLength;

    const ElementCount = Trunc(RequestedLength);
    FInterpreter.Limits.EnsureArrayLength(ElementCount);

    const LengthValue = TJSValue.CreateNumber(ElementCount);
    const LengthDefinition = TJSPropertyDefinition.ForValue(LengthValue);
    Created.DefineOwnProperty(LENGTH_PROPERTY, LengthDefinition);
  end
  else
  begin
    for var Argument in Args do
    begin
      Created.Push(Argument);
    end;
  end;

  Result := TJSValue.CreateObject(Created);
end;

procedure TJSEngine.RegisterDate;
begin
  const PrototypeObject: IJSObject = TJSObject.Create;

  FDateBuiltins := TJSDateBuiltins.Create(PrototypeObject);
  const DateConstructor = FDateBuiltins.CreateConstructor;

  SetGlobalObject(DATE_NAME, DateConstructor);
  AttachPrototypeObject(DateConstructor, PrototypeObject);
end;

procedure TJSEngine.RegisterErrors;
begin
  for var ErrorType := Low(TJSErrorType) to High(TJSErrorType) do
  begin
    const ErrorName = ErrorType.Name;
    const ErrorConstructor = CreateErrorConstructor(ErrorType, ErrorName);

    SetGlobalObject(ErrorName, ErrorConstructor);
  end;
end;

function TJSEngine.CreateErrorConstructor(const ErrorType: TJSErrorType; const ErrorName: string): IJSFunction;
begin
  const PrototypeObject: IJSObject = TJSObject.Create;
  const NameValue = TJSValue.CreateString(ErrorName);
  const EmptyMessage = TJSValue.CreateString(EMPTY_TEXT);
  TJSObjectOperations.DefineHiddenData(PrototypeObject, NAME_PROPERTY, NameValue);
  TJSObjectOperations.DefineHiddenData(PrototypeObject, MESSAGE_PROPERTY, EmptyMessage);

  Result := TJSFunction.CreateNative(ErrorName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructError(ErrorType, PrototypeObject, Args);
    end);

  AttachPrototypeObject(Result, PrototypeObject);
end;

function TJSEngine.ConstructError(const ErrorType: TJSErrorType; const PrototypeObject: IJSObject;
                                  const Args: TArray<TJSValue>): TJSValue;
begin
  const MessageArgument = TJSArrayLike.Argument(Args, 0);
  const HasMessage = (not MessageArgument.IsUndefined);

  var MessageText := EMPTY_TEXT;
  if HasMessage then
    MessageText := FInterpreter.ToStringCoerced(MessageArgument);

  const ErrorInstance: IJSError = TJSError.Create(ErrorType, MessageText);
  ErrorInstance.Prototype := PrototypeObject;

  if HasMessage then
  begin
    const MessageValue = TJSValue.CreateString(MessageText);
    TJSObjectOperations.DefineHiddenData(ErrorInstance, MESSAGE_PROPERTY, MessageValue);
  end;

  Result := TJSValue.CreateObject(ErrorInstance);
end;

procedure TJSEngine.RegisterRegExp;
begin
  const PrototypeObject: IJSObject = TJSObject.Create;

  const RegExpConstructor = TJSFunction.CreateNative(REGEXP_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallRegExp(This, Args, PrototypeObject);
    end);

  SetGlobalObject(REGEXP_NAME, RegExpConstructor);
  AttachPrototypeObject(RegExpConstructor, PrototypeObject);
end;

function TJSEngine.CallRegExp(const This: IJSObject; const Args: TArray<TJSValue>;
                              const PrototypeObject: IJSObject): TJSValue;
begin
  const PatternArgument = TJSArrayLike.Argument(Args, 0);
  const FlagsArgument = TJSArrayLike.Argument(Args, 1);

  const IsPlainCall = not TJSPrototypeMethods.IsConstructCall(This, PrototypeObject);
  const PatternIsRegExp = TJSConversions.IsRegExpLike(PatternArgument);
  const HasFlags = not FlagsArgument.IsUndefined;
  const ReturnsPattern = (IsPlainCall and
                          PatternIsRegExp and
                          (not HasFlags) and
                          HasSameRegExpConstructor(PatternArgument, PrototypeObject));
  if ReturnsPattern then
  begin
    Result := PatternArgument;
    Exit;
  end;

  const Source = ReadRegExpSource(PatternArgument, FlagsArgument, PatternIsRegExp);

  const RegExpInstance: IJSRegExp = TJSRegExp.Create(Source.Pattern, Source.Flags);
  RegExpInstance.Prototype := PrototypeObject;
  Result := TJSValue.CreateObject(RegExpInstance);
end;

function TJSEngine.HasSameRegExpConstructor(const Pattern: TJSValue; const PrototypeObject: IJSObject): Boolean;
begin
  const PatternObject = Pattern.ToObject;
  const PatternConstructor = PatternObject.GetProperty(CONSTRUCTOR_PROPERTY);
  const RegExpConstructor = PrototypeObject.GetProperty(CONSTRUCTOR_PROPERTY);

  Result := PatternConstructor.StrictEquals(RegExpConstructor);
end;

function TJSEngine.ReadRegExpSource(const PatternArgument: TJSValue; const FlagsArgument: TJSValue;
                                    const PatternIsRegExp: Boolean): TRegExpSource;
begin
  var SourceValue := PatternArgument;
  var FlagsValue := FlagsArgument;

  var BuiltIn: IJSRegExp;
  const IsBuiltInRegExp = (PatternArgument.IsObject and Supports(PatternArgument.ToObject, IJSRegExp, BuiltIn));

  if IsBuiltInRegExp then
  begin
    SourceValue := TJSValue.CreateString(BuiltIn.Pattern);
    if FlagsArgument.IsUndefined then
      FlagsValue := TJSValue.CreateString(BuiltIn.Flags);
  end
  else if PatternIsRegExp then
  begin
    const PatternObject = PatternArgument.ToObject;
    SourceValue := PatternObject.GetProperty(SOURCE_PROPERTY);
    if FlagsArgument.IsUndefined then
      FlagsValue := PatternObject.GetProperty(FLAGS_PROPERTY);
  end;

  Result.Pattern := EMPTY_TEXT;
  if not SourceValue.IsUndefined then
    Result.Pattern := FInterpreter.ToStringCoerced(SourceValue);

  Result.Flags := EMPTY_TEXT;
  if not FlagsValue.IsUndefined then
    Result.Flags := FInterpreter.ToStringCoerced(FlagsValue);
end;

procedure TJSEngine.RegisterFunctionObject;
begin
  const FunctionConstructor = TJSFunction.CreateNative(FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FFunctionFactory.CreateFunction(Args);
    end);

  const PrototypeObject: IJSFunction = TJSFunction.CreateNative(EMPTY_TEXT,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateUndefined;
    end);
  PrototypeObject.IsConstructor := False;
  TJSFunction.DefineLength(PrototypeObject, 0);
  FInterpreter.RegisterFunction(PrototypeObject);

  for var MethodName in [FUNCTION_CALL, FUNCTION_APPLY, FUNCTION_BIND] do
  begin
    const Method = CreateFunctionPrototypeMethod(MethodName);
    const MethodValue = TJSValue.CreateObject(Method);

    PrototypeObject.SetProperty(MethodName, MethodValue);
    FInterpreter.RegisterIntrinsicMethod(TJSIntrinsicGroup.FunctionMethod, MethodName, Method);
  end;

  AttachPrototypeObject(FunctionConstructor, PrototypeObject);
  SetGlobalObject(FUNCTION_NAME, FunctionConstructor);
end;

function TJSEngine.CreateFunctionPrototypeMethod(const MethodName: string): IJSFunction;
begin
  Result := TJSFunction.CreateNative(MethodName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Target: IJSFunction;
      const IsFunction = Supports(This, IJSFunction, Target);
      if not IsFunction then
      begin
        const Message = Format(NOT_CALLED_ON_FUNCTION, [MethodName]);
        raise TJSErrorFactory.TypeError(Message);
      end;

      Result := FInterpreter.ExecuteFunctionMethod(Target, MethodName, Args);
    end);
end;

procedure TJSEngine.DefineRestrictedFunctionProperties(const PrototypeObject: IJSObject);
begin
  const Undefined = TJSValue.CreateUndefined;
  const Poison = TJSValue.CreateObject(FInterpreter.ThrowTypeErrorFunction);

  for var PropertyName in [FUNCTION_CALLER, ARGUMENTS_NAME] do
  begin
    var Descriptor := TJSPropertyDescriptor.Create(Undefined);
    Descriptor.IsAccessor := True;
    Descriptor.Getter := Poison;
    Descriptor.Setter := Poison;
    Descriptor.Enumerable := False;
    PrototypeObject.DefineProperty(PropertyName, Descriptor);
  end;
end;

procedure TJSEngine.RegisterPrototypeMethods;
begin
  const ObjectPrototype = GlobalPrototype(OBJECT_NAME);
  const StringPrototype = GlobalPrototype(STRING_NAME);
  const NumberPrototype = GlobalPrototype(NUMBER_NAME);
  const BooleanPrototype = GlobalPrototype(BOOLEAN_NAME);
  const ErrorPrototype = GlobalPrototype(TJSErrorType.Error.Name);
  const RegExpPrototype = GlobalPrototype(REGEXP_NAME);
  const FunctionPrototype = GlobalPrototype(FUNCTION_NAME);

  FPrototypeMethods.RegisterObjectMethods(ObjectPrototype);
  FPrototypeMethods.RegisterStringMethods(StringPrototype);
  FPrototypeMethods.RegisterNumberMethods(NumberPrototype);
  FPrototypeMethods.RegisterBooleanMethods(BooleanPrototype);
  FPrototypeMethods.RegisterErrorMethods(ErrorPrototype);
  FPrototypeMethods.RegisterRegExpMethods(RegExpPrototype);
  FPrototypeMethods.RegisterFunctionMethods(FunctionPrototype);

  FInterpreter.StringPrototype := StringPrototype;
  FInterpreter.NumberPrototype := NumberPrototype;
  FInterpreter.BooleanPrototype := BooleanPrototype;
end;

procedure TJSEngine.LinkIntrinsicPrototypes;
begin
  const ObjectPrototype = GlobalPrototype(OBJECT_NAME);
  const FunctionPrototype = GlobalPrototype(FUNCTION_NAME);

  for var ConstructorName in [TJSErrorType.Error.Name, ARRAY_NAME, FUNCTION_NAME, DATE_NAME, REGEXP_NAME,
                              NUMBER_NAME, STRING_NAME, BOOLEAN_NAME] do
  begin
    const Prototype = GlobalPrototype(ConstructorName);
    Prototype.Prototype := ObjectPrototype;
  end;

  LinkErrorPrototypes;
  LinkGlobalObjectPrototypes(ObjectPrototype);

  FInterpreter.GlobalObject.Prototype := ObjectPrototype;
  FInterpreter.ObjectPrototype := ObjectPrototype;
  FInterpreter.ArrayPrototype := GlobalPrototype(ARRAY_NAME);
  FInterpreter.FunctionPrototype := FunctionPrototype;
  FInterpreter.RegExpPrototype := GlobalPrototype(REGEXP_NAME);

  DefineRestrictedFunctionProperties(FunctionPrototype);
end;

procedure TJSEngine.LinkErrorPrototypes;
begin
  const ErrorName = TJSErrorType.Error.Name;
  const ErrorPrototype = GlobalPrototype(ErrorName);
  const ErrorConstructor = GlobalObjectNamed(ErrorName);

  for var ErrorType := Succ(Low(TJSErrorType)) to High(TJSErrorType) do
  begin
    const NativeErrorName = ErrorType.Name;
    const NativeErrorPrototype = GlobalPrototype(NativeErrorName);
    NativeErrorPrototype.Prototype := ErrorPrototype;

    const NativeErrorConstructor = GlobalObjectNamed(NativeErrorName);
    NativeErrorConstructor.Prototype := ErrorConstructor;
  end;
end;

procedure TJSEngine.LinkGlobalObjectPrototypes(const ObjectPrototype: IJSObject);
begin
  for var GlobalName in [MATH_NAME, JSON_NAME] do
  begin
    const GlobalObjectValue = GlobalObjectNamed(GlobalName);
    GlobalObjectValue.Prototype := ObjectPrototype;
  end;
end;

procedure TJSEngine.AssignMissingFunctionPrototypes;
begin
  const Pending = TStack<IJSObject>.Create;
  const Visited = THashSet<Pointer>.Create;
  try
    Pending.Push(FInterpreter.GlobalObject);
    if Assigned(FArrayIteratorPrototype) then
      Pending.Push(FArrayIteratorPrototype);

    while HasPendingTargets(Pending) do
    begin
      const Target = Pending.Pop;

      const Identity = TJSObjectOperations.IdentityOf(Target);
      const IsFirstVisit = Visited.Add(Identity);
      if IsFirstVisit then
        AssignFunctionPrototype(Target, Pending);
    end;
  finally
    Visited.Free;
    Pending.Free;
  end;
end;

class function TJSEngine.HasPendingTargets(const Pending: TStack<IJSObject>): Boolean;
begin
  Result := (Pending.Count > 0);
end;

procedure TJSEngine.AssignFunctionPrototype(const Target: IJSObject; const Pending: TStack<IJSObject>);
begin
  const IsFunctionPrototype = TJSObjectOperations.IsSameObject(Target, FInterpreter.FunctionPrototype);
  const NeedsPrototype = (Supports(Target, IJSFunction) and
                          (not Assigned(Target.Prototype)) and
                          (not IsFunctionPrototype));
  if NeedsPrototype then
    Target.Prototype := FInterpreter.FunctionPrototype;

  if Assigned(Target.Prototype) then
    Pending.Push(Target.Prototype);

  for var Name in Target.GetOwnPropertyNames do
  begin
    QueueMemberObjects(Target, Name, Pending);
  end;

  for var Key in Target.GetOwnSymbolKeysInCreationOrder do
  begin
    QueueMemberObjects(Target, Key, Pending);
  end;
end;

procedure TJSEngine.QueueMemberObjects(const Target: IJSObject; const Name: TJSPropertyKey;
                                       const Pending: TStack<IJSObject>);
begin
  const Descriptor = Target.GetOwnPropertyDescriptor(Name);

  for var Member in [Descriptor.Value, Descriptor.Getter, Descriptor.Setter] do
  begin
    if Member.IsObject then
      Pending.Push(Member.AsObject);
  end;
end;

end.
