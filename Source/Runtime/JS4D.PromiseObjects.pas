unit JS4D.PromiseObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.ObjectRegistry;

type
  TJSPromiseState = (Pending, Fulfilled, Rejected);

  TJSPromiseCapability = record
    Promise: TJSValue;
    Resolve: TJSValue;
    Reject: TJSValue;
    IsInternal: Boolean;
  end;

  IJSPromiseContinuation = interface
    ['{B3D07E52-61A4-4C89-8F1D-5E2A9C74B016}']
    procedure Resume(const IsRejection: Boolean; const Value: TJSValue);
    procedure EnumerateReferences(const Callback: TJSValueVisitor);
  end;

  TJSPromiseReaction = record
    Capability: TJSPromiseCapability;
    HasCapability: Boolean;
    OnFulfilled: TJSValue;
    OnRejected: TJSValue;
    Continuation: IJSPromiseContinuation;

    procedure EnumerateValues(const Callback: TJSValueVisitor);
  end;

  IJSPromise = interface(IJSObject)
    ['{6B1E4C97-3A52-4D08-9F7B-C2E85A0D1B36}']
    function GetState: TJSPromiseState;
    function GetResult: TJSValue;
    procedure AddReaction(const Reaction: TJSPromiseReaction);
    function SettleAndTakeReactions(const State: TJSPromiseState; const Value: TJSValue): TArray<TJSPromiseReaction>;
    property State: TJSPromiseState read GetState;
    property Result: TJSValue read GetResult;
  end;

  TJSPromiseObject = class(TJSRegisteredObject, IJSPromise)
  private
    FState: TJSPromiseState;
    FResult: TJSValue;
    FReactions: TList<TJSPromiseReaction>;

    function GetState: TJSPromiseState;
    function GetResult: TJSValue;
    procedure AddReaction(const Reaction: TJSPromiseReaction);
    function SettleAndTakeReactions(const State: TJSPromiseState; const Value: TJSValue): TArray<TJSPromiseReaction>;
    procedure Reset;
    class procedure CollectNested(const Value: TJSValue; const Pending: TList<IJSObject>); static;

  protected
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;
    procedure ReleaseReferences; override;

  public
    constructor Create(const Registry: TJSObjectRegistry);
    destructor Destroy; override;

    procedure ReleaseHeldValues; override;
    procedure EnumerateValues(const Callback: TJSValueVisitor);
  end;

implementation

{ TJSPromiseReaction }

procedure TJSPromiseReaction.EnumerateValues(const Callback: TJSValueVisitor);
begin
  Callback(Capability.Promise);
  Callback(Capability.Resolve);
  Callback(Capability.Reject);
  Callback(OnFulfilled);
  Callback(OnRejected);

  if Assigned(Continuation) then
    Continuation.EnumerateReferences(Callback);
end;

{ TJSPromiseObject }

constructor TJSPromiseObject.Create(const Registry: TJSObjectRegistry);
begin
  inherited Create(Registry);

  FState := TJSPromiseState.Pending;
  FResult := TJSValue.CreateUndefined;
  FReactions := TList<TJSPromiseReaction>.Create;
end;

destructor TJSPromiseObject.Destroy;
begin
  inherited;
  FReactions.Free;
end;

function TJSPromiseObject.GetState: TJSPromiseState;
begin
  Result := FState;
end;

function TJSPromiseObject.GetResult: TJSValue;
begin
  Result := FResult;
end;

procedure TJSPromiseObject.AddReaction(const Reaction: TJSPromiseReaction);
begin
  FReactions.Add(Reaction);
end;

function TJSPromiseObject.SettleAndTakeReactions(const State: TJSPromiseState;
                                                 const Value: TJSValue): TArray<TJSPromiseReaction>;
begin
  Result := FReactions.ToArray;
  FReactions.Clear;

  FState := State;
  FResult := Value;
end;

procedure TJSPromiseObject.ReleaseHeldValues;
begin
  ReleaseNested;
  Reset;
end;

procedure TJSPromiseObject.ReleaseReferences;
begin
  ReleaseHeldValues;
  inherited;
end;

procedure TJSPromiseObject.Reset;
begin
  FReactions.Clear;
  FResult := TJSValue.CreateUndefined;
end;

procedure TJSPromiseObject.EnumerateValues(const Callback: TJSValueVisitor);
begin
  const SelfValue = TJSValue.CreateObject(Self);
  Callback(SelfValue);
  Callback(FResult);

  for var Reaction in FReactions do
  begin
    Reaction.EnumerateValues(Callback);
  end;
end;

class procedure TJSPromiseObject.CollectNested(const Value: TJSValue; const Pending: TList<IJSObject>);
begin
  const IsNestedObject = (Value.IsObject and (not Value.IsFunction));
  if IsNestedObject then
    Pending.Add(Value.ToObject);
end;

function TJSPromiseObject.HoldsNested: Boolean;
begin
  Result := ((FReactions.Count > 0) or FResult.IsObject or inherited HoldsNested);
end;

procedure TJSPromiseObject.DetachNested(const Pending: TList<IJSObject>);
begin
  CollectNested(FResult, Pending);

  for var Reaction in FReactions do
  begin
    CollectNested(Reaction.Capability.Promise, Pending);
  end;

  Reset;
  inherited DetachNested(Pending);
end;

end.
