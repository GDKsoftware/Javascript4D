unit JS4D.Tests.ObjectAccessors;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TObjectAccessorTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOfEval(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Getter_InObjectLiteral_ComputesValueOnRead;

    [Test]
    procedure Setter_InObjectLiteral_RunsOnAssignment;

    [Test]
    procedure GetterAndSetter_SameName_FormOneAccessorProperty;

    [Test]
    procedure Setter_ThenGetter_FormOneAccessorProperty;

    [Test]
    procedure Getter_ThisIsTheObject;

    [Test]
    procedure Accessor_KeyedByStringAndNumber_IsReadable;

    [Test]
    procedure Accessor_KeyedByReservedWord_IsReadable;

    [Test]
    procedure Accessor_Descriptor_IsEnumerableAndConfigurable;

    [Test]
    procedure PropertiesNamedGetAndSet_RemainOrdinaryProperties;

    [Test]
    procedure DataPropertyAfterAccessor_ReplacesAccessor;

    [Test]
    procedure AccessorAfterDataProperty_ReplacesDataProperty;

    [Test]
    [TestCase('GetterWithParameter', '({ get x(a) { return 1; } })')]
    [TestCase('SetterWithoutParameter', '({ set x() { } })')]
    [TestCase('SetterWithTwoParameters', '({ set x(a, b) { } })', ';')]
    [TestCase('GetterWithoutBody', '({ get x })')]
    [TestCase('EscapedGetKeyword', '({ \\u0067et x() { } })')]
    [TestCase('EscapedSetKeyword', '({ s\\u0065t x(v) { } })')]
    [TestCase('SetterParameterEvalInStrictCode', '''use strict''; ({ set x(eval) { } })')]
    [TestCase('SetterParameterArgumentsInStrictBody', '({ set x(arguments) { ''use strict''; } })')]
    procedure Eval_InvalidAccessor_IsSyntaxError(const Source: string);
  end;

implementation

const
  SyntaxErrorName = 'SyntaxError';

function TObjectAccessorTests.ErrorNameOfEval(const Source: string): string;
begin
  const Script = Format('var name = "none"; try { eval("%s"); } catch (e) { name = e.name; } name', [Source]);

  Result := FEngine.Evaluate(Script).AsString;
end;

procedure TObjectAccessorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TObjectAccessorTests.TearDown;
begin
  FEngine.Free;
end;

procedure TObjectAccessorTests.Getter_InObjectLiteral_ComputesValueOnRead;
begin
  const Script =
    'var calls = 0;' + sLineBreak +
    'var o = { get x() { calls++; return 41 + calls; } };' + sLineBreak +
    'o.x + o.x';

  Assert.AreEqual(85.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Setter_InObjectLiteral_RunsOnAssignment;
begin
  const Script =
    'var stored = 0;' + sLineBreak +
    'var o = { set x(v) { stored = v * 2; } };' + sLineBreak +
    'o.x = 21;' + sLineBreak +
    'stored';

  Assert.AreEqual(42.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.GetterAndSetter_SameName_FormOneAccessorProperty;
begin
  const Script =
    'var hidden = 1;' + sLineBreak +
    'var o = { get x() { return hidden; }, set x(v) { hidden = v + 1; } };' + sLineBreak +
    'o.x = 5;' + sLineBreak +
    'o.x';

  Assert.AreEqual(6.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Setter_ThenGetter_FormOneAccessorProperty;
begin
  const Script =
    'var hidden = 1;' + sLineBreak +
    'var o = { set x(v) { hidden = v + 1; }, get x() { return hidden; } };' + sLineBreak +
    'o.x = 5;' + sLineBreak +
    'o.x';

  Assert.AreEqual(6.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Getter_ThisIsTheObject;
begin
  const Script =
    'var o = { n: 7, get double() { return this.n * 2; } };' + sLineBreak +
    'o.double';

  Assert.AreEqual(14.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Accessor_KeyedByStringAndNumber_IsReadable;
begin
  const Script =
    'var o = { get "a b"() { return 1; }, get 7() { return 10; } };' + sLineBreak +
    'o["a b"] + o[7]';

  Assert.AreEqual(11.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Accessor_KeyedByReservedWord_IsReadable;
begin
  const Script =
    'var o = { get if() { return 3; }, set get(v) { } };' + sLineBreak +
    'o.if';

  Assert.AreEqual(3.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Accessor_Descriptor_IsEnumerableAndConfigurable;
begin
  const Script =
    'var o = { get x() { return 1; } };' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'typeof d.get === "function" && d.set === undefined && d.enumerable && d.configurable';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TObjectAccessorTests.PropertiesNamedGetAndSet_RemainOrdinaryProperties;
begin
  const Script =
    'var o = { get: 1, set: 2, get get() { return 3; } };' + sLineBreak +
    'var p = { get: 1, set: 2 };' + sLineBreak +
    'o.get * 100 + p.get * 10 + p.set';

  Assert.AreEqual(312.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.DataPropertyAfterAccessor_ReplacesAccessor;
begin
  const Script =
    'var o = { get x() { return 1; }, x: 2 };' + sLineBreak +
    'var d = Object.getOwnPropertyDescriptor(o, "x");' + sLineBreak +
    'd.value === 2 && d.writable';

  Assert.IsTrue(FEngine.Evaluate(Script).AsBoolean);
end;

procedure TObjectAccessorTests.AccessorAfterDataProperty_ReplacesDataProperty;
begin
  const Script =
    'var o = { x: 2, get x() { return 9; } };' + sLineBreak +
    'o.x';

  Assert.AreEqual(9.0, FEngine.Evaluate(Script).AsNumber);
end;

procedure TObjectAccessorTests.Eval_InvalidAccessor_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual(SyntaxErrorName, ErrorNameOfEval(Source));
end;

end.
