unit JS4D.ProxyObjects;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.Errors,
  JS4D.ObjectOperations;

type
  TJSConstructHandler = reference to function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;

  TJSTargetConstructor = reference to function(const Target: IJSFunction; const Args: TArray<TJSValue>;
                                               const NewTarget: IJSFunction): TJSValue;

  // A native function that has its own behaviour when it is called with new.
  IJSNativeConstructor = interface
    ['{2B9C4D61-8F3A-4E75-A0D2-5C7E1B3F9A48}']
    function ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
  end;

  TJSConstructorFunction = class(TJSFunctionImpl, IJSNativeConstructor)
  private
    FHandler: TJSConstructHandler;

  public
    constructor CreateConstructor(const Name: string; const Func: TNativeFunction;
                                  const Handler: TJSConstructHandler);
    destructor Destroy; override;

    function ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
  end;

  IJSProxyRuntime = interface
    ['{C41F7A02-5D3B-4B86-9E1C-72A8D0F6B3E5}']
    function GetObjectPrototype: IJSObject;
    function GetArrayPrototype: IJSObject;
    function Construct(const Target: IJSFunction; const Args: TArray<TJSValue>;
                       const NewTarget: IJSFunction): TJSValue;
    property ObjectPrototype: IJSObject read GetObjectPrototype;
    property ArrayPrototype: IJSObject read GetArrayPrototype;
  end;

  TJSProxyRuntime = class(TInterfacedObject, IJSProxyRuntime)
  private
    FObjectPrototype: IJSObject;
    FArrayPrototype: IJSObject;
    FConstruct: TJSTargetConstructor;

    function GetObjectPrototype: IJSObject;
    function GetArrayPrototype: IJSObject;

  public
    constructor Create(const ObjectPrototype: IJSObject; const ArrayPrototype: IJSObject;
                       const Construct: TJSTargetConstructor);
    destructor Destroy; override;

    function Construct(const Target: IJSFunction; const Args: TArray<TJSValue>;
                       const NewTarget: IJSFunction): TJSValue;
  end;

  // The internal methods of a proxy: every one looks up its trap on the handler, falls back to the target
  // and verifies the invariants of the result against the target.
  TJSProxyCore = class(TInterfacedObject, IJSProxy)
  private
    const
      REVOKED = 'Cannot perform ''%s'' on a proxy that has been revoked';
      TRAP_NOT_CALLABLE = 'The ''%s'' trap of a proxy handler must be a function';
      TRAP_GET_PROTOTYPE_OF = 'getPrototypeOf';
      TRAP_SET_PROTOTYPE_OF = 'setPrototypeOf';
      TRAP_IS_EXTENSIBLE = 'isExtensible';
      TRAP_PREVENT_EXTENSIONS = 'preventExtensions';
      TRAP_GET_OWN_PROPERTY_DESCRIPTOR = 'getOwnPropertyDescriptor';
      TRAP_DEFINE_PROPERTY = 'defineProperty';
      TRAP_HAS = 'has';
      TRAP_GET = 'get';
      TRAP_SET = 'set';
      TRAP_DELETE_PROPERTY = 'deleteProperty';
      TRAP_OWN_KEYS = 'ownKeys';
      TRAP_APPLY = 'apply';
      TRAP_CONSTRUCT = 'construct';
      PROTOTYPE_RESULT = '''getPrototypeOf'' on proxy: trap returned neither object nor null';
      PROTOTYPE_MISMATCH = '''getPrototypeOf'' on proxy: proxy target is non-extensible but the trap did not return its actual prototype';
      SET_PROTOTYPE_MISMATCH = '''setPrototypeOf'' on proxy: trap returned truish for setting a new prototype on the non-extensible proxy target';
      EXTENSIBLE_MISMATCH = '''isExtensible'' on proxy: trap result does not reflect extensibility of proxy target';
      PREVENT_EXTENSIONS_MISMATCH = '''preventExtensions'' on proxy: trap returned truish but the proxy target is extensible';
      DESCRIPTOR_RESULT = '''getOwnPropertyDescriptor'' on proxy: trap returned neither object nor undefined for property ''%s''';
      DESCRIPTOR_HIDES_NON_CONFIGURABLE = '''getOwnPropertyDescriptor'' on proxy: trap returned undefined for property ''%s'' which is non-configurable in the proxy target';
      DESCRIPTOR_HIDES_FROM_NON_EXTENSIBLE = '''getOwnPropertyDescriptor'' on proxy: trap returned undefined for property ''%s'' which exists in the non-extensible proxy target';
      DESCRIPTOR_INCOMPATIBLE = '''getOwnPropertyDescriptor'' on proxy: trap returned descriptor for property ''%s'' that is incompatible with the existing property in the proxy target';
      DESCRIPTOR_FALSE_NON_CONFIGURABLE = '''getOwnPropertyDescriptor'' on proxy: trap reported non-configurability for property ''%s'' which is either non-existent or configurable in the proxy target';
      DESCRIPTOR_FALSE_NON_WRITABLE = '''getOwnPropertyDescriptor'' on proxy: trap reported non-configurable and writable for property ''%s'' which is non-configurable, non-writable in the proxy target';
      DEFINE_NON_EXTENSIBLE = '''defineProperty'' on proxy: trap returned truish for adding property ''%s'' to the non-extensible proxy target';
      DEFINE_NON_CONFIGURABLE_MISSING = '''defineProperty'' on proxy: trap returned truish for defining non-configurable property ''%s'' which is either non-existent or configurable in the proxy target';
      DEFINE_INCOMPATIBLE = '''defineProperty'' on proxy: trap returned truish for adding property ''%s'' that is incompatible with the existing property in the proxy target';
      DEFINE_NON_WRITABLE = '''defineProperty'' on proxy: trap returned truish for defining non-configurable property ''%s'' which cannot be non-writable, unless there exists a corresponding non-configurable, non-writable property in the target';
      HAS_HIDES_NON_CONFIGURABLE = '''has'' on proxy: trap returned falsish for property ''%s'' which exists in the proxy target as non-configurable';
      HAS_HIDES_FROM_NON_EXTENSIBLE = '''has'' on proxy: trap returned falsish for property ''%s'' but the proxy target is not extensible';
      GET_VALUE_MISMATCH = '''get'' on proxy: property ''%s'' is a read-only and non-configurable data property on the proxy target but the proxy did not return its actual value';
      GET_ACCESSOR_MISMATCH = '''get'' on proxy: property ''%s'' is a non-configurable accessor property on the proxy target and does not have a getter function, but the trap did not return ''undefined''';
      SET_VALUE_MISMATCH = '''set'' on proxy: trap returned truish for property ''%s'' which exists in the proxy target as a non-configurable and non-writable data property with a different value';
      SET_ACCESSOR_MISMATCH = '''set'' on proxy: trap returned truish for property ''%s'' which exists in the proxy target as a non-configurable and non-writable accessor property without a setter';
      DELETE_NON_CONFIGURABLE = '''deleteProperty'' on proxy: trap returned truish for property ''%s'' which is non-configurable in the proxy target';
      DELETE_NON_EXTENSIBLE = '''deleteProperty'' on proxy: trap returned truish for property ''%s'' but the proxy target is non-extensible';
      KEYS_NOT_AN_OBJECT = '''ownKeys'' on proxy: trap returned a value that is not an object';
      KEYS_INVALID_ELEMENT = '''ownKeys'' on proxy: trap result must contain only strings and symbols';
      KEYS_DUPLICATE = '''ownKeys'' on proxy: trap returned duplicate entries';
      KEYS_MISSING_NON_CONFIGURABLE = '''ownKeys'' on proxy: trap result did not include ''%s''';
      KEYS_MISSING_FROM_NON_EXTENSIBLE = '''ownKeys'' on proxy: trap result did not include ''%s'' of the non-extensible proxy target';
      KEYS_EXTRA_FOR_NON_EXTENSIBLE = '''ownKeys'' on proxy: trap returned extra keys but proxy target is non-extensible';
      CONSTRUCT_RESULT = '''construct'' on proxy: trap returned non-object';
      NOT_CALLABLE = 'Proxy target is not a function';
      MAX_TARGET_NESTING = 256;
      NESTING_TOO_DEEP = 'Proxy targets are nested too deeply';

    var
      FRuntime: IJSProxyRuntime;
      FTarget: IJSObject;
      FTargetFunction: IJSFunction;
      FHandler: IJSObject;
      FSymbols: TDictionary<string, IJSSymbol>;

    procedure RequireSupportedNesting(const Target: IJSObject);
    function GetTrap(const TrapName: string): IJSFunction;
    function InvokeTrap(const Trap: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
    function ArrayFromList(const Items: TArray<TJSValue>): TJSValue;
    function DefinitionToObject(const Definition: TJSPropertyDefinition): TJSValue;
    class function CompleteDefinition(const Definition: TJSPropertyDefinition): TJSPropertyDescriptor; static;
    class function IsCompatible(const IsExtensible: Boolean; const Definition: TJSPropertyDefinition;
                                const HasCurrent: Boolean; const Current: TJSPropertyDescriptor): Boolean; static;
    function KeyFromValue(const Item: TJSValue): string;
    function ReadKeyList(const Source: TJSValue): TArray<string>;
    procedure CheckOwnKeys(const Keys: TArray<string>);
    procedure CheckOwnKeysAgainstTarget(const Subject: IJSObject; const Keys: TArray<string>);
    procedure RequireDescriptorMatches(const Subject: IJSObject; const Name: string; const Completed: TJSPropertyDescriptor;
                                       const Definition: TJSPropertyDefinition);

  public
    constructor Create(const Runtime: IJSProxyRuntime; const Target: IJSObject; const Handler: IJSObject);
    destructor Destroy; override;

    procedure Revoke;
    function IsRevoked: Boolean;
    procedure RequireLive(const Operation: string);

    function HasProperty(const Name: string): Boolean;
    function GetPrototypeOf: IJSObject;
    function SetPrototypeOf(const Prototype: IJSObject): Boolean;
    function IsExtensible: Boolean;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
    function Call(const ThisObj: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;

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

    property Target: IJSObject read FTarget;
  end;

  TJSProxyObject = class(TJSObjectImpl, IJSProxy, IJSIntegerIndexedKeys)
  private
    FProxyRef: IJSProxy;
    FCore: TJSProxyCore;

    function SelfValue: TJSValue;

  protected
    function GetPrototype: IJSObject; override;
    procedure SetPrototype(const Value: IJSObject); override;

  public
    constructor Create(const Core: TJSProxyCore);
    destructor Destroy; override;

    function HasProperty(const Name: string): Boolean; override;
    function GetProperty(const Name: string): TJSValue; override;
    procedure SetProperty(const Name: string; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: string); override;
    function IsPropertyConfigurable(const Name: string): Boolean; override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnSymbolKeys: TArray<string>; override;
    function IsFrozen: Boolean; override;
    function IsSealed: Boolean; override;
    function IsExtensible: Boolean; override;
    procedure Freeze; override;
    procedure Seal; override;
    procedure PreventExtensions; override;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: string): Boolean; override;
    procedure DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor); override;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; override;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; override;
    function IsInvalidIndexKey(const Name: string): Boolean;

    property ProxyImplementation: IJSProxy read FProxyRef implements IJSProxy;
  end;

  TJSProxyFunction = class(TJSFunctionImpl, IJSProxy, IJSNativeConstructor, IJSIntegerIndexedKeys)
  private
    FProxyRef: IJSProxy;
    FCore: TJSProxyCore;

    function SelfValue: TJSValue;

  protected
    function GetPrototype: IJSObject; override;
    procedure SetPrototype(const Value: IJSObject); override;

  public
    constructor Create(const Core: TJSProxyCore; const IsConstructorTarget: Boolean);
    destructor Destroy; override;

    function HasProperty(const Name: string): Boolean; override;
    function GetProperty(const Name: string): TJSValue; override;
    procedure SetProperty(const Name: string; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: string); override;
    function IsPropertyConfigurable(const Name: string): Boolean; override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnSymbolKeys: TArray<string>; override;
    function IsFrozen: Boolean; override;
    function IsSealed: Boolean; override;
    function IsExtensible: Boolean; override;
    procedure Freeze; override;
    procedure Seal; override;
    procedure PreventExtensions; override;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: string): Boolean; override;
    procedure DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor); override;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; override;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; override;
    function IsInvalidIndexKey(const Name: string): Boolean;

    function ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;

    property ProxyImplementation: IJSProxy read FProxyRef implements IJSProxy;
  end;

  TJSProxyFactory = class
  public
    class function Create(const Runtime: IJSProxyRuntime; const Target: IJSObject;
                          const Handler: IJSObject): IJSObject; static;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.SymbolRegistry,
  JS4D.PropertyDescriptors;

type
  TJSIntegrityLevel = (Sealed, Frozen);

  // Everything the two proxy classes share that is expressed through the IJSObject surface: the accessor
  // that stands in for a proxy found in a prototype chain, and the integrity level operations.
  TJSProxyShared = class
  public
    class function IsCallable(const Value: TJSValue; out Func: IJSFunction): Boolean; static;
    class function SameObject(const Left: IJSObject; const Right: IJSObject): Boolean; static;
    class function ObjectOrNull(const Value: IJSObject): TJSValue; static;
    class function ObjectOrUndefined(const Value: IJSObject): TJSValue; static;
    class function FirstArgument(const Args: TArray<TJSValue>): TJSValue; static;
    class function InheritedAccessor(const Proxy: IJSProxy; const Name: string): TJSPropertyDescriptor; static;
    class function StringKeys(const Keys: TArray<string>): TArray<string>; static;
    class function SymbolKeys(const Keys: TArray<string>): TArray<string>; static;
    class function TestIntegrity(const Core: TJSProxyCore; const Level: TJSIntegrityLevel): Boolean; static;
    class procedure SetIntegrity(const Core: TJSProxyCore; const Level: TJSIntegrityLevel); static;
    class procedure DefineOrRaise(const Core: TJSProxyCore; const Name: string;
                                  const Definition: TJSPropertyDefinition); static;
    class function ToDefinition(const Descriptor: TJSPropertyDescriptor): TJSPropertyDefinition; static;
  end;

const
  PROPERTY_NOT_DEFINED = 'Cannot redefine property: %s';
  PREVENT_FAILED = 'Cannot prevent extensions on this proxy';
  SET_PROTOTYPE_FAILED = 'Cannot set the prototype of this proxy';
  INHERITED_ACCESSOR = 'proxy';
  ATTRIBUTE_VALUE = 'value';
  ATTRIBUTE_WRITABLE = 'writable';
  ATTRIBUTE_GET = 'get';
  ATTRIBUTE_SET = 'set';
  ATTRIBUTE_ENUMERABLE = 'enumerable';
  ATTRIBUTE_CONFIGURABLE = 'configurable';

{ TJSConstructorFunction }

constructor TJSConstructorFunction.CreateConstructor(const Name: string; const Func: TNativeFunction;
                                                     const Handler: TJSConstructHandler);
begin
  inherited CreateNative(Name, Func);
  FHandler := Handler;
end;

destructor TJSConstructorFunction.Destroy;
begin
  FHandler := nil;
  inherited;
end;

function TJSConstructorFunction.ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  Result := FHandler(Args, NewTarget);
end;

{ TJSProxyRuntime }

constructor TJSProxyRuntime.Create(const ObjectPrototype: IJSObject; const ArrayPrototype: IJSObject;
                                   const Construct: TJSTargetConstructor);
begin
  inherited Create;

  FObjectPrototype := ObjectPrototype;
  FArrayPrototype := ArrayPrototype;
  FConstruct := Construct;
end;

destructor TJSProxyRuntime.Destroy;
begin
  FConstruct := nil;
  FObjectPrototype := nil;
  FArrayPrototype := nil;
  inherited;
end;

function TJSProxyRuntime.GetObjectPrototype: IJSObject;
begin
  Result := FObjectPrototype;
end;

function TJSProxyRuntime.GetArrayPrototype: IJSObject;
begin
  Result := FArrayPrototype;
end;

function TJSProxyRuntime.Construct(const Target: IJSFunction; const Args: TArray<TJSValue>;
                                   const NewTarget: IJSFunction): TJSValue;
begin
  Result := FConstruct(Target, Args, NewTarget);
end;

{ TJSProxyCore }

constructor TJSProxyCore.Create(const Runtime: IJSProxyRuntime; const Target: IJSObject; const Handler: IJSObject);
begin
  inherited Create;

  RequireSupportedNesting(Target);

  FRuntime := Runtime;
  FTarget := Target;
  FHandler := Handler;
  Supports(Target, IJSFunction, FTargetFunction);
end;

procedure TJSProxyCore.RequireSupportedNesting(const Target: IJSObject);
begin
  var Nesting := 0;
  var Current := Target;
  var Nested: IJSProxy;
  while Supports(Current, IJSProxy, Nested) do
  begin
    Inc(Nesting);
    if Nesting >= MAX_TARGET_NESTING then
      raise TJSErrorFactory.RangeError(NESTING_TOO_DEEP);

    Current := Nested.GetProxyTarget;
  end;
end;

destructor TJSProxyCore.Destroy;
begin
  FSymbols.Free;
  inherited;
end;

procedure TJSProxyCore.Revoke;
begin
  FTarget := nil;
  FTargetFunction := nil;
  FHandler := nil;
end;

function TJSProxyCore.IsRevoked: Boolean;
begin
  Result := not Assigned(FHandler);
end;

procedure TJSProxyCore.RequireLive(const Operation: string);
begin
  if IsRevoked then
    raise TJSErrorFactory.TypeError(Format(REVOKED, [Operation]));
end;

function TJSProxyCore.GetTrap(const TrapName: string): IJSFunction;
begin
  RequireLive(TrapName);

  Result := nil;
  const TrapValue = FHandler.GetProperty(TrapName);
  if TrapValue.IsNullOrUndefined then
    Exit;

  if not TJSProxyShared.IsCallable(TrapValue, Result) then
    raise TJSErrorFactory.TypeError(Format(TRAP_NOT_CALLABLE, [TrapName]));
end;

function TJSProxyCore.InvokeTrap(const Trap: IJSFunction; const Args: TArray<TJSValue>): TJSValue;
begin
  Result := Trap.Call(FHandler, Args);
end;

function TJSProxyCore.ArrayFromList(const Items: TArray<TJSValue>): TJSValue;
begin
  const List: IJSArray = TJSArray.Create;
  List.Prototype := FRuntime.ArrayPrototype;

  for var Item in Items do
  begin
    List.Push(Item);
  end;

  Result := TJSValue.CreateObject(List);
end;

function TJSProxyCore.DefinitionToObject(const Definition: TJSPropertyDefinition): TJSValue;
begin
  const Described: IJSObject = TJSObject.Create;
  Described.Prototype := FRuntime.ObjectPrototype;

  if Definition.HasValue then
    Described.SetProperty(ATTRIBUTE_VALUE, Definition.Value);

  if Definition.HasWritable then
    Described.SetProperty(ATTRIBUTE_WRITABLE, TJSValue.CreateBoolean(Definition.Writable));

  if Definition.HasGetter then
    Described.SetProperty(ATTRIBUTE_GET, Definition.Getter);

  if Definition.HasSetter then
    Described.SetProperty(ATTRIBUTE_SET, Definition.Setter);

  if Definition.HasEnumerable then
    Described.SetProperty(ATTRIBUTE_ENUMERABLE, TJSValue.CreateBoolean(Definition.Enumerable));

  if Definition.HasConfigurable then
    Described.SetProperty(ATTRIBUTE_CONFIGURABLE, TJSValue.CreateBoolean(Definition.Configurable));

  Result := TJSValue.CreateObject(Described);
end;

class function TJSProxyCore.CompleteDefinition(const Definition: TJSPropertyDefinition): TJSPropertyDescriptor;
begin
  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
  Result.Enumerable := Definition.HasEnumerable and Definition.Enumerable;
  Result.Configurable := Definition.HasConfigurable and Definition.Configurable;

  if Definition.IsAccessorDefinition then
  begin
    Result.IsAccessor := True;
    Result.Getter := TJSValue.CreateUndefined;
    Result.Setter := TJSValue.CreateUndefined;

    if Definition.HasGetter then
      Result.Getter := Definition.Getter;

    if Definition.HasSetter then
      Result.Setter := Definition.Setter;

    Exit;
  end;

  if Definition.HasValue then
    Result.Value := Definition.Value;

  Result.Writable := Definition.HasWritable and Definition.Writable;
end;

class function TJSProxyCore.IsCompatible(const IsExtensible: Boolean; const Definition: TJSPropertyDefinition;
                                         const HasCurrent: Boolean;
                                         const Current: TJSPropertyDescriptor): Boolean;
begin
  if not HasCurrent then
    Exit(IsExtensible);

  if Definition.IsEmpty or Current.Configurable then
    Exit(True);

  const BecomesConfigurable = Definition.HasConfigurable and Definition.Configurable;
  const ChangesEnumerable = Definition.HasEnumerable and (Definition.Enumerable <> Current.Enumerable);
  if BecomesConfigurable or ChangesEnumerable then
    Exit(False);

  const ChangesKind = (Definition.IsAccessorDefinition and (not Current.IsAccessor)) or
                      (Definition.IsDataDefinition and Current.IsAccessor);
  if ChangesKind then
    Exit(False);

  if Current.IsAccessor then
  begin
    const ChangesGetter = Definition.HasGetter and (not Definition.Getter.SameValue(Current.Getter));
    const ChangesSetter = Definition.HasSetter and (not Definition.Setter.SameValue(Current.Setter));
    Exit(not (ChangesGetter or ChangesSetter));
  end;

  if Current.Writable then
    Exit(True);

  const BecomesWritable = Definition.HasWritable and Definition.Writable;
  const ChangesValue = Definition.HasValue and (not Definition.Value.SameValue(Current.Value));
  Result := not (BecomesWritable or ChangesValue);
end;

function TJSProxyCore.HasProperty(const Name: string): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_HAS);
  if not Assigned(Trap) then
    Exit(Subject.HasProperty(Name));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name)]);
  Result := TrapResult.ToBoolean;
  if Result then
    Exit;

  var TargetDescriptor: TJSPropertyDescriptor;
  if not TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor) then
    Exit;

  if not TargetDescriptor.Configurable then
    raise TJSErrorFactory.TypeError(Format(HAS_HIDES_NON_CONFIGURABLE, [Name]));

  if not Subject.IsExtensible then
    raise TJSErrorFactory.TypeError(Format(HAS_HIDES_FROM_NON_EXTENSIBLE, [Name]));
end;

function TJSProxyCore.GetPrototypeOf: IJSObject;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_GET_PROTOTYPE_OF);
  if not Assigned(Trap) then
    Exit(Subject.Prototype);

  const Proposed = InvokeTrap(Trap, [TJSValue.CreateObject(Subject)]);
  const IsValid = Proposed.IsObject or Proposed.IsNull;
  if not IsValid then
    raise TJSErrorFactory.TypeError(PROTOTYPE_RESULT);

  Result := Proposed.ToObject;
  if Subject.IsExtensible then
    Exit;

  if not TJSProxyShared.SameObject(Result, Subject.Prototype) then
    raise TJSErrorFactory.TypeError(PROTOTYPE_MISMATCH);
end;

function TJSProxyCore.SetPrototypeOf(const Prototype: IJSObject): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_SET_PROTOTYPE_OF);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.SetPrototypeOf(Subject, Prototype));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSProxyShared.ObjectOrNull(Prototype)]);
  Result := TrapResult.ToBoolean;
  if (not Result) or Subject.IsExtensible then
    Exit;

  if not TJSProxyShared.SameObject(Prototype, Subject.Prototype) then
    raise TJSErrorFactory.TypeError(SET_PROTOTYPE_MISMATCH);
end;

function TJSProxyCore.IsExtensible: Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_IS_EXTENSIBLE);
  if not Assigned(Trap) then
    Exit(Subject.IsExtensible);

  Result := InvokeTrap(Trap, [TJSValue.CreateObject(Subject)]).ToBoolean;
  if Result <> Subject.IsExtensible then
    raise TJSErrorFactory.TypeError(EXTENSIBLE_MISMATCH);
end;

function TJSProxyCore.TryPreventExtensions: Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_PREVENT_EXTENSIONS);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.PreventExtensions(Subject));

  Result := InvokeTrap(Trap, [TJSValue.CreateObject(Subject)]).ToBoolean;
  if Result and Subject.IsExtensible then
    raise TJSErrorFactory.TypeError(PREVENT_EXTENSIONS_MISMATCH);
end;

function TJSProxyCore.TrySetPrototype(const Prototype: IJSObject): Boolean;
begin
  Result := SetPrototypeOf(Prototype);
end;

procedure TJSProxyCore.RequireDescriptorMatches(const Subject: IJSObject; const Name: string; const Completed: TJSPropertyDescriptor;
                                                const Definition: TJSPropertyDefinition);
begin
  var TargetDescriptor: TJSPropertyDescriptor;
  const HasTargetDescriptor = TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor);

  const IsCompatibleResult = IsCompatible(Subject.IsExtensible, TJSProxyShared.ToDefinition(Completed),
                                          HasTargetDescriptor, TargetDescriptor);
  if not IsCompatibleResult then
    raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_INCOMPATIBLE, [Name]));

  if Completed.Configurable then
    Exit;

  const IsConfigurableInTarget = (not HasTargetDescriptor) or TargetDescriptor.Configurable;
  if IsConfigurableInTarget then
    raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_FALSE_NON_CONFIGURABLE, [Name]));

  const ReportsNonWritable = Definition.HasWritable and (not Definition.Writable);
  const IsWritableInTarget = (not TargetDescriptor.IsAccessor) and TargetDescriptor.Writable;
  if ReportsNonWritable and IsWritableInTarget then
    raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_FALSE_NON_WRITABLE, [Name]));
end;

function TJSProxyCore.TryGetOwnProperty(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_GET_OWN_PROPERTY_DESCRIPTOR);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.TryGetOwnProperty(Subject, Name, Descriptor));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name)]);
  const IsValid = TrapResult.IsObject or TrapResult.IsUndefined;
  if not IsValid then
    raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_RESULT, [Name]));

  var TargetDescriptor: TJSPropertyDescriptor;
  const HasTargetDescriptor = TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor);

  if TrapResult.IsUndefined then
  begin
    if not HasTargetDescriptor then
      Exit(False);

    if not TargetDescriptor.Configurable then
      raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_HIDES_NON_CONFIGURABLE, [Name]));

    if not Subject.IsExtensible then
      raise TJSErrorFactory.TypeError(Format(DESCRIPTOR_HIDES_FROM_NON_EXTENSIBLE, [Name]));

    Exit(False);
  end;

  const Definition = TJSPropertyDescriptors.ToDefinition(TrapResult);
  Descriptor := CompleteDefinition(Definition);
  RequireDescriptorMatches(Subject, Name, Descriptor, Definition);
  Result := True;
end;

function TJSProxyCore.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_DEFINE_PROPERTY);
  if not Assigned(Trap) then
    Exit(Subject.DefineOwnProperty(Name, Definition));

  const Described = DefinitionToObject(Definition);
  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name),
                                       Described]);
  Result := TrapResult.ToBoolean;
  if not Result then
    Exit;

  var TargetDescriptor: TJSPropertyDescriptor;
  const HasTargetDescriptor = TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor);
  const SettingNonConfigurable = Definition.HasConfigurable and (not Definition.Configurable);

  if not HasTargetDescriptor then
  begin
    if not Subject.IsExtensible then
      raise TJSErrorFactory.TypeError(Format(DEFINE_NON_EXTENSIBLE, [Name]));

    if SettingNonConfigurable then
      raise TJSErrorFactory.TypeError(Format(DEFINE_NON_CONFIGURABLE_MISSING, [Name]));

    Exit;
  end;

  if not IsCompatible(Subject.IsExtensible, Definition, True, TargetDescriptor) then
    raise TJSErrorFactory.TypeError(Format(DEFINE_INCOMPATIBLE, [Name]));

  if SettingNonConfigurable and TargetDescriptor.Configurable then
    raise TJSErrorFactory.TypeError(Format(DEFINE_NON_CONFIGURABLE_MISSING, [Name]));

  const IsNonConfigurableWritableData = (not TargetDescriptor.IsAccessor) and (not TargetDescriptor.Configurable) and
                                        TargetDescriptor.Writable;
  const SettingNonWritable = Definition.HasWritable and (not Definition.Writable);
  if IsNonConfigurableWritableData and SettingNonWritable then
    raise TJSErrorFactory.TypeError(Format(DEFINE_NON_WRITABLE, [Name]));
end;

function TJSProxyCore.GetWithReceiver(const Name: string; const Receiver: TJSValue): TJSValue;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_GET);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.GetWithReceiver(Subject, Name, Receiver));

  Result := InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name), Receiver]);

  var TargetDescriptor: TJSPropertyDescriptor;
  const IsLocked = TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor) and
                   (not TargetDescriptor.Configurable);
  if not IsLocked then
    Exit;

  const HidesValue = (not TargetDescriptor.IsAccessor) and (not TargetDescriptor.Writable) and
                     (not Result.SameValue(TargetDescriptor.Value));
  if HidesValue then
    raise TJSErrorFactory.TypeError(Format(GET_VALUE_MISMATCH, [Name]));

  const HidesMissingGetter = TargetDescriptor.IsAccessor and TargetDescriptor.Getter.IsUndefined and
                             (not Result.IsUndefined);
  if HidesMissingGetter then
    raise TJSErrorFactory.TypeError(Format(GET_ACCESSOR_MISMATCH, [Name]));
end;

function TJSProxyCore.SetWithReceiver(const Name: string; const Value: TJSValue; const Receiver: TJSValue): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_SET);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.SetWithReceiver(Subject, Name, Value, Receiver));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name),
                                       Value, Receiver]);
  Result := TrapResult.ToBoolean;
  if not Result then
    Exit;

  var TargetDescriptor: TJSPropertyDescriptor;
  const IsLocked = TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor) and
                   (not TargetDescriptor.Configurable);
  if not IsLocked then
    Exit;

  const ChangesValue = (not TargetDescriptor.IsAccessor) and (not TargetDescriptor.Writable) and
                       (not Value.SameValue(TargetDescriptor.Value));
  if ChangesValue then
    raise TJSErrorFactory.TypeError(Format(SET_VALUE_MISMATCH, [Name]));

  const LacksSetter = TargetDescriptor.IsAccessor and TargetDescriptor.Setter.IsUndefined;
  if LacksSetter then
    raise TJSErrorFactory.TypeError(Format(SET_ACCESSOR_MISMATCH, [Name]));
end;

function TJSProxyCore.DeleteOwnProperty(const Name: string): Boolean;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_DELETE_PROPERTY);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.DeleteOwnProperty(Subject, Name));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSObjectOperations.KeyToValue(Name)]);
  Result := TrapResult.ToBoolean;
  if not Result then
    Exit;

  var TargetDescriptor: TJSPropertyDescriptor;
  if not TJSObjectOperations.TryGetOwnProperty(Subject, Name, TargetDescriptor) then
    Exit;

  if not TargetDescriptor.Configurable then
    raise TJSErrorFactory.TypeError(Format(DELETE_NON_CONFIGURABLE, [Name]));

  if not Subject.IsExtensible then
    raise TJSErrorFactory.TypeError(Format(DELETE_NON_EXTENSIBLE, [Name]));
end;

function TJSProxyCore.KeyFromValue(const Item: TJSValue): string;
begin
  if Item.IsString then
    Exit(Item.AsString);

  const IsSymbolValue = Item.IsSymbol;
  if not IsSymbolValue then
    raise TJSErrorFactory.TypeError(KEYS_INVALID_ELEMENT);

  if not Assigned(FSymbols) then
    FSymbols := TDictionary<string, IJSSymbol>.Create;

  var Symbol: IJSSymbol;
  if Supports(Item.AsObject, IJSSymbol, Symbol) then
    FSymbols.AddOrSetValue(Item.AsSymbolKey, Symbol);

  Result := Item.AsSymbolKey;
end;

function TJSProxyCore.ReadKeyList(const Source: TJSValue): TArray<string>;
begin
  if not Source.IsObject then
    raise TJSErrorFactory.TypeError(KEYS_NOT_AN_OBJECT);

  const List = Source.ToObject;
  const Count = TJSArrayLike.ToLength(List);
  SetLength(Result, Count);

  for var Position := 0 to Count - 1 do
  begin
    Result[Position] := KeyFromValue(List.GetProperty(TJSArrayLike.IndexName(Position)));
  end;
end;

procedure TJSProxyCore.CheckOwnKeys(const Keys: TArray<string>);
begin
  const Seen = TDictionary<string, Boolean>.Create;
  try
    for var Key in Keys do
    begin
      if Seen.ContainsKey(Key) then
        raise TJSErrorFactory.TypeError(KEYS_DUPLICATE);

      Seen.Add(Key, True);
    end;
  finally
    Seen.Free;
  end;
end;

procedure TJSProxyCore.CheckOwnKeysAgainstTarget(const Subject: IJSObject; const Keys: TArray<string>);
begin
  const IsTargetExtensible = Subject.IsExtensible;
  const TargetKeys = TJSObjectOperations.OwnKeys(Subject);

  const Unchecked = TDictionary<string, Boolean>.Create;
  const Configurable = TList<string>.Create;
  const NonConfigurable = TList<string>.Create;
  try
    for var Key in Keys do
    begin
      Unchecked.Add(Key, True);
    end;

    for var Key in TargetKeys do
    begin
      var Descriptor: TJSPropertyDescriptor;
      const IsLocked = TJSObjectOperations.TryGetOwnProperty(Subject, Key, Descriptor) and
                       (not Descriptor.Configurable);
      if IsLocked then
        NonConfigurable.Add(Key)
      else
        Configurable.Add(Key);
    end;

    if IsTargetExtensible and (NonConfigurable.Count = 0) then
      Exit;

    for var Key in NonConfigurable do
    begin
      if not Unchecked.ContainsKey(Key) then
        raise TJSErrorFactory.TypeError(Format(KEYS_MISSING_NON_CONFIGURABLE, [Key]));

      Unchecked.Remove(Key);
    end;

    if IsTargetExtensible then
      Exit;

    for var Key in Configurable do
    begin
      if not Unchecked.ContainsKey(Key) then
        raise TJSErrorFactory.TypeError(Format(KEYS_MISSING_FROM_NON_EXTENSIBLE, [Key]));

      Unchecked.Remove(Key);
    end;

    if Unchecked.Count > 0 then
      raise TJSErrorFactory.TypeError(KEYS_EXTRA_FOR_NON_EXTENSIBLE);
  finally
    NonConfigurable.Free;
    Configurable.Free;
    Unchecked.Free;
  end;
end;

function TJSProxyCore.OwnKeys: TArray<string>;
begin
  const Subject = FTarget;

  const Trap = GetTrap(TRAP_OWN_KEYS);
  if not Assigned(Trap) then
    Exit(TJSObjectOperations.OwnKeys(Subject));

  const TrapResult = InvokeTrap(Trap, [TJSValue.CreateObject(Subject)]);
  Result := ReadKeyList(TrapResult);
  CheckOwnKeys(Result);
  CheckOwnKeysAgainstTarget(Subject, Result);
end;

function TJSProxyCore.GetProxyTarget: IJSObject;
begin
  Result := FTarget;
end;

function TJSProxyCore.GetProxyHandler: IJSObject;
begin
  Result := FHandler;
end;

function TJSProxyCore.IsArrayProxy: Boolean;
begin
  const Subject = FTarget;

  RequireLive('IsArray');

  Result := TJSObjectOperations.IsArray(TJSValue.CreateObject(Subject));
end;

function TJSProxyCore.Call(const ThisObj: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Subject = FTarget;
  const SubjectFunction = FTargetFunction;

  const Trap = GetTrap(TRAP_APPLY);
  if not Assigned(SubjectFunction) then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);

  if not Assigned(Trap) then
    Exit(SubjectFunction.Call(ThisObj, Args));

  Result := InvokeTrap(Trap, [TJSValue.CreateObject(Subject), TJSProxyShared.ObjectOrUndefined(ThisObj), ArrayFromList(Args)]);
end;

function TJSProxyCore.Construct(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  const Subject = FTarget;
  const SubjectFunction = FTargetFunction;

  const Trap = GetTrap(TRAP_CONSTRUCT);
  if not Assigned(SubjectFunction) then
    raise TJSErrorFactory.TypeError(NOT_CALLABLE);

  if not Assigned(Trap) then
    Exit(FRuntime.Construct(SubjectFunction, Args, NewTarget));

  Result := InvokeTrap(Trap, [TJSValue.CreateObject(Subject), ArrayFromList(Args),
                              TJSValue.CreateObject(NewTarget)]);
  if not Result.IsObject then
    raise TJSErrorFactory.TypeError(CONSTRUCT_RESULT);
end;

{ TJSProxyShared }

class function TJSProxyShared.IsCallable(const Value: TJSValue; out Func: IJSFunction): Boolean;
begin
  Result := Value.IsFunction and Supports(Value.ToObject, IJSFunction, Func);
end;

class function TJSProxyShared.SameObject(const Left: IJSObject; const Right: IJSObject): Boolean;
begin
  Result := (Left as IInterface) = (Right as IInterface);
end;

class function TJSProxyShared.ObjectOrNull(const Value: IJSObject): TJSValue;
begin
  if Assigned(Value) then
    Result := TJSValue.CreateObject(Value)
  else
    Result := TJSValue.CreateNull;
end;

class function TJSProxyShared.ObjectOrUndefined(const Value: IJSObject): TJSValue;
begin
  if Assigned(Value) then
    Result := TJSValue.CreateObject(Value)
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSProxyShared.FirstArgument(const Args: TArray<TJSValue>): TJSValue;
begin
  if Length(Args) > 0 then
    Result := Args[0]
  else
    Result := TJSValue.CreateUndefined;
end;

class function TJSProxyShared.ToDefinition(const Descriptor: TJSPropertyDescriptor): TJSPropertyDefinition;
begin
  Result := Default(TJSPropertyDefinition);
  Result.HasEnumerable := True;
  Result.Enumerable := Descriptor.Enumerable;
  Result.HasConfigurable := True;
  Result.Configurable := Descriptor.Configurable;

  if Descriptor.IsAccessor then
  begin
    Result.HasGetter := True;
    Result.Getter := Descriptor.Getter;
    Result.HasSetter := True;
    Result.Setter := Descriptor.Setter;
    Exit;
  end;

  Result.HasValue := True;
  Result.Value := Descriptor.Value;
  Result.HasWritable := True;
  Result.Writable := Descriptor.Writable;
end;

class function TJSProxyShared.StringKeys(const Keys: TArray<string>): TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    for var Key in Keys do
    begin
      if not TJSSymbolRegistry.IsKey(Key) then
        Names.Add(Key);
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

class function TJSProxyShared.SymbolKeys(const Keys: TArray<string>): TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    for var Key in Keys do
    begin
      if TJSSymbolRegistry.IsKey(Key) then
        Names.Add(Key);
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

class function TJSProxyShared.InheritedAccessor(const Proxy: IJSProxy; const Name: string): TJSPropertyDescriptor;
begin
  const Getter = TJSFunction.CreateNative(INHERITED_ACCESSOR,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Proxy.GetWithReceiver(Name, TJSProxyShared.ObjectOrUndefined(This));
    end);

  const Setter = TJSFunction.CreateNative(INHERITED_ACCESSOR,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const IsAssigned = Proxy.SetWithReceiver(Name, TJSProxyShared.FirstArgument(Args), TJSProxyShared.ObjectOrUndefined(This));
      Result := TJSValue.CreateBoolean(IsAssigned);
    end);

  Result := Default(TJSPropertyDescriptor);
  Result.IsAccessor := True;
  Result.Enumerable := True;
  Result.Configurable := True;
  Result.Getter := TJSValue.CreateObject(Getter);
  Result.Setter := TJSValue.CreateObject(Setter);
end;

class procedure TJSProxyShared.DefineOrRaise(const Core: TJSProxyCore; const Name: string;
                                             const Definition: TJSPropertyDefinition);
begin
  if not Core.DefineOwnProperty(Name, Definition) then
    raise TJSErrorFactory.TypeError(Format(PROPERTY_NOT_DEFINED, [Name]));
end;

class function TJSProxyShared.TestIntegrity(const Core: TJSProxyCore; const Level: TJSIntegrityLevel): Boolean;
begin
  if Core.IsExtensible then
    Exit(False);

  for var Key in Core.OwnKeys do
  begin
    var Descriptor: TJSPropertyDescriptor;
    if not Core.TryGetOwnProperty(Key, Descriptor) then
      Continue;

    if Descriptor.Configurable then
      Exit(False);

    const IsWritableData = (Level = TJSIntegrityLevel.Frozen) and (not Descriptor.IsAccessor) and
                           Descriptor.Writable;
    if IsWritableData then
      Exit(False);
  end;

  Result := True;
end;

class procedure TJSProxyShared.SetIntegrity(const Core: TJSProxyCore; const Level: TJSIntegrityLevel);
begin
  if not Core.TryPreventExtensions then
    raise TJSErrorFactory.TypeError(PREVENT_FAILED);

  for var Key in Core.OwnKeys do
  begin
    var Definition := Default(TJSPropertyDefinition);
    Definition.HasConfigurable := True;

    if Level = TJSIntegrityLevel.Frozen then
    begin
      var Descriptor: TJSPropertyDescriptor;
      if not Core.TryGetOwnProperty(Key, Descriptor) then
        Continue;

      Definition.HasWritable := not Descriptor.IsAccessor;
    end;

    DefineOrRaise(Core, Key, Definition);
  end;
end;

{ TJSProxyObject }

constructor TJSProxyObject.Create(const Core: TJSProxyCore);
begin
  inherited Create;

  FProxyRef := Core;
  FCore := Core;
end;

destructor TJSProxyObject.Destroy;
begin
  FCore := nil;
  FProxyRef := nil;
  inherited;
end;

function TJSProxyObject.SelfValue: TJSValue;
begin
  Result := TJSValue.CreateObject(Self);
end;

function TJSProxyObject.GetPrototype: IJSObject;
begin
  Result := FCore.GetPrototypeOf;
end;

procedure TJSProxyObject.SetPrototype(const Value: IJSObject);
begin
  if not FCore.SetPrototypeOf(Value) then
    raise TJSErrorFactory.TypeError(SET_PROTOTYPE_FAILED);
end;

function TJSProxyObject.HasProperty(const Name: string): Boolean;
begin
  Result := FCore.HasProperty(Name);
end;

function TJSProxyObject.GetProperty(const Name: string): TJSValue;
begin
  Result := FCore.GetWithReceiver(Name, SelfValue);
end;

procedure TJSProxyObject.SetProperty(const Name: string; const Value: TJSValue);
begin
  FCore.SetWithReceiver(Name, Value, SelfValue);
end;

procedure TJSProxyObject.DeleteProperty(const Name: string);
begin
  FCore.DeleteOwnProperty(Name);
end;

function TJSProxyObject.IsPropertyConfigurable(const Name: string): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := (not FCore.TryGetOwnProperty(Name, Descriptor)) or Descriptor.Configurable;
end;

function TJSProxyObject.GetOwnPropertyNames: TArray<string>;
begin
  Result := TJSProxyShared.StringKeys(FCore.OwnKeys);
end;

function TJSProxyObject.GetOwnSymbolKeys: TArray<string>;
begin
  Result := TJSProxyShared.SymbolKeys(FCore.OwnKeys);
end;

function TJSProxyObject.IsFrozen: Boolean;
begin
  Result := TJSProxyShared.TestIntegrity(FCore, TJSIntegrityLevel.Frozen);
end;

function TJSProxyObject.IsSealed: Boolean;
begin
  Result := TJSProxyShared.TestIntegrity(FCore, TJSIntegrityLevel.Sealed);
end;

function TJSProxyObject.IsExtensible: Boolean;
begin
  Result := FCore.IsExtensible;
end;

procedure TJSProxyObject.Freeze;
begin
  TJSProxyShared.SetIntegrity(FCore, TJSIntegrityLevel.Frozen);
end;

procedure TJSProxyObject.Seal;
begin
  TJSProxyShared.SetIntegrity(FCore, TJSIntegrityLevel.Sealed);
end;

procedure TJSProxyObject.PreventExtensions;
begin
  if not FCore.TryPreventExtensions then
    raise TJSErrorFactory.TypeError(PREVENT_FAILED);
end;

function TJSProxyObject.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  if FCore.TryGetOwnProperty(Name, Result) then
    Exit;

  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
end;

function TJSProxyObject.HasOwnProperty(const Name: string): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := FCore.TryGetOwnProperty(Name, Descriptor);
end;

procedure TJSProxyObject.DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);
begin
  FCore.DefineOwnProperty(Name, TJSProxyShared.ToDefinition(Descriptor));
end;

function TJSProxyObject.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  Result := FCore.DefineOwnProperty(Name, Definition);
end;

function TJSProxyObject.IsInvalidIndexKey(const Name: string): Boolean;
begin
  Result := False;
end;

function TJSProxyObject.TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Descriptor := TJSProxyShared.InheritedAccessor(FProxyRef, Name);
  Result := True;
end;

{ TJSProxyFunction }

constructor TJSProxyFunction.Create(const Core: TJSProxyCore; const IsConstructorTarget: Boolean);
begin
  inherited CreateNative('', nil);

  NativeFunction :=
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FCore.Call(This, Args);
    end;

  FProxyRef := Core;
  FCore := Core;
  IsConstructor := IsConstructorTarget;
end;

destructor TJSProxyFunction.Destroy;
begin
  FCore := nil;
  FProxyRef := nil;
  inherited;
end;

function TJSProxyFunction.SelfValue: TJSValue;
begin
  Result := TJSValue.CreateObject(Self);
end;

function TJSProxyFunction.ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  if Assigned(NewTarget) then
    Exit(FCore.Construct(Args, NewTarget));

  Result := FCore.Construct(Args, Self);
end;

function TJSProxyFunction.GetPrototype: IJSObject;
begin
  if not Assigned(FCore) then
    Exit(inherited GetPrototype);

  Result := FCore.GetPrototypeOf;
end;

procedure TJSProxyFunction.SetPrototype(const Value: IJSObject);
begin
  if not Assigned(FCore) then
  begin
    inherited;
    Exit;
  end;

  if not FCore.SetPrototypeOf(Value) then
    raise TJSErrorFactory.TypeError(SET_PROTOTYPE_FAILED);
end;

function TJSProxyFunction.HasProperty(const Name: string): Boolean;
begin
  Result := FCore.HasProperty(Name);
end;

function TJSProxyFunction.GetProperty(const Name: string): TJSValue;
begin
  Result := FCore.GetWithReceiver(Name, SelfValue);
end;

procedure TJSProxyFunction.SetProperty(const Name: string; const Value: TJSValue);
begin
  FCore.SetWithReceiver(Name, Value, SelfValue);
end;

procedure TJSProxyFunction.DeleteProperty(const Name: string);
begin
  FCore.DeleteOwnProperty(Name);
end;

function TJSProxyFunction.IsPropertyConfigurable(const Name: string): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := (not FCore.TryGetOwnProperty(Name, Descriptor)) or Descriptor.Configurable;
end;

function TJSProxyFunction.GetOwnPropertyNames: TArray<string>;
begin
  Result := TJSProxyShared.StringKeys(FCore.OwnKeys);
end;

function TJSProxyFunction.GetOwnSymbolKeys: TArray<string>;
begin
  Result := TJSProxyShared.SymbolKeys(FCore.OwnKeys);
end;

function TJSProxyFunction.IsFrozen: Boolean;
begin
  Result := TJSProxyShared.TestIntegrity(FCore, TJSIntegrityLevel.Frozen);
end;

function TJSProxyFunction.IsSealed: Boolean;
begin
  Result := TJSProxyShared.TestIntegrity(FCore, TJSIntegrityLevel.Sealed);
end;

function TJSProxyFunction.IsExtensible: Boolean;
begin
  Result := FCore.IsExtensible;
end;

procedure TJSProxyFunction.Freeze;
begin
  TJSProxyShared.SetIntegrity(FCore, TJSIntegrityLevel.Frozen);
end;

procedure TJSProxyFunction.Seal;
begin
  TJSProxyShared.SetIntegrity(FCore, TJSIntegrityLevel.Sealed);
end;

procedure TJSProxyFunction.PreventExtensions;
begin
  if not FCore.TryPreventExtensions then
    raise TJSErrorFactory.TypeError(PREVENT_FAILED);
end;

function TJSProxyFunction.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  if FCore.TryGetOwnProperty(Name, Result) then
    Exit;

  Result := Default(TJSPropertyDescriptor);
  Result.Value := TJSValue.CreateUndefined;
end;

function TJSProxyFunction.HasOwnProperty(const Name: string): Boolean;
begin
  var Descriptor: TJSPropertyDescriptor;
  Result := FCore.TryGetOwnProperty(Name, Descriptor);
end;

procedure TJSProxyFunction.DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);
begin
  if not Assigned(FCore) then
  begin
    inherited;
    Exit;
  end;

  FCore.DefineOwnProperty(Name, TJSProxyShared.ToDefinition(Descriptor));
end;

function TJSProxyFunction.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  Result := FCore.DefineOwnProperty(Name, Definition);
end;

function TJSProxyFunction.IsInvalidIndexKey(const Name: string): Boolean;
begin
  Result := False;
end;

function TJSProxyFunction.TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Descriptor := TJSProxyShared.InheritedAccessor(FProxyRef, Name);
  Result := True;
end;

{ TJSProxyFactory }

class function TJSProxyFactory.Create(const Runtime: IJSProxyRuntime; const Target: IJSObject;
                                      const Handler: IJSObject): IJSObject;
begin
  const Core = TJSProxyCore.Create(Runtime, Target, Handler);

  var TargetFunction: IJSFunction;
  if Supports(Target, IJSFunction, TargetFunction) then
    Result := TJSProxyFunction.Create(Core, TargetFunction.IsConstructor)
  else
    Result := TJSProxyObject.Create(Core);
end;

end.
