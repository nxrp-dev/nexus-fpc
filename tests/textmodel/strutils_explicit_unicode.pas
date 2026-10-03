program StrUtilsExplicitUnicode;

{$mode objfpc}

uses
  StrUtils, Types;

var
  UpperA, LowerA, B, Text: UnicodeString;
  Parts: TUnicodeStringDynArray;

begin
  UpperA := UnicodeString(#$0100);
  LowerA := UnicodeString(#$0101);
  B := UnicodeString(#$0102);
  Text := UpperA + B;

  if not UnicodeStartsText(LowerA, Text) then Halt(1);
  if not UnicodeEndsText(B, Text) then Halt(2);
  if not UnicodeContainsText(Text, LowerA) then Halt(3);
  if UnicodeContainsText(Text, UnicodeString(#$0104)) then Halt(4);
  if not UnicodeStartsText('', Text) then Halt(5);
  if not UnicodeEndsText('', Text) then Halt(6);

  if not UnicodeStartsStr(UpperA, Text) then Halt(7);
  if UnicodeStartsStr(LowerA, Text) then Halt(8);
  if not UnicodeEndsStr(B, Text) then Halt(9);
  if not UnicodeContainsStr(Text, B) then Halt(10);
  if UnicodeContainsStr(Text, LowerA) then Halt(11);

  if UnicodeReplaceText(UpperA + LowerA, LowerA, B) <> B + B then Halt(12);
  if UnicodeReplaceStr(UpperA + LowerA, LowerA, B) <> UpperA + B then Halt(13);

  if UnicodeDupeString(Text, 3) <> Text + Text + Text then Halt(14);
  if UnicodeDupeString(Text, 0) <> '' then Halt(15);
  if UnicodeReverseString(Text) <> B + UpperA then Halt(16);
  if UnicodeStuffString(Text, 2, 1, LowerA) <> UpperA + LowerA then Halt(17);

  Parts := UnicodeSplitString(UpperA + B + LowerA, B);
  if (Length(Parts) <> 2) or (Parts[0] <> UpperA) or
    (Parts[1] <> LowerA) then Halt(18);
end.
