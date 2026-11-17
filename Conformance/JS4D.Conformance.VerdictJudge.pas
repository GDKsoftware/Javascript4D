unit JS4D.Conformance.VerdictJudge;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase;

type
  TVerdictJudge = class
  private
    class function JudgeNegativeError(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult; static;

  public
    class function CreateResult(const Outcome: TTestOutcome; const Detail: string): TVariantResult; static;
    class function PassedResult: TVariantResult; static;
    class function DescribeError(const Observed: TObservedError): string; static;
    class function EngineFaultResult(const Observed: TObservedError): TVariantResult; static;
    class function JudgeParseFailure(const TestCase: TTestCase; const Failure: TObservedError): TVariantResult; static;
    class function JudgeThrown(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult; static;
    class function JudgeCompletion(const TestCase: TTestCase): TVariantResult; static;
    class function JudgeAsyncCompletion(const Printed: TArray<string>): TVariantResult; static;
  end;

implementation

uses
  System.Math;

const
  ASYNC_COMPLETE_MESSAGE = 'Test262:AsyncTestComplete';
  ASYNC_FAILURE_PREFIX = 'Test262:AsyncTestFailure:';
  ASYNC_NOT_SIGNALLED_DETAIL = 'async test did not report completion';
  MAX_DETAIL_LENGTH = 160;
  ENGINE_FAULT_FORMAT = 'engine fault %s';
  UNEXPECTED_PARSE_FORMAT = 'expected parse %s, got %s';
  COMPLETED_NORMALLY_FORMAT = 'expected %s but the test completed normally';
  UNEXPECTED_RUNTIME_FORMAT = 'expected %s, got %s';
  PROGRAM_ACCEPTED_FORMAT = 'program accepted although parse %s was expected; runtime threw %s';
  DESCRIPTION_FORMAT = '%s: %s';

class function TVerdictJudge.CreateResult(const Outcome: TTestOutcome; const Detail: string): TVariantResult;
begin
  Result.Outcome := Outcome;
  Result.Detail := Detail;
end;

class function TVerdictJudge.PassedResult: TVariantResult;
begin
  Result := CreateResult(TTestOutcome.Passed, '');
end;

class function TVerdictJudge.DescribeError(const Observed: TObservedError): string;
begin
  const WithoutReturns = Observed.Message.Replace(#13, ' ');
  const Flattened = WithoutReturns.Replace(#10, ' ');
  const Shortened = Flattened.Substring(0, Min(Flattened.Length, MAX_DETAIL_LENGTH));
  Result := Format(DESCRIPTION_FORMAT, [Observed.Name, Shortened]);
end;

class function TVerdictJudge.EngineFaultResult(const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  const Detail = Format(ENGINE_FAULT_FORMAT, [Description]);
  Result := CreateResult(TTestOutcome.Failed, Detail);
end;

class function TVerdictJudge.JudgeParseFailure(const TestCase: TTestCase;
                                               const Failure: TObservedError): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  const Description = DescribeError(Failure);
  const ExpectsParseError = Metadata.IsNegative and (Metadata.NegativePhase = TErrorPhase.Parse);
  const IsExpectedType = (Failure.Name = Metadata.NegativeType);
  if Failure.IsEngineFault then
  begin
    Result := EngineFaultResult(Failure);
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
    const Detail = Format(UNEXPECTED_PARSE_FORMAT, [Metadata.NegativeType, Description]);
    Result := CreateResult(TTestOutcome.Failed, Detail);
  end;
end;

class function TVerdictJudge.JudgeThrown(const TestCase: TTestCase; const Observed: TObservedError): TVariantResult;
begin
  const Description = DescribeError(Observed);
  if Observed.IsLimit then
  begin
    Result := CreateResult(TTestOutcome.Limit, Description);
  end
  else if Observed.IsEngineFault then
  begin
    Result := EngineFaultResult(Observed);
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

class function TVerdictJudge.JudgeNegativeError(const TestCase: TTestCase;
                                                const Observed: TObservedError): TVariantResult;
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
    const Detail = Format(UNEXPECTED_RUNTIME_FORMAT, [Metadata.NegativeType, Description]);
    Result := CreateResult(TTestOutcome.Failed, Detail);
  end
  else
  begin
    const Detail = Format(PROGRAM_ACCEPTED_FORMAT, [Metadata.NegativeType, Description]);
    Result := CreateResult(TTestOutcome.Failed, Detail);
  end;
end;

class function TVerdictJudge.JudgeCompletion(const TestCase: TTestCase): TVariantResult;
begin
  const Metadata = TestCase.Metadata;
  if Metadata.IsNegative then
  begin
    const Detail = Format(COMPLETED_NORMALLY_FORMAT, [Metadata.NegativeType]);
    Result := CreateResult(TTestOutcome.Failed, Detail);
  end
  else
  begin
    Result := PassedResult;
  end;
end;

class function TVerdictJudge.JudgeAsyncCompletion(const Printed: TArray<string>): TVariantResult;
begin
  for var Line in Printed do
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

end.
