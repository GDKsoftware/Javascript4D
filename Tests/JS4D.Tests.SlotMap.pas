unit JS4D.Tests.SlotMap;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  JS4D.SlotMap;

const
  FIRST_NAME = 'name0';
  SECOND_NAME = 'name1';
  THIRD_NAME = 'name2';
  MISSING_NAME = 'missing';
  NAME_FORMAT = 'name%d';
  EMPTY_PREFIX = 'name';
  EMPTY_NAME = '';

type
  [TestFixture]
  TSlotMapTests = class
  private
    FMap: TJSSlotMap<Integer>;

    function NameOf(const Index: Integer): string;
    procedure AddNames(const Count: Integer);
    procedure AssertHolds(const Name: string; const Expected: Integer);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('AtTheSearchLimit', '8')]
    [TestCase('PastTheSearchLimit', '9')]
    [TestCase('ManyNames', '40')]
    procedure TryGetValue_AfterAdding_FindsEveryName(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure TryGetValue_WithUnknownName_ReturnsFalse(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure Names_AfterAdding_KeepsInsertionOrder(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure Remove_FirstName_KeepsTheOthers(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure AddOrSetValue_WithKnownName_ReplacesValue(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure Add_WithKnownName_Raises(const Count: Integer);

    [Test]
    [TestCase('FewNames', '3')]
    [TestCase('ManyNames', '40')]
    procedure Clear_ThenAdd_StartsEmpty(const Count: Integer);

    [Test]
    procedure TryGetSlot_WithKnownName_PointsAtTheStoredValue;

    [Test]
    procedure LayoutVersion_AfterRemove_Changes;
  end;

implementation

procedure TSlotMapTests.Setup;
begin
  FMap := TJSSlotMap<Integer>.Create;
end;

procedure TSlotMapTests.TearDown;
begin
  FMap.Free;
end;

function TSlotMapTests.NameOf(const Index: Integer): string;
begin
  Result := Format(NAME_FORMAT, [Index]);
end;

procedure TSlotMapTests.AddNames(const Count: Integer);
begin
  for var Index := 0 to Count - 1 do
  begin
    FMap.Add(NameOf(Index), Index);
  end;
end;

procedure TSlotMapTests.AssertHolds(const Name: string; const Expected: Integer);
begin
  var Actual: Integer;
  Assert.IsTrue(FMap.TryGetValue(Name, Actual), Name);
  Assert.AreEqual(Expected, Actual, Name);
end;

procedure TSlotMapTests.TryGetValue_AfterAdding_FindsEveryName(const Count: Integer);
begin
  AddNames(Count);

  Assert.AreEqual(Count, FMap.Count);
  for var Index := 0 to Count - 1 do
  begin
    AssertHolds(NameOf(Index), Index);
  end;
end;

procedure TSlotMapTests.TryGetValue_WithUnknownName_ReturnsFalse(const Count: Integer);
begin
  AddNames(Count);

  var Value: Integer;
  Assert.IsFalse(FMap.TryGetValue(MISSING_NAME, Value));
  Assert.IsFalse(FMap.ContainsKey(EMPTY_PREFIX));
  Assert.IsFalse(FMap.ContainsKey(EMPTY_NAME));
end;

procedure TSlotMapTests.Names_AfterAdding_KeepsInsertionOrder(const Count: Integer);
begin
  AddNames(Count);

  const Names = FMap.Names;
  const NameCount: Integer = Length(Names);
  Assert.AreEqual(Count, NameCount);
  for var Index := 0 to Count - 1 do
  begin
    Assert.AreEqual(NameOf(Index), Names[Index]);
  end;
end;

procedure TSlotMapTests.Remove_FirstName_KeepsTheOthers(const Count: Integer);
begin
  AddNames(Count);

  FMap.Remove(FIRST_NAME);

  Assert.AreEqual(Count - 1, FMap.Count);
  Assert.IsFalse(FMap.ContainsKey(FIRST_NAME));
  for var Index := 1 to Count - 1 do
  begin
    AssertHolds(NameOf(Index), Index);
  end;
end;

procedure TSlotMapTests.AddOrSetValue_WithKnownName_ReplacesValue(const Count: Integer);
begin
  AddNames(Count);

  FMap.AddOrSetValue(SECOND_NAME, 99);

  Assert.AreEqual(Count, FMap.Count);
  AssertHolds(SECOND_NAME, 99);
end;

procedure TSlotMapTests.Add_WithKnownName_Raises(const Count: Integer);
begin
  AddNames(Count);

  Assert.WillRaise(
    procedure
    begin
      FMap.Add(SECOND_NAME, 5);
    end,
    EListError);
end;

procedure TSlotMapTests.Clear_ThenAdd_StartsEmpty(const Count: Integer);
begin
  AddNames(Count);

  FMap.Clear;
  Assert.AreEqual(0, FMap.Count);
  Assert.IsFalse(FMap.ContainsKey(FIRST_NAME));

  AddNames(Count);
  AssertHolds(FIRST_NAME, 0);
  AssertHolds(NameOf(Count - 1), Count - 1);
end;

procedure TSlotMapTests.TryGetSlot_WithKnownName_PointsAtTheStoredValue;
begin
  AddNames(3);

  var Slot: TJSSlotMap<Integer>.PSlot;
  Assert.IsTrue(FMap.TryGetSlot(THIRD_NAME, Slot));
  Slot^ := 77;

  AssertHolds(THIRD_NAME, 77);
end;

procedure TSlotMapTests.LayoutVersion_AfterRemove_Changes;
begin
  AddNames(3);
  const Before = FMap.LayoutVersion;

  FMap.Remove(SECOND_NAME);

  Assert.AreNotEqual(Before, FMap.LayoutVersion);
end;

end.
