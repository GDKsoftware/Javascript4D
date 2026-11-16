unit JS4D.IntrinsicCache;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types;

type
  // The groups of built-in methods that a call expression runs directly, as long as the method that the
  // property lookup finds is still the built-in one.
  TJSIntrinsicGroup = (ArrayMethod, FunctionMethod, ObjectMethod);

  // The built-in functions and prototypes that the iteration fast paths compare against, to see that a
  // script has not replaced the iterator protocol of arrays, arguments objects or strings.
  TJSIterationIntrinsics = record
    ArrayIteratorPrototype: IJSObject;
    ArrayValues: IInterface;
    ArrayIteratorNext: IInterface;
    StringIteratorPrototype: IJSObject;
    StringIterator: IInterface;
    StringIteratorNext: IInterface;
  end;

  // Remembers where a built-in method sits in the property storage of its holder, so that checking it again
  // costs no hash lookup while the holder keeps the same layout.
  TJSIntrinsicSlot = record
    Holder: TJSObjectImpl;
    Version: Cardinal;
    Slot: PJSPropertyDescriptor;

    class function IsIntrinsic(const Candidate: TJSValue; const Original: IInterface): Boolean; static;
    function Holds(const HolderObject: IJSObject; const Key: TJSPropertyKey; const Original: IInterface): Boolean;
  end;

  // Remembers where push or pop sits in Array.prototype and which function is the built-in one, so that
  // calling it on a plain array needs neither a hash lookup nor a property read.
  TJSMutatorCache = record
  private
    function Fill(const Name: string; const ArrayPrototype: IJSObject;
                  const Methods: TDictionary<string, IJSObject>): Boolean;

  public
    Holder: TJSObjectImpl;
    Prototype: IJSObject;
    Version: Cardinal;
    Slot: PJSPropertyDescriptor;
    Original: IJSObject;
    PrototypeElements: IJSArray;

    function Holds(const Name: string; const ArrayPrototype: IJSObject;
                   const Methods: TDictionary<string, IJSObject>): Boolean;
  end;

implementation

{ TJSIntrinsicSlot }

class function TJSIntrinsicSlot.IsIntrinsic(const Candidate: TJSValue; const Original: IInterface): Boolean;
begin
  Result := Assigned(Original) and Candidate.IsObject and ((Candidate.ToObject as IInterface) = Original);
end;

function TJSIntrinsicSlot.Holds(const HolderObject: IJSObject; const Key: TJSPropertyKey;
                                const Original: IInterface): Boolean;
begin
  const IsOrdinaryObject = Assigned(Original) and (HolderObject is TJSObjectImpl);
  if not IsOrdinaryObject then
  begin
    Result := False;
    Exit;
  end;

  const HolderImpl = TJSObjectImpl(HolderObject);
  const IsCached = (Holder = HolderImpl) and (Version = HolderImpl.PropertyLayoutVersion);
  if not IsCached then
  begin
    Holder := nil;
    if not HolderImpl.TryGetOwnSlot(Key, Slot) then
    begin
      Result := False;
      Exit;
    end;

    Holder := HolderImpl;
    Version := HolderImpl.PropertyLayoutVersion;
  end;

  Result := ((not Slot.IsAccessor) and TJSIntrinsicSlot.IsIntrinsic(Slot.Value, Original));
end;

{ TJSMutatorCache }

function TJSMutatorCache.Holds(const Name: string; const ArrayPrototype: IJSObject;
                               const Methods: TDictionary<string, IJSObject>): Boolean;
begin
  const IsCurrent = Assigned(Holder) and (Prototype = ArrayPrototype) and
                    (Version = Holder.PropertyLayoutVersion);
  if (not IsCurrent) and (not Fill(Name, ArrayPrototype, Methods)) then
  begin
    Result := False;
    Exit;
  end;

  Result := (not Slot.IsAccessor) and Slot.Value.IsObject and (Slot.Value.ToObject = Original);
end;

function TJSMutatorCache.Fill(const Name: string; const ArrayPrototype: IJSObject;
                              const Methods: TDictionary<string, IJSObject>): Boolean;
begin
  Self := Default(TJSMutatorCache);

  var MethodOriginal: IJSObject;
  const IsKnownMethod = Assigned(Methods) and Methods.TryGetValue(Name, MethodOriginal) and
                        (ArrayPrototype is TJSObjectImpl);
  if not IsKnownMethod then
  begin
    Result := False;
    Exit;
  end;

  const PrototypeImpl = TJSObjectImpl(ArrayPrototype);
  var PrototypeSlot: PJSPropertyDescriptor;
  if not PrototypeImpl.TryGetOwnSlot(Name, PrototypeSlot) then
  begin
    Result := False;
    Exit;
  end;

  Holder := PrototypeImpl;
  Prototype := ArrayPrototype;
  Version := PrototypeImpl.PropertyLayoutVersion;
  Slot := PrototypeSlot;
  Original := MethodOriginal;
  Supports(ArrayPrototype, IJSArray, PrototypeElements);
  Result := True;
end;

end.
