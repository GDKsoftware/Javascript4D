unit JS4D.Tests.Engine;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TEngineTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure Execute_DateRelationalComparison_UsesTimestamp;

    [Test]
    procedure Execute_DateArithmetic_UsesTimestamp;

    [Test]
    procedure Execute_StringRelationalComparison_UsesLexicographicOrder;

    [Test]
    procedure Execute_DatePlusDate_ProducesNumericSum;

    [Test]
    procedure Execute_DateTimesNumber_ProducesNumericProduct;
  end;

implementation

procedure TEngineTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TEngineTests.TearDown;
begin
  FEngine.Free;
end;

procedure TEngineTests.Execute_SimpleAddition_ReturnsCorrectResult;
begin
  const Result = FEngine.Evaluate('1 + 2');

  Assert.AreEqual(Double(3), Result.ToNumber);
end;

procedure TEngineTests.Execute_Multiplication_ReturnsCorrectResult;
begin
  const Result = FEngine.Evaluate('3 * 4');

  Assert.AreEqual(Double(12), Result.ToNumber);
end;

procedure TEngineTests.Execute_OperatorPrecedence_ReturnsCorrectResult;
begin
  const Result = FEngine.Evaluate('1 + 2 * 3');

  Assert.AreEqual(Double(7), Result.ToNumber);
end;

procedure TEngineTests.Execute_VariableDeclaration_StoresValue;
begin
  FEngine.Execute('var x = 42;');
  const Result = FEngine.GetVariable('x');

  Assert.AreEqual(Double(42), Result.ToNumber);
end;

procedure TEngineTests.Execute_VariableAssignment_UpdatesValue;
begin
  FEngine.Execute('var x = 10; x = 20;');
  const Result = FEngine.GetVariable('x');

  Assert.AreEqual(Double(20), Result.ToNumber);
end;

procedure TEngineTests.Execute_FunctionDeclaration_CanBeCalled;
begin
  FEngine.Execute('function greet() { return "hello"; }');
  const Result = FEngine.Evaluate('greet()');

  Assert.AreEqual('hello', Result.ToString);
end;

procedure TEngineTests.Execute_FunctionWithReturn_ReturnsValue;
begin
  FEngine.Execute('function add(a, b) { return a + b; }');
  const Result = FEngine.Evaluate('add(3, 4)');

  Assert.AreEqual(Double(7), Result.ToNumber);
end;

procedure TEngineTests.Execute_ObjectLiteral_CreatesObject;
begin
  FEngine.Execute('var obj = { x: 1, y: 2 };');
  const Result = FEngine.Evaluate('obj.x + obj.y');

  Assert.AreEqual(Double(3), Result.ToNumber);
end;

procedure TEngineTests.Execute_ArrayLiteral_CreatesArray;
begin
  FEngine.Execute('var arr = [1, 2, 3];');
  const Result = FEngine.GetVariable('arr');

  Assert.IsTrue(Result.IsArray);
end;

procedure TEngineTests.Execute_ArrayAccess_ReturnsElement;
begin
  FEngine.Execute('var arr = [10, 20, 30];');
  const Result = FEngine.Evaluate('arr[1]');

  Assert.AreEqual(Double(20), Result.ToNumber);
end;

procedure TEngineTests.Execute_IfStatement_ExecutesCorrectBranch;
begin
  FEngine.Execute('var result = 0; if (true) { result = 1; } else { result = 2; }');
  const Result = FEngine.GetVariable('result');

  Assert.AreEqual(Double(1), Result.ToNumber);
end;

procedure TEngineTests.Execute_WhileLoop_IteratesCorrectly;
begin
  FEngine.Execute('var i = 0; var sum = 0; while (i < 5) { sum += i; i++; }');
  const Result = FEngine.GetVariable('sum');

  Assert.AreEqual(Double(10), Result.ToNumber);
end;

procedure TEngineTests.Execute_ForLoop_IteratesCorrectly;
begin
  FEngine.Execute('var sum = 0; for (var i = 1; i <= 5; i++) { sum += i; }');
  const Result = FEngine.GetVariable('sum');

  Assert.AreEqual(Double(15), Result.ToNumber);
end;

procedure TEngineTests.Execute_StringConcatenation_JoinsStrings;
begin
  const Result = FEngine.Evaluate('"Hello, " + "World!"');

  Assert.AreEqual('Hello, World!', Result.ToString);
end;

procedure TEngineTests.Execute_ComparisonOperators_ReturnsBoolean;
begin
  Assert.IsTrue(FEngine.Evaluate('5 > 3').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('5 >= 5').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('3 < 5').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('3 <= 3').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('5 == 5').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('5 != 3').ToBoolean);
end;

procedure TEngineTests.Execute_LogicalOperators_ReturnsCorrectResult;
begin
  Assert.IsTrue(FEngine.Evaluate('true && true').ToBoolean);
  Assert.IsFalse(FEngine.Evaluate('true && false').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('true || false').ToBoolean);
  Assert.IsFalse(FEngine.Evaluate('false || false').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('!false').ToBoolean);
end;

procedure TEngineTests.Execute_MathSqrt_ReturnsCorrectResult;
begin
  const Result = FEngine.Evaluate('Math.sqrt(16)');

  Assert.AreEqual(Double(4), Result.ToNumber);
end;

procedure TEngineTests.Execute_MathPow_ReturnsCorrectResult;
begin
  const Result = FEngine.Evaluate('Math.pow(2, 8)');

  Assert.AreEqual(Double(256), Result.ToNumber);
end;

procedure TEngineTests.Execute_MathFloorCeil_ReturnsCorrectResult;
begin
  Assert.AreEqual(Double(3), FEngine.Evaluate('Math.floor(3.7)').ToNumber);
  Assert.AreEqual(Double(4), FEngine.Evaluate('Math.ceil(3.2)').ToNumber);
end;

procedure TEngineTests.Execute_TernaryOperator_ReturnsCorrectValue;
begin
  Assert.AreEqual('yes', FEngine.Evaluate('true ? "yes" : "no"').ToString);
  Assert.AreEqual('no', FEngine.Evaluate('false ? "yes" : "no"').ToString);
end;

procedure TEngineTests.Execute_IncrementOperator_IncrementsValue;
begin
  FEngine.Execute('var x = 5; x++;');
  const Result = FEngine.GetVariable('x');

  Assert.AreEqual(Double(6), Result.ToNumber);
end;

procedure TEngineTests.Execute_DecrementOperator_DecrementsValue;
begin
  FEngine.Execute('var x = 5; x--;');
  const Result = FEngine.GetVariable('x');

  Assert.AreEqual(Double(4), Result.ToNumber);
end;

procedure TEngineTests.Execute_NestedFunction_WorksCorrectly;
begin
  FEngine.Execute('function outer(x) { function inner(y) { return y * 2; } return inner(x) + 1; }');
  const Result = FEngine.Evaluate('outer(5)');

  Assert.AreEqual(Double(11), Result.ToNumber);
end;

procedure TEngineTests.Execute_Recursion_WorksCorrectly;
begin
  FEngine.Execute('function factorial(n) { if (n <= 1) { return 1; } return n * factorial(n - 1); }');
  const Result = FEngine.Evaluate('factorial(5)');

  Assert.AreEqual(Double(120), Result.ToNumber);
end;

procedure TEngineTests.Execute_ObjectPropertyAccess_ReturnsValue;
begin
  FEngine.Execute('var obj = { name: "test", value: 42 };');

  Assert.AreEqual('test', FEngine.Evaluate('obj.name').ToString);
  Assert.AreEqual(Double(42), FEngine.Evaluate('obj.value').ToNumber);
end;

procedure TEngineTests.Execute_ObjectPropertyAssignment_UpdatesValue;
begin
  FEngine.Execute('var obj = { x: 1 }; obj.x = 10; obj.y = 20;');

  Assert.AreEqual(Double(10), FEngine.Evaluate('obj.x').ToNumber);
  Assert.AreEqual(Double(20), FEngine.Evaluate('obj.y').ToNumber);
end;

procedure TEngineTests.Execute_ArrayLength_ReturnsCount;
begin
  FEngine.Execute('var arr = [1, 2, 3, 4, 5];');
  const Result = FEngine.Evaluate('arr.length');

  Assert.AreEqual(Double(5), Result.ToNumber);
end;

procedure TEngineTests.Execute_StringLength_ReturnsCount;
begin
  const Result = FEngine.Evaluate('"Hello".length');

  Assert.AreEqual(Double(5), Result.ToNumber);
end;

procedure TEngineTests.Execute_TypeofOperator_ReturnsType;
begin
  Assert.AreEqual('number', FEngine.Evaluate('typeof 42').ToString);
  Assert.AreEqual('string', FEngine.Evaluate('typeof "hello"').ToString);
  Assert.AreEqual('boolean', FEngine.Evaluate('typeof true').ToString);
  Assert.AreEqual('object', FEngine.Evaluate('typeof {}').ToString);
  Assert.AreEqual('function', FEngine.Evaluate('typeof function() {}').ToString);
  Assert.AreEqual('undefined', FEngine.Evaluate('typeof undefined').ToString);
end;

procedure TEngineTests.Execute_DateRelationalComparison_UsesTimestamp;
begin
  Assert.IsTrue(FEngine.Evaluate('new Date(1000) >= new Date(0)').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('new Date(0) <= new Date(1000)').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('new Date(2000) > new Date(1000)').ToBoolean);
  Assert.IsFalse(FEngine.Evaluate('new Date(0) > new Date(1000)').ToBoolean);
end;

procedure TEngineTests.Execute_DateArithmetic_UsesTimestamp;
begin
  Assert.AreEqual(Double(1000), FEngine.Evaluate('new Date(2000) - new Date(1000)').ToNumber);
end;

procedure TEngineTests.Execute_StringRelationalComparison_UsesLexicographicOrder;
begin
  Assert.IsTrue(FEngine.Evaluate('"2026-05-19T10:20:32Z" >= "2026-05-19"').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('"2026-05-19T10:20:32Z" < "2026-05-26"').ToBoolean);
  Assert.IsTrue(FEngine.Evaluate('"apple" < "banana"').ToBoolean);
  Assert.IsFalse(FEngine.Evaluate('"banana" < "apple"').ToBoolean);
  // Mixed string/number uses numeric conversion per spec.
  Assert.IsTrue(FEngine.Evaluate('"10" >= 5').ToBoolean);
end;

procedure TEngineTests.Execute_DatePlusDate_ProducesNumericSum;
begin
  // Date + Date goes through the numeric Add branch because neither operand
  // is a String_. Diverges from browser JS (which does string concat via
  // Date's "default" ToPrimitive hint); JS4D's Add does a literal IsString
  // check rather than ToPrimitive.
  Assert.AreEqual(Double(3000), FEngine.Evaluate('new Date(1000) + new Date(2000)').ToNumber);
end;

procedure TEngineTests.Execute_DateTimesNumber_ProducesNumericProduct;
begin
  Assert.AreEqual(Double(2000), FEngine.Evaluate('new Date(1000) * 2').ToNumber);
end;

initialization
  TDUnitX.RegisterTestFixture(TEngineTests);

end.
