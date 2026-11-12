unit JS4D.ObjectOperations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.BinaryData,
  JS4D.SymbolRegistry;

type
  // The internal methods of a proxy that cannot be expressed through IJSObject: the ones that take a receiver
  // and the ones that report failure instead of raising.
  IJSProxy = interface
    ['{7E1D2C94-3B5A-4F0E-9C68-1A2B3C4D5E6F}']
    function GetWithReceiver(const Name: string; const Receiver: TJSValue): TJSValue;
    function SetWithReceiver(const Name: string; const Value: TJSValue; const Receiver: TJSValue): Boolean;
    function TryGetOwnProperty(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
    function DeleteOwnProperty(const Name: string): Boolean;
    function TryPreventExtensions: Boolean;
    function TrySetPrototype(const Prototype: IJSObject): Boolean;
    function OwnKeys: TArray<string>;
    function IsArrayProxy: Boolean;
    function GetProxyTarget: IJSObject;
    function GetProxyHandler: IJSObject;
    procedure Revoke;
    function IsRevoked: Boolean;
    property ProxyTarget: IJSObject read GetProxyTarget;
    property ProxyHandler: IJSObject read GetProxyHandler;
  end;

  // The ordinary object internal methods, written so that they also work for objects that have a proxy
  // in their prototype chain and for proxies themselves.
  TJSObjectOperations = class
  public
    class function AsProxy(const Target: IJSObject; out Proxy: IJSProxy): Boolean; static;
    class function KeyToValue(const Key: string): TJSValue; static;
    class function TryGetOwnProperty(const Target: IJSObject; const Name: string;
                                     out Descriptor: TJSPropertyDescriptor): Boolean; static;
    class function GetWithReceiver(const Target: IJSObject; const Name: string;
                                   const Receiver: TJSValue): TJSValue; static;
    class function SetWithReceiver(const Target: IJSObject; const Name: string; const Value: TJSValue;
                                   const Receiver: TJSValue): Boolean; static;
    class function CreateDataProperty(const Target: IJSObject; const Name: string;
                                      const Value: TJSValue): Boolean; static;
    class function DeleteOwnProperty(const Target: IJSObject; const Name: string): Boolean; static;
    class function PreventExtensions(const Target: IJSObject): Boolean; static;
    class function SetPrototypeOf(const Target: IJSObject; const Prototype: IJSObject): Boolean; static;
    class function OwnKeys(const Target: IJSObject): TArray<string>; static;
    class function IsArray(const Value: TJSValue): Boolean; static;
  end;

implementation

class function TJSObjectOperations.AsProxy(const Target: IJSObject; out Proxy: IJSProxy): Boolean;
begin
  Result := Assigned(Target) and Supports(Target, IJSProxy, Proxy);
end;

class function TJSObjectOperations.KeyToValue(const Key: string): TJSValue;
begin
  if TJSSymbolRegistry.IsKey(Key) then
  begin
    const Found = TJSSymbolRegistry.Find(Key);
    if Found is TJSSymbolImpl then
      Exit(TJSValue.CreateSymbol(TJSSymbolImpl(Found)));
  end;

  Result := TJSValue.CreateString(Key);
end;

class function TJSObjectOperations.TryGetOwnProperty(const Target: IJSObject; const Name: string;
                                                     out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  var Proxy: IJSProxy;
  if AsProxy(Target, Proxy) then
    Exit(Proxy.TryGetOwnProperty(Name, Descriptor));

  Result := Target.HasOwnProperty(Name);
  if Result then
    Descriptor := Target.GetOwnPropertyDescriptor(Name);
end;

class function TJSObjectOperations.GetWithReceiver(const Target: IJSObject; const Name: string;
                                                   const Receiver: TJSValue): TJSValue;
begin
  var Current := Target;
  while Assigned(Current) do
  begin
    var Proxy: IJSProxy;
    if AsProxy(Current, Proxy) then
      Exit(Proxy.GetWithReceiver(Name, Receiver));

    if Current.HasOwnProperty(Name) then
    begin
      const Descriptor = Current.GetOwnPropertyDescriptor(Name);
      if not Descriptor.IsAccessor then
        Exit(Descriptor.Value);

      var Getter: IJSFunction;
      const HasGetter = Descriptor.Getter.IsFunction and Supports(Descriptor.Getter.ToObject, IJSFunction, Getter);
      if not HasGetter then
        Exit(TJSValue.CreateUndefined);

      Exit(Getter.Call(Receiver.ToObject, nil));
    end;

    Current := Current.Prototype;
  end;

  Result := TJSValue.CreateUndefined;
end;

class function TJSObjectOperations.SetWithReceiver(const Target: IJSObject; const Name: string;
                                                   const Value: TJSValue; const Receiver: TJSValue): Boolean;
begin
  var OwnDescriptor := Default(TJSPropertyDescriptor);
  OwnDescriptor.Value := TJSValue.CreateUndefined;
  OwnDescriptor.Writable := True;
  OwnDescriptor.Enumerable := True;
  OwnDescriptor.Configurable := True;

  var Current := Target;
  while Assigned(Current) do
  begin
    var Proxy: IJSProxy;
    if AsProxy(Current, Proxy) then
      Exit(Proxy.SetWithReceiver(Name, Value, Receiver));

    var IsStored: Boolean;
    if TJSBinaryKeys.TryStoreElement(Current, Name, Value, Receiver, IsStored) then
      Exit(IsStored);

    if Current.HasOwnProperty(Name) then
    begin
      OwnDescriptor := Current.GetOwnPropertyDescriptor(Name);
      Break;
    end;

    Current := Current.Prototype;
  end;

  if OwnDescriptor.IsAccessor then
  begin
    var Setter: IJSFunction;
    const HasSetter = OwnDescriptor.Setter.IsFunction and Supports(OwnDescriptor.Setter.ToObject, IJSFunction, Setter);
    if not HasSetter then
      Exit(False);

    Setter.Call(Receiver.ToObject, [Value]);
    Exit(True);
  end;

  if (not OwnDescriptor.Writable) or (not Receiver.IsObject) then
    Exit(False);

  const ReceiverObject = Receiver.ToObject;
  var Existing: TJSPropertyDescriptor;
  if not TryGetOwnProperty(ReceiverObject, Name, Existing) then
    Exit(CreateDataProperty(ReceiverObject, Name, Value));

  if Existing.IsAccessor or (not Existing.Writable) then
    Exit(False);

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Value;
  Result := ReceiverObject.DefineOwnProperty(Name, Definition);
end;

class function TJSObjectOperations.CreateDataProperty(const Target: IJSObject; const Name: string;
                                                      const Value: TJSValue): Boolean;
begin
  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Value;
  Definition.HasWritable := True;
  Definition.Writable := True;
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  Result := Target.DefineOwnProperty(Name, Definition);
end;

class function TJSObjectOperations.DeleteOwnProperty(const Target: IJSObject; const Name: string): Boolean;
begin
  var Proxy: IJSProxy;
  if AsProxy(Target, Proxy) then
    Exit(Proxy.DeleteOwnProperty(Name));

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
  if AsProxy(Target, Proxy) then
    Exit(Proxy.TryPreventExtensions);

  Target.PreventExtensions;
  Result := True;
end;

class function TJSObjectOperations.SetPrototypeOf(const Target: IJSObject; const Prototype: IJSObject): Boolean;
begin
  var Proxy: IJSProxy;
  if AsProxy(Target, Proxy) then
    Exit(Proxy.TrySetPrototype(Prototype));

  const IsUnchanged = ((Target.Prototype as IInterface) = (Prototype as IInterface));
  if IsUnchanged then
    Exit(True);

  if not Target.IsExtensible then
    Exit(False);

  var Ancestor := Prototype;
  while Assigned(Ancestor) do
  begin
    if (Ancestor as IInterface) = (Target as IInterface) then
      Exit(False);

    if AsProxy(Ancestor, Proxy) then
      Break;

    Ancestor := Ancestor.Prototype;
  end;

  Target.Prototype := Prototype;
  Result := True;
end;

class function TJSObjectOperations.OwnKeys(const Target: IJSObject): TArray<string>;
begin
  var Proxy: IJSProxy;
  if AsProxy(Target, Proxy) then
    Exit(Proxy.OwnKeys);

  const Names = Target.GetOwnPropertyNames;
  const SymbolKeys = Target.GetOwnSymbolKeys;
  if Length(SymbolKeys) = 0 then
    Exit(Names);

  Result := Names + SymbolKeys;
end;

class function TJSObjectOperations.IsArray(const Value: TJSValue): Boolean;
begin
  if Value.IsArray then
    Exit(True);

  var Proxy: IJSProxy;
  Result := Value.IsObject and AsProxy(Value.ToObject, Proxy) and Proxy.IsArrayProxy;
end;

end.
