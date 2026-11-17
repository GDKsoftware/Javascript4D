unit JS4D.SymbolObject;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.PropertyKey,
  JS4D.SymbolRegistry,
  JS4D.Types;

type
  TJSSymbolImpl = class(TJSObjectImpl, IJSSymbol)
  private
    FId: Integer;
    FKey: TJSPropertyKey;
    FDescription: string;
    FHasDescription: Boolean;

  protected
    function GetKey: TJSPropertyKey;
    function GetDescription: string;
    function GetHasDescription: Boolean;

  public
    constructor Create(const Description: string; const HasDescription: Boolean);
    constructor CreateWellKnown(const Which: TJSWellKnownSymbol);
    destructor Destroy; override;

    property Key: TJSPropertyKey read GetKey;
    property Description: string read GetDescription;
    property HasDescription: Boolean read GetHasDescription;
  end;

implementation

{ TJSSymbolImpl }

constructor TJSSymbolImpl.Create(const Description: string; const HasDescription: Boolean);
begin
  inherited Create;
  FId := TJSSymbolRegistry.NextId;
  FKey := TJSPropertyKey.ForSymbol(FId);
  FHasDescription := HasDescription;
  if HasDescription then
    FDescription := Description;

  TJSSymbolRegistry.RegisterSymbol(FId, Self);
end;

constructor TJSSymbolImpl.CreateWellKnown(const Which: TJSWellKnownSymbol);
begin
  inherited Create;
  FId := TJSSymbolRegistry.WellKnownId(Which);
  FKey := TJSSymbolRegistry.WellKnownKey(Which);
  FDescription := TJSSymbolRegistry.WellKnownDescription(Which);
  FHasDescription := True;
  TJSSymbolRegistry.RegisterSymbol(FId, Self);
end;

destructor TJSSymbolImpl.Destroy;
begin
  TJSSymbolRegistry.UnregisterSymbol(FId);

  inherited Destroy;
end;

function TJSSymbolImpl.GetKey: TJSPropertyKey;
begin
  Result := FKey;
end;

function TJSSymbolImpl.GetDescription: string;
begin
  Result := FDescription;
end;

function TJSSymbolImpl.GetHasDescription: Boolean;
begin
  Result := FHasDescription;
end;

end.
