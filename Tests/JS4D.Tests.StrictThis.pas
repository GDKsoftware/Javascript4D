unit JS4D.Tests.StrictThis;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Engine;

const
  STRICT_BOOLEAN_TO_STRING = 'Boolean.prototype.toString = function () { "use strict"; return typeof this; }; ';
  SLOPPY_BOOLEAN_TO_STRING = 'Boolean.prototype.toString = function () { return typeof this; }; ';
  TRUE_TO_LOCALE_STRING_IS_BOOLEAN = 'true.toLocaleString() === "boolean"';

type
  [TestFixture]
  TStrictThisTests = class
  private
    const
      THROWS_TYPE_ERROR = 'try { %s; false; } catch (e) { e instanceof TypeError; }';
      OBJECT_TO_STRING_CALL = 'Object.prototype.toString.call(%s)';

    var
      FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Strict function called with a number', 'function f() { "use strict"; return typeof this; } f.call(1) === "number"', '#')]
    [TestCase('Strict function called with null', 'function f() { "use strict"; return this === null; } f.call(null)', '#')]
    [TestCase('Strict function called with undefined', 'function f() { "use strict"; return this === undefined; } f.call(undefined) && f()', '#')]
    [TestCase('Strict function applied with a string', 'function f() { "use strict"; return this; } f.apply("abc") === "abc"', '#')]
    [TestCase('Strict function bound to a boolean', 'function f() { "use strict"; return this; } f.bind(false)() === false', '#')]
    [TestCase('Strict function called as a method on a primitive', 'Number.prototype.me = function () { "use strict"; return this; }; (5).me() === 5', '#')]
    [TestCase('Strict function called with an object', 'var o = {}; function f() { "use strict"; return this; } f.call(o) === o', '#')]
    [TestCase('Strict arrow function inherits a primitive this', 'function f() { "use strict"; return (() => this)(); } f.call(7) === 7', '#')]
    [TestCase('Strict callback with a primitive this argument', 'var seen; [1].forEach(function () { "use strict"; seen = this; }, 3); seen === 3', '#')]
    [TestCase('Strict callback with a null this argument', 'var seen = 1; [1].every(function () { "use strict"; seen = this; return true; }, null); seen === null', '#')]
    [TestCase('Sloppy function called with a number', 'function f() { return typeof this; } f.call(1) === "object"', '#')]
    [TestCase('Sloppy function called with null', 'var g = this; function f() { return this === g; } f.call(null)', '#')]
    [TestCase('Strict getter read on a primitive', 'Object.defineProperty(Object.prototype, "me", { get: function () { "use strict"; return this; }, configurable: true }); (5).me === 5', '#')]
    [TestCase('Sloppy getter read on a primitive', 'Object.defineProperty(Object.prototype, "me", { get: function () { return this; }, configurable: true }); typeof (5).me === "object"', '#')]
    [TestCase('Object toLocaleString with a strict toString', STRICT_BOOLEAN_TO_STRING + TRUE_TO_LOCALE_STRING_IS_BOOLEAN, '#')]
    [TestCase('Object toLocaleString with a sloppy toString', SLOPPY_BOOLEAN_TO_STRING + 'true.toLocaleString() === "object"', '#')]
    [TestCase('Object toLocaleString with a strict toString getter', 'Object.defineProperty(Boolean.prototype, "toString", { get: function () { "use strict"; const seen = typeof this; return function () { return seen; }; } }); ' + TRUE_TO_LOCALE_STRING_IS_BOOLEAN, '#')]
    [TestCase('Array toLocaleString with a strict element toString', STRICT_BOOLEAN_TO_STRING + '[true, false].toLocaleString() === "boolean,boolean"', '#')]
    procedure Script_EvaluatesToTrue(const Script: string);

    [Test]
    [TestCase('Error toString on a number', 'Error.prototype.toString.call(1)', '#')]
    [TestCase('Error toString on a string', 'Error.prototype.toString.call("text")', '#')]
    [TestCase('Error toString on a boolean', 'Error.prototype.toString.call(true)', '#')]
    [TestCase('Error toString on null', 'Error.prototype.toString.call(null)', '#')]
    [TestCase('Error toString on undefined', 'Error.prototype.toString.call(undefined)', '#')]
    [TestCase('Date toPrimitive on a number', 'Date.prototype[Symbol.toPrimitive].call(86, "string")', '#')]
    [TestCase('Date toPrimitive on a string', 'Date.prototype[Symbol.toPrimitive].call("", "string")', '#')]
    [TestCase('Date toPrimitive on a boolean', 'Date.prototype[Symbol.toPrimitive].call(true, "string")', '#')]
    [TestCase('Object toLocaleString on null', 'Object.prototype.toLocaleString.call(null)', '#')]
    procedure Call_OnPrimitiveReceiver_ThrowsTypeError(const Call: string);

    [Test]
    [TestCase('Null', 'null#[object Null]', '#')]
    [TestCase('Undefined', 'undefined#[object Undefined]', '#')]
    [TestCase('Number', '1#[object Number]', '#')]
    [TestCase('String', '"x"#[object String]', '#')]
    [TestCase('Boolean', 'false#[object Boolean]', '#')]
    procedure ObjectToString_PrimitiveReceiver_ReturnsClassTag(const Receiver: string; const Expected: string);
  end;

implementation

uses
  System.SysUtils;

{ TStrictThisTests }

procedure TStrictThisTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TStrictThisTests.TearDown;
begin
  FEngine.Free;
end;

procedure TStrictThisTests.Script_EvaluatesToTrue(const Script: string);
begin
  const Actual = FEngine.Evaluate(Script);

  Assert.IsTrue(Actual.AsBoolean);
end;

procedure TStrictThisTests.Call_OnPrimitiveReceiver_ThrowsTypeError(const Call: string);
begin
  const Script = Format(THROWS_TYPE_ERROR, [Call]);

  const Actual = FEngine.Evaluate(Script);

  Assert.IsTrue(Actual.AsBoolean);
end;

procedure TStrictThisTests.ObjectToString_PrimitiveReceiver_ReturnsClassTag(const Receiver: string;
                                                                            const Expected: string);
begin
  const Script = Format(OBJECT_TO_STRING_CALL, [Receiver]);

  const Actual = FEngine.Evaluate(Script);

  Assert.AreEqual(Expected, Actual.AsString);
end;

end.
