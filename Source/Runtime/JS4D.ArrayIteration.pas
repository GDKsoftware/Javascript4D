unit JS4D.ArrayIteration;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.Errors,
  JS4D.Builtins,
  JS4D.ArrayLike,
  JS4D.ObjectOperations,
  JS4D.Conversions;

type
  TJSArrayIteration = class
  private
    const
      METHOD_FOR_EACH = 'forEach';
      METHOD_MAP = 'map';
      METHOD_FILTER = 'filter';
      METHOD_SOME = 'some';
      METHOD_EVERY = 'every';
      METHOD_REDUCE = 'reduce';
      METHOD_REDUCE_RIGHT = 'reduceRight';
      METHOD_INDEX_OF = 'indexOf';
      METHOD_LAST_INDEX_OF = 'lastIndexOf';
      METHOD_FIND = 'find';
      METHOD_FIND_INDEX = 'findIndex';
      METHOD_INCLUDES = 'includes';
      METHOD_AT = 'at';
      METHOD_FLAT = 'flat';
      METHOD_FLAT_MAP = 'flatMap';
      MAX_INTEGER_MAGNITUDE = 9007199254740992.0;
      NOT_CALLED_ON_OBJECT = 'Array.prototype.%s called on null or undefined';
      CALLBACK_NOT_A_FUNCTION = 'Array.prototype.%s: callback is not a function';
      REDUCE_OF_EMPTY_ARRAY = 'Reduce of empty array with no initial value';

    class function ToIntegerClamped(const Value: TJSValue): Int64; static;
    class function RequireCallback(const MethodName: string; const Args: TArray<TJSValue>): IJSFunction; static;
    class function CallbackArguments(const Element: TJSValue; const Index: Int64;
                                     const Target: IJSObject): TArray<TJSValue>; static;

    class function ForEach(const Target: IJSObject; const Args: TArray<TJSValue>;
                           const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Map(const Target: IJSObject; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                       const ArrayPrototype: IJSObject): TJSValue; static;
    class function Filter(const Target: IJSObject; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                          const ArrayPrototype: IJSObject): TJSValue; static;
    class function Some(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Every(const Target: IJSObject; const Args: TArray<TJSValue>;
                         const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Reduce(const Target: IJSObject; const Args: TArray<TJSValue>;
                          const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ReduceRight(const Target: IJSObject; const Args: TArray<TJSValue>;
                               const Executor: TJSCallbackExecutor): TJSValue; static;
    class function TryFindMatch(const MethodName: string; const Target: IJSObject; const Args: TArray<TJSValue>;
                                const Executor: TJSCallbackExecutor; out Index: Int64;
                                out Element: TJSValue): Boolean; static;
    class function Find(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor): TJSValue; static;
    class function FindIndex(const Target: IJSObject; const Args: TArray<TJSValue>;
                             const Executor: TJSCallbackExecutor): TJSValue; static;
    class function IndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;
    class function ReadElement(const Target: IJSObject; const Index: Int64): TJSValue; static;
    class function At(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;
    class function Includes(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;
    class function FlatDepth(const Args: TArray<TJSValue>): Double; static;
    class procedure FlattenInto(const Flattened: IJSArray; const Source: IJSObject; const SourceLength: Int64;
                                const Depth: Double; const Level: Integer; const Mapper: IJSFunction;
                                const Executor: TJSCallbackExecutor; const Limits: TJSLimits); static;
    class function Flat(const Target: IJSObject; const Args: TArray<TJSValue>; const ArrayPrototype: IJSObject;
                        const Limits: TJSLimits): TJSValue; static;
    class function FlatMap(const Target: IJSObject; const Args: TArray<TJSValue>;
                           const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                           const Limits: TJSLimits): TJSValue; static;
    class function LastIndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;

  public
    class function Handles(const MethodName: string): Boolean; static;
    class function CreatesResultArray(const MethodName: string): Boolean; static;
    class function Call(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                        const Limits: TJSLimits): TJSValue; static;
  end;

implementation

class function TJSArrayIteration.Handles(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_FOR_EACH) or
            (MethodName = METHOD_MAP) or
            (MethodName = METHOD_FILTER) or
            (MethodName = METHOD_SOME) or
            (MethodName = METHOD_EVERY) or
            (MethodName = METHOD_REDUCE) or
            (MethodName = METHOD_REDUCE_RIGHT) or
            (MethodName = METHOD_INDEX_OF) or
            (MethodName = METHOD_LAST_INDEX_OF) or
            (MethodName = METHOD_FIND) or
            (MethodName = METHOD_FIND_INDEX) or
            (MethodName = METHOD_INCLUDES) or
            (MethodName = METHOD_AT) or
            (MethodName = METHOD_FLAT) or
            (MethodName = METHOD_FLAT_MAP);
end;

class function TJSArrayIteration.CreatesResultArray(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_MAP) or
            (MethodName = METHOD_FILTER) or
            (MethodName = METHOD_FLAT) or
            (MethodName = METHOD_FLAT_MAP);
end;

class function TJSArrayIteration.Call(const Target: IJSObject; const MethodName: string;
                                      const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                      const ArrayPrototype: IJSObject; const Limits: TJSLimits): TJSValue;
begin
  if not Assigned(Target) then
    raise TJSErrorFactory.TypeError(Format(NOT_CALLED_ON_OBJECT, [MethodName]));

  if MethodName = METHOD_FOR_EACH then
    Exit(ForEach(Target, Args, Executor));

  if MethodName = METHOD_MAP then
    Exit(Map(Target, Args, Executor, ArrayPrototype));

  if MethodName = METHOD_FILTER then
    Exit(Filter(Target, Args, Executor, ArrayPrototype));

  if MethodName = METHOD_SOME then
    Exit(Some(Target, Args, Executor));

  if MethodName = METHOD_EVERY then
    Exit(Every(Target, Args, Executor));

  if MethodName = METHOD_REDUCE then
    Exit(Reduce(Target, Args, Executor));

  if MethodName = METHOD_REDUCE_RIGHT then
    Exit(ReduceRight(Target, Args, Executor));

  if MethodName = METHOD_FIND then
    Exit(Find(Target, Args, Executor));

  if MethodName = METHOD_FIND_INDEX then
    Exit(FindIndex(Target, Args, Executor));

  if MethodName = METHOD_INDEX_OF then
    Exit(IndexOf(Target, Args));

  if MethodName = METHOD_INCLUDES then
    Exit(Includes(Target, Args));

  if MethodName = METHOD_AT then
    Exit(At(Target, Args));

  if MethodName = METHOD_FLAT then
    Exit(Flat(Target, Args, ArrayPrototype, Limits));

  if MethodName = METHOD_FLAT_MAP then
    Exit(FlatMap(Target, Args, Executor, ArrayPrototype, Limits));

  if MethodName = METHOD_LAST_INDEX_OF then
    Exit(LastIndexOf(Target, Args));

  raise ENotSupportedException.CreateFmt('Unsupported array iteration method: %s', [MethodName]);
end;

class function TJSArrayIteration.ReadElement(const Target: IJSObject; const Index: Int64): TJSValue;
begin
  if not TJSArrayLike.TryGetElement(Target, Index, Result) then
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.At(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Relative = TJSConversions.ToIntegerOrInfinity(TJSArrayLike.Argument(Args, 0));

  var Position := Relative;
  if Relative < 0 then
    Position := Count + Relative;

  const IsInRange = (Position >= 0) and (Position < Count);
  if IsInRange then
    Result := ReadElement(Target, Trunc(Position))
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.Includes(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  if Count = 0 then
    Exit(TJSValue.CreateBoolean(False));

  const FromIndex = TJSConversions.ToIntegerOrInfinity(TJSArrayLike.Argument(Args, 1));
  if FromIndex >= Count then
    Exit(TJSValue.CreateBoolean(False));

  var Start := FromIndex;
  if FromIndex < 0 then
    Start := Max(Count + FromIndex, 0);

  const SearchElement = TJSArrayLike.Argument(Args, 0);
  for var Index: Int64 := Trunc(Start) to Count - 1 do
  begin
    const Element = ReadElement(Target, Index);
    const IsSame = Element.StrictEquals(SearchElement) or (Element.IsNaN and SearchElement.IsNaN);
    if IsSame then
      Exit(TJSValue.CreateBoolean(True));
  end;

  Result := TJSValue.CreateBoolean(False);
end;

class function TJSArrayIteration.FlatDepth(const Args: TArray<TJSValue>): Double;
begin
  const DepthArg = TJSArrayLike.Argument(Args, 0);
  if DepthArg.IsUndefined then
    Exit(1);

  Result := Max(TJSConversions.ToIntegerOrInfinity(DepthArg), 0);
end;

class procedure TJSArrayIteration.FlattenInto(const Flattened: IJSArray; const Source: IJSObject;
                                              const SourceLength: Int64; const Depth: Double; const Level: Integer;
                                              const Mapper: IJSFunction; const Executor: TJSCallbackExecutor;
                                              const Limits: TJSLimits);
begin
  for var Index: Int64 := 0 to SourceLength - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Source, Index, Element) then
      Continue;

    if Assigned(Mapper) then
      Element := Executor(Mapper, CallbackArguments(Element, Index, Source));

    const ShouldFlatten = (Depth > 0) and TJSObjectOperations.IsArray(Element);
    if ShouldFlatten then
    begin
      Limits.EnsureNestingDepth(Level + 1);

      const Nested = Element.ToObject;
      FlattenInto(Flattened, Nested, TJSArrayLike.ToLength(Nested), Depth - 1, Level + 1, nil, Executor, Limits);
      Continue;
    end;

    Limits.EnsureArrayLength(Int64(Flattened.Length) + 1);
    Flattened.Push(Element);
  end;
end;

class function TJSArrayIteration.Flat(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const ArrayPrototype: IJSObject; const Limits: TJSLimits): TJSValue;
begin
  const SourceLength = TJSArrayLike.ToLength(Target);
  const Depth = FlatDepth(Args);

  const Flattened: IJSArray = TJSArray.Create;
  Flattened.Prototype := ArrayPrototype;
  FlattenInto(Flattened, Target, SourceLength, Depth, 0, nil, nil, Limits);

  Result := TJSValue.CreateObject(Flattened);
end;

class function TJSArrayIteration.FlatMap(const Target: IJSObject; const Args: TArray<TJSValue>;
                                         const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                                         const Limits: TJSLimits): TJSValue;
begin
  const SourceLength = TJSArrayLike.ToLength(Target);
  const Mapper = RequireCallback(METHOD_FLAT_MAP, Args);

  const Flattened: IJSArray = TJSArray.Create;
  Flattened.Prototype := ArrayPrototype;
  FlattenInto(Flattened, Target, SourceLength, 1, 0, Mapper, Executor, Limits);

  Result := TJSValue.CreateObject(Flattened);
end;

class function TJSArrayIteration.ToIntegerClamped(const Value: TJSValue): Int64;
begin
  const Number = TJSArrayLike.ToNumber(Value);
  if System.Math.IsNaN(Number) then
    Exit(0);

  Result := Trunc(EnsureRange(Number, -MAX_INTEGER_MAGNITUDE, MAX_INTEGER_MAGNITUDE));
end;

class function TJSArrayIteration.RequireCallback(const MethodName: string;
                                                 const Args: TArray<TJSValue>): IJSFunction;
begin
  const HasCallback = (Length(Args) > 0) and Args[0].IsFunction;
  if (not HasCallback) or (not Supports(Args[0].ToObject, IJSFunction, Result)) then
    raise TJSErrorFactory.TypeError(Format(CALLBACK_NOT_A_FUNCTION, [MethodName]));
end;

class function TJSArrayIteration.CallbackArguments(const Element: TJSValue; const Index: Int64;
                                                   const Target: IJSObject): TArray<TJSValue>;
begin
  Result := [Element, TJSValue.CreateNumber(Index), TJSValue.CreateObject(Target)];
end;

class function TJSArrayIteration.ForEach(const Target: IJSObject; const Args: TArray<TJSValue>;
                                         const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_FOR_EACH, Args);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const CallbackArgs = CallbackArguments(Element, Index, Target);
      Executor(Callback, CallbackArgs);
    end;
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.Map(const Target: IJSObject; const Args: TArray<TJSValue>;
                                     const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_MAP, Args);
  if Count > MaxInt then
    raise TJSErrorFactory.InvalidArrayLength;

  const Mapped: IJSArray = TJSArray.Create;
  Mapped.Prototype := ArrayPrototype;
  if Count > 0 then
    Mapped[Integer(Count - 1)] := TJSValue.CreateUndefined;

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const CallbackArgs = CallbackArguments(Element, Index, Target);
      Mapped[Integer(Index)] := Executor(Callback, CallbackArgs);
    end;
  end;

  Result := TJSValue.CreateObject(Mapped);
end;

class function TJSArrayIteration.Filter(const Target: IJSObject; const Args: TArray<TJSValue>;
                                        const Executor: TJSCallbackExecutor;
                                        const ArrayPrototype: IJSObject): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_FILTER, Args);
  const Kept: IJSArray = TJSArray.Create;
  Kept.Prototype := ArrayPrototype;

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    const CallbackArgs = CallbackArguments(Element, Index, Target);
    const IsKept = Executor(Callback, CallbackArgs).ToBoolean;
    if IsKept then
      Kept.Push(Element);
  end;

  Result := TJSValue.CreateObject(Kept);
end;

class function TJSArrayIteration.Some(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_SOME, Args);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    const CallbackArgs = CallbackArguments(Element, Index, Target);
    const IsMatch = Executor(Callback, CallbackArgs).ToBoolean;
    if IsMatch then
    begin
      Result := TJSValue.CreateBoolean(True);
      Exit;
    end;
  end;

  Result := TJSValue.CreateBoolean(False);
end;

class function TJSArrayIteration.Every(const Target: IJSObject; const Args: TArray<TJSValue>;
                                       const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_EVERY, Args);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    const CallbackArgs = CallbackArguments(Element, Index, Target);
    const IsMatch = Executor(Callback, CallbackArgs).ToBoolean;
    if not IsMatch then
    begin
      Result := TJSValue.CreateBoolean(False);
      Exit;
    end;
  end;

  Result := TJSValue.CreateBoolean(True);
end;

class function TJSArrayIteration.TryFindMatch(const MethodName: string; const Target: IJSObject;
                                              const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                              out Index: Int64; out Element: TJSValue): Boolean;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(MethodName, Args);

  for var Position: Int64 := 0 to Count - 1 do
  begin
    Index := Position;
    if not TJSArrayLike.TryGetElement(Target, Position, Element) then
      Element := TJSValue.CreateUndefined;

    const CallbackArgs = CallbackArguments(Element, Position, Target);
    const IsMatch = Executor(Callback, CallbackArgs).ToBoolean;
    if IsMatch then
      Exit(True);
  end;

  Result := False;
end;

class function TJSArrayIteration.Find(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Executor: TJSCallbackExecutor): TJSValue;
begin
  var Index: Int64;
  var Element: TJSValue;
  if TryFindMatch(METHOD_FIND, Target, Args, Executor, Index, Element) then
    Result := Element
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.FindIndex(const Target: IJSObject; const Args: TArray<TJSValue>;
                                           const Executor: TJSCallbackExecutor): TJSValue;
begin
  var Index: Int64;
  var Element: TJSValue;
  if TryFindMatch(METHOD_FIND_INDEX, Target, Args, Executor, Index, Element) then
    Result := TJSValue.CreateNumber(Index)
  else
    Result := TJSValue.CreateNumber(-1);
end;

class function TJSArrayIteration.Reduce(const Target: IJSObject; const Args: TArray<TJSValue>;
                                        const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_REDUCE, Args);
  const HasInitialValue = (Length(Args) > 1);

  var Accumulator := TJSValue.CreateUndefined;
  var Index: Int64 := 0;

  if HasInitialValue then
  begin
    Accumulator := Args[1];
  end
  else
  begin
    var FoundFirst := False;
    while (not FoundFirst) and (Index < Count) do
    begin
      FoundFirst := TJSArrayLike.TryGetElement(Target, Index, Accumulator);
      Inc(Index);
    end;

    if not FoundFirst then
      raise TJSErrorFactory.TypeError(REDUCE_OF_EMPTY_ARRAY);
  end;

  while Index < Count do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const CallbackArgs: TArray<TJSValue> = [Accumulator, Element, TJSValue.CreateNumber(Index),
                                              TJSValue.CreateObject(Target)];
      Accumulator := Executor(Callback, CallbackArgs);
    end;

    Inc(Index);
  end;

  Result := Accumulator;
end;

class function TJSArrayIteration.ReduceRight(const Target: IJSObject; const Args: TArray<TJSValue>;
                                             const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_REDUCE_RIGHT, Args);
  const HasInitialValue = (Length(Args) > 1);

  var Accumulator := TJSValue.CreateUndefined;
  var Index := Count - 1;

  if HasInitialValue then
  begin
    Accumulator := Args[1];
  end
  else
  begin
    var FoundLast := False;
    while (not FoundLast) and (Index >= 0) do
    begin
      FoundLast := TJSArrayLike.TryGetElement(Target, Index, Accumulator);
      Dec(Index);
    end;

    if not FoundLast then
      raise TJSErrorFactory.TypeError(REDUCE_OF_EMPTY_ARRAY);
  end;

  while Index >= 0 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const CallbackArgs: TArray<TJSValue> = [Accumulator, Element, TJSValue.CreateNumber(Index),
                                              TJSValue.CreateObject(Target)];
      Accumulator := Executor(Callback, CallbackArgs);
    end;

    Dec(Index);
  end;

  Result := Accumulator;
end;

class function TJSArrayIteration.IndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const NotFound = TJSValue.CreateNumber(-1);
  const Count = TJSArrayLike.ToLength(Target);
  if Count = 0 then
    Exit(NotFound);

  const SearchElement = TJSArrayLike.Argument(Args, 0);
  const RequestedStart = ToIntegerClamped(TJSArrayLike.Argument(Args, 1));
  if RequestedStart >= Count then
    Exit(NotFound);

  var StartIndex := RequestedStart;
  if RequestedStart < 0 then
    StartIndex := Max(Count + RequestedStart, 0);

  for var Index: Int64 := StartIndex to Count - 1 do
  begin
    var Element: TJSValue;
    const IsMatch = TJSArrayLike.TryGetElement(Target, Index, Element) and Element.StrictEquals(SearchElement);
    if IsMatch then
    begin
      Result := TJSValue.CreateNumber(Index);
      Exit;
    end;
  end;

  Result := NotFound;
end;

class function TJSArrayIteration.LastIndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const NotFound = TJSValue.CreateNumber(-1);
  const Count = TJSArrayLike.ToLength(Target);
  if Count = 0 then
    Exit(NotFound);

  const SearchElement = TJSArrayLike.Argument(Args, 0);

  var StartIndex := Count - 1;
  if Length(Args) > 1 then
  begin
    const RequestedStart = ToIntegerClamped(Args[1]);
    if RequestedStart >= 0 then
      StartIndex := Min(RequestedStart, Count - 1)
    else
      StartIndex := Count + RequestedStart;
  end;

  for var Index := StartIndex downto 0 do
  begin
    var Element: TJSValue;
    const IsMatch = TJSArrayLike.TryGetElement(Target, Index, Element) and Element.StrictEquals(SearchElement);
    if IsMatch then
    begin
      Result := TJSValue.CreateNumber(Index);
      Exit;
    end;
  end;

  Result := NotFound;
end;

end.
