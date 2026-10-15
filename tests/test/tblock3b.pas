{ %FAIL }
{ %target=darwin,iphonesim}

program tblock3b;

{$mode objfpc}
{$modeswitch cblocks}

type
  {$calling stdcall}
  tblock = reference to procedure; cblock;

begin

end.
