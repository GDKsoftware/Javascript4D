unit JS4D.LexicalCharacters;

{$SCOPEDENUMS ON}

interface

uses
  System.Character;

type
  TJSLexicalCharacters = class
  private
    const
      UNDERSCORE = '_';
      DOLLAR_SIGN = '$';
      ZERO_WIDTH_NON_JOINER = #$200C;
      ZERO_WIDTH_JOINER = #$200D;
      VERTICAL_TILDE = #$2E2F;
      LF_CHAR = #10;
      CR_CHAR = #13;
      LINE_SEPARATOR_CHAR = #$2028;
      PARAGRAPH_SEPARATOR_CHAR = #$2029;
      TAB_CHAR = #9;
      BACKSPACE_CHAR = #8;
      VERTICAL_TAB_CHAR = #11;
      FORM_FEED_CHAR = #12;
      ESCAPE_N = 'n';
      ESCAPE_R = 'r';
      ESCAPE_T = 't';
      ESCAPE_B = 'b';
      ESCAPE_F = 'f';
      ESCAPE_V = 'v';
      FIRST_OCTAL_DIGIT = '0';
      LAST_OCTAL_DIGIT = '7';
      ETHIOPIC_DIGIT_ONE = $1369;
      ETHIOPIC_DIGIT_NINE = $1371;
      OTHER_ID_START_CODE_POINTS: array[0..5] of Integer = ($1885, $1886, $2118, $212E, $309B, $309C);
      OTHER_ID_CONTINUE_CODE_POINTS: array[0..4] of Integer = ($00B7, $0387, $19DA, $30FB, $FF65);
      ID_START_CATEGORIES = [TUnicodeCategory.ucUppercaseLetter,
                             TUnicodeCategory.ucLowercaseLetter,
                             TUnicodeCategory.ucTitlecaseLetter,
                             TUnicodeCategory.ucModifierLetter,
                             TUnicodeCategory.ucOtherLetter,
                             TUnicodeCategory.ucLetterNumber];
      ID_PART_CATEGORIES = [TUnicodeCategory.ucNonSpacingMark,
                            TUnicodeCategory.ucCombiningMark,
                            TUnicodeCategory.ucDecimalNumber,
                            TUnicodeCategory.ucConnectPunctuation];

    class function ContainsCodePoint(const CodePoints: array of Integer; const CodePoint: Integer): Boolean; static;
    class function IsOtherIdentifierStart(const Ch: Char): Boolean; static;
    class function IsOtherIdentifierPart(const Ch: Char): Boolean; static;

  public
    class function IsLineTerminator(const Ch: Char): Boolean; static;
    class function IsOctalDigit(const Ch: Char): Boolean; static;
    class function IsIdentifierStart(const Ch: Char): Boolean; static;
    class function IsIdentifierPart(const Ch: Char): Boolean; static;
    class function IsIdentifierCodePointAt(const Text: string; const Index: Integer;
                                           const IsFirstChar: Boolean): Boolean; static;
    class function CodePointLengthAt(const Text: string; const Index: Integer): Integer; static;
    class function TryControlEscape(const Escape: Char; out Value: Char): Boolean; static;
  end;

implementation

uses
  JS4D.Utf16;

{ TJSLexicalCharacters }

class function TJSLexicalCharacters.IsLineTerminator(const Ch: Char): Boolean;
begin
  Result := ((Ch = LF_CHAR) or (Ch = CR_CHAR) or (Ch = LINE_SEPARATOR_CHAR) or (Ch = PARAGRAPH_SEPARATOR_CHAR));
end;

class function TJSLexicalCharacters.IsOctalDigit(const Ch: Char): Boolean;
begin
  Result := ((Ch >= FIRST_OCTAL_DIGIT) and (Ch <= LAST_OCTAL_DIGIT));
end;

class function TJSLexicalCharacters.ContainsCodePoint(const CodePoints: array of Integer;
                                                      const CodePoint: Integer): Boolean;
begin
  for var Candidate in CodePoints do
  begin
    if Candidate = CodePoint then
      Exit(True);
  end;

  Result := False;
end;

class function TJSLexicalCharacters.IsOtherIdentifierStart(const Ch: Char): Boolean;
begin
  Result := ContainsCodePoint(OTHER_ID_START_CODE_POINTS, Ord(Ch));
end;

class function TJSLexicalCharacters.IsOtherIdentifierPart(const Ch: Char): Boolean;
begin
  const IsEthiopicDigit = ((Ord(Ch) >= ETHIOPIC_DIGIT_ONE) and (Ord(Ch) <= ETHIOPIC_DIGIT_NINE));

  Result := (IsEthiopicDigit or ContainsCodePoint(OTHER_ID_CONTINUE_CODE_POINTS, Ord(Ch)));
end;

class function TJSLexicalCharacters.IsIdentifierStart(const Ch: Char): Boolean;
begin
  const IsLetterLike = ((Ch.GetUnicodeCategory in ID_START_CATEGORIES) and (Ch <> VERTICAL_TILDE));

  Result := (IsLetterLike or (Ch = UNDERSCORE) or (Ch = DOLLAR_SIGN) or IsOtherIdentifierStart(Ch));
end;

class function TJSLexicalCharacters.IsIdentifierPart(const Ch: Char): Boolean;
begin
  const IsCombiningOrConnector = (Ch.GetUnicodeCategory in ID_PART_CATEGORIES);
  const IsJoiner = ((Ch = ZERO_WIDTH_NON_JOINER) or (Ch = ZERO_WIDTH_JOINER));

  Result := (IsIdentifierStart(Ch) or IsCombiningOrConnector or IsJoiner or IsOtherIdentifierPart(Ch));
end;

class function TJSLexicalCharacters.CodePointLengthAt(const Text: string; const Index: Integer): Integer;
begin
  if TJSUtf16.IsPairAt(Text, Index) then
    Result := 2
  else
    Result := 1;
end;

class function TJSLexicalCharacters.IsIdentifierCodePointAt(const Text: string; const Index: Integer;
                                                            const IsFirstChar: Boolean): Boolean;
begin
  const IsInText = (Index <= Length(Text));
  if not IsInText then
    Exit(False);

  if not TJSUtf16.IsPairAt(Text, Index) then
  begin
    const Ch = Text[Index];
    Result := IsIdentifierStart(Ch) or ((not IsFirstChar) and IsIdentifierPart(Ch));
    Exit;
  end;

  const Category = Char.GetUnicodeCategory(Text, Index - 1);
  const IsStart = (Category in ID_START_CATEGORIES);
  const IsContinuation = (Category in ID_PART_CATEGORIES);

  Result := (IsStart or ((not IsFirstChar) and IsContinuation));
end;

class function TJSLexicalCharacters.TryControlEscape(const Escape: Char; out Value: Char): Boolean;
begin
  Result := True;

  case Escape of
    ESCAPE_N : Value := LF_CHAR;
    ESCAPE_R : Value := CR_CHAR;
    ESCAPE_T : Value := TAB_CHAR;
    ESCAPE_B : Value := BACKSPACE_CHAR;
    ESCAPE_F : Value := FORM_FEED_CHAR;
    ESCAPE_V : Value := VERTICAL_TAB_CHAR;
  else
    begin
      Value := Escape;
      Result := False;
    end;
  end;
end;

end.
