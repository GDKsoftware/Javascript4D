unit JS4D.Conformance.Session;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Engine,
  JS4D.BinaryData,
  JS4D.Errors,
  JS4D.Conformance.Defines;

type
  TTestSession = class
  private
    FEngine: TJSEngine;
    FPrinted: TList<string>;

    function GetPrinted: TArray<string>;

    procedure ApplyLimits(const Limits: TSessionLimits);
    procedure InstallPrint;
    procedure InstallHostObject;
    procedure AddHostFunction(const HostObject: TJSObject; const Name: string; const NativeFunction: TNativeFunction);
    function CreateHostObject: TJSObject;
    function CreateEvalScript: TNativeFunction;
    function CreateDetachArrayBuffer: TNativeFunction;
    function CreateCollectGarbage: TNativeFunction;

  public
    constructor Create(const Limits: TSessionLimits);
    destructor Destroy; override;

    procedure Run(const Source: string);

    property Printed: TArray<string> read GetPrinted;
  end;

implementation

const
  PRINT_NAME = 'print';
  GLOBAL_PROPERTY_NAME = 'global';
  EVAL_SCRIPT_NAME = 'evalScript';
  GC_NAME = 'gc';
  DETACH_ARRAY_BUFFER_NAME = 'detachArrayBuffer';
  NOT_AN_ARRAY_BUFFER = 'detachArrayBuffer expects an ArrayBuffer';
  GLOBAL_THIS_SOURCE = 'this';

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
  FEngine.Free;
  FPrinted.Free;
  inherited;
end;

function TTestSession.GetPrinted: TArray<string>;
begin
  Result := FPrinted.ToArray;
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
  FEngine.RegisterFunction(PRINT_NAME,
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
  const HostObject = CreateHostObject;
  const HostValue = TJSValue.CreateObject(HostObject);
  FEngine.SetVariable(HOST_OBJECT_NAME, HostValue);
end;

function TTestSession.CreateHostObject: TJSObject;
begin
  Result := TJSObject.Create;

  const GlobalObject = FEngine.Execute(GLOBAL_THIS_SOURCE);
  Result.SetProperty(GLOBAL_PROPERTY_NAME, GlobalObject);
  AddHostFunction(Result, EVAL_SCRIPT_NAME, CreateEvalScript());
  AddHostFunction(Result, DETACH_ARRAY_BUFFER_NAME, CreateDetachArrayBuffer());
  AddHostFunction(Result, GC_NAME, CreateCollectGarbage());
end;

procedure TTestSession.AddHostFunction(const HostObject: TJSObject; const Name: string;
                                       const NativeFunction: TNativeFunction);
begin
  const FunctionObject = TJSFunction.CreateNative(Name, NativeFunction);
  const FunctionValue = TJSValue.CreateObject(FunctionObject);
  HostObject.SetProperty(Name, FunctionValue);
end;

function TTestSession.CreateEvalScript: TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasSource = (Length(Args) > 0);
      if HasSource then
      begin
        Result := FEngine.Execute(Args[0].ToString);
      end
      else
      begin
        Result := TJSValue.CreateUndefined;
      end;
    end;
end;

function TTestSession.CreateDetachArrayBuffer: TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      const HasArgument = (Length(Args) > 0);
      var Buffer: IJSArrayBuffer;
      var IsBuffer := False;
      if HasArgument and Args[0].IsObject then
        IsBuffer := Supports(Args[0].ToObject, IJSArrayBuffer, Buffer);

      if not IsBuffer then
        raise TJSErrorFactory.TypeError(NOT_AN_ARRAY_BUFFER);

      Buffer.Detach;
      Result := TJSValue.CreateNull;
    end;
end;

function TTestSession.CreateCollectGarbage: TNativeFunction;
begin
  Result := function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue
    begin
      FEngine.CollectGarbage;
      Result := TJSValue.CreateUndefined;
    end;
end;

end.
