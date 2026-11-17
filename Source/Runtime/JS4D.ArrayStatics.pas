unit JS4D.ArrayStatics;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.PropertyDescriptors;

type
  TJSConstructCallback = reference to function(const Constructor_: IJSFunction;
                                               const Args: TArray<TJSValue>): TJSValue;
  TJSMapCallback = reference to function(const Mapper: IJSFunction; const Args: TArray<TJSValue>;
                                         const ThisValue: TJSValue): TJSValue;
  TJSSequenceReader = reference to function(out Item: TJSValue): Boolean;
  TJSSequenceCloser = reference to procedure(const AfterThrow: Boolean);
  TJSSequenceOpener = reference to function(const Source: TJSValue; out Reader: TJSSequenceReader;
                                            out Closer: TJSSequenceCloser): Boolean;

  TJSArrayStaticsContext = record
    ArrayPrototype: IJSObject;
    Limits: TJSLimits;
    Construct: TJSConstructCallback;
    CallMapper: TJSMapCallback;
    OpenSequence: TJSSequenceOpener;
  end;

  TJSArrayStatics = class
  private
    const
      METHOD_OF = 'of';
      METHOD_FROM = 'from';
      MAPPER_NOT_A_FUNCTION = 'Array.from: when provided, the map function must be a function';
      UNSUPPORTED_METHOD = 'Unsupported Array static method: %s';
      SOURCE_NOT_COERCIBLE = 'Array.from requires an array-like or iterable object';

    class function CreateTarget(const ThisObj: IJSObject; const ConstructorArgs: TArray<TJSValue>;
                                const Context: TJSArrayStaticsContext): IJSObject; static;
    class procedure DefineElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue;
                                  const Context: TJSArrayStaticsContext); static;
    class function ArrayOf(const ThisObj: IJSObject; const Args: TArray<TJSValue>;
                           const Context: TJSArrayStaticsContext): TJSValue; static;
    class function ArrayFrom(const ThisObj: IJSObject; const Args: TArray<TJSValue>;
                             const Context: TJSArrayStaticsContext): TJSValue; static;
    class function RequireMapper(const MapFunction: TJSValue): IJSFunction; static;
    class function MapItem(const Mapper: IJSFunction; const Item: TJSValue; const Index: Int64;
                           const ThisArg: TJSValue; const Context: TJSArrayStaticsContext): TJSValue; static;
    class function CopySequence(const ThisObj: IJSObject; const Reader: TJSSequenceReader;
                                const Closer: TJSSequenceCloser; const Mapper: IJSFunction;
                                const ThisArg: TJSValue; const Context: TJSArrayStaticsContext): TJSValue; static;
    class procedure CopyItem(const Target: IJSObject; const Item: TJSValue; const Index: Int64;
                             const Mapper: IJSFunction; const ThisArg: TJSValue;
                             const Closer: TJSSequenceCloser; const Context: TJSArrayStaticsContext); static;
    class function CopyArrayLike(const ThisObj: IJSObject; const Items: TJSValue; const Mapper: IJSFunction;
                                 const ThisArg: TJSValue; const Context: TJSArrayStaticsContext): TJSValue; static;

  public
    class procedure CloseAfterFailure(const Closer: TJSSequenceCloser; const Failure: Exception); static;
    class function Handles(const MethodName: string): Boolean; static;
    class function Call(const MethodName: string; const ThisObj: IJSObject; const Args: TArray<TJSValue>;
                        const Context: TJSArrayStaticsContext): TJSValue; static;
  end;

implementation

class procedure TJSArrayStatics.CloseAfterFailure(const Closer: TJSSequenceCloser; const Failure: Exception);
begin
  const IsInterruption = (Failure is EJSExecutionInterrupted);
  if not IsInterruption then
    Closer(True);
end;

class function TJSArrayStatics.Handles(const MethodName: string): Boolean;
begin
  Result := (MethodName = METHOD_OF) or
            (MethodName = METHOD_FROM);
end;

class function TJSArrayStatics.Call(const MethodName: string; const ThisObj: IJSObject;
                                    const Args: TArray<TJSValue>; const Context: TJSArrayStaticsContext): TJSValue;
begin
  const IsOf = (MethodName = METHOD_OF);
  if IsOf then
  begin
    Result := ArrayOf(ThisObj, Args, Context);
    Exit;
  end;

  const IsFrom = (MethodName = METHOD_FROM);
  if IsFrom then
  begin
    Result := ArrayFrom(ThisObj, Args, Context);
    Exit;
  end;

  raise ENotSupportedException.CreateFmt(UNSUPPORTED_METHOD, [MethodName]);
end;

class function TJSArrayStatics.CreateTarget(const ThisObj: IJSObject; const ConstructorArgs: TArray<TJSValue>;
                                            const Context: TJSArrayStaticsContext): IJSObject;
begin
  var Constructor_: IJSFunction;
  const ThisValue = TJSValue.CreateObject(ThisObj);
  if ThisValue.TryGetConstructor(Constructor_) then
  begin
    const Constructed = Context.Construct(Constructor_, ConstructorArgs);
    Result := Constructed.ToObject;
    Exit;
  end;

  const Created = TJSArray.Create;
  Created.Prototype := Context.ArrayPrototype;
  Result := Created;
end;

class procedure TJSArrayStatics.DefineElement(const Target: IJSObject; const Index: Int64; const Value: TJSValue;
                                              const Context: TJSArrayStaticsContext);
begin
  var TargetArray: IJSArray;
  const IsAppend = Supports(Target, IJSArray, TargetArray) and
                   TargetArray.IsDenseAndMutable and
                   (TargetArray.Length = Index);
  if IsAppend then
  begin
    Context.Limits.EnsureArrayLength(Index + 1);
    TargetArray.Push(Value);
    Exit;
  end;

  const Definition = TJSPropertyDefinition.ForDataProperty(Value);
  const ElementName = TJSArrayLike.IndexName(Index);

  TJSPropertyDescriptors.Define(Target, ElementName, Definition, Context.Limits);
end;

class function TJSArrayStatics.ArrayOf(const ThisObj: IJSObject; const Args: TArray<TJSValue>;
                                       const Context: TJSArrayStaticsContext): TJSValue;
begin
  const Count = Length(Args);
  const ConstructorArgs: TArray<TJSValue> = [TJSValue.CreateNumber(Count)];
  const Target = CreateTarget(ThisObj, ConstructorArgs, Context);

  for var Index := 0 to Count - 1 do
  begin
    DefineElement(Target, Index, Args[Index], Context);
  end;

  TJSArrayLike.WriteLength(Target, Count);
  Result := TJSValue.CreateObject(Target);
end;

class function TJSArrayStatics.ArrayFrom(const ThisObj: IJSObject; const Args: TArray<TJSValue>;
                                         const Context: TJSArrayStaticsContext): TJSValue;
begin
  const Items = TJSArrayLike.Argument(Args, 0);
  const MapperArgument = TJSArrayLike.Argument(Args, 1);
  const Mapper = RequireMapper(MapperArgument);
  const ThisArg = TJSArrayLike.Argument(Args, 2);

  if Items.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(SOURCE_NOT_COERCIBLE);

  var Reader: TJSSequenceReader;
  var Closer: TJSSequenceCloser;
  if Context.OpenSequence(Items, Reader, Closer) then
  begin
    Result := CopySequence(ThisObj, Reader, Closer, Mapper, ThisArg, Context);
    Exit;
  end;

  Result := CopyArrayLike(ThisObj, Items, Mapper, ThisArg, Context);
end;

class function TJSArrayStatics.RequireMapper(const MapFunction: TJSValue): IJSFunction;
begin
  Result := nil;
  if MapFunction.IsUndefined then
    Exit;

  if not MapFunction.TryGetFunction(Result) then
    raise TJSErrorFactory.TypeError(MAPPER_NOT_A_FUNCTION);
end;

class function TJSArrayStatics.MapItem(const Mapper: IJSFunction; const Item: TJSValue; const Index: Int64;
                                       const ThisArg: TJSValue; const Context: TJSArrayStaticsContext): TJSValue;
begin
  if not Assigned(Mapper) then
    Exit(Item);

  const MapperArgs: TArray<TJSValue> = [Item, TJSValue.CreateNumber(Index)];

  Result := Context.CallMapper(Mapper, MapperArgs, ThisArg);
end;

class function TJSArrayStatics.CopySequence(const ThisObj: IJSObject; const Reader: TJSSequenceReader;
                                            const Closer: TJSSequenceCloser; const Mapper: IJSFunction;
                                            const ThisArg: TJSValue;
                                            const Context: TJSArrayStaticsContext): TJSValue;
begin
  const Target = CreateTarget(ThisObj, nil, Context);

  var Index: Int64 := 0;
  var Item: TJSValue;
  while Reader(Item) do
  begin
    CopyItem(Target, Item, Index, Mapper, ThisArg, Closer, Context);
    Inc(Index);
  end;

  TJSArrayLike.WriteLength(Target, Index);
  Result := TJSValue.CreateObject(Target);
end;

class procedure TJSArrayStatics.CopyItem(const Target: IJSObject; const Item: TJSValue; const Index: Int64;
                                         const Mapper: IJSFunction; const ThisArg: TJSValue;
                                         const Closer: TJSSequenceCloser; const Context: TJSArrayStaticsContext);
begin
  try
    const Mapped = MapItem(Mapper, Item, Index, ThisArg, Context);
    DefineElement(Target, Index, Mapped, Context);
  except
    on Failure: Exception do
    begin
      CloseAfterFailure(Closer, Failure);
      raise;
    end;
  end;
end;

class function TJSArrayStatics.CopyArrayLike(const ThisObj: IJSObject; const Items: TJSValue;
                                             const Mapper: IJSFunction; const ThisArg: TJSValue;
                                             const Context: TJSArrayStaticsContext): TJSValue;
begin
  const Source = Items.ToObject;
  var Count: Int64 := 0;
  if Items.IsObject then
    Count := TJSArrayLike.ToLength(Source);

  Context.Limits.EnsureArrayLength(Count);
  const ConstructorArgs: TArray<TJSValue> = [TJSValue.CreateNumber(Count)];
  const Target = CreateTarget(ThisObj, ConstructorArgs, Context);

  for var Index: Int64 := 0 to Count - 1 do
  begin
    const ElementName = TJSArrayLike.IndexName(Index);
    const Item = Source.GetProperty(ElementName);
    const Mapped = MapItem(Mapper, Item, Index, ThisArg, Context);
    DefineElement(Target, Index, Mapped, Context);
  end;

  TJSArrayLike.WriteLength(Target, Count);
  Result := TJSValue.CreateObject(Target);
end;

end.
