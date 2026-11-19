unit JS4D.Conformance.Selector;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Conformance.Defines,
  JS4D.Conformance.TestCase,
  JS4D.Conformance.FeatureExclusions,
  JS4D.Conformance.PathExclusions;

type
  TTestSelector = class
  private
    FExclusions: TFeatureExclusionList;
    FPathExclusions: TPathExclusionList;

    function TryGetFixtureReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetFlagReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetPathReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetPhaseReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetFeatureReason(const TestCase: TTestCase; out Reason: string): Boolean;
    function TryGetHostMemberReason(const TestCase: TTestCase; out Reason: string): Boolean;

  public
    constructor Create(const Exclusions: TFeatureExclusionList; const PathExclusions: TPathExclusionList);

    function TryGetSkipReason(const TestCase: TTestCase; out Reason: string): Boolean;
  end;

implementation

const
  FIXTURE_REASON = 'fixture file';
  FLAG_REASON_FORMAT = 'flag: %s';
  PATH_REASON_FORMAT = 'path: %s';
  PHASE_REASON_FORMAT = 'negative phase: %s';
  FEATURE_REASON_FORMAT = 'feature: %s';
  HOST_MEMBER_REASON_FORMAT = 'host member not provided: %s';
  UNSUPPORTED_HOST_MEMBERS: array[0..2] of string = (HOST_OBJECT_NAME + '.createRealm',
                                                     HOST_OBJECT_NAME + '.agent',
                                                     HOST_OBJECT_NAME + '.IsHTMLDDA');
  SKIPPED_FLAGS: array[0..2] of string = ('module', 'CanBlockIsFalse', 'CanBlockIsTrue');

constructor TTestSelector.Create(const Exclusions: TFeatureExclusionList; const PathExclusions: TPathExclusionList);
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
  Result := TestCase.IsFixture;
  if Result then
    Reason := FIXTURE_REASON
  else
    Reason := '';
end;

function TTestSelector.TryGetFlagReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  Reason := '';
  const Metadata = TestCase.Metadata;
  for var Flag in SKIPPED_FLAGS do
  begin
    if Metadata.HasFlag(Flag) then
    begin
      Reason := Format(FLAG_REASON_FORMAT, [Flag]);
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

function TTestSelector.TryGetPathReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  var Prefix: string;
  Result := FPathExclusions.TryFindExcluded(TestCase.RelativePath, Prefix);
  if Result then
    Reason := Format(PATH_REASON_FORMAT, [Prefix])
  else
    Reason := '';
end;

function TTestSelector.TryGetPhaseReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  const Metadata = TestCase.Metadata;
  Result := (Metadata.NegativePhase = TErrorPhase.Resolution);
  if Result then
    Reason := Format(PHASE_REASON_FORMAT, [PHASE_RESOLUTION])
  else
    Reason := '';
end;

function TTestSelector.TryGetFeatureReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  var Tag: string;
  const Metadata = TestCase.Metadata;
  const Features = Metadata.Features;
  Result := FExclusions.TryFindExcluded(Features, Tag);
  if Result then
    Reason := Format(FEATURE_REASON_FORMAT, [Tag])
  else
    Reason := '';
end;

function TTestSelector.TryGetHostMemberReason(const TestCase: TTestCase; out Reason: string): Boolean;
begin
  Reason := '';
  const Source = TestCase.Source;
  for var Member in UNSUPPORTED_HOST_MEMBERS do
  begin
    if Source.Contains(Member) then
    begin
      Reason := Format(HOST_MEMBER_REASON_FORMAT, [Member]);
      Result := True;
      Exit;
    end;
  end;

  Result := False;
end;

end.
