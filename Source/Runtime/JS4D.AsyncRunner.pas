unit JS4D.AsyncRunner;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.GeneratorObjects,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations;

type
  TJSAsyncRunner = class(TJSAsyncHost)
  private
    FInterpreter: TJSInterpreter;
    FOperations: TJSPromiseOperations;

    function TryAwaitedPromise(const Operand: TJSValue; out Awaited: IJSPromise; out Reason: TJSValue): Boolean;

  public
    constructor Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations);

    function CreateResult: IJSObject; override;
    procedure Start(const Result: IJSObject; const Body: IJSGenerator); override;
    procedure Reject(const Result: IJSObject; const Reason: TJSValue); override;

    procedure Step(const Result: IJSPromise; const Body: IJSGenerator; const Mode: TJSResumeMode;
                   const Value: TJSValue);
  end;

implementation

uses
  JS4D.Errors;

type
  TJSAwaitContinuation = class(TInterfacedObject, IJSPromiseContinuation)
  private
    FRunner: TJSAsyncRunner;
    FResult: IJSPromise;
    FBody: IJSGenerator;

  public
    constructor Create(const Runner: TJSAsyncRunner; const Result: IJSPromise; const Body: IJSGenerator);

    procedure Resume(const IsRejection: Boolean; const Value: TJSValue);
    procedure EnumerateReferences(const Callback: TJSValueVisitor);
  end;

{ TJSAwaitContinuation }

constructor TJSAwaitContinuation.Create(const Runner: TJSAsyncRunner; const Result: IJSPromise;
                                        const Body: IJSGenerator);
begin
  inherited Create;

  FRunner := Runner;
  FResult := Result;
  FBody := Body;
end;

procedure TJSAwaitContinuation.Resume(const IsRejection: Boolean; const Value: TJSValue);
begin
  var Mode := TJSResumeMode.Next;
  if IsRejection then
    Mode := TJSResumeMode.Throw;

  FRunner.Step(FResult, FBody, Mode, Value);
end;

procedure TJSAwaitContinuation.EnumerateReferences(const Callback: TJSValueVisitor);
begin
  Callback(TJSValue.CreateObject(FBody));
  Callback(TJSValue.CreateObject(FResult));
end;

{ TJSAsyncRunner }

constructor TJSAsyncRunner.Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FOperations := Operations;
end;

function TJSAsyncRunner.CreateResult: IJSObject;
begin
  Result := FOperations.CreatePromise(FOperations.Prototype);
end;

procedure TJSAsyncRunner.Start(const Result: IJSObject; const Body: IJSGenerator);
begin
  const ResultPromise = Result as IJSPromise;
  Step(ResultPromise, Body, TJSResumeMode.Next, TJSValue.CreateUndefined);
end;

procedure TJSAsyncRunner.Reject(const Result: IJSObject; const Reason: TJSValue);
begin
  const ResultPromise = Result as IJSPromise;
  FOperations.RejectPromise(ResultPromise, Reason);
end;

procedure TJSAsyncRunner.Step(const Result: IJSPromise; const Body: IJSGenerator; const Mode: TJSResumeMode;
                              const Value: TJSValue);
begin
  var NextMode := Mode;
  var NextValue := Value;

  while True do
  begin
    var Advanced: TJSBodyResult;
    try
      Advanced := FInterpreter.AdvanceBody(Body, NextMode, NextValue);
    except
      on EJSExecutionInterrupted do
        raise;
      on Error: Exception do
      begin
        const Reason = FInterpreter.ExceptionToValue(Error);
        FOperations.RejectPromise(Result, Reason);
        Exit;
      end;
    end;

    const IsFinished = (Advanced.Outcome = TJSBodyOutcome.Finished);
    if IsFinished then
    begin
      FOperations.ResolvePromise(Result, Advanced.Value);
      Exit;
    end;

    var Awaited: IJSPromise;
    var Reason: TJSValue;
    if TryAwaitedPromise(Advanced.Value, Awaited, Reason) then
    begin
      const Continuation: IJSPromiseContinuation = TJSAwaitContinuation.Create(Self, Result, Body);
      FOperations.PerformAwait(Awaited, Continuation);
      Exit;
    end;

    NextMode := TJSResumeMode.Throw;
    NextValue := Reason;
  end;
end;

function TJSAsyncRunner.TryAwaitedPromise(const Operand: TJSValue; out Awaited: IJSPromise;
                                          out Reason: TJSValue): Boolean;
begin
  Awaited := nil;
  Reason := TJSValue.CreateUndefined;

  try
    const PromiseConstructor = TJSValue.CreateObject(FOperations.Constructor_);
    const Resolved = FOperations.PromiseResolve(PromiseConstructor, Operand);
    Result := Supports(Resolved.ToObject, IJSPromise, Awaited);
  except
    on EJSExecutionInterrupted do
      raise;
    on Error: Exception do
    begin
      Reason := FInterpreter.ExceptionToValue(Error);
      Result := False;
    end;
  end;
end;

end.
