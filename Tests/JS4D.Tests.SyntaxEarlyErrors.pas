unit JS4D.Tests.SyntaxEarlyErrors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TSyntaxEarlyErrorTests = class
  private
    FEngine: TJSEngine;

    function EvaluatesToSyntaxError(const Source: string): Boolean;
    function SourceWithLineBreaks(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('ReturnAlone', 'return;')]
    [TestCase('ReturnWithValue', 'var x = 1; return 2;')]
    [TestCase('ReturnInBlock', '{ return; }')]
    procedure Return_OutsideFunction_IsSyntaxError(const Source: string);

    [Test]
    procedure Return_InsideFunctionAndAccessor_IsAllowed;

    [Test]
    [TestCase('Enum', 'var enum = 1;')]
    [TestCase('Extends', 'var extends;')]
    [TestCase('Export', 'var export;')]
    [TestCase('Import', 'var import;')]
    [TestCase('ExpressionReference', 'enum;')]
    [TestCase('FunctionName', 'function export() {}')]
    [TestCase('Parameter', 'function f(import) {}')]
    [TestCase('CatchParameter', 'try {} catch (enum) {}')]
    [TestCase('ForInVariable', 'for (var extends in {}) ;')]
    procedure Identifier_UnusedReservedWord_IsSyntaxError(const Source: string);

    [Test]
    procedure PropertyName_UnusedReservedWord_IsAllowed;

    [Test]
    [TestCase('TwoNumbers', '1 2')]
    [TestCase('TwoStrings', 'var s = "" "";')]
    [TestCase('BlockThenNumber', '{ 1 2 } 3')]
    [TestCase('ElseOnSameLine', 'if (false) x = 1 else x = -1')]
    [TestCase('VarFollowedByVar', 'var a = 1 var b = 2')]
    [TestCase('ReturnFollowedByToken', 'function f() { return 1 2 }')]
    [TestCase('BreakFollowedByToken', 'while (true) { break 1 }')]
    procedure Statement_WithoutTerminator_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('NewlineSeparatesVar', 'var a = 1<LF>var b = 2')]
    [TestCase('NewlineBeforeExpression', 'var x = 1<LF>x')]
    [TestCase('BlockCommentWithNewline', 'var a = 1 /*<LF>*/ var b = 2')]
    [TestCase('ClosingBrace', '{ 1 }')]
    [TestCase('EndOfInput', 'var a = 1')]
    [TestCase('DoWhileWithoutSemicolon', 'do {} while (false) var z = 1')]
    [TestCase('DoWhileEmptyBody', 'do ; while (false) 1')]
    procedure Statement_WithAutomaticSemicolon_IsAllowed(const Source: string);

    [Test]
    procedure Throw_FollowedByLineBreak_IsSyntaxError;

    [Test]
    [TestCase('While', 'while (false) function f() {}')]
    [TestCase('DoWhile', 'do function f() {} while (false)')]
    [TestCase('For', 'for (;false;) function f() {}')]
    [TestCase('ForIn', 'for (var p in {}) function f() {}')]
    [TestCase('StrictIf', '"use strict"; if (true) function f() {}')]
    [TestCase('StrictElse', '"use strict"; if (true) ; else function f() {}')]
    procedure Statement_FunctionDeclarationAsBody_IsSyntaxError(const Source: string);

    [Test]
    procedure Statement_FunctionDeclarationAsSloppyIfBody_IsAllowed;

    [Test]
    procedure Switch_TwoDefaultClauses_IsSyntaxError;

    [Test]
    [TestCase('Eval', '"use strict"; for (var eval in {}) ;')]
    [TestCase('Arguments', '"use strict"; for (var arguments in null) {}')]
    [TestCase('FutureReserved', '"use strict"; for (var let;;) break;')]
    procedure ForVariable_StrictRestrictedName_IsSyntaxError(const Source: string);

    [Test]
    procedure RegExpLiteral_BackslashBeforeLineBreak_IsSyntaxError;
  end;

implementation

procedure TSyntaxEarlyErrorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TSyntaxEarlyErrorTests.TearDown;
begin
  FEngine.Free;
end;

function TSyntaxEarlyErrorTests.SourceWithLineBreaks(const Source: string): string;
begin
  Result := Source.Replace('<LF>', #10);
end;

function TSyntaxEarlyErrorTests.EvaluatesToSyntaxError(const Source: string): Boolean;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const LineBreaksEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = false; try { eval("%s"); } catch (e) { caught = e instanceof SyntaxError; }',
                         [LineBreaksEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsBoolean;
end;

procedure TSyntaxEarlyErrorTests.Return_OutsideFunction_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TSyntaxEarlyErrorTests.Return_InsideFunctionAndAccessor_IsAllowed;
begin
  const Script =
    'function f() { return 1; }' + sLineBreak +
    'var o = { get g() { return 2; } };' + sLineBreak +
    'var h = new Function("return 4;");' + sLineBreak +
    'f() + o.g + h()';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TSyntaxEarlyErrorTests.Identifier_UnusedReservedWord_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TSyntaxEarlyErrorTests.PropertyName_UnusedReservedWord_IsAllowed;
begin
  const Script =
    'var o = { enum: 1, class: 2, get export() { return 4; } };' + sLineBreak +
    'o.enum + o.class + o.export';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TSyntaxEarlyErrorTests.Statement_WithoutTerminator_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TSyntaxEarlyErrorTests.Statement_WithAutomaticSemicolon_IsAllowed(const Source: string);
begin
  Assert.IsFalse(EvaluatesToSyntaxError(SourceWithLineBreaks(Source)));
end;

procedure TSyntaxEarlyErrorTests.Throw_FollowedByLineBreak_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError(SourceWithLineBreaks('try { throw<LF>1; } catch (e) {}')));
end;

procedure TSyntaxEarlyErrorTests.Statement_FunctionDeclarationAsBody_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TSyntaxEarlyErrorTests.Statement_FunctionDeclarationAsSloppyIfBody_IsAllowed;
begin
  Assert.IsFalse(EvaluatesToSyntaxError('if (true) function f() {}'));
end;

procedure TSyntaxEarlyErrorTests.Switch_TwoDefaultClauses_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError('switch (0) { default: break; default: break; }'));
end;

procedure TSyntaxEarlyErrorTests.ForVariable_StrictRestrictedName_IsSyntaxError(const Source: string);
begin
  Assert.IsTrue(EvaluatesToSyntaxError(Source));
end;

procedure TSyntaxEarlyErrorTests.RegExpLiteral_BackslashBeforeLineBreak_IsSyntaxError;
begin
  Assert.IsTrue(EvaluatesToSyntaxError(SourceWithLineBreaks('var r = /a\<LF>/;')));
end;

end.
