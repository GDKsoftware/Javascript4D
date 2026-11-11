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
  JS4D.ArrayLike,
  JS4D.UnicodeNormalization;

type
  TJSBuiltins = class
  private
    class function ArrayPush(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function ArrayPop(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayShift(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayUnshift(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function ArrayJoin(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function ArraySlice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArraySplice(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function ArrayConcat(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function ArrayReverse(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayToString(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;

    class function ArraySort(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue; static;
    class function CompareSortValues(const Left, Right: TJSValue; const Comparer: IJSFunction;
                                     const Executor: TJSCallbackExecutor; const Limits: TJSLimits): Double; static;
    class function CollectDefinedElements(const Arr: IJSArray): TArray<TJSValue>; static;
    class procedure MergeSortedRuns(const Elements, Buffer: TArray<TJSValue>; const First, Middle, Last: Integer;
                                    const Comparer: IJSFunction; const Executor: TJSCallbackExecutor; const Limits: TJSLimits); static;
    class procedure MergeSortRange(const Elements, Buffer: TArray<TJSValue>; const First, Last: Integer;
                                   const Comparer: IJSFunction; const Executor: TJSCallbackExecutor; const Limits: TJSLimits); static;

    class function IntegerArgument(const Args: TArray<TJSValue>; const Index: Integer): Double; static;
    class function ClampPosition(const Position: Double; const Count: Integer): Integer; static;
    class function RelativePosition(const Position: Double; const Count: Integer): Integer; static;
    class function EndPosition(const Args: TArray<TJSValue>; const Index: Integer; const Count: Integer): Double; static;
    class function StringCharAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringCharCodeAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringCodePointAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringNormalize(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringIndexOf(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringLastIndexOf(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringSubstring(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSubstr(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSlice(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToLowerCase(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToUpperCase(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringLocaleCompare(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrim(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrimStart(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrimEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArgumentOrUndefined(const Args: TArray<TJSValue>; const Index: Integer): TJSValue; static;
    class function BuildPadding(const PadStr: string; const PadLength: Integer): string; static;
    class function StringConcat(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringRepeat(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringStartsWith(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringEndsWith(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringIncludes(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringPadStart(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringPadEnd(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function StringToString(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringValueOf(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;

    class function NumberToString(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function RadixArgument(const Argument: TJSValue): Integer; static;
    class function DigitCountArgument(const Args: TArray<TJSValue>): Integer; static;
    class function HasDigitCountArgument(const Args: TArray<TJSValue>): Boolean; static;
    class function NumberToFixed(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToPrecision(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToExponential(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberValueOf(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;

  public
    class function CallArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;
    class function CallArrayMethodWithCallback(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue; static;
    class function CallStringMethod(const Str: string; const MethodName: string; const Args: TArray<TJSValue>;
                                    const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue; static;
    class function CallNumberMethod(const Num: Double; const MethodName: string; const Args: TArray<TJSValue>): TJSValue; static;

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

    class function CallObjectMethod(const Obj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue; static;

    class function RequiresCallback(const MethodName: string): Boolean; static;
    class function TakesCallbackThis(const MethodName: string): Boolean; static;

    class function IsArrayMethod(const MethodName: string): Boolean; static;
    class function IsStringMethod(const MethodName: string): Boolean; static;
    class function IsNumberMethod(const MethodName: string): Boolean; static;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.ObjectOperations,
  JS4D.NumberFormat,
  JS4D.NumberParse;

const
  DIGIT_COUNT_LIMIT = 1000;
  DEFAULT_RADIX = 10;
  MIN_RADIX = 2;
  MAX_RADIX = 36;
  RADIX_RANGE_MESSAGE = 'toString() radix must be between 2 and 36';
  TO_FIXED_RANGE_MESSAGE = 'toFixed() digits argument must be between 0 and 100';
  TO_PRECISION_RANGE_MESSAGE = 'toPrecision() argument must be between 1 and 100';
  TO_EXPONENTIAL_RANGE_MESSAGE = 'toExponential() argument must be between 0 and 100';
  INVALID_NORMALIZATION_FORM_MESSAGE = 'The normalization form should be one of NFC, NFD, NFKC, NFKD';
  INVALID_REPEAT_COUNT_MESSAGE = 'Invalid count value for String.prototype.repeat';
  METHOD_PUSH = 'push';
  METHOD_POP = 'pop';
  METHOD_SHIFT = 'shift';
  METHOD_UNSHIFT = 'unshift';
  METHOD_INDEX_OF = 'indexOf';
  METHOD_LAST_INDEX_OF = 'lastIndexOf';
  METHOD_JOIN = 'join';
  METHOD_SLICE = 'slice';
  METHOD_SPLICE = 'splice';
  METHOD_CONCAT = 'concat';
  METHOD_REVERSE = 'reverse';
  METHOD_INCLUDES = 'includes';
  METHOD_FILL = 'fill';
  METHOD_COPY_WITHIN = 'copyWithin';
  METHOD_TO_STRING = 'toString';
  METHOD_CHAR_AT = 'charAt';
  METHOD_CHAR_CODE_AT = 'charCodeAt';
  METHOD_CODE_POINT_AT = 'codePointAt';
  METHOD_NORMALIZE = 'normalize';
  METHOD_SUBSTRING = 'substring';
  METHOD_SUBSTR = 'substr';
  METHOD_TO_LOWER_CASE = 'toLowerCase';
  METHOD_TO_UPPER_CASE = 'toUpperCase';
  METHOD_TO_LOCALE_LOWER_CASE = 'toLocaleLowerCase';
  METHOD_TO_LOCALE_UPPER_CASE = 'toLocaleUpperCase';
  METHOD_LOCALE_COMPARE = 'localeCompare';
  METHOD_TRIM = 'trim';
  METHOD_TRIM_START = 'trimStart';
  METHOD_TRIM_LEFT = 'trimLeft';
  METHOD_TRIM_END = 'trimEnd';
  METHOD_TRIM_RIGHT = 'trimRight';
  METHOD_REPEAT = 'repeat';
  METHOD_STARTS_WITH = 'startsWith';
  METHOD_ENDS_WITH = 'endsWith';
  METHOD_PAD_START = 'padStart';
  METHOD_PAD_END = 'padEnd';
  METHOD_VALUE_OF = 'valueOf';
  METHOD_TO_FIXED = 'toFixed';
  METHOD_TO_PRECISION = 'toPrecision';
  METHOD_TO_EXPONENTIAL = 'toExponential';
  METHOD_MAP = 'map';
  METHOD_FILTER = 'filter';
  METHOD_FOR_EACH = 'forEach';
  METHOD_REDUCE = 'reduce';
  METHOD_REDUCE_RIGHT = 'reduceRight';
  METHOD_SOME = 'some';
  METHOD_EVERY = 'every';
  METHOD_FIND = 'find';
  METHOD_FIND_INDEX = 'findIndex';
  METHOD_SORT = 'sort';
  METHOD_FLAT = 'flat';
  METHOD_AT = 'at';
  METHOD_FLAT_MAP = 'flatMap';
  METHOD_CALL = 'call';
  METHOD_APPLY = 'apply';
  METHOD_BIND = 'bind';
  METHOD_HAS_OWN_PROPERTY = 'hasOwnProperty';
  METHOD_PROPERTY_IS_ENUMERABLE = 'propertyIsEnumerable';
  DEFAULT_SEPARATOR: string = ',';
  EMPTY_STRING: string = '';
  DEFAULT_NORMALIZATION_FORM = 'NFC';
  SPACE_CHAR: string = ' ';

  ARRAY_METHOD_NAMES: array[0..27] of string = (
    METHOD_PUSH, METHOD_POP, METHOD_SHIFT, METHOD_UNSHIFT, METHOD_INDEX_OF, METHOD_LAST_INDEX_OF,
    METHOD_JOIN, METHOD_SLICE, METHOD_SPLICE, METHOD_CONCAT, METHOD_REVERSE, METHOD_INCLUDES,
    METHOD_FILL, METHOD_COPY_WITHIN, METHOD_TO_STRING, METHOD_FLAT, METHOD_MAP, METHOD_FILTER,
    METHOD_FOR_EACH, METHOD_REDUCE, METHOD_REDUCE_RIGHT, METHOD_SOME, METHOD_EVERY, METHOD_FIND,
    METHOD_FIND_INDEX, METHOD_SORT, METHOD_AT, METHOD_FLAT_MAP);

  STRING_METHOD_NAMES: array[0..28] of string = (
    METHOD_CHAR_AT, METHOD_CHAR_CODE_AT, METHOD_INDEX_OF, METHOD_LAST_INDEX_OF, METHOD_SUBSTRING,
    METHOD_SUBSTR, METHOD_SLICE, METHOD_TO_LOWER_CASE, METHOD_TO_UPPER_CASE, METHOD_TRIM,
    METHOD_TRIM_START, METHOD_TRIM_LEFT, METHOD_TRIM_END, METHOD_TRIM_RIGHT,
    METHOD_CONCAT, METHOD_REPEAT, METHOD_STARTS_WITH, METHOD_ENDS_WITH,
    METHOD_INCLUDES, METHOD_PAD_START, METHOD_PAD_END, METHOD_TO_STRING, METHOD_VALUE_OF,
    METHOD_TO_LOCALE_LOWER_CASE, METHOD_TO_LOCALE_UPPER_CASE, METHOD_LOCALE_COMPARE,
    METHOD_CODE_POINT_AT, METHOD_NORMALIZE, METHOD_AT);

  NUMBER_METHOD_NAMES: array[0..4] of string = (
    METHOD_TO_STRING, METHOD_TO_FIXED, METHOD_TO_PRECISION, METHOD_TO_EXPONENTIAL, METHOD_VALUE_OF);

class function TJSBuiltins.ArrayPush(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const ArgsLength = Length(Args);

  Limits.EnsureArrayLength(Int64(Arr.Length) + ArgsLength);

  for var Arg in Args do
  begin
    Arr.Push(Arg);
  end;

  Result := TJSValue.CreateNumber(Arr.Length);
end;

class function TJSBuiltins.ArrayPop(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := Arr.Pop;
end;

class function TJSBuiltins.ArrayShift(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Arr.Length = 0 then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := Arr[0];

  for var Index := 0 to Arr.Length - 2 do
  begin
    Arr[Index] := Arr[Index + 1];
  end;

  Arr.Pop;
end;

class function TJSBuiltins.ArrayUnshift(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const OriginalLength = Arr.Length;
  const ArgsLength = Length(Args);

  Limits.EnsureArrayLength(Int64(OriginalLength) + ArgsLength);

  for var Index := 0 to ArgsLength - 1 do
  begin
    Arr.Push(TJSValue.CreateUndefined);
  end;

  for var Index := OriginalLength - 1 downto 0 do
  begin
    Arr[Index + ArgsLength] := Arr[Index];
  end;

  for var Index := 0 to ArgsLength - 1 do
  begin
    Arr[Index] := Args[Index];
  end;

  Result := TJSValue.CreateNumber(Arr.Length);
end;

class function TJSBuiltins.ArrayJoin(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  var Separator := DEFAULT_SEPARATOR;

  if (Length(Args) > 0) and (not Args[0].IsUndefined) then
    Separator := Args[0].ToLimitedString(Limits);

  const SeparatorLength = Length(Separator);
  var StringBuilder := TStringBuilder.Create;
  try
    for var Index := 0 to Arr.Length - 1 do
    begin
      const Element = Arr[Index];
      var ElementText := EMPTY_STRING;

      if not Element.IsNullOrUndefined then
        ElementText := Element.ToLimitedString(Limits);

      const NeedsSeparator = (Index > 0);
      var AddedLength := Length(ElementText);

      if NeedsSeparator then
        Inc(AddedLength, SeparatorLength);

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

class function TJSBuiltins.ArraySlice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const NewArr: IJSArray = TJSArray.Create;

  const Count = Int64(Arr.Length);
  const StartIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 0), Count, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 1), Count, Count);

  for var Index := StartIndex to EndIndex - 1 do
  begin
    NewArr.Push(Arr[Integer(Index)]);
  end;

  Result := TJSValue.CreateObject(NewArr);
end;

class function TJSBuiltins.ArraySplice(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const Removed: IJSArray = TJSArray.Create;

  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(Removed);
    Exit;
  end;

  const StartIndex = Integer(TJSArrayLike.RelativeIndex(Args[0], Arr.Length, 0));

  var DeleteCount := Arr.Length - StartIndex;

  if Length(Args) > 1 then
  begin
    const Requested = TJSArrayLike.ToInteger(Args[1]);
    DeleteCount := Trunc(Min(Max(Requested, 0), DeleteCount));
  end;

  for var Index := 0 to DeleteCount - 1 do
  begin
    Removed.Push(Arr[StartIndex + Index]);
  end;

  var ItemsToInsert: TArray<TJSValue>;

  if Length(Args) > 2 then
  begin
    SetLength(ItemsToInsert, Length(Args) - 2);

    for var Index := 2 to Length(Args) - 1 do
    begin
      ItemsToInsert[Index - 2] := Args[Index];
    end;
  end;

  const InsertCount = Length(ItemsToInsert);
  const Diff = InsertCount - DeleteCount;

  Limits.EnsureArrayLength(Int64(Arr.Length) + Diff);

  if Diff > 0 then
  begin
    for var Index := 0 to Diff - 1 do
    begin
      Arr.Push(TJSValue.CreateUndefined);
    end;

    for var Index := Arr.Length - 1 - Diff downto StartIndex + DeleteCount do
    begin
      Arr[Index + Diff] := Arr[Index];
    end;
  end
  else if Diff < 0 then
  begin
    for var Index := StartIndex + DeleteCount to Arr.Length - 1 do
    begin
      Arr[Index + Diff] := Arr[Index];
    end;

    for var Index := 0 to -Diff - 1 do
    begin
      Arr.Pop;
    end;
  end;

  for var Index := 0 to InsertCount - 1 do
  begin
    Arr[StartIndex + Index] := ItemsToInsert[Index];
  end;

  Result := TJSValue.CreateObject(Removed);
end;

class function TJSBuiltins.ArrayConcat(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  var TotalLength := Int64(Arr.Length);

  for var Arg in Args do
  begin
    var Source: IJSArray;
    if Arg.IsArray and Supports(Arg.ToObject, IJSArray, Source) then
      Inc(TotalLength, Source.Length)
    else
      Inc(TotalLength);
  end;

  Limits.EnsureArrayLength(TotalLength);

  const NewArr: IJSArray = TJSArray.Create;

  for var Index := 0 to Arr.Length - 1 do
  begin
    NewArr.Push(Arr[Index]);
  end;

  for var Arg in Args do
  begin
    if Arg.IsArray then
    begin
      var OtherArr: IJSArray;
      if Supports(Arg.ToObject, IJSArray, OtherArr) then
      begin
        for var Index := 0 to OtherArr.Length - 1 do
        begin
          NewArr.Push(OtherArr[Index]);
        end;
      end;
    end
    else
    begin
      NewArr.Push(Arg);
    end;
  end;

  Result := TJSValue.CreateObject(NewArr);
end;

class function TJSBuiltins.ArrayReverse(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const HalfLength = Arr.Length div 2;

  for var Index := 0 to HalfLength - 1 do
  begin
    const Temp = Arr[Index];
    const MirrorIndex = Arr.Length - 1 - Index;
    Arr[Index] := Arr[MirrorIndex];
    Arr[MirrorIndex] := Temp;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

class function TJSBuiltins.ArrayToString(const Arr: IJSArray; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  Result := ArrayJoin(Arr, [], Limits);
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

  if LeftText < RightText then
    Result := -1
  else if LeftText > RightText then
    Result := 1
  else
    Result := 0;
end;

class function TJSBuiltins.CollectDefinedElements(const Arr: IJSArray): TArray<TJSValue>;
begin
  SetLength(Result, Arr.Length);

  var DefinedCount := 0;

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];

    if not Element.IsUndefined then
    begin
      Result[DefinedCount] := Element;
      Inc(DefinedCount);
    end;
  end;

  SetLength(Result, DefinedCount);
end;

class procedure TJSBuiltins.MergeSortedRuns(const Elements, Buffer: TArray<TJSValue>; const First, Middle, Last: Integer;
                                            const Comparer: IJSFunction; const Executor: TJSCallbackExecutor; const Limits: TJSLimits);
begin
  var LeftIndex := First;
  var RightIndex := Middle + 1;
  var TargetIndex := First;

  while (LeftIndex <= Middle) and (RightIndex <= Last) do
  begin
    const RightGoesFirst = (CompareSortValues(Elements[LeftIndex], Elements[RightIndex], Comparer, Executor, Limits) > 0);

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

  while LeftIndex <= Middle do
  begin
    Buffer[TargetIndex] := Elements[LeftIndex];
    Inc(LeftIndex);
    Inc(TargetIndex);
  end;

  while RightIndex <= Last do
  begin
    Buffer[TargetIndex] := Elements[RightIndex];
    Inc(RightIndex);
    Inc(TargetIndex);
  end;

  for var Index := First to Last do
  begin
    Elements[Index] := Buffer[Index];
  end;
end;

class procedure TJSBuiltins.MergeSortRange(const Elements, Buffer: TArray<TJSValue>; const First, Last: Integer;
                                           const Comparer: IJSFunction; const Executor: TJSCallbackExecutor; const Limits: TJSLimits);
begin
  if First >= Last then
    Exit;

  const Middle = First + ((Last - First) div 2);

  MergeSortRange(Elements, Buffer, First, Middle, Comparer, Executor, Limits);
  MergeSortRange(Elements, Buffer, Middle + 1, Last, Comparer, Executor, Limits);
  MergeSortedRuns(Elements, Buffer, First, Middle, Last, Comparer, Executor, Limits);
end;

class function TJSBuiltins.ArraySort(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue;
begin
  if Arr.Length <= 1 then
  begin
    Result := TJSValue.CreateObject(Arr);
    Exit;
  end;

  var HasComparer := (Length(Args) > 0) and Args[0].IsFunction;
  var Comparer: IJSFunction := nil;

  if HasComparer then
    Supports(Args[0].ToObject, IJSFunction, Comparer);

  const Elements = CollectDefinedElements(Arr);
  const DefinedCount = Length(Elements);

  var Buffer: TArray<TJSValue>;
  SetLength(Buffer, DefinedCount);

  MergeSortRange(Elements, Buffer, 0, DefinedCount - 1, Comparer, Executor, Limits);

  for var Index := 0 to Arr.Length - 1 do
  begin
    if Index < DefinedCount then
      Arr[Index] := Elements[Index]
    else
      Arr[Index] := TJSValue.CreateUndefined;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

class function TJSBuiltins.IntegerArgument(const Args: TArray<TJSValue>; const Index: Integer): Double;
begin
  Result := 0;

  if Index >= Length(Args) then
    Exit;

  const Number = Args[Index].ToNumber;
  if not IsNaN(Number) then
    Result := Int(Number);
end;

class function TJSBuiltins.ClampPosition(const Position: Double; const Count: Integer): Integer;
begin
  Result := Trunc(EnsureRange(Position, 0, Count));
end;

class function TJSBuiltins.RelativePosition(const Position: Double; const Count: Integer): Integer;
begin
  if Position < 0 then
    Result := Trunc(Max(Count + Position, 0))
  else
    Result := Trunc(Min(Position, Count));
end;

class function TJSBuiltins.EndPosition(const Args: TArray<TJSValue>; const Index: Integer; const Count: Integer): Double;
begin
  const IsEndGiven = (Index < Length(Args)) and (not Args[Index].IsUndefined);
  if IsEndGiven then
    Result := IntegerArgument(Args, Index)
  else
    Result := Count;
end;

class function TJSBuiltins.StringCharAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Str));
  if IsInRange then
    Result := TJSValue.CreateString(Str[Trunc(Position) + 1])
  else
    Result := TJSValue.CreateString(EMPTY_STRING);
end;

class function TJSBuiltins.StringCharCodeAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Str));
  if IsInRange then
    Result := TJSValue.CreateNumber(Ord(Str[Trunc(Position) + 1]))
  else
    Result := TJSValue.CreateNaN;
end;

class function TJSBuiltins.StringCodePointAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Position = IntegerArgument(Args, 0);

  const IsInRange = (Position >= 0) and (Position < Length(Str));
  if not IsInRange then
    Exit(TJSValue.CreateUndefined);

  const Index = Trunc(Position) + 1;
  const First = Str[Index];

  const HasTrailUnit = Index < Length(Str);
  const IsSurrogatePair = HasTrailUnit and First.IsHighSurrogate and Str[Index + 1].IsLowSurrogate;
  if not IsSurrogatePair then
    Exit(TJSValue.CreateNumber(Ord(First)));

  const CodePoint = Char.ConvertToUtf32(First, Str[Index + 1]);
  Result := TJSValue.CreateNumber(CodePoint);
end;

class function TJSBuiltins.StringNormalize(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var FormName := DEFAULT_NORMALIZATION_FORM;

  const HasForm = (Length(Args) > 0) and not Args[0].IsUndefined;
  if HasForm then
    FormName := Args[0].ToString;

  var Form: TJSNormalizationForm;
  if not TJSUnicodeNormalization.TryParseForm(FormName, Form) then
    raise TJSErrorFactory.RangeError(INVALID_NORMALIZATION_FORM_MESSAGE);

  Result := TJSValue.CreateString(TJSUnicodeNormalization.Normalize(Str, Form));
end;

class function TJSBuiltins.StringIndexOf(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = ArgumentOrUndefined(Args, 0).ToLimitedString(Limits);
  const FromIndex = ClampPosition(IntegerArgument(Args, 1), Length(Str));

  if SearchStr = EMPTY_STRING then
    Exit(TJSValue.CreateNumber(FromIndex));

  const Position = Pos(SearchStr, Str, FromIndex + 1);

  if Position > 0 then
    Result := TJSValue.CreateNumber(Position - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.StringLastIndexOf(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = ArgumentOrUndefined(Args, 0).ToLimitedString(Limits);

  var StartIndex := Length(Str);
  const PositionNumber = ArgumentOrUndefined(Args, 1).ToNumber;
  if not IsNaN(PositionNumber) then
    StartIndex := ClampPosition(Int(PositionNumber), Length(Str));

  if SearchStr = EMPTY_STRING then
    Exit(TJSValue.CreateNumber(StartIndex));

  const SearchIn = Copy(Str, 1, Min(StartIndex + Length(SearchStr), Length(Str)));
  var LastPos := 0;
  var CurrentPos := 1;

  while CurrentPos <= Length(SearchIn) do
  begin
    const Position = Pos(SearchStr, SearchIn, CurrentPos);

    if Position = 0 then
      Break;

    LastPos := Position;
    CurrentPos := Position + 1;
  end;

  if LastPos > 0 then
    Result := TJSValue.CreateNumber(LastPos - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.StringSubstring(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var StartIndex := ClampPosition(IntegerArgument(Args, 0), Length(Str));
  var EndIndex := ClampPosition(EndPosition(Args, 1, Length(Str)), Length(Str));

  if StartIndex > EndIndex then
  begin
    const Temp = StartIndex;
    StartIndex := EndIndex;
    EndIndex := Temp;
  end;

  Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringSubstr(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const StartIndex = RelativePosition(IntegerArgument(Args, 0), Length(Str));
  const CharCount = ClampPosition(EndPosition(Args, 1, Length(Str)), Length(Str) - StartIndex);

  Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, CharCount));
end;

class function TJSBuiltins.StringSlice(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const StartIndex = RelativePosition(IntegerArgument(Args, 0), Length(Str));
  const EndIndex = RelativePosition(EndPosition(Args, 1, Length(Str)), Length(Str));

  if StartIndex >= EndIndex then
    Result := TJSValue.CreateString(EMPTY_STRING)
  else
    Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringToLowerCase(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(LowerCase(Str));
end;

class function TJSBuiltins.StringToUpperCase(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(UpperCase(Str));
end;

class function TJSBuiltins.StringLocaleCompare(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Other := 'undefined';
  if Length(Args) > 0 then
    Other := Args[0].ToString;

  Result := TJSValue.CreateNumber(Sign(CompareStr(Str, Other)));
end;

class function TJSBuiltins.StringTrim(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(TJSNumberParse.Trim(Str));
end;

class function TJSBuiltins.StringTrimStart(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(TJSNumberParse.TrimStart(Str));
end;

class function TJSBuiltins.StringTrimEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(TJSNumberParse.TrimEnd(Str));
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

class function TJSBuiltins.ArgumentOrUndefined(const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
begin
  if Index < Length(Args) then
    Result := Args[Index]
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.StringConcat(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  var StringBuilder := TStringBuilder.Create;
  try
    StringBuilder.Append(Str);

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

class function TJSBuiltins.StringRepeat(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

  const CountNumber = IntegerArgument(Args, 0);

  const IsInvalidCount = (CountNumber < 0) or IsInfinite(CountNumber);
  if IsInvalidCount then
    raise TJSErrorFactory.RangeError(INVALID_REPEAT_COUNT_MESSAGE);

  const Count = Trunc(CountNumber);

  if (Count = 0) or (Str = EMPTY_STRING) then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

  const RepeatedLength = Int64(Length(Str)) * Count;

  Limits.EnsureStringLength(RepeatedLength);

  var StringBuilder := TStringBuilder.Create;
  try
    for var Index := 1 to Count do
    begin
      StringBuilder.Append(Str);
    end;

    Result := TJSValue.CreateString(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.StringStartsWith(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = ArgumentOrUndefined(Args, 0).ToLimitedString(Limits);
  const Start = ClampPosition(IntegerArgument(Args, 1), Length(Str));

  const FitsInString = (Start + Length(SearchStr) <= Length(Str));

  Result := TJSValue.CreateBoolean(FitsInString and (Copy(Str, Start + 1, Length(SearchStr)) = SearchStr));
end;

class function TJSBuiltins.StringEndsWith(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = ArgumentOrUndefined(Args, 0).ToLimitedString(Limits);
  const EndIndex = ClampPosition(EndPosition(Args, 1, Length(Str)), Length(Str));
  const Start = EndIndex - Length(SearchStr);

  const FitsInString = (Start >= 0);

  Result := TJSValue.CreateBoolean(FitsInString and (Copy(Str, Start + 1, Length(SearchStr)) = SearchStr));
end;

class function TJSBuiltins.StringIncludes(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  const SearchStr = ArgumentOrUndefined(Args, 0).ToLimitedString(Limits);
  const Start = ClampPosition(IntegerArgument(Args, 1), Length(Str));

  const IsFound = SearchStr.IsEmpty or (Pos(SearchStr, Str, Start + 1) > 0);

  Result := TJSValue.CreateBoolean(IsFound);
end;

class function TJSBuiltins.StringAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const Relative = IntegerArgument(Args, 0);

  var Position := Relative;
  if Relative < 0 then
    Position := Length(Str) + Relative;

  const IsInRange = (Position >= 0) and (Position < Length(Str));
  if IsInRange then
    Result := TJSValue.CreateString(Str[Trunc(Position) + 1])
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.StringPadStart(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(Str);
    Exit;
  end;

  const TargetLength = Trunc(Args[0].ToNumber);

  if TargetLength <= Length(Str) then
  begin
    Result := TJSValue.CreateString(Str);
    Exit;
  end;

  var PadStr := SPACE_CHAR;

  if (Length(Args) > 1) and (not Args[1].IsUndefined) then
  begin
    PadStr := Args[1].ToLimitedString(Limits);

    if PadStr = EMPTY_STRING then
    begin
      Result := TJSValue.CreateString(Str);
      Exit;
    end;
  end;

  Limits.EnsureStringLength(TargetLength);

  const PadLength = TargetLength - Length(Str);
  const Padding = BuildPadding(PadStr, PadLength);

  Result := TJSValue.CreateString(Padding + Str);
end;

class function TJSBuiltins.StringPadEnd(const Str: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(Str);
    Exit;
  end;

  const TargetLength = Trunc(Args[0].ToNumber);

  if TargetLength <= Length(Str) then
  begin
    Result := TJSValue.CreateString(Str);
    Exit;
  end;

  var PadStr := SPACE_CHAR;

  if (Length(Args) > 1) and (not Args[1].IsUndefined) then
  begin
    PadStr := Args[1].ToLimitedString(Limits);

    if PadStr = EMPTY_STRING then
    begin
      Result := TJSValue.CreateString(Str);
      Exit;
    end;
  end;

  Limits.EnsureStringLength(TargetLength);

  const PadLength = TargetLength - Length(Str);
  const Padding = BuildPadding(PadStr, PadLength);

  Result := TJSValue.CreateString(Str + Padding);
end;

class function TJSBuiltins.StringToString(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(Str);
end;

class function TJSBuiltins.StringValueOf(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(Str);
end;

class function TJSBuiltins.NumberToString(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  const HasRadix = (Length(Args) > 0) and (Args[0].ValueType <> TJSValueType.Undefined);
  var Radix := DEFAULT_RADIX;
  if HasRadix then
    Radix := RadixArgument(Args[0]);

  if Radix = DEFAULT_RADIX then
  begin
    Result := TJSValue.CreateString(TJSValue.CreateNumber(Num).ToString);
    Exit;
  end;

  if IsNaN(Num) then
  begin
    Result := TJSValue.CreateString('NaN');
    Exit;
  end;

  if IsInfinite(Num) then
  begin
    if Num < 0 then
    begin
      Result := TJSValue.CreateString('-Infinity');
      Exit;
    end
    else
    begin
      Result := TJSValue.CreateString('Infinity');
      Exit;
    end;
  end;

  const IsNegative = Num < 0;
  var IntValue := Abs(Trunc(Num));
  var ResultStr := EMPTY_STRING;
  const Digits = '0123456789abcdefghijklmnopqrstuvwxyz';

  if IntValue = 0 then
    ResultStr := '0'
  else
  begin
    while IntValue > 0 do
    begin
      ResultStr := Digits[(IntValue mod Radix) + 1] + ResultStr;
      IntValue := IntValue div Radix;
    end;
  end;

  if IsNegative then
    ResultStr := '-' + ResultStr;

  Result := TJSValue.CreateString(ResultStr);
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
  Result := (Length(Args) > 0) and (Args[0].ValueType <> TJSValueType.Undefined);
end;

class function TJSBuiltins.NumberToFixed(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  var FractionDigits := 0;
  if HasDigitCountArgument(Args) then
    FractionDigits := DigitCountArgument(Args);

  if not TJSNumberFormat.IsFractionDigitsInRange(FractionDigits) then
    raise TJSErrorFactory.RangeError(TO_FIXED_RANGE_MESSAGE);

  Result := TJSValue.CreateString(TJSNumberFormat.ToFixed(Num, FractionDigits));
end;

class function TJSBuiltins.NumberToPrecision(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  if not HasDigitCountArgument(Args) then
    Exit(TJSValue.CreateString(TJSNumberFormat.ToDecimalString(Num)));

  const Precision = DigitCountArgument(Args);
  const IsFinite = not (IsNan(Num) or IsInfinite(Num));
  if IsFinite and not TJSNumberFormat.IsPrecisionInRange(Precision) then
    raise TJSErrorFactory.RangeError(TO_PRECISION_RANGE_MESSAGE);

  Result := TJSValue.CreateString(TJSNumberFormat.ToPrecision(Num, Precision));
end;

class function TJSBuiltins.NumberToExponential(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  var FractionDigits := 0;
  if HasDigitCountArgument(Args) then
    FractionDigits := DigitCountArgument(Args);

  const IsFinite = not (IsNan(Num) or IsInfinite(Num));
  if IsFinite and not TJSNumberFormat.IsFractionDigitsInRange(FractionDigits) then
    raise TJSErrorFactory.RangeError(TO_EXPONENTIAL_RANGE_MESSAGE);

  if HasDigitCountArgument(Args) then
    Result := TJSValue.CreateString(TJSNumberFormat.ToExponential(Num, FractionDigits))
  else
    Result := TJSValue.CreateString(TJSNumberFormat.ToShortestExponential(Num));
end;

class function TJSBuiltins.NumberValueOf(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateNumber(Num);
end;

class function TJSBuiltins.CallArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  if MethodName = METHOD_PUSH then
    Exit(ArrayPush(Arr, Args, Limits));

  if MethodName = METHOD_POP then
    Exit(ArrayPop(Arr, Args));

  if MethodName = METHOD_SHIFT then
    Exit(ArrayShift(Arr, Args));

  if MethodName = METHOD_UNSHIFT then
    Exit(ArrayUnshift(Arr, Args, Limits));

  if MethodName = METHOD_JOIN then
    Exit(ArrayJoin(Arr, Args, Limits));

  if MethodName = METHOD_SLICE then
    Exit(ArraySlice(Arr, Args));

  if MethodName = METHOD_SPLICE then
    Exit(ArraySplice(Arr, Args, Limits));

  if MethodName = METHOD_CONCAT then
    Exit(ArrayConcat(Arr, Args, Limits));

  if MethodName = METHOD_REVERSE then
    Exit(ArrayReverse(Arr, Args));

  if MethodName = METHOD_TO_STRING then
    Exit(ArrayToString(Arr, Args, Limits));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallArrayMethodWithCallback(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue;
begin
  if MethodName = METHOD_SORT then
    Exit(ArraySort(Arr, Args, Executor, Limits));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallStringMethod(const Str: string; const MethodName: string; const Args: TArray<TJSValue>;
                                            const Executor: TJSCallbackExecutor; const Limits: TJSLimits): TJSValue;
begin
  if MethodName = METHOD_CHAR_AT then
    Exit(StringCharAt(Str, Args));

  if MethodName = METHOD_CHAR_CODE_AT then
    Exit(StringCharCodeAt(Str, Args));

  if MethodName = METHOD_CODE_POINT_AT then
    Exit(StringCodePointAt(Str, Args));

  if MethodName = METHOD_NORMALIZE then
    Exit(StringNormalize(Str, Args));

  if MethodName = METHOD_INDEX_OF then
    Exit(StringIndexOf(Str, Args, Limits));

  if MethodName = METHOD_LAST_INDEX_OF then
    Exit(StringLastIndexOf(Str, Args, Limits));

  if MethodName = METHOD_SUBSTRING then
    Exit(StringSubstring(Str, Args));

  if MethodName = METHOD_SUBSTR then
    Exit(StringSubstr(Str, Args));

  if MethodName = METHOD_SLICE then
    Exit(StringSlice(Str, Args));

  if (MethodName = METHOD_TO_LOWER_CASE) or (MethodName = METHOD_TO_LOCALE_LOWER_CASE) then
    Exit(StringToLowerCase(Str, Args));

  if (MethodName = METHOD_TO_UPPER_CASE) or (MethodName = METHOD_TO_LOCALE_UPPER_CASE) then
    Exit(StringToUpperCase(Str, Args));

  if MethodName = METHOD_LOCALE_COMPARE then
    Exit(StringLocaleCompare(Str, Args));

  if MethodName = METHOD_TRIM then
    Exit(StringTrim(Str, Args));

  if (MethodName = METHOD_TRIM_START) or (MethodName = METHOD_TRIM_LEFT) then
    Exit(StringTrimStart(Str, Args));

  if (MethodName = METHOD_TRIM_END) or (MethodName = METHOD_TRIM_RIGHT) then
    Exit(StringTrimEnd(Str, Args));

  if MethodName = METHOD_CONCAT then
    Exit(StringConcat(Str, Args, Limits));

  if MethodName = METHOD_REPEAT then
    Exit(StringRepeat(Str, Args, Limits));

  if MethodName = METHOD_AT then
    Exit(StringAt(Str, Args));

  if MethodName = METHOD_STARTS_WITH then
    Exit(StringStartsWith(Str, Args, Limits));

  if MethodName = METHOD_ENDS_WITH then
    Exit(StringEndsWith(Str, Args, Limits));

  if MethodName = METHOD_INCLUDES then
    Exit(StringIncludes(Str, Args, Limits));

  if MethodName = METHOD_PAD_START then
    Exit(StringPadStart(Str, Args, Limits));

  if MethodName = METHOD_PAD_END then
    Exit(StringPadEnd(Str, Args, Limits));

  if MethodName = METHOD_TO_STRING then
    Exit(StringToString(Str, Args));

  if MethodName = METHOD_VALUE_OF then
    Exit(StringValueOf(Str, Args));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallNumberMethod(const Num: Double; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_TO_STRING then
    Exit(NumberToString(Num, Args));

  if MethodName = METHOD_TO_FIXED then
    Exit(NumberToFixed(Num, Args));

  if MethodName = METHOD_TO_PRECISION then
    Exit(NumberToPrecision(Num, Args));

  if MethodName = METHOD_TO_EXPONENTIAL then
    Exit(NumberToExponential(Num, Args));

  if MethodName = METHOD_VALUE_OF then
    Exit(NumberValueOf(Num, Args));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.ArrayMethodNames: TArray<string>;
begin
  SetLength(Result, Length(ARRAY_METHOD_NAMES));
  for var Index := 0 to High(ARRAY_METHOD_NAMES) do
  begin
    Result[Index] := ARRAY_METHOD_NAMES[Index];
  end;
end;

class function TJSBuiltins.HasArrayMethod(const MethodName: string): Boolean;
begin
  Result := False;

  for var ArrayMethodName in ARRAY_METHOD_NAMES do
  begin
    if ArrayMethodName = MethodName then
      Exit(True);
  end;
end;

class function TJSBuiltins.RequiresCallback(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_MAP) or
            (MethodName = METHOD_FILTER) or
            (MethodName = METHOD_FOR_EACH) or
            (MethodName = METHOD_REDUCE) or
            (MethodName = METHOD_REDUCE_RIGHT) or
            (MethodName = METHOD_SOME) or
            (MethodName = METHOD_EVERY) or
            (MethodName = METHOD_SORT);
end;

class function TJSBuiltins.TakesCallbackThis(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_MAP) or
            (MethodName = METHOD_FILTER) or
            (MethodName = METHOD_FOR_EACH) or
            (MethodName = METHOD_SOME) or
            (MethodName = METHOD_EVERY) or
            (MethodName = METHOD_FIND) or
            (MethodName = METHOD_FIND_INDEX) or
            (MethodName = METHOD_FLAT_MAP);
end;

class function TJSBuiltins.StringMethodNames: TArray<string>;
begin
  SetLength(Result, Length(STRING_METHOD_NAMES));
  for var Index := 0 to High(STRING_METHOD_NAMES) do
  begin
    Result[Index] := STRING_METHOD_NAMES[Index];
  end;
end;

class function TJSBuiltins.NumberMethodNames: TArray<string>;
begin
  SetLength(Result, Length(NUMBER_METHOD_NAMES));
  for var Index := 0 to High(NUMBER_METHOD_NAMES) do
  begin
    Result[Index] := NUMBER_METHOD_NAMES[Index];
  end;
end;

class function TJSBuiltins.HasStringMethod(const MethodName: string): Boolean;
begin
  Result := False;

  for var StringMethodName in STRING_METHOD_NAMES do
  begin
    if StringMethodName = MethodName then
      Exit(True);
  end;
end;

class function TJSBuiltins.IsNumericStringArgument(const MethodName: string; const Index: Integer): Boolean;
begin
  const IsFirstNumeric = (MethodName = METHOD_CHAR_AT) or
                         (MethodName = METHOD_AT) or
                         (MethodName = METHOD_CHAR_CODE_AT) or
                         (MethodName = METHOD_CODE_POINT_AT) or
                         (MethodName = METHOD_REPEAT) or
                         (MethodName = METHOD_PAD_START) or
                         (MethodName = METHOD_PAD_END);

  const IsSecondNumeric = (MethodName = METHOD_INDEX_OF) or
                          (MethodName = METHOD_LAST_INDEX_OF) or
                          (MethodName = METHOD_STARTS_WITH) or
                          (MethodName = METHOD_ENDS_WITH) or
                          (MethodName = METHOD_INCLUDES);

  const IsBothNumeric = (MethodName = METHOD_SUBSTRING) or
                        (MethodName = METHOD_SUBSTR) or
                        (MethodName = METHOD_SLICE);

  case Index of
    0 : Result := IsFirstNumeric or IsBothNumeric;
    1 : Result := IsSecondNumeric or IsBothNumeric;
  else
    Result := False;
  end;
end;

class function TJSBuiltins.HasNumberMethod(const MethodName: string): Boolean;
begin
  Result := False;

  for var NumberMethodName in NUMBER_METHOD_NAMES do
  begin
    if NumberMethodName = MethodName then
      Exit(True);
  end;
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
  Result := [METHOD_HAS_OWN_PROPERTY, METHOD_PROPERTY_IS_ENUMERABLE];
end;

class function TJSBuiltins.HasObjectMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_HAS_OWN_PROPERTY) or
            (MethodName = METHOD_PROPERTY_IS_ENUMERABLE);
end;

class function TJSBuiltins.CallObjectMethod(const Obj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>; const Limits: TJSLimits): TJSValue;
begin
  if Length(Args) = 0 then
    Exit(TJSValue.CreateBoolean(False));

  const PropertyName = Args[0].ToPropertyKey(Limits);

  if MethodName = METHOD_HAS_OWN_PROPERTY then
  begin
    const HasOwnProperty = Obj.HasOwnProperty(PropertyName);
    Exit(TJSValue.CreateBoolean(HasOwnProperty));
  end;

  if MethodName = METHOD_PROPERTY_IS_ENUMERABLE then
  begin
    var Descriptor: TJSPropertyDescriptor;
    const IsEnumerable = TJSObjectOperations.TryGetOwnProperty(Obj, PropertyName, Descriptor) and Descriptor.Enumerable;

    Exit(TJSValue.CreateBoolean(IsEnumerable));
  end;

  Result := TJSValue.CreateUndefined;
end;

end.
