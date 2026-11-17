unit JS4D.Tests.ArrayElements;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

const
  VALUE_OF_PLUS = 'valueOf: function() { return "+"; }';
  TO_STRING_STAR = 'toString: function() { return "*"; }';

type
  [TestFixture]
  TArrayElementTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure DefineProperty_AccessorOnIndex_IsReadThroughGetter;

    [Test]
    procedure DefineProperty_AccessorOnIndex_IsWrittenThroughSetter;

    [Test]
    procedure DefineProperty_IndexBeyondLength_ExtendsLength;

    [Test]
    procedure DefineProperty_NonWritableIndex_IgnoresAssignment;

    [Test]
    procedure DefineProperty_NonWritableIndexInStrictMode_ThrowsTypeError;

    [Test]
    procedure DefineProperty_IndexWhenLengthIsNotWritable_ThrowsTypeError;

    [Test]
    procedure DefineProperty_DataOnExistingElement_KeepsOtherAttributes;

    [Test]
    procedure GetOwnPropertyDescriptor_Element_ReportsValueAndAttributes;

    [Test]
    procedure GetOwnPropertyDescriptor_Hole_IsUndefined;

    [Test]
    procedure HasOwnProperty_Element_IsTrueAndHoleIsFalse;

    [Test]
    procedure NewArrayWithLength_HasNoOwnElements;

    [Test]
    procedure GetOwnPropertyNames_ListsElementsInIndexOrder;

    [Test]
    procedure ForIn_VisitsElementsAndSkipsHoles;

    [Test]
    procedure ForIn_SkipsNonEnumerableElement;

    [Test]
    procedure Keys_SkipsHolesAndNonEnumerableElements;

    [Test]
    [TestCase('JoinUsesToString', 'new Array({' + VALUE_OF_PLUS + ', ' + TO_STRING_STAR + '}).join()#*', '#')]
    [TestCase('JoinSkipsValueOf', 'new Array({' + VALUE_OF_PLUS + '}).join()#[object Object]', '#')]
    [TestCase('JoinFallsBackToValueOf', 'new Array({' + VALUE_OF_PLUS + ', toString: function() { return {}; }}).join()#+', '#')]
    [TestCase('JoinNestedArrayElement', '[[{toString: function() { return "n"; }}], 1].join("-")#n-1', '#')]
    [TestCase('JoinSeparatorObject', '[1, 2].join({toString: function() { return "|"; }})#1|2', '#')]
    [TestCase('ToStringUsesElementToString', '[{toString: function() { return "e"; }}].toString()#e', '#')]
    [TestCase('SortUsesElementToString', 'var n = 0; var o = {toString: function() { n++; return ""; }}; [o, o].sort(); n > 1#true', '#')]
    procedure ElementConversion_CallsUserDefinedToString(const Script: string; const Expected: string);

    [Test]
    procedure ElementConversion_ThrowsTypeErrorWithoutPrimitive;

    [Test]
    procedure Hole_ReadsValueInheritedFromArrayPrototype;

    [Test]
    procedure Delete_NonConfigurableElement_ReturnsFalse;

    [Test]
    procedure LengthShrink_StopsAtNonConfigurableElement;

    [Test]
    procedure LengthShrink_RemovesConfigurableAccessorElements;

    [Test]
    procedure Seal_PreventsDeletingElements;

    [Test]
    procedure Freeze_PreventsChangingElements;

    [Test]
    procedure Freeze_ReportsElementsAsNonWritable;

    [Test]
    procedure ForEach_VisitsAccessorElement;

    [Test]
    procedure Map_SkipsHolesOfNewArray;

    [Test]
    procedure AssignLength_ObjectWithValueOf_UsesTheConvertedNumber;

    [Test]
    procedure AssignLength_ObjectWithOnlyToString_UsesTheConvertedNumber;

    [Test]
    procedure DefineProperty_LengthObjectWithValueOf_UsesTheConvertedNumber;

    [Test]
    procedure DefineProperty_LengthObjectWithoutPrimitive_ThrowsTypeErrorAfterTryingBothConversions;

    [Test]
    procedure DefineProperty_InvalidLengthOnReadOnlyLength_ThrowsRangeError;
  end;

implementation

const
  EMPTY_ARRAY_DECLARATION = 'var arr = [];';
  SINGLE_ELEMENT_ARRAY_DECLARATION = 'var arr = [1];';
  SEEN_LIST_DECLARATION = 'var seen = [];';
  DEFINE_GETTER_AT_TWO = 'Object.defineProperty(arr, "2", { get: function () { return 12; }, configurable: true });';

procedure TArrayElementTests.DefineProperty_AccessorOnIndex_IsReadThroughGetter;
begin
  const Script =
    EMPTY_ARRAY_DECLARATION + sLineBreak +
    DEFINE_GETTER_AT_TWO + sLineBreak +
    'arr[2] === 12 && arr.length === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_AccessorOnIndex_IsWrittenThroughSetter;
begin
  const Script =
    'var stored;' + sLineBreak +
    SINGLE_ELEMENT_ARRAY_DECLARATION + sLineBreak +
    'Object.defineProperty(arr, "0", { get: function () { return stored; },' +
    ' set: function (value) { stored = value * 2; }, configurable: true });' + sLineBreak +
    'arr[0] = 21;' + sLineBreak +
    'arr[0] === 42';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_IndexBeyondLength_ExtendsLength;
begin
  const Script =
    'var arr = [1, 2];' + sLineBreak +
    'Object.defineProperty(arr, "5", { value: 9, writable: true });' + sLineBreak +
    'arr.length === 6 && arr[5] === 9 && !arr.hasOwnProperty("3")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_NonWritableIndex_IgnoresAssignment;
begin
  const Script =
    SINGLE_ELEMENT_ARRAY_DECLARATION + sLineBreak +
    'Object.defineProperty(arr, "0", { value: 7, writable: false });' + sLineBreak +
    'arr[0] = 8;' + sLineBreak +
    'arr[0] === 7';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_NonWritableIndexInStrictMode_ThrowsTypeError;
begin
  const Statement =
    '(function () { "use strict"; var arr = [1];' +
    ' Object.defineProperty(arr, "0", { value: 7, writable: false }); arr[0] = 8; })();';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_IndexWhenLengthIsNotWritable_ThrowsTypeError;
begin
  const Statement =
    'var arr = [1]; Object.defineProperty(arr, "length", { writable: false });' +
    ' Object.defineProperty(arr, "1", { value: 2 });';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_DataOnExistingElement_KeepsOtherAttributes;
begin
  const Script =
    'var arr = [5];' + sLineBreak +
    'Object.defineProperty(arr, "0", { enumerable: false });' + sLineBreak +
    'var desc = Object.getOwnPropertyDescriptor(arr, "0");' + sLineBreak +
    'desc.value === 5 && desc.writable === true && desc.configurable === true && desc.enumerable === false';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.GetOwnPropertyDescriptor_Element_ReportsValueAndAttributes;
begin
  const Script =
    'var desc = Object.getOwnPropertyDescriptor(["a", "b"], "1");' + sLineBreak +
    'desc.value === "b" && desc.writable && desc.enumerable && desc.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.GetOwnPropertyDescriptor_Hole_IsUndefined;
begin
  const Actual = EvaluateBoolean('Object.getOwnPropertyDescriptor([1, , 3], "1") === undefined');

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.HasOwnProperty_Element_IsTrueAndHoleIsFalse;
begin
  const Actual = EvaluateBoolean('var arr = [1, , 3]; arr.hasOwnProperty("0") && !arr.hasOwnProperty("1")');

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.NewArrayWithLength_HasNoOwnElements;
begin
  const Script =
    'var arr = new Array(3);' + sLineBreak +
    'arr.length === 3 && !arr.hasOwnProperty("0") && !(1 in arr)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.GetOwnPropertyNames_ListsElementsInIndexOrder;
begin
  const Script =
    'var arr = [1, , 3]; arr.extra = true;' + sLineBreak +
    'Object.getOwnPropertyNames(arr).join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('0,2,length,extra', Actual);
end;

procedure TArrayElementTests.ForIn_VisitsElementsAndSkipsHoles;
begin
  const Script =
    SEEN_LIST_DECLARATION + sLineBreak +
    'for (var key in [1, , 3]) { seen.push(key); }' + sLineBreak +
    'seen.join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('0,2', Actual);
end;

procedure TArrayElementTests.ForIn_SkipsNonEnumerableElement;
begin
  const Script =
    'var arr = [1, 2, 3];' + sLineBreak +
    'Object.defineProperty(arr, "1", { enumerable: false });' + sLineBreak +
    SEEN_LIST_DECLARATION + sLineBreak +
    'for (var key in arr) { seen.push(key); }' + sLineBreak +
    'seen.join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('0,2', Actual);
end;

procedure TArrayElementTests.Keys_SkipsHolesAndNonEnumerableElements;
begin
  const Script =
    'var arr = [1, , 3, 4];' + sLineBreak +
    'Object.defineProperty(arr, "3", { enumerable: false });' + sLineBreak +
    'Object.keys(arr).join()';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('0,2', Actual);
end;

procedure TArrayElementTests.ElementConversion_CallsUserDefinedToString(const Script: string; const Expected: string);
begin
  const Actual = EvaluateText(Script);

  Assert.AreEqual(Expected, Actual);
end;

procedure TArrayElementTests.ElementConversion_ThrowsTypeErrorWithoutPrimitive;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { [{valueOf: function() { return {}; }, toString: function() { return {}; }}].join(); }' + sLineBreak +
    'catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Hole_ReadsValueInheritedFromArrayPrototype;
begin
  const Script =
    'Array.prototype[1] = "inherited";' + sLineBreak +
    'var value = [0, , 2][1];' + sLineBreak +
    'delete Array.prototype[1];' + sLineBreak +
    'value === "inherited"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Delete_NonConfigurableElement_ReturnsFalse;
begin
  const Script =
    SINGLE_ELEMENT_ARRAY_DECLARATION + sLineBreak +
    'Object.defineProperty(arr, "0", { value: 1, configurable: false });' + sLineBreak +
    'delete arr[0] === false && arr[0] === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.LengthShrink_StopsAtNonConfigurableElement;
begin
  const Script =
    'var arr = [0, 1, 2, 3];' + sLineBreak +
    'Object.defineProperty(arr, "1", { value: 1, configurable: false });' + sLineBreak +
    'arr.length = 0;' + sLineBreak +
    'arr.length === 2 && arr[1] === 1 && !arr.hasOwnProperty("2")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.LengthShrink_RemovesConfigurableAccessorElements;
begin
  const Script =
    'var arr = [0];' + sLineBreak +
    'Object.defineProperty(arr, "3", { get: function () { return 1; }, configurable: true });' + sLineBreak +
    'arr.length = 1;' + sLineBreak +
    'arr.length === 1 && arr[3] === undefined && !arr.hasOwnProperty("3")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Seal_PreventsDeletingElements;
begin
  const Script =
    'var arr = Object.seal([1, 2]);' + sLineBreak +
    'delete arr[0] === false && arr.hasOwnProperty("0") && Object.isSealed(arr)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Freeze_PreventsChangingElements;
begin
  const Script =
    'var arr = Object.freeze([1, 2]);' + sLineBreak +
    'arr[0] = 9; arr[5] = 9;' + sLineBreak +
    'arr[0] === 1 && arr.length === 2 && Object.isFrozen(arr)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Freeze_ReportsElementsAsNonWritable;
begin
  const Script =
    'var desc = Object.getOwnPropertyDescriptor(Object.freeze([1]), "0");' + sLineBreak +
    '!desc.writable && !desc.configurable && desc.enumerable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.ForEach_VisitsAccessorElement;
begin
  const Script =
    'var seen = -1;' + sLineBreak +
    EMPTY_ARRAY_DECLARATION + sLineBreak +
    DEFINE_GETTER_AT_TWO + sLineBreak +
    'arr.forEach(function (value, index) { seen = value; });' + sLineBreak +
    'seen === 12';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.Map_SkipsHolesOfNewArray;
begin
  const Script =
    'var calls = 0;' + sLineBreak +
    'var source = new Array(10);' + sLineBreak +
    'source[1] = undefined;' + sLineBreak +
    'var result = source.map(function () { calls++; return 1; });' + sLineBreak +
    'result.length === 10 && calls === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.AssignLength_ObjectWithValueOf_UsesTheConvertedNumber;
begin
  const Script =
    EMPTY_ARRAY_DECLARATION + sLineBreak +
    'arr.length = { valueOf: function () { return 2; }, toString: function () { return 1; } };' + sLineBreak +
    'arr.length === 2';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.AssignLength_ObjectWithOnlyToString_UsesTheConvertedNumber;
begin
  const Script =
    EMPTY_ARRAY_DECLARATION + sLineBreak +
    'arr.length = { toString: function () { return 3; } };' + sLineBreak +
    'arr.length === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_LengthObjectWithValueOf_UsesTheConvertedNumber;
begin
  const Script =
    EMPTY_ARRAY_DECLARATION + sLineBreak +
    'Object.defineProperty(arr, "length", { value: { valueOf: function () { return 4; } } });' + sLineBreak +
    'arr.length === 4';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_LengthObjectWithoutPrimitive_ThrowsTypeErrorAfterTryingBothConversions;
begin
  const Script =
    'var valueOfCalled = false, toStringCalled = false, thrown = false;' + sLineBreak +
    'try {' + sLineBreak +
    '  Object.defineProperty([], "length", { value: {' + sLineBreak +
    '    valueOf: function () { valueOfCalled = true; return {}; },' + sLineBreak +
    '    toString: function () { toStringCalled = true; return {}; } } });' + sLineBreak +
    '} catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown && valueOfCalled && toStringCalled';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TArrayElementTests.DefineProperty_InvalidLengthOnReadOnlyLength_ThrowsRangeError;
begin
  const Script =
    'var arr = []; var thrown = false;' + sLineBreak +
    'Object.defineProperty(arr, "length", { writable: false });' + sLineBreak +
    'try { Object.defineProperty(arr, "length", { value: -1, writable: true }); }' + sLineBreak +
    'catch (e) { thrown = (e instanceof RangeError); }' + sLineBreak +
    'thrown';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
