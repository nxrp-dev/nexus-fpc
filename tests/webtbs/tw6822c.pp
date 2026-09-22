{ %target=win64,darwin,linux,freebsd,solaris,android,haiku}
uses
  SysUtils;

var
  t: text;
begin
  { see uw6822a.pp }
  assign(t,'uw6822a.txt');
{$i-}
  reset(t);
{$i+}
  if ioresult<>0 then
    halt(1);
  close(t);
  erase(t);
end.
