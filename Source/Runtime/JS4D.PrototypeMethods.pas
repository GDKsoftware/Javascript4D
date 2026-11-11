unit JS4D.PrototypeMethods;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.ArgumentsObject,
  JS4D.Interpreter,
  JS4D.Builtins;

type
  TRegExpReader = reference to function(const RegExpObj: IJSRegExp): TJSValue;

  TJSPrototypeMethods = class
  private
    FInterpreter: TJSInterpreter;
    FMathObject: IJSObject;
    FJSONObject: IJSObject;

    procedure DefineMethod(const PrototypeObj: IJSObject; const MethodName: string; const Method: TNativeFunction);
    function ObjectToPrimitive(const Source: IJSObject; const PreferString: Boolean): TJSValue;
    function ObjectToText(const Source: IJSObject): string;
    function ValueToText(const Value: TJSValue): string;
    function PropertyToText(const Source: IJSObject; const PropertyName: string; const DefaultText: string): string;
    function ConvertArgumentToPrimitive(const Arg: TJSValue; const PreferString: Boolean): TJSValue;
    function ConvertArgumentsToPrimitives(const Args: TArray<TJSValue>; const PreferString: Boolean): TArray<TJSValue>;
    function ConvertStringArgument(const MethodName: string; const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
    function ConvertStringArguments(const MethodName: string; const Args: TArray<TJSValue>): TArray<TJSValue>;
    function ThisToText(const This: IJSObject; const MethodName: string): string;
    procedure RejectRegExpSearchString(const MethodName: string; const Args: TArray<TJSValue>);
    function ThisToPrimitive(const This: IJSObject; const TypeName: string; const MethodName: string): TJSValue;
    function TryFormatLocaleNumber(const NumberValue: Double; const Args: TArray<TJSValue>; out Text: string): Boolean;
    function ClassTagOf(const Source: IJSObject): string;

    function ObjectToString(const This: IJSObject): TJSValue;
    function ObjectToLocaleString(const This: IJSObject): TJSValue;
    function ObjectValueOf(const This: IJSObject): TJSValue;
    function ObjectIsPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function ErrorToString(const This: IJSObject): TJSValue;
    function RegExpToString(const This: IJSObject): TJSValue;
    function RegExpFlags(const This: IJSObject): TJSValue;
    function RegExpFlagValue(const This: IJSObject; const PrototypeIdentity: Pointer; const PropertyName: string;
                             const FromRegExp: TRegExpReader): TJSValue;
    procedure DefineGetter(const Target: IJSObject; const PropertyName: string; const Getter: TNativeFunction);
    procedure DefineRegExpFlagGetter(const PrototypeObj: IJSObject; const PropertyName: string;
                                     const FromRegExp: TRegExpReader);
    procedure RegisterRegExpAccessors(const PrototypeObj: IJSObject);
    function RegExpExec(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function FunctionToString(const This: IJSObject): TJSValue;

    function CallStringMethod(const This: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function CallNumberMethod(const This: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
    function CallBooleanMethod(const This: IJSObject; const MethodName: string): TJSValue;

    function BindStringMethod(const MethodName: string): TNativeFunction;
    function BindNumberMethod(const MethodName: string): TNativeFunction;
    function BindBooleanMethod(const MethodName: string): TNativeFunction;

  public
    constructor Create(const Interpreter: TJSInterpreter);

    class function IsConstructCall(const This: IJSObject; const PrototypeObj: IJSObject): Boolean; static;

    procedure RegisterObjectMethods(const PrototypeObj: IJSObject; const MathObj: IJSObject; const JSONObj: IJSObject);
    procedure RegisterStringMethods(const PrototypeObj: IJSObject);
    procedure RegisterNumberMethods(const PrototypeObj: IJSObject);
    procedure RegisterBooleanMethods(const PrototypeObj: IJSObject);
    procedure RegisterErrorMethods(const PrototypeObj: IJSObject);
    procedure RegisterRegExpMethods(const PrototypeObj: IJSObject);
    procedure RegisterFunctionMethods(const PrototypeObj: IJSObject);
  end;

implementation

uses
  JS4D.LocaleArguments,
  JS4D.LocaleNumberFormat;

type
  TRegExpFlagProperty = record
    Name: string;
    Flag: Char;
  end;

const
  METHOD_TO_STRING = 'toString';
  METHOD_VALUE_OF = 'valueOf';
  METHOD_TO_LOCALE_STRING = 'toLocaleString';
  METHOD_IS_PROTOTYPE_OF = 'isPrototypeOf';
  METHOD_EXEC = 'exec';
  METHOD_TEST = 'test';
  METHOD_SPLIT = 'split';
  METHOD_STARTS_WITH = 'startsWith';
  METHOD_ENDS_WITH = 'endsWith';
  METHOD_INCLUDES = 'includes';
  REGEXP_SEARCH_STRING_MESSAGE = 'First argument to String.prototype.%s must not be a regular expression';
  TYPE_NAME_STRING = 'String';
  TYPE_NAME_NUMBER = 'Number';
  TYPE_NAME_BOOLEAN = 'Boolean';
  CLASS_TAG_FORMAT = '[object %s]';
  CLASS_UNDEFINED = 'Undefined';
  CLASS_OBJECT = 'Object';
  CLASS_ARRAY = 'Array';
  CLASS_FUNCTION = 'Function';
  CLASS_ARGUMENTS = 'Arguments';
  CLASS_DATE = 'Date';
  CLASS_REGEXP = 'RegExp';
  CLASS_ERROR = 'Error';
  CLASS_MATH = 'Math';
  CLASS_JSON = 'JSON';
  CALLED_ON_NULL_OR_UNDEFINED = '%s.prototype.%s called on null or undefined';
  CALLED_ON_INCOMPATIBLE_TYPE = '%s.prototype.%s called on an incompatible receiver';
  CANNOT_CONVERT_TO_PRIMITIVE = 'Cannot convert object to primitive value';
  NOT_A_REGEXP = 'RegExp.prototype.toString called on a value that is not a regular expression';
  NOT_A_REGEXP_RECEIVER = 'RegExp.prototype method called on a value that is not a regular expression';
  NOT_A_REGEXP_GETTER_RECEIVER = 'RegExp.prototype.%s getter called on a value that is not a regular expression';
  FLAGS_ON_NON_OBJECT = 'RegExp.prototype.flags getter called on a value that is not an object';
  GETTER_NAME_FORMAT = 'get %s';
  PROPERTY_FLAGS = 'flags';
  PROPERTY_DOT_ALL = 'dotAll';
  PROPERTY_GLOBAL = 'global';
  PROPERTY_HAS_INDICES = 'hasIndices';
  PROPERTY_IGNORE_CASE = 'ignoreCase';
  PROPERTY_MULTILINE = 'multiline';
  PROPERTY_STICKY = 'sticky';
  PROPERTY_UNICODE = 'unicode';
  PROPERTY_SOURCE = 'source';
  EMPTY_PATTERN_SOURCE = '(?:)';
  REGEXP_FLAG_PROPERTIES: array[0..6] of TRegExpFlagProperty = (
    (Name: PROPERTY_HAS_INDICES; Flag: 'd'),
    (Name: PROPERTY_GLOBAL; Flag: 'g'),
    (Name: PROPERTY_IGNORE_CASE; Flag: 'i'),
    (Name: PROPERTY_MULTILINE; Flag: 'm'),
    (Name: PROPERTY_DOT_ALL; Flag: 's'),
    (Name: PROPERTY_UNICODE; Flag: 'u'),
    (Name: PROPERTY_STICKY; Flag: 'y')
  );
  UNDEFINED_TEXT = 'undefined';
  NOT_A_FUNCTION = 'Function.prototype.toString called on a value that is not a function';
  ERROR_TO_STRING_ON_NON_OBJECT = 'Error.prototype.toString called on a value that is not an object';
  REGEXP_FORMAT = '/%s/%s';
  NATIVE_FUNCTION_FORMAT = 'function %s() { [native code] }';
  PROPERTY_NAME = 'name';
  PROPERTY_MESSAGE = 'message';
  DEFAULT_ERROR_NAME = 'Error';
  ERROR_SEPARATOR = ': ';

constructor TJSPrototypeMethods.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
end;

class function TJSPrototypeMethods.IsConstructCall(const This: IJSObject; const PrototypeObj: IJSObject): Boolean;
begin
  if not Assigned(This) then
    Exit(False);

  if Supports(This, IJSPrimitiveWrapper) then
    Exit(False);

  Result := (This.Prototype as IInterface) = (PrototypeObj as IInterface);
end;

procedure TJSPrototypeMethods.DefineMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                              const Method: TNativeFunction);
begin
  const Func: IJSFunction = TJSFunction.CreateNative(MethodName, Method);
  Func.IsConstructor := False;

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func));
  Descriptor.Enumerable := False;
  PrototypeObj.DefineProperty(MethodName, Descriptor);
end;

function TJSPrototypeMethods.ObjectToPrimitive(const Source: IJSObject; const PreferString: Boolean): TJSValue;
begin
  var ConversionNames := [METHOD_VALUE_OF, METHOD_TO_STRING];

  if PreferString then
    ConversionNames := [METHOD_TO_STRING, METHOD_VALUE_OF];

  for var ConversionName in ConversionNames do
  begin
    const Conversion = Source.GetProperty(ConversionName);

    var Func: IJSFunction;
    const IsCallable = Conversion.IsFunction and Supports(Conversion.ToObject, IJSFunction, Func);
    if not IsCallable then
      Continue;

    const Converted = FInterpreter.CallFunction(Func, nil, Source);
    if not Converted.IsObject then
      Exit(Converted);
  end;

  raise TJSErrorFactory.TypeError(CANNOT_CONVERT_TO_PRIMITIVE);
end;

function TJSPrototypeMethods.ObjectToText(const Source: IJSObject): string;
begin
  var Wrapper: IJSPrimitiveWrapper;
  if Supports(Source, IJSPrimitiveWrapper, Wrapper) then
    Exit(Wrapper.Primitive.ToString);

  const SourceValue = TJSValue.CreateObject(Source);
  if SourceValue.IsArray then
    Exit(SourceValue.ToLimitedString(FInterpreter.Limits));

  const Primitive = ObjectToPrimitive(Source, True);

  Result := Primitive.ToString;
end;

function TJSPrototypeMethods.ValueToText(const Value: TJSValue): string;
begin
  if Value.IsObject then
    Result := ObjectToText(Value.ToObject)
  else
    Result := Value.ToString;
end;

function TJSPrototypeMethods.PropertyToText(const Source: IJSObject; const PropertyName: string;
                                            const DefaultText: string): string;
begin
  const PropertyValue = Source.GetProperty(PropertyName);

  if PropertyValue.IsUndefined then
    Result := DefaultText
  else
    Result := ValueToText(PropertyValue);
end;

function TJSPrototypeMethods.ConvertArgumentToPrimitive(const Arg: TJSValue; const PreferString: Boolean): TJSValue;
begin
  const IsRegExp = Arg.IsObject and Supports(Arg.ToObject, IJSRegExp);
  const KeepsIdentity = (not Arg.IsObject) or Arg.IsArray or Arg.IsFunction or IsRegExp;
  if KeepsIdentity then
    Result := Arg
  else
    Result := ObjectToPrimitive(Arg.ToObject, PreferString);
end;

function TJSPrototypeMethods.ConvertArgumentsToPrimitives(const Args: TArray<TJSValue>;
                                                          const PreferString: Boolean): TArray<TJSValue>;
begin
  SetLength(Result, Length(Args));

  for var Index := 0 to Length(Args) - 1 do
  begin
    Result[Index] := ConvertArgumentToPrimitive(Args[Index], PreferString);
  end;
end;

function TJSPrototypeMethods.ConvertStringArgument(const MethodName: string; const Args: TArray<TJSValue>;
                                                   const Index: Integer): TJSValue;
begin
  const Arg = Args[Index];

  const IsNumber = Arg.IsObject and TJSBuiltins.IsNumericStringArgument(MethodName, Index);
  if IsNumber then
  begin
    const Primitive = ObjectToPrimitive(Arg.ToObject, False);
    Result := TJSValue.CreateNumber(Primitive.ToNumber);
  end
  else
    Result := ConvertArgumentToPrimitive(Arg, True);
end;

function TJSPrototypeMethods.ConvertStringArguments(const MethodName: string;
                                                    const Args: TArray<TJSValue>): TArray<TJSValue>;
begin
  SetLength(Result, Length(Args));

  const IsLimitFirst = (MethodName = METHOD_SPLIT) and (Length(Args) > 1);
  if IsLimitFirst then
    Result[1] := ConvertStringArgument(MethodName, Args, 1);

  for var Index := 0 to Length(Args) - 1 do
  begin
    const IsConverted = IsLimitFirst and (Index = 1);
    if not IsConverted then
      Result[Index] := ConvertStringArgument(MethodName, Args, Index);
  end;
end;

function TJSPrototypeMethods.ThisToText(const This: IJSObject; const MethodName: string): string;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [TYPE_NAME_STRING, MethodName]));

  Result := ObjectToText(This);
end;

function TJSPrototypeMethods.ThisToPrimitive(const This: IJSObject; const TypeName: string;
                                                const MethodName: string): TJSValue;
begin
  var Wrapper: IJSPrimitiveWrapper;
  const IsWrapper = Supports(This, IJSPrimitiveWrapper, Wrapper);

  const HasExpectedType = IsWrapper and (Wrapper.GetClassName = TypeName);
  if not HasExpectedType then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_INCOMPATIBLE_TYPE, [TypeName, MethodName]));

  Result := Wrapper.Primitive;
end;

function TJSPrototypeMethods.ClassTagOf(const Source: IJSObject): string;
begin
  var Wrapper: IJSPrimitiveWrapper;
  if Supports(Source, IJSPrimitiveWrapper, Wrapper) then
    Exit(Wrapper.GetClassName);

  if Supports(Source, IJSArray) then
    Exit(CLASS_ARRAY);

  if Supports(Source, IJSFunction) then
    Exit(CLASS_FUNCTION);

  if Supports(Source, IJSArgumentsScope) then
    Exit(CLASS_ARGUMENTS);

  if Supports(Source, IJSDate) then
    Exit(CLASS_DATE);

  if Supports(Source, IJSRegExp) then
    Exit(CLASS_REGEXP);

  if Supports(Source, IJSError) then
    Exit(CLASS_ERROR);

  if (Source as IInterface) = (FMathObject as IInterface) then
    Exit(CLASS_MATH);

  if (Source as IInterface) = (FJSONObject as IInterface) then
    Exit(CLASS_JSON);

  Result := CLASS_OBJECT;
end;

function TJSPrototypeMethods.ObjectToString(const This: IJSObject): TJSValue;
begin
  var ClassTag := CLASS_UNDEFINED;

  if Assigned(This) then
    ClassTag := ClassTagOf(This);

  const TagText = Format(CLASS_TAG_FORMAT, [ClassTag]);

  Result := TJSValue.CreateString(TagText);
end;

function TJSPrototypeMethods.ObjectToLocaleString(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [CLASS_OBJECT, METHOD_TO_LOCALE_STRING]));

  const Conversion = This.GetProperty(METHOD_TO_STRING);

  var Func: IJSFunction;
  const IsCallable = Conversion.IsFunction and Supports(Conversion.ToObject, IJSFunction, Func);
  if not IsCallable then
    raise TJSErrorFactory.NotAFunction(METHOD_TO_STRING);

  Result := FInterpreter.CallFunction(Func, nil, This);
end;

function TJSPrototypeMethods.ObjectValueOf(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [CLASS_OBJECT, METHOD_VALUE_OF]));

  Result := TJSValue.CreateObject(This);
end;

function TJSPrototypeMethods.ObjectIsPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const HasCandidate = (Length(Args) > 0) and Args[0].IsObject;
  if not HasCandidate then
    Exit(TJSValue.CreateBoolean(False));

  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [CLASS_OBJECT, METHOD_IS_PROTOTYPE_OF]));

  var Current := Args[0].ToObject.Prototype;
  while Assigned(Current) do
  begin
    if (Current as IInterface) = (This as IInterface) then
      Exit(TJSValue.CreateBoolean(True));

    Current := Current.Prototype;
  end;

  Result := TJSValue.CreateBoolean(False);
end;

function TJSPrototypeMethods.ErrorToString(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(ERROR_TO_STRING_ON_NON_OBJECT);

  var DefaultName := DEFAULT_ERROR_NAME;
  var DefaultMessage := '';

  var ErrorObj: IJSError;
  if Supports(This, IJSError, ErrorObj) then
  begin
    DefaultName := ErrorObj.GetErrorName;
    DefaultMessage := ErrorObj.Message;
  end;

  const ErrorName = PropertyToText(This, PROPERTY_NAME, DefaultName);
  const ErrorMessage = PropertyToText(This, PROPERTY_MESSAGE, DefaultMessage);

  if ErrorName.IsEmpty then
    Exit(TJSValue.CreateString(ErrorMessage));

  if ErrorMessage.IsEmpty then
    Exit(TJSValue.CreateString(ErrorName));

  Result := TJSValue.CreateString(ErrorName + ERROR_SEPARATOR + ErrorMessage);
end;

function TJSPrototypeMethods.RegExpToString(const This: IJSObject): TJSValue;
begin
  var RegExpObj: IJSRegExp;
  if not Supports(This, IJSRegExp, RegExpObj) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP);

  const FlagsText = RegExpFlags(This).ToString;
  const SourceText = Format(REGEXP_FORMAT, [RegExpObj.Source, FlagsText]);

  Result := TJSValue.CreateString(SourceText);
end;

function TJSPrototypeMethods.RegExpFlags(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) or Supports(This, IJSPrimitiveWrapper) then
    raise TJSErrorFactory.TypeError(FLAGS_ON_NON_OBJECT);

  var Flags := '';
  for var FlagProperty in REGEXP_FLAG_PROPERTIES do
  begin
    if This.GetProperty(FlagProperty.Name).ToBoolean then
      Flags := Flags + FlagProperty.Flag;
  end;

  Result := TJSValue.CreateString(Flags);
end;

function TJSPrototypeMethods.RegExpFlagValue(const This: IJSObject; const PrototypeIdentity: Pointer;
                                             const PropertyName: string;
                                             const FromRegExp: TRegExpReader): TJSValue;
begin
  var RegExpObj: IJSRegExp;
  if Supports(This, IJSRegExp, RegExpObj) then
    Exit(FromRegExp(RegExpObj));

  const IsPrototype = Assigned(This) and (Pointer(This as IInterface) = PrototypeIdentity);
  if IsPrototype then
    Exit(TJSValue.CreateUndefined);

  raise TJSErrorFactory.TypeError(Format(NOT_A_REGEXP_GETTER_RECEIVER, [PropertyName]));
end;

procedure TJSPrototypeMethods.DefineGetter(const Target: IJSObject; const PropertyName: string;
                                           const Getter: TNativeFunction);
begin
  const Func: IJSFunction = TJSFunction.CreateNative(Format(GETTER_NAME_FORMAT, [PropertyName]), Getter);
  Func.IsConstructor := False;
  TJSFunction.DefineLength(Func, 0);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateUndefined);
  Descriptor.IsAccessor := True;
  Descriptor.Getter := TJSValue.CreateObject(Func);
  Descriptor.Setter := TJSValue.CreateUndefined;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(PropertyName, Descriptor);
end;

procedure TJSPrototypeMethods.DefineRegExpFlagGetter(const PrototypeObj: IJSObject; const PropertyName: string;
                                                     const FromRegExp: TRegExpReader);
begin
  const PrototypeIdentity = Pointer(PrototypeObj as IInterface);

  DefineGetter(PrototypeObj, PropertyName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpFlagValue(This, PrototypeIdentity, PropertyName, FromRegExp);
    end);
end;

procedure TJSPrototypeMethods.RegisterRegExpAccessors(const PrototypeObj: IJSObject);
begin
  const PrototypeIdentity = Pointer(PrototypeObj as IInterface);

  DefineGetter(PrototypeObj, PROPERTY_FLAGS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpFlags(This);
    end);

  DefineGetter(PrototypeObj, PROPERTY_SOURCE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpFlagValue(This, PrototypeIdentity, PROPERTY_SOURCE,
        function(const RegExpObj: IJSRegExp): TJSValue
        begin
          Result := TJSValue.CreateString(RegExpObj.Source);
        end);

      if Result.IsUndefined then
        Result := TJSValue.CreateString(EMPTY_PATTERN_SOURCE);
    end);

  DefineRegExpFlagGetter(PrototypeObj, PROPERTY_GLOBAL,
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      Result := TJSValue.CreateBoolean(RegExpObj.Global);
    end);

  DefineRegExpFlagGetter(PrototypeObj, PROPERTY_IGNORE_CASE,
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      Result := TJSValue.CreateBoolean(RegExpObj.IgnoreCase);
    end);

  DefineRegExpFlagGetter(PrototypeObj, PROPERTY_MULTILINE,
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      Result := TJSValue.CreateBoolean(RegExpObj.Multiline);
    end);

  DefineRegExpFlagGetter(PrototypeObj, PROPERTY_UNICODE,
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      Result := TJSValue.CreateBoolean(RegExpObj.Unicode);
    end);

  DefineRegExpFlagGetter(PrototypeObj, PROPERTY_STICKY,
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      Result := TJSValue.CreateBoolean(RegExpObj.Sticky);
    end);
end;

function TJSPrototypeMethods.RegExpExec(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var RegExpObj: IJSRegExp;
  if not Supports(This, IJSRegExp, RegExpObj) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP_RECEIVER);

  var Subject := UNDEFINED_TEXT;
  if Length(Args) > 0 then
    Subject := ValueToText(Args[0]);

  Result := RegExpObj.Exec(Subject);
end;

function TJSPrototypeMethods.FunctionToString(const This: IJSObject): TJSValue;
begin
  var Func: IJSFunction;
  if not Supports(This, IJSFunction, Func) then
    raise TJSErrorFactory.TypeError(NOT_A_FUNCTION);

  var SourceText := Func.SourceText;
  const HasSourceText = not SourceText.IsEmpty;
  if not HasSourceText then
    SourceText := Format(NATIVE_FUNCTION_FORMAT, [Func.Name]);

  Result := TJSValue.CreateString(SourceText);
end;

procedure TJSPrototypeMethods.RejectRegExpSearchString(const MethodName: string; const Args: TArray<TJSValue>);
begin
  const IsSearchMethod = (MethodName = METHOD_STARTS_WITH) or
                         (MethodName = METHOD_ENDS_WITH) or
                         (MethodName = METHOD_INCLUDES);
  const HasSearchString = (Length(Args) > 0) and Args[0].IsObject;
  if not (IsSearchMethod and HasSearchString) then
    Exit;

  const IsRegExp = Supports(Args[0].ToObject, IJSRegExp);
  if IsRegExp then
    raise TJSErrorFactory.TypeError(Format(REGEXP_SEARCH_STRING_MESSAGE, [MethodName]));
end;

function TJSPrototypeMethods.CallStringMethod(const This: IJSObject; const MethodName: string;
                                                 const Args: TArray<TJSValue>): TJSValue;
begin
  const IsValueAccessor = (MethodName = METHOD_TO_STRING) or (MethodName = METHOD_VALUE_OF);
  if IsValueAccessor then
    Exit(ThisToPrimitive(This, TYPE_NAME_STRING, MethodName));

  const Text = ThisToText(This, MethodName);

  RejectRegExpSearchString(MethodName, Args);

  const PrimitiveArgs = ConvertStringArguments(MethodName, Args);

  const Executor: TJSCallbackExecutor =
    function(const Func: IJSFunction; const CallbackArgs: TArray<TJSValue>): TJSValue
    begin
      const ThisArg = FInterpreter.ThisObjectFor(Func, TJSValue.CreateUndefined);
      Result := FInterpreter.CallFunction(Func, CallbackArgs, ThisArg);
    end;

  Result := TJSBuiltins.CallStringMethod(Text, MethodName, PrimitiveArgs, Executor, FInterpreter.Limits);
end;

function TJSPrototypeMethods.TryFormatLocaleNumber(const NumberValue: Double; const Args: TArray<TJSValue>;
                                                   out Text: string): Boolean;
begin
  var Request: TJSLocaleRequest;
  Result := TJSLocaleArguments.TryCreateRequest(Args, Request);
  if not Result then
    Exit;

  const Options = TJSLocaleArguments.ReadNumberOptions(Request);

  Text := TJSLocaleNumberFormatter.FormatNumber(NumberValue, Request.Locale, Options);
end;

function TJSPrototypeMethods.CallNumberMethod(const This: IJSObject; const MethodName: string;
                                                 const Args: TArray<TJSValue>): TJSValue;
begin
  const Primitive = ThisToPrimitive(This, TYPE_NAME_NUMBER, MethodName);
  const NumberValue = Primitive.AsNumber;

  const IsLocaleString = (MethodName = METHOD_TO_LOCALE_STRING);

  var LocaleText: string;
  const IsLocaleFormatted = IsLocaleString and TryFormatLocaleNumber(NumberValue, Args, LocaleText);
  if IsLocaleFormatted then
    Exit(TJSValue.CreateString(LocaleText));

  var BuiltinName := MethodName;
  if IsLocaleString then
    BuiltinName := METHOD_TO_STRING;

  const PrimitiveArgs = ConvertArgumentsToPrimitives(Args, False);

  Result := TJSBuiltins.CallNumberMethod(NumberValue, BuiltinName, PrimitiveArgs);
end;

function TJSPrototypeMethods.CallBooleanMethod(const This: IJSObject; const MethodName: string): TJSValue;
begin
  const Primitive = ThisToPrimitive(This, TYPE_NAME_BOOLEAN, MethodName);

  if MethodName = METHOD_VALUE_OF then
    Exit(Primitive);

  Result := TJSValue.CreateString(Primitive.ToString);
end;

procedure TJSPrototypeMethods.RegisterObjectMethods(const PrototypeObj: IJSObject; const MathObj: IJSObject;
                                                       const JSONObj: IJSObject);
begin
  FMathObject := MathObj;
  FJSONObject := JSONObj;

  DefineMethod(PrototypeObj, METHOD_TO_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectToString(This);
    end);

  DefineMethod(PrototypeObj, METHOD_TO_LOCALE_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectToLocaleString(This);
    end);

  DefineMethod(PrototypeObj, METHOD_VALUE_OF,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectValueOf(This);
    end);

  DefineMethod(PrototypeObj, METHOD_IS_PROTOTYPE_OF,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectIsPrototypeOf(This, Args);
    end);
end;

function TJSPrototypeMethods.BindStringMethod(const MethodName: string): TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallStringMethod(This, MethodName, Args);
    end;
end;

function TJSPrototypeMethods.BindNumberMethod(const MethodName: string): TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallNumberMethod(This, MethodName, Args);
    end;
end;

function TJSPrototypeMethods.BindBooleanMethod(const MethodName: string): TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CallBooleanMethod(This, MethodName);
    end;
end;

procedure TJSPrototypeMethods.RegisterErrorMethods(const PrototypeObj: IJSObject);
begin
  DefineMethod(PrototypeObj, METHOD_TO_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ErrorToString(This);
    end);
end;

procedure TJSPrototypeMethods.RegisterRegExpMethods(const PrototypeObj: IJSObject);
begin
  RegisterRegExpAccessors(PrototypeObj);

  DefineMethod(PrototypeObj, METHOD_TO_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpToString(This);
    end);

  DefineMethod(PrototypeObj, METHOD_EXEC,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpExec(This, Args);
    end);

  DefineMethod(PrototypeObj, METHOD_TEST,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Matched = RegExpExec(This, Args);
      Result := TJSValue.CreateBoolean(not Matched.IsNull);
    end);
end;

procedure TJSPrototypeMethods.RegisterFunctionMethods(const PrototypeObj: IJSObject);
begin
  DefineMethod(PrototypeObj, METHOD_TO_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FunctionToString(This);
    end);
end;

procedure TJSPrototypeMethods.RegisterStringMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in TJSBuiltins.StringMethodNames do
  begin
    DefineMethod(PrototypeObj, MethodName, BindStringMethod(MethodName));
  end;
end;

procedure TJSPrototypeMethods.RegisterNumberMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in TJSBuiltins.NumberMethodNames + [METHOD_TO_LOCALE_STRING] do
  begin
    DefineMethod(PrototypeObj, MethodName, BindNumberMethod(MethodName));
  end;
end;

procedure TJSPrototypeMethods.RegisterBooleanMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in [METHOD_TO_STRING, METHOD_VALUE_OF] do
  begin
    DefineMethod(PrototypeObj, MethodName, BindBooleanMethod(MethodName));
  end;
end;

end.
