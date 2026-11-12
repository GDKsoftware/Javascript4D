unit JS4D.Tests.ArrayPrototypeSemantics;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArrayPrototypeSemanticsTests = class
  private
    FEngine: TJSEngine;

    function EvaluateText(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Skips null and undefined', '[1, null, undefined, 2].toLocaleString()#1,,,2', '#')]
    [TestCase('Invokes the element method', '[{ toLocaleString: function () { return "x"; } }, 3].toLocaleString()#x,3', '#')]
    [TestCase('Passes no arguments', '[{ toLocaleString: function () { return arguments.length; } }].toLocaleString("nl", {})#0', '#')]
    [TestCase('Array like receiver', 'Array.prototype.toLocaleString.call({ length: 2, 0: "a", 1: "b" })#a,b', '#')]
    [TestCase('Own method of the prototype', 'String(Array.prototype.hasOwnProperty("toLocaleString"))#true', '#')]
    [TestCase('Method is not a constructor', 'try { new Array.prototype.toLocaleString(); } catch (e) { e.name; }#TypeError', '#')]
    [TestCase('Missing element method', 'try { [{ toLocaleString: 1 }].toLocaleString(); } catch (e) { e.name; }#TypeError', '#')]
    procedure ToLocaleString_Receiver_ReturnsText(const Script: string; const Expected: string);

    [Test]
    [TestCase('Null', 'null')]
    [TestCase('Number', '42')]
    [TestCase('String', '"x"')]
    [TestCase('Object', '{}')]
    [TestCase('Boolean', 'true')]
    procedure Sort_ComparerIsNotCallable_ThrowsBeforeReadingLength(const Comparer: string);

    [Test]
    procedure Sort_ComparerIsUndefined_SortsByText;

    [Test]
    [TestCase('Missing elements are read', 'var log = []; var p = new Proxy({ length: 4 }, { get: function (t, k) { log.push(String(k)); return k === "length" ? 4 : k * 10; } }); [].includes.call(p, 42); log.join()#length,0,1,2,3', '#')]
    [TestCase('Stops at the match', 'var log = []; var p = new Proxy({ length: 4 }, { get: function (t, k) { log.push(String(k)); return k === "length" ? 4 : k * 10; } }); [].includes.call(p, 10); log.join()#length,0,1', '#')]
    [TestCase('Does not test for presence', 'var log = []; var p = new Proxy([1, 2], { has: function (t, k) { log.push(String(k)); return k in t; } }); [].includes.call(p, 2); log.join()#', '#')]
    procedure Includes_Proxy_ReadsEveryElementOnce(const Script: string; const Expected: string);

    [Test]
    [TestCase('Concat', 'concat')]
    [TestCase('Filter', 'filter')]
    [TestCase('Map', 'map')]
    [TestCase('Slice', 'slice')]
    [TestCase('Splice', 'splice')]
    procedure Method_ReceiverIsProxyOfArray_UsesTheSpeciesConstructor(const MethodName: string);

    [Test]
    procedure Method_ReceiverIsRevokedProxy_ThrowsTypeError;

    [Test]
    procedure Method_ReceiverIsProxyOfObject_CreatesPlainArray;

    [Test]
    [TestCase('Flat', 'flat')]
    [TestCase('FlatMap', 'flatMap')]
    procedure Flatten_ProxyReceiver_ReadsConstructorAfterLength(const MethodName: string);

    [Test]
    [TestCase('Array.isArray', 'Array.isArray(Array.prototype)#true', '#')]
    [TestCase('Initial length', 'String(Array.prototype.length)#0', '#')]
    [TestCase('Class tag', 'Object.prototype.toString.call(Array.prototype)#[object Array]', '#')]
    [TestCase('Index updates the length', 'Array.prototype[2] = 42; var n = Array.prototype.length; delete Array.prototype[2]; Array.prototype.length = 0; String(n)#3', '#')]
    [TestCase('Length truncates', 'Array.prototype[1] = 1; Array.prototype.length = 0; String(Array.prototype[1])#undefined', '#')]
    [TestCase('Instances do not share its length', 'String([].length)#0', '#')]
    [TestCase('Has an own length', 'String(Object.getOwnPropertyNames(Array.prototype).indexOf("length") >= 0)#true', '#')]
    procedure ArrayPrototype_IsAnArrayExoticObject(const Script: string; const Expected: string);

    [Test]
    [TestCase('Push', 'push')]
    [TestCase('Unshift', 'unshift')]
    procedure Method_PrototypeSetterLocksTheLength_ThrowsTypeError(const MethodName: string);

    [Test]
    procedure Push_PrototypeSetterFreezesTheArray_ThrowsTypeError;

    [Test]
    procedure Push_NoIndexedPrototypeProperty_AppendsDirectly;
  end;

implementation

procedure TArrayPrototypeSemanticsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayPrototypeSemanticsTests.TearDown;
begin
  FEngine.Free;
end;

function TArrayPrototypeSemanticsTests.EvaluateText(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

procedure TArrayPrototypeSemanticsTests.ToLocaleString_Receiver_ReturnsText(const Script: string;
                                                                            const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Sort_ComparerIsNotCallable_ThrowsBeforeReadingLength(const Comparer: string);
begin
  const Script = Format(
    'var poisoned = { get length() { throw new Error("length read"); } };' +
    'var names = [];' +
    'try { [1].sort(%0:s); } catch (e) { names.push(e.name); }' +
    'try { [].sort.call(poisoned, %0:s); } catch (e) { names.push(e.name); }' +
    'names.join()',
    [Comparer]);

  Assert.AreEqual('TypeError,TypeError', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Sort_ComparerIsUndefined_SortsByText;
begin
  Assert.AreEqual('1,10,2', EvaluateText('[10, 2, 1].sort(undefined).join()'));
end;

procedure TArrayPrototypeSemanticsTests.Includes_Proxy_ReadsEveryElementOnce(const Script: string;
                                                                             const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Method_ReceiverIsProxyOfArray_UsesTheSpeciesConstructor(
  const MethodName: string);
begin
  const Script = Format(
    'var array = [1, 2];' +
    'var proxy = new Proxy(new Proxy(array, {}), {});' +
    'var Ctor = function () {};' +
    'array.constructor = function () {};' +
    'array.constructor[Symbol.species] = Ctor;' +
    'var result = Array.prototype.%s.call(proxy, function (x) { return true; });' +
    'String(Object.getPrototypeOf(result) === Ctor.prototype)',
    [MethodName]);

  Assert.AreEqual('true', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Method_ReceiverIsRevokedProxy_ThrowsTypeError;
begin
  const Script =
    'var r = Proxy.revocable([], {}); r.revoke();' +
    'try { Array.prototype.map.call(r.proxy, function () {}); "none"; } catch (e) { e.name; }';

  Assert.AreEqual('TypeError', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Method_ReceiverIsProxyOfObject_CreatesPlainArray;
begin
  const Script =
    'var proxy = new Proxy({ length: 1, 0: "a", constructor: { [Symbol.species]: function () { throw 1; } } }, {});' +
    'String(Array.isArray(Array.prototype.slice.call(proxy)))';

  Assert.AreEqual('true', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Flatten_ProxyReceiver_ReadsConstructorAfterLength(const MethodName: string);
begin
  const Script = Format(
    'var gets = [];' +
    'var proxy = new Proxy([1, [2]], { get: function (t, k, r) { gets.push(String(k)); return Reflect.get(t, k, r); } });' +
    'Array.prototype.%s.call(proxy, function (x) { return x; });' +
    'gets.slice(0, 2).join()',
    [MethodName]);

  Assert.AreEqual('length,constructor', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.ArrayPrototype_IsAnArrayExoticObject(const Script: string;
                                                                             const Expected: string);
begin
  Assert.AreEqual(Expected, EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Method_PrototypeSetterLocksTheLength_ThrowsTypeError(const MethodName: string);
begin
  const Script = Format(
    'var array = [];' +
    'var setterCalls = 0;' +
    'Object.defineProperty(Array.prototype, "0", { configurable: true, set: function (v) {' +
    '  Object.defineProperty(array, "length", { writable: false }); setterCalls++; } });' +
    'var outcome;' +
    'try { array.%s(1); outcome = "none"; } catch (e) { outcome = e.name; }' +
    'delete Array.prototype[0];' +
    '[outcome, array.hasOwnProperty(0), array.length, setterCalls].join()',
    [MethodName]);

  Assert.AreEqual('TypeError,false,0,1', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Push_PrototypeSetterFreezesTheArray_ThrowsTypeError;
begin
  const Script =
    'var array = [];' +
    'Object.defineProperty(Array.prototype, "0", { configurable: true, set: function (v) { Object.freeze(array); } });' +
    'var outcome;' +
    'try { array.push(1); outcome = "none"; } catch (e) { outcome = e.name; }' +
    'delete Array.prototype[0];' +
    '[outcome, array.length].join()';

  Assert.AreEqual('TypeError,0', EvaluateText(Script));
end;

procedure TArrayPrototypeSemanticsTests.Push_NoIndexedPrototypeProperty_AppendsDirectly;
begin
  Assert.AreEqual('3,a,c', EvaluateText('var a = ["a"]; a.push("b", "c"); [a.length, a[0], a[2]].join()'));
end;

end.
