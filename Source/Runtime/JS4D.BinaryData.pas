unit JS4D.BinaryData;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.ObjectHeap,
  JS4D.Types;

type
  TJSElementKind = (Int8, Uint8, Uint8Clamped, Int16, Uint16, Int32, Uint32, Float32, Float64);

  TJSElementKindHelper = record helper for TJSElementKind
    function ElementSize: Integer;
    function ConstructorName: string;
  end;

  // Converts between the numbers of a script and the bytes of a buffer. A multi-byte value is stored in the
  // byte order that the caller asks for.
  TJSElementCodec = class
  private
    class function ToModular(const Value: Double): UInt32; static;
    class function ToClamped(const Value: Double): Byte; static;
    class procedure SwapIfBigEndian(var Raw: array of Byte; const Size: Integer;
                                    const IsLittleEndian: Boolean); static;

  public
    class function Read(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                        const IsLittleEndian: Boolean = True): Double; static;
    class procedure Write(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                          const Value: Double; const IsLittleEndian: Boolean = True); static;
  end;

  IJSArrayBuffer = interface(IJSObject)
    ['{5A7C3E19-B2D4-4F86-9E01-C8A6D3B7F254}']
    function GetBytes: TBytes;
    function GetByteLength: Integer;
    function GetIsDetached: Boolean;
    // Releases the bytes: afterwards the length is 0 and every view on the buffer is detached.
    procedure Detach;
    property Bytes: TBytes read GetBytes;
    property ByteLength: Integer read GetByteLength;
    property IsDetached: Boolean read GetIsDetached;
  end;

  IJSTypedArray = interface(IJSObject)
    ['{9E2B6D40-1C7A-4B35-A8F9-3D5E0C71B462}']
    function GetKind: TJSElementKind;
    function GetBuffer: IJSArrayBuffer;
    function GetByteOffset: Integer;
    function GetViewOffset: Integer;
    function GetLength: Integer;
    function GetIsDetached: Boolean;
    function ReadElement(const Index: Integer): TJSValue;
    // Converts the value to a number and stores it, unless the index is no longer valid.
    procedure StoreValue(const Index: Integer; const Value: TJSValue);
    function IsElementKey(const Name: TJSPropertyKey): Boolean;
    function IsNumericKey(const Name: TJSPropertyKey): Boolean;
    property Kind: TJSElementKind read GetKind;
    property Buffer: IJSArrayBuffer read GetBuffer;
    property ByteOffset: Integer read GetByteOffset;
    // The offset into the buffer, which stays what it was when the buffer is detached.
    property ViewOffset: Integer read GetViewOffset;
    property Length: Integer read GetLength;
    property IsDetached: Boolean read GetIsDetached;
  end;

  IJSDataView = interface(IJSObject)
    ['{0B8D4F27-6E3C-4A91-B7D5-2F9A1E6C8043}']
    function GetBuffer: IJSArrayBuffer;
    function GetByteOffset: Integer;
    function GetByteLength: Integer;
    property Buffer: IJSArrayBuffer read GetBuffer;
    property ByteOffset: Integer read GetByteOffset;
    property ByteLength: Integer read GetByteLength;
  end;

  // Asks an object whether a property name is one of the integer-indexed keys of a typed array.
  TJSBinaryKeys = class
  public
    class function TryStoreElement(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                   const Receiver: TJSValue; out IsStored: Boolean): Boolean; static;
    class function IsElementKey(const Target: IJSObject; const Name: TJSPropertyKey): Boolean; static;
  end;

  TJSArrayBufferObject = class(TJSObjectImpl, IJSArrayBuffer)
  private
    FData: TBytes;
    FIsDetached: Boolean;

    function GetBytes: TBytes;
    function GetByteLength: Integer;
    function GetIsDetached: Boolean;

  public
    constructor Create(const ByteLength: Integer);

    procedure Detach;
  end;

  TJSDataViewObject = class(TJSObjectImpl, IJSDataView)
  private
    FBuffer: IJSArrayBuffer;
    FByteOffset: Integer;
    FByteLength: Integer;

    function GetBuffer: IJSArrayBuffer;
    function GetByteOffset: Integer;
    function GetByteLength: Integer;

  protected
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;

  public
    constructor Create(const Buffer: IJSArrayBuffer; const ByteOffset: Integer; const ByteLength: Integer);
  end;

  // An integer-indexed exotic object: the property names that are canonical numeric strings never reach the
  // ordinary property table, they read and write the bytes of the buffer.
  TJSTypedArrayObject = class(TJSObjectImpl, IJSTypedArray, IJSIntegerIndexedKeys)
  private
    type
      TKeyClass = (NotNumeric, InvalidIndex, ValidIndex);

    const
      MAX_PLAIN_DIGITS = 15;
      NOT_FROZEN_ELEMENTS = 'Cannot freeze array buffer views with elements';
      NOT_SEALED_ELEMENTS = 'Cannot seal array buffer views with elements';

    var
      FKind: TJSElementKind;
      FBuffer: IJSArrayBuffer;
      FByteOffset: Integer;
      FLength: Integer;

  protected
    function LookupOwn(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): TJSOwnLookup; override;
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;

  private
    class function TryParsePlainIndex(const Name: string; out Index: Int64): Boolean; static;
    class function IsCanonicalNumber(const Name: string): Boolean; static;
    function ClassifyKey(const Key: TJSPropertyKey; out Index: Integer): TKeyClass;
    function IsInvalidIndexKey(const Name: TJSPropertyKey): Boolean;
    function CreateElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
    function GetKind: TJSElementKind;
    function GetBuffer: IJSArrayBuffer;
    function GetByteOffset: Integer;
    function GetViewOffset: Integer;
    function GetLength: Integer;
    function GetIsDetached: Boolean;

  public
    constructor Create(const Kind: TJSElementKind; const Buffer: IJSArrayBuffer; const ByteOffset: Integer;
                       const Length: Integer);

    function ReadElement(const Index: Integer): TJSValue;
    procedure StoreValue(const Index: Integer; const Value: TJSValue);
    function IsElementKey(const Name: TJSPropertyKey): Boolean;
    function IsNumericKey(const Name: TJSPropertyKey): Boolean;

    function GetProperty(const Name: TJSPropertyKey): TJSValue; override;
    procedure SetProperty(const Name: TJSPropertyKey; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: TJSPropertyKey); override;
    function IsPropertyConfigurable(const Name: TJSPropertyKey): Boolean; override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnPropertyDescriptor(const Name: TJSPropertyKey): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: TJSPropertyKey): Boolean; override;
    function TryAssignOwnProperty(const Name: TJSPropertyKey; const Value: TJSValue): Boolean; override;
    function DefineOwnProperty(const Name: TJSPropertyKey; const Definition: TJSPropertyDefinition): Boolean; override;
    function IsFrozen: Boolean; override;
    function IsSealed: Boolean; override;
    procedure Freeze; override;
    procedure Seal; override;
  end;

implementation

uses
  JS4D.Errors;

const
  TWO_POWER_32 = 4294967296.0;
  BYTE_MAX = 255;
  HALF = 0.5;
  ELEMENT_SIZES: array[TJSElementKind] of Integer = (1, 1, 1, 2, 2, 4, 4, 4, 8);
  CONSTRUCTOR_NAMES: array[TJSElementKind] of string = ('Int8Array', 'Uint8Array', 'Uint8ClampedArray',
                                                        'Int16Array', 'Uint16Array', 'Int32Array', 'Uint32Array',
                                                        'Float32Array', 'Float64Array');

{ TJSElementKindHelper }

function TJSElementKindHelper.ElementSize: Integer;
begin
  Result := ELEMENT_SIZES[Self];
end;

function TJSElementKindHelper.ConstructorName: string;
begin
  Result := CONSTRUCTOR_NAMES[Self];
end;

{ TJSElementCodec }

class function TJSElementCodec.ToModular(const Value: Double): UInt32;
begin
  const IsFinite = (not IsNaN(Value)) and (not IsInfinite(Value));
  if not IsFinite then
    Exit(0);

  const Whole = Int(Value);
  var Remainder := Whole - (Int(Whole / TWO_POWER_32) * TWO_POWER_32);
  if Remainder < 0 then
    Remainder := Remainder + TWO_POWER_32;

  Result := UInt32(Trunc(Remainder) and $FFFFFFFF);
end;

class function TJSElementCodec.ToClamped(const Value: Double): Byte;
begin
  if IsNaN(Value) or (Value <= 0) then
    Exit(0);

  if Value >= BYTE_MAX then
    Exit(BYTE_MAX);

  const Lower = Floor(Value);
  const Difference = Value - Lower;
  const IsLowerEven = (Trunc(Lower) mod 2) = 0;

  if (Difference < HALF) or ((Difference = HALF) and IsLowerEven) then
    Result := Byte(Trunc(Lower))
  else
    Result := Byte(Trunc(Lower) + 1);
end;

class procedure TJSElementCodec.SwapIfBigEndian(var Raw: array of Byte; const Size: Integer;
                                                const IsLittleEndian: Boolean);
begin
  if IsLittleEndian then
    Exit;

  for var Index := 0 to (Size div 2) - 1 do
  begin
    const Mirror = Size - 1 - Index;
    const Swapped = Raw[Index];
    Raw[Index] := Raw[Mirror];
    Raw[Mirror] := Swapped;
  end;
end;

class function TJSElementCodec.Read(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                                    const IsLittleEndian: Boolean): Double;
begin
  const Size = Kind.ElementSize;

  var Raw: array[0..7] of Byte;
  Move(Bytes[Offset], Raw[0], Size);
  SwapIfBigEndian(Raw, Size, IsLittleEndian);

  case Kind of
    TJSElementKind.Int8         : Result := ShortInt(Raw[0]);
    TJSElementKind.Uint8,
    TJSElementKind.Uint8Clamped : Result := Raw[0];
    TJSElementKind.Int16        : Result := PSmallInt(@Raw[0])^;
    TJSElementKind.Uint16       : Result := PWord(@Raw[0])^;
    TJSElementKind.Int32        : Result := PInteger(@Raw[0])^;
    TJSElementKind.Uint32       : Result := PCardinal(@Raw[0])^;
    TJSElementKind.Float32      : Result := PSingle(@Raw[0])^;
    TJSElementKind.Float64      : Result := PDouble(@Raw[0])^;
  else
    raise ENotSupportedException.CreateFmt('Unsupported element kind: %d', [Ord(Kind)]);
  end;
end;

class procedure TJSElementCodec.Write(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                                      const Value: Double; const IsLittleEndian: Boolean);
begin
  const Size = Kind.ElementSize;

  var Raw: array[0..7] of Byte;
  case Kind of
    TJSElementKind.Int8,
    TJSElementKind.Uint8        : Raw[0] := Byte(ToModular(Value) and $FF);
    TJSElementKind.Uint8Clamped : Raw[0] := ToClamped(Value);
    TJSElementKind.Int16,
    TJSElementKind.Uint16       : PWord(@Raw[0])^ := Word(ToModular(Value) and $FFFF);
    TJSElementKind.Int32,
    TJSElementKind.Uint32       : PCardinal(@Raw[0])^ := ToModular(Value);
    TJSElementKind.Float32      : PSingle(@Raw[0])^ := Value;
    TJSElementKind.Float64      : PDouble(@Raw[0])^ := Value;
  else
    raise ENotSupportedException.CreateFmt('Unsupported element kind: %d', [Ord(Kind)]);
  end;

  SwapIfBigEndian(Raw, Size, IsLittleEndian);
  Move(Raw[0], Bytes[Offset], Size);
end;

{ TJSBinaryKeys }

class function TJSBinaryKeys.TryStoreElement(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                             const Receiver: TJSValue; out IsStored: Boolean): Boolean;
begin
  IsStored := True;

  var TypedArray: IJSTypedArray;
  const IsNumeric = Supports(Target, IJSTypedArray, TypedArray) and TypedArray.IsNumericKey(Name);
  if not IsNumeric then
    Exit(False);

  const IsReceiver = Receiver.IsObject and ((Receiver.ToObject as IInterface) = (Target as IInterface));
  if IsReceiver then
  begin
    Target.SetProperty(Name, Value);
    Exit(True);
  end;

  Result := not TypedArray.IsElementKey(Name);
end;

class function TJSBinaryKeys.IsElementKey(const Target: IJSObject; const Name: TJSPropertyKey): Boolean;
begin
  var TypedArray: IJSTypedArray;

  Result := Supports(Target, IJSTypedArray, TypedArray) and TypedArray.IsElementKey(Name);
end;

{ TJSArrayBufferObject }

constructor TJSArrayBufferObject.Create(const ByteLength: Integer);
begin
  inherited Create;

  SetLength(FData, ByteLength);
  if ByteLength > 0 then
    FillChar(FData[0], ByteLength, 0);
end;

function TJSArrayBufferObject.GetBytes: TBytes;
begin
  Result := FData;
end;

function TJSArrayBufferObject.GetByteLength: Integer;
begin
  Result := Length(FData);
end;

function TJSArrayBufferObject.GetIsDetached: Boolean;
begin
  Result := FIsDetached;
end;

procedure TJSArrayBufferObject.Detach;
begin
  FData := nil;
  FIsDetached := True;
end;

{ TJSDataViewObject }

constructor TJSDataViewObject.Create(const Buffer: IJSArrayBuffer; const ByteOffset: Integer;
                                     const ByteLength: Integer);
begin
  inherited Create;

  FBuffer := Buffer;
  FByteOffset := ByteOffset;
  FByteLength := ByteLength;
end;

procedure TJSDataViewObject.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
  inherited;
  ReportReference(Visit, FBuffer);
end;

function TJSDataViewObject.GetBuffer: IJSArrayBuffer;
begin
  Result := FBuffer;
end;

function TJSDataViewObject.GetByteOffset: Integer;
begin
  Result := FByteOffset;
end;

function TJSDataViewObject.GetByteLength: Integer;
begin
  Result := FByteLength;
end;

{ TJSTypedArrayObject }

constructor TJSTypedArrayObject.Create(const Kind: TJSElementKind; const Buffer: IJSArrayBuffer;
                                       const ByteOffset: Integer; const Length: Integer);
begin
  inherited Create;
  HasOrdinaryLookup := False;

  FKind := Kind;
  FBuffer := Buffer;
  FByteOffset := ByteOffset;
  FLength := Length;
end;

procedure TJSTypedArrayObject.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
  inherited;
  ReportReference(Visit, FBuffer);
end;

function TJSTypedArrayObject.GetKind: TJSElementKind;
begin
  Result := FKind;
end;

function TJSTypedArrayObject.GetBuffer: IJSArrayBuffer;
begin
  Result := FBuffer;
end;

function TJSTypedArrayObject.GetByteOffset: Integer;
begin
  if FBuffer.IsDetached then
    Exit(0);

  Result := FByteOffset;
end;

function TJSTypedArrayObject.GetViewOffset: Integer;
begin
  Result := FByteOffset;
end;

function TJSTypedArrayObject.GetLength: Integer;
begin
  if FBuffer.IsDetached then
    Exit(0);

  Result := FLength;
end;

function TJSTypedArrayObject.GetIsDetached: Boolean;
begin
  Result := FBuffer.IsDetached;
end;

function TJSTypedArrayObject.ReadElement(const Index: Integer): TJSValue;
begin
  const IsValid = (Index >= 0) and (Index < GetLength);
  if not IsValid then
    Exit(TJSValue.CreateUndefined);

  const Offset = FByteOffset + (Index * FKind.ElementSize);
  Result := TJSValue.CreateNumber(TJSElementCodec.Read(FBuffer.Bytes, Offset, FKind));
end;

procedure TJSTypedArrayObject.StoreValue(const Index: Integer; const Value: TJSValue);
begin
  const Number = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;

  const IsValid = (Index >= 0) and (Index < GetLength);
  if not IsValid then
    Exit;

  const Offset = FByteOffset + (Index * FKind.ElementSize);
  TJSElementCodec.Write(FBuffer.Bytes, Offset, FKind, Number);
end;

class function TJSTypedArrayObject.TryParsePlainIndex(const Name: string; out Index: Int64): Boolean;
begin
  Index := 0;

  const NameLength = Length(Name);
  const HasValidLength = (NameLength > 0) and (NameLength <= MAX_PLAIN_DIGITS);
  const HasLeadingZero = (NameLength > 1) and (Name[1] = '0');
  if (not HasValidLength) or HasLeadingZero then
    Exit(False);

  for var Position := 1 to NameLength do
  begin
    const Digit = Ord(Name[Position]) - Ord('0');
    const IsDigit = (Digit >= 0) and (Digit <= 9);
    if not IsDigit then
      Exit(False);

    Index := (Index * 10) + Digit;
  end;

  Result := True;
end;

class function TJSTypedArrayObject.IsCanonicalNumber(const Name: string): Boolean;
begin
  const FirstChar = Name[1];
  const CanStartNumber = CharInSet(FirstChar, ['0'..'9', '-', 'I', 'N']);
  if not CanStartNumber then
    Exit(False);

  if Name = '-0' then
    Exit(True);

  const Number = TJSValue.CreateString(Name).ToNumber;
  Result := TJSValue.CreateNumber(Number).ToString = Name;
end;

function TJSTypedArrayObject.ClassifyKey(const Key: TJSPropertyKey; out Index: Integer): TKeyClass;
begin
  Index := -1;

  const Name = Key.Stored;

  const IsEmpty = (Name = '');
  if IsEmpty then
    Exit(TKeyClass.NotNumeric);

  var PlainIndex: Int64;
  if TryParsePlainIndex(Name, PlainIndex) then
  begin
    const IsInRange = (PlainIndex < GetLength);
    if not IsInRange then
      Exit(TKeyClass.InvalidIndex);

    Index := Integer(PlainIndex);
    Exit(TKeyClass.ValidIndex);
  end;

  if IsCanonicalNumber(Name) then
    Exit(TKeyClass.InvalidIndex);

  Result := TKeyClass.NotNumeric;
end;

function TJSTypedArrayObject.IsInvalidIndexKey(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;

  Result := ClassifyKey(Name, Index) = TKeyClass.InvalidIndex;
end;

function TJSTypedArrayObject.IsElementKey(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;

  Result := ClassifyKey(Name, Index) = TKeyClass.ValidIndex;
end;

function TJSTypedArrayObject.IsNumericKey(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;

  Result := ClassifyKey(Name, Index) <> TKeyClass.NotNumeric;
end;

function TJSTypedArrayObject.CreateElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
begin
  Result := TJSPropertyDescriptor.Create(ReadElement(Index));
  Result.Writable := True;
  Result.Enumerable := True;
  Result.Configurable := True;
end;

function TJSTypedArrayObject.LookupOwn(const Name: TJSPropertyKey;
                                       out Descriptor: TJSPropertyDescriptor): TJSOwnLookup;
begin
  var Index: Integer;

  case ClassifyKey(Name, Index) of
    TKeyClass.NotNumeric  : Result := inherited LookupOwn(Name, Descriptor);
    TKeyClass.ValidIndex  :
      begin
        Descriptor := CreateElementDescriptor(Index);
        Result := TJSOwnLookup.Found;
      end;
  else
    Result := TJSOwnLookup.Absent;
  end;
end;

function TJSTypedArrayObject.GetProperty(const Name: TJSPropertyKey): TJSValue;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited GetProperty(Name));

  Result := ReadElement(Index);
end;

procedure TJSTypedArrayObject.SetProperty(const Name: TJSPropertyKey; const Value: TJSValue);
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
  begin
    inherited SetProperty(Name, Value);
    Exit;
  end;

  const Number = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
  if ClassifyKey(Name, Index) = TKeyClass.ValidIndex then
    TJSElementCodec.Write(FBuffer.Bytes, FByteOffset + (Index * FKind.ElementSize), FKind, Number);
end;

procedure TJSTypedArrayObject.DeleteProperty(const Name: TJSPropertyKey);
begin
  var Index: Integer;
  if ClassifyKey(Name, Index) = TKeyClass.NotNumeric then
    inherited DeleteProperty(Name);
end;

function TJSTypedArrayObject.IsPropertyConfigurable(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited IsPropertyConfigurable(Name));

  Result := (KeyClass <> TKeyClass.ValidIndex);
end;

function TJSTypedArrayObject.GetOwnPropertyNames: TArray<string>;
begin
  const OrdinaryNames = inherited GetOwnPropertyNames;
  const ElementCount = GetLength;
  if ElementCount = 0 then
    Exit(OrdinaryNames);

  SetLength(Result, ElementCount + Length(OrdinaryNames));
  for var Index := 0 to ElementCount - 1 do
  begin
    Result[Index] := IntToStr(Index);
  end;

  for var Position := 0 to Length(OrdinaryNames) - 1 do
  begin
    Result[ElementCount + Position] := OrdinaryNames[Position];
  end;
end;

function TJSTypedArrayObject.GetOwnPropertyDescriptor(const Name: TJSPropertyKey): TJSPropertyDescriptor;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited GetOwnPropertyDescriptor(Name));

  if KeyClass = TKeyClass.ValidIndex then
    Exit(CreateElementDescriptor(Index));

  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
end;

function TJSTypedArrayObject.HasOwnProperty(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited HasOwnProperty(Name));

  Result := (KeyClass = TKeyClass.ValidIndex);
end;

function TJSTypedArrayObject.TryAssignOwnProperty(const Name: TJSPropertyKey; const Value: TJSValue): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited TryAssignOwnProperty(Name, Value));

  SetProperty(Name, Value);
  Result := True;
end;

function TJSTypedArrayObject.DefineOwnProperty(const Name: TJSPropertyKey; const Definition: TJSPropertyDefinition): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  if KeyClass = TKeyClass.NotNumeric then
    Exit(inherited DefineOwnProperty(Name, Definition));

  if KeyClass = TKeyClass.InvalidIndex then
    Exit(False);

  const RejectsAttributes = (Definition.HasConfigurable and (not Definition.Configurable)) or
                            (Definition.HasEnumerable and (not Definition.Enumerable)) or
                            (Definition.HasWritable and (not Definition.Writable));
  if Definition.IsAccessorDefinition or RejectsAttributes then
    Exit(False);

  if Definition.HasValue then
    StoreValue(Index, Definition.Value);

  Result := True;
end;

function TJSTypedArrayObject.IsFrozen: Boolean;
begin
  if GetLength > 0 then
    Exit(False);

  Result := inherited IsFrozen;
end;

function TJSTypedArrayObject.IsSealed: Boolean;
begin
  if GetLength > 0 then
    Exit(False);

  Result := inherited IsSealed;
end;

procedure TJSTypedArrayObject.Freeze;
begin
  if GetLength > 0 then
  begin
    PreventExtensions;
    raise TJSErrorFactory.TypeError(NOT_FROZEN_ELEMENTS);
  end;

  inherited Freeze;
end;

procedure TJSTypedArrayObject.Seal;
begin
  if GetLength > 0 then
  begin
    PreventExtensions;
    raise TJSErrorFactory.TypeError(NOT_SEALED_ELEMENTS);
  end;

  inherited Seal;
end;

end.
