unit JS4D.Tests.ArrayConversion;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TArrayConversionTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('String uses an own toString of the array', '(function () { var a = [1, 2]; a.toString = function () { return ''X''; }; return String(a); })()#X', '#')]
    [TestCase('Addition uses an own toString of the array', '(function () { var a = [1, 2]; a.toString = function () { return ''X''; }; return a + ''''; })()#X', '#')]
    [TestCase('A property key uses an own toString of the array', '(function () { var a = [1, 2]; a.toString = function () { return ''X''; }; var o = { X: 7 }; return o[a]; })()#7', '#')]
    [TestCase('String uses an own Symbol.toPrimitive of the array with the hint string', '(function () { var a = [1]; a[Symbol.toPrimitive] = function (h) { return ''P'' + h; }; return String(a); })()#Pstring', '#')]
    [TestCase('Addition uses an own Symbol.toPrimitive of the array with the hint default', '(function () { var a = [1]; a[Symbol.toPrimitive] = function (h) { return ''P'' + h; }; return a + ''''; })()#Pdefault', '#')]
    [TestCase('A property key uses an own Symbol.toPrimitive of the array', '(function () { var a = [1]; a[Symbol.toPrimitive] = function (h) { return ''P'' + h; }; var o = {}; o[''Pstring''] = 3; return o[a]; })()#3', '#')]
    [TestCase('A replaced Array.prototype.toString is used', '(function () { var s = Array.prototype.toString; Array.prototype.toString = function () { return ''T''; }; try { return String([1]) + [2]; } finally { Array.prototype.toString = s; } })()#TT', '#')]
    [TestCase('A replaced Array.prototype.join is used by toString', '(function () { var s = Array.prototype.join; Array.prototype.join = function () { return ''J''; }; try { return String([1, 2]); } finally { Array.prototype.join = s; } })()#J', '#')]
    [TestCase('A Symbol.toPrimitive on Object.prototype is used by arrays', '(function () { Object.prototype[Symbol.toPrimitive] = function () { return ''O''; }; try { return String([1]); } finally { delete Object.prototype[Symbol.toPrimitive]; } })()#O', '#')]
    [TestCase('A replaced Array.prototype.valueOf is used by addition', '(function () { var s = Array.prototype.valueOf; Array.prototype.valueOf = function () { return 5; }; try { return [1] + 1; } finally { delete Array.prototype.valueOf; } })()#6', '#')]
    [TestCase('A nested array with its own toString is converted through it', '(function () { var i = [1]; i.toString = function () { return ''I''; }; return String([i, 2]); })()#I,2', '#')]
    [TestCase('A toString that is not callable is skipped', '(function () { var a = [1]; a.toString = 5; a.valueOf = function () { return ''V''; }; return String(a); })()#V', '#')]
    [TestCase('Without a usable conversion String raises a TypeError', '(function () { var a = [1]; a.toString = null; try { String(a); } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('An own join is used by the inherited toString', '(function () { var a = [1, 2]; a.join = function () { return ''OJ''; }; return String(a); })()#OJ', '#')]
    [TestCase('An own join is used by addition', '(function () { var a = [1, 2]; a.join = function () { return ''OJ''; }; return a + ''''; })()#OJ', '#')]
    [TestCase('A Symbol.toPrimitive that returns an object raises a TypeError', '(function () { var a = [1]; a[Symbol.toPrimitive] = function () { return {}; }; try { String(a); } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('A getter for toString runs once', '(function () { var n = 0; var a = [1]; Object.defineProperty(a, ''toString'', { get: function () { n++; return function () { return ''G''; }; } }); return String(a) + n; })()#G1', '#')]
    [TestCase('An untouched array converts as before', 'String([1, [2, 3], [], null, undefined, ''x''])#1,2,3,,,,x', '#')]
    [TestCase('An untouched array in a property key converts as before', '(function () { var o = {}; o[[1, 2]] = 5; return Object.keys(o); })()#1,2', '#')]
    [TestCase('A cyclic array converts to an empty element', '(function () { var a = [1]; a[1] = a; var text = String(a); a.length = 0; return text; })()#1,', '#')]
    [TestCase('Addition of untouched arrays concatenates their text', '[1, 2] + [3] + ''''#1,23', '#')]
    [TestCase('A conversion after Array.prototype.toString was replaced and restored', '(function () { var r = String([1]); var s = Array.prototype.toString; Array.prototype.toString = function () { return ''T''; }; r += String([1]); Array.prototype.toString = s; return r + String([1]); })()#1T1', '#')]
    [TestCase('A conversion after Array.prototype.join was deleted and restored', '(function () { var r = String([1, 2]); var j = Array.prototype.join; delete Array.prototype.join; r += String([1, 2]); Array.prototype.join = j; return r + String([1, 2]); })()#1,2[object Array]1,2', '#')]
    [TestCase('A conversion after a Symbol.toPrimitive was added to and deleted from Array.prototype', '(function () { var r = String([1]); Array.prototype[Symbol.toPrimitive] = function () { return ''P''; }; r += String([1]) + ([1] + ''''); delete Array.prototype[Symbol.toPrimitive]; return r + String([1]); })()#1PP1', '#')]
    [TestCase('A conversion after a Symbol.toPrimitive was added to and deleted from Object.prototype', '(function () { var r = String([1]); Object.prototype[Symbol.toPrimitive] = function () { return ''O''; }; r += String([1]); delete Object.prototype[Symbol.toPrimitive]; return r + String([1]); })()#1O1', '#')]
    [TestCase('A conversion after Object.prototype.valueOf was replaced and restored', '(function () { var r = [1] + ''''; var v = Object.prototype.valueOf; Object.prototype.valueOf = function () { return 7; }; r += [1] + ''''; Object.prototype.valueOf = v; return r + ([1] + ''''); })()#171', '#')]
    [TestCase('A conversion after the prototype of Array.prototype changed', '(function () { var r = String([1]); var p = Object.getPrototypeOf(Array.prototype); Object.setPrototypeOf(Array.prototype, { [Symbol.toPrimitive]: function () { return ''Q''; } }); r += String([1]); Object.setPrototypeOf(Array.prototype, p); return r + String([1]); })()#1Q1', '#')]
    [TestCase('A conversion of an array with another prototype', '(function () { var a = [1]; String(a); Object.setPrototypeOf(a, { toString: function () { return ''S''; } }); return String(a); })()#S', '#')]
    [TestCase('A conversion of an array whose own property was added after a conversion', '(function () { var a = [1]; var r = String(a); a.x = 1; r += String(a); a.join = function () { return ''J''; }; return r + String(a); })()#11J', '#')]
    [TestCase('Repeated conversions of an array as a property key', '(function () { var o = { 1: ''a'' }; var a = [1]; var r = ''''; for (var i = 0; i < 3; i++) { r += o[a]; } var s = Array.prototype.toString; Array.prototype.toString = function () { return ''x''; }; o.x = ''b''; r += o[a]; Array.prototype.toString = s; return r + o[a]; })()#aaaba', '#')]
    procedure ArrayConversion_HonoursConversionHooks(const Expression, Expected: string);

    [Test]
    procedure ArrayConversion_CycleThroughNativeHooks_EndsInALimitError;
  end;

implementation

procedure TArrayConversionTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayConversionTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayConversionTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TArrayConversionTests.ArrayConversion_HonoursConversionHooks(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TArrayConversionTests.ArrayConversion_CycleThroughNativeHooks_EndsInALimitError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute('var a = [1]; a[1] = a; a.toString = Function.prototype.call.bind(Array.prototype.join, a); String(a);');
    end,
    EJSCallDepthExceeded);

  FEngine.Execute('a.length = 0; a.toString = null;');
end;

end.
