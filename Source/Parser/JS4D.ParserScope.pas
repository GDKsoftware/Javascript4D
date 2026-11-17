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

  TJSCatchBinding = record
    Names: TArray<string>;
    IsPattern: Boolean;

    class function None: TJSCatchBinding; static;
    class function Simple(const Name: string): TJSCatchBinding; static;
    class function Pattern(const Names: TArray<string>): TJSCatchBinding; static;
  end;

  TJSScopeTracker = class
  private
    type
      TScope = class
      private
        FKind: TJSParserScopeKind;
        FParameters: TArray<string>;
        FCatchBinding: TJSCatchBinding;
        FLexicalNames: TDictionary<string, Boolean>;
        FVarNames: THashSet<string>;
        FScopeInfo: TJSScopeInfo;

        function ContainsName(const Names: TArray<string>; const Name: string): Boolean;
        function IsParameter(const Name: string): Boolean;

      public
        constructor Create(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                           const CatchBinding: TJSCatchBinding);
        destructor Destroy; override;

        function DeclaresLexical(const Name: string): Boolean;
        function ConflictsWithVar(const Name: string): Boolean;
        function BlocksFunctionHoisting(const Name: string): Boolean;
        function TryAddLexical(const Name: string; const IsFunction: Boolean;
                               const AllowFunctionDuplicate: Boolean): Boolean;
        procedure AddVar(const Name: string);
        procedure AddDeclaration(const Declaration: TJSStatement);
        function TakeScopeInfo: TJSScopeInfo;

        property Kind: TJSParserScopeKind read FKind;
      end;

      TFunctionCandidate = record
        Declaration: TJSFunctionDeclaration;
        Depth: Integer;

        class function Create(const Declaration: TJSFunctionDeclaration;
                              const Depth: Integer): TFunctionCandidate; static;
      end;

  private
    FScopes: TObjectList<TScope>;
    FCandidates: TList<TFunctionCandidate>;

    procedure ResolveCandidates(const Scope: TScope; const Depth: Integer);
    function FunctionScopeIndex: Integer;

  public
    constructor Create;
    destructor Destroy; override;

    procedure Enter(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                    const CatchBinding: TJSCatchBinding);
    function Leave: TJSScopeInfo;
    procedure Discard;
    function IsFunctionLevel: Boolean;

    function TryDeclareLexical(const Name: string; const IsFunction: Boolean;
                               const AllowFunctionDuplicate: Boolean): Boolean;
    function TryDeclareVar(const Name: string): Boolean;
    procedure AddDeclaration(const Declaration: TJSStatement);
    procedure AddFunctionCandidate(const Declaration: TJSFunctionDeclaration);
  end;

implementation

{ TJSCatchBinding }

class function TJSCatchBinding.None: TJSCatchBinding;
begin
  Result.Names := nil;
  Result.IsPattern := False;
end;

class function TJSCatchBinding.Simple(const Name: string): TJSCatchBinding;
begin
  Result.Names := [Name];
  Result.IsPattern := False;
end;

class function TJSCatchBinding.Pattern(const Names: TArray<string>): TJSCatchBinding;
begin
  Result.Names := Names;
  Result.IsPattern := True;
end;

{ TJSScopeTracker.TScope }

constructor TJSScopeTracker.TScope.Create(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                                          const CatchBinding: TJSCatchBinding);
begin
  inherited Create;
  FKind := Kind;
  FParameters := Parameters;
  FCatchBinding := CatchBinding;
  FLexicalNames := TDictionary<string, Boolean>.Create;
  FVarNames := THashSet<string>.Create;
end;

destructor TJSScopeTracker.TScope.Destroy;
begin
  FScopeInfo.Free;
  FVarNames.Free;
  FLexicalNames.Free;
  inherited;
end;

function TJSScopeTracker.TScope.ContainsName(const Names: TArray<string>; const Name: string): Boolean;
begin
  for var Candidate in Names do
  begin
    if Candidate = Name then
      Exit(True);
  end;

  Result := False;
end;

function TJSScopeTracker.TScope.IsParameter(const Name: string): Boolean;
begin
  Result := ContainsName(FParameters, Name);
end;

function TJSScopeTracker.TScope.DeclaresLexical(const Name: string): Boolean;
begin
  Result := FLexicalNames.ContainsKey(Name);
end;

function TJSScopeTracker.TScope.ConflictsWithVar(const Name: string): Boolean;
begin
  const IsPatternName = (FCatchBinding.IsPattern and ContainsName(FCatchBinding.Names, Name));

  Result := (DeclaresLexical(Name) or IsPatternName);
end;

function TJSScopeTracker.TScope.BlocksFunctionHoisting(const Name: string): Boolean;
begin
  const IsFunctionParameter = ((FKind = TJSParserScopeKind.Function_) and IsParameter(Name));

  Result := (DeclaresLexical(Name) or IsFunctionParameter);
end;

function TJSScopeTracker.TScope.TryAddLexical(const Name: string; const IsFunction: Boolean;
                                              const AllowFunctionDuplicate: Boolean): Boolean;
begin
  var ExistingIsFunction := False;
  const IsDeclared = FLexicalNames.TryGetValue(Name, ExistingIsFunction);
  if IsDeclared then
  begin
    Result := (ExistingIsFunction and IsFunction and AllowFunctionDuplicate);
    Exit;
  end;

  const ClashesWithVar = FVarNames.Contains(Name);
  const ClashesWithParameter = ((FKind = TJSParserScopeKind.Function_) and IsParameter(Name));
  const ClashesWithCatchBinding = ContainsName(FCatchBinding.Names, Name);
  if ClashesWithVar or ClashesWithParameter or ClashesWithCatchBinding then
  begin
    Result := False;
    Exit;
  end;

  FLexicalNames.Add(Name, IsFunction);
  Result := True;
end;

procedure TJSScopeTracker.TScope.AddVar(const Name: string);
begin
  FVarNames.Add(Name);
end;

procedure TJSScopeTracker.TScope.AddDeclaration(const Declaration: TJSStatement);
begin
  if not Assigned(FScopeInfo) then
    FScopeInfo := TJSScopeInfo.Create;

  FScopeInfo.Declarations.Add(Declaration);
end;

function TJSScopeTracker.TScope.TakeScopeInfo: TJSScopeInfo;
begin
  Result := FScopeInfo;
  FScopeInfo := nil;
end;

{ TJSScopeTracker.TFunctionCandidate }

class function TJSScopeTracker.TFunctionCandidate.Create(const Declaration: TJSFunctionDeclaration;
                                                         const Depth: Integer): TFunctionCandidate;
begin
  Result.Declaration := Declaration;
  Result.Depth := Depth;
end;

{ TJSScopeTracker }

constructor TJSScopeTracker.Create;
begin
  inherited Create;
  FScopes := TObjectList<TScope>.Create(True);
  FCandidates := TList<TFunctionCandidate>.Create;
end;

destructor TJSScopeTracker.Destroy;
begin
  FCandidates.Free;
  FScopes.Free;
  inherited;
end;

procedure TJSScopeTracker.Enter(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                                const CatchBinding: TJSCatchBinding);
begin
  FScopes.Add(TScope.Create(Kind, Parameters, CatchBinding));
end;

function TJSScopeTracker.Leave: TJSScopeInfo;
begin
  const Depth = FScopes.Count - 1;
  const Scope = FScopes[Depth];

  ResolveCandidates(Scope, Depth);
  Result := Scope.TakeScopeInfo;
  FScopes.Delete(Depth);
end;

procedure TJSScopeTracker.Discard;
begin
  const AbandonedScopeInfo = Leave;
  AbandonedScopeInfo.Free;
end;

procedure TJSScopeTracker.ResolveCandidates(const Scope: TScope; const Depth: Integer);
begin
  const IsFunctionScope = (Scope.Kind = TJSParserScopeKind.Function_);

  for var Index := FCandidates.Count - 1 downto 0 do
  begin
    const Candidate = FCandidates[Index];
    const IsNested = (Candidate.Depth > Depth);
    if not IsNested then
      Continue;

    const FunctionName = Candidate.Declaration.Id.Name;
    const IsBlocked = Scope.BlocksFunctionHoisting(FunctionName);
    if IsFunctionScope and (not IsBlocked) then
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

function TJSScopeTracker.FunctionScopeIndex: Integer;
begin
  Result := FScopes.Count - 1;

  while (Result > 0) and (FScopes[Result].Kind <> TJSParserScopeKind.Function_) do
  begin
    Dec(Result);
  end;
end;

function TJSScopeTracker.TryDeclareVar(const Name: string): Boolean;
begin
  const OutermostIndex = FunctionScopeIndex;
  const InnermostIndex = FScopes.Count - 1;

  for var Index := InnermostIndex downto OutermostIndex do
  begin
    if FScopes[Index].ConflictsWithVar(Name) then
    begin
      Result := False;
      Exit;
    end;
  end;

  for var Index := InnermostIndex downto OutermostIndex do
  begin
    FScopes[Index].AddVar(Name);
  end;

  Result := True;
end;

procedure TJSScopeTracker.AddDeclaration(const Declaration: TJSStatement);
begin
  FScopes.Last.AddDeclaration(Declaration);
end;

procedure TJSScopeTracker.AddFunctionCandidate(const Declaration: TJSFunctionDeclaration);
begin
  const Candidate = TFunctionCandidate.Create(Declaration, FScopes.Count - 1);
  FCandidates.Add(Candidate);
end;

end.
