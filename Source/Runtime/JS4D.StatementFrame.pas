unit JS4D.StatementFrame;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.GeneratorObjects,
  JS4D.ControlFlow,
  JS4D.IterationSource;

type
  TJSFrameStage = (
    Fresh,
    BlockRunning,
    Delegating,
    IfConsequent,
    IfAlternate,
    WhileTesting,
    WhileBody,
    DoWhileBody,
    DoWhileTesting,
    ForHead,
    ForTesting,
    ForBody,
    ForCopyingScope,
    ForUpdating,
    ForInSubject,
    ForInKeys,
    ForInNextKey,
    ForInBody,
    ForOfSubject,
    ForOfOpening,
    ForOfNextValue,
    ForOfBinding,
    ForOfBody,
    SwitchSelecting,
    SwitchRunning,
    SwitchSkipped,
    LabeledEntered,
    WithEntered,
    TryBlock,
    TryCatch,
    TryFinally,
    PatternElement,
    PatternValueFetched
  );

  TJSStatementFrame = class(TJSGeneratorFrame)
  private
    class procedure VisitValue(const Value: TJSValue; const Visit: TJSReferenceVisitor); static;

  public
    Stage: TJSFrameStage;
    Index: Integer;
    ConsequentIndex: Integer;
    DefaultCaseIndex: Integer;
    IsCatchBound: Boolean;
    Scope: IJSScope;
    OuterScope: IJSScope;
    Labels: TArray<string>;
    Subject: TJSValue;
    Current: TJSValue;
    Thrown: TJSValue;
    Keys: TArray<string>;
    Source: IJSIterationSource;
    Pending: Exception;
    Iterator: IJSObject;
    NextMethod: TJSValue;
    Received: TJSResumption;

    destructor Destroy; override;

    function IsAt(const Expected: TJSFrameStage): Boolean; inline;
    procedure MoveTo(const Next: TJSFrameStage); inline;
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor); override;
  end;

implementation

{ TJSStatementFrame }

destructor TJSStatementFrame.Destroy;
begin
  Pending.Free;
  inherited;
end;

function TJSStatementFrame.IsAt(const Expected: TJSFrameStage): Boolean;
begin
  Result := (Stage = Expected);
end;

procedure TJSStatementFrame.MoveTo(const Next: TJSFrameStage);
begin
  Stage := Next;
end;

procedure TJSStatementFrame.EnumerateReferences(const Visit: TJSReferenceVisitor);
begin
  Visit(Scope);
  Visit(OuterScope);
  Visit(Iterator);
  VisitValue(Subject, Visit);
  VisitValue(Current, Visit);
  VisitValue(Thrown, Visit);
  VisitValue(NextMethod, Visit);
  VisitValue(Received.Value, Visit);

  if Assigned(Source) then
    Source.EnumerateReferences(Visit);

  if Pending is TJSThrowSignal then
    VisitValue(TJSThrowSignal(Pending).Value, Visit)
  else if Pending is TJSReturnSignal then
    VisitValue(TJSReturnSignal(Pending).Value, Visit);
end;

class procedure TJSStatementFrame.VisitValue(const Value: TJSValue; const Visit: TJSReferenceVisitor);
begin
  if Value.IsObject then
  begin
    const ValueObject = Value.ToObject;
    Visit(ValueObject);
  end;
end;

end.
