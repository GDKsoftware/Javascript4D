unit JS4D.Conformance.Session;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.Engine,
  JS4D.Conformance.Defines;

type
  TTestSession = class
  private
    FEngine: TJSEngine;
    FPrinted: TList<string>;

    procedure ApplyLimits(const Limits: TSessionLimits);
    procedure InstallPrint;
    procedure InstallHostObject;
    function CreateHostObject: TJSObject;
    function CreateNativeValue(const Name: string; const Func: TNativeFunction): TJSValue;

  public
    constructor Create(const Limits: TSessionLimits);
    destructor Destroy; override;

    procedure Run(const Source: string);

    property Printed: TList<string> read FPrinted;
  end;

implementation

const
  PrintName = 'print';
  HostObjectName = '$262';
  GlobalPropertyName = 'global';
  EvalScriptName = 'evalScript';
  GcName = 'gc';
  GlobalThisSource = 'this';

constructor TTestSession.Create(const Limits: TSessionLimits);
begin
  inherited Create;
  FEngine := TJSEngine.Create;
  FPrinted := TList<string>.Create;

  ApplyLimits(Limits);
  FEngine.OnConsoleOutput := procedure(const Output: string)
    begin
      FPrinted.Add(Output);
    end;

  InstallPrint;
  InstallHostObject;
end;

destructor TTestSession.Destroy;
begin
  FPrinted.Free;
  FEngine.Free;
  inherited;
end;

procedure TTestSession.Run(const Source: string);
begin
  FEngine.Execute(Source);
end;

procedure TTestSession.ApplyLimits(const Limits: TSessionLimits);
begin
  FEngine.StepBudget := Limits.StepBudget;
  FEngine.MaxCallDepth := Limits.MaxCallDepth;
  FEngine.MaxStringLength := Limits.MaxStringLength;
  FEngine.MaxArrayLength := Limits.MaxArrayLength;
end;

procedure TTestSession.InstallPrint;
begin
  FEngine.RegisterFunction(PrintName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasArgument = (Length(Args) > 0);
      if HasArgument then
        FPrinted.Add(Args[0].ToString);

      Result := TJSValue.CreateUndefined;
    end);
end;

procedure TTestSession.InstallHostObject;
begin
  FEngine.SetVariable(HostObjectName, TJSValue.CreateObject(CreateHostObject));
end;

function TTestSession.CreateHostObject: TJSObject;
begin
  Result := TJSObject.Create;
  Result.SetProperty(GlobalPropertyName, FEngine.Execute(GlobalThisSource));

  Result.SetProperty(EvalScriptName, CreateNativeValue(EvalScriptName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasSource = (Length(Args) > 0);
      if not HasSource then
        Exit(TJSValue.CreateUndefined);

      Result := FEngine.Execute(Args[0].ToString);
    end));

  Result.SetProperty(GcName, CreateNativeValue(GcName,
    function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FEngine.CollectGarbage;
      Result := TJSValue.CreateUndefined;
    end));
end;

function TTestSession.CreateNativeValue(const Name: string; const Func: TNativeFunction): TJSValue;
begin
  Result := TJSValue.CreateObject(TJSFunction.CreateNative(Name, Func));
end;

end.
