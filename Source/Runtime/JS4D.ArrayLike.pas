unit JS4D.ArrayLike;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Errors,
  JS4D.SymbolRegistry,
  JS4D.PropertyDescriptors,
  JS4D.ObjectOperations;

type
  TJSArrayLike = class
  private
    const
      LENGTH_PROPERTY = 'length';
      MAX_SAFE_LENGTH = 9007199254740991.0;
      MAX_SAFE_LENGTH_INTEGER = 9007199254740991;
      MAX_ARRAY_LENGTH = 4294967295;
      LENGTH_EXCEEDS_SAFE_INTEGER = 'The array length would exceed 2^53 - 1';
      CONSTRUCTOR_PROPERTY = 'constructor';
      CONSTRUCTOR_NOT_AN_OBJECT = 'The constructor property of an array must be an object or undefined';
      SPECIES_NOT_A_CONSTRUCTOR = 'The species of an array constructor must be a constructor, null or undefined';
      COMPARER_NOT_A_FUNCTION = 'The comparison function of sort must be a function or undefined';
      CANNOT_ASSIGN_PROPERTY = 'Cannot assign to read only property ''%s''';
      CANNOT_DELETE_PROPERTY = 'Cannot delete property ''%s''';

    class procedure PutProperty(const Target: IJSObject; const Name: string; const Value: TJSValue); static;
    class function SpeciesOf(const ConstructorValue: TJSValue; const SpeciesKey: TJSPropertyKey;
                             const IntrinsicSpeciesGetter: IJSFunction): TJSValue; static;

  public
    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    class function IndexName(const Index: Int64): string; static;
    class function ToNumber(const Value: TJSValue): Double; static;
    class function ToInteger(const Value: TJSValue): Double; static;
    class function ToLength(const Target: IJSObject): Int64; static;
    class function RelativeIndex(const Value: TJSValue; const Count, DefaultIndex: Int64): Int64; static;
    class function TryGetElement(const Target: IJSObject; const Index: Int64; out Element: TJSValue): Boolean; static;
    class function GetElement(const Target: IJSObject; const Index: Int64): TJSValue; static;
    class procedure SetElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue); static;
    class procedure DeleteElement(const Target: IJSObject; const Index: Int64); static;
    class procedure MoveElement(const Target: IJSObject; const FromIndex, ToIndex: Int64); static;
    class procedure WriteLength(const Target: IJSObject; const Count: Int64); static;
    class procedure RequireArrayLength(const Count: Int64); static;
    class procedure RequireSafeLength(const Count: Int64); static;
    class procedure RequireSortComparer(const Args: TArray<TJSValue>); static;
    // The constructor that creates the result of map, filter, slice, splice and concat for an array. Nil
    // means a plain array: the receiver is no array, has no constructor or uses the intrinsic Array.
    class function SpeciesConstructor(const Target: IJSObject; const IntrinsicArray: IJSFunction;
                                      const IntrinsicSpeciesGetter: IJSFunction): IJSFunction; static;
  end;

implementation

class function TJSArrayLike.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  if Position < Length(Args) then
    Result := Args[Position]
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayLike.IndexName(const Index: Int64): string;
begin
  Result := IntToStr(Index);
end;

class procedure TJSArrayLike.PutProperty(const Target: IJSObject; const Name: string; const Value: TJSValue);
begin
  if not TJSPropertyDescriptors.CanPut(Target, Name) then
    raise TJSErrorFactory.TypeError(Format(CANNOT_ASSIGN_PROPERTY, [Name]));

  Target.SetProperty(Name, Value);
end;

class function TJSArrayLike.ToNumber(const Value: TJSValue): Double;
begin
  Result := Value.ToPrimitiveWithHint(TJSPrimitiveHint.Number).ToNumber;
end;

class function TJSArrayLike.ToInteger(const Value: TJSValue): Double;
begin
  const Number = ToNumber(Value);
  if System.Math.IsNaN(Number) then
    Exit(0);

  Result := Int(Number);
end;

class function TJSArrayLike.ToLength(const Target: IJSObject): Int64;
begin
  var TargetArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, TargetArray);
  if IsArray then
    Exit(TargetArray.LogicalLength);

  const Number = ToInteger(Target.GetProperty(LENGTH_PROPERTY));
  Result := Trunc(EnsureRange(Number, 0, MAX_SAFE_LENGTH));
end;

class function TJSArrayLike.RelativeIndex(const Value: TJSValue; const Count, DefaultIndex: Int64): Int64;
begin
  if Value.IsUndefined then
    Exit(DefaultIndex);

  const Relative = ToInteger(Value);
  if Relative < 0 then
    Result := Trunc(Max(Count + Relative, 0))
  else
    Result := Trunc(Min(Relative, Count));
end;

class function TJSArrayLike.TryGetElement(const Target: IJSObject; const Index: Int64;
                                          out Element: TJSValue): Boolean;
begin
  var TargetArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, TargetArray);
  const IsOwnElement = IsArray and (Index < TargetArray.Length) and TargetArray.HasElement(Integer(Index));
  if IsOwnElement then
  begin
    Element := TargetArray[Integer(Index)];
    Exit(True);
  end;

  const Name = IndexName(Index);
  Result := Target.HasProperty(Name);
  if Result then
    Element := Target.GetProperty(Name);
end;

class function TJSArrayLike.GetElement(const Target: IJSObject; const Index: Int64): TJSValue;
begin
  var TargetArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, TargetArray);
  const IsOwnElement = IsArray and (Index < TargetArray.Length) and TargetArray.HasElement(Integer(Index));
  if IsOwnElement then
    Exit(TargetArray[Integer(Index)]);

  Result := Target.GetProperty(IndexName(Index));
end;

class procedure TJSArrayLike.SetElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue);
begin
  PutProperty(Target, IndexName(Index), Value);
end;

class procedure TJSArrayLike.DeleteElement(const Target: IJSObject; const Index: Int64);
begin
  const Name = IndexName(Index);
  const IsLocked = Target.HasOwnProperty(Name) and (not Target.IsPropertyConfigurable(Name));
  if IsLocked then
    raise TJSErrorFactory.TypeError(Format(CANNOT_DELETE_PROPERTY, [Name]));

  Target.DeleteProperty(Name);
end;

class procedure TJSArrayLike.MoveElement(const Target: IJSObject; const FromIndex, ToIndex: Int64);
begin
  var Element: TJSValue;
  if TryGetElement(Target, FromIndex, Element) then
    SetElement(Target, ToIndex, Element)
  else
    DeleteElement(Target, ToIndex);
end;

class procedure TJSArrayLike.WriteLength(const Target: IJSObject; const Count: Int64);
begin
  PutProperty(Target, LENGTH_PROPERTY, TJSValue.CreateNumber(Count));
end;

class procedure TJSArrayLike.RequireArrayLength(const Count: Int64);
begin
  if Count > MAX_ARRAY_LENGTH then
    raise TJSErrorFactory.InvalidArrayLength;
end;

class procedure TJSArrayLike.RequireSafeLength(const Count: Int64);
begin
  if Count > MAX_SAFE_LENGTH_INTEGER then
    raise TJSErrorFactory.TypeError(LENGTH_EXCEEDS_SAFE_INTEGER);
end;

class procedure TJSArrayLike.RequireSortComparer(const Args: TArray<TJSValue>);
begin
  const Comparer = Argument(Args, 0);
  const IsAcceptable = Comparer.IsUndefined or Comparer.IsFunction;
  if not IsAcceptable then
    raise TJSErrorFactory.TypeError(COMPARER_NOT_A_FUNCTION);
end;

class function TJSArrayLike.SpeciesOf(const ConstructorValue: TJSValue; const SpeciesKey: TJSPropertyKey;
                                      const IntrinsicSpeciesGetter: IJSFunction): TJSValue;
begin
  const ConstructorObject = ConstructorValue.ToObject;

  var Descriptor: TJSPropertyDescriptor;
  const IsIntrinsicGetter = Assigned(IntrinsicSpeciesGetter) and
                            ConstructorObject.TryGetPropertyDescriptor(SpeciesKey, Descriptor) and
                            Descriptor.IsAccessor and Descriptor.Getter.IsFunction and
                            ((Descriptor.Getter.ToObject as IInterface) = (IntrinsicSpeciesGetter as IInterface));
  if IsIntrinsicGetter then
    Exit(ConstructorValue);

  Result := ConstructorObject.GetProperty(SpeciesKey);
end;

class function TJSArrayLike.SpeciesConstructor(const Target: IJSObject; const IntrinsicArray: IJSFunction;
                                               const IntrinsicSpeciesGetter: IJSFunction): IJSFunction;
begin
  Result := nil;

  const IsArray = TJSObjectOperations.IsArray(TJSValue.CreateObject(Target));
  if not IsArray then
    Exit;

  const ConstructorValue = Target.GetProperty(CONSTRUCTOR_PROPERTY);
  if ConstructorValue.IsUndefined then
    Exit;

  if not ConstructorValue.IsObject then
    raise TJSErrorFactory.TypeError(CONSTRUCTOR_NOT_AN_OBJECT);

  const SpeciesKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);
  const Species = SpeciesOf(ConstructorValue, SpeciesKey, IntrinsicSpeciesGetter);
  if Species.IsNullOrUndefined then
    Exit;

  var Candidate: IJSFunction;
  const IsConstructor = Species.IsFunction and Supports(Species.ToObject, IJSFunction, Candidate) and
                        Candidate.IsConstructor;
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_CONSTRUCTOR);

  const IsIntrinsic = Assigned(IntrinsicArray) and ((Candidate as IInterface) = (IntrinsicArray as IInterface));
  if not IsIntrinsic then
    Result := Candidate;
end;

end.
