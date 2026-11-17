unit JS4D.Conformance.Harness;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  THarnessLibrary = class
  private
    FDirectory: string;
    FSources: TDictionary<string, string>;

  public
    class function BaseFiles: TArray<string>; static;

    constructor Create(const Directory: string);
    destructor Destroy; override;

    function ReadSource(const FileName: string): string;
  end;

implementation

uses
  System.IOUtils;

const
  ASSERT_FILE = 'assert.js';
  STA_FILE = 'sta.js';

class function THarnessLibrary.BaseFiles: TArray<string>;
begin
  Result := [ASSERT_FILE, STA_FILE];
end;

constructor THarnessLibrary.Create(const Directory: string);
begin
  inherited Create;
  FDirectory := Directory;
  FSources := TDictionary<string, string>.Create;
end;

destructor THarnessLibrary.Destroy;
begin
  FSources.Free;
  inherited;
end;

function THarnessLibrary.ReadSource(const FileName: string): string;
begin
  if FSources.TryGetValue(FileName, Result) then
    Exit;

  const FilePath = TPath.Combine(FDirectory, FileName);
  Result := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  FSources.Add(FileName, Result);
end;

end.
