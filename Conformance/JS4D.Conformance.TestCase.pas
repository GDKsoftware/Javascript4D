unit JS4D.Conformance.TestCase;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.IOUtils,
  JS4D.Conformance.Metadata;

type
  TTestCase = class
  private
    FRelativePath: string;
    FSource: string;
    FMetadata: TTestMetadata;

    function GetGroup: string;
    function GetIsFixture: Boolean;

  public
    constructor Create(const FilePath: string; const RelativePath: string);
    destructor Destroy; override;

    property RelativePath: string read FRelativePath;
    property Source: string read FSource;
    property Metadata: TTestMetadata read FMetadata;
    property Group: string read GetGroup;
    property IsFixture: Boolean read GetIsFixture;
  end;

implementation

const
  PathSeparator = '/';
  GroupDepth = 2;
  FixtureMarker = '_FIXTURE';

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
  const Segments = FRelativePath.Split([PathSeparator]);
  const HasDirectory = (Length(Segments) > GroupDepth);
  if not HasDirectory then
    Exit(Segments[0]);

  Result := string.Join(PathSeparator, Segments, 0, GroupDepth);
end;

function TTestCase.GetIsFixture: Boolean;
begin
  Result := FRelativePath.Contains(FixtureMarker);
end;

end.
