unit JS4D.StrictThis;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  // Carries a this value that is not an object (a primitive or null) to a function that must see it unboxed:
  // a strict function, or a native function that asks for the raw this value.
  TJSStrictThis = class(TJSObjectImpl)
  private
    FValue: TJSValue;

  public
    class function ValueOf(const ThisObj: IJSObject): TJSValue; static;
    class function IsNonObject(const ThisObj: IJSObject): Boolean; static;

    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

implementation

{ TJSStrictThis }

class function TJSStrictThis.ValueOf(const ThisObj: IJSObject): TJSValue;
begin
  if not Assigned(ThisObj) then
    Exit(TJSValue.CreateUndefined);

  var Holder: TJSStrictThis := nil;
  if ThisObj is TJSStrictThis then
    Holder := ThisObj as TJSStrictThis;

  if Assigned(Holder) then
    Exit(Holder.Value);

  Result := TJSValue.CreateObject(ThisObj);
end;

class function TJSStrictThis.IsNonObject(const ThisObj: IJSObject): Boolean;
begin
  Result := (not Assigned(ThisObj)) or (ThisObj is TJSStrictThis);
end;

constructor TJSStrictThis.Create(const Value: TJSValue);
begin
  inherited Create;
  FValue := Value;
end;

end.
