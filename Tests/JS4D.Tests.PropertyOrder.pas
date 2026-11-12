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
    [TestCase('NativeFunctionLengthBeforeName', 'var n = Object.getOwnPropertyNames(Function); n.indexOf("name") - n.indexOf("length")|1', '|')]
    [TestCase('NativeMethodLengthBeforeName', 'var n = Object.getOwnPropertyNames(Object.keys); n.slice(0, 2).join()|length,name', '|')]
    [TestCase('FunctionPrototypeLengthBeforeName', 'var n = Object.getOwnPropertyNames(Function.prototype); n.indexOf("name") - n.indexOf("length")|1', '|')]
    [TestCase('ScriptFunctionLengthBeforeName', 'function f(a) {} Object.getOwnPropertyNames(f).slice(0, 2).join()|length,name', '|')]
    [TestCase('BindLengthDefaultsToZeroWhenNotOwn', 'function f() {} Object.setPrototypeOf(f, { length: 42 }); delete f.length; Function.prototype.bind.call(f, null, 1).length|0', '|')]
    [TestCase('BindLengthKeepsLargeValue', 'function f() {} Object.defineProperty(f, "length", { value: 2147483648 }); f.bind().length|2147483648', '|')]
    [TestCase('BindLengthKeepsInfinity', 'function f() {} Object.defineProperty(f, "length", { value: Infinity }); f.bind(0, 0).length|Infinity', '|')]
    [TestCase('BindLengthOfNegativeInfinityIsZero', 'function f() {} Object.defineProperty(f, "length", { value: -Infinity }); f.bind(0, 0).length|0', '|')]
    [TestCase('BindLengthTruncatesFraction', 'function f() {} Object.defineProperty(f, "length", { value: 3.66 }); f.bind().length|3', '|')]
    [TestCase('BindLengthSubtractsBoundArguments', 'function f(a, b, c) {} f.bind(null, 1).length|2', '|')]
    [TestCase('BindLengthNeverNegative', 'function f(a) {} f.bind(null, 1, 2, 3).length|0', '|')]
    [TestCase('NewNewThrowsTypeError', 'var caught = ""; try { new new Boolean(true); } catch (e) { caught = e instanceof TypeError; } String(caught)|true', '|')]
    [TestCase('NewNewConstructsResult', 'function Outer() { return function Inner() { this.v = 7; }; } (new new Outer()).v|7', '|')]
    [TestCase('NewNewWithArguments', 'function A() { this.make = function () { return function B(n) { this.n = n; }; }; } new (new A().make())(5).n|5', '|')]
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
