unit JS4D.CaseMapping;

{$SCOPEDENUMS ON}

interface

type
  TJSCaseMapping = class
  private
    const
      ASCII_LIMIT = 128;
      LAST_SPECIAL_UPPER_INDEX = 101;
      LATIN_CAPITAL_I_WITH_DOT_ABOVE = $0130;
      COMBINING_DOT_ABOVE = $0307;
      GREEK_CAPITAL_SIGMA = $03A3;
      GREEK_SMALL_SIGMA = $03C3;
      GREEK_SMALL_FINAL_SIGMA = $03C2;
      CASE_IGNORABLE_PUNCTUATION: array[0..16] of Integer =
        ($0027, $002E, $003A, $00B7, $0387, $055F, $05F4, $2018, $2019,
         $2024, $2027, $FE13, $FE52, $FE55, $FF07, $FF0E, $FF1A);

    type
      TCaseRange = record
        First: Integer;
        Last: Integer;
        Stride: Integer;
        Delta: Integer;
      end;

    class function IsAscii(const Text: string): Boolean; static;
    class function CodePointAt(const Text: string; const Index: Integer; out Width: Integer): Integer; static;
    class function CodePointBefore(const Text: string; const Index: Integer; out Width: Integer): Integer; static;
    class function IsCased(const Code: Integer): Boolean; static;
    class function IsCaseIgnorable(const Code: Integer): Boolean; static;
    class function SimpleMapping(const Ranges: array of TCaseRange; const Code: Integer): Integer; static;
    class function FindSpecialUpper(const Code: Integer; out Text: string): Boolean; static;
    class function IsFinalSigma(const Text: string; const SigmaIndex: Integer): Boolean; static;
    class function CasedPrecedes(const Text: string; const SigmaIndex: Integer): Boolean; static;
    class function CasedFollows(const Text: string; const AfterSigmaIndex: Integer): Boolean; static;
    class function LowerCodePoint(const Text: string; const Index, Code: Integer): string; static;
    class function CodePointToString(const Code: Integer): string; static;

  public
    class function ToUpper(const Text: string): string; static;
    class function ToLower(const Text: string): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

type
  TSpecialUpper = record
    Code: Integer;
    Text: string;
  end;

const
  SPECIAL_UPPER_MAPPINGS: array[0..101] of TSpecialUpper = (
    (Code: $00DF; Text: #$0053#$0053),
    (Code: $0149; Text: #$02BC#$004E),
    (Code: $01F0; Text: #$004A#$030C),
    (Code: $0390; Text: #$0399#$0308#$0301),
    (Code: $03B0; Text: #$03A5#$0308#$0301),
    (Code: $0587; Text: #$0535#$0552),
    (Code: $1E96; Text: #$0048#$0331),
    (Code: $1E97; Text: #$0054#$0308),
    (Code: $1E98; Text: #$0057#$030A),
    (Code: $1E99; Text: #$0059#$030A),
    (Code: $1E9A; Text: #$0041#$02BE),
    (Code: $1F50; Text: #$03A5#$0313),
    (Code: $1F52; Text: #$03A5#$0313#$0300),
    (Code: $1F54; Text: #$03A5#$0313#$0301),
    (Code: $1F56; Text: #$03A5#$0313#$0342),
    (Code: $1F80; Text: #$1F08#$0399),
    (Code: $1F81; Text: #$1F09#$0399),
    (Code: $1F82; Text: #$1F0A#$0399),
    (Code: $1F83; Text: #$1F0B#$0399),
    (Code: $1F84; Text: #$1F0C#$0399),
    (Code: $1F85; Text: #$1F0D#$0399),
    (Code: $1F86; Text: #$1F0E#$0399),
    (Code: $1F87; Text: #$1F0F#$0399),
    (Code: $1F88; Text: #$1F08#$0399),
    (Code: $1F89; Text: #$1F09#$0399),
    (Code: $1F8A; Text: #$1F0A#$0399),
    (Code: $1F8B; Text: #$1F0B#$0399),
    (Code: $1F8C; Text: #$1F0C#$0399),
    (Code: $1F8D; Text: #$1F0D#$0399),
    (Code: $1F8E; Text: #$1F0E#$0399),
    (Code: $1F8F; Text: #$1F0F#$0399),
    (Code: $1F90; Text: #$1F28#$0399),
    (Code: $1F91; Text: #$1F29#$0399),
    (Code: $1F92; Text: #$1F2A#$0399),
    (Code: $1F93; Text: #$1F2B#$0399),
    (Code: $1F94; Text: #$1F2C#$0399),
    (Code: $1F95; Text: #$1F2D#$0399),
    (Code: $1F96; Text: #$1F2E#$0399),
    (Code: $1F97; Text: #$1F2F#$0399),
    (Code: $1F98; Text: #$1F28#$0399),
    (Code: $1F99; Text: #$1F29#$0399),
    (Code: $1F9A; Text: #$1F2A#$0399),
    (Code: $1F9B; Text: #$1F2B#$0399),
    (Code: $1F9C; Text: #$1F2C#$0399),
    (Code: $1F9D; Text: #$1F2D#$0399),
    (Code: $1F9E; Text: #$1F2E#$0399),
    (Code: $1F9F; Text: #$1F2F#$0399),
    (Code: $1FA0; Text: #$1F68#$0399),
    (Code: $1FA1; Text: #$1F69#$0399),
    (Code: $1FA2; Text: #$1F6A#$0399),
    (Code: $1FA3; Text: #$1F6B#$0399),
    (Code: $1FA4; Text: #$1F6C#$0399),
    (Code: $1FA5; Text: #$1F6D#$0399),
    (Code: $1FA6; Text: #$1F6E#$0399),
    (Code: $1FA7; Text: #$1F6F#$0399),
    (Code: $1FA8; Text: #$1F68#$0399),
    (Code: $1FA9; Text: #$1F69#$0399),
    (Code: $1FAA; Text: #$1F6A#$0399),
    (Code: $1FAB; Text: #$1F6B#$0399),
    (Code: $1FAC; Text: #$1F6C#$0399),
    (Code: $1FAD; Text: #$1F6D#$0399),
    (Code: $1FAE; Text: #$1F6E#$0399),
    (Code: $1FAF; Text: #$1F6F#$0399),
    (Code: $1FB2; Text: #$1FBA#$0399),
    (Code: $1FB3; Text: #$0391#$0399),
    (Code: $1FB4; Text: #$0386#$0399),
    (Code: $1FB6; Text: #$0391#$0342),
    (Code: $1FB7; Text: #$0391#$0342#$0399),
    (Code: $1FBC; Text: #$0391#$0399),
    (Code: $1FC2; Text: #$1FCA#$0399),
    (Code: $1FC3; Text: #$0397#$0399),
    (Code: $1FC4; Text: #$0389#$0399),
    (Code: $1FC6; Text: #$0397#$0342),
    (Code: $1FC7; Text: #$0397#$0342#$0399),
    (Code: $1FCC; Text: #$0397#$0399),
    (Code: $1FD2; Text: #$0399#$0308#$0300),
    (Code: $1FD3; Text: #$0399#$0308#$0301),
    (Code: $1FD6; Text: #$0399#$0342),
    (Code: $1FD7; Text: #$0399#$0308#$0342),
    (Code: $1FE2; Text: #$03A5#$0308#$0300),
    (Code: $1FE3; Text: #$03A5#$0308#$0301),
    (Code: $1FE4; Text: #$03A1#$0313),
    (Code: $1FE6; Text: #$03A5#$0342),
    (Code: $1FE7; Text: #$03A5#$0308#$0342),
    (Code: $1FF2; Text: #$1FFA#$0399),
    (Code: $1FF3; Text: #$03A9#$0399),
    (Code: $1FF4; Text: #$038F#$0399),
    (Code: $1FF6; Text: #$03A9#$0342),
    (Code: $1FF7; Text: #$03A9#$0342#$0399),
    (Code: $1FFC; Text: #$03A9#$0399),
    (Code: $FB00; Text: #$0046#$0046),
    (Code: $FB01; Text: #$0046#$0049),
    (Code: $FB02; Text: #$0046#$004C),
    (Code: $FB03; Text: #$0046#$0046#$0049),
    (Code: $FB04; Text: #$0046#$0046#$004C),
    (Code: $FB05; Text: #$0053#$0054),
    (Code: $FB06; Text: #$0053#$0054),
    (Code: $FB13; Text: #$0544#$0546),
    (Code: $FB14; Text: #$0544#$0535),
    (Code: $FB15; Text: #$0544#$053B),
    (Code: $FB16; Text: #$054E#$0546),
    (Code: $FB17; Text: #$0544#$053D)
  );

SIMPLE_UPPER_RANGES: array[0..193] of TJSCaseMapping.TCaseRange = (
  (First: $0061; Last: $007A; Stride: 1; Delta: -32),
  (First: $00B5; Last: $00B5; Stride: 1; Delta: 743),
  (First: $00E0; Last: $00F6; Stride: 1; Delta: -32),
  (First: $00F8; Last: $00FE; Stride: 1; Delta: -32),
  (First: $00FF; Last: $00FF; Stride: 1; Delta: 121),
  (First: $0101; Last: $012F; Stride: 2; Delta: -1),
  (First: $0131; Last: $0131; Stride: 1; Delta: -232),
  (First: $0133; Last: $0137; Stride: 2; Delta: -1),
  (First: $013A; Last: $0148; Stride: 2; Delta: -1),
  (First: $014B; Last: $0177; Stride: 2; Delta: -1),
  (First: $017A; Last: $017E; Stride: 2; Delta: -1),
  (First: $017F; Last: $017F; Stride: 1; Delta: -300),
  (First: $0180; Last: $0180; Stride: 1; Delta: 195),
  (First: $0183; Last: $0185; Stride: 2; Delta: -1),
  (First: $0188; Last: $0188; Stride: 1; Delta: -1),
  (First: $018C; Last: $018C; Stride: 1; Delta: -1),
  (First: $0192; Last: $0192; Stride: 1; Delta: -1),
  (First: $0195; Last: $0195; Stride: 1; Delta: 97),
  (First: $0199; Last: $0199; Stride: 1; Delta: -1),
  (First: $019A; Last: $019A; Stride: 1; Delta: 163),
  (First: $019E; Last: $019E; Stride: 1; Delta: 130),
  (First: $01A1; Last: $01A5; Stride: 2; Delta: -1),
  (First: $01A8; Last: $01A8; Stride: 1; Delta: -1),
  (First: $01AD; Last: $01AD; Stride: 1; Delta: -1),
  (First: $01B0; Last: $01B0; Stride: 1; Delta: -1),
  (First: $01B4; Last: $01B6; Stride: 2; Delta: -1),
  (First: $01B9; Last: $01B9; Stride: 1; Delta: -1),
  (First: $01BD; Last: $01BD; Stride: 1; Delta: -1),
  (First: $01BF; Last: $01BF; Stride: 1; Delta: 56),
  (First: $01C5; Last: $01C5; Stride: 1; Delta: -1),
  (First: $01C6; Last: $01C6; Stride: 1; Delta: -2),
  (First: $01C8; Last: $01C8; Stride: 1; Delta: -1),
  (First: $01C9; Last: $01C9; Stride: 1; Delta: -2),
  (First: $01CB; Last: $01CB; Stride: 1; Delta: -1),
  (First: $01CC; Last: $01CC; Stride: 1; Delta: -2),
  (First: $01CE; Last: $01DC; Stride: 2; Delta: -1),
  (First: $01DD; Last: $01DD; Stride: 1; Delta: -79),
  (First: $01DF; Last: $01EF; Stride: 2; Delta: -1),
  (First: $01F2; Last: $01F2; Stride: 1; Delta: -1),
  (First: $01F3; Last: $01F3; Stride: 1; Delta: -2),
  (First: $01F5; Last: $01F5; Stride: 1; Delta: -1),
  (First: $01F9; Last: $021F; Stride: 2; Delta: -1),
  (First: $0223; Last: $0233; Stride: 2; Delta: -1),
  (First: $023C; Last: $023C; Stride: 1; Delta: -1),
  (First: $023F; Last: $0240; Stride: 1; Delta: 10815),
  (First: $0242; Last: $0242; Stride: 1; Delta: -1),
  (First: $0247; Last: $024F; Stride: 2; Delta: -1),
  (First: $0250; Last: $0250; Stride: 1; Delta: 10783),
  (First: $0251; Last: $0251; Stride: 1; Delta: 10780),
  (First: $0252; Last: $0252; Stride: 1; Delta: 10782),
  (First: $0253; Last: $0253; Stride: 1; Delta: -210),
  (First: $0254; Last: $0254; Stride: 1; Delta: -206),
  (First: $0256; Last: $0257; Stride: 1; Delta: -205),
  (First: $0259; Last: $0259; Stride: 1; Delta: -202),
  (First: $025B; Last: $025B; Stride: 1; Delta: -203),
  (First: $025C; Last: $025C; Stride: 1; Delta: 42319),
  (First: $0260; Last: $0260; Stride: 1; Delta: -205),
  (First: $0261; Last: $0261; Stride: 1; Delta: 42315),
  (First: $0263; Last: $0263; Stride: 1; Delta: -207),
  (First: $0265; Last: $0265; Stride: 1; Delta: 42280),
  (First: $0266; Last: $0266; Stride: 1; Delta: 42308),
  (First: $0268; Last: $0268; Stride: 1; Delta: -209),
  (First: $0269; Last: $0269; Stride: 1; Delta: -211),
  (First: $026A; Last: $026A; Stride: 1; Delta: 42308),
  (First: $026B; Last: $026B; Stride: 1; Delta: 10743),
  (First: $026C; Last: $026C; Stride: 1; Delta: 42305),
  (First: $026F; Last: $026F; Stride: 1; Delta: -211),
  (First: $0271; Last: $0271; Stride: 1; Delta: 10749),
  (First: $0272; Last: $0272; Stride: 1; Delta: -213),
  (First: $0275; Last: $0275; Stride: 1; Delta: -214),
  (First: $027D; Last: $027D; Stride: 1; Delta: 10727),
  (First: $0280; Last: $0280; Stride: 1; Delta: -218),
  (First: $0282; Last: $0282; Stride: 1; Delta: 42307),
  (First: $0283; Last: $0283; Stride: 1; Delta: -218),
  (First: $0287; Last: $0287; Stride: 1; Delta: 42282),
  (First: $0288; Last: $0288; Stride: 1; Delta: -218),
  (First: $0289; Last: $0289; Stride: 1; Delta: -69),
  (First: $028A; Last: $028B; Stride: 1; Delta: -217),
  (First: $028C; Last: $028C; Stride: 1; Delta: -71),
  (First: $0292; Last: $0292; Stride: 1; Delta: -219),
  (First: $029D; Last: $029D; Stride: 1; Delta: 42261),
  (First: $029E; Last: $029E; Stride: 1; Delta: 42258),
  (First: $0345; Last: $0345; Stride: 1; Delta: 84),
  (First: $0371; Last: $0373; Stride: 2; Delta: -1),
  (First: $0377; Last: $0377; Stride: 1; Delta: -1),
  (First: $037B; Last: $037D; Stride: 1; Delta: 130),
  (First: $03AC; Last: $03AC; Stride: 1; Delta: -38),
  (First: $03AD; Last: $03AF; Stride: 1; Delta: -37),
  (First: $03B1; Last: $03C1; Stride: 1; Delta: -32),
  (First: $03C2; Last: $03C2; Stride: 1; Delta: -31),
  (First: $03C3; Last: $03CB; Stride: 1; Delta: -32),
  (First: $03CC; Last: $03CC; Stride: 1; Delta: -64),
  (First: $03CD; Last: $03CE; Stride: 1; Delta: -63),
  (First: $03D0; Last: $03D0; Stride: 1; Delta: -62),
  (First: $03D1; Last: $03D1; Stride: 1; Delta: -57),
  (First: $03D5; Last: $03D5; Stride: 1; Delta: -47),
  (First: $03D6; Last: $03D6; Stride: 1; Delta: -54),
  (First: $03D7; Last: $03D7; Stride: 1; Delta: -8),
  (First: $03D9; Last: $03EF; Stride: 2; Delta: -1),
  (First: $03F0; Last: $03F0; Stride: 1; Delta: -86),
  (First: $03F1; Last: $03F1; Stride: 1; Delta: -80),
  (First: $03F2; Last: $03F2; Stride: 1; Delta: 7),
  (First: $03F3; Last: $03F3; Stride: 1; Delta: -116),
  (First: $03F5; Last: $03F5; Stride: 1; Delta: -96),
  (First: $03F8; Last: $03F8; Stride: 1; Delta: -1),
  (First: $03FB; Last: $03FB; Stride: 1; Delta: -1),
  (First: $0430; Last: $044F; Stride: 1; Delta: -32),
  (First: $0450; Last: $045F; Stride: 1; Delta: -80),
  (First: $0461; Last: $0481; Stride: 2; Delta: -1),
  (First: $048B; Last: $04BF; Stride: 2; Delta: -1),
  (First: $04C2; Last: $04CE; Stride: 2; Delta: -1),
  (First: $04CF; Last: $04CF; Stride: 1; Delta: -15),
  (First: $04D1; Last: $052F; Stride: 2; Delta: -1),
  (First: $0561; Last: $0586; Stride: 1; Delta: -48),
  (First: $10D0; Last: $10FA; Stride: 1; Delta: 3008),
  (First: $10FD; Last: $10FF; Stride: 1; Delta: 3008),
  (First: $13F8; Last: $13FD; Stride: 1; Delta: -8),
  (First: $1C80; Last: $1C80; Stride: 1; Delta: -6254),
  (First: $1C81; Last: $1C81; Stride: 1; Delta: -6253),
  (First: $1C82; Last: $1C82; Stride: 1; Delta: -6244),
  (First: $1C83; Last: $1C84; Stride: 1; Delta: -6242),
  (First: $1C85; Last: $1C85; Stride: 1; Delta: -6243),
  (First: $1C86; Last: $1C86; Stride: 1; Delta: -6236),
  (First: $1C87; Last: $1C87; Stride: 1; Delta: -6181),
  (First: $1C88; Last: $1C88; Stride: 1; Delta: 35266),
  (First: $1D79; Last: $1D79; Stride: 1; Delta: 35332),
  (First: $1D7D; Last: $1D7D; Stride: 1; Delta: 3814),
  (First: $1D8E; Last: $1D8E; Stride: 1; Delta: 35384),
  (First: $1E01; Last: $1E95; Stride: 2; Delta: -1),
  (First: $1E9B; Last: $1E9B; Stride: 1; Delta: -59),
  (First: $1EA1; Last: $1EFF; Stride: 2; Delta: -1),
  (First: $1F00; Last: $1F07; Stride: 1; Delta: 8),
  (First: $1F10; Last: $1F15; Stride: 1; Delta: 8),
  (First: $1F20; Last: $1F27; Stride: 1; Delta: 8),
  (First: $1F30; Last: $1F37; Stride: 1; Delta: 8),
  (First: $1F40; Last: $1F45; Stride: 1; Delta: 8),
  (First: $1F51; Last: $1F57; Stride: 2; Delta: 8),
  (First: $1F60; Last: $1F67; Stride: 1; Delta: 8),
  (First: $1F70; Last: $1F71; Stride: 1; Delta: 74),
  (First: $1F72; Last: $1F75; Stride: 1; Delta: 86),
  (First: $1F76; Last: $1F77; Stride: 1; Delta: 100),
  (First: $1F78; Last: $1F79; Stride: 1; Delta: 128),
  (First: $1F7A; Last: $1F7B; Stride: 1; Delta: 112),
  (First: $1F7C; Last: $1F7D; Stride: 1; Delta: 126),
  (First: $1FB0; Last: $1FB1; Stride: 1; Delta: 8),
  (First: $1FBE; Last: $1FBE; Stride: 1; Delta: -7205),
  (First: $1FD0; Last: $1FD1; Stride: 1; Delta: 8),
  (First: $1FE0; Last: $1FE1; Stride: 1; Delta: 8),
  (First: $1FE5; Last: $1FE5; Stride: 1; Delta: 7),
  (First: $214E; Last: $214E; Stride: 1; Delta: -28),
  (First: $2170; Last: $217F; Stride: 1; Delta: -16),
  (First: $2184; Last: $2184; Stride: 1; Delta: -1),
  (First: $24D0; Last: $24E9; Stride: 1; Delta: -26),
  (First: $2C30; Last: $2C5F; Stride: 1; Delta: -48),
  (First: $2C61; Last: $2C61; Stride: 1; Delta: -1),
  (First: $2C65; Last: $2C65; Stride: 1; Delta: -10795),
  (First: $2C66; Last: $2C66; Stride: 1; Delta: -10792),
  (First: $2C68; Last: $2C6C; Stride: 2; Delta: -1),
  (First: $2C73; Last: $2C73; Stride: 1; Delta: -1),
  (First: $2C76; Last: $2C76; Stride: 1; Delta: -1),
  (First: $2C81; Last: $2CE3; Stride: 2; Delta: -1),
  (First: $2CEC; Last: $2CEE; Stride: 2; Delta: -1),
  (First: $2CF3; Last: $2CF3; Stride: 1; Delta: -1),
  (First: $2D00; Last: $2D25; Stride: 1; Delta: -7264),
  (First: $2D27; Last: $2D27; Stride: 1; Delta: -7264),
  (First: $2D2D; Last: $2D2D; Stride: 1; Delta: -7264),
  (First: $A641; Last: $A66D; Stride: 2; Delta: -1),
  (First: $A681; Last: $A69B; Stride: 2; Delta: -1),
  (First: $A723; Last: $A72F; Stride: 2; Delta: -1),
  (First: $A733; Last: $A76F; Stride: 2; Delta: -1),
  (First: $A77A; Last: $A77C; Stride: 2; Delta: -1),
  (First: $A77F; Last: $A787; Stride: 2; Delta: -1),
  (First: $A78C; Last: $A78C; Stride: 1; Delta: -1),
  (First: $A791; Last: $A793; Stride: 2; Delta: -1),
  (First: $A794; Last: $A794; Stride: 1; Delta: 48),
  (First: $A797; Last: $A7A9; Stride: 2; Delta: -1),
  (First: $A7B5; Last: $A7C3; Stride: 2; Delta: -1),
  (First: $A7C8; Last: $A7CA; Stride: 2; Delta: -1),
  (First: $A7D1; Last: $A7D1; Stride: 1; Delta: -1),
  (First: $A7D7; Last: $A7D9; Stride: 2; Delta: -1),
  (First: $A7F6; Last: $A7F6; Stride: 1; Delta: -1),
  (First: $AB53; Last: $AB53; Stride: 1; Delta: -928),
  (First: $AB70; Last: $ABBF; Stride: 1; Delta: -38864),
  (First: $FF41; Last: $FF5A; Stride: 1; Delta: -32),
  (First: $10428; Last: $1044F; Stride: 1; Delta: -40),
  (First: $104D8; Last: $104FB; Stride: 1; Delta: -40),
  (First: $10597; Last: $105A1; Stride: 1; Delta: -39),
  (First: $105A3; Last: $105B1; Stride: 1; Delta: -39),
  (First: $105B3; Last: $105B9; Stride: 1; Delta: -39),
  (First: $105BB; Last: $105BC; Stride: 1; Delta: -39),
  (First: $10CC0; Last: $10CF2; Stride: 1; Delta: -64),
  (First: $118C0; Last: $118DF; Stride: 1; Delta: -32),
  (First: $16E60; Last: $16E7F; Stride: 1; Delta: -32),
  (First: $1E922; Last: $1E943; Stride: 1; Delta: -34)
);

SIMPLE_LOWER_RANGES: array[0..180] of TJSCaseMapping.TCaseRange = (
  (First: $0041; Last: $005A; Stride: 1; Delta: 32),
  (First: $00C0; Last: $00D6; Stride: 1; Delta: 32),
  (First: $00D8; Last: $00DE; Stride: 1; Delta: 32),
  (First: $0100; Last: $012E; Stride: 2; Delta: 1),
  (First: $0132; Last: $0136; Stride: 2; Delta: 1),
  (First: $0139; Last: $0147; Stride: 2; Delta: 1),
  (First: $014A; Last: $0176; Stride: 2; Delta: 1),
  (First: $0178; Last: $0178; Stride: 1; Delta: -121),
  (First: $0179; Last: $017D; Stride: 2; Delta: 1),
  (First: $0181; Last: $0181; Stride: 1; Delta: 210),
  (First: $0182; Last: $0184; Stride: 2; Delta: 1),
  (First: $0186; Last: $0186; Stride: 1; Delta: 206),
  (First: $0187; Last: $0187; Stride: 1; Delta: 1),
  (First: $0189; Last: $018A; Stride: 1; Delta: 205),
  (First: $018B; Last: $018B; Stride: 1; Delta: 1),
  (First: $018E; Last: $018E; Stride: 1; Delta: 79),
  (First: $018F; Last: $018F; Stride: 1; Delta: 202),
  (First: $0190; Last: $0190; Stride: 1; Delta: 203),
  (First: $0191; Last: $0191; Stride: 1; Delta: 1),
  (First: $0193; Last: $0193; Stride: 1; Delta: 205),
  (First: $0194; Last: $0194; Stride: 1; Delta: 207),
  (First: $0196; Last: $0196; Stride: 1; Delta: 211),
  (First: $0197; Last: $0197; Stride: 1; Delta: 209),
  (First: $0198; Last: $0198; Stride: 1; Delta: 1),
  (First: $019C; Last: $019C; Stride: 1; Delta: 211),
  (First: $019D; Last: $019D; Stride: 1; Delta: 213),
  (First: $019F; Last: $019F; Stride: 1; Delta: 214),
  (First: $01A0; Last: $01A4; Stride: 2; Delta: 1),
  (First: $01A6; Last: $01A6; Stride: 1; Delta: 218),
  (First: $01A7; Last: $01A7; Stride: 1; Delta: 1),
  (First: $01A9; Last: $01A9; Stride: 1; Delta: 218),
  (First: $01AC; Last: $01AC; Stride: 1; Delta: 1),
  (First: $01AE; Last: $01AE; Stride: 1; Delta: 218),
  (First: $01AF; Last: $01AF; Stride: 1; Delta: 1),
  (First: $01B1; Last: $01B2; Stride: 1; Delta: 217),
  (First: $01B3; Last: $01B5; Stride: 2; Delta: 1),
  (First: $01B7; Last: $01B7; Stride: 1; Delta: 219),
  (First: $01B8; Last: $01B8; Stride: 1; Delta: 1),
  (First: $01BC; Last: $01BC; Stride: 1; Delta: 1),
  (First: $01C4; Last: $01C4; Stride: 1; Delta: 2),
  (First: $01C5; Last: $01C5; Stride: 1; Delta: 1),
  (First: $01C7; Last: $01C7; Stride: 1; Delta: 2),
  (First: $01C8; Last: $01C8; Stride: 1; Delta: 1),
  (First: $01CA; Last: $01CA; Stride: 1; Delta: 2),
  (First: $01CB; Last: $01DB; Stride: 2; Delta: 1),
  (First: $01DE; Last: $01EE; Stride: 2; Delta: 1),
  (First: $01F1; Last: $01F1; Stride: 1; Delta: 2),
  (First: $01F2; Last: $01F4; Stride: 2; Delta: 1),
  (First: $01F6; Last: $01F6; Stride: 1; Delta: -97),
  (First: $01F7; Last: $01F7; Stride: 1; Delta: -56),
  (First: $01F8; Last: $021E; Stride: 2; Delta: 1),
  (First: $0220; Last: $0220; Stride: 1; Delta: -130),
  (First: $0222; Last: $0232; Stride: 2; Delta: 1),
  (First: $023A; Last: $023A; Stride: 1; Delta: 10795),
  (First: $023B; Last: $023B; Stride: 1; Delta: 1),
  (First: $023D; Last: $023D; Stride: 1; Delta: -163),
  (First: $023E; Last: $023E; Stride: 1; Delta: 10792),
  (First: $0241; Last: $0241; Stride: 1; Delta: 1),
  (First: $0243; Last: $0243; Stride: 1; Delta: -195),
  (First: $0244; Last: $0244; Stride: 1; Delta: 69),
  (First: $0245; Last: $0245; Stride: 1; Delta: 71),
  (First: $0246; Last: $024E; Stride: 2; Delta: 1),
  (First: $0370; Last: $0372; Stride: 2; Delta: 1),
  (First: $0376; Last: $0376; Stride: 1; Delta: 1),
  (First: $037F; Last: $037F; Stride: 1; Delta: 116),
  (First: $0386; Last: $0386; Stride: 1; Delta: 38),
  (First: $0388; Last: $038A; Stride: 1; Delta: 37),
  (First: $038C; Last: $038C; Stride: 1; Delta: 64),
  (First: $038E; Last: $038F; Stride: 1; Delta: 63),
  (First: $0391; Last: $03A1; Stride: 1; Delta: 32),
  (First: $03A3; Last: $03AB; Stride: 1; Delta: 32),
  (First: $03CF; Last: $03CF; Stride: 1; Delta: 8),
  (First: $03D8; Last: $03EE; Stride: 2; Delta: 1),
  (First: $03F4; Last: $03F4; Stride: 1; Delta: -60),
  (First: $03F7; Last: $03F7; Stride: 1; Delta: 1),
  (First: $03F9; Last: $03F9; Stride: 1; Delta: -7),
  (First: $03FA; Last: $03FA; Stride: 1; Delta: 1),
  (First: $03FD; Last: $03FF; Stride: 1; Delta: -130),
  (First: $0400; Last: $040F; Stride: 1; Delta: 80),
  (First: $0410; Last: $042F; Stride: 1; Delta: 32),
  (First: $0460; Last: $0480; Stride: 2; Delta: 1),
  (First: $048A; Last: $04BE; Stride: 2; Delta: 1),
  (First: $04C0; Last: $04C0; Stride: 1; Delta: 15),
  (First: $04C1; Last: $04CD; Stride: 2; Delta: 1),
  (First: $04D0; Last: $052E; Stride: 2; Delta: 1),
  (First: $0531; Last: $0556; Stride: 1; Delta: 48),
  (First: $10A0; Last: $10C5; Stride: 1; Delta: 7264),
  (First: $10C7; Last: $10C7; Stride: 1; Delta: 7264),
  (First: $10CD; Last: $10CD; Stride: 1; Delta: 7264),
  (First: $13A0; Last: $13EF; Stride: 1; Delta: 38864),
  (First: $13F0; Last: $13F5; Stride: 1; Delta: 8),
  (First: $1C90; Last: $1CBA; Stride: 1; Delta: -3008),
  (First: $1CBD; Last: $1CBF; Stride: 1; Delta: -3008),
  (First: $1E00; Last: $1E94; Stride: 2; Delta: 1),
  (First: $1E9E; Last: $1E9E; Stride: 1; Delta: -7615),
  (First: $1EA0; Last: $1EFE; Stride: 2; Delta: 1),
  (First: $1F08; Last: $1F0F; Stride: 1; Delta: -8),
  (First: $1F18; Last: $1F1D; Stride: 1; Delta: -8),
  (First: $1F28; Last: $1F2F; Stride: 1; Delta: -8),
  (First: $1F38; Last: $1F3F; Stride: 1; Delta: -8),
  (First: $1F48; Last: $1F4D; Stride: 1; Delta: -8),
  (First: $1F59; Last: $1F5F; Stride: 2; Delta: -8),
  (First: $1F68; Last: $1F6F; Stride: 1; Delta: -8),
  (First: $1F88; Last: $1F8F; Stride: 1; Delta: -8),
  (First: $1F98; Last: $1F9F; Stride: 1; Delta: -8),
  (First: $1FA8; Last: $1FAF; Stride: 1; Delta: -8),
  (First: $1FB8; Last: $1FB9; Stride: 1; Delta: -8),
  (First: $1FBA; Last: $1FBB; Stride: 1; Delta: -74),
  (First: $1FBC; Last: $1FBC; Stride: 1; Delta: -9),
  (First: $1FC8; Last: $1FCB; Stride: 1; Delta: -86),
  (First: $1FCC; Last: $1FCC; Stride: 1; Delta: -9),
  (First: $1FD8; Last: $1FD9; Stride: 1; Delta: -8),
  (First: $1FDA; Last: $1FDB; Stride: 1; Delta: -100),
  (First: $1FE8; Last: $1FE9; Stride: 1; Delta: -8),
  (First: $1FEA; Last: $1FEB; Stride: 1; Delta: -112),
  (First: $1FEC; Last: $1FEC; Stride: 1; Delta: -7),
  (First: $1FF8; Last: $1FF9; Stride: 1; Delta: -128),
  (First: $1FFA; Last: $1FFB; Stride: 1; Delta: -126),
  (First: $1FFC; Last: $1FFC; Stride: 1; Delta: -9),
  (First: $2126; Last: $2126; Stride: 1; Delta: -7517),
  (First: $212A; Last: $212A; Stride: 1; Delta: -8383),
  (First: $212B; Last: $212B; Stride: 1; Delta: -8262),
  (First: $2132; Last: $2132; Stride: 1; Delta: 28),
  (First: $2160; Last: $216F; Stride: 1; Delta: 16),
  (First: $2183; Last: $2183; Stride: 1; Delta: 1),
  (First: $24B6; Last: $24CF; Stride: 1; Delta: 26),
  (First: $2C00; Last: $2C2F; Stride: 1; Delta: 48),
  (First: $2C60; Last: $2C60; Stride: 1; Delta: 1),
  (First: $2C62; Last: $2C62; Stride: 1; Delta: -10743),
  (First: $2C63; Last: $2C63; Stride: 1; Delta: -3814),
  (First: $2C64; Last: $2C64; Stride: 1; Delta: -10727),
  (First: $2C67; Last: $2C6B; Stride: 2; Delta: 1),
  (First: $2C6D; Last: $2C6D; Stride: 1; Delta: -10780),
  (First: $2C6E; Last: $2C6E; Stride: 1; Delta: -10749),
  (First: $2C6F; Last: $2C6F; Stride: 1; Delta: -10783),
  (First: $2C70; Last: $2C70; Stride: 1; Delta: -10782),
  (First: $2C72; Last: $2C72; Stride: 1; Delta: 1),
  (First: $2C75; Last: $2C75; Stride: 1; Delta: 1),
  (First: $2C7E; Last: $2C7F; Stride: 1; Delta: -10815),
  (First: $2C80; Last: $2CE2; Stride: 2; Delta: 1),
  (First: $2CEB; Last: $2CED; Stride: 2; Delta: 1),
  (First: $2CF2; Last: $2CF2; Stride: 1; Delta: 1),
  (First: $A640; Last: $A66C; Stride: 2; Delta: 1),
  (First: $A680; Last: $A69A; Stride: 2; Delta: 1),
  (First: $A722; Last: $A72E; Stride: 2; Delta: 1),
  (First: $A732; Last: $A76E; Stride: 2; Delta: 1),
  (First: $A779; Last: $A77B; Stride: 2; Delta: 1),
  (First: $A77D; Last: $A77D; Stride: 1; Delta: -35332),
  (First: $A77E; Last: $A786; Stride: 2; Delta: 1),
  (First: $A78B; Last: $A78B; Stride: 1; Delta: 1),
  (First: $A78D; Last: $A78D; Stride: 1; Delta: -42280),
  (First: $A790; Last: $A792; Stride: 2; Delta: 1),
  (First: $A796; Last: $A7A8; Stride: 2; Delta: 1),
  (First: $A7AA; Last: $A7AA; Stride: 1; Delta: -42308),
  (First: $A7AB; Last: $A7AB; Stride: 1; Delta: -42319),
  (First: $A7AC; Last: $A7AC; Stride: 1; Delta: -42315),
  (First: $A7AD; Last: $A7AD; Stride: 1; Delta: -42305),
  (First: $A7AE; Last: $A7AE; Stride: 1; Delta: -42308),
  (First: $A7B0; Last: $A7B0; Stride: 1; Delta: -42258),
  (First: $A7B1; Last: $A7B1; Stride: 1; Delta: -42282),
  (First: $A7B2; Last: $A7B2; Stride: 1; Delta: -42261),
  (First: $A7B3; Last: $A7B3; Stride: 1; Delta: 928),
  (First: $A7B4; Last: $A7C2; Stride: 2; Delta: 1),
  (First: $A7C4; Last: $A7C4; Stride: 1; Delta: -48),
  (First: $A7C5; Last: $A7C5; Stride: 1; Delta: -42307),
  (First: $A7C6; Last: $A7C6; Stride: 1; Delta: -35384),
  (First: $A7C7; Last: $A7C9; Stride: 2; Delta: 1),
  (First: $A7D0; Last: $A7D0; Stride: 1; Delta: 1),
  (First: $A7D6; Last: $A7D8; Stride: 2; Delta: 1),
  (First: $A7F5; Last: $A7F5; Stride: 1; Delta: 1),
  (First: $FF21; Last: $FF3A; Stride: 1; Delta: 32),
  (First: $10400; Last: $10427; Stride: 1; Delta: 40),
  (First: $104B0; Last: $104D3; Stride: 1; Delta: 40),
  (First: $10570; Last: $1057A; Stride: 1; Delta: 39),
  (First: $1057C; Last: $1058A; Stride: 1; Delta: 39),
  (First: $1058C; Last: $10592; Stride: 1; Delta: 39),
  (First: $10594; Last: $10595; Stride: 1; Delta: 39),
  (First: $10C80; Last: $10CB2; Stride: 1; Delta: 64),
  (First: $118A0; Last: $118BF; Stride: 1; Delta: 32),
  (First: $16E40; Last: $16E5F; Stride: 1; Delta: 32),
  (First: $1E900; Last: $1E921; Stride: 1; Delta: 34)
);

class function TJSCaseMapping.IsAscii(const Text: string): Boolean;
begin
  Result := True;
  for var Letter in Text do
  begin
    if Ord(Letter) >= ASCII_LIMIT then
      Exit(False);
  end;
end;

class function TJSCaseMapping.CodePointAt(const Text: string; const Index: Integer; out Width: Integer): Integer;
begin
  Width := 1;
  Result := Ord(Text[Index]);

  const HasNext = (Index < Length(Text));
  const IsPair = (HasNext and Text[Index].IsHighSurrogate and Text[Index + 1].IsLowSurrogate);
  if IsPair then
  begin
    Width := 2;
    Result := Char.ConvertToUtf32(Text[Index], Text[Index + 1]);
  end;
end;

class function TJSCaseMapping.CodePointBefore(const Text: string; const Index: Integer; out Width: Integer): Integer;
begin
  Width := 1;
  Result := Ord(Text[Index]);

  const HasPrevious = (Index > 1);
  const IsPair = (HasPrevious and Text[Index].IsLowSurrogate and Text[Index - 1].IsHighSurrogate);
  if IsPair then
  begin
    Width := 2;
    Result := Char.ConvertToUtf32(Text[Index - 1], Text[Index]);
  end;
end;

class function TJSCaseMapping.CodePointToString(const Code: Integer): string;
begin
  const IsLoneSurrogate = ((Code >= $D800) and (Code <= $DFFF));
  if IsLoneSurrogate then
    Exit(Char(Code));

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
    if Code = Punctuation then
      Exit(True);
  end;

  const Category = Char.GetUnicodeCategory(UCS4Char(Code));
  Result := (Category in [TUnicodeCategory.ucNonSpacingMark,
                          TUnicodeCategory.ucEnclosingMark,
                          TUnicodeCategory.ucFormat,
                          TUnicodeCategory.ucModifierLetter,
                          TUnicodeCategory.ucModifierSymbol]);
end;

class function TJSCaseMapping.SimpleMapping(const Ranges: array of TCaseRange; const Code: Integer): Integer;
begin
  var LowIndex := 0;
  var HighIndex := High(Ranges);
  while LowIndex <= HighIndex do
  begin
    const Middle = (LowIndex + HighIndex) div 2;
    const Range = Ranges[Middle];
    if Code < Range.First then
    begin
      HighIndex := Middle - 1;
    end
    else if Code > Range.Last then
    begin
      LowIndex := Middle + 1;
    end
    else
    begin
      const IsMapped = (((Code - Range.First) mod Range.Stride) = 0);
      if IsMapped then
        Exit(Code + Range.Delta);

      Exit(Code);
    end;
  end;
  Result := Code;
end;
class function TJSCaseMapping.FindSpecialUpper(const Code: Integer; out Text: string): Boolean;
begin
  var Low := 0;
  var High := LAST_SPECIAL_UPPER_INDEX;
  while Low <= High do
  begin
    const Middle = (Low + High) div 2;
    const Candidate = SPECIAL_UPPER_MAPPINGS[Middle].Code;
    if Candidate = Code then
    begin
      Text := SPECIAL_UPPER_MAPPINGS[Middle].Text;
      Exit(True);
    end;

    if Candidate < Code then
      Low := Middle + 1
    else
      High := Middle - 1;
  end;
  Result := False;
end;

class function TJSCaseMapping.CasedPrecedes(const Text: string; const SigmaIndex: Integer): Boolean;
begin
  var Index := SigmaIndex - 1;
  while Index >= 1 do
  begin
    var Width: Integer;
    const Code = CodePointBefore(Text, Index, Width);
    if not IsCaseIgnorable(Code) then
      Exit(IsCased(Code));

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
    const Code = CodePointAt(Text, Index, Width);
    if not IsCaseIgnorable(Code) then
      Exit(IsCased(Code));

    Inc(Index, Width);
  end;
  Result := False;
end;

class function TJSCaseMapping.IsFinalSigma(const Text: string; const SigmaIndex: Integer): Boolean;
begin
  const FollowedByCased = CasedFollows(Text, SigmaIndex + 1);
  Result := (CasedPrecedes(Text, SigmaIndex) and not FollowedByCased);
end;

class function TJSCaseMapping.LowerCodePoint(const Text: string; const Index, Code: Integer): string;
begin
  if Code = LATIN_CAPITAL_I_WITH_DOT_ABOVE then
  begin
    const DotAbove = CodePointToString(COMBINING_DOT_ABOVE);
    Exit(Format('i%s', [DotAbove]));
  end;

  if Code = GREEK_CAPITAL_SIGMA then
  begin
    const IsFinal = IsFinalSigma(Text, Index);
    if IsFinal then
      Exit(CodePointToString(GREEK_SMALL_FINAL_SIGMA));

    Exit(CodePointToString(GREEK_SMALL_SIGMA));
  end;

  const LowerCode = SimpleMapping(SIMPLE_LOWER_RANGES, Code);
  Result := CodePointToString(LowerCode);
end;

class function TJSCaseMapping.ToUpper(const Text: string): string;
begin
  if IsAscii(Text) then
    Exit(UpperCase(Text));

  var Builder := TStringBuilder.Create(Length(Text));
  try
    var Index := 1;
    while Index <= Length(Text) do
    begin
      var Width: Integer;
      const Code = CodePointAt(Text, Index, Width);

      var Mapped: string;
      const HasSpecialMapping = FindSpecialUpper(Code, Mapped);
      if not HasSpecialMapping then
      begin
        const UpperCode = SimpleMapping(SIMPLE_UPPER_RANGES, Code);
        Mapped := CodePointToString(UpperCode);
      end;

      Builder.Append(Mapped);
      Inc(Index, Width);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSCaseMapping.ToLower(const Text: string): string;
begin
  if IsAscii(Text) then
    Exit(LowerCase(Text));

  var Builder := TStringBuilder.Create(Length(Text));
  try
    var Index := 1;
    while Index <= Length(Text) do
    begin
      var Width: Integer;
      const Code = CodePointAt(Text, Index, Width);

      const Lowered = LowerCodePoint(Text, Index, Code);
      Builder.Append(Lowered);
      Inc(Index, Width);
    end;
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

end.

