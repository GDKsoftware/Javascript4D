unit JS4D.AsyncHost;

{$SCOPEDENUMS ON}

interface

uses
  JS4D.Types,
  JS4D.GeneratorObjects;

type
  TJSAsyncHost = class abstract
  public
    function CreateResult: IJSObject; virtual; abstract;
    procedure Start(const ResultPromise: IJSObject; const Body: IJSGenerator); virtual; abstract;
    procedure Reject(const ResultPromise: IJSObject; const Reason: TJSValue); virtual; abstract;
  end;

implementation

end.
