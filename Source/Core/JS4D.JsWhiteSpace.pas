unit JS4D.JsWhiteSpace;

interface

type
  TJSWhiteSpace = class
  public
    class function IsWhiteSpace(const Ch: Char): Boolean; static;
    class function TrimStart(const Text: string): string; static;
    class function TrimEnd(const Text: string): string; static;
    class function TrimBoth(const Text: string): string; static;
  end;

implementation

uses
  System.SysUtils;

{ TJSWhiteSpace }

class function TJSWhiteSpace.IsWhiteSpace(const Ch: Char): Boolean;
begin
  case Ch of
    #$0009, #$000A, #$000B, #$000C, #$000D, #$0020, #$00A0, #$1680,
    #$2000..#$200A, #$2028, #$2029, #$202F, #$205F, #$3000, #$FEFF:
      Result := True;
  else
    Result := False;
  end;
end;

class function TJSWhiteSpace.TrimStart(const Text: string): string;
begin
  var First := 1;
  while (First <= Length(Text)) and IsWhiteSpace(Text[First]) do
  begin
    Inc(First);
  end;

  Result := Text.Substring(First - 1);
end;

class function TJSWhiteSpace.TrimEnd(const Text: string): string;
begin
  var Last := Length(Text);
  while (Last >= 1) and IsWhiteSpace(Text[Last]) do
  begin
    Dec(Last);
  end;

  Result := Text.Substring(0, Last);
end;

class function TJSWhiteSpace.TrimBoth(const Text: string): string;
begin
  const WithoutLeading = TrimStart(Text);

  Result := TrimEnd(WithoutLeading);
end;

end.
