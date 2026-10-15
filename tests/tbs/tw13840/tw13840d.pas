{ %interactive }

{ perform the following steps:

rm tw13840d.nxu
fpc tw13840d
touch tw13840a.pas
fpc tw13840b -dchanged
fpc tw13840d -dchanged

In the last step, unit c also has to be recompiled. If it isn't, a linker
error will occur.

}

{$mode objfpc}

uses
  tw13840c;

var
  c: tc;
begin
  c:=tc.create;
  c.test;
  c.mymy(c);
  c.free;
end.
