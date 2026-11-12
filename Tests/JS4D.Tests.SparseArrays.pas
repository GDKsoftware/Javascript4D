unit JS4D.Tests.SparseArrays;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TSparseArrayTests = class
  private
    FEngine: TJSEngine;

    function EvaluateText(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Index past the dense range', 'var x = []; x[0] = 1; x[2147483648] = 1; x.length#2147483649', '#')]
    [TestCase('Largest index', 'var x = []; x[4294967294] = 1; x.length#4294967295', '#')]
    [TestCase('Length assignment', 'var x = []; x.length = 4294967295; x.length#4294967295', '#')]
    [TestCase('Array constructor', 'new Array(4294967295).length#4294967295', '#')]
    [TestCase('Define length', 'var x = []; Object.defineProperty(x, "length", { value: 4294967294 }); x.length#4294967294', '#')]
    [TestCase('Define largest index', 'var x = []; Object.defineProperty(x, "4294967294", { value: 100 }); x.length + "," + x.hasOwnProperty("4294967294") + "," + x[4294967294]#4294967295,true,100', '#')]
    [TestCase('Index beyond the largest is a plain property', 'var x = []; x[4294967295] = 1; x.length + "," + x[4294967295]#0,1', '#')]
    procedure Length_ForIndexesAndLengthsBeyondInt32_FollowsArrayIndexRules(const Script: string; const Expected: string);

    [Test]
    [TestCase('Length one past the maximum', 'var x = []; x.length = 4294967296#RangeError', '#')]
    [TestCase('Negative length', 'var x = []; x.length = -1#RangeError', '#')]
    [TestCase('Fractional length', 'var x = []; x.length = 1.5#RangeError', '#')]
    [TestCase('Defined length one past the maximum', 'var x = []; Object.defineProperty(x, "length", { value: 4294967296 })#RangeError', '#')]
    [TestCase('Push past the maximum', 'var x = []; x.length = 4294967295; x.push("x")#RangeError', '#')]
    procedure Length_OutsideUint32Range_ThrowsRangeError(const Script: string; const Expected: string);

    [Test]
    procedure Push_AtMaximumLength_StoresPlainPropertyBeforeThrowing;

    [Test]
    procedure Length_Shrunk_RemovesSparseElements;

    [Test]
    procedure Length_ShrunkOverNonConfigurableSparseElement_StopsAboveIt;

    [Test]
    procedure GetOwnPropertyNames_WithSparseElements_ListsIndexesBeforeLength;

    [Test]
    procedure IndexOf_StartingNearTheEnd_FindsSparseElement;

    [Test]
    procedure LastIndexOf_OnSparseArray_FindsSparseElement;

    [Test]
    procedure Length_AssignedObject_IsCoercedTwice;

    [Test]
    procedure Length_ChangedToNonWritableDuringCoercion_ThrowsTypeError;

    [Test]
    procedure Length_WithDefaultLimits_StillRaisesAllocationLimit;
  end;

implementation

procedure TSparseArrayTests.Setup;
begin
  FEngine := TJSEngine.Create;
  FEngine.MaxArrayLength := 0;
end;

procedure TSparseArrayTests.TearDown;
begin
  FEngine.Free;
end;

function TSparseArrayTests.EvaluateText(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

procedure TSparseArrayTests.Length_ForIndexesAndLengthsBeyondInt32_FollowsArrayIndexRules(const Script: string;
                                                                                           const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_OutsideUint32Range_ThrowsRangeError(const Script: string; const Expected: string);
begin
  const WrappedScript =
    'var name = "none";' + sLineBreak +
    'try { ' + Script + ' } catch (e) { name = e.name; }' + sLineBreak +
    'name';

  Assert.AreEqual(Expected, EvaluateText(WrappedScript));
end;

procedure TSparseArrayTests.Push_AtMaximumLength_StoresPlainPropertyBeforeThrowing;
begin
  const Script =
    'var x = []; x.length = 4294967295;' + sLineBreak +
    'var pushed = x.push();' + sLineBreak +
    'try { x.push("x"); } catch (e) {}' + sLineBreak +
    'pushed + "," + x[4294967295] + "," + x.length';

  Assert.AreEqual('4294967295,x,4294967295', EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_Shrunk_RemovesSparseElements;
begin
  const Script =
    'var x = [0, 1, 2]; x[4294967294] = 5; x.length = 2;' + sLineBreak +
    'x.length + "," + x[4294967294] + "," + x.hasOwnProperty("4294967294")';

  Assert.AreEqual('2,undefined,false', EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_ShrunkOverNonConfigurableSparseElement_StopsAboveIt;
begin
  const Script =
    'var x = []; x[3000000000] = 1; x[3500000000] = 2;' + sLineBreak +
    'Object.defineProperty(x, "3000000000", { configurable: false });' + sLineBreak +
    'var failed = false;' + sLineBreak +
    'try { Object.defineProperty(x, "length", { value: 10 }); } catch (e) { failed = (e instanceof TypeError); }' + sLineBreak +
    'failed + "," + x.length + "," + x.hasOwnProperty("3500000000")';

  Assert.AreEqual('true,3000000001,false', EvaluateText(Script));
end;

procedure TSparseArrayTests.GetOwnPropertyNames_WithSparseElements_ListsIndexesBeforeLength;
begin
  const Script =
    'var x = [0, 1]; x[4294967294] = 1; x[3000000000] = 1; x.name = "n";' + sLineBreak +
    'Object.getOwnPropertyNames(x).join("|")';

  Assert.AreEqual('0|1|3000000000|4294967294|length|name', EvaluateText(Script));
end;

procedure TSparseArrayTests.IndexOf_StartingNearTheEnd_FindsSparseElement;
begin
  const Script =
    'var a = [0, 1]; a[4294967294] = 2; a[4294967295] = 3; a[4294967296] = 4;' + sLineBreak +
    'a.indexOf(2, 4294967290) + "," + a.indexOf(3, 4294967290) + "," + a.indexOf(4, 4294967290)';

  Assert.AreEqual('4294967294,-1,-1', EvaluateText(Script));
end;

procedure TSparseArrayTests.LastIndexOf_OnSparseArray_FindsSparseElement;
begin
  const Script =
    'var a = [0, 1]; a[4294967294] = 2; a[4294967200] = 3;' + sLineBreak +
    'a.lastIndexOf(2) + "," + a.lastIndexOf(3)';

  Assert.AreEqual('4294967294,4294967200', EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_AssignedObject_IsCoercedTwice;
begin
  const Script =
    'var calls = 0; var x = [];' + sLineBreak +
    'x.length = { valueOf: function () { calls++; return 2; } };' + sLineBreak +
    'x.length + "," + calls';

  Assert.AreEqual('2,2', EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_ChangedToNonWritableDuringCoercion_ThrowsTypeError;
begin
  const Script =
    'var array = [1, 2]; var calls = 0;' + sLineBreak +
    'var length = { valueOf: function () {' + sLineBreak +
    '  calls++; if (calls !== 1) { Object.defineProperty(array, "length", { writable: false }); }' + sLineBreak +
    '  return array.length; } };' + sLineBreak +
    'var name = "none";' + sLineBreak +
    'try { Object.defineProperty(array, "length", { value: length, writable: true }); } catch (e) { name = e.name; }' +
    sLineBreak +
    'name + "," + calls';

  Assert.AreEqual('TypeError,2', EvaluateText(Script));
end;

procedure TSparseArrayTests.Length_WithDefaultLimits_StillRaisesAllocationLimit;
begin
  FEngine.MaxArrayLength := 1024 * 1024;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var a = []; a.length = 4294967295;');
    end,
    EJSAllocationLimitExceeded);
end;

end.
