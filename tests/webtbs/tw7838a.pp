{ %norun }
{ %needlibrary }
{ %target=win64,linux,android,haiku}

library tw7838a;

{$mode objfpc} {$h+}

uses uw7838a;

function dllf: longint;
begin
  result:=exetest;
  if (result<>aa) then
    halt(1);
end;

exports dllf;

begin

end.
