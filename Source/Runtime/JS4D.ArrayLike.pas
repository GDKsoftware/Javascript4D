unit JS4D.ArrayLike;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.Errors,
  JS4D.SymbolRegistry,
  JS4D.PropertyDescriptors,
  JS4D.ObjectOperations;

type
  TJSArrayLike = class
  private
    const
      LENGTH_EXCEEDS_SAFE_INTEGER = 'The array length would exceed 2^53 - 1';
      COMPARER_NOT_A_FUNCTION = 'The comparison function of sort must be a function or undefined';
      CANNOT_DELETE_PROPERTY = 'Cannot delete property ''%s''';

    class function TryGetOwnArrayElement(const Target: IJSObject; const Index: Int64;
                                         out Element: TJSValue): Boolean; static;

  public
    class function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue; static;
    class function IndexName(const Index: Int64): string; static;
    class function CreateArray(const ArrayPrototype: IJSObject; const Items: TArray<TJSValue>): TJSValue; static;
    class function ToLength(const Target: IJSObject): Int64; static;
    class function RelativeIndex(const Value: TJSValue; const Count, DefaultIndex: Int64): Int64; static;
    class function RelativeIndexArgument(const Args: TArray<TJSValue>; const Position: Integer;
                                         const Count, DefaultIndex: Int64): Int64; static;
    class function ToIntegerArgument(const Args: TArray<TJSValue>; const Position: Integer): Double; static;
    class function ResolveRelative(const Relative: Double; const Count: Int64): Int64; static;
    class function SpliceDeleteCount(const Args: TArray<TJSValue>; const Count, Start: Int64): Int64; static;
    class function TryGetElement(const Target: IJSObject; const Index: Int64; out Element: TJSValue): Boolean; static;
    class function GetElement(const Target: IJSObject; const Index: Int64): TJSValue; static;
    class procedure SetElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue); static;
    class procedure DeleteElement(const Target: IJSObject; const Index: Int64); static;
    class procedure MoveElement(const Target: IJSObject; const FromIndex, ToIndex: Int64); static;
    class procedure WriteLength(const Target: IJSObject; const Count: Int64); static;
    class procedure RequireArrayLength(const Count: Int64); static;
    class procedure RequireSafeLength(const Count: Int64); static;
    class procedure RequireSortComparer(const Args: TArray<TJSValue>); static;
    class function CustomSpeciesConstructor(const Target: IJSObject; const IntrinsicArray: IJSFunction;
                                      const IntrinsicSpeciesGetter: IJSFunction): IJSFunction; static;
  end;

implementation

uses
  JS4D.Conversions;

class function TJSArrayLike.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  const HasArgument = (Position < Length(Args));
  if HasArgument then
    Result := Args[Position]
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSArrayLike.CreateArray(const ArrayPrototype: IJSObject; const Items: TArray<TJSValue>): TJSValue;
begin
  const List: IJSArray = TJSArray.Create;
  List.Prototype := ArrayPrototype;

  for var Item in Items do
  begin
    List.Push(Item);
  end;

  Result := TJSValue.CreateObject(List);
end;

class function TJSArrayLike.IndexName(const Index: Int64): string;
begin
  Result := IntToStr(Index);
end;

class function TJSArrayLike.ToLength(const Target: IJSObject): Int64;
begin
  var TargetArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, TargetArray);
  if IsArray then
    Exit(TargetArray.LogicalLength);

  const Number = TJSConversions.ToIntegerOrInfinity(Target.GetProperty(LENGTH_PROPERTY));
  Result := Trunc(EnsureRange(Number, 0, MAX_SAFE_INTEGER));
end;

class function TJSArrayLike.RelativeIndex(const Value: TJSValue; const Count, DefaultIndex: Int64): Int64;
begin
  if Value.IsUndefined then
    Exit(DefaultIndex);

  const Relative = TJSConversions.ToIntegerOrInfinity(Value);

  Result := ResolveRelative(Relative, Count);
end;

class function TJSArrayLike.RelativeIndexArgument(const Args: TArray<TJSValue>; const Position: Integer;
                                                  const Count, DefaultIndex: Int64): Int64;
begin
  const Value = Argument(Args, Position);

  Result := RelativeIndex(Value, Count, DefaultIndex);
end;

class function TJSArrayLike.ToIntegerArgument(const Args: TArray<TJSValue>; const Position: Integer): Double;
begin
  const Value = Argument(Args, Position);

  Result := TJSConversions.ToIntegerOrInfinity(Value);
end;

class function TJSArrayLike.ResolveRelative(const Relative: Double; const Count: Int64): Int64;
begin
  const IsFromEnd = (Relative < 0);
  if IsFromEnd then
    Result := Trunc(Max(Count + Relative, 0))
  else
    Result := Trunc(Min(Relative, Count));
end;

class function TJSArrayLike.TryGetOwnArrayElement(const Target: IJSObject; const Index: Int64;
                                                  out Element: TJSValue): Boolean;
begin
  var TargetArray: IJSArray;
  const IsArray = Supports(Target, IJSArray, TargetArray);
  Result := (IsArray and (Index < TargetArray.Length) and TargetArray.HasElement(Integer(Index)));
  if Result then
    Element := TargetArray[Integer(Index)];
end;

class function TJSArrayLike.SpliceDeleteCount(const Args: TArray<TJSValue>; const Count, Start: Int64): Int64;
begin
  const HasNoArguments = (Length(Args) = 0);
  if HasNoArguments then
    Exit(0);

  const HasOnlyStart = (Length(Args) = 1);
  if HasOnlyStart then
    Exit(Count - Start);

  const Requested = TJSConversions.ToIntegerOrInfinity(Args[1]);
  Result := Trunc(Min(Max(Requested, 0), Count - Start));
end;

class function TJSArrayLike.TryGetElement(const Target: IJSObject; const Index: Int64;
                                          out Element: TJSValue): Boolean;
begin
  if TryGetOwnArrayElement(Target, Index, Element) then
    Exit(True);

  const Name = IndexName(Index);
  Result := Target.HasProperty(Name);
  if Result then
    Element := Target.GetProperty(Name);
end;

class function TJSArrayLike.GetElement(const Target: IJSObject; const Index: Int64): TJSValue;
begin
  if TryGetOwnArrayElement(Target, Index, Result) then
    Exit;

  Result := Target.GetProperty(IndexName(Index));
end;

class procedure TJSArrayLike.SetElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue);
begin
  TJSConversions.PutProperty(Target, IndexName(Index), Value);
end;

class procedure TJSArrayLike.DeleteElement(const Target: IJSObject; const Index: Int64);
begin
  const Name = IndexName(Index);
  const IsLocked = Target.HasOwnProperty(Name) and (not Target.IsPropertyConfigurable(Name));
  if IsLocked then
  begin
    const Message = Format(CANNOT_DELETE_PROPERTY, [Name]);
    raise TJSErrorFactory.TypeError(Message);
  end;

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
  TJSConversions.PutProperty(Target, LENGTH_PROPERTY, TJSValue.CreateNumber(Count));
end;

class procedure TJSArrayLike.RequireArrayLength(const Count: Int64);
begin
  const ExceedsArrayLength = (Count > MAX_ARRAY_LENGTH);
  if ExceedsArrayLength then
    raise TJSErrorFactory.InvalidArrayLength;
end;

class procedure TJSArrayLike.RequireSafeLength(const Count: Int64);
begin
  const ExceedsSafeLength = (Count > MAX_SAFE_INTEGER_COUNT);
  if ExceedsSafeLength then
    raise TJSErrorFactory.TypeError(LENGTH_EXCEEDS_SAFE_INTEGER);
end;

class procedure TJSArrayLike.RequireSortComparer(const Args: TArray<TJSValue>);
begin
  const Comparer = Argument(Args, 0);
  const IsAcceptable = Comparer.IsUndefined or Comparer.IsFunction;
  if not IsAcceptable then
    raise TJSErrorFactory.TypeError(COMPARER_NOT_A_FUNCTION);
end;

class function TJSArrayLike.CustomSpeciesConstructor(const Target: IJSObject; const IntrinsicArray: IJSFunction;
                                               const IntrinsicSpeciesGetter: IJSFunction): IJSFunction;
begin
  Result := nil;

  const IsArray = TJSObjectOperations.IsArray(TJSValue.CreateObject(Target));
  if not IsArray then
    Exit;

  const Candidate = TJSConversions.SpeciesConstructor(Target, IntrinsicArray, IntrinsicSpeciesGetter);
  const IsIntrinsic = Assigned(IntrinsicArray) and TJSObjectOperations.IsSameObject(Candidate, IntrinsicArray);
  if not IsIntrinsic then
    Result := Candidate;
end;

end.
