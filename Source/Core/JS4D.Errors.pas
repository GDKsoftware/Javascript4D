unit JS4D.Errors;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  EJSException = class(Exception)
  private
    FLine: Integer;
    FColumn: Integer;

  public
    constructor Create(const Message: string; const Line: Integer = 0; const Column: Integer = 0);

    property Line: Integer read FLine;
    property Column: Integer read FColumn;
  end;

  EJSSyntaxError = class(EJSException);

  EJSReferenceError = class(EJSException);

  EJSTypeError = class(EJSException);

  EJSRangeError = class(EJSException);

  EJSEvalError = class(EJSException);

  EJSURIError = class(EJSException);

  EJSInternalError = class(EJSException);

  TJSErrorFactory = class
  public
    class function SyntaxError(const Message: string; const Line: Integer = 0; const Column: Integer = 0): EJSSyntaxError;
    class function ReferenceError(const Name: string; const Line: Integer = 0; const Column: Integer = 0): EJSReferenceError;
    class function TypeError(const Message: string; const Line: Integer = 0; const Column: Integer = 0): EJSTypeError;
    class function RangeError(const Message: string; const Line: Integer = 0; const Column: Integer = 0): EJSRangeError;
    class function UnexpectedToken(const Token: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
    class function UnexpectedEndOfInput(const Line: Integer; const Column: Integer): EJSSyntaxError;
    class function InvalidLeftHandSide(const Line: Integer; const Column: Integer): EJSReferenceError;
    class function NotAFunction(const Name: string; const Line: Integer = 0; const Column: Integer = 0): EJSTypeError;
    class function UndefinedVariable(const Name: string; const Line: Integer = 0; const Column: Integer = 0): EJSReferenceError;
    class function InvalidArrayLength(const Line: Integer = 0; const Column: Integer = 0): EJSRangeError;
    class function InvalidRegExp(const Pattern: string; const Line: Integer = 0; const Column: Integer = 0): EJSSyntaxError;
  end;

implementation

const
  SyntaxErrorPrefix = 'SyntaxError: ';
  ReferenceErrorPrefix = 'ReferenceError: ';
  TypeErrorPrefix = 'TypeError: ';
  RangeErrorPrefix = 'RangeError: ';
  UnexpectedTokenMessage = 'Unexpected token ';
  UnexpectedEndMessage = 'Unexpected end of input';
  InvalidLhsMessage = 'Invalid left-hand side in assignment';
  NotAFunctionMessage = ' is not a function';
  NotDefinedMessage = ' is not defined';
  InvalidArrayLengthMessage = 'Invalid array length';
  InvalidRegExpMessage = 'Invalid regular expression: ';

{ EJSException }

constructor EJSException.Create(const Message: string; const Line: Integer; const Column: Integer);
begin
  inherited Create(Message);
  FLine := Line;
  FColumn := Column;
end;

{ TJSErrorFactory }

class function TJSErrorFactory.SyntaxError(const Message: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := EJSSyntaxError.Create(SyntaxErrorPrefix + Message, Line, Column);
end;

class function TJSErrorFactory.ReferenceError(const Name: string; const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := EJSReferenceError.Create(ReferenceErrorPrefix + Name, Line, Column);
end;

class function TJSErrorFactory.TypeError(const Message: string; const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := EJSTypeError.Create(TypeErrorPrefix + Message, Line, Column);
end;

class function TJSErrorFactory.RangeError(const Message: string; const Line: Integer; const Column: Integer): EJSRangeError;
begin
  Result := EJSRangeError.Create(RangeErrorPrefix + Message, Line, Column);
end;

class function TJSErrorFactory.UnexpectedToken(const Token: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := SyntaxError(UnexpectedTokenMessage + Token, Line, Column);
end;

class function TJSErrorFactory.UnexpectedEndOfInput(const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := SyntaxError(UnexpectedEndMessage, Line, Column);
end;

class function TJSErrorFactory.InvalidLeftHandSide(const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := EJSReferenceError.Create(ReferenceErrorPrefix + InvalidLhsMessage, Line, Column);
end;

class function TJSErrorFactory.NotAFunction(const Name: string; const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := TypeError(Name + NotAFunctionMessage, Line, Column);
end;

class function TJSErrorFactory.UndefinedVariable(const Name: string; const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := EJSReferenceError.Create(ReferenceErrorPrefix + Name + NotDefinedMessage, Line, Column);
end;

class function TJSErrorFactory.InvalidArrayLength(const Line: Integer; const Column: Integer): EJSRangeError;
begin
  Result := RangeError(InvalidArrayLengthMessage, Line, Column);
end;

class function TJSErrorFactory.InvalidRegExp(const Pattern: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := SyntaxError(InvalidRegExpMessage + Pattern, Line, Column);
end;

end.
