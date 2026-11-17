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
  EXIT_SUCCESS = 0;
  EXIT_CRASH = 2;

class function TConformanceApplication.Run: Integer;
begin
  try
    const Options = TConformanceOptions.Create;
    try
      const Runner = TConformanceRunner.Create(Options);
      try
        Runner.Run;
        const Report = Runner.Report;
        const Summary = Report.BuildSummary;
        Writeln(Summary);
        Report.SaveTo(Options.ResultsDirectory, Summary);

        const SavedMessage = Format('Results written to %s', [Options.ResultsDirectory]);
        Writeln(SavedMessage);
      finally
        Runner.Free;
      end;
    finally
      Options.Free;
    end;

    Result := EXIT_SUCCESS;
  except
    on E: Exception do
    begin
      const Message = Format('%s: %s', [E.ClassName, E.Message]);
      Writeln(ErrOutput, Message);
      Result := EXIT_CRASH;
    end;
  end;
end;

end.
