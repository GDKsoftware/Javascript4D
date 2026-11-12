unit JS4D.GeneratorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.GeneratorObjects;

type
  // %GeneratorFunction%, %GeneratorFunction.prototype% and %GeneratorPrototype% with next, return and throw.
  TJSGeneratorBuiltins = class
  private
    const
      GENERATOR_FUNCTION_NAME = 'GeneratorFunction';
      GENERATOR_TAG = 'Generator';
      NEXT_NAME = 'next';
      RETURN_NAME = 'return';
      THROW_NAME = 'throw';
      CONSTRUCTOR_NAME = 'constructor';
      PROTOTYPE_NAME = 'prototype';
      FUNCTION_NAME = 'Function';
      ANONYMOUS_NAME = 'anonymous';
      SOURCE_FORMAT = '(function* (%s' + sLineBreak + ') {' + sLineBreak + '%s' + sLineBreak + '})';
      TEXT_FORMAT = 'function* anonymous(%s'#10') {'#10'%s'#10'}';
      NOT_A_GENERATOR = '%s method called on an object that is not a generator';

    var
      FInterpreter: TJSInterpreter;
      FIteratorPrototype: IJSObject;
      FPrototype: IJSObject;
      FFunctionPrototype: IJSObject;
      FConstructor: IJSFunction;

    class procedure DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                 const IsWritable: Boolean); static;
    class function ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue; static;
    function CreateMethod(const Name: string; const Method: TNativeFunction): IJSFunction;
    function ToText(const Value: TJSValue): string;
    function Resume(const This: IJSObject; const MethodName: string; const Mode: TJSResumeMode;
                    const Args: TArray<TJSValue>): TJSValue;
    function CreateResumeMethod(const Name: string; const Mode: TJSResumeMode): IJSFunction;
    function CreateGeneratorFromSource(const Args: TArray<TJSValue>): TJSValue;
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    procedure CreateGeneratorPrototype;
    procedure CreateGeneratorFunctionPrototype;
    procedure CreateConstructor;

  public
    constructor Create(const Interpreter: TJSInterpreter; const IteratorPrototype: IJSObject);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.SymbolRegistry;

constructor TJSGeneratorBuiltins.Create(const Interpreter: TJSInterpreter; const IteratorPrototype: IJSObject);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FIteratorPrototype := IteratorPrototype;
end;

destructor TJSGeneratorBuiltins.Destroy;
begin
  if Assigned(FPrototype) then
    FPrototype.DeleteProperty(CONSTRUCTOR_NAME);

  if Assigned(FFunctionPrototype) then
  begin
    FFunctionPrototype.DeleteProperty(PROTOTYPE_NAME);
    FFunctionPrototype.DeleteProperty(CONSTRUCTOR_NAME);
  end;

  FConstructor := nil;
  FFunctionPrototype := nil;
  FPrototype := nil;
  FIteratorPrototype := nil;
  inherited;
end;

class procedure TJSGeneratorBuiltins.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey;
                                                  const Value: TJSValue; const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

class function TJSGeneratorBuiltins.ArgumentAt(const Args: TArray<TJSValue>; const Index: Integer): TJSValue;
begin
  if Index < Length(Args) then
    Exit(Args[Index]);

  Result := TJSValue.CreateUndefined;
end;

function TJSGeneratorBuiltins.ToText(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.String_);

  Result := Primitive.ToLimitedString(FInterpreter.Limits);
end;

function TJSGeneratorBuiltins.CreateMethod(const Name: string; const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, 1);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSGeneratorBuiltins.DefineToStringTag(const Target: IJSObject; const Tag: string);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);

  DefineMember(Target, Key, TJSValue.CreateString(Tag), False);
end;

function TJSGeneratorBuiltins.Resume(const This: IJSObject; const MethodName: string; const Mode: TJSResumeMode;
                                     const Args: TArray<TJSValue>): TJSValue;
begin
  var Generator: IJSGenerator;
  const IsGenerator = Assigned(This) and Supports(This, IJSGenerator, Generator);
  if not IsGenerator then
    raise TJSErrorFactory.TypeError(Format(NOT_A_GENERATOR, [MethodName]));

  Result := FInterpreter.ResumeGenerator((This as TObject) as TJSGeneratorObject, Mode, ArgumentAt(Args, 0));
end;

function TJSGeneratorBuiltins.CreateResumeMethod(const Name: string; const Mode: TJSResumeMode): IJSFunction;
begin
  Result := CreateMethod(Name,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Resume(This, Name, Mode, Args);
    end);
end;

procedure TJSGeneratorBuiltins.CreateGeneratorPrototype;
begin
  FPrototype := TJSObject.Create;
  FPrototype.Prototype := FIteratorPrototype;

  DefineMember(FPrototype, NEXT_NAME, TJSValue.CreateObject(CreateResumeMethod(NEXT_NAME, TJSResumeMode.Next)), True);
  DefineMember(FPrototype, RETURN_NAME, TJSValue.CreateObject(CreateResumeMethod(RETURN_NAME, TJSResumeMode.Return)), True);
  DefineMember(FPrototype, THROW_NAME, TJSValue.CreateObject(CreateResumeMethod(THROW_NAME, TJSResumeMode.Throw)), True);
  DefineToStringTag(FPrototype, GENERATOR_TAG);
end;

procedure TJSGeneratorBuiltins.CreateGeneratorFunctionPrototype;
begin
  FFunctionPrototype := TJSObject.Create;
  FFunctionPrototype.Prototype := FInterpreter.FunctionPrototype;

  DefineMember(FFunctionPrototype, PROTOTYPE_NAME, TJSValue.CreateObject(FPrototype), False);
  DefineMember(FPrototype, CONSTRUCTOR_NAME, TJSValue.CreateObject(FFunctionPrototype), False);
  DefineToStringTag(FFunctionPrototype, GENERATOR_FUNCTION_NAME);
end;

function TJSGeneratorBuiltins.CreateGeneratorFromSource(const Args: TArray<TJSValue>): TJSValue;
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

procedure TJSGeneratorBuiltins.CreateConstructor;
begin
  FConstructor := TJSFunction.CreateNative(GENERATOR_FUNCTION_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := CreateGeneratorFromSource(Args);
    end);
  FConstructor.Prototype := FInterpreter.GetGlobalVariable(FUNCTION_NAME).ToObject;
  TJSFunction.DefineLength(FConstructor, 1);
  FConstructor.SetNonConfigurableProperty(PROTOTYPE_NAME, TJSValue.CreateObject(FFunctionPrototype));
  FInterpreter.RegisterFunction(FConstructor);

  DefineMember(FFunctionPrototype, CONSTRUCTOR_NAME, TJSValue.CreateObject(FConstructor), False);
end;

procedure TJSGeneratorBuiltins.Register;
begin
  CreateGeneratorPrototype;
  CreateGeneratorFunctionPrototype;
  CreateConstructor;

  FInterpreter.GeneratorPrototype := FPrototype;
  FInterpreter.GeneratorFunctionPrototype := FFunctionPrototype;
end;

end.
