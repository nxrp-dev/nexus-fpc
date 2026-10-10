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

{ Case tb0172.pp }
{$push}
{ Old file: tbs0204.pp }
{ can typecast the result var in an assignment          OK 0.99.11 (PM) }

{ boolean(byte) byte(boolean)
  word(wordbool) wordbool(word)
  longint(longbool) and longbool(longint)
  must be accepted as var parameters
  or a left of an assignment }

procedure tb0172_error;
begin
   Writeln('Error in tbs0204');
   Halt(1);
end;

var
  tb0172_b : boolean;
  tb0172_wb : wordbool;
  tb0172_lb : longbool;
{$pop}

{ Case tb0172a.pp }
{$push}
{ Old file: tbs0204.pp }
{ can typecast the result var in an assignment          OK 0.99.11 (PM) }

{ boolean(byte) byte(boolean)
  word(wordbool) wordbool(word)
  longint(longbool) and longbool(longint)
  must be accepted as var parameters
  or a left of an assignment }

procedure tb0172a_error;
begin
   Writeln('Error in tb0172a');
   Halt(1);
end;

procedure tb0172a_test;
var
  tb0172a_b : shortint;
  tb0172a_wb : smallint;
  tb0172a_lb : longint;

begin
  tb0172a_b:=0;
  tb0172a_wb:=0;
  tb0172a_lb:=0;

  byte(tb0172a_b):=128;
  word(tb0172a_wb):=32768;
  cardinal(tb0172a_lb):=$80000000;
  if (tb0172a_b<>low(shortint)) or (tb0172a_wb<>low(smallint)) or (tb0172a_lb<>low(longint)) then
    tb0172a_error;
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

  { Case tb0172.pp }
  {$push}
begin
  byte(tb0172_b):=1;
  word(tb0172_wb):=1;
  longint(tb0172_lb):=1;
  if (not tb0172_b) or (not tb0172_wb) or (not tb0172_lb) then
    tb0172_error;
  byte(tb0172_b):=2;
  Writeln('if a boolean contains 2 it is considered as ',tb0172_b);
  byte(tb0172_b):=3;
  Writeln('if a boolean contains 3 it is considered as ',tb0172_b);
  shortint(tb0172_b):=-1;
  Writeln('if a boolean contains shortint(-1) it is considered as ',tb0172_b);
end;
  {$pop}

  { Case tb0172a.pp }
  {$push}
begin
  tb0172a_test;
end;
  {$pop}

end.
