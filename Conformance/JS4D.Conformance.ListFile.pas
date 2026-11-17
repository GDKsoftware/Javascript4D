unit JS4D.Conformance.ListFile;

{$SCOPEDENUMS ON}

interface

type
  TListFile = class
  public
    class function ReadEntries(const FilePath: string): TArray<string>; static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

const
  COMMENT_PREFIX = '#';

class function TListFile.ReadEntries(const FilePath: string): TArray<string>;
begin
  Result := [];
  for var Line in TFile.ReadAllLines(FilePath) do
  begin
    const Entry = Line.Trim;
    const IsEntry = (not Entry.IsEmpty) and (not Entry.StartsWith(COMMENT_PREFIX));
    if IsEntry then
      Result := Result + [Entry];
  end;
end;

end.
