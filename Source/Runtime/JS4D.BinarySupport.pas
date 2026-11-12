unit JS4D.BinarySupport;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ProxyObjects;

type
  // What the ArrayBuffer, DataView and typed array builtins have in common: defining functions and accessors,
  // reading arguments, and the conversions of the specification that decide which errors are raised.
  TJSBinarySupport = class
  private
    const
      MAX_SAFE_INTEGER = 9007199254740991.0;
      PROTOTYPE_PROPERTY = 'prototype';
      CONSTRUCTOR_PROPERTY = 'constructor';
      NAME_PROPERTY = 'name';
      SPECIES_GETTER_NAME = 'get [Symbol.species]';
      INVALID_INDEX = 'Invalid index: %s';
      CONSTRUCTOR_NOT_AN_OBJECT = 'The constructor property of the object is not an object';
      SPECIES_NOT_A_CONSTRUCTOR = 'The species of the constructor is not a constructor';
      NULL_OR_UNDEFINED = 'Cannot convert undefined or null to object';

    var
      FInterpreter: TJSInterpreter;

  public
    constructor Create(const Interpreter: TJSInterpreter);

    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    class function ToIntegerOrInfinity(const Value: TJSValue): Double; static;
    class function ToIndex(const Value: TJSValue): Int64; static;
    class function AsFunction(const Value: TJSValue; out Func: IJSFunction): Boolean; static;
    class function AsConstructor(const Value: TJSValue; out Func: IJSFunction): Boolean; static;

    function ToObject(const Value: TJSValue): IJSObject;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    function DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineMember(const Target: IJSObject; const Key: string; const Value: TJSValue;
                           const IsWritable: Boolean);
    procedure DefineConstant(const Target: IJSObject; const Key: string; const Value: TJSValue);
    procedure DefineGetter(const Target: IJSObject; const Key: string; const FunctionName: string;
                           const Method: TNativeFunction);
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    procedure DefineSpeciesGetter(const Constructor_: IJSObject);
    procedure LinkConstructor(const Constructor_: IJSFunction; const Prototype: IJSObject);
    function CreateConstructor(const Name: string; const ParameterCount: Integer; const RequiresNewMessage: string;
                               const Handler: TJSConstructHandler): IJSFunction;
    function PrototypeFromConstructor(const NewTarget: IJSFunction; const DefaultPrototype: IJSObject): IJSObject;
    function SpeciesConstructor(const Source: IJSObject; const DefaultConstructor: IJSFunction): IJSFunction;

    property Interpreter: TJSInterpreter read FInterpreter;
  end;

implementation

uses
  JS4D.Errors,
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

procedure TJSBinarySupport.DefineMember(const Target: IJSObject; const Key: string; const Value: TJSValue;
                                        const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBinarySupport.DefineConstant(const Target: IJSObject; const Key: string; const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSBinarySupport.DefineGetter(const Target: IJSObject; const Key: string; const FunctionName: string;
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
