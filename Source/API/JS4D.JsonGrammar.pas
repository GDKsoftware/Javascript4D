unit JS4D.JsonGrammar;

interface

const
  JSON_WHITE_SPACE = [' ', #9, #10, #13];
  JSON_NUMBER_CHARACTERS = ['0'..'9', '-', '+', '.', 'e', 'E'];
  JSON_QUOTE = '"';
  JSON_ESCAPE = '\';
  JSON_OBJECT_START = '{';
  JSON_OBJECT_END = '}';
  JSON_ARRAY_START = '[';
  JSON_ARRAY_END = ']';
  JSON_COMMA = ',';
  JSON_COLON = ':';
  JSON_MINUS = '-';
  JSON_PLUS = '+';
  JSON_DECIMAL_POINT = '.';
  JSON_ZERO = '0';
  JSON_EXPONENT_LOWER = 'e';
  JSON_EXPONENT_UPPER = 'E';
  JSON_UNICODE_ESCAPE = 'u';
  JSON_TRUE_START = 't';
  JSON_FALSE_START = 'f';
  JSON_NULL_START = 'n';
  JSON_TRUE_LITERAL = 'true';
  JSON_FALSE_LITERAL = 'false';
  JSON_NULL_LITERAL = 'null';
  JSON_UNICODE_ESCAPE_DIGITS = 4;

implementation

end.
