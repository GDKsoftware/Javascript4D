unit JS4D.StringPatternMethods;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.SymbolRegistry,
  JS4D.Interpreter;

type
  TJSStringPatternMethods = class
  private
    const
      MATCH_NAME = 'match';
      REPLACE_NAME = 'replace';
      REPLACE_ALL_NAME = 'replaceAll';
      SEARCH_NAME = 'search';
      SPLIT_NAME = 'split';
      FLAGS_PROPERTY = 'flags';
      GLOBAL_FLAG = 'g';
      CALLED_ON_NULL_OR_UNDEFINED = 'String.prototype.%s called on null or undefined';
      REPLACE_ALL_NEEDS_GLOBAL = 'replaceAll must be called with a global RegExp';
      NULL_FLAGS = 'The flags of a regular expression must not be null or undefined';

    var
      FInterpreter: TJSInterpreter;

    function ThisValueOf(const This: IJSObject; const MethodName: string): TJSValue;
    function Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
    function ToText(const Value: TJSValue): string;
    function HasSearchValue(const Value: TJSValue): Boolean;
    function DelegateTo(const SearchValue: TJSValue; const Key: string; const Subject: TJSValue;
                        const Rest: TArray<TJSValue>; out Handled: Boolean): TJSValue;
    procedure RequireGlobalFlags(const SearchValue: TJSValue);
    function InvokeOnNewRegExp(const Key: string; const Pattern: TJSValue; const Text: string): TJSValue;
    function MatchOrSearch(const This: IJSObject; const Args: TArray<TJSValue>; const MethodName: string;
                           const Which: TJSWellKnownSymbol): TJSValue;
    function Replace(const This: IJSObject; const Args: TArray<TJSValue>; const ReplaceAll: Boolean): TJSValue;
    function Split(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    function CreateMethod(const Name: string; const ParameterCount: Integer;
                          const Method: TNativeFunction): IJSFunction;
    procedure DefineMethod(const Target: IJSObject; const Name: string; const ParameterCount: Integer;
                           const Method: TNativeFunction);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Register;
  end;

implementation

uses
  JS4D.Errors,
  JS4D.Conversions,
  JS4D.PatternOperations;

constructor TJSStringPatternMethods.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FInterpreter := Interpreter;
end;

function TJSStringPatternMethods.ThisValueOf(const This: IJSObject; const MethodName: string): TJSValue;
begin
  if not Assigned(This) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [MethodName]));

  var Wrapper: IJSPrimitiveWrapper;
  if Supports(This, IJSPrimitiveWrapper, Wrapper) then
    Exit(Wrapper.Primitive);

  Result := TJSValue.CreateObject(This);
end;

function TJSStringPatternMethods.Argument(const Args: TArray<TJSValue>; const Position: Integer): TJSValue;
begin
  if Position < Length(Args) then
    Result := Args[Position]
  else
    Result := TJSValue.CreateUndefined;
end;

function TJSStringPatternMethods.ToText(const Value: TJSValue): string;
begin
  Result := TJSConversions.ToText(Value, FInterpreter.Limits);
end;

function TJSStringPatternMethods.HasSearchValue(const Value: TJSValue): Boolean;
begin
  Result := Value.IsObject;
end;

function TJSStringPatternMethods.DelegateTo(const SearchValue: TJSValue; const Key: string; const Subject: TJSValue;
                                            const Rest: TArray<TJSValue>; out Handled: Boolean): TJSValue;
begin
  Handled := False;
  Result := TJSValue.CreateUndefined;

  if not HasSearchValue(SearchValue) then
    Exit;

  const Method = TJSConversions.FindMethod(SearchValue, Key);
  if not Assigned(Method) then
    Exit;

  Handled := True;
  Result := Method.Call(SearchValue.ToObject, [Subject] + Rest);
end;

procedure TJSStringPatternMethods.RequireGlobalFlags(const SearchValue: TJSValue);
begin
  if not TJSConversions.IsRegExp(SearchValue) then
    Exit;

  const Flags = SearchValue.ToObject.GetProperty(FLAGS_PROPERTY);
  if Flags.IsNullOrUndefined then
    raise TJSErrorFactory.TypeError(NULL_FLAGS);

  const IsGlobal = (Pos(GLOBAL_FLAG, ToText(Flags)) > 0);
  if not IsGlobal then
    raise TJSErrorFactory.TypeError(REPLACE_ALL_NEEDS_GLOBAL);
end;

function TJSStringPatternMethods.InvokeOnNewRegExp(const Key: string; const Pattern: TJSValue;
                                                   const Text: string): TJSValue;
begin
  var PatternText := '';
  if not Pattern.IsUndefined then
    PatternText := ToText(Pattern);

  const NewRegExp: IJSRegExp = TJSRegExp.Create(PatternText, '');
  NewRegExp.Prototype := FInterpreter.RegExpPrototype;

  const Method = TJSConversions.FindMethod(TJSValue.CreateObject(NewRegExp), Key);
  if not Assigned(Method) then
    raise TJSErrorFactory.TypeError(Format(CALLED_ON_NULL_OR_UNDEFINED, [Key]));

  Result := Method.Call(NewRegExp, [TJSValue.CreateString(Text)]);
end;

function TJSStringPatternMethods.MatchOrSearch(const This: IJSObject; const Args: TArray<TJSValue>;
                                               const MethodName: string; const Which: TJSWellKnownSymbol): TJSValue;
begin
  const Subject = ThisValueOf(This, MethodName);
  const Pattern = Argument(Args, 0);
  const Key = TJSSymbolRegistry.WellKnownKey(Which);

  var Handled: Boolean;
  const Delegated = DelegateTo(Pattern, Key, Subject, nil, Handled);
  if Handled then
    Exit(Delegated);

  Result := InvokeOnNewRegExp(Key, Pattern, ToText(Subject));
end;

function TJSStringPatternMethods.Replace(const This: IJSObject; const Args: TArray<TJSValue>;
                                         const ReplaceAll: Boolean): TJSValue;
begin
  var MethodName := REPLACE_NAME;
  if ReplaceAll then
    MethodName := REPLACE_ALL_NAME;

  const Subject = ThisValueOf(This, MethodName);
  const SearchValue = Argument(Args, 0);
  const ReplaceValue = Argument(Args, 1);

  if ReplaceAll and HasSearchValue(SearchValue) then
    RequireGlobalFlags(SearchValue);

  var Handled: Boolean;
  const Delegated = DelegateTo(SearchValue, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Replace), Subject,
                               [ReplaceValue], Handled);
  if Handled then
    Exit(Delegated);

  const Text = ToText(Subject);
  const SearchText = ToText(SearchValue);

  var Replacement := ReplaceValue;
  if not TJSConversions.IsCallable(ReplaceValue) then
    Replacement := TJSValue.CreateString(ToText(ReplaceValue));

  const Executor: TJSCallbackExecutor =
    function(const Func: IJSFunction; const CallbackArgs: TArray<TJSValue>): TJSValue
    begin
      const ThisArg = FInterpreter.ThisObjectFor(Func, TJSValue.CreateUndefined);
      Result := FInterpreter.CallFunction(Func, CallbackArgs, ThisArg);
    end;

  const Replaced = TJSPatternOperations.ReplaceText(Text, SearchText, Replacement, ReplaceAll, Executor,
                                                    FInterpreter.Limits);
  Result := TJSValue.CreateString(Replaced);
end;

function TJSStringPatternMethods.Split(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  const Subject = ThisValueOf(This, SPLIT_NAME);
  const Separator = Argument(Args, 0);
  const LimitValue = Argument(Args, 1);

  var Handled: Boolean;
  const Delegated = DelegateTo(Separator, TJSSymbolRegistry.WellKnownKey(TJSWellKnownSymbol.Split), Subject,
                               [LimitValue], Handled);
  if Handled then
    Exit(Delegated);

  const Text = ToText(Subject);

  var Limit := Int64(High(Cardinal));
  if not LimitValue.IsUndefined then
    Limit := TJSConversions.ToUint32(LimitValue);

  const SeparatorText = ToText(Separator);

  const Pieces: IJSArray = TJSArray.Create;
  Result := TJSValue.CreateObject(Pieces);

  if Limit = 0 then
    Exit;

  if Separator.IsUndefined then
  begin
    Pieces.Push(TJSValue.CreateString(Text));
    Exit;
  end;

  const SplitPieces = TJSPatternOperations.SplitText(Text, SeparatorText, Limit, FInterpreter.Limits);
  Result := TJSValue.CreateObject(SplitPieces);
end;

function TJSStringPatternMethods.CreateMethod(const Name: string; const ParameterCount: Integer;
                                              const Method: TNativeFunction): IJSFunction;
begin
  Result := TJSFunction.CreateNative(Name, Method);
  Result.IsConstructor := False;
  Result.Prototype := FInterpreter.FunctionPrototype;
  TJSFunction.DefineLength(Result, ParameterCount);
  FInterpreter.RegisterFunction(Result);
end;

procedure TJSStringPatternMethods.DefineMethod(const Target: IJSObject; const Name: string;
                                               const ParameterCount: Integer; const Method: TNativeFunction);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateObject(CreateMethod(Name, ParameterCount, Method)));
  Descriptor.Enumerable := False;
  Target.DefineProperty(Name, Descriptor);
end;

procedure TJSStringPatternMethods.Register;
begin
  const PrototypeObj = FInterpreter.StringPrototype;

  DefineMethod(PrototypeObj, MATCH_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := MatchOrSearch(This, Args, MATCH_NAME, TJSWellKnownSymbol.Match);
    end);

  DefineMethod(PrototypeObj, SEARCH_NAME, 1,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := MatchOrSearch(This, Args, SEARCH_NAME, TJSWellKnownSymbol.Search);
    end);

  DefineMethod(PrototypeObj, REPLACE_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Replace(This, Args, False);
    end);

  DefineMethod(PrototypeObj, REPLACE_ALL_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Replace(This, Args, True);
    end);

  DefineMethod(PrototypeObj, SPLIT_NAME, 2,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      Result := Split(This, Args);
    end);
end;

end.
