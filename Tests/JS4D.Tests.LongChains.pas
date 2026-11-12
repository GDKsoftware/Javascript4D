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
    const
      MODERATE_LENGTH = 1000;
      HUGE_LENGTH = 100000;
      MODERATE_NESTING = 100;

  private
    FEngine: TJSEngine;

    function RunWithLength(const Script: string; const Length: Integer): string;
    function RunHuge(const Script: string; out Completed: Boolean): string;
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
    [TestCase('Nested try statements', 'eval("try { ".repeat(n) + "2;" + " } finally { }".repeat(n)) === 2#true', '#')]
    procedure Execute_NestedSource_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);

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

function TLongChainTests.RunWithLength(const Script: string; const Length: Integer): string;
begin
  const Program_ = Format('var n = %d; %s', [Length, Script]);

  Result := FEngine.Execute(Program_).ToString;
end;

function TLongChainTests.RunHuge(const Script: string; out Completed: Boolean): string;
begin
  Completed := False;
  Result := '';

  try
    Result := RunWithLength(Script, HUGE_LENGTH);
    Completed := True;
  except
    on EJSRangeError do
    begin
      Completed := False;
    end;
    on EJSSyntaxError do
    begin
      Completed := False;
    end;
  end;
end;

procedure TLongChainTests.AssertEngineStillWorks;
begin
  const Actual = FEngine.Execute('1 + 1').ToString;

  Assert.AreEqual('2', Actual, 'engine after the huge script');
end;

procedure TLongChainTests.Execute_LongChain_ModerateLengthWorksHugeLengthIsSafe(const Script, Expected: string);
begin
  const ModerateResult = RunWithLength(Script, MODERATE_LENGTH);
  Assert.AreEqual(Expected, ModerateResult, 'moderate length');

  var Completed: Boolean;
  const HugeResult = RunHuge(Script, Completed);
  if Completed then
    Assert.AreEqual(Expected, HugeResult, 'huge length');

  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_NestedSource_ModerateDepthWorksHugeDepthIsSafe(const Script, Expected: string);
begin
  const ModerateResult = RunWithLength(Script, MODERATE_NESTING);
  Assert.AreEqual(Expected, ModerateResult, 'moderate depth');

  var Completed: Boolean;
  const HugeResult = RunHuge(Script, Completed);
  if Completed then
    Assert.AreEqual(Expected, HugeResult, 'huge depth');

  AssertEngineStillWorks;
end;

procedure TLongChainTests.Execute_UnterminatedNestedTemplates_RaisesSyntaxErrorOrRangeError;
begin
  var Completed: Boolean;
  RunHuge('eval("`" + "${`".repeat(n))', Completed);

  Assert.IsFalse(Completed);
end;

procedure TLongChainTests.Execute_HugeStringLiteralAndComment_Completes;
begin
  const Script = 'var s = "x".repeat(4000000); eval("''" + s + "''").length === s.length && ' +
                 'eval("/*" + s + "*/ 7") === 7 && eval("//" + s + String.fromCharCode(10) + "8") === 8';

  const Actual = FEngine.Execute(Script).ToString;

  Assert.AreEqual('true', Actual);
end;

procedure TLongChainTests.Execute_LongChainSeveralTimes_EngineStaysUsable;
begin
  for var Run := 1 to 3 do
  begin
    var Completed: Boolean;
    RunHuge('eval("1" + "+1".repeat(n - 1)) === n', Completed);
    RunHuge('var a = {}; a.a = a; var ok; try { ok = eval("a" + ".a".repeat(n)) === a; } finally { a.a = null; } ok', Completed);
  end;

  const Actual = FEngine.Execute('2 + 2').ToString;

  Assert.AreEqual('4', Actual);
end;

end.
