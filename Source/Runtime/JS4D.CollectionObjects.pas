unit JS4D.CollectionObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.ObjectHeap,
  JS4D.Types,
  JS4D.ObjectRegistry,
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

  // A Map, Set, WeakMap or WeakSet. Weak collections hold their keys strongly: the registry empties every
  // collection when its engine goes away, so entries cannot keep objects alive past the engine.
  TJSCollectionObject = class(TJSRegisteredObject, IJSCollection)
  private
    FKind: TJSCollectionKind;
    FStore: TJSOrderedStore;

    function GetKind: TJSCollectionKind;
    function GetStore: TJSOrderedStore;

  protected
    procedure ReleaseReferences; override;
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;

  public
    constructor Create(const Kind: TJSCollectionKind; const Registry: TJSObjectRegistry);
    destructor Destroy; override;

    procedure ReleaseHeldValues; override;
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

  protected
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;
    procedure ReleaseReferences; override;
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;

  public
    constructor Create(const Collection: IJSCollection; const Kind: TJSCollectionIterationKind;
                       const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);
    destructor Destroy; override;

    function NextResult: TJSValue;
  end;

implementation

{ TJSCollectionObject }

constructor TJSCollectionObject.Create(const Kind: TJSCollectionKind; const Registry: TJSObjectRegistry);
begin
  inherited Create(Registry);

  FKind := Kind;
  FStore := TJSOrderedStore.Create;
end;

destructor TJSCollectionObject.Destroy;
begin
  ReleaseNested;
  FreeAndNil(FStore);
  inherited;
end;

procedure TJSCollectionObject.ReleaseHeldValues;
begin
  FStore.Clear;
end;

procedure TJSCollectionObject.ReleaseReferences;
begin
  ReleaseNested;
  FStore.Clear;
  inherited;
end;

function TJSCollectionObject.HoldsNested: Boolean;
begin
  Result := (Assigned(FStore) and FStore.HoldsNestedObjects) or inherited HoldsNested;
end;

procedure TJSCollectionObject.DetachNested(const Pending: TList<IJSObject>);
begin
  if Assigned(FStore) then
    FStore.DetachNestedObjects(Pending);

  inherited DetachNested(Pending);
end;

function TJSCollectionObject.GetKind: TJSCollectionKind;
begin
  Result := FKind;
end;

function TJSCollectionObject.GetStore: TJSOrderedStore;
begin
  Result := FStore;
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
  ReleaseNested;
  FCursor.Free;
  inherited;
end;

procedure TJSCollectionIterator.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
  inherited;
  ReportReference(Visit, FCollection);
  ReportReference(Visit, FArrayPrototype);
  ReportReference(Visit, FObjectPrototype);
end;

procedure TJSCollectionIterator.ReleaseReferences;
begin
  Finish;
  FArrayPrototype := nil;
  FObjectPrototype := nil;
  inherited;
end;

function TJSCollectionIterator.HoldsNested: Boolean;
begin
  Result := Assigned(FCollection) or inherited HoldsNested;
end;

procedure TJSCollectionIterator.DetachNested(const Pending: TList<IJSObject>);
begin
  if Assigned(FCollection) then
    Pending.Add(FCollection);

  Finish;
  inherited DetachNested(Pending);
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
