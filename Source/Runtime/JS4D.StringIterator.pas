unit JS4D.StringIterator;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Math,
  JS4D.Types,
  JS4D.IteratorProtocol;

type
  IJSStringIterator = interface
    ['{8A3F6C21-4B7D-4E95-9D02-C1E5A7B3F640}']
    function NextResult: TJSValue;
  end;

  TJSStringIterator = class(TJSObjectImpl, IJSStringIterator)
  private
    var
      FText: string;
      FObjectPrototype: IJSObject;
      FPosition: Integer;

  public
    class function CodePointLength(const Text: string; const Position: Integer): Integer; static;

    constructor Create(const Text: string; const ObjectPrototype: IJSObject);

    function NextResult: TJSValue;
  end;

implementation

uses
  JS4D.Utf16;

class function TJSStringIterator.CodePointLength(const Text: string; const Position: Integer): Integer;
begin
  const HasLowSurrogateNext = (Position < Length(Text)) and
                              InRange(Ord(Text[Position + 1]), LOW_SURROGATE_FIRST, LOW_SURROGATE_LAST);
  const IsSurrogatePair = InRange(Ord(Text[Position]), HIGH_SURROGATE_FIRST, HIGH_SURROGATE_LAST) and
                          HasLowSurrogateNext;

  Result := 1 + Ord(IsSurrogatePair);
end;

constructor TJSStringIterator.Create(const Text: string; const ObjectPrototype: IJSObject);
begin
  inherited Create;

  FText := Text;
  FObjectPrototype := ObjectPrototype;
  FPosition := 1;
end;

function TJSStringIterator.NextResult: TJSValue;
begin
  const IsExhausted = (FPosition > Length(FText));
  if IsExhausted then
  begin
    Result := TJSIteratorResults.CreateResult(FObjectPrototype, TJSValue.CreateUndefined, True);
    Exit;
  end;

  const CodeUnitCount = CodePointLength(FText, FPosition);
  const CodePoint = TJSValue.CreateString(Copy(FText, FPosition, CodeUnitCount));
  Inc(FPosition, CodeUnitCount);

  Result := TJSIteratorResults.CreateResult(FObjectPrototype, CodePoint, False);
end;

end.
