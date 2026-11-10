unit JS4D.Tests.GlobalObject;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TGlobalObjectTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToTrue(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ThisProperty_AtGlobalLevel_IsVisibleAsVariable;

    [Test]
    procedure GlobalVar_IsVisibleAsPropertyOfThis;

    [Test]
    procedure GlobalFunction_IsVisibleAsPropertyOfThis;

    [Test]
    procedure AssignmentToThisProperty_UpdatesGlobalVariable;

    [Test]
    procedure AssignmentToGlobalVariable_UpdatesThisProperty;

    [Test]
    procedure ImplicitGlobal_IsVisibleAsPropertyOfThis;

    [Test]
    procedure ThisProperty_InsideFunction_IsVisibleAsVariable;

    [Test]
    procedure ThisProperty_IsVisibleInsideWithBlockThatLacksIt;

    [Test]
    procedure BuiltinConstructor_IsReachableThroughThis;

    [Test]
    procedure BuiltinConstructor_IsNotEnumerableOnThis;

    [Test]
    procedure GlobalVar_IsEnumerableOnThis;

    [Test]
    procedure HostGlobal_IsVisibleAsPropertyOfThis;

    [Test]
    procedure UnknownVariable_StillThrowsReferenceError;

    [Test]
    procedure FunctionDeclaration_OverNaN_ThrowsTypeError;

    [Test]
    procedure FunctionDeclaration_OverNaN_DefinesNoVariablesOfSameProgram;

    [Test]
    procedure StrictAssignment_ToUnresolvableName_ThrowsBeforeEvaluatingRightSide;

    [Test]
    procedure GlobalAccessor_ReadAsVariable_InvokesGetter;

    [Test]
    procedure GlobalAccessor_AssignedAsVariable_InvokesSetter;

    [Test]
    procedure GlobalReadOnlyProperty_AssignedAsVariable_KeepsValue;
  end;

implementation

procedure TGlobalObjectTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TGlobalObjectTests.TearDown;
begin
  FEngine.Free;
end;

function TGlobalObjectTests.EvaluatesToTrue(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TGlobalObjectTests.ThisProperty_AtGlobalLevel_IsVisibleAsVariable;
begin
  Assert.IsTrue(EvaluatesToTrue('this.answer = 42; answer === 42'));
end;

procedure TGlobalObjectTests.GlobalVar_IsVisibleAsPropertyOfThis;
begin
  Assert.IsTrue(EvaluatesToTrue('var answer = 42; this.answer === 42'));
end;

procedure TGlobalObjectTests.GlobalFunction_IsVisibleAsPropertyOfThis;
begin
  Assert.IsTrue(EvaluatesToTrue('function answer() { return 42; } this.answer() === 42'));
end;

procedure TGlobalObjectTests.AssignmentToThisProperty_UpdatesGlobalVariable;
begin
  Assert.IsTrue(EvaluatesToTrue('var answer = 1; this.answer = 2; answer === 2'));
end;

procedure TGlobalObjectTests.AssignmentToGlobalVariable_UpdatesThisProperty;
begin
  Assert.IsTrue(EvaluatesToTrue('var answer = 1; answer = 2; this.answer === 2'));
end;

procedure TGlobalObjectTests.ImplicitGlobal_IsVisibleAsPropertyOfThis;
begin
  Assert.IsTrue(EvaluatesToTrue('(function () { implicit = 7; })(); this.implicit === 7'));
end;

procedure TGlobalObjectTests.ThisProperty_InsideFunction_IsVisibleAsVariable;
begin
  Assert.IsTrue(EvaluatesToTrue('this.answer = 42; (function () { return answer; })() === 42'));
end;

procedure TGlobalObjectTests.ThisProperty_IsVisibleInsideWithBlockThatLacksIt;
begin
  const Script = 'this.p1 = 1; var seen; with ({ other: 2 }) { seen = p1; } seen === 1';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.BuiltinConstructor_IsReachableThroughThis;
begin
  Assert.IsTrue(EvaluatesToTrue('this.Array === Array && this.Math === Math'));
end;

procedure TGlobalObjectTests.BuiltinConstructor_IsNotEnumerableOnThis;
begin
  const Script = 'var found = false; for (var key in this) { if (key === "Array") found = true; } !found';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalVar_IsEnumerableOnThis;
begin
  const Script = 'var visible = 1; var found = false; for (var key in this) { if (key === "visible") found = true; } found';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.HostGlobal_IsVisibleAsPropertyOfThis;
begin
  FEngine.SetVariable('hostValue', TJSValue.CreateNumber(5));

  Assert.IsTrue(EvaluatesToTrue('this.hostValue === 5'));
end;

procedure TGlobalObjectTests.UnknownVariable_StillThrowsReferenceError;
begin
  const Script = 'var name = ""; try { missing; } catch (e) { name = e.name; } name === "ReferenceError"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.FunctionDeclaration_OverNaN_ThrowsTypeError;
begin
  const Script = 'var name = ""; try { (0, eval)("function NaN() {}"); } catch (e) { name = e.name; } name === "TypeError"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.FunctionDeclaration_OverNaN_DefinesNoVariablesOfSameProgram;
begin
  const Script = 'try { (0, eval)("var early; function NaN() {} var late;"); } catch (e) { } ' +
                 'Object.getOwnPropertyDescriptor(this, "early") === undefined && ' +
                 'Object.getOwnPropertyDescriptor(this, "late") === undefined';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.StrictAssignment_ToUnresolvableName_ThrowsBeforeEvaluatingRightSide;
begin
  const Script = 'var name = ""; try { (0, eval)("\"use strict\"; undeclared = (this.undeclared = 5);"); } ' +
                 'catch (e) { name = e.name; } name === "ReferenceError"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalAccessor_ReadAsVariable_InvokesGetter;
begin
  const Script = 'Object.defineProperty(this, "computed", { get: function() { return 7; }, configurable: true }); ' +
                 'computed === 7';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalAccessor_AssignedAsVariable_InvokesSetter;
begin
  const Script = 'var stored = 0; ' +
                 'Object.defineProperty(this, "sink", { set: function(v) { stored = v; }, configurable: true }); ' +
                 'sink = 5; stored === 5';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalReadOnlyProperty_AssignedAsVariable_KeepsValue;
begin
  const Script = 'Object.defineProperty(this, "fixed", { value: 1, writable: false, configurable: true }); ' +
                 'fixed = 2; fixed === 1';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

end.
