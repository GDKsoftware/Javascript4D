unit JS4D.Combination;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types;

type
  IJSCombination = interface
    ['{4D7A2E91-C5B8-4F30-A619-E03B8D5C7F24}']
    function GetIsComplete: Boolean;
    procedure AddSlot;
    function TryClaimSlot(const Index: Integer): Boolean;
    procedure FillSlot(const Index: Integer; const Value: TJSValue);
    function GetSlots: TArray<TJSValue>;
    procedure AddPending;
    procedure RemovePending;
    property IsComplete: Boolean read GetIsComplete;
  end;

  TJSCombination = class(TInterfacedObject, IJSCombination)
  private
    const
      COMPLETION_GUARD = 1;

    var
      FSlots: TList<TJSValue>;
      FClaimed: TList<Boolean>;
      FPending: Integer;

    function GetIsComplete: Boolean;

  public
    constructor Create;
    destructor Destroy; override;

    procedure AddSlot;
    function TryClaimSlot(const Index: Integer): Boolean;
    procedure FillSlot(const Index: Integer; const Value: TJSValue);
    function GetSlots: TArray<TJSValue>;
    procedure AddPending;
    procedure RemovePending;
  end;

implementation

constructor TJSCombination.Create;
begin
  inherited Create;

  FSlots := TList<TJSValue>.Create;
  FClaimed := TList<Boolean>.Create;
  FPending := COMPLETION_GUARD;
end;

destructor TJSCombination.Destroy;
begin
  FClaimed.Free;
  FSlots.Free;
  inherited;
end;

function TJSCombination.GetIsComplete: Boolean;
begin
  Result := (FPending = 0);
end;

procedure TJSCombination.AddSlot;
begin
  FSlots.Add(TJSValue.CreateUndefined);
  FClaimed.Add(False);
end;

function TJSCombination.TryClaimSlot(const Index: Integer): Boolean;
begin
  Result := (not FClaimed[Index]);
  FClaimed[Index] := True;
end;

procedure TJSCombination.FillSlot(const Index: Integer; const Value: TJSValue);
begin
  FSlots[Index] := Value;
end;

function TJSCombination.GetSlots: TArray<TJSValue>;
begin
  Result := FSlots.ToArray;
end;

procedure TJSCombination.AddPending;
begin
  Inc(FPending);
end;

procedure TJSCombination.RemovePending;
begin
  Dec(FPending);
end;

end.
