{%FAIL}
{$mode objfpc}
{$interfaces corba}
type
  ITest = interface ['MYINTERFACE'] end;
var
  Value: LongInt;
begin
  Value := ITest;
end.
