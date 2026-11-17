unit JS4D.Tests.Support;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Engine;

type
  TJSTestSupport = class
  public
    class function TextOf(const Engine: TJSEngine; const Expression: string): string; static;
    class function RunAndRead(const Engine: TJSEngine; const Script: string): string; static;
    class function ErrorNameOf(const Engine: TJSEngine; const Source: string): string; static;
  end;

implementation

uses
  System.SysUtils;

class function TJSTestSupport.TextOf(const Engine: TJSEngine; const Expression: string): string;
begin
  const Wrapped = Format('String(%s)', [Expression]);
  const Value = Engine.Evaluate(Wrapped);

  Result := Value.ToString;
end;

class function TJSTestSupport.RunAndRead(const Engine: TJSEngine; const Script: string): string;
begin
  Engine.Execute(Script);

  Result := TextOf(Engine, 'r');
end;

class function TJSTestSupport.ErrorNameOf(const Engine: TJSEngine; const Source: string): string;
begin
  const BackslashesEscaped = Source.Replace('\', '\\');
  const QuotesEscaped = BackslashesEscaped.Replace('"', '\"');
  const NewlinesEscaped = QuotesEscaped.Replace(#10, '\n');
  const Wrapper = Format('var caught = ""; try { eval("%s"); } catch (e) { caught = e.name; }', [NewlinesEscaped]);
  Engine.Execute(Wrapper);

  const Caught = Engine.Evaluate('caught');
  Result := Caught.AsString;
end;

end.
