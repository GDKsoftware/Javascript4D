unit JS4D.Tests.Prototypes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Tests.Support;

type
  [TestFixture]
  TPrototypeTests = class(TJSEngineTestCase)
  public
    [Test]
    procedure Function_Declaration_HasPrototypeObject;

    [Test]
    procedure Function_Expression_HasPrototypeObject;

    [Test]
    procedure Prototype_Constructor_RefersBackToFunction;

    [Test]
    procedure New_PropertyOnPrototype_IsReadFromInstance;

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

const
  POINT_CONSTRUCTOR = 'function Point() {}';
  POINT_PROTOTYPE_IS_OBJECT = 'typeof Point.prototype === "object"';

procedure TPrototypeTests.Function_Declaration_HasPrototypeObject;
begin
  FEngine.Execute(POINT_CONSTRUCTOR);

  const Actual = EvaluateBoolean(POINT_PROTOTYPE_IS_OBJECT);

  Assert.IsTrue(Actual);
end;

procedure TPrototypeTests.Function_Expression_HasPrototypeObject;
begin
  FEngine.Execute('var Point = function () {};');

  const Actual = EvaluateBoolean(POINT_PROTOTYPE_IS_OBJECT);

  Assert.IsTrue(Actual);
end;

procedure TPrototypeTests.Prototype_Constructor_RefersBackToFunction;
begin
  FEngine.Execute(POINT_CONSTRUCTOR);

  const Actual = EvaluateBoolean('Point.prototype.constructor === Point');

  Assert.IsTrue(Actual);
end;

procedure TPrototypeTests.New_PropertyOnPrototype_IsReadFromInstance;
begin
  FEngine.Execute('function Point() {} Point.prototype.size = 5; var p = new Point();');

  const Actual = EvaluateNumber('p.size');

  Assert.AreEqual(5.0, Actual);
end;

procedure TPrototypeTests.New_ReplacedPrototype_IsUsedByNewObjects;
begin
  FEngine.Execute('function Point() {} Point.prototype = { size: 7 }; var p = new Point();');

  const Actual = EvaluateNumber('p.size');

  Assert.AreEqual(7.0, Actual);
end;

procedure TPrototypeTests.New_ConstructorReturningObject_ReplacesInstance;
begin
  FEngine.Execute('function Point() { return { size: 3 }; } var p = new Point();');

  const Size = EvaluateNumber('p.size');
  const IsInstance = EvaluateBoolean('p instanceof Point');

  Assert.AreEqual(3.0, Size);
  Assert.IsFalse(IsInstance);
end;

procedure TPrototypeTests.InstanceOf_ObjectCreatedWithNew_IsTrue;
begin
  FEngine.Execute('function Point() {} var p = new Point();');

  const Actual = EvaluateBoolean('p instanceof Point');

  Assert.IsTrue(Actual);
end;

procedure TPrototypeTests.InstanceOf_OtherConstructor_IsFalse;
begin
  FEngine.Execute('function Point() {} function Circle() {} var p = new Point();');

  const Actual = EvaluateBoolean('p instanceof Circle');

  Assert.IsFalse(Actual);
end;

procedure TPrototypeTests.InstanceOf_PrototypeChain_IsTrue;
begin
  FEngine.Execute(
    'function Shape() {} function Circle() {} ' +
    'Circle.prototype = Object.create(Shape.prototype); var c = new Circle();');

  const IsShape = EvaluateBoolean('c instanceof Shape');
  const IsCircle = EvaluateBoolean('c instanceof Circle');

  Assert.IsTrue(IsShape);
  Assert.IsTrue(IsCircle);
end;

procedure TPrototypeTests.InstanceOf_PlainObject_IsFalse;
begin
  FEngine.Execute(POINT_CONSTRUCTOR);

  const Actual = EvaluateBoolean('({}) instanceof Point');

  Assert.IsFalse(Actual);
end;

procedure TPrototypeTests.InstanceOf_GuardPattern_ConstructsWhenCalledAsFunction;
begin
  FEngine.Execute(
    'function Failure(message) {' +
    '  if (!(this instanceof Failure)) return new Failure(message);' +
    '  this.message = message;' +
    '}');

  const FromCall = EvaluateText('Failure("boom").message');
  const FromNew = EvaluateText('new Failure("boom").message');

  Assert.AreEqual('boom', FromCall);
  Assert.AreEqual('boom', FromNew);
end;

procedure TPrototypeTests.ForIn_InstanceOfConstructor_DoesNotListConstructorProperty;
begin
  FEngine.Execute(
    'function Point() { this.x = 1; } var names = ""; ' +
    'for (var name in new Point()) { names += name; }');

  const Names = EvaluateText('names');

  Assert.AreEqual('x', Names);
end;

end.
