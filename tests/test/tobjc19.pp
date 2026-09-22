{ %fail }
{ %target=darwin }
{ %cpu=x86_64,aarch64}

{ Written by Jonas Maebe in 2009, released into the public domain }

{$modeswitch objectivec1}

type
  ta = objcclass
    { should give an error because the selector is invalid }
    procedure test(l:longint); message 'test:l';
  end;

begin
end.
