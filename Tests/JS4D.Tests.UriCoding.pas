unit JS4D.Tests.UriCoding;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TUriCodingTests = class
  private
    FEngine: TJSEngine;

    function CodeUnitsOf(const Expression: string): string;
    function ErrorNameOf(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Ascii', '%41,65')]
    [TestCase('TwoBytes', '%C3%A9,233')]
    [TestCase('ThreeBytes', '%E2%82%AC,8364')]
    [TestCase('FourBytes', '%F0%9F%98%80,55357;56832')]
    [TestCase('LowestTwoByte', '%C2%80,128')]
    [TestCase('HighestCodePoint', '%F4%8F%BF%BF,56319;57343')]
    [TestCase('LowercaseHex', '%c3%a9,233')]
    [TestCase('Mixed', 'a%C3%A9b,97;233;98')]
    procedure Decode_EscapedSequence_ReturnsCodeUnits(const Encoded: string; const Expected: string);

    [Test]
    procedure DecodeURI_ReservedCharacters_StayEscaped;

    [Test]
    procedure DecodeURIComponent_ReservedCharacters_AreDecoded;

    [Test]
    [TestCase('LonePercent', '%')]
    [TestCase('TruncatedEscape', 'a%4')]
    [TestCase('FirstDigitInvalid', '%G1')]
    [TestCase('SecondDigitInvalid', '%1G')]
    [TestCase('LoneContinuationByte', '%80')]
    [TestCase('InvalidLeadByte', '%FF')]
    [TestCase('FiveByteLead', '%F8%80%80%80%80')]
    [TestCase('MissingContinuation', '%C3')]
    [TestCase('ContinuationNotEscaped', '%C3A9')]
    [TestCase('ContinuationNotHex', '%C3%G9')]
    [TestCase('ContinuationNotContinuationByte', '%C3%28')]
    [TestCase('OverlongTwoBytes', '%C0%80')]
    [TestCase('OverlongThreeBytes', '%E0%80%80')]
    [TestCase('OverlongFourBytes', '%F0%80%80%80')]
    [TestCase('EncodedSurrogate', '%ED%A0%80')]
    [TestCase('BeyondUnicodeRange', '%F4%90%80%80')]
    procedure Decode_MalformedInput_ThrowsURIError(const Encoded: string);

    [Test]
    [TestCase('Ascii', 'a,a')]
    [TestCase('TwoBytes', '\u00e9,%C3%A9')]
    [TestCase('ThreeBytes', '\u20ac,%E2%82%AC')]
    [TestCase('SurrogatePair', '\ud83d\ude00,%F0%9F%98%80')]
    [TestCase('Space', ' ,%20')]
    [TestCase('Percent', '%,%25')]
    [TestCase('LastTwoByte', '\u07ff,%DF%BF')]
    [TestCase('FirstThreeByte', '\u0800,%E0%A0%80')]
    procedure Encode_Text_ReturnsUppercasePercentEscapes(const Text: string; const Expected: string);

    [Test]
    procedure EncodeURI_ReservedCharacters_StayUnescaped;

    [Test]
    procedure EncodeURIComponent_ReservedCharacters_AreEscaped;

    [Test]
    [TestCase('LoneHighSurrogate', '\ud800')]
    [TestCase('LoneLowSurrogate', '\udc00')]
    [TestCase('HighSurrogateAtEnd', 'a\udbff')]
    [TestCase('HighSurrogateThenAscii', '\ud800a')]
    [TestCase('ReversedPair', '\udc00\ud800')]
    procedure Encode_LoneSurrogate_ThrowsURIError(const Text: string);

    [Test]
    procedure RoundTrip_SampledBasicMultilingualPlaneUnits_IsPreserved;

    [Test]
    procedure Decode_NoArgument_DecodesUndefinedText;

    [Test]
    procedure Decode_ObjectArgument_UsesItsStringValue;

    [Test]
    procedure Decode_ObjectWithoutPrimitiveValue_ThrowsTypeError;

    [Test]
    procedure Decode_CalledAsConstructor_ThrowsTypeError;
  end;

implementation

const
  NoError = 'none';
  UriErrorName = 'URIError';
  TypeErrorName = 'TypeError';
  ReservedCharacters = ';/?:@&=+$,#';

procedure TUriCodingTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TUriCodingTests.TearDown;
begin
  FEngine.Free;
end;

function TUriCodingTests.CodeUnitsOf(const Expression: string): string;
begin
  const Script = Format('var text = %s; var units = []; ' +
                        'for (var i = 0; i < text.length; i++) { units.push(text.charCodeAt(i)); } ' +
                        'units.join('';'')', [Expression]);

  Result := FEngine.Evaluate(Script).AsString;
end;

function TUriCodingTests.ErrorNameOf(const Expression: string): string;
begin
  const Script = Format('var name = ''%s''; try { %s; } catch (e) { name = e.name; } name',
                        [NoError, Expression]);

  Result := FEngine.Evaluate(Script).AsString;
end;

procedure TUriCodingTests.Decode_EscapedSequence_ReturnsCodeUnits(const Encoded: string; const Expected: string);
begin
  const FromUri = CodeUnitsOf(Format('decodeURI(''%s'')', [Encoded]));
  const FromComponent = CodeUnitsOf(Format('decodeURIComponent(''%s'')', [Encoded]));

  Assert.AreEqual(Expected, FromUri);
  Assert.AreEqual(Expected, FromComponent);
end;

procedure TUriCodingTests.DecodeURI_ReservedCharacters_StayEscaped;
begin
  const Script = 'decodeURI(''%3B%2F%3F%3A%40%26%3D%2B%24%2C%23'') === ''%3B%2F%3F%3A%40%26%3D%2B%24%2C%23''';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.DecodeURIComponent_ReservedCharacters_AreDecoded;
begin
  const Script = Format('decodeURIComponent(''%%3B%%2F%%3F%%3A%%40%%26%%3D%%2B%%24%%2C%%23'') === ''%s''',
                        [ReservedCharacters]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.Decode_MalformedInput_ThrowsURIError(const Encoded: string);
begin
  const FromUri = ErrorNameOf(Format('decodeURI(''%s'')', [Encoded]));
  const FromComponent = ErrorNameOf(Format('decodeURIComponent(''%s'')', [Encoded]));

  Assert.AreEqual(UriErrorName, FromUri);
  Assert.AreEqual(UriErrorName, FromComponent);
end;

procedure TUriCodingTests.Encode_Text_ReturnsUppercasePercentEscapes(const Text: string; const Expected: string);
begin
  const FromUri = FEngine.Evaluate(Format('encodeURI(''%s'')', [Text])).AsString;
  const FromComponent = FEngine.Evaluate(Format('encodeURIComponent(''%s'')', [Text])).AsString;

  Assert.AreEqual(Expected, FromUri);
  Assert.AreEqual(Expected, FromComponent);
end;

procedure TUriCodingTests.EncodeURI_ReservedCharacters_StayUnescaped;
begin
  const Script = Format('encodeURI(''%s'') === ''%s''', [ReservedCharacters, ReservedCharacters]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.EncodeURIComponent_ReservedCharacters_AreEscaped;
begin
  const Script = Format('encodeURIComponent(''%s'') === ''%%3B%%2F%%3F%%3A%%40%%26%%3D%%2B%%24%%2C%%23''',
                        [ReservedCharacters]);

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.Encode_LoneSurrogate_ThrowsURIError(const Text: string);
begin
  const FromUri = ErrorNameOf(Format('encodeURI(''%s'')', [Text]));
  const FromComponent = ErrorNameOf(Format('encodeURIComponent(''%s'')', [Text]));

  Assert.AreEqual(UriErrorName, FromUri);
  Assert.AreEqual(UriErrorName, FromComponent);
end;

procedure TUriCodingTests.RoundTrip_SampledBasicMultilingualPlaneUnits_IsPreserved;
begin
  const Script = 'var preserved = true; ' +
                 'for (var unit = 0; unit < 65536; unit += 7) { ' +
                 '  var isSurrogate = (unit >= 0xD800 && unit <= 0xDFFF); ' +
                 '  if (isSurrogate) { continue; } ' +
                 '  var text = String.fromCharCode(unit); ' +
                 '  if (decodeURIComponent(encodeURIComponent(text)) !== text) { preserved = false; } ' +
                 '} preserved';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.Decode_NoArgument_DecodesUndefinedText;
begin
  Assert.IsTrue(FEngine.Evaluate('decodeURI() === ''undefined'' && decodeURIComponent() === ''undefined''').AsBoolean);
end;

procedure TUriCodingTests.Decode_ObjectArgument_UsesItsStringValue;
begin
  const Script = 'var source = { valueOf: function () { return ''''; }, toString: function () { return ''%5E''; } }; ' +
                 'decodeURI(source) === ''^'' && decodeURIComponent(source) === ''^''';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TUriCodingTests.Decode_ObjectWithoutPrimitiveValue_ThrowsTypeError;
begin
  const Script = 'var source = { valueOf: function () { return {}; }, toString: function () { return {}; } }; ';

  FEngine.Evaluate(Script);
  const FromUri = ErrorNameOf('decodeURI(source)');
  const FromComponent = ErrorNameOf('decodeURIComponent(source)');

  Assert.AreEqual(TypeErrorName, FromUri);
  Assert.AreEqual(TypeErrorName, FromComponent);
end;

procedure TUriCodingTests.Decode_CalledAsConstructor_ThrowsTypeError;
begin
  const Constructed = ErrorNameOf('new decodeURI(''a'')');

  Assert.AreEqual(TypeErrorName, Constructed);
end;

end.
