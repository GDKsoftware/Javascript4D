unit JS4D.NumberParse;

{$SCOPEDENUMS ON}

interface

type
  TJSNumberParse = class
  private
    const
      INFINITY_TEXT = 'Infinity';
      DECIMAL_POINT = '.';
      MINUS_SIGN = '-';
      PLUS_SIGN = '+';
      HEX_PREFIX_LENGTH = 2;
      HEX_RADIX = 16;
      OCTAL_RADIX = 8;
      BINARY_RADIX = 2;
      NOT_PREFIXED = 0;
      DEFAULT_RADIX = 10;
      MIN_RADIX = 2;
      MAX_RADIX = 36;
      NOT_A_DIGIT = -1;
      LETTER_DIGIT_OFFSET = 10;
      MAX_EXPONENT_DIGITS = 9;
      HUGE_EXPONENT = 1000000000;

    class function IsAsciiDigit(const Ch: Char): Boolean; static;
    class function DigitValue(const Ch: Char): Integer; static;
    class function IsDigitInRadix(const Ch: Char; const Radix: Integer): Boolean; static;
    class function IsSign(const Ch: Char): Boolean; static;
    class function IsExponentMark(const Ch: Char): Boolean; static;
    class function IsHexPrefix(const Text: string; const Position: Integer): Boolean; static;
    class function CountDigits(const Text: string; const Position: Integer): Integer; static;
    class function CountDigitsInRadix(const Text: string; const Position: Integer;
                                      const Radix: Integer): Integer; static;
    class function ExponentLength(const Text: string; const Position: Integer): Integer; static;
    class function DecimalPrefixLength(const Text: string): Integer; static;
    class function PrefixedLiteralRadix(const Text: string): Integer; static;
    class function ExponentMarkPosition(const Literal: string): Integer; static;
    class function ExponentOf(const Literal: string): Integer; static;
    class function OutOfRangeValue(const Literal: string): Double; static;
    class function ConvertSignedLiteral(const Literal: string): Double; static;
    class function AccumulateDigits(const Digits: string; const Radix: Integer): Double; static;
    class function TryResolveRadix(const Radix: Integer; out EffectiveRadix: Integer;
                                   out StripsPrefix: Boolean): Boolean; static;

  public
    class function IsWhiteSpace(const Ch: Char): Boolean; static;
    class function TrimStart(const Text: string): string; static;
    class function TrimEnd(const Text: string): string; static;
    class function Trim(const Text: string): string; static;
    class function DecimalToDouble(const Literal: string): Double; static;
    class function StringToNumber(const Text: string): Double; static;
    class function ParseInt(const Text: string; const Radix: Integer): Double; static;
    class function ParseFloat(const Text: string): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

class function TJSNumberParse.IsAsciiDigit(const Ch: Char): Boolean;
begin
  Result := (Ch >= '0') and (Ch <= '9');
end;

class function TJSNumberParse.DigitValue(const Ch: Char): Integer;
begin
  Result := NOT_A_DIGIT;

  if IsAsciiDigit(Ch) then
    Result := Ord(Ch) - Ord('0')
  else if (Ch >= 'a') and (Ch <= 'z') then
    Result := Ord(Ch) - Ord('a') + LETTER_DIGIT_OFFSET
  else if (Ch >= 'A') and (Ch <= 'Z') then
    Result := Ord(Ch) - Ord('A') + LETTER_DIGIT_OFFSET;
end;

class function TJSNumberParse.IsDigitInRadix(const Ch: Char; const Radix: Integer): Boolean;
begin
  const Digit = DigitValue(Ch);

  Result := (Digit >= 0) and (Digit < Radix);
end;

class function TJSNumberParse.IsSign(const Ch: Char): Boolean;
begin
  Result := (Ch = PLUS_SIGN) or (Ch = MINUS_SIGN);
end;

class function TJSNumberParse.IsExponentMark(const Ch: Char): Boolean;
begin
  Result := (Ch = 'e') or (Ch = 'E');
end;

class function TJSNumberParse.IsHexPrefix(const Text: string; const Position: Integer): Boolean;
begin
  const HasRoom = (Position + 1 <= Length(Text));
  if not HasRoom then
    Exit(False);

  const HasZero = (Text[Position] = '0');
  const HasMark = (Text[Position + 1] = 'x') or (Text[Position + 1] = 'X');
  Result := HasZero and HasMark;
end;

class function TJSNumberParse.IsWhiteSpace(const Ch: Char): Boolean;
begin
  case Ch of
    #$0009, #$000A, #$000B, #$000C, #$000D, #$0020, #$00A0, #$1680,
    #$2000..#$200A, #$2028, #$2029, #$202F, #$205F, #$3000, #$FEFF:
      Result := True;
  else
    Result := False;
  end;
end;

class function TJSNumberParse.TrimStart(const Text: string): string;
begin
  var First := 1;
  while (First <= Length(Text)) and IsWhiteSpace(Text[First]) do
  begin
    Inc(First);
  end;

  Result := Text.Substring(First - 1);
end;

class function TJSNumberParse.TrimEnd(const Text: string): string;
begin
  var Last := Length(Text);
  while (Last >= 1) and IsWhiteSpace(Text[Last]) do
  begin
    Dec(Last);
  end;

  Result := Text.Substring(0, Last);
end;

class function TJSNumberParse.Trim(const Text: string): string;
begin
  const WithoutLeading = TrimStart(Text);

  Result := TrimEnd(WithoutLeading);
end;

class function TJSNumberParse.CountDigits(const Text: string; const Position: Integer): Integer;
begin
  Result := 0;

  while (Position + Result <= Length(Text)) and IsAsciiDigit(Text[Position + Result]) do
  begin
    Inc(Result);
  end;
end;

class function TJSNumberParse.CountDigitsInRadix(const Text: string; const Position: Integer;
                                                 const Radix: Integer): Integer;
begin
  Result := 0;

  while (Position + Result <= Length(Text)) and IsDigitInRadix(Text[Position + Result], Radix) do
  begin
    Inc(Result);
  end;
end;

class function TJSNumberParse.ExponentLength(const Text: string; const Position: Integer): Integer;
begin
  Result := 0;

  const HasMark = (Position <= Length(Text)) and IsExponentMark(Text[Position]);
  if not HasMark then
    Exit;

  var DigitsStart := Position + 1;
  const HasSign = (DigitsStart <= Length(Text)) and IsSign(Text[DigitsStart]);
  if HasSign then
    Inc(DigitsStart);

  const DigitCount = CountDigits(Text, DigitsStart);
  const HasDigits = (DigitCount > 0);
  if HasDigits then
    Result := DigitsStart + DigitCount - Position;
end;

class function TJSNumberParse.DecimalPrefixLength(const Text: string): Integer;
begin
  var Position := 1;
  const HasSign = (Position <= Length(Text)) and IsSign(Text[Position]);
  if HasSign then
    Inc(Position);

  const HasInfinity = (Copy(Text, Position, Length(INFINITY_TEXT)) = INFINITY_TEXT);
  if HasInfinity then
    Exit(Position - 1 + Length(INFINITY_TEXT));

  const IntegerDigits = CountDigits(Text, Position);
  Inc(Position, IntegerDigits);

  var FractionDigits := 0;
  const HasPoint = (Position <= Length(Text)) and (Text[Position] = DECIMAL_POINT);
  if HasPoint then
    FractionDigits := CountDigits(Text, Position + 1);

  const HasDigits = (IntegerDigits + FractionDigits > 0);
  if not HasDigits then
    Exit(0);

  if HasPoint then
    Inc(Position, FractionDigits + 1);

  Result := Position - 1 + ExponentLength(Text, Position);
end;

class function TJSNumberParse.ExponentMarkPosition(const Literal: string): Integer;
begin
  Result := Literal.IndexOfAny(['e', 'E']);
end;

class function TJSNumberParse.ExponentOf(const Literal: string): Integer;
begin
  Result := 0;

  const MarkPosition = ExponentMarkPosition(Literal);
  if MarkPosition < 0 then
    Exit;

  var Digits := Literal.Substring(MarkPosition + 1);
  const IsNegative = Digits.StartsWith(MINUS_SIGN);
  if IsSign(Digits[1]) then
    Digits := Digits.Substring(1);

  Digits := Digits.TrimLeft(['0']);
  const IsHuge = (Length(Digits) > MAX_EXPONENT_DIGITS);
  if IsHuge then
    Result := HUGE_EXPONENT
  else if not Digits.IsEmpty then
    Result := StrToInt(Digits);

  if IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.OutOfRangeValue(const Literal: string): Double;
begin
  var Mantissa := Literal;
  const MarkPosition = ExponentMarkPosition(Literal);
  if MarkPosition >= 0 then
    Mantissa := Mantissa.Substring(0, MarkPosition);

  const PointPosition = Mantissa.IndexOf(DECIMAL_POINT);
  var IntegerPart := Mantissa;
  if PointPosition >= 0 then
    IntegerPart := Mantissa.Substring(0, PointPosition);

  const SignificantInteger = IntegerPart.TrimLeft(['0']);
  const HasMagnitude = (Length(SignificantInteger) + ExponentOf(Literal) > 0);

  const MantissaDigits = Mantissa.Replace(DECIMAL_POINT, '');
  const IsAllZero = MantissaDigits.TrimLeft(['0']).IsEmpty;

  if IsAllZero or not HasMagnitude then
    Result := 0
  else
    Result := Infinity;
end;

class function TJSNumberParse.DecimalToDouble(const Literal: string): Double;
begin
  if TryStrToFloat(Literal, Result, TFormatSettings.Invariant) then
    Exit;

  Result := OutOfRangeValue(Literal);
end;

class function TJSNumberParse.ConvertSignedLiteral(const Literal: string): Double;
begin
  var Unsigned := Literal;
  const IsNegative = Literal.StartsWith(MINUS_SIGN);
  if IsSign(Literal[1]) then
    Unsigned := Literal.Substring(1);

  if Unsigned = INFINITY_TEXT then
    Result := Infinity
  else
    Result := DecimalToDouble(Unsigned);

  if IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.AccumulateDigits(const Digits: string; const Radix: Integer): Double;
begin
  Result := 0;

  for var Digit in Digits do
  begin
    Result := Result * Radix + DigitValue(Digit);
  end;
end;

class function TJSNumberParse.PrefixedLiteralRadix(const Text: string): Integer;
begin
  Result := NOT_PREFIXED;

  const HasDigits = (Length(Text) > HEX_PREFIX_LENGTH);
  const HasZeroPrefix = HasDigits and (Text[1] = '0');
  if not HasZeroPrefix then
    Exit;

  case Text[2] of
    'x', 'X' : Result := HEX_RADIX;
    'o', 'O' : Result := OCTAL_RADIX;
    'b', 'B' : Result := BINARY_RADIX;
  else
    Exit;
  end;

  const DigitCount = CountDigitsInRadix(Text, HEX_PREFIX_LENGTH + 1, Result);
  const IsWholeLiteral = (HEX_PREFIX_LENGTH + DigitCount = Length(Text));
  if not IsWholeLiteral then
    Result := NOT_PREFIXED;
end;

class function TJSNumberParse.StringToNumber(const Text: string): Double;
begin
  const Trimmed = Trim(Text);
  if Trimmed.IsEmpty then
    Exit(0);

  const PrefixedRadix = PrefixedLiteralRadix(Trimmed);
  if PrefixedRadix <> NOT_PREFIXED then
    Exit(AccumulateDigits(Trimmed.Substring(HEX_PREFIX_LENGTH), PrefixedRadix));

  const IsWholeLiteral = (DecimalPrefixLength(Trimmed) = Length(Trimmed));
  if IsWholeLiteral then
    Result := ConvertSignedLiteral(Trimmed)
  else
    Result := NaN;
end;

class function TJSNumberParse.TryResolveRadix(const Radix: Integer; out EffectiveRadix: Integer;
                                              out StripsPrefix: Boolean): Boolean;
begin
  EffectiveRadix := Radix;
  StripsPrefix := True;

  const IsDefault = (Radix = 0);
  if IsDefault then
  begin
    EffectiveRadix := DEFAULT_RADIX;
    Exit(True);
  end;

  Result := (Radix >= MIN_RADIX) and (Radix <= MAX_RADIX);
  StripsPrefix := (Radix = HEX_RADIX);
end;

class function TJSNumberParse.ParseInt(const Text: string; const Radix: Integer): Double;
begin
  var EffectiveRadix: Integer;
  var StripsPrefix: Boolean;
  const IsSupportedRadix = TryResolveRadix(Radix, EffectiveRadix, StripsPrefix);
  if not IsSupportedRadix then
    Exit(NaN);

  const Trimmed = TrimStart(Text);
  const IsNegative = Trimmed.StartsWith(MINUS_SIGN);

  var Position := 1;
  const HasSign = (Position <= Length(Trimmed)) and IsSign(Trimmed[Position]);
  if HasSign then
    Inc(Position);

  const HasHexPrefix = StripsPrefix and IsHexPrefix(Trimmed, Position);
  if HasHexPrefix then
  begin
    Inc(Position, HEX_PREFIX_LENGTH);
    EffectiveRadix := HEX_RADIX;
  end;

  const DigitCount = CountDigitsInRadix(Trimmed, Position, EffectiveRadix);
  if DigitCount = 0 then
    Exit(NaN);

  const Digits = Trimmed.Substring(Position - 1, DigitCount);
  if EffectiveRadix = DEFAULT_RADIX then
    Result := DecimalToDouble(Digits)
  else
    Result := AccumulateDigits(Digits, EffectiveRadix);

  if IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.ParseFloat(const Text: string): Double;
begin
  const Trimmed = TrimStart(Text);

  const PrefixLength = DecimalPrefixLength(Trimmed);
  if PrefixLength = 0 then
    Exit(NaN);

  const Prefix = Trimmed.Substring(0, PrefixLength);
  Result := ConvertSignedLiteral(Prefix);
end;

end.
