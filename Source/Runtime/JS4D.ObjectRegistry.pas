unit JS4D.ObjectRegistry;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.Types;

type
  TJSObjectRegistry = class;

  TJSRegisteredObject = class(TJSObjectImpl)
  private
    FRegistry: TJSObjectRegistry;
    FRegistryIndex: Integer;

  public
    constructor Create(const Registry: TJSObjectRegistry);
    destructor Destroy; override;

    procedure ReleaseHeldValues; virtual; abstract;
  end;

  TJSObjectRegistry = class
  private
    FEntries: TList<TJSRegisteredObject>;

    procedure Add(const Entry: TJSRegisteredObject);
    procedure Remove(const Entry: TJSRegisteredObject);

  public
    constructor Create;
    destructor Destroy; override;

    function GetEnumerator: TList<TJSRegisteredObject>.TEnumerator;
    procedure ReleaseAll;
  end;

implementation

{ TJSRegisteredObject }

constructor TJSRegisteredObject.Create(const Registry: TJSObjectRegistry);
begin
  inherited Create;

  FRegistry := Registry;
  FRegistry.Add(Self);
end;

destructor TJSRegisteredObject.Destroy;
begin
  if Assigned(FRegistry) then
    FRegistry.Remove(Self);

  inherited;
end;

{ TJSObjectRegistry }

constructor TJSObjectRegistry.Create;
begin
  inherited Create;

  FEntries := TList<TJSRegisteredObject>.Create;
end;

destructor TJSObjectRegistry.Destroy;
begin
  for var Entry in FEntries do
  begin
    Entry.FRegistry := nil;
  end;

  FEntries.Free;
  inherited;
end;

procedure TJSObjectRegistry.Add(const Entry: TJSRegisteredObject);
begin
  Entry.FRegistryIndex := FEntries.Count;
  FEntries.Add(Entry);
end;

procedure TJSObjectRegistry.Remove(const Entry: TJSRegisteredObject);
begin
  const LastIndex = FEntries.Count - 1;
  const Moved = FEntries[LastIndex];
  FEntries[Entry.FRegistryIndex] := Moved;
  Moved.FRegistryIndex := Entry.FRegistryIndex;
  FEntries.Delete(LastIndex);
end;

function TJSObjectRegistry.GetEnumerator: TList<TJSRegisteredObject>.TEnumerator;
begin
  Result := FEntries.GetEnumerator;
end;

procedure TJSObjectRegistry.ReleaseAll;
begin
  while FEntries.Count > 0 do
  begin
    const Entry = FEntries.Last;
    Entry.FRegistry := nil;
    FEntries.Delete(FEntries.Count - 1);

    const KeepAlive: IJSObject = Entry;
    Entry.ReleaseHeldValues;
  end;
end;

end.
