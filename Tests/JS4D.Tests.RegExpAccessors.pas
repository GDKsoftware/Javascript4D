unit JS4D.Tests.RegExpAccessors;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TRegExpAccessorsTests = class
  private
    FEngine: TJSEngine;

    procedure AssertScript(const Script: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

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
    procedure ToString_UsesEscapedSource;

    [Test]
    procedure Sticky_Exec_MatchesOnlyAtLastIndex;

    [Test]
    procedure Sticky_FailedExec_ResetsLastIndex;

    [Test]
    procedure Sticky_Test_AdvancesLastIndex;
  end;

implementation

procedure TRegExpAccessorsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpAccessorsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TRegExpAccessorsTests.AssertScript(const Script: string);
begin
  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean, Script);
end;

procedure TRegExpAccessorsTests.Prototype_FlagProperty_IsAccessorWithoutSetter(const Name: string);
begin
  AssertScript(
    Format('var d = Object.getOwnPropertyDescriptor(RegExp.prototype, "%s");' +
           'typeof d.get === "function" && d.set === undefined && d.enumerable === false && ' +
           'd.configurable === true', [Name]));
end;

procedure TRegExpAccessorsTests.Getter_NameAndLength_FollowTheSpecification(const Name: string);
begin
  AssertScript(
    Format('var g = Object.getOwnPropertyDescriptor(RegExp.prototype, "%s").get;' +
           'g.name === "get %s" && g.length === 0 && !g.hasOwnProperty("prototype")', [Name, Name]));
end;

procedure TRegExpAccessorsTests.Instance_OwnProperties_AreOnlyLastIndex;
begin
  AssertScript('Object.getOwnPropertyNames(/a/g).join() === "lastIndex"');
end;

procedure TRegExpAccessorsTests.LastIndex_Descriptor_IsWritableOnly;
begin
  AssertScript(
    'var d = Object.getOwnPropertyDescriptor(/a/, "lastIndex");' +
    'd.value === 0 && d.writable === true && d.enumerable === false && d.configurable === false');
end;

procedure TRegExpAccessorsTests.Getters_OnRegExp_ReportTheFlags;
begin
  AssertScript(
    'var re = /a\/b/gimuy;' +
    're.global === true && re.ignoreCase === true && re.multiline === true && re.unicode === true && ' +
    're.sticky === true && re.source === "a\\/b" && ' +
    '/a/.global === false && /a/.ignoreCase === false && /a/.multiline === false && ' +
    '/a/.unicode === false && /a/.sticky === false');
end;

procedure TRegExpAccessorsTests.Getters_OnRegExpPrototype_ReturnDefaults;
begin
  AssertScript(
    'RegExp.prototype.global === undefined && RegExp.prototype.sticky === undefined && ' +
    'RegExp.prototype.source === "(?:)" && RegExp.prototype.flags === ""');
end;

procedure TRegExpAccessorsTests.Getters_OnOtherObject_ThrowTypeError(const Name: string);
begin
  AssertScript(
    Format('var get = Object.getOwnPropertyDescriptor(RegExp.prototype, "%s").get;' +
           'var thrown = 0;' +
           'try { get.call({}); } catch (e) { if (e instanceof TypeError) thrown++; }' +
           'try { get.call(1); } catch (e) { if (e instanceof TypeError) thrown++; }' +
           'try { get.call(undefined); } catch (e) { if (e instanceof TypeError) thrown++; }' +
           'thrown === 3', [Name]));
end;

procedure TRegExpAccessorsTests.Flags_OnRegExp_IsInCanonicalOrder;
begin
  AssertScript('new RegExp("a", "yumig").flags === "gimuy" && /a/.flags === ""');
end;

procedure TRegExpAccessorsTests.Flags_OnPlainObject_ReadsTheFlagProperties;
begin
  AssertScript(
    'var get = Object.getOwnPropertyDescriptor(RegExp.prototype, "flags").get;' +
    'get.call({ global: 1, sticky: true, multiline: "", unicode: "x" }) === "guy"');
end;

procedure TRegExpAccessorsTests.Flags_OnPrimitive_ThrowsTypeError;
begin
  AssertScript(
    'var get = Object.getOwnPropertyDescriptor(RegExp.prototype, "flags").get;' +
    'var thrown = false;' +
    'try { get.call(true); } catch (e) { thrown = e instanceof TypeError; }' +
    'thrown');
end;

procedure TRegExpAccessorsTests.Source_EmptyPattern_IsEmptyGroup;
begin
  AssertScript('new RegExp("").source === "(?:)" && new RegExp().source === "(?:)" && String(new RegExp("")) === "/(?:)/"');
end;

procedure TRegExpAccessorsTests.Source_SlashAndLineTerminators_AreEscaped;
begin
  AssertScript(
    'new RegExp("/").source === "\\/" && new RegExp("\\/").source === "\\/" && ' +
    'new RegExp("\n").source === "\\n" && new RegExp("\r").source === "\\r" && ' +
    'new RegExp(String.fromCharCode(0x2028)).source === "\\u2028" && ' +
    'new RegExp(String.fromCharCode(0x2029)).source === "\\u2029"');
end;

procedure TRegExpAccessorsTests.Source_SlashInsideClass_StaysLiteral;
begin
  AssertScript('new RegExp("[/]").source === "[/]"');
end;

procedure TRegExpAccessorsTests.ToString_UsesEscapedSource;
begin
  AssertScript('String(new RegExp("a/b", "g")) === "/a\\/b/g"');
end;

procedure TRegExpAccessorsTests.Sticky_Exec_MatchesOnlyAtLastIndex;
begin
  AssertScript(
    'var r = /b/y;' +
    'var first = r.exec("ab");' +
    'r.lastIndex = 1;' +
    'var second = r.exec("ab");' +
    'first === null && second !== null && second.index === 1 && r.lastIndex === 2');
end;

procedure TRegExpAccessorsTests.Sticky_FailedExec_ResetsLastIndex;
begin
  AssertScript(
    'var r = /a/y; r.lastIndex = 1;' +
    'var m = r.exec("ab");' +
    'm === null && r.lastIndex === 0');
end;

procedure TRegExpAccessorsTests.Sticky_Test_AdvancesLastIndex;
begin
  AssertScript(
    'var r = /a/y;' +
    'var results = [r.test("aab"), r.lastIndex, r.test("aab"), r.lastIndex, r.test("aab"), r.lastIndex];' +
    'results.join() === "true,1,true,2,false,0"');
end;

end.
