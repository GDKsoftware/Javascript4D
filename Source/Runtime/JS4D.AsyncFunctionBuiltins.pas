unit JS4D.AsyncFunctionBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.PromiseOperations,
  JS4D.AsyncRunner;

type
  // %AsyncFunction% and %AsyncFunction.prototype%, and the runner that gives async functions their promises.
  TJSAsyncFunctionBuiltins = class
  private
    const
      ASYNC_FUNCTION_NAME = 'AsyncFunction';
      CONSTRUCTOR_NAME = 'constructor';
      PROTOTYPE_NAME = 'prototype';
      FUNCTION_NAME = 'Function';
      ANONYMOUS_NAME = 'anonymous';
      SOURCE_FORMAT = '(async function (%s' + sLineBreak + ') {' + sLineBreak + '%s' + sLineBreak + '})';
      TEXT_FORMAT = 'async function anonymous(%s'#10') {'#10'%s'#10'}';

    var
      FInterpreter: TJSInterpreter;
      FRunner: TJSAsyncRunner;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    class procedure DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue); static;
    function ToText(const Value: TJSValue): string;
    function CreateFunctionFromArguments(const Args: TArray<TJSValue>): TJSValue;
    procedure CreatePrototype;
    procedure CreateConstructor;

  public
    constructor Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.SymbolRegistry;

constructor TJSAsyncFunctionBuiltins.Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FRunner := TJSAsyncRunner.Create(Interpreter, Operations);
end;

destructor TJSAsyncFunctionBuiltins.Destroy;
begin
  if Assigned(FPrototype) then
    FPrototype.DeleteProperty(CONSTRUCTOR_NAME);

  FRunner.Free;
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

class procedure TJSAsyncFunctionBuiltins.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey;
                                                      const Value: TJSValue);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

function TJSAsyncFunctionBuiltins.ToText(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.String_);

  Result := Primitive.ToLimitedString(FInterpreter.Limits);
end;

function TJSAsyncFunctionBuiltins.CreateFunctionFromArguments(const Args: TArray<TJSValue>): TJSValue;
begin
  var Body := '';
  var Parameters := '';

  const HasArguments = (Length(Args) > 0);
  if HasArguments then
  begin
    for var Index := 0 to High(Args) - 1 do
    begin
      if Index > 0 then
        Parameters := Parameters + ',';

      Parameters := Parameters + ToText(Args[Index]);
    end;

    Body := ToText(Args[High(Args)]);
  end;

  Result := FInterpreter.CreateFunctionFromSource(Format(SOURCE_FORMAT, [Parameters, Body]));

  var Func: IJSFunction;
  const IsFunction = Supports(Result.ToObject, IJSFunction, Func);
  if IsFunction then
  begin
    Func.Name := ANONYMOUS_NAME;
    Func.SourceText := Format(TEXT_FORMAT, [Parameters, Body]);
  end;
end;

procedure TJSAsyncFunctionBuiltins.CreatePrototype;
begin
  FPrototype := TJSObject.Create;
  FPrototype.Prototype := FInterpreter.FunctionPrototype;

  const TagKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);
  DefineMember(FPrototype, TagKey, TJSValue.CreateString(ASYNC_FUNCTION_NAME));
end;

procedure TJSAsyncFunctionBuiltins.CreateConstructor;
begin
  FConstructor := TJSFunction.CreateNative(ASYNC_FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateFunctionFromArguments(Args);
    end);
  FConstructor.Prototype := FInterpreter.GetGlobalVariable(FUNCTION_NAME).ToObject;
  TJSFunction.DefineLength(FConstructor, 1);
  FConstructor.SetNonConfigurableProperty(PROTOTYPE_NAME, TJSValue.CreateObject(FPrototype));
  FInterpreter.RegisterFunction(FConstructor);

  DefineMember(FPrototype, CONSTRUCTOR_NAME, TJSValue.CreateObject(FConstructor));
end;

procedure TJSAsyncFunctionBuiltins.Register;
begin
  CreatePrototype;
  CreateConstructor;

  FInterpreter.AsyncFunctionPrototype := FPrototype;
  FInterpreter.AsyncHost := FRunner;
end;

end.
