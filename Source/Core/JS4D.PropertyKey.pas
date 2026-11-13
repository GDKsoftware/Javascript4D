unit JS4D.PropertyKey;

{$SCOPEDENUMS ON}

interface

type
  PJSPropertyKey = ^TJSPropertyKey;

  // The name of a property: either a string or a symbol. A key made from a string never equals the key of a
  // symbol, whatever characters the string holds. Objects store a key under its stored form; that form is
  // unique per key, so one map can hold the string keys and the symbol keys of an object side by side.
  TJSPropertyKey = record
  private
    const
      SYMBOL_MARKER = Char($FDD0);
      ESCAPE_CHAR = 'S';
      SKIPPED_PREFIX_LENGTH = 2;

    var
      FStored: string;
      FSymbolId: Integer;

  public
    class function ForSymbol(const Id: Integer): TJSPropertyKey; static;
    class function FromStored(const Stored: string): TJSPropertyKey; static;
    class function IsSymbolStored(const Stored: string): Boolean; static; inline;

    class operator Implicit(const Text: string): TJSPropertyKey; inline;
    class operator Equal(const Left, Right: TJSPropertyKey): Boolean; inline;
    class operator Equal(const Key: TJSPropertyKey; const Text: string): Boolean; inline;
    class operator NotEqual(const Left, Right: TJSPropertyKey): Boolean; inline;
    class operator NotEqual(const Key: TJSPropertyKey; const Text: string): Boolean; inline;

    // Makes this key the string key of Text, without building a second key to copy from.
    procedure SetText(const Text: string); inline;
    function IsSymbol: Boolean; inline;
    // True for a string key whose text starts with the character that marks symbol keys.
    function IsEscaped: Boolean; inline;
    // The text of a string key. A symbol key has no text of its own: its stored form is returned.
    function Text: string; inline;

    property Stored: string read FStored;
    property SymbolId: Integer read FSymbolId;
  end;

implementation

uses
  System.SysUtils;

class function TJSPropertyKey.ForSymbol(const Id: Integer): TJSPropertyKey;
begin
  Result.FStored := SYMBOL_MARKER + IntToStr(Id);
  Result.FSymbolId := Id;
end;

class function TJSPropertyKey.IsSymbolStored(const Stored: string): Boolean;
begin
  Result := (Length(Stored) >= SKIPPED_PREFIX_LENGTH) and
            (Stored[1] = SYMBOL_MARKER) and
            (Stored[2] <> ESCAPE_CHAR);
end;

class function TJSPropertyKey.FromStored(const Stored: string): TJSPropertyKey;
begin
  Result.FStored := Stored;
  Result.FSymbolId := 0;

  if IsSymbolStored(Stored) then
    Result.FSymbolId := StrToIntDef(Copy(Stored, 2, Length(Stored) - 1), 0);
end;

class operator TJSPropertyKey.Implicit(const Text: string): TJSPropertyKey;
begin
  Result.FSymbolId := 0;

  const NeedsEscape = (Text <> '') and (Text[1] = SYMBOL_MARKER);
  if NeedsEscape then
    Result.FStored := SYMBOL_MARKER + ESCAPE_CHAR + Text
  else
    Result.FStored := Text;
end;

class operator TJSPropertyKey.Equal(const Left, Right: TJSPropertyKey): Boolean;
begin
  Result := Left.FStored = Right.FStored;
end;

class operator TJSPropertyKey.Equal(const Key: TJSPropertyKey; const Text: string): Boolean;
begin
  const MayBeMarked = (Text <> '') and (Text[1] = SYMBOL_MARKER);
  if MayBeMarked then
    Exit((Key.FSymbolId = 0) and (Key.Text = Text));

  Result := Key.FStored = Text;
end;

class operator TJSPropertyKey.NotEqual(const Left, Right: TJSPropertyKey): Boolean;
begin
  Result := Left.FStored <> Right.FStored;
end;

class operator TJSPropertyKey.NotEqual(const Key: TJSPropertyKey; const Text: string): Boolean;
begin
  Result := not (Key = Text);
end;

procedure TJSPropertyKey.SetText(const Text: string);
begin
  FSymbolId := 0;

  const NeedsEscape = (Text <> '') and (Text[1] = SYMBOL_MARKER);
  if NeedsEscape then
    FStored := SYMBOL_MARKER + ESCAPE_CHAR + Text
  else
    FStored := Text;
end;

function TJSPropertyKey.IsSymbol: Boolean;
begin
  Result := FSymbolId <> 0;
end;

function TJSPropertyKey.IsEscaped: Boolean;
begin
  Result := (FSymbolId = 0) and (FStored <> '') and (FStored[1] = SYMBOL_MARKER);
end;

function TJSPropertyKey.Text: string;
begin
  if IsEscaped then
    Result := Copy(FStored, SKIPPED_PREFIX_LENGTH + 1, Length(FStored))
  else
    Result := FStored;
end;

end.
