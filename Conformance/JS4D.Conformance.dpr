program JS4D.Conformance;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  JS4D.Types in '..\Source\Core\JS4D.Types.pas',
  JS4D.ArrayObject in '..\Source\Core\JS4D.ArrayObject.pas',
  JS4D.RegExpObject in '..\Source\Core\JS4D.RegExpObject.pas',
  JS4D.SymbolObject in '..\Source\Core\JS4D.SymbolObject.pas',
  JS4D.Errors in '..\Source\Core\JS4D.Errors.pas',
  JS4D.RegExpSyntax in '..\Source\Core\JS4D.RegExpSyntax.pas',
  JS4D.RegExpTranslator in '..\Source\Core\JS4D.RegExpTranslator.pas',
  JS4D.PcreMatcher in '..\Source\Core\JS4D.PcreMatcher.pas',
  JS4D.Tokens in '..\Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in '..\Source\Lexer\JS4D.Lexer.pas',
  JS4D.LexicalCharacters in '..\Source\Lexer\JS4D.LexicalCharacters.pas',
  JS4D.SlashContext in '..\Source\Lexer\JS4D.SlashContext.pas',
  JS4D.AST in '..\Source\Parser\JS4D.AST.pas',
  JS4D.Parser in '..\Source\Parser\JS4D.Parser.pas',
  JS4D.ParserScope in '..\Source\Parser\JS4D.ParserScope.pas',
  JS4D.ParserConstants in '..\Source\Parser\JS4D.ParserConstants.pas',
  JS4D.ParserTypes in '..\Source\Parser\JS4D.ParserTypes.pas',
  JS4D.ParserBase in '..\Source\Parser\JS4D.ParserBase.pas',
  JS4D.ParserPatterns in '..\Source\Parser\JS4D.ParserPatterns.pas',
  JS4D.ParserExpressions in '..\Source\Parser\JS4D.ParserExpressions.pas',
  JS4D.ParserFunctions in '..\Source\Parser\JS4D.ParserFunctions.pas',
  JS4D.ParserRules in '..\Source\Parser\JS4D.ParserRules.pas',
  JS4D.ParserLookahead in '..\Source\Parser\JS4D.ParserLookahead.pas',
  JS4D.PatternConverter in '..\Source\Parser\JS4D.PatternConverter.pas',
  JS4D.PropertyKey in '..\Source\Core\JS4D.PropertyKey.pas',
  JS4D.BinaryData in '..\Source\Runtime\JS4D.BinaryData.pas',
  JS4D.ControlFlow in '..\Source\Runtime\JS4D.ControlFlow.pas',
  JS4D.LexicalStates in '..\Source\Runtime\JS4D.LexicalStates.pas',
  JS4D.JsonSyntax in '..\Source\API\JS4D.JsonSyntax.pas',
  JS4D.Builtins in '..\Source\Runtime\JS4D.Builtins.pas',
  JS4D.PatternOperations in '..\Source\Runtime\JS4D.PatternOperations.pas',
  JS4D.Interpreter in '..\Source\Runtime\JS4D.Interpreter.pas',
  JS4D.JsonWriter in '..\Source\API\JS4D.JsonWriter.pas',
  JS4D.Engine in '..\Source\API\JS4D.Engine.pas',
  JS4D.Conformance.Defines in 'JS4D.Conformance.Defines.pas',
  JS4D.Conformance.Metadata in 'JS4D.Conformance.Metadata.pas',
  JS4D.Conformance.FeatureExclusions in 'JS4D.Conformance.FeatureExclusions.pas',
  JS4D.Conformance.ListFile in 'JS4D.Conformance.ListFile.pas',
  JS4D.Conformance.PathExclusions in 'JS4D.Conformance.PathExclusions.pas',
  JS4D.Conformance.TestCase in 'JS4D.Conformance.TestCase.pas',
  JS4D.Conformance.Session in 'JS4D.Conformance.Session.pas',
  JS4D.Conformance.ErrorObserver in 'JS4D.Conformance.ErrorObserver.pas',
  JS4D.Conformance.Harness in 'JS4D.Conformance.Harness.pas',
  JS4D.Conformance.VerdictJudge in 'JS4D.Conformance.VerdictJudge.pas',
  JS4D.Conformance.TestExecutor in 'JS4D.Conformance.TestExecutor.pas',
  JS4D.Conformance.Selector in 'JS4D.Conformance.Selector.pas',
  JS4D.Conformance.Options in 'JS4D.Conformance.Options.pas',
  JS4D.Conformance.Report in 'JS4D.Conformance.Report.pas',
  JS4D.Conformance.ReportFormatter in 'JS4D.Conformance.ReportFormatter.pas',
  JS4D.Conformance.ReportWriter in 'JS4D.Conformance.ReportWriter.pas',
  JS4D.Conformance.Runner in 'JS4D.Conformance.Runner.pas',
  JS4D.Conformance.Application in 'JS4D.Conformance.Application.pas';

begin
  System.ExitCode := TConformanceApplication.Run;
end.
