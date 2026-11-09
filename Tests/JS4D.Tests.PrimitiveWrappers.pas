unit JS4D.Tests.PrimitiveWrappers;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TPrimitiveWrapperTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure NewString_IsObjectWithPrimitiveValue;

    [Test]
    procedure NewString_HasLengthAndIndexedCharacters;

    [Test]
    procedure NewString_LengthIsOwnNonEnumerableProperty;

    [Test]
    procedure NewString_InheritsStringPrototypeMethods;

    [Test]
    procedure NewNumber_IsObjectWithPrimitiveValue;

    [Test]
    procedure NewNumber_ParticipatesInArithmetic;

    [Test]
    procedure NewBoolean_IsObjectWithPrimitiveValue;

    [Test]
    procedure NewBoolean_IsAlwaysTruthy;

    [Test]
    procedure StringCalledAsFunction_ReturnsPrimitive;

    [Test]
    procedure NumberCalledAsFunction_ReturnsPrimitive;

    [Test]
    procedure BooleanCalledAsFunction_ReturnsPrimitive;

    [Test]
    procedure WrapperPrototypes_ChainToObjectPrototype;

    [Test]
    procedure WrapperInstanceOf_MatchesConstructor;

    [Test]
    procedure ObjectCalledWithPrimitive_ReturnsWrapper;
  end;

  [TestFixture]
  TPrimitivePrototypeMethodTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StringPrototype_MethodsAreFunctions;

    [Test]
    procedure StringPrototype_CharAtCalledOnPrimitive;

    [Test]
    procedure StringPrototype_CharAtCalledOnObjectUsesToString;

    [Test]
    procedure StringPrototype_CallOnUndefined_ThrowsTypeError;

    [Test]
    procedure StringPrototype_SplitCalledOnWrapper;

    [Test]
    procedure StringPrototype_ToStringOnNonString_ThrowsTypeError;

    [Test]
    procedure StringPrototype_ToStringOnWrapper_ReturnsPrimitive;

    [Test]
    procedure NumberPrototype_MethodsAreFunctions;

    [Test]
    procedure NumberPrototype_ToStringCalledOnWrapper;

    [Test]
    procedure NumberPrototype_ValueOfOnNonNumber_ThrowsTypeError;

    [Test]
    procedure BooleanPrototype_ToStringAndValueOf;

    [Test]
    procedure BooleanPrototype_ValueOfOnNonBoolean_ThrowsTypeError;

    [Test]
    procedure PrimitiveMemberAccess_FindsPrototypeMethodAsValue;

    [Test]
    procedure PrimitiveMemberAccess_FindsUserAddedPrototypeProperty;

    [Test]
    procedure PrimitiveMethodCall_UserPrototypeMethodSeesWrapperAsThis;

    [Test]
    procedure PrimitiveMemberAccess_InheritsObjectPrototypeMethods;
  end;

  [TestFixture]
  TObjectPrototypeMethodTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ObjectPrototype_ToString_ReportsClassOfPlainObject;

    [Test]
    procedure ObjectPrototype_ToString_ReportsClassOfBuiltIns;

    [Test]
    procedure ObjectPrototype_ToString_ReportsClassOfPrimitives;

    [Test]
    procedure ObjectPrototype_ToString_ReportsUndefined;

    [Test]
    procedure ObjectPrototype_ToString_WorksAsBorrowedMethod;

    [Test]
    procedure ObjectPrototype_ValueOf_ReturnsThisObject;

    [Test]
    procedure ObjectPrototype_ToLocaleString_CallsToString;

    [Test]
    procedure ObjectPrototype_IsPrototypeOf_WalksPrototypeChain;

    [Test]
    procedure ObjectPrototype_IsPrototypeOf_IsFalseForPrimitives;

    [Test]
    procedure BuiltInMethod_CalledWithNew_ThrowsTypeError;

    [Test]
    procedure ErrorPrototype_ToString_BuildsNameAndMessage;

    [Test]
    procedure ErrorPrototype_ToString_CalledWithoutReceiver_ThrowsTypeError;

    [Test]
    procedure RegExpPrototype_ToString_CalledWithoutRegExp_ThrowsTypeError;

    [Test]
    procedure FunctionPrototype_ToString_CalledOnNonFunction_ThrowsTypeError;

    [Test]
    procedure StringMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError;

    [Test]
    procedure NumberMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError;

    [Test]
    procedure StringMethodArgument_ObjectWithToString_UsesConvertedText;
  end;

implementation

{ TPrimitiveWrapperTests }

procedure TPrimitiveWrapperTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPrimitiveWrapperTests.TearDown;
begin
  FEngine.Free;
end;

function TPrimitiveWrapperTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TPrimitiveWrapperTests.NewString_IsObjectWithPrimitiveValue;
begin
  Assert.IsTrue(EvaluateBoolean('typeof new String("abc") === "object"'));
  Assert.IsTrue(EvaluateBoolean('new String("abc").valueOf() === "abc"'));
  Assert.IsTrue(EvaluateBoolean('new String("abc") + "d" === "abcd"'));
end;

procedure TPrimitiveWrapperTests.NewString_HasLengthAndIndexedCharacters;
begin
  Assert.IsTrue(EvaluateBoolean('new String("abc").length === 3'));
  Assert.IsTrue(EvaluateBoolean('new String("abc")[1] === "b"'));
  Assert.IsTrue(EvaluateBoolean('new String("abc")[3] === undefined'));
end;

procedure TPrimitiveWrapperTests.NewString_LengthIsOwnNonEnumerableProperty;
begin
  Assert.IsTrue(EvaluateBoolean('new String("abc").hasOwnProperty("length")'));
  Assert.IsTrue(EvaluateBoolean('new String("abc").hasOwnProperty("2")'));
  Assert.IsFalse(EvaluateBoolean('new String("abc").hasOwnProperty("3")'));
  Assert.IsFalse(EvaluateBoolean('new String("abc").propertyIsEnumerable("length")'));
  Assert.IsTrue(EvaluateBoolean('new String("abc").propertyIsEnumerable("0")'));
end;

procedure TPrimitiveWrapperTests.NewString_InheritsStringPrototypeMethods;
begin
  Assert.IsTrue(EvaluateBoolean('new String("abc").charAt(1) === "b"'));
  Assert.IsTrue(EvaluateBoolean('new String("a,b").split(",").length === 2'));
end;

procedure TPrimitiveWrapperTests.NewNumber_IsObjectWithPrimitiveValue;
begin
  Assert.IsTrue(EvaluateBoolean('typeof new Number(5) === "object"'));
  Assert.IsTrue(EvaluateBoolean('new Number(5).valueOf() === 5'));
  Assert.IsTrue(EvaluateBoolean('new Number().valueOf() === 0'));
end;

procedure TPrimitiveWrapperTests.NewNumber_ParticipatesInArithmetic;
begin
  Assert.IsTrue(EvaluateBoolean('new Number(5) + 1 === 6'));
  Assert.IsTrue(EvaluateBoolean('new Number(5) * 2 === 10'));
end;

procedure TPrimitiveWrapperTests.NewBoolean_IsObjectWithPrimitiveValue;
begin
  Assert.IsTrue(EvaluateBoolean('typeof new Boolean(false) === "object"'));
  Assert.IsFalse(EvaluateBoolean('new Boolean(false).valueOf()'));
  Assert.IsTrue(EvaluateBoolean('new Boolean(1).valueOf() === true'));
end;

procedure TPrimitiveWrapperTests.NewBoolean_IsAlwaysTruthy;
begin
  Assert.IsTrue(EvaluateBoolean('!!new Boolean(false)'));
  Assert.IsTrue(EvaluateBoolean('!!new Number(0)'));
  Assert.IsTrue(EvaluateBoolean('!!new String("")'));
end;

procedure TPrimitiveWrapperTests.StringCalledAsFunction_ReturnsPrimitive;
begin
  Assert.IsTrue(EvaluateBoolean('typeof String(5) === "string"'));
  Assert.IsTrue(EvaluateBoolean('String(5) === "5"'));
end;

procedure TPrimitiveWrapperTests.NumberCalledAsFunction_ReturnsPrimitive;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Number("5") === "number"'));
  Assert.IsTrue(EvaluateBoolean('Number("5") === 5'));
end;

procedure TPrimitiveWrapperTests.BooleanCalledAsFunction_ReturnsPrimitive;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Boolean(1) === "boolean"'));
  Assert.IsTrue(EvaluateBoolean('Boolean(0) === false'));
end;

procedure TPrimitiveWrapperTests.WrapperPrototypes_ChainToObjectPrototype;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(new String("a")) === String.prototype'));
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(new Number(1)) === Number.prototype'));
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(new Boolean(true)) === Boolean.prototype'));
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(String.prototype) === Object.prototype'));
end;

procedure TPrimitiveWrapperTests.WrapperInstanceOf_MatchesConstructor;
begin
  Assert.IsTrue(EvaluateBoolean('new String("a") instanceof String'));
  Assert.IsTrue(EvaluateBoolean('new Number(1) instanceof Number'));
  Assert.IsFalse(EvaluateBoolean('"a" instanceof String'));
end;

procedure TPrimitiveWrapperTests.ObjectCalledWithPrimitive_ReturnsWrapper;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Object("a") === "object"'));
  Assert.IsTrue(EvaluateBoolean('Object("a").valueOf() === "a"'));
  Assert.IsTrue(EvaluateBoolean('Object(5) instanceof Number'));
  Assert.IsTrue(EvaluateBoolean('Object(true) instanceof Boolean'));
end;

{ TPrimitivePrototypeMethodTests }

procedure TPrimitivePrototypeMethodTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPrimitivePrototypeMethodTests.TearDown;
begin
  FEngine.Free;
end;

function TPrimitivePrototypeMethodTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_MethodsAreFunctions;
begin
  Assert.IsTrue(EvaluateBoolean('typeof String.prototype.charAt === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof String.prototype.split === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof String.prototype.toString === "function"'));
  Assert.IsTrue(EvaluateBoolean('String.prototype.hasOwnProperty("indexOf")'));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_CharAtCalledOnPrimitive;
begin
  Assert.IsTrue(EvaluateBoolean('String.prototype.charAt.call("abc", 1) === "b"'));
  Assert.IsTrue(EvaluateBoolean('String.prototype.charAt.apply("abc", [2]) === "c"'));
  Assert.IsTrue(EvaluateBoolean('String.prototype.toUpperCase.call(123) === "123"'));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_CharAtCalledOnObjectUsesToString;
begin
  const Script = 'var obj = {toString: function() { return "xyz"; }};' +
                 'obj.charAt = String.prototype.charAt;' +
                 'obj.charAt(1) === "y"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_CallOnUndefined_ThrowsTypeError;
begin
  const Script = 'var caught = "none";' +
                 'try { String.prototype.charAt.call(undefined, 0); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught === true';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_SplitCalledOnWrapper;
begin
  Assert.IsTrue(EvaluateBoolean('String.prototype.split.call(new String("a-b"), "-").length === 2'));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_ToStringOnNonString_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { String.prototype.toString.call({}); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.StringPrototype_ToStringOnWrapper_ReturnsPrimitive;
begin
  Assert.IsTrue(EvaluateBoolean('String.prototype.toString.call(new String("q")) === "q"'));
  Assert.IsTrue(EvaluateBoolean('String.prototype.valueOf.call("q") === "q"'));
end;

procedure TPrimitivePrototypeMethodTests.NumberPrototype_MethodsAreFunctions;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Number.prototype.toString === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Number.prototype.toFixed === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Number.prototype.valueOf === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Number.prototype.toLocaleString === "function"'));
end;

procedure TPrimitivePrototypeMethodTests.NumberPrototype_ToStringCalledOnWrapper;
begin
  Assert.IsTrue(EvaluateBoolean('Number.prototype.toString.call(new Number(255), 16) === "ff"'));
  Assert.IsTrue(EvaluateBoolean('Number.prototype.toFixed.call(1.5, 2) === "1.50"'));
end;

procedure TPrimitivePrototypeMethodTests.NumberPrototype_ValueOfOnNonNumber_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { Number.prototype.valueOf.call("5"); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.BooleanPrototype_ToStringAndValueOf;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Boolean.prototype.toString === "function"'));
  Assert.IsTrue(EvaluateBoolean('Boolean.prototype.toString.call(true) === "true"'));
  Assert.IsTrue(EvaluateBoolean('Boolean.prototype.valueOf.call(new Boolean(false)) === false'));
end;

procedure TPrimitivePrototypeMethodTests.BooleanPrototype_ValueOfOnNonBoolean_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { Boolean.prototype.valueOf.call(1); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.PrimitiveMemberAccess_FindsPrototypeMethodAsValue;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".charAt === String.prototype.charAt'));
  Assert.IsTrue(EvaluateBoolean('(5).toFixed === Number.prototype.toFixed'));
  Assert.IsTrue(EvaluateBoolean('true.toString === Boolean.prototype.toString'));
end;

procedure TPrimitivePrototypeMethodTests.PrimitiveMemberAccess_FindsUserAddedPrototypeProperty;
begin
  Assert.IsTrue(EvaluateBoolean('String.prototype.answer = 42; "abc".answer === 42'));
  Assert.IsTrue(EvaluateBoolean('"abc".missing === undefined'));
end;

procedure TPrimitivePrototypeMethodTests.PrimitiveMethodCall_UserPrototypeMethodSeesWrapperAsThis;
begin
  const Script = 'String.prototype.shout = function() { return this.valueOf() + "!"; };' +
                 '"hey".shout() === "hey!"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPrimitivePrototypeMethodTests.PrimitiveMemberAccess_InheritsObjectPrototypeMethods;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".hasOwnProperty("length")'));
  Assert.IsTrue(EvaluateBoolean('(5).hasOwnProperty("x") === false'));
end;

{ TObjectPrototypeMethodTests }

procedure TObjectPrototypeMethodTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TObjectPrototypeMethodTests.TearDown;
begin
  FEngine.Free;
end;

function TObjectPrototypeMethodTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToString_ReportsClassOfPlainObject;
begin
  Assert.IsTrue(EvaluateBoolean('({}).toString() === "[object Object]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call({}) === "[object Object]"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToString_ReportsClassOfBuiltIns;
begin
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call([]) === "[object Array]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(function() {}) === "[object Function]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(new Date(0)) === "[object Date]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(/a/) === "[object RegExp]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(new Error("x")) === "[object Error]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(Math) === "[object Math]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(JSON) === "[object JSON]"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToString_ReportsClassOfPrimitives;
begin
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call("a") === "[object String]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(1) === "[object Number]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(true) === "[object Boolean]"'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(new String("a")) === "[object String]"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToString_ReportsUndefined;
begin
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(undefined) === "[object Undefined]"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToString_WorksAsBorrowedMethod;
begin
  const Script = 'var x = Array(1, 2); x.getClass = Object.prototype.toString; x.getClass() === "[object Array]"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ValueOf_ReturnsThisObject;
begin
  Assert.IsTrue(EvaluateBoolean('var o = {}; o.valueOf() === o'));
  Assert.IsTrue(EvaluateBoolean('typeof Object.prototype.valueOf === "function"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_ToLocaleString_CallsToString;
begin
  Assert.IsTrue(EvaluateBoolean('({}).toLocaleString() === "[object Object]"'));
  Assert.IsTrue(EvaluateBoolean('({toString: function() { return "custom"; }}).toLocaleString() === "custom"'));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_IsPrototypeOf_WalksPrototypeChain;
begin
  const Script = 'function Base() {} function Derived() {} Derived.prototype = new Base();' +
                 'var d = new Derived();' +
                 'Base.prototype.isPrototypeOf(d) && Derived.prototype.isPrototypeOf(d) && ' +
                 'Object.prototype.isPrototypeOf(d) && !d.isPrototypeOf(Base.prototype)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.ObjectPrototype_IsPrototypeOf_IsFalseForPrimitives;
begin
  Assert.IsFalse(EvaluateBoolean('Object.prototype.isPrototypeOf(1)'));
  Assert.IsFalse(EvaluateBoolean('Object.prototype.isPrototypeOf("a")'));
  Assert.IsFalse(EvaluateBoolean('Object.prototype.isPrototypeOf()'));
end;

procedure TObjectPrototypeMethodTests.BuiltInMethod_CalledWithNew_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { new String.prototype.charAt(); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.ErrorPrototype_ToString_BuildsNameAndMessage;
begin
  Assert.IsTrue(EvaluateBoolean('new TypeError("boom").toString() === "TypeError: boom"'));
  Assert.IsTrue(EvaluateBoolean('Error.prototype.toString.call({name: "N", message: "M"}) === "N: M"'));
  Assert.IsTrue(EvaluateBoolean('Error.prototype.toString.call({}) === "Error"'));
  Assert.IsTrue(EvaluateBoolean('Error.prototype.toString.call({name: "", message: "M"}) === "M"'));
end;

procedure TObjectPrototypeMethodTests.ErrorPrototype_ToString_CalledWithoutReceiver_ThrowsTypeError;
begin
  const Script = 'var caught = false; var f = Error.prototype.toString;' +
                 'try { f(); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.RegExpPrototype_ToString_CalledWithoutRegExp_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { RegExp.prototype.toString.call({}); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
  Assert.IsTrue(EvaluateBoolean('RegExp.prototype.toString.call(/a+/g) === "/a+/g"'));
end;

procedure TObjectPrototypeMethodTests.FunctionPrototype_ToString_CalledOnNonFunction_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { Function.prototype.toString.call({}); } catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
  Assert.IsTrue(EvaluateBoolean('typeof (function() {}).toString() === "string"'));
end;

procedure TObjectPrototypeMethodTests.StringMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { "abc".indexOf({toString: function() { return {}; }, valueOf: function() { return {}; }}); }' +
                 'catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.NumberMethodArgument_ObjectWithoutPrimitive_ThrowsTypeError;
begin
  const Script = 'var caught = false;' +
                 'try { Number.prototype.toFixed.call(0, {valueOf: undefined, toString: undefined}); }' +
                 'catch (e) { caught = e instanceof TypeError; }' +
                 'caught';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TObjectPrototypeMethodTests.StringMethodArgument_ObjectWithToString_UsesConvertedText;
begin
  Assert.IsTrue(EvaluateBoolean('"abcdef".indexOf({toString: function() { return "cd"; }}) === 2'));
end;

end.
