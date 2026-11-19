unit JS4D.Tests.Engine;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Tests.Support;

type
  [TestFixture]
  TEngineTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Execute_SimpleAddition_ReturnsCorrectResult;

    [Test]
    procedure Execute_Multiplication_ReturnsCorrectResult;

    [Test]
    procedure Execute_OperatorPrecedence_ReturnsCorrectResult;

    [Test]
    procedure Execute_VariableDeclaration_StoresValue;

    [Test]
    procedure Execute_VariableAssignment_UpdatesValue;

    [Test]
    procedure Execute_FunctionDeclaration_CanBeCalled;

    [Test]
    procedure Execute_FunctionWithReturn_ReturnsValue;

    [Test]
    procedure Execute_ObjectLiteral_CreatesObject;

    [Test]
    procedure Execute_ArrayLiteral_CreatesArray;

    [Test]
    procedure Execute_ArrayAccess_ReturnsElement;

    [Test]
    procedure Execute_IfStatement_ExecutesCorrectBranch;

    [Test]
    procedure Execute_WhileLoop_IteratesCorrectly;

    [Test]
    procedure Execute_ForLoop_IteratesCorrectly;

    [Test]
    procedure Execute_StringConcatenation_JoinsStrings;

    [Test]
    procedure Execute_ComparisonOperators_ReturnsBoolean;

    [Test]
    procedure Execute_LogicalOperators_ReturnsCorrectResult;

    [Test]
    procedure Execute_MathSqrt_ReturnsCorrectResult;

    [Test]
    procedure Execute_MathPow_ReturnsCorrectResult;

    [Test]
    procedure Execute_MathFloorCeil_ReturnsCorrectResult;

    [Test]
    procedure Execute_TernaryOperator_ReturnsCorrectValue;

    [Test]
    procedure Execute_IncrementOperator_IncrementsValue;

    [Test]
    procedure Execute_DecrementOperator_DecrementsValue;

    [Test]
    procedure Execute_NestedFunction_WorksCorrectly;

    [Test]
    procedure Execute_Recursion_WorksCorrectly;

    [Test]
    procedure Execute_ObjectPropertyAccess_ReturnsValue;

    [Test]
    procedure Execute_ObjectPropertyAssignment_UpdatesValue;

    [Test]
    procedure Execute_ArrayLength_ReturnsCount;

    [Test]
    procedure Execute_StringLength_ReturnsCount;

    [Test]
    procedure Execute_TypeofOperator_ReturnsType;

    [Test]
    [TestCase('Undeclared', 'typeof notDeclared,undefined')]
    [TestCase('FeatureDetection', 'typeof window === "undefined" ? "server" : "browser",server')]
    [TestCase('Declared', 'var answer = 42; typeof answer,number')]
    [TestCase('VarInIfBlock', '(function () { if (true) { var t = 1; } return t; })(),1')]
    [TestCase('VarRedeclaredInBlock', '(function () { var t = 0; if (true) { var t = 5; } return t; })(),5')]
    [TestCase('VarInForInit', '(function () { for (var i = 0; i < 3; i++) {} return i; })(),3')]
    [TestCase('VarInForIn', '(function () { for (var k in {a: 1}) {} return k; })(),a')]
    [TestCase('VarInCatchBlock', '(function () { try { throw 1; } catch (e) { var m = e; } return m; })(),1')]
    [TestCase('VarReadBeforeDeclaration', '(function () { var before = x; var x = 1; return before; })(),undefined')]
    [TestCase('FunctionCalledBeforeDeclaration', '(function () { return f(); function f() { return 42; } })(),42')]
    [TestCase('UndeclaredAssignmentGoesGlobal', '(function () { g = 9; })(); g,9')]
    procedure Execute_Script_ReturnsExpectedText(const Script: string; const Expected: string);

    [Test]
    procedure Execute_UndeclaredIdentifier_RaisesReferenceError;

    [Test]
    procedure Execute_DateRelationalComparison_UsesTimestamp;

    [Test]
    procedure Execute_DateArithmetic_UsesTimestamp;

    [Test]
    procedure Execute_StringRelationalComparison_UsesLexicographicOrder;

    [Test]
    procedure Execute_StringRelationalComparison_MixedStringAndNumber_UsesNumericConversion;

    [Test]
    procedure Execute_DatePlusDate_ReturnsString;

    [Test]
    procedure Execute_DatePlusDate_EqualsConcatenatedTextForms;

    [Test]
    procedure Execute_DateTimesNumber_ProducesNumericProduct;

    [Test]
    procedure Execute_RepeatedInSameEngine_DoesNotLeakMemory;

    [Test]
    procedure CollectGarbage_ClosureInGlobal_SurvivesAndWorks;

    [Test]
    procedure CollectGarbage_GlobalState_Persists;

    [Test]
    procedure CollectGarbage_Builtins_ReturnResultsAfterCollection;
  end;

implementation

procedure TEngineTests.Execute_SimpleAddition_ReturnsCorrectResult;
begin
  const Actual = FEngine.Evaluate('1 + 2');

  Assert.AreEqual(Double(3), Actual.ToNumber);
end;

procedure TEngineTests.Execute_Multiplication_ReturnsCorrectResult;
begin
  const Actual = FEngine.Evaluate('3 * 4');

  Assert.AreEqual(Double(12), Actual.ToNumber);
end;

procedure TEngineTests.Execute_OperatorPrecedence_ReturnsCorrectResult;
begin
  const Actual = FEngine.Evaluate('1 + 2 * 3');

  Assert.AreEqual(Double(7), Actual.ToNumber);
end;

procedure TEngineTests.Execute_VariableDeclaration_StoresValue;
begin
  FEngine.Execute('var x = 42;');
  const Actual = FEngine.GetVariable('x');

  Assert.AreEqual(Double(42), Actual.ToNumber);
end;

procedure TEngineTests.Execute_VariableAssignment_UpdatesValue;
begin
  FEngine.Execute('var x = 10; x = 20;');
  const Actual = FEngine.GetVariable('x');

  Assert.AreEqual(Double(20), Actual.ToNumber);
end;

procedure TEngineTests.Execute_FunctionDeclaration_CanBeCalled;
begin
  FEngine.Execute('function greet() { return "hello"; }');
  const Actual = FEngine.Evaluate('greet()');

  Assert.AreEqual('hello', Actual.ToString);
end;

procedure TEngineTests.Execute_FunctionWithReturn_ReturnsValue;
begin
  FEngine.Execute('function add(a, b) { return a + b; }');
  const Actual = FEngine.Evaluate('add(3, 4)');

  Assert.AreEqual(Double(7), Actual.ToNumber);
end;

procedure TEngineTests.Execute_ObjectLiteral_CreatesObject;
begin
  FEngine.Execute('var obj = { x: 1, y: 2 };');
  const Actual = FEngine.Evaluate('obj.x + obj.y');

  Assert.AreEqual(Double(3), Actual.ToNumber);
end;

procedure TEngineTests.Execute_ArrayLiteral_CreatesArray;
begin
  FEngine.Execute('var arr = [1, 2, 3];');
  const Actual = FEngine.GetVariable('arr');

  Assert.IsTrue(Actual.IsArray);
end;

procedure TEngineTests.Execute_ArrayAccess_ReturnsElement;
begin
  FEngine.Execute('var arr = [10, 20, 30];');
  const Actual = FEngine.Evaluate('arr[1]');

  Assert.AreEqual(Double(20), Actual.ToNumber);
end;

procedure TEngineTests.Execute_IfStatement_ExecutesCorrectBranch;
begin
  FEngine.Execute('var result = 0; if (true) { result = 1; } else { result = 2; }');
  const Actual = FEngine.GetVariable('result');

  Assert.AreEqual(Double(1), Actual.ToNumber);
end;

procedure TEngineTests.Execute_WhileLoop_IteratesCorrectly;
begin
  FEngine.Execute('var i = 0; var sum = 0; while (i < 5) { sum += i; i++; }');
  const Actual = FEngine.GetVariable('sum');

  Assert.AreEqual(Double(10), Actual.ToNumber);
end;

procedure TEngineTests.Execute_ForLoop_IteratesCorrectly;
begin
  FEngine.Execute('var sum = 0; for (var i = 1; i <= 5; i++) { sum += i; }');
  const Actual = FEngine.GetVariable('sum');

  Assert.AreEqual(Double(15), Actual.ToNumber);
end;

procedure TEngineTests.Execute_StringConcatenation_JoinsStrings;
begin
  const Actual = FEngine.Evaluate('"Hello, " + "World!"');

  Assert.AreEqual('Hello, World!', Actual.ToString);
end;

procedure TEngineTests.Execute_ComparisonOperators_ReturnsBoolean;
begin
  const FirstActual = EvaluateBoolean('5 > 3');
  const SecondActual = EvaluateBoolean('5 >= 5');
  const ThirdActual = EvaluateBoolean('3 < 5');
  const FourthActual = EvaluateBoolean('3 <= 3');
  const FifthActual = EvaluateBoolean('5 == 5');
  const SixthActual = EvaluateBoolean('5 != 3');

  Assert.IsTrue(FirstActual);
  Assert.IsTrue(SecondActual);
  Assert.IsTrue(ThirdActual);
  Assert.IsTrue(FourthActual);
  Assert.IsTrue(FifthActual);
  Assert.IsTrue(SixthActual);
end;

procedure TEngineTests.Execute_LogicalOperators_ReturnsCorrectResult;
begin
  const FirstActual = EvaluateBoolean('true && true');
  const SecondActual = EvaluateBoolean('true && false');
  const ThirdActual = EvaluateBoolean('true || false');
  const FourthActual = EvaluateBoolean('false || false');
  const FifthActual = EvaluateBoolean('!false');

  Assert.IsTrue(FirstActual);
  Assert.IsFalse(SecondActual);
  Assert.IsTrue(ThirdActual);
  Assert.IsFalse(FourthActual);
  Assert.IsTrue(FifthActual);
end;

procedure TEngineTests.Execute_MathSqrt_ReturnsCorrectResult;
begin
  const Actual = FEngine.Evaluate('Math.sqrt(16)');

  Assert.AreEqual(Double(4), Actual.ToNumber);
end;

procedure TEngineTests.Execute_MathPow_ReturnsCorrectResult;
begin
  const Actual = FEngine.Evaluate('Math.pow(2, 8)');

  Assert.AreEqual(Double(256), Actual.ToNumber);
end;

procedure TEngineTests.Execute_MathFloorCeil_ReturnsCorrectResult;
begin
  const FirstActual = EvaluateNumber('Math.floor(3.7)');
  const SecondActual = EvaluateNumber('Math.ceil(3.2)');

  Assert.AreEqual(Double(3), FirstActual);
  Assert.AreEqual(Double(4), SecondActual);
end;

procedure TEngineTests.Execute_TernaryOperator_ReturnsCorrectValue;
begin
  const FirstActual = EvaluateText('true ? "yes" : "no"');
  const SecondActual = EvaluateText('false ? "yes" : "no"');

  Assert.AreEqual('yes', FirstActual);
  Assert.AreEqual('no', SecondActual);
end;

procedure TEngineTests.Execute_IncrementOperator_IncrementsValue;
begin
  FEngine.Execute('var x = 5; x++;');
  const Actual = FEngine.GetVariable('x');

  Assert.AreEqual(Double(6), Actual.ToNumber);
end;

procedure TEngineTests.Execute_DecrementOperator_DecrementsValue;
begin
  FEngine.Execute('var x = 5; x--;');
  const Actual = FEngine.GetVariable('x');

  Assert.AreEqual(Double(4), Actual.ToNumber);
end;

procedure TEngineTests.Execute_NestedFunction_WorksCorrectly;
begin
  FEngine.Execute('function outer(x) { function inner(y) { return y * 2; } return inner(x) + 1; }');
  const Actual = FEngine.Evaluate('outer(5)');

  Assert.AreEqual(Double(11), Actual.ToNumber);
end;

procedure TEngineTests.Execute_Recursion_WorksCorrectly;
begin
  FEngine.Execute('function factorial(n) { if (n <= 1) { return 1; } return n * factorial(n - 1); }');
  const Actual = FEngine.Evaluate('factorial(5)');

  Assert.AreEqual(Double(120), Actual.ToNumber);
end;

procedure TEngineTests.Execute_ObjectPropertyAccess_ReturnsValue;
begin
  FEngine.Execute('var obj = { name: "test", value: 42 };');

  const FirstActual = EvaluateText('obj.name');
  const SecondActual = EvaluateNumber('obj.value');

  Assert.AreEqual('test', FirstActual);
  Assert.AreEqual(Double(42), SecondActual);
end;

procedure TEngineTests.Execute_ObjectPropertyAssignment_UpdatesValue;
begin
  FEngine.Execute('var obj = { x: 1 }; obj.x = 10; obj.y = 20;');

  const FirstActual = EvaluateNumber('obj.x');
  const SecondActual = EvaluateNumber('obj.y');

  Assert.AreEqual(Double(10), FirstActual);
  Assert.AreEqual(Double(20), SecondActual);
end;

procedure TEngineTests.Execute_ArrayLength_ReturnsCount;
begin
  FEngine.Execute('var arr = [1, 2, 3, 4, 5];');
  const Actual = FEngine.Evaluate('arr.length');

  Assert.AreEqual(Double(5), Actual.ToNumber);
end;

procedure TEngineTests.Execute_StringLength_ReturnsCount;
begin
  const Actual = FEngine.Evaluate('"Hello".length');

  Assert.AreEqual(Double(5), Actual.ToNumber);
end;

procedure TEngineTests.Execute_TypeofOperator_ReturnsType;
begin
  const FirstActual = EvaluateText('typeof 42');
  const SecondActual = EvaluateText('typeof "hello"');
  const ThirdActual = EvaluateText('typeof true');
  const FourthActual = EvaluateText('typeof {}');
  const FifthActual = EvaluateText('typeof function() {}');
  const SixthActual = EvaluateText('typeof undefined');

  Assert.AreEqual('number', FirstActual);
  Assert.AreEqual('string', SecondActual);
  Assert.AreEqual('boolean', ThirdActual);
  Assert.AreEqual('object', FourthActual);
  Assert.AreEqual('function', FifthActual);
  Assert.AreEqual('undefined', SixthActual);
end;

procedure TEngineTests.Execute_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Script);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TEngineTests.Execute_UndeclaredIdentifier_RaisesReferenceError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Evaluate('notDeclared');
    end,
    EJSReferenceError);
end;

procedure TEngineTests.Execute_DateRelationalComparison_UsesTimestamp;
begin
  const GreaterOrEqual = FEngine.Evaluate('new Date(1000) >= new Date(0)');
  const LessOrEqual = FEngine.Evaluate('new Date(0) <= new Date(1000)');
  const Greater = FEngine.Evaluate('new Date(2000) > new Date(1000)');
  const NotGreater = FEngine.Evaluate('new Date(0) > new Date(1000)');

  Assert.IsTrue(GreaterOrEqual.ToBoolean);
  Assert.IsTrue(LessOrEqual.ToBoolean);
  Assert.IsTrue(Greater.ToBoolean);
  Assert.IsFalse(NotGreater.ToBoolean);
end;

procedure TEngineTests.Execute_DateArithmetic_UsesTimestamp;
begin
  const Difference = FEngine.Evaluate('new Date(2000) - new Date(1000)');

  Assert.AreEqual(Double(1000), Difference.ToNumber);
end;

procedure TEngineTests.Execute_StringRelationalComparison_UsesLexicographicOrder;
begin
  const LongerString = FEngine.Evaluate('"2026-05-19T10:20:32Z" >= "2026-05-19"');
  const EarlierDay = FEngine.Evaluate('"2026-05-19T10:20:32Z" < "2026-05-26"');
  const Alphabetical = FEngine.Evaluate('"apple" < "banana"');
  const Reversed = FEngine.Evaluate('"banana" < "apple"');

  Assert.IsTrue(LongerString.ToBoolean);
  Assert.IsTrue(EarlierDay.ToBoolean);
  Assert.IsTrue(Alphabetical.ToBoolean);
  Assert.IsFalse(Reversed.ToBoolean);
end;

procedure TEngineTests.Execute_StringRelationalComparison_MixedStringAndNumber_UsesNumericConversion;
begin
  const IsGreaterOrEqual = FEngine.Evaluate('"10" >= 5');

  Assert.IsTrue(IsGreaterOrEqual.ToBoolean);
end;

procedure TEngineTests.Execute_DatePlusDate_ReturnsString;
begin
  const TypeName = FEngine.Evaluate('typeof (new Date(1000) + new Date(2000))');

  Assert.AreEqual('string', TypeName.ToString);
end;

procedure TEngineTests.Execute_DatePlusDate_EqualsConcatenatedTextForms;
begin
  const Script = '(new Date(1000) + new Date(2000)) === new Date(1000).toString() + new Date(2000).toString()';
  const IsConcatenation = FEngine.Evaluate(Script);

  Assert.IsTrue(IsConcatenation.ToBoolean);
end;

procedure TEngineTests.Execute_DateTimesNumber_ProducesNumericProduct;
begin
  const Product = FEngine.Evaluate('new Date(1000) * 2');

  Assert.AreEqual(Double(2000), Product.ToNumber);
end;

procedure TEngineTests.Execute_RepeatedInSameEngine_DoesNotLeakMemory;
begin
  const Script = 'function make(n) { var f = function() { return n * 2; }; return f(); } make(21);';

  for var I := 1 to 200 do
    FEngine.Execute(Script);

  const Before = TJSTestSupport.AllocatedBytes;
  for var I := 1 to 4000 do
  begin
    FEngine.Execute(Script);
    FEngine.CollectGarbage;
  end;
  const Growth = TJSTestSupport.AllocatedBytes - Before;

  Assert.IsTrue(Growth < 512 * 1024,
    Format('Heap grew by %d bytes over 4000 executions in one engine (expected < 512 KB): scopes/functions are retained for the engine lifetime', [Growth]));
end;

procedure TEngineTests.CollectGarbage_ClosureInGlobal_SurvivesAndWorks;
begin
  FEngine.Execute('var counter = (function() { var n = 0; return function() { n = n + 1; return n; }; })();');
  FEngine.Execute('counter();');
  FEngine.CollectGarbage;

  const Actual = FEngine.Evaluate('counter()');

  Assert.AreEqual(Double(2), Actual.ToNumber, 'Closure stored in a global must survive collection with its captured state');
end;

procedure TEngineTests.CollectGarbage_GlobalState_Persists;
begin
  FEngine.Execute('var data = { total: 42 };');
  FEngine.CollectGarbage;

  const Actual = FEngine.Evaluate('data.total');

  Assert.AreEqual(Double(42), Actual.ToNumber);
end;

procedure TEngineTests.CollectGarbage_Builtins_ReturnResultsAfterCollection;
begin
  FEngine.CollectGarbage;

  const Actual = FEngine.Evaluate('Math.max(3, 7)');

  Assert.AreEqual(Double(7), Actual.ToNumber);
end;

end.
