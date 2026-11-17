unit JS4D.Tests.BuiltInLocales;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.BuiltInLocales;

type
  [TestFixture]
  TBuiltInLocalesTests = class
  public
    [Test]
    [TestCase('Exact', 'nl-NL,nl-NL')]
    [TestCase('CaseInsensitive', 'DE-de,de-DE')]
    [TestCase('LanguageOnly', 'fr,fr-FR')]
    [TestCase('WithExtension', 'en-GB-u-hc-h12,en-GB')]
    [TestCase('Regional', 'nl-BE,nl-BE')]
    procedure TryFind_WithRequestedTag_ResolvesTheBuiltInLocale(const Requested: string; const Expected: string);

    [Test]
    [TestCase('Unknown', 'xx')]
    [TestCase('UnknownRegion', 'en-AU')]
    [TestCase('Empty', '')]
    procedure TryFind_WithUnsupportedTag_ReturnsFalse(const Requested: string);

    [Test]
    procedure FindDefault_Always_ReturnsAmericanEnglish;

    [Test]
    procedure TryFind_ForBritishEnglish_OverridesOnlyTheDifferingFields;

    [Test]
    procedure TryFind_ForBelgianDutch_SharesTheDutchNamesAndOverridesDatePatterns;

    [Test]
    procedure TryFind_Twice_ReturnsTheSharedDefinition;

    [Test]
    [TestCase('Zero', 'JPY,0')]
    [TestCase('Three', 'BHD,3')]
    [TestCase('Two', 'USD,2')]
    [TestCase('Empty', ',2')]
    [TestCase('CodesJoinedByPipe', 'JPY|KRW,2')]
    procedure CurrencyDigits_ForCode_ReturnsTheMinorUnits(const Currency: string; const Expected: Integer);

    [Test]
    [TestCase('Known', 'en-GB,USD,US$')]
    [TestCase('Unknown', 'en-GB,XYZ,XYZ')]
    [TestCase('Empty', 'en-GB,,')]
    procedure FindCurrencySymbol_ForCode_FallsBackToTheCode(const Tag: string; const Currency: string;
                                                           const Expected: string);

    [Test]
    [TestCase('English', 'en-US,Md,M/d')]
    [TestCase('Dutch', 'nl-NL,Md,d-M')]
    [TestCase('Missing', 'nl-NL,zzzz,')]
    procedure DatePatternMap_ForKey_ReturnsThePattern(const Tag: string; const Key: string; const Expected: string);
  end;

implementation

procedure TBuiltInLocalesTests.TryFind_WithRequestedTag_ResolvesTheBuiltInLocale(const Requested: string;
                                                                                 const Expected: string);
begin
  var Locale: PJSLocaleDefinition;

  Assert.IsTrue(TJSBuiltInLocaleTable.TryFind(Requested, Locale));
  Assert.AreEqual(Expected, Locale.Tag);
end;

procedure TBuiltInLocalesTests.TryFind_WithUnsupportedTag_ReturnsFalse(const Requested: string);
begin
  var Locale: PJSLocaleDefinition;

  Assert.IsFalse(TJSBuiltInLocaleTable.TryFind(Requested, Locale));
end;

procedure TBuiltInLocalesTests.FindDefault_Always_ReturnsAmericanEnglish;
begin
  Assert.AreEqual('en-US', TJSBuiltInLocaleTable.FindDefault.Tag);
end;

procedure TBuiltInLocalesTests.TryFind_ForBritishEnglish_OverridesOnlyTheDifferingFields;
begin
  var American: PJSLocaleDefinition;
  var British: PJSLocaleDefinition;
  TJSBuiltInLocaleTable.TryFind('en-US', American);
  TJSBuiltInLocaleTable.TryFind('en-GB', British);

  Assert.AreEqual(American.MonthsLong[8], British.MonthsLong[8]);
  Assert.AreEqual('Sep', American.MonthsShort[8]);
  Assert.AreEqual('Sept', British.MonthsShort[8]);
  Assert.IsTrue(American.Hour12ByDefault);
  Assert.IsFalse(British.Hour12ByDefault);
  Assert.AreEqual('am', British.AmMarker);
end;

procedure TBuiltInLocalesTests.TryFind_ForBelgianDutch_SharesTheDutchNamesAndOverridesDatePatterns;
begin
  var Netherlands: PJSLocaleDefinition;
  var Belgium: PJSLocaleDefinition;
  TJSBuiltInLocaleTable.TryFind('nl-NL', Netherlands);
  TJSBuiltInLocaleTable.TryFind('nl-BE', Belgium);

  Assert.AreEqual(Netherlands.MonthsLong[2], Belgium.MonthsLong[2]);
  Assert.AreEqual(Netherlands.TimePatterns24, Belgium.TimePatterns24);
  Assert.AreNotEqual(Netherlands.DatePatterns, Belgium.DatePatterns);
end;

procedure TBuiltInLocalesTests.TryFind_Twice_ReturnsTheSharedDefinition;
begin
  var First: PJSLocaleDefinition;
  var Second: PJSLocaleDefinition;
  TJSBuiltInLocaleTable.TryFind('it', First);
  TJSBuiltInLocaleTable.TryFind('it-IT', Second);

  Assert.IsTrue(First = Second);
end;

procedure TBuiltInLocalesTests.CurrencyDigits_ForCode_ReturnsTheMinorUnits(const Currency: string;
                                                                           const Expected: Integer);
begin
  Assert.AreEqual(Expected, TJSBuiltInLocaleTable.CurrencyDigits(Currency));
end;

procedure TBuiltInLocalesTests.FindCurrencySymbol_ForCode_FallsBackToTheCode(const Tag: string;
                                                                             const Currency: string;
                                                                             const Expected: string);
begin
  var Locale: PJSLocaleDefinition;
  TJSBuiltInLocaleTable.TryFind(Tag, Locale);

  Assert.AreEqual(Expected, TJSBuiltInLocaleTable.FindCurrencySymbol(Locale, Currency));
end;

procedure TBuiltInLocalesTests.DatePatternMap_ForKey_ReturnsThePattern(const Tag: string; const Key: string;
                                                                       const Expected: string);
begin
  var Locale: PJSLocaleDefinition;
  TJSBuiltInLocaleTable.TryFind(Tag, Locale);

  var Pattern: string;
  const IsFound = Locale.DatePatternMap.TryGetValue(Key, Pattern);

  Assert.AreEqual(not Expected.IsEmpty, IsFound);
  if IsFound then
    Assert.AreEqual(Expected, Pattern);
end;

end.
