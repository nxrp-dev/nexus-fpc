program NXCOperatorsDirectives;

{$mode objfpc}
{$IFDEF EnableCOperators}
  {$COPERATORS ON}
{$ENDIF}
{$IFDEF DisableCOperators}
  {$COPERATORS OFF}
{$ENDIF}

var
  lValue: LongInt;
begin
  lValue := 12;
  lValue += 6;
  if lValue <> 18 then
    Halt(1);
end.
