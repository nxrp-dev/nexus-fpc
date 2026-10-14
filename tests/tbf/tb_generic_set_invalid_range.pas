{%FAIL}
{$mode delphi}
type
  TTooWide = 0..256;
procedure Test<T>(AElement: T);
type
  TItems = set of T;
begin
end;
begin
  Test<TTooWide>(1);
end.
