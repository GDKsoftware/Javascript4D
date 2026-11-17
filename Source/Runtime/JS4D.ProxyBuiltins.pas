unit JS4D.ProxyBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BuiltinSupport,
  JS4D.ObjectOperations,
  JS4D.ProxyObjects;

type
  TJSProxyBuiltins = class(TJSBuiltinSet)
  private
    const
      PROXY_NAME = 'Proxy';
      REVOCABLE_NAME = 'revocable';
      PROXY_PROPERTY = 'proxy';
      REVOKE_PROPERTY = 'revoke';
      REVOKER_NAME = '';
      TARGET_NOT_AN_OBJECT = 'Cannot create proxy with a non-object as target';
      HANDLER_NOT_AN_OBJECT = 'Cannot create proxy with a non-object as handler';

    var
      FInterpreter: TJSInterpreter;
      FRuntime: IJSProxyRuntime;
      FSupport: TJSBuiltinSupport;

    procedure DefineLengthBeforeName(const Func: IJSFunction; const ParameterCount: Integer);
    function CreateProxy(const Target: TJSValue; const Handler: TJSValue): IJSObject;
    function CreateRevoker(const Proxy: IJSObject): IJSFunction;
    function CreateRevocable(const Args: TArray<TJSValue>): TJSValue;
    function CreateConstructor: IJSFunction;
    procedure DefineRevocable(const Constructor_: IJSFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.PropertyNames;

constructor TJSProxyBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSProxyBuiltins.Destroy;
begin
  if Assigned(FRuntime) then
    FRuntime.Detach;

  FRuntime := nil;
  FSupport.Free;
  inherited;
end;

procedure TJSProxyBuiltins.DefineLengthBeforeName(const Func: IJSFunction; const ParameterCount: Integer);
begin
  const FunctionName = Func.Name;
  Func.DeleteProperty(NAME_PROPERTY);

  TJSFunction.DefineLength(Func, ParameterCount);
  TJSFunction.DefineName(Func, FunctionName);
end;

function TJSProxyBuiltins.CreateProxy(const Target: TJSValue; const Handler: TJSValue): IJSObject;
begin
  if not Target.IsObject then
    raise TJSErrorFactory.TypeError(TARGET_NOT_AN_OBJECT);

  if not Handler.IsObject then
    raise TJSErrorFactory.TypeError(HANDLER_NOT_AN_OBJECT);

  const TargetObject = Target.ToObject;
  const HandlerObject = Handler.ToObject;

  Result := TJSProxyFactory.CreateProxy(FRuntime, TargetObject, HandlerObject);
end;

function TJSProxyBuiltins.CreateRevoker(const Proxy: IJSObject): IJSFunction;
begin
  var Revocable: IJSProxy;
  Supports(Proxy, IJSProxy, Revocable);

  Result := TJSFunction.CreateNative(REVOKER_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Assigned(Revocable) then
      begin
        Revocable.Revoke;
        Revocable := nil;
      end;

      Result := TJSValue.CreateUndefined;
    end);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  DefineLengthBeforeName(Result, 0);
end;

function TJSProxyBuiltins.CreateRevocable(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = TJSArrayLike.Argument(Args, 0);
  const Handler = TJSArrayLike.Argument(Args, 1);
  const Proxy = CreateProxy(Target, Handler);
  const Revoker = CreateRevoker(Proxy);

  const Revocable: IJSObject = TJSObject.Create;
  Revocable.Prototype := FInterpreter.ObjectPrototype;
  const ProxyValue = TJSValue.CreateObject(Proxy);
  const RevokerValue = TJSValue.CreateObject(Revoker);
  Revocable.SetProperty(PROXY_PROPERTY, ProxyValue);
  Revocable.SetProperty(REVOKE_PROPERTY, RevokerValue);

  Result := TJSValue.CreateObject(Revocable);
end;

function TJSProxyBuiltins.CreateConstructor: IJSFunction;
begin
  const RequiresNewMessage = Format(CONSTRUCTOR_REQUIRES_NEW, [PROXY_NAME]);

  Result := FSupport.CreateConstructor(PROXY_NAME, 2, RequiresNewMessage,
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      const Target = TJSArrayLike.Argument(Args, 0);
      const Handler = TJSArrayLike.Argument(Args, 1);
      const Proxy = CreateProxy(Target, Handler);

      Result := TJSValue.CreateObject(Proxy);
    end);
end;

procedure TJSProxyBuiltins.DefineRevocable(const Constructor_: IJSFunction);
begin
  const Revocable = TJSFunction.CreateNative(REVOCABLE_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateRevocable(Args);
    end);
  Revocable.IsConstructor := False;
  Revocable.Prototype := FInterpreter.FunctionPrototype;
  DefineLengthBeforeName(Revocable, 2);
  FInterpreter.RegisterFunction(Revocable);

  const RevocableValue = TJSValue.CreateObject(Revocable);
  var Descriptor := TJSPropertyDescriptor.Create(RevocableValue);
  Descriptor.Enumerable := False;
  Constructor_.DefineProperty(REVOCABLE_NAME, Descriptor);
end;

procedure TJSProxyBuiltins.Register;
begin
  FRuntime := TJSProxyRuntime.Create(FInterpreter.ObjectPrototype, FInterpreter.ArrayPrototype,
    function(const Target: IJSFunction; const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      Result := FInterpreter.Construct(Target, Args, NewTarget);
    end,
    procedure
    begin
      FInterpreter.ConsumeStep;
    end,
    procedure(Count: Int64)
    begin
      FInterpreter.Limits.EnsureArrayLength(Count);
    end);

  const Constructor_ = CreateConstructor;
  DefineRevocable(Constructor_);
  const ConstructorValue = TJSValue.CreateObject(Constructor_);
  FInterpreter.SetGlobalVariable(PROXY_NAME, ConstructorValue);
end;

end.
