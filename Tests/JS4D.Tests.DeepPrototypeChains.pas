unit JS4D.Tests.DeepPrototypeChains;

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
  TDeepPrototypeChainTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('A chain that mixes arrays, string wrappers, typed arrays and functions', '(function () { var makers = [function () { return [7]; }, function () { return new String(''xy''); }, function () { return new Uint8Array([5, 6]); }, function () { return function () {}; }, function () { return {}; }]; var o = { deep: 1 }; for (var i = 0; i < 2500; i++) { var n = makers[i % 5](); Object.setPrototypeOf(n, o); o = n; } return o.deep + '','' + (''deep'' in o) + '','' + (''nothing'' in o) + '','' + o[0] + '','' + (1 in o) + '','' + o.length; })()#1,true,false,5,true,0', '#')]
    [TestCase('A property is found at the end of a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return o.deep; })()#1', '#')]
    [TestCase('A missing property is not found in a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return o.missing; })()#undefined', '#')]
    [TestCase('The in operator walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return (''deep'' in o) + '','' + (''nothing'' in o); })()#true,false', '#')]
    [TestCase('An assignment walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } o.x = 5; o.deep = 6; return o.x + '','' + o.deep + '','' + root.deep + '','' + Object.keys(o); })()#5,6,1,x,deep', '#')]
    [TestCase('A getter at the end of a 100000 object chain gets the receiver', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } o.tag = ''T''; return o.acc; })()#T', '#')]
    [TestCase('A setter at the end of a 100000 object chain gets the receiver', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } o.sink = 3; return o.got + '','' + o.hasOwnProperty(''sink'') + '','' + root.hasOwnProperty(''got''); })()#3,false,false', '#')]
    [TestCase('isPrototypeOf walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return root.isPrototypeOf(o) + '','' + Array.prototype.isPrototypeOf(o) + '','' + Object.prototype.isPrototypeOf(o); })()#true,false,true', '#')]
    [TestCase('instanceof walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } function F() {} F.prototype = root; return (o instanceof F) + '','' + (o instanceof Array); })()#true,false', '#')]
    [TestCase('for-in walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } o.own = 1; var seen = []; for (var k in o) { seen.push(k); } return seen; })()#own,deep,acc,sink', '#')]
    [TestCase('Object.getPrototypeOf walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } var n = 0; var p = o; while (p !== root) { p = Object.getPrototypeOf(p); n++; } return n; })()#100000', '#')]
    [TestCase('Setting a prototype below a 100000 object chain detects a cycle', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } try { Object.setPrototypeOf(root, o); } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('A deep chain with a typed array, an array and a primitive wrapper at the end', '(function () { var o = [1, 2]; for (var i = 0; i < 100000; i++) { o = Object.create(o); } o.x = 1; return o[1] + '','' + o.length + '','' + (''1'' in o) + '','' + o.x; })()#2,2,true,1', '#')]
    [TestCase('hasOwnProperty on a deep chain stays local', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return o.hasOwnProperty(''deep'') + '','' + root.hasOwnProperty(''deep''); })()#false,true', '#')]
    [TestCase('Reflect.get walks a 100000 object chain', '(function () { var root = { deep: 1, get acc() { return this.tag; }, set sink(v) { this.got = v; } }; var o = root; for (var i = 0; i < 100000; i++) { o = Object.create(o); } return Reflect.get(o, ''deep'') + '','' + Reflect.has(o, ''deep'') + '','' + Reflect.set(o, ''y'', 2) + '','' + o.y; })()#1,true,true,2', '#')]
    procedure DeepChain_Lookup_DoesNotOverflowTheStack(const Expression, Expected: string);
  end;

implementation

procedure TDeepPrototypeChainTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDeepPrototypeChainTests.TearDown;
begin
  FEngine.Free;
end;

function TDeepPrototypeChainTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TDeepPrototypeChainTests.DeepChain_Lookup_DoesNotOverflowTheStack(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
