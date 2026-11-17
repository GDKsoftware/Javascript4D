unit JS4D.Conformance.TestExecutor;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase,
  JS4D.Conformance.Harness,
  JS4D.Conformance.Session;

type
  TTestExecutor = class
  private
    FHarness: THarnessLibrary;
    FLimits: TSessionLimits;

    function WithStrictPrefix(const Source: string; const TestVariant: TTestVariant): string;
    function TryParse(const Source: string; out Failure: TObservedError): Boolean;
    function ExecuteInFreshSession(const TestCase: TTestCase;
                                   const TestVariant: TTestVariant;
                                   const Source: string): TVariantResult;
    function TryLoadHarness(const Session: TTestSession;
                            const TestCase: TTestCase;
                            const TestVariant: TTestVariant;
                            out Detail: string): Boolean;
    function HarnessSource(const FileName: string; const TestVariant: TTestVariant): string;
    function RunTestSource(const Session: TTestSession;
                           const TestCase: TTestCase;
                           const Source: string): TVariantResult;
    function JudgeFinished(const Session: TTestSession; const TestCase: TTestCase): TVariantResult;

  public
    class function VariantsOf(const TestCase: TTestCase): TArray<TTestVariant>; static;

    constructor Create(const Harness: THarnessLibrary; const Limits: TSessionLimits);

    function Run(const TestCase: TTestCase; const TestVariant: TTestVariant): TVariantResult;
  end;

implementation

uses
  JS4D.Parser,
  JS4D.Conformance.ErrorObserver,
  JS4D.Conformance.VerdictJudge;

const
  RAW_FLAG = 'raw';
  DONE_PRINT_HANDLE_FILE = 'doneprintHandle.js';
  NO_STRICT_FLAG = 'noStrict';
  ONLY_STRICT_FLAG = 'onlyStrict';
  HARNESS_LOAD_FORMAT = 'harness load: %s';

class function TTestExecutor.VariantsOf(const TestCase: TTestCase): TArray<TTestVariant>;
begin
  const Metadata = TestCase.Metadata;
  const RunsStrictOnly = Metadata.HasFlag(ONLY_STRICT_FLAG);
  const RunsSloppyOnly = Metadata.HasFlag(NO_STRICT_FLAG) or Metadata.HasFlag(RAW_FLAG);
  if RunsStrictOnly then
  begin
    Result := [TTestVariant.Strict];
  end
  else if RunsSloppyOnly then
  begin
    Result := [TTestVariant.Sloppy];
  end
  else
  begin
    Result := [TTestVariant.Sloppy, TTestVariant.Strict];
  end;
end;

constructor TTestExecutor.Create(const Harness: THarnessLibrary; const Limits: TSessionLimits);
begin
  inherited Create;
  FHarness := Harness;
  FLimits := Limits;
end;

function TTestExecutor.Run(const TestCase: TTestCase; const TestVariant: TTestVariant): TVariantResult;
begin
  const Source = WithStrictPrefix(TestCase.Source, TestVariant);

  var ParseFailure: TObservedError;
  const ParseFailed = not TryParse(Source, ParseFailure);
  if ParseFailed then
    Result := TVerdictJudge.JudgeParseFailure(TestCase, ParseFailure)
  else
    Result := ExecuteInFreshSession(TestCase, TestVariant, Source);

  Result.TestVariant := TestVariant;
end;

function TTestExecutor.WithStrictPrefix(const Source: string; const TestVariant: TTestVariant): string;
begin
  const IsStrictVariant = (TestVariant = TTestVariant.Strict);
  if IsStrictVariant then
  begin
    Result := STRICT_PREFIX + Source;
  end
  else
  begin
    Result := Source;
  end;
end;

function TTestExecutor.TryParse(const Source: string; out Failure: TObservedError): Boolean;
begin
  var Parser: TJSParser := nil;
  try
    try
      Parser := TJSParser.Create(Source);
      const Tree = Parser.Parse;
      Tree.Free;
      Result := True;
    except
      on E: Exception do
      begin
        Failure := TErrorObserver.Observe(E);
        Result := False;
      end;
    end;
  finally
    Parser.Free;
  end;
end;

function TTestExecutor.ExecuteInFreshSession(const TestCase: TTestCase;
                                             const TestVariant: TTestVariant;
                                             const Source: string): TVariantResult;
begin
  const Session = TTestSession.Create(FLimits);
  try
    var HarnessFailure: string;
    const HarnessFailed = not TryLoadHarness(Session, TestCase, TestVariant, HarnessFailure);
    if HarnessFailed then
    begin
      Result := TVerdictJudge.CreateResult(TTestOutcome.Failed, HarnessFailure);
    end
    else
    begin
      Result := RunTestSource(Session, TestCase, Source);
    end;
  finally
    Session.Free;
  end;
end;

function TTestExecutor.HarnessSource(const FileName: string; const TestVariant: TTestVariant): string;
begin
  const Source = FHarness.ReadSource(FileName);
  Result := WithStrictPrefix(Source, TestVariant);
end;

function TTestExecutor.TryLoadHarness(const Session: TTestSession;
                                      const TestCase: TTestCase;
                                      const TestVariant: TTestVariant;
                                      out Detail: string): Boolean;
begin
  Detail := '';
  Result := True;
  const Metadata = TestCase.Metadata;
  if Metadata.HasFlag(RAW_FLAG) then
    Exit;

  try
    for var BaseFile in THarnessLibrary.BaseFiles do
    begin
      const BaseSource = HarnessSource(BaseFile, TestVariant);
      Session.Run(BaseSource);
    end;

    if TestCase.IsAsync then
    begin
      const DoneSource = HarnessSource(DONE_PRINT_HANDLE_FILE, TestVariant);
      Session.Run(DoneSource);
    end;

    for var IncludeFile in Metadata.Includes do
    begin
      const IncludeSource = HarnessSource(IncludeFile, TestVariant);
      Session.Run(IncludeSource);
    end;

  except
    on E: Exception do
    begin
      const Observed = TErrorObserver.Observe(E);
      const Description = TVerdictJudge.DescribeError(Observed);
      Detail := Format(HARNESS_LOAD_FORMAT, [Description]);
      Result := False;
    end;
  end;
end;

function TTestExecutor.RunTestSource(const Session: TTestSession;
                                     const TestCase: TTestCase;
                                     const Source: string): TVariantResult;
begin
  try
    Session.Run(Source);
  except
    on E: Exception do
    begin
      const Observed = TErrorObserver.Observe(E);
      Result := TVerdictJudge.JudgeThrown(TestCase, Observed);
      Exit;
    end;
  end;

  Result := JudgeFinished(Session, TestCase);
end;

function TTestExecutor.JudgeFinished(const Session: TTestSession; const TestCase: TTestCase): TVariantResult;
begin
  if TestCase.IsAsync then
  begin
    Result := TVerdictJudge.JudgeAsyncCompletion(Session.Printed);
  end
  else
  begin
    Result := TVerdictJudge.JudgeCompletion(TestCase);
  end;
end;

end.
