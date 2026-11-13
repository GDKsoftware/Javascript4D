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
  // Runs the body of an async function: it resumes the suspended body when the promise it awaits settles, and
  // settles the promise that the call returned when the body ends.
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

    // Runs the body until its next await or its end.
    procedure Step(const Result: IJSPromise; const Body: IJSGenerator; const Mode: TJSResumeMode;
                   const Value: TJSValue);
  end;

implementation

uses
  JS4D.Errors;

type
  // What an async function waits for at an await: the body to resume and the promise to settle at its end.
  TJSAwaitContinuation = class(TInterfacedObject, IJSPromiseContinuation)
  private
    FRunner: TJSAsyncRunner;
    FResult: IJSPromise;
    FBody: IJSGenerator;

  public
    constructor Create(const Runner: TJSAsyncRunner; const Result: IJSPromise; const Body: IJSGenerator);

    procedure Resume(const IsRejection: Boolean; const Value: TJSValue);
    procedure EnumerateReferences(const Callback: TProc<TJSValue>);
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

procedure TJSAwaitContinuation.EnumerateReferences(const Callback: TProc<TJSValue>);
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
    var Outcome: TJSBodyOutcome;
    var Produced: TJSValue;
    try
      Produced := FInterpreter.AdvanceBody(Body, NextMode, NextValue, Outcome);
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

    const IsFinished = (Outcome = TJSBodyOutcome.Finished);
    if IsFinished then
    begin
      FOperations.ResolvePromise(Result, Produced);
      Exit;
    end;

    var Awaited: IJSPromise;
    var Reason: TJSValue;
    if TryAwaitedPromise(Produced, Awaited, Reason) then
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
