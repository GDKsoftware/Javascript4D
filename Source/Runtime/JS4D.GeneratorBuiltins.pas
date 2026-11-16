unit JS4D.GeneratorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BinarySupport,
  JS4D.DynamicFunctions,
  JS4D.GeneratorObjects;

type
  TJSGeneratorBuiltins = class
  private
    const
      GENERATOR_FUNCTION_NAME = 'GeneratorFunction';
      GENERATOR_FUNCTION_KEYWORD = 'function*';
      GENERATOR_TAG = 'Generator';
      NEXT_NAME = 'next';
      RETURN_NAME = 'return';
      THROW_NAME = 'throw';
      CONSTRUCTOR_LENGTH = 1;
      RESUME_METHOD_LENGTH = 1;
      IS_WRITABLE = True;
      IS_READ_ONLY = False;
      NOT_A_GENERATOR = '%s method called on an object that is not a generator';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBinarySupport;
      FFactory: TJSDynamicFunctionFactory;
      FIteratorPrototype: IJSObject;
      FPrototype: IJSObject;
      FFunctionPrototype: IJSObject;
      FConstructor: IJSFunction;

    function Resume(const This: IJSObject; const MethodName: string; const Mode: TJSResumeMode;
                    const Args: TArray<TJSValue>): TJSValue;
    function CreateResumeMethod(const Name: string; const Mode: TJSResumeMode): IJSFunction;
    procedure DefineResumeMember(const Name: string; const Mode: TJSResumeMode);
    procedure CreateGeneratorPrototype;
    procedure CreateGeneratorFunctionPrototype(const Prototype: IJSObject);
    procedure CreateConstructor;

  public
    constructor Create(const Interpreter: TJSInterpreter; const IteratorPrototype: IJSObject);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.PropertyKey,
  JS4D.Errors,
  JS4D.PropertyNames;

constructor TJSGeneratorBuiltins.Create(const Interpreter: TJSInterpreter; const IteratorPrototype: IJSObject);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBinarySupport.Create(Interpreter);
  FFactory := TJSDynamicFunctionFactory.Create(Interpreter, GENERATOR_FUNCTION_KEYWORD);
  FIteratorPrototype := IteratorPrototype;
end;

destructor TJSGeneratorBuiltins.Destroy;
begin
  FSupport.UnlinkConstructor(FPrototype);

  if Assigned(FFunctionPrototype) then
  begin
    FFunctionPrototype.DeleteProperty(PROTOTYPE_PROPERTY);
    FSupport.UnlinkConstructor(FFunctionPrototype);
  end;

  FFactory.Free;
  FSupport.Free;
  FConstructor := nil;
  FFunctionPrototype := nil;
  FPrototype := nil;
  FIteratorPrototype := nil;
  inherited;
end;

function TJSGeneratorBuiltins.Resume(const This: IJSObject; const MethodName: string; const Mode: TJSResumeMode;
                                     const Args: TArray<TJSValue>): TJSValue;
begin
  const IsGenerator = (Assigned(This) and (This is TJSGeneratorObject));
  if not IsGenerator then
  begin
    const Message = Format(NOT_A_GENERATOR, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  const Generator = (This as TJSGeneratorObject);
  const Argument = TJSBinarySupport.Argument(Args, 0);

  Result := FInterpreter.GeneratorEngine.ResumeGenerator(Generator, Mode, Argument);
end;

function TJSGeneratorBuiltins.CreateResumeMethod(const Name: string; const Mode: TJSResumeMode): IJSFunction;
begin
  Result := FSupport.CreateMethod(Name, RESUME_METHOD_LENGTH,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Resume(This, Name, Mode, Args);
    end);
end;

procedure TJSGeneratorBuiltins.DefineResumeMember(const Name: string; const Mode: TJSResumeMode);
begin
  const Method = CreateResumeMethod(Name, Mode);
  const MethodValue = TJSValue.CreateObject(Method);

  FSupport.DefineMember(FPrototype, Name, MethodValue, IS_WRITABLE);
end;

procedure TJSGeneratorBuiltins.CreateGeneratorPrototype;
begin
  FPrototype := TJSObject.Create;
  FPrototype.Prototype := FIteratorPrototype;

  DefineResumeMember(NEXT_NAME, TJSResumeMode.Next);
  DefineResumeMember(RETURN_NAME, TJSResumeMode.Return);
  DefineResumeMember(THROW_NAME, TJSResumeMode.Throw);
  FSupport.DefineToStringTag(FPrototype, GENERATOR_TAG);
end;

procedure TJSGeneratorBuiltins.CreateGeneratorFunctionPrototype(const Prototype: IJSObject);
begin
  FFunctionPrototype := TJSObject.Create;
  FFunctionPrototype.Prototype := FInterpreter.FunctionPrototype;

  const PrototypeValue = TJSValue.CreateObject(Prototype);
  const FunctionPrototypeValue = TJSValue.CreateObject(FFunctionPrototype);
  FSupport.DefineMember(FFunctionPrototype, PROTOTYPE_PROPERTY, PrototypeValue, IS_READ_ONLY);
  FSupport.DefineMember(Prototype, CONSTRUCTOR_PROPERTY, FunctionPrototypeValue, IS_READ_ONLY);
  FSupport.DefineToStringTag(FFunctionPrototype, GENERATOR_FUNCTION_NAME);
end;

procedure TJSGeneratorBuiltins.CreateConstructor;
begin
  FConstructor := TJSFunction.CreateNative(GENERATOR_FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FFactory.CreateFunction(Args);
    end);

  const FunctionConstructor = FInterpreter.GetGlobalVariable(FUNCTION_NAME);
  FConstructor.Prototype := FunctionConstructor.ToObject;
  TJSFunction.DefineLength(FConstructor, CONSTRUCTOR_LENGTH);

  const PrototypeValue = TJSValue.CreateObject(FFunctionPrototype);
  FConstructor.SetNonConfigurableProperty(PROTOTYPE_PROPERTY, PrototypeValue);
  FInterpreter.RegisterFunction(FConstructor);

  const ConstructorValue = TJSValue.CreateObject(FConstructor);
  FSupport.DefineMember(FFunctionPrototype, CONSTRUCTOR_PROPERTY, ConstructorValue, IS_READ_ONLY);
end;

procedure TJSGeneratorBuiltins.Register;
begin
  CreateGeneratorPrototype;
  CreateGeneratorFunctionPrototype(FPrototype);
  CreateConstructor;

  FInterpreter.GeneratorPrototype := FPrototype;
  FInterpreter.GeneratorFunctionPrototype := FFunctionPrototype;
end;

end.
