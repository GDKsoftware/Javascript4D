unit JS4D.Tests.RegExpAccessors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TRegExpAccessorsTests = class(TJSEngineTestCase)
  public
    [Test]
    [TestCase('Source', 'source')]
    [TestCase('Flags', 'flags')]
    [TestCase('Global', 'global')]
    [TestCase('IgnoreCase', 'ignoreCase')]
    [TestCase('Multiline', 'multiline')]
    [TestCase('Sticky', 'sticky')]
    [TestCase('Unicode', 'unicode')]
    procedure Prototype_FlagProperty_IsAccessorWithoutSetter(const Name: string);

    [Test]
    [TestCase('Global', 'global')]
    [TestCase('Sticky', 'sticky')]
    procedure Getter_NameAndLength_FollowTheSpecification(const Name: string);

    [Test]
    procedure Instance_OwnProperties_AreOnlyLastIndex;

    [Test]
    procedure LastIndex_Descriptor_IsWritableOnly;

    [Test]
    procedure Getters_OnRegExp_ReportTheFlags;

    [Test]
    procedure Getters_OnRegExpPrototype_ReturnDefaults;

    [Test]
    [TestCase('Source', 'source')]
    [TestCase('Global', 'global')]
    [TestCase('Sticky', 'sticky')]
    procedure Getters_OnOtherObject_ThrowTypeError(const Name: string);

    [Test]
    procedure Flags_OnRegExp_IsInCanonicalOrder;

    [Test]
    procedure Flags_OnPlainObject_ReadsTheFlagProperties;

    [Test]
    procedure Flags_OnPrimitive_ThrowsTypeError;

    [Test]
    procedure Source_EmptyPattern_IsEmptyGroup;

    [Test]
    procedure Source_SlashAndLineTerminators_AreEscaped;

    [Test]
    procedure Source_SlashInsideClass_StaysLiteral;

    [Test]
    procedure ToString_PatternWithSlash_EscapesSource;

    [Test]
    procedure Sticky_Exec_MatchesOnlyAtLastIndex;

    [Test]
    procedure Sticky_FailedExec_ResetsLastIndex;

    [Test]
    procedure Sticky_Test_AdvancesLastIndex;
  end;

implementation

uses
  System.SysUtils;

const
  FLAG_DESCRIPTOR = 'var d = Object.getOwnPropertyDescriptor(RegExp.prototype, "%s");';
  FLAG_GETTER = 'var g = Object.getOwnPropertyDescriptor(RegExp.prototype, "%s").get;';

procedure TRegExpAccessorsTests.Prototype_FlagProperty_IsAccessorWithoutSetter(const Name: string);
begin
  const Preparation = Format(FLAG_DESCRIPTOR, [Name]);

  AssertChecksHold(Preparation,
    ['typeof d.get === "function"',
     'd.set === undefined',
     'd.enumerable === false',
     'd.configurable === true']);
end;

procedure TRegExpAccessorsTests.Getter_NameAndLength_FollowTheSpecification(const Name: string);
begin
  const Preparation = Format(FLAG_GETTER, [Name]);
  const ExpectedName = Format('g.name === "get %s"', [Name]);

  AssertChecksHold(Preparation,
    [ExpectedName,
     'g.length === 0',
     '!g.hasOwnProperty("prototype")']);
end;

procedure TRegExpAccessorsTests.Instance_OwnProperties_AreOnlyLastIndex;
begin
  AssertEvaluatesTo('lastIndex', 'Object.getOwnPropertyNames(/a/g).join()');
end;

procedure TRegExpAccessorsTests.LastIndex_Descriptor_IsWritableOnly;
begin
  AssertChecksHold('var d = Object.getOwnPropertyDescriptor(/a/, "lastIndex");',
    ['d.value === 0',
     'd.writable === true',
     'd.enumerable === false',
     'd.configurable === false']);
end;

procedure TRegExpAccessorsTests.Getters_OnRegExp_ReportTheFlags;
begin
  AssertChecksHold('var re = /a\/b/gimuy;',
    ['re.global === true',
     're.ignoreCase === true',
     're.multiline === true',
     're.unicode === true',
     're.sticky === true',
     're.source === "a\\/b"',
     '/a/.global === false',
     '/a/.ignoreCase === false',
     '/a/.multiline === false',
     '/a/.unicode === false',
     '/a/.sticky === false']);
end;

procedure TRegExpAccessorsTests.Getters_OnRegExpPrototype_ReturnDefaults;
begin
  AssertChecksHold('',
    ['RegExp.prototype.global === undefined',
     'RegExp.prototype.sticky === undefined',
     'RegExp.prototype.source === "(?:)"',
     'RegExp.prototype.flags === ""']);
end;

procedure TRegExpAccessorsTests.Getters_OnOtherObject_ThrowTypeError(const Name: string);
begin
  const Script = Format(FLAG_GETTER, [Name]) +
                 'var thrown = 0;' +
                 'try { g.call({}); } catch (e) { if (e instanceof TypeError) thrown++; }' +
                 'try { g.call(1); } catch (e) { if (e instanceof TypeError) thrown++; }' +
                 'try { g.call(undefined); } catch (e) { if (e instanceof TypeError) thrown++; }' +
                 'thrown';

  AssertEvaluatesTo('3', Script);
end;

procedure TRegExpAccessorsTests.Flags_OnRegExp_IsInCanonicalOrder;
begin
  AssertEvaluatesTo('gimuy|', '[new RegExp("a", "yumig").flags, /a/.flags].join("|")');
end;

procedure TRegExpAccessorsTests.Flags_OnPlainObject_ReadsTheFlagProperties;
begin
  AssertEvaluatesTo('guy',
    'var get = Object.getOwnPropertyDescriptor(RegExp.prototype, "flags").get;' +
    'get.call({ global: 1, sticky: true, multiline: "", unicode: "x" })');
end;

procedure TRegExpAccessorsTests.Flags_OnPrimitive_ThrowsTypeError;
begin
  AssertEvaluatesTo('true',
    'var get = Object.getOwnPropertyDescriptor(RegExp.prototype, "flags").get;' +
    'var thrown = false;' +
    'try { get.call(true); } catch (e) { thrown = e instanceof TypeError; }' +
    'thrown');
end;

procedure TRegExpAccessorsTests.Source_EmptyPattern_IsEmptyGroup;
begin
  AssertChecksHold('',
    ['new RegExp("").source === "(?:)"',
     'new RegExp().source === "(?:)"',
     'String(new RegExp("")) === "/(?:)/"']);
end;

procedure TRegExpAccessorsTests.Source_SlashAndLineTerminators_AreEscaped;
begin
  AssertChecksHold('',
    ['new RegExp("/").source === "\\/"',
     'new RegExp("\\/").source === "\\/"',
     'new RegExp("\n").source === "\\n"',
     'new RegExp("\r").source === "\\r"',
     'new RegExp(String.fromCharCode(0x2028)).source === "\\u2028"',
     'new RegExp(String.fromCharCode(0x2029)).source === "\\u2029"']);
end;

procedure TRegExpAccessorsTests.Source_SlashInsideClass_StaysLiteral;
begin
  AssertEvaluatesTo('[/]', 'new RegExp("[/]").source');
end;

procedure TRegExpAccessorsTests.ToString_PatternWithSlash_EscapesSource;
begin
  AssertEvaluatesTo('/a\/b/g', 'String(new RegExp("a/b", "g"))');
end;

procedure TRegExpAccessorsTests.Sticky_Exec_MatchesOnlyAtLastIndex;
begin
  AssertChecksHold(
    'var r = /b/y;' +
    'var first = r.exec("ab");' +
    'r.lastIndex = 1;' +
    'var second = r.exec("ab");',
    ['first === null',
     'second !== null',
     'second.index === 1',
     'r.lastIndex === 2']);
end;

procedure TRegExpAccessorsTests.Sticky_FailedExec_ResetsLastIndex;
begin
  AssertChecksHold('var r = /a/y; r.lastIndex = 1; var m = r.exec("ab");',
    ['m === null',
     'r.lastIndex === 0']);
end;

procedure TRegExpAccessorsTests.Sticky_Test_AdvancesLastIndex;
begin
  AssertEvaluatesTo('true,1,true,2,false,0',
    'var r = /a/y;' +
    '[r.test("aab"), r.lastIndex, r.test("aab"), r.lastIndex, r.test("aab"), r.lastIndex].join()');
end;

end.
