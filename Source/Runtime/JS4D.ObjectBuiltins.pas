unit JS4D.ObjectBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter;

type
  TJSObjectBuiltins = class
  private
    const
      OBJECT_NAME = 'Object';
      HAS_OWN_NAME = 'hasOwn';
      SET_PROTOTYPE_OF_NAME = 'setPrototypeOf';
      FROM_ENTRIES_NAME = 'fromEntries';
      KEY_PROPERTY = '0';
      VALUE_PROPERTY = '1';
      NOT_COERCIBLE = 'Cannot convert undefined or null to object';
      PROTOTYPE_NOT_AN_OBJECT = 'Object prototype may only be an Object or null';
      SET_PROTOTYPE_FAILED = 'Cannot set the prototype of this object: it is not extensible or the prototype chain would be cyclic';
      NOT_ITERABLE = 'Object.fromEntries requires an iterable object';
      ENTRY_NOT_AN_OBJECT = 'Iterator value is not an entry object';

    var
      FInterpreter: TJSInterpreter;

    function ObjectFor(const Value: TJSValue): IJSObject;
    function HasOwn(const Args: TArray<TJSValue>): TJSValue;
    function SetPrototypeOf(const Args: TArray<TJSValue>): TJSValue;
    procedure AddEntry(const Target: IJSObject; const Entry: TJSValue);
    function FromEntries(const Args: TArray<TJSValue>): TJSValue;
    procedure DefineStatic(const ObjectConstructor: IJSObject; const Name: string; const Method: TNativeFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.ArrayStatics,
  JS4D.PropertyDescriptors,
  JS4D.ObjectOperations;

constructor TJSObjectBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

function TJSObjectBuiltins.ObjectFor(const Value: TJSValue): IJSObject;
begin
  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NOT_COERCIBLE);

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
    raise TJSErrorFactory.TypeError(NOT_COERCIBLE);

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

procedure TJSObjectBuiltins.AddEntry(const Target: IJSObject; const Entry: TJSValue);
begin
  if not Entry.IsObject then
    raise TJSErrorFactory.TypeError(ENTRY_NOT_AN_OBJECT);

  const EntryObject = Entry.ToObject;
  const Key = EntryObject.GetProperty(KEY_PROPERTY);
  const Value = EntryObject.GetProperty(VALUE_PROPERTY);

  var Definition := Default(TJSPropertyDefinition);
  Definition.HasValue := True;
  Definition.Value := Value;
  Definition.HasWritable := True;
  Definition.Writable := True;
  Definition.HasEnumerable := True;
  Definition.Enumerable := True;
  Definition.HasConfigurable := True;
  Definition.Configurable := True;

  TJSPropertyDescriptors.Define(Target, Key.ToPropertyKey(FInterpreter.Limits), Definition, FInterpreter.Limits);
end;

function TJSObjectBuiltins.FromEntries(const Args: TArray<TJSValue>): TJSValue;
begin
  const Source = TJSArrayLike.Argument(Args, 0);
  if Source.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NOT_COERCIBLE);

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
      Closer(True);
      raise;
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
