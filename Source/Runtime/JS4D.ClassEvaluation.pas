unit JS4D.ClassEvaluation;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  JS4D.Types,
  JS4D.AST;

type
  TJSClassEvaluation = class abstract
  public
    procedure BindHomeObject(const Func: IJSFunction; const Home: IJSObject); virtual; abstract;
    function VisitClassExpression(const Node: TJSClassExpression;
                                  const InferredName: string): TJSValue; virtual; abstract;
  end;

implementation

end.
