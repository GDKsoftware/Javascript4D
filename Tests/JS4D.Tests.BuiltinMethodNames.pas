unit JS4D.Tests.BuiltinMethodNames;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TBuiltinMethodNameTests = class
  private
    function HasMethod(const Kind: string; const MethodName: string): Boolean;
    function MethodNamesOf(const Kind: string): TArray<string>;

  public
    [Test]
    [TestCase('Array', 'Array')]
    [TestCase('String', 'String')]
    [TestCase('Number', 'Number')]
    procedure HasMethod_EveryListedName_ReturnsTrue(const Kind: string);

    [Test]
    [TestCase('Array unknown name', 'Array,notAMethod')]
    [TestCase('Array miscased name', 'Array,Push')]
    [TestCase('Array empty name', 'Array,')]
    [TestCase('String unknown name', 'String,notAMethod')]
    [TestCase('String miscased name', 'String,CharAt')]
    [TestCase('String empty name', 'String,')]
    [TestCase('Number unknown name', 'Number,notAMethod')]
    [TestCase('Number miscased name', 'Number,ToFixed')]
    [TestCase('Number empty name', 'Number,')]
    procedure HasMethod_UnknownOrMiscasedName_ReturnsFalse(const Kind: string; const MethodName: string);
  end;

implementation

uses
  System.SysUtils,
  JS4D.Builtins;

function TBuiltinMethodNameTests.HasMethod(const Kind: string; const MethodName: string): Boolean;
begin
  if Kind = 'Array' then
  begin
    Result := TJSBuiltins.HasArrayMethod(MethodName);
  end
  else if Kind = 'String' then
  begin
    Result := TJSBuiltins.HasStringMethod(MethodName);
  end
  else if Kind = 'Number' then
  begin
    Result := TJSBuiltins.HasNumberMethod(MethodName);
  end
  else
  begin
    raise ENotSupportedException.CreateFmt('Unsupported kind: %s', [Kind]);
  end;
end;

function TBuiltinMethodNameTests.MethodNamesOf(const Kind: string): TArray<string>;
begin
  if Kind = 'Array' then
  begin
    Result := TJSBuiltins.ArrayMethodNames;
  end
  else if Kind = 'String' then
  begin
    Result := TJSBuiltins.StringMethodNames;
  end
  else if Kind = 'Number' then
  begin
    Result := TJSBuiltins.NumberMethodNames;
  end
  else
  begin
    raise ENotSupportedException.CreateFmt('Unsupported kind: %s', [Kind]);
  end;
end;

procedure TBuiltinMethodNameTests.HasMethod_EveryListedName_ReturnsTrue(const Kind: string);
begin
  for var MethodName in MethodNamesOf(Kind) do
  begin
    Assert.IsTrue(HasMethod(Kind, MethodName), MethodName);
  end;
end;

procedure TBuiltinMethodNameTests.HasMethod_UnknownOrMiscasedName_ReturnsFalse(const Kind: string;
                                                                              const MethodName: string);
begin
  const IsKnown = HasMethod(Kind, MethodName);

  Assert.IsFalse(IsKnown);
end;

end.
