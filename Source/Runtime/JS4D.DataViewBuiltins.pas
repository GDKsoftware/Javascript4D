unit JS4D.DataViewBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.BinarySupport;

type
  // The DataView constructor and prototype: the buffer, byteLength and byteOffset accessors and the get and
  // set methods for every element type except the clamped one.
  TJSDataViewBuiltins = class
  private
    const
      DATA_VIEW_NAME = 'DataView';
      BUFFER_PROPERTY = 'buffer';
      BYTE_LENGTH_PROPERTY = 'byteLength';
      BYTE_OFFSET_PROPERTY = 'byteOffset';
      GETTER_PREFIX = 'get ';
      GET_PREFIX = 'get';
      SET_PREFIX = 'set';
      REQUIRES_NEW = 'Constructor DataView requires ''new''';
      NOT_A_BUFFER = 'First argument to DataView constructor must be an ArrayBuffer';
      DETACHED_BUFFER = 'Cannot perform %s on a detached ArrayBuffer';
      OFFSET_OUT_OF_BOUNDS = 'Start offset %d is outside the bounds of the buffer';
      LENGTH_OUT_OF_BOUNDS = 'Invalid DataView length %d';
      INCOMPATIBLE_RECEIVER = 'Method DataView.prototype.%s called on an incompatible receiver';
      ACCESS_OUT_OF_BOUNDS = 'Offset is outside the bounds of the DataView';
      ACCESSOR_KINDS: array[0..7] of TJSElementKind = (TJSElementKind.Int8, TJSElementKind.Uint8,
                                                       TJSElementKind.Int16, TJSElementKind.Uint16,
                                                       TJSElementKind.Int32, TJSElementKind.Uint32,
                                                       TJSElementKind.Float32, TJSElementKind.Float64);
      ACCESSOR_NAMES: array[0..7] of string = ('Int8', 'Uint8', 'Int16', 'Uint16', 'Int32', 'Uint32',
                                               'Float32', 'Float64');

    var
      FSupport: TJSBinarySupport;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    function RequireView(const This: IJSObject; const MethodName: string): IJSDataView;
    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
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
    constructor Create(const Support: TJSBinarySupport);

    procedure Register;
  end;

implementation

uses
  System.Math,
  JS4D.Errors;

constructor TJSDataViewBuiltins.Create(const Support: TJSBinarySupport);
begin
  inherited Create;

  FSupport := Support;
end;

function TJSDataViewBuiltins.RequireView(const This: IJSObject; const MethodName: string): IJSDataView;
begin
  if not Supports(This, IJSDataView, Result) then
    raise TJSErrorFactory.TypeError(Format(INCOMPATIBLE_RECEIVER, [MethodName]));
end;

function TJSDataViewBuiltins.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  const BufferArgument = TJSBinarySupport.Argument(Args, 0);

  var Buffer: IJSArrayBuffer;
  const IsBuffer = BufferArgument.IsObject and Supports(BufferArgument.ToObject, IJSArrayBuffer, Buffer);
  if not IsBuffer then
    raise TJSErrorFactory.TypeError(NOT_A_BUFFER);

  const Offset = TJSBinarySupport.ToIndex(TJSBinarySupport.Argument(Args, 1));
  if Buffer.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_BUFFER, [DATA_VIEW_NAME]));

  if Offset > Buffer.ByteLength then
    raise TJSErrorFactory.RangeError(Format(OFFSET_OUT_OF_BOUNDS, [Offset]));

  const LengthArgument = TJSBinarySupport.Argument(Args, 2);
  var ViewLength := Int64(Buffer.ByteLength) - Offset;
  if not LengthArgument.IsUndefined then
  begin
    ViewLength := TJSBinarySupport.ToIndex(LengthArgument);
    if (Offset + ViewLength) > Buffer.ByteLength then
      raise TJSErrorFactory.RangeError(Format(LENGTH_OUT_OF_BOUNDS, [ViewLength]));
  end;

  const Prototype = FSupport.PrototypeFromConstructor(NewTarget, FPrototype);
  if Buffer.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_BUFFER, [DATA_VIEW_NAME]));

  const BufferLength = Int64(Buffer.ByteLength);
  if (Offset > BufferLength) or ((Offset + ViewLength) > BufferLength) then
    raise TJSErrorFactory.RangeError(Format(LENGTH_OUT_OF_BOUNDS, [ViewLength]));

  const View = TJSDataViewObject.Create(Buffer, Integer(Offset), Integer(ViewLength));
  View.Prototype := Prototype;

  Result := TJSValue.CreateObject(View);
end;

procedure TJSDataViewBuiltins.RequireRange(const View: IJSDataView; const RequestIndex: Int64;
                                           const Kind: TJSElementKind; const MethodName: string);
begin
  if View.Buffer.IsDetached then
    raise TJSErrorFactory.TypeError(Format(DETACHED_BUFFER, [MethodName]));

  const EndIndex = RequestIndex + Kind.ElementSize;
  if EndIndex > View.ByteLength then
    raise TJSErrorFactory.RangeError(ACCESS_OUT_OF_BOUNDS);
end;

function TJSDataViewBuiltins.ReadViewValue(const This: IJSObject; const Args: TArray<TJSValue>;
                                           const MethodName: string; const Kind: TJSElementKind): TJSValue;
begin
  const View = RequireView(This, MethodName);
  const RequestIndex = TJSBinarySupport.ToIndex(TJSBinarySupport.Argument(Args, 0));
  const IsLittleEndian = TJSBinarySupport.Argument(Args, 1).ToBoolean;

  RequireRange(View, RequestIndex, Kind, MethodName);

  const Offset = View.ByteOffset + Integer(RequestIndex);
  Result := TJSValue.CreateNumber(TJSElementCodec.Read(View.Buffer.Bytes, Offset, Kind, IsLittleEndian));
end;

function TJSDataViewBuiltins.WriteViewValue(const This: IJSObject; const Args: TArray<TJSValue>;
                                            const MethodName: string; const Kind: TJSElementKind): TJSValue;
begin
  const View = RequireView(This, MethodName);
  const RequestIndex = TJSBinarySupport.ToIndex(TJSBinarySupport.Argument(Args, 0));
  const Number = TJSBinarySupport.Argument(Args, 1).ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
  const IsLittleEndian = TJSBinarySupport.Argument(Args, 2).ToBoolean;

  RequireRange(View, RequestIndex, Kind, MethodName);

  const Offset = View.ByteOffset + Integer(RequestIndex);
  TJSElementCodec.Write(View.Buffer.Bytes, Offset, Kind, Number, IsLittleEndian);

  Result := TJSValue.CreateUndefined;
end;

procedure TJSDataViewBuiltins.DefineAccessors;
begin
  FSupport.DefineGetter(FPrototype, BUFFER_PROPERTY, GETTER_PREFIX + BUFFER_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := TJSValue.CreateObject(RequireView(This, BUFFER_PROPERTY).Buffer);
    end);

  FSupport.DefineGetter(FPrototype, BYTE_LENGTH_PROPERTY, GETTER_PREFIX + BYTE_LENGTH_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = RequireView(This, BYTE_LENGTH_PROPERTY);
      const IsDetached = View.Buffer.IsDetached;

      Result := TJSValue.CreateNumber(IfThen(IsDetached, 0, View.ByteLength));
    end);

  FSupport.DefineGetter(FPrototype, BYTE_OFFSET_PROPERTY, GETTER_PREFIX + BYTE_OFFSET_PROPERTY,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const View = RequireView(This, BYTE_OFFSET_PROPERTY);
      const IsDetached = View.Buffer.IsDetached;

      Result := TJSValue.CreateNumber(IfThen(IsDetached, 0, View.ByteOffset));
    end);
end;

procedure TJSDataViewBuiltins.DefineValueMethods;
begin
  for var Position := Low(ACCESSOR_KINDS) to High(ACCESSOR_KINDS) do
  begin
    DefineValueMethodPair(ACCESSOR_NAMES[Position], ACCESSOR_KINDS[Position]);
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

  FConstructor := FSupport.CreateConstructor(DATA_VIEW_NAME, 1, REQUIRES_NEW, Construct);
  FSupport.LinkConstructor(FConstructor, FPrototype);

  DefineAccessors;
  DefineValueMethods;
  FSupport.DefineToStringTag(FPrototype, DATA_VIEW_NAME);

  Interpreter.SetGlobalVariable(DATA_VIEW_NAME, TJSValue.CreateObject(FConstructor));
end;

end.
