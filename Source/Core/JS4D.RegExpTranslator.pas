unit JS4D.RegExpTranslator;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils;

type
  TJSRegExpTranslator = class
  private
    const
      WHITE_SPACE_SET = '\t\n\u000b\f\r \u00a0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000\ufeff';
      NON_WHITE_SPACE_SET = '\u0000-\u0008\u000e-\u001f\u0021-\u009f\u00a1-\u167f\u1681-\u1fff' +
                            '\u200b-\u2027\u202a-\u202e\u2030-\u205e\u2060-\u2fff\u3001-\ufefe\uff00-' + #$DBFF#$DFFF;
      ESCAPE_LENGTH = 2;
      CONTROL_ESCAPE_LENGTH = 3;
      CONTROL_CODE_MODULUS = 32;
      LITERAL_BACKSLASH_CONTROL = '\\c';
      BACKSLASH = '\';
      CLASS_OPEN = '[';
      CLASS_CLOSE = ']';

    var
      FPattern: string;
      FPosition: Integer;
      FInsideClass: Boolean;
      FOutput: TStringBuilder;

    constructor Create(const Pattern: string);

    function Run: string;
    function HasLetterAfterControlMarker: Boolean;

    procedure TranslateEscape;
    procedure AppendWhiteSpaceEscape(const Negated: Boolean);
    procedure AppendControlEscape;
    procedure AppendPlainCharacter;

  public
    class function Translate(const Pattern: string): string; static;

    destructor Destroy; override;
  end;

implementation

{ TJSRegExpTranslator }

class function TJSRegExpTranslator.Translate(const Pattern: string): string;
begin
  const Translator = TJSRegExpTranslator.Create(Pattern);
  try
    Result := Translator.Run;
  finally
    Translator.Free;
  end;
end;

constructor TJSRegExpTranslator.Create(const Pattern: string);
begin
  inherited Create;
  FPattern := Pattern;
  FPosition := 1;
  FOutput := TStringBuilder.Create;
end;

destructor TJSRegExpTranslator.Destroy;
begin
  FOutput.Free;
  inherited Destroy;
end;

function TJSRegExpTranslator.Run: string;
begin
  while FPosition <= Length(FPattern) do
  begin
    const IsEscape = (FPattern[FPosition] = BACKSLASH);
    if IsEscape then
    begin
      TranslateEscape;
    end
    else
    begin
      AppendPlainCharacter;
    end;
  end;

  Result := FOutput.ToString;
end;

procedure TJSRegExpTranslator.AppendPlainCharacter;
begin
  const Character = FPattern[FPosition];

  if (Character = CLASS_OPEN) and not FInsideClass then
  begin
    FInsideClass := True;
  end
  else if (Character = CLASS_CLOSE) and FInsideClass then
  begin
    FInsideClass := False;
  end;

  FOutput.Append(Character);
  Inc(FPosition);
end;

procedure TJSRegExpTranslator.TranslateEscape;
begin
  const HasEscapedCharacter = (FPosition < Length(FPattern));
  if not HasEscapedCharacter then
  begin
    FOutput.Append(BACKSLASH);
    Inc(FPosition);
    Exit;
  end;

  const Escaped = FPattern[FPosition + 1];
  case Escaped of
    's' : AppendWhiteSpaceEscape(False);
    'S' : AppendWhiteSpaceEscape(True);
    'c' : AppendControlEscape;
  else
    FOutput.Append(Copy(FPattern, FPosition, ESCAPE_LENGTH));
    Inc(FPosition, ESCAPE_LENGTH);
  end;
end;

procedure TJSRegExpTranslator.AppendWhiteSpaceEscape(const Negated: Boolean);
begin
  var CharacterSet := WHITE_SPACE_SET;
  if Negated then
  begin
    CharacterSet := NON_WHITE_SPACE_SET;
  end;

  if FInsideClass then
  begin
    FOutput.Append(CharacterSet);
  end
  else
  begin
    FOutput.Append(CLASS_OPEN);
    FOutput.Append(CharacterSet);
    FOutput.Append(CLASS_CLOSE);
  end;

  Inc(FPosition, ESCAPE_LENGTH);
end;

procedure TJSRegExpTranslator.AppendControlEscape;
begin
  if not HasLetterAfterControlMarker then
  begin
    FOutput.Append(LITERAL_BACKSLASH_CONTROL);
    Inc(FPosition, ESCAPE_LENGTH);
    Exit;
  end;

  const ControlCode = Ord(FPattern[FPosition + ESCAPE_LENGTH]) mod CONTROL_CODE_MODULUS;
  FOutput.Append(Format('\u%.4x', [ControlCode]));
  Inc(FPosition, CONTROL_ESCAPE_LENGTH);
end;

function TJSRegExpTranslator.HasLetterAfterControlMarker: Boolean;
begin
  const HasNextCharacter = (FPosition + ESCAPE_LENGTH <= Length(FPattern));
  if not HasNextCharacter then
    Exit(False);

  Result := CharInSet(FPattern[FPosition + ESCAPE_LENGTH], ['A'..'Z', 'a'..'z']);
end;

end.
