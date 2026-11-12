unit JS4D.PatternOperations;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.PropertyKey,
  JS4D.Types;

type
  TJSPatternOperations = class
  private
    class function IsTemplateDigit(const Text: string; const Position: Integer): Boolean; static;
    class function TryParseGroupNumber(const Text: string; const Position: Integer; const GroupCount: Integer;
                                       out Number: Integer; out Consumed: Integer): Boolean; static;
    class function TryExpandNamedCapture(const Template: string; const Position: Integer;
                                         const NamedCaptures: IJSObject; const Limits: TJSLimits;
                                         out Expansion: string; out Consumed: Integer): Boolean; static;
    class function ReplacementFor(const Str: string; const Position: Integer; const SearchText: string;
                                  const ReplaceValue: TJSValue; const Executor: TJSCallbackExecutor;
                                  const Limits: TJSLimits): string; static;
    class function FindMatchPositions(const Str: string; const SearchText: string;
                                      const ReplaceAll: Boolean): TArray<Integer>; static;

  public
    class function GetSubstitution(const Template: string; const Str: string; const Position: Integer;
                                   const Matched: string; const Captures: TArray<TJSValue>;
                                   const NamedCaptures: IJSObject; const Limits: TJSLimits): string; static;
    class function ReplaceText(const Str: string; const SearchText: string; const ReplaceValue: TJSValue;
                               const ReplaceAll: Boolean; const Executor: TJSCallbackExecutor;
                               const Limits: TJSLimits): string; static;
    class function SplitText(const Str: string; const Separator: string; const Limit: Int64;
                             const Limits: TJSLimits): IJSArray; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  JS4D.Conversions;

const
  DOLLAR = '$';
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
    const TwoDigits = FirstDigit * 10 + (Ord(Text[Position + 1]) - Ord('0'));
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

class function TJSPatternOperations.GetSubstitution(const Template: string; const Str: string; const Position: Integer;
                                                    const Matched: string; const Captures: TArray<TJSValue>;
                                                    const NamedCaptures: IJSObject;
                                                    const Limits: TJSLimits): string;
begin
  var Builder := TStringBuilder.Create;
  try
    var Cursor := 1;
    while Cursor <= Length(Template) do
    begin
      const Current = Template[Cursor];
      const HasNext = (Cursor < Length(Template));
      if (Current <> DOLLAR) or (not HasNext) then
      begin
        Builder.Append(Current);
        Inc(Cursor);
        Continue;
      end;

      const Selector = Template[Cursor + 1];
      var GroupNumber: Integer;
      var Consumed: Integer;
      var Expansion: string;

      if Selector = DOLLAR then
      begin
        Builder.Append(DOLLAR);
        Inc(Cursor, 2);
      end
      else if Selector = '&' then
      begin
        Builder.Append(Matched);
        Inc(Cursor, 2);
      end
      else if Selector = '`' then
      begin
        Builder.Append(Copy(Str, 1, Position));
        Inc(Cursor, 2);
      end
      else if Selector = '''' then
      begin
        Builder.Append(Copy(Str, Position + Length(Matched) + 1, MaxInt));
        Inc(Cursor, 2);
      end
      else if TryParseGroupNumber(Template, Cursor + 1, Length(Captures), GroupNumber, Consumed) then
      begin
        const Capture = Captures[GroupNumber - 1];
        if not Capture.IsUndefined then
          Builder.Append(TJSConversions.ToText(Capture, Limits));

        Inc(Cursor, 1 + Consumed);
      end
      else if (Selector = NAMED_CAPTURE_START) and
              TryExpandNamedCapture(Template, Cursor, NamedCaptures, Limits, Expansion, Consumed) then
      begin
        Builder.Append(Expansion);
        Inc(Cursor, Consumed);
      end
      else
      begin
        Builder.Append(Current);
        Inc(Cursor);
      end;

      Limits.EnsureStringLength(Builder.Length);
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSPatternOperations.ReplacementFor(const Str: string; const Position: Integer;
                                                   const SearchText: string; const ReplaceValue: TJSValue;
                                                   const Executor: TJSCallbackExecutor;
                                                   const Limits: TJSLimits): string;
begin
  const Func = TJSConversions.AsFunction(ReplaceValue);
  if Assigned(Func) then
  begin
    const CallArgs: TArray<TJSValue> = [TJSValue.CreateString(SearchText), TJSValue.CreateNumber(Position),
                                        TJSValue.CreateString(Str)];

    Exit(TJSConversions.ToText(Executor(Func, CallArgs), Limits));
  end;

  Result := GetSubstitution(ReplaceValue.AsString, Str, Position, SearchText, nil, nil, Limits);
end;

class function TJSPatternOperations.FindMatchPositions(const Str: string; const SearchText: string;
                                                       const ReplaceAll: Boolean): TArray<Integer>;
begin
  Result := nil;

  const IsEmptySearch = SearchText.IsEmpty;
  if IsEmptySearch then
  begin
    const LastPosition = IfThen(ReplaceAll, Length(Str), 0);
    for var Position := 0 to LastPosition do
    begin
      Result := Result + [Position];
    end;

    Exit;
  end;

  var Found := Pos(SearchText, Str);
  while Found > 0 do
  begin
    Result := Result + [Found - 1];
    if not ReplaceAll then
      Break;

    Found := Pos(SearchText, Str, Found + Length(SearchText));
  end;
end;

class function TJSPatternOperations.ReplaceText(const Str: string; const SearchText: string;
                                                const ReplaceValue: TJSValue; const ReplaceAll: Boolean;
                                                const Executor: TJSCallbackExecutor;
                                                const Limits: TJSLimits): string;
begin
  const Positions = FindMatchPositions(Str, SearchText, ReplaceAll);

  var Builder := TStringBuilder.Create;
  try
    var Copied := 0;
    for var Position in Positions do
    begin
      Builder.Append(Copy(Str, Copied + 1, Position - Copied));
      Builder.Append(ReplacementFor(Str, Position, SearchText, ReplaceValue, Executor, Limits));
      Limits.EnsureStringLength(Builder.Length);

      Copied := Position + Length(SearchText);
    end;

    Builder.Append(Copy(Str, Copied + 1, MaxInt));
    Limits.EnsureStringLength(Builder.Length);

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSPatternOperations.SplitText(const Str: string; const Separator: string; const Limit: Int64;
                                              const Limits: TJSLimits): IJSArray;
begin
  Result := TJSArray.Create;

  if Limit = 0 then
    Exit;

  if Separator.IsEmpty then
  begin
    const PartCount = Min(Length(Str), Limit);
    Limits.EnsureArrayLength(PartCount);

    for var Index := 1 to PartCount do
    begin
      Result.Push(TJSValue.CreateString(Str[Index]));
    end;

    Exit;
  end;

  var PieceStart := 1;
  while Result.Length < Limit do
  begin
    const NextPosition = Pos(Separator, Str, PieceStart);

    Limits.EnsureArrayLength(Int64(Result.Length) + 1);

    if NextPosition = 0 then
    begin
      Result.Push(TJSValue.CreateString(Copy(Str, PieceStart, MaxInt)));
      Break;
    end;

    Result.Push(TJSValue.CreateString(Copy(Str, PieceStart, NextPosition - PieceStart)));
    PieceStart := NextPosition + Length(Separator);
  end;
end;

end.
