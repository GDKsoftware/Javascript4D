unit JS4D.ObjectKeys;

{$SCOPEDENUMS ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  JS4D.Types,
  JS4D.ObjectOperations;

type
  TJSObjectKeys = class
  public
    class function Enumerable(const Target: IJSObject): TArray<string>; static;
    class function All(const Target: IJSObject): TArray<string>; static;
  end;

implementation

class function TJSObjectKeys.All(const Target: IJSObject): TArray<string>;
begin
  Result := TJSObjectOperations.OwnKeys(Target);
end;

class function TJSObjectKeys.Enumerable(const Target: IJSObject): TArray<string>;
begin
  const Keys = TList<string>.Create;
  try
    for var Name in Target.GetOwnPropertyNames do
    begin
      const Descriptor = Target.GetOwnPropertyDescriptor(Name);
      if Descriptor.Enumerable then
        Keys.Add(Name);
    end;

    Result := Keys.ToArray;
  finally
    Keys.Free;
  end;
end;

end.
