unit JS4D.ControlFlow;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.AST;

type
  EJSControlFlowSignal = class(EAbort);

  TJSJumpSignal = class(EJSControlFlowSignal)
  private
    FTargetLabel: string;

  public
    constructor Create(const TargetLabel: string);

    function IsLabelled: Boolean;
    function AppliesTo(const OwnLabels: TArray<string>): Boolean;

    property TargetLabel: string read FTargetLabel;
  end;

  TJSBreakSignal = class(TJSJumpSignal);
  TJSContinueSignal = class(TJSJumpSignal);

  TJSReturnSignal = class(EJSControlFlowSignal)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

  TJSYieldSignal = class(EJSControlFlowSignal)
  private
    FNode: TJSASTNode;
    FValue: TJSValue;
    FIsResult: Boolean;

  public
    constructor Create(const Node: TJSASTNode; const Value: TJSValue; const IsResult: Boolean);

    property Node: TJSASTNode read FNode;
    property Value: TJSValue read FValue;
    property IsResult: Boolean read FIsResult;
  end;

  TJSBodyOutcome = (Yielded, Delegated, Finished);

  TJSBodyResult = record
    Outcome: TJSBodyOutcome;
    Value: TJSValue;
  end;

  TJSIterationResult = record
    Value: TJSValue;
    KeepLooping: Boolean;
  end;

  TJSLoopJump = (Propagate, Stop, Proceed);

  TJSThrowSignal = class(Exception)
  private
    FValue: TJSValue;

  public
    constructor Create(const Value: TJSValue);

    property Value: TJSValue read FValue;
  end;

implementation

uses
  System.StrUtils;

{ TJSJumpSignal }

constructor TJSJumpSignal.Create(const TargetLabel: string);
begin
  inherited Create('');
  FTargetLabel := TargetLabel;
end;

function TJSJumpSignal.IsLabelled: Boolean;
begin
  Result := not FTargetLabel.IsEmpty;
end;

function TJSJumpSignal.AppliesTo(const OwnLabels: TArray<string>): Boolean;
begin
  Result := (not IsLabelled) or MatchStr(FTargetLabel, OwnLabels);
end;

{ TJSReturnSignal }

constructor TJSReturnSignal.Create(const Value: TJSValue);
begin
  inherited Create('');
  FValue := Value;
end;

{ TJSThrowSignal }

constructor TJSThrowSignal.Create(const Value: TJSValue);
begin
  var Msg := Value.ToString;

  if Value.IsObject then
  begin
    var Error: IJSError;

    if Supports(Value.AsObject, IJSError, Error) then
      Msg := Error.Message;
  end;

  inherited Create(Msg);
  FValue := Value;
end;

{ TJSYieldSignal }

constructor TJSYieldSignal.Create(const Node: TJSASTNode; const Value: TJSValue; const IsResult: Boolean);
begin
  inherited Create('');
  FNode := Node;
  FValue := Value;
  FIsResult := IsResult;
end;

end.
