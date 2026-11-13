unit JS4D.Tests.ProtoAccessor;

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
  TProtoAccessorTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('A global var named __proto__ is an own property of the global object', '(function () { return (0, eval)(''var __proto__ = 2; [typeof __proto__, Object.prototype.hasOwnProperty.call(this, \"__proto__\")].join()''); })()#number,true', '#')]
    [TestCase('Object.prototype keeps its prototype', '(function () { try { Object.setPrototypeOf(Object.prototype, {}); } catch (e) { return e.name + '','' + (Object.getPrototypeOf(Object.prototype) === null); } return ''none''; })()#TypeError,true', '#')]
    [TestCase('Object.prototype accepts its current prototype', 'Object.setPrototypeOf(Object.prototype, null) === Object.prototype#true', '#')]
    [TestCase('Object.getOwnPropertyDescriptors defines a __proto__ key as a data property', '(function () { var d = Object.getOwnPropertyDescriptors(JSON.parse(''{\"__proto__\": 1}'')); return Object.keys(d) + '','' + (Object.getPrototypeOf(d) === Object.prototype) + '','' + d.__proto__.value; })()#__proto__,true,1', '#')]
    [TestCase('__proto__ of a plain object is Object.prototype', '({}).__proto__ === Object.prototype#true', '#')]
    [TestCase('__proto__ can be assigned', '(function () { var o = {}; o.__proto__ = Array.prototype; return (o instanceof Array) + '','' + (Object.getPrototypeOf(o) === Array.prototype); })()#true,true', '#')]
    [TestCase('__proto__ is an accessor on Object.prototype', '(function () { var d = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__''); return typeof d.get + '','' + typeof d.set + '','' + d.enumerable + '','' + d.configurable + '','' + (''value'' in d); })()#function,function,false,true,false', '#')]
    [TestCase('The __proto__ accessor functions have names and lengths', '(function () { var d = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__''); return d.get.name + '','' + d.get.length + '','' + d.set.name + '','' + d.set.length; })()#get __proto__,0,set __proto__,1', '#')]
    [TestCase('__proto__ in an object literal sets the prototype', '({ __proto__: Array.prototype }) instanceof Array#true', '#')]
    [TestCase('A quoted __proto__ in an object literal sets the prototype', '({ ''__proto__'': Array.prototype }) instanceof Array#true', '#')]
    [TestCase('__proto__: null in an object literal creates an object without a prototype', 'Object.getPrototypeOf({ __proto__: null }) === null#true', '#')]
    [TestCase('A non-object __proto__ value in an object literal is ignored', 'Object.getPrototypeOf({ __proto__: 1 }) === Object.prototype#true', '#')]
    [TestCase('A computed __proto__ in an object literal is an own property', '(function () { var o = { [''__proto__'']: 5 }; return o.hasOwnProperty(''__proto__'') + '','' + (Object.getPrototypeOf(o) === Object.prototype); })()#true,true', '#')]
    [TestCase('A shorthand __proto__ in an object literal is an own property', '(function () { var __proto__ = 7; var o = { __proto__ }; return o.hasOwnProperty(''__proto__'') + '','' + o.__proto__; })()#true,7', '#')]
    [TestCase('A __proto__ method in an object literal is an own property', '(function () { var o = { __proto__() { return 1; } }; return o.hasOwnProperty(''__proto__'') + '','' + (Object.getPrototypeOf(o) === Object.prototype); })()#true,true', '#')]
    [TestCase('A duplicate __proto__ in an object literal is a SyntaxError', '(function () { try { eval(''({ __proto__: null, __proto__: null })''); } catch (e) { return e.name; } return ''none''; })()#SyntaxError', '#')]
    [TestCase('A __proto__ value and a computed __proto__ may be combined', '(function () { var o = eval(''({ __proto__: Array.prototype, [\"__proto__\"]: 1 })''); return (o instanceof Array) + '','' + o.hasOwnProperty(''__proto__''); })()#true,true', '#')]
    [TestCase('A destructuring pattern may repeat __proto__', '(function () { var o = { __proto__: 1 }; var r = ({ __proto__: a, __proto__: b } = { __proto__: 2 }); return ''ok''; })()#ok', '#')]
    [TestCase('An object without a prototype has no __proto__', 'Object.create(null).__proto__ === undefined#true', '#')]
    [TestCase('Assigning __proto__ on an object without Object.prototype makes an own property', '(function () { var o = Object.create(null); o.__proto__ = 5; return Object.prototype.hasOwnProperty.call(o, ''__proto__'') + '','' + o.__proto__; })()#true,5', '#')]
    [TestCase('The __proto__ setter ignores a non-object value', '(function () { var o = {}; o.__proto__ = 5; return Object.getPrototypeOf(o) === Object.prototype; })()#true', '#')]
    [TestCase('The __proto__ setter accepts null', '(function () { var o = {}; o.__proto__ = null; return Object.getPrototypeOf(o) === null; })()#true', '#')]
    [TestCase('The __proto__ setter rejects a cycle', '(function () { var a = {}; var b = { __proto__: a }; try { a.__proto__ = b; } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('The __proto__ setter rejects a non-extensible object', '(function () { var o = Object.preventExtensions({}); try { o.__proto__ = Array.prototype; } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('The __proto__ setter accepts the current prototype of a non-extensible object', '(function () { var o = Object.preventExtensions({}); o.__proto__ = Object.prototype; return ''ok''; })()#ok', '#')]
    [TestCase('The __proto__ getter works on primitives', '''a''.__proto__ === String.prototype && (1).__proto__ === Number.prototype && true.__proto__ === Boolean.prototype#true', '#')]
    [TestCase('The __proto__ getter raises a TypeError for undefined', '(function () { var g = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__'').get; try { g.call(undefined); } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('The __proto__ setter raises a TypeError for undefined', '(function () { var s = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__'').set; try { s.call(undefined, {}); } catch (e) { return e.name; } return ''none''; })()#TypeError', '#')]
    [TestCase('The __proto__ setter returns undefined and ignores primitives as this', '(function () { var s = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__'').set; return s.call(1, {}) === undefined; })()#true', '#')]
    [TestCase('JSON.parse makes __proto__ an own property', '(function () { var o = JSON.parse(''{\"__proto__\": null}''); return Object.keys(o) + '','' + (Object.getPrototypeOf(o) === Object.prototype); })()#__proto__,true', '#')]
    [TestCase('Object.keys and for-in do not list the inherited __proto__', '(function () { var seen = []; for (var k in {}) { seen.push(k); } return seen.length + '','' + Object.keys({}).length; })()#0,0', '#')]
    [TestCase('A spread copies an own __proto__ property', '(function () { var o = JSON.parse(''{\"__proto__\": 3}''); var c = { ...o }; return c.hasOwnProperty(''__proto__'') + '','' + (Object.getPrototypeOf(c) === Object.prototype); })()#true,true', '#')]
    [TestCase('Object.assign sets the prototype through the accessor', '(function () { var o = JSON.parse(''{\"__proto__\": null}''); var t = Object.assign({}, o); return Object.getPrototypeOf(t) === null; })()#true', '#')]
    [TestCase('__proto__ on a function and an array', '(function () { return (function () {}).__proto__ === Function.prototype && [].__proto__ === Array.prototype; })()#true', '#')]
    [TestCase('__proto__ resolves through the prototype of the global object', 'typeof __proto__#object', '#')]
    [TestCase('Object.getOwnPropertyNames of Object.prototype lists __proto__', 'Object.getOwnPropertyNames(Object.prototype).indexOf(''__proto__'') >= 0#true', '#')]
    [TestCase('A class-less constructor prototype through __proto__ keeps instanceof', '(function () { function A() {} var o = { __proto__: A.prototype }; return o instanceof A; })()#true', '#')]
    [TestCase('__proto__ through Object.defineProperty on the object itself', '(function () { var o = {}; Object.defineProperty(o, ''__proto__'', { value: 1 }); return o.__proto__ + '','' + (Object.getPrototypeOf(o) === Object.prototype); })()#1,true', '#')]
    [TestCase('Deleting __proto__ from Object.prototype removes the accessor', '(function () { var d = Object.getOwnPropertyDescriptor(Object.prototype, ''__proto__''); delete Object.prototype.__proto__; var gone = ({}).__proto__ === undefined; Object.defineProperty(Object.prototype, ''__proto__'', d); return gone + '','' + (({}).__proto__ === Object.prototype); })()#true,true', '#')]
    procedure ProtoAccessor_FollowsAnnexB(const Expression, Expected: string);
  end;

implementation

procedure TProtoAccessorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TProtoAccessorTests.TearDown;
begin
  FEngine.Free;
end;

function TProtoAccessorTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TProtoAccessorTests.ProtoAccessor_FollowsAnnexB(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

end.
