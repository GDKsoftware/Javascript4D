unit JS4D.WellKnownSymbolHooks;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.ArrayLike,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSWellKnownSymbolHooks = class
  private
    const
      MATH_NAME = 'Math';
      JSON_NAME = 'JSON';
      REGEXP_NAME = 'RegExp';
      ARRAY_NAME = 'Array';
      HAS_INSTANCE_NAME = '[Symbol.hasInstance]';
      UNSCOPABLE_ARRAY_METHODS: array[0..10] of string = (
        'at', 'copyWithin', 'entries', 'fill', 'find', 'findIndex', 'flat', 'flatMap', 'includes', 'keys', 'values'
      );

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;

    function HasInstanceMethod: IJSFunction;
    procedure DefineHasInstance;
    procedure DefineArrayUnscopables;
    procedure DefineToStringTag(const GlobalName: string);
    function DefineSpeciesGetter(const GlobalName: string): IJSFunction;

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);

    procedure Register;
  end;

implementation

constructor TJSWellKnownSymbolHooks.Create(const Interpreter: TJSInterpreter; const Support: TJSBuiltinSupport);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
end;

function TJSWellKnownSymbolHooks.HasInstanceMethod: IJSFunction;
begin
  Result := FSupport.CreateMethod(HAS_INSTANCE_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Candidate: IJSFunction;
      if not Supports(This, IJSFunction, Candidate) then
      begin
        Result := TJSValue.CreateBoolean(False);
        Exit;
      end;

      const Subject = TJSArrayLike.Argument(Args, 0);
      const IsInstance = FInterpreter.OrdinaryHasInstance(Candidate, Subject);

      Result := TJSValue.CreateBoolean(IsInstance);
    end);
end;

procedure TJSWellKnownSymbolHooks.DefineHasInstance;
begin
  const Method = HasInstanceMethod;
  FInterpreter.OrdinaryHasInstanceFunction := Method;

  const HasInstanceKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.HasInstance);
  FSupport.DefineConstant(FInterpreter.FunctionPrototype, HasInstanceKey, TJSValue.CreateObject(Method));
end;

procedure TJSWellKnownSymbolHooks.DefineArrayUnscopables;
begin
  const Unscopables: IJSObject = TJSObject.Create;
  for var MethodName in UNSCOPABLE_ARRAY_METHODS do
  begin
    const IsUnscopable = TJSValue.CreateBoolean(True);
    Unscopables.DefineProperty(MethodName, TJSPropertyDescriptor.Create(IsUnscopable));
  end;

  const UnscopablesKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Unscopables);
  FSupport.DefineMember(FInterpreter.ArrayPrototype, UnscopablesKey, TJSValue.CreateObject(Unscopables), False);
end;

procedure TJSWellKnownSymbolHooks.DefineToStringTag(const GlobalName: string);
begin
  const GlobalValue = FInterpreter.GetGlobalVariable(GlobalName);

  FSupport.DefineToStringTag(GlobalValue.ToObject, GlobalName);
end;

function TJSWellKnownSymbolHooks.DefineSpeciesGetter(const GlobalName: string): IJSFunction;
begin
  const GlobalValue = FInterpreter.GetGlobalVariable(GlobalName);

  Result := FSupport.DefineSpeciesGetter(GlobalValue.ToObject);
end;

procedure TJSWellKnownSymbolHooks.Register;
begin
  DefineHasInstance;
  DefineArrayUnscopables;
  DefineToStringTag(MATH_NAME);
  DefineToStringTag(JSON_NAME);

  const ArrayValue = FInterpreter.GetGlobalVariable(ARRAY_NAME);
  FInterpreter.ArrayConstructor := ArrayValue.ToObject as IJSFunction;
  FInterpreter.ArraySpeciesGetter := DefineSpeciesGetter(ARRAY_NAME);
  DefineSpeciesGetter(REGEXP_NAME);
end;

end.
