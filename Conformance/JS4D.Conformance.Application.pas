unit JS4D.Conformance.Application;

{$SCOPEDENUMS ON}

interface

type
  TConformanceApplication = class
  public
    class function Run: Integer; static;
  end;

implementation

uses
  System.SysUtils,
  JS4D.Conformance.Options,
  JS4D.Conformance.Runner;

const
  ExitSuccess = 0;
  ExitCrash = 2;

class function TConformanceApplication.Run: Integer;
begin
  try
    const Options = TConformanceOptions.Create;
    try
      const Runner = TConformanceRunner.Create(Options);
      try
        Runner.Run;
        const Summary = Runner.Report.BuildSummary;
        Writeln(Summary);
        Runner.Report.SaveTo(Options.ResultsDirectory);

        const SavedMessage = Format('Results written to %s', [Options.ResultsDirectory]);
        Writeln(SavedMessage);
      finally
        Runner.Free;
      end;
    finally
      Options.Free;
    end;

    Result := ExitSuccess;
  except
    on E: Exception do
    begin
      const Message = Format('%s: %s', [E.ClassName, E.Message]);
      Writeln(ErrOutput, Message);
      Result := ExitCrash;
    end;
  end;
end;

end.
