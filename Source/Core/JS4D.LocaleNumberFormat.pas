unit JS4D.LocaleNumberFormat;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.BuiltInLocales;

type
  TJSNumberStyle = (Decimal, Percent, Currency);
  TJSCurrencyDisplay = (Symbol, Code);

  TJSNumberFormatOptions = record
    Style: TJSNumberStyle;
    Currency: string;
    CurrencyDisplay: TJSCurrencyDisplay;
    MinimumIntegerDigits: Integer;
    MinimumFractionDigits: Integer;
    MaximumFractionDigits: Integer;
    UseGrouping: Boolean;
  end;

  TJSFractionDigitRange = record
    Minimum: Integer;
    Maximum: Integer;
  end;

  TJSLocaleNumberFormatter = class
  private
    const
      NOT_A_NUMBER_TEXT = 'NaN';
      INFINITY_TEXT = #$221E;
      PERCENT_SIGN = '%';
      PERCENT_POINT_SHIFT = 2;
      GROUP_SIZE = 3;
      NO_BREAK_SPACE = #$00A0;
      DEFAULT_MAXIMUM_DECIMAL_DIGITS = 3;
      DEFAULT_CURRENCY_DIGITS = 2;
      THREE_CURRENCY_DIGITS = 3;
      CURRENCY_BOUNDARY = '|';
      ZERO_DIGIT_CURRENCIES = '|JPY|KRW|VND|CLP|ISK|UGX|XAF|XOF|XPF|PYG|RWF|';
      THREE_DIGIT_CURRENCIES = '|BHD|KWD|OMR|JOD|TND|IQD|LYD|';
      UNSUPPORTED_STYLE = 'Unsupported number style: %d';

    class function CurrencyDigits(const Currency: string): Integer; static;
    class function GroupedText(const Digits: string; const Locale: TJSLocaleDefinition): string; static;
    class function PaddedIntegerText(const Digits: string; const MinimumLength: Integer): string; static;
    class function PaddedFractionText(const Digits: string; const MinimumLength: Integer): string; static;
    class function MagnitudeText(const Magnitude: Double; const Locale: TJSLocaleDefinition;
                                 const Options: TJSNumberFormatOptions): string; static;
    class function CurrencyText(const Magnitude: string; const SignText: string; const Locale: TJSLocaleDefinition;
                                const Options: TJSNumberFormatOptions): string; static;
    class function IsNegative(const Value: Double): Boolean; static;
  public
    class function DefaultFractionDigits(const Style: TJSNumberStyle; const Currency: string): TJSFractionDigitRange; static;
    class function FormatNumber(const Value: Double; const Locale: TJSLocaleDefinition;
                                const Options: TJSNumberFormatOptions): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  System.StrUtils,
  JS4D.NumberFormat;

class function TJSLocaleNumberFormatter.CurrencyDigits(const Currency: string): Integer;
begin
  const Marker = CURRENCY_BOUNDARY + Currency + CURRENCY_BOUNDARY;

  const HasNoMinorUnits = ZERO_DIGIT_CURRENCIES.Contains(Marker);
  if HasNoMinorUnits then
    Exit(0);

  const HasThreeMinorUnits = THREE_DIGIT_CURRENCIES.Contains(Marker);
  if HasThreeMinorUnits then
    Exit(THREE_CURRENCY_DIGITS);

  Result := DEFAULT_CURRENCY_DIGITS;
end;

class function TJSLocaleNumberFormatter.DefaultFractionDigits(const Style: TJSNumberStyle;
                                                             const Currency: string): TJSFractionDigitRange;
begin
  case Style of
    TJSNumberStyle.Decimal:
    begin
      Result.Minimum := 0;
      Result.Maximum := DEFAULT_MAXIMUM_DECIMAL_DIGITS;
    end;
    TJSNumberStyle.Percent:
    begin
      Result.Minimum := 0;
      Result.Maximum := 0;
    end;
    TJSNumberStyle.Currency:
    begin
      Result.Minimum := CurrencyDigits(Currency);
      Result.Maximum := Result.Minimum;
    end;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleNumberFormatter.IsNegative(const Value: Double): Boolean;
begin
  Result := Value.Sign;
end;

class function TJSLocaleNumberFormatter.GroupedText(const Digits: string; const Locale: TJSLocaleDefinition): string;
begin
  const FirstGroupedLength = GROUP_SIZE + Locale.MinimumGroupingDigits;
  const IsGroupable = (Length(Digits) >= FirstGroupedLength);
  if not IsGroupable then
    Exit(Digits);

  Result := '';
  var Position := Length(Digits);
  while Position > GROUP_SIZE do
  begin
    const Group = Copy(Digits, Position - GROUP_SIZE + 1, GROUP_SIZE);

    Result := Locale.GroupSeparator + Group + Result;
    Dec(Position, GROUP_SIZE);
  end;

  Result := Copy(Digits, 1, Position) + Result;
end;

class function TJSLocaleNumberFormatter.PaddedIntegerText(const Digits: string; const MinimumLength: Integer): string;
begin
  const MissingZeros = MinimumLength - Length(Digits);

  Result := StringOfChar('0', MissingZeros) + Digits;
end;

class function TJSLocaleNumberFormatter.PaddedFractionText(const Digits: string; const MinimumLength: Integer): string;
begin
  const MissingZeros = MinimumLength - Length(Digits);

  Result := Digits + StringOfChar('0', MissingZeros);
end;

class function TJSLocaleNumberFormatter.MagnitudeText(const Magnitude: Double; const Locale: TJSLocaleDefinition;
                                                      const Options: TJSNumberFormatOptions): string;
begin
  if IsNaN(Magnitude) then
    Exit(NOT_A_NUMBER_TEXT);

  if IsInfinite(Magnitude) then
    Exit(INFINITY_TEXT);

  const IsPercent = (Options.Style = TJSNumberStyle.Percent);
  const PointShift = IfThen(IsPercent, PERCENT_POINT_SHIFT, 0);
  const Rounded = TJSNumberFormat.ToRoundedDecimal(Magnitude, Options.MaximumFractionDigits, PointShift);

  const IntegerText = PaddedIntegerText(Rounded.IntegerDigits, Options.MinimumIntegerDigits);
  const FractionText = PaddedFractionText(Rounded.FractionDigits, Options.MinimumFractionDigits);

  Result := IntegerText;
  if Options.UseGrouping then
    Result := GroupedText(IntegerText, Locale);

  const HasFraction = (Length(FractionText) > 0);
  if HasFraction then
    Result := Result + Locale.DecimalSeparator + FractionText;
end;

class function TJSLocaleNumberFormatter.CurrencyText(const Magnitude: string; const SignText: string;
                                                     const Locale: TJSLocaleDefinition;
                                                     const Options: TJSNumberFormatOptions): string;
begin
  var DisplayedCurrency := Options.Currency;
  const ShowsSymbol = (Options.CurrencyDisplay = TJSCurrencyDisplay.Symbol);
  if ShowsSymbol then
    DisplayedCurrency := TJSBuiltInLocaleTable.FindCurrencySymbol(Locale, Options.Currency);

  case Locale.CurrencyLayout of
    TJSCurrencyLayout.SymbolBeforeNumber:
    begin
      const LastCharacter = DisplayedCurrency.Chars[Length(DisplayedCurrency) - 1];
      const Gap = IfThen(LastCharacter.IsLetter, NO_BREAK_SPACE, '');

      Result := SignText + DisplayedCurrency + Gap + Magnitude;
    end;
    TJSCurrencyLayout.SymbolBeforeNumberWithSpace : Result := DisplayedCurrency + NO_BREAK_SPACE + SignText + Magnitude;
    TJSCurrencyLayout.SymbolAfterNumberWithSpace  : Result := SignText + Magnitude + NO_BREAK_SPACE + DisplayedCurrency;
  else
    raise ENotSupportedException.CreateFmt('Unsupported currency layout: %d', [Ord(Locale.CurrencyLayout)]);
  end;
end;

class function TJSLocaleNumberFormatter.FormatNumber(const Value: Double; const Locale: TJSLocaleDefinition;
                                                     const Options: TJSNumberFormatOptions): string;
begin
  const IsNegativeNumber = IsNegative(Value) and (not IsNaN(Value));
  const SignText = IfThen(IsNegativeNumber, Locale.MinusSign, '');
  const AbsoluteValue = Abs(Value);
  const Magnitude = MagnitudeText(AbsoluteValue, Locale, Options);

  case Options.Style of
    TJSNumberStyle.Decimal  : Result := SignText + Magnitude;
    TJSNumberStyle.Percent  : Result := SignText + Magnitude + Locale.PercentGap + PERCENT_SIGN;
    TJSNumberStyle.Currency : Result := CurrencyText(Magnitude, SignText, Locale, Options);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_STYLE, [Ord(Options.Style)]);
  end;
end;

end.
