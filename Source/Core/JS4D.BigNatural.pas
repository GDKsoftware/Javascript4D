unit JS4D.BigNatural;

{$SCOPEDENUMS ON}

interface

type
  TJSBigNatural = record
  private
    const
      WORD_BITS = 32;
      WORD_MASK = UInt64($FFFFFFFF);
      DECIMAL_CHUNK_DIGITS = 9;
      DECIMAL_CHUNK_BASE = 1000000000;
      INITIAL_CAPACITY = 4;

    var
      FWords: TArray<UInt32>;
      FCount: Integer;

    procedure AppendWord(const Value: UInt32);
    procedure DropLeadingZeroWords;

  public
    class function FromDigits(const Digits: string): TJSBigNatural; static;
    class function FromWord(const Value: UInt32): TJSBigNatural; static;

    function Duplicate: TJSBigNatural;
    function BitLength: Integer;
    function CompareTo(const Other: TJSBigNatural): Integer;
    procedure MultiplyAdd(const Factor: UInt32; const Addend: UInt32);
    procedure MultiplyByPowerOfTen(const Power: Integer);
    procedure ShiftLeft(const Bits: Integer);
    procedure Subtract(const Other: TJSBigNatural);
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

  if Value > 0 then
    Result.AppendWord(Value);
end;

class function TJSBigNatural.FromDigits(const Digits: string): TJSBigNatural;
begin
  Result := FromWord(0);

  var Position := 1;
  while Position <= Length(Digits) do
  begin
    const ChunkLength = Min(DECIMAL_CHUNK_DIGITS, Length(Digits) - Position + 1);
    const Chunk = StrToInt(Copy(Digits, Position, ChunkLength));

    var Factor: UInt32 := 1;
    for var Step := 1 to ChunkLength do
    begin
      Factor := Factor * 10;
    end;

    Result.MultiplyAdd(Factor, Chunk);
    Inc(Position, ChunkLength);
  end;
end;

procedure TJSBigNatural.AppendWord(const Value: UInt32);
begin
  if FCount = Length(FWords) then
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

  var TopWord := FWords[FCount - 1];
  var TopBits := 0;
  while TopWord > 0 do
  begin
    Inc(TopBits);
    TopWord := TopWord shr 1;
  end;

  Result := ((FCount - 1) * WORD_BITS) + TopBits;
end;

function TJSBigNatural.CompareTo(const Other: TJSBigNatural): Integer;
begin
  if FCount <> Other.FCount then
    Exit(FCount - Other.FCount);

  for var Index := FCount - 1 downto 0 do
  begin
    if FWords[Index] <> Other.FWords[Index] then
    begin
      if FWords[Index] > Other.FWords[Index] then
        Exit(1);

      Exit(-1);
    end;
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

  if Carry > 0 then
    AppendWord(UInt32(Carry));
end;

procedure TJSBigNatural.MultiplyByPowerOfTen(const Power: Integer);
begin
  var Remaining := Power;

  while Remaining >= DECIMAL_CHUNK_DIGITS do
  begin
    MultiplyAdd(DECIMAL_CHUNK_BASE, 0);
    Dec(Remaining, DECIMAL_CHUNK_DIGITS);
  end;

  var Factor: UInt32 := 1;
  for var Step := 1 to Remaining do
  begin
    Factor := Factor * 10;
  end;

  if Factor > 1 then
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

procedure TJSBigNatural.Subtract(const Other: TJSBigNatural);
begin
  var Borrow: Int64 := 0;

  for var Index := 0 to FCount - 1 do
  begin
    var OtherWord: Int64 := 0;
    if Index < Other.FCount then
      OtherWord := Other.FWords[Index];

    var Difference: Int64 := Int64(FWords[Index]) - OtherWord - Borrow;
    Borrow := 0;
    if Difference < 0 then
    begin
      Inc(Difference, Int64(1) shl WORD_BITS);
      Borrow := 1;
    end;

    FWords[Index] := UInt32(Difference);
  end;

  DropLeadingZeroWords;
end;

end.
