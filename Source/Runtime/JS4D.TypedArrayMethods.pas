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
  JS4D.BinarySupport,
  JS4D.ArrayIterator,
  JS4D.TypedArrayBuiltins;

type
  // The properties of %TypedArray%.prototype: the accessors and every method that works on the elements.
  TJSTypedArrayMethods = class
  private
    type
      TViewMethod = reference to function(const This: IJSObject; const View: IJSTypedArray;
                                          const Args: TArray<TJSValue>): TJSValue;
      TElementComparer = reference to function(const Left: Double; const Right: Double): Double;
      TScanMode = (Every, Some, ForEach, Find, FindIndex);
      TSearchMode = (IndexOf, LastIndexOf, Includes);

    const
      BUFFER_PROPERTY = 'buffer';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_OFFSET_PROPERTY = 'byteOffset';
      LENGTH_PROPERTY = 'length';
      GETTER_PREFIX = 'get ';
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
      DETACHED_TYPED_ARRAY = 'Cannot perform %s on a detached ArrayBuffer';

    var
      FBuiltins: TJSTypedArrayBuiltins;
      FSupport: TJSBinarySupport;
      FInterpreter: TJSInterpreter;
      FPrototype: IJSObject;

    class function SameValueZero(const Left: TJSValue; const Right: TJSValue): Boolean; static;
    class function CompareDefault(const Left: Double; const Right: Double): Double; static;
    class function IsNegativeZero(const Value: Double): Boolean; static;
    class function NotFound(const Mode: TSearchMode): TJSValue; static;
    class function FirstIndex(const Offset: Double; const Count: Int64): Int64; static;

    procedure DefineView(const Name: string; const ParameterCount: Integer; const Method: TViewMethod);
    procedure DefineGetters;
    procedure DefineIterationMethods;
    procedure DefineSearchMethods;
    procedure DefineMutatingMethods;
    procedure DefineCopyingMethods;
    procedure DefineTextMethods;
    function RequireCallback(const Value: TJSValue; const MethodName: string): IJSFunction;
    function CreateIterator(const This: IJSObject; const Kind: TJSArrayIteratorKind): TJSValue;
    function At(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
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
    function Subarray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Sort(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    procedure MergeSort(const Values: TArray<Double>; const Scratch: TArray<Double>; const LowIndex: Integer;
                        const HighIndex: Integer; const Compare: TElementComparer);
    procedure MergeRuns(const Values: TArray<Double>; const Scratch: TArray<Double>; const LowIndex: Integer;
                        const MiddleIndex: Integer; const HighIndex: Integer; const Compare: TElementComparer);
    function CreateComparer(const Comparer: IJSFunction): TElementComparer;

  public
    constructor Create(const Builtins: TJSTypedArrayBuiltins);

    procedure Register;
  end;

implementation

uses
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

class function TJSTypedArrayMethods.SameValueZero(const Left: TJSValue; const Right: TJSValue): Boolean;
begin
  const AreNumbers = Left.IsNumber and Right.IsNumber;
  if AreNumbers then
    Exit((Left.AsNumber = Right.AsNumber) or (IsNaN(Left.AsNumber) and IsNaN(Right.AsNumber)));

  Result := Left.StrictEquals(Right);
end;

class function TJSTypedArrayMethods.IsNegativeZero(const Value: Double): Boolean;
begin
  Result := (Value = 0) and (PInt64(@Value)^ < 0);
end;

class function TJSTypedArrayMethods.CompareDefault(const Left: Double; const Right: Double): Double;
begin
  const LeftIsNaN = IsNaN(Left);
  const RightIsNaN = IsNaN(Right);
  if LeftIsNaN or RightIsNaN then
  begin
    if LeftIsNaN and RightIsNaN then
      Exit(0);

    if LeftIsNaN then
      Exit(1);

    Exit(-1);
  end;

  if Left < Right then
    Exit(-1);

  if Left > Right then
    Exit(1);

  const OnlyLeftNegative = IsNegativeZero(Left) and (not IsNegativeZero(Right));
  const OnlyRightNegative = IsNegativeZero(Right) and (not IsNegativeZero(Left));
  if OnlyLeftNegative then
    Exit(-1);

  if OnlyRightNegative then
    Exit(1);

  Result := 0;
end;

class function TJSTypedArrayMethods.NotFound(const Mode: TSearchMode): TJSValue;
begin
  if Mode = TSearchMode.Includes then
    Exit(TJSValue.CreateBoolean(False));

  Result := TJSValue.CreateNumber(-1);
end;

class function TJSTypedArrayMethods.FirstIndex(const Offset: Double; const Count: Int64): Int64;
begin
  if Offset >= 0 then
    Exit(Trunc(Min(Offset, Count)));

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
  if not TJSBinarySupport.AsFunction(Value, Result) then
    raise TJSErrorFactory.TypeError(Format(CALLBACK_NOT_CALLABLE, [MethodName]));
end;

procedure TJSTypedArrayMethods.DefineGetters;
begin
  FSupport.DefineGetter(FPrototype, BUFFER_PROPERTY, GETTER_PREFIX + BUFFER_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateObject(FBuiltins.RequireTypedArray(This, BUFFER_PROPERTY).Buffer);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_LENGTH_PROPERTY, GETTER_PREFIX + BYTE_LENGTH_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = FBuiltins.RequireTypedArray(This, BYTE_LENGTH_PROPERTY);

      Result := TJSValue.CreateNumber(View.Length * View.Kind.ElementSize);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_OFFSET_PROPERTY, GETTER_PREFIX + BYTE_OFFSET_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateNumber(FBuiltins.RequireTypedArray(This, BYTE_OFFSET_PROPERTY).ByteOffset);
    end);

  FSupport.DefineGetter(FPrototype, LENGTH_PROPERTY, GETTER_PREFIX + LENGTH_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateNumber(FBuiltins.RequireTypedArray(This, LENGTH_PROPERTY).Length);
    end);

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

function TJSTypedArrayMethods.At(const This: IJSObject; const View: IJSTypedArray;
                                 const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Relative = TJSBinarySupport.ToIntegerOrInfinity(TJSBinarySupport.Argument(Args, 0));

  var Position := Relative;
  if Relative < 0 then
    Position := ElementCount + Relative;

  const IsOutside = (Position < 0) or (Position >= ElementCount);
  if IsOutside then
    Exit(TJSValue.CreateUndefined);

  Result := View.ReadElement(Trunc(Position));
end;

function TJSTypedArrayMethods.Scan(const This: IJSObject; const View: IJSTypedArray;
                                   const Args: TArray<TJSValue>; const Mode: TScanMode;
                                   const MethodName: string): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = RequireCallback(TJSBinarySupport.Argument(Args, 0), MethodName);
  const ThisArgument = FInterpreter.ThisObjectFor(Callback, TJSBinarySupport.Argument(Args, 1));
  const Subject = TJSValue.CreateObject(This);

  for var Index := 0 to ElementCount - 1 do
  begin
    const Element = View.ReadElement(Index);
    const Outcome = FInterpreter.CallFunction(Callback, [Element, TJSValue.CreateNumber(Index), Subject],
                                              ThisArgument).ToBoolean;
    case Mode of
      TScanMode.Every     : if not Outcome then Exit(TJSValue.CreateBoolean(False));
      TScanMode.Some      : if Outcome then Exit(TJSValue.CreateBoolean(True));
      TScanMode.ForEach   : ;
      TScanMode.Find      : if Outcome then Exit(Element);
      TScanMode.FindIndex : if Outcome then Exit(TJSValue.CreateNumber(Index));
    else
      raise ENotSupportedException.CreateFmt('Unsupported scan mode: %d', [Ord(Mode)]);
    end;
  end;

  case Mode of
    TScanMode.Every     : Result := TJSValue.CreateBoolean(True);
    TScanMode.Some      : Result := TJSValue.CreateBoolean(False);
    TScanMode.FindIndex : Result := TJSValue.CreateNumber(-1);
  else
    Result := TJSValue.CreateUndefined;
  end;
end;

function TJSTypedArrayMethods.MapElements(const This: IJSObject; const View: IJSTypedArray;
                                          const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = RequireCallback(TJSBinarySupport.Argument(Args, 0), MAP_NAME);
  const ThisArgument = FInterpreter.ThisObjectFor(Callback, TJSBinarySupport.Argument(Args, 1));
  const Subject = TJSValue.CreateObject(This);

  const Target = FBuiltins.SpeciesCreate(View, [TJSValue.CreateNumber(ElementCount)], MAP_NAME);
  for var Index := 0 to ElementCount - 1 do
  begin
    const Element = View.ReadElement(Index);
    const Mapped = FInterpreter.CallFunction(Callback, [Element, TJSValue.CreateNumber(Index), Subject],
                                             ThisArgument);
    Target.StoreValue(Index, Mapped);
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSTypedArrayMethods.FilterElements(const This: IJSObject; const View: IJSTypedArray;
                                             const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = RequireCallback(TJSBinarySupport.Argument(Args, 0), FILTER_NAME);
  const ThisArgument = FInterpreter.ThisObjectFor(Callback, TJSBinarySupport.Argument(Args, 1));
  const Subject = TJSValue.CreateObject(This);

  const Kept = TList<TJSValue>.Create;
  try
    for var Index := 0 to ElementCount - 1 do
    begin
      const Element = View.ReadElement(Index);
      const IsSelected = FInterpreter.CallFunction(Callback, [Element, TJSValue.CreateNumber(Index), Subject],
                                                   ThisArgument).ToBoolean;
      if IsSelected then
        Kept.Add(Element);
    end;

    const Target = FBuiltins.SpeciesCreate(View, [TJSValue.CreateNumber(Kept.Count)], FILTER_NAME);
    for var Position := 0 to Kept.Count - 1 do
    begin
      Target.StoreValue(Position, Kept[Position]);
    end;

    Result := TJSValue.CreateObject(Target);
  finally
    Kept.Free;
  end;
end;

function TJSTypedArrayMethods.Reduce(const This: IJSObject; const View: IJSTypedArray;
                                     const Args: TArray<TJSValue>; const FromEnd: Boolean;
                                     const MethodName: string): TJSValue;
begin
  const ElementCount = View.Length;
  const Callback = RequireCallback(TJSBinarySupport.Argument(Args, 0), MethodName);

  const HasInitialValue = Length(Args) >= 2;
  if (ElementCount = 0) and (not HasInitialValue) then
    raise TJSErrorFactory.TypeError(REDUCE_EMPTY);

  var Step := 1;
  var Index := 0;
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
    Accumulator := View.ReadElement(Index);
    Inc(Index, Step);
  end;

  const Subject = TJSValue.CreateObject(This);
  const ThisArgument = FInterpreter.ThisObjectFor(Callback, TJSValue.CreateUndefined);
  while (Index >= 0) and (Index < ElementCount) do
  begin
    const Element = View.ReadElement(Index);
    Accumulator := FInterpreter.CallFunction(Callback, [Accumulator, Element, TJSValue.CreateNumber(Index), Subject],
                                             ThisArgument);
    Inc(Index, Step);
  end;

  Result := Accumulator;
end;

function TJSTypedArrayMethods.SearchForward(const View: IJSTypedArray; const Args: TArray<TJSValue>;
                                            const Mode: TSearchMode): TJSValue;
begin
  const ElementCount = View.Length;
  if ElementCount = 0 then
    Exit(NotFound(Mode));

  const Target = TJSBinarySupport.Argument(Args, 0);
  const Offset = TJSBinarySupport.ToIntegerOrInfinity(TJSBinarySupport.Argument(Args, 1));
  if Offset = Infinity then
    Exit(NotFound(Mode));

  const IsIncludes = (Mode = TSearchMode.Includes);
  for var Index := FirstIndex(Offset, ElementCount) to ElementCount - 1 do
  begin
    const IsPresent = Index < View.Length;
    const Element = View.ReadElement(Integer(Index));

    if IsIncludes and SameValueZero(Element, Target) then
      Exit(TJSValue.CreateBoolean(True));

    if (not IsIncludes) and IsPresent and Element.StrictEquals(Target) then
      Exit(TJSValue.CreateNumber(Index));
  end;

  Result := NotFound(Mode);
end;

function TJSTypedArrayMethods.SearchBackward(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const NotFound = TJSValue.CreateNumber(-1);
  if ElementCount = 0 then
    Exit(NotFound);

  const Target = TJSBinarySupport.Argument(Args, 0);
  var Offset: Double := ElementCount - 1;
  if Length(Args) > 1 then
    Offset := TJSBinarySupport.ToIntegerOrInfinity(Args[1]);

  if Offset = NegInfinity then
    Exit(NotFound);

  var Index: Int64;
  if Offset >= 0 then
    Index := Trunc(Min(Offset, ElementCount - 1))
  else
    Index := Trunc(ElementCount + Offset);

  while Index >= 0 do
  begin
    const IsPresent = Index < View.Length;
    if IsPresent and View.ReadElement(Integer(Index)).StrictEquals(Target) then
      Exit(TJSValue.CreateNumber(Index));

    Dec(Index);
  end;

  Result := NotFound;
end;

function TJSTypedArrayMethods.Search(const View: IJSTypedArray; const Args: TArray<TJSValue>;
                                     const Mode: TSearchMode): TJSValue;
begin
  if Mode = TSearchMode.LastIndexOf then
    Result := SearchBackward(View, Args)
  else
    Result := SearchForward(View, Args, Mode);
end;

function TJSTypedArrayMethods.Join(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const SeparatorArgument = TJSBinarySupport.Argument(Args, 0);

  var Separator: string := ',';
  if not SeparatorArgument.IsUndefined then
    Separator := SeparatorArgument.ToPrimitiveWithHint(TJSPrimitiveHint.String_).ToLimitedString(FInterpreter.Limits);

  const Builder = TStringBuilder.Create;
  try
    for var Index := 0 to ElementCount - 1 do
    begin
      if Index > 0 then
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
      if Index > 0 then
        Builder.Append(',');

      const Element = View.ReadElement(Index);
      if Element.IsNullOrUndefined then
        Continue;

      const Wrapper = FSupport.ToObject(Element);
      var Method: IJSFunction;
      if not TJSBinarySupport.AsFunction(Wrapper.GetProperty(TO_LOCALE_STRING_NAME), Method) then
        raise TJSErrorFactory.TypeError(LOCALE_METHOD_MISSING);

      const Text = FInterpreter.CallFunction(Method, nil, Wrapper);
      Builder.Append(Text.ToPrimitiveWithHint(TJSPrimitiveHint.String_).ToLimitedString(FInterpreter.Limits));
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
  const Number = TJSBinarySupport.Argument(Args, 0).ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
  const StartIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 1), ElementCount, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 2), ElementCount, ElementCount);

  if View.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [FILL_NAME]));

  const FillValue = TJSValue.CreateNumber(Number);
  for var Index := StartIndex to Min(EndIndex, View.Length) - 1 do
  begin
    View.StoreValue(Integer(Index), FillValue);
  end;

  Result := TJSValue.CreateObject(This);
end;

function TJSTypedArrayMethods.Reverse(const This: IJSObject; const View: IJSTypedArray): TJSValue;
begin
  const ElementCount = View.Length;
  const Size = View.Kind.ElementSize;
  const Bytes = View.Buffer.Bytes;

  var Scratch: array[0..7] of Byte;
  var LowerIndex := 0;
  var UpperIndex := ElementCount - 1;
  while LowerIndex < UpperIndex do
  begin
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
  const TargetIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 0), ElementCount, 0);
  const StartIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 1), ElementCount, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 2), ElementCount, ElementCount);
  var Count := Min(EndIndex - StartIndex, ElementCount - TargetIndex);

  if Count > 0 then
  begin
    if View.IsDetached then
      raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [COPY_WITHIN_NAME]));

    const Size = View.Kind.ElementSize;
    const Bytes = View.Buffer.Bytes;
    Move(Bytes[View.ByteOffset + Integer(StartIndex * Size)], Bytes[View.ByteOffset + Integer(TargetIndex * Size)],
         Integer(Count * Size));
  end;

  Result := TJSValue.CreateObject(This);
end;

procedure TJSTypedArrayMethods.SetFromTypedArray(const Target: IJSTypedArray; const Offset: Double;
                                                 const Source: IJSTypedArray);
begin
  if Target.IsDetached or Source.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [SET_NAME]));

  const SourceLength = Source.Length;
  if (Offset = Infinity) or ((SourceLength + Offset) > Target.Length) then
    raise TJSErrorFactory.RangeError(SOURCE_TOO_LONG);

  const TargetBytes = Target.Buffer.Bytes;
  const SourceKind = Source.Kind;
  const TargetKind = Target.Kind;
  const TargetStart = Target.ByteOffset + (Trunc(Offset) * TargetKind.ElementSize);
  const SourceSize = SourceKind.ElementSize;

  var SourceBytes := Source.Buffer.Bytes;
  var SourceStart := Source.ByteOffset;
  const IsSameBuffer = (Source.Buffer as IInterface) = (Target.Buffer as IInterface);
  if IsSameBuffer then
  begin
    SourceBytes := Copy(SourceBytes, SourceStart, SourceLength * SourceSize);
    SourceStart := 0;
  end;

  if SourceKind = TargetKind then
  begin
    if SourceLength > 0 then
      Move(SourceBytes[SourceStart], TargetBytes[TargetStart], SourceLength * SourceSize);

    Exit;
  end;

  for var Index := 0 to SourceLength - 1 do
  begin
    const Number = TJSElementCodec.Read(SourceBytes, SourceStart + (Index * SourceSize), SourceKind);
    TJSElementCodec.Write(TargetBytes, TargetStart + (Index * TargetKind.ElementSize), TargetKind, Number);
  end;
end;

procedure TJSTypedArrayMethods.SetFromArrayLike(const Target: IJSTypedArray; const Offset: Double;
                                                const Source: TJSValue);
begin
  if Target.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [SET_NAME]));

  const TargetLength = Target.Length;
  const SourceObject = FSupport.ToObject(Source);
  const SourceLength = TJSArrayLike.ToLength(SourceObject);
  if (Offset = Infinity) or ((SourceLength + Offset) > TargetLength) then
    raise TJSErrorFactory.RangeError(SOURCE_TOO_LONG);

  const TargetStart = Trunc(Offset);
  for var Index := 0 to SourceLength - 1 do
  begin
    const Element = SourceObject.GetProperty(TJSArrayLike.IndexName(Index));
    Target.StoreValue(Integer(TargetStart + Index), Element);
  end;
end;

function TJSTypedArrayMethods.SetElements(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = FBuiltins.RequireTypedArray(This, SET_NAME);
  const Offset = TJSBinarySupport.ToIntegerOrInfinity(TJSBinarySupport.Argument(Args, 1));
  if Offset < 0 then
    raise TJSErrorFactory.RangeError(NEGATIVE_OFFSET);

  const Source = TJSBinarySupport.Argument(Args, 0);
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
  const Size = View.Kind.ElementSize;
  if View.Kind = Target.Kind then
  begin
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

    Exit;
  end;

  var TargetIndex := 0;
  for var Index := FromIndex to EndIndex - 1 do
  begin
    Target.StoreValue(TargetIndex, View.ReadElement(Index));
    Inc(TargetIndex);
  end;
end;

function TJSTypedArrayMethods.Slice(const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue;
begin
  const ElementCount = View.Length;
  const StartIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 0), ElementCount, 0);
  var EndIndex := TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 1), ElementCount, ElementCount);
  var Count := Max(EndIndex - StartIndex, 0);

  const Target = FBuiltins.SpeciesCreate(View, [TJSValue.CreateNumber(Count)], SLICE_NAME);
  if Count > 0 then
  begin
    if View.IsDetached then
      raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [SLICE_NAME]));

    EndIndex := Min(EndIndex, View.Length);
    CopyRange(View, Target, Integer(StartIndex), Integer(EndIndex));
  end;

  Result := TJSValue.CreateObject(Target);
end;

function TJSTypedArrayMethods.Subarray(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const View = FBuiltins.RequireTypedArray(This, SUBARRAY_NAME);
  const SourceLength = View.Length;
  const BeginIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 0), SourceLength, 0);
  const EndIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 1), SourceLength, SourceLength);
  const NewLength = Max(EndIndex - BeginIndex, 0);
  const BeginByteOffset = View.ViewOffset + (BeginIndex * View.Kind.ElementSize);

  const Created = FBuiltins.SpeciesCreate(View, [TJSValue.CreateObject(View.Buffer),
                                                 TJSValue.CreateNumber(BeginByteOffset),
                                                 TJSValue.CreateNumber(NewLength)], SUBARRAY_NAME);
  Result := TJSValue.CreateObject(Created);
end;

function TJSTypedArrayMethods.CreateComparer(const Comparer: IJSFunction): TElementComparer;
begin
  if not Assigned(Comparer) then
  begin
    Result :=
      function(const Left: Double; const Right: Double): Double
      begin
        Result := CompareDefault(Left, Right);
      end;
    Exit;
  end;

  const ThisArgument = FInterpreter.ThisObjectFor(Comparer, TJSValue.CreateUndefined);
  Result :=
    function(const Left: Double; const Right: Double): Double
    begin
      const Outcome = FInterpreter.CallFunction(Comparer, [TJSValue.CreateNumber(Left), TJSValue.CreateNumber(Right)],
                                                ThisArgument);
      Result := Outcome.ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
      if IsNaN(Result) then
        Result := 0;
    end;
end;

procedure TJSTypedArrayMethods.MergeRuns(const Values: TArray<Double>; const Scratch: TArray<Double>;
                                         const LowIndex: Integer; const MiddleIndex: Integer;
                                         const HighIndex: Integer; const Compare: TElementComparer);
begin
  var LeftIndex := LowIndex;
  var RightIndex := MiddleIndex;
  for var Position := LowIndex to HighIndex - 1 do
  begin
    const TakesLeft = (RightIndex >= HighIndex) or
                      ((LeftIndex < MiddleIndex) and (Compare(Values[LeftIndex], Values[RightIndex]) <= 0));
    if TakesLeft then
    begin
      Scratch[Position] := Values[LeftIndex];
      Inc(LeftIndex);
    end
    else
    begin
      Scratch[Position] := Values[RightIndex];
      Inc(RightIndex);
    end;
  end;

  for var Position := LowIndex to HighIndex - 1 do
  begin
    Values[Position] := Scratch[Position];
  end;
end;

procedure TJSTypedArrayMethods.MergeSort(const Values: TArray<Double>; const Scratch: TArray<Double>;
                                         const LowIndex: Integer; const HighIndex: Integer;
                                         const Compare: TElementComparer);
begin
  if (HighIndex - LowIndex) < 2 then
    Exit;

  const MiddleIndex = LowIndex + ((HighIndex - LowIndex) div 2);
  MergeSort(Values, Scratch, LowIndex, MiddleIndex, Compare);
  MergeSort(Values, Scratch, MiddleIndex, HighIndex, Compare);
  MergeRuns(Values, Scratch, LowIndex, MiddleIndex, HighIndex, Compare);
end;

function TJSTypedArrayMethods.Sort(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const ComparerArgument = TJSBinarySupport.Argument(Args, 0);
  var Comparer: IJSFunction := nil;
  const HasComparer = not ComparerArgument.IsUndefined;
  if HasComparer and (not TJSBinarySupport.AsFunction(ComparerArgument, Comparer)) then
    raise TJSErrorFactory.TypeError(COMPARER_NOT_CALLABLE);

  const View = FBuiltins.ValidateTypedArray(This, SORT_NAME);
  const ElementCount = View.Length;

  var Values: TArray<Double>;
  var Scratch: TArray<Double>;
  SetLength(Values, ElementCount);
  SetLength(Scratch, ElementCount);

  const Bytes = View.Buffer.Bytes;
  const Size = View.Kind.ElementSize;
  for var Index := 0 to ElementCount - 1 do
  begin
    Values[Index] := TJSElementCodec.Read(Bytes, View.ByteOffset + (Index * Size), View.Kind);
  end;

  MergeSort(Values, Scratch, 0, ElementCount, CreateComparer(Comparer));

  for var Index := 0 to ElementCount - 1 do
  begin
    View.StoreValue(Index, TJSValue.CreateNumber(Values[Index]));
  end;

  Result := TJSValue.CreateObject(This);
end;

procedure TJSTypedArrayMethods.DefineIterationMethods;
begin
  DefineView(AT_NAME, 1, At);

  DefineView(EVERY_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, TScanMode.Every, EVERY_NAME);
    end);
  DefineView(SOME_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, TScanMode.Some, SOME_NAME);
    end);
  DefineView(FOR_EACH_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, TScanMode.ForEach, FOR_EACH_NAME);
    end);
  DefineView(FIND_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, TScanMode.Find, FIND_NAME);
    end);
  DefineView(FIND_INDEX_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Scan(This, View, Args, TScanMode.FindIndex, FIND_INDEX_NAME);
    end);

  DefineView(MAP_NAME, 1, MapElements);
  DefineView(FILTER_NAME, 1, FilterElements);

  DefineView(REDUCE_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Reduce(This, View, Args, False, REDUCE_NAME);
    end);
  DefineView(REDUCE_RIGHT_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Reduce(This, View, Args, True, REDUCE_RIGHT_NAME);
    end);

  DefineView(ENTRIES_NAME, 0,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateIterator(This, TJSArrayIteratorKind.Entries);
    end);
  DefineView(KEYS_NAME, 0,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateIterator(This, TJSArrayIteratorKind.Keys);
    end);

  const ValuesMethod = FSupport.CreateMethod(VALUES_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FBuiltins.ValidateTypedArray(This, VALUES_NAME);

      Result := CreateIterator(This, TJSArrayIteratorKind.Values);
    end);
  FSupport.DefineMember(FPrototype, VALUES_NAME, TJSValue.CreateObject(ValuesMethod), True);

  const IteratorKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);
  FSupport.DefineMember(FPrototype, IteratorKey, TJSValue.CreateObject(ValuesMethod), True);
end;

procedure TJSTypedArrayMethods.DefineSearchMethods;
begin
  DefineView(INDEX_OF_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Search(View, Args, TSearchMode.IndexOf);
    end);
  DefineView(LAST_INDEX_OF_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Search(View, Args, TSearchMode.LastIndexOf);
    end);
  DefineView(INCLUDES_NAME, 1,
    function(const This: IJSObject; const View: IJSTypedArray; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Search(View, Args, TSearchMode.Includes);
    end);
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
