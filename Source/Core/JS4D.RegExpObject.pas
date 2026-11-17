unit JS4D.RegExpObject;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.PcreMatcher,
  JS4D.RegExpSyntax,
  JS4D.Types;

type
  TJSRegExpImpl = class(TJSObjectImpl, IJSRegExp)
  private
    FPattern: string;
    FFlags: string;
    FFlagSet: TJSRegExpFlags;
    FMatcher: TJSPcreMatcher;

    function CreateMatcher: TJSPcreMatcher;
    procedure DefineLastIndex;
    function ReadLastIndex: Int64;
    procedure WriteLastIndex(const Value: Integer);
    function MatchFrom(const Str: string; const Start: Integer; const IsAnchored: Boolean): TJSRegExpMatch;
    function FindMatch(const Str: string): TJSRegExpMatch;
    function CaptureValue(const Str: string; const GroupIndex: Integer): TJSValue;
    class function MatchedText(const Str: string; const MatchResult: TJSRegExpMatch): TJSValue; static;
    class function NextSearchPosition(const MatchResult: TJSRegExpMatch): Integer; static;
    function BuildExecResult(const MatchResult: TJSRegExpMatch; const Str: string): TJSValue;
    function MatchAllText(const Str: string): TJSValue;

  protected
    function GetPattern: string;
    function GetFlags: string;
    function GetGlobal: Boolean;
    function GetIgnoreCase: Boolean;
    function GetMultiline: Boolean;
    function GetUnicode: Boolean;
    function GetSticky: Boolean;
    function GetSource: string;
    function GetLastIndex: Integer;
    procedure SetLastIndex(const Value: Integer);

  public
    constructor Create(const Pattern: string; const Flags: string = '');
    destructor Destroy; override;

    function Test(const Str: string): Boolean;
    function Exec(const Str: string): TJSValue;
    function Match(const Str: string): TJSValue;
    function MatchAt(const Str: string; const Start: Integer): TJSRegExpMatch;
    function CountReplacements(const Str: string): Integer;
    function Search(const Str: string): Integer;

    property Pattern: string read GetPattern;
    property Source: string read GetSource;
    property Flags: string read GetFlags;
    property Global: Boolean read GetGlobal;
    property IgnoreCase: Boolean read GetIgnoreCase;
    property Multiline: Boolean read GetMultiline;
    property Unicode: Boolean read GetUnicode;
    property Sticky: Boolean read GetSticky;
    property LastIndex: Integer read GetLastIndex write SetLastIndex;
  end;

  TJSRegExp = TJSRegExpImpl;

implementation

uses
  System.SysUtils,
  System.Math,
  JS4D.ArrayObject,
  JS4D.Errors,
  JS4D.PropertyKey,
  JS4D.RegExpTranslator;

const
  EMPTY_PATTERN_GROUP = '(?:)';
  PROP_LAST_INDEX = 'lastIndex';
  MAX_SAFE_LAST_INDEX = 9007199254740991.0;
  LAST_INDEX_READ_ONLY = 'Cannot assign to read only property ''lastIndex''';
  PROP_INDEX = 'index';
  PROP_INPUT = 'input';

{ TJSRegExpImpl }

constructor TJSRegExpImpl.Create(const Pattern: string; const Flags: string);
begin
  inherited Create;

  const UnknownPosition = TJSSourcePosition.Unknown;
  TJSRegExpSyntax.ValidateFlags(Flags, UnknownPosition);
  TJSRegExpSyntax.ValidatePattern(Pattern, Flags, UnknownPosition);

  FPattern := Pattern;
  FFlags := Flags;
  FFlagSet := TJSRegExpFlags.Parse(Flags);
  FMatcher := CreateMatcher;

  DefineLastIndex;
end;

destructor TJSRegExpImpl.Destroy;
begin
  FMatcher.Free;
  inherited Destroy;
end;

function TJSRegExpImpl.CreateMatcher: TJSPcreMatcher;
begin
  var CompilablePattern := FPattern;
  if FPattern.IsEmpty then
    CompilablePattern := EMPTY_PATTERN_GROUP;

  const HasSurrogateEscape = TJSRegExpTranslator.HasSurrogateEscape(CompilablePattern);
  const NeedsCodeUnits = ((not FFlagSet.IsUnicode) and HasSurrogateEscape);
  const UtfMode = (FFlagSet.IsUnicode or (FFlagSet.IgnoresCase and (not NeedsCodeUnits)));
  const Translated = TJSRegExpTranslator.Translate(CompilablePattern, FFlagSet.IsUnicode, UtfMode);

  Result := TJSPcreMatcher.Create(Translated, FFlagSet.IgnoresCase, FFlagSet.IsMultiline, UtfMode);
end;

procedure TJSRegExpImpl.DefineLastIndex;
begin
  const InitialIndex = TJSValue.CreateNumber(0);

  var LastIndexDescriptor := TJSPropertyDescriptor.Create(InitialIndex);
  LastIndexDescriptor.Enumerable := False;
  LastIndexDescriptor.Configurable := False;
  DefineProperty(PROP_LAST_INDEX, LastIndexDescriptor);
end;

function TJSRegExpImpl.GetPattern: string;
begin
  Result := FPattern;
end;

function TJSRegExpImpl.GetFlags: string;
begin
  Result := FFlags;
end;

function TJSRegExpImpl.GetGlobal: Boolean;
begin
  Result := FFlagSet.IsGlobal;
end;

function TJSRegExpImpl.GetIgnoreCase: Boolean;
begin
  Result := FFlagSet.IgnoresCase;
end;

function TJSRegExpImpl.GetMultiline: Boolean;
begin
  Result := FFlagSet.IsMultiline;
end;

function TJSRegExpImpl.GetUnicode: Boolean;
begin
  Result := FFlagSet.IsUnicode;
end;

function TJSRegExpImpl.GetSticky: Boolean;
begin
  Result := FFlagSet.IsSticky;
end;

function TJSRegExpImpl.GetSource: string;
begin
  Result := TJSRegExpSyntax.EscapePattern(FPattern);
end;

function TJSRegExpImpl.GetLastIndex: Integer;
begin
  const LastIndex = ReadLastIndex;
  const NonNegative = Max(LastIndex, 0);

  Result := Integer(Min(NonNegative, MaxInt));
end;

procedure TJSRegExpImpl.SetLastIndex(const Value: Integer);
begin
  WriteLastIndex(Value);
end;

function TJSRegExpImpl.ReadLastIndex: Int64;
begin
  const LastIndexValue = GetProperty(PROP_LAST_INDEX);
  const Primitive = LastIndexValue.ToPrimitiveWithHint(TJSPrimitiveHint.Number);
  const Number = Primitive.ToNumber;
  if Number.IsNaN then
    Exit(0);

  const Clamped = EnsureRange(Number, 0, MAX_SAFE_LAST_INDEX);
  Result := Trunc(Clamped);
end;

procedure TJSRegExpImpl.WriteLastIndex(const Value: Integer);
begin
  const IsWritable = GetOwnPropertyDescriptor(PROP_LAST_INDEX).Writable;
  if not IsWritable then
    raise TJSErrorFactory.TypeError(LAST_INDEX_READ_ONLY);

  const IndexValue = TJSValue.CreateNumber(Value);
  SetProperty(PROP_LAST_INDEX, IndexValue);
end;

function TJSRegExpImpl.MatchAt(const Str: string; const Start: Integer): TJSRegExpMatch;
begin
  Result := MatchFrom(Str, Start, False);
end;

function TJSRegExpImpl.MatchFrom(const Str: string; const Start: Integer;
                                 const IsAnchored: Boolean): TJSRegExpMatch;
begin
  Result := Default(TJSRegExpMatch);

  var HasMatched: Boolean;
  if IsAnchored then
    HasMatched := FMatcher.TryMatchAtStart(Str, Start)
  else
    HasMatched := FMatcher.TryMatch(Str, Start);

  if not HasMatched then
    Exit;

  const MatchStart = FMatcher.GroupStart(0);

  Result.IsMatch := True;
  Result.Index := MatchStart;
  Result.Length := FMatcher.GroupEnd(0) - MatchStart;

  SetLength(Result.Captures, FMatcher.CaptureCount);
  for var CaptureIndex := 0 to FMatcher.CaptureCount - 1 do
  begin
    Result.Captures[CaptureIndex] := CaptureValue(Str, CaptureIndex + 1);
  end;
end;

function TJSRegExpImpl.CaptureValue(const Str: string; const GroupIndex: Integer): TJSValue;
begin
  if not FMatcher.HasParticipated(GroupIndex) then
    Exit(TJSValue.CreateUndefined);

  const CaptureStart = FMatcher.GroupStart(GroupIndex);
  const CaptureLength = FMatcher.GroupEnd(GroupIndex) - CaptureStart;
  const CaptureText = Copy(Str, CaptureStart + 1, CaptureLength);

  Result := TJSValue.CreateString(CaptureText);
end;

function TJSRegExpImpl.FindMatch(const Str: string): TJSRegExpMatch;
begin
  const UsesLastIndex = (FFlagSet.IsGlobal or FFlagSet.IsSticky);

  var Start := ReadLastIndex;
  if not UsesLastIndex then
    Start := 0;

  Result := Default(TJSRegExpMatch);

  const InRange = (Start <= Length(Str));
  if InRange then
    Result := MatchFrom(Str, Integer(Start), FFlagSet.IsSticky);

  if not Result.IsMatch then
  begin
    if UsesLastIndex then
      WriteLastIndex(0);

    Exit;
  end;

  if UsesLastIndex then
    WriteLastIndex(Result.Index + Result.Length);
end;

function TJSRegExpImpl.Test(const Str: string): Boolean;
begin
  const MatchResult = FindMatch(Str);

  Result := MatchResult.IsMatch;
end;

class function TJSRegExpImpl.MatchedText(const Str: string; const MatchResult: TJSRegExpMatch): TJSValue;
begin
  const Text = Copy(Str, MatchResult.Index + 1, MatchResult.Length);

  Result := TJSValue.CreateString(Text);
end;

class function TJSRegExpImpl.NextSearchPosition(const MatchResult: TJSRegExpMatch): Integer;
begin
  Result := MatchResult.Index + MatchResult.Length;

  const IsEmptyMatch = (MatchResult.Length = 0);
  if IsEmptyMatch then
    Inc(Result);
end;

function TJSRegExpImpl.BuildExecResult(const MatchResult: TJSRegExpMatch; const Str: string): TJSValue;
begin
  const ExecResult: IJSArray = TJSArrayImpl.Create;

  const WholeMatch = MatchedText(Str, MatchResult);
  ExecResult.Push(WholeMatch);

  for var Capture in MatchResult.Captures do
  begin
    ExecResult.Push(Capture);
  end;

  const IndexValue = TJSValue.CreateNumber(MatchResult.Index);
  const InputValue = TJSValue.CreateString(Str);
  ExecResult.SetProperty(PROP_INDEX, IndexValue);
  ExecResult.SetProperty(PROP_INPUT, InputValue);

  Result := TJSValue.CreateObject(ExecResult);
end;

function TJSRegExpImpl.Exec(const Str: string): TJSValue;
begin
  const MatchResult = FindMatch(Str);
  if not MatchResult.IsMatch then
    Exit(TJSValue.CreateNull);

  Result := BuildExecResult(MatchResult, Str);
end;

function TJSRegExpImpl.MatchAllText(const Str: string): TJSValue;
begin
  WriteLastIndex(0);

  const MatchedTexts: IJSArray = TJSArrayImpl.Create;
  var Position := 0;

  while Position <= Length(Str) do
  begin
    const MatchResult = MatchAt(Str, Position);
    if not MatchResult.IsMatch then
      Break;

    const Text = MatchedText(Str, MatchResult);
    MatchedTexts.Push(Text);

    Position := NextSearchPosition(MatchResult);
  end;

  if MatchedTexts.Length = 0 then
    Exit(TJSValue.CreateNull);

  Result := TJSValue.CreateObject(MatchedTexts);
end;

function TJSRegExpImpl.Match(const Str: string): TJSValue;
begin
  if FFlagSet.IsGlobal then
    Result := MatchAllText(Str)
  else
    Result := Exec(Str);
end;

function TJSRegExpImpl.CountReplacements(const Str: string): Integer;
begin
  Result := 0;

  var Position := 0;
  while Position <= Length(Str) do
  begin
    const MatchResult = MatchAt(Str, Position);
    if not MatchResult.IsMatch then
      Break;

    Inc(Result);
    if not FFlagSet.IsGlobal then
      Break;

    Position := NextSearchPosition(MatchResult);
  end;
end;

function TJSRegExpImpl.Search(const Str: string): Integer;
begin
  const MatchResult = MatchAt(Str, 0);

  if MatchResult.IsMatch then
    Result := MatchResult.Index
  else
    Result := -1;
end;

end.
