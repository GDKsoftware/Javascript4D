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
        Length: Integer;
      end;

    const
      NARROW_NO_BREAK_SPACE = #$202F;
      ORDINARY_SPACE = ' ';
      TWELVE_HOUR_TOKEN = 'h';
      UNSUPPORTED_WEEKDAY_STYLE = 'Unsupported weekday style: %d';
      UNSUPPORTED_MONTH_STYLE = 'Unsupported month style: %d';
      LITERAL_START = '[';
      LITERAL_END = ']';
      TWO_DIGIT_YEAR_DIVISOR = 100;
      TWO_DIGIT_YEAR_WIDTH = 2;
      HOURS_PER_HALF_DAY = 12;
      MIN_NAME_TOKEN_LENGTH = 3;
      LONG_WEEKDAY_KEY = 'EEEE';
      ABBREVIATED_WEEKDAY_KEY = 'E';
      YEAR_KEY = 'y';
      NUMERIC_MONTH_KEY = 'M';
      TWO_DIGIT_MONTH_KEY = 'MM';
      ABBREVIATED_MONTH_KEY = 'MMM';
      LONG_MONTH_KEY = 'MMMM';
      NUMERIC_DAY_KEY = 'd';
      TWO_DIGIT_DAY_KEY = 'dd';
      NUMERIC_HOUR_KEY = 'h';
      TWO_DIGIT_HOUR_KEY = 'hh';
      NUMERIC_MINUTE_KEY = 'm';
      TWO_DIGIT_MINUTE_KEY = 'mm';
      NUMERIC_SECOND_KEY = 's';
      TWO_DIGIT_SECOND_KEY = 'ss';

    class function HasDateFields(const Options: TJSDateFormatOptions): Boolean; static;
    class function HasTimeFields(const Options: TJSDateFormatOptions): Boolean; static;
    class function IsTwelveHour(const Locale: TJSLocaleDefinition; const Options: TJSDateFormatOptions): Boolean; static;
    class function PartsOf(const Moment: Double): TDateParts; static;
    class function WeekdayKey(const Style: TJSDateFieldStyle): string; static;
    class function MonthKey(const Style: TJSDateFieldStyle): string; static;
    class function DatePatternKey(const Options: TJSDateFormatOptions): string; static;
    class function TimePatternKey(const Options: TJSDateFormatOptions): string; static;
    class function NumberText(const Value: Integer; const Width: Integer): string; static;
    class function WeekdayText(const Locale: TJSLocaleDefinition; const Weekday: Integer;
                               const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string; static;
    class function MonthText(const Locale: TJSLocaleDefinition; const Month: Integer;
                             const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string; static;
    class function YearText(const Year: Integer; const Style: TJSDateFieldStyle): string; static;
    class function HourText(const Hour: Integer; const IsTwelveHour: Boolean; const Width: Integer): string; static;
    class function DayPeriodText(const Locale: TJSLocaleDefinition; const Hour: Integer): string; static;
    class function RenderToken(const Token: Char; const Width: Integer; const Parts: TDateParts;
                               const Locale: TJSLocaleDefinition; const Options: TJSDateFormatOptions): string; static;
    class function LiteralSegmentAt(const Pattern: string; const Position: Integer): TPatternSegment; static;
    class function TokenSegmentAt(const Pattern: string; const Position: Integer; const Parts: TDateParts;
                                  const Locale: TJSLocaleDefinition;
                                  const Options: TJSDateFormatOptions): TPatternSegment; static;
    class function SegmentAt(const Pattern: string; const Position: Integer; const Parts: TDateParts;
                             const Locale: TJSLocaleDefinition;
                             const Options: TJSDateFormatOptions): TPatternSegment; static;
    class function RenderPattern(const Pattern: string; const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                                 const Options: TJSDateFormatOptions): string; static;
    class function DateText(const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                            const Options: TJSDateFormatOptions): string; static;
    class function TimeText(const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                            const Options: TJSDateFormatOptions): string; static;
    class function DateTimeGlue(const Locale: TJSLocaleDefinition; const Options: TJSDateFormatOptions): string; static;
  public
    class function WithDefaults(const Options: TJSDateFormatOptions;
                                const Scope: TJSDateFormatScope): TJSDateFormatOptions; static;
    class function FormatMoment(const Moment: Double; const Locale: TJSLocaleDefinition;
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

class function TJSLocaleDateFormatter.WithDefaults(const Options: TJSDateFormatOptions;
                                                   const Scope: TJSDateFormatScope): TJSDateFormatOptions;
begin
  Result := Options;

  const ChecksDate = (Scope <> TJSDateFormatScope.TimeOnly);
  const ChecksTime = (Scope <> TJSDateFormatScope.DateOnly);

  var NeedsDefaults := True;
  if ChecksDate and HasDateFields(Options) then
    NeedsDefaults := False;

  if ChecksTime and HasTimeFields(Options) then
    NeedsDefaults := False;

  if not NeedsDefaults then
    Exit;

  const AddsDate = (Scope <> TJSDateFormatScope.TimeOnly);
  if AddsDate then
  begin
    Result.Year := TJSDateFieldStyle.Numeric;
    Result.Month := TJSDateFieldStyle.Numeric;
    Result.Day := TJSDateFieldStyle.Numeric;
  end;

  const AddsTime = (Scope <> TJSDateFormatScope.DateOnly);
  if AddsTime then
  begin
    Result.Hour := TJSDateFieldStyle.Numeric;
    Result.Minute := TJSDateFieldStyle.Numeric;
    Result.Second := TJSDateFieldStyle.Numeric;
  end;
end;

class function TJSLocaleDateFormatter.IsTwelveHour(const Locale: TJSLocaleDefinition;
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

class function TJSLocaleDateFormatter.DatePatternKey(const Options: TJSDateFormatOptions): string;
begin
  Result := WeekdayKey(Options.Weekday);

  const HasYear = (Options.Year <> TJSDateFieldStyle.None);
  if HasYear then
    Result := Result + YEAR_KEY;

  Result := Result + MonthKey(Options.Month);

  case Options.Day of
    TJSDateFieldStyle.None     : ;
    TJSDateFieldStyle.TwoDigit : Result := Result + TWO_DIGIT_DAY_KEY;
  else
    Result := Result + NUMERIC_DAY_KEY;
  end;
end;

class function TJSLocaleDateFormatter.TimePatternKey(const Options: TJSDateFormatOptions): string;
begin
  Result := '';

  case Options.Hour of
    TJSDateFieldStyle.None     : ;
    TJSDateFieldStyle.TwoDigit : Result := Result + TWO_DIGIT_HOUR_KEY;
  else
    Result := Result + NUMERIC_HOUR_KEY;
  end;

  case Options.Minute of
    TJSDateFieldStyle.None     : ;
    TJSDateFieldStyle.TwoDigit : Result := Result + TWO_DIGIT_MINUTE_KEY;
  else
    Result := Result + NUMERIC_MINUTE_KEY;
  end;

  case Options.Second of
    TJSDateFieldStyle.None     : ;
    TJSDateFieldStyle.TwoDigit : Result := Result + TWO_DIGIT_SECOND_KEY;
  else
    Result := Result + NUMERIC_SECOND_KEY;
  end;
end;

class function TJSLocaleDateFormatter.NumberText(const Value: Integer; const Width: Integer): string;
begin
  const Digits = IntToStr(Value);
  const MissingZeros = Width - Length(Digits);

  Result := StringOfChar('0', MissingZeros) + Digits;
end;

class function TJSLocaleDateFormatter.WeekdayText(const Locale: TJSLocaleDefinition; const Weekday: Integer;
                                                  const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string;
begin
  case Style of
    TJSDateFieldStyle.Long   : Result := Locale.WeekdaysLong[Weekday];
    TJSDateFieldStyle.Narrow : Result := Locale.WeekdaysNarrow.Substring(Weekday, 1);
    TJSDateFieldStyle.Short  : Result := IfThen(IsStandalone, Locale.WeekdaysShortStandalone[Weekday], Locale.WeekdaysShort[Weekday]);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_WEEKDAY_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleDateFormatter.MonthText(const Locale: TJSLocaleDefinition; const Month: Integer;
                                                const Style: TJSDateFieldStyle; const IsStandalone: Boolean): string;
begin
  case Style of
    TJSDateFieldStyle.Long   : Result := Locale.MonthsLong[Month];
    TJSDateFieldStyle.Narrow : Result := Locale.MonthsNarrow.Substring(Month, 1);
    TJSDateFieldStyle.Short  : Result := IfThen(IsStandalone, Locale.MonthsShortStandalone[Month], Locale.MonthsShort[Month]);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_MONTH_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleDateFormatter.YearText(const Year: Integer; const Style: TJSDateFieldStyle): string;
begin
  const IsTwoDigit = (Style = TJSDateFieldStyle.TwoDigit);
  if not IsTwoDigit then
    Exit(IntToStr(Year));

  const LastTwoDigits = Abs(Year) mod TWO_DIGIT_YEAR_DIVISOR;

  Result := NumberText(LastTwoDigits, TWO_DIGIT_YEAR_WIDTH);
end;

class function TJSLocaleDateFormatter.HourText(const Hour: Integer; const IsTwelveHour: Boolean; const Width: Integer): string;
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

class function TJSLocaleDateFormatter.DayPeriodText(const Locale: TJSLocaleDefinition; const Hour: Integer): string;
begin
  const IsMorning = (Hour < HOURS_PER_HALF_DAY);

  Result := IfThen(IsMorning, Locale.AmMarker, Locale.PmMarker);
end;

class function TJSLocaleDateFormatter.RenderToken(const Token: Char; const Width: Integer; const Parts: TDateParts;
                                                  const Locale: TJSLocaleDefinition;
                                                  const Options: TJSDateFormatOptions): string;
begin
  const IsNameWidth = (Width >= MIN_NAME_TOKEN_LENGTH);

  case Token of
    'E' : Result := WeekdayText(Locale, Parts.Weekday, Options.Weekday, False);
    'c' : Result := WeekdayText(Locale, Parts.Weekday, Options.Weekday, True);
    'L' : Result := MonthText(Locale, Parts.Month, Options.Month, True);
    'y' : Result := YearText(Parts.Year, Options.Year);
    'd' : Result := NumberText(Parts.Day, Width);
    'M' :
    begin
      if IsNameWidth then
        Result := MonthText(Locale, Parts.Month, Options.Month, False)
      else
        Result := NumberText(Parts.Month + 1, Width);
    end;
    'h',
    'H' : Result := HourText(Parts.Hour, Token = TWELVE_HOUR_TOKEN, Width);
    'm' : Result := NumberText(Parts.Minute, Width);
    's' : Result := NumberText(Parts.Second, Width);
    'a' : Result := DayPeriodText(Locale, Parts.Hour);
  else
    raise ENotSupportedException.CreateFmt('Unsupported pattern letter: %s', [Token]);
  end;
end;

class function TJSLocaleDateFormatter.RenderPattern(const Pattern: string; const Parts: TDateParts;
                                                    const Locale: TJSLocaleDefinition;
                                                    const Options: TJSDateFormatOptions): string;
begin
  Result := '';

  var Position := 1;
  while Position <= Length(Pattern) do
  begin
    const Segment = SegmentAt(Pattern, Position, Parts, Locale, Options);

    Result := Result + Segment.Text;
    Inc(Position, Segment.Length);
  end;
end;

class function TJSLocaleDateFormatter.LiteralSegmentAt(const Pattern: string; const Position: Integer): TPatternSegment;
begin
  const LiteralEnd = PosEx(LITERAL_END, Pattern, Position);

  Result.Text := Copy(Pattern, Position + 1, LiteralEnd - Position - 1);
  Result.Length := LiteralEnd - Position + 1;
end;

class function TJSLocaleDateFormatter.TokenSegmentAt(const Pattern: string; const Position: Integer;
                                                     const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                                                     const Options: TJSDateFormatOptions): TPatternSegment;
begin
  const Token = Pattern[Position];

  var RunEnd := Position;
  while (RunEnd < Length(Pattern)) and (Pattern[RunEnd + 1] = Token) do
  begin
    Inc(RunEnd);
  end;

  Result.Length := RunEnd - Position + 1;
  Result.Text := RenderToken(Token, Result.Length, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.SegmentAt(const Pattern: string; const Position: Integer;
                                                const Parts: TDateParts; const Locale: TJSLocaleDefinition;
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
    Result.Length := 1;
  end;
end;

class function TJSLocaleDateFormatter.DateText(const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                                               const Options: TJSDateFormatOptions): string;
begin
  Result := '';

  const Key = DatePatternKey(Options);
  if Key.IsEmpty then
    Exit;

  var Pattern: string;
  const IsFound = TJSBuiltInLocaleTable.FindPattern(Locale.DatePatterns, Key, Pattern);
  if not IsFound then
    Exit;

  Result := RenderPattern(Pattern, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.TimeText(const Parts: TDateParts; const Locale: TJSLocaleDefinition;
                                               const Options: TJSDateFormatOptions): string;
begin
  Result := '';

  const Key = TimePatternKey(Options);
  if Key.IsEmpty then
    Exit;

  const UsesTwelveHour = IsTwelveHour(Locale, Options);
  const Patterns = IfThen(UsesTwelveHour, Locale.TimePatterns12, Locale.TimePatterns24);

  var Pattern: string;
  const IsFound = TJSBuiltInLocaleTable.FindPattern(Patterns, Key, Pattern);
  if not IsFound then
    Exit;

  Result := RenderPattern(Pattern, Parts, Locale, Options);
end;

class function TJSLocaleDateFormatter.DateTimeGlue(const Locale: TJSLocaleDefinition;
                                                   const Options: TJSDateFormatOptions): string;
begin
  case Options.Month of
    TJSDateFieldStyle.Long                            : Result := Locale.DateTimeGlueLong;
    TJSDateFieldStyle.Short, TJSDateFieldStyle.Narrow : Result := Locale.DateTimeGlueShort;
  else
    Result := Locale.DateTimeGlueNumeric;
  end;
end;

class function TJSLocaleDateFormatter.FormatMoment(const Moment: Double; const Locale: TJSLocaleDefinition;
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
