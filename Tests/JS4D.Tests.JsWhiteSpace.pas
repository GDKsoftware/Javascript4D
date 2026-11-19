unit JS4D.Tests.JsWhiteSpace;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.JsWhiteSpace;

type
  [TestFixture]
  TJsWhiteSpaceTests = class
  public
    [Test]
    [TestCase('Space', '32,True')]
    [TestCase('Tab', '9,True')]
    [TestCase('NoBreakSpace', '160,True')]
    [TestCase('ByteOrderMark', '65279,True')]
    [TestCase('LineSeparator', '8232,True')]
    [TestCase('Letter', '97,False')]
    [TestCase('ZeroWidthSpace', '8203,False')]
    procedure IsWhiteSpace_OfCodeUnit_FollowsTheSpecification(const CodeUnit: Integer; const Expected: Boolean);

    [Test]
    procedure TrimStart_WithPaddedText_KeepsTrailingWhiteSpace;

    [Test]
    procedure TrimEnd_WithPaddedText_KeepsLeadingWhiteSpace;

    [Test]
    procedure TrimBoth_WithPaddedText_RemovesBothSides;

    [Test]
    procedure TrimBoth_WithOnlyWhiteSpace_ReturnsEmpty;
  end;

implementation

procedure TJsWhiteSpaceTests.IsWhiteSpace_OfCodeUnit_FollowsTheSpecification(const CodeUnit: Integer;
                                                                             const Expected: Boolean);
begin
  Assert.AreEqual(Expected, TJSWhiteSpace.IsWhiteSpace(Char(CodeUnit)));
end;

procedure TJsWhiteSpaceTests.TrimStart_WithPaddedText_KeepsTrailingWhiteSpace;
begin
  Assert.AreEqual('a b ', TJSWhiteSpace.TrimStart(#$FEFF + ' a b '));
end;

procedure TJsWhiteSpaceTests.TrimEnd_WithPaddedText_KeepsLeadingWhiteSpace;
begin
  Assert.AreEqual(' a b', TJSWhiteSpace.TrimEnd(' a b' + #$00A0 + #9));
end;

procedure TJsWhiteSpaceTests.TrimBoth_WithPaddedText_RemovesBothSides;
begin
  Assert.AreEqual('a b', TJSWhiteSpace.TrimBoth(#9 + ' a b ' + #$2028));
end;

procedure TJsWhiteSpaceTests.TrimBoth_WithOnlyWhiteSpace_ReturnsEmpty;
begin
  Assert.AreEqual('', TJSWhiteSpace.TrimBoth(' ' + #9 + #$3000));
end;

end.
