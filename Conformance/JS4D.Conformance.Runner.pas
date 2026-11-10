unit JS4D.Conformance.Runner;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Diagnostics,
  System.Generics.Collections,
  JS4D.Conformance.Defines,
  JS4D.Conformance.Options,
  JS4D.Conformance.TestCase,
  JS4D.Conformance.Exclusions,
  JS4D.Conformance.PathExclusions,
  JS4D.Conformance.Harness,
  JS4D.Conformance.Selector,
  JS4D.Conformance.TestExecutor,
  JS4D.Conformance.Report;

type
  TConformanceRunner = class
  private
    FOptions: TConformanceOptions;
    FExclusions: TExclusionList;
    FPathExclusions: TPathExclusionList;
    FHarness: THarnessLibrary;
    FSelector: TTestSelector;
    FExecutor: TTestExecutor;
    FReport: TConformanceReport;

    function CollectTestFiles: TArray<string>;
    function ToRelativePath(const FilePath: string): string;
    function MatchesFilter(const RelativePath: string): Boolean;
    function RunVariants(const TestCase: TTestCase): TArray<TVariantResult>;

    procedure ProcessFile(const FilePath: string);
    procedure ReportProgress(const Processed: Integer; const Total: Integer);

  public
    constructor Create(const Options: TConformanceOptions);
    destructor Destroy; override;

    procedure Run;

    property Report: TConformanceReport read FReport;
  end;

implementation

const
  JavaScriptPattern = '*.js';
  DirectorySeparator = '/';

constructor TConformanceRunner.Create(const Options: TConformanceOptions);
begin
  inherited Create;
  FOptions := Options;
  FExclusions := TExclusionList.Create(Options.ExclusionsFile);
  FPathExclusions := TPathExclusionList.Create(Options.PathExclusionsFile);
  FHarness := THarnessLibrary.Create(Options.HarnessDirectory, Options.Limits);
  FSelector := TTestSelector.Create(FExclusions, FPathExclusions);
  FExecutor := TTestExecutor.Create(FHarness, Options.Limits);
  FReport := TConformanceReport.Create;
end;

destructor TConformanceRunner.Destroy;
begin
  FReport.Free;
  FExecutor.Free;
  FSelector.Free;
  FHarness.Free;
  FPathExclusions.Free;
  FExclusions.Free;
  inherited;
end;

procedure TConformanceRunner.Run;
begin
  const Stopwatch = TStopwatch.StartNew;
  const Files = CollectTestFiles;

  for var Index := 0 to High(Files) do
  begin
    ProcessFile(Files[Index]);
    ReportProgress(Index + 1, Length(Files));
  end;

  FReport.DurationMs := Stopwatch.ElapsedMilliseconds;
end;

function TConformanceRunner.CollectTestFiles: TArray<string>;
begin
  var Roots := FOptions.SearchRoots;
  const HasFilter = not FOptions.PathFilter.IsEmpty;
  if HasFilter then
    Roots := [FOptions.TestDirectory];

  const Files = TList<string>.Create;
  try
    for var Root in Roots do
    begin
      for var FilePath in TDirectory.GetFiles(Root, JavaScriptPattern, TSearchOption.soAllDirectories) do
      begin
        if MatchesFilter(ToRelativePath(FilePath)) then
          Files.Add(FilePath);
      end;
    end;

    Files.Sort;
    Result := Files.ToArray;
  finally
    Files.Free;
  end;
end;

function TConformanceRunner.ToRelativePath(const FilePath: string): string;
begin
  const Prefix = IncludeTrailingPathDelimiter(FOptions.TestDirectory);
  Result := FilePath.Substring(Prefix.Length).Replace('\', DirectorySeparator);
end;

function TConformanceRunner.MatchesFilter(const RelativePath: string): Boolean;
begin
  const Filter = FOptions.PathFilter;
  Result := Filter.IsEmpty or RelativePath.StartsWith(Filter, True);
end;

procedure TConformanceRunner.ProcessFile(const FilePath: string);
begin
  const TestCase = TTestCase.Create(FilePath, ToRelativePath(FilePath));
  try
    var SkipReason: string;
    const IsSkipped = FSelector.TryGetSkipReason(TestCase, SkipReason);
    if IsSkipped then
    begin
      FReport.RecordSkipped(TestCase, SkipReason);
    end
    else
    begin
      const Results = RunVariants(TestCase);
      FReport.RecordRun(TestCase, Results);
    end;
  finally
    TestCase.Free;
  end;
end;

function TConformanceRunner.RunVariants(const TestCase: TTestCase): TArray<TVariantResult>;
begin
  const Variants = TTestExecutor.VariantsOf(TestCase);
  SetLength(Result, Length(Variants));
  for var Index := 0 to High(Variants) do
  begin
    Result[Index] := FExecutor.Run(TestCase, Variants[Index]);
  end;
end;

procedure TConformanceRunner.ReportProgress(const Processed: Integer; const Total: Integer);
begin
  const IsMilestone = (Processed mod ProgressInterval = 0) or (Processed = Total);
  if IsMilestone then
  begin
    const Message = Format('Processed %d of %d test files', [Processed, Total]);
    Writeln(Message);
  end;
end;

end.
