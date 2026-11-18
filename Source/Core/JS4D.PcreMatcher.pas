unit JS4D.PcreMatcher;

interface

uses
  System.RegularExpressionsAPI;

type
  TJSPcreMatcher = class
  private
    type
      TPatternToken = record
        IsRewritten: Boolean;
        Replacement: string;
        SourceLength: Integer;

        class function Unchanged(const SourceLength: Integer): TPatternToken; static;
        class function Rewritten(const Replacement: string; const SourceLength: Integer): TPatternToken; static;
      end;

    const
      OFFSETS_PER_GROUP = 2;
      PCRE_VECTOR_ENTRIES_PER_GROUP = 3;
      UNSET_OFFSET = -1;
      UNSET_OFFSET_BYTE = $FF;
      MAX_QUANTIFIER_BOUND = 65535;
      MAX_QUANTIFIER_DIGITS = 5;
      ESTIMATED_RECURSION_FRAME_BYTES = 1024;
      RECURSION_STACK_RESERVE = 128 * 1024;
      MAX_RECURSION_DEPTH = 10000000;
      MIN_RECURSION_DEPTH = 1;
      MAX_MATCH_STEPS = 10000000;
      MATCH_LIMIT_MESSAGE = 'Regular expression match limit exceeded';
      PCRE_FAILURE_MESSAGE = 'Regular expression matching failed with PCRE error %d';

    var
      FPattern: string;
      FOptions: Integer;
      FCode: PPCRE;
      FCharTable: MarshaledAString;
      FOffsets: TArray<Integer>;
      FCaptureCount: Integer;

    procedure EnsureCompiled;
    procedure ResetOffsets;
    function TryExecute(const Subject: string; const Start: Integer; const ExecOptions: Integer): Boolean;
    function ExecuteMatch(const Subject: string; const Start: Integer; const ExecOptions: Integer): Integer;
    function IsMatchResult(const Executed: Integer): Boolean;

    class function ClampQuantifierBounds(const Pattern: string): string; static;
    class function NextToken(const Pattern: string; const Index: Integer;
                             const InsideClass: Boolean): TPatternToken; static;
    class function TryClampQuantifier(const Pattern: string; const OpenIndex: Integer;
                                      out Token: TPatternToken): Boolean; static;
    class function ClampBound(const Digits: string): string; static;
    class function IsDigits(const Text: string): Boolean; static;
    class function RecursionLimit: Cardinal; static;

  public
    constructor Create(const Pattern: string; const IgnoreCase: Boolean; const Multiline: Boolean;
                       const UtfMode: Boolean);
    destructor Destroy; override;

    function TryMatch(const Subject: string; const Start: Integer): Boolean;
    function TryMatchAtStart(const Subject: string; const Start: Integer): Boolean;
    function HasParticipated(const GroupIndex: Integer): Boolean;
    function GroupStart(const GroupIndex: Integer): Integer;
    function GroupEnd(const GroupIndex: Integer): Integer;

    property CaptureCount: Integer read FCaptureCount;
  end;

implementation

uses
  System.SysUtils,
  JS4D.AsciiDigits,
  JS4D.Errors,
  JS4D.RegExpCharacters,
  JS4D.StackGuard;

{ TJSPcreMatcher.TPatternToken }

class function TJSPcreMatcher.TPatternToken.Unchanged(const SourceLength: Integer): TPatternToken;
begin
  Result.IsRewritten := False;
  Result.Replacement := '';
  Result.SourceLength := SourceLength;
end;

class function TJSPcreMatcher.TPatternToken.Rewritten(const Replacement: string;
                                                      const SourceLength: Integer): TPatternToken;
begin
  Result.IsRewritten := True;
  Result.Replacement := Replacement;
  Result.SourceLength := SourceLength;
end;

{ TJSPcreMatcher }

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
    if not TJSAsciiDigits.IsDigit(Letter) then
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
  begin
    Result := IntToStr(MAX_QUANTIFIER_BOUND);
    Exit;
  end;

  Result := Significant;
end;

class function TJSPcreMatcher.TryClampQuantifier(const Pattern: string; const OpenIndex: Integer;
                                                 out Token: TPatternToken): Boolean;
begin
  Token := TPatternToken.Unchanged(1);

  const CloseIndex = Pattern.IndexOf(QUANTIFIER_CLOSE, OpenIndex);
  const HasClose = (CloseIndex >= 0);
  if not HasClose then
    Exit(False);

  const Bounds = Pattern.Substring(OpenIndex + 1, CloseIndex - OpenIndex - 1).Split([BOUND_SEPARATOR]);
  const HasUpperBound = (Length(Bounds) = 2);
  const IsBoundsCountValid = (Length(Bounds) in [1, 2]);
  if not (IsBoundsCountValid and IsDigits(Bounds[0])) then
    Exit(False);

  const IsUpperBoundValid = (not HasUpperBound) or Bounds[1].IsEmpty or IsDigits(Bounds[1]);
  if not IsUpperBoundValid then
    Exit(False);

  var Quantifier: string;
  if HasUpperBound then
    Quantifier := Format('%s%s%s%s%s', [QUANTIFIER_OPEN, ClampBound(Bounds[0]), BOUND_SEPARATOR,
                                        ClampBound(Bounds[1]), QUANTIFIER_CLOSE])
  else
    Quantifier := Format('%s%s%s', [QUANTIFIER_OPEN, ClampBound(Bounds[0]), QUANTIFIER_CLOSE]);

  Token := TPatternToken.Rewritten(Quantifier, CloseIndex - OpenIndex + 1);
  Result := True;
end;

class function TJSPcreMatcher.NextToken(const Pattern: string; const Index: Integer;
                                        const InsideClass: Boolean): TPatternToken;
begin
  const Current = Pattern.Chars[Index];

  const IsEscape = (Current = BACKSLASH) and (Index + 1 < Pattern.Length);
  if IsEscape then
  begin
    Result := TPatternToken.Unchanged(ESCAPE_LENGTH);
    Exit;
  end;

  const IsQuantifierStart = (not InsideClass) and (Current = QUANTIFIER_OPEN);
  if IsQuantifierStart and TryClampQuantifier(Pattern, Index, Result) then
    Exit;

  Result := TPatternToken.Unchanged(1);
end;

class function TJSPcreMatcher.ClampQuantifierBounds(const Pattern: string): string;
begin
  const Clamped = TStringBuilder.Create;
  try
    var Index := 0;
    var InsideClass := False;

    while Index < Pattern.Length do
    begin
      const Token = NextToken(Pattern, Index, InsideClass);
      if Token.IsRewritten then
        Clamped.Append(Token.Replacement)
      else
        Clamped.Append(Pattern, Index, Token.SourceLength);

      InsideClass := TJSRegExpCharacters.NextClassState(Pattern.Chars[Index], InsideClass);
      Inc(Index, Token.SourceLength);
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
    raise TJSErrorFactory.InvalidRegExp(FPattern, TJSSourcePosition.Unknown);

  pcre_fullinfo(FCode, nil, PCRE_INFO_CAPTURECOUNT, @FCaptureCount);

  SetLength(FOffsets, (FCaptureCount + 1) * PCRE_VECTOR_ENTRIES_PER_GROUP);
end;

class function TJSPcreMatcher.RecursionLimit: Cardinal;
begin
  const Remaining = TJSStackGuard.RemainingBytes;
  const HasNoSpareStack = (Remaining <= RECURSION_STACK_RESERVE);
  if HasNoSpareStack then
    Exit(MIN_RECURSION_DEPTH);

  const Depth = (Remaining - RECURSION_STACK_RESERVE) div ESTIMATED_RECURSION_FRAME_BYTES;
  const ExceedsMaximum = (Depth > MAX_RECURSION_DEPTH);
  if ExceedsMaximum then
    Result := MAX_RECURSION_DEPTH
  else
    Result := Cardinal(Depth);
end;

procedure TJSPcreMatcher.ResetOffsets;
begin
  FillChar(FOffsets[0], Length(FOffsets) * SizeOf(Integer), UNSET_OFFSET_BYTE);
end;

function TJSPcreMatcher.ExecuteMatch(const Subject: string; const Start: Integer;
                                     const ExecOptions: Integer): Integer;
begin
  var MatchLimits := Default(TPCREExtra);
  MatchLimits.flags := PCRE_EXTRA_MATCH_LIMIT or PCRE_EXTRA_MATCH_LIMIT_RECURSION;
  MatchLimits.match_limit := MAX_MATCH_STEPS;
  MatchLimits.match_limit_recursion := RecursionLimit;

  Result := pcre_exec(FCode, @MatchLimits, PCRE_STR(Subject), Length(Subject), Start,
                      PCRE_NO_UTF8_CHECK or ExecOptions, @FOffsets[0], Length(FOffsets));
end;

function TJSPcreMatcher.IsMatchResult(const Executed: Integer): Boolean;
begin
  const HasMatched = (Executed >= 0);
  if HasMatched then
    Exit(True);

  const HasNoMatch = (Executed = PCRE_ERROR_NOMATCH) or (Executed = PCRE_ERROR_BADOFFSET);
  if HasNoMatch then
    Exit(False);

  case Executed of
    PCRE_ERROR_RECURSIONLIMIT : raise TJSErrorFactory.StackExhausted;
    PCRE_ERROR_MATCHLIMIT     : raise TJSErrorFactory.RangeError(MATCH_LIMIT_MESSAGE);
  else
    raise EJSInternalError.CreateFmt(PCRE_FAILURE_MESSAGE, [Executed]);
  end;
end;

function TJSPcreMatcher.TryExecute(const Subject: string; const Start: Integer;
                                   const ExecOptions: Integer): Boolean;
begin
  EnsureCompiled;
  ResetOffsets;

  const Executed = ExecuteMatch(Subject, Start, ExecOptions);

  Result := IsMatchResult(Executed);
end;

function TJSPcreMatcher.TryMatch(const Subject: string; const Start: Integer): Boolean;
begin
  Result := TryExecute(Subject, Start, 0);
end;

function TJSPcreMatcher.TryMatchAtStart(const Subject: string; const Start: Integer): Boolean;
begin
  Result := TryExecute(Subject, Start, PCRE_ANCHORED);
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
