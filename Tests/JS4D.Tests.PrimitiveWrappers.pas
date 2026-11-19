unit JS4D.Tests.PrimitiveWrappers;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TPrimitiveWrapperTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('NewString_IsObjectWithPrimitiveValue1', 'typeof new String("abc")|object', '|')]
    [TestCase('NewString_IsObjectWithPrimitiveValue2', 'new String("abc").valueOf() === "abc"|true', '|')]
    [TestCase('NewString_IsObjectWithPrimitiveValue3', 'new String("abc") + "d" === "abcd"|true', '|')]
    [TestCase('NewString_HasLengthAndIndexedCharacters1', 'new String("abc").length === 3|true', '|')]
    [TestCase('NewString_HasLengthAndIndexedCharacters2', 'new String("abc")[1] === "b"|true', '|')]
    [TestCase('NewString_HasLengthAndIndexedCharacters3', 'new String("abc")[3] === undefined|true', '|')]
    [TestCase('NewString_LengthIsOwnNonEnumerableProperty1', 'new String("abc").hasOwnProperty("length")|true', '|')]
    [TestCase('NewString_LengthIsOwnNonEnumerableProperty2', 'new String("abc").hasOwnProperty("2")|true', '|')]
    [TestCase('NewString_LengthIsOwnNonEnumerableProperty3', 'new String("abc").hasOwnProperty("3")|false', '|')]
    [TestCase('NewString_LengthIsOwnNonEnumerableProperty4', 'new String("abc").propertyIsEnumerable("length")|false', '|')]
    [TestCase('NewString_LengthIsOwnNonEnumerableProperty5', 'new String("abc").propertyIsEnumerable("0")|true', '|')]
    [TestCase('NewString_InheritsStringPrototypeMethods1', 'new String("abc").charAt(1) === "b"|true', '|')]
    [TestCase('NewString_InheritsStringPrototypeMethods2', 'new String("a,b").split(",").length === 2|true', '|')]
    [TestCase('NewNumber_IsObjectWithPrimitiveValue1', 'typeof new Number(5)|object', '|')]
    [TestCase('NewNumber_IsObjectWithPrimitiveValue2', 'new Number(5).valueOf() === 5|true', '|')]
    [TestCase('NewNumber_IsObjectWithPrimitiveValue3', 'new Number().valueOf() === 0|true', '|')]
    [TestCase('NewNumber_ParticipatesInArithmetic1', 'new Number(5) + 1 === 6|true', '|')]
    [TestCase('NewNumber_ParticipatesInArithmetic2', 'new Number(5) * 2 === 10|true', '|')]
    [TestCase('NewBoolean_IsObjectWithPrimitiveValue1', 'typeof new Boolean(false)|object', '|')]
    [TestCase('NewBoolean_IsObjectWithPrimitiveValue2', 'new Boolean(false).valueOf()|false', '|')]
    [TestCase('NewBoolean_IsObjectWithPrimitiveValue3', 'new Boolean(1).valueOf() === true|true', '|')]
    [TestCase('NewBoolean_IsAlwaysTruthy1', '!!new Boolean(false)|true', '|')]
    [TestCase('NewBoolean_IsAlwaysTruthy2', '!!new Number(0)|true', '|')]
    [TestCase('NewBoolean_IsAlwaysTruthy3', '!!new String("")|true', '|')]
    [TestCase('StringCalledAsFunction_ReturnsPrimitive1', 'typeof String(5)|string', '|')]
    [TestCase('StringCalledAsFunction_ReturnsPrimitive2', 'String(5) === "5"|true', '|')]
    [TestCase('NumberCalledAsFunction_ReturnsPrimitive1', 'typeof Number("5")|number', '|')]
    [TestCase('NumberCalledAsFunction_ReturnsPrimitive2', 'Number("5") === 5|true', '|')]
    [TestCase('BooleanCalledAsFunction_ReturnsPrimitive1', 'typeof Boolean(1)|boolean', '|')]
    [TestCase('BooleanCalledAsFunction_ReturnsPrimitive2', 'Boolean(0) === false|true', '|')]
    [TestCase('WrapperPrototypes_ChainToObjectPrototype1', 'Object.getPrototypeOf(new String("a")) === String.prototype|true', '|')]
    [TestCase('WrapperPrototypes_ChainToObjectPrototype2', 'Object.getPrototypeOf(new Number(1)) === Number.prototype|true', '|')]
    [TestCase('WrapperPrototypes_ChainToObjectPrototype3',
      'Object.getPrototypeOf(new Boolean(true)) === Boolean.prototype|true', '|')]
    [TestCase('WrapperPrototypes_ChainToObjectPrototype4', 'Object.getPrototypeOf(String.prototype) === Object.prototype|true', '|')]
    [TestCase('WrapperInstanceOf_MatchesConstructor1', 'new String("a") instanceof String|true', '|')]
    [TestCase('WrapperInstanceOf_MatchesConstructor2', 'new Number(1) instanceof Number|true', '|')]
    [TestCase('WrapperInstanceOf_MatchesConstructor3', '"a" instanceof String|false', '|')]
    [TestCase('ObjectCalledWithPrimitive_ReturnsWrapper1', 'typeof Object("a")|object', '|')]
    [TestCase('ObjectCalledWithPrimitive_ReturnsWrapper2', 'Object("a").valueOf() === "a"|true', '|')]
    [TestCase('ObjectCalledWithPrimitive_ReturnsWrapper3', 'Object(5) instanceof Number|true', '|')]
    [TestCase('ObjectCalledWithPrimitive_ReturnsWrapper4', 'Object(true) instanceof Boolean|true', '|')]
    procedure Wrapper_Script_ReturnsExpectedText(const Script: string; const Expected: string);
  end;

implementation

procedure TPrimitiveWrapperTests.Wrapper_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual);
end;

end.
