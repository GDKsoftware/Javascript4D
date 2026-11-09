unit JS4D.Tests.Operators;

{$SCOPEDENUMS ON}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TOperatorsTests = class
  private
    FEngine: TJSEngine;

    function RunScript(const Script: string): string;
    function RunStrictScript(const Script: string): string;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    [TestCase('Unsigned shift of negative', 'result = -1 >>> 0#4294967295', '#')]
    [TestCase('Signed right shift of negative', 'result = -1 >> 1#-1', '#')]
    [TestCase('Signed right shift by 16', 'result = -1 >> 16#-1', '#')]
    [TestCase('Left shift into sign bit', 'result = 1 << 31#-2147483648', '#')]
    [TestCase('Left shift overflow', 'result = 2147483647 << 1#-2', '#')]
    [TestCase('Left shift wraps operand', 'result = -2147483649 << 0#2147483647', '#')]
    [TestCase('Shift count is masked', 'result = 1 << 32#1', '#')]
    [TestCase('Unsigned shift count is masked', 'result = -1 >>> 33#2147483647', '#')]
    [TestCase('Bitwise or wraps 2 pow 32', 'result = 4294967296 | 0#0', '#')]
    [TestCase('Bitwise or of NaN', 'result = NaN | 1#1', '#')]
    [TestCase('Bitwise or of string', 'result = "x" | 1#1', '#')]
    [TestCase('Bitwise and of fraction', 'result = 5.9 & 3#1', '#')]
    [TestCase('Bitwise xor of infinity', 'result = Infinity ^ 1#1', '#')]
    [TestCase('Bitwise not of NaN', 'result = ~"x"#-1', '#')]
    [TestCase('Bitwise not of large number', 'result = ~4294967295#0', '#')]
    procedure BinaryOperator_OnNumbers_UsesInt32Semantics(const Script: string; const Expected: string);

    [Test]
    [TestCase('Add wrapper and number', 'result = new String("1") + 1#11', '#')]
    [TestCase('Add two wrappers', 'result = new String("1") + new String("1")#11', '#')]
    [TestCase('Add wrapper and undefined', 'result = new String("1") + undefined#1undefined', '#')]
    [TestCase('Add boolean and wrapper', 'result = true + new String("1")#true1', '#')]
    [TestCase('Add object with valueOf', 'result = ({valueOf: function() { return 2; }}) + 3#5', '#')]
    [TestCase('Add object with string valueOf', 'result = ({valueOf: function() { return "a"; }}) + 3#a3', '#')]
    [TestCase('Add date uses string hint', 'result = typeof (new Date(0) + 1)#string', '#')]
    [TestCase('Subtract object with valueOf', 'result = ({valueOf: function() { return 5; }}) - 2#3', '#')]
    [TestCase('Multiply object with valueOf', 'result = ({valueOf: function() { return 5; }}) * 2#10', '#')]
    [TestCase('Divide by object with valueOf', 'result = 10 / ({valueOf: function() { return 4; }})#2.5', '#')]
    [TestCase('Modulo object with valueOf', 'result = ({valueOf: function() { return 5; }}) % 3#2', '#')]
    [TestCase('Shift object with valueOf', 'result = ({valueOf: function() { return 1; }}) << 3#8', '#')]
    [TestCase('Bitwise or object with valueOf', 'result = ({valueOf: function() { return 6; }}) | 1#7', '#')]
    [TestCase('Unary plus object with valueOf', 'result = +({valueOf: function() { return 7; }})#7', '#')]
    [TestCase('Unary minus object with valueOf', 'result = -({valueOf: function() { return 7; }})#-7', '#')]
    [TestCase('Bitwise not object with valueOf', 'result = ~({valueOf: function() { return 7; }})#-8', '#')]
    [TestCase('Add native function', 'result = typeof (eval + 1)#string', '#')]
    [TestCase('Native function inherits Function.prototype',
      'result = Object.getPrototypeOf(parseInt) === Function.prototype#true', '#')]
    [TestCase('Unary plus array', 'result = +[5]#5', '#')]
    [TestCase('Unary plus object without valueOf result', 'result = isNaN(+{})#true', '#')]
    procedure BinaryOperator_OnObjects_ConvertsOperandsToPrimitives(const Script: string; const Expected: string);

    [Test]
    [TestCase('Less than wrapper', 'result = new Number(1) < 2#true', '#')]
    [TestCase('Greater than object', 'result = ({valueOf: function() { return 3; }}) > 2#true', '#')]
    [TestCase('Less than or equal strings in objects', 'result = new String("a") <= new String("b")#true', '#')]
    [TestCase('Greater than or equal object', 'result = ({valueOf: function() { return 1; }}) >= 2#false', '#')]
    [TestCase('Equals wrapper and primitive', 'result = new String("a") == "a"#true', '#')]
    [TestCase('Equals object and boolean', 'result = ({valueOf: function() { return 1; }}) == true#true', '#')]
    [TestCase('Does not equal boolean and wrapper', 'result = true != new Boolean(true)#false', '#')]
    [TestCase('Equals number and numeric string', 'result = 255 == "255"#true', '#')]
    [TestCase('Two objects compare by identity', 'result = new String("a") == new String("a")#false', '#')]
    [TestCase('Null equals only undefined', 'result = (null == 0)#false', '#')]
    procedure Comparison_OnObjects_ConvertsOperandsToPrimitives(const Script: string; const Expected: string);

    [Test]
    [TestCase('Bitwise or on identifier', 'var x = 5; x |= 2; result = x#7', '#')]
    [TestCase('Bitwise and on identifier', 'var x = 7; x &= 2; result = x#2', '#')]
    [TestCase('Bitwise xor on identifier', 'var x = 7; x ^= 2; result = x#5', '#')]
    [TestCase('Left shift on identifier', 'var x = 1; x <<= 31; result = x#-2147483648', '#')]
    [TestCase('Right shift on identifier', 'var x = -8; x >>= 1; result = x#-4', '#')]
    [TestCase('Unsigned shift on identifier', 'var x = -1; x >>>= 28; result = x#15', '#')]
    [TestCase('Bitwise or on member', 'var o = {x: 5}; o.x |= 2; result = o.x#7', '#')]
    [TestCase('Bitwise xor on member', 'var o = {x: 7}; o.x ^= 2; result = o.x#5', '#')]
    [TestCase('Bitwise and on computed member', 'var o = {x: 7}; o["x"] &= 2; result = o.x#2', '#')]
    [TestCase('Left shift on member', 'var o = {x: 1}; o.x <<= 4; result = o.x#16', '#')]
    [TestCase('Right shift on member', 'var o = {x: -16}; o.x >>= 2; result = o.x#-4', '#')]
    [TestCase('Unsigned shift on member', 'var o = {x: -1}; o.x >>>= 31; result = o.x#1', '#')]
    [TestCase('Bitwise or on array element', 'var a = [4]; a[0] |= 1; result = a[0]#5', '#')]
    [TestCase('Bitwise or of string target', 'var x = "x"; x |= 1; result = x#1', '#')]
    [TestCase('Add wrapper to boolean target', 'var x = true; x += new String("1"); result = x#true1', '#')]
    [TestCase('Add assigns result of operator', 'var o = {x: 1}; result = (o.x += 2)#3', '#')]
    [TestCase('Subtract object operand', 'var x = 5; x -= {valueOf: function() { return 2; }}; result = x#3', '#')]
    procedure CompoundAssignment_AppliesOperator(const Script: string; const Expected: string);

    [Test]
    [TestCase('Identifier reads before right side', 'var x = 1; x += (x = 2); result = x#3', '#')]
    [TestCase('Identifier bitwise reads before right side', 'var x = 4; x |= (x = 1); result = x#5', '#')]
    [TestCase('Member reads before right side', 'var o = {x: 1}; o.x += (o.x = 2); result = o.x#3', '#')]
    [TestCase('Binary reads left operand first', 'var x = -4; result = x >> (x = 1)#-2', '#')]
    [TestCase('Simple assignment evaluates base first', 'var o = {}; var p = o; var r; (p).x = (p = null, 1); result = o.x#1', '#')]
    [TestCase('Property expression runs before right side',
      'var log = ""; var o = {}; o[(log += "p", "k")] = (log += "r", 1); result = log#pr', '#')]
    [TestCase('Property expression runs once in compound',
      'var n = 0; var o = {k: 1}; o[(n++, "k")] += 1; result = n + ":" + o.k#1:2', '#')]
    [TestCase('Key conversion happens once in compound',
      'var n = 0; var key = {toString: function() { n++; return "p"; }}; var o = {p: 2}; o[key] += 3; result = n + ":" + o.p#1:5', '#')]
    [TestCase('Key conversion happens once in update',
      'var n = 0; var key = {toString: function() { n++; return "p"; }}; var o = {p: 2}; o[key]++; result = n + ":" + o.p#1:3', '#')]
    procedure Assignment_EvaluatesOperandsInSpecOrder(const Script: string; const Expected: string);

    [Test]
    [TestCase('Compound on null base evaluates property first',
      'var log = ""; try { null[(log += "p", "k")] ^= (log += "r", 1); } catch (e) { log += e.name; } result = log#pTypeError', '#')]
    [TestCase('Compound on undefined base skips key conversion',
      'var log = ""; var key = {toString: function() { log += "k"; return "k"; }}; try { undefined[key] += (log += "r", 1); } catch (e) { log += e.name; } result = log#TypeError', '#')]
    [TestCase('Simple assignment on null base evaluates right side first',
      'var log = ""; try { null[(log += "p", "k")] = (log += "r", 1); } catch (e) { log += e.name; } result = log#prTypeError', '#')]
    procedure Assignment_ToNullBase_FailsAtTheSpecifiedStep(const Script: string; const Expected: string);

    [Test]
    [TestCase('Prefix increment on object', 'var o = {valueOf: function() { return 1; }}; result = ++o#2', '#')]
    [TestCase('Postfix increment on object returns number', 'var o = {valueOf: function() { return 1; }}; result = typeof (o++)#number', '#')]
    [TestCase('Postfix increment on string', 'var s = "5"; var old = s++; result = old + ":" + s#5:6', '#')]
    [TestCase('Postfix decrement on wrapper', 'var w = new Number(3); w--; result = w#2', '#')]
    [TestCase('Prefix decrement on member of wrapper', 'var o = {w: new String("4")}; result = --o.w#3', '#')]
    procedure UpdateExpression_ConvertsOperandToNumber(const Script: string; const Expected: string);

    [Test]
    [TestCase('Non writable property', 'var o = {}; Object.defineProperty(o, "p", {value: 1}); o.p = 2', '#')]
    [TestCase('Non writable compound', 'var o = {}; Object.defineProperty(o, "p", {value: 1}); o.p *= 2', '#')]
    [TestCase('Non writable update', 'var o = {}; Object.defineProperty(o, "p", {value: 1}); o.p++', '#')]
    [TestCase('Getter without setter', 'var o = {get p() { return 1; }}; o.p = 2', '#')]
    [TestCase('Getter without setter compound', 'var o = {get p() { return 1; }}; o.p += 2', '#')]
    [TestCase('Inherited non writable',
      'var proto = {}; Object.defineProperty(proto, "p", {value: 1}); var o = Object.create(proto); o.p = 2', '#')]
    [TestCase('Non extensible object', 'var o = Object.preventExtensions({}); o.p = 2', '#')]
    [TestCase('Frozen object', 'var o = Object.freeze({p: 1}); o.p = 2', '#')]
    [TestCase('Frozen array append', 'var a = Object.freeze([1]); a[1] = 2', '#')]
    [TestCase('Primitive base', 'var s = "abc"; s.p = 1', '#')]
    procedure StrictMode_FailedPut_ThrowsTypeError(const Script: string);

    [Test]
    [TestCase('Non writable property', 'var o = {}; Object.defineProperty(o, "p", {value: 1}); o.p = 2; result = o.p#1', '#')]
    [TestCase('Getter without setter', 'var o = {get p() { return 1; }}; o.p = 2; result = o.p#1', '#')]
    [TestCase('Non extensible object', 'var o = Object.preventExtensions({}); o.p = 2; result = typeof o.p#undefined', '#')]
    [TestCase('Primitive base', 'var s = "abc"; s.p = 1; result = typeof s.p#undefined', '#')]
    [TestCase('Compound on non writable', 'var o = {}; Object.defineProperty(o, "p", {value: 1}); o.p += 5; result = o.p#1', '#')]
    procedure SloppyMode_FailedPut_IsIgnored(const Script: string; const Expected: string);

    [Test]
    [TestCase('Writable property', 'var o = {p: 1}; o.p = 2; result = o.p#2', '#')]
    [TestCase('New property', 'var o = {}; o.p = 2; result = o.p#2', '#')]
    [TestCase('Setter', 'var seen; var o = {set p(v) { seen = v; }}; o.p = 2; result = seen#2', '#')]
    [TestCase('Inherited writable', 'var o = Object.create({p: 1}); o.p = 2; result = o.p#2', '#')]
    [TestCase('Array element', 'var a = [1]; a[0] = 2; a[1] = 3; result = a.join()#2,3', '#')]
    procedure StrictMode_SuccessfulPut_StillWorks(const Script: string; const Expected: string);
  end;

implementation

procedure TOperatorsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TOperatorsTests.TearDown;
begin
  FEngine.Free;
end;

function TOperatorsTests.RunScript(const Script: string): string;
begin
  FEngine.Execute(Format('var result; %s', [Script]));

  Result := FEngine.Evaluate('String(result)').ToString;
end;

function TOperatorsTests.RunStrictScript(const Script: string): string;
begin
  FEngine.Execute(Format('"use strict"; var result; %s', [Script]));

  Result := FEngine.Evaluate('String(result)').ToString;
end;

procedure TOperatorsTests.BinaryOperator_OnNumbers_UsesInt32Semantics(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.BinaryOperator_OnObjects_ConvertsOperandsToPrimitives(const Script: string;
                                                                                const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.Comparison_OnObjects_ConvertsOperandsToPrimitives(const Script: string;
                                                                            const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.CompoundAssignment_AppliesOperator(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.Assignment_EvaluatesOperandsInSpecOrder(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.Assignment_ToNullBase_FailsAtTheSpecifiedStep(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.UpdateExpression_ConvertsOperandToNumber(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.StrictMode_FailedPut_ThrowsTypeError(const Script: string);
begin
  const Guarded = Format('var caught = ""; try { %s } catch (e) { caught = e.name; } result = caught;', [Script]);

  Assert.AreEqual('TypeError', RunStrictScript(Guarded));
end;

procedure TOperatorsTests.SloppyMode_FailedPut_IsIgnored(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunScript(Script));
end;

procedure TOperatorsTests.StrictMode_SuccessfulPut_StillWorks(const Script: string; const Expected: string);
begin
  Assert.AreEqual(Expected, RunStrictScript(Script));
end;

end.
