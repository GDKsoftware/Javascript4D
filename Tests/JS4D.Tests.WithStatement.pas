unit JS4D.Tests.WithStatement;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.ErrorNames,
  JS4D.Tests.Support;

type
  [TestFixture]
  TWithStatementTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure ObjectScope_DeclareLexical_RaisesNotSupported;

    [Test]
    [TestCase('With_ReadsPropertyOfObject', 'var o = {a: 5}; var r; with (o) { r = a; } r|5', '|')]
    [TestCase('With_ReadsPropertyFromPrototypeChain',
      'function P() {} P.prototype.inherited = 7;' + sLineBreak +
      'var o = new P(); var r; with (o) { r = inherited; } r|7', '|')]
    [TestCase('With_UnknownNameFallsBackToOuterScope', 'var outer = 3; var r; with ({}) { r = outer; } r|3', '|')]
    [TestCase('With_AssignmentToExistingPropertyWritesObject',
      'var a = 1; var o = {a: 2}; with (o) { a = 9; } o.a * 10 + a|91', '|')]
    [TestCase('With_AssignmentToUnknownNameWritesOuterVariable',
      'var x = 1; var o = {}; with (o) { x = 4; } x * 10 + (o.hasOwnProperty("x") ? 1 : 0)|40', '|')]
    [TestCase('With_CompoundAssignmentAndIncrementUseObjectProperty',
      'var n = 100; var o = {n: 1}; with (o) { n += 2; n++; } o.n * 1000 + n|4100', '|')]
    [TestCase('With_VarDeclarationWithInitializerWritesObjectProperty',
      'var o = {v: 1}; with (o) { var v = 5; } o.v * 10 + (v === undefined ? 1 : 0)|51', '|')]
    [TestCase('With_VarDeclarationIsHoistedToEnclosingFunction',
      'function f() { with ({}) { var hoisted = 2; } return hoisted; }' + sLineBreak + 'f()|2', '|')]
    [TestCase('With_MethodCallUsesObjectAsThis',
      'var o = {k: 6, get: function() { return this.k; }};' + sLineBreak +
      'var r; with (o) { r = get(); } r|6', '|')]
    [TestCase('With_ClosureKeepsObjectInScope',
      'var f; with ({z: 8}) { f = function() { return z; }; }' + sLineBreak + 'f()|8', '|')]
    [TestCase('With_PrimitiveIsConvertedToWrapperObject', 'var r; with ("abc") { r = length; } r|3', '|')]
    [TestCase('With_BreakAndReturnLeaveObjectScope',
      'var a = 1;' + sLineBreak + 'function f() { with ({a: 2}) { return a; } }' + sLineBreak +
      'for (var i = 0; i < 1; i++) { with ({a: 3}) { break; } }' + sLineBreak + 'f() * 10 + a|21', '|')]
    [TestCase('With_LetIdentifierFollowedByNewline_IsExpressionStatement',
      'var let = 4; var r; with ({}) let' + sLineBreak + 'r = let; r|4', '|')]
    [TestCase('With_AssignmentWritesBindingResolvedBeforeRightHandSide',
      'var outer = {x: 0}; var inner = {x: 1};' + sLineBreak +
      'with (outer) { with (inner) { x = (delete inner.x, 2); } }' + sLineBreak +
      'inner.x * 10 + outer.x|20', '|')]
    [TestCase('With_AssignmentRecreatesPropertyDeletedByRightHandSide',
      'var x = 0; var scope = {x: 1};' + sLineBreak + 'with (scope) { x = (delete scope.x, 5); }' +
      sLineBreak + 'scope.x * 10 + x|50', '|')]
    [TestCase('With_CompoundAssignmentRecreatesPropertyDeletedByGetter',
      'var x = 0; var scope = { get x() { delete this.x; return 2; } };' + sLineBreak +
      'with (scope) { x *= 3; }' + sLineBreak + 'scope.x * 10 + x|60', '|')]
    [TestCase('With_IncrementRecreatesPropertyDeletedByGetter',
      'var x = 0; var scope = { get x() { delete this.x; return 2; } };' + sLineBreak +
      'with (scope) { x++; }' + sLineBreak + 'scope.x * 10 + x|30', '|')]
    [TestCase('Assignment_WritesVariableResolvedBeforeEvalDeclaresShadow',
      'var x = 0;' + sLineBreak +
      'var innerX = (function() { x = (eval("var x = 2;"), 1); return x; })();' + sLineBreak +
      'innerX * 10 + x|21', '|')]
    [TestCase('With_IncrementAndDecrementReadUnscopablesOnce',
      'var calls = 0; var o = { x: 4, get [Symbol.unscopables]() { calls++; return {}; } };' + sLineBreak +
      'with (o) { x++; x--; ++x; --x; }' + sLineBreak + 'calls * 10 + o.x|44', '|')]
    procedure With_Script_ReturnsNumber(const Script: string; const Expected: Double);

    [Test]
    [TestCase('With_TypeofOfObjectPropertyIsDefined', 'var r; with ({q: 1}) { r = typeof q; } r|number', '|')]
    [TestCase('With_ReadChecksBindingAgainAfterResolution',
      'var log = []; var proxy = new Proxy({ p: 7 }, {' + sLineBreak +
      '  has: function (t, k) { log.push("has:" + String(k)); return Reflect.has(t, k); },' + sLineBreak +
      '  get: function (t, k, r) { log.push("get:" + String(k)); return Reflect.get(t, k, r); } });' +
      sLineBreak + 'with (proxy) { p; }' + sLineBreak +
      'log.join()|has:p,get:Symbol(Symbol.unscopables),has:p,get:p', '|')]
    [TestCase('With_CallResolvesCalleeOnce',
      'var log = []; var proxy = new Proxy({}, {' + sLineBreak +
      '  has: function (t, k) { log.push("has:" + String(k)); return Reflect.has(t, k); } });' +
      sLineBreak + 'function f() { with (proxy) { Object(); } }' + sLineBreak + 'f(); log.join()|has:Object', '|')]
    [TestCase('With_CallReadsCalleeFromBindingObject',
      'var log = []; var proxy = new Proxy({ Object: Object }, {' + sLineBreak +
      '  has: function (t, k) { log.push("has:" + String(k)); return Reflect.has(t, k); },' + sLineBreak +
      '  get: function (t, k, r) { log.push("get:" + String(k)); return Reflect.get(t, k, r); } });' +
      sLineBreak + 'function f() { with (proxy) { Object(); } }' + sLineBreak +
      'f(); log.join()|has:Object,get:Symbol(Symbol.unscopables),has:Object,get:Object', '|')]
    [TestCase('With_AssignmentChecksBindingAgainBeforeSet',
      'var log = []; var proxy = new Proxy({ p: 0 }, {' + sLineBreak +
      '  has: function (t, k) { log.push("has:" + String(k)); return Reflect.has(t, k); },' + sLineBreak +
      '  get: function (t, k, r) { log.push("get:" + String(k)); return Reflect.get(t, k, r); },' +
      sLineBreak +
      '  set: function (t, k, v, r) { log.push("set:" + String(k)); return Reflect.set(t, k, v, ' +
      'r); } });' + sLineBreak + 'with (proxy) { p = 1; }' + sLineBreak +
      'log.slice(0, 4).join()|has:p,get:Symbol(Symbol.unscopables),has:p,set:p', '|')]
    [TestCase('With_CompoundAssignmentReadsAndWritesResolvedBinding',
      'var log = []; var proxy = new Proxy({ p: 0 }, {' + sLineBreak +
      '  has: function (t, k) { log.push("has:" + String(k)); return Reflect.has(t, k); },' + sLineBreak +
      '  get: function (t, k, r) { log.push("get:" + String(k)); return Reflect.get(t, k, r); },' +
      sLineBreak +
      '  set: function (t, k, v, r) { log.push("set:" + String(k)); return Reflect.set(t, k, v, ' +
      'r); } });' + sLineBreak + 'with (proxy) { p += 1; }' + sLineBreak +
      'log.join()|has:p,get:Symbol(Symbol.unscopables),has:p,get:p,has:p,set:p', '|')]
    procedure With_Script_ReturnsExpectedText(const Script: string; const Expected: string);

    [Test]
    [TestCase('With_NullOrUndefined_ThrowsTypeErrorNull', 'with (null) { }|' + TYPE_ERROR_NAME, '|')]
    [TestCase('With_NullOrUndefined_ThrowsTypeErrorUndefined', 'with (undefined) { }|' + TYPE_ERROR_NAME, '|')]
    [TestCase('With_InStrictMode_IsSyntaxError', 'eval("\"use strict\"; with ({}) { }");|' + SYNTAX_ERROR_NAME, '|')]
    [TestCase('With_InsideFunctionWithUseStrictDirective_IsSyntaxError',
      'new Function("\"use strict\"; var o = {}; with (o) { }");|' + SYNTAX_ERROR_NAME, '|')]
    [TestCase('With_FunctionDeclarationAsBody_IsSyntaxError',
      'eval("with ({}) function f() { }");|' + SYNTAX_ERROR_NAME, '|')]
    [TestCase('With_ReadOfBindingDeletedWhileResolving_ThrowsReferenceErrorInStrictCode',
      'var env = { binding: 0, get [Symbol.unscopables]() { delete env.binding; return null; } };' +
      sLineBreak + 'with (env) { (function () { "use strict"; binding; })(); }|' + REFERENCE_ERROR_NAME, '|')]
    procedure With_Source_RaisesError(const Source: string; const ExpectedError: string);

    [Test]
    procedure With_ReadOfBindingDeletedWhileResolving_IsUndefinedInSloppyCode;
  end;

implementation

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.ObjectScope;

procedure TWithStatementTests.ObjectScope_DeclareLexical_RaisesNotSupported;
begin
  const Bindings: IJSObject = TJSObject.Create;
  const Scope: IJSScope = TJSObjectScope.Create(nil, Bindings, nil);

  Assert.WillRaise(
    procedure
    begin
      Scope.DeclareLexical('x', False);
    end,
    ENotSupportedException);
end;

procedure TWithStatementTests.With_ReadOfBindingDeletedWhileResolving_IsUndefinedInSloppyCode;
begin
  const Script =
    'var env = { binding: 0, get [Symbol.unscopables]() { delete env.binding; return null; } };' + sLineBreak +
    'var r; with (env) { r = binding; } r';

  const Value = FEngine.Evaluate(Script);

  Assert.IsTrue(Value.IsUndefined);
end;

procedure TWithStatementTests.With_Script_ReturnsNumber(const Script: string; const Expected: Double);
begin
  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(Expected, Actual);
end;

procedure TWithStatementTests.With_Script_ReturnsExpectedText(const Script: string; const Expected: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual);
end;

procedure TWithStatementTests.With_Source_RaisesError(const Source: string; const ExpectedError: string);
begin
  const Actual = ThrownErrorNameOf(Source);

  Assert.AreEqual(ExpectedError, Actual);
end;

end.
