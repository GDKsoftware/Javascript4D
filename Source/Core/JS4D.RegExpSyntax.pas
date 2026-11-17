unit JS4D.RegExpSyntax;

interface

uses
  JS4D.Errors;

type
  TJSRegExpFlags = record
    IsGlobal: Boolean;
    IgnoresCase: Boolean;
    IsMultiline: Boolean;
    IsUnicode: Boolean;
    IsSticky: Boolean;

    const
      GLOBAL = 'g';
      IGNORE_CASE = 'i';
      MULTILINE = 'm';
      UNICODE = 'u';
      STICKY = 'y';

    class function Includes(const Flags: string; const Flag: Char): Boolean; static;
    class function Parse(const Flags: string): TJSRegExpFlags; static;
  end;

  TJSRegExpSyntax = class
  private
    class function LineTerminatorEscape(const Character: Char): string; static;
    class function EscapedCharacter(const Character: Char; const InClass: Boolean): string; static;
    class function EscapedPair(const Character: Char): string; static;

  public
    class procedure ValidatePattern(const Pattern: string; const Flags: string;
                                    const Position: TJSSourcePosition); static;
    class procedure ValidateFlags(const Flags: string; const Position: TJSSourcePosition); static;
    class function EscapePattern(const Pattern: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  JS4D.AsciiDigits,
  JS4D.RegExpCharacters,
  JS4D.Utf16;

type
  TJSRegExpValidator = class
  private
    type
      TClassAtom = record
        CodePoint: Integer;
        IsSet: Boolean;

        class function ForCodePoint(const CodePoint: Integer): TClassAtom; static;
        class function ForSet: TClassAtom; static;
      end;

      TQuantifierBounds = record
        Minimum: Int64;
        Maximum: Int64;
      end;

    const
      MAX_GROUP_DEPTH = 250;
      CLASS_SET_ESCAPES = 'dDsSwW';
      CLASS_CONTROL_ESCAPES = 'btnvfr';
      BACKSPACE_CODE = 8;
      SATURATED_QUANTIFIER_BOUND = 100000000000000000;
      SYNTAX_CHARACTERS = '^$\.*+?()[]{}|/-';
      LOOKAHEAD_POSITIVE = '(?=';
      LOOKAHEAD_NEGATIVE = '(?!';
      NON_CAPTURING_GROUP = '(?:';
      LOOKBEHIND_POSITIVE = '(?<=';
      LOOKBEHIND_NEGATIVE = '(?<!';
      NAMED_GROUP_OPEN = '(?<';
      GROUP_MODIFIER_OPEN = '(?';
      NAMED_GROUP_PREFIX_LENGTH = 3;
      LOOKBEHIND_PREFIX_LENGTH = 4;
      NAME_CLOSE = '>';
      NAME_OPEN = '<';
      WORD_BOUNDARIES = ['b', 'B'];
      NEGATED_CLASS_MARK = '^';
      RANGE_MARK = '-';
      NAMED_REFERENCE_MARK = 'k';
      ZERO_DIGIT = '0';
      OCTAL_DIGITS = ['0'..'7'];
      OCTAL_BASE = 8;
      MAX_OCTAL_DIGITS = 3;
      MAX_OCTAL_VALUE = 255;
      HEX_ESCAPE_DIGITS = 2;
      UNICODE_ESCAPE_DIGITS = 4;
      TRAIL_ESCAPE_LENGTH = ESCAPE_LENGTH + UNICODE_ESCAPE_DIGITS;
      BRACED_CODE_POINT_PREFIX_LENGTH = 2;
      NULL_ESCAPE_CODE = 0;
      DECIMAL_BASE = 10;

    var
      FPattern: string;
      FPosition: Integer;
      FIsUnicode: Boolean;
      FGroupCount: Integer;
      FGroupDepth: Integer;
      FSourcePosition: TJSSourcePosition;

    function IsAtEnd: Boolean;
    function IsAtAlternativeEnd: Boolean;
    function Current: Char;
    function PeekAt(const Offset: Integer): Char;
    function LooksLike(const Text: string): Boolean;
    function TryConsume(const Text: string): Boolean;
    procedure Fail;
    procedure Expect(const Expected: Char);
    procedure SkipNameThrough(const Delimiter: Char);

    procedure ParseDisjunction;
    procedure ParseAlternative;
    procedure ParseTerm;
    function ParseGroup: Boolean;
    procedure ParseGroupName;
    procedure ParseEscape;
    procedure ParseQuantifier;
    function TryParseBracedQuantifier: Boolean;
    function LooksLikeBracedQuantifier: Boolean;
    function TryReadBracedBounds(out Bounds: TQuantifierBounds): Boolean;
    function ReadDigits: Int64;
    procedure ParseClass;
    procedure ParseClassRange;
    function ParseClassAtom: TClassAtom;
    procedure ParseStrictAtomEscape;
    procedure ParseDecimalEscape;
    procedure ParseNamedReference;
    procedure ParsePropertyEscape;
    function CountCaptureGroups: Integer;
    function IsCapturingGroupAt(const Index: Integer): Boolean;
    function ParseClassEscape: TClassAtom;
    function ParseCharacterEscape(const Escaped: Char): Integer;
    function ParseNumericEscape: Integer;
    function ParseIdentityEscape(const Escaped: Char): Integer;
    function ParseUnicodeEscape: Integer;
    function ParseBracedCodePoint: Integer;
    function TryReadTrailSurrogateEscape(out Trail: Integer): Boolean;
    function ParseStrictNullEscape: Integer;
    function ParseHexEscape(const Digits: Integer; const Fallback: Integer): Integer;
    function ParseControlEscape: Integer;
    function ParseOctalEscape: Integer;

  public
    constructor Create(const Pattern: string; const Flags: string; const Position: TJSSourcePosition);

    procedure Validate;
  end;

const
  VALID_FLAG_CHARACTERS = 'gimuy';
  EMPTY_PATTERN_SOURCE = '(?:)';
  INVALID_FLAGS_MESSAGE = 'Invalid regular expression flags: %s';

{ TJSRegExpFlags }

class function TJSRegExpFlags.Includes(const Flags: string; const Flag: Char): Boolean;
begin
  Result := (Pos(Flag, Flags) > 0);
end;

class function TJSRegExpFlags.Parse(const Flags: string): TJSRegExpFlags;
begin
  Result.IsGlobal := Includes(Flags, GLOBAL);
  Result.IgnoresCase := Includes(Flags, IGNORE_CASE);
  Result.IsMultiline := Includes(Flags, MULTILINE);
  Result.IsUnicode := Includes(Flags, UNICODE);
  Result.IsSticky := Includes(Flags, STICKY);
end;

{ TJSRegExpSyntax }

class procedure TJSRegExpSyntax.ValidatePattern(const Pattern: string; const Flags: string;
                                                const Position: TJSSourcePosition);
begin
  const Validator = TJSRegExpValidator.Create(Pattern, Flags, Position);
  try
    Validator.Validate;
  finally
    Validator.Free;
  end;
end;

class procedure TJSRegExpSyntax.ValidateFlags(const Flags: string; const Position: TJSSourcePosition);
begin
  for var Index := 1 to Length(Flags) do
  begin
    const Flag = Flags[Index];
    const IsKnown = (Pos(Flag, VALID_FLAG_CHARACTERS) > 0);
    const IsRepeated = (Pos(Flag, Flags) < Index);

    if (not IsKnown) or IsRepeated then
    begin
      const Message = Format(INVALID_FLAGS_MESSAGE, [Flags]);
      raise TJSErrorFactory.SyntaxError(Message, Position.Line, Position.Column);
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

  Result := BACKSLASH + Character;
end;

class function TJSRegExpSyntax.EscapePattern(const Pattern: string): string;
begin
  if Pattern.IsEmpty then
    Exit(EMPTY_PATTERN_SOURCE);

  var Escaped := TStringBuilder.Create;
  try
    var InClass := False;
    var Index := 1;
    while Index <= Length(Pattern) do
    begin
      const Character = Pattern[Index];
      const IsEscapePair = (Character = BACKSLASH) and (Index < Length(Pattern));

      if IsEscapePair then
      begin
        Inc(Index);
        Escaped.Append(EscapedPair(Pattern[Index]));
      end
      else
      begin
        InClass := (InClass or (Character = CLASS_OPEN)) and (Character <> CLASS_CLOSE);
        Escaped.Append(EscapedCharacter(Character, InClass));
      end;

      Inc(Index);
    end;

    Result := Escaped.ToString;
  finally
    Escaped.Free;
  end;
end;

{ TJSRegExpValidator.TClassAtom }

class function TJSRegExpValidator.TClassAtom.ForCodePoint(const CodePoint: Integer): TClassAtom;
begin
  Result.CodePoint := CodePoint;
  Result.IsSet := False;
end;

class function TJSRegExpValidator.TClassAtom.ForSet: TClassAtom;
begin
  Result.CodePoint := 0;
  Result.IsSet := True;
end;

{ TJSRegExpValidator }

constructor TJSRegExpValidator.Create(const Pattern: string; const Flags: string;
                                      const Position: TJSSourcePosition);
begin
  inherited Create;
  FPattern := Pattern;
  const ParsedFlags = TJSRegExpFlags.Parse(Flags);
  FIsUnicode := ParsedFlags.IsUnicode;
  FGroupCount := 0;
  FGroupDepth := 0;
  FPosition := 1;
  FSourcePosition := Position;
end;

procedure TJSRegExpValidator.Validate;
begin
  if FIsUnicode then
    FGroupCount := CountCaptureGroups;

  ParseDisjunction;

  if not IsAtEnd then
    Fail;
end;

function TJSRegExpValidator.IsAtEnd: Boolean;
begin
  Result := (FPosition > Length(FPattern));
end;

function TJSRegExpValidator.IsAtAlternativeEnd: Boolean;
begin
  Result := IsAtEnd or CharInSet(Current, [ALTERNATION, GROUP_CLOSE]);
end;

function TJSRegExpValidator.Current: Char;
begin
  Result := PeekAt(0);
end;

function TJSRegExpValidator.PeekAt(const Offset: Integer): Char;
begin
  const Index = FPosition + Offset;
  const IsInside = (Index >= 1) and (Index <= Length(FPattern));

  if IsInside then
    Result := FPattern[Index]
  else
    Result := #0;
end;

function TJSRegExpValidator.LooksLike(const Text: string): Boolean;
begin
  Result := (Copy(FPattern, FPosition, Length(Text)) = Text);
end;

function TJSRegExpValidator.TryConsume(const Text: string): Boolean;
begin
  Result := LooksLike(Text);

  if Result then
    Inc(FPosition, Length(Text));
end;

procedure TJSRegExpValidator.Fail;
begin
  raise TJSErrorFactory.InvalidRegExp(FPattern, FSourcePosition);
end;

procedure TJSRegExpValidator.Expect(const Expected: Char);
begin
  const IsExpected = (not IsAtEnd) and (Current = Expected);
  if not IsExpected then
    Fail;

  Inc(FPosition);
end;

procedure TJSRegExpValidator.SkipNameThrough(const Delimiter: Char);
begin
  const NameStart = FPosition - 1;
  const DelimiterIndex = FPattern.IndexOf(Delimiter, NameStart);
  const NameLength = DelimiterIndex - NameStart;
  const IsNamed = (DelimiterIndex >= 0) and (NameLength > 0);
  if not IsNamed then
    Fail;

  Inc(FPosition, NameLength + 1);
end;

procedure TJSRegExpValidator.ParseDisjunction;
begin
  ParseAlternative;

  var HasAlternation := (not IsAtEnd) and (Current = ALTERNATION);
  while HasAlternation do
  begin
    Inc(FPosition);
    ParseAlternative;
    HasAlternation := (not IsAtEnd) and (Current = ALTERNATION);
  end;
end;

procedure TJSRegExpValidator.ParseAlternative;
begin
  while not IsAtAlternativeEnd do
  begin
    ParseTerm;
  end;
end;

procedure TJSRegExpValidator.ParseTerm;
begin
  var IsQuantifiable := True;

  case Current of
    '^', '$':
      begin
        Inc(FPosition);
        IsQuantifiable := False;
      end;

    BACKSLASH:
      begin
        const IsBoundary = CharInSet(PeekAt(1), WORD_BOUNDARIES);
        if IsBoundary then
        begin
          Inc(FPosition, ESCAPE_LENGTH);
          IsQuantifiable := False;
        end
        else
        begin
          ParseEscape;
        end;
      end;

    GROUP_OPEN:
      IsQuantifiable := ParseGroup;

    CLASS_OPEN:
      ParseClass;

    '*', '+', '?':
      Fail;

    QUANTIFIER_OPEN:
      begin
        const IsInvalidQuantifier = FIsUnicode or LooksLikeBracedQuantifier;
        if IsInvalidQuantifier then
          Fail;

        Inc(FPosition);
      end;

    QUANTIFIER_CLOSE, CLASS_CLOSE:
      begin
        if FIsUnicode then
          Fail;

        Inc(FPosition);
      end;
  else
    Inc(FPosition);
  end;

  if IsQuantifiable then
  begin
    ParseQuantifier;
    Exit;
  end;

  const IsDanglingMark = CharInSet(Current, QUANTIFIER_MARKS);
  const IsDanglingBraces = (Current = QUANTIFIER_OPEN) and LooksLikeBracedQuantifier;
  if IsDanglingMark or IsDanglingBraces then
    Fail;
end;

function TJSRegExpValidator.ParseGroup: Boolean;
begin
  Result := True;

  if TryConsume(LOOKAHEAD_POSITIVE) or TryConsume(LOOKAHEAD_NEGATIVE) then
  begin
    Result := not FIsUnicode;
  end
  else if TryConsume(NON_CAPTURING_GROUP) then
  begin
    Result := True;
  end
  else if TryConsume(LOOKBEHIND_POSITIVE) or TryConsume(LOOKBEHIND_NEGATIVE) then
  begin
    Result := False;
  end
  else if LooksLike(NAMED_GROUP_OPEN) then
  begin
    ParseGroupName;
  end
  else if LooksLike(GROUP_MODIFIER_OPEN) then
  begin
    Fail;
  end
  else
  begin
    Inc(FPosition);
  end;

  const IsTooDeep = (FGroupDepth >= MAX_GROUP_DEPTH);
  if IsTooDeep then
    Fail;

  Inc(FGroupDepth);
  try
    ParseDisjunction;
  finally
    Dec(FGroupDepth);
  end;

  Expect(GROUP_CLOSE);
end;

procedure TJSRegExpValidator.ParseGroupName;
begin
  Inc(FPosition, NAMED_GROUP_PREFIX_LENGTH);

  SkipNameThrough(NAME_CLOSE);
end;

procedure TJSRegExpValidator.ParseEscape;
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

procedure TJSRegExpValidator.ParseStrictAtomEscape;
begin
  const Escaped = PeekAt(1);

  case Escaped of
    RANGE_MARK:
      Fail;
    '0'..'9':
      ParseDecimalEscape;
    NAMED_REFERENCE_MARK:
      ParseNamedReference;
    'p', 'P':
      ParsePropertyEscape;
  else
    ParseClassEscape;
  end;
end;

procedure TJSRegExpValidator.ParseDecimalEscape;
begin
  Inc(FPosition);

  const IsNullEscape = (Current = ZERO_DIGIT);
  if IsNullEscape then
  begin
    Inc(FPosition);

    if TJSAsciiDigits.IsDigit(Current) then
      Fail;

    Exit;
  end;

  const Reference = ReadDigits;
  const IsMissingGroup = (Reference > FGroupCount);
  if IsMissingGroup then
    Fail;
end;

procedure TJSRegExpValidator.ParseNamedReference;
begin
  Inc(FPosition, ESCAPE_LENGTH);
  Expect(NAME_OPEN);

  SkipNameThrough(NAME_CLOSE);
end;

procedure TJSRegExpValidator.ParsePropertyEscape;
begin
  Inc(FPosition, ESCAPE_LENGTH);
  Expect(QUANTIFIER_OPEN);

  SkipNameThrough(QUANTIFIER_CLOSE);
end;

function TJSRegExpValidator.CountCaptureGroups: Integer;
begin
  Result := 0;
  var Index := 1;
  var IsInClass := False;

  while Index <= Length(FPattern) do
  begin
    const Character = FPattern[Index];

    const IsEscape = (Character = BACKSLASH);
    if IsEscape then
    begin
      Inc(Index);
    end
    else
    begin
      const IsGroupStart = (Character = GROUP_OPEN) and (not IsInClass);
      if IsGroupStart and IsCapturingGroupAt(Index) then
        Inc(Result);

      IsInClass := TJSRegExpCharacters.NextClassState(Character, IsInClass);
    end;

    Inc(Index);
  end;
end;

function TJSRegExpValidator.IsCapturingGroupAt(const Index: Integer): Boolean;
begin
  const Opening = Copy(FPattern, Index, LOOKBEHIND_PREFIX_LENGTH);
  const IsPlain = not Opening.StartsWith(GROUP_MODIFIER_OPEN);
  const IsLookbehind = Opening.StartsWith(LOOKBEHIND_POSITIVE) or Opening.StartsWith(LOOKBEHIND_NEGATIVE);
  const IsNamed = Opening.StartsWith(NAMED_GROUP_OPEN) and (not IsLookbehind);

  Result := IsPlain or IsNamed;
end;

procedure TJSRegExpValidator.ParseQuantifier;
begin
  case Current of
    '*', '+', '?':
      Inc(FPosition);
    QUANTIFIER_OPEN:
      if not TryParseBracedQuantifier then
        Exit;
  else
    Exit;
  end;

  const IsLazy = (Current = '?');
  if IsLazy then
    Inc(FPosition);

  const IsRepeatedMark = CharInSet(Current, QUANTIFIER_MARKS);
  if IsRepeatedMark then
    Fail;
end;

function TJSRegExpValidator.ReadDigits: Int64;
begin
  Result := 0;

  while TJSAsciiDigits.IsDigit(Current) do
  begin
    const HasRoomForDigit = (Result < SATURATED_QUANTIFIER_BOUND);
    if HasRoomForDigit then
      Result := (Result * DECIMAL_BASE) + TJSAsciiDigits.DigitValue(Current);

    Inc(FPosition);
  end;
end;

function TJSRegExpValidator.TryReadBracedBounds(out Bounds: TQuantifierBounds): Boolean;
begin
  Result := False;
  Bounds.Minimum := 0;
  Bounds.Maximum := 0;

  Inc(FPosition);

  const HasMinimum = TJSAsciiDigits.IsDigit(Current);
  if not HasMinimum then
    Exit;

  Bounds.Minimum := ReadDigits;
  Bounds.Maximum := Bounds.Minimum;

  const HasSeparator = (Current = BOUND_SEPARATOR);
  if HasSeparator then
  begin
    Inc(FPosition);

    const HasMaximum = TJSAsciiDigits.IsDigit(Current);
    if HasMaximum then
      Bounds.Maximum := ReadDigits
    else
      Bounds.Maximum := High(Int64);
  end;

  const IsClosed = (Current = QUANTIFIER_CLOSE);
  if not IsClosed then
    Exit;

  Inc(FPosition);
  Result := True;
end;

function TJSRegExpValidator.TryParseBracedQuantifier: Boolean;
begin
  const StartPosition = FPosition;

  var Bounds: TQuantifierBounds;
  Result := TryReadBracedBounds(Bounds);
  if not Result then
  begin
    FPosition := StartPosition;
    Exit;
  end;

  const IsOutOfOrder = (Bounds.Minimum > Bounds.Maximum);
  if IsOutOfOrder then
    Fail;
end;

function TJSRegExpValidator.LooksLikeBracedQuantifier: Boolean;
begin
  const StartPosition = FPosition;

  Result := TryParseBracedQuantifier;
  FPosition := StartPosition;
end;

procedure TJSRegExpValidator.ParseClass;
begin
  Inc(FPosition);

  const IsNegated = (Current = NEGATED_CLASS_MARK);
  if IsNegated then
    Inc(FPosition);

  while (not IsAtEnd) and (Current <> CLASS_CLOSE) do
  begin
    ParseClassRange;
  end;

  Expect(CLASS_CLOSE);
end;

procedure TJSRegExpValidator.ParseClassRange;
begin
  const StartAtom = ParseClassAtom;

  const IsRange = (Current = RANGE_MARK) and (PeekAt(1) <> CLASS_CLOSE) and (FPosition < Length(FPattern));
  if not IsRange then
    Exit;

  Inc(FPosition);

  const EndAtom = ParseClassAtom;

  const HasSet = StartAtom.IsSet or EndAtom.IsSet;
  const IsInvalidSetRange = HasSet and FIsUnicode;
  if IsInvalidSetRange then
    Fail;

  const IsOutOfOrder = (StartAtom.CodePoint > EndAtom.CodePoint);
  if (not HasSet) and IsOutOfOrder then
    Fail;
end;

function TJSRegExpValidator.ParseClassAtom: TClassAtom;
begin
  if Current = BACKSLASH then
  begin
    Result := ParseClassEscape;
    Exit;
  end;

  var CodePoint: Integer := Ord(Current);

  const LowSurrogate = PeekAt(1);
  const IsSurrogatePair = FIsUnicode and Current.IsHighSurrogate and LowSurrogate.IsLowSurrogate;
  if IsSurrogatePair then
  begin
    CodePoint := Char.ConvertToUtf32(Current, LowSurrogate);
    Inc(FPosition);
  end;

  Inc(FPosition);
  Result := TClassAtom.ForCodePoint(CodePoint);
end;

function TJSRegExpValidator.ParseClassEscape: TClassAtom;
begin
  Inc(FPosition);

  if IsAtEnd then
    Fail;

  const Escaped = Current;
  const IsSetEscape = (Pos(Escaped, CLASS_SET_ESCAPES) > 0);
  if IsSetEscape then
  begin
    Inc(FPosition);
    Result := TClassAtom.ForSet;
    Exit;
  end;

  const CodePoint = ParseCharacterEscape(Escaped);

  Result := TClassAtom.ForCodePoint(CodePoint);
end;

function TJSRegExpValidator.ParseCharacterEscape(const Escaped: Char): Integer;
begin
  const ControlEscapeIndex = Pos(Escaped, CLASS_CONTROL_ESCAPES);
  const IsControlEscape = (ControlEscapeIndex > 0);
  if IsControlEscape then
  begin
    Inc(FPosition);
    Exit(BACKSPACE_CODE + ControlEscapeIndex - 1);
  end;

  case Escaped of
    HEX_ESCAPE_MARK:
      Result := ParseHexEscape(HEX_ESCAPE_DIGITS, Ord(HEX_ESCAPE_MARK));
    UNICODE_ESCAPE_MARK:
      Result := ParseUnicodeEscape;
    CONTROL_ESCAPE_MARK:
      Result := ParseControlEscape;
    '0'..'7':
      Result := ParseNumericEscape;
  else
    Result := ParseIdentityEscape(Escaped);
  end;
end;

function TJSRegExpValidator.ParseNumericEscape: Integer;
begin
  if FIsUnicode then
    Result := ParseStrictNullEscape
  else
    Result := ParseOctalEscape;
end;

function TJSRegExpValidator.ParseIdentityEscape(const Escaped: Char): Integer;
begin
  const IsSyntaxCharacter = (Pos(Escaped, SYNTAX_CHARACTERS) > 0);
  const IsForbidden = FIsUnicode and (not IsSyntaxCharacter);
  if IsForbidden then
    Fail;

  Inc(FPosition);
  Result := Ord(Escaped);
end;

function TJSRegExpValidator.ParseUnicodeEscape: Integer;
begin
  const IsBraced = FIsUnicode and (PeekAt(1) = QUANTIFIER_OPEN);
  if IsBraced then
  begin
    Result := ParseBracedCodePoint;
    Exit;
  end;

  Result := ParseHexEscape(UNICODE_ESCAPE_DIGITS, Ord(UNICODE_ESCAPE_MARK));

  const IsLeadSurrogate = FIsUnicode and Char(Result).IsHighSurrogate;
  if not IsLeadSurrogate then
    Exit;

  var Trail: Integer;
  if TryReadTrailSurrogateEscape(Trail) then
    Result := Char.ConvertToUtf32(Char(Result), Char(Trail));
end;

function TJSRegExpValidator.ParseBracedCodePoint: Integer;
begin
  Inc(FPosition, BRACED_CODE_POINT_PREFIX_LENGTH);
  Result := 0;
  var DigitCount := 0;

  while TJSAsciiDigits.IsHexDigit(Current) do
  begin
    Result := (Result * TJSAsciiDigits.HEX_RADIX) + TJSAsciiDigits.HexValue(Current);

    const ExceedsCodePoints = (Result > MAX_CODE_POINT);
    if ExceedsCodePoints then
      Fail;

    Inc(DigitCount);
    Inc(FPosition);
  end;

  const IsComplete = (DigitCount > 0) and (Current = QUANTIFIER_CLOSE);
  if not IsComplete then
    Fail;

  Inc(FPosition);
end;

function TJSRegExpValidator.TryReadTrailSurrogateEscape(out Trail: Integer): Boolean;
begin
  Trail := 0;

  const IsEscape = (Current = BACKSLASH) and (PeekAt(1) = UNICODE_ESCAPE_MARK);
  if not IsEscape then
    Exit(False);

  const HasDigits = TJSAsciiDigits.TryParseHex(FPattern, FPosition + ESCAPE_LENGTH, UNICODE_ESCAPE_DIGITS, Trail);
  if not HasDigits then
    Exit(False);

  Result := (Trail >= LOW_SURROGATE_FIRST) and (Trail <= LOW_SURROGATE_LAST);
  if Result then
    Inc(FPosition, TRAIL_ESCAPE_LENGTH);
end;

function TJSRegExpValidator.ParseStrictNullEscape: Integer;
begin
  const IsNull = (Current = ZERO_DIGIT) and (not TJSAsciiDigits.IsDigit(PeekAt(1)));
  if not IsNull then
    Fail;

  Inc(FPosition);
  Result := NULL_ESCAPE_CODE;
end;

function TJSRegExpValidator.ParseHexEscape(const Digits: Integer; const Fallback: Integer): Integer;
begin
  const HasDigits = TJSAsciiDigits.TryParseHex(FPattern, FPosition + 1, Digits, Result);
  if HasDigits then
  begin
    Inc(FPosition, Digits + 1);
    Exit;
  end;

  if FIsUnicode then
    Fail;

  Inc(FPosition);
  Result := Fallback;
end;

function TJSRegExpValidator.ParseControlEscape: Integer;
begin
  const Letter = PeekAt(1);
  const IsLetter = CharInSet(Letter, ASCII_LETTERS);

  if IsLetter then
  begin
    Result := Ord(Letter) mod CONTROL_CODE_MODULUS;
    Inc(FPosition, ESCAPE_LENGTH);
  end
  else
  begin
    if FIsUnicode then
      Fail;

    Result := Ord(BACKSLASH);
  end;
end;

function TJSRegExpValidator.ParseOctalEscape: Integer;
begin
  Result := 0;

  for var DigitIndex := 1 to MAX_OCTAL_DIGITS do
  begin
    const IsOctalDigit = CharInSet(Current, OCTAL_DIGITS);
    if not IsOctalDigit then
      Exit;

    const Candidate = (Result * OCTAL_BASE) + TJSAsciiDigits.DigitValue(Current);
    const FitsInByte = (Candidate <= MAX_OCTAL_VALUE);
    if not FitsInByte then
      Exit;

    Result := Candidate;
    Inc(FPosition);
  end;
end;

end.
