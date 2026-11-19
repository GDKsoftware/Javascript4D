unit JS4D.Symbols;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.SymbolObject,
  JS4D.SymbolRegistry;

type
  TJSWellKnownSymbols = class
  private
    class var FSymbols: array[TJSWellKnownSymbol] of IJSSymbol;

    class constructor Create;

  public
    class function SymbolOf(const Kind: TJSWellKnownSymbol): IJSSymbol; static;
    class function ValueOf(const Kind: TJSWellKnownSymbol): TJSValue; static;
  end;

implementation

class constructor TJSWellKnownSymbols.Create;
begin
  for var Kind := Low(TJSWellKnownSymbol) to High(TJSWellKnownSymbol) do
  begin
    FSymbols[Kind] := TJSSymbolImpl.CreateWellKnown(Kind);
  end;
end;

class function TJSWellKnownSymbols.SymbolOf(const Kind: TJSWellKnownSymbol): IJSSymbol;
begin
  Result := FSymbols[Kind];
end;

class function TJSWellKnownSymbols.ValueOf(const Kind: TJSWellKnownSymbol): TJSValue;
begin
  Result := TJSValue.CreateSymbol(FSymbols[Kind]);
end;

end.
