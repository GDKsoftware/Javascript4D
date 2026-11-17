unit JS4D.JsonReader;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSJsonReader = class
  private
    const
      UNICODE_ESCAPE_FORMAT = '$%s';
      INVALID_JSON_TEXT = 'Unexpected token in JSON';

    var
      FText: string;
      FPosition: Integer;
      FStackFloor: NativeUInt;
      FObjectPrototype: IJSObject;
      FArrayPrototype: IJSObject;

    constructor Create(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject);

    function Current: Char;
    procedure SkipWhiteSpace;
    function TryConsume(const Expected: Char): Boolean;
    procedure Consume(const Expected: Char);
    procedure EnsureStackAvailable;

    function ReadValue: TJSValue;
    function ReadTrue: TJSValue;
    function ReadFalse: TJSValue;
    function ReadNull: TJSValue;
    procedure SkipLiteral(const Literal: string);
    function ReadObject: TJSValue;
    function ReadArray: TJSValue;
    function ReadStringValue: TJSValue;
    function ReadString: string;
    function ReadEscape: Char;
    function ReadUnicodeEscape: Char;
    function ReadNumber: TJSValue;

  public
    class function Read(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject): TJSValue; static;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.StackGuard,
  JS4D.NumberParse,
  JS4D.JsonGrammar,
  JS4D.JsonSyntax;

constructor TJSJsonReader.Create(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject);
begin
  inherited Create;
  FText := Text;
  FPosition := 1;
  FStackFloor := TJSStackGuard.CurrentFloor;
  FObjectPrototype := ObjectPrototype;
  FArrayPrototype := ArrayPrototype;
end;

class function TJSJsonReader.Read(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject): TJSValue;
begin
  const IsValidText = TJSJsonSyntax.IsValid(Text);
  if not IsValidText then
    raise TJSErrorFactory.SyntaxError(INVALID_JSON_TEXT);

  const Reader = TJSJsonReader.Create(Text, ObjectPrototype, ArrayPrototype);
  try
    Reader.SkipWhiteSpace;
    Result := Reader.ReadValue;
  finally
    Reader.Free;
  end;
end;

function TJSJsonReader.Current: Char;
begin
  Result := FText[FPosition];
end;

procedure TJSJsonReader.SkipWhiteSpace;
begin
  while CharInSet(Current, JSON_WHITE_SPACE) do
  begin
    Inc(FPosition);
  end;
end;

function TJSJsonReader.TryConsume(const Expected: Char): Boolean;
begin
  Result := (Current = Expected);
  if Result then
    Inc(FPosition);
end;

procedure TJSJsonReader.Consume(const Expected: Char);
begin
  if Current = Expected then
    Inc(FPosition);
end;

procedure TJSJsonReader.EnsureStackAvailable;
begin
  var StackMarker: Byte;
  const IsStackExhausted = (NativeUInt(@StackMarker) < FStackFloor);
  if IsStackExhausted then
    raise TJSErrorFactory.StackExhausted;
end;

function TJSJsonReader.ReadValue: TJSValue;
begin
  case Current of
    JSON_OBJECT_START : Result := ReadObject;
    JSON_ARRAY_START  : Result := ReadArray;
    JSON_QUOTE        : Result := ReadStringValue;
    JSON_TRUE_START   : Result := ReadTrue;
    JSON_FALSE_START  : Result := ReadFalse;
    JSON_NULL_START   : Result := ReadNull;
  else
    Result := ReadNumber;
  end;
end;

function TJSJsonReader.ReadTrue: TJSValue;
begin
  SkipLiteral(JSON_TRUE_LITERAL);
  Result := TJSValue.CreateBoolean(True);
end;

function TJSJsonReader.ReadFalse: TJSValue;
begin
  SkipLiteral(JSON_FALSE_LITERAL);
  Result := TJSValue.CreateBoolean(False);
end;

function TJSJsonReader.ReadNull: TJSValue;
begin
  SkipLiteral(JSON_NULL_LITERAL);
  Result := TJSValue.CreateNull;
end;

procedure TJSJsonReader.SkipLiteral(const Literal: string);
begin
  Inc(FPosition, Length(Literal));
end;

function TJSJsonReader.ReadObject: TJSValue;
begin
  EnsureStackAvailable;

  Inc(FPosition);
  SkipWhiteSpace;

  const Target = TJSObject.Create;
  Target.Prototype := FObjectPrototype;
  Result := TJSValue.CreateObject(Target);

  if TryConsume(JSON_OBJECT_END) then
    Exit;

  repeat
    SkipWhiteSpace;
    const Name = ReadString;
    SkipWhiteSpace;
    Consume(JSON_COLON);
    SkipWhiteSpace;

    const Member = ReadValue;
    const Descriptor = TJSPropertyDescriptor.Create(Member);
    Target.DefineProperty(Name, Descriptor);
    SkipWhiteSpace;
  until not TryConsume(JSON_COMMA);

  Consume(JSON_OBJECT_END);
end;

function TJSJsonReader.ReadStringValue: TJSValue;
begin
  const Text = ReadString;

  Result := TJSValue.CreateString(Text);
end;

function TJSJsonReader.ReadArray: TJSValue;
begin
  EnsureStackAvailable;

  Inc(FPosition);
  SkipWhiteSpace;

  const Target = TJSArray.Create;
  Target.Prototype := FArrayPrototype;
  Result := TJSValue.CreateObject(Target);

  if TryConsume(JSON_ARRAY_END) then
    Exit;

  repeat
    SkipWhiteSpace;
    const Element = ReadValue;
    Target.Push(Element);
    SkipWhiteSpace;
  until not TryConsume(JSON_COMMA);

  Consume(JSON_ARRAY_END);
end;

function TJSJsonReader.ReadString: string;
begin
  Inc(FPosition);

  const Builder = TStringBuilder.Create;
  try
    while Current <> JSON_QUOTE do
    begin
      const Character = Current;
      Inc(FPosition);

      const IsEscape = (Character = JSON_ESCAPE);
      if IsEscape then
        Builder.Append(ReadEscape)
      else
        Builder.Append(Character);
    end;

    Inc(FPosition);
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TJSJsonReader.ReadEscape: Char;
begin
  const Escape = Current;
  Inc(FPosition);

  case Escape of
    'b'                 : Result := #8;
    'f'                 : Result := #12;
    'n'                 : Result := #10;
    'r'                 : Result := #13;
    't'                 : Result := #9;
    JSON_UNICODE_ESCAPE : Result := ReadUnicodeEscape;
  else
    Result := Escape;
  end;
end;

function TJSJsonReader.ReadUnicodeEscape: Char;
begin
  const Digits = Copy(FText, FPosition, JSON_UNICODE_ESCAPE_DIGITS);
  Inc(FPosition, JSON_UNICODE_ESCAPE_DIGITS);

  const HexText = Format(UNICODE_ESCAPE_FORMAT, [Digits]);
  const CodeUnit = StrToInt(HexText);
  Result := Char(CodeUnit);
end;

function TJSJsonReader.ReadNumber: TJSValue;
begin
  const Start = FPosition;
  while (FPosition <= Length(FText)) and CharInSet(Current, JSON_NUMBER_CHARACTERS) do
  begin
    Inc(FPosition);
  end;

  const Literal = Copy(FText, Start, FPosition - Start);
  const Number = TJSNumberParse.StringToNumber(Literal);

  Result := TJSValue.CreateNumber(Number);
end;

end.
