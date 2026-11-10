unit JS4D.Tests.ArrayElements;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArrayElementTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;
    function EvaluateText(const Script: string): string;
    function ThrowsTypeError(const Statement: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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

procedure TArrayElementTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayElementTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayElementTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

function TArrayElementTests.EvaluateText(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

function TArrayElementTests.ThrowsTypeError(const Statement: string): Boolean;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { ' + Statement + ' } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown';

  Result := EvaluateBoolean(Script);
end;

procedure TArrayElementTests.DefineProperty_AccessorOnIndex_IsReadThroughGetter;
begin
  const Script =
    'var arr = [];' + sLineBreak +
    'Object.defineProperty(arr, "2", { get: function () { return 12; }, configurable: true });' + sLineBreak +
    'arr[2] === 12 && arr.length === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_AccessorOnIndex_IsWrittenThroughSetter;
begin
  const Script =
    'var stored;' + sLineBreak +
    'var arr = [1];' + sLineBreak +
    'Object.defineProperty(arr, "0", { get: function () { return stored; },' +
    ' set: function (value) { stored = value * 2; }, configurable: true });' + sLineBreak +
    'arr[0] = 21;' + sLineBreak +
    'arr[0] === 42';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_IndexBeyondLength_ExtendsLength;
begin
  const Script =
    'var arr = [1, 2];' + sLineBreak +
    'Object.defineProperty(arr, "5", { value: 9, writable: true });' + sLineBreak +
    'arr.length === 6 && arr[5] === 9 && !arr.hasOwnProperty("3")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_NonWritableIndex_IgnoresAssignment;
begin
  const Script =
    'var arr = [1];' + sLineBreak +
    'Object.defineProperty(arr, "0", { value: 7, writable: false });' + sLineBreak +
    'arr[0] = 8;' + sLineBreak +
    'arr[0] === 7';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_NonWritableIndexInStrictMode_ThrowsTypeError;
begin
  const Statement =
    '(function () { "use strict"; var arr = [1];' +
    ' Object.defineProperty(arr, "0", { value: 7, writable: false }); arr[0] = 8; })();';

  Assert.IsTrue(ThrowsTypeError(Statement));
end;

procedure TArrayElementTests.DefineProperty_IndexWhenLengthIsNotWritable_ThrowsTypeError;
begin
  const Statement =
    'var arr = [1]; Object.defineProperty(arr, "length", { writable: false });' +
    ' Object.defineProperty(arr, "1", { value: 2 });';

  Assert.IsTrue(ThrowsTypeError(Statement));
end;

procedure TArrayElementTests.DefineProperty_DataOnExistingElement_KeepsOtherAttributes;
begin
  const Script =
    'var arr = [5];' + sLineBreak +
    'Object.defineProperty(arr, "0", { enumerable: false });' + sLineBreak +
    'var desc = Object.getOwnPropertyDescriptor(arr, "0");' + sLineBreak +
    'desc.value === 5 && desc.writable === true && desc.configurable === true && desc.enumerable === false';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.GetOwnPropertyDescriptor_Element_ReportsValueAndAttributes;
begin
  const Script =
    'var desc = Object.getOwnPropertyDescriptor(["a", "b"], "1");' + sLineBreak +
    'desc.value === "b" && desc.writable && desc.enumerable && desc.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.GetOwnPropertyDescriptor_Hole_IsUndefined;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getOwnPropertyDescriptor([1, , 3], "1") === undefined'));
end;

procedure TArrayElementTests.HasOwnProperty_Element_IsTrueAndHoleIsFalse;
begin
  Assert.IsTrue(EvaluateBoolean('var arr = [1, , 3]; arr.hasOwnProperty("0") && !arr.hasOwnProperty("1")'));
end;

procedure TArrayElementTests.NewArrayWithLength_HasNoOwnElements;
begin
  const Script =
    'var arr = new Array(3);' + sLineBreak +
    'arr.length === 3 && !arr.hasOwnProperty("0") && !(1 in arr)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.GetOwnPropertyNames_ListsElementsInIndexOrder;
begin
  const Script =
    'var arr = [1, , 3]; arr.extra = true;' + sLineBreak +
    'Object.getOwnPropertyNames(arr).join()';

  Assert.AreEqual('0,2,extra', EvaluateText(Script));
end;

procedure TArrayElementTests.ForIn_VisitsElementsAndSkipsHoles;
begin
  const Script =
    'var seen = [];' + sLineBreak +
    'for (var key in [1, , 3]) { seen.push(key); }' + sLineBreak +
    'seen.join()';

  Assert.AreEqual('0,2', EvaluateText(Script));
end;

procedure TArrayElementTests.ForIn_SkipsNonEnumerableElement;
begin
  const Script =
    'var arr = [1, 2, 3];' + sLineBreak +
    'Object.defineProperty(arr, "1", { enumerable: false });' + sLineBreak +
    'var seen = [];' + sLineBreak +
    'for (var key in arr) { seen.push(key); }' + sLineBreak +
    'seen.join()';

  Assert.AreEqual('0,2', EvaluateText(Script));
end;

procedure TArrayElementTests.Keys_SkipsHolesAndNonEnumerableElements;
begin
  const Script =
    'var arr = [1, , 3, 4];' + sLineBreak +
    'Object.defineProperty(arr, "3", { enumerable: false });' + sLineBreak +
    'Object.keys(arr).join()';

  Assert.AreEqual('0,2', EvaluateText(Script));
end;

procedure TArrayElementTests.Hole_ReadsValueInheritedFromArrayPrototype;
begin
  const Script =
    'Array.prototype[1] = "inherited";' + sLineBreak +
    'var value = [0, , 2][1];' + sLineBreak +
    'delete Array.prototype[1];' + sLineBreak +
    'value === "inherited"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.Delete_NonConfigurableElement_ReturnsFalse;
begin
  const Script =
    'var arr = [1];' + sLineBreak +
    'Object.defineProperty(arr, "0", { value: 1, configurable: false });' + sLineBreak +
    'delete arr[0] === false && arr[0] === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.LengthShrink_StopsAtNonConfigurableElement;
begin
  const Script =
    'var arr = [0, 1, 2, 3];' + sLineBreak +
    'Object.defineProperty(arr, "1", { value: 1, configurable: false });' + sLineBreak +
    'arr.length = 0;' + sLineBreak +
    'arr.length === 2 && arr[1] === 1 && !arr.hasOwnProperty("2")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.LengthShrink_RemovesConfigurableAccessorElements;
begin
  const Script =
    'var arr = [0];' + sLineBreak +
    'Object.defineProperty(arr, "3", { get: function () { return 1; }, configurable: true });' + sLineBreak +
    'arr.length = 1;' + sLineBreak +
    'arr.length === 1 && arr[3] === undefined && !arr.hasOwnProperty("3")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.Seal_PreventsDeletingElements;
begin
  const Script =
    'var arr = Object.seal([1, 2]);' + sLineBreak +
    'delete arr[0] === false && arr.hasOwnProperty("0") && Object.isSealed(arr)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.Freeze_PreventsChangingElements;
begin
  const Script =
    'var arr = Object.freeze([1, 2]);' + sLineBreak +
    'arr[0] = 9; arr[5] = 9;' + sLineBreak +
    'arr[0] === 1 && arr.length === 2 && Object.isFrozen(arr)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.Freeze_ReportsElementsAsNonWritable;
begin
  const Script =
    'var desc = Object.getOwnPropertyDescriptor(Object.freeze([1]), "0");' + sLineBreak +
    '!desc.writable && !desc.configurable && desc.enumerable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.ForEach_VisitsAccessorElement;
begin
  const Script =
    'var seen = -1;' + sLineBreak +
    'var arr = [];' + sLineBreak +
    'Object.defineProperty(arr, "2", { get: function () { return 12; }, configurable: true });' + sLineBreak +
    'arr.forEach(function (value, index) { seen = value; });' + sLineBreak +
    'seen === 12';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.Map_SkipsHolesOfNewArray;
begin
  const Script =
    'var calls = 0;' + sLineBreak +
    'var source = new Array(10);' + sLineBreak +
    'source[1] = undefined;' + sLineBreak +
    'var result = source.map(function () { calls++; return 1; });' + sLineBreak +
    'result.length === 10 && calls === 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.AssignLength_ObjectWithValueOf_UsesTheConvertedNumber;
begin
  const Script =
    'var arr = [];' + sLineBreak +
    'arr.length = { valueOf: function () { return 2; }, toString: function () { return 1; } };' + sLineBreak +
    'arr.length === 2';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.AssignLength_ObjectWithOnlyToString_UsesTheConvertedNumber;
begin
  const Script =
    'var arr = [];' + sLineBreak +
    'arr.length = { toString: function () { return 3; } };' + sLineBreak +
    'arr.length === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_LengthObjectWithValueOf_UsesTheConvertedNumber;
begin
  const Script =
    'var arr = [];' + sLineBreak +
    'Object.defineProperty(arr, "length", { value: { valueOf: function () { return 4; } } });' + sLineBreak +
    'arr.length === 4';

  Assert.IsTrue(EvaluateBoolean(Script));
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

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayElementTests.DefineProperty_InvalidLengthOnReadOnlyLength_ThrowsRangeError;
begin
  const Script =
    'var arr = []; var thrown = false;' + sLineBreak +
    'Object.defineProperty(arr, "length", { writable: false });' + sLineBreak +
    'try { Object.defineProperty(arr, "length", { value: -1, writable: true }); }' + sLineBreak +
    'catch (e) { thrown = (e instanceof RangeError); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
