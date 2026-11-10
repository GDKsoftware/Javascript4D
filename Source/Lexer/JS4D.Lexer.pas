unit JS4D.Lexer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Character,
  System.Math,
  System.StrUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.Errors;

type
  TJSLexer = class
  private
    FSource: string;
    FPosition: Integer;
    FLine: Integer;
    FColumn: Integer;
    FLineStart: Integer;
    FTokens: TObjectList<TJSToken>;
    FCurrentIndex: Integer;
    FStringHasLegacyEscape: Boolean;

    function CurrentChar: Char;
    function PeekChar(const Offset: Integer = 1): Char;
    function IsAtEnd: Boolean;
    procedure Advance;
    procedure SkipWhitespace;
    procedure SkipSingleLineComment;
    procedure SkipMultiLineComment;

    function ScanToken: TJSToken;
    function ScanIdentifier: TJSToken;
    function IdentifierTokenType(const Name: string; const HasEscape: Boolean): TJSTokenType;
    function ScanNumber: TJSToken;
    function ScanNumberLiteral: TJSToken;
    procedure RejectIdentifierAfterNumber;
    function ScanString(const Quote: Char): TJSToken;
    function ScanRegExp: TJSToken;
    function ScanOperator: TJSToken;
    function ScanPunctuation: TJSToken;

    function IsIdentifierStart(const Ch: Char): Boolean;
    function IsIdentifierPart(const Ch: Char): Boolean;
    function IsDigit(const Ch: Char): Boolean;
    function IsLineTerminator(const Ch: Char): Boolean;
    function IsWhiteSpace(const Ch: Char): Boolean;
    function IsHexDigit(const Ch: Char): Boolean;
    function IsOctalDigit(const Ch: Char): Boolean;

    function ParseHexNumber: Double;
    function ParseOctalNumber: Double;
    function ReadDigits: string;
    function ReadExponent: string;
    function ParseDecimalNumber: Double;
    function IsLegacyOctalLiteral: Boolean;
    function ParseEscapeSequence: string;
    function ParseOctalEscape(const FirstDigit: Char): string;
    function ParseLineContinuation(const Terminator: Char): string;
    function ParseHexDigits(const DigitCount: Integer; const ErrorMessage: string): Integer;
    function ParseIdentifierEscape(const IsFirstChar: Boolean): Char;

    function CreateToken(const TokenType: TJSTokenType; const Value: string): TJSToken;

  public
    constructor Create(const Source: string);
    destructor Destroy; override;

    procedure Tokenize;

    function NextToken: TJSToken;
    function PeekToken(const Offset: Integer = 0): TJSToken;
    function CurrentToken: TJSToken;
    function IsEndOfTokens: Boolean;
    function HasIdentifierBetween(const FromPosition: Integer; const ToPosition: Integer;
                                  const Names: array of string): Boolean;

    property Position: Integer read FCurrentIndex;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

implementation

uses
  JS4D.NumberParse;

const
  NULL_CHAR = #0;
  TAB_CHAR = #9;
  LF_CHAR = #10;
  CR_CHAR = #13;
  VERTICAL_TAB_CHAR = #11;
  FORM_FEED_CHAR = #12;
  NO_BREAK_SPACE = #$00A0;
  BYTE_ORDER_MARK = #$FEFF;
  LINE_SEPARATOR_CHAR = #$2028;
  PARAGRAPH_SEPARATOR_CHAR = #$2029;
  ZERO_WIDTH_NON_JOINER = #$200C;
  ZERO_WIDTH_JOINER = #$200D;
  VERTICAL_TILDE = #$2E2F;
  SPACE_CHAR = ' ';
  SINGLE_QUOTE = '''';
  DOUBLE_QUOTE = '"';
  FORWARD_SLASH = '/';
  BACKSLASH = '\';
  ASTERISK = '*';
  PLUS_CHAR = '+';
  MINUS_CHAR = '-';
  EQUAL_CHAR = '=';
  EXCLAMATION = '!';
  LESS_THAN = '<';
  GREATER_THAN = '>';
  AMPERSAND = '&';
  PIPE_CHAR = '|';
  CARET_CHAR = '^';
  TILDE_CHAR = '~';
  PERCENT_CHAR = '%';
  QUESTION_CHAR = '?';
  COLON_CHAR = ':';
  SEMICOLON = ';';
  COMMA_CHAR = ',';
  DOT_CHAR = '.';
  LEFT_PAREN = '(';
  RIGHT_PAREN = ')';
  LEFT_BRACE = '{';
  RIGHT_BRACE = '}';
  LEFT_BRACKET = '[';
  RIGHT_BRACKET = ']';
  HEX_PREFIX_LOWER = 'x';
  HEX_PREFIX_UPPER = 'X';
  ZERO_CHAR = '0';
  UNDERSCORE = '_';
  DOLLAR_SIGN = '$';
  ESCAPE_N = 'n';
  ESCAPE_R = 'r';
  ESCAPE_T = 't';
  ESCAPE_B = 'b';
  ESCAPE_F = 'f';
  ESCAPE_V = 'v';
  NON_OCTAL_EIGHT = '8';
  NON_OCTAL_NINE = '9';
  MAX_THREE_DIGIT_OCTAL_START = '3';
  ESCAPE_U = 'u';
  ESCAPE_X = 'x';

  SUnterminatedStringLiteral = 'Unterminated string literal';
  SUnterminatedComment = 'Unterminated comment';
  SUnterminatedRegularExpression = 'Unterminated regular expression';
  SUnexpectedEndOfInput = 'Unexpected end of input';
  SInvalidHexEscapeSequence = 'Invalid hexadecimal escape sequence';
  SInvalidUnicodeEscapeSequence = 'Invalid Unicode escape sequence';
  SEscapeInRegularExpressionFlags = 'Regular expression flags cannot contain escape sequences';
  SIdentifierAfterNumber = 'Identifier starts immediately after a numeric literal';
  SInvalidIdentifierEscape = 'Unicode escape is not a valid identifier character';
  SMissingHexDigits = 'Hexadecimal literal has no digits';
  SMissingExponentDigits = 'Numeric literal exponent has no digits';

{ TJSLexer }

constructor TJSLexer.Create(const Source: string);
begin
  inherited Create;
  FSource := Source;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FLineStart := 1;
  FTokens := TObjectList<TJSToken>.Create(True);
  FCurrentIndex := 0;
end;

destructor TJSLexer.Destroy;
begin
  FTokens.Free;
  inherited;
end;

function TJSLexer.CurrentChar: Char;
begin
  if IsAtEnd then
    Result := NULL_CHAR
  else
    Result := FSource[FPosition];
end;

function TJSLexer.PeekChar(const Offset: Integer): Char;
begin
  const PeekPosition = FPosition + Offset;

  if (PeekPosition < 1) or (PeekPosition > Length(FSource)) then
    Result := NULL_CHAR
  else
    Result := FSource[PeekPosition];
end;

function TJSLexer.IsAtEnd: Boolean;
begin
  Result := FPosition > Length(FSource);
end;

function TJSLexer.IsLineTerminator(const Ch: Char): Boolean;
begin
  Result := (Ch = LF_CHAR) or (Ch = CR_CHAR) or (Ch = LINE_SEPARATOR_CHAR) or (Ch = PARAGRAPH_SEPARATOR_CHAR);
end;

function TJSLexer.IsWhiteSpace(const Ch: Char): Boolean;
begin
  case Ch of
    SPACE_CHAR, TAB_CHAR, VERTICAL_TAB_CHAR, FORM_FEED_CHAR, NO_BREAK_SPACE, BYTE_ORDER_MARK:
      Result := True;
  else
    Result := (Ch.GetUnicodeCategory = TUnicodeCategory.ucSpaceSeparator);
  end;
end;

procedure TJSLexer.Advance;
begin
  if not IsAtEnd then
  begin
    const IsCarriageReturnOfPair = (CurrentChar = CR_CHAR) and (PeekChar = LF_CHAR);
    if IsCarriageReturnOfPair then
    begin
      Inc(FColumn);
    end
    else if IsLineTerminator(CurrentChar) then
    begin
      Inc(FLine);
      FLineStart := FPosition + 1;
      FColumn := 1;
    end
    else
      Inc(FColumn);

    Inc(FPosition);
  end;
end;

procedure TJSLexer.SkipWhitespace;
begin
  while not IsAtEnd do
  begin
    const Ch = CurrentChar;

    if IsWhiteSpace(Ch) or IsLineTerminator(Ch) then
    begin
      Advance;
    end
    else if Ch = FORWARD_SLASH then
    begin
      const NextCh = PeekChar;

      if NextCh = FORWARD_SLASH then
        SkipSingleLineComment
      else if NextCh = ASTERISK then
        SkipMultiLineComment
      else
        Break;
    end
    else
    begin
      Break;
    end;
  end;
end;

procedure TJSLexer.SkipSingleLineComment;
begin
  while (not IsAtEnd) and (not IsLineTerminator(CurrentChar)) do
    Advance;
end;

procedure TJSLexer.SkipMultiLineComment;
begin
  Advance;
  Advance;

  while not IsAtEnd do
  begin
    if (CurrentChar = ASTERISK) and (PeekChar = FORWARD_SLASH) then
    begin
      Advance;
      Advance;
      Exit;
    end;

    Advance;
  end;

  raise TJSErrorFactory.SyntaxError(SUnterminatedComment, FLine, FColumn);
end;

function TJSLexer.ScanToken: TJSToken;
begin
  SkipWhitespace;

  if IsAtEnd then
    Exit(CreateToken(TJSTokenType.EndOfFile, ''));

  const Ch = CurrentChar;

  if IsIdentifierStart(Ch) or (Ch = BACKSLASH) then
    Exit(ScanIdentifier);

  const StartsNumber = IsDigit(Ch) or ((Ch = DOT_CHAR) and IsDigit(PeekChar));
  if StartsNumber then
    Exit(ScanNumber);

  if (Ch = SINGLE_QUOTE) or (Ch = DOUBLE_QUOTE) then
    Exit(ScanString(Ch));

  if CharInSet(Ch, [PLUS_CHAR, MINUS_CHAR, ASTERISK, FORWARD_SLASH, PERCENT_CHAR,
                    EQUAL_CHAR, EXCLAMATION, LESS_THAN, GREATER_THAN,
                    AMPERSAND, PIPE_CHAR, CARET_CHAR, TILDE_CHAR]) then
    Exit(ScanOperator);

  Result := ScanPunctuation;
end;

function TJSLexer.ScanIdentifier: TJSToken;
begin
  const StartColumn = FColumn;
  var Value := '';
  var HasEscape := False;

  while not IsAtEnd do
  begin
    if CurrentChar = BACKSLASH then
    begin
      Value := Value + ParseIdentifierEscape(Value.IsEmpty);
      HasEscape := True;
    end
    else if IsIdentifierPart(CurrentChar) then
    begin
      Value := Value + CurrentChar;
      Advance;
    end
    else
      Break;
  end;

  Result := TJSToken.Create(IdentifierTokenType(Value, HasEscape), Value, FLine, StartColumn);
  Result.HasEscape := HasEscape;
end;

function TJSLexer.IdentifierTokenType(const Name: string; const HasEscape: Boolean): TJSTokenType;
begin
  if not HasEscape then
    Exit(TJSKeywords.GetKeywordType(Name));

  if TJSKeywords.IsReservedWord(Name) then
    Result := TJSTokenType.EscapedKeyword
  else
    Result := TJSTokenType.Identifier;
end;

function TJSLexer.ScanNumber: TJSToken;
begin
  Result := ScanNumberLiteral;

  try
    RejectIdentifierAfterNumber;
  except
    Result.Free;
    raise;
  end;
end;

function TJSLexer.ScanNumberLiteral: TJSToken;
begin
  const StartColumn = FColumn;

  if (CurrentChar = ZERO_CHAR) and CharInSet(PeekChar, [HEX_PREFIX_LOWER, HEX_PREFIX_UPPER]) then
  begin
    const NumberValue = ParseHexNumber;
    Result := CreateToken(TJSTokenType.NumberLiteral, '');
    Result.NumberValue := NumberValue;
    Exit;
  end;

  const HasLeadingZero = (CurrentChar = ZERO_CHAR) and IsDigit(PeekChar);
  if HasLeadingZero and IsLegacyOctalLiteral then
  begin
    const NumberValue = ParseOctalNumber;
    Result := CreateToken(TJSTokenType.NumberLiteral, '');
    Result.NumberValue := NumberValue;
    Result.IsLegacyLiteral := True;
    Exit;
  end;

  const NumberValue = ParseDecimalNumber;
  Result := TJSToken.Create(TJSTokenType.NumberLiteral, '', FLine, StartColumn);
  Result.NumberValue := NumberValue;
  Result.IsLegacyLiteral := HasLeadingZero;
end;

function TJSLexer.IsLegacyOctalLiteral: Boolean;
begin
  var Offset := 1;
  while IsDigit(PeekChar(Offset)) do
  begin
    if not IsOctalDigit(PeekChar(Offset)) then
      Exit(False);

    Inc(Offset);
  end;

  Result := True;
end;

procedure TJSLexer.RejectIdentifierAfterNumber;
begin
  const StartsIdentifier = (IsIdentifierStart(CurrentChar) or (CurrentChar = BACKSLASH) or IsDigit(CurrentChar));
  if StartsIdentifier then
    raise TJSErrorFactory.SyntaxError(SIdentifierAfterNumber, FLine, FColumn);
end;

function TJSLexer.ParseHexNumber: Double;
begin
  Advance;
  Advance;

  var Value: Int64 := 0;
  var DigitCount := 0;

  while (not IsAtEnd) and IsHexDigit(CurrentChar) do
  begin
    const Ch = CurrentChar;
    var Digit: Integer;

    if CharInSet(Ch, ['0'..'9']) then
      Digit := Ord(Ch) - Ord('0')
    else if CharInSet(Ch, ['a'..'f']) then
      Digit := 10 + Ord(Ch) - Ord('a')
    else
      Digit := 10 + Ord(Ch) - Ord('A');

    Value := Value * 16 + Digit;
    Inc(DigitCount);
    Advance;
  end;

  const HasNoDigits = (DigitCount = 0);
  if HasNoDigits then
    raise TJSErrorFactory.SyntaxError(SMissingHexDigits, FLine, FColumn);

  Result := Value;
end;

function TJSLexer.ParseOctalNumber: Double;
begin
  Advance;

  var Value: Int64 := 0;

  while (not IsAtEnd) and IsOctalDigit(CurrentChar) do
  begin
    const Digit = Ord(CurrentChar) - Ord('0');
    Value := Value * 8 + Digit;
    Advance;
  end;

  Result := Value;
end;

function TJSLexer.ReadDigits: string;
begin
  Result := '';

  while (not IsAtEnd) and IsDigit(CurrentChar) do
  begin
    Result := Result + CurrentChar;
    Advance;
  end;
end;

function TJSLexer.ReadExponent: string;
begin
  Result := '';
  if not CharInSet(CurrentChar, ['e', 'E']) then
    Exit;

  Result := CurrentChar;
  Advance;

  if CharInSet(CurrentChar, [PLUS_CHAR, MINUS_CHAR]) then
  begin
    Result := Result + CurrentChar;
    Advance;
  end;

  const ExponentDigits = ReadDigits;
  if ExponentDigits.IsEmpty then
    raise TJSErrorFactory.SyntaxError(SMissingExponentDigits, FLine, FColumn);

  Result := Result + ExponentDigits;
end;

function TJSLexer.ParseDecimalNumber: Double;
begin
  var IntegerDigits := ReadDigits;
  if IntegerDigits.IsEmpty then
    IntegerDigits := ZERO_CHAR;

  var FractionDigits := '';
  if CurrentChar = DOT_CHAR then
  begin
    Advance;
    FractionDigits := ReadDigits;
  end;

  var NumberStr := IntegerDigits;
  if not FractionDigits.IsEmpty then
    NumberStr := NumberStr + DOT_CHAR + FractionDigits;

  NumberStr := NumberStr + ReadExponent;

  Result := TJSNumberParse.DecimalToDouble(NumberStr);
end;

function TJSLexer.ScanString(const Quote: Char): TJSToken;
begin
  const StartColumn = FColumn;
  const StartLine = FLine;
  const StartPosition = FPosition;

  Advance;

  var Value := '';
  FStringHasLegacyEscape := False;

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;

    if Ch = Quote then
    begin
      Advance;
      const SourceLength = FPosition - StartPosition;
      const QuoteCount = 2;
      Result := TJSToken.Create(TJSTokenType.StringLiteral, Value, StartLine, StartColumn);
      Result.IsLegacyLiteral := FStringHasLegacyEscape;
      Result.HasEscape := (SourceLength <> Length(Value) + QuoteCount);
      Exit;
    end;

    if Ch = BACKSLASH then
    begin
      Advance;
      Value := Value + ParseEscapeSequence;
    end
    else if (Ch = LF_CHAR) or (Ch = CR_CHAR) then
    begin
      raise TJSErrorFactory.SyntaxError(SUnterminatedStringLiteral, FLine, FColumn);
    end
    else
    begin
      Value := Value + Ch;
      Advance;
    end;
  end;

  raise TJSErrorFactory.SyntaxError(SUnterminatedStringLiteral, StartLine, StartColumn);
end;

function TJSLexer.ParseLineContinuation(const Terminator: Char): string;
begin
  const IsCarriageReturnLineFeed = (Terminator = CR_CHAR) and (CurrentChar = LF_CHAR);
  if IsCarriageReturnLineFeed then
    Advance;

  Result := '';
end;

function TJSLexer.ParseOctalEscape(const FirstDigit: Char): string;
begin
  const IsNullEscape = (FirstDigit = ZERO_CHAR) and (not IsDigit(CurrentChar));
  if IsNullEscape then
    Exit(NULL_CHAR);

  FStringHasLegacyEscape := True;

  var CodeUnit := Ord(FirstDigit) - Ord(ZERO_CHAR);
  const AllowsThreeDigits = (FirstDigit <= MAX_THREE_DIGIT_OCTAL_START);
  var RemainingDigits: Integer;
  if AllowsThreeDigits then
    RemainingDigits := 2
  else
    RemainingDigits := 1;

  while (RemainingDigits > 0) and IsOctalDigit(CurrentChar) do
  begin
    CodeUnit := CodeUnit * 8 + Ord(CurrentChar) - Ord(ZERO_CHAR);
    Dec(RemainingDigits);
    Advance;
  end;

  Result := Char(CodeUnit);
end;

function TJSLexer.ParseEscapeSequence: string;
begin
  if IsAtEnd then
    raise TJSErrorFactory.SyntaxError(SUnexpectedEndOfInput, FLine, FColumn);

  const Ch = CurrentChar;
  Advance;

  if IsLineTerminator(Ch) then
  begin
    Result := ParseLineContinuation(Ch);
    Exit;
  end;

  if IsOctalDigit(Ch) then
  begin
    Result := ParseOctalEscape(Ch);
    Exit;
  end;

  const IsNonOctalDigit = (Ch = NON_OCTAL_EIGHT) or (Ch = NON_OCTAL_NINE);
  if IsNonOctalDigit then
    FStringHasLegacyEscape := True;

  case Ch of
    ESCAPE_N:
      Result := LF_CHAR;
    ESCAPE_R:
      Result := CR_CHAR;
    ESCAPE_T:
      Result := TAB_CHAR;
    ESCAPE_B:
      Result := #8;
    ESCAPE_F:
      Result := #12;
    ESCAPE_V:
      Result := #11;
    BACKSLASH:
      Result := BACKSLASH;
    SINGLE_QUOTE:
      Result := SINGLE_QUOTE;
    DOUBLE_QUOTE:
      Result := DOUBLE_QUOTE;
    ESCAPE_X:
      Result := Char(ParseHexDigits(2, SInvalidHexEscapeSequence));
    ESCAPE_U:
      Result := Char(ParseHexDigits(4, SInvalidUnicodeEscapeSequence));
  else
    Result := Ch;
  end;
end;

function TJSLexer.ParseHexDigits(const DigitCount: Integer; const ErrorMessage: string): Integer;
begin
  Result := 0;

  for var I := 1 to DigitCount do
  begin
    const HexCh = CurrentChar;

    if not IsHexDigit(HexCh) then
      raise TJSErrorFactory.SyntaxError(ErrorMessage, FLine, FColumn);

    if CharInSet(HexCh, ['0'..'9']) then
      Result := Result * 16 + Ord(HexCh) - Ord('0')
    else if CharInSet(HexCh, ['a'..'f']) then
      Result := Result * 16 + 10 + Ord(HexCh) - Ord('a')
    else
      Result := Result * 16 + 10 + Ord(HexCh) - Ord('A');

    Advance;
  end;
end;

function TJSLexer.ParseIdentifierEscape(const IsFirstChar: Boolean): Char;
begin
  Advance;

  if CurrentChar <> ESCAPE_U then
    raise TJSErrorFactory.SyntaxError(SInvalidUnicodeEscapeSequence, FLine, FColumn);

  Advance;

  Result := Char(ParseHexDigits(4, SInvalidUnicodeEscapeSequence));

  const IsValidChar = (IsIdentifierStart(Result) or ((not IsFirstChar) and IsIdentifierPart(Result)));
  if not IsValidChar then
    raise TJSErrorFactory.SyntaxError(SInvalidIdentifierEscape, FLine, FColumn);
end;

function TJSLexer.ScanRegExp: TJSToken;
begin
  const StartColumn = FColumn;
  const StartLine = FLine;

  Advance;

  var Pattern := '';
  var InCharClass := False;

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;

    if Ch = BACKSLASH then
    begin
      Pattern := Pattern + Ch;
      Advance;

      if not IsAtEnd then
      begin
        Pattern := Pattern + CurrentChar;
        Advance;
      end;
    end
    else if Ch = LEFT_BRACKET then
    begin
      InCharClass := True;
      Pattern := Pattern + Ch;
      Advance;
    end
    else if Ch = RIGHT_BRACKET then
    begin
      InCharClass := False;
      Pattern := Pattern + Ch;
      Advance;
    end
    else if (Ch = FORWARD_SLASH) and (not InCharClass) then
    begin
      Advance;
      Break;
    end
    else if IsLineTerminator(Ch) or (Ch = CR_CHAR) then
    begin
      raise TJSErrorFactory.SyntaxError(SUnterminatedRegularExpression, FLine, FColumn);
    end
    else
    begin
      Pattern := Pattern + Ch;
      Advance;
    end;
  end;

  var Flags := '';

  while (not IsAtEnd) and IsIdentifierPart(CurrentChar) do
  begin
    Flags := Flags + CurrentChar;
    Advance;
  end;

  if CurrentChar = BACKSLASH then
    raise TJSErrorFactory.SyntaxError(SEscapeInRegularExpressionFlags, FLine, FColumn);

  Result := TJSToken.Create(TJSTokenType.RegExpLiteral, Pattern + '/' + Flags, StartLine, StartColumn);
end;

function TJSLexer.ScanOperator: TJSToken;
begin
  const StartColumn = FColumn;
  const Ch = CurrentChar;

  case Ch of
    PLUS_CHAR:
      begin
        Advance;
        if CurrentChar = PLUS_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.Increment, '++', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.PlusAssign, '+=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.Plus, '+', FLine, StartColumn));
      end;

    MINUS_CHAR:
      begin
        Advance;
        if CurrentChar = MINUS_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.Decrement, '--', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.MinusAssign, '-=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.Minus, '-', FLine, StartColumn));
      end;

    ASTERISK:
      begin
        Advance;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.MultiplyAssign, '*=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.Multiply, '*', FLine, StartColumn));
      end;

    FORWARD_SLASH:
      begin
        var IsDivisionContext := False;
        if FTokens.Count > 0 then
        begin
          const PrevToken = FTokens.Last;
          IsDivisionContext := PrevToken.TokenType in [
            TJSTokenType.Identifier,
            TJSTokenType.NumberLiteral,
            TJSTokenType.StringLiteral,
            TJSTokenType.BooleanLiteral,
            TJSTokenType.NullLiteral,
            TJSTokenType.RegExpLiteral,
            TJSTokenType.RightParen,
            TJSTokenType.RightBracket,
            TJSTokenType.RightBrace,
            TJSTokenType.Increment,
            TJSTokenType.Decrement,
            TJSTokenType.KeywordThis
          ];
        end;

        if IsDivisionContext then
        begin
          Advance;
          if CurrentChar = EQUAL_CHAR then
          begin
            Advance;
            Exit(TJSToken.Create(TJSTokenType.DivideAssign, '/=', FLine, StartColumn));
          end;
          Exit(TJSToken.Create(TJSTokenType.Divide, '/', FLine, StartColumn));
        end
        else
          Exit(ScanRegExp);
      end;

    PERCENT_CHAR:
      begin
        Advance;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.ModuloAssign, '%=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.Modulo, '%', FLine, StartColumn));
      end;

    EQUAL_CHAR:
      begin
        Advance;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          if CurrentChar = EQUAL_CHAR then
          begin
            Advance;
            Exit(TJSToken.Create(TJSTokenType.StrictEqual, '===', FLine, StartColumn));
          end;
          Exit(TJSToken.Create(TJSTokenType.Equal, '==', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.Assign, '=', FLine, StartColumn));
      end;

    EXCLAMATION:
      begin
        Advance;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          if CurrentChar = EQUAL_CHAR then
          begin
            Advance;
            Exit(TJSToken.Create(TJSTokenType.StrictNotEqual, '!==', FLine, StartColumn));
          end;
          Exit(TJSToken.Create(TJSTokenType.NotEqual, '!=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.LogicalNot, '!', FLine, StartColumn));
      end;

    LESS_THAN:
      begin
        Advance;
        if CurrentChar = LESS_THAN then
        begin
          Advance;
          if CurrentChar = EQUAL_CHAR then
          begin
            Advance;
            Exit(TJSToken.Create(TJSTokenType.LeftShiftAssign, '<<=', FLine, StartColumn));
          end;
          Exit(TJSToken.Create(TJSTokenType.LeftShift, '<<', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.LessThanOrEqual, '<=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.LessThan, '<', FLine, StartColumn));
      end;

    GREATER_THAN:
      begin
        Advance;
        if CurrentChar = GREATER_THAN then
        begin
          Advance;
          if CurrentChar = GREATER_THAN then
          begin
            Advance;
            if CurrentChar = EQUAL_CHAR then
            begin
              Advance;
              Exit(TJSToken.Create(TJSTokenType.UnsignedRightShiftAssign, '>>>=', FLine, StartColumn));
            end;
            Exit(TJSToken.Create(TJSTokenType.UnsignedRightShift, '>>>', FLine, StartColumn));
          end;
          if CurrentChar = EQUAL_CHAR then
          begin
            Advance;
            Exit(TJSToken.Create(TJSTokenType.RightShiftAssign, '>>=', FLine, StartColumn));
          end;
          Exit(TJSToken.Create(TJSTokenType.RightShift, '>>', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.GreaterThanOrEqual, '>=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.GreaterThan, '>', FLine, StartColumn));
      end;

    AMPERSAND:
      begin
        Advance;
        if CurrentChar = AMPERSAND then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.LogicalAnd, '&&', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.BitwiseAndAssign, '&=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.BitwiseAnd, '&', FLine, StartColumn));
      end;

    PIPE_CHAR:
      begin
        Advance;
        if CurrentChar = PIPE_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.LogicalOr, '||', FLine, StartColumn));
        end;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.BitwiseOrAssign, '|=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.BitwiseOr, '|', FLine, StartColumn));
      end;

    CARET_CHAR:
      begin
        Advance;
        if CurrentChar = EQUAL_CHAR then
        begin
          Advance;
          Exit(TJSToken.Create(TJSTokenType.BitwiseXorAssign, '^=', FLine, StartColumn));
        end;
        Exit(TJSToken.Create(TJSTokenType.BitwiseXor, '^', FLine, StartColumn));
      end;

    TILDE_CHAR:
      begin
        Advance;
        Exit(TJSToken.Create(TJSTokenType.BitwiseNot, '~', FLine, StartColumn));
      end;
  else
    raise TJSErrorFactory.UnexpectedToken(Ch, FLine, FColumn);
  end;
end;

function TJSLexer.ScanPunctuation: TJSToken;
begin
  const StartColumn = FColumn;
  const Ch = CurrentChar;

  Advance;

  case Ch of
    LEFT_PAREN:
      Result := TJSToken.Create(TJSTokenType.LeftParen, '(', FLine, StartColumn);
    RIGHT_PAREN:
      Result := TJSToken.Create(TJSTokenType.RightParen, ')', FLine, StartColumn);
    LEFT_BRACE:
      Result := TJSToken.Create(TJSTokenType.LeftBrace, '{', FLine, StartColumn);
    RIGHT_BRACE:
      Result := TJSToken.Create(TJSTokenType.RightBrace, '}', FLine, StartColumn);
    LEFT_BRACKET:
      Result := TJSToken.Create(TJSTokenType.LeftBracket, '[', FLine, StartColumn);
    RIGHT_BRACKET:
      Result := TJSToken.Create(TJSTokenType.RightBracket, ']', FLine, StartColumn);
    SEMICOLON:
      Result := TJSToken.Create(TJSTokenType.Semicolon, ';', FLine, StartColumn);
    COMMA_CHAR:
      Result := TJSToken.Create(TJSTokenType.Comma, ',', FLine, StartColumn);
    COLON_CHAR:
      Result := TJSToken.Create(TJSTokenType.Colon, ':', FLine, StartColumn);
    DOT_CHAR:
      Result := TJSToken.Create(TJSTokenType.Dot, '.', FLine, StartColumn);
    QUESTION_CHAR:
      Result := TJSToken.Create(TJSTokenType.Question, '?', FLine, StartColumn);
  else
    raise TJSErrorFactory.UnexpectedToken(Ch, FLine, StartColumn);
  end;
end;

function TJSLexer.IsIdentifierStart(const Ch: Char): Boolean;
begin
  const IsLetterLike = Ch.IsLetter or (Ch.GetUnicodeCategory = TUnicodeCategory.ucLetterNumber);

  Result := (IsLetterLike and (Ch <> VERTICAL_TILDE)) or (Ch = UNDERSCORE) or (Ch = DOLLAR_SIGN);
end;

function TJSLexer.IsIdentifierPart(const Ch: Char): Boolean;
begin
  const IsCombiningOrConnector = (Ch.GetUnicodeCategory in [TUnicodeCategory.ucNonSpacingMark,
                                                           TUnicodeCategory.ucCombiningMark,
                                                           TUnicodeCategory.ucDecimalNumber,
                                                           TUnicodeCategory.ucConnectPunctuation]);
  const IsJoiner = (Ch = ZERO_WIDTH_NON_JOINER) or (Ch = ZERO_WIDTH_JOINER);

  Result := IsIdentifierStart(Ch) or IsCombiningOrConnector or IsJoiner;
end;

function TJSLexer.IsDigit(const Ch: Char): Boolean;
begin
  Result := CharInSet(Ch, ['0'..'9']);
end;

function TJSLexer.IsHexDigit(const Ch: Char): Boolean;
begin
  Result := CharInSet(Ch, ['0'..'9', 'a'..'f', 'A'..'F']);
end;

function TJSLexer.IsOctalDigit(const Ch: Char): Boolean;
begin
  Result := CharInSet(Ch, ['0'..'7']);
end;

function TJSLexer.CreateToken(const TokenType: TJSTokenType; const Value: string): TJSToken;
begin
  Result := TJSToken.Create(TokenType, Value, FLine, FColumn);
end;

procedure TJSLexer.Tokenize;
begin
  FTokens.Clear;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FCurrentIndex := 0;

  while not IsAtEnd do
  begin
    const Token = ScanToken;
    FTokens.Add(Token);

    if Token.TokenType = TJSTokenType.EndOfFile then
      Break;
  end;

  if (FTokens.Count = 0) or (FTokens.Last.TokenType <> TJSTokenType.EndOfFile) then
    FTokens.Add(CreateToken(TJSTokenType.EndOfFile, ''));
end;

function TJSLexer.NextToken: TJSToken;
begin
  if FCurrentIndex < FTokens.Count then
  begin
    Result := FTokens[FCurrentIndex];
    Inc(FCurrentIndex);
  end
  else
    Result := FTokens.Last;
end;

function TJSLexer.PeekToken(const Offset: Integer): TJSToken;
begin
  const Index = FCurrentIndex + Offset;

  if (Index >= 0) and (Index < FTokens.Count) then
    Result := FTokens[Index]
  else
    Result := FTokens.Last;
end;

function TJSLexer.CurrentToken: TJSToken;
begin
  Result := PeekToken(0);
end;

function TJSLexer.IsEndOfTokens: Boolean;
begin
  Result := FCurrentIndex >= FTokens.Count;
end;

function TJSLexer.HasIdentifierBetween(const FromPosition: Integer; const ToPosition: Integer;
                                       const Names: array of string): Boolean;
begin
  const LastIndex = Min(ToPosition, FTokens.Count) - 1;

  for var Index := Max(FromPosition, 0) to LastIndex do
  begin
    const Token = FTokens[Index];
    if Token.TokenType <> TJSTokenType.Identifier then
      Continue;

    if MatchStr(Token.Value, Names) then
      Exit(True);
  end;

  Result := False;
end;

end.
