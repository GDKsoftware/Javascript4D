unit JS4D.Tests.GlobalObject;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine,
  JS4D.Tests.Support;

type
  [TestFixture]
  TGlobalObjectTests = class(TJSEngineTestCase)
  private
    function TotalAfterRun(const Engine: TJSEngine; const Increment: Integer): Double;

  public
    [Test]
    procedure ThisProperty_AtGlobalLevel_IsVisibleAsVariable;

    [Test]
    procedure GlobalVar_ReadViaThis_IsVisibleAsProperty;

    [Test]
    procedure GlobalFunction_CalledViaThis_IsVisibleAsProperty;

    [Test]
    procedure AssignmentToThisProperty_ExistingVar_UpdatesGlobalVariable;

    [Test]
    procedure AssignmentToGlobalVariable_ReadViaThis_UpdatesThisProperty;

    [Test]
    procedure ImplicitGlobal_AssignedInFunction_IsVisibleAsPropertyOfThis;

    [Test]
    procedure ThisProperty_InsideFunction_IsVisibleAsVariable;

    [Test]
    procedure ThisProperty_InsideWithBlock_IsVisibleWhenObjectLacksIt;

    [Test]
    procedure BuiltinConstructor_ReadViaThis_IsReachable;

    [Test]
    procedure BuiltinConstructor_ForIn_IsNotEnumerable;

    [Test]
    procedure GlobalVar_ForIn_IsEnumerable;

    [Test]
    procedure HostGlobal_ReadViaThis_IsVisibleAsProperty;

    [Test]
    procedure UnknownVariable_Read_ThrowsReferenceError;

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
    procedure Evaluate_SameSourceTwice_AccumulatesRunCount;

    [Test]
    procedure TwoEngines_RunningSameSource_KeepTheirOwnGlobals;

    [Test]
    procedure GlobalObject_GetPrototypeOf_IsObjectPrototype;

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

const
  ACCUMULATE_TOTAL_FORMAT = 'var total = (typeof total === "undefined") ? 0 : total; ' +
                            'for (var i = 0; i < 4; i++) { total += %d; } total';

procedure TGlobalObjectTests.ThisProperty_AtGlobalLevel_IsVisibleAsVariable;
begin
  const Actual = EvaluateBoolean('this.answer = 42; answer === 42');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalVar_ReadViaThis_IsVisibleAsProperty;
begin
  const Actual = EvaluateBoolean('var answer = 42; this.answer === 42');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalFunction_CalledViaThis_IsVisibleAsProperty;
begin
  const Actual = EvaluateBoolean('function answer() { return 42; } this.answer() === 42');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.AssignmentToThisProperty_ExistingVar_UpdatesGlobalVariable;
begin
  const Actual = EvaluateBoolean('var answer = 1; this.answer = 2; answer === 2');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.AssignmentToGlobalVariable_ReadViaThis_UpdatesThisProperty;
begin
  const Actual = EvaluateBoolean('var answer = 1; answer = 2; this.answer === 2');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.ImplicitGlobal_AssignedInFunction_IsVisibleAsPropertyOfThis;
begin
  const Actual = EvaluateBoolean('(function () { implicit = 7; })(); this.implicit === 7');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.ThisProperty_InsideFunction_IsVisibleAsVariable;
begin
  const Actual = EvaluateBoolean('this.answer = 42; (function () { return answer; })() === 42');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.ThisProperty_InsideWithBlock_IsVisibleWhenObjectLacksIt;
begin
  const Script = 'this.p1 = 1; var seen; with ({ other: 2 }) { seen = p1; } seen === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.BuiltinConstructor_ReadViaThis_IsReachable;
begin
  const Actual = EvaluateBoolean('this.Array === Array && this.Math === Math');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.BuiltinConstructor_ForIn_IsNotEnumerable;
begin
  const Script = 'var found = false; for (var key in this) { if (key === "Array") found = true; } !found';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalVar_ForIn_IsEnumerable;
begin
  const Script = 'var visible = 1; var found = false; for (var key in this) { if (key === "visible") found = true; } found';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.HostGlobal_ReadViaThis_IsVisibleAsProperty;
begin
  FEngine.SetVariable('hostValue', TJSValue.CreateNumber(5));

  const Actual = EvaluateBoolean('this.hostValue === 5');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.UnknownVariable_Read_ThrowsReferenceError;
begin
  const Script = 'var name = ""; try { missing; } catch (e) { name = e.name; } name === "ReferenceError"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.FunctionDeclaration_OverNaN_ThrowsTypeError;
begin
  const Script = 'var name = ""; try { (0, eval)("function NaN() {}"); } catch (e) { name = e.name; } name === "TypeError"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.FunctionDeclaration_OverNaN_DefinesNoVariablesOfSameProgram;
begin
  const Script = 'try { (0, eval)("var early; function NaN() {} var late;"); } catch (e) { } ' +
                 'Object.getOwnPropertyDescriptor(this, "early") === undefined && ' +
                 'Object.getOwnPropertyDescriptor(this, "late") === undefined';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.StrictAssignment_ToUnresolvableName_ThrowsBeforeEvaluatingRightSide;
begin
  const Script = 'var name = ""; try { (0, eval)("\"use strict\"; undeclared = (this.undeclared = 5);"); } ' +
                 'catch (e) { name = e.name; } name === "ReferenceError"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalAccessor_ReadAsVariable_InvokesGetter;
begin
  const Script = 'Object.defineProperty(this, "computed", { get: function() { return 7; }, configurable: true }); ' +
                 'computed === 7';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalAccessor_AssignedAsVariable_InvokesSetter;
begin
  const Script = 'var stored = 0; ' +
                 'Object.defineProperty(this, "sink", { set: function(v) { stored = v; }, configurable: true }); ' +
                 'sink = 5; stored === 5';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalReadOnlyProperty_AssignedAsVariable_KeepsValue;
begin
  const Script = 'Object.defineProperty(this, "fixed", { value: 1, writable: false, configurable: true }); ' +
                 'fixed = 2; fixed === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.DeletedGlobal_ReadAgainInSameLoop_ThrowsReferenceError;
begin
  const Script = 'this.gone = 1; var seen = 0; var caught = false; ' +
                 'try { for (var k = 0; k < 3; k++) { seen += gone; if (k === 0) { delete this.gone; } } } ' +
                 'catch (e) { caught = e instanceof ReferenceError; } ' +
                 'seen === 1 && caught';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.DeletedGlobal_ReadFromFunction_ThrowsReferenceError;
begin
  const Script = 'this.gone = 1; function read() { return gone; } ' +
                 'var first = read(); delete this.gone; var caught = false; ' +
                 'try { read(); } catch (e) { caught = e instanceof ReferenceError; } ' +
                 'first === 1 && caught';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.DeletedGlobal_DeclaredAgain_ReadsNewValue;
begin
  const Script = 'this.again = 1; var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(again); if (k === 0) { delete this.again; this.again = 10; } } ' +
                 'out.join() === "1,10,10"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalRedefinedAsAccessor_ReadInSameLoop_InvokesGetter;
begin
  const Script = 'this.v = 1; var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(v); ' +
                 'if (k === 0) { Object.defineProperty(this, "v", { get: function() { return 42; }, configurable: true }); } } ' +
                 'out.join() === "1,42,42"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalAccessorRedefinedAsData_ReadInSameLoop_ReadsValue;
begin
  const Script = 'Object.defineProperty(this, "w", { get: function() { return 5; }, configurable: true }); var out = []; ' +
                 'for (var k = 0; k < 3; k++) { out.push(w); ' +
                 'if (k === 0) { Object.defineProperty(this, "w", { value: 9, configurable: true }); } } ' +
                 'out.join() === "5,9,9"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalRedefinedAsReadOnly_AssignedInSameLoop_KeepsValue;
begin
  const Script = 'this.ro = 1; ' +
                 'for (var k = 0; k < 3; k++) { ro = ro + 1; ' +
                 'if (k === 0) { Object.defineProperty(this, "ro", { value: 100, writable: false, configurable: true }); } } ' +
                 'ro === 100';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalRedefinedWithSetter_AssignedInSameLoop_InvokesSetter;
begin
  const Script = 'this.sink = 0; var stored = []; ' +
                 'for (var k = 0; k < 3; k++) { sink = k; ' +
                 'if (k === 0) { Object.defineProperty(this, "sink", { set: function(v) { stored.push(v); }, configurable: true }); } } ' +
                 'stored.join() === "1,2"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.EvalDeclaredVar_ReadInLoop_IsDeletable;
begin
  const Script = 'eval("var fromEval = 1"); var seen = 0; var caught = false; ' +
                 'try { for (var k = 0; k < 3; k++) { seen += fromEval; if (k === 0) { delete this.fromEval; } } } ' +
                 'catch (e) { caught = e instanceof ReferenceError; } ' +
                 'seen === 1 && caught';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.UnresolvedGlobal_DeclaredInSameLoop_ReadsNewValue;
begin
  const Script = 'var out = []; ' +
                 'for (var k = 0; k < 3; k++) { ' +
                 'try { out.push(late); } catch (e) { out.push("missing"); } ' +
                 'if (k === 0) { this.late = 5; } } ' +
                 'out.join() === "missing,5,5"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalRead_AfterManyNewGlobalsAreDeclared_StaysCorrect;
begin
  const Script = 'this.kept = 7; var total = 0; ' +
                 'for (var k = 0; k < 3; k++) { total += kept; ' +
                 'if (k === 0) { for (var j = 0; j < 500; j++) { this["extra" + j] = j; } } } ' +
                 'total === 21 && extra499 === 499';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalAssignment_AfterManyNewGlobalsAreDeclared_StaysCorrect;
begin
  const Script = 'this.counter = 1; ' +
                 'for (var k = 0; k < 3; k++) { counter = counter + 1; ' +
                 'if (k === 0) { for (var j = 0; j < 500; j++) { this["extra" + j] = j; } } } ' +
                 'this.counter === 4 && extra0 === 0';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.WithObject_ShadowsGlobalInSameLoop_ReadsObjectProperty;
begin
  const Script = 'var shadowed = 1; var out = []; var box = { shadowed: 2 }; ' +
                 'for (var k = 0; k < 3; k++) { out.push(shadowed); with (box) { out.push(shadowed); shadowed = shadowed + 10; } } ' +
                 'out.join() === "1,2,1,12,1,22" && shadowed === 1 && box.shadowed === 32';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.Evaluate_SameSourceTwice_AccumulatesRunCount;
begin
  const Script = 'var runs = (typeof runs === "undefined") ? 1 : runs + 1; ' +
                 'var sum = 0; for (var i = 0; i < 5; i++) { sum += i; } sum + runs';

  const FirstActual = EvaluateNumber(Script);
  const SecondActual = EvaluateNumber(Script);

  Assert.AreEqual(11.0, FirstActual);
  Assert.AreEqual(12.0, SecondActual);
end;

function TGlobalObjectTests.TotalAfterRun(const Engine: TJSEngine; const Increment: Integer): Double;
begin
  const Script = Format(ACCUMULATE_TOTAL_FORMAT, [Increment]);
  const Total = Engine.Evaluate(Script);

  Result := Total.AsNumber;
end;

procedure TGlobalObjectTests.TwoEngines_RunningSameSource_KeepTheirOwnGlobals;
begin
  const Other = TJSEngine.Create;
  try
    const FirstRun = TotalAfterRun(FEngine, 1);
    const OtherFirstRun = TotalAfterRun(Other, 10);
    const SecondRun = TotalAfterRun(FEngine, 1);
    const OtherSecondRun = TotalAfterRun(Other, 10);
    const ThirdRun = TotalAfterRun(FEngine, 1);

    Assert.AreEqual(4.0, FirstRun);
    Assert.AreEqual(40.0, OtherFirstRun);
    Assert.AreEqual(8.0, SecondRun);
    Assert.AreEqual(80.0, OtherSecondRun);
    Assert.AreEqual(12.0, ThirdRun);
  finally
    Other.Free;
  end;
end;

procedure TGlobalObjectTests.GlobalObject_GetPrototypeOf_IsObjectPrototype;
begin
  const Actual = EvaluateBoolean('Object.getPrototypeOf(this) === Object.prototype');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalObject_HasOwnProperty_IsInherited;
begin
  const Actual = EvaluateBoolean('var answer = 1; this.hasOwnProperty("answer") && !this.hasOwnProperty("nothing")');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalObject_InheritedObjectPrototypeMethods_AreVisibleAsVariables;
begin
  const Actual = EvaluateBoolean('typeof hasOwnProperty === "function" && typeof toString === "function"');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.GlobalObject_InheritedProperties_AreNotOwn;
begin
  const Actual = EvaluateBoolean('this.hasOwnProperty("hasOwnProperty")');

  Assert.IsFalse(Actual);
end;

procedure TGlobalObjectTests.StrictAssignment_ToUndeclaredName_IsReferenceError;
begin
  const Script = 'var caught = ""; try { (function () { "use strict"; undeclaredName = 1; })(); } ' +
                 'catch (e) { caught = e.name; } caught === "ReferenceError"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.StrictAssignment_ToDeclaredGlobal_Succeeds;
begin
  const Actual = EvaluateBoolean('var answer = 1; (function () { "use strict"; answer = 2; })(); answer === 2');

  Assert.IsTrue(Actual);
end;

procedure TGlobalObjectTests.StrictAssignment_ToInheritedGlobalName_AssignsWithoutError;
begin
  const Script = '(function () { "use strict"; valueOf = 5; })(); this.valueOf === 5';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
