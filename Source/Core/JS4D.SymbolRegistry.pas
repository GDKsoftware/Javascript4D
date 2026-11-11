unit JS4D.SymbolRegistry;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.SyncObjs,
  System.Generics.Collections;

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

  // A symbol used as a property key is stored under a text key made of a marker character and the symbol id.
  // The registry maps such a key back to the live symbol. It does not own the symbols: an object that stores
  // a symbol key keeps the symbol itself alive, so every key found on an object resolves to a live symbol.
  TJSSymbolRegistry = class
  private
    const
      KEY_MARKER = Char($FDD0);
      FIRST_DYNAMIC_ID = 100;

    class var FLock: TCriticalSection;
    class var FLive: TDictionary<Integer, TObject>;
    class var FLastId: Integer;
    class var FWellKnownKeys: array[TJSWellKnownSymbol] of string;

    class constructor Create;
    class destructor Destroy;

  public
    class function IsKey(const Name: string): Boolean; static; inline;
    class function KeyFor(const Id: Integer): string; static;
    class function WellKnownKey(const Which: TJSWellKnownSymbol): string; static; inline;
    class function WellKnownDescription(const Which: TJSWellKnownSymbol): string; static;
    class function NextId: Integer; static;
    class procedure Add(const Id: Integer; const Symbol: TObject); static;
    class procedure Remove(const Id: Integer); static;
    class function Find(const Key: string): TObject; static;
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
    FWellKnownKeys[Which] := KeyFor(Ord(Which) + 1);
  end;
end;

class destructor TJSSymbolRegistry.Destroy;
begin
  FLive.Free;
  FLock.Free;
end;

class function TJSSymbolRegistry.IsKey(const Name: string): Boolean;
begin
  Result := (Length(Name) > 0) and (Name[1] = KEY_MARKER);
end;

class function TJSSymbolRegistry.KeyFor(const Id: Integer): string;
begin
  Result := KEY_MARKER + IntToStr(Id);
end;

class function TJSSymbolRegistry.WellKnownKey(const Which: TJSWellKnownSymbol): string;
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

class function TJSSymbolRegistry.Find(const Key: string): TObject;
begin
  Result := nil;

  if not IsKey(Key) then
    Exit;

  var Id: Integer;
  const IsId = TryStrToInt(Copy(Key, 2, Length(Key) - 1), Id);
  if not IsId then
    Exit;

  FLock.Enter;
  try
    if not FLive.TryGetValue(Id, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

end.
