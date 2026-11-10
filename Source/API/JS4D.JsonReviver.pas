unit JS4D.JsonReviver;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types;

type
  TJSJsonReviver = class
  private
    class function Walk(const Holder: IJSObject; const Name: string; const Reviver: IJSFunction): TJSValue; static;
    class procedure WalkMembers(const Container: IJSObject; const Reviver: IJSFunction); static;
    class procedure WalkMember(const Container: IJSObject; const Name: string; const Reviver: IJSFunction); static;

  public
    class function Revive(const Parsed: TJSValue; const Reviver: IJSFunction;
                          const ObjectPrototype: IJSObject): TJSValue; static;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.ObjectKeys;

class function TJSJsonReviver.Revive(const Parsed: TJSValue; const Reviver: IJSFunction;
                                     const ObjectPrototype: IJSObject): TJSValue;
begin
  const Root: IJSObject = TJSObject.Create;
  Root.Prototype := ObjectPrototype;
  Root.SetProperty('', Parsed);

  Result := Walk(Root, '', Reviver);
end;

class function TJSJsonReviver.Walk(const Holder: IJSObject; const Name: string;
                                   const Reviver: IJSFunction): TJSValue;
begin
  const Value = Holder.GetProperty(Name);
  if Value.IsObject then
    WalkMembers(Value.ToObject, Reviver);

  Result := Reviver.Call(Holder, [TJSValue.CreateString(Name), Value]);
end;

class procedure TJSJsonReviver.WalkMembers(const Container: IJSObject; const Reviver: IJSFunction);
begin
  var ContainerArray: IJSArray;
  if Supports(Container, IJSArray, ContainerArray) then
  begin
    const Count = TJSArrayLike.ToLength(Container);
    for var Index: Int64 := 0 to Count - 1 do
    begin
      WalkMember(Container, TJSArrayLike.IndexName(Index), Reviver);
    end;

    Exit;
  end;

  for var Name in TJSObjectKeys.Enumerable(Container) do
  begin
    WalkMember(Container, Name, Reviver);
  end;
end;

class procedure TJSJsonReviver.WalkMember(const Container: IJSObject; const Name: string;
                                          const Reviver: IJSFunction);
begin
  const Revived = Walk(Container, Name, Reviver);
  if Revived.IsUndefined then
  begin
    if Container.IsPropertyConfigurable(Name) then
      Container.DeleteProperty(Name);

    Exit;
  end;

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Revived;
  Definition.HasWritable := True;
  Definition.Writable := True;
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  Container.DefineOwnProperty(Name, Definition);
end;

end.
