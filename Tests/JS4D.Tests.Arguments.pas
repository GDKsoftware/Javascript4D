unit JS4D.Tests.Arguments;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TArgumentsTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('ThreeArguments', 'count(1, 2, 3)#3', '#')]
    [TestCase('NoArguments', 'count()#0', '#')]
    procedure Arguments_CountCall_LengthIsNumberOfPassedValues(const Call: string; const Expected: Double);

    [Test]
    procedure Arguments_ExposesValuesByIndex;

    [Test]
    procedure Arguments_ExtraArgumentsBeyondParameters_AreAvailable;

    [Test]
    [TestCase('FirstCall', 'a[0],1')]
    [TestCase('SecondCall', 'b[0],2')]
    procedure Arguments_TwoCalls_EachCallGetsItsOwnObject(const Read: string; const Expected: Double);

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

const
  COUNT_ARGUMENTS_SCRIPT = 'function count() { return arguments.length; }';

procedure TArgumentsTests.Arguments_CountCall_LengthIsNumberOfPassedValues(const Call: string;
                                                                           const Expected: Double);
begin
  FEngine.Execute(COUNT_ARGUMENTS_SCRIPT);

  const Actual = EvaluateNumber(Call);

  Assert.AreEqual(Expected, Actual);
end;

procedure TArgumentsTests.Arguments_ExposesValuesByIndex;
begin
  FEngine.Execute('function second() { return arguments[1]; }');

  const Actual = EvaluateText('second("a", "b")');

  Assert.AreEqual('b', Actual);
end;

procedure TArgumentsTests.Arguments_ExtraArgumentsBeyondParameters_AreAvailable;
begin
  FEngine.Execute('function first(a) { return arguments[2]; }');

  const Actual = EvaluateNumber('first(1, 2, 9)');

  Assert.AreEqual(9.0, Actual);
end;

procedure TArgumentsTests.Arguments_TwoCalls_EachCallGetsItsOwnObject(const Read: string; const Expected: Double);
begin
  FEngine.Execute('function grab() { return arguments; } var a = grab(1); var b = grab(2);');

  const Actual = EvaluateNumber(Read);

  Assert.AreEqual(Expected, Actual);
end;

procedure TArgumentsTests.Arguments_ClosureCalledRepeatedly_KeepsCapturedState;
begin
  FEngine.Execute('var next = (function() { var n = 0; return function() { n = n + 1; return n; }; })();');
  FEngine.Execute('next();');

  const Actual = EvaluateNumber('next()');

  Assert.AreEqual(2.0, Actual);
end;

procedure TArgumentsTests.Arguments_ParameterNamedArguments_ShadowsObject;
begin
  FEngine.Execute('function shadow(arguments) { return arguments; }');

  const Actual = EvaluateNumber('shadow(5)');

  Assert.AreEqual(5.0, Actual);
end;

procedure TArgumentsTests.Arguments_InsideNestedFunction_RefersToInnerCall;
begin
  FEngine.Execute(
    'function outer() { function inner() { return arguments.length; } return inner(1, 2); }');

  const Actual = EvaluateNumber('outer(1, 2, 3, 4)');

  Assert.AreEqual(2.0, Actual);
end;

procedure TArgumentsTests.Arguments_ReadThroughEval_SeesCallArguments;
begin
  FEngine.Execute('function viaEval() { return eval(''arguments.length''); }');

  const Actual = EvaluateNumber('viaEval(1, 2, 3)');

  Assert.AreEqual(3.0, Actual);
end;

procedure TArgumentsTests.Arguments_TypeOfGlobalArguments_IsUndefined;
begin
  const Actual = EvaluateText('typeof arguments');

  Assert.AreEqual('undefined', Actual);
end;

end.
