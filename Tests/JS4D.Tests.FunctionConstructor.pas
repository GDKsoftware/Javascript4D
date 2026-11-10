unit JS4D.Tests.FunctionConstructor;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionConstructorTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Call_BodyOnly_ReturnsFunction;

    [Test]
    procedure Call_ParametersAndBody_CreatesWorkingFunction;

    [Test]
    procedure Call_CommaSeparatedParameters_AreSplit;

    [Test]
    procedure New_CreatesCallableFunction;

    [Test]
    procedure Call_NoArguments_CreatesEmptyFunction;

    [Test]
    procedure Call_FunctionRunsInGlobalScope;

    [Test]
    procedure Call_InvalidBody_ThrowsSyntaxError;

    [Test]
    procedure Call_InvalidParameter_ThrowsSyntaxError;

    [Test]
    procedure Call_BodyClosingBraceInjection_ThrowsSyntaxError;

    [Test]
    procedure Call_StrictBody_AppliesStrictMode;

    [Test]
    procedure Call_Result_IsInstanceOfFunction;
  end;

implementation

procedure TFunctionConstructorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionConstructorTests.TearDown;
begin
  FEngine.Free;
end;

procedure TFunctionConstructorTests.Call_BodyOnly_ReturnsFunction;
begin
  Assert.AreEqual('function', FEngine.Evaluate('typeof Function("return 1")').AsString);
end;

procedure TFunctionConstructorTests.Call_ParametersAndBody_CreatesWorkingFunction;
begin
  Assert.AreEqual(5.0, FEngine.Evaluate('Function("a", "b", "return a + b")(2, 3)').AsNumber);
end;

procedure TFunctionConstructorTests.Call_CommaSeparatedParameters_AreSplit;
begin
  Assert.AreEqual(6.0, FEngine.Evaluate('Function("a, b", "c", "return a + b + c")(1, 2, 3)').AsNumber);
end;

procedure TFunctionConstructorTests.New_CreatesCallableFunction;
begin
  Assert.AreEqual(8.0, FEngine.Evaluate('new Function("x", "return x * 2")(4)').AsNumber);
end;

procedure TFunctionConstructorTests.Call_NoArguments_CreatesEmptyFunction;
begin
  Assert.IsTrue(FEngine.Evaluate('Function()() === undefined').AsBoolean);
end;

procedure TFunctionConstructorTests.Call_FunctionRunsInGlobalScope;
begin
  FEngine.Execute('var seen = 7; function outer() { var seen = 1; return Function("return seen")(); }');

  Assert.AreEqual(7.0, FEngine.Evaluate('outer()').AsNumber);
end;

procedure TFunctionConstructorTests.Call_InvalidBody_ThrowsSyntaxError;
begin
  FEngine.Execute('var caught = false; try { Function("return +"); } catch (e) { caught = e instanceof SyntaxError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TFunctionConstructorTests.Call_InvalidParameter_ThrowsSyntaxError;
begin
  FEngine.Execute('var caught = false; try { Function("a b", ""); } catch (e) { caught = e instanceof SyntaxError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TFunctionConstructorTests.Call_BodyClosingBraceInjection_ThrowsSyntaxError;
begin
  FEngine.Execute('var caught = false; try { Function("}); (function() {"); } catch (e) { caught = e instanceof SyntaxError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TFunctionConstructorTests.Call_StrictBody_AppliesStrictMode;
begin
  Assert.IsTrue(FEngine.Evaluate('Function("''use strict''; return this === undefined;")()').AsBoolean);
end;

procedure TFunctionConstructorTests.Call_Result_IsInstanceOfFunction;
begin
  Assert.IsTrue(FEngine.Evaluate('Function("") instanceof Function').AsBoolean);
end;

end.
