unit JS4D.ProxyBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.ObjectOperations,
  JS4D.ProxyObjects;

type
  // The Proxy constructor and Proxy.revocable.
  TJSProxyBuiltins = class
  private
    const
      PROXY_NAME = 'Proxy';
      REVOCABLE_NAME = 'revocable';
      PROXY_PROPERTY = 'proxy';
      REVOKE_PROPERTY = 'revoke';
      NAME_PROPERTY = 'name';
      REQUIRES_NEW = 'Constructor Proxy requires ''new''';
      TARGET_NOT_AN_OBJECT = 'Cannot create proxy with a non-object as target';
      HANDLER_NOT_AN_OBJECT = 'Cannot create proxy with a non-object as handler';

    var
      FInterpreter: TJSInterpreter;
      FRuntime: IJSProxyRuntime;

    procedure DefineLengthBeforeName(const Func: IJSFunction; const ParameterCount: Integer);
    function CreateProxy(const Target: TJSValue; const Handler: TJSValue): IJSObject;
    function CreateRevoker(const Proxy: IJSObject): IJSFunction;
    function CreateRevocable(const Args: TArray<TJSValue>): TJSValue;
    function CreateConstructor: IJSFunction;
    procedure DefineRevocable(const Constructor_: IJSFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayLike;

constructor TJSProxyBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

destructor TJSProxyBuiltins.Destroy;
begin
  if Assigned(FRuntime) then
    FRuntime.Detach;

  FRuntime := nil;
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

  Result := TJSProxyFactory.Create(FRuntime, Target.ToObject, Handler.ToObject);
end;

function TJSProxyBuiltins.CreateRevoker(const Proxy: IJSObject): IJSFunction;
begin
  var Revocable: IJSProxy;
  Supports(Proxy, IJSProxy, Revocable);

  Result := TJSFunction.CreateNative('',
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
  const Proxy = CreateProxy(TJSArrayLike.Argument(Args, 0), TJSArrayLike.Argument(Args, 1));

  const Revocable: IJSObject = TJSObject.Create;
  Revocable.Prototype := FInterpreter.ObjectPrototype;
  Revocable.SetProperty(PROXY_PROPERTY, TJSValue.CreateObject(Proxy));
  Revocable.SetProperty(REVOKE_PROPERTY, TJSValue.CreateObject(CreateRevoker(Proxy)));

  Result := TJSValue.CreateObject(Revocable);
end;

function TJSProxyBuiltins.CreateConstructor: IJSFunction;
begin
  Result := TJSConstructorFunction.CreateConstructor(PROXY_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      raise TJSErrorFactory.TypeError(REQUIRES_NEW);
    end,
    function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue
    begin
      const Proxy = CreateProxy(TJSArrayLike.Argument(Args, 0), TJSArrayLike.Argument(Args, 1));
      Result := TJSValue.CreateObject(Proxy);
    end);
  Result.Prototype := FInterpreter.FunctionPrototype;
  DefineLengthBeforeName(Result, 2);
  FInterpreter.RegisterFunction(Result);
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

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Revocable));
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
      FInterpreter.ChargeStep;
    end);

  const Constructor_ = CreateConstructor;
  DefineRevocable(Constructor_);
  FInterpreter.SetGlobalVariable(PROXY_NAME, TJSValue.CreateObject(Constructor_));
end;

end.
