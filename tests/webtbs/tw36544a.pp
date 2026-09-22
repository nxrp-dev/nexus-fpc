{ %norun }
{ %target=win64,wince,darwin,linux,freebsd,solaris,aix,android,haiku}
{ %needlibrary }
{$mode objfpc}
library tw36544a;

uses
  uw36544;

procedure library_procedure;
begin
  writeln('Not ok');
end;

exports library_procedure;

begin
end.
