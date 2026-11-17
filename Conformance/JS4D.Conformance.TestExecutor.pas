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

    function WithStrictPrefix(const Source: string; const Variant: TTestVariant): string;
    function TryParse(const Source: string; out Failure: TObservedError): Boolean;
    function JudgeParseFailure(const TestCase: TTestCase; const Failure: TObservedError): TVariantResult;
    function ExecuteInFreshSession(const TestCase: TTestCase;
                                   const Variant: TTestVariant;
                                   const Source: string): TVariantResult;
    function TryLoadHarness(const Session: TTestSession;
                            const TestCase: TTestCase;
                            const Variant: TTestVariant;
                            out Detail: string): Boolean;
    function HarnessSource(const FileName: string; const Variant: TTestVariant): string;
    function PassedResult: TVariantResult;
    function CreateEngineFaultResult(const Observed: TObservedError): TVariantResult;
    function RunTestSource(const Session: TTestSession;
                           const TestCase: TTestCase;
                           const Source: string): TVariantResult;
    function JudgeFinished(const Session: TTestSession; const TestCase: TTestCase): TVariantResult;
    function IsAsyncTest(const TestCase: TTestCase): Boolean;
    function JudgeCompletion(const TestCase: TTestCase): TVariantResult;
    function JudgeAsyncCompletion(const Session: TTestSession): TVariantResult;
    function JudgeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
    function JudgeNegativeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
    function CreateResult(const Outcome: TTestOutcome; const Detail: string): TVariantResult;
    function DescribeError(const Observed: TObservedError): string;

  public
    constructor Create(const Harness: THarnessLibrary; const Limits: TSessionLimits);

    function Run(const TestCase: TTestCase; const Variant: TTestVariant): TVariantResult;

    class function VariantsOf(const TestCase: TTestCase): TArray<TTestVariant>; static;
  end;

implementation

uses
  System.Math,
  JS4D.Errors,
  JS4D.Parser,
  JS4D.Conformance.ErrorObserver;

const
  RAW_FLAG = 'raw';
  ASYNC_FLAG = 'async';
  DONE_PRINT_HANDLE_FILE = 'doneprintHandle.js';
  ASYNC_COMPLETE_MESSAGE = 'Test262:AsyncTestComplete';
  ASYNC_FAILURE_PREFIX = 'Test262:AsyncTestFailure:';
  ASYNC_NOT_SIGNALLED_DETAIL = 'async test did not report completion';
  NO_STRICT_FLAG = 'noStrict';
  ONLY_STRICT_FLAG = 'onlyStrict';
  MAX_DETAIL_LENGTH = 160;
  ENGINE_FAULT_FORMAT = 'engine fault %s';
  HARNESS_LOAD_FORMAT = 'harness load: %s';
  UNEXPECTED_PARSE_FORMAT = 'expected parse %s, got %s';
  COMPLETED_NORMALLY_FORMAT = 'expected %s but the test completed normally';
  UNEXPECTED_RUNTIME_FORMAT = 'expected %s, got %s';
  PROGRAM_ACCEPTED_FORMAT = 'program accepted although parse %s was expected; runtime threw %s';
  DESCRIPTION_FORMAT = '%s: %s';

constructor TTestExecutor.Create(const Harness: THarnessLibrary; const Limits: TSessionLimits);
begin
  inherited Create;
  FHarness := Harness;
  FLimits := Limits;
end;

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

function TTestExecutor.Run(const TestCase: TTestCase; const Variant: TTestVariant): TVariantResult;
begin
  const Source = WithStrictPrefix(TestCase.Source, Variant);

  var ParseFailure: TObservedError;
  const ParseFailed = not TryParse(Source, ParseFailure);
  if ParseFailed then
    Result := JudgeParseFailure(TestCase, ParseFailure)
  else
    Result := ExecuteInFreshSession(TestCase, Variant, Source);

  Result.Variant := Variant;
end;

function TTestExecutor.WithStrictPrefix(const Source: string; const Variant: TTestVariant): string;
begin
  const IsStrictVariant = (Variant = TTestVariant.Strict);
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

function TTestExecutor.JudgeParseFailure(const TestCase: TTestCase; const Failure: TObservedError): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  const Description = DescribeError(Failure);
  const ExpectsParseError = Metadata.IsNegative and (Metadata.NegativePhase = TErrorPhase.Parse);
  const IsExpectedType = (Failure.Name = Metadata.NegativeType);
  if Failure.IsEngineFault then
  begin
    Result := CreateEngineFaultResult(Failure);
  end
  else if not ExpectsParseError then
  begin
    Result := CreateResult(TTestOutcome.Failed, Description);
  end
  else if IsExpectedType then
  begin
    Result := PassedResult;
  end
  else
  begin
    Result := CreateResult(TTestOutcome.Failed, Format(UNEXPECTED_PARSE_FORMAT, [Metadata.NegativeType, Description]));
  end;
end;

function TTestExecutor.CreateEngineFaultResult(const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  Result := CreateResult(TTestOutcome.Failed, Format(ENGINE_FAULT_FORMAT, [Description]));
end;

function TTestExecutor.ExecuteInFreshSession(const TestCase: TTestCase;
                                             const Variant: TTestVariant;
                                             const Source: string): TVariantResult;
begin
  const Session = TTestSession.Create(FLimits);
  try
    var HarnessFailure: string;
    const HarnessFailed = not TryLoadHarness(Session, TestCase, Variant, HarnessFailure);
    if HarnessFailed then
    begin
      Result := CreateResult(TTestOutcome.Failed, HarnessFailure);
    end
    else
    begin
      Result := RunTestSource(Session, TestCase, Source);
    end;
  finally
    Session.Free;
  end;
end;

function TTestExecutor.HarnessSource(const FileName: string; const Variant: TTestVariant): string;
begin
  const Source = FHarness.ReadSource(FileName);
  Result := WithStrictPrefix(Source, Variant);
end;

function TTestExecutor.PassedResult: TVariantResult;
begin
  Result := CreateResult(TTestOutcome.Passed, '');
end;

function TTestExecutor.TryLoadHarness(const Session: TTestSession;
                                      const TestCase: TTestCase;
                                      const Variant: TTestVariant;
                                      out Detail: string): Boolean;
begin
  Detail := '';
  Result := True;
  if TestCase.Metadata.HasFlag(RAW_FLAG) then
    Exit;

  try
    for var BaseFile in THarnessLibrary.BaseFiles do
    begin
      Session.Run(HarnessSource(BaseFile, Variant));
    end;

    if IsAsyncTest(TestCase) then
      Session.Run(HarnessSource(DONE_PRINT_HANDLE_FILE, Variant));

    for var IncludeFile in TestCase.Metadata.Includes do
    begin
      Session.Run(HarnessSource(IncludeFile, Variant));
    end;

  except
    on E: Exception do
    begin
      const Observed = TErrorObserver.Observe(E);
      const Description = DescribeError(Observed);
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
      Result := JudgeError(TestCase, Observed);
      Exit;
    end;
  end;

  Result := JudgeFinished(Session, TestCase);
end;

function TTestExecutor.JudgeFinished(const Session: TTestSession; const TestCase: TTestCase): TVariantResult;
begin
  if IsAsyncTest(TestCase) then
  begin
    Result := JudgeAsyncCompletion(Session);
  end
  else
  begin
    Result := JudgeCompletion(TestCase);
  end;
end;

function TTestExecutor.IsAsyncTest(const TestCase: TTestCase): Boolean;
begin
  Result := TestCase.Metadata.HasFlag(ASYNC_FLAG);
end;

function TTestExecutor.JudgeCompletion(const TestCase: TTestCase): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  if Metadata.IsNegative then
  begin
    Result := CreateResult(TTestOutcome.Failed, Format(COMPLETED_NORMALLY_FORMAT, [Metadata.NegativeType]));
  end
  else
  begin
    Result := PassedResult;
  end;
end;

function TTestExecutor.JudgeAsyncCompletion(const Session: TTestSession): TVariantResult;
begin
  for var Line in Session.Printed do
  begin
    const IsCompletion = (Line = ASYNC_COMPLETE_MESSAGE);
    if IsCompletion then
    begin
      Result := PassedResult;
      Exit;
    end;

    const IsFailure = Line.StartsWith(ASYNC_FAILURE_PREFIX);
    if IsFailure then
    begin
      const Offset = Length(ASYNC_FAILURE_PREFIX);
      const Detail = Line.Substring(Offset).Trim;
      Result := CreateResult(TTestOutcome.Failed, Detail);
      Exit;
    end;
  end;

  Result := CreateResult(TTestOutcome.Failed, ASYNC_NOT_SIGNALLED_DETAIL);
end;

function TTestExecutor.JudgeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  if Observed.IsLimit then
  begin
    Result := CreateResult(TTestOutcome.Limit, Description);
  end
  else if Observed.IsEngineFault then
  begin
    Result := CreateEngineFaultResult(Observed);
  end
  else if TestCase.Metadata.IsNegative then
  begin
    Result := JudgeNegativeError(TestCase, Observed);
  end
  else
  begin
    Result := CreateResult(TTestOutcome.Failed, Description);
  end;
end;

function TTestExecutor.JudgeNegativeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  const Description = DescribeError(Observed);
  const ExpectsRuntimeError = (Metadata.NegativePhase = TErrorPhase.Runtime);
  const IsExpectedType = (Observed.Name = Metadata.NegativeType);
  if ExpectsRuntimeError and IsExpectedType then
  begin
    Result := PassedResult;
  end
  else if ExpectsRuntimeError then
  begin
    Result := CreateResult(TTestOutcome.Failed, Format(UNEXPECTED_RUNTIME_FORMAT, [Metadata.NegativeType, Description]));
  end
  else
  begin
    Result := CreateResult(TTestOutcome.Failed, Format(PROGRAM_ACCEPTED_FORMAT, [Metadata.NegativeType, Description]));
  end;
end;

function TTestExecutor.CreateResult(const Outcome: TTestOutcome; const Detail: string): TVariantResult;
begin
  Result.Outcome := Outcome;
  Result.Detail := Detail;
end;

function TTestExecutor.DescribeError(const Observed: TObservedError): string;
begin
  const Flattened = Observed.Message.Replace(#13, ' ').Replace(#10, ' ');
  const Shortened = Flattened.Substring(0, Min(Flattened.Length, MAX_DETAIL_LENGTH));
  Result := Format(DESCRIPTION_FORMAT, [Observed.Name, Shortened]);
end;

end.
