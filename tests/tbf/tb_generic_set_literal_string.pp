{%FAIL}
{$mode objfpc}
generic procedure Test<T>(Value: T);
var
  Items: set of Byte;
begin
  Items := [Value];
end;
begin
  specialize Test<AnsiString>('invalid');
end.
