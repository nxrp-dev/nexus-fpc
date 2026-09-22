{ %fail }

{ %target=darwin }
{ %cpu=x86_64,arm,aarch64}

{$mode objfpc}
{$modeswitch objectivec1}

type
  tc = objcclass(NSObject)
    procedure test(s: ansistring); message 'test:';
  end;

procedure tc.test(s: ansistring);
  begin
  end;

begin
end.
