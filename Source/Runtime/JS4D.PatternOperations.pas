unit JS4D.PatternOperations;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.ArrayObject;

type
  TJSPatternOperations = class
  private
    type
      TSubstitutionSource = record
        Subject: string;
        Position: Integer;
        Matched: string;
        Captures: TArray<TJSValue>;
        NamedCaptures: IJSObject;
        Limits: TJSLimits;
      end;

    class function TryAppendMatchSelector(const Builder: TStringBuilder; const Selector: Char;
                                          const Source: TSubstitutionSource): Boolean; static;
    class function IsTemplateDigit(const Text: string; const Position: Integer): Boolean; static;
    class function TryParseGroupNumber(const Text: string; const Position: Integer; const GroupCount: Integer;
                                       out Number: Integer; out Consumed: Integer): Boolean; static;
    class function TryExpandNamedCapture(const Template: string; const Position: Integer;
                                         const NamedCaptures: IJSObject; const Limits: TJSLimits;
                                         out Expansion: string; out Consumed: Integer): Boolean; static;
    class function SourceFor(const Subject: string; const Position: Integer; const Matched: string;
                             const Captures: TArray<TJSValue>; const NamedCaptures: IJSObject;
                             const Limits: TJSLimits): TSubstitutionSource; static;
    class procedure AppendCapture(const Builder: TStringBuilder; const Capture: TJSValue;
                                  const Limits: TJSLimits); static;
    class function TryAppendNamedCapture(const Builder: TStringBuilder; const Template: string;
                                         const Cursor: Integer; const Source: TSubstitutionSource;
                                         out Consumed: Integer): Boolean; static;
    class procedure SplitIntoCharacters(const Subject: string; const Limit: Int64; const Limits: TJSLimits;
                                        const Pieces: IJSArray); static;
    class function TryAppendSubstitution(const Builder: TStringBuilder; const Template: string;
                                         const Cursor: Integer; const Source: TSubstitutionSource;
                                         out Consumed: Integer): Boolean; static;
    class function ReplacementFor(const Subject: string; const Position: Integer; const SearchText: string;
                                  const ReplacementTemplate: string; const ReplacementFunction: IJSFunction;
                                  const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function FindMatchPositions(const Subject: string; const SearchText: string;
                                      const ReplaceAll: Boolean): TArray<Integer>; static;

  public
    class function GetSubstitution(const Template: string; const Subject: string; const Position: Integer;
                                   const Matched: string; const Captures: TArray<TJSValue>;
                                   const NamedCaptures: IJSObject; const Limits: TJSLimits): string; static;
    class function ReplaceText(const Subject: string; const SearchText: string; const ReplacementTemplate: string;
                               const ReplacementFunction: IJSFunction; const ReplaceAll: Boolean;
                               const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function SplitText(const Subject: string; const Separator: string; const Limit: Int64;
                             const Limits: TJSLimits): IJSArray; static;
  end;

implementation

uses
  System.Math,
  System.Generics.Collections,
  JS4D.Conversions;

const
  DOLLAR = '$';
  AMPERSAND = '&';
  BACKTICK = '`';
  APOSTROPHE = '''';
  NAMED_CAPTURE_START = '<';
  NAMED_CAPTURE_END = '>';
  MAX_GROUP_DIGITS = 2;

class function TJSPatternOperations.IsTemplateDigit(const Text: string; const Position: Integer): Boolean;
begin
  Result := (Position <= Length(Text)) and CharInSet(Text[Position], ['0'..'9']);
end;

class function TJSPatternOperations.TryParseGroupNumber(const Text: string; const Position: Integer;
                                                        const GroupCount: Integer; out Number: Integer;
                                                        out Consumed: Integer): Boolean;
begin
  Number := 0;
  Consumed := 0;
  Result := False;

  if not IsTemplateDigit(Text, Position) then
    Exit;

  const FirstDigit = Ord(Text[Position]) - Ord('0');

  if IsTemplateDigit(Text, Position + 1) then
  begin
    const SecondDigit = Ord(Text[Position + 1]) - Ord('0');
    const TwoDigits = FirstDigit * 10 + SecondDigit;
    const IsTwoDigitGroup = (TwoDigits >= 1) and (TwoDigits <= GroupCount);
    if IsTwoDigitGroup then
    begin
      Number := TwoDigits;
      Consumed := MAX_GROUP_DIGITS;
      Exit(True);
    end;
  end;

  const IsOneDigitGroup = (FirstDigit >= 1) and (FirstDigit <= GroupCount);
  if IsOneDigitGroup then
  begin
    Number := FirstDigit;
    Consumed := 1;
    Result := True;
  end;
end;

class function TJSPatternOperations.TryExpandNamedCapture(const Template: string; const Position: Integer;
                                                          const NamedCaptures: IJSObject; const Limits: TJSLimits;
                                                          out Expansion: string; out Consumed: Integer): Boolean;
begin
  Expansion := '';
  Consumed := 0;

  const NameStart = Position + 2;
  const NameEnd = Pos(NAMED_CAPTURE_END, Template, NameStart);
  const IsComplete = Assigned(NamedCaptures) and (NameEnd > 0);
  if not IsComplete then
    Exit(False);

  const CaptureName = Copy(Template, NameStart, NameEnd - NameStart);
  const Capture = NamedCaptures.GetProperty(CaptureName);
  if not Capture.IsUndefined then
    Expansion := TJSConversions.ToText(Capture, Limits);

  Consumed := NameEnd - Position + 1;
  Result := True;
end;

class function TJSPatternOperations.TryAppendMatchSelector(const Builder: TStringBuilder; const Selector: Char;
                                                           const Source: TSubstitutionSource): Boolean;
begin
  Result := True;

  case Selector of
    DOLLAR     : Builder.Append(DOLLAR);
    AMPERSAND  : Builder.Append(Source.Matched);
    BACKTICK   :
      begin
        const Before = Copy(Source.Subject, 1, Source.Position);

        Builder.Append(Before);
      end;
    APOSTROPHE :
      begin
        const AfterStart = Source.Position + Length(Source.Matched) + 1;
        const After = Copy(Source.Subject, AfterStart, MaxInt);

        Builder.Append(After);
      end;
  else
    Result := False;
  end;
end;

class function TJSPatternOperations.TryAppendSubstitution(const Builder: TStringBuilder; const Template: string;
                                                          const Cursor: Integer; const Source: TSubstitutionSource;
                                                          out Consumed: Integer): Boolean;
begin
  Result := True;
  Consumed := 0;

  const Selector = Template[Cursor + 1];
  if TryAppendMatchSelector(Builder, Selector, Source) then
  begin
    Consumed := 2;
    Exit;
  end;

  var GroupNumber: Integer;
  var DigitCount: Integer;
  if TryParseGroupNumber(Template, Cursor + 1, Length(Source.Captures), GroupNumber, DigitCount) then
  begin
    AppendCapture(Builder, Source.Captures[GroupNumber - 1], Source.Limits);
    Consumed := 1 + DigitCount;
    Exit;
  end;

  Result := TryAppendNamedCapture(Builder, Template, Cursor, Source, Consumed);
end;

class function TJSPatternOperations.SourceFor(const Subject: string; const Position: Integer;
                                              const Matched: string; const Captures: TArray<TJSValue>;
                                              const NamedCaptures: IJSObject;
                                              const Limits: TJSLimits): TSubstitutionSource;
begin
  Result.Subject := Subject;
  Result.Position := Position;
  Result.Matched := Matched;
  Result.Captures := Captures;
  Result.NamedCaptures := NamedCaptures;
  Result.Limits := Limits;
end;

class procedure TJSPatternOperations.AppendCapture(const Builder: TStringBuilder; const Capture: TJSValue;
                                                   const Limits: TJSLimits);
begin
  if Capture.IsUndefined then
    Exit;

  const CaptureText = TJSConversions.ToText(Capture, Limits);

  Builder.Append(CaptureText);
end;

class function TJSPatternOperations.TryAppendNamedCapture(const Builder: TStringBuilder; const Template: string;
                                                          const Cursor: Integer; const Source: TSubstitutionSource;
                                                          out Consumed: Integer): Boolean;
begin
  Consumed := 0;
  Result := False;

  const Selector = Template[Cursor + 1];
  const StartsNamedCapture = (Selector = NAMED_CAPTURE_START);
  if not StartsNamedCapture then
    Exit;

  var Expansion: string;
  if not TryExpandNamedCapture(Template, Cursor, Source.NamedCaptures, Source.Limits, Expansion, Consumed) then
    Exit;

  Builder.Append(Expansion);
  Result := True;
end;

class function TJSPatternOperations.GetSubstitution(const Template: string; const Subject: string;
                                                    const Position: Integer; const Matched: string;
                                                    const Captures: TArray<TJSValue>;
                                                    const NamedCaptures: IJSObject;
                                                    const Limits: TJSLimits): string;
begin
  const Source = SourceFor(Subject, Position, Matched, Captures, NamedCaptures, Limits);

  var Builder := TStringBuilder.Create;
  try
    var Cursor := 1;
    while Cursor <= Length(Template) do
    begin
      const Current = Template[Cursor];
      const HasNext = (Cursor < Length(Template));
      const StartsEscape = (Current = DOLLAR) and HasNext;
      if not StartsEscape then
      begin
        Builder.Append(Current);
        Inc(Cursor);
        Continue;
      end;

      var Consumed: Integer;
      const IsSubstituted = TryAppendSubstitution(Builder, Template, Cursor, Source, Consumed);
      if not IsSubstituted then
      begin
        Builder.Append(Current);
        Consumed := 1;
      end;

      Inc(Cursor, Consumed);
      Limits.EnsureStringLength(Builder.Length);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSPatternOperations.ReplacementFor(const Subject: string; const Position: Integer;
                                                   const SearchText: string; const ReplacementTemplate: string;
                                                   const ReplacementFunction: IJSFunction;
                                                   const Executor: TJSCallbackExecutor;
                                                   const Limits: TJSLimits): string;
begin
  if Assigned(ReplacementFunction) then
  begin
    const MatchedValue = TJSValue.CreateString(SearchText);
    const PositionValue = TJSValue.CreateNumber(Position);
    const SubjectValue = TJSValue.CreateString(Subject);
    const CallArgs: TArray<TJSValue> = [MatchedValue, PositionValue, SubjectValue];
    const Returned = Executor(ReplacementFunction, CallArgs);

    Result := TJSConversions.ToText(Returned, Limits);
    Exit;
  end;

  Result := GetSubstitution(ReplacementTemplate, Subject, Position, SearchText, nil, nil, Limits);
end;

class function TJSPatternOperations.FindMatchPositions(const Subject: string; const SearchText: string;
                                                       const ReplaceAll: Boolean): TArray<Integer>;
begin
  const Positions = TList<Integer>.Create;
  try
    const IsEmptySearch = SearchText.IsEmpty;
    if IsEmptySearch then
    begin
      const LastPosition = IfThen(ReplaceAll, Length(Subject), 0);
      for var Position := 0 to LastPosition do
      begin
        Positions.Add(Position);
      end;

      Result := Positions.ToArray;
      Exit;
    end;

    var Found := Pos(SearchText, Subject);
    var HasFound := (Found > 0);
    while HasFound do
    begin
      Positions.Add(Found - 1);
      if not ReplaceAll then
        Break;

      const NextStart = Found + Length(SearchText);
      Found := Pos(SearchText, Subject, NextStart);
      HasFound := (Found > 0);
    end;

    Result := Positions.ToArray;
  finally
    Positions.Free;
  end;
end;

class function TJSPatternOperations.ReplaceText(const Subject: string; const SearchText: string;
                                                const ReplacementTemplate: string;
                                                const ReplacementFunction: IJSFunction; const ReplaceAll: Boolean;
                                                const Executor: TJSCallbackExecutor;
                                                const Limits: TJSLimits): string;
begin
  const Positions = FindMatchPositions(Subject, SearchText, ReplaceAll);

  var Builder := TStringBuilder.Create;
  try
    var Copied := 0;
    for var Position in Positions do
    begin
      const Skipped = Copy(Subject, Copied + 1, Position - Copied);
      const Replacement = ReplacementFor(Subject, Position, SearchText, ReplacementTemplate, ReplacementFunction,
                                         Executor, Limits);

      Builder.Append(Skipped);
      Builder.Append(Replacement);
      Limits.EnsureStringLength(Builder.Length);

      Copied := Position + Length(SearchText);
    end;

    const Remainder = Copy(Subject, Copied + 1, MaxInt);

    Builder.Append(Remainder);
    Limits.EnsureStringLength(Builder.Length);

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class procedure TJSPatternOperations.SplitIntoCharacters(const Subject: string; const Limit: Int64;
                                                         const Limits: TJSLimits; const Pieces: IJSArray);
begin
  const PartCount = Min(Length(Subject), Limit);
  Limits.EnsureArrayLength(PartCount);

  for var Index := 1 to PartCount do
  begin
    const Character = TJSValue.CreateString(Subject[Index]);

    Pieces.Push(Character);
  end;
end;

class function TJSPatternOperations.SplitText(const Subject: string; const Separator: string; const Limit: Int64;
                                              const Limits: TJSLimits): IJSArray;
begin
  Result := TJSArray.Create;

  const IsLimitZero = (Limit = 0);
  if IsLimitZero then
    Exit;

  if Separator.IsEmpty then
  begin
    SplitIntoCharacters(Subject, Limit, Limits, Result);
    Exit;
  end;

  var PieceStart := 1;
  while Result.Length < Limit do
  begin
    const NextPosition = Pos(Separator, Subject, PieceStart);

    const NextLength = Int64(Result.Length) + 1;
    Limits.EnsureArrayLength(NextLength);

    const IsLastPiece = (NextPosition = 0);
    if IsLastPiece then
    begin
      const LastPiece = Copy(Subject, PieceStart, MaxInt);
      const LastValue = TJSValue.CreateString(LastPiece);

      Result.Push(LastValue);
      Break;
    end;

    const Piece = Copy(Subject, PieceStart, NextPosition - PieceStart);
    const PieceValue = TJSValue.CreateString(Piece);

    Result.Push(PieceValue);
    PieceStart := NextPosition + Length(Separator);
  end;
end;

end.
