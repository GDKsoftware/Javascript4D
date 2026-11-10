unit JS4D.DateText;

{$SCOPEDENUMS ON}

interface

type
  // The string forms of ES5 15.9.5. Every function expects a finite time value.
  TJSDateText = class
  private
    class function YearText(const Year: Double; const PlainDigits: Integer): string; static;
    class function OffsetText(const UtcTime: Double): string; static;
  public
    class function ToDateString(const UtcTime: Double): string; static;
    class function ToTimeString(const UtcTime: Double): string; static;
    class function ToFullString(const UtcTime: Double): string; static;
    class function ToUtcString(const UtcTime: Double): string; static;
    class function ToIsoString(const UtcTime: Double): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.StrUtils,
  JS4D.DateMath;

const
  WeekDayNames: array[0..6] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
  MonthNames: array[0..11] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  DATE_FORMAT = '%s %s %.2d %s';
  TIME_FORMAT = '%.2d:%.2d:%.2d GMT%s';
  FULL_FORMAT = '%s %s';
  UTC_FORMAT = '%s, %.2d %s %s %.2d:%.2d:%.2d GMT';
  ISO_FORMAT = '%s-%.2d-%.2dT%.2d:%.2d:%.2d.%.3dZ';
  OFFSET_FORMAT = '%s%.2d%.2d';
  YEAR_FORMAT = '%s%.*d';
  PlainYearDigits = 4;
  ExtendedYearDigits = 6;
  MaxPlainYear = 9999;
  MinutesPerHour = 60;
  MINUS_SIGN = '-';
  PLUS_SIGN = '+';

class function TJSDateText.YearText(const Year: Double; const PlainDigits: Integer): string;
begin
  const Sign = IfThen(Year < 0, MINUS_SIGN, '');

  Result := Format(YEAR_FORMAT, [Sign, PlainDigits, Abs(Trunc(Year))]);
end;

class function TJSDateText.OffsetText(const UtcTime: Double): string;
begin
  const OffsetMinutes = Round(TJSDateMath.LocalOffset(UtcTime) / TJSDateMath.MsPerMinute);
  const Sign = IfThen(OffsetMinutes < 0, MINUS_SIGN, PLUS_SIGN);

  Result := Format(OFFSET_FORMAT, [Sign, Abs(OffsetMinutes) div MinutesPerHour, Abs(OffsetMinutes) mod MinutesPerHour]);
end;

class function TJSDateText.ToDateString(const UtcTime: Double): string;
begin
  const LocalTime = TJSDateMath.LocalTime(UtcTime);

  Result := Format(DATE_FORMAT, [WeekDayNames[TJSDateMath.WeekDay(LocalTime)],
                                 MonthNames[TJSDateMath.MonthFromTime(LocalTime)],
                                 TJSDateMath.DateFromTime(LocalTime),
                                 YearText(TJSDateMath.YearFromTime(LocalTime), PlainYearDigits)]);
end;

class function TJSDateText.ToTimeString(const UtcTime: Double): string;
begin
  const LocalTime = TJSDateMath.LocalTime(UtcTime);

  Result := Format(TIME_FORMAT, [TJSDateMath.HourFromTime(LocalTime),
                                 TJSDateMath.MinuteFromTime(LocalTime),
                                 TJSDateMath.SecondFromTime(LocalTime),
                                 OffsetText(UtcTime)]);
end;

class function TJSDateText.ToFullString(const UtcTime: Double): string;
begin
  Result := Format(FULL_FORMAT, [ToDateString(UtcTime), ToTimeString(UtcTime)]);
end;

class function TJSDateText.ToUtcString(const UtcTime: Double): string;
begin
  Result := Format(UTC_FORMAT, [WeekDayNames[TJSDateMath.WeekDay(UtcTime)],
                                TJSDateMath.DateFromTime(UtcTime),
                                MonthNames[TJSDateMath.MonthFromTime(UtcTime)],
                                YearText(TJSDateMath.YearFromTime(UtcTime), PlainYearDigits),
                                TJSDateMath.HourFromTime(UtcTime),
                                TJSDateMath.MinuteFromTime(UtcTime),
                                TJSDateMath.SecondFromTime(UtcTime)]);
end;

class function TJSDateText.ToIsoString(const UtcTime: Double): string;
begin
  const Year = TJSDateMath.YearFromTime(UtcTime);

  var YearPart: string;
  const IsPlainYear = (Year >= 0) and (Year <= MaxPlainYear);
  if IsPlainYear then
    YearPart := YearText(Year, PlainYearDigits)
  else
    YearPart := IfThen(Year < 0, MINUS_SIGN, PLUS_SIGN) + YearText(Abs(Year), ExtendedYearDigits);

  Result := Format(ISO_FORMAT, [YearPart,
                                TJSDateMath.MonthFromTime(UtcTime) + 1,
                                TJSDateMath.DateFromTime(UtcTime),
                                TJSDateMath.HourFromTime(UtcTime),
                                TJSDateMath.MinuteFromTime(UtcTime),
                                TJSDateMath.SecondFromTime(UtcTime),
                                TJSDateMath.MillisecondFromTime(UtcTime)]);
end;

end.
