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

{ Case tb0246.pp }
{$push}
{ Old file: tbs0287.pp }
{ (true > false) not supported                         OK 0.99.13 (PFV) }

var
  tb0246_b,tb0246_bb : boolean;
{$pop}

{ Case tb0328.pp }
{$push}
{ test for full boolean eval and register usage with b+ }

{$b+}

var
  tb0328_funcscalled: byte;
  tb0328_ok: boolean;

function tb0328_function1: boolean;
begin
  writeln('function1 called!');
  inc(tb0328_funcscalled);
  tb0328_function1 := false;
end;

function tb0328_function2: boolean;
begin
  writeln('function2 called!');
  inc(tb0328_funcscalled);
  tb0328_function2 := false;
end;

function tb0328_function3: boolean;
begin
  writeln('function3 called!');
  inc(tb0328_funcscalled);
  tb0328_function3 := false;
end;

function tb0328_function4: boolean;
begin
  writeln('function4 called!');
  inc(tb0328_funcscalled);
  tb0328_function4 := false;
end;

function tb0328_test2: boolean;
var tb0328_j, tb0328_k, tb0328_l, tb0328_m: longint;
begin
  tb0328_test2 := true;
  tb0328_m := 0;
{ get as much regvars occupied as possible }
  for tb0328_j := 1 to 100 do
    for tb0328_k := 1 to 100 do
      for tb0328_l := tb0328_k downto 0 do
         inc(tb0328_m,tb0328_j - tb0328_k + tb0328_l);
  if (tb0328_j = 5) and (tb0328_k = 0) and (tb0328_l = 100) and tb0328_function1 then
    begin
      tb0328_test2 := false;
      writeln('bug');
    end;
end;
{$pop}

{ Case tw15750.pp }
{$push}
var
  tw15750_i: longint;
  tw15750_a, tw15750_b: boolean;
{$pop}

{ Case tw11027.pp }
{$push}
var tw11027_i : char;
    tw11027_bb: bytebool;
{$pop}

{ Case tw35272.pp }
{$push}
var
  tw35272_b1, tw35272_b2, tw35272_b3: longbool;
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

  { Case tb0246.pp }
  {$push}
begin
  tb0246_b:=(true > false);
  if tb0246_b then
   writeln('ok 1')
  else
   halt(1);
  tb0246_b:=true;
  tb0246_b:=(tb0246_b > false);
  if tb0246_b then
   writeln('ok 2')
  else
   halt(1);
  tb0246_b:=false;
  tb0246_bb:=true;
  if tb0246_b<tb0246_bb then
   writeln('ok 3')
  else
   halt(1);
end;
  {$pop}

  { Case tb0328.pp }
  {$push}
{$B+}
begin
  tb0328_ok := true;
  tb0328_funcscalled := 0;
  if tb0328_function1 and tb0328_function2 and tb0328_function3 and tb0328_function4 then
    begin
      writeln('bug!');
    end;
  tb0328_ok := tb0328_funcscalled = 4;
  if tb0328_ok then
    writeln('all functions called!')
  else
    writeln('not all functions called');
  tb0328_ok := tb0328_test2 and (tb0328_funcscalled = 5);
  if tb0328_ok then
    writeln('test2 passed')
  else writeln('test2 not passed');
  if not tb0328_ok then
    begin
      writeln('full boolean evaluation is not working!');
      halt(1);
    end;
end;
  {$pop}

  { Case tw15750.pp }
  {$push}
begin
  tw15750_a:=true;
  tw15750_i:=0;
  for tw15750_b:=not tw15750_a to true do
    begin
      inc(tw15750_i);
      writeln('now b is ',tw15750_b);
    end;
  if tw15750_i<>2 then
    halt(1);
end;
  {$pop}

  { Case tw11027.pp }
  {$push}
begin
  boolean(tw11027_i) := (1=1);
  if not boolean(tw11027_i) then
    halt(1);
  boolean(tw11027_bb):=boolean(tw11027_i);
  if not(tw11027_bb) then
    halt(2);
end;
  {$pop}

  { Case tw35272.pp }
  {$push}
begin
  tw35272_b1:=longbool(1);
  tw35272_b2:=longbool(2);
  tw35272_b3:=tw35272_b1 and tw35272_b2;
  if not tw35272_b3 then
    halt(1);
  tw35272_b3:=tw35272_b1 xor tw35272_b2;
  if tw35272_b3 then
    halt(2);
{$b+}
  tw35272_b3:=tw35272_b1 and tw35272_b2;
  if not tw35272_b3 then
    halt(3);
  tw35272_b3:=tw35272_b1 xor tw35272_b2;
  if tw35272_b3 then
    halt(4);
end;
  {$pop}

end.
