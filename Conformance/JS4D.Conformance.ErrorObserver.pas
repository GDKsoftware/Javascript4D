unit JS4D.Conformance.ErrorObserver;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Interpreter,
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

const
  MessageProperty = 'message';
  ConstructorProperty = 'constructor';
  NameProperty = 'name';
  ObjectTypeName = 'Object';
  ThrownStringName = 'String';
  ThrownNumberName = 'Number';
  ThrownBooleanName = 'Boolean';
  ThrownOtherName = 'Value';

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
    Exit(ThrownStringName);

  if Value.IsNumber then
    Exit(ThrownNumberName);

  if Value.IsBoolean then
    Exit(ThrownBooleanName);

  if not Value.IsObject then
    Exit(ThrownOtherName);

  var NativeError: IJSError;
  if Supports(Value.AsObject, IJSError, NativeError) then
    Exit(NativeError.GetErrorName);

  Result := ConstructorNameOf(Value.AsObject);
end;

class function TErrorObserver.ConstructorNameOf(const Thrown: IJSObject): string;
begin
  Result := ObjectTypeName;

  const HasConstructor = Thrown.HasProperty(ConstructorProperty);
  if not HasConstructor then
    Exit;

  const ConstructorValue = Thrown.GetProperty(ConstructorProperty);
  const HasName = ConstructorValue.IsObject and ConstructorValue.AsObject.HasProperty(NameProperty);
  if HasName then
    Result := ConstructorValue.AsObject.GetProperty(NameProperty).ToString;
end;

class function TErrorObserver.MessageOfThrownValue(const Value: TJSValue): string;
begin
  const HasMessage = Value.IsObject and Value.AsObject.HasProperty(MessageProperty);
  if HasMessage then
    Result := Value.AsObject.GetProperty(MessageProperty).ToString
  else
    Result := Value.ToString;
end;

class function TErrorObserver.NameOfEngineError(const Error: Exception): string;
begin
  if Error is EJSSyntaxError then
    Exit(SyntaxErrorName);

  if Error is EJSReferenceError then
    Exit(ReferenceErrorName);

  if Error is EJSTypeError then
    Exit(TypeErrorName);

  if Error is EJSRangeError then
    Exit(RangeErrorName);

  if Error is EJSEvalError then
    Exit(EvalErrorName);

  if Error is EJSURIError then
    Exit(URIErrorName);

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
