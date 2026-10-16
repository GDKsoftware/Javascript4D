unit JS4D.Json;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.JSON,
  JS4D.Types;

type
  // Builds the JSON tree of a script value and counts the text it will produce, measured on the
  // nodes as they are written. A structure that would exceed the string limit is refused while it is
  // built, a nesting deeper than the call depth limit is refused, and a cycle raises a TypeError.
  TJSONConverter = class
  private
    FLimits: TJSLimits;
    FVisiting: TList<Pointer>;
    FTextLength: Int64;

    procedure AddTextLength(const Count: Int64);
    function MeasuredNode(const Node: TJSONValue): TJSONValue;
    function ConvertArray(const Value: TJSValue): TJSONValue;
    function ConvertObject(const Value: TJSValue): TJSONValue;
    function ConvertContainer(const Value: TJSValue; const Build: TFunc<TJSONValue>): TJSONValue;
    function ConvertScalar(const Value: TJSValue): TJSONValue;

  public
    constructor Create(const Limits: TJSLimits);
    destructor Destroy; override;

    function Convert(const Value: TJSValue): TJSONValue;
  end;

implementation

uses
  System.Math,
  JS4D.Errors;

const
  JsonCircularMessage = 'Converting circular structure to JSON';
  JsonEmptyContainerLength = 2;
  JsonSeparatorLength = 1;

{ TJSONConverter }

constructor TJSONConverter.Create(const Limits: TJSLimits);
begin
  inherited Create;
  FLimits := Limits;
  FVisiting := TList<Pointer>.Create;
  FTextLength := 0;
end;

destructor TJSONConverter.Destroy;
begin
  FVisiting.Free;
  inherited;
end;

procedure TJSONConverter.AddTextLength(const Count: Int64);
begin
  Inc(FTextLength, Count);
  FLimits.EnsureStringLength(FTextLength);
end;

function TJSONConverter.MeasuredNode(const Node: TJSONValue): TJSONValue;
begin
  try
    const NodeText = Node.ToJSON;
    const NodeLength = Length(NodeText);

    AddTextLength(NodeLength);
  except
    // The node is not handed to a parent yet, so free it before the limit error goes on.
    Node.Free;
    raise;
  end;

  Result := Node;
end;

function TJSONConverter.Convert(const Value: TJSValue): TJSONValue;
begin
  if Value.IsArray then
  begin
    Result := ConvertArray(Value);
    Exit;
  end;

  if Value.IsFunction then
  begin
    Result := ConvertScalar(TJSValue.CreateNull);
    Exit;
  end;

  if Value.IsObject then
  begin
    Result := ConvertObject(Value);
    Exit;
  end;

  Result := ConvertScalar(Value);
end;

function TJSONConverter.ConvertScalar(const Value: TJSValue): TJSONValue;
begin
  const Number = Value.AsNumber;
  const IsFiniteNumber = Value.IsNumber and (not System.Math.IsNaN(Number)) and (not System.Math.IsInfinite(Number));

  if IsFiniteNumber then
  begin
    const NumberNode = TJSONNumber.Create(Number);

    Result := MeasuredNode(NumberNode);
    Exit;
  end;

  if Value.IsBoolean then
  begin
    const BoolNode = TJSONBool.Create(Value.AsBoolean);

    Result := MeasuredNode(BoolNode);
    Exit;
  end;

  if Value.IsString then
  begin
    const StringNode = TJSONString.Create(Value.AsString);

    Result := MeasuredNode(StringNode);
    Exit;
  end;

  const NullNode = TJSONNull.Create;

  Result := MeasuredNode(NullNode);
end;

function TJSONConverter.ConvertContainer(const Value: TJSValue; const Build: TFunc<TJSONValue>): TJSONValue;
begin
  const Identity = Value.ToObject;
  const Marker = Pointer(Identity as IInterface);

  if FVisiting.Contains(Marker) then
    raise TJSErrorFactory.TypeError(JsonCircularMessage);

  const NestingDepth = FVisiting.Count + 1;

  FLimits.EnsureNestingDepth(NestingDepth);

  FVisiting.Add(Marker);
  try
    Result := Build();
  finally
    FVisiting.Delete(FVisiting.Count - 1);
  end;
end;

function TJSONConverter.ConvertArray(const Value: TJSValue): TJSONValue;
begin
  Result := ConvertContainer(Value,
    function: TJSONValue
    begin
      AddTextLength(JsonEmptyContainerLength);

      const JSONArray = TJSONArray.Create;
      try
        var ArrIntf: IJSArray;

        if Supports(Value.ToObject, IJSArray, ArrIntf) then
        begin
          for var Index := 0 to ArrIntf.Length - 1 do
          begin
            const IsNotFirst = (Index > 0);

            if IsNotFirst then
              AddTextLength(JsonSeparatorLength);

            const Element = ArrIntf[Index];
            const ElementNode = Convert(Element);

            JSONArray.AddElement(ElementNode);
          end;
        end;
      except
        // Free the half-built array, then let the original error through.
        JSONArray.Free;
        raise;
      end;

      Result := JSONArray;
    end);
end;

function TJSONConverter.ConvertObject(const Value: TJSValue): TJSONValue;
begin
  Result := ConvertContainer(Value,
    function: TJSONValue
    begin
      AddTextLength(JsonEmptyContainerLength);

      const JSONObject = TJSONObject.Create;
      try
        const SourceObject = Value.ToObject;
        var IsFirstMember := True;

        for var PropName in SourceObject.GetOwnPropertyNames do
        begin
          const PropValue = SourceObject.GetProperty(PropName);

          if PropValue.IsFunction then
            Continue;

          if not IsFirstMember then
            AddTextLength(JsonSeparatorLength);

          IsFirstMember := False;

          // The key text plus the colon that follows it.
          const KeyNode = TJSONString.Create(PropName);
          try
            const KeyText = KeyNode.ToJSON;
            const KeyLength = Length(KeyText) + JsonSeparatorLength;

            AddTextLength(KeyLength);
          finally
            KeyNode.Free;
          end;

          const MemberNode = Convert(PropValue);

          JSONObject.AddPair(PropName, MemberNode);
        end;
      except
        // Free the half-built object, then let the original error through.
        JSONObject.Free;
        raise;
      end;

      Result := JSONObject;
    end);
end;

end.
