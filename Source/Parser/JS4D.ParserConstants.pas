unit JS4D.ParserConstants;

{$SCOPEDENUMS ON}

interface

const
  ASYNC_FUNCTION = True;
  NOT_ASYNC = False;
  GENERATOR_ALLOWED = True;
  GENERATOR_NOT_ALLOWED = False;
  NOT_A_GENERATOR = False;
  NAME_REQUIRED = True;
  NAME_OPTIONAL = False;
  LINE_BREAK_ALLOWED = True;
  LINE_BREAK_NOT_ALLOWED = False;
  LABELLED_FUNCTION_ALLOWED = True;
  LABELLED_FUNCTION_NOT_ALLOWED = False;
  IN_OPERATOR_ALLOWED = True;
  IN_OPERATOR_NOT_ALLOWED = False;
  INITIALIZER_NOT_REQUIRED = False;
  DECLARATION_HEAD = True;
  EXPRESSION_HEAD = False;
  FOR_OF_LOOP = True;
  FOR_IN_LOOP = False;
  COMPUTED_KEY = True;
  PLAIN_KEY = False;
  PREFIX_OPERATOR = True;
  POSTFIX_OPERATOR = False;
  TAGGED_TEMPLATE = True;
  UNTAGGED_TEMPLATE = False;
  NOT_A_FUNCTION_NAME = False;
  NO_FUNCTION_DUPLICATE = False;
  NO_LABEL = -1;
  PROGRAM_FIRST_TOKEN_OFFSET = 0;
  FUNCTION_BODY_FIRST_TOKEN_OFFSET = 1;
  GETTER_PARAMETER_COUNT = 0;
  SETTER_PARAMETER_COUNT = 1;
  PRECEDENCE_LOGICAL_OR = 1;
  PRECEDENCE_LOGICAL_AND = 2;
  PRECEDENCE_BITWISE_OR = 3;
  PRECEDENCE_BITWISE_XOR = 4;
  PRECEDENCE_BITWISE_AND = 5;
  PRECEDENCE_EQUALITY = 6;
  PRECEDENCE_RELATIONAL = 7;
  PRECEDENCE_SHIFT = 8;
  PRECEDENCE_ADDITIVE = 9;
  PRECEDENCE_MULTIPLICATIVE = 10;
  USE_STRICT_DIRECTIVE = 'use strict';
  MAX_NESTING_DEPTH = 1000;
  CONSTRUCTOR_NAME = 'constructor';
  PROTOTYPE_NAME = 'prototype';
  TARGET_NAME = 'target';
  NESTING_TOO_DEEP_MESSAGE = 'The source nests parentheses, blocks or classes too deeply';
  LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE = 'Octal literals and escape sequences are not allowed in strict mode';
  SUPER_OUTSIDE_METHOD_MESSAGE = '''super'' keyword unexpected here';
  NEW_TARGET_OUTSIDE_FUNCTION_MESSAGE = 'new.target is only allowed inside functions';
  CLASS_DECLARATION_BODY_MESSAGE = 'Class declaration cannot appear in a single-statement context';
  DUPLICATE_CONSTRUCTOR_MESSAGE = 'A class may only have one constructor';
  SPECIAL_CONSTRUCTOR_MESSAGE = 'Class constructor may not be an accessor';
  CONSTRUCTOR_NOT_PLAIN_MESSAGE = 'Class constructor may not be a generator or an async method';
  STATIC_PROTOTYPE_MESSAGE = 'Classes may not have a static property named ''prototype''';
  CLASS_FIELD_MESSAGE = 'Class fields are not supported';
  NEW_SUPER_MESSAGE = '''super'' cannot be used with new';
  ACCESSOR_PARAMETER_COUNT_MESSAGE = 'Getter must not have parameters and setter must have exactly one';
  DUPLICATE_PROTOTYPE_MESSAGE = 'Duplicate __proto__ fields are not allowed in object literals';
  RESTRICTED_PARAMETER_NAME_MESSAGE = 'Parameter name ''%s'' is not allowed in strict mode';
  RESTRICTED_BINDING_NAME_MESSAGE = '''%s'' cannot be declared in strict mode';
  DELETE_IDENTIFIER_MESSAGE = 'Delete of an unqualified identifier in strict mode';
  UNARY_BEFORE_EXPONENT_MESSAGE = 'Unary operator used immediately before exponentiation expression';
  UNDEFINED_LABEL_MESSAGE = 'Undefined label ''%s''';
  DUPLICATE_LABEL_MESSAGE = 'Label ''%s'' has already been declared';
  CONTINUE_TARGET_NOT_LOOP_MESSAGE = 'Label ''%s'' does not label an iteration statement';
  ILLEGAL_RETURN_MESSAGE = 'Illegal return statement';
  ILLEGAL_BREAK_MESSAGE = 'Illegal break statement';
  ILLEGAL_CONTINUE_MESSAGE = 'Illegal continue statement';
  ILLEGAL_THROW_NEWLINE_MESSAGE = 'Illegal newline after throw';
  MISSING_CATCH_OR_FINALLY_MESSAGE = 'Missing catch or finally after try';
  WITH_IN_STRICT_MODE_MESSAGE = 'with statement is not allowed in strict mode';
  WITH_BODY_DECLARATION_MESSAGE = 'Declaration is not allowed as the body of a with statement';
  LABELLED_BODY_DECLARATION_MESSAGE = 'Declaration is not allowed as the body of a labelled statement';
  INVALID_ASSIGNMENT_TARGET_MESSAGE = 'Invalid left-hand side in assignment';
  DUPLICATE_STRICT_PARAMETER_MESSAGE = 'Duplicate parameter name not allowed in strict mode';
  DUPLICATE_DEFAULT_MESSAGE = 'More than one default clause in switch statement';
  FUNCTION_DECLARATION_BODY_MESSAGE = 'Function declaration is not allowed as the body of a statement';
  LEXICAL_DECLARATION_BODY_MESSAGE = 'Lexical declaration cannot appear in a single-statement context';
  REDECLARATION_MESSAGE = 'Identifier ''%s'' has already been declared';
  MISSING_CONST_INITIALIZER_MESSAGE = 'Missing initializer in const declaration';
  LET_BINDING_NAME_MESSAGE = 'let is disallowed as a lexically bound name';
  FOR_IN_INITIALIZER_MESSAGE = 'for-in loop variable declaration may not have an initializer';
  FOR_OF_HEAD_MESSAGE = 'for-of loop head must declare a single binding without an initializer';
  ASYNC_OF_HEAD_MESSAGE = 'The left-hand side of a for-of loop may not be async';
  DUPLICATE_ARROW_PARAMETER_MESSAGE = 'Duplicate parameter name not allowed in arrow functions';
  DUPLICATE_NON_SIMPLE_PARAMETER_MESSAGE = 'Duplicate parameter name not allowed with default or rest parameters';
  STRICT_NON_SIMPLE_PARAMETERS_MESSAGE = '''use strict'' directive not allowed in a function ' +
                                         'with default or rest parameters';
  REST_PARAMETER_NOT_LAST_MESSAGE = 'Rest parameter must be last formal parameter';
  INVALID_TEMPLATE_ESCAPE_MESSAGE = 'Invalid escape sequence in template literal';
  STRICT_RESERVED_WORD_MESSAGE = 'Use of future reserved word in strict mode: %s';
  YIELD_IDENTIFIER_MESSAGE = '''yield'' cannot be used as an identifier in a generator';
  YIELD_IN_PARAMETERS_MESSAGE = 'A yield expression is not allowed in formal parameters';
  YIELD_ESCAPE_MESSAGE = 'The keyword ''yield'' must not contain escaped characters';
  GENERATOR_DECLARATION_BODY_MESSAGE = 'Generator declaration is not allowed as the body of a statement';
  ASYNC_DECLARATION_BODY_MESSAGE = 'Async function declaration is not allowed as the body of a statement';
  ASYNC_GENERATOR_MESSAGE = 'Async generators are not supported';
  AWAIT_IDENTIFIER_MESSAGE = '''await'' cannot be used as an identifier in an async function';
  AWAIT_IN_PARAMETERS_MESSAGE = 'An await expression is not allowed in formal parameters';
  AWAIT_ESCAPE_MESSAGE = 'The keyword ''await'' must not contain escaped characters';
  PATTERN_PARAMETER_FORMAT = '(pattern %d)';
  REST_PATTERN_NAME = '(rest pattern)';
  MISSING_PATTERN_INITIALIZER_MESSAGE = 'Missing initializer in destructuring declaration';
  COVER_INITIALIZER_MESSAGE = 'Invalid shorthand property initializer';
  NULLISH_MIXED_WITH_LOGICAL_MESSAGE = '''??'' cannot be mixed with ''||'' or ''&&'' without parentheses';
  DUPLICATE_BINDING_MESSAGE = 'Duplicate binding ''%s'' in a pattern';

implementation

end.
