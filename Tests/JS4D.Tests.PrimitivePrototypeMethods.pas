unit JS4D.Tests.PrimitivePrototypeMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TPrimitivePrototypeMethodTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('StringPrototype_MethodsAreFunctions1', 'typeof String.prototype.charAt|function', '|')]
    [TestCase('StringPrototype_MethodsAreFunctions2', 'typeof String.prototype.split|function', '|')]
    [TestCase('StringPrototype_MethodsAreFunctions3', 'typeof String.prototype.toString|function', '|')]
    [TestCase('StringPrototype_MethodsAreFunctions4', 'String.prototype.hasOwnProperty("indexOf")|true', '|')]
    [TestCase('StringPrototype_CharAtCalledOnPrimitive1', 'String.prototype.charAt.call("abc", 1) === "b"|true', '|')]
    [TestCase('StringPrototype_CharAtCalledOnPrimitive2', 'String.prototype.charAt.apply("abc", [2]) === "c"|true', '|')]
    [TestCase('StringPrototype_CharAtCalledOnPrimitive3', 'String.prototype.toUpperCase.call(123) === "123"|true', '|')]
    [TestCase('StringPrototype_CharAtCalledOnObjectUsesToString1',
      'var obj = {toString: function() { return "xyz"; }};obj.charAt = ' +
      'String.prototype.charAt;obj.charAt(1) === "y"|true', '|')]
    [TestCase('StringPrototype_SplitCalledOnWrapper1', 'String.prototype.split.call(new String("a-b"), "-").length === 2|true', '|')]
    [TestCase('StringPrototype_ToStringOnWrapper_ReturnsPrimitive1',
      'String.prototype.toString.call(new String("q")) === "q"|true', '|')]
    [TestCase('StringPrototype_ToStringOnWrapper_ReturnsPrimitive2', 'String.prototype.valueOf.call("q") === "q"|true', '|')]
    [TestCase('NumberPrototype_MethodsAreFunctions1', 'typeof Number.prototype.toString|function', '|')]
    [TestCase('NumberPrototype_MethodsAreFunctions2', 'typeof Number.prototype.toFixed|function', '|')]
    [TestCase('NumberPrototype_MethodsAreFunctions3', 'typeof Number.prototype.valueOf|function', '|')]
    [TestCase('NumberPrototype_MethodsAreFunctions4', 'typeof Number.prototype.toLocaleString|function', '|')]
    [TestCase('NumberPrototype_ToStringCalledOnWrapper1', 'Number.prototype.toString.call(new Number(255), 16) === "ff"|true', '|')]
    [TestCase('NumberPrototype_ToStringCalledOnWrapper2', 'Number.prototype.toFixed.call(1.5, 2) === "1.50"|true', '|')]
    [TestCase('BooleanPrototype_ToStringAndValueOf1', 'typeof Boolean.prototype.toString|function', '|')]
    [TestCase('BooleanPrototype_ToStringAndValueOf2', 'Boolean.prototype.toString.call(true) === "true"|true', '|')]
    [TestCase('BooleanPrototype_ToStringAndValueOf3', 'Boolean.prototype.valueOf.call(new Boolean(false)) === false|true', '|')]
    [TestCase('PrimitiveMemberAccess_FindsPrototypeMethodAsValue1', '"abc".charAt === String.prototype.charAt|true', '|')]
    [TestCase('PrimitiveMemberAccess_FindsPrototypeMethodAsValue2', '(5).toFixed === Number.prototype.toFixed|true', '|')]
    [TestCase('PrimitiveMemberAccess_FindsPrototypeMethodAsValue3', 'true.toString === Boolean.prototype.toString|true', '|')]
    [TestCase('PrimitiveMemberAccess_FindsUserAddedPrototypeProperty1',
      'String.prototype.answer = 42; "abc".answer === 42|true', '|')]
    [TestCase('PrimitiveMemberAccess_FindsUserAddedPrototypeProperty2', '"abc".missing === undefined|true', '|')]
    [TestCase('PrimitiveMethodCall_UserPrototypeMethodSeesWrapperAsThis1',
      'String.prototype.shout = function() { return this.valueOf() + "!"; };"hey".shout() === ' +
      '"hey!"|true', '|')]
    [TestCase('PrimitiveMemberAccess_InheritsObjectPrototypeMethods1', '"abc".hasOwnProperty("length")|true', '|')]
    [TestCase('PrimitiveMemberAccess_InheritsObjectPrototypeMethods2', '(5).hasOwnProperty("x") === false|true', '|')]
    procedure PrototypeMethod_Script_ReturnsExpectedText(const Script: string; const Expected: string);

    [Test]
    [TestCase('StringPrototype_CallOnUndefined_ThrowsTypeError', 'String.prototype.charAt.call(undefined, 0);', '|')]
    [TestCase('StringPrototype_ToStringOnNonString_ThrowsTypeError', 'String.prototype.toString.call({});', '|')]
    [TestCase('NumberPrototype_ValueOfOnNonNumber_ThrowsTypeError', 'Number.prototype.valueOf.call("5");', '|')]
    [TestCase('BooleanPrototype_ValueOfOnNonBoolean_ThrowsTypeError', 'Boolean.prototype.valueOf.call(1);', '|')]
    procedure PrototypeMethod_InvalidReceiver_ThrowsTypeError(const Statement: string);
  end;

implementation

procedure TPrimitivePrototypeMethodTests.PrototypeMethod_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual);
end;

procedure TPrimitivePrototypeMethodTests.PrototypeMethod_InvalidReceiver_ThrowsTypeError(const Statement: string);
begin
  const Thrown = ThrowsTypeError(Statement);

  Assert.IsTrue(Thrown);
end;

end.
