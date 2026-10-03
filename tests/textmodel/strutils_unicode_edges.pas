program StrUtilsUnicodeEdges;

{$mode objfpc}

uses
  StrUtils;

var
  A, B, C, S, Original, Pair, Expected: UnicodeString;
  Args: TUnicodeStringArray;

begin
  A := UnicodeString(#$0100);
  B := UnicodeString(#$0102);
  C := UnicodeString(#$0104);

  S := A + B + A;
  if RPosEx(UnicodeChar(#$0104), S, 3) <> 0 then Halt(1);
  if RPosEx(UnicodeChar(#$0100), S, 3) <> 3 then Halt(2);
  if RPosEx(UnicodeChar(#$0100), S, 2) <> 1 then Halt(3);
  if RPosEx(UnicodeChar(#$0100), S, 4) <> 0 then Halt(4);
  if RPos(UnicodeChar(#$0104), S) <> 0 then Halt(5);
  if RPosEx(A + B, S, 3) <> 1 then Halt(6);

  S := UnicodeString(' ') + A + B + UnicodeString(' ');
  Original := S;
  RemovePadChars(S, [' ']);
  if S <> A + B then Halt(7);
  if Original <> UnicodeString(' ') + A + B + UnicodeString(' ') then Halt(8);

  Pair := UnicodeString(#$D83D) + UnicodeString(#$DE00);
  S := A + Pair + B;
  Expected := B + Pair + A;
  if UnicodeReverseString(S) <> Expected then Halt(9);
  if UnicodeReverseString('') <> '' then Halt(10);

  if not AnsiStartsStr(A, A + B) then Halt(11);
  if not AnsiEndsStr(B, A + B) then Halt(12);
  if AnsiStartsStr(C, A + B) then Halt(13);
  if AnsiEndsStr(C, A + B) then Halt(14);
  if not SecureCompare(A + B, A + B) then Halt(15);
  if SecureCompare(A, B) then Halt(16);

  Args := SplitCommandLine(A + UnicodeString(' ') + B);
  if (Length(Args) <> 2) or (Args[0] <> A) or (Args[1] <> B) then Halt(17);
end.
