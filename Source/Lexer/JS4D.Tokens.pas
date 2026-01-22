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

    Plus,
    Minus,
    Multiply,
    Divide,
    Modulo,

    Assign,
    PlusAssign,
    MinusAssign,
    MultiplyAssign,
    DivideAssign,
    ModuloAssign,

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
    KeywordDebugger
  );

  TJSToken = class
  private
    FTokenType: TJSTokenType;
    FValue: string;
    FNumberValue: Double;
    FLine: Integer;
    FColumn: Integer;
    FSourcePosition: Integer;
    FIsOctal: Boolean;

  public
    constructor Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer); overload;
    constructor Create(const TokenType: TJSTokenType; const Value: string; const Line: Integer; const Column: Integer; const SourcePosition: Integer); overload;

    property TokenType: TJSTokenType read FTokenType;
    property Value: string read FValue write FValue;
    property NumberValue: Double read FNumberValue write FNumberValue;
    property Line: Integer read FLine;
    property Column: Integer read FColumn;
    property SourcePosition: Integer read FSourcePosition write FSourcePosition;
    property IsOctal: Boolean read FIsOctal write FIsOctal;
  end;

  TJSKeywords = class
  private
    class var FKeywords: TDictionary<string, TJSTokenType>;
    class procedure InitializeKeywords;

  public
    class constructor Create;
    class destructor Destroy;

    class function IsKeyword(const Identifier: string): Boolean;
    class function GetKeywordType(const Identifier: string): TJSTokenType;
  end;

implementation

const
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
  InitializeKeywords;
end;

class destructor TJSKeywords.Destroy;
begin
  FKeywords.Free;
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
  FKeywords.Add(KeywordTrue, TJSTokenType.BooleanLiteral);
  FKeywords.Add(KeywordFalse, TJSTokenType.BooleanLiteral);
  FKeywords.Add(KeywordNull, TJSTokenType.NullLiteral);
end;

class function TJSKeywords.IsKeyword(const Identifier: string): Boolean;
begin
  Result := FKeywords.ContainsKey(Identifier);
end;

class function TJSKeywords.GetKeywordType(const Identifier: string): TJSTokenType;
begin
  if not FKeywords.TryGetValue(Identifier, Result) then
    Result := TJSTokenType.Identifier;
end;

end.
