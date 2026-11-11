unit JS4D.Tests.FunctionObjects;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionObjectTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure FunctionPrototype_Typeof_IsFunction;

    [Test]
    procedure FunctionPrototype_Called_ReturnsUndefined;

    [Test]
    procedure FunctionPrototype_ObjectToString_IsFunctionClass;

    [Test]
    procedure FunctionPrototype_Length_IsOwnZero;

    [Test]
    procedure FunctionPrototype_Prototype_IsObjectPrototype;

    [Test]
    procedure FunctionPrototypeProperty_Assigned_KeepsOriginal;

    [Test]
    procedure Bind_Result_InheritsFromFunctionPrototype;

    [Test]
    procedure Bind_Result_SeesFunctionPrototypeProperties;

    [Test]
    [TestCase('Caller read', 'bound.caller')]
    [TestCase('Arguments read', 'bound.arguments')]
    [TestCase('Caller write', 'bound.caller = {}')]
    [TestCase('Arguments write', 'bound.arguments = {}')]
    procedure Bind_RestrictedProperty_ThrowsTypeError(const Access: string);

    [Test]
    procedure Bind_RestrictedProperties_AreNotOwn;

    [Test]
    procedure Bind_Construct_IsInstanceOfBoundAndTarget;

    [Test]
    [TestCase('Keys of an object literal', 'Object.keys({ x: f });')]
    [TestCase('Keys of an accessor-named literal', 'Object.keys({ get: f });')]
    [TestCase('Keys of an array literal', 'Object.keys([f]);')]
    [TestCase('Frozen object literal', 'Object.freeze({ x: f });')]
    [TestCase('Object literal assigned and dropped', 'var holder = { x: f }; holder = null;')]
    procedure Closure_HeldByDiscardedObject_KeepsItsScope(const Discard: string);

    [Test]
    procedure Apply_ArgumentsObject_PassesElements;

    [Test]
    procedure Apply_ArrayLikeObject_PassesElements;

    [Test]
    [TestCase('true', 'true')]
    [TestCase('number', '1')]
    [TestCase('string', '"abc"')]
    procedure Apply_PrimitiveArgumentList_ThrowsTypeError(const ArgumentList: string);

    [Test]
    [TestCase('null', 'null')]
    [TestCase('undefined', 'undefined')]
    procedure Apply_NullishArgumentList_PassesNoArguments(const ArgumentList: string);

    [Test]
    procedure Apply_ElementGetterThrows_PropagatesError;

    [Test]
    procedure Constructor_ObjectParameters_UseToString;

    [Test]
    procedure Constructor_ParameterConversionThrows_RunsBeforeBodyConversion;

    [Test]
    procedure Constructor_BodyConversionThrows_PropagatesError;
  end;

implementation

const
  ThrowsTypeErrorHelper =
    'function throwsTypeError(action) {' +
    '  try { action(); } catch (e) { return e instanceof TypeError; }' +
    '  return false;' +
    '}';

procedure TFunctionObjectTests.Setup;
begin
  FEngine := TJSEngine.Create;
  FEngine.Execute(ThrowsTypeErrorHelper);
end;

procedure TFunctionObjectTests.TearDown;
begin
  FEngine.Free;
end;

function TFunctionObjectTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TFunctionObjectTests.FunctionPrototype_Typeof_IsFunction;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Function.prototype === "function"'));
end;

procedure TFunctionObjectTests.FunctionPrototype_Called_ReturnsUndefined;
begin
  Assert.IsTrue(EvaluateBoolean('Function.prototype(1, 2) === undefined'));
end;

procedure TFunctionObjectTests.FunctionPrototype_ObjectToString_IsFunctionClass;
begin
  Assert.IsTrue(EvaluateBoolean('Object.prototype.toString.call(Function.prototype) === "[object Function]"'));
end;

procedure TFunctionObjectTests.FunctionPrototype_Length_IsOwnZero;
begin
  Assert.IsTrue(EvaluateBoolean('Function.prototype.hasOwnProperty("length") && Function.prototype.length === 0'));
end;

procedure TFunctionObjectTests.FunctionPrototype_Prototype_IsObjectPrototype;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(Function.prototype) === Object.prototype'));
end;

procedure TFunctionObjectTests.FunctionPrototypeProperty_Assigned_KeepsOriginal;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var original = Function.prototype; Function.prototype = {}; return Function.prototype === original; })()'));
end;

procedure TFunctionObjectTests.Bind_Result_InheritsFromFunctionPrototype;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf((function () {}).bind({})) === Function.prototype'));
end;

procedure TFunctionObjectTests.Bind_Result_SeesFunctionPrototypeProperties;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { Function.prototype.shared = 12; return (function () {}).bind({}).shared === 12; })()'));
end;

procedure TFunctionObjectTests.Bind_RestrictedProperty_ThrowsTypeError(const Access: string);
begin
  const Script = Format('(function () { var bound = (function () {}).bind(null); return throwsTypeError(function () { %s; }); })()', [Access]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TFunctionObjectTests.Bind_RestrictedProperties_AreNotOwn;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var bound = (function () {}).bind(null);' +
    ' return !bound.hasOwnProperty("caller") && !bound.hasOwnProperty("arguments"); })()'));
end;

procedure TFunctionObjectTests.Closure_HeldByDiscardedObject_KeepsItsScope(const Discard: string);
begin
  const Script = Format('(function () { var captured = 5; var f = function () { return captured; }; %s' +
                        ' return f() === 5; })()', [Discard]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TFunctionObjectTests.Bind_Construct_IsInstanceOfBoundAndTarget;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var Target = function () { this.x = 1; }; var Bound = Target.bind({ y: 2 });' +
    ' var instance = new Bound(); return instance.x === 1 && instance instanceof Bound && instance instanceof Target; })()'));
end;

procedure TFunctionObjectTests.Apply_ArgumentsObject_PassesElements;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var sum = function (a, b, c) { return a + b + c; };' +
    ' return (function () { return sum.apply(null, arguments); })(1, 2, 3) === 6; })()'));
end;

procedure TFunctionObjectTests.Apply_ArrayLikeObject_PassesElements;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var count = function () { return arguments.length + ":" + arguments[1]; };' +
    ' return count.apply(null, { length: 2, 0: "a", 1: "b" }) === "2:b"; })()'));
end;

procedure TFunctionObjectTests.Apply_PrimitiveArgumentList_ThrowsTypeError(const ArgumentList: string);
begin
  const Script = Format('throwsTypeError(function () { (function () {}).apply(null, %s); })', [ArgumentList]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TFunctionObjectTests.Apply_NullishArgumentList_PassesNoArguments(const ArgumentList: string);
begin
  const Script = Format('(function () { return arguments.length; }).apply(null, %s) === 0', [ArgumentList]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TFunctionObjectTests.Apply_ElementGetterThrows_PropagatesError;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var list = { length: 2, 0: 0, get 1() { throw "stop"; } };' +
    ' try { (function () {}).apply(null, list); } catch (e) { return e === "stop"; } return false; })()'));
end;

procedure TFunctionObjectTests.Constructor_ObjectParameters_UseToString;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var i = 0; var p = { toString: function () { return "arg" + (++i); } };' +
    ' var f = Function(p, p, p, "return arg1 + arg2 + arg3;"); return f(4, "2", "x") === "42x"; })()'));
end;

procedure TFunctionObjectTests.Constructor_ParameterConversionThrows_RunsBeforeBodyConversion;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var p = { toString: function () { throw 1; } };' +
    ' var body = { toString: function () { throw "body"; } };' +
    ' try { new Function(p, body); } catch (e) { return e === 1; } return false; })()'));
end;

procedure TFunctionObjectTests.Constructor_BodyConversionThrows_PropagatesError;
begin
  Assert.IsTrue(EvaluateBoolean(
    '(function () { var body = { toString: function () { throw 7; } };' +
    ' try { new Function(body); } catch (e) { return e === 7; } return false; })()'));
end;

end.
