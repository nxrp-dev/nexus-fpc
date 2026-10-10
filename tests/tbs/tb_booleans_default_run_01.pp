{ Boolean arguments, XOR, casts and Boolean storage types. }
{ Original case IDs and global variable scope are retained below. }

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

end.
