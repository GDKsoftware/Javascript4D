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

procedure TBuiltinMethodLookupTests.DescriptorObject_InheritsFromObjectPrototype(const Expression: string);
begin
  const Script = Format('var descriptor = %s; descriptor.hasOwnProperty("value") && (descriptor instanceof Object)',
                        [Expression]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

end.
