unit JS4D.Tests.StringEs2015Methods;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TStringEs2015MethodsTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('Single code unit', 'abc,1,98')]
    [TestCase('Surrogate pair', '\uD83D\uDE00,0,128512')]
    [TestCase('Trail surrogate position', '\uD83D\uDE00,1,56832')]
    [TestCase('Lone lead surrogate', '\uD83Dx,0,55357')]
    [TestCase('Fractional position', 'abc,1.9,98')]
    [TestCase('Position past the end', 'abc,3,-1')]
    [TestCase('Negative position', 'abc,-1,-1')]
    procedure CodePointAt_Positions_ReturnsExpected(const Text: string; const Position: string; const Expected: Integer);

    [Test]
    procedure CodePointAt_MissingPosition_UsesZero;

    [Test]
    procedure CodePointAt_PositionObjectWithValueOf_ConvertsToNumber;

    [Test]
    procedure CodePointAt_ThisNull_ThrowsTypeError;

    [Test]
    procedure CodePointAt_Method_HasLengthOne;

    [Test]
    [TestCase('NFC', '\u1E9B\u0323,NFC,\u1E9B\u0323')]
    [TestCase('NFD', '\u1E9B\u0323,NFD,\u017F\u0323\u0307')]
    [TestCase('NFKC', '\u1E9B\u0323,NFKC,\u1E69')]
    [TestCase('NFKD', '\u1E9B\u0323,NFKD,s\u0323\u0307')]
    [TestCase('Empty string', ',NFD,')]
    procedure Normalize_Forms_ReturnsNormalizedString(const Text: string; const Form: string; const Expected: string);

    [Test]
    procedure Normalize_MissingForm_UsesNFC;

    [Test]
    procedure Normalize_LoneSurrogate_KeepsItUnchanged;

    [Test]
    procedure Normalize_UndefinedForm_UsesNFC;

    [Test]
    procedure Normalize_FormObjectWithToString_ConvertsToString;

    [Test]
    procedure Normalize_UnknownForm_ThrowsRangeError;

    [Test]
    procedure Normalize_ThisUndefined_ThrowsTypeError;

    [Test]
    procedure Normalize_Method_HasLengthZero;

    [Test]
    [TestCase('Infinity', 'Infinity')]
    [TestCase('Negative infinity', '-Infinity')]
    [TestCase('Negative', '-1')]
    procedure Repeat_InvalidCount_ThrowsRangeError(const Count: string);

    [Test]
    procedure Repeat_NegativeFraction_TruncatesToZero;

    [Test]
    [TestCase('startsWith', 'startsWith')]
    [TestCase('endsWith', 'endsWith')]
    [TestCase('includes', 'includes')]
    procedure SearchMethod_RegExpArgument_ThrowsTypeError(const MethodName: string);
  end;

implementation

uses
  System.SysUtils,
  JS4D.Tests.ErrorNames;

procedure TStringEs2015MethodsTests.CodePointAt_Positions_ReturnsExpected(const Text: string; const Position: string;
                                                                          const Expected: Integer);
begin
  const Script = Format('var result = "%s".codePointAt(%s); (result === undefined) ? -1 === %d : result === %d',
                        [Text, Position, Expected, Expected]);

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.CodePointAt_MissingPosition_UsesZero;
begin
  const Actual = EvaluateBoolean('"a".codePointAt() === 97');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.CodePointAt_PositionObjectWithValueOf_ConvertsToNumber;
begin
  const Script =
    'var one = { valueOf: function() { return 1; }, toString: function() { return "x"; } };' + sLineBreak +
    '"abc".codePointAt(one) === 98';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.CodePointAt_ThisNull_ThrowsTypeError;
begin
  const Actual = ThrownErrorNameOf('String.prototype.codePointAt.call(null, 0);');

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

procedure TStringEs2015MethodsTests.CodePointAt_Method_HasLengthOne;
begin
  const Actual = EvaluateBoolean('String.prototype.codePointAt.length === 1');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_Forms_ReturnsNormalizedString(const Text: string; const Form: string;
                                                                            const Expected: string);
begin
  const Script = Format('"%s".normalize("%s") === "%s"', [Text, Form, Expected]);

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_MissingForm_UsesNFC;
begin
  const Actual = EvaluateBoolean('"A\u030A".normalize() === "\u00C5"');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_LoneSurrogate_KeepsItUnchanged;
begin
  const SurroundedByPairs = EvaluateBoolean('"A\u030A\uD800A\u030A".normalize() === "\u00C5\uD800\u00C5"');
  const AloneInNFKD = EvaluateBoolean('"\uD800".normalize("NFKD") === "\uD800"');

  Assert.IsTrue(SurroundedByPairs);
  Assert.IsTrue(AloneInNFKD);
end;

procedure TStringEs2015MethodsTests.Normalize_UndefinedForm_UsesNFC;
begin
  const Actual = EvaluateBoolean('"A\u030A".normalize(undefined) === "\u00C5"');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_FormObjectWithToString_ConvertsToString;
begin
  const Script =
    'var form = { toString: function() { return "NFD"; } };' + sLineBreak +
    '"\u00C5".normalize(form) === "A\u030A"';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_UnknownForm_ThrowsRangeError;
begin
  const Actual = ThrownErrorNameOf('"a".normalize("nfc");');

  Assert.AreEqual(RANGE_ERROR_NAME, Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_ThisUndefined_ThrowsTypeError;
begin
  const Actual = ThrownErrorNameOf('String.prototype.normalize.call(undefined);');

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

procedure TStringEs2015MethodsTests.Normalize_Method_HasLengthZero;
begin
  const Actual = EvaluateBoolean('String.prototype.normalize.length === 0');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.Repeat_InvalidCount_ThrowsRangeError(const Count: string);
begin
  const Actual = ThrownErrorNameOf(Format('"a".repeat(%s);', [Count]));

  Assert.AreEqual(RANGE_ERROR_NAME, Actual);
end;

procedure TStringEs2015MethodsTests.Repeat_NegativeFraction_TruncatesToZero;
begin
  const Actual = EvaluateBoolean('"a".repeat(-0.5) === ""');

  Assert.IsTrue(Actual);
end;

procedure TStringEs2015MethodsTests.SearchMethod_RegExpArgument_ThrowsTypeError(const MethodName: string);
begin
  const Actual = ThrownErrorNameOf(Format('"abc".%s(/b/);', [MethodName]));

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

end.
