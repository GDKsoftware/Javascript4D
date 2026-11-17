unit JS4D.IteratorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.PropertyNames,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.IntrinsicCache,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSIteratorBuiltins = class
  private
    const
      VALUES_PROPERTY = 'values';
      ITERATOR_FUNCTION_NAME = '[Symbol.iterator]';
      ARRAY_ITERATOR_TAG = 'Array Iterator';
      STRING_ITERATOR_TAG = 'String Iterator';
      NOT_A_STRING_ITERATOR = 'next method called on an object that is not a string iterator';
      STRING_ITERATOR_ON_NOTHING = 'String.prototype[Symbol.iterator] called on undefined or null';
      INTRINSIC_NOT_A_FUNCTION = 'The intrinsic method is not a function';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
      FArrayIteratorPrototype: IJSObject;

    function RequireFunction(const Value: TJSValue): IJSFunction;
    function CreateIteratorPrototype: IJSObject;
    function CreateStringIteratorPrototype(const IteratorPrototype: IJSObject): IJSObject;
    function CreateSymbolIteratorMethod(const Method: TNativeFunction): IJSFunction;
    procedure DefineIteratorMethod(const Target: IJSObject; const Method: IJSFunction);
    function StringIteratorFor(const This: IJSObject): TJSValue;

  public
    constructor Create(const Interpreter: TJSInterpreter; const ArrayIteratorPrototype: IJSObject);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.StringIterator;

constructor TJSIteratorBuiltins.Create(const Interpreter: TJSInterpreter; const ArrayIteratorPrototype: IJSObject);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
  FArrayIteratorPrototype := ArrayIteratorPrototype;
end;

destructor TJSIteratorBuiltins.Destroy;
begin
  FSupport.Free;
  inherited;
end;

function TJSIteratorBuiltins.RequireFunction(const Value: TJSValue): IJSFunction;
begin
  if not TJSBuiltinSupport.TryGetFunction(Value, Result) then
    raise TJSErrorFactory.TypeError(INTRINSIC_NOT_A_FUNCTION);
end;

function TJSIteratorBuiltins.CreateSymbolIteratorMethod(const Method: TNativeFunction): IJSFunction;
begin
  Result := FSupport.CreateMethod(ITERATOR_FUNCTION_NAME, 0, Method);
end;

procedure TJSIteratorBuiltins.DefineIteratorMethod(const Target: IJSObject; const Method: IJSFunction);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Iterator);

  FSupport.DefineMember(Target, Key, TJSValue.CreateObject(Method), True);
end;

function TJSIteratorBuiltins.CreateIteratorPrototype: IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := FInterpreter.ObjectPrototype;

  const ReturnsThis = CreateSymbolIteratorMethod(TJSBuiltinSupport.ReturnsThis());

  DefineIteratorMethod(Result, ReturnsThis);
end;

function TJSIteratorBuiltins.StringIteratorFor(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(STRING_ITERATOR_ON_NOTHING);

  const Text = TJSConversions.ToText(TJSValue.CreateObject(This), FInterpreter.Limits);
  const Iterator = TJSStringIterator.Create(Text, FInterpreter.ObjectPrototype);
  Iterator.Prototype := FInterpreter.Iteration.StringIteratorPrototype;

  Result := TJSValue.CreateObject(Iterator);
end;

function TJSIteratorBuiltins.CreateStringIteratorPrototype(const IteratorPrototype: IJSObject): IJSObject;
begin
  Result := TJSObject.Create;
  Result.Prototype := IteratorPrototype;

  const NextMethod = FSupport.CreateMethod(NEXT_PROPERTY, 0,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      var Iterator: IJSStringIterator;
      if not Supports(This, IJSStringIterator, Iterator) then
        raise TJSErrorFactory.TypeError(NOT_A_STRING_ITERATOR);

      Result := Iterator.NextResult;
    end);

  FSupport.DefineMember(Result, NEXT_PROPERTY, TJSValue.CreateObject(NextMethod), True);
  FSupport.DefineToStringTag(Result, STRING_ITERATOR_TAG);
end;

procedure TJSIteratorBuiltins.Register;
begin
  var Intrinsics := Default(TJSIterationIntrinsics);

  const IteratorPrototype = CreateIteratorPrototype;

  FArrayIteratorPrototype.Prototype := IteratorPrototype;
  FSupport.DefineToStringTag(FArrayIteratorPrototype, ARRAY_ITERATOR_TAG);
  Intrinsics.ArrayIteratorPrototype := FArrayIteratorPrototype;
  const ArrayNext = RequireFunction(FArrayIteratorPrototype.GetProperty(NEXT_PROPERTY));
  ArrayNext.IsConstructor := False;
  TJSFunction.DefineLength(ArrayNext, 0);
  Intrinsics.ArrayIteratorNext := ArrayNext as IInterface;

  const ArrayPrototype = FInterpreter.ArrayPrototype;
  const ArrayValues = RequireFunction(ArrayPrototype.GetProperty(VALUES_PROPERTY));
  DefineIteratorMethod(ArrayPrototype, ArrayValues);
  Intrinsics.ArrayValues := ArrayValues as IInterface;

  Intrinsics.StringIteratorPrototype := CreateStringIteratorPrototype(IteratorPrototype);
  const StringNextValue = Intrinsics.StringIteratorPrototype.GetProperty(NEXT_PROPERTY);
  Intrinsics.StringIteratorNext := RequireFunction(StringNextValue) as IInterface;
  const StringIteratorMethod = CreateSymbolIteratorMethod(
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := StringIteratorFor(This);
    end);
  DefineIteratorMethod(FInterpreter.StringPrototype, StringIteratorMethod);
  Intrinsics.StringIterator := StringIteratorMethod as IInterface;

  FInterpreter.Iteration := Intrinsics;
end;

end.
