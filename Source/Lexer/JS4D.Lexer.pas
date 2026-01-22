unit JS4D.Lexer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Character,
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

    function CurrentChar: Char;
    function PeekChar(const Offset: Integer = 1): Char;
    function IsAtEnd: Boolean;
    procedure Advance;
    procedure SkipWhitespace;
    procedure SkipSingleLineComment;
    procedure SkipMultiLineComment;

    function ScanToken: TJSToken;
    function ScanIdentifier: TJSToken;
    function ScanNumber: TJSToken;
    function ScanString(const Quote: Char): TJSToken;
    function ScanRegExp: TJSToken;
    function ScanOperator: TJSToken;
    function ScanPunctuation: TJSToken;

    function IsIdentifierStart(const Ch: Char): Boolean;
    function IsIdentifierPart(const Ch: Char): Boolean;
    function IsDigit(const Ch: Char): Boolean;
    function IsHexDigit(const Ch: Char): Boolean;
    function IsOctalDigit(const Ch: Char): Boolean;

    function ParseHexNumber: Double;
    function ParseOctalNumber: Double;
    function ParseDecimalNumber: Double;
    function ParseEscapeSequence: Char;

    function CreateToken(const TokenType: TJSTokenType; const Value: string): TJSToken;

  public
    constructor Create(const Source: string);
    destructor Destroy; override;

    procedure Tokenize;

    function NextToken: TJSToken;
    function PeekToken(const Offset: Integer = 0): TJSToken;
    function CurrentToken: TJSToken;
    function IsEndOfTokens: Boolean;

    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

implementation

const
  NULL_CHAR = #0;
  TAB_CHAR = #9;
  LF_CHAR = #10;
  CR_CHAR = #13;
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
  ESCAPE_0 = '0';
  ESCAPE_U = 'u';
  ESCAPE_X = 'x';

  SUnterminatedStringLiteral = 'Unterminated string literal';
  SUnterminatedComment = 'Unterminated comment';
  SUnterminatedRegularExpression = 'Unterminated regular expression';
  SUnexpectedEndOfInput = 'Unexpected end of input';
  SInvalidHexEscapeSequence = 'Invalid hexadecimal escape sequence';
  SInvalidUnicodeEscapeSequence = 'Invalid Unicode escape sequence';

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

procedure TJSLexer.Advance;
begin
  if not IsAtEnd then
  begin
    if CurrentChar = LF_CHAR then
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

    case Ch of
      SPACE_CHAR, TAB_CHAR, CR_CHAR, LF_CHAR:
        Advance;

      FORWARD_SLASH:
        begin
          const NextCh = PeekChar;

          if NextCh = FORWARD_SLASH then
            SkipSingleLineComment
          else if NextCh = ASTERISK then
            SkipMultiLineComment
          else
            Break;
        end;
    else
      Break;
    end;
  end;
end;

procedure TJSLexer.SkipSingleLineComment;
begin
  while (not IsAtEnd) and (CurrentChar <> LF_CHAR) do
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

  if IsIdentifierStart(Ch) then
    Exit(ScanIdentifier);

  if IsDigit(Ch) then
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

  while (not IsAtEnd) and IsIdentifierPart(CurrentChar) do
  begin
    Value := Value + CurrentChar;
    Advance;
  end;

  const TokenType = TJSKeywords.GetKeywordType(Value);
  Result := TJSToken.Create(TokenType, Value, FLine, StartColumn);
end;

function TJSLexer.ScanNumber: TJSToken;
begin
  const StartColumn = FColumn;

  if (CurrentChar = ZERO_CHAR) and CharInSet(PeekChar, [HEX_PREFIX_LOWER, HEX_PREFIX_UPPER]) then
  begin
    const NumberValue = ParseHexNumber;
    Result := CreateToken(TJSTokenType.NumberLiteral, '');
    Result.NumberValue := NumberValue;
    Exit;
  end;

  if (CurrentChar = ZERO_CHAR) and IsOctalDigit(PeekChar) then
  begin
    const NumberValue = ParseOctalNumber;
    Result := CreateToken(TJSTokenType.NumberLiteral, '');
    Result.NumberValue := NumberValue;
    Result.IsOctal := True;
    Exit;
  end;

  const NumberValue = ParseDecimalNumber;
  Result := TJSToken.Create(TJSTokenType.NumberLiteral, '', FLine, StartColumn);
  Result.NumberValue := NumberValue;
end;

function TJSLexer.ParseHexNumber: Double;
begin
  Advance;
  Advance;

  var Value: Int64 := 0;

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
    Advance;
  end;

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

function TJSLexer.ParseDecimalNumber: Double;
begin
  var NumberStr := '';

  while (not IsAtEnd) and IsDigit(CurrentChar) do
  begin
    NumberStr := NumberStr + CurrentChar;
    Advance;
  end;

  if (CurrentChar = DOT_CHAR) and IsDigit(PeekChar) then
  begin
    NumberStr := NumberStr + CurrentChar;
    Advance;

    while (not IsAtEnd) and IsDigit(CurrentChar) do
    begin
      NumberStr := NumberStr + CurrentChar;
      Advance;
    end;
  end;

  if CharInSet(CurrentChar, ['e', 'E']) then
  begin
    NumberStr := NumberStr + CurrentChar;
    Advance;

    if CharInSet(CurrentChar, [PLUS_CHAR, MINUS_CHAR]) then
    begin
      NumberStr := NumberStr + CurrentChar;
      Advance;
    end;

    while (not IsAtEnd) and IsDigit(CurrentChar) do
    begin
      NumberStr := NumberStr + CurrentChar;
      Advance;
    end;
  end;

  Result := StrToFloat(NumberStr, TFormatSettings.Invariant);
end;

function TJSLexer.ScanString(const Quote: Char): TJSToken;
begin
  const StartColumn = FColumn;
  const StartLine = FLine;

  Advance;

  var Value := '';

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;

    if Ch = Quote then
    begin
      Advance;
      Exit(TJSToken.Create(TJSTokenType.StringLiteral, Value, StartLine, StartColumn));
    end;

    if Ch = BACKSLASH then
    begin
      Advance;
      Value := Value + ParseEscapeSequence;
    end
    else if Ch = LF_CHAR then
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

function TJSLexer.ParseEscapeSequence: Char;
begin
  if IsAtEnd then
    raise TJSErrorFactory.SyntaxError(SUnexpectedEndOfInput, FLine, FColumn);

  const Ch = CurrentChar;
  Advance;

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
    ESCAPE_0:
      Result := NULL_CHAR;
    BACKSLASH:
      Result := BACKSLASH;
    SINGLE_QUOTE:
      Result := SINGLE_QUOTE;
    DOUBLE_QUOTE:
      Result := DOUBLE_QUOTE;
    ESCAPE_X:
      begin
        var HexValue := 0;
        for var I := 1 to 2 do
        begin
          if not IsHexDigit(CurrentChar) then
            raise TJSErrorFactory.SyntaxError(SInvalidHexEscapeSequence, FLine, FColumn);

          const HexCh = CurrentChar;

          if CharInSet(HexCh, ['0'..'9']) then
            HexValue := HexValue * 16 + Ord(HexCh) - Ord('0')
          else if CharInSet(HexCh, ['a'..'f']) then
            HexValue := HexValue * 16 + 10 + Ord(HexCh) - Ord('a')
          else
            HexValue := HexValue * 16 + 10 + Ord(HexCh) - Ord('A');

          Advance;
        end;
        Result := Char(HexValue);
      end;
    ESCAPE_U:
      begin
        var UnicodeValue := 0;
        for var I := 1 to 4 do
        begin
          if not IsHexDigit(CurrentChar) then
            raise TJSErrorFactory.SyntaxError(SInvalidUnicodeEscapeSequence, FLine, FColumn);

          const HexCh = CurrentChar;

          if CharInSet(HexCh, ['0'..'9']) then
            UnicodeValue := UnicodeValue * 16 + Ord(HexCh) - Ord('0')
          else if CharInSet(HexCh, ['a'..'f']) then
            UnicodeValue := UnicodeValue * 16 + 10 + Ord(HexCh) - Ord('a')
          else
            UnicodeValue := UnicodeValue * 16 + 10 + Ord(HexCh) - Ord('A');

          Advance;
        end;
        Result := Char(UnicodeValue);
      end;
  else
    Result := Ch;
  end;
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
    else if Ch = LF_CHAR then
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
  Result := Ch.IsLetter or (Ch = UNDERSCORE) or (Ch = DOLLAR_SIGN);
end;

function TJSLexer.IsIdentifierPart(const Ch: Char): Boolean;
begin
  Result := IsIdentifierStart(Ch) or IsDigit(Ch);
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

end.
