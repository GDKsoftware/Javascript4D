unit JS4D.SymbolRegistry;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
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

    class var FLock: TCriticalSection;
    class var FLive: TDictionary<Integer, TObject>;
    class var FLastId: Integer;
    class var FWellKnownKeys: array[TJSWellKnownSymbol] of TJSPropertyKey;

    class constructor Create;
    class destructor Destroy;

  public
    class function WellKnownKey(const Which: TJSWellKnownSymbol): TJSPropertyKey; static; inline;
    class function WellKnownDescription(const Which: TJSWellKnownSymbol): string; static;
    class function NextId: Integer; static;
    class procedure Add(const Id: Integer; const Symbol: TObject); static;
    class procedure Remove(const Id: Integer); static;
    class function Find(const Id: Integer): TObject; static;
  end;

implementation

const
  WELL_KNOWN_DESCRIPTIONS: array[TJSWellKnownSymbol] of string = (
    'Symbol.asyncIterator',
    'Symbol.hasInstance',
    'Symbol.isConcatSpreadable',
    'Symbol.iterator',
    'Symbol.match',
    'Symbol.matchAll',
    'Symbol.replace',
    'Symbol.search',
    'Symbol.species',
    'Symbol.split',
    'Symbol.toPrimitive',
    'Symbol.toStringTag',
    'Symbol.unscopables'
  );

class constructor TJSSymbolRegistry.Create;
begin
  FLock := TCriticalSection.Create;
  FLive := TDictionary<Integer, TObject>.Create;
  FLastId := FIRST_DYNAMIC_ID;

  for var Which := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    FWellKnownKeys[Which] := TJSPropertyKey.ForSymbol(Ord(Which) + 1);
  end;
end;

class destructor TJSSymbolRegistry.Destroy;
begin
  FLive.Free;
  FLock.Free;
end;

class function TJSSymbolRegistry.WellKnownKey(const Which: TJSWellKnownSymbol): TJSPropertyKey;
begin
  Result := FWellKnownKeys[Which];
end;

class function TJSSymbolRegistry.WellKnownDescription(const Which: TJSWellKnownSymbol): string;
begin
  Result := WELL_KNOWN_DESCRIPTIONS[Which];
end;

class function TJSSymbolRegistry.NextId: Integer;
begin
  Result := TInterlocked.Increment(FLastId);
end;

class procedure TJSSymbolRegistry.Add(const Id: Integer; const Symbol: TObject);
begin
  FLock.Enter;
  try
    FLive.AddOrSetValue(Id, Symbol);
  finally
    FLock.Leave;
  end;
end;

class procedure TJSSymbolRegistry.Remove(const Id: Integer);
begin
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
