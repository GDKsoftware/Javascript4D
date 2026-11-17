unit JS4D.RegExpCharacters;

interface

type
  TJSRegExpCharacters = class
  public
    class function NextClassState(const Current: Char; const InsideClass: Boolean): Boolean; static;
  end;

const
  BACKSLASH = '\';
  CLASS_OPEN = '[';
  CLASS_CLOSE = ']';
  GROUP_OPEN = '(';
  GROUP_CLOSE = ')';
  ALTERNATION = '|';
  QUANTIFIER_OPEN = '{';
  QUANTIFIER_CLOSE = '}';
  BOUND_SEPARATOR = ',';
  UNICODE_ESCAPE_MARK = 'u';
  HEX_ESCAPE_MARK = 'x';
  CONTROL_ESCAPE_MARK = 'c';
  QUANTIFIER_MARKS = ['*', '+', '?'];
  ASCII_LETTERS = ['a'..'z', 'A'..'Z'];
  ESCAPE_LENGTH = 2;
  CONTROL_CODE_MODULUS = 32;

implementation

{ TJSRegExpCharacters }

class function TJSRegExpCharacters.NextClassState(const Current: Char; const InsideClass: Boolean): Boolean;
begin
  if Current = CLASS_OPEN then
    Exit(True);

  if Current = CLASS_CLOSE then
    Exit(False);

  Result := InsideClass;
end;

end.
