{ %target=darwin }
{ %cpu=x86_64,aarch64}

{ Written by Jonas Maebe in 2010, released into the public domain }

{$mode objfpc}
{$modeswitch objectivec1}

type
  NSArray = objcclass external;

var
  a: NSArray;
begin
end.
