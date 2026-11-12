unit JS4D.IteratorProtocol;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Errors;

type
  // An iterator obtained through the iterator protocol. HasNext asks the iterator for its next value and
  // keeps it until Next hands it out. Close lets the iterator clean up after the consumer stops early. A
  // record whose next method raised or reported completion is done, and closing a done record does nothing.
  IJSIteratorRecord = interface
    ['{5E2B7A14-9C3D-4F86-B1A0-6D8E3F7C2A59}']
    function HasNext: Boolean;
    function Next: TJSValue;
    procedure Close;
    procedure CloseAfterThrow;
    // Hands the iterator and the values that the record keeps to the garbage collector.
    procedure EnumerateReferences(const Visit: TProc<IInterface>);
  end;

  TJSIteratorRecord = class(TInterfacedObject, IJSIteratorRecord)
  private
    const
      NEXT_PROPERTY = 'next';
      RETURN_PROPERTY = 'return';
      DONE_PROPERTY = 'done';
      VALUE_PROPERTY = 'value';
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

    function HasNext: Boolean;
    function Next: TJSValue;
    procedure Close;
    procedure CloseAfterThrow;
    procedure EnumerateReferences(const Visit: TProc<IInterface>);
  end;

  TJSIteratorResults = class
  private
    const
      DONE_PROPERTY = 'done';
      VALUE_PROPERTY = 'value';

  public
    class function CreateResult(const ObjectPrototype: IJSObject; const Value: TJSValue;
                          const IsDone: Boolean): TJSValue; static;
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
  const IsComplete = StepResult.GetProperty(DONE_PROPERTY).ToBoolean;
  if IsComplete then
    Exit(False);

  Value := StepResult.GetProperty(VALUE_PROPERTY);
  FIsDone := False;
  Result := True;
end;

function TJSIteratorRecord.HasNext: Boolean;
begin
  if FHasPendingValue then
    Exit(True);

  FHasPendingValue := Step(FPendingValue);
  Result := FHasPendingValue;
end;

function TJSIteratorRecord.Next: TJSValue;
begin
  if not HasNext then
    Exit(TJSValue.CreateUndefined);

  Result := FPendingValue;
  FPendingValue := TJSValue.CreateUndefined;
  FHasPendingValue := False;
end;

procedure TJSIteratorRecord.EnumerateReferences(const Visit: TProc<IInterface>);
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
    on Exception do
      Exit;
  end;
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
