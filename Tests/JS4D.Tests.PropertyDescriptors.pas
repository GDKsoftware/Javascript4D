unit JS4D.Tests.PropertyDescriptors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TPropertyDescriptorTests = class
  private
    FEngine: TJSEngine;

    function EvaluateNumber(const Script: string): Double;
    function EvaluateBoolean(const Script: string): Boolean;
    function ThrowsTypeError(const Statement: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure DefineProperty_Getter_IsInvokedOnRead;

    [Test]
    procedure DefineProperty_GetterReceivesInstanceAsThis;

    [Test]
    procedure DefineProperty_Setter_IsInvokedOnWrite;

    [Test]
    procedure DefineProperty_AccessorOnPrototype_UsesInstanceAsThis;

    [Test]
    procedure DefineProperty_DataDescriptorWithoutAttributes_DefaultsToFalse;

    [Test]
    procedure DefineProperty_GetterAndValue_ThrowsTypeError;

    [Test]
    procedure DefineProperty_NonCallableGetter_ThrowsTypeError;

    [Test]
    procedure DefineProperty_NonObjectTarget_ThrowsTypeError;

    [Test]
    procedure DefineProperty_NonObjectDescriptor_ThrowsTypeError;

    [Test]
    procedure DefineProperty_ChangeNonConfigurableValue_ThrowsTypeError;

    [Test]
    procedure DefineProperty_SameValueOnNonConfigurable_Succeeds;

    [Test]
    procedure DefineProperty_PartialDescriptor_KeepsExistingAttributes;

    [Test]
    procedure DefineProperty_OnNonExtensibleObject_ThrowsTypeError;

    [Test]
    procedure DefineProperty_ConvertDataToAccessor_KeepsEnumerableAndConfigurable;

    [Test]
    procedure GetOwnPropertyDescriptor_DataProperty_ReturnsAllFields;

    [Test]
    procedure GetOwnPropertyDescriptor_Accessor_ReturnsGetAndSet;

    [Test]
    procedure GetOwnPropertyDescriptor_Undefined_ThrowsTypeError;

    [Test]
    procedure GetOwnPropertyDescriptor_Primitive_ReturnsUndefined;

    [Test]
    procedure DefineProperty_ArrayLength_CanBeMadeNonWritable;

    [Test]
    procedure DefineProperty_ArrayLength_TruncatesArray;

    [Test]
    procedure ForIn_SkipsNonEnumerableProperties;

    [Test]
    procedure Throw_EngineTypeError_IsCaughtAsTypeErrorObject;

    [Test]
    procedure GlobalCode_This_IsGlobalObjectInStrictMode;

    [Test]
    procedure Delete_NonConfigurableProperty_KeepsPropertyAndReturnsFalse;

    [Test]
    procedure ObjectLiteral_DefinesOwnPropertyDespiteInheritedReadOnly;

    [Test]
    procedure HasOwnProperty_InheritedProperty_ReturnsFalse;

    [Test]
    procedure Literals_InheritFromIntrinsicPrototypes;

    [Test]
    procedure ArrayCallback_ThisArg_IsPassedToCallback;

    [Test]
    procedure GetOwnPropertyDescriptor_MissingProperty_ReturnsUndefined;

    [Test]
    procedure DefineProperties_DefinesEveryProperty;

    [Test]
    procedure DefineProperties_InvalidDescriptor_DefinesNothing;

    [Test]
    procedure DefineProperties_NonObjectTarget_ThrowsTypeError;

    [Test]
    procedure DefineProperties_IgnoresNonEnumerableDescriptorKeys;

    [Test]
    procedure Create_WithProperties_DefinesThem;

    [Test]
    procedure Create_NonObjectPrototype_ThrowsTypeError;
  end;

implementation

procedure TPropertyDescriptorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPropertyDescriptorTests.TearDown;
begin
  FEngine.Free;
end;

function TPropertyDescriptorTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).AsNumber;
end;

function TPropertyDescriptorTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

function TPropertyDescriptorTests.ThrowsTypeError(const Statement: string): Boolean;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { ' + Statement + ' } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown';

  Result := EvaluateBoolean(Script);
end;

procedure TPropertyDescriptorTests.DefineProperty_Getter_IsInvokedOnRead;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'Object.defineProperty(o, "x", { get: function () { return 7; } });' + sLineBreak +
    'o.x';

  Assert.AreEqual(7.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_GetterReceivesInstanceAsThis;
begin
  const Script =
    'var o = { base: 4 };' + sLineBreak +
    'Object.defineProperty(o, "x", { get: function () { return this.base + 1; } });' + sLineBreak +
    'o.x';

  Assert.AreEqual(5.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_Setter_IsInvokedOnWrite;
begin
  const Script =
    'var o = { stored: 0 };' + sLineBreak +
    'Object.defineProperty(o, "x", { set: function (v) { this.stored = v * 2; } });' + sLineBreak +
    'o.x = 6;' + sLineBreak +
    'o.stored';

  Assert.AreEqual(12.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_AccessorOnPrototype_UsesInstanceAsThis;
begin
  const Script =
    'var proto = {};' + sLineBreak +
    'Object.defineProperty(proto, "x", { get: function () { return this.base; } });' + sLineBreak +
    'var child = Object.create(proto);' + sLineBreak +
    'child.base = 9;' + sLineBreak +
    'child.x';

  Assert.AreEqual(9.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_DataDescriptorWithoutAttributes_DefaultsToFalse;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'Object.defineProperty(o, "x", { value: 1 });' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    '!d.writable && !d.enumerable && !d.configurable && d.value === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_GetterAndValue_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.defineProperty(o, "x", { get: function () {}, value: 1 });'));
end;

procedure TPropertyDescriptorTests.DefineProperty_NonCallableGetter_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.defineProperty(o, "x", { get: 5 });'));
end;

procedure TPropertyDescriptorTests.DefineProperty_NonObjectTarget_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.defineProperty(1, "x", {});'));
end;

procedure TPropertyDescriptorTests.DefineProperty_NonObjectDescriptor_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.defineProperty(o, "x", 1);'));
end;

procedure TPropertyDescriptorTests.DefineProperty_ChangeNonConfigurableValue_ThrowsTypeError;
begin
  const Statement =
    'Object.defineProperty(o, "x", { value: 1 });' +
    'Object.defineProperty(o, "x", { value: 2 });';

  Assert.IsTrue(ThrowsTypeError(Statement));
end;

procedure TPropertyDescriptorTests.DefineProperty_SameValueOnNonConfigurable_Succeeds;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'Object.defineProperty(o, "x", { value: 1 });' + sLineBreak +
    'Object.defineProperty(o, "x", { value: 1 });' + sLineBreak +
    'o.x';

  Assert.AreEqual(1.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_PartialDescriptor_KeepsExistingAttributes;
begin
  const Script =
    'var o = { x: 1 };' + sLineBreak +
    'Object.defineProperty(o, "x", { enumerable: false });' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.value === 1 && d.writable && d.configurable && !d.enumerable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_OnNonExtensibleObject_ThrowsTypeError;
begin
  const Statement =
    'Object.preventExtensions(o);' +
    'Object.defineProperty(o, "x", { value: 1 });';

  Assert.IsTrue(ThrowsTypeError(Statement));
end;

procedure TPropertyDescriptorTests.DefineProperty_ConvertDataToAccessor_KeepsEnumerableAndConfigurable;
begin
  const Script =
    'var o = { x: 1 };' + sLineBreak +
    'Object.defineProperty(o, "x", { get: function () { return 3; } });' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.enumerable && d.configurable && o.x === 3 && d.set === undefined';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.GetOwnPropertyDescriptor_DataProperty_ReturnsAllFields;
begin
  const Script =
    'var o = { x: 5 };' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.value === 5 && d.writable === true && d.enumerable === true && d.configurable === true';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.GetOwnPropertyDescriptor_Accessor_ReturnsGetAndSet;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'var g = function () {};' + sLineBreak +
    'Object.defineProperty(o, "x", { get: g, configurable: true });' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.get === g && d.set === undefined && !("value" in d) && !("writable" in d) && d.configurable === true';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.GetOwnPropertyDescriptor_Undefined_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.getOwnPropertyDescriptor(undefined, "x");'));
end;

procedure TPropertyDescriptorTests.GetOwnPropertyDescriptor_Primitive_ReturnsUndefined;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getOwnPropertyDescriptor(1, "x") === undefined'));
end;

procedure TPropertyDescriptorTests.DefineProperty_ArrayLength_CanBeMadeNonWritable;
begin
  const Script =
    'var a = [1, 2, 3];' + sLineBreak +
    'Object.defineProperty(a, "length", { writable: false });' + sLineBreak +
    'Object.defineProperty(a, "length", { value: 3 });' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(a, "length");' + sLineBreak +
    'd.value === 3 && d.writable === false && d.configurable === false';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.DefineProperty_ArrayLength_TruncatesArray;
begin
  const Script =
    'var a = [1, 2, 3];' + sLineBreak +
    'Object.defineProperty(a, "length", { value: 1 });' + sLineBreak +
    'a.length';

  Assert.AreEqual(1.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.ForIn_SkipsNonEnumerableProperties;
begin
  const Script =
    'var o = { visible: 1 };' + sLineBreak +
    'Object.defineProperty(o, "hidden", { value: 2 });' + sLineBreak +
    'var seen = "";' + sLineBreak +
    'for (var key in o) { seen += key; }' + sLineBreak +
    'seen === "visible"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.Throw_EngineTypeError_IsCaughtAsTypeErrorObject;
begin
  const Script =
    'var caught;' + sLineBreak +
    'try { Object.defineProperty(1, "x", {}); } catch (e) { caught = e; }' + sLineBreak +
    'caught.constructor === TypeError && typeof caught.message === "string"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.HasOwnProperty_InheritedProperty_ReturnsFalse;
begin
  const Script =
    'var parent = { inherited: 1 };' + sLineBreak +
    'var child = Object.create(parent);' + sLineBreak +
    '!child.hasOwnProperty("inherited") && parent.hasOwnProperty("inherited")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.Literals_InheritFromIntrinsicPrototypes;
begin
  const Script =
    'Object.prototype.fromObject = 1;' + sLineBreak +
    'Function.prototype.fromFunction = 2;' + sLineBreak +
    'Array.prototype.fromArray = 3;' + sLineBreak +
    'function f() {}' + sLineBreak +
    '({}).fromObject === 1 && f.fromFunction === 2 && [].fromArray === 3 && [].fromObject === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.ArrayCallback_ThisArg_IsPassedToCallback;
begin
  const Script =
    '"use strict";' + sLineBreak +
    'var target = {};' + sLineBreak +
    'var matched = false;' + sLineBreak +
    '[1].forEach(function () { matched = (this === target); }, target);' + sLineBreak +
    'matched';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.Delete_NonConfigurableProperty_KeepsPropertyAndReturnsFalse;
begin
  const Script =
    'var o = { a: 1 };' + sLineBreak +
    'Object.freeze(o);' + sLineBreak +
    'var removed = delete o.a;' + sLineBreak +
    'removed === false && o.hasOwnProperty("a")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.ObjectLiteral_DefinesOwnPropertyDespiteInheritedReadOnly;
begin
  const Script =
    'Object.defineProperty(Object.prototype, "shadowed", { value: 100, writable: false, configurable: true });' + sLineBreak +
    'var o = { shadowed: 12 };' + sLineBreak +
    'o.hasOwnProperty("shadowed") && o.shadowed === 12';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.GlobalCode_This_IsGlobalObjectInStrictMode;
begin
  const Script =
    '"use strict";' + sLineBreak +
    'this !== undefined';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.GetOwnPropertyDescriptor_MissingProperty_ReturnsUndefined;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getOwnPropertyDescriptor({}, "x") === undefined'));
end;

procedure TPropertyDescriptorTests.DefineProperties_DefinesEveryProperty;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'var result = Object.defineProperties(o, { a: { value: 1 }, b: { get: function () { return 2; } } });' + sLineBreak +
    'result === o && o.a + o.b === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.DefineProperties_InvalidDescriptor_DefinesNothing;
begin
  const Script =
    'var o = {};' + sLineBreak +
    'try { Object.defineProperties(o, { a: { value: 1 }, b: 5 }); } catch (e) {}' + sLineBreak +
    '!o.hasOwnProperty("a")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.DefineProperties_NonObjectTarget_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.defineProperties(1, {});'));
end;

procedure TPropertyDescriptorTests.DefineProperties_IgnoresNonEnumerableDescriptorKeys;
begin
  const Script =
    'var props = {};' + sLineBreak +
    'Object.defineProperty(props, "hidden", { value: { value: 1 }, enumerable: false });' + sLineBreak +
    'var o = {};' + sLineBreak +
    'Object.defineProperties(o, props);' + sLineBreak +
    '!o.hasOwnProperty("hidden")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TPropertyDescriptorTests.Create_WithProperties_DefinesThem;
begin
  const Script =
    'var proto = { inherited: 1 };' + sLineBreak +
    'var o = Object.create(proto, { own: { value: 2, enumerable: true } });' + sLineBreak +
    'o.inherited + o.own';

  Assert.AreEqual(3.0, EvaluateNumber(Script));
end;

procedure TPropertyDescriptorTests.Create_NonObjectPrototype_ThrowsTypeError;
begin
  Assert.IsTrue(ThrowsTypeError('Object.create(1);'));
end;

end.
