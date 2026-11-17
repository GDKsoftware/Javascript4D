unit JS4D.Conformance.ErrorObserver;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Conformance.Defines;

type
  TErrorObserver = class
  private
    class function NameOfThrownValue(const Value: TJSValue): string; static;
    class function ConstructorNameOf(const Thrown: IJSObject): string; static;
    class function MessageOfThrownValue(const Value: TJSValue): string; static;
    class function NameOfEngineError(const Error: Exception): string; static;
    class function IsLimitError(const Error: Exception): Boolean; static;
    class function IsEngineFault(const Error: Exception): Boolean; static;

  public
    class function Observe(const Error: Exception): TObservedError; static;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ControlFlow;

type
  TErrorNameEntry = record
    ErrorClass: ExceptClass;
    Name: string;
  end;

const
  ENGINE_ERROR_NAMES: array[0..5] of TErrorNameEntry = (
    (ErrorClass: EJSSyntaxError;    Name: SYNTAX_ERROR_NAME),
    (ErrorClass: EJSReferenceError; Name: REFERENCE_ERROR_NAME),
    (ErrorClass: EJSTypeError;      Name: TYPE_ERROR_NAME),
    (ErrorClass: EJSRangeError;     Name: RANGE_ERROR_NAME),
    (ErrorClass: EJSEvalError;      Name: EVAL_ERROR_NAME),
    (ErrorClass: EJSURIError;       Name: URI_ERROR_NAME)
  );
  MESSAGE_PROPERTY = 'message';
  CONSTRUCTOR_PROPERTY = 'constructor';
  NAME_PROPERTY = 'name';
  OBJECT_TYPE_NAME = 'Object';
  THROWN_STRING_NAME = 'String';
  THROWN_NUMBER_NAME = 'Number';
  THROWN_BOOLEAN_NAME = 'Boolean';
  THROWN_OTHER_NAME = 'Value';

class function TErrorObserver.Observe(const Error: Exception): TObservedError;
begin
  Result.Message := Error.Message;
  Result.IsLimit := IsLimitError(Error);
  Result.IsEngineFault := IsEngineFault(Error);

  if Error is TJSThrowSignal then
  begin
    const ThrownValue = TJSThrowSignal(Error).Value;
    Result.Name    := NameOfThrownValue(ThrownValue);
    Result.Message := MessageOfThrownValue(ThrownValue);
  end
  else
  begin
    Result.Name := NameOfEngineError(Error);
  end;
end;

class function TErrorObserver.NameOfThrownValue(const Value: TJSValue): string;
begin
  if Value.IsString then
    Exit(THROWN_STRING_NAME);

  if Value.IsNumber then
    Exit(THROWN_NUMBER_NAME);

  if Value.IsBoolean then
    Exit(THROWN_BOOLEAN_NAME);

  if not Value.IsObject then
    Exit(THROWN_OTHER_NAME);

  const ThrownObject = Value.AsObject;
  var NativeError: IJSError;
  if Supports(ThrownObject, IJSError, NativeError) then
  begin
    Result := NativeError.GetErrorName;
    Exit;
  end;

  Result := ConstructorNameOf(ThrownObject);
end;

class function TErrorObserver.ConstructorNameOf(const Thrown: IJSObject): string;
begin
  Result := OBJECT_TYPE_NAME;

  const HasConstructor = Thrown.HasProperty(CONSTRUCTOR_PROPERTY);
  if not HasConstructor then
    Exit;

  const ConstructorValue = Thrown.GetProperty(CONSTRUCTOR_PROPERTY);
  const HasConstructorObject = ConstructorValue.IsObject;
  if not HasConstructorObject then
    Exit;

  const ConstructorObject = ConstructorValue.AsObject;
  const HasName = ConstructorObject.HasProperty(NAME_PROPERTY);
  if HasName then
  begin
    const NameValue = ConstructorObject.GetProperty(NAME_PROPERTY);
    Result := NameValue.ToString;
  end;
end;

class function TErrorObserver.MessageOfThrownValue(const Value: TJSValue): string;
begin
  Result := Value.ToString;
  if not Value.IsObject then
    Exit;

  const ThrownObject = Value.AsObject;
  const HasMessage = ThrownObject.HasProperty(MESSAGE_PROPERTY);
  if HasMessage then
  begin
    const MessageValue = ThrownObject.GetProperty(MESSAGE_PROPERTY);
    Result := MessageValue.ToString;
  end;
end;

class function TErrorObserver.NameOfEngineError(const Error: Exception): string;
begin
  for var Entry in ENGINE_ERROR_NAMES do
  begin
    if Error is Entry.ErrorClass then
    begin
      Result := Entry.Name;
      Exit;
    end;
  end;

  Result := Error.ClassName;
end;

class function TErrorObserver.IsLimitError(const Error: Exception): Boolean;
begin
  Result := (Error is EJSExecutionInterrupted);
end;

class function TErrorObserver.IsEngineFault(const Error: Exception): Boolean;
begin
  Result := not ((Error is EJSException) or (Error is TJSThrowSignal));
end;

end.
