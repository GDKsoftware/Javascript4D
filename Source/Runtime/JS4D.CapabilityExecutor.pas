unit JS4D.CapabilityExecutor;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.BuiltinSupport;

type
  IJSCapabilityExecutor = interface
    ['{7E2B5A94-D3C1-4F86-9A05-B18C6D4E2F73}']
    function GetResolve: TJSValue;
    function GetReject: TJSValue;
    function Execute(const Args: TArray<TJSValue>): TJSValue;
    property Resolve: TJSValue read GetResolve;
    property Reject: TJSValue read GetReject;
  end;

  TJSCapabilityExecutor = class(TInterfacedObject, IJSCapabilityExecutor)
  private
    const
      EXECUTOR_ALREADY_CALLED = 'Promise executor has already been invoked with non-undefined arguments';

    var
      FResolve: TJSValue;
      FReject: TJSValue;

    function GetResolve: TJSValue;
    function GetReject: TJSValue;

  public
    constructor Create;

    function Execute(const Args: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.Errors;

constructor TJSCapabilityExecutor.Create;
begin
  inherited Create;

  FResolve := TJSValue.CreateUndefined;
  FReject := TJSValue.CreateUndefined;
end;

function TJSCapabilityExecutor.GetResolve: TJSValue;
begin
  Result := FResolve;
end;

function TJSCapabilityExecutor.GetReject: TJSValue;
begin
  Result := FReject;
end;

function TJSCapabilityExecutor.Execute(const Args: TArray<TJSValue>): TJSValue;
begin
  const IsUsed = ((not FResolve.IsUndefined) or (not FReject.IsUndefined));
  if IsUsed then
    raise TJSErrorFactory.TypeError(EXECUTOR_ALREADY_CALLED);

  FResolve := TJSArrayLike.Argument(Args, 0);
  FReject := TJSArrayLike.Argument(Args, 1);
  Result := TJSValue.CreateUndefined;
end;

end.
