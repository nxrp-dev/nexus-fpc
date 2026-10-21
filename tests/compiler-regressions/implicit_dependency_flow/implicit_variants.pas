{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program implicit_variants;
{$mode objfpc}
var Value: Variant;
begin
  Value := 3;
  Value := Value + 4;
  if LongInt(Value) <> 7 then Halt(1);
  WriteLn('PASS late dependency');
end.
