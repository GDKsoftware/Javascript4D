unit JS4D.ParserScope;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.AST;

type
  TJSParserScopeKind = (
    Function_,
    Block
  );

  TJSParserScope = class
  private
    FKind: TJSParserScopeKind;
    FParameters: TArray<string>;
    FCatchParameter: string;
    FLexicalNames: TDictionary<string, Boolean>;
    FVarNames: TDictionary<string, Boolean>;
    FScopeInfo: TJSScopeInfo;

    function IsParameter(const Name: string): Boolean;

  public
    constructor Create(const Kind: TJSParserScopeKind; const Parameters: TArray<string>);
    destructor Destroy; override;

    function DeclaresLexical(const Name: string): Boolean;
    function BlocksFunctionHoisting(const Name: string): Boolean;
    function TryAddLexical(const Name: string; const IsFunction: Boolean; const AllowFunctionDuplicate: Boolean): Boolean;
    procedure AddVar(const Name: string);
    function HasVar(const Name: string): Boolean;
    procedure AddDeclaration(const Declaration: TJSStatement);
    function TakeScopeInfo: TJSScopeInfo;

    property Kind: TJSParserScopeKind read FKind;
    property CatchParameter: string read FCatchParameter write FCatchParameter;
  end;

  TJSScopeTracker = class
  private
    type
      TFunctionCandidate = record
        Declaration: TJSFunctionDeclaration;
        Depth: Integer;
      end;

  private
    FScopes: TObjectList<TJSParserScope>;
    FCandidates: TList<TFunctionCandidate>;

    procedure ResolveCandidates(const Scope: TJSParserScope; const Depth: Integer);

  public
    constructor Create;
    destructor Destroy; override;

    procedure Enter(const Kind: TJSParserScopeKind; const Parameters: TArray<string>);
    procedure SetCatchParameter(const Name: string);
    function Leave: TJSScopeInfo;
    function IsFunctionLevel: Boolean;

    function TryDeclareLexical(const Name: string; const IsFunction: Boolean; const AllowFunctionDuplicate: Boolean): Boolean;
    function TryDeclareVar(const Name: string): Boolean;
    procedure AddDeclaration(const Declaration: TJSStatement);
    procedure AddFunctionCandidate(const Declaration: TJSFunctionDeclaration);
  end;

implementation

{ TJSParserScope }

constructor TJSParserScope.Create(const Kind: TJSParserScopeKind; const Parameters: TArray<string>);
begin
  inherited Create;
  FKind := Kind;
  FParameters := Parameters;
end;

destructor TJSParserScope.Destroy;
begin
  FScopeInfo.Free;
  FVarNames.Free;
  FLexicalNames.Free;
  inherited;
end;

function TJSParserScope.IsParameter(const Name: string): Boolean;
begin
  for var Parameter in FParameters do
  begin
    if Parameter = Name then
      Exit(True);
  end;

  Result := False;
end;

function TJSParserScope.DeclaresLexical(const Name: string): Boolean;
begin
  Result := Assigned(FLexicalNames) and FLexicalNames.ContainsKey(Name);
end;

function TJSParserScope.BlocksFunctionHoisting(const Name: string): Boolean;
begin
  Result := DeclaresLexical(Name) or ((FKind = TJSParserScopeKind.Function_) and IsParameter(Name));
end;

function TJSParserScope.TryAddLexical(const Name: string; const IsFunction: Boolean;
                                      const AllowFunctionDuplicate: Boolean): Boolean;
begin
  var ExistingIsFunction: Boolean;
  const IsDeclared = Assigned(FLexicalNames) and FLexicalNames.TryGetValue(Name, ExistingIsFunction);
  if IsDeclared then
    Exit(ExistingIsFunction and IsFunction and AllowFunctionDuplicate);

  const ClashesWithVar = HasVar(Name);
  const ClashesWithParameter = (FKind = TJSParserScopeKind.Function_) and IsParameter(Name);
  const ClashesWithCatchParameter = (not FCatchParameter.IsEmpty) and (Name = FCatchParameter);
  if ClashesWithVar or ClashesWithParameter or ClashesWithCatchParameter then
    Exit(False);

  if not Assigned(FLexicalNames) then
    FLexicalNames := TDictionary<string, Boolean>.Create;

  FLexicalNames.Add(Name, IsFunction);
  Result := True;
end;

procedure TJSParserScope.AddVar(const Name: string);
begin
  if not Assigned(FVarNames) then
    FVarNames := TDictionary<string, Boolean>.Create;

  FVarNames.AddOrSetValue(Name, True);
end;

function TJSParserScope.HasVar(const Name: string): Boolean;
begin
  Result := Assigned(FVarNames) and FVarNames.ContainsKey(Name);
end;

procedure TJSParserScope.AddDeclaration(const Declaration: TJSStatement);
begin
  if not Assigned(FScopeInfo) then
    FScopeInfo := TJSScopeInfo.Create;

  FScopeInfo.Declarations.Add(Declaration);
end;

function TJSParserScope.TakeScopeInfo: TJSScopeInfo;
begin
  Result := FScopeInfo;
  FScopeInfo := nil;
end;

{ TJSScopeTracker }

constructor TJSScopeTracker.Create;
begin
  inherited Create;
  FScopes := TObjectList<TJSParserScope>.Create(True);
  FCandidates := TList<TFunctionCandidate>.Create;
end;

destructor TJSScopeTracker.Destroy;
begin
  FCandidates.Free;
  FScopes.Free;
  inherited;
end;

procedure TJSScopeTracker.Enter(const Kind: TJSParserScopeKind; const Parameters: TArray<string>);
begin
  FScopes.Add(TJSParserScope.Create(Kind, Parameters));
end;

procedure TJSScopeTracker.SetCatchParameter(const Name: string);
begin
  FScopes.Last.CatchParameter := Name;
end;

function TJSScopeTracker.Leave: TJSScopeInfo;
begin
  const Depth = FScopes.Count - 1;
  const Scope = FScopes[Depth];

  ResolveCandidates(Scope, Depth);
  Result := Scope.TakeScopeInfo;
  FScopes.Delete(Depth);
end;

procedure TJSScopeTracker.ResolveCandidates(const Scope: TJSParserScope; const Depth: Integer);
begin
  const IsFunctionScope = (Scope.Kind = TJSParserScopeKind.Function_);

  for var Index := FCandidates.Count - 1 downto 0 do
  begin
    const Candidate = FCandidates[Index];
    const IsNested = (Candidate.Depth > Depth);
    if not IsNested then
      Continue;

    const IsBlocked = Scope.BlocksFunctionHoisting(Candidate.Declaration.Id.Name);
    if IsFunctionScope and not IsBlocked then
      Candidate.Declaration.HoistsToVar := True;

    if IsFunctionScope or IsBlocked then
      FCandidates.Delete(Index);
  end;
end;

function TJSScopeTracker.IsFunctionLevel: Boolean;
begin
  Result := (FScopes.Last.Kind = TJSParserScopeKind.Function_);
end;

function TJSScopeTracker.TryDeclareLexical(const Name: string; const IsFunction: Boolean;
                                           const AllowFunctionDuplicate: Boolean): Boolean;
begin
  Result := FScopes.Last.TryAddLexical(Name, IsFunction, AllowFunctionDuplicate);
end;

function TJSScopeTracker.TryDeclareVar(const Name: string): Boolean;
begin
  for var Index := FScopes.Count - 1 downto 0 do
  begin
    const Scope = FScopes[Index];
    if Scope.DeclaresLexical(Name) then
      Exit(False);

    Scope.AddVar(Name);

    if Scope.Kind = TJSParserScopeKind.Function_ then
      Break;
  end;

  Result := True;
end;

procedure TJSScopeTracker.AddDeclaration(const Declaration: TJSStatement);
begin
  FScopes.Last.AddDeclaration(Declaration);
end;

procedure TJSScopeTracker.AddFunctionCandidate(const Declaration: TJSFunctionDeclaration);
begin
  var Candidate: TFunctionCandidate;
  Candidate.Declaration := Declaration;
  Candidate.Depth := FScopes.Count - 1;
  FCandidates.Add(Candidate);
end;

end.
