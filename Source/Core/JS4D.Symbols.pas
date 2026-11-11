unit JS4D.Symbols;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.SymbolRegistry;

type
  // The well-known symbols are shared by every engine, like the key strings that name them.
  TJSWellKnownSymbols = class
  private
    class var FSymbols: array[TJSWellKnownSymbol] of IJSSymbol;

    class constructor Create;
    class destructor Destroy;

  public
    class function Get(const Which: TJSWellKnownSymbol): IJSSymbol; static;
    class function Value(const Which: TJSWellKnownSymbol): TJSValue; static;
  end;

implementation

class constructor TJSWellKnownSymbols.Create;
begin
  for var Which := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    FSymbols[Which] := TJSSymbolImpl.CreateWellKnown(Which);
  end;
end;

class destructor TJSWellKnownSymbols.Destroy;
begin
  for var Which := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    FSymbols[Which] := nil;
  end;
end;

class function TJSWellKnownSymbols.Get(const Which: TJSWellKnownSymbol): IJSSymbol;
begin
  Result := FSymbols[Which];
end;

class function TJSWellKnownSymbols.Value(const Which: TJSWellKnownSymbol): TJSValue;
begin
  Result := TJSValue.CreateSymbol(FSymbols[Which]);
end;

end.
