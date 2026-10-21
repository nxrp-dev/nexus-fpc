{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_cycle_a;
interface
function CycleValue: LongInt;
implementation
uses implicit_cycle_b;
function CycleValue: LongInt;
begin
  CycleValue := OtherValue;
end;
initialization
  if CycleValue <> 42 then Halt(1);
  WriteLn('cycle A initialized');
end.
