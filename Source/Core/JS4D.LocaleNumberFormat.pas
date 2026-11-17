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
      INFINITY_SYMBOL = #$221E;
      PERCENT_SIGN = '%';
      PERCENT_POINT_SHIFT = 2;
      GROUP_SIZE = 3;
      NO_BREAK_SPACE = #$00A0;
      DEFAULT_MAXIMUM_DECIMAL_DIGITS = 3;
      UNSUPPORTED_STYLE = 'Unsupported number style: %d';
      UNSUPPORTED_CURRENCY_LAYOUT = 'Unsupported currency layout: %d';

    class function GroupedText(const Digits: string; const Locale: PJSLocaleDefinition): string; static;
    class function MagnitudeText(const Magnitude: Double; const Locale: PJSLocaleDefinition;
                                 const Options: TJSNumberFormatOptions): string; static;
    class function DisplayedCurrency(const Locale: PJSLocaleDefinition;
                                     const Options: TJSNumberFormatOptions): string; static;
    class function CurrencyText(const Magnitude: string; const SignText: string; const Locale: PJSLocaleDefinition;
                                const Options: TJSNumberFormatOptions): string; static;
  public
    class function DefaultFractionDigits(const Style: TJSNumberStyle; const Currency: string): TJSFractionDigitRange; static;
    class function FormatNumber(const Value: Double; const Locale: PJSLocaleDefinition;
                                const Options: TJSNumberFormatOptions): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Character,
  System.StrUtils,
  JS4D.NumberFormat,
  JS4D.NumberText;

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
      Result.Minimum := TJSBuiltInLocaleTable.CurrencyDigits(Currency);
      Result.Maximum := Result.Minimum;
    end;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_STYLE, [Ord(Style)]);
  end;
end;

class function TJSLocaleNumberFormatter.GroupedText(const Digits: string; const Locale: PJSLocaleDefinition): string;
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

class function TJSLocaleNumberFormatter.MagnitudeText(const Magnitude: Double; const Locale: PJSLocaleDefinition;
                                                      const Options: TJSNumberFormatOptions): string;
begin
  if IsNaN(Magnitude) then
    Exit(NAN_TEXT);

  if IsInfinite(Magnitude) then
    Exit(INFINITY_SYMBOL);

  const IsPercent = (Options.Style = TJSNumberStyle.Percent);
  const PointShift = IfThen(IsPercent, PERCENT_POINT_SHIFT, 0);
  const Rounded = TJSNumberFormat.ToRoundedDecimal(Magnitude, Options.MaximumFractionDigits, PointShift);

  const IntegerText = TJSNumberText.PadLeft(Rounded.IntegerDigits, Options.MinimumIntegerDigits);
  const FractionText = TJSNumberText.PadRight(Rounded.FractionDigits, Options.MinimumFractionDigits);

  if Options.UseGrouping then
    Result := GroupedText(IntegerText, Locale)
  else
    Result := IntegerText;

  const HasFraction = (Length(FractionText) > 0);
  if HasFraction then
    Result := Result + Locale.DecimalSeparator + FractionText;
end;

class function TJSLocaleNumberFormatter.DisplayedCurrency(const Locale: PJSLocaleDefinition;
                                                          const Options: TJSNumberFormatOptions): string;
begin
  const ShowsSymbol = (Options.CurrencyDisplay = TJSCurrencyDisplay.Symbol);
  if ShowsSymbol then
    Result := TJSBuiltInLocaleTable.FindCurrencySymbol(Locale, Options.Currency)
  else
    Result := Options.Currency;
end;

class function TJSLocaleNumberFormatter.CurrencyText(const Magnitude: string; const SignText: string;
                                                     const Locale: PJSLocaleDefinition;
                                                     const Options: TJSNumberFormatOptions): string;
begin
  const Currency = DisplayedCurrency(Locale, Options);

  case Locale.CurrencyLayout of
    TJSCurrencyLayout.SymbolBeforeNumber:
    begin
      const IsEmptyCurrency = Currency.IsEmpty;
      const EndsWithLetter = (not IsEmptyCurrency) and Currency.Chars[Length(Currency) - 1].IsLetter;
      const Gap = IfThen(EndsWithLetter, NO_BREAK_SPACE, '');

      Result := SignText + Currency + Gap + Magnitude;
    end;
    TJSCurrencyLayout.SymbolBeforeNumberWithSpace : Result := Currency + NO_BREAK_SPACE + SignText + Magnitude;
    TJSCurrencyLayout.SymbolAfterNumberWithSpace  : Result := SignText + Magnitude + NO_BREAK_SPACE + Currency;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_CURRENCY_LAYOUT, [Ord(Locale.CurrencyLayout)]);
  end;
end;

class function TJSLocaleNumberFormatter.FormatNumber(const Value: Double; const Locale: PJSLocaleDefinition;
                                                     const Options: TJSNumberFormatOptions): string;
begin
  const HasNegativeSign = Value.Sign;
  const IsNotANumber = IsNaN(Value);
  const IsNegativeNumber = HasNegativeSign and (not IsNotANumber);
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
