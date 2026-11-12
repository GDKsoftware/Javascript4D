unit JS4D.TypedArrayBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.BinarySupport,
  JS4D.ArrayBufferBuiltins;

type
  // The %TypedArray% intrinsic, the nine concrete typed array constructors and the ways to create a typed
  // array that the prototype methods share. The prototype methods are in TJSTypedArrayMethods.
  TJSTypedArrayBuiltins = class
  private
    const
      ABSTRACT_NAME = 'TypedArray';
      FROM_NAME = 'from';
      OF_NAME = 'of';
      BYTES_PER_ELEMENT = 'BYTES_PER_ELEMENT';
      ABSTRACT_CONSTRUCTOR = 'Abstract class TypedArray not directly constructable';
      REQUIRES_NEW = 'Constructor %s requires ''new''';
      NOT_A_TYPED_ARRAY = 'The value is not a typed array';
      DETACHED_TYPED_ARRAY = 'Cannot perform %s on a detached ArrayBuffer';
      TYPED_ARRAY_TOO_SHORT = 'The typed array that was created is too short';
      NOT_A_CONSTRUCTOR = 'The value is not a constructor';
      NOT_A_FUNCTION = 'The mapping function is not callable';
      OFFSET_NOT_ALIGNED = 'Start offset of %s should be a multiple of %d';
      LENGTH_NOT_ALIGNED = 'Byte length of %s should be a multiple of %d';
      OFFSET_OUT_OF_BOUNDS = 'Start offset %d is outside the bounds of the buffer';
      LENGTH_OUT_OF_BOUNDS = 'Invalid typed array length: %d';
      ALL_KINDS: array[0..8] of TJSElementKind = (TJSElementKind.Int8, TJSElementKind.Uint8,
                                                  TJSElementKind.Uint8Clamped, TJSElementKind.Int16,
                                                  TJSElementKind.Uint16, TJSElementKind.Int32,
                                                  TJSElementKind.Uint32, TJSElementKind.Float32,
                                                  TJSElementKind.Float64);

    var
      FSupport: TJSBinarySupport;
      FBuffers: TJSArrayBufferBuiltins;
      FIntrinsicConstructor: IJSFunction;
      FIntrinsicPrototype: IJSObject;
      FConstructors: array[TJSElementKind] of IJSFunction;
      FPrototypes: array[TJSElementKind] of IJSObject;

    function CreateIntrinsicConstructor: IJSFunction;
    function CreateConcreteConstructor(const Kind: TJSElementKind): IJSFunction;
    procedure RegisterConcrete(const Kind: TJSElementKind);
    function Construct(const Kind: TJSElementKind; const Args: TArray<TJSValue>;
                       const NewTarget: IJSFunction): TJSValue;
    function CreateFromTypedArray(const Kind: TJSElementKind; const Source: IJSTypedArray;
                                  const Prototype: IJSObject): IJSTypedArray;
    function CreateFromBuffer(const Kind: TJSElementKind; const Buffer: IJSArrayBuffer;
                              const Args: TArray<TJSValue>; const Prototype: IJSObject): IJSTypedArray;
    function CreateFromObject(const Kind: TJSElementKind; const Source: IJSObject;
                              const Prototype: IJSObject): IJSTypedArray;
    function CreateFromList(const Kind: TJSElementKind; const Items: TList<TJSValue>;
                            const Prototype: IJSObject): IJSTypedArray;
    function CreateFromArrayLike(const Kind: TJSElementKind; const Source: IJSObject;
                                 const Prototype: IJSObject): IJSTypedArray;
    function ReadIterable(const Source: TJSValue; const Items: TList<TJSValue>): Boolean;
    function FromStatic(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function OfStatic(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function RequireConstructor(const This: IJSObject): IJSFunction;
    procedure DefineStatics;

  public
    constructor Create(const Support: TJSBinarySupport; const Buffers: TJSArrayBufferBuiltins);
    destructor Destroy; override;

    procedure Register;
    function Allocate(const Kind: TJSElementKind; const ElementCount: Int64;
                      const Prototype: IJSObject): IJSTypedArray;
    function CreateOfKind(const Kind: TJSElementKind; const ElementCount: Int64): IJSTypedArray;
    function RequireTypedArray(const This: IJSObject; const MethodName: string): IJSTypedArray;
    function ValidateTypedArray(const Value: IJSObject; const MethodName: string): IJSTypedArray;
    function CreateFromConstructor(const Constructor_: IJSFunction; const Args: TArray<TJSValue>;
                                   const MethodName: string): IJSTypedArray;
    function SpeciesCreate(const Exemplar: IJSTypedArray; const Args: TArray<TJSValue>;
                           const MethodName: string): IJSTypedArray;

    property IntrinsicPrototype: IJSObject read FIntrinsicPrototype;
    property Support: TJSBinarySupport read FSupport;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayStatics,
  JS4D.ArrayLike;

constructor TJSTypedArrayBuiltins.Create(const Support: TJSBinarySupport; const Buffers: TJSArrayBufferBuiltins);
begin
  inherited Create;

  FSupport := Support;
  FBuffers := Buffers;
end;

destructor TJSTypedArrayBuiltins.Destroy;
begin
  for var Kind in ALL_KINDS do
  begin
    FConstructors[Kind] := nil;
    FPrototypes[Kind] := nil;
  end;

  FIntrinsicConstructor := nil;
  FIntrinsicPrototype := nil;
  inherited;
end;

function TJSTypedArrayBuiltins.Allocate(const Kind: TJSElementKind; const ElementCount: Int64;
                                        const Prototype: IJSObject): IJSTypedArray;
begin
  const ByteLength = ElementCount * Kind.ElementSize;
  const Buffer = FBuffers.CreateBuffer(ByteLength);

  const TypedArray = TJSTypedArrayObject.Create(Kind, Buffer, 0, Integer(ElementCount));
  TypedArray.Prototype := Prototype;

  Result := TypedArray;
end;

function TJSTypedArrayBuiltins.CreateOfKind(const Kind: TJSElementKind; const ElementCount: Int64): IJSTypedArray;
begin
  Result := Allocate(Kind, ElementCount, FPrototypes[Kind]);
end;

function TJSTypedArrayBuiltins.RequireTypedArray(const This: IJSObject; const MethodName: string): IJSTypedArray;
begin
  if not Supports(This, IJSTypedArray, Result) then
    raise TJSErrorFactory.TypeError(NOT_A_TYPED_ARRAY);
end;

function TJSTypedArrayBuiltins.ValidateTypedArray(const Value: IJSObject; const MethodName: string): IJSTypedArray;
begin
  Result := RequireTypedArray(Value, MethodName);

  if Result.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [MethodName]));
end;

function TJSTypedArrayBuiltins.CreateFromConstructor(const Constructor_: IJSFunction; const Args: TArray<TJSValue>;
                                                     const MethodName: string): IJSTypedArray;
begin
  const Created = FSupport.Interpreter.Construct(Constructor_, Args);
  if not Created.IsObject then
    raise TJSErrorFactory.TypeError(NOT_A_TYPED_ARRAY);

  Result := ValidateTypedArray(Created.ToObject, MethodName);

  const IsLengthRequest = (Length(Args) = 1) and Args[0].IsNumber;
  if IsLengthRequest and (Result.Length < Args[0].AsNumber) then
    raise TJSErrorFactory.TypeError(TYPED_ARRAY_TOO_SHORT);
end;

function TJSTypedArrayBuiltins.SpeciesCreate(const Exemplar: IJSTypedArray; const Args: TArray<TJSValue>;
                                             const MethodName: string): IJSTypedArray;
begin
  const ExemplarObject: IJSObject = Exemplar;
  const Species = FSupport.SpeciesConstructor(ExemplarObject, FConstructors[Exemplar.Kind]);

  Result := CreateFromConstructor(Species, Args, MethodName);
end;

function TJSTypedArrayBuiltins.RequireConstructor(const This: IJSObject): IJSFunction;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);

  if not TJSBinarySupport.AsConstructor(TJSValue.CreateObject(This), Result) then
    raise TJSErrorFactory.TypeError(NOT_A_CONSTRUCTOR);
end;

function TJSTypedArrayBuiltins.CreateFromTypedArray(const Kind: TJSElementKind; const Source: IJSTypedArray;
                                                    const Prototype: IJSObject): IJSTypedArray;
begin
  if Source.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [Kind.ConstructorName]));

  const ElementCount = Source.Length;
  Result := Allocate(Kind, ElementCount, Prototype);

  const SourceBytes = Source.Buffer.Bytes;
  const TargetBytes = Result.Buffer.Bytes;
  const SourceKind = Source.Kind;
  const SourceSize = SourceKind.ElementSize;
  const TargetSize = Kind.ElementSize;

  if SourceKind = Kind then
  begin
    if ElementCount > 0 then
      Move(SourceBytes[Source.ByteOffset], TargetBytes[0], ElementCount * TargetSize);

    Exit;
  end;

  for var Index := 0 to ElementCount - 1 do
  begin
    const Number = TJSElementCodec.Read(SourceBytes, Source.ByteOffset + (Index * SourceSize), SourceKind);
    TJSElementCodec.Write(TargetBytes, Index * TargetSize, Kind, Number);
  end;
end;

function TJSTypedArrayBuiltins.CreateFromBuffer(const Kind: TJSElementKind; const Buffer: IJSArrayBuffer;
                                                const Args: TArray<TJSValue>;
                                                const Prototype: IJSObject): IJSTypedArray;
begin
  const Size = Kind.ElementSize;
  const Offset = TJSBinarySupport.ToIndex(TJSBinarySupport.Argument(Args, 1));
  if (Offset mod Size) <> 0 then
    raise TJSErrorFactory.RangeError(Format(OFFSET_NOT_ALIGNED, [Kind.ConstructorName, Size]));

  const LengthArgument = TJSBinarySupport.Argument(Args, 2);
  var NewLength: Int64 := 0;
  if not LengthArgument.IsUndefined then
    NewLength := TJSBinarySupport.ToIndex(LengthArgument);

  if Buffer.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_TYPED_ARRAY, [Kind.ConstructorName]));

  const BufferLength = Int64(Buffer.ByteLength);
  if LengthArgument.IsUndefined then
  begin
    if (BufferLength mod Size) <> 0 then
      raise TJSErrorFactory.RangeError(Format(LENGTH_NOT_ALIGNED, [Kind.ConstructorName, Size]));

    if Offset > BufferLength then
      raise TJSErrorFactory.RangeError(Format(OFFSET_OUT_OF_BOUNDS, [Offset]));

    NewLength := (BufferLength - Offset) div Size;
  end
  else if (Offset + (NewLength * Size)) > BufferLength then
  begin
    raise TJSErrorFactory.RangeError(Format(LENGTH_OUT_OF_BOUNDS, [NewLength]));
  end;

  const TypedArray = TJSTypedArrayObject.Create(Kind, Buffer, Integer(Offset), Integer(NewLength));
  TypedArray.Prototype := Prototype;

  Result := TypedArray;
end;

function TJSTypedArrayBuiltins.ReadIterable(const Source: TJSValue; const Items: TList<TJSValue>): Boolean;
begin
  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  Result := FSupport.Interpreter.OpenSequenceReader(Source, Reader, Closer);
  if not Result then
    Exit;

  var Item: TJSValue;
  while Reader(Item) do
  begin
    Items.Add(Item);
  end;
end;

function TJSTypedArrayBuiltins.CreateFromList(const Kind: TJSElementKind; const Items: TList<TJSValue>;
                                              const Prototype: IJSObject): IJSTypedArray;
begin
  Result := Allocate(Kind, Items.Count, Prototype);

  for var Index := 0 to Items.Count - 1 do
  begin
    Result.StoreValue(Index, Items[Index]);
  end;
end;

function TJSTypedArrayBuiltins.CreateFromArrayLike(const Kind: TJSElementKind; const Source: IJSObject;
                                                   const Prototype: IJSObject): IJSTypedArray;
begin
  const ElementCount = TJSArrayLike.ToLength(Source);
  Result := Allocate(Kind, ElementCount, Prototype);

  for var Index := 0 to ElementCount - 1 do
  begin
    Result.StoreValue(Index, Source.GetProperty(TJSArrayLike.IndexName(Index)));
  end;
end;

function TJSTypedArrayBuiltins.CreateFromObject(const Kind: TJSElementKind; const Source: IJSObject;
                                                const Prototype: IJSObject): IJSTypedArray;
begin
  const Items = TList<TJSValue>.Create;
  try
    if ReadIterable(TJSValue.CreateObject(Source), Items) then
      Exit(CreateFromList(Kind, Items, Prototype));
  finally
    Items.Free;
  end;

  Result := CreateFromArrayLike(Kind, Source, Prototype);
end;

function TJSTypedArrayBuiltins.Construct(const Kind: TJSElementKind; const Args: TArray<TJSValue>;
                                         const NewTarget: IJSFunction): TJSValue;
begin
  const FirstArgument = TJSBinarySupport.Argument(Args, 0);
  var Created: IJSTypedArray;

  if not FirstArgument.IsObject then
  begin
    const ElementCount = TJSBinarySupport.ToIndex(FirstArgument);
    const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototypes[Kind]);
    Created := Allocate(Kind, ElementCount, Prototype);
    Exit(TJSValue.CreateObject(Created));
  end;

  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototypes[Kind]);
  const Source = FirstArgument.ToObject;

  var SourceArray: IJSTypedArray;
  var SourceBuffer: IJSArrayBuffer;
  if Supports(Source, IJSTypedArray, SourceArray) then
    Created := CreateFromTypedArray(Kind, SourceArray, Prototype)
  else if Supports(Source, IJSArrayBuffer, SourceBuffer) then
    Created := CreateFromBuffer(Kind, SourceBuffer, Args, Prototype)
  else
    Created := CreateFromObject(Kind, Source, Prototype);

  Result := TJSValue.CreateObject(Created);
end;

function TJSTypedArrayBuiltins.FromStatic(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireConstructor(This);

  const Source = TJSBinarySupport.Argument(Args, 0);
  const Mapper = TJSBinarySupport.Argument(Args, 1);
  const ThisArgument = TJSBinarySupport.Argument(Args, 2);

  var MapFunction: IJSFunction;
  const IsMapping = not Mapper.IsUndefined;
  if IsMapping and (not TJSBinarySupport.AsFunction(Mapper, MapFunction)) then
    raise TJSErrorFactory.TypeError(NOT_A_FUNCTION);

  const Items = TList<TJSValue>.Create;
  try
    var Created: IJSTypedArray;
    var ElementCount: Int64;
    var SourceObject: IJSObject;

    const IsIterable = ReadIterable(Source, Items);
    if IsIterable then
    begin
      ElementCount := Items.Count;
    end
    else
    begin
      SourceObject := FSupport.ToObject(Source);
      ElementCount := TJSArrayLike.ToLength(SourceObject);
    end;

    Created := CreateFromConstructor(Constructor_, [TJSValue.CreateNumber(ElementCount)], FROM_NAME);

    var MapThis: IJSObject := nil;
    if IsMapping then
      MapThis := FSupport.Interpreter.ThisObjectFor(MapFunction, ThisArgument);

    for var Index: Int64 := 0 to ElementCount - 1 do
    begin
      var Element: TJSValue;
      if IsIterable then
        Element := Items[Integer(Index)]
      else
        Element := SourceObject.GetProperty(TJSArrayLike.IndexName(Index));

      if IsMapping then
        Element := FSupport.Interpreter.CallFunction(MapFunction, [Element, TJSValue.CreateNumber(Index)], MapThis);

      Created.StoreValue(Integer(Index), Element);
    end;

    Result := TJSValue.CreateObject(Created);
  finally
    Items.Free;
  end;
end;

function TJSTypedArrayBuiltins.OfStatic(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Constructor_ = RequireConstructor(This);

  const Created = CreateFromConstructor(Constructor_, [TJSValue.CreateNumber(Length(Args))], OF_NAME);
  for var Index := 0 to Length(Args) - 1 do
  begin
    Created.StoreValue(Index, Args[Index]);
  end;

  Result := TJSValue.CreateObject(Created);
end;

procedure TJSTypedArrayBuiltins.DefineStatics;
begin
  FSupport.DefineMethod(FIntrinsicConstructor, FROM_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FromStatic(This, Args);
    end);

  FSupport.DefineMethod(FIntrinsicConstructor, OF_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := OfStatic(This, Args);
    end);

  FSupport.DefineSpeciesGetter(FIntrinsicConstructor);
end;

function TJSTypedArrayBuiltins.CreateIntrinsicConstructor: IJSFunction;
begin
  Result := FSupport.CreateConstructor(ABSTRACT_NAME, 0, ABSTRACT_CONSTRUCTOR,
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      raise TJSErrorFactory.TypeError(ABSTRACT_CONSTRUCTOR);
    end);
end;

function TJSTypedArrayBuiltins.CreateConcreteConstructor(const Kind: TJSElementKind): IJSFunction;
begin
  Result := FSupport.CreateConstructor(Kind.ConstructorName, 3, Format(REQUIRES_NEW, [Kind.ConstructorName]),
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      Result := Construct(Kind, Args, NewTarget);
    end);
end;

procedure TJSTypedArrayBuiltins.RegisterConcrete(const Kind: TJSElementKind);
begin
  const Prototype: IJSObject = TJSObject.Create;
  Prototype.Prototype := FIntrinsicPrototype;
  FPrototypes[Kind] := Prototype;

  const Constructor_ = CreateConcreteConstructor(Kind);
  Constructor_.Prototype := FIntrinsicConstructor;
  FConstructors[Kind] := Constructor_;

  FSupport.LinkConstructor(Constructor_, Prototype);

  const BytesPerElement = TJSValue.CreateNumber(Kind.ElementSize);
  FSupport.DefineConstant(Constructor_, BYTES_PER_ELEMENT, BytesPerElement);
  FSupport.DefineConstant(Prototype, BYTES_PER_ELEMENT, BytesPerElement);

  FSupport.Interpreter.SetGlobalVariable(Kind.ConstructorName, TJSValue.CreateObject(Constructor_));
end;

procedure TJSTypedArrayBuiltins.Register;
begin
  FIntrinsicPrototype := TJSObject.Create;
  FIntrinsicPrototype.Prototype := FSupport.Interpreter.ObjectPrototype;

  FIntrinsicConstructor := CreateIntrinsicConstructor;
  FSupport.LinkConstructor(FIntrinsicConstructor, FIntrinsicPrototype);
  DefineStatics;

  for var Kind in ALL_KINDS do
  begin
    RegisterConcrete(Kind);
  end;
end;

end.
