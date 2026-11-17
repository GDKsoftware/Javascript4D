unit JS4D.Tests.GenericArrayMutators;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TGenericArrayMutatorTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Push_OnObject_AppendsAndUpdatesLength;

    [Test]
    procedure Push_LengthBeyondUint32_KeepsCounting;

    [Test]
    procedure Push_InheritedLength_IsReadFromPrototype;

    [Test]
    procedure Pop_OnObject_RemovesLastElement;

    [Test]
    procedure Pop_EmptyObject_SetsLengthToZero;

    [Test]
    procedure Pop_LengthBeyondUint32_RemovesTheElementAtThatIndex;

    [Test]
    procedure Shift_OnObject_MovesElementsDown;

    [Test]
    procedure Shift_MissingElement_IsDeleted;

    [Test]
    procedure Unshift_OnObject_MovesElementsUp;

    [Test]
    procedure Splice_OnObject_RemovesAndInserts;

    [Test]
    procedure Splice_WithoutArguments_SetsLength;

    [Test]
    procedure Slice_OnObject_CopiesRange;

    [Test]
    procedure Slice_NegativeLength_ReturnsEmptyArray;

    [Test]
    procedure Reverse_OnObject_SwapsElementsAndKeepsHoles;

    [Test]
    procedure Reverse_NegativeLength_ChangesNothing;

    [Test]
    procedure Join_OnObject_UsesSeparator;

    [Test]
    procedure Join_OnBooleanPrimitive_ReturnsEmptyString;

    [Test]
    procedure Concat_OnObject_PrependsTheObjectItself;

    [Test]
    procedure Concat_OnNumberPrimitive_PrependsWrapper;

    [Test]
    procedure Sort_OnObject_SortsInPlaceAndReturnsTheObject;

    [Test]
    procedure Sort_OnObjectWithComparator_UsesComparator;

    [Test]
    procedure Sort_OnObject_MovesUndefinedToTheEndAndKeepsHolesAtTheEnd;

    [Test]
    procedure ToString_OnBooleanPrimitive_UsesObjectToString;

    [Test]
    [TestCase('Push', 'push(1)')]
    [TestCase('Pop', 'pop()')]
    [TestCase('Shift', 'shift()')]
    [TestCase('Unshift', 'unshift(1)')]
    procedure Mutator_OnFrozenArray_ThrowsTypeError(const Call: string);

    [Test]
    [TestCase('Push', 'push(1)')]
    [TestCase('Pop', 'pop()')]
    [TestCase('Shift', 'shift()')]
    [TestCase('Unshift', 'unshift(1)')]
    procedure Mutator_OnEmptyFrozenArray_ThrowsTypeError(const Call: string);

    [Test]
    [TestCase('Push', 'push(1)')]
    [TestCase('Pop', 'pop()')]
    [TestCase('Shift', 'shift()')]
    [TestCase('Unshift', 'unshift(1)')]
    procedure Mutator_OnArrayWithNonWritableLength_ThrowsTypeError(const Call: string);

    [Test]
    procedure Pop_GetterFreezesArrayWithHole_ThrowsTypeError;

    [Test]
    procedure Pop_HoleInheritedFromPrototype_ReturnsInheritedElement;

    [Test]
    procedure Shift_HoleInheritedFromPrototype_MovesInheritedElement;

    [Test]
    procedure Unshift_HoleInheritedFromPrototype_MovesInheritedElement;

    [Test]
    procedure Reverse_HoleInheritedFromPrototype_SwapsInheritedElement;

    [Test]
    procedure Slice_HoleInheritedFromPrototype_CopiesInheritedElement;

    [Test]
    procedure Splice_HoleInheritedFromPrototype_RemovesInheritedElement;

    [Test]
    procedure Join_HoleInheritedFromPrototype_UsesInheritedElement;

    [Test]
    procedure Push_PlainArray_AppendsElement;

    [Test]
    [TestCase('UndefinedEnd', 'x.slice(3, undefined).length|2', '|')]
    [TestCase('InfiniteStart', 'x.slice(Infinity, 3).length|0', '|')]
    [TestCase('InfiniteEnd', 'x.slice(0, Infinity).length|5', '|')]
    [TestCase('NegativeInfiniteStart', 'x.slice(-Infinity).length|5', '|')]
    [TestCase('ObjectEnd', 'x.slice(0, { valueOf: function () { return 3; } }).length|3', '|')]
    [TestCase('NaNStart', 'x.slice(NaN).length|5', '|')]
    [TestCase('SpliceInfiniteStart', 'x.splice(Infinity, 3).length|0', '|')]
    [TestCase('SpliceInfiniteCount', 'x.splice(0, Infinity).length|5', '|')]
    [TestCase('SpliceObjectCount', 'x.splice(0, { valueOf: function () { return 3; } }).length|3', '|')]
    [TestCase('SpliceNaNCount', 'x.splice(0, NaN).length|0', '|')]
    procedure SliceAndSplice_WithIrregularArguments_ConvertLikeToInteger(const Expression: string;
                                                                         const Expected: Integer);
    [Test]
    procedure ToString_OnObjectWithJoin_CallsJoin;

    [Test]
    procedure Unshift_GetterOnlyElement_ThrowsTypeError;

    [Test]
    procedure Splice_GetterOnlyLength_ThrowsTypeError;

    [Test]
    procedure Pop_NonConfigurableElement_ThrowsTypeError;

    [Test]
    [TestCase('push', 'push')]
    [TestCase('pop', 'pop')]
    [TestCase('shift', 'shift')]
    [TestCase('unshift', 'unshift')]
    [TestCase('splice', 'splice')]
    [TestCase('slice', 'slice')]
    [TestCase('reverse', 'reverse')]
    [TestCase('join', 'join')]
    [TestCase('concat', 'concat')]
    [TestCase('sort', 'sort')]
    procedure Method_NullThis_ThrowsTypeError(const MethodName: string);

    [Test]
    [TestCase('PushSafeLimit', 'Array.prototype.push.call(o, null)', '|')]
    [TestCase('PushAboveSafeLimit', 'o.length = Math.pow(2, 53) + 2; Array.prototype.push.call(o, null)', '|')]
    [TestCase('PushInfinity', 'o.length = Infinity; Array.prototype.push.call(o, null)', '|')]
    [TestCase('UnshiftSafeLimit', 'Array.prototype.unshift.call(o, null)', '|')]
    [TestCase('UnshiftInfinity', 'o.length = Infinity; Array.prototype.unshift.call(o, null)', '|')]
    [TestCase('SpliceInsert', 'Array.prototype.splice.call(o, 0, 0, null)', '|')]
    [TestCase('SpliceInsertInfinity', 'o.length = Infinity; Array.prototype.splice.call(o, 0, 0, null)', '|')]
    [TestCase('ConcatSpreadable', 's.length = o.length; [1].concat(s)', '|')]
    procedure ArrayLikeAtSafeIntegerLimit_GrowingMethod_ThrowsTypeError(const Statement: string);

    [Test]
    procedure Push_LengthAtSafeIntegerLimitWithoutItems_KeepsLength;

    [Test]
    procedure Splice_NoArgumentsOnHugeLength_ClampsLengthWithoutMovingElements;

    [Test]
    procedure Unshift_HugeLength_ReadsTheTopElementFirst;

    [Test]
    procedure Reverse_HugeLength_SwapsTheOutermostElementsFirst;

    [Test]
    procedure Concat_HugeSpreadableLength_ReadsIndexZeroFirst;
  end;

implementation

const
  INHERITED_ELEMENT_SETUP = 'Array.prototype[1] = 1; var x = [0]; x.length = 2;';
  STOPPED_DECLARATION = 'var stopped = false;';
  POP_ON_ARRAY_LIKE = 'var r = Array.prototype.pop.call(o);';
  ARRAY_LIKE_OF_THREE = 'var o = { 0: "a", 1: "b", 2: "c", length: 3 };';

procedure TGenericArrayMutatorTests.Push_OnObject_AppendsAndUpdatesLength;
begin
  const Script =
    'var o = { 0: "a", length: 1 };' + sLineBreak +
    'var r = Array.prototype.push.call(o, "b", "c");' + sLineBreak +
    'r === 3 && o.length === 3 && o[1] === "b" && o[2] === "c"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Push_LengthBeyondUint32_KeepsCounting;
begin
  const Script =
    'var o = { length: 4294967296 };' + sLineBreak +
    'var r = Array.prototype.push.call(o, "x", "y");' + sLineBreak +
    'r === 4294967298 && o.length === 4294967298 && o[4294967296] === "x" && ' +
    'o[4294967297] === "y" && o[0] === undefined';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Push_InheritedLength_IsReadFromPrototype;
begin
  const Script =
    'var proto = { length: 1 };' + sLineBreak +
    'var o = Object.create(proto);' + sLineBreak +
    'Array.prototype.push.call(o, 7);' + sLineBreak +
    'o[1] === 7 && o.length === 2 && proto.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_OnObject_RemovesLastElement;
begin
  const Script =
    'var o = { 0: "a", 1: "b", length: 2 };' + sLineBreak +
    POP_ON_ARRAY_LIKE + sLineBreak +
    'r === "b" && o.length === 1 && !o.hasOwnProperty("1") && o[0] === "a"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_EmptyObject_SetsLengthToZero;
begin
  const Script =
    'var o = {};' + sLineBreak +
    POP_ON_ARRAY_LIKE + sLineBreak +
    'r === undefined && o.length === 0';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_LengthBeyondUint32_RemovesTheElementAtThatIndex;
begin
  const Script =
    'var o = { length: 4294967296, 4294967295: "y" };' + sLineBreak +
    POP_ON_ARRAY_LIKE + sLineBreak +
    'r === "y" && o.length === 4294967295 && o[4294967295] === undefined';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Shift_OnObject_MovesElementsDown;
begin
  const Script =
    ARRAY_LIKE_OF_THREE + sLineBreak +
    'var r = Array.prototype.shift.call(o);' + sLineBreak +
    'r === "a" && o.length === 2 && o[0] === "b" && o[1] === "c" && !o.hasOwnProperty("2")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Shift_MissingElement_IsDeleted;
begin
  const Script =
    'var o = { 0: "a", 2: "c", length: 3 };' + sLineBreak +
    'Array.prototype.shift.call(o);' + sLineBreak +
    '!o.hasOwnProperty("0") && o[1] === "c" && o.length === 2';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Unshift_OnObject_MovesElementsUp;
begin
  const Script =
    'var o = { 0: "c", length: 1 };' + sLineBreak +
    'var r = Array.prototype.unshift.call(o, "a", "b");' + sLineBreak +
    'r === 3 && o.length === 3 && o[0] === "a" && o[1] === "b" && o[2] === "c"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Splice_OnObject_RemovesAndInserts;
begin
  const Script =
    'var o = { 0: 1, 1: 2, 2: 3, 3: 4, length: 4 };' + sLineBreak +
    'var r = Array.prototype.splice.call(o, 1, 2, "x");' + sLineBreak +
    'Array.isArray(r) && r.length === 2 && r[0] === 2 && r[1] === 3 && ' +
    'o.length === 3 && o[0] === 1 && o[1] === "x" && o[2] === 4 && !o.hasOwnProperty("3")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Splice_WithoutArguments_SetsLength;
begin
  const Script =
    'var o = { 0: "a" };' + sLineBreak +
    'var r = Array.prototype.splice.call(o);' + sLineBreak +
    'r.length === 0 && o.length === 0 && o[0] === "a"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Slice_OnObject_CopiesRange;
begin
  const Script =
    ARRAY_LIKE_OF_THREE + sLineBreak +
    'var r = Array.prototype.slice.call(o, 1);' + sLineBreak +
    'Array.isArray(r) && r.length === 2 && r[0] === "b" && r[1] === "c"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Slice_NegativeLength_ReturnsEmptyArray;
begin
  const Script =
    'var o = { 4294967294: "x", length: -1 };' + sLineBreak +
    'var r = Array.prototype.slice.call(o, 4294967294, 4294967295);' + sLineBreak +
    'r.length === 0 && r[0] === undefined';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Reverse_OnObject_SwapsElementsAndKeepsHoles;
begin
  const Script =
    'var o = { 0: "a", 2: "c", 3: "d", length: 4 };' + sLineBreak +
    'var r = Array.prototype.reverse.call(o);' + sLineBreak +
    'r === o && o[0] === "d" && o[1] === "c" && !o.hasOwnProperty("2") && o[3] === "a"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Reverse_NegativeLength_ChangesNothing;
begin
  const Script =
    'var o = { 0: "x", 1: "y", length: -4294967294 };' + sLineBreak +
    'Array.prototype.reverse.call(o);' + sLineBreak +
    'o[0] === "x" && o[1] === "y" && o.length === -4294967294';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Join_OnObject_UsesSeparator;
begin
  const Script = 'Array.prototype.join.call({ 0: "a", 1: null, 2: "c", length: 3 }, "-")';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('a--c', Actual);
end;

procedure TGenericArrayMutatorTests.Join_OnBooleanPrimitive_ReturnsEmptyString;
begin
  const Actual = EvaluateText('Array.prototype.join.call(true)');

  Assert.AreEqual('', Actual);
end;

procedure TGenericArrayMutatorTests.Concat_OnObject_PrependsTheObjectItself;
begin
  const Script =
    'var x = {};' + sLineBreak +
    'var r = Array.prototype.concat.call(x, [1, 2], 3);' + sLineBreak +
    'Array.isArray(r) && r.length === 4 && r[0] === x && r[1] === 1 && r[2] === 2 && r[3] === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Concat_OnNumberPrimitive_PrependsWrapper;
begin
  const Script =
    'var r = Array.prototype.concat.call(101);' + sLineBreak +
    'r.length === 1 && (r[0] instanceof Number)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Sort_OnObject_SortsInPlaceAndReturnsTheObject;
begin
  const Script =
    'var o = { 0: "b", 1: "c", 2: "a", length: 3 };' + sLineBreak +
    'var r = Array.prototype.sort.call(o);' + sLineBreak +
    'r === o && o[0] === "a" && o[1] === "b" && o[2] === "c"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Sort_OnObjectWithComparator_UsesComparator;
begin
  const Script =
    'var o = { 0: 1, 1: 3, 2: 2, length: 3 };' + sLineBreak +
    'Array.prototype.sort.call(o, function (a, b) { return b - a; });' + sLineBreak +
    'o[0] === 3 && o[1] === 2 && o[2] === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Sort_OnObject_MovesUndefinedToTheEndAndKeepsHolesAtTheEnd;
begin
  const Script =
    'var o = { 0: undefined, 2: "b", 3: "a", length: 4 };' + sLineBreak +
    'Array.prototype.sort.call(o);' + sLineBreak +
    'o[0] === "a" && o[1] === "b" && o.hasOwnProperty("2") && o[2] === undefined && !o.hasOwnProperty("3")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.ToString_OnBooleanPrimitive_UsesObjectToString;
begin
  const Actual = EvaluateText('Array.prototype.toString.call(true)');

  Assert.AreEqual('[object Boolean]', Actual);
end;

procedure TGenericArrayMutatorTests.ToString_OnObjectWithJoin_CallsJoin;
begin
  const Script = 'Array.prototype.toString.call({ join: function () { return "joined"; } })';

  const Actual = EvaluateText(Script);

  Assert.AreEqual('joined', Actual);
end;

procedure TGenericArrayMutatorTests.Unshift_GetterOnlyElement_ThrowsTypeError;
begin
  const Actual = ThrowsTypeError('Array.prototype.unshift.call({ get 0() { return 1; } }, 0);');

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Splice_GetterOnlyLength_ThrowsTypeError;
begin
  const Actual = ThrowsTypeError('Array.prototype.splice.call({ get length() { return 0; } }, 1, 2, 4);');

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_NonConfigurableElement_ThrowsTypeError;
begin
  const Statement =
    'var o = { length: 1 };' +
    'Object.defineProperty(o, "0", { value: "x", configurable: false });' +
    'Array.prototype.pop.call(o);';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Method_NullThis_ThrowsTypeError(const MethodName: string);
begin
  const Script = Format(
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.%s.call(null); } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown', [MethodName]);

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Mutator_OnFrozenArray_ThrowsTypeError(const Call: string);
begin
  const Actual = ThrowsTypeError(Format('Object.freeze([1, 2]).%s;', [Call]));

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Mutator_OnEmptyFrozenArray_ThrowsTypeError(const Call: string);
begin
  const Actual = ThrowsTypeError(Format('Object.freeze([]).%s;', [Call]));

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Mutator_OnArrayWithNonWritableLength_ThrowsTypeError(const Call: string);
begin
  const Statement =
    'var a = [];' +
    'Object.defineProperty(a, "length", { writable: false });' +
    Format('a.%s;', [Call]);

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_GetterFreezesArrayWithHole_ThrowsTypeError;
begin
  const Statement =
    'var a = new Array(1);' +
    'Object.defineProperty(Array.prototype, "0", { get: function () { Object.freeze(a); }, configurable: true });' +
    'a.pop();';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Pop_HoleInheritedFromPrototype_ReturnsInheritedElement;
begin
  const Script =
    INHERITED_ELEMENT_SETUP + sLineBreak +
    'x.pop() === 1 && x.length === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Shift_HoleInheritedFromPrototype_MovesInheritedElement;
begin
  const Script =
    INHERITED_ELEMENT_SETUP + sLineBreak +
    'x.shift(); x[0] === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Unshift_HoleInheritedFromPrototype_MovesInheritedElement;
begin
  const Script =
    'Array.prototype[0] = 1; var x = []; x.length = 1;' + sLineBreak +
    'x.unshift(0); x[1] === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Reverse_HoleInheritedFromPrototype_SwapsInheritedElement;
begin
  const Script =
    INHERITED_ELEMENT_SETUP + sLineBreak +
    'x.reverse(); x[0] === 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Slice_HoleInheritedFromPrototype_CopiesInheritedElement;
begin
  const Script =
    INHERITED_ELEMENT_SETUP + sLineBreak +
    'var copy = x.slice(); copy[1] === 1 && copy.hasOwnProperty("1")';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Splice_HoleInheritedFromPrototype_RemovesInheritedElement;
begin
  const Script =
    'Array.prototype[0] = -1; var x = []; x.length = 1;' + sLineBreak +
    'x.splice(0, 1)[0] === -1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Join_HoleInheritedFromPrototype_UsesInheritedElement;
begin
  const Script =
    INHERITED_ELEMENT_SETUP + sLineBreak +
    'x.join() === "0,1" && x.toString() === "0,1"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Push_PlainArray_AppendsElement;
begin
  const Actual = EvaluateBoolean('var a = [1]; a.push(2, 3) === 3 && a.join() === "1,2,3"');

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.SliceAndSplice_WithIrregularArguments_ConvertLikeToInteger(const Expression: string;
                                                                                               const Expected: Integer);
begin
  const Script = Format('var x = [0, 1, 2, 3, 4]; %s', [Expression]);

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(Double(Expected), Actual);
end;

procedure TGenericArrayMutatorTests.ArrayLikeAtSafeIntegerLimit_GrowingMethod_ThrowsTypeError(const Statement: string);
begin
  const Preamble =
    'var o = { length: Math.pow(2, 53) - 1 };' +
    'var s = {}; s[Symbol.isConcatSpreadable] = true;';

  const Actual = ThrowsTypeError(Preamble + Statement + ';');

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Push_LengthAtSafeIntegerLimitWithoutItems_KeepsLength;
begin
  const Script =
    'var o = { length: Math.pow(2, 53) - 1 };' + sLineBreak +
    'Array.prototype.push.call(o) === Math.pow(2, 53) - 1 && o.length === Math.pow(2, 53) - 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Splice_NoArgumentsOnHugeLength_ClampsLengthWithoutMovingElements;
begin
  const Script =
    'var o = { length: Math.pow(2, 53) + 2 };' + sLineBreak +
    'Array.prototype.splice.call(o);' + sLineBreak +
    'o.length === Math.pow(2, 53) - 1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Unshift_HugeLength_ReadsTheTopElementFirst;
begin
  const Script =
    STOPPED_DECLARATION + sLineBreak +
    'var o = { length: Math.pow(2, 53) - 2, get "9007199254740989"() { throw 1; } };' + sLineBreak +
    'try { Array.prototype.unshift.call(o, null); } catch (e) { stopped = (e === 1); }' + sLineBreak +
    'stopped && o.length === Math.pow(2, 53) - 2';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Reverse_HugeLength_SwapsTheOutermostElementsFirst;
begin
  const Script =
    STOPPED_DECLARATION + sLineBreak +
    'var o = { length: Math.pow(2, 53) + 2, get "9007199254740990"() { throw 1; } };' + sLineBreak +
    'try { Array.prototype.reverse.call(o); } catch (e) { stopped = (e === 1); }' + sLineBreak +
    'stopped';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericArrayMutatorTests.Concat_HugeSpreadableLength_ReadsIndexZeroFirst;
begin
  const Script =
    STOPPED_DECLARATION + sLineBreak +
    'var s = { length: Math.pow(2, 53) - 1, get 0() { throw 1; } };' + sLineBreak +
    's[Symbol.isConcatSpreadable] = true;' + sLineBreak +
    'try { [].concat(s); } catch (e) { stopped = (e === 1); }' + sLineBreak +
    'stopped';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.