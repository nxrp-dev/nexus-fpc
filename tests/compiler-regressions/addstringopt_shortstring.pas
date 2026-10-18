program AddStringOptShortString;
{$mode objfpc}{$H-}
var
  lText: ShortString;
  lChar, lOther: Char;
  lIndex: Integer;
begin
  lChar := 'b';
  lOther := 'd';
  lText := 'a';
  lText := lText + lChar;
  if lText <> 'ab' then
    Halt(1);
  lText := lText + 'cd';
  if lText <> 'abcd' then
    Halt(2);
  lText := lChar + lOther;
  if lText <> 'bd' then
    Halt(3);
  lText := '';
  for lIndex := 1 to 260 do
    lText := lText + lChar;
  if Length(lText) <> 255 then
    Halt(4);
  for lIndex := 1 to Length(lText) do
    if lText[lIndex] <> lChar then
      Halt(5);
  WriteLn('PASS shortstring char/constant/char-pair/truncation cases');
end.
