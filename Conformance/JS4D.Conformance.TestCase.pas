unit JS4D.Conformance.TestCase;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  JS4D.Conformance.Defines,
  JS4D.Conformance.Metadata;

type
  TTestCase = class
  private
    FRelativePath: string;
    FSource: string;
    FMetadata: TTestMetadata;

    function GetGroup: string;
    function GetIsFixture: Boolean;
    function GetIsAsync: Boolean;

  public
    constructor Create(const FilePath: string; const RelativePath: string);
    destructor Destroy; override;

    property RelativePath: string read FRelativePath;
    property Source: string read FSource;
    property Metadata: TTestMetadata read FMetadata;
    property Group: string read GetGroup;
    property IsFixture: Boolean read GetIsFixture;
    property IsAsync: Boolean read GetIsAsync;
  end;

implementation

const
  GROUP_DEPTH = 2;
  FIXTURE_MARKER = '_FIXTURE';
  ASYNC_FLAG = 'async';

constructor TTestCase.Create(const FilePath: string; const RelativePath: string);
begin
  inherited Create;
  FRelativePath := RelativePath;
  FSource := TFile.ReadAllText(FilePath, TEncoding.UTF8);
  FMetadata := TTestMetadata.Create(FSource);
end;

destructor TTestCase.Destroy;
begin
  FMetadata.Free;
  inherited;
end;

function TTestCase.GetGroup: string;
begin
  const Segments = FRelativePath.Split([PATH_SEPARATOR]);
  const IsNested = (Length(Segments) > GROUP_DEPTH);
  if not IsNested then
    Exit(Segments[0]);

  Result := string.Join(PATH_SEPARATOR, Segments, 0, GROUP_DEPTH);
end;

function TTestCase.GetIsFixture: Boolean;
begin
  Result := FRelativePath.Contains(FIXTURE_MARKER);
end;

function TTestCase.GetIsAsync: Boolean;
begin
  Result := FMetadata.HasFlag(ASYNC_FLAG);
end;

end.
