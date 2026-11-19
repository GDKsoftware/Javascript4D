unit JS4D.BuiltInLocales;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TJSCurrencyLayout = (SymbolBeforeNumber, SymbolBeforeNumberWithSpace, SymbolAfterNumberWithSpace);

  TJSPatternMap = TDictionary<string, string>;
  TJSMonthNames = array[0..11] of string;
  TJSWeekdayNames = array[0..6] of string;

  TJSLocaleDefinition = record
    Tag: string;
    DecimalSeparator: string;
    GroupSeparator: string;
    MinimumGroupingDigits: Integer;
    MinusSign: string;
    CurrencyLayout: TJSCurrencyLayout;
    PercentGap: string;
    CurrencySymbols: string;
    Hour12ByDefault: Boolean;
    AmMarker: string;
    PmMarker: string;
    MonthsLong: TJSMonthNames;
    MonthsShort: TJSMonthNames;
    MonthsShortStandalone: TJSMonthNames;
    MonthsNarrow: string;
    WeekdaysLong: TJSWeekdayNames;
    WeekdaysShort: TJSWeekdayNames;
    WeekdaysShortStandalone: TJSWeekdayNames;
    WeekdaysNarrow: string;
    DatePatterns: string;
    TimePatterns12: string;
    TimePatterns24: string;
    DateTimeGlueNumeric: string;
    DateTimeGlueShort: string;
    DateTimeGlueLong: string;
    CurrencySymbolMap: TJSPatternMap;
    DatePatternMap: TJSPatternMap;
    TimePatterns12Map: TJSPatternMap;
    TimePatterns24Map: TJSPatternMap;
  end;

  PJSLocaleDefinition = ^TJSLocaleDefinition;

  EJSLocaleTableError = class(Exception);

  TJSBuiltInLocaleTable = class
  private
    type
      TLanguageDefault = record
        Language: string;
        DefaultTag: string;
      end;

    const
      EXTENSION_MARKER = '-u-';
      TAG_SEPARATOR = '-';
      DEFAULT_TAG = 'en-US';
      ENTRY_SEPARATOR = '|';
      KEY_VALUE_SEPARATOR = '=';
      DEFAULT_CURRENCY_DIGITS = 2;
      THREE_CURRENCY_DIGITS = 3;
      MISSING_DEFAULT_LOCALE = 'Default locale %s is missing';
      LANGUAGE_DEFAULTS: array[0..5] of TLanguageDefault = (
        (Language: 'en'; DefaultTag: 'en-US'),
        (Language: 'nl'; DefaultTag: 'nl-NL'),
        (Language: 'de'; DefaultTag: 'de-DE'),
        (Language: 'fr'; DefaultTag: 'fr-FR'),
        (Language: 'es'; DefaultTag: 'es-ES'),
        (Language: 'it'; DefaultTag: 'it-IT'));
      ZERO_DIGIT_CURRENCIES: array[0..10] of string = (
        'JPY', 'KRW', 'VND', 'CLP', 'ISK', 'UGX', 'XAF', 'XOF', 'XPF', 'PYG', 'RWF');
      THREE_DIGIT_CURRENCIES: array[0..6] of string = (
        'BHD', 'KWD', 'OMR', 'JOD', 'TND', 'IQD', 'LYD');

    class var
      FDefinitions: TArray<TJSLocaleDefinition>;
      FPatternMaps: TObjectList<TJSPatternMap>;

    class constructor Create;
    class destructor Destroy;

    class function ParseEntries(const Entries: string): TJSPatternMap; static;
    class function StripExtensions(const Requested: string): string; static;
    class function ExpandLanguage(const Requested: string): string; static;
    class function TryFindExact(const Tag: string; out Locale: PJSLocaleDefinition): Boolean; static;

  public
    class function TryFind(const Requested: string; out Locale: PJSLocaleDefinition): Boolean; static;
    class function FindDefault: PJSLocaleDefinition; static;
    class function FindCurrencySymbol(const Locale: PJSLocaleDefinition; const Currency: string): string; static;
    class function CurrencyDigits(const Currency: string): Integer; static;
  end;

implementation

uses
  System.StrUtils,
  JS4D.BuiltInLocaleData;

{ TJSBuiltInLocaleTable }

class constructor TJSBuiltInLocaleTable.Create;
begin
  FPatternMaps := TObjectList<TJSPatternMap>.Create(True);
  FDefinitions := TJSBuiltInLocaleData.Definitions;

  for var Index := 0 to High(FDefinitions) do
  begin
    FDefinitions[Index].CurrencySymbolMap := ParseEntries(FDefinitions[Index].CurrencySymbols);
    FDefinitions[Index].DatePatternMap := ParseEntries(FDefinitions[Index].DatePatterns);
    FDefinitions[Index].TimePatterns12Map := ParseEntries(FDefinitions[Index].TimePatterns12);
    FDefinitions[Index].TimePatterns24Map := ParseEntries(FDefinitions[Index].TimePatterns24);
  end;
end;

class destructor TJSBuiltInLocaleTable.Destroy;
begin
  FPatternMaps.Free;
end;

class function TJSBuiltInLocaleTable.ParseEntries(const Entries: string): TJSPatternMap;
begin
  Result := TJSPatternMap.Create;
  FPatternMaps.Add(Result);

  for var Entry in Entries.Split([ENTRY_SEPARATOR]) do
  begin
    const AssignPosition = Entry.IndexOf(KEY_VALUE_SEPARATOR);
    const IsEntry = (AssignPosition >= 0);
    if not IsEntry then
      Continue;

    const Key = Entry.Substring(0, AssignPosition);
    const IsFirstOccurrence = not Result.ContainsKey(Key);
    if IsFirstOccurrence then
      Result.Add(Key, Entry.Substring(AssignPosition + 1));
  end;
end;

class function TJSBuiltInLocaleTable.StripExtensions(const Requested: string): string;
begin
  const ExtensionStart = Requested.IndexOf(EXTENSION_MARKER);
  const HasExtension = (ExtensionStart >= 0);
  if not HasExtension then
    Exit(Requested);

  Result := Requested.Substring(0, ExtensionStart);
end;

class function TJSBuiltInLocaleTable.ExpandLanguage(const Requested: string): string;
begin
  Result := Requested;

  const IsLanguageOnly = (Requested.IndexOf(TAG_SEPARATOR) < 0);
  if not IsLanguageOnly then
    Exit;

  for var Candidate in LANGUAGE_DEFAULTS do
  begin
    const IsRequestedLanguage = SameText(Requested, Candidate.Language);
    if IsRequestedLanguage then
      Exit(Candidate.DefaultTag);
  end;
end;

class function TJSBuiltInLocaleTable.TryFindExact(const Tag: string; out Locale: PJSLocaleDefinition): Boolean;
begin
  Locale := nil;

  for var Index := 0 to High(FDefinitions) do
  begin
    const IsRequestedTag = SameText(Tag, FDefinitions[Index].Tag);
    if IsRequestedTag then
    begin
      Locale := @FDefinitions[Index];
      Exit(True);
    end;
  end;

  Result := False;
end;

class function TJSBuiltInLocaleTable.TryFind(const Requested: string; out Locale: PJSLocaleDefinition): Boolean;
begin
  const WithoutExtensions = StripExtensions(Requested);
  const Tag = ExpandLanguage(WithoutExtensions);

  Result := TryFindExact(Tag, Locale);
end;

class function TJSBuiltInLocaleTable.FindDefault: PJSLocaleDefinition;
begin
  const IsFound = TryFindExact(DEFAULT_TAG, Result);
  if not IsFound then
    raise EJSLocaleTableError.CreateFmt(MISSING_DEFAULT_LOCALE, [DEFAULT_TAG]);
end;

class function TJSBuiltInLocaleTable.FindCurrencySymbol(const Locale: PJSLocaleDefinition;
                                                        const Currency: string): string;
begin
  const IsFound = Locale.CurrencySymbolMap.TryGetValue(Currency, Result);
  if not IsFound then
    Result := Currency;
end;

class function TJSBuiltInLocaleTable.CurrencyDigits(const Currency: string): Integer;
begin
  const HasNoMinorUnits = MatchStr(Currency, ZERO_DIGIT_CURRENCIES);
  if HasNoMinorUnits then
    Exit(0);

  const HasThreeMinorUnits = MatchStr(Currency, THREE_DIGIT_CURRENCIES);
  if HasThreeMinorUnits then
    Exit(THREE_CURRENCY_DIGITS);

  Result := DEFAULT_CURRENCY_DIGITS;
end;

end.
