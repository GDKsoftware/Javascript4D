unit JS4D.Tests.FunctionDeclarations;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionDeclarationTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Hoisting_PropertyAssignedBeforeDeclaration_IsKept;

    [Test]
    procedure Hoisting_PrototypeAssignedBeforeDeclaration_IsUsedByNew;

    [Test]
    procedure Hoisting_InsideFunctionBody_KeepsPropertiesAssignedBeforeDeclaration;

    [Test]
    procedure Hoisting_DeclarationReachedTwice_KeepsSameFunctionObject;

    [Test]
    procedure Hoisting_VariableAssignedBeforeDeclaration_IsNotOverwrittenByDeclaration;

    [Test]
    procedure Hoisting_DeclarationInsideBlock_IsVisibleBeforeTheBlock;

    [Test]
    procedure Prototype_IsArray_ElementsAndLengthAreInherited;
  end;

implementation

procedure TFunctionDeclarationTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionDeclarationTests.TearDown;
begin
  FEngine.Free;
end;

procedure TFunctionDeclarationTests.Hoisting_PropertyAssignedBeforeDeclaration_IsKept;
begin
  const Script =
    'foo.marker = 5;' + sLineBreak +
    'function foo() {}' + sLineBreak +
    'foo.marker';

  Assert.AreEqual(5.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionDeclarationTests.Hoisting_PrototypeAssignedBeforeDeclaration_IsUsedByNew;
begin
  const Script =
    'foo.prototype = [1];' + sLineBreak +
    'function foo() {}' + sLineBreak +
    'var instance = new foo();' + sLineBreak +
    'typeof instance.join === "function" && instance[0] === 1';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionDeclarationTests.Hoisting_InsideFunctionBody_KeepsPropertiesAssignedBeforeDeclaration;
begin
  const Script =
    '(function () {' + sLineBreak +
    '  inner.marker = 7;' + sLineBreak +
    '  function inner() {}' + sLineBreak +
    '  return inner.marker;' + sLineBreak +
    '})()';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionDeclarationTests.Hoisting_DeclarationReachedTwice_KeepsSameFunctionObject;
begin
  const Script =
    'var seen = [];' + sLineBreak +
    'for (var i = 0; i < 2; i++) {' + sLineBreak +
    '  seen.push(foo);' + sLineBreak +
    '  function foo() {}' + sLineBreak +
    '}' + sLineBreak +
    'seen[0] === seen[1]';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionDeclarationTests.Hoisting_VariableAssignedBeforeDeclaration_IsNotOverwrittenByDeclaration;
begin
  const Script =
    'foo = 3;' + sLineBreak +
    'function foo() {}' + sLineBreak +
    'foo';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionDeclarationTests.Hoisting_DeclarationInsideBlock_IsVisibleBeforeTheBlock;
begin
  const Script =
    'var before = typeof foo;' + sLineBreak +
    '{ function foo() {} }' + sLineBreak +
    'before';

  Assert.AreEqual('function', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionDeclarationTests.Prototype_IsArray_ElementsAndLengthAreInherited;
begin
  const Script =
    'function Holder() {}' + sLineBreak +
    'Holder.prototype = [7, 8];' + sLineBreak +
    'var instance = new Holder();' + sLineBreak +
    'instance[1] + instance.length * 10 + ((0 in instance) ? 100 : 0) + (instance.hasOwnProperty(0) ? 1000 : 0)';

  Assert.AreEqual(128.0, FEngine.Evaluate(Script).AsNumber);
end;

end.
