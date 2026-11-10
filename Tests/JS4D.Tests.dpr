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
  JS4D.RegExpSyntax in '..\Source\Core\JS4D.RegExpSyntax.pas',
  JS4D.RegExpTranslator in '..\Source\Core\JS4D.RegExpTranslator.pas',
  JS4D.PcreMatcher in '..\Source\Core\JS4D.PcreMatcher.pas',
  JS4D.UriCoding in '..\Source\Core\JS4D.UriCoding.pas',
  JS4D.NumberFormat in '..\Source\Core\JS4D.NumberFormat.pas',
  JS4D.NumberParse in '..\Source\Core\JS4D.NumberParse.pas',
  JS4D.Tokens in '..\Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in '..\Source\Lexer\JS4D.Lexer.pas',
  JS4D.AST in '..\Source\Parser\JS4D.AST.pas',
  JS4D.Parser in '..\Source\Parser\JS4D.Parser.pas',
  JS4D.Interpreter in '..\Source\Runtime\JS4D.Interpreter.pas',
  JS4D.Json in '..\Source\API\JS4D.Json.pas',
  JS4D.Engine in '..\Source\API\JS4D.Engine.pas',
  JS4D.Builtins in '..\Source\Runtime\JS4D.Builtins.pas',
  JS4D.PatternOperations in '..\Source\Runtime\JS4D.PatternOperations.pas',
  JS4D.Tests.Engine in 'JS4D.Tests.Engine.pas',
  JS4D.Tests.Lexer in 'JS4D.Tests.Lexer.pas',
  JS4D.Tests.Parser in 'JS4D.Tests.Parser.pas',
  JS4D.Tests.Builtins in 'JS4D.Tests.Builtins.pas',
  JS4D.Tests.Cancellation in 'JS4D.Tests.Cancellation.pas',
  JS4D.Tests.Limits in 'JS4D.Tests.Limits.pas',
  JS4D.Tests.Prototypes in 'JS4D.Tests.Prototypes.pas',
  JS4D.Tests.BuiltinPrototypes in 'JS4D.Tests.BuiltinPrototypes.pas',
  JS4D.Tests.Arguments in 'JS4D.Tests.Arguments.pas',
  JS4D.Tests.MappedArguments in 'JS4D.Tests.MappedArguments.pas',
  JS4D.Tests.Constructors in 'JS4D.Tests.Constructors.pas',
  JS4D.Tests.TryStatement in 'JS4D.Tests.TryStatement.pas',
  JS4D.Tests.PropertyDescriptors in 'JS4D.Tests.PropertyDescriptors.pas',
  JS4D.Tests.GenericArrayMethods in 'JS4D.Tests.GenericArrayMethods.pas',
  JS4D.Tests.ArrayElements in 'JS4D.Tests.ArrayElements.pas',
  JS4D.Tests.JsonParse in 'JS4D.Tests.JsonParse.pas',
  JS4D.Tests.Eval in 'JS4D.Tests.Eval.pas',
  JS4D.Tests.FunctionConstructor in 'JS4D.Tests.FunctionConstructor.pas',
  JS4D.Tests.MemberAccess in 'JS4D.Tests.MemberAccess.pas',
  JS4D.Tests.RestrictedProperties in 'JS4D.Tests.RestrictedProperties.pas',
  JS4D.Tests.IdentifierNames in 'JS4D.Tests.IdentifierNames.pas',
  JS4D.Tests.PrimitiveWrappers in 'JS4D.Tests.PrimitiveWrappers.pas',
  JS4D.Tests.AssignmentTargets in 'JS4D.Tests.AssignmentTargets.pas',
  JS4D.Tests.StrictEarlyErrors in 'JS4D.Tests.StrictEarlyErrors.pas',
  JS4D.Tests.DeleteIdentifier in 'JS4D.Tests.DeleteIdentifier.pas',
  JS4D.Tests.WithStatement in 'JS4D.Tests.WithStatement.pas',
  JS4D.Tests.Date in 'JS4D.Tests.Date.pas',
  JS4D.Tests.BuiltinAttributes in 'JS4D.Tests.BuiltinAttributes.pas',
  JS4D.Tests.LabelledStatements in 'JS4D.Tests.LabelledStatements.pas',
  JS4D.Tests.SyntaxEarlyErrors in 'JS4D.Tests.SyntaxEarlyErrors.pas',
  JS4D.Tests.FunctionDeclarations in 'JS4D.Tests.FunctionDeclarations.pas',
  JS4D.Tests.GlobalObject in 'JS4D.Tests.GlobalObject.pas',
  JS4D.Tests.RegExpSyntax in 'JS4D.Tests.RegExpSyntax.pas',
  JS4D.Tests.ObjectAccessors in 'JS4D.Tests.ObjectAccessors.pas',
  JS4D.Tests.Operators in 'JS4D.Tests.Operators.pas',
  JS4D.Tests.UriCoding in 'JS4D.Tests.UriCoding.pas',
  JS4D.Tests.GenericArrayMutators in 'JS4D.Tests.GenericArrayMutators.pas',
  JS4D.Tests.LexicalGrammar in 'JS4D.Tests.LexicalGrammar.pas',
  JS4D.Tests.ArrayIterationLength in 'JS4D.Tests.ArrayIterationLength.pas',
  JS4D.Tests.RegExpMatching in 'JS4D.Tests.RegExpMatching.pas',
  JS4D.Tests.RegExpPatternSemantics in 'JS4D.Tests.RegExpPatternSemantics.pas',
  JS4D.Tests.NumberFormat in 'JS4D.Tests.NumberFormat.pas',
  JS4D.Tests.FunctionObjects in 'JS4D.Tests.FunctionObjects.pas',
  JS4D.Tests.NumberParsing in 'JS4D.Tests.NumberParsing.pas',
  JS4D.Tests.JsonStringify in 'JS4D.Tests.JsonStringify.pas',
  JS4D.Tests.JsonReviver in 'JS4D.Tests.JsonReviver.pas',
  JS4D.Tests.MathFunctions in 'JS4D.Tests.MathFunctions.pas',
  JS4D.Tests.ErrorObjects in 'JS4D.Tests.ErrorObjects.pas';

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
