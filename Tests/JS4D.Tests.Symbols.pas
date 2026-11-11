unit JS4D.Tests.Symbols;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TSymbolTests = class
  private
    FEngine: TJSEngine;

    function Run(const Script: string): string;
    function ErrorNameOf(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('TypeOf', 'typeof Symbol()|symbol', '|')]
    [TestCase('TypeOfWrapper', 'typeof Object(Symbol())|object', '|')]
    [TestCase('TypeOfWellKnown', 'typeof Symbol.iterator|symbol', '|')]
    [TestCase('TypeOfConstructor', 'typeof Symbol|function', '|')]
    [TestCase('EveryCallIsUnique', 'Symbol() === Symbol()|false', '|')]
    [TestCase('SameValueIsEqual', 'var s = Symbol("a"); s === s|true', '|')]
    [TestCase('LooseEquality', 'var s = Symbol("a"); s == s|true', '|')]
    [TestCase('LooseInequality', 'Symbol("a") == Symbol("a")|false', '|')]
    [TestCase('NotEqualToItsDescription', 'Symbol("a") == "a"|false', '|')]
    [TestCase('IsTruthy', 'Symbol() ? "yes" : "no"|yes', '|')]
    [TestCase('Negation', '!Symbol()|false', '|')]
    [TestCase('ObjectIsSame', 'var s = Symbol(); Object.is(s, s)|true', '|')]
    [TestCase('ObjectIsOther', 'Object.is(Symbol(), Symbol())|false', '|')]
    [TestCase('StringConversionOfSymbol', 'String(Symbol("abc"))|Symbol(abc)', '|')]
    [TestCase('StringConversionWithoutDescription', 'String(Symbol())|Symbol()', '|')]
    [TestCase('StringConversionEmptyDescription', 'String(Symbol(""))|Symbol()', '|')]
    [TestCase('ToStringMethod', 'Symbol("x").toString()|Symbol(x)', '|')]
    [TestCase('ValueOfReturnsSymbol', 'var s = Symbol(); s.valueOf() === s|true', '|')]
    [TestCase('DescriptionOfSymbol', 'Symbol("abc").description|abc', '|')]
    [TestCase('DescriptionOfEmptyString', 'Symbol("").description === ""|true', '|')]
    [TestCase('DescriptionUndefined', 'Symbol().description === undefined|true', '|')]
    [TestCase('DescriptionIsConverted', 'Symbol(12).description|12', '|')]
    [TestCase('DescriptionOfUndefinedArgument', 'Symbol(undefined).description === undefined|true', '|')]
    [TestCase('DescriptionOfNull', 'Symbol(null).description|null', '|')]
    [TestCase('DescriptionIsAnAccessor', 'typeof Object.getOwnPropertyDescriptor(Symbol.prototype, "description").get|function', '|')]
    [TestCase('DescriptionIsNotOwn', 'Symbol("a").hasOwnProperty("description")|false', '|')]
    [TestCase('ConstructorLength', 'Symbol.length|0', '|')]
    [TestCase('ConstructorName', 'Symbol.name|Symbol', '|')]
    [TestCase('PrototypeConstructor', 'Symbol.prototype.constructor === Symbol|true', '|')]
    [TestCase('PrototypeIsReadOnly', 'Object.getOwnPropertyDescriptor(Symbol, "prototype").writable|false', '|')]
    [TestCase('ToStringTag', 'Object.prototype.toString.call(Symbol())|[object Symbol]', '|')]
    [TestCase('ToStringTagOfWrapper', 'Object.prototype.toString.call(Object(Symbol()))|[object Symbol]', '|')]
    [TestCase('SymbolOfWrapper', 'var s = Symbol(); Object(s) == s|true', '|')]
    [TestCase('WrapperIsNotStrictlyEqual', 'var s = Symbol(); Object(s) === s|false', '|')]
    [TestCase('WrapperValueOf', 'var s = Symbol(); Object(s).valueOf() === s|true', '|')]
    [TestCase('WrapperInheritsFromSymbolPrototype', 'Object.getPrototypeOf(Object(Symbol())) === Symbol.prototype|true', '|')]
    [TestCase('WrapperPropertyAccess', 'var o = Object(Symbol("q")); o.description|q', '|')]
    [TestCase('PrimitiveMethodCallOnSymbol', 'Symbol("w").toString()|Symbol(w)', '|')]
    [TestCase('StrictPrimitiveThis', '(function () { "use strict"; Symbol.prototype.me = function () { return typeof this; }; return Symbol().me(); })()|symbol', '|')]
    [TestCase('SloppyWrapperThis', '(function () { Symbol.prototype.me2 = function () { return typeof this; }; return Symbol().me2(); })()|object', '|')]
    procedure Symbol_Value_BehavesLikeAPrimitive(const Script, Expected: string);

    [Test]
    [TestCase('ForReturnsSameSymbol', 'Symbol.for("k") === Symbol.for("k")|true', '|')]
    [TestCase('ForDiffersFromSymbol', 'Symbol.for("k") === Symbol("k")|false', '|')]
    [TestCase('ForDescription', 'Symbol.for("k").description|k', '|')]
    [TestCase('ForConvertsKey', 'Symbol.for(1) === Symbol.for("1")|true', '|')]
    [TestCase('ForUndefinedKey', 'Symbol.for().description|undefined', '|')]
    [TestCase('KeyForRegistered', 'Symbol.keyFor(Symbol.for("shared"))|shared', '|')]
    [TestCase('KeyForUnregistered', 'Symbol.keyFor(Symbol("shared")) === undefined|true', '|')]
    [TestCase('KeyForWellKnown', 'Symbol.keyFor(Symbol.iterator) === undefined|true', '|')]
    [TestCase('KeyForSameDescriptionAsRegistered', 'Symbol.for("d"); Symbol.keyFor(Symbol("d")) === undefined|true', '|')]
    [TestCase('ForLength', 'Symbol.for.length|1', '|')]
    [TestCase('KeyForLength', 'Symbol.keyFor.length|1', '|')]
    procedure Symbol_Registry_SharesSymbolsByKey(const Script, Expected: string);

    [Test]
    [TestCase('WellKnownAreUnique', 'Symbol.iterator !== Symbol.toPrimitive|true', '|')]
    [TestCase('WellKnownAreStable', 'Symbol.hasInstance === Symbol.hasInstance|true', '|')]
    [TestCase('IteratorDescription', 'Symbol.iterator.description|Symbol.iterator', '|')]
    [TestCase('AsyncIteratorDescription', 'Symbol.asyncIterator.toString()|Symbol(Symbol.asyncIterator)', '|')]
    [TestCase('SpeciesDescription', 'Symbol.species.description|Symbol.species', '|')]
    [TestCase('ToPrimitiveDescription', 'Symbol.toPrimitive.description|Symbol.toPrimitive', '|')]
    [TestCase('WellKnownIsReadOnly', 'var d = Object.getOwnPropertyDescriptor(Symbol, "match"); [d.writable, d.enumerable, d.configurable].join()|false,false,false', '|')]
    [TestCase('AllWellKnownDefined', '["asyncIterator", "hasInstance", "isConcatSpreadable", "iterator", "match", "matchAll", "replace", "search", "species", "split", "toPrimitive", "toStringTag", "unscopables"].every(function (n) { return typeof Symbol[n] === "symbol"; })|true', '|')]
    procedure Symbol_WellKnown_AreDefined(const Script, Expected: string);

    [Test]
    [TestCase('ToNumber', '+Symbol()|', '|')]
    [TestCase('ToNumberFunction', 'Number(Symbol())|', '|')]
    [TestCase('Subtraction', 'Symbol() - 1|', '|')]
    [TestCase('Multiplication', '2 * Symbol()|', '|')]
    [TestCase('BitwiseNot', '~Symbol()|', '|')]
    [TestCase('Addition', 'Symbol() + 1|', '|')]
    [TestCase('StringConcatenation', '"a" + Symbol()|', '|')]
    [TestCase('TemplateLiteral', '`${Symbol()}`|', '|')]
    [TestCase('Relational', 'Symbol() < 1|', '|')]
    [TestCase('JoinElement', '[Symbol()].join()|', '|')]
    [TestCase('StringObject', 'new String(Symbol())|', '|')]
    [TestCase('NewSymbol', 'new Symbol()|', '|')]
    [TestCase('ParseInt', 'parseInt(Symbol())|', '|')]
    [TestCase('DescriptionIsSymbol', 'Symbol(Symbol())|', '|')]
    [TestCase('KeyForNotASymbol', 'Symbol.keyFor("x")|', '|')]
    [TestCase('ToStringOnNonSymbol', 'Symbol.prototype.toString.call("x")|', '|')]
    [TestCase('ValueOfOnNonSymbol', 'Symbol.prototype.valueOf.call({})|', '|')]
    [TestCase('DescriptionOnNonSymbol', 'Object.getOwnPropertyDescriptor(Symbol.prototype, "description").get.call({})|', '|')]
    [TestCase('ArrayElementJoin', 'new Array(Symbol()).join()|', '|')]
    [TestCase('InOperatorLeftSymbolWithPrimitiveRight', 'Symbol() in 1|', '|')]
    procedure Symbol_Conversion_RaisesTypeError(const Script, Ignored: string);

    [Test]
    [TestCase('SymbolKeyedAssignment', 'var s = Symbol(); var o = {}; o[s] = 5; o[s]|5', '|')]
    [TestCase('SymbolKeyDoesNotCollideWithDescription', 'var s = Symbol("a"); var o = {}; o[s] = 1; o.a === undefined|true', '|')]
    [TestCase('TwoSymbolsTwoProperties', 'var a = Symbol("x"), b = Symbol("x"); var o = {}; o[a] = 1; o[b] = 2; o[a] + o[b]|3', '|')]
    [TestCase('InOperator', 'var s = Symbol(); var o = {}; o[s] = 1; (s in o) + "," + (Symbol() in o)|true,false', '|')]
    [TestCase('HasOwnProperty', 'var s = Symbol(); var o = {}; o[s] = 1; o.hasOwnProperty(s)|true', '|')]
    [TestCase('HasOwnPropertyOfAbsent', 'var o = {}; o.hasOwnProperty(Symbol())|false', '|')]
    [TestCase('PropertyIsEnumerable', 'var s = Symbol(); var o = {}; o[s] = 1; o.propertyIsEnumerable(s)|true', '|')]
    [TestCase('DeleteSymbolProperty', 'var s = Symbol(); var o = {}; o[s] = 1; delete o[s]; (s in o)|false', '|')]
    [TestCase('InheritedSymbolProperty', 'var s = Symbol(); var p = {}; p[s] = "inherited"; Object.create(p)[s]|inherited', '|')]
    [TestCase('SymbolKeyOnArray', 'var s = Symbol(); var a = [1, 2]; a[s] = "x"; a[s] + a.length|x2', '|')]
    [TestCase('SymbolKeyOnFunction', 'var s = Symbol(); function f() {} f[s] = 3; f[s]|3', '|')]
    [TestCase('SymbolKeyOnWrapper', 'var s = Symbol(); var o = Object("str"); o[s] = 4; o[s]|4', '|')]
    [TestCase('SymbolKeyViaWrapperObject', 'var s = Symbol(); var o = {}; o[Object(s)] = 6; o[s]|6', '|')]
    [TestCase('SymbolValuedProperty', 'var s = Symbol("v"); var o = { k: s }; o.k === s|true', '|')]
    [TestCase('SymbolKeyedCall', 'var s = Symbol(); var o = {}; o[s] = function () { return "called"; }; o[s]()|called', '|')]
    [TestCase('SymbolKeyEvaluatedOnceInCall', 'var n = 0; var s = Symbol(); var o = {}; o[s] = function () {}; o[(n++, s)](); n|1', '|')]
    [TestCase('MemberCallObjectEvaluatedOnce', 'var n = 0; function f() { n++; return { g: function () { return 1; } }; } f().g(); n|1', '|')]
    [TestCase('ComputedKeyInLiteral', 'var s = Symbol(); var o = { [s]: 7 }; o[s]|7', '|')]
    [TestCase('ComputedKeyInLiteralIsTemporary', 'var o = { [Symbol.for("t")]: 8 }; o[Symbol.for("t")]|8', '|')]
    [TestCase('FreshSymbolKeyInLiteral', 'var o = { [Symbol("fresh")]: 9 }; Object.getOwnPropertySymbols(o).length + o[Object.getOwnPropertySymbols(o)[0]]|10', '|')]
    [TestCase('ComputedMethodInLiteral', 'var s = Symbol(); var o = { [s]() { return "m"; } }; o[s]()|m', '|')]
    [TestCase('ComputedAccessorInLiteral', 'var s = Symbol(); var o = { get [s]() { return "g"; } }; o[s]|g', '|')]
    [TestCase('FunctionNameFromSymbolKey', 'var s = Symbol("desc"); var o = { [s]: function () {} }; o[s].name|[desc]', '|')]
    [TestCase('FunctionNameFromSymbolWithoutDescription', 'var s = Symbol(); var o = { [s]() {} }; o[s].name === ""|true', '|')]
    [TestCase('AccessorNameFromSymbolKey', 'var s = Symbol("acc"); var o = { get [s]() { return 1; } }; Object.getOwnPropertyDescriptor(o, s).get.name|get [acc]', '|')]
    [TestCase('GetOwnPropertyNamesSkipsSymbols', 'var o = { a: 1 }; o[Symbol()] = 2; Object.getOwnPropertyNames(o).join()|a', '|')]
    [TestCase('KeysSkipSymbols', 'var o = { a: 1 }; o[Symbol()] = 2; Object.keys(o).join()|a', '|')]
    [TestCase('ForInSkipsSymbols', 'var o = { a: 1 }; o[Symbol()] = 2; var r = ""; for (var k in o) r += k; r|a', '|')]
    [TestCase('JsonStringifySkipsSymbols', 'var o = { a: 1 }; o[Symbol()] = 2; JSON.stringify(o)|{"a":1}', '|')]
    [TestCase('JsonStringifySkipsSymbolValues', 'JSON.stringify({ a: Symbol() })|{}', '|')]
    [TestCase('JsonStringifyArraySymbol', 'JSON.stringify([Symbol()])|[null]', '|')]
    [TestCase('JsonStringifySymbolAlone', 'JSON.stringify(Symbol()) === undefined|true', '|')]
    [TestCase('GetOwnPropertySymbols', 'var a = Symbol("a"), b = Symbol("b"); var o = {}; o[a] = 1; o[b] = 2; var r = Object.getOwnPropertySymbols(o); (r[0] === a) + "," + (r[1] === b) + "," + r.length|true,true,2', '|')]
    [TestCase('GetOwnPropertySymbolsOfPlainObject', 'Object.getOwnPropertySymbols({ a: 1 }).length|0', '|')]
    [TestCase('GetOwnPropertySymbolsLength', 'Object.getOwnPropertySymbols.length|1', '|')]
    [TestCase('GetOwnPropertySymbolsOfString', 'Object.getOwnPropertySymbols("abc").length|0', '|')]
    [TestCase('GetOwnPropertySymbolsOfArray', 'var s = Symbol(); var a = [1]; a[s] = 2; Object.getOwnPropertySymbols(a).length|1', '|')]
    [TestCase('OwnKeysOrderIndicesStringsSymbols', 'var s = Symbol("s"); var o = {}; o[s] = 0; o.b = 0; o[2] = 0; o.a = 0; o[1] = 0; Object.getOwnPropertyNames(o).join() + ";" + Object.getOwnPropertySymbols(o).length|1,2,b,a;1', '|')]
    [TestCase('SymbolsInCreationOrder', 'var a = Symbol("a"), b = Symbol("b"), c = Symbol("c"); var o = {}; o[b] = 0; o[c] = 0; o[a] = 0; Object.getOwnPropertySymbols(o).map(function (s) { return s.description; }).join("")|bca', '|')]
    [TestCase('DeletedSymbolIsNotListed', 'var a = Symbol(), b = Symbol(); var o = {}; o[a] = 0; o[b] = 0; delete o[a]; Object.getOwnPropertySymbols(o).length|1', '|')]
    [TestCase('ObjectAssignCopiesSymbols', 'var s = Symbol(); var src = {}; src[s] = 3; var t = Object.assign({}, src); t[s]|3', '|')]
    [TestCase('ObjectAssignSkipsNonEnumerableSymbols', 'var s = Symbol(); var src = {}; Object.defineProperty(src, s, { value: 3 }); var t = Object.assign({}, src); (s in t)|false', '|')]
    [TestCase('ObjectSpreadCopiesSymbols', 'var s = Symbol(); var src = {}; src[s] = 4; var t = { ...src }; t[s]|4', '|')]
    [TestCase('ObjectRestCopiesSymbols', 'var s = Symbol(); var src = { a: 1 }; src[s] = 5; var { a, ...rest } = src; rest[s]|5', '|')]
    [TestCase('ObjectRestSkipsDestructuredSymbol', 'var s = Symbol(); var src = { a: 1 }; src[s] = 5; var { [s]: v, ...rest } = src; v + "," + (s in rest)|5,false', '|')]
    [TestCase('DestructuringSymbolKey', 'var s = Symbol(); var { [s]: x } = { [s]: 11 }; x|11', '|')]
    [TestCase('DestructuringSymbolDefault', 'var s = Symbol(); var { [s]: x = 12 } = {}; x|12', '|')]
    [TestCase('AssignmentPatternSymbolKey', 'var s = Symbol(); var x; ({ [s]: x } = { [s]: 13 }); x|13', '|')]
    [TestCase('DefinePropertyWithSymbol', 'var s = Symbol(); var o = {}; Object.defineProperty(o, s, { value: 14 }); o[s]|14', '|')]
    [TestCase('DefinedSymbolIsNotEnumerable', 'var s = Symbol(); var o = {}; Object.defineProperty(o, s, { value: 14 }); o.propertyIsEnumerable(s)|false', '|')]
    [TestCase('DefinePropertiesWithSymbolKeys', 'var s = Symbol(); var o = Object.defineProperties({}, { [s]: { value: 15, enumerable: true } }); o[s]|15', '|')]
    [TestCase('ObjectCreateWithSymbolKeys', 'var s = Symbol(); var o = Object.create(null, { [s]: { value: 16 } }); o[s]|16', '|')]
    [TestCase('GetOwnPropertyDescriptorOfSymbolKey', 'var s = Symbol(); var o = {}; o[s] = 17; var d = Object.getOwnPropertyDescriptor(o, s); d.value + "," + d.writable + "," + d.enumerable + "," + d.configurable|17,true,true,true', '|')]
    [TestCase('GetOwnPropertyDescriptorOfAbsentSymbol', 'Object.getOwnPropertyDescriptor({}, Symbol()) === undefined|true', '|')]
    [TestCase('GetOwnPropertyDescriptorsIncludesSymbols', 'var s = Symbol(); var o = {}; o[s] = 18; Object.getOwnPropertyDescriptors(o)[s].value|18', '|')]
    [TestCase('FreezeLocksSymbolProperties', 'var s = Symbol(); var o = {}; o[s] = 1; Object.freeze(o); o[s] = 2; o[s]|1', '|')]
    [TestCase('SymbolAccessorProperty', 'var s = Symbol(); var o = {}; Object.defineProperty(o, s, { get: function () { return "got"; } }); o[s]|got', '|')]
    [TestCase('SymbolPropertyOfPrototypeChain', 'var s = Symbol(); function F() {} F.prototype[s] = "p"; new F()[s]|p', '|')]
    [TestCase('SymbolPropertyKeepsValueAlive', 'var o = {}; (function () { var s = Symbol("local"); o[s] = function () { return "alive"; }; })(); o[Object.getOwnPropertySymbols(o)[0]]()|alive', '|')]
    [TestCase('SymbolKeyAfterGarbageCollection', 'var o = {}; (function () { o[Symbol("local")] = 1; })(); o[Object.getOwnPropertySymbols(o)[0]]|1', '|')]
    [TestCase('StringKeyLikeSymbolIsAString', 'var o = {}; var key = "﷐" + "9999999"; o[key] = 1; Object.getOwnPropertyNames(o).length + "," + Object.getOwnPropertySymbols(o).length|1,0', '|')]
    procedure Symbol_PropertyKey_NamesProperties(const Script, Expected: string);

    [Test]
    [TestCase('CustomHasInstance', 'var o = { [Symbol.hasInstance](v) { return v === 1; } }; (1 instanceof o) + "," + (2 instanceof o)|true,false', '|')]
    [TestCase('HasInstanceResultIsConverted', 'var o = { [Symbol.hasInstance]() { return "yes"; } }; (1 instanceof o)|true', '|')]
    [TestCase('HasInstanceOnFunction', 'function F() {} Object.defineProperty(F, Symbol.hasInstance, { value: function () { return true; } }); ({}) instanceof F|true', '|')]
    [TestCase('HasInstanceCalledWithRightAsThis', 'var seen; var o = { [Symbol.hasInstance]() { seen = this; return true; } }; 1 instanceof o; seen === o|true', '|')]
    [TestCase('FunctionPrototypeHasInstance', 'function F() {} F[Symbol.hasInstance](new F())|true', '|')]
    [TestCase('FunctionPrototypeHasInstanceFalse', 'function F() {} F[Symbol.hasInstance]({})|false', '|')]
    [TestCase('FunctionPrototypeHasInstanceOnNonFunction', 'Function.prototype[Symbol.hasInstance].call({}, {})|false', '|')]
    [TestCase('FunctionPrototypeHasInstanceOnPrimitive', 'function F() {} F[Symbol.hasInstance](1)|false', '|')]
    [TestCase('FunctionHasInstanceAttributes', 'var d = Object.getOwnPropertyDescriptor(Function.prototype, Symbol.hasInstance); [d.writable, d.enumerable, d.configurable].join()|false,false,false', '|')]
    [TestCase('FunctionHasInstanceName', 'Function.prototype[Symbol.hasInstance].name|[Symbol.hasInstance]', '|')]
    [TestCase('FunctionHasInstanceLength', 'Function.prototype[Symbol.hasInstance].length|1', '|')]
    [TestCase('OrdinaryInstanceOfStillWorks', 'function F() {} (new F() instanceof F) + "," + ({} instanceof F) + "," + ([] instanceof Array)|true,false,true', '|')]
    [TestCase('BoundFunctionInstanceOf', 'function F() {} var B = F.bind(null); (new F() instanceof B)|true', '|')]
    [TestCase('HasInstanceNotCallable', 'var o = { [Symbol.hasInstance]: 1 }; 1 instanceof o|', '|')]
    procedure Symbol_HasInstance_CustomizesInstanceOf(const Script, Expected: string);

    [Test]
    [TestCase('ToPrimitiveOnAddition', 'var o = { [Symbol.toPrimitive](hint) { return hint; } }; o + ""|default', '|')]
    [TestCase('ToPrimitiveOnNumber', 'var o = { [Symbol.toPrimitive](hint) { return hint === "number" ? 42 : 0; } }; +o|42', '|')]
    [TestCase('ToPrimitiveOnString', 'var o = { [Symbol.toPrimitive](hint) { return hint; } }; String(o)|string', '|')]
    [TestCase('ToPrimitiveOnTemplate', 'var o = { [Symbol.toPrimitive](hint) { return hint; } }; `${o}`|string', '|')]
    [TestCase('ToPrimitiveOnPropertyKey', 'var o = { [Symbol.toPrimitive](hint) { return "k"; } }; var t = { k: 1 }; t[o]|1', '|')]
    [TestCase('ToPrimitiveOnRelational', 'var hints = []; var o = { [Symbol.toPrimitive](hint) { hints.push(hint); return 1; } }; o < 2; hints.join()|number', '|')]
    [TestCase('ToPrimitiveOnLooseEquality', 'var o = { [Symbol.toPrimitive](hint) { return hint; } }; o == "default"|true', '|')]
    [TestCase('ToPrimitiveReturnsSymbol', 'var s = Symbol(); var o = { [Symbol.toPrimitive]() { return s; } }; var t = {}; t[o] = 1; t[s]|1', '|')]
    [TestCase('ToPrimitiveNotCallable', 'var o = { [Symbol.toPrimitive]: 1 }; +o|', '|')]
    [TestCase('ToPrimitiveUndefinedFallsBack', 'var o = { [Symbol.toPrimitive]: undefined, valueOf() { return 3; } }; +o|3', '|')]
    [TestCase('ToPrimitiveNullFallsBack', 'var o = { [Symbol.toPrimitive]: null, valueOf() { return 4; } }; +o|4', '|')]
    [TestCase('ToPrimitiveReturnsObject', 'var o = { [Symbol.toPrimitive]() { return {}; } }; +o|', '|')]
    [TestCase('ToPrimitiveThisIsTheObject', 'var o = { [Symbol.toPrimitive]() { return this === o ? 1 : 0; } }; +o|1', '|')]
    [TestCase('DateToPrimitiveDefault', 'var d = new Date(0); d[Symbol.toPrimitive]("default") === d.toString()|true', '|')]
    [TestCase('DateToPrimitiveString', 'var d = new Date(0); d[Symbol.toPrimitive]("string") === d.toString()|true', '|')]
    [TestCase('DateToPrimitiveNumber', 'var d = new Date(5); d[Symbol.toPrimitive]("number")|5', '|')]
    [TestCase('DateToPrimitiveInvalidHint', 'new Date(0)[Symbol.toPrimitive]("x")|', '|')]
    [TestCase('DateToPrimitiveName', 'Date.prototype[Symbol.toPrimitive].name|[Symbol.toPrimitive]', '|')]
    [TestCase('DateToPrimitiveLength', 'Date.prototype[Symbol.toPrimitive].length|1', '|')]
    [TestCase('DateToPrimitiveAttributes', 'var d = Object.getOwnPropertyDescriptor(Date.prototype, Symbol.toPrimitive); [d.writable, d.enumerable, d.configurable].join()|false,false,true', '|')]
    [TestCase('DateAdditionIsConcatenation', 'typeof (new Date(0) + 1)|string', '|')]
    [TestCase('DateSubtractionIsNumeric', 'new Date(10) - new Date(4)|6', '|')]
    [TestCase('DateLooseEqualityUsesString', 'var d = new Date(0); d == d.toString()|true', '|')]
    [TestCase('SymbolPrototypeToPrimitive', 'var s = Symbol(); Object(s)[Symbol.toPrimitive]() === s|true', '|')]
    [TestCase('SymbolPrototypeToPrimitiveName', 'Symbol.prototype[Symbol.toPrimitive].name|[Symbol.toPrimitive]', '|')]
    [TestCase('SymbolPrototypeToPrimitiveAttributes', 'var d = Object.getOwnPropertyDescriptor(Symbol.prototype, Symbol.toPrimitive); [d.writable, d.enumerable, d.configurable].join()|false,false,true', '|')]
    [TestCase('SymbolWrapperToStringHint', 'var s = Symbol("h"); var o = Object(s); var t = {}; t[o] = 1; t[s]|1', '|')]
    procedure Symbol_ToPrimitive_ConvertsObjects(const Script, Expected: string);

    [Test]
    [TestCase('ToStringTagOfObject', 'var o = { [Symbol.toStringTag]: "Custom" }; Object.prototype.toString.call(o)|[object Custom]', '|')]
    [TestCase('ToStringTagOfClassLikeInstance', 'function F() {} F.prototype[Symbol.toStringTag] = "Fx"; Object.prototype.toString.call(new F())|[object Fx]', '|')]
    [TestCase('ToStringTagOverridesArray', 'var a = []; a[Symbol.toStringTag] = "Arr"; Object.prototype.toString.call(a)|[object Arr]', '|')]
    [TestCase('NonStringTagIsIgnored', 'var o = { [Symbol.toStringTag]: 1 }; Object.prototype.toString.call(o)|[object Object]', '|')]
    [TestCase('MathTag', 'Object.prototype.toString.call(Math)|[object Math]', '|')]
    [TestCase('JsonTag', 'Object.prototype.toString.call(JSON)|[object JSON]', '|')]
    [TestCase('MathTagProperty', 'Math[Symbol.toStringTag]|Math', '|')]
    [TestCase('DeletedMathTag', 'delete Math[Symbol.toStringTag]; Object.prototype.toString.call(Math)|[object Object]', '|')]
    [TestCase('SymbolPrototypeTag', 'Symbol.prototype[Symbol.toStringTag]|Symbol', '|')]
    [TestCase('SymbolPrototypeTagAttributes', 'var d = Object.getOwnPropertyDescriptor(Symbol.prototype, Symbol.toStringTag); [d.writable, d.enumerable, d.configurable].join()|false,false,true', '|')]
    [TestCase('DeletedSymbolTag', 'delete Symbol.prototype[Symbol.toStringTag]; Object.prototype.toString.call(Symbol())|[object Object]', '|')]
    [TestCase('PlainTagsUnchanged', '[Object.prototype.toString.call([]), Object.prototype.toString.call(function () {}), Object.prototype.toString.call(1)].join()|[object Array],[object Function],[object Number]', '|')]
    procedure Symbol_ToStringTag_RenamesObjects(const Script, Expected: string);

    [Test]
    [TestCase('SpreadableObject', 'var o = { length: 2, 0: "a", 1: "b", [Symbol.isConcatSpreadable]: true }; [1].concat(o).join()|1,a,b', '|')]
    [TestCase('SpreadableObjectReceiver', 'var o = { length: 1, 0: "x", [Symbol.isConcatSpreadable]: true, concat: Array.prototype.concat }; o.concat(2).join()|x,2', '|')]
    [TestCase('NonSpreadableArray', 'var a = [2, 3]; a[Symbol.isConcatSpreadable] = false; [1].concat(a).length|2', '|')]
    [TestCase('NonSpreadableArrayIsKept', 'var a = [2, 3]; a[Symbol.isConcatSpreadable] = false; [1].concat(a)[1] === a|true', '|')]
    [TestCase('NonSpreadableReceiver', 'var a = [1, 2]; a[Symbol.isConcatSpreadable] = false; a.concat(3).length|2', '|')]
    [TestCase('TruthyFlagIsConverted', 'var o = { length: 1, 0: "z", [Symbol.isConcatSpreadable]: 1 }; [].concat(o).join()|z', '|')]
    [TestCase('FlagOnPrototype', 'function F() { this.length = 1; this[0] = "p"; } F.prototype[Symbol.isConcatSpreadable] = true; [].concat(new F()).join()|p', '|')]
    [TestCase('FlagFalseOnPlainObject', 'var o = { length: 1, 0: "y", [Symbol.isConcatSpreadable]: false }; [].concat(o)[0] === o|true', '|')]
    [TestCase('SpreadableArrayLikeSkipsHoles', 'var o = { length: 3, 0: "a", 2: "c", [Symbol.isConcatSpreadable]: true }; var r = [].concat(o); r.length + "," + (1 in r)|3,false', '|')]
    [TestCase('PrimitivesAreNeverSpread', 'String.prototype[Symbol.isConcatSpreadable] = true; var r = [].concat("ab").length; delete String.prototype[Symbol.isConcatSpreadable]; r|1', '|')]
    [TestCase('PlainConcatStillFast', '[1].concat([2, 3], 4, [5]).join()|1,2,3,4,5', '|')]
    procedure Symbol_IsConcatSpreadable_ControlsConcat(const Script, Expected: string);

    [Test]
    [TestCase('UnscopablesBlocksBinding', 'var x = "outer"; var o = { x: "inner", [Symbol.unscopables]: { x: true } }; with (o) { x }|outer', '|')]
    [TestCase('UnscopablesFalseKeepsBinding', 'var x = "outer"; var o = { x: "inner", [Symbol.unscopables]: { x: false } }; with (o) { x }|inner', '|')]
    [TestCase('UnscopablesOnlyAffectsListedNames', 'var y = "outer"; var o = { x: "inner", y: "iy", [Symbol.unscopables]: { x: true } }; with (o) { y }|iy', '|')]
    [TestCase('UnscopablesAssignment', 'var x = "outer"; var o = { x: "inner", [Symbol.unscopables]: { x: true } }; with (o) { x = "changed"; } o.x + "," + x|inner,changed', '|')]
    [TestCase('UnscopablesTruthyValue', 'var x = "outer"; var o = { x: "inner", [Symbol.unscopables]: { x: 1 } }; with (o) { x }|outer', '|')]
    [TestCase('UnscopablesNonObjectIgnored', 'var x = "outer"; var o = { x: "inner", [Symbol.unscopables]: 1 }; with (o) { x }|inner', '|')]
    [TestCase('UnscopablesInPrototype', 'var x = "outer"; var p = { [Symbol.unscopables]: { x: true } }; var o = Object.create(p); o.x = "inner"; with (o) { x }|outer', '|')]
    [TestCase('UnscopablesOfCall', 'function f() { return "outer"; } var o = { f: function () { return "inner"; }, [Symbol.unscopables]: { f: true } }; with (o) { f() }|outer', '|')]
    [TestCase('ArrayPrototypeUnscopables', 'var d = Object.getOwnPropertyDescriptor(Array.prototype, Symbol.unscopables); [d.writable, d.enumerable, d.configurable].join()|false,false,true', '|')]
    [TestCase('ArrayPrototypeUnscopablesKeys', 'Object.keys(Array.prototype[Symbol.unscopables]).sort().join()|copyWithin,entries,fill,find,findIndex,flat,flatMap,includes,keys,values', '|')]
    [TestCase('ArrayPrototypeUnscopablesPrototype', 'Object.getPrototypeOf(Array.prototype[Symbol.unscopables]) === null|true', '|')]
    [TestCase('ArrayKeysUnscopableInWith', 'var keys = "outer"; with ([]) { keys }|outer', '|')]
    [TestCase('ArrayLengthStillScoped', 'with ([1, 2]) { length }|2', '|')]
    procedure Symbol_Unscopables_HidesWithBindings(const Script, Expected: string);

    [Test]
    [TestCase('ArraySpeciesGetter', 'Array[Symbol.species] === Array|true', '|')]
    [TestCase('ArraySpeciesGetterName', 'Object.getOwnPropertyDescriptor(Array, Symbol.species).get.name|get [Symbol.species]', '|')]
    [TestCase('ArraySpeciesGetterHasNoSetter', 'Object.getOwnPropertyDescriptor(Array, Symbol.species).set === undefined|true', '|')]
    [TestCase('ArraySpeciesGetterThisValue', 'Object.getOwnPropertyDescriptor(Array, Symbol.species).get.call(5)|5', '|')]
    [TestCase('RegExpSpeciesGetter', 'RegExp[Symbol.species] === RegExp|true', '|')]
    [TestCase('MapUsesSpecies', 'function C(n) { this.made = n; } var a = [1, 2]; a.constructor = { [Symbol.species]: C }; var r = a.map(function (x) { return x * 2; }); (r instanceof C) + "," + r[0] + r[1] + "," + r.made|true,24,2', '|')]
    [TestCase('FilterUsesSpecies', 'function C(n) { this.made = n; } var a = [1, 2, 3]; a.constructor = { [Symbol.species]: C }; var r = a.filter(function (x) { return x > 1; }); (r instanceof C) + "," + r[0] + r[1] + "," + r.made|true,23,0', '|')]
    [TestCase('SliceUsesSpecies', 'function C(n) { this.made = n; } var a = [1, 2, 3]; a.constructor = { [Symbol.species]: C }; var r = a.slice(1); (r instanceof C) + "," + r.length + "," + r.made|true,2,2', '|')]
    [TestCase('SpliceUsesSpecies', 'function C(n) { this.made = n; } var a = [1, 2, 3]; a.constructor = { [Symbol.species]: C }; var r = a.splice(0, 2); (r instanceof C) + "," + r.length + "," + r.made + "," + a.length|true,2,2,1', '|')]
    [TestCase('ConcatUsesSpecies', 'function C(n) { this.made = n; } var a = [1]; a.constructor = { [Symbol.species]: C }; var r = a.concat([2]); (r instanceof C) + "," + r.length + "," + r.made + "," + r[1]|true,2,0,2', '|')]
    [TestCase('SpeciesNullGivesPlainArray', 'var a = [1]; a.constructor = { [Symbol.species]: null }; Array.isArray(a.map(function (x) { return x; }))|true', '|')]
    [TestCase('SpeciesUndefinedGivesPlainArray', 'var a = [1]; a.constructor = { [Symbol.species]: undefined }; Array.isArray(a.slice())|true', '|')]
    [TestCase('ConstructorUndefinedGivesPlainArray', 'var a = [1]; a.constructor = undefined; Array.isArray(a.slice())|true', '|')]
    [TestCase('SpeciesNotAConstructor', 'var a = [1]; a.constructor = { [Symbol.species]: 1 }; a.slice()|', '|')]
    [TestCase('SpeciesNotAConstructorFunction', 'var a = [1]; a.constructor = { [Symbol.species]: Math.max }; a.slice()|', '|')]
    [TestCase('ConstructorPrimitiveRaises', 'var a = [1]; a.constructor = 1; a.map(function () {})|', '|')]
    [TestCase('PlainArraysAreUnaffected', 'var r = [1, 2, 3].map(function (x) { return x + 1; }); Array.isArray(r) + "," + r.join()|true,2,3,4', '|')]
    [TestCase('SpeciesReceivesConstructorResultProperties', 'function C() { this.extra = "e"; } var a = [1]; a.constructor = { [Symbol.species]: C }; a.map(function (x) { return x; }).extra|e', '|')]
    procedure Symbol_Species_CreatesArrayResults(const Script, Expected: string);

    [Test]
    [TestCase('StringIndexOfSearch', '"abc".indexOf({ [Symbol.toPrimitive]() { return "c"; } })|2', '|')]
    [TestCase('StringIndexOfPosition', '"abcabc".indexOf("c", { [Symbol.toPrimitive]() { return 3; } })|5', '|')]
    [TestCase('StringIndexOfHintIsString', 'var h; "a".indexOf({ [Symbol.toPrimitive](hint) { h = hint; return "a"; } }); h|string', '|')]
    [TestCase('StringIndexOfPositionHintIsNumber', 'var h; "a".indexOf("a", { [Symbol.toPrimitive](hint) { h = hint; return 0; } }); h|number', '|')]
    [TestCase('DateConstructorHint', 'var h; new Date({ [Symbol.toPrimitive](hint) { h = hint; return 0; } }); h|default', '|')]
    [TestCase('DateConstructorUsesStringResult', 'new Date({ [Symbol.toPrimitive]() { return "1970-01-01T00:00:00.000Z"; } }).getTime()|0', '|')]
    [TestCase('DateParseHint', 'var h; Date.parse({ [Symbol.toPrimitive](hint) { h = hint; return "x"; } }); h|string', '|')]
    [TestCase('BoundFunctionName', 'function foo() {} foo.bind().name|bound foo', '|')]
    [TestCase('BoundFunctionNameWithoutStringName', 'Object.defineProperty(function () {}, "name", { value: 1 }).bind().name|bound ', '|')]
    [TestCase('ToJsonWithoutThis', 'var f = Date.prototype.toJSON; f.call(undefined)|', '|')]
    [TestCase('ToJsonOfObjectWithToPrimitive', 'Date.prototype.toJSON.call({ [Symbol.toPrimitive]() { return 5; }, toISOString() { return "iso"; } })|iso', '|')]
    [TestCase('SymbolWrapperAsSearchString', '"".indexOf(Object(Symbol()))|', '|')]
    procedure Symbol_BuiltinArguments_UseToPrimitive(const Script, Expected: string);

    [Test]
    procedure Symbol_GetOwnPropertySymbols_OfNull_RaisesTypeError;

    [Test]
    procedure Symbol_ConsoleLog_PrintsDescriptiveString;
  end;

implementation

procedure TSymbolTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TSymbolTests.TearDown;
begin
  FEngine.Free;
end;

function TSymbolTests.Run(const Script: string): string;
begin
  Result := FEngine.Evaluate(Script).ToString;
end;

function TSymbolTests.ErrorNameOf(const Script: string): string;
begin
  FEngine.Execute('var caught = "none";');
  FEngine.Execute(Format('try { %s; } catch (e) { caught = e.name; }', [Script]));

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TSymbolTests.Symbol_Value_BehavesLikeAPrimitive(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_Registry_SharesSymbolsByKey(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_WellKnown_AreDefined(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_Conversion_RaisesTypeError(const Script, Ignored: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Script));
end;

procedure TSymbolTests.Symbol_PropertyKey_NamesProperties(const Script, Expected: string);
begin
  if Expected = '' then
    Assert.AreEqual('TypeError', ErrorNameOf(Script))
  else
    Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_HasInstance_CustomizesInstanceOf(const Script, Expected: string);
begin
  if Expected = '' then
    Assert.AreEqual('TypeError', ErrorNameOf(Script))
  else
    Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_ToPrimitive_ConvertsObjects(const Script, Expected: string);
begin
  if Expected = '' then
    Assert.AreEqual('TypeError', ErrorNameOf(Script))
  else
    Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_ToStringTag_RenamesObjects(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_IsConcatSpreadable_ControlsConcat(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_Unscopables_HidesWithBindings(const Script, Expected: string);
begin
  Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_Species_CreatesArrayResults(const Script, Expected: string);
begin
  if Expected = '' then
    Assert.AreEqual('TypeError', ErrorNameOf(Script))
  else
    Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_BuiltinArguments_UseToPrimitive(const Script, Expected: string);
begin
  if Expected = '' then
    Assert.AreEqual('TypeError', ErrorNameOf(Script))
  else
    Assert.AreEqual(Expected, Run(Script));
end;

procedure TSymbolTests.Symbol_ConsoleLog_PrintsDescriptiveString;
begin
  var Output := '';

  FEngine.OnConsoleOutput :=
    procedure(const Text: string)
    begin
      Output := Text;
    end;

  FEngine.Execute('console.log("a", Symbol("b"))');

  Assert.AreEqual('a Symbol(b)', Output);
end;

procedure TSymbolTests.Symbol_GetOwnPropertySymbols_OfNull_RaisesTypeError;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('Object.getOwnPropertySymbols(null)'));
end;

end.
