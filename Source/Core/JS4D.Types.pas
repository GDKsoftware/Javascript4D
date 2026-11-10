unit JS4D.Types;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.PcreMatcher;

type
  TJSValueType = (
    Undefined,
    Null,
    Boolean_,
    Number,
    String_,
    Object_,
    Function_,
    Array_
  );

  TJSErrorType = (
    Error,
    TypeError,
    RangeError,
    ReferenceError,
    SyntaxError,
    URIError,
    EvalError
  );

  TJSLimits = record
  public
    const
      DefaultMaxCallDepth = 100;
      DefaultMaxStringLength = 16 * 1024 * 1024;
      DefaultMaxArrayLength = 1024 * 1024;

  public
    MaxCallDepth: Integer;
    MaxStringLength: Integer;
    MaxArrayLength: Integer;

    class function Default: TJSLimits; static;
    // Limits that only cap nesting depth, for host-side conversions that have no engine limits at hand.
    class function DepthCapped: TJSLimits; static;

    procedure EnsureStringLength(const RequestedLength: Int64);
    procedure EnsureArrayLength(const RequestedLength: Int64);
    procedure EnsureNestingDepth(const RequestedDepth: Integer);
  end;

  IJSObject = interface;
  IJSArray = interface;
  IJSScope = interface;
  IJSFunction = interface;

  TJSValue = record
  private
    FValueType: TJSValueType;
    FBooleanValue: Boolean;
    FNumberValue: Double;
    FStringValue: string;
    FObjectRef: IJSObject;

    class procedure AppendArrayText(const SourceArray: IJSArray; const Builder: TStringBuilder;
      const Visiting: TList<Pointer>; const Limits: TJSLimits); static;

  public
    class function CreateUndefined: TJSValue; static;
    class function CreateNull: TJSValue; static;
    class function CreateBoolean(const Value: Boolean): TJSValue; static;
    class function CreateNumber(const Value: Double): TJSValue; static;
    class function CreateString(const Value: string): TJSValue; static;
    class function CreateObject(const Value: IJSObject): TJSValue; static;
    class function CreateNaN: TJSValue; static;
    class function CreateInfinity(const Negative: Boolean = False): TJSValue; static;

    function IsUndefined: Boolean;
    function IsNull: Boolean;
    function IsNullOrUndefined: Boolean;
    function IsBoolean: Boolean;
    function IsNumber: Boolean;
    function IsString: Boolean;
    function IsObject: Boolean;
    function IsFunction: Boolean;
    function IsArray: Boolean;
    function IsNaN: Boolean;
    function IsInfinity: Boolean;

    function SameValue(const Other: TJSValue): Boolean;
    function StrictEquals(const Other: TJSValue): Boolean;

    function ToBoolean: Boolean;
    function ToNumber: Double;
    function ToInteger: Int64;
    // Host-side conversion. Arrays nested deeper than the default call depth raise EJSCallDepthExceeded,
    // but the text length is not limited. Script values inside the engine go through ToLimitedString.
    function ToString: string;
    function ToLimitedString(const Limits: TJSLimits): string;
    function ToObject: IJSObject;
    function ToPrimitive(const PreferString: Boolean): TJSValue;

    function Clone: TJSValue;

    property ValueType: TJSValueType read FValueType;
    property AsBoolean: Boolean read FBooleanValue;
    property AsNumber: Double read FNumberValue;
    property AsString: string read FStringValue;
    property AsObject: IJSObject read FObjectRef;
  end;

  IJSScope = interface
    ['{D5E6F7A8-B9C0-1234-5678-90ABCDEF0001}']
    function HasVariable(const Name: string): Boolean;
    function GetVariable(const Name: string): TJSValue;
    procedure SetVariable(const Name: string; const Value: TJSValue);
    procedure DeclareVariable(const Name: string; const Value: TJSValue);
    procedure DeclareDeletableVariable(const Name: string; const Value: TJSValue);
    function DeleteVariable(const Name: string): Boolean;
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    function GetOwnVariables: TArray<TJSValue>;
    procedure ReleaseReferences;
    property Parent: IJSScope read GetParent;
  end;

  TNativeFunction = reference to function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;

  TJSPropertyDescriptor = record
    Value: TJSValue;
    Getter: TJSValue;
    Setter: TJSValue;
    IsAccessor: Boolean;
    Writable: Boolean;
    Enumerable: Boolean;
    Configurable: Boolean;

    class function Create(const AValue: TJSValue): TJSPropertyDescriptor; static;
  end;

  TJSPropertyDefinition = record
    HasValue: Boolean;
    HasWritable: Boolean;
    HasGetter: Boolean;
    HasSetter: Boolean;
    HasEnumerable: Boolean;
    HasConfigurable: Boolean;
    Value: TJSValue;
    Getter: TJSValue;
    Setter: TJSValue;
    Writable: Boolean;
    Enumerable: Boolean;
    Configurable: Boolean;

    function IsAccessorDefinition: Boolean;
    function IsDataDefinition: Boolean;
    function IsEmpty: Boolean;
  end;

  TJSCallHandler = class abstract
  public
    function CallFunction(const Func: IJSFunction; const Args: TArray<TJSValue>;
      const ThisObj: IJSObject): TJSValue; virtual; abstract;
  end;

  IJSObject = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function HasProperty(const Name: string): Boolean;
    function GetProperty(const Name: string): TJSValue;
    procedure SetProperty(const Name: string; const Value: TJSValue);
    procedure SetNonConfigurableProperty(const Name: string; const Value: TJSValue);
    procedure DeleteProperty(const Name: string);
    function IsPropertyConfigurable(const Name: string): Boolean;
    function GetOwnPropertyNames: TArray<string>;
    function GetPrototype: IJSObject;
    procedure SetPrototype(const Value: IJSObject);
    property Prototype: IJSObject read GetPrototype write SetPrototype;
    function IsFrozen: Boolean;
    function IsSealed: Boolean;
    function IsExtensible: Boolean;
    procedure Freeze;
    procedure Seal;
    procedure PreventExtensions;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
    function HasOwnProperty(const Name: string): Boolean;
    procedure DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
  end;

  IJSArray = interface(IJSObject)
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']
    function GetLength: Integer;
    function GetElement(const Index: Integer): TJSValue;
    procedure SetElement(const Index: Integer; const Value: TJSValue);
    procedure Push(const Value: TJSValue);
    function Pop: TJSValue;
    function HasElement(const Index: Integer): Boolean;
    procedure DeleteElement(const Index: Integer);
    property Length: Integer read GetLength;
    property Elements[const Index: Integer]: TJSValue read GetElement write SetElement; default;
  end;

  IJSFunction = interface(IJSObject)
    ['{C3D4E5F6-A7B8-9012-CDEF-345678901234}']
    function GetName: string;
    procedure SetName(const Value: string);
    function GetParameters: TArray<string>;
    procedure SetParameters(const Value: TArray<string>);
    function GetBodyNode: TObject;
    procedure SetBodyNode(const Value: TObject);
    function GetNativeFunction: TNativeFunction;
    function GetIsNative: Boolean;
    function GetIsStrict: Boolean;
    procedure SetIsStrict(const Value: Boolean);
    function GetClosureScope: IJSScope;
    procedure SetClosureScope(const Value: IJSScope);
    procedure SetNativeFunction(const Value: TNativeFunction);
    function GetCallHandler: TJSCallHandler;
    procedure SetCallHandler(const Value: TJSCallHandler);
    function GetIsConstructor: Boolean;
    procedure SetIsConstructor(const Value: Boolean);
    function Call(const ThisObj: IJSObject; const Args: TArray<TJSValue>): TJSValue;
    property Name: string read GetName write SetName;
    property Parameters: TArray<string> read GetParameters write SetParameters;
    property BodyNode: TObject read GetBodyNode write SetBodyNode;
    property NativeFunction: TNativeFunction read GetNativeFunction write SetNativeFunction;
    property IsNative: Boolean read GetIsNative;
    property IsStrict: Boolean read GetIsStrict write SetIsStrict;
    property ClosureScope: IJSScope read GetClosureScope write SetClosureScope;
    property CallHandler: TJSCallHandler read GetCallHandler write SetCallHandler;
    property IsConstructor: Boolean read GetIsConstructor write SetIsConstructor;
  end;

  IJSError = interface(IJSObject)
    ['{D4E5F6A7-B8C9-0123-DEFA-456789012345}']
    function GetErrorType: TJSErrorType;
    function GetMessage: string;
    procedure SetMessage(const Value: string);
    function GetStack: string;
    procedure SetStack(const Value: string);
    function GetErrorName: string;
    property ErrorType: TJSErrorType read GetErrorType;
    property Message: string read GetMessage write SetMessage;
    property Stack: string read GetStack write SetStack;
  end;

  IJSDate = interface(IJSObject)
    ['{E5F6A7B8-C9D0-1234-EFAB-567890123456}']
    function GetTime: Double;
    procedure SetTime(const Value: Double);
    property Time: Double read GetTime write SetTime;
  end;

  TJSCallbackExecutor = reference to function(const Func: IJSFunction; const Args: TArray<TJSValue>): TJSValue;

  TJSRegExpMatch = record
    Found: Boolean;
    Index: Integer;
    Length: Integer;
    Captures: TArray<TJSValue>;
  end;

  IJSRegExp = interface(IJSObject)
    ['{F6A7B8C9-D0E1-2345-FABC-678901234567}']
    function Test(const Str: string): Boolean;
    function Exec(const Str: string): TJSValue;
    function Match(const Str: string): TJSValue;
    function MatchAt(const Str: string; const Start: Integer): TJSRegExpMatch;
    function CountReplacements(const Str: string): Integer;
    function Search(const Str: string): Integer;
    function GetPattern: string;
    function GetFlags: string;
    function GetGlobal: Boolean;
    function GetIgnoreCase: Boolean;
    function GetMultiline: Boolean;
    function GetLastIndex: Integer;
    procedure SetLastIndex(const Value: Integer);
    property Pattern: string read GetPattern;
    property Flags: string read GetFlags;
    property Global: Boolean read GetGlobal;
    property IgnoreCase: Boolean read GetIgnoreCase;
    property Multiline: Boolean read GetMultiline;
    property LastIndex: Integer read GetLastIndex write SetLastIndex;
  end;

  IJSPrimitiveWrapper = interface(IJSObject)
    ['{A7B8C9D0-E1F2-3456-ABCD-789012345678}']
    function GetPrimitive: TJSValue;
    function GetClassName: string;
    property Primitive: TJSValue read GetPrimitive;
  end;

  TJSObjectImpl = class(TInterfacedObject, IJSObject)
  private
    FProperties: TDictionary<string, TJSPropertyDescriptor>;
    FOrderedKeys: TList<string>;
    FPrototype: IJSObject;
    FFrozen: Boolean;
    FSealed: Boolean;
    FExtensible: Boolean;

    function InvokeGetter(const Descriptor: TJSPropertyDescriptor): TJSValue;
    procedure InvokeSetter(const Descriptor: TJSPropertyDescriptor; const Value: TJSValue);
    function AddDefinedProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
    class procedure ReleaseClosure(const Value: TJSValue); static;

  protected
    class function CanRedefine(const Current: TJSPropertyDescriptor;
                               const Definition: TJSPropertyDefinition): Boolean; static;
    class function ApplyDefinition(const Current: TJSPropertyDescriptor;
                                   const Definition: TJSPropertyDefinition): TJSPropertyDescriptor; static;

    function GetPrototype: IJSObject;
    procedure SetPrototype(const Value: IJSObject);

    // Releasing a very deeply nested chain of arrays and objects would recurse through one destructor
    // per level and overflow the stack. A destructor calls ReleaseNested first, which empties the nested
    // objects it holds the last reference to one at a time.
    function HoldsNested: Boolean; virtual;
    procedure DetachNested(const Pending: TList<IJSObject>); virtual;
    procedure ReleaseNested;

  public
    constructor Create;
    destructor Destroy; override;

    function HasProperty(const Name: string): Boolean; virtual;
    function GetProperty(const Name: string): TJSValue;
    procedure SetProperty(const Name: string; const Value: TJSValue); virtual;
    procedure SetNonConfigurableProperty(const Name: string; const Value: TJSValue);
    procedure DeleteProperty(const Name: string); virtual;
    function IsPropertyConfigurable(const Name: string): Boolean;
    function GetOwnPropertyNames: TArray<string>; virtual;

    function IsFrozen: Boolean;
    function IsSealed: Boolean;
    function IsExtensible: Boolean;
    procedure Freeze;
    procedure Seal;
    procedure PreventExtensions;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; virtual;
    function HasOwnProperty(const Name: string): Boolean; virtual;
    procedure DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; virtual;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; virtual;

    property Prototype: IJSObject read GetPrototype write SetPrototype;
  end;

  TJSFunctionImpl = class(TJSObjectImpl, IJSFunction)
  private
    FName: string;
    FParameters: TArray<string>;
    FBodyNode: TObject;
    FNativeFunction: TNativeFunction;
    FIsNative: Boolean;
    FIsStrict: Boolean;
    FClosureScope: IJSScope;
    FCallHandler: TJSCallHandler;
    FIsConstructor: Boolean;

  protected
    function GetName: string;
    procedure SetName(const Value: string);
    function GetParameters: TArray<string>;
    procedure SetParameters(const Value: TArray<string>);
    function GetBodyNode: TObject;
    procedure SetBodyNode(const Value: TObject);
    function GetNativeFunction: TNativeFunction;
    procedure SetNativeFunction(const Value: TNativeFunction);
    function GetIsNative: Boolean;
    function GetIsStrict: Boolean;
    procedure SetIsStrict(const Value: Boolean);
    function GetClosureScope: IJSScope;
    procedure SetClosureScope(const Value: IJSScope);
    function GetCallHandler: TJSCallHandler;
    procedure SetCallHandler(const Value: TJSCallHandler);
    function GetIsConstructor: Boolean;
    procedure SetIsConstructor(const Value: Boolean);

  public
    constructor Create;
    constructor CreateNative(const Name: string; const Func: TNativeFunction);
    destructor Destroy; override;

    class procedure DefineLength(const Target: IJSObject; const Count: Integer); static;
    class procedure DefineName(const Target: IJSObject; const Name: string); static;

    function Call(const ThisObj: IJSObject; const Args: TArray<TJSValue>): TJSValue;

    property Name: string read GetName write SetName;
    property Parameters: TArray<string> read GetParameters write SetParameters;
    property BodyNode: TObject read GetBodyNode write SetBodyNode;
    property NativeFunction: TNativeFunction read GetNativeFunction write SetNativeFunction;
    property IsNative: Boolean read GetIsNative;
    property IsStrict: Boolean read GetIsStrict write SetIsStrict;
    property ClosureScope: IJSScope read GetClosureScope write SetClosureScope;
    property CallHandler: TJSCallHandler read GetCallHandler write SetCallHandler;
    property IsConstructor: Boolean read GetIsConstructor write SetIsConstructor;
  end;

  TJSArrayImpl = class(TJSObjectImpl, IJSArray)
  private
    FElements: TList<TJSValue>;
    FHoles: TDictionary<Integer, Boolean>;
    FLengthWritable: Boolean;

    function GetLengthDescriptor: TJSPropertyDescriptor;
    function PlainElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
    function TryGetElementDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
    function DefineLength(const Definition: TJSPropertyDefinition): Boolean;
    function DefineElement(const Index: Integer; const Name: string;
                           const Definition: TJSPropertyDefinition): Boolean;
    function RedefineElement(const Index: Integer; const Name: string;
                             const Definition: TJSPropertyDefinition): Boolean;
    function AddElement(const Index: Integer; const Name: string;
                        const Definition: TJSPropertyDefinition): Boolean;
    procedure MoveToSpecialElement(const Index: Integer; const Name: string;
                                   const Descriptor: TJSPropertyDescriptor);
    procedure ForgetSpecialElement(const Index: Integer);
    function IsLockedElement(const Index: Integer): Boolean;
    function ResizeTo(const NewLength: Integer): Boolean;
    function ShrinkTo(const NewLength: Integer): Boolean;
    procedure GrowTo(const NewLength: Integer);
    procedure MarkHoles(const FromIndex: Integer; const ToIndex: Integer);
    procedure ForgetHolesBetween(const FromIndex: Integer; const ToIndex: Integer);

  protected
    function HoldsNested: Boolean; override;
    procedure DetachNested(const Pending: TList<IJSObject>); override;
    function GetLength: Integer;
    function GetElement(const Index: Integer): TJSValue;
    procedure SetElement(const Index: Integer; const Value: TJSValue);

  public
    class function TryParseIndex(const Name: string; out Index: Integer): Boolean; static;

    constructor Create;
    destructor Destroy; override;

    procedure Push(const Value: TJSValue);
    function Pop: TJSValue;
    function HasElement(const Index: Integer): Boolean;
    procedure DeleteElement(const Index: Integer);

    procedure SetProperty(const Name: string; const Value: TJSValue); override;
    procedure DeleteProperty(const Name: string); override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: string): Boolean; override;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; override;
    function HasProperty(const Name: string): Boolean; override;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; override;

    property Length: Integer read GetLength;
    property Elements[const Index: Integer]: TJSValue read GetElement write SetElement; default;
  end;

  TJSErrorImpl = class(TJSObjectImpl, IJSError)
  private
    FErrorType: TJSErrorType;
    FMessage: string;
    FStack: string;

  protected
    function GetErrorType: TJSErrorType;
    function GetMessage: string;
    procedure SetMessage(const Value: string);
    function GetStack: string;
    procedure SetStack(const Value: string);

  public
    constructor Create(const ErrorType: TJSErrorType; const Message: string);
    function GetErrorName: string;

    property ErrorType: TJSErrorType read GetErrorType;
    property Message: string read GetMessage write SetMessage;
    property Stack: string read GetStack write SetStack;
  end;

  TJSDateImpl = class(TJSObjectImpl, IJSDate)
  private
    FTime: Double;

  protected
    function GetTime: Double;
    procedure SetTime(const Value: Double);

  public
    constructor Create(const Time: Double);

    property Time: Double read GetTime write SetTime;
  end;

  TJSRegExpImpl = class(TJSObjectImpl, IJSRegExp)
  private
    FPattern: string;
    FFlags: string;
    FMatcher: TJSPcreMatcher;
    FGlobal: Boolean;
    FIgnoreCase: Boolean;
    FMultiline: Boolean;

    function ReadLastIndex: Int64;
    procedure WriteLastIndex(const Value: Integer);
    function FindMatch(const Str: string): TJSRegExpMatch;
    function CaptureValue(const Str: string; const GroupIndex: Integer): TJSValue;
    function BuildExecResult(const Found: TJSRegExpMatch; const Str: string): TJSValue;
    function MatchAllText(const Str: string): TJSValue;

  protected
    function GetPattern: string;
    function GetFlags: string;
    function GetGlobal: Boolean;
    function GetIgnoreCase: Boolean;
    function GetMultiline: Boolean;
    function GetLastIndex: Integer;
    procedure SetLastIndex(const Value: Integer);

  public
    constructor Create(const Pattern: string; const Flags: string = '');
    destructor Destroy; override;

    function Test(const Str: string): Boolean;
    function Exec(const Str: string): TJSValue;
    function Match(const Str: string): TJSValue;
    function MatchAt(const Str: string; const Start: Integer): TJSRegExpMatch;
    function CountReplacements(const Str: string): Integer;
    function Search(const Str: string): Integer;

    property Pattern: string read GetPattern;
    property Flags: string read GetFlags;
    property Global: Boolean read GetGlobal;
    property IgnoreCase: Boolean read GetIgnoreCase;
    property Multiline: Boolean read GetMultiline;
    property LastIndex: Integer read GetLastIndex write SetLastIndex;
  end;

  TJSPrimitiveWrapperImpl = class(TJSObjectImpl, IJSPrimitiveWrapper)
  private
    FPrimitive: TJSValue;

    function IsStringWrapper: Boolean;
    function TryGetOwnStringDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;

  protected
    function GetPrimitive: TJSValue;
    function GetClassName: string;

  public
    constructor Create(const Primitive: TJSValue);

    function HasProperty(const Name: string): Boolean; override;
    function GetOwnPropertyNames: TArray<string>; override;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor; override;
    function HasOwnProperty(const Name: string): Boolean; override;
    function DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean; override;
    function TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean; override;

    property Primitive: TJSValue read GetPrimitive;
  end;

  TJSObject = TJSObjectImpl;
  TJSFunction = TJSFunctionImpl;
  TJSArray = TJSArrayImpl;
  TJSError = TJSErrorImpl;
  TJSDate = TJSDateImpl;
  TJSRegExp = TJSRegExpImpl;
  TJSPrimitiveWrapper = TJSPrimitiveWrapperImpl;

implementation

uses
  System.Math,
  JS4D.Errors,
  JS4D.NumberFormat,
  JS4D.NumberParse,
  JS4D.RegExpSyntax;

{ TJSLimits }

class function TJSLimits.Default: TJSLimits;
begin
  Result.MaxCallDepth := DefaultMaxCallDepth;
  Result.MaxStringLength := DefaultMaxStringLength;
  Result.MaxArrayLength := DefaultMaxArrayLength;
end;

procedure TJSLimits.EnsureStringLength(const RequestedLength: Int64);
begin
  if (MaxStringLength > 0) and (RequestedLength > MaxStringLength) then
    raise EJSAllocationLimitExceeded.Create(TJSAllocationKind.Characters, MaxStringLength);
end;

class function TJSLimits.DepthCapped: TJSLimits;
begin
  Result.MaxCallDepth := DefaultMaxCallDepth;
  Result.MaxStringLength := 0;
  Result.MaxArrayLength := 0;
end;

procedure TJSLimits.EnsureNestingDepth(const RequestedDepth: Integer);
begin
  if (MaxCallDepth > 0) and (RequestedDepth > MaxCallDepth) then
    raise EJSCallDepthExceeded.Create(MaxCallDepth);
end;

procedure TJSLimits.EnsureArrayLength(const RequestedLength: Int64);
begin
  if (MaxArrayLength > 0) and (RequestedLength > MaxArrayLength) then
    raise EJSAllocationLimitExceeded.Create(TJSAllocationKind.Elements, MaxArrayLength);
end;

const
  UNDEFINED_STRING = 'undefined';
  EMPTY_PATTERN_GROUP = '(?:)';
  NULL_STRING = 'null';
  TRUE_STRING = 'true';
  FALSE_STRING = 'false';
  NAN_STRING = 'NaN';
  VALUE_OF_METHOD = 'valueOf';
  TO_STRING_METHOD = 'toString';
  CANNOT_CONVERT_TO_PRIMITIVE = 'Cannot convert object to primitive value';
  INFINITY_STRING = 'Infinity';
  NEGATIVE_INFINITY_STRING = '-Infinity';
  OBJECT_STRING = '[object Object]';
  FUNCTION_STRING = '[object Function]';
  ARRAY_SEPARATOR = ',';
  LENGTH_PROPERTY = 'length';
  CLASS_NAME_STRING = 'String';
  CLASS_NAME_NUMBER = 'Number';
  CLASS_NAME_BOOLEAN = 'Boolean';

  PROP_NAME = 'name';
  PROP_MESSAGE = 'message';
  PROP_STACK = 'stack';
  PROP_SOURCE = 'source';
  PROP_FLAGS = 'flags';
  PROP_GLOBAL = 'global';
  PROP_IGNORE_CASE = 'ignoreCase';
  PROP_MULTILINE = 'multiline';
  PROP_LAST_INDEX = 'lastIndex';
  PROP_INDEX = 'index';
  PROP_INPUT = 'input';

class function TJSPropertyDescriptor.Create(const AValue: TJSValue): TJSPropertyDescriptor;
begin
  Result := Default(TJSPropertyDescriptor);
  Result.Value := AValue;
  Result.Writable := True;
  Result.Enumerable := True;
  Result.Configurable := True;
end;

{ TJSPropertyDefinition }

function TJSPropertyDefinition.IsAccessorDefinition: Boolean;
begin
  Result := HasGetter or HasSetter;
end;

function TJSPropertyDefinition.IsDataDefinition: Boolean;
begin
  Result := HasValue or HasWritable;
end;

function TJSPropertyDefinition.IsEmpty: Boolean;
begin
  Result := not (HasValue or HasWritable or HasGetter or HasSetter or HasEnumerable or HasConfigurable);
end;

class function TJSValue.CreateUndefined: TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Undefined;
end;

class function TJSValue.CreateNull: TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Null;
end;

class function TJSValue.CreateBoolean(const Value: Boolean): TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Boolean_;
  Result.FBooleanValue := Value;
end;

class function TJSValue.CreateNumber(const Value: Double): TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Number;
  Result.FNumberValue := Value;
end;

class function TJSValue.CreateString(const Value: string): TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.String_;
  Result.FStringValue := Value;
end;

class function TJSValue.CreateObject(const Value: IJSObject): TJSValue;
var
  FuncIntf: IJSFunction;
  ArrayIntf: IJSArray;
begin
  Result := Default(TJSValue);

  if Supports(Value, IJSFunction, FuncIntf) then
    Result.FValueType := TJSValueType.Function_
  else if Supports(Value, IJSArray, ArrayIntf) then
    Result.FValueType := TJSValueType.Array_
  else
    Result.FValueType := TJSValueType.Object_;

  Result.FObjectRef := Value;
end;

class function TJSValue.CreateNaN: TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Number;
  Result.FNumberValue := System.Math.NaN;
end;

class function TJSValue.CreateInfinity(const Negative: Boolean): TJSValue;
begin
  Result := Default(TJSValue);
  Result.FValueType := TJSValueType.Number;

  if Negative then
    Result.FNumberValue := NegInfinity
  else
    Result.FNumberValue := Infinity;
end;

function TJSValue.IsUndefined: Boolean;
begin
  Result := FValueType = TJSValueType.Undefined;
end;

function TJSValue.IsNull: Boolean;
begin
  Result := FValueType = TJSValueType.Null;
end;

function TJSValue.IsNullOrUndefined: Boolean;
begin
  Result := (FValueType = TJSValueType.Undefined) or (FValueType = TJSValueType.Null);
end;

function TJSValue.IsBoolean: Boolean;
begin
  Result := FValueType = TJSValueType.Boolean_;
end;

function TJSValue.IsNumber: Boolean;
begin
  Result := FValueType = TJSValueType.Number;
end;

function TJSValue.IsString: Boolean;
begin
  Result := FValueType = TJSValueType.String_;
end;

function TJSValue.IsObject: Boolean;
begin
  Result := FValueType in [TJSValueType.Object_, TJSValueType.Function_, TJSValueType.Array_];
end;

function TJSValue.IsFunction: Boolean;
begin
  Result := FValueType = TJSValueType.Function_;
end;

function TJSValue.IsArray: Boolean;
begin
  Result := FValueType = TJSValueType.Array_;
end;

function TJSValue.IsNaN: Boolean;
begin
  Result := IsNumber and System.Math.IsNaN(FNumberValue);
end;

function TJSValue.SameValue(const Other: TJSValue): Boolean;
begin
  if FValueType <> Other.FValueType then
    Exit(False);

  case FValueType of
    TJSValueType.Undefined,
    TJSValueType.Null:
      Result := True;
    TJSValueType.Boolean_:
      Result := FBooleanValue = Other.FBooleanValue;
    TJSValueType.Number:
      begin
        const BothNaN = System.Math.IsNaN(FNumberValue) and System.Math.IsNaN(Other.FNumberValue);
        const SameSign = FNumberValue.Sign = Other.FNumberValue.Sign;
        Result := BothNaN or ((FNumberValue = Other.FNumberValue) and SameSign);
      end;
    TJSValueType.String_:
      Result := FStringValue = Other.FStringValue;
    TJSValueType.Object_,
    TJSValueType.Function_,
    TJSValueType.Array_:
      Result := (FObjectRef as IInterface) = (Other.FObjectRef as IInterface);
  else
    raise ENotSupportedException.CreateFmt('Unsupported value type: %d', [Ord(FValueType)]);
  end;
end;

function TJSValue.StrictEquals(const Other: TJSValue): Boolean;
begin
  const BothNumbers = IsNumber and Other.IsNumber;
  if BothNumbers then
    Exit(FNumberValue = Other.FNumberValue);

  Result := SameValue(Other);
end;

function TJSValue.IsInfinity: Boolean;
begin
  Result := IsNumber and System.Math.IsInfinite(FNumberValue);
end;

function TJSValue.ToBoolean: Boolean;
begin
  case FValueType of
    TJSValueType.Undefined:
      Result := False;
    TJSValueType.Null:
      Result := False;
    TJSValueType.Boolean_:
      Result := FBooleanValue;
    TJSValueType.Number:
      Result := (FNumberValue <> 0) and (not System.Math.IsNaN(FNumberValue));
    TJSValueType.String_:
      Result := FStringValue <> '';
    else
      Result := True;
  end;
end;

function TJSValue.ToNumber: Double;
begin
  case FValueType of
    TJSValueType.Undefined:
      Result := System.Math.NaN;
    TJSValueType.Null:
      Result := 0;
    TJSValueType.Boolean_:
      if FBooleanValue then
        Result := 1
      else
        Result := 0;
    TJSValueType.Number:
      Result := FNumberValue;
    TJSValueType.String_:
      begin
        Result := TJSNumberParse.StringToNumber(FStringValue);
      end;
    TJSValueType.Object_:
      begin
        // Date objects coerce to their timestamp (ms since epoch) per ES spec.
        var DateObj: IJSDate;
        var Wrapper: IJSPrimitiveWrapper;
        if Supports(FObjectRef, IJSDate, DateObj) then
          Result := DateObj.GetTime
        else if Supports(FObjectRef, IJSPrimitiveWrapper, Wrapper) then
          Result := Wrapper.Primitive.ToNumber
        else
          Result := System.Math.NaN;
      end;
    else
      Result := System.Math.NaN;
  end;
end;

function TJSValue.ToInteger: Int64;
begin
  const NumberValue = ToNumber;

  if System.Math.IsNaN(NumberValue) then
    Exit(0);

  if System.Math.IsInfinite(NumberValue) then
    Exit(0);

  Result := Trunc(NumberValue);
end;

function TJSValue.ToString: string;
begin
  case FValueType of
    TJSValueType.Undefined:
      Result := UNDEFINED_STRING;
    TJSValueType.Null:
      Result := NULL_STRING;
    TJSValueType.Boolean_:
      if FBooleanValue then
        Result := TRUE_STRING
      else
        Result := FALSE_STRING;
    TJSValueType.Number:
      begin
        if System.Math.IsNaN(FNumberValue) then
          Exit(NAN_STRING);

        if System.Math.IsInfinite(FNumberValue) then
        begin
          if FNumberValue < 0 then
            Exit(NEGATIVE_INFINITY_STRING)
          else
            Exit(INFINITY_STRING);
        end;

        Result := TJSNumberFormat.ToDecimalString(FNumberValue);
      end;
    TJSValueType.String_:
      Result := FStringValue;
    TJSValueType.Object_:
      begin
        var Wrapper: IJSPrimitiveWrapper;
        if Supports(FObjectRef, IJSPrimitiveWrapper, Wrapper) then
          Result := Wrapper.Primitive.ToString
        else
          Result := OBJECT_STRING;
      end;
    TJSValueType.Function_:
      Result := FUNCTION_STRING;
    TJSValueType.Array_:
      Result := ToLimitedString(TJSLimits.DepthCapped);
    else
      Result := '';
  end;
end;

function TJSValue.ToLimitedString(const Limits: TJSLimits): string;
begin
  var Arr: IJSArray;

  if (FValueType <> TJSValueType.Array_) or (not Supports(FObjectRef, IJSArray, Arr)) then
    Exit(ToString);

  const Builder = TStringBuilder.Create;
  const Visiting = TList<Pointer>.Create;
  try
    AppendArrayText(Arr, Builder, Visiting, Limits);
    Result := Builder.ToString;
  finally
    Visiting.Free;
    Builder.Free;
  end;
end;

class procedure TJSValue.AppendArrayText(const SourceArray: IJSArray; const Builder: TStringBuilder;
  const Visiting: TList<Pointer>; const Limits: TJSLimits);
begin
  Limits.EnsureNestingDepth(Visiting.Count + 1);

  Visiting.Add(Pointer(SourceArray as IInterface));
  try
    for var Index := 0 to SourceArray.Length - 1 do
    begin
      if Index > 0 then
      begin
        const WithSeparator = Int64(Builder.Length) + Length(ARRAY_SEPARATOR);

        Limits.EnsureStringLength(WithSeparator);
        Builder.Append(ARRAY_SEPARATOR);
      end;

      const ElementValue = SourceArray[Index];
      const ElementObject = ElementValue.ToObject;
      var Nested: IJSArray;

      if ElementValue.IsArray and Supports(ElementObject, IJSArray, Nested) then
      begin
        const NestedMarker = Pointer(Nested as IInterface);

        // An array that is already being converted is a cycle and yields an empty element.
        if not Visiting.Contains(NestedMarker) then
          AppendArrayText(Nested, Builder, Visiting, Limits);
      end
      else if not ElementValue.IsNullOrUndefined then
      begin
        const ElementText = ElementValue.ToString;
        const WithElement = Int64(Builder.Length) + Length(ElementText);

        Limits.EnsureStringLength(WithElement);
        Builder.Append(ElementText);
      end;
    end;
  finally
    Visiting.Delete(Visiting.Count - 1);
  end;
end;

function TJSValue.ToObject: IJSObject;
begin
  if IsObject then
    Result := FObjectRef
  else
    Result := nil;
end;

function TJSValue.ToPrimitive(const PreferString: Boolean): TJSValue;
begin
  if not IsObject then
    Exit(Self);

  var ConversionNames := [VALUE_OF_METHOD, TO_STRING_METHOD];
  if PreferString then
    ConversionNames := [TO_STRING_METHOD, VALUE_OF_METHOD];

  for var ConversionName in ConversionNames do
  begin
    const Conversion = FObjectRef.GetProperty(ConversionName);

    var Func: IJSFunction;
    const IsCallable = Conversion.IsFunction and Supports(Conversion.ToObject, IJSFunction, Func);
    if not IsCallable then
      Continue;

    const Converted = Func.Call(FObjectRef, nil);
    if not Converted.IsObject then
      Exit(Converted);
  end;

  raise TJSErrorFactory.TypeError(CANNOT_CONVERT_TO_PRIMITIVE);
end;

function TJSValue.Clone: TJSValue;
begin
  case FValueType of
    TJSValueType.Undefined:
      Result := CreateUndefined;
    TJSValueType.Null:
      Result := CreateNull;
    TJSValueType.Boolean_:
      Result := CreateBoolean(FBooleanValue);
    TJSValueType.Number:
      Result := CreateNumber(FNumberValue);
    TJSValueType.String_:
      Result := CreateString(FStringValue);
    else
      Result := CreateObject(FObjectRef);
  end;
end;

constructor TJSObjectImpl.Create;
begin
  inherited Create;
  FProperties := TDictionary<string, TJSPropertyDescriptor>.Create;
  FOrderedKeys := TList<string>.Create;
  FFrozen := False;
  FSealed := False;
  FExtensible := True;
end;

function TJSObjectImpl.HoldsNested: Boolean;
begin
  Result := False;

  for var Entry in FProperties do
  begin
    const PropertyValue = Entry.Value.Value;

    if PropertyValue.IsObject and (not PropertyValue.IsFunction) then
      Exit(True);
  end;
end;

procedure TJSObjectImpl.DetachNested(const Pending: TList<IJSObject>);
begin
  for var Entry in FProperties do
  begin
    const PropertyValue = Entry.Value.Value;
    const PropertyObject = PropertyValue.ToObject;
    var Func: IJSFunction;

    if PropertyValue.IsFunction and Supports(PropertyObject, IJSFunction, Func) then
      Func.ClosureScope := nil
    else if PropertyValue.IsObject then
      Pending.Add(PropertyObject);
  end;

  FProperties.Clear;
  FOrderedKeys.Clear;
end;

procedure TJSObjectImpl.ReleaseNested;
begin
  if not HoldsNested then
    Exit;

  const Pending = TList<IJSObject>.Create;
  try
    DetachNested(Pending);

    while Pending.Count > 0 do
    begin
      const Current = Pending.Last;

      Pending.Delete(Pending.Count - 1);

      const CurrentObject = Current as TObject;
      const IsOnlyOwner = (CurrentObject is TJSObjectImpl) and (TJSObjectImpl(CurrentObject).RefCount = 1);

      if IsOnlyOwner then
        TJSObjectImpl(CurrentObject).DetachNested(Pending);
    end;
  finally
    Pending.Free;
  end;
end;

destructor TJSObjectImpl.Destroy;
begin
  FPrototype := nil;

  ReleaseNested;

  for var Pair in FProperties do
  begin
    ReleaseClosure(Pair.Value.Value);
    ReleaseClosure(Pair.Value.Getter);
    ReleaseClosure(Pair.Value.Setter);
  end;

  FProperties.Clear;
  FProperties.Free;
  FOrderedKeys.Free;
  inherited;
end;

function TJSObjectImpl.GetPrototype: IJSObject;
begin
  Result := FPrototype;
end;

procedure TJSObjectImpl.SetPrototype(const Value: IJSObject);
begin
  FPrototype := Value;
end;

function TJSObjectImpl.HasProperty(const Name: string): Boolean;
begin
  Result := FProperties.ContainsKey(Name);

  if (not Result) and (FPrototype <> nil) then
    Result := FPrototype.HasProperty(Name);
end;

class procedure TJSObjectImpl.ReleaseClosure(const Value: TJSValue);
begin
  var Func: IJSFunction;

  if Value.IsFunction and Supports(Value.ToObject, IJSFunction, Func) then
    Func.ClosureScope := nil;
end;

function TJSObjectImpl.InvokeGetter(const Descriptor: TJSPropertyDescriptor): TJSValue;
begin
  var Func: IJSFunction;

  const HasGetter = Descriptor.Getter.IsFunction and Supports(Descriptor.Getter.ToObject, IJSFunction, Func);
  if not HasGetter then
    Exit(TJSValue.CreateUndefined);

  Result := Func.Call(Self, nil);
end;

procedure TJSObjectImpl.InvokeSetter(const Descriptor: TJSPropertyDescriptor; const Value: TJSValue);
begin
  var Func: IJSFunction;

  const HasSetter = Descriptor.Setter.IsFunction and Supports(Descriptor.Setter.ToObject, IJSFunction, Func);
  if HasSetter then
    Func.Call(Self, [Value]);
end;

function TJSObjectImpl.GetProperty(const Name: string): TJSValue;
var
  Descriptor: TJSPropertyDescriptor;
begin
  if not TryGetPropertyDescriptor(Name, Descriptor) then
    Exit(TJSValue.CreateUndefined);

  if Descriptor.IsAccessor then
    Result := InvokeGetter(Descriptor)
  else
    Result := Descriptor.Value;
end;

function TJSObjectImpl.TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := FProperties.TryGetValue(Name, Descriptor);

  if (not Result) and (FPrototype <> nil) then
    Result := FPrototype.TryGetPropertyDescriptor(Name, Descriptor);
end;

procedure TJSObjectImpl.SetProperty(const Name: string; const Value: TJSValue);
var
  Descriptor: TJSPropertyDescriptor;
  PrototypeDescriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
  begin
    if Descriptor.IsAccessor then
    begin
      InvokeSetter(Descriptor, Value);
    end
    else if Descriptor.Writable then
    begin
      Descriptor.Value := Value;
      FProperties[Name] := Descriptor;
    end;

    Exit;
  end;

  const HasInherited = (FPrototype <> nil) and FPrototype.TryGetPropertyDescriptor(Name, PrototypeDescriptor);
  if HasInherited and PrototypeDescriptor.IsAccessor then
  begin
    InvokeSetter(PrototypeDescriptor, Value);
    Exit;
  end;

  const BlockedByInherited = HasInherited and (not PrototypeDescriptor.Writable);
  if BlockedByInherited or (not FExtensible) then
    Exit;

  Descriptor := TJSPropertyDescriptor.Create(Value);
  FProperties.Add(Name, Descriptor);
  FOrderedKeys.Add(Name);
end;

procedure TJSObjectImpl.SetNonConfigurableProperty(const Name: string; const Value: TJSValue);
var
  Descriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
  begin
    Descriptor.Value := Value;
    Descriptor.Writable := False;
    Descriptor.Enumerable := False;
    Descriptor.Configurable := False;
    FProperties[Name] := Descriptor;
  end
  else
  begin
    Descriptor := TJSPropertyDescriptor.Create(Value);
    Descriptor.Writable := False;
    Descriptor.Enumerable := False;
    Descriptor.Configurable := False;
    FProperties.Add(Name, Descriptor);
    FOrderedKeys.Add(Name);
  end;
end;

procedure TJSObjectImpl.DeleteProperty(const Name: string);
begin
  if FProperties.ContainsKey(Name) then
  begin
    FProperties.Remove(Name);
    FOrderedKeys.Remove(Name);
  end;
end;

function TJSObjectImpl.IsPropertyConfigurable(const Name: string): Boolean;
var
  Descriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
    Result := Descriptor.Configurable
  else if FPrototype <> nil then
    Result := FPrototype.IsPropertyConfigurable(Name)
  else
    Result := True;
end;

function TJSObjectImpl.GetOwnPropertyNames: TArray<string>;
begin
  Result := FOrderedKeys.ToArray;
end;

function TJSObjectImpl.IsFrozen: Boolean;
begin
  Result := FFrozen;
end;

function TJSObjectImpl.IsSealed: Boolean;
begin
  Result := FSealed;
end;

function TJSObjectImpl.IsExtensible: Boolean;
begin
  Result := FExtensible;
end;

procedure TJSObjectImpl.Freeze;
begin
  FFrozen := True;
  FSealed := True;
  FExtensible := False;

  for var Key in FProperties.Keys.ToArray do
  begin
    var Descriptor := FProperties[Key];
    Descriptor.Writable := False;
    Descriptor.Configurable := False;
    FProperties[Key] := Descriptor;
  end;
end;

procedure TJSObjectImpl.Seal;
begin
  FSealed := True;
  FExtensible := False;

  for var Key in FProperties.Keys.ToArray do
  begin
    var Descriptor := FProperties[Key];
    Descriptor.Configurable := False;
    FProperties[Key] := Descriptor;
  end;
end;

procedure TJSObjectImpl.PreventExtensions;
begin
  FExtensible := False;
end;

function TJSObjectImpl.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  if not FProperties.TryGetValue(Name, Result) then
  begin
    Result := Default(TJSPropertyDescriptor);
    Result.Value := TJSValue.CreateUndefined;
  end;
end;

function TJSObjectImpl.HasOwnProperty(const Name: string): Boolean;
begin
  Result := FProperties.ContainsKey(Name);
end;

procedure TJSObjectImpl.DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);
begin
  var ExistingDescriptor: TJSPropertyDescriptor;

  if FProperties.TryGetValue(Name, ExistingDescriptor) then
  begin
    if not ExistingDescriptor.Configurable then
      Exit;

    FProperties[Name] := Descriptor;
  end
  else
  begin
    if not FExtensible then
      Exit;

    FProperties.Add(Name, Descriptor);
    FOrderedKeys.Add(Name);
  end;
end;

function TJSObjectImpl.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  var Current: TJSPropertyDescriptor;

  if not FProperties.TryGetValue(Name, Current) then
    Exit(AddDefinedProperty(Name, Definition));

  Result := CanRedefine(Current, Definition);
  if Result then
    FProperties[Name] := ApplyDefinition(Current, Definition);
end;

function TJSObjectImpl.AddDefinedProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  if not FExtensible then
    Exit(False);

  var Descriptor := Default(TJSPropertyDescriptor);
  Descriptor.Enumerable := Definition.Enumerable;
  Descriptor.Configurable := Definition.Configurable;

  if Definition.IsAccessorDefinition then
  begin
    Descriptor.IsAccessor := True;
    Descriptor.Getter := Definition.Getter;
    Descriptor.Setter := Definition.Setter;
  end
  else
  begin
    Descriptor.Value := Definition.Value;
    Descriptor.Writable := Definition.Writable;
  end;

  FProperties.Add(Name, Descriptor);
  FOrderedKeys.Add(Name);
  Result := True;
end;

class function TJSObjectImpl.CanRedefine(const Current: TJSPropertyDescriptor;
                                         const Definition: TJSPropertyDefinition): Boolean;
begin
  if Definition.IsEmpty or Current.Configurable then
    Exit(True);

  const BecomesConfigurable = Definition.HasConfigurable and Definition.Configurable;
  const ChangesEnumerable = Definition.HasEnumerable and (Definition.Enumerable <> Current.Enumerable);
  if BecomesConfigurable or ChangesEnumerable then
    Exit(False);

  const ChangesKind = (Definition.IsAccessorDefinition and (not Current.IsAccessor)) or
                      (Definition.IsDataDefinition and Current.IsAccessor);
  if ChangesKind then
    Exit(False);

  if Current.IsAccessor then
  begin
    const ChangesGetter = Definition.HasGetter and (not Definition.Getter.SameValue(Current.Getter));
    const ChangesSetter = Definition.HasSetter and (not Definition.Setter.SameValue(Current.Setter));
    Exit(not (ChangesGetter or ChangesSetter));
  end;

  if Current.Writable then
    Exit(True);

  const BecomesWritable = Definition.HasWritable and Definition.Writable;
  const ChangesValue = Definition.HasValue and (not Definition.Value.SameValue(Current.Value));
  Result := not (BecomesWritable or ChangesValue);
end;

class function TJSObjectImpl.ApplyDefinition(const Current: TJSPropertyDescriptor;
                                             const Definition: TJSPropertyDefinition): TJSPropertyDescriptor;
begin
  Result := Current;

  const ChangesKind = (Definition.IsAccessorDefinition and (not Current.IsAccessor)) or
                      (Definition.IsDataDefinition and Current.IsAccessor);
  if ChangesKind then
  begin
    Result.IsAccessor := Definition.IsAccessorDefinition;
    Result.Value := TJSValue.CreateUndefined;
    Result.Getter := TJSValue.CreateUndefined;
    Result.Setter := TJSValue.CreateUndefined;
    Result.Writable := False;
  end;

  if Definition.HasValue then
    Result.Value := Definition.Value;

  if Definition.HasWritable then
    Result.Writable := Definition.Writable;

  if Definition.HasGetter then
    Result.Getter := Definition.Getter;

  if Definition.HasSetter then
    Result.Setter := Definition.Setter;

  if Definition.HasEnumerable then
    Result.Enumerable := Definition.Enumerable;

  if Definition.HasConfigurable then
    Result.Configurable := Definition.Configurable;
end;

function TJSFunctionImpl.Call(const ThisObj: IJSObject; const Args: TArray<TJSValue>): TJSValue;
begin
  if FIsNative then
    Exit(FNativeFunction(ThisObj, Args));

  if FCallHandler = nil then
    raise TJSErrorFactory.TypeError(Format('Function %s cannot be called outside an interpreter', [FName]));

  Result := FCallHandler.CallFunction(Self, Args, ThisObj);
end;

function TJSFunctionImpl.GetCallHandler: TJSCallHandler;
begin
  Result := FCallHandler;
end;

procedure TJSFunctionImpl.SetCallHandler(const Value: TJSCallHandler);
begin
  FCallHandler := Value;
end;

function TJSFunctionImpl.GetIsConstructor: Boolean;
begin
  Result := FIsConstructor;
end;

procedure TJSFunctionImpl.SetIsConstructor(const Value: Boolean);
begin
  FIsConstructor := Value;
end;

constructor TJSFunctionImpl.Create;
begin
  inherited Create;
  FIsNative := False;
  FIsConstructor := True;
  DefineName(Self, '');
end;

constructor TJSFunctionImpl.CreateNative(const Name: string; const Func: TNativeFunction);
begin
  inherited Create;
  FName := Name;
  FNativeFunction := Func;
  FIsNative := True;
  FIsConstructor := True;
  DefineName(Self, Name);
end;

destructor TJSFunctionImpl.Destroy;
begin
  FClosureScope := nil;
  FNativeFunction := nil;
  inherited;
end;

function TJSFunctionImpl.GetName: string;
begin
  Result := FName;
end;

procedure TJSFunctionImpl.SetName(const Value: string);
begin
  FName := Value;
  DefineName(Self, Value);
end;

function TJSFunctionImpl.GetParameters: TArray<string>;
begin
  Result := FParameters;
end;

procedure TJSFunctionImpl.SetParameters(const Value: TArray<string>);
begin
  FParameters := Value;
  DefineLength(Self, Length(Value));
end;

class procedure TJSFunctionImpl.DefineLength(const Target: IJSObject; const Count: Integer);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(Count));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(LENGTH_PROPERTY, Descriptor);
end;

class procedure TJSFunctionImpl.DefineName(const Target: IJSObject; const Name: string);
begin
  var Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateString(Name));
  Descriptor.Writable := False;
  Descriptor.Enumerable := False;
  Descriptor.Configurable := True;
  Target.DefineProperty(PROP_NAME, Descriptor);
end;

function TJSFunctionImpl.GetBodyNode: TObject;
begin
  Result := FBodyNode;
end;

procedure TJSFunctionImpl.SetBodyNode(const Value: TObject);
begin
  FBodyNode := Value;
end;

function TJSFunctionImpl.GetNativeFunction: TNativeFunction;
begin
  Result := FNativeFunction;
end;

procedure TJSFunctionImpl.SetNativeFunction(const Value: TNativeFunction);
begin
  FNativeFunction := Value;
end;

function TJSFunctionImpl.GetIsNative: Boolean;
begin
  Result := FIsNative;
end;

function TJSFunctionImpl.GetIsStrict: Boolean;
begin
  Result := FIsStrict;
end;

procedure TJSFunctionImpl.SetIsStrict(const Value: Boolean);
begin
  FIsStrict := Value;
end;

function TJSFunctionImpl.GetClosureScope: IJSScope;
begin
  Result := FClosureScope;
end;

procedure TJSFunctionImpl.SetClosureScope(const Value: IJSScope);
begin
  FClosureScope := Value;
end;

constructor TJSArrayImpl.Create;
begin
  inherited Create;
  FElements := TList<TJSValue>.Create;
  FLengthWritable := True;
end;

class function TJSArrayImpl.TryParseIndex(const Name: string; out Index: Integer): Boolean;
begin
  Result := TryStrToInt(Name, Index) and (Index >= 0) and (IntToStr(Index) = Name);
end;

function TJSArrayImpl.GetLengthDescriptor: TJSPropertyDescriptor;
begin
  Result := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(FElements.Count));
  Result.Writable := FLengthWritable and (not FFrozen);
  Result.Enumerable := False;
  Result.Configurable := False;
end;

function TJSArrayImpl.PlainElementDescriptor(const Index: Integer): TJSPropertyDescriptor;
begin
  Result := TJSPropertyDescriptor.Create(FElements[Index]);
  Result.Writable := not FFrozen;
  Result.Configurable := not FSealed;
end;

function TJSArrayImpl.TryGetElementDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := False;

  if Name = LENGTH_PROPERTY then
  begin
    Descriptor := GetLengthDescriptor;
    Exit(True);
  end;

  var Index: Integer;
  if not (TryParseIndex(Name, Index) and HasElement(Index)) then
    Exit;

  Descriptor := PlainElementDescriptor(Index);
  Result := True;
end;

procedure TJSArrayImpl.MarkHoles(const FromIndex: Integer; const ToIndex: Integer);
begin
  if not Assigned(FHoles) then
    FHoles := TDictionary<Integer, Boolean>.Create;

  for var Index := FromIndex to ToIndex do
  begin
    FHoles.AddOrSetValue(Index, True);
  end;
end;

procedure TJSArrayImpl.ForgetHolesBetween(const FromIndex: Integer; const ToIndex: Integer);
begin
  if (not Assigned(FHoles)) or (FHoles.Count = 0) then
    Exit;

  for var Index := FromIndex to ToIndex do
  begin
    FHoles.Remove(Index);
  end;
end;

procedure TJSArrayImpl.ForgetSpecialElement(const Index: Integer);
begin
  if FProperties.Count = 0 then
    Exit;

  const Name = IntToStr(Index);
  if FProperties.ContainsKey(Name) then
  begin
    FProperties.Remove(Name);
    FOrderedKeys.Remove(Name);
  end;
end;

procedure TJSArrayImpl.MoveToSpecialElement(const Index: Integer; const Name: string;
                                            const Descriptor: TJSPropertyDescriptor);
begin
  FElements[Index] := TJSValue.CreateUndefined;
  MarkHoles(Index, Index);

  FProperties.Add(Name, Descriptor);
  FOrderedKeys.Add(Name);
end;

function TJSArrayImpl.IsLockedElement(const Index: Integer): Boolean;
begin
  if HasElement(Index) then
    Exit(FSealed);

  var Descriptor: TJSPropertyDescriptor;
  const IsSpecial = (FProperties.Count > 0) and FProperties.TryGetValue(IntToStr(Index), Descriptor);
  Result := IsSpecial and (not Descriptor.Configurable);
end;

procedure TJSArrayImpl.GrowTo(const NewLength: Integer);
begin
  const OldLength = FElements.Count;

  while FElements.Count < NewLength do
  begin
    FElements.Add(TJSValue.CreateUndefined);
  end;

  if NewLength > OldLength then
    MarkHoles(OldLength, NewLength - 1);
end;

function TJSArrayImpl.ShrinkTo(const NewLength: Integer): Boolean;
begin
  const OldLength = FElements.Count;
  var KeptLength := NewLength;

  const MayBeLocked = FSealed or (FProperties.Count > 0);
  if MayBeLocked then
  begin
    for var Index := OldLength - 1 downto NewLength do
    begin
      if IsLockedElement(Index) then
      begin
        KeptLength := Index + 1;
        Break;
      end;

      ForgetSpecialElement(Index);
    end;
  end;

  while FElements.Count > KeptLength do
  begin
    FElements.Delete(FElements.Count - 1);
  end;

  ForgetHolesBetween(KeptLength, OldLength - 1);

  Result := (KeptLength = NewLength);
end;

function TJSArrayImpl.ResizeTo(const NewLength: Integer): Boolean;
begin
  Result := True;

  if NewLength < FElements.Count then
    Result := ShrinkTo(NewLength)
  else
    GrowTo(NewLength);
end;

function TJSArrayImpl.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  var Index: Integer;

  if Name = LENGTH_PROPERTY then
    Result := GetLengthDescriptor
  else if TryParseIndex(Name, Index) and HasElement(Index) then
    Result := PlainElementDescriptor(Index)
  else
    Result := inherited GetOwnPropertyDescriptor(Name);
end;

function TJSArrayImpl.HasOwnProperty(const Name: string): Boolean;
begin
  var Index: Integer;

  Result := (Name = LENGTH_PROPERTY) or
            (TryParseIndex(Name, Index) and HasElement(Index)) or
            inherited HasOwnProperty(Name);
end;

function TJSArrayImpl.GetOwnPropertyNames: TArray<string>;
begin
  const Names = TList<string>.Create;
  try
    const HasSpecialElements = (FProperties.Count > 0);

    for var Index := 0 to FElements.Count - 1 do
    begin
      const Name = IntToStr(Index);
      const IsOwnElement = HasElement(Index) or (HasSpecialElements and FProperties.ContainsKey(Name));
      if IsOwnElement then
        Names.Add(Name);
    end;

    for var Key in inherited GetOwnPropertyNames do
    begin
      var Index: Integer;
      if not TryParseIndex(Key, Index) then
        Names.Add(Key);
    end;

    Result := Names.ToArray;
  finally
    Names.Free;
  end;
end;

function TJSArrayImpl.HasProperty(const Name: string): Boolean;
var
  Descriptor: TJSPropertyDescriptor;
begin
  Result := TryGetElementDescriptor(Name, Descriptor) or inherited HasProperty(Name);
end;

function TJSArrayImpl.TryGetPropertyDescriptor(const Name: string; out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := TryGetElementDescriptor(Name, Descriptor) or inherited TryGetPropertyDescriptor(Name, Descriptor);
end;

procedure TJSArrayImpl.SetProperty(const Name: string; const Value: TJSValue);
begin
  if Name = LENGTH_PROPERTY then
  begin
    var Definition := Default(TJSPropertyDefinition);
    Definition.HasValue := True;
    Definition.Value := Value;
    DefineLength(Definition);
    Exit;
  end;

  var Index: Integer;
  if not TryParseIndex(Name, Index) then
  begin
    inherited SetProperty(Name, Value);
    Exit;
  end;

  if HasElement(Index) then
  begin
    if not FFrozen then
      FElements[Index] := Value;

    Exit;
  end;

  const LengthDescriptor = GetLengthDescriptor;
  const LengthBlocksIndex = (Index >= FElements.Count) and (not LengthDescriptor.Writable);
  if LengthBlocksIndex then
    Exit;

  const IsSpecialElement = FProperties.ContainsKey(Name);
  inherited SetProperty(Name, Value);

  const WasAddedAsDataProperty = (not IsSpecialElement) and FProperties.ContainsKey(Name);
  if WasAddedAsDataProperty then
  begin
    FProperties.Remove(Name);
    FOrderedKeys.Remove(Name);
    SetElement(Index, Value);
  end;
end;

procedure TJSArrayImpl.DeleteProperty(const Name: string);
begin
  var Index: Integer;
  const IsPlainElement = TryParseIndex(Name, Index) and HasElement(Index);

  if IsPlainElement then
  begin
    if not FSealed then
      DeleteElement(Index);

    Exit;
  end;

  inherited DeleteProperty(Name);
end;

function TJSArrayImpl.DefineLength(const Definition: TJSPropertyDefinition): Boolean;
begin
  const Current = GetLengthDescriptor;
  Result := CanRedefine(Current, Definition);
  if not Result then
    Exit;

  if Definition.HasValue then
  begin
    const NewLength = Definition.Value.ToNumber;
    const IsValidLength = (not System.Math.IsNaN(NewLength)) and (NewLength >= 0) and (Frac(NewLength) = 0) and
                          (NewLength <= MaxInt);
    if not IsValidLength then
      raise TJSErrorFactory.InvalidArrayLength;

    Result := ResizeTo(Trunc(NewLength));
  end;

  if Definition.HasWritable then
    FLengthWritable := Definition.Writable;
end;

function TJSArrayImpl.DefineOwnProperty(const Name: string; const Definition: TJSPropertyDefinition): Boolean;
begin
  if Name = LENGTH_PROPERTY then
    Exit(DefineLength(Definition));

  var Index: Integer;
  if not TryParseIndex(Name, Index) then
    Exit(inherited DefineOwnProperty(Name, Definition));

  Result := DefineElement(Index, Name, Definition);
end;

function TJSArrayImpl.DefineElement(const Index: Integer; const Name: string;
                                    const Definition: TJSPropertyDefinition): Boolean;
begin
  const LengthDescriptor = GetLengthDescriptor;
  const LengthBlocksIndex = (Index >= FElements.Count) and (not LengthDescriptor.Writable);
  if LengthBlocksIndex then
    Exit(False);

  if HasElement(Index) then
    Result := RedefineElement(Index, Name, Definition)
  else if FProperties.ContainsKey(Name) then
    Result := inherited DefineOwnProperty(Name, Definition)
  else
    Result := AddElement(Index, Name, Definition);

  if Result and (Index >= FElements.Count) then
    GrowTo(Index + 1);
end;

function TJSArrayImpl.RedefineElement(const Index: Integer; const Name: string;
                                      const Definition: TJSPropertyDefinition): Boolean;
begin
  const Current = PlainElementDescriptor(Index);
  Result := CanRedefine(Current, Definition);
  if not Result then
    Exit;

  const Updated = ApplyDefinition(Current, Definition);
  const IsPlain = (not Updated.IsAccessor) and Updated.Writable and Updated.Enumerable and Updated.Configurable;
  if IsPlain then
    FElements[Index] := Updated.Value
  else
    MoveToSpecialElement(Index, Name, Updated);
end;

function TJSArrayImpl.AddElement(const Index: Integer; const Name: string;
                                 const Definition: TJSPropertyDefinition): Boolean;
begin
  if not FExtensible then
    Exit(False);

  const IsPlain = (not Definition.IsAccessorDefinition) and Definition.Writable and Definition.Enumerable and
                  Definition.Configurable;
  if not IsPlain then
    Exit(AddDefinedProperty(Name, Definition));

  SetElement(Index, Definition.Value);
  Result := True;
end;

function TJSArrayImpl.HoldsNested: Boolean;
begin
  Result := inherited HoldsNested;

  if Result or (not Assigned(FElements)) then
    Exit;

  for var Element in FElements do
  begin
    if Element.IsObject and (not Element.IsFunction) then
      Exit(True);
  end;
end;

procedure TJSArrayImpl.DetachNested(const Pending: TList<IJSObject>);
begin
  for var Element in FElements do
  begin
    const ElementObject = Element.ToObject;
    var Func: IJSFunction;

    if Element.IsFunction and Supports(ElementObject, IJSFunction, Func) then
      Func.ClosureScope := nil
    else if Element.IsObject then
      Pending.Add(ElementObject);
  end;

  FElements.Clear;

  inherited DetachNested(Pending);
end;

destructor TJSArrayImpl.Destroy;
begin
  ReleaseNested;

  for var Element in FElements do
  begin
    if Element.IsFunction then
    begin
      var Func: IJSFunction;
      if Supports(Element.ToObject, IJSFunction, Func) then
        Func.ClosureScope := nil;
    end;
  end;

  FElements.Clear;
  FreeAndNil(FElements);
  FreeAndNil(FHoles);
  inherited;
end;

function TJSArrayImpl.GetLength: Integer;
begin
  Result := FElements.Count;
end;

function TJSArrayImpl.GetElement(const Index: Integer): TJSValue;
begin
  if (Index >= 0) and (Index < FElements.Count) then
    Result := FElements[Index]
  else
    Result := TJSValue.CreateUndefined;
end;

procedure TJSArrayImpl.SetElement(const Index: Integer; const Value: TJSValue);
begin
  const OldLength = FElements.Count;

  while FElements.Count <= Index do
  begin
    FElements.Add(TJSValue.CreateUndefined);
  end;

  if Index > OldLength then
    MarkHoles(OldLength, Index - 1);

  if Assigned(FHoles) then
    FHoles.Remove(Index);

  ForgetSpecialElement(Index);
  FElements[Index] := Value;
end;

function TJSArrayImpl.HasElement(const Index: Integer): Boolean;
begin
  const InRange = (Index >= 0) and (Index < FElements.Count);
  Result := InRange and ((not Assigned(FHoles)) or (not FHoles.ContainsKey(Index)));
end;

procedure TJSArrayImpl.DeleteElement(const Index: Integer);
begin
  const InRange = (Index >= 0) and (Index < FElements.Count);
  if not InRange then
    Exit;

  FElements[Index] := TJSValue.CreateUndefined;
  MarkHoles(Index, Index);
end;

procedure TJSArrayImpl.Push(const Value: TJSValue);
begin
  FElements.Add(Value);
end;

function TJSArrayImpl.Pop: TJSValue;
begin
  if FElements.Count > 0 then
  begin
    Result := FElements[FElements.Count - 1];
    ForgetSpecialElement(FElements.Count - 1);
    FElements.Delete(FElements.Count - 1);
    ForgetHolesBetween(FElements.Count, FElements.Count);
  end
  else
    Result := TJSValue.CreateUndefined;
end;

constructor TJSErrorImpl.Create(const ErrorType: TJSErrorType; const Message: string);
begin
  inherited Create;
  FErrorType := ErrorType;
  FMessage := Message;
  FStack := GetErrorName + ': ' + Message + sLineBreak + '    at <anonymous>';

  SetProperty(PROP_NAME, TJSValue.CreateString(GetErrorName));
  SetProperty(PROP_MESSAGE, TJSValue.CreateString(Message));
  SetProperty(PROP_STACK, TJSValue.CreateString(FStack));
end;

function TJSErrorImpl.GetErrorType: TJSErrorType;
begin
  Result := FErrorType;
end;

function TJSErrorImpl.GetMessage: string;
begin
  Result := FMessage;
end;

procedure TJSErrorImpl.SetMessage(const Value: string);
begin
  FMessage := Value;
end;

function TJSErrorImpl.GetStack: string;
begin
  Result := FStack;
end;

procedure TJSErrorImpl.SetStack(const Value: string);
begin
  FStack := Value;
end;

function TJSErrorImpl.GetErrorName: string;
begin
  case FErrorType of
    TJSErrorType.Error:
      Result := 'Error';
    TJSErrorType.TypeError:
      Result := 'TypeError';
    TJSErrorType.RangeError:
      Result := 'RangeError';
    TJSErrorType.ReferenceError:
      Result := 'ReferenceError';
    TJSErrorType.SyntaxError:
      Result := 'SyntaxError';
    TJSErrorType.URIError:
      Result := 'URIError';
    TJSErrorType.EvalError:
      Result := 'EvalError';
  end;
end;

constructor TJSDateImpl.Create(const Time: Double);
begin
  inherited Create;
  FTime := Time;
end;

function TJSDateImpl.GetTime: Double;
begin
  Result := FTime;
end;

procedure TJSDateImpl.SetTime(const Value: Double);
begin
  FTime := Value;
end;

constructor TJSRegExpImpl.Create(const Pattern: string; const Flags: string);
begin
  inherited Create;
  TJSRegExpSyntax.ValidateFlags(Flags);
  TJSRegExpSyntax.ValidatePattern(Pattern, Flags);

  FPattern := Pattern;
  FFlags := Flags;
  FGlobal := (Pos('g', Flags) > 0);
  FIgnoreCase := (Pos('i', Flags) > 0);
  FMultiline := (Pos('m', Flags) > 0);

  var CompilablePattern := Pattern;
  if Pattern.IsEmpty then
    CompilablePattern := EMPTY_PATTERN_GROUP;

  FMatcher := TJSPcreMatcher.Create(CompilablePattern, FIgnoreCase, FMultiline);

  SetProperty(PROP_SOURCE, TJSValue.CreateString(Pattern));
  SetProperty(PROP_FLAGS, TJSValue.CreateString(Flags));
  SetProperty(PROP_GLOBAL, TJSValue.CreateBoolean(FGlobal));
  SetProperty(PROP_IGNORE_CASE, TJSValue.CreateBoolean(FIgnoreCase));
  SetProperty(PROP_MULTILINE, TJSValue.CreateBoolean(FMultiline));
  SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(0));
end;

destructor TJSRegExpImpl.Destroy;
begin
  FMatcher.Free;
  inherited Destroy;
end;

function TJSRegExpImpl.GetPattern: string;
begin
  Result := FPattern;
end;

function TJSRegExpImpl.GetFlags: string;
begin
  Result := FFlags;
end;

function TJSRegExpImpl.GetGlobal: Boolean;
begin
  Result := FGlobal;
end;

function TJSRegExpImpl.GetIgnoreCase: Boolean;
begin
  Result := FIgnoreCase;
end;

function TJSRegExpImpl.GetMultiline: Boolean;
begin
  Result := FMultiline;
end;

function TJSRegExpImpl.GetLastIndex: Integer;
begin
  Result := Integer(Min(Max(ReadLastIndex, 0), MaxInt));
end;

procedure TJSRegExpImpl.SetLastIndex(const Value: Integer);
begin
  WriteLastIndex(Value);
end;

function TJSRegExpImpl.ReadLastIndex: Int64;
begin
  Result := GetProperty(PROP_LAST_INDEX).ToInteger;
end;

procedure TJSRegExpImpl.WriteLastIndex(const Value: Integer);
begin
  SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(Value));
end;

function TJSRegExpImpl.MatchAt(const Str: string; const Start: Integer): TJSRegExpMatch;
begin
  Result := Default(TJSRegExpMatch);

  if not FMatcher.TryMatch(Str, Start) then
    Exit;

  const MatchStart = FMatcher.GroupStart(0);

  Result.Found := True;
  Result.Index := MatchStart;
  Result.Length := FMatcher.GroupEnd(0) - MatchStart;

  SetLength(Result.Captures, FMatcher.CaptureCount);
  for var CaptureIndex := 0 to FMatcher.CaptureCount - 1 do
  begin
    Result.Captures[CaptureIndex] := CaptureValue(Str, CaptureIndex + 1);
  end;
end;

function TJSRegExpImpl.CaptureValue(const Str: string; const GroupIndex: Integer): TJSValue;
begin
  if not FMatcher.HasParticipated(GroupIndex) then
    Exit(TJSValue.CreateUndefined);

  const CaptureStart = FMatcher.GroupStart(GroupIndex);
  const CaptureLength = FMatcher.GroupEnd(GroupIndex) - CaptureStart;

  Result := TJSValue.CreateString(Copy(Str, CaptureStart + 1, CaptureLength));
end;

function TJSRegExpImpl.FindMatch(const Str: string): TJSRegExpMatch;
begin
  var Start := ReadLastIndex;
  if not FGlobal then
    Start := 0;

  const InRange = (Start >= 0) and (Start <= Length(Str));
  if InRange then
    Result := MatchAt(Str, Integer(Start))
  else
    Result := Default(TJSRegExpMatch);

  if not Result.Found then
  begin
    WriteLastIndex(0);
    Exit;
  end;

  if FGlobal then
    WriteLastIndex(Result.Index + Result.Length);
end;

function TJSRegExpImpl.Test(const Str: string): Boolean;
begin
  Result := FindMatch(Str).Found;
end;

function TJSRegExpImpl.BuildExecResult(const Found: TJSRegExpMatch; const Str: string): TJSValue;
begin
  const ResultArr: IJSArray = TJSArrayImpl.Create;
  ResultArr.Push(TJSValue.CreateString(Copy(Str, Found.Index + 1, Found.Length)));

  for var Capture in Found.Captures do
  begin
    ResultArr.Push(Capture);
  end;

  ResultArr.SetProperty(PROP_INDEX, TJSValue.CreateNumber(Found.Index));
  ResultArr.SetProperty(PROP_INPUT, TJSValue.CreateString(Str));

  Result := TJSValue.CreateObject(ResultArr);
end;

function TJSRegExpImpl.Exec(const Str: string): TJSValue;
begin
  const Found = FindMatch(Str);
  if not Found.Found then
    Exit(TJSValue.CreateNull);

  Result := BuildExecResult(Found, Str);
end;

function TJSRegExpImpl.MatchAllText(const Str: string): TJSValue;
begin
  WriteLastIndex(0);

  const ResultArr: IJSArray = TJSArrayImpl.Create;
  var Position := 0;

  while Position <= Length(Str) do
  begin
    const Found = MatchAt(Str, Position);
    if not Found.Found then
      Break;

    ResultArr.Push(TJSValue.CreateString(Copy(Str, Found.Index + 1, Found.Length)));

    Position := Found.Index + Found.Length;
    if Found.Length = 0 then
      Inc(Position);
  end;

  if ResultArr.Length = 0 then
    Exit(TJSValue.CreateNull);

  Result := TJSValue.CreateObject(ResultArr);
end;

function TJSRegExpImpl.Match(const Str: string): TJSValue;
begin
  if FGlobal then
    Result := MatchAllText(Str)
  else
    Result := Exec(Str);
end;

function TJSRegExpImpl.CountReplacements(const Str: string): Integer;
begin
  Result := 0;

  var Position := 0;
  while Position <= Length(Str) do
  begin
    const Found = MatchAt(Str, Position);
    if not Found.Found then
      Break;

    Inc(Result);
    if not FGlobal then
      Break;

    Position := Found.Index + Found.Length;
    if Found.Length = 0 then
      Inc(Position);
  end;
end;

function TJSRegExpImpl.Search(const Str: string): Integer;
begin
  const Found = MatchAt(Str, 0);

  if Found.Found then
    Result := Found.Index
  else
    Result := -1;
end;

{ TJSPrimitiveWrapperImpl }

constructor TJSPrimitiveWrapperImpl.Create(const Primitive: TJSValue);
begin
  inherited Create;
  FPrimitive := Primitive;
end;

function TJSPrimitiveWrapperImpl.GetPrimitive: TJSValue;
begin
  Result := FPrimitive;
end;

function TJSPrimitiveWrapperImpl.GetClassName: string;
begin
  if FPrimitive.IsString then
    Result := CLASS_NAME_STRING
  else if FPrimitive.IsNumber then
    Result := CLASS_NAME_NUMBER
  else
    Result := CLASS_NAME_BOOLEAN;
end;

function TJSPrimitiveWrapperImpl.IsStringWrapper: Boolean;
begin
  Result := FPrimitive.IsString;
end;

function TJSPrimitiveWrapperImpl.TryGetOwnStringDescriptor(const Name: string;
                                                           out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := False;

  if not IsStringWrapper then
    Exit;

  const Text = FPrimitive.AsString;

  if Name = LENGTH_PROPERTY then
  begin
    Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateNumber(Length(Text)));
    Descriptor.Writable := False;
    Descriptor.Enumerable := False;
    Descriptor.Configurable := False;
    Exit(True);
  end;

  var CharIndex: Integer;
  const IsCanonicalIndex = TryStrToInt(Name, CharIndex) and (IntToStr(CharIndex) = Name);
  const IsInRange = IsCanonicalIndex and (CharIndex >= 0) and (CharIndex < Length(Text));
  if not IsInRange then
    Exit;

  Descriptor := TJSPropertyDescriptor.Create(TJSValue.CreateString(Text[CharIndex + 1]));
  Descriptor.Writable := False;
  Descriptor.Configurable := False;
  Result := True;
end;

function TJSPrimitiveWrapperImpl.HasProperty(const Name: string): Boolean;
var
  Descriptor: TJSPropertyDescriptor;
begin
  Result := TryGetOwnStringDescriptor(Name, Descriptor) or inherited HasProperty(Name);
end;

function TJSPrimitiveWrapperImpl.GetOwnPropertyNames: TArray<string>;
begin
  const OrdinaryNames = inherited GetOwnPropertyNames;
  if not IsStringWrapper then
    Exit(OrdinaryNames);

  const CharCount = Length(FPrimitive.AsString);
  SetLength(Result, CharCount + 1 + Length(OrdinaryNames));

  for var CharIndex := 0 to CharCount - 1 do
  begin
    Result[CharIndex] := IntToStr(CharIndex);
  end;

  Result[CharCount] := LENGTH_PROPERTY;

  for var NameIndex := 0 to Length(OrdinaryNames) - 1 do
  begin
    Result[CharCount + 1 + NameIndex] := OrdinaryNames[NameIndex];
  end;
end;

function TJSPrimitiveWrapperImpl.GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
begin
  if not TryGetOwnStringDescriptor(Name, Result) then
    Result := inherited GetOwnPropertyDescriptor(Name);
end;

function TJSPrimitiveWrapperImpl.HasOwnProperty(const Name: string): Boolean;
var
  Descriptor: TJSPropertyDescriptor;
begin
  Result := TryGetOwnStringDescriptor(Name, Descriptor) or inherited HasOwnProperty(Name);
end;

function TJSPrimitiveWrapperImpl.DefineOwnProperty(const Name: string;
                                                   const Definition: TJSPropertyDefinition): Boolean;
var
  Current: TJSPropertyDescriptor;
begin
  if TryGetOwnStringDescriptor(Name, Current) then
    Exit(CanRedefine(Current, Definition));

  Result := inherited DefineOwnProperty(Name, Definition);
end;

function TJSPrimitiveWrapperImpl.TryGetPropertyDescriptor(const Name: string;
                                                          out Descriptor: TJSPropertyDescriptor): Boolean;
begin
  Result := TryGetOwnStringDescriptor(Name, Descriptor) or inherited TryGetPropertyDescriptor(Name, Descriptor);
end;

end.
