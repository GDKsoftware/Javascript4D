unit JS4D.Tests.BuiltinPrototypes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TBuiltinPrototypeTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Function_IsGlobalFunction;

    [Test]
    procedure InstanceOf_Function_IsTrueForFunctions;

    [Test]
    procedure FunctionPrototype_Call_InvokesTargetWithThisAndArguments;

    [Test]
    procedure FunctionPrototype_Apply_InvokesTargetWithArgumentArray;

    [Test]
    procedure FunctionPrototype_Call_OnNonFunction_ThrowsTypeError;

    [Test]
    procedure FunctionPrototype_CallBind_UncurriesArrayJoin;

    [Test]
    procedure FunctionPrototype_CallBind_UncurriesArrayPush;

    [Test]
    procedure FunctionPrototype_CallBind_UncurriesHasOwnProperty;

    [Test]
    procedure FunctionPrototype_CallBind_UncurriesPropertyIsEnumerable;

    [Test]
    procedure ArrayPrototype_Slice_CalledOnArray;

    [Test]
    procedure ArrayPrototype_Map_CallsCallback;

    [Test]
    procedure ArrayPrototype_Join_OnNonArray_ThrowsTypeError;

    [Test]
    procedure ObjectPrototype_HasOwnProperty_CalledOnObject;
  end;

implementation

procedure TBuiltinPrototypeTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TBuiltinPrototypeTests.TearDown;
begin
  FEngine.Free;
end;

function TBuiltinPrototypeTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TBuiltinPrototypeTests.Function_IsGlobalFunction;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Function === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Function.prototype === "object"'));
end;

procedure TBuiltinPrototypeTests.InstanceOf_Function_IsTrueForFunctions;
begin
  Assert.IsTrue(EvaluateBoolean('(function () {}) instanceof Function'));
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_Call_InvokesTargetWithThisAndArguments;
begin
  FEngine.Execute('function add(a) { return this.x + a; }');

  Assert.AreEqual(3.0, FEngine.Evaluate('Function.prototype.call.call(add, { x: 1 }, 2)').AsNumber);
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_Apply_InvokesTargetWithArgumentArray;
begin
  FEngine.Execute('function add(a, b) { return this.x + a + b; }');

  Assert.AreEqual(6.0, FEngine.Evaluate('Function.prototype.apply.call(add, { x: 1 }, [2, 3])').AsNumber);
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_Call_OnNonFunction_ThrowsTypeError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Evaluate('Function.prototype.call.call({})');
    end,
    EJSTypeError);
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_CallBind_UncurriesArrayJoin;
begin
  FEngine.Execute('var join = Function.prototype.call.bind(Array.prototype.join);');

  Assert.AreEqual('1-2-3', FEngine.Evaluate('join([1, 2, 3], "-")').AsString);
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_CallBind_UncurriesArrayPush;
begin
  FEngine.Execute('var push = Function.prototype.call.bind(Array.prototype.push); var list = [1]; push(list, 2);');

  Assert.AreEqual(2.0, FEngine.Evaluate('list.length').AsNumber);
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_CallBind_UncurriesHasOwnProperty;
begin
  FEngine.Execute('var has = Function.prototype.call.bind(Object.prototype.hasOwnProperty);');

  Assert.IsTrue(EvaluateBoolean('has({ a: 1 }, "a")'));
  Assert.IsFalse(EvaluateBoolean('has({ a: 1 }, "b")'));
end;

procedure TBuiltinPrototypeTests.FunctionPrototype_CallBind_UncurriesPropertyIsEnumerable;
begin
  FEngine.Execute(
    'var enumerable = Function.prototype.call.bind(Object.prototype.propertyIsEnumerable); ' +
    'var target = { a: 1 }; Object.defineProperty(target, "hidden", { value: 2, enumerable: false });');

  Assert.IsTrue(EvaluateBoolean('enumerable(target, "a")'));
  Assert.IsFalse(EvaluateBoolean('enumerable(target, "hidden")'));
  Assert.IsFalse(EvaluateBoolean('enumerable(target, "missing")'));
end;

procedure TBuiltinPrototypeTests.ArrayPrototype_Slice_CalledOnArray;
begin
  Assert.AreEqual(2.0, FEngine.Evaluate('Array.prototype.slice.call([1, 2, 3], 1).length').AsNumber);
end;

procedure TBuiltinPrototypeTests.ArrayPrototype_Map_CallsCallback;
begin
  Assert.AreEqual('2,4',
    FEngine.Evaluate('Array.prototype.map.call([1, 2], function (n) { return n * 2; }).join(",")').AsString);
end;

procedure TBuiltinPrototypeTests.ArrayPrototype_Join_OnNonArray_ThrowsTypeError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Evaluate('Array.prototype.join.call({})');
    end,
    EJSTypeError);
end;

procedure TBuiltinPrototypeTests.ObjectPrototype_HasOwnProperty_CalledOnObject;
begin
  Assert.IsTrue(EvaluateBoolean('Object.prototype.hasOwnProperty.call({ a: 1 }, "a")'));
end;

end.
