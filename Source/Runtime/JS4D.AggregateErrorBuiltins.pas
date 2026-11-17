unit JS4D.AggregateErrorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSAggregateErrorBuiltins = class
  private
    const
      AGGREGATE_ERROR_NAME = 'AggregateError';
      ERROR_NAME = 'Error';
      CONSTRUCTOR_LENGTH = 2;
      IS_WRITABLE = True;
      NOT_ITERABLE = 'The errors of an AggregateError are not iterable';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
    function CreateBaseError(const Prototype: IJSObject; const MessageText: string): IJSError;
    procedure DefineErrors(const Error: IJSError; const Errors: TArray<TJSValue>);
    procedure CreatePrototype(const ErrorConstructor: IJSObject);
    procedure CreateConstructor(const ErrorConstructor: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);
    destructor Destroy; override;

    procedure Register;
    function CreateFromList(const Errors: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.PropertyKey,
  JS4D.ProxyObjects,
  JS4D.ConstructorFunction,
  JS4D.Conversions,
  JS4D.PropertyNames;

constructor TJSAggregateErrorBuiltins.Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
end;

destructor TJSAggregateErrorBuiltins.Destroy;
begin
  FSupport.UnlinkConstructor(FPrototype);

  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

function TJSAggregateErrorBuiltins.CreateBaseError(const Prototype: IJSObject; const MessageText: string): IJSError;
begin
  Result := TJSError.Create(TJSErrorType.Error, MessageText);
  Result.Prototype := Prototype;
end;

procedure TJSAggregateErrorBuiltins.DefineErrors(const Error: IJSError; const Errors: TArray<TJSValue>);
begin
  const ErrorsValue = FSupport.CreateArray(Errors);

  FSupport.DefineMember(Error, ERRORS_PROPERTY, ErrorsValue, IS_WRITABLE);
end;

function TJSAggregateErrorBuiltins.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);

  const MessageValue = TJSArrayLike.Argument(Args, 1);
  const HasMessage = (not MessageValue.IsUndefined);
  var MessageText := '';
  if HasMessage then
    MessageText := TJSConversions.ToText(MessageValue, FInterpreter.Limits);

  const ErrorSource = TJSArrayLike.Argument(Args, 0);
  const Errors = FSupport.ReadSequence(ErrorSource, NOT_ITERABLE);

  const Error = CreateBaseError(Prototype, MessageText);
  if HasMessage then
  begin
    const MessageProperty = TJSValue.CreateString(MessageText);
    FSupport.DefineMember(Error, MESSAGE_PROPERTY, MessageProperty, IS_WRITABLE);
  end;

  DefineErrors(Error, Errors);

  Result := TJSValue.CreateObject(Error);
end;

function TJSAggregateErrorBuiltins.CreateFromList(const Errors: TArray<TJSValue>): TJSValue;
begin
  const Error = CreateBaseError(FPrototype, '');
  DefineErrors(Error, Errors);

  Result := TJSValue.CreateObject(Error);
end;

procedure TJSAggregateErrorBuiltins.CreatePrototype(const ErrorConstructor: IJSObject);
begin
  const ErrorPrototype = ErrorConstructor.GetProperty(PROTOTYPE_PROPERTY).ToObject;

  FPrototype := TJSObject.Create;
  FPrototype.Prototype := ErrorPrototype;

  const NameValue = TJSValue.CreateString(AGGREGATE_ERROR_NAME);
  const EmptyMessage = TJSValue.CreateString('');
  FSupport.DefineMember(FPrototype, NAME_PROPERTY, NameValue, IS_WRITABLE);
  FSupport.DefineMember(FPrototype, MESSAGE_PROPERTY, EmptyMessage, IS_WRITABLE);
end;

procedure TJSAggregateErrorBuiltins.CreateConstructor(const ErrorConstructor: IJSObject);
begin
  FConstructor := TJSConstructorFunction.CreateConstructor(AGGREGATE_ERROR_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Construct(Args, nil);
    end,
    Construct);
  FConstructor.Prototype := ErrorConstructor;
  FConstructor.DeleteProperty(NAME_PROPERTY);
  TJSFunction.DefineLength(FConstructor, CONSTRUCTOR_LENGTH);
  TJSFunction.DefineName(FConstructor, AGGREGATE_ERROR_NAME);
  FInterpreter.RegisterFunction(FConstructor);
end;

procedure TJSAggregateErrorBuiltins.Register;
begin
  const ErrorConstructor = FInterpreter.GetGlobalVariable(ERROR_NAME).ToObject;

  CreatePrototype(ErrorConstructor);
  CreateConstructor(ErrorConstructor);

  FSupport.LinkConstructor(FConstructor, FPrototype);

  const AggregateErrorValue = TJSValue.CreateObject(FConstructor);
  FInterpreter.SetGlobalVariable(AGGREGATE_ERROR_NAME, AggregateErrorValue);
end;

end.
