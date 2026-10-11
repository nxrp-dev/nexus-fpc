{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_booleans_default_run_01.pp }
{$push}

{ Case tb0007.pp }
{$push}
{ Old file: tbs0009.pp }
{  tests comparisons in function calls a(c<0);        OK 0.9.2 }

var tb0007_c:byte;

  Procedure tb0007_a(b:boolean);

    begin
       if b then writeln('TRUE') else writeln('FALSE');
    end;

  function tb0007_test_a(b:boolean) : string;

    begin
       if b then tb0007_test_a:='TRUE' else tb0007_test_a:='FALSE';
    end;
{$pop}

{ Case tb0009.pp }
{$push}
{ Old file: tbs0012.pp }
{  tests type conversation byte(a>b)                 OK 0.9.9 (FK) }

var
   tb0009_a,tb0009_b : longint;
{$pop}

{ Case tb0035.pp }
{$push}
{ Old file: tbs0040.pp }
{  shows the if b1 xor b2 problem where b1,b2 :boolean OK 0.9.9 (FK) }

{ xor operator bug                }
{ needs fix in pass_1.pas line    }
{ 706. as well as in the code     }
{ generator - secondadd()         }
var
 tb0035_b1,tb0035_b2: boolean;
{$pop}

{ Case tb0048.pp }
{$push}
{ Old file: tbs0054.pp }
{  wordbool and longbool types are missed               OK 0.99.6 (PFV) }

var
   tb0048_wb : wordbool;
   tb0048_wl : longbool;
{$pop}

{ Case tb0055.pp }
{$push}
{ Old file: tbs0062.pp }
{  shows illegal type conversion for boolean            OK 0.99.6 (PFV) }

var
 tb0055_myvar:boolean;
{$pop}

{ Case tb0087.pp }
{$push}
{ Old file: tbs0103.pp }
{ problems with boolean typecasts (other type)          OK 0.99.6 (PFV) }


Var
 tb0087_out: boolean;
 tb0087_int: byte;
{$pop}

{ Case tb0601.pp }
{$push}
var
  tb0601_i1, tb0601_i2, tb0601_i3: LongWord;
{$pop}

{ Case tb0625.pp }
{$push}
var
  tb0625_i: Int64;
  tb0625_b: Boolean;
{$pop}


{$pop}

{ Source group: tb_boolean_flags_default_run_01.pp }
{$push}

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


{$pop}

{ Source group: tb_branches_default_run_01.pp }
{$push}

{ Case tb0034.pp }
{$push}
{ Old file: tbs0039.pp }
{  shows the else-else problem                         OK 0.9.9 (FK) }

VAR tb0034_a : BYTE;
{$pop}

{ Case tb0036.pp }
{$push}
{ Old file: tbs0041.pp }
{  shows the if then end. problem                      OK 0.9.9 (FK) }

var
 tb0036_b1: boolean;
{$pop}

{ Case tb0057.pp }
{$push}
{ Old file: tbs0064.pp }
{  shows other types of problems with case statements   OK 0.99.1 (FK) }

var
 tb0057_i: byte;
 tb0057_j: integer;
 tb0057_c: char;
{$pop}

{ Case tb0082.pp }
{$push}
{ Old file: tbs0095.pp }
{ case with ranges starting with #0 bugs                OK 0.99.1 (FK) }

var
  tb0082_ch : char;
{$pop}

{ Case tb0712.pp }
{$push}
var
  tb0712_yy,tb0712_res : longint;
{$pop}

{ Case tw10009.pp }
{$push}
var
  tw10009_test : 2..14;
{$pop}

{ Case tw1061.pp }
{$push}
var tw1061_vlcnt:longint;
{$pop}

{ Case tw1222.pp }
{$push}
CONST
    tw1222_c1=$80000000;
    tw1222_c2=$80000001;
    tw1222_c3=$80000002;
    tw1222_c4=$80000003;
    tw1222_cm=$80000007;

VAR tw1222_v:dword;
{$pop}


{$pop}

{ Source group: tb_loops_default_run_01.pp }
{$push}

{ Case tb0003.pp }
{$push}
{ Old file: tbs0004.pp }
{  tests the continue instruction in the for loop      OK 0.9.2 }

var
   tb0003_i : longint;
{$pop}

{ Case tb0110.pp }
{$push}
{ Old file: tbs0129.pp }
{ endless loop with while/continue                      OK 0.99.6 (FK) }

var
 tb0110_e:boolean;
 tb0110_a:integer;
{$pop}

{ Case tb0115.pp }
{$push}
{ Old file: tbs0134.pp }
{ 'continue' keyword is buggy.                          OK 0.99.6 (FK) }

{
In this simple example, the even loop is wrong.  When continue; is called,
it should go back to the top and check the loop conditions and exit when i =
4, but continue skips checking the loop conditions and does i=5 too, then it
is odd, doesn't run the continue, and the loop terminates properly.
}


procedure tb0115_demoloop( max:integer );
var i : integer;
begin
i := 1;
while (i <= max) do
    begin
    if (i mod 2 = 0) then
        begin
        writeln('Even ',i,' of ',max);
        inc(i);
        continue;
        end;
    writeln('Odd ',i,' of ',max);
    inc(i);
    end;
end;
{$pop}

{ Case tb0131.pp }
{$push}
{ Old file: tbs0152.pp }
{ End value of loop variable must be calculated before loop variable is initialized.                              OK 0.99.11 (PM) }

{
  Shows wrong evaluation of loop boundaries. First end boundary must
  be calculated, only then Loop variable should be initialized.
  Change loop variable to J to see what should be the correct output.
}

PROCEDURE tb0131_lgrow(VAR tb0131_s : ShortString;C:CHAR;Count:WORD);

 VAR  I,J :WORD;

BEGIN
  I:=ORD(tb0131_s[0]);           { Keeping length in local data eases optimizations}
  IF I<Count THEN
     BEGIN
     Move(tb0131_s[1],tb0131_s[Count-I+1],I);
     FOR I:=1 TO Count-I DO
       tb0131_s[I]:=C;
     tb0131_s[0]:=CHR(Count);
     END;
END;

Var tb0131_s : ShortString;
{$pop}

{ Case tb0137.pp }
{$push}
{ Old file: tbs0162.pp }
{ continue in repeat ... until loop doesn't work correct OK 0.99.8 (PFV) }

var
   tb0137_i : longint;
{$pop}


{$pop}

begin
  { Source group: tb_booleans_default_run_01.pp }
  {$push}


begin
  { Case tb0007.pp }
  {$push}
begin {main program}
     tb0007_a(true); {works}
     if tb0007_test_a(true)<>'TRUE' then halt(1);
     tb0007_a(false); {works}
     if tb0007_test_a(false)<>'FALSE' then halt(1);
     tb0007_c:=0;
     tb0007_a(tb0007_c>0); {doesn't work}
     if tb0007_test_a(tb0007_c>0)<>'FALSE' then halt(1);
     tb0007_a(tb0007_c<0); {doesn't work}
     if tb0007_test_a(tb0007_c<0)<>'FALSE' then halt(1);
     tb0007_a(tb0007_c=0);
     if tb0007_test_a(tb0007_c=0)<>'TRUE' then halt(1);
  end;
  {$pop}

  { Case tb0009.pp }
  {$push}
begin
   tb0009_a:=1;
   tb0009_b:=2;
   if byte(tb0009_a>tb0009_b)=byte(tb0009_a<tb0009_b) then
     begin
        writeln('Ohhhh');
        Halt(1);
    end;
end;
  {$pop}

  { Case tb0035.pp }
  {$push}
Begin
  tb0035_b1:=true;
  tb0035_b2:=false;
  If (tb0035_b1 xor tb0035_b2) Then
  begin
  end
  else
    begin
       writeln('Problem with bool xor');
       halt;
    end;
  tb0035_b1:=true;
  tb0035_b2:=true;
  If (tb0035_b1 xor tb0035_b2) Then
    begin
       writeln('Problem with bool xor');
       halt;
    end;
  writeln('No problem found');
end;
  {$pop}

  { Case tb0048.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0055.pp }
  {$push}
Begin
 { by fixing this we also start partly implementing LONGBOOL/WORDBOOL }
 tb0055_myvar:=boolean(1);      { illegal type conversion }
end;
  {$pop}

  { Case tb0087.pp }
  {$push}
Begin
 { savesize is different! }
 tb0087_out:=boolean((tb0087_int AND $20) SHL 4);
end;
  {$pop}

  { Case tb0601.pp }
  {$push}
begin
  tb0601_i1 := 42;
  tb0601_i2 := 84;
  tb0601_i3 := LongWord(tb0601_i1 < tb0601_i2);
  if tb0601_i3 <> 1 then
    Halt(1);
end;
  {$pop}

  { Case tb0625.pp }
  {$push}
begin
  tb0625_i := 1;
  tb0625_b := Boolean(tb0625_i);
  if not tb0625_b then
    Halt(1);
  tb0625_i := 0;
  tb0625_b := Boolean(tb0625_i);
  if tb0625_b then
    Halt(2);
  tb0625_i := 42;
  tb0625_b := Boolean(tb0625_i);
  if not tb0625_b then
    Halt(3);
  tb0625_i := $ffffffffffffffff;
  tb0625_b := Boolean(tb0625_i);
  if not tb0625_b then
    Halt(4);
  tb0625_i := $ffffffffffffff00;
  tb0625_b := Boolean(tb0625_i);
  if tb0625_b then
    Halt(5);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_boolean_flags_default_run_01.pp }
  {$push}


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


end;
  {$pop}

  { Source group: tb_branches_default_run_01.pp }
  {$push}


begin
  { Case tb0034.pp }
  {$push}
BEGIN
  tb0034_a := 1;
  IF tb0034_a=0 THEN
    IF tb0034_a=1 THEN tb0034_a:=2
    ELSE
  ELSE tb0034_a:=3;        { "Illegal expression" }
END;
  {$pop}

  { Case tb0036.pp }
  {$push}
Begin
  begin
     If tb0036_b1 then      { illegal expression }
  end;
  while tb0036_b1 do
End;
  {$pop}

  { Case tb0057.pp }
  {$push}
Begin
  case tb0057_i of
  Ord('x'): ;
  end;
  case tb0057_j of
  Ord('x'): ;
  end;
  case tb0057_c of
  Chr(112): ;
  end;
end;
  {$pop}

  { Case tb0082.pp }
  {$push}
begin
  tb0082_ch:=#3;
  case tb0082_ch of
   #0..#31 : ;
  else
   writeln('bug');
  end;
  case tb0082_ch of
   #0,#1,#3 : ;
  else
   writeln('bug');
  end;
end;
  {$pop}

  { Case tb0712.pp }
  {$push}
begin
  tb0712_res:=0;
  tb0712_yy:=random(0)+1980;
  If (tb0712_yy<1980) or (tb0712_yy>2099) then
    tb0712_res:=1;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+2099;
  If (tb0712_yy<1980) or (tb0712_yy>2099) then
    tb0712_res:=2;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+1980;
  If (tb0712_yy<=1979) or (tb0712_yy>2099) then
    tb0712_res:=3;
  if tb0712_res<>0 then
    halt(tb0712_res);

  tb0712_yy:=random(0)+2099;
  If (tb0712_yy<1979) or (tb0712_yy>=2100) then
    tb0712_res:=4;
  if tb0712_res<>0 then
    halt(tb0712_res);
end;
  {$pop}

  { Case tw10009.pp }
  {$push}
begin
  tw10009_test:=14;
  case tw10009_test of
    2..9: halt(1);
    14: ;
  else
    halt(1);
  end;
  writeln('ok');
end;
  {$pop}

  { Case tw1061.pp }
  {$push}
begin
   tw1061_vlcnt := 10;
   case tw1061_vlcnt of
   7: writeln(7);
   12,13: begin
            writeln('Case codegeneration error!');
            halt(1);
          end;
   11:writeln(11);
   end;
end;
  {$pop}

  { Case tw1222.pp }
  {$push}
BEGIN
  tw1222_v:=tw1222_c2;
  CASE (tw1222_v AND tw1222_cm) OF
    tw1222_c1,tw1222_c2:writeln('case c1,c2');
    tw1222_c3,tw1222_c4:
    begin
      writeln('case c3,c4');
      halt(1);
    end;
  ELSE
    begin
      writeln('case failed, but it should not');
      halt(1);
    end;
  END;
END;
  {$pop}


end;
  {$pop}

  { Source group: tb_loops_default_run_01.pp }
  {$push}


begin
  { Case tb0003.pp }
  {$push}
begin
   for tb0003_i:=1 to 100 do
     begin
        writeln('Hello');
        continue;
        writeln('ohh');
        Halt(1);
     end;
end;
  {$pop}

  { Case tb0110.pp }
  {$push}
begin
 tb0110_e:=true;
 tb0110_a:=3;
 while (tb0110_a<5) and tb0110_e do begin
  tb0110_e:=false;
  write('*');
  continue;
 end;
end;
  {$pop}

  { Case tb0115.pp }
  {$push}
begin
writeln('Odd loop (continue is *not* last call):');
tb0115_demoloop(3);
writeln('Even loop (continue is last call):');
tb0115_demoloop(4);
end;
  {$pop}

  { Case tb0131.pp }
  {$push}
begin
  tb0131_s:='abcedfghij';
  writeln ('s : ',tb0131_s);
  tb0131_lgrow (tb0131_s,'1',17);
  writeln ('S : ',tb0131_s);
  if tb0131_s<>'1111111abcedfghij' then
    begin
       writeln('tbs0152 fails');
       halt(1);
    end;
end;
  {$pop}

  { Case tb0137.pp }
  {$push}
begin
   tb0137_i:=1;
   repeat
     continue;
   until tb0137_i=1;
end;
  {$pop}


end;
  {$pop}

end.
