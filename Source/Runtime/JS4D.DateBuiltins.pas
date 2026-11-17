unit JS4D.DateBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.LocaleDateFormat;

type
  TJSDateBuiltins = class
  private
    type
      TDateField = (Year, Month, Date, Hours, Minutes, Seconds, Milliseconds, WeekDay);
      TTextForm = (Full, DateOnly, TimeOnly, Utc);
      TThisMethod = function(const This: IJSObject): TJSValue of object;
      TThisAndArgumentsMethod = function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue of object;

    const
      DATE_NAME = 'Date';
      FIELD_NAMES: array[TDateField] of string = ('FullYear', 'Month', DATE_NAME, 'Hours', 'Minutes', 'Seconds',
                                                 'Milliseconds', 'Day');
      SETTER_ARGUMENT_COUNTS: array[TDateField] of Integer = (3, 2, 1, 4, 3, 2, 1, 0);
      COMPONENT_COUNT = Ord(TDateField.Milliseconds) + 1;
      CONSTRUCTOR_LENGTH = 7;

    var
      FPrototype: IJSObject;

    class procedure DefineHiddenMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                       const IsWritable: Boolean); static;
    class function ThisDate(const This: IJSObject): IJSDate; static;
    class function MomentFor(const Time: Double; const IsLocal: Boolean): Double; static;
    class function ComponentOf(const Field: TDateField; const Moment: Double): Double; static;
    class function ComponentsOf(const Moment: Double): TArray<Double>; static;
    class function MakeFullYear(const Year: Double): Double; static;
    class function ComposeTime(const Components: TArray<Double>): Double; static;
    class function CollectComponents(const Args: TArray<TJSValue>): TArray<Double>; static;
    class function NumberArgumentOrNaN(const Args: TArray<TJSValue>; const Position: Integer): Double; static;
    class function SetterValueCount(const Field: TDateField; const ArgumentCount: Integer): Integer; static;
    class function CollectSetterValues(const Field: TDateField; const Args: TArray<TJSValue>): TArray<Double>;
      static;
    class function TryGetSetterMoment(const OriginalTime: Double; const Field: TDateField; const IsLocal: Boolean;
                                      out Moment: Double): Boolean; static;
    class function TimeFromValue(const Value: TJSValue): Double; static;
    class function FormatTime(const Form: TTextForm; const Time: Double): string; static;
    class function HintFromArguments(const Args: TArray<TJSValue>): TJSPrimitiveHint; static;

    function DefineMethod(const Name: string; const ParameterCount: Integer; const Method: TNativeFunction): IJSFunction;
    function BindGetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
    function BindSetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
    function BindFormatter(const Form: TTextForm): TNativeFunction;
    function BindLocaleFormatter(const Form: TTextForm; const Scope: TJSDateFormatScope): TNativeFunction;
    function BindTimeValue: TNativeFunction;
    function BindThis(const Method: TThisMethod): TNativeFunction;
    function BindThisAndArguments(const Method: TThisAndArgumentsMethod): TNativeFunction;
    function DefineFormatter(const Name: string; const Form: TTextForm): IJSFunction;
    function DefineLocaleFormatter(const Name: string; const Form: TTextForm;
                                   const Scope: TJSDateFormatScope): IJSFunction;
    function DefineTimeValueMethod(const Name: string): IJSFunction;
    function DefineThisMethod(const Name: string; const ParameterCount: Integer;
                              const Method: TThisMethod): IJSFunction;
    function DefineThisAndArgumentsMethod(const Name: string; const ParameterCount: Integer;
                                          const Method: TThisAndArgumentsMethod): IJSFunction;

    function ApplySetter(const Target: IJSDate; const OriginalTime: Double; const Field: TDateField;
                         const Values: TArray<Double>; const IsLocal: Boolean): Double;
    function SetField(const This: IJSObject; const Args: TArray<TJSValue>; const Field: TDateField;
                      const IsLocal: Boolean): TJSValue;
    function LocaleString(const This: IJSObject; const Args: TArray<TJSValue>; const Form: TTextForm;
                          const Scope: TJSDateFormatScope): TJSValue;
    function TimeFromComponents(const Args: TArray<TJSValue>): Double;
    function TimeFromArguments(const Args: TArray<TJSValue>): Double;
    function ConstructDate(const Args: TArray<TJSValue>): TJSValue;
    function CallOrConstruct(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function SetTime(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function SetYear(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetYear(const This: IJSObject): TJSValue;
    function GetTimezoneOffset(const This: IJSObject): TJSValue;
    function ToIsoString(const This: IJSObject): TJSValue;
    function ToJson(const This: IJSObject): TJSValue;
    function ToPrimitiveMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function StaticNow(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function StaticParse(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function StaticUtc(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;

    procedure DefineToPrimitive;
    procedure DefineGettersAndSetters;
    procedure DefineStringMethods;
    procedure DefineUtilityMethods;
    procedure DefineStaticMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                                 const Method: TThisAndArgumentsMethod);
    procedure DefineStaticMethods(const Constructor_: IJSFunction);

  public
    constructor Create(const PrototypeObj: IJSObject);

    function CreateConstructor: IJSFunction;
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.Conversions,
  System.Math,
  System.StrUtils,
  JS4D.Errors,
  JS4D.SymbolRegistry,
  JS4D.StrictThis,
  JS4D.PrototypeMethods,
  JS4D.DateMath,
  JS4D.DateText,
  JS4D.DateParser,
  JS4D.LocaleArguments;

const
  INVALID_DATE = 'Invalid Date';
  THIS_NOT_A_DATE = 'this is not a Date object';
  THIS_NOT_AN_OBJECT = 'Date.prototype[Symbol.toPrimitive] called on a value that is not an object';
  INVALID_HINT = 'Invalid hint for Date.prototype[Symbol.toPrimitive]';
  TO_PRIMITIVE_FUNCTION_NAME = '[Symbol.toPrimitive]';
  HINT_STRING = 'string';
  HINT_NUMBER = 'number';
  HINT_DEFAULT = 'default';
  INVALID_TIME_VALUE = 'Invalid time value';
  NOT_CALLABLE = 'toISOString is not a function';
  ACCESSOR_NAME_FORMAT = '%s%s%s';
  GET_PREFIX = 'get';
  SET_PREFIX = 'set';
  UTC_INFIX = 'UTC';
  STATIC_UTC_NAME = UTC_INFIX;
  STATIC_NOW_NAME = 'now';
  STATIC_PARSE_NAME = 'parse';
  METHOD_TO_LOCALE_DATE_STRING = 'toLocaleDateString';
  METHOD_TO_LOCALE_TIME_STRING = 'toLocaleTimeString';
  METHOD_TO_GMT_STRING = 'toGMTString';
  METHOD_GET_YEAR = 'getYear';
  METHOD_GET_TIMEZONE_OFFSET = 'getTimezoneOffset';
  METHOD_SET_TIME = 'setTime';
  METHOD_SET_YEAR = 'setYear';
  METHOD_TO_JSON = 'toJSON';
  METHOD_GET_TIME = 'getTime';
  METHOD_TO_DATE_STRING = 'toDateString';
  METHOD_TO_TIME_STRING = 'toTimeString';
  METHOD_TO_UTC_STRING = 'toUTCString';
  METHOD_TO_ISO_STRING = 'toISOString';
  YEAR_OFFSET = 1900;
  LAST_TWO_DIGIT_YEAR = 99;
  DEFAULT_MONTH = 0;
  DEFAULT_DAY = 1;

constructor TJSDateBuiltins.Create(const PrototypeObj: IJSObject);
begin
  inherited Create;
  FPrototype := PrototypeObj;
end;

class procedure TJSDateBuiltins.DefineHiddenMember(const Target: IJSObject; const Key: TJSPropertyKey;
                                                   const Value: TJSValue; const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Target.DefineProperty(Key, Descriptor);
end;

class function TJSDateBuiltins.ThisDate(const This: IJSObject): IJSDate;
begin
  if not Supports(This, IJSDate, Result) then
    raise TJSErrorFactory.TypeError(THIS_NOT_A_DATE);
end;

class function TJSDateBuiltins.MomentFor(const Time: Double; const IsLocal: Boolean): Double;
begin
  Result := Time;
  if IsLocal then
    Result := TJSDateMath.LocalTime(Time);
end;

class function TJSDateBuiltins.FormatTime(const Form: TTextForm; const Time: Double): string;
begin
  case Form of
    TTextForm.Full     : Result := TJSDateText.ToFullString(Time);
    TTextForm.DateOnly : Result := TJSDateText.ToDateString(Time);
    TTextForm.TimeOnly : Result := TJSDateText.ToTimeString(Time);
    TTextForm.Utc      : Result := TJSDateText.ToUtcString(Time);
  else
    raise ENotSupportedException.CreateFmt('Unsupported text form: %d', [Ord(Form)]);
  end;
end;

class function TJSDateBuiltins.ComponentOf(const Field: TDateField; const Moment: Double): Double;
begin
  case Field of
    TDateField.Year         : Result := TJSDateMath.YearFromTime(Moment);
    TDateField.Month        : Result := TJSDateMath.MonthFromTime(Moment);
    TDateField.Date         : Result := TJSDateMath.DateFromTime(Moment);
    TDateField.Hours        : Result := TJSDateMath.HourFromTime(Moment);
    TDateField.Minutes      : Result := TJSDateMath.MinuteFromTime(Moment);
    TDateField.Seconds      : Result := TJSDateMath.SecondFromTime(Moment);
    TDateField.Milliseconds : Result := TJSDateMath.MillisecondFromTime(Moment);
    TDateField.WeekDay      : Result := TJSDateMath.WeekDay(Moment);
  else
    raise ENotSupportedException.CreateFmt('Unsupported date field: %d', [Ord(Field)]);
  end;
end;

class function TJSDateBuiltins.ComponentsOf(const Moment: Double): TArray<Double>;
begin
  SetLength(Result, COMPONENT_COUNT);
  for var Part := TDateField.Year to TDateField.Milliseconds do
  begin
    Result[Ord(Part)] := ComponentOf(Part, Moment);
  end;
end;

class function TJSDateBuiltins.MakeFullYear(const Year: Double): Double;
begin
  Result := Year;

  const WholeYear = TJSDateMath.ToInteger(Year);
  const IsTwoDigitYear = (WholeYear >= 0) and (WholeYear <= LAST_TWO_DIGIT_YEAR);
  if IsTwoDigitYear then
    Result := YEAR_OFFSET + WholeYear;
end;

class function TJSDateBuiltins.ComposeTime(const Components: TArray<Double>): Double;
begin
  const Year = Components[Ord(TDateField.Year)];
  const Month = Components[Ord(TDateField.Month)];
  const Day = Components[Ord(TDateField.Date)];
  const Hour = Components[Ord(TDateField.Hours)];
  const Minute = Components[Ord(TDateField.Minutes)];
  const Second = Components[Ord(TDateField.Seconds)];
  const Millisecond = Components[Ord(TDateField.Milliseconds)];

  const DayNumber = TJSDateMath.MakeDay(Year, Month, Day);
  const TimeOfDay = TJSDateMath.MakeTime(Hour, Minute, Second, Millisecond);

  Result := TJSDateMath.MakeDate(DayNumber, TimeOfDay);
end;

class function TJSDateBuiltins.CollectComponents(const Args: TArray<TJSValue>): TArray<Double>;
begin
  SetLength(Result, COMPONENT_COUNT);
  Result[Ord(TDateField.Year)] := System.Math.NaN;
  Result[Ord(TDateField.Month)] := DEFAULT_MONTH;
  Result[Ord(TDateField.Date)] := DEFAULT_DAY;

  const ProvidedCount = Min(Length(Args), COMPONENT_COUNT);
  for var Index := 0 to ProvidedCount - 1 do
  begin
    Result[Index] := TJSConversions.ToNumber(Args[Index]);
  end;

  Result[Ord(TDateField.Year)] := MakeFullYear(Result[Ord(TDateField.Year)]);
end;

class function TJSDateBuiltins.NumberArgumentOrNaN(const Args: TArray<TJSValue>; const Position: Integer): Double;
begin
  const IsProvided = (Length(Args) > Position);
  if not IsProvided then
    Exit(System.Math.NaN);

  Result := TJSConversions.ToNumber(Args[Position]);
end;

class function TJSDateBuiltins.SetterValueCount(const Field: TDateField; const ArgumentCount: Integer): Integer;
begin
  const MaximumCount = SETTER_ARGUMENT_COUNTS[Field];
  const ProvidedCount = Min(ArgumentCount, MaximumCount);

  Result := Max(1, ProvidedCount);
end;

class function TJSDateBuiltins.CollectSetterValues(const Field: TDateField;
                                                   const Args: TArray<TJSValue>): TArray<Double>;
begin
  const ValueCount = SetterValueCount(Field, Length(Args));
  SetLength(Result, ValueCount);
  for var Index := 0 to High(Result) do
  begin
    Result[Index] := NumberArgumentOrNaN(Args, Index);
  end;
end;

class function TJSDateBuiltins.TryGetSetterMoment(const OriginalTime: Double; const Field: TDateField;
                                                  const IsLocal: Boolean; out Moment: Double): Boolean;
begin
  Moment := 0;

  const IsInvalidTime = System.Math.IsNaN(OriginalTime);
  if not IsInvalidTime then
  begin
    Moment := MomentFor(OriginalTime, IsLocal);
    Exit(True);
  end;

  Result := (Field = TDateField.Year);
end;

class function TJSDateBuiltins.TimeFromValue(const Value: TJSValue): Double;
begin
  var SourceDate: IJSDate;
  if Supports(Value.ToObject, IJSDate, SourceDate) then
  begin
    Result := TJSDateMath.TimeClip(SourceDate.Time);
    Exit;
  end;

  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Default);
  if Primitive.IsString then
  begin
    Result := TJSDateParser.Parse(Primitive.AsString);
    Exit;
  end;

  const Number = Primitive.ToNumber;

  Result := TJSDateMath.TimeClip(Number);
end;

class function TJSDateBuiltins.HintFromArguments(const Args: TArray<TJSValue>): TJSPrimitiveHint;
begin
  var HintName := string.Empty;
  const HasHint = (Length(Args) > 0) and Args[0].IsString;
  if HasHint then
    HintName := Args[0].AsString;

  const IsStringHint = (HintName = HINT_STRING) or (HintName = HINT_DEFAULT);
  if IsStringHint then
    Exit(TJSPrimitiveHint.String_);

  const IsNumberHint = (HintName = HINT_NUMBER);
  if IsNumberHint then
    Exit(TJSPrimitiveHint.Number);

  raise TJSErrorFactory.TypeError(INVALID_HINT);
end;

function TJSDateBuiltins.TimeFromComponents(const Args: TArray<TJSValue>): Double;
begin
  const Components = CollectComponents(Args);
  const LocalMoment = ComposeTime(Components);
  const UtcMoment = TJSDateMath.ToUtc(LocalMoment);

  Result := TJSDateMath.TimeClip(UtcMoment);
end;

function TJSDateBuiltins.TimeFromArguments(const Args: TArray<TJSValue>): Double;
begin
  case Length(Args) of
    0: Result := TJSDateMath.CurrentTime;
    1: Result := TimeFromValue(Args[0]);
  else
    Result := TimeFromComponents(Args);
  end;
end;

function TJSDateBuiltins.ConstructDate(const Args: TArray<TJSValue>): TJSValue;
begin
  const Time = TimeFromArguments(Args);
  const NewDate: IJSObject = TJSDate.Create(Time);
  NewDate.Prototype := FPrototype;

  Result := TJSValue.CreateObject(NewDate);
end;

function TJSDateBuiltins.CallOrConstruct(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const IsConstruction = TJSPrototypeMethods.IsConstructCall(This, FPrototype);
  if IsConstruction then
  begin
    Result := ConstructDate(Args);
    Exit;
  end;

  const CurrentTime = TJSDateMath.CurrentTime;
  const Text = TJSDateText.ToFullString(CurrentTime);

  Result := TJSValue.CreateString(Text);
end;

function TJSDateBuiltins.DefineMethod(const Name: string; const ParameterCount: Integer;
                                      const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  TJSFunction.DefineLength(Result, ParameterCount);
  TJSFunction.DefineName(Result, Name);

  const MethodValue = TJSValue.CreateObject(Result);
  DefineHiddenMember(FPrototype, Name, MethodValue, True);
end;

function TJSDateBuiltins.BindGetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;
      if System.Math.IsNaN(Time) then
      begin
        Result := TJSValue.CreateNaN;
        Exit;
      end;

      const Moment = MomentFor(Time, IsLocal);
      const Component = ComponentOf(Field, Moment);

      Result := TJSValue.CreateNumber(Component);
    end;
end;

function TJSDateBuiltins.ApplySetter(const Target: IJSDate; const OriginalTime: Double; const Field: TDateField;
                                     const Values: TArray<Double>; const IsLocal: Boolean): Double;
begin
  var Moment: Double;
  const CanApply = TryGetSetterMoment(OriginalTime, Field, IsLocal, Moment);
  if not CanApply then
    Exit(System.Math.NaN);

  var Components := ComponentsOf(Moment);
  for var Index := 0 to High(Values) do
  begin
    Components[Ord(Field) + Index] := Values[Index];
  end;

  const ComposedTime = ComposeTime(Components);

  var UtcTime := ComposedTime;
  if IsLocal then
    UtcTime := TJSDateMath.ToUtc(ComposedTime);

  Result := TJSDateMath.TimeClip(UtcTime);
  Target.Time := Result;
end;

function TJSDateBuiltins.SetField(const This: IJSObject; const Args: TArray<TJSValue>; const Field: TDateField;
                                  const IsLocal: Boolean): TJSValue;
begin
  const Target = ThisDate(This);
  const OriginalTime = Target.Time;
  const Values = CollectSetterValues(Field, Args);
  const NewTime = ApplySetter(Target, OriginalTime, Field, Values, IsLocal);

  Result := TJSValue.CreateNumber(NewTime);
end;

function TJSDateBuiltins.BindSetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetField(This, Args, Field, IsLocal);
    end;
end;

function TJSDateBuiltins.BindFormatter(const Form: TTextForm): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;
      if System.Math.IsNaN(Time) then
      begin
        Result := TJSValue.CreateString(INVALID_DATE);
        Exit;
      end;

      const Text = FormatTime(Form, Time);

      Result := TJSValue.CreateString(Text);
    end;
end;

function TJSDateBuiltins.LocaleString(const This: IJSObject; const Args: TArray<TJSValue>; const Form: TTextForm;
                                      const Scope: TJSDateFormatScope): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
  begin
    Result := TJSValue.CreateString(INVALID_DATE);
    Exit;
  end;

  var Request: TJSLocaleRequest;
  const IsLocaleRequested = TJSLocaleArguments.TryCreateRequest(Args, Request);
  if not IsLocaleRequested then
  begin
    const FormattedTime = FormatTime(Form, Time);

    Result := TJSValue.CreateString(FormattedTime);
    Exit;
  end;

  const RequestedOptions = TJSLocaleArguments.ReadDateOptions(Request);
  const Options = TJSLocaleDateFormatter.WithDefaults(RequestedOptions, Scope);
  const UsesUtc = TJSLocaleArguments.UsesUtcZone(Request);
  const Moment = MomentFor(Time, not UsesUtc);
  const Text = TJSLocaleDateFormatter.FormatMoment(Moment, Request.Locale, Options);

  Result := TJSValue.CreateString(Text);
end;

function TJSDateBuiltins.BindLocaleFormatter(const Form: TTextForm;
                                             const Scope: TJSDateFormatScope): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := LocaleString(This, Args, Form, Scope);
    end;
end;

function TJSDateBuiltins.BindTimeValue: TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;

      Result := TJSValue.CreateNumber(Time);
    end;
end;

function TJSDateBuiltins.SetTime(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = ThisDate(This);
  const Requested = NumberArgumentOrNaN(Args, 0);

  Target.Time := TJSDateMath.TimeClip(Requested);
  Result := TJSValue.CreateNumber(Target.Time);
end;

function TJSDateBuiltins.SetYear(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = ThisDate(This);
  const OriginalTime = Target.Time;
  const Requested = NumberArgumentOrNaN(Args, 0);

  if System.Math.IsNaN(Requested) then
  begin
    Target.Time := System.Math.NaN;
    Result := TJSValue.CreateNaN;
    Exit;
  end;

  const FullYear = MakeFullYear(Requested);
  const NewTime = ApplySetter(Target, OriginalTime, TDateField.Year, [FullYear], True);

  Result := TJSValue.CreateNumber(NewTime);
end;

function TJSDateBuiltins.GetYear(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
  begin
    Result := TJSValue.CreateNaN;
    Exit;
  end;

  const LocalMoment = TJSDateMath.LocalTime(Time);
  const FullYear = TJSDateMath.YearFromTime(LocalMoment);

  Result := TJSValue.CreateNumber(FullYear - YEAR_OFFSET);
end;

function TJSDateBuiltins.GetTimezoneOffset(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
  begin
    Result := TJSValue.CreateNaN;
    Exit;
  end;

  const LocalMoment = TJSDateMath.LocalTime(Time);
  const OffsetMinutes = (Time - LocalMoment) / TJSDateMath.MS_PER_MINUTE;

  Result := TJSValue.CreateNumber(OffsetMinutes);
end;

function TJSDateBuiltins.ToIsoString(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
    raise TJSErrorFactory.RangeError(INVALID_TIME_VALUE);

  const Text = TJSDateText.ToIsoString(Time);

  Result := TJSValue.CreateString(Text);
end;

function TJSDateBuiltins.ToJson(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(THIS_NOT_A_DATE);

  const Subject = TJSValue.CreateObject(This);

  const Primitive = Subject.ToPrimitive(False);
  const IsNonFinite = Primitive.IsNumber and (not TJSDateMath.IsFinite(Primitive.AsNumber));
  if IsNonFinite then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  const Candidate = This.GetProperty(METHOD_TO_ISO_STRING);
  const Converter = TJSConversions.AsFunction(Candidate);
  const HasCallableConverter = Assigned(Converter);
  if not HasCallableConverter then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);

  Result := Converter.Call(This, nil);
end;

procedure TJSDateBuiltins.DefineGettersAndSetters;
begin
  for var Field := Low(TDateField) to High(TDateField) do
  begin
    for var IsLocal in [True, False] do
    begin
      const Infix = IfThen(IsLocal, string.Empty, UTC_INFIX);
      const GetterName = Format(ACCESSOR_NAME_FORMAT, [GET_PREFIX, Infix, FIELD_NAMES[Field]]);
      const Getter = BindGetter(Field, IsLocal);
      DefineMethod(GetterName, 0, Getter);

      const SetterArgumentCount = SETTER_ARGUMENT_COUNTS[Field];
      const HasSetter = (SetterArgumentCount > 0);
      if HasSetter then
      begin
        const SetterName = Format(ACCESSOR_NAME_FORMAT, [SET_PREFIX, Infix, FIELD_NAMES[Field]]);
        const Setter = BindSetter(Field, IsLocal);
        DefineMethod(SetterName, SetterArgumentCount, Setter);
      end;
    end;
  end;
end;

function TJSDateBuiltins.DefineFormatter(const Name: string; const Form: TTextForm): IJSFunction;
begin
  const Formatter = BindFormatter(Form);

  Result := DefineMethod(Name, 0, Formatter);
end;

function TJSDateBuiltins.DefineLocaleFormatter(const Name: string; const Form: TTextForm;
                                               const Scope: TJSDateFormatScope): IJSFunction;
begin
  const Formatter = BindLocaleFormatter(Form, Scope);

  Result := DefineMethod(Name, 0, Formatter);
end;

function TJSDateBuiltins.DefineTimeValueMethod(const Name: string): IJSFunction;
begin
  const TimeValueMethod = BindTimeValue;

  Result := DefineMethod(Name, 0, TimeValueMethod);
end;

function TJSDateBuiltins.DefineThisMethod(const Name: string; const ParameterCount: Integer;
                                          const Method: TThisMethod): IJSFunction;
begin
  const Native = BindThis(Method);

  Result := DefineMethod(Name, ParameterCount, Native);
end;

function TJSDateBuiltins.DefineThisAndArgumentsMethod(const Name: string; const ParameterCount: Integer;
                                                      const Method: TThisAndArgumentsMethod): IJSFunction;
begin
  const Native = BindThisAndArguments(Method);

  Result := DefineMethod(Name, ParameterCount, Native);
end;

procedure TJSDateBuiltins.DefineStringMethods;
begin
  DefineFormatter(TO_STRING_METHOD, TTextForm.Full);
  DefineFormatter(METHOD_TO_DATE_STRING, TTextForm.DateOnly);
  DefineFormatter(METHOD_TO_TIME_STRING, TTextForm.TimeOnly);
  DefineLocaleFormatter(METHOD_TO_LOCALE_STRING, TTextForm.Full, TJSDateFormatScope.DateAndTime);
  DefineLocaleFormatter(METHOD_TO_LOCALE_DATE_STRING, TTextForm.DateOnly, TJSDateFormatScope.DateOnly);
  DefineLocaleFormatter(METHOD_TO_LOCALE_TIME_STRING, TTextForm.TimeOnly, TJSDateFormatScope.TimeOnly);

  const UtcConverter = DefineFormatter(METHOD_TO_UTC_STRING, TTextForm.Utc);
  const GmtValue = TJSValue.CreateObject(UtcConverter);
  DefineHiddenMember(FPrototype, METHOD_TO_GMT_STRING, GmtValue, True);
end;

function TJSDateBuiltins.ToPrimitiveMethod(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  if TJSStrictThis.IsNonObject(This) then
    raise TJSErrorFactory.TypeError(THIS_NOT_AN_OBJECT);

  const Hint = HintFromArguments(Args);
  const Subject = TJSValue.CreateObject(This);

  Result := Subject.OrdinaryToPrimitive(Hint);
end;

procedure TJSDateBuiltins.DefineToPrimitive;
begin
  const Method = BindThisAndArguments(ToPrimitiveMethod);
  const Func: IJSFunction = TJSFunction.CreateNative(TO_PRIMITIVE_FUNCTION_NAME, Method);
  Func.IsConstructor := False;
  Func.ReceivesRawThis := True;
  TJSFunction.DefineLength(Func, 1);
  TJSFunction.DefineName(Func, TO_PRIMITIVE_FUNCTION_NAME);

  const ToPrimitiveKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToPrimitive);
  const FuncValue = TJSValue.CreateObject(Func);
  DefineHiddenMember(FPrototype, ToPrimitiveKey, FuncValue, False);
end;

function TJSDateBuiltins.BindThis(const Method: TThisMethod): TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Method(This);
    end;
end;

function TJSDateBuiltins.BindThisAndArguments(const Method: TThisAndArgumentsMethod): TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Method(This, Args);
    end;
end;

procedure TJSDateBuiltins.DefineUtilityMethods;
begin
  DefineTimeValueMethod(VALUE_OF_METHOD);
  DefineTimeValueMethod(METHOD_GET_TIME);
  DefineThisMethod(METHOD_GET_YEAR, 0, GetYear);
  DefineThisMethod(METHOD_GET_TIMEZONE_OFFSET, 0, GetTimezoneOffset);
  DefineThisAndArgumentsMethod(METHOD_SET_TIME, 1, SetTime);
  DefineThisAndArgumentsMethod(METHOD_SET_YEAR, 1, SetYear);
  DefineThisMethod(METHOD_TO_ISO_STRING, 0, ToIsoString);
  DefineThisMethod(METHOD_TO_JSON, 1, ToJson);
end;

function TJSDateBuiltins.StaticNow(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateNumber(TJSDateMath.CurrentTime);
end;

function TJSDateBuiltins.StaticParse(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const HasText = (Length(Args) > 0);
  if not HasText then
  begin
    Result := TJSValue.CreateNaN;
    Exit;
  end;

  const Primitive = Args[0].ToPrimitive(True);
  const Time = TJSDateParser.Parse(Primitive.ToString);

  Result := TJSValue.CreateNumber(Time);
end;

function TJSDateBuiltins.StaticUtc(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Components = CollectComponents(Args);
  const Moment = ComposeTime(Components);
  const Time = TJSDateMath.TimeClip(Moment);

  Result := TJSValue.CreateNumber(Time);
end;

procedure TJSDateBuiltins.DefineStaticMethod(const Target: IJSObject; const Name: string;
                                             const ParameterCount: Integer;
                                             const Method: TThisAndArgumentsMethod);
begin
  const Native = BindThisAndArguments(Method);
  const Func: IJSFunction = TJSFunction.CreateNative(Name, Native);
  Func.IsConstructor := False;
  TJSFunction.DefineLength(Func, ParameterCount);
  TJSFunction.DefineName(Func, Name);

  const FuncValue = TJSValue.CreateObject(Func);
  DefineHiddenMember(Target, Name, FuncValue, True);
end;

procedure TJSDateBuiltins.DefineStaticMethods(const Constructor_: IJSFunction);
begin
  const Target: IJSObject = Constructor_;

  DefineStaticMethod(Target, STATIC_NOW_NAME, 0, StaticNow);
  DefineStaticMethod(Target, STATIC_PARSE_NAME, 1, StaticParse);
  DefineStaticMethod(Target, STATIC_UTC_NAME, CONSTRUCTOR_LENGTH, StaticUtc);
end;

function TJSDateBuiltins.CreateConstructor: IJSFunction;
begin
  const Native = BindThisAndArguments(CallOrConstruct);
  Result := TJSFunction.CreateNative(DATE_NAME, Native);

  TJSFunction.DefineLength(Result, CONSTRUCTOR_LENGTH);
  TJSFunction.DefineName(Result, DATE_NAME);
  DefineStaticMethods(Result);
  DefineGettersAndSetters;
  DefineStringMethods;
  DefineUtilityMethods;
  DefineToPrimitive;
end;

end.
