program StrUtilsUnicode;

{$mode objfpc}

uses StrUtils;

var
  A, B, LowerA: UnicodeString;

begin
  A := UnicodeString(#$0100);
  B := UnicodeString(#$0102);
  LowerA := UnicodeString(#$0101);
  if AnsiContainsStr(B, A) then Halt(1);
  if not AnsiContainsStr(A + B, B) then Halt(2);
  if AnsiEndsText(A, B) then Halt(3);
  if not AnsiEndsText(LowerA, A) then Halt(4);
end.
