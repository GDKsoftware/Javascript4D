unit JS4D.CollectionObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.IteratorProtocol,
  JS4D.OrderedStore;

type
  TJSCollectionKind = (Map, Set_, WeakMap, WeakSet);

  TJSCollectionIterationKind = (Keys, Values, Entries);

  IJSCollection = interface(IJSObject)
    ['{8D2F4B61-07A3-4E95-B8C1-5A6E3D9F1C27}']
    function GetKind: TJSCollectionKind;
    function GetStore: TJSOrderedStore;
    property Kind: TJSCollectionKind read GetKind;
    property Store: TJSOrderedStore read GetStore;
  end;

  IJSCollectionIterator = interface(IJSObject)
    ['{3E7A9C15-D4B2-4F68-A01E-9B5C7D2E8F43}']
    function GetSourceKind: TJSCollectionKind;
    function NextResult: TJSValue;
    property SourceKind: TJSCollectionKind read GetSourceKind;
  end;

  TJSCollectionRegistry = class;

  // A Map, Set, WeakMap or WeakSet. Weak collections hold their keys strongly: the registry empties every
  // collection when its engine goes away, so entries cannot keep objects alive past the engine.
  TJSCollectionObject = class(TJSObjectImpl, IJSCollection)
  private
    FKind: TJSCollectionKind;
    FStore: TJSOrderedStore;
    FRegistry: TJSCollectionRegistry;
    FRegistryIndex: Integer;

    function GetKind: TJSCollectionKind;
    function GetStore: TJSOrderedStore;

  public
    constructor Create(const Kind: TJSCollectionKind; const Registry: TJSCollectionRegistry);
    destructor Destroy; override;
  end;

  // Remembers every live collection of one engine, so that cycles through collections (a map that contains
  // itself) can be broken when the engine is freed.
  TJSCollectionRegistry = class
  private
    FCollections: TList<TJSCollectionObject>;

    procedure Add(const Collection: TJSCollectionObject);
    procedure Remove(const Collection: TJSCollectionObject);

  public
    constructor Create;
    destructor Destroy; override;

    procedure ClearAll;
  end;

  TJSCollectionIterator = class(TJSObjectImpl, IJSCollectionIterator)
  private
    FCollection: IJSCollection;
    FCursor: TJSStoreCursor;
    FKind: TJSCollectionIterationKind;
    FSourceKind: TJSCollectionKind;
    FArrayPrototype: IJSObject;
    FObjectPrototype: IJSObject;

    function GetSourceKind: TJSCollectionKind;
    function CreateEntry(const Key: TJSValue; const Value: TJSValue): TJSValue;
    function Pick(const Key: TJSValue; const Value: TJSValue): TJSValue;
    procedure Finish;

  public
    constructor Create(const Collection: IJSCollection; const Kind: TJSCollectionIterationKind;
                       const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);
    destructor Destroy; override;

    function NextResult: TJSValue;
  end;

implementation

{ TJSCollectionObject }

constructor TJSCollectionObject.Create(const Kind: TJSCollectionKind; const Registry: TJSCollectionRegistry);
begin
  inherited Create;

  FKind := Kind;
  FStore := TJSOrderedStore.Create;
  FRegistry := Registry;
  FRegistry.Add(Self);
end;

destructor TJSCollectionObject.Destroy;
begin
  if Assigned(FRegistry) then
    FRegistry.Remove(Self);

  FStore.Free;
  inherited;
end;

function TJSCollectionObject.GetKind: TJSCollectionKind;
begin
  Result := FKind;
end;

function TJSCollectionObject.GetStore: TJSOrderedStore;
begin
  Result := FStore;
end;

{ TJSCollectionRegistry }

constructor TJSCollectionRegistry.Create;
begin
  inherited Create;

  FCollections := TList<TJSCollectionObject>.Create;
end;

destructor TJSCollectionRegistry.Destroy;
begin
  for var Collection in FCollections do
  begin
    Collection.FRegistry := nil;
  end;

  FCollections.Free;
  inherited;
end;

procedure TJSCollectionRegistry.Add(const Collection: TJSCollectionObject);
begin
  Collection.FRegistryIndex := FCollections.Count;
  FCollections.Add(Collection);
end;

procedure TJSCollectionRegistry.Remove(const Collection: TJSCollectionObject);
begin
  const LastIndex = FCollections.Count - 1;
  const Moved = FCollections[LastIndex];
  FCollections[Collection.FRegistryIndex] := Moved;
  Moved.FRegistryIndex := Collection.FRegistryIndex;
  FCollections.Delete(LastIndex);
end;

procedure TJSCollectionRegistry.ClearAll;
begin
  while FCollections.Count > 0 do
  begin
    const Collection = FCollections.Last;
    Collection.FRegistry := nil;
    FCollections.Delete(FCollections.Count - 1);

    const Held: IJSObject = Collection;
    Collection.FStore.Clear;
  end;
end;

{ TJSCollectionIterator }

constructor TJSCollectionIterator.Create(const Collection: IJSCollection; const Kind: TJSCollectionIterationKind;
                                         const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);
begin
  inherited Create;

  FCollection := Collection;
  FCursor := TJSStoreCursor.Create(Collection.Store);
  FKind := Kind;
  FSourceKind := Collection.Kind;
  FArrayPrototype := ArrayPrototype;
  FObjectPrototype := ObjectPrototype;
end;

destructor TJSCollectionIterator.Destroy;
begin
  FCursor.Free;
  inherited;
end;

function TJSCollectionIterator.GetSourceKind: TJSCollectionKind;
begin
  Result := FSourceKind;
end;

function TJSCollectionIterator.CreateEntry(const Key: TJSValue; const Value: TJSValue): TJSValue;
begin
  const Entry = TJSArray.Create;
  Entry.Prototype := FArrayPrototype;
  Entry.Push(Key);
  Entry.Push(Value);

  Result := TJSValue.CreateObject(Entry);
end;

function TJSCollectionIterator.Pick(const Key: TJSValue; const Value: TJSValue): TJSValue;
begin
  case FKind of
    TJSCollectionIterationKind.Keys    : Result := Key;
    TJSCollectionIterationKind.Values  : Result := Value;
    TJSCollectionIterationKind.Entries : Result := CreateEntry(Key, Value);
  else
    raise ENotSupportedException.CreateFmt('Unsupported collection iteration kind: %d', [Ord(FKind)]);
  end;
end;

procedure TJSCollectionIterator.Finish;
begin
  FreeAndNil(FCursor);
  FCollection := nil;
end;

function TJSCollectionIterator.NextResult: TJSValue;
begin
  var Key: TJSValue;
  var Value: TJSValue;
  const HasEntry = Assigned(FCursor) and FCursor.TryNext(Key, Value);
  if HasEntry then
  begin
    const Picked = Pick(Key, Value);
    Exit(TJSIteratorResults.CreateResult(FObjectPrototype, Picked, False));
  end;

  Finish;
  Result := TJSIteratorResults.CreateResult(FObjectPrototype, TJSValue.CreateUndefined, True);
end;

end.
