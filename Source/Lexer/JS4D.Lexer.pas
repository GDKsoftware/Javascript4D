unit JS4D.Lexer;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.SlashContext,
  JS4D.Errors;

type
  TJSLexer = class
  private
    type
      TTokenStart = record
        Line: Integer;
        Column: Integer;
        Offset: Integer;
        LineTerminatorBefore: Boolean;
        constructor Create(const Line: Integer; const Column: Integer; const Offset: Integer;
                           const LineTerminatorBefore: Boolean);
      end;

      TNumberLiteral = record
        Value: Double;
        IsLegacy: Boolean;
        constructor Create(const Value: Double; const IsLegacy: Boolean);
      end;

      TStringEscape = record
        Value: string;
        IsLegacy: Boolean;
        constructor Create(const Value: string; const IsLegacy: Boolean);
      end;

      TStringContent = record
        Value: string;
        HasEscape: Boolean;
        HasLegacyEscape: Boolean;
        constructor Create(const Value: string; const HasEscape: Boolean; const HasLegacyEscape: Boolean);
      end;

      TTemplatePiece = record
        Cooked: string;
        Raw: string;
        IsInvalid: Boolean;
        constructor Create(const Cooked: string; const Raw: string; const IsInvalid: Boolean);
        procedure Append(const Piece: TTemplatePiece);
      end;

    var
      FSource: string;
      FPosition: Integer;
      FLine: Integer;
      FColumn: Integer;
      FTokens: TObjectList<TJSToken>;
      FCurrentIndex: Integer;
      FBraceDepth: Integer;
      FSubstitutionDepths: TStack<Integer>;
      FSlashContext: TJSSlashContext;
      FTokenStart: TTokenStart;

    function CurrentChar: Char;
    function PeekChar(const Offset: Integer = 1): Char;
    function IsAtEnd: Boolean;
    procedure Advance;
    procedure AdvanceBy(const Count: Integer);
    function ConsumeChar: Char;
    procedure SkipLineFeedAfter(const Terminator: Char);
    procedure SkipWhitespace;
    procedure SkipSingleLineComment;
    procedure SkipMultiLineComment;

    procedure MarkTokenStart;
    function NewToken(const TokenType: TJSTokenType; const Value: string): TJSToken; overload;
    function NewToken(const TokenType: TJSTokenType; const Value: string;
                      const Details: TJSTokenDetails): TJSToken; overload;
    function NewEndOfFileToken: TJSToken;

    function ScanToken: TJSToken;
    function ScanIdentifier: TJSToken;
    function IdentifierTokenType(const Name: string; const HasEscape: Boolean): TJSTokenType;
    function ScanNumber: TJSToken;
    function ReadNumberLiteral: TNumberLiteral;
    procedure RejectIdentifierAfterNumber;
    function ScanString(const Quote: Char): TJSToken;
    function ScanRegExp: TJSToken;
    function ScanPunctuator: TJSToken;
    function FindPunctuatorAhead: Integer;
    procedure TrackBraceDepth(const TokenType: TJSTokenType);
    function StartsWithText(const Text: string): Boolean;
    function ScanTemplateHead: TJSToken;
    function ScanTemplateContinuation: TJSToken;

    function StartsIdentifierAhead(const IsFirstChar: Boolean): Boolean;
    function ReadCodePointText: string;

    function ParseRadixNumber(const Radix: Integer): Double;
    function ParseOctalNumber: Double;
    procedure ConsumeSeparatorBeforeDigit(const Radix: Integer);
    function ReadDigits(const AllowSeparators: Boolean): string;
    function ReadExponent(const AllowSeparators: Boolean): string;
    function ParseDecimalNumber(const AllowSeparators: Boolean): Double;
    function IsLegacyOctalLiteral: Boolean;

    function ReadStringContent(const Quote: Char): TStringContent;
    function ReadStringEscape: TStringEscape;
    function ReadOctalEscape(const FirstDigit: Char): TStringEscape;
    function ReadSimpleEscapeValue(const Escape: Char): string;
    function ParseUnicodeEscape: string;
    function ParseIdentifierEscape(const IsFirstChar: Boolean): string;

    function ScanTemplateChunk(const IsHead: Boolean): TJSToken;
    function CreateTemplateChunk(const Text: TTemplatePiece; const IsHead: Boolean;
                                 const IsTail: Boolean): TJSToken;
    function ReadTemplateElement: TTemplatePiece;
    function ClosesTemplateSubstitution: Boolean;
    function ReadTemplateLineTerminator: TTemplatePiece;
    function ReadTemplateEscape: TTemplatePiece;
    function ReadTemplateLineContinuation: TTemplatePiece;
    function TryReadEscapeValue(const Escape: Char; out Value: string): Boolean;
    function TryReadHexEscape(out Value: string): Boolean;
    function TryReadUnicodeEscape(out Value: string): Boolean;
    function TryReadHexDigits(const DigitCount: Integer; out Value: Integer): Boolean;
    function TryReadCodePointEscape(out Value: string): Boolean;
    function CodePointToText(const CodePoint: Integer): string;

    function ReadRegExpBody: string;
    function ReadRegExpEscape: string;
    function ReadRegExpFlags: string;

  public
    constructor Create(const Source: string);
    destructor Destroy; override;

    procedure Tokenize;

    function NextToken: TJSToken;
    function PeekToken(const Offset: Integer = 0): TJSToken;
    function CurrentToken: TJSToken;
    function SourceSlice(const StartOffset: Integer; const EndOffset: Integer): string;
    function HasIdentifierBetween(const FromTokenIndex: Integer; const ToTokenIndex: Integer;
                                  const Names: array of string): Boolean;

    property TokenIndex: Integer read FCurrentIndex;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

implementation

uses
  System.Character,
  System.Math,
  System.StrUtils,
  JS4D.AsciiDigits,
  JS4D.JsWhiteSpace,
  JS4D.LexicalCharacters,
  JS4D.NumberParse,
  JS4D.Utf16;

type
  TPunctuator = record
    Text: string;
    TokenType: TJSTokenType;
  end;

const
  NULL_CHAR = #0;
  LF_CHAR = #10;
  CR_CHAR = #13;
  SINGLE_QUOTE = '''';
  DOUBLE_QUOTE = '"';
  FORWARD_SLASH = '/';
  BACKSLASH = '\';
  ASTERISK = '*';
  DOT_CHAR = '.';
  LEFT_BRACE = '{';
  RIGHT_BRACE = '}';
  LEFT_BRACKET = '[';
  RIGHT_BRACKET = ']';
  UNDERSCORE = '_';
  DOLLAR_SIGN = '$';
  BACKTICK = '`';
  ZERO_CHAR = '0';
  DIGIT_ONE = '1';
  DIGIT_EIGHT = '8';
  DIGIT_NINE = '9';
  LAST_DIGIT_OF_THREE_DIGIT_OCTAL_START = '3';
  ESCAPE_U = 'u';
  ESCAPE_X = 'x';

  HEX_RADIX = 16;
  OCTAL_RADIX = 8;
  DECIMAL_RADIX = 10;
  RADIX_PREFIX_LENGTH = 2;
  COMMENT_DELIMITER_LENGTH = 2;
  HEX_ESCAPE_DIGITS = 2;
  UNICODE_ESCAPE_DIGITS = 4;
  LONG_OCTAL_ESCAPE_REMAINING_DIGITS = 2;
  SHORT_OCTAL_ESCAPE_REMAINING_DIGITS = 1;
  TEMPLATE_SUBSTITUTION_OPENER_LENGTH = 2;
  MAX_BASIC_PLANE_CODE_POINT = $FFFF;
  NO_PUNCTUATOR = -1;

  UNTERMINATED_TEMPLATE_MESSAGE = 'Unterminated template literal';
  UNTERMINATED_STRING_MESSAGE = 'Unterminated string literal';
  UNTERMINATED_COMMENT_MESSAGE = 'Unterminated comment';
  UNTERMINATED_REGEXP_MESSAGE = 'Unterminated regular expression';
  UNEXPECTED_END_OF_INPUT_MESSAGE = 'Unexpected end of input';
  INVALID_HEX_ESCAPE_MESSAGE = 'Invalid hexadecimal escape sequence';
  INVALID_UNICODE_ESCAPE_MESSAGE = 'Invalid Unicode escape sequence';
  ESCAPE_IN_REGEXP_FLAGS_MESSAGE = 'Regular expression flags cannot contain escape sequences';
  IDENTIFIER_AFTER_NUMBER_MESSAGE = 'Identifier starts immediately after a numeric literal';
  INVALID_IDENTIFIER_ESCAPE_MESSAGE = 'Unicode escape is not a valid identifier character';
  MISSING_RADIX_DIGITS_MESSAGE = 'Numeric literal has no digits after its radix prefix';
  MISSING_EXPONENT_DIGITS_MESSAGE = 'Numeric literal exponent has no digits';
  MISPLACED_NUMERIC_SEPARATOR_MESSAGE = 'Numeric separators are only allowed between digits';

  PUNCTUATORS: array[0..52] of TPunctuator = (
    (Text: '>>>='; TokenType: TJSTokenType.UnsignedRightShiftAssign),
    (Text: '...'; TokenType: TJSTokenType.Ellipsis),
    (Text: '**='; TokenType: TJSTokenType.ExponentAssign),
    (Text: '==='; TokenType: TJSTokenType.StrictEqual),
    (Text: '!=='; TokenType: TJSTokenType.StrictNotEqual),
    (Text: '<<='; TokenType: TJSTokenType.LeftShiftAssign),
    (Text: '>>='; TokenType: TJSTokenType.RightShiftAssign),
    (Text: '>>>'; TokenType: TJSTokenType.UnsignedRightShift),
    (Text: '++'; TokenType: TJSTokenType.Increment),
    (Text: '--'; TokenType: TJSTokenType.Decrement),
    (Text: '+='; TokenType: TJSTokenType.PlusAssign),
    (Text: '-='; TokenType: TJSTokenType.MinusAssign),
    (Text: '*='; TokenType: TJSTokenType.MultiplyAssign),
    (Text: '**'; TokenType: TJSTokenType.Exponent),
    (Text: '/='; TokenType: TJSTokenType.DivideAssign),
    (Text: '%='; TokenType: TJSTokenType.ModuloAssign),
    (Text: '=='; TokenType: TJSTokenType.Equal),
    (Text: '=>'; TokenType: TJSTokenType.Arrow),
    (Text: '!='; TokenType: TJSTokenType.NotEqual),
    (Text: '<='; TokenType: TJSTokenType.LessThanOrEqual),
    (Text: '>='; TokenType: TJSTokenType.GreaterThanOrEqual),
    (Text: '<<'; TokenType: TJSTokenType.LeftShift),
    (Text: '>>'; TokenType: TJSTokenType.RightShift),
    (Text: '&&'; TokenType: TJSTokenType.LogicalAnd),
    (Text: '||'; TokenType: TJSTokenType.LogicalOr),
    (Text: '&='; TokenType: TJSTokenType.BitwiseAndAssign),
    (Text: '|='; TokenType: TJSTokenType.BitwiseOrAssign),
    (Text: '^='; TokenType: TJSTokenType.BitwiseXorAssign),
    (Text: '??'; TokenType: TJSTokenType.NullishCoalesce),
    (Text: '+'; TokenType: TJSTokenType.Plus),
    (Text: '-'; TokenType: TJSTokenType.Minus),
    (Text: '*'; TokenType: TJSTokenType.Multiply),
    (Text: '/'; TokenType: TJSTokenType.Divide),
    (Text: '%'; TokenType: TJSTokenType.Modulo),
    (Text: '='; TokenType: TJSTokenType.Assign),
    (Text: '!'; TokenType: TJSTokenType.LogicalNot),
    (Text: '<'; TokenType: TJSTokenType.LessThan),
    (Text: '>'; TokenType: TJSTokenType.GreaterThan),
    (Text: '&'; TokenType: TJSTokenType.BitwiseAnd),
    (Text: '|'; TokenType: TJSTokenType.BitwiseOr),
    (Text: '^'; TokenType: TJSTokenType.BitwiseXor),
    (Text: '~'; TokenType: TJSTokenType.BitwiseNot),
    (Text: '('; TokenType: TJSTokenType.LeftParen),
    (Text: ')'; TokenType: TJSTokenType.RightParen),
    (Text: '{'; TokenType: TJSTokenType.LeftBrace),
    (Text: '}'; TokenType: TJSTokenType.RightBrace),
    (Text: '['; TokenType: TJSTokenType.LeftBracket),
    (Text: ']'; TokenType: TJSTokenType.RightBracket),
    (Text: ';'; TokenType: TJSTokenType.Semicolon),
    (Text: ','; TokenType: TJSTokenType.Comma),
    (Text: ':'; TokenType: TJSTokenType.Colon),
    (Text: '.'; TokenType: TJSTokenType.Dot),
    (Text: '?'; TokenType: TJSTokenType.Question)
  );

{ TJSLexer.TTokenStart }

constructor TJSLexer.TTokenStart.Create(const Line: Integer; const Column: Integer; const Offset: Integer;
                                        const LineTerminatorBefore: Boolean);
begin
  Self.Line := Line;
  Self.Column := Column;
  Self.Offset := Offset;
  Self.LineTerminatorBefore := LineTerminatorBefore;
end;

{ TJSLexer.TNumberLiteral }

constructor TJSLexer.TNumberLiteral.Create(const Value: Double; const IsLegacy: Boolean);
begin
  Self.Value := Value;
  Self.IsLegacy := IsLegacy;
end;

{ TJSLexer.TStringEscape }

constructor TJSLexer.TStringEscape.Create(const Value: string; const IsLegacy: Boolean);
begin
  Self.Value := Value;
  Self.IsLegacy := IsLegacy;
end;

{ TJSLexer.TStringContent }

constructor TJSLexer.TStringContent.Create(const Value: string; const HasEscape: Boolean;
                                           const HasLegacyEscape: Boolean);
begin
  Self.Value := Value;
  Self.HasEscape := HasEscape;
  Self.HasLegacyEscape := HasLegacyEscape;
end;

{ TJSLexer.TTemplatePiece }

constructor TJSLexer.TTemplatePiece.Create(const Cooked: string; const Raw: string; const IsInvalid: Boolean);
begin
  Self.Cooked := Cooked;
  Self.Raw := Raw;
  Self.IsInvalid := IsInvalid;
end;

procedure TJSLexer.TTemplatePiece.Append(const Piece: TTemplatePiece);
begin
  Cooked := Cooked + Piece.Cooked;
  Raw := Raw + Piece.Raw;
  IsInvalid := (IsInvalid or Piece.IsInvalid);
end;

{ TJSLexer }

constructor TJSLexer.Create(const Source: string);
begin
  inherited Create;
  FSource := Source;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FTokens := TObjectList<TJSToken>.Create(True);
  FSubstitutionDepths := TStack<Integer>.Create;
  FSlashContext := TJSSlashContext.Create;
  FCurrentIndex := 0;
end;

destructor TJSLexer.Destroy;
begin
  FSlashContext.Free;
  FSubstitutionDepths.Free;
  FTokens.Free;
  inherited;
end;

procedure TJSLexer.Tokenize;
begin
  FTokens.Clear;
  FPosition := 1;
  FLine := 1;
  FColumn := 1;
  FCurrentIndex := 0;
  FBraceDepth := 0;
  FSubstitutionDepths.Clear;
  FSlashContext.Reset;

  while not IsAtEnd do
  begin
    const Token = ScanToken;
    FTokens.Add(Token);
    FSlashContext.Observe(Token);

    if Token.TokenType = TJSTokenType.EndOfFile then
      Break;
  end;

  const EndsWithEndOfFile = ((FTokens.Count > 0) and (FTokens.Last.TokenType = TJSTokenType.EndOfFile));
  if not EndsWithEndOfFile then
    FTokens.Add(NewEndOfFileToken);
end;

function TJSLexer.NextToken: TJSToken;
begin
  if FCurrentIndex < FTokens.Count then
  begin
    Result := FTokens[FCurrentIndex];
    Inc(FCurrentIndex);
  end
  else
  begin
    Result := FTokens.Last;
  end;
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

function TJSLexer.SourceSlice(const StartOffset: Integer; const EndOffset: Integer): string;
begin
  Result := Copy(FSource, StartOffset, EndOffset - StartOffset);
end;

function TJSLexer.HasIdentifierBetween(const FromTokenIndex: Integer; const ToTokenIndex: Integer;
                                       const Names: array of string): Boolean;
begin
  const LastIndex = Min(ToTokenIndex, FTokens.Count) - 1;

  for var Index := Max(FromTokenIndex, 0) to LastIndex do
  begin
    const Token = FTokens[Index];
    if Token.TokenType <> TJSTokenType.Identifier then
      Continue;

    if MatchStr(Token.Value, Names) then
      Exit(True);
  end;

  Result := False;
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
  if IsAtEnd then
    Exit;

  const IsCarriageReturnOfPair = ((CurrentChar = CR_CHAR) and (PeekChar = LF_CHAR));
  const StartsNewLine = (TJSLexicalCharacters.IsLineTerminator(CurrentChar) and (not IsCarriageReturnOfPair));
  if StartsNewLine then
  begin
    Inc(FLine);
    FColumn := 1;
  end
  else
  begin
    Inc(FColumn);
  end;

  Inc(FPosition);
end;

procedure TJSLexer.AdvanceBy(const Count: Integer);
begin
  var Remaining := Count;

  while Remaining > 0 do
  begin
    Advance;
    Dec(Remaining);
  end;
end;

function TJSLexer.ConsumeChar: Char;
begin
  Result := CurrentChar;
  Advance;
end;

procedure TJSLexer.SkipLineFeedAfter(const Terminator: Char);
begin
  const IsCarriageReturnLineFeed = ((Terminator = CR_CHAR) and (CurrentChar = LF_CHAR));
  if IsCarriageReturnLineFeed then
    Advance;
end;

procedure TJSLexer.SkipWhitespace;
begin
  while not IsAtEnd do
  begin
    const Ch = CurrentChar;
    const Next = PeekChar;
    const IsSpace = TJSWhiteSpace.IsWhiteSpace(Ch);
    const StartsLineComment = ((Ch = FORWARD_SLASH) and (Next = FORWARD_SLASH));
    const StartsBlockComment = ((Ch = FORWARD_SLASH) and (Next = ASTERISK));

    if IsSpace then
      Advance
    else if StartsLineComment then
      SkipSingleLineComment
    else if StartsBlockComment then
      SkipMultiLineComment
    else
      Break;
  end;
end;

procedure TJSLexer.SkipSingleLineComment;
begin
  while (not IsAtEnd) and (not TJSLexicalCharacters.IsLineTerminator(CurrentChar)) do
  begin
    Advance;
  end;
end;

procedure TJSLexer.SkipMultiLineComment;
begin
  AdvanceBy(COMMENT_DELIMITER_LENGTH);

  while not IsAtEnd do
  begin
    const EndsComment = ((CurrentChar = ASTERISK) and (PeekChar = FORWARD_SLASH));
    if EndsComment then
    begin
      AdvanceBy(COMMENT_DELIMITER_LENGTH);
      Exit;
    end;

    Advance;
  end;

  raise TJSErrorFactory.SyntaxError(UNTERMINATED_COMMENT_MESSAGE, FLine, FColumn);
end;

procedure TJSLexer.MarkTokenStart;
begin
  const LineBeforeWhitespace = FLine;
  SkipWhitespace;

  const CrossedLineTerminator = (FLine > LineBeforeWhitespace);
  FTokenStart := TTokenStart.Create(FLine, FColumn, FPosition, CrossedLineTerminator);
end;

function TJSLexer.NewToken(const TokenType: TJSTokenType; const Value: string): TJSToken;
begin
  Result := NewToken(TokenType, Value, Default(TJSTokenDetails));
end;

function TJSLexer.NewToken(const TokenType: TJSTokenType; const Value: string;
                           const Details: TJSTokenDetails): TJSToken;
begin
  var Stamped := Details;
  Stamped.StartOffset := FTokenStart.Offset;
  Stamped.EndOffset := FPosition;
  Stamped.LineTerminatorBefore := FTokenStart.LineTerminatorBefore;

  Result := TJSToken.Create(TokenType, Value, FTokenStart.Line, FTokenStart.Column, Stamped);
end;

function TJSLexer.NewEndOfFileToken: TJSToken;
begin
  Result := TJSToken.Create(TJSTokenType.EndOfFile, '', FLine, FColumn, Default(TJSTokenDetails));
end;

function TJSLexer.ScanToken: TJSToken;
begin
  MarkTokenStart;

  if IsAtEnd then
    Exit(NewToken(TJSTokenType.EndOfFile, ''));

  const Ch = CurrentChar;
  const StartsIdentifier = (StartsIdentifierAhead(True) or (Ch = BACKSLASH));
  const StartsNumber = (TJSAsciiDigits.IsDigit(Ch) or ((Ch = DOT_CHAR) and TJSAsciiDigits.IsDigit(PeekChar)));
  const StartsString = ((Ch = SINGLE_QUOTE) or (Ch = DOUBLE_QUOTE));
  const StartsTemplate = (Ch = BACKTICK);
  const ClosesSubstitution = ((Ch = RIGHT_BRACE) and ClosesTemplateSubstitution);
  const StartsRegExp = ((Ch = FORWARD_SLASH) and (not FSlashContext.IsDivisionNext));

  if StartsIdentifier then
    Result := ScanIdentifier
  else if StartsNumber then
    Result := ScanNumber
  else if StartsString then
    Result := ScanString(Ch)
  else if StartsTemplate then
    Result := ScanTemplateHead
  else if ClosesSubstitution then
    Result := ScanTemplateContinuation
  else if StartsRegExp then
    Result := ScanRegExp
  else
    Result := ScanPunctuator;
end;

function TJSLexer.ScanPunctuator: TJSToken;
begin
  const Index = FindPunctuatorAhead;
  const HasPunctuator = (Index <> NO_PUNCTUATOR);
  if not HasPunctuator then
    raise TJSErrorFactory.UnexpectedToken(CurrentChar, FLine, FColumn);

  const Punctuator = PUNCTUATORS[Index];
  AdvanceBy(Length(Punctuator.Text));

  Result := NewToken(Punctuator.TokenType, Punctuator.Text);
  TrackBraceDepth(Punctuator.TokenType);
end;

function TJSLexer.FindPunctuatorAhead: Integer;
begin
  const Ch = CurrentChar;

  for var Index := Low(PUNCTUATORS) to High(PUNCTUATORS) do
  begin
    const MatchesFirstChar = (PUNCTUATORS[Index].Text[1] = Ch);
    if MatchesFirstChar and StartsWithText(PUNCTUATORS[Index].Text) then
      Exit(Index);
  end;

  Result := NO_PUNCTUATOR;
end;

procedure TJSLexer.TrackBraceDepth(const TokenType: TJSTokenType);
begin
  if TokenType = TJSTokenType.LeftBrace then
    Inc(FBraceDepth)
  else if TokenType = TJSTokenType.RightBrace then
    Dec(FBraceDepth);
end;

function TJSLexer.StartsWithText(const Text: string): Boolean;
begin
  const LastPosition = FPosition + Length(Text) - 1;
  if LastPosition > Length(FSource) then
    Exit(False);

  for var Offset := 0 to Length(Text) - 1 do
  begin
    if FSource[FPosition + Offset] <> Text[Offset + 1] then
      Exit(False);
  end;

  Result := True;
end;

function TJSLexer.ClosesTemplateSubstitution: Boolean;
begin
  const HasOpenSubstitution = (FSubstitutionDepths.Count > 0);

  Result := (HasOpenSubstitution and (FSubstitutionDepths.Peek = FBraceDepth));
end;

function TJSLexer.StartsIdentifierAhead(const IsFirstChar: Boolean): Boolean;
begin
  Result := TJSLexicalCharacters.IsIdentifierCodePointAt(FSource, FPosition, IsFirstChar);
end;

function TJSLexer.ReadCodePointText: string;
begin
  const CodePointLength = TJSLexicalCharacters.CodePointLengthAt(FSource, FPosition);
  Result := Copy(FSource, FPosition, CodePointLength);
  AdvanceBy(CodePointLength);
end;

function TJSLexer.ScanIdentifier: TJSToken;
begin
  var Value := '';
  var HasEscape := False;

  while not IsAtEnd do
  begin
    if CurrentChar = BACKSLASH then
    begin
      const IsFirstChar = Value.IsEmpty;
      const Escaped = ParseIdentifierEscape(IsFirstChar);
      Value := Value + Escaped;
      HasEscape := True;
    end
    else if StartsIdentifierAhead(False) then
    begin
      const CodePoint = ReadCodePointText;
      Value := Value + CodePoint;
    end
    else
    begin
      Break;
    end;
  end;

  var Details := Default(TJSTokenDetails);
  Details.HasEscape := HasEscape;

  const TokenType = IdentifierTokenType(Value, HasEscape);
  Result := NewToken(TokenType, Value, Details);
end;

function TJSLexer.IdentifierTokenType(const Name: string; const HasEscape: Boolean): TJSTokenType;
begin
  if HasEscape then
  begin
    if TJSKeywords.IsReservedWord(Name) then
      Result := TJSTokenType.EscapedKeyword
    else
      Result := TJSTokenType.Identifier;
  end
  else if TJSKeywords.IsUnusedReservedWord(Name) then
  begin
    Result := TJSTokenType.UnusedReservedWord;
  end
  else
  begin
    Result := TJSKeywords.GetKeywordType(Name);
  end;
end;

function TJSLexer.ScanNumber: TJSToken;
begin
  const Literal = ReadNumberLiteral;
  RejectIdentifierAfterNumber;

  var Details := Default(TJSTokenDetails);
  Details.NumberValue := Literal.Value;
  Details.IsLegacyLiteral := Literal.IsLegacy;

  Result := NewToken(TJSTokenType.NumberLiteral, '', Details);
end;

function TJSLexer.ReadNumberLiteral: TNumberLiteral;
begin
  const PrefixRadix = TJSNumberParse.RadixOfPrefixMark(PeekChar);
  const HasRadixPrefix = ((CurrentChar = ZERO_CHAR) and (PrefixRadix <> TJSNumberParse.NOT_PREFIXED));
  if HasRadixPrefix then
  begin
    const RadixValue = ParseRadixNumber(PrefixRadix);
    Exit(TNumberLiteral.Create(RadixValue, False));
  end;

  const SeparatorAfterZero = ((CurrentChar = ZERO_CHAR) and (PeekChar = UNDERSCORE));
  if SeparatorAfterZero then
    raise TJSErrorFactory.SyntaxError(MISPLACED_NUMERIC_SEPARATOR_MESSAGE, FLine, FColumn);

  const HasLeadingZero = ((CurrentChar = ZERO_CHAR) and TJSAsciiDigits.IsDigit(PeekChar));
  if HasLeadingZero and IsLegacyOctalLiteral then
  begin
    const OctalValue = ParseOctalNumber;
    Exit(TNumberLiteral.Create(OctalValue, True));
  end;

  const AllowSeparators = (not HasLeadingZero);
  const DecimalValue = ParseDecimalNumber(AllowSeparators);
  Result := TNumberLiteral.Create(DecimalValue, HasLeadingZero);
end;

function TJSLexer.IsLegacyOctalLiteral: Boolean;
begin
  var Offset := 1;
  while TJSAsciiDigits.IsDigit(PeekChar(Offset)) do
  begin
    if not TJSLexicalCharacters.IsOctalDigit(PeekChar(Offset)) then
      Exit(False);

    Inc(Offset);
  end;

  Result := True;
end;

procedure TJSLexer.RejectIdentifierAfterNumber;
begin
  const StartsIdentifier = (StartsIdentifierAhead(True) or
                            (CurrentChar = BACKSLASH) or
                            TJSAsciiDigits.IsDigit(CurrentChar));
  if StartsIdentifier then
    raise TJSErrorFactory.SyntaxError(IDENTIFIER_AFTER_NUMBER_MESSAGE, FLine, FColumn);
end;

function TJSLexer.ParseRadixNumber(const Radix: Integer): Double;
begin
  AdvanceBy(RADIX_PREFIX_LENGTH);

  Result := 0;
  var DigitCount := 0;

  while not IsAtEnd do
  begin
    const IsSeparator = ((CurrentChar = UNDERSCORE) and (DigitCount > 0));
    if IsSeparator then
      ConsumeSeparatorBeforeDigit(Radix);

    const IsDigitOfRadix = TJSAsciiDigits.IsDigitInRadix(CurrentChar, Radix);
    if not IsDigitOfRadix then
      Break;

    Result := Result * Radix + TJSAsciiDigits.DigitValue(CurrentChar);
    Inc(DigitCount);
    Advance;
  end;

  const HasNoDigits = (DigitCount = 0);
  if HasNoDigits then
    raise TJSErrorFactory.SyntaxError(MISSING_RADIX_DIGITS_MESSAGE, FLine, FColumn);
end;

function TJSLexer.ParseOctalNumber: Double;
begin
  Advance;

  var Value: Int64 := 0;

  while (not IsAtEnd) and TJSLexicalCharacters.IsOctalDigit(CurrentChar) do
  begin
    Value := Value * OCTAL_RADIX + TJSAsciiDigits.DigitValue(CurrentChar);
    Advance;
  end;

  Result := Value;
end;

procedure TJSLexer.ConsumeSeparatorBeforeDigit(const Radix: Integer);
begin
  const IsDigitAhead = TJSAsciiDigits.IsDigitInRadix(PeekChar, Radix);
  if not IsDigitAhead then
    raise TJSErrorFactory.SyntaxError(MISPLACED_NUMERIC_SEPARATOR_MESSAGE, FLine, FColumn);

  Advance;
end;

function TJSLexer.ReadDigits(const AllowSeparators: Boolean): string;
begin
  Result := '';

  while not IsAtEnd do
  begin
    const IsSeparator = (AllowSeparators and (CurrentChar = UNDERSCORE) and (not Result.IsEmpty));
    if IsSeparator then
      ConsumeSeparatorBeforeDigit(DECIMAL_RADIX);

    if not TJSAsciiDigits.IsDigit(CurrentChar) then
      Break;

    Result := Result + CurrentChar;
    Advance;
  end;
end;

function TJSLexer.ReadExponent(const AllowSeparators: Boolean): string;
begin
  Result := '';
  if not TJSNumberParse.IsExponentMark(CurrentChar) then
    Exit;

  Result := ConsumeChar;

  if TJSNumberParse.IsSign(CurrentChar) then
    Result := Result + ConsumeChar;

  const ExponentDigits = ReadDigits(AllowSeparators);
  if ExponentDigits.IsEmpty then
    raise TJSErrorFactory.SyntaxError(MISSING_EXPONENT_DIGITS_MESSAGE, FLine, FColumn);

  Result := Result + ExponentDigits;
end;

function TJSLexer.ParseDecimalNumber(const AllowSeparators: Boolean): Double;
begin
  var IntegerDigits := ReadDigits(AllowSeparators);
  if IntegerDigits.IsEmpty then
    IntegerDigits := ZERO_CHAR;

  var FractionDigits := '';
  if CurrentChar = DOT_CHAR then
  begin
    Advance;
    FractionDigits := ReadDigits(AllowSeparators);
  end;

  var NumberText := IntegerDigits;
  if not FractionDigits.IsEmpty then
    NumberText := NumberText + DOT_CHAR + FractionDigits;

  const Exponent = ReadExponent(AllowSeparators);
  NumberText := NumberText + Exponent;

  Result := TJSNumberParse.DecimalToDouble(NumberText);
end;

function TJSLexer.ScanString(const Quote: Char): TJSToken;
begin
  Advance;

  const Content = ReadStringContent(Quote);

  var Details := Default(TJSTokenDetails);
  Details.IsLegacyLiteral := Content.HasLegacyEscape;
  Details.HasEscape := Content.HasEscape;

  Result := NewToken(TJSTokenType.StringLiteral, Content.Value, Details);
end;

function TJSLexer.ReadStringContent(const Quote: Char): TStringContent;
begin
  var Value := '';
  var HasEscape := False;
  var HasLegacyEscape := False;

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;
    const EndsLiteral = (Ch = Quote);
    const StartsEscape = (Ch = BACKSLASH);
    const IsLineBreak = ((Ch = LF_CHAR) or (Ch = CR_CHAR));

    if EndsLiteral then
    begin
      Advance;
      Exit(TStringContent.Create(Value, HasEscape, HasLegacyEscape));
    end;

    if IsLineBreak then
      raise TJSErrorFactory.SyntaxError(UNTERMINATED_STRING_MESSAGE, FLine, FColumn);

    if StartsEscape then
    begin
      Advance;
      const Escape = ReadStringEscape;
      Value := Value + Escape.Value;
      HasEscape := True;
      HasLegacyEscape := (HasLegacyEscape or Escape.IsLegacy);
    end
    else
    begin
      Value := Value + ConsumeChar;
    end;
  end;

  raise TJSErrorFactory.SyntaxError(UNTERMINATED_STRING_MESSAGE, FTokenStart.Line, FTokenStart.Column);
end;

function TJSLexer.ReadStringEscape: TStringEscape;
begin
  if IsAtEnd then
    raise TJSErrorFactory.SyntaxError(UNEXPECTED_END_OF_INPUT_MESSAGE, FLine, FColumn);

  const Ch = ConsumeChar;

  if TJSLexicalCharacters.IsLineTerminator(Ch) then
  begin
    SkipLineFeedAfter(Ch);
    Exit(TStringEscape.Create('', False));
  end;

  if TJSLexicalCharacters.IsOctalDigit(Ch) then
    Exit(ReadOctalEscape(Ch));

  const IsNonOctalDigit = ((Ch = DIGIT_EIGHT) or (Ch = DIGIT_NINE));
  const Value = ReadSimpleEscapeValue(Ch);
  Result := TStringEscape.Create(Value, IsNonOctalDigit);
end;

function TJSLexer.ReadOctalEscape(const FirstDigit: Char): TStringEscape;
begin
  const IsNullEscape = ((FirstDigit = ZERO_CHAR) and (not TJSAsciiDigits.IsDigit(CurrentChar)));
  if IsNullEscape then
    Exit(TStringEscape.Create(NULL_CHAR, False));

  var CodeUnit := TJSAsciiDigits.DigitValue(FirstDigit);
  const AllowsThreeDigits = (FirstDigit <= LAST_DIGIT_OF_THREE_DIGIT_OCTAL_START);
  var RemainingDigits := SHORT_OCTAL_ESCAPE_REMAINING_DIGITS;
  if AllowsThreeDigits then
    RemainingDigits := LONG_OCTAL_ESCAPE_REMAINING_DIGITS;

  while (RemainingDigits > 0) and TJSLexicalCharacters.IsOctalDigit(CurrentChar) do
  begin
    CodeUnit := CodeUnit * OCTAL_RADIX + TJSAsciiDigits.DigitValue(CurrentChar);
    Dec(RemainingDigits);
    Advance;
  end;

  Result := TStringEscape.Create(Char(CodeUnit), True);
end;

function TJSLexer.ReadSimpleEscapeValue(const Escape: Char): string;
begin
  var ControlChar: Char;
  if TJSLexicalCharacters.TryControlEscape(Escape, ControlChar) then
    Exit(ControlChar);

  case Escape of
    ESCAPE_X:
      begin
        if not TryReadHexEscape(Result) then
          raise TJSErrorFactory.SyntaxError(INVALID_HEX_ESCAPE_MESSAGE, FLine, FColumn);
      end;
    ESCAPE_U:
      begin
        Result := ParseUnicodeEscape;
      end;
  else
    begin
      Result := Escape;
    end;
  end;
end;

function TJSLexer.ParseUnicodeEscape: string;
begin
  if not TryReadUnicodeEscape(Result) then
    raise TJSErrorFactory.SyntaxError(INVALID_UNICODE_ESCAPE_MESSAGE, FLine, FColumn);
end;

function TJSLexer.ParseIdentifierEscape(const IsFirstChar: Boolean): string;
begin
  Advance;

  if CurrentChar <> ESCAPE_U then
    raise TJSErrorFactory.SyntaxError(INVALID_UNICODE_ESCAPE_MESSAGE, FLine, FColumn);

  Advance;

  Result := ParseUnicodeEscape;

  if not TJSLexicalCharacters.IsIdentifierCodePointAt(Result, 1, IsFirstChar) then
    raise TJSErrorFactory.SyntaxError(INVALID_IDENTIFIER_ESCAPE_MESSAGE, FLine, FColumn);
end;

function TJSLexer.ScanTemplateHead: TJSToken;
begin
  Advance;

  Result := ScanTemplateChunk(True);
end;

function TJSLexer.ScanTemplateContinuation: TJSToken;
begin
  Advance;
  FSubstitutionDepths.Pop;

  Result := ScanTemplateChunk(False);
end;

function TJSLexer.ScanTemplateChunk(const IsHead: Boolean): TJSToken;
begin
  var Text := TTemplatePiece.Create('', '', False);

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;
    const EndsTemplate = (Ch = BACKTICK);
    const OpensSubstitution = ((Ch = DOLLAR_SIGN) and (PeekChar = LEFT_BRACE));

    if EndsTemplate then
    begin
      Advance;
      Exit(CreateTemplateChunk(Text, IsHead, True));
    end;

    if OpensSubstitution then
    begin
      AdvanceBy(TEMPLATE_SUBSTITUTION_OPENER_LENGTH);
      FSubstitutionDepths.Push(FBraceDepth);
      Exit(CreateTemplateChunk(Text, IsHead, False));
    end;

    const Piece = ReadTemplateElement;
    Text.Append(Piece);
  end;

  raise TJSErrorFactory.SyntaxError(UNTERMINATED_TEMPLATE_MESSAGE, FTokenStart.Line, FTokenStart.Column);
end;

function TJSLexer.CreateTemplateChunk(const Text: TTemplatePiece; const IsHead: Boolean;
                                      const IsTail: Boolean): TJSToken;
begin
  var Details := Default(TJSTokenDetails);
  Details.RawValue := Text.Raw;
  Details.HasInvalidEscape := Text.IsInvalid;
  Details.IsTemplateHead := IsHead;
  Details.IsTemplateTail := IsTail;

  Result := NewToken(TJSTokenType.TemplateChunk, Text.Cooked, Details);
end;

function TJSLexer.ReadTemplateElement: TTemplatePiece;
begin
  const Ch = CurrentChar;
  const StartsEscape = (Ch = BACKSLASH);
  const IsLineBreak = ((Ch = LF_CHAR) or (Ch = CR_CHAR));

  if StartsEscape then
  begin
    Result := ReadTemplateEscape;
  end
  else if IsLineBreak then
  begin
    Result := ReadTemplateLineTerminator;
  end
  else
  begin
    Advance;
    Result := TTemplatePiece.Create(Ch, Ch, False);
  end;
end;

function TJSLexer.ReadTemplateLineTerminator: TTemplatePiece;
begin
  const Terminator = ConsumeChar;
  SkipLineFeedAfter(Terminator);

  Result := TTemplatePiece.Create(LF_CHAR, LF_CHAR, False);
end;

function TJSLexer.ReadTemplateLineContinuation: TTemplatePiece;
begin
  const Terminator = ConsumeChar;
  SkipLineFeedAfter(Terminator);

  var RawTerminator := Terminator;
  if Terminator = CR_CHAR then
    RawTerminator := LF_CHAR;

  Result := TTemplatePiece.Create('', BACKSLASH + RawTerminator, False);
end;

function TJSLexer.ReadTemplateEscape: TTemplatePiece;
begin
  const EscapeStart = FPosition;
  Advance;

  if IsAtEnd then
    raise TJSErrorFactory.SyntaxError(UNTERMINATED_TEMPLATE_MESSAGE, FLine, FColumn);

  if TJSLexicalCharacters.IsLineTerminator(CurrentChar) then
    Exit(ReadTemplateLineContinuation);

  const Escape = ConsumeChar;

  var Value: string;
  const IsValid = TryReadEscapeValue(Escape, Value);
  const RawText = Copy(FSource, EscapeStart, FPosition - EscapeStart);

  if IsValid then
    Result := TTemplatePiece.Create(Value, RawText, False)
  else
    Result := TTemplatePiece.Create('', RawText, True);
end;

function TJSLexer.TryReadEscapeValue(const Escape: Char; out Value: string): Boolean;
begin
  var ControlChar: Char;
  if TJSLexicalCharacters.TryControlEscape(Escape, ControlChar) then
  begin
    Value := ControlChar;
    Exit(True);
  end;

  case Escape of
    ZERO_CHAR:
      begin
        Value := NULL_CHAR;
        Result := not TJSAsciiDigits.IsDigit(CurrentChar);
      end;
    DIGIT_ONE..DIGIT_NINE:
      begin
        Result := False;
      end;
    ESCAPE_X:
      begin
        Result := TryReadHexEscape(Value);
      end;
    ESCAPE_U:
      begin
        Result := TryReadUnicodeEscape(Value);
      end;
  else
    begin
      Value := Escape;
      Result := True;
    end;
  end;
end;

function TJSLexer.TryReadHexEscape(out Value: string): Boolean;
begin
  var CodeUnit: Integer;
  Result := TryReadHexDigits(HEX_ESCAPE_DIGITS, CodeUnit);
  if Result then
    Value := Char(CodeUnit);
end;

function TJSLexer.TryReadUnicodeEscape(out Value: string): Boolean;
begin
  const IsCodePointEscape = (CurrentChar = LEFT_BRACE);
  if IsCodePointEscape then
    Exit(TryReadCodePointEscape(Value));

  var CodeUnit: Integer;
  Result := TryReadHexDigits(UNICODE_ESCAPE_DIGITS, CodeUnit);
  if Result then
    Value := Char(CodeUnit);
end;

function TJSLexer.TryReadHexDigits(const DigitCount: Integer; out Value: Integer): Boolean;
begin
  Value := 0;

  for var Index := 1 to DigitCount do
  begin
    if not TJSAsciiDigits.IsHexDigit(CurrentChar) then
      Exit(False);

    Value := Value * HEX_RADIX + TJSAsciiDigits.HexValue(CurrentChar);
    Advance;
  end;

  Result := True;
end;

function TJSLexer.TryReadCodePointEscape(out Value: string): Boolean;
begin
  Advance;

  var CodePoint := 0;
  var DigitCount := 0;
  var IsInRange := True;

  while TJSAsciiDigits.IsHexDigit(CurrentChar) do
  begin
    if IsInRange then
      CodePoint := CodePoint * HEX_RADIX + TJSAsciiDigits.HexValue(CurrentChar);

    IsInRange := (IsInRange and (CodePoint <= MAX_CODE_POINT));
    Inc(DigitCount);
    Advance;
  end;

  const IsClosed = (CurrentChar = RIGHT_BRACE);
  if IsClosed then
    Advance;

  Result := (IsClosed and IsInRange and (DigitCount > 0));
  if Result then
    Value := CodePointToText(CodePoint);
end;

function TJSLexer.CodePointToText(const CodePoint: Integer): string;
begin
  if CodePoint <= MAX_BASIC_PLANE_CODE_POINT then
    Result := Char(CodePoint)
  else
    Result := Char.ConvertFromUtf32(CodePoint);
end;

function TJSLexer.ScanRegExp: TJSToken;
begin
  Advance;

  const Pattern = ReadRegExpBody;
  const Flags = ReadRegExpFlags;

  var Details := Default(TJSTokenDetails);
  Details.RawValue := Flags;

  Result := NewToken(TJSTokenType.RegExpLiteral, Pattern, Details);
end;

function TJSLexer.ReadRegExpBody: string;
begin
  Result := '';
  var InCharClass := False;

  while not IsAtEnd do
  begin
    const Ch = CurrentChar;
    const StartsEscape = (Ch = BACKSLASH);
    const EndsPattern = ((Ch = FORWARD_SLASH) and (not InCharClass));

    if StartsEscape then
    begin
      Result := Result + ReadRegExpEscape;
    end
    else if EndsPattern then
    begin
      Advance;
      Exit;
    end
    else if TJSLexicalCharacters.IsLineTerminator(Ch) then
    begin
      raise TJSErrorFactory.SyntaxError(UNTERMINATED_REGEXP_MESSAGE, FLine, FColumn);
    end
    else
    begin
      if Ch = LEFT_BRACKET then
        InCharClass := True
      else if Ch = RIGHT_BRACKET then
        InCharClass := False;

      Result := Result + ConsumeChar;
    end;
  end;
end;

function TJSLexer.ReadRegExpEscape: string;
begin
  Result := ConsumeChar;

  if TJSLexicalCharacters.IsLineTerminator(CurrentChar) then
    raise TJSErrorFactory.SyntaxError(UNTERMINATED_REGEXP_MESSAGE, FLine, FColumn);

  if not IsAtEnd then
    Result := Result + ConsumeChar;
end;

function TJSLexer.ReadRegExpFlags: string;
begin
  Result := '';

  while (not IsAtEnd) and TJSLexicalCharacters.IsIdentifierPart(CurrentChar) do
  begin
    Result := Result + ConsumeChar;
  end;

  if CurrentChar = BACKSLASH then
    raise TJSErrorFactory.SyntaxError(ESCAPE_IN_REGEXP_FLAGS_MESSAGE, FLine, FColumn);
end;

end.
