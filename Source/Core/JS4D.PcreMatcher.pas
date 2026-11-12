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
    class function ClampQuantifierBounds(const Pattern: string): string; static;
    class function TryClampQuantifier(const Pattern: string; const OpenIndex: Integer;
                                      out Quantifier: string; out TokenLength: Integer): Boolean; static;
    class function ClampBound(const Digits: string): string; static;
    class function IsDigits(const Text: string): Boolean; static;
    class function NextClassState(const Current: Char; const InsideClass: Boolean): Boolean; static;
    class function RecursionLimit: Cardinal; static;

  public
    constructor Create(const Pattern: string; const IgnoreCase: Boolean; const Multiline: Boolean;
                       const UtfMode: Boolean);
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
  System.RegularExpressionsCore,
  JS4D.Errors,
  JS4D.StackGuard;

const
  OFFSETS_PER_GROUP = 2;
  OFFSET_SLOTS_PER_GROUP = 3;
  UNSET_OFFSET = -1;
  COMPILE_ERROR_FORMAT = 'Error in regular expression at offset %d: %s';
  MAX_QUANTIFIER_BOUND = 65535;
  MAX_QUANTIFIER_DIGITS = 5;
  ESCAPE_LENGTH = 2;
  RECURSION_FRAME_BYTES = 1024;
  RECURSION_STACK_RESERVE = 128 * 1024;
  MAX_RECURSION_DEPTH = 10000000;
  STACK_EXHAUSTED = 'Maximum call stack size exceeded';

constructor TJSPcreMatcher.Create(const Pattern: string; const IgnoreCase: Boolean; const Multiline: Boolean;
                                  const UtfMode: Boolean);
begin
  inherited Create;
  FPattern := ClampQuantifierBounds(Pattern);
  FOptions := PCRE_NEWLINE_ANY or PCRE_JAVASCRIPT_COMPAT or PCRE_DOLLAR_ENDONLY;

  if UtfMode then
    FOptions := FOptions or PCRE_UTF8;

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

class function TJSPcreMatcher.IsDigits(const Text: string): Boolean;
begin
  Result := not Text.IsEmpty;

  for var Letter in Text do
  begin
    if not CharInSet(Letter, ['0'..'9']) then
      Exit(False);
  end;
end;

class function TJSPcreMatcher.ClampBound(const Digits: string): string;
begin
  if Digits.IsEmpty then
    Exit('');

  const Significant = Digits.TrimLeft(['0']);
  if Significant.IsEmpty then
    Exit('0');

  const ExceedsLimit = (Significant.Length > MAX_QUANTIFIER_DIGITS) or (StrToInt(Significant) > MAX_QUANTIFIER_BOUND);
  if ExceedsLimit then
    Exit(IntToStr(MAX_QUANTIFIER_BOUND));

  Result := Significant;
end;

class function TJSPcreMatcher.TryClampQuantifier(const Pattern: string; const OpenIndex: Integer;
                                                 out Quantifier: string; out TokenLength: Integer): Boolean;
begin
  const CloseIndex = Pattern.IndexOf('}', OpenIndex);
  if CloseIndex < 0 then
    Exit(False);

  const Bounds = Pattern.Substring(OpenIndex + 1, CloseIndex - OpenIndex - 1).Split([',']);
  const HasUpperBound = (Length(Bounds) = 2);
  const IsBoundsCountValid = (Length(Bounds) in [1, 2]);
  if not (IsBoundsCountValid and IsDigits(Bounds[0])) then
    Exit(False);

  const IsUpperBoundValid = (not HasUpperBound) or Bounds[1].IsEmpty or IsDigits(Bounds[1]);
  if not IsUpperBoundValid then
    Exit(False);

  Quantifier := '{' + ClampBound(Bounds[0]);
  if HasUpperBound then
    Quantifier := Quantifier + ',' + ClampBound(Bounds[1]);

  Quantifier := Quantifier + '}';
  TokenLength := CloseIndex - OpenIndex + 1;
  Result := True;
end;

class function TJSPcreMatcher.NextClassState(const Current: Char; const InsideClass: Boolean): Boolean;
begin
  if Current = '[' then
    Exit(True);

  if Current = ']' then
    Exit(False);

  Result := InsideClass;
end;

class function TJSPcreMatcher.ClampQuantifierBounds(const Pattern: string): string;
begin
  const Clamped = TStringBuilder.Create;
  try
    var Index := 0;
    var InsideClass := False;

    while Index < Pattern.Length do
    begin
      const Current = Pattern.Chars[Index];

      const IsEscape = (Current = '\') and (Index + 1 < Pattern.Length);
      if IsEscape then
      begin
        Clamped.Append(Pattern, Index, ESCAPE_LENGTH);
        Inc(Index, ESCAPE_LENGTH);
        Continue;
      end;

      var Quantifier := '';
      var TokenLength := 0;
      const IsQuantifier = (not InsideClass) and (Current = '{') and
                           TryClampQuantifier(Pattern, Index, Quantifier, TokenLength);
      if IsQuantifier then
      begin
        Clamped.Append(Quantifier);
        Inc(Index, TokenLength);
        Continue;
      end;

      InsideClass := NextClassState(Current, InsideClass);
      Clamped.Append(Current);
      Inc(Index);
    end;

    Result := Clamped.ToString;
  finally
    Clamped.Free;
  end;
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

class function TJSPcreMatcher.RecursionLimit: Cardinal;
begin
  const Remaining = TJSStackGuard.RemainingBytes;
  if Remaining <= RECURSION_STACK_RESERVE then
    Exit(1);

  const Depth = (Remaining - RECURSION_STACK_RESERVE) div RECURSION_FRAME_BYTES;
  if Depth > MAX_RECURSION_DEPTH then
    Exit(MAX_RECURSION_DEPTH);

  Result := Cardinal(Depth);
end;

function TJSPcreMatcher.TryMatch(const Subject: string; const Start: Integer): Boolean;
begin
  EnsureCompiled;

  for var Slot := 0 to High(FOffsets) do
  begin
    FOffsets[Slot] := UNSET_OFFSET;
  end;

  var Limits := Default(TPCREExtra);
  Limits.flags := PCRE_EXTRA_MATCH_LIMIT_RECURSION;
  Limits.match_limit_recursion := RecursionLimit;

  const Executed = pcre_exec(FCode, @Limits, PCRE_STR(Subject), Length(Subject), Start, PCRE_NO_UTF8_CHECK,
                             @FOffsets[0], Length(FOffsets));

  if Executed = PCRE_ERROR_RECURSIONLIMIT then
    raise TJSErrorFactory.RangeError(STACK_EXHAUSTED);

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
