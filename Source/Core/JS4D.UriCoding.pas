unit JS4D.UriCoding;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Errors;

type
  TJSUriCoding = class
  private
    const
      UNRESERVED_MARKS = ['-', '_', '.', '!', '~', '*', '''', '(', ')'];
      ALPHANUMERIC = ['A'..'Z', 'a'..'z', '0'..'9'];
      RESERVED = [';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '#'];
      ESCAPE_LENGTH = 3;
      MAX_CONTINUATION_BYTES = 3;
      HIGH_SURROGATE_FIRST = $D800;
      HIGH_SURROGATE_LAST = $DBFF;
      LOW_SURROGATE_FIRST = $DC00;
      LOW_SURROGATE_LAST = $DFFF;
      FIRST_SUPPLEMENTARY_CODE_POINT = $10000;
      LAST_CODE_POINT = $10FFFF;
      MIN_CODE_POINT_BY_CONTINUATIONS: array[1..MAX_CONTINUATION_BYTES] of Integer = ($80, $800, $10000);

    var
      FText: string;
      FPosition: Integer;
      FCharSet: TSysCharSet;

    constructor Create(const Text: string; const CharSet: TSysCharSet);

    function AtEnd: Boolean;
    function Encode: string;
    function Decode: string;

    function ReadCodePoint: Integer;
    procedure AppendUtf8Escapes(const Builder: TStringBuilder; const CodePoint: Integer);
    procedure AppendEscape(const Builder: TStringBuilder; const ByteValue: Integer);

    procedure DecodeEscapeSequence(const Builder: TStringBuilder);
    function ReadEscapedByte: Integer;
    function ContinuationCount(const LeadByte: Integer): Integer;
    function ReadContinuedCodePoint(const LeadByte: Integer): Integer;
    procedure AppendCodePoint(const Builder: TStringBuilder; const CodePoint: Integer);

    class function HexValue(const Digit: Char): Integer; static;
    class function IsHighSurrogate(const Value: Integer): Boolean; static;
    class function IsLowSurrogate(const Value: Integer): Boolean; static;
    class function Malformed: EJSURIError; static;

  public
    class function EncodeURI(const Text: string): string; static;
    class function EncodeURIComponent(const Text: string): string; static;
    class function DecodeURI(const Text: string): string; static;
    class function DecodeURIComponent(const Text: string): string; static;
  end;

implementation

const
  URIErrorPrefix = 'URIError: ';
  MalformedMessage = 'URI malformed';

{ TJSUriCoding }

class function TJSUriCoding.EncodeURI(const Text: string): string;
begin
  const Coding = TJSUriCoding.Create(Text, ALPHANUMERIC + UNRESERVED_MARKS + RESERVED);
  try
    Result := Coding.Encode;
  finally
    Coding.Free;
  end;
end;

class function TJSUriCoding.EncodeURIComponent(const Text: string): string;
begin
  const Coding = TJSUriCoding.Create(Text, ALPHANUMERIC + UNRESERVED_MARKS);
  try
    Result := Coding.Encode;
  finally
    Coding.Free;
  end;
end;

class function TJSUriCoding.DecodeURI(const Text: string): string;
begin
  const Coding = TJSUriCoding.Create(Text, RESERVED);
  try
    Result := Coding.Decode;
  finally
    Coding.Free;
  end;
end;

class function TJSUriCoding.DecodeURIComponent(const Text: string): string;
begin
  const Coding = TJSUriCoding.Create(Text, []);
  try
    Result := Coding.Decode;
  finally
    Coding.Free;
  end;
end;

class function TJSUriCoding.HexValue(const Digit: Char): Integer;
begin
  case Digit of
    '0'..'9': Result := Ord(Digit) - Ord('0');
    'A'..'F': Result := Ord(Digit) - Ord('A') + 10;
    'a'..'f': Result := Ord(Digit) - Ord('a') + 10;
  else
    Result := -1;
  end;
end;

class function TJSUriCoding.IsHighSurrogate(const Value: Integer): Boolean;
begin
  Result := ((Value >= HIGH_SURROGATE_FIRST) and (Value <= HIGH_SURROGATE_LAST));
end;

class function TJSUriCoding.IsLowSurrogate(const Value: Integer): Boolean;
begin
  Result := ((Value >= LOW_SURROGATE_FIRST) and (Value <= LOW_SURROGATE_LAST));
end;

class function TJSUriCoding.Malformed: EJSURIError;
begin
  Result := EJSURIError.Create(URIErrorPrefix + MalformedMessage);
end;

constructor TJSUriCoding.Create(const Text: string; const CharSet: TSysCharSet);
begin
  inherited Create;
  FText := Text;
  FPosition := 1;
  FCharSet := CharSet;
end;

function TJSUriCoding.AtEnd: Boolean;
begin
  Result := (FPosition > Length(FText));
end;

function TJSUriCoding.Encode: string;
begin
  const Builder = TStringBuilder.Create;
  try
    while not AtEnd do
    begin
      const Current = FText[FPosition];
      const IsUnescaped = CharInSet(Current, FCharSet);
      if IsUnescaped then
      begin
        Builder.Append(Current);
        Inc(FPosition);
      end
      else
      begin
        const CodePoint = ReadCodePoint;
        AppendUtf8Escapes(Builder, CodePoint);
      end;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TJSUriCoding.ReadCodePoint: Integer;
begin
  Result := Ord(FText[FPosition]);
  Inc(FPosition);

  if IsLowSurrogate(Result) then
    raise Malformed;

  if not IsHighSurrogate(Result) then
    Exit;

  if AtEnd then
    raise Malformed;

  const LowSurrogate = Ord(FText[FPosition]);
  if not IsLowSurrogate(LowSurrogate) then
    raise Malformed;

  Inc(FPosition);
  Result := (Result - HIGH_SURROGATE_FIRST) * $400 + (LowSurrogate - LOW_SURROGATE_FIRST) +
            FIRST_SUPPLEMENTARY_CODE_POINT;
end;

procedure TJSUriCoding.AppendUtf8Escapes(const Builder: TStringBuilder; const CodePoint: Integer);
begin
  if CodePoint < $80 then
  begin
    AppendEscape(Builder, CodePoint);
  end
  else if CodePoint < $800 then
  begin
    AppendEscape(Builder, $C0 or (CodePoint shr 6));
    AppendEscape(Builder, $80 or (CodePoint and $3F));
  end
  else if CodePoint < FIRST_SUPPLEMENTARY_CODE_POINT then
  begin
    AppendEscape(Builder, $E0 or (CodePoint shr 12));
    AppendEscape(Builder, $80 or ((CodePoint shr 6) and $3F));
    AppendEscape(Builder, $80 or (CodePoint and $3F));
  end
  else
  begin
    AppendEscape(Builder, $F0 or (CodePoint shr 18));
    AppendEscape(Builder, $80 or ((CodePoint shr 12) and $3F));
    AppendEscape(Builder, $80 or ((CodePoint shr 6) and $3F));
    AppendEscape(Builder, $80 or (CodePoint and $3F));
  end;
end;

procedure TJSUriCoding.AppendEscape(const Builder: TStringBuilder; const ByteValue: Integer);
begin
  const Escape = Format('%%%.2X', [ByteValue]);
  Builder.Append(Escape);
end;

function TJSUriCoding.Decode: string;
begin
  const Builder = TStringBuilder.Create;
  try
    while not AtEnd do
    begin
      const Current = FText[FPosition];
      const IsEscape = (Current = '%');
      if IsEscape then
      begin
        DecodeEscapeSequence(Builder);
      end
      else
      begin
        Builder.Append(Current);
        Inc(FPosition);
      end;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

procedure TJSUriCoding.DecodeEscapeSequence(const Builder: TStringBuilder);
begin
  const Start = FPosition;
  const LeadByte = ReadEscapedByte;

  const IsSingleByte = (LeadByte < $80);
  if not IsSingleByte then
  begin
    const CodePoint = ReadContinuedCodePoint(LeadByte);
    AppendCodePoint(Builder, CodePoint);
    Exit;
  end;

  const Decoded = Char(LeadByte);
  const IsReserved = CharInSet(Decoded, FCharSet);
  if IsReserved then
    Builder.Append(FText, Start - 1, ESCAPE_LENGTH)
  else
    Builder.Append(Decoded);
end;

function TJSUriCoding.ReadEscapedByte: Integer;
begin
  const HasRoomForEscape = (FPosition + ESCAPE_LENGTH - 1 <= Length(FText));
  if not HasRoomForEscape then
    raise Malformed;

  const IsEscape = (FText[FPosition] = '%');
  const HighDigit = HexValue(FText[FPosition + 1]);
  const LowDigit = HexValue(FText[FPosition + 2]);
  const IsValid = (IsEscape and (HighDigit >= 0) and (LowDigit >= 0));
  if not IsValid then
    raise Malformed;

  Result := HighDigit * 16 + LowDigit;
  Inc(FPosition, ESCAPE_LENGTH);
end;

function TJSUriCoding.ContinuationCount(const LeadByte: Integer): Integer;
begin
  if (LeadByte and $E0) = $C0 then
    Result := 1
  else if (LeadByte and $F0) = $E0 then
    Result := 2
  else if (LeadByte and $F8) = $F0 then
    Result := 3
  else
    raise Malformed;
end;

function TJSUriCoding.ReadContinuedCodePoint(const LeadByte: Integer): Integer;
begin
  const Count = ContinuationCount(LeadByte);

  Result := LeadByte and ($3F shr Count);
  for var Index := 1 to Count do
  begin
    const ContinuationByte = ReadEscapedByte;
    const IsContinuation = ((ContinuationByte and $C0) = $80);
    if not IsContinuation then
      raise Malformed;

    Result := (Result shl 6) or (ContinuationByte and $3F);
  end;

  const IsOverlong = (Result < MIN_CODE_POINT_BY_CONTINUATIONS[Count]);
  const IsSurrogate = (IsHighSurrogate(Result) or IsLowSurrogate(Result));
  const IsOutOfRange = (Result > LAST_CODE_POINT);
  if IsOverlong or IsSurrogate or IsOutOfRange then
    raise Malformed;
end;

procedure TJSUriCoding.AppendCodePoint(const Builder: TStringBuilder; const CodePoint: Integer);
begin
  const IsSupplementary = (CodePoint >= FIRST_SUPPLEMENTARY_CODE_POINT);
  if not IsSupplementary then
  begin
    Builder.Append(Char(CodePoint));
    Exit;
  end;

  const Offset = CodePoint - FIRST_SUPPLEMENTARY_CODE_POINT;
  Builder.Append(Char(HIGH_SURROGATE_FIRST + (Offset shr 10)));
  Builder.Append(Char(LOW_SURROGATE_FIRST + (Offset and $3FF)));
end;

end.
