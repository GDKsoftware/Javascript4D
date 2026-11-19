unit JS4D.Tests.TemplateLiterals;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TTemplateLiteralTests = class(TJSEngineTestCase)
  public
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
    [TestCase('Plain', 'function t(s) { return s.raw[0]; } t`a\nb`|a\nb', '|')]
    [TestCase('Backslash', 'function t(s) { return s.raw[0]; } t`a\\b`|a\\b', '|')]
    [TestCase('Unicode', 'function t(s) { return s.raw[0]; } t`\u00' + '41`|\u00' + '41', '|')]
    [TestCase('Substitutions', 'function t(s) { return s.raw.join(","); } t`x\ty${1}z\n`|x\ty,z\n', '|')]
    [TestCase('StringRaw Plain', 'String.raw({raw: ["a", "b", "c"]}, 1, 2)|a1b2c', '|')]
    [TestCase('FewerSubstitutions', 'String.raw({raw: ["a", "b", "c"]}, 1)|a1bc', '|')]
    [TestCase('MoreSubstitutions', 'String.raw({raw: ["a", "b"]}, 1, 2, 3)|a1b', '|')]
    [TestCase('ArrayLike', 'String.raw({raw: {length: 2, 0: "x", 1: "y"}}, 9)|x9y', '|')]
    [TestCase('SingleSegment', 'String.raw({raw: ["only"]}, 1)|only', '|')]
    [TestCase('EmptyRaw', 'String.raw({raw: []}) + "."|.', '|')]
    [TestCase('LengthUndefined', 'String.raw({raw: {}}) + "."|.', '|')]
    [TestCase('NegativeLength', 'String.raw({raw: {length: -1}}) + "."|.', '|')]
    [TestCase('StringRaw', 'String.raw({raw: "abc"}, 1, 2)|a1b2c', '|')]
    [TestCase('SubstitutionIsStringified', 'String.raw({raw: ["a", "b"]}, [1, 2])|a1,2b', '|')]
    [TestCase('Tagged_ReceivesStringsAndValues',
      'function t(s, a, b) { return s.join("|") + a + b; } t`x${1}y${2}z`~x|y|z12', '~')]
    [TestCase('Tagged_StringsArrayHasCookedStringsAndLength',
      'function t(s) { return s.length + ":" + s[0] + ":" + s[1]; } t`a\n${0}b`|2:a' + #10 + ':b', '|')]
    [TestCase('Tagged_RawStringsNormalizeLineTerminators',
      'function t(s) { return s.raw[0]; } t`a' + #13 + #10 + 'b' + #13 + 'c`|a' + #10 + 'b' + #10 + 'c', '|')]
    [TestCase('Tagged_RawStringsKeepLineContinuation',
      'function t(s) { return s.raw[0] + "/" + s[0]; } t`a\' + #10 + 'b`|a\' + #10 + 'b/ab', '|')]
    [TestCase('Tagged_InvalidEscapeGivesUndefinedCookedAndRaw',
      'function t(s) { return (s[0] === undefined) + ":" + s.raw[0]; } t`\unicode`|true:\unicode', '|')]
    [TestCase('Tagged_InvalidEscapeInLaterPartKeepsEarlierParts',
      'function t(s) { return s[0] + "," + (s[1] === undefined) + "," + s[2] + "," + s.raw[1]; } ' +
      't`a${1}\xg${2}c`|a,true,c,\xg', '|')]
    [TestCase('Tagged_TagIsEvaluatedBeforeSubstitutions',
      'var log = []; function tag() { log.push("tag"); return function () {}; } function sub() { ' +
      'log.push("sub"); return 1; } tag()`${sub()}`; log.join()|tag,sub', '|')]
    [TestCase('Tagged_TagResultCanBeTaggedAgain',
      'function t(s) { return function (u) { return s[0] + u[0]; }; } t`a``b`|ab', '|')]
    [TestCase('Tagged_ParenthesizedTag_Works', 'function t(s) { return s[0]; } (t)`a`|a', '|')]
    [TestCase('StringRaw_UsesRawStrings', 'String.raw`a\n${1}b`|a\n1b', '|')]
    [TestCase('Tagged_StringsArrayIsCachedPerSite',
      'function t(s) { return s; } function f() { return t`x`; } f() === f()|true', '|')]
    [TestCase('Tagged_DifferentSitesHaveDifferentArrays', 'function t(s) { return s; } t`x` === t`x`|false', '|')]
    [TestCase('Tagged_SameSiteInLoopSharesArray',
      'function t(s) { return s; } var seen = []; for (var i = 0; i < 3; i++) { ' +
      'seen.push(t`x${i}`); } seen[0] === seen[1] && seen[1] === seen[2]|true', '|')]
    [TestCase('Tagged_StringsArrayIsFrozen',
      'function t(s) { return s; } var s = t`a${1}b`; s[0] = "z"; s[5] = "q"; s.length = 0; ' +
      'Object.isFrozen(s) && s[0] === "a" && s.length === 2 && s[5] === undefined|true', '|')]
    [TestCase('Tagged_RawArrayIsFrozen',
      'function t(s) { return s; } var r = t`a${1}b`.raw; r[0] = "z"; r.length = 0; ' +
      'Object.isFrozen(r) && r[0] === "a" && r.length === 2 && Array.isArray(r)|true', '|')]
    [TestCase('Tagged_RawPropertyIsHidden',
      'function t(s) { return s; } var d = Object.getOwnPropertyDescriptor(t`a`, "raw"); ' +
      '!d.enumerable && !d.writable && !d.configurable|true', '|')]
    [TestCase('Tagged_StringsArrayIsAnArray',
      'function t(s) { return s; } Array.isArray(t`a`) && Object.keys(t`a${1}b`).join() === ' +
      '"0,1"|true', '|')]
    [TestCase('Tagged_MemberTagReceivesObjectAsThis',
      'var o = {f: function (s) { return this === o; }}; o.f`x`|true', '|')]
    [TestCase('Tagged_ComputedMemberTagReceivesObjectAsThis',
      'var o = {f: function (s) { return this === o; }}; o["f"]`x`|true', '|')]
    [TestCase('Tagged_PlainTagInSloppyModeReceivesGlobalAsThis',
      'var g = this; function t(s) { return this === g; } t`x`|true', '|')]
    [TestCase('Tagged_InsideFunctionSite_IsCachedAcrossCalls',
      'var seen = []; function t(s) { seen.push(s); } function f() { t`a${1}`; } f(); f(); ' +
      'seen[0] === seen[1]|true', '|')]
    procedure Template_Script_ReturnsExpectedText(const Source: string; const Expected: string);

    [Test]
    [TestCase('Tagged_ResultOfTagIsReturned',
      'function t(s, a) { return {first: s[0], value: a}; } t`p${7}`.value|7', '|')]
    [TestCase('Tagged_WithNoSubstitution_GetsOnlyStringsArray',
      'function t(s) { return arguments.length; } t`a`|1', '|')]
    [TestCase('Tagged_NewExpressionUsesTaggedResult',
      'function F() { this.v = 1; } function t(s) { return F; } (new t`x`).v|1', '|')]
    [TestCase('StringRaw_HasLengthOne', 'String.raw.length|1', '|')]
    procedure Template_Script_ReturnsNumber(const Source: string; const Expected: Double);

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
    procedure Template_InvalidSource_RaisesSyntaxError(const Source: string);

    [Test]
    [TestCase('TemplateStatement', '`a`;', '|')]
    [TestCase('TemplateStatementWithoutSemicolon', '`a`', '|')]
    [TestCase('TemplateBetweenBraces', 'var o = {a: `x`, b: `y${1}`};', '|')]
    [TestCase('TemplateInStrictMode', '"use strict"; `a${1}`;', '|')]
    [TestCase('TemplateInsideBlock', '{ `a${ `b` }` }', '|')]
    procedure Template_ValidSource_IsAccepted(const Source: string);

    [Test]
    [TestCase('RawIsUndefined', 'String.raw({})', '|')]
    [TestCase('RawIsNull', 'String.raw({raw: null})', '|')]
    [TestCase('TemplateIsUndefined', 'String.raw()', '|')]
    [TestCase('TemplateIsNull', 'String.raw(null)', '|')]
    [TestCase('Tagged_TagThatIsNotAFunction_RaisesTypeError', 'var x = 1; x`a`', '|')]
    [TestCase('StringRaw_IsNotAConstructor', 'new String.raw({raw: []})', '|')]
    procedure Template_Source_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('Tagged_ThrowingSubstitution_PropagatesError',
      'function t() {} t`${(function () { throw new RangeError("x"); })()}`', '|')]
    [TestCase('StringRaw_PropagatesErrorsFromGetters',
      'var o = {raw: {get length() { throw new RangeError("x"); }}}; String.raw(o)', '|')]
    procedure Template_Source_RaisesRangeError(const Source: string);
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

procedure TTemplateLiteralTests.Template_Script_ReturnsExpectedText(const Source: string; const Expected: string);
begin
  const Actual = EvaluateText(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TTemplateLiteralTests.Template_Script_ReturnsNumber(const Source: string; const Expected: Double);
begin
  const Actual = EvaluateNumber(Source);

  Assert.AreEqual(Expected, Actual);
end;

procedure TTemplateLiteralTests.Template_InvalidSource_RaisesSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

procedure TTemplateLiteralTests.Template_ValidSource_IsAccepted(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual('', Actual);
end;

procedure TTemplateLiteralTests.Template_Source_RaisesTypeError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

procedure TTemplateLiteralTests.Template_Source_RaisesRangeError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(RANGE_ERROR_NAME, Actual);
end;

end.
