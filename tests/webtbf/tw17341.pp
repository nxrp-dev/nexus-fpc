{ %fail }
{ %target=darwin }
{ %cpu=x86_64,arm}

{$mode objfpc}
{$modeswitch objectivec1}

type
  tmyprotocol = objcprotocol;
  tmyclass = objcclass(NSObject,tmyprotocol)
  end;

  tmyprotocol = objcprotocol
  end;

begin
end.
