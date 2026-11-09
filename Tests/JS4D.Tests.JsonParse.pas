unit JS4D.Tests.JsonParse;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.JsonSyntax,
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
    procedure IsValid_InvalidText_ReturnsFalse(const Text: string);

    [Test]
    procedure IsValid_TrailingComma_ReturnsFalse;

    [Test]
    procedure IsValid_ControlCharacterInString_ReturnsFalse;

    [Test]
    procedure IsValid_UnicodeWhitespaceAroundValue_ReturnsFalse;

    [Test]
    procedure IsValid_ExcessiveNesting_ReturnsFalse;

    [Test]
    procedure Parse_InvalidText_ThrowsSyntaxError;
  end;

implementation

procedure TJsonParseTests.IsValid_ValidText_ReturnsTrue(const Text: string);
begin
  Assert.IsTrue(TJSJsonSyntax.IsValid(Text));
end;

procedure TJsonParseTests.IsValid_InvalidText_ReturnsFalse(const Text: string);
begin
  Assert.IsFalse(TJSJsonSyntax.IsValid(Text));
end;

procedure TJsonParseTests.IsValid_TrailingComma_ReturnsFalse;
begin
  Assert.IsFalse(TJSJsonSyntax.IsValid('[1,]'), 'array');
  Assert.IsFalse(TJSJsonSyntax.IsValid('{"a":1,}'), 'object');
end;

procedure TJsonParseTests.IsValid_ControlCharacterInString_ReturnsFalse;
begin
  const Text = '"a' + #1 + 'b"';

  Assert.IsFalse(TJSJsonSyntax.IsValid(Text));
end;

procedure TJsonParseTests.IsValid_UnicodeWhitespaceAroundValue_ReturnsFalse;
begin
  const Text = #$1680 + '1';

  Assert.IsFalse(TJSJsonSyntax.IsValid(Text));
end;

procedure TJsonParseTests.IsValid_ExcessiveNesting_ReturnsFalse;
begin
  const Text = StringOfChar('[', 5000) + StringOfChar(']', 5000);

  Assert.IsFalse(TJSJsonSyntax.IsValid(Text));
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

    Assert.IsTrue(Engine.Evaluate(Script).AsBoolean);
  finally
    Engine.Free;
  end;
end;

end.
