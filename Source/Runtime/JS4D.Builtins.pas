unit JS4D.Builtins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.RegularExpressions,
  System.Character,
  JS4D.Types,
  JS4D.PropertyNames,
  JS4D.ArrayObject,
  JS4D.ArrayLike,
  JS4D.UnicodeNormalization;

type
  TJSBuiltins = class
  private
    type
      TArrayMethod = (Push, Pop, Shift, Unshift, IndexOf, LastIndexOf, Join, Slice, Splice, Concat, Reverse,
                      Includes, Fill, CopyWithin, ToText, Flat, Map, Filter, ForEach, Reduce, ReduceRight, Some,
                      Every, Find, FindIndex, Sort, At, FlatMap);

      TStringMethod = (CharAt, CharCodeAt, IndexOf, LastIndexOf, Substring, Substr, Slice, ToLowerCase,
                       ToUpperCase, Trim, TrimStart, TrimLeft, TrimEnd, TrimRight, Concat, Repeat_, StartsWith,
                       EndsWith, Includes, PadStart, PadEnd, ToText, ValueOf, ToLocaleLowerCase,
                       ToLocaleUpperCase, LocaleCompare, CodePointAt, Normalize, At);

      TNumberMethod = (ToText, ToFixed, ToPrecision, ToExponential, ValueOf);

    const
      ARRAY_METHOD_NAMES: array[TArrayMethod] of string = (
        METHOD_PUSH, METHOD_POP, METHOD_SHIFT, METHOD_UNSHIFT, METHOD_INDEX_OF, METHOD_LAST_INDEX_OF,
        JOIN_METHOD, METHOD_SLICE, METHOD_SPLICE, METHOD_CONCAT, METHOD_REVERSE, METHOD_INCLUDES,
        METHOD_FILL, METHOD_COPY_WITHIN, TO_STRING_METHOD, METHOD_FLAT, METHOD_MAP, METHOD_FILTER,
        METHOD_FOR_EACH, METHOD_REDUCE, METHOD_REDUCE_RIGHT, METHOD_SOME, METHOD_EVERY, METHOD_FIND,
        METHOD_FIND_INDEX, METHOD_SORT, METHOD_AT, METHOD_FLAT_MAP);

      STRING_METHOD_NAMES: array[TStringMethod] of string = (
        'charAt', 'charCodeAt', METHOD_INDEX_OF, METHOD_LAST_INDEX_OF, 'substring',
        'substr', METHOD_SLICE, 'toLowerCase', 'toUpperCase', 'trim',
        'trimStart', 'trimLeft', 'trimEnd', 'trimRight',
        METHOD_CONCAT, 'repeat', METHOD_STARTS_WITH, METHOD_ENDS_WITH,
        METHOD_INCLUDES, 'padStart', 'padEnd', TO_STRING_METHOD, VALUE_OF_METHOD,
        'toLocaleLowerCase', 'toLocaleUpperCase', 'localeCompare',
        'codePointAt', 'normalize', METHOD_AT);

      NUMBER_METHOD_NAMES: array[TNumberMethod] of string = (
        TO_STRING_METHOD, 'toFixed', 'toPrecision', 'toExponential', VALUE_OF_METHOD);

      OBJECT_METHOD_NAMES: array[0..1] of string = ('hasOwnProperty', 'propertyIsEnumerable');

      LIMITED_STRING_METHODS = [TStringMethod.IndexOf, TStringMethod.LastIndexOf, TStringMethod.Concat,
                                TStringMethod.Repeat_, TStringMethod.StartsWith, TStringMethod.EndsWith,
                                TStringMethod.Includes, TStringMethod.PadStart, TStringMethod.PadEnd];

      CALLBACK_ARRAY_METHODS = [TArrayMethod.Map, TArrayMethod.Filter, TArrayMethod.ForEach, TArrayMethod.Reduce,
                                TArrayMethod.ReduceRight, TArrayMethod.Some, TArrayMethod.Every, TArrayMethod.Sort];
      CALLBACK_THIS_ARRAY_METHODS = [TArrayMethod.Map, TArrayMethod.Filter, TArrayMethod.ForEach, TArrayMethod.Some,
                                     TArrayMethod.Every, TArrayMethod.Find, TArrayMethod.FindIndex,
                                     TArrayMethod.FlatMap];

    class function CallLimitedStringMethod(const Method: TStringMethod; const Text: string;
                                           const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function TryFindArrayMethod(const MethodName: string; out Method: TArrayMethod): Boolean; static;
    class function TryFindStringMethod(const MethodName: string; out Method: TStringMethod): Boolean; static;
    class function TryFindNumberMethod(const MethodName: string; out Method: TNumberMethod): Boolean; static;
    class function CopyNames(const Names: array of string): TArray<string>; static;
    class function PadString(const Text: string; const Args: TArray<TJSValue>; const Limits: TJSLimits;
                             const PadsAtStart: Boolean): TJSValue; static;
    class function ArrayPush(const Elements: IJSArray; const Args: TArray<TJSValue>;
                             const Limits: TJSLimits): TJSValue; static;
    class function ArrayPop(const Elements: IJSArray): TJSValue; static;
    class function ArrayShift(const Elements: IJSArray): TJSValue; static;
    class function ArrayUnshift(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                const Limits: TJSLimits): TJSValue; static;
    class function ArrayJoin(const Elements: IJSArray; const Args: TArray<TJSValue>;
                             const Limits: TJSLimits): TJSValue; static;
    class function ArraySlice(const Elements: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArraySplice(const Elements: IJSArray; const Args: TArray<TJSValue>;
                               const Limits: TJSLimits): TJSValue; static;
    class function ArrayConcat(const Elements: IJSArray; const Args: TArray<TJSValue>;
                               const Limits: TJSLimits): TJSValue; static;
    class function ArrayReverse(const Elements: IJSArray): TJSValue; static;
    class function ItemsToInsert(const Args: TArray<TJSValue>): TArray<TJSValue>; static;
    class procedure ResizeForSplice(const Elements: IJSArray; const StartIndex, DeleteCount, InsertCount: Integer;
                                    const Limits: TJSLimits); static;
    class procedure CopyElementsTo(const Source: IJSArray; const Target: IJSArray); static;
    class function ConcatLength(const Elements: IJSArray; const Args: TArray<TJSValue>): Int64; static;
    class procedure MergeRemainingRun(const Elements, Buffer: TArray<TJSValue>; const RunStart, RunEnd: Integer;
                                      const TargetStart: Integer); static;
    class function LastPositionOf(const SearchText, Text: string): Integer; static;
    class function RepeatText(const Text: string; const Count: Integer): string; static;
    class function SpecialNumberText(const Number: Double): string; static;
    class function ArrayToString(const Elements: IJSArray; const Limits: TJSLimits): TJSValue; static;

    class function ArraySort(const Elements: IJSArray; const Args: TArray<TJSValue>;
                             const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue; static;
    class function CompareSortValues(const Left, Right: TJSValue; const Comparer: IJSFunction;
                                     const Executor: TJSCallbackExecutor; const Limits: TJSLimits): Double; static;
    class function CollectDefinedElements(const Elements: IJSArray): TArray<TJSValue>; static;
    class procedure MergeSortedRuns(const Elements, Buffer: TArray<TJSValue>; const First, Middle, Last: Integer;
                                    const Comparer: IJSFunction; const Executor: TJSCallbackExecutor;
                                    const Limits: TJSLimits); static;
    class procedure MergeSortRange(const Elements, Buffer: TArray<TJSValue>; const First, Last: Integer;
                                   const Comparer: IJSFunction; const Executor: TJSCallbackExecutor;
                                   const Limits: TJSLimits); static;

    class function IntegerArgument(const Args: TArray<TJSValue>; const Index: Integer): Double; static;
    class function ClampedPositionArgument(const Args: TArray<TJSValue>; const Index: Integer;
                                           const Count: Integer): Integer; static;
    class function ClampPosition(const Position: Double; const Count: Integer): Integer; static;
    class function EndPosition(const Args: TArray<TJSValue>; const Index: Integer;
                               const Count: Integer): Double; static;
    class function StringCharAt(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringCharCodeAt(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringCodePointAt(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringNormalize(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringIndexOf(const Text: string; const Args: TArray<TJSValue>;
                                 const Limits: TJSLimits): TJSValue; static;
    class function StringLastIndexOf(const Text: string; const Args: TArray<TJSValue>;
                                     const Limits: TJSLimits): TJSValue; static;
    class function StringSubstring(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSubstr(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSlice(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToLowerCase(const Text: string): TJSValue; static;
    class function StringToUpperCase(const Text: string): TJSValue; static;
    class function StringLocaleCompare(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrim(const Text: string): TJSValue; static;
    class function StringTrimStart(const Text: string): TJSValue; static;
    class function StringTrimEnd(const Text: string): TJSValue; static;
    class function BuildPadding(const PadStr: string; const PadLength: Integer): string; static;
    class function StringConcat(const Text: string; const Args: TArray<TJSValue>;
                                const Limits: TJSLimits): TJSValue; static;
    class function StringRepeat(const Text: string; const Args: TArray<TJSValue>;
                                const Limits: TJSLimits): TJSValue; static;
    class function StringStartsWith(const Text: string; const Args: TArray<TJSValue>;
                                    const Limits: TJSLimits): TJSValue; static;
    class function StringEndsWith(const Text: string; const Args: TArray<TJSValue>;
                                  const Limits: TJSLimits): TJSValue; static;
    class function StringIncludes(const Text: string; const Args: TArray<TJSValue>;
                                  const Limits: TJSLimits): TJSValue; static;
    class function StringAt(const Text: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToString(const Text: string): TJSValue; static;
    class function StringValueOf(const Text: string): TJSValue; static;

    class function NumberToString(const Number: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function RadixArgument(const Argument: TJSValue): Integer; static;
    class function DigitCountArgument(const Args: TArray<TJSValue>): Integer; static;
    class function HasDigitCountArgument(const Args: TArray<TJSValue>): Boolean; static;
    class function DigitCountOrDefault(const Args: TArray<TJSValue>): Integer; static;
    class function DigitsInRadix(const Magnitude: Int64; const Radix: Integer): string; static;
    class function NumberToFixed(const Number: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToPrecision(const Number: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToExponential(const Number: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberValueOf(const Number: Double): TJSValue; static;

  public
    class function CallArrayMethod(const Elements: IJSArray; const MethodName: string; const Args: TArray<TJSValue>;
                                   const Limits: TJSLimits): TJSValue; static;
    class function CallArrayMethodWithCallback(const Elements: IJSArray; const MethodName: string;
                                               const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                               const Limits: TJSLimits): TJSValue; static;
    class function CallStringMethod(const Text: string; const MethodName: string; const Args: TArray<TJSValue>;
                                    const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue; static;
    class function CallNumberMethod(const Number: Double; const MethodName: string;
                                    const Args: TArray<TJSValue>): TJSValue; static;

    class function HasArrayMethod(const MethodName: string): Boolean; static;
    class function HasStringMethod(const MethodName: string): Boolean; static;
    class function IsNumericStringArgument(const MethodName: string; const Index: Integer): Boolean; static;
    class function HasNumberMethod(const MethodName: string): Boolean; static;
    class function HasFunctionMethod(const MethodName: string): Boolean; static;
    class function HasObjectMethod(const MethodName: string): Boolean; static;

    class function ArrayMethodNames: TArray<string>; static;
    class function StringMethodNames: TArray<string>; static;
    class function NumberMethodNames: TArray<string>; static;
    class function ObjectMethodNames: TArray<string>; static;

    class function CallObjectMethod(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                                    const Limits: TJSLimits): TJSValue; static;

    class function RequiresCallback(const MethodName: string): Boolean; static;
    class function TakesCallbackThis(const MethodName: string): Boolean; static;

    class function IsArrayMethod(const MethodName: string): Boolean; static;
    class function IsStringMethod(const MethodName: string): Boolean; static;
    class function IsNumberMethod(const MethodName: string): Boolean; static;
  end;

implementation

uses
  JS4D.Utf16,
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.CaseMapping,
  JS4D.ObjectOperations,
  JS4D.NumberFormat,
  JS4D.NumberText,
  JS4D.JsWhiteSpace;

const
  DIGIT_COUNT_LIMIT = 1000;
  DEFAULT_RADIX = 10;
  RADIX_DIGITS = '0123456789abcdefghijklmnopqrstuvwxyz';
  ZERO_DIGIT = '0';
  NEGATIVE_NUMBER_FORMAT = '-%s';
  MIN_RADIX = 2;
  MAX_RADIX = 36;
  RADIX_RANGE_MESSAGE = 'toString() radix must be between 2 and 36';
  TO_FIXED_RANGE_MESSAGE = 'toFixed() digits argument must be between 0 and 100';
  TO_PRECISION_RANGE_MESSAGE = 'toPrecision() argument must be between 1 and 100';
  TO_EXPONENTIAL_RANGE_MESSAGE = 'toExponential() argument must be between 0 and 100';
  INVALID_NORMALIZATION_FORM_MESSAGE = 'The normalization form should be one of NFC, NFD, NFKC, NFKD';
  INVALID_REPEAT_COUNT_MESSAGE = 'Invalid count value for String.prototype.repeat';
  EMPTY_STRING: string = '';
  DEFAULT_NORMALIZATION_FORM = 'NFC';
  SPACE_CHAR: string = ' ';

class function TJSBuiltins.ArrayPush(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                     const Limits: TJSLimits): TJSValue;
begin
  const ArgsLength = Length(Args);

  Limits.EnsureArrayLength(Int64(Elements.Length) + ArgsLength);

  for var Arg in Args do
  begin
    Elements.Push(Arg);
  end;

  Result := TJSValue.CreateNumber(Elements.Length);
end;

class function TJSBuiltins.ArrayPop(const Elements: IJSArray): TJSValue;
begin
  Result := Elements.Pop;
end;

class function TJSBuiltins.ArrayShift(const Elements: IJSArray): TJSValue;
begin
  const IsEmpty = (Elements.Length = 0);
  if IsEmpty then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := Elements[0];

  for var Index := 0 to Elements.Length - 2 do
  begin
    Elements[Index] := Elements[Index + 1];
  end;

  Elements.Pop;
end;

class function TJSBuiltins.ArrayUnshift(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                        const Limits: TJSLimits): TJSValue;
begin
  const OriginalLength = Elements.Length;
  const ArgsLength = Length(Args);

  Limits.EnsureArrayLength(Int64(OriginalLength) + ArgsLength);

  for var Index := 0 to ArgsLength - 1 do
  begin
    Elements.Push(TJSValue.CreateUndefined);
  end;

  for var Index := OriginalLength - 1 downto 0 do
  begin
    Elements[Index + ArgsLength] := Elements[Index];
  end;

  for var Index := 0 to ArgsLength - 1 do
  begin
    Elements[Index] := Args[Index];
  end;

  Result := TJSValue.CreateNumber(Elements.Length);
end;

class function TJSBuiltins.ArrayJoin(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                     const Limits: TJSLimits): TJSValue;
begin
  var Separator: string := ARRAY_SEPARATOR;

  const SeparatorArgument = TJSArrayLike.Argument(Args, 0);
  if not SeparatorArgument.IsUndefined then
    Separator := SeparatorArgument.ToLimitedString(Limits);

  const StringBuilder = TStringBuilder.Create;
  try
    for var Index := 0 to Elements.Length - 1 do
    begin
      const Element = Elements[Index];
      var ElementText := EMPTY_STRING;

      if not Element.IsNullOrUndefined then
        ElementText := Element.ToLimitedString(Limits);

      const NeedsSeparator = (Index > 0);
      var AddedLength := Length(ElementText);
      if NeedsSeparator then
        Inc(AddedLength, Length(Separator));

      Limits.EnsureStringLength(Int64(StringBuilder.Length) + AddedLength);

      if NeedsSeparator then
        StringBuilder.Append(Separator);

      StringBuilder.Append(ElementText);
    end;

    Result := TJSValue.CreateString(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.ArraySlice(const Elements: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const NewArr: IJSArray = TJSArray.Create;

  const Count = Int64(Elements.Length);
  const StartIndex = TJSArrayLike.RelativeIndexArgument(Args, 0, Count, 0);
  const EndIndex = TJSArrayLike.RelativeIndexArgument(Args, 1, Count, Count);

  for var Index := StartIndex to EndIndex - 1 do
  begin
    NewArr.Push(Elements[Integer(Index)]);
  end;

  Result := TJSValue.CreateObject(NewArr);
end;

class function TJSBuiltins.ItemsToInsert(const Args: TArray<TJSValue>): TArray<TJSValue>;
begin
  const HasItems = (Length(Args) > 2);
  if HasItems then
    Result := Copy(Args, 2, Length(Args) - 2)
  else
    Result := nil;
end;

class procedure TJSBuiltins.ResizeForSplice(const Elements: IJSArray; const StartIndex, DeleteCount,
                                            InsertCount: Integer; const Limits: TJSLimits);
begin
  const Diff = InsertCount - DeleteCount;

  Limits.EnsureArrayLength(Int64(Elements.Length) + Diff);

  const GrowsArray = (Diff > 0);
  const ShrinksArray = (Diff < 0);
  if GrowsArray then
  begin
    for var Index := 0 to Diff - 1 do
    begin
      Elements.Push(TJSValue.CreateUndefined);
    end;

    for var Index := Elements.Length - 1 - Diff downto StartIndex + DeleteCount do
    begin
      Elements[Index + Diff] := Elements[Index];
    end;
  end
  else if ShrinksArray then
  begin
    for var Index := StartIndex + DeleteCount to Elements.Length - 1 do
    begin
      Elements[Index + Diff] := Elements[Index];
    end;

    for var Index := 0 to -Diff - 1 do
    begin
      Elements.Pop;
    end;
  end;
end;

class function TJSBuiltins.ArraySplice(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                       const Limits: TJSLimits): TJSValue;
begin
  const Removed: IJSArray = TJSArray.Create;

  const HasNoArguments = (Length(Args) = 0);
  if HasNoArguments then
  begin
    Result := TJSValue.CreateObject(Removed);
    Exit;
  end;

  const StartIndex = Integer(TJSArrayLike.RelativeIndex(Args[0], Elements.Length, 0));
  const DeleteCount = Integer(TJSArrayLike.SpliceDeleteCount(Args, Elements.Length, StartIndex));

  for var Index := 0 to DeleteCount - 1 do
  begin
    Removed.Push(Elements[StartIndex + Index]);
  end;

  const Items = ItemsToInsert(Args);
  ResizeForSplice(Elements, StartIndex, DeleteCount, Length(Items), Limits);

  for var Index := 0 to High(Items) do
  begin
    Elements[StartIndex + Index] := Items[Index];
  end;

  Result := TJSValue.CreateObject(Removed);
end;

class function TJSBuiltins.ConcatLength(const Elements: IJSArray; const Args: TArray<TJSValue>): Int64;
begin
  Result := Elements.Length;

  for var Arg in Args do
  begin
    var Source: IJSArray;
    if Arg.IsArray and Supports(Arg.ToObject, IJSArray, Source) then
      Inc(Result, Source.Length)
    else
      Inc(Result);
  end;
end;

class procedure TJSBuiltins.CopyElementsTo(const Source: IJSArray; const Target: IJSArray);
begin
  for var Element in Source do
  begin
    Target.Push(Element);
  end;
end;

class function TJSBuiltins.ArrayConcat(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                       const Limits: TJSLimits): TJSValue;
begin
  const TotalLength = ConcatLength(Elements, Args);
  Limits.EnsureArrayLength(TotalLength);

  const Combined: IJSArray = TJSArray.Create;
  CopyElementsTo(Elements, Combined);

  for var Arg in Args do
  begin
    if not Arg.IsArray then
    begin
      Combined.Push(Arg);
      Continue;
    end;

    var OtherElements: IJSArray;
    if Supports(Arg.ToObject, IJSArray, OtherElements) then
      CopyElementsTo(OtherElements, Combined);
  end;

  Result := TJSValue.CreateObject(Combined);
end;

class function TJSBuiltins.ArrayReverse(const Elements: IJSArray): TJSValue;
begin
  const HalfLength = Elements.Length div 2;

  for var Index := 0 to HalfLength - 1 do
  begin
    const Temp = Elements[Index];
    const MirrorIndex = Elements.Length - 1 - Index;
    Elements[Index] := Elements[MirrorIndex];
    Elements[MirrorIndex] := Temp;
  end;

  Result := TJSValue.CreateObject(Elements);
end;

class function TJSBuiltins.ArrayToString(const Elements: IJSArray; const Limits: TJSLimits): TJSValue;
begin
  Result := ArrayJoin(Elements, [], Limits);
end;

class function TJSBuiltins.CompareSortValues(const Left, Right: TJSValue; const Comparer: IJSFunction;
                                             const Executor: TJSCallbackExecutor; const Limits: TJSLimits): Double;
begin
  if Assigned(Comparer) then
  begin
    const CallbackArgs: TArray<TJSValue> = [Left, Right];
    Result := Executor(Comparer, CallbackArgs).ToNumber;
    Exit;
  end;

  const LeftText = Left.ToLimitedString(Limits);
  const RightText = Right.ToLimitedString(Limits);

  Result := Sign(CompareStr(LeftText, RightText));
end;

class function TJSBuiltins.CollectDefinedElements(const Elements: IJSArray): TArray<TJSValue>;
begin
  SetLength(Result, Elements.Length);

  var DefinedCount := 0;

  for var Index := 0 to Elements.Length - 1 do
  begin
    const Element = Elements[Index];

    if not Element.IsUndefined then
    begin
      Result[DefinedCount] := Element;
      Inc(DefinedCount);
    end;
  end;

  SetLength(Result, DefinedCount);
end;

class procedure TJSBuiltins.MergeRemainingRun(const Elements, Buffer: TArray<TJSValue>; const RunStart,
                                              RunEnd: Integer; const TargetStart: Integer);
begin
  var TargetIndex := TargetStart;
  for var Index := RunStart to RunEnd do
  begin
    Buffer[TargetIndex] := Elements[Index];
    Inc(TargetIndex);
  end;
end;

class procedure TJSBuiltins.MergeSortedRuns(const Elements, Buffer: TArray<TJSValue>; const First, Middle,
                                            Last: Integer; const Comparer: IJSFunction;
                                            const Executor: TJSCallbackExecutor; const Limits: TJSLimits);
begin
  var LeftIndex := First;
  var RightIndex := Middle + 1;
  var TargetIndex := First;

  while (LeftIndex <= Middle) and (RightIndex <= Last) do
  begin
    const Order = CompareSortValues(Elements[LeftIndex], Elements[RightIndex], Comparer, Executor, Limits);
    const RightGoesFirst = (Order > 0);

    if RightGoesFirst then
    begin
      Buffer[TargetIndex] := Elements[RightIndex];
      Inc(RightIndex);
    end
    else
    begin
      Buffer[TargetIndex] := Elements[LeftIndex];
      Inc(LeftIndex);
    end;

    Inc(TargetIndex);
  end;

  MergeRemainingRun(Elements, Buffer, LeftIndex, Middle, TargetIndex);
  Inc(TargetIndex, Middle - LeftIndex + 1);
  MergeRemainingRun(Elements, Buffer, RightIndex, Last, TargetIndex);

  for var Index := First to Last do
  begin
    Elements[Index] := Buffer[Index];
  end;
end;

class procedure TJSBuiltins.MergeSortRange(const Elements, Buffer: TArray<TJSValue>; const First, Last: Integer;
                                           const Comparer: IJSFunction; const Executor: TJSCallbackExecutor;
                                           const Limits: TJSLimits);
begin
  const IsSingleElement = (First >= Last);
  if IsSingleElement then
    Exit;

  const Middle = First + ((Last - First) div 2);

  MergeSortRange(Elements, Buffer, First, Middle, Comparer, Executor, Limits);
  MergeSortRange(Elements, Buffer, Middle + 1, Last, Comparer, Executor, Limits);
  MergeSortedRuns(Elements, Buffer, First, Middle, Last, Comparer, Executor, Limits);
end;

class function TJSBuiltins.ArraySort(const Elements: IJSArray; const Args: TArray<TJSValue>;
                                     const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue;
begin
  TJSArrayLike.RequireSortComparer(Args);

  const IsSorted = (Elements.Length <= 1);
  if IsSorted then
  begin
    Result := TJSValue.CreateObject(Elements);
    Exit;
  end;

  var Comparer: IJSFunction := nil;
  const ComparerArgument = TJSArrayLike.Argument(Args, 0);
  ComparerArgument.TryGetFunction(Comparer);

  const Defined = CollectDefinedElements(Elements);
  const DefinedCount = Length(Defined);

  var Buffer: TArray<TJSValue>;
  SetLength(Buffer, DefinedCount);

  MergeSortRange(Defined, Buffer, 0, DefinedCount - 1, Comparer, Executor, Limits);

  for var Index := 0 to Elements.Length - 1 do
  begin
    const IsDefined = (Index < DefinedCount);
    if IsDefined then
      Elements[Index] := Defined[Index]
    else
      Elements[Index] := TJSValue.CreateUndefined;
  end;

  Result := TJSValue.CreateObject(Elements);
end;

class function TJSBuiltins.IntegerArgument(const Args: TArray<TJSValue>; const Index: Integer): Double;
begin
  Result := 0;

  const HasArgument = (Index < Length(Args));
  if not HasArgument then
    Exit;

  const Number = Args[Index].ToNumber;
  if not IsNaN(Number) then
    Result := Int(Number);
end;

class function TJSBuiltins.ClampedPositionArgument(const Args: TArray<TJSValue>; const Index: Integer;
                                                   const Count: Integer): Integer;
begin
  const Requested = IntegerArgument(Args, Index);

  Result := ClampPosition(Requested, Count);
end;

class function TJSBuiltins.ClampPosition(const Position: Double; const Count: Integer): Integer;
begin
  Result := Trunc(EnsureRange(Position, 0, Count));
end;

class function TJSBuiltins.EndPosition(const Args: TArray<TJSValue>; const Index: Integer;
                                       const Count: Integer): Double;
begin
  const IsEndGiven = (Index < Length(Args)) and (not Args[Index].IsUndefined);
  if IsEndGiven then
    Result := IntegerArgument(Args, Index)
  else
    Result := Count;
end;

class function TJSBuiltins.StringCharAt(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Text));
  if IsInRange then
    Result := TJSValue.CreateString(Text[Trunc(Position) + 1])
  else
    Result := TJSValue.CreateString(EMPTY_STRING);
end;

class function TJSBuiltins.StringCharCodeAt(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Text));
  if IsInRange then
    Result := TJSValue.CreateNumber(Ord(Text[Trunc(Position) + 1]))
  else
    Result := TJSValue.CreateNaN;
end;

class function TJSBuiltins.StringCodePointAt(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Text));
  if not IsInRange then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const Index = Trunc(Position) + 1;
  var Width: Integer;
  const CodePoint = TJSUtf16.CodePointAt(Text, Index, Width);

  Result := TJSValue.CreateNumber(CodePoint);
end;

class function TJSBuiltins.StringNormalize(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var FormName := DEFAULT_NORMALIZATION_FORM;

  const HasForm = (Length(Args) > 0) and not Args[0].IsUndefined;
  if HasForm then
    FormName := Args[0].ToString;

  var Form: TJSNormalizationForm;
  if not TJSUnicodeNormalization.TryParseForm(FormName, Form) then
    raise TJSErrorFactory.RangeError(INVALID_NORMALIZATION_FORM_MESSAGE);

  Result := TJSValue.CreateString(TJSUnicodeNormalization.Normalize(Text, Form));
end;

class function TJSBuiltins.StringIndexOf(const Text: string; const Args: TArray<TJSValue>;
                                         const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = TJSArrayLike.Argument(Args, 0).ToLimitedString(Limits);
  const FromIndex = ClampedPositionArgument(Args, 1, Length(Text));

  const IsEmptySearch = (SearchStr = EMPTY_STRING);
  if IsEmptySearch then
  begin
    Result := TJSValue.CreateNumber(FromIndex);
    Exit;
  end;

  const Position = Pos(SearchStr, Text, FromIndex + 1);

  const IsFound = (Position > 0);
  if IsFound then
    Result := TJSValue.CreateNumber(Position - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.LastPositionOf(const SearchText, Text: string): Integer;
begin
  Result := 0;

  var CurrentPos := 1;
  while CurrentPos <= Length(Text) do
  begin
    const Position = Pos(SearchText, Text, CurrentPos);

    const IsMissing = (Position = 0);
    if IsMissing then
      Break;

    Result := Position;
    CurrentPos := Position + 1;
  end;
end;

class function TJSBuiltins.StringLastIndexOf(const Text: string; const Args: TArray<TJSValue>;
                                             const Limits: TJSLimits): TJSValue;
begin
  const SearchArgument = TJSArrayLike.Argument(Args, 0);
  const PositionArgument = TJSArrayLike.Argument(Args, 1);
  const SearchStr = SearchArgument.ToLimitedString(Limits);

  var StartIndex := Length(Text);
  const PositionNumber = PositionArgument.ToNumber;
  if not IsNaN(PositionNumber) then
    StartIndex := ClampPosition(Int(PositionNumber), Length(Text));

  const IsEmptySearch = (SearchStr = EMPTY_STRING);
  if IsEmptySearch then
  begin
    Result := TJSValue.CreateNumber(StartIndex);
    Exit;
  end;

  const SearchIn = Copy(Text, 1, Min(StartIndex + Length(SearchStr), Length(Text)));
  const LastPos = LastPositionOf(SearchStr, SearchIn);

  const HasMatch = (LastPos > 0);
  if HasMatch then
    Result := TJSValue.CreateNumber(LastPos - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.StringSubstring(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var StartIndex := ClampedPositionArgument(Args, 0, Length(Text));
  var EndIndex := ClampPosition(EndPosition(Args, 1, Length(Text)), Length(Text));

  const IsReversed = (StartIndex > EndIndex);
  if IsReversed then
  begin
    const Temp = StartIndex;
    StartIndex := EndIndex;
    EndIndex := Temp;
  end;

  Result := TJSValue.CreateString(Copy(Text, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringSubstr(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const TextLength = Length(Text);
  const RequestedStart = IntegerArgument(Args, 0);
  const StartIndex = Integer(TJSArrayLike.ResolveRelative(RequestedStart, TextLength));
  const RequestedLength = EndPosition(Args, 1, TextLength);
  const CharCount = ClampPosition(RequestedLength, TextLength - StartIndex);

  Result := TJSValue.CreateString(Copy(Text, StartIndex + 1, CharCount));
end;

class function TJSBuiltins.StringSlice(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const TextLength = Length(Text);
  const RequestedStart = IntegerArgument(Args, 0);
  const RequestedEnd = EndPosition(Args, 1, TextLength);
  const StartIndex = Integer(TJSArrayLike.ResolveRelative(RequestedStart, TextLength));
  const EndIndex = Integer(TJSArrayLike.ResolveRelative(RequestedEnd, TextLength));

  const IsEmptyRange = (StartIndex >= EndIndex);
  if IsEmptyRange then
    Result := TJSValue.CreateString(EMPTY_STRING)
  else
    Result := TJSValue.CreateString(Copy(Text, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringToLowerCase(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(TJSCaseMapping.ToLower(Text));
end;

class function TJSBuiltins.StringToUpperCase(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(TJSCaseMapping.ToUpper(Text));
end;

class function TJSBuiltins.StringLocaleCompare(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const OtherArgument = TJSArrayLike.Argument(Args, 0);
  const Other = OtherArgument.ToString;

  Result := TJSValue.CreateNumber(Sign(CompareStr(Text, Other)));
end;

class function TJSBuiltins.StringTrim(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(TJSWhiteSpace.TrimBoth(Text));
end;

class function TJSBuiltins.StringTrimStart(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(TJSWhiteSpace.TrimStart(Text));
end;

class function TJSBuiltins.StringTrimEnd(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(TJSWhiteSpace.TrimEnd(Text));
end;

class function TJSBuiltins.BuildPadding(const PadStr: string; const PadLength: Integer): string;
begin
  const PadStrLength = Length(PadStr);

  SetLength(Result, PadLength);

  for var Index := 1 to PadLength do
  begin
    Result[Index] := PadStr[((Index - 1) mod PadStrLength) + 1];
  end;
end;

class function TJSBuiltins.StringConcat(const Text: string; const Args: TArray<TJSValue>;
                                        const Limits: TJSLimits): TJSValue;
begin
  var StringBuilder := TStringBuilder.Create;
  try
    StringBuilder.Append(Text);

    for var Arg in Args do
    begin
      const ArgText = Arg.ToLimitedString(Limits);
      const WithArg = Int64(StringBuilder.Length) + Length(ArgText);

      Limits.EnsureStringLength(WithArg);
      StringBuilder.Append(ArgText);
    end;

    Result := TJSValue.CreateString(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.StringRepeat(const Text: string; const Args: TArray<TJSValue>;
                                        const Limits: TJSLimits): TJSValue;
begin
  const HasNoArguments = (Length(Args) = 0);
  if HasNoArguments then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

  const CountNumber = IntegerArgument(Args, 0);

  const IsInvalidCount = (CountNumber < 0) or IsInfinite(CountNumber);
  if IsInvalidCount then
    raise TJSErrorFactory.RangeError(INVALID_REPEAT_COUNT_MESSAGE);

  const Count = Trunc(CountNumber);

  const IsEmptyResult = (Count = 0) or (Text = EMPTY_STRING);
  if IsEmptyResult then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

  const RepeatedLength = Int64(Length(Text)) * Count;

  Limits.EnsureStringLength(RepeatedLength);

  Result := TJSValue.CreateString(RepeatText(Text, Count));
end;

class function TJSBuiltins.RepeatText(const Text: string; const Count: Integer): string;
begin
  const StringBuilder = TStringBuilder.Create;
  try
    for var Index := 1 to Count do
    begin
      StringBuilder.Append(Text);
    end;

    Result := StringBuilder.ToString;
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.StringStartsWith(const Text: string; const Args: TArray<TJSValue>;
                                            const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = TJSArrayLike.Argument(Args, 0).ToLimitedString(Limits);
  const Start = ClampedPositionArgument(Args, 1, Length(Text));

  const FitsInString = (Start + Length(SearchStr) <= Length(Text));

  Result := TJSValue.CreateBoolean(FitsInString and (Copy(Text, Start + 1, Length(SearchStr)) = SearchStr));
end;

class function TJSBuiltins.StringEndsWith(const Text: string; const Args: TArray<TJSValue>;
                                          const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = TJSArrayLike.Argument(Args, 0).ToLimitedString(Limits);
  const EndIndex = ClampPosition(EndPosition(Args, 1, Length(Text)), Length(Text));
  const Start = EndIndex - Length(SearchStr);

  const FitsInString = (Start >= 0);

  Result := TJSValue.CreateBoolean(FitsInString and (Copy(Text, Start + 1, Length(SearchStr)) = SearchStr));
end;

class function TJSBuiltins.StringIncludes(const Text: string; const Args: TArray<TJSValue>;
                                          const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = TJSArrayLike.Argument(Args, 0).ToLimitedString(Limits);
  const Start = ClampedPositionArgument(Args, 1, Length(Text));

  const IsFound = (SearchStr.IsEmpty or (Pos(SearchStr, Text, Start + 1) > 0));

  Result := TJSValue.CreateBoolean(IsFound);
end;

class function TJSBuiltins.StringAt(const Text: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Relative = IntegerArgument(Args, 0);

  var Position := Relative;
  const IsFromEnd = (Relative < 0);
  if IsFromEnd then
    Position := Length(Text) + Relative;

  const IsInRange = (Position >= 0) and (Position < Length(Text));
  if IsInRange then
    Result := TJSValue.CreateString(Text[Trunc(Position) + 1])
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.PadString(const Text: string; const Args: TArray<TJSValue>; const Limits: TJSLimits;
                                      const PadsAtStart: Boolean): TJSValue;
begin
  Result := TJSValue.CreateString(Text);

  const HasTargetLength = (Length(Args) > 0);
  if not HasTargetLength then
    Exit;

  const TargetLength = Trunc(Args[0].ToNumber);
  const NeedsPadding = (TargetLength > Length(Text));
  if not NeedsPadding then
    Exit;

  var PadStr := SPACE_CHAR;
  const FillerArgument = TJSArrayLike.Argument(Args, 1);
  if not FillerArgument.IsUndefined then
  begin
    PadStr := FillerArgument.ToLimitedString(Limits);

    const HasNoFiller = (PadStr = EMPTY_STRING);
    if HasNoFiller then
      Exit;
  end;

  Limits.EnsureStringLength(TargetLength);

  const PadLength = TargetLength - Length(Text);
  const Padding = BuildPadding(PadStr, PadLength);
  if PadsAtStart then
    Result := TJSValue.CreateString(Padding + Text)
  else
    Result := TJSValue.CreateString(Text + Padding);
end;

class function TJSBuiltins.StringToString(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(Text);
end;

class function TJSBuiltins.StringValueOf(const Text: string): TJSValue;
begin
  Result := TJSValue.CreateString(Text);
end;

class function TJSBuiltins.NumberToString(const Number: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  const RadixValue = TJSArrayLike.Argument(Args, 0);
  var Radix := DEFAULT_RADIX;
  if not RadixValue.IsUndefined then
    Radix := RadixArgument(RadixValue);

  const IsDefaultRadix = (Radix = DEFAULT_RADIX);
  if IsDefaultRadix then
  begin
    Result := TJSValue.CreateString(TJSValue.CreateNumber(Number).ToString);
    Exit;
  end;

  const IsSpecialNumber = (IsNaN(Number) or IsInfinite(Number));
  if IsSpecialNumber then
  begin
    Result := TJSValue.CreateString(SpecialNumberText(Number));
    Exit;
  end;

  const IsNegative = (Number < 0);
  const DigitsText = DigitsInRadix(Abs(Trunc(Number)), Radix);
  if IsNegative then
    Result := TJSValue.CreateString(Format(NEGATIVE_NUMBER_FORMAT, [DigitsText]))
  else
    Result := TJSValue.CreateString(DigitsText);
end;

class function TJSBuiltins.SpecialNumberText(const Number: Double): string;
begin
  const IsNegative = (Number < 0);
  if IsNaN(Number) then
    Result := NAN_TEXT
  else if IsNegative then
    Result := NEGATIVE_INFINITY_TEXT
  else
    Result := INFINITY_TEXT;
end;

class function TJSBuiltins.DigitsInRadix(const Magnitude: Int64; const Radix: Integer): string;
begin
  var Remaining := Magnitude;
  Result := EMPTY_STRING;

  const IsZero = (Remaining = 0);
  if IsZero then
    Result := ZERO_DIGIT;

  while Remaining > 0 do
  begin
    Result := RADIX_DIGITS[(Remaining mod Radix) + 1] + Result;
    Remaining := Remaining div Radix;
  end;
end;

class function TJSBuiltins.RadixArgument(const Argument: TJSValue): Integer;
begin
  const Requested = TJSConversions.ToIntegerOrInfinity(Argument);

  const IsInRange = (Requested >= MIN_RADIX) and (Requested <= MAX_RADIX);
  if not IsInRange then
    raise TJSErrorFactory.RangeError(RADIX_RANGE_MESSAGE);

  Result := Trunc(Requested);
end;

class function TJSBuiltins.DigitCountArgument(const Args: TArray<TJSValue>): Integer;
begin
  const Requested = TJSConversions.ToIntegerOrInfinity(Args[0]);

  Result := Trunc(Max(-DIGIT_COUNT_LIMIT, Min(DIGIT_COUNT_LIMIT, Requested)));
end;

class function TJSBuiltins.HasDigitCountArgument(const Args: TArray<TJSValue>): Boolean;
begin
  const FirstArgument = TJSArrayLike.Argument(Args, 0);

  Result := (not FirstArgument.IsUndefined);
end;

class function TJSBuiltins.DigitCountOrDefault(const Args: TArray<TJSValue>): Integer;
begin
  Result := 0;

  if HasDigitCountArgument(Args) then
    Result := DigitCountArgument(Args);
end;

class function TJSBuiltins.NumberToFixed(const Number: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  const FractionDigits = DigitCountOrDefault(Args);

  if not TJSNumberFormat.IsFractionDigitsInRange(FractionDigits) then
    raise TJSErrorFactory.RangeError(TO_FIXED_RANGE_MESSAGE);

  Result := TJSValue.CreateString(TJSNumberFormat.ToFixed(Number, FractionDigits));
end;

class function TJSBuiltins.NumberToPrecision(const Number: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  if not HasDigitCountArgument(Args) then
  begin
    Result := TJSValue.CreateString(TJSNumberFormat.ToDecimalString(Number));
    Exit;
  end;

  const Precision = DigitCountArgument(Args);
  const IsFiniteNumber = (not (IsNan(Number) or IsInfinite(Number)));
  if IsFiniteNumber and (not TJSNumberFormat.IsPrecisionInRange(Precision)) then
    raise TJSErrorFactory.RangeError(TO_PRECISION_RANGE_MESSAGE);

  Result := TJSValue.CreateString(TJSNumberFormat.ToPrecision(Number, Precision));
end;

class function TJSBuiltins.NumberToExponential(const Number: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  const HasDigits = HasDigitCountArgument(Args);
  const FractionDigits = DigitCountOrDefault(Args);

  const IsFiniteNumber = (not (IsNan(Number) or IsInfinite(Number)));
  if IsFiniteNumber and (not TJSNumberFormat.IsFractionDigitsInRange(FractionDigits)) then
    raise TJSErrorFactory.RangeError(TO_EXPONENTIAL_RANGE_MESSAGE);

  if HasDigits then
    Result := TJSValue.CreateString(TJSNumberFormat.ToExponential(Number, FractionDigits))
  else
    Result := TJSValue.CreateString(TJSNumberFormat.ToShortestExponential(Number));
end;

class function TJSBuiltins.NumberValueOf(const Number: Double): TJSValue;
begin
  Result := TJSValue.CreateNumber(Number);
end;

class function TJSBuiltins.TryFindArrayMethod(const MethodName: string; out Method: TArrayMethod): Boolean;
begin
  for var Candidate := Low(TArrayMethod) to High(TArrayMethod) do
  begin
    const IsMatch = (ARRAY_METHOD_NAMES[Candidate] = MethodName);
    if IsMatch then
    begin
      Method := Candidate;
      Exit(True);
    end;
  end;

  Method := Low(TArrayMethod);
  Result := False;
end;

class function TJSBuiltins.TryFindStringMethod(const MethodName: string; out Method: TStringMethod): Boolean;
begin
  for var Candidate := Low(TStringMethod) to High(TStringMethod) do
  begin
    const IsMatch = (STRING_METHOD_NAMES[Candidate] = MethodName);
    if IsMatch then
    begin
      Method := Candidate;
      Exit(True);
    end;
  end;

  Method := Low(TStringMethod);
  Result := False;
end;

class function TJSBuiltins.TryFindNumberMethod(const MethodName: string; out Method: TNumberMethod): Boolean;
begin
  for var Candidate := Low(TNumberMethod) to High(TNumberMethod) do
  begin
    const IsMatch = (NUMBER_METHOD_NAMES[Candidate] = MethodName);
    if IsMatch then
    begin
      Method := Candidate;
      Exit(True);
    end;
  end;

  Method := Low(TNumberMethod);
  Result := False;
end;

class function TJSBuiltins.CopyNames(const Names: array of string): TArray<string>;
begin
  SetLength(Result, Length(Names));
  for var Index := 0 to High(Names) do
  begin
    Result[Index] := Names[Index];
  end;
end;

class function TJSBuiltins.CallArrayMethod(const Elements: IJSArray; const MethodName: string;
                                           const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  var Method: TArrayMethod;
  if not TryFindArrayMethod(MethodName, Method) then
    Exit;

  case Method of
    TArrayMethod.Push    : Result := ArrayPush(Elements, Args, Limits);
    TArrayMethod.Pop     : Result := ArrayPop(Elements);
    TArrayMethod.Shift   : Result := ArrayShift(Elements);
    TArrayMethod.Unshift : Result := ArrayUnshift(Elements, Args, Limits);
    TArrayMethod.Join    : Result := ArrayJoin(Elements, Args, Limits);
    TArrayMethod.Slice   : Result := ArraySlice(Elements, Args);
    TArrayMethod.Splice  : Result := ArraySplice(Elements, Args, Limits);
    TArrayMethod.Concat  : Result := ArrayConcat(Elements, Args, Limits);
    TArrayMethod.Reverse : Result := ArrayReverse(Elements);
    TArrayMethod.ToText  : Result := ArrayToString(Elements, Limits);
  end;
end;

class function TJSBuiltins.CallArrayMethodWithCallback(const Elements: IJSArray; const MethodName: string;
                                                       const Args: TArray<TJSValue>;
                                                       const Executor: TJSCallbackExecutor;
                                                       const Limits: TJSLimits): TJSValue;
begin
  const IsSort = (MethodName = METHOD_SORT);
  if IsSort then
    Result := ArraySort(Elements, Args, Executor, Limits)
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallLimitedStringMethod(const Method: TStringMethod; const Text: string;
                                                   const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  case Method of
    TStringMethod.IndexOf     : Result := StringIndexOf(Text, Args, Limits);
    TStringMethod.LastIndexOf : Result := StringLastIndexOf(Text, Args, Limits);
    TStringMethod.Concat      : Result := StringConcat(Text, Args, Limits);
    TStringMethod.Repeat_     : Result := StringRepeat(Text, Args, Limits);
    TStringMethod.StartsWith  : Result := StringStartsWith(Text, Args, Limits);
    TStringMethod.EndsWith    : Result := StringEndsWith(Text, Args, Limits);
    TStringMethod.Includes    : Result := StringIncludes(Text, Args, Limits);
    TStringMethod.PadStart    : Result := PadString(Text, Args, Limits, True);
    TStringMethod.PadEnd      : Result := PadString(Text, Args, Limits, False);
  else
    Result := TJSValue.CreateUndefined;
  end;
end;

class function TJSBuiltins.CallStringMethod(const Text: string; const MethodName: string; const Args: TArray<TJSValue>;
                                            const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  var Method: TStringMethod;
  if not TryFindStringMethod(MethodName, Method) then
    Exit;

  if Method in LIMITED_STRING_METHODS then
  begin
    Result := CallLimitedStringMethod(Method, Text, Args, Limits);
    Exit;
  end;

  case Method of
    TStringMethod.CharAt            : Result := StringCharAt(Text, Args);
    TStringMethod.CharCodeAt        : Result := StringCharCodeAt(Text, Args);
    TStringMethod.CodePointAt       : Result := StringCodePointAt(Text, Args);
    TStringMethod.Normalize         : Result := StringNormalize(Text, Args);
    TStringMethod.Substring         : Result := StringSubstring(Text, Args);
    TStringMethod.Substr            : Result := StringSubstr(Text, Args);
    TStringMethod.Slice             : Result := StringSlice(Text, Args);
    TStringMethod.ToLowerCase,
    TStringMethod.ToLocaleLowerCase : Result := StringToLowerCase(Text);
    TStringMethod.ToUpperCase,
    TStringMethod.ToLocaleUpperCase : Result := StringToUpperCase(Text);
    TStringMethod.LocaleCompare     : Result := StringLocaleCompare(Text, Args);
    TStringMethod.Trim              : Result := StringTrim(Text);
    TStringMethod.TrimStart,
    TStringMethod.TrimLeft          : Result := StringTrimStart(Text);
    TStringMethod.TrimEnd,
    TStringMethod.TrimRight         : Result := StringTrimEnd(Text);
    TStringMethod.At                : Result := StringAt(Text, Args);
    TStringMethod.ToText            : Result := StringToString(Text);
    TStringMethod.ValueOf           : Result := StringValueOf(Text);
  end;
end;

class function TJSBuiltins.CallNumberMethod(const Number: Double; const MethodName: string;
                                            const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateUndefined;

  var Method: TNumberMethod;
  if not TryFindNumberMethod(MethodName, Method) then
    Exit;

  case Method of
    TNumberMethod.ToText        : Result := NumberToString(Number, Args);
    TNumberMethod.ToFixed             : Result := NumberToFixed(Number, Args);
    TNumberMethod.ToPrecision         : Result := NumberToPrecision(Number, Args);
    TNumberMethod.ToExponential       : Result := NumberToExponential(Number, Args);
    TNumberMethod.ValueOf : Result := NumberValueOf(Number);
  end;
end;

class function TJSBuiltins.ArrayMethodNames: TArray<string>;
begin
  Result := CopyNames(ARRAY_METHOD_NAMES);
end;

class function TJSBuiltins.HasArrayMethod(const MethodName: string): Boolean;
begin
  var Method: TArrayMethod;
  Result := TryFindArrayMethod(MethodName, Method);
end;

class function TJSBuiltins.RequiresCallback(const MethodName: string): Boolean;
begin
  var Method: TArrayMethod;
  Result := (TryFindArrayMethod(MethodName, Method) and (Method in CALLBACK_ARRAY_METHODS));
end;

class function TJSBuiltins.TakesCallbackThis(const MethodName: string): Boolean;
begin
  var Method: TArrayMethod;
  Result := (TryFindArrayMethod(MethodName, Method) and (Method in CALLBACK_THIS_ARRAY_METHODS));
end;

class function TJSBuiltins.StringMethodNames: TArray<string>;
begin
  Result := CopyNames(STRING_METHOD_NAMES);
end;

class function TJSBuiltins.NumberMethodNames: TArray<string>;
begin
  Result := CopyNames(NUMBER_METHOD_NAMES);
end;

class function TJSBuiltins.HasStringMethod(const MethodName: string): Boolean;
begin
  var Method: TStringMethod;
  Result := TryFindStringMethod(MethodName, Method);
end;

class function TJSBuiltins.IsNumericStringArgument(const MethodName: string; const Index: Integer): Boolean;
begin
  var Method: TStringMethod;
  if not TryFindStringMethod(MethodName, Method) then
    Exit(False);

  const IsFirstNumeric = (Method in [TStringMethod.CharAt, TStringMethod.At, TStringMethod.CharCodeAt,
                                     TStringMethod.CodePointAt, TStringMethod.Repeat_, TStringMethod.PadStart,
                                     TStringMethod.PadEnd]);

  const IsSecondNumeric = (Method in [TStringMethod.IndexOf, TStringMethod.LastIndexOf,
                                      TStringMethod.StartsWith, TStringMethod.EndsWith,
                                      TStringMethod.Includes]);

  const IsBothNumeric = (Method in [TStringMethod.Substring, TStringMethod.Substr, TStringMethod.Slice]);

  case Index of
    0 : Result := (IsFirstNumeric or IsBothNumeric);
    1 : Result := (IsSecondNumeric or IsBothNumeric);
  else
    Result := False;
  end;
end;

class function TJSBuiltins.HasNumberMethod(const MethodName: string): Boolean;
begin
  var Method: TNumberMethod;
  Result := TryFindNumberMethod(MethodName, Method);
end;

class function TJSBuiltins.HasFunctionMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_CALL) or
            (MethodName = METHOD_APPLY) or
            (MethodName = METHOD_BIND);
end;

class function TJSBuiltins.IsArrayMethod(const MethodName: string): Boolean;
begin
  Result := HasArrayMethod(MethodName);
end;

class function TJSBuiltins.IsStringMethod(const MethodName: string): Boolean;
begin
  Result := HasStringMethod(MethodName);
end;

class function TJSBuiltins.IsNumberMethod(const MethodName: string): Boolean;
begin
  Result := HasNumberMethod(MethodName);
end;

class function TJSBuiltins.ObjectMethodNames: TArray<string>;
begin
  Result := CopyNames(OBJECT_METHOD_NAMES);
end;

class function TJSBuiltins.HasObjectMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = OBJECT_METHOD_NAMES[0]) or
            (MethodName = OBJECT_METHOD_NAMES[1]);
end;

class function TJSBuiltins.CallObjectMethod(const Target: IJSObject; const MethodName: string;
                                            const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const HasNoArguments = (Length(Args) = 0);
  if HasNoArguments then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  const PropertyName = Args[0].ToPropertyKey(Limits);

  const IsHasOwnProperty = (MethodName = OBJECT_METHOD_NAMES[0]);
  if IsHasOwnProperty then
  begin
    const HasOwnProperty = Target.HasOwnProperty(PropertyName);
    Result := TJSValue.CreateBoolean(HasOwnProperty);
    Exit;
  end;

  const IsPropertyIsEnumerable = (MethodName = OBJECT_METHOD_NAMES[1]);
  if IsPropertyIsEnumerable then
  begin
    var Descriptor: TJSPropertyDescriptor;
    const IsEnumerable = TJSObjectOperations.TryGetOwnProperty(Target, PropertyName,
                                                               Descriptor) and Descriptor.Enumerable;

    Result := TJSValue.CreateBoolean(IsEnumerable);
    Exit;
  end;

  Result := TJSValue.CreateUndefined;
end;

end.
