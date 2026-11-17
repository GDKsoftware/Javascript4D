unit JS4D.CallFrames;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  TJSThisBinding = class(TInterfacedObject, IJSThisBinding)
  private
    FValue: IJSObject;

    function GetValue: IJSObject;
    procedure SetValue(const Value: IJSObject);
  end;

  TJSFrame = class(TInterfacedObject, IJSFrame)
  private
    FCallee: IJSFunction;
    FNewTarget: IJSFunction;
    FThisBinding: IJSThisBinding;

    function GetCallee: IJSFunction;
    function GetNewTarget: IJSFunction;
    function GetThisBinding: IJSThisBinding;

  public
    constructor Create(const Callee: IJSFunction; const NewTarget: IJSFunction; const ThisBinding: IJSThisBinding);
  end;

implementation

{ TJSThisBinding }

function TJSThisBinding.GetValue: IJSObject;
begin
  Result := FValue;
end;

procedure TJSThisBinding.SetValue(const Value: IJSObject);
begin
  FValue := Value;
end;

{ TJSFrame }

constructor TJSFrame.Create(const Callee: IJSFunction; const NewTarget: IJSFunction;
                            const ThisBinding: IJSThisBinding);
begin
  inherited Create;
  FCallee := Callee;
  FNewTarget := NewTarget;
  FThisBinding := ThisBinding;
end;

function TJSFrame.GetCallee: IJSFunction;
begin
  Result := FCallee;
end;

function TJSFrame.GetNewTarget: IJSFunction;
begin
  Result := FNewTarget;
end;

function TJSFrame.GetThisBinding: IJSThisBinding;
begin
  Result := FThisBinding;
end;

end.
