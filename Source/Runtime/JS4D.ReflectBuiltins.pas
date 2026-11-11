unit JS4D.ReflectBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  // The Reflect object: one function per object internal method.
  TJSReflectBuiltins = class
  private
    const
      REFLECT_NAME = 'Reflect';
      REFLECT_TAG = 'Reflect';
      NOT_AN_OBJECT = 'Reflect.%s called on a non-object';
      NOT_CALLABLE = 'Reflect.%s requires a function as its target';
      NOT_A_CONSTRUCTOR = 'Reflect.construct requires a constructor';
      ARGUMENT_LIST_NOT_AN_OBJECT = 'The argument list must be an object';
      PROTOTYPE_NOT_AN_OBJECT = 'Object prototype may only be an Object or null';

    var
      FInterpreter: TJSInterpreter;

    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    function RequireObject(const Value: TJSValue; const MethodName: string): IJSObject;
    function RequireFunction(const Value: TJSValue; const MethodName: string): IJSFunction;
    function RequireConstructor(const Value: TJSValue): IJSFunction;
    function KeyOf(const Args: TArray<TJSValue>; const Position: Integer): string;
    function ListFromArrayLike(const Value: TJSValue): TArray<TJSValue>;
    function ArrayFromKeys(const Keys: TArray<string>): TJSValue;
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
                             const Method: TNativeFunction);
    procedure DefineToStringTag(const Reflect: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Register;
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

class function TJSReflectBuiltins.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  if Position < Length(Args) then
    Exit(Args[Position]);

  Result := TJSValue.CreateUndefined;
end;

function TJSReflectBuiltins.RequireObject(const Value: TJSValue; const MethodName: string): IJSObject;
begin
  if not Value.IsObject then
    raise TJSErrorFactory.TypeError(Format(NOT_AN_OBJECT, [MethodName]));

  Result := Value.ToObject;
end;

function TJSReflectBuiltins.RequireFunction(const Value: TJSValue; const MethodName: string): IJSFunction;
begin
  const IsCallable = Value.IsFunction and Supports(Value.ToObject, IJSFunction, Result);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(Format(NOT_CALLABLE, [MethodName]));
end;

function TJSReflectBuiltins.RequireConstructor(const Value: TJSValue): IJSFunction;
begin
  const IsConstructor = Value.IsFunction and Supports(Value.ToObject, IJSFunction, Result) and Result.IsConstructor;
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);
end;

function TJSReflectBuiltins.KeyOf(const Args: TArray<TJSValue>; const Position: Integer): string;
begin
  Result := Argument(Args, Position).ToPropertyKey(FInterpreter.Limits);
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
    Result[Index] := Source.GetProperty(TJSArrayLike.IndexName(Index));
  end;
end;

function TJSReflectBuiltins.ArrayFromKeys(const Keys: TArray<string>): TJSValue;
begin
  const List: IJSArray = TJSArray.Create;
  List.Prototype := FInterpreter.ArrayPrototype;

  for var Key in Keys do
  begin
    List.Push(TJSObjectOperations.KeyToValue(Key));
  end;

  Result := TJSValue.CreateObject(List);
end;

function TJSReflectBuiltins.ReceiverOf(const Args: TArray<TJSValue>; const Position: Integer;
                                       const Target: IJSObject): TJSValue;
begin
  if Position < Length(Args) then
    Exit(Args[Position]);

  Result := TJSValue.CreateObject(Target);
end;

function TJSReflectBuiltins.Apply(const Args: TArray<TJSValue>): TJSValue;
begin
  const Func = RequireFunction(Argument(Args, 0), 'apply');
  const CallArguments = ListFromArrayLike(Argument(Args, 2));
  const ThisObj = FInterpreter.ThisObjectFor(Func, Argument(Args, 1));

  Result := FInterpreter.CallFunction(Func, CallArguments, ThisObj);
end;

function TJSReflectBuiltins.Construct(const Args: TArray<TJSValue>): TJSValue;
begin
  const Func = RequireConstructor(Argument(Args, 0));

  var NewTarget := Func;
  if Length(Args) > 2 then
    NewTarget := RequireConstructor(Args[2]);

  const CallArguments = ListFromArrayLike(Argument(Args, 1));
  Result := FInterpreter.Construct(Func, CallArguments, NewTarget);
end;

function TJSReflectBuiltins.DefineProperty(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'defineProperty');
  const Key = KeyOf(Args, 1);
  const Definition = TJSPropertyDescriptors.ToDefinition(Argument(Args, 2));
  const Checked = TJSPropertyDescriptors.WithCheckedLength(Target, Key, Definition, FInterpreter.Limits);

  Result := TJSValue.CreateBoolean(Target.DefineOwnProperty(Key, Checked));
end;

function TJSReflectBuiltins.DeleteProperty(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'deleteProperty');

  const Key = KeyOf(Args, 1);
  const IsDeleted = TJSObjectOperations.DeleteOwnProperty(Target, Key);

  Result := TJSValue.CreateBoolean(IsDeleted);
end;

function TJSReflectBuiltins.Get(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'get');
  const Key = KeyOf(Args, 1);

  const Receiver = ReceiverOf(Args, 2, Target);

  Result := TJSObjectOperations.GetWithReceiver(Target, Key, Receiver);
end;

function TJSReflectBuiltins.GetOwnPropertyDescriptor(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'getOwnPropertyDescriptor');
  const Key = KeyOf(Args, 1);

  var Descriptor: TJSPropertyDescriptor;
  if not TJSObjectOperations.TryGetOwnProperty(Target, Key, Descriptor) then
    Exit(TJSValue.CreateUndefined);

  const Described = TJSPropertyDescriptors.ToDescriptorObject(Descriptor, FInterpreter.ObjectPrototype);
  Result := TJSValue.CreateObject(Described);
end;

function TJSReflectBuiltins.GetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'getPrototypeOf');
  const Prototype = Target.Prototype;

  if Assigned(Prototype) then
    Result := TJSValue.CreateObject(Prototype)
  else
    Result := TJSValue.CreateNull;
end;

function TJSReflectBuiltins.Has(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'has');

  const Key = KeyOf(Args, 1);
  const HasKey = Target.HasProperty(Key);

  Result := TJSValue.CreateBoolean(HasKey);
end;

function TJSReflectBuiltins.IsExtensible(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'isExtensible');

  const IsOpen = Target.IsExtensible;

  Result := TJSValue.CreateBoolean(IsOpen);
end;

function TJSReflectBuiltins.OwnKeys(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'ownKeys');

  const Keys = TJSObjectOperations.OwnKeys(Target);

  Result := ArrayFromKeys(Keys);
end;

function TJSReflectBuiltins.PreventExtensions(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'preventExtensions');

  const IsPrevented = TJSObjectOperations.PreventExtensions(Target);

  Result := TJSValue.CreateBoolean(IsPrevented);
end;

function TJSReflectBuiltins.Put(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'set');
  const Key = KeyOf(Args, 1);

  const Receiver = ReceiverOf(Args, 3, Target);
  const IsAssigned = TJSObjectOperations.SetWithReceiver(Target, Key, Argument(Args, 2), Receiver);
  Result := TJSValue.CreateBoolean(IsAssigned);
end;

function TJSReflectBuiltins.SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObject(Argument(Args, 0), 'setPrototypeOf');

  const Prototype = Argument(Args, 1);
  const IsValidPrototype = Prototype.IsObject or Prototype.IsNull;
  if not IsValidPrototype then
    raise TJSErrorFactory.TypeError(PROTOTYPE_NOT_AN_OBJECT);

  const IsChanged = TJSObjectOperations.SetPrototypeOf(Target, Prototype.ToObject);

  Result := TJSValue.CreateBoolean(IsChanged);
end;

procedure TJSReflectBuiltins.DefineFunction(const Reflect: IJSObject; const Name: string;
                                            const ParameterCount: Integer; const Method: TNativeFunction);
begin
  const Func = TJSFunction.CreateNative(Name, Method);
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
  Reflect.DefineProperty(TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag), Descriptor);
end;

procedure TJSReflectBuiltins.Register;
begin
  const Reflect: IJSObject = TJSObject.Create;
  Reflect.Prototype := FInterpreter.ObjectPrototype;

  DefineFunction(Reflect, 'apply', 3,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Apply(Args);
    end);

  DefineFunction(Reflect, 'construct', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Construct(Args);
    end);

  DefineFunction(Reflect, 'defineProperty', 3,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := DefineProperty(Args);
    end);

  DefineFunction(Reflect, 'deleteProperty', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := DeleteProperty(Args);
    end);

  DefineFunction(Reflect, 'get', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Get(Args);
    end);

  DefineFunction(Reflect, 'getOwnPropertyDescriptor', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := GetOwnPropertyDescriptor(Args);
    end);

  DefineFunction(Reflect, 'getPrototypeOf', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := GetPrototypeOf(Args);
    end);

  DefineFunction(Reflect, 'has', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Has(Args);
    end);

  DefineFunction(Reflect, 'isExtensible', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := IsExtensible(Args);
    end);

  DefineFunction(Reflect, 'ownKeys', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := OwnKeys(Args);
    end);

  DefineFunction(Reflect, 'preventExtensions', 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := PreventExtensions(Args);
    end);

  DefineFunction(Reflect, 'set', 3,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Put(Args);
    end);

  DefineFunction(Reflect, 'setPrototypeOf', 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetPrototypeOf(Args);
    end);

  DefineToStringTag(Reflect);
  FInterpreter.SetGlobalVariable(REFLECT_NAME, TJSValue.CreateObject(Reflect));
end;

end.
