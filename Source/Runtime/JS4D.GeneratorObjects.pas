unit JS4D.GeneratorObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.AST,
  JS4D.ObjectRegistry;

type
  TJSGeneratorState = (SuspendedStart, SuspendedYield, Executing, Completed);

  TJSResumeMode = (Next, Throw, Return);

  TJSResumption = record
    Mode: TJSResumeMode;
    Value: TJSValue;
  end;

  TJSGeneratorFrame = class abstract
  public
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor); virtual; abstract;
  end;

  IJSGenerator = interface(IJSObject)
    ['{3C7A91E4-5D28-4B6F-A0E3-8F14D2B7C569}']
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

  TJSGeneratorObject = class(TJSRegisteredObject, IJSGenerator)
  private
    FState: TJSGeneratorState;
    FFunctionObject: IJSFunction;
    FScope: IJSScope;
    FVarScope: IJSScope;
    FThisObject: IJSObject;
    FIsStrict: Boolean;
    FCallee: IJSFunction;
    FNewTarget: IJSFunction;
    FBinding: IJSThisBinding;
    FFrames: TObjectDictionary<TJSASTNode, TJSGeneratorFrame>;
    FResumptionsByNode: TDictionary<TJSASTNode, TJSResumption>;
    FSuspendedAt: TJSASTNode;
    FIsSuspending: Boolean;

    procedure DropAll;
    procedure EnumerateValue(const Value: TJSValue; const Visit: TJSReferenceVisitor);
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);

  protected
    procedure ReleaseReferences; override;

  public
    constructor Create(const Registry: TJSObjectRegistry);
    destructor Destroy; override;

    procedure Finish;
    procedure ReleaseHeldValues; override;
    function FindFrame(const Node: TJSASTNode): TJSGeneratorFrame;
    procedure AddFrame(const Node: TJSASTNode; const Frame: TJSGeneratorFrame);
    procedure ReleaseFrame(const Node: TJSASTNode);
    function TryFindResumption(const Node: TJSASTNode; out Entry: TJSResumption): Boolean;
    procedure AddResumption(const Node: TJSASTNode; const Entry: TJSResumption);
    procedure ReleaseResumptions;

    property State: TJSGeneratorState read FState write FState;
    property FunctionObject: IJSFunction read FFunctionObject write FFunctionObject;
    property Scope: IJSScope read FScope write FScope;
    property VarScope: IJSScope read FVarScope write FVarScope;
    property ThisObject: IJSObject read FThisObject write FThisObject;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property Callee: IJSFunction read FCallee write FCallee;
    property NewTarget: IJSFunction read FNewTarget write FNewTarget;
    property Binding: IJSThisBinding read FBinding write FBinding;
    property SuspendedAt: TJSASTNode read FSuspendedAt write FSuspendedAt;
    property IsSuspending: Boolean read FIsSuspending write FIsSuspending;
  end;

implementation

{ TJSGeneratorObject }

constructor TJSGeneratorObject.Create(const Registry: TJSObjectRegistry);
begin
  inherited Create(Registry);

  FState := TJSGeneratorState.SuspendedStart;
  FFrames := TObjectDictionary<TJSASTNode, TJSGeneratorFrame>.Create([doOwnsValues]);
  FResumptionsByNode := TDictionary<TJSASTNode, TJSResumption>.Create;
end;

destructor TJSGeneratorObject.Destroy;
begin
  FFrames.Free;
  FResumptionsByNode.Free;
  inherited;
end;

procedure TJSGeneratorObject.Finish;
begin
  FState := TJSGeneratorState.Completed;
  FSuspendedAt := nil;
  FIsSuspending := False;
  DropAll;

  FScope := nil;
  FVarScope := nil;
  FThisObject := nil;
  FCallee := nil;
  FNewTarget := nil;
  FBinding := nil;
  FFunctionObject := nil;
end;

procedure TJSGeneratorObject.ReleaseHeldValues;
begin
  Finish;
end;

procedure TJSGeneratorObject.ReleaseReferences;
begin
  Finish;
  inherited;
end;

procedure TJSGeneratorObject.DropAll;
begin
  FFrames.Clear;
  FResumptionsByNode.Clear;
end;

procedure TJSGeneratorObject.ReleaseResumptions;
begin
  if FIsSuspending then
    Exit;

  FResumptionsByNode.Clear;
end;

function TJSGeneratorObject.FindFrame(const Node: TJSASTNode): TJSGeneratorFrame;
begin
  if not FFrames.TryGetValue(Node, Result) then
    Result := nil;
end;

procedure TJSGeneratorObject.AddFrame(const Node: TJSASTNode; const Frame: TJSGeneratorFrame);
begin
  FFrames.Add(Node, Frame);
end;

procedure TJSGeneratorObject.ReleaseFrame(const Node: TJSASTNode);
begin
  if FIsSuspending then
    Exit;

  FFrames.Remove(Node);
end;

function TJSGeneratorObject.TryFindResumption(const Node: TJSASTNode; out Entry: TJSResumption): Boolean;
begin
  Result := FResumptionsByNode.TryGetValue(Node, Entry);
end;

procedure TJSGeneratorObject.AddResumption(const Node: TJSASTNode; const Entry: TJSResumption);
begin
  FResumptionsByNode.AddOrSetValue(Node, Entry);
end;

procedure TJSGeneratorObject.EnumerateValue(const Value: TJSValue; const Visit: TJSReferenceVisitor);
begin
  if Value.IsObject then
    Visit(Value.ToObject);
end;

procedure TJSGeneratorObject.EnumerateReferences(const Visit: TJSReferenceVisitor);
begin
  Visit(FScope);
  Visit(FVarScope);
  Visit(FThisObject);
  Visit(FCallee);
  Visit(FNewTarget);
  Visit(FFunctionObject);

  if Assigned(FBinding) then
    Visit(FBinding.Value);

  for var Entry in FResumptionsByNode.Values do
  begin
    EnumerateValue(Entry.Value, Visit);
  end;

  for var Frame in FFrames.Values do
  begin
    Frame.EnumerateReferences(Visit);
  end;
end;

end.
