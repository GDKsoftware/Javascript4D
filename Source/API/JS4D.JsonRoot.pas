unit JS4D.JsonRoot;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  TJSJsonRoot = class
  public
    const
      KEY = '';

    class function CreateHolder(const Prototype: IJSObject; const Value: TJSValue): IJSObject; static;
  end;

implementation

uses
  JS4D.PropertyKey,
  JS4D.ObjectOperations;

class function TJSJsonRoot.CreateHolder(const Prototype: IJSObject; const Value: TJSValue): IJSObject;
begin
  const Holder: IJSObject = TJSObject.Create;
  Holder.Prototype := Prototype;
  TJSObjectOperations.CreateDataProperty(Holder, KEY, Value);

  Result := Holder;
end;

end.
