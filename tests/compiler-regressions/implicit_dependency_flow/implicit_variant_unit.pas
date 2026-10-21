{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
unit implicit_variant_unit;
{$mode objfpc}
interface
function VariantValue: LongInt;
implementation
function VariantValue: LongInt;
var
  lValue: Variant;
begin
  lValue := 3;
  lValue := lValue + 4;
  Result := LongInt(lValue);
end;
initialization
  if VariantValue <> 7 then Halt(1);
  WriteLn('PASS unit late dependency');
end.
