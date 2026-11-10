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
    FStates: TDictionary<string, TJSBindingState>;

  public
    constructor Create;
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

constructor TJSLexicalStates.Create;
begin
  inherited Create;
  FStates := TDictionary<string, TJSBindingState>.Create;
end;

destructor TJSLexicalStates.Destroy;
begin
  FStates.Free;
  inherited;
end;

procedure TJSLexicalStates.Declare(const Name: string; const IsConstant: Boolean);
begin
  if IsConstant then
    FStates.AddOrSetValue(Name, TJSBindingState.UninitializedConstant)
  else
    FStates.AddOrSetValue(Name, TJSBindingState.Uninitialized);
end;

procedure TJSLexicalStates.MarkInitialized(const Name: string);
begin
  var State: TJSBindingState;
  if not FStates.TryGetValue(Name, State) then
    Exit;

  if State = TJSBindingState.UninitializedConstant then
    FStates.AddOrSetValue(Name, TJSBindingState.Constant)
  else
    FStates.AddOrSetValue(Name, TJSBindingState.Mutable);
end;

function TJSLexicalStates.Contains(const Name: string): Boolean;
begin
  Result := FStates.ContainsKey(Name);
end;

procedure TJSLexicalStates.EnsureInitialized(const Name: string);
begin
  var State: TJSBindingState;
  if not FStates.TryGetValue(Name, State) then
    Exit;

  const IsUninitialized = (State in [TJSBindingState.Uninitialized, TJSBindingState.UninitializedConstant]);
  if IsUninitialized then
    raise TJSErrorFactory.ReferenceError(Format(UninitializedAccessMessage, [Name]));
end;

procedure TJSLexicalStates.EnsureAssignable(const Name: string);
begin
  var State: TJSBindingState;
  if not FStates.TryGetValue(Name, State) then
    Exit;

  EnsureInitialized(Name);

  if State = TJSBindingState.Constant then
    raise TJSErrorFactory.TypeError(Format(ConstantAssignmentMessage, [Name]));
end;

procedure TJSLexicalStates.CopyFrom(const Source: TJSLexicalStates);
begin
  for var Pair in Source.FStates do
  begin
    FStates.AddOrSetValue(Pair.Key, Pair.Value);
  end;
end;

procedure TJSLexicalStates.Clear;
begin
  FStates.Clear;
end;

end.
