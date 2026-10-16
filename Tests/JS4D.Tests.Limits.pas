unit JS4D.Tests.Limits;

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
  TCallDepthLimitTests = class
  private
    FEngine: TJSEngine;

    procedure AssertRecursionStopped(const Script: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure MaxCallDepth_ByDefault_IsOneHundred;

    [Test]
    procedure Execute_UnboundedRecursion_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_UnboundedRecursionTwice_RaisesBothTimes;

    [Test]
    procedure Execute_AfterCallDepthExceeded_EngineRunsNormalScript;

    [Test]
    procedure Execute_ScriptCatchBlock_CannotSwallowCallDepthExceeded;

    [Test]
    procedure Execute_RecursionWithinConfiguredLimit_Completes;

    [Test]
    procedure Execute_RecursionBeyondConfiguredLimit_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_NestedCallsFiftyDeep_StillWork;

    [Test]
    procedure Execute_RecursionThroughMapCallback_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_RecursionThroughSortComparator_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_RecursionThroughNew_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_RecursionThroughCall_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_RecursionThroughApply_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_RecursionThroughBind_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_ArrayNestedPastCallDepth_RaisesCallDepthExceeded;
  end;

  [TestFixture]
  TAllocationLimitTests = class
  private
    FEngine: TJSEngine;

    procedure AssertExceedsLimit(const Script: string; const Message: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Limits_ByDefault_AreSixteenMiCharsAndOneMiElements;

    [Test]
    procedure Execute_DoublingStringInLoop_RaisesAllocationLimitWithinFewSteps;

    [Test]
    procedure Execute_RepeatOfOneBillion_RaisesAllocationLimit;

    [Test]
    procedure Execute_LargeButLegalScript_StillWorks;

    [Test]
    procedure Execute_StringExactlyAtLimit_IsAllowed;

    [Test]
    procedure Execute_ConcatenationOverLimit_Raises;

    [Test]
    procedure Execute_CompoundAssignmentOverLimit_Raises;

    [Test]
    procedure Execute_MemberCompoundAssignmentOverLimit_Raises;

    [Test]
    procedure Execute_RepeatOverLimit_Raises;

    [Test]
    procedure Execute_PadStartOverLimit_Raises;

    [Test]
    procedure Execute_PadEndOverLimit_Raises;

    [Test]
    procedure Execute_JoinOverLimit_Raises;

    [Test]
    procedure Execute_StringConcatMethodOverLimit_Raises;

    [Test]
    procedure Execute_ReplaceOverLimit_Raises;

    [Test]
    procedure Execute_RegExpReplaceOverLimit_Raises;

    [Test]
    procedure Execute_PushOverLimit_Raises;

    [Test]
    procedure Execute_ArrayConcatOverLimit_Raises;

    [Test]
    procedure Execute_UnshiftOverLimit_Raises;

    [Test]
    procedure Execute_SpliceInsertOverLimit_Raises;

    [Test]
    procedure Execute_FlatOverLimit_Raises;

    [Test]
    procedure Execute_SplitOverLimit_Raises;

    [Test]
    procedure Execute_ArrayFromLengthOverLimit_Raises;

    [Test]
    procedure Execute_ArrayLiteralOverLimit_Raises;

    [Test]
    procedure Execute_IndexAssignmentFarBeyondEnd_Raises;

    [Test]
    procedure Execute_ArrayExactlyAtLimit_IsAllowed;

    [Test]
    procedure Execute_ZeroLimits_MeanUnlimited;

    [Test]
    procedure Execute_AfterAllocationLimitExceeded_EngineStaysUsable;

    [Test]
    procedure Execute_StringOfBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_BigArrayPlusEmptyString_RaisesAllocationLimit;

    [Test]
    procedure Execute_EmptyStringPlusBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_ArrayToStringOfNestedBigArrays_RaisesAllocationLimit;

    [Test]
    procedure Execute_JoinOfBigNestedArrays_RaisesAllocationLimit;

    [Test]
    procedure Execute_JsonStringifyOfBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_BigArrayAsPropertyKey_RaisesAllocationLimit;

    [Test]
    procedure Execute_CircularArrayToString_YieldsEmptyElement;

    [Test]
    procedure Execute_MutuallyCircularArrays_StopAtTheRepeat;

    [Test]
    procedure Execute_CircularJsonStringify_RaisesTypeError;

    [Test]
    procedure Execute_CircularArrayJsonStringify_RaisesTypeError;

    [Test]
    procedure Execute_PadStartLargePadding_ProducesRepeatedPad;

    [Test]
    procedure Execute_PadEndLargePadding_ProducesRepeatedPad;

    [Test]
    procedure Execute_CompoundAssignmentWithBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_ConsoleLogOfBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_StringConcatWithBigArray_RaisesAllocationLimit;

    [Test]
    procedure Execute_ArrayConcatWithSeveralArrays_RaisesAllocationLimit;

    [Test]
    procedure Execute_JsonStringifyOfBigObject_RaisesAllocationLimit;

    [Test]
    procedure Execute_JsonStringifyOfManySmallNumbers_IsAllowed;

    [Test]
    procedure Execute_JsonStringifyJustWithinLimit_IsAllowed;

    [Test]
    procedure Execute_JsonStringifyJustOverLimit_RaisesAllocationLimit;

    [Test]
    procedure Execute_JsonStringifyNestedPastCallDepth_RaisesCallDepthExceeded;

    [Test]
    procedure Execute_JsonStringifyObjectsNestedPastCallDepth_RaisesCallDepthExceeded;
  end;

  [TestFixture]
  TDeepStructureTests = class
  private
    FEngine: TJSEngine;

    procedure AssertDeepArrayRejected(const Usage: string);

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure IndexOf_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure Includes_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure StartsWith_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure Search_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure ParseInt_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure DefaultSort_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure InOperator_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure HasOwnProperty_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure JsonParse_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure RegExpTest_WithDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure Throw_OfDeepArray_RaisesCallDepthExceeded;

    [Test]
    procedure Release_OfDeepObjectChain_DoesNotOverflowTheStack;

    [Test]
    procedure Release_OfDeepMixedChain_DoesNotOverflowTheStack;

    [Test]
    procedure Release_OfDeepObjectChainDroppedByAssignment_DoesNotOverflowTheStack;

    [Test]
    procedure Release_OfDeepObjectChainAfterCollection_DoesNotOverflowTheStack;
  end;

implementation

const
  EngineUsableMessage = 'The engine must be usable again after the limit stopped a script';
  ConfiguredLimitMessage = 'The exception must report the configured limit';
  MessageNamesLimitMessage = 'The message must name the limit';
  EndlessRecursionScript = 'function f(n) { return f(n + 1); } f(0);';
  CaughtRecursionScript = 'function f(n) { return f(n + 1); } try { f(0); } catch (e) { }';
  RecursionScriptFormat = 'function f(n) { if (n >= %d) { return n; } return f(n + 1); } f(0)';
  NestedCallDepth = 50;
  LegalRecursionDepth = 90;
  NormalScript = '40 + 2';
  NormalScriptResult = 42;
  DefaultCallDepth = 100;
  SmallCallDepth = 10;
  WithinSmallCallDepth = 5;
  BeyondSmallCallDepth = 20;
  DefaultStringLength = 16 * 1024 * 1024;
  DefaultArrayLength = 1024 * 1024;
  SmallStringLength = 100;
  SmallArrayLength = 10;
  SmallStringLengthText = '100';
  SmallArrayLengthText = '10';
  DoublingScript = 'var s = ''x''; while (true) { s += s; }';
  DoublingStepBudget = 1000;
  DoublingMaximumSteps = 200;
  RepeatBillionScript = '''x''.repeat(1000000000);';
  LegalScriptFormat =
    'var items = []; for (var i = 0; i < 10000; i++) { items.push(i); } ' +
    'function f(n) { if (n >= %d) { return n; } return f(n + 1); } ' +
    'var depthReached = f(0); var total = 0; for (var j = 0; j < items.length; j++) { total += items[j]; } ' +
    'items.length + total + depthReached';
  LegalScriptResult = 10000 + 49995000 + NestedCallDepth;
  HundredCharsScript = 'var s = ''x''.repeat(100); s.length';
  HundredOneCharsScript = 'var s = ''x''.repeat(100) + ''y'';';
  CompoundAssignmentScript = 'var s = ''x''.repeat(100); s += ''y'';';
  MemberCompoundAssignmentScript = 'var o = { s: ''x''.repeat(100) }; o.s += ''y'';';
  RepeatScript = '''ab''.repeat(51);';
  PadStartScript = '''x''.padStart(101, ''ab'');';
  PadEndScript = '''x''.padEnd(101, ''ab'');';
  JoinScript = 'var a = [''x''.repeat(60), ''x''.repeat(60)]; a.join('','');';
  StringConcatScript = '''x''.repeat(60).concat(''x''.repeat(41));';
  RegExpReplaceScript = '''x''.repeat(60).replace(/x/g, ''yy'');';
  ReplaceScript = '''x''.repeat(60).replace(''x'', ''y''.repeat(60));';
  PushScript = 'var a = []; for (var i = 0; i < 11; i++) { a.push(i); }';
  ArrayConcatScript = 'var a = [1, 2, 3, 4, 5, 6]; a.concat(a);';
  UnshiftScript = 'var a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; a.unshift(0);';
  SpliceScript = 'var a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]; a.splice(1, 0, 99);';
  FlatScript = 'var inner = [1, 2, 3, 4, 5, 6]; var outer = [inner, inner]; outer.flat();';
  SplitScript = '''x''.repeat(11).split('''');';
  ArrayFromScript = 'Array.from({ length: 1000000000 });';
  ArrayLiteralScript = 'var a = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];';
  IndexAssignmentScript = 'var a = []; a[1000000000] = 1;';
  TenElementsScript = 'var a = []; for (var i = 0; i < 10; i++) { a.push(i); } a.length';
  TenElements = 10;
  RecursionThroughMapScript = 'function f(n) { return [1].map(function(x) { return f(n + 1); }); } f(0);';
  RecursionThroughSortScript = 'function f(n) { return [2, 1].sort(function(a, b) { return f(n + 1); }); } f(0);';
  RecursionThroughNewScript = 'function F(n) { return new F(n + 1); } new F(0);';
  RecursionThroughCallScript = 'function f(n) { return f.call(null, n + 1); } f(0);';
  RecursionThroughApplyScript = 'function f(n) { return f.apply(null, [n + 1]); } f(0);';
  RecursionThroughBindScript = 'function f(n) { var g = f.bind(null, n + 1); return g(); } f(0);';
  NestedArrayScript = 'var a = []; for (var i = 0; i < 150; i++) { a = [a]; } a + '''';';
  BigPiecesPrefix = 'var s = ''x''.repeat(1000000); var a = []; for (var i = 0; i < 20; i++) { a.push(s); } ';
  StringOfBigArrayScript = BigPiecesPrefix + 'String(a);';
  BigArrayPlusScript = BigPiecesPrefix + 'a + '''';';
  EmptyPlusBigArrayScript = BigPiecesPrefix + ''''' + a;';
  NestedPiecesPrefix = 'var s = ''x''.repeat(1000000); var inner = []; for (var i = 0; i < 10; i++) { inner.push(s); } var outer = [inner, inner]; ';
  NestedBigArraysScript = NestedPiecesPrefix + 'outer + '''';';
  JoinNestedScript = NestedPiecesPrefix + 'outer.join('','');';
  JsonStringifyScript = BigPiecesPrefix + 'JSON.stringify(a);';
  BigKeyScript = BigPiecesPrefix + 'var o = {}; o[a] = 1;';
  CircularArrayScript = 'var a = []; a.push(a); var text = ''['' + a + '']''; a.pop(); text';
  CircularArrayResult = '[]';
  MutualCircularScript = 'var a = [1]; var b = [a]; a.push(b); var text = '''' + a; a.pop(); text';
  MutualCircularResult = '1,';
  CircularJsonScript = 'var o = {}; o.self = o; JSON.stringify(o);';
  CircularJsonCleanup = 'o.self = null;';
  CircularArrayJsonScript = 'var a = []; a.push(a); JSON.stringify(a);';
  CircularArrayJsonCleanup = 'a.pop();';
  LargePadScript = '''x''.padStart(100000, ''ab'')';
  LargePadEndScript = '''x''.padEnd(100000, ''ab'')';
  LargePadLength = 100000;
  PadStartBeginning = 'ababab';
  CompoundBigArrayScript = BigPiecesPrefix + 'var t = ''''; t += a;';
  ConsoleLogScript = BigPiecesPrefix + 'console.log(a);';
  StringConcatBigArrayScript = BigPiecesPrefix + '''x''.concat(a);';
  ArrayConcatSeveralScript = 'var a = [1, 2, 3, 4, 5, 6]; a.concat([7], [8], [9], [10, 11]);';
  JsonBigObjectScript = 'var s = ''x''.repeat(1000000); var o = {}; for (var i = 0; i < 20; i++) { o[''k'' + i] = s; } JSON.stringify(o);';
  JsonManyNumbersScript = 'var a = []; for (var i = 0; i < 700000; i++) a.push(i % 10); JSON.stringify(a).length';
  JsonManyNumbersMinimumLength = 1400001;
  JsonDigitsFormat = 'var a = []; for (var i = 0; i < %d; i++) { a.push(true); } JSON.stringify(a).length';
  JsonDigitsWithinLimit = 19;
  JsonDigitsWithinLimitLength = 96;
  JsonDigitsOverLimit = 20;
  JsonNestedArrayScript = 'var a = []; for (var i = 0; i < 150; i++) { a = [a]; } JSON.stringify(a);';
  JsonNestedObjectScript = 'var o = {}; for (var i = 0; i < 150; i++) { o = { x: o }; } JSON.stringify(o);';
  DeepArrayPrefix = 'var a = []; for (var i = 0; i < 200000; i++) a = [a]; ';
  DeepIndexOfScript = '''x''.indexOf(a);';
  DeepIncludesScript = '''x''.includes(a);';
  DeepStartsWithScript = '''x''.startsWith(a);';
  DeepSearchScript = '''x''.search(a);';
  DeepParseIntScript = 'parseInt(a);';
  DeepSortScript = '[a, a].sort();';
  DeepInScript = 'a in {};';
  DeepHasOwnPropertyScript = '({}).hasOwnProperty(a);';
  DeepJsonParseScript = 'JSON.parse(a);';
  DeepRegExpTestScript = 'var pattern = /x/; pattern.test(a);';
  DeepThrowScript = 'throw a;';
  DeepObjectChainScript = 'var a = {}; for (var i = 0; i < 200000; i++) a = { x: a };';
  DeepMixedChainScript = 'var a = {}; for (var i = 0; i < 200000; i++) a = (i % 2 === 0) ? { x: a } : [a];';
  DeepChainDropScript = DeepObjectChainScript + ' a = 0;';
  PadEndBeginning = 'xababab';
  UnlimitedScript = 'var s = ''x''.repeat(200); var a = []; for (var i = 0; i < 20; i++) { a.push(i); } s.length + a.length';
  UnlimitedScriptResult = 220;
  OneBillionElementsMessage = 'An array far beyond the element limit must be refused before it is allocated';

{ TCallDepthLimitTests }

procedure TCallDepthLimitTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TCallDepthLimitTests.TearDown;
begin
  FEngine.Free;
end;

procedure TCallDepthLimitTests.MaxCallDepth_ByDefault_IsOneHundred;
begin
  Assert.AreEqual(DefaultCallDepth, FEngine.MaxCallDepth, 'The default call depth limit must be 100');
end;

procedure TCallDepthLimitTests.Execute_UnboundedRecursion_RaisesCallDepthExceeded;
begin
  try
    FEngine.Execute(EndlessRecursionScript);
    Assert.Fail('Unbounded recursion must not run until the native stack overflows');
  except
    on E: EJSCallDepthExceeded do
    begin
      Assert.AreEqual(DefaultCallDepth, E.MaxCallDepth, 'The exception must report the limit it exceeded');
      const LimitText = IntToStr(DefaultCallDepth);

      Assert.Contains(E.Message, LimitText, MessageNamesLimitMessage);
    end;
  end;
end;

procedure TCallDepthLimitTests.Execute_UnboundedRecursionTwice_RaisesBothTimes;
begin
  for var Attempt := 1 to 2 do
  begin
    Assert.WillRaise(
      procedure
      begin
        FEngine.Execute(EndlessRecursionScript);
      end,
      EJSCallDepthExceeded,
      'Every run of unbounded recursion must end in the call depth exception');
  end;
end;

procedure TCallDepthLimitTests.Execute_AfterCallDepthExceeded_EngineRunsNormalScript;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(EndlessRecursionScript);
    end,
    EJSCallDepthExceeded);

  const Outcome = FEngine.Evaluate(NormalScript);

  Assert.AreEqual(Double(NormalScriptResult), Outcome.ToNumber, EngineUsableMessage);

  const LegalScript = Format(RecursionScriptFormat, [LegalRecursionDepth]);
  const Recursion = FEngine.Evaluate(LegalScript);

  Assert.AreEqual(Double(LegalRecursionDepth), Recursion.ToNumber, 'The depth counter must be unwound, so a legal recursion still fits');
end;

procedure TCallDepthLimitTests.Execute_ScriptCatchBlock_CannotSwallowCallDepthExceeded;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(CaughtRecursionScript);
    end,
    EJSCallDepthExceeded,
    'A catch block in the script must not be able to keep a runaway recursion alive');
end;

procedure TCallDepthLimitTests.Execute_RecursionWithinConfiguredLimit_Completes;
begin
  FEngine.MaxCallDepth := SmallCallDepth;

  const Script = Format(RecursionScriptFormat, [WithinSmallCallDepth]);
  const Outcome = FEngine.Evaluate(Script);

  Assert.AreEqual(Double(WithinSmallCallDepth), Outcome.ToNumber, 'A recursion inside the configured limit must complete');
end;

procedure TCallDepthLimitTests.Execute_RecursionBeyondConfiguredLimit_RaisesCallDepthExceeded;
begin
  FEngine.MaxCallDepth := SmallCallDepth;
  const Script = Format(RecursionScriptFormat, [BeyondSmallCallDepth]);

  try
    FEngine.Execute(Script);
    Assert.Fail('A recursion beyond the configured limit must be stopped');
  except
    on E: EJSCallDepthExceeded do
      Assert.AreEqual(SmallCallDepth, E.MaxCallDepth, ConfiguredLimitMessage);
  end;
end;

procedure TCallDepthLimitTests.Execute_NestedCallsFiftyDeep_StillWork;
begin
  const Script = Format(RecursionScriptFormat, [NestedCallDepth]);
  const Outcome = FEngine.Evaluate(Script);

  Assert.AreEqual(Double(NestedCallDepth), Outcome.ToNumber, 'Calls nested fifty deep must stay inside the default limit');
end;

procedure TCallDepthLimitTests.AssertRecursionStopped(const Script: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSCallDepthExceeded,
    'The runaway script must end in the call depth exception');

  const Outcome = FEngine.Evaluate(NormalScript);

  Assert.AreEqual(Double(NormalScriptResult), Outcome.ToNumber, EngineUsableMessage);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughMapCallback_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughMapScript);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughSortComparator_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughSortScript);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughNew_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughNewScript);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughCall_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughCallScript);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughApply_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughApplyScript);
end;

procedure TCallDepthLimitTests.Execute_RecursionThroughBind_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(RecursionThroughBindScript);
end;

procedure TCallDepthLimitTests.Execute_ArrayNestedPastCallDepth_RaisesCallDepthExceeded;
begin
  AssertRecursionStopped(NestedArrayScript);
end;

{ TAllocationLimitTests }

procedure TAllocationLimitTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TAllocationLimitTests.TearDown;
begin
  FEngine.Free;
end;

procedure TAllocationLimitTests.AssertExceedsLimit(const Script: string; const Message: string);
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSAllocationLimitExceeded,
    Message);
end;

procedure TAllocationLimitTests.Limits_ByDefault_AreSixteenMiCharsAndOneMiElements;
begin
  Assert.AreEqual(DefaultStringLength, FEngine.MaxStringLength, 'The default string limit must be 16 Mi chars');
  Assert.AreEqual(DefaultArrayLength, FEngine.MaxArrayLength, 'The default array limit must be 1 Mi elements');
end;

procedure TAllocationLimitTests.Execute_DoublingStringInLoop_RaisesAllocationLimitWithinFewSteps;
begin
  FEngine.StepBudget := DoublingStepBudget;

  try
    FEngine.Execute(DoublingScript);
    Assert.Fail('A string that doubles each step must hit the string limit');
  except
    on E: EJSAllocationLimitExceeded do
    begin
      Assert.AreEqual(DefaultStringLength, E.Limit, 'The exception must report the string limit');
      const Steps = FEngine.StepCount;
      const Failure = Format('The limit must stop the loop within %d steps, took %d', [DoublingMaximumSteps, Steps]);

      Assert.IsTrue(Steps < DoublingMaximumSteps, Failure);
    end;
  end;
end;

procedure TAllocationLimitTests.Execute_RepeatOfOneBillion_RaisesAllocationLimit;
begin
  AssertExceedsLimit(RepeatBillionScript, 'A repeat of a billion must be refused before it allocates');
end;

procedure TAllocationLimitTests.Execute_LargeButLegalScript_StillWorks;
begin
  const Script = Format(LegalScriptFormat, [NestedCallDepth]);
  const Outcome = FEngine.Evaluate(Script);

  Assert.AreEqual(Double(LegalScriptResult), Outcome.ToNumber, 'A large script inside the limits must behave as before');
end;

procedure TAllocationLimitTests.Execute_StringExactlyAtLimit_IsAllowed;
begin
  FEngine.MaxStringLength := SmallStringLength;

  const Outcome = FEngine.Evaluate(HundredCharsScript);

  Assert.AreEqual(Double(SmallStringLength), Outcome.ToNumber, 'A string of exactly the limit must be allowed');
end;

procedure TAllocationLimitTests.Execute_ConcatenationOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  try
    FEngine.Execute(HundredOneCharsScript);
    Assert.Fail('A concatenation past the limit must raise');
  except
    on E: EJSAllocationLimitExceeded do
    begin
      Assert.AreEqual(SmallStringLength, E.Limit, ConfiguredLimitMessage);
      Assert.Contains(E.Message, SmallStringLengthText, MessageNamesLimitMessage);
    end;
  end;
end;

procedure TAllocationLimitTests.Execute_CompoundAssignmentOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(CompoundAssignmentScript, 'A += past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_MemberCompoundAssignmentOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(MemberCompoundAssignmentScript, 'A += on a property past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_RepeatOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(RepeatScript, 'repeat past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_PadStartOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(PadStartScript, 'padStart past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_PadEndOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(PadEndScript, 'padEnd past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_JoinOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(JoinScript, 'join past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_StringConcatMethodOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(StringConcatScript, 'String concat past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_ReplaceOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(ReplaceScript, 'replace past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_RegExpReplaceOverLimit_Raises;
begin
  FEngine.MaxStringLength := SmallStringLength;

  AssertExceedsLimit(RegExpReplaceScript, 'A global regexp replace past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_PushOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  try
    FEngine.Execute(PushScript);
    Assert.Fail('A push past the limit must raise');
  except
    on E: EJSAllocationLimitExceeded do
    begin
      Assert.AreEqual(SmallArrayLength, E.Limit, ConfiguredLimitMessage);
      Assert.Contains(E.Message, SmallArrayLengthText, MessageNamesLimitMessage);
    end;
  end;
end;

procedure TAllocationLimitTests.Execute_ArrayConcatOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(ArrayConcatScript, 'concat past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_UnshiftOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(UnshiftScript, 'unshift past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_SpliceInsertOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(SpliceScript, 'splice that inserts past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_FlatOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(FlatScript, 'flat past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_SplitOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(SplitScript, 'split past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_ArrayFromLengthOverLimit_Raises;
begin
  AssertExceedsLimit(ArrayFromScript, OneBillionElementsMessage);
end;

procedure TAllocationLimitTests.Execute_ArrayLiteralOverLimit_Raises;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(ArrayLiteralScript, 'An array literal past the limit must raise');
end;

procedure TAllocationLimitTests.Execute_IndexAssignmentFarBeyondEnd_Raises;
begin
  AssertExceedsLimit(IndexAssignmentScript, OneBillionElementsMessage);
end;

procedure TAllocationLimitTests.Execute_ArrayExactlyAtLimit_IsAllowed;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  const Outcome = FEngine.Evaluate(TenElementsScript);

  Assert.AreEqual(Double(TenElements), Outcome.ToNumber, 'An array of exactly the limit must be allowed');
end;

procedure TAllocationLimitTests.Execute_ZeroLimits_MeanUnlimited;
begin
  FEngine.MaxStringLength := 0;
  FEngine.MaxArrayLength := 0;

  const Outcome = FEngine.Evaluate(UnlimitedScript);

  Assert.AreEqual(Double(UnlimitedScriptResult), Outcome.ToNumber, 'A limit of zero must switch the check off');
end;

procedure TAllocationLimitTests.Execute_StringOfBigArray_RaisesAllocationLimit;
begin
  AssertExceedsLimit(StringOfBigArrayScript, 'String(array) must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_BigArrayPlusEmptyString_RaisesAllocationLimit;
begin
  AssertExceedsLimit(BigArrayPlusScript, 'array + string must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_EmptyStringPlusBigArray_RaisesAllocationLimit;
begin
  AssertExceedsLimit(EmptyPlusBigArrayScript, 'string + array must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_ArrayToStringOfNestedBigArrays_RaisesAllocationLimit;
begin
  AssertExceedsLimit(NestedBigArraysScript, 'Converting nested arrays must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_JoinOfBigNestedArrays_RaisesAllocationLimit;
begin
  AssertExceedsLimit(JoinNestedScript, 'join over nested arrays must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyOfBigArray_RaisesAllocationLimit;
begin
  AssertExceedsLimit(JsonStringifyScript, 'JSON.stringify must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_BigArrayAsPropertyKey_RaisesAllocationLimit;
begin
  AssertExceedsLimit(BigKeyScript, 'Using a big array as a property key must stop at the string limit');
end;

procedure TAllocationLimitTests.Execute_CircularArrayToString_YieldsEmptyElement;
begin
  const Outcome = FEngine.Evaluate(CircularArrayScript);

  Assert.AreEqual(CircularArrayResult, Outcome.ToString, 'A cycle must convert to an empty element');
end;

procedure TAllocationLimitTests.Execute_MutuallyCircularArrays_StopAtTheRepeat;
begin
  const Outcome = FEngine.Evaluate(MutualCircularScript);

  Assert.AreEqual(MutualCircularResult, Outcome.ToString, 'The repeated array must convert to an empty element');
end;

procedure TAllocationLimitTests.Execute_CircularJsonStringify_RaisesTypeError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(CircularJsonScript);
    end,
    EJSTypeError,
    'JSON.stringify of a circular object must raise a TypeError');

  // The engine does not collect reference cycles, so the test breaks its own cycle.
  FEngine.Execute(CircularJsonCleanup);
end;

procedure TAllocationLimitTests.Execute_CircularArrayJsonStringify_RaisesTypeError;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(CircularArrayJsonScript);
    end,
    EJSTypeError,
    'JSON.stringify of a circular array must raise a TypeError');

  // The engine does not collect reference cycles, so the test breaks its own cycle.
  FEngine.Execute(CircularArrayJsonCleanup);
end;

procedure TAllocationLimitTests.Execute_PadStartLargePadding_ProducesRepeatedPad;
begin
  const Padded = FEngine.Evaluate(LargePadScript);
  const Outcome = Padded.ToString;

  Assert.AreEqual(LargePadLength, Length(Outcome), 'padStart must reach the requested length');
  Assert.IsTrue(Outcome.StartsWith(PadStartBeginning), 'padStart must repeat the pad string');
end;

procedure TAllocationLimitTests.Execute_PadEndLargePadding_ProducesRepeatedPad;
begin
  const Padded = FEngine.Evaluate(LargePadEndScript);
  const Outcome = Padded.ToString;

  Assert.AreEqual(LargePadLength, Length(Outcome), 'padEnd must reach the requested length');
  Assert.IsTrue(Outcome.StartsWith(PadEndBeginning), 'padEnd must repeat the pad string');
end;

procedure TAllocationLimitTests.Execute_CompoundAssignmentWithBigArray_RaisesAllocationLimit;
begin
  AssertExceedsLimit(CompoundBigArrayScript, 'string += array must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_ConsoleLogOfBigArray_RaisesAllocationLimit;
begin
  FEngine.OnConsoleOutput :=
    procedure(const Output: string)
    begin
    end;

  AssertExceedsLimit(ConsoleLogScript, 'console.log of a big array must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_StringConcatWithBigArray_RaisesAllocationLimit;
begin
  AssertExceedsLimit(StringConcatBigArrayScript, 'String concat with a big array must stop at the string limit');
end;

procedure TAllocationLimitTests.Execute_ArrayConcatWithSeveralArrays_RaisesAllocationLimit;
begin
  FEngine.MaxArrayLength := SmallArrayLength;

  AssertExceedsLimit(ArrayConcatSeveralScript, 'concat with several arrays must count all of them');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyOfBigObject_RaisesAllocationLimit;
begin
  AssertExceedsLimit(JsonBigObjectScript, 'JSON.stringify of an object must stop at the string limit while it builds');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyOfManySmallNumbers_IsAllowed;
begin
  const Outcome = FEngine.Evaluate(JsonManyNumbersScript);

  Assert.IsTrue(Outcome.ToNumber >= JsonManyNumbersMinimumLength, 'Every number needs at least one char plus a separator');
  Assert.IsTrue(Outcome.ToNumber < DefaultStringLength, 'The check must use the real text length, not a worst case');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyJustWithinLimit_IsAllowed;
begin
  FEngine.MaxStringLength := SmallStringLength;
  const Script = Format(JsonDigitsFormat, [JsonDigitsWithinLimit]);

  const Outcome = FEngine.Evaluate(Script);

  Assert.AreEqual(Double(JsonDigitsWithinLimitLength), Outcome.ToNumber, 'A JSON text inside the limit must be produced');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyJustOverLimit_RaisesAllocationLimit;
begin
  FEngine.MaxStringLength := SmallStringLength;
  const Script = Format(JsonDigitsFormat, [JsonDigitsOverLimit]);

  AssertExceedsLimit(Script, 'A JSON text just over the limit must raise');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyNestedPastCallDepth_RaisesCallDepthExceeded;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(JsonNestedArrayScript);
    end,
    EJSCallDepthExceeded,
    'JSON nesting beyond the call depth limit must raise');
end;

procedure TAllocationLimitTests.Execute_JsonStringifyObjectsNestedPastCallDepth_RaisesCallDepthExceeded;
begin
  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(JsonNestedObjectScript);
    end,
    EJSCallDepthExceeded,
    'JSON object nesting beyond the call depth limit must raise');
end;

procedure TAllocationLimitTests.Execute_AfterAllocationLimitExceeded_EngineStaysUsable;
begin
  AssertExceedsLimit(RepeatBillionScript, 'A repeat of a billion must be refused');

  const Outcome = FEngine.Evaluate(NormalScript);

  Assert.AreEqual(Double(NormalScriptResult), Outcome.ToNumber, EngineUsableMessage);
end;

{ TDeepStructureTests }

procedure TDeepStructureTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDeepStructureTests.TearDown;
begin
  FreeAndNil(FEngine);
end;

procedure TDeepStructureTests.AssertDeepArrayRejected(const Usage: string);
begin
  const Script = DeepArrayPrefix + Usage;

  Assert.WillRaise(
    procedure
    begin
      FEngine.Execute(Script);
    end,
    EJSCallDepthExceeded,
    'A very deeply nested array must be refused, not recursed into');
end;

procedure TDeepStructureTests.IndexOf_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepIndexOfScript);
end;

procedure TDeepStructureTests.Includes_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepIncludesScript);
end;

procedure TDeepStructureTests.StartsWith_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepStartsWithScript);
end;

procedure TDeepStructureTests.Search_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepSearchScript);
end;

procedure TDeepStructureTests.ParseInt_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepParseIntScript);
end;

procedure TDeepStructureTests.DefaultSort_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepSortScript);
end;

procedure TDeepStructureTests.InOperator_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepInScript);
end;

procedure TDeepStructureTests.HasOwnProperty_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepHasOwnPropertyScript);
end;

procedure TDeepStructureTests.JsonParse_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepJsonParseScript);
end;

procedure TDeepStructureTests.RegExpTest_WithDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepRegExpTestScript);
end;

procedure TDeepStructureTests.Release_OfDeepObjectChain_DoesNotOverflowTheStack;
begin
  FEngine.Execute(DeepObjectChainScript);

  FreeAndNil(FEngine);

  Assert.Pass('Freeing the engine released the whole chain');
end;

procedure TDeepStructureTests.Release_OfDeepMixedChain_DoesNotOverflowTheStack;
begin
  FEngine.Execute(DeepMixedChainScript);

  FreeAndNil(FEngine);

  Assert.Pass('Freeing the engine released the whole mixed chain');
end;

procedure TDeepStructureTests.Release_OfDeepObjectChainDroppedByAssignment_DoesNotOverflowTheStack;
begin
  FEngine.Execute(DeepChainDropScript);

  Assert.Pass('Dropping the last reference released the whole chain');
end;

procedure TDeepStructureTests.Release_OfDeepObjectChainAfterCollection_DoesNotOverflowTheStack;
begin
  FEngine.Execute(DeepChainDropScript);
  FEngine.CollectGarbage;

  Assert.Pass('Collecting garbage after dropping the chain did not overflow');
end;

procedure TDeepStructureTests.Throw_OfDeepArray_RaisesCallDepthExceeded;
begin
  AssertDeepArrayRejected(DeepThrowScript);
end;

initialization
  TDUnitX.RegisterTestFixture(TCallDepthLimitTests);
  TDUnitX.RegisterTestFixture(TAllocationLimitTests);
  TDUnitX.RegisterTestFixture(TDeepStructureTests);

end.
