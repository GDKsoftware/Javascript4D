unit JS4D.Conformance.TestExecutor;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Errors,
  JS4D.Parser,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase,
  JS4D.Conformance.Harness,
  JS4D.Conformance.Session,
  JS4D.Conformance.ErrorObserver;

type
  TTestExecutor = class
  private
    FHarness: THarnessLibrary;
    FLimits: TSessionLimits;

    function BuildSource(const TestCase: TTestCase; const Variant: TTestVariant): string;
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
    function CreateEngineFaultResult(const Observed: TObservedError): TVariantResult;
    function RunTestSource(const Session: TTestSession; const TestCase: TTestCase; const Source: string): TVariantResult;
    function JudgeCompletion(const TestCase: TTestCase): TVariantResult;
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

const
  RawFlag = 'raw';
  NoStrictFlag = 'noStrict';
  OnlyStrictFlag = 'onlyStrict';
  MaxDetailLength = 160;
  EngineFaultFormat = 'engine fault %s';
  HarnessLoadFormat = 'harness load: %s';

constructor TTestExecutor.Create(const Harness: THarnessLibrary; const Limits: TSessionLimits);
begin
  inherited Create;
  FHarness := Harness;
  FLimits := Limits;
end;

class function TTestExecutor.VariantsOf(const TestCase: TTestCase): TArray<TTestVariant>;
begin
  const Metadata = TestCase.Metadata;
  const RunsStrictOnly = Metadata.HasFlag(OnlyStrictFlag);
  const RunsSloppyOnly = Metadata.HasFlag(NoStrictFlag) or Metadata.HasFlag(RawFlag);
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
  const Source = BuildSource(TestCase, Variant);

  var ParseFailure: TObservedError;
  const ParseFailed = not TryParse(Source, ParseFailure);
  if ParseFailed then
    Result := JudgeParseFailure(TestCase, ParseFailure)
  else
    Result := ExecuteInFreshSession(TestCase, Variant, Source);

  Result.Variant := Variant;
end;

function TTestExecutor.BuildSource(const TestCase: TTestCase; const Variant: TTestVariant): string;
begin
  const IsStrictVariant = (Variant = TTestVariant.Strict);
  if IsStrictVariant then
    Result := StrictPrefix + TestCase.Source
  else
    Result := TestCase.Source;
end;

function TTestExecutor.TryParse(const Source: string; out Failure: TObservedError): Boolean;
begin
  var Parser: TJSParser := nil;
  try
    try
      Parser := TJSParser.Create(Source);
      Parser.Parse.Free;
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
  if Failure.IsEngineFault then
    Exit(CreateEngineFaultResult(Failure));

  if not ExpectsParseError then
    Exit(CreateResult(TTestOutcome.Failed, Description));

  const IsExpectedType = (Failure.Name = Metadata.NegativeType);
  if IsExpectedType then
    Exit(CreateResult(TTestOutcome.Passed, ''));

  Result := CreateResult(TTestOutcome.Failed,
                         Format('expected parse %s, got %s', [Metadata.NegativeType, Description]));
end;

function TTestExecutor.CreateEngineFaultResult(const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  Result := CreateResult(TTestOutcome.Failed, Format(EngineFaultFormat, [Description]));
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
      Exit(CreateResult(TTestOutcome.Failed, HarnessFailure));

    Result := RunTestSource(Session, TestCase, Source);
  finally
    Session.Free;
  end;
end;

function TTestExecutor.HarnessSource(const FileName: string; const Variant: TTestVariant): string;
begin
  const Source = FHarness.ReadSource(FileName);
  const IsStrictVariant = (Variant = TTestVariant.Strict);
  if IsStrictVariant then
    Result := StrictPrefix + Source
  else
    Result := Source;
end;

function TTestExecutor.TryLoadHarness(const Session: TTestSession;
                                      const TestCase: TTestCase;
                                      const Variant: TTestVariant;
                                      out Detail: string): Boolean;
begin
  Detail := '';
  if TestCase.Metadata.HasFlag(RawFlag) then
    Exit(True);

  try
    for var BaseFile in THarnessLibrary.BaseFiles do
    begin
      Session.Run(HarnessSource(BaseFile, Variant));
    end;

    for var Include in TestCase.Metadata.Includes do
    begin
      Session.Run(HarnessSource(Include, Variant));
    end;

    Result := True;
  except
    on E: Exception do
    begin
      const Observed = TErrorObserver.Observe(E);
      const Description = DescribeError(Observed);
      Detail := Format(HarnessLoadFormat, [Description]);
      Result := False;
    end;
  end;
end;

function TTestExecutor.RunTestSource(const Session: TTestSession; const TestCase: TTestCase; const Source: string): TVariantResult;
begin
  try
    Session.Run(Source);
    Result := JudgeCompletion(TestCase);
  except
    on E: Exception do
    begin
      const Observed = TErrorObserver.Observe(E);
      Result := JudgeError(TestCase, Observed);
    end;
  end;
end;

function TTestExecutor.JudgeCompletion(const TestCase: TTestCase): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  if not Metadata.IsNegative then
    Exit(CreateResult(TTestOutcome.Passed, ''));

  Result := CreateResult(TTestOutcome.Failed,
                         Format('expected %s but the test completed normally', [Metadata.NegativeType]));
end;

function TTestExecutor.JudgeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  if Observed.IsLimit then
    Exit(CreateResult(TTestOutcome.Limit, Description));

  if Observed.IsEngineFault then
    Exit(CreateEngineFaultResult(Observed));

  if TestCase.Metadata.IsNegative then
    Result := JudgeNegativeError(TestCase, Observed)
  else
    Result := CreateResult(TTestOutcome.Failed, Description);
end;

function TTestExecutor.JudgeNegativeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  const Description = DescribeError(Observed);
  const ExpectsRuntimeError = (Metadata.NegativePhase = TErrorPhase.Runtime);
  const IsExpectedType = (Observed.Name = Metadata.NegativeType);
  if ExpectsRuntimeError and IsExpectedType then
    Exit(CreateResult(TTestOutcome.Passed, ''));

  if ExpectsRuntimeError then
    Exit(CreateResult(TTestOutcome.Failed,
                      Format('expected %s, got %s', [Metadata.NegativeType, Description])));

  Result := CreateResult(TTestOutcome.Failed,
                         Format('program accepted although parse %s was expected; runtime threw %s',
                                [Metadata.NegativeType, Description]));
end;

function TTestExecutor.CreateResult(const Outcome: TTestOutcome; const Detail: string): TVariantResult;
begin
  Result.Outcome := Outcome;
  Result.Detail := Detail;
end;

function TTestExecutor.DescribeError(const Observed: TObservedError): string;
begin
  const Flattened = Observed.Message.Replace(#13, ' ').Replace(#10, ' ');
  const Shortened = Flattened.Substring(0, Min(Flattened.Length, MaxDetailLength));
  Result := Format('%s: %s', [Observed.Name, Shortened]);
end;

end.
