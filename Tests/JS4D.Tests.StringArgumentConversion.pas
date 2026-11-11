unit JS4D.Tests.StringArgumentConversion;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TStringArgumentConversionTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure Split_ConvertsLimitBeforeSeparator;

    [Test]
    procedure Slice_ThrowingValueOf_PropagatesTheError;

    [Test]
    procedure Slice_ObjectConvertingToUndefined_IsNotAnOmittedEnd;

    [Test]
    procedure IndexOf_StringArgument_UsesToStringBeforeValueOf;
  end;

implementation

procedure TStringArgumentConversionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TStringArgumentConversionTests.TearDown;
begin
  FEngine.Free;
end;

function TStringArgumentConversionTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TStringArgumentConversionTests.Slice_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var two = { valueOf: function() { return 2; }, toString: function() { return "x"; } };' + sLineBreak +
    '"5ABBBABAB".slice(two, 4) === "BB"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Slice_UndefinedEnd_MeansLength;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".slice(1, undefined) === "bc" && "abc".slice(-2) === "bc"'));
end;

procedure TStringArgumentConversionTests.Slice_InfiniteBounds_AreClamped;
begin
  const Script =
    '"abcdef".slice(NaN, Infinity) === "abcdef" && ' +
    '"abcdef".slice(-Infinity, 2) === "ab" && ' +
    '"abcdef".slice(Infinity) === "" && ' +
    '"abcdef".slice(1, -Infinity) === ""';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Substring_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var two = { valueOf: function() { return 2; }, toString: function() { return "x"; } };' + sLineBreak +
    '"5ABBBABAB".substring(two, 4) === "BB"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Substring_UndefinedEnd_MeansLength;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".substring(1, undefined) === "bc"'));
end;

procedure TStringArgumentConversionTests.Substring_InfiniteBounds_AreClampedAndSwapped;
begin
  const Script =
    '"abc".substring(NaN, Infinity) === "abc" && ' +
    '"abc".substring(Infinity, -Infinity) === "abc" && ' +
    '"abc".substring(-Infinity, 1) === "a"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Substr_InfiniteBounds_AreClamped;
begin
  const Script =
    '"abcdef".substr(-Infinity, 2) === "ab" && ' +
    '"abcdef".substr(2, Infinity) === "cdef" && ' +
    '"abcdef".substr(Infinity, 2) === "" && ' +
    '"abcdef".substr(1, undefined) === "bcdef"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Substr_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var two = { valueOf: function() { return 2; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abcdef".substr(two, two) === "cd"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.IndexOf_PositionObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var three = { valueOf: function() { return 3; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abcabc".indexOf("c", three) === 5';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.IndexOf_InfinitePosition_ClampsToLength;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".indexOf("c", Infinity) === -1 && "abc".indexOf("a", -Infinity) === 0'));
end;

procedure TStringArgumentConversionTests.IndexOf_MissingSearchString_SearchesForUndefinedText;
begin
  Assert.IsTrue(EvaluateBoolean('"undefined".indexOf() === 0 && "a undefined".indexOf(undefined) === 2'));
end;

procedure TStringArgumentConversionTests.IndexOf_EmptySearchString_ReturnsClampedPosition;
begin
  const Script =
    '"abc".indexOf("") === 0 && "abc".indexOf("", 2) === 2 && "abc".indexOf("", Infinity) === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.LastIndexOf_PositionObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var four = { valueOf: function() { return 4; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abcabc".lastIndexOf("c", four) === 2';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.LastIndexOf_NegativePosition_ClampsToZero;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".lastIndexOf("a", -5) === 0 && "abc".lastIndexOf("b", -Infinity) === -1'));
end;

procedure TStringArgumentConversionTests.LastIndexOf_EmptySearchString_ReturnsClampedPosition;
begin
  const Script =
    '"abc".lastIndexOf("") === 3 && "abc".lastIndexOf("", 1) === 1 && "abc".lastIndexOf("", -4) === 0';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.CharAt_ObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var one = { valueOf: function() { return 1; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abc".charAt(one) === "b" && "abc".charCodeAt(one) === 98';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.CharAt_InfinitePosition_ReturnsEmptyString;
begin
  Assert.IsTrue(EvaluateBoolean('"abc".charAt(Infinity) === "" && "abc".charAt(-Infinity) === ""'));
end;

procedure TStringArgumentConversionTests.CharCodeAt_InfinitePosition_ReturnsNaN;
begin
  Assert.IsTrue(EvaluateBoolean('isNaN("abc".charCodeAt(Infinity)) && isNaN("abc".charCodeAt(-Infinity))'));
end;

procedure TStringArgumentConversionTests.Split_LimitObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var two = { valueOf: function() { return 2; }, toString: function() { return "x"; } };' + sLineBreak +
    '"a,b,c".split(",", two).join("|") === "a|b"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Split_ConvertsLimitBeforeSeparator;
begin
  const Script =
    'var log = [];' + sLineBreak +
    'var separator = { toString: function() { log.push("separator"); return ","; } };' + sLineBreak +
    'var limit = { valueOf: function() { log.push("limit"); return 5; } };' + sLineBreak +
    '"a,b".split(separator, limit);' + sLineBreak +
    'log.join() === "limit,separator"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Slice_ThrowingValueOf_PropagatesTheError;
begin
  const Script =
    'var caught;' + sLineBreak +
    'try { "abc".slice({ valueOf: function() { throw "boom"; } }); } catch (e) { caught = e; }' + sLineBreak +
    'caught === "boom"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.Slice_ObjectConvertingToUndefined_IsNotAnOmittedEnd;
begin
  const Script =
    'var nothing = { valueOf: function() {} };' + sLineBreak +
    '"abc".slice(0, nothing) === ""';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStringArgumentConversionTests.IndexOf_StringArgument_UsesToStringBeforeValueOf;
begin
  const Script =
    'var object = { toString: function() { return "bc"; }, valueOf: function() { return 1; } };' + sLineBreak +
    '"abcd".indexOf(object) === 1 && "abcd".concat(object) === "abcdbc"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
