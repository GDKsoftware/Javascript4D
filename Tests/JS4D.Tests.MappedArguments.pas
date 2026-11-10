unit JS4D.Tests.MappedArguments;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TMappedArgumentsTests = class
  private
    FEngine: TJSEngine;

    procedure AssertScriptIsTrue(const Script: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Sloppy_AssigningParameter_UpdatesArgumentsElement;

    [Test]
    procedure Sloppy_AssigningArgumentsElement_UpdatesParameter;

    [Test]
    procedure Sloppy_ParameterWithoutPassedArgument_IsNotMapped;

    [Test]
    procedure Sloppy_DuplicateParameterNames_MapsLastIndexOnly;

    [Test]
    procedure Strict_AssigningParameter_LeavesArgumentsElement;

    [Test]
    procedure Sloppy_DefinePropertyWithValue_UpdatesParameter;

    [Test]
    procedure Sloppy_DefinePropertyNonWritable_RemovesMapping;

    [Test]
    procedure Sloppy_DefinePropertyNonWritable_KeepsCurrentParameterValue;

    [Test]
    procedure Sloppy_DefinePropertyAccessor_RemovesMapping;

    [Test]
    procedure Sloppy_DeleteElement_RemovesMapping;

    [Test]
    procedure Sloppy_DeleteNonConfigurableElement_KeepsMapping;

    [Test]
    procedure Sloppy_NonConfigurableElement_DescriptorFollowsParameter;

    [Test]
    procedure Sloppy_FreezeArguments_RemovesMapping;

    [Test]
    procedure Sloppy_Callee_IsOwnNonEnumerableWritableConfigurable;

    [Test]
    procedure Sloppy_Callee_IsTheCalledFunction;

    [Test]
    procedure Sloppy_CalleeOnObjectPrototype_DoesNotShadowOwnCallee;

    [Test]
    procedure Sloppy_WithArguments_AssignsOwnCallee;

    [Test]
    procedure Sloppy_ArgumentsSurvivingTheCall_KeepsMapping;
  end;

implementation

procedure TMappedArgumentsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TMappedArgumentsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TMappedArgumentsTests.AssertScriptIsTrue(const Script: string);
begin
  const Outcome = FEngine.Evaluate(Script);

  Assert.IsTrue(Outcome.AsBoolean);
end;

procedure TMappedArgumentsTests.Sloppy_AssigningParameter_UpdatesArgumentsElement;
begin
  AssertScriptIsTrue('(function(a) { a = 2; return arguments[0] === 2; })(1)');
end;

procedure TMappedArgumentsTests.Sloppy_AssigningArgumentsElement_UpdatesParameter;
begin
  AssertScriptIsTrue('(function(a) { arguments[0] = 3; return a === 3; })(1)');
end;

procedure TMappedArgumentsTests.Sloppy_ParameterWithoutPassedArgument_IsNotMapped;
begin
  const Script = '(function(a, b) { arguments[1] = 5; return b === undefined; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DuplicateParameterNames_MapsLastIndexOnly;
begin
  const Script = '(function(a, a) { a = 9; return arguments[1] === 9 && arguments[0] === 1; })(1, 2)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Strict_AssigningParameter_LeavesArgumentsElement;
begin
  const Script = '(function(a) { "use strict"; a = 2; return arguments[0] === 1; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DefinePropertyWithValue_UpdatesParameter;
begin
  const Script = '(function(a) { Object.defineProperty(arguments, "0", {value: 4}); return a === 4; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DefinePropertyNonWritable_RemovesMapping;
begin
  const Script =
    '(function(a) { Object.defineProperty(arguments, "0", {writable: false}); a = 7; ' +
    'return arguments[0] === 1; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DefinePropertyNonWritable_KeepsCurrentParameterValue;
begin
  const Script =
    '(function(a) { a = 6; Object.defineProperty(arguments, "0", {writable: false}); ' +
    'return arguments[0] === 6; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DefinePropertyAccessor_RemovesMapping;
begin
  const Script =
    '(function(a) { Object.defineProperty(arguments, "0", {get: function() { return 8; }}); ' +
    'a = 7; return arguments[0] === 8; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DeleteElement_RemovesMapping;
begin
  const Script =
    '(function(a) { delete arguments[0]; a = 2; return arguments[0] === undefined; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_DeleteNonConfigurableElement_KeepsMapping;
begin
  const Script =
    '(function(a) { Object.defineProperty(arguments, "0", {configurable: false}); ' +
    'var deleted = delete arguments[0]; a = 2; return deleted === false && arguments[0] === 2; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_NonConfigurableElement_DescriptorFollowsParameter;
begin
  const Script =
    '(function(a) { Object.defineProperty(arguments, "0", {configurable: false}); a = 2; ' +
    'var descriptor = Object.getOwnPropertyDescriptor(arguments, "0"); ' +
    'return descriptor.value === 2 && descriptor.writable === true && descriptor.enumerable === true; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_FreezeArguments_RemovesMapping;
begin
  const Script = '(function(a) { Object.freeze(arguments); a = 2; return arguments[0] === 1; })(1)';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_Callee_IsOwnNonEnumerableWritableConfigurable;
begin
  const Script =
    '(function() { var d = Object.getOwnPropertyDescriptor(arguments, "callee"); ' +
    'return d.enumerable === false && d.writable === true && d.configurable === true && ' +
    'arguments.hasOwnProperty("callee"); })()';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_Callee_IsTheCalledFunction;
begin
  const Script = 'var f = function() { return arguments.callee; }; f() === f';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_CalleeOnObjectPrototype_DoesNotShadowOwnCallee;
begin
  const Script =
    'Object.defineProperty(Object.prototype, "callee", {value: 1, writable: false, configurable: true}); ' +
    'var result = typeof (function() { return arguments; })().callee === "function"; ' +
    'delete Object.prototype.callee; result';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_WithArguments_AssignsOwnCallee;
begin
  const Script =
    'var callee = 0; var result = (function() { with (arguments) { callee = 1; } return arguments; })(); ' +
    'callee === 0 && result.callee === 1';

  AssertScriptIsTrue(Script);
end;

procedure TMappedArgumentsTests.Sloppy_ArgumentsSurvivingTheCall_KeepsMapping;
begin
  FEngine.Execute('var kept; function grab(a) { kept = arguments; a = 5; } grab(1);');

  AssertScriptIsTrue('kept[0] === 5');
end;

end.
