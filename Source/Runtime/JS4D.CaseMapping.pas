unit JS4D.CaseMapping;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.CaseMappingData;

type
  TJSCaseMapping = class
  private
    type
      TCodePointMapper = reference to function(const Text: string; const Index, Code: Integer): string;
      TItemComparer<T> = reference to function(const Item: T): Integer;

    const
      ASCII_LIMIT = 128;
      LOWER_DOTTED_I_FORMAT = 'i%s';
      LATIN_CAPITAL_I_WITH_DOT_ABOVE = $0130;
      COMBINING_DOT_ABOVE = $0307;
      GREEK_CAPITAL_SIGMA = $03A3;
      GREEK_SMALL_SIGMA = $03C3;
      GREEK_SMALL_FINAL_SIGMA = $03C2;
      CASE_IGNORABLE_PUNCTUATION: array[0..16] of Integer =
        ($0027, $002E, $003A, $00B7, $0387, $055F, $05F4, $2018, $2019,
         $2024, $2027, $FE13, $FE52, $FE55, $FF07, $FF0E, $FF1A);

    class function IsAscii(const Text: string): Boolean; static;
    class function IsCased(const Code: Integer): Boolean; static;
    class function IsCaseIgnorable(const Code: Integer): Boolean; static;
    class function SimpleMapping(const Ranges: array of TJSCaseRange; const Code: Integer): Integer; static;
    class function FindSpecialUpper(const Code: Integer; out Text: string): Boolean; static;
    class function IsFinalSigma(const Text: string; const SigmaIndex: Integer): Boolean; static;
    class function CasedPrecedes(const Text: string; const SigmaIndex: Integer): Boolean; static;
    class function CasedFollows(const Text: string; const AfterSigmaIndex: Integer): Boolean; static;
    class function LowerCodePoint(const Text: string; const Index, Code: Integer): string; static;
    class function UpperCodePoint(const Code: Integer): string; static;
    class function MapText(const Text: string; const Mapper: TCodePointMapper): string; static;
    class function BinarySearch<T>(const Items: array of T; const Compare: TItemComparer<T>): Integer; static;
    class function CodePointToString(const Code: Integer): string; static;

  public
    class function ToUpper(const Text: string): string; static;
    class function ToLower(const Text: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character,
  System.Math,
  JS4D.Utf16;

class function TJSCaseMapping.IsAscii(const Text: string): Boolean;
begin
  Result := True;
  for var Letter in Text do
  begin
    const IsOutsideAscii = (Ord(Letter) >= ASCII_LIMIT);
    if IsOutsideAscii then
      Exit(False);
  end;
end;

class function TJSCaseMapping.CodePointToString(const Code: Integer): string;
begin
  const IsLoneSurrogate = ((Code >= HIGH_SURROGATE_FIRST) and (Code <= LOW_SURROGATE_LAST));
  if IsLoneSurrogate then
  begin
    Result := Char(Code);
    Exit;
  end;

  Result := Char.ConvertFromUtf32(Code);
end;

class function TJSCaseMapping.IsCased(const Code: Integer): Boolean;
begin
  const Category = Char.GetUnicodeCategory(UCS4Char(Code));
  Result := (Category in [TUnicodeCategory.ucUppercaseLetter,
                          TUnicodeCategory.ucLowercaseLetter,
                          TUnicodeCategory.ucTitlecaseLetter]);
end;

class function TJSCaseMapping.IsCaseIgnorable(const Code: Integer): Boolean;
begin
  for var Punctuation in CASE_IGNORABLE_PUNCTUATION do
  begin
    const IsPunctuation = (Code = Punctuation);
    if IsPunctuation then
      Exit(True);
  end;

  const Category = Char.GetUnicodeCategory(UCS4Char(Code));
  Result := (Category in [TUnicodeCategory.ucNonSpacingMark,
                          TUnicodeCategory.ucEnclosingMark,
                          TUnicodeCategory.ucFormat,
                          TUnicodeCategory.ucModifierLetter,
                          TUnicodeCategory.ucModifierSymbol]);
end;

class function TJSCaseMapping.BinarySearch<T>(const Items: array of T; const Compare: TItemComparer<T>): Integer;
begin
  var LowIndex := 0;
  var HighIndex := High(Items);
  while LowIndex <= HighIndex do
  begin
    const Middle = (LowIndex + HighIndex) div 2;
    const Order = Compare(Items[Middle]);

    const IsFound = (Order = 0);
    if IsFound then
      Exit(Middle);

    const IsBeforeProbe = (Order < 0);
    if IsBeforeProbe then
      HighIndex := Middle - 1
    else
      LowIndex := Middle + 1;
  end;

  Result := -1;
end;

class function TJSCaseMapping.SimpleMapping(const Ranges: array of TJSCaseRange; const Code: Integer): Integer;
begin
  const RangeIndex = BinarySearch<TJSCaseRange>(Ranges,
    function(const Range: TJSCaseRange): Integer
    begin
      const IsBelow = (Code < Range.First);
      const IsAbove = (Code > Range.Last);

      Result := 0;
      if IsBelow then
        Result := -1
      else if IsAbove then
        Result := 1;
    end);

  Result := Code;

  const IsInRange = (RangeIndex >= 0);
  if not IsInRange then
    Exit;

  const Range = Ranges[RangeIndex];
  const IsMapped = (((Code - Range.First) mod Range.Stride) = 0);
  if IsMapped then
    Result := Code + Range.Delta;
end;

class function TJSCaseMapping.FindSpecialUpper(const Code: Integer; out Text: string): Boolean;
begin
  const SpecialIndex = BinarySearch<TJSSpecialUpper>(SPECIAL_UPPER_MAPPINGS,
    function(const Special: TJSSpecialUpper): Integer
    begin
      Result := Sign(Code - Special.Code);
    end);

  Result := (SpecialIndex >= 0);
  if Result then
    Text := SPECIAL_UPPER_MAPPINGS[SpecialIndex].Text;
end;

class function TJSCaseMapping.CasedPrecedes(const Text: string; const SigmaIndex: Integer): Boolean;
begin
  var Index := SigmaIndex - 1;
  while Index >= 1 do
  begin
    var Width: Integer;
    const Code = TJSUtf16.CodePointBefore(Text, Index, Width);
    if not IsCaseIgnorable(Code) then
    begin
      Result := IsCased(Code);
      Exit;
    end;

    Dec(Index, Width);
  end;
  Result := False;
end;

class function TJSCaseMapping.CasedFollows(const Text: string; const AfterSigmaIndex: Integer): Boolean;
begin
  var Index := AfterSigmaIndex;
  while Index <= Length(Text) do
  begin
    var Width: Integer;
    const Code = TJSUtf16.CodePointAt(Text, Index, Width);
    if not IsCaseIgnorable(Code) then
    begin
      Result := IsCased(Code);
      Exit;
    end;

    Inc(Index, Width);
  end;
  Result := False;
end;

class function TJSCaseMapping.IsFinalSigma(const Text: string; const SigmaIndex: Integer): Boolean;
begin
  const FollowedByCased = CasedFollows(Text, SigmaIndex + 1);
  const PrecededByCased = CasedPrecedes(Text, SigmaIndex);

  Result := (PrecededByCased and (not FollowedByCased));
end;

class function TJSCaseMapping.LowerCodePoint(const Text: string; const Index, Code: Integer): string;
begin
  const IsDottedCapitalI = (Code = LATIN_CAPITAL_I_WITH_DOT_ABOVE);
  if IsDottedCapitalI then
  begin
    const DotAbove = CodePointToString(COMBINING_DOT_ABOVE);
    Result := Format(LOWER_DOTTED_I_FORMAT, [DotAbove]);
    Exit;
  end;

  const IsCapitalSigma = (Code = GREEK_CAPITAL_SIGMA);
  if IsCapitalSigma then
  begin
    const IsFinal = IsFinalSigma(Text, Index);
    if IsFinal then
    begin
      Result := CodePointToString(GREEK_SMALL_FINAL_SIGMA);
      Exit;
    end;

    Result := CodePointToString(GREEK_SMALL_SIGMA);
    Exit;
  end;

  const LowerCode = SimpleMapping(SIMPLE_LOWER_RANGES, Code);
  Result := CodePointToString(LowerCode);
end;

class function TJSCaseMapping.UpperCodePoint(const Code: Integer): string;
begin
  if FindSpecialUpper(Code, Result) then
    Exit;

  const UpperCode = SimpleMapping(SIMPLE_UPPER_RANGES, Code);
  Result := CodePointToString(UpperCode);
end;

class function TJSCaseMapping.MapText(const Text: string; const Mapper: TCodePointMapper): string;
begin
  const Builder = TStringBuilder.Create(Length(Text));
  try
    var Index := 1;
    while Index <= Length(Text) do
    begin
      var Width: Integer;
      const Code = TJSUtf16.CodePointAt(Text, Index, Width);

      Builder.Append(Mapper(Text, Index, Code));
      Inc(Index, Width);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSCaseMapping.ToUpper(const Text: string): string;
begin
  if IsAscii(Text) then
  begin
    Result := UpperCase(Text);
    Exit;
  end;

  Result := MapText(Text,
    function(const Source: string; const Index, Code: Integer): string
    begin
      Result := UpperCodePoint(Code);
    end);
end;

class function TJSCaseMapping.ToLower(const Text: string): string;
begin
  if IsAscii(Text) then
  begin
    Result := LowerCase(Text);
    Exit;
  end;

  Result := MapText(Text,
    function(const Source: string; const Index, Code: Integer): string
    begin
      Result := LowerCodePoint(Source, Index, Code);
    end);
end;

end.

