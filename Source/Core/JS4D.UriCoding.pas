unit JS4D.UriCoding;

interface

uses
  System.SysUtils,
  JS4D.Errors;

type
  TJSUriCoding = class
  private
    type
      TUtf8Lead = record
        Mask: Integer;
        Marker: Integer;
        PayloadMask: Integer;
      end;

    const
      UNRESERVED_MARKS = ['-', '_', '.', '!', '~', '*', '''', '(', ')'];
      ALPHANUMERIC = ['A'..'Z', 'a'..'z', '0'..'9'];
      RESERVED = [';', '/', '?', ':', '@', '&', '=', '+', '$', ',', '#'];
      ENCODE_URI_UNESCAPED: TSysCharSet = ALPHANUMERIC + UNRESERVED_MARKS + RESERVED;
      ENCODE_COMPONENT_UNESCAPED: TSysCharSet = ALPHANUMERIC + UNRESERVED_MARKS;
      DECODE_URI_PRESERVED: TSysCharSet = RESERVED;
      DECODE_COMPONENT_PRESERVED: TSysCharSet = [];
      HEX_DIGITS = '0123456789ABCDEF';
      PERCENT_SIGN = '%';
      PERCENT_ESCAPE_LENGTH = 3;
      NIBBLE_BITS = 4;
      NIBBLE_MASK = $0F;
      MAX_CONTINUATION_BYTES = 3;
      SINGLE_BYTE_LIMIT = $80;
      CONTINUATION_MARKER = $80;
      CONTINUATION_MASK = $C0;
      CONTINUATION_PAYLOAD_BITS = 6;
      CONTINUATION_PAYLOAD_MASK = $3F;
      MIN_CODE_POINT_BY_CONTINUATIONS: array[1..MAX_CONTINUATION_BYTES] of Integer = ($80, $800, $10000);
      UTF8_LEADS: array[1..MAX_CONTINUATION_BYTES] of TUtf8Lead = (
        (Mask: $E0; Marker: $C0; PayloadMask: $1F),
        (Mask: $F0; Marker: $E0; PayloadMask: $0F),
        (Mask: $F8; Marker: $F0; PayloadMask: $07)
      );

    var
      FText: string;
      FPosition: Integer;
      FCharSet: TSysCharSet;

    constructor Create(const Text: string; const CharSet: TSysCharSet);

    class function Encoded(const Text: string; const Unescaped: TSysCharSet): string; static;
    class function Decoded(const Text: string; const Preserved: TSysCharSet): string; static;

    function AtEnd: Boolean;
    function Encode: string;
    function Decode: string;

    function ReadCodePoint: Integer;
    function ContinuationCountOfCodePoint(const CodePoint: Integer): Integer;
    procedure AppendUtf8Escapes(const Builder: TStringBuilder; const CodePoint: Integer);
    procedure AppendEscape(const Builder: TStringBuilder; const ByteValue: Integer);

    procedure DecodeEscapeSequence(const Builder: TStringBuilder);
    function ReadEscapedByte: Integer;
    function ContinuationCount(const LeadByte: Integer): Integer;
    function ReadContinuedCodePoint(const LeadByte: Integer): Integer;
    procedure AppendCodePoint(const Builder: TStringBuilder; const CodePoint: Integer);

  public
    class function EncodeURI(const Text: string): string; static;
    class function EncodeURIComponent(const Text: string): string; static;
    class function DecodeURI(const Text: string): string; static;
    class function DecodeURIComponent(const Text: string): string; static;
  end;

implementation

uses
  System.Character,
  JS4D.AsciiDigits,
  JS4D.Utf16;

{ TJSUriCoding }

class function TJSUriCoding.EncodeURI(const Text: string): string;
begin
  Result := Encoded(Text, ENCODE_URI_UNESCAPED);
end;

class function TJSUriCoding.EncodeURIComponent(const Text: string): string;
begin
  Result := Encoded(Text, ENCODE_COMPONENT_UNESCAPED);
end;

class function TJSUriCoding.DecodeURI(const Text: string): string;
begin
  Result := Decoded(Text, DECODE_URI_PRESERVED);
end;

class function TJSUriCoding.DecodeURIComponent(const Text: string): string;
begin
  Result := Decoded(Text, DECODE_COMPONENT_PRESERVED);
end;

class function TJSUriCoding.Encoded(const Text: string; const Unescaped: TSysCharSet): string;
begin
  const Coding = TJSUriCoding.Create(Text, Unescaped);
  try
    Result := Coding.Encode;
  finally
    Coding.Free;
  end;
end;

class function TJSUriCoding.Decoded(const Text: string; const Preserved: TSysCharSet): string;
begin
  const Coding = TJSUriCoding.Create(Text, Preserved);
  try
    Result := Coding.Decode;
  finally
    Coding.Free;
  end;
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
  const First = FText[FPosition];
  Inc(FPosition);

  if First.IsLowSurrogate then
    raise TJSErrorFactory.MalformedUri;

  if not First.IsHighSurrogate then
  begin
    Result := Ord(First);
    Exit;
  end;

  if AtEnd then
    raise TJSErrorFactory.MalformedUri;

  const Second = FText[FPosition];
  if not Second.IsLowSurrogate then
    raise TJSErrorFactory.MalformedUri;

  Inc(FPosition);
  Result := Char.ConvertToUtf32(First, Second);
end;

function TJSUriCoding.ContinuationCountOfCodePoint(const CodePoint: Integer): Integer;
begin
  Result := 0;

  while (Result < MAX_CONTINUATION_BYTES) and (CodePoint >= MIN_CODE_POINT_BY_CONTINUATIONS[Result + 1]) do
  begin
    Inc(Result);
  end;
end;

procedure TJSUriCoding.AppendUtf8Escapes(const Builder: TStringBuilder; const CodePoint: Integer);
begin
  const Count = ContinuationCountOfCodePoint(CodePoint);
  if Count = 0 then
  begin
    AppendEscape(Builder, CodePoint);
    Exit;
  end;

  const LeadShift = Count * CONTINUATION_PAYLOAD_BITS;
  AppendEscape(Builder, UTF8_LEADS[Count].Marker or (CodePoint shr LeadShift));

  for var Index := Count - 1 downto 0 do
  begin
    const Payload = ((CodePoint shr (Index * CONTINUATION_PAYLOAD_BITS)) and CONTINUATION_PAYLOAD_MASK);
    AppendEscape(Builder, CONTINUATION_MARKER or Payload);
  end;
end;

procedure TJSUriCoding.AppendEscape(const Builder: TStringBuilder; const ByteValue: Integer);
begin
  Builder.Append(PERCENT_SIGN);
  Builder.Append(HEX_DIGITS[(ByteValue shr NIBBLE_BITS) + 1]);
  Builder.Append(HEX_DIGITS[(ByteValue and NIBBLE_MASK) + 1]);
end;

function TJSUriCoding.Decode: string;
begin
  const Builder = TStringBuilder.Create;
  try
    while not AtEnd do
    begin
      const Current = FText[FPosition];
      const IsEscape = (Current = PERCENT_SIGN);
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

  const IsSingleByte = (LeadByte < SINGLE_BYTE_LIMIT);
  if not IsSingleByte then
  begin
    const CodePoint = ReadContinuedCodePoint(LeadByte);
    AppendCodePoint(Builder, CodePoint);
    Exit;
  end;

  const Decoded = Char(LeadByte);
  const IsReserved = CharInSet(Decoded, FCharSet);
  if IsReserved then
    Builder.Append(FText, Start - 1, PERCENT_ESCAPE_LENGTH)
  else
    Builder.Append(Decoded);
end;

function TJSUriCoding.ReadEscapedByte: Integer;
begin
  const HasRoomForEscape = (FPosition + PERCENT_ESCAPE_LENGTH - 1 <= Length(FText));
  if not HasRoomForEscape then
    raise TJSErrorFactory.MalformedUri;

  const IsEscape = (FText[FPosition] = PERCENT_SIGN);
  const HighDigit = TJSAsciiDigits.HexValue(FText[FPosition + 1]);
  const LowDigit = TJSAsciiDigits.HexValue(FText[FPosition + 2]);
  const IsValid = (IsEscape and (HighDigit >= 0) and (LowDigit >= 0));
  if not IsValid then
    raise TJSErrorFactory.MalformedUri;

  Result := (HighDigit shl NIBBLE_BITS) or LowDigit;
  Inc(FPosition, PERCENT_ESCAPE_LENGTH);
end;

function TJSUriCoding.ContinuationCount(const LeadByte: Integer): Integer;
begin
  for var Count := 1 to MAX_CONTINUATION_BYTES do
  begin
    const IsLeadOfLength = ((LeadByte and UTF8_LEADS[Count].Mask) = UTF8_LEADS[Count].Marker);
    if IsLeadOfLength then
      Exit(Count);
  end;

  raise TJSErrorFactory.MalformedUri;
end;

function TJSUriCoding.ReadContinuedCodePoint(const LeadByte: Integer): Integer;
begin
  const Count = ContinuationCount(LeadByte);

  Result := LeadByte and UTF8_LEADS[Count].PayloadMask;
  for var Index := 1 to Count do
  begin
    const ContinuationByte = ReadEscapedByte;
    const IsContinuation = ((ContinuationByte and CONTINUATION_MASK) = CONTINUATION_MARKER);
    if not IsContinuation then
      raise TJSErrorFactory.MalformedUri;

    Result := (Result shl CONTINUATION_PAYLOAD_BITS) or (ContinuationByte and CONTINUATION_PAYLOAD_MASK);
  end;

  const IsOverlong = (Result < MIN_CODE_POINT_BY_CONTINUATIONS[Count]);
  const IsSurrogate = ((Result >= HIGH_SURROGATE_FIRST) and (Result <= LOW_SURROGATE_LAST));
  const IsOutOfRange = (Result > MAX_CODE_POINT);
  if IsOverlong or IsSurrogate or IsOutOfRange then
    raise TJSErrorFactory.MalformedUri;
end;

procedure TJSUriCoding.AppendCodePoint(const Builder: TStringBuilder; const CodePoint: Integer);
begin
  const Text = Char.ConvertFromUtf32(CodePoint);
  Builder.Append(Text);
end;

end.
