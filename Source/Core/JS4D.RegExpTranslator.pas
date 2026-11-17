unit JS4D.RegExpTranslator;

interface

type
  TJSRegExpTranslator = class
  public
    class function Translate(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean): string; static;
    class function HasSurrogateEscape(const Pattern: string): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  JS4D.AsciiDigits,
  JS4D.RegExpCharacters,
  JS4D.Utf16;

type
  TJSRegExpTranslation = class
  private
    type
      TUnicodeEscape = record
        CodePoint: Integer;
        EscapeLength: Integer;
      end;

    const
      WHITE_SPACE_SET = '\t\n\u000b\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff';
      NON_WHITE_SPACE_SET = '\u0000-\u0008\u000e-\u001f\u0021-\u009f\u00a1-\u167f\u1681-\u1fff' +
                            '\u200b-\u2027\u202a-\u202e\u2030-\u205e\u2060-\u2fff\u3001-\ufefe\uff00-';
      NON_WHITE_SPACE_UTF_END = #$DBFF#$DFFF;
      NON_WHITE_SPACE_UNIT_END = '\uffff';
      NEVER_MATCHES = '(?!)';
      CLASS_BRACKET_ESCAPE = BACKSLASH + CLASS_OPEN;
      UNIT_ESCAPE_FORMAT = '\u%.4x';
      LITERAL_BACKSLASH_CONTROL = '\\c';
      HEX_DIGITS_PER_UNIT = 4;
      UNIT_ESCAPE_LENGTH = ESCAPE_LENGTH + HEX_DIGITS_PER_UNIT;
      SURROGATE_PAIR_ESCAPE_LENGTH = 2 * UNIT_ESCAPE_LENGTH;
      CONTROL_ESCAPE_LENGTH = 3;
      BRACED_ESCAPE_DELIMITER_LENGTH = 2;
      WHITE_SPACE_MARK = 's';
      NON_WHITE_SPACE_MARK = 'S';
      CLASS_OPENING_LOOKALIKES = ['.', ':', '='];

    var
      FPattern: string;
      FPosition: Integer;
      FInsideClass: Boolean;
      FUnicode: Boolean;
      FUtfMode: Boolean;
      FOutput: TStringBuilder;

    class function UnitEscape(const Value: Integer): string; static;

    function HasLetterAfterControlMarker: Boolean;
    function TryReadBracedEscape(const Position: Integer; out Escape: TUnicodeEscape): Boolean;
    function TryReadUnicodeEscape(const Position: Integer; out Escape: TUnicodeEscape): Boolean;
    function TryReadSurrogatePair(const Position: Integer; const HighSurrogate: Integer;
                                  out Escape: TUnicodeEscape): Boolean;

    procedure AppendCodePoint(const CodePoint: Integer);
    procedure TranslateUnicodeEscape;
    procedure AppendCharacterSet(const CharacterSet: string);
    procedure AppendWhiteSpaceSet;
    procedure AppendNonWhiteSpaceSet;
    procedure AppendControlEscape;
    procedure EscapeClassOpeningLookalike;
    procedure AppendPlainCharacter;
    procedure TranslateEscape;

  public
    constructor Create(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean);
    destructor Destroy; override;

    function Run: string;
  end;

{ TJSRegExpTranslator }

class function TJSRegExpTranslator.Translate(const Pattern: string; const Unicode: Boolean;
                                             const UtfMode: Boolean): string;
begin
  const Translation = TJSRegExpTranslation.Create(Pattern, Unicode, UtfMode);
  try
    Result := Translation.Run;
  finally
    Translation.Free;
  end;
end;

class function TJSRegExpTranslator.HasSurrogateEscape(const Pattern: string): Boolean;
begin
  var Position := 1;

  while Position + TJSRegExpTranslation.HEX_DIGITS_PER_UNIT < Length(Pattern) do
  begin
    const IsEscape = (Pattern[Position] = BACKSLASH);
    if not IsEscape then
    begin
      Inc(Position);
      Continue;
    end;

    const IsUnicodeEscape = (Pattern[Position + 1] = UNICODE_ESCAPE_MARK);
    var Value: Integer;
    const HasUnitDigits = TJSAsciiDigits.TryParseHex(Pattern, Position + ESCAPE_LENGTH,
                                                    TJSRegExpTranslation.HEX_DIGITS_PER_UNIT, Value);
    const IsSurrogate = HasUnitDigits and (Value >= HIGH_SURROGATE_FIRST) and (Value <= LOW_SURROGATE_LAST);
    if IsUnicodeEscape and IsSurrogate then
      Exit(True);

    Inc(Position, ESCAPE_LENGTH);
  end;

  Result := False;
end;

{ TJSRegExpTranslation }

constructor TJSRegExpTranslation.Create(const Pattern: string; const Unicode: Boolean; const UtfMode: Boolean);
begin
  inherited Create;
  FPattern := Pattern;
  FUnicode := Unicode;
  FUtfMode := UtfMode;
  FPosition := 1;
  FOutput := TStringBuilder.Create;
end;

destructor TJSRegExpTranslation.Destroy;
begin
  FOutput.Free;
  inherited Destroy;
end;

class function TJSRegExpTranslation.UnitEscape(const Value: Integer): string;
begin
  Result := Format(UNIT_ESCAPE_FORMAT, [Value]);
end;

function TJSRegExpTranslation.HasLetterAfterControlMarker: Boolean;
begin
  const HasNextCharacter = (FPosition + ESCAPE_LENGTH <= Length(FPattern));
  if not HasNextCharacter then
    Exit(False);

  Result := CharInSet(FPattern[FPosition + ESCAPE_LENGTH], ASCII_LETTERS);
end;

function TJSRegExpTranslation.TryReadBracedEscape(const Position: Integer; out Escape: TUnicodeEscape): Boolean;
begin
  Escape.CodePoint := 0;
  Escape.EscapeLength := 0;

  const BraceIndex = Position + ESCAPE_LENGTH;
  const IsBraced = (BraceIndex <= Length(FPattern)) and (FPattern[BraceIndex] = QUANTIFIER_OPEN);
  if not IsBraced then
    Exit(False);

  const CloseIndex = Pos(QUANTIFIER_CLOSE, FPattern, BraceIndex);
  const DigitCount = CloseIndex - BraceIndex - 1;
  const HasDigits = (CloseIndex > 0) and (DigitCount >= 1);
  if not HasDigits then
    Exit(False);

  const HasHexDigits = TJSAsciiDigits.TryParseHex(FPattern, BraceIndex + 1, DigitCount, Escape.CodePoint);
  Escape.EscapeLength := ESCAPE_LENGTH + DigitCount + BRACED_ESCAPE_DELIMITER_LENGTH;
  Result := HasHexDigits and (Escape.CodePoint <= MAX_CODE_POINT);
end;

function TJSRegExpTranslation.TryReadUnicodeEscape(const Position: Integer; out Escape: TUnicodeEscape): Boolean;
begin
  const HasUnitDigits = TJSAsciiDigits.TryParseHex(FPattern, Position + ESCAPE_LENGTH, HEX_DIGITS_PER_UNIT,
                                                   Escape.CodePoint);
  if HasUnitDigits then
  begin
    Escape.EscapeLength := UNIT_ESCAPE_LENGTH;
    Exit(True);
  end;

  Result := TryReadBracedEscape(Position, Escape);
end;

function TJSRegExpTranslation.TryReadSurrogatePair(const Position: Integer; const HighSurrogate: Integer;
                                                   out Escape: TUnicodeEscape): Boolean;
begin
  Escape.CodePoint := 0;
  Escape.EscapeLength := 0;

  const LowPosition = Position + UNIT_ESCAPE_LENGTH;
  const HasLowEscape = (LowPosition + 1 <= Length(FPattern)) and (FPattern[LowPosition] = BACKSLASH) and
                       (FPattern[LowPosition + 1] = UNICODE_ESCAPE_MARK);
  if not HasLowEscape then
    Exit(False);

  var Low: Integer;
  const HasLowDigits = TJSAsciiDigits.TryParseHex(FPattern, LowPosition + ESCAPE_LENGTH, HEX_DIGITS_PER_UNIT, Low);
  const IsLowSurrogate = HasLowDigits and (Low >= LOW_SURROGATE_FIRST) and (Low <= LOW_SURROGATE_LAST);
  if not IsLowSurrogate then
    Exit(False);

  const HighPayload = ((HighSurrogate - HIGH_SURROGATE_FIRST) shl SURROGATE_PAYLOAD_BITS);
  const LowPayload = (Low - LOW_SURROGATE_FIRST);
  Escape.CodePoint := FIRST_SUPPLEMENTARY_CODE_POINT + HighPayload + LowPayload;
  Escape.EscapeLength := SURROGATE_PAIR_ESCAPE_LENGTH;
  Result := True;
end;

procedure TJSRegExpTranslation.AppendCodePoint(const CodePoint: Integer);
begin
  const IsSurrogate = (CodePoint >= HIGH_SURROGATE_FIRST) and (CodePoint <= LOW_SURROGATE_LAST);
  const IsAstral = (CodePoint >= FIRST_SUPPLEMENTARY_CODE_POINT);
  if IsAstral then
  begin
    FOutput.Append(Char.ConvertFromUtf32(CodePoint));
    Exit;
  end;

  if not IsSurrogate then
  begin
    const Escape = UnitEscape(CodePoint);
    FOutput.Append(Escape);
    Exit;
  end;

  if not FInsideClass then
    FOutput.Append(NEVER_MATCHES);
end;

procedure TJSRegExpTranslation.TranslateUnicodeEscape;
begin
  var Escape: TUnicodeEscape;

  const IsEscape = FUnicode and TryReadUnicodeEscape(FPosition, Escape);
  if not IsEscape then
  begin
    FOutput.Append(Copy(FPattern, FPosition, ESCAPE_LENGTH));
    Inc(FPosition, ESCAPE_LENGTH);
    Exit;
  end;

  const IsHighSurrogate = (Escape.EscapeLength = UNIT_ESCAPE_LENGTH) and
                          (Escape.CodePoint >= HIGH_SURROGATE_FIRST) and
                          (Escape.CodePoint <= HIGH_SURROGATE_LAST);
  if IsHighSurrogate then
  begin
    var Pair: TUnicodeEscape;
    if TryReadSurrogatePair(FPosition, Escape.CodePoint, Pair) then
      Escape := Pair;
  end;

  AppendCodePoint(Escape.CodePoint);
  Inc(FPosition, Escape.EscapeLength);
end;

procedure TJSRegExpTranslation.AppendCharacterSet(const CharacterSet: string);
begin
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

procedure TJSRegExpTranslation.AppendWhiteSpaceSet;
begin
  AppendCharacterSet(WHITE_SPACE_SET);
end;

procedure TJSRegExpTranslation.AppendNonWhiteSpaceSet;
begin
  if FUtfMode then
    AppendCharacterSet(NON_WHITE_SPACE_SET + NON_WHITE_SPACE_UTF_END)
  else
    AppendCharacterSet(NON_WHITE_SPACE_SET + NON_WHITE_SPACE_UNIT_END);
end;

procedure TJSRegExpTranslation.AppendControlEscape;
begin
  if not HasLetterAfterControlMarker then
  begin
    FOutput.Append(LITERAL_BACKSLASH_CONTROL);
    Inc(FPosition, ESCAPE_LENGTH);
    Exit;
  end;

  const ControlCode = Ord(FPattern[FPosition + ESCAPE_LENGTH]) mod CONTROL_CODE_MODULUS;
  const Escape = UnitEscape(ControlCode);
  FOutput.Append(Escape);
  Inc(FPosition, CONTROL_ESCAPE_LENGTH);
end;

procedure TJSRegExpTranslation.EscapeClassOpeningLookalike;
begin
  const HasNextCharacter = (FPosition <= Length(FPattern));
  const IsLookalike = HasNextCharacter and CharInSet(FPattern[FPosition], CLASS_OPENING_LOOKALIKES);
  if IsLookalike then
    FOutput.Append(BACKSLASH);
end;

procedure TJSRegExpTranslation.AppendPlainCharacter;
begin
  const Character = FPattern[FPosition];
  const IsClassOpener = (Character = CLASS_OPEN) and (not FInsideClass);
  const IsNestedBracket = (Character = CLASS_OPEN) and FInsideClass;
  const IsClassCloser = (Character = CLASS_CLOSE) and FInsideClass;
  const IsStrayCloser = (Character = CLASS_CLOSE) and (not FInsideClass);

  if IsNestedBracket then
  begin
    FOutput.Append(CLASS_BRACKET_ESCAPE);
    Inc(FPosition);
  end
  else if IsClassOpener then
  begin
    FInsideClass := True;
    FOutput.Append(Character);
    Inc(FPosition);
    EscapeClassOpeningLookalike;
  end
  else
  begin
    if IsClassCloser then
      FInsideClass := False;

    if IsStrayCloser then
      FOutput.Append(BACKSLASH);

    FOutput.Append(Character);
    Inc(FPosition);
  end;
end;

procedure TJSRegExpTranslation.TranslateEscape;
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
    WHITE_SPACE_MARK     : AppendWhiteSpaceSet;
    NON_WHITE_SPACE_MARK : AppendNonWhiteSpaceSet;
    CONTROL_ESCAPE_MARK  : AppendControlEscape;
    UNICODE_ESCAPE_MARK  : TranslateUnicodeEscape;
  else
    FOutput.Append(Copy(FPattern, FPosition, ESCAPE_LENGTH));
    Inc(FPosition, ESCAPE_LENGTH);
  end;
end;

function TJSRegExpTranslation.Run: string;
begin
  while FPosition <= Length(FPattern) do
  begin
    const IsEscape = (FPattern[FPosition] = BACKSLASH);
    if IsEscape then
      TranslateEscape
    else
      AppendPlainCharacter;
  end;

  Result := FOutput.ToString;
end;

end.
