unit JS4D.RegExpProtocol;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSRegExpProtocol = class
  private
    const
      EXEC_PROPERTY = 'exec';
      FLAGS_PROPERTY = 'flags';
      LAST_INDEX_PROPERTY = 'lastIndex';
      INDEX_PROPERTY = 'index';
      LENGTH_PROPERTY = 'length';
      GROUPS_PROPERTY = 'groups';
      CONSTRUCTOR_PROPERTY = 'constructor';
      REGEXP_NAME = 'RegExp';
      TEST_NAME = 'test';
      MATCH_NAME = '[Symbol.match]';
      REPLACE_NAME = '[Symbol.replace]';
      SEARCH_NAME = '[Symbol.search]';
      SPLIT_NAME = '[Symbol.split]';
      GLOBAL_FLAG = 'g';
      UNICODE_FLAG = 'u';
      STICKY_FLAG = 'y';
      IGNORE_CASE_FLAG = 'i';
      MULTILINE_FLAG = 'm';
      INITIAL_MATCH_CAPACITY = 16;
      FIRST_CAPTURE_NAME = '0';
      HIGH_SURROGATE_FIRST = $D800;
      HIGH_SURROGATE_LAST = $DBFF;
      LOW_SURROGATE_FIRST = $DC00;
      LOW_SURROGATE_LAST = $DFFF;
      MAX_ARRAY_LENGTH = 4294967295;
      THIS_NOT_AN_OBJECT = 'RegExp.prototype.%s called on a value that is not an object';
      NULL_TO_OBJECT = 'Cannot convert undefined or null to object';
      EXEC_RESULT_INVALID = 'The result of the exec method must be an object or null';
      NOT_A_REGEXP = 'RegExp.prototype.exec called on a value that is not a regular expression';
      CONSTRUCTOR_NOT_AN_OBJECT = 'The constructor property of a regular expression must be an object or undefined';
      SPECIES_NOT_A_CONSTRUCTOR = 'The species of a regular expression constructor must be a constructor, null or undefined';

    type
      TMatchRecord = record
        Result: IJSObject;
        Matched: string;
        Position: Integer;
        Captures: TArray<TJSValue>;
      end;

    var
      FInterpreter: TJSInterpreter;
      FIntrinsicExec: IJSFunction;
      FIntrinsicConstructor: IJSFunction;

    class function AdvanceStringIndex(const Text: string; const Index: Int64; const IsUnicode: Boolean): Int64; static;
    function ToText(const Value: TJSValue): string;
    function ToObjectValue(const Value: TJSValue): IJSObject;
    function RequireReceiver(const This: IJSObject; const MethodName: string): IJSObject;
    function ReadFlags(const Receiver: IJSObject): string;
    function ReadLastIndex(const Receiver: IJSObject): Int64;
    procedure WriteLastIndex(const Receiver: IJSObject; const Index: Int64);
    procedure AdvanceLastIndex(const Receiver: IJSObject; const Text: string; const IsUnicode: Boolean);
    function RegExpExec(const Receiver: IJSObject; const Text: string): TJSValue;
    function UsesIntrinsicExec(const Receiver: IJSObject; out Pattern: IJSRegExp): Boolean;
    function TryCollectPlainMatches(const Receiver: IJSObject; const Text: string; const IsUnicode: Boolean;
                                    out Matches: TArray<TMatchRecord>): Boolean;
    function CollectMatches(const Receiver: IJSObject; const Text: string; const IsGlobal: Boolean;
                            const IsUnicode: Boolean): TArray<TMatchRecord>;
    procedure ReadMatchDetails(var Found: TMatchRecord; const Text: string);
    function CollectCaptures(const Found: IJSObject): TArray<TJSValue>;
    function ReplacementOf(const Found: TMatchRecord; const Text: string; const ReplaceValue: TJSValue;
                           const IsFunctional: Boolean): string;
    function ReplaceWith(const Receiver: IJSObject; const Text: string; const ReplaceValue: TJSValue): TJSValue;
    function SpeciesConstructor(const Receiver: IJSObject): IJSFunction;
    function CreateSplitter(const Species: IJSFunction; const Receiver: IJSObject;
                            const NewFlags: string): IJSObject;
    function TryUseReceiverAsSplitter(const Receiver: IJSObject; const Species: IJSFunction; const Flags: string;
                                      out Pattern: IJSRegExp): Boolean;
    function SplitWithPattern(const Pattern: IJSRegExp; const Text: string; const Limit: Int64;
                              const IsUnicode: Boolean): TJSValue;
    function SplitWith(const Receiver: IJSObject; const Text: string; const LimitValue: TJSValue): TJSValue;
    function Match(const Receiver: IJSObject; const Text: string): TJSValue;
    function Search(const Receiver: IJSObject; const Text: string): TJSValue;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineMethod(const Target: IJSObject; const Key: string; const Name: string;
                           const ParameterCount: Integer; const Method: TNativeFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.ArrayLike,
  JS4D.PatternOperations;

constructor TJSRegExpProtocol.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

destructor TJSRegExpProtocol.Destroy;
begin
  FIntrinsicExec := nil;
  FIntrinsicConstructor := nil;

  inherited Destroy;
end;

class function TJSRegExpProtocol.AdvanceStringIndex(const Text: string; const Index: Int64;
                                                    const IsUnicode: Boolean): Int64;
begin
  Result := Index + 1;

  const HasNextUnit = (Index + 1 < Length(Text));
  if not (IsUnicode and HasNextUnit) then
    Exit;

  const First = Ord(Text[Index + 1]);
  const Second = Ord(Text[Index + 2]);
  const IsSurrogatePair = InRange(First, HIGH_SURROGATE_FIRST, HIGH_SURROGATE_LAST) and
                          InRange(Second, LOW_SURROGATE_FIRST, LOW_SURROGATE_LAST);
  if IsSurrogatePair then
    Result := Index + 2;
end;

function TJSRegExpProtocol.ToText(const Value: TJSValue): string;
begin
  Result := TJSConversions.ToText(Value, FInterpreter.Limits);
end;

function TJSRegExpProtocol.ToObjectValue(const Value: TJSValue): IJSObject;
begin
  if Value.IsObject then
    Exit(Value.ToObject);

  if Value.IsNull then
    raise TJSErrorFactory.TypeError(NULL_TO_OBJECT);

  Result := FInterpreter.WrapPrimitive(Value);
end;

function TJSRegExpProtocol.RequireReceiver(const This: IJSObject; const MethodName: string): IJSObject;
begin
  const IsObject = Assigned(This) and (not Supports(This, IJSPrimitiveWrapper));
  if not IsObject then
    raise TJSErrorFactory.TypeError(Format(THIS_NOT_AN_OBJECT, [MethodName]));

  Result := This;
end;

function TJSRegExpProtocol.ReadFlags(const Receiver: IJSObject): string;
begin
  Result := ToText(Receiver.GetProperty(FLAGS_PROPERTY));
end;

function TJSRegExpProtocol.ReadLastIndex(const Receiver: IJSObject): Int64;
begin
  Result := TJSConversions.ToLength(Receiver.GetProperty(LAST_INDEX_PROPERTY));
end;

procedure TJSRegExpProtocol.WriteLastIndex(const Receiver: IJSObject; const Index: Int64);
begin
  TJSConversions.PutProperty(Receiver, LAST_INDEX_PROPERTY, TJSValue.CreateNumber(Index));
end;

procedure TJSRegExpProtocol.AdvanceLastIndex(const Receiver: IJSObject; const Text: string;
                                             const IsUnicode: Boolean);
begin
  const ThisIndex = ReadLastIndex(Receiver);

  WriteLastIndex(Receiver, AdvanceStringIndex(Text, ThisIndex, IsUnicode));
end;

function TJSRegExpProtocol.RegExpExec(const Receiver: IJSObject; const Text: string): TJSValue;
begin
  const Method = TJSConversions.AsFunction(Receiver.GetProperty(EXEC_PROPERTY));
  if Assigned(Method) then
  begin
    const Returned = Method.Call(Receiver, [TJSValue.CreateString(Text)]);
    const IsValidResult = Returned.IsNull or Returned.IsObject;
    if not IsValidResult then
      raise TJSErrorFactory.TypeError(EXEC_RESULT_INVALID);

    Exit(Returned);
  end;

  var BuiltIn: IJSRegExp;
  if not Supports(Receiver, IJSRegExp, BuiltIn) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP);

  Result := BuiltIn.Exec(Text);
end;

function TJSRegExpProtocol.Match(const Receiver: IJSObject; const Text: string): TJSValue;
begin
  const Flags = ReadFlags(Receiver);
  const IsGlobal = (Pos(GLOBAL_FLAG, Flags) > 0);
  if not IsGlobal then
    Exit(RegExpExec(Receiver, Text));

  const IsUnicode = (Pos(UNICODE_FLAG, Flags) > 0);

  var Plain: TArray<TMatchRecord>;
  if TryCollectPlainMatches(Receiver, Text, IsUnicode, Plain) then
  begin
    if Length(Plain) = 0 then
      Exit(TJSValue.CreateNull);

    const PlainMatches: IJSArray = TJSArray.Create;
    for var Entry in Plain do
    begin
      PlainMatches.Push(TJSValue.CreateString(Entry.Matched));
    end;

    Exit(TJSValue.CreateObject(PlainMatches));
  end;

  WriteLastIndex(Receiver, 0);

  const Matches: IJSArray = TJSArray.Create;
  while True do
  begin
    const Found = RegExpExec(Receiver, Text);
    if Found.IsNull then
      Break;

    const MatchedText = ToText(Found.ToObject.GetProperty(FIRST_CAPTURE_NAME));
    FInterpreter.Limits.EnsureArrayLength(Int64(Matches.Length) + 1);
    Matches.Push(TJSValue.CreateString(MatchedText));

    if MatchedText.IsEmpty then
      AdvanceLastIndex(Receiver, Text, IsUnicode);
  end;

  if Matches.Length = 0 then
    Exit(TJSValue.CreateNull);

  Result := TJSValue.CreateObject(Matches);
end;

function TJSRegExpProtocol.Search(const Receiver: IJSObject; const Text: string): TJSValue;
begin
  const PreviousLastIndex = Receiver.GetProperty(LAST_INDEX_PROPERTY);
  const Zero = TJSValue.CreateNumber(0);
  if not PreviousLastIndex.SameValue(Zero) then
    TJSConversions.PutProperty(Receiver, LAST_INDEX_PROPERTY, Zero);

  const Found = RegExpExec(Receiver, Text);

  const CurrentLastIndex = Receiver.GetProperty(LAST_INDEX_PROPERTY);
  if not CurrentLastIndex.SameValue(PreviousLastIndex) then
    TJSConversions.PutProperty(Receiver, LAST_INDEX_PROPERTY, PreviousLastIndex);

  if Found.IsNull then
    Exit(TJSValue.CreateNumber(-1));

  Result := Found.ToObject.GetProperty(INDEX_PROPERTY);
end;

function TJSRegExpProtocol.UsesIntrinsicExec(const Receiver: IJSObject; out Pattern: IJSRegExp): Boolean;
begin
  Result := False;

  if not Supports(Receiver, IJSRegExp, Pattern) then
    Exit;

  var Descriptor: TJSPropertyDescriptor;
  if not Receiver.TryGetPropertyDescriptor(EXEC_PROPERTY, Descriptor) then
    Exit;

  const IsIntrinsic = (not Descriptor.IsAccessor) and Descriptor.Value.IsFunction and
                      ((Descriptor.Value.AsObject as IInterface) = (FIntrinsicExec as IInterface));
  Result := IsIntrinsic;
end;

function TJSRegExpProtocol.TryCollectPlainMatches(const Receiver: IJSObject; const Text: string;
                                                  const IsUnicode: Boolean;
                                                  out Matches: TArray<TMatchRecord>): Boolean;
begin
  Matches := nil;

  var Pattern: IJSRegExp;
  const IsPlain = UsesIntrinsicExec(Receiver, Pattern) and Pattern.Global and (not Pattern.Sticky) and
                  (Pattern.Unicode = IsUnicode);
  if not IsPlain then
    Exit(False);

  WriteLastIndex(Receiver, 0);

  var Count := 0;
  var Position := 0;
  while Position <= Length(Text) do
  begin
    const Found = Pattern.MatchAt(Text, Position);
    if not Found.Found then
      Break;

    FInterpreter.Limits.EnsureArrayLength(Int64(Count) + 1);
    if Count = Length(Matches) then
      SetLength(Matches, Max(Count * 2, INITIAL_MATCH_CAPACITY));

    Matches[Count].Matched := Copy(Text, Found.Index + 1, Found.Length);
    Matches[Count].Position := Found.Index;
    Matches[Count].Captures := Found.Captures;
    Inc(Count);

    Position := Found.Index + Found.Length;
    if Found.Length = 0 then
      Position := Integer(AdvanceStringIndex(Text, Position, IsUnicode));
  end;

  SetLength(Matches, Count);
  Result := True;
end;

procedure TJSRegExpProtocol.ReadMatchDetails(var Found: TMatchRecord; const Text: string);
begin
  if not Assigned(Found.Result) then
    Exit;

  Found.Matched := ToText(Found.Result.GetProperty(FIRST_CAPTURE_NAME));

  const RawPosition = TJSConversions.ToIntegerOrInfinity(Found.Result.GetProperty(INDEX_PROPERTY));
  Found.Position := Trunc(EnsureRange(RawPosition, 0, Length(Text)));
end;

function TJSRegExpProtocol.CollectMatches(const Receiver: IJSObject; const Text: string; const IsGlobal: Boolean;
                                          const IsUnicode: Boolean): TArray<TMatchRecord>;
begin
  Result := nil;

  if IsGlobal then
    WriteLastIndex(Receiver, 0);

  while True do
  begin
    const Found = RegExpExec(Receiver, Text);
    if Found.IsNull then
      Break;

    var Entry := Default(TMatchRecord);
    Entry.Result := Found.ToObject;
    Result := Result + [Entry];

    if not IsGlobal then
      Break;

    const MatchedText = ToText(Entry.Result.GetProperty(FIRST_CAPTURE_NAME));
    if MatchedText.IsEmpty then
      AdvanceLastIndex(Receiver, Text, IsUnicode);
  end;
end;

function TJSRegExpProtocol.CollectCaptures(const Found: IJSObject): TArray<TJSValue>;
begin
  const ResultLength = TJSConversions.ToLength(Found.GetProperty(LENGTH_PROPERTY));
  const CaptureCount = Max(ResultLength - 1, 0);
  FInterpreter.Limits.EnsureArrayLength(CaptureCount);

  SetLength(Result, CaptureCount);
  for var Number := 1 to CaptureCount do
  begin
    var Capture := Found.GetProperty(IntToStr(Number));
    if not Capture.IsUndefined then
      Capture := TJSValue.CreateString(ToText(Capture));

    Result[Number - 1] := Capture;
  end;
end;

function TJSRegExpProtocol.ReplacementOf(const Found: TMatchRecord; const Text: string; const ReplaceValue: TJSValue;
                                         const IsFunctional: Boolean): string;
begin
  var Captures := Found.Captures;
  var NamedCaptures := TJSValue.CreateUndefined;
  if Assigned(Found.Result) then
  begin
    Captures := CollectCaptures(Found.Result);
    NamedCaptures := Found.Result.GetProperty(GROUPS_PROPERTY);
  end;

  if IsFunctional then
  begin
    const Func = TJSConversions.AsFunction(ReplaceValue);

    var CallArgs: TArray<TJSValue> := [TJSValue.CreateString(Found.Matched)];
    CallArgs := CallArgs + Captures;
    CallArgs := CallArgs + [TJSValue.CreateNumber(Found.Position), TJSValue.CreateString(Text)];
    if not NamedCaptures.IsUndefined then
      CallArgs := CallArgs + [NamedCaptures];

    const ThisArg = FInterpreter.ThisObjectFor(Func, TJSValue.CreateUndefined);
    Exit(ToText(FInterpreter.CallFunction(Func, CallArgs, ThisArg)));
  end;

  var NamedObject: IJSObject := nil;
  if not NamedCaptures.IsUndefined then
    NamedObject := ToObjectValue(NamedCaptures);

  Result := TJSPatternOperations.GetSubstitution(ReplaceValue.AsString, Text, Found.Position, Found.Matched,
                                                 Captures, NamedObject, FInterpreter.Limits);
end;

function TJSRegExpProtocol.ReplaceWith(const Receiver: IJSObject; const Text: string;
                                       const ReplaceValue: TJSValue): TJSValue;
begin
  const IsFunctional = TJSConversions.IsCallable(ReplaceValue);
  var Replacement := ReplaceValue;
  if not IsFunctional then
    Replacement := TJSValue.CreateString(ToText(ReplaceValue));

  const Flags = ReadFlags(Receiver);
  const IsGlobal = (Pos(GLOBAL_FLAG, Flags) > 0);
  const IsUnicode = (Pos(UNICODE_FLAG, Flags) > 0);

  var Matches: TArray<TMatchRecord>;
  const IsPlain = IsGlobal and TryCollectPlainMatches(Receiver, Text, IsUnicode, Matches);
  if not IsPlain then
    Matches := CollectMatches(Receiver, Text, IsGlobal, IsUnicode);

  const Builder = TStringBuilder.Create;
  try
    var NextSourcePosition := 0;
    for var Index := 0 to High(Matches) do
    begin
      ReadMatchDetails(Matches[Index], Text);

      const Replaced = ReplacementOf(Matches[Index], Text, Replacement, IsFunctional);

      const Position = Matches[Index].Position;
      const IsInOrder = (Position >= NextSourcePosition);
      if IsInOrder then
      begin
        Builder.Append(Copy(Text, NextSourcePosition + 1, Position - NextSourcePosition));
        Builder.Append(Replaced);
        FInterpreter.Limits.EnsureStringLength(Builder.Length);

        NextSourcePosition := Position + Length(Matches[Index].Matched);
      end;
    end;

    Builder.Append(Copy(Text, NextSourcePosition + 1, MaxInt));
    FInterpreter.Limits.EnsureStringLength(Builder.Length);

    Result := TJSValue.CreateString(Builder.ToString);
  finally
    Builder.Free;
  end;
end;

function TJSRegExpProtocol.SpeciesConstructor(const Receiver: IJSObject): IJSFunction;
begin
  const DefaultConstructor = FInterpreter.GetGlobalVariable(REGEXP_NAME);
  const ConstructorValue = Receiver.GetProperty(CONSTRUCTOR_PROPERTY);
  if ConstructorValue.IsUndefined then
    Exit(TJSConversions.AsFunction(DefaultConstructor));

  if not ConstructorValue.IsObject then
    raise TJSErrorFactory.TypeError(CONSTRUCTOR_NOT_AN_OBJECT);

  const SpeciesKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Species);
  const Species = ConstructorValue.ToObject.GetProperty(SpeciesKey);
  if Species.IsNullOrUndefined then
    Exit(TJSConversions.AsFunction(DefaultConstructor));

  Result := TJSConversions.AsFunction(Species);
  const IsConstructor = Assigned(Result) and Result.IsConstructor;
  if not IsConstructor then
    raise TJSErrorFactory.TypeError(SPECIES_NOT_A_CONSTRUCTOR);
end;

function TJSRegExpProtocol.CreateSplitter(const Species: IJSFunction; const Receiver: IJSObject;
                                          const NewFlags: string): IJSObject;
begin
  const ConstructorArgs: TArray<TJSValue> = [TJSValue.CreateObject(Receiver), TJSValue.CreateString(NewFlags)];
  const Created = FInterpreter.Construct(Species, ConstructorArgs);

  Result := Created.ToObject;
end;

function TJSRegExpProtocol.TryUseReceiverAsSplitter(const Receiver: IJSObject; const Species: IJSFunction;
                                                    const Flags: string; out Pattern: IJSRegExp): Boolean;
begin
  const IsIntrinsicSpecies = Assigned(Species) and
                             ((Species as IInterface) = (FIntrinsicConstructor as IInterface));
  const HasOnlyLastIndex = (Length(Receiver.GetOwnPropertyNames) = 1) and (Length(Receiver.GetOwnSymbolKeys) = 0);
  const IsPristine = IsIntrinsicSpecies and HasOnlyLastIndex and UsesIntrinsicExec(Receiver, Pattern);
  if not IsPristine then
    Exit(False);

  Result := ((Pos(IGNORE_CASE_FLAG, Flags) > 0) = Pattern.IgnoreCase) and
            ((Pos(MULTILINE_FLAG, Flags) > 0) = Pattern.Multiline) and
            ((Pos(UNICODE_FLAG, Flags) > 0) = Pattern.Unicode);
end;

function TJSRegExpProtocol.SplitWithPattern(const Pattern: IJSRegExp; const Text: string; const Limit: Int64;
                                            const IsUnicode: Boolean): TJSValue;
begin
  const Pieces: IJSArray = TJSArray.Create;
  Result := TJSValue.CreateObject(Pieces);

  if Limit = 0 then
    Exit;

  const Size = Length(Text);
  if Size = 0 then
  begin
    if not Pattern.MatchAt(Text, 0).Found then
      Pieces.Push(TJSValue.CreateString(Text));

    Exit;
  end;

  var PieceStart := 0;
  var Cursor := 0;
  while Cursor < Size do
  begin
    const Found = Pattern.MatchAt(Text, Cursor);
    const IsInsideText = Found.Found and (Found.Index < Size);
    if not IsInsideText then
      Break;

    const MatchEnd = Min(Found.Index + Found.Length, Size);
    if MatchEnd = PieceStart then
    begin
      Cursor := Integer(AdvanceStringIndex(Text, Found.Index, IsUnicode));
      Continue;
    end;

    FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
    Pieces.Push(TJSValue.CreateString(Copy(Text, PieceStart + 1, Found.Index - PieceStart)));
    if Int64(Pieces.Length) = Limit then
      Exit;

    for var Capture in Found.Captures do
    begin
      FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
      Pieces.Push(Capture);
      if Int64(Pieces.Length) = Limit then
        Exit;
    end;

    PieceStart := MatchEnd;
    Cursor := PieceStart;
  end;

  FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
  Pieces.Push(TJSValue.CreateString(Copy(Text, PieceStart + 1, MaxInt)));
end;

function TJSRegExpProtocol.SplitWith(const Receiver: IJSObject; const Text: string;
                                     const LimitValue: TJSValue): TJSValue;
begin
  const Flags = ReadFlags(Receiver);
  const IsUnicode = (Pos(UNICODE_FLAG, Flags) > 0);
  const HasSticky = (Pos(STICKY_FLAG, Flags) > 0);
  var SplitterFlags := Flags;
  if not HasSticky then
    SplitterFlags := Flags + STICKY_FLAG;

  const Species = SpeciesConstructor(Receiver);

  var Pattern: IJSRegExp;
  if TryUseReceiverAsSplitter(Receiver, Species, Flags, Pattern) then
  begin
    var PlainLimit: Int64 := MAX_ARRAY_LENGTH;
    if not LimitValue.IsUndefined then
      PlainLimit := TJSConversions.ToUint32(LimitValue);

    Exit(SplitWithPattern(Pattern, Text, PlainLimit, IsUnicode));
  end;

  const Splitter = CreateSplitter(Species, Receiver, SplitterFlags);

  const Pieces: IJSArray = TJSArray.Create;
  Result := TJSValue.CreateObject(Pieces);

  var Limit: Int64 := MAX_ARRAY_LENGTH;
  if not LimitValue.IsUndefined then
    Limit := TJSConversions.ToUint32(LimitValue);

  if Limit = 0 then
    Exit;

  const Size = Length(Text);
  if Size = 0 then
  begin
    if RegExpExec(Splitter, Text).IsNull then
      Pieces.Push(TJSValue.CreateString(Text));

    Exit;
  end;

  var PieceStart: Int64 := 0;
  var Cursor: Int64 := 0;
  while Cursor < Size do
  begin
    WriteLastIndex(Splitter, Cursor);

    const Found = RegExpExec(Splitter, Text);
    if Found.IsNull then
    begin
      Cursor := AdvanceStringIndex(Text, Cursor, IsUnicode);
      Continue;
    end;

    const MatchEnd = Min(ReadLastIndex(Splitter), Size);
    if MatchEnd = PieceStart then
    begin
      Cursor := AdvanceStringIndex(Text, Cursor, IsUnicode);
      Continue;
    end;

    FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
    Pieces.Push(TJSValue.CreateString(Copy(Text, PieceStart + 1, Cursor - PieceStart)));
    if Int64(Pieces.Length) = Limit then
      Exit;

    PieceStart := MatchEnd;

    const FoundObject = Found.ToObject;
    const CaptureCount = Max(TJSConversions.ToLength(FoundObject.GetProperty(LENGTH_PROPERTY)) - 1, 0);
    for var Number := 1 to CaptureCount do
    begin
      FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
      Pieces.Push(FoundObject.GetProperty(IntToStr(Number)));
      if Int64(Pieces.Length) = Limit then
        Exit;
    end;

    Cursor := PieceStart;
  end;

  FInterpreter.Limits.EnsureArrayLength(Int64(Pieces.Length) + 1);
  Pieces.Push(TJSValue.CreateString(Copy(Text, PieceStart + 1, MaxInt)));
end;

function TJSRegExpProtocol.CreateMethod(const Name: string; const ParameterCount: Integer;
                                        const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSRegExpProtocol.DefineMethod(const Target: IJSObject; const Key: string; const Name: string;
                                         const ParameterCount: Integer; const Method: TNativeFunction);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(CreateMethod(Name, ParameterCount, Method)));
  Descriptor.Enumerable := False;
  Target.DefineProperty(Key, Descriptor);
end;

procedure TJSRegExpProtocol.Register;
begin
  const PrototypeObj = FInterpreter.RegExpPrototype;

  FIntrinsicExec := TJSConversions.AsFunction(PrototypeObj.GetProperty(EXEC_PROPERTY));
  FIntrinsicConstructor := TJSConversions.AsFunction(FInterpreter.GetGlobalVariable(REGEXP_NAME));

  DefineMethod(PrototypeObj, TEST_NAME, TEST_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, TEST_NAME);
      const Text = ToText(TJSArrayLike.Argument(Args, 0));

      var Pattern: IJSRegExp;
      if UsesIntrinsicExec(Receiver, Pattern) then
        Exit(TJSValue.CreateBoolean(Pattern.Test(Text)));

      Result := TJSValue.CreateBoolean(not RegExpExec(Receiver, Text).IsNull);
    end);

  DefineMethod(PrototypeObj, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Match), MATCH_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, MATCH_NAME);

      Result := Match(Receiver, ToText(TJSArrayLike.Argument(Args, 0)));
    end);

  DefineMethod(PrototypeObj, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Replace), REPLACE_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, REPLACE_NAME);
      const Text = ToText(TJSArrayLike.Argument(Args, 0));

      Result := ReplaceWith(Receiver, Text, TJSArrayLike.Argument(Args, 1));
    end);

  DefineMethod(PrototypeObj, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Search), SEARCH_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, SEARCH_NAME);

      Result := Search(Receiver, ToText(TJSArrayLike.Argument(Args, 0)));
    end);

  DefineMethod(PrototypeObj, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Split), SPLIT_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, SPLIT_NAME);
      const Text = ToText(TJSArrayLike.Argument(Args, 0));

      Result := SplitWith(Receiver, Text, TJSArrayLike.Argument(Args, 1));
    end);
end;

end.
