unit JS4D.ArrayBufferBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.BuiltinSupport;

type
  TJSArrayBufferBuiltins = class
  private
    const
      ARRAY_BUFFER_NAME = 'ArrayBuffer';
      IS_VIEW_NAME = 'isView';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_LENGTH_GETTER_NAME = 'get byteLength';
      SLICE_NAME = 'slice';
      ARRAY_BUFFER_SLICE_PATH = 'ArrayBuffer.prototype.slice';
      MAX_BYTE_LENGTH = 1073741824;
      ALLOCATION_FAILED = 'Array buffer allocation failed';
      SPECIES_NOT_A_BUFFER = 'The species constructor did not return an ArrayBuffer';
      SPECIES_DETACHED = 'The species constructor returned a detached ArrayBuffer';
      SPECIES_SAME_BUFFER = 'The species constructor returned the buffer that is being sliced';
      SPECIES_TOO_SMALL = 'The species constructor returned an ArrayBuffer that is too small';

    var
      FSupport: TJSBuiltinSupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function RequireBuffer(const This: IJSObject; const MethodName: string): IJSArrayBuffer;
    function Allocate(const ByteLength: Int64; const Prototype: IJSObject): IJSArrayBuffer;
    function IsView(const Args: TArray<TJSValue>): TJSValue;
    function Slice(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateSliceTarget(const Source: IJSArrayBuffer; const NewLength: Int64): IJSArrayBuffer;
    procedure DefinePrototypeMembers;

  public
    constructor Create(const Support: TJSBuiltinSupport);

    procedure Register;
    function CreateBuffer(const ByteLength: Int64): IJSArrayBuffer;
  end;

implementation

uses
  JS4D.Conversions,
  JS4D.PropertyNames,
  System.Math,
  JS4D.Errors,
  JS4D.ArrayLike;

constructor TJSArrayBufferBuiltins.Create(const Support: TJSBuiltinSupport);
begin
  inherited Create;

  FSupport := Support;
end;

function TJSArrayBufferBuiltins.RequireBuffer(const This: IJSObject; const MethodName: string): IJSArrayBuffer;
begin
  if not Supports(This, IJSArrayBuffer, Result) then
  begin
    const Message = Format(INCOMPATIBLE_RECEIVER_FORMAT, [ARRAY_BUFFER_NAME, MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSArrayBufferBuiltins.Allocate(const ByteLength: Int64; const Prototype: IJSObject): IJSArrayBuffer;
begin
  const ExceedsMaximum = (ByteLength > MAX_BYTE_LENGTH);
  if ExceedsMaximum then
    raise TJSErrorFactory.RangeError(ALLOCATION_FAILED);

  var Buffer: TJSArrayBufferObject;
  try
    Buffer := TJSArrayBufferObject.Create(Integer(ByteLength));
  except
    on EOutOfMemory do
      raise TJSErrorFactory.RangeError(ALLOCATION_FAILED);
  end;

  Buffer.Prototype := Prototype;

  Result := Buffer;
end;

function TJSArrayBufferBuiltins.CreateBuffer(const ByteLength: Int64): IJSArrayBuffer;
begin
  Result := Allocate(ByteLength, FPrototype);
end;

function TJSArrayBufferBuiltins.IsView(const Args: TArray<TJSValue>): TJSValue;
begin
  const Candidate = TJSArrayLike.Argument(Args, 0);

  const CandidateObject = Candidate.ToObject;
  const IsViewObject = (Supports(CandidateObject, IJSTypedArray) or Supports(CandidateObject, IJSDataView));

  Result := TJSValue.CreateBoolean(IsViewObject);
end;

function TJSArrayBufferBuiltins.CreateSliceTarget(const Source: IJSArrayBuffer;
                                                  const NewLength: Int64): IJSArrayBuffer;
begin
  const SourceObject: IJSObject = Source;
  const Species = TJSConversions.SpeciesConstructor(SourceObject, FConstructor);
  const Created = FSupport.Interpreter.Construct(Species, [TJSValue.CreateNumber(NewLength)]);

  if not Supports(Created.ToObject, IJSArrayBuffer, Result) then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_BUFFER);

  if Result.IsDetached then
    raise TJSErrorFactory.TypeError(SPECIES_DETACHED);

  const IsSameBuffer = ((Result as IInterface) = (Source as IInterface));
  if IsSameBuffer then
    raise TJSErrorFactory.TypeError(SPECIES_SAME_BUFFER);

  const IsTooSmall = (Result.ByteLength < NewLength);
  if IsTooSmall then
    raise TJSErrorFactory.TypeError(SPECIES_TOO_SMALL);
end;

function TJSArrayBufferBuiltins.Slice(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = RequireBuffer(This, SLICE_NAME);
  TJSBuiltinSupport.RequireNotDetached(Source.IsDetached, ARRAY_BUFFER_SLICE_PATH);

  const Count = Source.ByteLength;
  const StartArgument = TJSArrayLike.Argument(Args, 0);
  const EndArgument = TJSArrayLike.Argument(Args, 1);
  const FirstIndex = TJSArrayLike.RelativeIndex(StartArgument, Count, 0);
  const FinalIndex = TJSArrayLike.RelativeIndex(EndArgument, Count, Count);
  const NewLength = Int64(Max(FinalIndex - FirstIndex, 0));

  const Target = CreateSliceTarget(Source, NewLength);
  TJSBuiltinSupport.RequireNotDetached(Source.IsDetached, ARRAY_BUFFER_SLICE_PATH);

  const AvailableLength = Source.ByteLength;
  const CopyLength = Integer(Min(NewLength, Max(AvailableLength - FirstIndex, 0)));
  const HasBytesToCopy = (CopyLength > 0);
  if HasBytesToCopy then
    Move(Source.Bytes[Integer(FirstIndex)], Target.Bytes[0], CopyLength);

  Result := TJSValue.CreateObject(Target);
end;

procedure TJSArrayBufferBuiltins.DefinePrototypeMembers;
begin
  FSupport.DefineGetter(FPrototype, BYTE_LENGTH_PROPERTY, BYTE_LENGTH_GETTER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateNumber(RequireBuffer(This, BYTE_LENGTH_PROPERTY).ByteLength);
    end);

  FSupport.DefineMethod(FPrototype, SLICE_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Slice(This, Args);
    end);

  FSupport.DefineToStringTag(FPrototype, ARRAY_BUFFER_NAME);
end;

procedure TJSArrayBufferBuiltins.Register;
begin
  const Interpreter = FSupport.Interpreter;

  FPrototype := TJSObject.Create;
  FPrototype.Prototype := Interpreter.ObjectPrototype;

  const RequiresNewMessage = Format(CONSTRUCTOR_REQUIRES_NEW, [ARRAY_BUFFER_NAME]);
  FConstructor := FSupport.CreateConstructor(ARRAY_BUFFER_NAME, 1, RequiresNewMessage,
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      const LengthArgument = TJSArrayLike.Argument(Args, 0);
      const ByteLength = TJSBuiltinSupport.ToIndex(LengthArgument);
      const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);

      Result := TJSValue.CreateObject(Allocate(ByteLength, Prototype));
    end);

  FSupport.LinkConstructor(FConstructor, FPrototype);
  FSupport.DefineSpeciesGetter(FConstructor);
  FSupport.DefineMethod(FConstructor, IS_VIEW_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := IsView(Args);
    end);

  DefinePrototypeMembers;
  Interpreter.SetGlobalVariable(ARRAY_BUFFER_NAME, TJSValue.CreateObject(FConstructor));
end;

end.
