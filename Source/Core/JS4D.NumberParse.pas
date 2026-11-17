unit JS4D.NumberParse;

interface

type
  TJSNumberParse = class
  private
    type
      TSignedText = record
        IsNegative: Boolean;
        Unsigned: string;
      end;

      TRadixRule = record
        IsSupported: Boolean;
        Radix: Integer;
        StripsPrefix: Boolean;
      end;

      TIntegerBody = record
        Digits: string;
        Radix: Integer;
      end;

    const
      DECIMAL_POINT = '.';
      PLUS_SIGN = '+';
      ZERO_DIGIT = '0';
      EXPONENT_MARKS = ['e', 'E'];
      HEX_PREFIX_MARKS = ['x', 'X'];
      OCTAL_PREFIX_MARKS = ['o', 'O'];
      BINARY_PREFIX_MARKS = ['b', 'B'];
      RADIX_PREFIX_LENGTH = 2;
      HEX_RADIX = 16;
      OCTAL_RADIX = 8;
      BINARY_RADIX = 2;
      NOT_PREFIXED = 0;
      RADIX_UNSPECIFIED = 0;
      DEFAULT_RADIX = 10;
      MIN_RADIX = 2;
      MAX_RADIX = 36;
      MAX_EXPONENT_DIGITS = 9;
      HUGE_EXPONENT = 1000000000;

    class function IsSign(const Ch: Char): Boolean; static;
    class function IsExponentMark(const Ch: Char): Boolean; static;
    class function IsHexPrefix(const Text: string; const Position: Integer): Boolean; static;
    class function SplitSign(const Text: string): TSignedText; static;
    class function CountDigits(const Text: string; const Position: Integer): Integer; static;
    class function CountDigitsInRadix(const Text: string; const Position: Integer;
                                      const Radix: Integer): Integer; static;
    class function ExponentLength(const Text: string; const Position: Integer): Integer; static;
    class function DecimalPrefixLength(const Text: string): Integer; static;
    class function RadixOfPrefixMark(const Mark: Char): Integer; static;
    class function PrefixedLiteralRadix(const Text: string): Integer; static;
    class function ExponentMarkPosition(const Literal: string): Integer; static;
    class function ExponentOf(const Literal: string): Integer; static;
    class function ConvertSignedLiteral(const Literal: string): Double; static;
    class function AccumulateDigits(const Digits: string; const Radix: Integer): Double; static;
    class function ResolveRadix(const Radix: Integer): TRadixRule; static;
    class function ReadIntegerBody(const Unsigned: string; const RadixRule: TRadixRule): TIntegerBody; static;

  public
    class function DecimalToDouble(const Literal: string): Double; static;
    class function StringToNumber(const Text: string): Double; static;
    class function ParseInt(const Text: string; const Radix: Integer): Double; static;
    class function ParseFloat(const Text: string): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  JS4D.AsciiDigits,
  JS4D.DecimalConversion,
  JS4D.JsWhiteSpace,
  JS4D.NumberText;

class function TJSNumberParse.IsSign(const Ch: Char): Boolean;
begin
  Result := (Ch = PLUS_SIGN) or (Ch = MINUS_SIGN);
end;

class function TJSNumberParse.IsExponentMark(const Ch: Char): Boolean;
begin
  Result := CharInSet(Ch, EXPONENT_MARKS);
end;

class function TJSNumberParse.IsHexPrefix(const Text: string; const Position: Integer): Boolean;
begin
  const HasRoom = (Position + 1 <= Length(Text));
  if not HasRoom then
    Exit(False);

  const HasZero = (Text[Position] = ZERO_DIGIT);
  const HasMark = CharInSet(Text[Position + 1], HEX_PREFIX_MARKS);
  Result := HasZero and HasMark;
end;

class function TJSNumberParse.SplitSign(const Text: string): TSignedText;
begin
  Result.IsNegative := Text.StartsWith(MINUS_SIGN);
  Result.Unsigned := Text;

  const HasSign = (not Text.IsEmpty) and IsSign(Text[1]);
  if HasSign then
    Result.Unsigned := Text.Substring(1);
end;

class function TJSNumberParse.CountDigits(const Text: string; const Position: Integer): Integer;
begin
  Result := 0;

  while (Position + Result <= Length(Text)) and TJSAsciiDigits.IsDigit(Text[Position + Result]) do
  begin
    Inc(Result);
  end;
end;

class function TJSNumberParse.CountDigitsInRadix(const Text: string; const Position: Integer;
                                                 const Radix: Integer): Integer;
begin
  Result := 0;

  while (Position + Result <= Length(Text)) and
        TJSAsciiDigits.IsDigitInRadix(Text[Position + Result], Radix) do
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
  for var Index := 0 to Length(Literal) - 1 do
  begin
    if IsExponentMark(Literal[Index + 1]) then
      Exit(Index);
  end;

  Result := -1;
end;

class function TJSNumberParse.ExponentOf(const Literal: string): Integer;
begin
  Result := 0;

  const MarkPosition = ExponentMarkPosition(Literal);
  const HasExponent = (MarkPosition >= 0);
  if not HasExponent then
    Exit;

  const Signed = SplitSign(Literal.Substring(MarkPosition + 1));
  const Digits = Signed.Unsigned.TrimLeft([ZERO_DIGIT]);
  const IsHuge = (Length(Digits) > MAX_EXPONENT_DIGITS);
  if IsHuge then
    Result := HUGE_EXPONENT
  else if not Digits.IsEmpty then
    Result := StrToInt(Digits);

  if Signed.IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.DecimalToDouble(const Literal: string): Double;
begin
  var Mantissa := Literal;
  const MarkPosition = ExponentMarkPosition(Literal);
  const HasExponent = (MarkPosition >= 0);
  if HasExponent then
    Mantissa := Mantissa.Substring(0, MarkPosition);

  var IntegerPart := Mantissa;
  var FractionPart := '';
  const PointPosition = Mantissa.IndexOf(DECIMAL_POINT);
  const HasPoint = (PointPosition >= 0);
  if HasPoint then
  begin
    IntegerPart := Mantissa.Substring(0, PointPosition);
    FractionPart := Mantissa.Substring(PointPosition + 1);
  end;

  const Scale = ExponentOf(Literal) - Length(FractionPart);

  Result := TJSDecimalConversion.ToDouble(IntegerPart + FractionPart, Scale);
end;

class function TJSNumberParse.ConvertSignedLiteral(const Literal: string): Double;
begin
  const Signed = SplitSign(Literal);

  const IsInfinity = (Signed.Unsigned = INFINITY_TEXT);
  if IsInfinity then
    Result := Infinity
  else
    Result := DecimalToDouble(Signed.Unsigned);

  if Signed.IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.AccumulateDigits(const Digits: string; const Radix: Integer): Double;
begin
  Result := 0;

  for var Digit in Digits do
  begin
    Result := Result * Radix + TJSAsciiDigits.DigitValue(Digit);
  end;
end;

class function TJSNumberParse.RadixOfPrefixMark(const Mark: Char): Integer;
begin
  if CharInSet(Mark, HEX_PREFIX_MARKS) then
    Result := HEX_RADIX
  else if CharInSet(Mark, OCTAL_PREFIX_MARKS) then
    Result := OCTAL_RADIX
  else if CharInSet(Mark, BINARY_PREFIX_MARKS) then
    Result := BINARY_RADIX
  else
    Result := NOT_PREFIXED;
end;

class function TJSNumberParse.PrefixedLiteralRadix(const Text: string): Integer;
begin
  const HasDigits = (Length(Text) > RADIX_PREFIX_LENGTH);
  const HasZeroPrefix = HasDigits and (Text[1] = ZERO_DIGIT);
  if not HasZeroPrefix then
    Exit(NOT_PREFIXED);

  Result := RadixOfPrefixMark(Text[2]);
  const IsPrefixed = (Result <> NOT_PREFIXED);
  if not IsPrefixed then
    Exit;

  const DigitCount = CountDigitsInRadix(Text, RADIX_PREFIX_LENGTH + 1, Result);
  const IsWholeLiteral = (RADIX_PREFIX_LENGTH + DigitCount = Length(Text));
  if not IsWholeLiteral then
    Result := NOT_PREFIXED;
end;

class function TJSNumberParse.StringToNumber(const Text: string): Double;
begin
  const Trimmed = TJSWhiteSpace.TrimBoth(Text);
  if Trimmed.IsEmpty then
    Exit(0);

  const PrefixedRadix = PrefixedLiteralRadix(Trimmed);
  const IsPrefixed = (PrefixedRadix <> NOT_PREFIXED);
  if IsPrefixed then
  begin
    const PrefixedDigits = Trimmed.Substring(RADIX_PREFIX_LENGTH);
    Result := AccumulateDigits(PrefixedDigits, PrefixedRadix);
    Exit;
  end;

  const IsWholeLiteral = (DecimalPrefixLength(Trimmed) = Length(Trimmed));
  if IsWholeLiteral then
    Result := ConvertSignedLiteral(Trimmed)
  else
    Result := NaN;
end;

class function TJSNumberParse.ResolveRadix(const Radix: Integer): TRadixRule;
begin
  Result.Radix := Radix;
  Result.IsSupported := True;
  Result.StripsPrefix := True;

  const IsUnspecified = (Radix = RADIX_UNSPECIFIED);
  if IsUnspecified then
  begin
    Result.Radix := DEFAULT_RADIX;
    Exit;
  end;

  Result.IsSupported := (Radix >= MIN_RADIX) and (Radix <= MAX_RADIX);
  Result.StripsPrefix := (Radix = HEX_RADIX);
end;

class function TJSNumberParse.ReadIntegerBody(const Unsigned: string; const RadixRule: TRadixRule): TIntegerBody;
begin
  Result.Digits := Unsigned;
  Result.Radix := RadixRule.Radix;

  const HasHexPrefix = RadixRule.StripsPrefix and IsHexPrefix(Unsigned, 1);
  if HasHexPrefix then
  begin
    Result.Digits := Unsigned.Substring(RADIX_PREFIX_LENGTH);
    Result.Radix := HEX_RADIX;
  end;
end;

class function TJSNumberParse.ParseInt(const Text: string; const Radix: Integer): Double;
begin
  const RadixRule = ResolveRadix(Radix);
  if not RadixRule.IsSupported then
    Exit(NaN);

  const Signed = SplitSign(TJSWhiteSpace.TrimStart(Text));
  const Body = ReadIntegerBody(Signed.Unsigned, RadixRule);

  const DigitCount = CountDigitsInRadix(Body.Digits, 1, Body.Radix);
  const HasDigits = (DigitCount > 0);
  if not HasDigits then
    Exit(NaN);

  const Digits = Body.Digits.Substring(0, DigitCount);
  const IsDecimal = (Body.Radix = DEFAULT_RADIX);
  if IsDecimal then
    Result := DecimalToDouble(Digits)
  else
    Result := AccumulateDigits(Digits, Body.Radix);

  if Signed.IsNegative then
    Result := -Result;
end;

class function TJSNumberParse.ParseFloat(const Text: string): Double;
begin
  const Trimmed = TJSWhiteSpace.TrimStart(Text);

  const PrefixLength = DecimalPrefixLength(Trimmed);
  const HasNumber = (PrefixLength > 0);
  if not HasNumber then
    Exit(NaN);

  const Prefix = Trimmed.Substring(0, PrefixLength);
  Result := ConvertSignedLiteral(Prefix);
end;

end.
