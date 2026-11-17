unit JS4D.DataViewBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.BuiltinSupport;

type
  TJSDataViewBuiltins = class
  private
    const
      DATA_VIEW_NAME = 'DataView';
      BUFFER_PROPERTY = 'buffer';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_OFFSET_PROPERTY = 'byteOffset';
      GET_PREFIX = 'get';
      SET_PREFIX = 'set';
      NOT_A_BUFFER = 'First argument to DataView constructor must be an ArrayBuffer';
      OFFSET_OUT_OF_BOUNDS = 'Start offset %d is outside the bounds of the buffer';
      LENGTH_OUT_OF_BOUNDS = 'Invalid DataView length %d';
      ACCESS_OUT_OF_BOUNDS = 'Offset is outside the bounds of the DataView';

    var
      FSupport: TJSBuiltinSupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function RequireView(const This: IJSObject; const MethodName: string): IJSDataView;
    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
    function RequireBuffer(const Args: TArray<TJSValue>): IJSArrayBuffer;
    function ResolveViewLength(const Buffer: IJSArrayBuffer; const Offset: Int64;
                               const LengthArgument: TJSValue): Int64;
    procedure RequireOffsetWithin(const Buffer: IJSArrayBuffer; const Offset: Int64);
    procedure RequireViewWithin(const Buffer: IJSArrayBuffer; const Offset: Int64; const ViewLength: Int64);
    function ReadViewValue(const This: IJSObject; const Args: TArray<TJSValue>; const MethodName: string;
                           const Kind: TJSElementKind): TJSValue;
    function WriteViewValue(const This: IJSObject; const Args: TArray<TJSValue>; const MethodName: string;
                            const Kind: TJSElementKind): TJSValue;
    procedure RequireRange(const View: IJSDataView; const RequestIndex: Int64; const Kind: TJSElementKind;
                           const MethodName: string);
    procedure DefineAccessors;
    procedure DefineValueMethods;
    procedure DefineValueMethodPair(const TypeName: string; const Kind: TJSElementKind);

  public
    constructor Create(const Support: TJSBuiltinSupport);

    procedure Register;
  end;

implementation

uses
  JS4D.Conversions,
  JS4D.PropertyNames,
  JS4D.ArrayLike,
  System.Math,
  JS4D.Errors;

constructor TJSDataViewBuiltins.Create(const Support: TJSBuiltinSupport);
begin
  inherited Create;

  FSupport := Support;
end;

function TJSDataViewBuiltins.RequireView(const This: IJSObject; const MethodName: string): IJSDataView;
begin
  if not Supports(This, IJSDataView, Result) then
  begin
    const Message = Format(INCOMPATIBLE_RECEIVER_FORMAT, [DATA_VIEW_NAME, MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

function TJSDataViewBuiltins.RequireBuffer(const Args: TArray<TJSValue>): IJSArrayBuffer;
begin
  const BufferArgument = TJSArrayLike.Argument(Args, 0);

  if not Supports(BufferArgument.ToObject, IJSArrayBuffer, Result) then
    raise TJSErrorFactory.TypeError(NOT_A_BUFFER);
end;

procedure TJSDataViewBuiltins.RequireOffsetWithin(const Buffer: IJSArrayBuffer; const Offset: Int64);
begin
  const IsPastEnd = (Offset > Buffer.ByteLength);
  if IsPastEnd then
  begin
    const Message = Format(OFFSET_OUT_OF_BOUNDS, [Offset]);
    raise TJSErrorFactory.RangeError(Message);
  end;
end;

function TJSDataViewBuiltins.ResolveViewLength(const Buffer: IJSArrayBuffer; const Offset: Int64;
                                               const LengthArgument: TJSValue): Int64;
begin
  Result := Int64(Buffer.ByteLength) - Offset;
  if LengthArgument.IsUndefined then
    Exit;

  Result := TJSBuiltinSupport.ToIndex(LengthArgument);
  RequireViewWithin(Buffer, Offset, Result);
end;

procedure TJSDataViewBuiltins.RequireViewWithin(const Buffer: IJSArrayBuffer; const Offset: Int64;
                                                const ViewLength: Int64);
begin
  const BufferLength = Int64(Buffer.ByteLength);
  const IsOutside = (Offset > BufferLength) or ((Offset + ViewLength) > BufferLength);
  if IsOutside then
  begin
    const Message = Format(LENGTH_OUT_OF_BOUNDS, [ViewLength]);
    raise TJSErrorFactory.RangeError(Message);
  end;
end;

function TJSDataViewBuiltins.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  const Buffer = RequireBuffer(Args);

  const OffsetArgument = TJSArrayLike.Argument(Args, 1);
  const Offset = TJSBuiltinSupport.ToIndex(OffsetArgument);
  TJSBuiltinSupport.RequireNotDetached(Buffer.IsDetached, DATA_VIEW_NAME);
  RequireOffsetWithin(Buffer, Offset);

  const LengthArgument = TJSArrayLike.Argument(Args, 2);
  const ViewLength = ResolveViewLength(Buffer, Offset, LengthArgument);

  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);
  TJSBuiltinSupport.RequireNotDetached(Buffer.IsDetached, DATA_VIEW_NAME);
  RequireViewWithin(Buffer, Offset, ViewLength);

  const View = TJSDataViewObject.Create(Buffer, Integer(Offset), Integer(ViewLength));
  View.Prototype := Prototype;

  Result := TJSValue.CreateObject(View);
end;

procedure TJSDataViewBuiltins.RequireRange(const View: IJSDataView; const RequestIndex: Int64;
                                           const Kind: TJSElementKind; const MethodName: string);
begin
  TJSBuiltinSupport.RequireNotDetached(View.Buffer.IsDetached, MethodName);

  const EndIndex = RequestIndex + Kind.ElementSize;
  const IsOutOfRange = (EndIndex > View.ByteLength);
  if IsOutOfRange then
    raise TJSErrorFactory.RangeError(ACCESS_OUT_OF_BOUNDS);
end;

function TJSDataViewBuiltins.ReadViewValue(const This: IJSObject; const Args: TArray<TJSValue>;
                                           const MethodName: string; const Kind: TJSElementKind): TJSValue;
begin
  const View = RequireView(This, MethodName);
  const IndexArgument = TJSArrayLike.Argument(Args, 0);
  const EndiannessArgument = TJSArrayLike.Argument(Args, 1);
  const RequestIndex = TJSBuiltinSupport.ToIndex(IndexArgument);
  const IsLittleEndian = EndiannessArgument.ToBoolean;

  RequireRange(View, RequestIndex, Kind, MethodName);

  const Offset = View.ByteOffset + Integer(RequestIndex);
  const Number = TJSElementCodec.Read(View.Buffer.Bytes, Offset, Kind, IsLittleEndian);

  Result := TJSValue.CreateNumber(Number);
end;

function TJSDataViewBuiltins.WriteViewValue(const This: IJSObject; const Args: TArray<TJSValue>;
                                            const MethodName: string; const Kind: TJSElementKind): TJSValue;
begin
  const View = RequireView(This, MethodName);
  const IndexArgument = TJSArrayLike.Argument(Args, 0);
  const ValueArgument = TJSArrayLike.Argument(Args, 1);
  const EndiannessArgument = TJSArrayLike.Argument(Args, 2);
  const RequestIndex = TJSBuiltinSupport.ToIndex(IndexArgument);
  const Number = TJSConversions.ToNumber(ValueArgument);
  const IsLittleEndian = EndiannessArgument.ToBoolean;

  RequireRange(View, RequestIndex, Kind, MethodName);

  const Offset = View.ByteOffset + Integer(RequestIndex);
  TJSElementCodec.Write(View.Buffer.Bytes, Offset, Kind, Number, IsLittleEndian);

  Result := TJSValue.CreateUndefined;
end;

procedure TJSDataViewBuiltins.DefineAccessors;
begin
  const BufferGetterName = Format(GETTER_NAME_FORMAT, [BUFFER_PROPERTY]);
  const ByteLengthGetterName = Format(GETTER_NAME_FORMAT, [BYTE_LENGTH_PROPERTY]);
  const ByteOffsetGetterName = Format(GETTER_NAME_FORMAT, [BYTE_OFFSET_PROPERTY]);

  FSupport.DefineGetter(FPrototype, BUFFER_PROPERTY, BufferGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = RequireView(This, BUFFER_PROPERTY);

      Result := TJSValue.CreateObject(View.Buffer);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_LENGTH_PROPERTY, ByteLengthGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = RequireView(This, BYTE_LENGTH_PROPERTY);
      const IsDetached = View.Buffer.IsDetached;

      const ByteLength = IfThen(IsDetached, 0, View.ByteLength);

      Result := TJSValue.CreateNumber(ByteLength);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_OFFSET_PROPERTY, ByteOffsetGetterName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = RequireView(This, BYTE_OFFSET_PROPERTY);
      const IsDetached = View.Buffer.IsDetached;

      const ByteOffset = IfThen(IsDetached, 0, View.ByteOffset);

      Result := TJSValue.CreateNumber(ByteOffset);
    end);
end;

procedure TJSDataViewBuiltins.DefineValueMethods;
begin
  for var Kind := Low(TJSElementKind) to High(TJSElementKind) do
  begin
    const IsClamped = (Kind = TJSElementKind.Uint8Clamped);
    if IsClamped then
      Continue;

    DefineValueMethodPair(Kind.TypeName, Kind);
  end;
end;

procedure TJSDataViewBuiltins.DefineValueMethodPair(const TypeName: string; const Kind: TJSElementKind);
begin
  const GetterName = GET_PREFIX + TypeName;
  const SetterName = SET_PREFIX + TypeName;

  FSupport.DefineMethod(FPrototype, GetterName, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ReadViewValue(This, Args, GetterName, Kind);
    end);

  FSupport.DefineMethod(FPrototype, SetterName, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := WriteViewValue(This, Args, SetterName, Kind);
    end);
end;

procedure TJSDataViewBuiltins.Register;
begin
  const Interpreter = FSupport.Interpreter;

  FPrototype := TJSObject.Create;
  FPrototype.Prototype := Interpreter.ObjectPrototype;

  const RequiresNewMessage = Format(CONSTRUCTOR_REQUIRES_NEW, [DATA_VIEW_NAME]);
  FConstructor := FSupport.CreateConstructor(DATA_VIEW_NAME, 1, RequiresNewMessage, Construct);
  FSupport.LinkConstructor(FConstructor, FPrototype);

  DefineAccessors;
  DefineValueMethods;
  FSupport.DefineToStringTag(FPrototype, DATA_VIEW_NAME);

  const ConstructorValue = TJSValue.CreateObject(FConstructor);
  Interpreter.SetGlobalVariable(DATA_VIEW_NAME, ConstructorValue);
end;

end.
