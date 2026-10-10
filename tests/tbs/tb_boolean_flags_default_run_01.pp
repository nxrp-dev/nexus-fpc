{ Boolean flag results, case selectors, mixed widths and noncanonical values. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0161.pp }
{$push}
{ Old file: tbs0192.pp }
{ can't compare boolean result with true/false, because the boolean result is already in the flags             OK 0.99.11 (PFV) }

var
  tb0161_k,tb0161_l : word;
{$pop}

{ Case tb0169.pp }
{$push}
{ Old file: tbs0202.pp }
{ flag results not supported with case                  OK 0.99.11 (PFV) }

var tb0169_greater : boolean;

procedure tb0169_error;
begin
   Writeln('Error in tbs0202');
   Halt(1);
end;

procedure tb0169_compare(i,j : integer);
begin
   case (i>j) of
     true : begin
                tb0169_greater:=true;
            end;
     false : begin
                tb0169_greater:=false;
             end;
   end;
end;
{$pop}

{ Case tb0175.pp }
{$push}
{ Old file: tbs0209.pp }
{ problem with boolean expressions of different store sizes }

{ problem with boolean expression mixing different boolean sizes }

var
  tb0175_b : boolean;
  tb0175_wb : wordbool;
  tb0175_lb : longbool;
{$pop}

{ Case tb0177.pp }
{$push}
{ Old file: tbs0211.pp }
{ a and not a is true !!! (if a:=boolean(5))           OK 0.99.11 (PM) }

var
   tb0177_a,tb0177_b : boolean;
   tb0177_c : byte;
   tb0177_i : longint;

procedure tb0177_error;
begin
   Writeln('Error in bug0211');
   Halt(1);
end;
{$pop}

begin
  { Case tb0161.pp }
  {$push}
begin
  if (tb0161_k<>tb0161_l)=false then
   ;
  if (tb0161_k<>tb0161_l)=true then
   ;
end;
  {$pop}

  { Case tb0169.pp }
  {$push}
begin
  tb0169_compare(45,2);
  if not tb0169_greater then
    tb0169_error;
  tb0169_compare(-5,26);
  if tb0169_greater then
    tb0169_error;
end;
  {$pop}

  { Case tb0175.pp }
  {$push}
begin
  tb0175_b:=true;
  tb0175_wb:=true;
  tb0175_lb:=true;
  if (not tb0175_b) or (not tb0175_wb) or (not tb0175_lb) then
    begin
       Writeln('Error with boolean expressions of different sizes');
       Halt(1);
    end;
end;
  {$pop}

  { Case tb0177.pp }
  {$push}
begin
  tb0177_c:=5;
  tb0177_a:=boolean(tb0177_c);
  if tb0177_a and not tb0177_a then
    Begin
       Writeln('FPC is crazy !!');
       tb0177_error;
    End;
  tb0177_i:=256;
  tb0177_a:=boolean(tb0177_i);
  { the value here is less trivial }
  { BP returns false here !!       }
  { the problem is the converting wordbool to boolean }
  { if wordbool is 256 should not convert true to false !! }

  Writeln('boolean(256) =',tb0177_a);
end;
  {$pop}

end.
