unit JS4D.IteratorBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.PropertyKey,
  JS4D.PropertyNames,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.IntrinsicCache,
  JS4D.Interpreter,
  JS4D.BuiltinSupport;

type
  TJSIteratorBuiltins = class(TJSBuiltinSet)
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
    function WithArrayIterator(const Source: TJSIterationIntrinsics;
                               const IteratorPrototype: IJSObject): TJSIterationIntrinsics;
    function WithStringIterator(const Source: TJSIterationIntrinsics;
                                const IteratorPrototype: IJSObject): TJSIterationIntrinsics;

  public
    constructor Create(const Interpreter: TJSInterpreter; const ArrayIteratorPrototype: IJSObject);
    destructor Destroy; override;

    procedure Register; override;
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
  if not Value.TryGetFunction(Result) then
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

  const ReturnThisMethod = TJSBuiltinSupport.ReturnsThis;
  const ReturnsThis = CreateSymbolIteratorMethod(ReturnThisMethod);

  DefineIteratorMethod(Result, ReturnsThis);
end;

function TJSIteratorBuiltins.StringIteratorFor(const This: IJSObject): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(STRING_ITERATOR_ON_NOTHING);

  const ThisValue = TJSValue.CreateObject(This);
  const Text = TJSConversions.ToText(ThisValue, FInterpreter.Limits);
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

function TJSIteratorBuiltins.WithArrayIterator(const Source: TJSIterationIntrinsics;
                                               const IteratorPrototype: IJSObject): TJSIterationIntrinsics;
begin
  Result := Source;

  FArrayIteratorPrototype.Prototype := IteratorPrototype;
  FSupport.DefineToStringTag(FArrayIteratorPrototype, ARRAY_ITERATOR_TAG);
  Result.ArrayIteratorPrototype := FArrayIteratorPrototype;
  const ArrayNextValue = FArrayIteratorPrototype.GetProperty(NEXT_PROPERTY);
  const ArrayNext = RequireFunction(ArrayNextValue);
  ArrayNext.IsConstructor := False;
  TJSFunction.DefineLength(ArrayNext, 0);
  Result.ArrayIteratorNext := ArrayNext as IInterface;

  const ArrayPrototype = FInterpreter.ArrayPrototype;
  const ArrayValuesValue = ArrayPrototype.GetProperty(VALUES_PROPERTY);
  const ArrayValues = RequireFunction(ArrayValuesValue);
  DefineIteratorMethod(ArrayPrototype, ArrayValues);
  Result.ArrayValues := ArrayValues as IInterface;
end;

function TJSIteratorBuiltins.WithStringIterator(const Source: TJSIterationIntrinsics;
                                                const IteratorPrototype: IJSObject): TJSIterationIntrinsics;
begin
  Result := Source;

  Result.StringIteratorPrototype := CreateStringIteratorPrototype(IteratorPrototype);
  const StringNextValue = Result.StringIteratorPrototype.GetProperty(NEXT_PROPERTY);
  Result.StringIteratorNext := RequireFunction(StringNextValue) as IInterface;
  const StringIteratorMethod = CreateSymbolIteratorMethod(
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := StringIteratorFor(This);
    end);
  DefineIteratorMethod(FInterpreter.StringPrototype, StringIteratorMethod);
  Result.StringIterator := StringIteratorMethod as IInterface;
end;

procedure TJSIteratorBuiltins.Register;
begin
  const IteratorPrototype = CreateIteratorPrototype;

  var Intrinsics := Default(TJSIterationIntrinsics);
  Intrinsics := WithArrayIterator(Intrinsics, IteratorPrototype);
  Intrinsics := WithStringIterator(Intrinsics, IteratorPrototype);

  FInterpreter.Iteration := Intrinsics;
end;

end.
