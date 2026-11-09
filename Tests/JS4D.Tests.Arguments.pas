unit JS4D.Tests.Arguments;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArgumentsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Arguments_ReportsPassedCount;

    [Test]
    procedure Arguments_ExposesValuesByIndex;

    [Test]
    procedure Arguments_ExtraArgumentsBeyondParameters_AreAvailable;

    [Test]
    procedure Arguments_NoArguments_HasZeroLength;

    [Test]
    procedure Arguments_EachCallGetsItsOwnObject;

    [Test]
    procedure Arguments_ClosureCalledRepeatedly_KeepsCapturedState;

    [Test]
    procedure Arguments_ParameterNamedArguments_ShadowsObject;

    [Test]
    procedure Arguments_InsideNestedFunction_RefersToInnerCall;

    [Test]
    procedure Arguments_ReadThroughEval_SeesCallArguments;

    [Test]
    procedure Arguments_TypeOfGlobalArguments_IsUndefined;
  end;

implementation

procedure TArgumentsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArgumentsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TArgumentsTests.Arguments_ReportsPassedCount;
begin
  FEngine.Execute('function count() { return arguments.length; }');

  Assert.AreEqual(3.0, FEngine.Evaluate('count(1, 2, 3)').AsNumber);
end;

procedure TArgumentsTests.Arguments_ExposesValuesByIndex;
begin
  FEngine.Execute('function second() { return arguments[1]; }');

  Assert.AreEqual('b', FEngine.Evaluate('second("a", "b")').AsString);
end;

procedure TArgumentsTests.Arguments_ExtraArgumentsBeyondParameters_AreAvailable;
begin
  FEngine.Execute('function first(a) { return arguments[2]; }');

  Assert.AreEqual(9.0, FEngine.Evaluate('first(1, 2, 9)').AsNumber);
end;

procedure TArgumentsTests.Arguments_NoArguments_HasZeroLength;
begin
  FEngine.Execute('function count() { return arguments.length; }');

  Assert.AreEqual(0.0, FEngine.Evaluate('count()').AsNumber);
end;

procedure TArgumentsTests.Arguments_EachCallGetsItsOwnObject;
begin
  FEngine.Execute('function grab() { return arguments; } var a = grab(1); var b = grab(2);');

  Assert.AreEqual(1.0, FEngine.Evaluate('a[0]').AsNumber);
  Assert.AreEqual(2.0, FEngine.Evaluate('b[0]').AsNumber);
end;

procedure TArgumentsTests.Arguments_ClosureCalledRepeatedly_KeepsCapturedState;
begin
  FEngine.Execute('var next = (function() { var n = 0; return function() { n = n + 1; return n; }; })();');
  FEngine.Execute('next();');

  Assert.AreEqual(2.0, FEngine.Evaluate('next()').AsNumber);
end;

procedure TArgumentsTests.Arguments_ParameterNamedArguments_ShadowsObject;
begin
  FEngine.Execute('function shadow(arguments) { return arguments; }');

  Assert.AreEqual(5.0, FEngine.Evaluate('shadow(5)').AsNumber);
end;

procedure TArgumentsTests.Arguments_InsideNestedFunction_RefersToInnerCall;
begin
  FEngine.Execute(
    'function outer() { function inner() { return arguments.length; } return inner(1, 2); }');

  Assert.AreEqual(2.0, FEngine.Evaluate('outer(1, 2, 3, 4)').AsNumber);
end;

procedure TArgumentsTests.Arguments_ReadThroughEval_SeesCallArguments;
begin
  FEngine.Execute('function viaEval() { return eval(''arguments.length''); }');

  Assert.AreEqual(3.0, FEngine.Evaluate('viaEval(1, 2, 3)').AsNumber);
end;

procedure TArgumentsTests.Arguments_TypeOfGlobalArguments_IsUndefined;
begin
  Assert.AreEqual('undefined', FEngine.Evaluate('typeof arguments').AsString);
end;

end.
