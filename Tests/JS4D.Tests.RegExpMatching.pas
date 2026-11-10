unit JS4D.Tests.RegExpMatching;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TRegExpMatchingTests = class
  private
    FEngine: TJSEngine;

    procedure AssertScript(const Script: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Quantifier_BoundBeyondEngineLimit_StillCompiles;

    [Test]
    procedure Quantifier_HugeNumberInEscapeOrClass_IsLeftAlone;

    [Test]
    procedure Exec_TrailingGroupDidNotParticipate_IsUndefinedAndCounted;

    [Test]
    procedure Exec_MiddleGroupDidNotParticipate_IsUndefined;

    [Test]
    procedure Exec_Result_IsArrayWithIndexAndInput;

    [Test]
    procedure Exec_Global_ReadsAssignedLastIndex;

    [Test]
    procedure Exec_NonGlobal_IgnoresLastIndex;

    [Test]
    procedure Exec_Global_SetsLastIndexToMatchEnd;

    [Test]
    procedure Exec_Failure_ResetsLastIndex;

    [Test]
    procedure Exec_LastIndexBeyondLength_FailsAndResets;

    [Test]
    procedure Exec_NoArgument_MatchesTextUndefined;

    [Test]
    procedure Exec_ArgumentToStringThrows_PropagatesTheError;

    [Test]
    procedure RegExp_Literal_HasNoOwnExecTestOrToString;

    [Test]
    procedure RegExp_Constructor_HasNoOwnExecTestOrToString;

    [Test]
    procedure Match_NonGlobalTrailingGroup_KeepsCaptureCount;

    [Test]
    procedure Match_Global_ReturnsAllMatches;

    [Test]
    procedure Match_GlobalEmptyMatches_AdvancesPastEach;

    [Test]
    procedure Match_NoArgument_MatchesEmptyPattern;

    [Test]
    procedure Search_NoArgument_ReturnsZero;

    [Test]
    procedure Search_StringArgument_IsTreatedAsPattern;

    [Test]
    procedure Replace_FunctionReplacement_ReceivesMatchGroupsOffsetAndString;

    [Test]
    procedure Replace_FunctionReplacementWithStringPattern_ReceivesMatchOffsetAndString;

    [Test]
    procedure Replace_GlobalFunctionReplacement_CalledPerMatch;

    [Test]
    procedure Replace_DollarPatterns_AreExpanded;

    [Test]
    procedure Replace_DollarZero_StaysLiteral;

    [Test]
    procedure Replace_TwoDigitGroupReference_FallsBackToOneDigit;

    [Test]
    procedure Replace_GlobalEmptyMatches_InsertsAtEveryPosition;

    [Test]
    procedure Replace_StringPatternDollarAmpersand_IsExpanded;

    [Test]
    procedure Split_RegExpWithCaptures_SplicesCapturesIn;

    [Test]
    procedure Split_AnchorAtStart_DoesNotSplit;

    [Test]
    procedure Split_EmptyMatchingRegExp_SplitsIntoCharacters;

    [Test]
    procedure Split_LazyEmptyMatch_SplitsIntoCharacters;

    [Test]
    procedure Split_WithLimit_StopsAtLimit;

    [Test]
    procedure Split_LimitUndefined_MeansNoLimit;

    [Test]
    procedure Split_LimitBeyondInt32_IsReducedModulo32Bits;

    [Test]
    procedure Split_EmptyStringWithMatchingRegExp_ReturnsEmptyArray;

    [Test]
    procedure Split_EmptyStringWithNonMatchingRegExp_ReturnsTheString;
  end;

implementation

procedure TRegExpMatchingTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpMatchingTests.TearDown;
begin
  FEngine.Free;
end;

procedure TRegExpMatchingTests.AssertScript(const Script: string);
begin
  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean, Script);
end;

procedure TRegExpMatchingTests.Quantifier_BoundBeyondEngineLimit_StillCompiles;
begin
  AssertScript(
    '!new RegExp("b{9007199254740991}").test("") && !new RegExp("b{9007199254740991,}?").test("a") &&' +
    '!new RegExp("b{9007199254740991,9007199254740991}").test("b") && /^b{0,9007199254740991}$/.test("bbb") &&' +
    '/^b{00000002}$/.test("bb")');
end;

procedure TRegExpMatchingTests.Quantifier_HugeNumberInEscapeOrClass_IsLeftAlone;
begin
  AssertScript(
    '/\{99999999\}/.test("{99999999}") && /[{99999999}]/.test("9")');
end;

procedure TRegExpMatchingTests.Exec_TrailingGroupDidNotParticipate_IsUndefinedAndCounted;
begin
  AssertScript(
    'var m = /(a)(b)?/.exec("a");' +
    'm.length === 3 && m[1] === "a" && m[2] === undefined');
end;

procedure TRegExpMatchingTests.Exec_MiddleGroupDidNotParticipate_IsUndefined;
begin
  AssertScript(
    'var m = /(a)|(b)|(c)/.exec("c");' +
    'm.length === 4 && m[1] === undefined && m[2] === undefined && m[3] === "c"');
end;

procedure TRegExpMatchingTests.Exec_Result_IsArrayWithIndexAndInput;
begin
  AssertScript(
    'var m = /b+/.exec("aabbb");' +
    '(m instanceof Array) && m[0] === "bbb" && m.index === 2 && m.input === "aabbb"');
end;

procedure TRegExpMatchingTests.Exec_Global_ReadsAssignedLastIndex;
begin
  AssertScript(
    'var r = /a/g; r.lastIndex = 2;' +
    'var m = r.exec("aaaa");' +
    'm.index === 2 && r.lastIndex === 3');
end;

procedure TRegExpMatchingTests.Exec_NonGlobal_IgnoresLastIndex;
begin
  AssertScript(
    'var r = /a/; r.lastIndex = 5;' +
    'var m = r.exec("ba");' +
    'm.index === 1 && r.lastIndex === 5');
end;

procedure TRegExpMatchingTests.Exec_Global_SetsLastIndexToMatchEnd;
begin
  AssertScript(
    'var r = /\d+/g;' +
    'r.exec("ab12cd345");' +
    'var first = r.lastIndex;' +
    'var m = r.exec("ab12cd345");' +
    'first === 4 && m[0] === "345" && r.lastIndex === 9');
end;

procedure TRegExpMatchingTests.Exec_Failure_ResetsLastIndex;
begin
  AssertScript(
    'var r = /a/g; r.lastIndex = 1;' +
    'var m = r.exec("ab");' +
    'm === null && r.lastIndex === 0');
end;

procedure TRegExpMatchingTests.Exec_LastIndexBeyondLength_FailsAndResets;
begin
  AssertScript(
    'var r = /a?/g; r.lastIndex = 4;' +
    'var m = r.exec("abc");' +
    'm === null && r.lastIndex === 0');
end;

procedure TRegExpMatchingTests.Exec_NoArgument_MatchesTextUndefined;
begin
  AssertScript('/und/.exec()[0] === "und"');
end;

procedure TRegExpMatchingTests.Exec_ArgumentToStringThrows_PropagatesTheError;
begin
  AssertScript(
    'var caught;' +
    'try { /a/.exec({ toString: function () { throw "boom"; } }); } catch (e) { caught = e; }' +
    'caught === "boom"');
end;

procedure TRegExpMatchingTests.RegExp_Literal_HasNoOwnExecTestOrToString;
begin
  AssertScript(
    'var r = /a/;' +
    '!r.hasOwnProperty("exec") && !r.hasOwnProperty("test") && !r.hasOwnProperty("toString") &&' +
    'r.exec === RegExp.prototype.exec');
end;

procedure TRegExpMatchingTests.RegExp_Constructor_HasNoOwnExecTestOrToString;
begin
  AssertScript(
    'var r = new RegExp("a");' +
    '!r.hasOwnProperty("exec") && !r.hasOwnProperty("test") && !r.hasOwnProperty("toString") &&' +
    'r.test === RegExp.prototype.test');
end;

procedure TRegExpMatchingTests.Match_NonGlobalTrailingGroup_KeepsCaptureCount;
begin
  AssertScript(
    'var m = "Boston, MA 02134".match(/([\d]{5})([-\ ]?[\d]{4})?$/);' +
    'm.length === 3 && m[1] === "02134" && m[2] === undefined && m.index === 11');
end;

procedure TRegExpMatchingTests.Match_Global_ReturnsAllMatches;
begin
  AssertScript(
    'var r = /\d/g; r.lastIndex = 3;' +
    'var m = "a1b2c3".match(r);' +
    'm.length === 3 && m[0] === "1" && m[2] === "3" && r.lastIndex === 0');
end;

procedure TRegExpMatchingTests.Match_GlobalEmptyMatches_AdvancesPastEach;
begin
  AssertScript('"abc".match(/x*/g).length === 4');
end;

procedure TRegExpMatchingTests.Match_NoArgument_MatchesEmptyPattern;
begin
  AssertScript(
    'var m = "abc".match();' +
    'm.length === 1 && m[0] === "" && m.index === 0');
end;

procedure TRegExpMatchingTests.Search_NoArgument_ReturnsZero;
begin
  AssertScript('"".search() === 0 && "abc".search() === 0');
end;

procedure TRegExpMatchingTests.Search_StringArgument_IsTreatedAsPattern;
begin
  AssertScript('"a1b".search("\\d") === 1 && "a.b".search(".") === 0');
end;

procedure TRegExpMatchingTests.Replace_FunctionReplacement_ReceivesMatchGroupsOffsetAndString;
begin
  AssertScript(
    'var seen;' +
    '"abc12 def34".replace(/([a-z]+)([0-9]+)/, function () { seen = Array.prototype.slice.call(arguments); return "X"; });' +
    'seen.length === 5 && seen[0] === "abc12" && seen[1] === "abc" && seen[2] === "12" &&' +
    'seen[3] === 0 && seen[4] === "abc12 def34"');
end;

procedure TRegExpMatchingTests.Replace_FunctionReplacementWithStringPattern_ReceivesMatchOffsetAndString;
begin
  AssertScript(
    'var seen;' +
    'var out = "xaby".replace("ab", function () { seen = Array.prototype.slice.call(arguments); return "-"; });' +
    'out === "x-y" && seen.length === 3 && seen[0] === "ab" && seen[1] === 1 && seen[2] === "xaby"');
end;

procedure TRegExpMatchingTests.Replace_GlobalFunctionReplacement_CalledPerMatch;
begin
  AssertScript(
    '"abc12 def34".replace(/([a-z]+)([0-9]+)/g, function (all, letters, digits) { return digits + letters; })' +
    ' === "12abc 34def"');
end;

procedure TRegExpMatchingTests.Replace_DollarPatterns_AreExpanded;
begin
  AssertScript(
    '"abcde".replace(/c/, "[$`|$&|$\x27|$$]") === "ab[ab|c|de|$]de"');
end;

procedure TRegExpMatchingTests.Replace_DollarZero_StaysLiteral;
begin
  AssertScript('"x".replace(/x/, "[$0]") === "[$0]" && "x".replace(/(x)/, "[$01]") === "[x]"');
end;

procedure TRegExpMatchingTests.Replace_TwoDigitGroupReference_FallsBackToOneDigit;
begin
  AssertScript(
    '"abc".replace(/(b)/, "[$10]") === "a[b0]c" && "abc".replace(/(b)/, "[$2]") === "a[$2]c"');
end;

procedure TRegExpMatchingTests.Replace_GlobalEmptyMatches_InsertsAtEveryPosition;
begin
  AssertScript('"abc".replace(/x*/g, "-") === "-a-b-c-"');
end;

procedure TRegExpMatchingTests.Replace_StringPatternDollarAmpersand_IsExpanded;
begin
  AssertScript('"abc".replace("b", "[$&$`$\x27]") === "a[bac]c"');
end;

procedure TRegExpMatchingTests.Split_RegExpWithCaptures_SplicesCapturesIn;
begin
  AssertScript(
    'var parts = "A<B>bold</B>and<CODE>coded</CODE>".split(/<(\/)?([^<>]+)>/);' +
    'parts.length === 13 && parts[0] === "A" && parts[1] === undefined && parts[2] === "B" &&' +
    'parts[3] === "bold" && parts[4] === "/" && parts[5] === "B" && parts[12] === ""');
end;

procedure TRegExpMatchingTests.Split_AnchorAtStart_DoesNotSplit;
begin
  AssertScript('var parts = "x".split(/^/); parts.length === 1 && parts[0] === "x"');
end;

procedure TRegExpMatchingTests.Split_EmptyMatchingRegExp_SplitsIntoCharacters;
begin
  AssertScript('var parts = "abc".split(/(?:)/); parts.join("|") === "a|b|c"');
end;

procedure TRegExpMatchingTests.Split_LazyEmptyMatch_SplitsIntoCharacters;
begin
  AssertScript('"ab".split(/a*?/).join("|") === "a|b" && "ab".split(/a*/).join("|") === "|b"');
end;

procedure TRegExpMatchingTests.Split_WithLimit_StopsAtLimit;
begin
  AssertScript('"hello".split(/l/, 1).join("|") === "he" && "a,b,c".split(/,/, 2).join("|") === "a|b"');
end;

procedure TRegExpMatchingTests.Split_LimitUndefined_MeansNoLimit;
begin
  AssertScript(
    '"a,b".split(/,/, undefined).length === 2 && "a,b".split(",", void 0).length === 2 &&' +
    '"ab".split("", undefined).length === 2');
end;

procedure TRegExpMatchingTests.Split_LimitBeyondInt32_IsReducedModulo32Bits;
begin
  AssertScript(
    '"a,b".split(",", 4294967297).length === 1 && "a,b".split(",", 4294967295).length === 2 &&' +
    '"a,b".split(",", -1).length === 2');
end;

procedure TRegExpMatchingTests.Split_EmptyStringWithMatchingRegExp_ReturnsEmptyArray;
begin
  AssertScript('"".split(/(?:)/).length === 0 && "".split(/a*/).length === 0');
end;

procedure TRegExpMatchingTests.Split_EmptyStringWithNonMatchingRegExp_ReturnsTheString;
begin
  AssertScript('var parts = "".split(/a/); parts.length === 1 && parts[0] === ""');
end;

end.
