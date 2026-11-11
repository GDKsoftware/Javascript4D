unit JS4D.Conformance.Defines;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TTestOutcome = (Passed, Failed, Limit, Skipped);

  TTestVariant = (Sloppy, Strict);

  TErrorPhase = (None, Parse, Resolution, Runtime);

  TSessionLimits = record
    StepBudget: Int64;
    MaxCallDepth: Integer;
    MaxStringLength: Integer;
    MaxArrayLength: Integer;
  end;

  TObservedError = record
    Name: string;
    Message: string;
    IsLimit: Boolean;
    IsEngineFault: Boolean;
  end;

  TVariantResult = record
    Variant: TTestVariant;
    Outcome: TTestOutcome;
    Detail: string;
  end;

  EConformanceError = class(Exception);

const
  DefaultStepBudget = 2000000;
  DefaultMaxCallDepth = 100;
  DefaultMaxStringLength = 1000000;
  DefaultMaxArrayLength = 1048576;
  ProgressInterval = 2000;
  StrictPrefix = '"use strict";' + #10;
  SyntaxErrorName = 'SyntaxError';
  ReferenceErrorName = 'ReferenceError';
  TypeErrorName = 'TypeError';
  RangeErrorName = 'RangeError';
  EvalErrorName = 'EvalError';
  URIErrorName = 'URIError';

implementation

end.
