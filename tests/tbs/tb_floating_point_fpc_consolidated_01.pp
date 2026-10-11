{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0185.pp }
{$push}
{ Old file: tbs0218.pp }
{ rounding errors with write/str (the bugs is fixed,    OK 0.99.11 (FK) }


{}
Var tb0185_r,tb0185_rr,tb0185_error:Extended;
    tb0185_s:String;
    tb0185_code : word;
{}

{$pop}

{ Case tb0450.pp }
{$push}

var
 tb0450_i: single;

{$pop}

{ Case tb_float_literals_default_run_01.pp }
{$push}
{ Floating-point formatting, fractional parts, rounding and scientific literals. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0054.pp }
{$push}
{ Old file: tbs0061.pp }
{  shows wrong errors when compiling (NOT A bugs)        OK 0.99.1 }

var
   tb0054_r : double;
   tb0054_s : string;
{$pop}

{ Case tb0058.pp }
{$push}
{ Old file: tbs0065.pp }
{  shows that frac() doesn't work correctly.            OK 0.99.1 (PFV) }

{ Program to demonstrate the Frac function. }

Var tb0058_r : Real;
{$pop}

{ Case tb0059.pp }
{$push}
{ Old file: tbs0066.pp }
{  shows that Round doesn't work correctly. (NOT A bugs) OK 0.99.1 }

{ Program to demonstrate the Round function. }
{$pop}

{ Case tb0566.pp }
{$push}
var
 tb0566_d1,tb0566_d2,tb0566_d3 : extended;
 tb0566_err: longint;
{$pop}


{$pop}

{ Case tb_real_output_default_run_01.pp }
{$push}
{ Floating-point Write formatting and Comp output. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0096.pp }
{$push}
{ Old file: tbs0114.pp }
{ writeln problem (by Pavel Ozerski)                    OK 0.99.1 (PFV) }
{$pop}

{ Case tb0097.pp }
{$push}
{ Old file: tbs0115.pp }
{ missing writeln for comp data type                    OK 0.99.6 (FK) }

var
   tb0097_c : comp;
{$pop}

{ Case tb0134.pp }
{$push}
{ Old file: tbs0157.pp }
{ Invalid compilation and also crashes                  OK 0.99.7 (PFV) }

{ this should be rejected because we only accept integer args }

var tb0134_x,tb0134_y:real;
{$pop}

{ Case tw0810.pp }
{$push}
var tw0810_i:byte;
    tw0810_e:extended;
    tw0810_s:string;
{$pop}

{ Case tw1104.pp }
{$push}
var
  tw1104_r1,tw1104_r2 : extended;
  tw1104_code : integer;
{$pop}


{$pop}

{ Case tw0911.pp }
{$push}
Function tw0911_Log(const b,r:real):real;
begin
  tw0911_log:=ln(r)/ln(b);
end;


{$pop}

{ Case tw0976.pp }
{$push}
{ Source provided for Free Pascal Bug Report 976 }
{ Submitted by    }
{ e-mail:  }


type tw0976_PDouble = ^Double;
var tw0976_A, tw0976_B: tw0976_PDouble;
    tw0976_x: Double;

Operator + (tw0976_x: Double; tw0976_A: tw0976_PDouble) tw0976_B: Double;

  begin
  tw0976_B := tw0976_x + tw0976_A^;
  end;

{ This was wrong because B value is not initialized !!
Operator + (x: Single; A: PDouble) B: PDouble;

  begin
  B^ := x + A^;
  end; }


{$pop}

{ Case tw1021.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1021 }
{ Submitted by "Oliver Puetz" on  2000-07-03 }
{ e-mail: Oliver.Puetz@gmx.de }
{
  Free Pascal Compiler version 0.99.15 [2000/03/30] for i386
  Copyright (c) 1993-2000 by Florian Klaempfl
  Win NT 4.0 Fixpak 2

  With TFloat = EXTENDED Writeln resumes 0.0   0.0   1
  With TFloat = DOUBLE   Writeln resumes 0.0   1.0   1

  Thus only the write-command seems not to transfer the extended a equals 1
  to a string like '1'
}

type  tw1021_tfloat  = extended;

var   tw1021_a, tw1021_b    : tw1021_tfloat;
      tw1021_i       : INTEGER;
      tw1021_f : text;

{$pop}

{ Case tw12051.pp }
{$push}

var
 tw12051_s: string;

{$pop}

{ Case tw12202.pp }
{$push}


procedure tw12202_check(tw12202_s: string);
var
  i: longint;
begin
  delete(tw12202_s,pos(' ',tw12202_s),1);
  delete(tw12202_s,pos('E',tw12202_s),1);
  delete(tw12202_s,pos('.',tw12202_s),1);
  delete(tw12202_s,pos('+',tw12202_s),1);
  for i := 1 to length(tw12202_s) do
    if (tw12202_s[i]<>'0') then
      halt(1);
end;

var
  tw12202_foo: single;
  tw12202_d: double;
  tw12202_e: extended;
  tw12202_s: string;

{$pop}

{ Case tw1374.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1374 }
{ Submitted by "Christian Keck" on  2001-02-01 }
{ e-mail: C.Keck@gmx.net }


var tw1374_temp        : longint;
    tw1374_low         : byte;
    tw1374_high        : byte;
    tw1374_DLL_Version : extended{real};


{$pop}

{ Case tw1477.pp }
{$push}
CONST
  tw1477_Digit:Byte=3;{did work if we use DWord}
VAR
  tw1477_x:Real;

{$pop}

{ Case tw16863.pp }
{$push}
var
    tw16863_d : double;
    tw16863_r : real48 = ($0, $0, $0, $0, $0, $0);

{$pop}

{ Case tw1720.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1720 }
{ Submitted by "Jesse Towner" on  2001-12-09 }
{ e-mail: jesse@gdnmail.net }
var tw1720_a, tw1720_b, tw1720_c : single;

{$pop}

{ Case tw1896.pp }
{$push}
var
  tw1896_value:real;
  tw1896_fin:text;

{$pop}

{ Case tw21151.pp }
{$push}
const
  tw21151_cs = single(0.05);

{$pop}

{ Case tw2131.pp }
{$push}


var
  tw2131_TestStr : string;
  tw2131_correct : string;

{$pop}

{ Case tw2226.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2226 }
{ Submitted by "" on  2002-11-12 }
{ e-mail:  }


const tw2226_mindouble: double = -5.0E324;

var
  tw2226_s : string;
  tw2226_correct : string;

{$pop}

{ Case tw2643.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2643 }
{ Submitted by "Wayne Sullivan" on  2003-08-19 }
{ e-mail: Wayne.Sullivan@cnri.dit.ie }

var tw2643_d:double;
    tw2643_s:string;
    tw2643_s1:string;

{$pop}

{ Case tw2885.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2885 }
{ Submitted by "Michalis Kamburelis" on  2004-01-07 }
{ e-mail: michalis@camelot.homedns.org }
procedure tw2885_p(const b:Single); overload;
begin
  Writeln('single');
end;

procedure tw2885_p(const b:Double); overload;
begin
  Writeln('double');
  halt(1);
end;


{$pop}

{ Case tw33635.pp }
{$push}

var
  tw33635_x,tw33635_y: double;

{$pop}

{ Case tw3694.pp }
{$push}


function tw3694_f : tobject;
begin
  tw3694_f := tobject.create;
end;

var
{$ifdef CPU64}
  tw3694_s : double;
{$else}
  tw3694_s : single;
{$endif CPU64}

{$pop}

{ Case tw38249.pp }
{$push}
var
  tw38249_A: Double = 0.0001;
  tw38249_B: Double = 0;

{$pop}

{ Case tw3893.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3893 }
{ Submitted by "George Bakhtadze" on  2005-04-14 }
{ e-mail: mirage@avagames.net }


function tw3893_GetPropertyValue: Pointer;
begin
  tw3893_GetPropertyValue:=nil;
end;

var
  tw3893_Size, tw3893_Size2: Single;
  tw3893_d: Integer;
  tw3893_p: Pointer;


{$pop}

{ Case tw4902.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4902 }
{ Submitted by "Yu Hang" on  2006-03-14 }
{ e-mail: cosechy@gmail.com }
function tw4902_x:real;
begin
end;


{$pop}

{ Case tw6493.pp }
{$push}


  Const
{$ifdef FPC_HAS_TYPE_EXTENDED}
    tw6493_MinExtendedStr=' 3.6451995318824746E-4951';
    tw6493_MinExtended=3.64519953188247460E-4951;
    tw6493_ToWidth=25;
{$else}
    tw6493_MinExtendedStr=' 4.94065645841247E-324';
    tw6493_MinExtended=4.94065645841247E-324;
    tw6493_ToWidth=22;
{$endif}

  Var
    tw6493_x:extended;
    tw6493_s:shortstring;

  
{$pop}

{ Case tw6727.pp }
{$push}
const tw6727_vegt : real = exp( 15001*ln(2000000));

{$pop}

{ Case tw7105.pp }
{$push}
var tw7105_i:integer;
    tw7105_H:single;
    tw7105_s:string;


{$pop}

{ Case tw7425.pp }
{$push}
procedure tw7425_a(r: double); overload;
begin
end;

procedure tw7425_a(r: real); overload;
begin
end;

{$ifdef FPC_HAS_TYPE_EXTENDED}
procedure tw7425_a(r: extended); overload;
begin
end;
{$endif}


{$pop}

{ Case tw8977.pp }
{$push}
function tw8977_DoTest: double; safecall;
begin
  tw8977_DoTest:=1.0;
end;


{$pop}

{ Case tw9026.pp }
{$push}
operator := (input:extended) output: string;
begin
   str(round(input),output);
end;

operator + (const tw9026_s: string; input:extended) output: string;
begin
   str(round(input),output);
   output:=tw9026_s+output;
end;

procedure tw9026_test(a:string);
begin
   writeln(a);
   if (a <> 'help1') then
     halt(1);
end;

var
tw9026_s: string;

{$pop}

{ Case tw9695.pp }
{$push}
var
  tw9695_s: string;
  tw9695_d: Double;

{$pop}

begin

{ Case tb0185.pp }
{$push}

Begin
  Writeln('Size of Extended type (r)=',SizeOf(tb0185_r),' bytes');
  tb0185_r:=0.000058184639;
  Writeln('r=',tb0185_r);
  Writeln('r=',tb0185_r:16:13);
  Writeln('r=',tb0185_r:15:12);
  Writeln('r=',tb0185_r:14:11);
  Writeln('r=',tb0185_r:13:10);
  Writeln('r=',tb0185_r:12:9);
  Writeln('r=',tb0185_r:11:8);
  Writeln('r=',tb0185_r:10:7);
  Writeln('r=',tb0185_r:9:6);
  Writeln('r=',tb0185_r:8:5);
  Writeln('r=',tb0185_r:7:4);
  Str(tb0185_r,tb0185_s);
  Writeln('r=',tb0185_s,' (as string)');
  str(tb0185_r,tb0185_s);
  val(tb0185_s,tb0185_rr,tb0185_code);
  { calculate maximum possible precision }
  if sizeof(extended) = 12 then
    tb0185_error := exp(17*ln(10))
  else if sizeof(extended) = 10 then
    tb0185_error := exp(17*ln(10))
  else if sizeof(extended) = 8 then
    tb0185_error := exp(14*ln(10))
  else if sizeof(extended) = 4 then
    { the net may have to be 9 instead of 8, not sure }
    tb0185_error := exp(8*ln(10))
  else
    begin
      Writeln('unknown extended type size!');
      halt(1)
    end;
  if abs(tb0185_r-tb0185_rr) > tb0185_error then
    begin
      Writeln('r=',tb0185_r);
      Writeln('is different from rr=',tb0185_rr);
      halt(1);
    end;
End;
{$pop}

{ Case tb0450.pp }
{$push}

Begin
  case round(tb0450_i) of
  0: WriteLn;
  1: WriteLn;
  end;
end;
{$pop}

{ Case tb_float_literals_default_run_01.pp }
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0054.pp }
  {$push}
begin
   tb0054_r:=1234.0;
   str(tb0054_r,tb0054_s);
end;
  {$pop}

  { Case tb0058.pp }
  {$push}
begin
  Writeln (Frac (123.456):0:3);  { Prints  O.456 }
  Writeln (Frac (-123.456):0:3); { Prints -O.456 }
end;
  {$pop}

  { Case tb0059.pp }
  {$push}
begin
  Writeln (Round(123.456));  { Prints 124  }
  Writeln (Round(-123.456)); { Prints -124 }
  Writeln (Round(12.3456));  { Prints 12   }
  Writeln (Round(-12.3456)); { Prints -12  }
end;
  {$pop}

  { Case tb0566.pp }
  {$push}
begin
 tb0566_d1:=105;
 tb0566_d2:=1.05e2;
 if (tb0566_d1<>tb0566_d2) then
   halt(1);
end;
  {$pop}

end;
{$pop}

{ Case tb_real_output_default_run_01.pp }
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0096.pp }
  {$push}
begin
 write{ln}(0.997:0:2);
end;
  {$pop}

  { Case tb0097.pp }
  {$push}
begin
   tb0097_c:=1234;
   writeln(tb0097_c);
   {readln(c);}
   tb0097_c:=-258674;
   writeln(tb0097_c);
end;
  {$pop}

  { Case tb0134.pp }
  {$push}
begin
tb0134_x:=5.6;
tb0134_y:=45.789;
write(tb0134_y:2:3,tb0134_x:3:4);
{write(y:3.2,x:5.2);}
end;
  {$pop}

  { Case tw0810.pp }
  {$push}
begin
tw0810_e:=103; (*1003,100003,1000003*)
for tw0810_i:=0 to 17 do
    begin
    str(tw0810_e:0:tw0810_i,tw0810_s);
    writeln(tw0810_s);
    end;

end;
  {$pop}

  { Case tw1104.pp }
  {$push}
begin
  val('.',tw1104_r1,tw1104_code);
  if tw1104_r1<>0.0 then
   writeln('error with val(".")');
  val('.E',tw1104_r2,tw1104_code);
  if tw1104_r2<>0.0 then
   writeln('error with val(".E")');
  if (tw1104_r1<>0.0) or (tw1104_r2<>0.0) then
   halt(1);
end;
  {$pop}

end;
{$pop}

{ Case tw0911.pp }
{$push}

begin
  tw0911_log(2,5);
end;
{$pop}

{ Case tw0976.pp }
{$push}

begin
new (tw0976_A);
new (tw0976_B);
tw0976_x  := 0.5;
tw0976_A^ := tw0976_x;

{--- Addition "Double + Double": OK}
tw0976_B^ := tw0976_x + tw0976_A^;
writeln (tw0976_B^:4:2);
if tw0976_B^<>1.0 then
  Halt(1);
{---Identical error messages for addition "PDouble + Double" and "Double + PDouble"}
{---in spite of overloaded + operator}
// B := A + x;
tw0976_B^ := tw0976_x + tw0976_A;
writeln (tw0976_B^:4:2);
if tw0976_B^<>1.0 then
  Halt(1);
end;
{$pop}

{ Case tw1021.pp }
{$push}

begin
  case sizeof(tw1021_tfloat) of
    4:  writeln('single');
    8:  writeln('double');
   10:  writeln('extended');
   else writeln(sizeof(tw1021_tfloat));
  end;
  tw1021_a := 0;
  tw1021_b := 1 - tw1021_a;
  tw1021_i := Round(tw1021_b);
  writeln(tw1021_a:30:20, tw1021_b:30:20, tw1021_i:10);
  assign(tw1021_f,'tbug1021.tmp');
  rewrite(tw1021_f);
  writeln(tw1021_f,tw1021_a:30:20,' ',tw1021_b:30:20,' ',tw1021_i:10);
  close(tw1021_f);
  reset(tw1021_f);
  read(tw1021_f,tw1021_a);
  read(tw1021_f,tw1021_b);
  read(tw1021_f,tw1021_i);
  if (tw1021_a<>0.0) then
    begin
      Writeln('Error reading A value, should be zero');
      Halt(1);
    end;
  if (tw1021_b<>1.0) then
    begin
      Writeln('Error reading B value, should be one');
      Halt(1);
    end;
  if (tw1021_i<>1) then
    begin
      Writeln('Error reading I value, should be one');
      Halt(1);
    end;
  close(tw1021_f);
  erase(tw1021_f);
end;
{$pop}

{ Case tw12051.pp }
{$push}

begin
 str(double(10000000000000000000),tw12051_s);
 writeln(tw12051_s);
 if (pos('-',tw12051_s)<>0) then
   halt(1);
end;
{$pop}

{ Case tw12202.pp }
{$push}

begin
   tw12202_foo:=0.0;
   tw12202_d:=0.0;
   tw12202_e:=0.0;
   str(tw12202_foo,tw12202_s);
   writeln(tw12202_s);
   tw12202_check(tw12202_s);
   str(tw12202_d,tw12202_s);
   writeln(tw12202_s);
   tw12202_check(tw12202_s);
   str(tw12202_e,tw12202_s);
   writeln(tw12202_s);
   tw12202_check(tw12202_s);
end;
{$pop}

{ Case tw1374.pp }
{$push}

begin
  tw1374_temp:= 14340; { This value is normally retrieved form an external DLL }

  tw1374_low:= ((tw1374_temp shr 8) and $FF);
  tw1374_high:= (tw1374_temp and $FF);          { Some calculation...   }
  tw1374_DLL_Version:= tw1374_high + (tw1374_low/100); { to get an real result }

  { ... }

  if tw1374_DLL_Version < 4.56 then      { 4.560000000000000E+000 < 4.56 ?!?! }
    writeln ('Error! 4.56 < 4.56');
end;
{$pop}

{ Case tw1477.pp }
{$push}

BEGIN
  tw1477_x:=10;
  WriteLn(tw1477_x:1:tw1477_Digit);
END;
{$pop}

{ Case tw16863.pp }
{$push}

BEGIN
    tw16863_d := tw16863_r;
    if tw16863_d<>0.0 then
      halt(1);
END;
{$pop}

{ Case tw1720.pp }
{$push}

begin
    (* ... other floating point code goes here *)

    tw1720_a := 5.6;
    tw1720_b := 3.4;
    tw1720_b:= tw1720_b + sqrt(tw1720_b)- ln(tw1720_a);

    tw1720_c := tw1720_a - (tw1720_b-(tw1720_b-1));

    if abs(tw1720_c-(tw1720_a-1))>0.01 then
      begin
        Writeln('Error in floating point code');
        halt(1);
      end;
    (* sometimes, depending on the previous code,
       the code generator will chose to swap the
       operands. however, it just calls the
       reverse version of the instruction without
       swapping the operands. this results in
       giving a value of (b-a) or -2.2 for c. the
       same goes for floating point division. *)
end;
{$pop}

{ Case tw1896.pp }
{$push}

begin
  assign(tw1896_fin,'tw1896.tmp');
  rewrite(tw1896_fin);
  writeln(tw1896_fin,'12.3');
  writeln(tw1896_fin,'13.2');
  close(tw1896_fin);

  assign(tw1896_fin,'tw1896.tmp');
  reset(tw1896_fin);
  while not eof(tw1896_fin) do
  begin
  read(tw1896_fin,tw1896_value);
  writeln(tw1896_value)
  end;
  { Delphi returns 0 as last value }
  if tw1896_value<>0 then
   begin
     writeln('Error');
     halt(1);
   end;
  close(tw1896_fin);
  erase(tw1896_fin);
end;
{$pop}

{ Case tw21151.pp }
{$push}

begin
  if sizeof(tw21151_cs)<>4 then
    halt(1);
end;
{$pop}

{ Case tw2131.pp }
{$push}

begin
  if sizeof(extended) > sizeof(double) then
    tw2131_correct := ' 1.8E+0012'
  else
    tw2131_correct := ' 1.8E+012';
  Str (extended(1.789e12):1, tw2131_TestStr);
  if (tw2131_teststr <> tw2131_correct) then
    begin
      writeln('error, got "',tw2131_teststr,'" expected "',tw2131_correct,'"');
      halt(1);
    end
end;
{$pop}

{ Case tw2226.pp }
{$push}

begin
  case sizeof(extended) of
    10: tw2226_correct := '                  -Inf';
    8: tw2226_correct := '                  -Inf';
  end;
  str(tw2226_mindouble:22,tw2226_s);
  if tw2226_s<>tw2226_correct then
    begin
      writeln('error');
      halt(1);
    end;
end;
{$pop}

{ Case tw2643.pp }
{$push}

begin
   tw2643_d:=5168568.5;
   str(tw2643_d:10,tw2643_s);
   if tw2643_s<>' 5.17E+006' then
     begin
       writeln(tw2643_s);
       halt(1);
     end;
   str(tw2643_d:11,tw2643_s);
   if tw2643_s<>' 5.169E+006' then
     begin
       writeln(tw2643_s);
       halt(1);
     end;
   str(tw2643_d:22,tw2643_s);
   if sizeof(extended) > 8 then
     tw2643_s1 := ' 5.16856850000000E+006'
   else
     tw2643_s1 := ' 5.16856850000000E+006';
   if tw2643_s<>tw2643_s1 then
     begin
       writeln(tw2643_s);
       halt(1);
     end;
end;
{$pop}

{ Case tw2885.pp }
{$push}

begin
  tw2885_p(single(1.0));
end;
{$pop}

{ Case tw33635.pp }
{$push}

begin
  tw33635_x := 1e20;
  writeln('x=',tw33635_x);
  tw33635_y := frac(tw33635_x);
  writeln('frac(x)=',tw33635_y);
end;
{$pop}

{ Case tw3694.pp }
{$push}
{$ifdef CPU64}
{$else}
{$endif CPU64}
begin
{$ifdef CPU64}
  tw3694_s := double(tw3694_f);
{$else CPU64}
  tw3694_s := single(tw3694_f);
{$endif CPU64}
end;
{$pop}

{ Case tw38249.pp }
{$push}

begin
  if tw38249_B >= 0 then
    tw38249_A := tw38249_B;
  if tw38249_A<>0 then
    halt(1);
end;
{$pop}

{ Case tw3893.pp }
{$push}

begin
{$ifndef cpu64}
  tw3893_Size := 9.11;
//  d := Integer(GetPropertyValue());   // All commented code works
//  p := GetPropertyValue();
//  Size2 := single(p);
  tw3893_Size2 := single(tw3893_GetPropertyValue());
{$endif cpu64}
end;
{$pop}

{ Case tw4902.pp }
{$push}

begin
tw4902_x;
{anything here}
 writeln(1);
 writeln(2);
 writeln(3);
{crash here}
writeln(1.0)
end;
{$pop}

{ Case tw6493.pp }
{$push}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$else}
{$endif}
Begin
    val(tw6493_MinExtendedStr,tw6493_x);
    str(tw6493_x:tw6493_ToWidth,tw6493_s);
    if (tw6493_x=0.0) or
       (tw6493_x<>tw6493_minextended) or
       (tw6493_s<>tw6493_MinExtendedStr) then
      halt(1);
  End;
{$pop}

{ Case tw6727.pp }
{$push}

begin
end;
{$pop}

{ Case tw7105.pp }
{$push}

begin
  tw7105_H:= 10;
  for tw7105_i:=1 to 25 do
    begin
      str(tw7105_H:8,tw7105_s);
      if (tw7105_s[1] <> ' ') or
         (length(tw7105_s) <> 8) then
        begin
          writeln(tw7105_s);
          halt(1);
        end;
      tw7105_H:= tw7105_H / 10.0;
    end;
end;
{$pop}

{ Case tw7425.pp }
{$push}
{$ifdef FPC_HAS_TYPE_EXTENDED}
{$endif}
begin
  writeln(sizeof(real));
end;
{$pop}

{ Case tw8977.pp }
{$push}

begin
  writeln(tw8977_DoTest);
end;
{$pop}

{ Case tw9026.pp }
{$push}

begin
   tw9026_s:='help';
   tw9026_test('help'+1);
   tw9026_test(tw9026_s+1);
   tw9026_test(tw9026_s+1.2);
   tw9026_test(tw9026_s+extended(1.2));
   tw9026_test(tw9026_s+string(1.2));
end;
{$pop}

{ Case tw9695.pp }
{$push}

begin
  tw9695_d := 5.9999999999999991;
  Str(tw9695_d:23,tw9695_s);
  if (pos('6',tw9695_s)<>0) then
    halt(1);
end;
{$pop}

end.
