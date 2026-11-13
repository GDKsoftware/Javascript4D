unit JS4D.BinarySupport;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.PropertyNames,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ProxyObjects;

type
  TJSCallOutcome = record
    IsNormal: Boolean;
    Value: TJSValue;
  end;

  // What the ArrayBuffer, DataView and typed array builtins have in common: defining functions and accessors,
  // reading arguments, and the conversions of the specification that decide which errors are raised.
  TJSBinarySupport = class
  private
    const
      MAX_SAFE_INTEGER = 9007199254740991.0;
      SPECIES_GETTER_NAME = 'get [Symbol.species]';
      INVALID_INDEX = 'Invalid index: %s';
      CONSTRUCTOR_NOT_AN_OBJECT = 'The constructor property of the object is not an object';
      SPECIES_NOT_A_CONSTRUCTOR = 'The species of the constructor is not a constructor';
      NULL_OR_UNDEFINED = 'Cannot convert undefined or null to object';
      NOT_A_FUNCTION = '%s is not a function';

    var
      FInterpreter: TJSInterpreter;

  public
    constructor Create(const Interpreter: TJSInterpreter);

    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    class function ToIntegerOrInfinity(const Value: TJSValue): Double; static;
    class function ToIndex(const Value: TJSValue): Int64; static;
    class function AsFunction(const Value: TJSValue; out Func: IJSFunction): Boolean; static;
    class function AsConstructor(const Value: TJSValue; out Func: IJSFunction): Boolean; static;
    class function IsCallable(const Value: TJSValue): Boolean; static;
    class function IsSameObject(const First: IJSObject; const Second: IJSObject): Boolean; static;
    class function ArgumentsFrom(const Args: TArray<TJSValue>; const FirstPosition: Integer): TArray<TJSValue>; static;

    function ToObject(const Value: TJSValue): IJSObject;
    function CreateArray(const Items: TArray<TJSValue>): TJSValue;
    function ReadSequence(const Source: TJSValue; const NotIterableMessage: string): TArray<TJSValue>;
    function TypeErrorValue(const Message: string): TJSValue;
    function Invoke(const Target: TJSValue; const Name: string; const Args: TArray<TJSValue>): TJSValue;
    function Capture(const Operation: TFunc<TJSValue>): TJSCallOutcome;
    procedure AttemptIgnoringFailure(const Operation: TProc);
    function CallCapturingThrow(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                const This: IJSObject): TJSCallOutcome;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    function DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                           const IsWritable: Boolean);
    procedure DefineConstant(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue);
    procedure DefineGetter(const Target: IJSObject; const Key: TJSPropertyKey; const FunctionName: string;
                           const Method: TNativeFunction);
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    procedure DefineSpeciesGetter(const Constructor_: IJSObject);
    procedure LinkConstructor(const Constructor_: IJSFunction; const Prototype: IJSObject);
    procedure UnlinkConstructor(const Prototype: IJSObject);
    function CreateConstructor(const Name: string; const ParameterCount: Integer; const RequiresNewMessage: string;
                               const Handler: TJSConstructHandler): IJSFunction;
    function PrototypeFromConstructor(const NewTarget: IJSFunction; const DefaultPrototype: IJSObject): IJSObject;
    function SpeciesConstructor(const Source: IJSObject; const DefaultConstructor: IJSFunction): IJSFunction;

    property Interpreter: TJSInterpreter read FInterpreter;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayStatics,
  JS4D.SymbolRegistry;

constructor TJSBinarySupport.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

class function TJSBinarySupport.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  if Position < Length(Args) then
    Exit(Args[Position]);

  Result := TJSValue.CreateUndefined;
end;

class function TJSBinarySupport.ToIntegerOrInfinity(const Value: TJSValue): Double;
begin
  const Number = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
  if IsNaN(Number) then
    Exit(0);

  Result := Int(Number);
end;

class function TJSBinarySupport.ToIndex(const Value: TJSValue): Int64;
begin
  if Value.IsUndefined then
    Exit(0);

  const Whole = ToIntegerOrInfinity(Value);
  const IsValid = (Whole >= 0) and (Whole <= MAX_SAFE_INTEGER);
  if not IsValid then
    raise TJSErrorFactory.RangeError(Format(INVALID_INDEX, [Value.ToString]));

  Result := Trunc(Whole);
end;

class function TJSBinarySupport.AsFunction(const Value: TJSValue; out Func: IJSFunction): Boolean;
begin
  Result := Value.IsFunction and Supports(Value.ToObject, IJSFunction, Func);
end;

class function TJSBinarySupport.AsConstructor(const Value: TJSValue; out Func: IJSFunction): Boolean;
begin
  Result := AsFunction(Value, Func) and Func.IsConstructor;
end;

function TJSBinarySupport.ToObject(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_OR_UNDEFINED);

  if Value.IsObject then
    Exit(Value.ToObject);

  Result := FInterpreter.WrapPrimitive(Value);
end;

class function TJSBinarySupport.IsCallable(const Value: TJSValue): Boolean;
begin
  var Func: IJSFunction;
  Result := AsFunction(Value, Func);
end;

class function TJSBinarySupport.IsSameObject(const First: IJSObject; const Second: IJSObject): Boolean;
begin
  Result := ((First as IInterface) = (Second as IInterface));
end;

class function TJSBinarySupport.ArgumentsFrom(const Args: TArray<TJSValue>;
                                              const FirstPosition: Integer): TArray<TJSValue>;
begin
  const HasArguments = (Length(Args) > FirstPosition);
  if HasArguments then
    Result := Copy(Args, FirstPosition, Length(Args) - FirstPosition)
  else
    Result := nil;
end;

function TJSBinarySupport.CreateArray(const Items: TArray<TJSValue>): TJSValue;
begin
  const List = TJSArray.Create;
  List.Prototype := FInterpreter.ArrayPrototype;
  for var Item in Items do
  begin
    List.Push(Item);
  end;

  Result := TJSValue.CreateObject(List);
end;

function TJSBinarySupport.ReadSequence(const Source: TJSValue; const NotIterableMessage: string): TArray<TJSValue>;
begin
  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if not FInterpreter.OpenSequenceReader(Source, Reader, Closer) then
    raise TJSErrorFactory.TypeError(NotIterableMessage);

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

function TJSBinarySupport.TypeErrorValue(const Message: string): TJSValue;
begin
  const Error = TJSErrorFactory.TypeError(Message);
  try
    Result := FInterpreter.ExceptionToValue(Error);
  finally
    Error.Free;
  end;
end;

function TJSBinarySupport.Invoke(const Target: TJSValue; const Name: string;
                                 const Args: TArray<TJSValue>): TJSValue;
begin
  const Holder = ToObject(Target);
  const Method = Holder.GetProperty(Name);

  var Func: IJSFunction;
  const IsFunction = AsFunction(Method, Func);
  if not IsFunction then
  begin
    const Message = Format(NOT_A_FUNCTION, [Name]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  const ThisObject = FInterpreter.ThisObjectFor(Func, Target);

  Result := FInterpreter.CallFunction(Func, Args, ThisObject);
end;

function TJSBinarySupport.Capture(const Operation: TFunc<TJSValue>): TJSCallOutcome;
begin
  Result.IsNormal := True;
  Result.Value := TJSValue.CreateUndefined;

  try
    Result.Value := Operation;
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      Result.IsNormal := False;
      Result.Value := FInterpreter.ExceptionToValue(Error);
    end;
  end;
end;

function TJSBinarySupport.CallCapturingThrow(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                             const This: IJSObject): TJSCallOutcome;
begin
  Result := Capture(
    function: TJSValue
    begin
      Result := FInterpreter.CallFunction(Func, Args, This);
    end);
end;

procedure TJSBinarySupport.AttemptIgnoringFailure(const Operation: TProc);
begin
  Capture(
    function: TJSValue
    begin
      Operation;
      Result := TJSValue.CreateUndefined;
    end);
end;

function TJSBinarySupport.CreateMethod(const Name: string; const ParameterCount: Integer;
                                       const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

function TJSBinarySupport.DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                                       const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(Name, ParameterCount, Method);

  DefineMember(Target, Name, TJSValue.CreateObject(Result), True);
end;

procedure TJSBinarySupport.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                        const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBinarySupport.DefineConstant(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBinarySupport.DefineGetter(const Target: IJSObject; const Key: TJSPropertyKey; const FunctionName: string;
                                        const Method: TNativeFunction);
begin
  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.IsAccessor := True;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Descriptor.Getter := TJSValue.CreateObject(CreateMethod(FunctionName, 0, Method));
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBinarySupport.DefineToStringTag(const Target: IJSObject; const Tag: string);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);

  DefineMember(Target, Key, TJSValue.CreateString(Tag), False);
end;

procedure TJSBinarySupport.DefineSpeciesGetter(const Constructor_: IJSObject);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);

  DefineGetter(Constructor_, Key, SPECIES_GETTER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Assigned(This) then
        Result := TJSValue.CreateObject(This)
      else
        Result := TJSValue.CreateUndefined;
    end);
end;

procedure TJSBinarySupport.LinkConstructor(const Constructor_: IJSFunction; const Prototype: IJSObject);
begin
  DefineMember(Prototype, CONSTRUCTOR_PROPERTY, TJSValue.CreateObject(Constructor_), True);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, TJSValue.CreateObject(Prototype));
end;

function TJSBinarySupport.CreateConstructor(const Name: string; const ParameterCount: Integer;
                                            const RequiresNewMessage: string;
                                            const Handler: TJSConstructHandler): IJSFunction;
begin
  Result := TJSConstructorFunction.CreateConstructor(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      raise TJSErrorFactory.TypeError(RequiresNewMessage);
    end,
    Handler);
  Result.Prototype := FInterpreter.FunctionPrototype;

  Result.DeleteProperty(NAME_PROPERTY);
  TJSFunction.DefineLength(Result, ParameterCount);
  TJSFunction.DefineName(Result, Name);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSBinarySupport.UnlinkConstructor(const Prototype: IJSObject);
begin
  if Assigned(Prototype) then
    Prototype.DeleteProperty(CONSTRUCTOR_PROPERTY);
end;

function TJSBinarySupport.PrototypeFromConstructor(const NewTarget: IJSFunction;
                                                   const DefaultPrototype: IJSObject): IJSObject;
begin
  Result := DefaultPrototype;
  if not Assigned(NewTarget) then
    Exit;

  const Candidate = NewTarget.GetProperty(PROTOTYPE_PROPERTY);
  if Candidate.IsObject then
    Result := Candidate.ToObject;
end;

function TJSBinarySupport.SpeciesConstructor(const Source: IJSObject;
                                             const DefaultConstructor: IJSFunction): IJSFunction;
begin
  const ConstructorValue = Source.GetProperty(CONSTRUCTOR_PROPERTY);
  if ConstructorValue.IsUndefined then
    Exit(DefaultConstructor);

  if not ConstructorValue.IsObject then
    raise TJSErrorFactory.TypeError(CONSTRUCTOR_NOT_AN_OBJECT);

  const SpeciesKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);
  const Species = ConstructorValue.ToObject.GetProperty(SpeciesKey);
  if Species.IsNullOrUndefined then
    Exit(DefaultConstructor);

  if not AsConstructor(Species, Result) then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_CONSTRUCTOR);
end;

end.
