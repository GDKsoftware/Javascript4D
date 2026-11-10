unit JS4D.DateParser;

{$SCOPEDENUMS ON}

interface

type
  // Date.parse: the ES5 15.9.1.15 ISO format, plus the layouts that toString and toUTCString produce.
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
    function TryReadLegacyDate(const Tokens: TArray<string>; var Index: Integer): Boolean;
    function TryReadLegacyTime(const Token: string): Boolean;
    function TryReadLegacyOffset(const Token: string): Boolean;

    function IsValidDate: Boolean;
    function IsValidTime: Boolean;
    function ToTimeValue: Double;

    class function SplitLegacyTokens(const Text: string): TArray<string>; static;
    class function IndexOfName(const Names: array of string; const Token: string): Integer; static;
    class function TryParseInteger(const Token: string; out Value: Integer): Boolean; static;

  public
    class function Parse(const Text: string): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  JS4D.DateMath;

const
  MonthNames: array[0..11] of string = ('jan', 'feb', 'mar', 'apr', 'may', 'jun',
                                        'jul', 'aug', 'sep', 'oct', 'nov', 'dec');
  WeekDayNames: array[0..6] of string = ('sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat');
  NameLength = 3;
  YearDigitsPlain = 4;
  YearDigitsExtended = 6;
  TwoDigits = 2;
  MaxHour = 24;
  MaxMinuteOrSecond = 59;
  MinutesPerHour = 60;
  OffsetDigits = 4;
  UtcLabels: array[0..2] of string = ('GMT', 'UTC', 'Z');
  CommentStart = '(';
  FractionDigitsKept = 3;
  MinDay = 1;

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
  FDay := MinDay;
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
  Result := FPosition > Length(FText);
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
    if not CharInSet(Digit, ['0'..'9']) then
      Exit(False);

    Value := (Value * 10) + (Ord(Digit) - Ord('0'));
  end;

  Inc(FPosition, Count);
end;

function TJSDateParser.TryReadFraction(out Millisecond: Integer): Boolean;
begin
  Millisecond := 0;

  var DigitCount := 0;
  while (not IsAtEnd) and CharInSet(FText[FPosition], ['0'..'9']) do
  begin
    if DigitCount < FractionDigitsKept then
      Millisecond := (Millisecond * 10) + (Ord(FText[FPosition]) - Ord('0'));

    Inc(DigitCount);
    Inc(FPosition);
  end;

  Result := DigitCount > 0;
  if not Result then
    Exit;

  for var Missing := DigitCount + 1 to FractionDigitsKept do
  begin
    Millisecond := Millisecond * 10;
  end;
end;

function TJSDateParser.TryReadYear: Boolean;
begin
  var Magnitude: Integer;
  var Sign := 1;

  const HasExtendedYear = (not IsAtEnd) and CharInSet(FText[FPosition], ['+', '-']);
  if HasExtendedYear then
  begin
    if FText[FPosition] = '-' then
      Sign := -1;

    Inc(FPosition);
    Result := TryReadDigits(YearDigitsExtended, Magnitude);
    const IsNegativeZero = (Sign < 0) and (Magnitude = 0);
    Result := Result and (not IsNegativeZero);
  end
  else
  begin
    Result := TryReadDigits(YearDigitsPlain, Magnitude);
  end;

  FYear := Sign * Magnitude;
end;

function TJSDateParser.TryReadIsoDate: Boolean;
begin
  Result := TryReadYear;
  if not Result then
    Exit;

  if TryConsume('-') then
  begin
    var Month: Integer;
    Result := TryReadDigits(TwoDigits, Month);
    FMonth := Month - 1;

    const HasDay = Result and TryConsume('-');
    if HasDay then
      Result := TryReadDigits(TwoDigits, FDay);
  end;
end;

function TJSDateParser.TryReadIsoTime: Boolean;
begin
  FIsLocalTime := True;

  Result := TryReadDigits(TwoDigits, FHour) and TryConsume(':') and TryReadDigits(TwoDigits, FMinute);
  if not Result then
    Exit;

  if TryConsume(':') then
  begin
    Result := TryReadDigits(TwoDigits, FSecond);

    const HasFraction = Result and TryConsume('.');
    if HasFraction then
      Result := TryReadFraction(FMillisecond);
  end;
end;

function TJSDateParser.TryReadIsoOffset: Boolean;
begin
  Result := True;

  if TryConsume('Z') then
  begin
    FHasOffset := True;
    Exit;
  end;

  const HasSign = (not IsAtEnd) and CharInSet(FText[FPosition], ['+', '-']);
  if not HasSign then
    Exit;

  const Sign = IfThen(FText[FPosition] = '-', -1, 1);
  Inc(FPosition);

  var Hours: Integer;
  var Minutes: Integer;
  Result := TryReadDigits(TwoDigits, Hours) and TryConsume(':') and TryReadDigits(TwoDigits, Minutes);
  FHasOffset := True;
  FOffsetMinutes := Sign * ((Hours * MinutesPerHour) + Minutes);
end;

function TJSDateParser.TryParseIso: Boolean;
begin
  Result := TryReadIsoDate;
  if not Result then
    Exit;

  if TryConsume('T') then
  begin
    Result := TryReadIsoTime and TryReadIsoOffset;
  end;

  Result := Result and IsAtEnd and IsValidDate and IsValidTime;
end;

class function TJSDateParser.SplitLegacyTokens(const Text: string): TArray<string>;
begin
  var Visible := Text;
  const CommentIndex = Visible.IndexOf(CommentStart);
  if CommentIndex >= 0 then
    Visible := Visible.Substring(0, CommentIndex);

  Result := Visible.Split([' ', ','], TStringSplitOptions.ExcludeEmpty);
end;

class function TJSDateParser.IndexOfName(const Names: array of string; const Token: string): Integer;
begin
  Result := -1;

  const HasNameLength = Length(Token) >= NameLength;
  if not HasNameLength then
    Exit;

  const Prefix = Token.Substring(0, NameLength).ToLower;
  for var Index := 0 to High(Names) do
  begin
    if Names[Index] = Prefix then
      Exit(Index);
  end;
end;

class function TJSDateParser.TryParseInteger(const Token: string; out Value: Integer): Boolean;
begin
  Value := 0;

  var Start := 1;
  var Sign := 1;
  const HasSign = (Length(Token) > 1) and CharInSet(Token[1], ['+', '-']);
  if HasSign then
  begin
    Start := 2;
    if Token[1] = '-' then
      Sign := -1;
  end;

  Result := Start <= Length(Token);
  for var Position := Start to Length(Token) do
  begin
    if not CharInSet(Token[Position], ['0'..'9']) then
      Exit(False);

    Value := (Value * 10) + (Ord(Token[Position]) - Ord('0'));
  end;

  Value := Value * Sign;
end;

function TJSDateParser.TryReadLegacyDate(const Tokens: TArray<string>; var Index: Integer): Boolean;
begin
  Result := (Index + 2) < Length(Tokens);
  if not Result then
    Exit;

  const MonthFirst = IndexOfName(MonthNames, Tokens[Index]) >= 0;
  var DayToken: string;
  var MonthToken: string;
  if MonthFirst then
  begin
    MonthToken := Tokens[Index];
    DayToken := Tokens[Index + 1];
  end
  else
  begin
    DayToken := Tokens[Index];
    MonthToken := Tokens[Index + 1];
  end;

  var YearNumber: Integer;
  FMonth := IndexOfName(MonthNames, MonthToken);
  Result := (FMonth >= 0) and TryParseInteger(DayToken, FDay) and TryParseInteger(Tokens[Index + 2], YearNumber);
  FYear := YearNumber;
  Inc(Index, 3);
end;

function TJSDateParser.TryReadLegacyTime(const Token: string): Boolean;
begin
  const Parts = Token.Split([':']);
  const HasValidShape = (Length(Parts) = 2) or (Length(Parts) = 3);
  Result := HasValidShape and TryParseInteger(Parts[0], FHour) and TryParseInteger(Parts[1], FMinute);

  const HasSeconds = Result and (Length(Parts) = 3);
  if HasSeconds then
    Result := TryParseInteger(Parts[2], FSecond);
end;

function TJSDateParser.TryReadLegacyOffset(const Token: string): Boolean;
begin
  Result := False;

  for var UtcLabel in UtcLabels do
  begin
    if not Token.StartsWith(UtcLabel, True) then
      Continue;

    FHasOffset := True;
    const Remainder = Token.Substring(Length(UtcLabel));
    if Remainder.IsEmpty then
      Exit(True);

    var Signed: Integer;
    const HasValidDigits = (Length(Remainder) = OffsetDigits + 1) and TryParseInteger(Remainder, Signed);
    if not HasValidDigits then
      Exit(False);

    const Sign = IfThen(Signed < 0, -1, 1);
    FOffsetMinutes := Sign * (((Abs(Signed) div 100) * MinutesPerHour) + (Abs(Signed) mod 100));
    Exit(True);
  end;
end;

function TJSDateParser.TryParseLegacy: Boolean;
begin
  const Tokens = SplitLegacyTokens(FText);
  ResetFields;
  FIsLocalTime := True;

  var Index := 0;
  const HasWeekDay = (Length(Tokens) > 0) and (IndexOfName(WeekDayNames, Tokens[0]) >= 0);
  if HasWeekDay then
    Inc(Index);

  Result := TryReadLegacyDate(Tokens, Index);

  const HasTime = Result and (Index < Length(Tokens)) and Tokens[Index].Contains(':');
  if HasTime then
  begin
    Result := TryReadLegacyTime(Tokens[Index]);
    Inc(Index);
  end;

  const HasOffset = Result and (Index < Length(Tokens));
  if HasOffset then
  begin
    Result := TryReadLegacyOffset(Tokens[Index]);
    Inc(Index);
  end;

  Result := Result and (Index = Length(Tokens)) and IsValidDate and IsValidTime;
end;

function TJSDateParser.IsValidDate: Boolean;
begin
  const IsMonthValid = (FMonth >= 0) and (FMonth < 12);

  Result := IsMonthValid and (FDay >= MinDay) and (FDay <= TJSDateMath.DaysInMonth(FYear, FMonth));
end;

function TJSDateParser.IsValidTime: Boolean;
begin
  const IsEndOfDay = (FHour = MaxHour) and (FMinute = 0) and (FSecond = 0) and (FMillisecond = 0);
  const IsHourValid = (FHour >= 0) and ((FHour < MaxHour) or IsEndOfDay);

  Result := IsHourValid and
            (FMinute >= 0) and (FMinute <= MaxMinuteOrSecond) and
            (FSecond >= 0) and (FSecond <= MaxMinuteOrSecond);
end;

function TJSDateParser.ToTimeValue: Double;
begin
  const DayNumber = TJSDateMath.MakeDay(FYear, FMonth, FDay);
  const TimeOfDay = TJSDateMath.MakeTime(FHour, FMinute, FSecond, FMillisecond);
  var Time := TJSDateMath.MakeDate(DayNumber, TimeOfDay);

  if FHasOffset then
    Time := Time - (FOffsetMinutes * TJSDateMath.MsPerMinute)
  else if FIsLocalTime then
    Time := TJSDateMath.ToUtc(Time);

  Result := TJSDateMath.TimeClip(Time);
end;

end.
