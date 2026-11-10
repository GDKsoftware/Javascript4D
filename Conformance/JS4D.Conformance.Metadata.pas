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
    function GetFlags: TArray<string>;
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
    property Flags: TArray<string> read GetFlags;
    property Features: TArray<string> read GetFeatures;
    property IsNegative: Boolean read GetIsNegative;
    property NegativePhase: TErrorPhase read FNegativePhase;
    property NegativeType: string read FNegativeType;
  end;

implementation

const
  FrontmatterStart = '/*---';
  FrontmatterEnd = '---*/';
  KeyIncludes = 'includes';
  KeyFlags = 'flags';
  KeyFeatures = 'features';
  KeyNegative = 'negative';
  KeyPhase = 'phase';
  KeyType = 'type';
  ListItemPrefix = '- ';
  ListKeys: array[0..2] of string = (KeyIncludes, KeyFlags, KeyFeatures);

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
  Result := FLists[KeyFlags].Contains(Flag);
end;

function TTestMetadata.ExtractFrontmatter(const Source: string): string;
begin
  const StartIndex = Source.IndexOf(FrontmatterStart);
  const EndIndex = Source.IndexOf(FrontmatterEnd);
  const HasFrontmatter = (StartIndex >= 0) and (EndIndex > StartIndex);
  if not HasFrontmatter then
    Exit('');

  const BodyStart = StartIndex + FrontmatterStart.Length;
  Result := Source.Substring(BodyStart, EndIndex - BodyStart);
end;

function TTestMetadata.GetIncludes: TArray<string>;
begin
  Result := FLists[KeyIncludes].ToArray;
end;

function TTestMetadata.GetFlags: TArray<string>;
begin
  Result := FLists[KeyFlags].ToArray;
end;

function TTestMetadata.GetFeatures: TArray<string>;
begin
  Result := FLists[KeyFeatures].ToArray;
end;

function TTestMetadata.GetIsNegative: Boolean;
begin
  Result := (FNegativePhase <> TErrorPhase.None);
end;

function TTestMetadata.ParsePhase(const Value: string): TErrorPhase;
begin
  if SameText(Value, 'parse') then
    Exit(TErrorPhase.Parse);

  if SameText(Value, 'resolution') then
    Exit(TErrorPhase.Resolution);

  Result := TErrorPhase.Runtime;
end;

procedure TTestMetadata.ParseLine(const Line: string);
begin
  if Line.Trim.IsEmpty then
    Exit;

  const IsIndented = Line.StartsWith(' ') or Line.StartsWith(#9);
  if IsIndented then
  begin
    ContinueKey(Line.Trim);
  end
  else
  begin
    StartKey(Line.Trim);
  end;
end;

procedure TTestMetadata.StartKey(const Line: string);
begin
  const SeparatorIndex = Line.IndexOf(':');
  const HasSeparator = (SeparatorIndex >= 0);
  if not HasSeparator then
    Exit;

  FCurrentKey := Line.Substring(0, SeparatorIndex).Trim;
  AddValues(FCurrentKey, Line.Substring(SeparatorIndex + 1).Trim);
end;

procedure TTestMetadata.ContinueKey(const Line: string);
begin
  if Line.StartsWith(ListItemPrefix) then
  begin
    AddValues(FCurrentKey, Line.Substring(ListItemPrefix.Length));
    Exit;
  end;

  const IsNegativeKey = (FCurrentKey = KeyNegative);
  if IsNegativeKey then
    ContinueNegative(Line);
end;

procedure TTestMetadata.ContinueNegative(const Line: string);
begin
  const SeparatorIndex = Line.IndexOf(':');
  const HasSeparator = (SeparatorIndex >= 0);
  if not HasSeparator then
    Exit;

  const Key = Line.Substring(0, SeparatorIndex).Trim;
  const Value = Line.Substring(SeparatorIndex + 1).Trim.DeQuotedString('"');
  const IsPhaseKey = (Key = KeyPhase);
  const IsTypeKey = (Key = KeyType);
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

  const Entries = Value.Trim(['[', ']', ' ']).Split([',']);
  for var Entry in Entries do
  begin
    const CleanEntry = Entry.Trim.Trim(['"', '''']);
    if not CleanEntry.IsEmpty then
      Collected.Add(CleanEntry);
  end;
end;

end.
