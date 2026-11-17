unit JS4D.ArrayGeneric;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.PropertyNames,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.Errors,
  JS4D.SymbolRegistry,
  JS4D.Builtins,
  JS4D.ArrayLike,
  JS4D.ObjectOperations;

type
  TJSMethodInvoker = reference to function(const Target: TJSValue; const MethodName: string): TJSValue;

  TJSArrayGenericContext = record
    ArrayPrototype: IJSObject;
    ObjectPrototype: IJSObject;
    Limits: TJSLimits;
    Executor: TJSCallbackExecutor;
    InvokeMethod: TJSMethodInvoker;
  end;

  TJSArrayGeneric = class
  private
    type
      TGenericMethod = (Push, Pop, Shift, Unshift, Splice, Slice, Reverse, Join, Concat, Sort, ToText,
                        ToLocaleText, Fill, CopyWithin);

      TGenericMethodInfo = record
        Name: string;
        CreatesResultArray: Boolean;
        StoresNewElements: Boolean;
        AlwaysUsesPropertySemantics: Boolean;
      end;

      TElementFormatter = reference to function(const Element: TJSValue): string;

    const
      NOT_CALLED_ON_OBJECT = 'Array.prototype.%s called on null or undefined';
      UNSUPPORTED_METHOD = 'Unsupported generic array method: %s';
      METHODS: array[TGenericMethod] of TGenericMethodInfo = (
        (Name: METHOD_PUSH; CreatesResultArray: False; StoresNewElements: True; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_POP; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_SHIFT; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_UNSHIFT; CreatesResultArray: False; StoresNewElements: True; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_SPLICE; CreatesResultArray: True; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_SLICE; CreatesResultArray: True; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_REVERSE; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: JOIN_METHOD; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_CONCAT; CreatesResultArray: True; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_SORT; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: TO_STRING_METHOD; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_TO_LOCALE_STRING; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: False),
        (Name: METHOD_FILL; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: True),
        (Name: METHOD_COPY_WITHIN; CreatesResultArray: False; StoresNewElements: False; AlwaysUsesPropertySemantics: True));

    class function TryFindMethod(const MethodName: string; out Method: TGenericMethod): Boolean; static;
    class function TryResetEmpty(const Target: IJSObject; const Count: Int64): Boolean; static;
    class function JoinElements(const Target: IJSObject; const Separator: string;
                                const Context: TJSArrayGenericContext;
                                const FormatElement: TElementFormatter): string; static;
    class function ReadSpreadableFlag(const Item: TJSValue): TJSValue; static;
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
    class function ToLocaleText(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue; static;
    class function Fill(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
    class function CopyWithin(const Target: IJSObject; const Args: TArray<TJSValue>;
                              const Context: TJSArrayGenericContext): TJSValue; static;
    class procedure MoveRange(const Target: IJSObject; const FromIndex, ToIndex, Count: Int64); static;

    class function CopyRange(const Source: IJSObject; const FirstIndex, Count: Int64;
                             const Context: TJSArrayGenericContext): IJSArray; static;
    class procedure ShiftTailDown(const Target: IJSObject; const Count, Start, DeleteCount, ItemCount: Int64;
                                  const Context: TJSArrayGenericContext); static;
    class procedure ShiftTailUp(const Target: IJSObject; const Count, Start, DeleteCount, ItemCount: Int64;
                                const Context: TJSArrayGenericContext); static;
    class procedure SwapMirroredElements(const Target: IJSObject; const LowerIndex, UpperIndex: Int64); static;
    class function HasSpreadabilityFlag(const Item: TJSValue): Boolean; static;
    class function IsConcatSpreadable(const Item: TJSValue): Boolean; static;
    class function AppendConcatItem(const Item: TJSValue; const Combined: IJSArray; const NextIndex: Int64;
                                    const Context: TJSArrayGenericContext): Int64; static;
    class procedure StoreConcatElement(const Combined: IJSArray; const Index: Int64; const Element: TJSValue;
                                       const Context: TJSArrayGenericContext); static;
    class procedure WriteSortedElements(const Target: IJSObject; const Sorted: IJSArray;
                                        const UndefinedCount, Count: Int64); static;

  public
    class function Handles(const MethodName: string): Boolean; static;
    class function AlwaysUsesPropertySemantics(const MethodName: string): Boolean; static;
    class function CreatesResultArray(const MethodName: string): Boolean; static;
    class function StoresNewElements(const MethodName: string): Boolean; static;
    class function ConcatsCustomItems(const MethodName: string; const Target: IJSObject;
                                      const Args: TArray<TJSValue>): Boolean; static;
    class function Call(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                        const Context: TJSArrayGenericContext): TJSValue; static;
  end;

implementation

uses
  JS4D.Conversions;

class function TJSArrayGeneric.TryFindMethod(const MethodName: string; out Method: TGenericMethod): Boolean;
begin
  for var Candidate := Low(TGenericMethod) to High(TGenericMethod) do
  begin
    const IsMatch = (METHODS[Candidate].Name = MethodName);
    if IsMatch then
    begin
      Method := Candidate;
      Exit(True);
    end;
  end;

  Method := Low(TGenericMethod);
  Result := False;
end;

class function TJSArrayGeneric.Handles(const MethodName: string): Boolean;
begin
  var Method: TGenericMethod;
  Result := TryFindMethod(MethodName, Method);
end;

class function TJSArrayGeneric.AlwaysUsesPropertySemantics(const MethodName: string): Boolean;
begin
  var Method: TGenericMethod;
  Result := (TryFindMethod(MethodName, Method) and METHODS[Method].AlwaysUsesPropertySemantics);
end;

class function TJSArrayGeneric.CreatesResultArray(const MethodName: string): Boolean;
begin
  var Method: TGenericMethod;
  Result := (TryFindMethod(MethodName, Method) and METHODS[Method].CreatesResultArray);
end;

class function TJSArrayGeneric.StoresNewElements(const MethodName: string): Boolean;
begin
  var Method: TGenericMethod;
  Result := (TryFindMethod(MethodName, Method) and METHODS[Method].StoresNewElements);
end;

class function TJSArrayGeneric.ConcatsCustomItems(const MethodName: string; const Target: IJSObject;
                                                  const Args: TArray<TJSValue>): Boolean;
begin
  Result := False;

  const IsConcat = (MethodName = METHOD_CONCAT);
  if not IsConcat then
    Exit;

  const TargetValue = TJSValue.CreateObject(Target);
  if HasSpreadabilityFlag(TargetValue) then
    Exit(True);

  for var Item in Args do
  begin
    if HasSpreadabilityFlag(Item) then
      Exit(True);
  end;
end;

class function TJSArrayGeneric.ReadSpreadableFlag(const Item: TJSValue): TJSValue;
begin
  const FlagKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.IsConcatSpreadable);

  Result := Item.ToObject.GetProperty(FlagKey);
end;

class function TJSArrayGeneric.HasSpreadabilityFlag(const Item: TJSValue): Boolean;
begin
  if not Item.IsObject then
    Exit(False);

  var Proxy: IJSProxy;
  if TJSObjectOperations.AsProxy(Item.ToObject, Proxy) then
    Exit(True);

  const Flag = ReadSpreadableFlag(Item);
  Result := not Flag.IsUndefined;
end;

class function TJSArrayGeneric.IsConcatSpreadable(const Item: TJSValue): Boolean;
begin
  if not Item.IsObject then
    Exit(False);

  const Flag = ReadSpreadableFlag(Item);
  if not Flag.IsUndefined then
  begin
    Result := Flag.ToBoolean;
    Exit;
  end;

  Result := TJSObjectOperations.IsArray(Item);
end;

class function TJSArrayGeneric.Call(const Target: IJSObject; const MethodName: string;
                                    const Args: TArray<TJSValue>; const Context: TJSArrayGenericContext): TJSValue;
begin
  if not Assigned(Target) then
  begin
    const Message = Format(NOT_CALLED_ON_OBJECT, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  var Method: TGenericMethod;
  if not TryFindMethod(MethodName, Method) then
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [MethodName]);

  case Method of
    TGenericMethod.Push         : Result := Push(Target, Args);
    TGenericMethod.Pop          : Result := Pop(Target);
    TGenericMethod.Shift        : Result := Shift(Target, Context);
    TGenericMethod.Unshift      : Result := Unshift(Target, Args, Context);
    TGenericMethod.Splice       : Result := Splice(Target, Args, Context);
    TGenericMethod.Slice        : Result := Slice(Target, Args, Context);
    TGenericMethod.Reverse      : Result := Reverse(Target, Context);
    TGenericMethod.Join         : Result := Join(Target, Args, Context);
    TGenericMethod.Concat       : Result := Concat(Target, Args, Context);
    TGenericMethod.Sort         : Result := Sort(Target, Args, Context);
    TGenericMethod.ToText       : Result := ToText(Target, Context);
    TGenericMethod.ToLocaleText : Result := ToLocaleText(Target, Context);
    TGenericMethod.Fill         : Result := Fill(Target, Args, Context);
    TGenericMethod.CopyWithin   : Result := CopyWithin(Target, Args, Context);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [MethodName]);
  end;
end;

class function TJSArrayGeneric.Push(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  var Count := TJSArrayLike.ToLength(Target);
  TJSArrayLike.RequireSafeLength(Count + Length(Args));

  for var Item in Args do
  begin
    TJSArrayLike.SetElement(Target, Count, Item);
    Inc(Count);
  end;

  TJSArrayLike.WriteLength(Target, Count);
  Result := TJSValue.CreateNumber(Count);
end;

class function TJSArrayGeneric.TryResetEmpty(const Target: IJSObject; const Count: Int64): Boolean;
begin
  Result := (Count = 0);
  if Result then
    TJSArrayLike.WriteLength(Target, 0);
end;

class function TJSArrayGeneric.Pop(const Target: IJSObject): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  if TryResetEmpty(Target, Count) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const LastIndex = Count - 1;
  Result := TJSArrayLike.GetElement(Target, LastIndex);
  TJSArrayLike.DeleteElement(Target, LastIndex);
  TJSArrayLike.WriteLength(Target, LastIndex);
end;

class function TJSArrayGeneric.Shift(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  if TryResetEmpty(Target, Count) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := TJSArrayLike.GetElement(Target, 0);
  for var Index: Int64 := 1 to Count - 1 do
  begin
    Context.Limits.EnsureArrayLength(Index);
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
    TJSArrayLike.RequireSafeLength(Count + ItemCount);

    for var Index: Int64 := Count downto 1 do
    begin
      Context.Limits.EnsureArrayLength(Count - Index + 1);
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
  const StartArgument = TJSArrayLike.Argument(Args, 0);
  const Start = TJSArrayLike.RelativeIndex(StartArgument, Count, 0);
  const DeleteCount = TJSArrayLike.SpliceDeleteCount(Args, Count, Start);
  const ItemCount = Max(Length(Args) - 2, 0);

  TJSArrayLike.RequireSafeLength(Count - DeleteCount + ItemCount);
  TJSArrayLike.RequireArrayLength(DeleteCount);

  const Removed = CopyRange(Target, Start, DeleteCount, Context);

  const ShrinksTail = (ItemCount < DeleteCount);
  const GrowsTail = (ItemCount > DeleteCount);
  if ShrinksTail then
    ShiftTailDown(Target, Count, Start, DeleteCount, ItemCount, Context)
  else if GrowsTail then
    ShiftTailUp(Target, Count, Start, DeleteCount, ItemCount, Context);

  for var Position := 0 to ItemCount - 1 do
  begin
    TJSArrayLike.SetElement(Target, Start + Position, Args[Position + 2]);
  end;

  TJSArrayLike.WriteLength(Target, Count - DeleteCount + ItemCount);
  Result := TJSValue.CreateObject(Removed);
end;

class procedure TJSArrayGeneric.ShiftTailDown(const Target: IJSObject;
                                              const Count, Start, DeleteCount, ItemCount: Int64;
                                              const Context: TJSArrayGenericContext);
begin
  for var Index: Int64 := Start to Count - DeleteCount - 1 do
  begin
    Context.Limits.EnsureArrayLength(Index - Start + 1);
    TJSArrayLike.MoveElement(Target, Index + DeleteCount, Index + ItemCount);
  end;

  for var Index: Int64 := Count downto Count - DeleteCount + ItemCount + 1 do
  begin
    Context.Limits.EnsureArrayLength(Count - Index + 1);
    TJSArrayLike.DeleteElement(Target, Index - 1);
  end;
end;

class procedure TJSArrayGeneric.ShiftTailUp(const Target: IJSObject;
                                            const Count, Start, DeleteCount, ItemCount: Int64;
                                            const Context: TJSArrayGenericContext);
begin
  for var Index: Int64 := Count - DeleteCount downto Start + 1 do
  begin
    Context.Limits.EnsureArrayLength(Count - DeleteCount - Index + 1);
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
  const StartArgument = TJSArrayLike.Argument(Args, 0);
  const EndArgument = TJSArrayLike.Argument(Args, 1);
  const Start = TJSArrayLike.RelativeIndex(StartArgument, Count, 0);
  const Finish = TJSArrayLike.RelativeIndex(EndArgument, Count, Count);
  const SliceCount = Max(Finish - Start, 0);

  const Copied = CopyRange(Target, Start, SliceCount, Context);
  Result := TJSValue.CreateObject(Copied);
end;

class function TJSArrayGeneric.Reverse(const Target: IJSObject; const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);

  for var LowerIndex: Int64 := 0 to (Count div 2) - 1 do
  begin
    Context.Limits.EnsureArrayLength(LowerIndex + 1);
    SwapMirroredElements(Target, LowerIndex, Count - LowerIndex - 1);
  end;

  Result := TJSValue.CreateObject(Target);
end;

class function TJSArrayGeneric.Fill(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const FillValue = TJSArrayLike.Argument(Args, 0);
  const StartArgument = TJSArrayLike.Argument(Args, 1);
  const EndArgument = TJSArrayLike.Argument(Args, 2);
  const StartIndex = TJSArrayLike.RelativeIndex(StartArgument, Count, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(EndArgument, Count, Count);

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
  const TargetArgument = TJSArrayLike.Argument(Args, 0);
  const StartArgument = TJSArrayLike.Argument(Args, 1);
  const EndArgument = TJSArrayLike.Argument(Args, 2);
  const ToIndex = TJSArrayLike.RelativeIndex(TargetArgument, Count, 0);
  const FromIndex = TJSArrayLike.RelativeIndex(StartArgument, Count, 0);
  const FinalIndex = TJSArrayLike.RelativeIndex(EndArgument, Count, Count);
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

class function TJSArrayGeneric.JoinElements(const Target: IJSObject; const Separator: string;
                                            const Context: TJSArrayGenericContext;
                                            const FormatElement: TElementFormatter): string;
begin
  const Count = TJSArrayLike.ToLength(Target);
  Context.Limits.EnsureArrayLength(Count);

  const Builder = TStringBuilder.Create;
  try
    for var Index: Int64 := 0 to Count - 1 do
    begin
      const NeedsSeparator = (Index > 0);
      if NeedsSeparator then
        Builder.Append(Separator);

      const Element = TJSArrayLike.GetElement(Target, Index);
      if not Element.IsNullOrUndefined then
        Builder.Append(FormatElement(Element));

      Context.Limits.EnsureStringLength(Builder.Length);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSArrayGeneric.Join(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  var Separator: string := ARRAY_SEPARATOR;
  const SeparatorArgument = TJSArrayLike.Argument(Args, 0);
  if not SeparatorArgument.IsUndefined then
    Separator := SeparatorArgument.ToLimitedString(Context.Limits);

  const Joined = JoinElements(Target, Separator, Context,
    function(const Element: TJSValue): string
    begin
      Result := Element.ToLimitedString(Context.Limits);
    end);

  Result := TJSValue.CreateString(Joined);
end;

class function TJSArrayGeneric.ToLocaleText(const Target: IJSObject;
                                            const Context: TJSArrayGenericContext): TJSValue;
begin
  const Joined = JoinElements(Target, ARRAY_SEPARATOR, Context,
    function(const Element: TJSValue): string
    begin
      const LocaleText = Context.InvokeMethod(Element, METHOD_TO_LOCALE_STRING);

      Result := LocaleText.ToLimitedString(Context.Limits);
    end);

  Result := TJSValue.CreateString(Joined);
end;

class function TJSArrayGeneric.Concat(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Context: TJSArrayGenericContext): TJSValue;
begin
  const Combined: IJSArray = TJSArray.Create;
  Combined.Prototype := Context.ArrayPrototype;

  const TargetValue = TJSValue.CreateObject(Target);
  var NextIndex := AppendConcatItem(TargetValue, Combined, 0, Context);
  for var Item in Args do
  begin
    NextIndex := AppendConcatItem(Item, Combined, NextIndex, Context);
  end;

  TJSArrayLike.WriteLength(Combined, NextIndex);
  Result := TJSValue.CreateObject(Combined);
end;

class function TJSArrayGeneric.AppendConcatItem(const Item: TJSValue; const Combined: IJSArray;
                                                const NextIndex: Int64;
                                                const Context: TJSArrayGenericContext): Int64;
begin
  Result := NextIndex;

  if not IsConcatSpreadable(Item) then
  begin
    TJSArrayLike.RequireSafeLength(Result + 1);
    StoreConcatElement(Combined, Result, Item, Context);
    Inc(Result);
    Exit;
  end;

  const Source = Item.ToObject;
  const SourceLength = TJSArrayLike.ToLength(Source);
  TJSArrayLike.RequireSafeLength(Result + SourceLength);

  for var Index: Int64 := 0 to SourceLength - 1 do
  begin
    Context.Limits.EnsureArrayLength(Index + 1);

    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Source, Index, Element) then
      StoreConcatElement(Combined, Result, Element, Context);

    Inc(Result);
  end;
end;

class procedure TJSArrayGeneric.StoreConcatElement(const Combined: IJSArray; const Index: Int64;
                                                   const Element: TJSValue; const Context: TJSArrayGenericContext);
begin
  Context.Limits.EnsureArrayLength(Index + 1);
  TJSArrayLike.RequireArrayLength(Index + 1);

  Combined[Integer(Index)] := Element;
end;

class function TJSArrayGeneric.Sort(const Target: IJSObject; const Args: TArray<TJSValue>;
                                    const Context: TJSArrayGenericContext): TJSValue;
begin
  TJSArrayLike.RequireSortComparer(Args);

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

  for var Element in Sorted do
  begin
    TJSArrayLike.SetElement(Target, NextIndex, Element);
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
  const JoinMethod = Target.GetProperty(JOIN_METHOD);
  if JoinMethod.TryGetFunction(Converter) then
  begin
    Result := Converter.Call(Target, nil);
    Exit;
  end;

  const ObjectToString = Context.ObjectPrototype.GetProperty(TO_STRING_METHOD);
  if ObjectToString.TryGetFunction(Converter) then
  begin
    Result := Converter.Call(Target, nil);
    Exit;
  end;

  const Message = Format(NOT_CALLED_ON_OBJECT, [TO_STRING_METHOD]);
  raise TJSErrorFactory.TypeError(Message);
end;

end.
