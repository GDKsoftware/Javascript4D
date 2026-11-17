unit JS4D.SlotMap;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections;

type
  TJSSlotMap<T> = class
  public
    type
      PSlot = ^T;

  private
    FIndexByName: TDictionary<string, Integer>;
    FNames: TArray<string>;
    FFingerprints: TArray<Cardinal>;
    FValues: TArray<T>;
    FCount: Integer;
    FLayoutVersion: Cardinal;

    class function FingerprintOf(const Name: string): Cardinal; static; inline;
    function IndexOf(const Name: string): Integer;
    procedure Append(const Name: string; const Value: T);
    procedure BuildIndex;
    procedure GrowStorage;
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
    function Names: TArray<string>;
    function SlotAt(const Position: Integer): PSlot;
    function NameAt(const Position: Integer): string;

    property Count: Integer read FCount;
    property Items[const Name: string]: T read GetItem write SetItem; default;
    property LayoutVersion: Cardinal read FLayoutVersion;
  end;

implementation

uses
  System.SysUtils;

const
  INITIAL_CAPACITY = 4;
  LINEAR_SEARCH_LIMIT = 8;

destructor TJSSlotMap<T>.Destroy;
begin
  FIndexByName.Free;
  inherited;
end;

class function TJSSlotMap<T>.FingerprintOf(const Name: string): Cardinal;
begin
  const NameLength = Length(Name);
  const IsEmpty = (NameLength = 0);
  if IsEmpty then
    Exit(0);

  Result := (Cardinal(NameLength) shl 20) xor (Cardinal(Ord(Name[1])) shl 10) xor Cardinal(Ord(Name[NameLength]));
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
    raise EListError.CreateFmt('Property %s does not exist', [Name]);

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
  var Capacity := Length(FValues) * 2;
  if Capacity < INITIAL_CAPACITY then
    Capacity := INITIAL_CAPACITY;

  SetLength(FValues, Capacity);
  SetLength(FNames, Capacity);
  SetLength(FFingerprints, Capacity);
  Inc(FLayoutVersion);
end;

procedure TJSSlotMap<T>.Append(const Name: string; const Value: T);
begin
  if FCount = Length(FValues) then
    GrowStorage;

  FNames[FCount] := Name;
  FFingerprints[FCount] := FingerprintOf(Name);
  FValues[FCount] := Value;
  Inc(FCount);

  const NeedsIndex = (FCount > LINEAR_SEARCH_LIMIT);
  if Assigned(FIndexByName) then
    FIndexByName.Add(Name, FCount - 1)
  else if NeedsIndex then
    BuildIndex;
end;

procedure TJSSlotMap<T>.Add(const Name: string; const Value: T);
begin
  const IsPresent = (IndexOf(Name) >= 0);
  if IsPresent then
    raise EListError.CreateFmt('Property %s already exists', [Name]);

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

  if Position <> LastPosition then
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

procedure TJSSlotMap<T>.Clear;
begin
  FreeAndNil(FIndexByName);
  FNames := nil;
  FFingerprints := nil;
  FValues := nil;
  FCount := 0;
  Inc(FLayoutVersion);
end;

function TJSSlotMap<T>.Names: TArray<string>;
begin
  Result := Copy(FNames, 0, FCount);
end;

function TJSSlotMap<T>.SlotAt(const Position: Integer): PSlot;
begin
  Result := @FValues[Position];
end;

function TJSSlotMap<T>.NameAt(const Position: Integer): string;
begin
  Result := FNames[Position];
end;

end.
