unit JS4D.Tests.GenericEs2015ArrayMethods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TGenericEs2015ArrayMethodTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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

procedure TGenericEs2015ArrayMethodTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TGenericEs2015ArrayMethodTests.TearDown;
begin
  FEngine.Free;
end;

function TGenericEs2015ArrayMethodTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TGenericEs2015ArrayMethodTests.Fill_OnArrayLike_WritesTheRangeAndReturnsThis;
begin
  const Script =
    'var o = { length: 4 };' + sLineBreak +
    'var r = Array.prototype.fill.call(o, 7, 1, 3);' + sLineBreak +
    'r === o && !(0 in o) && o[1] === 7 && o[2] === 7 && !(3 in o)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_WithoutArguments_FillsWithUndefined;
begin
  const Script =
    'var a = [0, 0]; a.fill();' + sLineBreak +
    'a.length === 2 && a[0] === undefined && a[1] === undefined';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_UndefinedEnd_MeansLength;
begin
  Assert.IsTrue(EvaluateBoolean('[0, 0].fill(1, 0, undefined).join() === "1,1"'));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_OnBooleanPrimitive_ReturnsWrapper;
begin
  const Script =
    'var r = Array.prototype.fill.call(true, 1);' + sLineBreak +
    'typeof r === "object" && r.valueOf() === true';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_LengthNearIntegerLimit_WritesTheLastIndices;
begin
  const Script =
    'var o = { length: 9007199254740991 };' + sLineBreak +
    'Array.prototype.fill.call(o, "x", 9007199254740988);' + sLineBreak +
    'o[9007199254740988] === "x" && o[9007199254740990] === "x" && !(9007199254740987 in o)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_ThrowingEnd_PropagatesTheError;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { [].fill(1, 0, { valueOf: function() { throw "end"; } }); } catch (e) { thrown = (e === "end"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Fill_ThrowingSetter_PropagatesTheError;
begin
  const Script =
    'var o = { length: 1 };' + sLineBreak +
    'Object.defineProperty(o, "0", { set: function() { throw "set"; } });' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.fill.call(o, 1); } catch (e) { thrown = (e === "set"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_OnArrayLike_MovesElementsAndKeepsHoles;
begin
  const Script =
    'var o = { 0: "a", 2: "c", length: 4 };' + sLineBreak +
    'var r = Array.prototype.copyWithin.call(o, 1, 0, 3);' + sLineBreak +
    'r === o && o[0] === "a" && o[1] === "a" && !(2 in o) && o[3] === "c"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_EndPastLength_IsClampedToLength;
begin
  Assert.IsTrue(EvaluateBoolean('[0, 1, 2, 3].copyWithin(0, 1, 6).join() === "1,2,3,3"'));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_UndefinedEnd_MeansLength;
begin
  Assert.IsTrue(EvaluateBoolean('[0, 1, 2, 3].copyWithin(0, 1, undefined).join() === "1,2,3,3"'));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_ThrowingStart_PropagatesTheError;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { [].copyWithin(0, { valueOf: function() { throw "start"; } }); } catch (e) { thrown = (e === "start"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_ThrowingLength_PropagatesTheError;
begin
  const Script =
    'var o = { get length() { throw "length"; } };' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.copyWithin.call(o, 0); } catch (e) { thrown = (e === "length"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.CopyWithin_OnBooleanPrimitive_ReturnsWrapper;
begin
  const Script =
    'var r = Array.prototype.copyWithin.call(true, 0);' + sLineBreak +
    'typeof r === "object" && r.valueOf() === true';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Find_OnArrayLike_ReturnsFirstMatch;
begin
  const Script =
    'var o = { 0: 1, 1: 5, 2: 9, length: 3 };' + sLineBreak +
    'Array.prototype.find.call(o, function(v) { return v > 3; }) === 5';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Find_NotCallablePredicate_ThrowsTypeError;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { [].find(null); } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Find_ThrowingGetter_PropagatesTheError;
begin
  const Script =
    'var o = { length: 1 };' + sLineBreak +
    'Object.defineProperty(o, "0", { get: function() { throw "get"; } });' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.find.call(o, function() { return true; }); } catch (e) { thrown = (e === "get"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Find_ThrowingLength_PropagatesTheError;
begin
  const Script =
    'var o = { get length() { throw "length"; } };' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.find.call(o, function() { return true; }); } catch (e) { thrown = (e === "length"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.Find_VisitsHolesAsUndefined;
begin
  const Script =
    'var visited = 0;' + sLineBreak +
    '[1, , 3].find(function() { visited++; return false; });' + sLineBreak +
    'visited === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_OnArrayLike_ReturnsFirstMatchingIndex;
begin
  const Script =
    'var o = { 0: 1, 1: 5, 2: 9, length: 3 };' + sLineBreak +
    'Array.prototype.findIndex.call(o, function(v) { return v > 3; }) === 1 && ' +
    'Array.prototype.findIndex.call(o, function(v) { return v > 10; }) === -1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_NotCallablePredicate_ThrowsTypeError;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { [].findIndex(); } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_ThrowingGetter_PropagatesTheError;
begin
  const Script =
    'var o = { length: 1 };' + sLineBreak +
    'Object.defineProperty(o, "0", { get: function() { throw "get"; } });' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.findIndex.call(o, function() { return true; }); } catch (e) { thrown = (e === "get"); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TGenericEs2015ArrayMethodTests.FindIndex_UsesThisArgument;
begin
  const Script =
    'var seen;' + sLineBreak +
    '[1].findIndex(function() { seen = this.marker; return true; }, { marker: 42 });' + sLineBreak +
    'seen === 42';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
