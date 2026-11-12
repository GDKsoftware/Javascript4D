unit JS4D.Tests.HotPathSemantics;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  THotPathSemanticsTests = class
  private
    FEngine: TJSEngine;

    function Run(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('For-of variable leaves a read-only global alone', 'var ro = 1; Object.defineProperty(this, ''ro'', { writable: false }); for (var ro of [4, 5]) { } String(ro)#1', '#')]
    [TestCase('For-of variable replaces a global value', 'var seen = 0; for (var seen of [4, 5]) { } String(seen)#5', '#')]
    [TestCase('Spread reads a hole through the prototype', 'var a = [1, , 3]; Array.prototype[1] = 9; var r = [...a].join(); delete Array.prototype[1]; r#1,9,3', '#')]
    [TestCase('Push after a length extension keeps the sparse part', 'var a = []; a.length = 3; a.push(7); a.length + '','' + a[3]#4,7', '#')]
    [TestCase('Reading a named member of undefined names the member', 'try { undefined.foo; } catch (e) { String(/foo/.test(e.message)); }#true', '#')]
    [TestCase('Reading a computed member of undefined names the key', 'var k = ''bar''; try { undefined[k]; } catch (e) { String(/bar/.test(e.message)); }#true', '#')]
    [TestCase('Computed and named access reach the same property', 'var o = { a: 1 }; var k = ''a''; o.a += 1; o[k] += 1; String(o.a)#3', '#')]
    procedure HotPath_KeepsSemantics(const Script, Expected: string);
  end;

implementation

procedure THotPathSemanticsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure THotPathSemanticsTests.TearDown;
begin
  FEngine.Free;
end;

function THotPathSemanticsTests.Run(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

procedure THotPathSemanticsTests.HotPath_KeepsSemantics(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

end.
