unit JS4D.RegExpTranslator;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Character;

type
  TJSRegExpTranslator = class
  private
    const
      WHITE_SPACE_SET = '\t\n\u000b\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff';
      NON_WHITE_SPACE_SET = '\u0000-\u0008\u000e-\u001f\u0021-\u009f\u00a1-\u167f\u1681-\u1fff' +
                            '\u200b-\u2027\u202a-\u202e\u2030-\u205e\u2060-\u2fff\u3001-\ufefe\uff00-';
      NON_WHITE_SPACE_UTF_END = #$DBFF#$DFFF;
      NON_WHITE_SPACE_UNIT_END = '\uffff';
      NEVER_MATCHES = '(?!)';
      CLASS_BRACKET_ESCAPE = '\[';
      HEX_DIGITS_PER_UNIT = 4;
      HIGH_SURROGATE_FIRST = $D800;
      HIGH_SURROGATE_LAST = $DBFF;
      LOW_SURROGATE_FIRST = $DC00;
      LOW_SURROGATE_LAST = $DFFF;
      SURROGATE_OFFSET = $10000;
      SURROGATE_SHIFT = 10;
      MAX_CODE_POINT = $10FFFF;
      ESCAPE_LENGTH = 2;
      CONTROL_ESCAPE_LENGTH = 3;
      CONTROL_CODE_MODULUS = 32;
      LITERAL_BACKSLASH_CONTROL = '\\c';
      BACKSLASH = '\';
      CLASS_OPEN = '[';
      CLASS_CLOSE = ']';

    var
      FPattern: string;
      FPosition: Integer;
      FInsideClass: Boolean;
      FUnicode: Boolean;
      FUtfMode: Boolean;
      FOutput: TStringBuilder;

    constructor Create(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean);

    function Run: string;
    function HasLetterAfterControlMarker: Boolean;
    function TryReadUnicodeEscape(const Position: Integer; out CodePoint: Integer; out EscapeLength: Integer): Boolean;
    function TryReadSurrogatePair(const HighSurrogate: Integer; out CodePoint: Integer;
                                  out EscapeLength: Integer): Boolean;
    function ParseHexDigits(const Start: Integer; const Count: Integer): Integer;

    procedure TranslateEscape;
    procedure TranslateUnicodeEscape;
    procedure AppendCodePoint(const CodePoint: Integer);
    procedure EscapePosixLookalike;
    procedure AppendWhiteSpaceEscape(const Negated: Boolean);
    procedure AppendControlEscape;
    procedure AppendPlainCharacter;

  public
    class function Translate(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean): string; static;
    class function HasSurrogateEscape(const Pattern: string): Boolean; static;

    destructor Destroy; override;
  end;

implementation

{ TJSRegExpTranslator }

class function TJSRegExpTranslator.Translate(const Pattern: string; const Unicode: Boolean;
                                             const UtfMode: Boolean): string;
begin
  const Translator = TJSRegExpTranslator.Create(Pattern, Unicode, UtfMode);
  try
    Result := Translator.Run;
  finally
    Translator.Free;
  end;
end;

class function TJSRegExpTranslator.HasSurrogateEscape(const Pattern: string): Boolean;
begin
  var Position := 1;

  while Position + HEX_DIGITS_PER_UNIT < Length(Pattern) do
  begin
    const IsEscape = (Pattern[Position] = BACKSLASH);
    if not IsEscape then
    begin
      Inc(Position);
      Continue;
    end;

    const IsUnicodeEscape = (Pattern[Position + 1] = 'u');
    if IsUnicodeEscape then
    begin
      const Value = StrToIntDef('$' + Copy(Pattern, Position + ESCAPE_LENGTH, HEX_DIGITS_PER_UNIT), -1);
      const IsSurrogate = (Value >= HIGH_SURROGATE_FIRST) and (Value <= LOW_SURROGATE_LAST);
      if IsSurrogate then
        Exit(True);
    end;

    Inc(Position, ESCAPE_LENGTH);
  end;

  Result := False;
end;

constructor TJSRegExpTranslator.Create(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean);
begin
  inherited Create;
  FPattern := Pattern;
  FUnicode := Unicode;
  FUtfMode := UtfMode;
  FPosition := 1;
  FOutput := TStringBuilder.Create;
end;

destructor TJSRegExpTranslator.Destroy;
begin
  FOutput.Free;
  inherited Destroy;
end;

function TJSRegExpTranslator.Run: string;
begin
  while FPosition <= Length(FPattern) do
  begin
    const IsEscape = (FPattern[FPosition] = BACKSLASH);
    if IsEscape then
    begin
      TranslateEscape;
    end
    else
    begin
      AppendPlainCharacter;
    end;
  end;

  Result := FOutput.ToString;
end;

procedure TJSRegExpTranslator.AppendPlainCharacter;
begin
  const Character = FPattern[FPosition];

  const IsNestedBracket = (Character = CLASS_OPEN) and FInsideClass;
  if IsNestedBracket then
  begin
    FOutput.Append(CLASS_BRACKET_ESCAPE);
    Inc(FPosition);
    Exit;
  end;

  if (Character = CLASS_OPEN) and not FInsideClass then
  begin
    FInsideClass := True;
    FOutput.Append(Character);
    Inc(FPosition);
    EscapePosixLookalike;
    Exit;
  end
  else if (Character = CLASS_CLOSE) and FInsideClass then
  begin
    FInsideClass := False;
  end
  else if Character = CLASS_CLOSE then
  begin
    FOutput.Append(BACKSLASH);
  end;

  FOutput.Append(Character);
  Inc(FPosition);
end;

procedure TJSRegExpTranslator.EscapePosixLookalike;
begin
  const HasNextCharacter = (FPosition <= Length(FPattern));
  if HasNextCharacter and CharInSet(FPattern[FPosition], ['.', ':', '=']) then
    FOutput.Append(BACKSLASH);
end;

procedure TJSRegExpTranslator.TranslateEscape;
begin
  const HasEscapedCharacter = (FPosition < Length(FPattern));
  if not HasEscapedCharacter then
  begin
    FOutput.Append(BACKSLASH);
    Inc(FPosition);
    Exit;
  end;

  const Escaped = FPattern[FPosition + 1];
  case Escaped of
    's' : AppendWhiteSpaceEscape(False);
    'S' : AppendWhiteSpaceEscape(True);
    'c' : AppendControlEscape;
    'u' : TranslateUnicodeEscape;
  else
    FOutput.Append(Copy(FPattern, FPosition, ESCAPE_LENGTH));
    Inc(FPosition, ESCAPE_LENGTH);
  end;
end;

function TJSRegExpTranslator.ParseHexDigits(const Start: Integer; const Count: Integer): Integer;
begin
  Result := -1;

  const HasAllDigits = (Start + Count - 1 <= Length(FPattern));
  if not HasAllDigits then
    Exit;

  for var Offset := 0 to Count - 1 do
  begin
    if not CharInSet(FPattern[Start + Offset], ['0'..'9', 'a'..'f', 'A'..'F']) then
      Exit;
  end;

  Result := StrToInt('$' + Copy(FPattern, Start, Count));
end;

function TJSRegExpTranslator.TryReadUnicodeEscape(const Position: Integer; out CodePoint: Integer;
                                                  out EscapeLength: Integer): Boolean;
begin
  CodePoint := ParseHexDigits(Position + ESCAPE_LENGTH, HEX_DIGITS_PER_UNIT);
  EscapeLength := ESCAPE_LENGTH + HEX_DIGITS_PER_UNIT;
  if CodePoint >= 0 then
    Exit(True);

  const IsBraced = (Position + ESCAPE_LENGTH <= Length(FPattern)) and (FPattern[Position + ESCAPE_LENGTH] = '{');
  if not IsBraced then
    Exit(False);

  const CloseIndex = Pos('}', FPattern, Position + ESCAPE_LENGTH);
  const DigitCount = CloseIndex - Position - ESCAPE_LENGTH - 1;
  if (CloseIndex = 0) or (DigitCount < 1) then
    Exit(False);

  CodePoint := ParseHexDigits(Position + ESCAPE_LENGTH + 1, DigitCount);
  EscapeLength := ESCAPE_LENGTH + DigitCount + 2;
  Result := (CodePoint >= 0) and (CodePoint <= MAX_CODE_POINT);
end;

function TJSRegExpTranslator.TryReadSurrogatePair(const HighSurrogate: Integer; out CodePoint: Integer;
                                                  out EscapeLength: Integer): Boolean;
begin
  const LowPosition = FPosition + ESCAPE_LENGTH + HEX_DIGITS_PER_UNIT;
  const HasLowEscape = (LowPosition + 1 <= Length(FPattern)) and (FPattern[LowPosition] = BACKSLASH) and
                       (FPattern[LowPosition + 1] = 'u');
  if not HasLowEscape then
    Exit(False);

  const Low = ParseHexDigits(LowPosition + ESCAPE_LENGTH, HEX_DIGITS_PER_UNIT);
  const IsLowSurrogate = (Low >= LOW_SURROGATE_FIRST) and (Low <= LOW_SURROGATE_LAST);
  if not IsLowSurrogate then
    Exit(False);

  CodePoint := SURROGATE_OFFSET + ((HighSurrogate - HIGH_SURROGATE_FIRST) shl SURROGATE_SHIFT) +
               (Low - LOW_SURROGATE_FIRST);
  EscapeLength := 2 * (ESCAPE_LENGTH + HEX_DIGITS_PER_UNIT);
  Result := True;
end;

procedure TJSRegExpTranslator.AppendCodePoint(const CodePoint: Integer);
begin
  const IsSurrogate = (CodePoint >= HIGH_SURROGATE_FIRST) and (CodePoint <= LOW_SURROGATE_LAST);
  const IsAstral = (CodePoint >= SURROGATE_OFFSET);
  if IsAstral then
  begin
    FOutput.Append(Char.ConvertFromUtf32(CodePoint));
    Exit;
  end;

  if not IsSurrogate then
  begin
    FOutput.Append(Format('\u%.4x', [CodePoint]));
    Exit;
  end;

  if not FInsideClass then
    FOutput.Append(NEVER_MATCHES);
end;

procedure TJSRegExpTranslator.TranslateUnicodeEscape;
begin
  var CodePoint: Integer;
  var EscapeLength: Integer;

  const IsEscape = FUnicode and TryReadUnicodeEscape(FPosition, CodePoint, EscapeLength);
  if not IsEscape then
  begin
    FOutput.Append(Copy(FPattern, FPosition, ESCAPE_LENGTH));
    Inc(FPosition, ESCAPE_LENGTH);
    Exit;
  end;

  const IsHighSurrogate = (EscapeLength = ESCAPE_LENGTH + HEX_DIGITS_PER_UNIT) and
                          (CodePoint >= HIGH_SURROGATE_FIRST) and (CodePoint <= HIGH_SURROGATE_LAST);
  var PairLength: Integer;
  var PairCodePoint: Integer;
  if IsHighSurrogate and TryReadSurrogatePair(CodePoint, PairCodePoint, PairLength) then
  begin
    CodePoint := PairCodePoint;
    EscapeLength := PairLength;
  end;

  AppendCodePoint(CodePoint);
  Inc(FPosition, EscapeLength);
end;

procedure TJSRegExpTranslator.AppendWhiteSpaceEscape(const Negated: Boolean);
begin
  var CharacterSet := WHITE_SPACE_SET;
  if Negated then
  begin
    CharacterSet := NON_WHITE_SPACE_SET;
    if FUtfMode then
      CharacterSet := CharacterSet + NON_WHITE_SPACE_UTF_END
    else
      CharacterSet := CharacterSet + NON_WHITE_SPACE_UNIT_END;
  end;

  if FInsideClass then
  begin
    FOutput.Append(CharacterSet);
  end
  else
  begin
    FOutput.Append(CLASS_OPEN);
    FOutput.Append(CharacterSet);
    FOutput.Append(CLASS_CLOSE);
  end;

  Inc(FPosition, ESCAPE_LENGTH);
end;

procedure TJSRegExpTranslator.AppendControlEscape;
begin
  if not HasLetterAfterControlMarker then
  begin
    FOutput.Append(LITERAL_BACKSLASH_CONTROL);
    Inc(FPosition, ESCAPE_LENGTH);
    Exit;
  end;

  const ControlCode = Ord(FPattern[FPosition + ESCAPE_LENGTH]) mod CONTROL_CODE_MODULUS;
  FOutput.Append(Format('\u%.4x', [ControlCode]));
  Inc(FPosition, CONTROL_ESCAPE_LENGTH);
end;

function TJSRegExpTranslator.HasLetterAfterControlMarker: Boolean;
begin
  const HasNextCharacter = (FPosition + ESCAPE_LENGTH <= Length(FPattern));
  if not HasNextCharacter then
    Exit(False);

  Result := CharInSet(FPattern[FPosition + ESCAPE_LENGTH], ['A'..'Z', 'a'..'z']);
end;

end.
