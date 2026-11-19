unit JS4D.LocaleArguments;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.BuiltInLocales,
  JS4D.LocaleNumberFormat,
  JS4D.LocaleDateFormat;

type
  TJSLocaleRequest = record
    Locale: PJSLocaleDefinition;
    Options: TJSValue;
  end;

  TJSLocaleArguments = class
  private
    const
      LOCALES_INDEX = 0;
      OPTIONS_INDEX = 1;
      UNSPECIFIED_DIGITS = -1;
      MAX_FRACTION_DIGITS = 100;
      MAX_INTEGER_DIGITS = 21;
      MIN_INTEGER_DIGITS = 1;
      CURRENCY_CODE_LENGTH = 3;
      ZONE_BOUNDARY = '|';
      UTC_ZONE_NAMES = '|UTC|GMT|ETC/UTC|ETC/GMT|';
      MAX_LOCALE_LIST_LENGTH = 1000;
      NAME_STYLE_OPTION = 'style';
      NAME_CURRENCY_DISPLAY_OPTION = 'currencyDisplay';
      NAME_USE_GROUPING_OPTION = 'useGrouping';
      NAME_MINIMUM_FRACTION_DIGITS_OPTION = 'minimumFractionDigits';
      NAME_MAXIMUM_FRACTION_DIGITS_OPTION = 'maximumFractionDigits';
      NAME_MINIMUM_INTEGER_DIGITS_OPTION = 'minimumIntegerDigits';
      NAME_WEEKDAY_OPTION = 'weekday';
      NAME_YEAR_OPTION = 'year';
      NAME_MONTH_OPTION = 'month';
      NAME_DAY_OPTION = 'day';
      NAME_HOUR_OPTION = 'hour';
      NAME_MINUTE_OPTION = 'minute';
      NAME_SECOND_OPTION = 'second';
      NAME_HOUR12_OPTION = 'hour12';
      NAME_HOUR_CYCLE_OPTION = 'hourCycle';
      NAME_TIME_ZONE_OPTION = 'timeZone';
      NAME_UNIT = 'unit';
      NAME_NARROW_SYMBOL = 'narrowSymbol';
      NAME_NAME = 'name';
      VALUE_OUT_OF_RANGE = '%s value is out of range.';
      CHOICE_OUT_OF_RANGE = 'Value %s out of range for %s options property %s';
      CURRENCY_REQUIRED = 'Currency code is required with currency style.';
      INVALID_CURRENCY = 'Invalid currency code : %s';
      NUMBER_SCOPE = 'Number.prototype.toLocaleString';
      DATE_SCOPE = 'Date.prototype.toLocaleString';

      NAME_NUMERIC = 'numeric';
      NAME_TWO_DIGIT = '2-digit';
      NAME_LONG = 'long';
      NAME_SHORT = 'short';
      NAME_NARROW = 'narrow';
      NAME_DECIMAL = 'decimal';
      NAME_PERCENT = 'percent';
      NAME_CURRENCY = 'currency';
      NAME_CODE = 'code';
      NAME_SYMBOL = 'symbol';
      NAME_HOUR_CYCLE_H11 = 'h11';
      NAME_HOUR_CYCLE_H12 = 'h12';
      NAME_HOUR_CYCLE_H23 = 'h23';
      NAME_HOUR_CYCLE_H24 = 'h24';

      NUMERIC_STYLES: array[0..1] of string = (NAME_NUMERIC, NAME_TWO_DIGIT);
      WEEKDAY_STYLES: array[0..2] of string = (NAME_LONG, NAME_SHORT, NAME_NARROW);
      MONTH_STYLES: array[0..4] of string = (NAME_NUMERIC, NAME_TWO_DIGIT, NAME_LONG, NAME_SHORT, NAME_NARROW);
      NUMBER_STYLES: array[0..3] of string = (NAME_DECIMAL, NAME_PERCENT, NAME_CURRENCY, NAME_UNIT);
      CURRENCY_DISPLAYS: array[0..3] of string = (NAME_CODE, NAME_SYMBOL, NAME_NARROW_SYMBOL, NAME_NAME);
      HOUR_CYCLES: array[0..3] of string = (NAME_HOUR_CYCLE_H11, NAME_HOUR_CYCLE_H12,
                                            NAME_HOUR_CYCLE_H23, NAME_HOUR_CYCLE_H24);
      DATE_FIELD_STYLE_NAMES: array[TJSDateFieldStyle] of string = ('', NAME_NUMERIC, NAME_TWO_DIGIT, NAME_LONG,
                                                                    NAME_SHORT, NAME_NARROW);

    class function TryResolveLocale(const Locales: TJSValue; out Locale: PJSLocaleDefinition): Boolean; static;
    class function TryResolveLocaleList(const Locales: TJSValue; out Locale: PJSLocaleDefinition): Boolean; static;
    class function OptionValue(const Request: TJSLocaleRequest; const Name: string): TJSValue; static;
    class function ChoiceOption(const Request: TJSLocaleRequest; const Name: string; const Choices: array of string;
                                const Scope: string): string; static;
    class function DigitsOption(const Request: TJSLocaleRequest; const Name: string; const Minimum: Integer;
                                const Maximum: Integer): Integer; static;
    class function FieldStyleOption(const Request: TJSLocaleRequest; const Name: string;
                                    const Choices: array of string): TJSDateFieldStyle; static;
    class function StyleFromName(const Name: string): TJSDateFieldStyle; static;
    class function IsAllLetters(const Text: string): Boolean; static;
    class function ReadStyle(const Request: TJSLocaleRequest): TJSNumberStyle; static;
    class function ReadCurrency(const Request: TJSLocaleRequest; const Style: TJSNumberStyle): string; static;
    class function ReadCurrencyDisplay(const Request: TJSLocaleRequest): TJSCurrencyDisplay; static;
    class function ReadGrouping(const Request: TJSLocaleRequest): Boolean; static;
    class function ReadHourCycle(const Request: TJSLocaleRequest): TJSHourCycle; static;
    class function ReadFractionDigits(const Request: TJSLocaleRequest; const Style: TJSNumberStyle;
                                      const Currency: string): TJSFractionDigitRange; static;
  public
    class function TryCreateRequest(const Args: TArray<TJSValue>; out Request: TJSLocaleRequest): Boolean; static;
    class function ReadNumberOptions(const Request: TJSLocaleRequest): TJSNumberFormatOptions; static;
    class function ReadDateOptions(const Request: TJSLocaleRequest): TJSDateFormatOptions; static;
    class function UsesUtcZone(const Request: TJSLocaleRequest): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  JS4D.Errors,
  JS4D.ArrayLike;

class function TJSLocaleArguments.TryResolveLocaleList(const Locales: TJSValue;
                                                       out Locale: PJSLocaleDefinition): Boolean;
begin
  const ListObject = Locales.ToObject;
  const ListLength = Min(TJSArrayLike.ToLength(ListObject), MAX_LOCALE_LIST_LENGTH);

  for var Index := 0 to ListLength - 1 do
  begin
    const Entry = ListObject.GetProperty(TJSArrayLike.IndexName(Index));
    const IsResolved = Entry.IsString and TJSBuiltInLocaleTable.TryFind(Entry.ToString, Locale);
    if IsResolved then
      Exit(True);
  end;

  Result := False;
end;

class function TJSLocaleArguments.TryResolveLocale(const Locales: TJSValue; out Locale: PJSLocaleDefinition): Boolean;
begin
  Result := False;

  if Locales.IsString then
  begin
    const LocaleText = Locales.ToString;

    Result := TJSBuiltInLocaleTable.TryFind(LocaleText, Locale);
  end
  else if Locales.IsObject then
  begin
    Result := TryResolveLocaleList(Locales, Locale);
  end;
end;

class function TJSLocaleArguments.TryCreateRequest(const Args: TArray<TJSValue>;
                                                   out Request: TJSLocaleRequest): Boolean;
begin
  Request.Options := TJSArrayLike.Argument(Args, OPTIONS_INDEX);

  const HasOptions = Request.Options.IsObject;
  const LocalesArgument = TJSArrayLike.Argument(Args, LOCALES_INDEX);
  const IsLocaleResolved = TryResolveLocale(LocalesArgument, Request.Locale);
  if not IsLocaleResolved then
    Request.Locale := TJSBuiltInLocaleTable.FindDefault;

  Result := IsLocaleResolved or HasOptions;
end;

class function TJSLocaleArguments.OptionValue(const Request: TJSLocaleRequest; const Name: string): TJSValue;
begin
  const HasOptions = Request.Options.IsObject;
  if not HasOptions then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const OptionsObject = Request.Options.ToObject;

  Result := OptionsObject.GetProperty(Name);
end;

class function TJSLocaleArguments.ChoiceOption(const Request: TJSLocaleRequest; const Name: string;
                                               const Choices: array of string; const Scope: string): string;
begin
  const Value = OptionValue(Request, Name);
  const IsSpecified = (not Value.IsUndefined);
  if not IsSpecified then
    Exit('');

  Result := Value.ToString;
  for var Choice in Choices do
  begin
    const IsChoice = (Choice = Result);
    if IsChoice then
      Exit;
  end;

  const Message = Format(CHOICE_OUT_OF_RANGE, [Result, Scope, Name]);

  raise TJSErrorFactory.RangeError(Message);
end;

class function TJSLocaleArguments.DigitsOption(const Request: TJSLocaleRequest; const Name: string;
                                               const Minimum: Integer; const Maximum: Integer): Integer;
begin
  const Value = OptionValue(Request, Name);
  const IsSpecified = (not Value.IsUndefined);
  if not IsSpecified then
    Exit(UNSPECIFIED_DIGITS);

  const Number = Value.ToNumber;
  const IsInRange = (not IsNaN(Number)) and (Number >= Minimum) and (Number <= Maximum);
  if not IsInRange then
  begin
    const Message = Format(VALUE_OUT_OF_RANGE, [Name]);

    raise TJSErrorFactory.RangeError(Message);
  end;

  Result := Floor(Number);
end;

class function TJSLocaleArguments.IsAllLetters(const Text: string): Boolean;
begin
  for var Letter in Text do
  begin
    if not Letter.IsLetter then
      Exit(False);
  end;

  Result := True;
end;

class function TJSLocaleArguments.ReadStyle(const Request: TJSLocaleRequest): TJSNumberStyle;
begin
  const StyleName = ChoiceOption(Request, NAME_STYLE_OPTION, NUMBER_STYLES, NUMBER_SCOPE);

  const IsPercent = (StyleName = NAME_PERCENT);
  if IsPercent then
    Exit(TJSNumberStyle.Percent);

  const IsCurrency = (StyleName = NAME_CURRENCY);
  if IsCurrency then
    Exit(TJSNumberStyle.Currency);

  Result := TJSNumberStyle.Decimal;
end;

class function TJSLocaleArguments.ReadCurrency(const Request: TJSLocaleRequest; const Style: TJSNumberStyle): string;
begin
  const Value = OptionValue(Request, NAME_CURRENCY);
  const IsSpecified = (not Value.IsUndefined);
  if not IsSpecified then
  begin
    const IsCurrencyStyle = (Style = TJSNumberStyle.Currency);
    if IsCurrencyStyle then
      raise TJSErrorFactory.TypeError(CURRENCY_REQUIRED);

    Exit('');
  end;

  const CodeText = Value.ToString;
  Result := CodeText.ToUpper;

  const IsWellFormed = (Length(Result) = CURRENCY_CODE_LENGTH) and IsAllLetters(Result);
  if not IsWellFormed then
  begin
    const Message = Format(INVALID_CURRENCY, [CodeText]);

    raise TJSErrorFactory.RangeError(Message);
  end;
end;

class function TJSLocaleArguments.ReadCurrencyDisplay(const Request: TJSLocaleRequest): TJSCurrencyDisplay;
begin
  const DisplayName = ChoiceOption(Request, NAME_CURRENCY_DISPLAY_OPTION, CURRENCY_DISPLAYS, NUMBER_SCOPE);

  const IsCode = (DisplayName = NAME_CODE);
  if IsCode then
    Exit(TJSCurrencyDisplay.Code);

  Result := TJSCurrencyDisplay.Symbol;
end;

class function TJSLocaleArguments.ReadGrouping(const Request: TJSLocaleRequest): Boolean;
begin
  const Value = OptionValue(Request, NAME_USE_GROUPING_OPTION);

  Result := Value.IsUndefined or Value.ToBoolean;
end;

class function TJSLocaleArguments.ReadFractionDigits(const Request: TJSLocaleRequest;
                                                     const Style: TJSNumberStyle;
                                                     const Currency: string): TJSFractionDigitRange;
begin
  const Defaults = TJSLocaleNumberFormatter.DefaultFractionDigits(Style, Currency);
  const RequestedMinimum = DigitsOption(Request, NAME_MINIMUM_FRACTION_DIGITS_OPTION, 0, MAX_FRACTION_DIGITS);
  const RequestedMaximum = DigitsOption(Request, NAME_MAXIMUM_FRACTION_DIGITS_OPTION, 0, MAX_FRACTION_DIGITS);

  const HasMinimum = (RequestedMinimum <> UNSPECIFIED_DIGITS);
  const HasMaximum = (RequestedMaximum <> UNSPECIFIED_DIGITS);

  const IsRangeInverted = (HasMinimum and HasMaximum and (RequestedMinimum > RequestedMaximum));
  if IsRangeInverted then
  begin
    const Message = Format(VALUE_OUT_OF_RANGE, [NAME_MAXIMUM_FRACTION_DIGITS_OPTION]);
    raise TJSErrorFactory.RangeError(Message);
  end;

  Result.Minimum := IfThen(HasMinimum, RequestedMinimum, IfThen(HasMaximum, Min(Defaults.Minimum, RequestedMaximum),
                                                                Defaults.Minimum));
  Result.Maximum := IfThen(HasMaximum, RequestedMaximum, IfThen(HasMinimum, Max(Defaults.Maximum, RequestedMinimum),
                                                                Defaults.Maximum));
end;

class function TJSLocaleArguments.ReadNumberOptions(const Request: TJSLocaleRequest): TJSNumberFormatOptions;
begin
  Result.Style := ReadStyle(Request);
  Result.Currency := ReadCurrency(Request, Result.Style);
  Result.CurrencyDisplay := ReadCurrencyDisplay(Request);
  Result.UseGrouping := ReadGrouping(Request);

  const RequestedIntegerDigits = DigitsOption(Request, NAME_MINIMUM_INTEGER_DIGITS_OPTION, MIN_INTEGER_DIGITS,
                                              MAX_INTEGER_DIGITS);
  const IsIntegerDigitsUnspecified = (RequestedIntegerDigits = UNSPECIFIED_DIGITS);
  Result.MinimumIntegerDigits := IfThen(IsIntegerDigitsUnspecified, MIN_INTEGER_DIGITS, RequestedIntegerDigits);

  const FractionDigits = ReadFractionDigits(Request, Result.Style, Result.Currency);
  Result.MinimumFractionDigits := FractionDigits.Minimum;
  Result.MaximumFractionDigits := FractionDigits.Maximum;
end;

class function TJSLocaleArguments.StyleFromName(const Name: string): TJSDateFieldStyle;
begin
  for var Style := TJSDateFieldStyle.Numeric to High(TJSDateFieldStyle) do
  begin
    const IsNamed = (DATE_FIELD_STYLE_NAMES[Style] = Name);
    if IsNamed then
      Exit(Style);
  end;

  Result := TJSDateFieldStyle.None;
end;

class function TJSLocaleArguments.FieldStyleOption(const Request: TJSLocaleRequest; const Name: string;
                                                   const Choices: array of string): TJSDateFieldStyle;
begin
  const StyleName = ChoiceOption(Request, Name, Choices, DATE_SCOPE);

  Result := StyleFromName(StyleName);
end;

class function TJSLocaleArguments.ReadHourCycle(const Request: TJSLocaleRequest): TJSHourCycle;
begin
  const HourFormatOption = OptionValue(Request, NAME_HOUR12_OPTION);
  const IsHourFormatGiven = (not HourFormatOption.IsUndefined);
  if IsHourFormatGiven then
  begin
    const IsTwelveHour = HourFormatOption.ToBoolean;
    if IsTwelveHour then
      Exit(TJSHourCycle.Twelve);

    Exit(TJSHourCycle.TwentyFour);
  end;

  const CycleName = ChoiceOption(Request, NAME_HOUR_CYCLE_OPTION, HOUR_CYCLES, DATE_SCOPE);
  const IsTwelveHourCycle = ((CycleName = NAME_HOUR_CYCLE_H11) or (CycleName = NAME_HOUR_CYCLE_H12));
  if IsTwelveHourCycle then
    Exit(TJSHourCycle.Twelve);

  const IsTwentyFourHourCycle = ((CycleName = NAME_HOUR_CYCLE_H23) or (CycleName = NAME_HOUR_CYCLE_H24));
  if IsTwentyFourHourCycle then
    Exit(TJSHourCycle.TwentyFour);

  Result := TJSHourCycle.LocaleDefault;
end;

class function TJSLocaleArguments.ReadDateOptions(const Request: TJSLocaleRequest): TJSDateFormatOptions;
begin
  Result.Weekday := FieldStyleOption(Request, NAME_WEEKDAY_OPTION, WEEKDAY_STYLES);
  Result.Year := FieldStyleOption(Request, NAME_YEAR_OPTION, NUMERIC_STYLES);
  Result.Month := FieldStyleOption(Request, NAME_MONTH_OPTION, MONTH_STYLES);
  Result.Day := FieldStyleOption(Request, NAME_DAY_OPTION, NUMERIC_STYLES);
  Result.Hour := FieldStyleOption(Request, NAME_HOUR_OPTION, NUMERIC_STYLES);
  Result.Minute := FieldStyleOption(Request, NAME_MINUTE_OPTION, NUMERIC_STYLES);
  Result.Second := FieldStyleOption(Request, NAME_SECOND_OPTION, NUMERIC_STYLES);
  Result.HourCycle := ReadHourCycle(Request);
end;

class function TJSLocaleArguments.UsesUtcZone(const Request: TJSLocaleRequest): Boolean;
begin
  const Zone = OptionValue(Request, NAME_TIME_ZONE_OPTION);
  const IsZoneGiven = (not Zone.IsUndefined);
  if not IsZoneGiven then
    Exit(False);

  const ZoneName = Zone.ToString;
  const Marker = ZONE_BOUNDARY + ZoneName.ToUpper + ZONE_BOUNDARY;

  Result := UTC_ZONE_NAMES.Contains(Marker);
end;

end.
