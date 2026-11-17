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

    function ManyName(const Index: Integer): string;
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
    procedure CopyFrom_EmptyTarget_CopiesStates;

    [Test]
    procedure Clear_DeclaredNames_RemovesAll;

    [Test]
    procedure Declare_ManyNames_TracksEachIndependently;
  end;

implementation

const
  MANY_NAMES = 40;
  NAME_X = 'x';
  NAME_Y = 'y';

procedure TLexicalStatesTests.Setup;
begin
  FStates := TJSLexicalStates.Create;
end;

procedure TLexicalStatesTests.TearDown;
begin
  FStates.Free;
end;

function TLexicalStatesTests.ManyName(const Index: Integer): string;
begin
  Result := Format('name%d', [Index]);
end;

procedure TLexicalStatesTests.DeclareMany(const Count: Integer);
begin
  for var Index := 1 to Count do
  begin
    FStates.Declare(ManyName(Index), False);
  end;
end;

procedure TLexicalStatesTests.Contains_UndeclaredName_ReturnsFalse;
begin
  const Actual = FStates.Contains(NAME_X);

  Assert.IsFalse(Actual);
end;

procedure TLexicalStatesTests.Contains_DeclaredName_ReturnsTrue;
begin
  FStates.Declare(NAME_X, False);

  const Actual = FStates.Contains(NAME_X);

  Assert.IsTrue(Actual);
end;

procedure TLexicalStatesTests.EnsureInitialized_UndeclaredName_DoesNotRaise;
begin
  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized(NAME_X);
    end);
end;

procedure TLexicalStatesTests.EnsureInitialized_BeforeInitialization_RaisesReferenceError;
begin
  FStates.Declare(NAME_X, False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized(NAME_X);
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.EnsureInitialized_AfterInitialization_DoesNotRaise;
begin
  FStates.Declare(NAME_X, True);
  FStates.MarkInitialized(NAME_X);

  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized(NAME_X);
    end);
end;

procedure TLexicalStatesTests.EnsureAssignable_BeforeInitialization_RaisesReferenceError;
begin
  FStates.Declare(NAME_X, False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureAssignable(NAME_X);
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.EnsureAssignable_MutableAfterInitialization_DoesNotRaise;
begin
  FStates.Declare(NAME_X, False);
  FStates.MarkInitialized(NAME_X);

  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureAssignable(NAME_X);
    end);
end;

procedure TLexicalStatesTests.EnsureAssignable_ConstantAfterInitialization_RaisesTypeError;
begin
  FStates.Declare(NAME_X, True);
  FStates.MarkInitialized(NAME_X);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureAssignable(NAME_X);
    end,
    EJSTypeError);
end;

procedure TLexicalStatesTests.Declare_SameNameTwice_ResetsToUninitialized;
begin
  FStates.Declare(NAME_X, False);
  FStates.MarkInitialized(NAME_X);
  FStates.Declare(NAME_X, False);

  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized(NAME_X);
    end,
    EJSReferenceError);
end;

procedure TLexicalStatesTests.CopyFrom_EmptyTarget_CopiesStates;
begin
  FStates.Declare(NAME_X, True);
  FStates.MarkInitialized(NAME_X);
  FStates.Declare(NAME_Y, False);

  const CopiedStates = TJSLexicalStates.Create;
  try
    CopiedStates.CopyFrom(FStates);

    const ContainsX = CopiedStates.Contains(NAME_X);
    const ContainsY = CopiedStates.Contains(NAME_Y);

    Assert.IsTrue(ContainsX);
    Assert.IsTrue(ContainsY);
    Assert.WillRaise(
      procedure
      begin
        CopiedStates.EnsureAssignable(NAME_X);
      end,
      EJSTypeError);
    Assert.WillRaise(
      procedure
      begin
        CopiedStates.EnsureInitialized(NAME_Y);
      end,
      EJSReferenceError);
  finally
    CopiedStates.Free;
  end;
end;

procedure TLexicalStatesTests.Clear_DeclaredNames_RemovesAll;
begin
  DeclareMany(MANY_NAMES);

  FStates.Clear;

  const ContainsFirst = FStates.Contains(ManyName(1));
  const ContainsLast = FStates.Contains(ManyName(MANY_NAMES));

  Assert.IsFalse(ContainsFirst);
  Assert.IsFalse(ContainsLast);
end;

procedure TLexicalStatesTests.Declare_ManyNames_TracksEachIndependently;
begin
  const FirstName = ManyName(1);
  const MiddleName = ManyName(MANY_NAMES div 2);
  const LastName = ManyName(MANY_NAMES);
  const UndeclaredName = ManyName(MANY_NAMES + 1);

  DeclareMany(MANY_NAMES);
  FStates.MarkInitialized(FirstName);
  FStates.MarkInitialized(LastName);

  const ContainsMiddle = FStates.Contains(MiddleName);
  const ContainsUndeclared = FStates.Contains(UndeclaredName);

  Assert.IsTrue(ContainsMiddle);
  Assert.IsFalse(ContainsUndeclared);
  Assert.WillNotRaise(
    procedure
    begin
      FStates.EnsureInitialized(FirstName);
      FStates.EnsureInitialized(LastName);
    end);
  Assert.WillRaise(
    procedure
    begin
      FStates.EnsureInitialized(MiddleName);
    end,
    EJSReferenceError);
end;

end.
