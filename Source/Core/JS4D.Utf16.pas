unit JS4D.Utf16;

interface

const
  HIGH_SURROGATE_FIRST = $D800;
  HIGH_SURROGATE_LAST = $DBFF;
  LOW_SURROGATE_FIRST = $DC00;
  LOW_SURROGATE_LAST = $DFFF;
  FIRST_SUPPLEMENTARY_CODE_POINT = $10000;
  SURROGATE_PAYLOAD_BITS = 10;
  SURROGATE_PAYLOAD_MASK = $3FF;
  MAX_CODE_POINT = $10FFFF;

type
  TJSUtf16 = class
  public
    class function IsPairAt(const Text: string; const Index: Integer): Boolean; static;
    class function IsPairEndingAt(const Text: string; const Index: Integer): Boolean; static;
    class function CodePointAt(const Text: string; const Index: Integer; out Width: Integer): Integer; static;
    class function CodePointBefore(const Text: string; const Index: Integer; out Width: Integer): Integer; static;
  end;

implementation

uses
  System.Character;

class function TJSUtf16.IsPairAt(const Text: string; const Index: Integer): Boolean;
begin
  const HasNext = (Index < Length(Text));

  Result := (HasNext and Text[Index].IsHighSurrogate and Text[Index + 1].IsLowSurrogate);
end;

class function TJSUtf16.IsPairEndingAt(const Text: string; const Index: Integer): Boolean;
begin
  const HasPrevious = (Index > 1);

  Result := (HasPrevious and Text[Index].IsLowSurrogate and Text[Index - 1].IsHighSurrogate);
end;

class function TJSUtf16.CodePointAt(const Text: string; const Index: Integer; out Width: Integer): Integer;
begin
  Width := 1;
  Result := Ord(Text[Index]);

  if IsPairAt(Text, Index) then
  begin
    Width := 2;
    Result := Char.ConvertToUtf32(Text[Index], Text[Index + 1]);
  end;
end;

class function TJSUtf16.CodePointBefore(const Text: string; const Index: Integer; out Width: Integer): Integer;
begin
  Width := 1;
  Result := Ord(Text[Index]);

  if IsPairEndingAt(Text, Index) then
  begin
    Width := 2;
    Result := Char.ConvertToUtf32(Text[Index - 1], Text[Index]);
  end;
end;

end.
