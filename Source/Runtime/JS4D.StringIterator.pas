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

  // The object returned by String.prototype[Symbol.iterator]. It yields one code point per step, so a
  // surrogate pair comes out as one string of two code units.
  TJSStringIterator = class(TJSObjectImpl, IJSStringIterator)
  private
    const
      HIGH_SURROGATE_FIRST = $D800;
      HIGH_SURROGATE_LAST = $DBFF;
      LOW_SURROGATE_FIRST = $DC00;
      LOW_SURROGATE_LAST = $DFFF;

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
  if FPosition > Length(FText) then
    Exit(TJSIteratorResults.CreateResult(FObjectPrototype, TJSValue.CreateUndefined, True));

  const CodeUnitCount = CodePointLength(FText, FPosition);
  const CodePoint = TJSValue.CreateString(Copy(FText, FPosition, CodeUnitCount));
  Inc(FPosition, CodeUnitCount);

  Result := TJSIteratorResults.CreateResult(FObjectPrototype, CodePoint, False);
end;

end.
