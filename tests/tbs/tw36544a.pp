{ %norun }
{ %target=win64,darwin,linux,android}
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
