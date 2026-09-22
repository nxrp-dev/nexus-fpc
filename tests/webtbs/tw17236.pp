{ %target=linux,darwin}
{ %cpu=x86_64,ia64,alpha}
{ %opt=-Xa }

{ windows does not support statics > 2GB }
var
  i : longint;
  a : array[0..1500000000] of longint;
begin
  writeln(a[i]);
end.
