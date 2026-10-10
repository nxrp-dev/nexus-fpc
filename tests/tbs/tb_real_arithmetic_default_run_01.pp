{ Floating-point expression generation, integer division conversion and explicit casts. }
{ Original case IDs and variable scopes are retained below. }

uses erroru;

{ Case tb0005.pp }
{$push}
{ Old file: tbs0006.pp }
{  tests the wrong floating point code generation      OK 0.9.2 }

var
   tb0005_a,tb0005_b,tb0005_c,tb0005_d,tb0005_e,tb0005_f,tb0005_g,tb0005_r : double;
{$pop}

{ Case tb0326.pp }
{$push}
var
   tb0326_d1,tb0326_d2 :double;
   tb0326_i1,tb0326_i2 : int64;
   tb0326_c1,tb0326_c2 : dword;
{$pop}

{ Case tb0535.pp }
{$push}
var tb0535_l,tb0535_h:longint;
    tb0535_r:single;
{$pop}

begin
  { Case tb0005.pp }
  {$push}
begin
   tb0005_a:=10.0;
   tb0005_b:=11.0;
   tb0005_c:=13.0;
   tb0005_d:=17.0;
   tb0005_e:=19.0;
   tb0005_f:=23.0;
   tb0005_g:=0.0;
   tb0005_r:=2.0;
   tb0005_a:= tb0005_a - 2*tb0005_b*tb0005_e - 2*tb0005_c*tb0005_f - 2*tb0005_d*tb0005_g - Sqr(tb0005_r);
   writeln(tb0005_a,' (must be -1010)');
   if tb0005_a<>-1010.0 then
     Error;
end;
  {$pop}

  { Case tb0326.pp }
  {$push}
begin
  tb0326_c1:=10;
  tb0326_c2:=100;
  tb0326_i1:=1000;
  tb0326_i2:=10000;
  tb0326_d1:=tb0326_c1/tb0326_c2;
  tb0326_d2:=tb0326_i1/tb0326_i2;
  if tb0326_d1<>tb0326_d2 then
    begin
      writeln('error');
      halt(1);
    end;
end;
  {$pop}

  { Case tb0535.pp }
  {$push}
begin
  tb0535_l:=-2;
  tb0535_h:=1;
  tb0535_r:=0;
  tb0535_r:=tb0535_r+(single(tb0535_h)-single(tb0535_l))-1;
  if trunc(tb0535_r) <> 2 then
    halt(1);
end;
  {$pop}

end.
