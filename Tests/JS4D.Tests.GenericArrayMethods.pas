unit JS4D.Tests.GenericArrayMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TGenericArrayMethodTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Reduce_OnArrayLikeObject_SumsElements;

    [Test]
    procedure Reduce_OnArrayLikeObject_WithInitialValue;

    [Test]
    procedure Reduce_EmptyWithoutInitialValue_ThrowsTypeError;

    [Test]
    procedure Reduce_SkipsMissingIndices;

    [Test]
    procedure ReduceRight_OnArrayLikeObject_VisitsFromTheEnd;

    [Test]
    procedure ForEach_ReceivesOriginalObjectAsThirdArgument;

    [Test]
    procedure ForEach_ReadsLengthFromStringValue;

    [Test]
    procedure ForEach_SkipsMissingIndices;

    [Test]
    procedure ForEach_ElementsRemovedDuringIteration_AreNotVisited;

    [Test]
    procedure Map_OnArrayLikeObject_ReturnsArrayOfSameLength;

    [Test]
    procedure Filter_OnArrayLikeObject_KeepsMatching;

    [Test]
    procedure Some_OnArrayLikeObject_FindsMatch;

    [Test]
    procedure Every_OnArrayLikeObject_ChecksAllPresent;

    [Test]
    procedure IndexOf_OnArrayLikeObject_FindsElement;

    [Test]
    procedure IndexOf_NegativeFromIndex_CountsFromTheEnd;

    [Test]
    procedure IndexOf_UsesStrictEquality;

    [Test]
    procedure LastIndexOf_OnArrayLikeObject_FindsLastElement;

    [Test]
    procedure LastIndexOf_FromIndex_LimitsSearch;

    [Test]
    [TestCase('ForEachNonCallableCallback', '[1].forEach(1);', '#')]
    [TestCase('MapNonCallableCallback', '[1].map({});', '#')]
    [TestCase('FilterNonCallableCallback', '[1].filter(undefined);', '#')]
    [TestCase('SomeNonCallableCallback', '[1].some("x");', '#')]
    [TestCase('EveryNonCallableCallback', '[1].every(null);', '#')]
    [TestCase('ReduceNonCallableCallback', '[1].reduce(1, 0);', '#')]
    [TestCase('ReduceRightNonCallableCallback', '[1].reduceRight(1, 0);', '#')]
    [TestCase('ForEachNullThis', 'Array.prototype.forEach.call(null, function () {});', '#')]
    [TestCase('IndexOfUndefinedThis', 'Array.prototype.indexOf.call(undefined, 1);', '#')]
    procedure Method_NonCallableCallbackOrNullishThis_ThrowsTypeError(const Statement: string);

    [Test]
    procedure ForEach_ThisArgIsPassedToCallback;

    [Test]
    [TestCase('forEach', 'forEach')]
    [TestCase('map', 'map')]
    [TestCase('filter', 'filter')]
    [TestCase('some', 'some')]
    [TestCase('every', 'every')]
    procedure Callback_PrimitiveThisArgInSloppyCode_IsBoxed(const MethodName: string);

    [Test]
    procedure Callback_UndefinedThisArgInSloppyCode_IsGlobalObject;

    [Test]
    procedure Delete_ArrayElement_ReadsAsUndefined;

    [Test]
    procedure ForEach_DeletedArrayElement_IsSkipped;

    [Test]
    procedure ForEach_ArrayWithGap_SkipsTheGap;

    [Test]
    procedure IndexOf_DeletedArrayElement_FallsBackToPrototype;

    [Test]
    procedure ForEach_ObjectLength_IsConvertedWithValueOf;

    [Test]
    procedure ForEach_UnconvertibleLength_ThrowsTypeError;
  end;

implementation

const
  ARRAY_LIKE_OF_THREE_NUMBERS = 'var o = { 0: 1, 1: 2, 2: 3, length: 3 };';
  DELETE_SECOND_ELEMENT = 'delete a[1];';
  COUNT_START = 'var count = 0;';
  COUNT_VISITS_OF_OBJECT = 'Array.prototype.forEach.call(o, function () { count++; });';
  COUNT_VISITS_OF_ARRAY = 'a.forEach(function () { count++; });';
  ARRAY_LIKE_OF_TWO = 'var o = { 0: 1, 1: 2, length: 2 };';

procedure TGenericArrayMethodTests.Reduce_OnArrayLikeObject_SumsElements;
begin
  const Script =
    ARRAY_LIKE_OF_THREE_NUMBERS + sLineBreak +
    'Array.prototype.reduce.call(o, function (a, b) { return a + b; })';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(6.0, Actual);
end;

procedure TGenericArrayMethodTests.Reduce_OnArrayLikeObject_WithInitialValue;
begin
  const Script =
    ARRAY_LIKE_OF_TWO + sLineBreak +
    'Array.prototype.reduce.call(o, function (a, b) { return a + b; }, 10)';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(13.0, Actual);
end;

procedure TGenericArrayMethodTests.Reduce_EmptyWithoutInitialValue_ThrowsTypeError;
begin
  const Actual = ThrowsTypeError('Array.prototype.reduce.call({ length: 0 }, function () {});');

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Reduce_SkipsMissingIndices;
begin
  const Script =
    'var o = { 1: 5, 3: 7, length: 4 };' + sLineBreak +
    'Array.prototype.reduce.call(o, function (a, b) { return a + b; })';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(12.0, Actual);
end;

procedure TGenericArrayMethodTests.ReduceRight_OnArrayLikeObject_VisitsFromTheEnd;
begin
  const Script =
    'var o = { 0: "a", 1: "b", 2: "c", length: 3 };' + sLineBreak +
    'Array.prototype.reduceRight.call(o, function (a, b) { return a + b; }) === "cba"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.ForEach_ReceivesOriginalObjectAsThirdArgument;
begin
  const Script =
    'var o = { 0: 1, length: 1 };' + sLineBreak +
    'var same = false;' + sLineBreak +
    'Array.prototype.forEach.call(o, function (v, i, obj) { same = (obj === o); });' + sLineBreak +
    'same';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.ForEach_ReadsLengthFromStringValue;
begin
  const Script =
    'var o = { 0: 1, 1: 1, 2: 1, length: "2" };' + sLineBreak +
    COUNT_START + sLineBreak +
    COUNT_VISITS_OF_OBJECT + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.ForEach_SkipsMissingIndices;
begin
  const Script =
    'var o = { 0: 1, 2: 1, length: 3 };' + sLineBreak +
    COUNT_START + sLineBreak +
    COUNT_VISITS_OF_OBJECT + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.ForEach_ElementsRemovedDuringIteration_AreNotVisited;
begin
  const Script =
    'var a = [1, 2, 3, 4];' + sLineBreak +
    COUNT_START + sLineBreak +
    'a.forEach(function () { count++; a.pop(); });' + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.Map_OnArrayLikeObject_ReturnsArrayOfSameLength;
begin
  const Script =
    'var o = { 0: 1, 1: 2, length: 3 };' + sLineBreak +
    'var r = Array.prototype.map.call(o, function (v) { return v * 2; });' + sLineBreak +
    'r.length === 3 && r[0] === 2 && r[1] === 4';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Filter_OnArrayLikeObject_KeepsMatching;
begin
  const Script =
    ARRAY_LIKE_OF_THREE_NUMBERS + sLineBreak +
    'var r = Array.prototype.filter.call(o, function (v) { return v > 1; });' + sLineBreak +
    'r.length === 2 && r[0] === 2 && r[1] === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Some_OnArrayLikeObject_FindsMatch;
begin
  const Script =
    ARRAY_LIKE_OF_TWO + sLineBreak +
    'Array.prototype.some.call(o, function (v) { return v === 2; })';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Every_OnArrayLikeObject_ChecksAllPresent;
begin
  const Script =
    'var o = { 0: 2, 2: 4, length: 3 };' + sLineBreak +
    'Array.prototype.every.call(o, function (v) { return v % 2 === 0; })';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.IndexOf_OnArrayLikeObject_FindsElement;
begin
  const Script =
    'var o = { 0: "a", 1: "b", length: 2 };' + sLineBreak +
    'Array.prototype.indexOf.call(o, "b")';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TGenericArrayMethodTests.IndexOf_NegativeFromIndex_CountsFromTheEnd;
begin
  const Script =
    'var a = [1, 2, 1, 2];' + sLineBreak +
    'a.indexOf(1, -2)';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.IndexOf_UsesStrictEquality;
begin
  const Actual = EvaluateNumber('[1, 2, 3].indexOf("2")');

  Assert.AreEqual(-1.0, Actual);
end;

procedure TGenericArrayMethodTests.LastIndexOf_OnArrayLikeObject_FindsLastElement;
begin
  const Script =
    'var o = { 0: 1, 1: 2, 2: 1, length: 3 };' + sLineBreak +
    'Array.prototype.lastIndexOf.call(o, 1)';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.LastIndexOf_FromIndex_LimitsSearch;
begin
  const Actual = EvaluateNumber('[1, 2, 1].lastIndexOf(1, 1)');

  Assert.AreEqual(0.0, Actual);
end;

procedure TGenericArrayMethodTests.Method_NonCallableCallbackOrNullishThis_ThrowsTypeError(const Statement: string);
begin
  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual, Statement);
end;

procedure TGenericArrayMethodTests.ForEach_ThisArgIsPassedToCallback;
begin
  const Script =
    'var ctx = { n: 5 };' + sLineBreak +
    'var seen = 0;' + sLineBreak +
    'Array.prototype.forEach.call({ 0: 1, length: 1 }, function () { seen = this.n; }, ctx);' + sLineBreak +
    'seen';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(5.0, Actual);
end;

procedure TGenericArrayMethodTests.Callback_PrimitiveThisArgInSloppyCode_IsBoxed(const MethodName: string);
begin
  const Script = Format(
    'var boxed = false;' + sLineBreak +
    '[1].%s(function () { boxed = (typeof this === "object") && (this.valueOf() === false); }, false);' + sLineBreak +
    'boxed', [MethodName]);

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Callback_UndefinedThisArgInSloppyCode_IsGlobalObject;
begin
  const Script =
    'var seenGlobal = false;' + sLineBreak +
    '[1].forEach(function () { seenGlobal = (this === (function () { return this; })()); });' + sLineBreak +
    'seenGlobal';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.Delete_ArrayElement_ReadsAsUndefined;
begin
  const Script =
    'var a = ["x", "y"];' + sLineBreak +
    'delete a[0];' + sLineBreak +
    'a[0] === undefined && a.length === 2 && a.indexOf("x") === -1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMethodTests.ForEach_DeletedArrayElement_IsSkipped;
begin
  const Script =
    'var a = [1, 2, 3];' + sLineBreak +
    DELETE_SECOND_ELEMENT + sLineBreak +
    COUNT_START + sLineBreak +
    COUNT_VISITS_OF_ARRAY + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.ForEach_ArrayWithGap_SkipsTheGap;
begin
  const Script =
    'var a = [];' + sLineBreak +
    'a[3] = "x";' + sLineBreak +
    COUNT_START + sLineBreak +
    COUNT_VISITS_OF_ARRAY + sLineBreak +
    'count * 10 + a.length';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(14.0, Actual);
end;

procedure TGenericArrayMethodTests.IndexOf_DeletedArrayElement_FallsBackToPrototype;
begin
  const Script =
    'Array.prototype[1] = "inherited";' + sLineBreak +
    'var a = ["a", "b"];' + sLineBreak +
    DELETE_SECOND_ELEMENT + sLineBreak +
    'var seen = a.indexOf("inherited");' + sLineBreak +
    'delete Array.prototype[1];' + sLineBreak +
    'seen';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(1.0, Actual);
end;

procedure TGenericArrayMethodTests.ForEach_ObjectLength_IsConvertedWithValueOf;
begin
  const Script =
    'var o = { 0: 1, 1: 1, 2: 1, length: { valueOf: function () { return 2; } } };' + sLineBreak +
    COUNT_START + sLineBreak +
    COUNT_VISITS_OF_OBJECT + sLineBreak +
    'count';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(2.0, Actual);
end;

procedure TGenericArrayMethodTests.ForEach_UnconvertibleLength_ThrowsTypeError;
begin
  const Statement =
    'var o = { length: { valueOf: function () { return {}; }, toString: function () { return {}; } } };' +
    'Array.prototype.forEach.call(o, function () {});';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

end.
