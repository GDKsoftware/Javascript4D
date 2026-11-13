unit JS4D.StackGuard;

{$SCOPEDENUMS ON}

interface

type
  // Tells how far the calling thread may still use its stack. The parser and the evaluator compare the address of
  // a local variable with the floor, so that source of any shape ends in a RangeError instead of a stack overflow.
  TJSStackGuard = class sealed
  private
    const
      MAX_RESERVE = 256 * 1024;
      FALLBACK_BUDGET = 512 * 1024;

  public
    // The lowest stack address that script code may use on the calling thread. The part of the stack below it is
    // kept for raising the error and for native built-ins that run at the floor.
    class function CurrentFloor: NativeUInt; static;
    // The number of bytes between the caller and the end of the stack of the calling thread, for native code
    // that cannot check the stack while it runs and has to size its work beforehand.
    class function RemainingBytes: NativeUInt; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;

type
  TGetCurrentThreadStackLimits = procedure(out LowLimit: NativeUInt; out HighLimit: NativeUInt); stdcall;

var
  GetCurrentThreadStackLimits: TGetCurrentThreadStackLimits;
  IsLimitsLookupDone: Boolean;

procedure LookUpStackLimitsApi;
begin
  const KernelModule = GetModuleHandle('kernel32.dll');
  if KernelModule <> 0 then
    GetCurrentThreadStackLimits := GetProcAddress(KernelModule, 'GetCurrentThreadStackLimits');

  IsLimitsLookupDone := True;
end;

function TryReadStackLimits(out LowLimit: NativeUInt; out HighLimit: NativeUInt): Boolean;
begin
  if not IsLimitsLookupDone then
    LookUpStackLimitsApi;

  Result := Assigned(GetCurrentThreadStackLimits);
  if Result then
    GetCurrentThreadStackLimits(LowLimit, HighLimit);
end;
{$ENDIF}

{ TJSStackGuard }

class function TJSStackGuard.CurrentFloor: NativeUInt;
begin
  var Marker: Byte;
  const Position = NativeUInt(@Marker);

  {$IFDEF MSWINDOWS}
  var LowLimit: NativeUInt;
  var HighLimit: NativeUInt;
  if TryReadStackLimits(LowLimit, HighLimit) then
  begin
    const Reserve = (HighLimit - LowLimit) div 4;
    if Reserve > MAX_RESERVE then
      Exit(LowLimit + MAX_RESERVE);

    Exit(LowLimit + Reserve);
  end;
  {$ENDIF}

  if Position > FALLBACK_BUDGET then
    Result := Position - FALLBACK_BUDGET
  else
    Result := 0;
end;

class function TJSStackGuard.RemainingBytes: NativeUInt;
begin
  var Marker: Byte;
  const Position = NativeUInt(@Marker);

  {$IFDEF MSWINDOWS}
  var LowLimit: NativeUInt;
  var HighLimit: NativeUInt;
  if TryReadStackLimits(LowLimit, HighLimit) then
  begin
    if Position > LowLimit then
      Exit(Position - LowLimit);

    Exit(0);
  end;
  {$ENDIF}

  Result := FALLBACK_BUDGET;
end;

end.
