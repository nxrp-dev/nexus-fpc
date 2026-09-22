{ %target=win64,darwin,linux,freebsd,solaris,android,haiku}
uses
  SysUtils;

var
  t: text;
begin
  { see tw9089b.pp }
  assign(t,'tw9089b.txt');
{$i-}
  reset(t);
{$i+}
  if ioresult<>0 then
    halt(1);
  close(t);
  erase(t);
  writeln('ok');
end.
