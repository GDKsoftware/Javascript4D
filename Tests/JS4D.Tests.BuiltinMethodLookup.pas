unit JS4D.Tests.BuiltinMethodLookup;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TBuiltinMethodLookupTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure ArrayMethod_OwnPropertyReplacesIt_RunsTheReplacement;

    [Test]
    procedure ArrayMethod_PrototypeReplacesIt_RunsTheReplacement;

    [Test]
    procedure ArrayToString_PrototypeUsesObjectToString_ReturnsClassTag;

    [Test]
    procedure FunctionCall_OwnPropertyReplacesIt_RunsTheReplacement;

    [Test]
    procedure HasOwnProperty_OwnPropertyReplacesIt_RunsTheReplacement;

    [Test]
    procedure PushAndPop_PrototypeValueReplacedAndRestored_FollowsTheCurrentValue;

    [Test]
    procedure PushAndPop_PrototypeMethodDeletedAndAddedAgain_FollowsTheCurrentMethod;

    [Test]
    procedure Push_PrototypeHoldsElements_StoresTheElementOnTheArray;

    [Test]
    procedure ArrayProperty_InheritedAccessor_ReceivesTheArray;

    [Test]
    procedure ArrayProperty_InheritedFromObjectPrototype_ReadsTheValue;

    [Test]
    procedure ArrayProperty_WithoutPrototype_IsUndefined;

    [Test]
    procedure BuiltinMethods_NotReplaced_RunTheBuiltin;

    [Test]
    [TestCase('Descriptor', 'Object.getOwnPropertyDescriptor({ a: 1 }, "a")', '#')]
    [TestCase('Descriptors', 'Object.getOwnPropertyDescriptors({ a: 1 }).a', '#')]
    procedure DescriptorObject_Expression_InheritsFromObjectPrototype(const Expression: string);

    [Test]
    procedure ArrayPush_InFunction_AppendsInOrder;

    [Test]
    procedure PropertyRead_OwnDataProperty_ReturnsValue;

    [Test]
    procedure PropertyRead_InheritedProperty_ReturnsPrototypeValue;

    [Test]
    procedure PropertyRead_OwnPropertyShadowsInherited_ReturnsOwnValue;

    [Test]
    procedure PropertyRead_OwnAccessor_InvokesGetterWithObjectAsThis;

    [Test]
    procedure PropertyRead_MissingProperty_IsUndefined;

    [Test]
    procedure PropertyRead_NamedPropertyOnArray_KeepsElementsAndLength;

    [Test]
    procedure PropertyRead_LengthAndIndexOfStringWrapper_ReadsPrimitive;

    [Test]
    procedure PropertyRead_DeletedProperty_IsUndefined;

    [Test]
    procedure PropertyRead_ReadOnlyProperty_ReadsValueAndIgnoresWrite;
  end;

implementation

procedure TBuiltinMethodLookupTests.ArrayMethod_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var a = [1, 2]; a.push = function() { return "own"; }; a.push(3)';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('own', Actual);
end;

procedure TBuiltinMethodLookupTests.ArrayMethod_PrototypeReplacesIt_RunsTheReplacement;
begin
  const Script = 'var original = Array.prototype.indexOf;' +
                 'Array.prototype.indexOf = function() { return "proto"; };' +
                 'var result = [1].indexOf(1);' +
                 'Array.prototype.indexOf = original;' +
                 'result';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('proto', Actual);
end;

procedure TBuiltinMethodLookupTests.ArrayToString_PrototypeUsesObjectToString_ReturnsClassTag;
begin
  const Script = 'Array.prototype.toString = Object.prototype.toString; [0, 1, 2].toString()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('[object Array]', Actual);
end;

procedure TBuiltinMethodLookupTests.FunctionCall_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var f = function() {}; f.call = function() { return "own"; }; f.call()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('own', Actual);
end;

procedure TBuiltinMethodLookupTests.HasOwnProperty_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var o = { hasOwnProperty: function() { return "own"; } }; o.hasOwnProperty("x")';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('own', Actual);
end;

procedure TBuiltinMethodLookupTests.BuiltinMethods_NotReplaced_RunTheBuiltin;
begin
  const Script = 'var a = [1, 2]; a.push(3);' +
                 'var f = function(x) { return x; };' +
                 '[a.join("-"), f.call(null, 7), ({ k: 1 }).hasOwnProperty("k")].join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('1-2-3,7,true', Actual);
end;

procedure TBuiltinMethodLookupTests.PushAndPop_PrototypeValueReplacedAndRestored_FollowsTheCurrentValue;
begin
  const Script = 'var push = Array.prototype.push; var pop = Array.prototype.pop; var a = [1];' +
                 'a.push(2); a.pop();' +
                 'Array.prototype.push = function() { return "push"; };' +
                 'Array.prototype.pop = function() { return "pop"; };' +
                 'var replaced = a.push(3) + a.pop();' +
                 'Array.prototype.push = push; Array.prototype.pop = pop;' +
                 'a.push(4); var popped = a.pop();' +
                 '[replaced, popped, a.length].join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('pushpop,4,1', Actual);
end;

procedure TBuiltinMethodLookupTests.PushAndPop_PrototypeMethodDeletedAndAddedAgain_FollowsTheCurrentMethod;
begin
  const Script = 'var push = Array.prototype.push; var a = [];' +
                 'a.push(1);' +
                 'delete Array.prototype.push;' +
                 'var missing; try { a.push(2); } catch (e) { missing = e instanceof TypeError; }' +
                 'Object.defineProperty(Array.prototype, "push", { value: function() { return "again"; }, configurable: true, writable: true });' +
                 'var again = a.push(3);' +
                 'Array.prototype.push = push; a.push(4);' +
                 '[missing, again, a.join("-")].join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('true,again,1-4', Actual);
end;

procedure TBuiltinMethodLookupTests.Push_PrototypeHoldsElements_StoresTheElementOnTheArray;
begin
  const Script = 'Array.prototype.push(9);' +
                 'var a = []; a.push(5);' +
                 'var result = [a.length, a.hasOwnProperty("0"), a[0]].join();' +
                 'Array.prototype.pop();' +
                 'result';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('1,true,5', Actual);
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_InheritedAccessor_ReceivesTheArray;
begin
  const Script = 'Object.defineProperty(Array.prototype, "size", { get: function() { return this.length; }, configurable: true });' +
                 'var size = [1, 2, 3].size;' +
                 'delete Array.prototype.size;' +
                 'size';

  const Size = FEngine.Evaluate(Script);

  Assert.AreEqual(3.0, Size.AsNumber);
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_InheritedFromObjectPrototype_ReadsTheValue;
begin
  const Script = 'Object.prototype.shared = "yes"; var own = []; own.local = "own";' +
                 'var result = [[].shared, own.local, [].missing].join();' +
                 'delete Object.prototype.shared;' +
                 'result';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('yes,own,', Actual);
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_WithoutPrototype_IsUndefined;
begin
  const Script = 'var a = [1]; Object.setPrototypeOf(a, null); [typeof a.shared, a.length].join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('undefined,1', Actual);
end;

procedure TBuiltinMethodLookupTests.DescriptorObject_Expression_InheritsFromObjectPrototype(const Expression: string);
begin
  const Script = Format('var descriptor = %s; descriptor.hasOwnProperty("value") && (descriptor instanceof Object)',
                        [Expression]);

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.ArrayPush_InFunction_AppendsInOrder;
begin
  const Script = '(function () { var a = []; for (var i = 0; i < 5; i++) { a.push(i, i * 2); } ' +
                 'return a.join(); })() === "0,0,1,2,2,4,3,6,4,8"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_OwnDataProperty_ReturnsValue;
begin
  const Actual = EvaluateBoolean('var o = { a: 1, b: "two" }; o.a === 1 && o.b === "two"');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_InheritedProperty_ReturnsPrototypeValue;
begin
  const Actual = EvaluateBoolean('var o = Object.create({ inherited: 1 }); o.own = 2; o.inherited + o.own === 3');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_OwnPropertyShadowsInherited_ReturnsOwnValue;
begin
  const Actual = EvaluateBoolean('var o = Object.create({ x: 1 }); o.x = 2; o.x === 2');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_OwnAccessor_InvokesGetterWithObjectAsThis;
begin
  const Script = 'var o = { base: 40 }; ' +
                 'Object.defineProperty(o, "answer", { get: function() { return this.base + 2; }, configurable: true }); ' +
                 'o.answer === 42';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_MissingProperty_IsUndefined;
begin
  const Actual = EvaluateBoolean('var o = { a: 1 }; o.missing === undefined');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_NamedPropertyOnArray_KeepsElementsAndLength;
begin
  const Actual = EvaluateBoolean('var a = [7, 8]; a.extra = 5; a.extra === 5 && a.length === 2 && a[1] === 8');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_LengthAndIndexOfStringWrapper_ReadsPrimitive;
begin
  const Actual = EvaluateBoolean('var s = new String("abc"); s.length === 3 && s[1] === "b"');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_DeletedProperty_IsUndefined;
begin
  const Actual = EvaluateBoolean('var o = { a: 1 }; var before = o.a; delete o.a; before === 1 && o.a === undefined');

  Assert.IsTrue(Actual);
end;

procedure TBuiltinMethodLookupTests.PropertyRead_ReadOnlyProperty_ReadsValueAndIgnoresWrite;
begin
  const Script = 'var o = {}; Object.defineProperty(o, "fixed", { value: 1, writable: false }); ' +
                 'o.fixed = 2; o.fixed === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
