unit JS4D.ObjectBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSObjectBuiltins = class(TJSBuiltinSet)
  private
    const
      OBJECT_NAME = 'Object';
      HAS_OWN_NAME = 'hasOwn';
      SET_PROTOTYPE_OF_NAME = 'setPrototypeOf';
      PROTO_GETTER_NAME = 'get __proto__';
      PROTO_SETTER_NAME = 'set __proto__';
      FROM_ENTRIES_NAME = 'fromEntries';
      KEY_PROPERTY = '0';
      VALUE_PROPERTY = '1';
      PROTOTYPE_NOT_AN_OBJECT = 'Object prototype may only be an Object or null';
      SET_PROTOTYPE_FAILED = 'Cannot set the prototype of this object: it is not extensible or the prototype chain ' +
                             'would be cyclic';
      NOT_ITERABLE = 'Object.fromEntries requires an iterable object';
      ENTRY_NOT_AN_OBJECT = 'Iterator value is not an entry object';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;

    function ObjectFor(const Value: TJSValue): IJSObject;
    function HasOwn(const Args: TArray<TJSValue>): TJSValue;
    function SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
    function ReadPrototypeOf(const This: IJSObject): TJSValue;
    function WritePrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateProtoGetter: IJSFunction;
    function CreateProtoSetter: IJSFunction;
    procedure DefineProtoAccessor(const ObjectPrototype: IJSObject);
    procedure AddEntry(const Target: IJSObject; const Entry: TJSValue);
    function FromEntries(const Args: TArray<TJSValue>): TJSValue;
    procedure DefineStatic(const ObjectConstructor: IJSObject; const Name: string; const Method: TNativeFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.ArrayStatics,
  JS4D.PropertyDescriptors,
  JS4D.ObjectOperations;

constructor TJSObjectBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSObjectBuiltins.Destroy;
begin
  FSupport.Free;
  inherited;
end;

function TJSObjectBuiltins.ObjectFor(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  if Value.IsObject then
    Exit(Value.ToObject);

  Result := FInterpreter.WrapPrimitive(Value);
end;

function TJSObjectBuiltins.HasOwn(const Args: TArray<TJSValue>): TJSValue;
begin
  const Target = ObjectFor(TJSArrayLike.Argument(Args, 0));
  const Key = TJSArrayLike.Argument(Args, 1).ToPropertyKey(FInterpreter.Limits);

  Result := TJSValue.CreateBoolean(Target.HasOwnProperty(Key));
end;

function TJSObjectBuiltins.SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
begin
  const Subject = TJSArrayLike.Argument(Args, 0);
  const NewPrototype = TJSArrayLike.Argument(Args, 1);

  if Subject.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  const IsValidPrototype = NewPrototype.IsNull or NewPrototype.IsObject;
  if not IsValidPrototype then
    raise TJSErrorFactory.TypeError(PROTOTYPE_NOT_AN_OBJECT);

  Result := Subject;
  if not Subject.IsObject then
    Exit;

  const Target = Subject.ToObject;
  const Prototype = NewPrototype.ToObject;

  if not TJSObjectOperations.SetPrototypeOf(Target, Prototype) then
    raise TJSErrorFactory.TypeError(SET_PROTOTYPE_FAILED);
end;

function TJSObjectBuiltins.ReadPrototypeOf(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.NotCoercibleToObject;

  const Prototype = This.Prototype;
  if Assigned(Prototype) then
    Result := TJSValue.CreateObject(Prototype)
  else
    Result := TJSValue.CreateNull;
end;

function TJSObjectBuiltins.WritePrototypeOf(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.NotCoercibleToObject;

  Result := TJSValue.CreateUndefined;

  const NewPrototype = TJSArrayLike.Argument(Args, 0);
  const IsValidPrototype = NewPrototype.IsNull or NewPrototype.IsObject;
  if not IsValidPrototype then
    Exit;

  const NewPrototypeObject = NewPrototype.ToObject;
  const IsChanged = TJSObjectOperations.SetPrototypeOf(This, NewPrototypeObject);
  if not IsChanged then
    raise TJSErrorFactory.TypeError(SET_PROTOTYPE_FAILED);
end;

function TJSObjectBuiltins.CreateProtoGetter: IJSFunction;
begin
  Result := FSupport.CreateMethod(PROTO_GETTER_NAME, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := ReadPrototypeOf(This);
    end);
end;

function TJSObjectBuiltins.CreateProtoSetter: IJSFunction;
begin
  Result := FSupport.CreateMethod(PROTO_SETTER_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := WritePrototypeOf(This, Args);
    end);
end;

procedure TJSObjectBuiltins.DefineProtoAccessor(const ObjectPrototype: IJSObject);
begin
  const Getter = CreateProtoGetter;
  const Setter = CreateProtoSetter;

  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.IsAccessor := True;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Descriptor.Getter := TJSValue.CreateObject(Getter);
  Descriptor.Setter := TJSValue.CreateObject(Setter);
  ObjectPrototype.DefineProperty(PROTOTYPE_ACCESSOR_KEY, Descriptor);
end;

procedure TJSObjectBuiltins.AddEntry(const Target: IJSObject; const Entry: TJSValue);
begin
  if not Entry.IsObject then
    raise TJSErrorFactory.TypeError(ENTRY_NOT_AN_OBJECT);

  const EntryObject = Entry.ToObject;
  const Key = EntryObject.GetProperty(KEY_PROPERTY);
  const Value = EntryObject.GetProperty(VALUE_PROPERTY);

  const Definition = TJSPropertyDefinition.ForDataProperty(Value);

  TJSPropertyDescriptors.Define(Target, Key.ToPropertyKey(FInterpreter.Limits), Definition, FInterpreter.Limits);
end;

function TJSObjectBuiltins.FromEntries(const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = TJSArrayLike.Argument(Args, 0);
  if Source.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if not FInterpreter.OpenSequenceReader(Source, Reader, Closer) then
    raise TJSErrorFactory.TypeError(NOT_ITERABLE);

  const Created: IJSObject = TJSObject.Create;
  Created.Prototype := FInterpreter.ObjectPrototype;

  var Entry: TJSValue;
  while Reader(Entry) do
  begin
    try
      AddEntry(Created, Entry);
    except
      on EJSExecutionInterrupted do
        raise;
      on Exception do
      begin
        Closer(True);
        raise;
      end;
    end;
  end;

  Result := TJSValue.CreateObject(Created);
end;

procedure TJSObjectBuiltins.DefineStatic(const ObjectConstructor: IJSObject; const Name: string;
                                         const Method: TNativeFunction);
begin
  const Func = TJSFunction.CreateNative(Name, Method);
  Func.Prototype := FInterpreter.FunctionPrototype;
  FInterpreter.RegisterFunction(Func);

  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(Func));
  Descriptor.Enumerable := False;
  ObjectConstructor.DefineProperty(Name, Descriptor);
end;

procedure TJSObjectBuiltins.Register;
begin
  const ObjectConstructor = FInterpreter.GetGlobalVariable(OBJECT_NAME).ToObject;

  const PrototypeValue = ObjectConstructor.GetProperty(PROTOTYPE_PROPERTY);
  const ObjectPrototype = PrototypeValue.ToObject;
  DefineProtoAccessor(ObjectPrototype);

  DefineStatic(ObjectConstructor, HAS_OWN_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := HasOwn(Args);
    end);

  DefineStatic(ObjectConstructor, SET_PROTOTYPE_OF_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := SetPrototypeOf(Args);
    end);

  DefineStatic(ObjectConstructor, FROM_ENTRIES_NAME,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := FromEntries(Args);
    end);
end;

end.
