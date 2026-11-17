unit JS4D.JsonSyntax;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TJSJsonSyntax = class
  private
    const
      MAX_NESTING = 1000;
      SIMPLE_ESCAPES = '"\/bfnrt';
      HEX_DIGITS = '0123456789abcdefABCDEF';
      FIRST_PRINTABLE = #32;

    var
      FText: string;
      FPosition: Integer;
      FStackFloor: NativeUInt;

    constructor Create(const Text: string);

    class function IsDigit(const Value: Char): Boolean; static;

    function AtEnd: Boolean;
    function Current: Char;
    function IsNext(const Expected: Char): Boolean;
    function TryConsume(const Expected: Char): Boolean;
    procedure SkipOptional(const Expected: Char);
    procedure SkipWhitespace;
    procedure EnsureStackAvailable;

    function ParseDocument: Boolean;
    function ParseValue(const Depth: Integer): Boolean;
    function ParseObject(const Depth: Integer): Boolean;
    function ParseMember(const Depth: Integer): Boolean;
    function ParseArray(const Depth: Integer): Boolean;
    function ParseString: Boolean;
    function ParseEscape: Boolean;
    function ParseUnicodeDigits: Boolean;
    function ParseNumber: Boolean;
    function ParseDigits: Boolean;
    function ParseFraction: Boolean;
    function ParseExponent: Boolean;
    function ParseLiteral(const Literal: string): Boolean;

  public
    class function IsValid(const Text: string): Boolean; static;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.StackGuard,
  JS4D.JsonGrammar;

class function TJSJsonSyntax.IsValid(const Text: string): Boolean;
begin
  const Syntax = TJSJsonSyntax.Create(Text);
  try
    Result := Syntax.ParseDocument;
  finally
    Syntax.Free;
  end;
end;

constructor TJSJsonSyntax.Create(const Text: string);
begin
  inherited Create;
  FText := Text;
  FPosition := 1;
  FStackFloor := TJSStackGuard.CurrentFloor;
end;

class function TJSJsonSyntax.IsDigit(const Value: Char): Boolean;
begin
  Result := ((Value >= '0') and (Value <= '9'));
end;

function TJSJsonSyntax.AtEnd: Boolean;
begin
  Result := (FPosition > Length(FText));
end;

function TJSJsonSyntax.Current: Char;
begin
  Result := FText[FPosition];
end;

function TJSJsonSyntax.IsNext(const Expected: Char): Boolean;
begin
  Result := ((not AtEnd) and (Current = Expected));
end;

function TJSJsonSyntax.TryConsume(const Expected: Char): Boolean;
begin
  Result := IsNext(Expected);
  if Result then
    Inc(FPosition);
end;

procedure TJSJsonSyntax.SkipOptional(const Expected: Char);
begin
  if IsNext(Expected) then
    Inc(FPosition);
end;

procedure TJSJsonSyntax.SkipWhitespace;
begin
  while (not AtEnd) and CharInSet(Current, JSON_WHITE_SPACE) do
  begin
    Inc(FPosition);
  end;
end;

procedure TJSJsonSyntax.EnsureStackAvailable;
begin
  var StackMarker: Byte;
  const IsStackExhausted = (NativeUInt(@StackMarker) < FStackFloor);
  if IsStackExhausted then
    raise TJSErrorFactory.StackExhausted;
end;

function TJSJsonSyntax.ParseDocument: Boolean;
begin
  SkipWhitespace;
  Result := ParseValue(0);
  if not Result then
    Exit;

  SkipWhitespace;
  Result := AtEnd;
end;

function TJSJsonSyntax.ParseValue(const Depth: Integer): Boolean;
begin
  const IsTooDeep = (Depth > MAX_NESTING);
  if IsTooDeep or AtEnd then
    Exit(False);

  case Current of
    JSON_OBJECT_START : Result := ParseObject(Depth);
    JSON_ARRAY_START  : Result := ParseArray(Depth);
    JSON_QUOTE        : Result := ParseString;
    JSON_TRUE_START   : Result := ParseLiteral(JSON_TRUE_LITERAL);
    JSON_FALSE_START  : Result := ParseLiteral(JSON_FALSE_LITERAL);
    JSON_NULL_START   : Result := ParseLiteral(JSON_NULL_LITERAL);
  else
    Result := ParseNumber;
  end;
end;

function TJSJsonSyntax.ParseObject(const Depth: Integer): Boolean;
begin
  EnsureStackAvailable;

  Inc(FPosition);
  SkipWhitespace;

  if TryConsume(JSON_OBJECT_END) then
    Exit(True);

  repeat
    if not ParseMember(Depth) then
      Exit(False);

    SkipWhitespace;
  until not TryConsume(JSON_COMMA);

  Result := TryConsume(JSON_OBJECT_END);
end;

function TJSJsonSyntax.ParseMember(const Depth: Integer): Boolean;
begin
  SkipWhitespace;
  const StartsString = IsNext(JSON_QUOTE);
  if not StartsString then
    Exit(False);

  if not ParseString then
    Exit(False);

  SkipWhitespace;
  if not TryConsume(JSON_COLON) then
    Exit(False);

  SkipWhitespace;
  Result := ParseValue(Depth + 1);
end;

function TJSJsonSyntax.ParseArray(const Depth: Integer): Boolean;
begin
  EnsureStackAvailable;

  Inc(FPosition);
  SkipWhitespace;

  if TryConsume(JSON_ARRAY_END) then
    Exit(True);

  repeat
    SkipWhitespace;
    if not ParseValue(Depth + 1) then
      Exit(False);

    SkipWhitespace;
  until not TryConsume(JSON_COMMA);

  Result := TryConsume(JSON_ARRAY_END);
end;

function TJSJsonSyntax.ParseString: Boolean;
begin
  Inc(FPosition);

  while not AtEnd do
  begin
    const Character = Current;
    Inc(FPosition);

    const IsClosingQuote = (Character = JSON_QUOTE);
    if IsClosingQuote then
      Exit(True);

    const IsControlCharacter = (Character < FIRST_PRINTABLE);
    if IsControlCharacter then
      Exit(False);

    const StartsEscape = (Character = JSON_ESCAPE);
    if StartsEscape then
    begin
      const IsValidEscape = ParseEscape;
      if not IsValidEscape then
        Exit(False);
    end;
  end;

  Result := False;
end;

function TJSJsonSyntax.ParseEscape: Boolean;
begin
  if AtEnd then
    Exit(False);

  const Escape = Current;
  Inc(FPosition);

  const IsSimpleEscape = (Pos(Escape, SIMPLE_ESCAPES) > 0);
  if IsSimpleEscape then
    Exit(True);

  const IsUnicodeEscape = (Escape = JSON_UNICODE_ESCAPE);
  if not IsUnicodeEscape then
    Exit(False);

  Result := ParseUnicodeDigits;
end;

function TJSJsonSyntax.ParseUnicodeDigits: Boolean;
begin
  var Remaining := JSON_UNICODE_ESCAPE_DIGITS;
  while Remaining > 0 do
  begin
    const IsHexDigit = ((not AtEnd) and (Pos(Current, HEX_DIGITS) > 0));
    if not IsHexDigit then
      Exit(False);

    Inc(FPosition);
    Dec(Remaining);
  end;

  Result := True;
end;

function TJSJsonSyntax.ParseNumber: Boolean;
begin
  SkipOptional(JSON_MINUS);

  const StartsWithDigit = ((not AtEnd) and IsDigit(Current));
  if not StartsWithDigit then
    Exit(False);

  if TryConsume(JSON_ZERO) then
    Result := True
  else
    Result := ParseDigits;

  if Result then
    Result := (ParseFraction and ParseExponent);
end;

function TJSJsonSyntax.ParseDigits: Boolean;
begin
  Result := ((not AtEnd) and IsDigit(Current));

  while (not AtEnd) and IsDigit(Current) do
  begin
    Inc(FPosition);
  end;
end;

function TJSJsonSyntax.ParseFraction: Boolean;
begin
  if not TryConsume(JSON_DECIMAL_POINT) then
    Exit(True);

  Result := ParseDigits;
end;

function TJSJsonSyntax.ParseExponent: Boolean;
begin
  const HasExponent = (TryConsume(JSON_EXPONENT_LOWER) or TryConsume(JSON_EXPONENT_UPPER));
  if not HasExponent then
    Exit(True);

  if not TryConsume(JSON_PLUS) then
    SkipOptional(JSON_MINUS);

  Result := ParseDigits;
end;

function TJSJsonSyntax.ParseLiteral(const Literal: string): Boolean;
begin
  const Candidate = Copy(FText, FPosition, Length(Literal));
  Result := (Candidate = Literal);
  if Result then
    Inc(FPosition, Length(Literal));
end;

end.
