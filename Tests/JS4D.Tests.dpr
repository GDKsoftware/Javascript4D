program JS4D.Tests;

{$APPTYPE CONSOLE}

{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.NUnit,
  DUnitX.TestFramework,
  JS4D.Types in '..\Source\Core\JS4D.Types.pas',
  JS4D.Errors in '..\Source\Core\JS4D.Errors.pas',
  JS4D.Tokens in '..\Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in '..\Source\Lexer\JS4D.Lexer.pas',
  JS4D.AST in '..\Source\Parser\JS4D.AST.pas',
  JS4D.Parser in '..\Source\Parser\JS4D.Parser.pas',
  JS4D.Interpreter in '..\Source\Runtime\JS4D.Interpreter.pas',
  JS4D.Engine in '..\Source\API\JS4D.Engine.pas',
  JS4D.Builtins in '..\Source\Runtime\JS4D.Builtins.pas',
  JS4D.Tests.Engine in 'JS4D.Tests.Engine.pas',
  JS4D.Tests.Lexer in 'JS4D.Tests.Lexer.pas',
  JS4D.Tests.Parser in 'JS4D.Tests.Parser.pas',
  JS4D.Tests.Builtins in 'JS4D.Tests.Builtins.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
  NUnitLogger: ITestLogger;

begin
  ReportMemoryLeaksOnShutdown := True;

  try
    TDUnitX.CheckCommandLine;

    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;

    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);

    NUnitLogger := TDUnitXXMLNUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(NUnitLogger);
    Runner.FailsOnNoAsserts := False;

    Results := Runner.Execute;

    if not Results.AllPassed then
      System.ExitCode := EXIT_ERRORS;

    {$IFNDEF CI}
    if TDUnitX.Options.ExitBehavior = TDUnitXExitBehavior.Pause then
    begin
      System.Write('Done.. press <Enter> key to quit.');
      System.Readln;
    end;
    {$ENDIF}
  except
    on E: Exception do
      System.Writeln(E.ClassName, ': ', E.Message);
  end;
end.
