unit JS4D.Tests.RegExpEngineLimits;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.PcreMatcher,
  JS4D.RegExpTranslator;

const
  UNICODE_ESCAPE = '\' + 'u';

type
  [TestFixture]
  TRegExpEngineLimitsTests = class
  public
    [Test]
    procedure TryMatch_WithCatastrophicBacktracking_RaisesRangeError;

    [Test]
    procedure TryMatch_WithPatternRejectedByPcre_RaisesSyntaxError;

    [Test]
    procedure TryMatch_StartingPastTheSubject_ReturnsFalse;

    [Test]
    procedure Translate_WithBracedEscapeOfManyLeadingZeros_ConvertsTheCodePoint;

    [Test]
    procedure Translate_WithBracedEscapeBeyondTheLastCodePoint_KeepsTheEscapeUnconverted;

    [Test]
    procedure Translate_WithBracedEscapeOfManyDigits_DoesNotRaise;

    [Test]
    [TestCase('LoneHigh', 'D83D,True')]
    [TestCase('LoneLow', 'DC00,True')]
    [TestCase('Letter', '0041,False')]
    [TestCase('NotHex', '00GG,False')]
    procedure HasSurrogateEscape_WithUnitEscape_DetectsSurrogates(const Digits: string; const Expected: Boolean);
  end;

implementation

procedure TRegExpEngineLimitsTests.TryMatch_WithCatastrophicBacktracking_RaisesRangeError;
begin
  const Matcher = TJSPcreMatcher.Create('(a+)+$', False, False, False);
  try
    Assert.WillRaise(
      procedure
      begin
        Matcher.TryMatch(StringOfChar('a', 64) + '!', 0);
      end,
      EJSRangeError);
  finally
    Matcher.Free;
  end;
end;

procedure TRegExpEngineLimitsTests.TryMatch_WithPatternRejectedByPcre_RaisesSyntaxError;
begin
  const Matcher = TJSPcreMatcher.Create('(?<same>a)(?<same>b)', False, False, False);
  try
    Assert.WillRaise(
      procedure
      begin
        Matcher.TryMatch('ab', 0);
      end,
      EJSSyntaxError);
  finally
    Matcher.Free;
  end;
end;

procedure TRegExpEngineLimitsTests.TryMatch_StartingPastTheSubject_ReturnsFalse;
begin
  const Matcher = TJSPcreMatcher.Create('a', False, False, False);
  try
    Assert.IsFalse(Matcher.TryMatch('a', 5));
  finally
    Matcher.Free;
  end;
end;

procedure TRegExpEngineLimitsTests.Translate_WithBracedEscapeOfManyLeadingZeros_ConvertsTheCodePoint;
begin
  const Pattern = UNICODE_ESCAPE + '{0000000000000041}';

  Assert.AreEqual(UNICODE_ESCAPE + '0041', TJSRegExpTranslator.Translate(Pattern, True, True));
end;

procedure TRegExpEngineLimitsTests.Translate_WithBracedEscapeBeyondTheLastCodePoint_KeepsTheEscapeUnconverted;
begin
  const Pattern = UNICODE_ESCAPE + '{110000}';

  Assert.AreEqual(Pattern, TJSRegExpTranslator.Translate(Pattern, True, True));
end;

procedure TRegExpEngineLimitsTests.Translate_WithBracedEscapeOfManyDigits_DoesNotRaise;
begin
  const Pattern = UNICODE_ESCAPE + '{FFFFFFFFFFFFFFFFFFFF}';

  Assert.WillNotRaise(
    procedure
    begin
      TJSRegExpTranslator.Translate(Pattern, True, True);
    end);
end;

procedure TRegExpEngineLimitsTests.HasSurrogateEscape_WithUnitEscape_DetectsSurrogates(const Digits: string;
                                                                                       const Expected: Boolean);
begin
  const Pattern = UNICODE_ESCAPE + Digits + 'xxxx';

  Assert.AreEqual(Expected, TJSRegExpTranslator.HasSurrogateEscape(Pattern));
end;

end.
