unit JS4D.IteratorProtocol;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.PropertyNames,
  JS4D.Types,
  JS4D.Errors;

const
  DONE_PROPERTY = 'done';
  VALUE_PROPERTY = 'value';

type
  IJSIteratorRecord = interface
    ['{5E2B7A14-9C3D-4F86-B1A0-6D8E3F7C2A59}']
    function TryPrefetchNext: Boolean;
    function Next: TJSValue;
    procedure Close;
    procedure CloseAfterThrow;
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

  TJSIteratorRecord = class(TInterfacedObject, IJSIteratorRecord)
  private
    const
      RETURN_PROPERTY = 'return';
      NEXT_NOT_CALLABLE = 'The iterator''s next method is not a function';
      RESULT_NOT_AN_OBJECT = 'The iterator result is not an object';
      RETURN_NOT_CALLABLE = 'The iterator''s return method is not a function';
      RETURN_RESULT_NOT_AN_OBJECT = 'The result of the iterator''s return method is not an object';

    var
      FHandler: TJSCallHandler;
      FIterator: IJSObject;
      FNextMethod: TJSValue;
      FPendingValue: TJSValue;
      FHasPendingValue: Boolean;
      FIsDone: Boolean;

    function ReadResult: IJSObject;
    function Step(out Value: TJSValue): Boolean;
    function FindReturnMethod: IJSFunction;

  public
    constructor Create(const Handler: TJSCallHandler; const Iterator: IJSObject);

    function TryPrefetchNext: Boolean;
    function Next: TJSValue;
    procedure Close;
    procedure CloseAfterThrow;
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

  TJSIteratorResults = class
  public
    class function CreateResult(const ObjectPrototype: IJSObject; const Value: TJSValue;
                                const IsDone: Boolean): TJSValue; static;
    class function CreateEntry(const ArrayPrototype: IJSObject; const Key: TJSValue;
                               const Value: TJSValue): TJSValue; static;
  end;

implementation

constructor TJSIteratorRecord.Create(const Handler: TJSCallHandler; const Iterator: IJSObject);
begin
  inherited Create;

  FHandler := Handler;
  FIterator := Iterator;
  FNextMethod := Iterator.GetProperty(NEXT_PROPERTY);
end;

function TJSIteratorRecord.ReadResult: IJSObject;
begin
  var NextFunction: IJSFunction;
  const IsCallable = FNextMethod.IsFunction and Supports(FNextMethod.ToObject, IJSFunction, NextFunction);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(NEXT_NOT_CALLABLE);

  const Outcome = FHandler.CallFunction(NextFunction, nil, FIterator);
  if not Outcome.IsObject then
    raise TJSErrorFactory.TypeError(RESULT_NOT_AN_OBJECT);

  Result := Outcome.ToObject;
end;

function TJSIteratorRecord.Step(out Value: TJSValue): Boolean;
begin
  Value := TJSValue.CreateUndefined;
  if FIsDone then
    Exit(False);

  FIsDone := True;

  const StepResult = ReadResult;
  const DoneValue = StepResult.GetProperty(DONE_PROPERTY);
  const IsComplete = DoneValue.ToBoolean;
  if IsComplete then
    Exit(False);

  Value := StepResult.GetProperty(VALUE_PROPERTY);
  FIsDone := False;
  Result := True;
end;

function TJSIteratorRecord.TryPrefetchNext: Boolean;
begin
  if FHasPendingValue then
    Exit(True);

  FHasPendingValue := Step(FPendingValue);
  Result := FHasPendingValue;
end;

function TJSIteratorRecord.Next: TJSValue;
begin
  if not TryPrefetchNext then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := FPendingValue;
  FPendingValue := TJSValue.CreateUndefined;
  FHasPendingValue := False;
end;

procedure TJSIteratorRecord.EnumerateReferences(const Visit: TJSReferenceVisitor);
begin
  Visit(FIterator);

  if FNextMethod.IsObject then
    Visit(FNextMethod.ToObject);

  if FPendingValue.IsObject then
    Visit(FPendingValue.ToObject);
end;

function TJSIteratorRecord.FindReturnMethod: IJSFunction;
begin
  Result := nil;

  const ReturnMethod = FIterator.GetProperty(RETURN_PROPERTY);
  if ReturnMethod.IsNullOrUndefined then
    Exit;

  const IsCallable = ReturnMethod.IsFunction and Supports(ReturnMethod.ToObject, IJSFunction, Result);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(RETURN_NOT_CALLABLE);
end;

procedure TJSIteratorRecord.Close;
begin
  if FIsDone then
    Exit;

  FIsDone := True;

  const ReturnFunction = FindReturnMethod;
  if not Assigned(ReturnFunction) then
    Exit;

  const Outcome = FHandler.CallFunction(ReturnFunction, nil, FIterator);
  if not Outcome.IsObject then
    raise TJSErrorFactory.TypeError(RETURN_RESULT_NOT_AN_OBJECT);
end;

procedure TJSIteratorRecord.CloseAfterThrow;
begin
  if FIsDone then
    Exit;

  try
    Close;
  except
    on EJSExecutionInterrupted do
      raise;
    on EOutOfMemory do
      raise;
    on EAccessViolation do
      raise;
    on Exception do
      Exit;
  end;
end;

class function TJSIteratorResults.CreateEntry(const ArrayPrototype: IJSObject; const Key: TJSValue;
                                              const Value: TJSValue): TJSValue;
begin
  const Entry = TJSArray.Create;
  Entry.Prototype := ArrayPrototype;
  Entry.Push(Key);
  Entry.Push(Value);

  Result := TJSValue.CreateObject(Entry);
end;

class function TJSIteratorResults.CreateResult(const ObjectPrototype: IJSObject; const Value: TJSValue;
                                               const IsDone: Boolean): TJSValue;
begin
  const ResultObject = TJSObject.Create;
  ResultObject.Prototype := ObjectPrototype;
  ResultObject.SetProperty(VALUE_PROPERTY, Value);
  ResultObject.SetProperty(DONE_PROPERTY, TJSValue.CreateBoolean(IsDone));

  Result := TJSValue.CreateObject(ResultObject);
end;

end.
