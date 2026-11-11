unit JS4D.Tests.ArrayResultCreation;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArrayResultCreationTests = class
  private
    FEngine: TJSEngine;

    function ThrowsErrorNamed(const ErrorName: string; const Statement: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Concat', 'concat')]
    [TestCase('Filter', 'filter')]
    [TestCase('Map', 'map')]
    [TestCase('Slice', 'slice')]
    [TestCase('Splice', 'splice')]
    procedure Method_ConstructorIsNotAnObject_ThrowsTypeError(const MethodName: string);

    [Test]
    [TestCase('Concat', 'concat')]
    [TestCase('Filter', 'filter')]
    [TestCase('Map', 'map')]
    [TestCase('Slice', 'slice')]
    [TestCase('Splice', 'splice')]
    procedure Method_ConstructorGetterThrows_PropagatesTheError(const MethodName: string);

    [Test]
    [TestCase('Concat', 'concat')]
    [TestCase('Filter', 'filter')]
    [TestCase('Map', 'map')]
    [TestCase('Slice', 'slice')]
    [TestCase('Splice', 'splice')]
    procedure Method_ConstructorIsUndefined_ReturnsPlainArray(const MethodName: string);

    [Test]
    procedure Slice_ArrayLikeLengthBeyondArrayLimit_ThrowsRangeError;

    [Test]
    procedure Splice_ArrayLikeLengthBeyondArrayLimit_ThrowsRangeError;

    [Test]
    procedure Splice_ArrayLikeLengthBeyondArrayLimit_DoesNotWriteLength;
  end;

implementation

procedure TArrayResultCreationTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayResultCreationTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayResultCreationTests.ThrowsErrorNamed(const ErrorName: string; const Statement: string): Boolean;
begin
  const Script = Format(
    'var thrown = false;' + sLineBreak +
    'try { %s } catch (e) { thrown = (e instanceof %s); }' + sLineBreak +
    'thrown',
    [Statement, ErrorName]);

  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TArrayResultCreationTests.Method_ConstructorIsNotAnObject_ThrowsTypeError(const MethodName: string);
begin
  const Statement = Format('var a = []; a.constructor = null; a.%s(function() { return true; });', [MethodName]);

  Assert.IsTrue(ThrowsErrorNamed('TypeError', Statement));
end;

procedure TArrayResultCreationTests.Method_ConstructorGetterThrows_PropagatesTheError(const MethodName: string);
begin
  const Statement = Format(
    'var a = [];' +
    'Object.defineProperty(a, "constructor", { get: function() { throw new RangeError("poisoned"); } });' +
    'a.%s(function() { return true; });',
    [MethodName]);

  Assert.IsTrue(ThrowsErrorNamed('RangeError', Statement));
end;

procedure TArrayResultCreationTests.Method_ConstructorIsUndefined_ReturnsPlainArray(const MethodName: string);
begin
  const Script = Format(
    'var a = [1, 2]; a.constructor = undefined;' +
    'Array.isArray(a.%s(function() { return true; }))',
    [MethodName]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TArrayResultCreationTests.Slice_ArrayLikeLengthBeyondArrayLimit_ThrowsRangeError;
begin
  const Statement = 'Array.prototype.slice.call({ length: Math.pow(2, 32) });';

  Assert.IsTrue(ThrowsErrorNamed('RangeError', Statement));
end;

procedure TArrayResultCreationTests.Splice_ArrayLikeLengthBeyondArrayLimit_ThrowsRangeError;
begin
  const Statement = 'Array.prototype.splice.call({ length: Math.pow(2, 32) }, 0);';

  Assert.IsTrue(ThrowsErrorNamed('RangeError', Statement));
end;

procedure TArrayResultCreationTests.Splice_ArrayLikeLengthBeyondArrayLimit_DoesNotWriteLength;
begin
  const Script =
    'var writes = 0;' +
    'var obj = Object.defineProperty({}, "length", {' +
    '  get: function() { return Math.pow(2, 32); },' +
    '  set: function() { writes++; } });' +
    'try { Array.prototype.splice.call(obj, 0); } catch (e) {}' +
    'writes';

  Assert.AreEqual<Double>(0, FEngine.Evaluate(Script).AsNumber);
end;

end.
