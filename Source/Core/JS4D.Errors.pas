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

  EJSExecutionInterrupted = class(EJSException);

  EJSExecutionCancelled = class(EJSExecutionInterrupted)
  public
    constructor Create;
  end;

  EJSStepBudgetExceeded = class(EJSExecutionInterrupted)
  private
    FStepBudget: Int64;

  public
    constructor Create(const StepBudget: Int64);

    property StepBudget: Int64 read FStepBudget;
  end;

  EJSCallDepthExceeded = class(EJSExecutionInterrupted)
  private
    FMaxCallDepth: Integer;

  public
    constructor Create(const MaxCallDepth: Integer);

    property MaxCallDepth: Integer read FMaxCallDepth;
  end;

  TJSAllocationKind = (
    Characters,
    Elements
  );

  EJSAllocationLimitExceeded = class(EJSExecutionInterrupted)
  private
    FKind: TJSAllocationKind;
    FLimit: Integer;

  public
    constructor Create(const Kind: TJSAllocationKind; const Limit: Integer);

    property Kind: TJSAllocationKind read FKind;
    property Limit: Integer read FLimit;
  end;

  TJSSourcePosition = record
    Line: Integer;
    Column: Integer;

    class function At(const Line: Integer; const Column: Integer): TJSSourcePosition; static;
    class function Unknown: TJSSourcePosition; static;
  end;

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
    class function NotAConstructor(const Name: string; const Line: Integer = 0; const Column: Integer = 0): EJSTypeError;
    class function UndefinedVariable(const Name: string; const Line: Integer = 0; const Column: Integer = 0): EJSReferenceError;
    class function InvalidArrayLength(const Line: Integer = 0; const Column: Integer = 0): EJSRangeError;
    class function NotCoercibleToObject(const Line: Integer = 0; const Column: Integer = 0): EJSTypeError;
    class function StackExhausted(const Line: Integer = 0; const Column: Integer = 0): EJSRangeError;
    class function MalformedUri: EJSURIError;
    class function InvalidRegExp(const Pattern: string; const Position: TJSSourcePosition): EJSSyntaxError;
  end;

implementation

const
  SYNTAX_ERROR_PREFIX = 'SyntaxError: ';
  REFERENCE_ERROR_PREFIX = 'ReferenceError: ';
  TYPE_ERROR_PREFIX = 'TypeError: ';
  RANGE_ERROR_PREFIX = 'RangeError: ';
  STACK_EXHAUSTED_MESSAGE = 'Maximum call stack size exceeded';
  UNEXPECTED_TOKEN_MESSAGE = 'Unexpected token ';
  UNEXPECTED_END_MESSAGE = 'Unexpected end of input';
  INVALID_LHS_MESSAGE = 'Invalid left-hand side in assignment';
  NOT_A_FUNCTION_MESSAGE = ' is not a function';
  NOT_A_CONSTRUCTOR_MESSAGE = ' is not a constructor';
  NOT_DEFINED_MESSAGE = ' is not defined';
  INVALID_ARRAY_LENGTH_MESSAGE = 'Invalid array length';
  NOT_COERCIBLE_TO_OBJECT_MESSAGE = 'Cannot convert undefined or null to object';
  INVALID_REGEXP_FORMAT = 'Invalid regular expression: %s';
  URI_ERROR_PREFIX = 'URIError: ';
  MALFORMED_URI_MESSAGE = 'URI malformed';
  EXECUTION_CANCELLED_MESSAGE = 'Script execution was cancelled';
  STEP_BUDGET_EXCEEDED_MESSAGE = 'Script exceeded its step budget of %d steps';
  CALL_DEPTH_EXCEEDED_MESSAGE = 'Script exceeded its call depth limit of %d nested calls';
  STRING_LENGTH_EXCEEDED_MESSAGE = 'Script exceeded the string length limit of %d characters';
  ARRAY_LENGTH_EXCEEDED_MESSAGE = 'Script exceeded the array length limit of %d elements';

{ EJSException }

constructor EJSException.Create(const Message: string; const Line: Integer; const Column: Integer);
begin
  inherited Create(Message);
  FLine := Line;
  FColumn := Column;
end;

{ EJSExecutionCancelled }

constructor EJSExecutionCancelled.Create;
begin
  inherited Create(EXECUTION_CANCELLED_MESSAGE);
end;

{ EJSStepBudgetExceeded }

constructor EJSStepBudgetExceeded.Create(const StepBudget: Int64);
begin
  inherited Create(Format(STEP_BUDGET_EXCEEDED_MESSAGE, [StepBudget]));
  FStepBudget := StepBudget;
end;

{ EJSCallDepthExceeded }

constructor EJSCallDepthExceeded.Create(const MaxCallDepth: Integer);
begin
  inherited Create(Format(CALL_DEPTH_EXCEEDED_MESSAGE, [MaxCallDepth]));
  FMaxCallDepth := MaxCallDepth;
end;

{ EJSAllocationLimitExceeded }

constructor EJSAllocationLimitExceeded.Create(const Kind: TJSAllocationKind; const Limit: Integer);
begin
  case Kind of
    TJSAllocationKind.Characters:
      inherited Create(Format(STRING_LENGTH_EXCEEDED_MESSAGE, [Limit]));
    TJSAllocationKind.Elements:
      inherited Create(Format(ARRAY_LENGTH_EXCEEDED_MESSAGE, [Limit]));
    else
      inherited Create(Format(ARRAY_LENGTH_EXCEEDED_MESSAGE, [Limit]));
  end;

  FKind := Kind;
  FLimit := Limit;
end;

{ TJSSourcePosition }

class function TJSSourcePosition.At(const Line: Integer; const Column: Integer): TJSSourcePosition;
begin
  Result.Line := Line;
  Result.Column := Column;
end;

class function TJSSourcePosition.Unknown: TJSSourcePosition;
begin
  Result := At(0, 0);
end;

{ TJSErrorFactory }

class function TJSErrorFactory.SyntaxError(const Message: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := EJSSyntaxError.Create(SYNTAX_ERROR_PREFIX + Message, Line, Column);
end;

class function TJSErrorFactory.ReferenceError(const Name: string; const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := EJSReferenceError.Create(REFERENCE_ERROR_PREFIX + Name, Line, Column);
end;

class function TJSErrorFactory.TypeError(const Message: string; const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := EJSTypeError.Create(TYPE_ERROR_PREFIX + Message, Line, Column);
end;

class function TJSErrorFactory.RangeError(const Message: string; const Line: Integer; const Column: Integer): EJSRangeError;
begin
  Result := EJSRangeError.Create(RANGE_ERROR_PREFIX + Message, Line, Column);
end;

class function TJSErrorFactory.NotCoercibleToObject(const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := TypeError(NOT_COERCIBLE_TO_OBJECT_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.UnexpectedToken(const Token: string; const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := SyntaxError(UNEXPECTED_TOKEN_MESSAGE + Token, Line, Column);
end;

class function TJSErrorFactory.UnexpectedEndOfInput(const Line: Integer; const Column: Integer): EJSSyntaxError;
begin
  Result := SyntaxError(UNEXPECTED_END_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.InvalidLeftHandSide(const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := ReferenceError(INVALID_LHS_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.NotAFunction(const Name: string; const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := TypeError(Name + NOT_A_FUNCTION_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.NotAConstructor(const Name: string; const Line: Integer; const Column: Integer): EJSTypeError;
begin
  Result := TypeError(Name + NOT_A_CONSTRUCTOR_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.UndefinedVariable(const Name: string; const Line: Integer; const Column: Integer): EJSReferenceError;
begin
  Result := ReferenceError(Name + NOT_DEFINED_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.InvalidArrayLength(const Line: Integer; const Column: Integer): EJSRangeError;
begin
  Result := RangeError(INVALID_ARRAY_LENGTH_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.StackExhausted(const Line: Integer; const Column: Integer): EJSRangeError;
begin
  Result := RangeError(STACK_EXHAUSTED_MESSAGE, Line, Column);
end;

class function TJSErrorFactory.MalformedUri: EJSURIError;
begin
  Result := EJSURIError.Create(URI_ERROR_PREFIX + MALFORMED_URI_MESSAGE);
end;

class function TJSErrorFactory.InvalidRegExp(const Pattern: string; const Position: TJSSourcePosition): EJSSyntaxError;
begin
  Result := SyntaxError(Format(INVALID_REGEXP_FORMAT, [Pattern]), Position.Line, Position.Column);
end;

end.
