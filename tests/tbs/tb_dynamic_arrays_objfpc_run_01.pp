{ Dynamic-array function results, indexed temporary results and Copy slices. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tb0411.pp }
{$push}
type
   tb0411_ta = array of longint;

function tb0411_f : tb0411_ta;
  begin
     setlength(result,10);
  end;
{$pop}

{ Case tb0457.pp }
{$push}
Type
  tb0457_ta = array of Integer;

var
  tb0457_a,tb0457_b : tb0457_ta;
  tb0457_i,tb0457_j : Integer;
{$pop}

begin
  { Case tb0411.pp }
  {$push}
begin
   tb0411_f[1]:=1;
end;
  {$pop}

  { Case tb0457.pp }
  {$push}
begin
  Setlength(tb0457_a,10);
  For tb0457_i:=0 to 9 do
      tb0457_a[tb0457_i]:=tb0457_i;
  tb0457_b:=Copy(tb0457_a,3,6);
  if High(tb0457_b)<>5 then
    begin
      writeln('Error 1');
      halt(1);
    end;
  For tb0457_i:=0 to High(tb0457_b) do
    if tb0457_b[tb0457_i]<>tb0457_i+3 then
      begin
        writeln('Error 2');
        halt(1);
      end;
end;
  {$pop}

end.
