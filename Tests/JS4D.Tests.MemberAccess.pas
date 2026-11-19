unit JS4D.Tests.MemberAccess;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TMemberAccessTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('ReadOnUndefined', 'var u; u.x;')]
    [TestCase('ReadOnNull', 'null.x;')]
    [TestCase('ComputedReadOnUndefined', 'var u; u[0];')]
    [TestCase('AssignOnUndefined', 'var u; u.x = 1;')]
    [TestCase('MethodCallOnUndefined', 'var u; u.run();')]
    [TestCase('ChainedReadOfMissingProperty', 'var o = {}; o.a.b;')]
    procedure Member_AccessOnNullishValue_ThrowsTypeError(const Statements: string);

    [Test]
    procedure Member_ReadOnPrimitiveString_StillWorks;
  end;

implementation

procedure TMemberAccessTests.Member_AccessOnNullishValue_ThrowsTypeError(const Statements: string);
begin
  const Thrown = ThrowsTypeError(Statements);

  Assert.IsTrue(Thrown);
end;

procedure TMemberAccessTests.Member_ReadOnPrimitiveString_StillWorks;
begin
  const TextLength = EvaluateNumber('"abc".length');

  Assert.AreEqual(3.0, TextLength);
end;

end.
