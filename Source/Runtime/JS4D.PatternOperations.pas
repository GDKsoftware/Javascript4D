unit JS4D.PatternOperations;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types;

type
  TJSPatternOperations = class
  private
    class function CollectMatches(const Str: string; const Pattern: IJSRegExp): TArray<TJSRegExpMatch>; static;
    class function IsTemplateDigit(const Text: string; const Position: Integer): Boolean; static;
    class function TryParseGroupNumber(const Text: string; const Position: Integer; const GroupCount: Integer;
                                    out Number: Integer; out Consumed: Integer): Boolean; static;
    class function ExpandTemplate(const Template: string; const Str: string; const Found: TJSRegExpMatch): string; static;
    class function ReplacementFor(const Str: string; const Found: TJSRegExpMatch; const ReplaceValue: TJSValue;
                                  const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function BuildReplaced(const Str: string; const Matches: TArray<TJSRegExpMatch>; const ReplaceValue: TJSValue;
                                 const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function CallReplacer(const Func: IJSFunction; const Str: string; const Found: TJSRegExpMatch;
                                const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;

  public
    class function Replace(const Str: string; const Pattern: IJSRegExp; const ReplaceValue: TJSValue;
                           const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function ReplaceText(const Str: string; const SearchText: string; const ReplaceValue: TJSValue;
                               const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string; static;
    class function Split(const Str: string; const Pattern: IJSRegExp; const Limit: Int64;
                         const Limits: TJSLimits): IJSArray; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

const
  DOLLAR = '$';
  MAX_GROUP_DIGITS = 2;

class function TJSPatternOperations.CollectMatches(const Str: string; const Pattern: IJSRegExp): TArray<TJSRegExpMatch>;
begin
  Result := nil;

  if not Pattern.Global then
  begin
    const Found = Pattern.MatchAt(Str, 0);
    if Found.Found then
      Result := [Found]
    else
      Pattern.LastIndex := 0;

    Exit;
  end;

  Pattern.LastIndex := 0;

  var Position := 0;
  while Position <= Length(Str) do
  begin
    const Found = Pattern.MatchAt(Str, Position);
    if not Found.Found then
      Break;

    Result := Result + [Found];

    Position := Found.Index + Found.Length;
    const IsEmptyMatch = (Found.Length = 0);
    if IsEmptyMatch then
      Inc(Position);
  end;
end;

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

class function TJSPatternOperations.ExpandTemplate(const Template: string; const Str: string;
                                                   const Found: TJSRegExpMatch): string;
begin
  var Builder := TStringBuilder.Create;
  try
    var Position := 1;
    while Position <= Length(Template) do
    begin
      const Current = Template[Position];
      const HasNext = (Position < Length(Template));
      if (Current <> DOLLAR) or (not HasNext) then
      begin
        Builder.Append(Current);
        Inc(Position);
        Continue;
      end;

      const Selector = Template[Position + 1];
      var GroupNumber: Integer;
      var DigitCount: Integer;

      if Selector = DOLLAR then
      begin
        Builder.Append(DOLLAR);
        Inc(Position, 2);
      end
      else if Selector = '&' then
      begin
        Builder.Append(Copy(Str, Found.Index + 1, Found.Length));
        Inc(Position, 2);
      end
      else if Selector = '`' then
      begin
        Builder.Append(Copy(Str, 1, Found.Index));
        Inc(Position, 2);
      end
      else if Selector = '''' then
      begin
        Builder.Append(Copy(Str, Found.Index + Found.Length + 1, MaxInt));
        Inc(Position, 2);
      end
      else if TryParseGroupNumber(Template, Position + 1, Length(Found.Captures), GroupNumber, DigitCount) then
      begin
        const Capture = Found.Captures[GroupNumber - 1];
        if not Capture.IsUndefined then
          Builder.Append(Capture.ToString);

        Inc(Position, 1 + DigitCount);
      end
      else
      begin
        Builder.Append(Current);
        Inc(Position);
      end;
    end;

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSPatternOperations.CallReplacer(const Func: IJSFunction; const Str: string;
                                                 const Found: TJSRegExpMatch; const Executor: TJSCallbackExecutor;
                                                 const Limits: TJSLimits): string;
begin
  const MatchedText = Copy(Str, Found.Index + 1, Found.Length);
  var CallArgs: TArray<TJSValue> := [TJSValue.CreateString(MatchedText)];
  CallArgs := CallArgs + Found.Captures;
  CallArgs := CallArgs + [TJSValue.CreateNumber(Found.Index), TJSValue.CreateString(Str)];

  const Returned = Executor(Func, CallArgs);

  Result := Returned.ToLimitedString(Limits);
end;

class function TJSPatternOperations.ReplacementFor(const Str: string; const Found: TJSRegExpMatch;
                                                   const ReplaceValue: TJSValue; const Executor: TJSCallbackExecutor;
                                                   const Limits: TJSLimits): string;
begin
  var Func: IJSFunction;
  const IsCallback = ReplaceValue.IsFunction and Supports(ReplaceValue.ToObject, IJSFunction, Func);
  if IsCallback then
    Exit(CallReplacer(Func, Str, Found, Executor, Limits));

  Result := ExpandTemplate(ReplaceValue.ToLimitedString(Limits), Str, Found);
end;

class function TJSPatternOperations.BuildReplaced(const Str: string; const Matches: TArray<TJSRegExpMatch>;
                                                  const ReplaceValue: TJSValue; const Executor: TJSCallbackExecutor;
                                                  const Limits: TJSLimits): string;
begin
  var Builder := TStringBuilder.Create;
  try
    var Copied := 0;
    for var Found in Matches do
    begin
      Builder.Append(Copy(Str, Copied + 1, Found.Index - Copied));
      Builder.Append(ReplacementFor(Str, Found, ReplaceValue, Executor, Limits));
      Limits.EnsureStringLength(Builder.Length);

      Copied := Found.Index + Found.Length;
    end;

    Builder.Append(Copy(Str, Copied + 1, MaxInt));
    Limits.EnsureStringLength(Builder.Length);

    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

class function TJSPatternOperations.Replace(const Str: string; const Pattern: IJSRegExp; const ReplaceValue: TJSValue;
                                            const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string;
begin
  const Matches = CollectMatches(Str, Pattern);

  Result := BuildReplaced(Str, Matches, ReplaceValue, Executor, Limits);
end;

class function TJSPatternOperations.ReplaceText(const Str: string; const SearchText: string; const ReplaceValue: TJSValue;
                                                const Executor: TJSCallbackExecutor; const Limits: TJSLimits): string;
begin
  const Position = Pos(SearchText, Str);
  if Position = 0 then
    Exit(Str);

  var Found := Default(TJSRegExpMatch);
  Found.Found := True;
  Found.Index := Position - 1;
  Found.Length := Length(SearchText);

  Result := BuildReplaced(Str, [Found], ReplaceValue, Executor, Limits);
end;

class function TJSPatternOperations.Split(const Str: string; const Pattern: IJSRegExp; const Limit: Int64;
                                          const Limits: TJSLimits): IJSArray;
begin
  Result := TJSArray.Create;

  if Limit = 0 then
    Exit;

  const Size = Length(Str);
  if Size = 0 then
  begin
    if not Pattern.MatchAt(Str, 0).Found then
      Result.Push(TJSValue.CreateString(Str));

    Exit;
  end;

  var PieceStart := 0;
  var Cursor := 0;

  while Cursor < Size do
  begin
    const Found = Pattern.MatchAt(Str, Cursor);
    const MatchesInside = Found.Found and (Found.Index < Size);
    if not MatchesInside then
      Break;

    const MatchEnd = Min(Found.Index + Found.Length, Size);
    const IsEmptyAtPieceStart = (MatchEnd = PieceStart);
    if IsEmptyAtPieceStart then
    begin
      Cursor := Found.Index + 1;
      Continue;
    end;

    Limits.EnsureArrayLength(Int64(Result.Length) + 1);
    const Piece = Copy(Str, PieceStart + 1, Found.Index - PieceStart);
    Result.Push(TJSValue.CreateString(Piece));
    if Result.Length = Limit then
      Exit;

    for var Capture in Found.Captures do
    begin
      Limits.EnsureArrayLength(Int64(Result.Length) + 1);
      Result.Push(Capture);
      if Result.Length = Limit then
        Exit;
    end;

    PieceStart := MatchEnd;
    Cursor := PieceStart;
  end;

  Limits.EnsureArrayLength(Int64(Result.Length) + 1);
  const LastPiece = Copy(Str, PieceStart + 1, MaxInt);
  Result.Push(TJSValue.CreateString(LastPiece));
end;

end.
