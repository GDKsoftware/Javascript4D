unit JS4D.PromiseJobQueue;

{$SCOPEDENUMS ON}

interface

uses
  System.Generics.Collections,
  JS4D.Types,
  JS4D.PromiseObjects;

type
  TJSPromiseJobKind = (Reaction, ResolveThenable);

  TJSPromiseJob = record
    Kind: TJSPromiseJobKind;
    Reaction: TJSPromiseReaction;
    Argument: TJSValue;
    IsRejection: Boolean;
    Promise: IJSPromise;
    Thenable: TJSValue;
    ThenFunction: TJSValue;

    procedure EnumerateValues(const MarkValue: TJSValueVisitor);
  end;

  TJSPromiseJobQueue = class
  private
    FJobs: TQueue<TJSPromiseJob>;

  public
    constructor Create;
    destructor Destroy; override;

    procedure EnqueueReaction(const Reaction: TJSPromiseReaction; const IsRejection: Boolean;
                              const Argument: TJSValue);
    procedure EnqueueThenable(const Promise: IJSPromise; const Thenable: TJSValue; const ThenFunction: TJSValue);
    function IsEmpty: Boolean;
    function Dequeue: TJSPromiseJob;
    procedure Clear;
    procedure EnumerateValues(const MarkValue: TJSValueVisitor);
  end;

implementation

{ TJSPromiseJob }

procedure TJSPromiseJob.EnumerateValues(const MarkValue: TJSValueVisitor);
begin
  Reaction.EnumerateValues(MarkValue);

  MarkValue(Argument);
  MarkValue(Thenable);
  MarkValue(ThenFunction);

  if Assigned(Promise) then
  begin
    const PromiseValue = TJSValue.CreateObject(Promise);
    MarkValue(PromiseValue);
  end;
end;

{ TJSPromiseJobQueue }

constructor TJSPromiseJobQueue.Create;
begin
  inherited Create;

  FJobs := TQueue<TJSPromiseJob>.Create;
end;

destructor TJSPromiseJobQueue.Destroy;
begin
  FJobs.Free;
  inherited;
end;

procedure TJSPromiseJobQueue.EnqueueReaction(const Reaction: TJSPromiseReaction; const IsRejection: Boolean;
                                             const Argument: TJSValue);
begin
  var Job := Default(TJSPromiseJob);
  Job.Kind := TJSPromiseJobKind.Reaction;
  Job.Reaction := Reaction;
  Job.IsRejection := IsRejection;
  Job.Argument := Argument;

  FJobs.Enqueue(Job);
end;

procedure TJSPromiseJobQueue.EnqueueThenable(const Promise: IJSPromise; const Thenable: TJSValue;
                                             const ThenFunction: TJSValue);
begin
  var Job := Default(TJSPromiseJob);
  Job.Kind := TJSPromiseJobKind.ResolveThenable;
  Job.Promise := Promise;
  Job.Thenable := Thenable;
  Job.ThenFunction := ThenFunction;

  FJobs.Enqueue(Job);
end;

function TJSPromiseJobQueue.IsEmpty: Boolean;
begin
  Result := (FJobs.Count = 0);
end;

function TJSPromiseJobQueue.Dequeue: TJSPromiseJob;
begin
  Result := FJobs.Dequeue;
end;

procedure TJSPromiseJobQueue.Clear;
begin
  FJobs.Clear;
end;

procedure TJSPromiseJobQueue.EnumerateValues(const MarkValue: TJSValueVisitor);
begin
  for var Job in FJobs do
  begin
    Job.EnumerateValues(MarkValue);
  end;
end;

end.
