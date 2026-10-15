{ Floating-point expression generation, integer division conversion and explicit casts. }
{ Original case IDs and variable scopes are retained below. }

uses erroru;

{ Case tb0005.pas }
{$push}
{ Old file: tbs0006.pas }
{  tests the wrong floating point code generation      OK 0.9.2 }

var
   tb0005_a,tb0005_b,tb0005_c,tb0005_d,tb0005_e,tb0005_f,tb0005_g,tb0005_r : double;
{$pop}

{ Case tb0326.pas }
{$push}
var
   tb0326_d1,tb0326_d2 :double;
   tb0326_i1,tb0326_i2 : int64;
   tb0326_c1,tb0326_c2 : dword;
{$pop}

{ Case tb0535.pas }
{$push}
var tb0535_l,tb0535_h:longint;
    tb0535_r:single;
{$pop}

{ Case tb0068.pas }
{$push}
{ Old file: tbs0076.pas }
{  bugs in intel asm generator. was already fixed        OK 0.99.1 (FK) }

{Generates wrong code when compiled with output set to intel asm.

 Reported from mailing list by Vtech Kavan.

 15 Januari 1998, Daniel Mantione}

type  tb0068_tvtx2d = record x,y:longint end;

var  tb0068_vtx2d:array[0..2] of tb0068_tvtx2d;

function tb0068_setupscanlines(tb0068_va,tb0068_vb,tb0068_vc:word):single;
var tb0068_dx3d,tb0068_dx2d,tb0068_dy2d,tb0068_dz,tb0068_ex3d,tb0068_ex2d,tb0068_ez:longint;
    tb0068_r:single;
begin
 tb0068_dy2d := 0;
 tb0068_dy2d := tb0068_vtx2d[tb0068_vb].y;
 tb0068_r    := (tb0068_dy2d-tb0068_vtx2d[tb0068_va].y);     {this line causes error!!!!!!!!!!!!!!!!!!!}
end;
{$pop}

{ Case tb0235.pas }
{$push}
{ Old file: tbs0275.pas }
{ too many warnings }

var
  tb0235_d : single;
{$pop}

{ Case tb0295.pas }
{$push}
{ Old file: tbs0353.pas }
{  }

Var
  tb0295_i : Int64;
  tb0295_j : longint;
  tb0295_k : Int64;
  tb0295_err : boolean;
{$pop}

begin
  { Case tb0005.pas }
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

  { Case tb0326.pas }
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

  { Case tb0535.pas }
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

  { Case tb0068.pas }
  {$push}
begin
 tb0068_setupscanlines(1,2,3);
end;
  {$pop}

  { Case tb0235.pas }
  {$push}
begin
  writeln(longint(tb0235_d));
end;
  {$pop}

  { Case tb0295.pas }
  {$push}
begin
  tb0295_i:=2;
  Writeln(tb0295_i);
  tb0295_k:=qword(1) shl 62;
  For tb0295_j:=1 to 61 do
    begin
    tb0295_i:=tb0295_i*2;
    If tb0295_i/tb0295_k*100>100 then
      begin
        Writeln('Error');
        tb0295_err:=true;
      end
    else
      Writeln(tb0295_j:2,': ',tb0295_i:20,' ',tb0295_i div 1024:20,' ',(tb0295_i/tb0295_k*100):4:1);
    end;
  if tb0295_err then
   halt(1);
end;
  {$pop}

end.
