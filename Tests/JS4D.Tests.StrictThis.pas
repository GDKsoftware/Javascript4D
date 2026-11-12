unit JS4D.Tests.StrictThis;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TStrictThisTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StrictFunction_CalledWithNumber_SeesNumber;

    [Test]
    procedure StrictFunction_CalledWithNull_SeesNull;

    [Test]
    procedure StrictFunction_CalledWithUndefined_SeesUndefined;

    [Test]
    procedure StrictFunction_AppliedWithString_SeesString;

    [Test]
    procedure StrictFunction_BoundToBoolean_SeesBoolean;

    [Test]
    procedure StrictFunction_CalledAsMethodOnPrimitive_SeesPrimitive;

    [Test]
    procedure StrictFunction_CalledWithObject_SeesSameObject;

    [Test]
    procedure StrictArrowFunction_InheritsPrimitiveThis;

    [Test]
    procedure StrictCallback_ThisArgPrimitive_SeesPrimitive;

    [Test]
    procedure StrictCallback_ThisArgNull_SeesNull;

    [Test]
    procedure SloppyFunction_CalledWithNumber_SeesNumberObject;

    [Test]
    procedure SloppyFunction_CalledWithNull_SeesGlobalObject;

    [Test]
    procedure StrictGetter_ReadOnPrimitive_SeesPrimitive;

    [Test]
    procedure SloppyGetter_ReadOnPrimitive_SeesWrapper;

    [Test]
    [TestCase('Number', '1')]
    [TestCase('String', '"text"')]
    [TestCase('Boolean', 'true')]
    [TestCase('Null', 'null')]
    [TestCase('Undefined', 'undefined')]
    procedure ErrorToString_PrimitiveReceiver_ThrowsTypeError(const Receiver: string);

    [Test]
    [TestCase('Number', '86')]
    [TestCase('String', '""')]
    [TestCase('Boolean', 'true')]
    procedure DateToPrimitive_PrimitiveReceiver_ThrowsTypeError(const Receiver: string);

    [Test]
    [TestCase('Null', 'null#[object Null]', '#')]
    [TestCase('Undefined', 'undefined#[object Undefined]', '#')]
    [TestCase('Number', '1#[object Number]', '#')]
    [TestCase('String', '"x"#[object String]', '#')]
    [TestCase('Boolean', 'false#[object Boolean]', '#')]
    procedure ObjectToString_PrimitiveReceiver_ReturnsClassTag(const Receiver: string; const Expected: string);

    [Test]
    procedure ObjectToLocaleString_StrictToString_SeesPrimitive;

    [Test]
    procedure ObjectToLocaleString_SloppyToString_SeesWrapper;

    [Test]
    procedure ObjectToLocaleString_StrictToStringGetter_SeesPrimitive;

    [Test]
    procedure ArrayToLocaleString_StrictElementToString_SeesPrimitive;

    [Test]
    procedure ObjectToLocaleString_NullReceiver_ThrowsTypeError;
  end;

implementation

{ TStrictThisTests }

procedure TStrictThisTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TStrictThisTests.TearDown;
begin
  FEngine.Free;
end;

function TStrictThisTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TStrictThisTests.StrictFunction_CalledWithNumber_SeesNumber;
begin
  const Script = 'function f() { "use strict"; return typeof this; } f.call(1) === "number"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_CalledWithNull_SeesNull;
begin
  const Script = 'function f() { "use strict"; return this === null; } f.call(null)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_CalledWithUndefined_SeesUndefined;
begin
  const Script = 'function f() { "use strict"; return this === undefined; } f.call(undefined) && f()';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_AppliedWithString_SeesString;
begin
  const Script = 'function f() { "use strict"; return this; } f.apply("abc") === "abc"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_BoundToBoolean_SeesBoolean;
begin
  const Script = 'function f() { "use strict"; return this; } f.bind(false)() === false';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_CalledAsMethodOnPrimitive_SeesPrimitive;
begin
  const Script = 'Number.prototype.me = function () { "use strict"; return this; }; (5).me() === 5';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictFunction_CalledWithObject_SeesSameObject;
begin
  const Script = 'var o = {}; function f() { "use strict"; return this; } f.call(o) === o';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictArrowFunction_InheritsPrimitiveThis;
begin
  const Script = 'function f() { "use strict"; return (() => this)(); } f.call(7) === 7';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictCallback_ThisArgPrimitive_SeesPrimitive;
begin
  const Script = 'var seen; [1].forEach(function () { "use strict"; seen = this; }, 3); seen === 3';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictCallback_ThisArgNull_SeesNull;
begin
  const Script = 'var seen = 1; [1].every(function () { "use strict"; seen = this; return true; }, null); seen === null';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.SloppyFunction_CalledWithNumber_SeesNumberObject;
begin
  const Script = 'function f() { return typeof this; } f.call(1) === "object"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.SloppyFunction_CalledWithNull_SeesGlobalObject;
begin
  const Script = 'var g = this; function f() { return this === g; } f.call(null)';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.StrictGetter_ReadOnPrimitive_SeesPrimitive;
begin
  const Script = 'Object.defineProperty(Object.prototype, "me", ' +
                 '{ get: function () { "use strict"; return this; }, configurable: true }); (5).me === 5';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.SloppyGetter_ReadOnPrimitive_SeesWrapper;
begin
  const Script = 'Object.defineProperty(Object.prototype, "me", ' +
                 '{ get: function () { return this; }, configurable: true }); typeof (5).me === "object"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ErrorToString_PrimitiveReceiver_ThrowsTypeError(const Receiver: string);
begin
  const Script = 'try { Error.prototype.toString.call(' + Receiver + '); false; } catch (e) { e instanceof TypeError; }';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.DateToPrimitive_PrimitiveReceiver_ThrowsTypeError(const Receiver: string);
begin
  const Script = 'try { Date.prototype[Symbol.toPrimitive].call(' + Receiver + ', "string"); false; } ' +
                 'catch (e) { e instanceof TypeError; }';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ObjectToString_PrimitiveReceiver_ReturnsClassTag(const Receiver: string;
                                                                            const Expected: string);
begin
  const Script = 'Object.prototype.toString.call(' + Receiver + ')';

  const Actual = FEngine.Evaluate(Script).AsString;

  Assert.AreEqual(Expected, Actual);
end;

procedure TStrictThisTests.ObjectToLocaleString_StrictToString_SeesPrimitive;
begin
  const Script = 'Boolean.prototype.toString = function () { "use strict"; return typeof this; }; ' +
                 'true.toLocaleString() === "boolean"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ObjectToLocaleString_SloppyToString_SeesWrapper;
begin
  const Script = 'Boolean.prototype.toString = function () { return typeof this; }; ' +
                 'true.toLocaleString() === "object"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ObjectToLocaleString_StrictToStringGetter_SeesPrimitive;
begin
  const Script = 'Object.defineProperty(Boolean.prototype, "toString", { get: function () { "use strict"; ' +
                 'const seen = typeof this; return function () { return seen; }; } }); ' +
                 'true.toLocaleString() === "boolean"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ArrayToLocaleString_StrictElementToString_SeesPrimitive;
begin
  const Script = 'Boolean.prototype.toString = function () { "use strict"; return typeof this; }; ' +
                 '[true, false].toLocaleString() === "boolean,boolean"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TStrictThisTests.ObjectToLocaleString_NullReceiver_ThrowsTypeError;
begin
  const Script = 'try { Object.prototype.toLocaleString.call(null); false; } catch (e) { e instanceof TypeError; }';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
