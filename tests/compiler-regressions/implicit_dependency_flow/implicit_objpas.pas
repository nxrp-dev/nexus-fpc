{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program implicit_objpas;
{$mode objfpc}
type TProbe = class
  Value: LongInt;
end;
var Probe: TProbe;
begin
  Probe := TProbe.Create;
  Probe.Value := 42;
  if Probe.Value <> 42 then Halt(1);
  Probe.Free;
  WriteLn('PASS language dependency');
end.
