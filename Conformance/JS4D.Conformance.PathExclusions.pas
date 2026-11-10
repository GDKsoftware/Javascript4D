unit JS4D.Conformance.PathExclusions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections;

type
  TPathExclusionList = class
  private
    FPrefixes: TList<string>;

  public
    constructor Create(const FilePath: string);
    destructor Destroy; override;

    function TryFindExcluded(const RelativePath: string; out Prefix: string): Boolean;
  end;

implementation

const
  CommentPrefix = '#';

constructor TPathExclusionList.Create(const FilePath: string);
begin
  inherited Create;
  FPrefixes := TList<string>.Create;

  for var Line in TFile.ReadAllLines(FilePath) do
  begin
    const Prefix = Line.Trim;
    const IsPrefix = (not Prefix.IsEmpty) and (not Prefix.StartsWith(CommentPrefix));
    if IsPrefix then
      FPrefixes.Add(Prefix);
  end;
end;

destructor TPathExclusionList.Destroy;
begin
  FPrefixes.Free;
  inherited;
end;

function TPathExclusionList.TryFindExcluded(const RelativePath: string; out Prefix: string): Boolean;
begin
  for var Candidate in FPrefixes do
  begin
    if RelativePath.StartsWith(Candidate) then
    begin
      Prefix := Candidate;
      Exit(True);
    end;
  end;

  Prefix := '';
  Result := False;
end;

end.
