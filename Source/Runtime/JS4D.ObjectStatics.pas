unit JS4D.ObjectStatics;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSObjectStatics = class(TJSBuiltinSet)
  private
    type
      TIntegrityOperation = reference to procedure(const Target: IJSObject);
      TIntegrityTest = reference to function(const Target: IJSObject): Boolean;

    const
      OBJECT_NAME = 'Object';
      ASSIGN_NAME = 'assign';
      CREATE_NAME = 'create';
      FREEZE_NAME = 'freeze';
      IS_FROZEN_NAME = 'isFrozen';
      SEAL_NAME = 'seal';
      IS_SEALED_NAME = 'isSealed';
      PREVENT_EXTENSIONS_NAME = 'preventExtensions';
      IS_EXTENSIBLE_NAME = 'isExtensible';
      GET_PROTOTYPE_OF_NAME = 'getPrototypeOf';
      GET_OWN_PROPERTY_NAMES_NAME = 'getOwnPropertyNames';
      GET_OWN_PROPERTY_SYMBOLS_NAME = 'getOwnPropertySymbols';
      GET_OWN_PROPERTY_DESCRIPTOR_NAME = 'getOwnPropertyDescriptor';
      GET_OWN_PROPERTY_DESCRIPTORS_NAME = 'getOwnPropertyDescriptors';
      IS_NAME = 'is';
      DEFINE_PROPERTY_NAME = 'defineProperty';
      DEFINE_PROPERTIES_NAME = 'defineProperties';
      UNDEFINED_KEY = 'undefined';
      CANNOT_ASSIGN_READ_ONLY = 'Cannot assign to read only property ''%s''';
      METHOD_CALLED_ON_NON_OBJECT = 'Object method called on a value that is not an object';
      PROTOTYPE_MUST_BE_OBJECT_OR_NULL = 'Object prototype may only be an Object or null';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FObjectConstructor: IJSObject;

    class function IsEnumerableOwn(const Source: IJSObject; const Name: TJSPropertyKey): Boolean; static;
    class procedure PutChecked(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue); static;

    procedure DefineStatic(const Name: string; const Method: TNativeFunction);
    procedure DefineIntegrityOperation(const Name: string; const Operation: TIntegrityOperation);
    procedure DefineIntegrityTest(const Name: string; const ResultForPrimitive: Boolean;
                                  const Test: TIntegrityTest);
    function CreateResultArray: IJSArray;
    function KeyArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSPropertyKey;
    function CoerceFirstArgument(const Args: TArray<TJSValue>): IJSObject;
    function RequireObjectArgument(const Args: TArray<TJSValue>): IJSObject;
    function TryGetDescriptorObject(const Source: IJSObject; const Name: TJSPropertyKey;
                                    out DescriptorObject: TJSValue): Boolean;
    procedure CopyEnumerableOwn(const Source: IJSObject; const Target: IJSObject);

    function Keys(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Values(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Entries(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Assign(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateObject(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function DefineProperties(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function DefineProperty(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetOwnPropertyNames(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetOwnPropertySymbols(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetOwnPropertyDescriptor(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function GetOwnPropertyDescriptors(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function SameValue(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;

    procedure RegisterEnumeration;
    procedure RegisterConstruction;
    procedure RegisterIntegrity;
    procedure RegisterDescriptors;

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.Errors,
  JS4D.PropertyNames,
  JS4D.ObjectOperations,
  JS4D.PropertyDescriptors;

constructor TJSObjectStatics.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSObjectStatics.Destroy;
begin
  FObjectConstructor := nil;
  FSupport.Free;

  inherited;
end;

procedure TJSObjectStatics.Register;
begin
  FObjectConstructor := FInterpreter.GetGlobalVariable(OBJECT_NAME).ToObject;

  RegisterEnumeration;
  RegisterConstruction;
  RegisterIntegrity;
  RegisterDescriptors;
end;

class function TJSObjectStatics.IsEnumerableOwn(const Source: IJSObject; const Name: TJSPropertyKey): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := TJSObjectOperations.TryGetOwnProperty(Source, Name, Descriptor) and Descriptor.Enumerable;
end;

class procedure TJSObjectStatics.PutChecked(const Target: IJSObject; const Name: TJSPropertyKey;
                                            const Value: TJSValue);
begin
  const CanPut = TJSPropertyDescriptors.CanPut(Target, Name);
  if not CanPut then
  begin
    const Message = Format(CANNOT_ASSIGN_READ_ONLY, [Name.Text]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  Target.SetProperty(Name, Value);
end;

procedure TJSObjectStatics.DefineStatic(const Name: string; const Method: TNativeFunction);
begin
  const Native = TJSFunction.CreateNative(Name, Method);
  const NativeValue = TJSValue.CreateObject(Native);

  FObjectConstructor.SetProperty(Name, NativeValue);
end;

procedure TJSObjectStatics.DefineIntegrityOperation(const Name: string; const Operation: TIntegrityOperation);
begin
  DefineStatic(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSArrayLike.Argument(Args, 0);

      const IsObjectArgument = Result.IsObject;
      if IsObjectArgument then
        Operation(Result.ToObject);
    end);
end;

procedure TJSObjectStatics.DefineIntegrityTest(const Name: string; const ResultForPrimitive: Boolean;
                                               const Test: TIntegrityTest);
begin
  DefineStatic(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Argument = TJSArrayLike.Argument(Args, 0);

      var Verdict := ResultForPrimitive;
      if Argument.IsObject then
        Verdict := Test(Argument.ToObject);

      Result := TJSValue.CreateBoolean(Verdict);
    end);
end;

function TJSObjectStatics.CreateResultArray: IJSArray;
begin
  Result := TJSArray.Create;
  Result.Prototype := FInterpreter.ArrayPrototype;
end;

function TJSObjectStatics.KeyArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSPropertyKey;
begin
  const HasArgument = (Length(Args) > Index);
  if HasArgument then
  begin
    Result := Args[Index].ToPropertyKey(FInterpreter.Limits);
  end
  else
  begin
    Result := UNDEFINED_KEY;
  end;
end;

function TJSObjectStatics.CoerceFirstArgument(const Args: TArray<TJSValue>): IJSObject;
begin
  const Argument = TJSArrayLike.Argument(Args, 0);

  Result := FSupport.ToObject(Argument);
end;

function TJSObjectStatics.RequireObjectArgument(const Args: TArray<TJSValue>): IJSObject;
begin
  const Target = TJSArrayLike.Argument(Args, 0);
  if not Target.IsObject then
    raise TJSErrorFactory.TypeError(METHOD_CALLED_ON_NON_OBJECT);

  Result := Target.ToObject;
end;

function TJSObjectStatics.TryGetDescriptorObject(const Source: IJSObject; const Name: TJSPropertyKey;
                                                 out DescriptorObject: TJSValue): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := TJSObjectOperations.TryGetOwnProperty(Source, Name, Descriptor);
  if not Result then
    Exit;

  const Created = TJSPropertyDescriptors.ToDescriptorObject(Descriptor, FInterpreter.ObjectPrototype);
  DescriptorObject := TJSValue.CreateObject(Created);
end;

procedure TJSObjectStatics.CopyEnumerableOwn(const Source: IJSObject; const Target: IJSObject);
begin
  for var Name in TJSObjectOperations.OwnKeys(Source) do
  begin
    if IsEnumerableOwn(Source, Name) then
    begin
      const Value = Source.GetProperty(Name);
      PutChecked(Target, Name, Value);
    end;
  end;
end;

function TJSObjectStatics.Keys(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Names = CreateResultArray;

  for var Name in Source.GetOwnPropertyNames do
  begin
    if IsEnumerableOwn(Source, Name) then
    begin
      const NameValue = TJSValue.CreateString(Name);
      Names.Push(NameValue);
    end;
  end;

  Result := TJSValue.CreateObject(Names);
end;

function TJSObjectStatics.Values(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Collected = CreateResultArray;

  for var Name in Source.GetOwnPropertyNames do
  begin
    if IsEnumerableOwn(Source, Name) then
    begin
      const Value = Source.GetProperty(Name);
      Collected.Push(Value);
    end;
  end;

  Result := TJSValue.CreateObject(Collected);
end;

function TJSObjectStatics.Entries(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Collected = CreateResultArray;

  for var Name in Source.GetOwnPropertyNames do
  begin
    if IsEnumerableOwn(Source, Name) then
    begin
      const Entry = CreateResultArray;
      const NameValue = TJSValue.CreateString(Name);
      const Value = Source.GetProperty(Name);
      Entry.Push(NameValue);
      Entry.Push(Value);

      const EntryValue = TJSValue.CreateObject(Entry);
      Collected.Push(EntryValue);
    end;
  end;

  Result := TJSValue.CreateObject(Collected);
end;

function TJSObjectStatics.Assign(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = CoerceFirstArgument(Args);

  for var Index := 1 to Length(Args) - 1 do
  begin
    if not Args[Index].IsNullOrUndefined then
    begin
      const Source = FSupport.ToObject(Args[Index]);
      CopyEnumerableOwn(Source, Target);
    end;
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSObjectStatics.CreateObject(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const PrototypeArgument = TJSArrayLike.Argument(Args, 0);
  const IsValidPrototype = (PrototypeArgument.IsObject or PrototypeArgument.IsNull);
  if not IsValidPrototype then
    raise TJSErrorFactory.TypeError(PROTOTYPE_MUST_BE_OBJECT_OR_NULL);

  const Created = TJSObject.Create;
  if PrototypeArgument.IsObject then
    Created.Prototype := PrototypeArgument.ToObject;

  const Properties = TJSArrayLike.Argument(Args, 1);
  if not Properties.IsUndefined then
    TJSPropertyDescriptors.DefineAll(Created, Properties, FInterpreter.Limits);

  Result := TJSValue.CreateObject(Created);
end;

function TJSObjectStatics.DefineProperties(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObjectArgument(Args);
  const Properties = TJSArrayLike.Argument(Args, 1);

  TJSPropertyDescriptors.DefineAll(Target, Properties, FInterpreter.Limits);

  Result := Args[0];
end;

function TJSObjectStatics.DefineProperty(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = RequireObjectArgument(Args);
  const Name = KeyArgumentAt(Args, 1);
  const Description = TJSArrayLike.Argument(Args, 2);

  const Definition = TJSPropertyDescriptors.ToDefinition(Description);
  TJSPropertyDescriptors.Define(Target, Name, Definition, FInterpreter.Limits);

  Result := Args[0];
end;

function TJSObjectStatics.GetPrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Prototype = Source.Prototype;

  if Assigned(Prototype) then
    Result := TJSValue.CreateObject(Prototype)
  else
    Result := TJSValue.CreateNull;
end;

function TJSObjectStatics.GetOwnPropertyNames(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Names = CreateResultArray;

  for var Name in Source.GetOwnPropertyNames do
  begin
    const NameValue = TJSValue.CreateString(Name);
    Names.Push(NameValue);
  end;

  Result := TJSValue.CreateObject(Names);
end;

function TJSObjectStatics.GetOwnPropertySymbols(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Symbols = CreateResultArray;

  for var SymbolKey in Source.GetOwnSymbolKeysInCreationOrder do
  begin
    const SymbolValue = TJSObjectOperations.KeyToValue(SymbolKey);
    Symbols.Push(SymbolValue);
  end;

  Result := TJSValue.CreateObject(Symbols);
end;

function TJSObjectStatics.GetOwnPropertyDescriptor(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);
  const Name = KeyArgumentAt(Args, 1);

  var DescriptorObject: TJSValue;
  const HasProperty = TryGetDescriptorObject(Source, Name, DescriptorObject);
  if HasProperty then
    Result := DescriptorObject
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSObjectStatics.GetOwnPropertyDescriptors(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = CoerceFirstArgument(Args);

  const Descriptors: IJSObject = TJSObject.Create;
  Descriptors.Prototype := FInterpreter.ObjectPrototype;

  for var Name in TJSObjectOperations.OwnKeys(Source) do
  begin
    var DescriptorObject: TJSValue;
    if TryGetDescriptorObject(Source, Name, DescriptorObject) then
    begin
      const Definition = TJSPropertyDescriptor.Create(DescriptorObject);
      Descriptors.DefineProperty(Name, Definition);
    end;
  end;

  Result := TJSValue.CreateObject(Descriptors);
end;

function TJSObjectStatics.SameValue(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Left = TJSArrayLike.Argument(Args, 0);
  const Right = TJSArrayLike.Argument(Args, 1);

  const AreSame = Left.SameValue(Right);

  Result := TJSValue.CreateBoolean(AreSame);
end;

procedure TJSObjectStatics.RegisterEnumeration;
begin
  DefineStatic(KEYS_PROPERTY, Keys);
  DefineStatic(VALUES_PROPERTY, Values);
  DefineStatic(ENTRIES_PROPERTY, Entries);
  DefineStatic(GET_OWN_PROPERTY_NAMES_NAME, GetOwnPropertyNames);
  DefineStatic(GET_OWN_PROPERTY_SYMBOLS_NAME, GetOwnPropertySymbols);
end;

procedure TJSObjectStatics.RegisterConstruction;
begin
  DefineStatic(ASSIGN_NAME, Assign);
  DefineStatic(CREATE_NAME, CreateObject);
  DefineStatic(DEFINE_PROPERTIES_NAME, DefineProperties);
  DefineStatic(DEFINE_PROPERTY_NAME, DefineProperty);
  DefineStatic(GET_PROTOTYPE_OF_NAME, GetPrototypeOf);
  DefineStatic(IS_NAME, SameValue);
end;

procedure TJSObjectStatics.RegisterIntegrity;
begin
  DefineIntegrityOperation(FREEZE_NAME,
    procedure(const Target: IJSObject)
    begin
      Target.Freeze;
    end);
  DefineIntegrityTest(IS_FROZEN_NAME, True,
    function(const Target: IJSObject): Boolean
    begin
      Result := Target.IsFrozen;
    end);

  DefineIntegrityOperation(SEAL_NAME,
    procedure(const Target: IJSObject)
    begin
      Target.Seal;
    end);
  DefineIntegrityTest(IS_SEALED_NAME, True,
    function(const Target: IJSObject): Boolean
    begin
      Result := Target.IsSealed;
    end);

  DefineIntegrityOperation(PREVENT_EXTENSIONS_NAME,
    procedure(const Target: IJSObject)
    begin
      Target.PreventExtensions;
    end);
  DefineIntegrityTest(IS_EXTENSIBLE_NAME, False,
    function(const Target: IJSObject): Boolean
    begin
      Result := Target.IsExtensible;
    end);
end;

procedure TJSObjectStatics.RegisterDescriptors;
begin
  DefineStatic(GET_OWN_PROPERTY_DESCRIPTOR_NAME, GetOwnPropertyDescriptor);
  DefineStatic(GET_OWN_PROPERTY_DESCRIPTORS_NAME, GetOwnPropertyDescriptors);
end;

end.
