unit JS4D.Tests.ForIn;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TForInTests = class
  private
    FEngine: TJSEngine;

    procedure AssertEvaluatesTo(const Expected: string; const Source: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Inherited', 'function F() { this.own = 1; } F.prototype = { shared: 2 }; var r = ""; for (var k in new F) r += k; r|ownshared', '|')]
    [TestCase('InheritedThroughSeveralLevels', 'var a = { x: 1 }; var b = Object.create(a); b.y = 2; var c = Object.create(b); c.z = 3; var r = ""; for (var k in c) r += k; r|zyx', '|')]
    [TestCase('InheritedDefinedProperty', 'var p = {}; Object.defineProperty(p, "q", { value: 1, enumerable: true }); var r = ""; for (var k in Object.create(p)) r += k; r|q', '|')]
    [TestCase('InheritedFromBuiltinPrototype', 'Array.prototype.extra = 1; var r = ""; for (var k in [5]) r += k; delete Array.prototype.extra; r|0extra', '|')]
    [TestCase('NonEnumerableInheritedIsSkipped', 'var p = {}; Object.defineProperty(p, "q", { value: 1, enumerable: false }); var r = ""; for (var k in Object.create(p)) r += k; r + "!"|!', '|')]
    [TestCase('OwnShadowsInherited', 'var o = Object.create({ x: 1, y: 2 }); o.x = 3; var r = ""; for (var k in o) r += k; r|xy', '|')]
    [TestCase('OwnNonEnumerableShadowsInherited', 'var o = Object.create({ x: 1 }); Object.defineProperty(o, "x", { value: 2, enumerable: false }); var r = ""; for (var k in o) r += k; r + "!"|!', '|')]
    [TestCase('StringPrimitive', 'var r = ""; for (var k in "ab") r += k; r|01', '|')]
    [TestCase('NumberPrimitive', 'var r = ""; for (var k in 5) r += k; r + "!"|!', '|')]
    [TestCase('NullAndUndefinedAreSkipped', 'var n = 0; for (var k in null) n++; for (var k in undefined) n++; n|0', '|')]
    [TestCase('DeletedBeforeVisitIsSkipped', 'var o = { a: 1, b: 2, c: 3 }; var r = ""; for (var k in o) { r += k; delete o.b; } r|ac', '|')]
    [TestCase('DeletedInheritedBeforeVisitIsSkipped', 'var p = { u: 1, v: 2 }; var o = Object.create(p); var r = ""; for (var k in o) { r += k; delete p.v; } r|u', '|')]
    [TestCase('AddedDuringIterationIsNotVisited', 'var o = { a: 1 }; var r = ""; for (var k in o) { o.z = 1; r += k; } r|a', '|')]
    [TestCase('LetBinding', 'var r = ""; for (let k in Object.create({ p: 1 })) r += k; r|p', '|')]
    procedure Enumerates_Result(const Source: string; const Expected: string);
  end;

implementation

procedure TForInTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TForInTests.TearDown;
begin
  FEngine.Free;
end;

procedure TForInTests.AssertEvaluatesTo(const Expected: string; const Source: string);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).ToString);
end;

procedure TForInTests.Enumerates_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

end.
