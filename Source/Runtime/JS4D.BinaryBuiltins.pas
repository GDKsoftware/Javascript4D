unit JS4D.BinaryBuiltins;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Interpreter,
  JS4D.BinarySupport,
  JS4D.ArrayBufferBuiltins,
  JS4D.DataViewBuiltins,
  JS4D.TypedArrayBuiltins,
  JS4D.TypedArrayMethods;

type
  // ArrayBuffer, DataView and the typed arrays.
  TJSBinaryBuiltins = class
  private
    FSupport: TJSBinarySupport;
    FBuffers: TJSArrayBufferBuiltins;
    FDataViews: TJSDataViewBuiltins;
    FTypedArrays: TJSTypedArrayBuiltins;
    FTypedArrayMethods: TJSTypedArrayMethods;

  public
    constructor Create(const Interpreter: TJSInterpreter);
    destructor Destroy; override;

    procedure Register;
  end;

implementation

constructor TJSBinaryBuiltins.Create(const Interpreter: TJSInterpreter);
begin
  inherited Create;

  FSupport := TJSBinarySupport.Create(Interpreter);
  FBuffers := TJSArrayBufferBuiltins.Create(FSupport);
  FDataViews := TJSDataViewBuiltins.Create(FSupport);
  FTypedArrays := TJSTypedArrayBuiltins.Create(FSupport, FBuffers);
  FTypedArrayMethods := TJSTypedArrayMethods.Create(FTypedArrays);
end;

destructor TJSBinaryBuiltins.Destroy;
begin
  FTypedArrayMethods.Free;
  FTypedArrays.Free;
  FDataViews.Free;
  FBuffers.Free;
  FSupport.Free;
  inherited;
end;

procedure TJSBinaryBuiltins.Register;
begin
  FBuffers.Register;
  FDataViews.Register;
  FTypedArrays.Register;
  FTypedArrayMethods.Register;
end;

end.
