unit JS4D.Builtins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  System.Generics.Defaults,
  System.RegularExpressions,
  JS4D.Types;

type
  TJSCallbackExecutor = reference to function(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;

  TJSBuiltins = class
  private
    class function ArrayPush(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayPop(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayShift(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayUnshift(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayIndexOf(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayLastIndexOf(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayJoin(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArraySlice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArraySplice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayConcat(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayReverse(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayIncludes(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayFill(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayCopyWithin(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;
    class function ArrayToString(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;

    class function ArrayMap(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayFilter(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayForEach(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayReduce(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayReduceRight(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArraySome(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayEvery(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayFind(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayFindIndex(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArraySort(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ArrayFlat(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue; static;

    class function StringCharAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringCharCodeAt(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringIndexOf(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringLastIndexOf(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSubstring(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSubstr(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSlice(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSplit(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToLowerCase(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToUpperCase(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrim(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrimStart(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringTrimEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringReplace(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringConcat(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringRepeat(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringStartsWith(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringEndsWith(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringIncludes(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringPadStart(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringPadEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringToString(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringValueOf(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringMatch(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function StringSearch(const Str: string; const Args: TArray<TJSValue>): TJSValue; static;

    class function NumberToString(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToFixed(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToPrecision(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberToExponential(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;
    class function NumberValueOf(const Num: Double; const Args: TArray<TJSValue>): TJSValue; static;

  public
    class function CallArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function CallArrayMethodWithCallback(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue; static;
    class function CallStringMethod(const Str: string; const MethodName: string; const Args: TArray<TJSValue>): TJSValue; static;
    class function CallNumberMethod(const Num: Double; const MethodName: string; const Args: TArray<TJSValue>): TJSValue; static;

    class function HasArrayMethod(const MethodName: string): Boolean; static;
    class function HasStringMethod(const MethodName: string): Boolean; static;
    class function HasNumberMethod(const MethodName: string): Boolean; static;
    class function HasFunctionMethod(const MethodName: string): Boolean; static;
    class function HasObjectMethod(const MethodName: string): Boolean; static;

    class function CallObjectMethod(const Obj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue; static;

    class function RequiresCallback(const MethodName: string): Boolean; static;

    class function IsArrayMethod(const MethodName: string): Boolean; static;
    class function IsStringMethod(const MethodName: string): Boolean; static;
    class function IsNumberMethod(const MethodName: string): Boolean; static;
  end;

implementation

const
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
  METHOD_SUBSTRING = 'substring';
  METHOD_SUBSTR = 'substr';
  METHOD_SPLIT = 'split';
  METHOD_TO_LOWER_CASE = 'toLowerCase';
  METHOD_TO_UPPER_CASE = 'toUpperCase';
  METHOD_TRIM = 'trim';
  METHOD_TRIM_START = 'trimStart';
  METHOD_TRIM_LEFT = 'trimLeft';
  METHOD_TRIM_END = 'trimEnd';
  METHOD_TRIM_RIGHT = 'trimRight';
  METHOD_REPLACE = 'replace';
  METHOD_MATCH = 'match';
  METHOD_SEARCH = 'search';
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
  METHOD_CALL = 'call';
  METHOD_APPLY = 'apply';
  METHOD_BIND = 'bind';
  METHOD_HAS_OWN_PROPERTY = 'hasOwnProperty';
  DEFAULT_SEPARATOR: string = ',';
  EMPTY_STRING: string = '';
  SPACE_CHAR: string = ' ';

class function TJSBuiltins.ArrayPush(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
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

class function TJSBuiltins.ArrayUnshift(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const OriginalLength = Arr.Length;
  const ArgsLength = Length(Args);

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

class function TJSBuiltins.ArrayIndexOf(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  const SearchElement = Args[0];

  var FromIndex := 0;
  if Length(Args) > 1 then
    FromIndex := Trunc(Args[1].ToNumber);

  if FromIndex < 0 then
    FromIndex := Max(0, Arr.Length + FromIndex);

  for var Index := FromIndex to Arr.Length - 1 do
  begin
    const Element = Arr[Index];

    if Element.ValueType = SearchElement.ValueType then
    begin
      case Element.ValueType of
        TJSValueType.Number:
          if Element.AsNumber = SearchElement.AsNumber then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.String_:
          if Element.AsString = SearchElement.AsString then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.Boolean_:
          if Element.AsBoolean = SearchElement.AsBoolean then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.Null, TJSValueType.Undefined:
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        else
          if Element.ToObject = SearchElement.ToObject then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
      end;
    end;
  end;

  Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.ArrayLastIndexOf(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  const SearchElement = Args[0];

  var FromIndex := Arr.Length - 1;
  if Length(Args) > 1 then
  begin
    FromIndex := Trunc(Args[1].ToNumber);
    if FromIndex < 0 then
      FromIndex := Arr.Length + FromIndex;
  end;

  FromIndex := Min(FromIndex, Arr.Length - 1);

  for var Index := FromIndex downto 0 do
  begin
    const Element = Arr[Index];

    if Element.ValueType = SearchElement.ValueType then
    begin
      case Element.ValueType of
        TJSValueType.Number:
          if Element.AsNumber = SearchElement.AsNumber then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.String_:
          if Element.AsString = SearchElement.AsString then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.Boolean_:
          if Element.AsBoolean = SearchElement.AsBoolean then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        TJSValueType.Null, TJSValueType.Undefined:
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
        else
          if Element.ToObject = SearchElement.ToObject then
          begin
            Result := TJSValue.CreateNumber(Index);
            Exit;
          end;
      end;
    end;
  end;

  Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.ArrayJoin(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  var Separator := DEFAULT_SEPARATOR;

  if (Length(Args) > 0) and (not Args[0].IsUndefined) then
    Separator := Args[0].ToString;

  var StringBuilder := TStringBuilder.Create;
  try
    for var Index := 0 to Arr.Length - 1 do
    begin
      if Index > 0 then
        StringBuilder.Append(Separator);

      const Element = Arr[Index];

      if not Element.IsNullOrUndefined then
        StringBuilder.Append(Element.ToString);
    end;

    Result := TJSValue.CreateString(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.ArraySlice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const NewArr: IJSArray = TJSArray.Create;

  var StartIndex := 0;
  var EndIndex := Arr.Length;

  if Length(Args) > 0 then
  begin
    StartIndex := Trunc(Args[0].ToNumber);

    if StartIndex < 0 then
      StartIndex := Max(0, Arr.Length + StartIndex);
  end;

  if Length(Args) > 1 then
  begin
    EndIndex := Trunc(Args[1].ToNumber);

    if EndIndex < 0 then
      EndIndex := Max(0, Arr.Length + EndIndex);
  end;

  StartIndex := Min(StartIndex, Arr.Length);
  EndIndex := Min(EndIndex, Arr.Length);

  for var Index := StartIndex to EndIndex - 1 do
  begin
    NewArr.Push(Arr[Index]);
  end;

  Result := TJSValue.CreateObject(NewArr);
end;

class function TJSBuiltins.ArraySplice(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const Removed: IJSArray = TJSArray.Create;

  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(Removed);
    Exit;
  end;

  var StartIndex := Trunc(Args[0].ToNumber);

  if StartIndex < 0 then
    StartIndex := Max(0, Arr.Length + StartIndex);

  StartIndex := Min(StartIndex, Arr.Length);

  var DeleteCount := Arr.Length - StartIndex;

  if Length(Args) > 1 then
    DeleteCount := Min(Trunc(Args[1].ToNumber), Arr.Length - StartIndex);

  DeleteCount := Max(0, DeleteCount);

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

class function TJSBuiltins.ArrayConcat(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
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

class function TJSBuiltins.ArrayIncludes(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  const SearchElement = Args[0];

  var FromIndex := 0;
  if Length(Args) > 1 then
  begin
    FromIndex := Trunc(Args[1].ToNumber);
    if FromIndex < 0 then
      FromIndex := Max(0, Arr.Length + FromIndex);
  end;

  for var Index := FromIndex to Arr.Length - 1 do
  begin
    const Element = Arr[Index];

    if SearchElement.IsNaN and Element.IsNaN then
    begin
      Result := TJSValue.CreateBoolean(True);
      Exit;
    end;

    if Element.ValueType = SearchElement.ValueType then
    begin
      case Element.ValueType of
        TJSValueType.Number:
          if Element.AsNumber = SearchElement.AsNumber then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        TJSValueType.String_:
          if Element.AsString = SearchElement.AsString then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        TJSValueType.Boolean_:
          if Element.AsBoolean = SearchElement.AsBoolean then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        TJSValueType.Null, TJSValueType.Undefined:
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
        else
          if Element.ToObject = SearchElement.ToObject then
          begin
            Result := TJSValue.CreateBoolean(True);
            Exit;
          end;
      end;
    end;
  end;

  Result := TJSValue.CreateBoolean(False);
end;

class function TJSBuiltins.ArrayFill(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(Arr);
    Exit;
  end;

  const FillValue = Args[0];

  var StartIndex := 0;
  var EndIndex := Arr.Length;

  if Length(Args) > 1 then
  begin
    StartIndex := Trunc(Args[1].ToNumber);
    if StartIndex < 0 then
      StartIndex := Max(0, Arr.Length + StartIndex);
  end;

  if Length(Args) > 2 then
  begin
    EndIndex := Trunc(Args[2].ToNumber);
    if EndIndex < 0 then
      EndIndex := Max(0, Arr.Length + EndIndex);
  end;

  StartIndex := Min(StartIndex, Arr.Length);
  EndIndex := Min(EndIndex, Arr.Length);

  for var Index := StartIndex to EndIndex - 1 do
  begin
    Arr[Index] := FillValue;
  end;

  Result := TJSValue.CreateObject(Arr);
end;

class function TJSBuiltins.ArrayCopyWithin(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(Arr);
    Exit;
  end;

  var Target := Trunc(Args[0].ToNumber);
  if Target < 0 then
    Target := Max(0, Arr.Length + Target);
  Target := Min(Target, Arr.Length);

  var StartIndex := 0;
  if Length(Args) > 1 then
  begin
    StartIndex := Trunc(Args[1].ToNumber);
    if StartIndex < 0 then
      StartIndex := Max(0, Arr.Length + StartIndex);
  end;

  var EndIndex := Arr.Length;
  if Length(Args) > 2 then
  begin
    EndIndex := Trunc(Args[2].ToNumber);
    if EndIndex < 0 then
      EndIndex := Max(0, Arr.Length + EndIndex);
  end;

  const Count = Min(EndIndex - StartIndex, Arr.Length - Target);

  var TempArr: TArray<TJSValue>;
  SetLength(TempArr, Count);

  for var Index := 0 to Count - 1 do
  begin
    TempArr[Index] := Arr[StartIndex + Index];
  end;

  for var Index := 0 to Count - 1 do
  begin
    Arr[Target + Index] := TempArr[Index];
  end;

  Result := TJSValue.CreateObject(Arr);
end;

class function TJSBuiltins.ArrayToString(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := ArrayJoin(Arr, []);
end;

class function TJSBuiltins.ArrayMap(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  const ResultArr: IJSArray = TJSArray.Create;

  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const MappedValue = Executor(Callback, CallbackArgs);
    ResultArr.Push(MappedValue);
  end;

  Result := TJSValue.CreateObject(ResultArr);
end;

class function TJSBuiltins.ArrayFilter(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  const ResultArr: IJSArray = TJSArray.Create;

  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const Predicate = Executor(Callback, CallbackArgs);

    if Predicate.ToBoolean then
      ResultArr.Push(Element);
  end;

  Result := TJSValue.CreateObject(ResultArr);
end;

class function TJSBuiltins.ArrayForEach(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    Executor(Callback, CallbackArgs);
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.ArrayReduce(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  var Accumulator: TJSValue;
  var StartIndex := 0;

  if Length(Args) > 1 then
    Accumulator := Args[1]
  else if Arr.Length > 0 then
  begin
    Accumulator := Arr[0];
    StartIndex := 1;
  end
  else
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  for var Index := StartIndex to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Accumulator, Element, TJSValue.CreateNumber(Index), ArrValue];
    Accumulator := Executor(Callback, CallbackArgs);
  end;

  Result := Accumulator;
end;

class function TJSBuiltins.ArrayReduceRight(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  var Accumulator: TJSValue;
  var StartIndex := Arr.Length - 1;

  if Length(Args) > 1 then
    Accumulator := Args[1]
  else if Arr.Length > 0 then
  begin
    Accumulator := Arr[Arr.Length - 1];
    StartIndex := Arr.Length - 2;
  end
  else
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  for var Index := StartIndex downto 0 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Accumulator, Element, TJSValue.CreateNumber(Index), ArrValue];
    Accumulator := Executor(Callback, CallbackArgs);
  end;

  Result := Accumulator;
end;

class function TJSBuiltins.ArraySome(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const Predicate = Executor(Callback, CallbackArgs);

    if Predicate.ToBoolean then
    begin
      Result := TJSValue.CreateBoolean(True);
      Exit;
    end;
  end;

  Result := TJSValue.CreateBoolean(False);
end;

class function TJSBuiltins.ArrayEvery(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const Predicate = Executor(Callback, CallbackArgs);

    if not Predicate.ToBoolean then
    begin
      Result := TJSValue.CreateBoolean(False);
      Exit;
    end;
  end;

  Result := TJSValue.CreateBoolean(True);
end;

class function TJSBuiltins.ArrayFind(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const Predicate = Executor(Callback, CallbackArgs);

    if Predicate.ToBoolean then
    begin
      Result := Element;
      Exit;
    end;
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.ArrayFindIndex(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  if not Args[0].IsFunction then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  var Callback: IJSFunction;
  if not Supports(Args[0].ToObject, IJSFunction, Callback) then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;
  const ArrValue = TJSValue.CreateObject(Arr);

  for var Index := 0 to Arr.Length - 1 do
  begin
    const Element = Arr[Index];
    const CallbackArgs: TArray<TJSValue> = [Element, TJSValue.CreateNumber(Index), ArrValue];
    const Predicate = Executor(Callback, CallbackArgs);

    if Predicate.ToBoolean then
    begin
      Result := TJSValue.CreateNumber(Index);
      Exit;
    end;
  end;

  Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.ArraySort(const Arr: IJSArray; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
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

  var Elements: TArray<TJSValue>;
  SetLength(Elements, Arr.Length);

  for var Index := 0 to Arr.Length - 1 do
  begin
    Elements[Index] := Arr[Index];
  end;

  for var OuterIndex := 0 to Length(Elements) - 2 do
  begin
    for var InnerIndex := 0 to Length(Elements) - OuterIndex - 2 do
    begin
      var CompareResult: Double;

      if HasComparer then
      begin
        const CallbackArgs: TArray<TJSValue> = [Elements[InnerIndex], Elements[InnerIndex + 1]];
        CompareResult := Executor(Comparer, CallbackArgs).ToNumber;
      end
      else
      begin
        const StrA = Elements[InnerIndex].ToString;
        const StrB = Elements[InnerIndex + 1].ToString;

        if StrA < StrB then
          CompareResult := -1
        else if StrA > StrB then
          CompareResult := 1
        else
          CompareResult := 0;
      end;

      if CompareResult > 0 then
      begin
        const Temp = Elements[InnerIndex];
        Elements[InnerIndex] := Elements[InnerIndex + 1];
        Elements[InnerIndex + 1] := Temp;
      end;
    end;
  end;

  for var Index := 0 to Length(Elements) - 1 do
  begin
    Arr[Index] := Elements[Index];
  end;

  Result := TJSValue.CreateObject(Arr);
end;

class function TJSBuiltins.ArrayFlat(const Arr: IJSArray; const Args: TArray<TJSValue>): TJSValue;

  procedure FlattenArray(const Source: IJSArray; const Target: IJSArray; const Depth: Integer);
  begin
    for var Index := 0 to Source.Length - 1 do
    begin
      const Element = Source[Index];

      if Element.IsArray and (Depth > 0) then
      begin
        var NestedArr: IJSArray;
        if Supports(Element.ToObject, IJSArray, NestedArr) then
          FlattenArray(NestedArr, Target, Depth - 1)
        else
          Target.Push(Element);
      end
      else
        Target.Push(Element);
    end;
  end;

begin
  const ResultArr: IJSArray = TJSArray.Create;

  var Depth := 1;

  if Length(Args) > 0 then
  begin
    const DepthArg = Args[0].ToNumber;

    if not IsNaN(DepthArg) then
      Depth := Max(0, Trunc(DepthArg));
  end;

  FlattenArray(Arr, ResultArr, Depth);

  Result := TJSValue.CreateObject(ResultArr);
end;

class function TJSBuiltins.StringCharAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Index := 0;

  if Length(Args) > 0 then
    Index := Trunc(Args[0].ToNumber);

  if (Index >= 0) and (Index < Length(Str)) then
    Result := TJSValue.CreateString(Str[Index + 1])
  else
    Result := TJSValue.CreateString(EMPTY_STRING);
end;

class function TJSBuiltins.StringCharCodeAt(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var Index := 0;

  if Length(Args) > 0 then
    Index := Trunc(Args[0].ToNumber);

  if (Index >= 0) and (Index < Length(Str)) then
    Result := TJSValue.CreateNumber(Ord(Str[Index + 1]))
  else
    Result := TJSValue.CreateNaN;
end;

class function TJSBuiltins.StringIndexOf(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  const SearchStr = Args[0].ToString;

  var FromIndex := 1;

  if Length(Args) > 1 then
    FromIndex := Max(1, Trunc(Args[1].ToNumber) + 1);

  const Position = Pos(SearchStr, Str, FromIndex);

  if Position > 0 then
    Result := TJSValue.CreateNumber(Position - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.StringLastIndexOf(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  const SearchStr = Args[0].ToString;

  var MaxIndex := Length(Str);

  if Length(Args) > 1 then
  begin
    const ArgValue = Args[1].ToNumber;

    if not IsNaN(ArgValue) then
      MaxIndex := Min(Trunc(ArgValue) + Length(SearchStr), Length(Str));
  end;

  const SearchIn = Copy(Str, 1, MaxIndex);
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
  var StartIndex := 0;
  var EndIndex := Length(Str);

  if Length(Args) > 0 then
  begin
    const StartArg = Args[0].ToNumber;

    if not IsNaN(StartArg) then
      StartIndex := Max(0, Trunc(StartArg));
  end;

  if Length(Args) > 1 then
  begin
    const EndArg = Args[1].ToNumber;

    if not IsNaN(EndArg) then
      EndIndex := Max(0, Trunc(EndArg));
  end;

  if StartIndex > EndIndex then
  begin
    const Temp = StartIndex;
    StartIndex := EndIndex;
    EndIndex := Temp;
  end;

  StartIndex := Min(StartIndex, Length(Str));
  EndIndex := Min(EndIndex, Length(Str));

  Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringSubstr(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var StartIndex := 0;
  var CharCount := Length(Str);

  if Length(Args) > 0 then
  begin
    StartIndex := Trunc(Args[0].ToNumber);

    if StartIndex < 0 then
      StartIndex := Max(0, Length(Str) + StartIndex);
  end;

  if Length(Args) > 1 then
    CharCount := Max(0, Trunc(Args[1].ToNumber));

  StartIndex := Min(StartIndex, Length(Str));
  CharCount := Min(CharCount, Length(Str) - StartIndex);

  Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, CharCount));
end;

class function TJSBuiltins.StringSlice(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var StartIndex := 0;
  var EndIndex := Length(Str);

  if Length(Args) > 0 then
  begin
    StartIndex := Trunc(Args[0].ToNumber);

    if StartIndex < 0 then
      StartIndex := Max(0, Length(Str) + StartIndex);
  end;

  if Length(Args) > 1 then
  begin
    EndIndex := Trunc(Args[1].ToNumber);

    if EndIndex < 0 then
      EndIndex := Max(0, Length(Str) + EndIndex);
  end;

  StartIndex := Min(StartIndex, Length(Str));
  EndIndex := Min(EndIndex, Length(Str));

  if StartIndex >= EndIndex then
    Result := TJSValue.CreateString(EMPTY_STRING)
  else
    Result := TJSValue.CreateString(Copy(Str, StartIndex + 1, EndIndex - StartIndex));
end;

class function TJSBuiltins.StringSplit(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  const ResultArr: IJSArray = TJSArray.Create;

  if Length(Args) = 0 then
  begin
    ResultArr.Push(TJSValue.CreateString(Str));
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  const Separator = Args[0];

  var LimitValue := MaxInt;

  if Length(Args) > 1 then
    LimitValue := Max(0, Trunc(Args[1].ToNumber));

  if LimitValue = 0 then
  begin
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  if Separator.IsUndefined then
  begin
    ResultArr.Push(TJSValue.CreateString(Str));
    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  var RegExpIntf: IJSRegExp;
  if Separator.IsObject and Supports(Separator.ToObject, IJSRegExp, RegExpIntf) then
  begin
    const SplitResult = RegExpIntf.Split(Str, LimitValue);

    for var Index := 0 to SplitResult.Length - 1 do
    begin
      ResultArr.Push(SplitResult[Index]);
    end;

    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  const SepStr = Separator.ToString;

  if SepStr = EMPTY_STRING then
  begin
    for var Index := 1 to Min(Length(Str), LimitValue) do
    begin
      ResultArr.Push(TJSValue.CreateString(Str[Index]));
    end;

    Result := TJSValue.CreateObject(ResultArr);
    Exit;
  end;

  var CurrentPos := 1;
  var Count := 0;

  while (CurrentPos <= Length(Str)) and (Count < LimitValue) do
  begin
    const NextPos = Pos(SepStr, Str, CurrentPos);

    if NextPos = 0 then
    begin
      ResultArr.Push(TJSValue.CreateString(Copy(Str, CurrentPos, Length(Str) - CurrentPos + 1)));
      Break;
    end;

    ResultArr.Push(TJSValue.CreateString(Copy(Str, CurrentPos, NextPos - CurrentPos)));
    CurrentPos := NextPos + Length(SepStr);
    Inc(Count);
  end;

  if (CurrentPos > Length(Str)) and (Count < LimitValue) then
    ResultArr.Push(TJSValue.CreateString(EMPTY_STRING));

  Result := TJSValue.CreateObject(ResultArr);
end;

class function TJSBuiltins.StringToLowerCase(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(LowerCase(Str));
end;

class function TJSBuiltins.StringToUpperCase(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(UpperCase(Str));
end;

class function TJSBuiltins.StringTrim(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(Trim(Str));
end;

class function TJSBuiltins.StringTrimStart(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(TrimLeft(Str));
end;

class function TJSBuiltins.StringTrimEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateString(TrimRight(Str));
end;

class function TJSBuiltins.StringReplace(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) < 2 then
  begin
    Result := TJSValue.CreateString(Str);
    Exit;
  end;

  const ReplaceValue = Args[1].ToString;

  var RegExpIntf: IJSRegExp;
  if Args[0].IsObject and Supports(Args[0].ToObject, IJSRegExp, RegExpIntf) then
  begin
    Result := TJSValue.CreateString(RegExpIntf.Replace(Str, ReplaceValue));
    Exit;
  end;

  const SearchValue = Args[0].ToString;
  const Position = Pos(SearchValue, Str);

  if Position > 0 then
    Result := TJSValue.CreateString(
      Copy(Str, 1, Position - 1) + ReplaceValue + Copy(Str, Position + Length(SearchValue), MaxInt))
  else
    Result := TJSValue.CreateString(Str);
end;

class function TJSBuiltins.StringConcat(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  var StringBuilder := TStringBuilder.Create;
  try
    StringBuilder.Append(Str);

    for var Arg in Args do
    begin
      StringBuilder.Append(Arg.ToString);
    end;

    Result := TJSValue.CreateString(StringBuilder.ToString);
  finally
    StringBuilder.Free;
  end;
end;

class function TJSBuiltins.StringRepeat(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

  const Count = Trunc(Args[0].ToNumber);

  if Count <= 0 then
  begin
    Result := TJSValue.CreateString(EMPTY_STRING);
    Exit;
  end;

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

class function TJSBuiltins.StringStartsWith(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;

  const SearchStr = Args[0].ToString;

  var Position := 0;

  if Length(Args) > 1 then
    Position := Max(0, Trunc(Args[1].ToNumber));

  const SubStr = Copy(Str, Position + 1, Length(SearchStr));

  Result := TJSValue.CreateBoolean(SubStr = SearchStr);
end;

class function TJSBuiltins.StringEndsWith(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;

  const SearchStr = Args[0].ToString;

  var EndPosition := Length(Str);

  if Length(Args) > 1 then
    EndPosition := Min(Trunc(Args[1].ToNumber), Length(Str));

  if EndPosition < Length(SearchStr) then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  const SubStr = Copy(Str, EndPosition - Length(SearchStr) + 1, Length(SearchStr));

  Result := TJSValue.CreateBoolean(SubStr = SearchStr);
end;

class function TJSBuiltins.StringIncludes(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateBoolean(True);
    Exit;
  end;

  const SearchStr = Args[0].ToString;

  var Position := 1;

  if Length(Args) > 1 then
    Position := Max(1, Trunc(Args[1].ToNumber) + 1);

  Result := TJSValue.CreateBoolean(Pos(SearchStr, Str, Position) > 0);
end;

class function TJSBuiltins.StringPadStart(const Str: string; const Args: TArray<TJSValue>): TJSValue;
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
    PadStr := Args[1].ToString;

    if PadStr = EMPTY_STRING then
    begin
      Result := TJSValue.CreateString(Str);
      Exit;
    end;
  end;

  const PadLength = TargetLength - Length(Str);
  var Padding := EMPTY_STRING;

  while Length(Padding) < PadLength do
  begin
    Padding := Padding + PadStr;
  end;

  Padding := Copy(Padding, 1, PadLength);

  Result := TJSValue.CreateString(Padding + Str);
end;

class function TJSBuiltins.StringPadEnd(const Str: string; const Args: TArray<TJSValue>): TJSValue;
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
    PadStr := Args[1].ToString;

    if PadStr = EMPTY_STRING then
    begin
      Result := TJSValue.CreateString(Str);
      Exit;
    end;
  end;

  const PadLength = TargetLength - Length(Str);
  var Padding := EMPTY_STRING;

  while Length(Padding) < PadLength do
  begin
    Padding := Padding + PadStr;
  end;

  Padding := Copy(Padding, 1, PadLength);

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

class function TJSBuiltins.StringMatch(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  var RegExpIntf: IJSRegExp;
  if Args[0].IsObject and Supports(Args[0].ToObject, IJSRegExp, RegExpIntf) then
  begin
    Result := RegExpIntf.Match(Str);
    Exit;
  end;

  const SearchStr = Args[0].ToString;
  const Position = Pos(SearchStr, Str);

  if Position > 0 then
  begin
    const ResultArr: IJSArray = TJSArray.Create;
    ResultArr.Push(TJSValue.CreateString(SearchStr));
    ResultArr.SetProperty('index', TJSValue.CreateNumber(Position - 1));
    ResultArr.SetProperty('input', TJSValue.CreateString(Str));
    Result := TJSValue.CreateObject(ResultArr);
  end
  else
    Result := TJSValue.CreateNull;
end;

class function TJSBuiltins.StringSearch(const Str: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  var RegExpIntf: IJSRegExp;
  if Args[0].IsObject and Supports(Args[0].ToObject, IJSRegExp, RegExpIntf) then
  begin
    Result := TJSValue.CreateNumber(RegExpIntf.Search(Str));
    Exit;
  end;

  const SearchStr = Args[0].ToString;
  const Position = Pos(SearchStr, Str);

  if Position > 0 then
    Result := TJSValue.CreateNumber(Position - 1)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSBuiltins.NumberToString(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(TJSValue.CreateNumber(Num).ToString);
    Exit;
  end;

  const Radix = Trunc(Args[0].ToNumber);

  if (Radix < 2) or (Radix > 36) then
  begin
    Result := TJSValue.CreateString(TJSValue.CreateNumber(Num).ToString);
    Exit;
  end;

  if Radix = 10 then
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

class function TJSBuiltins.NumberToFixed(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  var Digits := 0;

  if Length(Args) > 0 then
    Digits := Max(0, Min(100, Trunc(Args[0].ToNumber)));

  Result := TJSValue.CreateString(FormatFloat('0.' + System.StringOfChar('0', Digits), Num));
end;

class function TJSBuiltins.NumberToPrecision(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) = 0 then
  begin
    Result := TJSValue.CreateString(TJSValue.CreateNumber(Num).ToString);
    Exit;
  end;

  const Precision = Max(1, Min(100, Trunc(Args[0].ToNumber)));

  var FormatStr: string := '0';

  if Precision > 1 then
  begin
    const DecimalPart: string = System.StringOfChar('#', Precision - 1);
    FormatStr := FormatStr + '.' + DecimalPart;
  end;

  Result := TJSValue.CreateString(FormatFloat(FormatStr, Num));
end;

class function TJSBuiltins.NumberToExponential(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  var Digits := 6;

  if Length(Args) > 0 then
    Digits := Max(0, Min(100, Trunc(Args[0].ToNumber)));

  var FormatSettings := TFormatSettings.Create;
  FormatSettings.DecimalSeparator := '.';

  Result := TJSValue.CreateString(Format('%.' + IntToStr(Digits) + 'e', [Num], FormatSettings));
end;

class function TJSBuiltins.NumberValueOf(const Num: Double; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateNumber(Num);
end;

class function TJSBuiltins.CallArrayMethod(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_PUSH then
    Exit(ArrayPush(Arr, Args));

  if MethodName = METHOD_POP then
    Exit(ArrayPop(Arr, Args));

  if MethodName = METHOD_SHIFT then
    Exit(ArrayShift(Arr, Args));

  if MethodName = METHOD_UNSHIFT then
    Exit(ArrayUnshift(Arr, Args));

  if MethodName = METHOD_INDEX_OF then
    Exit(ArrayIndexOf(Arr, Args));

  if MethodName = METHOD_LAST_INDEX_OF then
    Exit(ArrayLastIndexOf(Arr, Args));

  if MethodName = METHOD_JOIN then
    Exit(ArrayJoin(Arr, Args));

  if MethodName = METHOD_SLICE then
    Exit(ArraySlice(Arr, Args));

  if MethodName = METHOD_SPLICE then
    Exit(ArraySplice(Arr, Args));

  if MethodName = METHOD_CONCAT then
    Exit(ArrayConcat(Arr, Args));

  if MethodName = METHOD_REVERSE then
    Exit(ArrayReverse(Arr, Args));

  if MethodName = METHOD_INCLUDES then
    Exit(ArrayIncludes(Arr, Args));

  if MethodName = METHOD_FILL then
    Exit(ArrayFill(Arr, Args));

  if MethodName = METHOD_COPY_WITHIN then
    Exit(ArrayCopyWithin(Arr, Args));

  if MethodName = METHOD_TO_STRING then
    Exit(ArrayToString(Arr, Args));

  if MethodName = METHOD_FLAT then
    Exit(ArrayFlat(Arr, Args));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallArrayMethodWithCallback(const Arr: IJSArray; const MethodName: string; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor): TJSValue;
begin
  if MethodName = METHOD_MAP then
    Exit(ArrayMap(Arr, Args, Executor));

  if MethodName = METHOD_FILTER then
    Exit(ArrayFilter(Arr, Args, Executor));

  if MethodName = METHOD_FOR_EACH then
    Exit(ArrayForEach(Arr, Args, Executor));

  if MethodName = METHOD_REDUCE then
    Exit(ArrayReduce(Arr, Args, Executor));

  if MethodName = METHOD_REDUCE_RIGHT then
    Exit(ArrayReduceRight(Arr, Args, Executor));

  if MethodName = METHOD_SOME then
    Exit(ArraySome(Arr, Args, Executor));

  if MethodName = METHOD_EVERY then
    Exit(ArrayEvery(Arr, Args, Executor));

  if MethodName = METHOD_FIND then
    Exit(ArrayFind(Arr, Args, Executor));

  if MethodName = METHOD_FIND_INDEX then
    Exit(ArrayFindIndex(Arr, Args, Executor));

  if MethodName = METHOD_SORT then
    Exit(ArraySort(Arr, Args, Executor));

  Result := TJSValue.CreateUndefined;
end;

class function TJSBuiltins.CallStringMethod(const Str: string; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_CHAR_AT then
    Exit(StringCharAt(Str, Args));

  if MethodName = METHOD_CHAR_CODE_AT then
    Exit(StringCharCodeAt(Str, Args));

  if MethodName = METHOD_INDEX_OF then
    Exit(StringIndexOf(Str, Args));

  if MethodName = METHOD_LAST_INDEX_OF then
    Exit(StringLastIndexOf(Str, Args));

  if MethodName = METHOD_SUBSTRING then
    Exit(StringSubstring(Str, Args));

  if MethodName = METHOD_SUBSTR then
    Exit(StringSubstr(Str, Args));

  if MethodName = METHOD_SLICE then
    Exit(StringSlice(Str, Args));

  if MethodName = METHOD_SPLIT then
    Exit(StringSplit(Str, Args));

  if MethodName = METHOD_TO_LOWER_CASE then
    Exit(StringToLowerCase(Str, Args));

  if MethodName = METHOD_TO_UPPER_CASE then
    Exit(StringToUpperCase(Str, Args));

  if MethodName = METHOD_TRIM then
    Exit(StringTrim(Str, Args));

  if (MethodName = METHOD_TRIM_START) or (MethodName = METHOD_TRIM_LEFT) then
    Exit(StringTrimStart(Str, Args));

  if (MethodName = METHOD_TRIM_END) or (MethodName = METHOD_TRIM_RIGHT) then
    Exit(StringTrimEnd(Str, Args));

  if MethodName = METHOD_REPLACE then
    Exit(StringReplace(Str, Args));

  if MethodName = METHOD_MATCH then
    Exit(StringMatch(Str, Args));

  if MethodName = METHOD_SEARCH then
    Exit(StringSearch(Str, Args));

  if MethodName = METHOD_CONCAT then
    Exit(StringConcat(Str, Args));

  if MethodName = METHOD_REPEAT then
    Exit(StringRepeat(Str, Args));

  if MethodName = METHOD_STARTS_WITH then
    Exit(StringStartsWith(Str, Args));

  if MethodName = METHOD_ENDS_WITH then
    Exit(StringEndsWith(Str, Args));

  if MethodName = METHOD_INCLUDES then
    Exit(StringIncludes(Str, Args));

  if MethodName = METHOD_PAD_START then
    Exit(StringPadStart(Str, Args));

  if MethodName = METHOD_PAD_END then
    Exit(StringPadEnd(Str, Args));

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

class function TJSBuiltins.HasArrayMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_PUSH) or
            (MethodName = METHOD_POP) or
            (MethodName = METHOD_SHIFT) or
            (MethodName = METHOD_UNSHIFT) or
            (MethodName = METHOD_INDEX_OF) or
            (MethodName = METHOD_LAST_INDEX_OF) or
            (MethodName = METHOD_JOIN) or
            (MethodName = METHOD_SLICE) or
            (MethodName = METHOD_SPLICE) or
            (MethodName = METHOD_CONCAT) or
            (MethodName = METHOD_REVERSE) or
            (MethodName = METHOD_INCLUDES) or
            (MethodName = METHOD_FILL) or
            (MethodName = METHOD_COPY_WITHIN) or
            (MethodName = METHOD_TO_STRING) or
            (MethodName = METHOD_FLAT) or
            (MethodName = METHOD_MAP) or
            (MethodName = METHOD_FILTER) or
            (MethodName = METHOD_FOR_EACH) or
            (MethodName = METHOD_REDUCE) or
            (MethodName = METHOD_REDUCE_RIGHT) or
            (MethodName = METHOD_SOME) or
            (MethodName = METHOD_EVERY) or
            (MethodName = METHOD_FIND) or
            (MethodName = METHOD_FIND_INDEX) or
            (MethodName = METHOD_SORT);
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
            (MethodName = METHOD_FIND) or
            (MethodName = METHOD_FIND_INDEX) or
            (MethodName = METHOD_SORT);
end;

class function TJSBuiltins.HasStringMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_CHAR_AT) or
            (MethodName = METHOD_CHAR_CODE_AT) or
            (MethodName = METHOD_INDEX_OF) or
            (MethodName = METHOD_LAST_INDEX_OF) or
            (MethodName = METHOD_SUBSTRING) or
            (MethodName = METHOD_SUBSTR) or
            (MethodName = METHOD_SLICE) or
            (MethodName = METHOD_SPLIT) or
            (MethodName = METHOD_TO_LOWER_CASE) or
            (MethodName = METHOD_TO_UPPER_CASE) or
            (MethodName = METHOD_TRIM) or
            (MethodName = METHOD_TRIM_START) or
            (MethodName = METHOD_TRIM_LEFT) or
            (MethodName = METHOD_TRIM_END) or
            (MethodName = METHOD_TRIM_RIGHT) or
            (MethodName = METHOD_REPLACE) or
            (MethodName = METHOD_MATCH) or
            (MethodName = METHOD_SEARCH) or
            (MethodName = METHOD_CONCAT) or
            (MethodName = METHOD_REPEAT) or
            (MethodName = METHOD_STARTS_WITH) or
            (MethodName = METHOD_ENDS_WITH) or
            (MethodName = METHOD_INCLUDES) or
            (MethodName = METHOD_PAD_START) or
            (MethodName = METHOD_PAD_END) or
            (MethodName = METHOD_TO_STRING) or
            (MethodName = METHOD_VALUE_OF);
end;

class function TJSBuiltins.HasNumberMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_TO_STRING) or
            (MethodName = METHOD_TO_FIXED) or
            (MethodName = METHOD_TO_PRECISION) or
            (MethodName = METHOD_TO_EXPONENTIAL) or
            (MethodName = METHOD_VALUE_OF);
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

class function TJSBuiltins.HasObjectMethod(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_HAS_OWN_PROPERTY);
end;

class function TJSBuiltins.CallObjectMethod(const Obj: IJSObject; const MethodName: string; const Args: TArray<TJSValue>): TJSValue;
begin
  if MethodName = METHOD_HAS_OWN_PROPERTY then
  begin
    if Length(Args) = 0 then
      Result := TJSValue.CreateBoolean(False)
    else
      Result := TJSValue.CreateBoolean(Obj.HasProperty(Args[0].ToString));
  end
  else
    Result := TJSValue.CreateUndefined;
end;

end.
