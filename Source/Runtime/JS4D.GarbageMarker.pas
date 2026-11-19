unit JS4D.GarbageMarker;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.ObjectKeys,
  JS4D.ArgumentsObject,
  JS4D.ObjectOperations,
  JS4D.GeneratorObjects;

type
  TJSGarbageMarker = class
  private
    FLive: TDictionary<Pointer, Byte>;
    FWork: TList<IInterface>;

    procedure MarkGeneratorReferences(const Generator: IJSGenerator);
    procedure MarkFrame(const Frame: IJSFrame);
    procedure MarkOwnProperties(const Obj: IJSObject);
    procedure TraceItem(const Item: IInterface);
    procedure TraceScope(const Scope: IJSScope);
    procedure TraceProxy(const Proxy: IJSProxy);
    procedure TraceFunction(const Func: IJSFunction);
    procedure TraceArray(const Arr: IJSArray);
    procedure TraceObject(const Obj: IJSObject);

  public
    constructor Create;
    destructor Destroy; override;

    procedure Mark(const Item: IInterface);
    procedure MarkValue(const Value: TJSValue);
    procedure MarkGenerator(const Generator: TJSGeneratorObject);
    procedure MarkBinding(const Binding: IJSThisBinding);
    procedure TraceReferences;
    function IsLive(const Item: IInterface): Boolean;
  end;

implementation

{ TJSGarbageMarker }

constructor TJSGarbageMarker.Create;
begin
  inherited Create;
  FLive := TDictionary<Pointer, Byte>.Create;
  FWork := TList<IInterface>.Create;
end;

destructor TJSGarbageMarker.Destroy;
begin
  FWork.Free;
  FLive.Free;
  inherited;
end;

procedure TJSGarbageMarker.Mark(const Item: IInterface);
begin
  if not Assigned(Item) then
    Exit;

  const Id = Pointer(Item as IInterface);
  if FLive.ContainsKey(Id) then
    Exit;

  FLive.Add(Id, 0);
  FWork.Add(Item);
end;

function TJSGarbageMarker.IsLive(const Item: IInterface): Boolean;
begin
  Result := FLive.ContainsKey(Pointer(Item as IInterface));
end;

procedure TJSGarbageMarker.MarkGenerator(const Generator: TJSGeneratorObject);
begin
  if not Assigned(Generator) then
    Exit;

  const Held: IJSObject = Generator;
  Mark(Held);
end;

procedure TJSGarbageMarker.MarkGeneratorReferences(const Generator: IJSGenerator);
begin
  Generator.EnumerateReferences(
    procedure(const Reference: IInterface)
    begin
      Mark(Reference);
    end);
end;

procedure TJSGarbageMarker.MarkBinding(const Binding: IJSThisBinding);
begin
  if Assigned(Binding) then
    Mark(Binding.Value);
end;

procedure TJSGarbageMarker.MarkFrame(const Frame: IJSFrame);
begin
  if not Assigned(Frame) then
    Exit;

  Mark(Frame.Callee);
  Mark(Frame.NewTarget);
  MarkBinding(Frame.ThisBinding);
end;

procedure TJSGarbageMarker.MarkValue(const Value: TJSValue);
begin
  if Value.IsObject then
    Mark(Value.ToObject);
end;

procedure TJSGarbageMarker.MarkOwnProperties(const Obj: IJSObject);
begin
  for var PropName in TJSObjectOperations.OwnKeys(Obj) do
  begin
    const Descriptor = Obj.GetOwnPropertyDescriptor(PropName);

    MarkValue(Descriptor.Value);
    MarkValue(Descriptor.Getter);
    MarkValue(Descriptor.Setter);
  end;
end;

procedure TJSGarbageMarker.TraceReferences;
begin
  while FWork.Count > 0 do
  begin
    const Item = FWork.Last;
    FWork.Delete(FWork.Count - 1);

    TraceItem(Item);
  end;
end;

procedure TJSGarbageMarker.TraceItem(const Item: IInterface);
begin
  var Scope: IJSScope;
  var Func: IJSFunction;
  var Proxy: IJSProxy;
  var Arr: IJSArray;
  var Obj: IJSObject;

  if Supports(Item, IJSScope, Scope) then
    TraceScope(Scope)
  else if Supports(Item, IJSProxy, Proxy) then
    TraceProxy(Proxy)
  else if Supports(Item, IJSFunction, Func) then
    TraceFunction(Func)
  else if Supports(Item, IJSArray, Arr) then
    TraceArray(Arr)
  else if Supports(Item, IJSObject, Obj) then
    TraceObject(Obj);
end;

procedure TJSGarbageMarker.TraceScope(const Scope: IJSScope);
begin
  Mark(Scope.Parent);
  for var Value in Scope.GetOwnVariables do
    MarkValue(Value);
end;

procedure TJSGarbageMarker.TraceProxy(const Proxy: IJSProxy);
begin
  Mark(Proxy.ProxyTarget);
  Mark(Proxy.ProxyHandler);
end;

procedure TJSGarbageMarker.TraceFunction(const Func: IJSFunction);
begin
  Mark(Func.ClosureScope);
  Mark(Func.LexicalThis);
  Mark(Func.Prototype);
  Mark(Func.HomeObject);
  MarkFrame(Func.Frame);
  MarkOwnProperties(Func);
end;

procedure TJSGarbageMarker.TraceArray(const Arr: IJSArray);
begin
  for var ElementIndex := 0 to Arr.Length - 1 do
    MarkValue(Arr.Elements[ElementIndex]);

  Mark(Arr.Prototype);
  MarkOwnProperties(Arr);
end;

procedure TJSGarbageMarker.TraceObject(const Obj: IJSObject);
begin
  var ArgumentsScope: IJSArgumentsScope;
  if Supports(Obj, IJSArgumentsScope, ArgumentsScope) then
    Mark(ArgumentsScope.MappedScope);

  var Generator: IJSGenerator;
  if Supports(Obj, IJSGenerator, Generator) then
    MarkGeneratorReferences(Generator);

  Mark(Obj.Prototype);
  MarkOwnProperties(Obj);
end;

end.
