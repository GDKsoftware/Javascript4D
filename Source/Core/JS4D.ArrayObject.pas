unit JS4D.ArrayObject;

{$SCOPEDENUMS ON}

interface

uses
  System.Classes,
  System.Generics.Collections,
  JS4D.ObjectHeap,
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSArrayImpl = class(TJSObjectImpl, IJSArray)
  private
    FElements: TList<TJSValue>;
    FHoles: TBits;
    FHoleCount: Integer;
    FSparseLength: Int64;
    FLengthWritable: Boolean;

    function GetLengthDescriptor: TJSPropertyDescriptor;
    function IsLengthWritable: Boolean;
    function IsBlockedByLength(const Index: Int64): Boolean;
    function PlainElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
    function TryGetPresentElementIndex(const Name: TJSPropertyKey; out Index: Integer): Boolean;
    function TryGetElementDescriptor(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): Boolean;
    class function IsElementOrLengthKey(const Name: TJSPropertyKey): Boolean; static; inline;
    procedure SetLengthProperty(const Value: TJSValue);
    procedure SetSparseElement(const Name: TJSPropertyKey; const ElementIndex: Int64; const Value: TJSValue);
    procedure SetDenseElement(const Name: TJSPropertyKey; const Index: Integer; const Value: TJSValue);
    function DefineLength(const Definition: TJSPropertyDefinition): Boolean;
    function DefineSparseElement(const Name: TJSPropertyKey; const ElementIndex: Int64;
                                 const Definition: TJSPropertyDefinition): Boolean;
    function DefineElement(const Index: Integer; const Name: TJSPropertyKey;
                           const Definition: TJSPropertyDefinition): Boolean;
    function RedefineElement(const Index: Integer; const Name: TJSPropertyKey;
                             const Definition: TJSPropertyDefinition): Boolean;
    function AddElement(const Index: Integer; const Name: TJSPropertyKey;
                        const Definition: TJSPropertyDefinition): Boolean;
    procedure MoveToSpecialElement(const Index: Integer; const Name: TJSPropertyKey;
                                   const Descriptor: TJSPropertyDescriptor);
    procedure ForgetSpecialElement(const Index: Integer);
    procedure PushPastSparsePart(const Value: TJSValue);
    function IsLockedElement(const Index: Integer): Boolean;
    function ResizeTo(const NewLength: Int64): Boolean;
    procedure GrowLogicalLength(const NewLength: Int64);
    function ShrinkLogicalLength(const NewLength: Int64): Boolean;
    function ShrinkTo(const NewLength: Integer): Boolean;
    function ShrinkSparsePart(const NewLength: Int64): Int64;
    procedure GrowTo(const NewLength: Integer);
    function IsSparseIndex(const Index: Int64): Boolean;
    function SparseElementIndexes: TList<Int64>;
    procedure AppendSparseNames(const Names: TList<string>);
    function IsHole(const Index: Integer): Boolean; inline;
    procedure ClearHole(const Index: Integer);
    procedure MarkHoles(const FromIndex: Integer; const ToIndex: Integer);
    procedure ForgetHolesBetween(const FromIndex: Integer; const ToIndex: Integer);

  protected
    function HasStandardPropertyLookup: Boolean; override;
    function LookupOwn(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): TJSOwnLookup; override;
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;
    procedure ReleaseReferences; override;
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;
    function GetLength: Integer;
    function GetLogicalLength: Int64;
    function GetElement(const Index: Integer): TJSValue;
    procedure SetElement(const Index: Integer; const Value: TJSValue);

  public
    class function TryParseIndex(const Name: TJSPropertyKey; out Index: Integer): Boolean; static;
    class function CoerceLength(const Value: TJSValue): Int64; static;

    constructor Create;
    destructor Destroy; override;

    function GetProperty(const Name: TJSPropertyKey): TJSValue; override;
    procedure Push(const Value: TJSValue);
    function Pop: TJSValue;
    function HasElement(const Index: Integer): Boolean;
    procedure DeleteElement(const Index: Integer);
    function IsDenseAndMutable: Boolean;
    function GetEnumerator: TJSArrayElementEnumerator;

    procedure SetProperty(const Name: TJSPropertyKey; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: TJSPropertyKey); override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnPropertyDescriptor(const Name: TJSPropertyKey): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: TJSPropertyKey): Boolean; override;
    function DefineOwnProperty(const Name: TJSPropertyKey; const Definition: TJSPropertyDefinition): Boolean; override;

    property Length: Integer read GetLength;
    property LogicalLength: Int64 read GetLogicalLength;
    property Elements[const Index: Integer]: TJSValue read GetElement write SetElement; default;
  end;

  TJSArray = TJSArrayImpl;

implementation

uses
  System.SysUtils,
  JS4D.Errors;

const
  MAX_DENSE_GAP = 1024 * 1024;

{ TJSArrayImpl }

constructor TJSArrayImpl.Create;
begin
  inherited Create;
  LooksUpOwnPropertiesInMap := False;
  StoresNamedDataInSlotMap := True;
  FElements := TList<TJSValue>.Create;
  FLengthWritable := True;
end;

destructor TJSArrayImpl.Destroy;
begin
  ReleaseNestedIteratively;

  FElements.Clear;
  FreeAndNil(FElements);
  FreeAndNil(FHoles);
  inherited Destroy;
end;

class function TJSArrayImpl.TryParseIndex(const Name: TJSPropertyKey; out Index: Integer): Boolean;
begin
  var ElementIndex: Int64;
  Result := TryParseArrayIndex(Name, ElementIndex) and (ElementIndex <= MaxInt);

  if Result then
    Index := Integer(ElementIndex)
  else
    Index := 0;
end;

class function TJSArrayImpl.CoerceLength(const Value: TJSValue): Int64;
begin
  const FirstPrimitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number);
  const FirstNumber = FirstPrimitive.ToNumber;
  const IsFiniteNumber = ((not FirstNumber.IsNaN) and (not FirstNumber.IsInfinity));

  var Unsigned := 0.0;
  if IsFiniteNumber then
  begin
    const Whole = Int(FirstNumber);
    Unsigned := Whole - (Int(Whole / UINT32_RANGE) * UINT32_RANGE);
    if Unsigned < 0 then
      Unsigned := Unsigned + UINT32_RANGE;
  end;

  const SecondPrimitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number);
  const SecondNumber = SecondPrimitive.ToNumber;
  if SecondNumber <> Unsigned then
    raise TJSErrorFactory.InvalidArrayLength;

  Result := Trunc(Unsigned);
end;

function TJSArrayImpl.GetLogicalLength: Int64;
begin
  Result := FElements.Count;

  if FSparseLength > Result then
    Result := FSparseLength;
end;

function TJSArrayImpl.IsSparseIndex(const Index: Int64): Boolean;
begin
  Result := ((Index - FElements.Count) > MAX_DENSE_GAP);
end;

function TJSArrayImpl.SparseElementIndexes: TList<Int64>;
begin
  Result := TList<Int64>.Create;

  for var Position := 0 to FProperties.Count - 1 do
  begin
    const Name = FProperties.NameInInsertionOrder(Position);
    var Index: Int64;
    const IsSparseElement = (TryParseArrayIndex(Name, Index) and (Index >= FElements.Count));
    if IsSparseElement then
      Result.Add(Index);
  end;
end;

procedure TJSArrayImpl.AppendSparseNames(const Names: TList<string>);
begin
  const Indexes = SparseElementIndexes;
  try
    Indexes.Sort;

    for var Index in Indexes do
    begin
      Names.Add(IntToStr(Index));
    end;
  finally
    Indexes.Free;
  end;
end;

function TJSArrayImpl.IsLengthWritable: Boolean;
begin
  Result := (FLengthWritable and (not FFrozen));
end;

function TJSArrayImpl.IsBlockedByLength(const Index: Int64): Boolean;
begin
  Result := ((Index >= GetLogicalLength) and (not IsLengthWritable));
end;

function TJSArrayImpl.GetLengthDescriptor: TJSPropertyDescriptor;
begin
  const LengthValue = TJSValue.CreateNumber(GetLogicalLength);

  Result := TJSPropertyDescriptor.Create(LengthValue);
  Result.Writable := IsLengthWritable;
  Result.Enumerable := False;
  Result.Configurable := False;
end;

function TJSArrayImpl.PlainElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
begin
  Result := TJSPropertyDescriptor.Create(FElements[Index]);
  Result.Writable := not FFrozen;
  Result.Configurable := not FSealed;
end;

function TJSArrayImpl.TryGetPresentElementIndex(const Name: TJSPropertyKey; out Index: Integer): Boolean;
begin
  const IsElementKey = TryParseIndex(Name, Index);

  Result := (IsElementKey and HasElement(Index));
end;

function TJSArrayImpl.TryGetElementDescriptor(const Name: TJSPropertyKey;
                                              out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := False;

  const IsLengthKey = (Name = LENGTH_PROPERTY);
  if IsLengthKey then
  begin
    Descriptor := GetLengthDescriptor;
    Result := True;
    Exit;
  end;

  var Index: Integer;
  const IsPresentElement = TryGetPresentElementIndex(Name, Index);
  if not IsPresentElement then
    Exit;

  Descriptor := PlainElementDescriptor(Index);
  Result := True;
end;

function TJSArrayImpl.IsHole(const Index: Integer): Boolean;
begin
  Result := ((FHoleCount > 0) and (Index < FHoles.Size) and FHoles[Index]);
end;

procedure TJSArrayImpl.ClearHole(const Index: Integer);
begin
  if not IsHole(Index) then
    Exit;

  FHoles[Index] := False;
  Dec(FHoleCount);
end;

procedure TJSArrayImpl.MarkHoles(const FromIndex: Integer; const ToIndex: Integer);
begin
  if not Assigned(FHoles) then
    FHoles := TBits.Create;

  for var Index := FromIndex to ToIndex do
  begin
    if not IsHole(Index) then
    begin
      FHoles[Index] := True;
      Inc(FHoleCount);
    end;
  end;
end;

procedure TJSArrayImpl.ForgetHolesBetween(const FromIndex: Integer; const ToIndex: Integer);
begin
  if FHoleCount = 0 then
    Exit;

  for var Index := FromIndex to ToIndex do
  begin
    ClearHole(Index);
  end;
end;

procedure TJSArrayImpl.ForgetSpecialElement(const Index: Integer);
begin
  if FProperties.Count = 0 then
    Exit;

  const Name = IntToStr(Index);
  if FProperties.ContainsKey(Name) then
  begin
    FProperties.Remove(Name);
  end;
end;

procedure TJSArrayImpl.MoveToSpecialElement(const Index: Integer; const Name: TJSPropertyKey;
                                            const Descriptor: TJSPropertyDescriptor);
begin
  FElements[Index] := TJSValue.CreateUndefined;
  MarkHoles(Index, Index);

  AppendProperty(Name, Descriptor);
end;

function TJSArrayImpl.IsLockedElement(const Index: Integer): Boolean;
begin
  if HasElement(Index) then
    Exit(FSealed);

  var Descriptor: TJSPropertyDescriptor;
  const IsSpecial = ((FProperties.Count > 0) and FProperties.TryGetValue(IntToStr(Index), Descriptor));
  Result := (IsSpecial and (not Descriptor.Configurable));
end;

procedure TJSArrayImpl.GrowTo(const NewLength: Integer);
begin
  const OldLength = FElements.Count;

  while FElements.Count < NewLength do
  begin
    FElements.Add(TJSValue.CreateUndefined);
  end;

  if NewLength > OldLength then
    MarkHoles(OldLength, NewLength - 1);
end;

function TJSArrayImpl.ShrinkTo(const NewLength: Integer): Boolean;
begin
  const OldLength = FElements.Count;
  var KeptLength := NewLength;

  const MayBeLocked = (FSealed or (FProperties.Count > 0));
  if MayBeLocked then
  begin
    for var Index := OldLength - 1 downto NewLength do
    begin
      if IsLockedElement(Index) then
      begin
        KeptLength := Index + 1;
        Break;
      end;

      ForgetSpecialElement(Index);
    end;
  end;

  while FElements.Count > KeptLength do
  begin
    FElements.Delete(FElements.Count - 1);
  end;

  ForgetHolesBetween(KeptLength, OldLength - 1);

  Result := (KeptLength = NewLength);
end;

function TJSArrayImpl.ShrinkSparsePart(const NewLength: Int64): Int64;
begin
  Result := NewLength;

  const Indexes = SparseElementIndexes;
  try
    Indexes.Sort;

    for var Position := Indexes.Count - 1 downto 0 do
    begin
      const Index = Indexes[Position];
      if Index < NewLength then
        Break;

      const Name = IntToStr(Index);
      if not FProperties[Name].Configurable then
        Exit(Index + 1);

      RemoveProperty(Name);
    end;
  finally
    Indexes.Free;
  end;
end;

function TJSArrayImpl.ResizeTo(const NewLength: Int64): Boolean;
begin
  Result := True;

  const OldLength = GetLogicalLength;
  if NewLength = OldLength then
    Exit;

  if NewLength > OldLength then
    GrowLogicalLength(NewLength)
  else
    Result := ShrinkLogicalLength(NewLength);
end;

procedure TJSArrayImpl.GrowLogicalLength(const NewLength: Int64);
begin
  if IsSparseIndex(NewLength) then
    FSparseLength := NewLength
  else
    GrowTo(Integer(NewLength));
end;

function TJSArrayImpl.ShrinkLogicalLength(const NewLength: Int64): Boolean;
begin
  var KeptLength := NewLength;
  const HasSparsePart = (FSparseLength > FElements.Count);
  if HasSparsePart then
    KeptLength := ShrinkSparsePart(NewLength);

  const IsFullyResized = (KeptLength = NewLength);
  const StaysSparse = (KeptLength > FElements.Count);
  if StaysSparse then
  begin
    FSparseLength := KeptLength;
    Result := IsFullyResized;
    Exit;
  end;

  FSparseLength := 0;
  const IsDenseShrunk = ShrinkTo(Integer(KeptLength));
  Result := (IsDenseShrunk and IsFullyResized);
end;

function TJSArrayImpl.GetOwnPropertyDescriptor(const Name: TJSPropertyKey): TJSPropertyDescriptor;
begin
  var Index: Integer;
  const IsLengthKey = (Name = LENGTH_PROPERTY);

  if IsLengthKey then
    Result := GetLengthDescriptor
  else if TryGetPresentElementIndex(Name, Index) then
    Result := PlainElementDescriptor(Index)
  else
    Result := inherited GetOwnPropertyDescriptor(Name);
end;

function TJSArrayImpl.HasOwnProperty(const Name: TJSPropertyKey): Boolean;
begin
  var Index: Integer;
  const IsLengthKey = (Name = LENGTH_PROPERTY);

  Result := (IsLengthKey or TryGetPresentElementIndex(Name, Index) or inherited HasOwnProperty(Name));
end;

function TJSArrayImpl.GetOwnPropertyNames: TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    const HasSpecialElements = (FProperties.Count > 0);

    for var Index := 0 to FElements.Count - 1 do
    begin
      const Name = IntToStr(Index);
      const IsOwnElement = (HasElement(Index) or (HasSpecialElements and FProperties.ContainsKey(Name)));
      if IsOwnElement then
        Names.Add(Name);
    end;

    if FSparseLength > FElements.Count then
      AppendSparseNames(Names);

    Names.Add(LENGTH_PROPERTY);

    for var Key in inherited GetOwnPropertyNames do
    begin
      var Index: Int64;
      if not TryParseArrayIndex(Key, Index) then
        Names.Add(Key);
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

function TJSArrayImpl.LookupOwn(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): TJSOwnLookup;
begin
  if TryGetElementDescriptor(Name, Descriptor) then
    Exit(TJSOwnLookup.Found);

  Result := inherited LookupOwn(Name, Descriptor);
end;

function TJSArrayImpl.HasStandardPropertyLookup: Boolean;
begin
  Result := False;
end;

class function TJSArrayImpl.IsElementOrLengthKey(const Name: TJSPropertyKey): Boolean;
begin
  const IsEmptyKey = (Name.Stored = '');
  const IsLengthKey = (Name = LENGTH_PROPERTY);

  Result := (IsEmptyKey or TJSPropertyKey.CanStartNumber(Name.Stored) or IsLengthKey);
end;

function TJSArrayImpl.GetProperty(const Name: TJSPropertyKey): TJSValue;
begin
  if (not IsElementOrLengthKey(Name)) and TryReadDataPropertyBySlots(Name, Result) then
    Exit;

  Result := inherited GetProperty(Name);
end;

procedure TJSArrayImpl.SetProperty(const Name: TJSPropertyKey; const Value: TJSValue);
begin
  const IsLengthKey = (Name = LENGTH_PROPERTY);
  if IsLengthKey then
  begin
    SetLengthProperty(Value);
    Exit;
  end;

  var ElementIndex: Int64;
  const IsElementKey = TryParseArrayIndex(Name, ElementIndex);
  if not IsElementKey then
  begin
    inherited SetProperty(Name, Value);
    Exit;
  end;

  if IsSparseIndex(ElementIndex) then
    SetSparseElement(Name, ElementIndex, Value)
  else
    SetDenseElement(Name, Integer(ElementIndex), Value);
end;

procedure TJSArrayImpl.SetLengthProperty(const Value: TJSValue);
begin
  if not IsLengthWritable then
    Exit;

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Value;
  DefineLength(Definition);
end;

procedure TJSArrayImpl.SetSparseElement(const Name: TJSPropertyKey; const ElementIndex: Int64;
                                        const Value: TJSValue);
begin
  if IsBlockedByLength(ElementIndex) then
    Exit;

  inherited SetProperty(Name, Value);

  const IsStored = FProperties.ContainsKey(Name.Stored);
  const ExtendsLength = (ElementIndex >= GetLogicalLength);
  if IsStored and ExtendsLength then
    FSparseLength := ElementIndex + 1;
end;

procedure TJSArrayImpl.SetDenseElement(const Name: TJSPropertyKey; const Index: Integer; const Value: TJSValue);
begin
  if HasElement(Index) then
  begin
    if not FFrozen then
      FElements[Index] := Value;

    Exit;
  end;

  if IsBlockedByLength(Index) then
    Exit;

  const IsSpecialElement = FProperties.ContainsKey(Name.Stored);
  inherited SetProperty(Name, Value);

  const WasAddedAsDataProperty = ((not IsSpecialElement) and FProperties.ContainsKey(Name.Stored));
  if WasAddedAsDataProperty then
  begin
    FProperties.Remove(Name.Stored);
    SetElement(Index, Value);
  end;
end;

procedure TJSArrayImpl.DeleteProperty(const Name: TJSPropertyKey);
begin
  var Index: Integer;
  const IsPlainElement = TryGetPresentElementIndex(Name, Index);

  if IsPlainElement then
  begin
    if not FSealed then
      DeleteElement(Index);

    Exit;
  end;

  inherited DeleteProperty(Name);
end;

function TJSArrayImpl.DefineLength(const Definition: TJSPropertyDefinition): Boolean;
begin
  var NewLength: Int64 := 0;
  var Coerced := Definition;

  if Definition.HasValue then
  begin
    NewLength := CoerceLength(Definition.Value);
    Coerced.Value := TJSValue.CreateNumber(NewLength);
  end;

  const Current = GetLengthDescriptor;
  Result := CanRedefine(Current, Coerced);
  if not Result then
    Exit;

  if Definition.HasValue then
    Result := ResizeTo(NewLength);

  if Definition.HasWritable then
    FLengthWritable := Definition.Writable;
end;

function TJSArrayImpl.DefineOwnProperty(const Name: TJSPropertyKey; const Definition: TJSPropertyDefinition): Boolean;
begin
  const IsLengthKey = (Name = LENGTH_PROPERTY);
  if IsLengthKey then
  begin
    Result := DefineLength(Definition);
    Exit;
  end;

  var ElementIndex: Int64;
  const IsElementKey = TryParseArrayIndex(Name, ElementIndex);
  if not IsElementKey then
  begin
    Result := inherited DefineOwnProperty(Name, Definition);
    Exit;
  end;

  if IsSparseIndex(ElementIndex) then
    Result := DefineSparseElement(Name, ElementIndex, Definition)
  else
    Result := DefineElement(Integer(ElementIndex), Name, Definition);
end;

function TJSArrayImpl.DefineSparseElement(const Name: TJSPropertyKey; const ElementIndex: Int64;
                                          const Definition: TJSPropertyDefinition): Boolean;
begin
  if IsBlockedByLength(ElementIndex) then
    Exit(False);

  Result := inherited DefineOwnProperty(Name, Definition);

  const ExtendsLength = (ElementIndex >= GetLogicalLength);
  if Result and ExtendsLength then
    FSparseLength := ElementIndex + 1;
end;

function TJSArrayImpl.DefineElement(const Index: Integer; const Name: TJSPropertyKey;
                                    const Definition: TJSPropertyDefinition): Boolean;
begin
  if IsBlockedByLength(Index) then
    Exit(False);

  if HasElement(Index) then
    Result := RedefineElement(Index, Name, Definition)
  else if FProperties.ContainsKey(Name.Stored) then
    Result := inherited DefineOwnProperty(Name, Definition)
  else
    Result := AddElement(Index, Name, Definition);

  if Result and (Index >= FElements.Count) then
    GrowTo(Index + 1);
end;

function TJSArrayImpl.RedefineElement(const Index: Integer; const Name: TJSPropertyKey;
                                      const Definition: TJSPropertyDefinition): Boolean;
begin
  const Current = PlainElementDescriptor(Index);
  Result := CanRedefine(Current, Definition);
  if not Result then
    Exit;

  const Updated = ApplyDefinition(Current, Definition);
  if Updated.IsPlainData then
    FElements[Index] := Updated.Value
  else
    MoveToSpecialElement(Index, Name, Updated);
end;

function TJSArrayImpl.AddElement(const Index: Integer; const Name: TJSPropertyKey;
                                 const Definition: TJSPropertyDefinition): Boolean;
begin
  if not FExtensible then
    Exit(False);

  if not Definition.IsPlainData then
  begin
    Result := AddDefinedProperty(Name, Definition);
    Exit;
  end;

  SetElement(Index, Definition.Value);
  Result := True;
end;

function TJSArrayImpl.HoldsNested: Boolean;
begin
  Result := inherited HoldsNested;

  if Result or (not Assigned(FElements)) then
    Exit;

  for var Element in FElements do
  begin
    if Element.IsNonFunctionObject then
      Exit(True);
  end;
end;

procedure TJSArrayImpl.DetachNested(const Pending: TList<IJSObject>);
begin
  if Assigned(FElements) then
  begin
    for var Element in FElements do
    begin
      if Element.IsNonFunctionObject then
        Pending.Add(Element.ToObject);
    end;

    FElements.Clear;
  end;

  inherited DetachNested(Pending);
end;

procedure TJSArrayImpl.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
  inherited EnumerateHeapReferences(Visit);

  for var Element in FElements do
  begin
    ReportValue(Visit, Element);
  end;
end;

procedure TJSArrayImpl.ReleaseReferences;
begin
  inherited ReleaseReferences;

  FElements.Clear;
  FSparseLength := 0;
  FHoleCount := 0;

  if Assigned(FHoles) then
    FHoles.Size := 0;
end;

function TJSArrayImpl.GetEnumerator: TJSArrayElementEnumerator;
begin
  Result := TJSArrayElementEnumerator.Create(Self);
end;

function TJSArrayImpl.GetLength: Integer;
begin
  Result := FElements.Count;
end;

function TJSArrayImpl.GetElement(const Index: Integer): TJSValue;
begin
  if (Index >= 0) and (Index < FElements.Count) then
    Result := FElements[Index]
  else
    Result := TJSValue.CreateUndefined;
end;

procedure TJSArrayImpl.SetElement(const Index: Integer; const Value: TJSValue);
begin
  const OldLength = FElements.Count;

  while FElements.Count <= Index do
  begin
    FElements.Add(TJSValue.CreateUndefined);
  end;

  if Index > OldLength then
    MarkHoles(OldLength, Index - 1);

  ClearHole(Index);

  ForgetSpecialElement(Index);
  FElements[Index] := Value;
end;

function TJSArrayImpl.HasElement(const Index: Integer): Boolean;
begin
  const InRange = ((Index >= 0) and (Index < FElements.Count));

  Result := (InRange and (not IsHole(Index)));
end;

function TJSArrayImpl.IsDenseAndMutable: Boolean;
begin
  const HasHoles = ((FHoleCount > 0) or (FSparseLength > FElements.Count));
  const IsLocked = (FFrozen or FSealed or (not FExtensible) or (not FLengthWritable));

  Result := not (HasHoles or IsLocked);
end;

procedure TJSArrayImpl.DeleteElement(const Index: Integer);
begin
  const InRange = ((Index >= 0) and (Index < FElements.Count));
  if not InRange then
    Exit;

  FElements[Index] := TJSValue.CreateUndefined;
  MarkHoles(Index, Index);
end;

procedure TJSArrayImpl.PushPastSparsePart(const Value: TJSValue);
begin
  const IndexKey: TJSPropertyKey = IntToStr(FSparseLength);
  SetProperty(IndexKey, Value);
end;

procedure TJSArrayImpl.Push(const Value: TJSValue);
begin
  const HasSparsePart = (FSparseLength > FElements.Count);
  if HasSparsePart then
  begin
    PushPastSparsePart(Value);
    Exit;
  end;

  FElements.Add(Value);
end;

function TJSArrayImpl.Pop: TJSValue;
begin
  if FElements.Count > 0 then
  begin
    Result := FElements[FElements.Count - 1];
    ForgetSpecialElement(FElements.Count - 1);
    FElements.Delete(FElements.Count - 1);
    ForgetHolesBetween(FElements.Count, FElements.Count);
  end
  else
  begin
    Result := TJSValue.CreateUndefined;
  end;
end;

end.
