library NXAssemblerLibrary;

{$mode objfpc}{$H+}

uses NXAssemblerProbe;

function NexusAssemblerTest: LongInt; cdecl;
begin
  Result := RunProbe;
end;

exports NexusAssemblerTest;

begin
end.
