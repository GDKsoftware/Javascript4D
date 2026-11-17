unit JS4D.DateMath;

{$SCOPEDENUMS ON}

interface

type
  TJSDateMath = class
  public
    const
      MS_PER_SECOND = 1000.0;
      MS_PER_MINUTE = 60000.0;
      MS_PER_HOUR = 3600000.0;
      MS_PER_DAY = 86400000.0;
      MAX_TIME_VALUE = 8.64E15;

  private
    const
      UNIX_EPOCH: Double = 25569.0;
      MIN_CONVERTIBLE_TIME = -62135596800000.0;
      MAX_CONVERTIBLE_TIME = 253402300799999.0;
      MAX_YEAR_MAGNITUDE = 400000.0;
      MONTHS_PER_YEAR = 12;

    class function DaysBeforeMonth(const Year: Double; const Month: Integer): Integer; static;
    class function DayWithinYear(const Time: Double): Integer; static;
    class function FloorOf(const Value: Double): Double; static;
    class function Modulo(const Value: Double; const Divisor: Double): Double; static;
    class function OffsetAt(const Time: Double): Double; static;

  public
    class function ToInteger(const Value: Double): Double; static;
    class function IsFinite(const Value: Double): Boolean; static;

    class function Day(const Time: Double): Double; static;
    class function TimeWithinDay(const Time: Double): Double; static;
    class function IsLeapYear(const Year: Double): Boolean; static;
    class function DayFromYear(const Year: Double): Double; static;
    class function TimeFromYear(const Year: Double): Double; static;
    class function YearFromTime(const Time: Double): Double; static;
    class function MonthFromTime(const Time: Double): Integer; static;
    class function DateFromTime(const Time: Double): Integer; static;
    class function WeekDay(const Time: Double): Integer; static;
    class function HourFromTime(const Time: Double): Integer; static;
    class function MinuteFromTime(const Time: Double): Integer; static;
    class function SecondFromTime(const Time: Double): Integer; static;
    class function MillisecondFromTime(const Time: Double): Integer; static;
    class function DaysInMonth(const Year: Double; const Month: Integer): Integer; static;

    class function MakeTime(const Hour, Minute, Second, Millisecond: Double): Double; static;
    class function MakeDay(const Year, Month, Date: Double): Double; static;
    class function MakeDate(const Day, Time: Double): Double; static;
    class function TimeClip(const Time: Double): Double; static;

    class function LocalOffset(const UtcTime: Double): Double; static;
    class function LocalTime(const UtcTime: Double): Double; static;
    class function ToUtc(const LocalTime: Double): Double; static;
    class function CurrentTime: Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.DateUtils;

const
  CUMULATIVE_DAYS: array[0..12] of Integer = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365);
  DAYS_PER_WEEK = 7;
  EPOCH_WEEK_DAY = 4;
  LEAP_DAY_MONTH = 2;

class function TJSDateMath.FloorOf(const Value: Double): Double;
begin
  Result := Int(Value);

  if Value < Result then
    Result := Result - 1;
end;

class function TJSDateMath.Modulo(const Value: Double; const Divisor: Double): Double;
begin
  Result := Value - (Divisor * FloorOf(Value / Divisor));
end;

class function TJSDateMath.ToInteger(const Value: Double): Double;
begin
  if System.Math.IsNaN(Value) or System.Math.IsInfinite(Value) then
    Exit(Value);

  const Whole = Int(Value);
  const IsNegativeZero = (Whole = 0) and Whole.Sign;
  if IsNegativeZero then
    Exit(0);

  Result := Whole;
end;

class function TJSDateMath.IsFinite(const Value: Double): Boolean;
begin
  Result := not (System.Math.IsNaN(Value) or System.Math.IsInfinite(Value));
end;

class function TJSDateMath.Day(const Time: Double): Double;
begin
  Result := FloorOf(Time / MS_PER_DAY);
end;

class function TJSDateMath.TimeWithinDay(const Time: Double): Double;
begin
  Result := Modulo(Time, MS_PER_DAY);
end;

class function TJSDateMath.IsLeapYear(const Year: Double): Boolean;
begin
  const DividesByFour = (Modulo(Year, 4) = 0);
  const DividesByHundred = (Modulo(Year, 100) = 0);
  const DividesByFourHundred = (Modulo(Year, 400) = 0);

  Result := DividesByFour and ((not DividesByHundred) or DividesByFourHundred);
end;

class function TJSDateMath.DayFromYear(const Year: Double): Double;
begin
  Result := (365 * (Year - 1970)) +
            FloorOf((Year - 1969) / 4) -
            FloorOf((Year - 1901) / 100) +
            FloorOf((Year - 1601) / 400);
end;

class function TJSDateMath.TimeFromYear(const Year: Double): Double;
begin
  Result := MS_PER_DAY * DayFromYear(Year);
end;

class function TJSDateMath.YearFromTime(const Time: Double): Double;
begin
  Result := FloorOf(Time / (MS_PER_DAY * 365.2425)) + 1970;

  while TimeFromYear(Result) > Time do
  begin
    Result := Result - 1;
  end;

  while TimeFromYear(Result + 1) <= Time do
  begin
    Result := Result + 1;
  end;
end;

class function TJSDateMath.DaysBeforeMonth(const Year: Double; const Month: Integer): Integer;
begin
  Result := CUMULATIVE_DAYS[Month];

  const PassesLeapDay = IsLeapYear(Year) and (Month >= LEAP_DAY_MONTH);
  if PassesLeapDay then
    Inc(Result);
end;

class function TJSDateMath.DayWithinYear(const Time: Double): Integer;
begin
  Result := Trunc(Day(Time) - DayFromYear(YearFromTime(Time)));
end;

class function TJSDateMath.MonthFromTime(const Time: Double): Integer;
begin
  const Year = YearFromTime(Time);
  const DayInYear = DayWithinYear(Time);

  Result := 0;
  while (Result < MONTHS_PER_YEAR - 1) and (DayInYear >= DaysBeforeMonth(Year, Result + 1)) do
  begin
    Inc(Result);
  end;
end;

class function TJSDateMath.DateFromTime(const Time: Double): Integer;
begin
  const Year = YearFromTime(Time);
  const Month = MonthFromTime(Time);

  Result := DayWithinYear(Time) - DaysBeforeMonth(Year, Month) + 1;
end;

class function TJSDateMath.WeekDay(const Time: Double): Integer;
begin
  Result := Trunc(Modulo(Day(Time) + EPOCH_WEEK_DAY, DAYS_PER_WEEK));
end;

class function TJSDateMath.HourFromTime(const Time: Double): Integer;
begin
  Result := Trunc(Modulo(FloorOf(Time / MS_PER_HOUR), 24));
end;

class function TJSDateMath.MinuteFromTime(const Time: Double): Integer;
begin
  Result := Trunc(Modulo(FloorOf(Time / MS_PER_MINUTE), 60));
end;

class function TJSDateMath.SecondFromTime(const Time: Double): Integer;
begin
  Result := Trunc(Modulo(FloorOf(Time / MS_PER_SECOND), 60));
end;

class function TJSDateMath.MillisecondFromTime(const Time: Double): Integer;
begin
  Result := Trunc(Modulo(Time, MS_PER_SECOND));
end;

class function TJSDateMath.DaysInMonth(const Year: Double; const Month: Integer): Integer;
begin
  Result := DaysBeforeMonth(Year, Month + 1) - DaysBeforeMonth(Year, Month);
end;

class function TJSDateMath.MakeTime(const Hour, Minute, Second, Millisecond: Double): Double;
begin
  const AllFinite = IsFinite(Hour) and IsFinite(Minute) and IsFinite(Second) and IsFinite(Millisecond);
  if not AllFinite then
    Exit(System.Math.NaN);

  Result := (ToInteger(Hour) * MS_PER_HOUR) +
            (ToInteger(Minute) * MS_PER_MINUTE) +
            (ToInteger(Second) * MS_PER_SECOND) +
            ToInteger(Millisecond);
end;

class function TJSDateMath.MakeDay(const Year, Month, Date: Double): Double;
begin
  const AllFinite = IsFinite(Year) and IsFinite(Month) and IsFinite(Date);
  if not AllFinite then
    Exit(System.Math.NaN);

  const YearNumber = ToInteger(Year) + FloorOf(ToInteger(Month) / MONTHS_PER_YEAR);
  const MonthNumber = Trunc(Modulo(ToInteger(Month), MONTHS_PER_YEAR));

  const IsOutOfRange = (Abs(YearNumber) > MAX_YEAR_MAGNITUDE) or (Abs(ToInteger(Date)) > MAX_TIME_VALUE);
  if IsOutOfRange then
    Exit(System.Math.NaN);

  Result := DayFromYear(YearNumber) + DaysBeforeMonth(YearNumber, MonthNumber) + ToInteger(Date) - 1;
end;

class function TJSDateMath.MakeDate(const Day, Time: Double): Double;
begin
  if not (IsFinite(Day) and IsFinite(Time)) then
    Exit(System.Math.NaN);

  Result := (Day * MS_PER_DAY) + Time;
end;

class function TJSDateMath.TimeClip(const Time: Double): Double;
begin
  const IsOutOfRange = (not IsFinite(Time)) or (Abs(Time) > MAX_TIME_VALUE);
  if IsOutOfRange then
    Exit(System.Math.NaN);

  Result := ToInteger(Time);
end;

class function TJSDateMath.OffsetAt(const Time: Double): Double;
begin
  const IsConvertible = (Time >= MIN_CONVERTIBLE_TIME) and (Time <= MAX_CONVERTIBLE_TIME);
  const Probe = IfThen(IsConvertible, Time, 0);

  const UtcDateTime = UNIX_EPOCH + (Probe / MS_PER_DAY);
  const LocalDateTime = TTimeZone.Local.ToLocalTime(UtcDateTime);

  Result := Round((LocalDateTime - UtcDateTime) * MS_PER_DAY / MS_PER_MINUTE) * MS_PER_MINUTE;
end;

class function TJSDateMath.LocalOffset(const UtcTime: Double): Double;
begin
  if System.Math.IsNaN(UtcTime) then
    Exit(0);

  Result := OffsetAt(UtcTime);
end;

class function TJSDateMath.LocalTime(const UtcTime: Double): Double;
begin
  Result := UtcTime + LocalOffset(UtcTime);
end;

class function TJSDateMath.ToUtc(const LocalTime: Double): Double;
begin
  const FirstGuess = LocalTime - LocalOffset(LocalTime);

  Result := LocalTime - LocalOffset(FirstGuess);
end;

class function TJSDateMath.CurrentTime: Double;
begin
  const UtcNow = TTimeZone.Local.ToUniversalTime(Now);

  Result := (DateTimeToUnix(UtcNow, True) * MS_PER_SECOND) + MilliSecondOf(UtcNow);
end;

end.
