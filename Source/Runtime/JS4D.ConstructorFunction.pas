unit JS4D.ConstructorFunction;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types;

type
  TJSConstructHandler = reference to function(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;

  IJSNativeConstructor = interface
    ['{2B9C4D61-8F3A-4E75-A0D2-5C7E1B3F9A48}']
    function ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
  end;

  TJSConstructorFunction = class(TJSFunctionImpl, IJSNativeConstructor)
  private
    FHandler: TJSConstructHandler;

  protected
    procedure ReleaseReferences; override;

  public
    constructor CreateConstructor(const Name: string; const Func: TNativeFunction;
                                  const Handler: TJSConstructHandler);

    function ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
  end;

implementation

{ TJSConstructorFunction }

constructor TJSConstructorFunction.CreateConstructor(const Name: string; const Func: TNativeFunction;
                                                     const Handler: TJSConstructHandler);
begin
  inherited CreateNative(Name, Func);
  FHandler := Handler;
end;

procedure TJSConstructorFunction.ReleaseReferences;
begin
  FHandler := nil;
  inherited;
end;

function TJSConstructorFunction.ConstructWith(const Args: TArray<TJSValue>; const NewTarget: IJSFunction): TJSValue;
begin
  Result := FHandler(Args, NewTarget);
end;

end.
