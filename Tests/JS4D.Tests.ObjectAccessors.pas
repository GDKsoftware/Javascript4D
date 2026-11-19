unit JS4D.Tests.ObjectAccessors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TObjectAccessorTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Getter_InObjectLiteral_ComputesValueOnRead;

    [Test]
    procedure Setter_InObjectLiteral_RunsOnAssignment;

    [Test]
    procedure GetterAndSetter_SameName_FormOneAccessorProperty;

    [Test]
    procedure Setter_ThenGetter_FormOneAccessorProperty;

    [Test]
    procedure Getter_ReadThroughObject_ReceivesObjectAsThis;

    [Test]
    procedure Accessor_KeyedByStringAndNumber_IsReadable;

    [Test]
    procedure Accessor_KeyedByReservedWord_IsReadable;

    [Test]
    procedure Accessor_Descriptor_IsEnumerableAndConfigurable;

    [Test]
    procedure ObjectLiteral_PropertiesNamedGetAndSet_RemainOrdinary;

    [Test]
    procedure ObjectLiteral_DataPropertyAfterAccessor_ReplacesAccessor;

    [Test]
    procedure ObjectLiteral_AccessorAfterDataProperty_ReplacesDataProperty;

    [Test]
    [TestCase('GetterWithParameter', '({ get x(a) { return 1; } })')]
    [TestCase('SetterWithoutParameter', '({ set x() { } })')]
    [TestCase('SetterWithTwoParameters', '({ set x(a, b) { } })', ';')]
    [TestCase('GetterWithoutBody', '({ get x })')]
    [TestCase('EscapedGetKeyword', '({ \u0067et x() { } })')]
    [TestCase('EscapedSetKeyword', '({ s\u0065t x(v) { } })')]
    [TestCase('SetterParameterEvalInStrictCode', '''use strict''; ({ set x(eval) { } })')]
    [TestCase('SetterParameterArgumentsInStrictBody', '({ set x(arguments) { ''use strict''; } })')]
    procedure Eval_InvalidAccessor_IsSyntaxError(const Source: string);
  end;

implementation

uses
  JS4D.Tests.ErrorNames;

procedure TObjectAccessorTests.Getter_InObjectLiteral_ComputesValueOnRead;
begin
  const Script =
    'var calls = 0;' + sLineBreak +
    'var o = { get x() { calls++; return 41 + calls; } };' + sLineBreak +
    'o.x + o.x';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(85.0, Actual);
end;

procedure TObjectAccessorTests.Setter_InObjectLiteral_RunsOnAssignment;
begin
  const Script =
    'var stored = 0;' + sLineBreak +
    'var o = { set x(v) { stored = v * 2; } };' + sLineBreak +
    'o.x = 21;' + sLineBreak +
    'stored';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(42.0, Actual);
end;

procedure TObjectAccessorTests.GetterAndSetter_SameName_FormOneAccessorProperty;
begin
  const Script =
    'var hidden = 1;' + sLineBreak +
    'var o = { get x() { return hidden; }, set x(v) { hidden = v + 1; } };' + sLineBreak +
    'o.x = 5;' + sLineBreak +
    'o.x';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(6.0, Actual);
end;

procedure TObjectAccessorTests.Setter_ThenGetter_FormOneAccessorProperty;
begin
  const Script =
    'var hidden = 1;' + sLineBreak +
    'var o = { set x(v) { hidden = v + 1; }, get x() { return hidden; } };' + sLineBreak +
    'o.x = 5;' + sLineBreak +
    'o.x';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(6.0, Actual);
end;

procedure TObjectAccessorTests.Getter_ReadThroughObject_ReceivesObjectAsThis;
begin
  const Script =
    'var o = { n: 7, get double() { return this.n * 2; } };' + sLineBreak +
    'o.double';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(14.0, Actual);
end;

procedure TObjectAccessorTests.Accessor_KeyedByStringAndNumber_IsReadable;
begin
  const Script =
    'var o = { get "a b"() { return 1; }, get 7() { return 10; } };' + sLineBreak +
    'o["a b"] + o[7]';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(11.0, Actual);
end;

procedure TObjectAccessorTests.Accessor_KeyedByReservedWord_IsReadable;
begin
  const Script =
    'var o = { get if() { return 3; }, set get(v) { } };' + sLineBreak +
    'o.if';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(3.0, Actual);
end;

procedure TObjectAccessorTests.Accessor_Descriptor_IsEnumerableAndConfigurable;
begin
  const Script =
    'var o = { get x() { return 1; } };' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'typeof d.get === "function" && d.set === undefined && d.enumerable && d.configurable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TObjectAccessorTests.ObjectLiteral_PropertiesNamedGetAndSet_RemainOrdinary;
begin
  const Script =
    'var o = { get: 1, set: 2, get get() { return 3; } };' + sLineBreak +
    'var p = { get: 1, set: 2 };' + sLineBreak +
    'o.get * 100 + p.get * 10 + p.set';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(312.0, Actual);
end;

procedure TObjectAccessorTests.ObjectLiteral_DataPropertyAfterAccessor_ReplacesAccessor;
begin
  const Script =
    'var o = { get x() { return 1; }, x: 2 };' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.value === 2 && d.writable';

  const Actual = EvaluateBoolean(Script);

  Assert.IsTrue(Actual);
end;

procedure TObjectAccessorTests.ObjectLiteral_AccessorAfterDataProperty_ReplacesDataProperty;
begin
  const Script =
    'var o = { x: 2, get x() { return 9; } };' + sLineBreak +
    'o.x';

  const Actual = EvaluateNumber(Script);

  Assert.AreEqual(9.0, Actual);
end;

procedure TObjectAccessorTests.Eval_InvalidAccessor_IsSyntaxError(const Source: string);
begin
  const Actual = ErrorNameOf(Source);

  Assert.AreEqual(SYNTAX_ERROR_NAME, Actual);
end;

end.
