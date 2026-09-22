{ %fail }
{ %target=darwin }
{ %cpu=x86_64,aarch64}

{ Written by Jonas Maebe in 2009, released into the public domain }

{$modeswitch objectivec1}

type
  ta = objcclass external
    { no constructors in Objective-C }
    constructor create; message 'create';
  end;

begin
end.
