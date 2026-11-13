unit JS4D.AwaitContinuation;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.GeneratorObjects,
  JS4D.PromiseObjects;

type
  TJSResumeStep = reference to procedure(const ResultPromise: IJSPromise; const Body: IJSGenerator;
                                         const Mode: TJSResumeMode; const Value: TJSValue);

  TJSAwaitContinuation = class(TInterfacedObject, IJSPromiseContinuation)
  private
    FResumeStep: TJSResumeStep;
    FResultPromise: IJSPromise;
    FBody: IJSGenerator;

  public
    constructor Create(const ResumeStep: TJSResumeStep; const ResultPromise: IJSPromise;
                       const Body: IJSGenerator);

    procedure Resume(const IsRejection: Boolean; const Value: TJSValue);
    procedure EnumerateReferences(const Callback: TJSValueVisitor);
  end;

implementation

constructor TJSAwaitContinuation.Create(const ResumeStep: TJSResumeStep; const ResultPromise: IJSPromise;
                                        const Body: IJSGenerator);
begin
  inherited Create;

  FResumeStep := ResumeStep;
  FResultPromise := ResultPromise;
  FBody := Body;
end;

procedure TJSAwaitContinuation.Resume(const IsRejection: Boolean; const Value: TJSValue);
begin
  var Mode := TJSResumeMode.Next;
  if IsRejection then
    Mode := TJSResumeMode.Throw;

  FResumeStep(FResultPromise, FBody, Mode, Value);
end;

procedure TJSAwaitContinuation.EnumerateReferences(const Callback: TJSValueVisitor);
begin
  const BodyValue = TJSValue.CreateObject(FBody);
  const ResultValue = TJSValue.CreateObject(FResultPromise);

  Callback(BodyValue);
  Callback(ResultValue);
end;

end.
