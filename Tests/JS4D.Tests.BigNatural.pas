unit JS4D.Tests.BigNatural;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.BigNatural;

type
  [TestFixture]
  TBigNaturalTests = class
  public
    [Test]
    [TestCase('Zero', '0,0')]
    [TestCase('One', '1,1')]
    [TestCase('Largest32', '4294967295,32')]
    [TestCase('Smallest33', '4294967296,33')]
    [TestCase('Largest64', '18446744073709551615,64')]
    [TestCase('Smallest65', '18446744073709551616,65')]
    procedure BitLength_OfDigits_CountsTheSignificantBits(const Digits: string; const Expected: Integer);

    [Test]
    [TestCase('SameLength', '12,34,-1')]
    [TestCase('Equal', '34,34,0')]
    [TestCase('Greater', '99999999999999999999,3,1')]
    [TestCase('SameWordsLowerTail', '18446744073709551617,18446744073709551616,1')]
    procedure CompareTo_WithDigits_ReturnsTheSign(const Left: string; const Right: string; const Expected: Integer);

    [Test]
    procedure TrySubtract_WithSmallerNumber_SubtractsAcrossWords;

    [Test]
    procedure TrySubtract_WithLargerNumber_LeavesTheValueUnchanged;

    [Test]
    procedure ShiftRightOne_WithPowerOfTwoAboveOneWord_DropsOneBit;

    [Test]
    procedure MultiplyByPowerOfTen_WithLargeExponent_MatchesTheDecimalDigits;
  end;

implementation

procedure TBigNaturalTests.BitLength_OfDigits_CountsTheSignificantBits(const Digits: string; const Expected: Integer);
begin
  Assert.AreEqual(Expected, TJSBigNatural.FromDigits(Digits).BitLength);
end;

procedure TBigNaturalTests.CompareTo_WithDigits_ReturnsTheSign(const Left: string; const Right: string;
                                                               const Expected: Integer);
begin
  Assert.AreEqual(Expected, TJSBigNatural.FromDigits(Left).CompareTo(TJSBigNatural.FromDigits(Right)));
end;

procedure TBigNaturalTests.TrySubtract_WithSmallerNumber_SubtractsAcrossWords;
begin
  var Number := TJSBigNatural.FromDigits('18446744073709551616');

  Assert.IsTrue(Number.TrySubtract(TJSBigNatural.FromWord(1)));
  Assert.AreEqual(0, Number.CompareTo(TJSBigNatural.FromDigits('18446744073709551615')));
end;

procedure TBigNaturalTests.TrySubtract_WithLargerNumber_LeavesTheValueUnchanged;
begin
  var Number := TJSBigNatural.FromWord(5);

  Assert.IsFalse(Number.TrySubtract(TJSBigNatural.FromDigits('4294967296')));
  Assert.AreEqual(0, Number.CompareTo(TJSBigNatural.FromWord(5)));
end;

procedure TBigNaturalTests.ShiftRightOne_WithPowerOfTwoAboveOneWord_DropsOneBit;
begin
  var Number := TJSBigNatural.FromDigits('18446744073709551616');

  Number.ShiftRightOne;

  Assert.AreEqual(0, Number.CompareTo(TJSBigNatural.FromDigits('9223372036854775808')));
end;

procedure TBigNaturalTests.MultiplyByPowerOfTen_WithLargeExponent_MatchesTheDecimalDigits;
begin
  var Number := TJSBigNatural.FromWord(7);

  Number.MultiplyByPowerOfTen(23);

  Assert.AreEqual(0, Number.CompareTo(TJSBigNatural.FromDigits('700000000000000000000000')));
end;

end.
