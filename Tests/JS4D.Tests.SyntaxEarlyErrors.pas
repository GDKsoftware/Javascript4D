unit JS4D.Tests.SyntaxEarlyErrors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TSyntaxEarlyErrorTests = class(TJSEngineTestCase)
  private
    function SourceWithLineBreaks(const Source: string): string;

  public
    [Test]
    [TestCase('ReturnAlone', 'return;')]
    [TestCase('ReturnWithValue', 'var x = 1; return 2;')]
    [TestCase('ReturnInBlock', '{ return; }')]
    [TestCase('Enum', 'var enum = 1;')]
    [TestCase('Extends', 'var extends;')]
    [TestCase('Export', 'var export;')]
    [TestCase('Import', 'var import;')]
    [TestCase('ExpressionReference', 'enum;')]
    [TestCase('FunctionName', 'function export() {}')]
    [TestCase('Parameter', 'function f(import) {}')]
    [TestCase('CatchParameter', 'try {} catch (enum) {}')]
    [TestCase('ForInVariable', 'for (var extends in {}) ;')]
    [TestCase('TwoNumbers', '1 2')]
    [TestCase('TwoStrings', 'var s = "" "";')]
    [TestCase('BlockThenNumber', '{ 1 2 } 3')]
    [TestCase('ElseOnSameLine', 'if (false) x = 1 else x = -1')]
    [TestCase('VarFollowedByVar', 'var a = 1 var b = 2')]
    [TestCase('ReturnFollowedByToken', 'function f() { return 1 2 }')]
    [TestCase('BreakFollowedByToken', 'while (true) { break 1 }')]
    [TestCase('While', 'while (false) function f() {}')]
    [TestCase('DoWhile', 'do function f() {} while (false)')]
    [TestCase('For', 'for (;false;) function f() {}')]
    [TestCase('ForIn', 'for (var p in {}) function f() {}')]
    [TestCase('StrictIf', '"use strict"; if (true) function f() {}')]
    [TestCase('StrictElse', '"use strict"; if (true) ; else function f() {}')]
    [TestCase('Eval', '"use strict"; for (var eval in {}) ;')]
    [TestCase('Arguments', '"use strict"; for (var arguments in null) {}')]
    [TestCase('FutureReserved', '"use strict"; for (var let;;) break;')]
    [TestCase('ThrowFollowedByLineBreak', 'try { throw<LF>1; } catch (e) {}')]
    [TestCase('TwoDefaultClauses', 'switch (0) { default: break; default: break; }')]
    [TestCase('RegExpBackslashBeforeLineBreak', 'var r = /a\<LF>/;')]
    procedure Source_InvalidSyntax_RaisesSyntaxError(const Source: string);

    [Test]
    procedure Return_InsideFunctionAndAccessor_IsAllowed;

    [Test]
    procedure PropertyName_UnusedReservedWord_IsAllowed;

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
    procedure Statement_FunctionDeclarationAsSloppyIfBody_IsAllowed;
  end;

implementation

uses
  System.SysUtils,
  JS4D.Tests.ErrorNames;

function TSyntaxEarlyErrorTests.SourceWithLineBreaks(const Source: string): string;
begin
  Result := Source.Replace('<LF>', #10);
end;

procedure TSyntaxEarlyErrorTests.Source_InvalidSyntax_RaisesSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(SourceWithLineBreaks(Source));

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TSyntaxEarlyErrorTests.Return_InsideFunctionAndAccessor_IsAllowed;
begin
  const Script =
    'function f() { return 1; }' + sLineBreak +
    'var o = { get g() { return 2; } };' + sLineBreak +
    'var h = new Function("return 4;");' + sLineBreak +
    'f() + o.g + h()';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(7.0, Actual);
end;

procedure TSyntaxEarlyErrorTests.PropertyName_UnusedReservedWord_IsAllowed;
begin
  const Script =
    'var o = { enum: 1, class: 2, get export() { return 4; } };' + sLineBreak +
    'o.enum + o.class + o.export';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(7.0, Actual);
end;

procedure TSyntaxEarlyErrorTests.Statement_WithAutomaticSemicolon_IsAllowed(const Source: string);
begin
  const Actual = ErrorNameOf(SourceWithLineBreaks(Source));

  Assert.AreNotEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TSyntaxEarlyErrorTests.Statement_FunctionDeclarationAsSloppyIfBody_IsAllowed;
begin
  const Actual = ErrorNameOf('if (true) function f() {}');

  Assert.AreNotEqual(SYNTAX_ERROR_NAME, Actual);
end;

end.
