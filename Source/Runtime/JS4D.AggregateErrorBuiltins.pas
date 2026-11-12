unit JS4D.AggregateErrorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ArrayStatics,
  JS4D.BinarySupport;

type
  // AggregateError, the error that Promise.any rejects with.
  TJSAggregateErrorBuiltins = class
  private
    const
      AGGREGATE_ERROR_NAME = 'AggregateError';
      ERROR_NAME = 'Error';
      NAME_PROPERTY = 'name';
      MESSAGE_PROPERTY = 'message';
      ERRORS_PROPERTY = 'errors';
      NOT_ITERABLE = 'The errors of an AggregateError are not iterable';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBinarySupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
    function ReadErrors(const Source: TJSValue): TArray<TJSValue>;
    function CreateError(const Prototype: IJSObject; const MessageText: string; const HasMessage: Boolean;
                         const Errors: TArray<TJSValue>): TJSValue;
    function CreateErrorsArray(const Errors: TArray<TJSValue>): TJSValue;

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport);
    destructor Destroy; override;

    procedure Register;
    function CreateFromList(const Errors: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ProxyObjects,
  JS4D.Conversions;

constructor TJSAggregateErrorBuiltins.Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
end;

destructor TJSAggregateErrorBuiltins.Destroy;
begin
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

function TJSAggregateErrorBuiltins.ReadErrors(const Source: TJSValue): TArray<TJSValue>;
begin
  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if not FInterpreter.OpenSequenceReader(Source, Reader, Closer) then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  const Items = TList<TJSValue>.Create;
  try
    var Item: TJSValue;
    while Reader(Item) do
    begin
      Items.Add(Item);
    end;

    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

function TJSAggregateErrorBuiltins.CreateErrorsArray(const Errors: TArray<TJSValue>): TJSValue;
begin
  const List = TJSArray.Create;
  List.Prototype := FInterpreter.ArrayPrototype;
  for var Item in Errors do
  begin
    List.Push(Item);
  end;

  Result := TJSValue.CreateObject(List);
end;

function TJSAggregateErrorBuiltins.CreateError(const Prototype: IJSObject; const MessageText: string;
                                               const HasMessage: Boolean;
                                               const Errors: TArray<TJSValue>): TJSValue;
begin
  const Error: IJSError = TJSError.Create(TJSErrorType.Error, MessageText);
  Error.Prototype := Prototype;

  if HasMessage then
    FSupport.DefineMember(Error, MESSAGE_PROPERTY, TJSValue.CreateString(MessageText), True);

  FSupport.DefineMember(Error, ERRORS_PROPERTY, CreateErrorsArray(Errors), True);

  Result := TJSValue.CreateObject(Error);
end;

function TJSAggregateErrorBuiltins.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);

  const MessageValue = TJSBinarySupport.Argument(Args, 1);
  const HasMessage = not MessageValue.IsUndefined;
  var MessageText := '';
  if HasMessage then
    MessageText := TJSConversions.ToText(MessageValue, FInterpreter.Limits);

  const Errors = ReadErrors(TJSBinarySupport.Argument(Args, 0));
  Result := CreateError(Prototype, MessageText, HasMessage, Errors);
end;

function TJSAggregateErrorBuiltins.CreateFromList(const Errors: TArray<TJSValue>): TJSValue;
begin
  Result := CreateError(FPrototype, '', False, Errors);
end;

procedure TJSAggregateErrorBuiltins.Register;
begin
  const ErrorConstructor = FInterpreter.GetGlobalVariable(ERROR_NAME).ToObject;
  const ErrorPrototype = ErrorConstructor.GetProperty('prototype').ToObject;

  FPrototype := TJSObject.Create;
  FPrototype.Prototype := ErrorPrototype;
  FSupport.DefineMember(FPrototype, NAME_PROPERTY, TJSValue.CreateString(AGGREGATE_ERROR_NAME), True);
  FSupport.DefineMember(FPrototype, MESSAGE_PROPERTY, TJSValue.CreateString(''), True);

  FConstructor := TJSConstructorFunction.CreateConstructor(AGGREGATE_ERROR_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Construct(Args, nil);
    end,
    Construct);
  FConstructor.Prototype := ErrorConstructor;
  FConstructor.DeleteProperty(NAME_PROPERTY);
  TJSFunction.DefineLength(FConstructor, 2);
  TJSFunction.DefineName(FConstructor, AGGREGATE_ERROR_NAME);
  FInterpreter.RegisterFunction(FConstructor);

  FSupport.LinkConstructor(FConstructor, FPrototype);
  FInterpreter.SetGlobalVariable(AGGREGATE_ERROR_NAME, TJSValue.CreateObject(FConstructor));
end;

end.
