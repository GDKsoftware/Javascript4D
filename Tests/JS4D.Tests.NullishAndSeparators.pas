unit JS4D.Tests.NullishAndSeparators;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TNullishAndSeparatorsTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('NullLeft', 'null ?? 5#5', '#')]
    [TestCase('UndefinedLeft', 'undefined ?? 6#6', '#')]
    [TestCase('ZeroIsKept', '0 ?? 7#0', '#')]
    [TestCase('EmptyStringIsKept', '("" ?? 7).length#0', '#')]
    [TestCase('FalseIsKept', 'false ?? 7#false', '#')]
    [TestCase('Chain', 'null ?? undefined ?? 3#3', '#')]
    [TestCase('ChainStopsAtFirstValue', 'null ?? 2 ?? 3#2', '#')]
    [TestCase('RightIsNotEvaluated', 'var n = 0; 1 ?? n++; n#0', '#')]
    [TestCase('RightIsEvaluatedForNull', 'var n = 0; null ?? n++; n#1', '#')]
    [TestCase('ParenthesizedMix', '(null || 4) ?? 9#4', '#')]
    [TestCase('ParenthesizedMixRight', 'null ?? (false && 1)#false', '#')]
    [TestCase('BindsTighterThanConditional', 'null ?? 0 ? "a" : "b"#b', '#')]
    [TestCase('BindsLooserThanBitwiseOr', 'null ?? 1 | 2#3', '#')]
    [TestCase('Computed key', 'var x; var o = { 2: "two" }; o[x ?? 2]#two', '#')]
    procedure Nullish_ReturnsExpectedResult(const Source: string; const Expected: string);

    [Test]
    [TestCase('OrBefore', 'a || b ?? c')]
    [TestCase('OrAfter', 'a ?? b || c')]
    [TestCase('AndBefore', 'a && b ?? c')]
    [TestCase('AndAfter', 'a ?? b && c')]
    procedure Nullish_MixedWithLogicalOperators_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('Decimal', '1_000#1000', '#')]
    [TestCase('Fraction', '1.0_1#1.01', '#')]
    [TestCase('Exponent', '1e1_0#10000000000', '#')]
    [TestCase('Hex', '0xA_B#171', '#')]
    [TestCase('Octal', '0o1_7#15', '#')]
    [TestCase('Binary', '0b1_01#5', '#')]
    [TestCase('Many', '1_2_3#123', '#')]
    [TestCase('MemberOfLiteral', '1_0..toString()#10', '#')]
    [TestCase('ComputedKey', 'var o = { 10: "ten" }; o[1_0]#ten', '#')]
    [TestCase('StringToNumberIgnoresSeparators', 'Number("1_0")#NaN', '#')]
    procedure NumericSeparator_ReturnsExpectedResult(const Source: string; const Expected: string);

    [Test]
    [TestCase('Trailing', '1_')]
    [TestCase('Doubled', '1__0')]
    [TestCase('AfterLeadingZero', '0_1')]
    [TestCase('AfterLegacyOctal', '01_0')]
    [TestCase('AfterNonOctalDecimal', '08_1')]
    [TestCase('BeforeDot', '1_.5')]
    [TestCase('AfterDot', '1._5')]
    [TestCase('BeforeExponent', '1_e5')]
    [TestCase('AfterExponent', '1e_5')]
    [TestCase('AfterExponentSign', '1e+_5')]
    [TestCase('AfterRadixPrefix', '0x_1')]
    [TestCase('TrailingInHex', '0x1_')]
    procedure NumericSeparator_InWrongPlace_IsSyntaxError(const Source: string);
  end;

implementation

procedure TNullishAndSeparatorsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TNullishAndSeparatorsTests.TearDown;
begin
  FEngine.Free;
end;

function TNullishAndSeparatorsTests.ErrorNameOf(const Source: string): string;
begin
  const QuotesEscaped = Source.Replace('"', '\"');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [QuotesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TNullishAndSeparatorsTests.Nullish_ReturnsExpectedResult(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source).ToString;

  Assert.AreEqual(Expected, Actual);
end;

procedure TNullishAndSeparatorsTests.Nullish_MixedWithLogicalOperators_IsSyntaxError(const Source: string);
begin
  const ErrorName = ErrorNameOf(Source);

  Assert.AreEqual('SyntaxError', ErrorName);
end;

procedure TNullishAndSeparatorsTests.NumericSeparator_ReturnsExpectedResult(const Source: string;
                                                                            const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source).ToString;

  Assert.AreEqual(Expected, Actual);
end;

procedure TNullishAndSeparatorsTests.NumericSeparator_InWrongPlace_IsSyntaxError(const Source: string);
begin
  const ErrorName = ErrorNameOf(Source);

  Assert.AreEqual('SyntaxError', ErrorName);
end;

end.
