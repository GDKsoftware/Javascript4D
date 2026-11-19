unit JS4D.LargeStackCall;

interface

uses
  System.SysUtils;

type
  TJSLargeStackCall = class sealed
  private
    type
      TCallState = record
        Work: TFunc<Integer>;
        Outcome: Integer;
        Failure: TObject;
      end;
      PCallState = ^TCallState;

    const
      {$IFDEF CPU64BITS}
      RESERVED_STACK_BYTES = 256 * 1024 * 1024;
      {$ELSE}
      RESERVED_STACK_BYTES = 128 * 1024 * 1024;
      {$ENDIF}
      NO_THREAD = 0;
      THREAD_EXIT_CODE = 0;

    class function StartThread(const State: PCallState): THandle; static;
    class function RunOnThread(Parameter: Pointer): Integer; static;
    class procedure AwaitThread(const Thread: THandle); static;

  public
    class function Run(const Work: TFunc<Integer>): Integer; static;
  end;

implementation

uses
  Winapi.Windows,
  JS4D.Errors;

{ TJSLargeStackCall }

class function TJSLargeStackCall.Run(const Work: TFunc<Integer>): Integer;
begin
  var State := Default(TCallState);
  State.Work := Work;

  const Thread = StartThread(@State);
  AwaitThread(Thread);

  if Assigned(State.Failure) then
    raise State.Failure;

  Result := State.Outcome;
end;

class function TJSLargeStackCall.StartThread(const State: PCallState): THandle;
begin
  var ThreadId: TThreadID;
  Result := BeginThread(nil, RESERVED_STACK_BYTES, RunOnThread, State, STACK_SIZE_PARAM_IS_A_RESERVATION, ThreadId);

  const HasNoThread = (Result = NO_THREAD);
  if HasNoThread then
    raise TJSErrorFactory.StackExhausted;
end;

class function TJSLargeStackCall.RunOnThread(Parameter: Pointer): Integer;
begin
  const State = PCallState(Parameter);
  try
    State.Outcome := State.Work();
  except
    State.Failure := TObject(AcquireExceptionObject);
  end;

  Result := THREAD_EXIT_CODE;
end;

class procedure TJSLargeStackCall.AwaitThread(const Thread: THandle);
begin
  try
    WaitForSingleObject(Thread, INFINITE);
  finally
    CloseHandle(Thread);
  end;
end;

end.
