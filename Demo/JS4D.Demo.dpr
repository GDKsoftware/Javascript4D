program JS4D.Demo;

uses
  Vcl.Forms,
  JS4D.Demo.Main in 'JS4D.Demo.Main.pas' {FormMain},
  JS4D.Types in '..\Source\Core\JS4D.Types.pas',
  JS4D.Errors in '..\Source\Core\JS4D.Errors.pas',
  JS4D.Tokens in '..\Source\Lexer\JS4D.Tokens.pas',
  JS4D.Lexer in '..\Source\Lexer\JS4D.Lexer.pas',
  JS4D.AST in '..\Source\Parser\JS4D.AST.pas',
  JS4D.Parser in '..\Source\Parser\JS4D.Parser.pas',
  JS4D.Builtins in '..\Source\Runtime\JS4D.Builtins.pas',
  JS4D.Interpreter in '..\Source\Runtime\JS4D.Interpreter.pas',
  JS4D.Engine in '..\Source\API\JS4D.Engine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'JavaScript4D Demo';
  Application.CreateForm(TFormMain, FormMain);
  Application.Run;
end.
