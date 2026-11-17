unit JS4D.Tests.GenericEs2015ArrayMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Tests.Support;

type
  [TestFixture]
  TGenericEs2015ArrayMethodTests = class(TJSEngineTestCase)
  private
    function ThrowsValue(const Statement: string; const ThrownValue: string): Boolean;

  public
    [Test]
    procedure Fill_OnArrayLike_WritesTheRangeAndReturnsThis;

    [Test]
    procedure Fill_WithoutArguments_FillsWithUndefined;

    [Test]
    procedure Fill_UndefinedEnd_MeansLength;

    [Test]
    procedure Fill_OnBooleanPrimitive_ReturnsWrapper;

    [Test]
    procedure Fill_LengthNearIntegerLimit_WritesTheLastIndices;

    [Test]
    procedure Fill_ThrowingEnd_PropagatesTheError;

    [Test]
    procedure Fill_ThrowingSetter_PropagatesTheError;

    [Test]
    procedure CopyWithin_OnArrayLike_MovesElementsAndKeepsHoles;

    [Test]
    procedure CopyWithin_EndPastLength_IsClampedToLength;

    [Test]
    procedure CopyWithin_UndefinedEnd_MeansLength;

    [Test]
    procedure CopyWithin_ThrowingStart_PropagatesTheError;

    [Test]
    procedure CopyWithin_ThrowingLength_PropagatesTheError;

    [Test]
    procedure CopyWithin_OnBooleanPrimitive_ReturnsWrapper;

    [Test]
    procedure Find_OnArrayLike_ReturnsFirstMatch;

    [Test]
    procedure Find_NotCallablePredicate_ThrowsTypeError;

    [Test]
    procedure Find_ThrowingGetter_PropagatesTheError;

    [Test]
    procedure Find_ThrowingLength_PropagatesTheError;

    [Test]
    procedure Find_VisitsHolesAsUndefined;

    [Test]
    procedure FindIndex_OnArrayLike_ReturnsFirstMatchingIndex;

    [Test]
    procedure FindIndex_NotCallablePredicate_ThrowsTypeError;

    [Test]
    procedure FindIndex_ThrowingGetter_PropagatesTheError;

    [Test]
    procedure FindIndex_UsesThisArgument;
  end;

implementation

const
  ARRAY_LIKE_OF_ONE = 'var o = { length: 1 };';
  GETTER_THROWN = 'get';
  LENGTH_THROWN = 'length';
  THROWS_VALUE_FORMAT = 'var thrown = false; try { %s } catch (e) { thrown = (e === "%s"); } thrown';

function TGenericEs2015ArrayMethodTests.ThrowsValue(const Statement: string; const ThrownValue: string): Boolean;
begin
  const Script = Format(THROWS_VALUE_FORMAT, [Statement, ThrownValue]);

  Result := EvaluateBoolean(Script);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_OnArrayLike_WritesTheRangeAndReturnsThis;
begin
  const Script =
    'var o = { length: 4 };' + sLineBreak +
    'var r = Array.prototype.fill.call(o, 7, 1, 3);' + sLineBreak +
    'r === o && !(0 in o) && o[1] === 7 && o[2] === 7 && !(3 in o)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_WithoutArguments_FillsWithUndefined;
begin
  const Script =
    'var a = [0, 0]; a.fill();' + sLineBreak +
    'a.length === 2 && a[0] === undefined && a[1] === undefined';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_UndefinedEnd_MeansLength;
begin
  const Actual = EvaluateBoolean('[0, 0].fill(1, 0, undefined).join() === "1,1"');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_OnBooleanPrimitive_ReturnsWrapper;
begin
  const Script =
    'var r = Array.prototype.fill.call(true, 1);' + sLineBreak +
    'typeof r === "object" && r.valueOf() === true';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_LengthNearIntegerLimit_WritesTheLastIndices;
begin
  const Script =
    'var o = { length: 9007199254740991 };' + sLineBreak +
    'Array.prototype.fill.call(o, "x", 9007199254740988);' + sLineBreak +
    'o[9007199254740988] === "x" && o[9007199254740990] === "x" && !(9007199254740987 in o)';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_ThrowingEnd_PropagatesTheError;
begin
  const Statement = '[].fill(1, 0, { valueOf: function() { throw "end"; } });';

  const Actual = ThrowsValue(Statement, 'end');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Fill_ThrowingSetter_PropagatesTheError;
begin
  const Statement =
    ARRAY_LIKE_OF_ONE + sLineBreak +
    'Object.defineProperty(o, "0", { set: function() { throw "set"; } });' + sLineBreak +
    'Array.prototype.fill.call(o, 1);';

  const Actual = ThrowsValue(Statement, 'set');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_OnArrayLike_MovesElementsAndKeepsHoles;
begin
  const Script =
    'var o = { 0: "a", 2: "c", length: 4 };' + sLineBreak +
    'var r = Array.prototype.copyWithin.call(o, 1, 0, 3);' + sLineBreak +
    'r === o && o[0] === "a" && o[1] === "a" && !(2 in o) && o[3] === "c"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_EndPastLength_IsClampedToLength;
begin
  const Actual = EvaluateBoolean('[0, 1, 2, 3].copyWithin(0, 1, 6).join() === "1,2,3,3"');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_UndefinedEnd_MeansLength;
begin
  const Actual = EvaluateBoolean('[0, 1, 2, 3].copyWithin(0, 1, undefined).join() === "1,2,3,3"');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_ThrowingStart_PropagatesTheError;
begin
  const Statement = '[].copyWithin(0, { valueOf: function() { throw "start"; } });';

  const Actual = ThrowsValue(Statement, 'start');

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_ThrowingLength_PropagatesTheError;
begin
  const Statement =
    'var o = { get length() { throw "length"; } };' + sLineBreak +
    'Array.prototype.copyWithin.call(o, 0);';

  const Actual = ThrowsValue(Statement, LENGTH_THROWN);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_OnBooleanPrimitive_ReturnsWrapper;
begin
  const Script =
    'var r = Array.prototype.copyWithin.call(true, 0);' + sLineBreak +
    'typeof r === "object" && r.valueOf() === true';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Find_OnArrayLike_ReturnsFirstMatch;
begin
  const Script =
    'var o = { 0: 1, 1: 5, 2: 9, length: 3 };' + sLineBreak +
    'Array.prototype.find.call(o, function(v) { return v > 3; }) === 5';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Find_NotCallablePredicate_ThrowsTypeError;
begin
  const Statement = '[].find(null);';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Find_ThrowingGetter_PropagatesTheError;
begin
  const Statement =
    ARRAY_LIKE_OF_ONE + sLineBreak +
    'Object.defineProperty(o, "0", { get: function() { throw "get"; } });' + sLineBreak +
    'Array.prototype.find.call(o, function() { return true; });';

  const Actual = ThrowsValue(Statement, GETTER_THROWN);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Find_ThrowingLength_PropagatesTheError;
begin
  const Statement =
    'var o = { get length() { throw "length"; } };' + sLineBreak +
    'Array.prototype.find.call(o, function() { return true; });';

  const Actual = ThrowsValue(Statement, LENGTH_THROWN);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.Find_VisitsHolesAsUndefined;
begin
  const Script =
    'var visited = 0;' + sLineBreak +
    '[1, , 3].find(function() { visited++; return false; });' + sLineBreak +
    'visited === 3';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_OnArrayLike_ReturnsFirstMatchingIndex;
begin
  const Script =
    'var o = { 0: 1, 1: 5, 2: 9, length: 3 };' + sLineBreak +
    'Array.prototype.findIndex.call(o, function(v) { return v > 3; }) === 1 && ' +
    'Array.prototype.findIndex.call(o, function(v) { return v > 10; }) === -1';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_NotCallablePredicate_ThrowsTypeError;
begin
  const Statement = '[].findIndex();';

  const Actual = ThrowsTypeError(Statement);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_ThrowingGetter_PropagatesTheError;
begin
  const Statement =
    ARRAY_LIKE_OF_ONE + sLineBreak +
    'Object.defineProperty(o, "0", { get: function() { throw "get"; } });' + sLineBreak +
    'Array.prototype.findIndex.call(o, function() { return true; });';

  const Actual = ThrowsValue(Statement, GETTER_THROWN);

  Assert.IsTrue(Actual);
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_UsesThisArgument;
begin
  const Script =
    'var seen;' + sLineBreak +
    '[1].findIndex(function() { seen = this.marker; return true; }, { marker: 42 });' + sLineBreak +
    'seen === 42';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

end.
