unit JS4D.SymbolRegistry;

{$SCOPEDENUMS ON}

interface

uses
  System.SyncObjs,
  System.Generics.Collections,
  JS4D.PropertyKey;

type
  TJSWellKnownSymbol = (
    AsyncIterator,
    HasInstance,
    IsConcatSpreadable,
    Iterator,
    Match,
    MatchAll,
    Replace,
    Search,
    Species,
    Split,
    ToPrimitive,
    ToStringTag,
    Unscopables
  );

  TJSSymbolRegistry = class
  private
    const
      FIRST_DYNAMIC_ID = 100;
      WELL_KNOWN_ID_BASE = 1;
      WELL_KNOWN_DESCRIPTION_FORMAT = 'Symbol.%s';

    class var FLock: TCriticalSection;
    class var FLive: TDictionary<Integer, TObject>;
    class var FLastId: Integer;
    class var FWellKnownKeys: array[TJSWellKnownSymbol] of TJSPropertyKey;
    class var FWellKnownDescriptions: array[TJSWellKnownSymbol] of string;

    class constructor Create;
    class destructor Destroy;

  public
    class function WellKnownKey(const Which: TJSWellKnownSymbol): TJSPropertyKey; static; inline;
    class function WellKnownDescription(const Which: TJSWellKnownSymbol): string; static;
    class function WellKnownId(const Which: TJSWellKnownSymbol): Integer; static;
    class function NextId: Integer; static;
    class procedure RegisterSymbol(const Id: Integer; const Symbol: TObject); static;
    class procedure UnregisterSymbol(const Id: Integer); static;
    class function Find(const Id: Integer): TObject; static;
  end;

implementation

uses
  System.SysUtils,
  System.TypInfo;

class constructor TJSSymbolRegistry.Create;
begin
  FLock := TCriticalSection.Create;
  FLive := TDictionary<Integer, TObject>.Create;
  FLastId := FIRST_DYNAMIC_ID;

  Assert(WellKnownId(High(TJSWellKnownSymbol)) < FIRST_DYNAMIC_ID);

  for var Which := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    const EnumName = GetEnumName(TypeInfo(TJSWellKnownSymbol), Ord(Which));
    const PropertyName = EnumName.Substring(0, 1).ToLower + EnumName.Substring(1);

    FWellKnownKeys[Which] := TJSPropertyKey.ForSymbol(WellKnownId(Which));
    FWellKnownDescriptions[Which] := Format(WELL_KNOWN_DESCRIPTION_FORMAT, [PropertyName]);
  end;
end;

class destructor TJSSymbolRegistry.Destroy;
begin
  FreeAndNil(FLive);
  FreeAndNil(FLock);
end;

class function TJSSymbolRegistry.WellKnownKey(const Which: TJSWellKnownSymbol): TJSPropertyKey;
begin
  Result := FWellKnownKeys[Which];
end;

class function TJSSymbolRegistry.WellKnownDescription(const Which: TJSWellKnownSymbol): string;
begin
  Result := FWellKnownDescriptions[Which];
end;

class function TJSSymbolRegistry.WellKnownId(const Which: TJSWellKnownSymbol): Integer;
begin
  Result := Ord(Which) + WELL_KNOWN_ID_BASE;
end;

class function TJSSymbolRegistry.NextId: Integer;
begin
  Result := TInterlocked.Increment(FLastId);
end;

class procedure TJSSymbolRegistry.RegisterSymbol(const Id: Integer; const Symbol: TObject);
begin
  FLock.Enter;
  try
    FLive.Add(Id, Symbol);
  finally
    FLock.Leave;
  end;
end;

class procedure TJSSymbolRegistry.UnregisterSymbol(const Id: Integer);
begin
  const IsRegistryGone = (not Assigned(FLock));
  if IsRegistryGone then
    Exit;

  FLock.Enter;
  try
    FLive.Remove(Id);
  finally
    FLock.Leave;
  end;
end;

class function TJSSymbolRegistry.Find(const Id: Integer): TObject;
begin
  FLock.Enter;
  try
    if not FLive.TryGetValue(Id, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

end.
