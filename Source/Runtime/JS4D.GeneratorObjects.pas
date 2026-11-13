unit JS4D.GeneratorObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.AST;

type
  TJSGeneratorState = (SuspendedStart, SuspendedYield, Executing, Completed);

  TJSResumeMode = (Next, Throw, Return);

  TJSResumption = record
    Mode: TJSResumeMode;
    Value: TJSValue;
  end;

  TJSGeneratorFrame = class
  public
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor); virtual;
  end;

  IJSGenerator = interface(IJSObject)
    ['{3C7A91E4-5D28-4B6F-A0E3-8F14D2B7C569}']
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

  TJSGeneratorRegistry = class;

  TJSAsyncHost = class abstract
  public
    function CreateResult: IJSObject; virtual; abstract;
    procedure Start(const Result: IJSObject; const Body: IJSGenerator); virtual; abstract;
    procedure Reject(const Result: IJSObject; const Reason: TJSValue); virtual; abstract;
  end;

  TJSGeneratorObject = class(TJSObjectImpl, IJSGenerator)
  private
    FState: TJSGeneratorState;
    FFunction: IJSFunction;
    FScope: IJSScope;
    FVarScope: IJSScope;
    FThisObject: IJSObject;
    FIsStrict: Boolean;
    FCallee: IJSFunction;
    FNewTarget: IJSFunction;
    FBinding: IJSThisBinding;
    FFrames: TObjectDictionary<TJSASTNode, TJSGeneratorFrame>;
    FMemory: TDictionary<TJSASTNode, TJSResumption>;
    FSuspendedAt: TJSASTNode;
    FRegistry: TJSGeneratorRegistry;
    FRegistryIndex: Integer;

    procedure EnumerateValue(const Value: TJSValue; const Visit: TJSReferenceVisitor);
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);

  protected
    procedure ReleaseReferences; override;

  public
    constructor Create(const Registry: TJSGeneratorRegistry);
    destructor Destroy; override;

    procedure Finish;
    function FindFrame(const Node: TJSASTNode; out Frame: TJSGeneratorFrame): Boolean;
    procedure AddFrame(const Node: TJSASTNode; const Frame: TJSGeneratorFrame);
    procedure DropFrame(const Node: TJSASTNode);
    function Recall(const Node: TJSASTNode; out Entry: TJSResumption): Boolean;
    procedure Remember(const Node: TJSASTNode; const Entry: TJSResumption);
    procedure ForgetAll;
    procedure ForgetMemory;

    property State: TJSGeneratorState read FState write FState;
    property Func: IJSFunction read FFunction write FFunction;
    property Scope: IJSScope read FScope write FScope;
    property VarScope: IJSScope read FVarScope write FVarScope;
    property ThisObject: IJSObject read FThisObject write FThisObject;
    property IsStrict: Boolean read FIsStrict write FIsStrict;
    property Callee: IJSFunction read FCallee write FCallee;
    property NewTarget: IJSFunction read FNewTarget write FNewTarget;
    property Binding: IJSThisBinding read FBinding write FBinding;
    property SuspendedAt: TJSASTNode read FSuspendedAt write FSuspendedAt;
  end;

  TJSGeneratorRegistry = class
  private
    FGenerators: TList<TJSGeneratorObject>;

    procedure Add(const Generator: TJSGeneratorObject);
    procedure Remove(const Generator: TJSGeneratorObject);

  public
    constructor Create;
    destructor Destroy; override;

    procedure ReleaseAll;
  end;

implementation

{ TJSGeneratorFrame }

procedure TJSGeneratorFrame.EnumerateReferences(const Visit: TJSReferenceVisitor);
begin
end;

{ TJSGeneratorObject }

constructor TJSGeneratorObject.Create(const Registry: TJSGeneratorRegistry);
begin
  inherited Create;

  FState := TJSGeneratorState.SuspendedStart;
  FFrames := TObjectDictionary<TJSASTNode, TJSGeneratorFrame>.Create([doOwnsValues]);
  FMemory := TDictionary<TJSASTNode, TJSResumption>.Create;
  FRegistry := Registry;
  FRegistry.Add(Self);
end;

destructor TJSGeneratorObject.Destroy;
begin
  if Assigned(FRegistry) then
    FRegistry.Remove(Self);

  ForgetAll;
  FFrames.Free;
  FMemory.Free;
  inherited;
end;

procedure TJSGeneratorObject.Finish;
begin
  FState := TJSGeneratorState.Completed;
  FSuspendedAt := nil;
  ForgetAll;

  FScope := nil;
  FVarScope := nil;
  FThisObject := nil;
  FCallee := nil;
  FNewTarget := nil;
  FBinding := nil;
  FFunction := nil;
end;

procedure TJSGeneratorObject.ReleaseReferences;
begin
  Finish;
  inherited;
end;

procedure TJSGeneratorObject.ForgetAll;
begin
  FFrames.Clear;
  FMemory.Clear;
end;

procedure TJSGeneratorObject.ForgetMemory;
begin
  FMemory.Clear;
end;

function TJSGeneratorObject.FindFrame(const Node: TJSASTNode; out Frame: TJSGeneratorFrame): Boolean;
begin
  Result := FFrames.TryGetValue(Node, Frame);
end;

procedure TJSGeneratorObject.AddFrame(const Node: TJSASTNode; const Frame: TJSGeneratorFrame);
begin
  FFrames.Add(Node, Frame);
end;

procedure TJSGeneratorObject.DropFrame(const Node: TJSASTNode);
begin
  FFrames.Remove(Node);
end;

function TJSGeneratorObject.Recall(const Node: TJSASTNode; out Entry: TJSResumption): Boolean;
begin
  Result := FMemory.TryGetValue(Node, Entry);
end;

procedure TJSGeneratorObject.Remember(const Node: TJSASTNode; const Entry: TJSResumption);
begin
  FMemory.AddOrSetValue(Node, Entry);
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
  Visit(FFunction);

  if Assigned(FBinding) then
    Visit(FBinding.Value);

  for var Entry in FMemory.Values do
  begin
    EnumerateValue(Entry.Value, Visit);
  end;

  for var Frame in FFrames.Values do
  begin
    Frame.EnumerateReferences(Visit);
  end;
end;

{ TJSGeneratorRegistry }

constructor TJSGeneratorRegistry.Create;
begin
  inherited Create;

  FGenerators := TList<TJSGeneratorObject>.Create;
end;

destructor TJSGeneratorRegistry.Destroy;
begin
  for var Generator in FGenerators do
  begin
    Generator.FRegistry := nil;
  end;

  FGenerators.Free;
  inherited;
end;

procedure TJSGeneratorRegistry.Add(const Generator: TJSGeneratorObject);
begin
  Generator.FRegistryIndex := FGenerators.Count;
  FGenerators.Add(Generator);
end;

procedure TJSGeneratorRegistry.Remove(const Generator: TJSGeneratorObject);
begin
  const LastIndex = FGenerators.Count - 1;
  const Moved = FGenerators[LastIndex];
  FGenerators[Generator.FRegistryIndex] := Moved;
  Moved.FRegistryIndex := Generator.FRegistryIndex;
  FGenerators.Delete(LastIndex);
end;

procedure TJSGeneratorRegistry.ReleaseAll;
begin
  while FGenerators.Count > 0 do
  begin
    const Generator = FGenerators.Last;
    Generator.FRegistry := nil;
    FGenerators.Delete(FGenerators.Count - 1);

    const Held: IJSObject = Generator;
    Generator.Finish;
  end;
end;

end.
