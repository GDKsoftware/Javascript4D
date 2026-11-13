unit JS4D.Tests.SourceNesting;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TSourceNestingTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Unary operators', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''!''; } eval(s + ''1'');', '#')]
    [TestCase('Await operators', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''await ''; } eval(''async function f() { '' + s + ''1 }'');', '#')]
    [TestCase('Yield operators', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''yield ''; } eval(''function* f() { '' + s + ''1 }'');', '#')]
    [TestCase('Chained assignments', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''a = ''; } eval(''var a; '' + s + ''1'');', '#')]
    [TestCase('Chained conditionals', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''1 ? 2 : ''; } eval(s + ''1'');', '#')]
    [TestCase('Chained exponentiations', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''2 ** ''; } eval(s + ''1'');', '#')]
    [TestCase('Chained new expressions', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''new ''; } eval(s + ''Object'');', '#')]
    [TestCase('Chained arrow functions', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''x => ''; } eval(s + ''1'');', '#')]
    [TestCase('Chained async arrow functions', 'var s = ''''; for (var i = 0; i < 20000; i++) { s += ''async x => ''; } eval(s + ''1'');', '#')]
    procedure Execute_DeeplyNestedSource_RaisesRangeError(const Script: string);

    [Test]
    [TestCase('Unary operators', 'var s = ''''; for (var i = 0; i < 100; i++) { s += ''!''; } eval(s + ''1'');#true', '#')]
    [TestCase('Await operators', 'var s = ''''; for (var i = 0; i < 100; i++) { s += ''await ''; } String(typeof eval(''(async function f() { '' + s + ''1 })''));#function', '#')]
    [TestCase('Chained assignments', 'var s = ''''; for (var i = 0; i < 100; i++) { s += ''a = ''; } eval(''var a; '' + s + ''7'');#7', '#')]
    [TestCase('Chained conditionals', 'var s = ''''; for (var i = 0; i < 100; i++) { s += ''0 ? 2 : ''; } eval(s + ''5'');#5', '#')]
    [TestCase('Chained arrow functions', 'var s = ''''; for (var i = 0; i < 100; i++) { s += ''x => ''; } typeof eval(s + ''1'');#function', '#')]
    procedure Execute_ModeratelyNestedSource_StillWorks(const Script, Expected: string);
  end;

implementation

procedure TSourceNestingTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TSourceNestingTests.TearDown;
begin
  FEngine.Free;
end;

procedure TSourceNestingTests.Execute_DeeplyNestedSource_RaisesRangeError(const Script: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSRangeError);
end;

procedure TSourceNestingTests.Execute_ModeratelyNestedSource_StillWorks(const Script, Expected: string);
begin
  const Actual = FEngine.Execute(Script).ToString;

  Assert.AreEqual(Expected, Actual);
end;

end.
