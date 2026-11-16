unit JS4D.ClassBuilder;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.StrUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.AST,
  JS4D.Errors,
  JS4D.Scope,
  JS4D.ClassEvaluation,
  JS4D.PropertyNames,
  JS4D.Interpreter;

type
  TJSClassHeritage = record
    PrototypeParent: IJSObject;
    ConstructorParent: IJSObject;
  end;

  TJSClassBuilder = class(TJSClassEvaluation)
  private
    FInterpreter: TJSInterpreter;

    function ResolveClassHeritage(const Node: TJSClassExpression): TJSClassHeritage;
    function CreateClassConstructor(const Node: TJSClassExpression; const Prototype: IJSObject;
                                    const ConstructorParent: IJSObject; const DeclaredName: string): IJSFunction;
    procedure DefineClassMember(const Member: TJSClassMember; const ClassConstructor: IJSFunction;
                                const Prototype: IJSObject);
    procedure DefineClassMethod(const Target: IJSObject; const Key: TJSPropertyKey; const Member: TJSClassMember);
    procedure DefineClassAccessor(const Target: IJSObject; const Key: TJSPropertyKey; const Member: TJSClassMember);
    procedure DefineClassProperty(const Target: IJSObject; const Key: TJSPropertyKey;
                                  const Definition: TJSPropertyDefinition);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure BindHomeObject(const Func: IJSFunction; const Home: IJSObject); override;
    function VisitClassExpression(const Node: TJSClassExpression; const InferredName: string): TJSValue; override;
  end;

implementation

const
  CLASS_EXTENDS_NOT_CONSTRUCTOR = 'Class extends value is not a constructor or null';
  CLASS_EXTENDS_BAD_PROTOTYPE = 'Class extends value does not have a valid prototype property';
  CLASS_MEMBER_NOT_DEFINED = 'Cannot define class member ''%s''';

{ TJSClassBuilder }

constructor TJSClassBuilder.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
end;

procedure TJSClassBuilder.BindHomeObject(const Func: IJSFunction; const Home: IJSObject);
begin
  Func.HomeObject := Home;
  Func.Kind := TJSFunctionKind.Method;
end;

function TJSClassBuilder.VisitClassExpression(const Node: TJSClassExpression; const InferredName: string): TJSValue;
begin
  const OuterScope = FInterpreter.CurrentScope;
  const OuterStrictMode = FInterpreter.StrictMode;
  FInterpreter.StrictMode := True;
  try
    const HasBinding = Assigned(Node.Id);
    var DeclaredName := InferredName;
    if HasBinding then
    begin
      DeclaredName := Node.Id.Name;
      const ClassScope: IJSScope = TJSScope.Create(OuterScope);
      FInterpreter.CurrentScope := ClassScope;
      FInterpreter.RegisterScope(ClassScope);
      ClassScope.DeclareLexical(DeclaredName, True);
    end;

    const Heritage = ResolveClassHeritage(Node);

    const Prototype: IJSObject = TJSObject.Create;
    Prototype.Prototype := Heritage.PrototypeParent;

    const ClassConstructor = CreateClassConstructor(Node, Prototype, Heritage.ConstructorParent, DeclaredName);
    for var Member in Node.Members do
    begin
      DefineClassMember(Member, ClassConstructor, Prototype);
    end;

    Result := TJSValue.CreateObject(ClassConstructor);
    if HasBinding then
    begin
      const ClassScope = FInterpreter.CurrentScope;
      ClassScope.InitializeLexical(DeclaredName, Result);
    end;
  finally
    FInterpreter.CurrentScope := OuterScope;
    FInterpreter.StrictMode := OuterStrictMode;
  end;
end;

function TJSClassBuilder.ResolveClassHeritage(const Node: TJSClassExpression): TJSClassHeritage;
begin
  Result.PrototypeParent := FInterpreter.ObjectPrototype;
  Result.ConstructorParent := FInterpreter.FunctionPrototype;

  if not Assigned(Node.SuperClass) then
    Exit;

  const SuperValue = FInterpreter.Visit(Node.SuperClass);
  if SuperValue.IsNull then
  begin
    Result.PrototypeParent := nil;
    Exit;
  end;

  var SuperFunction: IJSFunction;
  const SuperObject = SuperValue.ToObject;
  const IsFunctionValue = (SuperValue.IsFunction and Supports(SuperObject, IJSFunction, SuperFunction));
  const IsConstructor = (IsFunctionValue and SuperFunction.IsConstructor);
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(CLASS_EXTENDS_NOT_CONSTRUCTOR);

  const PrototypeValue = SuperFunction.GetProperty(PROTOTYPE_PROPERTY);
  if PrototypeValue.IsNull then
    Result.PrototypeParent := nil
  else if PrototypeValue.IsObject then
    Result.PrototypeParent := PrototypeValue.ToObject
  else
    raise TJSErrorFactory.TypeError(CLASS_EXTENDS_BAD_PROTOTYPE);

  Result.ConstructorParent := SuperFunction;
end;

function TJSClassBuilder.CreateClassConstructor(const Node: TJSClassExpression; const Prototype: IJSObject;
                                                const ConstructorParent: IJSObject;
                                                const DeclaredName: string): IJSFunction;
begin
  const Func = TJSFunction.Create;
  Func.Prototype := ConstructorParent;
  Func.Name := DeclaredName;
  Func.SourceText := Node.SourceText;
  Func.IsStrict := True;
  Func.ClosureScope := FInterpreter.CurrentScope;

  if Assigned(Node.SuperClass) then
    Func.Kind := TJSFunctionKind.DerivedConstructor
  else
    Func.Kind := TJSFunctionKind.BaseConstructor;

  if Assigned(Node.Constructor_) then
  begin
    Func.BodyNode := Node.Constructor_.Body;
    FInterpreter.AssignParameters(Func, Node.Constructor_.Params, Node.Constructor_.ParameterInfo);
  end
  else
  begin
    Func.IsDefaultConstructor := True;
  end;

  FInterpreter.RegisterFunction(Func);
  Func.HomeObject := Prototype;

  const Engine = FInterpreter.GeneratorEngine;
  Engine.DefinePrototypeProperty(Func, Prototype, False);

  const ConstructorValue = TJSValue.CreateObject(Func as IJSObject);
  var ConstructorDescriptor := TJSPropertyDescriptor.Create(ConstructorValue);
  ConstructorDescriptor.Enumerable := False;
  Prototype.DefineProperty(CONSTRUCTOR_PROPERTY, ConstructorDescriptor);

  Result := Func;
end;

procedure TJSClassBuilder.DefineClassMember(const Member: TJSClassMember; const ClassConstructor: IJSFunction;
                                            const Prototype: IJSObject);
begin
  var Target := Prototype;
  if Member.IsStatic then
    Target := ClassConstructor;

  const Evaluated = FInterpreter.EvaluatePropertyKey(Member.Computed, Member.Key);

  const IsMethod = (Member.Kind = TJSPropertyKind.Method);
  if IsMethod then
    DefineClassMethod(Target, Evaluated.Key, Member)
  else
    DefineClassAccessor(Target, Evaluated.Key, Member);
end;

procedure TJSClassBuilder.DefineClassMethod(const Target: IJSObject; const Key: TJSPropertyKey;
                                            const Member: TJSClassMember);
begin
  const MethodName = FInterpreter.FunctionNameForKey(Key);
  const Method = FInterpreter.CreateMethodFunction(Member.Value, MethodName);
  BindHomeObject(Method, Target);

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := TJSValue.CreateObject(Method);
  Definition.HasWritable := True;
  Definition.Writable := True;
  Definition.HasEnumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  DefineClassProperty(Target, Key, Definition);
end;

procedure TJSClassBuilder.DefineClassAccessor(const Target: IJSObject; const Key: TJSPropertyKey;
                                              const Member: TJSClassMember);
begin
  const IsGetter = (Member.Kind = TJSPropertyKind.Getter);
  const NameFormat = IfThen(IsGetter, GETTER_NAME_FORMAT, SETTER_NAME_FORMAT);
  const AccessorName = Format(NameFormat, [FInterpreter.FunctionNameForKey(Key)]);
  const AccessorFunction = FInterpreter.CreateMethodFunction(Member.Value, AccessorName);
  BindHomeObject(AccessorFunction, Target);

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasEnumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  if IsGetter then
  begin
    Definition.HasGetter := True;
    Definition.Getter := TJSValue.CreateObject(AccessorFunction);
  end
  else
  begin
    Definition.HasSetter := True;
    Definition.Setter := TJSValue.CreateObject(AccessorFunction);
  end;

  DefineClassProperty(Target, Key, Definition);
end;

procedure TJSClassBuilder.DefineClassProperty(const Target: IJSObject; const Key: TJSPropertyKey;
                                              const Definition: TJSPropertyDefinition);
begin
  const IsDefined = Target.DefineOwnProperty(Key, Definition);
  if not IsDefined then
  begin
    const Message = Format(CLASS_MEMBER_NOT_DEFINED, [Key.Text]);
    raise TJSErrorFactory.TypeError(Message);
  end;
end;

end.
