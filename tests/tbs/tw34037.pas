program project1;
{$mode objfpc}{$H+}

uses
  Classes, Generics.Collections;

type
  TBaseClass = class (TObject)
  end;

  generic TObjectListEx<T: TBaseClass> = class (specialize TObjectList<T>)
    function GetItemByID(AID: Integer): T;
  end;

function TObjectListEx.GetItemByID(AID: Integer): T;
begin
  Result:=nil; //T(nil);
end;

begin
end.
