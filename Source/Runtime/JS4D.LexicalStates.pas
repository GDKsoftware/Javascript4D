unit JS4D.LexicalStates;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Errors;

type
  TJSBindingState = (
    Uninitialized,
    UninitializedConstant,
    Mutable,
    Constant
  );

  TJSLexicalStates = class
  private
    FNames: TArray<string>;
    FStates: TArray<TJSBindingState>;
    FCount: Integer;
    FIndex: TDictionary<string, Integer>;

    function IndexOf(const Name: string): Integer;
    procedure Add(const Name: string; const State: TJSBindingState);
    procedure BuildIndex;
    procedure Store(const Name: string; const State: TJSBindingState);
    function TryGetState(const Name: string; out State: TJSBindingState): Boolean;
    procedure RaiseIfUninitialized(const Name: string; const State: TJSBindingState);

  public
    destructor Destroy; override;

    procedure Declare(const Name: string; const IsConstant: Boolean);
    procedure MarkInitialized(const Name: string);
    function Contains(const Name: string): Boolean;
    procedure EnsureInitialized(const Name: string);
    procedure EnsureAssignable(const Name: string);
    procedure CopyFrom(const Source: TJSLexicalStates);
    procedure Clear;
  end;

implementation

const
  UninitializedAccessMessage = 'Cannot access ''%s'' before initialization';
  ConstantAssignmentMessage = 'Assignment to constant variable ''%s''';
  LINEAR_SEARCH_LIMIT = 8;
  INITIAL_CAPACITY = 4;

destructor TJSLexicalStates.Destroy;
begin
  FIndex.Free;
  inherited;
end;

function TJSLexicalStates.IndexOf(const Name: string): Integer;
begin
  if Assigned(FIndex) then
  begin
    if not FIndex.TryGetValue(Name, Result) then
      Result := -1;

    Exit;
  end;

  for Result := 0 to FCount - 1 do
  begin
    if FNames[Result] = Name then
      Exit;
  end;

  Result := -1;
end;

procedure TJSLexicalStates.Add(const Name: string; const State: TJSBindingState);
begin
  if FCount = Length(FNames) then
  begin
    const NewCapacity = Length(FNames) * 2 + INITIAL_CAPACITY;
    SetLength(FNames, NewCapacity);
    SetLength(FStates, NewCapacity);
  end;

  FNames[FCount] := Name;
  FStates[FCount] := State;

  if Assigned(FIndex) then
    FIndex.Add(Name, FCount);

  Inc(FCount);

  const NeedsIndex = (not Assigned(FIndex)) and (FCount > LINEAR_SEARCH_LIMIT);
  if NeedsIndex then
    BuildIndex;
end;

procedure TJSLexicalStates.BuildIndex;
begin
  FIndex := TDictionary<string, Integer>.Create;

  for var Position := 0 to FCount - 1 do
  begin
    FIndex.Add(FNames[Position], Position);
  end;
end;

procedure TJSLexicalStates.Store(const Name: string; const State: TJSBindingState);
begin
  const Position = IndexOf(Name);
  if Position < 0 then
  begin
    Add(Name, State);
    Exit;
  end;

  FStates[Position] := State;
end;

function TJSLexicalStates.TryGetState(const Name: string; out State: TJSBindingState): Boolean;
begin
  const Position = IndexOf(Name);
  Result := (Position >= 0);

  if Result then
    State := FStates[Position];
end;

procedure TJSLexicalStates.RaiseIfUninitialized(const Name: string; const State: TJSBindingState);
begin
  const IsUninitialized = (State in [TJSBindingState.Uninitialized, TJSBindingState.UninitializedConstant]);
  if IsUninitialized then
    raise TJSErrorFactory.ReferenceError(Format(UninitializedAccessMessage, [Name]));
end;

procedure TJSLexicalStates.Declare(const Name: string; const IsConstant: Boolean);
begin
  if IsConstant then
    Store(Name, TJSBindingState.UninitializedConstant)
  else
    Store(Name, TJSBindingState.Uninitialized);
end;

procedure TJSLexicalStates.MarkInitialized(const Name: string);
begin
  const Position = IndexOf(Name);
  if Position < 0 then
    Exit;

  if FStates[Position] = TJSBindingState.UninitializedConstant then
    FStates[Position] := TJSBindingState.Constant
  else
    FStates[Position] := TJSBindingState.Mutable;
end;

function TJSLexicalStates.Contains(const Name: string): Boolean;
begin
  Result := (IndexOf(Name) >= 0);
end;

procedure TJSLexicalStates.EnsureInitialized(const Name: string);
begin
  var State: TJSBindingState;
  if not TryGetState(Name, State) then
    Exit;

  RaiseIfUninitialized(Name, State);
end;

procedure TJSLexicalStates.EnsureAssignable(const Name: string);
begin
  var State: TJSBindingState;
  if not TryGetState(Name, State) then
    Exit;

  RaiseIfUninitialized(Name, State);

  if State = TJSBindingState.Constant then
    raise TJSErrorFactory.TypeError(Format(ConstantAssignmentMessage, [Name]));
end;

procedure TJSLexicalStates.CopyFrom(const Source: TJSLexicalStates);
begin
  for var Position := 0 to Source.FCount - 1 do
  begin
    Store(Source.FNames[Position], Source.FStates[Position]);
  end;
end;

procedure TJSLexicalStates.Clear;
begin
  FreeAndNil(FIndex);
  FNames := nil;
  FStates := nil;
  FCount := 0;
end;

end.
