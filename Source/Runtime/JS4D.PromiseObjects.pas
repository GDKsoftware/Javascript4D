unit JS4D.PromiseObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types;

type
  TJSPromiseState = (Pending, Fulfilled, Rejected);

  // The promise together with the functions that settle it. A capability that the engine creates itself for a
  // derived promise has no functions: its promise is settled directly, so that chaining makes no function objects.
  TJSPromiseCapability = record
    Promise: TJSValue;
    Resolve: TJSValue;
    Reject: TJSValue;
    IsInternal: Boolean;
  end;

  TJSPromiseReaction = record
    Capability: TJSPromiseCapability;
    HasCapability: Boolean;
    OnFulfilled: TJSValue;
    OnRejected: TJSValue;
  end;

  IJSPromise = interface(IJSObject)
    ['{6B1E4C97-3A52-4D08-9F7B-C2E85A0D1B36}']
    function GetState: TJSPromiseState;
    function GetResult: TJSValue;
    function GetIsHandled: Boolean;
    procedure SetIsHandled(const Value: Boolean);
    procedure AddReaction(const Reaction: TJSPromiseReaction);
    // Moves the promise out of the pending state and hands back the reactions that were waiting for that.
    function Settle(const State: TJSPromiseState; const Value: TJSValue): TArray<TJSPromiseReaction>;
    property State: TJSPromiseState read GetState;
    property Result: TJSValue read GetResult;
    property IsHandled: Boolean read GetIsHandled write SetIsHandled;
  end;

  TJSPromiseRegistry = class;

  TJSPromiseObject = class(TJSObjectImpl, IJSPromise)
  private
    FState: TJSPromiseState;
    FResult: TJSValue;
    FReactions: TList<TJSPromiseReaction>;
    FIsHandled: Boolean;
    FRegistry: TJSPromiseRegistry;
    FRegistryIndex: Integer;

    function GetState: TJSPromiseState;
    function GetResult: TJSValue;
    function GetIsHandled: Boolean;
    procedure SetIsHandled(const Value: Boolean);
    procedure AddReaction(const Reaction: TJSPromiseReaction);
    function Settle(const State: TJSPromiseState; const Value: TJSValue): TArray<TJSPromiseReaction>;
    procedure Reset;
    procedure EnumerateValues(const Callback: TProc<TJSValue>);
    class procedure CollectNested(const Value: TJSValue; const Pending: TList<IJSObject>); static;

  protected
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;

  public
    constructor Create(const Registry: TJSPromiseRegistry);
    procedure ReleaseHeldValues;
    destructor Destroy; override;
  end;

  // Remembers every live promise of one engine. The engine releases what they hold when it goes away, which breaks
  // the cycles that scripts make through promises, and the garbage collector finds the values they hold.
  TJSPromiseRegistry = class
  private
    FPromises: TList<TJSPromiseObject>;

    procedure Add(const Promise: TJSPromiseObject);
    procedure Remove(const Promise: TJSPromiseObject);

  public
    constructor Create;
    destructor Destroy; override;

    procedure ClearAll;
    procedure EnumerateValues(const Callback: TProc<TJSValue>);
  end;

implementation

{ TJSPromiseObject }

constructor TJSPromiseObject.Create(const Registry: TJSPromiseRegistry);
begin
  inherited Create;

  FState := TJSPromiseState.Pending;
  FResult := TJSValue.CreateUndefined;
  FReactions := TList<TJSPromiseReaction>.Create;
  FRegistry := Registry;
  FRegistry.Add(Self);
end;

destructor TJSPromiseObject.Destroy;
begin
  if Assigned(FRegistry) then
    FRegistry.Remove(Self);

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

function TJSPromiseObject.GetIsHandled: Boolean;
begin
  Result := FIsHandled;
end;

procedure TJSPromiseObject.SetIsHandled(const Value: Boolean);
begin
  FIsHandled := Value;
end;

procedure TJSPromiseObject.AddReaction(const Reaction: TJSPromiseReaction);
begin
  FReactions.Add(Reaction);
end;

function TJSPromiseObject.Settle(const State: TJSPromiseState;
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

procedure TJSPromiseObject.Reset;
begin
  FReactions.Clear;
  FResult := TJSValue.CreateUndefined;
end;

procedure TJSPromiseObject.EnumerateValues(const Callback: TProc<TJSValue>);
begin
  Callback(TJSValue.CreateObject(Self));
  Callback(FResult);

  for var Reaction in FReactions do
  begin
    Callback(Reaction.Capability.Promise);
    Callback(Reaction.Capability.Resolve);
    Callback(Reaction.Capability.Reject);
    Callback(Reaction.OnFulfilled);
    Callback(Reaction.OnRejected);
  end;
end;

class procedure TJSPromiseObject.CollectNested(const Value: TJSValue; const Pending: TList<IJSObject>);
begin
  const IsNestedObject = Value.IsObject and (not Value.IsFunction);
  if IsNestedObject then
    Pending.Add(Value.ToObject);
end;

function TJSPromiseObject.HoldsNested: Boolean;
begin
  Result := (FReactions.Count > 0) or FResult.IsObject or inherited HoldsNested;
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

{ TJSPromiseRegistry }

constructor TJSPromiseRegistry.Create;
begin
  inherited Create;

  FPromises := TList<TJSPromiseObject>.Create;
end;

destructor TJSPromiseRegistry.Destroy;
begin
  for var Promise in FPromises do
  begin
    Promise.FRegistry := nil;
  end;

  FPromises.Free;
  inherited;
end;

procedure TJSPromiseRegistry.Add(const Promise: TJSPromiseObject);
begin
  Promise.FRegistryIndex := FPromises.Count;
  FPromises.Add(Promise);
end;

procedure TJSPromiseRegistry.Remove(const Promise: TJSPromiseObject);
begin
  const LastIndex = FPromises.Count - 1;
  const Moved = FPromises[LastIndex];
  FPromises[Promise.FRegistryIndex] := Moved;
  Moved.FRegistryIndex := Promise.FRegistryIndex;
  FPromises.Delete(LastIndex);
end;

procedure TJSPromiseRegistry.ClearAll;
begin
  while FPromises.Count > 0 do
  begin
    const Promise = FPromises.Last;
    Promise.FRegistry := nil;
    FPromises.Delete(FPromises.Count - 1);

    const Held: IJSObject = Promise;
    Promise.ReleaseHeldValues;
  end;
end;

procedure TJSPromiseRegistry.EnumerateValues(const Callback: TProc<TJSValue>);
begin
  for var Promise in FPromises do
  begin
    Promise.EnumerateValues(Callback);
  end;
end;

end.
