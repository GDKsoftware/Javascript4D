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
  // Where the values of an iterable come from: the elements of an array or arguments object and the code
  // points of a string are read directly, anything else goes through the iterator protocol.
  TJSIterationSource = record
    Elements: IJSArray;
    ArrayLike: IJSObject;
    Protocol: IJSIteratorRecord;
    Items: TArray<TJSValue>;
    Position: Integer;

    function ReadNamedElement(const Source: IJSObject): TJSValue;
    function HasNext: Boolean;
    function Next: TJSValue;
    function Remaining: TArray<TJSValue>;
    procedure Close;
    procedure CloseAfterThrow;
    procedure CloseForException(const Error: Exception);
  end;

implementation

{ TJSIterationSource }

function TJSIterationSource.HasNext: Boolean;
begin
  if Assigned(Protocol) then
  begin
    Result := Protocol.HasNext;
    Exit;
  end;

  if Assigned(Elements) then
  begin
    Result := Position < Elements.Length;
    Exit;
  end;

  if Assigned(ArrayLike) then
  begin
    Result := Position < TJSArrayLike.ToLength(ArrayLike);
    Exit;
  end;

  Result := (Position < Length(Items));
end;

function TJSIterationSource.ReadNamedElement(const Source: IJSObject): TJSValue;
begin
  Result := Source.GetProperty(TJSArrayLike.IndexName(Position));
end;

function TJSIterationSource.Next: TJSValue;
begin
  if Assigned(Protocol) then
  begin
    Result := Protocol.Next;
    Exit;
  end;

  Result := TJSValue.CreateUndefined;

  if HasNext then
  begin
    if Assigned(Elements) then
    begin
      if Elements.HasElement(Position) then
        Result := Elements.GetElement(Position)
      else
        Result := ReadNamedElement(Elements);
    end
    else if Assigned(ArrayLike) then
    begin
      Result := ReadNamedElement(ArrayLike);
    end
    else
    begin
      Result := Items[Position];
    end;
  end;

  Inc(Position);
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
  if Assigned(Protocol) then
    Protocol.Close;
end;

procedure TJSIterationSource.CloseForException(const Error: Exception);
begin
  if Error is EJSControlFlowSignal then
  begin
    Close;
  end
  else
  begin
    CloseAfterThrow;
  end;
end;

procedure TJSIterationSource.CloseAfterThrow;
begin
  if Assigned(Protocol) then
    Protocol.CloseAfterThrow;
end;

end.
