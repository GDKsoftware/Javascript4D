unit JS4D.Conformance.ReportWriter;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Conformance.Report;

type
  TReportWriter = class
  public
    class procedure SaveTo(const Directory: string; const Report: TConformanceReport;
                           const Summary: string); static;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

const
  SUMMARY_FILE_NAME = 'baseline.txt';
  FAILURES_FILE_NAME = 'failures.txt';
  PASSED_FILE_NAME = 'passed.txt';

class procedure TReportWriter.SaveTo(const Directory: string; const Report: TConformanceReport;
                                     const Summary: string);
begin
  const SummaryPath = TPath.Combine(Directory, SUMMARY_FILE_NAME);
  const FailuresPath = TPath.Combine(Directory, FAILURES_FILE_NAME);
  const PassedPath = TPath.Combine(Directory, PASSED_FILE_NAME);

  TDirectory.CreateDirectory(Directory);
  TFile.WriteAllText(SummaryPath, Summary, TEncoding.UTF8);
  TFile.WriteAllLines(FailuresPath, Report.FailureLines, TEncoding.UTF8);
  TFile.WriteAllLines(PassedPath, Report.SortedPassedLines, TEncoding.UTF8);
end;

end.
