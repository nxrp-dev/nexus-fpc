{ %target=win64,darwin,linux,android}
{ %needlibrary }
{ %norun }

library tw6586a;
{$H+}{$MODE OBJFPC}

uses cmem;

procedure ExportTest1(input: longint); stdcall;
begin
 input:= 5;
end;

exports
  ExportTest1;

begin
end.

