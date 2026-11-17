unit JS4D.SymbolBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter,
  JS4D.BuiltinSupport,
  JS4D.WellKnownSymbolHooks;

type
  TJSSymbolBuiltins = class
  private
    const
      SYMBOL_NAME = 'Symbol';
      SYMBOL_DESCRIPTION_PREFIX = 'Symbol.';
      METHOD_TO_STRING = 'toString';
      METHOD_VALUE_OF = 'valueOf';
      METHOD_FOR = 'for';
      METHOD_KEY_FOR = 'keyFor';
      PROPERTY_DESCRIPTION = 'description';
      GETTER_DESCRIPTION_NAME = 'get description';
      TO_PRIMITIVE_NAME = '[Symbol.toPrimitive]';
      SYMBOL_TAG = 'Symbol';
      SYMBOL_NOT_A_CONSTRUCTOR = 'Symbol is not a constructor';
      KEY_FOR_NOT_A_SYMBOL = 'Symbol.keyFor requires a symbol';
      THIS_NOT_A_SYMBOL = 'Symbol.prototype.%s requires that ''this'' be a Symbol';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FHooks: TJSWellKnownSymbolHooks;
      FRegistry: TDictionary<string, IJSSymbol>;

    class function ThisSymbolValue(const This: IJSObject; const MethodName: string): TJSValue; static;
    class function WellKnownPropertyName(const Which: TJSWellKnownSymbol): string; static;
    function ToText(const Value: TJSValue): string;
    function IsSymbolConstructCall(const This: IJSObject; const Prototype: IJSObject): Boolean;
    function ConstructSymbol(const This: IJSObject; const Prototype: IJSObject;
                             const Args: TArray<TJSValue>): TJSValue;
    function SymbolFor(const Args: TArray<TJSValue>): TJSValue;
    function SymbolKeyFor(const Args: TArray<TJSValue>): TJSValue;
    function DescriptionOf(const This: IJSObject): TJSValue;
    procedure DefineConstructorMembers(const Constructor_: IJSFunction);
    procedure DefinePrototypeMembers(const Prototype: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.Conversions,
  JS4D.Symbols;

constructor TJSSymbolBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
  FHooks := TJSWellKnownSymbolHooks.Create(Interpreter, FSupport);
  FRegistry := TDictionary<string, IJSSymbol>.Create;
end;

destructor TJSSymbolBuiltins.Destroy;
begin
  FRegistry.Free;
  FHooks.Free;
  FSupport.Free;
  inherited;
end;

function TJSSymbolBuiltins.ToText(const Value: TJSValue): string;
begin
  Result := TJSConversions.ToText(Value, FInterpreter.Limits);
end;

class function TJSSymbolBuiltins.ThisSymbolValue(const This: IJSObject; const MethodName: string): TJSValue;
begin
  var Wrapper: IJSPrimitiveWrapper;
  const IsSymbolWrapper = Supports(This, IJSPrimitiveWrapper, Wrapper) and Wrapper.Primitive.IsSymbol;
  if not IsSymbolWrapper then
  begin
    const Message = Format(THIS_NOT_A_SYMBOL, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := Wrapper.Primitive;
end;

class function TJSSymbolBuiltins.WellKnownPropertyName(const Which: TJSWellKnownSymbol): string;
begin
  const Description = TJSSymbolRegistry.WellKnownDescription(Which);

  Result := Description.Substring(Length(SYMBOL_DESCRIPTION_PREFIX));
end;

function TJSSymbolBuiltins.IsSymbolConstructCall(const This: IJSObject; const Prototype: IJSObject): Boolean;
begin
  const HasThis = Assigned(This);
  if not HasThis then
    Exit(False);

  const HasSymbolPrototype = ((This.Prototype as IInterface) = (Prototype as IInterface));
  const IsWrapper = Supports(This, IJSPrimitiveWrapper);

  Result := HasSymbolPrototype and (not IsWrapper);
end;

function TJSSymbolBuiltins.ConstructSymbol(const This: IJSObject; const Prototype: IJSObject;
                                           const Args: TArray<TJSValue>): TJSValue;
begin
  if IsSymbolConstructCall(This, Prototype) then
    raise TJSErrorFactory.TypeError(SYMBOL_NOT_A_CONSTRUCTOR);

  const DescriptionArgument = TJSArrayLike.Argument(Args, 0);
  const HasDescription = (not DescriptionArgument.IsUndefined);

  var Description := '';
  if HasDescription then
    Description := ToText(DescriptionArgument);

  const NewSymbol: IJSSymbol = TJSSymbolImpl.Create(Description, HasDescription);

  Result := TJSValue.CreateSymbol(NewSymbol);
end;

function TJSSymbolBuiltins.SymbolFor(const Args: TArray<TJSValue>): TJSValue;
begin
  const KeyValue = TJSArrayLike.Argument(Args, 0);
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
  const SymbolArgument = TJSArrayLike.Argument(Args, 0);
  if not SymbolArgument.IsSymbol then
    raise TJSErrorFactory.TypeError(KEY_FOR_NOT_A_SYMBOL);

  const Subject = SymbolArgument.AsObject as IJSSymbol;

  var Found: IJSSymbol;
  const IsKnown = FRegistry.TryGetValue(Subject.Description, Found);
  const IsRegistered = IsKnown and (Found.Key = Subject.Key);
  if IsRegistered then
    Result := TJSValue.CreateString(Subject.Description)
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSSymbolBuiltins.DescriptionOf(const This: IJSObject): TJSValue;
begin
  const SymbolValue = ThisSymbolValue(This, PROPERTY_DESCRIPTION);
  const Symbol = SymbolValue.AsObject as IJSSymbol;

  if Symbol.HasDescription then
    Result := TJSValue.CreateString(Symbol.Description)
  else
    Result := TJSValue.CreateUndefined;
end;

procedure TJSSymbolBuiltins.DefineConstructorMembers(const Constructor_: IJSFunction);
begin
  for var Which := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    const PropertyName = WellKnownPropertyName(Which);
    FSupport.DefineConstant(Constructor_, PropertyName, TJSWellKnownSymbols.Value(Which));
  end;

  FSupport.DefineMethod(Constructor_, METHOD_FOR, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SymbolFor(Args);
    end);

  FSupport.DefineMethod(Constructor_, METHOD_KEY_FOR, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SymbolKeyFor(Args);
    end);
end;

procedure TJSSymbolBuiltins.DefinePrototypeMembers(const Prototype: IJSObject);
begin
  FSupport.DefineMethod(Prototype, METHOD_TO_STRING, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const SymbolValue = ThisSymbolValue(This, METHOD_TO_STRING);

      Result := TJSValue.CreateString(SymbolValue.SymbolDescriptiveString);
    end);

  FSupport.DefineMethod(Prototype, METHOD_VALUE_OF, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ThisSymbolValue(This, METHOD_VALUE_OF);
    end);

  FSupport.DefineGetter(Prototype, PROPERTY_DESCRIPTION, GETTER_DESCRIPTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := DescriptionOf(This);
    end);

  const ToPrimitiveKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToPrimitive);
  const ToPrimitiveMethod = FSupport.CreateMethod(TO_PRIMITIVE_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ThisSymbolValue(This, TO_PRIMITIVE_NAME);
    end);
  FSupport.DefineMember(Prototype, ToPrimitiveKey, TJSValue.CreateObject(ToPrimitiveMethod), False);

  FSupport.DefineToStringTag(Prototype, SYMBOL_TAG);
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

  FSupport.LinkConstructor(Constructor_, Prototype);
  FInterpreter.RegisterFunction(Constructor_);

  DefineConstructorMembers(Constructor_);
  DefinePrototypeMembers(Prototype);
  FInterpreter.SymbolPrototype := Prototype;
  FInterpreter.SetGlobalVariable(SYMBOL_NAME, TJSValue.CreateObject(Constructor_));

  FHooks.Register;
end;

end.
