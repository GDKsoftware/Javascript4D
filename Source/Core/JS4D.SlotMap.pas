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
    FValues: TArray<T>;
    FCount: Integer;
    FLayoutVersion: Cardinal;

    procedure Append(const Name: string; const Value: T);
    procedure GrowStorage;
    function GetItem(const Name: string): T;
    procedure SetItem(const Name: string; const Value: T);

  public
    constructor Create;
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

    property Count: Integer read FCount;
    property Items[const Name: string]: T read GetItem write SetItem; default;
    property LayoutVersion: Cardinal read FLayoutVersion;
  end;

implementation

uses
  System.SysUtils;

const
  INITIAL_CAPACITY = 4;

constructor TJSSlotMap<T>.Create;
begin
  inherited Create;
  FIndexByName := TDictionary<string, Integer>.Create;
end;

destructor TJSSlotMap<T>.Destroy;
begin
  FIndexByName.Free;
  inherited;
end;

function TJSSlotMap<T>.GetItem(const Name: string): T;
begin
  var Position: Integer;
  if not FIndexByName.TryGetValue(Name, Position) then
    raise EListError.CreateFmt('Property %s does not exist', [Name]);

  Result := FValues[Position];
end;

procedure TJSSlotMap<T>.SetItem(const Name: string; const Value: T);
begin
  AddOrSetValue(Name, Value);
end;

function TJSSlotMap<T>.TryGetValue(const Name: string; out Value: T): Boolean;
begin
  var Position: Integer;
  Result := FIndexByName.TryGetValue(Name, Position);

  if Result then
    Value := FValues[Position];
end;

function TJSSlotMap<T>.TryGetSlot(const Name: string; out Slot: PSlot): Boolean;
begin
  var Position: Integer;
  Result := (FCount > 0) and FIndexByName.TryGetValue(Name, Position);

  if Result then
    Slot := @FValues[Position]
  else
    Slot := nil;
end;

function TJSSlotMap<T>.ContainsKey(const Name: string): Boolean;
begin
  Result := FIndexByName.ContainsKey(Name);
end;

procedure TJSSlotMap<T>.GrowStorage;
begin
  var Capacity := Length(FValues) * 2;
  if Capacity < INITIAL_CAPACITY then
    Capacity := INITIAL_CAPACITY;

  SetLength(FValues, Capacity);
  SetLength(FNames, Capacity);
  Inc(FLayoutVersion);
end;

procedure TJSSlotMap<T>.Append(const Name: string; const Value: T);
begin
  if FCount = Length(FValues) then
    GrowStorage;

  FNames[FCount] := Name;
  FValues[FCount] := Value;
  FIndexByName.Add(Name, FCount);
  Inc(FCount);
end;

procedure TJSSlotMap<T>.Add(const Name: string; const Value: T);
begin
  if FIndexByName.ContainsKey(Name) then
    raise EListError.CreateFmt('Property %s already exists', [Name]);

  Append(Name, Value);
end;

procedure TJSSlotMap<T>.AddOrSetValue(const Name: string; const Value: T);
begin
  var Position: Integer;
  if FIndexByName.TryGetValue(Name, Position) then
    FValues[Position] := Value
  else
    Append(Name, Value);
end;

procedure TJSSlotMap<T>.Remove(const Name: string);
begin
  var Position: Integer;
  if not FIndexByName.TryGetValue(Name, Position) then
    Exit;

  const LastPosition = FCount - 1;
  FIndexByName.Remove(Name);

  if Position <> LastPosition then
  begin
    FNames[Position] := FNames[LastPosition];
    FValues[Position] := FValues[LastPosition];
    FIndexByName[FNames[Position]] := Position;
  end;

  FNames[LastPosition] := '';
  FValues[LastPosition] := Default(T);
  FCount := LastPosition;
  Inc(FLayoutVersion);
end;

procedure TJSSlotMap<T>.Clear;
begin
  FIndexByName.Clear;
  FNames := nil;
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

end.
