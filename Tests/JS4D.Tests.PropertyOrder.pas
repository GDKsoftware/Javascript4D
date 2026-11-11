unit JS4D.Tests.PropertyOrder;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  [TestFixture]
  TPropertyOrderTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('KeysIntegerFirst', 'Object.keys({ b: 1, 2: 1, a: 1, 1: 1 }).join()|1,2,b,a', '|')]
    [TestCase('KeysAscendingNumeric', 'Object.keys({ 10: 1, 9: 1, 100: 1 }).join()|9,10,100', '|')]
    [TestCase('KeysAssignedLater', 'var o = { b: 1 }; o[3] = 1; o[1] = 1; o.a = 1; Object.keys(o).join()|1,3,b,a', '|')]
    [TestCase('ComputedIntegerKeys', 'var o = { a: 1, [2]: 1, c: 1, [1]: 1 }; Object.keys(o).join()|1,2,a,c', '|')]
    [TestCase('OwnPropertyNames', 'Object.getOwnPropertyNames({ x: 1, 5: 1, 0: 1 }).join()|0,5,x', '|')]
    [TestCase('NonIndexNumericStaysInOrder', 'Object.keys({ b: 1, "01": 1, "-1": 1, 1: 1 }).join()|1,b,01,-1', '|')]
    [TestCase('LargestIndex', 'Object.keys({ a: 1, 4294967294: 1, 4294967295: 1 }).join()|4294967294,a,4294967295', '|')]
    [TestCase('ForInOrder', 'var r = []; for (var k in { b: 1, 2: 1, a: 1, 1: 1 }) r.push(k); r.join()|1,2,b,a', '|')]
    [TestCase('ArrayOwnNames', 'var a = [1, 2]; a.x = 1; Object.getOwnPropertyNames(a).join()|0,1,length,x', '|')]
    [TestCase('ArraySparseDefinedIndex', 'var a = [1, 2, 3]; Object.defineProperty(a, "5", { value: 1, configurable: true }); Object.getOwnPropertyNames(a).join()|0,1,2,5,length', '|')]
    procedure Evaluate_Result(const Source: string; const Expected: string);
  end;

implementation

procedure TPropertyOrderTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPropertyOrderTests.TearDown;
begin
  FEngine.Free;
end;

procedure TPropertyOrderTests.Evaluate_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

end.
