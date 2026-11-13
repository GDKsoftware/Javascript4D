unit JS4D.StackGuard;

{$SCOPEDENUMS ON}

interface

type
  TJSStackGuard = class sealed
  private
    type
      TGetCurrentThreadStackLimits = procedure(out LowLimit: NativeUInt; out HighLimit: NativeUInt); stdcall;

    const
      MAX_RESERVE = 256 * 1024;
      FALLBACK_BUDGET = 512 * 1024;
      RESERVE_FRACTION_DIVISOR = 4;
      KERNEL_MODULE_NAME = 'kernel32.dll';
      STACK_LIMITS_API_NAME = 'GetCurrentThreadStackLimits';

    class var
      FGetCurrentThreadStackLimits: TGetCurrentThreadStackLimits;

    class constructor Create;

    class function TryReadStackLimits(out LowLimit: NativeUInt; out HighLimit: NativeUInt): Boolean; static;
    class function FloorFromLimits(const LowLimit: NativeUInt; const HighLimit: NativeUInt): NativeUInt; static;
    class function FloorFromPosition(const Position: NativeUInt): NativeUInt; static;
    class function RemainingFromLimits(const Position: NativeUInt; const LowLimit: NativeUInt): NativeUInt; static;

  public
    class function CurrentFloor: NativeUInt; static;
    class function RemainingBytes: NativeUInt; static;
  end;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;
{$ENDIF}

{ TJSStackGuard }

class constructor TJSStackGuard.Create;
begin
  {$IFDEF MSWINDOWS}
  const KernelModule = GetModuleHandle(KERNEL_MODULE_NAME);
  const IsKernelLoaded = (KernelModule <> 0);
  if IsKernelLoaded then
  begin
    FGetCurrentThreadStackLimits := GetProcAddress(KernelModule, STACK_LIMITS_API_NAME);
  end;
  {$ENDIF}
end;

class function TJSStackGuard.TryReadStackLimits(out LowLimit: NativeUInt; out HighLimit: NativeUInt): Boolean;
begin
  LowLimit := 0;
  HighLimit := 0;

  Result := Assigned(FGetCurrentThreadStackLimits);
  if Result then
  begin
    FGetCurrentThreadStackLimits(LowLimit, HighLimit);
  end;
end;

class function TJSStackGuard.FloorFromLimits(const LowLimit: NativeUInt; const HighLimit: NativeUInt): NativeUInt;
begin
  const Reserve = (HighLimit - LowLimit) div RESERVE_FRACTION_DIVISOR;
  const ExceedsMaxReserve = (Reserve > MAX_RESERVE);

  if ExceedsMaxReserve then
  begin
    Result := LowLimit + MAX_RESERVE;
  end
  else
  begin
    Result := LowLimit + Reserve;
  end;
end;

class function TJSStackGuard.FloorFromPosition(const Position: NativeUInt): NativeUInt;
begin
  const HasRoomForBudget = (Position > FALLBACK_BUDGET);

  if HasRoomForBudget then
  begin
    Result := Position - FALLBACK_BUDGET;
  end
  else
  begin
    Result := 0;
  end;
end;

class function TJSStackGuard.RemainingFromLimits(const Position: NativeUInt; const LowLimit: NativeUInt): NativeUInt;
begin
  const IsAboveLowLimit = (Position > LowLimit);

  if IsAboveLowLimit then
  begin
    Result := Position - LowLimit;
  end
  else
  begin
    Result := 0;
  end;
end;

class function TJSStackGuard.CurrentFloor: NativeUInt;
begin
  var Marker: Byte;
  const Position = NativeUInt(@Marker);

  var LowLimit: NativeUInt;
  var HighLimit: NativeUInt;
  const HasLimits = TryReadStackLimits(LowLimit, HighLimit);

  if HasLimits then
  begin
    Result := FloorFromLimits(LowLimit, HighLimit);
  end
  else
  begin
    Result := FloorFromPosition(Position);
  end;
end;

class function TJSStackGuard.RemainingBytes: NativeUInt;
begin
  var Marker: Byte;
  const Position = NativeUInt(@Marker);

  var LowLimit: NativeUInt;
  var HighLimit: NativeUInt;
  const HasLimits = TryReadStackLimits(LowLimit, HighLimit);

  if HasLimits then
  begin
    Result := RemainingFromLimits(Position, LowLimit);
  end
  else
  begin
    Result := FALLBACK_BUDGET;
  end;
end;

end.
