unit JS4D.ArrayIteration;

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
    class function IndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;
    class function LastIndexOf(const Target: IJSObject; const Args: TArray<TJSValue>): TJSValue; static;

  public
    class function Handles(const MethodName: string): Boolean; static;
    class function Call(const Target: IJSObject; const MethodName: string; const Args: TArray<TJSValue>;
                        const Executor: TJSCallbackExecutor; const ArrayPrototype: IJSObject): TJSValue; static;
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
            (MethodName = METHOD_LAST_INDEX_OF);
end;

class function TJSArrayIteration.Call(const Target: IJSObject; const MethodName: string;
                                      const Args: TArray<TJSValue>; const Executor: TJSCallbackExecutor;
                                      const ArrayPrototype: IJSObject): TJSValue;
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

  if MethodName = METHOD_INDEX_OF then
    Exit(IndexOf(Target, Args));

  if MethodName = METHOD_LAST_INDEX_OF then
    Exit(LastIndexOf(Target, Args));

  raise ENotSupportedException.CreateFmt('Unsupported array iteration method: %s', [MethodName]);
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
