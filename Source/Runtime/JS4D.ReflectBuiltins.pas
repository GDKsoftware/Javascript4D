unit JS4D.ReflectBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSReflectBuiltins = class(TJSBuiltinSet)
  private
    type
      TReflectMethod = function(const Args: TArray<TJSValue>): TJSValue of object;

    const
      REFLECT_NAME = 'Reflect';
      REFLECT_TAG = 'Reflect';
      APPLY_NAME = 'apply';
      CONSTRUCT_NAME = 'construct';
      DEFINE_PROPERTY_NAME = 'defineProperty';
      DELETE_PROPERTY_NAME = 'deleteProperty';
      GET_NAME = 'get';
      GET_OWN_PROPERTY_DESCRIPTOR_NAME = 'getOwnPropertyDescriptor';
      GET_PROTOTYPE_OF_NAME = 'getPrototypeOf';
      HAS_NAME = 'has';
      IS_EXTENSIBLE_NAME = 'isExtensible';
      OWN_KEYS_NAME = 'ownKeys';
      PREVENT_EXTENSIONS_NAME = 'preventExtensions';
      SET_NAME = 'set';
      SET_PROTOTYPE_OF_NAME = 'setPrototypeOf';
      NOT_AN_OBJECT = 'Reflect.%s called on a non-object';
      NOT_CALLABLE = 'Reflect.%s requires a function as its target';
      NOT_A_CONSTRUCTOR = 'Reflect.construct requires a constructor';
      ARGUMENT_LIST_NOT_AN_OBJECT = 'The argument list must be an object';
      PROTOTYPE_NOT_AN_OBJECT = 'Object prototype may only be an Object or null';

    var
      FInterpreter: TJSInterpreter;

    function RequireTarget(const Args: TArray<TJSValue>; const MethodName: string): IJSObject;
    function RequireObject(const Value: TJSValue; const MethodName: string): IJSObject;
    function RequireFunction(const Value: TJSValue; const MethodName: string): IJSFunction;
    function RequireConstructor(const Value: TJSValue): IJSFunction;
    function KeyOf(const Args: TArray<TJSValue>; const Position: Integer): TJSPropertyKey;
    function ListFromArrayLike(const Value: TJSValue): TArray<TJSValue>;
    function ArrayFromKeys(const Keys: TArray<TJSPropertyKey>): TJSValue;
    function ReceiverOf(const Args: TArray<TJSValue>; const Position: Integer; const Target: IJSObject): TJSValue;

    function Apply(const Args: TArray<TJSValue>): TJSValue;
    function Construct(const Args: TArray<TJSValue>): TJSValue;
    function DefineProperty(const Args: TArray<TJSValue>): TJSValue;
    function DeleteProperty(const Args: TArray<TJSValue>): TJSValue;
    function Get(const Args: TArray<TJSValue>): TJSValue;
    function GetOwnPropertyDescriptor(const Args: TArray<TJSValue>): TJSValue;
    function GetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
    function Has(const Args: TArray<TJSValue>): TJSValue;
    function IsExtensible(const Args: TArray<TJSValue>): TJSValue;
    function OwnKeys(const Args: TArray<TJSValue>): TJSValue;
    function PreventExtensions(const Args: TArray<TJSValue>): TJSValue;
    function Put(const Args: TArray<TJSValue>): TJSValue;
    function SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;

    procedure DefineFunction(const Reflect: IJSObject; const Name: string; const ParameterCount: Integer;
                             const Method: TReflectMethod);
    procedure DefineToStringTag(const Reflect: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Register; override;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.ObjectOperations,
  JS4D.PropertyDescriptors;

constructor TJSReflectBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

function TJSReflectBuiltins.RequireTarget(const Args: TArray<TJSValue>; const MethodName: string): IJSObject;
begin
  const TargetValue = TJSArrayLike.Argument(Args, 0);

  Result := RequireObject(TargetValue, MethodName);
end;

function TJSReflectBuiltins.RequireObject(const Value: TJSValue; const MethodName: string): IJSObject;
begin
  if not Value.IsObject then
  begin
    const Message = Format(NOT_AN_OBJECT, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := Value.ToObject;
end;

function TJSReflectBuiltins.RequireFunction(const Value: TJSValue; const MethodName: string): IJSFunction;
begin
  const IsCallable = Value.IsFunction and Supports(Value.ToObject, IJSFunction, Result);
  if not IsCallable then
  begin
    const Message = Format(NOT_CALLABLE, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSReflectBuiltins.RequireConstructor(const Value: TJSValue): IJSFunction;
begin
  const IsConstructor = Value.IsFunction and Supports(Value.ToObject, IJSFunction, Result) and Result.IsConstructor;
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);
end;

function TJSReflectBuiltins.KeyOf(const Args: TArray<TJSValue>; const Position: Integer): TJSPropertyKey;
begin
  const KeyValue = TJSArrayLike.Argument(Args, Position);

  Result := KeyValue.ToPropertyKey(FInterpreter.Limits);
end;

function TJSReflectBuiltins.ListFromArrayLike(const Value: TJSValue): TArray<TJSValue>;
begin
  if not Value.IsObject then
    raise TJSErrorFactory.TypeError(ARGUMENT_LIST_NOT_AN_OBJECT);

  const Source = Value.ToObject;
  const Count = TJSArrayLike.ToLength(Source);
  FInterpreter.Limits.EnsureArrayLength(Count);

  SetLength(Result, Count);
  for var Index := 0 to Count - 1 do
  begin
    const ElementName = TJSArrayLike.IndexName(Index);
    Result[Index] := Source.GetProperty(ElementName);
  end;
end;

function TJSReflectBuiltins.ArrayFromKeys(const Keys: TArray<TJSPropertyKey>): TJSValue;
begin
  var KeyValues: TArray<TJSValue>;
  SetLength(KeyValues, Length(Keys));
  for var Index := 0 to Length(Keys) - 1 do
  begin
    KeyValues[Index] := TJSObjectOperations.KeyToValue(Keys[Index]);
  end;

  Result := TJSArrayLike.CreateArray(FInterpreter.ArrayPrototype, KeyValues);
end;

function TJSReflectBuiltins.ReceiverOf(const Args: TArray<TJSValue>; const Position: Integer;
                                       const Target: IJSObject): TJSValue;
begin
  const HasReceiver = (Position < Length(Args));
  if HasReceiver then
  begin
    Result := Args[Position];
    Exit;
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSReflectBuiltins.Apply(const Args: TArray<TJSValue>): TJSValue;
begin
  const TargetValue = TJSArrayLike.Argument(Args, 0);
  const Func = RequireFunction(TargetValue, APPLY_NAME);

  const ArgumentList = TJSArrayLike.Argument(Args, 2);
  const CallArguments = ListFromArrayLike(ArgumentList);

  const ThisValue = TJSArrayLike.Argument(Args, 1);
  const ThisReceiver = FInterpreter.ThisObjectFor(Func, ThisValue);

  Result := FInterpreter.CallFunction(Func, CallArguments, ThisReceiver);
end;

function TJSReflectBuiltins.Construct(const Args: TArray<TJSValue>): TJSValue;
begin
  const TargetValue = TJSArrayLike.Argument(Args, 0);
  const Func = RequireConstructor(TargetValue);

  var NewTarget := Func;
  const HasNewTarget = (Length(Args) > 2);
  if HasNewTarget then
    NewTarget := RequireConstructor(Args[2]);

  const ArgumentList = TJSArrayLike.Argument(Args, 1);
  const CallArguments = ListFromArrayLike(ArgumentList);

  Result := FInterpreter.Construct(Func, CallArguments, NewTarget);
end;

function TJSReflectBuiltins.DefineProperty(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, DEFINE_PROPERTY_NAME);
  const Key = KeyOf(Args, 1);

  const DescriptorValue = TJSArrayLike.Argument(Args, 2);
  const Definition = TJSPropertyDescriptors.ToDefinition(DescriptorValue);
  const Checked = TJSPropertyDescriptors.WithCheckedLength(Target, Key, Definition, FInterpreter.Limits);
  const IsDefined = Target.DefineOwnProperty(Key, Checked);

  Result := TJSValue.CreateBoolean(IsDefined);
end;

function TJSReflectBuiltins.DeleteProperty(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, DELETE_PROPERTY_NAME);

  const Key = KeyOf(Args, 1);
  const IsDeleted = TJSObjectOperations.DeleteOwnProperty(Target, Key);

  Result := TJSValue.CreateBoolean(IsDeleted);
end;

function TJSReflectBuiltins.Get(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, GET_NAME);
  const Key = KeyOf(Args, 1);

  const Receiver = ReceiverOf(Args, 2, Target);

  Result := TJSObjectOperations.GetWithReceiver(Target, Key, Receiver);
end;

function TJSReflectBuiltins.GetOwnPropertyDescriptor(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, GET_OWN_PROPERTY_DESCRIPTOR_NAME);
  const Key = KeyOf(Args, 1);

  var Descriptor: TJSPropertyDescriptor;
  const IsFound = TJSObjectOperations.TryGetOwnProperty(Target, Key, Descriptor);
  if not IsFound then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const Described = TJSPropertyDescriptors.ToDescriptorObject(Descriptor, FInterpreter.ObjectPrototype);
  Result := TJSValue.CreateObject(Described);
end;

function TJSReflectBuiltins.GetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, GET_PROTOTYPE_OF_NAME);
  const Prototype = Target.Prototype;

  if Assigned(Prototype) then
    Result := TJSValue.CreateObject(Prototype)
  else
    Result := TJSValue.CreateNull;
end;

function TJSReflectBuiltins.Has(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, HAS_NAME);

  const Key = KeyOf(Args, 1);
  const HasKey = Target.HasProperty(Key);

  Result := TJSValue.CreateBoolean(HasKey);
end;

function TJSReflectBuiltins.IsExtensible(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, IS_EXTENSIBLE_NAME);

  const IsOpen = Target.IsExtensible;

  Result := TJSValue.CreateBoolean(IsOpen);
end;

function TJSReflectBuiltins.OwnKeys(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, OWN_KEYS_NAME);

  const Keys = TJSObjectOperations.OwnKeys(Target);

  Result := ArrayFromKeys(Keys);
end;

function TJSReflectBuiltins.PreventExtensions(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, PREVENT_EXTENSIONS_NAME);

  const IsPrevented = TJSObjectOperations.PreventExtensions(Target);

  Result := TJSValue.CreateBoolean(IsPrevented);
end;

function TJSReflectBuiltins.Put(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, SET_NAME);
  const Key = KeyOf(Args, 1);

  const Value = TJSArrayLike.Argument(Args, 2);
  const Receiver = ReceiverOf(Args, 3, Target);
  const IsAssigned = TJSObjectOperations.SetWithReceiver(Target, Key, Value, Receiver);

  Result := TJSValue.CreateBoolean(IsAssigned);
end;

function TJSReflectBuiltins.SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireTarget(Args, SET_PROTOTYPE_OF_NAME);

  const Prototype = TJSArrayLike.Argument(Args, 1);
  const IsValidPrototype = Prototype.IsObject or Prototype.IsNull;
  if not IsValidPrototype then
    raise TJSErrorFactory.TypeError(PROTOTYPE_NOT_AN_OBJECT);

  const IsChanged = TJSObjectOperations.SetPrototypeOf(Target, Prototype.ToObject);

  Result := TJSValue.CreateBoolean(IsChanged);
end;

procedure TJSReflectBuiltins.DefineFunction(const Reflect: IJSObject; const Name: string;
                                            const ParameterCount: Integer; const Method: TReflectMethod);
begin
  const Native: TNativeFunction =
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Method(Args);
    end;

  const Func = TJSFunction.CreateNative(Name, Native);
  Func.IsConstructor := False;
  Func.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Func, ParameterCount);
  FInterpreter.RegisterFunction(Func);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func));
  Descriptor.Enumerable := False;
  Reflect.DefineProperty(Name, Descriptor);
end;

procedure TJSReflectBuiltins.DefineToStringTag(const Reflect: IJSObject);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateString(REFLECT_TAG));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;

  const TagKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);
  Reflect.DefineProperty(TagKey, Descriptor);
end;

procedure TJSReflectBuiltins.Register;
begin
  const Reflect: IJSObject = TJSObject.Create;
  Reflect.Prototype := FInterpreter.ObjectPrototype;

  DefineFunction(Reflect, APPLY_NAME, 3, Apply);
  DefineFunction(Reflect, CONSTRUCT_NAME, 2, Construct);
  DefineFunction(Reflect, DEFINE_PROPERTY_NAME, 3, DefineProperty);
  DefineFunction(Reflect, DELETE_PROPERTY_NAME, 2, DeleteProperty);
  DefineFunction(Reflect, GET_NAME, 2, Get);
  DefineFunction(Reflect, GET_OWN_PROPERTY_DESCRIPTOR_NAME, 2, GetOwnPropertyDescriptor);
  DefineFunction(Reflect, GET_PROTOTYPE_OF_NAME, 1, GetPrototypeOf);
  DefineFunction(Reflect, HAS_NAME, 2, Has);
  DefineFunction(Reflect, IS_EXTENSIBLE_NAME, 1, IsExtensible);
  DefineFunction(Reflect, OWN_KEYS_NAME, 1, OwnKeys);
  DefineFunction(Reflect, PREVENT_EXTENSIONS_NAME, 1, PreventExtensions);
  DefineFunction(Reflect, SET_NAME, 3, Put);
  DefineFunction(Reflect, SET_PROTOTYPE_OF_NAME, 2, SetPrototypeOf);

  DefineToStringTag(Reflect);

  const ReflectValue = TJSValue.CreateObject(Reflect);
  FInterpreter.SetGlobalVariable(REFLECT_NAME, ReflectValue);
end;

end.
