unit JS4D.Tests.ErrorObjects;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TErrorObjectTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Instance_WithMessage_HasOwnNonEnumerableWritableConfigurableMessage;

    [Test]
    procedure Instance_WithoutMessage_InheritsEmptyMessage;

    [Test]
    procedure Instance_WithUndefinedMessage_HasNoOwnMessage;

    [Test]
    procedure Instance_HasNoOwnNameOrToString;

    [Test]
    procedure Instance_ForIn_VisitsNothing;

    [Test]
    procedure Prototype_HasOwnNonEnumerableNameAndEmptyMessage;

    [Test]
    [TestCase('EvalError', 'EvalError')]
    [TestCase('RangeError', 'RangeError')]
    [TestCase('ReferenceError', 'ReferenceError')]
    [TestCase('SyntaxError', 'SyntaxError')]
    [TestCase('TypeError', 'TypeError')]
    [TestCase('URIError', 'URIError')]
    procedure NativeErrorPrototype_HasOwnNameAndEmptyMessage(const ConstructorName: string);

    [Test]
    [TestCase('EvalError', 'EvalError')]
    [TestCase('RangeError', 'RangeError')]
    [TestCase('ReferenceError', 'ReferenceError')]
    [TestCase('SyntaxError', 'SyntaxError')]
    [TestCase('TypeError', 'TypeError')]
    [TestCase('URIError', 'URIError')]
    procedure NativeError_InheritsFromErrorConstructor(const ConstructorName: string);

    [Test]
    [TestCase('EvalError', 'EvalError')]
    [TestCase('TypeError', 'TypeError')]
    procedure NativeErrorInstance_NameComesFromPrototype(const ConstructorName: string);

    [Test]
    procedure ToString_EmptyName_ReturnsMessage;

    [Test]
    procedure ToString_NameOnly_ReturnsName;

    [Test]
    procedure ToString_NameAndMessage_JoinsWithColon;

    [Test]
    procedure ToString_ReplacedOnPrototype_AppliesToInstances;

    [Test]
    procedure InternalError_Caught_HasNameFromPrototype;

    [Test]
    [TestCase('E', 'E')]
    [TestCase('LN10', 'LN10')]
    [TestCase('LN2', 'LN2')]
    [TestCase('LOG10E', 'LOG10E')]
    [TestCase('LOG2E', 'LOG2E')]
    [TestCase('PI', 'PI')]
    [TestCase('SQRT1_2', 'SQRT1_2')]
    [TestCase('SQRT2', 'SQRT2')]
    procedure MathConstant_IsReadOnlyHiddenAndPermanent(const ConstantName: string);

    [Test]
    [TestCase('MAX_VALUE', 'MAX_VALUE')]
    [TestCase('MIN_VALUE', 'MIN_VALUE')]
    [TestCase('NaN', 'NaN')]
    [TestCase('POSITIVE_INFINITY', 'POSITIVE_INFINITY')]
    [TestCase('NEGATIVE_INFINITY', 'NEGATIVE_INFINITY')]
    procedure NumberConstant_IsReadOnlyHiddenAndPermanent(const ConstantName: string);

    [Test]
    procedure NumberConstant_AssignmentKeepsValue;

    [Test]
    procedure NumberConstant_DeleteReturnsFalse;
  end;

implementation

procedure TErrorObjectTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TErrorObjectTests.TearDown;
begin
  FEngine.Free;
end;

function TErrorObjectTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

procedure TErrorObjectTests.Instance_WithMessage_HasOwnNonEnumerableWritableConfigurableMessage;
begin
  const Script =
    'var e = new Error("boom");' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(e, "message");' + sLineBreak +
    'e.hasOwnProperty("message") && d.value === "boom" && d.writable && !d.enumerable && d.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.Instance_WithoutMessage_InheritsEmptyMessage;
begin
  const Script = 'var e = new Error(); !e.hasOwnProperty("message") && e.message === ""';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.Instance_WithUndefinedMessage_HasNoOwnMessage;
begin
  const Script = '!new TypeError(undefined).hasOwnProperty("message")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.Instance_HasNoOwnNameOrToString;
begin
  const Script =
    'var e = new RangeError("x");' + sLineBreak +
    '!e.hasOwnProperty("name") && !e.hasOwnProperty("toString") && e.name === "RangeError"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.Instance_ForIn_VisitsNothing;
begin
  const Script =
    'var count = 0; for (var key in new Error("x")) { count++; } count === 0';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.Prototype_HasOwnNonEnumerableNameAndEmptyMessage;
begin
  const Script =
    'var n = Object.getOwnPropertyDescriptor(Error.prototype, "name");' + sLineBreak +
    'var m = Object.getOwnPropertyDescriptor(Error.prototype, "message");' + sLineBreak +
    'n.value === "Error" && n.writable && !n.enumerable && n.configurable &&' + sLineBreak +
    'm.value === "" && m.writable && !m.enumerable && m.configurable';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NativeErrorPrototype_HasOwnNameAndEmptyMessage(const ConstructorName: string);
begin
  const Script = Format(
    'var proto = %0:s.prototype;' + sLineBreak +
    'var n = Object.getOwnPropertyDescriptor(proto, "name");' + sLineBreak +
    'n.value === "%0:s" && n.writable && !n.enumerable && n.configurable &&' + sLineBreak +
    'proto.hasOwnProperty("message") && proto.message === ""',
    [ConstructorName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NativeError_InheritsFromErrorConstructor(const ConstructorName: string);
begin
  const Script = Format('Object.getPrototypeOf(%s) === Error', [ConstructorName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NativeErrorInstance_NameComesFromPrototype(const ConstructorName: string);
begin
  const Script = Format('var e = new %0:s("m"); e.name === "%0:s" && !e.hasOwnProperty("name")', [ConstructorName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.ToString_EmptyName_ReturnsMessage;
begin
  const Script = 'var e = new Error("ErrorMessage"); e.name = ""; e.toString() === "ErrorMessage"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.ToString_NameOnly_ReturnsName;
begin
  const Script = 'var e = new Error(); e.name = "ErrorName"; e.toString() === "ErrorName"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.ToString_NameAndMessage_JoinsWithColon;
begin
  const Script = 'var e = new Error("ErrorMessage"); e.name = "ErrorName"; e.toString() === "ErrorName: ErrorMessage"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.ToString_ReplacedOnPrototype_AppliesToInstances;
begin
  const Script =
    'var original = Error.prototype.toString;' + sLineBreak +
    'Error.prototype.toString = Object.prototype.toString;' + sLineBreak +
    'var replaced = new Error().toString();' + sLineBreak +
    'Error.prototype.toString = original;' + sLineBreak +
    'replaced === "[object Error]"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.InternalError_Caught_HasNameFromPrototype;
begin
  const Script =
    'var caught;' + sLineBreak +
    'try { null.property; } catch (e) { caught = e; }' + sLineBreak +
    'caught.name === "TypeError" && !caught.hasOwnProperty("name") && caught.hasOwnProperty("message")';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.MathConstant_IsReadOnlyHiddenAndPermanent(const ConstantName: string);
begin
  const Script = Format(
    'var d = Object.getOwnPropertyDescriptor(Math, "%0:s");' + sLineBreak +
    'var before = Math.%0:s; Math.%0:s = 1;' + sLineBreak +
    '!d.writable && !d.enumerable && !d.configurable && Math.%0:s === before',
    [ConstantName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NumberConstant_IsReadOnlyHiddenAndPermanent(const ConstantName: string);
begin
  const Script = Format(
    'var d = Object.getOwnPropertyDescriptor(Number, "%s");' + sLineBreak +
    '!d.writable && !d.enumerable && !d.configurable',
    [ConstantName]);

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NumberConstant_AssignmentKeepsValue;
begin
  const Script = 'Number.NaN = 1; Number.MAX_VALUE = 1; Number.NaN !== 1 && Number.MAX_VALUE > 1';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

procedure TErrorObjectTests.NumberConstant_DeleteReturnsFalse;
begin
  const Script = '(delete Number.NaN) === false && typeof Number.NaN !== "undefined"';

  Assert.IsTrue(EvaluateBoolean(Script));
end;

end.
