{%FAIL}
{$mode delphi}
procedure Test<T>(Value: T);
var
  Items: set of Byte;
begin
  Items := [Value];
end;
begin
  Test<TObject>(nil);
end.
