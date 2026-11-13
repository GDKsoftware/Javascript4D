unit JS4D.ObjectHeap;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TJSHeap = class;
  TJSHeapObject = class;

  TJSHeapVisitor = reference to procedure(const Item: TJSHeapObject);

  // The base of every object an engine creates. An object joins the heap that is current on its thread when it is
  // made and leaves it when it is freed, so the heap always lists the objects that are alive.
  TJSHeapObject = class(TInterfacedObject)
  private
    FHeap: TJSHeap;
    FHeapSlot: Integer;

  protected
    // Drops every reference this object holds to other objects, so that a cycle it belongs to is broken. The object
    // itself stays valid and empty.
    procedure ReleaseReferences; virtual;
    // Reports every object of the heap that this object holds a reference to, once for each reference. An object
    // that holds a reference without reporting it makes the object it refers to look as if the host holds it.
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); virtual;
    // True for an object that is emptied when its engine goes away, whoever still holds it: a function, which
    // keeps the scope it was made in.
    function IsReleasedWithEngine: Boolean; virtual;

    class procedure ReportReference(const Visit: TJSHeapVisitor; const Reference: IInterface); static;

  public
    constructor Create;
    destructor Destroy; override;
  end;

  // Lists the objects of one engine without keeping them alive. A script can build cycles of objects that reference
  // counting never frees; when the engine goes away the heap empties every object that is still alive, which breaks
  // those cycles.
  TJSHeap = class
  private
    FObjects: TArray<TJSHeapObject>;
    FCount: Integer;

    procedure Add(const Item: TJSHeapObject);
    procedure Remove(const Item: TJSHeapObject);
    procedure ListObjects(const Objects: TList<TJSHeapObject>; const Holders: TList<IInterface>);
    procedure ReleaseFunctions(const Objects: TList<TJSHeapObject>);
    function CountReferences(const Objects: TList<TJSHeapObject>): TDictionary<TJSHeapObject, Integer>;
    function FindRetained(const Objects: TList<TJSHeapObject>): TDictionary<TJSHeapObject, Byte>;
    procedure ReleaseUnretained(const Objects: TList<TJSHeapObject>;
                                const Retained: TDictionary<TJSHeapObject, Byte>);
    procedure Detach;

  public
    destructor Destroy; override;

    // Makes Heap the heap that new objects join and returns the one it replaces. A nil heap makes objects that
    // belong to no engine.
    class function Switch(const Heap: TJSHeap): TJSHeap; static;

    // Empties every object of the heap that nothing outside the engine holds, and every function. An object that the
    // host still holds, and what it refers to, keeps its contents; it is no longer listed.
    procedure ReleaseAll;
  end;

implementation

const
  INITIAL_CAPACITY = 64;

threadvar
  CurrentHeap: TJSHeap;

{ TJSHeapObject }

constructor TJSHeapObject.Create;
begin
  inherited Create;

  const Heap = CurrentHeap;
  if Assigned(Heap) then
    Heap.Add(Self);
end;

destructor TJSHeapObject.Destroy;
begin
  if Assigned(FHeap) then
    FHeap.Remove(Self);

  inherited;
end;

procedure TJSHeapObject.ReleaseReferences;
begin
end;

procedure TJSHeapObject.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
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
  if Target is TJSHeapObject then
    Visit(TJSHeapObject(Target));
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
  if FCount = Length(FObjects) then
    SetLength(FObjects, (FCount * 2) + INITIAL_CAPACITY);

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
  for var Index := 0 to FCount - 1 do
  begin
    FObjects[Index].FHeap := nil;
  end;

  FObjects := nil;
  FCount := 0;
end;

procedure TJSHeap.ListObjects(const Objects: TList<TJSHeapObject>; const Holders: TList<IInterface>);
begin
  for var Index := 0 to FCount - 1 do
  begin
    const Item = FObjects[Index];
    Objects.Add(Item);
    Holders.Add(Item);
  end;
end;

procedure TJSHeap.ReleaseFunctions(const Objects: TList<TJSHeapObject>);
begin
  for var Item in Objects do
  begin
    if Item.IsReleasedWithEngine then
      Item.ReleaseReferences;
  end;
end;

function TJSHeap.CountReferences(const Objects: TList<TJSHeapObject>): TDictionary<TJSHeapObject, Integer>;
begin
  const Counts = TDictionary<TJSHeapObject, Integer>.Create;
  Result := Counts;

  const Count: TJSHeapVisitor =
    procedure(const Target: TJSHeapObject)
    begin
      var Current: Integer;
      Counts.TryGetValue(Target, Current);
      Counts.AddOrSetValue(Target, Current + 1);
    end;

  for var Item in Objects do
  begin
    if not Item.IsReleasedWithEngine then
      Item.EnumerateHeapReferences(Count);
  end;
end;

function TJSHeap.FindRetained(const Objects: TList<TJSHeapObject>): TDictionary<TJSHeapObject, Byte>;
begin
  const Retained = TDictionary<TJSHeapObject, Byte>.Create;
  Result := Retained;

  const Counts = CountReferences(Objects);
  try
    const Pending = TStack<TJSHeapObject>.Create;
    try
      const Retain: TJSHeapVisitor =
        procedure(const Target: TJSHeapObject)
        begin
          const IsNew = (not Target.IsReleasedWithEngine) and (not Retained.ContainsKey(Target));
          if IsNew then
          begin
            Retained.Add(Target, 0);
            Pending.Push(Target);
          end;
        end;

      const OwnReferences = 1;
      for var Item in Objects do
      begin
        var Counted: Integer;
        Counts.TryGetValue(Item, Counted);

        const IsHeldFromOutside = (Item.RefCount - OwnReferences) > Counted;
        if IsHeldFromOutside then
          Retain(Item);
      end;

      while Pending.Count > 0 do
      begin
        const Next = Pending.Pop;
        Next.EnumerateHeapReferences(Retain);
      end;
    finally
      Pending.Free;
    end;
  finally
    Counts.Free;
  end;
end;

procedure TJSHeap.ReleaseUnretained(const Objects: TList<TJSHeapObject>;
                                    const Retained: TDictionary<TJSHeapObject, Byte>);
begin
  for var Item in Objects do
  begin
    const IsKept = Item.IsReleasedWithEngine or Retained.ContainsKey(Item);
    if not IsKept then
      Item.ReleaseReferences;
  end;
end;

procedure TJSHeap.ReleaseAll;
begin
  const Objects = TList<TJSHeapObject>.Create;
  const Holders = TList<IInterface>.Create;
  try
    ListObjects(Objects, Holders);
    ReleaseFunctions(Objects);

    const Retained = FindRetained(Objects);
    try
      ReleaseUnretained(Objects, Retained);
    finally
      Retained.Free;
    end;
  finally
    Holders.Free;
    Objects.Free;
  end;

  Detach;
end;

end.
