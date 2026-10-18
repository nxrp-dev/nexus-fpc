{ Copyright (c) 2026 Kevin Collins.
  SPDX-License-Identifier: MPL-2.0-no-copyleft-exception }
program implicit_heaptrc_source;
{$mode objfpc}{$H+}
var
  lMemory: Pointer;
begin
  GetMem(lMemory, 73);
  FillChar(lMemory^, 73, 42);
  FreeMem(lMemory);
  HeapTrc.CheckHeap;
  WriteLn('PASS implicit HeapTrc source compilation');
end.
