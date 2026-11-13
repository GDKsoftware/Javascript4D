unit JS4D.Tests.PropertyKeys;

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
  TPropertyKeyTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('A string that looks like a symbol key reads nothing', '(function () { var s = Symbol(''x''); var o = {}; o[s] = 1; var hits = 0; for (var i = 0; i < 3000; i++) { if (o[''\uFDD0'' + i] !== undefined) { hits++; } } return hits; })()#0', '#')]
    [TestCase('A string that looks like a symbol key is not in the object', '(function () { var s = Symbol(''x''); var o = {}; o[s] = 1; var hits = 0; for (var i = 0; i < 3000; i++) { if ((''\uFDD0'' + i) in o) { hits++; } } return hits; })()#0', '#')]
    [TestCase('Writing a string that looks like a symbol key leaves the symbol alone', '(function () { var s = Symbol(''x''); var o = {}; o[s] = 1; for (var i = 0; i < 3000; i++) { o[''\uFDD0'' + i] = 2; } return o[s] + '','' + Object.getOwnPropertySymbols(o).length + '','' + Object.keys(o).length; })()#1,1,3000', '#')]
    [TestCase('Deleting a string that looks like a symbol key leaves the symbol alone', '(function () { var s = Symbol(''x''); var o = {}; o[s] = 1; for (var i = 0; i < 3000; i++) { delete o[''\uFDD0'' + i]; } return o[s]; })()#1', '#')]
    [TestCase('A symbol key still reads through its symbol', '(function () { var s = Symbol(''x''); var o = { [s]: 5 }; return o[s] + '','' + (s in o) + '','' + o.hasOwnProperty(s); })()#5,true,true', '#')]
    [TestCase('A string key that starts with the marker character is listed unchanged', '(function () { var o = {}; o[''\uFDD0abc''] = 1; o[''\uFDD0''] = 2; o[''\uFDD0'' + ''5''] = 3; var k = Object.keys(o); return k.length + '','' + (k[0] === ''\uFDD0abc'') + '','' + (k[1] === ''\uFDD0'') + '','' + (k[2] === ''\uFDD05''); })()#3,true,true,true', '#')]
    [TestCase('A string key that starts with the marker character is found again', '(function () { var o = { ''\uFDD0S'': 1 }; o[''\uFDD0''] = 2; return o[''\uFDD0S''] + '','' + o[''\uFDD0''] + '','' + Object.getOwnPropertyNames(o).length; })()#1,2,2', '#')]
    [TestCase('A string key that starts with the marker character is enumerated by for-in', '(function () { var o = { ''\uFDD07'': 1 }; var seen = []; for (var k in o) { seen.push(k === ''\uFDD07''); } return seen; })()#true', '#')]
    [TestCase('A string key that starts with the marker character survives JSON', '(function () { var o = JSON.parse(''{\"\uFDD0100\": 1}''); return Object.keys(o).length + '','' + (Object.keys(o)[0] === ''\uFDD0100''); })()#1,true', '#')]
    [TestCase('JSON.parse with a key that looks like a symbol does not read a symbol', '(function () { var s = Symbol(); var o = {}; o[s] = 1; var hits = 0; for (var i = 0; i < 3000; i++) { if (JSON.parse(''{\"\uFDD0'' + i + ''\": 7}'')[''\uFDD0'' + i] !== 7) { hits++; } } return hits + '','' + o[s]; })()#0,1', '#')]
    [TestCase('Object.assign copies string keys that start with the marker character', '(function () { var o = Object.assign({}, { ''\uFDD0z'': 4 }); return o[''\uFDD0z''] + '','' + Object.keys(o).length; })()#4,1', '#')]
    [TestCase('Spread copies string keys that start with the marker character', '(function () { var o = { ...{ ''\uFDD0z'': 4 } }; return o[''\uFDD0z''] + '','' + Object.keys(o).length; })()#4,1', '#')]
    [TestCase('A proxy trap sees a marker string as a string and a symbol as a symbol', '(function () { var seen = []; var p = new Proxy({}, { get: function (t, k) { seen.push(typeof k); return 1; } }); var s = Symbol(); p[''\uFDD0100'']; p[s]; return seen; })()#string,symbol', '#')]
    [TestCase('Reflect.ownKeys lists a marker string as a string', '(function () { var s = Symbol(''q''); var o = { ''\uFDD0100'': 1, [s]: 2 }; var k = Reflect.ownKeys(o); return typeof k[0] + '','' + typeof k[1] + '','' + (k[0] === ''\uFDD0100''); })()#string,symbol,true', '#')]
    [TestCase('An array keeps marker strings and symbols apart', '(function () { var s = Symbol(); var a = [1]; a[s] = 2; a[''\uFDD0100''] = 3; return a[s] + '','' + a[''\uFDD0100''] + '','' + Object.keys(a).length; })()#2,3,2', '#')]
    [TestCase('A function keeps marker strings and symbols apart', '(function () { var s = Symbol(); var f = function () {}; f[s] = 2; f[''\uFDD0100''] = 3; return f[s] + '','' + f[''\uFDD0100'']; })()#2,3', '#')]
    [TestCase('Object.defineProperty with a marker string defines a string property', '(function () { var o = {}; Object.defineProperty(o, ''\uFDD0100'', { value: 1, enumerable: true }); return Object.getOwnPropertySymbols(o).length + '','' + Object.keys(o).length; })()#0,1', '#')]
    [TestCase('Object.getOwnPropertyDescriptor with a marker string reads a string property', '(function () { var s = Symbol(); var o = { [s]: 1 }; return Object.getOwnPropertyDescriptor(o, ''\uFDD0100'') === undefined; })()#true', '#')]
    [TestCase('A Map keeps marker strings and symbols apart', '(function () { var s = Symbol(); var m = new Map([[s, 1], [''\uFDD0100'', 2]]); return m.size + '','' + m.get(s) + '','' + m.get(''\uFDD0100''); })()#2,1,2', '#')]
    [TestCase('A symbol wrapper keeps marker strings apart', '(function () { var s = Symbol(); var w = Object(s); w[s] = 1; return w[''\uFDD0100''] === undefined; })()#true', '#')]
    [TestCase('A computed method name keeps a marker string', '(function () { var o = { [''\uFDD0100'']() { return 1; } }; return o[''\uFDD0100''].name === ''\uFDD0100''; })()#true', '#')]
    [TestCase('Object.entries returns marker strings unchanged', '(function () { var o = { ''\uFDD0100'': 1 }; return Object.entries(o)[0][0] === ''\uFDD0100''; })()#true', '#')]
    procedure PropertyKey_SeparatesStringsFromSymbols(const Expression, Expected: string);
  end;

implementation

procedure TPropertyKeyTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPropertyKeyTests.TearDown;
begin
  FEngine.Free;
end;

function TPropertyKeyTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TPropertyKeyTests.PropertyKey_SeparatesStringsFromSymbols(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
