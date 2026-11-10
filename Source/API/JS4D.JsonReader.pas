unit JS4D.JsonReader;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types;

type
  TJSJsonReader = class
  private
    const
      WhiteSpace = [' ', #9, #10, #13];
      NumberCharacters = ['0'..'9', '-', '+', '.', 'e', 'E'];
      UnicodeEscapeDigits = 4;
      UnicodeEscapeFormat = '$%s';
      ObjectEnd = '}';
      ArrayEnd = ']';
      StringDelimiter = '"';
      TrueLiteral = 'true';
      FalseLiteral = 'false';
      NullLiteral = 'null';

    var
      FText: string;
      FPosition: Integer;
      FObjectPrototype: IJSObject;
      FArrayPrototype: IJSObject;

    constructor Create(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject);

    function Current: Char;
    procedure SkipWhiteSpace;
    function TryConsume(const Expected: Char): Boolean;

    function ReadValue: TJSValue;
    function ReadLiteral(const Literal: string; const Value: TJSValue): TJSValue;
    function ReadObject: TJSValue;
    function ReadArray: TJSValue;
    function ReadStringValue: TJSValue;
    function ReadString: string;
    function ReadEscape: Char;
    function ReadNumber: TJSValue;

  public
    class function Read(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject): TJSValue; static;
  end;

implementation

uses
  JS4D.NumberParse;

constructor TJSJsonReader.Create(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject);
begin
  inherited Create;
  FText := Text;
  FPosition := 1;
  FObjectPrototype := ObjectPrototype;
  FArrayPrototype := ArrayPrototype;
end;

class function TJSJsonReader.Read(const Text: string; const ObjectPrototype, ArrayPrototype: IJSObject): TJSValue;
begin
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
  while CharInSet(Current, WhiteSpace) do
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

function TJSJsonReader.ReadValue: TJSValue;
begin
  case Current of
    '{': Result := ReadObject;
    '[': Result := ReadArray;
    '"': Result := ReadStringValue;
    't': Result := ReadLiteral(TrueLiteral, TJSValue.CreateBoolean(True));
    'f': Result := ReadLiteral(FalseLiteral, TJSValue.CreateBoolean(False));
    'n': Result := ReadLiteral(NullLiteral, TJSValue.CreateNull);
  else
    Result := ReadNumber;
  end;
end;

function TJSJsonReader.ReadLiteral(const Literal: string; const Value: TJSValue): TJSValue;
begin
  Inc(FPosition, Length(Literal));
  Result := Value;
end;

function TJSJsonReader.ReadObject: TJSValue;
begin
  Inc(FPosition);
  SkipWhiteSpace;

  const Target = TJSObject.Create;
  Target.Prototype := FObjectPrototype;
  Result := TJSValue.CreateObject(Target);

  if TryConsume(ObjectEnd) then
    Exit;

  repeat
    SkipWhiteSpace;
    const Name = ReadString;
    SkipWhiteSpace;
    TryConsume(':');
    SkipWhiteSpace;

    const Member = ReadValue;
    Target.DefineProperty(Name, TJSPropertyDescriptor.Create(Member));
    SkipWhiteSpace;
  until not TryConsume(',');

  TryConsume(ObjectEnd);
end;

function TJSJsonReader.ReadStringValue: TJSValue;
begin
  const Text = ReadString;

  Result := TJSValue.CreateString(Text);
end;

function TJSJsonReader.ReadArray: TJSValue;
begin
  Inc(FPosition);
  SkipWhiteSpace;

  const Target = TJSArray.Create;
  Target.Prototype := FArrayPrototype;
  Result := TJSValue.CreateObject(Target);

  if TryConsume(ArrayEnd) then
    Exit;

  repeat
    SkipWhiteSpace;
    const Element = ReadValue;
    Target.Push(Element);
    SkipWhiteSpace;
  until not TryConsume(',');

  TryConsume(ArrayEnd);
end;

function TJSJsonReader.ReadString: string;
begin
  Inc(FPosition);

  const Builder = TStringBuilder.Create;
  try
    while Current <> StringDelimiter do
    begin
      const Character = Current;
      Inc(FPosition);

      const IsEscape = (Character = '\');
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
    'b': Result := #8;
    'f': Result := #12;
    'n': Result := #10;
    'r': Result := #13;
    't': Result := #9;
    'u':
      begin
        const Digits = Copy(FText, FPosition, UnicodeEscapeDigits);
        Inc(FPosition, UnicodeEscapeDigits);
        Result := Char(StrToInt(Format(UnicodeEscapeFormat, [Digits])));
      end;
  else
    Result := Escape;
  end;
end;

function TJSJsonReader.ReadNumber: TJSValue;
begin
  const Start = FPosition;
  while (FPosition <= Length(FText)) and CharInSet(Current, NumberCharacters) do
  begin
    Inc(FPosition);
  end;

  const Literal = Copy(FText, Start, FPosition - Start);
  const Number = TJSNumberParse.StringToNumber(Literal);

  Result := TJSValue.CreateNumber(Number);
end;

end.
