unit JS4D.DateText;

{$SCOPEDENUMS ON}

interface

type
  TJSDateText = class
  private
    class function YearText(const Year: Double; const PlainDigits: Integer): string; static;
    class function IsoYearText(const Year: Double): string; static;
    class function OffsetText(const FiniteUtcTime: Double): string; static;
  public
    class function ToDateString(const FiniteUtcTime: Double): string; static;
    class function ToTimeString(const FiniteUtcTime: Double): string; static;
    class function ToFullString(const FiniteUtcTime: Double): string; static;
    class function ToUtcString(const FiniteUtcTime: Double): string; static;
    class function ToIsoString(const FiniteUtcTime: Double): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  JS4D.DateMath;

const
  DATE_FORMAT = '%s %s %.2d %s';
  TIME_FORMAT = '%.2d:%.2d:%.2d GMT%s';
  FULL_FORMAT = '%s %s';
  UTC_FORMAT = '%s, %.2d %s %s %.2d:%.2d:%.2d GMT';
  ISO_FORMAT = '%s-%.2d-%.2dT%.2d:%.2d:%.2d.%.3dZ';
  OFFSET_FORMAT = '%s%.2d%.2d';
  YEAR_FORMAT = '%s%.*d';
  PLAIN_YEAR_DIGITS = 4;
  EXTENDED_YEAR_DIGITS = 6;
  MAX_PLAIN_YEAR = 9999;
  MINUS_SIGN = '-';
  PLUS_SIGN = '+';

class function TJSDateText.YearText(const Year: Double; const PlainDigits: Integer): string;
begin
  const Sign = IfThen(Year < 0, MINUS_SIGN, string.Empty);
  const Magnitude = Abs(Trunc(Year));

  Result := Format(YEAR_FORMAT, [Sign, PlainDigits, Magnitude]);
end;

class function TJSDateText.IsoYearText(const Year: Double): string;
begin
  const IsPlainYear = (Year >= 0) and (Year <= MAX_PLAIN_YEAR);
  if IsPlainYear then
  begin
    Result := YearText(Year, PLAIN_YEAR_DIGITS);
    Exit;
  end;

  const Sign = IfThen(Year < 0, MINUS_SIGN, PLUS_SIGN);
  const Magnitude = Abs(Trunc(Year));

  Result := Format(YEAR_FORMAT, [Sign, EXTENDED_YEAR_DIGITS, Magnitude]);
end;

class function TJSDateText.OffsetText(const FiniteUtcTime: Double): string;
begin
  const OffsetMs = TJSDateMath.LocalOffset(FiniteUtcTime);
  const OffsetMinutes = Round(OffsetMs / TJSDateMath.MS_PER_MINUTE);
  const Sign = IfThen(OffsetMinutes < 0, MINUS_SIGN, PLUS_SIGN);
  const AbsoluteMinutes = Abs(OffsetMinutes);
  const Hours = AbsoluteMinutes div TJSDateMath.MINUTES_PER_HOUR;
  const Minutes = AbsoluteMinutes mod TJSDateMath.MINUTES_PER_HOUR;

  Result := Format(OFFSET_FORMAT, [Sign, Hours, Minutes]);
end;

class function TJSDateText.ToDateString(const FiniteUtcTime: Double): string;
begin
  const LocalTime = TJSDateMath.LocalTime(FiniteUtcTime);
  const WeekDay = TJSDateMath.WeekDay(LocalTime);
  const WeekDayName = TJSDateMath.WEEK_DAY_NAMES[WeekDay];
  const MonthIndex = TJSDateMath.MonthFromTime(LocalTime);
  const MonthName = TJSDateMath.MONTH_NAMES[MonthIndex];
  const Day = TJSDateMath.DateFromTime(LocalTime);
  const Year = TJSDateMath.YearFromTime(LocalTime);
  const Text = YearText(Year, PLAIN_YEAR_DIGITS);

  Result := Format(DATE_FORMAT, [WeekDayName, MonthName, Day, Text]);
end;

class function TJSDateText.ToTimeString(const FiniteUtcTime: Double): string;
begin
  const LocalTime = TJSDateMath.LocalTime(FiniteUtcTime);
  const Hour = TJSDateMath.HourFromTime(LocalTime);
  const Minute = TJSDateMath.MinuteFromTime(LocalTime);
  const Second = TJSDateMath.SecondFromTime(LocalTime);
  const Offset = OffsetText(FiniteUtcTime);

  Result := Format(TIME_FORMAT, [Hour, Minute, Second, Offset]);
end;

class function TJSDateText.ToFullString(const FiniteUtcTime: Double): string;
begin
  const DateText = ToDateString(FiniteUtcTime);
  const TimeText = ToTimeString(FiniteUtcTime);

  Result := Format(FULL_FORMAT, [DateText, TimeText]);
end;

class function TJSDateText.ToUtcString(const FiniteUtcTime: Double): string;
begin
  const WeekDay = TJSDateMath.WeekDay(FiniteUtcTime);
  const WeekDayName = TJSDateMath.WEEK_DAY_NAMES[WeekDay];
  const MonthIndex = TJSDateMath.MonthFromTime(FiniteUtcTime);
  const MonthName = TJSDateMath.MONTH_NAMES[MonthIndex];
  const Day = TJSDateMath.DateFromTime(FiniteUtcTime);
  const Year = TJSDateMath.YearFromTime(FiniteUtcTime);
  const Text = YearText(Year, PLAIN_YEAR_DIGITS);
  const Hour = TJSDateMath.HourFromTime(FiniteUtcTime);
  const Minute = TJSDateMath.MinuteFromTime(FiniteUtcTime);
  const Second = TJSDateMath.SecondFromTime(FiniteUtcTime);

  Result := Format(UTC_FORMAT, [WeekDayName, Day, MonthName, Text, Hour, Minute, Second]);
end;

class function TJSDateText.ToIsoString(const FiniteUtcTime: Double): string;
begin
  const Year = TJSDateMath.YearFromTime(FiniteUtcTime);
  const YearPart = IsoYearText(Year);
  const Month = TJSDateMath.MonthFromTime(FiniteUtcTime) + 1;
  const Day = TJSDateMath.DateFromTime(FiniteUtcTime);
  const Hour = TJSDateMath.HourFromTime(FiniteUtcTime);
  const Minute = TJSDateMath.MinuteFromTime(FiniteUtcTime);
  const Second = TJSDateMath.SecondFromTime(FiniteUtcTime);
  const Millisecond = TJSDateMath.MillisecondFromTime(FiniteUtcTime);

  Result := Format(ISO_FORMAT, [YearPart, Month, Day, Hour, Minute, Second, Millisecond]);
end;

end.
