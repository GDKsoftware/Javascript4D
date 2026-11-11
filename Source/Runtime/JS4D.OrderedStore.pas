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
  // The identity of a value under SameValueZero: NaN equals NaN, +0 equals -0, strings and numbers compare by
  // content, objects and symbols by identity. The hash is computed once, so rehashing never touches the value.
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

  // A position in the entries of a store that survives additions, deletions and compaction, for forEach and
  // for iterators. A cursor sees entries added after it was created and never sees an entry twice.
  TJSStoreCursor = class
  private
    FStore: TJSOrderedStore;
    FPosition: Integer;

  public
    constructor Create(const Store: TJSOrderedStore);
    destructor Destroy; override;

    function TryNext(out Key: TJSValue; out Value: TJSValue): Boolean;
  end;

  // Entries in insertion order with an average O(1) lookup by SameValueZero. A deleted entry leaves a gap that
  // keeps the position of the cursors valid until the gaps are compacted away.
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

    var
      FEntries: TArray<TEntry>;
      FUsed: Integer;
      FGaps: Integer;
      FIndex: TDictionary<TJSStoreKey, Integer>;
      FCursors: TList<TJSStoreCursor>;

    function GetCount: Integer;
    procedure Append(const Identity: TJSStoreKey; const Key: TJSValue; const Value: TJSValue);
    procedure CompactIfSparse;
    procedure Compact;
    procedure MoveCursors(const LiveBefore: TArray<Integer>);
    procedure RegisterCursor(const Cursor: TJSStoreCursor);
    procedure UnregisterCursor(const Cursor: TJSStoreCursor);
    function TryReadFrom(var Position: Integer; out Key: TJSValue; out Value: TJSValue): Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    // The key as the store keeps and hands it out: -0 becomes +0, every other value stays as it is.
    class function CanonicalKey(const Key: TJSValue): TJSValue; static;

    function TryGet(const Key: TJSValue; out Value: TJSValue): Boolean;
    function Contains(const Key: TJSValue): Boolean;
    procedure Put(const Key: TJSValue; const Value: TJSValue);
    function Remove(const Key: TJSValue): Boolean;
    procedure Clear;

    property Count: Integer read GetCount;
  end;

implementation

uses
  System.Math;

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
    Result := Ord(Key.FKind) * 31 + Ord(Key.FNumber <> 0);
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
    TJSValueType.Symbol   : Result.FText := Value.AsSymbolKey;
    TJSValueType.Object_  : Result.FIdentity := Pointer(Value.AsObject as IInterface);
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
  Result := FStore.TryReadFrom(FPosition, Key, Value);
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
    Exit(TJSValue.CreateNumber(0));

  Result := Key;
end;

function TJSOrderedStore.TryGet(const Key: TJSValue; out Value: TJSValue): Boolean;
begin
  var Slot: Integer;
  Result := FIndex.TryGetValue(TJSStoreKey.From(Key), Slot);
  if Result then
    Value := FEntries[Slot].Value
  else
    Value := TJSValue.CreateUndefined;
end;

function TJSOrderedStore.Contains(const Key: TJSValue): Boolean;
begin
  Result := FIndex.ContainsKey(TJSStoreKey.From(Key));
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
    SetLength(FEntries, Max(8, FUsed * 2));

  FEntries[FUsed].Identity := Identity;
  FEntries[FUsed].Key := CanonicalKey(Key);
  FEntries[FUsed].Value := Value;
  FEntries[FUsed].IsLive := True;
  FIndex.Add(Identity, FUsed);
  Inc(FUsed);
end;

function TJSOrderedStore.Remove(const Key: TJSValue): Boolean;
begin
  var Slot: Integer;
  Result := FIndex.TryGetValue(TJSStoreKey.From(Key), Slot);
  if not Result then
    Exit;

  FIndex.Remove(FEntries[Slot].Identity);
  FEntries[Slot] := Default(TEntry);
  Inc(FGaps);
  CompactIfSparse;
end;

procedure TJSOrderedStore.Clear;
begin
  const Released = FEntries;
  FEntries := nil;
  FUsed := 0;
  FGaps := 0;
  FIndex.Clear;

  for var Cursor in FCursors do
  begin
    Cursor.FPosition := 0;
  end;
end;

procedure TJSOrderedStore.CompactIfSparse;
begin
  const HasManyGaps = (FGaps >= MIN_GAPS_TO_COMPACT) and (FGaps * 2 >= FUsed);
  if HasManyGaps then
    Compact;
end;

procedure TJSOrderedStore.Compact;
begin
  var LiveBefore: TArray<Integer>;
  const HasCursors = (FCursors.Count > 0);
  if HasCursors then
    SetLength(LiveBefore, FUsed + 1);

  var Target := 0;
  for var Source := 0 to FUsed - 1 do
  begin
    if HasCursors then
      LiveBefore[Source] := Target;

    if not FEntries[Source].IsLive then
      Continue;

    if Target <> Source then
    begin
      FEntries[Target] := FEntries[Source];
      FIndex[FEntries[Target].Identity] := Target;
    end;

    Inc(Target);
  end;

  if HasCursors then
  begin
    LiveBefore[FUsed] := Target;
    MoveCursors(LiveBefore);
  end;

  for var Index := Target to FUsed - 1 do
  begin
    FEntries[Index] := Default(TEntry);
  end;

  FUsed := Target;
  FGaps := 0;
end;

procedure TJSOrderedStore.MoveCursors(const LiveBefore: TArray<Integer>);
begin
  for var Cursor in FCursors do
  begin
    Cursor.FPosition := LiveBefore[Min(Cursor.FPosition, FUsed)];
  end;
end;

function TJSOrderedStore.TryReadFrom(var Position: Integer; out Key: TJSValue; out Value: TJSValue): Boolean;
begin
  while Position < FUsed do
  begin
    const Slot = Position;
    Inc(Position);

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
