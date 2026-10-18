{ %NORUN }

program tw24867;

{$MODE DELPHi}{$H+}
{$APPTYPE CONSOLE}

uses
  Generics.Collections;

var
  d: TDictionary<string, string>; // ok
begin
  d := TDictionary<string, string>.Create; // Error: This type can't be a generic
end.

