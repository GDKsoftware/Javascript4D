unit JS4D.Tests.RestrictedProperties;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TRestrictedPropertyTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StrictArguments_Callee_IsPoisonedAccessor;

    [Test]
    procedure StrictArguments_ReadingCallee_ThrowsTypeError;

    [Test]
    procedure ThrowTypeError_IsFrozen;

    [Test]
    procedure ThrowTypeError_IsSharedBetweenArgumentsObjects;

    [Test]
    procedure ThrowTypeError_IsFunctionPrototypeCallerAccessor;

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

procedure TRestrictedPropertyTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRestrictedPropertyTests.TearDown;
begin
  FEngine.Free;
end;

function TRestrictedPropertyTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TRestrictedPropertyTests.StrictArguments_Callee_IsPoisonedAccessor;
begin
  Assert.IsTrue(EvaluateBoolean('var d = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee''); d.get !== undefined && d.get === d.set && !d.configurable'));
end;

procedure TRestrictedPropertyTests.StrictArguments_ReadingCallee_ThrowsTypeError;
begin
  Assert.IsTrue(EvaluateBoolean('var caught = false; try { (function () { ''use strict''; return arguments.callee; })(); } catch (e) { caught = e instanceof TypeError; } caught'));
end;

procedure TRestrictedPropertyTests.ThrowTypeError_IsFrozen;
begin
  Assert.IsTrue(EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; Object.isFrozen(t)'));
end;

procedure TRestrictedPropertyTests.ThrowTypeError_IsSharedBetweenArgumentsObjects;
begin
  Assert.IsTrue(EvaluateBoolean('function s() { ''use strict''; return arguments; } Object.getOwnPropertyDescriptor(s(), ''callee'').get === Object.getOwnPropertyDescriptor(s(), ''callee'').set'));
end;

procedure TRestrictedPropertyTests.ThrowTypeError_IsFunctionPrototypeCallerAccessor;
begin
  Assert.IsTrue(EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; Object.getOwnPropertyDescriptor(Function.prototype, ''caller'').get === t'));
end;

procedure TRestrictedPropertyTests.ThrowTypeError_Called_ThrowsTypeError;
begin
  Assert.IsTrue(EvaluateBoolean('var t = Object.getOwnPropertyDescriptor((function () { ''use strict''; return arguments; })(), ''callee'').get; var caught = false; try { t(); } catch (e) { caught = e instanceof TypeError; } caught'));
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_HasNoPrototypeProperty;
begin
  Assert.IsTrue(EvaluateBoolean('RegExp.prototype.exec.prototype === undefined'));
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_MatchesOnRegExp;
begin
  Assert.IsTrue(EvaluateBoolean('RegExp.prototype.exec.call(/b/, ''abc'')[0] === ''b'''));
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Test_MatchesOnRegExp;
begin
  Assert.IsTrue(EvaluateBoolean('RegExp.prototype.test.call(/b/, ''abc'') === true'));
end;

procedure TRestrictedPropertyTests.RegExpPrototype_Exec_OnNonRegExp_ThrowsTypeError;
begin
  Assert.IsTrue(EvaluateBoolean('var caught = false; try { RegExp.prototype.exec.call({}, ''a''); } catch (e) { caught = e instanceof TypeError; } caught'));
end;

procedure TRestrictedPropertyTests.StringPrototype_LocaleCompare_OrdersStrings;
begin
  Assert.IsTrue(EvaluateBoolean('''a''.localeCompare(''b'') < 0 && ''b''.localeCompare(''a'') > 0 && ''a''.localeCompare(''a'') === 0'));
end;

procedure TRestrictedPropertyTests.StringPrototype_ToLocaleUpperCase_UppercasesText;
begin
  Assert.IsTrue(EvaluateBoolean('''abc''.toLocaleUpperCase() === ''ABC'''));
end;

procedure TRestrictedPropertyTests.StringPrototype_ToLocaleLowerCase_LowercasesText;
begin
  Assert.IsTrue(EvaluateBoolean('''ABC''.toLocaleLowerCase() === ''abc'''));
end;

procedure TRestrictedPropertyTests.StringPrototype_LocaleCompare_HasNoPrototypeProperty;
begin
  Assert.IsTrue(EvaluateBoolean('String.prototype.localeCompare.prototype === undefined'));
end;

end.
