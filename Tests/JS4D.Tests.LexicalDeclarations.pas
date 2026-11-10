unit JS4D.Tests.LexicalDeclarations;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TLexicalDeclarationTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure Const_WithoutInitializer_IsSyntaxError(const Source: string);

    [Test]
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
    procedure Declaration_Redeclared_IsSyntaxError(const Source: string);

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
    procedure Declaration_Valid_RaisesNoError(const Source: string);

    [Test]
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
    procedure LexicalDeclaration_AsStatementBody_IsSyntaxError(const Source: string);

    [Test]
    procedure ForLet_CreatesFreshBindingPerIteration;

    [Test]
    procedure ForLet_FreshBindingSurvivesContinue;

    [Test]
    procedure ForLet_BreakAndContinueStillWork;

    [Test]
    procedure ForLet_ClosureInInitializerSeesInitialBinding;

    [Test]
    procedure ForLet_VariableIsNotVisibleAfterLoop;

    [Test]
    procedure ForIn_Let_CreatesFreshBindingPerIteration;

    [Test]
    procedure ForIn_Const_BindsEachKey;

    [Test]
    procedure Switch_Let_IsScopedToSwitchBlock;

    [Test]
    procedure Switch_JumpingPastLet_LeavesItUninitialized;

    [Test]
    procedure BlockFunction_IsHoistedToTopOfBlock;

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
    procedure GlobalLet_IsNotPropertyOfGlobalObject;

    [Test]
    procedure GlobalLet_IsVisibleToLaterScripts;

    [Test]
    procedure GlobalConst_Reassignment_RaisesTypeError;

    [Test]
    procedure GlobalLet_DeclaredTwiceInSeparateScripts_IsSyntaxError;

    [Test]
    procedure GlobalVar_AfterGlobalLet_IsSyntaxError;

    [Test]
    procedure GlobalLet_AfterGlobalVar_IsSyntaxError;

    [Test]
    procedure GlobalLet_ShadowsGlobalObjectProperty;

    [Test]
    procedure Eval_Let_IsNotVisibleOutsideEval;

    [Test]
    procedure Eval_VarIsVisibleAndLetIsNot;

    [Test]
    procedure Eval_SeesEnclosingBlockBindings;

    [Test]
    procedure Eval_VarInsideBlockScopeDeclaresInFunction;

    [Test]
    [TestCase('FunctionLet', 'function f() { let x; eval("var x;"); } f();')]
    [TestCase('NestedBlockLet', 'function f() { { let x; { eval("var x;"); } } } f();')]
    [TestCase('FunctionInBlock', 'function f() { { function x() { } eval("var x;"); } } f();')]
    procedure Eval_VarConflictingWithEnclosingLexicalBinding_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('CatchParameter', 'try { throw 1; } catch (e) { eval("var e;"); }')]
    [TestCase('SiblingBlock', 'function f() { { let x; } eval("var x;"); } f();')]
    procedure Eval_VarNotConflictingWithEnclosingLexicalBinding_RaisesNoError(const Source: string);

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

procedure TLexicalDeclarationTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TLexicalDeclarationTests.TearDown;
begin
  FEngine.Free;
end;

function TLexicalDeclarationTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [QuotesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TLexicalDeclarationTests.Let_InBlock_IsNotVisibleOutsideBlock;
begin
  const Script = 'var r = "outer"; { let r = "inner"; } r';

  Assert.AreEqual('outer', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Let_InBlock_ShadowsOuterBinding;
begin
  const Script = 'var r = 1; var inner; { let r = 2; inner = r; } inner * 10 + r';

  Assert.AreEqual(21.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.Let_WithoutInitializer_IsUndefined;
begin
  const Script = 'var t; { let u; t = typeof u; } t';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Let_MultipleDeclarators_AreAllBound;
begin
  const Script = 'var r; { let a = 1, b = a + 1, c; r = a + b + (c === undefined ? 10 : 0); } r';

  Assert.AreEqual(13.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.Let_InFunctionBody_IsVisibleToClosures;
begin
  const Script =
    'function make() { let count = 0; const step = 2; return function () { count += step; return count; }; }' + sLineBreak +
    'var next = make(); next(); next()';

  Assert.AreEqual(4.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.TemporalDeadZone_Access_RaisesReferenceError(const Source: string);
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Const_Read_ReturnsValue;
begin
  Assert.AreEqual(5.0, FEngine.Evaluate('const c = 5; { const d = c + 1; } c').AsNumber);
end;

procedure TLexicalDeclarationTests.Const_Reassignment_RaisesTypeError(const Source: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Const_WithoutInitializer_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Declaration_Redeclared_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Declaration_Valid_RaisesNoError(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.LexicalDeclaration_AsStatementBody_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.ForLet_CreatesFreshBindingPerIteration;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let i = 0; i < 3; i++) { fs.push(function () { return i; }); }' + sLineBreak +
    'fs[0]() + fs[1]() * 10 + fs[2]() * 100';

  Assert.AreEqual(210.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.ForLet_FreshBindingSurvivesContinue;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let i = 0; i < 3; i++) { if (i == 1) continue; fs.push(function () { return i; }); }' + sLineBreak +
    'fs[0]() * 10 + fs[1]()';

  Assert.AreEqual(2.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.ForLet_BreakAndContinueStillWork;
begin
  const Script =
    'var sum = 0;' + sLineBreak +
    'for (let i = 0; i < 5; i++) { if (i == 1) continue; if (i == 3) break; sum += i; }' + sLineBreak +
    'sum';

  Assert.AreEqual(2.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.ForLet_ClosureInInitializerSeesInitialBinding;
begin
  const Script =
    'var probe;' + sLineBreak +
    'for (let i = 0, f = function () { return i; }; i < 2; i++) { probe = f; }' + sLineBreak +
    'probe()';

  Assert.AreEqual(0.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.ForLet_VariableIsNotVisibleAfterLoop;
begin
  const Script = 'for (let i = 0; i < 2; i++) { } typeof i';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.ForIn_Let_CreatesFreshBindingPerIteration;
begin
  const Script =
    'var fs = [];' + sLineBreak +
    'for (let k in { a: 1, b: 2 }) { fs.push(function () { return k; }); }' + sLineBreak +
    'fs[0]() + fs[1]()';

  Assert.AreEqual('ab', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.ForIn_Const_BindsEachKey;
begin
  const Script =
    'var keys = "";' + sLineBreak +
    'for (const k in { a: 1, b: 2 }) { keys += k; }' + sLineBreak +
    'keys';

  Assert.AreEqual('ab', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Switch_Let_IsScopedToSwitchBlock;
begin
  const Script = 'var r; switch (1) { case 1: let sw = 5; r = sw; break; } r + typeof sw';

  Assert.AreEqual('5undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Switch_JumpingPastLet_LeavesItUninitialized;
begin
  const Script = 'var r; switch (2) { case 1: let a = 1; case 2: a = 4; r = a; }; r';

  Assert.AreEqual('ReferenceError', ErrorNameOf(Script));
end;

procedure TLexicalDeclarationTests.BlockFunction_IsHoistedToTopOfBlock;
begin
  const Script = 'var r; { r = f(); function f() { return 7; } } r';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.BlockFunction_Sloppy_IsAlsoVisibleInFunctionAfterBlock;
begin
  const Script =
    'function outer() { { function inner() { return 3; } } return inner(); }' + sLineBreak +
    'outer()';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.BlockFunction_Sloppy_IsUndefinedBeforeBlock;
begin
  const Script =
    'function outer() { var before = typeof g; { function g() { } } return before + typeof g; }' + sLineBreak +
    'outer()';

  Assert.AreEqual('undefinedfunction', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.BlockFunction_Strict_IsNotVisibleOutsideBlock;
begin
  const Script =
    '"use strict"; function outer() { { function g() { } } return typeof g; }' + sLineBreak +
    'outer()';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.BlockFunction_BlockedByOuterLet_DoesNotReplaceOuterBinding;
begin
  const Script =
    'function outer() { let f = 1; { function f() { } } return f; }' + sLineBreak +
    'outer()';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.BlockFunction_InIfWithoutBraces_IsVisibleAfterwards;
begin
  const Script =
    'function outer() { if (true) function h() { return 9; } return h(); }' + sLineBreak +
    'outer()';

  Assert.AreEqual(9.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.BlockFunction_ReassignedInsideBlock_KeepsOuterCopyFromDeclaration;
begin
  const Script =
    'function outer() { { function f() { return 1; } f = 2; } return typeof f; }' + sLineBreak +
    'outer()';

  Assert.AreEqual('function', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.LabelledFunction_AtFunctionLevel_IsHoisted;
begin
  const Script =
    'function outer() { return typeof f + f(); l: function f() { return 1; } }' + sLineBreak +
    'outer()';

  Assert.AreEqual('function1', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.GlobalLet_IsNotPropertyOfGlobalObject;
begin
  const Script =
    'let gl = 4; const gc = 5;' + sLineBreak +
    'var globalObject = (function () { return this; })();' + sLineBreak +
    'gl + gc + typeof globalObject.gl + typeof globalObject.gc';

  Assert.AreEqual('9undefinedundefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.GlobalLet_IsVisibleToLaterScripts;
begin
  FEngine.Execute('let shared = 1; function bump() { shared++; }');
  FEngine.Execute('bump(); bump();');

  Assert.AreEqual(3.0, FEngine.Evaluate('shared').AsNumber);
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

procedure TLexicalDeclarationTests.GlobalLet_ShadowsGlobalObjectProperty;
begin
  FEngine.Execute('Object.defineProperty((function () { return this; })(), "shadowed", { value: 1, configurable: true });');
  FEngine.Execute('let shadowed = 2;');

  Assert.AreEqual(2.0, FEngine.Evaluate('shadowed').AsNumber);
end;

procedure TLexicalDeclarationTests.Eval_Let_IsNotVisibleOutsideEval;
begin
  const Script = 'eval("let inEval = 1;"); typeof inEval';

  Assert.AreEqual('undefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Eval_VarIsVisibleAndLetIsNot;
begin
  const Script = 'eval("var viaVar = 1; let viaLet = 2;"); typeof viaVar + typeof viaLet';

  Assert.AreEqual('numberundefined', FEngine.Evaluate(Script).AsString);
end;

procedure TLexicalDeclarationTests.Eval_SeesEnclosingBlockBindings;
begin
  const Script =
    'function f() { { let inner = 6; return eval("inner * 2"); } }' + sLineBreak +
    'f()';

  Assert.AreEqual(12.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TLexicalDeclarationTests.Eval_VarConflictingWithEnclosingLexicalBinding_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Eval_VarNotConflictingWithEnclosingLexicalBinding_RaisesNoError(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TLexicalDeclarationTests.Eval_CompletionValue_IgnoresDeclarations(const Source: string; const Expected: string);
begin
  const Escaped = Source.Replace('"', '\"');
  const Actual = FEngine.Evaluate(Format('String(eval("%s"))', [Escaped])).AsString;

  Assert.AreEqual(Expected, Actual);
end;

procedure TLexicalDeclarationTests.Eval_VarInsideBlockScopeDeclaresInFunction;
begin
  const Script =
    'function f() { { let hidden = 1; eval("var leaked = 2;"); } return typeof leaked; }' + sLineBreak +
    'f()';

  Assert.AreEqual('number', FEngine.Evaluate(Script).AsString);
end;

end.
