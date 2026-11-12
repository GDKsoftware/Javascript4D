unit JS4D.ArrayIterator;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.BinaryData,
  JS4D.IteratorProtocol;

type
  TJSArrayIteratorKind = (Keys, Values, Entries);

  IJSArrayIterator = interface
    ['{4C8E1B73-2A5D-4F90-B6D1-7E3A9C05F284}']
    function HasNext: Boolean;
    function Next: TJSValue;
    function NextResult: TJSValue;
  end;

  // The object returned by Array.prototype keys, values and entries. It reads the length of the iterated
  // object on every step, so elements added before the iterator is exhausted are still visited.
  TJSArrayIterator = class(TJSObjectImpl, IJSArrayIterator)
  private
    var
      FTarget: IJSObject;
      FTypedArray: IJSTypedArray;
      FKind: TJSArrayIteratorKind;
      FArrayPrototype: IJSObject;
      FObjectPrototype: IJSObject;
      FPosition: Int64;
      FIsExhausted: Boolean;

    function ReadElement(const Index: Int64): TJSValue;
    function CreateEntry(const Index: Int64): TJSValue;
    function CreateResult(const Value: TJSValue; const IsDone: Boolean): TJSValue;

  public
    constructor Create(const Target: IJSObject; const Kind: TJSArrayIteratorKind;
                       const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);

    function HasNext: Boolean;
    function Next: TJSValue;
    function NextResult: TJSValue;
  end;

implementation

const
  DETACHED_TYPED_ARRAY = 'Cannot perform %ArrayIteratorPrototype%.next on a detached ArrayBuffer';

constructor TJSArrayIterator.Create(const Target: IJSObject; const Kind: TJSArrayIteratorKind;
                                    const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);
begin
  inherited Create;

  FTarget := Target;
  Supports(Target, IJSTypedArray, FTypedArray);
  FKind := Kind;
  FArrayPrototype := ArrayPrototype;
  FObjectPrototype := ObjectPrototype;
end;

function TJSArrayIterator.HasNext: Boolean;
begin
  if FIsExhausted then
    Exit(False);

  if Assigned(FTypedArray) then
  begin
    if FTypedArray.IsDetached then
      raise TJSErrorFactory.TypeError(DETACHED_TYPED_ARRAY);

    Result := FPosition < FTypedArray.Length;
  end
  else
  begin
    Result := FPosition < TJSArrayLike.ToLength(FTarget);
  end;

  if not Result then
  begin
    FIsExhausted := True;
    FTarget := nil;
    FTypedArray := nil;
  end;
end;

function TJSArrayIterator.Next: TJSValue;
begin
  const Index = FPosition;
  Inc(FPosition);

  case FKind of
    TJSArrayIteratorKind.Keys    : Result := TJSValue.CreateNumber(Index);
    TJSArrayIteratorKind.Values  : Result := ReadElement(Index);
    TJSArrayIteratorKind.Entries : Result := CreateEntry(Index);
  else
    raise ENotSupportedException.CreateFmt('Unsupported array iterator kind: %d', [Ord(FKind)]);
  end;
end;

function TJSArrayIterator.NextResult: TJSValue;
begin
  if HasNext then
  begin
    const Value = Next;
    Exit(CreateResult(Value, False));
  end;

  Result := CreateResult(TJSValue.CreateUndefined, True);
end;

function TJSArrayIterator.ReadElement(const Index: Int64): TJSValue;
begin
  Result := FTarget.GetProperty(TJSArrayLike.IndexName(Index));
end;

function TJSArrayIterator.CreateEntry(const Index: Int64): TJSValue;
begin
  const Entry = TJSArray.Create;
  Entry.Prototype := FArrayPrototype;
  const Element = ReadElement(Index);
  Entry.Push(TJSValue.CreateNumber(Index));
  Entry.Push(Element);

  Result := TJSValue.CreateObject(Entry);
end;

function TJSArrayIterator.CreateResult(const Value: TJSValue; const IsDone: Boolean): TJSValue;
begin
  Result := TJSIteratorResults.CreateResult(FObjectPrototype, Value, IsDone);
end;

end.
