unit JS4D.Tests.GlobalObject;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
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

    [Test]
    procedure DeletedGlobal_ReadAgainInSameLoop_ThrowsReferenceError;

    [Test]
    procedure DeletedGlobal_ReadFromFunction_ThrowsReferenceError;

    [Test]
    procedure DeletedGlobal_DeclaredAgain_ReadsNewValue;

    [Test]
    procedure GlobalRedefinedAsAccessor_ReadInSameLoop_InvokesGetter;

    [Test]
    procedure GlobalAccessorRedefinedAsData_ReadInSameLoop_ReadsValue;

    [Test]
    procedure GlobalRedefinedAsReadOnly_AssignedInSameLoop_KeepsValue;

    [Test]
    procedure GlobalRedefinedWithSetter_AssignedInSameLoop_InvokesSetter;

    [Test]
    procedure EvalDeclaredVar_ReadInLoop_IsDeletable;

    [Test]
    procedure UnresolvedGlobal_DeclaredInSameLoop_ReadsNewValue;

    [Test]
    procedure GlobalRead_AfterManyNewGlobalsAreDeclared_StaysCorrect;

    [Test]
    procedure GlobalAssignment_AfterManyNewGlobalsAreDeclared_StaysCorrect;

    [Test]
    procedure WithObject_ShadowsGlobalInSameLoop_ReadsObjectProperty;

    [Test]
    procedure GlobalReadAndWrite_InSameSource_RunTwice_StaysCorrect;

    [Test]
    procedure TwoEngines_RunningSameSource_KeepTheirOwnGlobals;

    [Test]
    procedure GlobalObject_InheritsFromObjectPrototype;

    [Test]
    procedure GlobalObject_HasOwnProperty_IsInherited;

    [Test]
    procedure GlobalObject_InheritedObjectPrototypeMethods_AreVisibleAsVariables;

    [Test]
    procedure GlobalObject_InheritedProperties_AreNotOwn;

    [Test]
    procedure StrictAssignment_ToUndeclaredName_IsReferenceError;

    [Test]
    procedure StrictAssignment_ToDeclaredGlobal_Succeeds;

    [Test]
    procedure StrictAssignment_ToInheritedGlobalName_AssignsWithoutError;
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

procedure TGlobalObjectTests.DeletedGlobal_ReadAgainInSameLoop_ThrowsReferenceError;
begin
  const Script = 'this.gone = 1; var seen = 0; var caught = false; ' +
                 'try { for (var k = 0; k < 3; k++) { seen += gone; if (k === 0) { delete this.gone; } } } ' +
                 'catch (e) { caught = e instanceof ReferenceError; } ' +
                 'seen === 1 && caught';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.DeletedGlobal_ReadFromFunction_ThrowsReferenceError;
begin
  const Script = 'this.gone = 1; function read() { return gone; } ' +
                 'var first = read(); delete this.gone; var caught = false; ' +
                 'try { read(); } catch (e) { caught = e instanceof ReferenceError; } ' +
                 'first === 1 && caught';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.DeletedGlobal_DeclaredAgain_ReadsNewValue;
begin
  const Script = 'this.again = 1; var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(again); if (k === 0) { delete this.again; this.again = 10; } } ' +
                 'out.join() === "1,10,10"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalRedefinedAsAccessor_ReadInSameLoop_InvokesGetter;
begin
  const Script = 'this.v = 1; var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(v); ' +
                 'if (k === 0) { Object.defineProperty(this, "v", { get: function() { return 42; }, configurable: true }); } } ' +
                 'out.join() === "1,42,42"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalAccessorRedefinedAsData_ReadInSameLoop_ReadsValue;
begin
  const Script = 'Object.defineProperty(this, "w", { get: function() { return 5; }, configurable: true }); var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(w); ' +
                 'if (k === 0) { Object.defineProperty(this, "w", { value: 9, configurable: true }); } } ' +
                 'out.join() === "5,9,9"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalRedefinedAsReadOnly_AssignedInSameLoop_KeepsValue;
begin
  const Script = 'this.ro = 1; ' +
                 'for (var k = 0; k < 3; k++) { ro = ro + 1; ' +
                 'if (k === 0) { Object.defineProperty(this, "ro", { value: 100, writable: false, configurable: true }); } } ' +
                 'ro === 100';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalRedefinedWithSetter_AssignedInSameLoop_InvokesSetter;
begin
  const Script = 'this.sink = 0; var stored = []; ' +
                 'for (var k = 0; k < 3; k++) { sink = k; ' +
                 'if (k === 0) { Object.defineProperty(this, "sink", { set: function(v) { stored.push(v); }, configurable: true }); } } ' +
                 'stored.join() === "1,2"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.EvalDeclaredVar_ReadInLoop_IsDeletable;
begin
  const Script = 'eval("var fromEval = 1"); var seen = 0; var caught = false; ' +
                 'try { for (var k = 0; k < 3; k++) { seen += fromEval; if (k === 0) { delete this.fromEval; } } } ' +
                 'catch (e) { caught = e instanceof ReferenceError; } ' +
                 'seen === 1 && caught';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.UnresolvedGlobal_DeclaredInSameLoop_ReadsNewValue;
begin
  const Script = 'var out = []; ' +
                 'for (var k = 0; k < 3; k++) { ' +
                 'try { out.push(late); } catch (e) { out.push("missing"); } ' +
                 'if (k === 0) { this.late = 5; } } ' +
                 'out.join() === "missing,5,5"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalRead_AfterManyNewGlobalsAreDeclared_StaysCorrect;
begin
  const Script = 'this.kept = 7; var total = 0; ' +
                 'for (var k = 0; k < 3; k++) { total += kept; ' +
                 'if (k === 0) { for (var j = 0; j < 500; j++) { this["extra" + j] = j; } } } ' +
                 'total === 21 && extra499 === 499';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalAssignment_AfterManyNewGlobalsAreDeclared_StaysCorrect;
begin
  const Script = 'this.counter = 1; ' +
                 'for (var k = 0; k < 3; k++) { counter = counter + 1; ' +
                 'if (k === 0) { for (var j = 0; j < 500; j++) { this["extra" + j] = j; } } } ' +
                 'this.counter === 4 && extra0 === 0';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.WithObject_ShadowsGlobalInSameLoop_ReadsObjectProperty;
begin
  const Script = 'var shadowed = 1; var out = []; var box = { shadowed: 2 }; ' +
                 'for (var k = 0; k < 3; k++) { out.push(shadowed); with (box) { out.push(shadowed); shadowed = shadowed + 10; } } ' +
                 'out.join() === "1,2,1,12,1,22" && shadowed === 1 && box.shadowed === 32';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.GlobalReadAndWrite_InSameSource_RunTwice_StaysCorrect;
begin
  const Script = 'var runs = (typeof runs === "undefined") ? 1 : runs + 1; ' +
                 'var sum = 0; for (var i = 0; i < 5; i++) { sum += i; } sum + runs';

  Assert.AreEqual(Double(11), FEngine.Evaluate(Script).AsNumber);
  Assert.AreEqual(Double(12), FEngine.Evaluate(Script).AsNumber);
end;

procedure TGlobalObjectTests.TwoEngines_RunningSameSource_KeepTheirOwnGlobals;
begin
  const Other = TJSEngine.Create;
  try
    const Script = 'var total = (typeof total === "undefined") ? 0 : total; ' +
                   'for (var i = 0; i < 4; i++) { total += %d; } total';

    Assert.AreEqual(Double(4), FEngine.Evaluate(Format(Script, [1])).AsNumber);
    Assert.AreEqual(Double(40), Other.Evaluate(Format(Script, [10])).AsNumber);
    Assert.AreEqual(Double(8), FEngine.Evaluate(Format(Script, [1])).AsNumber);
    Assert.AreEqual(Double(80), Other.Evaluate(Format(Script, [10])).AsNumber);
    Assert.AreEqual(Double(12), FEngine.Evaluate(Format(Script, [1])).AsNumber);
  finally
    Other.Free;
  end;
end;

procedure TGlobalObjectTests.GlobalObject_InheritsFromObjectPrototype;
begin
  Assert.IsTrue(EvaluatesToTrue('Object.getPrototypeOf(this) === Object.prototype'));
end;

procedure TGlobalObjectTests.GlobalObject_HasOwnProperty_IsInherited;
begin
  Assert.IsTrue(EvaluatesToTrue('var answer = 1; this.hasOwnProperty("answer") && !this.hasOwnProperty("nothing")'));
end;

procedure TGlobalObjectTests.GlobalObject_InheritedObjectPrototypeMethods_AreVisibleAsVariables;
begin
  Assert.IsTrue(EvaluatesToTrue('typeof hasOwnProperty === "function" && typeof toString === "function"'));
end;

procedure TGlobalObjectTests.GlobalObject_InheritedProperties_AreNotOwn;
begin
  Assert.IsFalse(EvaluatesToTrue('this.hasOwnProperty("hasOwnProperty")'));
end;

procedure TGlobalObjectTests.StrictAssignment_ToUndeclaredName_IsReferenceError;
begin
  const Script = 'var caught = ""; try { (function () { "use strict"; undeclaredName = 1; })(); } ' +
                 'catch (e) { caught = e.name; } caught === "ReferenceError"';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

procedure TGlobalObjectTests.StrictAssignment_ToDeclaredGlobal_Succeeds;
begin
  Assert.IsTrue(EvaluatesToTrue('var answer = 1; (function () { "use strict"; answer = 2; })(); answer === 2'));
end;

procedure TGlobalObjectTests.StrictAssignment_ToInheritedGlobalName_AssignsWithoutError;
begin
  const Script = '(function () { "use strict"; valueOf = 5; })(); this.valueOf === 5';

  Assert.IsTrue(EvaluatesToTrue(Script));
end;

end.
