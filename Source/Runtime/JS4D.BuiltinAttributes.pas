unit JS4D.BuiltinAttributes;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.PropertyKey,
  JS4D.Types,
  JS4D.Interpreter;

type
  TJSArityTable = record
    Owner: string;
    Entries: string;
  end;

  TJSBuiltinAttributes = class
  private
    const
      PATH_SEPARATOR = '.';
      ENTRY_SEPARATOR = ' ';
      ARITY_SEPARATOR = ':';
      GLOBAL_OWNER = '';
      PROTOTYPE_PROPERTY = 'prototype';
      ARITY_TABLES: array[0..32] of TJSArityTable = (
        (Owner: GLOBAL_OWNER;
         Entries: 'Object:1 Function:1 Array:1 String:1 Number:1 Boolean:1 Date:7 RegExp:2 Error:1 ' +
                  'EvalError:1 RangeError:1 ReferenceError:1 SyntaxError:1 TypeError:1 URIError:1 ' +
                  'eval:1 parseInt:2 parseFloat:1 isNaN:1 isFinite:1 decodeURI:1 decodeURIComponent:1 ' +
                  'encodeURI:1 encodeURIComponent:1'),
        (Owner: 'Object';
         Entries: 'getPrototypeOf:1 getOwnPropertyDescriptor:2 getOwnPropertyNames:1 getOwnPropertySymbols:1 ' +
                  'create:2 defineProperty:3 ' +
                  'defineProperties:2 seal:1 freeze:1 preventExtensions:1 isSealed:1 isFrozen:1 isExtensible:1 ' +
                  'keys:1 assign:2 entries:1 values:1 is:2 getOwnPropertyDescriptors:1 hasOwn:2 setPrototypeOf:2 fromEntries:1'),
        (Owner: 'Object.prototype';
         Entries: 'toString:0 toLocaleString:0 valueOf:0 hasOwnProperty:1 isPrototypeOf:1 propertyIsEnumerable:1'),
        (Owner: 'Function';
         Entries: ''),
        (Owner: 'Function.prototype';
         Entries: 'toString:0 apply:2 call:1 bind:1'),
        (Owner: 'Array';
         Entries: 'isArray:1 of:0 from:1'),
        (Owner: 'Array.prototype';
         Entries: 'toString:0 toLocaleString:0 concat:1 join:1 pop:0 push:1 reverse:0 shift:0 slice:2 sort:1 ' +
                  'splice:2 unshift:1 indexOf:1 lastIndexOf:1 every:1 some:1 forEach:1 map:1 filter:1 reduce:1 ' +
                  'reduceRight:1 find:1 findIndex:1 fill:1 copyWithin:2 includes:1 keys:0 values:0 entries:0 ' +
                  'flat:0 flatMap:1 at:1'),
        (Owner: 'String';
         Entries: 'fromCharCode:1 fromCodePoint:1 raw:1'),
        (Owner: 'String.prototype';
         Entries: 'toString:0 valueOf:0 charAt:1 charCodeAt:1 concat:1 indexOf:1 lastIndexOf:1 localeCompare:1 ' +
                  'match:1 replace:2 search:1 slice:2 split:2 substring:2 toLowerCase:0 toLocaleLowerCase:0 ' +
                  'toUpperCase:0 toLocaleUpperCase:0 trim:0 substr:2 startsWith:1 endsWith:1 includes:1 repeat:1 ' +
                  'padStart:1 padEnd:1 trimStart:0 trimEnd:0 trimLeft:0 trimRight:0 codePointAt:1 normalize:0 at:1'),
        (Owner: 'Number';
         Entries: 'isFinite:1 isInteger:1 isNaN:1 isSafeInteger:1 parseFloat:1 parseInt:2'),
        (Owner: 'Number.prototype';
         Entries: 'toString:1 toLocaleString:0 valueOf:0 toFixed:1 toExponential:1 toPrecision:1'),
        (Owner: 'Boolean';
         Entries: ''),
        (Owner: 'Boolean.prototype';
         Entries: 'toString:0 valueOf:0'),
        (Owner: 'Math';
         Entries: 'abs:1 acos:1 asin:1 atan:1 atan2:2 ceil:1 cos:1 exp:1 floor:1 log:1 max:2 min:2 pow:2 ' +
                  'random:0 round:1 sin:1 sqrt:1 tan:1 trunc:1 sign:1 cbrt:1 log2:1 log10:1 log1p:1 expm1:1 ' +
                  'sinh:1 cosh:1 tanh:1 asinh:1 acosh:1 atanh:1 hypot:2 fround:1 imul:2 clz32:1'),
        (Owner: 'JSON';
         Entries: 'parse:2 stringify:3'),
        (Owner: 'Date';
         Entries: 'parse:1 UTC:7 now:0'),
        (Owner: 'Date.prototype';
         Entries: 'toString:0 toDateString:0 toTimeString:0 toLocaleString:0 toLocaleDateString:0 ' +
                  'toLocaleTimeString:0 valueOf:0 getTime:0 getFullYear:0 getUTCFullYear:0 getMonth:0 ' +
                  'getUTCMonth:0 getDate:0 getUTCDate:0 getDay:0 getUTCDay:0 getHours:0 getUTCHours:0 ' +
                  'getMinutes:0 getUTCMinutes:0 getSeconds:0 getUTCSeconds:0 getMilliseconds:0 ' +
                  'getUTCMilliseconds:0 getTimezoneOffset:0 setTime:1 setMilliseconds:1 setUTCMilliseconds:1 ' +
                  'setSeconds:2 setUTCSeconds:2 setMinutes:3 setUTCMinutes:3 setHours:4 setUTCHours:4 ' +
                  'setDate:1 setUTCDate:1 setMonth:2 setUTCMonth:2 setFullYear:3 setUTCFullYear:3 ' +
                  'toUTCString:0 toISOString:0 toJSON:1 getYear:0 setYear:1 toGMTString:0'),
        (Owner: 'RegExp';
         Entries: ''),
        (Owner: 'RegExp.prototype';
         Entries: 'exec:1 test:1 toString:0 compile:2'),
        (Owner: 'Error';
         Entries: ''),
        (Owner: 'Error.prototype';
         Entries: 'toString:0'),
        (Owner: 'EvalError';
         Entries: ''),
        (Owner: 'EvalError.prototype';
         Entries: ''),
        (Owner: 'RangeError';
         Entries: ''),
        (Owner: 'RangeError.prototype';
         Entries: ''),
        (Owner: 'ReferenceError';
         Entries: ''),
        (Owner: 'ReferenceError.prototype';
         Entries: ''),
        (Owner: 'SyntaxError';
         Entries: ''),
        (Owner: 'SyntaxError.prototype';
         Entries: ''),
        (Owner: 'TypeError';
         Entries: ''),
        (Owner: 'TypeError.prototype';
         Entries: ''),
        (Owner: 'URIError';
         Entries: ''),
        (Owner: 'URIError.prototype';
         Entries: '')
      );

    var
      FInterpreter: TJSInterpreter;

    function ResolveOwner(const Path: string): IJSObject;
    function ResolveMember(const Target: IJSObject; const Name: string): TJSValue;
    procedure ApplyTable(const Table: TJSArityTable);
    procedure DefineMethodLengths(const Table: TJSArityTable; const Target: IJSObject);
    procedure HideProperties(const Target: IJSObject);

  public
    constructor Create(const Interpreter: TJSInterpreter);

    procedure Apply;
  end;

implementation

constructor TJSBuiltinAttributes.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;
  FInterpreter := Interpreter;
end;

procedure TJSBuiltinAttributes.Apply;
begin
  for var Table in ARITY_TABLES do
  begin
    ApplyTable(Table);
  end;
end;

procedure TJSBuiltinAttributes.ApplyTable(const Table: TJSArityTable);
begin
  const IsGlobalTable = (Table.Owner = GLOBAL_OWNER);
  const Target = ResolveOwner(Table.Owner);
  if (not IsGlobalTable) and (not Assigned(Target)) then
    Exit;

  DefineMethodLengths(Table, Target);

  if not IsGlobalTable then
    HideProperties(Target);
end;

function TJSBuiltinAttributes.ResolveOwner(const Path: string): IJSObject;
begin
  Result := nil;
  if Path = GLOBAL_OWNER then
    Exit;

  const Segments = Path.Split([PATH_SEPARATOR]);
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
    Exit(Target.GetProperty(Name));

  Result := FInterpreter.GetGlobalVariable(Name);
end;

procedure TJSBuiltinAttributes.DefineMethodLengths(const Table: TJSArityTable; const Target: IJSObject);
begin
  const Entries = Table.Entries.Split([ENTRY_SEPARATOR], TStringSplitOptions.ExcludeEmpty);
  for var Entry in Entries do
  begin
    const Parts = Entry.Split([ARITY_SEPARATOR]);
    const Member = ResolveMember(Target, Parts[0]);
    if not Member.IsFunction then
      Continue;

    const Arity = StrToInt(Parts[1]);
    TJSFunction.DefineLength(Member.ToObject, Arity);

    var Method: IJSFunction;
    const IsFunction = Supports(Member.ToObject, IJSFunction, Method);
    const IsMethod = IsFunction and (Assigned(Target) or (not Method.HasOwnProperty(PROTOTYPE_PROPERTY)));
    if IsMethod then
      Method.IsConstructor := False;
  end;
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
