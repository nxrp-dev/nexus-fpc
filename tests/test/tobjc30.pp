{ %target=darwin }
{ %cpu=x86_64,arm,aarch64}

{ Written by Jonas Maebe in 2009, released into the Public Domain }

{$mode objfpc}
{$modeswitch objectivec1}

var
  a: id;
begin
  a:=NSObject.alloc.init;
  if a.conformsToProtocol_(objcprotocol(NSObjectProtocol)) then
    writeln('ok conformsToProtocol')
  else
    halt(1);
end.
