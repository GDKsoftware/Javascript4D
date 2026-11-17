unit JS4D.Tests.LocaleFormatting;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TLocaleFormattingTests = class(TJSEngineTestCase)
  private
    function EvaluateEscaped(const Script: string): string;

  public
    [Test]
    [TestCase('Plain en-US', '(1234567.891).toLocaleString("en-US")|1,234,567.891', '|')]
    [TestCase('Small en-US', '(1234).toLocaleString("en-US")|1,234', '|')]
    [TestCase('Five en-US', '(12345).toLocaleString("en-US")|12,345', '|')]
    [TestCase('Negative en-US', '(-1234.5).toLocaleString("en-US")|-1,234.5', '|')]
    [TestCase('Fraction en-US', '(8864.43).toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8,864.43', '|')]
    [TestCase('Percent en-US', '(0.256).toLocaleString("en-US", {style: "percent"})|26%', '|')]
    [TestCase('PercentFraction en-US', '(0.12345).toLocaleString("en-US", {style: "percent", minimumFractionDigits: 1})|12.3%', '|')]
    [TestCase('CurrencyEUR en-US', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "EUR"})|\u20ac1,234.50', '|')]
    [TestCase('CurrencyUSD en-US', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "USD"})|$1,234.50', '|')]
    [TestCase('CurrencyGBP en-US', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "GBP"})|\u00a31,234.50', '|')]
    [TestCase('CurrencyJPY en-US', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "JPY"})|\u00a51,235', '|')]
    [TestCase('CurrencyCHF en-US', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "CHF"})|CHF\u00a01,234.50', '|')]
    [TestCase('CurrencyCode en-US',
      '(1234.5).toLocaleString("en-US", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|EUR\u00a01,234.50', '|')]
    [TestCase('CurrencyNegative en-US', '(-1234.5).toLocaleString("en-US", {style: "currency", currency: "EUR"})|-\u20ac1,234.50', '|')]
    [TestCase('MinInteger en-US', '(7).toLocaleString("en-US", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping en-US', '(1234567.5).toLocaleString("en-US", {useGrouping: false})|1234567.5', '|')]
    [TestCase('Plain en-GB', '(1234567.891).toLocaleString("en-GB")|1,234,567.891', '|')]
    [TestCase('Small en-GB', '(1234).toLocaleString("en-GB")|1,234', '|')]
    [TestCase('Five en-GB', '(12345).toLocaleString("en-GB")|12,345', '|')]
    [TestCase('Negative en-GB', '(-1234.5).toLocaleString("en-GB")|-1,234.5', '|')]
    [TestCase('Fraction en-GB', '(8864.43).toLocaleString("en-GB", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8,864.43', '|')]
    [TestCase('Percent en-GB', '(0.256).toLocaleString("en-GB", {style: "percent"})|26%', '|')]
    [TestCase('PercentFraction en-GB', '(0.12345).toLocaleString("en-GB", {style: "percent", minimumFractionDigits: 1})|12.3%', '|')]
    [TestCase('CurrencyEUR en-GB', '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "EUR"})|\u20ac1,234.50', '|')]
    [TestCase('CurrencyUSD en-GB', '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "USD"})|US$1,234.50', '|')]
    [TestCase('CurrencyGBP en-GB', '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "GBP"})|\u00a31,234.50', '|')]
    [TestCase('CurrencyJPY en-GB', '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "JPY"})|JP\u00a51,235', '|')]
    [TestCase('CurrencyCHF en-GB', '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "CHF"})|CHF\u00a01,234.50', '|')]
    [TestCase('CurrencyCode en-GB',
      '(1234.5).toLocaleString("en-GB", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|EUR\u00a01,234.50', '|')]
    [TestCase('CurrencyNegative en-GB', '(-1234.5).toLocaleString("en-GB", {style: "currency", currency: "EUR"})|-\u20ac1,234.50', '|')]
    [TestCase('MinInteger en-GB', '(7).toLocaleString("en-GB", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping en-GB', '(1234567.5).toLocaleString("en-GB", {useGrouping: false})|1234567.5', '|')]
    [TestCase('Plain nl-NL', '(1234567.891).toLocaleString("nl-NL")|1.234.567,891', '|')]
    [TestCase('Small nl-NL', '(1234).toLocaleString("nl-NL")|1.234', '|')]
    [TestCase('Five nl-NL', '(12345).toLocaleString("nl-NL")|12.345', '|')]
    [TestCase('Negative nl-NL', '(-1234.5).toLocaleString("nl-NL")|-1.234,5', '|')]
    [TestCase('Fraction nl-NL', '(8864.43).toLocaleString("nl-NL", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8.864,43', '|')]
    [TestCase('Percent nl-NL', '(0.256).toLocaleString("nl-NL", {style: "percent"})|26%', '|')]
    [TestCase('PercentFraction nl-NL', '(0.12345).toLocaleString("nl-NL", {style: "percent", minimumFractionDigits: 1})|12,3%', '|')]
    [TestCase('CurrencyEUR nl-NL', '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "EUR"})|\u20ac\u00a01.234,50', '|')]
    [TestCase('CurrencyUSD nl-NL', '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "USD"})|US$\u00a01.234,50', '|')]
    [TestCase('CurrencyGBP nl-NL', '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "GBP"})|\u00a3\u00a01.234,50', '|')]
    [TestCase('CurrencyJPY nl-NL', '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "JPY"})|JP\u00a5\u00a01.235', '|')]
    [TestCase('CurrencyCHF nl-NL', '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "CHF"})|CHF\u00a01.234,50', '|')]
    [TestCase('CurrencyCode nl-NL',
      '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|EUR\u00a01.234,50', '|')]
    [TestCase('CurrencyNegative nl-NL', '(-1234.5).toLocaleString("nl-NL", {style: "currency", currency: "EUR"})|\u20ac\u00a0-1.234,50', '|')]
    [TestCase('MinInteger nl-NL', '(7).toLocaleString("nl-NL", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping nl-NL', '(1234567.5).toLocaleString("nl-NL", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Plain nl-BE', '(1234567.891).toLocaleString("nl-BE")|1.234.567,891', '|')]
    [TestCase('Small nl-BE', '(1234).toLocaleString("nl-BE")|1.234', '|')]
    [TestCase('Five nl-BE', '(12345).toLocaleString("nl-BE")|12.345', '|')]
    [TestCase('Negative nl-BE', '(-1234.5).toLocaleString("nl-BE")|-1.234,5', '|')]
    [TestCase('Fraction nl-BE', '(8864.43).toLocaleString("nl-BE", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8.864,43', '|')]
    [TestCase('Percent nl-BE', '(0.256).toLocaleString("nl-BE", {style: "percent"})|26%', '|')]
    [TestCase('PercentFraction nl-BE', '(0.12345).toLocaleString("nl-BE", {style: "percent", minimumFractionDigits: 1})|12,3%', '|')]
    [TestCase('CurrencyEUR nl-BE', '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "EUR"})|\u20ac\u00a01.234,50', '|')]
    [TestCase('CurrencyUSD nl-BE', '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "USD"})|US$\u00a01.234,50', '|')]
    [TestCase('CurrencyGBP nl-BE', '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "GBP"})|\u00a3\u00a01.234,50', '|')]
    [TestCase('CurrencyJPY nl-BE', '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "JPY"})|JP\u00a5\u00a01.235', '|')]
    [TestCase('CurrencyCHF nl-BE', '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "CHF"})|CHF\u00a01.234,50', '|')]
    [TestCase('CurrencyCode nl-BE',
      '(1234.5).toLocaleString("nl-BE", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|EUR\u00a01.234,50', '|')]
    [TestCase('CurrencyNegative nl-BE', '(-1234.5).toLocaleString("nl-BE", {style: "currency", currency: "EUR"})|\u20ac\u00a0-1.234,50', '|')]
    [TestCase('MinInteger nl-BE', '(7).toLocaleString("nl-BE", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping nl-BE', '(1234567.5).toLocaleString("nl-BE", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Plain de-DE', '(1234567.891).toLocaleString("de-DE")|1.234.567,891', '|')]
    [TestCase('Small de-DE', '(1234).toLocaleString("de-DE")|1.234', '|')]
    [TestCase('Five de-DE', '(12345).toLocaleString("de-DE")|12.345', '|')]
    [TestCase('Negative de-DE', '(-1234.5).toLocaleString("de-DE")|-1.234,5', '|')]
    [TestCase('Fraction de-DE', '(8864.43).toLocaleString("de-DE", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8.864,43', '|')]
    [TestCase('Percent de-DE', '(0.256).toLocaleString("de-DE", {style: "percent"})|26\u00a0%', '|')]
    [TestCase('PercentFraction de-DE', '(0.12345).toLocaleString("de-DE", {style: "percent", minimumFractionDigits: 1})|12,3\u00a0%', '|')]
    [TestCase('CurrencyEUR de-DE', '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "EUR"})|1.234,50\u00a0\u20ac', '|')]
    [TestCase('CurrencyUSD de-DE', '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "USD"})|1.234,50\u00a0$', '|')]
    [TestCase('CurrencyGBP de-DE', '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "GBP"})|1.234,50\u00a0\u00a3', '|')]
    [TestCase('CurrencyJPY de-DE', '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "JPY"})|1.235\u00a0\u00a5', '|')]
    [TestCase('CurrencyCHF de-DE', '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "CHF"})|1.234,50\u00a0CHF', '|')]
    [TestCase('CurrencyCode de-DE',
      '(1234.5).toLocaleString("de-DE", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|1.234,50\u00a0EUR', '|')]
    [TestCase('CurrencyNegative de-DE', '(-1234.5).toLocaleString("de-DE", {style: "currency", currency: "EUR"})|-1.234,50\u00a0\u20ac', '|')]
    [TestCase('MinInteger de-DE', '(7).toLocaleString("de-DE", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping de-DE', '(1234567.5).toLocaleString("de-DE", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Plain fr-FR', '(1234567.891).toLocaleString("fr-FR")|1\u202f234\u202f567,891', '|')]
    [TestCase('Small fr-FR', '(1234).toLocaleString("fr-FR")|1\u202f234', '|')]
    [TestCase('Five fr-FR', '(12345).toLocaleString("fr-FR")|12\u202f345', '|')]
    [TestCase('Negative fr-FR', '(-1234.5).toLocaleString("fr-FR")|-1\u202f234,5', '|')]
    [TestCase('Fraction fr-FR', '(8864.43).toLocaleString("fr-FR", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8\u202f864,43', '|')]
    [TestCase('Percent fr-FR', '(0.256).toLocaleString("fr-FR", {style: "percent"})|26\u00a0%', '|')]
    [TestCase('PercentFraction fr-FR', '(0.12345).toLocaleString("fr-FR", {style: "percent", minimumFractionDigits: 1})|12,3\u00a0%', '|')]
    [TestCase('CurrencyEUR fr-FR', '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "EUR"})|1\u202f234,50\u00a0\u20ac', '|')]
    [TestCase('CurrencyUSD fr-FR', '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "USD"})|1\u202f234,50\u00a0$US', '|')]
    [TestCase('CurrencyGBP fr-FR', '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "GBP"})|1\u202f234,50\u00a0\u00a3GB', '|')]
    [TestCase('CurrencyJPY fr-FR', '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "JPY"})|1\u202f235\u00a0JPY', '|')]
    [TestCase('CurrencyCHF fr-FR', '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "CHF"})|1\u202f234,50\u00a0CHF', '|')]
    [TestCase('CurrencyCode fr-FR',
      '(1234.5).toLocaleString("fr-FR", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|1\u202f234,50\u00a0EUR', '|')]
    [TestCase('CurrencyNegative fr-FR', '(-1234.5).toLocaleString("fr-FR", {style: "currency", currency: "EUR"})|-1\u202f234,50\u00a0\u20ac', '|')]
    [TestCase('MinInteger fr-FR', '(7).toLocaleString("fr-FR", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping fr-FR', '(1234567.5).toLocaleString("fr-FR", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Plain es-ES', '(1234567.891).toLocaleString("es-ES")|1.234.567,891', '|')]
    [TestCase('Small es-ES', '(1234).toLocaleString("es-ES")|1234', '|')]
    [TestCase('Five es-ES', '(12345).toLocaleString("es-ES")|12.345', '|')]
    [TestCase('Negative es-ES', '(-1234.5).toLocaleString("es-ES")|-1234,5', '|')]
    [TestCase('Fraction es-ES', '(8864.43).toLocaleString("es-ES", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8864,43', '|')]
    [TestCase('Percent es-ES', '(0.256).toLocaleString("es-ES", {style: "percent"})|26\u00a0%', '|')]
    [TestCase('PercentFraction es-ES', '(0.12345).toLocaleString("es-ES", {style: "percent", minimumFractionDigits: 1})|12,3\u00a0%', '|')]
    [TestCase('CurrencyEUR es-ES', '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "EUR"})|1234,50\u00a0\u20ac', '|')]
    [TestCase('CurrencyUSD es-ES', '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "USD"})|1234,50\u00a0US$', '|')]
    [TestCase('CurrencyGBP es-ES', '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "GBP"})|1234,50\u00a0GBP', '|')]
    [TestCase('CurrencyJPY es-ES', '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "JPY"})|1235\u00a0JPY', '|')]
    [TestCase('CurrencyCHF es-ES', '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "CHF"})|1234,50\u00a0CHF', '|')]
    [TestCase('CurrencyCode es-ES',
      '(1234.5).toLocaleString("es-ES", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|1234,50\u00a0EUR', '|')]
    [TestCase('CurrencyNegative es-ES', '(-1234.5).toLocaleString("es-ES", {style: "currency", currency: "EUR"})|-1234,50\u00a0\u20ac', '|')]
    [TestCase('MinInteger es-ES', '(7).toLocaleString("es-ES", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping es-ES', '(1234567.5).toLocaleString("es-ES", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Plain it-IT', '(1234567.891).toLocaleString("it-IT")|1.234.567,891', '|')]
    [TestCase('Small it-IT', '(1234).toLocaleString("it-IT")|1234', '|')]
    [TestCase('Five it-IT', '(12345).toLocaleString("it-IT")|12.345', '|')]
    [TestCase('Negative it-IT', '(-1234.5).toLocaleString("it-IT")|-1234,5', '|')]
    [TestCase('Fraction it-IT', '(8864.43).toLocaleString("it-IT", {minimumFractionDigits: 2, maximumFractionDigits: 2})|8864,43', '|')]
    [TestCase('Percent it-IT', '(0.256).toLocaleString("it-IT", {style: "percent"})|26%', '|')]
    [TestCase('PercentFraction it-IT', '(0.12345).toLocaleString("it-IT", {style: "percent", minimumFractionDigits: 1})|12,3%', '|')]
    [TestCase('CurrencyEUR it-IT', '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "EUR"})|1234,50\u00a0\u20ac', '|')]
    [TestCase('CurrencyUSD it-IT', '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "USD"})|1234,50\u00a0USD', '|')]
    [TestCase('CurrencyGBP it-IT', '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "GBP"})|1234,50\u00a0\u00a3', '|')]
    [TestCase('CurrencyJPY it-IT', '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "JPY"})|1235\u00a0JPY', '|')]
    [TestCase('CurrencyCHF it-IT', '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "CHF"})|1234,50\u00a0CHF', '|')]
    [TestCase('CurrencyCode it-IT',
      '(1234.5).toLocaleString("it-IT", {style: "currency", currency: "EUR", currencyDisplay: ' +
      '"code"})|1234,50\u00a0EUR', '|')]
    [TestCase('CurrencyNegative it-IT', '(-1234.5).toLocaleString("it-IT", {style: "currency", currency: "EUR"})|-1234,50\u00a0\u20ac', '|')]
    [TestCase('MinInteger it-IT', '(7).toLocaleString("it-IT", {minimumIntegerDigits: 3})|007', '|')]
    [TestCase('NoGrouping it-IT', '(1234567.5).toLocaleString("it-IT", {useGrouping: false})|1234567,5', '|')]
    [TestCase('Option en-US 1.005', '(1.005).toLocaleString("en-US", {maximumFractionDigits: 2})|1.01', '|')]
    [TestCase('Option en-US 2.5', '(2.5).toLocaleString("en-US", {maximumFractionDigits: 0})|3', '|')]
    [TestCase('Option en-US 0.5 = 1', '(0.5).toLocaleString("en-US", {maximumFractionDigits: 0})|1', '|')]
    [TestCase('Option en-US 0.4', '(0.4).toLocaleString("en-US", {maximumFractionDigits: 0})|0', '|')]
    [TestCase('Option en-US 1.45', '(1.45).toLocaleString("en-US", {maximumFractionDigits: 1})|1.5', '|')]
    [TestCase('Option en-US 999.9996', '(999.9996).toLocaleString("en-US", {maximumFractionDigits: 3})|1,000', '|')]
    [TestCase('Option en-US 0.0004', '(0.0004).toLocaleString("en-US", {maximumFractionDigits: 2})|0', '|')]
    [TestCase('Option en-US -0.0004', '(-0.0004).toLocaleString("en-US", {maximumFractionDigits: 2})|-0', '|')]
    [TestCase('Option nl-NL 0', '(0).toLocaleString("nl-NL", {minimumFractionDigits: 2})|0,00', '|')]
    [TestCase('Option en-US -0', '(-0).toLocaleString("en-US")|-0', '|')]
    [TestCase('Option en-US 1e21', '(1e21).toLocaleString("en-US")|1,000,000,000,000,000,000,000', '|')]
    [TestCase('Option en-US 123456789012345680000', '(123456789012345680000).toLocaleString("en-US")|123,456,789,012,345,680,000', '|')]
    [TestCase('Option en-US 0.000001', '(0.000001).toLocaleString("en-US", {maximumFractionDigits: 8})|0.000001', '|')]
    [TestCase('Option en-US 1234.5 = 1234.50000', '(1234.5).toLocaleString("en-US", {minimumFractionDigits: 5})|1,234.50000', '|')]
    [TestCase('Option en-US 1234.5678', '(1234.5678).toLocaleString("en-US", {maximumFractionDigits: 0})|1,235', '|')]
    [TestCase('Option en-US 1234.5 = 1235 style currency currency USD maximumFract', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "USD", maximumFractionDigits: 0})|$1,235', '|')]
    [TestCase('Option en-US 1234.5 = 1234.50 style currency currency usd', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "usd"})|$1,234.50', '|')]
    [TestCase('Option en-US 5 = u00a55', '(5).toLocaleString("en-US", {style: "currency", currency: "JPY"})|\u00a55', '|')]
    [TestCase('Option en-US 5 = KWDu00a05.000', '(5).toLocaleString("en-US", {style: "currency", currency: "KWD"})|KWD\u00a05.000', '|')]
    [TestCase('Option en-US 0.5 = 50', '(0.5).toLocaleString("en-US", {style: "percent", maximumFractionDigits: 2})|50%', '|')]
    [TestCase('Option de-DE 12.3456', '(12.3456).toLocaleString("de-DE", {style: "percent", maximumFractionDigits: 2})|1.234,56\u00a0%', '|')]
    [TestCase('Option en-US NaN', 'NaN.toLocaleString("en-US")|NaN', '|')]
    [TestCase('Option nl-NL Infinity', 'Infinity.toLocaleString("nl-NL")|\u221e', '|')]
    [TestCase('Option en-US -Infinity', '(-Infinity).toLocaleString("en-US")|-\u221e', '|')]
    [TestCase('Option nl-NL NaN', 'NaN.toLocaleString("nl-NL", {style: "currency", currency: "EUR"})|\u20ac\u00a0NaN', '|')]
    [TestCase('Option nl 8864.43', '(8864.43).toLocaleString("nl")|8.864,43', '|')]
    [TestCase('Option de 8864.43', '(8864.43).toLocaleString("de")|8.864,43', '|')]
    [TestCase('Option nl-NL-u-nu-latn 8864.43', '(8864.43).toLocaleString("nl-NL-u-nu-latn")|8.864,43', '|')]
    [TestCase('Option xx-XX 8864.43', '(8864.43).toLocaleString(["xx-XX", "nl-NL"])|8.864,43', '|')]
    [TestCase('Option de-DE 8864.43', '(8864.43).toLocaleString(["de-DE", "nl-NL"])|8.864,43', '|')]
    [TestCase('Option en-US 1234.5 = 1234.5', '(1234.5).toLocaleString("en-US", {})|1,234.5', '|')]
    [TestCase('Option en-US new Number1234.5', 'new Number(1234.5).toLocaleString("en-US")|1,234.5', '|')]
    [TestCase('Option 1234.5', '(1234.5).toLocaleString("EN-us")|1,234.5', '|')]
    [TestCase('Option en-US 1234567.891',
      '(1234567.891).toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2, useGrouping: ' +
      'true})|1,234,567.89', '|')]
    [TestCase('Option en-US 1234.5 = 001234.5',
      '(1234.5).toLocaleString("en-US", {style: "decimal", maximumFractionDigits: 1, minimumIntegerDigits: ' +
      '6})|001,234.5', '|')]
    [TestCase('Option en-US 12', '(12).toLocaleString("en-US", {style: "currency", currency: "EUR", currencyDisplay: "symbol"})|\u20ac12.00', '|')]
    [TestCase('Option en-US 1234.5 = 1235 maximumFractionDigits 0 minimumFractionD', '(1234.5).toLocaleString("en-US", {maximumFractionDigits: 0, minimumFractionDigits: 0})|1,235', '|')]
    [TestCase('Option en-US 2', '(2).toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 2})|2.00', '|')]
    [TestCase('Option en-US 1234.5 = 1234.50 minimumFractionDigits 2 maximumFractionD', '(1234.5).toLocaleString("en-US", {minimumFractionDigits: 2, maximumFractionDigits: 3})|1,234.50', '|')]
    [TestCase('Option nl-NL 1234.5',
      '(1234.5).toLocaleString("nl-NL", {style: "currency", currency: "EUR", maximumFractionDigits: ' +
      '0})|\u20ac\u00a01.235', '|')]
    [TestCase('Option en-US 1234.5 = u20b91234.50', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "INR"})|\u20b91,234.50', '|')]
    [TestCase('Option en-US 1234.5 = CA1234.50', '(1234.5).toLocaleString("en-US", {style: "currency", currency: "CAD"})|CA$1,234.50', '|')]
    [TestCase('Default en-US', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-US", {timeZone: "UTC"})|1/5/2024, 2:30:05 PM', '|')]
    [TestCase('DefaultLate en-US',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("en-US", {timeZone: "UTC"})|11/25/2024, ' +
      '12:05:09 AM', '|')]
    [TestCase('DateOnly en-US', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {timeZone: "UTC"})|1/5/2024', '|')]
    [TestCase('TimeOnly en-US', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-US", {timeZone: "UTC"})|2:30:05 PM', '|')]
    [TestCase('TimeOnlyLate en-US', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("en-US", {timeZone: "UTC"})|12:05:09 AM', '|')]
    [TestCase('LocalDefault en-US', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("en-US")|1/5/2024, 2:30:05 PM', '|')]
    [TestCase('LocalDate en-US', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("en-US")|1/5/2024', '|')]
    [TestCase('LocalTime en-US', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("en-US")|2:30:05 PM', '|')]
    [TestCase('MonthLong en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-US", {month: "long", timeZone: ' +
      '"UTC"})|January', '|')]
    [TestCase('MonthShort en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {month: "short", timeZone: ' +
      '"UTC"})|Jan', '|')]
    [TestCase('MonthNarrow en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {weekday: "long", timeZone: ' +
      '"UTC"})|Friday', '|')]
    [TestCase('WeekdayShort en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {weekday: "short", timeZone: ' +
      '"UTC"})|Fri', '|')]
    [TestCase('FullDate en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|Friday, January 5, 2024', '|')]
    [TestCase('MediumDate en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|Jan 5, 2024', '|')]
    [TestCase('MonthYear en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|January 2024', '|')]
    [TestCase('TwoDigits en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|01/05/2024', '|')]
    [TestCase('TwoDigitYear en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|1/5/24', '|')]
    [TestCase('DayMonth en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|1/5', '|')]
    [TestCase('YearOnly en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-US", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-US", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|02:30 PM', '|')]
    [TestCase('Hour en-US = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("en-US", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour en-US = 23005 PM',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-US", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 PM', '|')]
    [TestCase('DateTimeLong en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-US", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|January 5 at 02:30 PM', '|')]
    [TestCase('DateTimeShort en-US',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-US", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|Jan 5, 2024, ' +
      '2:30:05 PM', '|')]
    [TestCase('Default en-GB', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-GB", {timeZone: "UTC"})|05/01/2024, 14:30:05', '|')]
    [TestCase('DefaultLate en-GB',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("en-GB", {timeZone: "UTC"})|25/11/2024, ' +
      '00:05:09', '|')]
    [TestCase('DateOnly en-GB', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TimeOnly en-GB', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-GB", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate en-GB', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("en-GB", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault en-GB', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("en-GB")|05/01/2024, 14:30:05', '|')]
    [TestCase('LocalDate en-GB', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("en-GB")|05/01/2024', '|')]
    [TestCase('LocalTime en-GB', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("en-GB")|14:30:05', '|')]
    [TestCase('MonthLong en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-GB", {month: "long", timeZone: ' +
      '"UTC"})|January', '|')]
    [TestCase('MonthShort en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {month: "short", timeZone: ' +
      '"UTC"})|Jan', '|')]
    [TestCase('MonthNarrow en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {weekday: "long", timeZone: ' +
      '"UTC"})|Friday', '|')]
    [TestCase('WeekdayShort en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {weekday: "short", timeZone: ' +
      '"UTC"})|Fri', '|')]
    [TestCase('FullDate en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|Friday, 5 January 2024', '|')]
    [TestCase('MediumDate en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 Jan 2024', '|')]
    [TestCase('MonthYear en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|January 2024', '|')]
    [TestCase('TwoDigits en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TwoDigitYear en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|05/01/24', '|')]
    [TestCase('DayMonth en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|05/01', '|')]
    [TestCase('YearOnly en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("en-GB", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-GB", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour en-GB = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("en-GB", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour en-GB = 23005 pm',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("en-GB", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 pm', '|')]
    [TestCase('DateTimeLong en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-GB", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 January at 14:30', '|')]
    [TestCase('DateTimeShort en-GB',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("en-GB", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 Jan 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default nl-NL', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-NL", {timeZone: "UTC"})|5-1-2024, 14:30:05', '|')]
    [TestCase('DefaultLate nl-NL',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("nl-NL", {timeZone: "UTC"})|25-11-2024, ' +
      '00:05:09', '|')]
    [TestCase('DateOnly nl-NL', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {timeZone: "UTC"})|5-1-2024', '|')]
    [TestCase('TimeOnly nl-NL', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-NL", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate nl-NL', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("nl-NL", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault nl-NL', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("nl-NL")|5-1-2024, 14:30:05', '|')]
    [TestCase('LocalDate nl-NL', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("nl-NL")|5-1-2024', '|')]
    [TestCase('LocalTime nl-NL', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("nl-NL")|14:30:05', '|')]
    [TestCase('MonthLong nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-NL", {month: "long", timeZone: ' +
      '"UTC"})|januari', '|')]
    [TestCase('MonthShort nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {month: "short", timeZone: ' +
      '"UTC"})|jan', '|')]
    [TestCase('MonthNarrow nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {weekday: "long", timeZone: ' +
      '"UTC"})|vrijdag', '|')]
    [TestCase('WeekdayShort nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {weekday: "short", timeZone: ' +
      '"UTC"})|vr', '|')]
    [TestCase('FullDate nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|vrijdag 5 januari 2024', '|')]
    [TestCase('MediumDate nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 jan 2024', '|')]
    [TestCase('MonthYear nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|januari 2024', '|')]
    [TestCase('TwoDigits nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05-01-2024', '|')]
    [TestCase('TwoDigitYear nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|5-1-24', '|')]
    [TestCase('DayMonth nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|5-1', '|')]
    [TestCase('YearOnly nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-NL", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-NL", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour nl-NL = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("nl-NL", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour nl-NL = 23005 p.m.',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-NL", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 p.m.', '|')]
    [TestCase('DateTimeLong nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-NL", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 januari om 14:30', '|')]
    [TestCase('DateTimeShort nl-NL',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-NL", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 jan 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default nl-BE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-BE", {timeZone: "UTC"})|5/1/2024, 14:30:05', '|')]
    [TestCase('DefaultLate nl-BE',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("nl-BE", {timeZone: "UTC"})|25/11/2024, ' +
      '00:05:09', '|')]
    [TestCase('DateOnly nl-BE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {timeZone: "UTC"})|5/1/2024', '|')]
    [TestCase('TimeOnly nl-BE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-BE", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate nl-BE', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("nl-BE", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault nl-BE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("nl-BE")|5/1/2024, 14:30:05', '|')]
    [TestCase('LocalDate nl-BE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("nl-BE")|5/1/2024', '|')]
    [TestCase('LocalTime nl-BE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("nl-BE")|14:30:05', '|')]
    [TestCase('MonthLong nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-BE", {month: "long", timeZone: ' +
      '"UTC"})|januari', '|')]
    [TestCase('MonthShort nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {month: "short", timeZone: ' +
      '"UTC"})|jan', '|')]
    [TestCase('MonthNarrow nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {weekday: "long", timeZone: ' +
      '"UTC"})|vrijdag', '|')]
    [TestCase('WeekdayShort nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {weekday: "short", timeZone: ' +
      '"UTC"})|vr', '|')]
    [TestCase('FullDate nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|vrijdag 5 januari 2024', '|')]
    [TestCase('MediumDate nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 jan 2024', '|')]
    [TestCase('MonthYear nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|januari 2024', '|')]
    [TestCase('TwoDigits nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TwoDigitYear nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|5/1/24', '|')]
    [TestCase('DayMonth nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|5/1', '|')]
    [TestCase('YearOnly nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("nl-BE", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-BE", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour nl-BE = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("nl-BE", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour nl-BE = 23005 p.m.',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("nl-BE", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 p.m.', '|')]
    [TestCase('DateTimeLong nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-BE", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 januari om 14:30', '|')]
    [TestCase('DateTimeShort nl-BE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("nl-BE", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 jan 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default de-DE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("de-DE", {timeZone: "UTC"})|5.1.2024, 14:30:05', '|')]
    [TestCase('DefaultLate de-DE',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("de-DE", {timeZone: "UTC"})|25.11.2024, ' +
      '00:05:09', '|')]
    [TestCase('DateOnly de-DE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {timeZone: "UTC"})|5.1.2024', '|')]
    [TestCase('TimeOnly de-DE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("de-DE", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate de-DE', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("de-DE", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault de-DE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("de-DE")|5.1.2024, 14:30:05', '|')]
    [TestCase('LocalDate de-DE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("de-DE")|5.1.2024', '|')]
    [TestCase('LocalTime de-DE', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("de-DE")|14:30:05', '|')]
    [TestCase('MonthLong de-DE', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("de-DE", {month: "long", timeZone: "UTC"})|Januar', '|')]
    [TestCase('MonthShort de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {month: "short", timeZone: ' +
      '"UTC"})|Jan', '|')]
    [TestCase('MonthNarrow de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {weekday: "long", timeZone: ' +
      '"UTC"})|Freitag', '|')]
    [TestCase('WeekdayShort de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {weekday: "short", timeZone: ' +
      '"UTC"})|Fr', '|')]
    [TestCase('FullDate de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|Freitag, 5. Januar 2024', '|')]
    [TestCase('MediumDate de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5. Jan. 2024', '|')]
    [TestCase('MonthYear de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|Januar 2024', '|')]
    [TestCase('TwoDigits de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05.01.2024', '|')]
    [TestCase('TwoDigitYear de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|5.1.24', '|')]
    [TestCase('DayMonth de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|5.1.', '|')]
    [TestCase('YearOnly de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("de-DE", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("de-DE", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour de-DE = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("de-DE", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour de-DE = 23005 PM',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("de-DE", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 PM', '|')]
    [TestCase('DateTimeLong de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("de-DE", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5. Januar um 14:30', '|')]
    [TestCase('DateTimeShort de-DE',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("de-DE", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5. Jan. 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default fr-FR', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("fr-FR", {timeZone: "UTC"})|05/01/2024 14:30:05', '|')]
    [TestCase('DefaultLate fr-FR', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("fr-FR", {timeZone: "UTC"})|25/11/2024 00:05:09', '|')]
    [TestCase('DateOnly fr-FR', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TimeOnly fr-FR', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("fr-FR", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate fr-FR', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("fr-FR", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault fr-FR', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("fr-FR")|05/01/2024 14:30:05', '|')]
    [TestCase('LocalDate fr-FR', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("fr-FR")|05/01/2024', '|')]
    [TestCase('LocalTime fr-FR', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("fr-FR")|14:30:05', '|')]
    [TestCase('MonthLong fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("fr-FR", {month: "long", timeZone: ' +
      '"UTC"})|janvier', '|')]
    [TestCase('MonthShort fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {month: "short", timeZone: ' +
      '"UTC"})|janv.', '|')]
    [TestCase('MonthNarrow fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {month: "narrow", timeZone: ' +
      '"UTC"})|J', '|')]
    [TestCase('WeekdayLong fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {weekday: "long", timeZone: ' +
      '"UTC"})|vendredi', '|')]
    [TestCase('WeekdayShort fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {weekday: "short", timeZone: ' +
      '"UTC"})|ven.', '|')]
    [TestCase('FullDate fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|vendredi 5 janvier 2024', '|')]
    [TestCase('MediumDate fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 janv. 2024', '|')]
    [TestCase('MonthYear fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|janvier 2024', '|')]
    [TestCase('TwoDigits fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TwoDigitYear fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|05/01/24', '|')]
    [TestCase('DayMonth fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|05/01', '|')]
    [TestCase('YearOnly fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("fr-FR", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("fr-FR", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour fr-FR = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("fr-FR", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour fr-FR = 23005 PM',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("fr-FR", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 PM', '|')]
    [TestCase('DateTimeLong fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("fr-FR", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 janvier \u00e0 14:30', '|')]
    [TestCase('DateTimeShort fr-FR',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("fr-FR", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 janv. 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default es-ES', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("es-ES", {timeZone: "UTC"})|5/1/2024, 14:30:05', '|')]
    [TestCase('DefaultLate es-ES', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("es-ES", {timeZone: "UTC"})|25/11/2024, 0:05:09', '|')]
    [TestCase('DateOnly es-ES', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {timeZone: "UTC"})|5/1/2024', '|')]
    [TestCase('TimeOnly es-ES', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("es-ES", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate es-ES', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("es-ES", {timeZone: "UTC"})|0:05:09', '|')]
    [TestCase('LocalDefault es-ES', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("es-ES")|5/1/2024, 14:30:05', '|')]
    [TestCase('LocalDate es-ES', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("es-ES")|5/1/2024', '|')]
    [TestCase('LocalTime es-ES', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("es-ES")|14:30:05', '|')]
    [TestCase('MonthLong es-ES', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("es-ES", {month: "long", timeZone: "UTC"})|enero', '|')]
    [TestCase('MonthShort es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {month: "short", timeZone: ' +
      '"UTC"})|ene', '|')]
    [TestCase('MonthNarrow es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {month: "narrow", timeZone: ' +
      '"UTC"})|E', '|')]
    [TestCase('WeekdayLong es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {weekday: "long", timeZone: ' +
      '"UTC"})|viernes', '|')]
    [TestCase('WeekdayShort es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {weekday: "short", timeZone: ' +
      '"UTC"})|vie', '|')]
    [TestCase('FullDate es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|viernes, 5 de enero de 2024', '|')]
    [TestCase('MediumDate es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 ene 2024', '|')]
    [TestCase('MonthYear es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|enero de 2024', '|')]
    [TestCase('TwoDigits es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TwoDigitYear es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|5/1/24', '|')]
    [TestCase('DayMonth es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|5/1', '|')]
    [TestCase('YearOnly es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("es-ES", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("es-ES", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour es-ES = 00509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("es-ES", {hour12: false, timeZone: ' +
      '"UTC"})|0:05:09', '|')]
    [TestCase('Hour es-ES = 23005 p.u00a0m.',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("es-ES", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 p.\u00a0m.', '|')]
    [TestCase('DateTimeLong es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("es-ES", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 de enero, 14:30', '|')]
    [TestCase('DateTimeShort es-ES',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("es-ES", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 ene 2024, ' +
      '14:30:05', '|')]
    [TestCase('Default it-IT', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("it-IT", {timeZone: "UTC"})|05/01/2024, 14:30:05', '|')]
    [TestCase('DefaultLate it-IT',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleString("it-IT", {timeZone: "UTC"})|25/11/2024, ' +
      '00:05:09', '|')]
    [TestCase('DateOnly it-IT', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TimeOnly it-IT', '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("it-IT", {timeZone: "UTC"})|14:30:05', '|')]
    [TestCase('TimeOnlyLate it-IT', '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("it-IT", {timeZone: "UTC"})|00:05:09', '|')]
    [TestCase('LocalDefault it-IT', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("it-IT")|05/01/2024, 14:30:05', '|')]
    [TestCase('LocalDate it-IT', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("it-IT")|05/01/2024', '|')]
    [TestCase('LocalTime it-IT', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("it-IT")|14:30:05', '|')]
    [TestCase('MonthLong it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("it-IT", {month: "long", timeZone: ' +
      '"UTC"})|gennaio', '|')]
    [TestCase('MonthShort it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {month: "short", timeZone: ' +
      '"UTC"})|gen', '|')]
    [TestCase('MonthNarrow it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {month: "narrow", timeZone: ' +
      '"UTC"})|G', '|')]
    [TestCase('WeekdayLong it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {weekday: "long", timeZone: ' +
      '"UTC"})|venerd\u00ec', '|')]
    [TestCase('WeekdayShort it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {weekday: "short", timeZone: ' +
      '"UTC"})|ven', '|')]
    [TestCase('FullDate it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {weekday: "long", year: ' +
      '"numeric", month: "long", day: "numeric", timeZone: "UTC"})|venerd\u00ec 5 gennaio 2024', '|')]
    [TestCase('MediumDate it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {year: "numeric", month: ' +
      '"short", day: "numeric", timeZone: "UTC"})|5 gen 2024', '|')]
    [TestCase('MonthYear it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {month: "long", year: "numeric", ' +
      'timeZone: "UTC"})|gennaio 2024', '|')]
    [TestCase('TwoDigits it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {year: "numeric", month: ' +
      '"2-digit", day: "2-digit", timeZone: "UTC"})|05/01/2024', '|')]
    [TestCase('TwoDigitYear it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {year: "2-digit", month: ' +
      '"numeric", day: "numeric", timeZone: "UTC"})|05/01/24', '|')]
    [TestCase('DayMonth it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {month: "numeric", day: ' +
      '"numeric", timeZone: "UTC"})|05/01', '|')]
    [TestCase('YearOnly it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleDateString("it-IT", {year: "numeric", timeZone: ' +
      '"UTC"})|2024', '|')]
    [TestCase('HourMinute it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("it-IT", {hour: "2-digit", minute: ' +
      '"2-digit", timeZone: "UTC"})|14:30', '|')]
    [TestCase('Hour it-IT = 000509',
      '(new Date(Date.UTC(2024, 10, 25, 0, 5, 9))).toLocaleTimeString("it-IT", {hour12: false, timeZone: ' +
      '"UTC"})|00:05:09', '|')]
    [TestCase('Hour it-IT = 23005 PM',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleTimeString("it-IT", {hour12: true, timeZone: ' +
      '"UTC"})|2:30:05 PM', '|')]
    [TestCase('DateTimeLong it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("it-IT", {month: "long", day: "numeric", ' +
      'hour: "2-digit", minute: "2-digit", timeZone: "UTC"})|5 gennaio alle ore 14:30', '|')]
    [TestCase('DateTimeShort it-IT',
      '(new Date(Date.UTC(2024, 0, 5, 14, 30, 5))).toLocaleString("it-IT", {year: "numeric", month: "short", ' +
      'day: "numeric", hour: "numeric", minute: "numeric", second: "numeric", timeZone: "UTC"})|5 gen 2024, ' +
      '14:30:05', '|')]
    [TestCase('MonthName nl-NL = februari', 'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("nl-NL", {month: "long", timeZone: "UTC"})|februari', '|')]
    [TestCase('MonthName de-DE = Februar', 'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("de-DE", {month: "long", timeZone: "UTC"})|Februar', '|')]
    [TestCase('MonthName fr-FR = fu00e9vrier',
      'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("fr-FR", {month: "long", timeZone: ' +
      '"UTC"})|f\u00e9vrier', '|')]
    [TestCase('MonthName es-ES = febrero', 'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("es-ES", {month: "long", timeZone: "UTC"})|febrero', '|')]
    [TestCase('MonthName it-IT = febbraio', 'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("it-IT", {month: "long", timeZone: "UTC"})|febbraio', '|')]
    [TestCase('MonthName en-GB = February', 'new Date(Date.UTC(2024, 1, 15)).toLocaleDateString("en-GB", {month: "long", timeZone: "UTC"})|February', '|')]
    [TestCase('MonthAbbreviation nl-NL = 15 mrt',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("nl-NL", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 mrt', '|')]
    [TestCase('MonthAbbreviation de-DE = 15. Mu00e4rz',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("de-DE", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15. M\u00e4rz', '|')]
    [TestCase('MonthAbbreviation fr-FR = 15 mars',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("fr-FR", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 mars', '|')]
    [TestCase('MonthAbbreviation es-ES = 15 mar',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("es-ES", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 mar', '|')]
    [TestCase('MonthAbbreviation it-IT = 15 mar',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("it-IT", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 mar', '|')]
    [TestCase('MonthAbbreviation en-GB = 15 Mar',
      'new Date(Date.UTC(2024, 2, 15)).toLocaleDateString("en-GB", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 Mar', '|')]
    [TestCase('MonthName nl-NL = juni', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("nl-NL", {month: "long", timeZone: "UTC"})|juni', '|')]
    [TestCase('MonthName de-DE = Juni', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("de-DE", {month: "long", timeZone: "UTC"})|Juni', '|')]
    [TestCase('MonthName fr-FR = juin', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("fr-FR", {month: "long", timeZone: "UTC"})|juin', '|')]
    [TestCase('MonthName es-ES = junio', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("es-ES", {month: "long", timeZone: "UTC"})|junio', '|')]
    [TestCase('MonthName it-IT = giugno', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("it-IT", {month: "long", timeZone: "UTC"})|giugno', '|')]
    [TestCase('MonthName en-GB = June', 'new Date(Date.UTC(2024, 5, 15)).toLocaleDateString("en-GB", {month: "long", timeZone: "UTC"})|June', '|')]
    [TestCase('MonthAbbreviation nl-NL = 15 jul',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("nl-NL", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 jul', '|')]
    [TestCase('MonthAbbreviation de-DE = 15. Juli',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("de-DE", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15. Juli', '|')]
    [TestCase('MonthAbbreviation fr-FR = 15 juil.',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("fr-FR", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 juil.', '|')]
    [TestCase('MonthAbbreviation es-ES = 15 jul',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("es-ES", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 jul', '|')]
    [TestCase('MonthAbbreviation it-IT = 15 lug',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("it-IT", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 lug', '|')]
    [TestCase('MonthAbbreviation en-GB = 15 Jul',
      'new Date(Date.UTC(2024, 6, 15)).toLocaleDateString("en-GB", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 Jul', '|')]
    [TestCase('MonthName nl-NL = oktober', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("nl-NL", {month: "long", timeZone: "UTC"})|oktober', '|')]
    [TestCase('MonthName de-DE = Oktober', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("de-DE", {month: "long", timeZone: "UTC"})|Oktober', '|')]
    [TestCase('MonthName fr-FR = octobre', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("fr-FR", {month: "long", timeZone: "UTC"})|octobre', '|')]
    [TestCase('MonthName es-ES = octubre', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("es-ES", {month: "long", timeZone: "UTC"})|octubre', '|')]
    [TestCase('MonthName it-IT = ottobre', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("it-IT", {month: "long", timeZone: "UTC"})|ottobre', '|')]
    [TestCase('MonthName en-GB = October', 'new Date(Date.UTC(2024, 9, 15)).toLocaleDateString("en-GB", {month: "long", timeZone: "UTC"})|October', '|')]
    [TestCase('MonthAbbreviation nl-NL = 15 nov',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("nl-NL", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 nov', '|')]
    [TestCase('MonthAbbreviation de-DE = 15. Nov.',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("de-DE", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15. Nov.', '|')]
    [TestCase('MonthAbbreviation fr-FR = 15 nov.',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("fr-FR", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 nov.', '|')]
    [TestCase('MonthAbbreviation es-ES = 15 nov',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("es-ES", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 nov', '|')]
    [TestCase('MonthAbbreviation it-IT = 15 nov',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("it-IT", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 nov', '|')]
    [TestCase('MonthAbbreviation en-GB = 15 Nov',
      'new Date(Date.UTC(2024, 10, 15)).toLocaleDateString("en-GB", {month: "short", day: "numeric", timeZone: ' +
      '"UTC"})|15 Nov', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 = January', 'new Date(Date.UTC(2024, 0, 15)).toLocaleString("en-US", {month: "long", timeZone: "UTC"})|January', '|')]
    [TestCase('Option nl-NL new DateDate.UTC2024 0 15', 'new Date(Date.UTC(2024, 0, 15)).toLocaleDateString("nl-NL", {timeZone: "UTC"})|15-1-2024', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 = 1152024', 'new Date(Date.UTC(2024, 0, 15)).toLocaleDateString("en-US", {timeZone: "UTC"})|1/15/2024', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 23 59',
      'new Date(Date.UTC(2024, 0, 15, 23, 59, 59)).toLocaleString("en-US", {timeZone: "UTC", hour: "numeric", ' +
      'minute: "2-digit"})|11:59 PM', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 12 0 0', 'new Date(Date.UTC(2024, 0, 15, 12, 0, 0)).toLocaleTimeString("en-US", {timeZone: "UTC"})|12:00:00 PM', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 0 0 0', 'new Date(Date.UTC(2024, 0, 15, 0, 0, 0)).toLocaleTimeString("en-US", {timeZone: "UTC"})|12:00:00 AM', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = 090507 hour 2-digit minute 2-digit second 2-dig',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleTimeString("en-US", {hour: "2-digit", minute: ' +
      '"2-digit", second: "2-digit", hour12: false, timeZone: "UTC"})|09:05:07', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = 905 AM',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleTimeString("en-US", {hour: "numeric", minute: ' +
      '"2-digit", timeZone: "UTC"})|9:05 AM', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = 1152024 9 AM',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("en-US", {hour: "numeric", timeZone: ' +
      '"UTC"})|1/15/2024, 9 AM', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = 090507 hourCycle h23 timeZone UTC',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleTimeString("en-US", {hourCycle: "h23", timeZone: ' +
      '"UTC"})|09:05:07', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = Mon',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleString("en-US", {timeZone: "Etc/UTC", weekday: ' +
      '"short"})|Mon', '|')]
    [TestCase('Option xx-XX new DateDate.UTC2024 0 15 9 5 7',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString(["xx-XX", "de-DE"], {month: "long", ' +
      'timeZone: "UTC"})|Januar', '|')]
    [TestCase('Option new DateDate.UTC2024 0 15 9 5 7',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("fr", {month: "long", timeZone: ' +
      '"UTC"})|janvier', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = January 15 2024',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("en-US", {year: "numeric", month: "long", ' +
      'day: "2-digit", timeZone: "UTC"})|January 15, 2024', '|')]
    [TestCase('Option en-GB',
      'new Date(Date.UTC(2024, 11, 31, 9, 5, 7)).toLocaleDateString("en-GB", {day: "numeric", month: "short", ' +
      'year: "numeric", timeZone: "UTC"})|31 Dec 2024', '|')]
    [TestCase('Option de-DE new DateDate.UTC2024 0 15 9 5 7 = Mo. 15. Jan. 2024',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("de-DE", {weekday: "short", year: "numeric", ' +
      'month: "short", day: "numeric", timeZone: "UTC"})|Mo., 15. Jan. 2024', '|')]
    [TestCase('Option de-DE new DateDate.UTC2024 0 15 9 5 7 = Mo',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("de-DE", {weekday: "short", timeZone: ' +
      '"UTC"})|Mo', '|')]
    [TestCase('Option de-DE new DateDate.UTC2024 0 15 9 5 7 = Jan',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("de-DE", {month: "short", timeZone: ' +
      '"UTC"})|Jan', '|')]
    [TestCase('Option de-DE new DateDate.UTC2024 0 15 9 5 7 = Jan. 2024',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("de-DE", {month: "short", year: "numeric", ' +
      'timeZone: "UTC"})|Jan. 2024', '|')]
    [TestCase('Option en-US new DateDate.UTC2024 0 15 9 5 7 = Mon Jan 15',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("en-US", {weekday: "short", month: "short", ' +
      'day: "numeric", timeZone: "UTC"})|Mon, Jan 15', '|')]
    [TestCase('Option nl-NL new DateDate.UTC2024 0 15 9 5 7',
      'new Date(Date.UTC(2024, 0, 15, 9, 5, 7)).toLocaleDateString("nl-NL", {weekday: "long", day: "numeric", ' +
      'month: "long", timeZone: "UTC"})|maandag 15 januari', '|')]
    [TestCase('NoArguments', '(8864.43).toLocaleString()|8864.43', '|')]
    [TestCase('UnknownLocale', '(8864.43).toLocaleString("xx-XX")|8864.43', '|')]
    [TestCase('NumberAsLocale', '(255).toLocaleString(16)|255', '|')]
    [TestCase('NullLocale', '(8864.43).toLocaleString(null)|8864.43', '|')]
    [TestCase('DateNoArguments', 'new Date(2024, 0, 5, 14, 30, 5).toLocaleString() === new Date(2024, 0, 5, 14, 30, 5).toString()|true', '|')]
    [TestCase('DateUnknownLocale',
      'new Date(2024, 0, 5, 14, 30, 5).toLocaleString("xx-XX") === new Date(2024, 0, 5, 14, 30, ' +
      '5).toString()|true', '|')]
    [TestCase('DateOnlyUnknownLocale',
      'new Date(2024, 0, 5, 14, 30, 5).toLocaleDateString("xx-XX") === new Date(2024, 0, 5, 14, 30, ' +
      '5).toDateString()|true', '|')]
    [TestCase('TimeOnlyUnknownLocale',
      'new Date(2024, 0, 5, 14, 30, 5).toLocaleTimeString("xx-XX") === new Date(2024, 0, 5, 14, 30, ' +
      '5).toTimeString()|true', '|')]
    [TestCase('InvalidDate', 'new Date(NaN).toLocaleString("nl-NL", {month: "long"})|Invalid Date', '|')]
    [TestCase('NumberWithoutLocale', '(8864.43).toLocaleString(undefined, {minimumFractionDigits: 3})|8,864.430', '|')]
    [TestCase('NumberUnknownLocale', '(8864.43).toLocaleString("xx-XX", {minimumFractionDigits: 3})|8,864.430', '|')]
    [TestCase('DateWithoutLocale',
      'new Date(Date.UTC(2024, 0, 15)).toLocaleDateString(undefined, {month: "long", year: "numeric", timeZone: ' +
      '"UTC"})|January 2024', '|')]
    [TestCase('FallbackDateUnknownLocale',
      'new Date(Date.UTC(2024, 0, 15)).toLocaleDateString("xx-XX", {month: "long", year: "numeric", timeZone: ' +
      '"UTC"})|January 2024', '|')]
    [TestCase('MissingCurrency', '(1).toLocaleString("en-US", {style: "currency"})|TypeError: Currency code is required with currency style.', '|')]
    [TestCase('FractionDigitsAboveLimit',
      '(1).toLocaleString("en-US", {maximumFractionDigits: 101})|RangeError: maximumFractionDigits value is out ' +
      'of range.', '|')]
    [TestCase('InvertedFractionDigits',
      '(1).toLocaleString("en-US", {minimumFractionDigits: 3, maximumFractionDigits: 1})|RangeError: ' +
      'maximumFractionDigits value is out of range.', '|')]
    [TestCase('InvalidCurrency', '(1).toLocaleString("en-US", {style: "currency", currency: "EURO"})|RangeError: Invalid currency code : EURO', '|')]
    [TestCase('IntegerDigitsBelowLimit',
      '(1).toLocaleString("en-US", {minimumIntegerDigits: 0})|RangeError: minimumIntegerDigits value is out of ' +
      'range.', '|')]
    [TestCase('InvalidStyle',
      '(1).toLocaleString("en-US", {style: "bogus"})|RangeError: Value bogus out of range for ' +
      'Number.prototype.toLocaleString options property style', '|')]
    [TestCase('InvalidMonth',
      'new Date(0).toLocaleString("en-US", {month: "bogus"})|RangeError: Value bogus out of range for ' +
      'Date.prototype.toLocaleString options property month', '|')]
    procedure ToLocaleString_Script_ReturnsExpectedText(const Script: string; const Expected: string);

    [Test]
    procedure ToLocaleString_Methods_KeepLengthZero;
  end;

implementation

const
  ESCAPE_PRELUDE = 'function escapeText(text) {' +
                   '  return String(text).replace(/[^\x20-\x7e]/g, function(c) {' +
                   '    return String.fromCharCode(92) + "u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4);' +
                   '  });' +
                   '}';
  CATCH_FORMAT = 'escapeText((function() { try { return %s; } catch (e) { return e.name + ": " + e.message; } })())';

function TLocaleFormattingTests.EvaluateEscaped(const Script: string): string;
begin
  FEngine.Evaluate(ESCAPE_PRELUDE);

  const GuardedScript = Format(CATCH_FORMAT, [Script]);

  Result := EvaluateText(GuardedScript);
end;

procedure TLocaleFormattingTests.ToLocaleString_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = EvaluateEscaped(Script);

  Assert.AreEqual(Expected, Actual, Script);
end;

procedure TLocaleFormattingTests.ToLocaleString_Methods_KeepLengthZero;
begin
  const Script = 'Number.prototype.toLocaleString.length === 0 && Date.prototype.toLocaleString.length === 0 && ' +
                 'Date.prototype.toLocaleDateString.length === 0 && Date.prototype.toLocaleTimeString.length === 0';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
