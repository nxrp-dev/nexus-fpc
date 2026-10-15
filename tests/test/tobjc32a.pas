{ %fail }

{ %target=darwin }
{ %cpu=x86_64,aarch64}

{$mode objfpc}
{$modeswitch objectivec1}

type
  tc = objcclass(NSObject)
    function test: ansistring; message 'test';
  end;

procedure tc.test: ansistring;
  begin
  end;

begin
end.
