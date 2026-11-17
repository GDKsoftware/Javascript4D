unit JS4D.StringPatternMethods;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.BuiltinSet,
  JS4D.BuiltinSupport,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.RegExpObject,
  JS4D.ArrayObject,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSStringPatternMethods = class(TJSBuiltinSet)
  private
    const
      MATCH_NAME = 'match';
      REPLACE_NAME = 'replace';
      REPLACE_ALL_NAME = 'replaceAll';
      SEARCH_NAME = 'search';
      SPLIT_NAME = 'split';
      CALLED_ON_NULL_OR_UNDEFINED = 'String.prototype.%s called on null or undefined';
      REPLACE_ALL_NEEDS_GLOBAL = 'replaceAll must be called with a global RegExp';
      NULL_FLAGS = 'The flags of a regular expression must not be null or undefined';

    var
      FInterpreter: TJSInterpreter;
      FSupport: TJSBuiltinSupport;

    class function ReplaceMethodName(const ReplaceAll: Boolean): string; static;

    function ThisValueOf(const This: IJSObject; const MethodName: string): TJSValue;
    function ToText(const Value: TJSValue): string;
    function TryDelegateTo(const SearchValue: TJSValue; const Key: TJSPropertyKey; const Subject: TJSValue;
                           const Rest: TArray<TJSValue>; out Delegated: TJSValue): Boolean;
    procedure RequireGlobalFlags(const SearchValue: TJSValue);
    function InvokeOnNewRegExp(const Key: TJSPropertyKey; const Pattern: TJSValue; const Text: string): TJSValue;
    function MatchOrSearch(const This: IJSObject; const Args: TArray<TJSValue>; const MethodName: string;
                           const Which: TJSWellKnownSymbol): TJSValue;
    function ReplaceInText(const Subject: TJSValue; const SearchValue: TJSValue; const ReplaceValue: TJSValue;
                           const ReplaceAll: Boolean): TJSValue;
    function Replace(const This: IJSObject; const Args: TArray<TJSValue>; const ReplaceAll: Boolean): TJSValue;
    function SplitLimit(const LimitValue: TJSValue): Int64;
    function SplitInText(const Subject: TJSValue; const Separator: TJSValue; const LimitValue: TJSValue): TJSValue;
    function Split(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    procedure DefineMatchOrSearch(const Target: IJSObject; const Name: string; const Which: TJSWellKnownSymbol);
    procedure DefineReplace(const Target: IJSObject; const Name: string; const ReplaceAll: Boolean);
    procedure DefineSplit(const Target: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register; override;
  end;

implementation

uses
  JS4D.ArrayLike,
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.PropertyNames,
  JS4D.RegExpSyntax,
  JS4D.PatternOperations;

constructor TJSStringPatternMethods.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FSupport := TJSBuiltinSupport.Create(Interpreter);
end;

destructor TJSStringPatternMethods.Destroy;
begin
  FSupport.Free;

  inherited;
end;

class function TJSStringPatternMethods.ReplaceMethodName(const ReplaceAll: Boolean): string;
begin
  if ReplaceAll then
    Exit(REPLACE_ALL_NAME);

  Result := REPLACE_NAME;
end;

function TJSStringPatternMethods.ThisValueOf(const This: IJSObject; const MethodName: string): TJSValue;
begin
  if not Assigned(This) then
  begin
    const Message = Format(CALLED_ON_NULL_OR_UNDEFINED, [MethodName]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  var Wrapper: IJSPrimitiveWrapper;
  if Supports(This, IJSPrimitiveWrapper, Wrapper) then
    Exit(Wrapper.Primitive);

  Result := TJSValue.CreateObject(This);
end;

function TJSStringPatternMethods.ToText(const Value: TJSValue): string;
begin
  Result := TJSConversions.ToText(Value, FInterpreter.Limits);
end;

function TJSStringPatternMethods.TryDelegateTo(const SearchValue: TJSValue; const Key: TJSPropertyKey;
                                               const Subject: TJSValue; const Rest: TArray<TJSValue>;
                                               out Delegated: TJSValue): Boolean;
begin
  Delegated := TJSValue.CreateUndefined;
  Result := False;

  if not SearchValue.IsObject then
    Exit;

  const Method = TJSConversions.FindMethod(SearchValue, Key);
  if not Assigned(Method) then
    Exit;

  const MethodArguments = [Subject] + Rest;
  Delegated := Method.Call(SearchValue.ToObject, MethodArguments);
  Result := True;
end;

procedure TJSStringPatternMethods.RequireGlobalFlags(const SearchValue: TJSValue);
begin
  if not TJSConversions.IsRegExpLike(SearchValue) then
    Exit;

  const Flags = SearchValue.ToObject.GetProperty(FLAGS_PROPERTY);
  if Flags.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_FLAGS);

  const FlagsText = ToText(Flags);
  const IsGlobal = TJSRegExpFlags.Includes(FlagsText, TJSRegExpFlags.GLOBAL);
  if not IsGlobal then
    raise TJSErrorFactory.TypeError(REPLACE_ALL_NEEDS_GLOBAL);
end;

function TJSStringPatternMethods.InvokeOnNewRegExp(const Key: TJSPropertyKey; const Pattern: TJSValue;
                                                   const Text: string): TJSValue;
begin
  var PatternText := '';
  if not Pattern.IsUndefined then
    PatternText := ToText(Pattern);

  const NewRegExp: IJSRegExp = TJSRegExp.Create(PatternText, '');
  NewRegExp.Prototype := FInterpreter.RegExpPrototype;

  const RegExpValue = TJSValue.CreateObject(NewRegExp);
  const Method = TJSConversions.FindMethod(RegExpValue, Key);
  if not Assigned(Method) then
  begin
    const Message = Format(CALLED_ON_NULL_OR_UNDEFINED, [Key.Text]);
    raise TJSErrorFactory.TypeError(Message);
  end;

  const TextValue = TJSValue.CreateString(Text);

  Result := Method.Call(NewRegExp, [TextValue]);
end;

function TJSStringPatternMethods.MatchOrSearch(const This: IJSObject; const Args: TArray<TJSValue>;
                                               const MethodName: string; const Which: TJSWellKnownSymbol): TJSValue;
begin
  const Subject = ThisValueOf(This, MethodName);
  const Pattern = TJSArrayLike.Argument(Args, 0);
  const Key = TJSSymbolRegistry.WellKnownKey(Which);

  var Delegated: TJSValue;
  if TryDelegateTo(Pattern, Key, Subject, nil, Delegated) then
    Exit(Delegated);

  const Text = ToText(Subject);

  Result := InvokeOnNewRegExp(Key, Pattern, Text);
end;

function TJSStringPatternMethods.ReplaceInText(const Subject: TJSValue; const SearchValue: TJSValue;
                                               const ReplaceValue: TJSValue; const ReplaceAll: Boolean): TJSValue;
begin
  const Text = ToText(Subject);
  const SearchText = ToText(SearchValue);

  var ReplacementTemplate := '';
  var ReplacementFunction: IJSFunction := nil;
  if ReplaceValue.IsFunction then
    ReplacementFunction := TJSConversions.AsFunction(ReplaceValue)
  else
    ReplacementTemplate := ToText(ReplaceValue);

  const Executor: TJSCallbackExecutor = FInterpreter.CallWithUndefinedThis;
  const Replaced = TJSPatternOperations.ReplaceText(Text, SearchText, ReplacementTemplate, ReplacementFunction,
                                                    ReplaceAll, Executor, FInterpreter.Limits);

  Result := TJSValue.CreateString(Replaced);
end;

function TJSStringPatternMethods.Replace(const This: IJSObject; const Args: TArray<TJSValue>;
                                         const ReplaceAll: Boolean): TJSValue;
begin
  const MethodName = ReplaceMethodName(ReplaceAll);
  const Subject = ThisValueOf(This, MethodName);
  const SearchValue = TJSArrayLike.Argument(Args, 0);
  const ReplaceValue = TJSArrayLike.Argument(Args, 1);

  const MustBeGlobal = ReplaceAll and SearchValue.IsObject;
  if MustBeGlobal then
    RequireGlobalFlags(SearchValue);

  const ReplaceKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Replace);
  var Delegated: TJSValue;
  if TryDelegateTo(SearchValue, ReplaceKey, Subject, [ReplaceValue], Delegated) then
    Exit(Delegated);

  Result := ReplaceInText(Subject, SearchValue, ReplaceValue, ReplaceAll);
end;

function TJSStringPatternMethods.SplitLimit(const LimitValue: TJSValue): Int64;
begin
  Result := MAX_ARRAY_LENGTH;
  if not LimitValue.IsUndefined then
    Result := TJSConversions.ToUint32(LimitValue);
end;

function TJSStringPatternMethods.SplitInText(const Subject: TJSValue; const Separator: TJSValue;
                                             const LimitValue: TJSValue): TJSValue;
begin
  const Text = ToText(Subject);
  const Limit = SplitLimit(LimitValue);
  const SeparatorText = ToText(Separator);

  const Pieces: IJSArray = TJSArray.Create;
  Result := TJSValue.CreateObject(Pieces);

  const HasNoRoom = (Limit = 0);
  if HasNoRoom then
    Exit;

  if Separator.IsUndefined then
  begin
    const TextValue = TJSValue.CreateString(Text);
    Pieces.Push(TextValue);
    Exit;
  end;

  const SplitPieces = TJSPatternOperations.SplitText(Text, SeparatorText, Limit, FInterpreter.Limits);

  Result := TJSValue.CreateObject(SplitPieces);
end;

function TJSStringPatternMethods.Split(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Subject = ThisValueOf(This, SPLIT_NAME);
  const Separator = TJSArrayLike.Argument(Args, 0);
  const LimitValue = TJSArrayLike.Argument(Args, 1);

  const SplitKey = TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Split);
  var Delegated: TJSValue;
  if TryDelegateTo(Separator, SplitKey, Subject, [LimitValue], Delegated) then
    Exit(Delegated);

  Result := SplitInText(Subject, Separator, LimitValue);
end;

procedure TJSStringPatternMethods.DefineMatchOrSearch(const Target: IJSObject; const Name: string;
                                                      const Which: TJSWellKnownSymbol);
begin
  FSupport.DefineMethod(Target, Name, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := MatchOrSearch(This, Args, Name, Which);
    end);
end;

procedure TJSStringPatternMethods.DefineReplace(const Target: IJSObject; const Name: string;
                                                const ReplaceAll: Boolean);
begin
  FSupport.DefineMethod(Target, Name, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Replace(This, Args, ReplaceAll);
    end);
end;

procedure TJSStringPatternMethods.DefineSplit(const Target: IJSObject);
begin
  FSupport.DefineMethod(Target, SPLIT_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Split(This, Args);
    end);
end;

procedure TJSStringPatternMethods.Register;
begin
  const PrototypeObj = FInterpreter.StringPrototype;

  DefineMatchOrSearch(PrototypeObj, MATCH_NAME, TJSWellKnownSymbol.Match);
  DefineMatchOrSearch(PrototypeObj, SEARCH_NAME, TJSWellKnownSymbol.Search);
  DefineReplace(PrototypeObj, REPLACE_NAME, False);
  DefineReplace(PrototypeObj, REPLACE_ALL_NAME, True);
  DefineSplit(PrototypeObj);
end;

end.
