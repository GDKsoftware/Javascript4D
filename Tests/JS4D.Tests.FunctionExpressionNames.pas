unit JS4D.Tests.FunctionExpressionNames;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionExpressionNameTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Name_InsideBody_RefersToTheFunction;

    [Test]
    procedure Name_OutsideFunction_IsNotDeclared;

    [Test]
    procedure Name_OuterVariableWithSameName_IsNotChanged;

    [Test]
    procedure Name_ReachableFromNestedClosure_AfterTheCallReturned;

    [Test]
    procedure Name_SloppyReassignment_IsIgnored;

    [Test]
    procedure Name_SloppyReassignmentInEval_IsIgnored;

    [Test]
    procedure Name_StrictReassignment_RaisesTypeError;

    [Test]
    procedure Name_StrictReassignmentInEval_RaisesTypeError;

    [Test]
    procedure Name_VarWithSameNameInBody_ShadowsTheFunctionName;

    [Test]
    procedure Name_ParameterWithSameName_ShadowsTheFunctionName;

    [Test]
    procedure Name_UsedByRecursion_Works;

    [Test]
    procedure Name_InParameterInitializer_RefersToTheFunction;
  end;

implementation

procedure TFunctionExpressionNameTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionExpressionNameTests.TearDown;
begin
  FEngine.Free;
end;

procedure TFunctionExpressionNameTests.Name_InsideBody_RefersToTheFunction;
begin
  const Script =
    'var ref = function Inner() { return Inner; };' + sLineBreak +
    'ref() === ref';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_OutsideFunction_IsNotDeclared;
begin
  const Script =
    'var ref = function Inner() {};' + sLineBreak +
    'typeof Inner';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionExpressionNameTests.Name_OuterVariableWithSameName_IsNotChanged;
begin
  const Script =
    'var f = "outside";' + sLineBreak +
    'var func = function f() { f = null; };' + sLineBreak +
    'func();' + sLineBreak +
    'f';

  Assert.AreEqual('outside', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionExpressionNameTests.Name_ReachableFromNestedClosure_AfterTheCallReturned;
begin
  const Script =
    'var probe;' + sLineBreak +
    'var f = "outside";' + sLineBreak +
    'var func = function f() { probe = function() { return f; }; };' + sLineBreak +
    'func();' + sLineBreak +
    'probe() === func && f === "outside"';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_SloppyReassignment_IsIgnored;
begin
  const Script =
    'var ref = function Inner() { Inner = 1; return Inner; };' + sLineBreak +
    'ref() === ref';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_SloppyReassignmentInEval_IsIgnored;
begin
  const Script =
    'var ref = function Inner() { eval("Inner = 1"); return Inner; };' + sLineBreak +
    'ref() === ref';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_StrictReassignment_RaisesTypeError;
begin
  const Script =
    '"use strict";' + sLineBreak +
    'var ref = function Inner() { Inner = 1; };' + sLineBreak +
    'var caught = "none";' + sLineBreak +
    'try { ref(); } catch (e) { caught = e instanceof TypeError; }' + sLineBreak +
    'caught';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_StrictReassignmentInEval_RaisesTypeError;
begin
  const Script =
    '"use strict";' + sLineBreak +
    'var ref = function Inner() { eval("Inner = 1"); };' + sLineBreak +
    'var caught = "none";' + sLineBreak +
    'try { ref(); } catch (e) { caught = e instanceof TypeError; }' + sLineBreak +
    'caught';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TFunctionExpressionNameTests.Name_VarWithSameNameInBody_ShadowsTheFunctionName;
begin
  const Script =
    'var ref = function Inner() { var Inner = 5; return Inner; };' + sLineBreak +
    'ref()';

  Assert.AreEqual(5.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionExpressionNameTests.Name_ParameterWithSameName_ShadowsTheFunctionName;
begin
  const Script =
    'var ref = function Inner(Inner) { return Inner; };' + sLineBreak +
    'ref(7)';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionExpressionNameTests.Name_UsedByRecursion_Works;
begin
  const Script =
    'var fact = function f(n) { return n <= 1 ? 1 : n * f(n - 1); };' + sLineBreak +
    'fact(5)';

  Assert.AreEqual(120.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionExpressionNameTests.Name_InParameterInitializer_RefersToTheFunction;
begin
  const Script =
    'var seen;' + sLineBreak +
    'var func = function f(a = (seen = f)) {};' + sLineBreak +
    'func();' + sLineBreak +
    'seen === func';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

end.
