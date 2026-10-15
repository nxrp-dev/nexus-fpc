program NXCOperatorsDefault;

var
  lInteger: LongInt;
  lReal: Double;
begin
  lInteger := 12;
  lInteger += 6;
  lInteger -= 2;
  lInteger *= 3;
  lReal := lInteger;
  lReal /= 4;
  if (lInteger <> 48) or (lReal <> 12) then
    Halt(1);
end.
