unit JS4D.UnicodeNormalization;

{$SCOPEDENUMS ON}

interface

uses
  Winapi.Windows;

type
  TJSNormalizationForm = (NFC, NFD, NFKC, NFKD);

  TJSUnicodeNormalization = class
  private
    class function ToNormForm(const Form: TJSNormalizationForm): TNormForm; static;
    class function IsLoneSurrogate(const Text: string; const Index: Integer): Boolean; static;
    class function NormalizeRun(const Text: string; const Form: TJSNormalizationForm): string; static;

  public
    class function TryParseForm(const Name: string; out Form: TJSNormalizationForm): Boolean; static;
    class function Normalize(const Text: string; const Form: TJSNormalizationForm): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Character;

type
  TFormName = record
    Name: string;
    Form: TJSNormalizationForm;
  end;

const
  NORMALIZATION_FAILED_MESSAGE = 'The string could not be normalized: %s';
  UNSUPPORTED_FORM = 'Unsupported normalization form: %d';
  FORM_NAMES: array[0..3] of TFormName = (
    (Name: 'NFC'; Form: TJSNormalizationForm.NFC),
    (Name: 'NFD'; Form: TJSNormalizationForm.NFD),
    (Name: 'NFKC'; Form: TJSNormalizationForm.NFKC),
    (Name: 'NFKD'; Form: TJSNormalizationForm.NFKD)
  );

class function TJSUnicodeNormalization.ToNormForm(const Form: TJSNormalizationForm): TNormForm;
begin
  case Form of
    TJSNormalizationForm.NFC  : Result := TNormForm.NormalizationC;
    TJSNormalizationForm.NFD  : Result := TNormForm.NormalizationD;
    TJSNormalizationForm.NFKC : Result := TNormForm.NormalizationKC;
    TJSNormalizationForm.NFKD : Result := TNormForm.NormalizationKD;
  else
    raise ENotSupportedException.CreateFmt(UNSUPPORTED_FORM, [Ord(Form)]);
  end;
end;

class function TJSUnicodeNormalization.TryParseForm(const Name: string; out Form: TJSNormalizationForm): Boolean;
begin
  Result := False;

  for var Entry in FORM_NAMES do
  begin
    const IsMatch = (Entry.Name = Name);
    if IsMatch then
    begin
      Form := Entry.Form;
      Result := True;
      Exit;
    end;
  end;
end;

class function TJSUnicodeNormalization.IsLoneSurrogate(const Text: string; const Index: Integer): Boolean;
begin
  const Current = Text[Index];
  if not Current.IsSurrogate then
    Exit(False);

  const HasNext = (Index < Length(Text));
  const FormsPair = Current.IsHighSurrogate and HasNext and Text[Index + 1].IsLowSurrogate;
  const IsSecondOfPair = Current.IsLowSurrogate and (Index > 1) and Text[Index - 1].IsHighSurrogate;

  Result := not (FormsPair or IsSecondOfPair);
end;

class function TJSUnicodeNormalization.NormalizeRun(const Text: string; const Form: TJSNormalizationForm): string;
begin
  if Text.IsEmpty then
    Exit(Text);

  const NormForm = ToNormForm(Form);

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

class function TJSUnicodeNormalization.Normalize(const Text: string; const Form: TJSNormalizationForm): string;
begin
  const Builder = TStringBuilder.Create;
  try
    var RunStart := 1;
    for var Index := 1 to Length(Text) do
    begin
      if not IsLoneSurrogate(Text, Index) then
        Continue;

      Builder.Append(NormalizeRun(Copy(Text, RunStart, Index - RunStart), Form));
      Builder.Append(Text[Index]);
      RunStart := Index + 1;
    end;

    Builder.Append(NormalizeRun(Copy(Text, RunStart, MaxInt), Form));
    Result := Builder.ToString;
  finally
    Builder.Free;
  end;
end;

end.
