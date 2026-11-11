unit JS4D.Tests.TypedArrays;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine,
  JS4D.BinaryData;

type
  [TestFixture]
  TTypedArrayTests = class
  private
    FEngine: TJSEngine;

    function Evaluate(const Expression: string): string;
    procedure InstallDetach;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Length and byteLength', 'new ArrayBuffer(8).byteLength#8', '#')]
    [TestCase('Tag', 'Object.prototype.toString.call(new ArrayBuffer(1))#[object ArrayBuffer]', '#')]
    [TestCase('Requires new', '(function () { try { ArrayBuffer(1); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Negative length', '(function () { try { new ArrayBuffer(-1); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Huge length', '(function () { try { new ArrayBuffer(7 * 1125899906842624); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Slice copies bytes', '(function () { var a = new Uint8Array([1,2,3,4]); return new Uint8Array(a.buffer.slice(1, 3)).join(); })()#2,3', '#')]
    [TestCase('Slice with negative indexes', '(function () { var a = new Uint8Array([1,2,3,4]); return a.buffer.slice(-2).byteLength; })()#2', '#')]
    [TestCase('isView', '[ArrayBuffer.isView(new Uint8Array(1)), ArrayBuffer.isView(new DataView(new ArrayBuffer(1))), ArrayBuffer.isView(new ArrayBuffer(1)), ArrayBuffer.isView()].join()#true,true,false,false', '#')]
    [TestCase('Species', 'ArrayBuffer[Symbol.species] === ArrayBuffer#true', '#')]
    [TestCase('Slice uses the species constructor', '(function () { var b = new ArrayBuffer(4); var n = 0; b.constructor = { [Symbol.species]: function (l) { n++; return new ArrayBuffer(l); } }; b.slice(0, 2); return n; })()#1', '#')]
    [TestCase('Receiver check', '(function () { try { ArrayBuffer.prototype.slice.call({}, 0); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    procedure ArrayBuffer_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Length constructor', '(function () { var a = new Int16Array(3); return a.length + "," + a.byteLength + "," + a.byteOffset; })()#3,6,0', '#')]
    [TestCase('Elements start at zero', 'new Float64Array(2).join()#0,0', '#')]
    [TestCase('Bytes per element', '[Int8Array, Uint8Array, Uint8ClampedArray, Int16Array, Uint16Array, Int32Array, Uint32Array, Float32Array, Float64Array].map(function (c) { return c.BYTES_PER_ELEMENT; }).join("")#111224448', '#')]
    [TestCase('Prototype bytes per element', 'Int32Array.prototype.BYTES_PER_ELEMENT#4', '#')]
    [TestCase('Constructor names', '[Int8Array, Uint8ClampedArray, Float64Array].map(function (c) { return c.name; }).join()#Int8Array,Uint8ClampedArray,Float64Array', '#')]
    [TestCase('Constructor length', 'Uint8Array.length#3', '#')]
    [TestCase('Requires new', '(function () { try { Int8Array(1); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('From array', 'new Uint8Array([1, 2, 300]).join()#1,2,44', '#')]
    [TestCase('From array-like', 'new Uint8Array({ length: 2, 0: 7, 1: 8 }).join()#7,8', '#')]
    [TestCase('From iterable', 'new Uint8Array(new Set([5, 6])).join()#5,6', '#')]
    [TestCase('From typed array', 'new Float32Array(new Int8Array([-1, 2])).join()#-1,2', '#')]
    [TestCase('From buffer', '(function () { var b = new ArrayBuffer(8); var a = new Int16Array(b, 2, 2); return a.length + "," + a.byteOffset + "," + (a.buffer === b); })()#2,2,true', '#')]
    [TestCase('Unaligned offset', '(function () { try { new Int16Array(new ArrayBuffer(8), 1); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Unaligned buffer length', '(function () { try { new Int16Array(new ArrayBuffer(7)); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Length beyond the buffer', '(function () { try { new Int8Array(new ArrayBuffer(4), 2, 3); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Shared storage', '(function () { var a = new Uint8Array(4); var b = new Uint16Array(a.buffer); b[0] = 0x0102; return a[0] + "," + a[1]; })()#2,1', '#')]
    [TestCase('Prototype chain', 'Object.getPrototypeOf(Int8Array) === Object.getPrototypeOf(Float64Array)#true', '#')]
    [TestCase('Abstract constructor', '(function () { var T = Object.getPrototypeOf(Int8Array); try { new T(); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Tag', 'Object.prototype.toString.call(new Float32Array(1))#[object Float32Array]', '#')]
    [TestCase('Tag on the prototype', 'Object.getOwnPropertyDescriptor(Object.getPrototypeOf(Int8Array.prototype), Symbol.toStringTag).get.call(1)#undefined', '#')]
    [TestCase('Subclass-like prototype', '(function () { function F() {} F.prototype = { x: 1 }; var a = Reflect.construct(Int8Array, [2], F); return Object.getPrototypeOf(a) === F.prototype; })()#true', '#')]
    procedure Constructors_FollowSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Int8 wraps', 'new Int8Array([127, 128, 255, -129]).join()#127,-128,-1,127', '#')]
    [TestCase('Uint8 wraps', 'new Uint8Array([256, -1, 1.9, NaN, Infinity]).join()#0,255,1,0,0', '#')]
    [TestCase('Clamped rounds half to even', 'new Uint8ClampedArray([0.5, 1.5, 2.5, 254.5, 255.5, -3, 300, NaN]).join()#0,2,2,254,255,0,255,0', '#')]
    [TestCase('Int16 wraps', 'new Int16Array([32768, 65535, -32769]).join()#-32768,-1,32767', '#')]
    [TestCase('Uint16 wraps', 'new Uint16Array([65536, -1]).join()#0,65535', '#')]
    [TestCase('Int32 wraps', 'new Int32Array([2147483648, 4294967295, 4294967296]).join()#-2147483648,-1,0', '#')]
    [TestCase('Uint32 wraps', 'new Uint32Array([-1, 4294967296, 4294967297]).join()#4294967295,0,1', '#')]
    [TestCase('Large values wrap', 'new Uint32Array([1e21, -1e21, 2 ** 53 + 2]).join()#3735027712,559939584,2', '#')]
    [TestCase('Float32 rounds', 'new Float32Array([0.1, 16777217, 1e300, -1e300]).join()#0.10000000149011612,16777216,Infinity,-Infinity', '#')]
    [TestCase('Float64 keeps NaN and zero', '(function () { var a = new Float64Array([NaN, -0]); return isNaN(a[0]) + "," + (1 / a[1]); })()#true,-Infinity', '#')]
    [TestCase('Values are converted with ToNumber', 'new Int8Array(["12", true, null, undefined, { valueOf: function () { return 3; } }]).join()#12,1,0,0,3', '#')]
    procedure Elements_AreConverted(const Expression, Expected: string);

    [Test]
    [TestCase('Read in range', 'new Int8Array([5, 6])[1]#6', '#')]
    [TestCase('Read out of range', 'new Int8Array(2)[2]#undefined', '#')]
    [TestCase('Negative index', 'new Int8Array(2)[-1]#undefined', '#')]
    [TestCase('Fractional index', 'new Int8Array(2)["0.5"]#undefined', '#')]
    [TestCase('Negative zero index', 'new Int8Array(2)["-0"]#undefined', '#')]
    [TestCase('Write out of range is ignored', '(function () { var a = new Int8Array(1); a[5] = 1; return a.length + "," + Object.keys(a).join(); })()#1,0', '#')]
    [TestCase('Write out of range in strict mode', '(function () { "use strict"; var a = new Int8Array(1); a[5] = 1; a[-1] = 1; a["1.5"] = 1; return "ok"; })()#ok', '#')]
    [TestCase('Other names are ordinary', '(function () { var a = new Int8Array(1); a.foo = 1; a["01"] = 2; return a.foo + "," + a["01"] + "," + Object.keys(a).join(); })()#1,2,0,foo,01', '#')]
    [TestCase('In operator', '(function () { var a = new Int8Array(2); return (0 in a) + "," + (2 in a) + "," + (-1 in a) + "," + ("length" in a); })()#true,false,false,true', '#')]
    [TestCase('Has own property', '(function () { var a = new Int8Array(2); return a.hasOwnProperty(1) + "," + a.hasOwnProperty(2) + "," + a.hasOwnProperty("length"); })()#true,false,false', '#')]
    [TestCase('Own keys list the indexes first', '(function () { var a = new Int8Array(2); a.x = 1; return Reflect.ownKeys(a).join(); })()#0,1,x', '#')]
    [TestCase('Descriptor of an element', '(function () { var d = Object.getOwnPropertyDescriptor(new Int8Array([9]), "0"); return [d.value, d.writable, d.enumerable, d.configurable].join(); })()#9,true,true,true', '#')]
    [TestCase('Define an element', '(function () { var a = new Int8Array(1); Object.defineProperty(a, "0", { value: 7 }); return a[0]; })()#7', '#')]
    [TestCase('Define with other attributes fails', '(function () { var a = new Int8Array(1); return [Reflect.defineProperty(a, "0", { value: 1, configurable: false }), Reflect.defineProperty(a, "0", { value: 1, writable: false }), Reflect.defineProperty(a, "0", { get: function () {} }), Reflect.defineProperty(a, "1", { value: 1 })].join(); })()#false,false,false,false', '#')]
    [TestCase('Delete', '(function () { var a = new Int8Array(1); return Reflect.deleteProperty(a, "0") + "," + Reflect.deleteProperty(a, "1") + "," + delete a[0] + "," + delete a[3]; })()#false,true,false,true', '#')]
    [TestCase('Delete in strict mode', '(function () { "use strict"; var a = new Int8Array(1); try { delete a[0]; } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Freeze fails with elements', '(function () { try { Object.freeze(new Int8Array(1)); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Freeze of an empty array', 'Object.isFrozen(Object.freeze(new Int8Array(0)))#true', '#')]
    [TestCase('Seal fails with elements', '(function () { try { Object.seal(new Int8Array(1)); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Index from the prototype chain', '(function () { var a = new Int8Array([4]); var o = Object.create(a); return o[0] + "," + o[1]; })()#4,undefined', '#')]
    [TestCase('For-in lists the indexes', '(function () { var r = []; for (var k in new Int8Array(2)) r.push(k); return r.join(); })()#0,1', '#')]
    [TestCase('Set with Reflect', '(function () { var a = new Int8Array(2); return Reflect.set(a, "1", 5) + "," + a[1] + "," + Reflect.set(a, "7", 5); })()#true,5,true', '#')]
    procedure IntegerIndexedObject_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('at', '(function () { var a = new Int8Array([1, 2, 3]); return a.at(0) + "," + a.at(-1) + "," + a.at(3); })()#1,3,undefined', '#')]
    [TestCase('copyWithin', 'new Int8Array([1, 2, 3, 4, 5]).copyWithin(0, 3).join()#4,5,3,4,5', '#')]
    [TestCase('copyWithin overlapping', 'new Int8Array([1, 2, 3, 4, 5]).copyWithin(1, 0, 4).join()#1,1,2,3,4', '#')]
    [TestCase('entries', '[...new Int8Array([7, 8]).entries()].join("|")#0,7|1,8', '#')]
    [TestCase('keys', '[...new Int8Array(2).keys()].join()#0,1', '#')]
    [TestCase('values and iterator', '(function () { var a = new Int8Array([1, 2]); return [...a].join() + "," + (a[Symbol.iterator] === a.values) + "," + (a.values === Array.prototype.values); })()#1,2,true,false', '#')]
    [TestCase('every and some', '(function () { var a = new Int8Array([1, 2, 3]); return a.every(function (x) { return x > 0; }) + "," + a.some(function (x) { return x > 2; }) + "," + a.some(function (x) { return x > 3; }); })()#true,true,false', '#')]
    [TestCase('fill', 'new Int8Array(4).fill(7, 1, 3).join()#0,7,7,0', '#')]
    [TestCase('fill converts once', '(function () { var n = 0; new Int8Array(3).fill({ valueOf: function () { n++; return 1; } }); return n; })()#1', '#')]
    [TestCase('filter', 'new Int8Array([1, 2, 3, 4]).filter(function (x) { return x % 2 === 0; }).join()#2,4', '#')]
    [TestCase('filter keeps the type', 'new Float32Array([1, 2]).filter(function () { return true; }) instanceof Float32Array#true', '#')]
    [TestCase('find and findIndex', '(function () { var a = new Int8Array([5, 6, 7]); return a.find(function (x) { return x > 5; }) + "," + a.findIndex(function (x) { return x > 5; }) + "," + a.findIndex(function (x) { return x > 9; }); })()#6,1,-1', '#')]
    [TestCase('forEach', '(function () { var r = []; new Int8Array([1, 2]).forEach(function (v, i, a) { r.push(v + ":" + i + ":" + a.length); }); return r.join(); })()#1:0:2,2:1:2', '#')]
    [TestCase('includes', '(function () { var a = new Float64Array([1, NaN]); return a.includes(1) + "," + a.includes(NaN) + "," + a.includes(1, 1); })()#true,true,false', '#')]
    [TestCase('indexOf', '(function () { var a = new Int8Array([1, 2, 1]); return a.indexOf(1) + "," + a.indexOf(1, 1) + "," + a.indexOf(1, -1) + "," + a.indexOf(5); })()#0,2,2,-1', '#')]
    [TestCase('lastIndexOf', '(function () { var a = new Int8Array([1, 2, 1]); return a.lastIndexOf(1) + "," + a.lastIndexOf(1, 1) + "," + a.lastIndexOf(1, -4) + "," + a.lastIndexOf(5); })()#2,0,-1,-1', '#')]
    [TestCase('join', '(function () { var a = new Int8Array([1, 2]); return a.join() + "|" + a.join("-") + "|" + a.join(""); })()#1,2|1-2|12', '#')]
    [TestCase('map', 'new Int8Array([1, 2]).map(function (x) { return x * 200; }).join()#-56,-112', '#')]
    [TestCase('reduce', 'new Int8Array([1, 2, 3]).reduce(function (a, b) { return a + b; })#6', '#')]
    [TestCase('reduceRight', 'new Int8Array([1, 2, 3]).reduceRight(function (a, b) { return a + "" + b; })#321', '#')]
    [TestCase('reduce of an empty array', '(function () { try { new Int8Array(0).reduce(function () {}); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('reverse', 'new Int16Array([1, 2, 3]).reverse().join()#3,2,1', '#')]
    [TestCase('set from an array', '(function () { var a = new Int8Array(4); a.set([1, 2], 1); return a.join(); })()#0,1,2,0', '#')]
    [TestCase('set from a typed array', '(function () { var a = new Int8Array(4); a.set(new Float32Array([1.5, 2.5])); return a.join(); })()#1,2,0,0', '#')]
    [TestCase('set on the same buffer', '(function () { var a = new Int8Array([1, 2, 3, 4]); a.set(a.subarray(0, 3), 1); return a.join(); })()#1,1,2,3', '#')]
    [TestCase('set with a negative offset', '(function () { try { new Int8Array(2).set([1], -1); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('set with a too large source', '(function () { try { new Int8Array(2).set([1, 2, 3]); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('slice', 'new Int8Array([1, 2, 3, 4]).slice(1, -1).join()#2,3', '#')]
    [TestCase('slice into another type', '(function () { var a = new Int8Array([1, 2, 3]); a.constructor = { [Symbol.species]: Float32Array }; var s = a.slice(1); return (s instanceof Float32Array) + "," + s.join(); })()#true,2,3', '#')]
    [TestCase('sort numerically', 'new Int8Array([10, 9, -1, 2]).sort().join()#-1,2,9,10', '#')]
    [TestCase('sort floats', 'new Float64Array([NaN, 3, -0, 0, -Infinity, 1]).sort().join()#-Infinity,0,0,1,3,NaN', '#')]
    [TestCase('sort negative zero first', '(function () { var a = new Float64Array([0, -0]).sort(); return (1 / a[0]) + "," + (1 / a[1]); })()#-Infinity,Infinity', '#')]
    [TestCase('sort with a comparer', 'new Int8Array([1, 3, 2]).sort(function (a, b) { return b - a; }).join()#3,2,1', '#')]
    [TestCase('sort is stable', '(function () { var a = new Int8Array([1, 2, 3, 4, 5, 6]); a.sort(function (x, y) { return (x % 2) - (y % 2); }); return a.join(); })()#2,4,6,1,3,5', '#')]
    [TestCase('sort rejects a bad comparer', '(function () { try { new Int8Array(1).sort(1); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('subarray shares the buffer', '(function () { var a = new Int8Array([1, 2, 3]); var s = a.subarray(1); s[0] = 9; return a.join() + "," + s.byteOffset + "," + (s.buffer === a.buffer); })()#1,9,3,1,true', '#')]
    [TestCase('subarray with negative indexes', 'new Int8Array([1, 2, 3, 4]).subarray(-3, -1).join()#2,3', '#')]
    [TestCase('toString', '(function () { var a = new Int8Array([1, 2]); return a.toString() + "," + (Int8Array.prototype.toString === Array.prototype.toString); })()#1,2,true', '#')]
    [TestCase('toLocaleString', 'new Int8Array([1, 2]).toLocaleString()#1,2', '#')]
    [TestCase('Method on a plain object', '(function () { try { Int8Array.prototype.fill.call([], 1); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Accessors on the wrong receiver', '(function () { var g = Object.getOwnPropertyDescriptor(Object.getPrototypeOf(Int8Array.prototype), "length").get; try { g.call({}); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Method lengths', '(function () { var p = Object.getPrototypeOf(Int8Array.prototype); return ["at", "copyWithin", "fill", "indexOf", "set", "slice", "subarray", "sort", "map", "reduce", "toLocaleString"].map(function (n) { return p[n].length; }).join(""); })()#12111221110', '#')]
    procedure Methods_FollowSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('from array', 'Int8Array.from([1, 2]).join()#1,2', '#')]
    [TestCase('from with a mapper', 'Int8Array.from([1, 2], function (x, i) { return x * 10 + i; }).join()#10,21', '#')]
    [TestCase('from a string', 'Uint8Array.from("123").join()#1,2,3', '#')]
    [TestCase('from an array-like', 'Uint8Array.from({ length: 2, 0: 3, 1: 4 }).join()#3,4', '#')]
    [TestCase('from with a non-callable mapper', '(function () { try { Int8Array.from([], 1); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('from on a non-constructor', '(function () { try { Int8Array.from.call({}, []); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('of', 'Float32Array.of(1, 2.5).join()#1,2.5', '#')]
    [TestCase('Species', '(function () { var T = Object.getPrototypeOf(Int8Array); return T[Symbol.species] === T; })()#true', '#')]
    procedure Statics_FollowSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Set and get', '(function () { var v = new DataView(new ArrayBuffer(8)); v.setInt16(0, -2); return v.getInt16(0) + "," + v.getUint16(0); })()#-2,65534', '#')]
    [TestCase('Endianness', '(function () { var v = new DataView(new ArrayBuffer(4)); v.setUint16(0, 0x0102); v.setUint16(2, 0x0102, true); return [v.getUint8(0), v.getUint8(1), v.getUint8(2), v.getUint8(3)].join(); })()#1,2,2,1', '#')]
    [TestCase('Floats', '(function () { var v = new DataView(new ArrayBuffer(12)); v.setFloat32(0, 1.5); v.setFloat64(4, -2.25, true); return v.getFloat32(0) + "," + v.getFloat64(4, true); })()#1.5,-2.25', '#')]
    [TestCase('Int32 and Uint32', '(function () { var v = new DataView(new ArrayBuffer(4)); v.setUint32(0, 4294967295); return v.getInt32(0) + "," + v.getUint32(0); })()#-1,4294967295', '#')]
    [TestCase('Int8 and Uint8', '(function () { var v = new DataView(new ArrayBuffer(1)); v.setInt8(0, 200); return v.getInt8(0) + "," + v.getUint8(0); })()#-56,200', '#')]
    [TestCase('Offset and length', '(function () { var v = new DataView(new ArrayBuffer(8), 2, 4); return v.byteOffset + "," + v.byteLength; })()#2,4', '#')]
    [TestCase('Default length', '(function () { var v = new DataView(new ArrayBuffer(8), 3); return v.byteLength; })()#5', '#')]
    [TestCase('Buffer', '(function () { var b = new ArrayBuffer(2); return new DataView(b).buffer === b; })()#true', '#')]
    [TestCase('Shares bytes with typed arrays', '(function () { var b = new ArrayBuffer(2); new DataView(b).setUint8(1, 9); return new Uint8Array(b).join(); })()#0,9', '#')]
    [TestCase('Out of range read', '(function () { try { new DataView(new ArrayBuffer(2)).getInt32(0); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Out of range write', '(function () { try { new DataView(new ArrayBuffer(2)).setInt8(2, 0); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Negative index', '(function () { try { new DataView(new ArrayBuffer(2)).getInt8(-1); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Offset beyond the buffer', '(function () { try { new DataView(new ArrayBuffer(2), 3); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Length beyond the buffer', '(function () { try { new DataView(new ArrayBuffer(2), 1, 2); } catch (e) { return e instanceof RangeError; } })()#true', '#')]
    [TestCase('Not a buffer', '(function () { try { new DataView({}); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Requires new', '(function () { try { DataView(new ArrayBuffer(1)); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Tag', 'Object.prototype.toString.call(new DataView(new ArrayBuffer(1)))#[object DataView]', '#')]
    [TestCase('Method lengths', '[DataView.prototype.getInt8.length, DataView.prototype.setInt8.length, DataView.prototype.getFloat64.length, DataView.prototype.setFloat64.length, DataView.length].join("")#12121', '#')]
    [TestCase('Receiver check', '(function () { try { DataView.prototype.getInt8.call({}, 0); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    procedure DataView_FollowsSpecification(const Expression, Expected: string);

    [Test]
    [TestCase('Length', '(function () { var a = new Int8Array(4); detach(a.buffer); return a.length + "," + a.byteLength + "," + a.byteOffset; })()#0,0,0', '#')]
    [TestCase('Buffer byteLength', '(function () { var b = new ArrayBuffer(4); detach(b); return b.byteLength; })()#0', '#')]
    [TestCase('Elements', '(function () { var a = new Int8Array(4); detach(a.buffer); return a[0] + "," + (0 in a) + "," + Object.keys(a).length; })()#undefined,false,0', '#')]
    [TestCase('Write is ignored', '(function () { "use strict"; var a = new Int8Array(4); detach(a.buffer); a[0] = 1; return "ok"; })()#ok', '#')]
    [TestCase('Methods throw', '(function () { var a = new Int8Array(4); detach(a.buffer); try { a.fill(0); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Constructor throws', '(function () { var b = new ArrayBuffer(4); detach(b); try { new Int8Array(b); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Slice throws', '(function () { var b = new ArrayBuffer(4); detach(b); try { b.slice(0); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('DataView throws', '(function () { var b = new ArrayBuffer(4); var v = new DataView(b); detach(b); try { v.getInt8(0); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    [TestCase('Detaching during a conversion', '(function () { var a = new Int8Array(2); a[0] = { valueOf: function () { detach(a.buffer); return 1; } }; return a.length; })()#0', '#')]
    [TestCase('Iterator throws', '(function () { var a = new Int8Array(2); var it = a[Symbol.iterator](); it.next(); detach(a.buffer); try { it.next(); } catch (e) { return e instanceof TypeError; } })()#true', '#')]
    procedure DetachedBuffer_FollowsSpecification(const Expression, Expected: string);

    [Test]
    procedure Elements_OfLargeArrays_StayFast;
  end;

implementation

procedure TTypedArrayTests.Setup;
begin
  FEngine := TJSEngine.Create;
  InstallDetach;
end;

procedure TTypedArrayTests.TearDown;
begin
  FEngine.Free;
end;

procedure TTypedArrayTests.InstallDetach;
begin
  FEngine.RegisterFunction('detach',
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Buffer: IJSArrayBuffer;
      if Supports(Args[0].ToObject, IJSArrayBuffer, Buffer) then
        Buffer.Detach;

      Result := TJSValue.CreateUndefined;
    end);
end;

function TTypedArrayTests.Evaluate(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Format('String(%s)', [Expression])).ToString;
end;

procedure TTypedArrayTests.ArrayBuffer_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.Constructors_FollowSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.Elements_AreConverted(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.IntegerIndexedObject_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.Methods_FollowSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.Statics_FollowSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.DataView_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.DetachedBuffer_FollowsSpecification(const Expression, Expected: string);
begin
  Assert.AreEqual(Expected, Evaluate(Expression));
end;

procedure TTypedArrayTests.Elements_OfLargeArrays_StayFast;
begin
  const Script = '(function () { var a = new Float64Array(200000); for (var i = 0; i < a.length; i++) { a[i] = i; } ' +
                 'var sum = 0; for (var j = 0; j < a.length; j++) { sum += a[j]; } return sum; })()';

  Assert.AreEqual('19999900000', Evaluate(Script));
end;

end.
