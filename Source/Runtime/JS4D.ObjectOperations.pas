unit JS4D.ObjectOperations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolObject,
  JS4D.ArrayObject,
  JS4D.BinaryData,
  JS4D.SymbolRegistry;

type
  IJSProxy = interface
    ['{7E1D2C94-3B5A-4F0E-9C68-1A2B3C4D5E6F}']
    function GetWithReceiver(const Name: TJSPropertyKey; const Receiver: TJSValue): TJSValue;
    function SetWithReceiver(const Name: TJSPropertyKey; const Value: TJSValue; const Receiver: TJSValue): Boolean;
    function TryGetOwnProperty(const Name: TJSPropertyKey; out Descriptor: TJSPropertyDescriptor): Boolean;
    function DeleteOwnProperty(const Name: TJSPropertyKey): Boolean;
    function TryPreventExtensions: Boolean;
    function TrySetPrototype(const Prototype: IJSObject): Boolean;
    function OwnKeys: TArray<TJSPropertyKey>;
    function IsArrayProxy: Boolean;
    function GetProxyTarget: IJSObject;
    function GetProxyHandler: IJSObject;
    procedure Revoke;
    function IsRevoked: Boolean;
    property ProxyTarget: IJSObject read GetProxyTarget;
    property ProxyHandler: IJSObject read GetProxyHandler;
  end;

  TJSObjectOperations = class
  private
    class function ReadFromDescriptor(const Descriptor: TJSPropertyDescriptor;
                                      const Receiver: TJSValue): TJSValue; static;
    class function FreshDataDescriptor: TJSPropertyDescriptor; static;
    class function TryDelegateSet(const Current: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                  const Receiver: TJSValue; out Outcome: Boolean): Boolean; static;
    class function CallSetter(const OwnDescriptor: TJSPropertyDescriptor; const Value: TJSValue;
                              const Receiver: TJSValue): Boolean; static;
    class function SetOnReceiver(const OwnDescriptor: TJSPropertyDescriptor; const Name: TJSPropertyKey;
                                 const Value: TJSValue; const Receiver: TJSValue): Boolean; static;

  public
    class function TryGetProxy(const Target: IJSObject; out Proxy: IJSProxy): Boolean; static;
    class function IsProxy(const Target: IJSObject): Boolean; static;
    class function KeyToValue(const Key: TJSPropertyKey): TJSValue; static;
    class function TryGetOwnProperty(const Target: IJSObject; const Name: TJSPropertyKey;
                                     out Descriptor: TJSPropertyDescriptor): Boolean; static;
    class function GetWithReceiver(const Target: IJSObject; const Name: TJSPropertyKey;
                                   const Receiver: TJSValue): TJSValue; static;
    class function SetWithReceiver(const Target: IJSObject; const Name: TJSPropertyKey; const Value: TJSValue;
                                   const Receiver: TJSValue): Boolean; static;
    class function CreateDataProperty(const Target: IJSObject; const Name: TJSPropertyKey;
                                      const Value: TJSValue): Boolean; static;
    class procedure DefineHiddenData(const Target: IJSObject; const Name: TJSPropertyKey;
                                     const Value: TJSValue); static;
    class procedure DefineConstantData(const Target: IJSObject; const Name: TJSPropertyKey;
                                       const Value: TJSValue); static;
    class function DeleteOwnProperty(const Target: IJSObject; const Name: TJSPropertyKey): Boolean; static;
    class function PreventExtensions(const Target: IJSObject): Boolean; static;
    class function SetPrototypeOf(const Target: IJSObject; const Prototype: IJSObject): Boolean; static;
    class function OwnKeys(const Target: IJSObject): TArray<TJSPropertyKey>; static;
    class function IsArray(const Value: TJSValue): Boolean; static;
    class function IdentityOf(const Target: IInterface): Pointer; static;
    class function IsSameObject(const First: IInterface; const Second: IInterface): Boolean; static;
  end;

implementation

class function TJSObjectOperations.TryGetProxy(const Target: IJSObject; out Proxy: IJSProxy): Boolean;
begin
  Result := Assigned(Target) and Supports(Target, IJSProxy, Proxy);
end;

class function TJSObjectOperations.IsProxy(const Target: IJSObject): Boolean;
begin
  var Proxy: IJSProxy;

  Result := TryGetProxy(Target, Proxy);
end;

class function TJSObjectOperations.KeyToValue(const Key: TJSPropertyKey): TJSValue;
begin
  if Key.IsSymbol then
  begin
    const Found = TJSSymbolRegistry.Find(Key.SymbolId);
    if Found is TJSSymbolImpl then
    begin
      Result := TJSValue.CreateSymbol(Found as TJSSymbolImpl);
      Exit;
    end;
  end;

  Result := TJSValue.CreateString(Key.Text);
end;

class function TJSObjectOperations.TryGetOwnProperty(const Target: IJSObject; const Name: TJSPropertyKey;
                                                     out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  var Proxy: IJSProxy;
  if TryGetProxy(Target, Proxy) then
  begin
    Result := Proxy.TryGetOwnProperty(Name, Descriptor);
    Exit;
  end;

  Result := Target.HasOwnProperty(Name);
  if Result then
    Descriptor := Target.GetOwnPropertyDescriptor(Name);
end;

class function TJSObjectOperations.ReadFromDescriptor(const Descriptor: TJSPropertyDescriptor;
                                                      const Receiver: TJSValue): TJSValue;
begin
  if not Descriptor.IsAccessor then
  begin
    Result := Descriptor.Value;
    Exit;
  end;

  var Getter: IJSFunction;
  if not Descriptor.Getter.TryGetFunction(Getter) then
  begin
    Result := TJSValue.CreateUndefined;
    Exit;
  end;

  Result := Getter.Call(Receiver.ToObject, nil);
end;

class function TJSObjectOperations.GetWithReceiver(const Target: IJSObject; const Name: TJSPropertyKey;
                                                   const Receiver: TJSValue): TJSValue;
begin
  var Current := Target;
  while Assigned(Current) do
  begin
    var Proxy: IJSProxy;
    if TryGetProxy(Current, Proxy) then
    begin
      Result := Proxy.GetWithReceiver(Name, Receiver);
      Exit;
    end;

    if Current.HasOwnProperty(Name) then
    begin
      const Descriptor = Current.GetOwnPropertyDescriptor(Name);

      Result := ReadFromDescriptor(Descriptor, Receiver);
      Exit;
    end;

    Current := Current.Prototype;
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSObjectOperations.FreshDataDescriptor: TJSPropertyDescriptor;
begin
  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
  Result.Writable := True;
  Result.Enumerable := True;
  Result.Configurable := True;
end;

class function TJSObjectOperations.TryDelegateSet(const Current: IJSObject; const Name: TJSPropertyKey;
                                                  const Value: TJSValue; const Receiver: TJSValue;
                                                  out Outcome: Boolean): Boolean;
begin
  Result := True;

  var Proxy: IJSProxy;
  if TryGetProxy(Current, Proxy) then
  begin
    Outcome := Proxy.SetWithReceiver(Name, Value, Receiver);
    Exit;
  end;

  if TJSBinaryKeys.TryStoreElement(Current, Name, Value, Receiver) then
  begin
    Outcome := True;
    Exit;
  end;

  Outcome := False;
  Result := False;
end;

class function TJSObjectOperations.SetWithReceiver(const Target: IJSObject; const Name: TJSPropertyKey;
                                                   const Value: TJSValue; const Receiver: TJSValue): Boolean;
begin
  var OwnDescriptor := FreshDataDescriptor;

  var Current := Target;
  while Assigned(Current) do
  begin
    var Outcome: Boolean;
    if TryDelegateSet(Current, Name, Value, Receiver, Outcome) then
      Exit(Outcome);

    if Current.HasOwnProperty(Name) then
    begin
      OwnDescriptor := Current.GetOwnPropertyDescriptor(Name);
      Break;
    end;

    Current := Current.Prototype;
  end;

  if OwnDescriptor.IsAccessor then
    Result := CallSetter(OwnDescriptor, Value, Receiver)
  else
    Result := SetOnReceiver(OwnDescriptor, Name, Value, Receiver);
end;

class function TJSObjectOperations.CallSetter(const OwnDescriptor: TJSPropertyDescriptor; const Value: TJSValue;
                                              const Receiver: TJSValue): Boolean;
begin
  var Setter: IJSFunction;
  if not OwnDescriptor.Setter.TryGetFunction(Setter) then
    Exit(False);

  Setter.Call(Receiver.ToObject, [Value]);
  Result := True;
end;

class function TJSObjectOperations.SetOnReceiver(const OwnDescriptor: TJSPropertyDescriptor;
                                                 const Name: TJSPropertyKey; const Value: TJSValue;
                                                 const Receiver: TJSValue): Boolean;
begin
  const CannotAssign = (not OwnDescriptor.Writable) or (not Receiver.IsObject);
  if CannotAssign then
    Exit(False);

  const ReceiverObject = Receiver.ToObject;
  var Existing: TJSPropertyDescriptor;
  const HasExisting = TryGetOwnProperty(ReceiverObject, Name, Existing);
  if not HasExisting then
  begin
    Result := CreateDataProperty(ReceiverObject, Name, Value);
    Exit;
  end;

  if Existing.IsAccessor or (not Existing.Writable) then
    Exit(False);

  const Definition = TJSPropertyDefinition.ForValue(Value);
  Result := ReceiverObject.DefineOwnProperty(Name, Definition);
end;

class function TJSObjectOperations.CreateDataProperty(const Target: IJSObject; const Name: TJSPropertyKey;
                                                      const Value: TJSValue): Boolean;
begin
  const Definition = TJSPropertyDefinition.ForDataProperty(Value);

  Result := Target.DefineOwnProperty(Name, Definition);
end;

class procedure TJSObjectOperations.DefineHiddenData(const Target: IJSObject; const Name: TJSPropertyKey;
                                                     const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Enumerable := False;
  Target.DefineProperty(Name, Descriptor);
end;

class procedure TJSObjectOperations.DefineConstantData(const Target: IJSObject; const Name: TJSPropertyKey;
                                                       const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := False;
  Target.DefineProperty(Name, Descriptor);
end;

class function TJSObjectOperations.DeleteOwnProperty(const Target: IJSObject; const Name: TJSPropertyKey): Boolean;
begin
  var Proxy: IJSProxy;
  if TryGetProxy(Target, Proxy) then
  begin
    Result := Proxy.DeleteOwnProperty(Name);
    Exit;
  end;

  if not Target.HasOwnProperty(Name) then
    Exit(True);

  if TJSBinaryKeys.IsElementKey(Target, Name) then
    Exit(False);

  if not Target.GetOwnPropertyDescriptor(Name).Configurable then
    Exit(False);

  var Elements: IJSArray;
  var Index: Integer;
  const IsElement = Supports(Target, IJSArray, Elements) and TJSArray.TryParseIndex(Name, Index);
  if IsElement then
    Elements.DeleteElement(Index);

  Target.DeleteProperty(Name);
  Result := True;
end;

class function TJSObjectOperations.PreventExtensions(const Target: IJSObject): Boolean;
begin
  var Proxy: IJSProxy;
  if TryGetProxy(Target, Proxy) then
  begin
    Result := Proxy.TryPreventExtensions;
    Exit;
  end;

  Target.PreventExtensions;
  Result := True;
end;

class function TJSObjectOperations.SetPrototypeOf(const Target: IJSObject; const Prototype: IJSObject): Boolean;
begin
  var Proxy: IJSProxy;
  if TryGetProxy(Target, Proxy) then
  begin
    Result := Proxy.TrySetPrototype(Prototype);
    Exit;
  end;

  const IsUnchanged = IsSameObject(Target.Prototype, Prototype);
  if IsUnchanged then
    Exit(True);

  const HasImmutablePrototype = ((Target is TJSObjectImpl) and TJSObjectImpl(Target).HasImmutablePrototype);
  const IsNonExtensible = (not Target.IsExtensible);
  if HasImmutablePrototype or IsNonExtensible then
    Exit(False);

  var Ancestor := Prototype;
  while Assigned(Ancestor) do
  begin
    const IsCycle = IsSameObject(Ancestor, Target);
    if IsCycle then
      Exit(False);

    if TryGetProxy(Ancestor, Proxy) then
      Break;

    Ancestor := Ancestor.Prototype;
  end;

  Target.Prototype := Prototype;
  Result := True;
end;

class function TJSObjectOperations.OwnKeys(const Target: IJSObject): TArray<TJSPropertyKey>;
begin
  var Proxy: IJSProxy;
  if TryGetProxy(Target, Proxy) then
  begin
    Result := Proxy.OwnKeys;
    Exit;
  end;

  const Names = Target.GetOwnPropertyNames;
  const SymbolKeys = Target.GetOwnSymbolKeysInCreationOrder;

  SetLength(Result, Length(Names) + Length(SymbolKeys));
  var Next := 0;
  for var Name in Names do
  begin
    Result[Next] := Name;
    Inc(Next);
  end;

  for var SymbolKey in SymbolKeys do
  begin
    Result[Next] := SymbolKey;
    Inc(Next);
  end;
end;

class function TJSObjectOperations.IdentityOf(const Target: IInterface): Pointer;
begin
  Result := Pointer(Target as IInterface);
end;

class function TJSObjectOperations.IsSameObject(const First: IInterface; const Second: IInterface): Boolean;
begin
  Result := (IdentityOf(First) = IdentityOf(Second));
end;

class function TJSObjectOperations.IsArray(const Value: TJSValue): Boolean;
begin
  if Value.IsArray then
    Exit(True);

  var Proxy: IJSProxy;
  Result := Value.IsObject and TryGetProxy(Value.ToObject, Proxy) and Proxy.IsArrayProxy;
end;

end.
