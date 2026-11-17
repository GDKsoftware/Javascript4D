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
    TestVariant: TTestVariant;
    Outcome: TTestOutcome;
    Detail: string;
  end;

  EConformanceError = class(Exception);

const
  DEFAULT_STEP_BUDGET = 2000000;
  DEFAULT_MAX_CALL_DEPTH = 100;
  DEFAULT_MAX_STRING_LENGTH = 1000000;
  UNLIMITED_ARRAY_LENGTH = 0;
  PROGRESS_INTERVAL = 2000;
  STRICT_PREFIX = '"use strict";' + #10;
  SYNTAX_ERROR_NAME = 'SyntaxError';
  REFERENCE_ERROR_NAME = 'ReferenceError';
  TYPE_ERROR_NAME = 'TypeError';
  RANGE_ERROR_NAME = 'RangeError';
  EVAL_ERROR_NAME = 'EvalError';
  URI_ERROR_NAME = 'URIError';
  PATH_SEPARATOR = '/';
  PHASE_PARSE = 'parse';
  PHASE_RESOLUTION = 'resolution';
  HOST_OBJECT_NAME = '$262';
  BACKSLASH = '\';

implementation

end.
