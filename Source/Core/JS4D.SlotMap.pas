unit JS4D.SlotMap;

interface

uses
  System.Generics.Collections;

type
  TJSSlotMap<T> = class
  public
    type
      PSlot = ^T;

      TSlotEnumerator = record
      private
        FMap: TJSSlotMap<T>;
        FPosition: Integer;

        function GetCurrent: PSlot;

      public
        constructor Create(const Map: TJSSlotMap<T>);

        function MoveNext: Boolean;

        property Current: PSlot read GetCurrent;
      end;

  private
    const
      INITIAL_CAPACITY = 4;
      LINEAR_SEARCH_LIMIT = 8;
      KEY_MISSING_MESSAGE = 'Key %s does not exist';
      KEY_PRESENT_MESSAGE = 'Key %s already exists';
      FINGERPRINT_LENGTH_SHIFT = 20;
      FINGERPRINT_FIRST_CHARACTER_SHIFT = 10;

    var
      FIndexByName: TDictionary<string, Integer>;
      FNames: TArray<string>;
      FFingerprints: TArray<Cardinal>;
      FInsertionOrder: TArray<Integer>;
      FValues: TArray<T>;
      FCount: Integer;
      FLayoutVersion: Cardinal;

    class function FingerprintOf(const Name: string): Cardinal; static; inline;
    function IndexOf(const Name: string): Integer;
    procedure Append(const Name: string; const Value: T);
    procedure BuildIndex;
    procedure GrowStorage;
    function InsertionOrderIndexOf(const Position: Integer): Integer;
    procedure ForgetInsertionOrder(const Position: Integer; const LastPosition: Integer);
    function GetItem(const Name: string): T;
    procedure SetItem(const Name: string; const Value: T);

  public
    destructor Destroy; override;

    function TryGetValue(const Name: string; out Value: T): Boolean;
    function TryGetSlot(const Name: string; out Slot: PSlot): Boolean;
    function ContainsKey(const Name: string): Boolean;
    procedure Add(const Name: string; const Value: T);
    procedure AddOrSetValue(const Name: string; const Value: T);
    procedure Remove(const Name: string);
    procedure Clear;
    function GetEnumerator: TSlotEnumerator;
    function Names: TArray<string>;
    function SlotAt(const Position: Integer): PSlot;
    function ValueAt(const Position: Integer): T;
    function NameAt(const Position: Integer): string;
    function NameInInsertionOrder(const OrderIndex: Integer): string;

    property Count: Integer read FCount;
    property Items[const Name: string]: T read GetItem write SetItem; default;
    property LayoutVersion: Cardinal read FLayoutVersion;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

constructor TJSSlotMap<T>.TSlotEnumerator.Create(const Map: TJSSlotMap<T>);
begin
  FMap := Map;
  FPosition := -1;
end;

function TJSSlotMap<T>.TSlotEnumerator.MoveNext: Boolean;
begin
  Inc(FPosition);

  Result := (FPosition < FMap.Count);
end;

function TJSSlotMap<T>.TSlotEnumerator.GetCurrent: PSlot;
begin
  Result := FMap.SlotAt(FPosition);
end;

destructor TJSSlotMap<T>.Destroy;
begin
  FIndexByName.Free;
  inherited Destroy;
end;

function TJSSlotMap<T>.GetEnumerator: TSlotEnumerator;
begin
  Result := TSlotEnumerator.Create(Self);
end;

class function TJSSlotMap<T>.FingerprintOf(const Name: string): Cardinal;
begin
  const NameLength = Length(Name);
  const IsEmpty = (NameLength = 0);
  if IsEmpty then
    Exit(0);

  Result := (Cardinal(NameLength) shl FINGERPRINT_LENGTH_SHIFT) xor
            (Cardinal(Ord(Name[1])) shl FINGERPRINT_FIRST_CHARACTER_SHIFT) xor
            Cardinal(Ord(Name[NameLength]));
end;

function TJSSlotMap<T>.IndexOf(const Name: string): Integer;
begin
  if Assigned(FIndexByName) then
  begin
    if not FIndexByName.TryGetValue(Name, Result) then
      Result := -1;

    Exit;
  end;

  const Wanted = FingerprintOf(Name);

  for var Position := 0 to FCount - 1 do
  begin
    const IsOtherName = (FFingerprints[Position] <> Wanted);
    if IsOtherName then
      Continue;

    const IsMatch = (Pointer(FNames[Position]) = Pointer(Name)) or (FNames[Position] = Name);
    if IsMatch then
      Exit(Position);
  end;

  Result := -1;
end;

procedure TJSSlotMap<T>.BuildIndex;
begin
  FIndexByName := TDictionary<string, Integer>.Create;

  for var Position := 0 to FCount - 1 do
  begin
    FIndexByName.Add(FNames[Position], Position);
  end;
end;

function TJSSlotMap<T>.GetItem(const Name: string): T;
begin
  const Position = IndexOf(Name);
  const IsMissing = (Position < 0);
  if IsMissing then
    raise EListError.CreateFmt(KEY_MISSING_MESSAGE, [Name]);

  Result := FValues[Position];
end;

procedure TJSSlotMap<T>.SetItem(const Name: string; const Value: T);
begin
  AddOrSetValue(Name, Value);
end;

function TJSSlotMap<T>.TryGetValue(const Name: string; out Value: T): Boolean;
begin
  const Position = IndexOf(Name);
  Result := (Position >= 0);

  if Result then
    Value := FValues[Position];
end;

function TJSSlotMap<T>.TryGetSlot(const Name: string; out Slot: PSlot): Boolean;
begin
  const Position = IndexOf(Name);
  Result := (Position >= 0);

  if Result then
    Slot := @FValues[Position]
  else
    Slot := nil;
end;

function TJSSlotMap<T>.ContainsKey(const Name: string): Boolean;
begin
  Result := (IndexOf(Name) >= 0);
end;

procedure TJSSlotMap<T>.GrowStorage;
begin
  const Capacity = Max(Length(FValues) * 2, INITIAL_CAPACITY);

  SetLength(FValues, Capacity);
  SetLength(FNames, Capacity);
  SetLength(FFingerprints, Capacity);
  SetLength(FInsertionOrder, Capacity);
  Inc(FLayoutVersion);
end;

procedure TJSSlotMap<T>.Append(const Name: string; const Value: T);
begin
  const IsFull = (FCount = Length(FValues));
  if IsFull then
    GrowStorage;

  FNames[FCount] := Name;
  FFingerprints[FCount] := FingerprintOf(Name);
  FInsertionOrder[FCount] := FCount;
  FValues[FCount] := Value;
  Inc(FCount);

  if Assigned(FIndexByName) then
  begin
    FIndexByName.Add(Name, FCount - 1);
    Exit;
  end;

  const NeedsIndex = (FCount > LINEAR_SEARCH_LIMIT);
  if NeedsIndex then
    BuildIndex;
end;

procedure TJSSlotMap<T>.Add(const Name: string; const Value: T);
begin
  const IsPresent = (IndexOf(Name) >= 0);
  if IsPresent then
    raise EListError.CreateFmt(KEY_PRESENT_MESSAGE, [Name]);

  Append(Name, Value);
end;

procedure TJSSlotMap<T>.AddOrSetValue(const Name: string; const Value: T);
begin
  const Position = IndexOf(Name);
  const IsPresent = (Position >= 0);
  if IsPresent then
    FValues[Position] := Value
  else
    Append(Name, Value);
end;

procedure TJSSlotMap<T>.Remove(const Name: string);
begin
  const Position = IndexOf(Name);
  const IsMissing = (Position < 0);
  if IsMissing then
    Exit;

  const LastPosition = FCount - 1;
  if Assigned(FIndexByName) then
    FIndexByName.Remove(Name);

  ForgetInsertionOrder(Position, LastPosition);

  const IsLastSlot = (Position = LastPosition);
  if not IsLastSlot then
  begin
    FNames[Position] := FNames[LastPosition];
    FFingerprints[Position] := FFingerprints[LastPosition];
    FValues[Position] := FValues[LastPosition];

    if Assigned(FIndexByName) then
      FIndexByName[FNames[Position]] := Position;
  end;

  FNames[LastPosition] := '';
  FValues[LastPosition] := Default(T);
  FCount := LastPosition;
  Inc(FLayoutVersion);
end;

function TJSSlotMap<T>.InsertionOrderIndexOf(const Position: Integer): Integer;
begin
  for var OrderIndex := 0 to FCount - 1 do
  begin
    const IsPosition = (FInsertionOrder[OrderIndex] = Position);
    if IsPosition then
      Exit(OrderIndex);
  end;

  Result := -1;
end;

procedure TJSSlotMap<T>.ForgetInsertionOrder(const Position: Integer; const LastPosition: Integer);
begin
  const RemovedOrderIndex = InsertionOrderIndexOf(Position);

  const IsLastSlot = (Position = LastPosition);
  if not IsLastSlot then
    FInsertionOrder[InsertionOrderIndexOf(LastPosition)] := Position;

  const MovedCount = FCount - 1 - RemovedOrderIndex;
  const HasEntriesToMove = (MovedCount > 0);
  if HasEntriesToMove then
    Move(FInsertionOrder[RemovedOrderIndex + 1], FInsertionOrder[RemovedOrderIndex], MovedCount * SizeOf(Integer));
end;

procedure TJSSlotMap<T>.Clear;
begin
  FreeAndNil(FIndexByName);
  FNames := nil;
  FFingerprints := nil;
  FInsertionOrder := nil;
  FValues := nil;
  FCount := 0;
  Inc(FLayoutVersion);
end;

function TJSSlotMap<T>.Names: TArray<string>;
begin
  SetLength(Result, FCount);

  for var OrderIndex := 0 to FCount - 1 do
  begin
    Result[OrderIndex] := FNames[FInsertionOrder[OrderIndex]];
  end;
end;

function TJSSlotMap<T>.NameInInsertionOrder(const OrderIndex: Integer): string;
begin
  const IsOccupied = (OrderIndex >= 0) and (OrderIndex < FCount);
  Assert(IsOccupied);

  Result := FNames[FInsertionOrder[OrderIndex]];
end;

function TJSSlotMap<T>.SlotAt(const Position: Integer): PSlot;
begin
  const IsOccupied = (Position >= 0) and (Position < FCount);
  Assert(IsOccupied);

  Result := @FValues[Position];
end;

function TJSSlotMap<T>.ValueAt(const Position: Integer): T;
begin
  const IsOccupied = (Position >= 0) and (Position < FCount);
  Assert(IsOccupied);

  Result := FValues[Position];
end;

function TJSSlotMap<T>.NameAt(const Position: Integer): string;
begin
  const IsOccupied = (Position >= 0) and (Position < FCount);
  Assert(IsOccupied);

  Result := FNames[Position];
end;

end.
