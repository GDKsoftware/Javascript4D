unit JS4D.RegExpSyntax;

{$SCOPEDENUMS ON}

interface

type
  TJSRegExpSyntax = class
  private
    FPattern: string;
    FPosition: Integer;
    FIsUnicode: Boolean;
    FGroupCount: Integer;
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
    procedure ParseStrictAtomEscape;
    procedure ParseDecimalEscape;
    procedure ParseNamedReference;
    procedure ParsePropertyEscape;
    function CountCaptureGroups: Integer;
    function IsCapturingGroupAt(const Index: Integer): Boolean;
    function ParseClassEscape(out IsSet: Boolean): Integer;
    function ParseUnicodeEscape: Integer;
    function ParseBracedCodePoint: Integer;
    function TryReadTrailSurrogateEscape(out Trail: Integer): Boolean;
    function ParseStrictNullEscape: Integer;
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
  SyntaxCharacters = '^$\.*+?()[]{}|/-';
  MaxCodePoint = $10FFFF;

constructor TJSRegExpSyntax.Create(const Pattern: string; const Flags: string; const Line: Integer; const Column: Integer);
begin
  inherited Create;
  FPattern := Pattern;
  FIsUnicode := (Pos('u', Flags) > 0);
  FGroupCount := 0;
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
  if FIsUnicode then
    FGroupCount := CountCaptureGroups;

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
        if FIsUnicode or ScanBracedQuantifier(False) then
          Fail;

        Inc(FPosition);
      end;

    '}', ']':
      begin
        if FIsUnicode then
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

  if LooksLike('(?=') or LooksLike('(?!') then
  begin
    Inc(FPosition, 3);
    Result := not FIsUnicode;
  end
  else if LooksLike('(?:') then
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
  if FIsUnicode then
  begin
    ParseStrictAtomEscape;
    Exit;
  end;

  Inc(FPosition);

  if IsAtEnd then
    Fail;

  Inc(FPosition);
end;

procedure TJSRegExpSyntax.ParseStrictAtomEscape;
begin
  const Escaped = PeekAt(1);

  if Escaped = '-' then
  begin
    Fail;
  end
  else if CharInSet(Escaped, ['0'..'9']) then
  begin
    ParseDecimalEscape;
  end
  else if Escaped = 'k' then
  begin
    ParseNamedReference;
  end
  else if CharInSet(Escaped, ['p', 'P']) then
  begin
    ParsePropertyEscape;
  end
  else
  begin
    var IsSet: Boolean;
    ParseClassEscape(IsSet);
  end;
end;

procedure TJSRegExpSyntax.ParseDecimalEscape;
begin
  Inc(FPosition);

  if Current = '0' then
  begin
    Inc(FPosition);

    if CharInSet(Current, ['0'..'9']) then
      Fail;

    Exit;
  end;

  const Reference = ReadDigits;
  if Reference > FGroupCount then
    Fail;
end;

procedure TJSRegExpSyntax.ParseNamedReference;
begin
  Inc(FPosition, 2);
  Expect('<');

  const Remainder = Copy(FPattern, FPosition, MaxInt);
  const NameLength = Pos('>', Remainder) - 1;
  const IsNamed = (NameLength > 0);
  if not IsNamed then
    Fail;

  Inc(FPosition, NameLength + 1);
end;

procedure TJSRegExpSyntax.ParsePropertyEscape;
begin
  Inc(FPosition, 2);
  Expect('{');

  const Remainder = Copy(FPattern, FPosition, MaxInt);
  const NameLength = Pos('}', Remainder) - 1;
  const IsNamed = (NameLength > 0);
  if not IsNamed then
    Fail;

  Inc(FPosition, NameLength + 1);
end;

function TJSRegExpSyntax.CountCaptureGroups: Integer;
begin
  Result := 0;
  var Index := 1;
  var IsInClass := False;

  while Index <= Length(FPattern) do
  begin
    const Character = FPattern[Index];

    if Character = '\' then
    begin
      Inc(Index);
    end
    else if IsInClass then
    begin
      IsInClass := (Character <> ']');
    end
    else if Character = '[' then
    begin
      IsInClass := True;
    end
    else if (Character = '(') and IsCapturingGroupAt(Index) then
    begin
      Inc(Result);
    end;

    Inc(Index);
  end;
end;

function TJSRegExpSyntax.IsCapturingGroupAt(const Index: Integer): Boolean;
begin
  const Opening = Copy(FPattern, Index, 4);
  const IsPlain = not Opening.StartsWith('(?');
  const IsLookbehind = Opening.StartsWith('(?<=') or Opening.StartsWith('(?<!');
  const IsNamed = Opening.StartsWith('(?<') and not IsLookbehind;

  Result := IsPlain or IsNamed;
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
  if HasSet and FIsUnicode then
    Fail;

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
      Result := ParseUnicodeEscape;
    'c':
      Result := ParseControlEscape;
    '0'..'7':
      begin
        if FIsUnicode then
          Result := ParseStrictNullEscape
        else
          Result := ParseOctalEscape;
      end;
  else
    begin
      const IsSyntaxCharacter = (Pos(Escaped, SyntaxCharacters) > 0);
      if FIsUnicode and not IsSyntaxCharacter then
        Fail;

      Inc(FPosition);
      Result := Ord(Escaped);
    end;
  end;
end;

function TJSRegExpSyntax.ParseUnicodeEscape: Integer;
begin
  const IsBraced = FIsUnicode and (PeekAt(1) = '{');
  if IsBraced then
    Exit(ParseBracedCodePoint);

  Result := ParseHexEscape(4, Ord('u'));

  const IsLeadSurrogate = FIsUnicode and (Result >= $D800) and (Result <= $DBFF);
  if not IsLeadSurrogate then
    Exit;

  var Trail: Integer;
  if TryReadTrailSurrogateEscape(Trail) then
    Result := $10000 + ((Result - $D800) shl 10) + (Trail - $DC00);
end;

function TJSRegExpSyntax.ParseBracedCodePoint: Integer;
begin
  Inc(FPosition, 2);
  Result := 0;
  var DigitCount := 0;

  while IsHexDigitAt(0) do
  begin
    Result := (Result * 16) + StrToInt(Format('$%s', [Current]));

    if Result > MaxCodePoint then
      Fail;

    Inc(DigitCount);
    Inc(FPosition);
  end;

  const IsComplete = (DigitCount > 0) and (Current = '}');
  if not IsComplete then
    Fail;

  Inc(FPosition);
end;

function TJSRegExpSyntax.TryReadTrailSurrogateEscape(out Trail: Integer): Boolean;
begin
  Result := False;
  Trail := 0;

  const IsEscape = (Current = '\') and (PeekAt(1) = 'u');
  if not IsEscape then
    Exit;

  for var Offset := 2 to 5 do
  begin
    if not IsHexDigitAt(Offset) then
      Exit;
  end;

  Trail := StrToInt(Format('$%s', [Copy(FPattern, FPosition + 2, 4)]));
  Result := (Trail >= $DC00) and (Trail <= $DFFF);

  if Result then
    Inc(FPosition, 6);
end;

function TJSRegExpSyntax.ParseStrictNullEscape: Integer;
begin
  const IsNull = (Current = '0') and not CharInSet(PeekAt(1), ['0'..'9']);
  if not IsNull then
    Fail;

  Inc(FPosition);
  Result := 0;
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
      if FIsUnicode then
        Fail;

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
    if FIsUnicode then
      Fail;

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
