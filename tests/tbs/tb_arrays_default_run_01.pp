{ Arrays regression cases; original case IDs are retained below. }

{ Case tb0012.pp }
{$push}
{ Old file: tbs0015.pp }
{  tests for wrong allocated register for return result of floating function (allocates int register)       OK 0.9.2 }

type
    tb0012_realgr=    array [1..1000]  of double;
var
    tb0012_sx    :tb0012_realgr;
    tb0012_i     :integer;
    tb0012_stemp :double;
{$pop}

{ Case tb0026.pp }
{$push}
{ Old file: tbs0030.pp }
{  tests type conversations in typed consts            OK 0.9.6 }

const
   tb0026_a : array[0..1] of real = (1,1);
{$pop}

{ Case tb0027.pp }
{$push}
{ Old file: tbs0031.pp }
{  tests array[boolean] of ....                        OK 0.9.8 }

var
   tb0027_a : array[boolean] of longint;
{$pop}

{ Case tb0029.pp }
{$push}
{ Old file: tbs0033.pp }
{  tests var p : pchar; begin p:='c'; end.             OK 0.9.9 }

var
   tb0029_p1 : pchar;
   tb0029_p2 : array[0..10] of char;
   tb0029_s : string;
   tb0029_c : char;
{$pop}

{ Case tb0047.pp }
{$push}
{ Old file: tbs0053.pp }
{  shows a problem with open arrays                     OK 0.99.1 (FK) }

procedure tb0047_abc(var a : array of char);

  begin
     // error: a:='asdf';
  end;

var
   tb0047_c : array[0..10] of char;
{$pop}

{ Case tb0049.pp }
{ Equivalent case tb0065.pp: identical declarations and empty main block. }
{$push}
{ Old file: tbs0055.pp }
{  internal error 10 (means too few registers           OK 0.99.1 (FK) }

type
   tb0049_tarraysingle = array[0..1] of single;

procedure tb0049_test(var a : tb0049_tarraysingle);

var
   tb0049_i,tb0049_j,tb0049_k : integer;

begin
   a[tb0049_i]:=a[tb0049_j]-a[tb0049_k];
end;
{$pop}

{ Case tb0098.pp }
{$push}
{ Old file: tbs0116.pp }
{ Exercise a local variable size greater than $ffff. }

Procedure tb0098_test;

Var tb0098_a: Array[1..4000000] of longint;
Begin
End;
{$pop}

{ Case tb0112.pp }
{$push}
{ Old file: tbs0131.pp }
{ internal error 10 with highdimension arrays           OK 0.99.6 (MVC) }

type tb0112_ta = Array[1..2,1..2,1..2,1..2,1..2,1..2,1..3,1..3,1..3,1..3] of Byte;
 tb0112_ta2 = Array[1..2,1..2,1..2] of Byte;

var tb0112_v,tb0112_w: tb0112_ta;
  tb0112_x: tb0112_ta2;
    tb0112_e: longint;
{$pop}

{ Case tb0127.pp }
{$push}
{ Old file: tbs0146.pp }
{ no sizeof() for var arrays and the size is pushed incorrect OK 0.99.7 (PFV) }

procedure tb0127_myfunction(var t : array of char);
begin
  writeln(sizeof(t)); { should be 51 }
  if sizeof(t)<>51 then halt(1);
end;

var
  tb0127_mycharstring : array[0..50] of char;
{$pop}

{ Case tb0153.pp }
{$push}
{ Old file: tbs0183.pp }
{ internal error 10 in secondnot                        OK 0.99.11 (PM) }

type
  tb0153_pbug = ^tb0153_tbug;
  tb0153_tbug = array[1..1] of boolean;

var
  tb0153_left : tb0153_pbug;
  tb0153_test : longint;
{$pop}

{ Case tb0176.pp }
{$push}
{ Old file: tbs0210.pp }
{ fillchar should accept boolean value also !!         OK 0.99.11 (PM) }

{ boolean args are accepted for fillchar in BP }

  var tb0176_l : array[1..10] of boolean;
{$pop}

begin
  { Case tb0012.pp }
  {$push}

  begin
tb0012_sx[1]:=10;
     tb0012_sx[2]:=-20;
     tb0012_sx[3]:=30;
     tb0012_sx[4]:=-40;
     tb0012_sx[5]:=50;
     tb0012_sx[6]:=-60;
     tb0012_i:=1;
     tb0012_stemp:=1000;
     tb0012_stemp := tb0012_stemp+abs(tb0012_sx[tb0012_i])+abs(tb0012_sx[tb0012_i+1])+abs(tb0012_sx[tb0012_i+2])+abs(tb0012_sx[tb0012_i+3])+
              abs(tb0012_sx[tb0012_i+4])+abs(tb0012_sx[tb0012_i+5]);
     writeln(tb0012_stemp);
     if tb0012_stemp<>1210.0 then halt(1);
  end;
  {$pop}

  { Case tb0027.pp }
  {$push}

  begin
tb0027_a[true]:=1234;
   tb0027_a[false]:=123;
  end;
  {$pop}

  { Case tb0029.pp }
  {$push}

  begin
tb0029_p1:='c';
   tb0029_s:='c';
   { this isn't allowed
   p1:=c;
   }
  end;
  {$pop}

  { Case tb0047.pp }
  {$push}

  begin
tb0047_abc(tb0047_c);
   writeln(tb0047_c);
   // error: writeln(a);
  end;
  {$pop}

  { Case tb0112.pp }
  {$push}

  begin
tb0112_e :=1;
  tb0112_x[tb0112_e,tb0112_e,tb0112_e]:=1;
  tb0112_v[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e] :=1;
  tb0112_w[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_v[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e],tb0112_e,tb0112_e,tb0112_v[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_v[tb0112_e,tb0112_v[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_v[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e],tb0112_e,tb0112_e,tb0112_e,tb0112_e],tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e],tb0112_e,tb0112_e,tb0112_e]] := tb0112_v [tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e];
  writeln(tb0112_w[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e]);
  if tb0112_w[tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e,tb0112_e]<>1 then
   begin
     writeln('Error!');
     halt(1);
   end;
  end;
  {$pop}

  { Case tb0127.pp }
  {$push}

  begin
tb0127_myfunction(tb0127_mycharstring);
  if sizeof(tb0127_mycharstring)<>51 then halt(1);
  end;
  {$pop}

  { Case tb0153.pp }
  {$push}

  begin
New(tb0153_left);
  tb0153_test := 1;

{ following shows internal error 10 only if the

    array index is a var on both sides
  ( if either is a constant then it compiles fine, error only occurs if the
    not is in the statement )
    bug only appears if the array is referred to using a pointer -
      if using TBug, and no pointers it compiles fine
      with PBug the error appears
    }

  tb0153_left^[tb0153_test] := not tb0153_left^[tb0153_test];
  end;
  {$pop}

  { Case tb0176.pp }
  {$push}

  begin
fillchar(tb0176_l,sizeof(tb0176_l),true);
  end;
  {$pop}

end.
