unit JS4D.Tests.LargeStackCall;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  JS4D.Errors,
  JS4D.LargeStackCall,
  JS4D.StackGuard;

type
  [TestFixture]
  TLargeStackCallTests = class
  private
    const
      WORK_RESULT = 42;
      MIN_LARGE_STACK_BYTES = 32 * 1024 * 1024;
      FAILURE_MESSAGE = 'work failed';

  public
    [Test]
    procedure Run_WithWork_ReturnsTheWorkResult;

    [Test]
    procedure Run_WithWork_GivesTheWorkALargeStack;

    [Test]
    procedure Run_WhenTheWorkRaises_RaisesTheErrorInTheCaller;
  end;

implementation

procedure TLargeStackCallTests.Run_WithWork_ReturnsTheWorkResult;
begin
  const Actual = TJSLargeStackCall.Run(
    function: Integer
    begin
      Result := WORK_RESULT;
    end);

  Assert.AreEqual(WORK_RESULT, Actual);
end;

procedure TLargeStackCallTests.Run_WithWork_GivesTheWorkALargeStack;
begin
  const HasLargeStack = TJSLargeStackCall.Run(
    function: Integer
    begin
      const IsLarge = (TJSStackGuard.RemainingBytes > MIN_LARGE_STACK_BYTES);
      Result := Ord(IsLarge);
    end);

  Assert.AreEqual(Ord(True), HasLargeStack);
end;

procedure TLargeStackCallTests.Run_WhenTheWorkRaises_RaisesTheErrorInTheCaller;
begin
  Assert.WillRaise(
    procedure
    begin
      TJSLargeStackCall.Run(
        function: Integer
        begin
          raise TJSErrorFactory.RangeError(FAILURE_MESSAGE);
        end);
    end,
    EJSRangeError);
end;

end.
