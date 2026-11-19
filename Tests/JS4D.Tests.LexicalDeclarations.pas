unit JS4D.Tests.LexicalDeclarations;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Tests.Support;

type
  [TestFixture]
  TLexicalDeclarationTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Let_InBlock_IsNotVisibleOutsideBlock;

    [Test]
    procedure Let_InBlock_ShadowsOuterBinding;

    [Test]
    procedure Let_WithoutInitializer_IsUndefined;

    [Test]
    procedure Let_MultipleDeclarators_AreAllBound;

    [Test]
    procedure Let_InFunctionBody_IsVisibleToClosures;

    [Test]
    [TestCase('ReadBeforeDeclaration', '{ x; let x = 1; }')]
    [TestCase('WriteBeforeDeclaration', '{ x = 1; let x; }')]
    [TestCase('TypeofBeforeDeclaration', '{ typeof x; let x; }')]
    [TestCase('SelfReferenceInInitializer', '{ let x = x; }')]
    [TestCase('GlobalSelfReference', 'let y = y;')]
    [TestCase('ConstSelfReference', '{ const x = x; }')]
    [TestCase('ClosureCalledTooEarly', '{ function f() { return x; } f(); let x = 1; }')]
    [TestCase('SwitchCaseBeforeDeclaration', 'switch (1) { case 0: let a; break; case 1: a = 1; }')]
    [TestCase('ForInHead', 'for (let k in k) ;')]
    procedure TemporalDeadZone_Access_RaisesReferenceError(const Source: string);

    [Test]
    procedure Const_Read_ReturnsValue;

    [Test]
    [TestCase('Assignment', 'const c = 1; c = 2;')]
    [TestCase('CompoundAssignment', 'const c = 1; c += 1;')]
    [TestCase('Increment', 'const c = 1; c++;')]
    [TestCase('PrefixDecrement', 'const c = 1; --c;')]
    [TestCase('FromNestedBlock', 'const c = 1; { c = 2; }')]
    [TestCase('FromClosure', 'const c = 1; (function () { c = 2; })();')]
    [TestCase('ForInVariable', 'for (const k in { a: 1 }) { k = 2; }')]
    [TestCase('ForLoopVariable', 'for (const i = 0; i < 1; i++) { }')]
    procedure Const_Reassignment_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('MissingInitializer', 'const c;')]
    [TestCase('MissingInitializerInBlock', '{ const c; }')]
    [TestCase('MissingInitializerInFor', 'for (const c; false;) { }')]
    [TestCase('SecondDeclaratorWithoutInitializer', 'const a = 1; const b = 2; const c = 3, d;', '|')]
    [TestCase('LetLet', 'let a; let a;')]
    [TestCase('LetVar', 'let a; var a;')]
    [TestCase('VarLet', 'var a; let a;')]
    [TestCase('LetVarInNestedBlock', 'let a; { var a; }')]
    [TestCase('VarInNestedBlockLet', '{ { var a; } let a; }')]
    [TestCase('ConstFunction', 'const a = 1; function a() { }')]
    [TestCase('LetParameter', 'function f(a) { let a; }')]
    [TestCase('LetCatchParameter', 'try { } catch (e) { let e; }')]
    [TestCase('BlockFunctionLet', '{ function f() { } let f; }')]
    [TestCase('BlockLetFunction', '{ let f; function f() { } }')]
    [TestCase('BlockVarFunction', '{ var f; function f() { } }')]
    [TestCase('ForLetBodyVar', 'for (let i = 0; false;) { var i; }')]
    [TestCase('ForLetTwice', 'for (let i, i; false;) { }', '|')]
    [TestCase('SwitchLetLet', 'switch (0) { case 0: let a; case 1: let a; }')]
    [TestCase('LetNamedLet', 'let let = 1;')]
    [TestCase('ConstNamedLet', 'const let = 1;')]
    [TestCase('StrictBlockFunctionTwice', '"use strict"; { function f() { } function f() { } }')]
    [TestCase('If', 'if (true) let x = 1;')]
    [TestCase('IfConst', 'if (true) const x = 1;')]
    [TestCase('While', 'while (false) let y;')]
    [TestCase('For', 'for (;;) const z = 1;')]
    [TestCase('LetBracket', 'if (true) let [x] = 1;')]
    [TestCase('Label', 'l: let x;')]
    [TestCase('With', 'with ({}) let x;')]
    [TestCase('LabelledFunctionInStrictMode', '"use strict"; l: function f() { }')]
    [TestCase('LabelledFunctionInLoop', 'while (false) l: function f() { }')]
    [TestCase('LabelledFunctionInIf', 'if (true) l: function f() { }')]
    [TestCase('FunctionLet', 'function f() { let x; eval("var x;"); } f();')]
    [TestCase('NestedBlockLet', 'function f() { { let x; { eval("var x;"); } } } f();')]
    [TestCase('FunctionInBlock', 'function f() { { function x() { } eval("var x;"); } } f();')]
    procedure Declaration_InvalidSource_RaisesSyntaxError(const Source: string);

    [Test]
    [TestCase('ShadowInBlock', 'let a; { let a; }')]
    [TestCase('ShadowParameter', 'function f(a) { { let a; } }')]
    [TestCase('VarInCatch', 'try { } catch (e) { var e; }')]
    [TestCase('FunctionTwiceInBlock', '{ function f() { } function f() { } }')]
    [TestCase('ForLetBodyLet', 'for (let i = 0; false;) { let i; }')]
    [TestCase('SiblingBlocks', '{ let a; } { let a; }')]
    [TestCase('TopLevelFunctionAndVar', 'function f() { } var f;')]
    [TestCase('PropertyNamedConst', 'var o = { const: 1 }; o.const;')]
    [TestCase('LetAsIdentifier', 'var let = 1; let = 2; let;')]
    [TestCase('LabelledFunction', 'l: function f() { }')]
    [TestCase('LabelledFunctionInBlock', '{ l: function f() { } }')]
    [TestCase('NestedLabelledFunction', 'a: b: function f() { }')]
    [TestCase('CatchParameter', 'try { throw 1; } catch (e) { eval("var e;"); }')]
    [TestCase('SiblingBlock', 'function f() { { let x; } eval("var x;"); } f();')]
    procedure Declaration_ValidSource_RaisesNoError(const Source: string);

    [Test]
    procedure ForLet_ClosuresInLoop_SeeFreshBindingPerIteration;

    [Test]
    procedure ForLet_Continue_KeepsFreshBindingPerIteration;

    [Test]
    procedure ForLet_BreakAndContinue_LeaveLoopCorrectly;

    [Test]
    procedure ForLet_ClosureInInitializerSeesInitialBinding;

    [Test]
    procedure ForLet_AfterLoop_VariableIsNotVisible;

    [Test]
    procedure ForIn_Let_CreatesFreshBindingPerIteration;

    [Test]
    procedure ForIn_Const_BindsEachKey;

    [Test]
    procedure Switch_Let_IsScopedToSwitchBlock;

    [Test]
    procedure Switch_JumpingPastLet_LeavesItUninitialized;

    [Test]
    procedure BlockFunction_CalledBeforeDeclaration_IsHoistedToTopOfBlock;

    [Test]
    procedure BlockFunction_Sloppy_IsAlsoVisibleInFunctionAfterBlock;

    [Test]
    procedure BlockFunction_Sloppy_IsUndefinedBeforeBlock;

    [Test]
    procedure BlockFunction_Strict_IsNotVisibleOutsideBlock;

    [Test]
    procedure BlockFunction_BlockedByOuterLet_DoesNotReplaceOuterBinding;

    [Test]
    procedure BlockFunction_InIfWithoutBraces_IsVisibleAfterwards;

    [Test]
    procedure BlockFunction_ReassignedInsideBlock_KeepsOuterCopyFromDeclaration;

    [Test]
    procedure LabelledFunction_AtFunctionLevel_IsHoisted;

    [Test]
    procedure GlobalLet_ReadViaGlobalObject_IsNotAProperty;

    [Test]
    procedure GlobalLet_SecondScript_IsVisibleToLaterScripts;

    [Test]
    procedure GlobalConst_Reassignment_RaisesTypeError;

    [Test]
    procedure GlobalLet_DeclaredTwiceInSeparateScripts_IsSyntaxError;

    [Test]
    procedure GlobalVar_AfterGlobalLet_IsSyntaxError;

    [Test]
    procedure GlobalLet_AfterGlobalVar_IsSyntaxError;

    [Test]
    procedure GlobalLet_SameNameAsGlobalProperty_ShadowsIt;

    [Test]
    procedure Eval_Let_IsNotVisibleOutsideEval;

    [Test]
    procedure Eval_VarAndLet_VarIsVisibleAndLetIsNot;

    [Test]
    procedure Eval_InsideBlock_SeesEnclosingBlockBindings;

    [Test]
    procedure Eval_VarInsideBlock_DeclaresInFunction;

    [Test]
    [TestCase('LetOnly', 'let a = 1;|undefined', '|')]
    [TestCase('ValueThenLet', '7; let a = 1;|7', '|')]
    [TestCase('ValueThenConst', '8; const a = 1;|8', '|')]
    [TestCase('ValueThenVar', '9; var a = 1;|9', '|')]
    [TestCase('ValueThenFunction', '10; function a() { }|10', '|')]
    [TestCase('ValueThenEmptyStatement', '11;;|11', '|')]
    procedure Eval_CompletionValue_IgnoresDeclarations(const Source: string; const Expected: string);
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

const
  CALL_OUTER = 'outer()';
  UNDEFINED_TYPE_NAME = 'undefined';

procedure TLexicalDeclarationTests.Let_InBlock_IsNotVisibleOutsideBlock;
begin
  const Script = 'var r = "outer"; { let r = "inner"; } r';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('outer', Actual);
end;

procedure TLexicalDeclarationTests.Let_InBlock_ShadowsOuterBinding;
begin
  const Script = 'var r = 1; var inner; { let r = 2; inner = r; } inner * 10 + r';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(21.0, Actual);
end;

procedure TLexicalDeclarationTests.Let_WithoutInitializer_IsUndefined;
begin
  const Script = 'var t; { let u; t = typeof u; } t';

  const Actual = EvaluateText(Script);

  Assert.AreEqual(UNDEFINED_TYPE_NAME, Actual);
end;

procedure TLexicalDeclarationTests.Let_MultipleDeclarators_AreAllBound;
begin
  const Script = 'var r; { let a = 1, b = a + 1, c; r = a + b + (c === undefined ? 10 : 0); } r';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(13.0, Actual);
end;

procedure TLexicalDeclarationTests.Let_InFunctionBody_IsVisibleToClosures;
begin
  const Script =
    'function make() { let count = 0; const step = 2; return function () { count += step; return count; }; }' + sLineBreak +
    'var next = make(); next(); next()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(4.0, Actual);
end;

procedure TLexicalDeclarationTests.TemporalDeadZone_Access_RaisesReferenceError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(REFERENCE_ERROR_NAME, Actual);
end;

procedure TLexicalDeclarationTests.Const_Read_ReturnsValue;
begin
  const Actual = EvaluateNumber('const c = 5; { const d = c + 1; } c');

  Assert.AreEqual(5.0, Actual);
end;

procedure TLexicalDeclarationTests.Const_Reassignment_RaisesTypeError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

procedure TLexicalDeclarationTests.Declaration_InvalidSource_RaisesSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TLexicalDeclarationTests.Declaration_ValidSource_RaisesNoError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual('', Actual);
end;

procedure TLexicalDeclarationTests.ForLet_ClosuresInLoop_SeeFreshBindingPerIteration;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let i = 0; i < 3; i++) { fs.push(function () { return i; }); }' + sLineBreak +
    'fs[0]() + fs[1]() * 10 + fs[2]() * 100';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(210.0, Actual);
end;

procedure TLexicalDeclarationTests.ForLet_Continue_KeepsFreshBindingPerIteration;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let i = 0; i < 3; i++) { if (i == 1) continue; fs.push(function () { return i; }); }' + sLineBreak +
    'fs[0]() * 10 + fs[1]()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TLexicalDeclarationTests.ForLet_BreakAndContinue_LeaveLoopCorrectly;
begin
  const Script =
    'var sum = 0;' + sLineBreak +
    'for (let i = 0; i < 5; i++) { if (i == 1) continue; if (i == 3) break; sum += i; }' + sLineBreak +
    'sum';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TLexicalDeclarationTests.ForLet_ClosureInInitializerSeesInitialBinding;
begin
  const Script =
    'var probe;' + sLineBreak +
    'for (let i = 0, f = function () { return i; }; i < 2; i++) { probe = f; }' + sLineBreak +
    'probe()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(0.0, Actual);
end;

procedure TLexicalDeclarationTests.ForLet_AfterLoop_VariableIsNotVisible;
begin
  const Script = 'for (let i = 0; i < 2; i++) { } typeof i';

  const Actual = EvaluateText(Script);

  Assert.AreEqual(UNDEFINED_TYPE_NAME, Actual);
end;

procedure TLexicalDeclarationTests.ForIn_Let_CreatesFreshBindingPerIteration;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let k in { a: 1, b: 2 }) { fs.push(function () { return k; }); }' + sLineBreak +
    'fs[0]() + fs[1]()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('ab', Actual);
end;

procedure TLexicalDeclarationTests.ForIn_Const_BindsEachKey;
begin
  const Script =
    'var keys = "";' + sLineBreak +
    'for (const k in { a: 1, b: 2 }) { keys += k; }' + sLineBreak +
    'keys';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('ab', Actual);
end;

procedure TLexicalDeclarationTests.Switch_Let_IsScopedToSwitchBlock;
begin
  const Script = 'var r; switch (1) { case 1: let sw = 5; r = sw; break; } r + typeof sw';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('5undefined', Actual);
end;

procedure TLexicalDeclarationTests.Switch_JumpingPastLet_LeavesItUninitialized;
begin
  const Script = 'var r; switch (2) { case 1: let a = 1; case 2: a = 4; r = a; }; r';

  const Actual = ErrorNameOf(Script);

  Assert.AreEqual(REFERENCE_ERROR_NAME, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_CalledBeforeDeclaration_IsHoistedToTopOfBlock;
begin
  const Script = 'var r; { r = f(); function f() { return 7; } } r';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(7.0, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_Sloppy_IsAlsoVisibleInFunctionAfterBlock;
begin
  const Script =
    'function outer() { { function inner() { return 3; } } return inner(); }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(3.0, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_Sloppy_IsUndefinedBeforeBlock;
begin
  const Script =
    'function outer() { var before = typeof g; { function g() { } } return before + typeof g; }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateText(Script);

  Assert.AreEqual('undefinedfunction', Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_Strict_IsNotVisibleOutsideBlock;
begin
  const Script =
    '"use strict"; function outer() { { function g() { } } return typeof g; }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateText(Script);

  Assert.AreEqual(UNDEFINED_TYPE_NAME, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_BlockedByOuterLet_DoesNotReplaceOuterBinding;
begin
  const Script =
    'function outer() { let f = 1; { function f() { } } return f; }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_InIfWithoutBraces_IsVisibleAfterwards;
begin
  const Script =
    'function outer() { if (true) function h() { return 9; } return h(); }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(9.0, Actual);
end;

procedure TLexicalDeclarationTests.BlockFunction_ReassignedInsideBlock_KeepsOuterCopyFromDeclaration;
begin
  const Script =
    'function outer() { { function f() { return 1; } f = 2; } return typeof f; }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateText(Script);

  Assert.AreEqual('function', Actual);
end;

procedure TLexicalDeclarationTests.LabelledFunction_AtFunctionLevel_IsHoisted;
begin
  const Script =
    'function outer() { return typeof f + f(); l: function f() { return 1; } }' + sLineBreak +
    CALL_OUTER;

  const Actual = EvaluateText(Script);

  Assert.AreEqual('function1', Actual);
end;

procedure TLexicalDeclarationTests.GlobalLet_ReadViaGlobalObject_IsNotAProperty;
begin
  const Script =
    'let gl = 4; const gc = 5;' + sLineBreak +
    'var globalObject = (function () { return this; })();' + sLineBreak +
    'gl + gc + typeof globalObject.gl + typeof globalObject.gc';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('9undefinedundefined', Actual);
end;

procedure TLexicalDeclarationTests.GlobalLet_SecondScript_IsVisibleToLaterScripts;
begin
  FEngine.Execute('let shared = 1; function bump() { shared++; }');
  FEngine.Execute('bump(); bump();');

  const Actual = EvaluateNumber('shared');

  Assert.AreEqual(3.0, Actual);
end;

procedure TLexicalDeclarationTests.GlobalConst_Reassignment_RaisesTypeError;
begin
  FEngine.Execute('const fixed = 1;');

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('fixed = 2;');
    end,
    EJSTypeError);
end;

procedure TLexicalDeclarationTests.GlobalLet_DeclaredTwiceInSeparateScripts_IsSyntaxError;
begin
  FEngine.Execute('let twice = 1;');

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('let twice = 2;');
    end,
    EJSSyntaxError);
end;

procedure TLexicalDeclarationTests.GlobalVar_AfterGlobalLet_IsSyntaxError;
begin
  FEngine.Execute('let clash = 1;');

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var clash;');
    end,
    EJSSyntaxError);
end;

procedure TLexicalDeclarationTests.GlobalLet_AfterGlobalVar_IsSyntaxError;
begin
  FEngine.Execute('var clash = 1;');

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('let clash;');
    end,
    EJSSyntaxError);
end;

procedure TLexicalDeclarationTests.GlobalLet_SameNameAsGlobalProperty_ShadowsIt;
begin
  FEngine.Execute('Object.defineProperty((function () { return this; })(), "shadowed", { value: 1, configurable: true });');
  FEngine.Execute('let shadowed = 2;');

  const Actual = EvaluateNumber('shadowed');

  Assert.AreEqual(2.0, Actual);
end;

procedure TLexicalDeclarationTests.Eval_Let_IsNotVisibleOutsideEval;
begin
  const Script = 'eval("let inEval = 1;"); typeof inEval';

  const Actual = EvaluateText(Script);

  Assert.AreEqual(UNDEFINED_TYPE_NAME, Actual);
end;

procedure TLexicalDeclarationTests.Eval_VarAndLet_VarIsVisibleAndLetIsNot;
begin
  const Script = 'eval("var viaVar = 1; let viaLet = 2;"); typeof viaVar + typeof viaLet';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('numberundefined', Actual);
end;

procedure TLexicalDeclarationTests.Eval_InsideBlock_SeesEnclosingBlockBindings;
begin
  const Script =
    'function f() { { let inner = 6; return eval("inner * 2"); } }' + sLineBreak +
    'f()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(12.0, Actual);
end;

procedure TLexicalDeclarationTests.Eval_CompletionValue_IgnoresDeclarations(const Source: string; const Expected: string);
begin
  const Escaped = Source.Replace('"', '\"');
  const Actual = EvaluateText(Format('String(eval("%s"))', [Escaped]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TLexicalDeclarationTests.Eval_VarInsideBlock_DeclaresInFunction;
begin
  const Script =
    'function f() { { let hidden = 1; eval("var leaked = 2;"); } return typeof leaked; }' + sLineBreak +
    'f()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('number', Actual);
end;

end.
