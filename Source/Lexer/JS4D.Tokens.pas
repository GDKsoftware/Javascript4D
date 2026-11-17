unit JS4D.Tokens;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

const
  YIELD_NAME = 'yield';

type
  TJSTokenType = (
    EndOfFile,

    Identifier,
    NumberLiteral,
    StringLiteral,
    BooleanLiteral,
    NullLiteral,
    RegExpLiteral,
    TemplateChunk,
    EscapedKeyword,
    UnusedReservedWord,

    LeftParen,
    RightParen,
    LeftBrace,
    RightBrace,
    LeftBracket,
    RightBracket,
    Comma,
    Semicolon,
    Colon,
    Dot,
    Ellipsis,

    Plus,
    Minus,
    Multiply,
    Divide,
    Modulo,
    Exponent,

    Assign,
    Arrow,
    PlusAssign,
    MinusAssign,
    MultiplyAssign,
    DivideAssign,
    ModuloAssign,
    ExponentAssign,

    Equal,
    NotEqual,
    StrictEqual,
    StrictNotEqual,
    LessThan,
    GreaterThan,
    LessThanOrEqual,
    GreaterThanOrEqual,

    LogicalAnd,
    LogicalOr,
    LogicalNot,
    NullishCoalesce,

    BitwiseAnd,
    BitwiseOr,
    BitwiseXor,
    BitwiseNot,
    LeftShift,
    RightShift,
    UnsignedRightShift,

    BitwiseAndAssign,
    BitwiseOrAssign,
    BitwiseXorAssign,
    LeftShiftAssign,
    RightShiftAssign,
    UnsignedRightShiftAssign,

    Increment,
    Decrement,

    Question,

    KeywordVar,
    KeywordFunction,
    KeywordReturn,
    KeywordIf,
    KeywordElse,
    KeywordWhile,
    KeywordFor,
    KeywordDo,
    KeywordBreak,
    KeywordContinue,
    KeywordSwitch,
    KeywordCase,
    KeywordDefault,
    KeywordNew,
    KeywordThis,
    KeywordTypeof,
    KeywordInstanceof,
    KeywordIn,
    KeywordDelete,
    KeywordVoid,
    KeywordTry,
    KeywordCatch,
    KeywordFinally,
    KeywordThrow,
    KeywordWith,
    KeywordDebugger,
    KeywordConst,
    KeywordClass,
    KeywordExtends,
    KeywordSuper
  );

  TJSTokenDetails = record
    NumberValue: Double;
    RawValue: string;
    StartOffset: Integer;
    EndOffset: Integer;
    IsLegacyLiteral: Boolean;
    HasEscape: Boolean;
    LineTerminatorBefore: Boolean;
    HasInvalidEscape: Boolean;
    IsTemplateHead: Boolean;
    IsTemplateTail: Boolean;
  end;

  TJSToken = class
  private
    FTokenType: TJSTokenType;
    FValue: string;
    FLine: Integer;
    FColumn: Integer;
    FDetails: TJSTokenDetails;

  public
    constructor Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer;
                       const Column: Integer; const Details: TJSTokenDetails);
    function IsIdentifierNamed(const Name: string): Boolean;

    property TokenType: TJSTokenType read FTokenType;
    property Value: string read FValue;
    property NumberValue: Double read FDetails.NumberValue;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property StartOffset: Integer read FDetails.StartOffset;
    property EndOffset: Integer read FDetails.EndOffset;
    property IsLegacyLiteral: Boolean read FDetails.IsLegacyLiteral;
    property HasEscape: Boolean read FDetails.HasEscape;
    property LineTerminatorBefore: Boolean read FDetails.LineTerminatorBefore;
    property RawValue: string read FDetails.RawValue;
    property HasInvalidEscape: Boolean read FDetails.HasInvalidEscape;
    property IsTemplateHead: Boolean read FDetails.IsTemplateHead;
    property IsTemplateTail: Boolean read FDetails.IsTemplateTail;
  end;

  TJSKeywords = class
  private
    class var FKeywords: TDictionary<string, TJSTokenType>;
    class procedure InitializeKeywords;

  public
    class constructor Create;
    class destructor Destroy;

    class function IsReservedWord(const Identifier: string): Boolean;
    class function IsUnusedReservedWord(const Identifier: string): Boolean;
    class function IsIdentifierName(const TokenType: TJSTokenType): Boolean;
    class function GetKeywordType(const Identifier: string): TJSTokenType;
  end;

implementation

uses
  System.StrUtils;

type
  TKeywordEntry = record
    Text: string;
    TokenType: TJSTokenType;
  end;

const
  UNUSED_RESERVED_WORDS: array[0..2] of string = ('enum', 'export', 'import');

  KEYWORD_TOKENS = [TJSTokenType.KeywordVar..TJSTokenType.KeywordSuper];

  NAME_LIKE_TOKENS = [TJSTokenType.Identifier,
                      TJSTokenType.EscapedKeyword,
                      TJSTokenType.UnusedReservedWord,
                      TJSTokenType.BooleanLiteral,
                      TJSTokenType.NullLiteral];

  KEYWORD_ENTRIES: array[0..32] of TKeywordEntry = (
    (Text: 'var'; TokenType: TJSTokenType.KeywordVar),
    (Text: 'function'; TokenType: TJSTokenType.KeywordFunction),
    (Text: 'return'; TokenType: TJSTokenType.KeywordReturn),
    (Text: 'if'; TokenType: TJSTokenType.KeywordIf),
    (Text: 'else'; TokenType: TJSTokenType.KeywordElse),
    (Text: 'while'; TokenType: TJSTokenType.KeywordWhile),
    (Text: 'for'; TokenType: TJSTokenType.KeywordFor),
    (Text: 'do'; TokenType: TJSTokenType.KeywordDo),
    (Text: 'break'; TokenType: TJSTokenType.KeywordBreak),
    (Text: 'continue'; TokenType: TJSTokenType.KeywordContinue),
    (Text: 'switch'; TokenType: TJSTokenType.KeywordSwitch),
    (Text: 'case'; TokenType: TJSTokenType.KeywordCase),
    (Text: 'default'; TokenType: TJSTokenType.KeywordDefault),
    (Text: 'new'; TokenType: TJSTokenType.KeywordNew),
    (Text: 'this'; TokenType: TJSTokenType.KeywordThis),
    (Text: 'typeof'; TokenType: TJSTokenType.KeywordTypeof),
    (Text: 'instanceof'; TokenType: TJSTokenType.KeywordInstanceof),
    (Text: 'in'; TokenType: TJSTokenType.KeywordIn),
    (Text: 'delete'; TokenType: TJSTokenType.KeywordDelete),
    (Text: 'void'; TokenType: TJSTokenType.KeywordVoid),
    (Text: 'try'; TokenType: TJSTokenType.KeywordTry),
    (Text: 'catch'; TokenType: TJSTokenType.KeywordCatch),
    (Text: 'finally'; TokenType: TJSTokenType.KeywordFinally),
    (Text: 'throw'; TokenType: TJSTokenType.KeywordThrow),
    (Text: 'with'; TokenType: TJSTokenType.KeywordWith),
    (Text: 'debugger'; TokenType: TJSTokenType.KeywordDebugger),
    (Text: 'const'; TokenType: TJSTokenType.KeywordConst),
    (Text: 'class'; TokenType: TJSTokenType.KeywordClass),
    (Text: 'extends'; TokenType: TJSTokenType.KeywordExtends),
    (Text: 'super'; TokenType: TJSTokenType.KeywordSuper),
    (Text: 'true'; TokenType: TJSTokenType.BooleanLiteral),
    (Text: 'false'; TokenType: TJSTokenType.BooleanLiteral),
    (Text: 'null'; TokenType: TJSTokenType.NullLiteral)
  );

{ TJSToken }

constructor TJSToken.Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer;
                            const Column: Integer; const Details: TJSTokenDetails);
begin
  inherited Create;
  FTokenType := TokenType;
  FValue := Value;
  FLine := Line;
  FColumn := Column;
  FDetails := Details;
end;

function TJSToken.IsIdentifierNamed(const Name: string): Boolean;
begin
  Result := ((FTokenType = TJSTokenType.Identifier) and (FValue = Name));
end;

{ TJSKeywords }

class constructor TJSKeywords.Create;
begin
  FKeywords := TDictionary<string, TJSTokenType>.Create;
  InitializeKeywords;
end;

class destructor TJSKeywords.Destroy;
begin
  FKeywords.Free;
end;

class procedure TJSKeywords.InitializeKeywords;
begin
  for var Entry in KEYWORD_ENTRIES do
  begin
    FKeywords.Add(Entry.Text, Entry.TokenType);
  end;
end;

class function TJSKeywords.IsReservedWord(const Identifier: string): Boolean;
begin
  Result := FKeywords.ContainsKey(Identifier) or IsUnusedReservedWord(Identifier);
end;

class function TJSKeywords.IsUnusedReservedWord(const Identifier: string): Boolean;
begin
  Result := MatchStr(Identifier, UNUSED_RESERVED_WORDS);
end;

class function TJSKeywords.IsIdentifierName(const TokenType: TJSTokenType): Boolean;
begin
  Result := ((TokenType in NAME_LIKE_TOKENS) or (TokenType in KEYWORD_TOKENS));
end;

class function TJSKeywords.GetKeywordType(const Identifier: string): TJSTokenType;
begin
  if not FKeywords.TryGetValue(Identifier, Result) then
    Result := TJSTokenType.Identifier;
end;

end.
