unit JS4D.Tests.LexicalStates;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.LexicalStates;

type
  [TestFixture]
  TLexicalStatesTests = class
  private
    FStates: TJSLexicalStates;

    procedure DeclareMany(const Count: Integer);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Contains_UndeclaredName_ReturnsFalse;

    [Test]
    procedure Contains_DeclaredName_ReturnsTrue;

    [Test]
    procedure EnsureInitialized_UndeclaredName_DoesNotRaise;

    [Test]
    procedure EnsureInitialized_BeforeInitialization_RaisesReferenceError;

    [Test]
    procedure EnsureInitialized_AfterInitialization_DoesNotRaise;

    [Test]
    procedure EnsureAssignable_BeforeInitialization_RaisesReferenceError;

    [Test]
    procedure EnsureAssignable_MutableAfterInitialization_DoesNotRaise;

    [Test]
    procedure EnsureAssignable_ConstantAfterInitialization_RaisesTypeError;

    [Test]
    procedure Declare_SameNameTwice_ResetsToUninitialized;

    [Test]
    procedure CopyFrom_CopiesStatesIntoEmptyInstance;

    [Test]
    procedure Clear_RemovesAllNames;

    [Test]
    procedure ManyNames_AreFoundAndTrackedIndependently;
  end;

implementation

const
  MANY_NAMES = 40;

procedure TLexicalStatesTests.Setup;
begin
  FStates := TJSLexicalStates.Create;
end;

procedure TLexicalStatesTests.TearDown;
begin
  FStates.Free;
end;

procedure TLexicalStatesTests.DeclareMany(const Count: Integer);
begin
  for var Index := 1 to Count do
  begin
    FStates.Declare(Format('name%d', [Index]), False);
  end;
end;

procedure TLexicalStatesTests.Contains_UndeclaredName_ReturnsFalse;
begin
  Assert.IsFalse(FStates.Contains('x'));
end;

procedure TLexicalStatesTests.Contains_DeclaredName_ReturnsTrue;
begin
  FStates.Declare('x', False);

  Assert.IsTrue(FStates.Contains('x'));
end;

procedure TLexicalStatesTests.EnsureInitialized_UndeclaredName_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized('x');
    end);
end;

procedure TLexicalStatesTests.EnsureInitialized_BeforeInitialization_RaisesReferenceError;
begin
  FStates.Declare('x', False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized('x');
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.EnsureInitialized_AfterInitialization_DoesNotRaise;
begin
  FStates.Declare('x', True);
  FStates.MarkInitialized('x');

  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized('x');
    end);
end;

procedure TLexicalStatesTests.EnsureAssignable_BeforeInitialization_RaisesReferenceError;
begin
  FStates.Declare('x', False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureAssignable('x');
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.EnsureAssignable_MutableAfterInitialization_DoesNotRaise;
begin
  FStates.Declare('x', False);
  FStates.MarkInitialized('x');

  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureAssignable('x');
    end);
end;

procedure TLexicalStatesTests.EnsureAssignable_ConstantAfterInitialization_RaisesTypeError;
begin
  FStates.Declare('x', True);
  FStates.MarkInitialized('x');

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureAssignable('x');
    end,
    EJSTypeError);
end;

procedure TLexicalStatesTests.Declare_SameNameTwice_ResetsToUninitialized;
begin
  FStates.Declare('x', False);
  FStates.MarkInitialized('x');
  FStates.Declare('x', False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized('x');
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.CopyFrom_CopiesStatesIntoEmptyInstance;
begin
  FStates.Declare('x', True);
  FStates.MarkInitialized('x');
  FStates.Declare('y', False);

  const Copy = TJSLexicalStates.Create;
  try
    Copy.CopyFrom(FStates);

    Assert.IsTrue(Copy.Contains('x'));
    Assert.IsTrue(Copy.Contains('y'));
    Assert.WillRaise(
      procedure
      begin
        Copy.EnsureAssignable('x');
      end,
      EJSTypeError);
    Assert.WillRaise(
      procedure
      begin
        Copy.EnsureInitialized('y');
      end,
      EJSReferenceError);
  finally
    Copy.Free;
  end;
end;

procedure TLexicalStatesTests.Clear_RemovesAllNames;
begin
  DeclareMany(MANY_NAMES);

  FStates.Clear;

  Assert.IsFalse(FStates.Contains('name1'));
  Assert.IsFalse(FStates.Contains(Format('name%d', [MANY_NAMES])));
end;

procedure TLexicalStatesTests.ManyNames_AreFoundAndTrackedIndependently;
begin
  DeclareMany(MANY_NAMES);
  FStates.MarkInitialized('name1');
  FStates.MarkInitialized(Format('name%d', [MANY_NAMES]));

  Assert.IsTrue(FStates.Contains('name20'));
  Assert.IsFalse(FStates.Contains('name41'));
  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized('name1');
      FStates.EnsureInitialized(Format('name%d', [MANY_NAMES]));
    end);
  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized('name20');
    end,
    EJSReferenceError);
end;

end.
