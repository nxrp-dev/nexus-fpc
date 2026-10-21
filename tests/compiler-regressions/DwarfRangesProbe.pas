// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program DwarfRangesProbe;
{$mode objfpc}{$H+}
uses utDwarfRangesFixture;
begin
  WriteLn(FirstValue + SecondValue);
  {$ifdef KEEP_UNUSED_RANGE}
  WriteLn(UnusedValue);
  {$endif}
end.
