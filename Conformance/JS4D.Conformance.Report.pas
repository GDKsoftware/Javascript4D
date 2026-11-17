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

    function Totals: TGroupStats;
    function FormatRate(const Passed: Integer; const RunCount: Integer): string;
    function SortedKeys<T>(const Source: TDictionary<string, T>): TArray<string>;
    function TopCounts(const Counts: TDictionary<string, Integer>): TArray<TPair<string, Integer>>;
    function TopClusters(const Count: Integer): TArray<TFailureCluster>;
    function NormalizeDetail(const Detail: string): string;
    function CutDetail(const Detail: string): string;
    function CollapseNumbers(const Text: string): string;
    function PickOutcome(const Results: TArray<TVariantResult>): TTestOutcome;
    function FirstFailure(const Results: TArray<TVariantResult>): TVariantResult;

    procedure AddToGroup(const Group: string; const Outcome: TTestOutcome);
    procedure AddVariants(const Results: TArray<TVariantResult>);
    procedure AddResultLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    function FormatResultLine(const TestCase: TTestCase; const VariantResult: TVariantResult): string;
    function VariantNameOf(const Variant: TTestVariant): string;
    function SortedPassedLines: TArray<string>;
    procedure AddCluster(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure AddRunFeatures(const TestCase: TTestCase);
    procedure AddCount(const Counts: TDictionary<string, Integer>; const Key: string);
    procedure AppendTotals(const Lines: TList<string>);
    procedure AppendSkipReasons(const Lines: TList<string>);
    procedure AppendGroups(const Lines: TList<string>);
    procedure AppendClusters(const Lines: TList<string>);
    procedure AppendRunFeatures(const Lines: TList<string>);

  public
    constructor Create;
    destructor Destroy; override;

    procedure RecordSkipped(const TestCase: TTestCase; const Reason: string);
    procedure RecordRun(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure SaveTo(const Directory: string; const Summary: string);

    function BuildSummary: string;

    property DurationMs: Int64 read FDurationMs write FDurationMs;
  end;

implementation

uses
  System.Character,
  System.IOUtils,
  System.Math,
  System.TypInfo,
  System.Generics.Defaults;

const
  SUMMARY_FILE_NAME = 'baseline.txt';
  FAILURES_FILE_NAME = 'failures.txt';
  PASSED_FILE_NAME = 'passed.txt';
  CLUSTER_COUNT = 15;
  TOP_LIST_COUNT = 40;
  MAX_CLUSTER_KEY_LENGTH = 70;
  CLUSTER_CUT_MARKER = #$AB;
  NUMBER_PLACEHOLDER = '#';
  FAILURE_LINE_FORMAT = '%s [%s] %s';
  PASSED_LINE_FORMAT = '%s [%s]';
  LIST_LINE_FORMAT = '  %7d  %s';
  DETAIL_CUT_SEPARATOR = ';';
  WORD_CONNECTOR = '_';
  GROUP_HEADER_FORMAT = '%-48s %7s %7s %7s %7s %7s %8s';
  GROUP_ROW_FORMAT = '%-48s %7d %7d %7d %7d %7d %8s';

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
    Inc(FVariantRun[VariantResult.Variant]);
    const HasPassed = (VariantResult.Outcome = TTestOutcome.Passed);
    if HasPassed then
      Inc(FVariantPassed[VariantResult.Variant]);
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
  const VariantName = VariantNameOf(VariantResult.Variant);
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

function TConformanceReport.VariantNameOf(const Variant: TTestVariant): string;
begin
  Result := LowerCase(GetEnumName(TypeInfo(TTestVariant), Ord(Variant)));
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

function TConformanceReport.FormatRate(const Passed: Integer; const RunCount: Integer): string;
begin
  const HasNoRuns = (RunCount = 0);
  if HasNoRuns then
    Exit('    n/a');

  Result := Format('%6.1f%%', [Passed * 100.0 / RunCount], TFormatSettings.Invariant);
end;

function TConformanceReport.SortedKeys<T>(const Source: TDictionary<string, T>): TArray<string>;
begin
  Result := Source.Keys.ToArray;
  TArray.Sort<string>(Result);
end;

function TConformanceReport.TopCounts(const Counts: TDictionary<string, Integer>): TArray<TPair<string, Integer>>;
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

function TConformanceReport.TopClusters(const Count: Integer): TArray<TFailureCluster>;
begin
  Result := FClusters.Values.ToArray;
  TArray.Sort<TFailureCluster>(Result, TComparer<TFailureCluster>.Construct(
    function(const Left, Right: TFailureCluster): Integer
    begin
      Result := Right.Count - Left.Count;
      if Result = 0 then
        Result := CompareStr(Left.Key, Right.Key);
    end));

  const HasSurplus = (Length(Result) > Count);
  if HasSurplus then
    SetLength(Result, Count);
end;

function TConformanceReport.BuildSummary: string;
begin
  const Lines = TList<string>.Create;
  try
    AppendTotals(Lines);
    AppendSkipReasons(Lines);
    AppendGroups(Lines);
    AppendClusters(Lines);
    AppendRunFeatures(Lines);
    Result := string.Join(sLineBreak, Lines.ToArray);
  finally
    Lines.Free;
  end;
end;

procedure TConformanceReport.AppendTotals(const Lines: TList<string>);
begin
  const Sum = Totals;
  Lines.Add('test262 conformance baseline');
  Lines.Add('');
  Lines.Add(Format('Found tests : %d', [Sum.Found]));
  Lines.Add(Format('Skipped     : %d', [Sum.Skipped]));
  Lines.Add(Format('Run         : %d', [Sum.RunCount]));
  Lines.Add(Format('  Passed    : %d', [Sum.Passed]));
  Lines.Add(Format('  Failed    : %d (of which step budget or limit exceeded: %d)', [Sum.Failed + Sum.Limit, Sum.Limit]));
  Lines.Add(Format('Pass rate   : %s of the tests that ran', [FormatRate(Sum.Passed, Sum.RunCount).Trim]));
  Lines.Add(Format('Variants    : sloppy %d of %d passed, strict %d of %d passed',
                   [FVariantPassed[TTestVariant.Sloppy], FVariantRun[TTestVariant.Sloppy],
                    FVariantPassed[TTestVariant.Strict], FVariantRun[TTestVariant.Strict]]));
  Lines.Add(Format('Duration    : %.1f seconds', [FDurationMs / 1000], TFormatSettings.Invariant));
end;

procedure TConformanceReport.AppendSkipReasons(const Lines: TList<string>);
begin
  Lines.Add('');
  Lines.Add('Skipped by reason (the feature entries are the roadmap)');
  for var Reason in TopCounts(FSkipReasons) do
  begin
    Lines.Add(Format(LIST_LINE_FORMAT, [Reason.Value, Reason.Key]));
  end;
end;

procedure TConformanceReport.AppendGroups(const Lines: TList<string>);
begin
  Lines.Add('');
  Lines.Add(Format(GROUP_HEADER_FORMAT, ['Directory', 'Found', 'Skipped', 'Run', 'Passed', 'Failed', 'Rate']));
  for var Group in SortedKeys<TGroupStats>(FGroups) do
  begin
    const Stats = FGroups[Group];
    const Rate = FormatRate(Stats.Passed, Stats.RunCount);
    const FailedCount = Stats.Failed + Stats.Limit;
    Lines.Add(Format(GROUP_ROW_FORMAT, [Group, Stats.Found, Stats.Skipped, Stats.RunCount, Stats.Passed, FailedCount,
                                        Rate]));
  end;
end;

procedure TConformanceReport.AppendClusters(const Lines: TList<string>);
begin
  Lines.Add('');
  Lines.Add(Format('Top %d failure clusters (directory | error), with one example each', [CLUSTER_COUNT]));
  for var Cluster in TopClusters(CLUSTER_COUNT) do
  begin
    Lines.Add(Format('  %6d  %s', [Cluster.Count, Cluster.Key]));
    Lines.Add(Format('          e.g. %s', [Cluster.Example]));
  end;
end;

procedure TConformanceReport.AppendRunFeatures(const Lines: TList<string>);
begin
  Lines.Add('');
  Lines.Add('Feature tags on tests that ran (candidates for the exclusion list)');
  const HasNoFeatures = (FRunFeatures.Count = 0);
  if HasNoFeatures then
    Lines.Add('  (none)');

  const Features = TopCounts(FRunFeatures);
  for var Index := 0 to Min(Length(Features), TOP_LIST_COUNT) - 1 do
  begin
    Lines.Add(Format(LIST_LINE_FORMAT, [Features[Index].Value, Features[Index].Key]));
  end;
end;

procedure TConformanceReport.SaveTo(const Directory: string; const Summary: string);
begin
  const SummaryPath = TPath.Combine(Directory, SUMMARY_FILE_NAME);
  const FailuresPath = TPath.Combine(Directory, FAILURES_FILE_NAME);
  const PassedPath = TPath.Combine(Directory, PASSED_FILE_NAME);

  TDirectory.CreateDirectory(Directory);
  TFile.WriteAllText(SummaryPath, Summary, TEncoding.UTF8);
  TFile.WriteAllLines(FailuresPath, FFailureLines.ToArray, TEncoding.UTF8);
  TFile.WriteAllLines(PassedPath, SortedPassedLines, TEncoding.UTF8);
end;

end.
