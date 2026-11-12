unit JS4D.SymbolBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSSymbolBuiltins = class
  private
    type
      TWellKnownProperty = record
        Name: string;
        Which: TJSWellKnownSymbol;
      end;

    const
      WELL_KNOWN_PROPERTIES: array[0..12] of TWellKnownProperty = (
        (Name: 'asyncIterator'; Which: TJSWellKnownSymbol.AsyncIterator),
        (Name: 'hasInstance'; Which: TJSWellKnownSymbol.HasInstance),
        (Name: 'isConcatSpreadable'; Which: TJSWellKnownSymbol.IsConcatSpreadable),
        (Name: 'iterator'; Which: TJSWellKnownSymbol.Iterator),
        (Name: 'match'; Which: TJSWellKnownSymbol.Match),
        (Name: 'matchAll'; Which: TJSWellKnownSymbol.MatchAll),
        (Name: 'replace'; Which: TJSWellKnownSymbol.Replace),
        (Name: 'search'; Which: TJSWellKnownSymbol.Search),
        (Name: 'species'; Which: TJSWellKnownSymbol.Species),
        (Name: 'split'; Which: TJSWellKnownSymbol.Split),
        (Name: 'toPrimitive'; Which: TJSWellKnownSymbol.ToPrimitive),
        (Name: 'toStringTag'; Which: TJSWellKnownSymbol.ToStringTag),
        (Name: 'unscopables'; Which: TJSWellKnownSymbol.Unscopables)
      );

      UNSCOPABLE_ARRAY_METHODS: array[0..10] of string = (
        'at', 'copyWithin', 'entries', 'fill', 'find', 'findIndex', 'flat', 'flatMap', 'includes', 'keys', 'values'
      );

  private
    FInterpreter: TJSInterpreter;
    FRegistry: TDictionary<string, IJSSymbol>;

    function ToText(const Value: TJSValue): string;
    class function ThisSymbolValue(const This: IJSObject; const MethodName: string): TJSValue; static;
    class procedure DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                 const IsConfigurable: Boolean); static;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                           const Method: TNativeFunction);
    procedure DefineSymbolMethod(const Target: IJSObject; const Which: TJSWellKnownSymbol;
                                 const ParameterCount: Integer; const Method: TNativeFunction;
                                 const IsConfigurable: Boolean);
    function ConstructSymbol(const This: IJSObject; const Prototype: IJSObject;
                             const Args: TArray<TJSValue>): TJSValue;
    function SymbolFor(const Args: TArray<TJSValue>): TJSValue;
    function SymbolKeyFor(const Args: TArray<TJSValue>): TJSValue;
    procedure DefineConstructorMembers(const Constructor_: IJSFunction);
    procedure DefinePrototypeMembers(const Prototype: IJSObject);
    procedure DefineHasInstance;
    procedure DefineArrayUnscopables;
    procedure DefineToStringTag(const GlobalName: string);
    function DefineSpeciesGetter(const GlobalName: string): IJSFunction;

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.Symbols;

const
  SYMBOL_NAME = 'Symbol';
  FUNCTION_NAME = 'Function';
  ARRAY_NAME = 'Array';
  REGEXP_NAME = 'RegExp';
  SPECIES_GETTER_NAME = 'get [Symbol.species]';
  MATH_NAME = 'Math';
  JSON_NAME = 'JSON';
  PROTOTYPE_PROPERTY = 'prototype';
  CONSTRUCTOR_PROPERTY = 'constructor';
  METHOD_TO_STRING = 'toString';
  METHOD_VALUE_OF = 'valueOf';
  METHOD_FOR = 'for';
  METHOD_KEY_FOR = 'keyFor';
  PROPERTY_DESCRIPTION = 'description';
  GETTER_DESCRIPTION_NAME = 'get description';
  TO_PRIMITIVE_NAME = '[Symbol.toPrimitive]';
  HAS_INSTANCE_NAME = '[Symbol.hasInstance]';
  SYMBOL_TAG = 'Symbol';
  SYMBOL_NOT_A_CONSTRUCTOR = 'Symbol is not a constructor';
  KEY_FOR_NOT_A_SYMBOL = 'Symbol.keyFor requires a symbol';
  THIS_NOT_A_SYMBOL = 'Symbol.prototype.%s requires that ''this'' be a Symbol';

constructor TJSSymbolBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
  FRegistry := TDictionary<string, IJSSymbol>.Create;
end;

destructor TJSSymbolBuiltins.Destroy;
begin
  FRegistry.Free;
  inherited;
end;

function TJSSymbolBuiltins.ToText(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.String_);

  Result := Primitive.ToLimitedString(FInterpreter.Limits);
end;

class function TJSSymbolBuiltins.ThisSymbolValue(const This: IJSObject; const MethodName: string): TJSValue;
begin
  var Wrapper: IJSPrimitiveWrapper;
  const IsSymbolWrapper = Supports(This, IJSPrimitiveWrapper, Wrapper) and Wrapper.Primitive.IsSymbol;
  if not IsSymbolWrapper then
    raise TJSErrorFactory.TypeError(Format(THIS_NOT_A_SYMBOL, [MethodName]));

  Result := Wrapper.Primitive;
end;

class procedure TJSSymbolBuiltins.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                               const IsConfigurable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := IsConfigurable;
  Target.DefineProperty(Key, Descriptor);
end;

function TJSSymbolBuiltins.CreateMethod(const Name: string; const ParameterCount: Integer;
                                        const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSSymbolBuiltins.DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                                         const Method: TNativeFunction);
begin
  const Func = CreateMethod(Name, ParameterCount, Method);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func));
  Descriptor.Enumerable := False;
  Target.DefineProperty(Name, Descriptor);
end;

procedure TJSSymbolBuiltins.DefineSymbolMethod(const Target: IJSObject; const Which: TJSWellKnownSymbol;
                                               const ParameterCount: Integer; const Method: TNativeFunction;
                                               const IsConfigurable: Boolean);
begin
  const Name = TJSSymbolRegistry.WellKnownDescription(Which);
  const FunctionName = Format('[%s]', [Name]);
  const Func = CreateMethod(FunctionName, ParameterCount, Method);

  DefineMember(Target, TJSSymbolRegistry.WellKnownKey(Which), TJSValue.CreateObject(Func), IsConfigurable);
end;

function TJSSymbolBuiltins.ConstructSymbol(const This: IJSObject; const Prototype: IJSObject;
                                           const Args: TArray<TJSValue>): TJSValue;
begin
  const IsConstructCall = Assigned(This) and ((This.Prototype as IInterface) = (Prototype as IInterface)) and
                          (not Supports(This, IJSPrimitiveWrapper));
  if IsConstructCall then
    raise TJSErrorFactory.TypeError(SYMBOL_NOT_A_CONSTRUCTOR);

  const HasDescription = (Length(Args) > 0) and (not Args[0].IsUndefined);

  var Description := '';
  if HasDescription then
    Description := ToText(Args[0]);

  const NewSymbol: IJSSymbol = TJSSymbolImpl.Create(Description, HasDescription);

  Result := TJSValue.CreateSymbol(NewSymbol);
end;

function TJSSymbolBuiltins.SymbolFor(const Args: TArray<TJSValue>): TJSValue;
begin
  var KeyValue := TJSValue.CreateUndefined;
  if Length(Args) > 0 then
    KeyValue := Args[0];

  const Key = ToText(KeyValue);

  var Registered: IJSSymbol;
  if not FRegistry.TryGetValue(Key, Registered) then
  begin
    Registered := TJSSymbolImpl.Create(Key, True);
    FRegistry.Add(Key, Registered);
  end;

  Result := TJSValue.CreateSymbol(Registered);
end;

function TJSSymbolBuiltins.SymbolKeyFor(const Args: TArray<TJSValue>): TJSValue;
begin
  const IsSymbol = (Length(Args) > 0) and Args[0].IsSymbol;
  if not IsSymbol then
    raise TJSErrorFactory.TypeError(KEY_FOR_NOT_A_SYMBOL);

  const Subject = Args[0].AsObject as IJSSymbol;

  var Found: IJSSymbol;
  const IsRegistered = FRegistry.TryGetValue(Subject.Description, Found) and (Found.Key = Subject.Key);
  if IsRegistered then
    Result := TJSValue.CreateString(Subject.Description)
  else
    Result := TJSValue.CreateUndefined;
end;

procedure TJSSymbolBuiltins.DefineConstructorMembers(const Constructor_: IJSFunction);
begin
  for var Entry in WELL_KNOWN_PROPERTIES do
  begin
    DefineMember(Constructor_, Entry.Name, TJSWellKnownSymbols.Value(Entry.Which), False);
  end;

  DefineMethod(Constructor_, METHOD_FOR, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SymbolFor(Args);
    end);

  DefineMethod(Constructor_, METHOD_KEY_FOR, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SymbolKeyFor(Args);
    end);
end;

procedure TJSSymbolBuiltins.DefinePrototypeMembers(const Prototype: IJSObject);
begin
  DefineMethod(Prototype, METHOD_TO_STRING, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const SymbolValue = ThisSymbolValue(This, METHOD_TO_STRING);

      Result := TJSValue.CreateString(SymbolValue.SymbolDescriptiveString);
    end);

  DefineMethod(Prototype, METHOD_VALUE_OF, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ThisSymbolValue(This, METHOD_VALUE_OF);
    end);

  var DescriptionDescriptor := Default(TJSPropertyDescriptor);
  DescriptionDescriptor.IsAccessor := True;
  DescriptionDescriptor.Enumerable := False;
  DescriptionDescriptor.Configurable := True;
  const Getter = CreateMethod(GETTER_DESCRIPTION_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const SymbolValue = ThisSymbolValue(This, PROPERTY_DESCRIPTION);
      const Symbol = SymbolValue.AsObject as IJSSymbol;

      if Symbol.HasDescription then
        Result := TJSValue.CreateString(Symbol.Description)
      else
        Result := TJSValue.CreateUndefined;
    end);
  DescriptionDescriptor.Getter := TJSValue.CreateObject(Getter);
  Prototype.DefineProperty(PROPERTY_DESCRIPTION, DescriptionDescriptor);

  DefineSymbolMethod(Prototype, TJSWellKnownSymbol.ToPrimitive, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ThisSymbolValue(This, TO_PRIMITIVE_NAME);
    end, True);

  DefineMember(Prototype, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag),
               TJSValue.CreateString(SYMBOL_TAG), True);
end;

procedure TJSSymbolBuiltins.DefineHasInstance;
begin
  const FunctionValue = FInterpreter.GetGlobalVariable(FUNCTION_NAME);
  const FunctionPrototype = FunctionValue.ToObject.GetProperty(PROTOTYPE_PROPERTY).ToObject;

  const Method = CreateMethod(HAS_INSTANCE_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Candidate: IJSFunction;
      if not Supports(This, IJSFunction, Candidate) then
        Exit(TJSValue.CreateBoolean(False));

      var Subject := TJSValue.CreateUndefined;
      if Length(Args) > 0 then
        Subject := Args[0];

      Result := TJSValue.CreateBoolean(FInterpreter.OrdinaryHasInstance(Candidate, Subject));
    end);

  FInterpreter.OrdinaryHasInstanceFunction := Method;
  DefineMember(FunctionPrototype, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.HasInstance),
               TJSValue.CreateObject(Method), False);
end;

procedure TJSSymbolBuiltins.DefineArrayUnscopables;
begin
  const ArrayValue = FInterpreter.GetGlobalVariable(ARRAY_NAME);
  const ArrayPrototype = ArrayValue.ToObject.GetProperty(PROTOTYPE_PROPERTY).ToObject;

  const Unscopables: IJSObject = TJSObject.Create;
  for var MethodName in UNSCOPABLE_ARRAY_METHODS do
  begin
    Unscopables.DefineProperty(MethodName, TJSPropertyDescriptor.Create(TJSValue.CreateBoolean(True)));
  end;

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Unscopables));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  ArrayPrototype.DefineProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Unscopables), Descriptor);
end;

procedure TJSSymbolBuiltins.DefineToStringTag(const GlobalName: string);
begin
  const Target = FInterpreter.GetGlobalVariable(GlobalName).ToObject;

  DefineMember(Target, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag),
               TJSValue.CreateString(GlobalName), True);
end;

function TJSSymbolBuiltins.DefineSpeciesGetter(const GlobalName: string): IJSFunction;
begin
  const Target = FInterpreter.GetGlobalVariable(GlobalName).ToObject;

  Result := CreateMethod(SPECIES_GETTER_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Assigned(This) then
        Result := TJSValue.CreateObject(This)
      else
        Result := TJSValue.CreateUndefined;
    end);

  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.IsAccessor := True;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Descriptor.Getter := TJSValue.CreateObject(Result);
  Target.DefineProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species), Descriptor);
end;

procedure TJSSymbolBuiltins.Register;
begin
  const Prototype: IJSObject = TJSObject.Create;
  Prototype.Prototype := FInterpreter.ObjectPrototype;

  const Constructor_ = TJSFunction.CreateNative(SYMBOL_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ConstructSymbol(This, Prototype, Args);
    end);
  Constructor_.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Constructor_, 0);

  var ConstructorDescriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Constructor_));
  ConstructorDescriptor.Enumerable := False;
  Prototype.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, TJSValue.CreateObject(Prototype));
  FInterpreter.RegisterFunction(Constructor_);

  DefineConstructorMembers(Constructor_);
  DefinePrototypeMembers(Prototype);
  FInterpreter.SymbolPrototype := Prototype;
  FInterpreter.SetGlobalVariable(SYMBOL_NAME, TJSValue.CreateObject(Constructor_));

  DefineHasInstance;
  DefineArrayUnscopables;
  DefineToStringTag(MATH_NAME);
  DefineToStringTag(JSON_NAME);

  FInterpreter.ArrayConstructor := FInterpreter.GetGlobalVariable(ARRAY_NAME).ToObject as IJSFunction;
  FInterpreter.ArraySpeciesGetter := DefineSpeciesGetter(ARRAY_NAME);
  DefineSpeciesGetter(REGEXP_NAME);
end;

end.
