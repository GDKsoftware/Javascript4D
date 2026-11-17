unit JS4D.LocaleDateFormat;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.BuiltInLocales;

type
  TJSDateFieldStyle = (None, Numeric, TwoDigit, Long, Short, Narrow);
  TJSHourCycle = (LocaleDefault, Twelve, TwentyFour);
  TJSDateFormatScope = (DateOnly, TimeOnly, DateAndTime);

  TJSDateFormatOptions = record
    Weekday: TJSDateFieldStyle;
    Year: TJSDateFieldStyle;
    Month: TJSDateFieldStyle;
    Day: TJSDateFieldStyle;
    Hour: TJSDateFieldStyle;
    Minute: TJSDateFieldStyle;
    Second: TJSDateFieldStyle;
    HourCycle: TJSHourCycle;
  end;

  TJSLocaleDateFormatter = class
  private
    type
      TDateParts = record
        Year: Integer;
        Month: Integer;
        Day: Integer;
        Weekday: Integer;
        Hour: Integer;
        Minute: Integer;
        Second: Integer;
      end;

      TPatternSegment = record
        Text: string;
        ConsumedChars: Integer;
      end;

    const
      NARROW_NO_BREAK_SPACE = #$202F;
      ORDINARY_SPACE = ' ';
      WEEKDAY_TOKEN = 'E';
      STANDALONE_WEEKDAY_TOKEN = 'c';
      STANDALONE_MONTH_TOKEN = 'L';
      YEAR_TOKEN = 'y';
      DAY_TOKEN = 'd';
      MONTH_TOKEN = 'M';
      TWELVE_HOUR_TOKEN = 'h';
      TWENTY_FOUR_HOUR_TOKEN = 'H';
      MINUTE_TOKEN = 'm';
      SECOND_TOKEN = 's';
      DAY_PERIOD_TOKEN = 'a';
      UNSUPPORTED_PATTERN_LETTER = 'Unsupported pattern letter: %s';
      UNSUPPORTED_WEEKDAY_STYLE = 'Unsupported weekday style: %d';
      UNSUPPORTED_MONTH_STYLE = 'Unsupported month style: %d';
      LITERAL_START = '[';
      LITERAL_END = ']';
      TWO_DIGIT_YEAR_DIVISOR = 100;
      TWO_DIGIT_YEAR_WIDTH = 2;
      HOURS_PER_HALF_DAY = 12;
      MIN_NAME_TOKEN_LENGTH = 3;
      LONG_WEEKDAY_KEY = 'EEEE';
      ABBREVIATED_WEEKDAY_KEY = WEEKDAY_TOKEN;
      YEAR_KEY = YEAR_TOKEN;
      NUMERIC_MONTH_KEY = MONTH_TOKEN;
      TWO_DIGIT_MONTH_KEY = 'MM';
      ABBREVIATED_MONTH_KEY = 'MMM';
      LONG_MONTH_KEY = 'MMMM';
      NUMERIC_DAY_KEY = DAY_TOKEN;
      TWO_DIGIT_DAY_KEY = 'dd';
      NUMERIC_HOUR_KEY = TWELVE_HOUR_TOKEN;
      TWO_DIGIT_HOUR_KEY = 'hh';
      NUMERIC_MINUTE_KEY = MINUTE_TOKEN;
      TWO_DIGIT_MINUTE_KEY = 'mm';
      NUMERIC_SECOND_KEY = SECOND_TOKEN;
      TWO_DIGIT_SECOND_KEY = 'ss';

    class function HasDateFields(const Options: TJSDateFormatOptions): Boolean; static;
    class function HasTimeFields(const Options: TJSDateFormatOptions): Boolean; static;
    class function IncludesDate(const Scope: TJSDateFormatScope): Boolean; static;
    class function IncludesTime(const Scope: TJSDateFormatScope): Boolean; static;
    class function NeedsDefaults(const Options: TJSDateFormatOptions;
                                 const Scope: TJSDateFormatScope): Boolean; static;
    class function IsTwelveHour(const Locale: PJSLocaleDefinition;
                                const Options: TJSDateFormatOptions): Boolean; static;
    class function PartsOf(const Moment: Double): TDateParts; static;
    class function WeekdayKey(const Style: TJSDateFieldStyle): string; static;
    class function MonthKey(const Style: TJSDateFieldStyle): string; static;
    class function NumericOrTwoDigitKey(const Style: TJSDateFieldStyle; const NumericKey: string;
                                        const TwoDigitKey: string): string; static;
    class function DatePatternKey(const Options: TJSDateFormatOptions): string; static;
    class function TimePatternKey(const Options: TJSDateFormatOptions): string; static;
    class function NumberText(const Value: Integer; const Width: Integer): string; static;
    class function StyleText(const Style: TJSDateFieldStyle; const LongName: string; const ShortName: string;
                             const NarrowNames: string; const Index: Integer;
                             const UnsupportedFormat: string): string; static;
    class function WeekdayText(const Locale: PJSLocaleDefinition; const Weekday: Integer;
                               const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string; static;
    class function MonthText(const Locale: PJSLocaleDefinition; const Month: Integer;
                             const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string; static;
    class function YearText(const Year: Integer; const Style: TJSDateFieldStyle): string; static;
    class function HourText(const Hour: Integer; const IsTwelveHour: Boolean; const Width: Integer): string; static;
    class function DayPeriodText(const Locale: PJSLocaleDefinition; const Hour: Integer): string; static;
    class function RenderToken(const Token: Char; const Width: Integer; const Parts: TDateParts;
                               const Locale: PJSLocaleDefinition; const Options: TJSDateFormatOptions): string; static;
    class function LiteralSegmentAt(const Pattern: string; const Position: Integer): TPatternSegment; static;
    class function TokenSegmentAt(const Pattern: string; const Position: Integer; const Parts: TDateParts;
                                  const Locale: PJSLocaleDefinition;
                                  const Options: TJSDateFormatOptions): TPatternSegment; static;
    class function SegmentAt(const Pattern: string; const Position: Integer; const Parts: TDateParts;
                             const Locale: PJSLocaleDefinition;
                             const Options: TJSDateFormatOptions): TPatternSegment; static;
    class function RenderPattern(const Pattern: string; const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                 const Options: TJSDateFormatOptions): string; static;
    class function PatternText(const Patterns: TJSPatternMap; const Key: string; const Parts: TDateParts;
                               const Locale: PJSLocaleDefinition;
                               const Options: TJSDateFormatOptions): string; static;
    class function DateText(const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                            const Options: TJSDateFormatOptions): string; static;
    class function TimeText(const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                            const Options: TJSDateFormatOptions): string; static;
    class function DateTimeGlue(const Locale: PJSLocaleDefinition; const Options: TJSDateFormatOptions): string; static;
  public
    class function WithDefaults(const Options: TJSDateFormatOptions;
                                const Scope: TJSDateFormatScope): TJSDateFormatOptions; static;
    class function FormatMoment(const Moment: Double; const Locale: PJSLocaleDefinition;
                                const Options: TJSDateFormatOptions): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  JS4D.DateMath;

class function TJSLocaleDateFormatter.HasDateFields(const Options: TJSDateFormatOptions): Boolean;
begin
  Result := (Options.Weekday <> TJSDateFieldStyle.None) or
            (Options.Year <> TJSDateFieldStyle.None) or
            (Options.Month <> TJSDateFieldStyle.None) or
            (Options.Day <> TJSDateFieldStyle.None);
end;

class function TJSLocaleDateFormatter.HasTimeFields(const Options: TJSDateFormatOptions): Boolean;
begin
  Result := (Options.Hour <> TJSDateFieldStyle.None) or
            (Options.Minute <> TJSDateFieldStyle.None) or
            (Options.Second <> TJSDateFieldStyle.None);
end;

class function TJSLocaleDateFormatter.IncludesDate(const Scope: TJSDateFormatScope): Boolean;
begin
  Result := (Scope <> TJSDateFormatScope.TimeOnly);
end;

class function TJSLocaleDateFormatter.IncludesTime(const Scope: TJSDateFormatScope): Boolean;
begin
  Result := (Scope <> TJSDateFormatScope.DateOnly);
end;

class function TJSLocaleDateFormatter.NeedsDefaults(const Options: TJSDateFormatOptions;
                                                    const Scope: TJSDateFormatScope): Boolean;
begin
  const HasRequestedDate = IncludesDate(Scope) and HasDateFields(Options);
  const HasRequestedTime = IncludesTime(Scope) and HasTimeFields(Options);

  Result := not (HasRequestedDate or HasRequestedTime);
end;

class function TJSLocaleDateFormatter.WithDefaults(const Options: TJSDateFormatOptions;
                                                   const Scope: TJSDateFormatScope): TJSDateFormatOptions;
begin
  Result := Options;

  if not NeedsDefaults(Options, Scope) then
    Exit;

  if IncludesDate(Scope) then
  begin
    Result.Year := TJSDateFieldStyle.Numeric;
    Result.Month := TJSDateFieldStyle.Numeric;
    Result.Day := TJSDateFieldStyle.Numeric;
  end;

  if IncludesTime(Scope) then
  begin
    Result.Hour := TJSDateFieldStyle.Numeric;
    Result.Minute := TJSDateFieldStyle.Numeric;
    Result.Second := TJSDateFieldStyle.Numeric;
  end;
end;

class function TJSLocaleDateFormatter.IsTwelveHour(const Locale: PJSLocaleDefinition;
                                                   const Options: TJSDateFormatOptions): Boolean;
begin
  case Options.HourCycle of
    TJSHourCycle.LocaleDefault : Result := Locale.Hour12ByDefault;
    TJSHourCycle.Twelve        : Result := True;
    TJSHourCycle.TwentyFour    : Result := False;
  else
    raise ENotSupportedException.CreateFmt('Unsupported hour cycle: %d', [Ord(Options.HourCycle)]);
  end;
end;

class function TJSLocaleDateFormatter.PartsOf(const Moment: Double): TDateParts;
begin
  const FullYear = TJSDateMath.YearFromTime(Moment);

  Result.Year := Trunc(FullYear);
  Result.Month := TJSDateMath.MonthFromTime(Moment);
  Result.Day := TJSDateMath.DateFromTime(Moment);
  Result.Weekday := TJSDateMath.WeekDay(Moment);
  Result.Hour := TJSDateMath.HourFromTime(Moment);
  Result.Minute := TJSDateMath.MinuteFromTime(Moment);
  Result.Second := TJSDateMath.SecondFromTime(Moment);
end;

class function TJSLocaleDateFormatter.WeekdayKey(const Style: TJSDateFieldStyle): string;
begin
  case Style of
    TJSDateFieldStyle.None                            : Result := '';
    TJSDateFieldStyle.Long                            : Result := LONG_WEEKDAY_KEY;
    TJSDateFieldStyle.Short, TJSDateFieldStyle.Narrow : Result := ABBREVIATED_WEEKDAY_KEY;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_WEEKDAY_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleDateFormatter.MonthKey(const Style: TJSDateFieldStyle): string;
begin
  case Style of
    TJSDateFieldStyle.None                            : Result := '';
    TJSDateFieldStyle.Numeric                         : Result := NUMERIC_MONTH_KEY;
    TJSDateFieldStyle.TwoDigit                        : Result := TWO_DIGIT_MONTH_KEY;
    TJSDateFieldStyle.Short, TJSDateFieldStyle.Narrow : Result := ABBREVIATED_MONTH_KEY;
    TJSDateFieldStyle.Long                            : Result := LONG_MONTH_KEY;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_MONTH_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleDateFormatter.NumericOrTwoDigitKey(const Style: TJSDateFieldStyle;
                                                           const NumericKey: string;
                                                           const TwoDigitKey: string): string;
begin
  case Style of
    TJSDateFieldStyle.None     : Result := '';
    TJSDateFieldStyle.TwoDigit : Result := TwoDigitKey;
  else
    Result := NumericKey;
  end;
end;

class function TJSLocaleDateFormatter.DatePatternKey(const Options: TJSDateFormatOptions): string;
begin
  Result := WeekdayKey(Options.Weekday);

  const HasYear = (Options.Year <> TJSDateFieldStyle.None);
  if HasYear then
    Result := Result + YEAR_KEY;

  const DayKey = NumericOrTwoDigitKey(Options.Day, NUMERIC_DAY_KEY, TWO_DIGIT_DAY_KEY);

  Result := Result + MonthKey(Options.Month) + DayKey;
end;

class function TJSLocaleDateFormatter.TimePatternKey(const Options: TJSDateFormatOptions): string;
begin
  const HourKey = NumericOrTwoDigitKey(Options.Hour, NUMERIC_HOUR_KEY, TWO_DIGIT_HOUR_KEY);
  const MinuteKey = NumericOrTwoDigitKey(Options.Minute, NUMERIC_MINUTE_KEY, TWO_DIGIT_MINUTE_KEY);
  const SecondKey = NumericOrTwoDigitKey(Options.Second, NUMERIC_SECOND_KEY, TWO_DIGIT_SECOND_KEY);

  Result := HourKey + MinuteKey + SecondKey;
end;

class function TJSLocaleDateFormatter.NumberText(const Value: Integer; const Width: Integer): string;
begin
  const Digits = IntToStr(Value);
  const MissingZeros = Width - Length(Digits);

  Result := StringOfChar('0', MissingZeros) + Digits;
end;

class function TJSLocaleDateFormatter.StyleText(const Style: TJSDateFieldStyle; const LongName: string;
                                                const ShortName: string; const NarrowNames: string;
                                                const Index: Integer; const UnsupportedFormat: string): string;
begin
  case Style of
    TJSDateFieldStyle.Long   : Result := LongName;
    TJSDateFieldStyle.Narrow : Result := NarrowNames.Substring(Index, 1);
    TJSDateFieldStyle.Short  : Result := ShortName;
  else
    raise ENotSupportedException.CreateFmt(UnsupportedFormat, [Ord(Style)]);
  end;
end;

class function TJSLocaleDateFormatter.WeekdayText(const Locale: PJSLocaleDefinition; const Weekday: Integer;
                                                  const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string;
begin
  const LongName = Locale.WeekdaysLong[Weekday];
  const StandaloneName = Locale.WeekdaysShortStandalone[Weekday];
  const FormatName = Locale.WeekdaysShort[Weekday];
  const ShortName = IfThen(IsStandalone, StandaloneName, FormatName);

  Result := StyleText(Style, LongName, ShortName, Locale.WeekdaysNarrow, Weekday, UNSUPPORTED_WEEKDAY_STYLE);
end;

class function TJSLocaleDateFormatter.MonthText(const Locale: PJSLocaleDefinition; const Month: Integer;
                                                const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string;
begin
  const LongName = Locale.MonthsLong[Month];
  const StandaloneName = Locale.MonthsShortStandalone[Month];
  const FormatName = Locale.MonthsShort[Month];
  const ShortName = IfThen(IsStandalone, StandaloneName, FormatName);

  Result := StyleText(Style, LongName, ShortName, Locale.MonthsNarrow, Month, UNSUPPORTED_MONTH_STYLE);
end;

class function TJSLocaleDateFormatter.YearText(const Year: Integer; const Style: TJSDateFieldStyle): string;
begin
  const IsTwoDigit = (Style = TJSDateFieldStyle.TwoDigit);
  if not IsTwoDigit then
  begin
    Result := IntToStr(Year);
    Exit;
  end;

  const LastTwoDigits = Abs(Year) mod TWO_DIGIT_YEAR_DIVISOR;

  Result := NumberText(LastTwoDigits, TWO_DIGIT_YEAR_WIDTH);
end;

class function TJSLocaleDateFormatter.HourText(const Hour: Integer; const IsTwelveHour: Boolean;
                                               const Width: Integer): string;
begin
  var DisplayHour := Hour;
  if IsTwelveHour then
  begin
    DisplayHour := Hour mod HOURS_PER_HALF_DAY;

    const IsMidnightOrNoon = (DisplayHour = 0);
    if IsMidnightOrNoon then
      DisplayHour := HOURS_PER_HALF_DAY;
  end;

  Result := NumberText(DisplayHour, Width);
end;

class function TJSLocaleDateFormatter.DayPeriodText(const Locale: PJSLocaleDefinition; const Hour: Integer): string;
begin
  const IsMorning = (Hour < HOURS_PER_HALF_DAY);

  Result := IfThen(IsMorning, Locale.AmMarker, Locale.PmMarker);
end;

class function TJSLocaleDateFormatter.RenderToken(const Token: Char; const Width: Integer; const Parts: TDateParts;
                                                  const Locale: PJSLocaleDefinition;
                                                  const Options: TJSDateFormatOptions): string;
begin
  const IsNameWidth = (Width >= MIN_NAME_TOKEN_LENGTH);

  const IsTwelveHourToken = (Token = TWELVE_HOUR_TOKEN);

  case Token of
    WEEKDAY_TOKEN            : Result := WeekdayText(Locale, Parts.Weekday, Options.Weekday, False);
    STANDALONE_WEEKDAY_TOKEN : Result := WeekdayText(Locale, Parts.Weekday, Options.Weekday, True);
    STANDALONE_MONTH_TOKEN   : Result := MonthText(Locale, Parts.Month, Options.Month, True);
    YEAR_TOKEN               : Result := YearText(Parts.Year, Options.Year);
    DAY_TOKEN                : Result := NumberText(Parts.Day, Width);
    MONTH_TOKEN              :
    begin
      if IsNameWidth then
        Result := MonthText(Locale, Parts.Month, Options.Month, False)
      else
        Result := NumberText(Parts.Month + 1, Width);
    end;
    TWELVE_HOUR_TOKEN,
    TWENTY_FOUR_HOUR_TOKEN   : Result := HourText(Parts.Hour, IsTwelveHourToken, Width);
    MINUTE_TOKEN             : Result := NumberText(Parts.Minute, Width);
    SECOND_TOKEN             : Result := NumberText(Parts.Second, Width);
    DAY_PERIOD_TOKEN         : Result := DayPeriodText(Locale, Parts.Hour);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_PATTERN_LETTER, [Token]);
  end;
end;

class function TJSLocaleDateFormatter.RenderPattern(const Pattern: string; const Parts: TDateParts;
                                                    const Locale: PJSLocaleDefinition;
                                                    const Options: TJSDateFormatOptions): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var Position := 1;
    while Position <= Length(Pattern) do
    begin
      const Segment = SegmentAt(Pattern, Position, Parts, Locale, Options);

      Builder.Append(Segment.Text);
      Inc(Position, Segment.ConsumedChars);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSLocaleDateFormatter.LiteralSegmentAt(const Pattern: string; const Position: Integer): TPatternSegment;
begin
  const LiteralEnd = PosEx(LITERAL_END, Pattern, Position);
  const HasLiteralEnd = (LiteralEnd > 0);
  if not HasLiteralEnd then
  begin
    Result.Text := Copy(Pattern, Position + 1, MaxInt);
    Result.ConsumedChars := Length(Pattern) - Position + 1;
    Exit;
  end;

  Result.Text := Copy(Pattern, Position + 1, LiteralEnd - Position - 1);
  Result.ConsumedChars := LiteralEnd - Position + 1;
end;

class function TJSLocaleDateFormatter.TokenSegmentAt(const Pattern: string; const Position: Integer;
                                                     const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                                     const Options: TJSDateFormatOptions): TPatternSegment;
begin
  const Token = Pattern[Position];

  var RunEnd := Position;
  while (RunEnd < Length(Pattern)) and (Pattern[RunEnd + 1] = Token) do
  begin
    Inc(RunEnd);
  end;

  Result.ConsumedChars := RunEnd - Position + 1;
  Result.Text := RenderToken(Token, Result.ConsumedChars, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.SegmentAt(const Pattern: string; const Position: Integer;
                                                const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                                const Options: TJSDateFormatOptions): TPatternSegment;
begin
  const Current = Pattern[Position];

  const StartsLiteral = (Current = LITERAL_START);
  const IsLetter = CharInSet(Current, ['a'..'z', 'A'..'Z']);

  if StartsLiteral then
    Result := LiteralSegmentAt(Pattern, Position)
  else if IsLetter then
    Result := TokenSegmentAt(Pattern, Position, Parts, Locale, Options)
  else
  begin
    Result.Text := Current;
    Result.ConsumedChars := 1;
  end;
end;

class function TJSLocaleDateFormatter.PatternText(const Patterns: TJSPatternMap; const Key: string;
                                                  const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                                  const Options: TJSDateFormatOptions): string;
begin
  Result := '';

  if Key.IsEmpty then
    Exit;

  var Pattern: string;
  const IsFound = Patterns.TryGetValue(Key, Pattern);
  if not IsFound then
    Exit;

  Result := RenderPattern(Pattern, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.DateText(const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                               const Options: TJSDateFormatOptions): string;
begin
  const Key = DatePatternKey(Options);

  Result := PatternText(Locale.DatePatternMap, Key, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.TimeText(const Parts: TDateParts; const Locale: PJSLocaleDefinition;
                                               const Options: TJSDateFormatOptions): string;
begin
  const Key = TimePatternKey(Options);
  const UsesTwelveHour = IsTwelveHour(Locale, Options);

  if UsesTwelveHour then
    Result := PatternText(Locale.TimePatterns12Map, Key, Parts, Locale, Options)
  else
    Result := PatternText(Locale.TimePatterns24Map, Key, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.DateTimeGlue(const Locale: PJSLocaleDefinition;
                                                   const Options: TJSDateFormatOptions): string;
begin
  case Options.Month of
    TJSDateFieldStyle.Long                            : Result := Locale.DateTimeGlueLong;
    TJSDateFieldStyle.Short, TJSDateFieldStyle.Narrow : Result := Locale.DateTimeGlueShort;
  else
    Result := Locale.DateTimeGlueNumeric;
  end;
end;

class function TJSLocaleDateFormatter.FormatMoment(const Moment: Double; const Locale: PJSLocaleDefinition;
                                                   const Options: TJSDateFormatOptions): string;
begin
  const Parts = PartsOf(Moment);
  const DatePart = DateText(Parts, Locale, Options);
  const TimePart = TimeText(Parts, Locale, Options);

  const HasBothParts = (not DatePart.IsEmpty) and (not TimePart.IsEmpty);
  if HasBothParts then
  begin
    const Glue = DateTimeGlue(Locale, Options);

    Result := DatePart + Glue + TimePart;
  end
  else
  begin
    Result := DatePart + TimePart;
  end;

  Result := Result.Replace(NARROW_NO_BREAK_SPACE, ORDINARY_SPACE, [rfReplaceAll]);
end;

end.
