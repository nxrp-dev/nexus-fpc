{ Mixed string concatenation and ordinal-to-string assignment operators. }
{ Original case IDs and variable scopes are retained below. }

{$mode fpc}

{ Case tb0413.pp }
{$push}
var
   tb0413_s : ansistring;
   tb0413_ss : shortstring;
   tb0413_as : ansistring;
   tb0413_c : char;
{$pop}

{ Case tb0441.pp }
{$push}
operator :=(tb0441_x:ShortInt)RESULT:ShortString;
  begin
    Val(RESULT,tb0441_x);
  end;

var
  tb0441_s:ShortString;
{$pop}

begin
  { Case tb0413.pp }
  {$push}
begin
   tb0413_as:='ansistring';
   tb0413_ss:='shortstring';
   tb0413_c:='C';
   tb0413_s:=tb0413_s+tb0413_as;
   tb0413_s:=tb0413_s+tb0413_c;
   tb0413_s:=tb0413_s+tb0413_ss;
   tb0413_s:=tb0413_s+tb0413_s;
   if tb0413_s<>'ansistringCshortstringansistringCshortstring' then
     begin
        writeln('Problem with ansistring appending');
        halt(1);
     end;
end;
  {$pop}

  { Case tb0441.pp }
  {$push}
begin
  tb0441_s:=12;
end;
  {$pop}

end.
