unit JS4D.IteratorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  // Makes arrays, strings and arguments objects iterable: %IteratorPrototype%, %ArrayIteratorPrototype%,
  // %StringIteratorPrototype% and the Symbol.iterator methods that return their iterators.
  TJSIteratorBuiltins = class
  private
    FInterpreter: TJSInterpreter;
    FArrayIteratorPrototype: IJSObject;

    class procedure DefineMember(const Target: IJSObject; const Key: TJSPropertyKey; const Value: TJSValue;
                                 const IsWritable: Boolean); static;
    class function AsFunction(const Value: TJSValue): IJSFunction; static;
    function CreateMethod(const Name: string; const Method: TNativeFunction): IJSFunction;
    function CreateIteratorPrototype: IJSObject;
    function CreateStringIteratorPrototype(const IteratorPrototype: IJSObject): IJSObject;
    function CreateNextMethod(const Method: TNativeFunction): IJSFunction;
    function CreateSymbolIteratorMethod(const Method: TNativeFunction): IJSFunction;
    procedure DefineIteratorMethod(const Target: IJSObject; const Method: IJSFunction);
    procedure DefineToStringTag(const Target: IJSObject; const Tag: string);
    function StringIteratorFor(const This: IJSObject): TJSValue;
    function ToText(const Value: TJSValue): string;

  public
    constructor Create(const Interpreter: TJSInterpreter; const ArrayIteratorPrototype: IJSObject);

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.StringIterator;

const
  NEXT_PROPERTY = 'next';
  VALUES_PROPERTY = 'values';
  ITERATOR_FUNCTION_NAME = '[Symbol.iterator]';
  ARRAY_ITERATOR_TAG = 'Array Iterator';
  STRING_ITERATOR_TAG = 'String Iterator';
  NOT_A_STRING_ITERATOR = 'next method called on an object that is not a string iterator';
  STRING_ITERATOR_ON_NOTHING = 'String.prototype[Symbol.iterator] called on undefined or null';

constructor TJSIteratorBuiltins.Create(const Interpreter: TJSInterpreter; const ArrayIteratorPrototype: IJSObject);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FArrayIteratorPrototype := ArrayIteratorPrototype;
end;

class procedure TJSIteratorBuiltins.DefineMember(const Target: IJSObject; const Key: TJSPropertyKey;
                                                 const Value: TJSValue; const IsWritable: Boolean);
begin
  var Descriptor := TJSPropertyDescriptor.Create(Value);
  Descriptor.Writable := IsWritable;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(Key, Descriptor);
end;

class function TJSIteratorBuiltins.AsFunction(const Value: TJSValue): IJSFunction;
begin
  Supports(Value.ToObject, IJSFunction, Result);
end;

function TJSIteratorBuiltins.ToText(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitiveWithHint(TJSPrimitiveHint.String_);

  Result := Primitive.ToLimitedString(FInterpreter.Limits);
end;

function TJSIteratorBuiltins.CreateMethod(const Name: string; const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, 0);
  FInterpreter.RegisterFunction(Result);
end;

function TJSIteratorBuiltins.CreateNextMethod(const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(NEXT_PROPERTY, Method);
end;

function TJSIteratorBuiltins.CreateSymbolIteratorMethod(const Method: TNativeFunction): IJSFunction;
begin
  Result := CreateMethod(ITERATOR_FUNCTION_NAME, Method);
end;

procedure TJSIteratorBuiltins.DefineIteratorMethod(const Target: IJSObject; const Method: IJSFunction);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  DefineMember(Target, Key, TJSValue.CreateObject(Method), True);
end;

procedure TJSIteratorBuiltins.DefineToStringTag(const Target: IJSObject; const Tag: string);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.ToStringTag);

  DefineMember(Target, Key, TJSValue.CreateString(Tag), False);
end;

function TJSIteratorBuiltins.CreateIteratorPrototype: IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := FInterpreter.ObjectPrototype;

  const ReturnsThis = CreateSymbolIteratorMethod(
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      if Assigned(This) then
        Result := TJSValue.CreateObject(This)
      else
        Result := TJSValue.CreateUndefined;
    end);

  DefineIteratorMethod(Result, ReturnsThis);
end;

function TJSIteratorBuiltins.StringIteratorFor(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(STRING_ITERATOR_ON_NOTHING);

  const Text = ToText(TJSValue.CreateObject(This));
  const Iterator = TJSStringIterator.Create(Text, FInterpreter.ObjectPrototype);
  Iterator.Prototype := FInterpreter.Iteration.StringIteratorPrototype;

  Result := TJSValue.CreateObject(Iterator);
end;

function TJSIteratorBuiltins.CreateStringIteratorPrototype(const IteratorPrototype: IJSObject): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := IteratorPrototype;

  const NextMethod = CreateNextMethod(
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Iterator: IJSStringIterator;
      if not Supports(This, IJSStringIterator, Iterator) then
        raise TJSErrorFactory.TypeError(NOT_A_STRING_ITERATOR);

      Result := Iterator.NextResult;
    end);

  DefineMember(Result, NEXT_PROPERTY, TJSValue.CreateObject(NextMethod), True);
  DefineToStringTag(Result, STRING_ITERATOR_TAG);
end;

procedure TJSIteratorBuiltins.Register;
begin
  var Intrinsics := Default(TJSIterationIntrinsics);

  const IteratorPrototype = CreateIteratorPrototype;

  FArrayIteratorPrototype.Prototype := IteratorPrototype;
  DefineToStringTag(FArrayIteratorPrototype, ARRAY_ITERATOR_TAG);
  Intrinsics.ArrayIteratorPrototype := FArrayIteratorPrototype;
  const ArrayNext = AsFunction(FArrayIteratorPrototype.GetProperty(NEXT_PROPERTY));
  ArrayNext.IsConstructor := False;
  TJSFunction.DefineLength(ArrayNext, 0);
  Intrinsics.ArrayIteratorNext := ArrayNext as IInterface;

  const ArrayPrototype = FInterpreter.ArrayPrototype;
  const ArrayValues = AsFunction(ArrayPrototype.GetProperty(VALUES_PROPERTY));
  DefineIteratorMethod(ArrayPrototype, ArrayValues);
  Intrinsics.ArrayValues := ArrayValues as IInterface;

  Intrinsics.StringIteratorPrototype := CreateStringIteratorPrototype(IteratorPrototype);
  Intrinsics.StringIteratorNext := AsFunction(Intrinsics.StringIteratorPrototype.GetProperty(NEXT_PROPERTY)) as IInterface;
  const StringIterator = CreateSymbolIteratorMethod(
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := StringIteratorFor(This);
    end);
  DefineIteratorMethod(FInterpreter.StringPrototype, StringIterator);
  Intrinsics.StringIterator := StringIterator as IInterface;

  FInterpreter.Iteration := Intrinsics;
end;

end.
