unit JS4D.ArrayIterator;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.ObjectHeap,
  JS4D.Types,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.BinaryData,
  JS4D.IteratorProtocol;

type
  TJSArrayIteratorKind = (Keys, Values, Entries);

  IJSArrayIterator = interface
    ['{4C8E1B73-2A5D-4F90-B6D1-7E3A9C05F284}']
    function TryPrepareNext: Boolean;
    function Next: TJSValue;
    function NextResult: TJSValue;
  end;

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
    procedure ClearTarget;

  protected
    procedure EnumerateHeapReferences(const Visit: TJSHeapVisitor); override;
    procedure ReleaseReferences; override;
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;

  public
    constructor Create(const Target: IJSObject; const Kind: TJSArrayIteratorKind;
                       const ArrayPrototype: IJSObject; const ObjectPrototype: IJSObject);
    destructor Destroy; override;

    function TryPrepareNext: Boolean;
    function Next: TJSValue;
    function NextResult: TJSValue;
  end;

implementation

const
  DETACHED_TYPED_ARRAY = 'Cannot perform %ArrayIteratorPrototype%.next on a detached ArrayBuffer';
  UNSUPPORTED_ARRAY_ITERATOR_KIND = 'Unsupported array iterator kind: %d';

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

destructor TJSArrayIterator.Destroy;
begin
  ReleaseNestedIteratively;
  inherited;
end;

procedure TJSArrayIterator.ReleaseReferences;
begin
  ReleaseNestedIteratively;
  ClearTarget;
  FArrayPrototype := nil;
  FObjectPrototype := nil;
  inherited;
end;

function TJSArrayIterator.HoldsNested: Boolean;
begin
  Result := Assigned(FTarget) or inherited HoldsNested;
end;

procedure TJSArrayIterator.DetachNested(const Pending: TList<IJSObject>);
begin
  if Assigned(FTarget) then
    Pending.Add(FTarget);

  ClearTarget;
  inherited DetachNested(Pending);
end;

procedure TJSArrayIterator.ClearTarget;
begin
  FIsExhausted := True;
  FTarget := nil;
  FTypedArray := nil;
end;

procedure TJSArrayIterator.EnumerateHeapReferences(const Visit: TJSHeapVisitor);
begin
  inherited;
  ReportReference(Visit, FTarget);
  ReportReference(Visit, FTypedArray);
  ReportReference(Visit, FArrayPrototype);
  ReportReference(Visit, FObjectPrototype);
end;

function TJSArrayIterator.TryPrepareNext: Boolean;
begin
  if FIsExhausted then
    Exit(False);

  if Assigned(FTypedArray) then
  begin
    if FTypedArray.IsDetached then
      raise TJSErrorFactory.TypeError(DETACHED_TYPED_ARRAY);

    Result := (FPosition < FTypedArray.Length);
  end
  else
  begin
    const TargetLength = TJSArrayLike.ToLength(FTarget);
    Result := (FPosition < TargetLength);
  end;

  if not Result then
    ClearTarget;
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
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_ARRAY_ITERATOR_KIND, [Ord(FKind)]);
  end;
end;

function TJSArrayIterator.NextResult: TJSValue;
begin
  if TryPrepareNext then
  begin
    const Value = Next;
    Result := TJSIteratorResults.CreateResult(FObjectPrototype, Value, False);
    Exit;
  end;

  Result := TJSIteratorResults.CreateResult(FObjectPrototype, TJSValue.CreateUndefined, True);
end;

function TJSArrayIterator.ReadElement(const Index: Int64): TJSValue;
begin
  const ElementName = TJSArrayLike.IndexName(Index);

  Result := FTarget.GetProperty(ElementName);
end;

function TJSArrayIterator.CreateEntry(const Index: Int64): TJSValue;
begin
  const Element = ReadElement(Index);
  const IndexValue = TJSValue.CreateNumber(Index);

  Result := TJSIteratorResults.CreateEntry(FArrayPrototype, IndexValue, Element);
end;

end.
