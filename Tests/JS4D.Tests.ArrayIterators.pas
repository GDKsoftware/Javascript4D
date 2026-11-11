unit JS4D.Tests.ArrayIterators;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TArrayIteratorsTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;
    function ErrorNameOf(const Statements: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('KeysNext', 'var it = ["a", "b"].keys(); var r = it.next(); r.value + "," + r.done#0,false', '#')]
    [TestCase('ValuesNext', 'var it = ["a", "b"].values(); it.next(); var r = it.next(); r.value + "," + r.done#b,false', '#')]
    [TestCase('EntriesNext', 'var r = ["a"].entries().next(); r.value[0] + r.value[1] + r.value.length#0a2', '#')]
    [TestCase('ExhaustedResult', 'var it = [].keys(); var r = it.next(); r.done + "," + r.value#true,undefined', '#')]
    [TestCase('StaysExhausted', 'var a = []; var it = a.keys(); it.next(); a.push(1); it.next().done#true', '#')]
    [TestCase('SeesElementAddedBeforeDone', 'var a = []; var it = a.entries(); a.push("x"); var r = it.next(); r.value[1] + r.done#xfalse', '#')]
    [TestCase('HolesYieldUndefined', 'var it = [, 1].values(); it.next().value#undefined', '#')]
    [TestCase('ArrayLike', 'var it = Array.prototype.keys.call({length: 2}); it.next().value + "" + it.next().value + it.next().done#01true', '#')]
    [TestCase('StringThis', 'var it = Array.prototype.values.call("ab"); it.next().value + it.next().value#ab', '#')]
    [TestCase('ResultIsPlainObject', 'Object.getPrototypeOf([].keys().next()) === Object.prototype#true', '#')]
    [TestCase('KeysLength', 'Array.prototype.keys.length#0', '#')]
    [TestCase('ValuesName', 'Array.prototype.values.name#values', '#')]
    [TestCase('EntriesTypeof', 'typeof Array.prototype.entries#function', '#')]
    [TestCase('KeysNotEnumerable', 'Object.keys(Array.prototype).indexOf("keys")#-1', '#')]
    [TestCase('IteratorsShareNext', '[].keys().next === [].entries().next#true', '#')]
    procedure Iterator_Result(const Expression: string; const Expected: string);

    [Test]
    [TestCase('ForOfKeys', 'var r = ""; for (var k of ["a", "b"].keys()) r += k; r#01', '#')]
    [TestCase('ForOfValues', 'var r = ""; for (var v of ["a", "b"].values()) r += v; r#ab', '#')]
    [TestCase('ForOfEntries', 'var r = ""; for (var [k, v] of ["a", "b"].entries()) r += k + v; r#0a1b', '#')]
    [TestCase('ForOfVisitsHoles', 'var n = 0; for (var k of [0, , 2].keys()) n++; n#3', '#')]
    [TestCase('ForOfPartiallyConsumed', 'var it = [1, 2, 3].values(); it.next(); var r = ""; for (var v of it) r += v; r#23', '#')]
    [TestCase('ForOfBreakKeepsRest', 'var it = [1, 2, 3].values(); for (var v of it) break; it.next().value#2', '#')]
    [TestCase('Spread', '[...["a", "b"].keys()].join()#0,1', '#')]
    [TestCase('SpreadInCall', 'Math.max(...[3, 9, 4].values())#9', '#')]
    [TestCase('ArrayDestructuring', 'var [x, y] = ["p", "q"].values(); x + y#pq', '#')]
    procedure Iterator_IsIterable(const Expression: string; const Expected: string);

    [Test]
    [TestCase('NextOnObject', 'Array.prototype.keys.call([]).next.call({})#TypeError', '#')]
    [TestCase('KeysOnNull', 'Array.prototype.keys.call(null)#TypeError', '#')]
    [TestCase('ValuesOnUndefined', 'Array.prototype.values.call(undefined)#TypeError', '#')]
    procedure Iterator_RaisesError(const Statements: string; const Expected: string);
  end;

implementation

procedure TArrayIteratorsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayIteratorsTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayIteratorsTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Expression).ToString;
end;

function TArrayIteratorsTests.ErrorNameOf(const Statements: string): string;
begin
  const Wrapper = Format('var caught = "none"; try { %s } catch (e) { caught = e.name; }', [Statements]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TArrayIteratorsTests.Iterator_Result(const Expression: string; const Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TArrayIteratorsTests.Iterator_IsIterable(const Expression: string; const Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TArrayIteratorsTests.Iterator_RaisesError(const Statements: string; const Expected: string);
begin
  Assert.AreEqual(Expected, ErrorNameOf(Statements));
end;

end.
