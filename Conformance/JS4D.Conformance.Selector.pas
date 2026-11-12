unit JS4D.Conformance.Selector;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase,
  JS4D.Conformance.Exclusions,
  JS4D.Conformance.PathExclusions;

type
  TTestSelector = class
  private
    FExclusions: TExclusionList;
    FPathExclusions: TPathExclusionList;

    function TryGetFixtureReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetFlagReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetPathReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetPhaseReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetFeatureReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetHostMemberReason(const TestCase: TTestCase; out Reason: string): Boolean;

  public
    constructor Create(const Exclusions: TExclusionList; const PathExclusions: TPathExclusionList);

    function TryGetSkipReason(const TestCase: TTestCase; out Reason: string): Boolean;
  end;

implementation

const
  FixtureReason = 'fixture file';
  FlagReasonFormat = 'flag: %s';
  PathReasonFormat = 'path: %s';
  PhaseReasonFormat = 'negative phase: %s';
  FeatureReasonFormat = 'feature: %s';
  HostMemberReasonFormat = 'host member not provided: %s';
  UnsupportedHostMembers: array[0..2] of string = ('$262.createRealm',
                                                   '$262.agent',
                                                   '$262.IsHTMLDDA');
  SkippedFlags: array[0..3] of string = ('module', 'async', 'CanBlockIsFalse', 'CanBlockIsTrue');
  ResolutionPhase = 'resolution';

constructor TTestSelector.Create(const Exclusions: TExclusionList; const PathExclusions: TPathExclusionList);
begin
  inherited Create;
  FExclusions := Exclusions;
  FPathExclusions := PathExclusions;
end;

function TTestSelector.TryGetSkipReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  Result := TryGetFixtureReason(TestCase, Reason) or
            TryGetFlagReason(TestCase, Reason) or
            TryGetPhaseReason(TestCase, Reason) or
            TryGetFeatureReason(TestCase, Reason) or
            TryGetPathReason(TestCase, Reason) or
            TryGetHostMemberReason(TestCase, Reason);
end;

function TTestSelector.TryGetFixtureReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  Reason := FixtureReason;
  Result := TestCase.IsFixture;
end;

function TTestSelector.TryGetFlagReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  for var Flag in SkippedFlags do
  begin
    if TestCase.Metadata.HasFlag(Flag) then
    begin
      Reason := Format(FlagReasonFormat, [Flag]);
      Exit(True);
    end;
  end;

  Result := False;
end;

function TTestSelector.TryGetPathReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  var Prefix: string;
  Result := FPathExclusions.TryFindExcluded(TestCase.RelativePath, Prefix);
  if Result then
    Reason := Format(PathReasonFormat, [Prefix])
  else
    Reason := '';
end;

function TTestSelector.TryGetPhaseReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  Reason := Format(PhaseReasonFormat, [ResolutionPhase]);
  Result := (TestCase.Metadata.NegativePhase = TErrorPhase.Resolution);
end;

function TTestSelector.TryGetFeatureReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  var Tag: string;
  Result := FExclusions.TryFindExcluded(TestCase.Metadata.Features, Tag);
  if Result then
    Reason := Format(FeatureReasonFormat, [Tag])
  else
    Reason := '';
end;

function TTestSelector.TryGetHostMemberReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  for var Member in UnsupportedHostMembers do
  begin
    if TestCase.Source.Contains(Member) then
    begin
      Reason := Format(HostMemberReasonFormat, [Member]);
      Exit(True);
    end;
  end;

  Result := False;
end;

end.
