unit JS4D.Tests.StrictEarlyErrors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TStrictEarlyErrorsTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('Assign eval', '"use strict"; eval = 1')]
    [TestCase('Assign arguments', '"use strict"; arguments = 1')]
    [TestCase('Assign parenthesized eval', '"use strict"; (eval) = 1')]
    [TestCase('Compound eval', '"use strict"; eval += 1')]
    [TestCase('Compound arguments', '"use strict"; arguments >>>= 1')]
    [TestCase('Prefix eval', '"use strict"; ++eval')]
    [TestCase('Prefix arguments', '"use strict"; --arguments')]
    [TestCase('Postfix eval', '"use strict"; eval++')]
    [TestCase('Postfix arguments', '"use strict"; arguments--')]
    [TestCase('For in eval', '"use strict"; for (eval in {}) {}')]
    [TestCase('Var eval', '"use strict"; var eval')]
    [TestCase('Var arguments with initializer', '"use strict"; var arguments = 1')]
    [TestCase('Declaration named eval', '"use strict"; function eval() {}')]
    [TestCase('Expression named arguments', '"use strict"; (function arguments() {})')]
    [TestCase('Catch parameter eval', '"use strict"; try {} catch (eval) {}')]
    [TestCase('Catch parameter arguments', '"use strict"; try {} catch (arguments) {}')]
    [TestCase('Delete identifier', '"use strict"; var x; delete x')]
    [TestCase('Delete parenthesized identifier', '"use strict"; var x; delete (x)')]
    [TestCase('Assign eval in strict function', 'function f() { "use strict"; eval = 1; }')]
    [TestCase('Function Declaration named eval', 'function eval() { "use strict"; }')]
    [TestCase('Declaration named arguments', 'function arguments() { "use strict"; }')]
    [TestCase('Expression named eval', '(function eval() { "use strict"; })')]
    [TestCase('Declaration parameter eval', 'function f(eval) { "use strict"; }')]
    [TestCase('Declaration parameter arguments', 'function f(arguments) { "use strict"; }')]
    [TestCase('Declaration reserved name', 'function static() { "use strict"; }')]
    [TestCase('Declaration reserved parameter', 'function f(public) { "use strict"; }')]
    [TestCase('Expression reserved name', '(function interface() { "use strict"; })')]
    [TestCase('Expression parameter eval', '(function (eval) { "use strict"; })')]
    procedure StrictSource_RestrictedUse_RaisesSyntaxError(const Source: string);

    [Test]
    [TestCase('Assign arguments', '(function () { var arguments; arguments = 1; arguments++; })')]
    [TestCase('Declaration named eval', '(function () { function eval() {} })')]
    [TestCase('Catch parameter eval', '(function () { try {} catch (eval) {} })')]
    [TestCase('Delete identifier', '(function () { var x; delete x; })')]
    [TestCase('Parameter named eval', '(function (eval) {})')]
    [TestCase('Strict function elsewhere', 'function f() { "use strict"; } (function eval() {})')]
    procedure Source_InSloppyMode_AcceptsRestrictedNames(const Source: string);

    [Test]
    procedure DirectEval_InStrictFunction_InheritsStrictness;

    [Test]
    procedure DirectEval_InSloppyFunction_StaysSloppy;

    [Test]
    procedure IndirectEval_CalledFromStrictFunction_StaysSloppy;
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

procedure TStrictEarlyErrorsTests.StrictSource_RestrictedUse_RaisesSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TStrictEarlyErrorsTests.Source_InSloppyMode_AcceptsRestrictedNames(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreNotEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TStrictEarlyErrorsTests.DirectEval_InStrictFunction_InheritsStrictness;
begin
  FEngine.Execute('var caught = false;' +
                  'function f() { "use strict"; try { eval("var public = 1;"); } ' +
                  'catch (e) { caught = e instanceof SyntaxError; } }' +
                  'f();');

  const Caught = EvaluateBoolean('caught');

  Assert.IsTrue(Caught);
end;

procedure TStrictEarlyErrorsTests.DirectEval_InSloppyFunction_StaysSloppy;
begin
  FEngine.Execute('var caught = false;' +
                  'function f() { try { eval("var public = 1;"); } catch (e) { caught = true; } }' +
                  'f();');

  const Caught = EvaluateBoolean('caught');

  Assert.IsFalse(Caught);
end;

procedure TStrictEarlyErrorsTests.IndirectEval_CalledFromStrictFunction_StaysSloppy;
begin
  FEngine.Execute('var caught = false; var indirect = eval;' +
                  'function f() { "use strict"; try { indirect("var public = 1;"); } catch (e) { caught = true; } }' +
                  'f();');

  const Caught = EvaluateBoolean('caught');

  Assert.IsFalse(Caught);
end;

end.
