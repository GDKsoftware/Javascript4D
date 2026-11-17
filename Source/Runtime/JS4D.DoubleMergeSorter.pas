unit JS4D.DoubleMergeSorter;

interface

uses
  System.SysUtils;

type
  TJSElementComparer = reference to function(const Left: Double; const Right: Double): Double;

  TJSDoubleMergeSorter = class
  private
    FValues: TArray<Double>;
    FScratch: TArray<Double>;
    FCompare: TJSElementComparer;

    procedure MergeSort(const LowIndex: Integer; const HighIndex: Integer);
    function IsLeftNext(const LeftIndex: Integer; const RightIndex: Integer; const MiddleIndex: Integer;
                        const HighIndex: Integer): Boolean;
    procedure MergeRuns(const LowIndex: Integer; const MiddleIndex: Integer; const HighIndex: Integer);

  public
    constructor Create(const Values: TArray<Double>; const Compare: TJSElementComparer);

    function Sorted: TArray<Double>;
  end;

implementation

constructor TJSDoubleMergeSorter.Create(const Values: TArray<Double>; const Compare: TJSElementComparer);
begin
  inherited Create;

  FValues := Copy(Values);
  SetLength(FScratch, Length(Values));
  FCompare := Compare;
end;

function TJSDoubleMergeSorter.Sorted: TArray<Double>;
begin
  MergeSort(0, Length(FValues));

  Result := FValues;
end;

procedure TJSDoubleMergeSorter.MergeSort(const LowIndex: Integer; const HighIndex: Integer);
begin
  const IsSorted = ((HighIndex - LowIndex) < 2);
  if IsSorted then
    Exit;

  const MiddleIndex = LowIndex + ((HighIndex - LowIndex) div 2);
  MergeSort(LowIndex, MiddleIndex);
  MergeSort(MiddleIndex, HighIndex);
  MergeRuns(LowIndex, MiddleIndex, HighIndex);
end;

function TJSDoubleMergeSorter.IsLeftNext(const LeftIndex: Integer; const RightIndex: Integer;
                                         const MiddleIndex: Integer; const HighIndex: Integer): Boolean;
begin
  const RightIsExhausted = (RightIndex >= HighIndex);
  if RightIsExhausted then
    Exit(True);

  const LeftIsExhausted = (LeftIndex >= MiddleIndex);
  if LeftIsExhausted then
    Exit(False);

  const Order = FCompare(FValues[LeftIndex], FValues[RightIndex]);

  Result := (Order <= 0);
end;

procedure TJSDoubleMergeSorter.MergeRuns(const LowIndex: Integer; const MiddleIndex: Integer;
                                         const HighIndex: Integer);
begin
  var LeftIndex := LowIndex;
  var RightIndex := MiddleIndex;
  for var Position := LowIndex to HighIndex - 1 do
  begin
    const TakesLeft = IsLeftNext(LeftIndex, RightIndex, MiddleIndex, HighIndex);
    if TakesLeft then
    begin
      FScratch[Position] := FValues[LeftIndex];
      Inc(LeftIndex);
    end
    else
    begin
      FScratch[Position] := FValues[RightIndex];
      Inc(RightIndex);
    end;
  end;

  const RunLength = HighIndex - LowIndex;
  Move(FScratch[LowIndex], FValues[LowIndex], RunLength * SizeOf(Double));
end;

end.
