unit JS4D.BuiltinAttributes;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter;

type
  TJSBuiltinAttributes = class
  private
    type
      TBuiltinOwner = (
        Global, ObjectConstructor, ObjectPrototype,
        FunctionConstructor, FunctionPrototype, ArrayConstructor,
        ArrayPrototype, StringConstructor, StringPrototype,
        NumberConstructor, NumberPrototype, BooleanConstructor,
        BooleanPrototype, MathObject, JsonObject,
        DateConstructor, DatePrototype, RegExpConstructor,
        RegExpPrototype, ErrorConstructor, ErrorPrototype,
        EvalErrorConstructor, EvalErrorPrototype, RangeErrorConstructor,
        RangeErrorPrototype, ReferenceErrorConstructor, ReferenceErrorPrototype,
        SyntaxErrorConstructor, SyntaxErrorPrototype, TypeErrorConstructor,
        TypeErrorPrototype, URIErrorConstructor, URIErrorPrototype);

      TMemberArity = record
        Owner: TBuiltinOwner;
        Name: string;
        Arity: Integer;
      end;

    const
      PATH_SEPARATOR = '.';
      OWNER_PATHS: array[TBuiltinOwner] of string = (
        '',
        'Object',
        'Object.prototype',
        'Function',
        'Function.prototype',
        'Array',
        'Array.prototype',
        'String',
        'String.prototype',
        'Number',
        'Number.prototype',
        'Boolean',
        'Boolean.prototype',
        'Math',
        'JSON',
        'Date',
        'Date.prototype',
        'RegExp',
        'RegExp.prototype',
        'Error',
        'Error.prototype',
        'EvalError',
        'EvalError.prototype',
        'RangeError',
        'RangeError.prototype',
        'ReferenceError',
        'ReferenceError.prototype',
        'SyntaxError',
        'SyntaxError.prototype',
        'TypeError',
        'TypeError.prototype',
        'URIError',
        'URIError.prototype');
      MEMBER_ARITIES: array[0..196] of TMemberArity = (
        (Owner: TBuiltinOwner.Global; Name: 'Object'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'Function'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'Array'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'String'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'Number'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'Boolean'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'Date'; Arity: 7),
        (Owner: TBuiltinOwner.Global; Name: 'RegExp'; Arity: 2),
        (Owner: TBuiltinOwner.Global; Name: 'Error'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'EvalError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'RangeError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'ReferenceError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'SyntaxError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'TypeError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'URIError'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'eval'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'parseInt'; Arity: 2),
        (Owner: TBuiltinOwner.Global; Name: 'parseFloat'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'isNaN'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'isFinite'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'decodeURI'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'decodeURIComponent'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'encodeURI'; Arity: 1),
        (Owner: TBuiltinOwner.Global; Name: 'encodeURIComponent'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'getPrototypeOf'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'getOwnPropertyDescriptor'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'getOwnPropertyNames'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'getOwnPropertySymbols'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'create'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'defineProperty'; Arity: 3),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'defineProperties'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'seal'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'freeze'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'preventExtensions'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'isSealed'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'isFrozen'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'isExtensible'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'keys'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'assign'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'entries'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'values'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'is'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'getOwnPropertyDescriptors'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'hasOwn'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'setPrototypeOf'; Arity: 2),
        (Owner: TBuiltinOwner.ObjectConstructor; Name: 'fromEntries'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'toLocaleString'; Arity: 0),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'valueOf'; Arity: 0),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'hasOwnProperty'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'isPrototypeOf'; Arity: 1),
        (Owner: TBuiltinOwner.ObjectPrototype; Name: 'propertyIsEnumerable'; Arity: 1),
        (Owner: TBuiltinOwner.FunctionPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.FunctionPrototype; Name: 'apply'; Arity: 2),
        (Owner: TBuiltinOwner.FunctionPrototype; Name: 'call'; Arity: 1),
        (Owner: TBuiltinOwner.FunctionPrototype; Name: 'bind'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayConstructor; Name: 'isArray'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayConstructor; Name: 'of'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayConstructor; Name: 'from'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'toLocaleString'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'concat'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'join'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'pop'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'push'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'reverse'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'shift'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'slice'; Arity: 2),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'sort'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'splice'; Arity: 2),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'unshift'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'indexOf'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'lastIndexOf'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'every'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'some'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'forEach'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'map'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'filter'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'reduce'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'reduceRight'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'find'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'findIndex'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'fill'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'copyWithin'; Arity: 2),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'includes'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'keys'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'values'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'entries'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'flat'; Arity: 0),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'flatMap'; Arity: 1),
        (Owner: TBuiltinOwner.ArrayPrototype; Name: 'at'; Arity: 1),
        (Owner: TBuiltinOwner.StringConstructor; Name: 'fromCharCode'; Arity: 1),
        (Owner: TBuiltinOwner.StringConstructor; Name: 'fromCodePoint'; Arity: 1),
        (Owner: TBuiltinOwner.StringConstructor; Name: 'raw'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'valueOf'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'charAt'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'charCodeAt'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'concat'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'indexOf'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'lastIndexOf'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'localeCompare'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'match'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'replace'; Arity: 2),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'search'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'slice'; Arity: 2),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'split'; Arity: 2),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'substring'; Arity: 2),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'toLowerCase'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'toLocaleLowerCase'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'toUpperCase'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'toLocaleUpperCase'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'trim'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'substr'; Arity: 2),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'startsWith'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'endsWith'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'includes'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'repeat'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'padStart'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'padEnd'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'trimStart'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'trimEnd'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'trimLeft'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'trimRight'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'codePointAt'; Arity: 1),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'normalize'; Arity: 0),
        (Owner: TBuiltinOwner.StringPrototype; Name: 'at'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'isFinite'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'isInteger'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'isNaN'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'isSafeInteger'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'parseFloat'; Arity: 1),
        (Owner: TBuiltinOwner.NumberConstructor; Name: 'parseInt'; Arity: 2),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'toString'; Arity: 1),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'toLocaleString'; Arity: 0),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'valueOf'; Arity: 0),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'toFixed'; Arity: 1),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'toExponential'; Arity: 1),
        (Owner: TBuiltinOwner.NumberPrototype; Name: 'toPrecision'; Arity: 1),
        (Owner: TBuiltinOwner.BooleanPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.BooleanPrototype; Name: 'valueOf'; Arity: 0),
        (Owner: TBuiltinOwner.JsonObject; Name: 'parse'; Arity: 2),
        (Owner: TBuiltinOwner.JsonObject; Name: 'stringify'; Arity: 3),
        (Owner: TBuiltinOwner.DateConstructor; Name: 'parse'; Arity: 1),
        (Owner: TBuiltinOwner.DateConstructor; Name: 'UTC'; Arity: 7),
        (Owner: TBuiltinOwner.DateConstructor; Name: 'now'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toDateString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toTimeString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toLocaleString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toLocaleDateString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toLocaleTimeString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'valueOf'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getTime'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getFullYear'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCFullYear'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getMonth'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCMonth'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getDate'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCDate'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getDay'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCDay'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getHours'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCHours'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getMinutes'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCMinutes'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getSeconds'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCSeconds'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getMilliseconds'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getUTCMilliseconds'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getTimezoneOffset'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setTime'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setMilliseconds'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCMilliseconds'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setSeconds'; Arity: 2),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCSeconds'; Arity: 2),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setMinutes'; Arity: 3),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCMinutes'; Arity: 3),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setHours'; Arity: 4),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCHours'; Arity: 4),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setDate'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCDate'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setMonth'; Arity: 2),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCMonth'; Arity: 2),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setFullYear'; Arity: 3),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setUTCFullYear'; Arity: 3),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toUTCString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toISOString'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toJSON'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'getYear'; Arity: 0),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'setYear'; Arity: 1),
        (Owner: TBuiltinOwner.DatePrototype; Name: 'toGMTString'; Arity: 0),
        (Owner: TBuiltinOwner.RegExpPrototype; Name: 'exec'; Arity: 1),
        (Owner: TBuiltinOwner.RegExpPrototype; Name: 'test'; Arity: 1),
        (Owner: TBuiltinOwner.RegExpPrototype; Name: 'toString'; Arity: 0),
        (Owner: TBuiltinOwner.RegExpPrototype; Name: 'compile'; Arity: 2),
        (Owner: TBuiltinOwner.ErrorPrototype; Name: 'toString'; Arity: 0));

    var
      FInterpreter: TJSInterpreter;

    function ResolveOwner(const Owner: TBuiltinOwner): IJSObject;
    function ResolveMember(const Target: IJSObject; const Name: string): TJSValue;
    function ApplyOwner(const Owner: TBuiltinOwner; const FirstRow: Integer): Integer;
    procedure DefineMethodLength(const Member: TMemberArity; const Target: IJSObject);
    procedure HideProperties(const Target: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Apply;
  end;

implementation

uses
  JS4D.PropertyNames;

constructor TJSBuiltinAttributes.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
end;

procedure TJSBuiltinAttributes.Apply;
begin
  var FirstRow := 0;
  for var Owner := Low(TBuiltinOwner) to High(TBuiltinOwner) do
  begin
    FirstRow := ApplyOwner(Owner, FirstRow);
  end;
end;

function TJSBuiltinAttributes.ApplyOwner(const Owner: TBuiltinOwner; const FirstRow: Integer): Integer;
begin
  const IsGlobal = (Owner = TBuiltinOwner.Global);
  const Target = ResolveOwner(Owner);
  const IsMissing = (not IsGlobal) and (not Assigned(Target));

  Result := FirstRow;
  while (Result < Length(MEMBER_ARITIES)) and (MEMBER_ARITIES[Result].Owner = Owner) do
  begin
    if not IsMissing then
      DefineMethodLength(MEMBER_ARITIES[Result], Target);

    Inc(Result);
  end;

  if not (IsGlobal or IsMissing) then
    HideProperties(Target);
end;

function TJSBuiltinAttributes.ResolveOwner(const Owner: TBuiltinOwner): IJSObject;
begin
  Result := nil;

  const IsGlobal = (Owner = TBuiltinOwner.Global);
  if IsGlobal then
    Exit;

  const Segments = OWNER_PATHS[Owner].Split([PATH_SEPARATOR]);
  const Root = FInterpreter.GetGlobalVariable(Segments[0]);
  if not Root.IsObject then
    Exit;

  Result := Root.ToObject;
  for var Index := 1 to High(Segments) do
  begin
    const Child = Result.GetProperty(Segments[Index]);
    Result := Child.ToObject;
  end;
end;

function TJSBuiltinAttributes.ResolveMember(const Target: IJSObject; const Name: string): TJSValue;
begin
  if Assigned(Target) then
  begin
    Result := Target.GetProperty(Name);
    Exit;
  end;

  Result := FInterpreter.GetGlobalVariable(Name);
end;

procedure TJSBuiltinAttributes.DefineMethodLength(const Member: TMemberArity; const Target: IJSObject);
begin
  const Value = ResolveMember(Target, Member.Name);
  if not Value.IsFunction then
    Exit;

  TJSFunction.DefineLength(Value.ToObject, Member.Arity);

  var Method: IJSFunction;
  if not Value.TryGetFunction(Method) then
    Exit;

  const IsMethod = (Assigned(Target) or (not Method.HasOwnProperty(PROTOTYPE_PROPERTY)));
  if IsMethod then
    Method.IsConstructor := False;
end;

procedure TJSBuiltinAttributes.HideProperties(const Target: IJSObject);
begin
  for var Name in Target.GetOwnPropertyNames do
  begin
    var Descriptor := Target.GetOwnPropertyDescriptor(Name);
    if not Descriptor.Enumerable then
      Continue;

    Descriptor.Enumerable := False;
    Target.DefineProperty(Name, Descriptor);
  end;
end;

end.
