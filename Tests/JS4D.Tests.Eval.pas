unit JS4D.Tests.Eval;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TEvalTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Eval_IsAFunction;

    [Test]
    procedure Eval_Expression_ReturnsValue;

    [Test]
    procedure Eval_NonStringArgument_IsReturnedUnchanged;

    [Test]
    procedure Eval_NoArgument_ReturnsUndefined;

    [Test]
    procedure Eval_EmptyString_ReturnsUndefined;

    [Test]
    procedure Eval_StatementList_ReturnsLastCompletionValue;

    [Test]
    procedure Eval_GlobalVar_BecomesGlobalVariable;

    [Test]
    procedure Eval_FunctionDeclaration_IsCallableAfterwards;

    [Test]
    procedure Eval_Direct_SeesLocalVariables;

    [Test]
    procedure Eval_Direct_VarDeclaresInCallingFunction;

    [Test]
    procedure Eval_Direct_AssignsToLocalVariables;

    [Test]
    procedure Eval_Direct_KeepsThisOfCaller;

    [Test]
    procedure Eval_Indirect_SeesGlobalNotLocal;

    [Test]
    procedure Eval_IndirectThroughAlias_SeesGlobalNotLocal;

    [Test]
    procedure Eval_StrictSource_KeepsVarPrivate;

    [Test]
    procedure Eval_DirectInStrictCaller_KeepsVarPrivate;

    [Test]
    procedure Eval_SyntaxError_ThrowsSyntaxError;

    [Test]
    procedure Eval_ThrownValue_PropagatesToCaller;

    [Test]
    procedure Eval_CreatedClosure_OutlivesEval;

    [Test]
    procedure Eval_Nested_EvaluatesInnerSource;

    [Test]
    procedure Eval_CompoundAssignmentToUnresolvableName_ThrowsReferenceError;

    [Test]
    procedure Eval_LineSeparatorBetweenStatements_ActsAsLineTerminator;
  end;

implementation

procedure TEvalTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TEvalTests.TearDown;
begin
  FEngine.Free;
end;

procedure TEvalTests.Eval_IsAFunction;
begin
  Assert.AreEqual('function', FEngine.Evaluate('typeof eval').AsString);
end;

procedure TEvalTests.Eval_Expression_ReturnsValue;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('eval("1 + 2")').AsNumber);
end;

procedure TEvalTests.Eval_NonStringArgument_IsReturnedUnchanged;
begin
  Assert.AreEqual(42.0, FEngine.Evaluate('eval(42)').AsNumber);
end;

procedure TEvalTests.Eval_NoArgument_ReturnsUndefined;
begin
  Assert.AreEqual('undefined', FEngine.Evaluate('typeof eval()').AsString);
end;

procedure TEvalTests.Eval_EmptyString_ReturnsUndefined;
begin
  Assert.AreEqual('undefined', FEngine.Evaluate('typeof eval("")').AsString);
end;

procedure TEvalTests.Eval_StatementList_ReturnsLastCompletionValue;
begin
  Assert.AreEqual(5.0, FEngine.Evaluate('eval("var a = 2; a + 3")').AsNumber);
end;

procedure TEvalTests.Eval_GlobalVar_BecomesGlobalVariable;
begin
  FEngine.Execute('eval("var fromEval = 5");');

  Assert.AreEqual(5.0, FEngine.Evaluate('fromEval').AsNumber);
end;

procedure TEvalTests.Eval_FunctionDeclaration_IsCallableAfterwards;
begin
  FEngine.Execute('eval("function twice(n) { return n * 2; }");');

  Assert.AreEqual(8.0, FEngine.Evaluate('twice(4)').AsNumber);
end;

procedure TEvalTests.Eval_Direct_SeesLocalVariables;
begin
  FEngine.Execute('function f() { var a = 2; return eval("a * 3"); }');

  Assert.AreEqual(6.0, FEngine.Evaluate('f()').AsNumber);
end;

procedure TEvalTests.Eval_Direct_VarDeclaresInCallingFunction;
begin
  FEngine.Execute('function f() { eval("var b = 7"); return b; }');

  Assert.AreEqual(7.0, FEngine.Evaluate('f()').AsNumber);
  Assert.AreEqual('undefined', FEngine.Evaluate('typeof b').AsString);
end;

procedure TEvalTests.Eval_Direct_AssignsToLocalVariables;
begin
  FEngine.Execute('function f() { var c = 1; eval("c = 9"); return c; }');

  Assert.AreEqual(9.0, FEngine.Evaluate('f()').AsNumber);
end;

procedure TEvalTests.Eval_Direct_KeepsThisOfCaller;
begin
  FEngine.Execute('var holder = { v: 11, get: function() { return eval("this.v"); } };');

  Assert.AreEqual(11.0, FEngine.Evaluate('holder.get()').AsNumber);
end;

procedure TEvalTests.Eval_Indirect_SeesGlobalNotLocal;
begin
  FEngine.Execute('var g = "global"; function f() { var g = "local"; return (0, eval)("g"); }');

  Assert.AreEqual('global', FEngine.Evaluate('f()').AsString);
end;

procedure TEvalTests.Eval_IndirectThroughAlias_SeesGlobalNotLocal;
begin
  FEngine.Execute('var h = "global"; var alias = eval; function f() { var h = "local"; return alias("h"); }');

  Assert.AreEqual('global', FEngine.Evaluate('f()').AsString);
end;

procedure TEvalTests.Eval_StrictSource_KeepsVarPrivate;
begin
  FEngine.Execute('function f() { eval("\"use strict\"; var s = 1"); return typeof s; }');

  Assert.AreEqual('undefined', FEngine.Evaluate('f()').AsString);
end;

procedure TEvalTests.Eval_DirectInStrictCaller_KeepsVarPrivate;
begin
  FEngine.Execute('function f() { "use strict"; eval("var t = 1"); return typeof t; }');

  Assert.AreEqual('undefined', FEngine.Evaluate('f()').AsString);
end;

procedure TEvalTests.Eval_SyntaxError_ThrowsSyntaxError;
begin
  FEngine.Execute('var caught = false; try { eval("var"); } catch (e) { caught = e instanceof SyntaxError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TEvalTests.Eval_ThrownValue_PropagatesToCaller;
begin
  FEngine.Execute('var seen; try { eval("throw 12"); } catch (e) { seen = e; }');

  Assert.AreEqual(12.0, FEngine.Evaluate('seen').AsNumber);
end;

procedure TEvalTests.Eval_CreatedClosure_OutlivesEval;
begin
  FEngine.Execute('var make = eval("(function() { return 21; })");');
  FEngine.CollectGarbage;

  Assert.AreEqual(21.0, FEngine.Evaluate('make()').AsNumber);
end;

procedure TEvalTests.Eval_Nested_EvaluatesInnerSource;
begin
  Assert.AreEqual(4.0, FEngine.Evaluate('eval("eval(\"2 + 2\")")').AsNumber);
end;

procedure TEvalTests.Eval_CompoundAssignmentToUnresolvableName_ThrowsReferenceError;
begin
  FEngine.Execute('var caught = false; try { eval("missingName *= 1"); } catch (e) { caught = e instanceof ReferenceError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TEvalTests.Eval_LineSeparatorBetweenStatements_ActsAsLineTerminator;
begin
  const Source = 'eval("var p = 1' + #$2028 + 'var q = 2' + #$2029 + 'p + q")';

  Assert.AreEqual(3.0, FEngine.Evaluate(Source).AsNumber);
end;

end.
