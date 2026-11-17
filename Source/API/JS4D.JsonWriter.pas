unit JS4D.JsonWriter;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSJsonWriter = class
  private
    const
      MAX_GAP_LENGTH = 10;
      TO_JSON_NAME = 'toJSON';
      NEW_LINE = #10;
      GAP_CHARACTER = ' ';
      MEMBER_SEPARATOR = ':';
      MEMBER_SEPARATOR_WITH_GAP = ': ';
      UNICODE_ESCAPE_PREFIX = '\u';
      CIRCULAR_MESSAGE = 'Converting circular structure to JSON';

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

    function HasGap: Boolean;
    procedure EnsureOutputWithinLimit;
    procedure Append(const Text: string);
    procedure AppendQuoted(const Text: string);
    procedure AppendCharacter(const Character: Char);
    procedure AppendUnicodeEscape(const Character: Char);
    procedure AppendNewLine;
    class function IsSurrogatePair(const Text: string; const Position: Integer): Boolean; static;

    function TextOf(const Value: TJSValue): string;
    procedure ConfigureReplacer(const Replacer: TJSValue);
    procedure ConfigureAllowedKeys(const Replacer: IJSObject);
    function TryKeyOfReplacerEntry(const Entry: TJSValue; out Key: string): Boolean;
    procedure ConfigureGap(const Space: TJSValue);

    function TryGetWrapper(const Value: TJSValue; out Wrapper: IJSPrimitiveWrapper): Boolean;
    function ApplyToJson(const Key: string; const Value: TJSValue): TJSValue;
    function ApplyReplacer(const Key: string; const Holder: IJSObject; const Value: TJSValue): TJSValue;
    function Unwrapped(const Value: TJSValue): TJSValue;
    function TryPrepare(const Key: string; const Holder: IJSObject; out Prepared: TJSValue): Boolean;

    function MemberKeys(const Target: IJSObject): TArray<string>;
    procedure OpenContainer(const Target: IJSObject; const OpenBracket: Char);
    procedure CloseContainer(const PreviousIndent: string; const HasContent: Boolean; const CloseBracket: Char);
    procedure BeginEntry(const IsFirst: Boolean);

    procedure WriteValue(const Value: TJSValue);
    procedure RaiseUnsupportedType(const ValueType: TJSValueType);
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
  System.Character,
  System.StrUtils,
  JS4D.Errors,
  JS4D.ArrayLike,
  JS4D.MathFunctions,
  JS4D.ObjectKeys,
  JS4D.ObjectOperations,
  JS4D.JsonGrammar,
  JS4D.JsonRoot;

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

function TJSJsonWriter.HasGap: Boolean;
begin
  Result := not FGap.IsEmpty;
end;

procedure TJSJsonWriter.EnsureOutputWithinLimit;
begin
  FLimits.EnsureStringLength(FOutput.Length);
end;

procedure TJSJsonWriter.Append(const Text: string);
begin
  FOutput.Append(Text);
  EnsureOutputWithinLimit;
end;

procedure TJSJsonWriter.AppendNewLine;
begin
  Append(NEW_LINE);
  Append(FIndent);
end;

class function TJSJsonWriter.IsSurrogatePair(const Text: string; const Position: Integer): Boolean;
begin
  const HasNext = (Position < Length(Text));

  Result := (HasNext and Text[Position].IsHighSurrogate and Text[Position + 1].IsLowSurrogate);
end;

procedure TJSJsonWriter.AppendUnicodeEscape(const Character: Char);
begin
  const HexDigits = LowerCase(IntToHex(Ord(Character), 4));

  FOutput.Append(UNICODE_ESCAPE_PREFIX);
  FOutput.Append(HexDigits);
end;

procedure TJSJsonWriter.AppendCharacter(const Character: Char);
begin
  case Character of
    JSON_QUOTE  : FOutput.Append('\"');
    JSON_ESCAPE : FOutput.Append('\\');
    #8          : FOutput.Append('\b');
    #9          : FOutput.Append('\t');
    #10         : FOutput.Append('\n');
    #12         : FOutput.Append('\f');
    #13         : FOutput.Append('\r');
  else
    const NeedsUnicodeEscape = ((Character < ' ') or Character.IsSurrogate);
    if NeedsUnicodeEscape then
      AppendUnicodeEscape(Character)
    else
      FOutput.Append(Character);
  end;
end;

procedure TJSJsonWriter.AppendQuoted(const Text: string);
begin
  FOutput.Append(JSON_QUOTE);

  var Position := 1;
  while Position <= Length(Text) do
  begin
    if IsSurrogatePair(Text, Position) then
    begin
      FOutput.Append(Text[Position]);
      FOutput.Append(Text[Position + 1]);
      Inc(Position, 2);
    end
    else
    begin
      AppendCharacter(Text[Position]);
      Inc(Position);
    end;

    EnsureOutputWithinLimit;
  end;

  FOutput.Append(JSON_QUOTE);
  EnsureOutputWithinLimit;
end;

procedure TJSJsonWriter.ConfigureReplacer(const Replacer: TJSValue);
begin
  FReplacer := nil;
  FHasAllowedKeys := False;
  FAllowedKeys.Clear;

  if not Replacer.IsObject then
    Exit;

  var ReplacerFunction: IJSFunction;
  const ReplacerObject = Replacer.ToObject;

  if Replacer.IsFunction and Supports(ReplacerObject, IJSFunction, ReplacerFunction) then
    FReplacer := ReplacerFunction
  else if TJSObjectOperations.IsArray(Replacer) then
    ConfigureAllowedKeys(ReplacerObject);
end;

function TJSJsonWriter.TextOf(const Value: TJSValue): string;
begin
  const Primitive = Value.ToPrimitive(True);

  Result := Primitive.ToString;
end;

procedure TJSJsonWriter.ConfigureAllowedKeys(const Replacer: IJSObject);
begin
  FHasAllowedKeys := True;

  const Count = TJSArrayLike.ToLength(Replacer);
  FLimits.EnsureArrayLength(Count);

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
      const MaxGapWidth: Double = MAX_GAP_LENGTH;
      const Capped = Min(Requested, MaxGapWidth);
      const Count = Trunc(Capped);

      FGap := StringOfChar(GAP_CHARACTER, Count);
    end;
  end
  else if Resolved.IsString then
  begin
    FGap := Copy(Resolved.AsString, 1, MAX_GAP_LENGTH);
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
  const Candidate = Source.GetProperty(TO_JSON_NAME);
  const IsCallable = (Candidate.IsFunction and Supports(Candidate.ToObject, IJSFunction, ToJson));
  if not IsCallable then
    Exit;

  const KeyArgument = TJSValue.CreateString(Key);

  Result := ToJson.Call(Source, [KeyArgument]);
end;

function TJSJsonWriter.ApplyReplacer(const Key: string; const Holder: IJSObject; const Value: TJSValue): TJSValue;
begin
  if not Assigned(FReplacer) then
  begin
    Result := Value;
    Exit;
  end;

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
    const Text = TextOf(Value);

    Result := TJSValue.CreateString(Text);
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

  const IsOmitted = (Prepared.IsUndefined or Prepared.IsFunction or Prepared.IsSymbol);
  Result := not IsOmitted;
end;

function TJSJsonWriter.MemberKeys(const Target: IJSObject): TArray<string>;
begin
  if FHasAllowedKeys then
    Result := FAllowedKeys.ToArray
  else
    Result := TJSObjectKeys.Enumerable(Target);
end;

procedure TJSJsonWriter.OpenContainer(const Target: IJSObject; const OpenBracket: Char);
begin
  const Marker = TJSObjectOperations.IdentityOf(Target);

  if FVisiting.Contains(Marker) then
    raise TJSErrorFactory.TypeError(CIRCULAR_MESSAGE);

  FLimits.EnsureNestingDepth(FVisiting.Count + 1);
  FVisiting.Add(Marker);

  FIndent := FIndent + FGap;

  Append(OpenBracket);
end;

procedure TJSJsonWriter.CloseContainer(const PreviousIndent: string; const HasContent: Boolean;
                                       const CloseBracket: Char);
begin
  FIndent := PreviousIndent;
  FVisiting.Delete(FVisiting.Count - 1);

  const NeedsNewLine = (HasContent and HasGap);
  if NeedsNewLine then
    AppendNewLine;

  Append(CloseBracket);
end;

procedure TJSJsonWriter.BeginEntry(const IsFirst: Boolean);
begin
  if not IsFirst then
    Append(JSON_COMMA);

  if HasGap then
    AppendNewLine;
end;

procedure TJSJsonWriter.WriteNumber(const Value: TJSValue);
begin
  const Number = Value.AsNumber;

  if TJSMathFunctions.IsFiniteNumber(Number) then
    Append(Value.ToString)
  else
    Append(JSON_NULL_LITERAL);
end;

procedure TJSJsonWriter.WriteContainer(const Value: TJSValue);
begin
  const Target = Value.ToObject;

  if TJSObjectOperations.IsArray(Value) then
    WriteArray(Target)
  else
    WriteObject(Target);
end;

procedure TJSJsonWriter.WriteArray(const Target: IJSObject);
begin
  const PreviousIndent = FIndent;
  OpenContainer(Target, JSON_ARRAY_START);

  const Count = TJSArrayLike.ToLength(Target);
  for var Index: Int64 := 0 to Count - 1 do
  begin
    var Element: TJSValue;
    const IsFirst = (Index = 0);
    BeginEntry(IsFirst);

    if TryPrepare(TJSArrayLike.IndexName(Index), Target, Element) then
      WriteValue(Element)
    else
      Append(JSON_NULL_LITERAL);
  end;

  const HasContent = (Count > 0);
  CloseContainer(PreviousIndent, HasContent, JSON_ARRAY_END);
end;

procedure TJSJsonWriter.WriteObject(const Target: IJSObject);
begin
  const PreviousIndent = FIndent;
  OpenContainer(Target, JSON_OBJECT_START);

  const Separator = IfThen(HasGap, MEMBER_SEPARATOR_WITH_GAP, MEMBER_SEPARATOR);

  var HasMember := False;
  for var Key in MemberKeys(Target) do
  begin
    var Member: TJSValue;
    if TryPrepare(Key, Target, Member) then
    begin
      const IsFirst = (not HasMember);
      BeginEntry(IsFirst);
      AppendQuoted(Key);
      Append(Separator);
      WriteValue(Member);

      HasMember := True;
    end;
  end;

  CloseContainer(PreviousIndent, HasMember, JSON_OBJECT_END);
end;

procedure TJSJsonWriter.WriteValue(const Value: TJSValue);
begin
  case Value.ValueType of
    TJSValueType.Null    : Append(JSON_NULL_LITERAL);
    TJSValueType.Boolean_: Append(IfThen(Value.AsBoolean, JSON_TRUE_LITERAL, JSON_FALSE_LITERAL));
    TJSValueType.Number  : WriteNumber(Value);
    TJSValueType.String_ : AppendQuoted(Value.AsString);
    TJSValueType.Array_,
    TJSValueType.Object_ : WriteContainer(Value);
  else
    RaiseUnsupportedType(Value.ValueType);
  end;
end;

procedure TJSJsonWriter.RaiseUnsupportedType(const ValueType: TJSValueType);
begin
  const Message = Format(UNSUPPORTED_VALUE_TYPE_MESSAGE, [Ord(ValueType)]);

  raise TJSErrorFactory.TypeError(Message);
end;

function TJSJsonWriter.TryStringify(const Value, Replacer, Space: TJSValue; out Text: string): Boolean;
begin
  Text := '';

  ConfigureReplacer(Replacer);
  ConfigureGap(Space);

  const Holder = TJSJsonRoot.CreateHolder(FObjectPrototype, Value);

  var Prepared: TJSValue;
  Result := TryPrepare(TJSJsonRoot.KEY, Holder, Prepared);
  if not Result then
    Exit;

  WriteValue(Prepared);
  Text := FOutput.ToString;
end;

end.
