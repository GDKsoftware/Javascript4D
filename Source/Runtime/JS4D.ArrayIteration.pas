unit JS4D.ArrayIteration;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.PropertyNames,
  JS4D.ArrayObject,
  JS4D.Errors,
  JS4D.Builtins,
  JS4D.ArrayLike,
  JS4D.ObjectOperations,
  JS4D.Conversions;

type
  TJSArrayIteration = class
  private
    type
      TIterationMethod = (ForEach, Map, Filter, Some, Every, Reduce, ReduceRight, Find, FindIndex, IndexOf,
                          Includes, At, Flat, FlatMap, LastIndexOf);

      TIterationMethodInfo = record
        Name: string;
        CreatesResultArray: Boolean;
      end;

      TFindMatch = record
        IsFound: Boolean;
        Index: Int64;
        Element: TJSValue;
      end;

      TReduceStart = record
        Accumulator: TJSValue;
        NextIndex: Int64;
      end;

    const
      CALLBACK_METHODS = [TIterationMethod.ForEach, TIterationMethod.Map, TIterationMethod.Filter,
                          TIterationMethod.Some, TIterationMethod.Every, TIterationMethod.Reduce,
                          TIterationMethod.ReduceRight, TIterationMethod.Find, TIterationMethod.FindIndex,
                          TIterationMethod.FlatMap];
      METHODS: array[TIterationMethod] of TIterationMethodInfo = (
        (Name: METHOD_FOR_EACH; CreatesResultArray: False),
        (Name: METHOD_MAP; CreatesResultArray: True),
        (Name: METHOD_FILTER; CreatesResultArray: True),
        (Name: METHOD_SOME; CreatesResultArray: False),
        (Name: METHOD_EVERY; CreatesResultArray: False),
        (Name: METHOD_REDUCE; CreatesResultArray: False),
        (Name: METHOD_REDUCE_RIGHT; CreatesResultArray: False),
        (Name: METHOD_FIND; CreatesResultArray: False),
        (Name: METHOD_FIND_INDEX; CreatesResultArray: False),
        (Name: METHOD_INDEX_OF; CreatesResultArray: False),
        (Name: METHOD_INCLUDES; CreatesResultArray: False),
        (Name: METHOD_AT; CreatesResultArray: False),
        (Name: METHOD_FLAT; CreatesResultArray: True),
        (Name: METHOD_FLAT_MAP; CreatesResultArray: True),
        (Name: METHOD_LAST_INDEX_OF; CreatesResultArray: False));
      EMPTY_RESULT_METHODS = [TIterationMethod.Filter, TIterationMethod.Flat, TIterationMethod.FlatMap];
      UNSUPPORTED_METHOD = 'Unsupported array iteration method: %s';
      MAX_INTEGER_MAGNITUDE = 9007199254740992.0;
      NOT_CALLED_ON_OBJECT = 'Array.prototype.%s called on null or undefined';
      CALLBACK_NOT_A_FUNCTION = 'Array.prototype.%s: callback is not a function';
      REDUCE_OF_EMPTY_ARRAY = 'Reduce of empty array with no initial value';

    class function TryFindMethod(const MethodName: string; out Method: TIterationMethod): Boolean; static;
    class function HasElementWithOutcome(const MethodName: string; const Target: IJSObject;
                                         const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                         const Outcome: Boolean): Boolean; static;
    class function CallWithCallback(const Method: TIterationMethod; const Target: IJSObject;
                                    const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                    const ArrayPrototype: IJSObject; const Limits: TJSLimits;
                                    const BeforeElements: TProc): TJSValue; static;
    class function CallWithoutCallback(const Method: TIterationMethod; const Target: IJSObject;
                                       const Args: TArray<TJSValue>; const ArrayPrototype: IJSObject;
                                       const Limits: TJSLimits; const BeforeElements: TProc): TJSValue; static;
    class function FindReduceStart(const Target: IJSObject; const Args: TArray<TJSValue>; const Count: Int64;
                                   const Step: Integer): TReduceStart; static;
    class function IncludesStart(const Args: TArray<TJSValue>; const Count: Int64): Int64; static;
    class function LastIndexStart(const Args: TArray<TJSValue>; const Count: Int64): Int64; static;
    class procedure NotifyBeforeElements(const BeforeElements: TProc); static;
    class function ToIntegerClamped(const Value: TJSValue): Int64; static;
    class function RequireCallback(const MethodName: string; const Args: TArray<TJSValue>): IJSFunction; static;
    class function CallbackArguments(const Element: TJSValue; const Index: Int64;
                                     const Target: IJSObject): TArray<TJSValue>; static;

    class function ForEach(const Target: IJSObject; const Args: TArray<TJSValue>;
                           const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Map(const Target: IJSObject; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                       const ArrayPrototype: IJSObject; const BeforeElements: TProc): TJSValue; static;
    class function Filter(const Target: IJSObject; const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                          const ArrayPrototype: IJSObject; const BeforeElements: TProc): TJSValue; static;
    class function Some(const Target: IJSObject; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Every(const Target: IJSObject; const Args: TArray<TJSValue>;
                         const Executor: TJSCallbackExecutor): TJSValue; static;
    class function Reduce(const Target: IJSObject; const Args: TArray<TJSValue>;
                          const Executor: TJSCallbackExecutor): TJSValue; static;
    class function ReduceInDirection(const Target: IJSObject; const Args: TArray<TJSValue>;
                                     const Executor: TJSCallbackExecutor; const MethodName: string;
                                     const Step: Integer): TJSValue; static;
    class function ReduceRight(const Target: IJSObject; const Args: TArray<TJSValue>;
                               const Executor: TJSCallbackExecutor): TJSValue; static;
    class function FindMatch(const MethodName: string; const Target: IJSObject; const Args: TArray<TJSValue>;
                             const Executor: TJSCallbackExecutor): TFindMatch; static;
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
                        const Limits: TJSLimits; const BeforeElements: TProc): TJSValue; static;
    class function FlatMap(const Target: IJSObject; const Args: TArray<TJSValue>;
                           const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                           const Limits: TJSLimits; const BeforeElements: TProc): TJSValue; static;
    class function LastIndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;

  public
    class function Handles(const MethodName: string): Boolean; static;
    class function CreatesResultArray(const MethodName: string): Boolean; static;
    class function StartsEmpty(const MethodName: string): Boolean; static;
    class function Call(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                        const Limits: TJSLimits; const BeforeElements: TProc = nil): TJSValue; static;
  end;

implementation

class function TJSArrayIteration.TryFindMethod(const MethodName: string; out Method: TIterationMethod): Boolean;
begin
  for var Candidate := Low(TIterationMethod) to High(TIterationMethod) do
  begin
    const IsMatch = (METHODS[Candidate].Name = MethodName);
    if IsMatch then
    begin
      Method := Candidate;
      Exit(True);
    end;
  end;

  Method := Low(TIterationMethod);
  Result := False;
end;

class function TJSArrayIteration.Handles(const MethodName: string): Boolean;
begin
  var Method: TIterationMethod;
  Result := TryFindMethod(MethodName, Method);
end;

class function TJSArrayIteration.CreatesResultArray(const MethodName: string): Boolean;
begin
  var Method: TIterationMethod;
  Result := (TryFindMethod(MethodName, Method) and METHODS[Method].CreatesResultArray);
end;

class function TJSArrayIteration.StartsEmpty(const MethodName: string): Boolean;
begin
  var Method: TIterationMethod;
  Result := (TryFindMethod(MethodName, Method) and (Method in EMPTY_RESULT_METHODS));
end;

class function TJSArrayIteration.CallWithCallback(const Method: TIterationMethod; const Target: IJSObject;
                                                 const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                                 const ArrayPrototype: IJSObject; const Limits: TJSLimits;
                                                 const BeforeElements: TProc): TJSValue;
begin
  case Method of
    TIterationMethod.ForEach     : Result := ForEach(Target, Args, Executor);
    TIterationMethod.Map         : Result := Map(Target, Args, Executor, ArrayPrototype, BeforeElements);
    TIterationMethod.Filter      : Result := Filter(Target, Args, Executor, ArrayPrototype, BeforeElements);
    TIterationMethod.Some        : Result := Some(Target, Args, Executor);
    TIterationMethod.Every       : Result := Every(Target, Args, Executor);
    TIterationMethod.Reduce      : Result := Reduce(Target, Args, Executor);
    TIterationMethod.ReduceRight : Result := ReduceRight(Target, Args, Executor);
    TIterationMethod.Find        : Result := Find(Target, Args, Executor);
    TIterationMethod.FindIndex   : Result := FindIndex(Target, Args, Executor);
    TIterationMethod.FlatMap     : Result := FlatMap(Target, Args, Executor, ArrayPrototype, Limits, BeforeElements);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [METHODS[Method].Name]);
  end;
end;

class function TJSArrayIteration.CallWithoutCallback(const Method: TIterationMethod; const Target: IJSObject;
                                                    const Args: TArray<TJSValue>; const ArrayPrototype: IJSObject;
                                                    const Limits: TJSLimits;
                                                    const BeforeElements: TProc): TJSValue;
begin
  case Method of
    TIterationMethod.IndexOf     : Result := IndexOf(Target, Args);
    TIterationMethod.Includes    : Result := Includes(Target, Args);
    TIterationMethod.At          : Result := At(Target, Args);
    TIterationMethod.Flat        : Result := Flat(Target, Args, ArrayPrototype, Limits, BeforeElements);
    TIterationMethod.LastIndexOf : Result := LastIndexOf(Target, Args);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [METHODS[Method].Name]);
  end;
end;

class function TJSArrayIteration.Call(const Target: IJSObject; const MethodName: string;
                                      const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                      const ArrayPrototype: IJSObject; const Limits: TJSLimits;
                                      const BeforeElements: TProc): TJSValue;
begin
  if not Assigned(Target) then
  begin
    const Message = Format(NOT_CALLED_ON_OBJECT, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  var Method: TIterationMethod;
  if not TryFindMethod(MethodName, Method) then
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [MethodName]);

  if Method in CALLBACK_METHODS then
    Result := CallWithCallback(Method, Target, Args, Executor, ArrayPrototype, Limits, BeforeElements)
  else
    Result := CallWithoutCallback(Method, Target, Args, ArrayPrototype, Limits, BeforeElements);
end;

class function TJSArrayIteration.ReadElement(const Target: IJSObject; const Index: Int64): TJSValue;
begin
  if not TJSArrayLike.TryGetElement(Target, Index, Result) then
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.At(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const IndexArgument = TJSArrayLike.Argument(Args, 0);
  const Relative = TJSConversions.ToIntegerOrInfinity(IndexArgument);

  var Position := Relative;
  const IsFromEnd = (Relative < 0);
  if IsFromEnd then
    Position := Count + Relative;

  const IsInRange = (Position >= 0) and (Position < Count);
  if IsInRange then
    Result := ReadElement(Target, Trunc(Position))
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.IncludesStart(const Args: TArray<TJSValue>; const Count: Int64): Int64;
begin
  const FromIndex = TJSArrayLike.ToIntegerArgument(Args, 1);

  const StartsPastEnd = (FromIndex >= Count);
  if StartsPastEnd then
  begin
    Result := Count;
    Exit;
  end;

  const StartsFromEnd = (FromIndex < 0);
  if StartsFromEnd then
    Result := Trunc(Max(Count + FromIndex, 0))
  else
    Result := Trunc(FromIndex);
end;

class function TJSArrayIteration.Includes(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateBoolean(False);

  const Count = TJSArrayLike.ToLength(Target);
  const IsEmpty = (Count = 0);
  if IsEmpty then
    Exit;

  const Start = IncludesStart(Args, Count);
  const SearchElement = TJSArrayLike.Argument(Args, 0);
  for var Index: Int64 := Start to Count - 1 do
  begin
    const Element = TJSArrayLike.GetElement(Target, Index);
    const IsSame = Element.StrictEquals(SearchElement) or (Element.IsNaN and SearchElement.IsNaN);
    if IsSame then
    begin
      Result := TJSValue.CreateBoolean(True);
      Exit;
    end;
  end;
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
    begin
      const MapperArguments = CallbackArguments(Element, Index, Source);
      Element := Executor(Mapper, MapperArguments);
    end;

    const ShouldFlatten = (Depth > 0) and TJSObjectOperations.IsArray(Element);
    if ShouldFlatten then
    begin
      Limits.EnsureNestingDepth(Level + 1);

      const Nested = Element.ToObject;
      const NestedLength = TJSArrayLike.ToLength(Nested);
      FlattenInto(Flattened, Nested, NestedLength, Depth - 1, Level + 1, nil, Executor, Limits);
      Continue;
    end;

    Limits.EnsureArrayLength(Int64(Flattened.Length) + 1);
    Flattened.Push(Element);
  end;
end;

class function TJSArrayIteration.Flat(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const ArrayPrototype: IJSObject; const Limits: TJSLimits;
                                      const BeforeElements: TProc): TJSValue;
begin
  const SourceLength = TJSArrayLike.ToLength(Target);
  const Depth = FlatDepth(Args);
  NotifyBeforeElements(BeforeElements);

  const Flattened: IJSArray = TJSArray.Create;
  Flattened.Prototype := ArrayPrototype;
  FlattenInto(Flattened, Target, SourceLength, Depth, 0, nil, nil, Limits);

  Result := TJSValue.CreateObject(Flattened);
end;

class function TJSArrayIteration.FlatMap(const Target: IJSObject; const Args: TArray<TJSValue>;
                                         const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                                         const Limits: TJSLimits; const BeforeElements: TProc): TJSValue;
begin
  const SourceLength = TJSArrayLike.ToLength(Target);
  const Mapper = RequireCallback(METHOD_FLAT_MAP, Args);
  NotifyBeforeElements(BeforeElements);

  const Flattened: IJSArray = TJSArray.Create;
  Flattened.Prototype := ArrayPrototype;
  FlattenInto(Flattened, Target, SourceLength, 1, 0, Mapper, Executor, Limits);

  Result := TJSValue.CreateObject(Flattened);
end;

class procedure TJSArrayIteration.NotifyBeforeElements(const BeforeElements: TProc);
begin
  if Assigned(BeforeElements) then
    BeforeElements();
end;

class function TJSArrayIteration.ToIntegerClamped(const Value: TJSValue): Int64;
begin
  const Number = TJSConversions.ToIntegerOrInfinity(Value);

  Result := Trunc(EnsureRange(Number, -MAX_INTEGER_MAGNITUDE, MAX_INTEGER_MAGNITUDE));
end;

class function TJSArrayIteration.RequireCallback(const MethodName: string;
                                                 const Args: TArray<TJSValue>): IJSFunction;
begin
  const CallbackArgument = TJSArrayLike.Argument(Args, 0);
  if not CallbackArgument.TryGetFunction(Result) then
  begin
    const Message = Format(CALLBACK_NOT_A_FUNCTION, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
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
                                     const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject;
                                     const BeforeElements: TProc): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_MAP, Args);
  NotifyBeforeElements(BeforeElements);
  const ExceedsArrayLength = (Count > MaxInt);
  if ExceedsArrayLength then
    raise TJSErrorFactory.InvalidArrayLength;

  const Mapped: IJSArray = TJSArray.Create;
  Mapped.Prototype := ArrayPrototype;
  const HasElements = (Count > 0);
  if HasElements then
    Mapped[Integer(Count - 1)] := TJSValue.CreateUndefined;

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const CallbackArgs = CallbackArguments(Element, Index, Target);
      const MappedElement = Executor(Callback, CallbackArgs);
      Mapped[Integer(Index)] := MappedElement;
    end;
  end;

  Result := TJSValue.CreateObject(Mapped);
end;

class function TJSArrayIteration.Filter(const Target: IJSObject; const Args: TArray<TJSValue>;
                                        const Executor: TJSCallbackExecutor;
                                        const ArrayPrototype: IJSObject; const BeforeElements: TProc): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(METHOD_FILTER, Args);
  NotifyBeforeElements(BeforeElements);
  const Kept: IJSArray = TJSArray.Create;
  Kept.Prototype := ArrayPrototype;

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    const CallbackArgs = CallbackArguments(Element, Index, Target);
    const CallbackResult = Executor(Callback, CallbackArgs);
    if CallbackResult.ToBoolean then
      Kept.Push(Element);
  end;

  Result := TJSValue.CreateObject(Kept);
end;

class function TJSArrayIteration.HasElementWithOutcome(const MethodName: string; const Target: IJSObject;
                                                         const Args: TArray<TJSValue>;
                                                         const Executor: TJSCallbackExecutor;
                                                         const Outcome: Boolean): Boolean;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(MethodName, Args);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Index, Element) then
      Continue;

    const CallbackArgs = CallbackArguments(Element, Index, Target);
    const CallbackResult = Executor(Callback, CallbackArgs);
    const HasOutcome = (CallbackResult.ToBoolean = Outcome);
    if HasOutcome then
      Exit(True);
  end;

  Result := False;
end;

class function TJSArrayIteration.Some(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Executor: TJSCallbackExecutor): TJSValue;
begin
  const HasMatch = HasElementWithOutcome(METHOD_SOME, Target, Args, Executor, True);

  Result := TJSValue.CreateBoolean(HasMatch);
end;

class function TJSArrayIteration.Every(const Target: IJSObject; const Args: TArray<TJSValue>;
                                       const Executor: TJSCallbackExecutor): TJSValue;
begin
  const HasMismatch = HasElementWithOutcome(METHOD_EVERY, Target, Args, Executor, False);

  Result := TJSValue.CreateBoolean(not HasMismatch);
end;

class function TJSArrayIteration.FindMatch(const MethodName: string; const Target: IJSObject;
                                           const Args: TArray<TJSValue>;
                                           const Executor: TJSCallbackExecutor): TFindMatch;
begin
  Result.IsFound := False;
  Result.Index := -1;
  Result.Element := TJSValue.CreateUndefined;

  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(MethodName, Args);

  for var Position: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    if not TJSArrayLike.TryGetElement(Target, Position, Element) then
      Element := TJSValue.CreateUndefined;

    const CallbackArgs = CallbackArguments(Element, Position, Target);
    const CallbackResult = Executor(Callback, CallbackArgs);
    if CallbackResult.ToBoolean then
    begin
      Result.IsFound := True;
      Result.Index := Position;
      Result.Element := Element;
      Exit;
    end;
  end;
end;

class function TJSArrayIteration.Find(const Target: IJSObject; const Args: TArray<TJSValue>;
                                      const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Match = FindMatch(METHOD_FIND, Target, Args, Executor);

  if Match.IsFound then
    Result := Match.Element
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayIteration.FindIndex(const Target: IJSObject; const Args: TArray<TJSValue>;
                                           const Executor: TJSCallbackExecutor): TJSValue;
begin
  const Match = FindMatch(METHOD_FIND_INDEX, Target, Args, Executor);

  Result := TJSValue.CreateNumber(Match.Index);
end;

class function TJSArrayIteration.Reduce(const Target: IJSObject; const Args: TArray<TJSValue>;
                                        const Executor: TJSCallbackExecutor): TJSValue;
begin
  Result := ReduceInDirection(Target, Args, Executor, METHOD_REDUCE, 1);
end;

class function TJSArrayIteration.ReduceRight(const Target: IJSObject; const Args: TArray<TJSValue>;
                                             const Executor: TJSCallbackExecutor): TJSValue;
begin
  Result := ReduceInDirection(Target, Args, Executor, METHOD_REDUCE_RIGHT, -1);
end;

class function TJSArrayIteration.FindReduceStart(const Target: IJSObject; const Args: TArray<TJSValue>;
                                                 const Count: Int64; const Step: Integer): TReduceStart;
begin
  Result.Accumulator := TJSValue.CreateUndefined;
  Result.NextIndex := 0;

  const IsBackward = (Step < 0);
  if IsBackward then
    Result.NextIndex := Count - 1;

  const HasInitialValue = (Length(Args) > 1);
  if HasInitialValue then
  begin
    Result.Accumulator := Args[1];
    Exit;
  end;

  var FoundFirst := False;
  while (not FoundFirst) and (Result.NextIndex >= 0) and (Result.NextIndex < Count) do
  begin
    FoundFirst := TJSArrayLike.TryGetElement(Target, Result.NextIndex, Result.Accumulator);
    Inc(Result.NextIndex, Step);
  end;

  if not FoundFirst then
    raise TJSErrorFactory.TypeError(REDUCE_OF_EMPTY_ARRAY);
end;

class function TJSArrayIteration.ReduceInDirection(const Target: IJSObject; const Args: TArray<TJSValue>;
                                                   const Executor: TJSCallbackExecutor;
                                                   const MethodName: string; const Step: Integer): TJSValue;
begin
  const Count = TJSArrayLike.ToLength(Target);
  const Callback = RequireCallback(MethodName, Args);
  const Start = FindReduceStart(Target, Args, Count, Step);

  var Accumulator := Start.Accumulator;
  var Index := Start.NextIndex;

  const TargetValue = TJSValue.CreateObject(Target);
  while (Index >= 0) and (Index < Count) do
  begin
    var Element: TJSValue;
    if TJSArrayLike.TryGetElement(Target, Index, Element) then
    begin
      const IndexValue = TJSValue.CreateNumber(Index);
      const CallbackArgs: TArray<TJSValue> = [Accumulator, Element, IndexValue, TargetValue];
      Accumulator := Executor(Callback, CallbackArgs);
    end;

    Inc(Index, Step);
  end;

  Result := Accumulator;
end;

class function TJSArrayIteration.IndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const NotFound = TJSValue.CreateNumber(-1);
  const Count = TJSArrayLike.ToLength(Target);
  const IsEmpty = (Count = 0);
  if IsEmpty then
    Exit(NotFound);

  const SearchElement = TJSArrayLike.Argument(Args, 0);
  const StartArgument = TJSArrayLike.Argument(Args, 1);
  const RequestedStart = ToIntegerClamped(StartArgument);
  const StartsPastEnd = (RequestedStart >= Count);
  if StartsPastEnd then
    Exit(NotFound);

  var StartIndex := RequestedStart;
  const StartsFromEnd = (RequestedStart < 0);
  if StartsFromEnd then
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

class function TJSArrayIteration.LastIndexStart(const Args: TArray<TJSValue>; const Count: Int64): Int64;
begin
  Result := Count - 1;

  const HasStartArgument = (Length(Args) > 1);
  if not HasStartArgument then
    Exit;

  const RequestedStart = ToIntegerClamped(Args[1]);
  const StartsFromBeginning = (RequestedStart >= 0);
  if StartsFromBeginning then
    Result := Min(RequestedStart, Count - 1)
  else
    Result := Count + RequestedStart;
end;

class function TJSArrayIteration.LastIndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := TJSValue.CreateNumber(-1);

  const Count = TJSArrayLike.ToLength(Target);
  const IsEmpty = (Count = 0);
  if IsEmpty then
    Exit;

  const SearchElement = TJSArrayLike.Argument(Args, 0);
  for var Index := LastIndexStart(Args, Count) downto 0 do
  begin
    var Element: TJSValue;
    const IsMatch = TJSArrayLike.TryGetElement(Target, Index, Element) and Element.StrictEquals(SearchElement);
    if IsMatch then
    begin
      Result := TJSValue.CreateNumber(Index);
      Exit;
    end;
  end;
end;

end.
