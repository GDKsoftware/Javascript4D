unit JS4D.Tests.FunctionSourceText;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TFunctionSourceTextTests = class
  private
    FEngine: TJSEngine;

    function SourceOf(const Expression: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ToString_FunctionDeclaration_ReturnsExactSource;

    [Test]
    procedure ToString_FunctionExpression_ReturnsExactSource;

    [Test]
    procedure ToString_FunctionDeclarationWithUnicodeEscapes_KeepsEscapes;

    [Test]
    procedure ToString_ArrowFunctionWithParentheses_ReturnsExactSource;

    [Test]
    procedure ToString_ArrowFunctionWithBareParameter_ReturnsExactSource;

    [Test]
    procedure ToString_ArrowFunctionWithConciseBody_ReturnsExactSource;

    [Test]
    procedure ToString_ObjectMethod_ReturnsSourceFromKey;

    [Test]
    procedure ToString_ObjectMethodWithComputedKey_ReturnsSourceFromBracket;

    [Test]
    procedure ToString_ObjectGetter_IncludesGetKeyword;

    [Test]
    procedure ToString_ObjectSetter_IncludesSetKeyword;

    [Test]
    procedure ToString_LineTerminators_ArePreserved;

    [Test]
    procedure ToString_FunctionConstructor_ReturnsAnonymousFunctionSource;

    [Test]
    procedure ToString_NativeFunction_ReturnsNativeCodeSource;

    [Test]
    procedure Name_FunctionConstructor_IsAnonymous;

    [Test]
    procedure Call_FunctionConstructor_DoesNotBindAnonymousInsideBody;
  end;

implementation

const
  EXPRESSION_ASSIGNMENT = 'var f = /* before */%s/* after */;';
  OBJECT_MEMBER_ASSIGNMENT = 'var f = { /* before */%s/* after */ }.f;';
  OBJECT_ACCESSOR_ASSIGNMENT = 'var f = Object.getOwnPropertyDescriptor({ /* before */%s/* after */ }, "f").%s;';

procedure TFunctionSourceTextTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionSourceTextTests.TearDown;
begin
  FEngine.Free;
end;

function TFunctionSourceTextTests.SourceOf(const Expression: string): string;
begin
  Result := FEngine.Evaluate(Expression).AsString;
end;

procedure TFunctionSourceTextTests.ToString_FunctionDeclaration_ReturnsExactSource;
begin
  const Source = 'function /* a */ f /* b */ ( /* c */ x /* d */ ) /* e */ { /* f */ }';
  FEngine.Execute(Source);

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_FunctionExpression_ReturnsExactSource;
begin
  const Source = 'function /* a */ F /* b */ ( /* c */ x /* d */ ) /* e */ { /* f */ }';
  FEngine.Execute(Format(EXPRESSION_ASSIGNMENT, [Source]));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_FunctionDeclarationWithUnicodeEscapes_KeepsEscapes;
begin
  const Source = 'function a(\u{62}, c) { b = \u{00063}; return b; }';
  FEngine.Execute(Source);

  Assert.AreEqual(Source, SourceOf('a.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ArrowFunctionWithParentheses_ReturnsExactSource;
begin
  const Source = '( /* a */ a /* b */ , /* c */ b /* d */ ) /* e */ => /* f */ { /* g */ }';
  FEngine.Execute(Format(EXPRESSION_ASSIGNMENT, [Source]));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ArrowFunctionWithBareParameter_ReturnsExactSource;
begin
  const Source = 'a /* a */ => /* b */ { return a; }';
  FEngine.Execute(Format(EXPRESSION_ASSIGNMENT, [Source]));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ArrowFunctionWithConciseBody_ReturnsExactSource;
begin
  FEngine.Execute('var f = [(a, b) => a + b /* tail */][0];');

  Assert.AreEqual('(a, b) => a + b', SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ObjectMethod_ReturnsSourceFromKey;
begin
  const Source = 'f /* a */ ( /* b */ ) /* c */ { /* d */ }';
  FEngine.Execute(Format(OBJECT_MEMBER_ASSIGNMENT, [Source]));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ObjectMethodWithComputedKey_ReturnsSourceFromBracket;
begin
  const Source = '[ /* a */ "f" /* b */ ] /* c */ ( /* d */ ) /* e */ { /* f */ }';
  FEngine.Execute(Format(OBJECT_MEMBER_ASSIGNMENT, [Source]));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ObjectGetter_IncludesGetKeyword;
begin
  const Source = 'get /* a */ f /* b */ ( /* c */ ) /* d */ { /* e */ }';
  FEngine.Execute(Format(OBJECT_ACCESSOR_ASSIGNMENT, [Source, 'get']));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_ObjectSetter_IncludesSetKeyword;
begin
  const Source = 'set /* a */ f /* b */ ( /* c */ a /* d */ ) /* e */ { /* f */ }';
  FEngine.Execute(Format(OBJECT_ACCESSOR_ASSIGNMENT, [Source, 'set']));

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_LineTerminators_ArePreserved;
begin
  const Lines: TArray<string> = ['function // a', 'f // b', '( // c', ') { }'];
  const Source = string.Join(#13#10, Lines);
  FEngine.Execute(Source);

  Assert.AreEqual(Source, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_FunctionConstructor_ReturnsAnonymousFunctionSource;
begin
  FEngine.Execute('var f = Function("a", " /* a */ b, c /* b */ //", "/* c */ ; /* d */ //");');

  const Lines: TArray<string> = ['function anonymous(a, /* a */ b, c /* b */ //', ') {', '/* c */ ; /* d */ //', '}'];
  const Expected = string.Join(#10, Lines);
  Assert.AreEqual(Expected, SourceOf('f.toString()'));
end;

procedure TFunctionSourceTextTests.ToString_NativeFunction_ReturnsNativeCodeSource;
begin
  Assert.AreEqual('function push() { [native code] }', SourceOf('Function.prototype.toString.call(Array.prototype.push)'));
end;

procedure TFunctionSourceTextTests.Name_FunctionConstructor_IsAnonymous;
begin
  Assert.AreEqual('anonymous', SourceOf('Function().name'));
end;

procedure TFunctionSourceTextTests.Call_FunctionConstructor_DoesNotBindAnonymousInsideBody;
begin
  FEngine.Execute('var anonymous = 42;');

  Assert.AreEqual(42.0, FEngine.Evaluate('Function("return anonymous")()').AsNumber);
end;

end.
