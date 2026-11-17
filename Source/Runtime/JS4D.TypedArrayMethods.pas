unit JS4D.TypedArrayMethods;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BinaryData,
  JS4D.BuiltinSupport,
  JS4D.ArrayIterator,
  JS4D.DoubleMergeSorter,
  JS4D.TypedArrayBuiltins;

type
  TJSTypedArrayMethods = class
  private
    type
      TViewMethod = reference to function(const This: IJSObject; const View: IJSTypedArray;
                                          const Args: TArray<TJSValue>): TJSValue;
      TElementCallback = record
        Func: IJSFunction;
        ThisArgument: IJSObject;
        Subject: TJSValue;
      end;
      TScanMode = (Every, Some, ForEach, Find, FindIndex);
      TSearchMode = (IndexOf, LastIndexOf, Includes);

    const
      BUFFER_PROPERTY = 'buffer';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_OFFSET_PROPERTY = 'byteOffset';
      SORT_ALLOCATION_FAILED = 'Typed array too large to sort';
      UNSUPPORTED_SCAN_MODE = 'Unsupported scan mode: %d';
      TAG_GETTER_NAME = 'get [Symbol.toStringTag]';
      AT_NAME = 'at';
      EVERY_NAME = 'every';
      SOME_NAME = 'some';
      FOR_EACH_NAME = 'forEach';
      FIND_NAME = 'find';
      FIND_INDEX_NAME = 'findIndex';
      MAP_NAME = 'map';
      FILTER_NAME = 'filter';
      REDUCE_NAME = 'reduce';
      REDUCE_RIGHT_NAME = 'reduceRight';
      ENTRIES_NAME = 'entries';
      KEYS_NAME = 'keys';
      VALUES_NAME = 'values';
      INDEX_OF_NAME = 'indexOf';
      LAST_INDEX_OF_NAME = 'lastIndexOf';
      INCLUDES_NAME = 'includes';
      FILL_NAME = 'fill';
      REVERSE_NAME = 'reverse';
      COPY_WITHIN_NAME = 'copyWithin';
      SORT_NAME = 'sort';
      SET_NAME = 'set';
      SLICE_NAME = 'slice';
      SUBARRAY_NAME = 'subarray';
      JOIN_NAME = 'join';
      TO_STRING_NAME = 'toString';
      TO_LOCALE_STRING_NAME = 'toLocaleString';
      CALLBACK_NOT_CALLABLE = 'The callback of %s is not a function';
      COMPARER_NOT_CALLABLE = 'The comparison function must be either a function or undefined';
      REDUCE_EMPTY = 'Reduce of empty array with no initial value';
      NEGATIVE_OFFSET = 'Offset is out of bounds';
      SOURCE_TOO_LONG = 'Source is too large for the offset';
      LOCALE_METHOD_MISSING = 'The toLocaleString of an element is not a function';

    var
      FBuiltins: TJSTypedArrayBuiltins;
      FSupport: TJSBuiltinSupport;
      FInterpreter: TJSInterpreter;
      FPrototype: IJSObject;

    class function NotFound(const Mode: TSearchMode): TJSValue; static;
    class function IsMatchAt(const View: IJSTypedArray; const Index: Int64; const Target: TJSValue;
                             const Mode: TSearchMode): Boolean; static;
    class function BackwardStart(const Args: TArray<TJSValue>; const ElementCount: Int64): Int64; static;
    function ReduceFrom(const This: IJSObject; const View: IJSTypedArray; const Callback: IJSFunction;
                        const InitialValue: TJSValue; const FirstIndex: Int64; const Step: Integer): TJSValue;
    class function FirstIndex(const Offset: Double; const Count: Int64): Int64; static;

    procedure DefineView(const Name: string; const ParameterCount: Integer; const Method: TViewMethod);
    procedure DefineGetters;
    procedure DefineLayoutGetters;
    procedure DefineByteGetters;
    procedure DefineTagGetter;
    procedure DefineIterationMethods;
    procedure DefineScan(const Name: string; const Mode: TScanMode);
    procedure DefineScanMethods;
    procedure DefineReduce(const Name: string; const FromEnd: Boolean);
    procedure DefineReduceMethods;
    procedure DefineIterator(const Name: string; const Kind: TJSArrayIteratorKind);
    procedure DefineIteratorMethods;
    procedure DefineSearch(const Name: string; const Mode: TSearchMode);
    procedure DefineSearchMethods;
    procedure DefineMutatingMethods;
    procedure DefineCopyingMethods;
    procedure DefineTextMethods;
    function RequireCallback(const Value: TJSValue; const MethodName: string): IJSFunction;
    function OpenCallback(const This: IJSObject; const Args: TArray<TJSValue>;
                          const MethodName: string): TElementCallback;
    function InvokeCallback(const Callback: TElementCallback; const Element: TJSValue;
                            const Index: Integer): TJSValue;
    class function StopsScan(const Mode: TScanMode; const Outcome: Boolean): Boolean; static;
    class function StoppedScanResult(const Mode: TScanMode; const Element: TJSValue;
                                     const Index: Integer): TJSValue; static;
    class function ExhaustedScanResult(const Mode: TScanMode): TJSValue; static;
    function CreateIterator(const This: IJSObject; const Kind: TJSArrayIteratorKind): TJSValue;
    function At(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function Scan(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>;
                  const Mode: TScanMode; const MethodName: string): TJSValue;
    function MapElements(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function FilterElements(const This: IJSObject; const View: IJSTypedArray;
                            const Args: TArray<TJSValue>): TJSValue;
    function Reduce(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>;
                    const FromEnd: Boolean; const MethodName: string): TJSValue;
    function Search(const View: IJSTypedArray; const Args: TArray<TJSValue>; const Mode: TSearchMode): TJSValue;
    function SearchForward(const View: IJSTypedArray; const Args: TArray<TJSValue>;
                           const Mode: TSearchMode): TJSValue;
    function SearchBackward(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function Join(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function JoinLocaleStrings(const View: IJSTypedArray): TJSValue;
    function Fill(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function Reverse(const This: IJSObject; const View: IJSTypedArray): TJSValue;
    function CopyWithin(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    function SetElements(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    procedure SetFromTypedArray(const Target: IJSTypedArray; const Offset: Double; const Source: IJSTypedArray);
    procedure SetFromArrayLike(const Target: IJSTypedArray; const Offset: Double; const Source: TJSValue);
    function Slice(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
    procedure CopyRange(const View: IJSTypedArray; const Target: IJSTypedArray; const FromIndex: Integer;
                        const EndIndex: Integer);
    procedure CopyBytesAscending(const View: IJSTypedArray; const Target: IJSTypedArray; const FromIndex: Integer;
                        const EndIndex: Integer);
    procedure CopyElements(const View: IJSTypedArray; const Target: IJSTypedArray; const FromIndex: Integer;
                           const EndIndex: Integer);
    function Subarray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Sort(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function AllocateSortValues(const ElementCount: Integer): TArray<Double>;
    function SortValues(const Values: TArray<Double>; const Comparer: TJSElementComparer): TArray<Double>;
    function CreateComparer(const Comparer: IJSFunction): TJSElementComparer;

  public
    constructor Create(const Builtins: TJSTypedArrayBuiltins);

    procedure Register;
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.Conversions,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.SymbolRegistry;

constructor TJSTypedArrayMethods.Create(const Builtins: TJSTypedArrayBuiltins);
begin
  inherited Create;

  FBuiltins := Builtins;
  FSupport := Builtins.Support;
  FInterpreter := FSupport.Interpreter;
end;

class function TJSTypedArrayMethods.NotFound(const Mode: TSearchMode): TJSValue;
begin
  const IsIncludesMode = (Mode = TSearchMode.Includes);
  if IsIncludesMode then
  begin
    Result := TJSValue.CreateBoolean(False);
    Exit;
  end;

  Result := TJSValue.CreateNumber(-1);
end;

class function TJSTypedArrayMethods.FirstIndex(const Offset: Double; const Count: Int64): Int64;
begin
  const IsNonNegative = (Offset >= 0);
  if IsNonNegative then
  begin
    Result := Trunc(Min(Offset, Count));
    Exit;
  end;

  Result := Trunc(Max(Count + Offset, 0));
end;

procedure TJSTypedArrayMethods.DefineView(const Name: string; const ParameterCount: Integer;
                                          const Method: TViewMethod);
begin
  FSupport.DefineMethod(FPrototype, Name, ParameterCount,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.ValidateTypedArray(This, Name);

      Result := Method(This, View, Args);
    end);
end;

function TJSTypedArrayMethods.RequireCallback(const Value: TJSValue; const MethodName: string): IJSFunction;
begin
  if not Value.TryGetFunction(Result) then
  begin
    const Message = Format(CALLBACK_NOT_CALLABLE, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

procedure TJSTypedArrayMethods.DefineGetters;
begin
  DefineLayoutGetters;
  DefineByteGetters;
  DefineTagGetter;
end;

procedure TJSTypedArrayMethods.DefineLayoutGetters;
begin
  const BufferGetterName = Format(GETTER_NAME_FORMAT, [BUFFER_PROPERTY]);
  const LengthGetterName = Format(GETTER_NAME_FORMAT, [LENGTH_PROPERTY]);

  FSupport.DefineGetter(FPrototype, BUFFER_PROPERTY, BufferGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.RequireTypedArray(This);

      Result := TJSValue.CreateObject(View.Buffer);
    end);

  FSupport.DefineGetter(FPrototype, LENGTH_PROPERTY, LengthGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.RequireTypedArray(This);

      Result := TJSValue.CreateNumber(View.Length);
    end);
end;

procedure TJSTypedArrayMethods.DefineByteGetters;
begin
  const ByteLengthGetterName = Format(GETTER_NAME_FORMAT, [BYTE_LENGTH_PROPERTY]);
  const ByteOffsetGetterName = Format(GETTER_NAME_FORMAT, [BYTE_OFFSET_PROPERTY]);

  FSupport.DefineGetter(FPrototype, BYTE_LENGTH_PROPERTY, ByteLengthGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.RequireTypedArray(This);

      Result := TJSValue.CreateNumber(View.Length * View.Kind.ElementSize);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_OFFSET_PROPERTY, ByteOffsetGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.RequireTypedArray(This);

      Result := TJSValue.CreateNumber(View.ByteOffset);
    end);
end;

procedure TJSTypedArrayMethods.DefineTagGetter;
begin
  const TagKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);
  FSupport.DefineGetter(FPrototype, TagKey, TAG_GETTER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var View: IJSTypedArray;
      if Supports(This, IJSTypedArray, View) then
        Result := TJSValue.CreateString(View.Kind.ConstructorName)
      else
        Result := TJSValue.CreateUndefined;
    end);
end;

function TJSTypedArrayMethods.CreateIterator(const This: IJSObject; const Kind: TJSArrayIteratorKind): TJSValue;
begin
  const Iterator = TJSArrayIterator.Create(This, Kind, FInterpreter.ArrayPrototype, FInterpreter.ObjectPrototype);
  Iterator.Prototype := FInterpreter.Iteration.ArrayIteratorPrototype;

  Result := TJSValue.CreateObject(Iterator);
end;

function TJSTypedArrayMethods.At(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Relative = TJSArrayLike.ToIntegerArgument(Args, 0);

  var Position := Relative;
  const IsFromEnd = (Relative < 0);
  if IsFromEnd then
    Position := ElementCount + Relative;

  const IsOutside = (Position < 0) or (Position >= ElementCount);
  if IsOutside then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := View.ReadElement(Trunc(Position));
end;

function TJSTypedArrayMethods.OpenCallback(const This: IJSObject; const Args: TArray<TJSValue>;
                                           const MethodName: string): TElementCallback;
begin
  const CallbackValue = TJSArrayLike.Argument(Args, 0);
  Result.Func := RequireCallback(CallbackValue, MethodName);

  const ThisValue = TJSArrayLike.Argument(Args, 1);
  Result.ThisArgument := FInterpreter.ThisObjectFor(Result.Func, ThisValue);
  Result.Subject := TJSValue.CreateObject(This);
end;

function TJSTypedArrayMethods.InvokeCallback(const Callback: TElementCallback; const Element: TJSValue;
                                             const Index: Integer): TJSValue;
begin
  const IndexValue = TJSValue.CreateNumber(Index);

  Result := FInterpreter.CallFunction(Callback.Func, [Element, IndexValue, Callback.Subject],
                                      Callback.ThisArgument);
end;

class function TJSTypedArrayMethods.StopsScan(const Mode: TScanMode; const Outcome: Boolean): Boolean;
begin
  case Mode of
    TScanMode.Every     : Result := (not Outcome);
    TScanMode.Some,
    TScanMode.Find,
    TScanMode.FindIndex : Result := Outcome;
    TScanMode.ForEach   : Result := False;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_SCAN_MODE, [Ord(Mode)]);
  end;
end;

class function TJSTypedArrayMethods.StoppedScanResult(const Mode: TScanMode; const Element: TJSValue;
                                                      const Index: Integer): TJSValue;
begin
  case Mode of
    TScanMode.Every     : Result := TJSValue.CreateBoolean(False);
    TScanMode.Some      : Result := TJSValue.CreateBoolean(True);
    TScanMode.Find      : Result := Element;
    TScanMode.FindIndex : Result := TJSValue.CreateNumber(Index);
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_SCAN_MODE, [Ord(Mode)]);
  end;
end;

class function TJSTypedArrayMethods.ExhaustedScanResult(const Mode: TScanMode): TJSValue;
begin
  case Mode of
    TScanMode.Every     : Result := TJSValue.CreateBoolean(True);
    TScanMode.Some      : Result := TJSValue.CreateBoolean(False);
    TScanMode.FindIndex : Result := TJSValue.CreateNumber(-1);
  else
    Result := TJSValue.CreateUndefined;
  end;
end;

function TJSTypedArrayMethods.Scan(const This: IJSObject; const View: IJSTypedArray;
                                   const Args: TArray<TJSValue>; const Mode: TScanMode;
                                   const MethodName: string): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = OpenCallback(This, Args, MethodName);

  for var Index := 0 to ElementCount - 1 do
  begin
    const Element = View.ReadElement(Index);
    const Returned = InvokeCallback(Callback, Element, Index);
    const Outcome = Returned.ToBoolean;
    const Stops = StopsScan(Mode, Outcome);
    if Stops then
    begin
      Result := StoppedScanResult(Mode, Element, Index);
      Exit;
    end;
  end;

  Result := ExhaustedScanResult(Mode);
end;

function TJSTypedArrayMethods.MapElements(const This: IJSObject; const View: IJSTypedArray;
                                          const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = OpenCallback(This, Args, MAP_NAME);

  const CountArguments: TArray<TJSValue> = [TJSValue.CreateNumber(ElementCount)];
  const Target = FBuiltins.SpeciesCreate(View, CountArguments, MAP_NAME);
  for var Index := 0 to ElementCount - 1 do
  begin
    const Element = View.ReadElement(Index);
    const Mapped = InvokeCallback(Callback, Element, Index);
    Target.StoreConvertedValue(Index, Mapped);
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSTypedArrayMethods.FilterElements(const This: IJSObject; const View: IJSTypedArray;
                                             const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = OpenCallback(This, Args, FILTER_NAME);

  const Kept = TList<TJSValue>.Create;
  try
    for var Index := 0 to ElementCount - 1 do
    begin
      const Element = View.ReadElement(Index);
      const Returned = InvokeCallback(Callback, Element, Index);
      const IsSelected = Returned.ToBoolean;
      if IsSelected then
        Kept.Add(Element);
    end;

    const CountArguments: TArray<TJSValue> = [TJSValue.CreateNumber(Kept.Count)];
    const Target = FBuiltins.SpeciesCreate(View, CountArguments, FILTER_NAME);
    for var Position := 0 to Kept.Count - 1 do
    begin
      Target.StoreConvertedValue(Position, Kept[Position]);
    end;

    Result := TJSValue.CreateObject(Target);
  finally
    Kept.Free;
  end;
end;

function TJSTypedArrayMethods.ReduceFrom(const This: IJSObject; const View: IJSTypedArray;
                                         const Callback: IJSFunction; const InitialValue: TJSValue;
                                         const FirstIndex: Int64; const Step: Integer): TJSValue;
begin
  const ElementCount = View.Length;
  const Subject = TJSValue.CreateObject(This);
  const Undefined = TJSValue.CreateUndefined;
  const ThisArgument = FInterpreter.ThisObjectFor(Callback, Undefined);

  Result := InitialValue;

  var Index := FirstIndex;
  while (Index >= 0) and (Index < ElementCount) do
  begin
    const Element = View.ReadElement(Integer(Index));
    const IndexValue = TJSValue.CreateNumber(Index);
    const CallbackArgs: TArray<TJSValue> = [Result, Element, IndexValue, Subject];
    Result := FInterpreter.CallFunction(Callback, CallbackArgs, ThisArgument);
    Inc(Index, Step);
  end;
end;

function TJSTypedArrayMethods.Reduce(const This: IJSObject; const View: IJSTypedArray;
                                     const Args: TArray<TJSValue>; const FromEnd: Boolean;
                                     const MethodName: string): TJSValue;
begin
  const ElementCount = View.Length;
  const CallbackArgument = TJSArrayLike.Argument(Args, 0);
  const Callback = RequireCallback(CallbackArgument, MethodName);

  const HasInitialValue = Length(Args) >= 2;
  const IsEmptyWithoutInitial = (ElementCount = 0) and (not HasInitialValue);
  if IsEmptyWithoutInitial then
    raise TJSErrorFactory.TypeError(REDUCE_EMPTY);

  var Step := 1;
  var Index: Int64 := 0;
  if FromEnd then
  begin
    Step := -1;
    Index := ElementCount - 1;
  end;

  var Accumulator: TJSValue;
  if HasInitialValue then
  begin
    Accumulator := Args[1];
  end
  else
  begin
    Accumulator := View.ReadElement(Integer(Index));
    Inc(Index, Step);
  end;

  Result := ReduceFrom(This, View, Callback, Accumulator, Index, Step);
end;

class function TJSTypedArrayMethods.IsMatchAt(const View: IJSTypedArray; const Index: Int64;
                                              const Target: TJSValue; const Mode: TSearchMode): Boolean;
begin
  const IsPresent = (Index < View.Length);
  const Element = View.ReadElement(Integer(Index));

  const IsIncludesMode = (Mode = TSearchMode.Includes);
  if IsIncludesMode then
    Result := Element.SameValueZero(Target)
  else
    Result := (IsPresent and Element.StrictEquals(Target));
end;

function TJSTypedArrayMethods.SearchForward(const View: IJSTypedArray; const Args: TArray<TJSValue>;
                                            const Mode: TSearchMode): TJSValue;
begin
  const ElementCount = View.Length;
  const IsEmpty = (ElementCount = 0);
  if IsEmpty then
  begin
    Result := NotFound(Mode);
    Exit;
  end;

  const Target = TJSArrayLike.Argument(Args, 0);
  const Offset = TJSArrayLike.ToIntegerArgument(Args, 1);
  const IsInfiniteOffset = (Offset = Infinity);
  if IsInfiniteOffset then
  begin
    Result := NotFound(Mode);
    Exit;
  end;

  const IsIncludesMode = (Mode = TSearchMode.Includes);
  for var Index := FirstIndex(Offset, ElementCount) to ElementCount - 1 do
  begin
    if not IsMatchAt(View, Index, Target, Mode) then
      Continue;

    if IsIncludesMode then
      Result := TJSValue.CreateBoolean(True)
    else
      Result := TJSValue.CreateNumber(Index);

    Exit;
  end;

  Result := NotFound(Mode);
end;

class function TJSTypedArrayMethods.BackwardStart(const Args: TArray<TJSValue>; const ElementCount: Int64): Int64;
begin
  var Offset: Double := ElementCount - 1;
  const HasStartArgument = (Length(Args) > 1);
  if HasStartArgument then
    Offset := TJSConversions.ToIntegerOrInfinity(Args[1]);

  const IsBeforeStart = (Offset = NegInfinity);
  if IsBeforeStart then
    Exit(-1);

  const IsNonNegativeOffset = (Offset >= 0);
  if IsNonNegativeOffset then
    Result := Trunc(Min(Offset, ElementCount - 1))
  else
    Result := Trunc(ElementCount + Offset);
end;

function TJSTypedArrayMethods.SearchBackward(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  Result := NotFound(TSearchMode.LastIndexOf);

  const IsEmpty = (ElementCount = 0);
  if IsEmpty then
    Exit;

  const Target = TJSArrayLike.Argument(Args, 0);
  var Index := BackwardStart(Args, ElementCount);
  while Index >= 0 do
  begin
    if IsMatchAt(View, Index, Target, TSearchMode.LastIndexOf) then
    begin
      Result := TJSValue.CreateNumber(Index);
      Exit;
    end;

    Dec(Index);
  end;
end;

function TJSTypedArrayMethods.Search(const View: IJSTypedArray; const Args: TArray<TJSValue>;
                                     const Mode: TSearchMode): TJSValue;
begin
  const IsLastIndexOf = (Mode = TSearchMode.LastIndexOf);
  if IsLastIndexOf then
    Result := SearchBackward(View, Args)
  else
    Result := SearchForward(View, Args, Mode);
end;

function TJSTypedArrayMethods.Join(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const SeparatorArgument = TJSArrayLike.Argument(Args, 0);

  var Separator: string := ARRAY_SEPARATOR;
  if not SeparatorArgument.IsUndefined then
  begin
    const SeparatorPrimitive = SeparatorArgument.ToPrimitiveWithHint(TJSPrimitiveHint.String_);
    Separator := SeparatorPrimitive.ToLimitedString(FInterpreter.Limits);
  end;

  const Builder = TStringBuilder.Create;
  try
    for var Index := 0 to ElementCount - 1 do
    begin
      const HasSeparator = (Index > 0);
      if HasSeparator then
        Builder.Append(Separator);

      const Element = View.ReadElement(Index);
      if not Element.IsUndefined then
        Builder.Append(Element.ToString);

      FInterpreter.Limits.EnsureStringLength(Builder.Length);
    end;

    Result := TJSValue.CreateString(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

function TJSTypedArrayMethods.JoinLocaleStrings(const View: IJSTypedArray): TJSValue;
begin
  const ElementCount = View.Length;

  const Builder = TStringBuilder.Create;
  try
    for var Index := 0 to ElementCount - 1 do
    begin
      const HasSeparator = (Index > 0);
      if HasSeparator then
        Builder.Append(ARRAY_SEPARATOR);

      const Element = View.ReadElement(Index);
      if Element.IsNullOrUndefined then
        Continue;

      const Wrapper = FSupport.ToObject(Element);
      const MethodValue = Wrapper.GetProperty(TO_LOCALE_STRING_NAME);
      var Method: IJSFunction;
      if not MethodValue.TryGetFunction(Method) then
        raise TJSErrorFactory.TypeError(LOCALE_METHOD_MISSING);

      const Text = FInterpreter.CallFunction(Method, nil, Wrapper);
      const TextPrimitive = Text.ToPrimitiveWithHint(TJSPrimitiveHint.String_);
      const ElementText = TextPrimitive.ToLimitedString(FInterpreter.Limits);
      Builder.Append(ElementText);
    end;

    Result := TJSValue.CreateString(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

function TJSTypedArrayMethods.Fill(const This: IJSObject; const View: IJSTypedArray;
                                   const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const ValueArgument = TJSArrayLike.Argument(Args, 0);
  const ValuePrimitive = ValueArgument.ToPrimitiveWithHint(TJSPrimitiveHint.Number);
  const Number = ValuePrimitive.ToNumber;
  const StartIndex = TJSArrayLike.RelativeIndexArgument(Args, 1, ElementCount, 0);
  const EndIndex = TJSArrayLike.RelativeIndexArgument(Args, 2, ElementCount, ElementCount);

  TJSBuiltinSupport.RequireNotDetached(View.IsDetached, FILL_NAME);

  const FillValue = TJSValue.CreateNumber(Number);
  const StopIndex = Min(EndIndex, View.Length);
  for var Index := StartIndex to StopIndex - 1 do
  begin
    FInterpreter.ConsumeStep;
    View.StoreConvertedValue(Integer(Index), FillValue);
  end;

  Result := TJSValue.CreateObject(This);
end;

function TJSTypedArrayMethods.Reverse(const This: IJSObject; const View: IJSTypedArray): TJSValue;
begin
  const ElementCount = View.Length;
  const Size = View.Kind.ElementSize;
  const Bytes = View.Buffer.Bytes;

  var Scratch: TElementBytes;
  var LowerIndex := 0;
  var UpperIndex := ElementCount - 1;
  while LowerIndex < UpperIndex do
  begin
    FInterpreter.ConsumeStep;

    const LowerOffset = View.ByteOffset + (LowerIndex * Size);
    const UpperOffset = View.ByteOffset + (UpperIndex * Size);

    Move(Bytes[LowerOffset], Scratch[0], Size);
    Move(Bytes[UpperOffset], Bytes[LowerOffset], Size);
    Move(Scratch[0], Bytes[UpperOffset], Size);

    Inc(LowerIndex);
    Dec(UpperIndex);
  end;

  Result := TJSValue.CreateObject(This);
end;

function TJSTypedArrayMethods.CopyWithin(const This: IJSObject; const View: IJSTypedArray;
                                         const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const TargetIndex = TJSArrayLike.RelativeIndexArgument(Args, 0, ElementCount, 0);
  const StartIndex = TJSArrayLike.RelativeIndexArgument(Args, 1, ElementCount, 0);
  const EndIndex = TJSArrayLike.RelativeIndexArgument(Args, 2, ElementCount, ElementCount);
  const Count = Min(EndIndex - StartIndex, ElementCount - TargetIndex);

  const HasElementsToMove = (Count > 0);
  if HasElementsToMove then
  begin
    TJSBuiltinSupport.RequireNotDetached(View.IsDetached, COPY_WITHIN_NAME);

    const Size = View.Kind.ElementSize;
    const Bytes = View.Buffer.Bytes;
    const SourceOffset = View.ByteOffset + Integer(StartIndex * Size);
    const TargetOffset = View.ByteOffset + Integer(TargetIndex * Size);
    Move(Bytes[SourceOffset], Bytes[TargetOffset], Integer(Count * Size));
  end;

  Result := TJSValue.CreateObject(This);
end;

procedure TJSTypedArrayMethods.SetFromTypedArray(const Target: IJSTypedArray; const Offset: Double;
                                                 const Source: IJSTypedArray);
begin
  TJSBuiltinSupport.RequireNotDetached((Target.IsDetached or Source.IsDetached), SET_NAME);

  const SourceLength = Source.Length;
  const ExceedsTarget = (Offset = Infinity) or ((SourceLength + Offset) > Target.Length);
  if ExceedsTarget then
    raise TJSErrorFactory.RangeError(SOURCE_TOO_LONG);

  const TargetBytes = Target.Buffer.Bytes;
  const SourceKind = Source.Kind;
  const TargetKind = Target.Kind;
  const TargetStart = Target.ByteOffset + (Trunc(Offset) * TargetKind.ElementSize);

  var SourceBytes := Source.Buffer.Bytes;
  var SourceStart := Source.ByteOffset;
  const IsSameBuffer = (Source.Buffer as IInterface) = (Target.Buffer as IInterface);
  if IsSameBuffer then
  begin
    SourceBytes := Copy(SourceBytes, SourceStart, SourceLength * SourceKind.ElementSize);
    SourceStart := 0;
  end;

  TJSElementCodec.CopyElements(SourceBytes, SourceStart, SourceKind, TargetBytes, TargetStart, TargetKind,
                               SourceLength);
end;

procedure TJSTypedArrayMethods.SetFromArrayLike(const Target: IJSTypedArray; const Offset: Double;
                                                const Source: TJSValue);
begin
  TJSBuiltinSupport.RequireNotDetached(Target.IsDetached, SET_NAME);

  const TargetLength = Target.Length;
  const SourceObject = FSupport.ToObject(Source);
  const SourceLength = TJSArrayLike.ToLength(SourceObject);
  const ExceedsTargetLength = (Offset = Infinity) or ((SourceLength + Offset) > TargetLength);
  if ExceedsTargetLength then
    raise TJSErrorFactory.RangeError(SOURCE_TOO_LONG);

  const TargetStart = Trunc(Offset);
  for var Index := 0 to SourceLength - 1 do
  begin
    FInterpreter.ConsumeStep;

    const Element = TJSArrayLike.GetElement(SourceObject, Index);
    Target.StoreConvertedValue(Integer(TargetStart + Index), Element);
  end;
end;

function TJSTypedArrayMethods.SetElements(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = FBuiltins.RequireTypedArray(This);
  const Offset = TJSArrayLike.ToIntegerArgument(Args, 1);
  const IsNegativeOffset = (Offset < 0);
  if IsNegativeOffset then
    raise TJSErrorFactory.RangeError(NEGATIVE_OFFSET);

  const Source = TJSArrayLike.Argument(Args, 0);
  var SourceView: IJSTypedArray;
  if Source.IsObject and Supports(Source.ToObject, IJSTypedArray, SourceView) then
    SetFromTypedArray(Target, Offset, SourceView)
  else
    SetFromArrayLike(Target, Offset, Source);

  Result := TJSValue.CreateUndefined;
end;

procedure TJSTypedArrayMethods.CopyRange(const View: IJSTypedArray; const Target: IJSTypedArray;
                                         const FromIndex: Integer; const EndIndex: Integer);
begin
  const HasSameKind = (View.Kind = Target.Kind);
  if HasSameKind then
    CopyBytesAscending(View, Target, FromIndex, EndIndex)
  else
    CopyElements(View, Target, FromIndex, EndIndex);
end;

procedure TJSTypedArrayMethods.CopyBytesAscending(const View: IJSTypedArray; const Target: IJSTypedArray;
                                                  const FromIndex: Integer; const EndIndex: Integer);
begin
  const Size = View.Kind.ElementSize;
  const SourceBytes = View.Buffer.Bytes;
  const TargetBytes = Target.Buffer.Bytes;
  var SourceIndex := View.ByteOffset + (FromIndex * Size);
  var TargetIndex := Target.ByteOffset;
  const TargetLimit = Min(TargetIndex + ((EndIndex - FromIndex) * Size), Length(TargetBytes));

  while TargetIndex < TargetLimit do
  begin
    TargetBytes[TargetIndex] := SourceBytes[SourceIndex];
    Inc(SourceIndex);
    Inc(TargetIndex);
  end;
end;

procedure TJSTypedArrayMethods.CopyElements(const View: IJSTypedArray; const Target: IJSTypedArray;
                                            const FromIndex: Integer; const EndIndex: Integer);
begin
  var TargetPosition := 0;
  for var Index := FromIndex to EndIndex - 1 do
  begin
    const Element = View.ReadElement(Index);
    Target.StoreConvertedValue(TargetPosition, Element);
    Inc(TargetPosition);
  end;
end;

function TJSTypedArrayMethods.Slice(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const StartIndex = TJSArrayLike.RelativeIndexArgument(Args, 0, ElementCount, 0);
  var EndIndex := TJSArrayLike.RelativeIndexArgument(Args, 1, ElementCount, ElementCount);
  const Count = Max(EndIndex - StartIndex, 0);

  const CountArguments: TArray<TJSValue> = [TJSValue.CreateNumber(Count)];
  const Target = FBuiltins.SpeciesCreate(View, CountArguments, SLICE_NAME);
  const HasElementsToCopy = (Count > 0);
  if HasElementsToCopy then
  begin
    TJSBuiltinSupport.RequireNotDetached(View.IsDetached, SLICE_NAME);

    EndIndex := Min(EndIndex, View.Length);
    CopyRange(View, Target, Integer(StartIndex), Integer(EndIndex));
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSTypedArrayMethods.Subarray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const View = FBuiltins.RequireTypedArray(This);
  const SourceLength = View.Length;
  const BeginIndex = TJSArrayLike.RelativeIndexArgument(Args, 0, SourceLength, 0);
  const EndIndex = TJSArrayLike.RelativeIndexArgument(Args, 1, SourceLength, SourceLength);
  const NewLength = Max(EndIndex - BeginIndex, 0);
  const BeginByteOffset = View.RetainedByteOffset + (BeginIndex * View.Kind.ElementSize);

  const BufferValue = TJSValue.CreateObject(View.Buffer);
  const OffsetValue = TJSValue.CreateNumber(BeginByteOffset);
  const LengthValue = TJSValue.CreateNumber(NewLength);
  const CreateArguments: TArray<TJSValue> = [BufferValue, OffsetValue, LengthValue];
  const Created = FBuiltins.SpeciesCreate(View, CreateArguments, SUBARRAY_NAME);
  Result := TJSValue.CreateObject(Created);
end;

function TJSTypedArrayMethods.AllocateSortValues(const ElementCount: Integer): TArray<Double>;
begin
  try
    SetLength(Result, ElementCount);
  except
    on EOutOfMemory do
      raise TJSErrorFactory.RangeError(SORT_ALLOCATION_FAILED);
  end;
end;

function TJSTypedArrayMethods.SortValues(const Values: TArray<Double>;
                                         const Comparer: TJSElementComparer): TArray<Double>;
begin
  try
    const Sorter = TJSDoubleMergeSorter.Create(Values, Comparer);
    try
      Result := Sorter.Sorted;
    finally
      Sorter.Free;
    end;
  except
    on EOutOfMemory do
      raise TJSErrorFactory.RangeError(SORT_ALLOCATION_FAILED);
  end;
end;

function TJSTypedArrayMethods.CreateComparer(const Comparer: IJSFunction): TJSElementComparer;
begin
  if not Assigned(Comparer) then
  begin
    Result := TJSDoubleMergeSorter.CompareDefault;
    Exit;
  end;

  const Undefined = TJSValue.CreateUndefined;
  const ThisArgument = FInterpreter.ThisObjectFor(Comparer, Undefined);
  Result :=
    function(const Left: Double; const Right: Double): Double
    begin
      const LeftValue = TJSValue.CreateNumber(Left);
      const RightValue = TJSValue.CreateNumber(Right);
      const Outcome = FInterpreter.CallFunction(Comparer, [LeftValue, RightValue], ThisArgument);
      const OutcomeNumber = Outcome.ToPrimitiveWithHint(TJSPrimitiveHint.Number);

      Result := OutcomeNumber.ToNumber;
      if IsNaN(Result) then
        Result := 0;
    end;
end;

function TJSTypedArrayMethods.Sort(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ComparerArgument = TJSArrayLike.Argument(Args, 0);
  var Comparer: IJSFunction := nil;
  const HasComparer = not ComparerArgument.IsUndefined;
  if HasComparer and (not ComparerArgument.TryGetFunction(Comparer)) then
    raise TJSErrorFactory.TypeError(COMPARER_NOT_CALLABLE);

  const View = FBuiltins.ValidateTypedArray(This, SORT_NAME);
  const ElementCount = View.Length;

  var Values := AllocateSortValues(ElementCount);

  const Bytes = View.Buffer.Bytes;
  const Size = View.Kind.ElementSize;
  for var Index := 0 to ElementCount - 1 do
  begin
    FInterpreter.ConsumeStep;
    Values[Index] := TJSElementCodec.Read(Bytes, View.ByteOffset + (Index * Size), View.Kind);
  end;

  const ElementComparer = CreateComparer(Comparer);
  Values := SortValues(Values, ElementComparer);

  for var Index := 0 to ElementCount - 1 do
  begin
    FInterpreter.ConsumeStep;

    const SortedValue = TJSValue.CreateNumber(Values[Index]);
    View.StoreConvertedValue(Index, SortedValue);
  end;

  Result := TJSValue.CreateObject(This);
end;

procedure TJSTypedArrayMethods.DefineIterationMethods;
begin
  DefineView(AT_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := At(View, Args);
    end);
  DefineScanMethods;

  DefineView(MAP_NAME, 1, MapElements);
  DefineView(FILTER_NAME, 1, FilterElements);

  DefineReduceMethods;
  DefineIteratorMethods;
end;

procedure TJSTypedArrayMethods.DefineScan(const Name: string; const Mode: TScanMode);
begin
  DefineView(Name, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, Mode, Name);
    end);
end;

procedure TJSTypedArrayMethods.DefineScanMethods;
begin
  DefineScan(EVERY_NAME, TScanMode.Every);
  DefineScan(SOME_NAME, TScanMode.Some);
  DefineScan(FOR_EACH_NAME, TScanMode.ForEach);
  DefineScan(FIND_NAME, TScanMode.Find);
  DefineScan(FIND_INDEX_NAME, TScanMode.FindIndex);
end;

procedure TJSTypedArrayMethods.DefineReduce(const Name: string; const FromEnd: Boolean);
begin
  DefineView(Name, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Reduce(This, View, Args, FromEnd, Name);
    end);
end;

procedure TJSTypedArrayMethods.DefineReduceMethods;
begin
  DefineReduce(REDUCE_NAME, False);
  DefineReduce(REDUCE_RIGHT_NAME, True);
end;

procedure TJSTypedArrayMethods.DefineIterator(const Name: string; const Kind: TJSArrayIteratorKind);
begin
  DefineView(Name, 0,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateIterator(This, Kind);
    end);
end;

procedure TJSTypedArrayMethods.DefineIteratorMethods;
begin
  DefineIterator(ENTRIES_NAME, TJSArrayIteratorKind.Entries);
  DefineIterator(KEYS_NAME, TJSArrayIteratorKind.Keys);

  const ValuesMethod = FSupport.CreateMethod(VALUES_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FBuiltins.ValidateTypedArray(This, VALUES_NAME);

      Result := CreateIterator(This, TJSArrayIteratorKind.Values);
    end);
  const ValuesValue = TJSValue.CreateObject(ValuesMethod);
  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  FSupport.DefineMember(FPrototype, VALUES_NAME, ValuesValue, True);
  FSupport.DefineMember(FPrototype, IteratorKey, ValuesValue, True);
end;

procedure TJSTypedArrayMethods.DefineSearch(const Name: string; const Mode: TSearchMode);
begin
  DefineView(Name, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Search(View, Args, Mode);
    end);
end;

procedure TJSTypedArrayMethods.DefineSearchMethods;
begin
  DefineSearch(INDEX_OF_NAME, TSearchMode.IndexOf);
  DefineSearch(LAST_INDEX_OF_NAME, TSearchMode.LastIndexOf);
  DefineSearch(INCLUDES_NAME, TSearchMode.Includes);
end;

procedure TJSTypedArrayMethods.DefineMutatingMethods;
begin
  DefineView(FILL_NAME, 1, Fill);
  DefineView(REVERSE_NAME, 0,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Reverse(This, View);
    end);
  DefineView(COPY_WITHIN_NAME, 2, CopyWithin);

  FSupport.DefineMethod(FPrototype, SORT_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Sort(This, Args);
    end);

  FSupport.DefineMethod(FPrototype, SET_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetElements(This, Args);
    end);
end;

procedure TJSTypedArrayMethods.DefineCopyingMethods;
begin
  DefineView(SLICE_NAME, 2,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Slice(View, Args);
    end);

  FSupport.DefineMethod(FPrototype, SUBARRAY_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Subarray(This, Args);
    end);
end;

procedure TJSTypedArrayMethods.DefineTextMethods;
begin
  DefineView(JOIN_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Join(View, Args);
    end);
  DefineView(TO_LOCALE_STRING_NAME, 0,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := JoinLocaleStrings(View);
    end);

  const ArrayToString = FInterpreter.ArrayPrototype.GetProperty(TO_STRING_NAME);
  FSupport.DefineMember(FPrototype, TO_STRING_NAME, ArrayToString, True);
end;

procedure TJSTypedArrayMethods.Register;
begin
  FPrototype := FBuiltins.IntrinsicPrototype;

  DefineGetters;
  DefineIterationMethods;
  DefineSearchMethods;
  DefineMutatingMethods;
  DefineCopyingMethods;
  DefineTextMethods;
end;

end.
