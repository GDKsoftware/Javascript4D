unit JS4D.Types;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.RegularExpressions;

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

  IJSObject = interface;
  IJSArray = interface;
  IJSScope = interface;

  TJSValue = record
  private
    FValueType: TJSValueType;
    FBooleanValue: Boolean;
    FNumberValue: Double;
    FStringValue: string;
    FObjectRef: IJSObject;

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

    function ToBoolean: Boolean;
    function ToNumber: Double;
    function ToInteger: Int64;
    function ToString: string;
    function ToObject: IJSObject;

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
    function Resolve(const Name: string): IJSScope;
    function GetParent: IJSScope;
    procedure Clear;
    property Parent: IJSScope read GetParent;
  end;

  TNativeFunction = reference to function(const This: IJSObject; const Args: TArray<TJSValue>): TJSValue;

  TJSPropertyDescriptor = record
    Value: TJSValue;
    Writable: Boolean;
    Enumerable: Boolean;
    Configurable: Boolean;

    class function Create(const AValue: TJSValue): TJSPropertyDescriptor; static;
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
  end;

  IJSArray = interface(IJSObject)
    ['{B2C3D4E5-F6A7-8901-BCDE-F23456789012}']
    function GetLength: Integer;
    function GetElement(const Index: Integer): TJSValue;
    procedure SetElement(const Index: Integer; const Value: TJSValue);
    procedure Push(const Value: TJSValue);
    function Pop: TJSValue;
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
    property Name: string read GetName write SetName;
    property Parameters: TArray<string> read GetParameters write SetParameters;
    property BodyNode: TObject read GetBodyNode write SetBodyNode;
    property NativeFunction: TNativeFunction read GetNativeFunction write SetNativeFunction;
    property IsNative: Boolean read GetIsNative;
    property IsStrict: Boolean read GetIsStrict write SetIsStrict;
    property ClosureScope: IJSScope read GetClosureScope write SetClosureScope;
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
    function GetFullYear: Integer;
    function GetMonth: Integer;
    function GetDate: Integer;
    function GetDay: Integer;
    function GetHours: Integer;
    function GetMinutes: Integer;
    function GetSeconds: Integer;
    function GetMilliseconds: Integer;
    function GetUTCFullYear: Integer;
    function GetUTCMonth: Integer;
    function GetUTCDate: Integer;
    function GetUTCDay: Integer;
    function GetUTCHours: Integer;
    function GetUTCMinutes: Integer;
    function GetUTCSeconds: Integer;
    function GetUTCMilliseconds: Integer;
    function GetTimezoneOffset: Integer;
    procedure SetTime(const Value: Double);
    procedure SetFullYear(const Value: Integer);
    procedure SetMonth(const Value: Integer);
    procedure SetDate(const Value: Integer);
    procedure SetHours(const Value: Integer);
    procedure SetMinutes(const Value: Integer);
    procedure SetSeconds(const Value: Integer);
    procedure SetMilliseconds(const Value: Integer);
    function ToISOString: string;
    function ToDateString: string;
    function ToTimeString: string;
    function ToLocaleString: string;
    function GetDateTime: TDateTime;
    procedure SetDateTime(const Value: TDateTime);
    function GetTimestamp: Double;
    procedure SetTimestamp(const Value: Double);
    property DateTime: TDateTime read GetDateTime write SetDateTime;
    property Timestamp: Double read GetTimestamp write SetTimestamp;
  end;

  IJSRegExp = interface(IJSObject)
    ['{F6A7B8C9-D0E1-2345-FABC-678901234567}']
    function Test(const Str: string): Boolean;
    function Exec(const Str: string): TJSValue;
    function Match(const Str: string): TJSValue;
    function Replace(const Str: string; const Replacement: string): string;
    function Search(const Str: string): Integer;
    function Split(const Str: string; const Limit: Integer = -1): IJSArray;
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

  TJSObjectImpl = class(TInterfacedObject, IJSObject)
  private
    FProperties: TDictionary<string, TJSPropertyDescriptor>;
    FPrototype: IJSObject;
    FFrozen: Boolean;
    FSealed: Boolean;
    FExtensible: Boolean;

  protected
    function GetPrototype: IJSObject;
    procedure SetPrototype(const Value: IJSObject);

  public
    constructor Create;
    destructor Destroy; override;

    function HasProperty(const Name: string): Boolean;
    function GetProperty(const Name: string): TJSValue;
    procedure SetProperty(const Name: string; const Value: TJSValue);
    procedure SetNonConfigurableProperty(const Name: string; const Value: TJSValue);
    procedure DeleteProperty(const Name: string);
    function IsPropertyConfigurable(const Name: string): Boolean;
    function GetOwnPropertyNames: TArray<string>;

    function IsFrozen: Boolean;
    function IsSealed: Boolean;
    function IsExtensible: Boolean;
    procedure Freeze;
    procedure Seal;
    procedure PreventExtensions;
    function GetOwnPropertyDescriptor(const Name: string): TJSPropertyDescriptor;
    function HasOwnProperty(const Name: string): Boolean;
    procedure DefineProperty(const Name: string; const Descriptor: TJSPropertyDescriptor);

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

  public
    constructor Create;
    constructor CreateNative(const Name: string; const Func: TNativeFunction);
    destructor Destroy; override;

    property Name: string read GetName write SetName;
    property Parameters: TArray<string> read GetParameters write SetParameters;
    property BodyNode: TObject read GetBodyNode write SetBodyNode;
    property NativeFunction: TNativeFunction read GetNativeFunction write SetNativeFunction;
    property IsNative: Boolean read GetIsNative;
    property IsStrict: Boolean read GetIsStrict write SetIsStrict;
    property ClosureScope: IJSScope read GetClosureScope write SetClosureScope;
  end;

  TJSArrayImpl = class(TJSObjectImpl, IJSArray)
  private
    FElements: TList<TJSValue>;

  protected
    function GetLength: Integer;
    function GetElement(const Index: Integer): TJSValue;
    procedure SetElement(const Index: Integer; const Value: TJSValue);

  public
    constructor Create;
    destructor Destroy; override;

    procedure Push(const Value: TJSValue);
    function Pop: TJSValue;

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
    FDateTime: TDateTime;
    FTimestamp: Double;

    procedure UpdateFromTimestamp;
    procedure UpdateFromDateTime;

  protected
    function GetDateTime: TDateTime;
    procedure SetDateTime(const Value: TDateTime);
    function GetTimestamp: Double;
    procedure SetTimestamp(const Value: Double);

  public
    constructor Create; overload;
    constructor Create(const Timestamp: Double); overload;
    constructor Create(const Year, Month: Integer; const Day: Integer = 1;
      const Hours: Integer = 0; const Minutes: Integer = 0;
      const Seconds: Integer = 0; const Milliseconds: Integer = 0); overload;

    function GetTime: Double;
    function GetFullYear: Integer;
    function GetMonth: Integer;
    function GetDate: Integer;
    function GetDay: Integer;
    function GetHours: Integer;
    function GetMinutes: Integer;
    function GetSeconds: Integer;
    function GetMilliseconds: Integer;

    function GetUTCFullYear: Integer;
    function GetUTCMonth: Integer;
    function GetUTCDate: Integer;
    function GetUTCDay: Integer;
    function GetUTCHours: Integer;
    function GetUTCMinutes: Integer;
    function GetUTCSeconds: Integer;
    function GetUTCMilliseconds: Integer;

    function GetTimezoneOffset: Integer;

    procedure SetTime(const Value: Double);
    procedure SetFullYear(const Value: Integer);
    procedure SetMonth(const Value: Integer);
    procedure SetDate(const Value: Integer);
    procedure SetHours(const Value: Integer);
    procedure SetMinutes(const Value: Integer);
    procedure SetSeconds(const Value: Integer);
    procedure SetMilliseconds(const Value: Integer);

    function ToISOString: string;
    function ToDateString: string;
    function ToTimeString: string;
    function ToLocaleString: string;

    property DateTime: TDateTime read GetDateTime write SetDateTime;
    property Timestamp: Double read GetTimestamp write SetTimestamp;
  end;

  TJSRegExpImpl = class(TJSObjectImpl, IJSRegExp)
  private
    FPattern: string;
    FFlags: string;
    FRegEx: TRegEx;
    FGlobal: Boolean;
    FIgnoreCase: Boolean;
    FMultiline: Boolean;
    FLastIndex: Integer;

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

    function Test(const Str: string): Boolean;
    function Exec(const Str: string): TJSValue;
    function Match(const Str: string): TJSValue;
    function Replace(const Str: string; const Replacement: string): string;
    function Search(const Str: string): Integer;
    function Split(const Str: string; const Limit: Integer = -1): IJSArray;

    property Pattern: string read GetPattern;
    property Flags: string read GetFlags;
    property Global: Boolean read GetGlobal;
    property IgnoreCase: Boolean read GetIgnoreCase;
    property Multiline: Boolean read GetMultiline;
    property LastIndex: Integer read GetLastIndex write SetLastIndex;
  end;

  TJSObject = TJSObjectImpl;
  TJSFunction = TJSFunctionImpl;
  TJSArray = TJSArrayImpl;
  TJSError = TJSErrorImpl;
  TJSDate = TJSDateImpl;
  TJSRegExp = TJSRegExpImpl;

implementation

uses
  System.Math,
  System.DateUtils,
  System.TimeSpan;

const
  UNDEFINED_STRING = 'undefined';
  NULL_STRING = 'null';
  TRUE_STRING = 'true';
  FALSE_STRING = 'false';
  NAN_STRING = 'NaN';
  INFINITY_STRING = 'Infinity';
  NEGATIVE_INFINITY_STRING = '-Infinity';
  OBJECT_STRING = '[object Object]';
  FUNCTION_STRING = '[object Function]';
  ARRAY_SEPARATOR = ',';
  LENGTH_PROPERTY = 'length';

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
  Result.Value := AValue;
  Result.Writable := True;
  Result.Enumerable := True;
  Result.Configurable := True;
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
        const TrimmedValue = Trim(FStringValue);

        if TrimmedValue = '' then
          Exit(0);

        var NumberValue: Double;
        if TryStrToFloat(TrimmedValue, NumberValue, TFormatSettings.Invariant) then
          Result := NumberValue
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
var
  Arr: IJSArray;
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

        const IntValue = Trunc(FNumberValue);
        if FNumberValue = IntValue then
          Result := IntToStr(IntValue)
        else
          Result := FloatToStr(FNumberValue, TFormatSettings.Invariant);
      end;
    TJSValueType.String_:
      Result := FStringValue;
    TJSValueType.Object_:
      Result := OBJECT_STRING;
    TJSValueType.Function_:
      Result := FUNCTION_STRING;
    TJSValueType.Array_:
      begin
        if Supports(FObjectRef, IJSArray, Arr) then
        begin
          var StringBuilder := TStringBuilder.Create;
          try
            for var Index := 0 to Arr.Length - 1 do
            begin
              if Index > 0 then
                StringBuilder.Append(ARRAY_SEPARATOR);

              const ElementValue = Arr[Index];
              if not ElementValue.IsNullOrUndefined then
                StringBuilder.Append(ElementValue.ToString);
            end;
            Result := StringBuilder.ToString;
          finally
            StringBuilder.Free;
          end;
        end
        else
          Result := '';
      end;
    else
      Result := '';
  end;
end;

function TJSValue.ToObject: IJSObject;
begin
  if IsObject then
    Result := FObjectRef
  else
    Result := nil;
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
  FFrozen := False;
  FSealed := False;
  FExtensible := True;
end;

destructor TJSObjectImpl.Destroy;
begin
  FPrototype := nil;

  for var Pair in FProperties do
  begin
    if Pair.Value.Value.IsFunction then
    begin
      var Func: IJSFunction;
      if Supports(Pair.Value.Value.ToObject, IJSFunction, Func) then
        Func.ClosureScope := nil;
    end;
  end;

  FProperties.Clear;
  FProperties.Free;
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

function TJSObjectImpl.GetProperty(const Name: string): TJSValue;
var
  Descriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
    Exit(Descriptor.Value);

  if FPrototype <> nil then
    Exit(FPrototype.GetProperty(Name));

  Result := TJSValue.CreateUndefined;
end;

procedure TJSObjectImpl.SetProperty(const Name: string; const Value: TJSValue);
var
  Descriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
  begin
    if Descriptor.Writable then
    begin
      Descriptor.Value := Value;
      FProperties[Name] := Descriptor;
    end;
  end
  else
  begin
    if not FExtensible then
      Exit;

    Descriptor := TJSPropertyDescriptor.Create(Value);
    FProperties.Add(Name, Descriptor);
  end;
end;

procedure TJSObjectImpl.SetNonConfigurableProperty(const Name: string; const Value: TJSValue);
var
  Descriptor: TJSPropertyDescriptor;
begin
  if FProperties.TryGetValue(Name, Descriptor) then
  begin
    Descriptor.Value := Value;
    Descriptor.Configurable := False;
    FProperties[Name] := Descriptor;
  end
  else
  begin
    Descriptor := TJSPropertyDescriptor.Create(Value);
    Descriptor.Configurable := False;
    FProperties.Add(Name, Descriptor);
  end;
end;

procedure TJSObjectImpl.DeleteProperty(const Name: string);
begin
  FProperties.Remove(Name);
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
  Result := FProperties.Keys.ToArray;
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
  end;
end;

constructor TJSFunctionImpl.Create;
begin
  inherited Create;
  FIsNative := False;
end;

constructor TJSFunctionImpl.CreateNative(const Name: string; const Func: TNativeFunction);
begin
  inherited Create;
  FName := Name;
  FNativeFunction := Func;
  FIsNative := True;
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
end;

function TJSFunctionImpl.GetParameters: TArray<string>;
begin
  Result := FParameters;
end;

procedure TJSFunctionImpl.SetParameters(const Value: TArray<string>);
begin
  FParameters := Value;
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
end;

destructor TJSArrayImpl.Destroy;
begin
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
  FElements.Free;
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
  while FElements.Count <= Index do
  begin
    FElements.Add(TJSValue.CreateUndefined);
  end;

  FElements[Index] := Value;
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
    FElements.Delete(FElements.Count - 1);
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

const
  UNIX_EPOCH: TDateTime = 25569.0;

constructor TJSDateImpl.Create;
begin
  inherited Create;
  FDateTime := Now;
  UpdateFromDateTime;
end;

constructor TJSDateImpl.Create(const Timestamp: Double);
begin
  inherited Create;
  FTimestamp := Timestamp;
  UpdateFromTimestamp;
end;

constructor TJSDateImpl.Create(const Year, Month, Day, Hours, Minutes, Seconds, Milliseconds: Integer);
begin
  inherited Create;
  FDateTime := EncodeDateTime(Year, Month + 1, Day, Hours, Minutes, Seconds, Milliseconds);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.UpdateFromTimestamp;
begin
  const UTCDateTime = UNIX_EPOCH + (FTimestamp / 86400000.0);
  FDateTime := TTimeZone.Local.ToLocalTime(UTCDateTime);
end;

procedure TJSDateImpl.UpdateFromDateTime;
begin
  FTimestamp := (FDateTime - UNIX_EPOCH) * 86400000.0;
end;

function TJSDateImpl.GetDateTime: TDateTime;
begin
  Result := FDateTime;
end;

procedure TJSDateImpl.SetDateTime(const Value: TDateTime);
begin
  FDateTime := Value;
  UpdateFromDateTime;
end;

function TJSDateImpl.GetTimestamp: Double;
begin
  Result := FTimestamp;
end;

procedure TJSDateImpl.SetTimestamp(const Value: Double);
begin
  FTimestamp := Value;
  UpdateFromTimestamp;
end;

function TJSDateImpl.GetTime: Double;
begin
  Result := FTimestamp;
end;

function TJSDateImpl.GetFullYear: Integer;
begin
  Result := YearOf(FDateTime);
end;

function TJSDateImpl.GetMonth: Integer;
begin
  Result := MonthOf(FDateTime) - 1;
end;

function TJSDateImpl.GetDate: Integer;
begin
  Result := DayOf(FDateTime);
end;

function TJSDateImpl.GetDay: Integer;
begin
  Result := DayOfTheWeek(FDateTime) mod 7;
end;

function TJSDateImpl.GetHours: Integer;
begin
  Result := HourOf(FDateTime);
end;

function TJSDateImpl.GetMinutes: Integer;
begin
  Result := MinuteOf(FDateTime);
end;

function TJSDateImpl.GetSeconds: Integer;
begin
  Result := SecondOf(FDateTime);
end;

function TJSDateImpl.GetMilliseconds: Integer;
begin
  Result := MilliSecondOf(FDateTime);
end;

function TJSDateImpl.GetUTCFullYear: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := YearOf(UTCTime);
end;

function TJSDateImpl.GetUTCMonth: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := MonthOf(UTCTime) - 1;
end;

function TJSDateImpl.GetUTCDate: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := DayOf(UTCTime);
end;

function TJSDateImpl.GetUTCDay: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := DayOfTheWeek(UTCTime) mod 7;
end;

function TJSDateImpl.GetUTCHours: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := HourOf(UTCTime);
end;

function TJSDateImpl.GetUTCMinutes: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := MinuteOf(UTCTime);
end;

function TJSDateImpl.GetUTCSeconds: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := SecondOf(UTCTime);
end;

function TJSDateImpl.GetUTCMilliseconds: Integer;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := MilliSecondOf(UTCTime);
end;

function TJSDateImpl.GetTimezoneOffset: Integer;
begin
  const Offset = TTimeZone.Local.GetUtcOffset(FDateTime);
  Result := -Round(Offset.TotalMinutes);
end;

procedure TJSDateImpl.SetTime(const Value: Double);
begin
  FTimestamp := Value;
  UpdateFromTimestamp;
end;

procedure TJSDateImpl.SetFullYear(const Value: Integer);
begin
  FDateTime := RecodeYear(FDateTime, Value);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetMonth(const Value: Integer);
begin
  FDateTime := RecodeMonth(FDateTime, Value + 1);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetDate(const Value: Integer);
begin
  FDateTime := RecodeDay(FDateTime, Value);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetHours(const Value: Integer);
begin
  FDateTime := RecodeHour(FDateTime, Value);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetMinutes(const Value: Integer);
begin
  FDateTime := RecodeMinute(FDateTime, Value);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetSeconds(const Value: Integer);
begin
  FDateTime := RecodeSecond(FDateTime, Value);
  UpdateFromDateTime;
end;

procedure TJSDateImpl.SetMilliseconds(const Value: Integer);
begin
  FDateTime := RecodeMilliSecond(FDateTime, Value);
  UpdateFromDateTime;
end;

function TJSDateImpl.ToISOString: string;
begin
  const UTCTime = TTimeZone.Local.ToUniversalTime(FDateTime);
  Result := FormatDateTime('yyyy"-"mm"-"dd"T"hh":"nn":"ss"."zzz"Z"', UTCTime);
end;

function TJSDateImpl.ToDateString: string;
const
  DayNames: array[1..7] of string = ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun');
  MonthNames: array[1..12] of string = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
begin
  const DayIdx = DayOfTheWeek(FDateTime);
  const MonthIdx = MonthOf(FDateTime);

  Result := DayNames[DayIdx] + ' ' + MonthNames[MonthIdx] + ' ' +
            Format('%.2d', [DayOf(FDateTime)]) + ' ' + IntToStr(YearOf(FDateTime));
end;

function TJSDateImpl.ToTimeString: string;
begin
  Result := FormatDateTime('hh":"nn":"ss', FDateTime);
end;

function TJSDateImpl.ToLocaleString: string;
begin
  Result := DateTimeToStr(FDateTime);
end;

constructor TJSRegExpImpl.Create(const Pattern: string; const Flags: string);
begin
  inherited Create;
  FPattern := Pattern;
  FFlags := Flags;
  FGlobal := (Pos('g', Flags) > 0);
  FIgnoreCase := (Pos('i', Flags) > 0);
  FMultiline := (Pos('m', Flags) > 0);
  FLastIndex := 0;

  var Options: TRegExOptions := [];

  if FIgnoreCase then
    Options := Options + [roIgnoreCase];

  if FMultiline then
    Options := Options + [roMultiLine];

  FRegEx := TRegEx.Create(Pattern, Options);

  SetProperty(PROP_SOURCE, TJSValue.CreateString(Pattern));
  SetProperty(PROP_FLAGS, TJSValue.CreateString(Flags));
  SetProperty(PROP_GLOBAL, TJSValue.CreateBoolean(FGlobal));
  SetProperty(PROP_IGNORE_CASE, TJSValue.CreateBoolean(FIgnoreCase));
  SetProperty(PROP_MULTILINE, TJSValue.CreateBoolean(FMultiline));
  SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(0));
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
  Result := FLastIndex;
end;

procedure TJSRegExpImpl.SetLastIndex(const Value: Integer);
begin
  FLastIndex := Value;
end;

function TJSRegExpImpl.Test(const Str: string): Boolean;
begin
  if FGlobal then
  begin
    const Match = FRegEx.Match(Str, FLastIndex + 1);
    Result := Match.Success;

    if Result then
      FLastIndex := Match.Index + Match.Length - 1
    else
      FLastIndex := 0;

    SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(FLastIndex));
  end
  else
    Result := FRegEx.IsMatch(Str);
end;

function TJSRegExpImpl.Exec(const Str: string): TJSValue;
var
  Match: TMatch;
begin
  if FGlobal then
  begin
    Match := FRegEx.Match(Str, FLastIndex + 1);

    if Match.Success then
    begin
      FLastIndex := Match.Index + Match.Length - 1;
      SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(FLastIndex));
    end
    else
    begin
      FLastIndex := 0;
      SetProperty(PROP_LAST_INDEX, TJSValue.CreateNumber(0));
      Result := TJSValue.CreateNull;
      Exit;
    end;
  end
  else
  begin
    Match := FRegEx.Match(Str);

    if not Match.Success then
    begin
      Result := TJSValue.CreateNull;
      Exit;
    end;
  end;

  const ResultArr: IJSArray = TJSArrayImpl.Create;
  ResultArr.Push(TJSValue.CreateString(Match.Value));

  for var GroupIdx := 1 to Match.Groups.Count - 1 do
  begin
    const Group = Match.Groups[GroupIdx];

    if Group.Success then
      ResultArr.Push(TJSValue.CreateString(Group.Value))
    else
      ResultArr.Push(TJSValue.CreateUndefined);
  end;

  ResultArr.SetProperty(PROP_INDEX, TJSValue.CreateNumber(Match.Index - 1));
  ResultArr.SetProperty(PROP_INPUT, TJSValue.CreateString(Str));

  Result := TJSValue.CreateObject(ResultArr);
end;

function TJSRegExpImpl.Match(const Str: string): TJSValue;
begin
  if not FGlobal then
  begin
    Result := Exec(Str);
    Exit;
  end;

  const Matches = FRegEx.Matches(Str);

  if Matches.Count = 0 then
  begin
    Result := TJSValue.CreateNull;
    Exit;
  end;

  const ResultArr: IJSArray = TJSArrayImpl.Create;

  for var MatchItem in Matches do
  begin
    ResultArr.Push(TJSValue.CreateString(MatchItem.Value));
  end;

  Result := TJSValue.CreateObject(ResultArr);
end;

function TJSRegExpImpl.Replace(const Str: string; const Replacement: string): string;
begin
  if FGlobal then
    Result := FRegEx.Replace(Str, Replacement)
  else
    Result := FRegEx.Replace(Str, Replacement, 1);
end;

function TJSRegExpImpl.Search(const Str: string): Integer;
begin
  const Match = FRegEx.Match(Str);

  if Match.Success then
    Result := Match.Index - 1
  else
    Result := -1;
end;

function TJSRegExpImpl.Split(const Str: string; const Limit: Integer): IJSArray;
begin
  Result := TJSArrayImpl.Create;

  const Matches = FRegEx.Matches(Str);

  if Matches.Count = 0 then
  begin
    Result.Push(TJSValue.CreateString(Str));
    Exit;
  end;

  var LastEnd := 1;
  var Count := 0;

  for var MatchItem in Matches do
  begin
    if (Limit >= 0) and (Count >= Limit) then
      Break;

    const Part = Copy(Str, LastEnd, MatchItem.Index - LastEnd);
    Result.Push(TJSValue.CreateString(Part));
    Inc(Count);

    LastEnd := MatchItem.Index + MatchItem.Length;
  end;

  if (Limit < 0) or (Count < Limit) then
  begin
    const Remainder = Copy(Str, LastEnd, Length(Str) - LastEnd + 1);
    Result.Push(TJSValue.CreateString(Remainder));
  end;
end;

end.
