unit JS4D.Tests.LongChains;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TLongChainTests = class
  private
    type
      THugeRun = record
        Completed: Boolean;
        Text: string;
      end;

    const
      MODERATE_LENGTH = 1000;
      HUGE_LENGTH = 100000;
      MODERATE_NESTING = 100;
      LENGTH_DIMENSION = 'length';
      DEPTH_DIMENSION = 'depth';
      MODERATE_FORMAT = 'moderate %s';
      HUGE_FORMAT = 'huge %s';
      TRUE_RESULT = 'true';

    var
      FEngine: TJSEngine;

    function RunWithLength(const Script: string; const ChainLength: Integer): string;
    function ExecuteHuge(const Script: string): THugeRun;
    procedure AssertModerateWorks(const Script, Expected: string; const Size: Integer; const Dimension: string);
    procedure AssertHugeIsCorrectOrRefused(const Script, Expected: string; const Dimension: string);
    procedure AssertHugeIsRefused(const Script: string; const Dimension: string);
    procedure AssertEngineStillWorks;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Addition', 'eval("1" + "+1".repeat(n - 1)) === n#true', '#')]
    [TestCase('Subtraction', 'eval("0" + "-1".repeat(n)) === -n#true', '#')]
    [TestCase('Comparison', 'eval("1" + "<2".repeat(n))#true', '#')]
    [TestCase('Logical or', 'var a = 1; eval("a" + "||a".repeat(n)) === 1#true', '#')]
    [TestCase('Logical and', 'var a = 1; eval("a" + "&&a".repeat(n)) === 1#true', '#')]
    [TestCase('Nullish', 'var a = 1; eval("a" + "??a".repeat(n)) === 1#true', '#')]
    [TestCase('Comma', 'eval("1" + ",2".repeat(n)) === 2#true', '#')]
    [TestCase('String concatenation', 'eval("''a''" + "+''a''".repeat(n - 1)).length === n#true', '#')]
    [TestCase('Mixed operators', 'eval("1" + "+1*1".repeat(n)) === n + 1#true', '#')]
    [TestCase('Property chain', 'var a = {}; a.a = a; var ok; try { ok = eval("a" + ".a".repeat(n)) === a; } finally { a.a = null; } ok#true', '#')]
    [TestCase('Computed property chain', 'var a = []; a[0] = a; var ok; try { ok = eval("a" + "[0]".repeat(n)) === a; } finally { a[0] = null; } ok#true', '#')]
    [TestCase('Call chain', 'function f() { return f; } eval("f" + "()".repeat(n)) === f#true', '#')]
    [TestCase('Method call chain', 'var o = {}; o.b = function() { return o; }; eval("o" + ".b()".repeat(n)) === o#true', '#')]
    [TestCase('Tagged template chain', 'function t() { return t; } eval("t" + "`x`".repeat(n)) === t#true', '#')]
    [TestCase('Mixed member and call chain', 'var o = {}; o.b = function() { return o; }; o.c = o; var ok; try { ok = eval("o" + ".c.b()[''c'']".repeat(n)) === o; } finally { o.b = null; o.c = null; } ok#true', '#')]
    [TestCase('Assignment to property chain', 'var a = {}; a.a = a; eval("a" + ".a".repeat(n) + " = 5"); a.a === 5#true', '#')]
    [TestCase('Update of property chain', 'var a = {}; a.a = a; eval("a" + ".a".repeat(n) + "++"); isNaN(a.a)#true', '#')]
    [TestCase('Delete of property chain', 'var a = {}; a.a = a; eval("delete a" + ".a".repeat(n)); a.a === undefined#true', '#')]
    [TestCase('New of property chain', 'function F() {} F.F = F; eval("new F" + ".F".repeat(n) + "()") instanceof F#true', '#')]
    [TestCase('Chain inside a generator', 'function* g() { yield 1; return eval("1" + "+1".repeat(n - 1)); } var it = g(); it.next(); it.next().value === n#true', '#')]
    [TestCase('Chain with yield', 'var it = eval("(function*() { return (yield 1)" + "+1".repeat(n - 1) + "; })")(); it.next(); it.next(1).value === n#true', '#')]
    [TestCase('Chain with await', 'typeof eval("(async function() { return await 1" + "+1".repeat(n - 1) + "; })")()#object', '#')]
    [TestCase('Chain as default value', 'eval("(function(p = 1" + "+1".repeat(n - 1) + ") { return p; })")() === n#true', '#')]
    [TestCase('Chain in a function body', 'eval("(function() { return 1" + "+1".repeat(n - 1) + "; })")() === n#true', '#')]
    [TestCase('Chain in a class', 'eval("(class { static m() { return 1" + "+1".repeat(n - 1) + "; } })").m() === n#true', '#')]
    procedure Execute_LongChain_ModerateLengthWorksHugeLengthIsSafe(const Script, Expected: string);

    [Test]
    [TestCase('Template literals', 'eval("`" + "${`".repeat(n) + "x" + "`}".repeat(n) + "`") === "x"#true', '#')]
    [TestCase('Array literals', 'eval("[".repeat(n) + "]".repeat(n)).length === 1#true', '#')]
    [TestCase('Object literals', 'typeof eval("({a:".repeat(n) + "1" + "})".repeat(n))#object', '#')]
    [TestCase('Parentheses', 'eval("(".repeat(n) + "1" + ")".repeat(n)) === 1#true', '#')]
    [TestCase('Blocks', 'eval("{".repeat(n) + "}".repeat(n)) === undefined#true', '#')]
    [TestCase('If statements', 'eval("if (1) ".repeat(n) + "2;") === 2#true', '#')]
    [TestCase('Do while statements', 'eval("do ".repeat(n) + "2;" + " while (0)".repeat(n)) === 2#true', '#')]
    [TestCase('While statements', 'eval("while (0) ".repeat(n) + ";") === undefined#true', '#')]
    [TestCase('Function expressions', 'typeof eval("(function() { return ".repeat(n) + "1" + "})".repeat(n))#function', '#')]
    [TestCase('Class expressions', 'typeof eval("(class extends ".repeat(n) + "Object" + " {})".repeat(n))#function', '#')]
    [TestCase('Computed member keys', 'var a = [0]; eval("a[".repeat(n) + "0" + "]".repeat(n)) === 0#true', '#')]
    [TestCase('Call arguments', 'function f(x) { return x; } eval("f(".repeat(n) + "1" + ")".repeat(n)) === 1#true', '#')]
    [TestCase('Spread arguments', 'function f(x) { return x; } eval("f(...[".repeat(n) + "1" + "])".repeat(n)) === 1#true', '#')]
    [TestCase('Array binding patterns', 'eval("let " + "[".repeat(n) + "a" + "]".repeat(n) + " = " + "[".repeat(n) + "1" + "]".repeat(n) + "; a") === 1#true', '#')]
    [TestCase('Object binding patterns', 'eval("var " + "{a:".repeat(n) + "a" + "}".repeat(n) + " = " + "{a:".repeat(n) + "1" + "}".repeat(n) + "; a") === 1#true', '#')]
    [TestCase('Parameter binding patterns', 'eval("(function(" + "[".repeat(n) + "a" + "]".repeat(n) + ") { return a; })(" + "[".repeat(n) + "1" + "]".repeat(n) + ")") === 1#true', '#')]
    [TestCase('Arrow parameter binding patterns', 'eval("(" + "[".repeat(n) + "a" + "]".repeat(n) + ") => a")(eval("[".repeat(n) + "1" + "]".repeat(n))) === 1#true', '#')]
    [TestCase('Catch binding patterns', 'eval("var r; try { throw " + "[".repeat(n) + "1" + "]".repeat(n) + " } catch (" + "[".repeat(n) + "a" + "]".repeat(n) + ") { r = a } r") === 1#true', '#')]
    [TestCase('For-of binding patterns', 'eval("var r; for (let " + "[".repeat(n) + "a" + "]".repeat(n) + " of [" + "[".repeat(n) + "1" + "]".repeat(n) + "]) { r = a } r") === 1#true', '#')]
    [TestCase('Rest binding patterns', 'eval("let " + "[...".repeat(n) + "a" + "]".repeat(n) + " = " + "[".repeat(n) + "1" + "]".repeat(n) + "; a") instanceof Array#true', '#')]
    [TestCase('Nested try statements', 'eval("try { ".repeat(n) + "2;" + " } finally { }".repeat(n)) === 2#true', '#')]
    procedure Execute_NestedSource_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);

    [Test]
    [TestCase('Capturing groups', 'new RegExp("(".repeat(n) + ")".repeat(n)).test("")#true', '#')]
    [TestCase('Non-capturing groups', 'new RegExp("(?:".repeat(n) + "a" + ")".repeat(n)).test("a")#true', '#')]
    [TestCase('Lookaheads', 'new RegExp("(?=".repeat(n) + ")".repeat(n)).test("")#true', '#')]
    [TestCase('Literal', 'eval("/" + "(".repeat(n) + ")".repeat(n) + "/").test("")#true', '#')]
    [TestCase('Alternatives', 'new RegExp("(a|".repeat(n) + "b" + ")".repeat(n)).test("b")#true', '#')]
    procedure Execute_NestedRegularExpression_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);

    [Test]
    procedure Execute_RegularExpressionMatchingThatNestsTooDeeply_RaisesRangeError;

    [Test]
    procedure Execute_RegularExpressionOnModerateSubject_Matches;

    [Test]
    procedure Execute_UnterminatedNestedTemplates_RaisesSyntaxErrorOrRangeError;

    [Test]
    procedure Execute_HugeStringLiteralAndComment_Completes;

    [Test]
    procedure Execute_LongChainSeveralTimes_EngineStaysUsable;
  end;

implementation

procedure TLongChainTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TLongChainTests.TearDown;
begin
  FEngine.Free;
end;

function TLongChainTests.RunWithLength(const Script: string; const ChainLength: Integer): string;
begin
  const Source = Format('var n = %d; %s', [ChainLength, Script]);

  Result := FEngine.Execute(Source).ToString;
end;

function TLongChainTests.ExecuteHuge(const Script: string): THugeRun;
begin
  Result := Default(THugeRun);

  try
    Result.Text := RunWithLength(Script, HUGE_LENGTH);
    Result.Completed := True;
  except
    on E: Exception do
    begin
      const IsRefusal = ((E is EJSRangeError) or (E is EJSSyntaxError));
      if not IsRefusal then
        raise;
    end;
  end;
end;

procedure TLongChainTests.AssertModerateWorks(const Script, Expected: string; const Size: Integer;
                                              const Dimension: string);
begin
  const ModerateResult = RunWithLength(Script, Size);

  Assert.AreEqual(Expected, ModerateResult, Format(MODERATE_FORMAT, [Dimension]));
end;

procedure TLongChainTests.AssertHugeIsCorrectOrRefused(const Script, Expected: string; const Dimension: string);
begin
  const HugeRun = ExecuteHuge(Script);

  const IsCorrectOrRefused = ((not HugeRun.Completed) or (HugeRun.Text = Expected));
  Assert.IsTrue(IsCorrectOrRefused, Format(HUGE_FORMAT, [Dimension]));
end;

procedure TLongChainTests.AssertHugeIsRefused(const Script: string; const Dimension: string);
begin
  const HugeRun = ExecuteHuge(Script);

  Assert.IsFalse(HugeRun.Completed, Format(HUGE_FORMAT, [Dimension]));
end;

procedure TLongChainTests.AssertEngineStillWorks;
begin
  const Actual = FEngine.Execute('1 + 1').ToString;

  Assert.AreEqual('2', Actual, 'engine after the huge script');
end;

procedure TLongChainTests.Execute_LongChain_ModerateLengthWorksHugeLengthIsSafe(const Script, Expected: string);
begin
  AssertModerateWorks(Script, Expected, MODERATE_LENGTH, LENGTH_DIMENSION);
  AssertHugeIsCorrectOrRefused(Script, Expected, LENGTH_DIMENSION);
  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_NestedSource_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);
begin
  AssertModerateWorks(Script, Expected, MODERATE_NESTING, DEPTH_DIMENSION);
  AssertHugeIsCorrectOrRefused(Script, Expected, DEPTH_DIMENSION);
  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_NestedRegularExpression_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);
begin
  AssertModerateWorks(Script, Expected, MODERATE_NESTING, DEPTH_DIMENSION);
  AssertHugeIsRefused(Script, DEPTH_DIMENSION);
  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_RegularExpressionMatchingThatNestsTooDeeply_RaisesRangeError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('/(a|aa)+$b/.test("a".repeat(200000))');
    end,
    EJSRangeError);

  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_RegularExpressionOnModerateSubject_Matches;
begin
  const Actual = FEngine.Execute('/^(?:a|b)*$/.test("ab".repeat(100)) && /(a|aa)+$/.test("a".repeat(300))').ToString;

  Assert.AreEqual(TRUE_RESULT, Actual);
end;

procedure TLongChainTests.Execute_UnterminatedNestedTemplates_RaisesSyntaxErrorOrRangeError;
begin
  const HugeRun = ExecuteHuge('eval("`" + "${`".repeat(n))');

  Assert.IsFalse(HugeRun.Completed);
end;

procedure TLongChainTests.Execute_HugeStringLiteralAndComment_Completes;
begin
  const Script = 'var s = "x".repeat(4000000); eval("''" + s + "''").length === s.length && ' +
                 'eval("/*" + s + "*/ 7") === 7 && eval("//" + s + String.fromCharCode(10) + "8") === 8';

  const Actual = FEngine.Execute(Script).ToString;

  Assert.AreEqual(TRUE_RESULT, Actual);
end;

procedure TLongChainTests.Execute_LongChainSeveralTimes_EngineStaysUsable;
begin
  for var Repetition := 1 to 3 do
  begin
    ExecuteHuge('eval("1" + "+1".repeat(n - 1)) === n');
    ExecuteHuge('var a = {}; a.a = a; var ok; try { ok = eval("a" + ".a".repeat(n)) === a; } finally { a.a = null; } ok');
  end;

  const Actual = FEngine.Execute('2 + 2').ToString;

  Assert.AreEqual('4', Actual);
end;

end.
