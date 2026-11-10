unit JS4D.Tests.ForOf;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TForOfTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;
    procedure AssertEvaluatesTo(const Expected: string; const Source: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('ArrayVar', 'var r = ""; for (var x of [1, 2, 3]) r += x; r|123', '|')]
    [TestCase('ArrayLet', 'var r = ""; for (let x of [1, 2, 3]) r += x; r|123', '|')]
    [TestCase('ArrayConst', 'var r = ""; for (const x of [1, 2, 3]) r += x; r|123', '|')]
    [TestCase('ArrayExpressionTarget', 'var x, r = ""; for (x of [1, 2]) r += x; r + x|122', '|')]
    [TestCase('VarIsFunctionScoped', 'for (var x of [1, 2]) {} x|2', '|')]
    [TestCase('EmptyArray', 'var n = 0; for (var x of []) n++; n|0', '|')]
    [TestCase('Holes', 'var r = ""; for (var x of [1, , 3]) r += typeof x + ";"; r|number;undefined;number;', '|')]
    [TestCase('HoleReadsPrototype', 'Array.prototype[1] = "p"; var r = ""; for (var x of [1, , 3]) r += x; delete Array.prototype[1]; r|1p3', '|')]
    [TestCase('String', 'var r = ""; for (var c of "abc") r += c + "-"; r|a-b-c-', '|')]
    [TestCase('StringByCodePoint', 'var n = 0; for (var c of "a'#$D83D#$DE00'b") n++; n|3', '|')]
    [TestCase('StringSurrogatePairLength', 'var l; for (var c of "'#$D83D#$DE00'") l = c.length; l|2', '|')]
    [TestCase('LoneSurrogate', 'var n = 0; for (var c of "\uD83Dx") n++; n|2', '|')]
    [TestCase('StringObject', 'var r = ""; for (var c of new String("ab")) r += c; r|ab', '|')]
    [TestCase('Arguments', 'function f() { var r = ""; for (var x of arguments) r += x; return r; } f(1, 2, 3)|123', '|')]
    [TestCase('ArrayGrowsDuringLoop', 'var a = [1]; var n = 0; for (var x of a) { if (n++ < 3) a.push(x + 1); } a.length|4', '|')]
    [TestCase('ArrayShrinksDuringLoop', 'var a = [1, 2, 3]; var n = 0; for (var x of a) { n++; a.length = 1; } n|1', '|')]
    [TestCase('RightIsAssignmentExpression', 'var r = ""; for (var x of true ? [1, 2] : []) r += x; r|12', '|')]
    [TestCase('InOperatorInRight', 'var n = 0; for (var x of "a" in {} ? [1] : [1, 2]) n++; n|2', '|')]
    [TestCase('NameOfIsStillAnIdentifier', 'var of = 1; of + 1|2', '|')]
    [TestCase('NameOfAsLoopVariable', 'var r; for (var of of [3]) r = of; r|3', '|')]
    [TestCase('NameOfInForLoop', 'var n = 0; for (var of = 0; of < 3; of++) n += of; n|3', '|')]
    [TestCase('NameOfAsExpressionTarget', 'var of, r; for (of of [4]) r = of; r|4', '|')]
    procedure Iterates_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Break', 'var r = ""; for (var x of [1, 2, 3]) { if (x == 2) break; r += x; } r|1', '|')]
    [TestCase('Continue', 'var r = ""; for (var x of [1, 2, 3]) { if (x == 2) continue; r += x; } r|13', '|')]
    [TestCase('BreakLabel', 'var r = ""; a: for (var x of [1, 2]) { for (var y of [1, 2]) { if (y == 2) break a; r += x + "" + y; } } r|11', '|')]
    [TestCase('ContinueLabel', 'var r = ""; a: for (var x of [1, 2]) { for (var y of [1, 2]) { if (y == 2) continue a; r += x + "" + y; } } r|1121', '|')]
    [TestCase('ContinueLabelWithLetHead', 'var r = ""; a: for (let x of [1, 2]) { for (let y of [1, 2]) { if (y == 2) continue a; r += x + "" + y; } } r|1121', '|')]
    [TestCase('BreakFromLabeledBlock', 'var r = ""; a: { for (var x of [1, 2]) { r += x; break a; } r += "no"; } r|1', '|')]
    [TestCase('Return', 'function f() { for (var x of [1, 2, 3]) { if (x == 2) return x; } return 0; } f()|2', '|')]
    [TestCase('ReturnFromLetHead', 'function f() { for (let x of [1, 2, 3]) { if (x == 2) return x; } return 0; } f()|2', '|')]
    [TestCase('BreakInTry', 'var r = ""; for (var x of [1, 2]) { try { break; } finally { r += "f"; } } r|f', '|')]
    [TestCase('ContinueInTry', 'var r = ""; for (var x of [1, 2]) { try { continue; } finally { r += "f"; } } r|ff', '|')]
    [TestCase('NestedLoops', 'var r = ""; for (var x of [1, 2]) for (var y of "ab") r += x + y; r|1a1b2a2b', '|')]
    [TestCase('ThrowInBody', 'var r = ""; try { for (var x of [1, 2]) { r += x; throw 1; } } catch (e) { r += "c"; } r|1c', '|')]
    [TestCase('ScopeRestoredAfterBreak', 'let x = "outer"; for (let x of [1]) { break; } x|outer', '|')]
    [TestCase('ScopeRestoredAfterLoop', 'let x = "outer"; for (let x of [1, 2]) {} x|outer', '|')]
    [TestCase('ScopeRestoredAfterThrow', 'let x = "outer"; try { for (let x of [1]) { throw 1; } } catch (e) {} x|outer', '|')]
    procedure ControlFlow_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('LetClosures', 'var f = []; for (let x of [1, 2, 3]) f.push(() => x); f[0]() + "," + f[1]() + "," + f[2]()|1,2,3', '|')]
    [TestCase('ConstClosures', 'var f = []; for (const x of [1, 2]) f.push(() => x); f[0]() + "," + f[1]()|1,2', '|')]
    [TestCase('VarClosuresShareBinding', 'var f = []; for (var x of [1, 2]) f.push(() => x); f[0]() + "," + f[1]()|2,2', '|')]
    [TestCase('ClosureSeesBodyChange', 'var f = []; for (let x of [1, 2]) { f.push(() => x); x = x * 10; } f[0]() + "," + f[1]()|10,20', '|')]
    [TestCase('LetIsAssignableInBody', 'var r = ""; for (let x of [1, 2]) { x += 1; r += x; } r|23', '|')]
    [TestCase('LetShadowsOuter', 'let x = "o"; var r = ""; for (let x of [1]) r += x; r + x|1o', '|')]
    [TestCase('RightIsEvaluatedOnce', 'var n = 0; for (let x of (n++, [1, 2])) {} n|1', '|')]
    procedure PerIterationBindings_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('LetArray', 'var r = ""; for (let [a, b] of [[1, 2], [3, 4]]) r += a + b + ";"; r|3;7;', '|')]
    [TestCase('ConstObject', 'var r = ""; for (const {a, b} of [{a: 1, b: 2}]) r += a + b; r|3', '|')]
    [TestCase('VarArray', 'var r = ""; for (var [a, b] of [[1, 2]]) r += a + b; r + a|31', '|')]
    [TestCase('VarObject', 'for (var {a} of [{a: 5}]); a|5', '|')]
    [TestCase('Defaults', 'var r = ""; for (let [a, b = 7] of [[1]]) r += a + b; r|8', '|')]
    [TestCase('Rest', 'var r; for (let [a, ...b] of [[1, 2, 3]]) r = b.join(); r|2,3', '|')]
    [TestCase('Nested', 'var r; for (let {a: [b]} of [{a: [6]}]) r = b; r|6', '|')]
    [TestCase('StringElements', 'var r = ""; for (let [a, b] of ["xy", "zw"]) r += b + a; r|yxwz', '|')]
    [TestCase('AssignmentArrayPattern', 'var a, b, r = ""; for ([a, b] of [[1, 2], [3, 4]]) r += a + b; r|37', '|')]
    [TestCase('AssignmentObjectPattern', 'var a, r = ""; for ({a} of [{a: 1}, {a: 2}]) r += a; r|12', '|')]
    [TestCase('AssignmentToMember', 'var o = {}; for (o.p of [1, 2]); o.p|2', '|')]
    [TestCase('AssignmentToIndexedMember', 'var o = []; for (o[1] of [7]); o[1]|7', '|')]
    [TestCase('PatternClosures', 'var f = []; for (let [a] of [[1], [2]]) f.push(() => a); f[0]() + "," + f[1]()|1,2', '|')]
    procedure Destructuring_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Object', 'for (var x of {}) {}', '|')]
    [TestCase('Number', 'for (var x of 1) {}', '|')]
    [TestCase('Boolean', 'for (var x of true) {}', '|')]
    [TestCase('Null', 'for (var x of null) {}', '|')]
    [TestCase('Undefined', 'for (var x of undefined) {}', '|')]
    [TestCase('Function', 'for (var x of function() {}) {}', '|')]
    [TestCase('ArrayLikeObject', 'for (var x of {length: 1, 0: "a"}) {}', '|')]
    [TestCase('ConstAssignment', 'for (const x of [1]) { x = 2; }', '|')]
    [TestCase('PatternOfNull', 'for (var [a] of [null]) {}', '|')]
    [TestCase('PatternOfUndefinedObject', 'for (let {a} of [undefined]) {}', '|')]
    procedure Runtime_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('TemporalDeadZone', 'for (let x of [x]) {}', '|')]
    [TestCase('TemporalDeadZoneInPatternRight', 'for (let [x] of [[x]]) {}', '|')]
    [TestCase('StrictUndeclaredTarget', '"use strict"; for (undeclaredTarget of [1]) {}', '|')]
    procedure Runtime_RaisesReferenceError(const Source: string);

    [Test]
    [TestCase('Initializer', 'for (var x = 1 of []) {}', '|')]
    [TestCase('LetInitializer', 'for (let x = 1 of []) {}', '|')]
    [TestCase('PatternInitializer', 'for (var [x] = [] of []) {}', '|')]
    [TestCase('TwoDeclarators', 'for (var x, y of []) {}', '|')]
    [TestCase('TwoLexicalDeclarators', 'for (let x, y of []) {}', '|')]
    [TestCase('CommaInRight', 'for (var x of [], []) {}', '|')]
    [TestCase('InvalidTarget', 'for (1 of []) {}', '|')]
    [TestCase('ParenthesizedPattern', 'for (([a]) of []) {}', '|')]
    [TestCase('LetNamedLet', 'for (let let of []) {}', '|')]
    [TestCase('ConstWithoutBinding', 'for (const of []) {}', '|')]
    [TestCase('BodyVarClashesWithLet', 'for (let x of []) { var x; }', '|')]
    [TestCase('DuplicateLexicalNames', 'for (let [x, x] of []) {}', '|')]
    [TestCase('FunctionDeclarationBody', 'for (var x of []) function f() {}', '|')]
    [TestCase('LexicalDeclarationBody', 'for (var x of []) let y = 1;', '|')]
    [TestCase('MissingParenthesis', 'for (var x of [] {}', '|')]
    [TestCase('EscapedOf', 'for (var x '#$5C'u006ff []) {}', '|')]
    [TestCase('StrictEvalTarget', '"use strict"; for (eval of []) {}', '|')]
    [TestCase('StrictArgumentsBinding', '"use strict"; for (var arguments of []) {}', '|')]
    [TestCase('BreakOutsideLoop', 'for (var x of []) {} break;', '|')]
    [TestCase('AsyncOf', 'for (async of [1]) {}', '|')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [Test]
    [TestCase('AsyncAsVarLoopVariable', 'for (var async of []) {}', '|')]
    [TestCase('AsyncMemberTarget', 'var async = {}; for (async.x of []) {}', '|')]
    [TestCase('AsyncAsForInTarget', 'var async; for (async in {}) {}', '|')]
    procedure Source_IsAccepted(const Source: string);

    procedure ForIn_AfterForOfSupport_StillWorks;

    [Test]
    [TestCase('Arguments', '(function() { return [...arguments].join(); })(1, 2)|1,2', '|')]
    [TestCase('StringObject', '[...new String("ab")].join()|a,b', '|')]
    [TestCase('ArgumentsPattern', '(function() { var [a, b] = arguments; return a + b; })(1, 2)|3', '|')]
    procedure ArrayLikes_InSpreadAndPatterns_Result(const Source: string; const Expected: string);
  end;

implementation

procedure TForOfTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TForOfTests.TearDown;
begin
  FEngine.Free;
end;

function TForOfTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TForOfTests.AssertEvaluatesTo(const Expected: string; const Source: string);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).ToString);
end;

procedure TForOfTests.Iterates_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TForOfTests.ControlFlow_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TForOfTests.PerIterationBindings_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TForOfTests.Destructuring_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

procedure TForOfTests.Runtime_RaisesTypeError(const Source: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Source));
end;

procedure TForOfTests.Runtime_RaisesReferenceError(const Source: string);
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf(Source));
end;

procedure TForOfTests.Source_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TForOfTests.Source_IsAccepted(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TForOfTests.ForIn_AfterForOfSupport_StillWorks;
begin
  const Script = 'var r = ""; for (var k in {a: 1, b: 2}) r += k; for (let k in {c: 1}) r += k; r';

  AssertEvaluatesTo('abc', Script);
end;

procedure TForOfTests.ArrayLikes_InSpreadAndPatterns_Result(const Source: string; const Expected: string);
begin
  AssertEvaluatesTo(Expected, Source);
end;

end.
