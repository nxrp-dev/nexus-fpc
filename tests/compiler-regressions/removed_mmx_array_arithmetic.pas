{ %CPU=i386 }
{ %fail }
// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program RemovedMMXArrayArithmetic;
{$mode objfpc}
{$MMX ON}
type
  TWords = array[0..3] of Word;
var
  lLeft, lRight, lResult: TWords;
  lIndex: LongInt;
begin
  for lIndex:=0 to High(lLeft) do
    begin
      lLeft[lIndex]:=lIndex+1;
      lRight[lIndex]:=lIndex+2;
    end;
  lResult:=lLeft+lRight;
  WriteLn(lResult[0]);
end.
