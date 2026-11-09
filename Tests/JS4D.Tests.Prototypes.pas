unit JS4D.Tests.Prototypes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TPrototypeTests = class
  private
    FEngine: TJSEngine;

    function EvaluateBoolean(const Script: string): Boolean;
    function EvaluateNumber(const Script: string): Double;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Function_Declaration_HasPrototypeObject;

    [Test]
    procedure Function_Expression_HasPrototypeObject;

    [Test]
    procedure Prototype_Constructor_RefersBackToFunction;

    [Test]
    procedure New_ReadsPropertyFromConstructorPrototype;

    [Test]
    procedure New_ReplacedPrototype_IsUsedByNewObjects;

    [Test]
    procedure New_ConstructorReturningObject_ReplacesInstance;

    [Test]
    procedure InstanceOf_ObjectCreatedWithNew_IsTrue;

    [Test]
    procedure InstanceOf_OtherConstructor_IsFalse;

    [Test]
    procedure InstanceOf_PrototypeChain_IsTrue;

    [Test]
    procedure InstanceOf_PlainObject_IsFalse;

    [Test]
    procedure InstanceOf_GuardPattern_ConstructsWhenCalledAsFunction;

    [Test]
    procedure ForIn_InstanceOfConstructor_DoesNotListConstructorProperty;
  end;

implementation

procedure TPrototypeTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TPrototypeTests.TearDown;
begin
  FEngine.Free;
end;

function TPrototypeTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

function TPrototypeTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).AsNumber;
end;

procedure TPrototypeTests.Function_Declaration_HasPrototypeObject;
begin
  FEngine.Execute('function Point() {}');

  Assert.IsTrue(EvaluateBoolean('typeof Point.prototype === "object"'));
end;

procedure TPrototypeTests.Function_Expression_HasPrototypeObject;
begin
  FEngine.Execute('var Point = function () {};');

  Assert.IsTrue(EvaluateBoolean('typeof Point.prototype === "object"'));
end;

procedure TPrototypeTests.Prototype_Constructor_RefersBackToFunction;
begin
  FEngine.Execute('function Point() {}');

  Assert.IsTrue(EvaluateBoolean('Point.prototype.constructor === Point'));
end;

procedure TPrototypeTests.New_ReadsPropertyFromConstructorPrototype;
begin
  FEngine.Execute('function Point() {} Point.prototype.size = 5; var p = new Point();');

  Assert.AreEqual(5.0, EvaluateNumber('p.size'));
end;

procedure TPrototypeTests.New_ReplacedPrototype_IsUsedByNewObjects;
begin
  FEngine.Execute('function Point() {} Point.prototype = { size: 7 }; var p = new Point();');

  Assert.AreEqual(7.0, EvaluateNumber('p.size'));
end;

procedure TPrototypeTests.New_ConstructorReturningObject_ReplacesInstance;
begin
  FEngine.Execute('function Point() { return { size: 3 }; } var p = new Point();');

  Assert.AreEqual(3.0, EvaluateNumber('p.size'));
  Assert.IsFalse(EvaluateBoolean('p instanceof Point'));
end;

procedure TPrototypeTests.InstanceOf_ObjectCreatedWithNew_IsTrue;
begin
  FEngine.Execute('function Point() {} var p = new Point();');

  Assert.IsTrue(EvaluateBoolean('p instanceof Point'));
end;

procedure TPrototypeTests.InstanceOf_OtherConstructor_IsFalse;
begin
  FEngine.Execute('function Point() {} function Circle() {} var p = new Point();');

  Assert.IsFalse(EvaluateBoolean('p instanceof Circle'));
end;

procedure TPrototypeTests.InstanceOf_PrototypeChain_IsTrue;
begin
  FEngine.Execute(
    'function Shape() {} function Circle() {} ' +
    'Circle.prototype = Object.create(Shape.prototype); var c = new Circle();');

  Assert.IsTrue(EvaluateBoolean('c instanceof Shape'));
  Assert.IsTrue(EvaluateBoolean('c instanceof Circle'));
end;

procedure TPrototypeTests.InstanceOf_PlainObject_IsFalse;
begin
  FEngine.Execute('function Point() {}');

  Assert.IsFalse(EvaluateBoolean('({}) instanceof Point'));
end;

procedure TPrototypeTests.InstanceOf_GuardPattern_ConstructsWhenCalledAsFunction;
begin
  FEngine.Execute(
    'function Failure(message) {' +
    '  if (!(this instanceof Failure)) return new Failure(message);' +
    '  this.message = message;' +
    '}');

  Assert.AreEqual('boom', FEngine.Evaluate('Failure("boom").message').AsString);
  Assert.AreEqual('boom', FEngine.Evaluate('new Failure("boom").message').AsString);
end;

procedure TPrototypeTests.ForIn_InstanceOfConstructor_DoesNotListConstructorProperty;
begin
  FEngine.Execute(
    'function Point() { this.x = 1; } var names = ""; ' +
    'for (var name in new Point()) { names += name; }');

  Assert.AreEqual('x', FEngine.Evaluate('names').AsString);
end;

end.
