{ Nil object assignment, Assigned and absolute-zero addresses. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0329.pp }
{$push}
var
   tb0329_o : tobject;
{$pop}

{ Case tb0331.pp }
{$push}

{ tests assignments and compare }

var
   tb0331_o1,tb0331_o2 : tobject;
{$pop}

{ Case tb0350.pp }
{$push}
var
   tb0350_a : longint absolute 0;
{$pop}

begin
  { Case tb0329.pp }
  {$push}
begin
   if assigned(tb0329_o) then
     halt(1);
end;
  {$pop}

  { Case tb0331.pp }
  {$push}
begin
   tb0331_o1:=nil;
   tb0331_o2:=tb0331_o1;
   if tb0331_o2<>nil then
     halt(1);
end;
  {$pop}

  { Case tb0350.pp }
  {$push}
begin
   if @tb0350_a<>nil then
     halt(1);
end;
  {$pop}

end.
