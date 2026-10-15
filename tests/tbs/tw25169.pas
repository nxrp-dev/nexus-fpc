{ %target=darwin,linux }

uses
  unixcp;
begin
  if GetCodepageByName('cp1250')<>1250 then
    halt(1);
  if GetCodepageByName('CP1250')<>1250 then
    halt(2);
end.
