unit JS4D.Tests.Constructors;

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
  TConstructorTests = class
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
    procedure Array_IsGlobalFunction;

    [Test]
    procedure Array_CalledWithoutArguments_ReturnsEmptyArray;

    [Test]
    procedure Array_CalledWithLength_ReturnsArrayOfThatLength;

    [Test]
    procedure Array_CalledWithSeveralArguments_ReturnsArrayOfElements;

    [Test]
    procedure Array_CalledWithSingleNonNumber_ReturnsArrayWithThatElement;

    [Test]
    procedure NewArray_CalledWithLength_ReturnsArrayOfThatLength;

    [Test]
    procedure NewArray_CalledWithSeveralArguments_ReturnsArrayOfElements;

    [Test]
    procedure NewArray_ResultIsArray;

    [Test]
    procedure NewArray_ResultIsInstanceOfArray;

    [Test]
    [TestCase('Negative', '-1')]
    [TestCase('Fractional', '1.5')]
    [TestCase('TooLarge', '4294967296')]
    procedure NewArray_InvalidLength_ThrowsRangeError(const RequestedLength: string);

    [Test]
    procedure Array_StaticMethods_StillAvailable;

    [Test]
    procedure Object_IsGlobalFunction;

    [Test]
    procedure Object_CalledWithoutArgument_ReturnsNewObject;

    [Test]
    procedure Object_CalledWithNull_ReturnsNewObject;

    [Test]
    procedure Object_CalledWithObject_ReturnsSameObject;

    [Test]
    procedure NewObject_ReturnsFreshObject;

    [Test]
    procedure NewObject_CalledWithObject_ReturnsSameObject;

    [Test]
    procedure NewObject_ResultInheritsFromObjectPrototype;

    [Test]
    procedure Object_StaticMethods_StillAvailable;
  end;

implementation

procedure TConstructorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TConstructorTests.TearDown;
begin
  FEngine.Free;
end;

function TConstructorTests.EvaluateBoolean(const Script: string): Boolean;
begin
  Result := FEngine.Evaluate(Script).AsBoolean;
end;

function TConstructorTests.EvaluateNumber(const Script: string): Double;
begin
  Result := FEngine.Evaluate(Script).AsNumber;
end;

procedure TConstructorTests.Array_IsGlobalFunction;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Array === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Array.prototype === "object"'));
end;

procedure TConstructorTests.Array_CalledWithoutArguments_ReturnsEmptyArray;
begin
  Assert.AreEqual(0.0, EvaluateNumber('Array().length'));
end;

procedure TConstructorTests.Array_CalledWithLength_ReturnsArrayOfThatLength;
begin
  Assert.AreEqual(3.0, EvaluateNumber('Array(3).length'));
end;

procedure TConstructorTests.Array_CalledWithSeveralArguments_ReturnsArrayOfElements;
begin
  Assert.AreEqual(3.0, EvaluateNumber('Array(1, 2, 3).length'));
  Assert.AreEqual(2.0, EvaluateNumber('Array(1, 2, 3)[1]'));
end;

procedure TConstructorTests.Array_CalledWithSingleNonNumber_ReturnsArrayWithThatElement;
begin
  Assert.AreEqual(1.0, EvaluateNumber('Array("a").length'));
  Assert.AreEqual('a', FEngine.Evaluate('Array("a")[0]').AsString);
end;

procedure TConstructorTests.NewArray_CalledWithLength_ReturnsArrayOfThatLength;
begin
  Assert.AreEqual(5.0, EvaluateNumber('new Array(5).length'));
end;

procedure TConstructorTests.NewArray_CalledWithSeveralArguments_ReturnsArrayOfElements;
begin
  Assert.AreEqual(3.0, EvaluateNumber('new Array(7, 8, 9).length'));
  Assert.AreEqual(9.0, EvaluateNumber('new Array(7, 8, 9)[2]'));
end;

procedure TConstructorTests.NewArray_ResultIsArray;
begin
  Assert.IsTrue(EvaluateBoolean('Array.isArray(new Array(2))'));
end;

procedure TConstructorTests.NewArray_ResultIsInstanceOfArray;
begin
  Assert.IsTrue(EvaluateBoolean('new Array(2) instanceof Array'));
end;

procedure TConstructorTests.NewArray_InvalidLength_ThrowsRangeError(const RequestedLength: string);
begin
  const Script = Format('new Array(%s)', [RequestedLength]);

  Assert.WillRaise(
    procedure
    begin
      FEngine.Evaluate(Script);
    end,
    EJSRangeError);
end;

procedure TConstructorTests.Array_StaticMethods_StillAvailable;
begin
  Assert.IsTrue(EvaluateBoolean('Array.isArray([])'));
  Assert.AreEqual(2.0, EvaluateNumber('Array.from([1, 2]).length'));
end;

procedure TConstructorTests.Object_IsGlobalFunction;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Object === "function"'));
  Assert.IsTrue(EvaluateBoolean('typeof Object.prototype === "object"'));
end;

procedure TConstructorTests.Object_CalledWithoutArgument_ReturnsNewObject;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Object() === "object"'));
end;

procedure TConstructorTests.Object_CalledWithNull_ReturnsNewObject;
begin
  Assert.IsTrue(EvaluateBoolean('typeof Object(null) === "object"'));
  Assert.IsTrue(EvaluateBoolean('typeof Object(undefined) === "object"'));
end;

procedure TConstructorTests.Object_CalledWithObject_ReturnsSameObject;
begin
  Assert.IsTrue(EvaluateBoolean('var source = { a: 1 }; Object(source) === source'));
end;

procedure TConstructorTests.NewObject_ReturnsFreshObject;
begin
  Assert.AreEqual(1.0, EvaluateNumber('var created = new Object(); created.x = 1; created.x'));
end;

procedure TConstructorTests.NewObject_CalledWithObject_ReturnsSameObject;
begin
  Assert.IsTrue(EvaluateBoolean('var source = { a: 1 }; new Object(source) === source'));
end;

procedure TConstructorTests.NewObject_ResultInheritsFromObjectPrototype;
begin
  Assert.IsTrue(EvaluateBoolean('Object.getPrototypeOf(new Object()) === Object.prototype'));
  Assert.IsTrue(EvaluateBoolean('new Object() instanceof Object'));
end;

procedure TConstructorTests.Object_StaticMethods_StillAvailable;
begin
  Assert.AreEqual(1.0, EvaluateNumber('Object.keys({ a: 1 }).length'));
  Assert.IsTrue(EvaluateBoolean('Object.prototype.hasOwnProperty.call({ a: 1 }, "a")'));
end;

end.
