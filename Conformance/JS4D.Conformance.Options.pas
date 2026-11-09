unit JS4D.Conformance.Options;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  JS4D.Conformance.Defines;

type
  TConformanceOptions = class
  private
    FConformanceDirectory: string;
    FTest262Directory: string;
    FExclusionsFile: string;
    FPathExclusionsFile: string;
    FResultsDirectory: string;
    FPathFilter: string;
    FLimits: TSessionLimits;

    function FindConformanceDirectory: string;
    function ReadOption(const Name: string): string;
    function ReadInt64Option(const Name: string; const DefaultValue: Int64): Int64;

  public
    constructor Create;

    function TestDirectory: string;
    function HarnessDirectory: string;
    function SearchRoots: TArray<string>;

    property Test262Directory: string read FTest262Directory;
    property ExclusionsFile: string read FExclusionsFile;
    property PathExclusionsFile: string read FPathExclusionsFile;
    property ResultsDirectory: string read FResultsDirectory;
    property PathFilter: string read FPathFilter;
    property Limits: TSessionLimits read FLimits;
  end;

implementation

const
  OptionPrefix = '-';
  OptionSeparator = '=';
  Test262Option = 'test262';
  ExclusionsOption = 'exclusions';
  PathExclusionsOption = 'path-exclusions';
  ResultsOption = 'results';
  FilterOption = 'filter';
  BudgetOption = 'budget';
  ExclusionsFileName = 'exclusions.txt';
  PathExclusionsFileName = 'excluded-paths.txt';
  Test262FolderName = 'test262';
  ResultsFolderName = 'results';
  TestFolderName = 'test';
  HarnessFolderName = 'harness';
  DefaultRoots: array[0..1] of string = ('language', 'built-ins');
  MaxLevelsUp = 6;

constructor TConformanceOptions.Create;
begin
  inherited Create;
  FConformanceDirectory := FindConformanceDirectory;

  FTest262Directory := ReadOption(Test262Option);
  if FTest262Directory.IsEmpty then
    FTest262Directory := TPath.Combine(FConformanceDirectory, Test262FolderName);

  FExclusionsFile := ReadOption(ExclusionsOption);
  if FExclusionsFile.IsEmpty then
    FExclusionsFile := TPath.Combine(FConformanceDirectory, ExclusionsFileName);

  FPathExclusionsFile := ReadOption(PathExclusionsOption);
  if FPathExclusionsFile.IsEmpty then
    FPathExclusionsFile := TPath.Combine(FConformanceDirectory, PathExclusionsFileName);

  FResultsDirectory := ReadOption(ResultsOption);
  if FResultsDirectory.IsEmpty then
    FResultsDirectory := TPath.Combine(FConformanceDirectory, ResultsFolderName);

  FPathFilter := ReadOption(FilterOption).Replace('\', '/');

  FLimits.StepBudget := ReadInt64Option(BudgetOption, DefaultStepBudget);
  FLimits.MaxCallDepth := DefaultMaxCallDepth;
  FLimits.MaxStringLength := DefaultMaxStringLength;
  FLimits.MaxArrayLength := DefaultMaxArrayLength;
end;

function TConformanceOptions.TestDirectory: string;
begin
  Result := TPath.Combine(FTest262Directory, TestFolderName);
end;

function TConformanceOptions.HarnessDirectory: string;
begin
  Result := TPath.Combine(FTest262Directory, HarnessFolderName);
end;

function TConformanceOptions.SearchRoots: TArray<string>;
begin
  SetLength(Result, Length(DefaultRoots));
  for var Index := 0 to High(DefaultRoots) do
  begin
    Result[Index] := TPath.Combine(TestDirectory, DefaultRoots[Index]);
  end;
end;

function TConformanceOptions.FindConformanceDirectory: string;
begin
  var Candidate := TPath.GetDirectoryName(ParamStr(0));
  for var Level := 0 to MaxLevelsUp do
  begin
    const MarkerPath = TPath.Combine(Candidate, ExclusionsFileName);
    if TFile.Exists(MarkerPath) then
      Exit(Candidate);

    Candidate := TPath.GetDirectoryName(Candidate);
  end;

  raise EConformanceError.CreateFmt('Cannot find %s above %s', [ExclusionsFileName, ParamStr(0)]);
end;

function TConformanceOptions.ReadOption(const Name: string): string;
begin
  const Prefix = Format('%s%s%s', [OptionPrefix, Name, OptionSeparator]);
  for var Index := 1 to ParamCount do
  begin
    if ParamStr(Index).StartsWith(Prefix, True) then
      Exit(ParamStr(Index).Substring(Prefix.Length));
  end;

  Result := '';
end;

function TConformanceOptions.ReadInt64Option(const Name: string; const DefaultValue: Int64): Int64;
begin
  const Text = ReadOption(Name);
  if Text.IsEmpty then
    Exit(DefaultValue);

  if not TryStrToInt64(Text, Result) then
    raise EConformanceError.CreateFmt('Option %s needs a whole number, got "%s"', [Name, Text]);
end;

end.
