unit JS4D.ArrayGeneric;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Builtins,
  JS4D.ArrayLike;

type
  TJSArrayGenericContext = record
    ArrayPrototype: IJSObject;
    ObjectPrototype: IJSObject;
    Limits: TJSLimits;
    Executor: TJSCallbackExecutor;
  end;

  TJSArrayGeneric = class
  private
    const
      METHOD_PUSH = 'push';
      METHOD_POP = 'pop';
      METHOD_SHIFT = 'shift';
      METHOD_UNSHIFT = 'unshift';
      METHOD_SPLICE = 'splice';
      METHOD_SLICE = 'slice';
      METHOD_REVERSE = 'reverse';
      METHOD_JOIN = 'join';
      METHOD_CONCAT = 'concat';
      METHOD_SORT = 'sort';
      METHOD_TO_STRING = 'toString';
      METHOD_FILL = 'fill';
      METHOD_COPY_WITHIN = 'copyWithin';
      DEFAULT_SEPARATOR = ',';
      NOT_CALLED_ON_OBJECT = 'Array.prototype.%s called on null or undefined';

    class function Push(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;
    class function Pop(const Target: IJSObject): TJSValue; static;
    class function Shift(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue; static;
    class function Unshift(const Target: IJSObject; const Args: TArray<TJSValue>;
                           const Context: TJSArrayGenericContext): TJSValue; static;
    class function Splice(const Target: IJSObject; const Args: TArray<TJSValue>;
                          const Context: TJSArrayGenericContext): TJSValue; static;
    class function Slice(const Target: IJSObject; const Args: TArray<TJSValue>;
                         const Context: TJSArrayGenericContext): TJSValue; static;
    class function Reverse(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue; static;
    class function Join(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
    class function Concat(const Target: IJSObject; const Args: TArray<TJSValue>;
                          const Context: TJSArrayGenericContext): TJSValue; static;
    class function Sort(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
    class function ToText(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue; static;
    class function Fill(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
    class function CopyWithin(const Target: IJSObject; const Args: TArray<TJSValue>;
                              const Context: TJSArrayGenericContext): TJSValue; static;
    class procedure MoveRange(const Target: IJSObject; const FromIndex, ToIndex, Count: Int64); static;

    class function CopyRange(const Source: IJSObject; const FirstIndex, Count: Int64;
                             const Context: TJSArrayGenericContext): IJSArray; static;
    class function SpliceDeleteCount(const Args: TArray<TJSValue>; const Count, Start: Int64): Int64; static;
    class procedure ShiftTailDown(const Target: IJSObject; const Count, Start, DeleteCount, ItemCount: Int64); static;
    class procedure ShiftTailUp(const Target: IJSObject; const Count, Start, DeleteCount, ItemCount: Int64); static;
    class procedure SwapMirroredElements(const Target: IJSObject; const LowerIndex, UpperIndex: Int64); static;
    class procedure AppendConcatItem(const Item: TJSValue; const Combined: IJSArray; var NextIndex: Int64;
                                     const Context: TJSArrayGenericContext); static;
    class procedure WriteSortedElements(const Target: IJSObject; const Sorted: IJSArray;
                                        const UndefinedCount, Count: Int64); static;

  public
    class function Handles(const MethodName: string): Boolean; static;
    class function AlwaysUsesPropertySemantics(const MethodName: string): Boolean; static;
    class function CreatesResultArray(const MethodName: string): Boolean; static;
    class function Call(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
  end;

implementation

class function TJSArrayGeneric.Handles(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_PUSH) or
            (MethodName = METHOD_POP) or
            (MethodName = METHOD_SHIFT) or
            (MethodName = METHOD_UNSHIFT) or
            (MethodName = METHOD_SPLICE) or
            (MethodName = METHOD_SLICE) or
            (MethodName = METHOD_REVERSE) or
            (MethodName = METHOD_JOIN) or
            (MethodName = METHOD_CONCAT) or
            (MethodName = METHOD_SORT) or
            (MethodName = METHOD_TO_STRING) or
            AlwaysUsesPropertySemantics(MethodName);
end;

class function TJSArrayGeneric.AlwaysUsesPropertySemantics(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_FILL) or
            (MethodName = METHOD_COPY_WITHIN);
end;

class function TJSArrayGeneric.CreatesResultArray(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_SPLICE) or
            (MethodName = METHOD_SLICE) or
            (MethodName = METHOD_CONCAT);
end;

class function TJSArrayGeneric.Call(const Target: IJSObject; const MethodName: string;
                                    const Args: TArray<TJSValue>; const Context: TJSArrayGenericContext): TJSValue;
begin
  if not Assigned(Target) then
    raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_OBJECT, [MethodName]));

  if MethodName = METHOD_PUSH then
    Exit(Push(Target, Args));

  if MethodName = METHOD_POP then
    Exit(Pop(Target));

  if MethodName = METHOD_SHIFT then
    Exit(Shift(Target, Context));

  if MethodName = METHOD_UNSHIFT then
    Exit(Unshift(Target, Args, Context));

  if MethodName = METHOD_SPLICE then
    Exit(Splice(Target, Args, Context));

  if MethodName = METHOD_SLICE then
    Exit(Slice(Target, Args, Context));

  if MethodName = METHOD_REVERSE then
    Exit(Reverse(Target, Context));

  if MethodName = METHOD_JOIN then
    Exit(Join(Target, Args, Context));

  if MethodName = METHOD_CONCAT then
    Exit(Concat(Target, Args, Context));

  if MethodName = METHOD_SORT then
    Exit(Sort(Target, Args, Context));

  if MethodName = METHOD_TO_STRING then
    Exit(ToText(Target, Context));

  if MethodName = METHOD_FILL then
    Exit(Fill(Target, Args, Context));

  if MethodName = METHOD_COPY_WITHIN then
    Exit(CopyWithin(Target, Args, Context));

  raise ENotSupportedException.CreateFmt('Unsupported generic array method: %s', [MethodName]);
end;

class function TJSArrayGeneric.Push(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var Count := TJSArrayLike.ToLength(Target);

  for var Item in Args do
  begin
    TJSArrayLike.SetElement(Target, Count, Item);
    Inc(Count);
  end;

  TJSArrayLike.WriteLength(Target, Count);
  Result := TJSValue.CreateNumber(Count);
end;

class function TJSArrayGeneric.Pop(const Target: IJSObject): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const IsEmpty = (Count = 0);
  if IsEmpty then
  begin
    TJSArrayLike.WriteLength(Target, 0);
    Exit(TJSValue.CreateUndefined);
  end;

  const LastIndex = Count - 1;
  Result := Target.GetProperty(TJSArrayLike.IndexName(LastIndex));
  TJSArrayLike.DeleteElement(Target, LastIndex);
  TJSArrayLike.WriteLength(Target, LastIndex);
end;

class function TJSArrayGeneric.Shift(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const IsEmpty = (Count = 0);
  if IsEmpty then
  begin
    TJSArrayLike.WriteLength(Target, 0);
    Exit(TJSValue.CreateUndefined);
  end;

  Context.Limits.EnsureArrayLength(Count);

  Result := Target.GetProperty(TJSArrayLike.IndexName(0));
  for var Index: Int64 := 1 to Count - 1 do
  begin
    TJSArrayLike.MoveElement(Target, Index, Index - 1);
  end;

  TJSArrayLike.DeleteElement(Target, Count - 1);
  TJSArrayLike.WriteLength(Target, Count - 1);
end;

class function TJSArrayGeneric.Unshift(const Target: IJSObject; const Args: TArray<TJSValue>;
                                       const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const ItemCount = Length(Args);

  const HasItems = (ItemCount > 0);
  if HasItems then
  begin
    Context.Limits.EnsureArrayLength(Count);

    for var Index: Int64 := Count downto 1 do
    begin
      TJSArrayLike.MoveElement(Target, Index - 1, Index + ItemCount - 1);
    end;

    for var Position := 0 to ItemCount - 1 do
    begin
      TJSArrayLike.SetElement(Target, Position, Args[Position]);
    end;
  end;

  TJSArrayLike.WriteLength(Target, Count + ItemCount);
  Result := TJSValue.CreateNumber(Count + ItemCount);
end;

class function TJSArrayGeneric.Splice(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Start = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 0), Count, 0);
  const DeleteCount = SpliceDeleteCount(Args, Count, Start);
  const ItemCount = Max(Length(Args) - 2, 0);

  TJSArrayLike.RequireArrayLength(DeleteCount);
  Context.Limits.EnsureArrayLength(Count - Start);

  const Removed = CopyRange(Target, Start, DeleteCount, Context);

  const ShrinksTail = (ItemCount < DeleteCount);
  const GrowsTail = (ItemCount > DeleteCount);
  if ShrinksTail then
    ShiftTailDown(Target, Count, Start, DeleteCount, ItemCount)
  else if GrowsTail then
    ShiftTailUp(Target, Count, Start, DeleteCount, ItemCount);

  for var Position := 0 to ItemCount - 1 do
  begin
    TJSArrayLike.SetElement(Target, Start + Position, Args[Position + 2]);
  end;

  TJSArrayLike.WriteLength(Target, Count - DeleteCount + ItemCount);
  Result := TJSValue.CreateObject(Removed);
end;

class function TJSArrayGeneric.SpliceDeleteCount(const Args: TArray<TJSValue>; const Count, Start: Int64): Int64;
begin
  const HasNoArguments = (Length(Args) = 0);
  if HasNoArguments then
    Exit(0);

  const HasOnlyStart = (Length(Args) = 1);
  if HasOnlyStart then
    Exit(Count - Start);

  const Requested = TJSArrayLike.ToInteger(Args[1]);
  Result := Trunc(Min(Max(Requested, 0), Count - Start));
end;

class procedure TJSArrayGeneric.ShiftTailDown(const Target: IJSObject;
                                              const Count, Start, DeleteCount, ItemCount: Int64);
begin
  for var Index: Int64 := Start to Count - DeleteCount - 1 do
  begin
    TJSArrayLike.MoveElement(Target, Index + DeleteCount, Index + ItemCount);
  end;

  for var Index: Int64 := Count downto Count - DeleteCount + ItemCount + 1 do
  begin
    TJSArrayLike.DeleteElement(Target, Index - 1);
  end;
end;

class procedure TJSArrayGeneric.ShiftTailUp(const Target: IJSObject;
                                            const Count, Start, DeleteCount, ItemCount: Int64);
begin
  for var Index: Int64 := Count - DeleteCount downto Start + 1 do
  begin
    TJSArrayLike.MoveElement(Target, Index + DeleteCount - 1, Index + ItemCount - 1);
  end;
end;

class function TJSArrayGeneric.CopyRange(const Source: IJSObject; const FirstIndex, Count: Int64;
                                         const Context: TJSArrayGenericContext): IJSArray;
begin
  TJSArrayLike.RequireArrayLength(Count);
  Context.Limits.EnsureArrayLength(Count);

  Result := TJSArray.Create;
  Result.Prototype := Context.ArrayPrototype;

  for var Offset: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Source, FirstIndex + Offset, Element) then
      Result[Integer(Offset)] := Element;
  end;

  TJSArrayLike.WriteLength(Result, Count);
end;

class function TJSArrayGeneric.Slice(const Target: IJSObject; const Args: TArray<TJSValue>;
                                     const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Start = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 0), Count, 0);
  const Finish = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 1), Count, Count);
  const SliceCount = Max(Finish - Start, 0);

  const Copied = CopyRange(Target, Start, SliceCount, Context);
  Result := TJSValue.CreateObject(Copied);
end;

class function TJSArrayGeneric.Reverse(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  Context.Limits.EnsureArrayLength(Count);

  for var LowerIndex: Int64 := 0 to (Count div 2) - 1 do
  begin
    SwapMirroredElements(Target, LowerIndex, Count - LowerIndex - 1);
  end;

  Result := TJSValue.CreateObject(Target);
end;

class function TJSArrayGeneric.Fill(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const StartIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 1), Count, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 2), Count, Count);
  const FillValue = TJSArrayLike.Argument(Args, 0);

  Context.Limits.EnsureArrayLength(Max(EndIndex - StartIndex, 0));

  for var Index: Int64 := StartIndex to EndIndex - 1 do
  begin
    TJSArrayLike.SetElement(Target, Index, FillValue);
  end;

  Result := TJSValue.CreateObject(Target);
end;

class function TJSArrayGeneric.CopyWithin(const Target: IJSObject; const Args: TArray<TJSValue>;
                                          const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const ToIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 0), Count, 0);
  const FromIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 1), Count, 0);
  const FinalIndex = TJSArrayLike.RelativeIndex(TJSArrayLike.Argument(Args, 2), Count, Count);
  const MoveCount = Min(FinalIndex - FromIndex, Count - ToIndex);

  const HasElementsToMove = (MoveCount > 0);
  if HasElementsToMove then
  begin
    Context.Limits.EnsureArrayLength(MoveCount);
    MoveRange(Target, FromIndex, ToIndex, MoveCount);
  end;

  Result := TJSValue.CreateObject(Target);
end;

class procedure TJSArrayGeneric.MoveRange(const Target: IJSObject; const FromIndex, ToIndex, Count: Int64);
begin
  const OverlapsForward = (FromIndex < ToIndex) and (ToIndex < FromIndex + Count);
  if OverlapsForward then
  begin
    for var Offset: Int64 := Count - 1 downto 0 do
    begin
      TJSArrayLike.MoveElement(Target, FromIndex + Offset, ToIndex + Offset);
    end;
    Exit;
  end;

  for var Offset: Int64 := 0 to Count - 1 do
  begin
    TJSArrayLike.MoveElement(Target, FromIndex + Offset, ToIndex + Offset);
  end;
end;

class procedure TJSArrayGeneric.SwapMirroredElements(const Target: IJSObject; const LowerIndex, UpperIndex: Int64);
begin
  var LowerValue: TJSValue;
  var UpperValue: TJSValue;
  const HasLower = TJSArrayLike.TryGetElement(Target, LowerIndex, LowerValue);
  const HasUpper = TJSArrayLike.TryGetElement(Target, UpperIndex, UpperValue);

  if HasUpper then
    TJSArrayLike.SetElement(Target, LowerIndex, UpperValue)
  else
    TJSArrayLike.DeleteElement(Target, LowerIndex);

  if HasLower then
    TJSArrayLike.SetElement(Target, UpperIndex, LowerValue)
  else
    TJSArrayLike.DeleteElement(Target, UpperIndex);
end;

class function TJSArrayGeneric.Join(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  var Separator: string := DEFAULT_SEPARATOR;
  const SeparatorArgument = TJSArrayLike.Argument(Args, 0);
  if not SeparatorArgument.IsUndefined then
    Separator := SeparatorArgument.ToLimitedString(Context.Limits);

  const Count = TJSArrayLike.ToLength(Target);
  Context.Limits.EnsureArrayLength(Count);

  const Builder = TStringBuilder.Create;
  try
    for var Index: Int64 := 0 to Count - 1 do
    begin
      const NeedsSeparator = (Index > 0);
      if NeedsSeparator then
        Builder.Append(Separator);

      const Element = Target.GetProperty(TJSArrayLike.IndexName(Index));
      if not Element.IsNullOrUndefined then
        Builder.Append(Element.ToLimitedString(Context.Limits));

      Context.Limits.EnsureStringLength(Builder.Length);
    end;

    Result := TJSValue.CreateString(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

class function TJSArrayGeneric.Concat(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Context: TJSArrayGenericContext): TJSValue;
begin
  const Combined: IJSArray = TJSArray.Create;
  Combined.Prototype := Context.ArrayPrototype;

  var NextIndex: Int64 := 0;
  AppendConcatItem(TJSValue.CreateObject(Target), Combined, NextIndex, Context);
  for var Item in Args do
  begin
    AppendConcatItem(Item, Combined, NextIndex, Context);
  end;

  TJSArrayLike.WriteLength(Combined, NextIndex);
  Result := TJSValue.CreateObject(Combined);
end;

class procedure TJSArrayGeneric.AppendConcatItem(const Item: TJSValue; const Combined: IJSArray;
                                                 var NextIndex: Int64; const Context: TJSArrayGenericContext);
begin
  var Source: IJSArray;
  const IsSpreadable = Item.IsArray and Supports(Item.ToObject, IJSArray, Source);
  if not IsSpreadable then
  begin
    Context.Limits.EnsureArrayLength(NextIndex + 1);
    Combined[Integer(NextIndex)] := Item;
    Inc(NextIndex);
    Exit;
  end;

  Context.Limits.EnsureArrayLength(NextIndex + Source.Length);
  for var Index: Int64 := 0 to Source.Length - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Source, Index, Element) then
      Combined[Integer(NextIndex)] := Element;

    Inc(NextIndex);
  end;
end;

class function TJSArrayGeneric.Sort(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  Context.Limits.EnsureArrayLength(Count);

  const Defined: IJSArray = TJSArray.Create;
  var UndefinedCount: Int64 := 0;

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    if Element.IsUndefined then
      Inc(UndefinedCount)
    else
      Defined.Push(Element);
  end;

  TJSBuiltins.CallArrayMethodWithCallback(Defined, METHOD_SORT, Args, Context.Executor, Context.Limits);

  WriteSortedElements(Target, Defined, UndefinedCount, Count);
  Result := TJSValue.CreateObject(Target);
end;

class procedure TJSArrayGeneric.WriteSortedElements(const Target: IJSObject; const Sorted: IJSArray;
                                                    const UndefinedCount, Count: Int64);
begin
  var NextIndex: Int64 := 0;

  for var Index := 0 to Sorted.Length - 1 do
  begin
    TJSArrayLike.SetElement(Target, NextIndex, Sorted[Index]);
    Inc(NextIndex);
  end;

  const UndefinedEnd = NextIndex + UndefinedCount;
  while NextIndex < UndefinedEnd do
  begin
    TJSArrayLike.SetElement(Target, NextIndex, TJSValue.CreateUndefined);
    Inc(NextIndex);
  end;

  while NextIndex < Count do
  begin
    TJSArrayLike.DeleteElement(Target, NextIndex);
    Inc(NextIndex);
  end;
end;

class function TJSArrayGeneric.ToText(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue;
begin
  var Converter: IJSFunction;
  const JoinMethod = Target.GetProperty(METHOD_JOIN);
  const HasJoin = JoinMethod.IsFunction and Supports(JoinMethod.ToObject, IJSFunction, Converter);
  if HasJoin then
    Exit(Converter.Call(Target, nil));

  const ObjectToString = Context.ObjectPrototype.GetProperty(METHOD_TO_STRING);
  if ObjectToString.IsFunction and Supports(ObjectToString.ToObject, IJSFunction, Converter) then
    Exit(Converter.Call(Target, nil));

  raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_OBJECT, [METHOD_TO_STRING]));
end;

end.
