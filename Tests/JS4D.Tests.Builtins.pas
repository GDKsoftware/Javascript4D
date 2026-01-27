unit JS4D.Tests.Builtins;

{$SCOPEDENUMS ON}

interface

uses
  System.Math,
  DUnitX.TestFramework,
  JS4D.Types,
  JS4D.Engine;

type
  [TestFixture]
  TArrayMethodsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Array_Push_AddsElement;

    [Test]
    procedure Array_Pop_RemovesLastElement;

    [Test]
    procedure Array_Shift_RemovesFirstElement;

    [Test]
    procedure Array_Unshift_AddsToFront;

    [Test]
    procedure Array_IndexOf_FindsElement;

    [Test]
    procedure Array_IndexOf_ReturnsMinusOneWhenNotFound;

    [Test]
    procedure Array_Join_ConcatenatesElements;

    [Test]
    procedure Array_Slice_ReturnsSubarray;

    [Test]
    procedure Array_Concat_MergesArrays;

    [Test]
    procedure Array_Reverse_ReversesInPlace;

    [Test]
    procedure Array_Reverse_ChainedWithJoin;

    [Test]
    procedure Array_SortThenReverse_Statements;

    [Test]
    procedure Array_SortThenReverse_Chained;

    [Test]
    procedure Array_SortThenReverse_InStringConcat;

    [Test]
    procedure Array_SortThenReverse_ExactDemoCode;

    [Test]
    procedure Array_Includes_ReturnsTrue;

    [Test]
    procedure Array_Map_TransformsElements;

    [Test]
    procedure Array_Filter_SelectsElements;

    [Test]
    procedure Array_Reduce_AccumulatesValue;

    [Test]
    procedure Array_ForEach_IteratesElements;

    [Test]
    procedure Array_Some_ReturnsTrueWhenMatches;

    [Test]
    procedure Array_Every_ReturnsTrueWhenAllMatch;

    [Test]
    procedure Array_Find_ReturnsFirstMatch;

    [Test]
    procedure Array_FindIndex_ReturnsIndex;

    [Test]
    procedure Array_Sort_SortsStrings;

    [Test]
    procedure Array_Sort_WithComparer;

    [Test]
    procedure Array_Sort_WithNumericComparerDescending;

    [Test]
    procedure Array_Sort_WithObjectPropertyComparer;

    [Test]
    procedure Array_Sort_WithExternalLookup;

    [Test]
    procedure Array_Sort_WithExternalLookupDescending;

    [Test]
    procedure Array_Sort_ObjectKeysWithLookup;

    [Test]
    procedure Array_Sort_WithStringValuesFromCSV;

    [Test]
    procedure Array_Flat_FlattensNestedArrays;

    [Test]
    procedure Array_Sort_TwoStepObjectKeys;

    [Test]
    procedure Array_Sort_TwoStepWithVariable;
  end;

  [TestFixture]
  TStringMethodsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure String_CharAt_ReturnsCharacter;

    [Test]
    procedure String_IndexOf_FindsSubstring;

    [Test]
    procedure String_Substring_ReturnsSubstring;

    [Test]
    procedure String_Split_SplitsString;

    [Test]
    procedure String_ToLowerCase_ConvertsToLower;

    [Test]
    procedure String_ToUpperCase_ConvertsToUpper;

    [Test]
    procedure String_Trim_RemovesWhitespace;

    [Test]
    procedure String_Replace_ReplacesFirst;

    [Test]
    procedure String_StartsWith_ChecksPrefix;

    [Test]
    procedure String_EndsWith_ChecksSuffix;

    [Test]
    procedure String_Includes_ChecksContains;

    [Test]
    procedure String_Repeat_RepeatsString;

    [Test]
    procedure String_PadStart_PadsBeginning;

    [Test]
    procedure String_PadEnd_PadsEnd;
  end;

  [TestFixture]
  TObjectMethodsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Object_Keys_ReturnsPropertyNames;

    [Test]
    procedure Object_Values_ReturnsPropertyValues;

    [Test]
    procedure Object_Entries_ReturnsKeyValuePairs;

    [Test]
    procedure Object_Assign_CopiesProperties;

    [Test]
    procedure Object_HasOwnProperty_ReturnsTrue;

    [Test]
    procedure Object_HasOwnProperty_ReturnsFalse;
  end;

  [TestFixture]
  TJSONTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure JSON_Parse_ParsesObject;

    [Test]
    procedure JSON_Parse_ParsesArray;

    [Test]
    procedure JSON_Parse_ParsesNestedStructure;

    [Test]
    procedure JSON_Stringify_StringifiesObject;

    [Test]
    procedure JSON_Stringify_StringifiesArray;

    [Test]
    procedure JSON_RoundTrip_PreservesData;
  end;

  [TestFixture]
  TGlobalFunctionsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure ParseInt_ParsesInteger;

    [Test]
    procedure ParseInt_ParsesHex;

    [Test]
    procedure ParseFloat_ParsesFloat;

    [Test]
    procedure IsNaN_DetectsNaN;

    [Test]
    procedure IsFinite_DetectsFinite;

    [Test]
    procedure Array_IsArray_DetectsArray;

    [Test]
    procedure GlobalNumber_ConvertsStringToNumber;

    [Test]
    procedure GlobalNumber_ConvertsBooleanTrue;

    [Test]
    procedure GlobalNumber_ConvertsBooleanFalse;

    [Test]
    procedure GlobalNumber_ConvertsNull;

    [Test]
    procedure GlobalNumber_ConvertsUndefined;

    [Test]
    procedure UnaryPlus_ConvertsStringToNumber;

    [Test]
    procedure Number_ToString_UsesDotDecimalSeparator;
  end;

  [TestFixture]
  TRegExpTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure RegExp_Test_MatchesPattern;

    [Test]
    procedure RegExp_Test_NoMatch;

    [Test]
    procedure RegExp_Exec_ReturnsMatchArray;

    [Test]
    procedure RegExp_Exec_NoMatch_ReturnsNull;

    [Test]
    procedure RegExp_CaseInsensitive_Flag;

    [Test]
    procedure RegExp_Global_Flag;

    [Test]
    procedure String_Match_ReturnsMatches;

    [Test]
    procedure String_Match_NoMatch_ReturnsNull;

    [Test]
    procedure String_Replace_WithRegExp;

    [Test]
    procedure String_Replace_GlobalRegExp;

    [Test]
    procedure String_Search_ReturnsIndex;

    [Test]
    procedure String_Search_NoMatch_ReturnsMinusOne;

    [Test]
    procedure String_Split_WithRegExp;

    [Test]
    procedure RegExp_Source_Property;

    [Test]
    procedure RegExp_Flags_Properties;

    [Test]
    procedure RegExp_Literal_Syntax;
  end;

  [TestFixture]
  TDateMethodsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Date_Now_ReturnsTimestamp;

    [Test]
    procedure Date_Constructor_NoArgs;

    [Test]
    procedure Date_Constructor_WithTimestamp;

    [Test]
    procedure Date_Constructor_WithComponents;

    [Test]
    procedure Date_GetFullYear_ReturnsYear;

    [Test]
    procedure Date_GetMonth_ReturnsMonth;

    [Test]
    procedure Date_GetDate_ReturnsDay;

    [Test]
    procedure Date_GetDay_ReturnsDayOfWeek;

    [Test]
    procedure Date_GetHours_ReturnsHours;

    [Test]
    procedure Date_GetMinutes_ReturnsMinutes;

    [Test]
    procedure Date_GetSeconds_ReturnsSeconds;

    [Test]
    procedure Date_GetMilliseconds_ReturnsMs;

    [Test]
    procedure Date_GetTime_ReturnsTimestamp;

    [Test]
    procedure Date_SetFullYear_SetsYear;

    [Test]
    procedure Date_SetMonth_SetsMonth;

    [Test]
    procedure Date_SetDate_SetsDay;

    [Test]
    procedure Date_SetHours_SetsHours;

    [Test]
    procedure Date_SetMinutes_SetsMinutes;

    [Test]
    procedure Date_SetSeconds_SetsSeconds;

    [Test]
    procedure Date_ToISOString_FormatsCorrectly;

    [Test]
    procedure Date_ToDateString_FormatsCorrectly;

    [Test]
    procedure Date_ToTimeString_FormatsCorrectly;

    [Test]
    procedure Date_Parse_ParsesISOString;

    [Test]
    procedure Date_UTC_ReturnsTimestamp;

    [Test]
    procedure Date_GetUTCFullYear_ReturnsUTCYear;

    [Test]
    procedure Date_GetTimezoneOffset_ReturnsOffset;
  end;

  [TestFixture]
  TErrorConstructorTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Error_Constructor_CreatesError;

    [Test]
    procedure Error_Message_Property;

    [Test]
    procedure Error_Name_Property;

    [Test]
    procedure TypeError_Constructor;

    [Test]
    procedure RangeError_Constructor;

    [Test]
    procedure ReferenceError_Constructor;

    [Test]
    procedure SyntaxError_Constructor;

    [Test]
    procedure URIError_Constructor;

    [Test]
    procedure EvalError_Constructor;

    [Test]
    procedure Error_ToString_FormatsCorrectly;

    [Test]
    procedure Throw_Error_CanBeCaught;

    [Test]
    procedure Throw_TypeError_CanBeCaught;

    [Test]
    procedure Error_InstanceOf_Error;

    [Test]
    procedure TypeError_InstanceOf_Error;

    [Test]
    procedure Error_Stack_Property;
  end;

  [TestFixture]
  TStrictModeTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure StrictMode_UndeclaredVariable_ThrowsError;

    [Test]
    procedure StrictMode_DeleteUndeletable_ThrowsError;

    [Test]
    procedure StrictMode_DuplicateParams_ThrowsError;

    [Test]
    procedure StrictMode_OctalLiteral_ThrowsError;

    [Test]
    procedure StrictMode_WithStatement_ThrowsError;

    [Test]
    procedure StrictMode_EvalArguments_ReadOnly;

    [Test]
    procedure StrictMode_ThisInFunction_IsUndefined;

    [Test]
    procedure StrictMode_FunctionScoped;

    [Test]
    procedure NonStrictMode_UndeclaredVariable_Allowed;

    [Test]
    procedure StrictMode_DeleteVariable_ThrowsError;

    [Test]
    procedure StrictMode_ReservedWords_ThrowsError;
  end;

  [TestFixture]
  TFunctionMethodsTests = class
  private
    FEngine: TJSEngine;

  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Function_Call_SetsThisContext;

    [Test]
    procedure Function_Call_PassesArguments;

    [Test]
    procedure Function_Call_NullThis_UsesGlobal;

    [Test]
    procedure Function_Apply_SetsThisContext;

    [Test]
    procedure Function_Apply_PassesArrayAsArguments;

    [Test]
    procedure Function_Apply_EmptyArray;

    [Test]
    procedure Function_Bind_ReturnsNewFunction;

    [Test]
    procedure Function_Bind_PartialApplication;

    [Test]
    procedure Function_Bind_ChainedBind;
  end;

implementation

procedure TArrayMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TArrayMethodsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TArrayMethodsTests.Array_Push_AddsElement;
begin
  FEngine.Execute('var arr = [1, 2]; var len = arr.push(3);');

  const LenResult = FEngine.GetVariable('len');
  Assert.AreEqual(Double(3), LenResult.AsNumber);

  const ArrResult = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('1,2,3', ArrResult.AsString);
end;

procedure TArrayMethodsTests.Array_Pop_RemovesLastElement;
begin
  FEngine.Execute('var arr = [1, 2, 3]; var popped = arr.pop();');

  const PoppedResult = FEngine.GetVariable('popped');
  Assert.AreEqual(Double(3), PoppedResult.AsNumber);

  const ArrResult = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('1,2', ArrResult.AsString);
end;

procedure TArrayMethodsTests.Array_Shift_RemovesFirstElement;
begin
  FEngine.Execute('var arr = [1, 2, 3]; var shifted = arr.shift();');

  const ShiftedResult = FEngine.GetVariable('shifted');
  Assert.AreEqual(Double(1), ShiftedResult.AsNumber);

  const ArrResult = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('2,3', ArrResult.AsString);
end;

procedure TArrayMethodsTests.Array_Unshift_AddsToFront;
begin
  FEngine.Execute('var arr = [2, 3]; var len = arr.unshift(1);');

  const LenResult = FEngine.GetVariable('len');
  Assert.AreEqual(Double(3), LenResult.AsNumber);

  const ArrResult = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('1,2,3', ArrResult.AsString);
end;

procedure TArrayMethodsTests.Array_IndexOf_FindsElement;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 2].indexOf(2)');
  Assert.AreEqual(Double(1), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_IndexOf_ReturnsMinusOneWhenNotFound;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].indexOf(5)');
  Assert.AreEqual(Double(-1), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_Join_ConcatenatesElements;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].join("-")');
  Assert.AreEqual('1-2-3', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Slice_ReturnsSubarray;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 4, 5].slice(1, 4).join(",")');
  Assert.AreEqual('2,3,4', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Concat_MergesArrays;
begin
  const Result = FEngine.Evaluate('[1, 2].concat([3, 4]).join(",")');
  Assert.AreEqual('1,2,3,4', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Reverse_ReversesInPlace;
begin
  FEngine.Execute('var arr = [1, 2, 3]; arr.reverse();');
  const Result = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('3,2,1', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Reverse_ChainedWithJoin;
begin
  const Result = FEngine.Evaluate('[3, 1, 2].reverse().join(",")');
  Assert.AreEqual('2,1,3', Result.AsString);
end;

procedure TArrayMethodsTests.Array_SortThenReverse_Statements;
begin
  FEngine.Execute('var arr = [3, 1, 2]; arr.sort(); arr.reverse();');
  const Result = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('3,2,1', Result.AsString);
end;

procedure TArrayMethodsTests.Array_SortThenReverse_Chained;
begin
  FEngine.Execute('var arr = [3, 1, 2]; arr.sort();');
  const Result = FEngine.Evaluate('arr.reverse().join(",")');
  Assert.AreEqual('3,2,1', Result.AsString);
end;

procedure TArrayMethodsTests.Array_SortThenReverse_InStringConcat;
begin
  // Exact scenario from demo: sort().join() in concat, then reverse().join() in concat
  FEngine.Execute(
    'var letters = ["c", "a", "b", "e", "d"];' +
    'var sorted = "Sorted: " + letters.sort().join(",");' +
    'var reversed = "Reversed: " + letters.reverse().join(",");'
  );
  Assert.AreEqual('Sorted: a,b,c,d,e', FEngine.GetVariable('sorted').ToString);
  Assert.AreEqual('Reversed: e,d,c,b,a', FEngine.GetVariable('reversed').ToString);
end;

procedure TArrayMethodsTests.Array_SortThenReverse_ExactDemoCode;
begin
  // Test 1: Array LITERAL in console.log - should work
  var Out1: TArray<string>;
  FEngine.OnConsoleOutput := procedure(const S: string)
  begin
    SetLength(Out1, Length(Out1) + 1);
    Out1[High(Out1)] := S;
  end;
  FEngine.Execute('console.log([3, 1, 2].reverse().join(","));');
  Assert.AreEqual('2,1,3', Out1[0], 'Array literal reverse in console.log failed');

  // Test 2: Array VARIABLE in console.log - this is failing
  var Out2: TArray<string>;
  FEngine.OnConsoleOutput := procedure(const S: string)
  begin
    SetLength(Out2, Length(Out2) + 1);
    Out2[High(Out2)] := S;
  end;
  FEngine.Execute(
    'var a = [3, 1, 2];' +
    'console.log(a.reverse().join(","));'
  );
  Assert.AreEqual('2,1,3', Out2[0], 'Array variable reverse in console.log failed');
end;

procedure TArrayMethodsTests.Array_Includes_ReturnsTrue;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].includes(2)');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TArrayMethodsTests.Array_Map_TransformsElements;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].map(function(x) { return x * 2; }).join(",")');
  Assert.AreEqual('2,4,6', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Filter_SelectsElements;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 4, 5].filter(function(x) { return x > 2; }).join(",")');
  Assert.AreEqual('3,4,5', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Reduce_AccumulatesValue;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 4].reduce(function(acc, x) { return acc + x; }, 0)');
  Assert.AreEqual(Double(10), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_ForEach_IteratesElements;
begin
  FEngine.Execute('var sum = 0; [1, 2, 3].forEach(function(x) { sum += x; });');
  const Result = FEngine.GetVariable('sum');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_Some_ReturnsTrueWhenMatches;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].some(function(x) { return x > 2; })');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TArrayMethodsTests.Array_Every_ReturnsTrueWhenAllMatch;
begin
  const Result = FEngine.Evaluate('[1, 2, 3].every(function(x) { return x > 0; })');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TArrayMethodsTests.Array_Find_ReturnsFirstMatch;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 4].find(function(x) { return x > 2; })');
  Assert.AreEqual(Double(3), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_FindIndex_ReturnsIndex;
begin
  const Result = FEngine.Evaluate('[1, 2, 3, 4].findIndex(function(x) { return x > 2; })');
  Assert.AreEqual(Double(2), Result.AsNumber);
end;

procedure TArrayMethodsTests.Array_Sort_SortsStrings;
begin
  const Result = FEngine.Evaluate('["c", "a", "b"].sort().join(",")');
  Assert.AreEqual('a,b,c', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithComparer;
begin
  const Result = FEngine.Evaluate('[3, 1, 2].sort(function(a, b) { return a - b; }).join(",")');
  Assert.AreEqual('1,2,3', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithNumericComparerDescending;
begin
  FEngine.Execute('var arr = [3, 1, 4, 1, 5, 9, 2, 6]; var sorted = arr.sort(function(a, b) { return b - a; });');
  const Result = FEngine.Evaluate('sorted.join(",")');
  Assert.AreEqual('9,6,5,4,3,2,1,1', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithObjectPropertyComparer;
begin
  FEngine.Execute('var items = [{name: "B", val: 20}, {name: "A", val: 10}, {name: "C", val: 30}];');
  FEngine.Execute('items.sort(function(a, b) { return a.val - b.val; });');
  const Result = FEngine.Evaluate('items.map(function(x) { return x.name; }).join(",")');
  Assert.AreEqual('A,B,C', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithExternalLookup;
begin
  FEngine.Execute('var keys = ["x", "y", "z"]; var vals = { x: 300, y: 100, z: 200 };');
  FEngine.Execute('keys.sort(function(a, b) { return vals[a] - vals[b]; });');
  const Result = FEngine.Evaluate('keys.join(",")');
  Assert.AreEqual('y,z,x', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithExternalLookupDescending;
begin
  FEngine.Execute('var arr = ["Jan", "Lisa", "Kees"];');
  FEngine.Execute('var scores = { "Jan": 6146.79, "Lisa": 8964.78, "Kees": 5297.63 };');
  FEngine.Execute('var sorted = arr.sort(function(a, b) { return scores[b] - scores[a]; });');
  const Result = FEngine.Evaluate('sorted.join(", ")');
  Assert.AreEqual('Lisa, Jan, Kees', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_ObjectKeysWithLookup;
const
  Script =
    'var data = [' +
    '  {verkoper: "Jan", aantal: 3, prijs: 1299.99},' +
    '  {verkoper: "Jan", aantal: 12, prijs: 29.99},' +
    '  {verkoper: "Lisa", aantal: 5, prijs: 449.00},' +
    '  {verkoper: "Lisa", aantal: 8, prijs: 89.99},' +
    '  {verkoper: "Kees", aantal: 2, prijs: 1299.99},' +
    '  {verkoper: "Kees", aantal: 15, prijs: 79.99},' +
    '  {verkoper: "Jan", aantal: 3, prijs: 449.00},' +
    '  {verkoper: "Lisa", aantal: 4, prijs: 1299.99},' +
    '  {verkoper: "Kees", aantal: 20, prijs: 29.99},' +
    '  {verkoper: "Jan", aantal: 6, prijs: 89.99},' +
    '  {verkoper: "Lisa", aantal: 10, prijs: 79.99},' +
    '  {verkoper: "Kees", aantal: 2, prijs: 449.00}' +
    '];' +
    'var verkooperResultaten = {};' +
    'data.forEach(function(row) {' +
    '  var verk = row.verkoper;' +
    '  if (!verkooperResultaten[verk]) verkooperResultaten[verk] = 0;' +
    '  verkooperResultaten[verk] += parseFloat(row.aantal) * parseFloat(row.prijs);' +
    '});' +
    'var verkopers = Object.keys(verkooperResultaten).sort(function(a, b) {' +
    '  return verkooperResultaten[b] - verkooperResultaten[a];' +
    '});';
begin
  FEngine.Execute(Script);

  const Jan = FEngine.Evaluate('verkooperResultaten["Jan"]');
  const Lisa = FEngine.Evaluate('verkooperResultaten["Lisa"]');
  const Kees = FEngine.Evaluate('verkooperResultaten["Kees"]');
  Assert.AreEqual(6146.79, Jan.AsNumber, 0.01, 'Jan totaal');
  Assert.AreEqual(8964.78, Lisa.AsNumber, 0.01, 'Lisa totaal');
  Assert.AreEqual(5297.63, Kees.AsNumber, 0.01, 'Kees totaal');

  const Result = FEngine.Evaluate('verkopers.join(", ")');
  Assert.AreEqual('Lisa, Jan, Kees', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_WithStringValuesFromCSV;
const
  Script =
    'var data = [' +
    '  {verkoper: "Jan", aantal: "3", prijs: "1299.99"},' +
    '  {verkoper: "Jan", aantal: "12", prijs: "29.99"},' +
    '  {verkoper: "Lisa", aantal: "5", prijs: "449.00"},' +
    '  {verkoper: "Lisa", aantal: "8", prijs: "89.99"},' +
    '  {verkoper: "Kees", aantal: "2", prijs: "1299.99"},' +
    '  {verkoper: "Kees", aantal: "15", prijs: "79.99"},' +
    '  {verkoper: "Jan", aantal: "3", prijs: "449.00"},' +
    '  {verkoper: "Lisa", aantal: "4", prijs: "1299.99"},' +
    '  {verkoper: "Kees", aantal: "20", prijs: "29.99"},' +
    '  {verkoper: "Jan", aantal: "6", prijs: "89.99"},' +
    '  {verkoper: "Lisa", aantal: "10", prijs: "79.99"},' +
    '  {verkoper: "Kees", aantal: "2", prijs: "449.00"}' +
    '];' +
    'var verkooperResultaten = {};' +
    'data.forEach(function(row) {' +
    '  var verk = row.verkoper;' +
    '  if (!verkooperResultaten[verk]) verkooperResultaten[verk] = 0;' +
    '  verkooperResultaten[verk] += parseFloat(row.aantal) * parseFloat(row.prijs);' +
    '});' +
    'var verkopers = Object.keys(verkooperResultaten).sort(function(a, b) {' +
    '  return verkooperResultaten[b] - verkooperResultaten[a];' +
    '});';
begin
  FEngine.Execute(Script);

  const Jan = FEngine.Evaluate('verkooperResultaten["Jan"]');
  const Lisa = FEngine.Evaluate('verkooperResultaten["Lisa"]');
  const Kees = FEngine.Evaluate('verkooperResultaten["Kees"]');
  Assert.AreEqual(6146.79, Jan.AsNumber, 0.01, 'Jan totaal');
  Assert.AreEqual(8964.78, Lisa.AsNumber, 0.01, 'Lisa totaal');
  Assert.AreEqual(5297.63, Kees.AsNumber, 0.01, 'Kees totaal');

  const Result = FEngine.Evaluate('verkopers.join(", ")');
  Assert.AreEqual('Lisa, Jan, Kees', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Flat_FlattensNestedArrays;
begin
  const Result = FEngine.Evaluate('[[1, 2], [3, 4]].flat().join(",")');
  Assert.AreEqual('1,2,3,4', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_TwoStepObjectKeys;
const
  Script =
    'var cats = { "Support": { hours: 10 }, "Bug Fixes": { hours: 25 } };' +
    'var keys = Object.keys(cats);' +
    'keys.sort(function(a, b) { return cats[b].hours - cats[a].hours; });';
begin
  FEngine.Execute(Script);

  const Result = FEngine.Evaluate('keys.join(", ")');
  Assert.AreEqual('Bug Fixes, Support', Result.AsString);
end;

procedure TArrayMethodsTests.Array_Sort_TwoStepWithVariable;
const
  Script =
    'var arr = [3, 1, 2];' +
    'arr.sort(function(a, b) { return a - b; });';
begin
  FEngine.Execute(Script);

  const Result = FEngine.Evaluate('arr.join(",")');
  Assert.AreEqual('1,2,3', Result.AsString);
end;

procedure TStringMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TStringMethodsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TStringMethodsTests.String_CharAt_ReturnsCharacter;
begin
  const Result = FEngine.Evaluate('"hello".charAt(1)');
  Assert.AreEqual('e', Result.AsString);
end;

procedure TStringMethodsTests.String_IndexOf_FindsSubstring;
begin
  const Result = FEngine.Evaluate('"hello world".indexOf("world")');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

procedure TStringMethodsTests.String_Substring_ReturnsSubstring;
begin
  const Result = FEngine.Evaluate('"hello".substring(1, 4)');
  Assert.AreEqual('ell', Result.AsString);
end;

procedure TStringMethodsTests.String_Split_SplitsString;
begin
  const Result = FEngine.Evaluate('"a,b,c".split(",").join("-")');
  Assert.AreEqual('a-b-c', Result.AsString);
end;

procedure TStringMethodsTests.String_ToLowerCase_ConvertsToLower;
begin
  const Result = FEngine.Evaluate('"HELLO".toLowerCase()');
  Assert.AreEqual('hello', Result.AsString);
end;

procedure TStringMethodsTests.String_ToUpperCase_ConvertsToUpper;
begin
  const Result = FEngine.Evaluate('"hello".toUpperCase()');
  Assert.AreEqual('HELLO', Result.AsString);
end;

procedure TStringMethodsTests.String_Trim_RemovesWhitespace;
begin
  const Result = FEngine.Evaluate('"  hello  ".trim()');
  Assert.AreEqual('hello', Result.AsString);
end;

procedure TStringMethodsTests.String_Replace_ReplacesFirst;
begin
  const Result = FEngine.Evaluate('"hello hello".replace("hello", "hi")');
  Assert.AreEqual('hi hello', Result.AsString);
end;

procedure TStringMethodsTests.String_StartsWith_ChecksPrefix;
begin
  const Result = FEngine.Evaluate('"hello".startsWith("hel")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TStringMethodsTests.String_EndsWith_ChecksSuffix;
begin
  const Result = FEngine.Evaluate('"hello".endsWith("lo")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TStringMethodsTests.String_Includes_ChecksContains;
begin
  const Result = FEngine.Evaluate('"hello".includes("ell")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TStringMethodsTests.String_Repeat_RepeatsString;
begin
  const Result = FEngine.Evaluate('"ab".repeat(3)');
  Assert.AreEqual('ababab', Result.AsString);
end;

procedure TStringMethodsTests.String_PadStart_PadsBeginning;
begin
  const Result = FEngine.Evaluate('"5".padStart(3, "0")');
  Assert.AreEqual('005', Result.AsString);
end;

procedure TStringMethodsTests.String_PadEnd_PadsEnd;
begin
  const Result = FEngine.Evaluate('"5".padEnd(3, "0")');
  Assert.AreEqual('500', Result.AsString);
end;

procedure TObjectMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TObjectMethodsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TObjectMethodsTests.Object_Keys_ReturnsPropertyNames;
begin
  FEngine.Execute('var obj = { a: 1, b: 2 };');
  const Result = FEngine.Evaluate('Object.keys(obj).sort().join(",")');
  Assert.AreEqual('a,b', Result.AsString);
end;

procedure TObjectMethodsTests.Object_Values_ReturnsPropertyValues;
begin
  FEngine.Execute('var obj = { a: 1, b: 2 };');
  const Result = FEngine.Evaluate('Object.values(obj).sort().join(",")');
  Assert.AreEqual('1,2', Result.AsString);
end;

procedure TObjectMethodsTests.Object_Entries_ReturnsKeyValuePairs;
begin
  FEngine.Execute('var obj = { a: 1 };');
  const Result = FEngine.Evaluate('Object.entries(obj)[0].join(":")');
  Assert.AreEqual('a:1', Result.AsString);
end;

procedure TObjectMethodsTests.Object_Assign_CopiesProperties;
begin
  FEngine.Execute('var target = { a: 1 }; Object.assign(target, { b: 2 });');
  const Result = FEngine.Evaluate('target.a + target.b');
  Assert.AreEqual(Double(3), Result.AsNumber);
end;

procedure TObjectMethodsTests.Object_HasOwnProperty_ReturnsTrue;
begin
  FEngine.Execute('var obj = { name: "test", value: 42 };');
  const Result = FEngine.Evaluate('obj.hasOwnProperty("name")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TObjectMethodsTests.Object_HasOwnProperty_ReturnsFalse;
begin
  FEngine.Execute('var obj = { name: "test" };');
  const Result = FEngine.Evaluate('obj.hasOwnProperty("unknown")');
  Assert.IsFalse(Result.AsBoolean);
end;

procedure TJSONTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TJSONTests.TearDown;
begin
  FEngine.Free;
end;

procedure TJSONTests.JSON_Parse_ParsesObject;
begin
  FEngine.Execute('var obj = JSON.parse(''{"a":1,"b":2}'');');
  const Result = FEngine.Evaluate('obj.a + obj.b');
  Assert.AreEqual(Double(3), Result.AsNumber);
end;

procedure TJSONTests.JSON_Parse_ParsesArray;
begin
  const Result = FEngine.Evaluate('JSON.parse("[1,2,3]").join(",")');
  Assert.AreEqual('1,2,3', Result.AsString);
end;

procedure TJSONTests.JSON_Parse_ParsesNestedStructure;
begin
  FEngine.Execute('var obj = JSON.parse(''{"arr":[1,2],"nested":{"x":10}}'');');
  const Result = FEngine.Evaluate('obj.arr[1] + obj.nested.x');
  Assert.AreEqual(Double(12), Result.AsNumber);
end;

procedure TJSONTests.JSON_Stringify_StringifiesObject;
begin
  FEngine.Execute('var obj = { a: 1 };');
  const Result = FEngine.Evaluate('JSON.stringify(obj)');
  const JsonStr = Result.AsString;
  Assert.IsTrue(Pos('"a"', JsonStr) > 0);
  Assert.IsTrue(Pos('1', JsonStr) > 0);
end;

procedure TJSONTests.JSON_Stringify_StringifiesArray;
begin
  const Result = FEngine.Evaluate('JSON.stringify([1,2,3])');
  const JsonStr = Result.AsString;
  Assert.IsTrue((JsonStr = '[1,2,3]') or (JsonStr = '[1.0,2.0,3.0]'));
end;

procedure TJSONTests.JSON_RoundTrip_PreservesData;
begin
  FEngine.Execute('var original = { x: 42, y: "test" };');
  FEngine.Execute('var json = JSON.stringify(original);');
  FEngine.Execute('var parsed = JSON.parse(json);');
  const XResult = FEngine.Evaluate('parsed.x');
  const YResult = FEngine.Evaluate('parsed.y');
  Assert.AreEqual(Double(42), XResult.AsNumber);
  Assert.AreEqual('test', YResult.AsString);
end;

procedure TGlobalFunctionsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TGlobalFunctionsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TGlobalFunctionsTests.ParseInt_ParsesInteger;
begin
  const Result = FEngine.Evaluate('parseInt("42")');
  Assert.AreEqual(Double(42), Result.AsNumber);
end;

procedure TGlobalFunctionsTests.ParseInt_ParsesHex;
begin
  const Result = FEngine.Evaluate('parseInt("0xFF", 16)');
  Assert.AreEqual(Double(255), Result.AsNumber);
end;

procedure TGlobalFunctionsTests.ParseFloat_ParsesFloat;
begin
  const Result = FEngine.Evaluate('parseFloat("3.14")');
  Assert.AreEqual(3.14, Result.AsNumber, 0.001);
end;

procedure TGlobalFunctionsTests.IsNaN_DetectsNaN;
begin
  const Result = FEngine.Evaluate('isNaN(NaN)');
  Assert.IsTrue(Result.AsBoolean);

  const Result2 = FEngine.Evaluate('isNaN(42)');
  Assert.IsFalse(Result2.AsBoolean);
end;

procedure TGlobalFunctionsTests.IsFinite_DetectsFinite;
begin
  const Result = FEngine.Evaluate('isFinite(42)');
  Assert.IsTrue(Result.AsBoolean);

  const Result2 = FEngine.Evaluate('isFinite(Infinity)');
  Assert.IsFalse(Result2.AsBoolean);
end;

procedure TGlobalFunctionsTests.Array_IsArray_DetectsArray;
begin
  const Result = FEngine.Evaluate('Array.isArray([1,2,3])');
  Assert.IsTrue(Result.AsBoolean);

  const Result2 = FEngine.Evaluate('Array.isArray("hello")');
  Assert.IsFalse(Result2.AsBoolean);
end;

procedure TGlobalFunctionsTests.GlobalNumber_ConvertsStringToNumber;
begin
  const Result = FEngine.Evaluate('Number("123.45")');
  Assert.AreEqual(Double(123.45), Result.AsNumber, 0.001);
end;

procedure TGlobalFunctionsTests.GlobalNumber_ConvertsBooleanTrue;
begin
  const Result = FEngine.Evaluate('Number(true)');
  Assert.AreEqual(Double(1), Result.AsNumber);
end;

procedure TGlobalFunctionsTests.GlobalNumber_ConvertsBooleanFalse;
begin
  const Result = FEngine.Evaluate('Number(false)');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TGlobalFunctionsTests.GlobalNumber_ConvertsNull;
begin
  const Result = FEngine.Evaluate('Number(null)');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TGlobalFunctionsTests.GlobalNumber_ConvertsUndefined;
begin
  const Result = FEngine.Evaluate('Number(undefined)');
  Assert.IsTrue(System.Math.IsNaN(Result.AsNumber));
end;

procedure TGlobalFunctionsTests.UnaryPlus_ConvertsStringToNumber;
begin
  const Result = FEngine.Evaluate('+"123.45"');
  Assert.AreEqual(Double(123.45), Result.AsNumber, 0.001);
end;

procedure TGlobalFunctionsTests.Number_ToString_UsesDotDecimalSeparator;
begin
  const Result = FEngine.Evaluate('(3.14159).toString()');
  Assert.AreEqual('3.14159', Result.AsString);
end;

procedure TRegExpTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TRegExpTests.TearDown;
begin
  FEngine.Free;
end;

procedure TRegExpTests.RegExp_Test_MatchesPattern;
begin
  const Result = FEngine.Evaluate('/hello/.test("hello world")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TRegExpTests.RegExp_Test_NoMatch;
begin
  const Result = FEngine.Evaluate('/xyz/.test("hello world")');
  Assert.IsFalse(Result.AsBoolean);
end;

procedure TRegExpTests.RegExp_Exec_ReturnsMatchArray;
begin
  FEngine.Execute('var result = /(\w+)\s(\w+)/.exec("hello world");');
  const FullMatch = FEngine.Evaluate('result[0]');
  Assert.AreEqual('hello world', FullMatch.AsString);

  const Group1 = FEngine.Evaluate('result[1]');
  Assert.AreEqual('hello', Group1.AsString);

  const Group2 = FEngine.Evaluate('result[2]');
  Assert.AreEqual('world', Group2.AsString);
end;

procedure TRegExpTests.RegExp_Exec_NoMatch_ReturnsNull;
begin
  const Result = FEngine.Evaluate('/xyz/.exec("hello")');
  Assert.IsTrue(Result.IsNull);
end;

procedure TRegExpTests.RegExp_CaseInsensitive_Flag;
begin
  const Result = FEngine.Evaluate('/HELLO/i.test("hello")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TRegExpTests.RegExp_Global_Flag;
begin
  FEngine.Execute('var str = "cat bat rat"; var re = /at/g; var count = 0;');
  FEngine.Execute('while (re.exec(str) !== null) { count++; }');
  const Result = FEngine.GetVariable('count');
  Assert.AreEqual(Double(3), Result.AsNumber);
end;

procedure TRegExpTests.String_Match_ReturnsMatches;
begin
  FEngine.Execute('var result = "hello world".match(/\w+/g);');
  const Length = FEngine.Evaluate('result.length');
  Assert.AreEqual(Double(2), Length.AsNumber);

  const First = FEngine.Evaluate('result[0]');
  Assert.AreEqual('hello', First.AsString);
end;

procedure TRegExpTests.String_Match_NoMatch_ReturnsNull;
begin
  const Result = FEngine.Evaluate('"hello".match(/xyz/)');
  Assert.IsTrue(Result.IsNull);
end;

procedure TRegExpTests.String_Replace_WithRegExp;
begin
  const Result = FEngine.Evaluate('"hello world".replace(/world/, "there")');
  Assert.AreEqual('hello there', Result.AsString);
end;

procedure TRegExpTests.String_Replace_GlobalRegExp;
begin
  const Result = FEngine.Evaluate('"cat bat rat".replace(/at/g, "ot")');
  Assert.AreEqual('cot bot rot', Result.AsString);
end;

procedure TRegExpTests.String_Search_ReturnsIndex;
begin
  const Result = FEngine.Evaluate('"hello world".search(/world/)');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

procedure TRegExpTests.String_Search_NoMatch_ReturnsMinusOne;
begin
  const Result = FEngine.Evaluate('"hello".search(/xyz/)');
  Assert.AreEqual(Double(-1), Result.AsNumber);
end;

procedure TRegExpTests.String_Split_WithRegExp;
begin
  const Result = FEngine.Evaluate('"a1b2c3".split(/\d/).join(",")');
  Assert.AreEqual('a,b,c,', Result.AsString);
end;

procedure TRegExpTests.RegExp_Source_Property;
begin
  const Result = FEngine.Evaluate('/hello/.source');
  Assert.AreEqual('hello', Result.AsString);
end;

procedure TRegExpTests.RegExp_Flags_Properties;
begin
  FEngine.Execute('var re = /test/gi;');

  const Global = FEngine.Evaluate('re.global');
  Assert.IsTrue(Global.AsBoolean);

  const IgnoreCase = FEngine.Evaluate('re.ignoreCase');
  Assert.IsTrue(IgnoreCase.AsBoolean);

  const Multiline = FEngine.Evaluate('re.multiline');
  Assert.IsFalse(Multiline.AsBoolean);
end;

procedure TRegExpTests.RegExp_Literal_Syntax;
begin
  FEngine.Execute('var re = /[a-z]+/;');
  const Result = FEngine.Evaluate('re.test("hello")');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TDateMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TDateMethodsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TDateMethodsTests.Date_Now_ReturnsTimestamp;
begin
  const Result = FEngine.Evaluate('Date.now()');
  Assert.IsTrue(Result.AsNumber > 0);
end;

procedure TDateMethodsTests.Date_Constructor_NoArgs;
begin
  FEngine.Execute('var d = new Date();');
  const Result = FEngine.Evaluate('d.getTime()');
  Assert.IsTrue(Result.AsNumber > 0);
end;

procedure TDateMethodsTests.Date_Constructor_WithTimestamp;
begin
  FEngine.Execute('var d = new Date(0);');
  const Result = FEngine.Evaluate('d.getTime()');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_Constructor_WithComponents;
begin
  FEngine.Execute('var d = new Date(2024, 0, 15, 10, 30, 45);');
  const Year = FEngine.Evaluate('d.getFullYear()');
  Assert.AreEqual(Double(2024), Year.AsNumber);

  const Month = FEngine.Evaluate('d.getMonth()');
  Assert.AreEqual(Double(0), Month.AsNumber);

  const Day = FEngine.Evaluate('d.getDate()');
  Assert.AreEqual(Double(15), Day.AsNumber);
end;

procedure TDateMethodsTests.Date_GetFullYear_ReturnsYear;
begin
  FEngine.Execute('var d = new Date(2024, 5, 15);');
  const Result = FEngine.Evaluate('d.getFullYear()');
  Assert.AreEqual(Double(2024), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetMonth_ReturnsMonth;
begin
  FEngine.Execute('var d = new Date(2024, 5, 15);');
  const Result = FEngine.Evaluate('d.getMonth()');
  Assert.AreEqual(Double(5), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetDate_ReturnsDay;
begin
  FEngine.Execute('var d = new Date(2024, 5, 15);');
  const Result = FEngine.Evaluate('d.getDate()');
  Assert.AreEqual(Double(15), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetDay_ReturnsDayOfWeek;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1);');
  const Result = FEngine.Evaluate('d.getDay()');
  Assert.IsTrue((Result.AsNumber >= 0) and (Result.AsNumber <= 6));
end;

procedure TDateMethodsTests.Date_GetHours_ReturnsHours;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 14, 30, 0);');
  const Result = FEngine.Evaluate('d.getHours()');
  Assert.AreEqual(Double(14), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetMinutes_ReturnsMinutes;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 14, 30, 0);');
  const Result = FEngine.Evaluate('d.getMinutes()');
  Assert.AreEqual(Double(30), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetSeconds_ReturnsSeconds;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 14, 30, 45);');
  const Result = FEngine.Evaluate('d.getSeconds()');
  Assert.AreEqual(Double(45), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetMilliseconds_ReturnsMs;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 14, 30, 45, 123);');
  const Result = FEngine.Evaluate('d.getMilliseconds()');
  Assert.AreEqual(Double(123), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetTime_ReturnsTimestamp;
begin
  FEngine.Execute('var d = new Date(0);');
  const Result = FEngine.Evaluate('d.getTime()');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetFullYear_SetsYear;
begin
  FEngine.Execute('var d = new Date(2020, 0, 1); d.setFullYear(2025);');
  const Result = FEngine.Evaluate('d.getFullYear()');
  Assert.AreEqual(Double(2025), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetMonth_SetsMonth;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1); d.setMonth(6);');
  const Result = FEngine.Evaluate('d.getMonth()');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetDate_SetsDay;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1); d.setDate(20);');
  const Result = FEngine.Evaluate('d.getDate()');
  Assert.AreEqual(Double(20), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetHours_SetsHours;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 0, 0, 0); d.setHours(15);');
  const Result = FEngine.Evaluate('d.getHours()');
  Assert.AreEqual(Double(15), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetMinutes_SetsMinutes;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 0, 0, 0); d.setMinutes(45);');
  const Result = FEngine.Evaluate('d.getMinutes()');
  Assert.AreEqual(Double(45), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_SetSeconds_SetsSeconds;
begin
  FEngine.Execute('var d = new Date(2024, 0, 1, 0, 0, 0); d.setSeconds(30);');
  const Result = FEngine.Evaluate('d.getSeconds()');
  Assert.AreEqual(Double(30), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_ToISOString_FormatsCorrectly;
begin
  FEngine.Execute('var d = new Date(0);');
  const Result = FEngine.Evaluate('d.toISOString()');
  Assert.AreEqual('1970-01-01T00:00:00.000Z', Result.AsString);
end;

procedure TDateMethodsTests.Date_ToDateString_FormatsCorrectly;
begin
  FEngine.Execute('var d = new Date(2024, 0, 15);');
  const Result = FEngine.Evaluate('d.toDateString()');
  Assert.IsTrue(Length(Result.AsString) > 0);
end;

procedure TDateMethodsTests.Date_ToTimeString_FormatsCorrectly;
begin
  FEngine.Execute('var d = new Date(2024, 0, 15, 14, 30, 45);');
  const Result = FEngine.Evaluate('d.toTimeString()');
  Assert.IsTrue(Length(Result.AsString) > 0);
end;

procedure TDateMethodsTests.Date_Parse_ParsesISOString;
begin
  const Result = FEngine.Evaluate('Date.parse("1970-01-01T00:00:00.000Z")');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_UTC_ReturnsTimestamp;
begin
  const Result = FEngine.Evaluate('Date.UTC(1970, 0, 1, 0, 0, 0, 0)');
  Assert.AreEqual(Double(0), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetUTCFullYear_ReturnsUTCYear;
begin
  FEngine.Execute('var d = new Date(Date.UTC(2024, 5, 15));');
  const Result = FEngine.Evaluate('d.getUTCFullYear()');
  Assert.AreEqual(Double(2024), Result.AsNumber);
end;

procedure TDateMethodsTests.Date_GetTimezoneOffset_ReturnsOffset;
begin
  FEngine.Execute('var d = new Date();');
  const Result = FEngine.Evaluate('d.getTimezoneOffset()');
  Assert.IsTrue(Result.IsNumber);
end;

procedure TErrorConstructorTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TErrorConstructorTests.TearDown;
begin
  FEngine.Free;
end;

procedure TErrorConstructorTests.Error_Constructor_CreatesError;
begin
  FEngine.Execute('var e = new Error("test message");');
  const Result = FEngine.Evaluate('e instanceof Error');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TErrorConstructorTests.Error_Message_Property;
begin
  FEngine.Execute('var e = new Error("test message");');
  const Result = FEngine.Evaluate('e.message');
  Assert.AreEqual('test message', Result.AsString);
end;

procedure TErrorConstructorTests.Error_Name_Property;
begin
  FEngine.Execute('var e = new Error("test");');
  const Result = FEngine.Evaluate('e.name');
  Assert.AreEqual('Error', Result.AsString);
end;

procedure TErrorConstructorTests.TypeError_Constructor;
begin
  FEngine.Execute('var e = new TypeError("type error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('TypeError', Name.AsString);

  const Msg = FEngine.Evaluate('e.message');
  Assert.AreEqual('type error', Msg.AsString);
end;

procedure TErrorConstructorTests.RangeError_Constructor;
begin
  FEngine.Execute('var e = new RangeError("range error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('RangeError', Name.AsString);
end;

procedure TErrorConstructorTests.ReferenceError_Constructor;
begin
  FEngine.Execute('var e = new ReferenceError("ref error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('ReferenceError', Name.AsString);
end;

procedure TErrorConstructorTests.SyntaxError_Constructor;
begin
  FEngine.Execute('var e = new SyntaxError("syntax error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('SyntaxError', Name.AsString);
end;

procedure TErrorConstructorTests.URIError_Constructor;
begin
  FEngine.Execute('var e = new URIError("uri error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('URIError', Name.AsString);
end;

procedure TErrorConstructorTests.EvalError_Constructor;
begin
  FEngine.Execute('var e = new EvalError("eval error");');

  const Name = FEngine.Evaluate('e.name');
  Assert.AreEqual('EvalError', Name.AsString);
end;

procedure TErrorConstructorTests.Error_ToString_FormatsCorrectly;
begin
  FEngine.Execute('var e = new Error("test");');
  const Result = FEngine.Evaluate('e.toString()');
  Assert.AreEqual('Error: test', Result.AsString);
end;

procedure TErrorConstructorTests.Throw_Error_CanBeCaught;
begin
  FEngine.Execute('var caught = null; try { throw new Error("caught!"); } catch (e) { caught = e.message; }');
  const Result = FEngine.GetVariable('caught');
  Assert.AreEqual('caught!', Result.AsString);
end;

procedure TErrorConstructorTests.Throw_TypeError_CanBeCaught;
begin
  FEngine.Execute('var errName = null; try { throw new TypeError("type!"); } catch (e) { errName = e.name; }');
  const Result = FEngine.GetVariable('errName');
  Assert.AreEqual('TypeError', Result.AsString);
end;

procedure TErrorConstructorTests.Error_InstanceOf_Error;
begin
  const Result = FEngine.Evaluate('(new Error()) instanceof Error');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TErrorConstructorTests.TypeError_InstanceOf_Error;
begin
  const Result = FEngine.Evaluate('(new TypeError()) instanceof Error');
  Assert.IsTrue(Result.AsBoolean);
end;

procedure TErrorConstructorTests.Error_Stack_Property;
begin
  FEngine.Execute('var e = new Error("test");');
  const Result = FEngine.Evaluate('typeof e.stack');
  Assert.AreEqual('string', Result.AsString);
end;

procedure TStrictModeTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TStrictModeTests.TearDown;
begin
  FEngine.Free;
end;

procedure TStrictModeTests.StrictMode_UndeclaredVariable_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; x = 10;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_DeleteUndeletable_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; delete Object.prototype;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_DuplicateParams_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; function f(a, a) { return a; }');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_OctalLiteral_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; var x = 010;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_WithStatement_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; var obj = {}; with (obj) { }');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_EvalArguments_ReadOnly;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; eval = 10;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_ThisInFunction_IsUndefined;
begin
  FEngine.Execute('"use strict"; function f() { return this; } var result = f();');
  const Result = FEngine.GetVariable('result');
  Assert.IsTrue(Result.IsUndefined);
end;

procedure TStrictModeTests.StrictMode_FunctionScoped;
begin
  FEngine.Execute('var globalThis; function strict() { "use strict"; return this; } function nonStrict() { return this; }');
  FEngine.Execute('var strictResult = strict();');
  FEngine.Execute('var nonStrictResult = nonStrict();');

  const StrictResult = FEngine.GetVariable('strictResult');
  Assert.IsTrue(StrictResult.IsUndefined);

  const NonStrictResult = FEngine.GetVariable('nonStrictResult');
  Assert.IsFalse(NonStrictResult.IsUndefined);
end;

procedure TStrictModeTests.NonStrictMode_UndeclaredVariable_Allowed;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('y = 20;');
    const Result = FEngine.GetVariable('y');
    Assert.AreEqual(Double(20), Result.AsNumber);
  except
    ErrorThrown := True;
  end;
  Assert.IsFalse(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_DeleteVariable_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; var x = 1; delete x;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TStrictModeTests.StrictMode_ReservedWords_ThrowsError;
begin
  var ErrorThrown := False;
  try
    FEngine.Execute('"use strict"; var implements = 1;');
  except
    ErrorThrown := True;
  end;
  Assert.IsTrue(ErrorThrown);
end;

procedure TFunctionMethodsTests.Setup;
begin
  FEngine := TJSEngine.Create;
end;

procedure TFunctionMethodsTests.TearDown;
begin
  FEngine.Free;
end;

procedure TFunctionMethodsTests.Function_Call_SetsThisContext;
begin
  FEngine.Execute('var obj = { value: 42 }; function f() { return this.value; }');
  const Result = FEngine.Evaluate('f.call(obj)');
  Assert.AreEqual(Double(42), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Call_PassesArguments;
begin
  FEngine.Execute('function add(a, b) { return this.x + a + b; }');
  const Result = FEngine.Evaluate('add.call({x: 10}, 20, 30)');
  Assert.AreEqual(Double(60), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Call_NullThis_UsesGlobal;
begin
  FEngine.Execute('"use strict"; function f() { return this; }');
  const Result = FEngine.Evaluate('f.call(null)');
  Assert.IsTrue(Result.IsNull or Result.IsUndefined);
end;

procedure TFunctionMethodsTests.Function_Apply_SetsThisContext;
begin
  FEngine.Execute('var obj = { value: 100 }; function f() { return this.value; }');
  const Result = FEngine.Evaluate('f.apply(obj)');
  Assert.AreEqual(Double(100), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Apply_PassesArrayAsArguments;
begin
  FEngine.Execute('function sum(a, b, c) { return a + b + c; }');
  const Result = FEngine.Evaluate('sum.apply(null, [1, 2, 3])');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Apply_EmptyArray;
begin
  FEngine.Execute('function f() { return 42; }');
  const Result = FEngine.Evaluate('f.apply(null, [])');
  Assert.AreEqual(Double(42), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Bind_ReturnsNewFunction;
begin
  FEngine.Execute('var obj = { x: 5 }; function f() { return this.x; } var g = f.bind(obj);');
  const Result = FEngine.Evaluate('g()');
  Assert.AreEqual(Double(5), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Bind_PartialApplication;
begin
  FEngine.Execute('function add(a, b) { return a + b; } var add10 = add.bind(null, 10);');
  const Result = FEngine.Evaluate('add10(5)');
  Assert.AreEqual(Double(15), Result.AsNumber);
end;

procedure TFunctionMethodsTests.Function_Bind_ChainedBind;
begin
  FEngine.Execute('function f(a, b, c) { return a + b + c; } var g = f.bind(null, 1).bind(null, 2);');
  const Result = FEngine.Evaluate('g(3)');
  Assert.AreEqual(Double(6), Result.AsNumber);
end;

initialization
  TDUnitX.RegisterTestFixture(TArrayMethodsTests);
  TDUnitX.RegisterTestFixture(TStringMethodsTests);
  TDUnitX.RegisterTestFixture(TObjectMethodsTests);
  TDUnitX.RegisterTestFixture(TJSONTests);
  TDUnitX.RegisterTestFixture(TGlobalFunctionsTests);
  TDUnitX.RegisterTestFixture(TRegExpTests);
  TDUnitX.RegisterTestFixture(TDateMethodsTests);
  TDUnitX.RegisterTestFixture(TErrorConstructorTests);
  TDUnitX.RegisterTestFixture(TStrictModeTests);
  TDUnitX.RegisterTestFixture(TFunctionMethodsTests);

end.
