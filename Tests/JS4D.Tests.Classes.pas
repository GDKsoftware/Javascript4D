unit JS4D.Tests.Classes;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Engine;

type
  [TestFixture]
  TClassTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Method', 'class A { m() { return 1; } } new A().m()#1', '#')]
    [TestCase('Constructor', 'class A { constructor(x) { this.x = x; } } new A(5).x#5', '#')]
    [TestCase('StaticMethod', 'class A { static s() { return 2; } } A.s()#2', '#')]
    [TestCase('Accessors', 'class A { get v() { return this._v; } set v(x) { this._v = x * 2; } } var a = new A(); a.v = 2; a.v#4', '#')]
    [TestCase('StaticAccessor', 'class A { static get v() { return 8; } } A.v#8', '#')]
    [TestCase('ComputedName', 'var k = "dyn"; class A { [k + "1"]() { return 7; } } new A().dyn1()#7', '#')]
    [TestCase('ComputedSymbolName', 'var s = Symbol("sym"); class A { [s]() { return 1; } } new A()[s].name#[sym]', '#')]
    [TestCase('Expression', 'var C = class { m() { return 3; } }; new C().m()#3', '#')]
    [TestCase('ExpressionNameBinding', 'var C = class D { static n() { return typeof D; } }; C.n() + typeof D#functionundefined', '#')]
    [TestCase('InferredName', 'var C = class {}; C.name#C', '#')]
    [TestCase('InferredNameFromProperty', 'var o = { k: class {} }; o.k.name#k', '#')]
    [TestCase('StaticNameMethodWins', 'var C = class { static name() { return 1; } }; typeof C.name#function', '#')]
    [TestCase('DeclarationName', 'class A {} A.name#A', '#')]
    [TestCase('TypeOf', 'class A {} typeof A#function', '#')]
    [TestCase('MethodsAreNotEnumerable', 'class A { m() {} } Object.keys(A.prototype).length#0', '#')]
    [TestCase('PrototypeAttributes', 'class A {} var d = Object.getOwnPropertyDescriptor(A, "prototype"); [d.writable, d.enumerable, d.configurable].join()#false,false,false', '#')]
    [TestCase('ConstructorProperty', 'class A {} A.prototype.constructor === A#true', '#')]
    [TestCase('PropertyOrder', 'class A { static m() {} } Object.getOwnPropertyNames(A).join()#length,name,prototype,m', '#')]
    [TestCase('SourceText', 'class A { m() {} } A.toString()#class A { m() {} }', '#')]
    [TestCase('MethodSourceText', 'class A { static  m() {} } A.m.toString()#m() {}', '#')]
    [TestCase('BaseConstructorReturnsObject', 'class A { constructor() { return {z: 1}; } } new A().z#1', '#')]
    [TestCase('BaseConstructorIgnoresPrimitiveResult', 'class A { constructor() { this.z = 1; return 5; } } new A().z#1', '#')]
    [TestCase('ClassBodyIsStrict', 'class A { m() { return this; } } var f = new A().m; typeof f()#undefined', '#')]
    [TestCase('MethodIsNotConstructor', 'class A { m() {} } var r; try { new (new A().m)(); } catch (e) { r = e.name; } r#TypeError', '#')]
    [TestCase('StaticMethodNamedPrototypeComputed', 'var r; try { class A { static ["prototype"]() {} } } catch (e) { r = e.name; } r#TypeError', '#')]
    [TestCase('StaticAndInstanceSameName', 'class A { static x() { return 1; } x() { return 2; } } A.x() + new A().x()#3', '#')]
    [TestCase('MethodNamedStatic', 'class A { static() { return 1; } } new A().static()#1', '#')]
    [TestCase('MethodNamedGet', 'class A { get() { return 1; } set() { return 2; } } new A().get() + new A().set()#3', '#')]
    [TestCase('StringConstructorName', 'class A { "constructor"() { this.x = 1; } } new A().x#1', '#')]
    [TestCase('RegExpAfterDeclaration', 'class C {}/1/.test("1")#true', '#')]
    [TestCase('SuperMethodCall', 'class A { f() { return "a"; } } class B extends A { f() { return super.f() + "b"; } } new B().f()#ab', '#')]
    [TestCase('SuperConstructorCall', 'class A { constructor(x) { this.x = x; } } class B extends A { constructor() { super(3); this.y = 4; } } var b = new B(); b.x + b.y#7', '#')]
    [TestCase('DefaultDerivedConstructor', 'class A { constructor(a, b) { this.s = a + b; } } class B extends A {} new B(1, 2).s#3', '#')]
    [TestCase('DefaultDerivedConstructorIgnoresArrayIteration', 'var orig = Array.prototype[Symbol.iterator]; Array.prototype[Symbol.iterator] = function () { throw 1; }; class A { constructor(x) { this.x = x; } } class B extends A {} var r = new B(7).x; Array.prototype[Symbol.iterator] = orig; r#7', '#')]
    [TestCase('ExtendsNull', 'class A extends null {} Object.getPrototypeOf(A.prototype) === null#true', '#')]
    [TestCase('ExtendsNullConstructorParent', 'class A extends null {} Object.getPrototypeOf(A) === Function.prototype#true', '#')]
    [TestCase('ExtendsFunction', 'function F() { this.f = 1; } class A extends F {} new A().f#1', '#')]
    [TestCase('ExtendsArray', 'class L extends Array {} var l = new L(); l.push(1); l.length + "," + Array.isArray(l) + "," + (l instanceof L)#1,true,true', '#')]
    [TestCase('ExtendsError', 'class E extends Error {} var e = new E("m"); e.message + (e instanceof Error) + (e instanceof E)#mtruetrue', '#')]
    [TestCase('ExtendsMap', 'class M extends Map {} var m = new M([[1, 2]]); m.get(1) + "," + (m instanceof M)#2,true', '#')]
    [TestCase('ExtendsRegExp', 'class R extends RegExp {} var r = new R("a", "g"); r.test("a") + "," + (r instanceof R) + "," + r.flags#true,true,g', '#')]
    [TestCase('ExtendsTypedArray', 'class T extends Uint8Array {} var t = new T(2); t.length + "," + (t instanceof T)#2,true', '#')]
    [TestCase('ExtendsObject', 'class O extends Object {} var o = new O(1); (o instanceof O) + "," + (typeof o)#true,object', '#')]
    [TestCase('ExtendsBoolean', 'class B extends Boolean {} var b = new B(true); (b instanceof B) + "," + b.valueOf()#true,true', '#')]
    [TestCase('ExtendsFunctionConstructor', 'class F extends Function {} var f = new F("return 4"); (f instanceof F) + "," + f()#true,4', '#')]
    [TestCase('StaticInheritance', 'class A { static s() { return "s"; } } class B extends A { static t() { return super.s() + "t"; } } B.t() + B.s()#sts', '#')]
    [TestCase('ConstructorPrototypeChain', 'class A {} class B extends A {} Object.getPrototypeOf(B) === A#true', '#')]
    [TestCase('SuperPropertyAssignment', 'class A {} class B extends A { m() { super.x = 5; return this.x; } } new B().m()#5', '#')]
    [TestCase('SuperGetterReceiver', 'class A { get g() { return this.v; } } class B extends A { constructor() { super(); this.v = 9; } m() { return super.g; } } new B().m()#9', '#')]
    [TestCase('SuperComputedProperty', 'class A { f() { return 6; } } class B extends A { m() { var k = "f"; return super[k](); } } new B().m()#6', '#')]
    [TestCase('SuperInObjectLiteral', 'var p = { f() { return 1; } }; var o = { __proto__: p, f() { return super.f() + 1; } }; o.f()#2', '#')]
    [TestCase('SuperInObjectLiteralAccessor', 'var p = { get g() { return 4; } }; var o = { __proto__: p, get g() { return super.g + 1; } }; o.g#5', '#')]
    [TestCase('SuperFollowsPrototypeChanges', 'var o = { f() { return super.x; } }; Object.setPrototypeOf(o, { x: 1 }); var a = o.f(); Object.setPrototypeOf(o, { x: 2 }); a + "," + o.f()#1,2', '#')]
    [TestCase('SuperInArrow', 'class A { f() { return 8; } } class B extends A { m() { return (() => super.f())(); } } new B().m()#8', '#')]
    [TestCase('SuperCallInArrow', 'class A { constructor() { this.v = 1; } } class B extends A { constructor() { var f = () => super(); f(); this.w = this.v + 1; } } new B().w#2', '#')]
    [TestCase('SuperCallInEval', 'class A { constructor() { this.v = 1; } } class B extends A { constructor() { eval("super()"); this.w = this.v + 1; } } new B().w#2', '#')]
    [TestCase('SuperPropertyInEval', 'class A { f() { return 3; } } class B extends A { m() { return eval("super.f()"); } } new B().m()#3', '#')]
    [TestCase('DerivedReturnsObject', 'class A {} class B extends A { constructor() { return {z: 2}; } } new B().z#2', '#')]
    [TestCase('ThisIsSharedWithArrow', 'class A {} class B extends A { constructor() { var f = () => this; super(); this.x = 1; return f() === this ? f() : null; } } new B().x#1', '#')]
    [TestCase('NewTargetInFunction', 'function F() { this.t = new.target; } new F().t === F#true', '#')]
    [TestCase('NewTargetWithoutNew', 'function F() { return new.target; } typeof F()#undefined', '#')]
    [TestCase('NewTargetInDerivedChain', 'var seen; class A { constructor() { seen = new.target; } } class B extends A {} new B(); seen === B#true', '#')]
    [TestCase('NewTargetInArrow', 'function F() { return (() => new.target)(); } new F() === undefined#false', '#')]
    [TestCase('NewTargetFromReflect', 'function F() { this.t = new.target; } function G() {} Reflect.construct(F, [], G).t === G#true', '#')]
    [TestCase('NewTargetInEval', 'function F() { return eval("new.target"); } typeof F()#undefined', '#')]
    [TestCase('ReflectConstructPrototype', 'class A {} function G() {} G.prototype = { tag: 1 }; Reflect.construct(A, [], G).tag#1', '#')]
    procedure Script_ReturnsExpectedResult(const Source: string; const Expected: string);

    [Test]
    [TestCase('CallWithoutNew', 'class A {} A()#TypeError', '#')]
    [TestCase('ExtendsUndefinedBinding', 'class A extends Missing {}#ReferenceError', '#')]
    [TestCase('ExtendsNumber', 'class A extends 1 {}#TypeError', '#')]
    [TestCase('ExtendsMethod', 'class A extends ({ m() {} }).m {}#TypeError', '#')]
    [TestCase('ExtendsBadPrototype', 'function F() {} F.prototype = 1; class A extends F {}#TypeError', '#')]
    [TestCase('ThisBeforeSuper', 'class A {} class B extends A { constructor() { this.x = 1; } } new B()#ReferenceError', '#')]
    [TestCase('ThisBeforeSuperInArrow', 'class A {} class B extends A { constructor() { (() => this)(); super(); } } new B()#ReferenceError', '#')]
    [TestCase('MissingSuperCall', 'class A {} class B extends A { constructor() { } } new B()#ReferenceError', '#')]
    [TestCase('SuperCalledTwice', 'class A {} class B extends A { constructor() { super(); super(); } } new B()#ReferenceError', '#')]
    [TestCase('DerivedReturnsPrimitive', 'class A {} class B extends A { constructor() { super(); return 1; } } new B()#TypeError', '#')]
    [TestCase('SuperParentNotConstructor', 'class A {} class B extends A { constructor() { super(); } } Object.setPrototypeOf(B, Math.sin); Object.setPrototypeOf(B, {}); new B()#TypeError', '#')]
    [TestCase('TemporalDeadZone', 'new A(); class A {}#ReferenceError', '#')]
    [TestCase('TemporalDeadZoneInHeritage', 'class A extends A {}#ReferenceError', '#')]
    [TestCase('InnerBindingIsConstant', 'class A { static m() { A = 1; } } A.m()#TypeError', '#')]
    [TestCase('DeleteSuperProperty', 'class A { m() { delete super.x; } } new A().m()#ReferenceError', '#')]
    [TestCase('SuperPropertyOfNullPrototype', 'class A extends null { m() { return super.x; } } A.prototype.m.call({})#TypeError', '#')]
    [TestCase('ReturnWithoutValueInDerivedConstructor', 'class A {} class B extends A { constructor() { super(); return; } } new B()#', '#')]
    procedure Class_RaisesError(const Source: string; const Expected: string);

    [Test]
    [TestCase('DuplicateConstructor', 'class A { constructor() {} constructor() {} }', '#')]
    [TestCase('GetterConstructor', 'class A { get constructor() {} }', '#')]
    [TestCase('SetterConstructor', 'class A { set constructor(v) {} }', '#')]
    [TestCase('StaticPrototype', 'class A { static prototype() {} }', '#')]
    [TestCase('StaticStringPrototype', 'class A { static "prototype"() {} }', '#')]
    [TestCase('SuperCallInBaseConstructor', 'class A { constructor() { super(); } }', '#')]
    [TestCase('SuperCallInMethod', 'class A extends Object { m() { super(); } }', '#')]
    [TestCase('SuperPropertyInFunction', 'function f() { super.x; }', '#')]
    [TestCase('SuperCallInFunction', 'function f() { super(); }', '#')]
    [TestCase('SuperAtTopLevel', 'super.x;', '#')]
    [TestCase('NewSuper', 'class A extends Object { constructor() { new super(); } }', '#')]
    [TestCase('BareSuper', 'class A extends Object { m() { super; } }', '#')]
    [TestCase('NewTargetAtTopLevel', 'new.target;', '#')]
    [TestCase('NewTargetInArrowAtTopLevel', '(() => new.target)();', '#')]
    [TestCase('MisspelledNewTarget', 'function f() { new.targ; }', '#')]
    [TestCase('DeclarationWithoutName', 'class { }', '#')]
    [TestCase('DeclarationInStatementPosition', 'if (true) class A {}', '#')]
    [TestCase('DeclarationAsLoopBody', 'while (false) class A {}', '#')]
    [TestCase('LabelledDeclaration', 'a: class A {}', '#')]
    [TestCase('Redeclaration', 'class A {} class A {}', '#')]
    [TestCase('RedeclarationOfLet', 'let A; class A {}', '#')]
    [TestCase('StrictBodyRejectsWith', 'class A { m() { with (a) {} } }', '#')]
    [TestCase('StrictNameLet', 'class let {}', '#')]
    [TestCase('StrictNameYield', 'class yield {}', '#')]
    [TestCase('StrictNameEval', 'class eval {}', '#')]
    [TestCase('StrictOctalInBody', 'class A { m() { return 010; } }', '#')]
    [TestCase('StrictOctalInHeritage', 'class A extends (010, Object) {}', '#')]
    [TestCase('DuplicateMethodParameters', 'class A { m(a, a) {} }', '#')]
    [TestCase('ClassAsIdentifier', 'var class;', '#')]
    [TestCase('ExtendsAsIdentifier', 'var extends;', '#')]
    [TestCase('MissingBody', 'class A', '#')]
    [TestCase('GetterWithParameter', 'class A { get x(a) {} }', '#')]
    [TestCase('CommaBetweenMembers', 'class A { m() {}, n() {} }', '#')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('KeywordNamedMethods', 'class A { static() {} get() {} set() {} static static() {} static get get() {} }', '#')]
    [TestCase('KeywordAsPropertyName', 'class A { class() {} extends() {} super() {} }', '#')]
    [TestCase('StringConstructor', 'class A { "constructor"() {} }', '#')]
    [TestCase('EmptyElements', 'class A { ;; m() {} ; }', '#')]
    [TestCase('NumericAndStringNames', 'class A { 1() {} "two"() {} 3.5() {} }', '#')]
    [TestCase('ComputedConstructor', 'class A { ["constructor"]() {} }', '#')]
    [TestCase('StaticConstructor', 'class A { static constructor() {} }', '#')]
    [TestCase('NewTargetInFunction', 'function f() { new.target; }', '#')]
    [TestCase('NewTargetInArrowInFunction', 'function f() { return () => new.target; }', '#')]
    [TestCase('SuperPropertyInObjectMethod', 'var o = { m() { return super.x; } };', '#')]
    [TestCase('SuperPropertyInObjectGetter', 'var o = { get m() { return super.x; } };', '#')]
    [TestCase('SuperCallInDerivedConstructor', 'class A extends Object { constructor() { super(); } }', '#')]
    [TestCase('ClassExpressionInExpression', 'var x = [class {}, class B extends Object {}];', '#')]
    [TestCase('NamedClassExpressionLet', 'var C = class yieldy {};', '#')]
    procedure Source_IsAccepted(const Source: string);
  end;

implementation

procedure TClassTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TClassTests.TearDown;
begin
  FEngine.Free;
end;

function TClassTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TClassTests.Script_ReturnsExpectedResult(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TClassTests.Class_RaisesError(const Source: string; const Expected: string);
begin
  const ErrorName = ErrorNameOf(Source);

  Assert.AreEqual(Expected, ErrorName);
end;

procedure TClassTests.Source_IsSyntaxError(const Source: string);
begin
  const ErrorName = ErrorNameOf(Source);

  Assert.AreEqual('SyntaxError', ErrorName);
end;

procedure TClassTests.Source_IsAccepted(const Source: string);
begin
  const ErrorName = ErrorNameOf(Source);

  Assert.AreEqual('', ErrorName);
end;

end.
