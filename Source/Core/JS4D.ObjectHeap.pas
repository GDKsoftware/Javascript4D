unit JS4D.ObjectHeap;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections;

type
  TJSHeap = class;
  TJSHeapObject = class;

  TJSHeapVisitor = reference to procedure(const Item: TJSHeapObject);

  TJSHeapObject = class abstract(TInterfacedObject)
  private
    FHeap: TJSHeap;
    FHeapSlot: Integer;

  protected
    procedure ReleaseReferences; virtual; abstract;
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); virtual; abstract;
    function IsReleasedWithEngine: Boolean; virtual;

    class procedure ReportReference(const Visit: TJSHeapVisitor; const Reference: IInterface); static;

  public
    constructor Create;
    destructor Destroy; override;
  end;

  TJSHeap = class
  private
    FObjects: TArray<TJSHeapObject>;
    FCount: Integer;

    procedure Add(const Item: TJSHeapObject);
    procedure Remove(const Item: TJSHeapObject);
    procedure ListObjects(const Objects: TList<TJSHeapObject>; const KeepAlive: TList<IInterface>);
    procedure ReleaseFunctions(const Objects: TList<TJSHeapObject>);
    procedure CountReferences(const Objects: TList<TJSHeapObject>;
                              const Counts: TDictionary<TJSHeapObject, Integer>);
    class function CountedReferences(const Counts: TDictionary<TJSHeapObject, Integer>;
                                     const Item: TJSHeapObject): Integer; static;
    function IsHeldFromOutside(const Item: TJSHeapObject;
                               const Counts: TDictionary<TJSHeapObject, Integer>): Boolean;
    procedure RetainHeldFromOutside(const Objects: TList<TJSHeapObject>;
                                    const Counts: TDictionary<TJSHeapObject, Integer>;
                                    const Retain: TJSHeapVisitor);
    procedure RetainReachable(const Pending: TStack<TJSHeapObject>; const Retain: TJSHeapVisitor);
    procedure FindRetained(const Objects: TList<TJSHeapObject>;
                           const Counts: TDictionary<TJSHeapObject, Integer>;
                           const Retained: THashSet<TJSHeapObject>);
    procedure ReleaseUnretained(const Objects: TList<TJSHeapObject>;
                                const Retained: THashSet<TJSHeapObject>);
    procedure Detach;

  public
    destructor Destroy; override;

    class function Switch(const Heap: TJSHeap): TJSHeap; static;

    procedure ReleaseAll;
  end;

implementation

const
  INITIAL_CAPACITY = 64;
  KEEP_ALIVE_REFERENCES = 1;

threadvar
  CurrentHeap: TJSHeap;

{ TJSHeapObject }

constructor TJSHeapObject.Create;
begin
  inherited Create;

  const Heap = CurrentHeap;
  if Assigned(Heap) then
  begin
    Heap.Add(Self);
  end;
end;

destructor TJSHeapObject.Destroy;
begin
  if Assigned(FHeap) then
  begin
    FHeap.Remove(Self);
  end;

  inherited;
end;

function TJSHeapObject.IsReleasedWithEngine: Boolean;
begin
  Result := False;
end;

class procedure TJSHeapObject.ReportReference(const Visit: TJSHeapVisitor; const Reference: IInterface);
begin
  if not Assigned(Reference) then
    Exit;

  const Target = Reference as TObject;
  const IsHeapObject = (Target is TJSHeapObject);
  if IsHeapObject then
  begin
    Visit(TJSHeapObject(Target));
  end;
end;

{ TJSHeap }

destructor TJSHeap.Destroy;
begin
  Detach;
  inherited;
end;

class function TJSHeap.Switch(const Heap: TJSHeap): TJSHeap;
begin
  Result := CurrentHeap;
  CurrentHeap := Heap;
end;

procedure TJSHeap.Add(const Item: TJSHeapObject);
begin
  const IsFull = (FCount = Length(FObjects));
  if IsFull then
  begin
    SetLength(FObjects, (FCount * 2) + INITIAL_CAPACITY);
  end;

  Item.FHeap := Self;
  Item.FHeapSlot := FCount;
  FObjects[FCount] := Item;
  Inc(FCount);
end;

procedure TJSHeap.Remove(const Item: TJSHeapObject);
begin
  Dec(FCount);

  const Last = FObjects[FCount];
  FObjects[Item.FHeapSlot] := Last;
  Last.FHeapSlot := Item.FHeapSlot;
  FObjects[FCount] := nil;

  Item.FHeap := nil;
end;

procedure TJSHeap.Detach;
begin
  for var Item in FObjects do
  begin
    if Assigned(Item) then
    begin
      Item.FHeap := nil;
    end;
  end;

  FObjects := nil;
  FCount := 0;
end;

procedure TJSHeap.ListObjects(const Objects: TList<TJSHeapObject>; const KeepAlive: TList<IInterface>);
begin
  for var Item in FObjects do
  begin
    if Assigned(Item) then
    begin
      Objects.Add(Item);
      KeepAlive.Add(Item);
    end;
  end;
end;

procedure TJSHeap.ReleaseFunctions(const Objects: TList<TJSHeapObject>);
begin
  for var Item in Objects do
  begin
    if Item.IsReleasedWithEngine then
    begin
      Item.ReleaseReferences;
    end;
  end;
end;

procedure TJSHeap.CountReferences(const Objects: TList<TJSHeapObject>;
                                  const Counts: TDictionary<TJSHeapObject, Integer>);
begin
  const CountReference: TJSHeapVisitor =
    procedure(const Target: TJSHeapObject)
    begin
      const ExistingCount = CountedReferences(Counts, Target);
      Counts.AddOrSetValue(Target, ExistingCount + 1);
    end;

  for var Item in Objects do
  begin
    if not Item.IsReleasedWithEngine then
    begin
      Item.EnumerateHeapReferences(CountReference);
    end;
  end;
end;

class function TJSHeap.CountedReferences(const Counts: TDictionary<TJSHeapObject, Integer>;
                                         const Item: TJSHeapObject): Integer;
begin
  if not Counts.TryGetValue(Item, Result) then
  begin
    Result := 0;
  end;
end;

function TJSHeap.IsHeldFromOutside(const Item: TJSHeapObject;
                                   const Counts: TDictionary<TJSHeapObject, Integer>): Boolean;
begin
  const CountedByHeap = CountedReferences(Counts, Item);
  Result := ((Item.RefCount - KEEP_ALIVE_REFERENCES) > CountedByHeap);
end;

procedure TJSHeap.RetainHeldFromOutside(const Objects: TList<TJSHeapObject>;
                                        const Counts: TDictionary<TJSHeapObject, Integer>;
                                        const Retain: TJSHeapVisitor);
begin
  for var Item in Objects do
  begin
    if IsHeldFromOutside(Item, Counts) then
    begin
      Retain(Item);
    end;
  end;
end;

procedure TJSHeap.RetainReachable(const Pending: TStack<TJSHeapObject>; const Retain: TJSHeapVisitor);
begin
  while True do
  begin
    const IsDrained = (Pending.Count = 0);
    if IsDrained then
      Break;

    const Next = Pending.Pop;
    Next.EnumerateHeapReferences(Retain);
  end;
end;

procedure TJSHeap.FindRetained(const Objects: TList<TJSHeapObject>;
                               const Counts: TDictionary<TJSHeapObject, Integer>;
                               const Retained: THashSet<TJSHeapObject>);
begin
  const Pending = TStack<TJSHeapObject>.Create;
  try
    const Retain: TJSHeapVisitor =
      procedure(const Target: TJSHeapObject)
      begin
        const IsNew = ((not Target.IsReleasedWithEngine) and (not Retained.Contains(Target)));
        if IsNew then
        begin
          Retained.Add(Target);
          Pending.Push(Target);
        end;
      end;

    RetainHeldFromOutside(Objects, Counts, Retain);
    RetainReachable(Pending, Retain);
  finally
    Pending.Free;
  end;
end;

procedure TJSHeap.ReleaseUnretained(const Objects: TList<TJSHeapObject>;
                                    const Retained: THashSet<TJSHeapObject>);
begin
  for var Item in Objects do
  begin
    const IsKept = (Item.IsReleasedWithEngine or Retained.Contains(Item));
    if not IsKept then
    begin
      Item.ReleaseReferences;
    end;
  end;
end;

procedure TJSHeap.ReleaseAll;
begin
  const Objects = TList<TJSHeapObject>.Create;
  const KeepAlive = TList<IInterface>.Create;
  const Counts = TDictionary<TJSHeapObject, Integer>.Create;
  const Retained = THashSet<TJSHeapObject>.Create;
  try
    ListObjects(Objects, KeepAlive);
    ReleaseFunctions(Objects);
    CountReferences(Objects, Counts);
    FindRetained(Objects, Counts, Retained);
    ReleaseUnretained(Objects, Retained);
  finally
    Retained.Free;
    Counts.Free;
    KeepAlive.Free;
    Objects.Free;
  end;

  Detach;
end;

end.
