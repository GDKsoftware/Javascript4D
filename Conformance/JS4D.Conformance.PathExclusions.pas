unit JS4D.Conformance.PathExclusions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
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

uses
  JS4D.Conformance.ListFile;

constructor TPathExclusionList.Create(const FilePath: string);
begin
  inherited Create;
  FPrefixes := TList<string>.Create;

  FPrefixes.AddRange(TListFile.ReadEntries(FilePath));
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
      Result := True;
      Exit;
    end;
  end;

  Prefix := '';
  Result := False;
end;

end.
