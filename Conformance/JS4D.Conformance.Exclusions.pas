unit JS4D.Conformance.Exclusions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections;

type
  TExclusionList = class
  private
    FTags: THashSet<string>;

  public
    constructor Create(const FilePath: string);
    destructor Destroy; override;

    function TryFindExcluded(const Features: TArray<string>; out Tag: string): Boolean;
  end;

implementation

const
  CommentPrefix = '#';

constructor TExclusionList.Create(const FilePath: string);
begin
  inherited Create;
  FTags := THashSet<string>.Create;

  for var Line in TFile.ReadAllLines(FilePath) do
  begin
    const Tag = Line.Trim;
    const IsTag = (not Tag.IsEmpty) and (not Tag.StartsWith(CommentPrefix));
    if IsTag then
      FTags.Add(Tag);
  end;
end;

destructor TExclusionList.Destroy;
begin
  FTags.Free;
  inherited;
end;

function TExclusionList.TryFindExcluded(const Features: TArray<string>; out Tag: string): Boolean;
begin
  for var Feature in Features do
  begin
    if FTags.Contains(Feature) then
    begin
      Tag := Feature;
      Exit(True);
    end;
  end;

  Tag := '';
  Result := False;
end;

end.
