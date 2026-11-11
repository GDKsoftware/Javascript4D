unit JS4D.Tests.BuiltinMethodLookup;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TBuiltinMethodLookupTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure BuiltinMethods_NotReplaced_KeepWorking;

    [Test]
    [TestCase('Descriptor', 'Object.getOwnPropertyDescriptor({ a: 1 }, "a")', '#')]
    [TestCase('Descriptors', 'Object.getOwnPropertyDescriptors({ a: 1 }).a', '#')]
    procedure DescriptorObject_InheritsFromObjectPrototype(const Expression: string);
  end;

implementation

procedure TBuiltinMethodLookupTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TBuiltinMethodLookupTests.TearDown;
begin
  FEngine.Free;
end;

procedure TBuiltinMethodLookupTests.ArrayMethod_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var a = [1, 2]; a.push = function() { return "own"; }; a.push(3)';

  Assert.AreEqual('own', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.ArrayMethod_PrototypeReplacesIt_RunsTheReplacement;
begin
  const Script = 'var original = Array.prototype.indexOf;' +
                 'Array.prototype.indexOf = function() { return "proto"; };' +
                 'var result = [1].indexOf(1);' +
                 'Array.prototype.indexOf = original;' +
                 'result';

  Assert.AreEqual('proto', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.ArrayToString_PrototypeUsesObjectToString_ReturnsClassTag;
begin
  const Script = 'Array.prototype.toString = Object.prototype.toString; [0, 1, 2].toString()';

  Assert.AreEqual('[object Array]', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.FunctionCall_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var f = function() {}; f.call = function() { return "own"; }; f.call()';

  Assert.AreEqual('own', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.HasOwnProperty_OwnPropertyReplacesIt_RunsTheReplacement;
begin
  const Script = 'var o = { hasOwnProperty: function() { return "own"; } }; o.hasOwnProperty("x")';

  Assert.AreEqual('own', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.BuiltinMethods_NotReplaced_KeepWorking;
begin
  const Script = 'var a = [1, 2]; a.push(3);' +
                 'var f = function(x) { return x; };' +
                 '[a.join("-"), f.call(null, 7), ({ k: 1 }).hasOwnProperty("k")].join()';

  Assert.AreEqual('1-2-3,7,true', FEngine.Evaluate(Script).AsString);
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

  Assert.AreEqual('pushpop,4,1', FEngine.Evaluate(Script).AsString);
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

  Assert.AreEqual('true,again,1-4', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.Push_PrototypeHoldsElements_StoresTheElementOnTheArray;
begin
  const Script = 'Array.prototype.push(9);' +
                 'var a = []; a.push(5);' +
                 'var result = [a.length, a.hasOwnProperty("0"), a[0]].join();' +
                 'Array.prototype.pop();' +
                 'result';

  Assert.AreEqual('1,true,5', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_InheritedAccessor_ReceivesTheArray;
begin
  const Script = 'Object.defineProperty(Array.prototype, "size", { get: function() { return this.length; }, configurable: true });' +
                 'var size = [1, 2, 3].size;' +
                 'delete Array.prototype.size;' +
                 'size';

  Assert.AreEqual(3, Integer(Trunc(FEngine.Evaluate(Script).AsNumber)));
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_InheritedFromObjectPrototype_ReadsTheValue;
begin
  const Script = 'Object.prototype.shared = "yes"; var own = []; own.local = "own";' +
                 'var result = [[].shared, own.local, [].missing].join();' +
                 'delete Object.prototype.shared;' +
                 'result';

  Assert.AreEqual('yes,own,', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.ArrayProperty_WithoutPrototype_IsUndefined;
begin
  const Script = 'var a = [1]; Object.setPrototypeOf(a, null); [typeof a.shared, a.length].join()';

  Assert.AreEqual('undefined,1', FEngine.Evaluate(Script).AsString);
end;

procedure TBuiltinMethodLookupTests.DescriptorObject_InheritsFromObjectPrototype(const Expression: string);
begin
  const Script = Format('var descriptor = %s; descriptor.hasOwnProperty("value") && (descriptor instanceof Object)',
                        [Expression]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

end.
