unit JS4D.Tests.JsonParse;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.JsonSyntax,
  JS4D.JsonReader,
  JS4D.Engine;

type
  [TestFixture]
  TJsonParseTests = class
  public
    [Test]
    [TestCase('Object', '{"a": [1]}')]
    [TestCase('Padded', '  12  ')]
    [TestCase('Escapes', '"a\n\"\\\/é"')]
    [TestCase('Exponent', '-0.5e+3')]
    [TestCase('EmptyContainers', '[{}]')]
    [TestCase('Literal', 'null')]
    procedure IsValid_ValidText_ReturnsTrue(const Text: string);

    [Test]
    [TestCase('Empty', '')]
    [TestCase('SingleQuotes', '{''a'': 1}')]
    [TestCase('UnquotedKey', '{a: 1}')]
    [TestCase('LeadingZero', '01')]
    [TestCase('LoneMinus', '-')]
    [TestCase('TrailingDot', '1.')]
    [TestCase('BadExponent', '1e')]
    [TestCase('BadEscape', '"\x41"')]
    [TestCase('ShortUnicodeEscape', '"\u12"')]
    [TestCase('UnterminatedString', '"abc')]
    [TestCase('TrailingGarbage', '1 2')]
    [TestCase('Undefined', 'undefined')]
    [TestCase('UnclosedArray', '[1')]
    [TestCase('TrailingCommaInArray', '[1,]')]
    [TestCase('TrailingCommaInObject', '{"a":1,}')]
    procedure IsValid_InvalidText_ReturnsFalse(const Text: string);

    [Test]
    procedure IsValid_ControlCharacterInString_ReturnsFalse;

    [Test]
    procedure IsValid_UnicodeWhitespaceAroundValue_ReturnsFalse;

    [Test]
    procedure IsValid_ExcessiveNesting_ReturnsFalse;

    [Test]
    procedure Parse_InvalidText_ThrowsSyntaxError;

    [Test]
    [TestCase('Truncated', '{"a":')]
    [TestCase('Empty', '')]
    [TestCase('UnterminatedString', '"abc')]
    [TestCase('LoneEscape', '"abc\')]
    procedure Read_InvalidText_RaisesSyntaxError(const Text: string);
  end;

implementation

const
  NESTING_DEPTH = 5000;

procedure TJsonParseTests.IsValid_ValidText_ReturnsTrue(const Text: string);
begin
  const IsValid = TJSJsonSyntax.IsValid(Text);

  Assert.IsTrue(IsValid);
end;

procedure TJsonParseTests.IsValid_InvalidText_ReturnsFalse(const Text: string);
begin
  const IsValid = TJSJsonSyntax.IsValid(Text);

  Assert.IsFalse(IsValid);
end;

procedure TJsonParseTests.IsValid_ControlCharacterInString_ReturnsFalse;
begin
  const Text = '"a' + #1 + 'b"';

  const IsValid = TJSJsonSyntax.IsValid(Text);

  Assert.IsFalse(IsValid);
end;

procedure TJsonParseTests.IsValid_UnicodeWhitespaceAroundValue_ReturnsFalse;
begin
  const Text = #$1680 + '1';

  const IsValid = TJSJsonSyntax.IsValid(Text);

  Assert.IsFalse(IsValid);
end;

procedure TJsonParseTests.IsValid_ExcessiveNesting_ReturnsFalse;
begin
  const Text = StringOfChar('[', NESTING_DEPTH) + StringOfChar(']', NESTING_DEPTH);

  const IsValid = TJSJsonSyntax.IsValid(Text);

  Assert.IsFalse(IsValid);
end;

procedure TJsonParseTests.Read_InvalidText_RaisesSyntaxError(const Text: string);
begin
  Assert.WillRaise(
    procedure
    begin
      TJSJsonReader.Read(Text, nil, nil);
    end,
    EJSSyntaxError);
end;

procedure TJsonParseTests.Parse_InvalidText_ThrowsSyntaxError;
begin
  const Engine = TJSEngine.Create;
  try
    const Script =
      'var thrown = false;' + sLineBreak +
      'try { JSON.parse(''{"a": tru}''); }' +
      ' catch (e) { thrown = (e instanceof SyntaxError); }' + sLineBreak +
      'thrown';

    const Thrown = Engine.Evaluate(Script);

    Assert.IsTrue(Thrown.AsBoolean);
  finally
    Engine.Free;
  end;
end;

end.
