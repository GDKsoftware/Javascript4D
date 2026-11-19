unit JS4D.Tests.ObjectPrototypeMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TObjectPrototypeMethodTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPlainObject1', '({}).toString() === "[object Object]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPlainObject2',
      'Object.prototype.toString.call({}) === "[object Object]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns1',
      'Object.prototype.toString.call([]) === "[object Array]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns2',
      'Object.prototype.toString.call(function() {}) === "[object Function]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns3',
      'Object.prototype.toString.call(new Date(0)) === "[object Date]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns4',
      'Object.prototype.toString.call(/a/) === "[object RegExp]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns5',
      'Object.prototype.toString.call(new Error("x")) === "[object Error]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns6',
      'Object.prototype.toString.call(Math) === "[object Math]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfBuiltIns7',
      'Object.prototype.toString.call(JSON) === "[object JSON]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPrimitives1',
      'Object.prototype.toString.call("a") === "[object String]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPrimitives2',
      'Object.prototype.toString.call(1) === "[object Number]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPrimitives3',
      'Object.prototype.toString.call(true) === "[object Boolean]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsClassOfPrimitives4',
      'Object.prototype.toString.call(new String("a")) === "[object String]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_ReportsUndefined1',
      'Object.prototype.toString.call(undefined) === "[object Undefined]"|true', '|')]
    [TestCase('ObjectPrototype_ToString_WorksAsBorrowedMethod1',
      'var x = Array(1, 2); x.getClass = Object.prototype.toString; x.getClass() === "[object ' +
      'Array]"|true', '|')]
    [TestCase('ObjectPrototype_ValueOf_ReturnsThisObject1', 'var o = {}; o.valueOf() === o|true', '|')]
    [TestCase('ObjectPrototype_ValueOf_ReturnsThisObject2', 'typeof Object.prototype.valueOf|function', '|')]
    [TestCase('ObjectPrototype_ToLocaleString_CallsToString1', '({}).toLocaleString() === "[object Object]"|true', '|')]
    [TestCase('ObjectPrototype_ToLocaleString_CallsToString2',
      '({toString: function() { return "custom"; }}).toLocaleString() === "custom"|true', '|')]
    [TestCase('ObjectPrototype_IsPrototypeOf_WalksPrototypeChain1',
      'function Base() {} function Derived() {} Derived.prototype = new Base();var d = new ' +
      'Derived();Base.prototype.isPrototypeOf(d) && Derived.prototype.isPrototypeOf(d) && ' +
      'Object.prototype.isPrototypeOf(d) && !d.isPrototypeOf(Base.prototype)|true', '|')]
    [TestCase('ObjectPrototype_IsPrototypeOf_IsFalseForPrimitives1', 'Object.prototype.isPrototypeOf(1)|false', '|')]
    [TestCase('ObjectPrototype_IsPrototypeOf_IsFalseForPrimitives2', 'Object.prototype.isPrototypeOf("a")|false', '|')]
    [TestCase('ObjectPrototype_IsPrototypeOf_IsFalseForPrimitives3', 'Object.prototype.isPrototypeOf()|false', '|')]
    [TestCase('ErrorPrototype_ToString_BuildsNameAndMessage1', 'new TypeError("boom").toString() === "TypeError: boom"|true', '|')]
    [TestCase('ErrorPrototype_ToString_BuildsNameAndMessage2',
      'Error.prototype.toString.call({name: "N", message: "M"}) === "N: M"|true', '|')]
    [TestCase('ErrorPrototype_ToString_BuildsNameAndMessage3', 'Error.prototype.toString.call({}) === "Error"|true', '|')]
    [TestCase('ErrorPrototype_ToString_BuildsNameAndMessage4',
      'Error.prototype.toString.call({name: "", message: "M"}) === "M"|true', '|')]
    [TestCase('RegExpPrototype_ToString_CalledWithoutRegExp_ValidReceiver1',
      'RegExp.prototype.toString.call(/a+/g) === "/a+/g"|true', '|')]
    [TestCase('FunctionPrototype_ToString_CalledOnNonFunction_ValidReceiver1', 'typeof (function() {}).toString()|string', '|')]
    [TestCase('StringMethodArgument_ObjectWithToString_UsesConvertedText1',
      '"abcdef".indexOf({toString: function() { return "cd"; }}) === 2|true', '|')]
    [TestCase('Sloppy',
      'Object.prototype.toString.call((function() { return arguments; })(1, 2)) === "[object ' +
      'Arguments]"|true', '|')]
    [TestCase('Strict',
      'Object.prototype.toString.call((function() { "use strict"; return arguments; })(1, 2)) === ' +
      '"[object Arguments]"|true', '|')]
    [TestCase('StringConversion', 'String((function() { return arguments; })()) === "[object Arguments]"|true', '|')]
    [TestCase('ArrayEveryReceivesArguments',
      'Array.prototype.every.call((function() { return arguments; })("a", "b"), function(v, i, o) { ' +
      'return Object.prototype.toString.call(o) === "[object Arguments]"; })|true', '|')]
    procedure ObjectPrototype_Script_ReturnsExpectedText(const Script: string; const Expected: string);

    [Test]
    [TestCase('BuiltInMethod_CalledWithNew_ThrowsTypeError', 'new String.prototype.charAt();', '|')]
    [TestCase('ErrorPrototype_ToString_CalledWithoutReceiver_ThrowsTypeError',
      'var f = Error.prototype.toString; f();', '|')]
    [TestCase('RegExpPrototype_ToString_CalledWithoutRegExp_ThrowsTypeError', 'RegExp.prototype.toString.call({});', '|')]
    [TestCase('FunctionPrototype_ToString_CalledOnNonFunction_ThrowsTypeError',
      'Function.prototype.toString.call({});', '|')]
    [TestCase('StringMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError',
      '"abc".indexOf({toString: function() { return {}; }, valueOf: function() { return {}; }});', '|')]
    [TestCase('NumberMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError',
      'Number.prototype.toFixed.call(0, {valueOf: undefined, toString: undefined});', '|')]
    procedure ObjectPrototype_InvalidUse_ThrowsTypeError(const Statement: string);
  end;

implementation

procedure TObjectPrototypeMethodTests.ObjectPrototype_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual);
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_InvalidUse_ThrowsTypeError(const Statement: string);
begin
  const Thrown = ThrowsTypeError(Statement);

  Assert.IsTrue(Thrown);
end;

end.
