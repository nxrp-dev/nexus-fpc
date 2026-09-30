program NXAssemblerSample;

{$mode objfpc}{$H+}

uses NXAssemblerProbe;

begin
  if RunProbe <> 42 then
    Halt(1);
  WriteLn('Nexus assembler sample: OK; pointer bytes=', SizeOf(Pointer));
end.
