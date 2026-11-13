unit JS4D.PropertyKey;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  PJSPropertyKey = ^TJSPropertyKey;

  TJSPropertyKey = record
  private
    const
      SYMBOL_MARKER = Char($FDD0);
      ESCAPE_CHAR = 'S';
      NUMBER_START_CHARS = ['0'..'9', '-', 'I', 'N'];
      MARKER_LENGTH = 1;
      ESCAPE_PREFIX_LENGTH = 2;
      MIN_SYMBOL_STORED_LENGTH = 2;

    var
      FStored: string;
      FSymbolId: Integer;

    class function StartsWithMarker(const Text: string): Boolean; static; inline;
    class function IsSymbolStored(const Stored: string): Boolean; static; inline;

  public
    class function ForSymbol(const Id: Integer): TJSPropertyKey; static;
    class function FromStored(const Stored: string): TJSPropertyKey; static;
    class function CanStartNumber(const Text: string): Boolean; static; inline;

    class operator Implicit(const Text: string): TJSPropertyKey; inline;
    class operator Equal(const Left, Right: TJSPropertyKey): Boolean; inline;
    class operator Equal(const Key: TJSPropertyKey; const Text: string): Boolean; inline;
    class operator NotEqual(const Left, Right: TJSPropertyKey): Boolean; inline;
    class operator NotEqual(const Key: TJSPropertyKey; const Text: string): Boolean; inline;

    procedure SetText(const Text: string); inline;
    function IsSymbol: Boolean; inline;
    function IsEscaped: Boolean; inline;
    function Text: string; inline;

    property Stored: string read FStored;
    property SymbolId: Integer read FSymbolId;
  end;

implementation

class function TJSPropertyKey.ForSymbol(const Id: Integer): TJSPropertyKey;
begin
  Result.FStored := SYMBOL_MARKER + IntToStr(Id);
  Result.FSymbolId := Id;
end;

class function TJSPropertyKey.StartsWithMarker(const Text: string): Boolean;
begin
  Result := ((Text <> '') and (Text[1] = SYMBOL_MARKER));
end;

class function TJSPropertyKey.CanStartNumber(const Text: string): Boolean;
begin
  Result := ((Text <> '') and CharInSet(Text[1], NUMBER_START_CHARS));
end;

class function TJSPropertyKey.IsSymbolStored(const Stored: string): Boolean;
begin
  Result := (Length(Stored) >= MIN_SYMBOL_STORED_LENGTH) and
            (Stored[1] = SYMBOL_MARKER) and
            (Stored[2] <> ESCAPE_CHAR);
end;

class function TJSPropertyKey.FromStored(const Stored: string): TJSPropertyKey;
begin
  Result.FStored := Stored;
  Result.FSymbolId := 0;

  if IsSymbolStored(Stored) then
  begin
    const Digits = Copy(Stored, MARKER_LENGTH + 1, Length(Stored));
    Result.FSymbolId := StrToIntDef(Digits, 0);
  end;
end;

class operator TJSPropertyKey.Implicit(const Text: string): TJSPropertyKey;
begin
  Result.SetText(Text);
end;

class operator TJSPropertyKey.Equal(const Left, Right: TJSPropertyKey): Boolean;
begin
  Result := (Left.FStored = Right.FStored);
end;

class operator TJSPropertyKey.Equal(const Key: TJSPropertyKey; const Text: string): Boolean;
begin
  if StartsWithMarker(Text) then
  begin
    const IsSameStringKey = ((Key.FSymbolId = 0) and (Key.Text = Text));
    Result := IsSameStringKey;
  end
  else
  begin
    Result := (Key.FStored = Text);
  end;
end;

class operator TJSPropertyKey.NotEqual(const Left, Right: TJSPropertyKey): Boolean;
begin
  Result := (Left.FStored <> Right.FStored);
end;

class operator TJSPropertyKey.NotEqual(const Key: TJSPropertyKey; const Text: string): Boolean;
begin
  Result := not (Key = Text);
end;

procedure TJSPropertyKey.SetText(const Text: string);
begin
  FSymbolId := 0;

  if StartsWithMarker(Text) then
  begin
    FStored := SYMBOL_MARKER + ESCAPE_CHAR + Text;
  end
  else
  begin
    FStored := Text;
  end;
end;

function TJSPropertyKey.IsSymbol: Boolean;
begin
  Result := (FSymbolId <> 0);
end;

function TJSPropertyKey.IsEscaped: Boolean;
begin
  Result := ((FSymbolId = 0) and StartsWithMarker(FStored));
end;

function TJSPropertyKey.Text: string;
begin
  if IsEscaped then
  begin
    Result := Copy(FStored, ESCAPE_PREFIX_LENGTH + 1, Length(FStored));
  end
  else
  begin
    Result := FStored;
  end;
end;

end.
