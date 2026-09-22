{ %fail }

{ %target=darwin }
{ %cpu=x86_64,arm,aarch64}

{$mode objfpc}
{$modeswitch objectivec1}

type
  tc = objcclass(NSObject)
    s: ansistring;
  end;

begin
end.
