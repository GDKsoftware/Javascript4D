unit JS4D.PrototypeMethods;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Errors,
  JS4D.ArgumentsObject,
  JS4D.Interpreter,
  JS4D.SymbolRegistry,
  JS4D.StrictThis,
  JS4D.BuiltinSupport,
  JS4D.Builtins;

type
  TRegExpReader = reference to function(const RegExpObj: IJSRegExp): TJSValue;

  TJSPrototypeMethods = class
  private
    const
      NO_PARAMETERS = 0;

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;

    function DefineMethod(const PrototypeObj: IJSObject; const MethodName: string;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineRawThisMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                  const Method: TNativeFunction);
    procedure DefineIntrinsicMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                    const Method: TNativeFunction; const Role: TJSIntrinsicRole);
    function BoxThis(const This: IJSObject): IJSObject;
    function ObjectToPrimitive(const Source: IJSObject; const PreferString: Boolean): TJSValue;
    function ObjectToText(const Source: IJSObject): string;
    function ValueToText(const Value: TJSValue): string;
    function PropertyToText(const Source: IJSObject; const PropertyName: string; const DefaultText: string): string;
    function ConvertArgumentToPrimitive(const Arg: TJSValue; const PreferString: Boolean): TJSValue;
    function ConvertArgumentsToPrimitives(const Args: TArray<TJSValue>; const PreferString: Boolean): TArray<TJSValue>;
    function ConvertStringArgument(const MethodName: string; const Args: TArray<TJSValue>;
                                   const Index: Integer): TJSValue;
    function ConvertStringArguments(const MethodName: string; const Args: TArray<TJSValue>): TArray<TJSValue>;
    function ThisToText(const This: IJSObject; const MethodName: string): string;
    procedure RejectRegExpSearchString(const MethodName: string; const Args: TArray<TJSValue>);
    function ThisToPrimitive(const This: IJSObject; const TypeName: string; const MethodName: string): TJSValue;
    function TryFormatLocaleNumber(const NumberValue: Double; const Args: TArray<TJSValue>; out Text: string): Boolean;
    function ClassTagOf(const Source: IJSObject): string;
    function ClassTagOfThis(const ThisValue: TJSValue; const This: IJSObject): string;

    function ObjectToString(const This: IJSObject): TJSValue;
    function ObjectToLocaleString(const This: IJSObject): TJSValue;
    function ObjectValueOf(const This: IJSObject): TJSValue;
    function ObjectIsPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function ErrorToString(const This: IJSObject): TJSValue;
    function RegExpToString(const This: IJSObject): TJSValue;
    function RegExpFlags(const This: IJSObject): TJSValue;
    function RegExpFlagValue(const This: IJSObject; const PrototypeIdentity: Pointer; const PropertyName: string;
                             const FromRegExp: TRegExpReader): TJSValue;
    function RegExpFlagOf(const RegExpObj: IJSRegExp; const Flag: Char): Boolean;
    function FlagReader(const Flag: Char): TRegExpReader;
    function ReadSource(const RegExpObj: IJSRegExp): TJSValue;
    function RegExpSource(const This: IJSObject; const PrototypeIdentity: Pointer): TJSValue;
    procedure RaiseCalledOnNullOrUndefined(const TypeName: string; const MethodName: string);
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
    destructor Destroy; override;

    class function IsConstructCall(const This: IJSObject; const PrototypeObj: IJSObject): Boolean; static;

    procedure RegisterObjectMethods(const PrototypeObj: IJSObject);
    procedure RegisterStringMethods(const PrototypeObj: IJSObject);
    procedure RegisterNumberMethods(const PrototypeObj: IJSObject);
    procedure RegisterBooleanMethods(const PrototypeObj: IJSObject);
    procedure RegisterErrorMethods(const PrototypeObj: IJSObject);
    procedure RegisterRegExpMethods(const PrototypeObj: IJSObject);
    procedure RegisterFunctionMethods(const PrototypeObj: IJSObject);
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.ObjectOperations,
  JS4D.RegExpSyntax,
  JS4D.Conversions,
  JS4D.LocaleArguments,
  JS4D.LocaleNumberFormat;

type
  TRegExpFlagProperty = record
    Name: string;
    Flag: Char;
  end;

const
  METHOD_IS_PROTOTYPE_OF = 'isPrototypeOf';
  METHOD_EXEC = 'exec';
  REGEXP_SEARCH_STRING_MESSAGE = 'First argument to String.prototype.%s must not be a regular expression';
  TYPE_NAME_STRING = 'String';
  TYPE_NAME_NUMBER = 'Number';
  TYPE_NAME_BOOLEAN = 'Boolean';
  CLASS_TAG_FORMAT = '[object %s]';
  CLASS_UNDEFINED = 'Undefined';
  CLASS_NULL = 'Null';
  CLASS_OBJECT = 'Object';
  CLASS_ARRAY = 'Array';
  CLASS_FUNCTION = 'Function';
  CLASS_ARGUMENTS = 'Arguments';
  CLASS_DATE = 'Date';
  CLASS_REGEXP = 'RegExp';
  CLASS_ERROR = 'Error';
  CLASS_SYMBOL = 'Symbol';
  CALLED_ON_NULL_OR_UNDEFINED = '%s.prototype.%s called on null or undefined';
  CALLED_ON_INCOMPATIBLE_TYPE = '%s.prototype.%s called on an incompatible receiver';
  NOT_A_REGEXP = 'RegExp.prototype.toString called on a value that is not a regular expression';
  NOT_A_REGEXP_RECEIVER = 'RegExp.prototype method called on a value that is not a regular expression';
  NOT_A_REGEXP_GETTER_RECEIVER = 'RegExp.prototype.%s getter called on a value that is not a regular expression';
  FLAGS_ON_NON_OBJECT = 'RegExp.prototype.flags getter called on a value that is not an object';
  PROPERTY_DOT_ALL = 'dotAll';
  PROPERTY_GLOBAL = 'global';
  PROPERTY_HAS_INDICES = 'hasIndices';
  PROPERTY_IGNORE_CASE = 'ignoreCase';
  PROPERTY_MULTILINE = 'multiline';
  PROPERTY_STICKY = 'sticky';
  PROPERTY_UNICODE = 'unicode';
  PROPERTY_SOURCE = 'source';
  EMPTY_PATTERN_SOURCE = '(?:)';
  HAS_INDICES_FLAG = 'd';
  DOT_ALL_FLAG = 's';
  UNSUPPORTED_FLAG = 'Unsupported regular expression flag: %s';
  REGEXP_FLAG_PROPERTIES: array[0..6] of TRegExpFlagProperty = (
    (Name: PROPERTY_HAS_INDICES; Flag: HAS_INDICES_FLAG),
    (Name: PROPERTY_GLOBAL; Flag: TJSRegExpFlags.GLOBAL),
    (Name: PROPERTY_IGNORE_CASE; Flag: TJSRegExpFlags.IGNORE_CASE),
    (Name: PROPERTY_MULTILINE; Flag: TJSRegExpFlags.MULTILINE),
    (Name: PROPERTY_DOT_ALL; Flag: DOT_ALL_FLAG),
    (Name: PROPERTY_UNICODE; Flag: TJSRegExpFlags.UNICODE),
    (Name: PROPERTY_STICKY; Flag: TJSRegExpFlags.STICKY)
  );
  REGEXP_FLAG_GETTERS: array[0..4] of TRegExpFlagProperty = (
    (Name: PROPERTY_GLOBAL; Flag: TJSRegExpFlags.GLOBAL),
    (Name: PROPERTY_IGNORE_CASE; Flag: TJSRegExpFlags.IGNORE_CASE),
    (Name: PROPERTY_MULTILINE; Flag: TJSRegExpFlags.MULTILINE),
    (Name: PROPERTY_UNICODE; Flag: TJSRegExpFlags.UNICODE),
    (Name: PROPERTY_STICKY; Flag: TJSRegExpFlags.STICKY)
  );
  UNDEFINED_TEXT = 'undefined';
  NOT_A_FUNCTION = 'Function.prototype.toString called on a value that is not a function';
  ERROR_TO_STRING_ON_NON_OBJECT = 'Error.prototype.toString called on a value that is not an object';
  REGEXP_FORMAT = '/%s/%s';
  ERROR_TEXT_FORMAT = '%s: %s';
  NATIVE_FUNCTION_FORMAT = 'function %s() { [native code] }';
  PROPERTY_NAME = 'name';
  PROPERTY_MESSAGE = 'message';
  DEFAULT_ERROR_NAME = CLASS_ERROR;

constructor TJSPrototypeMethods.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSPrototypeMethods.Destroy;
begin
  FSupport.Free;
  inherited;
end;

class function TJSPrototypeMethods.IsConstructCall(const This: IJSObject; const PrototypeObj: IJSObject): Boolean;
begin
  if not Assigned(This) then
    Exit(False);

  if Supports(This, IJSPrimitiveWrapper) then
    Exit(False);

  Result := TJSObjectOperations.IsSameObject(This.Prototype, PrototypeObj);
end;

procedure TJSPrototypeMethods.RaiseCalledOnNullOrUndefined(const TypeName: string; const MethodName: string);
begin
  const Message = Format(CALLED_ON_NULL_OR_UNDEFINED, [TypeName, MethodName]);

  raise TJSErrorFactory.TypeError(Message);
end;

function TJSPrototypeMethods.DefineMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                          const Method: TNativeFunction): IJSFunction;
begin
  Result := FSupport.DefineMethod(PrototypeObj, MethodName, NO_PARAMETERS, Method);
end;

procedure TJSPrototypeMethods.DefineRawThisMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                                  const Method: TNativeFunction);
begin
  const Func = DefineMethod(PrototypeObj, MethodName, Method);
  Func.ReceivesRawThis := True;
end;

procedure TJSPrototypeMethods.DefineIntrinsicMethod(const PrototypeObj: IJSObject; const MethodName: string;
                                                    const Method: TNativeFunction; const Role: TJSIntrinsicRole);
begin
  const Func = DefineMethod(PrototypeObj, MethodName, Method);
  Func.IntrinsicRole := Role;
end;

function TJSPrototypeMethods.BoxThis(const This: IJSObject): IJSObject;
begin
  if not (This is TJSStrictThis) then
    Exit(This);

  const Primitive = TJSStrictThis.ValueOf(This);

  Result := FInterpreter.WrapPrimitive(Primitive);
end;

function TJSPrototypeMethods.ObjectToPrimitive(const Source: IJSObject; const PreferString: Boolean): TJSValue;
begin
  Result := TJSValue.CreateObject(Source).ToPrimitive(PreferString);
end;

function TJSPrototypeMethods.ObjectToText(const Source: IJSObject): string;
begin
  var Wrapper: IJSPrimitiveWrapper;
  if Supports(Source, IJSPrimitiveWrapper, Wrapper) then
  begin
    const WrappedValue = Wrapper.Primitive;

    Result := WrappedValue.ToString;
    Exit;
  end;

  const SourceValue = TJSValue.CreateObject(Source);
  if SourceValue.IsArray then
  begin
    Result := SourceValue.ToLimitedString(FInterpreter.Limits);
    Exit;
  end;

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
  const IsRegExpInstance = Arg.IsObject and Supports(Arg.ToObject, IJSRegExp);
  const KeepsIdentity = (not Arg.IsObject) or Arg.IsArray or Arg.IsFunction or IsRegExpInstance;
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
    const NumberValue = Primitive.ToNumber;

    Result := TJSValue.CreateNumber(NumberValue);
  end
  else
    Result := ConvertArgumentToPrimitive(Arg, True);
end;

function TJSPrototypeMethods.ConvertStringArguments(const MethodName: string;
                                                    const Args: TArray<TJSValue>): TArray<TJSValue>;
begin
  SetLength(Result, Length(Args));

  for var Index := 0 to Length(Args) - 1 do
  begin
    Result[Index] := ConvertStringArgument(MethodName, Args, Index);
  end;
end;

function TJSPrototypeMethods.ThisToText(const This: IJSObject; const MethodName: string): string;
begin
  if not Assigned(This) then
    RaiseCalledOnNullOrUndefined(TYPE_NAME_STRING, MethodName);

  Result := ObjectToText(This);
end;

function TJSPrototypeMethods.ThisToPrimitive(const This: IJSObject; const TypeName: string;
                                             const MethodName: string): TJSValue;
begin
  var Wrapper: IJSPrimitiveWrapper;
  const IsWrapper = Supports(This, IJSPrimitiveWrapper, Wrapper);

  const HasExpectedType = IsWrapper and (Wrapper.GetClassName = TypeName);
  if not HasExpectedType then
  begin
    const Message = Format(CALLED_ON_INCOMPATIBLE_TYPE, [TypeName, MethodName]);

    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := Wrapper.Primitive;
end;

function TJSPrototypeMethods.ClassTagOf(const Source: IJSObject): string;
begin
  var Wrapper: IJSPrimitiveWrapper;
  if Supports(Source, IJSPrimitiveWrapper, Wrapper) then
  begin
    const IsSymbolWrapper = (Wrapper.GetClassName = CLASS_SYMBOL);

    if IsSymbolWrapper then
      Exit(CLASS_OBJECT);

    Exit(Wrapper.GetClassName);
  end;

  const SourceValue = TJSValue.CreateObject(Source);
  if TJSObjectOperations.IsArray(SourceValue) then
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

  Result := CLASS_OBJECT;
end;

function TJSPrototypeMethods.ObjectToString(const This: IJSObject): TJSValue;
begin
  const ThisValue = TJSStrictThis.ValueOf(This);
  const ClassTag = ClassTagOfThis(ThisValue, This);
  const TagText = Format(CLASS_TAG_FORMAT, [ClassTag]);

  Result := TJSValue.CreateString(TagText);
end;

function TJSPrototypeMethods.ClassTagOfThis(const ThisValue: TJSValue; const This: IJSObject): string;
begin
  if ThisValue.IsNull then
    Exit(CLASS_NULL);

  if ThisValue.IsNullOrUndefined then
    Exit(CLASS_UNDEFINED);

  const Subject = BoxThis(This);
  const ClassTag = ClassTagOf(Subject);

  const ToStringTagKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);
  const CustomTag = Subject.GetProperty(ToStringTagKey);
  if CustomTag.IsString then
    Exit(CustomTag.AsString);

  Result := ClassTag;
end;

function TJSPrototypeMethods.ObjectToLocaleString(const This: IJSObject): TJSValue;
begin
  const ThisValue = TJSStrictThis.ValueOf(This);
  if ThisValue.IsNullOrUndefined then
    RaiseCalledOnNullOrUndefined(CLASS_OBJECT, METHOD_TO_LOCALE_STRING);

  Result := FInterpreter.InvokeMethod(ThisValue, TO_STRING_METHOD);
end;

function TJSPrototypeMethods.ObjectValueOf(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    RaiseCalledOnNullOrUndefined(CLASS_OBJECT, VALUE_OF_METHOD);

  Result := TJSValue.CreateObject(This);
end;

function TJSPrototypeMethods.ObjectIsPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const HasCandidate = (Length(Args) > 0) and Args[0].IsObject;
  if not HasCandidate then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  if not Assigned(This) then
    RaiseCalledOnNullOrUndefined(CLASS_OBJECT, METHOD_IS_PROTOTYPE_OF);

  const Candidate = Args[0].ToObject;

  var Current := Candidate.Prototype;
  while Assigned(Current) do
  begin
    const IsMatch = TJSObjectOperations.IsSameObject(Current, This);
    if IsMatch then
    begin
      Result := TJSValue.CreateBoolean(True);
      Exit;
    end;

    Current := Current.Prototype;
  end;

  Result := TJSValue.CreateBoolean(False);
end;

function TJSPrototypeMethods.ErrorToString(const This: IJSObject): TJSValue;
begin
  if TJSStrictThis.IsNonObject(This) then
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
  begin
    Result := TJSValue.CreateString(ErrorMessage);
    Exit;
  end;

  if ErrorMessage.IsEmpty then
  begin
    Result := TJSValue.CreateString(ErrorName);
    Exit;
  end;

  const ErrorText = Format(ERROR_TEXT_FORMAT, [ErrorName, ErrorMessage]);

  Result := TJSValue.CreateString(ErrorText);
end;

function TJSPrototypeMethods.RegExpToString(const This: IJSObject): TJSValue;
begin
  var RegExpObj: IJSRegExp;
  if not Supports(This, IJSRegExp, RegExpObj) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP);

  const FlagsValue = RegExpFlags(This);
  const FlagsText = FlagsValue.ToString;
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
    const FlagValue = This.GetProperty(FlagProperty.Name);
    if FlagValue.ToBoolean then
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
  begin
    Result := FromRegExp(RegExpObj);
    Exit;
  end;

  const IsPrototype = Assigned(This) and (Pointer(This as IInterface) = PrototypeIdentity);
  if IsPrototype then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const Message = Format(NOT_A_REGEXP_GETTER_RECEIVER, [PropertyName]);

  raise TJSErrorFactory.TypeError(Message);
end;

function TJSPrototypeMethods.RegExpFlagOf(const RegExpObj: IJSRegExp; const Flag: Char): Boolean;
begin
  case Flag of
    TJSRegExpFlags.GLOBAL      : Result := RegExpObj.Global;
    TJSRegExpFlags.IGNORE_CASE : Result := RegExpObj.IgnoreCase;
    TJSRegExpFlags.MULTILINE   : Result := RegExpObj.Multiline;
    TJSRegExpFlags.UNICODE     : Result := RegExpObj.Unicode;
    TJSRegExpFlags.STICKY      : Result := RegExpObj.Sticky;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_FLAG, [Flag]);
  end;
end;

function TJSPrototypeMethods.FlagReader(const Flag: Char): TRegExpReader;
begin
  Result :=
    function(const RegExpObj: IJSRegExp): TJSValue
    begin
      const IsSet = RegExpFlagOf(RegExpObj, Flag);

      Result := TJSValue.CreateBoolean(IsSet);
    end;
end;

function TJSPrototypeMethods.ReadSource(const RegExpObj: IJSRegExp): TJSValue;
begin
  Result := TJSValue.CreateString(RegExpObj.Source);
end;

function TJSPrototypeMethods.RegExpSource(const This: IJSObject; const PrototypeIdentity: Pointer): TJSValue;
begin
  Result := RegExpFlagValue(This, PrototypeIdentity, PROPERTY_SOURCE, ReadSource);
  if Result.IsUndefined then
    Result := TJSValue.CreateString(EMPTY_PATTERN_SOURCE);
end;

procedure TJSPrototypeMethods.DefineGetter(const Target: IJSObject; const PropertyName: string;
                                           const Getter: TNativeFunction);
begin
  const GetterName = Format(GETTER_NAME_FORMAT, [PropertyName]);

  FSupport.DefineGetter(Target, PropertyName, GetterName, Getter);
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

  DefineGetter(PrototypeObj, FLAGS_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpFlags(This);
    end);

  DefineGetter(PrototypeObj, PROPERTY_SOURCE,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpSource(This, PrototypeIdentity);
    end);

  for var FlagProperty in REGEXP_FLAG_GETTERS do
  begin
    const Reader = FlagReader(FlagProperty.Flag);

    DefineRegExpFlagGetter(PrototypeObj, FlagProperty.Name, Reader);
  end;
end;

function TJSPrototypeMethods.RegExpExec(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var RegExpObj: IJSRegExp;
  if not Supports(This, IJSRegExp, RegExpObj) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP_RECEIVER);

  var Subject := UNDEFINED_TEXT;
  const HasArgument = (Length(Args) > 0);
  if HasArgument then
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

  const IsRegExpLike = TJSConversions.IsRegExpLike(Args[0]);
  if not IsRegExpLike then
    Exit;

  const Message = Format(REGEXP_SEARCH_STRING_MESSAGE, [MethodName]);

  raise TJSErrorFactory.TypeError(Message);
end;

function TJSPrototypeMethods.CallStringMethod(const This: IJSObject; const MethodName: string;
                                              const Args: TArray<TJSValue>): TJSValue;
begin
  const IsValueAccessor = (MethodName = TO_STRING_METHOD) or (MethodName = VALUE_OF_METHOD);
  if IsValueAccessor then
  begin
    Result := ThisToPrimitive(This, TYPE_NAME_STRING, MethodName);
    Exit;
  end;

  const Text = ThisToText(This, MethodName);

  RejectRegExpSearchString(MethodName, Args);

  const PrimitiveArgs = ConvertStringArguments(MethodName, Args);

  const Executor: TJSCallbackExecutor = FInterpreter.CallWithUndefinedThis;

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
  if IsLocaleString then
  begin
    var LocaleText: string;
    if TryFormatLocaleNumber(NumberValue, Args, LocaleText) then
    begin
      Result := TJSValue.CreateString(LocaleText);
      Exit;
    end;

    Result := TJSBuiltins.CallNumberMethod(NumberValue, TO_STRING_METHOD, []);
    Exit;
  end;

  const PrimitiveArgs = ConvertArgumentsToPrimitives(Args, False);

  Result := TJSBuiltins.CallNumberMethod(NumberValue, MethodName, PrimitiveArgs);
end;

function TJSPrototypeMethods.CallBooleanMethod(const This: IJSObject; const MethodName: string): TJSValue;
begin
  const Primitive = ThisToPrimitive(This, TYPE_NAME_BOOLEAN, MethodName);

  const IsValueOf = (MethodName = VALUE_OF_METHOD);
  if IsValueOf then
    Exit(Primitive);

  const BooleanText = Primitive.ToString;

  Result := TJSValue.CreateString(BooleanText);
end;

procedure TJSPrototypeMethods.RegisterObjectMethods(const PrototypeObj: IJSObject);
begin
  DefineRawThisMethod(PrototypeObj, TO_STRING_METHOD,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectToString(This);
    end);

  DefineRawThisMethod(PrototypeObj, METHOD_TO_LOCALE_STRING,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectToLocaleString(This);
    end);

  DefineIntrinsicMethod(PrototypeObj, VALUE_OF_METHOD,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ObjectValueOf(This);
    end, TJSIntrinsicRole.ObjectValueOf);

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
  DefineRawThisMethod(PrototypeObj, TO_STRING_METHOD,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ErrorToString(This);
    end);
end;

procedure TJSPrototypeMethods.RegisterRegExpMethods(const PrototypeObj: IJSObject);
begin
  RegisterRegExpAccessors(PrototypeObj);

  DefineMethod(PrototypeObj, TO_STRING_METHOD,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpToString(This);
    end);

  DefineMethod(PrototypeObj, METHOD_EXEC,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := RegExpExec(This, Args);
    end);
end;

procedure TJSPrototypeMethods.RegisterFunctionMethods(const PrototypeObj: IJSObject);
begin
  DefineMethod(PrototypeObj, TO_STRING_METHOD,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FunctionToString(This);
    end);
end;

procedure TJSPrototypeMethods.RegisterStringMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in TJSBuiltins.StringMethodNames do
  begin
    const Method = BindStringMethod(MethodName);

    DefineMethod(PrototypeObj, MethodName, Method);
  end;
end;

procedure TJSPrototypeMethods.RegisterNumberMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in TJSBuiltins.NumberMethodNames + [METHOD_TO_LOCALE_STRING] do
  begin
    const Method = BindNumberMethod(MethodName);

    DefineMethod(PrototypeObj, MethodName, Method);
  end;
end;

procedure TJSPrototypeMethods.RegisterBooleanMethods(const PrototypeObj: IJSObject);
begin
  for var MethodName in [TO_STRING_METHOD, VALUE_OF_METHOD] do
  begin
    const Method = BindBooleanMethod(MethodName);

    DefineMethod(PrototypeObj, MethodName, Method);
  end;
end;

end.
