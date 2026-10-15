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
  ExecutionCancelledMessage = 'Script execution was cancelled';
  StepBudgetExceededMessage = 'Script exceeded its step budget of %d steps';
  CallDepthExceededMessage = 'Script exceeded its call depth limit of %d nested calls';
  StringLengthExceededMessage = 'Script exceeded the string length limit of %d characters';
  ArrayLengthExceededMessage = 'Script exceeded the array length limit of %d elements';

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
  inherited Create(ExecutionCancelledMessage);
end;

{ EJSStepBudgetExceeded }

constructor EJSStepBudgetExceeded.Create(const StepBudget: Int64);
begin
  inherited Create(Format(StepBudgetExceededMessage, [StepBudget]));
  FStepBudget := StepBudget;
end;

{ EJSCallDepthExceeded }

constructor EJSCallDepthExceeded.Create(const MaxCallDepth: Integer);
begin
  inherited Create(Format(CallDepthExceededMessage, [MaxCallDepth]));
  FMaxCallDepth := MaxCallDepth;
end;

{ EJSAllocationLimitExceeded }

constructor EJSAllocationLimitExceeded.Create(const Kind: TJSAllocationKind; const Limit: Integer);
begin
  case Kind of
    TJSAllocationKind.Characters:
      inherited Create(Format(StringLengthExceededMessage, [Limit]));
    TJSAllocationKind.Elements:
      inherited Create(Format(ArrayLengthExceededMessage, [Limit]));
    else
      inherited Create(Format(ArrayLengthExceededMessage, [Limit]));
  end;

  FKind := Kind;
  FLimit := Limit;
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
