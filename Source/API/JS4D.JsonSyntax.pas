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
      UNICODE_ESCAPE_DIGITS = 4;
      FIRST_PRINTABLE = #32;

    var
      FText: string;
      FPosition: Integer;

    constructor Create(const Text: string);

    function AtEnd: Boolean;
    function Current: Char;
    function TryConsume(const Expected: Char): Boolean;
    function IsDigit(const Value: Char): Boolean;
    procedure SkipWhitespace;

    function ParseDocument: Boolean;
    function ParseValue(const Depth: Integer): Boolean;
    function ParseObject(const Depth: Integer): Boolean;
    function ParseMember(const Depth: Integer): Boolean;
    function ParseArray(const Depth: Integer): Boolean;
    function ParseString: Boolean;
    function ParseEscape: Boolean;
    function ParseNumber: Boolean;
    function ParseDigits: Boolean;
    function ParseFraction: Boolean;
    function ParseExponent: Boolean;
    function ParseLiteral(const Literal: string): Boolean;

  public
    class function IsValid(const Text: string): Boolean; static;
  end;

implementation

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
end;

function TJSJsonSyntax.AtEnd: Boolean;
begin
  Result := (FPosition > Length(FText));
end;

function TJSJsonSyntax.Current: Char;
begin
  Result := FText[FPosition];
end;

function TJSJsonSyntax.TryConsume(const Expected: Char): Boolean;
begin
  Result := (not AtEnd) and (Current = Expected);
  if Result then
    Inc(FPosition);
end;

function TJSJsonSyntax.IsDigit(const Value: Char): Boolean;
begin
  Result := (Value >= '0') and (Value <= '9');
end;

procedure TJSJsonSyntax.SkipWhitespace;
begin
  while (not AtEnd) and CharInSet(Current, [' ', #9, #10, #13]) do
  begin
    Inc(FPosition);
  end;
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
    '{': Result := ParseObject(Depth);
    '[': Result := ParseArray(Depth);
    '"': Result := ParseString;
    't': Result := ParseLiteral('true');
    'f': Result := ParseLiteral('false');
    'n': Result := ParseLiteral('null');
  else
    Result := ParseNumber;
  end;
end;

function TJSJsonSyntax.ParseObject(const Depth: Integer): Boolean;
begin
  Inc(FPosition);
  SkipWhitespace;

  if TryConsume('}') then
    Exit(True);

  repeat
    if not ParseMember(Depth) then
      Exit(False);

    SkipWhitespace;
  until not TryConsume(',');

  Result := TryConsume('}');
end;

function TJSJsonSyntax.ParseMember(const Depth: Integer): Boolean;
begin
  SkipWhitespace;
  if AtEnd or (Current <> '"') then
    Exit(False);

  if not ParseString then
    Exit(False);

  SkipWhitespace;
  if not TryConsume(':') then
    Exit(False);

  SkipWhitespace;
  Result := ParseValue(Depth + 1);
end;

function TJSJsonSyntax.ParseArray(const Depth: Integer): Boolean;
begin
  Inc(FPosition);
  SkipWhitespace;

  if TryConsume(']') then
    Exit(True);

  repeat
    SkipWhitespace;
    if not ParseValue(Depth + 1) then
      Exit(False);

    SkipWhitespace;
  until not TryConsume(',');

  Result := TryConsume(']');
end;

function TJSJsonSyntax.ParseString: Boolean;
begin
  Inc(FPosition);

  while not AtEnd do
  begin
    const Character = Current;
    Inc(FPosition);

    if Character = '"' then
      Exit(True);

    const IsControlCharacter = (Character < FIRST_PRINTABLE);
    if IsControlCharacter then
      Exit(False);

    if (Character = '\') and (not ParseEscape) then
      Exit(False);
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

  if Escape <> 'u' then
    Exit(False);

  for var DigitIndex := 1 to UNICODE_ESCAPE_DIGITS do
  begin
    const IsHexDigit = (not AtEnd) and (Pos(Current, HEX_DIGITS) > 0);
    if not IsHexDigit then
      Exit(False);

    Inc(FPosition);
  end;

  Result := True;
end;

function TJSJsonSyntax.ParseNumber: Boolean;
begin
  TryConsume('-');

  if AtEnd or (not IsDigit(Current)) then
    Exit(False);

  if TryConsume('0') then
    Result := True
  else
    Result := ParseDigits;

  if Result then
    Result := ParseFraction and ParseExponent;
end;

function TJSJsonSyntax.ParseDigits: Boolean;
begin
  Result := (not AtEnd) and IsDigit(Current);

  while (not AtEnd) and IsDigit(Current) do
  begin
    Inc(FPosition);
  end;
end;

function TJSJsonSyntax.ParseFraction: Boolean;
begin
  if not TryConsume('.') then
    Exit(True);

  Result := ParseDigits;
end;

function TJSJsonSyntax.ParseExponent: Boolean;
begin
  const HasExponent = TryConsume('e') or TryConsume('E');
  if not HasExponent then
    Exit(True);

  if not TryConsume('+') then
    TryConsume('-');

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
