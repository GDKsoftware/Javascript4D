unit JS4D.Tests.RestrictedProperties;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TRestrictedPropertyTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure StrictArguments_Callee_IsPoisonedAccessor;

    [Test]
    procedure StrictArguments_ReadingCallee_ThrowsTypeError;

    [Test]
    procedure ThrowTypeError_Function_IsFrozen;

    [Test]
    procedure ThrowTypeError_StrictArgumentsObjects_ShareOneFunction;

    [Test]
    procedure ThrowTypeError_FunctionPrototypeCaller_UsesSameFunction;

    [Test]
    procedure ThrowTypeError_Called_ThrowsTypeError;

    [Test]
    procedure RegExpPrototype_Exec_HasNoPrototypeProperty;

    [Test]
    procedure RegExpPrototype_Exec_MatchesOnRegExp;

    [Test]
    procedure RegExpPrototype_Test_MatchesOnRegExp;

    [Test]
    procedure RegExpPrototype_Exec_OnNonRegExp_ThrowsTypeError;

    [Test]
    procedure StringPrototype_LocaleCompare_OrdersStrings;

    [Test]
    procedure StringPrototype_ToLocaleUpperCase_UppercasesText;

    [Test]
    procedure StringPrototype_ToLocaleLowerCase_LowercasesText;

    [Test]
    procedure StringPrototype_LocaleCompare_HasNoPrototypeProperty;
  end;

implementation

procedure TRestrictedPropertyTests.StrictArguments_Callee_IsPoisonedAccessor;
begin
  const Actual = EvaluateBoolean('var d = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee''); d.get !== undefined && d.get === d.set && !d.configurable');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.StrictArguments_ReadingCallee_ThrowsTypeError;
begin
  const Actual = EvaluateBoolean('var caught = false; try { (function () { ''use strict''; return arguments.callee; })(); } catch (e) { caught = e instanceof TypeError; } caught');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.ThrowTypeError_Function_IsFrozen;
begin
  const Actual = EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; Object.isFrozen(t)');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.ThrowTypeError_StrictArgumentsObjects_ShareOneFunction;
begin
  const Actual = EvaluateBoolean('function s() { ''use strict''; return arguments; } Object.getOwnPropertyDescriptor(s(), ''callee'').get === Object.getOwnPropertyDescriptor(s(), ''callee'').set');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.ThrowTypeError_FunctionPrototypeCaller_UsesSameFunction;
begin
  const Actual = EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; Object.getOwnPropertyDescriptor(Function.prototype, ''caller'').get === t');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.ThrowTypeError_Called_ThrowsTypeError;
begin
  const Actual = EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; var caught = false; try { t(); } catch (e) { caught = e instanceof TypeError; } caught');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_HasNoPrototypeProperty;
begin
  const Actual = EvaluateBoolean('RegExp.prototype.exec.prototype === undefined');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_MatchesOnRegExp;
begin
  const Actual = EvaluateBoolean('RegExp.prototype.exec.call(/b/, ''abc'')[0] === ''b''');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Test_MatchesOnRegExp;
begin
  const Actual = EvaluateBoolean('RegExp.prototype.test.call(/b/, ''abc'') === true');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_OnNonRegExp_ThrowsTypeError;
begin
  const Actual = EvaluateBoolean('var caught = false; try { RegExp.prototype.exec.call({}, ''a''); } catch (e) { caught = e instanceof TypeError; } caught');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.StringPrototype_LocaleCompare_OrdersStrings;
begin
  const Actual = EvaluateBoolean('''a''.localeCompare(''b'') < 0 && ''b''.localeCompare(''a'') > 0 && ''a''.localeCompare(''a'') === 0');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.StringPrototype_ToLocaleUpperCase_UppercasesText;
begin
  const Actual = EvaluateBoolean('''abc''.toLocaleUpperCase() === ''ABC''');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.StringPrototype_ToLocaleLowerCase_LowercasesText;
begin
  const Actual = EvaluateBoolean('''ABC''.toLocaleLowerCase() === ''abc''');

  Assert.IsTrue(Actual);
end;

procedure TRestrictedPropertyTests.StringPrototype_LocaleCompare_HasNoPrototypeProperty;
begin
  const Actual = EvaluateBoolean('String.prototype.localeCompare.prototype === undefined');

  Assert.IsTrue(Actual);
end;

end.
