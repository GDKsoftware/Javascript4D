unit JS4D.Tests.UriCoding;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TUriCodingTests = class(TJSEngineTestCase)
  private
    const
      DECODE_URI = 'decodeURI';
      DECODE_URI_COMPONENT = 'decodeURIComponent';
      ENCODE_URI = 'encodeURI';
      ENCODE_URI_COMPONENT = 'encodeURIComponent';

    function CodeUnitsOf(const Expression: string): string;
    function ErrorNameOfCall(const Expression: string): string;

  public
    [Test]
    [TestCase('AsciiUri', DECODE_URI + ',%41,65')]
    [TestCase('AsciiComponent', DECODE_URI_COMPONENT + ',%41,65')]
    [TestCase('TwoBytesUri', DECODE_URI + ',%C3%A9,233')]
    [TestCase('TwoBytesComponent', DECODE_URI_COMPONENT + ',%C3%A9,233')]
    [TestCase('ThreeBytesUri', DECODE_URI + ',%E2%82%AC,8364')]
    [TestCase('ThreeBytesComponent', DECODE_URI_COMPONENT + ',%E2%82%AC,8364')]
    [TestCase('FourBytesUri', DECODE_URI + ',%F0%9F%98%80,55357;56832')]
    [TestCase('FourBytesComponent', DECODE_URI_COMPONENT + ',%F0%9F%98%80,55357;56832')]
    [TestCase('LowestTwoByteUri', DECODE_URI + ',%C2%80,128')]
    [TestCase('LowestTwoByteComponent', DECODE_URI_COMPONENT + ',%C2%80,128')]
    [TestCase('HighestCodePointUri', DECODE_URI + ',%F4%8F%BF%BF,56319;57343')]
    [TestCase('HighestCodePointComponent', DECODE_URI_COMPONENT + ',%F4%8F%BF%BF,56319;57343')]
    [TestCase('LowercaseHexUri', DECODE_URI + ',%c3%a9,233')]
    [TestCase('LowercaseHexComponent', DECODE_URI_COMPONENT + ',%c3%a9,233')]
    [TestCase('MixedUri', DECODE_URI + ',a%C3%A9b,97;233;98')]
    [TestCase('MixedComponent', DECODE_URI_COMPONENT + ',a%C3%A9b,97;233;98')]
    procedure Decode_EscapedSequence_ReturnsCodeUnits(const FunctionName: string; const Encoded: string;
                                                      const Expected: string);

    [Test]
    procedure DecodeURI_ReservedCharacters_StayEscaped;

    [Test]
    procedure DecodeURIComponent_ReservedCharacters_AreDecoded;

    [Test]
    [TestCase('LonePercentUri', DECODE_URI + ',%')]
    [TestCase('LonePercentComponent', DECODE_URI_COMPONENT + ',%')]
    [TestCase('TruncatedEscapeUri', DECODE_URI + ',a%4')]
    [TestCase('TruncatedEscapeComponent', DECODE_URI_COMPONENT + ',a%4')]
    [TestCase('FirstDigitInvalidUri', DECODE_URI + ',%G1')]
    [TestCase('FirstDigitInvalidComponent', DECODE_URI_COMPONENT + ',%G1')]
    [TestCase('SecondDigitInvalidUri', DECODE_URI + ',%1G')]
    [TestCase('SecondDigitInvalidComponent', DECODE_URI_COMPONENT + ',%1G')]
    [TestCase('LoneContinuationByteUri', DECODE_URI + ',%80')]
    [TestCase('LoneContinuationByteComponent', DECODE_URI_COMPONENT + ',%80')]
    [TestCase('InvalidLeadByteUri', DECODE_URI + ',%FF')]
    [TestCase('InvalidLeadByteComponent', DECODE_URI_COMPONENT + ',%FF')]
    [TestCase('FiveByteLeadUri', DECODE_URI + ',%F8%80%80%80%80')]
    [TestCase('FiveByteLeadComponent', DECODE_URI_COMPONENT + ',%F8%80%80%80%80')]
    [TestCase('MissingContinuationUri', DECODE_URI + ',%C3')]
    [TestCase('MissingContinuationComponent', DECODE_URI_COMPONENT + ',%C3')]
    [TestCase('ContinuationNotEscapedUri', DECODE_URI + ',%C3A9')]
    [TestCase('ContinuationNotEscapedComponent', DECODE_URI_COMPONENT + ',%C3A9')]
    [TestCase('ContinuationNotHexUri', DECODE_URI + ',%C3%G9')]
    [TestCase('ContinuationNotHexComponent', DECODE_URI_COMPONENT + ',%C3%G9')]
    [TestCase('ContinuationNotContinuationByteUri', DECODE_URI + ',%C3%28')]
    [TestCase('ContinuationNotContinuationByteComponent', DECODE_URI_COMPONENT + ',%C3%28')]
    [TestCase('OverlongTwoBytesUri', DECODE_URI + ',%C0%80')]
    [TestCase('OverlongTwoBytesComponent', DECODE_URI_COMPONENT + ',%C0%80')]
    [TestCase('OverlongThreeBytesUri', DECODE_URI + ',%E0%80%80')]
    [TestCase('OverlongThreeBytesComponent', DECODE_URI_COMPONENT + ',%E0%80%80')]
    [TestCase('OverlongFourBytesUri', DECODE_URI + ',%F0%80%80%80')]
    [TestCase('OverlongFourBytesComponent', DECODE_URI_COMPONENT + ',%F0%80%80%80')]
    [TestCase('EncodedSurrogateUri', DECODE_URI + ',%ED%A0%80')]
    [TestCase('EncodedSurrogateComponent', DECODE_URI_COMPONENT + ',%ED%A0%80')]
    [TestCase('BeyondUnicodeRangeUri', DECODE_URI + ',%F4%90%80%80')]
    [TestCase('BeyondUnicodeRangeComponent', DECODE_URI_COMPONENT + ',%F4%90%80%80')]
    procedure Decode_MalformedInput_ThrowsURIError(const FunctionName: string; const Encoded: string);

    [Test]
    [TestCase('AsciiUri', ENCODE_URI + ',a,a')]
    [TestCase('AsciiComponent', ENCODE_URI_COMPONENT + ',a,a')]
    [TestCase('TwoBytesUri', ENCODE_URI + ',\u00e9,%C3%A9')]
    [TestCase('TwoBytesComponent', ENCODE_URI_COMPONENT + ',\u00e9,%C3%A9')]
    [TestCase('ThreeBytesUri', ENCODE_URI + ',\u20ac,%E2%82%AC')]
    [TestCase('ThreeBytesComponent', ENCODE_URI_COMPONENT + ',\u20ac,%E2%82%AC')]
    [TestCase('SurrogatePairUri', ENCODE_URI + ',\ud83d\ude00,%F0%9F%98%80')]
    [TestCase('SurrogatePairComponent', ENCODE_URI_COMPONENT + ',\ud83d\ude00,%F0%9F%98%80')]
    [TestCase('SpaceUri', ENCODE_URI + ', ,%20')]
    [TestCase('SpaceComponent', ENCODE_URI_COMPONENT + ', ,%20')]
    [TestCase('PercentUri', ENCODE_URI + ',%,%25')]
    [TestCase('PercentComponent', ENCODE_URI_COMPONENT + ',%,%25')]
    [TestCase('LastTwoByteUri', ENCODE_URI + ',\u07ff,%DF%BF')]
    [TestCase('LastTwoByteComponent', ENCODE_URI_COMPONENT + ',\u07ff,%DF%BF')]
    [TestCase('FirstThreeByteUri', ENCODE_URI + ',\u0800,%E0%A0%80')]
    [TestCase('FirstThreeByteComponent', ENCODE_URI_COMPONENT + ',\u0800,%E0%A0%80')]
    procedure Encode_Text_ReturnsUppercasePercentEscapes(const FunctionName: string; const Text: string;
                                                         const Expected: string);

    [Test]
    procedure EncodeURI_ReservedCharacters_StayUnescaped;

    [Test]
    procedure EncodeURIComponent_ReservedCharacters_AreEscaped;

    [Test]
    [TestCase('LoneHighSurrogateUri', ENCODE_URI + ',\ud800')]
    [TestCase('LoneHighSurrogateComponent', ENCODE_URI_COMPONENT + ',\ud800')]
    [TestCase('LoneLowSurrogateUri', ENCODE_URI + ',\udc00')]
    [TestCase('LoneLowSurrogateComponent', ENCODE_URI_COMPONENT + ',\udc00')]
    [TestCase('HighSurrogateAtEndUri', ENCODE_URI + ',a\udbff')]
    [TestCase('HighSurrogateAtEndComponent', ENCODE_URI_COMPONENT + ',a\udbff')]
    [TestCase('HighSurrogateThenAsciiUri', ENCODE_URI + ',\ud800a')]
    [TestCase('HighSurrogateThenAsciiComponent', ENCODE_URI_COMPONENT + ',\ud800a')]
    [TestCase('ReversedPairUri', ENCODE_URI + ',\udc00\ud800')]
    [TestCase('ReversedPairComponent', ENCODE_URI_COMPONENT + ',\udc00\ud800')]
    procedure Encode_LoneSurrogate_ThrowsURIError(const FunctionName: string; const Text: string);

    [Test]
    procedure RoundTrip_SampledBasicMultilingualPlaneUnits_IsPreserved;

    [Test]
    [TestCase('DecodeURI', DECODE_URI)]
    [TestCase('DecodeURIComponent', DECODE_URI_COMPONENT)]
    procedure Decode_NoArgument_DecodesUndefinedText(const FunctionName: string);

    [Test]
    [TestCase('DecodeURI', DECODE_URI)]
    [TestCase('DecodeURIComponent', DECODE_URI_COMPONENT)]
    procedure Decode_ObjectArgument_UsesItsStringValue(const FunctionName: string);

    [Test]
    [TestCase('DecodeURI', DECODE_URI)]
    [TestCase('DecodeURIComponent', DECODE_URI_COMPONENT)]
    procedure Decode_ObjectWithoutPrimitiveValue_ThrowsTypeError(const FunctionName: string);

    [Test]
    procedure Decode_CalledAsConstructor_ThrowsTypeError;
  end;

implementation

uses
  System.SysUtils,
  JS4D.Tests.ErrorNames;

const
  RESERVED_CHARACTERS = ';/?:@&=+$,#';
  ESCAPED_RESERVED_CHARACTERS = '%3B%2F%3F%3A%40%26%3D%2B%24%2C%23';

function TUriCodingTests.CodeUnitsOf(const Expression: string): string;
begin
  const Script = Format('var text = %s; var units = []; ' +
                        'for (var i = 0; i < text.length; i++) { units.push(text.charCodeAt(i)); } ' +
                        'units.join('';'')', [Expression]);

  Result := EvaluateText(Script);
end;

function TUriCodingTests.ErrorNameOfCall(const Expression: string): string;
begin
  const Statement = Format('%s;', [Expression]);

  Result := ThrownErrorNameOf(Statement);
end;

procedure TUriCodingTests.Decode_EscapedSequence_ReturnsCodeUnits(const FunctionName: string; const Encoded: string;
                                                                  const Expected: string);
begin
  const Actual = CodeUnitsOf(Format('%s(''%s'')', [FunctionName, Encoded]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TUriCodingTests.DecodeURI_ReservedCharacters_StayEscaped;
begin
  const Script = Format('decodeURI(''%s'') === ''%s''', [ESCAPED_RESERVED_CHARACTERS, ESCAPED_RESERVED_CHARACTERS]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.DecodeURIComponent_ReservedCharacters_AreDecoded;
begin
  const Script = Format('decodeURIComponent(''%s'') === ''%s''', [ESCAPED_RESERVED_CHARACTERS, RESERVED_CHARACTERS]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.Decode_MalformedInput_ThrowsURIError(const FunctionName: string; const Encoded: string);
begin
  const Actual = ErrorNameOfCall(Format('%s(''%s'')', [FunctionName, Encoded]));

  Assert.AreEqual(URI_ERROR_NAME, Actual);
end;

procedure TUriCodingTests.Encode_Text_ReturnsUppercasePercentEscapes(const FunctionName: string; const Text: string;
                                                                     const Expected: string);
begin
  const Actual = EvaluateText(Format('%s(''%s'')', [FunctionName, Text]));

  Assert.AreEqual(Expected, Actual);
end;

procedure TUriCodingTests.EncodeURI_ReservedCharacters_StayUnescaped;
begin
  const Script = Format('encodeURI(''%s'') === ''%s''', [RESERVED_CHARACTERS, RESERVED_CHARACTERS]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.EncodeURIComponent_ReservedCharacters_AreEscaped;
begin
  const Script = Format('encodeURIComponent(''%s'') === ''%s''', [RESERVED_CHARACTERS, ESCAPED_RESERVED_CHARACTERS]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.Encode_LoneSurrogate_ThrowsURIError(const FunctionName: string; const Text: string);
begin
  const Actual = ErrorNameOfCall(Format('%s(''%s'')', [FunctionName, Text]));

  Assert.AreEqual(URI_ERROR_NAME, Actual);
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

  const IsPreserved = EvaluateBoolean(Script);

  Assert.IsTrue(IsPreserved);
end;

procedure TUriCodingTests.Decode_NoArgument_DecodesUndefinedText(const FunctionName: string);
begin
  const Script = Format('%s() === ''undefined''', [FunctionName]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.Decode_ObjectArgument_UsesItsStringValue(const FunctionName: string);
begin
  const Script = Format('var source = { valueOf: function () { return ''''; }, toString: function () { return ''%%5E''; } }; ' +
                        '%s(source) === ''^''', [FunctionName]);
  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TUriCodingTests.Decode_ObjectWithoutPrimitiveValue_ThrowsTypeError(const FunctionName: string);
begin
  FEngine.Execute('var source = { valueOf: function () { return {}; }, toString: function () { return {}; } };');

  const Actual = ErrorNameOfCall(Format('%s(source)', [FunctionName]));

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

procedure TUriCodingTests.Decode_CalledAsConstructor_ThrowsTypeError;
begin
  const Actual = ErrorNameOfCall('new decodeURI(''a'')');

  Assert.AreEqual(TYPE_ERROR_NAME, Actual);
end;

end.
