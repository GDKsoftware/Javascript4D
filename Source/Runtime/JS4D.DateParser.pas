unit JS4D.DateParser;

{$SCOPEDENUMS ON}

interface

type
  TJSDateParser = class
  private
    FText: string;
    FPosition: Integer;
    FYear: Double;
    FMonth: Integer;
    FDay: Integer;
    FHour: Integer;
    FMinute: Integer;
    FSecond: Integer;
    FMillisecond: Integer;
    FIsLocalTime: Boolean;
    FHasOffset: Boolean;
    FOffsetMinutes: Integer;
    FTokenIndex: Integer;

    constructor Create(const Text: string);

    procedure ResetFields;
    function IsAtEnd: Boolean;
    function TryConsume(const Expected: Char): Boolean;
    function TryReadDigits(const Count: Integer; out Value: Integer): Boolean;
    function TryReadFraction(out Millisecond: Integer): Boolean;
    function TryReadYear: Boolean;
    function TryReadIsoDate: Boolean;
    function TryReadIsoTime: Boolean;
    function TryReadIsoOffset: Boolean;
    function TryParseIso: Boolean;

    function TryParseLegacy: Boolean;
    function TryReadLegacyDate(const Tokens: TArray<string>): Boolean;
    function TryReadLegacyTime(const Token: string): Boolean;
    function TryReadLegacyOffset(const Token: string): Boolean;

    function IsValidDate: Boolean;
    function IsValidTime: Boolean;
    function ToTimeValue: Double;

    class function SplitLegacyTokens(const Text: string): TArray<string>; static;
    class function IndexOfName(const Names: array of string; const Token: string): Integer; static;
    class function TryParseInteger(const Token: string; out Value: Integer): Boolean; static;
    class function AppendDigit(const Value: Integer; const Digit: Char): Integer; static;

  public
    class function Parse(const Text: string): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  JS4D.DateMath;

const
  NAME_LENGTH = 3;
  YEAR_DIGITS_PLAIN = 4;
  YEAR_DIGITS_EXTENDED = 6;
  TWO_DIGITS = 2;
  MAX_HOUR = 24;
  MAX_MINUTE_OR_SECOND = 59;
  OFFSET_DIGITS = 4;
  OFFSET_HOUR_DIVISOR = 100;
  UTC_DESIGNATOR = 'Z';
  UTC_LABELS: array[0..2] of string = ('GMT', 'UTC', UTC_DESIGNATOR);
  TIME_DESIGNATOR = 'T';
  FRACTION_SEPARATOR = '.';
  COMMENT_START = '(';
  FRACTION_DIGITS_KEPT = 3;
  MIN_DAY = 1;
  DECIMAL_BASE = 10;
  TIME_SEPARATOR = ':';
  MINUS_SIGN = '-';
  DATE_SEPARATOR = MINUS_SIGN;
  ZERO_DIGIT = '0';
  SIGN_CHARS: TSysCharSet = ['+', '-'];
  DIGIT_CHARS: TSysCharSet = ['0'..'9'];

constructor TJSDateParser.Create(const Text: string);
begin
  inherited Create;
  FText := Text.Trim;
  FPosition := 1;
  ResetFields;
end;

procedure TJSDateParser.ResetFields;
begin
  FYear := 0;
  FMonth := 0;
  FDay := MIN_DAY;
  FHour := 0;
  FMinute := 0;
  FSecond := 0;
  FMillisecond := 0;
  FIsLocalTime := False;
  FHasOffset := False;
  FOffsetMinutes := 0;
end;

class function TJSDateParser.Parse(const Text: string): Double;
begin
  const Parser = TJSDateParser.Create(Text);
  try
    const IsParsed = Parser.TryParseIso or Parser.TryParseLegacy;
    if IsParsed then
      Result := Parser.ToTimeValue
    else
      Result := System.Math.NaN;
  finally
    Parser.Free;
  end;
end;

function TJSDateParser.IsAtEnd: Boolean;
begin
  Result := (FPosition > Length(FText));
end;

function TJSDateParser.TryConsume(const Expected: Char): Boolean;
begin
  Result := (not IsAtEnd) and (FText[FPosition] = Expected);

  if Result then
    Inc(FPosition);
end;

function TJSDateParser.TryReadDigits(const Count: Integer; out Value: Integer): Boolean;
begin
  Value := 0;
  Result := (FPosition + Count - 1) <= Length(FText);
  if not Result then
    Exit;

  for var Offset := 0 to Count - 1 do
  begin
    const Digit = FText[FPosition + Offset];
    if not CharInSet(Digit, DIGIT_CHARS) then
      Exit(False);

    Value := AppendDigit(Value, Digit);
  end;

  Inc(FPosition, Count);
end;

function TJSDateParser.TryReadFraction(out Millisecond: Integer): Boolean;
begin
  Millisecond := 0;

  var DigitCount := 0;
  while (not IsAtEnd) and CharInSet(FText[FPosition], DIGIT_CHARS) do
  begin
    if DigitCount < FRACTION_DIGITS_KEPT then
      Millisecond := AppendDigit(Millisecond, FText[FPosition]);

    Inc(DigitCount);
    Inc(FPosition);
  end;

  Result := (DigitCount > 0);
  if not Result then
    Exit;

  const MissingDigits = FRACTION_DIGITS_KEPT - DigitCount;
  const HasMissingDigits = (MissingDigits > 0);
  if HasMissingDigits then
    Millisecond := Millisecond * Round(IntPower(DECIMAL_BASE, MissingDigits));
end;

function TJSDateParser.TryReadYear: Boolean;
begin
  var Magnitude: Integer;
  var Sign := 1;

  const HasExtendedYear = (not IsAtEnd) and CharInSet(FText[FPosition], SIGN_CHARS);
  if HasExtendedYear then
  begin
    if FText[FPosition] = MINUS_SIGN then
      Sign := -1;

    Inc(FPosition);
    Result := TryReadDigits(YEAR_DIGITS_EXTENDED, Magnitude);
    const IsNegativeZero = (Sign < 0) and (Magnitude = 0);
    Result := Result and (not IsNegativeZero);
  end
  else
  begin
    Result := TryReadDigits(YEAR_DIGITS_PLAIN, Magnitude);
  end;

  FYear := Sign * Magnitude;
end;

function TJSDateParser.TryReadIsoDate: Boolean;
begin
  Result := TryReadYear;
  if not Result then
    Exit;

  if TryConsume(DATE_SEPARATOR) then
  begin
    var Month: Integer;
    Result := TryReadDigits(TWO_DIGITS, Month);
    FMonth := Month - 1;

    const HasDay = Result and TryConsume(DATE_SEPARATOR);
    if HasDay then
      Result := TryReadDigits(TWO_DIGITS, FDay);
  end;
end;

function TJSDateParser.TryReadIsoTime: Boolean;
begin
  FIsLocalTime := True;

  Result := TryReadDigits(TWO_DIGITS, FHour) and TryConsume(TIME_SEPARATOR) and TryReadDigits(TWO_DIGITS, FMinute);
  if not Result then
    Exit;

  if TryConsume(TIME_SEPARATOR) then
  begin
    Result := TryReadDigits(TWO_DIGITS, FSecond);

    const HasFraction = Result and TryConsume(FRACTION_SEPARATOR);
    if HasFraction then
      Result := TryReadFraction(FMillisecond);
  end;
end;

function TJSDateParser.TryReadIsoOffset: Boolean;
begin
  Result := True;

  if TryConsume(UTC_DESIGNATOR) then
  begin
    FHasOffset := True;
    Exit;
  end;

  const HasSign = (not IsAtEnd) and CharInSet(FText[FPosition], SIGN_CHARS);
  if not HasSign then
    Exit;

  const IsNegativeOffset = (FText[FPosition] = MINUS_SIGN);
  const Sign = IfThen(IsNegativeOffset, -1, 1);
  Inc(FPosition);

  var Hours := 0;
  var Minutes := 0;
  Result := TryReadDigits(TWO_DIGITS, Hours) and TryConsume(TIME_SEPARATOR) and TryReadDigits(TWO_DIGITS, Minutes);
  FHasOffset := True;
  if Result then
    FOffsetMinutes := Sign * ((Hours * TJSDateMath.MINUTES_PER_HOUR) + Minutes);
end;

function TJSDateParser.TryParseIso: Boolean;
begin
  Result := TryReadIsoDate;
  if not Result then
    Exit;

  if TryConsume(TIME_DESIGNATOR) then
  begin
    Result := TryReadIsoTime and TryReadIsoOffset;
  end;

  Result := Result and IsAtEnd and IsValidDate and IsValidTime;
end;

class function TJSDateParser.SplitLegacyTokens(const Text: string): TArray<string>;
begin
  var Visible := Text;
  const CommentIndex = Visible.IndexOf(COMMENT_START);
  if CommentIndex >= 0 then
    Visible := Visible.Substring(0, CommentIndex);

  Result := Visible.Split([' ', ','], TStringSplitOptions.ExcludeEmpty);
end;

class function TJSDateParser.IndexOfName(const Names: array of string; const Token: string): Integer;
begin
  Result := -1;

  const HasNameLength = (Length(Token) >= NAME_LENGTH);
  if not HasNameLength then
    Exit;

  const Prefix = Token.Substring(0, NAME_LENGTH).ToLower;
  for var Index := 0 to High(Names) do
  begin
    const NameMatches = (Names[Index].ToLower = Prefix);
    if NameMatches then
      Exit(Index);
  end;
end;

class function TJSDateParser.AppendDigit(const Value: Integer; const Digit: Char): Integer;
begin
  Result := (Value * DECIMAL_BASE) + (Ord(Digit) - Ord(ZERO_DIGIT));
end;

class function TJSDateParser.TryParseInteger(const Token: string; out Value: Integer): Boolean;
begin
  Value := 0;

  var Start := 1;
  var Sign := 1;
  const HasSign = (Length(Token) > 1) and CharInSet(Token[1], SIGN_CHARS);
  if HasSign then
  begin
    Start := 2;
    if Token[1] = MINUS_SIGN then
      Sign := -1;
  end;

  Result := (Start <= Length(Token));
  for var Position := Start to Length(Token) do
  begin
    if not CharInSet(Token[Position], DIGIT_CHARS) then
      Exit(False);

    Value := AppendDigit(Value, Token[Position]);
  end;

  Value := Value * Sign;
end;

function TJSDateParser.TryReadLegacyDate(const Tokens: TArray<string>): Boolean;
begin
  Result := (FTokenIndex + 2) < Length(Tokens);
  if not Result then
    Exit;

  const FirstToken = Tokens[FTokenIndex];
  const SecondToken = Tokens[FTokenIndex + 1];
  const YearToken = Tokens[FTokenIndex + 2];

  const MonthFirst = (IndexOfName(TJSDateMath.MONTH_NAMES, FirstToken) >= 0);
  var DayToken := FirstToken;
  var MonthToken := SecondToken;
  if MonthFirst then
  begin
    MonthToken := FirstToken;
    DayToken := SecondToken;
  end;

  var YearNumber := 0;
  FMonth := IndexOfName(TJSDateMath.MONTH_NAMES, MonthToken);
  Result := (FMonth >= 0) and TryParseInteger(DayToken, FDay) and TryParseInteger(YearToken, YearNumber);
  if not Result then
    Exit;

  FYear := YearNumber;
  Inc(FTokenIndex, 3);
end;

function TJSDateParser.TryReadLegacyTime(const Token: string): Boolean;
begin
  const Parts = Token.Split([TIME_SEPARATOR]);
  const PartCount = Length(Parts);
  const HasSecondsPart = (PartCount = 3);
  const HasValidShape = (PartCount = 2) or HasSecondsPart;
  Result := HasValidShape and TryParseInteger(Parts[0], FHour) and TryParseInteger(Parts[1], FMinute);

  const HasSeconds = Result and HasSecondsPart;
  if HasSeconds then
    Result := TryParseInteger(Parts[2], FSecond);
end;

function TJSDateParser.TryReadLegacyOffset(const Token: string): Boolean;
begin
  Result := False;

  for var UtcLabel in UTC_LABELS do
  begin
    if not Token.StartsWith(UtcLabel, True) then
      Continue;

    FHasOffset := True;
    const Remainder = Token.Substring(Length(UtcLabel));
    if Remainder.IsEmpty then
      Exit(True);

    var Signed: Integer;
    const HasValidDigits = (Length(Remainder) = OFFSET_DIGITS + 1) and TryParseInteger(Remainder, Signed);
    if not HasValidDigits then
      Exit(False);

    const Sign = IfThen(Signed < 0, -1, 1);
    const Magnitude = Abs(Signed);
    const Hours = Magnitude div OFFSET_HOUR_DIVISOR;
    const Minutes = Magnitude mod OFFSET_HOUR_DIVISOR;
    FOffsetMinutes := Sign * ((Hours * TJSDateMath.MINUTES_PER_HOUR) + Minutes);
    Exit(True);
  end;
end;

function TJSDateParser.TryParseLegacy: Boolean;
begin
  const Tokens = SplitLegacyTokens(FText);
  ResetFields;
  FIsLocalTime := True;

  FTokenIndex := 0;
  const HasTokens = (Length(Tokens) > 0);
  const HasWeekDay = HasTokens and (IndexOfName(TJSDateMath.WEEK_DAY_NAMES, Tokens[0]) >= 0);
  if HasWeekDay then
    Inc(FTokenIndex);

  Result := TryReadLegacyDate(Tokens);

  const HasTime = Result and (FTokenIndex < Length(Tokens)) and Tokens[FTokenIndex].Contains(TIME_SEPARATOR);
  if HasTime then
  begin
    Result := TryReadLegacyTime(Tokens[FTokenIndex]);
    Inc(FTokenIndex);
  end;

  const HasOffset = Result and (FTokenIndex < Length(Tokens));
  if HasOffset then
  begin
    Result := TryReadLegacyOffset(Tokens[FTokenIndex]);
    Inc(FTokenIndex);
  end;

  const IsFullyConsumed = (FTokenIndex = Length(Tokens));
  Result := Result and IsFullyConsumed and IsValidDate and IsValidTime;
end;

function TJSDateParser.IsValidDate: Boolean;
begin
  const IsMonthValid = (FMonth >= 0) and (FMonth < TJSDateMath.MONTHS_PER_YEAR);
  if not IsMonthValid then
    Exit(False);

  const LastDay = TJSDateMath.DaysInMonth(FYear, FMonth);

  Result := (FDay >= MIN_DAY) and (FDay <= LastDay);
end;

function TJSDateParser.IsValidTime: Boolean;
begin
  const IsEndOfDay = (FHour = MAX_HOUR) and (FMinute = 0) and (FSecond = 0) and (FMillisecond = 0);
  const IsHourValid = (FHour >= 0) and ((FHour < MAX_HOUR) or IsEndOfDay);

  Result := IsHourValid and
            (FMinute >= 0) and (FMinute <= MAX_MINUTE_OR_SECOND) and
            (FSecond >= 0) and (FSecond <= MAX_MINUTE_OR_SECOND);
end;

function TJSDateParser.ToTimeValue: Double;
begin
  const DayNumber = TJSDateMath.MakeDay(FYear, FMonth, FDay);
  const TimeOfDay = TJSDateMath.MakeTime(FHour, FMinute, FSecond, FMillisecond);
  var Time := TJSDateMath.MakeDate(DayNumber, TimeOfDay);

  if FHasOffset then
    Time := Time - (FOffsetMinutes * TJSDateMath.MS_PER_MINUTE)
  else if FIsLocalTime then
    Time := TJSDateMath.ToUtc(Time);

  Result := TJSDateMath.TimeClip(Time);
end;

end.
