unit JS4D.Tests.StringArgumentConversion;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TStringArgumentConversionTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Slice_ObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure Slice_UndefinedEnd_MeansLength;

    [Test]
    procedure Slice_InfiniteBounds_AreClamped;

    [Test]
    procedure Substring_ObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure Substring_UndefinedEnd_MeansLength;

    [Test]
    procedure Substring_InfiniteBounds_AreClampedAndSwapped;

    [Test]
    procedure Substr_InfiniteBounds_AreClamped;

    [Test]
    procedure Substr_ObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure IndexOf_PositionObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure IndexOf_InfinitePosition_ClampsToLength;

    [Test]
    procedure IndexOf_MissingSearchString_SearchesForUndefinedText;

    [Test]
    procedure IndexOf_EmptySearchString_ReturnsClampedPosition;

    [Test]
    procedure LastIndexOf_PositionObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure LastIndexOf_NegativePosition_ClampsToZero;

    [Test]
    procedure LastIndexOf_EmptySearchString_ReturnsClampedPosition;

    [Test]
    procedure CharAt_ObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure CharAt_InfinitePosition_ReturnsEmptyString;

    [Test]
    procedure CharCodeAt_InfinitePosition_ReturnsNaN;

    [Test]
    procedure Split_LimitObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure Split_LimitAndSeparatorObjects_ConvertsLimitFirst;

    [Test]
    procedure Slice_ThrowingValueOf_PropagatesTheError;

    [Test]
    procedure Slice_ObjectConvertingToUndefined_IsNotAnOmittedEnd;

    [Test]
    procedure IndexOf_StringArgument_UsesToStringBeforeValueOf;
  end;

implementation

const
  TWO_OBJECT = 'var two = { valueOf: function() { return 2; }, toString: function() { return "x"; } };';

procedure TStringArgumentConversionTests.Slice_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    TWO_OBJECT + sLineBreak +
    '"5ABBBABAB".slice(two, 4) === "BB"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Slice_UndefinedEnd_MeansLength;
begin
  const Actual = EvaluateBoolean('"abc".slice(1, undefined) === "bc" && "abc".slice(-2) === "bc"');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Slice_InfiniteBounds_AreClamped;
begin
  const Script =
    '"abcdef".slice(NaN, Infinity) === "abcdef" && ' +
    '"abcdef".slice(-Infinity, 2) === "ab" && ' +
    '"abcdef".slice(Infinity) === "" && ' +
    '"abcdef".slice(1, -Infinity) === ""';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Substring_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    TWO_OBJECT + sLineBreak +
    '"5ABBBABAB".substring(two, 4) === "BB"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Substring_UndefinedEnd_MeansLength;
begin
  const Actual = EvaluateBoolean('"abc".substring(1, undefined) === "bc"');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Substring_InfiniteBounds_AreClampedAndSwapped;
begin
  const Script =
    '"abc".substring(NaN, Infinity) === "abc" && ' +
    '"abc".substring(Infinity, -Infinity) === "abc" && ' +
    '"abc".substring(-Infinity, 1) === "a"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Substr_InfiniteBounds_AreClamped;
begin
  const Script =
    '"abcdef".substr(-Infinity, 2) === "ab" && ' +
    '"abcdef".substr(2, Infinity) === "cdef" && ' +
    '"abcdef".substr(Infinity, 2) === "" && ' +
    '"abcdef".substr(1, undefined) === "bcdef"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Substr_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    TWO_OBJECT + sLineBreak +
    '"abcdef".substr(two, two) === "cd"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.IndexOf_PositionObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var three = { valueOf: function() { return 3; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abcabc".indexOf("c", three) === 5';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.IndexOf_InfinitePosition_ClampsToLength;
begin
  const Actual = EvaluateBoolean('"abc".indexOf("c", Infinity) === -1 && "abc".indexOf("a", -Infinity) === 0');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.IndexOf_MissingSearchString_SearchesForUndefinedText;
begin
  const Actual = EvaluateBoolean('"undefined".indexOf() === 0 && "a undefined".indexOf(undefined) === 2');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.IndexOf_EmptySearchString_ReturnsClampedPosition;
begin
  const Script =
    '"abc".indexOf("") === 0 && "abc".indexOf("", 2) === 2 && "abc".indexOf("", Infinity) === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.LastIndexOf_PositionObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var four = { valueOf: function() { return 4; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abcabc".lastIndexOf("c", four) === 2';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.LastIndexOf_NegativePosition_ClampsToZero;
begin
  const Actual = EvaluateBoolean('"abc".lastIndexOf("a", -5) === 0 && "abc".lastIndexOf("b", -Infinity) === -1');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.LastIndexOf_EmptySearchString_ReturnsClampedPosition;
begin
  const Script =
    '"abc".lastIndexOf("") === 3 && "abc".lastIndexOf("", 1) === 1 && "abc".lastIndexOf("", -4) === 0';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.CharAt_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var one = { valueOf: function() { return 1; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abc".charAt(one) === "b" && "abc".charCodeAt(one) === 98';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.CharAt_InfinitePosition_ReturnsEmptyString;
begin
  const Actual = EvaluateBoolean('"abc".charAt(Infinity) === "" && "abc".charAt(-Infinity) === ""');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.CharCodeAt_InfinitePosition_ReturnsNaN;
begin
  const Actual = EvaluateBoolean('isNaN("abc".charCodeAt(Infinity)) && isNaN("abc".charCodeAt(-Infinity))');

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Split_LimitObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    TWO_OBJECT + sLineBreak +
    '"a,b,c".split(",", two).join("|") === "a|b"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Split_LimitAndSeparatorObjects_ConvertsLimitFirst;
begin
  const Script =
    'var log = [];' + sLineBreak +
    'var separator = { toString: function() { log.push("separator"); return ","; } };' + sLineBreak +
    'var limit = { valueOf: function() { log.push("limit"); return 5; } };' + sLineBreak +
    '"a,b".split(separator, limit);' + sLineBreak +
    'log.join() === "limit,separator"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Slice_ThrowingValueOf_PropagatesTheError;
begin
  const Script =
    'var caught;' + sLineBreak +
    'try { "abc".slice({ valueOf: function() { throw "boom"; } }); } catch (e) { caught = e; }' + sLineBreak +
    'caught === "boom"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.Slice_ObjectConvertingToUndefined_IsNotAnOmittedEnd;
begin
  const Script =
    'var nothing = { valueOf: function() {} };' + sLineBreak +
    '"abc".slice(0, nothing) === ""';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringArgumentConversionTests.IndexOf_StringArgument_UsesToStringBeforeValueOf;
begin
  const Script =
    'var object = { toString: function() { return "bc"; }, valueOf: function() { return 1; } };' + sLineBreak +
    '"abcd".indexOf(object) === 1 && "abcd".concat(object) === "abcdbc"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
