unit JS4D.ArrayBufferBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.BinarySupport;

type
  // The ArrayBuffer constructor, ArrayBuffer.isView and the prototype with byteLength and slice.
  TJSArrayBufferBuiltins = class
  private
    const
      ARRAY_BUFFER_NAME = 'ArrayBuffer';
      IS_VIEW_NAME = 'isView';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_LENGTH_GETTER_NAME = 'get byteLength';
      SLICE_NAME = 'slice';
      MAX_BYTE_LENGTH = 1073741824;
      REQUIRES_NEW = 'Constructor ArrayBuffer requires ''new''';
      ALLOCATION_FAILED = 'Array buffer allocation failed';
      INCOMPATIBLE_RECEIVER = 'Method ArrayBuffer.prototype.%s called on an incompatible receiver';
      DETACHED_BUFFER = 'Cannot perform ArrayBuffer.prototype.%s on a detached ArrayBuffer';
      SPECIES_NOT_A_BUFFER = 'The species constructor did not return an ArrayBuffer';
      SPECIES_DETACHED = 'The species constructor returned a detached ArrayBuffer';
      SPECIES_SAME_BUFFER = 'The species constructor returned the buffer that is being sliced';
      SPECIES_TOO_SMALL = 'The species constructor returned an ArrayBuffer that is too small';

    var
      FSupport: TJSBinarySupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function RequireBuffer(const This: IJSObject; const MethodName: string): IJSArrayBuffer;
    function Allocate(const ByteLength: Int64; const Prototype: IJSObject): IJSArrayBuffer;
    function IsView(const Args: TArray<TJSValue>): TJSValue;
    function Slice(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateSliceTarget(const Source: IJSArrayBuffer; const NewLength: Int64): IJSArrayBuffer;
    procedure DefinePrototypeMembers;

  public
    constructor Create(const Support: TJSBinarySupport);

    procedure Register;
    function CreateBuffer(const ByteLength: Int64): IJSArrayBuffer;

    property Prototype: IJSObject read FPrototype;
    property Constructor_: IJSFunction read FConstructor;
  end;

implementation

uses
  System.Math,
  JS4D.Errors,
  JS4D.ArrayLike;

constructor TJSArrayBufferBuiltins.Create(const Support: TJSBinarySupport);
begin
  inherited Create;

  FSupport := Support;
end;

function TJSArrayBufferBuiltins.RequireBuffer(const This: IJSObject; const MethodName: string): IJSArrayBuffer;
begin
  if not Supports(This, IJSArrayBuffer, Result) then
    raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_RECEIVER, [MethodName]));
end;

function TJSArrayBufferBuiltins.Allocate(const ByteLength: Int64; const Prototype: IJSObject): IJSArrayBuffer;
begin
  if ByteLength > MAX_BYTE_LENGTH then
    raise TJSErrorFactory.RangeError(ALLOCATION_FAILED);

  const Buffer = TJSArrayBufferObject.Create(Integer(ByteLength));
  Buffer.Prototype := Prototype;

  Result := Buffer;
end;

function TJSArrayBufferBuiltins.CreateBuffer(const ByteLength: Int64): IJSArrayBuffer;
begin
  Result := Allocate(ByteLength, FPrototype);
end;

function TJSArrayBufferBuiltins.IsView(const Args: TArray<TJSValue>): TJSValue;
begin
  const Candidate = TJSBinarySupport.Argument(Args, 0);

  const IsViewObject = Candidate.IsObject and (Supports(Candidate.ToObject, IJSTypedArray) or
                                               Supports(Candidate.ToObject, IJSDataView));

  Result := TJSValue.CreateBoolean(IsViewObject);
end;

function TJSArrayBufferBuiltins.CreateSliceTarget(const Source: IJSArrayBuffer;
                                                  const NewLength: Int64): IJSArrayBuffer;
begin
  const SourceObject: IJSObject = Source;
  const Species = FSupport.SpeciesConstructor(SourceObject, FConstructor);
  const Created = FSupport.Interpreter.Construct(Species, [TJSValue.CreateNumber(NewLength)]);

  const IsBuffer = Created.IsObject and Supports(Created.ToObject, IJSArrayBuffer, Result);
  if not IsBuffer then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_BUFFER);

  if Result.IsDetached then
    raise TJSErrorFactory.TypeError(SPECIES_DETACHED);

  const IsSameBuffer = ((Result as IInterface) = (Source as IInterface));
  if IsSameBuffer then
    raise TJSErrorFactory.TypeError(SPECIES_SAME_BUFFER);

  if Result.ByteLength < NewLength then
    raise TJSErrorFactory.TypeError(SPECIES_TOO_SMALL);
end;

function TJSArrayBufferBuiltins.Slice(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = RequireBuffer(This, SLICE_NAME);
  if Source.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_BUFFER, [SLICE_NAME]));

  const Count = Source.ByteLength;
  const FirstIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 0), Count, 0);
  const FinalIndex = TJSArrayLike.RelativeIndex(TJSBinarySupport.Argument(Args, 1), Count, Count);
  const NewLength = Int64(Max(FinalIndex - FirstIndex, 0));

  const Target = CreateSliceTarget(Source, NewLength);
  if Source.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_BUFFER, [SLICE_NAME]));

  const AvailableLength = Source.ByteLength;
  const CopyLength = Integer(Min(NewLength, Max(AvailableLength - FirstIndex, 0)));
  if CopyLength > 0 then
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

  FConstructor := FSupport.CreateConstructor(ARRAY_BUFFER_NAME, 1, REQUIRES_NEW,
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      const ByteLength = TJSBinarySupport.ToIndex(TJSBinarySupport.Argument(Args, 0));
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
