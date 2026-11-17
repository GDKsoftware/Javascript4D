unit JS4D.CollectionBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter,
  JS4D.ObjectRegistry,
  JS4D.BuiltinSupport,
  JS4D.OrderedStore,
  JS4D.CollectionObjects;

type
  TJSCollectionBuiltins = class(TJSBuiltinSet)
  private
    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FRegistry: TJSObjectRegistry;
      FPrototypes: array[TJSCollectionKind] of IJSObject;
      FMapIteratorPrototype: IJSObject;
      FSetIteratorPrototype: IJSObject;

    class function IsWeak(const Kind: TJSCollectionKind): Boolean; static;
    class function IsMapLike(const Kind: TJSCollectionKind): Boolean; static;
    class function KindName(const Kind: TJSCollectionKind): string; static;
    class function AdderName(const Kind: TJSCollectionKind): string; static;
    function RequireCollection(const This: IJSObject; const Kind: TJSCollectionKind;
                               const MethodName: string): IJSCollection;
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
    procedure CreatePrototype(const Kind: TJSCollectionKind);
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
    procedure DefineClearAndSize(const Kind: TJSCollectionKind; const Prototype: IJSObject);
    function DefineIterationMethod(const Kind: TJSCollectionKind; const Prototype: IJSObject;
                                   const MethodName: string;
                                   const Iteration: TJSCollectionIterationKind): IJSFunction;
    procedure DefineIterationAliases(const Kind: TJSCollectionKind; const Prototype: IJSObject;
                                     const Entries: IJSFunction; const Values: IJSFunction);
    procedure DefineConstructorLinks(const Kind: TJSCollectionKind; const Constructor_: IJSFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
    procedure ReleaseCollections;
  end;

implementation

uses
  System.Math,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.ArrayStatics,
  JS4D.PrototypeMethods,
  JS4D.PropertyNames;

const
  SIZE_PROPERTY = 'size';
  SIZE_GETTER_NAME = 'get size';
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
  FSupport := TJSBuiltinSupport.Create(Interpreter);
  FRegistry := TJSObjectRegistry.Create;
end;

destructor TJSCollectionBuiltins.Destroy;
begin
  ReleaseCollections;
  FRegistry.Free;
  FSupport.Free;
  inherited;
end;

procedure TJSCollectionBuiltins.ReleaseCollections;
begin
  FRegistry.ReleaseAll;
end;

class function TJSCollectionBuiltins.IsWeak(const Kind: TJSCollectionKind): Boolean;
begin
  Result := (Kind in [TJSCollectionKind.WeakMap, TJSCollectionKind.WeakSet]);
end;

class function TJSCollectionBuiltins.IsMapLike(const Kind: TJSCollectionKind): Boolean;
begin
  Result := (Kind in [TJSCollectionKind.Map, TJSCollectionKind.WeakMap]);
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

function TJSCollectionBuiltins.RequireCollection(const This: IJSObject; const Kind: TJSCollectionKind;
                                                 const MethodName: string): IJSCollection;
begin
  const IsMatch = Supports(This, IJSCollection, Result) and (Result.Kind = Kind);
  if not IsMatch then
  begin
    const Message = Format(INCOMPATIBLE_RECEIVER, [KindName(Kind), MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSCollectionBuiltins.RequireStore(const This: IJSObject; const Kind: TJSCollectionKind;
                                            const MethodName: string): TJSOrderedStore;
begin
  const Collection = RequireCollection(This, Kind, MethodName);

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
  Store.TryGet(TJSArrayLike.Argument(Args, 0), Found);

  Result := Found;
end;

function TJSCollectionBuiltins.HasKey(const This: IJSObject; const Kind: TJSCollectionKind;
                                      const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_HAS);

  const Key = TJSArrayLike.Argument(Args, 0);
  const HasEntry = Store.Contains(Key);

  Result := TJSValue.CreateBoolean(HasEntry);
end;

function TJSCollectionBuiltins.DeleteKey(const This: IJSObject; const Kind: TJSCollectionKind;
                                         const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_DELETE);

  const Key = TJSArrayLike.Argument(Args, 0);
  const WasRemoved = Store.Remove(Key);

  Result := TJSValue.CreateBoolean(WasRemoved);
end;

function TJSCollectionBuiltins.PutEntry(const This: IJSObject; const Kind: TJSCollectionKind;
                                        const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, AdderName(Kind));
  const Key = TJSArrayLike.Argument(Args, 0);
  RequireWeakKey(Kind, Key);

  if IsMapLike(Kind) then
    Store.Put(Key, TJSArrayLike.Argument(Args, 1))
  else
    Store.Put(Key, TJSOrderedStore.CanonicalKey(Key));

  Result := TJSValue.CreateObject(This);
end;

function TJSCollectionBuiltins.ForEachEntry(const This: IJSObject; const Kind: TJSCollectionKind;
                                            const Args: TArray<TJSValue>): TJSValue;
begin
  const Store = RequireStore(This, Kind, METHOD_FOR_EACH);
  const Callback = RequireCallback(TJSArrayLike.Argument(Args, 0), KindName(Kind));
  const ThisArg = FInterpreter.ThisObjectFor(Callback, TJSArrayLike.Argument(Args, 1));
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
  const Collection = RequireCollection(This, Kind, MethodName);

  const Iterator = TJSCollectionIterator.Create(Collection, Iteration, FInterpreter.ArrayPrototype,
                                                FInterpreter.ObjectPrototype);
  const IsMap = (Kind = TJSCollectionKind.Map);
  if IsMap then
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
  if not IsMapLike(Kind) then
  begin
    FInterpreter.CallFunction(Adder, [Item], Collection);
    Exit;
  end;

  if not Item.IsObject then
    raise TJSErrorFactory.TypeError(ENTRY_NOT_AN_OBJECT);

  const Entry = Item.ToObject;
  const Key = Entry.GetProperty(TJSArrayLike.IndexName(0));
  const Value = Entry.GetProperty(TJSArrayLike.IndexName(1));

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
    raise TJSErrorFactory.TypeError(Format(CONSTRUCTOR_REQUIRES_NEW, [KindName(Kind)]));

  const Collection: IJSObject = TJSCollectionObject.Create(Kind, FRegistry);
  Collection.Prototype := This.Prototype;

  const Iterable = TJSArrayLike.Argument(Args, 0);
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
  if IsMapLike(Kind) then
  begin
    FSupport.DefineMethod(Prototype, METHOD_GET, 1,
      function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
      begin
        Result := GetValue(This, Kind, Args);
      end);
  end;

  const AdderParameterCount = IfThen(IsMapLike(Kind), 2, 1);
  FSupport.DefineMethod(Prototype, AdderName(Kind), AdderParameterCount,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := PutEntry(This, Kind, Args);
    end);

  FSupport.DefineMethod(Prototype, METHOD_HAS, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := HasKey(This, Kind, Args);
    end);

  FSupport.DefineMethod(Prototype, METHOD_DELETE, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := DeleteKey(This, Kind, Args);
    end);
end;

procedure TJSCollectionBuiltins.DefineIterationMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  DefineClearAndSize(Kind, Prototype);

  const Entries = DefineIterationMethod(Kind, Prototype, METHOD_ENTRIES, TJSCollectionIterationKind.Entries);
  const Values = DefineIterationMethod(Kind, Prototype, METHOD_VALUES, TJSCollectionIterationKind.Values);

  DefineIterationAliases(Kind, Prototype, Entries, Values);
end;

procedure TJSCollectionBuiltins.DefineClearAndSize(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  FSupport.DefineMethod(Prototype, METHOD_CLEAR, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Store = RequireStore(This, Kind, METHOD_CLEAR);
      Store.Clear;

      Result := TJSValue.CreateUndefined;
    end);

  FSupport.DefineMethod(Prototype, METHOD_FOR_EACH, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ForEachEntry(This, Kind, Args);
    end);

  FSupport.DefineGetter(Prototype, SIZE_PROPERTY, SIZE_GETTER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Store = RequireStore(This, Kind, SIZE_PROPERTY);

      Result := TJSValue.CreateNumber(Store.Count);
    end);
end;

function TJSCollectionBuiltins.DefineIterationMethod(const Kind: TJSCollectionKind; const Prototype: IJSObject;
                                                     const MethodName: string;
                                                     const Iteration: TJSCollectionIterationKind): IJSFunction;
begin
  Result := FSupport.DefineMethod(Prototype, MethodName, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := IterateCollection(This, Kind, Iteration, MethodName);
    end);
end;

procedure TJSCollectionBuiltins.DefineIterationAliases(const Kind: TJSCollectionKind; const Prototype: IJSObject;
                                                       const Entries: IJSFunction; const Values: IJSFunction);
begin
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  const IsMap = (Kind = TJSCollectionKind.Map);
  if IsMap then
  begin
    DefineIterationMethod(Kind, Prototype, METHOD_KEYS, TJSCollectionIterationKind.Keys);
    FSupport.DefineMember(Prototype, IteratorKey, TJSValue.CreateObject(Entries), True);
  end
  else
  begin
    FSupport.DefineMember(Prototype, METHOD_KEYS, TJSValue.CreateObject(Values), True);
    FSupport.DefineMember(Prototype, IteratorKey, TJSValue.CreateObject(Values), True);
  end;
end;

procedure TJSCollectionBuiltins.DefineSharedMembers(const Kind: TJSCollectionKind; const Prototype: IJSObject);
begin
  DefineLookupMembers(Kind, Prototype);

  if not IsWeak(Kind) then
    DefineIterationMembers(Kind, Prototype);

  FSupport.DefineToStringTag(Prototype, KindName(Kind));
end;

procedure TJSCollectionBuiltins.CreatePrototype(const Kind: TJSCollectionKind);
begin
  const Prototype: IJSObject = TJSObject.Create;
  Prototype.Prototype := FInterpreter.ObjectPrototype;
  FPrototypes[Kind] := Prototype;

  DefineSharedMembers(Kind, Prototype);
end;

function TJSCollectionBuiltins.CreateIteratorPrototype(const Kind: TJSCollectionKind;
                                                       const IteratorPrototype: IJSObject): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := IteratorPrototype;

  FSupport.DefineMethod(Result, NEXT_PROPERTY, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Iterator: IJSCollectionIterator;
      const IsMatch = Supports(This, IJSCollectionIterator, Iterator) and (Iterator.SourceKind = Kind);
      if not IsMatch then
        raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_ITERATOR, [KindName(Kind)]));

      Result := Iterator.NextResult;
    end);

  const IsMap = (Kind = TJSCollectionKind.Map);
  if IsMap then
    FSupport.DefineToStringTag(Result, MAP_ITERATOR_TAG)
  else
    FSupport.DefineToStringTag(Result, SET_ITERATOR_TAG);
end;

procedure TJSCollectionBuiltins.DefineConstructorLinks(const Kind: TJSCollectionKind;
                                                       const Constructor_: IJSFunction);
begin
  const Prototype = FPrototypes[Kind];

  FSupport.DefineMember(Prototype, CONSTRUCTOR_PROPERTY, TJSValue.CreateObject(Constructor_), True);
  Constructor_.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, TJSValue.CreateObject(Prototype));

  if not IsWeak(Kind) then
    FSupport.DefineSpeciesGetter(Constructor_);
end;

procedure TJSCollectionBuiltins.Register;
begin
  const IteratorPrototype = FInterpreter.Iteration.ArrayIteratorPrototype.Prototype;
  FMapIteratorPrototype := CreateIteratorPrototype(TJSCollectionKind.Map, IteratorPrototype);
  FSetIteratorPrototype := CreateIteratorPrototype(TJSCollectionKind.Set_, IteratorPrototype);

  for var Kind := Low(TJSCollectionKind) to High(TJSCollectionKind) do
  begin
    CreatePrototype(Kind);

    const Constructor_ = CreateConstructor(Kind);
    DefineConstructorLinks(Kind, Constructor_);
    FInterpreter.SetGlobalVariable(KindName(Kind), TJSValue.CreateObject(Constructor_));
  end;
end;

end.
