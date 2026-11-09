unit JS4D.Tests.MemberAccess;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TMemberAccessTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Member_ReadOnUndefined_ThrowsTypeError;

    [Test]
    procedure Member_ReadOnNull_ThrowsTypeError;

    [Test]
    procedure Member_ComputedReadOnUndefined_ThrowsTypeError;

    [Test]
    procedure Member_AssignOnUndefined_ThrowsTypeError;

    [Test]
    procedure Member_MethodCallOnUndefined_ThrowsTypeError;

    [Test]
    procedure Member_ChainedReadOfMissingProperty_ThrowsTypeError;

    [Test]
    procedure Member_ReadOnPrimitiveString_StillWorks;
  end;

implementation

procedure TMemberAccessTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TMemberAccessTests.TearDown;
begin
  FEngine.Free;
end;

procedure TMemberAccessTests.Member_ReadOnUndefined_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; var u; try { u.x; } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_ReadOnNull_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; try { null.x; } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_ComputedReadOnUndefined_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; var u; try { u[0]; } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_AssignOnUndefined_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; var u; try { u.x = 1; } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_MethodCallOnUndefined_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; var u; try { u.run(); } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_ChainedReadOfMissingProperty_ThrowsTypeError;
begin
  FEngine.Execute('var caught = false; var o = {}; try { o.a.b; } catch (e) { caught = e instanceof TypeError; }');

  Assert.IsTrue(FEngine.Evaluate('caught').AsBoolean);
end;

procedure TMemberAccessTests.Member_ReadOnPrimitiveString_StillWorks;
begin
  Assert.AreEqual(3.0, FEngine.Evaluate('"abc".length').AsNumber);
end;

end.
