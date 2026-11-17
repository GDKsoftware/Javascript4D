unit JS4D.Parser;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.StrUtils,
  System.Generics.Collections,
  JS4D.Tokens,
  JS4D.Lexer,
  JS4D.AST,
  JS4D.SourceContext,
  JS4D.ParserScope,
  JS4D.Errors,
  JS4D.RegExpSyntax;

type
  TJSBindingKind = (Var_, Lexical, Parameter, Catch);

  TJSLabelInfo = record
    Name: string;
    LabelsIteration: Boolean;
  end;

  TJSFunctionContext = (Ordinary, Method, DerivedConstructor);

  TJSFunctionState = record
    Context: TJSSourceContext;
    InGenerator: Boolean;
    YieldForbidden: Boolean;
    InAsync: Boolean;
    AwaitForbidden: Boolean;
  end;

  TJSClassMemberHead = record
    KeyText: string;
    IsStatic: Boolean;
    IsGenerator: Boolean;
    IsAsync: Boolean;
    Computed: Boolean;
    Kind: TJSPropertyKind;
    SourceStart: Integer;

    function IsConstructor: Boolean;
  end;

  TJSOperandParser = function: TJSExpression of object;

  TJSParser = class
  private
    FLexer: TJSLexer;
    FOwnsLexer: Boolean;
    FPreviousTokenLine: Integer;
    FStrictMode: Boolean;
    FInOperatorAllowed: Boolean;
    FActiveLabels: TList<TJSLabelInfo>;
    FLabelScopeStart: Integer;
    FLoopDepth: Integer;
    FSwitchDepth: Integer;
    FFunctionDepth: Integer;
    FScopes: TJSScopeTracker;
    FClosureCount: Integer;
    FAllowLabelledFunction: Boolean;
    FInLiteralElement: Boolean;
    FCoverInitializerCount: Integer;
    FContext: TJSSourceContext;
    FNestingDepth: Integer;
    FStackFloor: NativeUInt;
    FInGenerator: Boolean;
    FYieldForbidden: Boolean;
    FInAsync: Boolean;
    FAwaitForbidden: Boolean;

    procedure EnterNesting;
    procedure LeaveNesting; inline;
    function SaveFunctionState: TJSFunctionState;
    procedure RestoreFunctionState(const State: TJSFunctionState);
    procedure EnterFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean; const IsAsync: Boolean);
    procedure RaiseAtCurrentToken(const Message: string);
    procedure RejectAsyncGenerator(const IsGenerator: Boolean; const IsAsync: Boolean);
    function ParseNested(const ParseOperand: TJSOperandParser): TJSExpression;
    function ParseWithInOperator(const ParseOperand: TJSOperandParser): TJSExpression;
    function ParseRightOperand(const Left: TJSExpression; const ParseOperand: TJSOperandParser): TJSExpression;
    function ParseMemberName(const Owner: TJSExpression): TJSIdentifier;
    function ParseComputedMember(const Owner: TJSExpression): TJSExpression;
    function ParseClass(const RequireName: Boolean): TJSClassExpression;
    function ParseClassDefinition(const RequireName: Boolean; const SourceStart: Integer): TJSClassExpression;
    procedure DeclareClassName(const ClassName: string);
    function ParseClassDeclaration: TJSVariableDeclaration;
    procedure ParseClassHeritage(const Target: TJSClassExpression);
    procedure ParseClassBody(const Target: TJSClassExpression);
    procedure ParseClassMember(const Target: TJSClassExpression);
    function StartsStaticModifier: Boolean;
    function ParseClassMemberKind(const HasModifier: Boolean): TJSPropertyKind;
    function ClassMemberKeyText(const Key: TJSExpression; const Computed: Boolean): string;
    procedure ValidateClassMember(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
    procedure ValidateClassMemberName(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
    class function ClassFunctionContext(const IsConstructor: Boolean;
                                        const HasSuperClass: Boolean): TJSFunctionContext; static;
    function ParseClassMemberFunction(const Target: TJSClassExpression;
                                      const Head: TJSClassMemberHead): TJSFunctionExpression;
    procedure AddClassMember(const Target: TJSClassExpression; const Key: TJSExpression;
                             const Func: TJSFunctionExpression; const Head: TJSClassMemberHead);
    function ParseMethodFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                 const IsAsync: Boolean; const SourceStart: Integer): TJSFunctionExpression;
    function ParseSuperExpression: TJSExpression;
    function ParseNewTarget: TJSExpression;

    function CurrentToken: TJSToken;
    procedure Advance;
    function Match(const TokenType: TJSTokenType): Boolean;
    function Check(const TokenType: TJSTokenType): Boolean;
    function CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
    procedure Expect(const TokenType: TJSTokenType);
    procedure ExpectOwning(const TokenType: TJSTokenType; const Owned: array of TObject);
    procedure ExpectSemicolon;
    function IsAtEnd: Boolean;

    function ParseProgram: TJSProgram;
    function ParseStatement: TJSStatement;
    function ParseStatementBody: TJSStatement;
    function ParseAsyncOrExpressionStatement(const AllowLabelledFunction: Boolean): TJSStatement;
    function ParseStatementListItem: TJSStatement;
    function ParseBlockStatement: TJSBlockStatement;
    function ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                              const CatchParameter: string;
                              const CatchPatternNames: TArray<string> = nil): TJSBlockStatement;
    function ParseVariableDeclaration: TJSVariableDeclaration;
    procedure ParseVarDeclarator(const Declaration: TJSVariableDeclaration);
    procedure ParseVarPatternDeclarator(const Declaration: TJSVariableDeclaration);
    procedure ParseLexicalPatternBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean);
    procedure RejectMissingPatternInitializers(const Declaration: TJSVariableDeclaration);
    function ParseForVarDeclarations: TJSVariableDeclaration;
    function ParseForInStatementRest(const Left: TJSASTNode): TJSStatement;
    function ParseForOfStatementRest(const Left: TJSASTNode; const IsDeclaration: Boolean): TJSStatement;
    procedure RejectForOfInitializer(const Declaration: TJSVariableDeclaration);
    function IsOfKeyword: Boolean;
    function IsAsyncOfHead: Boolean;
    function MatchOf: Boolean;
    function ConvertForInTarget(const Target: TJSExpression): TJSExpression;
    procedure RejectCoverInitializers(const CoverMark: Integer; const Node: TJSASTNode);
    function ParseLexicalDeclaration: TJSVariableDeclaration;
    procedure ParseLexicalBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean;
                                  const RequireInitializer: Boolean);
    function ParseLexicalForStatement: TJSStatement;
    function ParseLexicalForHeadAndBody(const Declaration: TJSVariableDeclaration): TJSStatement;
    function ParseIfBranch: TJSStatement;
    function StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
    procedure DeclareVarName(const Name: string);
    procedure DeclareLexicalName(const Name: string; const IsFunction: Boolean; const AllowFunctionDuplicate: Boolean);
    procedure CheckLexicalBindingName(const Name: string);
    function ParseFunctionDeclaration(const AllowGenerator: Boolean;
                                      const IsAsync: Boolean = False): TJSFunctionDeclaration;
    procedure DeclareFunctionName(const FuncName: string; const IsFunctionLevel: Boolean;
                                  const IsPlainFunction: Boolean);
    procedure ParseFunctionDeclarationBody(const Func: TJSFunctionDeclaration; const SourceStart: Integer);
    procedure CheckHeaderInEnclosingAsyncContext(const Func: TJSFunctionDeclaration;
                                                 const OuterState: TJSFunctionState);
    procedure RegisterBlockFunction(const Func: TJSFunctionDeclaration; const IsStrictContext: Boolean;
                                    const IsPlainFunction: Boolean);
    function ParseExpressionStatement: TJSExpressionStatement;
    function ParseIfStatement: TJSIfStatement;
    function ParseWhileStatement: TJSWhileStatement;
    function ParseDoWhileStatement: TJSDoWhileStatement;
    function ParseLoopBody(const Owned: array of TObject): TJSStatement;
    procedure RejectFunctionDeclarationBody(const Owned: array of TObject);
    procedure FreeOwned(const Owned: array of TObject);
    function ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
    function LabelsIterationStatement: Boolean;
    function FindActiveLabel(const LabelName: string): Integer;
    function ParseJumpLabel(const KeywordToken: TJSToken): string;
    function ParseWithStatement: TJSWithStatement;
    function ParseWithBody: TJSStatement;
    function StartsWithDeclaration: Boolean;
    function ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>;
                                    const ParameterInfo: TJSParameterInfo): TJSBlockStatement;
    function PrologueDeclaresStrictMode(const FirstTokenOffset: Integer): Boolean;
    procedure RejectLegacyLiteralInStrictMode(const Token: TJSToken);
    function ParseForStatement: TJSStatement;
    function ParseReturnStatement: TJSReturnStatement;
    function ParseBreakStatement: TJSBreakStatement;
    function ParseContinueStatement: TJSContinueStatement;
    function ParseSwitchStatement: TJSSwitchStatement;
    function ParseThrowStatement: TJSThrowStatement;
    function ParseTryStatement: TJSTryStatement;
    function ParseCatchClause: TJSCatchClause;
    function ParseEmptyStatement: TJSEmptyStatement;
    function ParseDebuggerStatement: TJSDebuggerStatement;

    function ParseExpression: TJSExpression;
    function ParseAssignmentExpression: TJSExpression;
    function ParseAssignmentOperand: TJSExpression;
    function ParseUnaryOperand: TJSExpression;
    function ParseExponentOperand: TJSExpression;
    function ParseNewOperand: TJSExpression;
    function ParseExpressionWithoutIn: TJSExpression;
    function ParseNestedExpression: TJSExpression;
    function ParseNestedAssignmentExpression: TJSExpression;
    function ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement;
    function ParseConditionalExpression: TJSExpression;
    function ParseShortCircuitExpression: TJSExpression;
    function ParseNullishCoalesceExpression(const Head: TJSExpression): TJSExpression;
    function ParseLogicalOrExpression: TJSExpression;
    function ParseLogicalAndExpression: TJSExpression;
    function ParseBitwiseOrExpression: TJSExpression;
    function ParseBitwiseXorExpression: TJSExpression;
    function ParseBitwiseAndExpression: TJSExpression;
    function ParseEqualityExpression: TJSExpression;
    function ParseRelationalExpression: TJSExpression;
    function ParseShiftExpression: TJSExpression;
    function ParseAdditiveExpression: TJSExpression;
    function ParseMultiplicativeExpression: TJSExpression;
    function ParseExponentiationExpression: TJSExpression;
    function ParseUnaryExpression: TJSExpression;
    function ParseUpdateExpression: TJSExpression;
    function ParseCallExpression: TJSExpression;
    function ParseIdentifierName: TJSIdentifier;
    function ParseMemberExpression: TJSExpression;
    function ParseNewExpression: TJSExpression;
    function IsTemplateStart: Boolean;
    function ParseTemplateLiteral: TJSTemplateLiteral;
    function ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
    procedure ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
                                const Expressions: TObjectList<TJSExpression>);
    function CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
    function ParsePrimaryExpression: TJSExpression;
    function ParseArrayExpression: TJSArrayExpression;
    function ParseObjectExpression: TJSObjectExpression;
    function ParseObjectMember: TJSObjectProperty;
    function ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
    function ParseCoverInitializedProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
    function ParseMethodProperty(const Key: TJSExpression; const Computed: Boolean;
                                 const SourceStart: Integer; const IsGenerator: Boolean;
                                 const IsAsync: Boolean): TJSObjectProperty;
    function StartsAccessorProperty: Boolean;
    function ParsePropertyKey(out Computed: Boolean): TJSExpression;
    function ParseAccessorProperty: TJSObjectProperty;
    function ParseAccessorFunction(const Kind: TJSPropertyKind; const SourceStart: Integer;
                                   const Context: TJSFunctionContext = TJSFunctionContext.Method): TJSFunctionExpression;
    function ParseFunctionExpression(const IsAsync: Boolean = False): TJSFunctionExpression;
    procedure CheckFunctionExpressionName(const FuncName: string; const IsGenerator: Boolean;
                                          const IsAsync: Boolean);
    procedure ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression;
                                            const Context: TJSFunctionContext = TJSFunctionContext.Ordinary;
                                            const IsGenerator: Boolean = False;
                                            const IsAsync: Boolean = False);
    procedure ParseSignatureAndBodyInContext(const Func: TJSFunctionExpression; const IsGenerator: Boolean;
                                             const IsAsync: Boolean);
    function ParseYieldExpression: TJSExpression;
    function StartsYieldOperand: Boolean;
    function IsYieldKeyword: Boolean;
    procedure MarkSuspendableBody(const Body: TJSBlockStatement; const IsGenerator: Boolean;
                                const IsAsync: Boolean = False);
    function IsAwaitKeyword: Boolean;
    function ParseAwaitExpression: TJSExpression;
    function IsAsyncWord: Boolean;
    function StartsAsyncModifier: Boolean;
    function StartsAsyncFunction: Boolean;
    function StartsAsyncArrowFunction: Boolean;
    function StartsArrowFunction: Boolean;
    function SourceTextFrom(const StartOffset: Integer): string;
    function ParseArrowFunction(const IsAsync: Boolean = False): TJSFunctionExpression;
    procedure ParseArrowParameters(const Func: TJSFunctionExpression);
    procedure ParseArrowParameter(const Func: TJSFunctionExpression);
    function ParseFormalParameters(const Params: TObjectList<TJSIdentifier>): TJSParameterInfo;
    procedure ParseFormalParameter(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
    procedure ParseRestParameter(const Info: TJSParameterInfo);
    procedure RejectDuplicateNonSimpleParameters(const Info: TJSParameterInfo);
    function StartsParameterExpression(const Offset: Integer): Boolean;
    function FindClosingParenthesisOffset(const StartOffset: Integer = 0): Integer;
    function StartsArrowAfterParenthesis: Boolean;
    function ParseSpreadOrAssignmentExpression: TJSExpression;

    function IsPatternStart: Boolean;
    procedure CheckBindingName(const Name: string; const Kind: TJSBindingKind);
    function ParseBindingIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
    function ParseBindingTarget(const Kind: TJSBindingKind): TJSExpression;
    function ParseBindingElement(const Kind: TJSBindingKind): TJSExpression;
    function ParseArrayBindingPattern(const Kind: TJSBindingKind): TJSArrayPattern;
    function ParseObjectBindingPattern(const Kind: TJSBindingKind): TJSObjectPattern;
    function ParseBindingProperty(const Kind: TJSBindingKind): TJSObjectProperty;
    function ConvertToAssignmentPattern(const Node: TJSExpression): TJSExpression;
    procedure ValidateDestructuringTarget(const Node: TJSExpression);
    procedure ValidateDestructuringElement(const Node: TJSExpression);
    procedure ValidateArrayPattern(const Source: TJSArrayExpression);
    procedure ValidateObjectPattern(const Source: TJSObjectExpression);
    function BuildDestructuringTarget(const Node: TJSExpression): TJSExpression;
    function BuildDestructuringElement(const Node: TJSExpression): TJSExpression;
    function BuildArrayPattern(const Source: TJSArrayExpression): TJSArrayPattern;
    function BuildObjectPattern(const Source: TJSObjectExpression): TJSObjectPattern;
    function ParseCatchPattern: TJSCatchClause;
    procedure CollectBoundNames(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
    procedure ParseArrowBody(const Func: TJSFunctionExpression);
    procedure ParseArrowBlockBody(const Func: TJSFunctionExpression);
    procedure ParseArrowConciseBody(const Func: TJSFunctionExpression);
    function ParseConciseBody: TJSBlockStatement;
    procedure RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
    function ParseArguments(const Target: TObjectList<TJSExpression>): Boolean;

    function IsAssignmentOperator(const TokenType: TJSTokenType): Boolean;
    function IsRelationalOperator: Boolean;
    function IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
    procedure EnsureAssignmentTarget(const Target: TJSExpression);
    function TokenToAssignmentOperator(const TokenType: TJSTokenType): TJSAssignmentOperator;

    function IsStrictModeReservedWord(const Name: string): Boolean;
    procedure CheckStrictModeReservedWord(const Name: string);
    function IsRestrictedStrictName(const Name: string): Boolean;
    procedure CheckRestrictedBindingName(const Name: string);
    procedure CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                        const ParameterInfo: TJSParameterInfo);
    procedure CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
    procedure RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
    procedure CheckRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);

  public
    constructor Create(const Source: string); overload;
    constructor Create(const Lexer: TJSLexer); overload;
    destructor Destroy; override;

    function Parse: TJSProgram; overload;
    function Parse(const IsStrictContext: Boolean): TJSProgram; overload;
    function Parse(const IsStrictContext: Boolean; const Context: TJSSourceContext): TJSProgram; overload;
  end;

implementation

uses
  JS4D.StackGuard,
  JS4D.SuspensionAnalysis;

const
  ASYNC_FUNCTION = True;
  GENERATOR_NOT_ALLOWED = False;
  NOT_A_GENERATOR = False;
  NAME_REQUIRED = True;
  NAME_OPTIONAL = False;
  LINE_BREAK_ALLOWED = True;
  LINE_BREAK_NOT_ALLOWED = False;
  TRUE_VALUE = 'true';
  USE_STRICT_DIRECTIVE = 'use strict';
  LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE = 'Octal literals and escape sequences are not allowed in strict mode';
  ARGUMENTS_NAME = 'arguments';
  EVAL_NAME = 'eval';
  MAX_NESTING_DEPTH = 1000;
  NESTING_TOO_DEEP_MESSAGE = 'The source nests parentheses, blocks or classes too deeply';
  STATIC_NAME = 'static';
  CONSTRUCTOR_NAME = 'constructor';
  PROTOTYPE_NAME = 'prototype';
  TARGET_NAME = 'target';
  SUPER_OUTSIDE_METHOD_MESSAGE = '''super'' keyword unexpected here';
  NEW_TARGET_OUTSIDE_FUNCTION_MESSAGE = 'new.target is only allowed inside functions';
  CLASS_DECLARATION_BODY_MESSAGE = 'Class declaration cannot appear in a single-statement context';
  DUPLICATE_CONSTRUCTOR_MESSAGE = 'A class may only have one constructor';
  SPECIAL_CONSTRUCTOR_MESSAGE = 'Class constructor may not be an accessor';
  CONSTRUCTOR_NOT_PLAIN_MESSAGE = 'Class constructor may not be a generator or an async method';
  STATIC_PROTOTYPE_MESSAGE = 'Classes may not have a static property named ''prototype''';
  CLASS_FIELD_MESSAGE = 'Class fields are not supported';
  NEW_SUPER_MESSAGE = '''super'' cannot be used with new';
  KEYWORD_GET = 'get';
  KEYWORD_SET = 'set';
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
  ILLEGAL_THROW_NEWLINE_MESSAGE = 'Illegal newline after throw';
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
  LET_NAME = 'let';
  STRICT_RESERVED_WORD_MESSAGE = 'Use of future reserved word in strict mode: %s';
  STRICT_RESERVED_WORDS: array[0..8] of string = ('implements', 'interface', LET_NAME, 'package', 'private',
                                                  'protected', 'public', STATIC_NAME, YIELD_NAME);
  OF_NAME = 'of';
  YIELD_IDENTIFIER_MESSAGE = '''yield'' cannot be used as an identifier in a generator';
  YIELD_IN_PARAMETERS_MESSAGE = 'A yield expression is not allowed in formal parameters';
  YIELD_ESCAPE_MESSAGE = 'The keyword ''yield'' must not contain escaped characters';
  GENERATOR_DECLARATION_BODY_MESSAGE = 'Generator declaration is not allowed as the body of a statement';
  ASYNC_DECLARATION_BODY_MESSAGE = 'Async function declaration is not allowed as the body of a statement';
  ASYNC_GENERATOR_MESSAGE = 'Async generators are not supported';
  AWAIT_IDENTIFIER_MESSAGE = '''await'' cannot be used as an identifier in an async function';
  AWAIT_IN_PARAMETERS_MESSAGE = 'An await expression is not allowed in formal parameters';
  AWAIT_ESCAPE_MESSAGE = 'The keyword ''await'' must not contain escaped characters';
  ASYNC_NAME = 'async';
  AWAIT_NAME = 'await';
  PATTERN_PARAMETER_FORMAT = '(pattern %d)';
  REST_PATTERN_NAME = '(rest pattern)';
  INVALID_DESTRUCTURING_TARGET_MESSAGE = 'Invalid destructuring assignment target';
  MISSING_PATTERN_INITIALIZER_MESSAGE = 'Missing initializer in destructuring declaration';
  REST_ELEMENT_LAST_MESSAGE = 'Rest element must be last element';
  COVER_INITIALIZER_MESSAGE = 'Invalid shorthand property initializer';
  NULLISH_MIXED_WITH_LOGICAL_MESSAGE = '''??'' cannot be mixed with ''||'' or ''&&'' without parentheses';
  DUPLICATE_BINDING_MESSAGE = 'Duplicate binding ''%s'' in a pattern';

{ TJSClassMemberHead }

function TJSClassMemberHead.IsConstructor: Boolean;
begin
  Result := ((not IsStatic) and (KeyText = CONSTRUCTOR_NAME));
end;

{ TJSParser }

constructor TJSParser.Create(const Source: string);
begin
  inherited Create;
  FLexer := TJSLexer.Create(Source);
  FOwnsLexer := True;
  FLexer.Tokenize;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
end;

constructor TJSParser.Create(const Lexer: TJSLexer);
begin
  inherited Create;
  FLexer := Lexer;
  FOwnsLexer := False;
  FInOperatorAllowed := True;
  FActiveLabels := TList<TJSLabelInfo>.Create;
  FScopes := TJSScopeTracker.Create;
end;

destructor TJSParser.Destroy;
begin
  FScopes.Free;
  FActiveLabels.Free;

  if FOwnsLexer then
    FLexer.Free;

  inherited;
end;

function TJSParser.CurrentToken: TJSToken;
begin
  Result := FLexer.CurrentToken;
end;

procedure TJSParser.Advance;
begin
  FPreviousTokenLine := CurrentToken.Line;
  FLexer.NextToken;
end;

function TJSParser.Match(const TokenType: TJSTokenType): Boolean;
begin
  Result := Check(TokenType);

  if Result then
    Advance;
end;

function TJSParser.Check(const TokenType: TJSTokenType): Boolean;
begin
  Result := (CurrentToken.TokenType = TokenType);
end;

function TJSParser.CheckAny(const TokenTypes: array of TJSTokenType): Boolean;
begin
  for var TokenType in TokenTypes do
  begin
    if Check(TokenType) then
      Exit(True);
  end;

  Result := False;
end;

procedure TJSParser.Expect(const TokenType: TJSTokenType);
begin
  if not Match(TokenType) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.ExpectOwning(const TokenType: TJSTokenType; const Owned: array of TObject);
begin
  try
    Expect(TokenType);
  except
    FreeOwned(Owned);
    raise;
  end;
end;

procedure TJSParser.ExpectSemicolon;
begin
  if Match(TJSTokenType.Semicolon) then
    Exit;

  const CanInsertSemicolon = (Check(TJSTokenType.RightBrace) or
                              Check(TJSTokenType.EndOfFile) or
                              CurrentToken.LineTerminatorBefore);
  if not CanInsertSemicolon then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.IsAtEnd: Boolean;
begin
  Result := Check(TJSTokenType.EndOfFile);
end;

function TJSParser.Parse: TJSProgram;
begin
  Result := ParseProgram;
end;

function TJSParser.Parse(const IsStrictContext: Boolean): TJSProgram;
begin
  FStrictMode := IsStrictContext;
  Result := ParseProgram;
end;

function TJSParser.Parse(const IsStrictContext: Boolean; const Context: TJSSourceContext): TJSProgram;
begin
  FContext := Context;
  Result := Parse(IsStrictContext);
end;

function TJSParser.ParseProgram: TJSProgram;
begin
  Result := TJSProgram.Create;
  FScopes.Enter(TJSParserScopeKind.Function_, nil);
  const ClosureMark = FClosureCount;

  try
    if PrologueDeclaresStrictMode(0) then
    begin
      FStrictMode := True;
      Result.IsStrict := True;
    end;

    while not IsAtEnd do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Result.ScopeInfo := FScopes.Leave;
  except
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

function TJSParser.ParseStatementListItem: TJSStatement;
begin
  const StartsLexicalDeclaration = (Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(LINE_BREAK_ALLOWED));
  const StartsClassDeclaration = Check(TJSTokenType.KeywordClass);

  if StartsLexicalDeclaration then
  begin
    Result := ParseLexicalDeclaration;
  end
  else if StartsClassDeclaration then
  begin
    Result := ParseClassDeclaration;
  end
  else
  begin
    FAllowLabelledFunction := True;
    Result := ParseStatement;
  end;
end;

function TJSParser.ParseStatement: TJSStatement;
begin
  EnterNesting;
  try
    Result := ParseStatementBody;
  finally
    LeaveNesting;
  end;
end;

function TJSParser.ParseStatementBody: TJSStatement;
begin
  const AllowLabelledFunction = FAllowLabelledFunction;
  FAllowLabelledFunction := False;

  const StartsLexicalDeclaration = (Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(False));
  if StartsLexicalDeclaration then
    raise TJSErrorFactory.SyntaxError(LEXICAL_DECLARATION_BODY_MESSAGE, CurrentToken.Line, CurrentToken.Column);

  const StartsLabel = (Check(TJSTokenType.Identifier) and
                       (FLexer.PeekToken(1).TokenType = TJSTokenType.Colon));
  if StartsLabel then
  begin
    Result := ParseLabeledStatement(AllowLabelledFunction);
    Exit;
  end;

  case CurrentToken.TokenType of
    TJSTokenType.LeftBrace:
      Result := ParseBlockStatement;
    TJSTokenType.KeywordVar:
      Result := ParseVariableDeclaration;
    TJSTokenType.KeywordFunction:
      Result := ParseFunctionDeclaration(AllowLabelledFunction);
    TJSTokenType.KeywordClass:
      raise TJSErrorFactory.SyntaxError(CLASS_DECLARATION_BODY_MESSAGE, CurrentToken.Line, CurrentToken.Column);
    TJSTokenType.KeywordIf:
      Result := ParseIfStatement;
    TJSTokenType.KeywordWhile:
      Result := ParseWhileStatement;
    TJSTokenType.KeywordDo:
      Result := ParseDoWhileStatement;
    TJSTokenType.KeywordWith:
      Result := ParseWithStatement;
    TJSTokenType.KeywordFor:
      Result := ParseForStatement;
    TJSTokenType.KeywordReturn:
      Result := ParseReturnStatement;
    TJSTokenType.KeywordBreak:
      Result := ParseBreakStatement;
    TJSTokenType.KeywordContinue:
      Result := ParseContinueStatement;
    TJSTokenType.KeywordSwitch:
      Result := ParseSwitchStatement;
    TJSTokenType.KeywordThrow:
      Result := ParseThrowStatement;
    TJSTokenType.KeywordTry:
      Result := ParseTryStatement;
    TJSTokenType.Semicolon:
      Result := ParseEmptyStatement;
    TJSTokenType.KeywordDebugger:
      Result := ParseDebuggerStatement;
    else
      Result := ParseAsyncOrExpressionStatement(AllowLabelledFunction);
  end;
end;

function TJSParser.ParseAsyncOrExpressionStatement(const AllowLabelledFunction: Boolean): TJSStatement;
begin
  if StartsAsyncFunction then
  begin
    if not AllowLabelledFunction then
      RaiseAtCurrentToken(ASYNC_DECLARATION_BODY_MESSAGE);

    Result := ParseFunctionDeclaration(AllowLabelledFunction, ASYNC_FUNCTION);
  end
  else
  begin
    Result := ParseExpressionStatement;
  end;
end;

function TJSParser.ParseBlockStatement: TJSBlockStatement;
begin
  Result := ParseScopedBlock(TJSParserScopeKind.Block, nil, '');
end;

function TJSParser.ParseScopedBlock(const Kind: TJSParserScopeKind; const Parameters: TArray<string>;
                                    const CatchParameter: string;
                                    const CatchPatternNames: TArray<string>): TJSBlockStatement;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := (Kind = TJSParserScopeKind.Function_);
  FScopes.Enter(Kind, Parameters);
  FScopes.SetCatchParameter(CatchParameter);
  FScopes.SetCatchPatternNames(CatchPatternNames);
  const ClosureMark = FClosureCount;

  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      const Statement = ParseStatementListItem;
      Result.Body.Add(Statement);
    end;

    Expect(TJSTokenType.RightBrace);
    Result.ScopeInfo := FScopes.Leave;
  except
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

procedure TJSParser.DeclareVarName(const Name: string);
begin
  if not FScopes.TryDeclareVar(Name) then
    raise TJSErrorFactory.SyntaxError(Format(REDECLARATION_MESSAGE, [Name]), CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.DeclareLexicalName(const Name: string; const IsFunction: Boolean;
                                       const AllowFunctionDuplicate: Boolean);
begin
  if not FScopes.TryDeclareLexical(Name, IsFunction, AllowFunctionDuplicate) then
    raise TJSErrorFactory.SyntaxError(Format(REDECLARATION_MESSAGE, [Name]), CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.CheckLexicalBindingName(const Name: string);
begin
  if Name = LET_NAME then
    raise TJSErrorFactory.SyntaxError(LET_BINDING_NAME_MESSAGE, CurrentToken.Line, CurrentToken.Column);

  CheckStrictModeReservedWord(Name);
  CheckRestrictedBindingName(Name);
end;

function TJSParser.StartsLetDeclaration(const AllowLineBreak: Boolean): Boolean;
begin
  const IsLetWord = (Check(TJSTokenType.Identifier) and (CurrentToken.Value = LET_NAME) and
                     (not CurrentToken.HasEscape));
  if not IsLetWord then
    Exit(False);

  const FollowingToken = FLexer.PeekToken(1);
  const IsAllowedPosition = (AllowLineBreak or (FollowingToken.Line = CurrentToken.Line));
  const FollowedByBinding = (FollowingToken.TokenType in [TJSTokenType.Identifier, TJSTokenType.LeftBrace]);
  const FollowedByPattern = (FollowingToken.TokenType = TJSTokenType.LeftBracket);

  Result := FollowedByPattern or (FollowedByBinding and IsAllowedPosition);
end;

function TJSParser.ParseLexicalDeclaration: TJSVariableDeclaration;
begin
  Result := TJSVariableDeclaration.Create;

  try
    if Check(TJSTokenType.KeywordConst) then
      Result.Kind := TJSDeclarationKind.Const_
    else
      Result.Kind := TJSDeclarationKind.Let;

    Advance;

    repeat
      ParseLexicalBinding(Result, True, Result.Kind = TJSDeclarationKind.Const_);
    until not Match(TJSTokenType.Comma);

    RejectMissingPatternInitializers(Result);
    ExpectSemicolon;
    FScopes.AddDeclaration(Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseLexicalBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean;
                                        const RequireInitializer: Boolean);
begin
  if IsPatternStart then
  begin
    ParseLexicalPatternBinding(Declaration, AllowIn);
    Exit;
  end;

  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const BindingName = CurrentToken.Value;
  CheckLexicalBindingName(BindingName);
  DeclareLexicalName(BindingName, False, False);
  Advance;

  var InitExpr: TJSExpression := nil;

  if Match(TJSTokenType.Assign) then
  begin
    const PreviousAllowed = FInOperatorAllowed;
    FInOperatorAllowed := AllowIn;
    try
      InitExpr := ParseAssignmentExpression;
    finally
      FInOperatorAllowed := PreviousAllowed;
    end;
  end
  else if RequireInitializer then
  begin
    raise TJSErrorFactory.SyntaxError(MISSING_CONST_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
  end;

  const Identifier = TJSIdentifier.Create(BindingName);
  const Declarator = TJSVariableDeclarator.Create(Identifier, InitExpr);
  Declaration.Declarations.Add(Declarator);
end;

function TJSParser.ParseVariableDeclaration: TJSVariableDeclaration;
begin
  Expect(TJSTokenType.KeywordVar);

  Result := TJSVariableDeclaration.Create;

  try
    repeat
      ParseVarDeclarator(Result);
    until not Match(TJSTokenType.Comma);

    RejectMissingPatternInitializers(Result);
    ExpectSemicolon;
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseVarDeclarator(const Declaration: TJSVariableDeclaration);
begin
  if IsPatternStart then
  begin
    ParseVarPatternDeclarator(Declaration);
    Exit;
  end;

  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const IdName = CurrentToken.Value;
  CheckStrictModeReservedWord(IdName);
  CheckRestrictedBindingName(IdName);
  DeclareVarName(IdName);
  Advance;

  var InitExpr: TJSExpression := nil;

  if Match(TJSTokenType.Assign) then
    InitExpr := ParseAssignmentExpression;

  const Identifier = TJSIdentifier.Create(IdName);
  const Declarator = TJSVariableDeclarator.Create(Identifier, InitExpr);
  Declaration.Declarations.Add(Declarator);
end;

procedure TJSParser.ParseVarPatternDeclarator(const Declaration: TJSVariableDeclaration);
begin
  const Pattern = ParseBindingTarget(TJSBindingKind.Var_);
  var InitExpr: TJSExpression := nil;

  try
    for var Name in TJSPatternNames.Of_(Pattern) do
    begin
      DeclareVarName(Name);
    end;

    if Match(TJSTokenType.Assign) then
      InitExpr := ParseAssignmentExpression;
  except
    Pattern.Free;
    raise;
  end;

  const Declarator = TJSVariableDeclarator.CreateWithPattern(Pattern, InitExpr);
  Declaration.Declarations.Add(Declarator);
end;

procedure TJSParser.ParseLexicalPatternBinding(const Declaration: TJSVariableDeclaration; const AllowIn: Boolean);
begin
  const Pattern = ParseBindingTarget(TJSBindingKind.Lexical);
  var InitExpr: TJSExpression := nil;

  try
    for var Name in TJSPatternNames.Of_(Pattern) do
    begin
      DeclareLexicalName(Name, False, False);
    end;

    if Match(TJSTokenType.Assign) then
    begin
      const PreviousAllowed = FInOperatorAllowed;
      FInOperatorAllowed := AllowIn;
      try
        InitExpr := ParseAssignmentExpression;
      finally
        FInOperatorAllowed := PreviousAllowed;
      end;
    end;
  except
    Pattern.Free;
    raise;
  end;

  const Declarator = TJSVariableDeclarator.CreateWithPattern(Pattern, InitExpr);
  Declaration.Declarations.Add(Declarator);
end;

procedure TJSParser.RejectMissingPatternInitializers(const Declaration: TJSVariableDeclaration);
begin
  for var Declarator in Declaration.Declarations do
  begin
    const IsMissingInitializer = Assigned(Declarator.Pattern) and (not Assigned(Declarator.Init));
    if IsMissingInitializer then
      raise TJSErrorFactory.SyntaxError(MISSING_PATTERN_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
  end;
end;

function TJSParser.SourceTextFrom(const StartOffset: Integer): string;
begin
  const LastConsumed = FLexer.PeekToken(-1);
  Result := FLexer.SourceSlice(StartOffset, LastConsumed.EndOffset);
end;

function TJSParser.ParseFunctionDeclaration(const AllowGenerator: Boolean;
                                           const IsAsync: Boolean): TJSFunctionDeclaration;
begin
  const SourceStart = CurrentToken.StartOffset;
  if IsAsync then
    Advance;

  Expect(TJSTokenType.KeywordFunction);

  const IsGenerator = Match(TJSTokenType.Multiply);
  const IsRejectedGenerator = (IsGenerator and (not AllowGenerator));
  if IsRejectedGenerator then
    RaiseAtCurrentToken(GENERATOR_DECLARATION_BODY_MESSAGE);

  RejectAsyncGenerator(IsGenerator, IsAsync);

  const HasName = Check(TJSTokenType.Identifier);
  if not HasName then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const FuncName = CurrentToken.Value;
  CheckStrictModeReservedWord(FuncName);

  const IsStrictContext = FStrictMode;
  const IsFunctionLevel = FScopes.IsFunctionLevel;
  const IsPlainFunction = (not IsGenerator) and (not IsAsync);
  DeclareFunctionName(FuncName, IsFunctionLevel, IsPlainFunction);

  Advance;
  Inc(FClosureCount);

  const Identifier = TJSIdentifier.Create(FuncName);
  Result := TJSFunctionDeclaration.Create(Identifier);
  Result.IsGenerator := IsGenerator;
  Result.IsAsync := IsAsync;

  try
    ParseFunctionDeclarationBody(Result, SourceStart);
  except
    Result.Free;
    raise;
  end;

  if not IsFunctionLevel then
    RegisterBlockFunction(Result, IsStrictContext, IsPlainFunction);
end;

procedure TJSParser.DeclareFunctionName(const FuncName: string; const IsFunctionLevel: Boolean;
                                        const IsPlainFunction: Boolean);
begin
  if IsFunctionLevel then
  begin
    DeclareVarName(FuncName);
  end
  else
  begin
    const AllowFunctionDuplicate = ((not FStrictMode) and IsPlainFunction);
    DeclareLexicalName(FuncName, IsPlainFunction, AllowFunctionDuplicate);
  end;
end;

procedure TJSParser.ParseFunctionDeclarationBody(const Func: TJSFunctionDeclaration; const SourceStart: Integer);
begin
  const OuterState = SaveFunctionState;
  EnterFunction(TJSFunctionContext.Ordinary, Func.IsGenerator, Func.IsAsync);
  try
    Func.ParameterInfo := ParseFormalParameters(Func.Params);
    FYieldForbidden := False;
    FAwaitForbidden := False;

    const OldStrictMode = FStrictMode;
    const Body = ParseFunctionBodyBlock(Func.Params, Func.ParameterInfo);
    Func.Body := Body;
    MarkSuspendableBody(Body, Func.IsGenerator, Func.IsAsync);

    if Body.DeclaresStrictMode then
    begin
      Func.IsStrict := True;
      FStrictMode := True;
    end;

    CheckHeaderInEnclosingAsyncContext(Func, OuterState);
    FStrictMode := OldStrictMode;
    Func.SourceText := SourceTextFrom(SourceStart);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSParser.CheckHeaderInEnclosingAsyncContext(const Func: TJSFunctionDeclaration;
                                                       const OuterState: TJSFunctionState);
begin
  FInAsync := OuterState.InAsync;
  CheckStrictFunctionHeader(Func.Id.Name, Func.Params, Func.ParameterInfo);
end;

procedure TJSParser.RegisterBlockFunction(const Func: TJSFunctionDeclaration; const IsStrictContext: Boolean;
                                          const IsPlainFunction: Boolean);
begin
  FScopes.AddDeclaration(Func);

  const IsCandidate = ((not IsStrictContext) and IsPlainFunction);
  if IsCandidate then
    FScopes.AddFunctionCandidate(Func);
end;

function TJSParser.ParseExpressionStatement: TJSExpressionStatement;
begin
  const Expression = ParseExpression;
  try
    ExpectSemicolon;
  except
    Expression.Free;
    raise;
  end;

  Result := TJSExpressionStatement.Create(Expression);
end;

function TJSParser.ParseIfStatement: TJSIfStatement;
begin
  Expect(TJSTokenType.KeywordIf);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;
  var Consequent: TJSStatement := nil;
  var Alternate: TJSStatement := nil;

  try
    Expect(TJSTokenType.RightParen);

    if FStrictMode then
      RejectFunctionDeclarationBody([]);

    Consequent := ParseIfBranch;

    if Match(TJSTokenType.KeywordElse) then
    begin
      if FStrictMode then
        RejectFunctionDeclarationBody([]);

      Alternate := ParseIfBranch;
    end;
  except
    FreeOwned([Test, Consequent, Alternate]);
    raise;
  end;

  Result := TJSIfStatement.Create(Test, Consequent, Alternate);
end;

function TJSParser.ParseIfBranch: TJSStatement;
begin
  if not Check(TJSTokenType.KeywordFunction) then
    Exit(ParseStatement);

  const Block = TJSBlockStatement.Create;
  FScopes.Enter(TJSParserScopeKind.Block, nil);

  try
    const Declaration = ParseFunctionDeclaration(GENERATOR_NOT_ALLOWED);
    Block.Body.Add(Declaration);
    Block.ScopeInfo := FScopes.Leave;
  except
    Block.Free;
    raise;
  end;

  Block.ScopeInfo.MayCaptureScope := True;
  Result := Block;
end;

function TJSParser.ParseWhileStatement: TJSWhileStatement;
begin
  Expect(TJSTokenType.KeywordWhile);
  Expect(TJSTokenType.LeftParen);

  const Test = ParseExpression;

  ExpectOwning(TJSTokenType.RightParen, [Test]);

  const Body = ParseLoopBody([Test]);

  Result := TJSWhileStatement.Create(Test, Body);
end;

function TJSParser.ParseWithStatement: TJSWithStatement;
begin
  if FStrictMode then
    raise TJSErrorFactory.SyntaxError('with statement is not allowed in strict mode',
      CurrentToken.Line, CurrentToken.Column);

  Expect(TJSTokenType.KeywordWith);
  Expect(TJSTokenType.LeftParen);

  const Target = ParseExpression;

  try
    Expect(TJSTokenType.RightParen);

    const Body = ParseWithBody;

    Result := TJSWithStatement.Create(Target, Body);
  except
    Target.Free;
    raise;
  end;
end;

function TJSParser.ParseWithBody: TJSStatement;
begin
  if StartsWithDeclaration then
    raise TJSErrorFactory.SyntaxError('Declaration is not allowed as the body of a with statement',
      CurrentToken.Line, CurrentToken.Column);

  Result := ParseStatement;
end;

function TJSParser.StartsWithDeclaration: Boolean;
begin
  if CheckAny([TJSTokenType.KeywordFunction, TJSTokenType.KeywordConst, TJSTokenType.KeywordClass]) then
    Exit(True);

  if not Check(TJSTokenType.Identifier) then
    Exit(False);

  Result := StartsLetDeclaration(LINE_BREAK_NOT_ALLOWED);
end;

function TJSParser.PrologueDeclaresStrictMode(const FirstTokenOffset: Integer): Boolean;
begin
  Result := False;
  var HasLegacyDirective := False;
  var Offset := FirstTokenOffset;

  while True do
  begin
    const DirectiveToken = FLexer.PeekToken(Offset);
    if DirectiveToken.TokenType <> TJSTokenType.StringLiteral then
      Break;

    const EndToken = FLexer.PeekToken(Offset + 1);
    const EndsWithSemicolon = (EndToken.TokenType = TJSTokenType.Semicolon);
    const EndsDirective = (EndsWithSemicolon or
                           (EndToken.TokenType in [TJSTokenType.RightBrace, TJSTokenType.EndOfFile]) or
                           (EndToken.Line <> DirectiveToken.Line));
    if not EndsDirective then
      Break;

    const IsUseStrict = (DirectiveToken.Value = USE_STRICT_DIRECTIVE) and (not DirectiveToken.HasEscape);
    if IsUseStrict then
      Result := True;

    if DirectiveToken.IsLegacyLiteral then
      HasLegacyDirective := True;

    Inc(Offset);
    if EndsWithSemicolon then
      Inc(Offset);
  end;

  if Result and HasLegacyDirective then
    raise TJSErrorFactory.SyntaxError(LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE,
      CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.RejectLegacyLiteralInStrictMode(const Token: TJSToken);
begin
  if FStrictMode and Token.IsLegacyLiteral then
    raise TJSErrorFactory.SyntaxError(LEGACY_LITERAL_IN_STRICT_MODE_MESSAGE, Token.Line, Token.Column);
end;

function TJSParser.ParseFunctionBodyBlock(const Params: TObjectList<TJSIdentifier>;
                                          const ParameterInfo: TJSParameterInfo): TJSBlockStatement;
begin
  var ParameterNames: TArray<string>;
  if Assigned(ParameterInfo) then
  begin
    ParameterNames := ParameterInfo.BoundNames;
  end
  else
  begin
    SetLength(ParameterNames, Params.Count);

    for var Index := 0 to Params.Count - 1 do
    begin
      ParameterNames[Index] := Params[Index].Name;
    end;
  end;

  const OldStrictMode = FStrictMode;
  const OuterLabelScopeStart = FLabelScopeStart;
  const OuterLoopDepth = FLoopDepth;
  const OuterSwitchDepth = FSwitchDepth;

  Inc(FFunctionDepth);

  const DeclaresStrictMode = Check(TJSTokenType.LeftBrace) and PrologueDeclaresStrictMode(1);
  if DeclaresStrictMode then
    FStrictMode := True;

  FLabelScopeStart := FActiveLabels.Count;
  FLoopDepth := 0;
  FSwitchDepth := 0;
  try
    if DeclaresStrictMode and Assigned(ParameterInfo) then
      raise TJSErrorFactory.SyntaxError(STRICT_NON_SIMPLE_PARAMETERS_MESSAGE, CurrentToken.Line, CurrentToken.Column);

    const StartPosition = FLexer.Position;
    Result := ParseNestedBlockStatement(ParameterNames);
    Result.DeclaresStrictMode := DeclaresStrictMode;
    Result.ParameterInfo := ParameterInfo;
    Result.ReferencesArguments := FLexer.HasIdentifierBetween(StartPosition, FLexer.Position,
                                                              [ARGUMENTS_NAME, EVAL_NAME]) or
                                  (Assigned(ParameterInfo) and ParameterInfo.ReferencesArguments);
  finally
    Dec(FFunctionDepth);
    FStrictMode := OldStrictMode;
    FLabelScopeStart := OuterLabelScopeStart;
    FLoopDepth := OuterLoopDepth;
    FSwitchDepth := OuterSwitchDepth;
  end;
end;

function TJSParser.ParseDoWhileStatement: TJSDoWhileStatement;
begin
  Expect(TJSTokenType.KeywordDo);

  const Body = ParseLoopBody([]);

  var Test: TJSExpression := nil;
  try
    Expect(TJSTokenType.KeywordWhile);
    Expect(TJSTokenType.LeftParen);
    Test := ParseExpression;
    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Body, Test]);
    raise;
  end;

  Match(TJSTokenType.Semicolon);

  Result := TJSDoWhileStatement.Create(Body, Test);
end;

function TJSParser.ParseForStatement: TJSStatement;
begin
  Expect(TJSTokenType.KeywordFor);
  Expect(TJSTokenType.LeftParen);

  const IsLexicalHead = (Check(TJSTokenType.KeywordConst) or StartsLetDeclaration(True));
  if IsLexicalHead then
    Exit(ParseLexicalForStatement);

  var Init: TJSASTNode := nil;

  if Check(TJSTokenType.KeywordVar) then
  begin
    Advance;
    const Declaration = ParseForVarDeclarations;

    if Match(TJSTokenType.KeywordIn) then
      Exit(ParseForInStatementRest(Declaration));

    if MatchOf then
      Exit(ParseForOfStatementRest(Declaration, True));

    Init := Declaration;
  end
  else if not Check(TJSTokenType.Semicolon) then
  begin
    const CoverMark = FCoverInitializerCount;
    FInLiteralElement := True;
    const StartsWithAsyncOf = IsAsyncOfHead;
    var Expr := ParseExpressionWithoutIn;

    if Match(TJSTokenType.KeywordIn) then
    begin
      Expr := ConvertForInTarget(Expr);
      RejectCoverInitializers(CoverMark, Expr);
      Exit(ParseForInStatementRest(Expr));
    end;

    if MatchOf then
    begin
      if StartsWithAsyncOf then
      begin
        Expr.Free;
        raise TJSErrorFactory.SyntaxError(ASYNC_OF_HEAD_MESSAGE, CurrentToken.Line, CurrentToken.Column);
      end;

      Expr := ConvertForInTarget(Expr);
      RejectCoverInitializers(CoverMark, Expr);
      Exit(ParseForOfStatementRest(Expr, False));
    end;

    RejectCoverInitializers(CoverMark, Expr);
    Init := TJSExpressionStatement.Create(Expr);
  end;

  var Test: TJSExpression := nil;
  var Update: TJSExpression := nil;

  try
    Expect(TJSTokenType.Semicolon);

    if not Check(TJSTokenType.Semicolon) then
      Test := ParseExpression;

    Expect(TJSTokenType.Semicolon);

    if not Check(TJSTokenType.RightParen) then
      Update := ParseExpression;

    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Init, Test, Update]);
    raise;
  end;

  const Body = ParseLoopBody([Init, Test, Update]);

  Result := TJSForStatement.Create(Init, Test, Update, Body);
end;

function TJSParser.ParseForVarDeclarations: TJSVariableDeclaration;
begin
  Result := TJSVariableDeclaration.Create;

  try
    ParseVarDeclarator(Result);

    if Check(TJSTokenType.KeywordIn) or IsOfKeyword then
      Exit;

    while Match(TJSTokenType.Comma) do
    begin
      ParseVarDeclarator(Result);
    end;

    RejectMissingPatternInitializers(Result);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseForInStatementRest(const Left: TJSASTNode): TJSStatement;
begin
  var Right: TJSExpression := nil;
  try
    Right := ParseExpression;
    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Left, Right]);
    raise;
  end;

  const Body = ParseLoopBody([Left, Right]);

  Result := TJSForInStatement.Create(Left, Right, Body);
end;

function TJSParser.IsAsyncOfHead: Boolean;
begin
  const IsAsyncWord = (Check(TJSTokenType.Identifier) and (CurrentToken.Value = ASYNC_NAME) and
                       (not CurrentToken.HasEscape));
  if not IsAsyncWord then
    Exit(False);

  const FollowingToken = FLexer.PeekToken(1);
  const IsOfWord = ((FollowingToken.TokenType = TJSTokenType.Identifier) and (FollowingToken.Value = OF_NAME) and
                    (not FollowingToken.HasEscape));
  const IsArrowParameter = (FLexer.PeekToken(2).TokenType = TJSTokenType.Arrow);

  Result := IsOfWord and (not IsArrowParameter);
end;

function TJSParser.IsOfKeyword: Boolean;
begin
  Result := (Check(TJSTokenType.Identifier) and (CurrentToken.Value = OF_NAME) and (not CurrentToken.HasEscape));
end;

function TJSParser.MatchOf: Boolean;
begin
  Result := IsOfKeyword;

  if Result then
    Advance;
end;

function TJSParser.ParseForOfStatementRest(const Left: TJSASTNode; const IsDeclaration: Boolean): TJSStatement;
begin
  var Right: TJSExpression := nil;

  try
    if IsDeclaration then
      RejectForOfInitializer(TJSVariableDeclaration(Left));

    Right := ParseAssignmentExpression;
    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Left, Right]);
    raise;
  end;

  const Body = ParseLoopBody([Left, Right]);

  Result := TJSForOfStatement.Create(Left, Right, Body);
end;

procedure TJSParser.RejectForOfInitializer(const Declaration: TJSVariableDeclaration);
begin
  const IsSingleBinding = (Declaration.Declarations.Count = 1);
  const HasInitializer = IsSingleBinding and Assigned(Declaration.Declarations[0].Init);
  if (not IsSingleBinding) or HasInitializer then
    raise TJSErrorFactory.SyntaxError(FOR_OF_HEAD_MESSAGE, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.ConvertForInTarget(const Target: TJSExpression): TJSExpression;
begin
  const IsLiteral = ((Target is TJSArrayExpression) or (Target is TJSObjectExpression)) and
                    (not Target.IsParenthesized);
  if IsLiteral then
    Exit(ConvertToAssignmentPattern(Target));

  EnsureAssignmentTarget(Target);
  Result := Target;
end;

procedure TJSParser.RejectCoverInitializers(const CoverMark: Integer; const Node: TJSASTNode);
begin
  if FCoverInitializerCount = CoverMark then
    Exit;

  Node.Free;
  raise TJSErrorFactory.SyntaxError(COVER_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.ParseLexicalForStatement: TJSStatement;
begin
  FScopes.Enter(TJSParserScopeKind.Block, nil);
  const ClosureMark = FClosureCount;

  const Declaration = TJSVariableDeclaration.Create;
  if Check(TJSTokenType.KeywordConst) then
    Declaration.Kind := TJSDeclarationKind.Const_
  else
    Declaration.Kind := TJSDeclarationKind.Let;

  Advance;

  try
    Result := ParseLexicalForHeadAndBody(Declaration);
  except
    const AbandonedScopeInfo = FScopes.Leave;
    AbandonedScopeInfo.Free;
    raise;
  end;

  const ForScopeInfo = FScopes.Leave;
  ForScopeInfo.Free;

  const MayCaptureScope = (FClosureCount <> ClosureMark);
  if Result is TJSForInStatement then
    TJSForInStatement(Result).MayCaptureScope := MayCaptureScope
  else
    TJSForStatement(Result).MayCaptureScope := MayCaptureScope;
end;

function TJSParser.ParseLexicalForHeadAndBody(const Declaration: TJSVariableDeclaration): TJSStatement;
begin
  var Right: TJSExpression := nil;
  var Test: TJSExpression := nil;
  var Update: TJSExpression := nil;
  var IsForOf := False;

  try
    ParseLexicalBinding(Declaration, False, False);

    if Match(TJSTokenType.KeywordIn) then
    begin
      if Assigned(Declaration.Declarations[0].Init) then
        raise TJSErrorFactory.SyntaxError(FOR_IN_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);

      Right := ParseExpression;
    end
    else if MatchOf then
    begin
      IsForOf := True;
      RejectForOfInitializer(Declaration);
      Right := ParseAssignmentExpression;
    end
    else
    begin
      while Match(TJSTokenType.Comma) do
      begin
        ParseLexicalBinding(Declaration, False, False);
      end;

      for var Declarator in Declaration.Declarations do
      begin
        const IsMissingConstInitializer = (Declaration.Kind = TJSDeclarationKind.Const_) and (Declarator.Init = nil);
        if IsMissingConstInitializer then
          raise TJSErrorFactory.SyntaxError(MISSING_CONST_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
      end;

      RejectMissingPatternInitializers(Declaration);
      Expect(TJSTokenType.Semicolon);

      if not Check(TJSTokenType.Semicolon) then
        Test := ParseExpression;

      Expect(TJSTokenType.Semicolon);

      if not Check(TJSTokenType.RightParen) then
        Update := ParseExpression;
    end;

    Expect(TJSTokenType.RightParen);
  except
    FreeOwned([Declaration, Right, Test, Update]);
    raise;
  end;

  if IsForOf then
  begin
    const ForOfBody = ParseLoopBody([Declaration, Right]);
    Result := TJSForOfStatement.Create(Declaration, Right, ForOfBody);
  end
  else if Assigned(Right) then
  begin
    const ForInBody = ParseLoopBody([Declaration, Right]);
    Result := TJSForInStatement.Create(Declaration, Right, ForInBody);
  end
  else
  begin
    const ForBody = ParseLoopBody([Declaration, Test, Update]);
    Result := TJSForStatement.Create(Declaration, Test, Update, ForBody);
  end;
end;

function TJSParser.ParseReturnStatement: TJSReturnStatement;
begin
  const Token = CurrentToken;
  if FFunctionDepth = 0 then
    raise TJSErrorFactory.SyntaxError(ILLEGAL_RETURN_MESSAGE, Token.Line, Token.Column);

  Expect(TJSTokenType.KeywordReturn);

  var Argument: TJSExpression := nil;

  const HasNewLine = (CurrentToken.Line > Token.Line);
  const IsEndOfStatement = (Check(TJSTokenType.Semicolon) or Check(TJSTokenType.RightBrace) or Check(TJSTokenType.EndOfFile));

  if (not HasNewLine) and (not IsEndOfStatement) then
    Argument := ParseExpression;

  try
    ExpectSemicolon;
  except
    Argument.Free;
    raise;
  end;

  Result := TJSReturnStatement.Create(Argument);
end;

function TJSParser.ParseBreakStatement: TJSBreakStatement;
begin
  const KeywordToken = CurrentToken;
  Expect(TJSTokenType.KeywordBreak);

  const LabelName = ParseJumpLabel(KeywordToken);
  const HasLabel = not LabelName.IsEmpty;
  const IsInsideBreakable = ((FLoopDepth > 0) or (FSwitchDepth > 0));
  if (not HasLabel) and (not IsInsideBreakable) then
    raise TJSErrorFactory.SyntaxError('Illegal break statement', KeywordToken.Line, KeywordToken.Column);

  ExpectSemicolon;

  var LabelId: TJSIdentifier := nil;
  if HasLabel then
    LabelId := TJSIdentifier.Create(LabelName);

  Result := TJSBreakStatement.Create(LabelId);
end;

function TJSParser.ParseContinueStatement: TJSContinueStatement;
begin
  const KeywordToken = CurrentToken;
  Expect(TJSTokenType.KeywordContinue);

  const LabelName = ParseJumpLabel(KeywordToken);
  const HasLabel = not LabelName.IsEmpty;
  if HasLabel then
  begin
    const LabelIndex = FindActiveLabel(LabelName);
    const LabelsLoop = FActiveLabels[LabelIndex].LabelsIteration;
    if not LabelsLoop then
      raise TJSErrorFactory.SyntaxError(Format(CONTINUE_TARGET_NOT_LOOP_MESSAGE, [LabelName]),
        KeywordToken.Line, KeywordToken.Column);
  end
  else if FLoopDepth = 0 then
  begin
    raise TJSErrorFactory.SyntaxError('Illegal continue statement', KeywordToken.Line, KeywordToken.Column);
  end;

  ExpectSemicolon;

  var LabelId: TJSIdentifier := nil;
  if HasLabel then
    LabelId := TJSIdentifier.Create(LabelName);

  Result := TJSContinueStatement.Create(LabelId);
end;

function TJSParser.ParseJumpLabel(const KeywordToken: TJSToken): string;
begin
  Result := '';

  const IsLabelOnSameLine = (Check(TJSTokenType.Identifier) and (CurrentToken.Line = KeywordToken.Line));
  if not IsLabelOnSameLine then
    Exit;

  Result := CurrentToken.Value;

  const IsDeclared = (FindActiveLabel(Result) >= 0);
  if not IsDeclared then
    raise TJSErrorFactory.SyntaxError(Format(UNDEFINED_LABEL_MESSAGE, [Result]),
      CurrentToken.Line, CurrentToken.Column);

  Advance;
end;

function TJSParser.FindActiveLabel(const LabelName: string): Integer;
begin
  for var Index := FActiveLabels.Count - 1 downto FLabelScopeStart do
  begin
    if FActiveLabels[Index].Name = LabelName then
      Exit(Index);
  end;

  Result := -1;
end;

function TJSParser.LabelsIterationStatement: Boolean;
begin
  var Offset := 0;

  while (FLexer.PeekToken(Offset).TokenType = TJSTokenType.Identifier) and
        (FLexer.PeekToken(Offset + 1).TokenType = TJSTokenType.Colon) do
  begin
    Inc(Offset, 2);
  end;

  Result := (FLexer.PeekToken(Offset).TokenType in [TJSTokenType.KeywordFor,
                                                   TJSTokenType.KeywordWhile,
                                                   TJSTokenType.KeywordDo]);
end;

function TJSParser.ParseLabeledStatement(const AllowFunction: Boolean): TJSLabeledStatement;
begin
  const LabelToken = CurrentToken;
  CheckStrictModeReservedWord(LabelToken.Value);

  const IsDuplicate = (FindActiveLabel(LabelToken.Value) >= 0);
  if IsDuplicate then
    raise TJSErrorFactory.SyntaxError(Format(DUPLICATE_LABEL_MESSAGE, [LabelToken.Value]),
      LabelToken.Line, LabelToken.Column);

  var Info: TJSLabelInfo;
  Info.Name := LabelToken.Value;
  Info.LabelsIteration := LabelsIterationStatement;

  Advance;
  Expect(TJSTokenType.Colon);

  const FollowingToken = FLexer.PeekToken(1);
  const IsLabelledGenerator = (Check(TJSTokenType.KeywordFunction) and
                               (FollowingToken.TokenType = TJSTokenType.Multiply));
  if IsLabelledGenerator then
    RaiseAtCurrentToken(GENERATOR_DECLARATION_BODY_MESSAGE);

  if StartsAsyncFunction then
    RaiseAtCurrentToken(ASYNC_DECLARATION_BODY_MESSAGE);

  const IsAllowedFunction = (AllowFunction and Check(TJSTokenType.KeywordFunction) and (not FStrictMode));
  if StartsWithDeclaration and (not IsAllowedFunction) then
    raise TJSErrorFactory.SyntaxError('Declaration is not allowed as the body of a labelled statement',
      CurrentToken.Line, CurrentToken.Column);

  FActiveLabels.Add(Info);
  try
    FAllowLabelledFunction := AllowFunction;
    const Body = ParseStatement;
    Result := TJSLabeledStatement.Create(Info.Name, Body);
  finally
    FActiveLabels.Delete(FActiveLabels.Count - 1);
  end;
end;

procedure TJSParser.RejectFunctionDeclarationBody(const Owned: array of TObject);
begin
  if not Check(TJSTokenType.KeywordFunction) then
    Exit;

  FreeOwned(Owned);

  raise TJSErrorFactory.SyntaxError(FUNCTION_DECLARATION_BODY_MESSAGE, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.FreeOwned(const Owned: array of TObject);
begin
  for var Node in Owned do
  begin
    Node.Free;
  end;
end;

function TJSParser.ParseLoopBody(const Owned: array of TObject): TJSStatement;
begin
  RejectFunctionDeclarationBody(Owned);

  Inc(FLoopDepth);
  try
    try
      Result := ParseStatement;
    except
      FreeOwned(Owned);
      raise;
    end;
  finally
    Dec(FLoopDepth);
  end;
end;

function TJSParser.ParseSwitchStatement: TJSSwitchStatement;
begin
  Expect(TJSTokenType.KeywordSwitch);
  Expect(TJSTokenType.LeftParen);

  const Discriminant = ParseExpression;

  ExpectOwning(TJSTokenType.RightParen, [Discriminant]);
  ExpectOwning(TJSTokenType.LeftBrace, [Discriminant]);

  Result := TJSSwitchStatement.Create(Discriminant);

  var HasDefaultClause := False;

  FScopes.Enter(TJSParserScopeKind.Block, nil);
  const ClosureMark = FClosureCount;

  Inc(FSwitchDepth);
  try
    while (not Check(TJSTokenType.RightBrace)) and (not IsAtEnd) do
    begin
      var Test: TJSExpression := nil;

      if Match(TJSTokenType.KeywordCase) then
      begin
        Test := ParseExpression;
      end
      else
      begin
        if HasDefaultClause then
          raise TJSErrorFactory.SyntaxError(DUPLICATE_DEFAULT_MESSAGE, CurrentToken.Line, CurrentToken.Column);

        HasDefaultClause := True;
        Expect(TJSTokenType.KeywordDefault);
      end;

      ExpectOwning(TJSTokenType.Colon, [Test]);

      const SwitchCase = TJSSwitchCase.Create(Test);
      Result.Cases.Add(SwitchCase);

      while (not Check(TJSTokenType.KeywordCase)) and
            (not Check(TJSTokenType.KeywordDefault)) and
            (not Check(TJSTokenType.RightBrace)) and
            (not IsAtEnd) do
      begin
        const Statement = ParseStatementListItem;
        SwitchCase.Consequent.Add(Statement);
      end;
    end;

    Expect(TJSTokenType.RightBrace);
    Result.ScopeInfo := FScopes.Leave;
    Dec(FSwitchDepth);
  except
    Dec(FSwitchDepth);
    Result.Free;
    raise;
  end;

  if Assigned(Result.ScopeInfo) then
    Result.ScopeInfo.MayCaptureScope := (FClosureCount <> ClosureMark);
end;

function TJSParser.ParseThrowStatement: TJSThrowStatement;
begin
  Expect(TJSTokenType.KeywordThrow);

  if CurrentToken.LineTerminatorBefore then
    raise TJSErrorFactory.SyntaxError(ILLEGAL_THROW_NEWLINE_MESSAGE, CurrentToken.Line, CurrentToken.Column);

  const Argument = ParseExpression;
  try
    ExpectSemicolon;
  except
    Argument.Free;
    raise;
  end;

  Result := TJSThrowStatement.Create(Argument);
end;

function TJSParser.ParseTryStatement: TJSTryStatement;
begin
  Expect(TJSTokenType.KeywordTry);

  const Block = ParseBlockStatement;
  var Handler: TJSCatchClause := nil;
  var Finalizer: TJSBlockStatement := nil;

  try
    if Match(TJSTokenType.KeywordCatch) then
      Handler := ParseCatchClause;

    if Match(TJSTokenType.KeywordFinally) then
      Finalizer := ParseBlockStatement;

    if (Handler = nil) and (Finalizer = nil) then
      raise TJSErrorFactory.SyntaxError('Missing catch or finally after try', CurrentToken.Line, CurrentToken.Column);
  except
    Block.Free;
    Handler.Free;
    Finalizer.Free;
    raise;
  end;

  Result := TJSTryStatement.Create(Block, Handler, Finalizer);
end;

function TJSParser.ParseCatchClause: TJSCatchClause;
begin
  Expect(TJSTokenType.LeftParen);

  if IsPatternStart then
    Exit(ParseCatchPattern);

  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const ParamName = CurrentToken.Value;
  CheckStrictModeReservedWord(ParamName);
  CheckRestrictedBindingName(ParamName);
  Advance;

  const Param = TJSIdentifier.Create(ParamName);
  var CatchBody: TJSBlockStatement;
  try
    Expect(TJSTokenType.RightParen);
    CatchBody := ParseScopedBlock(TJSParserScopeKind.Block, nil, ParamName);
  except
    Param.Free;
    raise;
  end;

  Result := TJSCatchClause.Create(Param, CatchBody);
end;

function TJSParser.ParseCatchPattern: TJSCatchClause;
begin
  const Pattern = ParseBindingTarget(TJSBindingKind.Catch);
  var CatchBody: TJSBlockStatement;

  try
    const Names = TJSPatternNames.Of_(Pattern);
    for var Index := 0 to Length(Names) - 1 do
    begin
      for var EarlierIndex := 0 to Index - 1 do
      begin
        const IsDuplicate = (Names[EarlierIndex] = Names[Index]);
        if IsDuplicate then
          raise TJSErrorFactory.SyntaxError(Format(DUPLICATE_BINDING_MESSAGE, [Names[Index]]),
                                            CurrentToken.Line, CurrentToken.Column);
      end;
    end;

    Expect(TJSTokenType.RightParen);
    CatchBody := ParseScopedBlock(TJSParserScopeKind.Block, nil, '', Names);
  except
    Pattern.Free;
    raise;
  end;

  Result := TJSCatchClause.CreateWithPattern(Pattern, CatchBody);
end;

function TJSParser.ParseEmptyStatement: TJSEmptyStatement;
begin
  Expect(TJSTokenType.Semicolon);
  Result := TJSEmptyStatement.Create;
end;

function TJSParser.ParseDebuggerStatement: TJSDebuggerStatement;
begin
  Expect(TJSTokenType.KeywordDebugger);
  ExpectSemicolon;
  Result := TJSDebuggerStatement.Create;
end;

function TJSParser.ParseExpression: TJSExpression;
begin
  const Expr = ParseAssignmentExpression;

  if Check(TJSTokenType.Comma) then
  begin
    const SeqExpr = TJSSequenceExpression.Create;
    SeqExpr.Expressions.Add(Expr);

    try
      while Match(TJSTokenType.Comma) do
      begin
        const NextExpr = ParseAssignmentExpression;
        SeqExpr.Expressions.Add(NextExpr);
      end;
    except
      SeqExpr.Free;
      raise;
    end;

    Exit(SeqExpr);
  end;

  Result := Expr;
end;

function TJSParser.ParseExpressionWithoutIn: TJSExpression;
begin
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := False;
  try
    Result := ParseExpression;
  finally
    FInOperatorAllowed := PreviousAllowed;
  end;
end;

procedure TJSParser.EnterNesting;
begin
  const IsStackFloorUnset = (FStackFloor = 0);
  if IsStackFloorUnset then
    FStackFloor := TJSStackGuard.CurrentFloor;

  var StackMarker: Byte;
  const IsStackExhausted = (NativeUInt(@StackMarker) < FStackFloor);
  const IsTooDeep = (FNestingDepth >= MAX_NESTING_DEPTH);
  if IsStackExhausted or IsTooDeep then
    raise TJSErrorFactory.RangeError(NESTING_TOO_DEEP_MESSAGE, CurrentToken.Line, CurrentToken.Column);

  Inc(FNestingDepth);
end;

procedure TJSParser.LeaveNesting;
begin
  Dec(FNestingDepth);
end;

function TJSParser.ParseNested(const ParseOperand: TJSOperandParser): TJSExpression;
begin
  EnterNesting;
  try
    Result := ParseOperand;
  finally
    LeaveNesting;
  end;
end;

function TJSParser.ParseWithInOperator(const ParseOperand: TJSOperandParser): TJSExpression;
begin
  EnterNesting;
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := True;
  try
    Result := ParseOperand;
  finally
    FInOperatorAllowed := PreviousAllowed;
    LeaveNesting;
  end;
end;

function TJSParser.ParseRightOperand(const Left: TJSExpression; const ParseOperand: TJSOperandParser): TJSExpression;
begin
  try
    Result := ParseOperand;
  except
    Left.Free;
    raise;
  end;
end;

function TJSParser.ParseMemberName(const Owner: TJSExpression): TJSIdentifier;
begin
  try
    Result := ParseIdentifierName;
  except
    Owner.Free;
    raise;
  end;
end;

function TJSParser.ParseComputedMember(const Owner: TJSExpression): TJSExpression;
begin
  Result := nil;
  try
    Result := ParseNestedExpression;
    Expect(TJSTokenType.RightBracket);
  except
    Result.Free;
    Owner.Free;
    raise;
  end;
end;

function TJSParser.ParseAssignmentOperand: TJSExpression;
begin
  Result := ParseNested(ParseAssignmentExpression);
end;

function TJSParser.ParseUnaryOperand: TJSExpression;
begin
  Result := ParseNested(ParseUnaryExpression);
end;

function TJSParser.ParseExponentOperand: TJSExpression;
begin
  Result := ParseNested(ParseExponentiationExpression);
end;

function TJSParser.ParseNewOperand: TJSExpression;
begin
  Result := ParseNested(ParseNewExpression);
end;

function TJSParser.ParseNestedExpression: TJSExpression;
begin
  Result := ParseWithInOperator(ParseExpression);
end;

function TJSParser.ParseNestedAssignmentExpression: TJSExpression;
begin
  Result := ParseWithInOperator(ParseAssignmentExpression);
end;

function TJSParser.ParseNestedBlockStatement(const Parameters: TArray<string>): TJSBlockStatement;
begin
  EnterNesting;
  const PreviousAllowed = FInOperatorAllowed;
  FInOperatorAllowed := True;
  try
    Result := ParseScopedBlock(TJSParserScopeKind.Function_, Parameters, '');
  finally
    FInOperatorAllowed := PreviousAllowed;
    LeaveNesting;
  end;
end;

function TJSParser.ParseAssignmentExpression: TJSExpression;
begin
  const IsLiteralElement = FInLiteralElement;
  FInLiteralElement := False;
  const CoverMark = FCoverInitializerCount;

  if IsYieldKeyword then
  begin
    Result := ParseYieldExpression;
    Exit;
  end;

  if StartsAsyncArrowFunction then
  begin
    Result := ParseArrowFunction(ASYNC_FUNCTION);
    Exit;
  end;

  if StartsArrowFunction then
    Exit(ParseArrowFunction);

  var Left := ParseConditionalExpression;

  if IsAssignmentOperator(CurrentToken.TokenType) then
  begin
    const IsLiteral = ((Left is TJSArrayExpression) or (Left is TJSObjectExpression)) and
                      (not Left.IsParenthesized);
    const IsPatternAssignment = IsLiteral and Check(TJSTokenType.Assign);
    if IsPatternAssignment then
      Left := ConvertToAssignmentPattern(Left)
    else
      EnsureAssignmentTarget(Left);

    const Op = TokenToAssignmentOperator(CurrentToken.TokenType);
    Advance;

    var Right: TJSExpression;
    try
      Right := ParseAssignmentOperand;
    except
      Left.Free;
      raise;
    end;

    Result := TJSAssignmentExpression.Create(Op, Left, Right);
  end
  else
  begin
    Result := Left;
  end;

  const HasStrayCoverInitializer = (not IsLiteralElement) and (FCoverInitializerCount <> CoverMark);
  if HasStrayCoverInitializer then
  begin
    Result.Free;
    raise TJSErrorFactory.SyntaxError(COVER_INITIALIZER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
  end;
end;

function TJSParser.ParseConditionalExpression: TJSExpression;
begin
  const Test = ParseShortCircuitExpression;

  if Match(TJSTokenType.Question) then
  begin
    var Consequent: TJSExpression := nil;
    var Alternate: TJSExpression := nil;
    try
      Consequent := ParseNestedAssignmentExpression;
      Expect(TJSTokenType.Colon);
      Alternate := ParseAssignmentOperand;
    except
      FreeOwned([Test, Consequent, Alternate]);
      raise;
    end;

    Exit(TJSConditionalExpression.Create(Test, Consequent, Alternate));
  end;

  Result := Test;
end;

function TJSParser.ParseShortCircuitExpression: TJSExpression;
begin
  Result := ParseLogicalOrExpression;

  const StartsNullishChain = Check(TJSTokenType.NullishCoalesce);
  if StartsNullishChain then
    Result := ParseNullishCoalesceExpression(Result);
end;

function TJSParser.ParseNullishCoalesceExpression(const Head: TJSExpression): TJSExpression;
begin
  const HeadIsBareLogical = (Head is TJSLogicalExpression) and (not Head.IsParenthesized);
  if HeadIsBareLogical then
  begin
    Head.Free;
    RaiseAtCurrentToken(NULLISH_MIXED_WITH_LOGICAL_MESSAGE);
  end;

  Result := Head;

  while Match(TJSTokenType.NullishCoalesce) do
  begin
    const Right = ParseRightOperand(Result, ParseBitwiseOrExpression);

    Result := TJSLogicalExpression.Create(TJSLogicalOperator.Nullish, Result, Right);
  end;

  const IsMixedWithLogical = (Check(TJSTokenType.LogicalOr) or Check(TJSTokenType.LogicalAnd));
  if IsMixedWithLogical then
  begin
    Result.Free;
    RaiseAtCurrentToken(NULLISH_MIXED_WITH_LOGICAL_MESSAGE);
  end;
end;

function TJSParser.ParseLogicalOrExpression: TJSExpression;
begin
  Result := ParseLogicalAndExpression;

  while Match(TJSTokenType.LogicalOr) do
  begin
    const Right = ParseRightOperand(Result, ParseLogicalAndExpression);

    Result := TJSLogicalExpression.Create(TJSLogicalOperator.Or_, Result, Right);
  end;
end;

function TJSParser.ParseLogicalAndExpression: TJSExpression;
begin
  Result := ParseBitwiseOrExpression;

  while Match(TJSTokenType.LogicalAnd) do
  begin
    const Right = ParseRightOperand(Result, ParseBitwiseOrExpression);

    Result := TJSLogicalExpression.Create(TJSLogicalOperator.And_, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseOrExpression: TJSExpression;
begin
  Result := ParseBitwiseXorExpression;

  while Match(TJSTokenType.BitwiseOr) do
  begin
    const Right = ParseRightOperand(Result, ParseBitwiseXorExpression);

    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseOr, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseXorExpression: TJSExpression;
begin
  Result := ParseBitwiseAndExpression;

  while Match(TJSTokenType.BitwiseXor) do
  begin
    const Right = ParseRightOperand(Result, ParseBitwiseAndExpression);

    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseXor, Result, Right);
  end;
end;

function TJSParser.ParseBitwiseAndExpression: TJSExpression;
begin
  Result := ParseEqualityExpression;

  while Match(TJSTokenType.BitwiseAnd) do
  begin
    const Right = ParseRightOperand(Result, ParseEqualityExpression);

    Result := TJSBinaryExpression.Create(TJSBinaryOperator.BitwiseAnd, Result, Right);
  end;
end;

function TJSParser.ParseEqualityExpression: TJSExpression;
begin
  Result := ParseRelationalExpression;

  while CheckAny([TJSTokenType.Equal, TJSTokenType.NotEqual, TJSTokenType.StrictEqual, TJSTokenType.StrictNotEqual]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.Equal:
        Op := TJSBinaryOperator.Equal;
      TJSTokenType.NotEqual:
        Op := TJSBinaryOperator.NotEqual;
      TJSTokenType.StrictEqual:
        Op := TJSBinaryOperator.StrictEqual;
      else
        Op := TJSBinaryOperator.StrictNotEqual;
    end;

    Advance;

    const Right = ParseRightOperand(Result, ParseRelationalExpression);

    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseRelationalExpression: TJSExpression;
begin
  Result := ParseShiftExpression;

  while IsRelationalOperator do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LessThan:
        Op := TJSBinaryOperator.LessThan;
      TJSTokenType.GreaterThan:
        Op := TJSBinaryOperator.GreaterThan;
      TJSTokenType.LessThanOrEqual:
        Op := TJSBinaryOperator.LessThanOrEqual;
      TJSTokenType.GreaterThanOrEqual:
        Op := TJSBinaryOperator.GreaterThanOrEqual;
      TJSTokenType.KeywordInstanceof:
        Op := TJSBinaryOperator.InstanceOf;
      else
        Op := TJSBinaryOperator.In_;
    end;

    Advance;

    const Right = ParseRightOperand(Result, ParseShiftExpression);

    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseShiftExpression: TJSExpression;
begin
  Result := ParseAdditiveExpression;

  while CheckAny([TJSTokenType.LeftShift, TJSTokenType.RightShift, TJSTokenType.UnsignedRightShift]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LeftShift:
        Op := TJSBinaryOperator.LeftShift;
      TJSTokenType.RightShift:
        Op := TJSBinaryOperator.RightShift;
      else
        Op := TJSBinaryOperator.UnsignedRightShift;
    end;

    Advance;

    const Right = ParseRightOperand(Result, ParseAdditiveExpression);

    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseAdditiveExpression: TJSExpression;
begin
  Result := ParseMultiplicativeExpression;

  while CheckAny([TJSTokenType.Plus, TJSTokenType.Minus]) do
  begin
    var Op: TJSBinaryOperator;

    if CurrentToken.TokenType = TJSTokenType.Plus then
      Op := TJSBinaryOperator.Add
    else
      Op := TJSBinaryOperator.Subtract;

    Advance;

    const Right = ParseRightOperand(Result, ParseMultiplicativeExpression);

    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseMultiplicativeExpression: TJSExpression;
begin
  Result := ParseExponentiationExpression;

  while CheckAny([TJSTokenType.Multiply, TJSTokenType.Divide, TJSTokenType.Modulo]) do
  begin
    var Op: TJSBinaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.Multiply:
        Op := TJSBinaryOperator.Multiply;
      TJSTokenType.Divide:
        Op := TJSBinaryOperator.Divide;
      else
        Op := TJSBinaryOperator.Modulo;
    end;

    Advance;

    const Right = ParseRightOperand(Result, ParseExponentiationExpression);

    Result := TJSBinaryExpression.Create(Op, Result, Right);
  end;
end;

function TJSParser.ParseExponentiationExpression: TJSExpression;
begin
  const StartsWithUnaryOperator = CheckAny([TJSTokenType.LogicalNot, TJSTokenType.BitwiseNot, TJSTokenType.Plus,
                                            TJSTokenType.Minus, TJSTokenType.KeywordTypeof, TJSTokenType.KeywordVoid,
                                            TJSTokenType.KeywordDelete]) or IsAwaitKeyword;

  Result := ParseUnaryExpression;

  if not Check(TJSTokenType.Exponent) then
    Exit;

  if StartsWithUnaryOperator then
  begin
    Result.Free;
    raise TJSErrorFactory.SyntaxError(UNARY_BEFORE_EXPONENT_MESSAGE, CurrentToken.Line, CurrentToken.Column);
  end;

  Advance;

  const Right = ParseRightOperand(Result, ParseExponentOperand);

  Result := TJSBinaryExpression.Create(TJSBinaryOperator.Exponent, Result, Right);
end;

function TJSParser.ParseUnaryExpression: TJSExpression;
begin
  if IsAwaitKeyword then
  begin
    Result := ParseAwaitExpression;
    Exit;
  end;

  if CheckAny([TJSTokenType.LogicalNot, TJSTokenType.BitwiseNot, TJSTokenType.Plus, TJSTokenType.Minus,
               TJSTokenType.KeywordTypeof, TJSTokenType.KeywordVoid, TJSTokenType.KeywordDelete]) then
  begin
    var Op: TJSUnaryOperator;

    case CurrentToken.TokenType of
      TJSTokenType.LogicalNot:
        Op := TJSUnaryOperator.LogicalNot;
      TJSTokenType.BitwiseNot:
        Op := TJSUnaryOperator.BitwiseNot;
      TJSTokenType.Plus:
        Op := TJSUnaryOperator.Plus;
      TJSTokenType.Minus:
        Op := TJSUnaryOperator.Minus;
      TJSTokenType.KeywordTypeof:
        Op := TJSUnaryOperator.TypeOf;
      TJSTokenType.KeywordVoid:
        Op := TJSUnaryOperator.Void;
      else
        Op := TJSUnaryOperator.Delete;
    end;

    Advance;

    const Argument = ParseUnaryOperand;

    const IsStrictIdentifierDelete = (Op = TJSUnaryOperator.Delete) and FStrictMode and
                                     (Argument is TJSIdentifier);
    if IsStrictIdentifierDelete then
    begin
      Argument.Free;
      raise TJSErrorFactory.SyntaxError(DELETE_IDENTIFIER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
    end;

    Exit(TJSUnaryExpression.Create(Op, Argument, True));
  end;

  Result := ParseUpdateExpression;
end;

function TJSParser.ParseUpdateExpression: TJSExpression;
begin
  if CheckAny([TJSTokenType.Increment, TJSTokenType.Decrement]) then
  begin
    var Op: TJSUpdateOperator;

    if CurrentToken.TokenType = TJSTokenType.Increment then
      Op := TJSUpdateOperator.Increment
    else
      Op := TJSUpdateOperator.Decrement;

    Advance;

    const Argument = ParseCallExpression;
    EnsureAssignmentTarget(Argument);

    Exit(TJSUpdateExpression.Create(Op, Argument, True));
  end;

  const Argument = ParseCallExpression;

  const IsUpdateToken = CheckAny([TJSTokenType.Increment, TJSTokenType.Decrement]);
  const IsOnSameLine = (CurrentToken.Line = FPreviousTokenLine);
  if IsUpdateToken and IsOnSameLine then
  begin
    EnsureAssignmentTarget(Argument);

    var Op: TJSUpdateOperator;

    if CurrentToken.TokenType = TJSTokenType.Increment then
      Op := TJSUpdateOperator.Increment
    else
      Op := TJSUpdateOperator.Decrement;

    Advance;

    Exit(TJSUpdateExpression.Create(Op, Argument, False));
  end;

  Result := Argument;
end;

function TJSParser.ParseCallExpression: TJSExpression;
begin
  if Check(TJSTokenType.KeywordNew) then
    Result := ParseNewOperand
  else
    Result := ParseMemberExpression;

  while True do
  begin
    if Check(TJSTokenType.LeftParen) then
    begin
      const CallExpr = TJSCallExpression.Create(Result);
      try
        CallExpr.HasSpread := ParseArguments(CallExpr.Arguments);
      except
        CallExpr.Free;
        raise;
      end;

      Result := CallExpr;
    end
    else if Match(TJSTokenType.Dot) then
    begin
      const Prop = ParseMemberName(Result);
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseComputedMember(Result);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else if IsTemplateStart then
      Result := ParseTaggedTemplate(Result)
    else
      Break;
  end;
end;

function TJSParser.ParseIdentifierName: TJSIdentifier;
begin
  if not TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  Result := TJSIdentifier.Create(CurrentToken.Value);
  Advance;
end;

function TJSParser.ParseMemberExpression: TJSExpression;
begin
  if Check(TJSTokenType.KeywordNew) then
    Result := ParseNewOperand
  else
    Result := ParsePrimaryExpression;

  while True do
  begin
    if Match(TJSTokenType.Dot) then
    begin
      const Prop = ParseMemberName(Result);
      Result := TJSMemberExpression.Create(Result, Prop, False);
    end
    else if Match(TJSTokenType.LeftBracket) then
    begin
      const Prop = ParseComputedMember(Result);
      Result := TJSMemberExpression.Create(Result, Prop, True);
    end
    else if IsTemplateStart then
      Result := ParseTaggedTemplate(Result)
    else
      Break;
  end;
end;

function TJSParser.IsTemplateStart: Boolean;
begin
  Result := Check(TJSTokenType.TemplateChunk) and CurrentToken.IsTemplateHead;
end;

function TJSParser.ParseTemplateLiteral: TJSTemplateLiteral;
begin
  Result := TJSTemplateLiteral.Create;
  Result.Line := CurrentToken.Line;
  Result.Column := CurrentToken.Column;

  try
    ReadTemplateParts(False, Result.Parts, Result.Expressions);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseTaggedTemplate(const Tag: TJSExpression): TJSTaggedTemplateExpression;
begin
  const Site = TJSTemplateObject.Create;
  Site.Line := CurrentToken.Line;
  Site.Column := CurrentToken.Column;

  Result := TJSTaggedTemplateExpression.Create(Tag);
  Result.Line := Site.Line;
  Result.Column := Site.Column;
  Result.Arguments.Add(Site);

  try
    ReadTemplateParts(True, Site.Parts, Result.Arguments);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ReadTemplateParts(const IsTagged: Boolean; const Parts: TList<TJSTemplatePart>;
                                      const Expressions: TObjectList<TJSExpression>);
begin
  var Chunk := CurrentToken;

  while True do
  begin
    const Part = CreateTemplatePart(Chunk, IsTagged);
    Parts.Add(Part);
    Advance;

    if Chunk.IsTemplateTail then
      Exit;

    const Substitution = ParseNestedExpression;
    Expressions.Add(Substitution);

    Chunk := CurrentToken;
    const ContinuesTemplate = (Chunk.TokenType = TJSTokenType.TemplateChunk) and (not Chunk.IsTemplateHead);
    if not ContinuesTemplate then
      raise TJSErrorFactory.UnexpectedToken(Chunk.Value, Chunk.Line, Chunk.Column);
  end;
end;

function TJSParser.CreateTemplatePart(const Chunk: TJSToken; const IsTagged: Boolean): TJSTemplatePart;
begin
  const IsRejected = Chunk.HasInvalidEscape and (not IsTagged);
  if IsRejected then
    raise TJSErrorFactory.SyntaxError(INVALID_TEMPLATE_ESCAPE_MESSAGE, Chunk.Line, Chunk.Column);

  Result.Cooked := Chunk.Value;
  Result.Raw := Chunk.RawValue;
  Result.HasCooked := not Chunk.HasInvalidEscape;
end;

function TJSParser.ParseNewExpression: TJSExpression;
begin
  Expect(TJSTokenType.KeywordNew);

  if Check(TJSTokenType.Dot) then
  begin
    Result := ParseNewTarget;
    Exit;
  end;

  const Callee = ParseMemberExpression;
  if Callee is TJSSuperExpression then
  begin
    Callee.Free;
    RaiseAtCurrentToken(NEW_SUPER_MESSAGE);
  end;

  const NewExpr = TJSNewExpression.Create(Callee);

  if Check(TJSTokenType.LeftParen) then
  begin
    try
      NewExpr.HasSpread := ParseArguments(NewExpr.Arguments);
    except
      NewExpr.Free;
      raise;
    end;
  end;

  Result := NewExpr;
end;

function TJSParser.ParsePrimaryExpression: TJSExpression;
begin
  case CurrentToken.TokenType of
    TJSTokenType.Identifier:
      begin
        if StartsAsyncFunction then
        begin
          Result := ParseFunctionExpression(ASYNC_FUNCTION);
          Exit;
        end;

        const Name = CurrentToken.Value;
        CheckStrictModeReservedWord(Name);

        if Name = EVAL_NAME then
          Inc(FClosureCount);

        Advance;
        Exit(TJSIdentifier.Create(Name));
      end;

    TJSTokenType.NumberLiteral:
      begin
        const Value = CurrentToken.NumberValue;
        RejectLegacyLiteralInStrictMode(CurrentToken);
        Advance;
        Exit(TJSLiteral.CreateNumber(Value));
      end;

    TJSTokenType.StringLiteral:
      begin
        const Value = CurrentToken.Value;
        RejectLegacyLiteralInStrictMode(CurrentToken);
        Advance;
        Exit(TJSLiteral.CreateString(Value));
      end;

    TJSTokenType.BooleanLiteral:
      begin
        const Value = (CurrentToken.Value = TRUE_VALUE);
        Advance;
        Exit(TJSLiteral.CreateBoolean(Value));
      end;

    TJSTokenType.NullLiteral:
      begin
        Advance;
        Exit(TJSLiteral.CreateNull);
      end;

    TJSTokenType.RegExpLiteral:
      begin
        const Pattern = CurrentToken.Value;
        const Flags = CurrentToken.RawValue;
        const Line = CurrentToken.Line;
        const Column = CurrentToken.Column;
        Advance;

        const Position = TJSSourcePosition.At(Line, Column);
        TJSRegExpSyntax.ValidateFlags(Flags, Position);
        TJSRegExpSyntax.ValidatePattern(Pattern, Flags, Position);

        Exit(TJSLiteral.CreateRegExp(Pattern, Flags));
      end;

    TJSTokenType.KeywordThis:
      begin
        Advance;
        Exit(TJSThisExpression.Create);
      end;

    TJSTokenType.TemplateChunk:
      begin
        if not CurrentToken.IsTemplateHead then
          raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

        Exit(ParseTemplateLiteral);
      end;

    TJSTokenType.LeftParen:
      begin
        Advance;
        const Expr = ParseNestedExpression;
        ExpectOwning(TJSTokenType.RightParen, [Expr]);

        Expr.IsParenthesized := True;

        Exit(Expr);
      end;

    TJSTokenType.LeftBracket:
      Exit(ParseArrayExpression);

    TJSTokenType.LeftBrace:
      Exit(ParseObjectExpression);

    TJSTokenType.KeywordFunction:
      Exit(ParseFunctionExpression);

    TJSTokenType.KeywordClass:
      Result := ParseClass(NAME_OPTIONAL);

    TJSTokenType.KeywordSuper:
      Result := ParseSuperExpression;

    else
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
  end;
end;

function TJSParser.ParseArrayExpression: TJSArrayExpression;
begin
  Expect(TJSTokenType.LeftBracket);

  Result := TJSArrayExpression.Create;

  try
    while not Check(TJSTokenType.RightBracket) do
    begin
      if Check(TJSTokenType.Comma) then
      begin
        Result.Elements.Add(nil);
        Advance;
      end
      else
      begin
        FInLiteralElement := True;
        const Element = ParseSpreadOrAssignmentExpression;
        Result.Elements.Add(Element);

        const IsSpread = (Element is TJSSpreadElement);
        Result.HasSpread := Result.HasSpread or IsSpread;
        if IsSpread and Check(TJSTokenType.Comma) then
          Result.SpreadFollowedByComma := True;

        if not Check(TJSTokenType.RightBracket) then
          Expect(TJSTokenType.Comma);
      end;
    end;

    Expect(TJSTokenType.RightBracket);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseObjectExpression: TJSObjectExpression;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSObjectExpression.Create;

  try
    var HasPrototypeSetter := False;

    while not Check(TJSTokenType.RightBrace) do
    begin
      const Member = ParseObjectMember;
      Result.Properties.Add(Member);

      const IsDuplicatePrototype = Member.SetsPrototype and HasPrototypeSetter;
      if IsDuplicatePrototype and (not Result.HasDuplicatePrototype) then
      begin
        Result.HasDuplicatePrototype := True;
        Inc(FCoverInitializerCount);
      end;

      HasPrototypeSetter := HasPrototypeSetter or Member.SetsPrototype;

      if (Member.Kind = TJSPropertyKind.Spread) and Check(TJSTokenType.Comma) then
        Result.SpreadFollowedByComma := True;

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseObjectMember: TJSObjectProperty;
begin
  if Match(TJSTokenType.Ellipsis) then
  begin
    const SpreadValue = ParseNestedAssignmentExpression;
    Exit(TJSObjectProperty.Create(nil, SpreadValue, False, TJSPropertyKind.Spread));
  end;

  if StartsAccessorProperty then
    Exit(ParseAccessorProperty);

  const MemberStart = CurrentToken.StartOffset;
  const IsAsync = StartsAsyncModifier;
  if IsAsync then
    Advance;

  const IsGenerator = Match(TJSTokenType.Multiply);
  RejectAsyncGenerator(IsGenerator, IsAsync);

  const KeyIsIdentifier = (Check(TJSTokenType.Identifier) and (not IsGenerator) and (not IsAsync));
  const KeyText = CurrentToken.Value;

  var Computed: Boolean;
  const Key = ParsePropertyKey(Computed);
  try
    if (IsGenerator or IsAsync) and (not Check(TJSTokenType.LeftParen)) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    if Match(TJSTokenType.Colon) then
    begin
      FInLiteralElement := True;
      const Value = ParseNestedAssignmentExpression;
      Result := TJSObjectProperty.Create(Key, Value, Computed);
      Exit;
    end;

    if Check(TJSTokenType.LeftParen) then
    begin
      Result := ParseMethodProperty(Key, Computed, MemberStart, IsGenerator, IsAsync);
      Exit;
    end;

    const EndsMember = Check(TJSTokenType.Comma) or Check(TJSTokenType.RightBrace);
    const IsShorthand = KeyIsIdentifier and (not Computed) and EndsMember;
    if IsShorthand then
    begin
      Result := ParseShorthandProperty(Key, KeyText);
      Exit;
    end;

    const IsCoverInitializer = KeyIsIdentifier and (not Computed) and Check(TJSTokenType.Assign);
    if IsCoverInitializer then
    begin
      Result := ParseCoverInitializedProperty(Key, KeyText);
      Exit;
    end;

    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
  except
    Key.Free;
    raise;
  end;
end;

function TJSParser.ParseShorthandProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
begin
  CheckStrictModeReservedWord(Name);

  const IsEval = (Name = EVAL_NAME);
  if IsEval then
    Inc(FClosureCount);

  const Value = TJSIdentifier.Create(Name);
  Result := TJSObjectProperty.Create(Key, Value, False, TJSPropertyKind.Shorthand);
end;

function TJSParser.ParseCoverInitializedProperty(const Key: TJSExpression; const Name: string): TJSObjectProperty;
begin
  CheckStrictModeReservedWord(Name);
  Expect(TJSTokenType.Assign);

  const Default = ParseNestedAssignmentExpression;
  const Target = TJSIdentifier.Create(Name);
  const Value = TJSAssignmentPattern.Create(Target, Default);

  Inc(FCoverInitializerCount);
  Result := TJSObjectProperty.Create(Key, Value, False, TJSPropertyKind.Shorthand);
end;

function TJSParser.ParseMethodProperty(const Key: TJSExpression; const Computed: Boolean;
                                       const SourceStart: Integer; const IsGenerator: Boolean;
                                       const IsAsync: Boolean): TJSObjectProperty;
begin
  const Func = ParseMethodFunction(TJSFunctionContext.Method, IsGenerator, IsAsync, SourceStart);

  Result := TJSObjectProperty.Create(Key, Func, Computed, TJSPropertyKind.Method);
end;

function TJSParser.ParseMethodFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                       const IsAsync: Boolean; const SourceStart: Integer): TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;
  try
    ParseFunctionSignatureAndBody(Result, Context, IsGenerator, IsAsync);
    RejectDuplicateParameters(Result.Params);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.StartsAccessorProperty: Boolean;
begin
  const IsGetOrSet = Check(TJSTokenType.Identifier) and (not CurrentToken.HasEscape) and
                     ((CurrentToken.Value = KEYWORD_GET) or (CurrentToken.Value = KEYWORD_SET));
  if not IsGetOrSet then
    Exit(False);

  const FollowingType = FLexer.PeekToken(1).TokenType;
  Result := not (FollowingType in [TJSTokenType.Colon, TJSTokenType.LeftParen, TJSTokenType.Comma,
                                   TJSTokenType.RightBrace, TJSTokenType.Assign]);
end;

function TJSParser.ParsePropertyKey(out Computed: Boolean): TJSExpression;
begin
  Computed := False;

  if Check(TJSTokenType.StringLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result := TJSLiteral.CreateString(CurrentToken.Value);
    Advance;
  end
  else if Check(TJSTokenType.NumberLiteral) then
  begin
    RejectLegacyLiteralInStrictMode(CurrentToken);
    Result := TJSLiteral.CreateNumber(CurrentToken.NumberValue);
    Advance;
  end
  else if TJSKeywords.IsIdentifierName(CurrentToken.TokenType) then
  begin
    Result := ParseIdentifierName;
  end
  else if Check(TJSTokenType.LeftBracket) then
  begin
    Advance;
    Result := ParseNestedAssignmentExpression;
    Computed := True;
    try
      Expect(TJSTokenType.RightBracket);
    except
      Result.Free;
      raise;
    end;
  end
  else
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.ParseAccessorProperty: TJSObjectProperty;
begin
  const SourceStart = CurrentToken.StartOffset;
  var Kind := TJSPropertyKind.Getter;
  const IsSetter = (CurrentToken.Value = KEYWORD_SET);
  if IsSetter then
    Kind := TJSPropertyKind.Setter;
  Advance;

  var Computed: Boolean;
  const Key = ParsePropertyKey(Computed);
  try
    const Func = ParseAccessorFunction(Kind, SourceStart);
    Result := TJSObjectProperty.Create(Key, Func, Computed, Kind);
  except
    Key.Free;
    raise;
  end;
end;

function TJSParser.ParseAccessorFunction(const Kind: TJSPropertyKind; const SourceStart: Integer;
                                         const Context: TJSFunctionContext): TJSFunctionExpression;
begin
  Result := TJSFunctionExpression.Create;

  try
    const AccessorLine = CurrentToken.Line;
    const AccessorColumn = CurrentToken.Column;

    ParseFunctionSignatureAndBody(Result, Context);

    const ExpectedParamCount = Ord(Kind = TJSPropertyKind.Setter);
    const HasRest = Assigned(Result.ParameterInfo) and Assigned(Result.ParameterInfo.Rest);
    const HasExpectedParams = (Result.Params.Count = ExpectedParamCount) and (not HasRest);
    if not HasExpectedParams then
      raise TJSErrorFactory.SyntaxError(ACCESSOR_PARAMETER_COUNT_MESSAGE, AccessorLine, AccessorColumn);

    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseClassDeclaration: TJSVariableDeclaration;
begin
  const ClassNode = ParseClass(NAME_REQUIRED);
  const ClassId = TJSIdentifier.Create(ClassNode.Id.Name);
  const Declarator = TJSVariableDeclarator.Create(ClassId, ClassNode);

  Result := TJSVariableDeclaration.Create;
  Result.Kind := TJSDeclarationKind.Let;
  Result.Declarations.Add(Declarator);
  FScopes.AddDeclaration(Result);
end;

function TJSParser.ParseClass(const RequireName: Boolean): TJSClassExpression;
begin
  const SourceStart = CurrentToken.StartOffset;
  Expect(TJSTokenType.KeywordClass);
  EnterNesting;

  const OuterStrictMode = FStrictMode;
  FStrictMode := True;
  try
    Result := ParseClassDefinition(RequireName, SourceStart);
  finally
    FStrictMode := OuterStrictMode;
    LeaveNesting;
  end;
end;

function TJSParser.ParseClassDefinition(const RequireName: Boolean; const SourceStart: Integer): TJSClassExpression;
begin
  Result := TJSClassExpression.Create;
  try
    const HasName = Check(TJSTokenType.Identifier);
    const IsMissingName = (RequireName and (not HasName));
    if IsMissingName then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    if HasName then
    begin
      const ClassName = CurrentToken.Value;
      CheckLexicalBindingName(ClassName);

      if RequireName then
        DeclareClassName(ClassName);

      Result.Id := TJSIdentifier.Create(ClassName);
      Advance;
    end;

    Inc(FClosureCount);
    ParseClassHeritage(Result);
    ParseClassBody(Result);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.DeclareClassName(const ClassName: string);
begin
  const IsFunction = False;
  const AllowFunctionDuplicate = False;
  DeclareLexicalName(ClassName, IsFunction, AllowFunctionDuplicate);
end;

procedure TJSParser.ParseClassHeritage(const Target: TJSClassExpression);
begin
  if Match(TJSTokenType.KeywordExtends) then
    Target.SuperClass := ParseCallExpression;
end;

procedure TJSParser.ParseClassBody(const Target: TJSClassExpression);
begin
  Expect(TJSTokenType.LeftBrace);

  while not Check(TJSTokenType.RightBrace) do
  begin
    ParseClassMember(Target);
  end;

  Expect(TJSTokenType.RightBrace);
end;

function TJSParser.StartsStaticModifier: Boolean;
begin
  const IsStaticWord = (CurrentToken.IsIdentifierNamed(STATIC_NAME) and (not CurrentToken.HasEscape));
  if not IsStaticWord then
    Exit(False);

  const FollowingToken = FLexer.PeekToken(1);
  const FollowingType = FollowingToken.TokenType;
  Result := not (FollowingType in [TJSTokenType.LeftParen, TJSTokenType.Assign, TJSTokenType.Semicolon,
                                   TJSTokenType.RightBrace]);
end;

function TJSParser.ParseClassMemberKind(const HasModifier: Boolean): TJSPropertyKind;
begin
  const IsAccessor = ((not HasModifier) and StartsAccessorProperty);
  if not IsAccessor then
    Exit(TJSPropertyKind.Method);

  const IsSetter = (CurrentToken.Value = KEYWORD_SET);
  if IsSetter then
    Result := TJSPropertyKind.Setter
  else
    Result := TJSPropertyKind.Getter;

  Advance;
end;

function TJSParser.ClassMemberKeyText(const Key: TJSExpression; const Computed: Boolean): string;
begin
  Result := '';

  if Computed then
    Exit;

  if Key is TJSIdentifier then
  begin
    Result := TJSIdentifier(Key).Name;
    Exit;
  end;

  const IsStringKey = (Key is TJSLiteral) and (TJSLiteral(Key).LiteralType = TJSLiteralType.String_);
  if IsStringKey then
    Result := TJSLiteral(Key).StringValue;
end;

procedure TJSParser.ParseClassMember(const Target: TJSClassExpression);
begin
  if Match(TJSTokenType.Semicolon) then
    Exit;

  var Head := Default(TJSClassMemberHead);
  Head.IsStatic := StartsStaticModifier;
  if Head.IsStatic then
    Advance;

  Head.SourceStart := CurrentToken.StartOffset;
  Head.IsAsync := StartsAsyncModifier;
  if Head.IsAsync then
    Advance;

  Head.IsGenerator := Match(TJSTokenType.Multiply);
  RejectAsyncGenerator(Head.IsGenerator, Head.IsAsync);

  const HasModifier = (Head.IsGenerator or Head.IsAsync);
  Head.Kind := ParseClassMemberKind(HasModifier);

  const Key = ParsePropertyKey(Head.Computed);
  Head.KeyText := ClassMemberKeyText(Key, Head.Computed);

  var Func: TJSFunctionExpression;
  try
    ValidateClassMember(Target, Head);
    Func := ParseClassMemberFunction(Target, Head);
  except
    Key.Free;
    raise;
  end;

  AddClassMember(Target, Key, Func, Head);
end;

procedure TJSParser.ValidateClassMember(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
begin
  const IsField = (not Check(TJSTokenType.LeftParen));
  if IsField then
    RaiseAtCurrentToken(CLASS_FIELD_MESSAGE);

  ValidateClassMemberName(Target, Head);

  const IsSpecialConstructor = (Head.IsConstructor and (Head.IsGenerator or Head.IsAsync));
  if IsSpecialConstructor then
    RaiseAtCurrentToken(CONSTRUCTOR_NOT_PLAIN_MESSAGE);
end;

procedure TJSParser.ValidateClassMemberName(const Target: TJSClassExpression; const Head: TJSClassMemberHead);
begin
  const IsPlainMethod = (Head.Kind = TJSPropertyKind.Method);
  const IsSpecialConstructor = (Head.IsConstructor and (not IsPlainMethod));
  if IsSpecialConstructor then
    RaiseAtCurrentToken(SPECIAL_CONSTRUCTOR_MESSAGE);

  const IsDuplicateConstructor = (Head.IsConstructor and Assigned(Target.Constructor_));
  if IsDuplicateConstructor then
    RaiseAtCurrentToken(DUPLICATE_CONSTRUCTOR_MESSAGE);

  const IsStaticPrototype = (Head.IsStatic and (Head.KeyText = PROTOTYPE_NAME));
  if IsStaticPrototype then
    RaiseAtCurrentToken(STATIC_PROTOTYPE_MESSAGE);
end;

class function TJSParser.ClassFunctionContext(const IsConstructor: Boolean;
                                              const HasSuperClass: Boolean): TJSFunctionContext;
begin
  const IsDerivedConstructor = (IsConstructor and HasSuperClass);
  if IsDerivedConstructor then
    Result := TJSFunctionContext.DerivedConstructor
  else
    Result := TJSFunctionContext.Method;
end;

function TJSParser.ParseClassMemberFunction(const Target: TJSClassExpression;
                                            const Head: TJSClassMemberHead): TJSFunctionExpression;
begin
  const IsAccessor = (Head.Kind <> TJSPropertyKind.Method);
  if IsAccessor then
  begin
    Result := ParseAccessorFunction(Head.Kind, Head.SourceStart);
    Exit;
  end;

  const HasSuperClass = Assigned(Target.SuperClass);
  const Context = ClassFunctionContext(Head.IsConstructor, HasSuperClass);

  Result := ParseMethodFunction(Context, Head.IsGenerator, Head.IsAsync, Head.SourceStart);
end;

procedure TJSParser.AddClassMember(const Target: TJSClassExpression; const Key: TJSExpression;
                                   const Func: TJSFunctionExpression; const Head: TJSClassMemberHead);
begin
  if Head.IsConstructor then
  begin
    Target.Constructor_ := Func;
    Key.Free;
    Exit;
  end;

  const Member = TJSClassMember.Create(Key, Func, Head.Computed, Head.IsStatic, Head.Kind);
  Target.Members.Add(Member);
end;

function TJSParser.ParseSuperExpression: TJSExpression;
begin
  const Line = CurrentToken.Line;
  const Column = CurrentToken.Column;
  Expect(TJSTokenType.KeywordSuper);

  var IsAllowed: Boolean;
  case CurrentToken.TokenType of
    TJSTokenType.LeftParen:
      IsAllowed := FContext.AllowSuperCall;
    TJSTokenType.Dot,
    TJSTokenType.LeftBracket:
      IsAllowed := FContext.AllowSuperProperty;
  else
    IsAllowed := False;
  end;

  if not IsAllowed then
    raise TJSErrorFactory.SyntaxError(SUPER_OUTSIDE_METHOD_MESSAGE, Line, Column);

  Result := TJSSuperExpression.Create;
end;

function TJSParser.ParseNewTarget: TJSExpression;
begin
  const Line = CurrentToken.Line;
  const Column = CurrentToken.Column;
  Expect(TJSTokenType.Dot);

  const IsTargetName = (CurrentToken.IsIdentifierNamed(TARGET_NAME) and (not CurrentToken.HasEscape));
  if not IsTargetName then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  if not FContext.AllowNewTarget then
    raise TJSErrorFactory.SyntaxError(NEW_TARGET_OUTSIDE_FUNCTION_MESSAGE, Line, Column);

  Advance;
  Result := TJSNewTargetExpression.Create;
end;

function TJSParser.ParseFunctionExpression(const IsAsync: Boolean): TJSFunctionExpression;
begin
  const SourceStart = CurrentToken.StartOffset;
  if IsAsync then
    Advance;

  Expect(TJSTokenType.KeywordFunction);

  const IsGenerator = Match(TJSTokenType.Multiply);
  RejectAsyncGenerator(IsGenerator, IsAsync);

  Result := TJSFunctionExpression.Create;

  try
    if Check(TJSTokenType.Identifier) then
    begin
      const FuncName = CurrentToken.Value;
      CheckFunctionExpressionName(FuncName, IsGenerator, IsAsync);

      Advance;
      Result.Id := TJSIdentifier.Create(FuncName);
    end;

    ParseFunctionSignatureAndBody(Result, TJSFunctionContext.Ordinary, IsGenerator, IsAsync);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.CheckFunctionExpressionName(const FuncName: string; const IsGenerator: Boolean;
                                                const IsAsync: Boolean);
begin
  const OuterState = SaveFunctionState;
  FInGenerator := IsGenerator;
  FInAsync := IsAsync;
  try
    CheckStrictModeReservedWord(FuncName);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSParser.ParseFunctionSignatureAndBody(const Func: TJSFunctionExpression;
                                                  const Context: TJSFunctionContext;
                                                  const IsGenerator: Boolean; const IsAsync: Boolean);
begin
  const OuterState = SaveFunctionState;
  EnterFunction(Context, IsGenerator, IsAsync);
  Func.IsGenerator := IsGenerator;
  Func.IsAsync := IsAsync;
  try
    ParseSignatureAndBodyInContext(Func, IsGenerator, IsAsync);
  finally
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSParser.ParseSignatureAndBodyInContext(const Func: TJSFunctionExpression; const IsGenerator: Boolean;
                                                   const IsAsync: Boolean);
begin
  Func.ParameterInfo := ParseFormalParameters(Func.Params);
  FYieldForbidden := False;
  FAwaitForbidden := False;

  Inc(FClosureCount);

  const OldStrictMode = FStrictMode;
  const Body = ParseFunctionBodyBlock(Func.Params, Func.ParameterInfo);
  Func.Body := Body;
  MarkSuspendableBody(Body, IsGenerator, IsAsync);

  if Body.DeclaresStrictMode then
  begin
    Func.IsStrict := True;
    FStrictMode := True;
  end;

  var FuncName := '';
  if Assigned(Func.Id) then
    FuncName := Func.Id.Name;

  CheckStrictFunctionHeader(FuncName, Func.Params, Func.ParameterInfo);
  FStrictMode := OldStrictMode;
end;

function TJSParser.IsYieldKeyword: Boolean;
begin
  Result := (FInGenerator and CurrentToken.IsIdentifierNamed(YIELD_NAME));
end;

function TJSParser.StartsYieldOperand: Boolean;
begin
  const HasLineBreak = CurrentToken.LineTerminatorBefore;
  if HasLineBreak then
    Exit(False);

  const EndsExpression = CheckAny([TJSTokenType.RightParen, TJSTokenType.RightBracket, TJSTokenType.RightBrace,
                                   TJSTokenType.Comma, TJSTokenType.Semicolon, TJSTokenType.Colon,
                                   TJSTokenType.EndOfFile, TJSTokenType.KeywordIn]);
  const ContinuesTemplate = (Check(TJSTokenType.TemplateChunk) and (not CurrentToken.IsTemplateHead));
  Result := not (EndsExpression or ContinuesTemplate);
end;

function TJSParser.ParseYieldExpression: TJSExpression;
begin
  const YieldToken = CurrentToken;
  if FYieldForbidden then
    raise TJSErrorFactory.SyntaxError(YIELD_IN_PARAMETERS_MESSAGE, YieldToken.Line, YieldToken.Column);

  if YieldToken.HasEscape then
    raise TJSErrorFactory.SyntaxError(YIELD_ESCAPE_MESSAGE, YieldToken.Line, YieldToken.Column);

  Advance;

  var IsDelegate := False;
  var Argument: TJSExpression := nil;

  const HasLineBreak = CurrentToken.LineTerminatorBefore;
  if (not HasLineBreak) and Match(TJSTokenType.Multiply) then
  begin
    IsDelegate := True;
    Argument := ParseAssignmentOperand;
  end
  else if StartsYieldOperand then
  begin
    Argument := ParseAssignmentOperand;
  end;

  Result := TJSYieldExpression.Create(Argument, IsDelegate);
  Result.Line := YieldToken.Line;
  Result.Column := YieldToken.Column;
end;

procedure TJSParser.MarkSuspendableBody(const Body: TJSBlockStatement; const IsGenerator: Boolean;
                                      const IsAsync: Boolean);
begin
  if not (IsGenerator or IsAsync) then
    Exit;

  Body.IsGeneratorBody := IsGenerator;
  Body.IsAsyncBody := IsAsync;
  TJSSuspensionAnalysis.Mark(Body);
end;

function TJSParser.IsAwaitKeyword: Boolean;
begin
  Result := (FInAsync and CurrentToken.IsIdentifierNamed(AWAIT_NAME));
end;

function TJSParser.ParseAwaitExpression: TJSExpression;
begin
  const AwaitToken = CurrentToken;
  if FAwaitForbidden then
    raise TJSErrorFactory.SyntaxError(AWAIT_IN_PARAMETERS_MESSAGE, AwaitToken.Line, AwaitToken.Column);

  if AwaitToken.HasEscape then
    raise TJSErrorFactory.SyntaxError(AWAIT_ESCAPE_MESSAGE, AwaitToken.Line, AwaitToken.Column);

  Advance;

  const Argument = ParseUnaryOperand;
  Result := TJSAwaitExpression.Create(Argument);
  Result.Line := AwaitToken.Line;
  Result.Column := AwaitToken.Column;
end;

function TJSParser.IsAsyncWord: Boolean;
begin
  Result := (CurrentToken.IsIdentifierNamed(ASYNC_NAME) and (not CurrentToken.HasEscape));
end;

function TJSParser.StartsAsyncModifier: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);
  const EndsMemberName = (NextToken.TokenType in [TJSTokenType.LeftParen, TJSTokenType.Colon, TJSTokenType.Comma,
                                                  TJSTokenType.RightBrace, TJSTokenType.Assign,
                                                  TJSTokenType.Semicolon]);
  Result := (not EndsMemberName) and (not NextToken.LineTerminatorBefore);
end;

function TJSParser.StartsAsyncFunction: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);
  Result := (NextToken.TokenType = TJSTokenType.KeywordFunction) and (not NextToken.LineTerminatorBefore);
end;

function TJSParser.StartsAsyncArrowFunction: Boolean;
begin
  if not IsAsyncWord then
    Exit(False);

  const NextToken = FLexer.PeekToken(1);
  if NextToken.LineTerminatorBefore then
    Exit(False);

  const IsSingleParameter = (NextToken.TokenType = TJSTokenType.Identifier);
  if IsSingleParameter then
  begin
    const ThirdToken = FLexer.PeekToken(2);
    Result := (ThirdToken.TokenType = TJSTokenType.Arrow);
    Exit;
  end;

  const StartsParameterList = (NextToken.TokenType = TJSTokenType.LeftParen);
  if not StartsParameterList then
    Exit(False);

  const ClosingOffset = FindClosingParenthesisOffset(1);
  const HasClosingParenthesis = (ClosingOffset >= 0);
  if not HasClosingParenthesis then
    Exit(False);

  const TokenAfterParameters = FLexer.PeekToken(ClosingOffset + 1);
  Result := (TokenAfterParameters.TokenType = TJSTokenType.Arrow);
end;

function TJSParser.SaveFunctionState: TJSFunctionState;
begin
  Result.Context := FContext;
  Result.InGenerator := FInGenerator;
  Result.YieldForbidden := FYieldForbidden;
  Result.InAsync := FInAsync;
  Result.AwaitForbidden := FAwaitForbidden;
end;

procedure TJSParser.RestoreFunctionState(const State: TJSFunctionState);
begin
  FContext := State.Context;
  FInGenerator := State.InGenerator;
  FYieldForbidden := State.YieldForbidden;
  FInAsync := State.InAsync;
  FAwaitForbidden := State.AwaitForbidden;
end;

procedure TJSParser.EnterFunction(const Context: TJSFunctionContext; const IsGenerator: Boolean;
                                  const IsAsync: Boolean);
begin
  FContext.AllowNewTarget := True;
  FContext.AllowSuperProperty := (Context <> TJSFunctionContext.Ordinary);
  FContext.AllowSuperCall := (Context = TJSFunctionContext.DerivedConstructor);

  FInGenerator := IsGenerator;
  FYieldForbidden := IsGenerator;
  FInAsync := IsAsync;
  FAwaitForbidden := IsAsync;
end;

procedure TJSParser.RaiseAtCurrentToken(const Message: string);
begin
  raise TJSErrorFactory.SyntaxError(Message, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.RejectAsyncGenerator(const IsGenerator: Boolean; const IsAsync: Boolean);
begin
  const IsAsyncGenerator = (IsGenerator and IsAsync);
  if IsAsyncGenerator then
    RaiseAtCurrentToken(ASYNC_GENERATOR_MESSAGE);
end;

function TJSParser.ParseFormalParameters(const Params: TObjectList<TJSIdentifier>): TJSParameterInfo;
begin
  Expect(TJSTokenType.LeftParen);

  const StartPosition = FLexer.Position;
  const Info = TJSParameterInfo.Create;
  try
    while not Check(TJSTokenType.RightParen) do
    begin
      if Check(TJSTokenType.Ellipsis) then
      begin
        ParseRestParameter(Info);
        Break;
      end;

      ParseFormalParameter(Params, Info);

      if not Check(TJSTokenType.RightParen) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightParen);

    const IsSimple = (not Info.HasDefaults) and (not Info.HasPatterns) and (not Assigned(Info.Rest));
    if IsSimple then
    begin
      Info.Free;
      Exit(nil);
    end;

    CollectBoundNames(Params, Info);
    RejectDuplicateNonSimpleParameters(Info);
    Info.ReferencesArguments := FLexer.HasIdentifierBetween(StartPosition, FLexer.Position,
                                                            [ARGUMENTS_NAME, EVAL_NAME]);
    Result := Info;
  except
    Info.Free;
    raise;
  end;
end;

procedure TJSParser.ParseFormalParameter(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
begin
  if IsPatternStart then
  begin
    const Pattern = ParseBindingTarget(TJSBindingKind.Parameter);
    Info.Patterns.Add(Pattern);
    Info.HasPatterns := True;

    const PlaceholderName = Format(PATTERN_PARAMETER_FORMAT, [Params.Count]);
    Params.Add(TJSIdentifier.Create(PlaceholderName));
  end
  else
  begin
    if not Check(TJSTokenType.Identifier) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    const ParamName = CurrentToken.Value;
    CheckStrictModeReservedWord(ParamName);
    Advance;

    Info.Patterns.Add(nil);
    Params.Add(TJSIdentifier.Create(ParamName));
  end;

  const HasDefault = Match(TJSTokenType.Assign);
  if not HasDefault then
  begin
    Info.Defaults.Add(nil);
    if not Info.HasDefaults then
      Info.ExpectedArgumentCount := Info.ExpectedArgumentCount + 1;
    Exit;
  end;

  Info.HasDefaults := True;
  Info.Defaults.Add(ParseNestedAssignmentExpression);
end;

procedure TJSParser.ParseRestParameter(const Info: TJSParameterInfo);
begin
  Expect(TJSTokenType.Ellipsis);

  if IsPatternStart then
  begin
    Info.RestPattern := ParseBindingTarget(TJSBindingKind.Parameter);
    Info.HasPatterns := True;
    Info.Rest := TJSIdentifier.Create(REST_PATTERN_NAME);
  end
  else
  begin
    if not Check(TJSTokenType.Identifier) then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    const ParamName = CurrentToken.Value;
    CheckStrictModeReservedWord(ParamName);
    Advance;

    Info.Rest := TJSIdentifier.Create(ParamName);
  end;

  const ClosesParameters = Check(TJSTokenType.RightParen);
  if not ClosesParameters then
    raise TJSErrorFactory.SyntaxError(REST_PARAMETER_NOT_LAST_MESSAGE, CurrentToken.Line, CurrentToken.Column);
end;

procedure TJSParser.CollectBoundNames(const Params: TObjectList<TJSIdentifier>; const Info: TJSParameterInfo);
begin
  const Names = TList<string>.Create;
  try
    for var Index := 0 to Params.Count - 1 do
    begin
      const Pattern = Info.Patterns[Index];
      if Assigned(Pattern) then
        TJSPatternNames.Collect(Pattern, Names)
      else
        Names.Add(Params[Index].Name);
    end;

    if Assigned(Info.RestPattern) then
      TJSPatternNames.Collect(Info.RestPattern, Names)
    else if Assigned(Info.Rest) then
      Names.Add(Info.Rest.Name);

    Info.BoundNames := Names.ToArray;
  finally
    Names.Free;
  end;
end;

procedure TJSParser.RejectDuplicateNonSimpleParameters(const Info: TJSParameterInfo);
begin
  const Names = Info.BoundNames;

  for var Index := 1 to Length(Names) - 1 do
  begin
    for var EarlierIndex := 0 to Index - 1 do
    begin
      const IsDuplicate = (Names[EarlierIndex] = Names[Index]);
      if IsDuplicate then
        raise TJSErrorFactory.SyntaxError(DUPLICATE_NON_SIMPLE_PARAMETER_MESSAGE, CurrentToken.Line, CurrentToken.Column);
    end;
  end;
end;

function TJSParser.StartsParameterExpression(const Offset: Integer): Boolean;
begin
  const TokenType = FLexer.PeekToken(Offset).TokenType;

  Result := (TokenType = TJSTokenType.Assign) or (TokenType = TJSTokenType.Ellipsis);
end;

function TJSParser.FindClosingParenthesisOffset(const StartOffset: Integer): Integer;
begin
  var Depth := 0;
  var Offset := StartOffset;

  while True do
  begin
    const TokenType = FLexer.PeekToken(Offset).TokenType;

    if TokenType = TJSTokenType.EndOfFile then
      Exit(-1);

    if TokenType in [TJSTokenType.LeftParen, TJSTokenType.LeftBracket, TJSTokenType.LeftBrace] then
      Inc(Depth)
    else if TokenType in [TJSTokenType.RightParen, TJSTokenType.RightBracket, TJSTokenType.RightBrace] then
      Dec(Depth);

    if Depth = 0 then
      Exit(Offset);

    Inc(Offset);
  end;
end;

function TJSParser.StartsArrowFunction: Boolean;
begin
  if Check(TJSTokenType.Identifier) then
  begin
    const NextToken = FLexer.PeekToken(1);
    Exit(NextToken.TokenType = TJSTokenType.Arrow);
  end;

  if not Check(TJSTokenType.LeftParen) then
    Exit(False);

  var Offset := 1;
  while FLexer.PeekToken(Offset).TokenType = TJSTokenType.Identifier do
  begin
    Inc(Offset);

    const HasParameterExpression = StartsParameterExpression(Offset);
    if HasParameterExpression then
      Exit(StartsArrowAfterParenthesis);

    const SeparatorToken = FLexer.PeekToken(Offset);
    const HasMoreParameters = (SeparatorToken.TokenType = TJSTokenType.Comma);
    if not HasMoreParameters then
      Break;

    Inc(Offset);
  end;

  const IsRestParameter = (FLexer.PeekToken(Offset).TokenType = TJSTokenType.Ellipsis);
  if IsRestParameter then
    Exit(StartsArrowAfterParenthesis);

  const IsPatternParameter = (FLexer.PeekToken(Offset).TokenType in [TJSTokenType.LeftBracket, TJSTokenType.LeftBrace]);
  if IsPatternParameter then
    Exit(StartsArrowAfterParenthesis);

  const ClosingToken = FLexer.PeekToken(Offset);
  const TokenAfterClosing = FLexer.PeekToken(Offset + 1);
  const ClosesParameters = (ClosingToken.TokenType = TJSTokenType.RightParen);
  Result := ClosesParameters and (TokenAfterClosing.TokenType = TJSTokenType.Arrow);
end;

function TJSParser.StartsArrowAfterParenthesis: Boolean;
begin
  const ClosingOffset = FindClosingParenthesisOffset;
  if ClosingOffset < 0 then
    Exit(False);

  Result := (FLexer.PeekToken(ClosingOffset + 1).TokenType = TJSTokenType.Arrow);
end;

function TJSParser.ParseArrowFunction(const IsAsync: Boolean): TJSFunctionExpression;
begin
  const SourceStart = CurrentToken.StartOffset;
  if IsAsync then
    Advance;

  Result := TJSFunctionExpression.Create;
  Result.IsArrow := True;
  Result.IsAsync := IsAsync;

  try
    ParseArrowParameters(Result);

    const HasLineBreakBeforeArrow = CurrentToken.LineTerminatorBefore;
    if HasLineBreakBeforeArrow then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    Expect(TJSTokenType.Arrow);
    Inc(FClosureCount);

    ParseArrowBody(Result);
    Result.SourceText := SourceTextFrom(SourceStart);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.ParseArrowParameters(const Func: TJSFunctionExpression);
begin
  const OuterState = SaveFunctionState;
  FInAsync := (FInAsync or Func.IsAsync);
  FAwaitForbidden := FInAsync;
  try
    const IsParenthesized = Check(TJSTokenType.LeftParen);
    if not IsParenthesized then
    begin
      ParseArrowParameter(Func);
      Exit;
    end;

    FYieldForbidden := FInGenerator;
    Func.ParameterInfo := ParseFormalParameters(Func.Params);
  finally
    RestoreFunctionState(OuterState);
  end;

  RejectDuplicateArrowParameters(Func.Params);
end;

procedure TJSParser.ParseArrowParameter(const Func: TJSFunctionExpression);
begin
  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const ParamName = CurrentToken.Value;
  CheckStrictModeReservedWord(ParamName);
  Advance;

  const Parameter = TJSIdentifier.Create(ParamName);
  Func.Params.Add(Parameter);
end;

procedure TJSParser.ParseArrowBody(const Func: TJSFunctionExpression);
begin
  const OldStrictMode = FStrictMode;
  const OuterState = SaveFunctionState;
  FInGenerator := False;
  FInAsync := Func.IsAsync;
  FAwaitForbidden := False;
  try
    const HasBlockBody = Check(TJSTokenType.LeftBrace);
    if HasBlockBody then
      ParseArrowBlockBody(Func)
    else
      ParseArrowConciseBody(Func);

    CheckStrictFunctionHeader('', Func.Params, Func.ParameterInfo);
  finally
    FStrictMode := OldStrictMode;
    RestoreFunctionState(OuterState);
  end;
end;

procedure TJSParser.ParseArrowBlockBody(const Func: TJSFunctionExpression);
begin
  const Body = ParseFunctionBodyBlock(Func.Params, Func.ParameterInfo);
  Func.Body := Body;
  MarkSuspendableBody(Body, NOT_A_GENERATOR, Func.IsAsync);

  if Body.DeclaresStrictMode then
  begin
    Func.IsStrict := True;
    FStrictMode := True;
  end;
end;

procedure TJSParser.ParseArrowConciseBody(const Func: TJSFunctionExpression);
begin
  const Body = ParseConciseBody;
  Body.ParameterInfo := Func.ParameterInfo;
  Func.Body := Body;
  MarkSuspendableBody(Body, NOT_A_GENERATOR, Func.IsAsync);
end;

function TJSParser.ParseConciseBody: TJSBlockStatement;
begin
  Result := TJSBlockStatement.Create;
  Result.IsFunctionBody := True;

  try
    const Argument = ParseAssignmentOperand;
    const ReturnStatement = TJSReturnStatement.Create(Argument);
    Result.Body.Add(ReturnStatement);
  except
    Result.Free;
    raise;
  end;
end;

procedure TJSParser.RejectDuplicateArrowParameters(const Params: TObjectList<TJSIdentifier>);
begin
  for var Index := 1 to Params.Count - 1 do
  begin
    for var EarlierIndex := 0 to Index - 1 do
    begin
      const IsDuplicate = (Params[EarlierIndex].Name = Params[Index].Name);
      if IsDuplicate then
        raise TJSErrorFactory.SyntaxError(DUPLICATE_ARROW_PARAMETER_MESSAGE, Params[Index].Line, Params[Index].Column);
    end;
  end;
end;

function TJSParser.ParseArguments(const Target: TObjectList<TJSExpression>): Boolean;
begin
  Expect(TJSTokenType.LeftParen);

  Result := False;

  if not Check(TJSTokenType.RightParen) then
  begin
    repeat
      const HasTrailingComma = Check(TJSTokenType.RightParen);
      if HasTrailingComma then
        Break;

      const Argument = ParseSpreadOrAssignmentExpression;
      Target.Add(Argument);
      Result := Result or (Argument is TJSSpreadElement);
    until not Match(TJSTokenType.Comma);
  end;

  Expect(TJSTokenType.RightParen);
end;

function TJSParser.ParseSpreadOrAssignmentExpression: TJSExpression;
begin
  const IsSpread = Match(TJSTokenType.Ellipsis);
  if not IsSpread then
    Exit(ParseNestedAssignmentExpression);

  Result := TJSSpreadElement.Create(ParseNestedAssignmentExpression);
end;

function TJSParser.IsPatternStart: Boolean;
begin
  Result := CheckAny([TJSTokenType.LeftBracket, TJSTokenType.LeftBrace]);
end;

procedure TJSParser.CheckBindingName(const Name: string; const Kind: TJSBindingKind);
begin
  if Kind = TJSBindingKind.Lexical then
  begin
    CheckLexicalBindingName(Name);
    Exit;
  end;

  CheckStrictModeReservedWord(Name);
  CheckRestrictedBindingName(Name);
end;

function TJSParser.ParseBindingIdentifier(const Kind: TJSBindingKind): TJSIdentifier;
begin
  if not Check(TJSTokenType.Identifier) then
    raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

  const Name = CurrentToken.Value;
  CheckBindingName(Name, Kind);
  Advance;

  Result := TJSIdentifier.Create(Name);
end;

function TJSParser.ParseBindingTarget(const Kind: TJSBindingKind): TJSExpression;
begin
  const IsArrayPattern = Check(TJSTokenType.LeftBracket);
  const IsPattern = (IsArrayPattern or Check(TJSTokenType.LeftBrace));
  if not IsPattern then
  begin
    Result := ParseBindingIdentifier(Kind);
    Exit;
  end;

  EnterNesting;
  try
    if IsArrayPattern then
      Result := ParseArrayBindingPattern(Kind)
    else
      Result := ParseObjectBindingPattern(Kind);
  finally
    LeaveNesting;
  end;
end;

function TJSParser.ParseBindingElement(const Kind: TJSBindingKind): TJSExpression;
begin
  const Target = ParseBindingTarget(Kind);
  if not Check(TJSTokenType.Assign) then
    Exit(Target);

  try
    Advance;
    const Default = ParseNestedAssignmentExpression;
    Result := TJSAssignmentPattern.Create(Target, Default);
  except
    Target.Free;
    raise;
  end;
end;

function TJSParser.ParseArrayBindingPattern(const Kind: TJSBindingKind): TJSArrayPattern;
begin
  Expect(TJSTokenType.LeftBracket);

  Result := TJSArrayPattern.Create;

  try
    while not Check(TJSTokenType.RightBracket) do
    begin
      if Check(TJSTokenType.Comma) then
      begin
        Result.Elements.Add(nil);
        Advance;
        Continue;
      end;

      if Match(TJSTokenType.Ellipsis) then
      begin
        const RestTarget = ParseBindingTarget(Kind);
        const RestElement = TJSSpreadElement.Create(RestTarget);
        Result.Elements.Add(RestElement);

        if not Check(TJSTokenType.RightBracket) then
          raise TJSErrorFactory.SyntaxError(REST_ELEMENT_LAST_MESSAGE, CurrentToken.Line, CurrentToken.Column);

        Break;
      end;

      const Element = ParseBindingElement(Kind);
      Result.Elements.Add(Element);

      if not Check(TJSTokenType.RightBracket) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBracket);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseObjectBindingPattern(const Kind: TJSBindingKind): TJSObjectPattern;
begin
  Expect(TJSTokenType.LeftBrace);

  Result := TJSObjectPattern.Create;

  try
    while not Check(TJSTokenType.RightBrace) do
    begin
      if Match(TJSTokenType.Ellipsis) then
      begin
        Result.Rest := ParseBindingIdentifier(Kind);

        if not Check(TJSTokenType.RightBrace) then
          raise TJSErrorFactory.SyntaxError(REST_ELEMENT_LAST_MESSAGE, CurrentToken.Line, CurrentToken.Column);

        Break;
      end;

      const Member = ParseBindingProperty(Kind);
      Result.Properties.Add(Member);

      if not Check(TJSTokenType.RightBrace) then
        Expect(TJSTokenType.Comma);
    end;

    Expect(TJSTokenType.RightBrace);
  except
    Result.Free;
    raise;
  end;
end;

function TJSParser.ParseBindingProperty(const Kind: TJSBindingKind): TJSObjectProperty;
begin
  const KeyIsIdentifier = Check(TJSTokenType.Identifier);
  const KeyText = CurrentToken.Value;

  var Computed: Boolean;
  const Key = ParsePropertyKey(Computed);
  try
    if Match(TJSTokenType.Colon) then
    begin
      const Value = ParseBindingElement(Kind);
      Result := TJSObjectProperty.Create(Key, Value, Computed);
      Exit;
    end;

    const IsShorthand = KeyIsIdentifier and (not Computed);
    if not IsShorthand then
      raise TJSErrorFactory.UnexpectedToken(CurrentToken.Value, CurrentToken.Line, CurrentToken.Column);

    CheckBindingName(KeyText, Kind);

    var Value: TJSExpression := TJSIdentifier.Create(KeyText);
    if Match(TJSTokenType.Assign) then
    begin
      try
        const Default = ParseNestedAssignmentExpression;
        Value := TJSAssignmentPattern.Create(Value, Default);
      except
        Value.Free;
        raise;
      end;
    end;

    Result := TJSObjectProperty.Create(Key, Value, False, TJSPropertyKind.Shorthand);
  except
    Key.Free;
    raise;
  end;
end;

function TJSParser.ConvertToAssignmentPattern(const Node: TJSExpression): TJSExpression;
begin
  try
    ValidateDestructuringTarget(Node);
  except
    Node.Free;
    raise;
  end;

  Result := BuildDestructuringTarget(Node);
end;

procedure TJSParser.ValidateDestructuringTarget(const Node: TJSExpression);
begin
  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      begin
        if Node.IsParenthesized then
          raise TJSErrorFactory.SyntaxError(INVALID_DESTRUCTURING_TARGET_MESSAGE, CurrentToken.Line, CurrentToken.Column);

        ValidateArrayPattern(TJSArrayExpression(Node));
      end;
    TJSASTNodeType.ObjectExpression:
      begin
        if Node.IsParenthesized then
          raise TJSErrorFactory.SyntaxError(INVALID_DESTRUCTURING_TARGET_MESSAGE, CurrentToken.Line, CurrentToken.Column);

        ValidateObjectPattern(TJSObjectExpression(Node));
      end;
    TJSASTNodeType.ArrayPattern,
    TJSASTNodeType.ObjectPattern,
    TJSASTNodeType.MemberExpression:
      Exit;
    TJSASTNodeType.Identifier:
      begin
        const IsRestricted = IsRestrictedStrictName(TJSIdentifier(Node).Name);
        if IsRestricted then
          raise TJSErrorFactory.SyntaxError(INVALID_DESTRUCTURING_TARGET_MESSAGE, CurrentToken.Line, CurrentToken.Column);
      end;
  else
    raise TJSErrorFactory.SyntaxError(INVALID_DESTRUCTURING_TARGET_MESSAGE, CurrentToken.Line, CurrentToken.Column);
  end;
end;

procedure TJSParser.ValidateDestructuringElement(const Node: TJSExpression);
begin
  const IsDefaultedTarget = (Node.NodeType = TJSASTNodeType.AssignmentExpression) and
                            (TJSAssignmentExpression(Node).Operator = TJSAssignmentOperator.Assign) and
                            (not Node.IsParenthesized);
  if IsDefaultedTarget then
    ValidateDestructuringTarget(TJSAssignmentExpression(Node).Left)
  else
    ValidateDestructuringTarget(Node);
end;

procedure TJSParser.ValidateArrayPattern(const Source: TJSArrayExpression);
begin
  for var Element in Source.Elements do
  begin
    if Element = nil then
      Continue;

    if Element is TJSSpreadElement then
    begin
      if Source.SpreadFollowedByComma then
        raise TJSErrorFactory.SyntaxError(REST_ELEMENT_LAST_MESSAGE, CurrentToken.Line, CurrentToken.Column);

      ValidateDestructuringTarget(TJSSpreadElement(Element).Argument);
    end
    else
    begin
      ValidateDestructuringElement(Element);
    end;
  end;
end;

procedure TJSParser.ValidateObjectPattern(const Source: TJSObjectExpression);
begin
  for var Prop in Source.Properties do
  begin
    case Prop.Kind of
      TJSPropertyKind.Data:
        ValidateDestructuringElement(Prop.Value);
      TJSPropertyKind.Spread:
        begin
          const IsLiteralTarget = (Prop.Value is TJSArrayExpression) or (Prop.Value is TJSObjectExpression);
          if Source.SpreadFollowedByComma or IsLiteralTarget then
            raise TJSErrorFactory.SyntaxError(REST_ELEMENT_LAST_MESSAGE, CurrentToken.Line, CurrentToken.Column);

          ValidateDestructuringTarget(Prop.Value);
        end;
      TJSPropertyKind.Shorthand:
        begin
          const IsCoverInitializer = (Prop.Value is TJSAssignmentPattern);
          if IsCoverInitializer then
            ValidateDestructuringTarget(TJSAssignmentPattern(Prop.Value).Target)
          else
            ValidateDestructuringTarget(Prop.Value);
        end;
    else
      raise TJSErrorFactory.SyntaxError(INVALID_DESTRUCTURING_TARGET_MESSAGE, CurrentToken.Line, CurrentToken.Column);
    end;
  end;
end;

function TJSParser.BuildDestructuringTarget(const Node: TJSExpression): TJSExpression;
begin
  case Node.NodeType of
    TJSASTNodeType.ArrayExpression:
      Result := BuildArrayPattern(TJSArrayExpression(Node));
    TJSASTNodeType.ObjectExpression:
      Result := BuildObjectPattern(TJSObjectExpression(Node));
  else
    Result := Node;
  end;
end;

function TJSParser.BuildDestructuringElement(const Node: TJSExpression): TJSExpression;
begin
  const IsDefaultedTarget = (Node.NodeType = TJSASTNodeType.AssignmentExpression) and
                            (TJSAssignmentExpression(Node).Operator = TJSAssignmentOperator.Assign) and
                            (not Node.IsParenthesized);
  if not IsDefaultedTarget then
    Exit(BuildDestructuringTarget(Node));

  const Assignment = TJSAssignmentExpression(Node);
  const Target = Assignment.TakeLeft;
  const Default = Assignment.TakeRight;
  Assignment.Free;

  Result := TJSAssignmentPattern.Create(Target, Default);
end;

function TJSParser.BuildArrayPattern(const Source: TJSArrayExpression): TJSArrayPattern;
begin
  Result := TJSArrayPattern.Create;
  Result.Line := Source.Line;
  Result.Column := Source.Column;

  Source.Elements.OwnsObjects := False;

  for var Element in Source.Elements do
  begin
    if Element = nil then
    begin
      Result.Elements.Add(nil);
    end
    else if Element is TJSSpreadElement then
    begin
      const Rest = TJSSpreadElement(Element);
      Rest.Argument := BuildDestructuringTarget(Rest.Argument);
      Result.Elements.Add(Rest);
    end
    else
    begin
      const Built = BuildDestructuringElement(Element);
      Result.Elements.Add(Built);
    end;
  end;

  Source.Elements.Clear;
  Source.Free;
end;

function TJSParser.BuildObjectPattern(const Source: TJSObjectExpression): TJSObjectPattern;
begin
  Result := TJSObjectPattern.Create;
  Result.Line := Source.Line;
  Result.Column := Source.Column;

  Source.Properties.OwnsObjects := False;

  if Source.HasDuplicatePrototype then
    Dec(FCoverInitializerCount);

  for var Prop in Source.Properties do
  begin
    if Prop.Kind = TJSPropertyKind.Spread then
    begin
      Result.Rest := Prop.Value;
      Prop.Value := nil;
      Prop.Free;
      Continue;
    end;

    const IsCoverInitializer = (Prop.Value is TJSAssignmentPattern);
    if IsCoverInitializer then
      Dec(FCoverInitializerCount)
    else
      Prop.Value := BuildDestructuringElement(Prop.Value);

    Result.Properties.Add(Prop);
  end;

  Source.Properties.Clear;
  Source.Free;
end;

function TJSParser.IsAssignmentOperator(const TokenType: TJSTokenType): Boolean;
begin
  Result := TokenType in [
    TJSTokenType.Assign,
    TJSTokenType.PlusAssign,
    TJSTokenType.MinusAssign,
    TJSTokenType.MultiplyAssign,
    TJSTokenType.DivideAssign,
    TJSTokenType.ModuloAssign,
    TJSTokenType.ExponentAssign,
    TJSTokenType.BitwiseAndAssign,
    TJSTokenType.BitwiseOrAssign,
    TJSTokenType.BitwiseXorAssign,
    TJSTokenType.LeftShiftAssign,
    TJSTokenType.RightShiftAssign,
    TJSTokenType.UnsignedRightShiftAssign
  ];
end;

function TJSParser.IsRelationalOperator: Boolean;
begin
  const IsInKeyword = Check(TJSTokenType.KeywordIn);
  if IsInKeyword then
    Exit(FInOperatorAllowed);

  Result := CheckAny([TJSTokenType.LessThan, TJSTokenType.GreaterThan, TJSTokenType.LessThanOrEqual,
                      TJSTokenType.GreaterThanOrEqual, TJSTokenType.KeywordInstanceof]);
end;

function TJSParser.IsValidAssignmentTarget(const Target: TJSExpression): Boolean;
begin
  if Target is TJSTaggedTemplateExpression then
    Exit(False);

  const IsCall = (Target.NodeType = TJSASTNodeType.CallExpression);
  if IsCall then
    Exit(not FStrictMode);

  const IsIdentifier = (Target.NodeType = TJSASTNodeType.Identifier);
  if IsIdentifier then
  begin
    const IdentifierName = TJSIdentifier(Target).Name;
    Exit(not IsRestrictedStrictName(IdentifierName));
  end;

  Result := (Target.NodeType = TJSASTNodeType.MemberExpression);
end;

procedure TJSParser.EnsureAssignmentTarget(const Target: TJSExpression);
begin
  if IsValidAssignmentTarget(Target) then
    Exit;

  Target.Free;
  raise TJSErrorFactory.SyntaxError('Invalid left-hand side in assignment', CurrentToken.Line, CurrentToken.Column);
end;

function TJSParser.TokenToAssignmentOperator(const TokenType: TJSTokenType): TJSAssignmentOperator;
begin
  case TokenType of
    TJSTokenType.Assign:
      Result := TJSAssignmentOperator.Assign;
    TJSTokenType.PlusAssign:
      Result := TJSAssignmentOperator.AddAssign;
    TJSTokenType.MinusAssign:
      Result := TJSAssignmentOperator.SubtractAssign;
    TJSTokenType.MultiplyAssign:
      Result := TJSAssignmentOperator.MultiplyAssign;
    TJSTokenType.DivideAssign:
      Result := TJSAssignmentOperator.DivideAssign;
    TJSTokenType.ModuloAssign:
      Result := TJSAssignmentOperator.ModuloAssign;
    TJSTokenType.ExponentAssign:
      Result := TJSAssignmentOperator.ExponentAssign;
    TJSTokenType.BitwiseAndAssign:
      Result := TJSAssignmentOperator.BitwiseAndAssign;
    TJSTokenType.BitwiseOrAssign:
      Result := TJSAssignmentOperator.BitwiseOrAssign;
    TJSTokenType.BitwiseXorAssign:
      Result := TJSAssignmentOperator.BitwiseXorAssign;
    TJSTokenType.LeftShiftAssign:
      Result := TJSAssignmentOperator.LeftShiftAssign;
    TJSTokenType.RightShiftAssign:
      Result := TJSAssignmentOperator.RightShiftAssign;
    TJSTokenType.UnsignedRightShiftAssign:
      Result := TJSAssignmentOperator.UnsignedRightShiftAssign;
    else
      Result := TJSAssignmentOperator.Assign;
  end;
end;

function TJSParser.IsStrictModeReservedWord(const Name: string): Boolean;
begin
  Result := MatchStr(Name, STRICT_RESERVED_WORDS);
end;

procedure TJSParser.CheckStrictModeReservedWord(const Name: string);
begin
  if FStrictMode and IsStrictModeReservedWord(Name) then
    RaiseAtCurrentToken(Format(STRICT_RESERVED_WORD_MESSAGE, [Name]));

  const IsYieldInGenerator = (FInGenerator and (Name = YIELD_NAME));
  if IsYieldInGenerator then
    RaiseAtCurrentToken(YIELD_IDENTIFIER_MESSAGE);

  const IsAwaitInAsync = (FInAsync and (Name = AWAIT_NAME));
  if IsAwaitInAsync then
    RaiseAtCurrentToken(AWAIT_IDENTIFIER_MESSAGE);
end;

function TJSParser.IsRestrictedStrictName(const Name: string): Boolean;
begin
  const IsEvalOrArguments = (Name = EVAL_NAME) or (Name = ARGUMENTS_NAME);
  Result := FStrictMode and IsEvalOrArguments;
end;

procedure TJSParser.CheckRestrictedBindingName(const Name: string);
begin
  if IsRestrictedStrictName(Name) then
  begin
    const Message = Format(RESTRICTED_BINDING_NAME_MESSAGE, [Name]);
    raise TJSErrorFactory.SyntaxError(Message, CurrentToken.Line, CurrentToken.Column);
  end;
end;

procedure TJSParser.CheckStrictFunctionHeader(const FuncName: string; const Params: TObjectList<TJSIdentifier>;
                                              const ParameterInfo: TJSParameterInfo);
begin
  if not FStrictMode then
    Exit;

  CheckStrictModeReservedWord(FuncName);
  CheckRestrictedBindingName(FuncName);

  for var Param in Params do
  begin
    CheckStrictModeReservedWord(Param.Name);
  end;

  const HasRest = Assigned(ParameterInfo) and Assigned(ParameterInfo.Rest);
  if HasRest then
  begin
    CheckRestrictedBindingName(ParameterInfo.Rest.Name);
  end;

  CheckDuplicateParameters(Params);
  CheckRestrictedParameterNames(Params);
end;

procedure TJSParser.CheckDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  if FStrictMode then
    RejectDuplicateParameters(Params);
end;

procedure TJSParser.RejectDuplicateParameters(const Params: TObjectList<TJSIdentifier>);
begin
  var ParamNames: TArray<string>;
  SetLength(ParamNames, Params.Count);

  for var I := 0 to Params.Count - 1 do
  begin
    const ParamName = Params[I].Name;

    for var J := 0 to I - 1 do
    begin
      if ParamNames[J] = ParamName then
        raise TJSErrorFactory.SyntaxError('Duplicate parameter name not allowed in strict mode',
          Params[I].Line, Params[I].Column);
    end;

    ParamNames[I] := ParamName;
  end;
end;

procedure TJSParser.CheckRestrictedParameterNames(const Params: TObjectList<TJSIdentifier>);
begin
  if not FStrictMode then
    Exit;

  for var Param in Params do
  begin
    const IsRestricted = (Param.Name = EVAL_NAME) or (Param.Name = ARGUMENTS_NAME);
    if IsRestricted then
    begin
      const Message = Format(RESTRICTED_PARAMETER_NAME_MESSAGE, [Param.Name]);
      raise TJSErrorFactory.SyntaxError(Message, Param.Line, Param.Column);
    end;
  end;
end;

end.
