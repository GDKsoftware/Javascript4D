unit JS4D.IterationSource;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayLike,
  JS4D.IteratorProtocol,
  JS4D.ControlFlow;

type
  IJSIterationSource = interface
    ['{3C8E5B21-7A94-4D16-A0F3-92B6E1D4C875}']
    function HasNext: Boolean;
    function Next: TJSValue;
    function Remaining: TArray<TJSValue>;
    procedure Close;
    procedure CloseAfterThrow;
    procedure CloseForException(const Error: Exception);
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

  TJSIterationSource = class(TInterfacedObject, IJSIterationSource)
  private
    FElements: IJSArray;
    FArrayLike: IJSObject;
    FProtocol: IJSIteratorRecord;
    FItems: TArray<TJSValue>;
    FPosition: Integer;

    function ReadNamedElement(const Source: IJSObject): TJSValue;
    function ReadCurrentElement: TJSValue;

  public
    constructor Create(const Elements: IJSArray; const ArrayLike: IJSObject; const Protocol: IJSIteratorRecord;
                       const Items: TArray<TJSValue>);

    class function OverElements(const Elements: IJSArray): IJSIterationSource; static;
    class function OverArrayLike(const ArrayLike: IJSObject): IJSIterationSource; static;
    class function OverProtocol(const Protocol: IJSIteratorRecord): IJSIterationSource; static;
    class function OverItems(const Items: TArray<TJSValue>): IJSIterationSource; static;

    function HasNext: Boolean;
    function Next: TJSValue;
    function Remaining: TArray<TJSValue>;
    procedure Close;
    procedure CloseAfterThrow;
    procedure CloseForException(const Error: Exception);
    procedure EnumerateReferences(const Visit: TJSReferenceVisitor);
  end;

implementation

{ TJSIterationSource }

constructor TJSIterationSource.Create(const Elements: IJSArray; const ArrayLike: IJSObject;
                                      const Protocol: IJSIteratorRecord; const Items: TArray<TJSValue>);
begin
  inherited Create;

  FElements := Elements;
  FArrayLike := ArrayLike;
  FProtocol := Protocol;
  FItems := Items;
end;

class function TJSIterationSource.OverElements(const Elements: IJSArray): IJSIterationSource;
begin
  Result := TJSIterationSource.Create(Elements, nil, nil, nil);
end;

class function TJSIterationSource.OverArrayLike(const ArrayLike: IJSObject): IJSIterationSource;
begin
  Result := TJSIterationSource.Create(nil, ArrayLike, nil, nil);
end;

class function TJSIterationSource.OverProtocol(const Protocol: IJSIteratorRecord): IJSIterationSource;
begin
  Result := TJSIterationSource.Create(nil, nil, Protocol, nil);
end;

class function TJSIterationSource.OverItems(const Items: TArray<TJSValue>): IJSIterationSource;
begin
  Result := TJSIterationSource.Create(nil, nil, nil, Items);
end;

function TJSIterationSource.HasNext: Boolean;
begin
  if Assigned(FProtocol) then
  begin
    Result := FProtocol.TryPrefetchNext;
    Exit;
  end;

  if Assigned(FElements) then
  begin
    Result := (FPosition < FElements.Length);
    Exit;
  end;

  if Assigned(FArrayLike) then
  begin
    Result := (FPosition < TJSArrayLike.ToLength(FArrayLike));
    Exit;
  end;

  Result := (FPosition < Length(FItems));
end;

function TJSIterationSource.ReadNamedElement(const Source: IJSObject): TJSValue;
begin
  Result := Source.GetProperty(TJSArrayLike.IndexName(FPosition));
end;

function TJSIterationSource.ReadCurrentElement: TJSValue;
begin
  if Assigned(FElements) then
  begin
    const HasElement = FElements.HasElement(FPosition);
    if HasElement then
      Result := FElements.GetElement(FPosition)
    else
      Result := ReadNamedElement(FElements);

    Exit;
  end;

  if Assigned(FArrayLike) then
  begin
    Result := ReadNamedElement(FArrayLike);
    Exit;
  end;

  Result := FItems[FPosition];
end;

function TJSIterationSource.Next: TJSValue;
begin
  if Assigned(FProtocol) then
  begin
    Result := FProtocol.Next;
    Exit;
  end;

  Result := TJSValue.CreateUndefined;

  if HasNext then
    Result := ReadCurrentElement;

  Inc(FPosition);
end;

function TJSIterationSource.Remaining: TArray<TJSValue>;
begin
  const Values = TList<TJSValue>.Create;
  try
    while HasNext do
    begin
      Values.Add(Next);
    end;

    Result := Values.ToArray;
  finally
    Values.Free;
  end;
end;

procedure TJSIterationSource.Close;
begin
  if Assigned(FProtocol) then
    FProtocol.Close;
end;

procedure TJSIterationSource.CloseAfterThrow;
begin
  if Assigned(FProtocol) then
    FProtocol.CloseAfterThrow;
end;

procedure TJSIterationSource.CloseForException(const Error: Exception);
begin
  const IsControlFlow = (Error is EJSControlFlowSignal);
  if IsControlFlow then
  begin
    Close;
  end
  else
  begin
    CloseAfterThrow;
  end;
end;

procedure TJSIterationSource.EnumerateReferences(const Visit: TJSReferenceVisitor);
begin
  Visit(FElements);
  Visit(FArrayLike);

  if Assigned(FProtocol) then
    FProtocol.EnumerateReferences(Visit);

  for var Item in FItems do
  begin
    if Item.IsObject then
      Visit(Item.ToObject);
  end;
end;

end.
