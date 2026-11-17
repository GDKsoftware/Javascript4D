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
    FTest262Directory: string;
    FExclusionsFile: string;
    FPathExclusionsFile: string;
    FResultsDirectory: string;
    FPathFilter: string;
    FLimits: TSessionLimits;

    function FindConformanceDirectory: string;
    function ReadPathOption(const Name: string; const ConformanceDirectory: string;
                            const DefaultFileName: string): string;
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
  OPTION_PREFIX = '-';
  OPTION_SEPARATOR = '=';
  TEST262_OPTION = 'test262';
  EXCLUSIONS_OPTION = 'exclusions';
  PATH_EXCLUSIONS_OPTION = 'path-exclusions';
  RESULTS_OPTION = 'results';
  FILTER_OPTION = 'filter';
  BUDGET_OPTION = 'budget';
  EXCLUSIONS_FILE_NAME = 'exclusions.txt';
  PATH_EXCLUSIONS_FILE_NAME = 'excluded-paths.txt';
  TEST262_FOLDER_NAME = 'test262';
  RESULTS_FOLDER_NAME = 'results';
  TEST_FOLDER_NAME = 'test';
  HARNESS_FOLDER_NAME = 'harness';
  DEFAULT_ROOTS: array[0..1] of string = ('language', 'built-ins');

constructor TConformanceOptions.Create;
begin
  inherited Create;
  const ConformanceDirectory = FindConformanceDirectory;

  FTest262Directory := ReadPathOption(TEST262_OPTION, ConformanceDirectory, TEST262_FOLDER_NAME);
  FExclusionsFile := ReadPathOption(EXCLUSIONS_OPTION, ConformanceDirectory, EXCLUSIONS_FILE_NAME);
  FPathExclusionsFile := ReadPathOption(PATH_EXCLUSIONS_OPTION, ConformanceDirectory, PATH_EXCLUSIONS_FILE_NAME);
  FResultsDirectory := ReadPathOption(RESULTS_OPTION, ConformanceDirectory, RESULTS_FOLDER_NAME);
  FPathFilter := ReadOption(FILTER_OPTION).Replace(BACKSLASH, PATH_SEPARATOR);

  FLimits.StepBudget := ReadInt64Option(BUDGET_OPTION, DEFAULT_STEP_BUDGET);
  FLimits.MaxCallDepth := DEFAULT_MAX_CALL_DEPTH;
  FLimits.MaxStringLength := DEFAULT_MAX_STRING_LENGTH;
  FLimits.MaxArrayLength := UNLIMITED_ARRAY_LENGTH;
end;

function TConformanceOptions.TestDirectory: string;
begin
  Result := TPath.Combine(FTest262Directory, TEST_FOLDER_NAME);
end;

function TConformanceOptions.HarnessDirectory: string;
begin
  Result := TPath.Combine(FTest262Directory, HARNESS_FOLDER_NAME);
end;

function TConformanceOptions.SearchRoots: TArray<string>;
begin
  Result := [];
  for var Root in DEFAULT_ROOTS do
  begin
    const RootDirectory = TPath.Combine(TestDirectory, Root);
    Result := Result + [RootDirectory];
  end;
end;

function TConformanceOptions.FindConformanceDirectory: string;
begin
  var Candidate := TPath.GetDirectoryName(ParamStr(0));
  while not Candidate.IsEmpty do
  begin
    const MarkerPath = TPath.Combine(Candidate, EXCLUSIONS_FILE_NAME);
    if TFile.Exists(MarkerPath) then
      Exit(Candidate);

    Candidate := TPath.GetDirectoryName(Candidate);
  end;

  raise EConformanceError.CreateFmt('Cannot find %s above %s', [EXCLUSIONS_FILE_NAME, ParamStr(0)]);
end;

function TConformanceOptions.ReadOption(const Name: string): string;
begin
  const Prefix = Format('%s%s%s', [OPTION_PREFIX, Name, OPTION_SEPARATOR]);
  for var Index := 1 to ParamCount do
  begin
    const Argument = ParamStr(Index);
    if Argument.StartsWith(Prefix, True) then
    begin
      Result := Argument.Substring(Prefix.Length);
      Exit;
    end;
  end;

  Result := '';
end;

function TConformanceOptions.ReadPathOption(const Name: string; const ConformanceDirectory: string;
                                            const DefaultFileName: string): string;
begin
  Result := ReadOption(Name);
  if Result.IsEmpty then
    Result := TPath.Combine(ConformanceDirectory, DefaultFileName);
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
