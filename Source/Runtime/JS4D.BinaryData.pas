unit JS4D.BinaryData;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.ObjectHeap,
  JS4D.Types;

const
  MAX_ELEMENT_SIZE = 8;

type
  TElementBytes = array[0..MAX_ELEMENT_SIZE - 1] of Byte;

  TJSElementKind = (Int8, Uint8, Uint8Clamped, Int16, Uint16, Int32, Uint32, Float32, Float64);

  TJSElementKindHelper = record helper for TJSElementKind
    function ElementSize: Integer;
    function ConstructorName: string;
    function TypeName: string;
  end;

  TJSElementCodec = class
  private
    class function ToModular(const Value: Double): UInt32; static;
    class function ToClamped(const Value: Double): Byte; static;
    class function OrderedBytes(const Raw: TElementBytes; const Size: Integer;
                                const IsLittleEndian: Boolean): TElementBytes; static;

  public
    class function Read(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                        const IsLittleEndian: Boolean = True): Double; static;
    class procedure Write(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                          const Value: Double; const IsLittleEndian: Boolean = True); static;
    class procedure CopyElements(const SourceBytes: TBytes; const SourceStart: Integer;
                                 const SourceKind: TJSElementKind; const TargetBytes: TBytes;
                                 const TargetStart: Integer; const TargetKind: TJSElementKind;
                                 const ElementCount: Integer); static;
  end;

  IJSArrayBuffer = interface(IJSObject)
    ['{5A7C3E19-B2D4-4F86-9E01-C8A6D3B7F254}']
    function GetBytes: TBytes;
    function GetByteLength: Integer;
    function GetIsDetached: Boolean;
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
    function GetRetainedByteOffset: Integer;
    function GetLength: Integer;
    function GetIsDetached: Boolean;
    function ReadElement(const Index: Integer): TJSValue;
    procedure StoreConvertedValue(const Index: Integer; const Value: TJSValue);
    function IsElementKey(const Name: TJSPropertyKey): Boolean;
    function IsNumericKey(const Name: TJSPropertyKey): Boolean;
    property Kind: TJSElementKind read GetKind;
    property Buffer: IJSArrayBuffer read GetBuffer;
    property ByteOffset: Integer read GetByteOffset;
    property RetainedByteOffset: Integer read GetRetainedByteOffset;
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

  TJSBinaryKeys = class
  public
    class function TryStoreElement(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                   const Receiver: TJSValue): Boolean; static;
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

    class function TryParsePlainIndex(const Name: string; out Index: Int64): Boolean; static;
    class function IsCanonicalNumber(const Name: string): Boolean; static;
    function ClassifyKey(const Key: TJSPropertyKey; out Index: Integer): TKeyClass;
    function KeyClassOf(const Key: TJSPropertyKey): TKeyClass;
    function IsValidIndex(const Index: Integer): Boolean;
    function ElementOffset(const Index: Integer): Integer;
    function IsInvalidIndexKey(const Name: TJSPropertyKey): Boolean;
    function CreateElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
    function GetKind: TJSElementKind;
    function GetBuffer: IJSArrayBuffer;
    function GetByteOffset: Integer;
    function GetRetainedByteOffset: Integer;
    function GetLength: Integer;
    function GetIsDetached: Boolean;

  protected
    function LookupOwn(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): TJSOwnLookup; override;
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;

  public
    constructor Create(const Kind: TJSElementKind; const Buffer: IJSArrayBuffer; const ByteOffset: Integer;
                       const Length: Integer);

    function ReadElement(const Index: Integer): TJSValue;
    procedure StoreConvertedValue(const Index: Integer; const Value: TJSValue);
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
  JS4D.ObjectOperations,
  JS4D.Conversions,
  JS4D.Errors;

const
  BYTE_MAX = 255;
  HALF = 0.5;
  UNSUPPORTED_ELEMENT_KIND = 'Unsupported element kind: %d';
  ELEMENT_BYTES_OUT_OF_RANGE = 'Element bytes are outside the buffer';
  ZERO_DIGIT = '0';
  ARRAY_NAME_SUFFIX = 'Array';
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

function TJSElementKindHelper.TypeName: string;
begin
  const FullName = ConstructorName;

  Result := Copy(FullName, 1, Length(FullName) - Length(ARRAY_NAME_SUFFIX));
end;

{ TJSElementCodec }

class function TJSElementCodec.ToModular(const Value: Double): UInt32;
begin
  const IsFinite = (not IsNaN(Value)) and (not IsInfinite(Value));
  if not IsFinite then
    Exit(0);

  const Whole = Int(Value);
  var Remainder := Whole - (Int(Whole / UINT32_RANGE) * UINT32_RANGE);
  const IsNegativeRemainder = (Remainder < 0);
  if IsNegativeRemainder then
    Remainder := Remainder + UINT32_RANGE;

  Result := UInt32(Trunc(Remainder) and $FFFFFFFF);
end;

class function TJSElementCodec.ToClamped(const Value: Double): Byte;
begin
  const IsNotPositive = (IsNaN(Value) or (Value <= 0));
  if IsNotPositive then
    Exit(0);

  const IsAboveMaximum = (Value >= BYTE_MAX);
  if IsAboveMaximum then
    Exit(BYTE_MAX);

  const Lower = Floor(Value);
  const Difference = Value - Lower;
  const IsLowerEven = (Trunc(Lower) mod 2) = 0;

  const RoundsDown = (Difference < HALF) or ((Difference = HALF) and IsLowerEven);
  if RoundsDown then
    Result := Byte(Trunc(Lower))
  else
    Result := Byte(Trunc(Lower) + 1);
end;

class function TJSElementCodec.OrderedBytes(const Raw: TElementBytes; const Size: Integer;
                                            const IsLittleEndian: Boolean): TElementBytes;
begin
  Result := Raw;
  if IsLittleEndian then
    Exit;

  for var Index := 0 to Size - 1 do
  begin
    Result[Index] := Raw[Size - 1 - Index];
  end;
end;

class function TJSElementCodec.Read(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                                    const IsLittleEndian: Boolean): Double;
begin
  const Size = Kind.ElementSize;
  const FitsInBuffer = (Offset >= 0) and (Offset + Size <= Length(Bytes));
  if not FitsInBuffer then
    raise TJSErrorFactory.RangeError(ELEMENT_BYTES_OUT_OF_RANGE);

  var Stored: TElementBytes;
  Move(Bytes[Offset], Stored[0], Size);
  const Raw = OrderedBytes(Stored, Size, IsLittleEndian);

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
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_ELEMENT_KIND, [Ord(Kind)]);
  end;
end;

class procedure TJSElementCodec.Write(const Bytes: TBytes; const Offset: Integer; const Kind: TJSElementKind;
                                      const Value: Double; const IsLittleEndian: Boolean);
begin
  const Size = Kind.ElementSize;
  const FitsInBuffer = (Offset >= 0) and (Offset + Size <= Length(Bytes));
  if not FitsInBuffer then
    raise TJSErrorFactory.RangeError(ELEMENT_BYTES_OUT_OF_RANGE);

  var Raw: TElementBytes;
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
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_ELEMENT_KIND, [Ord(Kind)]);
  end;

  const Ordered = OrderedBytes(Raw, Size, IsLittleEndian);
  Move(Ordered[0], Bytes[Offset], Size);
end;

class procedure TJSElementCodec.CopyElements(const SourceBytes: TBytes; const SourceStart: Integer;
                                             const SourceKind: TJSElementKind; const TargetBytes: TBytes;
                                             const TargetStart: Integer; const TargetKind: TJSElementKind;
                                             const ElementCount: Integer);
begin
  const HasElements = (ElementCount > 0);
  if not HasElements then
    Exit;

  const SourceSize = SourceKind.ElementSize;
  const TargetSize = TargetKind.ElementSize;

  const IsSameKind = (SourceKind = TargetKind);
  if IsSameKind then
  begin
    Move(SourceBytes[SourceStart], TargetBytes[TargetStart], ElementCount * SourceSize);
    Exit;
  end;

  for var Index := 0 to ElementCount - 1 do
  begin
    const Number = Read(SourceBytes, SourceStart + (Index * SourceSize), SourceKind);
    Write(TargetBytes, TargetStart + (Index * TargetSize), TargetKind, Number);
  end;
end;

{ TJSBinaryKeys }

class function TJSBinaryKeys.TryStoreElement(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                             const Receiver: TJSValue): Boolean;
begin
  var TypedArray: IJSTypedArray;
  const IsNumeric = Supports(Target, IJSTypedArray, TypedArray) and TypedArray.IsNumericKey(Name);
  if not IsNumeric then
    Exit(False);

  const IsReceiver = Receiver.IsObject and TJSObjectOperations.IsSameObject(Receiver.ToObject, Target);
  if IsReceiver then
  begin
    Target.SetProperty(Name, Value);
    Result := True;
    Exit;
  end;

  Result := not TypedArray.IsElementKey(Name);
end;

class function TJSBinaryKeys.IsElementKey(const Target: IJSObject; const Name: TJSPropertyKey): Boolean;
begin
  var TypedArray: IJSTypedArray;

  Result := (Supports(Target, IJSTypedArray, TypedArray) and TypedArray.IsElementKey(Name));
end;

{ TJSArrayBufferObject }

constructor TJSArrayBufferObject.Create(const ByteLength: Integer);
begin
  inherited Create;

  SetLength(FData, ByteLength);
  const HasBytes = (ByteLength > 0);
  if HasBytes then
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
  LooksUpOwnPropertiesInMap := False;

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

function TJSTypedArrayObject.GetRetainedByteOffset: Integer;
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
  if not IsValidIndex(Index) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  const Offset = ElementOffset(Index);
  const Number = TJSElementCodec.Read(FBuffer.Bytes, Offset, FKind);

  Result := TJSValue.CreateNumber(Number);
end;

procedure TJSTypedArrayObject.StoreConvertedValue(const Index: Integer; const Value: TJSValue);
begin
  const Number = TJSConversions.ToNumber(Value);

  if IsValidIndex(Index) then
  begin
    const Offset = ElementOffset(Index);
    TJSElementCodec.Write(FBuffer.Bytes, Offset, FKind, Number);
  end;
end;

class function TJSTypedArrayObject.TryParsePlainIndex(const Name: string; out Index: Int64): Boolean;
begin
  Index := 0;

  const NameLength = Length(Name);
  const HasValidLength = (NameLength > 0) and (NameLength <= MAX_PLAIN_DIGITS);
  const HasLeadingZero = (NameLength > 1) and (Name[1] = ZERO_DIGIT);
  if (not HasValidLength) or HasLeadingZero then
    Exit(False);

  for var Character in Name do
  begin
    const Digit = Ord(Character) - Ord(ZERO_DIGIT);
    const IsDigit = (Digit >= 0) and (Digit <= 9);
    if not IsDigit then
      Exit(False);

    Index := (Index * 10) + Digit;
  end;

  Result := True;
end;

class function TJSTypedArrayObject.IsCanonicalNumber(const Name: string): Boolean;
begin
  const CanStartNumber = TJSPropertyKey.CanStartNumber(Name);
  if not CanStartNumber then
    Exit(False);

  const IsNegativeZero = (Name = '-0');
  if IsNegativeZero then
    Exit(True);

  const Number = TJSValue.CreateString(Name).ToNumber;
  const NumberText = TJSValue.CreateNumber(Number).ToString;
  Result := (NumberText = Name);
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

  const IsOtherNumber = IsCanonicalNumber(Name);
  if IsOtherNumber then
    Exit(TKeyClass.InvalidIndex);

  Result := TKeyClass.NotNumeric;
end;

function TJSTypedArrayObject.KeyClassOf(const Key: TJSPropertyKey): TKeyClass;
begin
  var Index: Integer;

  Result := ClassifyKey(Key, Index);
end;

function TJSTypedArrayObject.IsValidIndex(const Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index < GetLength);
end;

function TJSTypedArrayObject.ElementOffset(const Index: Integer): Integer;
begin
  Result := FByteOffset + (Index * FKind.ElementSize);
end;

function TJSTypedArrayObject.IsInvalidIndexKey(const Name: TJSPropertyKey): Boolean;
begin
  Result := (KeyClassOf(Name) = TKeyClass.InvalidIndex);
end;

function TJSTypedArrayObject.IsElementKey(const Name: TJSPropertyKey): Boolean;
begin
  Result := (KeyClassOf(Name) = TKeyClass.ValidIndex);
end;

function TJSTypedArrayObject.IsNumericKey(const Name: TJSPropertyKey): Boolean;
begin
  Result := (KeyClassOf(Name) <> TKeyClass.NotNumeric);
end;

function TJSTypedArrayObject.CreateElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
begin
  const Element = ReadElement(Index);

  Result := TJSPropertyDescriptor.Create(Element);
  Result.Writable := True;
  Result.Enumerable := True;
  Result.Configurable := True;
end;

function TJSTypedArrayObject.LookupOwn(const Name: TJSPropertyKey;
                                       out Descriptor: TJSPropertyDescriptor): TJSOwnLookup;
begin
  var Index: Integer;

  const KeyClass = ClassifyKey(Name, Index);

  case KeyClass of
    TKeyClass.NotNumeric:
      begin
        Result := inherited LookupOwn(Name, Descriptor);
      end;
    TKeyClass.ValidIndex:
      begin
        Descriptor := CreateElementDescriptor(Index);
        Result := TJSOwnLookup.Found;
      end;
  else
    Result := TJSOwnLookup.NotFoundInChain;
  end;
end;

function TJSTypedArrayObject.GetProperty(const Name: TJSPropertyKey): TJSValue;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited GetProperty(Name);
    Exit;
  end;

  Result := ReadElement(Index);
end;

procedure TJSTypedArrayObject.SetProperty(const Name: TJSPropertyKey; const Value: TJSValue);
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    inherited SetProperty(Name, Value);
    Exit;
  end;

  const Number = TJSConversions.ToNumber(Value);
  const KeyClassAfterConversion = ClassifyKey(Name, Index);
  const IsStillValid = (KeyClassAfterConversion = TKeyClass.ValidIndex);
  if IsStillValid then
  begin
    const Offset = ElementOffset(Index);
    TJSElementCodec.Write(FBuffer.Bytes, Offset, FKind, Number);
  end;
end;

procedure TJSTypedArrayObject.DeleteProperty(const Name: TJSPropertyKey);
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
    inherited DeleteProperty(Name);
end;

function TJSTypedArrayObject.IsPropertyConfigurable(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited IsPropertyConfigurable(Name);
    Exit;
  end;

  Result := (KeyClass <> TKeyClass.ValidIndex);
end;

function TJSTypedArrayObject.GetOwnPropertyNames: TArray<string>;
begin
  const OrdinaryNames = inherited GetOwnPropertyNames;
  const ElementCount = GetLength;
  const HasNoElements = (ElementCount = 0);
  if HasNoElements then
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
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited GetOwnPropertyDescriptor(Name);
    Exit;
  end;

  const IsValidIndex = (KeyClass = TKeyClass.ValidIndex);
  if IsValidIndex then
  begin
    Result := CreateElementDescriptor(Index);
    Exit;
  end;

  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
end;

function TJSTypedArrayObject.HasOwnProperty(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited HasOwnProperty(Name);
    Exit;
  end;

  Result := (KeyClass = TKeyClass.ValidIndex);
end;

function TJSTypedArrayObject.TryAssignOwnProperty(const Name: TJSPropertyKey; const Value: TJSValue): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited TryAssignOwnProperty(Name, Value);
    Exit;
  end;

  SetProperty(Name, Value);
  Result := True;
end;

function TJSTypedArrayObject.DefineOwnProperty(const Name: TJSPropertyKey;
                                               const Definition: TJSPropertyDefinition): Boolean;
begin
  var Index: Integer;
  const KeyClass = ClassifyKey(Name, Index);
  const IsOrdinaryKey = (KeyClass = TKeyClass.NotNumeric);
  if IsOrdinaryKey then
  begin
    Result := inherited DefineOwnProperty(Name, Definition);
    Exit;
  end;

  const IsInvalidIndex = (KeyClass = TKeyClass.InvalidIndex);
  if IsInvalidIndex then
    Exit(False);

  const RejectsAttributes = (Definition.HasConfigurable and (not Definition.Configurable)) or
                            (Definition.HasEnumerable and (not Definition.Enumerable)) or
                            (Definition.HasWritable and (not Definition.Writable));
  if Definition.IsAccessorDefinition or RejectsAttributes then
    Exit(False);

  if Definition.HasValue then
    StoreConvertedValue(Index, Definition.Value);

  Result := True;
end;

function TJSTypedArrayObject.IsFrozen: Boolean;
begin
  const HasElements = (GetLength > 0);
  if HasElements then
    Exit(False);

  Result := inherited IsFrozen;
end;

function TJSTypedArrayObject.IsSealed: Boolean;
begin
  const HasElements = (GetLength > 0);
  if HasElements then
    Exit(False);

  Result := inherited IsSealed;
end;

procedure TJSTypedArrayObject.Freeze;
begin
  const HasElements = (GetLength > 0);
  if HasElements then
  begin
    PreventExtensions;
    raise TJSErrorFactory.TypeError(NOT_FROZEN_ELEMENTS);
  end;

  inherited Freeze;
end;

procedure TJSTypedArrayObject.Seal;
begin
  const HasElements = (GetLength > 0);
  if HasElements then
  begin
    PreventExtensions;
    raise TJSErrorFactory.TypeError(NOT_SEALED_ELEMENTS);
  end;

  inherited Seal;
end;

end.
