unit JS4D.Tests.ArrayIterationLength;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArrayIterationLengthTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('forEach', 'forEach')]
    [TestCase('map', 'map')]
    [TestCase('filter', 'filter')]
    [TestCase('some', 'some')]
    [TestCase('every', 'every')]
    [TestCase('reduce', 'reduce')]
    [TestCase('reduceRight', 'reduceRight')]
    procedure NegativeLength_VisitsNoElements(const MethodName: string);

    [Test]
    [TestCase('forEach', 'forEach')]
    [TestCase('map', 'map')]
    [TestCase('filter', 'filter')]
    [TestCase('some', 'some')]
    [TestCase('every', 'every')]
    [TestCase('reduce', 'reduce')]
    [TestCase('reduceRight', 'reduceRight')]
    procedure LengthGetter_RunsBeforeCallbackIsValidated(const MethodName: string);

    [Test]
    [TestCase('forEach', 'forEach')]
    [TestCase('map', 'map')]
    [TestCase('filter', 'filter')]
    [TestCase('some', 'some')]
    [TestCase('every', 'every')]
    [TestCase('reduce', 'reduce')]
    [TestCase('reduceRight', 'reduceRight')]
    procedure LengthGetterThrows_PropagatesInsteadOfCallbackTypeError(const MethodName: string);

    [Test]
    [TestCase('forEach', 'forEach')]
    [TestCase('map', 'map')]
    [TestCase('filter', 'filter')]
    [TestCase('some', 'some')]
    [TestCase('every', 'every')]
    [TestCase('reduce', 'reduce')]
    [TestCase('reduceRight', 'reduceRight')]
    procedure MissingCallback_ThrowsTypeErrorAfterLengthIsRead(const MethodName: string);

    [Test]
    procedure Map_InfiniteLength_ThrowsRangeError;

    [Test]
    procedure IndexOf_NegativeLength_FindsNothing;

    [Test]
    procedure LastIndexOf_NegativeLength_FindsNothing;
  end;

implementation

procedure TArrayIterationLengthTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayIterationLengthTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayIterationLengthTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TArrayIterationLengthTests.NegativeLength_VisitsNoElements(const MethodName: string);
begin
  const Script = Format(
    'var visits = 0;' + sLineBreak +
    'var o = { 0: 1, 1: 2, length: -4294967294 };' + sLineBreak +
    'Array.prototype.%s.call(o, function () { visits++; }, 0);' + sLineBreak +
    'visits === 0',
    [MethodName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.LengthGetter_RunsBeforeCallbackIsValidated(const MethodName: string);
begin
  const Script = Format(
    'var accessed = false;' + sLineBreak +
    'var o = { 0: 11 };' + sLineBreak +
    'Object.defineProperty(o, "length", { get: function () { accessed = true; return 1; } });' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.%s.call(o, null); } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'accessed && thrown',
    [MethodName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.LengthGetterThrows_PropagatesInsteadOfCallbackTypeError(
  const MethodName: string);
begin
  const Script = Format(
    'var o = {};' + sLineBreak +
    'Object.defineProperty(o, "length", { get: function () { throw new RangeError("boom"); } });' + sLineBreak +
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.%s.call(o, undefined); } catch (e) { thrown = (e instanceof RangeError); }' + sLineBreak +
    'thrown',
    [MethodName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.MissingCallback_ThrowsTypeErrorAfterLengthIsRead(const MethodName: string);
begin
  const Script = Format(
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.%s.call({ length: 0 }); } catch (e) { thrown = (e instanceof TypeError); }' + sLineBreak +
    'thrown',
    [MethodName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.Map_InfiniteLength_ThrowsRangeError;
begin
  const Script =
    'var thrown = false;' + sLineBreak +
    'try { Array.prototype.map.call({ 0: 9, length: Infinity }, function () {}); }' + sLineBreak +
    'catch (e) { thrown = (e instanceof RangeError); }' + sLineBreak +
    'thrown';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.IndexOf_NegativeLength_FindsNothing;
begin
  const Script = 'Array.prototype.indexOf.call({ 0: 1, length: -1 }, 1) === -1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TArrayIterationLengthTests.LastIndexOf_NegativeLength_FindsNothing;
begin
  const Script = 'Array.prototype.lastIndexOf.call({ 0: 1, length: -4294967295 }, 1) === -1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
