unit JS4D.AsyncRunner;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.ControlFlow,
  JS4D.Interpreter,
  JS4D.BinarySupport,
  JS4D.GeneratorObjects,
  JS4D.AsyncHost,
  JS4D.PromiseObjects,
  JS4D.PromiseOperations;

type
  TJSAwaitedPromise = record
    Promise: IJSPromise;
    Reason: TJSValue;
    IsAwaitable: Boolean;
  end;

  TJSBodyAdvance = record
    IsDone: Boolean;
    Resumption: TJSResumption;
  end;

  TJSAsyncRunner = class(TJSAsyncHost)
  private
    FInterpreter: TJSInterpreter;
    FSupport: TJSBinarySupport;
    FOperations: TJSPromiseOperations;

    function AwaitedPromiseOf(const Operand: TJSValue): TJSAwaitedPromise;
    function AdvanceOnce(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                         const Resumption: TJSResumption): TJSBodyAdvance;
    procedure SubscribeAwait(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                             const Awaited: IJSPromise);
    procedure Step(const ResultPromise: IJSPromise; const Body: IJSGenerator; const Mode: TJSResumeMode;
                   const Value: TJSValue);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport;
                       const Operations: TJSPromiseOperations);

    function CreateResult: IJSObject; override;
    procedure Start(const ResultPromise: IJSObject; const Body: IJSGenerator); override;
    procedure Reject(const ResultPromise: IJSObject; const Reason: TJSValue); override;
  end;

implementation

uses
  JS4D.AwaitContinuation;

constructor TJSAsyncRunner.Create(const Interpreter: TJSInterpreter; const Support: TJSBinarySupport;
                                  const Operations: TJSPromiseOperations);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := Support;
  FOperations := Operations;
end;

function TJSAsyncRunner.CreateResult: IJSObject;
begin
  Result := FOperations.CreatePromise(FOperations.Prototype);
end;

procedure TJSAsyncRunner.Start(const ResultPromise: IJSObject; const Body: IJSGenerator);
begin
  const Promise = (ResultPromise as IJSPromise);
  const Undefined = TJSValue.CreateUndefined;

  Step(Promise, Body, TJSResumeMode.Next, Undefined);
end;

procedure TJSAsyncRunner.Reject(const ResultPromise: IJSObject; const Reason: TJSValue);
begin
  const Promise = (ResultPromise as IJSPromise);

  FOperations.RejectPromise(Promise, Reason);
end;

procedure TJSAsyncRunner.Step(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                              const Mode: TJSResumeMode; const Value: TJSValue);
begin
  var Resumption := Default(TJSResumption);
  Resumption.Mode := Mode;
  Resumption.Value := Value;

  var Advance: TJSBodyAdvance;
  repeat
    Advance := AdvanceOnce(ResultPromise, Body, Resumption);
    Resumption := Advance.Resumption;
  until Advance.IsDone;
end;

function TJSAsyncRunner.AdvanceOnce(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                                    const Resumption: TJSResumption): TJSBodyAdvance;
begin
  Result := Default(TJSBodyAdvance);
  Result.IsDone := True;

  var Advanced: TJSBodyResult;
  const Outcome = FSupport.Capture(
    function: TJSValue
    begin
      Advanced := FInterpreter.GeneratorEngine.AdvanceBody(Body, Resumption.Mode, Resumption.Value);
      Result := TJSValue.CreateUndefined;
    end);

  if not Outcome.IsNormal then
  begin
    FOperations.RejectPromise(ResultPromise, Outcome.Value);
    Exit;
  end;

  const IsFinished = (Advanced.Outcome = TJSBodyOutcome.Finished);
  if IsFinished then
  begin
    FOperations.ResolvePromise(ResultPromise, Advanced.Value);
    Exit;
  end;

  const Awaited = AwaitedPromiseOf(Advanced.Value);
  if Awaited.IsAwaitable then
  begin
    SubscribeAwait(ResultPromise, Body, Awaited.Promise);
    Exit;
  end;

  Result.IsDone := False;
  Result.Resumption.Mode := TJSResumeMode.Throw;
  Result.Resumption.Value := Awaited.Reason;
end;

procedure TJSAsyncRunner.SubscribeAwait(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                                        const Awaited: IJSPromise);
begin
  const Continuation: IJSPromiseContinuation = TJSAwaitContinuation.Create(Step, ResultPromise, Body);

  FOperations.PerformAwait(Awaited, Continuation);
end;

function TJSAsyncRunner.AwaitedPromiseOf(const Operand: TJSValue): TJSAwaitedPromise;
begin
  Result := Default(TJSAwaitedPromise);
  Result.Reason := TJSValue.CreateUndefined;

  var Awaited: IJSPromise;
  var IsAwaitable := False;
  const Outcome = FSupport.Capture(
    function: TJSValue
    begin
      const PromiseConstructor = TJSValue.CreateObject(FOperations.PromiseConstructor);
      const Resolved = FOperations.PromiseResolve(PromiseConstructor, Operand);
      const ResolvedObject = Resolved.ToObject;
      IsAwaitable := Supports(ResolvedObject, IJSPromise, Awaited);
      Result := TJSValue.CreateUndefined;
    end);

  if Outcome.IsNormal then
  begin
    Result.Promise := Awaited;
    Result.IsAwaitable := IsAwaitable;
  end
  else
  begin
    Result.Reason := Outcome.Value;
  end;
end;

end.
