unit JS4D.Conformance.Harness;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  JS4D.Conformance.Defines,
  JS4D.Conformance.Session;

type
  THarnessLibrary = class
  private
    FDirectory: string;
    FLimits: TSessionLimits;
    FSources: TDictionary<string, string>;
  public
    constructor Create(const Directory: string; const Limits: TSessionLimits);
    destructor Destroy; override;

    function ReadSource(const FileName: string): string;

    class function BaseFiles: TArray<string>; static;
  end;

implementation

const
  AssertFile = 'assert.js';
  StaFile = 'sta.js';

class function THarnessLibrary.BaseFiles: TArray<string>;
begin
  Result := [AssertFile, StaFile];
end;

constructor THarnessLibrary.Create(const Directory: string; const Limits: TSessionLimits);
begin
  inherited Create;
  FDirectory := Directory;
  FLimits := Limits;
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
