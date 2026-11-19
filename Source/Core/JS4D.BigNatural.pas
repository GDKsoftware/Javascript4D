unit JS4D.BigNatural;

interface

type
  TJSBigNatural = record
  private
    const
      WORD_BITS = 32;
      WORD_MASK = UInt64($FFFFFFFF);
      DECIMAL_CHUNK_DIGITS = 9;
      INITIAL_CAPACITY = 4;
      POWERS_OF_TEN: array[0..DECIMAL_CHUNK_DIGITS] of UInt32 = (
        1, 10, 100, 1000, 10000, 100000, 1000000, 10000000, 100000000, 1000000000);

    var
      FWords: TArray<UInt32>;
      FCount: Integer;

    procedure AppendWord(const Value: UInt32);
    procedure DropLeadingZeroWords;
    procedure SubtractWords(const Other: TJSBigNatural);

    class function PowerOfTenWord(const Exponent: Integer): UInt32; static;
    class function SignificantBits(const Value: UInt32): Integer; static;

  public
    class function FromDigits(const Digits: string): TJSBigNatural; static;
    class function FromWord(const Value: UInt32): TJSBigNatural; static;

    function Duplicate: TJSBigNatural;
    function BitLength: Integer;
    function CompareTo(const Other: TJSBigNatural): Integer;
    procedure MultiplyAdd(const Factor: UInt32; const Addend: UInt32);
    procedure MultiplyByPowerOfTen(const Power: Integer);
    procedure ShiftLeft(const Bits: Integer);
    procedure ShiftRightOne;
    function TrySubtract(const Other: TJSBigNatural): Boolean;
  end;

implementation

uses
  System.SysUtils,
  System.Math;

{ TJSBigNatural }

class function TJSBigNatural.FromWord(const Value: UInt32): TJSBigNatural;
begin
  Result.FCount := 0;
  SetLength(Result.FWords, INITIAL_CAPACITY);

  const HasValue = (Value > 0);
  if HasValue then
    Result.AppendWord(Value);
end;

class function TJSBigNatural.PowerOfTenWord(const Exponent: Integer): UInt32;
begin
  Result := POWERS_OF_TEN[Exponent];
end;

class function TJSBigNatural.SignificantBits(const Value: UInt32): Integer;
begin
  Result := 0;

  var Remaining := Value;
  while Remaining <> 0 do
  begin
    Inc(Result);
    Remaining := Remaining shr 1;
  end;
end;

class function TJSBigNatural.FromDigits(const Digits: string): TJSBigNatural;
begin
  Result := FromWord(0);

  var Position := 1;
  while Position <= Length(Digits) do
  begin
    const ChunkLength = Min(DECIMAL_CHUNK_DIGITS, Length(Digits) - Position + 1);
    const Chunk = StrToInt(Copy(Digits, Position, ChunkLength));

    Result.MultiplyAdd(PowerOfTenWord(ChunkLength), Chunk);
    Inc(Position, ChunkLength);
  end;
end;

procedure TJSBigNatural.AppendWord(const Value: UInt32);
begin
  const IsFull = (FCount = Length(FWords));
  if IsFull then
    SetLength(FWords, (Length(FWords) * 2) + INITIAL_CAPACITY);

  FWords[FCount] := Value;
  Inc(FCount);
end;

procedure TJSBigNatural.DropLeadingZeroWords;
begin
  while (FCount > 0) and (FWords[FCount - 1] = 0) do
  begin
    Dec(FCount);
  end;
end;

function TJSBigNatural.Duplicate: TJSBigNatural;
begin
  Result.FWords := System.Copy(FWords);
  Result.FCount := FCount;
end;

function TJSBigNatural.BitLength: Integer;
begin
  if FCount = 0 then
    Exit(0);

  Result := ((FCount - 1) * WORD_BITS) + SignificantBits(FWords[FCount - 1]);
end;

function TJSBigNatural.CompareTo(const Other: TJSBigNatural): Integer;
begin
  const HasSameLength = (FCount = Other.FCount);
  if not HasSameLength then
  begin
    Result := CompareValue(FCount, Other.FCount);
    Exit;
  end;

  for var Index := FCount - 1 downto 0 do
  begin
    const Comparison = CompareValue(FWords[Index], Other.FWords[Index]);
    const IsDifferent = (Comparison <> 0);
    if IsDifferent then
      Exit(Comparison);
  end;

  Result := 0;
end;

procedure TJSBigNatural.MultiplyAdd(const Factor: UInt32; const Addend: UInt32);
begin
  var Carry: UInt64 := Addend;

  for var Index := 0 to FCount - 1 do
  begin
    const Product = (UInt64(FWords[Index]) * Factor) + Carry;
    FWords[Index] := UInt32(Product and WORD_MASK);
    Carry := Product shr WORD_BITS;
  end;

  const HasCarry = (Carry > 0);
  if HasCarry then
    AppendWord(UInt32(Carry));
end;

procedure TJSBigNatural.MultiplyByPowerOfTen(const Power: Integer);
begin
  var Remaining := Power;

  while Remaining >= DECIMAL_CHUNK_DIGITS do
  begin
    MultiplyAdd(PowerOfTenWord(DECIMAL_CHUNK_DIGITS), 0);
    Dec(Remaining, DECIMAL_CHUNK_DIGITS);
  end;

  const Factor = PowerOfTenWord(Remaining);
  const NeedsScaling = (Factor > 1);
  if NeedsScaling then
    MultiplyAdd(Factor, 0);
end;

procedure TJSBigNatural.ShiftLeft(const Bits: Integer);
begin
  if (FCount = 0) or (Bits = 0) then
    Exit;

  const WordShift = Bits div WORD_BITS;
  const BitShift = Bits mod WORD_BITS;

  var Shifted: TArray<UInt32>;
  SetLength(Shifted, FCount + WordShift + 1);

  for var Index := 0 to FCount - 1 do
  begin
    const Spread = UInt64(FWords[Index]) shl BitShift;
    const Target = Index + WordShift;
    Shifted[Target] := Shifted[Target] or UInt32(Spread and WORD_MASK);
    Shifted[Target + 1] := Shifted[Target + 1] or UInt32(Spread shr WORD_BITS);
  end;

  FWords := Shifted;
  FCount := Length(Shifted);
  DropLeadingZeroWords;
end;

procedure TJSBigNatural.ShiftRightOne;
begin
  var Carry: UInt32 := 0;

  for var Index := FCount - 1 downto 0 do
  begin
    const CurrentWord = FWords[Index];
    FWords[Index] := (CurrentWord shr 1) or (Carry shl (WORD_BITS - 1));
    Carry := CurrentWord and 1;
  end;

  DropLeadingZeroWords;
end;

function TJSBigNatural.TrySubtract(const Other: TJSBigNatural): Boolean;
begin
  const IsLargeEnough = (CompareTo(Other) >= 0);
  if IsLargeEnough then
    SubtractWords(Other);

  Result := IsLargeEnough;
end;

procedure TJSBigNatural.SubtractWords(const Other: TJSBigNatural);
begin
  var Borrow: Int64 := 0;

  for var Index := 0 to FCount - 1 do
  begin
    var OtherWord: Int64 := 0;
    const HasOtherWord = (Index < Other.FCount);
    if HasOtherWord then
      OtherWord := Other.FWords[Index];

    var Difference: Int64 := Int64(FWords[Index]) - OtherWord - Borrow;
    Borrow := 0;
    const IsBorrowing = (Difference < 0);
    if IsBorrowing then
    begin
      Inc(Difference, Int64(1) shl WORD_BITS);
      Borrow := 1;
    end;

    FWords[Index] := UInt32(Difference);
  end;

  DropLeadingZeroWords;
end;

end.
