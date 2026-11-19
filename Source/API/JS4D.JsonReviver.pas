unit JS4D.JsonReviver;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSJsonReviver = class
  private
    FReviver: IJSFunction;
    FLimits: TJSLimits;

    function Walk(const Holder: IJSObject; const Name: string; const Depth: Integer): TJSValue;
    procedure WalkArrayMembers(const Container: IJSObject; const Depth: Integer);
    procedure WalkObjectMembers(const Container: IJSObject; const Depth: Integer);
    procedure WalkMember(const Container: IJSObject; const Name: string; const Depth: Integer);

  public
    class function Revive(const Parsed: TJSValue; const Reviver: IJSFunction; const ObjectPrototype: IJSObject;
                          const Limits: TJSLimits): TJSValue; static;

    constructor Create(const Reviver: IJSFunction; const Limits: TJSLimits);
  end;

implementation

uses
  JS4D.JsonRoot,
  JS4D.ArrayLike,
  JS4D.ObjectKeys,
  JS4D.ObjectOperations;

class function TJSJsonReviver.Revive(const Parsed: TJSValue; const Reviver: IJSFunction;
                                     const ObjectPrototype: IJSObject; const Limits: TJSLimits): TJSValue;
begin
  const Root = TJSJsonRoot.CreateHolder(ObjectPrototype, Parsed);

  const Walker = TJSJsonReviver.Create(Reviver, Limits);
  try
    Result := Walker.Walk(Root, TJSJsonRoot.KEY, 0);
  finally
    Walker.Free;
  end;
end;

constructor TJSJsonReviver.Create(const Reviver: IJSFunction; const Limits: TJSLimits);
begin
  inherited Create;

  FReviver := Reviver;
  FLimits := Limits;
end;

function TJSJsonReviver.Walk(const Holder: IJSObject; const Name: string; const Depth: Integer): TJSValue;
begin
  FLimits.EnsureNestingDepth(Depth + 1);

  const Value = Holder.GetProperty(Name);
  if Value.IsObject then
  begin
    const Container = Value.ToObject;
    const IsArrayValue = TJSObjectOperations.IsArray(Value);

    if IsArrayValue then
      WalkArrayMembers(Container, Depth)
    else
      WalkObjectMembers(Container, Depth);
  end;

  const NameValue = TJSValue.CreateString(Name);
  Result := FReviver.Call(Holder, [NameValue, Value]);
end;

procedure TJSJsonReviver.WalkArrayMembers(const Container: IJSObject; const Depth: Integer);
begin
  const Count = TJSArrayLike.ToLength(Container);
  FLimits.EnsureArrayLength(Count);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    const IndexName = TJSArrayLike.IndexName(Index);
    WalkMember(Container, IndexName, Depth);
  end;
end;

procedure TJSJsonReviver.WalkObjectMembers(const Container: IJSObject; const Depth: Integer);
begin
  for var Name in TJSObjectKeys.Enumerable(Container) do
  begin
    WalkMember(Container, Name, Depth);
  end;
end;

procedure TJSJsonReviver.WalkMember(const Container: IJSObject; const Name: string; const Depth: Integer);
begin
  const Revived = Walk(Container, Name, Depth + 1);
  if Revived.IsUndefined then
  begin
    if Container.IsPropertyConfigurable(Name) then
      Container.DeleteProperty(Name);

    Exit;
  end;

  TJSObjectOperations.CreateDataProperty(Container, Name, Revived);
end;

end.
