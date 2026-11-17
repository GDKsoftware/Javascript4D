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
      MINUTES_PER_HOUR = 60;
      MONTHS_PER_YEAR = 12;
      WEEK_DAY_NAMES: array[0..6] of string = ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
      MONTH_NAMES: array[0..11] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                             'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');

  private
    const
      UNIX_EPOCH: Double = 25569.0;
      MIN_CONVERTIBLE_TIME = -62135596800000.0;
      MAX_CONVERTIBLE_TIME = 253402300799999.0;
      MAX_YEAR_MAGNITUDE = 400000.0;

    class function DaysBeforeMonth(const Year: Double; const Month: Integer): Integer; static;
    class function DayWithinYear(const Time: Double): Integer; static;
    class function Modulo(const Value: Double; const Divisor: Double): Double; static;
    class function TimeUnitOfCycle(const Time: Double; const MsPerUnit: Double; const UnitsPerCycle: Integer): Integer;
      static;
    class function YearStartsAfter(const Year: Double; const Time: Double): Boolean; static;
    class function NextYearStartsBy(const Year: Double; const Time: Double): Boolean; static;
    class function LaterMonthStartedBy(const Year: Double; const DayInYear: Integer; const Month: Integer): Boolean;
      static;
    class function OffsetAt(const Time: Double): Double; static;

  public
    class function ToInteger(const Value: Double): Double; static;

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
  System.DateUtils,
  JS4D.MathFunctions;

const
  HOURS_PER_DAY = 24;
  SECONDS_PER_MINUTE = 60;
  DAYS_PER_COMMON_YEAR = 365;
  AVERAGE_DAYS_PER_YEAR = 365.2425;
  EPOCH_YEAR = 1970;
  LEAP_YEAR_REFERENCE = 1969;
  CENTURY_REFERENCE = 1901;
  FOUR_CENTURY_REFERENCE = 1601;
  YEARS_PER_LEAP_CYCLE = 4;
  YEARS_PER_CENTURY = 100;
  YEARS_PER_FOUR_CENTURIES = 400;
  LAST_MONTH = 11;
  CUMULATIVE_DAYS: array[0..12] of Integer = (0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334, 365);
  DAYS_PER_WEEK = 7;
  EPOCH_WEEK_DAY = 4;
  LEAP_DAY_MONTH = 2;

class function TJSDateMath.Modulo(const Value: Double; const Divisor: Double): Double;
begin
  Result := Value - (Divisor * TJSMathFunctions.JsFloor(Value / Divisor));
end;

class function TJSDateMath.TimeUnitOfCycle(const Time: Double; const MsPerUnit: Double;
                                           const UnitsPerCycle: Integer): Integer;
begin
  const WholeUnits = TJSMathFunctions.JsFloor(Time / MsPerUnit);
  const UnitInCycle = Modulo(WholeUnits, UnitsPerCycle);

  Result := Trunc(UnitInCycle);
end;

class function TJSDateMath.YearStartsAfter(const Year: Double; const Time: Double): Boolean;
begin
  Result := (TimeFromYear(Year) > Time);
end;

class function TJSDateMath.NextYearStartsBy(const Year: Double; const Time: Double): Boolean;
begin
  Result := (TimeFromYear(Year + 1) <= Time);
end;

class function TJSDateMath.LaterMonthStartedBy(const Year: Double; const DayInYear: Integer;
                                               const Month: Integer): Boolean;
begin
  const HasLaterMonth = (Month < LAST_MONTH);
  if not HasLaterMonth then
    Exit(False);

  const NextMonthStart = DaysBeforeMonth(Year, Month + 1);

  Result := (DayInYear >= NextMonthStart);
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

class function TJSDateMath.Day(const Time: Double): Double;
begin
  Result := TJSMathFunctions.JsFloor(Time / MS_PER_DAY);
end;

class function TJSDateMath.TimeWithinDay(const Time: Double): Double;
begin
  Result := Modulo(Time, MS_PER_DAY);
end;

class function TJSDateMath.IsLeapYear(const Year: Double): Boolean;
begin
  const DividesByFour = (Modulo(Year, YEARS_PER_LEAP_CYCLE) = 0);
  const DividesByHundred = (Modulo(Year, YEARS_PER_CENTURY) = 0);
  const DividesByFourHundred = (Modulo(Year, YEARS_PER_FOUR_CENTURIES) = 0);

  Result := DividesByFour and ((not DividesByHundred) or DividesByFourHundred);
end;

class function TJSDateMath.DayFromYear(const Year: Double): Double;
begin
  const LeapDays = TJSMathFunctions.JsFloor((Year - LEAP_YEAR_REFERENCE) / YEARS_PER_LEAP_CYCLE);
  const CenturyDays = TJSMathFunctions.JsFloor((Year - CENTURY_REFERENCE) / YEARS_PER_CENTURY);
  const FourCenturyDays = TJSMathFunctions.JsFloor((Year - FOUR_CENTURY_REFERENCE) / YEARS_PER_FOUR_CENTURIES);

  Result := (DAYS_PER_COMMON_YEAR * (Year - EPOCH_YEAR)) + LeapDays - CenturyDays + FourCenturyDays;
end;

class function TJSDateMath.TimeFromYear(const Year: Double): Double;
begin
  Result := MS_PER_DAY * DayFromYear(Year);
end;

class function TJSDateMath.YearFromTime(const Time: Double): Double;
begin
  const AverageYearLength = MS_PER_DAY * AVERAGE_DAYS_PER_YEAR;
  const YearsSinceEpoch = TJSMathFunctions.JsFloor(Time / AverageYearLength);

  Result := YearsSinceEpoch + EPOCH_YEAR;

  while YearStartsAfter(Result, Time) do
  begin
    Result := Result - 1;
  end;

  while NextYearStartsBy(Result, Time) do
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
  const Year = YearFromTime(Time);
  const YearStart = DayFromYear(Year);
  const DayInYear = Day(Time) - YearStart;

  Result := Trunc(DayInYear);
end;

class function TJSDateMath.MonthFromTime(const Time: Double): Integer;
begin
  const Year = YearFromTime(Time);
  const DayInYear = DayWithinYear(Time);

  Result := 0;
  while LaterMonthStartedBy(Year, DayInYear, Result) do
  begin
    Inc(Result);
  end;
end;

class function TJSDateMath.DateFromTime(const Time: Double): Integer;
begin
  const Year = YearFromTime(Time);
  const Month = MonthFromTime(Time);

  const DayInYear = DayWithinYear(Time);
  const MonthStart = DaysBeforeMonth(Year, Month);

  Result := DayInYear - MonthStart + 1;
end;

class function TJSDateMath.WeekDay(const Time: Double): Integer;
begin
  const DayNumber = Day(Time) + EPOCH_WEEK_DAY;
  const DayOfWeek = Modulo(DayNumber, DAYS_PER_WEEK);

  Result := Trunc(DayOfWeek);
end;

class function TJSDateMath.HourFromTime(const Time: Double): Integer;
begin
  Result := TimeUnitOfCycle(Time, MS_PER_HOUR, HOURS_PER_DAY);
end;

class function TJSDateMath.MinuteFromTime(const Time: Double): Integer;
begin
  Result := TimeUnitOfCycle(Time, MS_PER_MINUTE, MINUTES_PER_HOUR);
end;

class function TJSDateMath.SecondFromTime(const Time: Double): Integer;
begin
  Result := TimeUnitOfCycle(Time, MS_PER_SECOND, SECONDS_PER_MINUTE);
end;

class function TJSDateMath.MillisecondFromTime(const Time: Double): Integer;
begin
  const Milliseconds = Modulo(Time, MS_PER_SECOND);

  Result := Trunc(Milliseconds);
end;

class function TJSDateMath.DaysInMonth(const Year: Double; const Month: Integer): Integer;
begin
  const NextMonthStart = DaysBeforeMonth(Year, Month + 1);
  const MonthStart = DaysBeforeMonth(Year, Month);

  Result := NextMonthStart - MonthStart;
end;

class function TJSDateMath.MakeTime(const Hour, Minute, Second, Millisecond: Double): Double;
begin
  const AllFinite = (TJSMathFunctions.IsFiniteNumber(Hour) and
                     TJSMathFunctions.IsFiniteNumber(Minute) and
                     TJSMathFunctions.IsFiniteNumber(Second) and
                     TJSMathFunctions.IsFiniteNumber(Millisecond));
  if not AllFinite then
    Exit(System.Math.NaN);

  const HourMs = ToInteger(Hour) * MS_PER_HOUR;
  const MinuteMs = ToInteger(Minute) * MS_PER_MINUTE;
  const SecondMs = ToInteger(Second) * MS_PER_SECOND;

  Result := HourMs + MinuteMs + SecondMs + ToInteger(Millisecond);
end;

class function TJSDateMath.MakeDay(const Year, Month, Date: Double): Double;
begin
  const AllFinite = (TJSMathFunctions.IsFiniteNumber(Year) and
                     TJSMathFunctions.IsFiniteNumber(Month) and
                     TJSMathFunctions.IsFiniteNumber(Date));
  if not AllFinite then
    Exit(System.Math.NaN);

  const WholeMonth = ToInteger(Month);
  const WholeDate = ToInteger(Date);
  const YearCarry = TJSMathFunctions.JsFloor(WholeMonth / MONTHS_PER_YEAR);
  const YearNumber = ToInteger(Year) + YearCarry;
  const MonthInYear = Modulo(WholeMonth, MONTHS_PER_YEAR);
  const MonthNumber = Trunc(MonthInYear);

  const IsOutOfRange = (Abs(YearNumber) > MAX_YEAR_MAGNITUDE) or (Abs(WholeDate) > MAX_TIME_VALUE);
  if IsOutOfRange then
    Exit(System.Math.NaN);

  const YearStart = DayFromYear(YearNumber);
  const MonthStart = DaysBeforeMonth(YearNumber, MonthNumber);

  Result := YearStart + MonthStart + WholeDate - 1;
end;

class function TJSDateMath.MakeDate(const Day, Time: Double): Double;
begin
  const BothFinite = (TJSMathFunctions.IsFiniteNumber(Day) and
                      TJSMathFunctions.IsFiniteNumber(Time));
  if not BothFinite then
    Exit(System.Math.NaN);

  Result := (Day * MS_PER_DAY) + Time;
end;

class function TJSDateMath.TimeClip(const Time: Double): Double;
begin
  const IsInfiniteTime = (not TJSMathFunctions.IsFiniteNumber(Time));
  const IsOutOfRange = (IsInfiniteTime or (Abs(Time) > MAX_TIME_VALUE));
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

  const OffsetDays = LocalDateTime - UtcDateTime;
  const OffsetMinutes = Round(OffsetDays * MS_PER_DAY / MS_PER_MINUTE);

  Result := OffsetMinutes * MS_PER_MINUTE;
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
  const FirstOffset = LocalOffset(LocalTime);
  const FirstGuess = LocalTime - FirstOffset;
  const SecondOffset = LocalOffset(FirstGuess);

  Result := LocalTime - SecondOffset;
end;

class function TJSDateMath.CurrentTime: Double;
begin
  const UtcNow = TTimeZone.Local.ToUniversalTime(Now);

  const UnixSeconds = DateTimeToUnix(UtcNow, True);
  const Milliseconds = MilliSecondOf(UtcNow);

  Result := (UnixSeconds * MS_PER_SECOND) + Milliseconds;
end;

end.
