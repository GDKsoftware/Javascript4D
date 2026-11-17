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
    Locale: TJSLocaleDefinition;
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
      PROPERTY_LENGTH = 'length';
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
      NAME_CYCLE_11 = 'h11';
      NAME_CYCLE_12 = 'h12';
      NAME_CYCLE_23 = 'h23';
      NAME_CYCLE_24 = 'h24';

      NUMERIC_STYLES: array[0..1] of string = (NAME_NUMERIC, NAME_TWO_DIGIT);
      WEEKDAY_STYLES: array[0..2] of string = (NAME_LONG, NAME_SHORT, NAME_NARROW);
      MONTH_STYLES: array[0..4] of string = (NAME_NUMERIC, NAME_TWO_DIGIT, NAME_LONG, NAME_SHORT, NAME_NARROW);
      NUMBER_STYLES: array[0..3] of string = (NAME_DECIMAL, NAME_PERCENT, NAME_CURRENCY, 'unit');
      CURRENCY_DISPLAYS: array[0..3] of string = (NAME_CODE, NAME_SYMBOL, 'narrowSymbol', 'name');
      HOUR_CYCLES: array[0..3] of string = (NAME_CYCLE_11, NAME_CYCLE_12, NAME_CYCLE_23, NAME_CYCLE_24);

    class function ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue; static;
    class function TryResolveLocale(const Locales: TJSValue; out Locale: TJSLocaleDefinition): Boolean; static;
    class function TryResolveLocaleList(const Locales: TJSValue; out Locale: TJSLocaleDefinition): Boolean; static;
    class function OptionValue(const Request: TJSLocaleRequest; const Name: string): TJSValue; static;
    class function ChoiceOption(const Request: TJSLocaleRequest; const Name: string; const Choices: array of string;
                                const Scope: string): string; static;
    class function DigitsOption(const Request: TJSLocaleRequest; const Name: string; const Minimum: Integer;
                                const Maximum: Integer): Integer; static;
    class function FieldStyleOption(const Request: TJSLocaleRequest; const Name: string;
                                    const Choices: array of string): TJSDateFieldStyle; static;
    class function StyleFromName(const Name: string): TJSDateFieldStyle; static;
    class function ReadStyle(const Request: TJSLocaleRequest): TJSNumberStyle; static;
    class function ReadCurrency(const Request: TJSLocaleRequest; const Style: TJSNumberStyle): string; static;
    class function ReadCurrencyDisplay(const Request: TJSLocaleRequest): TJSCurrencyDisplay; static;
    class function ReadGrouping(const Request: TJSLocaleRequest): Boolean; static;
    class function ReadHourCycle(const Request: TJSLocaleRequest): TJSHourCycle; static;
    class procedure ApplyFractionDigits(const Request: TJSLocaleRequest; var Options: TJSNumberFormatOptions); static;
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
  JS4D.Errors;

class function TJSLocaleArguments.ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
begin
  const IsPresent = (Index < Length(Args));
  if IsPresent then
    Exit(Args[Index]);

  Result := TJSValue.CreateUndefined;
end;

class function TJSLocaleArguments.TryResolveLocaleList(const Locales: TJSValue;
                                                       out Locale: TJSLocaleDefinition): Boolean;
begin
  const ListObject = Locales.ToObject;
  const LengthValue = ListObject.GetProperty(PROPERTY_LENGTH);
  const ListLength = Trunc(LengthValue.ToNumber);

  for var Index := 0 to ListLength - 1 do
  begin
    const Entry = ListObject.GetProperty(IntToStr(Index));
    const EntryText = Entry.ToString;
    const IsResolved = Entry.IsString and TJSBuiltInLocaleTable.TryFind(EntryText, Locale);
    if IsResolved then
      Exit(True);
  end;

  Result := False;
end;

class function TJSLocaleArguments.TryResolveLocale(const Locales: TJSValue; out Locale: TJSLocaleDefinition): Boolean;
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

class function TJSLocaleArguments.TryCreateRequest(const Args: TArray<TJSValue>; out Request: TJSLocaleRequest): Boolean;
begin
  Request.Options := ArgumentAt(Args, OPTIONS_INDEX);

  const HasOptions = Request.Options.IsObject;
  const IsLocaleResolved = TryResolveLocale(ArgumentAt(Args, LOCALES_INDEX), Request.Locale);
  if not IsLocaleResolved then
    Request.Locale := TJSBuiltInLocaleTable.FindDefault;

  Result := IsLocaleResolved or HasOptions;
end;

class function TJSLocaleArguments.OptionValue(const Request: TJSLocaleRequest; const Name: string): TJSValue;
begin
  const HasOptions = Request.Options.IsObject;
  if not HasOptions then
    Exit(TJSValue.CreateUndefined);

  const OptionsObject = Request.Options.ToObject;

  Result := OptionsObject.GetProperty(Name);
end;

class function TJSLocaleArguments.ChoiceOption(const Request: TJSLocaleRequest; const Name: string;
                                               const Choices: array of string; const Scope: string): string;
begin
  const Value = OptionValue(Request, Name);
  if Value.IsUndefined then
    Exit('');

  Result := Value.ToString;
  for var Choice in Choices do
  begin
    if Choice = Result then
      Exit;
  end;

  const Message = Format('Value %s out of range for %s options property %s', [Result, Scope, Name]);

  raise TJSErrorFactory.RangeError(Message);
end;

class function TJSLocaleArguments.DigitsOption(const Request: TJSLocaleRequest; const Name: string;
                                               const Minimum: Integer; const Maximum: Integer): Integer;
begin
  const Value = OptionValue(Request, Name);
  if Value.IsUndefined then
    Exit(UNSPECIFIED_DIGITS);

  const Number = Value.ToNumber;
  const IsInRange = (not IsNaN(Number)) and (Number >= Minimum) and (Number <= Maximum);
  if not IsInRange then
  begin
    const Message = Format('%s value is out of range.', [Name]);

    raise TJSErrorFactory.RangeError(Message);
  end;

  Result := Floor(Number);
end;

class function TJSLocaleArguments.ReadStyle(const Request: TJSLocaleRequest): TJSNumberStyle;
begin
  const StyleName = ChoiceOption(Request, 'style', NUMBER_STYLES, NUMBER_SCOPE);

  if StyleName = NAME_PERCENT then
    Exit(TJSNumberStyle.Percent);

  if StyleName = NAME_CURRENCY then
    Exit(TJSNumberStyle.Currency);

  Result := TJSNumberStyle.Decimal;
end;

class function TJSLocaleArguments.ReadCurrency(const Request: TJSLocaleRequest; const Style: TJSNumberStyle): string;
begin
  const Value = OptionValue(Request, NAME_CURRENCY);
  if Value.IsUndefined then
  begin
    if Style = TJSNumberStyle.Currency then
      raise TJSErrorFactory.TypeError('Currency code is required with currency style.');

    Exit('');
  end;

  const CodeText = Value.ToString;
  Result := CodeText.ToUpper;

  var IsWellFormed := (Length(Result) = CURRENCY_CODE_LENGTH);
  for var Letter in Result do
  begin
    IsWellFormed := IsWellFormed and Letter.IsLetter;
  end;

  if not IsWellFormed then
  begin
    const Message = Format('Invalid currency code : %s', [CodeText]);

    raise TJSErrorFactory.RangeError(Message);
  end;
end;

class function TJSLocaleArguments.ReadCurrencyDisplay(const Request: TJSLocaleRequest): TJSCurrencyDisplay;
begin
  const DisplayName = ChoiceOption(Request, 'currencyDisplay', CURRENCY_DISPLAYS, NUMBER_SCOPE);

  if DisplayName = NAME_CODE then
    Exit(TJSCurrencyDisplay.Code);

  Result := TJSCurrencyDisplay.Symbol;
end;

class function TJSLocaleArguments.ReadGrouping(const Request: TJSLocaleRequest): Boolean;
begin
  const Value = OptionValue(Request, 'useGrouping');

  Result := Value.IsUndefined or Value.ToBoolean;
end;

class procedure TJSLocaleArguments.ApplyFractionDigits(const Request: TJSLocaleRequest;
                                                       var Options: TJSNumberFormatOptions);
begin
  const Defaults = TJSLocaleNumberFormatter.DefaultFractionDigits(Options.Style, Options.Currency);
  const RequestedMinimum = DigitsOption(Request, 'minimumFractionDigits', 0, MAX_FRACTION_DIGITS);
  const RequestedMaximum = DigitsOption(Request, 'maximumFractionDigits', 0, MAX_FRACTION_DIGITS);

  const HasMinimum = (RequestedMinimum <> UNSPECIFIED_DIGITS);
  const HasMaximum = (RequestedMaximum <> UNSPECIFIED_DIGITS);

  Options.MinimumFractionDigits := Defaults.Minimum;
  Options.MaximumFractionDigits := Defaults.Maximum;

  if HasMinimum then
  begin
    Options.MinimumFractionDigits := RequestedMinimum;
    Options.MaximumFractionDigits := Max(Defaults.Maximum, RequestedMinimum);
  end;

  if HasMaximum then
  begin
    Options.MaximumFractionDigits := RequestedMaximum;
    Options.MinimumFractionDigits := Min(Defaults.Minimum, RequestedMaximum);
  end;

  if HasMinimum and HasMaximum then
  begin
    Options.MinimumFractionDigits := RequestedMinimum;

    const IsRangeInverted = (RequestedMinimum > RequestedMaximum);
    if IsRangeInverted then
      raise TJSErrorFactory.RangeError('maximumFractionDigits value is out of range.');
  end;
end;

class function TJSLocaleArguments.ReadNumberOptions(const Request: TJSLocaleRequest): TJSNumberFormatOptions;
begin
  Result.Style := ReadStyle(Request);
  Result.Currency := ReadCurrency(Request, Result.Style);
  Result.CurrencyDisplay := ReadCurrencyDisplay(Request);
  Result.UseGrouping := ReadGrouping(Request);

  const RequestedIntegerDigits = DigitsOption(Request, 'minimumIntegerDigits', MIN_INTEGER_DIGITS, MAX_INTEGER_DIGITS);
  Result.MinimumIntegerDigits := IfThen(RequestedIntegerDigits = UNSPECIFIED_DIGITS, MIN_INTEGER_DIGITS, RequestedIntegerDigits);

  ApplyFractionDigits(Request, Result);
end;

class function TJSLocaleArguments.StyleFromName(const Name: string): TJSDateFieldStyle;
begin
  if Name = NAME_NUMERIC then
    Exit(TJSDateFieldStyle.Numeric);

  if Name = NAME_TWO_DIGIT then
    Exit(TJSDateFieldStyle.TwoDigit);

  if Name = NAME_LONG then
    Exit(TJSDateFieldStyle.Long);

  if Name = NAME_SHORT then
    Exit(TJSDateFieldStyle.Short);

  if Name = NAME_NARROW then
    Exit(TJSDateFieldStyle.Narrow);

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
  const Hour12 = OptionValue(Request, 'hour12');
  if not Hour12.IsUndefined then
  begin
    if Hour12.ToBoolean then
      Exit(TJSHourCycle.Twelve);

    Exit(TJSHourCycle.TwentyFour);
  end;

  const CycleName = ChoiceOption(Request, 'hourCycle', HOUR_CYCLES, DATE_SCOPE);
  if (CycleName = NAME_CYCLE_11) or (CycleName = NAME_CYCLE_12) then
    Exit(TJSHourCycle.Twelve);

  if (CycleName = NAME_CYCLE_23) or (CycleName = NAME_CYCLE_24) then
    Exit(TJSHourCycle.TwentyFour);

  Result := TJSHourCycle.LocaleDefault;
end;

class function TJSLocaleArguments.ReadDateOptions(const Request: TJSLocaleRequest): TJSDateFormatOptions;
begin
  Result.Weekday := FieldStyleOption(Request, 'weekday', WEEKDAY_STYLES);
  Result.Year := FieldStyleOption(Request, 'year', NUMERIC_STYLES);
  Result.Month := FieldStyleOption(Request, 'month', MONTH_STYLES);
  Result.Day := FieldStyleOption(Request, 'day', NUMERIC_STYLES);
  Result.Hour := FieldStyleOption(Request, 'hour', NUMERIC_STYLES);
  Result.Minute := FieldStyleOption(Request, 'minute', NUMERIC_STYLES);
  Result.Second := FieldStyleOption(Request, 'second', NUMERIC_STYLES);
  Result.HourCycle := ReadHourCycle(Request);
end;

class function TJSLocaleArguments.UsesUtcZone(const Request: TJSLocaleRequest): Boolean;
begin
  const Zone = OptionValue(Request, 'timeZone');
  if Zone.IsUndefined then
    Exit(False);

  const ZoneName = Zone.ToString;
  const Marker = ZONE_BOUNDARY + ZoneName.ToUpper + ZONE_BOUNDARY;

  Result := UTC_ZONE_NAMES.Contains(Marker);
end;

end.
