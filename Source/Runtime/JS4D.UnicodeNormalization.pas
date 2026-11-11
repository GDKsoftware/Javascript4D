unit JS4D.UnicodeNormalization;

{$SCOPEDENUMS ON}

interface

type
  TJSNormalizationForm = (NFC, NFD, NFKC, NFKD);

  TJSUnicodeNormalization = class
  private
    class function ToNormForm(const Form: TJSNormalizationForm): Integer; static;
  public
    class function TryParseForm(const Name: string; out Form: TJSNormalizationForm): Boolean; static;
    class function Normalize(const Text: string; const Form: TJSNormalizationForm): string; static;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows;

const
  NORMALIZATION_C = 1;
  NORMALIZATION_D = 2;
  NORMALIZATION_KC = 5;
  NORMALIZATION_KD = 6;
  NORMALIZATION_FAILED_MESSAGE = 'The string could not be normalized: %s';

class function TJSUnicodeNormalization.ToNormForm(const Form: TJSNormalizationForm): Integer;
begin
  case Form of
    TJSNormalizationForm.NFC  : Result := NORMALIZATION_C;
    TJSNormalizationForm.NFD  : Result := NORMALIZATION_D;
    TJSNormalizationForm.NFKC : Result := NORMALIZATION_KC;
    TJSNormalizationForm.NFKD : Result := NORMALIZATION_KD;
  else
    raise ENotSupportedException.CreateFmt('Unsupported normalization form: %d', [Ord(Form)]);
  end;
end;

class function TJSUnicodeNormalization.TryParseForm(const Name: string; out Form: TJSNormalizationForm): Boolean;
begin
  Result := True;

  if Name = 'NFC' then
    Form := TJSNormalizationForm.NFC
  else if Name = 'NFD' then
    Form := TJSNormalizationForm.NFD
  else if Name = 'NFKC' then
    Form := TJSNormalizationForm.NFKC
  else if Name = 'NFKD' then
    Form := TJSNormalizationForm.NFKD
  else
    Result := False;
end;

class function TJSUnicodeNormalization.Normalize(const Text: string; const Form: TJSNormalizationForm): string;
begin
  if Text.IsEmpty then
    Exit(Text);

  const NormForm = TNormForm(ToNormForm(Form));

  var Capacity := NormalizeString(NormForm, PChar(Text), Length(Text), nil, 0);

  while Capacity > 0 do
  begin
    var Buffer: string;
    SetLength(Buffer, Capacity);

    const Written = NormalizeString(NormForm, PChar(Text), Length(Text), PChar(Buffer), Capacity);
    if Written > 0 then
    begin
      SetLength(Buffer, Written);
      Exit(Buffer);
    end;

    const IsBufferTooSmall = (GetLastError = ERROR_INSUFFICIENT_BUFFER);
    if not IsBufferTooSmall then
      Break;

    Capacity := Capacity * 2;
  end;

  raise EArgumentException.CreateFmt(NORMALIZATION_FAILED_MESSAGE, [SysErrorMessage(GetLastError)]);
end;

end.
