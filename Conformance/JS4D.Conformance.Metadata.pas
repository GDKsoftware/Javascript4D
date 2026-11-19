unit JS4D.Conformance.Metadata;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Conformance.Defines;

type
  TTestMetadata = class
  private
    FLists: TObjectDictionary<string, TList<string>>;
    FCurrentKey: string;
    FNegativePhase: TErrorPhase;
    FNegativeType: string;

    function ExtractFrontmatter(const Source: string): string;
    function GetIncludes: TArray<string>;
    function GetFeatures: TArray<string>;
    function GetIsNegative: Boolean;
    function ParsePhase(const Value: string): TErrorPhase;

    procedure ParseLine(const Line: string);
    procedure StartKey(const Line: string);
    procedure ContinueKey(const Line: string);
    procedure ContinueNegative(const Line: string);
    procedure AddValues(const Key: string; const Value: string);

  public
    constructor Create(const Source: string);
    destructor Destroy; override;

    function HasFlag(const Flag: string): Boolean;

    property Includes: TArray<string> read GetIncludes;
    property Features: TArray<string> read GetFeatures;
    property IsNegative: Boolean read GetIsNegative;
    property NegativePhase: TErrorPhase read FNegativePhase;
    property NegativeType: string read FNegativeType;
  end;

implementation

const
  FRONTMATTER_START = '/*---';
  FRONTMATTER_END = '---*/';
  KEY_INCLUDES = 'includes';
  KEY_FLAGS = 'flags';
  KEY_FEATURES = 'features';
  KEY_NEGATIVE = 'negative';
  KEY_PHASE = 'phase';
  KEY_TYPE = 'type';
  LIST_ITEM_PREFIX = '- ';
  KEY_SEPARATOR = ':';
  VALUE_SEPARATOR = ',';
  SPACE = ' ';
  TAB = #9;
  QUOTE = '"';
  APOSTROPHE = '''';
  LIST_BRACKET_OPEN = '[';
  LIST_BRACKET_CLOSE = ']';
  ListKeys: array[0..2] of string = (KEY_INCLUDES, KEY_FLAGS, KEY_FEATURES);

constructor TTestMetadata.Create(const Source: string);
begin
  inherited Create;
  FLists := TObjectDictionary<string, TList<string>>.Create([doOwnsValues]);

  for var Key in ListKeys do
  begin
    FLists.Add(Key, TList<string>.Create);
  end;

  const Frontmatter = ExtractFrontmatter(Source);
  const Lines = Frontmatter.Replace(#13, '').Split([#10]);
  for var Line in Lines do
  begin
    ParseLine(Line);
  end;
end;

destructor TTestMetadata.Destroy;
begin
  FLists.Free;
  inherited;
end;

function TTestMetadata.HasFlag(const Flag: string): Boolean;
begin
  Result := FLists[KEY_FLAGS].Contains(Flag);
end;

function TTestMetadata.ExtractFrontmatter(const Source: string): string;
begin
  const StartIndex = Source.IndexOf(FRONTMATTER_START);
  const EndIndex = Source.IndexOf(FRONTMATTER_END);
  const HasFrontmatter = (StartIndex >= 0) and (EndIndex > StartIndex);
  if not HasFrontmatter then
    Exit('');

  const BodyStart = StartIndex + FRONTMATTER_START.Length;
  Result := Source.Substring(BodyStart, EndIndex - BodyStart);
end;

function TTestMetadata.GetIncludes: TArray<string>;
begin
  Result := FLists[KEY_INCLUDES].ToArray;
end;

function TTestMetadata.GetFeatures: TArray<string>;
begin
  Result := FLists[KEY_FEATURES].ToArray;
end;

function TTestMetadata.GetIsNegative: Boolean;
begin
  Result := (FNegativePhase <> TErrorPhase.None);
end;

function TTestMetadata.ParsePhase(const Value: string): TErrorPhase;
begin
  if SameText(Value, PHASE_PARSE) then
    Exit(TErrorPhase.Parse);

  if SameText(Value, PHASE_RESOLUTION) then
    Exit(TErrorPhase.Resolution);

  Result := TErrorPhase.Runtime;
end;

procedure TTestMetadata.ParseLine(const Line: string);
begin
  const TrimmedLine = Line.Trim;
  if TrimmedLine.IsEmpty then
    Exit;

  const IsIndented = Line.StartsWith(SPACE) or Line.StartsWith(TAB);
  if IsIndented then
  begin
    ContinueKey(TrimmedLine);
  end
  else
  begin
    StartKey(TrimmedLine);
  end;
end;

procedure TTestMetadata.StartKey(const Line: string);
begin
  const SeparatorIndex = Line.IndexOf(KEY_SEPARATOR);
  const HasSeparator = (SeparatorIndex >= 0);
  if not HasSeparator then
    Exit;

  const Values = Line.Substring(SeparatorIndex + 1).Trim;
  FCurrentKey := Line.Substring(0, SeparatorIndex).Trim;
  AddValues(FCurrentKey, Values);
end;

procedure TTestMetadata.ContinueKey(const Line: string);
begin
  const IsListItem = Line.StartsWith(LIST_ITEM_PREFIX);
  if IsListItem then
  begin
    const Item = Line.Substring(LIST_ITEM_PREFIX.Length);
    AddValues(FCurrentKey, Item);
    Exit;
  end;

  const IsNegativeKey = (FCurrentKey = KEY_NEGATIVE);
  if IsNegativeKey then
    ContinueNegative(Line);
end;

procedure TTestMetadata.ContinueNegative(const Line: string);
begin
  const SeparatorIndex = Line.IndexOf(KEY_SEPARATOR);
  const HasSeparator = (SeparatorIndex >= 0);
  if not HasSeparator then
    Exit;

  const Key = Line.Substring(0, SeparatorIndex).Trim;
  const RawValue = Line.Substring(SeparatorIndex + 1).Trim;
  const Value = RawValue.DeQuotedString(QUOTE);
  const IsPhaseKey = (Key = KEY_PHASE);
  const IsTypeKey = (Key = KEY_TYPE);
  if IsPhaseKey then
  begin
    FNegativePhase := ParsePhase(Value);
  end
  else if IsTypeKey then
  begin
    FNegativeType := Value;
  end;
end;

procedure TTestMetadata.AddValues(const Key: string; const Value: string);
begin
  var Collected: TList<string>;
  const IsListKey = FLists.TryGetValue(Key, Collected);
  if not IsListKey then
    Exit;

  const Entries = Value.Trim([LIST_BRACKET_OPEN, LIST_BRACKET_CLOSE, SPACE]).Split([VALUE_SEPARATOR]);
  for var Entry in Entries do
  begin
    const TrimmedEntry = Entry.Trim;
    const CleanEntry = TrimmedEntry.Trim([QUOTE, APOSTROPHE]);
    if not CleanEntry.IsEmpty then
      Collected.Add(CleanEntry);
  end;
end;

end.
