unit JS4D.Conformance.FeatureExclusions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TFeatureExclusionList = class
  private
    FTags: THashSet<string>;

  public
    constructor Create(const FilePath: string);
    destructor Destroy; override;

    function TryFindExcluded(const Features: TArray<string>; out Tag: string): Boolean;
  end;

implementation

uses
  JS4D.Conformance.ListFile;

constructor TFeatureExclusionList.Create(const FilePath: string);
begin
  inherited Create;
  FTags := THashSet<string>.Create;

  for var Tag in TListFile.ReadEntries(FilePath) do
  begin
    FTags.Add(Tag);
  end;
end;

destructor TFeatureExclusionList.Destroy;
begin
  FTags.Free;
  inherited;
end;

function TFeatureExclusionList.TryFindExcluded(const Features: TArray<string>; out Tag: string): Boolean;
begin
  for var Feature in Features do
  begin
    if FTags.Contains(Feature) then
    begin
      Tag := Feature;
      Result := True;
      Exit;
    end;
  end;

  Tag := '';
  Result := False;
end;

end.
