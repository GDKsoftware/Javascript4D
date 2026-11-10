unit JS4D.Tests.LexicalGrammar;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TLexicalGrammarTests = class
  private
    FEngine: TJSEngine;

    function EscapeForStringLiteral(const Source: string): string;
    function ErrorNameOfEval(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure SingleLineComment_EndsAtAnyLineTerminator(const CodeUnit: Integer);

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
    procedure NumericLiteral_DecimalForms_HaveTheirValue(const Source: string; const Expected: Double);

    [Test]
    procedure NumericLiteral_TrailingDotBeforeMember_ReadsMemberOfNumber;

    [Test]
    [TestCase('Zero eight', '08,8')]
    [TestCase('Zero nine', '09,9')]
    [TestCase('Double zero eight', '008,8')]
    [TestCase('Octal like decimal', '0178,178')]
    [TestCase('Octal like decimal long', '0708,708')]
    [TestCase('Legacy octal', '010,8')]
    [TestCase('Legacy octal seven', '0777,511')]
    procedure NumericLiteral_LeadingZero_FollowsLegacyRules(const Source: string; const Expected: Double);

    [Test]
    [TestCase('Lower hex prefix', '0x')]
    [TestCase('Upper hex prefix', '0X')]
    [TestCase('Hex prefix before operator', '0x+1')]
    [TestCase('Identifier after number', '3in [] ')]
    procedure NumericLiteral_Malformed_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('Zero eight', '"use strict"; 08')]
    [TestCase('Zero nine', '"use strict"; 09')]
    [TestCase('Octal like decimal', '"use strict"; 018')]
    [TestCase('Legacy octal', '"use strict"; 010')]
    procedure NumericLiteral_LeadingZeroInStrictCode_IsSyntaxError(const Source: string);

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
    [TestCase('Octal', '"use strict"; "\1"')]
    [TestCase('Octal with zero', '"use strict"; "\08"')]
    [TestCase('Three digit octal', '"use strict"; "\101"')]
    [TestCase('Eight', '"use strict"; "\8"')]
    [TestCase('Nine', '"use strict"; "\9"')]
    [TestCase('Inside strict function', 'function f() { "use strict"; return "\1"; }')]
    [TestCase('Prologue before directive', 'function f() { "\1"; "use strict"; }')]
    [TestCase('Prologue before directive at top', '"\052"; "use strict";')]
    procedure StringLiteral_LegacyEscapeInStrictCode_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('Plain zero', '"use strict"; "\0"')]
    [TestCase('Zero before letter', '"use strict"; "\0a"')]
    [TestCase('Sloppy function next to strict one', 'function f() { "use strict"; } function g() { return "\1"; }')]
    [TestCase('Octal after prologue', 'function f() { "a"; return "\1"; }')]
    procedure StringLiteral_AllowedEscapes_AreNotRejected(const Source: string);

    [Test]
    procedure DirectivePrologue_UseStrictAfterOtherDirective_StartsStrictMode;

    [Test]
    [TestCase('Hex escape', 'function f() { "use\x20strict"; with ({}) {} }')]
    [TestCase('Line continuation', 'function f() { "use str\' + #10 + 'ict"; with ({}) {} }')]
    procedure DirectivePrologue_UseStrictWithEscape_IsNotADirective(const Source: string);
  end;

implementation

const
  SyntaxErrorName = 'SyntaxError';
  NoErrorName = 'none';

procedure TLexicalGrammarTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TLexicalGrammarTests.TearDown;
begin
  FEngine.Free;
end;

function TLexicalGrammarTests.EscapeForStringLiteral(const Source: string): string;
begin
  var Escaped := '';
  for var Character in Source do
  begin
    Escaped := Escaped + Format('\u%.4x', [Ord(Character)]);
  end;

  Result := Escaped;
end;

function TLexicalGrammarTests.ErrorNameOfEval(const Source: string): string;
begin
  const Script = Format('var name = "%s"; try { eval("%s"); } catch (e) { name = e.name; } name',
                        [NoErrorName, EscapeForStringLiteral(Source)]);

  Result := FEngine.Evaluate(Script).AsString;
end;

procedure TLexicalGrammarTests.WhiteSpace_BetweenTokens_IsSkipped(const CodeUnit: Integer);
begin
  const Gap = Char(CodeUnit);
  const Source = Format('1%s+%s2', [Gap, Gap]);

  Assert.AreEqual(3.0, FEngine.Evaluate(Source).AsNumber);
end;

procedure TLexicalGrammarTests.WhiteSpace_AfterRegExpLiteral_IsSkipped(const CodeUnit: Integer);
begin
  const Gap = Char(CodeUnit);
  const Source = Format('/a/%s.test("a")', [Gap]);

  Assert.IsTrue(FEngine.Evaluate(Source).AsBoolean);
end;

procedure TLexicalGrammarTests.SingleLineComment_EndsAtAnyLineTerminator(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('var x = 1; // comment%sx = 2; x', [Terminator]);

  Assert.AreEqual(2.0, FEngine.Evaluate(Source).AsNumber);
end;

procedure TLexicalGrammarTests.StringLiteral_WithRawLineTerminator_IsSyntaxError(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('"a%sb"', [Terminator]);

  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.LineContinuation_InStringLiteral_ContributesNothing(const CodeUnit: Integer);
begin
  const Terminator = Char(CodeUnit);
  const Source = Format('"a\%sb"', [Terminator]);

  Assert.AreEqual('ab', FEngine.Evaluate(Source).AsString);
end;

procedure TLexicalGrammarTests.LineContinuation_CarriageReturnLineFeed_IsOneTerminator;
begin
  const Source = '"a\' + #13#10 + 'b"';

  Assert.AreEqual('ab', FEngine.Evaluate(Source).AsString);
end;

procedure TLexicalGrammarTests.NumericLiteral_DecimalForms_HaveTheirValue(const Source: string;
                                                                          const Expected: Double);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).AsNumber);
end;

procedure TLexicalGrammarTests.NumericLiteral_TrailingDotBeforeMember_ReadsMemberOfNumber;
begin
  Assert.AreEqual('1', FEngine.Evaluate('1..toString()').AsString);
end;

procedure TLexicalGrammarTests.NumericLiteral_LeadingZero_FollowsLegacyRules(const Source: string;
                                                                             const Expected: Double);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).AsNumber);
end;

procedure TLexicalGrammarTests.NumericLiteral_Malformed_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.NumericLiteral_LeadingZeroInStrictCode_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.StringLiteral_LegacyOctalEscape_ProducesCodeUnit(const Escape: string;
                                                                                const Expected: Integer);
begin
  const Literal = Format('"%s".charCodeAt(0)', [Escape]);
  const Script = Format('eval("%s")', [EscapeForStringLiteral(Literal)]);

  Assert.AreEqual(Double(Expected), FEngine.Evaluate(Script).AsNumber, Literal);
end;

procedure TLexicalGrammarTests.StringLiteral_OctalEscapeFollowedByNonOctalDigit_KeepsTheDigit;
begin
  Assert.AreEqual(2.0, FEngine.Evaluate('"\08".length').AsNumber);
  Assert.AreEqual(0.0, FEngine.Evaluate('"\08".charCodeAt(0)').AsNumber);
  Assert.AreEqual(56.0, FEngine.Evaluate('"\08".charCodeAt(1)').AsNumber);
  Assert.AreEqual(56.0, FEngine.Evaluate('"\18".charCodeAt(1)').AsNumber);
end;

procedure TLexicalGrammarTests.StringLiteral_ZeroEscapeNotFollowedByDigit_IsNull;
begin
  Assert.AreEqual(0.0, FEngine.Evaluate('"\0".charCodeAt(0)').AsNumber);
  Assert.AreEqual(2.0, FEngine.Evaluate('"\0a".length').AsNumber);
end;

procedure TLexicalGrammarTests.StringLiteral_NonOctalEscapeInSloppyCode_IsTheDigit;
begin
  Assert.AreEqual('8', FEngine.Evaluate('"\8"').AsString);
  Assert.AreEqual('9', FEngine.Evaluate('"\9"').AsString);
end;

procedure TLexicalGrammarTests.StringLiteral_LegacyEscapeInStrictCode_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.StringLiteral_AllowedEscapes_AreNotRejected(const Source: string);
begin
  Assert.AreEqual(NoErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.DirectivePrologue_UseStrictAfterOtherDirective_StartsStrictMode;
begin
  const Source = 'function f() { "other"; "use strict"; with ({}) {} }';

  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

procedure TLexicalGrammarTests.DirectivePrologue_UseStrictWithEscape_IsNotADirective(const Source: string);
begin
  Assert.AreEqual(NoErrorName, ErrorNameOfEval(Source));
end;

end.
