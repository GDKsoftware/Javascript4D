unit JS4D.BuiltInLocales;

{$SCOPEDENUMS ON}

interface

type
  TJSCurrencyLayout = (SymbolBeforeNumber, SymbolBeforeNumberWithSpace, SymbolAfterNumberWithSpace);

  TJSLocaleDefinition = record
    Tag: string;
    DecimalSeparator: string;
    GroupSeparator: string;
    MinimumGroupingDigits: Integer;
    MinusSign: string;
    CurrencyLayout: TJSCurrencyLayout;
    PercentGap: string;
    CurrencySymbols: string;
    Hour12ByDefault: Boolean;
    AmMarker: string;
    PmMarker: string;
    MonthsLong: array[0..11] of string;
    MonthsShort: array[0..11] of string;
    MonthsShortStandalone: array[0..11] of string;
    MonthsNarrow: string;
    WeekdaysLong: array[0..6] of string;
    WeekdaysShort: array[0..6] of string;
    WeekdaysShortStandalone: array[0..6] of string;
    WeekdaysNarrow: string;
    DatePatterns: string;
    TimePatterns12: string;
    TimePatterns24: string;
    DateTimeGlueNumeric: string;
    DateTimeGlueShort: string;
    DateTimeGlueLong: string;
  end;

  TJSBuiltInLocaleTable = class
  private
    const
      LOCALE_COUNT = 8;
      EXTENSION_MARKER = '-u-';
      TAG_SEPARATOR = '-';

    class function StripExtensions(const Requested: string): string; static;
    class function ExpandLanguage(const Requested: string): string; static;
    class function TryFindExact(const Tag: string; out Locale: TJSLocaleDefinition): Boolean; static;
  public
    class function TryFind(const Requested: string; out Locale: TJSLocaleDefinition): Boolean; static;
    class function FindDefault: TJSLocaleDefinition; static;
    class function FindPattern(const Patterns: string; const Key: string; out Pattern: string): Boolean; static;
    class function FindCurrencySymbol(const Locale: TJSLocaleDefinition; const Currency: string): string; static;
  end;

implementation

uses
  System.SysUtils;

const
  DEFAULT_TAG = 'en-US';
  PATTERN_SEPARATOR = '|';
  PATTERN_ASSIGN = '=';
  SYMBOL_ASSIGN = '=';

  LANGUAGE_DEFAULTS: array[0..5, 0..1] of string = (
    ('en', 'en-US'),
    ('nl', 'nl-NL'),
    ('de', 'de-DE'),
    ('fr', 'fr-FR'),
    ('es', 'es-ES'),
    ('it', 'it-IT'));

  BUILT_IN_LOCALES: array[0..7] of TJSLocaleDefinition = (
  (Tag: 'en-US';
   DecimalSeparator: '.'; GroupSeparator: ','; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolBeforeNumber; PercentGap: '';
   CurrencySymbols: 'EUR='#$20AC'|USD=$|GBP='#$00A3'|JPY='#$00A5'|CAD=CA$|AUD=A$|INR='#$20B9'|CNY=CN'#$00A5'|BRL=R$|MXN=MX$|KRW='#$20A9'|NZD=NZ$|HKD=HK$|ILS='#$20AA'|TWD=NT$|PHP='#$20B1'|VND='#$20AB;
   Hour12ByDefault: True; AmMarker: 'AM'; PmMarker: 'PM';
   MonthsLong: ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
   MonthsShort: ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
   MonthsShortStandalone: ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
   WeekdaysShort: ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
   WeekdaysShortStandalone: ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
   WeekdaysNarrow: 'SMTWTFS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=M/d|Mdd=M/dd|MM=MM|MMd=MM/d|MMdd=MM/dd|MMM=MMM|MMMd=MMM d|MMMdd=MMM dd|MMMM=MMM|MMMMd=MMM d' +
      '|MMMMdd=MMM dd|y=y|yd=y ([day]: d)|ydd=y ([day]: dd)|yM=M/y|yMd=M/d/y|yMdd=M/dd/y|yMM=MM/y|yMMd=MM/d/y' +
      '|yMMdd=MM/dd/y|yMMM=MMM y|yMMMd=MMM d, y|yMMMdd=MMM dd, y|yMMMM=MMM y|yMMMMd=MMM d, y|yMMMMdd=MMM dd, y|E=E' +
      '|Ed=d E|Edd=dd E|EM=M E|EMd=E, M/d|EMdd=E, M/dd|EMM=E ([month]: MM)|EMMd=E, MM/d|EMMdd=E, MM/dd|EMMM=MMM E' +
      '|EMMMd=E, MMM d|EMMMdd=E, MMM dd|EMMMM=E ([month]: MMM)|EMMMMd=E, MMM d|EMMMMdd=E, MMM dd|Ey=y E|Eyd=d E y' +
      '|Eydd=dd E y|EyM=M/y E|EyMd=E, M/d/y|EyMdd=E, M/dd/y|EyMM=MM/y E|EyMMd=E, MM/d/y|EyMMdd=E, MM/dd/y' +
      '|EyMMM=MMM y E|EyMMMd=E, MMM d, y|EyMMMdd=E, MMM dd, y|EyMMMM=MMM y E|EyMMMMd=E, MMM d, y' +
      '|EyMMMMdd=E, MMM dd, y|EEEE=E|EEEEd=d E|EEEEdd=dd E|EEEEM=M E|EEEEMd=E, M/d|EEEEMdd=E, M/dd|EEEEMM=MM E' +
      '|EEEEMMd=E, MM/d|EEEEMMdd=E, MM/dd|EEEEMMM=MMM E|EEEEMMMd=E, MMM d|EEEEMMMdd=E, MMM dd|EEEEMMMM=MMM E' +
      '|EEEEMMMMd=E, MMM d|EEEEMMMMdd=E, MMM dd|EEEEy=y E|EEEEyd=d E y|EEEEydd=dd E y|EEEEyM=M/y E|EEEEyMd=E, M/d/y' +
      '|EEEEyMdd=E, M/dd/y|EEEEyMM=MM/y E|EEEEyMMd=E, MM/d/y|EEEEyMMdd=E, MM/dd/y|EEEEyMMM=MMM y E' +
      '|EEEEyMMMd=E, MMM d, y|EEEEyMMMdd=E, MMM dd, y|EEEEyMMMM=MMM y E|EEEEyMMMMd=E, MMM d, y' +
      '|EEEEyMMMMdd=E, MMM dd, y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([second]: s)|hss=h'#$202F'a ([second]: s)' +
      '|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([second]: s)|hhss=hh'#$202F'a ([second]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a' +
      '|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH|hs=HH ([second]: s)|hss=HH ([second]: s)' +
      '|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=HH:mm|hmms=HH:mm:ss|hmmss=HH:mm:ss|hh=HH|hhs=s ([hour]: HH)' +
      '|hhss=HH ([second]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' at '),
  (Tag: 'en-GB';
   DecimalSeparator: '.'; GroupSeparator: ','; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolBeforeNumber; PercentGap: '';
   CurrencySymbols: 'EUR='#$20AC'|USD=US$|GBP='#$00A3'|JPY=JP'#$00A5'|CAD=CA$|AUD=A$|INR='#$20B9'|CNY=CN'#$00A5'|BRL=R$|MXN=MX$|KRW='#$20A9'|NZD=NZ$|HKD=HK$|ILS='#$20AA'|TWD=NT$|PHP='#$20B1'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'am'; PmMarker: 'pm';
   MonthsLong: ('January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December');
   MonthsShort: ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec');
   MonthsShortStandalone: ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday');
   WeekdaysShort: ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
   WeekdaysShortStandalone: ('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
   WeekdaysNarrow: 'SMTWTFS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=dd/MM|Mdd=dd/M|MM=MM|MMd=d/MM|MMdd=dd/MM|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM' +
      '|MMMMd=d MMM|MMMMdd=dd MMM|y=y|yd=y ([day]: d)|ydd=y ([day]: dd)|yM=MM/y|yMd=dd/MM/y|yMdd=dd/M/y|yMM=MM/y' +
      '|yMMd=d/MM/y|yMMdd=dd/MM/y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM y|yMMMMd=d MMM y' +
      '|yMMMMdd=dd MMM y|E=E|Ed=E d|Edd=E dd|EM=M E|EMd=E dd/MM|EMdd=E dd/MM|EMM=E ([month]: MM)|EMMd=E dd/MM' +
      '|EMMdd=E dd/MM|EMMM=MMM E|EMMMd=E d MMM|EMMMdd=E dd MMM|EMMMM=E ([month]: MMM)|EMMMMd=E d MMM|EMMMMdd=E dd MMM' +
      '|Ey=y E|Eyd=E d y|Eydd=E dd y|EyM=MM/y E|EyMd=E, dd/MM/y|EyMdd=E, dd/MM/y|EyMM=MM/y E|EyMMd=E, dd/MM/y' +
      '|EyMMdd=E, dd/MM/y|EyMMM=MMM y E|EyMMMd=E, d MMM y|EyMMMdd=E, dd MMM y|EyMMMM=MMM y E|EyMMMMd=E, d MMM y' +
      '|EyMMMMdd=E, dd MMM y|EEEE=E|EEEEd=E d|EEEEdd=E dd|EEEEM=M E|EEEEMd=E dd/MM|EEEEMdd=E dd/MM|EEEEMM=MM E' +
      '|EEEEMMd=E dd/MM|EEEEMMdd=E dd/MM|EEEEMMM=MMM E|EEEEMMMd=E d MMM|EEEEMMMdd=E dd MMM|EEEEMMMM=MMM E' +
      '|EEEEMMMMd=E d MMM|EEEEMMMMdd=E dd MMM|EEEEy=y E|EEEEyd=E d y|EEEEydd=E dd y|EEEEyM=MM/y E|EEEEyMd=E, dd/MM/y' +
      '|EEEEyMdd=E, dd/MM/y|EEEEyMM=MM/y E|EEEEyMMd=E, dd/MM/y|EEEEyMMdd=E, dd/MM/y|EEEEyMMM=MMM y E' +
      '|EEEEyMMMd=E, d MMM y|EEEEyMMMdd=E, dd MMM y|EEEEyMMMM=MMM y E|EEEEyMMMMd=E, d MMM y|EEEEyMMMMdd=E, dd MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([second]: s)|hss=h'#$202F'a ([second]: s)' +
      '|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([second]: s)|hhss=hh'#$202F'a ([second]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a' +
      '|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH|hs=HH ([second]: s)|hss=HH ([second]: s)' +
      '|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss|hh=HH|hhs=s ([hour]: HH)' +
      '|hhss=HH ([second]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' at '),
  (Tag: 'nl-NL';
   DecimalSeparator: ','; GroupSeparator: '.'; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolBeforeNumberWithSpace; PercentGap: '';
   CurrencySymbols: 'EUR='#$20AC'|USD=US$|GBP='#$00A3'|JPY=JP'#$00A5'|CAD=C$|AUD=AU$|INR='#$20B9'|CNY=CN'#$00A5'|BRL=R$|MXN=MX$|KRW='#$20A9'|NZD=NZ$|HKD=HK$|ILS='#$20AA'|TWD=NT$|THB='#$0E3F'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'a.m.'; PmMarker: 'p.m.';
   MonthsLong: ('januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december');
   MonthsShort: ('jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec');
   MonthsShortStandalone: ('jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag');
   WeekdaysShort: ('zo', 'ma', 'di', 'wo', 'do', 'vr', 'za');
   WeekdaysShortStandalone: ('zo', 'ma', 'di', 'wo', 'do', 'vr', 'za');
   WeekdaysNarrow: 'ZMDWDVZ';
   DatePatterns: '|d=d|dd=dd|M=M|Md=d-M|Mdd=dd-M|MM=MM|MMd=d-MM|MMdd=dd-MM|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM|MMMMd=d MMM' +
      '|MMMMdd=dd MMM|y=y|yd=y ([dag]: d)|ydd=y ([dag]: dd)|yM=M-y|yMd=d-M-y|yMdd=dd-M-y|yMM=MM-y|yMMd=d-MM-y' +
      '|yMMdd=dd-MM-y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM y|yMMMMd=d MMM y|yMMMMdd=dd MMM y|E=E|Ed=E d' +
      '|Edd=E dd|EM=M E|EMd=E d-M|EMdd=E dd-M|EMM=E ([maand]: MM)|EMMd=E d-MM|EMMdd=E dd-MM|EMMM=MMM E|EMMMd=E d MMM' +
      '|EMMMdd=E dd MMM|EMMMM=E ([maand]: MMM)|EMMMMd=E d MMM|EMMMMdd=E dd MMM|Ey=y E|Eyd=y E d|Eydd=y E dd|EyM=M-y E' +
      '|EyMd=E d-M-y|EyMdd=E dd-M-y|EyMM=MM-y E|EyMMd=E d-MM-y|EyMMdd=E dd-MM-y|EyMMM=MMM y E|EyMMMd=E d MMM y' +
      '|EyMMMdd=E dd MMM y|EyMMMM=MMM y E|EyMMMMd=E d MMM y|EyMMMMdd=E dd MMM y|EEEE=E|EEEEd=E d|EEEEdd=E dd' +
      '|EEEEM=M E|EEEEMd=E d-M|EEEEMdd=E dd-M|EEEEMM=MM E|EEEEMMd=E d-MM|EEEEMMdd=E dd-MM|EEEEMMM=MMM E' +
      '|EEEEMMMd=E d MMM|EEEEMMMdd=E dd MMM|EEEEMMMM=MMM E|EEEEMMMMd=E d MMM|EEEEMMMMdd=E dd MMM|EEEEy=y E' +
      '|EEEEyd=y E d|EEEEydd=y E dd|EEEEyM=M-y E|EEEEyMd=E d-M-y|EEEEyMdd=E dd-M-y|EEEEyMM=MM-y E|EEEEyMMd=E d-MM-y' +
      '|EEEEyMMdd=E dd-MM-y|EEEEyMMM=MMM y E|EEEEyMMMd=E d MMM y|EEEEyMMMdd=E dd MMM y|EEEEyMMMM=MMM y E' +
      '|EEEEyMMMMd=E d MMM y|EEEEyMMMMdd=E dd MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([seconde]: s)|hss=h'#$202F'a ([seconde]: s)' +
      '|hm=h:mm a|hms=h:mm:ss a|hmss=h:mm:ss a|hmm=h:mm a|hmms=h:mm:ss a|hmmss=h:mm:ss a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([seconde]: s)|hhss=hh'#$202F'a ([seconde]: s)|hhm=hh:mm a|hhms=hh:mm:ss a|hhmss=hh:mm:ss a|hhmm=hh:mm a' +
      '|hhmms=hh:mm:ss a|hhmmss=hh:mm:ss a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH|hs=HH ([seconde]: s)|hss=HH ([seconde]: s)' +
      '|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss|hh=HH|hhs=s ([uur]: HH)' +
      '|hhss=HH ([seconde]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' om '),
  (Tag: 'nl-BE';
   DecimalSeparator: ','; GroupSeparator: '.'; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolBeforeNumberWithSpace; PercentGap: '';
   CurrencySymbols: 'EUR='#$20AC'|USD=US$|GBP='#$00A3'|JPY=JP'#$00A5'|CAD=C$|AUD=AU$|INR='#$20B9'|CNY=CN'#$00A5'|BRL=R$|MXN=MX$|KRW='#$20A9'|NZD=NZ$|HKD=HK$|ILS='#$20AA'|TWD=NT$|THB='#$0E3F'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'a.m.'; PmMarker: 'p.m.';
   MonthsLong: ('januari', 'februari', 'maart', 'april', 'mei', 'juni', 'juli', 'augustus', 'september', 'oktober', 'november', 'december');
   MonthsShort: ('jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec');
   MonthsShortStandalone: ('jan', 'feb', 'mrt', 'apr', 'mei', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag');
   WeekdaysShort: ('zo', 'ma', 'di', 'wo', 'do', 'vr', 'za');
   WeekdaysShortStandalone: ('zo', 'ma', 'di', 'wo', 'do', 'vr', 'za');
   WeekdaysNarrow: 'ZMDWDVZ';
   DatePatterns: '|d=d|dd=dd|M=M|Md=d/M|Mdd=dd/M|MM=MM|MMd=d/MM|MMdd=dd/MM|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM|MMMMd=d MMM' +
      '|MMMMdd=dd MMM|y=y|yd=y ([dag]: d)|ydd=y ([dag]: dd)|yM=M/y|yMd=d/M/y|yMdd=dd/M/y|yMM=MM/y|yMMd=d/MM/y' +
      '|yMMdd=dd/MM/y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM y|yMMMMd=d MMM y|yMMMMdd=dd MMM y|E=E|Ed=E d' +
      '|Edd=E dd|EM=M E|EMd=E d/M|EMdd=E dd/M|EMM=E ([maand]: MM)|EMMd=E d/MM|EMMdd=E dd/MM|EMMM=MMM E|EMMMd=E d MMM' +
      '|EMMMdd=E dd MMM|EMMMM=E ([maand]: MMM)|EMMMMd=E d MMM|EMMMMdd=E dd MMM|Ey=y E|Eyd=y E d|Eydd=y E dd|EyM=M/y E' +
      '|EyMd=E d/M/y|EyMdd=E dd/M/y|EyMM=MM/y E|EyMMd=E d/MM/y|EyMMdd=E dd/MM/y|EyMMM=MMM y E|EyMMMd=E d MMM y' +
      '|EyMMMdd=E dd MMM y|EyMMMM=MMM y E|EyMMMMd=E d MMM y|EyMMMMdd=E dd MMM y|EEEE=E|EEEEd=E d|EEEEdd=E dd' +
      '|EEEEM=M E|EEEEMd=E d/M|EEEEMdd=E dd/M|EEEEMM=MM E|EEEEMMd=E d/MM|EEEEMMdd=E dd/MM|EEEEMMM=MMM E' +
      '|EEEEMMMd=E d MMM|EEEEMMMdd=E dd MMM|EEEEMMMM=MMM E|EEEEMMMMd=E d MMM|EEEEMMMMdd=E dd MMM|EEEEy=y E' +
      '|EEEEyd=y E d|EEEEydd=y E dd|EEEEyM=M/y E|EEEEyMd=E d/M/y|EEEEyMdd=E dd/M/y|EEEEyMM=MM/y E|EEEEyMMd=E d/MM/y' +
      '|EEEEyMMdd=E dd/MM/y|EEEEyMMM=MMM y E|EEEEyMMMd=E d MMM y|EEEEyMMMdd=E dd MMM y|EEEEyMMMM=MMM y E' +
      '|EEEEyMMMMd=E d MMM y|EEEEyMMMMdd=E dd MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([seconde]: s)|hss=h'#$202F'a ([seconde]: s)' +
      '|hm=h:mm a|hms=h:mm:ss a|hmss=h:mm:ss a|hmm=h:mm a|hmms=h:mm:ss a|hmmss=h:mm:ss a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([seconde]: s)|hhss=hh'#$202F'a ([seconde]: s)|hhm=hh:mm a|hhms=hh:mm:ss a|hhmss=hh:mm:ss a|hhmm=hh:mm a' +
      '|hhmms=hh:mm:ss a|hhmmss=hh:mm:ss a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH|hs=HH ([seconde]: s)|hss=HH ([seconde]: s)' +
      '|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss|hh=HH|hhs=s ([uur]: HH)' +
      '|hhss=HH ([seconde]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' om '),
  (Tag: 'de-DE';
   DecimalSeparator: ','; GroupSeparator: '.'; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolAfterNumberWithSpace; PercentGap: #$00A0;
   CurrencySymbols: 'EUR='#$20AC'|USD=$|GBP='#$00A3'|JPY='#$00A5'|CAD=CA$|AUD=AU$|INR='#$20B9'|CNY=CN'#$00A5'|BRL=R$|MXN=MX$|KRW='#$20A9'|NZD=NZ$|HKD=HK$|ILS='#$20AA'|TWD=NT$|THB='#$0E3F'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'AM'; PmMarker: 'PM';
   MonthsLong: ('Januar', 'Februar', 'M'#$00E4'rz', 'April', 'Mai', 'Juni', 'Juli', 'August', 'September', 'Oktober', 'November', 'Dezember');
   MonthsShort: ('Jan.', 'Feb.', 'M'#$00E4'rz', 'Apr.', 'Mai', 'Juni', 'Juli', 'Aug.', 'Sept.', 'Okt.', 'Nov.', 'Dez.');
   MonthsShortStandalone: ('Jan', 'Feb', 'M'#$00E4'r', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('Sonntag', 'Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag');
   WeekdaysShort: ('So.', 'Mo.', 'Di.', 'Mi.', 'Do.', 'Fr.', 'Sa.');
   WeekdaysShortStandalone: ('So', 'Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa');
   WeekdaysNarrow: 'SMDMDFS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=d.M.|Mdd=dd.M.|MM=MM|MMd=d.MM.|MMdd=dd.MM.|MMM=LLL|MMMd=d. MMM|MMMdd=dd. MMM|MMMM=MMM' +
      '|MMMMd=d. MMM|MMMMdd=dd. MMM|y=y|yd=y ([Tag]: d)|ydd=y ([Tag]: dd)|yM=M/y|yMd=d.M.y|yMdd=dd.M.y|yMM=MM.y' +
      '|yMMd=d.MM.y|yMMdd=dd.MM.y|yMMM=MMM y|yMMMd=d. MMM y|yMMMdd=dd. MMM y|yMMMM=MMM y|yMMMMd=d. MMM y' +
      '|yMMMMdd=dd. MMM y|E=c|Ed=E, d.|Edd=E, dd.|EM=M c|EMd=E, d.M.|EMdd=E, dd.M.|EMM=c ([Monat]: MM)|EMMd=E, d.MM.' +
      '|EMMdd=E, dd.MM.|EMMM=LLL c|EMMMd=E, d. MMM|EMMMdd=E, dd. MMM|EMMMM=c ([Monat]: MMM)|EMMMMd=E, d. MMM' +
      '|EMMMMdd=E, dd. MMM|Ey=y c|Eyd=y E, d.|Eydd=y E, dd.|EyM=M/y c|EyMd=E, d.M.y|EyMdd=E, dd.M.y|EyMM=MM.y c' +
      '|EyMMd=E, d.MM.y|EyMMdd=E, dd.MM.y|EyMMM=MMM y c|EyMMMd=E, d. MMM y|EyMMMdd=E, dd. MMM y|EyMMMM=MMM y c' +
      '|EyMMMMd=E, d. MMM y|EyMMMMdd=E, dd. MMM y|EEEE=E|EEEEd=E, d.|EEEEdd=E, dd.|EEEEM=M E|EEEEMd=E, d.M.' +
      '|EEEEMdd=E, dd.M.|EEEEMM=MM E|EEEEMMd=E, d.MM.|EEEEMMdd=E, dd.MM.|EEEEMMM=LLL E|EEEEMMMd=E, d. MMM' +
      '|EEEEMMMdd=E, dd. MMM|EEEEMMMM=MMM E|EEEEMMMMd=E, d. MMM|EEEEMMMMdd=E, dd. MMM|EEEEy=y E|EEEEyd=y E, d.' +
      '|EEEEydd=y E, dd.|EEEEyM=M/y E|EEEEyMd=E, d.M.y|EEEEyMdd=E, dd.M.y|EEEEyMM=MM.y E|EEEEyMMd=E, d.MM.y' +
      '|EEEEyMMdd=E, dd.MM.y|EEEEyMMM=MMM y E|EEEEyMMMd=E, d. MMM y|EEEEyMMMdd=E, dd. MMM y|EEEEyMMMM=MMM y E' +
      '|EEEEyMMMMd=E, d. MMM y|EEEEyMMMMdd=E, dd. MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h [Uhr] a|hs=h [Uhr] a ([Sekunde]: s)' +
      '|hss=h [Uhr] a ([Sekunde]: s)|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a' +
      '|hh=hh [Uhr] a|hhs=hh [Uhr] a ([Sekunde]: s)|hhss=hh [Uhr] a ([Sekunde]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a' +
      '|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH [Uhr]|hs=HH [Uhr] ([Sekunde]: s)' +
      '|hss=HH [Uhr] ([Sekunde]: s)|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss' +
      '|hh=HH [Uhr]|hhs=s ([Stunde]: HH [Uhr])|hhss=HH [Uhr] ([Sekunde]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss' +
      '|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' um '),
  (Tag: 'fr-FR';
   DecimalSeparator: ','; GroupSeparator: #$202F; MinimumGroupingDigits: 1;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolAfterNumberWithSpace; PercentGap: #$00A0;
   CurrencySymbols: 'EUR='#$20AC'|USD=$US|GBP='#$00A3'GB|CAD=$CA|AUD=$AU|INR='#$20B9'|BRL=R$|MXN=$MX|KRW='#$20A9'|NZD=$NZ|SGD=$SG|ILS='#$20AA'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'AM'; PmMarker: 'PM';
   MonthsLong: ('janvier', 'f'#$00E9'vrier', 'mars', 'avril', 'mai', 'juin', 'juillet', 'ao'#$00FB't', 'septembre', 'octobre', 'novembre', 'd'#$00E9'cembre');
   MonthsShort: ('janv.', 'f'#$00E9'vr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'ao'#$00FB't', 'sept.', 'oct.', 'nov.', 'd'#$00E9'c.');
   MonthsShortStandalone: ('janv.', 'f'#$00E9'vr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'ao'#$00FB't', 'sept.', 'oct.', 'nov.', 'd'#$00E9'c.');
   MonthsNarrow: 'JFMAMJJASOND';
   WeekdaysLong: ('dimanche', 'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi');
   WeekdaysShort: ('dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.');
   WeekdaysShortStandalone: ('dim.', 'lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.');
   WeekdaysNarrow: 'DLMMJVS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=dd/MM|Mdd=dd/MM|MM=MM|MMd=dd/MM|MMdd=dd/MM|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM' +
      '|MMMMd=d MMM|MMMMdd=dd MMM|y=y|yd=y ([jour]: d)|ydd=y ([jour]: dd)|yM=MM/y|yMd=dd/MM/y|yMdd=dd/M/y|yMM=MM/y' +
      '|yMMd=d/MM/y|yMMdd=dd/MM/y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM y|yMMMMd=d MMM y' +
      '|yMMMMdd=dd MMM y|E=E|Ed=E d|Edd=E dd|EM=M E|EMd=E dd/MM|EMdd=E dd/MM|EMM=E ([mois]: MM)|EMMd=E dd/MM' +
      '|EMMdd=E dd/MM|EMMM=MMM E|EMMMd=E d MMM|EMMMdd=E dd MMM|EMMMM=E ([mois]: MMM)|EMMMMd=E d MMM|EMMMMdd=E dd MMM' +
      '|Ey=y E|Eyd=y E d|Eydd=y E dd|EyM=MM/y E|EyMd=E dd/MM/y|EyMdd=E dd/MM/y|EyMM=MM/y E|EyMMd=E dd/MM/y' +
      '|EyMMdd=E dd/MM/y|EyMMM=MMM y E|EyMMMd=E d MMM y|EyMMMdd=E dd MMM y|EyMMMM=MMM y E|EyMMMMd=E d MMM y' +
      '|EyMMMMdd=E dd MMM y|EEEE=E|EEEEd=E d|EEEEdd=E dd|EEEEM=M E|EEEEMd=E dd/MM|EEEEMdd=E dd/MM|EEEEMM=MM E' +
      '|EEEEMMd=E dd/MM|EEEEMMdd=E dd/MM|EEEEMMM=MMM E|EEEEMMMd=E d MMM|EEEEMMMdd=E dd MMM|EEEEMMMM=MMM E' +
      '|EEEEMMMMd=E d MMM|EEEEMMMMdd=E dd MMM|EEEEy=y E|EEEEyd=y E d|EEEEydd=y E dd|EEEEyM=MM/y E|EEEEyMd=E dd/MM/y' +
      '|EEEEyMdd=E dd/MM/y|EEEEyMM=MM/y E|EEEEyMMd=E dd/MM/y|EEEEyMMdd=E dd/MM/y|EEEEyMMM=MMM y E|EEEEyMMMd=E d MMM y' +
      '|EEEEyMMMdd=E dd MMM y|EEEEyMMMM=MMM y E|EEEEyMMMMd=E d MMM y|EEEEyMMMMdd=E dd MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([seconde]: s)|hss=h'#$202F'a ([seconde]: s)' +
      '|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([seconde]: s)|hhss=hh'#$202F'a ([seconde]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a' +
      '|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH [h]|hs=HH [h] ([seconde]: s)' +
      '|hss=HH [h] ([seconde]: s)|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss|hh=HH [h]' +
      '|hhs=s ([heure]: HH [h])|hhss=HH [h] ([seconde]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm' +
      '|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ' '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' '#$00E0' '),
  (Tag: 'es-ES';
   DecimalSeparator: ','; GroupSeparator: '.'; MinimumGroupingDigits: 2;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolAfterNumberWithSpace; PercentGap: #$00A0;
   CurrencySymbols: 'EUR='#$20AC'|USD=US$|THB='#$0E3F'|VND='#$20AB;
   Hour12ByDefault: False; AmMarker: 'a.'#$00A0'm.'; PmMarker: 'p.'#$00A0'm.';
   MonthsLong: ('enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre');
   MonthsShort: ('ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic');
   MonthsShortStandalone: ('ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic');
   MonthsNarrow: 'EFMAMJJASOND';
   WeekdaysLong: ('domingo', 'lunes', 'martes', 'mi'#$00E9'rcoles', 'jueves', 'viernes', 's'#$00E1'bado');
   WeekdaysShort: ('dom', 'lun', 'mar', 'mi'#$00E9, 'jue', 'vie', 's'#$00E1'b');
   WeekdaysShortStandalone: ('dom', 'lun', 'mar', 'mi'#$00E9, 'jue', 'vie', 's'#$00E1'b');
   WeekdaysNarrow: 'DLMXJVS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=d/M|Mdd=d/M|MM=MM|MMd=d/M|MMdd=d/M|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM|MMMMd=d [de] MMM' +
      '|MMMMdd=dd [de] MMM|y=y|yd=y ([d]'#$00ED'[a]: d)|ydd=y ([d]'#$00ED'[a]: dd)|yM=M/y|yMd=d/M/y|yMdd=dd/M/y|yMM=M/y|yMMd=d/MM/y' +
      '|yMMdd=dd/MM/y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM [de] y|yMMMMd=d [de] MMM [de] y' +
      '|yMMMMdd=dd [de] MMM [de] y|E=E|Ed=E d|Edd=E dd|EM=M E|EMd=E, d/M|EMdd=E, dd/M|EMM=E ([mes]: MM)|EMMd=E, d/MM' +
      '|EMMdd=E, dd/MM|EMMM=MMM E|EMMMd=E, d MMM|EMMMdd=E, dd MMM|EMMMM=E ([mes]: MMM)|EMMMMd=E, d [de] MMM' +
      '|EMMMMdd=E, dd [de] MMM|Ey=y E|Eyd=y E d|Eydd=y E dd|EyM=M/y E|EyMd=E, d/M/y|EyMdd=E, dd/M/y|EyMM=M/y E' +
      '|EyMMd=E, d/MM/y|EyMMdd=E, dd/MM/y|EyMMM=MMM y E|EyMMMd=E, d MMM y|EyMMMdd=E, dd MMM y|EyMMMM=MMM [de] y E' +
      '|EyMMMMd=E, d [de] MMM [de] y|EyMMMMdd=E, dd [de] MMM [de] y|EEEE=E|EEEEd=E d|EEEEdd=E dd|EEEEM=M E' +
      '|EEEEMd=E, d/M|EEEEMdd=E, dd/M|EEEEMM=MM E|EEEEMMd=E, d/MM|EEEEMMdd=E, dd/MM|EEEEMMM=MMM E|EEEEMMMd=E, d MMM' +
      '|EEEEMMMdd=E, dd MMM|EEEEMMMM=MMM E|EEEEMMMMd=E, d [de] MMM|EEEEMMMMdd=E, dd [de] MMM|EEEEy=y E|EEEEyd=y E d' +
      '|EEEEydd=y E dd|EEEEyM=M/y E|EEEEyMd=E, d/M/y|EEEEyMdd=E, dd/M/y|EEEEyMM=M/y E|EEEEyMMd=E, d/MM/y' +
      '|EEEEyMMdd=E, dd/MM/y|EEEEyMMM=MMM y E|EEEEyMMMd=E, d [de] MMM [de] y|EEEEyMMMdd=E, dd [de] MMM [de] y' +
      '|EEEEyMMMM=MMM [de] y E|EEEEyMMMMd=E, d [de] MMM [de] y|EEEEyMMMMdd=E, dd [de] MMM [de] y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([segundo]: s)|hss=h'#$202F'a ([segundo]: s)' +
      '|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([segundo]: s)|hhss=hh'#$202F'a ([segundo]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a' +
      '|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=H|hs=H ([segundo]: s)|hss=H ([segundo]: s)' +
      '|hm=H:mm|hms=H:mm:ss|hmss=H:mm:ss|hmm=H:mm|hmms=H:mm:ss|hmmss=H:mm:ss|hh=HH|hhs=s ([hora]: HH)' +
      '|hhss=HH ([segundo]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ', '),
  (Tag: 'it-IT';
   DecimalSeparator: ','; GroupSeparator: '.'; MinimumGroupingDigits: 2;
   MinusSign: '-'; CurrencyLayout: TJSCurrencyLayout.SymbolAfterNumberWithSpace; PercentGap: '';
   CurrencySymbols: 'EUR='#$20AC'|GBP='#$00A3'|CAD=CA$|AUD=A$|CNY=CN'#$00A5'|NZD=NZ$|ILS='#$20AA'|THB='#$0E3F'|PHP='#$20B1;
   Hour12ByDefault: False; AmMarker: 'AM'; PmMarker: 'PM';
   MonthsLong: ('gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno', 'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre');
   MonthsShort: ('gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic');
   MonthsShortStandalone: ('gen', 'feb', 'mar', 'apr', 'mag', 'giu', 'lug', 'ago', 'set', 'ott', 'nov', 'dic');
   MonthsNarrow: 'GFMAMGLASOND';
   WeekdaysLong: ('domenica', 'luned'#$00EC, 'marted'#$00EC, 'mercoled'#$00EC, 'gioved'#$00EC, 'venerd'#$00EC, 'sabato');
   WeekdaysShort: ('dom', 'lun', 'mar', 'mer', 'gio', 'ven', 'sab');
   WeekdaysShortStandalone: ('dom', 'lun', 'mar', 'mer', 'gio', 'ven', 'sab');
   WeekdaysNarrow: 'DLMMGVS';
   DatePatterns: '|d=d|dd=dd|M=M|Md=dd/MM|Mdd=dd/MM|MM=MM|MMd=dd/MM|MMdd=dd/MM|MMM=MMM|MMMd=d MMM|MMMdd=dd MMM|MMMM=MMM' +
      '|MMMMd=d MMM|MMMMdd=dd MMM|y=y|yd=y ([giorno]: d)|ydd=y ([giorno]: dd)|yM=MM/y|yMd=dd/MM/y|yMdd=dd/MM/y' +
      '|yMM=MM/y|yMMd=dd/MM/y|yMMdd=dd/MM/y|yMMM=MMM y|yMMMd=d MMM y|yMMMdd=dd MMM y|yMMMM=MMM y|yMMMMd=d MMM y' +
      '|yMMMMdd=dd MMM y|E=E|Ed=E d|Edd=E dd|EM=M E|EMd=E dd/MM|EMdd=E dd/MM|EMM=E ([mese]: MM)|EMMd=E dd/MM' +
      '|EMMdd=E dd/MM|EMMM=MMM E|EMMMd=E d MMM|EMMMdd=E dd MMM|EMMMM=E ([mese]: MMM)|EMMMMd=E d MMM|EMMMMdd=E dd MMM' +
      '|Ey=y E|Eyd=y E d|Eydd=y E dd|EyM=MM/y E|EyMd=E dd/MM/y|EyMdd=E dd/MM/y|EyMM=MM/y E|EyMMd=E dd/MM/y' +
      '|EyMMdd=E dd/MM/y|EyMMM=MMM y E|EyMMMd=E d MMM y|EyMMMdd=E dd MMM y|EyMMMM=MMM y E|EyMMMMd=E d MMM y' +
      '|EyMMMMdd=E dd MMM y|EEEE=E|EEEEd=E d|EEEEdd=E dd|EEEEM=M E|EEEEMd=E dd/MM|EEEEMdd=E dd/MM|EEEEMM=MM E' +
      '|EEEEMMd=E dd/MM|EEEEMMdd=E dd/MM|EEEEMMM=MMM E|EEEEMMMd=E d MMM|EEEEMMMdd=E dd MMM|EEEEMMMM=MMM E' +
      '|EEEEMMMMd=E d MMM|EEEEMMMMdd=E dd MMM|EEEEy=y E|EEEEyd=y E d|EEEEydd=y E dd|EEEEyM=MM/y E|EEEEyMd=E dd/MM/y' +
      '|EEEEyMdd=E dd/MM/y|EEEEyMM=MM/y E|EEEEyMMd=E dd/MM/y|EEEEyMMdd=E dd/MM/y|EEEEyMMM=MMM y E|EEEEyMMMd=E d MMM y' +
      '|EEEEyMMMdd=E dd MMM y|EEEEyMMMM=MMM y E|EEEEyMMMMd=E d MMM y|EEEEyMMMMdd=E dd MMM y|';
   TimePatterns12: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=h'#$202F'a|hs=h'#$202F'a ([secondo]: s)|hss=h'#$202F'a ([secondo]: s)' +
      '|hm=h:mm'#$202F'a|hms=h:mm:ss'#$202F'a|hmss=h:mm:ss'#$202F'a|hmm=h:mm'#$202F'a|hmms=h:mm:ss'#$202F'a|hmmss=h:mm:ss'#$202F'a|hh=hh'#$202F'a' +
      '|hhs=hh'#$202F'a ([secondo]: s)|hhss=hh'#$202F'a ([secondo]: s)|hhm=hh:mm'#$202F'a|hhms=hh:mm:ss'#$202F'a|hhmss=hh:mm:ss'#$202F'a|hhmm=hh:mm'#$202F'a' +
      '|hhmms=hh:mm:ss'#$202F'a|hhmmss=hh:mm:ss'#$202F'a|';
   TimePatterns24: '|s=s|ss=s|m=m|ms=mm:ss|mss=mm:ss|mm=m|mms=mm:ss|mmss=mm:ss|h=HH|hs=HH ([secondo]: s)|hss=HH ([secondo]: s)' +
      '|hm=HH:mm|hms=HH:mm:ss|hmss=HH:mm:ss|hmm=H:mm|hmms=HH:mm:ss|hmmss=H:mm:ss|hh=HH|hhs=s ([ora]: HH)' +
      '|hhss=HH ([secondo]: s)|hhm=HH:mm|hhms=HH:mm:ss|hhmss=HH:mm:ss|hhmm=HH:mm|hhmms=HH:mm:ss|hhmmss=HH:mm:ss|';
   DateTimeGlueNumeric: ', '; DateTimeGlueShort: ', '; DateTimeGlueLong: ' alle ore ')
  );

class function TJSBuiltInLocaleTable.StripExtensions(const Requested: string): string;
begin
  const ExtensionStart = Requested.IndexOf(EXTENSION_MARKER);
  const HasExtension = (ExtensionStart >= 0);
  if not HasExtension then
    Exit(Requested);

  Result := Requested.Substring(0, ExtensionStart);
end;

class function TJSBuiltInLocaleTable.ExpandLanguage(const Requested: string): string;
begin
  Result := Requested;

  const IsLanguageOnly = (Requested.IndexOf(TAG_SEPARATOR) < 0);
  if not IsLanguageOnly then
    Exit;

  for var Index := Low(LANGUAGE_DEFAULTS) to High(LANGUAGE_DEFAULTS) do
  begin
    const IsRequestedLanguage = SameText(Requested, LANGUAGE_DEFAULTS[Index, 0]);
    if IsRequestedLanguage then
      Exit(LANGUAGE_DEFAULTS[Index, 1]);
  end;
end;

class function TJSBuiltInLocaleTable.TryFindExact(const Tag: string; out Locale: TJSLocaleDefinition): Boolean;
begin
  for var Index := Low(BUILT_IN_LOCALES) to High(BUILT_IN_LOCALES) do
  begin
    const IsRequestedTag = SameText(Tag, BUILT_IN_LOCALES[Index].Tag);
    if IsRequestedTag then
    begin
      Locale := BUILT_IN_LOCALES[Index];
      Exit(True);
    end;
  end;

  Result := False;
end;

class function TJSBuiltInLocaleTable.TryFind(const Requested: string; out Locale: TJSLocaleDefinition): Boolean;
begin
  const WithoutExtensions = StripExtensions(Requested);
  const Tag = ExpandLanguage(WithoutExtensions);

  Result := TryFindExact(Tag, Locale);
end;

class function TJSBuiltInLocaleTable.FindDefault: TJSLocaleDefinition;
begin
  const IsFound = TryFindExact(DEFAULT_TAG, Result);
  if not IsFound then
    raise ENotSupportedException.CreateFmt('Default locale %s is missing', [DEFAULT_TAG]);
end;

class function TJSBuiltInLocaleTable.FindPattern(const Patterns: string; const Key: string; out Pattern: string): Boolean;
begin
  const Marker = PATTERN_SEPARATOR + Key + PATTERN_ASSIGN;
  const MarkerStart = Patterns.IndexOf(Marker);
  const IsFound = (MarkerStart >= 0);
  if not IsFound then
    Exit(False);

  const PatternStart = MarkerStart + Marker.Length;
  const PatternEnd = Patterns.IndexOf(PATTERN_SEPARATOR, PatternStart);

  Pattern := Patterns.Substring(PatternStart, PatternEnd - PatternStart);
  Result := True;
end;

class function TJSBuiltInLocaleTable.FindCurrencySymbol(const Locale: TJSLocaleDefinition; const Currency: string): string;
begin
  Result := Currency;

  const Entries = Locale.CurrencySymbols.Split([PATTERN_SEPARATOR]);
  for var Entry in Entries do
  begin
    const AssignPosition = Entry.IndexOf(SYMBOL_ASSIGN);
    const EntryCode = Entry.Substring(0, AssignPosition);
    const IsRequestedCurrency = (EntryCode = Currency);
    if IsRequestedCurrency then
    begin
      Result := Entry.Substring(AssignPosition + 1);
      Exit;
    end;
  end;
end;

end.
