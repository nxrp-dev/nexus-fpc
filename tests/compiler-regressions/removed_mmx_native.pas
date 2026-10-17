// Copyright (c) 2026 Kevin Collins.
// SPDX-License-Identifier: MPL-2.0-no-copyleft-exception
program RemovedMMXNative;
{$mode objfpc}
type
  TWords = array[0..3] of Word;

operator +(const ALeft, ARight: TWords) AResult: TWords;
var
  lIndex: LongInt;
begin
  for lIndex:=0 to High(AResult) do
    AResult[lIndex]:=ALeft[lIndex]+ARight[lIndex];
end;

{$if defined(CPUI386) or defined(CPUX86_64)}
{$asmmode intel}
procedure ExerciseX86Assembly; assembler; nostackframe;
asm
  pxor mm0,mm0
  paddw mm0,mm0
  emms
  pxor xmm0,xmm0
  paddw xmm0,xmm0
end;
{$endif}

var
  lLeft, lRight, lResult, lCopy: TWords;
  lIndex: LongInt;
begin
  for lIndex:=0 to High(lLeft) do
    begin
      lLeft[lIndex]:=lIndex+1;
      lRight[lIndex]:=lIndex+2;
    end;
  lResult:=lLeft+lRight;
  lCopy:=lResult;
  for lIndex:=0 to High(lCopy) do
    if lCopy[lIndex]<>2*lIndex+3 then
      Halt(1);
  {$if defined(CPUI386) or defined(CPUX86_64)}
  ExerciseX86Assembly;
  {$endif}
  WriteLn('PASS array operators, copies and retained assembly');
end.
