unit JS4D.OrderedStore;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Hash,
  System.Generics.Collections,
  System.Generics.Defaults,
  JS4D.Types;

type
  TJSStoreKey = record
  private
    FKind: TJSValueType;
    FNumber: Double;
    FText: string;
    FIdentity: Pointer;
    FHash: Integer;

    class function KindOf(const Value: TJSValue): TJSValueType; static;
    class function HashOf(const Key: TJSStoreKey): Integer; static;

  public
    class function From(const Value: TJSValue): TJSStoreKey; static;
    class function AreEqual(const Left: TJSStoreKey; const Right: TJSStoreKey): Boolean; static;

    property Hash: Integer read FHash;
  end;

  TJSStoreKeyComparer = class(TEqualityComparer<TJSStoreKey>)
  public
    function Equals(const Left: TJSStoreKey; const Right: TJSStoreKey): Boolean; override;
    function GetHashCode(const Value: TJSStoreKey): Integer; override;
  end;

  TJSOrderedStore = class;

  TJSStoreCursor = class
  private
    FStore: TJSOrderedStore;
    FPosition: Integer;

  public
    constructor Create(const Store: TJSOrderedStore);
    destructor Destroy; override;

    function TryNext(out Key: TJSValue; out Value: TJSValue): Boolean;
  end;

  TJSOrderedStore = class
  private
    type
      TEntry = record
        Identity: TJSStoreKey;
        Key: TJSValue;
        Value: TJSValue;
        IsLive: Boolean;
      end;

    const
      MIN_GAPS_TO_COMPACT = 16;
      MIN_CAPACITY = 8;
      GAPS_PER_USED_TO_COMPACT = 2;

    var
      FEntries: TArray<TEntry>;
      FUsed: Integer;
      FGaps: Integer;
      FIndex: TDictionary<TJSStoreKey, Integer>;
      FCursors: TList<TJSStoreCursor>;

    class function IsNestedObject(const Value: TJSValue): Boolean; static;

    function GetCount: Integer;
    procedure Append(const Identity: TJSStoreKey; const Key: TJSValue; const Value: TJSValue);
    procedure CompactIfSparse;
    function MoveLiveEntries(const LiveBefore: TArray<Integer>): Integer;
    procedure Compact;
    procedure MoveCursors(const LiveBefore: TArray<Integer>);
    procedure RegisterCursor(const Cursor: TJSStoreCursor);
    procedure UnregisterCursor(const Cursor: TJSStoreCursor);
    function TryReadFrom(const Cursor: TJSStoreCursor; out Key: TJSValue; out Value: TJSValue): Boolean;
    procedure ResetAndRelease(EntriesToRelease: TArray<TEntry>);

  public
    constructor Create;
    destructor Destroy; override;

    class function CanonicalKey(const Key: TJSValue): TJSValue; static;

    function TryGet(const Key: TJSValue; out Value: TJSValue): Boolean;
    function Contains(const Key: TJSValue): Boolean;
    procedure Put(const Key: TJSValue; const Value: TJSValue);
    function Remove(const Key: TJSValue): Boolean;
    procedure Clear;

    function HoldsNestedObjects: Boolean;
    procedure DetachNestedObjects(const Pending: TList<IJSObject>);

    property Count: Integer read GetCount;
  end;

implementation

uses
  System.Math;

const
  KIND_HASH_MULTIPLIER = 31;

{ TJSStoreKey }

class function TJSStoreKey.KindOf(const Value: TJSValue): TJSValueType;
begin
  if Value.IsObject then
    Exit(TJSValueType.Object_);

  Result := Value.ValueType;
end;

class function TJSStoreKey.HashOf(const Key: TJSStoreKey): Integer;
begin
  const Seed = Ord(Key.FKind);
  const TextByteCount = Length(Key.FText) * SizeOf(Char);

  case Key.FKind of
    TJSValueType.Number  : Result := THashBobJenkins.GetHashValue(Key.FNumber, SizeOf(Double), Seed);
    TJSValueType.String_,
    TJSValueType.Symbol  : Result := THashBobJenkins.GetHashValue(PChar(Key.FText)^, TextByteCount, Seed);
    TJSValueType.Object_ : Result := THashBobJenkins.GetHashValue(Key.FIdentity, SizeOf(Pointer), Seed);
  else
    Result := (Ord(Key.FKind) * KIND_HASH_MULTIPLIER) + Ord(Key.FNumber <> 0);
  end;
end;

class function TJSStoreKey.From(const Value: TJSValue): TJSStoreKey;
begin
  Result := Default(TJSStoreKey);
  Result.FKind := KindOf(Value);

  case Result.FKind of
    TJSValueType.Boolean_ : Result.FNumber := Ord(Value.AsBoolean);
    TJSValueType.Number   :
      begin
        const IsNotANumber = IsNan(Value.AsNumber);
        const IsZero = (Value.AsNumber = 0);
        if IsNotANumber then
          Result.FNumber := NaN
        else if not IsZero then
          Result.FNumber := Value.AsNumber;
      end;
    TJSValueType.String_  : Result.FText := Value.AsString;
    TJSValueType.Symbol   : Result.FText := Value.AsSymbolKey.Stored;
    TJSValueType.Object_  : Result.FIdentity := Pointer(Value.AsObject as IInterface);
  else
    Result.FNumber := 0;
  end;

  Result.FHash := HashOf(Result);
end;

class function TJSStoreKey.AreEqual(const Left: TJSStoreKey; const Right: TJSStoreKey): Boolean;
begin
  const IsSameShape = (Left.FHash = Right.FHash) and (Left.FKind = Right.FKind);
  if not IsSameShape then
    Exit(False);

  case Left.FKind of
    TJSValueType.Boolean_ : Result := (Left.FNumber = Right.FNumber);
    TJSValueType.Number   : Result := (Left.FNumber = Right.FNumber) or (IsNan(Left.FNumber) and IsNan(Right.FNumber));
    TJSValueType.String_,
    TJSValueType.Symbol   : Result := (Left.FText = Right.FText);
    TJSValueType.Object_  : Result := (Left.FIdentity = Right.FIdentity);
  else
    Result := True;
  end;
end;

{ TJSStoreKeyComparer }

function TJSStoreKeyComparer.Equals(const Left: TJSStoreKey; const Right: TJSStoreKey): Boolean;
begin
  Result := TJSStoreKey.AreEqual(Left, Right);
end;

function TJSStoreKeyComparer.GetHashCode(const Value: TJSStoreKey): Integer;
begin
  Result := Value.Hash;
end;

{ TJSStoreCursor }

constructor TJSStoreCursor.Create(const Store: TJSOrderedStore);
begin
  inherited Create;

  FStore := Store;
  FStore.RegisterCursor(Self);
end;

destructor TJSStoreCursor.Destroy;
begin
  FStore.UnregisterCursor(Self);
  inherited;
end;

function TJSStoreCursor.TryNext(out Key: TJSValue; out Value: TJSValue): Boolean;
begin
  Result := FStore.TryReadFrom(Self, Key, Value);
end;

{ TJSOrderedStore }

constructor TJSOrderedStore.Create;
begin
  inherited Create;

  FIndex := TDictionary<TJSStoreKey, Integer>.Create(TJSStoreKeyComparer.Create);
  FCursors := TList<TJSStoreCursor>.Create;
end;

destructor TJSOrderedStore.Destroy;
begin
  FIndex.Free;
  FCursors.Free;
  inherited;
end;

class function TJSOrderedStore.IsNestedObject(const Value: TJSValue): Boolean;
begin
  Result := (Value.IsObject and (not Value.IsFunction));
end;

function TJSOrderedStore.GetCount: Integer;
begin
  Result := FUsed - FGaps;
end;

procedure TJSOrderedStore.RegisterCursor(const Cursor: TJSStoreCursor);
begin
  FCursors.Add(Cursor);
end;

procedure TJSOrderedStore.UnregisterCursor(const Cursor: TJSStoreCursor);
begin
  FCursors.Remove(Cursor);
end;

class function TJSOrderedStore.CanonicalKey(const Key: TJSValue): TJSValue;
begin
  const IsZero = Key.IsNumber and (Key.AsNumber = 0);
  if IsZero then
  begin
    Result := TJSValue.CreateNumber(0);
    Exit;
  end;

  Result := Key;
end;

function TJSOrderedStore.TryGet(const Key: TJSValue; out Value: TJSValue): Boolean;
begin
  const Identity = TJSStoreKey.From(Key);

  var Slot: Integer;
  Result := FIndex.TryGetValue(Identity, Slot);
  if Result then
    Value := FEntries[Slot].Value
  else
    Value := TJSValue.CreateUndefined;
end;

function TJSOrderedStore.Contains(const Key: TJSValue): Boolean;
begin
  const Identity = TJSStoreKey.From(Key);

  Result := FIndex.ContainsKey(Identity);
end;

procedure TJSOrderedStore.Put(const Key: TJSValue; const Value: TJSValue);
begin
  const Identity = TJSStoreKey.From(Key);

  var Slot: Integer;
  if FIndex.TryGetValue(Identity, Slot) then
  begin
    FEntries[Slot].Value := Value;
    Exit;
  end;

  Append(Identity, Key, Value);
end;

procedure TJSOrderedStore.Append(const Identity: TJSStoreKey; const Key: TJSValue; const Value: TJSValue);
begin
  const IsFull = (FUsed = Length(FEntries));
  if IsFull then
  begin
    const GrownCapacity = Max(MIN_CAPACITY, FUsed * 2);
    SetLength(FEntries, GrownCapacity);
  end;

  FEntries[FUsed].Identity := Identity;
  FEntries[FUsed].Key := CanonicalKey(Key);
  FEntries[FUsed].Value := Value;
  FEntries[FUsed].IsLive := True;
  FIndex.Add(Identity, FUsed);
  Inc(FUsed);
end;

function TJSOrderedStore.Remove(const Key: TJSValue): Boolean;
begin
  const Identity = TJSStoreKey.From(Key);

  var Slot: Integer;
  Result := FIndex.TryGetValue(Identity, Slot);
  if not Result then
    Exit;

  FIndex.Remove(FEntries[Slot].Identity);
  FEntries[Slot] := Default(TEntry);
  Inc(FGaps);
  CompactIfSparse;
end;

procedure TJSOrderedStore.Clear;
begin
  ResetAndRelease(FEntries);
end;

procedure TJSOrderedStore.ResetAndRelease(EntriesToRelease: TArray<TEntry>);
begin
  FEntries := nil;
  FUsed := 0;
  FGaps := 0;
  FIndex.Clear;

  for var Cursor in FCursors do
  begin
    Cursor.FPosition := 0;
  end;
end;

function TJSOrderedStore.HoldsNestedObjects: Boolean;
begin
  for var Entry in FEntries do
  begin
    const IsHeld = (Entry.IsLive and (IsNestedObject(Entry.Key) or IsNestedObject(Entry.Value)));
    if IsHeld then
      Exit(True);
  end;

  Result := False;
end;

procedure TJSOrderedStore.DetachNestedObjects(const Pending: TList<IJSObject>);
begin
  for var Entry in FEntries do
  begin
    if not Entry.IsLive then
      Continue;

    if IsNestedObject(Entry.Key) then
      Pending.Add(Entry.Key.ToObject);

    if IsNestedObject(Entry.Value) then
      Pending.Add(Entry.Value.ToObject);
  end;

  Clear;
end;

procedure TJSOrderedStore.CompactIfSparse;
begin
  const HasManyGaps = (FGaps >= MIN_GAPS_TO_COMPACT) and ((FGaps * GAPS_PER_USED_TO_COMPACT) >= FUsed);
  if HasManyGaps then
    Compact;
end;

function TJSOrderedStore.MoveLiveEntries(const LiveBefore: TArray<Integer>): Integer;
begin
  const TracksCursors = (Length(LiveBefore) > 0);

  Result := 0;
  for var Source := 0 to FUsed - 1 do
  begin
    if TracksCursors then
      LiveBefore[Source] := Result;

    if not FEntries[Source].IsLive then
      Continue;

    const HasMoved = (Result <> Source);
    if HasMoved then
    begin
      FEntries[Result] := FEntries[Source];
      FIndex[FEntries[Result].Identity] := Result;
    end;

    Inc(Result);
  end;
end;

procedure TJSOrderedStore.Compact;
begin
  var LiveBefore: TArray<Integer>;
  const HasCursors = (FCursors.Count > 0);
  if HasCursors then
    SetLength(LiveBefore, FUsed + 1);

  const LiveCount = MoveLiveEntries(LiveBefore);

  if HasCursors then
  begin
    LiveBefore[FUsed] := LiveCount;
    MoveCursors(LiveBefore);
  end;

  for var Index := LiveCount to FUsed - 1 do
  begin
    FEntries[Index] := Default(TEntry);
  end;

  FUsed := LiveCount;
  FGaps := 0;
end;

procedure TJSOrderedStore.MoveCursors(const LiveBefore: TArray<Integer>);
begin
  for var Cursor in FCursors do
  begin
    const ClampedPosition = Min(Cursor.FPosition, FUsed);
    Cursor.FPosition := LiveBefore[ClampedPosition];
  end;
end;

function TJSOrderedStore.TryReadFrom(const Cursor: TJSStoreCursor; out Key: TJSValue;
                                      out Value: TJSValue): Boolean;
begin
  while Cursor.FPosition < FUsed do
  begin
    const Slot = Cursor.FPosition;
    Inc(Cursor.FPosition);

    if FEntries[Slot].IsLive then
    begin
      Key := FEntries[Slot].Key;
      Value := FEntries[Slot].Value;
      Exit(True);
    end;
  end;

  Key := TJSValue.CreateUndefined;
  Value := TJSValue.CreateUndefined;
  Result := False;
end;

end.
