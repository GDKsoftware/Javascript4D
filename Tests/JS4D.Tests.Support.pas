unit JS4D.Tests.Support;

{$SCOPEDENUMS ON}

{$WARN SYMBOL_PLATFORM OFF}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  TJSTestSupport = class
  private
    class function SmallBlockBytes(const State: TMemoryManagerState): Int64; static;

  public
    class function TextOf(const Engine: TJSEngine; const Expression: string): string; static;
    class function RunAndRead(const Engine: TJSEngine; const Script: string): string; static;
    class function EscapeForStringLiteral(const Source: string): string; static;
    class function AllocatedBytes: Int64; static;
    class function ErrorNameOf(const Engine: TJSEngine; const Source: string): string; static;
  end;

  TJSEngineTestCase = class
  protected
    FEngine: TJSEngine;

    procedure ConfigureEngine; virtual;
    function EvaluateNumber(const Script: string): Double;
    function EvaluateBoolean(const Script: string): Boolean;
    function EvaluateText(const Script: string): string;
    function TextOf(const Expression: string): string;
    function ErrorNameOf(const Source: string): string;
    function ThrownErrorNameOf(const Statements: string): string;
    function ThrowsTypeError(const Statement: string): Boolean;

    procedure AssertEvaluatesTo(const Expected: string; const Script: string);
    procedure AssertChecksHold(const Preparation: string; const Checks: array of string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;
  end;

implementation

uses
  System.SysUtils;

const
  CAUGHT_ERROR_NAME_FORMAT = 'var caught = "none"; try { %s } catch (e) { caught = e.name; }';
  THROWS_TYPE_ERROR_FORMAT = 'var thrown = false; try { %s } catch (e) { thrown = (e instanceof TypeError); } thrown';

class function TJSTestSupport.TextOf(const Engine: TJSEngine; const Expression: string): string;
begin
  const Wrapped = Format('String(%s)', [Expression]);
  const Value = Engine.Evaluate(Wrapped);

  Result := Value.ToString;
end;

class function TJSTestSupport.SmallBlockBytes(const State: TMemoryManagerState): Int64;
begin
  Result := 0;
  for var SmallBlockState in State.SmallBlockTypeStates do
  begin
    const BlockBytes = Int64(SmallBlockState.UseableBlockSize) * Int64(SmallBlockState.AllocatedBlockCount);
    Inc(Result, BlockBytes);
  end;
end;

class function TJSTestSupport.AllocatedBytes: Int64;
begin
  var State: TMemoryManagerState;
  GetMemoryManagerState(State);

  const LargerBlockBytes = Int64(State.TotalAllocatedMediumBlockSize) + Int64(State.TotalAllocatedLargeBlockSize);

  Result := LargerBlockBytes + SmallBlockBytes(State);
end;

class function TJSTestSupport.RunAndRead(const Engine: TJSEngine; const Script: string): string;
begin
  Engine.Execute(Script);

  Result := TextOf(Engine, 'r');
end;

class function TJSTestSupport.EscapeForStringLiteral(const Source: string): string;
begin
  const Escaped = TStringBuilder.Create;
  try
    for var Character in Source do
    begin
      Escaped.AppendFormat('\u%.4x', [Ord(Character)]);
    end;

    Result := Escaped.ToString;
  finally
    Escaped.Free;
  end;
end;

class function TJSTestSupport.ErrorNameOf(const Engine: TJSEngine; const Source: string): string;
begin
  const Literal = EscapeForStringLiteral(Source);
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [Literal]);
  Engine.Execute(Wrapper);

  const Caught = Engine.Evaluate('caught');
  Result := Caught.AsString;
end;

procedure TJSEngineTestCase.ConfigureEngine;
begin
end;

procedure TJSEngineTestCase.Setup;
begin
  FEngine := TJSEngine.Create;
  ConfigureEngine;
end;

procedure TJSEngineTestCase.TearDown;
begin
  FEngine.Free;
end;

function TJSEngineTestCase.EvaluateNumber(const Script: string): Double;
begin
  const Value = FEngine.Evaluate(Script);

  Result := Value.AsNumber;
end;

function TJSEngineTestCase.EvaluateBoolean(const Script: string): Boolean;
begin
  const Value = FEngine.Evaluate(Script);

  Result := Value.AsBoolean;
end;

function TJSEngineTestCase.EvaluateText(const Script: string): string;
begin
  const Value = FEngine.Evaluate(Script);

  Result := Value.ToString;
end;

function TJSEngineTestCase.TextOf(const Expression: string): string;
begin
  Result := TJSTestSupport.TextOf(FEngine, Expression);
end;

function TJSEngineTestCase.ErrorNameOf(const Source: string): string;
begin
  Result := TJSTestSupport.ErrorNameOf(FEngine, Source);
end;

function TJSEngineTestCase.ThrownErrorNameOf(const Statements: string): string;
begin
  const Wrapper = Format(CAUGHT_ERROR_NAME_FORMAT, [Statements]);
  FEngine.Execute(Wrapper);

  Result := EvaluateText('caught');
end;

function TJSEngineTestCase.ThrowsTypeError(const Statement: string): Boolean;
begin
  const Script = Format(THROWS_TYPE_ERROR_FORMAT, [Statement]);

  Result := EvaluateBoolean(Script);
end;

procedure TJSEngineTestCase.AssertEvaluatesTo(const Expected: string; const Script: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual, Script);
end;

procedure TJSEngineTestCase.AssertChecksHold(const Preparation: string; const Checks: array of string);
begin
  var Passing: TArray<string>;
  SetLength(Passing, Length(Checks));
  for var Index := 0 to High(Checks) do
  begin
    Passing[Index] := 'true';
  end;

  const Expected = string.Join(',', Passing);
  const Expressions = string.Join(', ', Checks);
  const Script = Format('%s [%s].join()', [Preparation, Expressions]);

  AssertEvaluatesTo(Expected, Script);
end;

end.
