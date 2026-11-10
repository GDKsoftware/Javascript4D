unit JS4D.Tests.ArrowFunctions;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TArrowFunctionTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('SingleIdentifier', 'var f = x => x + 1; f(1)|2', '|')]
    [TestCase('EmptyParameters', 'var f = () => 7; f()|7', '|')]
    [TestCase('ParenthesizedSingle', 'var f = (x) => x * 2; f(4)|8', '|')]
    [TestCase('MultipleParameters', 'var f = (a, b, c) => a + b + c; f(1, 2, 3)|6', '|')]
    [TestCase('MissingArgumentIsUndefined', 'var f = (a, b) => typeof b; f(1)|undefined', '|')]
    [TestCase('BlockBody', 'var f = (a) => { var b = a * 3; return b; }; f(2)|6', '|')]
    [TestCase('BlockBodyWithoutReturn', 'var f = () => { 1; }; typeof f()|undefined', '|')]
    [TestCase('ObjectLiteralBody', 'var f = () => ({ a: 5 }); f().a|5', '|')]
    [TestCase('ConciseBodyIsAssignmentExpression', 'var f = x => y => x + y; f(1)(2)|3', '|')]
    [TestCase('ConditionalBody', 'var f = x => x ? "yes" : "no"; f(0)|no', '|')]
    [TestCase('ImmediatelyInvoked', '(x => x * x)(5)|25', '|')]
    [TestCase('AsArgument', '[1, 2, 3].map(x => x * 2).join()|2,4,6', '|')]
    [TestCase('CommaEndsConciseBody', 'var f = [x => 1, x => 2]; f.length|2', '|')]
    [TestCase('RegularExpressionBody', 'var f = s => /a+/.test(s); f("caat")|true', '|')]
    [TestCase('InsideTernaryAlternate', 'var f = true ? 1 : x => 2; f|1', '|')]
    procedure Call_Result(const Source: string; const Expected: string);

    [Test]
    procedure This_IsInheritedFromEnclosingFunction;

    [Test]
    procedure This_IgnoresCallAndApplyAndBind;

    [Test]
    procedure This_InNestedArrow_IsInheritedFromOuterFunction;

    [Test]
    procedure This_AtGlobalLevel_IsGlobalObject;

    [Test]
    procedure This_InStrictFunctionWithoutReceiver_IsUndefined;

    [Test]
    procedure This_InStrictGlobalCode_IsGlobalObject;

    [Test]
    procedure Arguments_AreTakenFromEnclosingFunction;

    [Test]
    procedure Arguments_InNestedArrow_AreTakenFromEnclosingFunction;

    [Test]
    procedure Arguments_AtGlobalLevel_IsReferenceError;

    [Test]
    procedure Prototype_IsNotDefined;

    [Test]
    procedure Length_IsParameterCount;

    [Test]
    procedure Length_WithTrailingComma_IgnoresComma;

    [Test]
    procedure TypeOf_IsFunction;

    [Test]
    procedure Closure_CapturesEnclosingBindings;

    [Test]
    procedure Parameters_ShadowOuterBindings;

    [Test]
    [TestCase('New', 'var f = () => 1; new f();', '|')]
    [TestCase('NewWithArguments', 'var f = (a) => a; new f(1);', '|')]
    procedure New_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('LineBreakBeforeArrow', 'var f = x'#10'=> x;', '|')]
    [TestCase('LineBreakBeforeArrowAfterParens', 'var f = (x)'#10'=> x;', '|')]
    [TestCase('DuplicateParameters', 'var f = (a, a) => 1;', '|')]
    [TestCase('DuplicateParametersStrict', '"use strict"; var f = (a, a) => 1;', '|')]
    [TestCase('NumberAsParameter', 'var f = (1) => 1;', '|')]
    [TestCase('ExpressionAsParameter', 'var f = (a + b) => 1;', '|')]
    [TestCase('MissingBody', 'var f = () =>;', '|')]
    [TestCase('ArrowWithoutParameters', 'var f = => 1;', '|')]
    [TestCase('ArrowIsNotACallee', 'var f = x => {}(1);', '|')]
    [TestCase('BinaryOperandIsNotAssignmentExpression', 'var f = 1 + x => x;', '|')]
    [TestCase('ReservedWordParameter', 'var f = (if) => 1;', '|')]
    [TestCase('StrictEvalParameter', '"use strict"; var f = eval => 1;', '|')]
    [TestCase('StrictArgumentsParameter', '"use strict"; var f = (arguments) => 1;', '|')]
    [TestCase('StrictFutureReservedWord', '"use strict"; var f = yield => 1;', '|')]
    [TestCase('UseStrictBodyMakesParametersStrict', 'var f = (eval) => { "use strict"; };', '|')]
    [TestCase('LexicalRedeclarationOfParameter', 'var f = (a) => { let a; };', '|')]
    [TestCase('BreakInsideBody', 'while (true) { var f = () => { break; }; }', '|')]
    [TestCase('OnlyComma', 'var f = (,) => 1;', '|')]
    [TestCase('DoubleTrailingComma', 'var f = (a,,) => 1;', '|')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('NewlineAfterArrow', 'var f = x =>'#10' x;', '|')]
    [TestCase('NewlineInsideParameters', 'var f = (a,'#10' b) => a;', '|')]
    [TestCase('ArrowAsStatement', 'x => x;', '|')]
    [TestCase('TrailingComma', 'var f = (a, b,) => a;', '|')]
    [TestCase('ArrowBodyIsVarScoped', 'var f = () => { var a; var a; };', '|')]
    [TestCase('ShadowedParameterInBody', 'var f = (a) => { var a; };', '|')]
    [TestCase('ArrowAfterNewlineWithoutSemicolon', 'var f = () => {}'#10'(1)', '|')]
    procedure Source_IsAccepted(const Source: string);

    [Test]
    procedure ConciseBody_InForInitializer_IsParsed;
  end;

implementation

procedure TArrowFunctionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrowFunctionTests.TearDown;
begin
  FEngine.Free;
end;

function TArrowFunctionTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TArrowFunctionTests.Call_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TArrowFunctionTests.This_IsInheritedFromEnclosingFunction;
begin
  const Script = 'var o = { v: 3, make: function () { return () => this.v; } }; o.make()()';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.This_IgnoresCallAndApplyAndBind;
begin
  const Script = 'var o = { v: 1, make: function () { return () => this.v; } };' +
                 'var f = o.make(); var other = { v: 2 };' +
                 'f.call(other) + "," + f.apply(other) + "," + f.bind(other)()';

  Assert.AreEqual('1,1,1', FEngine.Evaluate(Script).AsString);
end;

procedure TArrowFunctionTests.This_InNestedArrow_IsInheritedFromOuterFunction;
begin
  const Script = 'var o = { v: 4, make: function () { return () => () => this.v; } }; o.make()()()';

  Assert.AreEqual(4.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.This_AtGlobalLevel_IsGlobalObject;
begin
  const Script = 'var g = this; var f = () => this; f() === g';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TArrowFunctionTests.This_InStrictFunctionWithoutReceiver_IsUndefined;
begin
  const Script = 'function outer() { "use strict"; return () => typeof this; } outer()()';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TArrowFunctionTests.This_InStrictGlobalCode_IsGlobalObject;
begin
  const Script = '"use strict"; var g = this; var f = () => this; f() === g';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TArrowFunctionTests.Arguments_AreTakenFromEnclosingFunction;
begin
  const Script = 'function outer() { return (() => arguments[0] + arguments.length)(99); } outer(10, 20)';

  Assert.AreEqual(12.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.Arguments_InNestedArrow_AreTakenFromEnclosingFunction;
begin
  const Script = 'function outer() { return (() => () => arguments[1])()(); } outer(1, 2)';

  Assert.AreEqual(2.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.Arguments_AtGlobalLevel_IsReferenceError;
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf('(() => arguments)()'));
end;

procedure TArrowFunctionTests.Prototype_IsNotDefined;
begin
  const Script = 'var f = () => 1; f.hasOwnProperty("prototype") + "," + typeof f.prototype';

  Assert.AreEqual('false,undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TArrowFunctionTests.Length_IsParameterCount;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('((a, b, c) => 1).length').AsNumber);
end;

procedure TArrowFunctionTests.Length_WithTrailingComma_IgnoresComma;
begin
  Assert.AreEqual(2.0, FEngine.Evaluate('((a, b,) => 1).length').AsNumber);
end;

procedure TArrowFunctionTests.TypeOf_IsFunction;
begin
  Assert.AreEqual('function', FEngine.Evaluate('typeof (() => 1)').AsString);
end;

procedure TArrowFunctionTests.Closure_CapturesEnclosingBindings;
begin
  const Script = 'function counter() { var n = 0; return () => ++n; } var c = counter(); c(); c(); c()';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.Parameters_ShadowOuterBindings;
begin
  const Script = 'var x = 1; var f = x => x + 1; f(10) + x';

  Assert.AreEqual(12.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TArrowFunctionTests.New_RaisesTypeError(const Source: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Source));
end;

procedure TArrowFunctionTests.Source_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TArrowFunctionTests.Source_IsAccepted(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TArrowFunctionTests.ConciseBody_InForInitializer_IsParsed;
begin
  const Script = 'var r = 0; for (var f = x => x; r < 1; r++) { } r';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

end.
