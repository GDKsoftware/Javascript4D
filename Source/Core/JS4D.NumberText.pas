unit JS4D.NumberText;

interface

type
  TJSNumberText = class
  public
    class function PadLeft(const Digits: string; const Count: Integer): string; static;
    class function PadRight(const Digits: string; const Count: Integer): string; static;
  end;

const
  NAN_TEXT = 'NaN';
  INFINITY_TEXT = 'Infinity';
  NEGATIVE_INFINITY_TEXT = '-Infinity';
  MINUS_SIGN = '-';

implementation

uses
  System.SysUtils,
  System.Math;

{ TJSNumberText }

class function TJSNumberText.PadLeft(const Digits: string; const Count: Integer): string;
begin
  Result := StringOfChar('0', Max(0, Count - Length(Digits))) + Digits;
end;

class function TJSNumberText.PadRight(const Digits: string; const Count: Integer): string;
begin
  Result := Digits + StringOfChar('0', Max(0, Count - Length(Digits)));
end;

end.
