program tthreadvarpointer;
{$mode objfpc}
uses HeapTrc;
threadvar
  Value: LongInt;
  Values: array[0..31] of LongInt;
begin
  GlobalSkipIfNoLeaks:=true;
  Value:=7;
  Values[31]:=19;
  CheckPointer(@Value);
  CheckPointer(@Values[0]);
  CheckPointer(@Values[31]);
  if (Value<>7) or (Values[31]<>19) then Halt(1);
end.
