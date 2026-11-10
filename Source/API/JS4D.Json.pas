unit JS4D.Json;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types;

type
  TJSJsonWriter = class
  private
    const
      MaxGapLength = 10;
      ToJsonName = 'toJSON';
      QuoteCharacter = '"';
      NullLiteral = 'null';
      TrueLiteral = 'true';
      FalseLiteral = 'false';
      CircularMessage = 'Converting circular structure to JSON';
      UnsupportedTypeMessage = 'Unsupported value type: %d';

    var
      FLimits: TJSLimits;
      FObjectPrototype: IJSObject;
      FOutput: TStringBuilder;
      FVisiting: TList<Pointer>;
      FReplacer: IJSFunction;
      FAllowedKeys: TList<string>;
      FHasAllowedKeys: Boolean;
      FGap: string;
      FIndent: string;

    procedure Append(const Text: string);
    procedure AppendQuoted(const Text: string);
    procedure AppendEscaped(const Character: Char);
    procedure AppendNewLine;

    function TextOf(const Value: TJSValue): string;
    procedure ConfigureReplacer(const Replacer: TJSValue);
    procedure ConfigureAllowedKeys(const Replacer: IJSArray);
    function TryKeyOfReplacerEntry(const Entry: TJSValue; out Key: string): Boolean;
    procedure ConfigureGap(const Space: TJSValue);

    function TryGetWrapper(const Value: TJSValue; out Wrapper: IJSPrimitiveWrapper): Boolean;
    function ApplyToJson(const Key: string; const Value: TJSValue): TJSValue;
    function ApplyReplacer(const Key: string; const Holder: IJSObject; const Value: TJSValue): TJSValue;
    function Unwrapped(const Value: TJSValue): TJSValue;
    function TryPrepare(const Key: string; const Holder: IJSObject; out Prepared: TJSValue): Boolean;

    function MemberKeys(const Target: IJSObject): TArray<string>;
    function EnterContainer(const Target: IJSObject; const OpenBracket: Char): string;
    procedure LeaveContainer(const PreviousIndent: string; const HasContent: Boolean; const CloseBracket: Char);
    procedure BeginEntry(const IsFirst: Boolean);

    procedure WriteValue(const Value: TJSValue);
    procedure WriteNumber(const Value: TJSValue);
    procedure WriteContainer(const Value: TJSValue);
    procedure WriteArray(const Target: IJSObject);
    procedure WriteObject(const Target: IJSObject);

  public
    constructor Create(const Limits: TJSLimits; const ObjectPrototype: IJSObject);
    destructor Destroy; override;

    function TryStringify(const Value, Replacer, Space: TJSValue; out Text: string): Boolean;
  end;

implementation

uses
  System.Math,
  System.StrUtils,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.ObjectKeys;

{ TJSJsonWriter }

constructor TJSJsonWriter.Create(const Limits: TJSLimits; const ObjectPrototype: IJSObject);
begin
  inherited Create;
  FLimits := Limits;
  FObjectPrototype := ObjectPrototype;
  FOutput := TStringBuilder.Create;
  FVisiting := TList<Pointer>.Create;
  FAllowedKeys := TList<string>.Create;
end;

destructor TJSJsonWriter.Destroy;
begin
  FAllowedKeys.Free;
  FVisiting.Free;
  FOutput.Free;
  inherited;
end;

procedure TJSJsonWriter.Append(const Text: string);
begin
  FOutput.Append(Text);
  FLimits.EnsureStringLength(FOutput.Length);
end;

procedure TJSJsonWriter.AppendNewLine;
begin
  Append(#10 + FIndent);
end;

procedure TJSJsonWriter.AppendEscaped(const Character: Char);
begin
  case Character of
    '"' : FOutput.Append('\"');
    '\' : FOutput.Append('\\');
    #8  : FOutput.Append('\b');
    #9  : FOutput.Append('\t');
    #10 : FOutput.Append('\n');
    #12 : FOutput.Append('\f');
    #13 : FOutput.Append('\r');
  else
    const IsControlCharacter = (Character < ' ');
    if IsControlCharacter then
      FOutput.Append('\u').Append(LowerCase(IntToHex(Ord(Character), 4)))
    else
      FOutput.Append(Character);
  end;
end;

procedure TJSJsonWriter.AppendQuoted(const Text: string);
begin
  FOutput.Append(QuoteCharacter);
  for var Character in Text do
  begin
    AppendEscaped(Character);
  end;
  FOutput.Append(QuoteCharacter);

  FLimits.EnsureStringLength(FOutput.Length);
end;

procedure TJSJsonWriter.ConfigureReplacer(const Replacer: TJSValue);
begin
  FReplacer := nil;
  FHasAllowedKeys := False;
  FAllowedKeys.Clear;

  if not Replacer.IsObject then
    Exit;

  var ReplacerFunction: IJSFunction;
  var ReplacerArray: IJSArray;
  const ReplacerObject = Replacer.ToObject;

  if Replacer.IsFunction and Supports(ReplacerObject, IJSFunction, ReplacerFunction) then
    FReplacer := ReplacerFunction
  else if Replacer.IsArray and Supports(ReplacerObject, IJSArray, ReplacerArray) then
    ConfigureAllowedKeys(ReplacerArray);
end;

function TJSJsonWriter.TextOf(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitive(True);

  Result := Primitive.ToString;
end;

procedure TJSJsonWriter.ConfigureAllowedKeys(const Replacer: IJSArray);
begin
  FHasAllowedKeys := True;

  const Count = TJSArrayLike.ToLength(Replacer);
  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Key: string;
    const Entry = Replacer.GetProperty(TJSArrayLike.IndexName(Index));
    const IsUsable = TryKeyOfReplacerEntry(Entry, Key);
    const IsNew = (IsUsable and (not FAllowedKeys.Contains(Key)));
    if IsNew then
      FAllowedKeys.Add(Key);
  end;
end;

function TJSJsonWriter.TryKeyOfReplacerEntry(const Entry: TJSValue; out Key: string): Boolean;
begin
  Key := '';

  if Entry.IsString or Entry.IsNumber then
  begin
    Key := Entry.ToString;
    Exit(True);
  end;

  var Wrapper: IJSPrimitiveWrapper;
  const IsWrapper = TryGetWrapper(Entry, Wrapper);
  if not IsWrapper then
    Exit(False);

  const Primitive = Wrapper.Primitive;
  const IsStringOrNumberObject = (Primitive.IsString or Primitive.IsNumber);
  if IsStringOrNumberObject then
    Key := TextOf(Entry);

  Result := IsStringOrNumberObject;
end;

procedure TJSJsonWriter.ConfigureGap(const Space: TJSValue);
begin
  FGap := '';
  FIndent := '';

  const Resolved = Unwrapped(Space);

  if Resolved.IsNumber then
  begin
    const Requested = TJSArrayLike.ToInteger(Resolved);
    const NeedsGap = (Requested >= 1);
    if NeedsGap then
    begin
      const Count = Trunc(Min(Requested, Double(MaxGapLength)));

      FGap := StringOfChar(' ', Count);
    end;
  end
  else if Resolved.IsString then
  begin
    FGap := Copy(Resolved.AsString, 1, MaxGapLength);
  end;
end;

function TJSJsonWriter.TryGetWrapper(const Value: TJSValue; out Wrapper: IJSPrimitiveWrapper): Boolean;
begin
  Result := Value.IsObject and Supports(Value.ToObject, IJSPrimitiveWrapper, Wrapper);
end;

function TJSJsonWriter.ApplyToJson(const Key: string; const Value: TJSValue): TJSValue;
begin
  Result := Value;
  if not Value.IsObject then
    Exit;

  var ToJson: IJSFunction;
  const Source = Value.ToObject;
  const Candidate = Source.GetProperty(ToJsonName);
  const IsCallable = (Candidate.IsFunction and Supports(Candidate.ToObject, IJSFunction, ToJson));
  if not IsCallable then
    Exit;

  const KeyArgument = TJSValue.CreateString(Key);

  Result := ToJson.Call(Source, [KeyArgument]);
end;

function TJSJsonWriter.ApplyReplacer(const Key: string; const Holder: IJSObject; const Value: TJSValue): TJSValue;
begin
  if not Assigned(FReplacer) then
    Exit(Value);

  const KeyArgument = TJSValue.CreateString(Key);

  Result := FReplacer.Call(Holder, [KeyArgument, Value]);
end;

function TJSJsonWriter.Unwrapped(const Value: TJSValue): TJSValue;
begin
  Result := Value;

  var Wrapper: IJSPrimitiveWrapper;
  if not TryGetWrapper(Value, Wrapper) then
    Exit;

  const Primitive = Wrapper.Primitive;

  if Primitive.IsNumber then
  begin
    const Number = TJSArrayLike.ToNumber(Value);

    Result := TJSValue.CreateNumber(Number);
  end
  else if Primitive.IsString then
  begin
    Result := TJSValue.CreateString(TextOf(Value));
  end
  else
  begin
    Result := Primitive;
  end;
end;

function TJSJsonWriter.TryPrepare(const Key: string; const Holder: IJSObject; out Prepared: TJSValue): Boolean;
begin
  var Current := Holder.GetProperty(Key);
  Current := ApplyToJson(Key, Current);
  Current := ApplyReplacer(Key, Holder, Current);
  Prepared := Unwrapped(Current);

  const IsOmitted = (Prepared.IsUndefined or Prepared.IsFunction);
  Result := not IsOmitted;
end;

function TJSJsonWriter.MemberKeys(const Target: IJSObject): TArray<string>;
begin
  if not FHasAllowedKeys then
    Exit(TJSObjectKeys.Enumerable(Target));

  Result := FAllowedKeys.ToArray;
end;

function TJSJsonWriter.EnterContainer(const Target: IJSObject; const OpenBracket: Char): string;
begin
  const Marker = Pointer(Target as IInterface);

  if FVisiting.Contains(Marker) then
    raise TJSErrorFactory.TypeError(CircularMessage);

  FLimits.EnsureNestingDepth(FVisiting.Count + 1);
  FVisiting.Add(Marker);

  Result := FIndent;
  FIndent := FIndent + FGap;

  Append(OpenBracket);
end;

procedure TJSJsonWriter.LeaveContainer(const PreviousIndent: string; const HasContent: Boolean;
                                       const CloseBracket: Char);
begin
  FIndent := PreviousIndent;
  FVisiting.Delete(FVisiting.Count - 1);

  const NeedsNewLine = (HasContent and (not FGap.IsEmpty));
  if NeedsNewLine then
    AppendNewLine;

  Append(CloseBracket);
end;

procedure TJSJsonWriter.BeginEntry(const IsFirst: Boolean);
begin
  if not IsFirst then
    Append(',');

  if not FGap.IsEmpty then
    AppendNewLine;
end;

procedure TJSJsonWriter.WriteNumber(const Value: TJSValue);
begin
  const Number = Value.AsNumber;
  const IsFiniteNumber = ((not System.Math.IsNaN(Number)) and (not System.Math.IsInfinite(Number)));

  if IsFiniteNumber then
    Append(Value.ToString)
  else
    Append(NullLiteral);
end;

procedure TJSJsonWriter.WriteContainer(const Value: TJSValue);
begin
  const Target = Value.ToObject;

  if Value.IsArray then
    WriteArray(Target)
  else
    WriteObject(Target);
end;

procedure TJSJsonWriter.WriteArray(const Target: IJSObject);
begin
  const PreviousIndent = EnterContainer(Target, '[');

  const Count = TJSArrayLike.ToLength(Target);
  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    BeginEntry(Index = 0);

    if TryPrepare(TJSArrayLike.IndexName(Index), Target, Element) then
      WriteValue(Element)
    else
      Append(NullLiteral);
  end;

  LeaveContainer(PreviousIndent, Count > 0, ']');
end;

procedure TJSJsonWriter.WriteObject(const Target: IJSObject);
begin
  const PreviousIndent = EnterContainer(Target, '{');
  const Separator = IfThen(FGap.IsEmpty, ':', ': ');

  var HasMember := False;
  for var Key in MemberKeys(Target) do
  begin
    var Member: TJSValue;
    if TryPrepare(Key, Target, Member) then
    begin
      BeginEntry(not HasMember);
      AppendQuoted(Key);
      Append(Separator);
      WriteValue(Member);

      HasMember := True;
    end;
  end;

  LeaveContainer(PreviousIndent, HasMember, '}');
end;

procedure TJSJsonWriter.WriteValue(const Value: TJSValue);
begin
  case Value.ValueType of
    TJSValueType.Null    : Append(NullLiteral);
    TJSValueType.Boolean_: Append(IfThen(Value.AsBoolean, TrueLiteral, FalseLiteral));
    TJSValueType.Number  : WriteNumber(Value);
    TJSValueType.String_ : AppendQuoted(Value.AsString);
    TJSValueType.Array_,
    TJSValueType.Object_ : WriteContainer(Value);
  else
    raise ENotSupportedException.CreateFmt(UnsupportedTypeMessage, [Ord(Value.ValueType)]);
  end;
end;

function TJSJsonWriter.TryStringify(const Value, Replacer, Space: TJSValue; out Text: string): Boolean;
begin
  Text := '';

  ConfigureReplacer(Replacer);
  ConfigureGap(Space);

  const Holder: IJSObject = TJSObject.Create;
  Holder.Prototype := FObjectPrototype;
  Holder.SetProperty('', Value);

  var Prepared: TJSValue;
  Result := TryPrepare('', Holder, Prepared);
  if not Result then
    Exit;

  WriteValue(Prepared);
  Text := FOutput.ToString;
end;

end.
