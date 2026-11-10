unit JS4D.PcreMatcher;

interface

uses
  System.RegularExpressionsAPI;

type
  TJSPcreMatcher = class
  private
    FPattern: string;
    FOptions: Integer;
    FCode: PPCRE;
    FCharTable: MarshaledAString;
    FOffsets: TArray<Integer>;
    FCaptureCount: Integer;

    procedure EnsureCompiled;

  public
    constructor Create(const Pattern: string; const IgnoreCase: Boolean; const Multiline: Boolean);
    destructor Destroy; override;

    function TryMatch(const Subject: string; const Start: Integer): Boolean;
    function HasParticipated(const GroupIndex: Integer): Boolean;
    function GroupStart(const GroupIndex: Integer): Integer;
    function GroupEnd(const GroupIndex: Integer): Integer;

    property CaptureCount: Integer read FCaptureCount;
  end;

implementation

uses
  System.SysUtils,
  System.RegularExpressionsCore;

const
  OFFSETS_PER_GROUP = 2;
  OFFSET_SLOTS_PER_GROUP = 3;
  UNSET_OFFSET = -1;
  COMPILE_ERROR_FORMAT = 'Error in regular expression at offset %d: %s';

constructor TJSPcreMatcher.Create(const Pattern: string; const IgnoreCase: Boolean; const Multiline: Boolean);
begin
  inherited Create;
  FPattern := Pattern;
  FOptions := PCRE_UTF8 or PCRE_NEWLINE_ANY or PCRE_JAVASCRIPT_COMPAT or PCRE_DOLLAR_ENDONLY;

  if IgnoreCase then
    FOptions := FOptions or PCRE_CASELESS;

  if Multiline then
    FOptions := FOptions or PCRE_MULTILINE;

  FCharTable := pcre_maketables;
end;

destructor TJSPcreMatcher.Destroy;
begin
  pcre_dispose(FCode, nil, FCharTable);
  inherited Destroy;
end;

procedure TJSPcreMatcher.EnsureCompiled;
begin
  if Assigned(FCode) then
    Exit;

  var ErrorText: MarshaledAString;
  var ErrorOffset: Integer;

  FCode := pcre_compile(PCRE_STR(FPattern), FOptions, @ErrorText, @ErrorOffset, FCharTable);
  if not Assigned(FCode) then
    raise ERegularExpressionError.CreateFmt(COMPILE_ERROR_FORMAT, [ErrorOffset, string(ErrorText)]);

  var CaptureTotal: Integer;
  pcre_fullinfo(FCode, nil, PCRE_INFO_CAPTURECOUNT, @CaptureTotal);

  FCaptureCount := CaptureTotal;
  SetLength(FOffsets, (FCaptureCount + 1) * OFFSET_SLOTS_PER_GROUP);
end;

function TJSPcreMatcher.TryMatch(const Subject: string; const Start: Integer): Boolean;
begin
  EnsureCompiled;

  for var Slot := 0 to High(FOffsets) do
  begin
    FOffsets[Slot] := UNSET_OFFSET;
  end;

  const Executed = pcre_exec(FCode, nil, PCRE_STR(Subject), Length(Subject), Start, PCRE_NO_UTF8_CHECK,
                             @FOffsets[0], Length(FOffsets));

  Result := (Executed <> PCRE_ERROR_NOMATCH) and (Executed >= 0);
end;

function TJSPcreMatcher.GroupStart(const GroupIndex: Integer): Integer;
begin
  Result := FOffsets[GroupIndex * OFFSETS_PER_GROUP];
end;

function TJSPcreMatcher.GroupEnd(const GroupIndex: Integer): Integer;
begin
  Result := FOffsets[GroupIndex * OFFSETS_PER_GROUP + 1];
end;

function TJSPcreMatcher.HasParticipated(const GroupIndex: Integer): Boolean;
begin
  Result := (GroupStart(GroupIndex) <> UNSET_OFFSET);
end;

end.
