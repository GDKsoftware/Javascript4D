unit JS4D.RegExpSyntax;

{$SCOPEDENUMS ON}

interface

type
  TJSRegExpSyntax = class
  private
    FPattern: string;
    FPosition: Integer;
    FIsUnicode: Boolean;
    FLine: Integer;
    FColumn: Integer;

    constructor Create(const Pattern: string; const Flags: string; const Line: Integer; const Column: Integer);

    function IsAtEnd: Boolean;
    function Current: Char;
    function PeekAt(const Offset: Integer): Char;
    function LooksLike(const Text: string): Boolean;
    procedure Fail;
    procedure Expect(const Expected: Char);

    procedure ParseDisjunction;
    procedure ParseAlternative;
    procedure ParseTerm;
    function ParseGroup: Boolean;
    procedure ParseGroupName;
    procedure ParseEscape;
    procedure ParseQuantifier;
    function ScanBracedQuantifier(const Consume: Boolean): Boolean;
    function ReadDigits: Int64;
    procedure ParseClass;
    procedure ParseClassRange;
    function ParseClassAtom(out IsSet: Boolean): Integer;
    function ParseClassEscape(out IsSet: Boolean): Integer;
    function ParseHexEscape(const Digits: Integer; const Fallback: Integer): Integer;
    function ParseControlEscape: Integer;
    function ParseOctalEscape: Integer;
    function IsHexDigitAt(const Offset: Integer): Boolean;

    procedure Validate;

    class function LineTerminatorEscape(const Character: Char): string; static;
    class function EscapedCharacter(const Character: Char; const InClass: Boolean): string; static;
    class function EscapedPair(const Character: Char): string; static;
  public
    class procedure ValidatePattern(const Pattern: string; const Flags: string; const Line: Integer = 0; const Column: Integer = 0);
    class procedure ValidateFlags(const Flags: string; const Line: Integer = 0; const Column: Integer = 0);
    class function EscapePattern(const Pattern: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  JS4D.Errors;

const
  ValidFlagCharacters = 'gimuy';
  EmptyPatternSource = '(?:)';
  ClassSetEscapes = 'dDsSwW';
  BackspaceCode = 8;
  InvalidFlagsMessage = 'Invalid regular expression flags: %s';
  SaturatedQuantifierBound = 100000000000000000;

constructor TJSRegExpSyntax.Create(const Pattern: string; const Flags: string; const Line: Integer; const Column: Integer);
begin
  inherited Create;
  FPattern := Pattern;
  FIsUnicode := (Pos('u', Flags) > 0);
  FPosition := 1;
  FLine := Line;
  FColumn := Column;
end;

class procedure TJSRegExpSyntax.ValidatePattern(const Pattern: string; const Flags: string; const Line: Integer; const Column: Integer);
begin
  const Checker = TJSRegExpSyntax.Create(Pattern, Flags, Line, Column);
  try
    Checker.Validate;
  finally
    Checker.Free;
  end;
end;

class procedure TJSRegExpSyntax.ValidateFlags(const Flags: string; const Line: Integer; const Column: Integer);
begin
  for var Index := 1 to Length(Flags) do
  begin
    const Flag = Flags[Index];
    const IsKnown = (Pos(Flag, ValidFlagCharacters) > 0);
    const IsRepeated = (Pos(Flag, Flags) < Index);

    if (not IsKnown) or IsRepeated then
    begin
      const Message = Format(InvalidFlagsMessage, [Flags]);
      raise TJSErrorFactory.SyntaxError(Message, Line, Column);
    end;
  end;
end;

class function TJSRegExpSyntax.LineTerminatorEscape(const Character: Char): string;
begin
  case Character of
    #10    : Result := '\n';
    #13    : Result := '\r';
    #$2028 : Result := '\u2028';
    #$2029 : Result := '\u2029';
  else
    Result := '';
  end;
end;

class function TJSRegExpSyntax.EscapedCharacter(const Character: Char; const InClass: Boolean): string;
begin
  const LineTerminator = LineTerminatorEscape(Character);
  if not LineTerminator.IsEmpty then
    Exit(LineTerminator);

  const IsBareSlash = (Character = '/') and (not InClass);
  if IsBareSlash then
    Exit('\/');

  Result := Character;
end;

class function TJSRegExpSyntax.EscapedPair(const Character: Char): string;
begin
  const LineTerminator = LineTerminatorEscape(Character);
  if not LineTerminator.IsEmpty then
    Exit(LineTerminator);

  Result := '\' + Character;
end;

class function TJSRegExpSyntax.EscapePattern(const Pattern: string): string;
begin
  if Pattern.IsEmpty then
    Exit(EmptyPatternSource);

  var Escaped := TStringBuilder.Create;
  try
    var InClass := False;
    var Index := 1;
    while Index <= Length(Pattern) do
    begin
      const Character = Pattern[Index];
      const IsEscapePair = (Character = '\') and (Index < Length(Pattern));

      if IsEscapePair then
      begin
        Inc(Index);
        Escaped.Append(EscapedPair(Pattern[Index]));
      end
      else
      begin
        InClass := (InClass or (Character = '[')) and (Character <> ']');
        Escaped.Append(EscapedCharacter(Character, InClass));
      end;

      Inc(Index);
    end;

    Result := Escaped.ToString;
  finally
    Escaped.Free;
  end;
end;

procedure TJSRegExpSyntax.Validate;
begin
  ParseDisjunction;

  if not IsAtEnd then
    Fail;
end;

function TJSRegExpSyntax.IsAtEnd: Boolean;
begin
  Result := (FPosition > Length(FPattern));
end;

function TJSRegExpSyntax.Current: Char;
begin
  Result := PeekAt(0);
end;

function TJSRegExpSyntax.PeekAt(const Offset: Integer): Char;
begin
  const Index = FPosition + Offset;
  const IsInside = (Index >= 1) and (Index <= Length(FPattern));

  if IsInside then
    Result := FPattern[Index]
  else
    Result := #0;
end;

function TJSRegExpSyntax.LooksLike(const Text: string): Boolean;
begin
  Result := (Copy(FPattern, FPosition, Length(Text)) = Text);
end;

procedure TJSRegExpSyntax.Fail;
begin
  raise TJSErrorFactory.InvalidRegExp(FPattern, FLine, FColumn);
end;

procedure TJSRegExpSyntax.Expect(const Expected: Char);
begin
  const IsExpected = (not IsAtEnd) and (Current = Expected);
  if not IsExpected then
    Fail;

  Inc(FPosition);
end;

procedure TJSRegExpSyntax.ParseDisjunction;
begin
  ParseAlternative;

  while (not IsAtEnd) and (Current = '|') do
  begin
    Inc(FPosition);
    ParseAlternative;
  end;
end;

procedure TJSRegExpSyntax.ParseAlternative;
begin
  while (not IsAtEnd) and (Current <> '|') and (Current <> ')') do
  begin
    ParseTerm;
  end;
end;

procedure TJSRegExpSyntax.ParseTerm;
begin
  var IsQuantifiable := True;

  case Current of
    '^', '$':
      begin
        Inc(FPosition);
        IsQuantifiable := False;
      end;

    '\':
      begin
        const IsBoundary = CharInSet(PeekAt(1), ['b', 'B']);
        if IsBoundary then
        begin
          Inc(FPosition, 2);
          IsQuantifiable := False;
        end
        else
        begin
          ParseEscape;
        end;
      end;

    '(':
      IsQuantifiable := ParseGroup;

    '[':
      ParseClass;

    '*', '+', '?':
      Fail;

    '{':
      begin
        if ScanBracedQuantifier(False) then
          Fail;

        Inc(FPosition);
      end;
  else
    Inc(FPosition);
  end;

  if IsQuantifiable then
    ParseQuantifier
  else if CharInSet(Current, ['*', '+', '?']) then
    Fail
  else if (Current = '{') and ScanBracedQuantifier(False) then
    Fail;
end;

function TJSRegExpSyntax.ParseGroup: Boolean;
begin
  Result := True;

  if LooksLike('(?=') or LooksLike('(?!') or LooksLike('(?:') then
  begin
    Inc(FPosition, 3);
  end
  else if LooksLike('(?<=') or LooksLike('(?<!') then
  begin
    Inc(FPosition, 4);
    Result := False;
  end
  else if LooksLike('(?<') then
  begin
    ParseGroupName;
  end
  else if LooksLike('(?') then
  begin
    Fail;
  end
  else
  begin
    Inc(FPosition);
  end;

  ParseDisjunction;
  Expect(')');
end;

procedure TJSRegExpSyntax.ParseGroupName;
begin
  Inc(FPosition, 3);

  const Remainder = Copy(FPattern, FPosition, MaxInt);
  const NameLength = Pos('>', Remainder) - 1;
  const IsNamed = (NameLength > 0);
  if not IsNamed then
    Fail;

  Inc(FPosition, NameLength + 1);
end;

procedure TJSRegExpSyntax.ParseEscape;
begin
  Inc(FPosition);

  if IsAtEnd then
    Fail;

  Inc(FPosition);
end;

procedure TJSRegExpSyntax.ParseQuantifier;
begin
  case Current of
    '*', '+', '?':
      Inc(FPosition);
    '{':
      if not ScanBracedQuantifier(True) then
        Exit;
  else
    Exit;
  end;

  if Current = '?' then
    Inc(FPosition);

  if CharInSet(Current, ['*', '+', '?']) then
    Fail;
end;

function TJSRegExpSyntax.ReadDigits: Int64;
begin
  Result := 0;

  while CharInSet(Current, ['0'..'9']) do
  begin
    if Result < SaturatedQuantifierBound then
      Result := (Result * 10) + (Ord(Current) - Ord('0'));

    Inc(FPosition);
  end;
end;

function TJSRegExpSyntax.ScanBracedQuantifier(const Consume: Boolean): Boolean;
begin
  Result := False;
  const StartPosition = FPosition;
  try
    Inc(FPosition);

    const HasMinimum = CharInSet(Current, ['0'..'9']);
    if not HasMinimum then
      Exit;

    const Minimum = ReadDigits;
    var Maximum := Minimum;

    if Current = ',' then
    begin
      Inc(FPosition);

      const HasMaximum = CharInSet(Current, ['0'..'9']);
      if HasMaximum then
        Maximum := ReadDigits
      else
        Maximum := High(Int64);
    end;

    if Current <> '}' then
      Exit;

    Inc(FPosition);

    if Minimum > Maximum then
      Fail;

    Result := True;
  finally
    if (not Result) or (not Consume) then
      FPosition := StartPosition;
  end;
end;

procedure TJSRegExpSyntax.ParseClass;
begin
  Inc(FPosition);

  if Current = '^' then
    Inc(FPosition);

  while (not IsAtEnd) and (Current <> ']') do
  begin
    ParseClassRange;
  end;

  Expect(']');
end;

procedure TJSRegExpSyntax.ParseClassRange;
begin
  var StartIsSet: Boolean;
  const StartCode = ParseClassAtom(StartIsSet);

  const IsRange = (Current = '-') and (PeekAt(1) <> ']') and (FPosition < Length(FPattern));
  if not IsRange then
    Exit;

  Inc(FPosition);

  var EndIsSet: Boolean;
  const EndCode = ParseClassAtom(EndIsSet);

  const HasSet = StartIsSet or EndIsSet;
  const IsOutOfOrder = (StartCode > EndCode);
  if (not HasSet) and IsOutOfOrder then
    Fail;
end;

function TJSRegExpSyntax.ParseClassAtom(out IsSet: Boolean): Integer;
begin
  IsSet := False;

  if Current = '\' then
  begin
    Result := ParseClassEscape(IsSet);
    Exit;
  end;

  Result := Ord(Current);

  const LowSurrogate = PeekAt(1);
  const IsSurrogatePair = FIsUnicode and Current.IsHighSurrogate and LowSurrogate.IsLowSurrogate;
  if IsSurrogatePair then
  begin
    Result := Char.ConvertToUtf32(Current, LowSurrogate);
    Inc(FPosition);
  end;

  Inc(FPosition);
end;

function TJSRegExpSyntax.ParseClassEscape(out IsSet: Boolean): Integer;
begin
  IsSet := False;
  Inc(FPosition);

  if IsAtEnd then
    Fail;

  const Escaped = Current;

  if Pos(Escaped, ClassSetEscapes) > 0 then
  begin
    IsSet := True;
    Inc(FPosition);
    Exit(0);
  end;

  case Escaped of
    'b':
      begin
        Inc(FPosition);
        Result := BackspaceCode;
      end;
    't':
      begin
        Inc(FPosition);
        Result := 9;
      end;
    'n':
      begin
        Inc(FPosition);
        Result := 10;
      end;
    'v':
      begin
        Inc(FPosition);
        Result := 11;
      end;
    'f':
      begin
        Inc(FPosition);
        Result := 12;
      end;
    'r':
      begin
        Inc(FPosition);
        Result := 13;
      end;
    'x':
      Result := ParseHexEscape(2, Ord('x'));
    'u':
      Result := ParseHexEscape(4, Ord('u'));
    'c':
      Result := ParseControlEscape;
    '0'..'7':
      Result := ParseOctalEscape;
  else
    begin
      Inc(FPosition);
      Result := Ord(Escaped);
    end;
  end;
end;

function TJSRegExpSyntax.IsHexDigitAt(const Offset: Integer): Boolean;
begin
  Result := CharInSet(PeekAt(Offset), ['0'..'9', 'a'..'f', 'A'..'F']);
end;

function TJSRegExpSyntax.ParseHexEscape(const Digits: Integer; const Fallback: Integer): Integer;
begin
  for var Offset := 1 to Digits do
  begin
    if not IsHexDigitAt(Offset) then
    begin
      Inc(FPosition);
      Exit(Fallback);
    end;
  end;

  const HexText = Copy(FPattern, FPosition + 1, Digits);
  Result := StrToInt(Format('$%s', [HexText]));
  Inc(FPosition, Digits + 1);
end;

function TJSRegExpSyntax.ParseControlEscape: Integer;
begin
  const Letter = PeekAt(1);
  const IsLetter = CharInSet(Letter, ['a'..'z', 'A'..'Z']);

  if IsLetter then
  begin
    Result := Ord(Letter) mod 32;
    Inc(FPosition, 2);
  end
  else
  begin
    Result := Ord('\');
  end;
end;

function TJSRegExpSyntax.ParseOctalEscape: Integer;
begin
  Result := 0;
  var DigitCount := 0;

  while (DigitCount < 3) and CharInSet(Current, ['0'..'7']) and ((Result * 8) + (Ord(Current) - Ord('0')) <= 255) do
  begin
    Result := (Result * 8) + (Ord(Current) - Ord('0'));
    Inc(FPosition);
    Inc(DigitCount);
  end;
end;

end.
