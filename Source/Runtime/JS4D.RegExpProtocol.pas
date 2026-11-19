unit JS4D.RegExpProtocol;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.Math,
  JS4D.BuiltinSet,
  JS4D.BuiltinSupport,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSRegExpProtocol = class(TJSBuiltinSet)
  private
    const
      EXEC_PROPERTY = 'exec';
      LAST_INDEX_PROPERTY = 'lastIndex';
      INDEX_PROPERTY = 'index';
      GROUPS_PROPERTY = 'groups';
      REGEXP_NAME = 'RegExp';
      TEST_NAME = 'test';
      MATCH_NAME = '[Symbol.match]';
      REPLACE_NAME = '[Symbol.replace]';
      SEARCH_NAME = '[Symbol.search]';
      SPLIT_NAME = '[Symbol.split]';
      ONE_PARAMETER = 1;
      TWO_PARAMETERS = 2;
      INITIAL_MATCH_CAPACITY = 16;
      FIXED_CALLBACK_ARGUMENTS = 3;
      FIRST_CAPTURE_NAME = '0';
      THIS_NOT_AN_OBJECT = 'RegExp.prototype.%s called on a value that is not an object';
      EXEC_RESULT_INVALID = 'The result of the exec method must be an object or null';
      NOT_A_REGEXP = 'RegExp.prototype.exec called on a value that is not a regular expression';

    type
      TMatchRecord = record
        Result: IJSObject;
        Matched: string;
        Position: Integer;
        Captures: TArray<TJSValue>;
      end;

      TSplitPieces = record
        Items: IJSArray;
        Limit: Int64;
        Limits: TJSLimits;

        function Add(const Value: TJSValue): Boolean;
        function AddText(const Text: string): Boolean;
      end;

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;
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
    function TryGetPlainPattern(const Receiver: IJSObject; const IsUnicode: Boolean; out Pattern: IJSRegExp): Boolean;
    function CollectPatternMatches(const Pattern: IJSRegExp; const Text: string;
                                   const IsUnicode: Boolean): TArray<TMatchRecord>;
    function TryCollectPlainMatches(const Receiver: IJSObject; const Text: string; const IsUnicode: Boolean;
                                    out Matches: TArray<TMatchRecord>): Boolean;
    function CollectMatches(const Receiver: IJSObject; const Text: string; const IsGlobal: Boolean;
                            const IsUnicode: Boolean): TArray<TMatchRecord>;
    function CollectReplaceMatches(const Receiver: IJSObject; const Text: string; const IsGlobal: Boolean;
                                   const IsUnicode: Boolean): TArray<TMatchRecord>;
    function ReadMatchDetails(const Found: TMatchRecord; const Text: string): TMatchRecord;
    function CollectCaptures(const Found: IJSObject): TArray<TJSValue>;
    function CallbackArguments(const Found: TMatchRecord; const Text: string; const Captures: TArray<TJSValue>;
                               const NamedCaptures: TJSValue): TArray<TJSValue>;
    function ReplacementOf(const Found: TMatchRecord; const Text: string; const ReplaceTemplate: string;
                           const ReplaceFunction: IJSFunction): string;
    function BuildReplaced(const Matches: TArray<TMatchRecord>; const Text: string; const ReplaceTemplate: string;
                           const ReplaceFunction: IJSFunction): string;
    function ReplaceWith(const Receiver: IJSObject; const Text: string; const ReplaceValue: TJSValue): TJSValue;
    function SpeciesConstructor(const Receiver: IJSObject): IJSFunction;
    function CreateSplitter(const Species: IJSFunction; const Receiver: IJSObject;
                            const NewFlags: string): IJSObject;
    function TryUseReceiverAsSplitter(const Receiver: IJSObject; const Species: IJSFunction; const Flags: string;
                                      out Pattern: IJSRegExp): Boolean;
    function NewSplitPieces(const Limit: Int64): TSplitPieces;
    function ReadSplitLimit(const LimitValue: TJSValue): Int64;
    class procedure PushWholeText(const Pieces: TSplitPieces; const Text: string); static;
    function AddResultCaptures(const Pieces: TSplitPieces; const Found: TJSValue): Boolean;
    procedure SplitPatternPieces(const Pattern: IJSRegExp; const Text: string; const Pieces: TSplitPieces;
                                 const IsUnicode: Boolean);
    procedure SplitSplitterPieces(const Splitter: IJSObject; const Text: string; const Pieces: TSplitPieces;
                                  const IsUnicode: Boolean);
    function SplitWithPattern(const Pattern: IJSRegExp; const Text: string; const Limit: Int64;
                              const IsUnicode: Boolean): TJSValue;
    function SplitWithSplitter(const Splitter: IJSObject; const Text: string; const Limit: Int64;
                               const IsUnicode: Boolean): TJSValue;
    function SplitWith(const Receiver: IJSObject; const Text: string; const LimitValue: TJSValue): TJSValue;
    function PlainMatchResult(const Plain: TArray<TMatchRecord>): TJSValue;
    function GenericMatchResult(const Receiver: IJSObject; const Text: string; const IsUnicode: Boolean): TJSValue;
    function Match(const Receiver: IJSObject; const Text: string): TJSValue;
    function Search(const Receiver: IJSObject; const Text: string): TJSValue;
    procedure DefineMethod(const Target: IJSObject; const Key: TJSPropertyKey; const Name: string;
                           const ParameterCount: Integer; const Method: TNativeFunction);
    procedure RegisterTest(const PrototypeObj: IJSObject);
    procedure RegisterMatch(const PrototypeObj: IJSObject);
    procedure RegisterReplace(const PrototypeObj: IJSObject);
    procedure RegisterSearch(const PrototypeObj: IJSObject);
    procedure RegisterSplit(const PrototypeObj: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
  end;

implementation

uses
  JS4D.PropertyNames,
  JS4D.Utf16,
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.ArrayLike,
  JS4D.ObjectOperations,
  JS4D.RegExpSyntax,
  JS4D.PatternOperations;

function TJSRegExpProtocol.TSplitPieces.Add(const Value: TJSValue): Boolean;
begin
  const NextLength = Int64(Items.Length) + 1;
  Limits.EnsureArrayLength(NextLength);
  Items.Push(Value);

  Result := (Int64(Items.Length) = Limit);
end;

constructor TJSRegExpProtocol.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSRegExpProtocol.Destroy;
begin
  FSupport.Free;
  FIntrinsicExec := nil;
  FIntrinsicConstructor := nil;

  inherited Destroy;
end;

class function TJSRegExpProtocol.AdvanceStringIndex(const Text: string; const Index: Int64;
                                                    const IsUnicode: Boolean): Int64;
begin
  Result := Index + 1;

  const SkipsPair = (IsUnicode and TJSUtf16.IsPairAt(Text, Index + 1));
  if SkipsPair then
    Result := Index + 2;
end;

function TJSRegExpProtocol.ToText(const Value: TJSValue): string;
begin
  Result := TJSConversions.ToText(Value, FInterpreter.Limits);
end;

function TJSRegExpProtocol.ToObjectValue(const Value: TJSValue): IJSObject;
begin
  if Value.IsObject then
  begin
    Result := Value.ToObject;
    Exit;
  end;

  if Value.IsNullOrUndefined then
    raise TJSErrorFactory.NotCoercibleToObject;

  Result := FInterpreter.WrapPrimitive(Value);
end;

function TJSRegExpProtocol.RequireReceiver(const This: IJSObject; const MethodName: string): IJSObject;
begin
  const IsObject = Assigned(This) and (not Supports(This, IJSPrimitiveWrapper));
  if not IsObject then
  begin
    const Message = Format(THIS_NOT_AN_OBJECT, [MethodName]);

    raise TJSErrorFactory.TypeError(Message);
  end;

  Result := This;
end;

function TJSRegExpProtocol.ReadFlags(const Receiver: IJSObject): string;
begin
  const FlagsValue = Receiver.GetProperty(FLAGS_PROPERTY);

  Result := ToText(FlagsValue);
end;

function TJSRegExpProtocol.ReadLastIndex(const Receiver: IJSObject): Int64;
begin
  const LastIndexValue = Receiver.GetProperty(LAST_INDEX_PROPERTY);

  Result := TJSConversions.ToLength(LastIndexValue);
end;

procedure TJSRegExpProtocol.WriteLastIndex(const Receiver: IJSObject; const Index: Int64);
begin
  const IndexValue = TJSValue.CreateNumber(Index);

  TJSConversions.PutProperty(Receiver, LAST_INDEX_PROPERTY, IndexValue);
end;

procedure TJSRegExpProtocol.AdvanceLastIndex(const Receiver: IJSObject; const Text: string;
                                             const IsUnicode: Boolean);
begin
  const ThisIndex = ReadLastIndex(Receiver);
  const NextIndex = AdvanceStringIndex(Text, ThisIndex, IsUnicode);

  WriteLastIndex(Receiver, NextIndex);
end;

function TJSRegExpProtocol.RegExpExec(const Receiver: IJSObject; const Text: string): TJSValue;
begin
  const ExecValue = Receiver.GetProperty(EXEC_PROPERTY);
  const Method = TJSConversions.AsFunction(ExecValue);
  if Assigned(Method) then
  begin
    const TextArgument: TArray<TJSValue> = [TJSValue.CreateString(Text)];
    const Returned = Method.Call(Receiver, TextArgument);
    const IsValidResult = Returned.IsNull or Returned.IsObject;
    if not IsValidResult then
      raise TJSErrorFactory.TypeError(EXEC_RESULT_INVALID);

    Result := Returned;
    Exit;
  end;

  var BuiltIn: IJSRegExp;
  if not Supports(Receiver, IJSRegExp, BuiltIn) then
    raise TJSErrorFactory.TypeError(NOT_A_REGEXP);

  Result := BuiltIn.Exec(Text);
end;

function TJSRegExpProtocol.PlainMatchResult(const Plain: TArray<TMatchRecord>): TJSValue;
begin
  const HasMatches = (Length(Plain) > 0);
  if not HasMatches then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  const PlainMatches: IJSArray = TJSArray.Create;
  for var Entry in Plain do
  begin
    const MatchedValue = TJSValue.CreateString(Entry.Matched);

    PlainMatches.Push(MatchedValue);
  end;

  Result := TJSValue.CreateObject(PlainMatches);
end;

function TJSRegExpProtocol.GenericMatchResult(const Receiver: IJSObject; const Text: string;
                                              const IsUnicode: Boolean): TJSValue;
begin
  WriteLastIndex(Receiver, 0);

  const Matches: IJSArray = TJSArray.Create;
  while True do
  begin
    const Found = RegExpExec(Receiver, Text);
    if Found.IsNull then
      Break;

    const FoundObject = Found.ToObject;
    const FirstCapture = FoundObject.GetProperty(FIRST_CAPTURE_NAME);
    const MatchedText = ToText(FirstCapture);
    const NextLength = Int64(Matches.Length) + 1;
    FInterpreter.Limits.EnsureArrayLength(NextLength);

    const MatchedValue = TJSValue.CreateString(MatchedText);
    Matches.Push(MatchedValue);

    if MatchedText.IsEmpty then
      AdvanceLastIndex(Receiver, Text, IsUnicode);
  end;

  const HasMatches = (Matches.Length > 0);
  if not HasMatches then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  Result := TJSValue.CreateObject(Matches);
end;

function TJSRegExpProtocol.Match(const Receiver: IJSObject; const Text: string): TJSValue;
begin
  const Flags = ReadFlags(Receiver);
  const IsGlobal = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.GLOBAL);
  if not IsGlobal then
  begin
    Result := RegExpExec(Receiver, Text);
    Exit;
  end;

  const IsUnicode = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.UNICODE);

  var Plain: TArray<TMatchRecord>;
  const IsPlain = TryCollectPlainMatches(Receiver, Text, IsUnicode, Plain);
  if IsPlain then
    Result := PlainMatchResult(Plain)
  else
    Result := GenericMatchResult(Receiver, Text, IsUnicode);
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
  begin
    Result := TJSValue.CreateNumber(-1);
    Exit;
  end;

  const FoundObject = Found.ToObject;

  Result := FoundObject.GetProperty(INDEX_PROPERTY);
end;

function TJSRegExpProtocol.UsesIntrinsicExec(const Receiver: IJSObject; out Pattern: IJSRegExp): Boolean;
begin
  Result := False;

  if not Supports(Receiver, IJSRegExp, Pattern) then
    Exit;

  var Descriptor: TJSPropertyDescriptor;
  if not Receiver.TryGetPropertyDescriptor(EXEC_PROPERTY, Descriptor) then
    Exit;

  const IsDataFunction = (not Descriptor.IsAccessor) and Descriptor.Value.IsFunction;

  Result := IsDataFunction and TJSObjectOperations.IsSameObject(Descriptor.Value.AsObject, FIntrinsicExec);
end;

function TJSRegExpProtocol.TryGetPlainPattern(const Receiver: IJSObject; const IsUnicode: Boolean;
                                              out Pattern: IJSRegExp): Boolean;
begin
  Result := False;

  if not UsesIntrinsicExec(Receiver, Pattern) then
    Exit;

  Result := Pattern.Global and (not Pattern.Sticky) and (Pattern.Unicode = IsUnicode);
end;

function TJSRegExpProtocol.CollectPatternMatches(const Pattern: IJSRegExp; const Text: string;
                                                 const IsUnicode: Boolean): TArray<TMatchRecord>;
begin
  Result := nil;

  const TextLength = Length(Text);
  var Count := 0;
  var Position := 0;
  while Position <= TextLength do
  begin
    const Found = Pattern.MatchAt(Text, Position);
    if not Found.IsMatch then
      Break;

    const NextCount = Int64(Count) + 1;
    FInterpreter.Limits.EnsureArrayLength(NextCount);

    const IsFull = (Count = Length(Result));
    if IsFull then
      SetLength(Result, Max(Count * 2, INITIAL_MATCH_CAPACITY));

    Result[Count].Matched := Copy(Text, Found.Index + 1, Found.Length);
    Result[Count].Position := Found.Index;
    Result[Count].Captures := Found.Captures;
    Inc(Count);

    Position := Found.Index + Found.Length;

    const IsEmptyMatch = (Found.Length = 0);
    if IsEmptyMatch then
      Position := Integer(AdvanceStringIndex(Text, Position, IsUnicode));
  end;

  SetLength(Result, Count);
end;

function TJSRegExpProtocol.TryCollectPlainMatches(const Receiver: IJSObject; const Text: string;
                                                  const IsUnicode: Boolean;
                                                  out Matches: TArray<TMatchRecord>): Boolean;
begin
  Matches := nil;

  var Pattern: IJSRegExp;
  Result := TryGetPlainPattern(Receiver, IsUnicode, Pattern);
  if not Result then
    Exit;

  WriteLastIndex(Receiver, 0);

  Matches := CollectPatternMatches(Pattern, Text, IsUnicode);
end;

function TJSRegExpProtocol.ReadMatchDetails(const Found: TMatchRecord; const Text: string): TMatchRecord;
begin
  Result := Found;
  if not Assigned(Found.Result) then
    Exit;

  const MatchedValue = Found.Result.GetProperty(FIRST_CAPTURE_NAME);
  Result.Matched := ToText(MatchedValue);

  const IndexValue = Found.Result.GetProperty(INDEX_PROPERTY);
  const RawPosition = TJSConversions.ToIntegerOrInfinity(IndexValue);
  const ClampedPosition = EnsureRange(RawPosition, 0, Length(Text));
  Result.Position := Trunc(ClampedPosition);
end;

function TJSRegExpProtocol.CollectMatches(const Receiver: IJSObject; const Text: string; const IsGlobal: Boolean;
                                          const IsUnicode: Boolean): TArray<TMatchRecord>;
begin
  if IsGlobal then
    WriteLastIndex(Receiver, 0);

  const Collected = TList<TMatchRecord>.Create;
  try
    while True do
    begin
      const Found = RegExpExec(Receiver, Text);
      if Found.IsNull then
        Break;

      const NextCount = Int64(Collected.Count) + 1;
      FInterpreter.Limits.EnsureArrayLength(NextCount);

      var Entry := Default(TMatchRecord);
      Entry.Result := Found.ToObject;
      Collected.Add(Entry);

      if not IsGlobal then
        Break;

      const MatchedValue = Entry.Result.GetProperty(FIRST_CAPTURE_NAME);
      const MatchedText = ToText(MatchedValue);
      if MatchedText.IsEmpty then
        AdvanceLastIndex(Receiver, Text, IsUnicode);
    end;

    Result := Collected.ToArray;
  finally
    Collected.Free;
  end;
end;

function TJSRegExpProtocol.CollectReplaceMatches(const Receiver: IJSObject; const Text: string;
                                                 const IsGlobal: Boolean;
                                                 const IsUnicode: Boolean): TArray<TMatchRecord>;
begin
  var IsPlain := False;
  if IsGlobal then
    IsPlain := TryCollectPlainMatches(Receiver, Text, IsUnicode, Result);

  if not IsPlain then
    Result := CollectMatches(Receiver, Text, IsGlobal, IsUnicode);
end;

function TJSRegExpProtocol.CollectCaptures(const Found: IJSObject): TArray<TJSValue>;
begin
  const LengthValue = Found.GetProperty(LENGTH_PROPERTY);
  const ResultLength = TJSConversions.ToLength(LengthValue);
  const CaptureCount = Max(ResultLength - 1, 0);
  FInterpreter.Limits.EnsureArrayLength(CaptureCount);

  SetLength(Result, CaptureCount);
  for var Number := 1 to CaptureCount do
  begin
    const CaptureName = TJSArrayLike.IndexName(Number);
    var Capture := Found.GetProperty(CaptureName);
    if not Capture.IsUndefined then
    begin
      const CaptureText = ToText(Capture);

      Capture := TJSValue.CreateString(CaptureText);
    end;

    Result[Number - 1] := Capture;
  end;
end;

function TJSRegExpProtocol.CallbackArguments(const Found: TMatchRecord; const Text: string;
                                             const Captures: TArray<TJSValue>;
                                             const NamedCaptures: TJSValue): TArray<TJSValue>;
begin
  const HasNamedCaptures = (not NamedCaptures.IsUndefined);
  const CaptureCount = Length(Captures);
  const PositionIndex = CaptureCount + 1;

  var ArgumentCount := CaptureCount + FIXED_CALLBACK_ARGUMENTS;
  if HasNamedCaptures then
    Inc(ArgumentCount);

  SetLength(Result, ArgumentCount);
  Result[0] := TJSValue.CreateString(Found.Matched);

  for var Index := 0 to CaptureCount - 1 do
  begin
    Result[Index + 1] := Captures[Index];
  end;

  Result[PositionIndex] := TJSValue.CreateNumber(Found.Position);
  Result[PositionIndex + 1] := TJSValue.CreateString(Text);
  if HasNamedCaptures then
    Result[PositionIndex + 2] := NamedCaptures;
end;

function TJSRegExpProtocol.ReplacementOf(const Found: TMatchRecord; const Text: string;
                                         const ReplaceTemplate: string; const ReplaceFunction: IJSFunction): string;
begin
  var Captures := Found.Captures;
  var NamedCaptures := TJSValue.CreateUndefined;
  if Assigned(Found.Result) then
  begin
    Captures := CollectCaptures(Found.Result);
    NamedCaptures := Found.Result.GetProperty(GROUPS_PROPERTY);
  end;

  if Assigned(ReplaceFunction) then
  begin
    const CallArgs = CallbackArguments(Found, Text, Captures, NamedCaptures);
    const Returned = FInterpreter.CallWithUndefinedThis(ReplaceFunction, CallArgs);

    Result := ToText(Returned);
    Exit;
  end;

  var NamedObject: IJSObject := nil;
  if not NamedCaptures.IsUndefined then
    NamedObject := ToObjectValue(NamedCaptures);

  Result := TJSPatternOperations.GetSubstitution(ReplaceTemplate, Text, Found.Position, Found.Matched,
                                                 Captures, NamedObject, FInterpreter.Limits);
end;

function TJSRegExpProtocol.BuildReplaced(const Matches: TArray<TMatchRecord>; const Text: string;
                                         const ReplaceTemplate: string; const ReplaceFunction: IJSFunction): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var NextSourcePosition := 0;
    for var Candidate in Matches do
    begin
      const Found = ReadMatchDetails(Candidate, Text);
      const Replaced = ReplacementOf(Found, Text, ReplaceTemplate, ReplaceFunction);

      const IsInOrder = (Found.Position >= NextSourcePosition);
      if IsInOrder then
      begin
        const Skipped = Copy(Text, NextSourcePosition + 1, Found.Position - NextSourcePosition);

        Builder.Append(Skipped);
        Builder.Append(Replaced);
        FInterpreter.Limits.EnsureStringLength(Builder.Length);

        NextSourcePosition := Found.Position + Length(Found.Matched);
      end;
    end;

    const Remainder = Copy(Text, NextSourcePosition + 1, MaxInt);

    Builder.Append(Remainder);
    FInterpreter.Limits.EnsureStringLength(Builder.Length);

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

function TJSRegExpProtocol.ReplaceWith(const Receiver: IJSObject; const Text: string;
                                       const ReplaceValue: TJSValue): TJSValue;
begin
  var ReplaceTemplate := '';
  var ReplaceFunction: IJSFunction := nil;
  if ReplaceValue.IsFunction then
    ReplaceFunction := TJSConversions.AsFunction(ReplaceValue)
  else
    ReplaceTemplate := ToText(ReplaceValue);

  const Flags = ReadFlags(Receiver);
  const IsGlobal = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.GLOBAL);
  const IsUnicode = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.UNICODE);

  const Matches = CollectReplaceMatches(Receiver, Text, IsGlobal, IsUnicode);
  const Replaced = BuildReplaced(Matches, Text, ReplaceTemplate, ReplaceFunction);

  Result := TJSValue.CreateString(Replaced);
end;

function TJSRegExpProtocol.SpeciesConstructor(const Receiver: IJSObject): IJSFunction;
begin
  const ConstructorValue = FInterpreter.GetGlobalVariable(REGEXP_NAME);
  const DefaultConstructor = TJSConversions.AsFunction(ConstructorValue);

  Result := TJSConversions.SpeciesConstructor(Receiver, DefaultConstructor);
end;

function TJSRegExpProtocol.CreateSplitter(const Species: IJSFunction; const Receiver: IJSObject;
                                          const NewFlags: string): IJSObject;
begin
  const ReceiverValue = TJSValue.CreateObject(Receiver);
  const FlagsValue = TJSValue.CreateString(NewFlags);
  const ConstructorArgs: TArray<TJSValue> = [ReceiverValue, FlagsValue];
  const Created = FInterpreter.Construct(Species, ConstructorArgs);

  Result := Created.ToObject;
end;

function TJSRegExpProtocol.TryUseReceiverAsSplitter(const Receiver: IJSObject; const Species: IJSFunction;
                                                    const Flags: string; out Pattern: IJSRegExp): Boolean;
begin
  Result := False;

  const IsIntrinsicSpecies = Assigned(Species) and
                             TJSObjectOperations.IsSameObject(Species, FIntrinsicConstructor);
  const OwnNameCount = Length(Receiver.GetOwnPropertyNames);
  const OwnSymbolCount = Length(Receiver.GetOwnSymbolKeysInCreationOrder);
  const HasOnlyLastIndex = ((OwnNameCount = 1) and (OwnSymbolCount = 0));
  const IsPristineReceiver = IsIntrinsicSpecies and HasOnlyLastIndex;
  if not IsPristineReceiver then
    Exit;

  if not UsesIntrinsicExec(Receiver, Pattern) then
    Exit;

  const HasIgnoreCase = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.IGNORE_CASE);
  const HasMultiline = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.MULTILINE);
  const HasUnicode = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.UNICODE);

  Result := ((HasIgnoreCase = Pattern.IgnoreCase) and
             (HasMultiline = Pattern.Multiline) and
             (HasUnicode = Pattern.Unicode));
end;

function TJSRegExpProtocol.NewSplitPieces(const Limit: Int64): TSplitPieces;
begin
  Result.Items := TJSArray.Create;
  Result.Limit := Limit;
  Result.Limits := FInterpreter.Limits;
end;

function TJSRegExpProtocol.ReadSplitLimit(const LimitValue: TJSValue): Int64;
begin
  Result := MAX_ARRAY_LENGTH;
  if not LimitValue.IsUndefined then
    Result := TJSConversions.ToUint32(LimitValue);
end;

function TJSRegExpProtocol.TSplitPieces.AddText(const Text: string): Boolean;
begin
  const TextValue = TJSValue.CreateString(Text);

  Result := Add(TextValue);
end;

class procedure TJSRegExpProtocol.PushWholeText(const Pieces: TSplitPieces; const Text: string);
begin
  const WholeText = TJSValue.CreateString(Text);

  Pieces.Items.Push(WholeText);
end;

procedure TJSRegExpProtocol.SplitPatternPieces(const Pattern: IJSRegExp; const Text: string;
                                               const Pieces: TSplitPieces; const IsUnicode: Boolean);
begin
  const Size = Length(Text);

  var PieceStart := 0;
  var Cursor := 0;
  while Cursor < Size do
  begin
    const Found = Pattern.MatchAt(Text, Cursor);
    const IsInsideText = Found.IsMatch and (Found.Index < Size);
    if not IsInsideText then
      Break;

    const MatchEnd = Min(Found.Index + Found.Length, Size);
    const IsEmptyPiece = (MatchEnd = PieceStart);
    if IsEmptyPiece then
    begin
      Cursor := Integer(AdvanceStringIndex(Text, Found.Index, IsUnicode));
      Continue;
    end;

    const PieceText = Copy(Text, PieceStart + 1, Found.Index - PieceStart);
    if Pieces.AddText(PieceText) then
      Exit;

    for var Capture in Found.Captures do
    begin
      if Pieces.Add(Capture) then
        Exit;
    end;

    PieceStart := MatchEnd;
    Cursor := PieceStart;
  end;

  const TailText = Copy(Text, PieceStart + 1, MaxInt);

  Pieces.AddText(TailText);
end;

function TJSRegExpProtocol.SplitWithPattern(const Pattern: IJSRegExp; const Text: string; const Limit: Int64;
                                            const IsUnicode: Boolean): TJSValue;
begin
  const Pieces = NewSplitPieces(Limit);
  Result := TJSValue.CreateObject(Pieces.Items);

  const IsLimitZero = (Limit = 0);
  if IsLimitZero then
    Exit;

  if Text.IsEmpty then
  begin
    const EmptyMatch = Pattern.MatchAt(Text, 0);
    if not EmptyMatch.IsMatch then
      PushWholeText(Pieces, Text);

    Exit;
  end;

  SplitPatternPieces(Pattern, Text, Pieces, IsUnicode);
end;

function TJSRegExpProtocol.AddResultCaptures(const Pieces: TSplitPieces; const Found: TJSValue): Boolean;
begin
  Result := True;

  const FoundObject = Found.ToObject;
  const LengthValue = FoundObject.GetProperty(LENGTH_PROPERTY);
  const ResultLength = TJSConversions.ToLength(LengthValue);
  const CaptureCount = Max(ResultLength - 1, 0);
  for var Number := 1 to CaptureCount do
  begin
    const CaptureName = IntToStr(Number);
    const Capture = FoundObject.GetProperty(CaptureName);
    if Pieces.Add(Capture) then
      Exit;
  end;

  Result := False;
end;

procedure TJSRegExpProtocol.SplitSplitterPieces(const Splitter: IJSObject; const Text: string;
                                                const Pieces: TSplitPieces; const IsUnicode: Boolean);
begin
  const Size = Length(Text);

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

    const SplitterIndex = ReadLastIndex(Splitter);
    const MatchEnd = Min(SplitterIndex, Size);
    const IsEmptyPiece = (MatchEnd = PieceStart);
    if IsEmptyPiece then
    begin
      Cursor := AdvanceStringIndex(Text, Cursor, IsUnicode);
      Continue;
    end;

    const PieceText = Copy(Text, PieceStart + 1, Cursor - PieceStart);
    if Pieces.AddText(PieceText) then
      Exit;

    PieceStart := MatchEnd;

    if AddResultCaptures(Pieces, Found) then
      Exit;

    Cursor := PieceStart;
  end;

  const TailText = Copy(Text, PieceStart + 1, MaxInt);

  Pieces.AddText(TailText);
end;

function TJSRegExpProtocol.SplitWithSplitter(const Splitter: IJSObject; const Text: string; const Limit: Int64;
                                             const IsUnicode: Boolean): TJSValue;
begin
  const Pieces = NewSplitPieces(Limit);
  Result := TJSValue.CreateObject(Pieces.Items);

  const IsLimitZero = (Limit = 0);
  if IsLimitZero then
    Exit;

  if Text.IsEmpty then
  begin
    const EmptyMatch = RegExpExec(Splitter, Text);
    if EmptyMatch.IsNull then
      PushWholeText(Pieces, Text);

    Exit;
  end;

  SplitSplitterPieces(Splitter, Text, Pieces, IsUnicode);
end;

function TJSRegExpProtocol.SplitWith(const Receiver: IJSObject; const Text: string;
                                     const LimitValue: TJSValue): TJSValue;
begin
  const Flags = ReadFlags(Receiver);
  const IsUnicode = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.UNICODE);
  const HasSticky = TJSRegExpFlags.Includes(Flags, TJSRegExpFlags.STICKY);
  var SplitterFlags := Flags;
  if not HasSticky then
    SplitterFlags := Flags + TJSRegExpFlags.STICKY;

  const Species = SpeciesConstructor(Receiver);

  var Pattern: IJSRegExp;
  if TryUseReceiverAsSplitter(Receiver, Species, Flags, Pattern) then
  begin
    const PatternLimit = ReadSplitLimit(LimitValue);

    Result := SplitWithPattern(Pattern, Text, PatternLimit, IsUnicode);
    Exit;
  end;

  const Splitter = CreateSplitter(Species, Receiver, SplitterFlags);
  const SplitterLimit = ReadSplitLimit(LimitValue);

  Result := SplitWithSplitter(Splitter, Text, SplitterLimit, IsUnicode);
end;

procedure TJSRegExpProtocol.DefineMethod(const Target: IJSObject; const Key: TJSPropertyKey; const Name: string;
                                         const ParameterCount: Integer; const Method: TNativeFunction);
begin
  const MethodFunction = FSupport.CreateMethod(Name, ParameterCount, Method);
  const MethodValue = TJSValue.CreateObject(MethodFunction);

  FSupport.DefineMember(Target, Key, MethodValue, True);
end;

procedure TJSRegExpProtocol.RegisterTest(const PrototypeObj: IJSObject);
begin
  DefineMethod(PrototypeObj, TEST_NAME, TEST_NAME, ONE_PARAMETER,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, TEST_NAME);
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = ToText(Argument);

      var Pattern: IJSRegExp;
      if UsesIntrinsicExec(Receiver, Pattern) then
      begin
        const IsMatch = Pattern.Test(Text);

        Result := TJSValue.CreateBoolean(IsMatch);
        Exit;
      end;

      const Found = RegExpExec(Receiver, Text);

      Result := TJSValue.CreateBoolean(not Found.IsNull);
    end);
end;

procedure TJSRegExpProtocol.RegisterMatch(const PrototypeObj: IJSObject);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Match);

  DefineMethod(PrototypeObj, Key, MATCH_NAME, ONE_PARAMETER,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, MATCH_NAME);
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = ToText(Argument);

      Result := Match(Receiver, Text);
    end);
end;

procedure TJSRegExpProtocol.RegisterReplace(const PrototypeObj: IJSObject);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Replace);

  DefineMethod(PrototypeObj, Key, REPLACE_NAME, TWO_PARAMETERS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, REPLACE_NAME);
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = ToText(Argument);
      const ReplaceValue = TJSArrayLike.Argument(Args, 1);

      Result := ReplaceWith(Receiver, Text, ReplaceValue);
    end);
end;

procedure TJSRegExpProtocol.RegisterSearch(const PrototypeObj: IJSObject);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Search);

  DefineMethod(PrototypeObj, Key, SEARCH_NAME, ONE_PARAMETER,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, SEARCH_NAME);
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = ToText(Argument);

      Result := Search(Receiver, Text);
    end);
end;

procedure TJSRegExpProtocol.RegisterSplit(const PrototypeObj: IJSObject);
begin
  const Key = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Split);

  DefineMethod(PrototypeObj, Key, SPLIT_NAME, TWO_PARAMETERS,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const Receiver = RequireReceiver(This, SPLIT_NAME);
      const Argument = TJSArrayLike.Argument(Args, 0);
      const Text = ToText(Argument);
      const LimitValue = TJSArrayLike.Argument(Args, 1);

      Result := SplitWith(Receiver, Text, LimitValue);
    end);
end;

procedure TJSRegExpProtocol.Register;
begin
  const PrototypeObj = FInterpreter.RegExpPrototype;

  const ExecValue = PrototypeObj.GetProperty(EXEC_PROPERTY);
  FIntrinsicExec := TJSConversions.AsFunction(ExecValue);

  const ConstructorValue = FInterpreter.GetGlobalVariable(REGEXP_NAME);
  FIntrinsicConstructor := TJSConversions.AsFunction(ConstructorValue);

  RegisterTest(PrototypeObj);
  RegisterMatch(PrototypeObj);
  RegisterReplace(PrototypeObj);
  RegisterSearch(PrototypeObj);
  RegisterSplit(PrototypeObj);
end;

end.
