program RemovedSDCCRegistration;
{$mode objfpc}{$H+}
uses Systems, Link;
var
  Kind: TAr;
begin
  if not Assigned(ArInfos[Ar_GNU_Ar]) or
     not Assigned(ArInfos[Ar_GNU_Ar_Scripted]) then Halt(1);
  for Kind := Low(TAr) to High(TAr) do
    if Assigned(ArInfos[Kind]) and (Pos('sdar', ArInfos[Kind]^.ArCmd) <> 0) then
      Halt(2);
  WriteLn('PASS: retained archive drivers registered; SDCC drivers absent');
end.
