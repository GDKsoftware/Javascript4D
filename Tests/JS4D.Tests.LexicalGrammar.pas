unit JS4D.Tests.LexicalGrammar;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TLexicalGrammarTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('Tab', '9')]
    [TestCase('Vertical tab', '11')]
    [TestCase('Form feed', '12')]
    [TestCase('Space', '32')]
    [TestCase('No-break space', '160')]
    [TestCase('Ogham space mark', '5760')]
    [TestCase('En quad', '8192')]
    [TestCase('Hair space', '8202')]
    [TestCase('Narrow no-break space', '8239')]
    [TestCase('Medium mathematical space', '8287')]
    [TestCase('Ideographic space', '12288')]
    [TestCase('Byte order mark', '65279')]
    procedure WhiteSpace_BetweenTokens_IsSkipped(const CodeUnit: Integer);

    [Test]
    [TestCase('Vertical tab', '11')]
    [TestCase('No-break space', '160')]
    [TestCase('Byte order mark', '65279')]
    [TestCase('Ideographic space', '12288')]
    procedure WhiteSpace_AfterRegExpLiteral_IsSkipped(const CodeUnit: Integer);

    [Test]
    [TestCase('Line feed', '10')]
    [TestCase('Carriage return', '13')]
    [TestCase('Line separator', '8232')]
    [TestCase('Paragraph separator', '8233')]
    procedure SingleLineComment_AnyLineTerminator_EndsComment(const CodeUnit: Integer);

    [Test]
    [TestCase('Line feed', '10')]
    [TestCase('Carriage return', '13')]
    procedure StringLiteral_WithRawLineTerminator_IsSyntaxError(const CodeUnit: Integer);

    [Test]
    [TestCase('Line feed', '10')]
    [TestCase('Carriage return', '13')]
    [TestCase('Line separator', '8232')]
    [TestCase('Paragraph separator', '8233')]
    procedure LineContinuation_InStringLiteral_ContributesNothing(const CodeUnit: Integer);

    [Test]
    procedure LineContinuation_CarriageReturnLineFeed_IsOneTerminator;

    [Test]
    [TestCase('Leading dot', '.5,0.5')]
    [TestCase('Leading dot with exponent', '.5e1,5')]
    [TestCase('Trailing dot', '5.,5')]
    [TestCase('Trailing dot with exponent', '1.e1,10')]
    [TestCase('Zero trailing dot with exponent', '0.e1,0')]
    [TestCase('Zero trailing dot with negative exponent', '0.E-1,0')]
    [TestCase('Zero leading dot', '.0,0')]
    [TestCase('Fraction', '1.25,1.25')]
    [TestCase('Exponent', '2e3,2000')]
    [TestCase('Zero eight', '08,8')]
    [TestCase('Zero nine', '09,9')]
    [TestCase('Double zero eight', '008,8')]
    [TestCase('Octal like decimal', '0178,178')]
    [TestCase('Octal like decimal long', '0708,708')]
    [TestCase('Legacy octal', '010,8')]
    [TestCase('Legacy octal seven', '0777,511')]
    procedure NumericLiteral_Source_HasExpectedValue(const Source: string; const Expected: Double);

    [Test]
    procedure NumericLiteral_TrailingDotBeforeMember_ReadsMemberOfNumber;

    [Test]
    [TestCase('Lower hex prefix', '0x')]
    [TestCase('Upper hex prefix', '0X')]
    [TestCase('Hex prefix before operator', '0x+1')]
    [TestCase('Identifier after number', '3in [] ')]
    [TestCase('Zero eight', '"use strict"; 08')]
    [TestCase('Zero nine', '"use strict"; 09')]
    [TestCase('Octal like decimal', '"use strict"; 018')]
    [TestCase('Legacy octal', '"use strict"; 010')]
    [TestCase('Octal', '"use strict"; "\1"')]
    [TestCase('Octal with zero', '"use strict"; "\08"')]
    [TestCase('Three digit octal', '"use strict"; "\101"')]
    [TestCase('Eight', '"use strict"; "\8"')]
    [TestCase('Nine', '"use strict"; "\9"')]
    [TestCase('Inside strict function', 'function f() { "use strict"; return "\1"; }')]
    [TestCase('Prologue before directive', 'function f() { "\1"; "use strict"; }')]
    [TestCase('Prologue before directive at top', '"\052"; "use strict";')]
    procedure Literal_InvalidSource_RaisesSyntaxError(const Source: string);

    [Test]
    [TestCase('One', '\1,1')]
    [TestCase('Seven', '\7,7')]
    [TestCase('Two digits', '\12,10')]
    [TestCase('Three digits', '\101,65')]
    [TestCase('Highest', '\377,255')]
    [TestCase('Four and zero', '\400,32')]
    procedure StringLiteral_LegacyOctalEscape_ProducesCodeUnit(const Escape: string; const Expected: Integer);

    [Test]
    procedure StringLiteral_OctalEscapeFollowedByNonOctalDigit_KeepsTheDigit;

    [Test]
    procedure StringLiteral_ZeroEscapeNotFollowedByDigit_IsNull;

    [Test]
    procedure StringLiteral_NonOctalEscapeInSloppyCode_IsTheDigit;

    [Test]
    [TestCase('Plain zero', '"use strict"; "\0"')]
    [TestCase('Zero before letter', '"use strict"; "\0a"')]
    [TestCase('Sloppy function next to strict one', 'function f() { "use strict"; } function g() { return "\1"; }')]
    [TestCase('Octal after prologue', 'function f() { "a"; return "\1"; }')]
    [TestCase('Hex escape', 'function f() { "use\x20strict"; with ({}) {} }')]
    [TestCase('Line continuation', 'function f() { "use str\' + #10 + 'ict"; with ({}) {} }')]
    procedure StringLiteral_ValidSource_RaisesNoError(const Source: string);

    [Test]
    procedure DirectivePrologue_UseStrictAfterOtherDirective_StartsStrictMode;
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

procedure TLexicalGrammarTests.WhiteSpace_BetweenTokens_IsSkipped(const CodeUnit: Integer);
begin
  const Gap = Char(CodeUnit);
  const Source = Format('1%s+%s2', [Gap, Gap]);

  const Actual = EvaluateNumber(Source);

  Assert.AreEqual(3.0, Actual);
end;

procedure TLexicalGrammarTests.WhiteSpace_AfterRegExpLiteral_IsSkipped(const CodeUnit: Integer);
begin
  const Gap = Char(CodeUnit);
  const Source = Format('/a/%s.test("a")', [Gap]);

  const Actual = EvaluateBoolean(Source);

  Assert.IsTrue(Actual);
end;

procedure TLexicalGrammarTests.SingleLineComment_AnyLineTerminator_EndsComment(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('var x = 1; // comment%sx = 2; x', [Terminator]);

  const Actual = EvaluateNumber(Source);

  Assert.AreEqual(2.0, Actual);
end;

procedure TLexicalGrammarTests.StringLiteral_WithRawLineTerminator_IsSyntaxError(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('"a%sb"', [Terminator]);

  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TLexicalGrammarTests.LineContinuation_InStringLiteral_ContributesNothing(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('"a\%sb"', [Terminator]);

  const Actual = EvaluateText(Source);

  Assert.AreEqual('ab', Actual);
end;

procedure TLexicalGrammarTests.LineContinuation_CarriageReturnLineFeed_IsOneTerminator;
begin
  const Source = '"a\' + #13#10 + 'b"';

  const Actual = EvaluateText(Source);

  Assert.AreEqual('ab', Actual);
end;

procedure TLexicalGrammarTests.NumericLiteral_Source_HasExpectedValue(const Source: string;
                                                                          const Expected: Double);
begin
  const Actual = EvaluateNumber(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TLexicalGrammarTests.NumericLiteral_TrailingDotBeforeMember_ReadsMemberOfNumber;
begin
  const Actual = EvaluateText('1..toString()');

  Assert.AreEqual('1', Actual);
end;

procedure TLexicalGrammarTests.Literal_InvalidSource_RaisesSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TLexicalGrammarTests.StringLiteral_LegacyOctalEscape_ProducesCodeUnit(const Escape: string;
                                                                                const Expected: Integer);
begin
  const Literal = Format('"%s".charCodeAt(0)', [Escape]);
  const Script = Format('eval("%s")', [TJSTestSupport.EscapeForStringLiteral(Literal)]);

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(Double(Expected), Actual, Literal);
end;

procedure TLexicalGrammarTests.StringLiteral_OctalEscapeFollowedByNonOctalDigit_KeepsTheDigit;
begin
  const FirstActual = EvaluateNumber('"\08".length');
  const SecondActual = EvaluateNumber('"\08".charCodeAt(0)');
  const ThirdActual = EvaluateNumber('"\08".charCodeAt(1)');
  const FourthActual = EvaluateNumber('"\18".charCodeAt(1)');

  Assert.AreEqual(2.0, FirstActual);
  Assert.AreEqual(0.0, SecondActual);
  Assert.AreEqual(56.0, ThirdActual);
  Assert.AreEqual(56.0, FourthActual);
end;

procedure TLexicalGrammarTests.StringLiteral_ZeroEscapeNotFollowedByDigit_IsNull;
begin
  const FirstActual = EvaluateNumber('"\0".charCodeAt(0)');
  const SecondActual = EvaluateNumber('"\0a".length');

  Assert.AreEqual(0.0, FirstActual);
  Assert.AreEqual(2.0, SecondActual);
end;

procedure TLexicalGrammarTests.StringLiteral_NonOctalEscapeInSloppyCode_IsTheDigit;
begin
  const FirstActual = EvaluateText('"\8"');
  const SecondActual = EvaluateText('"\9"');

  Assert.AreEqual('8', FirstActual);
  Assert.AreEqual('9', SecondActual);
end;

procedure TLexicalGrammarTests.StringLiteral_ValidSource_RaisesNoError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual('', Actual);
end;

procedure TLexicalGrammarTests.DirectivePrologue_UseStrictAfterOtherDirective_StartsStrictMode;
begin
  const Source = 'function f() { "other"; "use strict"; with ({}) {} }';

  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

end.
