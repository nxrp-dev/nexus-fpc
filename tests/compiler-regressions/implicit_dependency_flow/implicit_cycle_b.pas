{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_cycle_b;
interface
uses implicit_cycle_a;
function OtherValue: LongInt;
implementation
function OtherValue: LongInt;
begin
  OtherValue := 42;
end;
initialization
  WriteLn('cycle B initialized');
end.
