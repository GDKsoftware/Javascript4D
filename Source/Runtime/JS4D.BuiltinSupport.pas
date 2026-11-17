unit JS4D.BuiltinSupport;

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
  JS4D.ConstructorFunction;

type
  TJSCallOutcome = record
    IsNormal: Boolean;
    Value: TJSValue;
  end;

  TJSBuiltinSupport = class
  private
    const
      INVALID_INDEX = 'Invalid index: %s';
      DETACHED_BUFFER = 'Cannot perform %s on a detached ArrayBuffer';
      NOT_A_FUNCTION = '%s is not a function';

    var
      FInterpreter: TJSInterpreter;

  public
    constructor Create(const Interpreter: TJSInterpreter);

    class function ToIndex(const Value: TJSValue): Int64; static;
    class function IsCallable(const Value: TJSValue): Boolean; static;
    class function ReturnsThis: TNativeFunction; static;
    class procedure RequireNotDetached(const IsDetached: Boolean; const MethodName: string); static;
    class function ArgumentsFrom(const Args: TArray<TJSValue>; const FirstPosition: Integer): TArray<TJSValue>; static;

    function ToObject(const Value: TJSValue): IJSObject;
    function CreateArray(const Items: TArray<TJSValue>): TJSValue;
    function TryReadSequence(const Source: TJSValue; out Items: TArray<TJSValue>): Boolean;
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
    function DefineGetter(const Target: IJSObject; const Key: TJSPropertyKey; const FunctionName: string;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    function DefineSpeciesGetter(const Constructor_: IJSObject): IJSFunction;
    procedure LinkConstructor(const Constructor_: IJSFunction; const Prototype: IJSObject);
    procedure UnlinkConstructor(const Prototype: IJSObject);
    function CreateConstructor(const Name: string; const ParameterCount: Integer; const RequiresNewMessage: string;
                               const Handler: TJSConstructHandler): IJSFunction;
    function PrototypeFromConstructor(const NewTarget: IJSFunction; const DefaultPrototype: IJSObject): IJSObject;

    property Interpreter: TJSInterpreter read FInterpreter;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.Conversions,
  JS4D.Errors,
  JS4D.ArrayStatics,
  JS4D.SymbolRegistry;

constructor TJSBuiltinSupport.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

class function TJSBuiltinSupport.ToIndex(const Value: TJSValue): Int64;
begin
  if Value.IsUndefined then
    Exit(0);

  const Whole = TJSConversions.ToIntegerOrInfinity(Value);
  const IsValid = (Whole >= 0) and (Whole <= MAX_SAFE_INTEGER);
  if not IsValid then
  begin
    const Message = Format(INVALID_INDEX, [Value.ToString]);
    raise TJSErrorFactory.RangeError(Message);
  end;

  Result := Trunc(Whole);
end;

function TJSBuiltinSupport.ToObject(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  if Value.IsObject then
  begin
    Result := Value.ToObject;
    Exit;
  end;

  Result := FInterpreter.WrapPrimitive(Value);
end;

class function TJSBuiltinSupport.IsCallable(const Value: TJSValue): Boolean;
begin
  var Func: IJSFunction;
  Result := Value.TryGetFunction(Func);
end;

class procedure TJSBuiltinSupport.RequireNotDetached(const IsDetached: Boolean; const MethodName: string);
begin
  if not IsDetached then
    Exit;

  const Message = Format(DETACHED_BUFFER, [MethodName]);
  raise TJSErrorFactory.TypeError(Message);
end;

class function TJSBuiltinSupport.ReturnsThis: TNativeFunction;
begin
  Result :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Assigned(This) then
        Result := TJSValue.CreateObject(This)
      else
        Result := TJSValue.CreateUndefined;
    end;
end;

class function TJSBuiltinSupport.ArgumentsFrom(const Args: TArray<TJSValue>;
                                              const FirstPosition: Integer): TArray<TJSValue>;
begin
  const HasArguments = (Length(Args) > FirstPosition);
  if HasArguments then
    Result := Copy(Args, FirstPosition, Length(Args) - FirstPosition)
  else
    Result := nil;
end;

function TJSBuiltinSupport.CreateArray(const Items: TArray<TJSValue>): TJSValue;
begin
  Result := TJSArrayLike.CreateArray(FInterpreter.ArrayPrototype, Items);
end;

function TJSBuiltinSupport.TryReadSequence(const Source: TJSValue; out Items: TArray<TJSValue>): Boolean;
begin
  Items := nil;

  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  Result := FInterpreter.OpenSequenceReader(Source, Reader, Closer);
  if not Result then
    Exit;

  const Collected = TList<TJSValue>.Create;
  try
    var Item: TJSValue;
    while Reader(Item) do
    begin
      Collected.Add(Item);
    end;

    Items := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

function TJSBuiltinSupport.ReadSequence(const Source: TJSValue; const NotIterableMessage: string): TArray<TJSValue>;
begin
  if not TryReadSequence(Source, Result) then
    raise TJSErrorFactory.TypeError(NotIterableMessage);
end;

function TJSBuiltinSupport.TypeErrorValue(const Message: string): TJSValue;
begin
  const Error = TJSErrorFactory.TypeError(Message);
  try
    Result := FInterpreter.ExceptionToValue(Error);
  finally
    Error.Free;
  end;
end;

function TJSBuiltinSupport.Invoke(const Target: TJSValue; const Name: string;
                                 const Args: TArray<TJSValue>): TJSValue;
begin
  const Holder = ToObject(Target);
  const Method = Holder.GetProperty(Name);

  var Func: IJSFunction;
  const IsFunction = Method.TryGetFunction(Func);
  if not IsFunction then
  begin
    const Message = Format(NOT_A_FUNCTION, [Name]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  const ThisObject = FInterpreter.ThisObjectFor(Func, Target);

  Result := FInterpreter.CallFunction(Func, Args, ThisObject);
end;

function TJSBuiltinSupport.Capture(const Operation: TFunc<TJSValue>): TJSCallOutcome;
begin
  Result.IsNormal := True;
  Result.Value := TJSValue.CreateUndefined;

  try
    Result.Value := Operation;
  except
    on EJSExecutionInterrupted do
      raise;
    on EOutOfMemory do
      raise;
    on EAccessViolation do
      raise;
    on Error: Exception do
    begin
      Result.IsNormal := False;
      Result.Value := FInterpreter.ExceptionToValue(Error);
    end;
  end;
end;

function TJSBuiltinSupport.CallCapturingThrow(const Func: IJSFunction; const Args: TArray<TJSValue>;
                                             const This: IJSObject): TJSCallOutcome;
begin
  Result := Capture(
    function: TJSValue
    begin
      Result := FInterpreter.CallFunction(Func, Args, This);
    end);
end;

procedure TJSBuiltinSupport.AttemptIgnoringFailure(const Operation: TProc);
begin
  Capture(
    function: TJSValue
    begin
      Operation;
      Result := TJSValue.CreateUndefined;
    end);
end;

function TJSBuiltinSupport.CreateMethod(const Name: string; const ParameterCount: Integer;
                                       const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

function TJSBuiltinSupport.DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                                       const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(Name, ParameterCount, Method);

  const MethodValue = TJSValue.CreateObject(Result);
  DefineMember(Target, Name, MethodValue, True);
end;

procedure TJSBuiltinSupport.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                        const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBuiltinSupport.DefineConstant(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Key, Descriptor);
end;

function TJSBuiltinSupport.DefineGetter(const Target: IJSObject; const Key: TJSPropertyKey;
                                        const FunctionName: string; const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(FunctionName, 0, Method);

  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.IsAccessor := True;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Descriptor.Getter := TJSValue.CreateObject(Result);
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBuiltinSupport.DefineToStringTag(const Target: IJSObject; const Tag: string);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);

  const TagValue = TJSValue.CreateString(Tag);
  DefineMember(Target, Key, TagValue, False);
end;

function TJSBuiltinSupport.DefineSpeciesGetter(const Constructor_: IJSObject): IJSFunction;
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);

  const Getter = ReturnsThis();

  Result := DefineGetter(Constructor_, Key, SPECIES_GETTER_NAME, Getter);
end;

procedure TJSBuiltinSupport.LinkConstructor(const Constructor_: IJSFunction; const Prototype: IJSObject);
begin
  const ConstructorValue = TJSValue.CreateObject(Constructor_);
  const PrototypeValue = TJSValue.CreateObject(Prototype);

  DefineMember(Prototype, CONSTRUCTOR_PROPERTY, ConstructorValue, True);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, PrototypeValue);
end;

function TJSBuiltinSupport.CreateConstructor(const Name: string; const ParameterCount: Integer;
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

procedure TJSBuiltinSupport.UnlinkConstructor(const Prototype: IJSObject);
begin
  if Assigned(Prototype) then
    Prototype.DeleteProperty(CONSTRUCTOR_PROPERTY);
end;

function TJSBuiltinSupport.PrototypeFromConstructor(const NewTarget: IJSFunction;
                                                   const DefaultPrototype: IJSObject): IJSObject;
begin
  Result := DefaultPrototype;
  if not Assigned(NewTarget) then
    Exit;

  const Candidate = NewTarget.GetProperty(PROTOTYPE_PROPERTY);
  if Candidate.IsObject then
    Result := Candidate.ToObject;
end;

end.
