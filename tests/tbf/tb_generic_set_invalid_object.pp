{%FAIL}
{$mode delphi}
procedure Test<T>(AElement: T);
type
  TItems = set of T;
begin
end;
begin
  Test<TObject>(nil);
end.
