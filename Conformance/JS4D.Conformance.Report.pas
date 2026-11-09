unit JS4D.Conformance.Report;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Character,
  System.Classes,
  System.IOUtils,
  System.Math,
  System.TypInfo,
  System.Generics.Collections,
  System.Generics.Defaults,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase;

type
  TGroupStats = record
    Found: Integer;
    Passed: Integer;
    Failed: Integer;
    Limit: Integer;
    Skipped: Integer;

    function Run: Integer;
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
    function FormatRate(const Passed: Integer; const Run: Integer): string;
    function SortedKeys<T>(const Source: TDictionary<string, T>): TArray<string>;
    function TopSkipReasons: TArray<TPair<string, Integer>>;
    function TopRunFeatures: TArray<TPair<string, Integer>>;
    function TopClusters(const Count: Integer): TArray<TFailureCluster>;
    function NormalizeDetail(const Detail: string): string;
    function PickOutcome(const Results: TArray<TVariantResult>): TTestOutcome;
    function FirstFailure(const Results: TArray<TVariantResult>): TVariantResult;

    procedure AddToGroup(const Group: string; const Outcome: TTestOutcome);
    procedure AddVariants(const Results: TArray<TVariantResult>);
    procedure AddFailure(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure AddFailureLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
    procedure AddPassedLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
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
    procedure SaveTo(const Directory: string);

    function BuildSummary: string;

    property DurationMs: Int64 read FDurationMs write FDurationMs;
  end;

implementation

const
  SummaryFileName = 'baseline.txt';
  FailuresFileName = 'failures.txt';
  PassedFileName = 'passed.txt';
  ClusterCount = 15;
  TopListCount = 40;
  MaxClusterKeyLength = 70;
  ClusterCutMarker = #$AB;
  NumberPlaceholder = '#';
  FailureLineFormat = '%s [%s] %s';
  PassedLineFormat = '%s [%s]';
  ListLineFormat = '  %7d  %s';
  BlankLine = '';

function TGroupStats.Run: Integer;
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
  AddPassedLines(TestCase, Results);

  const IsPass = (Outcome = TTestOutcome.Passed);
  if not IsPass then
    AddFailure(TestCase, Results);
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
  FGroups.TryGetValue(Group, Stats);

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

procedure TConformanceReport.AddFailure(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  AddFailureLines(TestCase, Results);
  AddCluster(TestCase, Results);
end;

procedure TConformanceReport.AddFailureLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  for var VariantResult in Results do
  begin
    const HasNotPassed = (VariantResult.Outcome <> TTestOutcome.Passed);
    if HasNotPassed then
    begin
      FFailureLines.Add(FormatResultLine(TestCase, VariantResult));
    end;
  end;
end;

procedure TConformanceReport.AddPassedLines(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  for var VariantResult in Results do
  begin
    const HasPassed = (VariantResult.Outcome = TTestOutcome.Passed);
    if HasPassed then
    begin
      const VariantName = VariantNameOf(VariantResult.Variant);
      FPassedLines.Add(Format(PassedLineFormat, [TestCase.RelativePath, VariantName]));
    end;
  end;
end;

function TConformanceReport.FormatResultLine(const TestCase: TTestCase; const VariantResult: TVariantResult): string;
begin
  const VariantName = VariantNameOf(VariantResult.Variant);
  Result := Format(FailureLineFormat, [TestCase.RelativePath, VariantName, VariantResult.Detail]);
end;

function TConformanceReport.VariantNameOf(const Variant: TTestVariant): string;
begin
  Result := LowerCase(GetEnumName(TypeInfo(TTestVariant), Ord(Variant)));
end;

function TConformanceReport.SortedPassedLines: TArray<string>;
begin
  Result := FPassedLines.ToArray;
  TArray.Sort<string>(Result, TComparer<string>.Construct(
    function(const Left, Right: string): Integer
    begin
      Result := CompareStr(Left, Right);
    end));
end;

procedure TConformanceReport.AddCluster(const TestCase: TTestCase; const Results: TArray<TVariantResult>);
begin
  const First = FirstFailure(Results);
  const Key = Format('%s | %s', [TestCase.Group, NormalizeDetail(First.Detail)]);

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
  Counts.TryGetValue(Key, Current);
  Counts.AddOrSetValue(Key, Current + 1);
end;

function TConformanceReport.NormalizeDetail(const Detail: string): string;
begin
  var Text := Detail;
  const CutIndex = Text.IndexOfAny([ClusterCutMarker, ';']);
  const HasCutMarker = (CutIndex >= 0);
  if HasCutMarker then
    Text := Text.Substring(0, CutIndex);

  const Normalized = TStringBuilder.Create;
  try
    var InWord := False;
    var InNumber := False;
    for var Character in Text do
    begin
      const IsDigit = CharInSet(Character, ['0'..'9']);
      const IsNumberStart = IsDigit and (not InWord) and (not InNumber);
      const IsNumberPart = IsDigit and (not InWord) and InNumber;
      if IsNumberStart then
      begin
        Normalized.Append(NumberPlaceholder);
      end
      else if not IsNumberPart then
      begin
        Normalized.Append(Character);
      end;

      InNumber := IsDigit and (not InWord);
      InWord := Character.IsLetter or (IsDigit and InWord) or (Character = '_');
    end;

    const Key = Normalized.ToString;
    Result := Key.Substring(0, Min(Key.Length, MaxClusterKeyLength));
  finally
    Normalized.Free;
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

function TConformanceReport.FormatRate(const Passed: Integer; const Run: Integer): string;
begin
  const HasNoRuns = (Run = 0);
  if HasNoRuns then
    Exit('    n/a');

  Result := Format('%6.1f%%', [Passed * 100.0 / Run], TFormatSettings.Invariant);
end;

function TConformanceReport.SortedKeys<T>(const Source: TDictionary<string, T>): TArray<string>;
begin
  Result := Source.Keys.ToArray;
  TArray.Sort<string>(Result);
end;

function TConformanceReport.TopSkipReasons: TArray<TPair<string, Integer>>;
begin
  Result := FSkipReasons.ToArray;
  TArray.Sort<TPair<string, Integer>>(Result, TComparer<TPair<string, Integer>>.Construct(
    function(const Left, Right: TPair<string, Integer>): Integer
    begin
      Result := Right.Value - Left.Value;
    end));
end;

function TConformanceReport.TopRunFeatures: TArray<TPair<string, Integer>>;
begin
  Result := FRunFeatures.ToArray;
  TArray.Sort<TPair<string, Integer>>(Result, TComparer<TPair<string, Integer>>.Construct(
    function(const Left, Right: TPair<string, Integer>): Integer
    begin
      Result := Right.Value - Left.Value;
    end));
end;

function TConformanceReport.TopClusters(const Count: Integer): TArray<TFailureCluster>;
begin
  Result := FClusters.Values.ToArray;
  TArray.Sort<TFailureCluster>(Result, TComparer<TFailureCluster>.Construct(
    function(const Left, Right: TFailureCluster): Integer
    begin
      Result := Right.Count - Left.Count;
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
  Lines.Add(BlankLine);
  Lines.Add(Format('Found tests : %d', [Sum.Found]));
  Lines.Add(Format('Skipped     : %d', [Sum.Skipped]));
  Lines.Add(Format('Run         : %d', [Sum.Run]));
  Lines.Add(Format('  Passed    : %d', [Sum.Passed]));
  Lines.Add(Format('  Failed    : %d (of which step budget or limit exceeded: %d)', [Sum.Failed + Sum.Limit, Sum.Limit]));
  Lines.Add(Format('Pass rate   : %s of the tests that ran', [FormatRate(Sum.Passed, Sum.Run).Trim]));
  Lines.Add(Format('Variants    : sloppy %d of %d passed, strict %d of %d passed',
                   [FVariantPassed[TTestVariant.Sloppy], FVariantRun[TTestVariant.Sloppy],
                    FVariantPassed[TTestVariant.Strict], FVariantRun[TTestVariant.Strict]]));
  Lines.Add(Format('Duration    : %.1f seconds', [FDurationMs / 1000], TFormatSettings.Invariant));
end;

procedure TConformanceReport.AppendSkipReasons(const Lines: TList<string>);
begin
  Lines.Add(BlankLine);
  Lines.Add('Skipped by reason (the feature entries are the roadmap)');
  for var Reason in TopSkipReasons do
  begin
    Lines.Add(Format(ListLineFormat, [Reason.Value, Reason.Key]));
  end;
end;

procedure TConformanceReport.AppendGroups(const Lines: TList<string>);
begin
  Lines.Add(BlankLine);
  Lines.Add(Format('%-48s %7s %7s %7s %7s %7s %8s', ['Directory', 'Found', 'Skipped', 'Run', 'Passed', 'Failed', 'Rate']));
  for var Group in SortedKeys<TGroupStats>(FGroups) do
  begin
    const Stats = FGroups[Group];
    Lines.Add(Format('%-48s %7d %7d %7d %7d %7d %8s',
                     [Group, Stats.Found, Stats.Skipped, Stats.Run, Stats.Passed, Stats.Failed + Stats.Limit,
                      FormatRate(Stats.Passed, Stats.Run)]));
  end;
end;

procedure TConformanceReport.AppendClusters(const Lines: TList<string>);
begin
  Lines.Add(BlankLine);
  Lines.Add(Format('Top %d failure clusters (directory | error), with one example each', [ClusterCount]));
  for var Cluster in TopClusters(ClusterCount) do
  begin
    Lines.Add(Format('  %6d  %s', [Cluster.Count, Cluster.Key]));
    Lines.Add(Format('          e.g. %s', [Cluster.Example]));
  end;
end;

procedure TConformanceReport.AppendRunFeatures(const Lines: TList<string>);
begin
  Lines.Add(BlankLine);
  Lines.Add('Feature tags on tests that ran (candidates for the exclusion list)');
  var Printed := 0;
  const HasNoFeatures = (FRunFeatures.Count = 0);
  if HasNoFeatures then
    Lines.Add('  (none)');

  for var Feature in TopRunFeatures do
  begin
    const IsListFull = (Printed >= TopListCount);
    if IsListFull then
      Break;

    Lines.Add(Format(ListLineFormat, [Feature.Value, Feature.Key]));
    Inc(Printed);
  end;
end;

procedure TConformanceReport.SaveTo(const Directory: string);
begin
  TDirectory.CreateDirectory(Directory);
  TFile.WriteAllText(TPath.Combine(Directory, SummaryFileName), BuildSummary, TEncoding.UTF8);
  TFile.WriteAllLines(TPath.Combine(Directory, FailuresFileName), FFailureLines.ToArray, TEncoding.UTF8);
  TFile.WriteAllLines(TPath.Combine(Directory, PassedFileName), SortedPassedLines, TEncoding.UTF8);
end;

end.
