unit JS4D.CollectionBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter,
  JS4D.OrderedStore,
  JS4D.CollectionObjects;

type
  // Map, Set, WeakMap and WeakSet with the iterators of Map and Set.
  TJSCollectionBuiltins = class
  private
    const
      ALL_KINDS: array[0..3] of TJSCollectionKind = (TJSCollectionKind.Map, TJSCollectionKind.Set_,
                                                     TJSCollectionKind.WeakMap, TJSCollectionKind.WeakSet);

    var
      FInterpreter: TJSInterpreter;
      FRegistry: TJSCollectionRegistry;
      FPrototypes: array[TJSCollectionKind] of IJSObject;
      FMapIteratorPrototype: IJSObject;
      FSetIteratorPrototype: IJSObject;

    class function IsWeak(const Kind: TJSCollectionKind): Boolean; static;
    class function KindName(const Kind: TJSCollectionKind): string; static;
    class function AdderName(const Kind: TJSCollectionKind): string; static;
    class procedure DefineMember(const Target: IJSObject; const Key: string; const Value: TJSValue;
                                 const IsWritable: Boolean); static;
    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    function DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineGetter(const Target: IJSObject; const Key: string; const Name: string;
                           const Method: TNativeFunction);
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    procedure DefineSpeciesGetter(const Constructor_: IJSObject);
    function RequireStore(const This: IJSObject; const Kind: TJSCollectionKind;
                          const MethodName: string): TJSOrderedStore;
    function RequireCallback(const Value: TJSValue; const MethodName: string): IJSFunction;
    function RequireAdder(const Collection: IJSObject; const Kind: TJSCollectionKind): IJSFunction;
    procedure AddFromIterable(const Collection: IJSObject; const Kind: TJSCollectionKind;
                              const Iterable: TJSValue);
    procedure AddItem(const Collection: IJSObject; const Adder: IJSFunction; const Kind: TJSCollectionKind;
                      const Item: TJSValue);
    function Construct(const Kind: TJSCollectionKind; const This: IJSObject;
                       const Args: TArray<TJSValue>): TJSValue;
    function CreateConstructor(const Kind: TJSCollectionKind): IJSFunction;
    function CreatePrototype(const Kind: TJSCollectionKind): IJSObject;
    function CreateIteratorPrototype(const Kind: TJSCollectionKind; const IteratorPrototype: IJSObject): IJSObject;
    function IterateCollection(const This: IJSObject; const Kind: TJSCollectionKind;
                               const Iteration: TJSCollectionIterationKind; const MethodName: string): TJSValue;
    function ForEachEntry(const This: IJSObject; const Kind: TJSCollectionKind;
                          const Args: TArray<TJSValue>): TJSValue;
    function GetValue(const This: IJSObject; const Kind: TJSCollectionKind; const Args: TArray<TJSValue>): TJSValue;
    function HasKey(const This: IJSObject; const Kind: TJSCollectionKind; const Args: TArray<TJSValue>): TJSValue;
    function DeleteKey(const This: IJSObject; const Kind: TJSCollectionKind; const Args: TArray<TJSValue>): TJSValue;
    function PutEntry(const This: IJSObject; const Kind: TJSCollectionKind; const Args: TArray<TJSValue>): TJSValue;
    procedure RequireWeakKey(const Kind: TJSCollectionKind; const Key: TJSValue);
    procedure DefineSharedMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
    procedure DefineLookupMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
    procedure DefineIterationMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
    procedure DefineConstructorLinks(const Kind: TJSCollectionKind; const Constructor_: IJSFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
    procedure ReleaseCollections;
  end;

implementation

uses
  System.Math,
  JS4D.Errors,
  JS4D.ArrayStatics,
  JS4D.PrototypeMethods;

const
  NEXT_PROPERTY = 'next';
  PROTOTYPE_PROPERTY = 'prototype';
  CONSTRUCTOR_PROPERTY = 'constructor';
  SIZE_PROPERTY = 'size';
  SIZE_GETTER_NAME = 'get size';
  SPECIES_GETTER_NAME = 'get [Symbol.species]';
  METHOD_GET = 'get';
  METHOD_SET = 'set';
  METHOD_ADD = 'add';
  METHOD_HAS = 'has';
  METHOD_DELETE = 'delete';
  METHOD_CLEAR = 'clear';
  METHOD_FOR_EACH = 'forEach';
  METHOD_KEYS = 'keys';
  METHOD_VALUES = 'values';
  METHOD_ENTRIES = 'entries';
  MAP_NAME = 'Map';
  SET_NAME = 'Set';
  WEAK_MAP_NAME = 'WeakMap';
  WEAK_SET_NAME = 'WeakSet';
  MAP_ITERATOR_TAG = 'Map Iterator';
  SET_ITERATOR_TAG = 'Set Iterator';
  UNSUPPORTED_KIND = 'Unsupported collection kind: %d';
  REQUIRES_NEW ='Constructor %s requires ''new''';
  INCOMPATIBLE_RECEIVER = 'Method %s.prototype.%s called on an incompatible receiver';
  INCOMPATIBLE_ITERATOR = 'Method %s Iterator.prototype.next called on an incompatible receiver';
  ADDER_NOT_CALLABLE = '''%s'' returned for property ''%s'' of object is not a function';
  CALLBACK_NOT_CALLABLE = '%s.prototype.forEach requires a callback function';
  NOT_ITERABLE = 'The value is not iterable';
  ENTRY_NOT_AN_OBJECT = 'Iterator value is not an entry object';
  INVALID_WEAK_KEY = 'Invalid value used as a weak collection key';

constructor TJSCollectionBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FRegistry := TJSCollectionRegistry.Create;
end;

destructor TJSCollectionBuiltins.Destroy;
begin
  ReleaseCollections;
  FRegistry.Free;
  inherited;
end;

procedure TJSCollectionBuiltins.ReleaseCollections;
begin
  FRegistry.ClearAll;
end;

class function TJSCollectionBuiltins.IsWeak(const Kind: TJSCollectionKind): Boolean;
begin
  Result := Kind in [TJSCollectionKind.WeakMap, TJSCollectionKind.WeakSet];
end;

class function TJSCollectionBuiltins.KindName(const Kind: TJSCollectionKind): string;
begin
  case Kind of
    TJSCollectionKind.Map     : Result := MAP_NAME;
    TJSCollectionKind.Set_    : Result := SET_NAME;
    TJSCollectionKind.WeakMap : Result := WEAK_MAP_NAME;
    TJSCollectionKind.WeakSet : Result := WEAK_SET_NAME;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_KIND, [Ord(Kind)]);
  end;
end;

class function TJSCollectionBuiltins.AdderName(const Kind: TJSCollectionKind): string;
begin
  case Kind of
    TJSCollectionKind.Map,
    TJSCollectionKind.WeakMap : Result := METHOD_SET;
    TJSCollectionKind.Set_,
    TJSCollectionKind.WeakSet : Result := METHOD_ADD;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_KIND, [Ord(Kind)]);
  end;
end;

class procedure TJSCollectionBuiltins.DefineMember(const Target: IJSObject; const Key: string;
                                                   const Value: TJSValue; const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

class function TJSCollectionBuiltins.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  if Position < Length(Args) then
    Exit(Args[Position]);

  Result := TJSValue.CreateUndefined;
end;

function TJSCollectionBuiltins.CreateMethod(const Name: string; const ParameterCount: Integer;
                                            const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

function TJSCollectionBuiltins.DefineMethod(const Target: IJSObject; const Name: string;
                                            const ParameterCount: Integer;
                                            const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(Name, ParameterCount, Method);

  DefineMember(Target, Name, TJSValue.CreateObject(Result), True);
end;

procedure TJSCollectionBuiltins.DefineGetter(const Target: IJSObject; const Key: string; const Name: string;
                                             const Method: TNativeFunction);
begin
  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.IsAccessor := True;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Descriptor.Getter := TJSValue.CreateObject(CreateMethod(Name, 0, Method));
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSCollectionBuiltins.DefineToStringTag(const Target: IJSObject; const Tag: string);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);

  DefineMember(Target, Key, TJSValue.CreateString(Tag), False);
end;

procedure TJSCollectionBuiltins.DefineSpeciesGetter(const Constructor_: IJSObject);
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

function TJSCollectionBuiltins.RequireStore(const This: IJSObject; const Kind: TJSCollectionKind;
                                            const MethodName: string): TJSOrderedStore;
begin
  var Collection: IJSCollection;
  const IsMatch = Supports(This, IJSCollection, Collection) and (Collection.Kind = Kind);
  if not IsMatch then
    raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_RECEIVER, [KindName(Kind), MethodName]));

  Result := Collection.Store;
end;

function TJSCollectionBuiltins.RequireCallback(const Value: TJSValue; const MethodName: string): IJSFunction;
begin
  const IsCallable = Value.IsFunction and Supports(Value.ToObject, IJSFunction, Result);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(Format(CALLBACK_NOT_CALLABLE, [MethodName]));
end;

procedure TJSCollectionBuiltins.RequireWeakKey(const Kind: TJSCollectionKind; const Key: TJSValue);
begin
  const IsInvalid = IsWeak(Kind) and (not Key.IsObject);
  if IsInvalid then
    raise TJSErrorFactory.TypeError(INVALID_WEAK_KEY);
end;

function TJSCollectionBuiltins.GetValue(const This: IJSObject; const Kind: TJSCollectionKind;
                                        const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_GET);

  var Found: TJSValue;
  Store.TryGet(Argument(Args, 0), Found);

  Result := Found;
end;

function TJSCollectionBuiltins.HasKey(const This: IJSObject; const Kind: TJSCollectionKind;
                                      const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_HAS);

  const Key = Argument(Args, 0);
  const HasEntry = Store.Contains(Key);

  Result := TJSValue.CreateBoolean(HasEntry);
end;

function TJSCollectionBuiltins.DeleteKey(const This: IJSObject; const Kind: TJSCollectionKind;
                                         const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_DELETE);

  const Key = Argument(Args, 0);
  const WasRemoved = Store.Remove(Key);

  Result := TJSValue.CreateBoolean(WasRemoved);
end;

function TJSCollectionBuiltins.PutEntry(const This: IJSObject; const Kind: TJSCollectionKind;
                                        const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, AdderName(Kind));
  const Key = Argument(Args, 0);
  RequireWeakKey(Kind, Key);

  const IsMapLike = Kind in [TJSCollectionKind.Map, TJSCollectionKind.WeakMap];
  if IsMapLike then
    Store.Put(Key, Argument(Args, 1))
  else
    Store.Put(Key, TJSOrderedStore.CanonicalKey(Key));

  Result := TJSValue.CreateObject(This);
end;

function TJSCollectionBuiltins.ForEachEntry(const This: IJSObject; const Kind: TJSCollectionKind;
                                            const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_FOR_EACH);
  const Callback = RequireCallback(Argument(Args, 0), KindName(Kind));
  const ThisArg = FInterpreter.ThisObjectFor(Callback, Argument(Args, 1));
  const Collection = TJSValue.CreateObject(This);

  const Cursor = TJSStoreCursor.Create(Store);
  try
    var Key: TJSValue;
    var Value: TJSValue;
    while Cursor.TryNext(Key, Value) do
    begin
      const CallbackArgs: TArray<TJSValue> = [Value, Key, Collection];
      FInterpreter.CallFunction(Callback, CallbackArgs, ThisArg);
    end;
  finally
    Cursor.Free;
  end;

  Result := TJSValue.CreateUndefined;
end;

function TJSCollectionBuiltins.IterateCollection(const This: IJSObject; const Kind: TJSCollectionKind;
                                                 const Iteration: TJSCollectionIterationKind;
                                                 const MethodName: string): TJSValue;
begin
  RequireStore(This, Kind, MethodName);

  var Collection: IJSCollection;
  Supports(This, IJSCollection, Collection);

  const Iterator = TJSCollectionIterator.Create(Collection, Iteration, FInterpreter.ArrayPrototype,
                                                FInterpreter.ObjectPrototype);
  if Kind = TJSCollectionKind.Map then
    Iterator.Prototype := FMapIteratorPrototype
  else
    Iterator.Prototype := FSetIteratorPrototype;

  Result := TJSValue.CreateObject(Iterator);
end;

function TJSCollectionBuiltins.RequireAdder(const Collection: IJSObject; const Kind: TJSCollectionKind): IJSFunction;
begin
  const Name = AdderName(Kind);
  const Candidate = Collection.GetProperty(Name);

  const IsCallable = Candidate.IsFunction and Supports(Candidate.ToObject, IJSFunction, Result);
  if not IsCallable then
    raise TJSErrorFactory.TypeError(Format(ADDER_NOT_CALLABLE, [Candidate.ToString, Name]));
end;

procedure TJSCollectionBuiltins.AddItem(const Collection: IJSObject; const Adder: IJSFunction;
                                        const Kind: TJSCollectionKind; const Item: TJSValue);
begin
  const IsMapLike = Kind in [TJSCollectionKind.Map, TJSCollectionKind.WeakMap];
  if not IsMapLike then
  begin
    FInterpreter.CallFunction(Adder, [Item], Collection);
    Exit;
  end;

  if not Item.IsObject then
    raise TJSErrorFactory.TypeError(ENTRY_NOT_AN_OBJECT);

  const Entry = Item.ToObject;
  const Key = Entry.GetProperty('0');
  const Value = Entry.GetProperty('1');

  FInterpreter.CallFunction(Adder, [Key, Value], Collection);
end;

procedure TJSCollectionBuiltins.AddFromIterable(const Collection: IJSObject; const Kind: TJSCollectionKind;
                                                const Iterable: TJSValue);
begin
  const Adder = RequireAdder(Collection, Kind);

  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if not FInterpreter.OpenSequenceReader(Iterable, Reader, Closer) then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  var Item: TJSValue;
  while Reader(Item) do
  begin
    try
      AddItem(Collection, Adder, Kind, Item);
    except
      on EJSExecutionInterrupted do
        raise;
      on Exception do
      begin
        Closer(True);
        raise;
      end;
    end;
  end;
end;

function TJSCollectionBuiltins.Construct(const Kind: TJSCollectionKind; const This: IJSObject;
                                         const Args: TArray<TJSValue>): TJSValue;
begin
  const IsConstructCall = TJSPrototypeMethods.IsConstructCall(This, FPrototypes[Kind]);
  if not IsConstructCall then
    raise TJSErrorFactory.TypeError(Format(REQUIRES_NEW, [KindName(Kind)]));

  const Collection: IJSObject = TJSCollectionObject.Create(Kind, FRegistry);
  Collection.Prototype := This.Prototype;

  const Iterable = Argument(Args, 0);
  if not Iterable.IsNullOrUndefined then
    AddFromIterable(Collection, Kind, Iterable);

  Result := TJSValue.CreateObject(Collection);
end;

function TJSCollectionBuiltins.CreateConstructor(const Kind: TJSCollectionKind): IJSFunction;
begin
  Result := TJSFunction.CreateNative(KindName(Kind),
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Construct(Kind, This, Args);
    end);
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, 0);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSCollectionBuiltins.DefineLookupMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  const IsMapLike = Kind in [TJSCollectionKind.Map, TJSCollectionKind.WeakMap];
  if IsMapLike then
  begin
    DefineMethod(Prototype, METHOD_GET, 1,
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        Result := GetValue(This, Kind, Args);
      end);
  end;

  const AdderParameterCount = IfThen(IsMapLike, 2, 1);
  DefineMethod(Prototype, AdderName(Kind), AdderParameterCount,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := PutEntry(This, Kind, Args);
    end);

  DefineMethod(Prototype, METHOD_HAS, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := HasKey(This, Kind, Args);
    end);

  DefineMethod(Prototype, METHOD_DELETE, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := DeleteKey(This, Kind, Args);
    end);
end;

procedure TJSCollectionBuiltins.DefineIterationMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  DefineMethod(Prototype, METHOD_CLEAR, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Store = RequireStore(This, Kind, METHOD_CLEAR);
      Store.Clear;

      Result := TJSValue.CreateUndefined;
    end);

  DefineMethod(Prototype, METHOD_FOR_EACH, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ForEachEntry(This, Kind, Args);
    end);

  DefineGetter(Prototype, SIZE_PROPERTY, SIZE_GETTER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Store = RequireStore(This, Kind, SIZE_PROPERTY);

      Result := TJSValue.CreateNumber(Store.Count);
    end);

  const Entries = DefineMethod(Prototype, METHOD_ENTRIES, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := IterateCollection(This, Kind, TJSCollectionIterationKind.Entries, METHOD_ENTRIES);
    end);

  const Values = DefineMethod(Prototype, METHOD_VALUES, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := IterateCollection(This, Kind, TJSCollectionIterationKind.Values, METHOD_VALUES);
    end);

  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);
  if Kind = TJSCollectionKind.Map then
  begin
    DefineMethod(Prototype, METHOD_KEYS, 0,
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        Result := IterateCollection(This, Kind, TJSCollectionIterationKind.Keys, METHOD_KEYS);
      end);
    DefineMember(Prototype, IteratorKey, TJSValue.CreateObject(Entries), True);
  end
  else
  begin
    DefineMember(Prototype, METHOD_KEYS, TJSValue.CreateObject(Values), True);
    DefineMember(Prototype, IteratorKey, TJSValue.CreateObject(Values), True);
  end;
end;

procedure TJSCollectionBuiltins.DefineSharedMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  DefineLookupMembers(Kind, Prototype);

  if not IsWeak(Kind) then
    DefineIterationMembers(Kind, Prototype);

  DefineToStringTag(Prototype, KindName(Kind));
end;

function TJSCollectionBuiltins.CreatePrototype(const Kind: TJSCollectionKind): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := FInterpreter.ObjectPrototype;
  FPrototypes[Kind] := Result;

  DefineSharedMembers(Kind, Result);
end;

function TJSCollectionBuiltins.CreateIteratorPrototype(const Kind: TJSCollectionKind;
                                                       const IteratorPrototype: IJSObject): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := IteratorPrototype;

  DefineMethod(Result, NEXT_PROPERTY, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Iterator: IJSCollectionIterator;
      const IsMatch = Supports(This, IJSCollectionIterator, Iterator) and (Iterator.SourceKind = Kind);
      if not IsMatch then
        raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_ITERATOR, [KindName(Kind)]));

      Result := Iterator.NextResult;
    end);

  if Kind = TJSCollectionKind.Map then
    DefineToStringTag(Result, MAP_ITERATOR_TAG)
  else
    DefineToStringTag(Result, SET_ITERATOR_TAG);
end;

procedure TJSCollectionBuiltins.DefineConstructorLinks(const Kind: TJSCollectionKind;
                                                       const Constructor_: IJSFunction);
begin
  const Prototype = FPrototypes[Kind];

  DefineMember(Prototype, CONSTRUCTOR_PROPERTY, TJSValue.CreateObject(Constructor_), True);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, TJSValue.CreateObject(Prototype));

  if not IsWeak(Kind) then
    DefineSpeciesGetter(Constructor_);
end;

procedure TJSCollectionBuiltins.Register;
begin
  const IteratorPrototype = FInterpreter.Iteration.ArrayIteratorPrototype.Prototype;
  FMapIteratorPrototype := CreateIteratorPrototype(TJSCollectionKind.Map, IteratorPrototype);
  FSetIteratorPrototype := CreateIteratorPrototype(TJSCollectionKind.Set_, IteratorPrototype);

  for var Kind in ALL_KINDS do
  begin
    CreatePrototype(Kind);

    const Constructor_ = CreateConstructor(Kind);
    DefineConstructorLinks(Kind, Constructor_);
    FInterpreter.SetGlobalVariable(KindName(Kind), TJSValue.CreateObject(Constructor_));
  end;
end;

end.
