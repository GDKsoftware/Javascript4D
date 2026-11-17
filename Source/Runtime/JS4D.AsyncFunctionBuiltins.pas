unit JS4D.AsyncFunctionBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BuiltinSupport,
  JS4D.DynamicFunctions,
  JS4D.PromiseOperations,
  JS4D.AsyncRunner;

type
  TJSAsyncFunctionBuiltins = class
  private
    const
      ASYNC_FUNCTION_NAME = 'AsyncFunction';
      ASYNC_FUNCTION_KEYWORD = 'async function';
      CONSTRUCTOR_LENGTH = 1;
      IS_READ_ONLY = False;

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FFactory: TJSDynamicFunctionFactory;
      FRunner: TJSAsyncRunner;
      FPrototype: IJSObject;
      FConstructor: IJSFunction;

    procedure CreatePrototype;
    procedure CreateConstructor;

  public
    constructor Create(const Interpreter: TJSInterpreter; const Operations: TJSPromiseOperations);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.PropertyKey,
  JS4D.PropertyNames;

constructor TJSAsyncFunctionBuiltins.Create(const Interpreter: TJSInterpreter;
                                            const Operations: TJSPromiseOperations);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
  FFactory := TJSDynamicFunctionFactory.Create(Interpreter, ASYNC_FUNCTION_KEYWORD);
  FRunner := TJSAsyncRunner.Create(Interpreter, FSupport, Operations);
end;

destructor TJSAsyncFunctionBuiltins.Destroy;
begin
  FSupport.UnlinkConstructor(FPrototype);

  FRunner.Free;
  FFactory.Free;
  FSupport.Free;
  FConstructor := nil;
  FPrototype := nil;
  inherited;
end;

procedure TJSAsyncFunctionBuiltins.CreatePrototype;
begin
  FPrototype := TJSObject.Create;
  FPrototype.Prototype := FInterpreter.FunctionPrototype;

  FSupport.DefineToStringTag(FPrototype, ASYNC_FUNCTION_NAME);
end;

procedure TJSAsyncFunctionBuiltins.CreateConstructor;
begin
  FConstructor := TJSFunction.CreateNative(ASYNC_FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FFactory.CreateFunction(Args);
    end);

  const FunctionConstructor = FInterpreter.GetGlobalVariable(FUNCTION_NAME);
  FConstructor.Prototype := FunctionConstructor.ToObject;
  TJSFunction.DefineLength(FConstructor, CONSTRUCTOR_LENGTH);

  const PrototypeValue = TJSValue.CreateObject(FPrototype);
  FConstructor.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, PrototypeValue);
  FInterpreter.RegisterFunction(FConstructor);

  const ConstructorValue = TJSValue.CreateObject(FConstructor);
  FSupport.DefineMember(FPrototype, CONSTRUCTOR_PROPERTY, ConstructorValue, IS_READ_ONLY);
end;

procedure TJSAsyncFunctionBuiltins.Register;
begin
  CreatePrototype;
  CreateConstructor;

  FInterpreter.AsyncFunctionPrototype := FPrototype;
  FInterpreter.AsyncHost := FRunner;
end;

end.
