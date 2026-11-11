unit JS4D.Tests.FunctionParameters;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionParameterTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('UsedWhenMissing', 'function f(a, b = 5) { return b; } f(1)|5', '|')]
    [TestCase('UsedWhenUndefined', 'function f(a = 7) { return a; } f(undefined)|7', '|')]
    [TestCase('NotUsedForNull', 'function f(a = 7) { return a; } String(f(null))|null', '|')]
    [TestCase('NotUsedWhenPassed', 'function f(a = 7) { return a; } f(3)|3', '|')]
    [TestCase('NotUsedForFalsyValue', 'function f(a = 7) { return a; } f(0)|0', '|')]
    [TestCase('SeesEarlierParameter', 'function f(a, b = a + 1) { return b; } f(4)|5', '|')]
    [TestCase('SeesOuterBinding', 'var x = 10; function f(a = x) { return a; } f()|10', '|')]
    [TestCase('FunctionExpression', 'var f = function(a = 2) { return a; }; f()|2', '|')]
    [TestCase('ArrowFunction', 'var f = (a, b = 3) => a + b; f(1)|4', '|')]
    [TestCase('ArrowFunctionSingleDefault', 'var f = (a = 9) => a; f()|9', '|')]
    [TestCase('ArrowAsDefaultValue', 'function f(g = () => 4) { return g(); } f()|4', '|')]
    [TestCase('ParenthesizedAssignmentIsNotArrow', 'var a; var r = (a = 5); r + a|10', '|')]
    [TestCase('ObjectMethod', 'var o = { m(a = 6) { return a; } }; o.m()|6', '|')]
    [TestCase('Setter', 'var o = { set s(v = 2) { this.x = v; } }; o.s = undefined; o.x|2', '|')]
    [TestCase('FunctionConstructor', 'new Function("a", "b = 2", "return a + b")(1)|3', '|')]
    [TestCase('NameIsInferred', 'function f(g = function() {}) { return g.name; } f()|g', '|')]
    [TestCase('ThisIsReceiver', 'var o = { v: 8, f: function(a = this.v) { return a; } }; o.f()|8', '|')]
    procedure Default_Result(const Source: string; const Expected: string);

    [Test]
    procedure Default_IsEvaluatedAtEachCall;

    [Test]
    procedure Default_IsNotEvaluatedWhenArgumentIsPassed;

    [Test]
    procedure Default_ReferencingLaterParameter_IsReferenceError;

    [Test]
    procedure Default_ReferencingOwnParameter_IsReferenceError;

    [Test]
    procedure Default_ClosureSeesParameterNotBodyVariable;

    [Test]
    procedure Body_VarWithParameterName_StartsWithParameterValue;

    [Test]
    procedure Body_VarWithParameterName_IsSeparateBinding;

    [Test]
    procedure Body_FunctionWithParameterName_ReplacesParameterInBody;

    [Test]
    procedure Arguments_WithDefaults_IsNotMappedToParameters;

    [Test]
    procedure Arguments_InDefault_RefersToCallArguments;

    [Test]
    [TestCase('NoDefaults', 'function f(a, b) {} f.length|2', '|')]
    [TestCase('StopsAtFirstDefault', 'function f(a, b = 1, c) {} f.length|1', '|')]
    [TestCase('DefaultFirst', 'function f(a = 1, b) {} f.length|0', '|')]
    [TestCase('RestIsNotCounted', 'function f(a, ...r) {} f.length|1', '|')]
    [TestCase('OnlyRest', 'function f(...r) {} f.length|0', '|')]
    [TestCase('ArrowWithDefault', '((a, b = 1) => 1).length|1', '|')]
    [TestCase('ArrowWithRest', '((a, ...r) => 1).length|1', '|')]
    [TestCase('MethodWithDefault', '({ m(a, b = 1) {} }).m.length|1', '|')]
    procedure Length_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Collects', 'function f(a, ...r) { return r.join(); } f(1, 2, 3)|2,3', '|')]
    [TestCase('EmptyWhenNoExtraArguments', 'function f(a, ...r) { return r.length; } f(1)|0', '|')]
    [TestCase('OnlyRest', 'function f(...r) { return r.length; } f(1, 2, 3, 4)|4', '|')]
    [TestCase('IsArray', 'function f(...r) { return Array.isArray(r); } f()|true', '|')]
    [TestCase('IsFreshArray', 'function f(...r) { return r; } f() !== f()|true', '|')]
    [TestCase('Arrow', 'var f = (...r) => r.length; f(1, 2)|2', '|')]
    [TestCase('ArrowAfterParameter', 'var f = (a, ...r) => r[0]; f(1, 2)|2', '|')]
    [TestCase('WithDefaultBefore', 'function f(a = 1, ...r) { return a + r.length; } f(undefined, 5, 6)|3', '|')]
    [TestCase('Method', 'var o = { m(...r) { return r.length; } }; o.m(1, 2, 3)|3', '|')]
    [TestCase('VarWithRestName', 'function f(a = 1, ...r) { var r; return r.length; } f(undefined, 1, 2)|2', '|')]
    [TestCase('ArgumentsStillHoldsAll', 'function f(a, ...r) { return arguments.length; } f(1, 2, 3)|3', '|')]
    [TestCase('FunctionConstructor', 'new Function("...r", "return r.length")(1, 2)|2', '|')]
    procedure Rest_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Call', 'function f(a, b, c) { return a + b + c; } f(...[1, 2, 3])|6', '|')]
    [TestCase('CallMixed', 'function f() { return Array.prototype.join.call(arguments); } f(0, ...[1, 2], 3, ...[4])|0,1,2,3,4', '|')]
    [TestCase('CallEmptyArray', 'function f() { return arguments.length; } f(...[])|0', '|')]
    [TestCase('CallString', 'function f() { return arguments.length; } f(..."abc")|3', '|')]
    [TestCase('CallStringSurrogatePair', 'function f() { return arguments.length; } f(..."a'#$D83D#$DE00'b")|3', '|')]
    [TestCase('MethodCall', 'var o = { v: 2, f: function(a, b) { return this.v * (a + b); } }; o.f(...[1, 2])|6', '|')]
    [TestCase('BuiltinMethod', 'Math.max(...[1, 9, 3])|9', '|')]
    [TestCase('ArrayPush', 'var a = [1]; a.push(...[2, 3]); a.join()|1,2,3', '|')]
    [TestCase('HoleBecomesUndefined', 'function f(a, b) { return typeof b; } f(...[1, ,])|undefined', '|')]
    [TestCase('New', 'function P(a, b) { this.s = a + b; } new P(...[1, 2]).s|3', '|')]
    [TestCase('NewMixed', 'function P() { this.n = arguments.length; } new P(1, ...[2, 3]).n|3', '|')]
    [TestCase('EvaluatedLeftToRight', 'var log = ""; function t(x) { log += x; return [x]; } Math.max(...t(1), ...t(2)); log|12', '|')]
    [TestCase('ArrowCall', 'var f = (...r) => r.length; f(...[1, 2], ...[3])|3', '|')]
    procedure SpreadCall_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Array', '[0, ...[1, 2], 3].join()|0,1,2,3', '|')]
    [TestCase('OnlyArray', '[...[1, 2]].length|2', '|')]
    [TestCase('Empty', '[...[]].length|0', '|')]
    [TestCase('String', '[..."ab"].join()|a,b', '|')]
    [TestCase('StringSurrogatePair', '[..."'#$D83D#$DE00'"].length|1', '|')]
    [TestCase('Twice', '[...[1], ...[2]].join()|1,2', '|')]
    [TestCase('HolesBecomeUndefined', '[...[1, ,2]].hasOwnProperty(1)|true', '|')]
    [TestCase('ElisionBeforeSpread', '[, ...[1]].hasOwnProperty(0)|false', '|')]
    [TestCase('IsCopy', 'var a = [1]; var b = [...a]; b.push(2); a.length|1', '|')]
    [TestCase('Nested', '[...[...[1, 2]], 3].join()|1,2,3', '|')]
    [TestCase('ArgumentOfSpreadCall', 'Math.max(...[...[1, 5], 2])|5', '|')]
    procedure SpreadArray_Result(const Source: string; const Expected: string);

    [Test]
    procedure New_EvaluatesArgumentsBeforeCheckingConstructor;

    [Test]
    [TestCase('Number', 'f(...1);', '|')]
    [TestCase('Undefined', 'f(...undefined);', '|')]
    [TestCase('Null', 'f(...null);', '|')]
    [TestCase('PlainObject', 'f(...{});', '|')]
    [TestCase('ArrayLiteralOfNumber', '[...5];', '|')]
    [TestCase('NewOfNumber', 'new f(...5);', '|')]
    procedure Spread_OfNonIterable_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('DefaultSeesLaterParameter', 'function f(a = b, b) {} f();', '|')]
    procedure Default_RaisesReferenceError(const Source: string);

    [Test]
    [TestCase('RestNotLast', 'function f(...a, b) {}', '|')]
    [TestCase('RestWithDefault', 'function f(...a = []) {}', '|')]
    [TestCase('RestTrailingComma', 'function f(...a,) {}', '|')]
    [TestCase('RestWithoutName', 'function f(...) {}', '|')]
    [TestCase('TwoRest', 'function f(...a, ...b) {}', '|')]
    [TestCase('DuplicateWithDefault', 'function f(a, a = 1) {}', '|')]
    [TestCase('DuplicateWithRest', 'function f(a, ...a) {}', '|')]
    [TestCase('UseStrictWithDefault', 'function f(a = 1) { "use strict"; }', '|')]
    [TestCase('UseStrictWithRest', 'function f(...a) { "use strict"; }', '|')]
    [TestCase('UseStrictWithArrowDefault', 'var f = (a = 1) => { "use strict"; };', '|')]
    [TestCase('StrictEvalRest', '"use strict"; function f(...eval) {}', '|')]
    [TestCase('StrictRestNamedArguments', '"use strict"; function f(...arguments) {}', '|')]
    [TestCase('LexicalRedeclarationOfRest', 'function f(...a) { let a; }', '|')]
    [TestCase('LexicalRedeclarationOfDefaulted', 'function f(a = 1) { let a; }', '|')]
    [TestCase('SetterWithRest', 'var o = { set s(...v) {} };', '|')]
    [TestCase('GetterWithRest', 'var o = { get g(...v) {} };', '|')]
    [TestCase('ArrowRestNotLast', 'var f = (...a, b) => 1;', '|')]
    [TestCase('ArrowRestWithDefault', 'var f = (...a = 1) => 1;', '|')]
    [TestCase('ArrowDuplicateWithDefault', 'var f = (a, a = 1) => 1;', '|')]
    [TestCase('SpreadWithoutOperand', 'f(...);', '|')]
    [TestCase('DoubleCommaInArguments', 'f(a,,);', '|')]
    [TestCase('OnlyCommaInArguments', 'f(,);', '|')]
    [TestCase('DoubleCommaInParameters', 'function f(a,,) {}', '|')]
    [TestCase('SpreadInNewWithoutOperand', 'new f(...);', '|')]
    [TestCase('SpreadInParenthesizedExpression', 'var a = (...b);', '|')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('DefaultWithComma', 'function f(a = 1, b = 2) {}', '|')]
    [TestCase('RestAfterDefault', 'function f(a = 1, ...b) {}', '|')]
    [TestCase('SloppyRestNamedEval', 'function f(...eval) {}', '|')]
    [TestCase('TrailingCommaAfterDefault', 'function f(a = 1,) {}', '|')]
    [TestCase('TrailingCommaInParameters', 'function f(a, b,) {}', '|')]
    [TestCase('TrailingCommaInArguments', 'function g() {} g(1, 2,);', '|')]
    [TestCase('TrailingCommaAfterSpread', 'function g() {} g(...[1],);', '|')]
    [TestCase('TrailingCommaInNewArguments', 'function g() {} new g(1,);', '|')]
    [TestCase('ArrowTrailingCommaAfterDefault', 'var f = (a = 1,) => a;', '|')]
    [TestCase('ArrowWithCallInDefault', 'var f = (a = g(1, 2)) => a;', '|')]
    [TestCase('ArrowWithObjectInDefault', 'var f = (a = { x: (1) }) => a;', '|')]
    [TestCase('ArrowWithTemplateInDefault', 'var f = (a = `x${1}`) => a;', '|')]
    [TestCase('SpreadAsOnlyArgument', 'function g() {} g(...[1]);', '|')]
    [TestCase('SpreadOfCallResult', 'function g() { return []; } g(...g());', '|')]
    [TestCase('SpreadAfterNewline', 'function g() {} g('#10'...[1]);', '|')]
    procedure Source_IsAccepted(const Source: string);
  end;

implementation

procedure TFunctionParameterTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionParameterTests.TearDown;
begin
  FEngine.Free;
end;

function TFunctionParameterTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TFunctionParameterTests.Default_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TFunctionParameterTests.Default_IsEvaluatedAtEachCall;
begin
  const Script = 'var n = 0; function f(a = ++n) { return a; } f(); f(); f()';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionParameterTests.Default_IsNotEvaluatedWhenArgumentIsPassed;
begin
  const Script = 'var n = 0; function f(a = ++n) { return a; } f(1); f(2); n';

  Assert.AreEqual(0.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionParameterTests.Default_ReferencingLaterParameter_IsReferenceError;
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf('function f(a = b, b) {} f();'));
end;

procedure TFunctionParameterTests.Default_ReferencingOwnParameter_IsReferenceError;
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf('function f(a = a) {} f();'));
end;

procedure TFunctionParameterTests.Default_ClosureSeesParameterNotBodyVariable;
begin
  const Script = 'var x = "outer"; function f(g = () => x) { var x = "body"; return g(); } f()';

  Assert.AreEqual('outer', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionParameterTests.Body_VarWithParameterName_StartsWithParameterValue;
begin
  const Script = 'function f(a = 1) { var a; return a; } f(5)';

  Assert.AreEqual(5.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionParameterTests.Body_VarWithParameterName_IsSeparateBinding;
begin
  const Script = 'function f(a = 1, g = () => a) { var a = 2; return g() + "," + a; } f()';

  Assert.AreEqual('1,2', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionParameterTests.Body_FunctionWithParameterName_ReplacesParameterInBody;
begin
  const Script = 'function f(a = 1) { function a() {} return typeof a; } f()';

  Assert.AreEqual('function', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionParameterTests.Arguments_WithDefaults_IsNotMappedToParameters;
begin
  const Script = 'function f(a, b = 2) { arguments[0] = 9; return a; } f(1)';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionParameterTests.Arguments_InDefault_RefersToCallArguments;
begin
  const Script = 'function f(a = arguments.length) { return a; } f(undefined, 2, 3)';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TFunctionParameterTests.Length_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TFunctionParameterTests.Rest_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TFunctionParameterTests.SpreadCall_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TFunctionParameterTests.SpreadArray_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TFunctionParameterTests.New_EvaluatesArgumentsBeforeCheckingConstructor;
begin
  const Script = 'var x = {}; var caught = ""; try { new x(x = Array); } catch (e) { caught = e.name; } ' +
                 'caught + "," + (x === Array)';

  Assert.AreEqual('TypeError,true', FEngine.Evaluate(Script).AsString);
end;

procedure TFunctionParameterTests.Spread_OfNonIterable_RaisesTypeError(const Source: string);
begin
  const Script = Format('function f() {} %s', [Source]);

  Assert.AreEqual('TypeError', ErrorNameOf(Script));
end;

procedure TFunctionParameterTests.Default_RaisesReferenceError(const Source: string);
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf(Source));
end;

procedure TFunctionParameterTests.Source_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TFunctionParameterTests.Source_IsAccepted(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

end.
