{ Try/Finally inside For loops with variable and constant upper bounds. }
{ Original case IDs and variable scopes are retained below. }

{$mode objfpc}

{ Case tw37305a.pp }
{$push}
var
  tw37305a_i, tw37305a_j, tw37305a_c: Int32;
{$pop}

{ Case tw37305b.pp }
{$push}
var
  tw37305b_i, tw37305b_j: Int32;
{$pop}

begin
  { Case tw37305a.pp }
  {$push}
begin
  tw37305a_c := 1;
  for tw37305a_i := 0 to tw37305a_c do // SIGSEGV at runtime
  try
    tw37305a_j := tw37305a_i;
  finally
    if (tw37305a_j <> 0) then
      tw37305a_j := 0;
  end;
end;
  {$pop}

  { Case tw37305b.pp }
  {$push}
begin
  for tw37305b_i := 0 to 1 do // Error: Compilation raised exception internally
  try
    tw37305b_j := tw37305b_i;
  finally
    if (tw37305b_j <> 0) then
      tw37305b_j := 0;
  end;
end;
  {$pop}

end.
