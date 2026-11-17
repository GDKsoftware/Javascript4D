unit JS4D.Conformance.ReportFormatter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Conformance.Report;

type
  TReportFormatter = class
  private
    class function FormatRate(const Passed: Integer; const RunCount: Integer): string; static;
    class function Truncated<T>(const Items: TArray<T>; const MaxCount: Integer): TArray<T>; static;

    class procedure AddLine(const Lines: TList<string>; const Pattern: string; const Args: array of const); static;
    class procedure AppendTotals(const Lines: TList<string>; const Report: TConformanceReport); static;
    class procedure AppendSkipReasons(const Lines: TList<string>; const Report: TConformanceReport); static;
    class procedure AppendGroups(const Lines: TList<string>; const Report: TConformanceReport); static;
    class procedure AppendClusters(const Lines: TList<string>; const Report: TConformanceReport); static;
    class procedure AppendRunFeatures(const Lines: TList<string>; const Report: TConformanceReport); static;

  public
    class function BuildSummary(const Report: TConformanceReport): string; static;
  end;

implementation

uses
  JS4D.Conformance.Defines;

const
  CLUSTER_COUNT = 15;
  TOP_LIST_COUNT = 40;
  LIST_LINE_FORMAT = '  %7d  %s';
  GROUP_HEADER_FORMAT = '%-48s %7s %7s %7s %7s %7s %8s';
  GROUP_ROW_FORMAT = '%-48s %7d %7d %7d %7d %7d %8s';
  CLUSTER_LINE_FORMAT = '  %6d  %s';
  CLUSTER_EXAMPLE_FORMAT = '          e.g. %s';
  NO_RUNS_RATE = '    n/a';
  RATE_FORMAT = '%6.1f%%';

class function TReportFormatter.BuildSummary(const Report: TConformanceReport): string;
begin
  const Lines = TList<string>.Create;
  try
    AppendTotals(Lines, Report);
    AppendSkipReasons(Lines, Report);
    AppendGroups(Lines, Report);
    AppendClusters(Lines, Report);
    AppendRunFeatures(Lines, Report);
    Result := string.Join(sLineBreak, Lines.ToArray);
  finally
    Lines.Free;
  end;
end;

class procedure TReportFormatter.AddLine(const Lines: TList<string>; const Pattern: string;
                                         const Args: array of const);
begin
  const Line = Format(Pattern, Args, TFormatSettings.Invariant);
  Lines.Add(Line);
end;

class function TReportFormatter.FormatRate(const Passed: Integer; const RunCount: Integer): string;
begin
  const HasNoRuns = (RunCount = 0);
  if HasNoRuns then
    Exit(NO_RUNS_RATE);

  Result := Format(RATE_FORMAT, [Passed * 100.0 / RunCount], TFormatSettings.Invariant);
end;

class function TReportFormatter.Truncated<T>(const Items: TArray<T>; const MaxCount: Integer): TArray<T>;
begin
  Result := Items;
  const HasSurplus = (Length(Result) > MaxCount);
  if HasSurplus then
    SetLength(Result, MaxCount);
end;

class procedure TReportFormatter.AppendTotals(const Lines: TList<string>; const Report: TConformanceReport);
begin
  const Sum = Report.Totals;
  const FailedCount = Sum.Failed + Sum.Limit;
  const PassRate = FormatRate(Sum.Passed, Sum.RunCount).Trim;
  const SloppyRun = Report.VariantRunCount(TTestVariant.Sloppy);
  const SloppyPassed = Report.VariantPassedCount(TTestVariant.Sloppy);
  const StrictRun = Report.VariantRunCount(TTestVariant.Strict);
  const StrictPassed = Report.VariantPassedCount(TTestVariant.Strict);
  const Seconds = Report.DurationMs / 1000;

  Lines.Add('test262 conformance baseline');
  Lines.Add('');
  AddLine(Lines, 'Found tests : %d', [Sum.Found]);
  AddLine(Lines, 'Skipped     : %d', [Sum.Skipped]);
  AddLine(Lines, 'Run         : %d', [Sum.RunCount]);
  AddLine(Lines, '  Passed    : %d', [Sum.Passed]);
  AddLine(Lines, '  Failed    : %d (of which step budget or limit exceeded: %d)', [FailedCount, Sum.Limit]);
  AddLine(Lines, 'Pass rate   : %s of the tests that ran', [PassRate]);
  AddLine(Lines, 'Variants    : sloppy %d of %d passed, strict %d of %d passed',
          [SloppyPassed, SloppyRun, StrictPassed, StrictRun]);
  AddLine(Lines, 'Duration    : %.1f seconds', [Seconds]);
end;

class procedure TReportFormatter.AppendSkipReasons(const Lines: TList<string>; const Report: TConformanceReport);
begin
  Lines.Add('');
  Lines.Add('Skipped by reason (the feature entries are the roadmap)');
  for var Reason in Report.SkipReasons do
  begin
    AddLine(Lines, LIST_LINE_FORMAT, [Reason.Value, Reason.Key]);
  end;
end;

class procedure TReportFormatter.AppendGroups(const Lines: TList<string>; const Report: TConformanceReport);
begin
  Lines.Add('');
  AddLine(Lines, GROUP_HEADER_FORMAT, ['Directory', 'Found', 'Skipped', 'Run', 'Passed', 'Failed', 'Rate']);
  for var Group in Report.SortedGroups do
  begin
    const Stats = Group.Value;
    const Rate = FormatRate(Stats.Passed, Stats.RunCount);
    const FailedCount = Stats.Failed + Stats.Limit;
    AddLine(Lines, GROUP_ROW_FORMAT,
            [Group.Key, Stats.Found, Stats.Skipped, Stats.RunCount, Stats.Passed, FailedCount, Rate]);
  end;
end;

class procedure TReportFormatter.AppendClusters(const Lines: TList<string>; const Report: TConformanceReport);
begin
  Lines.Add('');
  AddLine(Lines, 'Top %d failure clusters (directory | error), with one example each', [CLUSTER_COUNT]);
  const Clusters = Truncated<TFailureCluster>(Report.SortedClusters, CLUSTER_COUNT);
  for var Cluster in Clusters do
  begin
    AddLine(Lines, CLUSTER_LINE_FORMAT, [Cluster.Count, Cluster.Key]);
    AddLine(Lines, CLUSTER_EXAMPLE_FORMAT, [Cluster.Example]);
  end;
end;

class procedure TReportFormatter.AppendRunFeatures(const Lines: TList<string>; const Report: TConformanceReport);
begin
  Lines.Add('');
  Lines.Add('Feature tags on tests that ran (candidates for the exclusion list)');
  const Features = Report.RunFeatures;
  const HasNoFeatures = (Length(Features) = 0);
  if HasNoFeatures then
    Lines.Add('  (none)');

  const TopFeatures = Truncated<TPair<string, Integer>>(Features, TOP_LIST_COUNT);
  for var Feature in TopFeatures do
  begin
    AddLine(Lines, LIST_LINE_FORMAT, [Feature.Value, Feature.Key]);
  end;
end;

end.
