unit JS4D.Conformance.Report;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase;

type
  TGroupStats = record
    Found: Integer;
    Passed: Integer;
    Failed: Integer;
    Limit: Integer;
    Skipped: Integer;

    function RunCount: Integer;
  end;

  TFailureCluster = record
    Key: string;
    Count: Integer;
    Example: string;
  end;

  TConformanceReport = class
  private
    FGroups: TDictionary<string, TGroupStats>;
    FSkipReasons: TDictionary<string, Integer>;
    FClusters: TDictionary<string, TFailureCluster>;
    FRunFeatures: TDictionary<string, Integer>;
    FPassedLines: TList<string>;
    FFailureLines: TList<string>;
    FVariantRun: array[TTestVariant] of Integer;
    FVariantPassed: array[TTestVariant] of Integer;
    FDurationMs: Int64;

    function SortedCounts(const Counts: TDictionary<string, Integer>): TArray<TPair<string, Integer>>;
    function NormalizeDetail(const Detail: string): string;
    function CutDetail(const Detail: string): string;
    function CollapseNumbers(const Text: string): string;
    function PickOutcome(const Results: TArray<TVariantResult>): TTestOutcome;
    function FirstFailure(const Results: TArray<TVariantResult>): TVariantResult;
    function FormatResultLine(const TestCase: TTestCase; const VariantResult: TVariantResult): string;
    function VariantNameOf(const TestVariant: TTestVariant): string;

    procedure AddToGroup(const Group: string; const Outcome: TTestOutcome);
    procedure AddVariants(const Results: TArray<TVariantResult>);
    procedure AddResultLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure AddCluster(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure AddRunFeatures(const TestCase: TTestCase);
    procedure AddCount(const Counts: TDictionary<string, Integer>; const Key: string);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RecordSkipped(const TestCase: TTestCase; const Reason: string);
    procedure RecordRun(const TestCase: TTestCase; const Results: TArray<TVariantResult>);

    function Totals: TGroupStats;
    function SortedGroups: TArray<TPair<string, TGroupStats>>;
    function SkipReasons: TArray<TPair<string, Integer>>;
    function RunFeatures: TArray<TPair<string, Integer>>;
    function SortedClusters: TArray<TFailureCluster>;
    function SortedPassedLines: TArray<string>;
    function FailureLines: TArray<string>;
    function VariantRunCount(const TestVariant: TTestVariant): Integer;
    function VariantPassedCount(const TestVariant: TTestVariant): Integer;

    property DurationMs: Int64 read FDurationMs write FDurationMs;
  end;

implementation

uses
  System.Character,
  System.Math,
  System.TypInfo,
  System.Generics.Defaults;

const
  MAX_CLUSTER_KEY_LENGTH = 70;
  CLUSTER_CUT_MARKER = #$AB;
  NUMBER_PLACEHOLDER = '#';
  FAILURE_LINE_FORMAT = '%s [%s] %s';
  PASSED_LINE_FORMAT = '%s [%s]';
  DETAIL_CUT_SEPARATOR = ';';
  WORD_CONNECTOR = '_';

function TGroupStats.RunCount: Integer;
begin
  Result := Passed + Failed + Limit;
end;

constructor TConformanceReport.Create;
begin
  inherited Create;
  FGroups := TDictionary<string, TGroupStats>.Create;
  FSkipReasons := TDictionary<string, Integer>.Create;
  FClusters := TDictionary<string, TFailureCluster>.Create;
  FRunFeatures := TDictionary<string, Integer>.Create;
  FPassedLines := TList<string>.Create;
  FFailureLines := TList<string>.Create;
end;

destructor TConformanceReport.Destroy;
begin
  FFailureLines.Free;
  FRunFeatures.Free;
  FPassedLines.Free;
  FClusters.Free;
  FSkipReasons.Free;
  FGroups.Free;
  inherited;
end;

procedure TConformanceReport.RecordSkipped(const TestCase: TTestCase; const Reason: string);
begin
  AddToGroup(TestCase.Group, TTestOutcome.Skipped);
  AddCount(FSkipReasons, Reason);
end;

procedure TConformanceReport.RecordRun(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  const Outcome = PickOutcome(Results);
  AddToGroup(TestCase.Group, Outcome);
  AddVariants(Results);
  AddRunFeatures(TestCase);
  AddResultLines(TestCase, Results);

  const IsPass = (Outcome = TTestOutcome.Passed);
  if not IsPass then
    AddCluster(TestCase, Results);
end;

function TConformanceReport.PickOutcome(const Results: TArray<TVariantResult>): TTestOutcome;
begin
  Result := TTestOutcome.Passed;
  for var VariantResult in Results do
  begin
    const HasFailed = (VariantResult.Outcome = TTestOutcome.Failed);
    if HasFailed then
      Exit(TTestOutcome.Failed);

    const HasHitLimit = (VariantResult.Outcome = TTestOutcome.Limit);
    if HasHitLimit then
      Result := TTestOutcome.Limit;
  end;
end;

function TConformanceReport.FirstFailure(const Results: TArray<TVariantResult>): TVariantResult;
begin
  for var VariantResult in Results do
  begin
    const HasNotPassed = (VariantResult.Outcome <> TTestOutcome.Passed);
    if HasNotPassed then
      Exit(VariantResult);
  end;

  raise EConformanceError.Create('No failing variant found in a failing test');
end;

procedure TConformanceReport.AddToGroup(const Group: string; const Outcome: TTestOutcome);
begin
  var Stats: TGroupStats;
  if not FGroups.TryGetValue(Group, Stats) then
    Stats := Default(TGroupStats);

  Inc(Stats.Found);
  case Outcome of
    TTestOutcome.Passed  : Inc(Stats.Passed);
    TTestOutcome.Failed  : Inc(Stats.Failed);
    TTestOutcome.Limit   : Inc(Stats.Limit);
    TTestOutcome.Skipped : Inc(Stats.Skipped);
  else
    raise ENotSupportedException.CreateFmt('Unsupported outcome: %d', [Ord(Outcome)]);
  end;

  FGroups.AddOrSetValue(Group, Stats);
end;

procedure TConformanceReport.AddVariants(const Results: TArray<TVariantResult>);
begin
  for var VariantResult in Results do
  begin
    Inc(FVariantRun[VariantResult.TestVariant]);
    const HasPassed = (VariantResult.Outcome = TTestOutcome.Passed);
    if HasPassed then
      Inc(FVariantPassed[VariantResult.TestVariant]);
  end;
end;

procedure TConformanceReport.AddResultLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  for var VariantResult in Results do
  begin
    const Line = FormatResultLine(TestCase, VariantResult);
    const HasPassed = (VariantResult.Outcome = TTestOutcome.Passed);
    if HasPassed then
    begin
      FPassedLines.Add(Line);
    end
    else
    begin
      FFailureLines.Add(Line);
    end;
  end;
end;

function TConformanceReport.FormatResultLine(const TestCase: TTestCase; const VariantResult: TVariantResult): string;
begin
  const VariantName = VariantNameOf(VariantResult.TestVariant);
  const HasPassed = (VariantResult.Outcome = TTestOutcome.Passed);
  if HasPassed then
  begin
    Result := Format(PASSED_LINE_FORMAT, [TestCase.RelativePath, VariantName]);
  end
  else
  begin
    Result := Format(FAILURE_LINE_FORMAT, [TestCase.RelativePath, VariantName, VariantResult.Detail]);
  end;
end;

function TConformanceReport.VariantNameOf(const TestVariant: TTestVariant): string;
begin
  Result := LowerCase(GetEnumName(TypeInfo(TTestVariant), Ord(TestVariant)));
end;

function TConformanceReport.SortedPassedLines: TArray<string>;
begin
  Result := FPassedLines.ToArray;
  TArray.Sort<string>(Result);
end;

procedure TConformanceReport.AddCluster(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  const First = FirstFailure(Results);
  const NormalizedDetail = NormalizeDetail(First.Detail);
  const Key = Format('%s | %s', [TestCase.Group, NormalizedDetail]);

  var Cluster: TFailureCluster;
  const IsKnown = FClusters.TryGetValue(Key, Cluster);
  if not IsKnown then
  begin
    Cluster.Key := Key;
    Cluster.Example := TestCase.RelativePath;
  end;

  Inc(Cluster.Count);
  FClusters.AddOrSetValue(Key, Cluster);
end;

procedure TConformanceReport.AddRunFeatures(const TestCase: TTestCase);
begin
  for var Feature in TestCase.Metadata.Features do
  begin
    AddCount(FRunFeatures, Feature);
  end;
end;

procedure TConformanceReport.AddCount(const Counts: TDictionary<string, Integer>; const Key: string);
begin
  var Current: Integer;
  if not Counts.TryGetValue(Key, Current) then
    Current := 0;

  Counts.AddOrSetValue(Key, Current + 1);
end;

function TConformanceReport.NormalizeDetail(const Detail: string): string;
begin
  const CutText = CutDetail(Detail);
  const Collapsed = CollapseNumbers(CutText);

  Result := Collapsed.Substring(0, Min(Collapsed.Length, MAX_CLUSTER_KEY_LENGTH));
end;

function TConformanceReport.CutDetail(const Detail: string): string;
begin
  const CutIndex = Detail.IndexOfAny([CLUSTER_CUT_MARKER, DETAIL_CUT_SEPARATOR]);
  const HasCutMarker = (CutIndex >= 0);
  if HasCutMarker then
  begin
    Result := Detail.Substring(0, CutIndex);
  end
  else
  begin
    Result := Detail;
  end;
end;

function TConformanceReport.CollapseNumbers(const Text: string): string;
begin
  const Collapsed = TStringBuilder.Create;
  try
    var InWord := False;
    var InNumber := False;
    for var Symbol in Text do
    begin
      const IsDigit = CharInSet(Symbol, ['0'..'9']);
      const IsNumberStart = IsDigit and (not InWord) and (not InNumber);
      const IsNumberPart = IsDigit and (not InWord) and InNumber;
      if IsNumberStart then
      begin
        Collapsed.Append(NUMBER_PLACEHOLDER);
      end
      else if not IsNumberPart then
      begin
        Collapsed.Append(Symbol);
      end;

      InNumber := IsDigit and (not InWord);
      InWord := Symbol.IsLetter or (IsDigit and InWord) or (Symbol = WORD_CONNECTOR);
    end;

    Result := Collapsed.ToString;
  finally
    Collapsed.Free;
  end;
end;

function TConformanceReport.Totals: TGroupStats;
begin
  Result := Default(TGroupStats);
  for var Stats in FGroups.Values do
  begin
    Inc(Result.Found, Stats.Found);
    Inc(Result.Passed, Stats.Passed);
    Inc(Result.Failed, Stats.Failed);
    Inc(Result.Limit, Stats.Limit);
    Inc(Result.Skipped, Stats.Skipped);
  end;
end;

function TConformanceReport.SortedGroups: TArray<TPair<string, TGroupStats>>;
begin
  Result := FGroups.ToArray;
  TArray.Sort<TPair<string, TGroupStats>>(Result, TComparer<TPair<string, TGroupStats>>.Construct(
    function(const Left, Right: TPair<string, TGroupStats>): Integer
    begin
      Result := CompareStr(Left.Key, Right.Key);
    end));
end;

function TConformanceReport.SortedCounts(const Counts: TDictionary<string, Integer>): TArray<TPair<string, Integer>>;
begin
  Result := Counts.ToArray;
  TArray.Sort<TPair<string, Integer>>(Result, TComparer<TPair<string, Integer>>.Construct(
    function(const Left, Right: TPair<string, Integer>): Integer
    begin
      Result := Right.Value - Left.Value;
      if Result = 0 then
        Result := CompareStr(Left.Key, Right.Key);
    end));
end;

function TConformanceReport.SkipReasons: TArray<TPair<string, Integer>>;
begin
  Result := SortedCounts(FSkipReasons);
end;

function TConformanceReport.RunFeatures: TArray<TPair<string, Integer>>;
begin
  Result := SortedCounts(FRunFeatures);
end;

function TConformanceReport.SortedClusters: TArray<TFailureCluster>;
begin
  Result := FClusters.Values.ToArray;
  TArray.Sort<TFailureCluster>(Result, TComparer<TFailureCluster>.Construct(
    function(const Left, Right: TFailureCluster): Integer
    begin
      Result := Right.Count - Left.Count;
      if Result = 0 then
        Result := CompareStr(Left.Key, Right.Key);
    end));
end;

function TConformanceReport.FailureLines: TArray<string>;
begin
  Result := FFailureLines.ToArray;
end;

function TConformanceReport.VariantRunCount(const TestVariant: TTestVariant): Integer;
begin
  Result := FVariantRun[TestVariant];
end;

function TConformanceReport.VariantPassedCount(const TestVariant: TTestVariant): Integer;
begin
  Result := FVariantPassed[TestVariant];
end;

end.
