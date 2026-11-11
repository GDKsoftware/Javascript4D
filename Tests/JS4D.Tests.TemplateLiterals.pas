unit JS4D.Tests.TemplateLiterals;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TTemplateLiteralTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('NoSubstitution', '`abc`|abc', '|')]
    [TestCase('Empty', '`` + "x"|x', '|')]
    [TestCase('OneSubstitution', '`a${1 + 2}b`|a3b', '|')]
    [TestCase('AdjacentSubstitutions', '`${"x"}${"y"}`|xy', '|')]
    [TestCase('Nested', '`a${`b${1}`}c`|ab1c', '|')]
    [TestCase('ObjectLiteralInSubstitution', '`${ {a: 2}.a }!`|2!', '|')]
    [TestCase('FunctionBodyInSubstitution', '`${(function () { return {a: 4}; })().a}`|4', '|')]
    [TestCase('RegularExpressionInSubstitution', '`${/a/.test("a")}`|true', '|')]
    [TestCase('DivisionAfterTemplate', '`4` / 2|2', '|')]
    [TestCase('DivisionAfterTemplateTail', '`${2}4` / 2|12', '|')]
    [TestCase('MemberOfTemplate', '`abc`.length|3', '|')]
    [TestCase('ArrayIsJoined', '`${[1, 2]}`|1,2', '|')]
    [TestCase('ToStringIsPreferredOverValueOf', '`${{toString: function () { return "t"; }, valueOf: function () { return "v"; }}}`|t', '|')]
    [TestCase('UndefinedAndNull', '`${undefined}${null}`|undefinednull', '|')]
    [TestCase('DollarWithoutBrace', '`$`|$', '|')]
    [TestCase('DoubleDollar', '`$${1}`|$1', '|')]
    [TestCase('EscapedDollarBrace', '`\${1}`|${1}', '|')]
    [TestCase('Typeof', 'typeof `a`|string', '|')]
    [TestCase('CommaInsideSubstitution', '`${1, 2}`|2', '|')]
    [TestCase('Concatenation', '`a` + `b`|ab', '|')]
    [TestCase('SubstitutionsAreEvaluatedInOrder', 'var s = ""; function f(x) { s += x; return x; } `${f(1)}${f(2)}${f(3)}`; s|123', '|')]
    procedure Template_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('NewlineEscape', '`\n`.charCodeAt(0)|10', '|')]
    [TestCase('TabEscape', '`\t`.charCodeAt(0)|9', '|')]
    [TestCase('HexEscape', '`\x41`|A', '|')]
    [TestCase('UnicodeEscape', '`\u00' + '41`|A', '|')]
    [TestCase('CodePointEscape', '`\u{41}`|A', '|')]
    [TestCase('CodePointEscapeAstral', '`\u{1F600}`.length|2', '|')]
    [TestCase('CodePointEscapeHighSurrogate', '`\u{1F600}`.charCodeAt(0)|55357', '|')]
    [TestCase('CodePointEscapeLeadingZeros', '`\u{0000041}`|A', '|')]
    [TestCase('NulEscape', '`\0`.charCodeAt(0)|0', '|')]
    [TestCase('EscapedBacktick', '`\``|`', '|')]
    [TestCase('EscapedBackslash', '`\\`.length|1', '|')]
    [TestCase('NonEscapeCharacter', '`\a`|a', '|')]
    [TestCase('LineContinuation', '`a\' + #10 + 'b`|ab', '|')]
    [TestCase('LiteralNewline', '`a' + #10 + 'b`.length|3', '|')]
    [TestCase('CarriageReturnLineFeedIsNormalized', '`a' + #13#10 + 'b`.length|3', '|')]
    [TestCase('CarriageReturnIsNormalized', '`a' + #13 + 'b`.charCodeAt(1)|10', '|')]
    [TestCase('LineContinuationWithCarriageReturnLineFeed', '`a\' + #13#10 + 'b`|ab', '|')]
    procedure Escape_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('UnterminatedTemplate', '`abc', '|')]
    [TestCase('UnterminatedSubstitution', '`${1', '|')]
    [TestCase('UnterminatedAfterSubstitution', '`${1}abc', '|')]
    [TestCase('EmptySubstitution', '`${}`', '|')]
    [TestCase('InvalidUnicodeEscape', '`\u`', '|')]
    [TestCase('ShortUnicodeEscape', '`\u00`', '|')]
    [TestCase('InvalidHexEscape', '`\xg`', '|')]
    [TestCase('ShortHexEscape', '`\x4`', '|')]
    [TestCase('LegacyOctalEscape', '`\01`', '|')]
    [TestCase('DecimalEscape', '`\1`', '|')]
    [TestCase('EightEscape', '`\8`', '|')]
    [TestCase('CodePointTooLarge', '`\u{110000}`', '|')]
    [TestCase('UnterminatedCodePoint', '`\u{41`', '|')]
    [TestCase('EmptyCodePoint', '`\u{}`', '|')]
    [TestCase('InvalidEscapeAfterSubstitution', '`${1}\u`', '|')]
    [TestCase('StrayRightBrace', '}`a`', '|')]
    [TestCase('TaggedTemplateAsAssignmentTarget', 'f()`` = 1', '|')]
    [TestCase('MemberTaggedTemplateAsAssignmentTarget', 'o.f()`` = 1', '|')]
    [TestCase('ParenthesizedTaggedTemplateAsAssignmentTarget', '(f()``) = 1', '|')]
    [TestCase('TaggedTemplateInPostfixUpdate', 'f``++', '|')]
    [TestCase('TaggedTemplateInPrefixUpdate', '++f``', '|')]
    [TestCase('TaggedTemplateAsForInTarget', 'for (f`` in {}) ;', '|')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('TemplateStatement', '`a`;', '|')]
    [TestCase('TemplateStatementWithoutSemicolon', '`a`', '|')]
    [TestCase('TemplateBetweenBraces', 'var o = {a: `x`, b: `y${1}`};', '|')]
    [TestCase('TemplateInStrictMode', '"use strict"; `a${1}`;', '|')]
    [TestCase('TemplateInsideBlock', '{ `a${ `b` }` }', '|')]
    procedure Source_IsAccepted(const Source: string);

    [Test]
    procedure Tagged_ReceivesStringsAndValues;

    [Test]
    procedure Tagged_StringsArrayHasCookedStringsAndLength;

    [Test]
    [TestCase('Plain', 'function t(s) { return s.raw[0]; } t`a\nb`|a\nb', '|')]
    [TestCase('Backslash', 'function t(s) { return s.raw[0]; } t`a\\b`|a\\b', '|')]
    [TestCase('Unicode', 'function t(s) { return s.raw[0]; } t`\u00' + '41`|\u00' + '41', '|')]
    [TestCase('Substitutions', 'function t(s) { return s.raw.join(","); } t`x\ty${1}z\n`|x\ty,z\n', '|')]
    procedure Tagged_RawStringsKeepEscapes(const Source: string; const Expected: string);

    [Test]
    procedure Tagged_RawStringsNormalizeLineTerminators;

    [Test]
    procedure Tagged_RawStringsKeepLineContinuation;

    [Test]
    procedure Tagged_StringsArrayIsCachedPerSite;

    [Test]
    procedure Tagged_DifferentSitesHaveDifferentArrays;

    [Test]
    procedure Tagged_SameSiteInLoopSharesArray;

    [Test]
    procedure Tagged_StringsArrayIsFrozen;

    [Test]
    procedure Tagged_RawArrayIsFrozen;

    [Test]
    procedure Tagged_RawPropertyIsHidden;

    [Test]
    procedure Tagged_StringsArrayIsAnArray;

    [Test]
    procedure Tagged_InvalidEscapeGivesUndefinedCookedAndRaw;

    [Test]
    procedure Tagged_InvalidEscapeInLaterPartKeepsEarlierParts;

    [Test]
    procedure Tagged_MemberTagReceivesObjectAsThis;

    [Test]
    procedure Tagged_ComputedMemberTagReceivesObjectAsThis;

    [Test]
    procedure Tagged_PlainTagInSloppyModeReceivesGlobalAsThis;

    [Test]
    procedure Tagged_TagIsEvaluatedBeforeSubstitutions;

    [Test]
    procedure Tagged_ResultOfTagIsReturned;

    [Test]
    procedure Tagged_TagResultCanBeTaggedAgain;

    [Test]
    procedure Tagged_TagThatIsNotAFunction_RaisesTypeError;

    [Test]
    procedure Tagged_WithNoSubstitution_GetsOnlyStringsArray;

    [Test]
    procedure Tagged_ParenthesizedTag_Works;

    [Test]
    procedure Tagged_NewExpressionUsesTaggedResult;

    [Test]
    procedure Tagged_InsideFunctionSite_IsCachedAcrossCalls;

    [Test]
    procedure Tagged_ThrowingSubstitution_PropagatesError;

    [Test]
    procedure StringRaw_UsesRawStrings;

    [Test]
    [TestCase('Plain', 'String.raw({raw: ["a", "b", "c"]}, 1, 2)|a1b2c', '|')]
    [TestCase('FewerSubstitutions', 'String.raw({raw: ["a", "b", "c"]}, 1)|a1bc', '|')]
    [TestCase('MoreSubstitutions', 'String.raw({raw: ["a", "b"]}, 1, 2, 3)|a1b', '|')]
    [TestCase('ArrayLike', 'String.raw({raw: {length: 2, 0: "x", 1: "y"}}, 9)|x9y', '|')]
    [TestCase('SingleSegment', 'String.raw({raw: ["only"]}, 1)|only', '|')]
    [TestCase('EmptyRaw', 'String.raw({raw: []}) + "."|.', '|')]
    [TestCase('LengthUndefined', 'String.raw({raw: {}}) + "."|.', '|')]
    [TestCase('NegativeLength', 'String.raw({raw: {length: -1}}) + "."|.', '|')]
    [TestCase('StringRaw', 'String.raw({raw: "abc"}, 1, 2)|a1b2c', '|')]
    [TestCase('SubstitutionIsStringified', 'String.raw({raw: ["a", "b"]}, [1, 2])|a1,2b', '|')]
    procedure StringRaw_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('RawIsUndefined', 'String.raw({})', '|')]
    [TestCase('RawIsNull', 'String.raw({raw: null})', '|')]
    [TestCase('TemplateIsUndefined', 'String.raw()', '|')]
    [TestCase('TemplateIsNull', 'String.raw(null)', '|')]
    procedure StringRaw_RaisesTypeError(const Source: string);

    [Test]
    procedure StringRaw_HasLengthOne;

    [Test]
    procedure StringRaw_IsNotAConstructor;

    [Test]
    procedure StringRaw_PropagatesErrorsFromGetters;
  end;

implementation

procedure TTemplateLiteralTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TTemplateLiteralTests.TearDown;
begin
  FEngine.Free;
end;

function TTemplateLiteralTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TTemplateLiteralTests.Template_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TTemplateLiteralTests.Escape_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TTemplateLiteralTests.Source_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TTemplateLiteralTests.Source_IsAccepted(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TTemplateLiteralTests.Tagged_ReceivesStringsAndValues;
begin
  const Script = 'function t(s, a, b) { return s.join("|") + a + b; } t`x${1}y${2}z`';

  Assert.AreEqual('x|y|z12', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_StringsArrayHasCookedStringsAndLength;
begin
  const Script = 'function t(s) { return s.length + ":" + s[0] + ":" + s[1]; } t`a\n${0}b`';

  Assert.AreEqual('2:a' + #10 + ':b', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_RawStringsKeepEscapes(const Source: string; const Expected: string);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).ToString);
end;

procedure TTemplateLiteralTests.Tagged_RawStringsNormalizeLineTerminators;
begin
  const Script = 'function t(s) { return s.raw[0]; } t`a' + #13#10 + 'b' + #13 + 'c`';

  Assert.AreEqual('a' + #10 + 'b' + #10 + 'c', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_RawStringsKeepLineContinuation;
begin
  const Script = 'function t(s) { return s.raw[0] + "/" + s[0]; } t`a\' + #10 + 'b`';

  Assert.AreEqual('a\' + #10 + 'b/ab', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_StringsArrayIsCachedPerSite;
begin
  const Script = 'function t(s) { return s; } function f() { return t`x`; } f() === f()';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_DifferentSitesHaveDifferentArrays;
begin
  const Script = 'function t(s) { return s; } t`x` === t`x`';

  Assert.IsFalse(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_SameSiteInLoopSharesArray;
begin
  const Script = 'function t(s) { return s; } var seen = []; ' +
                 'for (var i = 0; i < 3; i++) { seen.push(t`x${i}`); } ' +
                 'seen[0] === seen[1] && seen[1] === seen[2]';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_StringsArrayIsFrozen;
begin
  const Script = 'function t(s) { return s; } var s = t`a${1}b`; ' +
                 's[0] = "z"; s[5] = "q"; s.length = 0; ' +
                 'Object.isFrozen(s) && s[0] === "a" && s.length === 2 && s[5] === undefined';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_RawArrayIsFrozen;
begin
  const Script = 'function t(s) { return s; } var r = t`a${1}b`.raw; ' +
                 'r[0] = "z"; r.length = 0; ' +
                 'Object.isFrozen(r) && r[0] === "a" && r.length === 2 && Array.isArray(r)';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_RawPropertyIsHidden;
begin
  const Script = 'function t(s) { return s; } var d = Object.getOwnPropertyDescriptor(t`a`, "raw"); ' +
                 '!d.enumerable && !d.writable && !d.configurable';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_StringsArrayIsAnArray;
begin
  const Script = 'function t(s) { return s; } Array.isArray(t`a`) && Object.keys(t`a${1}b`).join() === "0,1"';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_InvalidEscapeGivesUndefinedCookedAndRaw;
begin
  const Script = 'function t(s) { return (s[0] === undefined) + ":" + s.raw[0]; } t`\unicode`';

  Assert.AreEqual('true:\unicode', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_InvalidEscapeInLaterPartKeepsEarlierParts;
begin
  const Script = 'function t(s) { return s[0] + "," + (s[1] === undefined) + "," + s[2] + "," + s.raw[1]; } ' +
                 't`a${1}\xg${2}c`';

  Assert.AreEqual('a,true,c,\xg', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_MemberTagReceivesObjectAsThis;
begin
  const Script = 'var o = {f: function (s) { return this === o; }}; o.f`x`';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_ComputedMemberTagReceivesObjectAsThis;
begin
  const Script = 'var o = {f: function (s) { return this === o; }}; o["f"]`x`';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_PlainTagInSloppyModeReceivesGlobalAsThis;
begin
  const Script = 'var g = this; function t(s) { return this === g; } t`x`';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_TagIsEvaluatedBeforeSubstitutions;
begin
  const Script = 'var log = []; function tag() { log.push("tag"); return function () {}; } ' +
                 'function sub() { log.push("sub"); return 1; } tag()`${sub()}`; log.join()';

  Assert.AreEqual('tag,sub', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_ResultOfTagIsReturned;
begin
  const Script = 'function t(s, a) { return {first: s[0], value: a}; } t`p${7}`.value';

  Assert.AreEqual(7.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TTemplateLiteralTests.Tagged_TagResultCanBeTaggedAgain;
begin
  const Script = 'function t(s) { return function (u) { return s[0] + u[0]; }; } t`a``b`';

  Assert.AreEqual('ab', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_TagThatIsNotAFunction_RaisesTypeError;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('var x = 1; x`a`'));
end;

procedure TTemplateLiteralTests.Tagged_WithNoSubstitution_GetsOnlyStringsArray;
begin
  const Script = 'function t(s) { return arguments.length; } t`a`';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TTemplateLiteralTests.Tagged_ParenthesizedTag_Works;
begin
  const Script = 'function t(s) { return s[0]; } (t)`a`';

  Assert.AreEqual('a', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.Tagged_NewExpressionUsesTaggedResult;
begin
  const Script = 'function F() { this.v = 1; } function t(s) { return F; } (new t`x`).v';

  Assert.AreEqual(1.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TTemplateLiteralTests.Tagged_InsideFunctionSite_IsCachedAcrossCalls;
begin
  const Script = 'var seen = []; function t(s) { seen.push(s); } function f() { t`a${1}`; } f(); f(); seen[0] === seen[1]';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TTemplateLiteralTests.Tagged_ThrowingSubstitution_PropagatesError;
begin
  Assert.AreEqual('RangeError', ErrorNameOf('function t() {} t`${(function () { throw new RangeError("x"); })()}`'));
end;

procedure TTemplateLiteralTests.StringRaw_UsesRawStrings;
begin
  const Script = 'String.raw`a\n${1}b`';

  Assert.AreEqual('a\n1b', FEngine.Evaluate(Script).AsString);
end;

procedure TTemplateLiteralTests.StringRaw_Result(const Source: string; const Expected: string);
begin
  Assert.AreEqual(Expected, FEngine.Evaluate(Source).ToString);
end;

procedure TTemplateLiteralTests.StringRaw_RaisesTypeError(const Source: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Source));
end;

procedure TTemplateLiteralTests.StringRaw_HasLengthOne;
begin
  Assert.AreEqual(1.0, FEngine.Evaluate('String.raw.length').AsNumber);
end;

procedure TTemplateLiteralTests.StringRaw_IsNotAConstructor;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('new String.raw({raw: []})'));
end;

procedure TTemplateLiteralTests.StringRaw_PropagatesErrorsFromGetters;
begin
  const Script = 'var o = {raw: {get length() { throw new RangeError("x"); }}}; String.raw(o)';

  Assert.AreEqual('RangeError', ErrorNameOf(Script));
end;

end.
