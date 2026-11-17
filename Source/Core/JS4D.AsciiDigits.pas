unit JS4D.AsciiDigits;

interface

type
  TJSAsciiDigits = class
  public
    const
      NOT_A_DIGIT = -1;
      HEX_RADIX = 16;
      LETTER_DIGIT_OFFSET = 10;
      HEX_VALUE_CEILING = $8000000;

    class function IsDigit(const Ch: Char): Boolean; static;
    class function DigitValue(const Ch: Char): Integer; static;
    class function IsDigitInRadix(const Ch: Char; const Radix: Integer): Boolean; static;
    class function IsHexDigit(const Ch: Char): Boolean; static;
    class function HexValue(const Ch: Char): Integer; static;
    class function TryParseHex(const Text: string; const Start: Integer; const Count: Integer;
                               out Value: Integer): Boolean; static;
  end;

implementation

{ TJSAsciiDigits }

class function TJSAsciiDigits.IsDigit(const Ch: Char): Boolean;
begin
  Result := (Ch >= '0') and (Ch <= '9');
end;

class function TJSAsciiDigits.DigitValue(const Ch: Char): Integer;
begin
  Result := NOT_A_DIGIT;

  if IsDigit(Ch) then
    Result := Ord(Ch) - Ord('0')
  else if (Ch >= 'a') and (Ch <= 'z') then
    Result := Ord(Ch) - Ord('a') + LETTER_DIGIT_OFFSET
  else if (Ch >= 'A') and (Ch <= 'Z') then
    Result := Ord(Ch) - Ord('A') + LETTER_DIGIT_OFFSET;
end;

class function TJSAsciiDigits.IsDigitInRadix(const Ch: Char; const Radix: Integer): Boolean;
begin
  const Digit = DigitValue(Ch);

  Result := (Digit >= 0) and (Digit < Radix);
end;

class function TJSAsciiDigits.HexValue(const Ch: Char): Integer;
begin
  Result := DigitValue(Ch);

  const IsHexValue = (Result < HEX_RADIX);
  if not IsHexValue then
    Result := NOT_A_DIGIT;
end;

class function TJSAsciiDigits.TryParseHex(const Text: string; const Start: Integer; const Count: Integer;
                                          out Value: Integer): Boolean;
begin
  Value := 0;

  const HasAllDigits = (Start >= 1) and (Start + Count - 1 <= Length(Text));
  if not HasAllDigits then
    Exit(False);

  for var Offset := 0 to Count - 1 do
  begin
    const Digit = HexValue(Text[Start + Offset]);
    const IsHexDigitText = (Digit <> NOT_A_DIGIT);
    if not IsHexDigitText then
      Exit(False);

    const HasRoomForDigit = (Value < HEX_VALUE_CEILING);
    if HasRoomForDigit then
      Value := (Value * HEX_RADIX) + Digit;
  end;

  Result := True;
end;

class function TJSAsciiDigits.IsHexDigit(const Ch: Char): Boolean;
begin
  Result := (HexValue(Ch) <> NOT_A_DIGIT);
end;

end.
