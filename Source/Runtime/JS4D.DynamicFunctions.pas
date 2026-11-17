unit JS4D.DynamicFunctions;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.Interpreter;

type
  TJSFunctionText = record
    Parameters: string;
    Body: string;
  end;

  TJSDynamicFunctionFactory = class
  private
    const
      SOURCE_FORMAT = '(%s (%s' + sLineBreak + ') {' + sLineBreak + '%s' + sLineBreak + '})';
      TEXT_FORMAT = '%s anonymous(%s'#10') {'#10'%s'#10'}';
      PARAMETER_SEPARATOR = ',';

    var
      FInterpreter: TJSInterpreter;
      FKeyword: string;

    function ReadText(const Args: TArray<TJSValue>): TJSFunctionText;
    procedure Decorate(const Created: TJSValue; const Text: TJSFunctionText);

  public
    constructor Create(const Interpreter: TJSInterpreter; const Keyword: string);

    function CreateFunction(const Args: TArray<TJSValue>): TJSValue;
  end;

implementation

uses
  JS4D.Conversions,
  JS4D.PropertyNames;

constructor TJSDynamicFunctionFactory.Create(const Interpreter: TJSInterpreter; const Keyword: string);
begin
  inherited Create;

  FInterpreter := Interpreter;
  FKeyword := Keyword;
end;

function TJSDynamicFunctionFactory.ReadText(const Args: TArray<TJSValue>): TJSFunctionText;
begin
  Result := Default(TJSFunctionText);

  const HasArguments = (Length(Args) > 0);
  if not HasArguments then
    Exit;

  const LastIndex = High(Args);
  var ParameterTexts: TArray<string>;
  SetLength(ParameterTexts, LastIndex);
  for var Index := 0 to LastIndex - 1 do
  begin
    ParameterTexts[Index] := TJSConversions.ToText(Args[Index], FInterpreter.Limits);
  end;

  Result.Parameters := string.Join(PARAMETER_SEPARATOR, ParameterTexts);
  Result.Body := TJSConversions.ToText(Args[LastIndex], FInterpreter.Limits);
end;

function TJSDynamicFunctionFactory.CreateFunction(const Args: TArray<TJSValue>): TJSValue;
begin
  const Text = ReadText(Args);
  const Source = Format(SOURCE_FORMAT, [FKeyword, Text.Parameters, Text.Body]);

  Result := FInterpreter.CreateFunctionFromSource(Source);
  Decorate(Result, Text);
end;

procedure TJSDynamicFunctionFactory.Decorate(const Created: TJSValue; const Text: TJSFunctionText);
begin
  var Func: IJSFunction;
  const CreatedObject = Created.ToObject;
  const IsFunction = Supports(CreatedObject, IJSFunction, Func);
  if not IsFunction then
    Exit;

  Func.Name := ANONYMOUS_NAME;
  Func.SourceText := Format(TEXT_FORMAT, [FKeyword, Text.Parameters, Text.Body]);
end;

end.
