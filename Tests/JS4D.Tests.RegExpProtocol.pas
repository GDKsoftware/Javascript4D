unit JS4D.Tests.RegExpProtocol;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TRegExpProtocolTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Match global collects all matches', '/a/g[Symbol.match]("banana").join()#a,a,a', '#')]
    [TestCase('Match global without matches is null', '/x/g[Symbol.match]("banana")#null', '#')]
    [TestCase('Match non-global returns the exec result', '/(n)(a)/[Symbol.match]("banana").slice().join()#na,n,a', '#')]
    [TestCase('Match uses a replaced exec', '(function () { var r = /a/; r.exec = function () { return null; }; return r[Symbol.match]("a"); })()#null', '#')]
    [TestCase('Match advances after an empty match', '/(?:)/g[Symbol.match]("ab").length#3', '#')]
    [TestCase('Match resets lastIndex of a global regexp', '(function () { var r = /a/g; r.lastIndex = 5; r[Symbol.match]("aa"); return r.lastIndex; })()#0', '#')]
    [TestCase('Match reads the flags property', '(function () { var o = { flags: "g", lastIndex: 0, exec: function (s) { return this.lastIndex++ < 2 ? ["x"] : null; } }; return RegExp.prototype[Symbol.match].call(o, "abc").join(); })()#x,x', '#')]
    [TestCase('Match on a primitive receiver throws', '(function () { try { RegExp.prototype[Symbol.match].call(1, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Match has length 1', 'RegExp.prototype[Symbol.match].length#1', '#')]
    [TestCase('Match has a symbol name', 'RegExp.prototype[Symbol.match].name#[Symbol.match]', '#')]
    [TestCase('Match is not enumerable', 'Object.getOwnPropertyDescriptor(RegExp.prototype, Symbol.match).enumerable#false', '#')]
    [TestCase('String match uses the pattern string', '"a.c".match("a.c")[0]#a.c', '#')]
    [TestCase('String match delegates to the symbol method', '(function () { var o = {}; o[Symbol.match] = function (s) { return "m:" + s; }; return "abc".match(o); })()#m:abc', '#')]
    [TestCase('String match without an argument matches the empty string', '"abc".match().index#0', '#')]
    procedure Match_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Replace global', '"aXbX".replace(/X/g, "-")#a-b-', '#')]
    [TestCase('Replace first only', '"aXbX".replace(/X/, "-")#a-bX', '#')]
    [TestCase('Replace expands $ patterns', '"abc".replace(/(b)/, "[$1$&$`$'']")#a[bbac]c', '#')]
    [TestCase('Replace function arguments', '"abc".replace(/(b)/, function (m, p1, off, s) { return m + p1 + off + s; })#abb1abcc', '#')]
    [TestCase('Replace string search value', '"a.c".replace(".", "-")#a-c', '#')]
    [TestCase('Replace with custom exec and groups', '(function () { var r = /./; r.exec = function () { var a = ["a"]; a.index = 0; a.groups = { n: "Z" }; return a; }; return r[Symbol.replace]("abc", "<$<n>>"); })()#<Z>bc', '#')]
    [TestCase('Replace passes groups to the function', '(function () { var r = /./; r.exec = function () { var a = ["a"]; a.index = 0; a.groups = { n: "Z" }; return a; }; return r[Symbol.replace]("abc", function (m, off, s, g) { return g.n; }); })()#Zbc', '#')]
    [TestCase('Replace coerces the index with a number hint', '(function () { var hint; var index = {}; index[Symbol.toPrimitive] = function (h) { hint = h; return 1; }; var r = /./; r.exec = function () { return { length: 1, 0: "b", index: index }; }; r[Symbol.replace]("abc", "x"); return hint; })()#number', '#')]
    [TestCase('Replace ignores overlapping results', 'RegExp.prototype[Symbol.replace].call({ flags: "g", lastIndex: 0, n: 0, exec: function () { return [{ length: 1, 0: "ab", index: 0 }, { length: 1, 0: "b", index: 1 }][this.n++] || null; } }, "abc", "X")#Xc', '#')]
    [TestCase('Replace advances over surrogate pairs with the u flag', '"\uD83D\uDE00".replace(/(?:)/gu, "-").length#4', '#')]
    [TestCase('Replace advances per code unit without the u flag', '"\uD83D\uDE00".replace(/(?:)/g, "-").length#5', '#')]
    [TestCase('Replace has length 2', 'RegExp.prototype[Symbol.replace].length#2', '#')]
    [TestCase('String replace delegates to the symbol method', '(function () { var o = {}; o[Symbol.replace] = function (s, r) { return s + "/" + r; }; return "abc".replace(o, "x"); })()#abc/x', '#')]
    [TestCase('Replace on a primitive receiver throws', '(function () { try { RegExp.prototype[Symbol.replace].call(1, "a", "b"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    procedure Replace_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Search finds the index', '/b/[Symbol.search]("abc")#1', '#')]
    [TestCase('Search returns -1 without a match', '/x/[Symbol.search]("abc")#-1', '#')]
    [TestCase('Search restores lastIndex', '(function () { var r = /b/g; r.lastIndex = 2; r[Symbol.search]("abc"); return r.lastIndex; })()#2', '#')]
    [TestCase('Search of a sticky regexp matches at zero only', '(function () { var r = /b/y; r.lastIndex = 1; return r[Symbol.search]("abc"); })()#-1', '#')]
    [TestCase('String search delegates to the symbol method', '(function () { var o = {}; o[Symbol.search] = function (s) { return "s:" + s; }; return "abc".search(o); })()#s:abc', '#')]
    [TestCase('String search with a string pattern', '"abc".search("c")#2', '#')]
    [TestCase('Search has length 1', 'RegExp.prototype[Symbol.search].length#1', '#')]
    procedure Search_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Split on a regexp', '"a1b2c".split(/\d/).join("|")#a|b|c', '#')]
    [TestCase('Split includes captures', '"a1b2c".split(/(\d)/).join("|")#a|1|b|2|c', '#')]
    [TestCase('Split with a limit', '"a1b2c".split(/\d/, 2).join("|")#a|b', '#')]
    [TestCase('Split of an empty string', '"".split(/x/).length#1', '#')]
    [TestCase('Split of an empty string on a matching regexp', '"".split(/(?:)/).length#0', '#')]
    [TestCase('Split on the empty regexp', '"abc".split(/(?:)/).join("|")#a|b|c', '#')]
    [TestCase('Split limit zero', '"abc".split(/b/, 0).length#0', '#')]
    [TestCase('Split reads the limit before the separator text', '(function () { try { "a".split({ toString: function () { throw new RangeError(); } }, { valueOf: function () { throw new TypeError(); } }); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Split uses the species constructor', '(function () { function C() {} C[Symbol.species] = function (p, f) { return new RegExp(p, f); }; var r = /b/; r.constructor = C; return "abc".split(r).join("|"); })()#a|c', '#')]
    [TestCase('Split rejects a species that is not a constructor', '(function () { try { (function () { var r = /b/; r.constructor = { [Symbol.species]: 1 }; "abc".split(r); })(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('String split delegates to the symbol method', '(function () { var o = {}; o[Symbol.split] = function (s, l) { return s + "/" + l; }; return "abc".split(o, 5); })()#abc/5', '#')]
    [TestCase('Split on a string', '"a,b,,c".split(",").join("|")#a|b||c', '#')]
    [TestCase('Split on an empty string', '"abc".split("").join("|")#a|b|c', '#')]
    [TestCase('Split without a separator', '"abc".split().length#1', '#')]
    [TestCase('Split on a sticky regexp does not change the receiver', '(function () { var r = /b/; "abc".split(r); return r.lastIndex + "," + r.sticky; })()#0,false', '#')]
    [TestCase('Split has length 2', 'RegExp.prototype[Symbol.split].length#2', '#')]
    procedure Split_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('ReplaceAll with a string', '"aXbX".replaceAll("X", "-")#a-b-', '#')]
    [TestCase('ReplaceAll with an empty search string', '"abc".replaceAll("", "-")#-a-b-c-', '#')]
    [TestCase('ReplaceAll skips overlapping matches', '"aaa".replaceAll("aa", "b")#ba', '#')]
    [TestCase('ReplaceAll with a global regexp', '"aXbX".replaceAll(/X/g, "-")#a-b-', '#')]
    [TestCase('ReplaceAll with a function', '"abab".replaceAll("b", function (m, p, s) { return p; })#a1a3', '#')]
    [TestCase('ReplaceAll expands the pattern', '"abab".replaceAll("b", "[$&]")#a[b]a[b]', '#')]
    [TestCase('ReplaceAll with a non-global regexp throws', '(function () { try { "a".replaceAll(/a/, "b"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('ReplaceAll delegates to the symbol method', '(function () { var o = {}; o[Symbol.replace] = function (s, r) { return s + "/" + r; }; return "abc".replaceAll(o, "x"); })()#abc/x', '#')]
    [TestCase('ReplaceAll has length 2', 'String.prototype.replaceAll.length#2', '#')]
    procedure ReplaceAll_ReturnsSpecResult(const Expression, Expected: string);

    [Test]
    [TestCase('Sticky match at lastIndex', '(function () { var r = /b/y; r.lastIndex = 1; var m = r.exec("abc"); return m[0] + r.lastIndex; })()#b2', '#')]
    [TestCase('Sticky miss resets lastIndex', '(function () { var r = /b/y; return r.exec("abc") + "," + r.lastIndex; })()#null,0', '#')]
    [TestCase('Global exec advances lastIndex', '(function () { var r = /a/g; r.exec("aa"); return r.lastIndex; })()#1', '#')]
    [TestCase('Non-global exec ignores lastIndex', '(function () { var r = /a/; r.lastIndex = 1; return r.exec("aa").index; })()#0', '#')]
    [TestCase('Non-global failure keeps lastIndex', '(function () { var r = /x/; r.lastIndex = 1; r.exec("aa"); return r.lastIndex; })()#1', '#')]
    [TestCase('Global failure resets lastIndex', '(function () { var r = /x/g; r.lastIndex = 1; r.exec("aa"); return r.lastIndex; })()#0', '#')]
    [TestCase('LastIndex beyond the string resets it', '(function () { var r = /a/g; r.lastIndex = 9; return r.exec("aa") + "," + r.lastIndex; })()#null,0', '#')]
    [TestCase('LastIndex is converted with valueOf', '(function () { var n = 0; var r = /a/; r.lastIndex = { valueOf: function () { n++; return 0; } }; r.exec("a"); return n; })()#1', '#')]
    [TestCase('LastIndex infinity does not match', '(function () { var r = /a/g; r.lastIndex = Infinity; return r.exec("a"); })()#null', '#')]
    [TestCase('Read-only lastIndex throws on a write', '(function () { var r = /a/g; Object.defineProperty(r, "lastIndex", { writable: false, value: 0 }); try { r.exec("b"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Test uses the exec property', '(function () { var calls = 0; var r = /a/; r.exec = function (s) { calls++; return null; }; return r.test("a") + "," + calls; })()#false,1', '#')]
    [TestCase('Test rejects an invalid exec result', '(function () { try { (function () { var r = /a/; r.exec = function () { return 1; }; r.test("a"); })(); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Test works on a generic object', 'RegExp.prototype.test.call({ exec: function () { return {}; } }, "a")#true', '#')]
    [TestCase('Test requires an exec method on a non-regexp', '(function () { try { RegExp.prototype.test.call({}, "a"); } catch (e) { return e instanceof TypeError; } return false; })()#true', '#')]
    [TestCase('Flags of the sticky and unicode regexp', '/a/gimuy.flags#gimuy', '#')]
    procedure Exec_FollowsLastIndexSemantics(const Expression, Expected: string);

    [Test]
    [TestCase('Constructor copies a regexp-like object', '(function () { var o = { source: "b+", flags: "g" }; o[Symbol.match] = true; var r = new RegExp(o); return r.source + r.flags; })()#b+g', '#')]
    [TestCase('Constructor call returns the same regexp', '(function () { var r = /a/; return RegExp(r) === r; })()#true', '#')]
    [TestCase('Constructor call with flags creates a new regexp', 'RegExp(/a/g, "i").flags#i', '#')]
    [TestCase('Constructor call returns a regexp-like object with the same constructor', '(function () { var o = { source: "x", flags: "i", constructor: RegExp }; o[Symbol.match] = true; return RegExp(o) === o; })()#true', '#')]
    [TestCase('Constructor treats a falsy match symbol as no regexp', '(function () { var r = /a/; r[Symbol.match] = false; return RegExp(r) === r; })()#false', '#')]
    [TestCase('Constructor reads the source of a regexp-like object', '(function () { try { (function () { var o = { get source() { throw new RangeError(); } }; o[Symbol.match] = true; new RegExp(o); })(); } catch (e) { return e instanceof RangeError; } return false; })()#true', '#')]
    procedure Constructor_FollowsRegExpProtocol(const Expression, Expected: string);

  end;

implementation

procedure TRegExpProtocolTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpProtocolTests.TearDown;
begin
  FEngine.Free;
end;

function TRegExpProtocolTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TRegExpProtocolTests.Match_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.Replace_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.Search_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.Split_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.ReplaceAll_ReturnsSpecResult(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.Exec_FollowsLastIndexSemantics(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TRegExpProtocolTests.Constructor_FollowsRegExpProtocol(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
