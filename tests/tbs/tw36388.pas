{ %NORUN }

{$mode objfpc}

program tw36388;
uses
  SysUtils, Classes;

generic function CopyList<T: TList> (source: T): T;
begin
 // Internal error 200204175
  result := T.Create;
end;

begin
end.
