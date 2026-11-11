unit JS4D.Tests.Destructuring;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Errors,
  JS4D.Engine;

type
  [TestFixture]
  TDestructuringTests = class
  private
    FEngine: TJSEngine;

    function ErrorNameOf(const Source: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Basic', 'var [a, b] = [1, 2]; a + "," + b|1,2', '|')]
    [TestCase('Hole', 'var [, b] = [1, 2]; b|2', '|')]
    [TestCase('Rest', 'var [a, ...r] = [1, 2, 3]; r.join()|2,3', '|')]
    [TestCase('RestIsArray', 'var [...r] = [1]; Array.isArray(r)|true', '|')]
    [TestCase('RestOfShortArray', 'var [a, b, ...r] = [1]; r.length|0', '|')]
    [TestCase('DefaultUsedForUndefined', 'var [a = 5] = []; a|5', '|')]
    [TestCase('DefaultNotUsedForNull', 'var [a = 5] = [null]; String(a)|null', '|')]
    [TestCase('DefaultNotUsedWhenPresent', 'var [a = 5] = [0]; a|0', '|')]
    [TestCase('DefaultSeesEarlierElement', 'var [a, b = a + 1] = [1]; b|2', '|')]
    [TestCase('Nested', 'var [[a], [b, c]] = [[1], [2, 3]]; a + b + c|6', '|')]
    [TestCase('NestedObject', 'var [{x}] = [{x: 4}]; x|4', '|')]
    [TestCase('String', 'var [a, b] = "xy"; a + b|xy', '|')]
    [TestCase('StringSurrogatePair', 'var [a, b] = "a'#$D83D#$DE00'"; b.length|2', '|')]
    [TestCase('MissingElementIsUndefined', 'var [a] = []; typeof a|undefined', '|')]
    [TestCase('ArrayHole', 'var [a, b] = [1, , 3]; typeof b|undefined', '|')]
    [TestCase('NameInferenceForDefault', 'var [f = function() {}] = []; f.name|f', '|')]
    [TestCase('NameInferenceForArrow', 'var [f = () => 1] = []; f.name|f', '|')]
    [TestCase('NoNameForNestedPatternDefault', 'var [[f] = [function() {}]] = []; f.name|', '|')]
    [TestCase('Empty', 'var [] = [1]; 1|1', '|')]
    procedure ArrayPattern_Var_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Basic', 'var {a, b} = {a: 1, b: 2}; a + "," + b|1,2', '|')]
    [TestCase('Renamed', 'var {a: x} = {a: 3}; x|3', '|')]
    [TestCase('Default', 'var {a = 4} = {}; a|4', '|')]
    [TestCase('RenamedDefault', 'var {a: x = 6} = {}; x|6', '|')]
    [TestCase('Nested', 'var {a: {b}} = {a: {b: 7}}; b|7', '|')]
    [TestCase('NestedArray', 'var {a: [b]} = {a: [8]}; b|8', '|')]
    [TestCase('ComputedKey', 'var k = "z"; var {[k]: v} = {z: 9}; v|9', '|')]
    [TestCase('StringKey', 'var {"a b": v} = {"a b": 1}; v|1', '|')]
    [TestCase('NumericKey', 'var {1: v} = [0, 5]; v|5', '|')]
    [TestCase('PrimitiveNumber', 'var {toFixed} = 1; typeof toFixed|function', '|')]
    [TestCase('PrimitiveString', 'var {length} = "abc"; length|3', '|')]
    [TestCase('InheritedProperty', 'var {x} = Object.create({x: 2}); x|2', '|')]
    [TestCase('Getter', 'var {x} = { get x() { return 3; } }; x|3', '|')]
    [TestCase('Empty', 'var {} = 1; 1|1', '|')]
    [TestCase('MissingIsUndefined', 'var {a} = {}; typeof a|undefined', '|')]
    [TestCase('NameInferenceForDefault', 'var {f = function() {}} = {}; f.name|f', '|')]
    [TestCase('KeywordKey', 'var {if: v} = {if: 1}; v|1', '|')]
    [TestCase('ArrayLengthProperty', 'var {length} = [1, 2]; length|2', '|')]
    procedure ObjectPattern_Var_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Basic', 'var {a, ...r} = {a: 1, b: 2, c: 3}; Object.keys(r).join()|b,c', '|')]
    [TestCase('Values', 'var {...r} = {a: 1}; r.a|1', '|')]
    [TestCase('IsCopy', 'var o = {a: 1}; var {...r} = o; r !== o|true', '|')]
    [TestCase('SkipsNonEnumerable', 'var o = {}; Object.defineProperty(o, "h", {value: 1}); var {...r} = o; Object.keys(r).length|0', '|')]
    [TestCase('ComputedKeyIsExcluded', 'var k = "a"; var {[k]: x, ...r} = {a: 1, b: 2}; Object.keys(r).join()|b', '|')]
    [TestCase('String', 'var {...r} = "ab"; r[0] + r[1]|ab', '|')]
    [TestCase('Number', 'var {...r} = 1; Object.keys(r).length|0', '|')]
    [TestCase('AssignmentToVariable', 'var a, r; ({a, ...r} = {a: 1, b: 2}); Object.keys(r).join()|b', '|')]
    [TestCase('AssignmentToMember', 'var o = {}; ({...o.r} = {x: 1}); o.r.x|1', '|')]
    [TestCase('InParameter', 'function f({a, ...r}) { return Object.keys(r).join(); } f({a: 1, b: 2, c: 3})|b,c', '|')]
    [TestCase('Getter', 'var n = 0; var o = { get a() { n++; return 1; } }; var {...r} = o; r.a + "," + n|1,1', '|')]
    [TestCase('NullIsTypeError', 'var r; try { var {...x} = null; } catch (e) { r = e.name; } r|TypeError', '|')]
    procedure ObjectRest_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Let', 'let [a, b] = [1, 2]; a + b|3', '|')]
    [TestCase('Const', 'const {a, b} = {a: 1, b: 2}; a + b|3', '|')]
    [TestCase('LetObject', 'let {a: {b}} = {a: {b: 5}}; b|5', '|')]
    [TestCase('InBlock', '{ let [a] = [1]; a } |1', '|')]
    [TestCase('Closures', 'var f = []; { let [a, b] = [1, 2]; f.push(() => a + b); } f[0]()|3', '|')]
    [TestCase('MultipleDeclarators', 'let [a] = [1], {b} = {b: 2}; a + b|3', '|')]
    [TestCase('DefaultSeesEarlier', 'let [a, b = a] = [3]; b|3', '|')]
    [TestCase('ConstInFunction', 'function f() { const [a, b] = [1, 2]; return a * b; } f()|2', '|')]
    [TestCase('LetIsAssignable', 'let [a] = [1]; a = 2; a|2', '|')]
    procedure Lexical_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Array', 'var a, b; [a, b] = [1, 2]; a + "," + b|1,2', '|')]
    [TestCase('Swap', 'var a = 1, b = 2; [a, b] = [b, a]; a + "," + b|2,1', '|')]
    [TestCase('Object', 'var a, b; ({a, b} = {a: 1, b: 2}); a + "," + b|1,2', '|')]
    [TestCase('ObjectRenamed', 'var x; ({a: x} = {a: 5}); x|5', '|')]
    [TestCase('Default', 'var a; [a = 3] = []; a|3', '|')]
    [TestCase('ObjectDefault', 'var a; ({a = 4} = {}); a|4', '|')]
    [TestCase('MemberTarget', 'var o = {}; [o.x, o["y"]] = [1, 2]; o.x + o.y|3', '|')]
    [TestCase('ObjectMemberTarget', 'var o = {}; ({a: o.p} = {a: 6}); o.p|6', '|')]
    [TestCase('Nested', 'var a, b; [[a], {b}] = [[1], {b: 2}]; a + b|3', '|')]
    [TestCase('Rest', 'var a, r; [a, ...r] = [1, 2, 3]; r.join()|2,3', '|')]
    [TestCase('RestMemberTarget', 'var o = {}; [...o.r] = [1, 2]; o.r.join()|1,2', '|')]
    [TestCase('RestPattern', 'var a, b; [...[a, b]] = [1, 2]; a + b|3', '|')]
    [TestCase('ResultIsRightHandSide', 'var a; var r = [1, 2]; ([a] = r) === r|true', '|')]
    [TestCase('ObjectResultIsRightHandSide', 'var a; var r = {a: 1}; ({a} = r) === r|true', '|')]
    [TestCase('Hole', 'var b; [, b] = [1, 2]; b|2', '|')]
    [TestCase('String', 'var a, b; [a, b] = "xy"; a + b|xy', '|')]
    [TestCase('NameInference', 'var f; [f = function() {}] = []; f.name|f', '|')]
    [TestCase('NoNameForMemberTarget', 'var o = {}; [o.f = function() {}] = []; o.f.name|', '|')]
    [TestCase('LetBinding', 'let a; [a] = [1]; a|1', '|')]
    [TestCase('NestedDefault', 'var a; [[a] = [7]] = []; a|7', '|')]
    [TestCase('DuplicatePrototypeKey', 'var a, b; ({__proto__: a, __proto__: b} = {}); 1|1', '|')]
    [TestCase('SpreadCopiesProperties', 'var s = {a: 1}; var c = {...s, b: 2}; c.a + c.b|3', '|')]
    [TestCase('SpreadIsACopy', 'var s = {a: 1}; ({...s}) !== s|true', '|')]
    [TestCase('SpreadSkipsNullAndUndefined', 'Object.keys({...null, ...undefined, a: 1}).join()|a', '|')]
    [TestCase('SpreadString', '({..."ab"})[1]|b', '|')]
    [TestCase('SpreadSkipsNonEnumerable', 'var o = Object.defineProperty({}, "h", {value: 1}); Object.keys({...o}).length|0', '|')]
    [TestCase('SpreadLaterPropertyWins', '({a: 1, ...{a: 2}}).a|2', '|')]
    [TestCase('SpreadEarlierPropertyIsOverwritten', '({...{a: 2}, a: 1}).a|1', '|')]
    procedure Assignment_Result(const Source: string; const Expected: string);

    [Test]
    procedure Assignment_TargetIsResolvedBeforeValueIsRead;

    [Test]
    procedure Assignment_ElementsAreEvaluatedLeftToRight;

    [Test]
    procedure Assignment_ToConstant_IsTypeError;

    [Test]
    procedure Assignment_ToUndeclaredInStrictMode_IsReferenceError;

    [Test]
    procedure Assignment_ToUndeclaredInSloppyMode_CreatesGlobal;

    [Test]
    [TestCase('Basic', 'function f([a, b]) { return a + b; } f([1, 2])|3', '|')]
    [TestCase('Object', 'function f({a, b}) { return a + b; } f({a: 1, b: 2})|3', '|')]
    [TestCase('Default', 'function f([a] = [5]) { return a; } f()|5', '|')]
    [TestCase('ObjectDefault', 'function f({a} = {a: 6}) { return a; } f()|6', '|')]
    [TestCase('ElementDefault', 'function f({a = 7}) { return a; } f({})|7', '|')]
    [TestCase('AfterSimple', 'function f(x, [a], y) { return x + a + y; } f(1, [2], 3)|6', '|')]
    [TestCase('RestPattern', 'function f(...[a, b]) { return a + b; } f(1, 2, 3)|3', '|')]
    [TestCase('RestObjectPattern', 'function f(...{length}) { return length; } f(1, 2, 3)|3', '|')]
    [TestCase('Arrow', 'var f = ([a, b]) => a + b; f([1, 2])|3', '|')]
    [TestCase('ArrowObject', 'var f = ({a}) => a; f({a: 4})|4', '|')]
    [TestCase('ArrowAfterSimple', 'var f = (x, {a}) => x + a; f(1, {a: 2})|3', '|')]
    [TestCase('ArrowWithDefault', 'var f = ([a] = [8]) => a; f()|8', '|')]
    [TestCase('ArrowObjectCoverInitializer', 'var f = ({a = 9}) => a; f({})|9', '|')]
    [TestCase('Method', 'var o = { m([a]) { return a; } }; o.m([3])|3', '|')]
    [TestCase('Setter', 'var o = { set s([a]) { this.v = a; } }; o.s = [4]; o.v|4', '|')]
    [TestCase('FunctionExpression', 'var f = function({a}) { return a; }; f({a: 2})|2', '|')]
    [TestCase('DefaultSeesEarlierParameter', 'function f(a, [b = a]) { return b; } f(5, [])|5', '|')]
    [TestCase('PatternDefaultSeesEarlierPattern', 'function f([a], {b = a}) { return b; } f([6], {})|6', '|')]
    [TestCase('Closure', 'function f([a]) { return () => a; } f([1])()|1', '|')]
    [TestCase('BodyVarWithPatternName', 'function f([a]) { var a; return a; } f([2])|2', '|')]
    [TestCase('BodyVarAssignedIsSeparate', 'function f([a], g = () => a) { var a = 9; return g() + "," + a; } f([1])|1,9', '|')]
    [TestCase('NameInference', 'function f({g = function() {}}) { return g.name; } f({})|g', '|')]
    [TestCase('ArgumentsHoldsOriginalValues', 'function f([a]) { return arguments[0][0]; } f([3])|3', '|')]
    [TestCase('ArgumentsIsNotMapped', 'function f([a]) { a = 5; return arguments[0][0]; } f([3])|3', '|')]
    [TestCase('FunctionConstructor', 'new Function("[a, b]", "return a + b")([1, 2])|3', '|')]
    procedure Parameter_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('PatternsCount', 'function f([a], {b}) {} f.length|2', '|')]
    [TestCase('StopsAtDefault', 'function f([a], b = 1, {c}) {} f.length|1', '|')]
    [TestCase('PatternDefault', 'function f([a] = []) {} f.length|0', '|')]
    [TestCase('RestPatternIsNotCounted', 'function f(a, ...[b]) {} f.length|1', '|')]
    [TestCase('Arrow', '(([a], {b}) => 1).length|2', '|')]
    procedure Length_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('Array', 'var r = ""; try { throw [1, 2]; } catch ([a, b]) { r = a + "," + b; } r|1,2', '|')]
    [TestCase('Object', 'var r = ""; try { throw {a: 3}; } catch ({a}) { r = a; } r|3', '|')]
    [TestCase('Default', 'var r = ""; try { throw []; } catch ([a = 4]) { r = a; } r|4', '|')]
    [TestCase('Closure', 'var f; try { throw [5]; } catch ([a]) { f = () => a; } f()|5', '|')]
    [TestCase('ScopedToCatch', 'try { throw [5]; } catch ([a]) {} typeof a|undefined', '|')]
    [TestCase('ThrownError', 'var r; try { null.x; } catch ({name}) { r = name; } r|TypeError', '|')]
    procedure Catch_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('VarArray', 'var r = ""; for (var [a, b] in {xy: 1}) { r = a + b; } r|xy', '|')]
    [TestCase('VarObject', 'var r = ""; for (var {length} in {abc: 1}) { r = length; } r|3', '|')]
    [TestCase('LetArray', 'var r = ""; for (let [a, b] in {xy: 1}) { r += a + b; } r|xy', '|')]
    [TestCase('ConstObject', 'var r = ""; for (const {length} in {abc: 1, de: 2}) { r += length; } r|32', '|')]
    [TestCase('AssignmentArray', 'var a, b; for ([a, b] in {xy: 1}) {} a + b|xy', '|')]
    [TestCase('AssignmentObject', 'var length; for ({length} in {abc: 1}) {} length|3', '|')]
    [TestCase('AssignmentMember', 'var o = {}; for (o.k in {a: 1}) {} o.k|a', '|')]
    [TestCase('LetClosures', 'var f = []; for (let [a] in {x: 1, y: 2}) { f.push(() => a); } f[0]() + f[1]()|xy', '|')]
    [TestCase('VarIsHoisted', 'var r = typeof a; for (var [a] in {x: 1}) {} r|undefined', '|')]
    procedure ForIn_Result(const Source: string; const Expected: string);

    [Test]
    [TestCase('NullInArray', 'var [a] = null;', '|')]
    [TestCase('UndefinedInArray', 'var [a] = undefined;', '|')]
    [TestCase('NumberInArray', 'var [a] = 1;', '|')]
    [TestCase('ObjectInArray', 'var [a] = {};', '|')]
    [TestCase('NullInObject', 'var {a} = null;', '|')]
    [TestCase('UndefinedInObject', 'var {a} = undefined;', '|')]
    [TestCase('NullInObjectAssignment', 'var a; ({a} = null);', '|')]
    [TestCase('NullInArrayAssignment', 'var a; [a] = null;', '|')]
    [TestCase('NullInParameter', 'function f({a}) {} f(null);', '|')]
    [TestCase('UndefinedInParameter', 'function f([a]) {} f();', '|')]
    [TestCase('NullInEmptyObjectPattern', 'var {} = null;', '|')]
    [TestCase('ThrowingGetter', 'var {a} = { get a() { throw new TypeError(); } };', '|')]
    procedure Pattern_RaisesTypeError(const Source: string);

    [Test]
    [TestCase('TemporalDeadZone', 'let [a = b, b] = [];', '|')]
    [TestCase('OwnTemporalDeadZone', 'let [a = a] = [];', '|')]
    [TestCase('ParameterDeadZone', 'function f([a = b], b) {} f([]);', '|')]
    [TestCase('ParameterOwnDeadZone', 'function f([a = a]) {} f([]);', '|')]
    [TestCase('ParameterObjectDeadZone', 'function f({a = b, b}) {} f({});', '|')]
    procedure Pattern_RaisesReferenceError(const Source: string);

    [Test]
    procedure Const_Pattern_AssignmentIsTypeError;

    [Test]
    procedure Rest_Element_CopiesRemainingElementsAtThatPoint;

    [Test]
    procedure Array_ElementsAreReadLazily;

    [Test]
    procedure Default_IsEvaluatedOnlyWhenNeeded;

    [Test]
    procedure Default_IsEvaluatedInOrder;

    [Test]
    procedure ComputedKey_IsEvaluatedBeforeTarget;

    [Test]
    procedure Statement_AtBlockStart_IsNotAnObjectPattern;

    [Test]
    [TestCase('NoInitializerArray', 'var [a];', '|')]
    [TestCase('NoInitializerObject', 'var {a};', '|')]
    [TestCase('NoInitializerLet', 'let [a];', '|')]
    [TestCase('NoInitializerConst', 'const {a};', '|')]
    [TestCase('NoInitializerInForHead', 'for (var [a];;) {}', '|')]
    [TestCase('NoInitializerInLetForHead', 'for (let {a};;) {}', '|')]
    [TestCase('RestNotLast', 'var [...a, b] = [];', '|')]
    [TestCase('RestTrailingComma', 'var [...a,] = [];', '|')]
    [TestCase('RestWithInitializer', 'var [...a = []] = [];', '|')]
    [TestCase('ObjectRestNotLast', 'var {...a, b} = {};', '|')]
    [TestCase('ObjectRestTrailingComma', 'var {...a,} = {};', '|')]
    [TestCase('ObjectRestIsPattern', 'var {...{a}} = {};', '|')]
    [TestCase('DuplicateLexical', 'let [a, a] = [];', '|')]
    [TestCase('DuplicateLexicalAcrossPatterns', 'let [a] = [], {a} = {};', '|')]
    [TestCase('DuplicateLexicalWithVar', 'var a; let [a] = [];', '|')]
    [TestCase('LetAsLexicalName', 'let [let] = [];', '|')]
    [TestCase('LetAsConstName', 'const {let} = {};', '|')]
    [TestCase('KeywordAsShorthand', 'var {if} = {};', '|')]
    [TestCase('NumberAsShorthand', 'var {1} = {};', '|')]
    [TestCase('StrictEvalBinding', '"use strict"; var [eval] = [];', '|')]
    [TestCase('StrictArgumentsBinding', '"use strict"; var {arguments} = {};', '|')]
    [TestCase('StrictReservedBinding', '"use strict"; var [yield] = [];', '|')]
    [TestCase('LiteralAsBindingTarget', 'var [1] = [];', '|')]
    [TestCase('MemberAsBindingTarget', 'var [a.b] = [];', '|')]
    [TestCase('CallAsBindingTarget', 'var {a: f()} = {};', '|')]
    [TestCase('DuplicateParameter', 'function f([a], a) {}', '|')]
    [TestCase('DuplicateInPatternParameter', 'function f([a, a]) {}', '|')]
    [TestCase('DuplicateAcrossPatternParameters', 'function f([a], {a}) {}', '|')]
    [TestCase('DuplicateWithRestParameter', 'function f([a], ...a) {}', '|')]
    [TestCase('DuplicateArrowParameter', '([a], a) => 1', '|')]
    [TestCase('UseStrictWithPatternParameter', 'function f([a]) { "use strict"; }', '|')]
    [TestCase('LexicalConflictWithPatternParameter', 'function f([a]) { let a; }', '|')]
    [TestCase('LexicalConflictWithObjectParameter', 'function f({a}) { const a = 1; }', '|')]
    [TestCase('LexicalConflictWithRestPatternParameter', 'function f(...[a]) { let a; }', '|')]
    [TestCase('StrictEvalInPatternParameter', '"use strict"; function f([eval]) {}', '|')]
    [TestCase('RestParameterWithInitializer', 'function f(...[a] = []) {}', '|')]
    [TestCase('RestParameterNotLast', 'function f(...[a], b) {}', '|')]
    [TestCase('SetterWithTwoPatterns', '({ set s([a], [b]) {} })', '|')]
    [TestCase('CatchDuplicate', 'try {} catch ([a, a]) {}', '|')]
    [TestCase('CatchLexicalConflict', 'try {} catch ([a]) { let a; }', '|')]
    [TestCase('CatchVarConflict', 'try {} catch ([a]) { var a; }', '|')]
    [TestCase('CatchObjectVarConflict', 'try {} catch ({a}) { var a; }', '|')]
    [TestCase('CatchWithInitializer', 'try {} catch ([a] = []) {}', '|')]
    [TestCase('ForInInitializer', 'for (let [a] = [] in {}) {}', '|')]
    [TestCase('ForInVarInitializer', 'for (var [a] = [] in {}) {}', '|')]
    [TestCase('ForInDuplicate', 'for (let [a, a] in {}) {}', '|')]
    [TestCase('ForInLetNotLast', 'for (let [...a, b] in {}) {}', '|')]
    procedure Source_IsSyntaxError(const Source: string);

    [Test]
    [TestCase('NumberLiteralTarget', '[1] = [];', '|')]
    [TestCase('CallTarget', '[f()] = [];', '|')]
    [TestCase('BinaryTarget', '[a + b] = [];', '|')]
    [TestCase('ParenthesizedPatternTarget', '[([a])] = [];', '|')]
    [TestCase('ParenthesizedPatternAsWholeTarget', '([a]) = [];', '|')]
    [TestCase('ParenthesizedObjectAsWholeTarget', '({a}) = {};', '|')]
    [TestCase('ParenthesizedNestedObject', '({a: ({b})} = {});', '|')]
    [TestCase('ParenthesizedAssignmentInElement', '[(a = 1)] = [];', '|')]
    [TestCase('RestNotLast', '[...a, b] = [];', '|')]
    [TestCase('RestTrailingComma', '[...a,] = [];', '|')]
    [TestCase('RestWithInitializer', '[...a = []] = [];', '|')]
    [TestCase('ObjectMethodTarget', '({m() {}} = {});', '|')]
    [TestCase('ObjectGetterTarget', '({get a() {}} = {});', '|')]
    [TestCase('ObjectLiteralValueTarget', '({a: 1} = {});', '|')]
    [TestCase('ObjectCallTarget', '({a: f()} = {});', '|')]
    [TestCase('CoverInitializerInExpression', '({a = 1});', '|')]
    [TestCase('CoverInitializerInArgument', 'f({a = 1});', '|')]
    [TestCase('CoverInitializerInArray', '[{a = 1}];', '|')]
    [TestCase('CoverInitializerOnRightHandSide', 'x = {a = 1};', '|')]
    [TestCase('CoverInitializerInMemberObject', '[{a = 1}.b] = [];', '|')]
    [TestCase('CoverInitializerInConditional', 'x ? {a = 1} : 2;', '|')]
    [TestCase('CoverInitializerInPlainFor', 'for ({a = 1};;) {}', '|')]
    [TestCase('CompoundAssignmentToPattern', '[a] += [];', '|')]
    [TestCase('ObjectRestTrailingComma', '({...a,} = {});', '|')]
    [TestCase('ObjectRestIsObjectPattern', '({...{a}} = {});', '|')]
    [TestCase('ObjectRestIsArrayPattern', '({...[a]} = {});', '|')]
    [TestCase('ObjectRestNotLast', '({...a, b} = {});', '|')]
    [TestCase('ObjectRestWithInitializer', '({...a = 1} = {});', '|')]
    [TestCase('DuplicatePrototypeKeyInLiteral', '({__proto__: 1, __proto__: 2});', '|')]
    [TestCase('DuplicatePrototypeKeyInArgument', 'f({__proto__: 1, __proto__: 2});', '|')]
    [TestCase('StrictEvalTarget', '"use strict"; [eval] = [];', '|')]
    [TestCase('StrictArgumentsShorthand', '"use strict"; ({arguments} = {});', '|')]
    [TestCase('StrictEvalShorthandDefault', '"use strict"; ({eval = 1} = {});', '|')]
    [TestCase('ForInParenthesized', 'for (([a]) in {}) {}', '|')]
    [TestCase('ForInInvalidTarget', 'for ([1] in {}) {}', '|')]
    [TestCase('ForInRestNotLast', 'for ([...a, b] in {}) {}', '|')]
    procedure Source_IsSyntaxErrorInAssignment(const Source: string);

    [Test]
    [TestCase('Array', '[a] = [];', '|')]
    [TestCase('ObjectInParentheses', '({a} = {});', '|')]
    [TestCase('NestedDefault', '[[a] = [], {b} = {}] = [];', '|')]
    [TestCase('ObjectDefaultForShorthand', '({a = 1} = {});', '|')]
    [TestCase('NestedObjectDefaultForShorthand', '[{a = 1}] = [{}];', '|')]
    [TestCase('NestedObjectPropertyDefault', '({a: {b = 1}} = {a: {}});', '|')]
    [TestCase('ParenthesizedIdentifierTarget', '[(a)] = [];', '|')]
    [TestCase('ParenthesizedMemberTarget', 'var a = {}; [(a.b)] = [];', '|')]
    [TestCase('Holes', '[, , a, ,] = [];', '|')]
    [TestCase('GetAsShorthandDefault', '({get = 1} = {});', '|')]
    [TestCase('SetAsShorthandDefault', '({set = 1} = {});', '|')]
    [TestCase('GetAsShorthand', '({get} = {});', '|')]
    [TestCase('RestMember', 'var a = {}; [...a.b] = [];', '|')]
    [TestCase('CoverInitializerInForIn', 'for ({a = 1} in {}) {}', '|')]
    [TestCase('ForInVarPattern', 'for (var [a] in {}) {}', '|')]
    [TestCase('ForInLetPattern', 'for (let {a} in {}) {}', '|')]
    [TestCase('ArrowWithPatternsAndDefaults', '({a = 1}, [b] = [], ...[c]) => 1;', '|')]
    [TestCase('ArrowAfterNestedPatternParameter', '([[a]], {b: [c]}) => 1;', '|')]
    [TestCase('ParenthesizedExpressionNotArrow', '([1, 2]);', '|')]
    [TestCase('ParenthesizedObjectNotArrow', '({a: 1}).a;', '|')]
    [TestCase('ParenthesizedSequenceWithArray', '(1, [2]);', '|')]
    [TestCase('CatchPattern', 'try {} catch ([a, {b}]) {}', '|')]
    [TestCase('CatchBodyVarWithOtherName', 'try {} catch ([a]) { var b; }', '|')]
    [TestCase('CatchSimpleVarSameName', 'try {} catch (a) { var a; }', '|')]
    [TestCase('ParameterShadowedByFunctionInBody', 'function f([a]) { function a() {} }', '|')]
    [TestCase('ParameterShadowedByVarInBody', 'function f([a]) { var a; }', '|')]
    [TestCase('LexicalFromOtherBlock', 'function f([a]) { { let a; } }', '|')]
    [TestCase('LetPatternDeclaration', 'let [a] = [], {b} = {};', '|')]
    procedure Source_IsAccepted(const Source: string);

    [Test]
    procedure ObjectLiteral_StillAcceptsShorthandAndAccessors;

    [Test]
    procedure Hoisting_VarPatternNames_AreDeclaredAtTheTop;

    [Test]
    procedure Hoisting_VarPatternNames_InNestedBlocksAreFunctionScoped;
  end;

implementation

procedure TDestructuringTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDestructuringTests.TearDown;
begin
  FEngine.Free;
end;

function TDestructuringTests.ErrorNameOf(const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  FEngine.Execute(Wrapper);

  Result := FEngine.Evaluate('caught').AsString;
end;

procedure TDestructuringTests.ArrayPattern_Var_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.ObjectPattern_Var_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.ObjectRest_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Lexical_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Assignment_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Assignment_TargetIsResolvedBeforeValueIsRead;
begin
  const Script = 'var log = ""; var o = { get a() { log += "get;"; return 1; } }; ' +
                 'function target() { log += "target;"; return {}; } ' +
                 '({a: target().x} = o); log';

  Assert.AreEqual('target;get;', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Assignment_ElementsAreEvaluatedLeftToRight;
begin
  const Script = 'var log = ""; function t(n) { log += n; return {}; } ' +
                 '[t(1).a, t(2).b, t(3).c] = [1, 2, 3]; log';

  Assert.AreEqual('123', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Assignment_ToConstant_IsTypeError;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('const a = 1; [a] = [2];'));
end;

procedure TDestructuringTests.Assignment_ToUndeclaredInStrictMode_IsReferenceError;
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf('"use strict"; [undeclaredTarget] = [1];'));
end;

procedure TDestructuringTests.Assignment_ToUndeclaredInSloppyMode_CreatesGlobal;
begin
  FEngine.Execute('[createdByPattern] = [3];');

  Assert.AreEqual('3', FEngine.Evaluate('createdByPattern').ToString);
end;

procedure TDestructuringTests.Parameter_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Length_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Catch_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.ForIn_Result(const Source: string; const Expected: string);
begin
  const Actual = FEngine.Evaluate(Source);

  Assert.AreEqual(Expected, Actual.ToString);
end;

procedure TDestructuringTests.Pattern_RaisesTypeError(const Source: string);
begin
  Assert.AreEqual('TypeError', ErrorNameOf(Source));
end;

procedure TDestructuringTests.Pattern_RaisesReferenceError(const Source: string);
begin
  Assert.AreEqual('ReferenceError', ErrorNameOf(Source));
end;

procedure TDestructuringTests.Const_Pattern_AssignmentIsTypeError;
begin
  Assert.AreEqual('TypeError', ErrorNameOf('const [a] = [1]; a = 2;'));
end;

procedure TDestructuringTests.Rest_Element_CopiesRemainingElementsAtThatPoint;
begin
  const Script = 'var a = [1, 2, 3]; var [x, ...r] = a; a.push(4); r.join()';

  Assert.AreEqual('2,3', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Array_ElementsAreReadLazily;
begin
  const Script = 'var a = [1, undefined, 3]; var [x, y = (a[2] = 9), z] = a; x + "," + y + "," + z';

  Assert.AreEqual('1,9,9', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Default_IsEvaluatedOnlyWhenNeeded;
begin
  const Script = 'var n = 0; function d() { n++; return 1; } var [a = d(), b = d()] = [5]; n';

  Assert.AreEqual('1', FEngine.Evaluate(Script).ToString);
end;

procedure TDestructuringTests.Default_IsEvaluatedInOrder;
begin
  const Script = 'var log = ""; function d(n) { log += n; return n; } ' +
                 'var {a = d(1), b = d(2), c: [e = d(3)] = []} = {}; log';

  Assert.AreEqual('123', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.ComputedKey_IsEvaluatedBeforeTarget;
begin
  const Script = 'var log = ""; function k() { log += "k;"; return "a"; } ' +
                 'function t() { log += "t;"; return {}; } ' +
                 '({[k()]: t().x} = {a: 1}); log';

  Assert.AreEqual('k;t;', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Statement_AtBlockStart_IsNotAnObjectPattern;
begin
  const Script = 'var a = 1; { a } a';

  Assert.AreEqual('1', FEngine.Evaluate(Script).ToString);
end;

procedure TDestructuringTests.Source_IsSyntaxError(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TDestructuringTests.Source_IsSyntaxErrorInAssignment(const Source: string);
begin
  Assert.AreEqual('SyntaxError', ErrorNameOf(Source));
end;

procedure TDestructuringTests.Source_IsAccepted(const Source: string);
begin
  Assert.AreEqual('', ErrorNameOf(Source));
end;

procedure TDestructuringTests.ObjectLiteral_StillAcceptsShorthandAndAccessors;
begin
  const Script = 'var a = 1, get = 2, set = 3; var o = {a, get, set, get g() { return 4; }, set s(v) {}, m() {}}; ' +
                 'o.a + o.get + o.set + o.g';

  Assert.AreEqual('10', FEngine.Evaluate(Script).ToString);
end;

procedure TDestructuringTests.Hoisting_VarPatternNames_AreDeclaredAtTheTop;
begin
  const Script = 'var before = typeof a + typeof b; var [a, {b}] = [1, {b: 2}]; before + "," + a + b';

  Assert.AreEqual('undefinedundefined,12', FEngine.Evaluate(Script).AsString);
end;

procedure TDestructuringTests.Hoisting_VarPatternNames_InNestedBlocksAreFunctionScoped;
begin
  const Script = 'function f() { if (true) { var [a] = [3]; } return a; } f()';

  Assert.AreEqual('3', FEngine.Evaluate(Script).ToString);
end;

end.
