program JS4D.Conformance;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  JS4D.Types in '..\Source\Core\JS4D.Types.pas',
  JS4D.Errors in '..\Source\Core\JS4D.Errors.pas',
  JS4D.RegExpSyntax in '..\Source\Core\JS4D.RegExpSyntax.pas',
  JS4D.Tokens in '..\Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in '..\Source\Lexer\JS4D.Lexer.pas',
  JS4D.AST in '..\Source\Parser\JS4D.AST.pas',
  JS4D.Parser in '..\Source\Parser\JS4D.Parser.pas',
  JS4D.Builtins in '..\Source\Runtime\JS4D.Builtins.pas',
  JS4D.Interpreter in '..\Source\Runtime\JS4D.Interpreter.pas',
  JS4D.Json in '..\Source\API\JS4D.Json.pas',
  JS4D.Engine in '..\Source\API\JS4D.Engine.pas',
  JS4D.Conformance.Defines in 'JS4D.Conformance.Defines.pas',
  JS4D.Conformance.Metadata in 'JS4D.Conformance.Metadata.pas',
  JS4D.Conformance.Exclusions in 'JS4D.Conformance.Exclusions.pas',
  JS4D.Conformance.PathExclusions in 'JS4D.Conformance.PathExclusions.pas',
  JS4D.Conformance.TestCase in 'JS4D.Conformance.TestCase.pas',
  JS4D.Conformance.Session in 'JS4D.Conformance.Session.pas',
  JS4D.Conformance.ErrorObserver in 'JS4D.Conformance.ErrorObserver.pas',
  JS4D.Conformance.Harness in 'JS4D.Conformance.Harness.pas',
  JS4D.Conformance.TestExecutor in 'JS4D.Conformance.TestExecutor.pas',
  JS4D.Conformance.Selector in 'JS4D.Conformance.Selector.pas',
  JS4D.Conformance.Options in 'JS4D.Conformance.Options.pas',
  JS4D.Conformance.Report in 'JS4D.Conformance.Report.pas',
  JS4D.Conformance.Runner in 'JS4D.Conformance.Runner.pas',
  JS4D.Conformance.Application in 'JS4D.Conformance.Application.pas';

begin
  System.ExitCode := TConformanceApplication.Run;
end.
