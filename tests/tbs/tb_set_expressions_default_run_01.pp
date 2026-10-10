{ Variable character ranges and function-call set constructors. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0173.pp }
{$push}
{ Old file: tbs0206.pp }
{ sets with variable ranges doesn't work                OK 0.99.11 (PFV) }

CONST tb0173_a:char='A';tb0173_z:char='Z';
VAR tb0173_s:set of char;tb0173_c:char;
{$pop}

{ Case tb0216.pp }
{$push}
{ Old file: tbs0255.pp }
{ internal error 10 with in and function calls         OK 0.99.12 (FK) }


function tb0216_a: char;
begin
  tb0216_a:='c';
end;
{$pop}

begin
  { Case tb0173.pp }
  {$push}
BEGIN
 tb0173_s:=[tb0173_a..tb0173_z];
 for tb0173_c:=#0 to #255 do
  if tb0173_c in tb0173_s then
   write(tb0173_c);
 writeln;
END;
  {$pop}

  { Case tb0216.pp }
  {$push}
begin
  if #12 in [tb0216_a, tb0216_a, tb0216_a, tb0216_a, tb0216_a] then ; { <--- }
end;
  {$pop}

end.
