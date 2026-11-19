unit JS4D.Binary64;

interface

type
  TJSDoubleBits = record
    case Boolean of
      False: (Bits: UInt64);
      True: (Value: Double);
  end;

const
  MANTISSA_BITS = 52;
  EXPONENT_BIAS = 1075;
  MAX_BIASED_EXPONENT = 2047;
  DENORMAL_EXPONENT = 1 - EXPONENT_BIAS;
  HIDDEN_BIT = UInt64(1) shl MANTISSA_BITS;
  MANTISSA_MASK = HIDDEN_BIT - 1;
  SINGLE_MANTISSA_BITS = 23;
  NEGATIVE_ZERO_BITS = UInt64($8000000000000000);

implementation

end.
