unit JS4D.DateBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.LocaleDateFormat;

type
  // The Date constructor and Date.prototype of ES5 15.9.
  TJSDateBuiltins = class
  private
    type
      TDateField = (Year, Month, Date, Hours, Minutes, Seconds, Milliseconds, WeekDay);
      TTextForm = (Full, DateOnly, TimeOnly, Utc);

    const
      FieldNames: array[TDateField] of string = ('FullYear', 'Month', 'Date', 'Hours', 'Minutes', 'Seconds',
                                                 'Milliseconds', 'Day');
      SetterArgumentCounts: array[TDateField] of Integer = (3, 2, 1, 4, 3, 2, 1, 0);
      FieldCount = Ord(TDateField.WeekDay);
      ConstructorLength = 7;

  private
    FPrototype: IJSObject;

    class procedure DefineFunctionAttributes(const Func: IJSFunction; const Name: string;
                                             const ParameterCount: Integer); static;
    class function ThisDate(const This: IJSObject): IJSDate; static;
    class function ToNumberValue(const Value: TJSValue): Double; static;
    class function ComponentOf(const Field: TDateField; const Moment: Double): Double; static;
    class function MakeFullYear(const Year: Double): Double; static;
    class function ComposeTime(const Components: TArray<Double>): Double; static;
    class function CollectComponents(const Args: TArray<TJSValue>): TArray<Double>; static;
    class function TimeFromValue(const Value: TJSValue): Double; static;
    class function NumberResult(const Time: Double): TJSValue; static;
    class function FormatTime(const Form: TTextForm; const Time: Double): string; static;

    function DefineMethod(const Name: string; const ParameterCount: Integer; const Method: TNativeFunction): IJSFunction;
    function BindGetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
    function BindSetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
    function BindFormatter(const Form: TTextForm): TNativeFunction;
    function BindLocaleFormatter(const Form: TTextForm; const Scope: TJSDateFormatScope): TNativeFunction;
    function BindTimeValue: TNativeFunction;

    function ApplySetter(const Target: IJSDate; const OriginalTime: Double; const Field: TDateField;
                         const Values: TArray<Double>; const IsLocal: Boolean): Double;
    function TimeFromComponents(const Args: TArray<TJSValue>): Double;
    function TimeFromArguments(const Args: TArray<TJSValue>): Double;
    function ConstructDate(const Args: TArray<TJSValue>): TJSValue;
    function SetTime(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function SetYear(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetYear(const This: IJSObject): TJSValue;
    function GetTimezoneOffset(const This: IJSObject): TJSValue;
    function ToIsoString(const This: IJSObject): TJSValue;
    function ToJson(const This: IJSObject): TJSValue;

    procedure DefineToPrimitive;
    procedure DefineGettersAndSetters;
    procedure DefineStringMethods;
    procedure DefineUtilityMethods;
    procedure DefineStaticMethods(const Constructor_: IJSFunction);

  public
    constructor Create(const PrototypeObj: IJSObject);

    function CreateConstructor: IJSFunction;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  JS4D.Errors,
  JS4D.SymbolRegistry,
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
  GET_PREFIX = 'get';
  SET_PREFIX = 'set';
  UTC_INFIX = 'UTC';
  METHOD_GET_TIME = 'getTime';
  METHOD_VALUE_OF = 'valueOf';
  METHOD_TO_STRING = 'toString';
  METHOD_TO_DATE_STRING = 'toDateString';
  METHOD_TO_TIME_STRING = 'toTimeString';
  METHOD_TO_UTC_STRING = 'toUTCString';
  METHOD_TO_ISO_STRING = 'toISOString';
  PROPERTY_LENGTH = 'length';
  PROPERTY_NAME = 'name';
  DATE_NAME = 'Date';
  YEAR_OFFSET = 1900;
  LAST_TWO_DIGIT_YEAR = 99;
  DefaultMonth = 0;
  DefaultDay = 1;

constructor TJSDateBuiltins.Create(const PrototypeObj: IJSObject);
begin
  inherited Create;
  FPrototype := PrototypeObj;
end;

class procedure TJSDateBuiltins.DefineFunctionAttributes(const Func: IJSFunction; const Name: string;
                                                         const ParameterCount: Integer);
begin
  const Target: IJSObject = Func;

  var LengthDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(ParameterCount));
  LengthDescriptor.Writable := False;
  LengthDescriptor.Enumerable := False;
  Target.DefineProperty(PROPERTY_LENGTH, LengthDescriptor);

  var NameDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateString(Name));
  NameDescriptor.Writable := False;
  NameDescriptor.Enumerable := False;
  Target.DefineProperty(PROPERTY_NAME, NameDescriptor);
end;

class function TJSDateBuiltins.ThisDate(const This: IJSObject): IJSDate;
begin
  if not Supports(This, IJSDate, Result) then
    raise TJSErrorFactory.TypeError(THIS_NOT_A_DATE);
end;

class function TJSDateBuiltins.ToNumberValue(const Value: TJSValue): Double;
begin
  Result := Value.ToPrimitive(False).ToNumber;
end;

class function TJSDateBuiltins.NumberResult(const Time: Double): TJSValue;
begin
  Result := TJSValue.CreateNumber(Time);
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
  const DayNumber = TJSDateMath.MakeDay(Components[Ord(TDateField.Year)],
                                        Components[Ord(TDateField.Month)],
                                        Components[Ord(TDateField.Date)]);
  const TimeOfDay = TJSDateMath.MakeTime(Components[Ord(TDateField.Hours)],
                                         Components[Ord(TDateField.Minutes)],
                                         Components[Ord(TDateField.Seconds)],
                                         Components[Ord(TDateField.Milliseconds)]);

  Result := TJSDateMath.MakeDate(DayNumber, TimeOfDay);
end;

class function TJSDateBuiltins.CollectComponents(const Args: TArray<TJSValue>): TArray<Double>;
begin
  SetLength(Result, FieldCount);
  Result[Ord(TDateField.Year)] := System.Math.NaN;
  Result[Ord(TDateField.Month)] := DefaultMonth;
  Result[Ord(TDateField.Date)] := DefaultDay;

  for var Index := 0 to Min(Length(Args), FieldCount) - 1 do
  begin
    Result[Index] := ToNumberValue(Args[Index]);
  end;

  Result[Ord(TDateField.Year)] := MakeFullYear(Result[Ord(TDateField.Year)]);
end;

class function TJSDateBuiltins.TimeFromValue(const Value: TJSValue): Double;
begin
  var SourceDate: IJSDate;
  if Supports(Value.ToObject, IJSDate, SourceDate) then
    Exit(TJSDateMath.TimeClip(SourceDate.Time));

  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Default);
  if Primitive.IsString then
    Result := TJSDateParser.Parse(Primitive.AsString)
  else
    Result := TJSDateMath.TimeClip(Primitive.ToNumber);
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
  const NewDate: IJSObject = TJSDate.Create(TimeFromArguments(Args));
  NewDate.Prototype := FPrototype;

  Result := TJSValue.CreateObject(NewDate);
end;

function TJSDateBuiltins.DefineMethod(const Name: string; const ParameterCount: Integer;
                                      const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  DefineFunctionAttributes(Result, Name, ParameterCount);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Result));
  Descriptor.Enumerable := False;
  FPrototype.DefineProperty(Name, Descriptor);
end;

function TJSDateBuiltins.BindGetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;
      if System.Math.IsNaN(Time) then
        Exit(TJSValue.CreateNaN);

      const Moment = IfThen(IsLocal, TJSDateMath.LocalTime(Time), Time);

      const Component = ComponentOf(Field, Moment);

      Result := NumberResult(Component);
    end;
end;

function TJSDateBuiltins.ApplySetter(const Target: IJSDate; const OriginalTime: Double; const Field: TDateField;
                                     const Values: TArray<Double>; const IsLocal: Boolean): Double;
begin
  var Moment := OriginalTime;

  if System.Math.IsNaN(Moment) then
  begin
    if Field <> TDateField.Year then
      Exit(System.Math.NaN);

    Moment := 0;
  end
  else if IsLocal then
  begin
    Moment := TJSDateMath.LocalTime(Moment);
  end;

  var Components: TArray<Double>;
  SetLength(Components, FieldCount);
  for var Part := TDateField.Year to TDateField.Milliseconds do
  begin
    Components[Ord(Part)] := ComponentOf(Part, Moment);
  end;

  for var Index := 0 to High(Values) do
  begin
    Components[Ord(Field) + Index] := Values[Index];
  end;

  var NewTime := ComposeTime(Components);
  if IsLocal then
    NewTime := TJSDateMath.ToUtc(NewTime);

  Result := TJSDateMath.TimeClip(NewTime);
  Target.Time := Result;
end;

function TJSDateBuiltins.BindSetter(const Field: TDateField; const IsLocal: Boolean): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Target = ThisDate(This);
      const OriginalTime = Target.Time;

      var Values: TArray<Double>;
      SetLength(Values, Max(1, Min(Length(Args), SetterArgumentCounts[Field])));
      for var Index := 0 to High(Values) do
      begin
        if Index < Length(Args) then
          Values[Index] := ToNumberValue(Args[Index])
        else
          Values[Index] := System.Math.NaN;
      end;

      const NewTime = ApplySetter(Target, OriginalTime, Field, Values, IsLocal);

      Result := NumberResult(NewTime);
    end;
end;

function TJSDateBuiltins.BindFormatter(const Form: TTextForm): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;
      if System.Math.IsNaN(Time) then
        Exit(TJSValue.CreateString(INVALID_DATE));

      Result := TJSValue.CreateString(FormatTime(Form, Time));
    end;
end;

function TJSDateBuiltins.BindLocaleFormatter(const Form: TTextForm;
                                             const Scope: TJSDateFormatScope): TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Time = ThisDate(This).Time;
      if System.Math.IsNaN(Time) then
        Exit(TJSValue.CreateString(INVALID_DATE));

      var Request: TJSLocaleRequest;
      const IsLocaleRequested = TJSLocaleArguments.TryCreateRequest(Args, Request);
      if not IsLocaleRequested then
      begin
        const FormattedTime = FormatTime(Form, Time);

        Exit(TJSValue.CreateString(FormattedTime));
      end;

      const RequestedOptions = TJSLocaleArguments.ReadDateOptions(Request);
      const Options = TJSLocaleDateFormatter.WithDefaults(RequestedOptions, Scope);
      const UsesUtc = TJSLocaleArguments.UsesUtcZone(Request);
      const Moment = IfThen(UsesUtc, Time, TJSDateMath.LocalTime(Time));
      const Text = TJSLocaleDateFormatter.FormatMoment(Moment, Request.Locale, Options);

      Result := TJSValue.CreateString(Text);
    end;
end;

function TJSDateBuiltins.BindTimeValue: TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := NumberResult(ThisDate(This).Time);
    end;
end;

function TJSDateBuiltins.SetTime(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = ThisDate(This);

  var Requested := System.Math.NaN;
  if Length(Args) > 0 then
    Requested := ToNumberValue(Args[0]);

  Target.Time := TJSDateMath.TimeClip(Requested);
  Result := NumberResult(Target.Time);
end;

function TJSDateBuiltins.SetYear(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = ThisDate(This);
  const OriginalTime = Target.Time;

  var Requested := System.Math.NaN;
  if Length(Args) > 0 then
    Requested := ToNumberValue(Args[0]);

  if System.Math.IsNaN(Requested) then
  begin
    Target.Time := System.Math.NaN;
    Exit(TJSValue.CreateNaN);
  end;

  const NewTime = ApplySetter(Target, OriginalTime, TDateField.Year, [MakeFullYear(Requested)], True);

  Result := NumberResult(NewTime);
end;

function TJSDateBuiltins.GetYear(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
    Exit(TJSValue.CreateNaN);

  const LocalMoment = TJSDateMath.LocalTime(Time);

  Result := NumberResult(TJSDateMath.YearFromTime(LocalMoment) - YEAR_OFFSET);
end;

function TJSDateBuiltins.GetTimezoneOffset(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
    Exit(TJSValue.CreateNaN);

  Result := NumberResult((Time - TJSDateMath.LocalTime(Time)) / TJSDateMath.MsPerMinute);
end;

function TJSDateBuiltins.ToIsoString(const This: IJSObject): TJSValue;
begin
  const Time = ThisDate(This).Time;
  if System.Math.IsNaN(Time) then
    raise TJSErrorFactory.RangeError(INVALID_TIME_VALUE);

  Result := TJSValue.CreateString(TJSDateText.ToIsoString(Time));
end;

function TJSDateBuiltins.ToJson(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(THIS_NOT_A_DATE);

  const Subject = TJSValue.CreateObject(This);

  const Primitive = Subject.ToPrimitive(False);
  const IsNonFinite = Primitive.IsNumber and (not TJSDateMath.IsFinite(Primitive.AsNumber));
  if IsNonFinite then
    Exit(TJSValue.CreateNull);

  var Converter: IJSFunction;
  const Candidate = This.GetProperty(METHOD_TO_ISO_STRING);
  if not (Candidate.IsFunction and Supports(Candidate.ToObject, IJSFunction, Converter)) then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);

  Result := Converter.Call(This, nil);
end;

procedure TJSDateBuiltins.DefineGettersAndSetters;
begin
  for var Field := Low(TDateField) to High(TDateField) do
  begin
    for var IsLocal in [True, False] do
    begin
      const Infix = IfThen(IsLocal, '', UTC_INFIX);

      DefineMethod(GET_PREFIX + Infix + FieldNames[Field], 0, BindGetter(Field, IsLocal));

      const HasSetter = (SetterArgumentCounts[Field] > 0);
      if HasSetter then
        DefineMethod(SET_PREFIX + Infix + FieldNames[Field], SetterArgumentCounts[Field], BindSetter(Field, IsLocal));
    end;
  end;
end;

procedure TJSDateBuiltins.DefineStringMethods;
begin
  DefineMethod(METHOD_TO_STRING, 0, BindFormatter(TTextForm.Full));
  DefineMethod(METHOD_TO_DATE_STRING, 0, BindFormatter(TTextForm.DateOnly));
  DefineMethod(METHOD_TO_TIME_STRING, 0, BindFormatter(TTextForm.TimeOnly));
  DefineMethod('toLocaleString', 0, BindLocaleFormatter(TTextForm.Full, TJSDateFormatScope.DateAndTime));
  DefineMethod('toLocaleDateString', 0, BindLocaleFormatter(TTextForm.DateOnly, TJSDateFormatScope.DateOnly));
  DefineMethod('toLocaleTimeString', 0, BindLocaleFormatter(TTextForm.TimeOnly, TJSDateFormatScope.TimeOnly));

  const UtcConverter = DefineMethod(METHOD_TO_UTC_STRING, 0, BindFormatter(TTextForm.Utc));
  var GmtDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(UtcConverter));
  GmtDescriptor.Enumerable := False;
  FPrototype.DefineProperty('toGMTString', GmtDescriptor);
end;

procedure TJSDateBuiltins.DefineToPrimitive;
begin
  const Func: IJSFunction = TJSFunction.CreateNative(TO_PRIMITIVE_FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if not Assigned(This) then
        raise TJSErrorFactory.TypeError(THIS_NOT_AN_OBJECT);

      var HintName := '';
      if (Length(Args) > 0) and Args[0].IsString then
        HintName := Args[0].AsString;

      var Hint: TJSPrimitiveHint;
      if (HintName = HINT_STRING) or (HintName = HINT_DEFAULT) then
        Hint := TJSPrimitiveHint.String_
      else if HintName = HINT_NUMBER then
        Hint := TJSPrimitiveHint.Number
      else
        raise TJSErrorFactory.TypeError(INVALID_HINT);

      Result := TJSValue.CreateObject(This).OrdinaryToPrimitive(Hint);
    end);
  Func.IsConstructor := False;
  DefineFunctionAttributes(Func, TO_PRIMITIVE_FUNCTION_NAME, 1);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  FPrototype.DefineProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToPrimitive), Descriptor);
end;

procedure TJSDateBuiltins.DefineUtilityMethods;
begin
  DefineMethod(METHOD_VALUE_OF, 0, BindTimeValue());
  DefineMethod(METHOD_GET_TIME, 0, BindTimeValue());
  DefineMethod('getYear', 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := GetYear(This);
    end);
  DefineMethod('getTimezoneOffset', 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := GetTimezoneOffset(This);
    end);
  DefineMethod('setTime', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetTime(This, Args);
    end);
  DefineMethod('setYear', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetYear(This, Args);
    end);
  DefineMethod(METHOD_TO_ISO_STRING, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ToIsoString(This);
    end);
  DefineMethod('toJSON', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ToJson(This);
    end);
end;

procedure TJSDateBuiltins.DefineStaticMethods(const Constructor_: IJSFunction);
begin
  const Target: IJSObject = Constructor_;

  const NowFunc: IJSFunction = TJSFunction.CreateNative('now',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := NumberResult(TJSDateMath.CurrentTime);
    end);
  const ParseFunc: IJSFunction = TJSFunction.CreateNative('parse',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Length(Args) = 0 then
        Exit(TJSValue.CreateNaN);

      const Primitive = Args[0].ToPrimitive(True);

      Result := NumberResult(TJSDateParser.Parse(Primitive.ToString));
    end);
  const UtcFunc: IJSFunction = TJSFunction.CreateNative('UTC',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Components = CollectComponents(Args);
      const Moment = ComposeTime(Components);

      Result := NumberResult(TJSDateMath.TimeClip(Moment));
    end);

  const StaticMethods: TArray<IJSFunction> = [NowFunc, ParseFunc, UtcFunc];
  const ParameterCounts: TArray<Integer> = [0, 1, ConstructorLength];
  for var Index := 0 to High(StaticMethods) do
  begin
    const StaticMethod = StaticMethods[Index];
    StaticMethod.IsConstructor := False;
    DefineFunctionAttributes(StaticMethod, StaticMethod.Name, ParameterCounts[Index]);

    var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(StaticMethod));
    Descriptor.Enumerable := False;
    Target.DefineProperty(StaticMethod.Name, Descriptor);
  end;
end;

function TJSDateBuiltins.CreateConstructor: IJSFunction;
begin
  Result := TJSFunction.CreateNative(DATE_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if TJSPrototypeMethods.IsConstructCall(This, FPrototype) then
        Exit(ConstructDate(Args));

      Result := TJSValue.CreateString(TJSDateText.ToFullString(TJSDateMath.CurrentTime));
    end);

  DefineFunctionAttributes(Result, DATE_NAME, ConstructorLength);
  DefineStaticMethods(Result);
  DefineGettersAndSetters;
  DefineStringMethods;
  DefineUtilityMethods;
  DefineToPrimitive;
end;

end.
