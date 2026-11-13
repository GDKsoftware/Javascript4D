unit JS4D.Tokens;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

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

  TJSToken = class
  private
    FTokenType: TJSTokenType;
    FValue: string;
    FNumberValue: Double;
    FLine: Integer;
    FColumn: Integer;
    FSourcePosition: Integer;
    FStartOffset: Integer;
    FEndOffset: Integer;
    FIsLegacyLiteral: Boolean;
    FHasEscape: Boolean;
    FLineTerminatorBefore: Boolean;
    FRawValue: string;
    FHasInvalidEscape: Boolean;
    FIsTemplateHead: Boolean;
    FIsTemplateTail: Boolean;

  public
    constructor Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer); overload;
    constructor Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer; const SourcePosition: Integer); overload;

    property TokenType: TJSTokenType read FTokenType;
    property Value: string read FValue write FValue;
    property NumberValue: Double read FNumberValue write FNumberValue;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property SourcePosition: Integer read FSourcePosition write FSourcePosition;
    property StartOffset: Integer read FStartOffset write FStartOffset;
    property EndOffset: Integer read FEndOffset write FEndOffset;
    property IsLegacyLiteral: Boolean read FIsLegacyLiteral write FIsLegacyLiteral;
    property HasEscape: Boolean read FHasEscape write FHasEscape;
    property LineTerminatorBefore: Boolean read FLineTerminatorBefore write FLineTerminatorBefore;
    property RawValue: string read FRawValue write FRawValue;
    property HasInvalidEscape: Boolean read FHasInvalidEscape write FHasInvalidEscape;
    property IsTemplateHead: Boolean read FIsTemplateHead write FIsTemplateHead;
    property IsTemplateTail: Boolean read FIsTemplateTail write FIsTemplateTail;
  end;

  TJSKeywords = class
  private
    class var FKeywords: TDictionary<string, TJSTokenType>;
    class var FFutureReservedWords: TList<string>;
    class procedure InitializeKeywords;
    class procedure InitializeFutureReservedWords;

  public
    class constructor Create;
    class destructor Destroy;

    class function IsKeyword(const Identifier: string): Boolean;
    class function IsReservedWord(const Identifier: string): Boolean;
    class function IsUnusedReservedWord(const Identifier: string): Boolean;
    class function IsIdentifierName(const TokenType: TJSTokenType): Boolean;
    class function GetKeywordType(const Identifier: string): TJSTokenType;
  end;

implementation

uses
  System.StrUtils;

const
  UnusedReservedWords: array[0..2] of string = ('enum', 'export', 'import');
  KeywordVar = 'var';
  KeywordFunction = 'function';
  KeywordReturn = 'return';
  KeywordIf = 'if';
  KeywordElse = 'else';
  KeywordWhile = 'while';
  KeywordFor = 'for';
  KeywordDo = 'do';
  KeywordBreak = 'break';
  KeywordContinue = 'continue';
  KeywordSwitch = 'switch';
  KeywordCase = 'case';
  KeywordDefault = 'default';
  KeywordNew = 'new';
  KeywordThis = 'this';
  KeywordTypeof = 'typeof';
  KeywordInstanceof = 'instanceof';
  KeywordIn = 'in';
  KeywordDelete = 'delete';
  KeywordVoid = 'void';
  KeywordTry = 'try';
  KeywordCatch = 'catch';
  KeywordFinally = 'finally';
  KeywordThrow = 'throw';
  KeywordWith = 'with';
  KeywordDebugger = 'debugger';
  KeywordConst = 'const';
  KeywordClass = 'class';
  KeywordExtends = 'extends';
  KeywordSuper = 'super';
  KeywordTrue = 'true';
  KeywordFalse = 'false';
  KeywordNull = 'null';

{ TJSToken }

constructor TJSToken.Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer);
begin
  inherited Create;
  FTokenType := TokenType;
  FValue := Value;
  FLine := Line;
  FColumn := Column;
  FNumberValue := 0;
  FSourcePosition := 0;
end;

constructor TJSToken.Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer; const SourcePosition: Integer);
begin
  inherited Create;
  FTokenType := TokenType;
  FValue := Value;
  FLine := Line;
  FColumn := Column;
  FNumberValue := 0;
  FSourcePosition := SourcePosition;
end;

{ TJSKeywords }

class constructor TJSKeywords.Create;
begin
  FKeywords := TDictionary<string, TJSTokenType>.Create;
  FFutureReservedWords := TList<string>.Create;
  InitializeKeywords;
  InitializeFutureReservedWords;
end;

class destructor TJSKeywords.Destroy;
begin
  FFutureReservedWords.Free;
  FKeywords.Free;
end;

class procedure TJSKeywords.InitializeFutureReservedWords;
begin
  FFutureReservedWords.AddRange(['enum', 'export', 'import']);
end;

class procedure TJSKeywords.InitializeKeywords;
begin
  FKeywords.Add(KeywordVar, TJSTokenType.KeywordVar);
  FKeywords.Add(KeywordFunction, TJSTokenType.KeywordFunction);
  FKeywords.Add(KeywordReturn, TJSTokenType.KeywordReturn);
  FKeywords.Add(KeywordIf, TJSTokenType.KeywordIf);
  FKeywords.Add(KeywordElse, TJSTokenType.KeywordElse);
  FKeywords.Add(KeywordWhile, TJSTokenType.KeywordWhile);
  FKeywords.Add(KeywordFor, TJSTokenType.KeywordFor);
  FKeywords.Add(KeywordDo, TJSTokenType.KeywordDo);
  FKeywords.Add(KeywordBreak, TJSTokenType.KeywordBreak);
  FKeywords.Add(KeywordContinue, TJSTokenType.KeywordContinue);
  FKeywords.Add(KeywordSwitch, TJSTokenType.KeywordSwitch);
  FKeywords.Add(KeywordCase, TJSTokenType.KeywordCase);
  FKeywords.Add(KeywordDefault, TJSTokenType.KeywordDefault);
  FKeywords.Add(KeywordNew, TJSTokenType.KeywordNew);
  FKeywords.Add(KeywordThis, TJSTokenType.KeywordThis);
  FKeywords.Add(KeywordTypeof, TJSTokenType.KeywordTypeof);
  FKeywords.Add(KeywordInstanceof, TJSTokenType.KeywordInstanceof);
  FKeywords.Add(KeywordIn, TJSTokenType.KeywordIn);
  FKeywords.Add(KeywordDelete, TJSTokenType.KeywordDelete);
  FKeywords.Add(KeywordVoid, TJSTokenType.KeywordVoid);
  FKeywords.Add(KeywordTry, TJSTokenType.KeywordTry);
  FKeywords.Add(KeywordCatch, TJSTokenType.KeywordCatch);
  FKeywords.Add(KeywordFinally, TJSTokenType.KeywordFinally);
  FKeywords.Add(KeywordThrow, TJSTokenType.KeywordThrow);
  FKeywords.Add(KeywordWith, TJSTokenType.KeywordWith);
  FKeywords.Add(KeywordDebugger, TJSTokenType.KeywordDebugger);
  FKeywords.Add(KeywordConst, TJSTokenType.KeywordConst);
  FKeywords.Add(KeywordClass, TJSTokenType.KeywordClass);
  FKeywords.Add(KeywordExtends, TJSTokenType.KeywordExtends);
  FKeywords.Add(KeywordSuper, TJSTokenType.KeywordSuper);
  FKeywords.Add(KeywordTrue, TJSTokenType.BooleanLiteral);
  FKeywords.Add(KeywordFalse, TJSTokenType.BooleanLiteral);
  FKeywords.Add(KeywordNull, TJSTokenType.NullLiteral);
end;

class function TJSKeywords.IsKeyword(const Identifier: string): Boolean;
begin
  Result := FKeywords.ContainsKey(Identifier);
end;

class function TJSKeywords.IsReservedWord(const Identifier: string): Boolean;
begin
  Result := FKeywords.ContainsKey(Identifier) or FFutureReservedWords.Contains(Identifier);
end;

class function TJSKeywords.IsUnusedReservedWord(const Identifier: string): Boolean;
begin
  Result := MatchStr(Identifier, UnusedReservedWords);
end;

class function TJSKeywords.IsIdentifierName(const TokenType: TJSTokenType): Boolean;
begin
  const IsNameLikeLiteral = (TokenType in [TJSTokenType.Identifier,
                                           TJSTokenType.EscapedKeyword,
                                           TJSTokenType.UnusedReservedWord,
                                           TJSTokenType.BooleanLiteral,
                                           TJSTokenType.NullLiteral]);
  const IsKeywordToken = (TokenType >= TJSTokenType.KeywordVar);

  Result := IsNameLikeLiteral or IsKeywordToken;
end;

class function TJSKeywords.GetKeywordType(const Identifier: string): TJSTokenType;
begin
  if not FKeywords.TryGetValue(Identifier, Result) then
    Result := TJSTokenType.Identifier;
end;

end.
