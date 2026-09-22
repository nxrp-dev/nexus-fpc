{ %norun }
{ %needlibrary }
{ %target=win64,wince,darwin,linux,freebsd,solaris,aix,android,haiku}

library tw16949a;

{$mode objfpc}{$H+}

function foo: LongInt; cdecl;
var
 x: LongInt = 12345;
begin
 Result := x;
end;

exports
 foo;

begin
end.
