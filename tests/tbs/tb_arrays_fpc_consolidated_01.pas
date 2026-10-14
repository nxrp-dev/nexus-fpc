{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tb0008.pas }
{$push}
{ Old file: tbs0011.pas }
{  tests div/mod bugs, where edx is scrambled, if a called procedure does a div/mod                   OK 0.9.2 }

{$message don't know how to make a test from bug0011 (PM)}
var
   tb0008_vga : array[0..320*200-1] of byte;

procedure tb0008_test(x,y : longint);

  begin
     tb0008_vga[x+y mod 320]:=random(256);
     tb0008_vga[x+y mod 320]:=random(256);
  end;


{$pop}

{ Case tb_array_type_expressions.pas }
{$push}
{ Array type bounds, constant expressions and packed declarations. }

{ tb0073.pas }
{  Shows Missing High() (internal) function.             OK 0.99.6 (MVC) }

type

 tb_array_type_expressions_tHugeArray = array [ 1 .. High(Word) ] of byte;

{ tb0108.pas }
{ packed array isn't allowed                            OK 0.99.6 (FK) }

type
   tb_array_type_expressions_myarray = packed array[0..10] of longint;

{ tb0361.pas }
type
  tb_array_type_expressions_e=(tb_array_type_expressions_one,tb_array_type_expressions_two,tb_array_type_expressions_three);

var
  tb_array_type_expressions_a : array[0..cardinal(tb_array_type_expressions_two)+1] of byte;


{$pop}

{ Case tb_arrays_default_run_01.pas }
{$push}
{ Consolidated feature cases; original case IDs and settings are retained below. }


{ Source group: tb_arrays_default_run_01.pas }
{$push}

{ Case tb0012.pas }
{$push}
{ Old file: tbs0015.pas }
{  tests for wrong allocated register for return result of floating function (allocates int register)       OK 0.9.2 }

type
    tb0012_realgr=    array [1..1000]  of double;
var
    tb0012_sx    :tb0012_realgr;
    tb0012_i     :integer;
    tb0012_stemp :double;
{$pop}

{ Case tb0026.pas }
{$push}
{ Old file: tbs0030.pas }
{  tests type conversations in typed consts            OK 0.9.6 }

const
   tb0026_a : array[0..1] of real = (1,1);
{$pop}

{ Case tb0027.pas }
{$push}
{ Old file: tbs0031.pas }
{  tests array[boolean] of ....                        OK 0.9.8 }

var
   tb0027_a : array[boolean] of longint;
{$pop}

{ Case tb0029.pas }
{$push}
{ Old file: tbs0033.pas }
{  tests var p : pchar; begin p:='c'; end.             OK 0.9.9 }

var
   tb0029_p1 : pchar;
   tb0029_p2 : array[0..10] of char;
   tb0029_s : string;
   tb0029_c : char;
{$pop}

{ Case tb0047.pas }
{$push}
{ Old file: tbs0053.pas }
{  shows a problem with open arrays                     OK 0.99.1 (FK) }

procedure tb0047_abc(var tb_arrays_default_run_01_a : array of char);

  begin
     // error: a:='asdf';
  end;

var
   tb0047_c : array[0..10] of char;
{$pop}

{ Case tb0049.pas }
{ Equivalent case tb0065.pas: identical declarations and empty main block. }
{$push}
{ Old file: tbs0055.pas }
{  internal error 10 (means too few registers           OK 0.99.1 (FK) }

type
   tb0049_tarraysingle = array[0..1] of single;

procedure tb0049_test(var tb_arrays_default_run_01_a : tb0049_tarraysingle);

var
   tb0049_i,tb0049_j,tb0049_k : integer;

begin
   tb_arrays_default_run_01_a[tb0049_i]:=tb_arrays_default_run_01_a[tb0049_j]-tb_arrays_default_run_01_a[tb0049_k];
end;
{$pop}

{ Case tb0098.pas }
{$push}
{ Old file: tbs0116.pas }
{ Exercise a local variable size greater than $ffff. }

Procedure tb0098_test;

Var tb0098_a: Array[1..4000000] of longint;
Begin
End;
{$pop}

{ Case tb0112.pas }
{$push}
{ Old file: tbs0131.pas }
{ internal error 10 with highdimension arrays           OK 0.99.6 (MVC) }

type tb0112_ta = Array[1..2,1..2,1..2,1..2,1..2,1..2,1..3,1..3,1..3,1..3] of Byte;
 tb0112_ta2 = Array[1..2,1..2,1..2] of Byte;

var tb0112_v,tb0112_w: tb0112_ta;
  tb0112_x: tb0112_ta2;
    tb0112_e: longint;
{$pop}

{ Case tb0127.pas }
{$push}
{ Old file: tbs0146.pas }
{ no sizeof() for var arrays and the size is pushed incorrect OK 0.99.7 (PFV) }

procedure tb0127_myfunction(var t : array of char);
begin
  writeln(sizeof(t)); { should be 51 }
  if sizeof(t)<>51 then halt(1);
end;

var
  tb0127_mycharstring : array[0..50] of char;
{$pop}

{ Case tb0153.pas }
{$push}
{ Old file: tbs0183.pas }
{ internal error 10 in secondnot                        OK 0.99.11 (PM) }

type
  tb0153_pbug = ^tb0153_tbug;
  tb0153_tbug = array[1..1] of boolean;

var
  tb0153_left : tb0153_pbug;
  tb0153_test : longint;
{$pop}

{ Case tb0176.pas }
{$push}
{ Old file: tbs0210.pas }
{ fillchar should accept boolean value also !!         OK 0.99.11 (PM) }

{ boolean args are accepted for fillchar in BP }

  var tb0176_l : array[1..10] of boolean;
{$pop}

{ Case tb0052.pas }
{$push}
{ Old file: tbs0058.pas }
{  causes an internal error 10 (problem with getregisterOK 0.99.1 (FK) }

{$r+}
var
   tb0052_a1 : array[0..1,0..1] of word;
   tb0052_a2 : array[0..1,0..1] of longint;
   tb0052_i,tb0052_j,tb0052_l,tb0052_n : longint;
{$pop}


{$pop}

{ Source group: tb_arrays_default_run_02.pas }
{$push}

{ Case tb0186.pas }
{$push}
{ Old file: tbs0220.pas }
{ array of char overloading problem with strings        OK 0.99.11 (PFV) }

type
  tb0186_a = array[1..100] of char;

var
  tb0186_a1 : tb0186_a;
  tb0186_s : string;
{$pop}

{ Case tb0233.pas }
{$push}
{ Old file: tbs0273.pas }
{ small array pushing to array of char procedure is wrong OK 0.99.13 (PFV) }

Var tb0233_chararray : Array[1..4] Of Char;

    tb0233_s : String;
{$pop}

{ Case tb0260.pas }
{$push}
{ Old file: tbs0303.pas }
{ One more InternalError(10) out of register !         OK 0.99.13 (FK) }

  type
    tb0260_intarray = array[1..1000,0..1] of longint;

  procedure tb0260_test;
   var
     tb0260_ar : tb0260_intarray;
     tb0260_i : longint;
  procedure local;
   begin
    tb0260_i:=4;
    tb0260_ar[tb0260_i,0]:=56;
    tb0260_ar[tb0260_i-1,0]:=pred(tb0260_ar[tb0260_i,0]);
   end;
  begin
    local;
  end;
{$pop}

{ Case tb0288.pas }
{$push}
{ Old file: tbs0340.pas }
{  }

{$packenum 1}
type
  tb0288_t = (tb_arrays_default_run_01_a,tb_arrays_default_run_01_b,tb_arrays_default_run_01_c,tb_arrays_default_run_01_d,tb_arrays_default_run_01_e);

const tb0288_arr:  array[0..4] of tb0288_t = (tb_arrays_default_run_01_a,tb_arrays_default_run_01_b,tb_arrays_default_run_01_c,tb_arrays_default_run_01_d,tb_arrays_default_run_01_e);

var
  tb0288_x: byte;
{$pop}

{ Case tb0321.pas }
{$push}
{ this test program test allocation of large pieces of stack }
{ this is especially necessary for win32                     }

procedure tb0321_p1(tb0321_a : array of byte);

  var
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

procedure tb0321_p2;

  var
     tb0321_a : array[0..20000] of byte;
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

procedure tb0321_p3;

  var
     tb0321_a : array[0..200000] of byte;
     tb0321_i : longint;

  begin
     for tb0321_i:=0 to high(tb0321_a) do
       tb0321_a[tb0321_i]:=0;
  end;

var
   tb0321_a : array[0..10000] of byte;
{$pop}

{ Case tb0327.pas }
{$push}
type tb0327_ta = array[1..1,1..100] of integer;

procedure tb0327_t(tb0327_a: tb0327_ta);
begin
end;

var tb0327_a: tb0327_ta;
{$pop}

{ Case tb0363.pas }
{$push}
procedure tb0363_p1(const tb0363_a:array of byte);
var
  tb0363_l : longint;
begin
  tb0363_l:=length(tb0363_a);
  writeln('openarray length: ',tb0363_l);
  if tb0363_l<>9 then
   halt(1);
end;

var
  tb0363_a : array[2..10] of byte;
  tb0363_l : longint;
{$pop}

{ Case tb0392.pas }
{$push}
var
  tb0392_l: longint;
  tb0392_a: array[0..1] of char;
{$pop}

{ Case tb0418.pas }
{$push}
procedure tb0418_array_test(tb_arrays_default_run_01_b: integer; tb0418_parr: array of word; tb0418_c: integer);
begin
end;
{$pop}

{ Case tb0419.pas }
{$push}
var
  tb0419_nc : integer;
  tb0419_test_w : word;

procedure tb0419_array_test(tb_arrays_default_run_01_b: integer; tb0419_parr: array of word; tb0419_c: integer);cdecl;
begin
  tb0419_nc:=tb0419_c;
  tb0419_test_w:=tb0419_parr[2];
end;
{$pop}

{ Case tb0420.pas }
{$push}
procedure tb0420_array_test(tb_arrays_default_run_01_b: integer; tb0420_parr: array of word; tb0420_c: integer);cdecl;
begin
end;

var
 tb0420_a: array[1..12] of word;
{$pop}

{ Case tb0446.pas }
{$push}
var
  tb0446_a : array[0..9] of char;
  tb0446_pc : pchar;
{$pop}


{$pop}

{ Source group: tb_arrays_default_run_03.pas }
{$push}

{ Case tb0494.pas }
{$push}
{ the test checks only if the syntax is possible }
var
  tb0494_ca : array[0..1000] of char;
  tb0494_p1 : pchar;
{$pop}

{ Case tb0529.pas }
{$push}
{ It tests conversion from "array of char" to "array of PChar" }

function tb0529_dotest(params: array of PChar): string;
var
  tb0529_i: integer;
  tb0529_res: string;
begin
  tb0529_res:='';
  for tb0529_i:=Low(params) to High(params) do
    tb0529_res:=tb0529_res + params[tb0529_i];
  tb0529_dotest:=tb0529_res;
end;

var
  tb0529_s: string;
{$pop}

{ Case tb0541.pas }
{$push}
const
  tb0541_teststr: widestring = 'Test';

var
  tb0541_buf: array[0..10] of widechar;
  tb0541_s: widestring;
{$pop}

{ Case tb0555.pas }
{$push}
function tb0555_dotest(params: array of PWideChar): WideString;
var
  tb0555_i: integer;
  tb0555_res: WideString;
begin
  tb0555_res:='';
  for tb0555_i:=Low(params) to High(params) do
    tb0555_res:=tb0555_res + params[tb0555_i];
  tb0555_dotest:=tb0555_res;
end;

var
  tb0555_s: WideString;
{$pop}

{ Case tb0708.pas }
{$push}
procedure tb0708_fillsomeqwords;
var
	tb0708_q: array[0 .. 9] of uint64;
	tb0708_rep: int32;
begin
	for tb0708_rep := 1 to 128 * 1024 * 1024 do
		FillQWord(tb0708_q, length(tb0708_q), 1234);
end;
{$pop}

{ Case tw0852.pas }
{$push}
type
  tw0852_tfloat80array = array [0..1000000] of Extended;

procedure tw0852_addfloat80proc(var Vector1; const Vector2; tw0852_count: Integer);
var
  tw0852_i: Integer;
begin
  for tw0852_i:=0 to tw0852_count - 1 do
    tw0852_tfloat80array(Vector1)[tw0852_i]:=tw0852_tfloat80array(Vector1)[tw0852_i] + tw0852_tfloat80array(Vector2)[tw0852_i];
end;
{$pop}

{ Case tw0879.pas }
{$push}
TYPE
        tw0879_ta      = ARRAY[3..8] OF word;
VAR
        tw0879_aa      : ^tw0879_ta;
        tw0879_i       : word;
{$pop}

{ Case tw0881.pas }
{$push}
TYPE
    tw0881_byteset     = SET OF 0..7;
    tw0881_booleanarray    = ARRAY[0..HIGH(word) DIV 8] OF tw0881_byteset;
    tw0881_booleanarraypointer = ^tw0881_booleanarray;

PROCEDURE tw0881_setbooleanarray(  CONST p     : tw0881_booleanarraypointer;
                            CONST index : word );
BEGIN
    INCLUDE(p^[index DIV 8],index MOD 8)
END;
{$pop}

{ Case tw1275.pas }
{$push}
var
  tw1275_sizes:array [1..3] of int64;
  tw1275_i:integer;

function tw1275_count:int64;
var
  tw1275_c:int64;
begin
  tw1275_c:=1;

  writeln(tw1275_c);
  tw1275_count:=tw1275_c;
end;
{$pop}

{ Case tw14307.pas }
{$push}
var
  tw14307_buf: array[0..3] of widechar;
  tw14307_s: string;
{$pop}

{ Case tw14812.pas }
{$push}
type
  tw14812_stdstrlong = string;

procedure tw14812_packstr // Convert string to packed array
   ( InStr: tw14812_stdstrlong;
    var tw14812_outarr: packed array of char);
var
  tw14812_i: longint;
begin
  if (low(tw14812_outarr)<>0) or
     (high(tw14812_outarr)<>5) then
    halt(1);
  if (instr<>'abc') then
    halt(2);
  for tw14812_i:=1 to length(instr) do
    tw14812_outarr[tw14812_i-1]:=instr[tw14812_i];
end;

var
  tw14812_a: packed array[5..10] of char;
{$pop}

{ Case tw1567.pas }
{$push}
procedure tw1567_hallo(tb_arrays_default_run_01_a:array of word);
begin
   writeln(tb_arrays_default_run_01_a[0],' ',tb_arrays_default_run_01_a[1],' ',tb_arrays_default_run_01_a[2]);
   if (tb_arrays_default_run_01_a[0]<>999) or
      (tb_arrays_default_run_01_a[1]<>999) or
      (tb_arrays_default_run_01_a[2]<>999) then
    halt(1);
end;
{$pop}


{$pop}

{ Source group: tb_arrays_default_run_04.pas }
{$push}

{ Case tw1938.pas }
{$push}
{$inline on }

var tw1938_a: array [0..1] of Integer;

function tw1938_f: Integer; inline;
begin
  tw1938_f := tw1938_a[1];
end;
{$pop}

{ Case tw2280.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2280 }
{ Submitted by "Yakov Sudeikin" on  2002-12-23 }
{ e-mail: yashka@exebook.com }
var
 tw2280_a: array of string;
{$pop}

{ Case tw2525.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2525 }
{ Submitted by "Pavel V. Ozerski" on  2003-06-05 }
{ e-mail: ozerski@list.ru }
procedure tw2525_myproc(x:array of longint);
 begin
   writeln(high(x));
   if high(x)<>2 then
     halt(1);
 end;
type
 tw2525_tmyenum=(tb_arrays_default_run_01_My1,tb_arrays_default_run_01_My2,tb_arrays_default_run_01_My3);
var
 tw2525_ar:array[tw2525_tmyenum]of longint;
{$pop}

{ Case tw25349.pas }
{$push}
procedure tw25349_trashstack;
var
  tw25349_a: array[0..high(word)] of byte;
begin
  fillchar(tw25349_a,sizeof(tw25349_a),$ff);
end;

procedure tw25349_test;
var
  tw25349_s1,tw25349_s2,tw25349_s3,tw25349_s4: ansistring;
begin
  tw25349_s2:='';
  tw25349_s3:='';
  tw25349_s4:='';
  tw25349_s1:=tw25349_s2+tw25349_s3+tw25349_s4;
  if tw25349_s1<>'' then
    halt(1);
end;
{$pop}

{ Case tw2561.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2561 }
{ Submitted by "Nikolay Nikolov" on  2003-07-06 }
{ e-mail: nickysn1983@netscape.net }
Procedure tw2561_tralala(Var tw2561_q);

Begin
  Writeln(SizeOf(tw2561_q));
  if sizeof(tw2561_q)<>0 then
    halt(1);
End;

Var
  tw2561_q : Integer;
  tw2561_w : Array[1..10] Of Integer;
{$pop}

{ Case tw2620.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2620 }
{ Submitted by "Louis Jean-Richard" on  2003-08-04 }
{ e-mail: l.jean-richard@bluewin.ch }
CONST
        tw2620_prime   : ARRAY[1 .. 4] OF cardinal =
        ( 536870909, 1073741789, 2147483647, 4294967291);
{$pop}

{ Case tw2803.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2803 }
{ Submitted by "C Western" on  2003-11-22 }
{ e-mail: mftq75@dsl.pipex.com }

{$T+}
var
  tw2803_a: array of Double;
{$pop}

{ Case tw2876.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2876 }
{ Submitted by "marco (gory bugs department)" on  2004-01-04 }
{ e-mail:  }
function tw2876_strtoppchar(const tw2876_args:array of ansistring):ppchar;

begin
end;

function tw2876_execl (filename:ansistring;const tw2876_args:array of ansistring):integer;

var tw2876_p:ppchar;

begin
 tw2876_p:=tw2876_strtoppchar(tw2876_args);
end;

procedure tw2876_myexec (filename:ansistring;const tw2876_args:array of ansistring);

begin
 tw2876_execl(filename,tw2876_args);
end;
{$pop}

{ Case tw2912.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2912 }
{ Submitted by "Bill Pearce" on  2004-01-19 }
{ e-mail: pearceg@post.queensu.ca }
procedure tw2912_setrowcount(n,m : integer);
var
  tw2912_tmp : array of array of string;
begin
  SetLength(tw2912_tmp, n, m);
end;
{$pop}

{ Case tw3012.pas }
{$push}
Type tw3012_char2=Array[1..2] of char;

var tw3012_c1,tw3012_c2:tw3012_char2;
    tw3012_st:string;

Procedure tw3012_writelength(s:string; tw3012_shouldbe: longint);
begin
  WriteLn(s+' ',Length(s));
  if length(s) <> tw3012_shouldbe then
    halt(1);
end;
{$pop}

{ Case tw3113.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3113 }
{ Submitted by "Michalis Kamburelis" on  2004-05-23 }
{ e-mail: michalis@camelot.homedns.org }
type
  tw3113_tvector3 = array[0..2]of Integer;

procedure tw3113_p(const tb_arrays_default_run_01_A:array of tw3113_tvector3);
var tw3113_i:Integer;
begin
 Writeln(High(tb_arrays_default_run_01_A));

 if High(tb_arrays_default_run_01_A)<>0 then
   begin
     writeln('Error!');
     halt(1);
   end;

 for tw3113_i:=0 to High(tb_arrays_default_run_01_A) do
  Writeln('  ', tb_arrays_default_run_01_A[tw3113_i][0], ' ', tb_arrays_default_run_01_A[tw3113_i][1], ' ', tb_arrays_default_run_01_A[tw3113_i][2]);
end;

const tw3113_a1:tw3113_tvector3 = (1, 2, 3);
{$pop}

{ Case tw33004.pas }
{$push}
const
  tw33004_inputs: array[0..2] of QWord = (500, $4563918244F40000,QWord($8AC7230489E80000));

var tw33004_x, tw33004_y: QWord; tw33004_c: Integer;
{$pop}


{$pop}

{ Source group: tb_arrays_default_run_05.pas }
{$push}

{ Case tw3320.pas }
{$push}
var
  tw3320_a,tw3320_b:array of integer;
  tw3320_i :integer;
  tw3320_err : boolean;
{$pop}

{ Case tw3612.pas }
{$push}
{ Source provided for Free Pascal Bug Report 3612 }
{ Submitted by "Alexey Barkovoy" on  2005-01-30 }
{ e-mail: clootie@ixbt.com }
var
  tw3612_str: array[0..200] of WideChar;
  tw3612_w: PWideChar;
  tw3612_s: String;
{$pop}

{ Case tw36157.pas }
{$push}
type
  tw36157_tenum = (tb_arrays_default_run_01_EnVal1, tb_arrays_default_run_01_EnVal2, tb_arrays_default_run_01_EnVal3, tb_arrays_default_run_01_EnVal4);
  tw36157_tset = set of tw36157_tenum;
  tw36157_tbitpacksetarray2 = bitpacked array [0..1, 0..2] of tw36157_tset;
const
  tw36157_gcbitpacksetarray2 : tw36157_tbitpacksetarray2 = (([tb_arrays_default_run_01_EnVal3, tb_arrays_default_run_01_EnVal1], [], [tb_arrays_default_run_01_EnVal3]), ([],[tb_arrays_default_run_01_EnVal1,tb_arrays_default_run_01_EnVal2],[tb_arrays_default_run_01_EnVal1]));
{$pop}

{ Case tw39897.pas }
{$push}
var
  tw39897_a,tw39897_b : array of longint;
{$pop}

{ Case tw4115.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4115 }
{ Submitted by "Alexey Chernobayev" on  2005-06-25 }
{ e-mail: alexch@caravan.ru }
var
  tw4115_a: array [WideChar] of Char;
  tw4115_w: WideChar;
{$pop}

{ Case tw4496.pas }
{$push}
type
  //BoolDeriv = Boolean; //gives no internal error
  tw4496_boolderiv = false..true;

var
  tw4496_a: array[tw4496_boolderiv] of char;
{$pop}

{ Case tw4616.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4616 }
{ Submitted by "Simon Felix" on  2005-12-18 }
{ e-mail: de@royalinc.ath.cx }
var
  tw4616_t:array[0..128] of widechar;
{$pop}

{ Case tw6960.pas }
{$push}
function tw6960_somefunc(var Res: array of Double): Integer;
begin
  // do something
  writeln(High(Res));
end;

var
  tw6960_d: Double;
  tw6960_darr: array[1..3] of Double;
{$pop}

{ Case tw7143.pas }
{$push}
var tw7143_a,tw7143_b: array[0..99] of byte;
    tw7143_i: integer;
    tw7143_c: byte;
{$pop}


{$pop}


{$pop}

{ Case tw0859.pas }
{$push}
type
  tw0859_TBoolArray = array [0..1048576] of Boolean;

procedure tw0859_OrBoolProc(var Vector1; const Vector2; Count: Integer);
var
  tw0859_I: Integer;
begin
  for tw0859_I:=0 to Count - 1 do
    tw0859_TBoolArray(Vector1)[tw0859_I]:=tw0859_TBoolArray(Vector1)[tw0859_I] or tw0859_TBoolArray(Vector2)[tw0859_I];
end;

var
  tw0859_A, tw0859_B: array [0..10] of Boolean;
  tw0859_I: Integer;
const
  tw0859_error : boolean = false;

{$pop}

{ Case tw15694.pas }
{$push}
type
 tw15694_TEn=array [0..63] of boolean;
var
  tw15694_WlEnb:array [0..511] of tw15694_TEn;

procedure tw15694_ReadMask;
var
  I,ICd,J:ptrint;
  b: boolean;
begin
  for ICd:=0 to 10 do
    begin
      J:=icd;
{$R-}
      for I:=0 to 3 do
        begin
          tw15694_WlEnb[ICd,I]:=J and $01<>0;
          b:=J and $01<>0;
          if tw15694_WlEnb[ICd,I]<>b then
            halt(1);
          J:=J shr 1;
       end;
{$R+}
    end;
end;


{$pop}

{ Case tw24007.pas }
{$push}
var
    tw24007_str: bitpacked array [1..6] of 'a'..'z';
    tw24007_i: integer;
    tw24007_ch: char;
    tw24007_error: boolean;

{$pop}

{ Case tw25956.pas }
{$push}
{$r+}

{$t+}
var
  tw25956_a : array of integer;
  tw25956_i : integer;

procedure tw25956_Foo(var c: array of integer);
begin
  writeln( (@c)^[1] );
  tw25956_i:=(@c)^[1];
end;


{$pop}

{ Case tw3210.pas }
{$push}
Const
    tw3210_N   = 10000;

Var
    tw3210_count       : array[0..200] of int64;
    tw3210_i , tw3210_tot     : longint;


{$pop}

{ Case tw38413.pas }
{$push}
var
  tw38413_arr : array[-1..140] of byte=(4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,
    4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4);
  tw38413_index , tw38413_value : byte; // unsigned byte - important

{$pop}

{ Case tw3864.pas }
{$push}
{ Explicitly disable range check as the test
  is not about this but does generate a range check error
  for the index of rasteriso array }
{$R-}

{ Source provided for Free Pascal Bug Report 3864 }
{ Submitted by "Jernej" on  2005-04-01 }
{ e-mail: jernejcoder@gmail.com }
const
 tw3864_rasteriso: array[0..2] of byte = // this is WAY too big
 (
   $00, $00, $00
 );

procedure tw3864_glBitMap(const pb:pbyte);cdecl;
begin
end;

var
  tw3864_i : longint;

{$pop}

{ Case tw40292.pas }
{$push}
var
  tw40292_arr: array of longint;
  tw40292_x: longint;

{$pop}

{ Case tw4669.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4669 }
{ Submitted by "C.Stolk" on  2006-01-07 }
{ e-mail: C.stolk@cos.rotterdam.nl }


const
  tw4669_nul1:array[boolean] of byte=(0,1);
var
  tw4669_b,tw4669_j,tw4669_h:byte;

{$pop}

begin

{ Case tb0008.pas }
{$push}
{$message don't know how to make a test from bug0011 (PM)}
begin
end;
{$pop}

{ Case tb_array_type_expressions.pas }
{$push}

begin

end;
{$pop}

{ Case tb_arrays_default_run_01.pas }
{$push}

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
{$push}
{$pop}
{$push}
{$r+}
{$pop}
{$pop}
{$push}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$packenum 1}
{$pop}
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
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$pop}
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
{$push}
{$pop}
{$push}
{$pop}
{$pop}
{$push}
{$push}
{$inline on }
{$pop}
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
{$push}
{$T+}
{$pop}
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
{$pop}
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
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$pop}
begin
  { Source group: tb_arrays_default_run_01.pas }
  {$push}

begin
  { Case tb0012.pas }
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

  { Case tb0027.pas }
  {$push}

  begin
tb0027_a[true]:=1234;
   tb0027_a[false]:=123;
  end;
  {$pop}

  { Case tb0029.pas }
  {$push}

  begin
tb0029_p1:='c';
   tb0029_s:='c';
   { this isn't allowed
   p1:=c;
   }
  end;
  {$pop}

  { Case tb0047.pas }
  {$push}

  begin
tb0047_abc(tb0047_c);
   writeln(tb0047_c);
   // error: writeln(a);
  end;
  {$pop}

  { Case tb0112.pas }
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

  { Case tb0127.pas }
  {$push}

  begin
tb0127_myfunction(tb0127_mycharstring);
  if sizeof(tb0127_mycharstring)<>51 then halt(1);
  end;
  {$pop}

  { Case tb0153.pas }
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

  { Case tb0176.pas }
  {$push}

  begin
fillchar(tb0176_l,sizeof(tb0176_l),true);
  end;
  {$pop}

  { Case tb0052.pas }
  {$push}
{$R+}
begin
   tb0052_a1[tb0052_i,tb0052_j]:=tb0052_a2[tb0052_l,tb0052_n];
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_default_run_02.pas }
  {$push}

begin
  { Case tb0186.pas }
  {$push}

  begin
tb0186_a1[1]:='1';tb0186_a1[2]:='2';tb0186_a1[3]:='3';
  tb0186_a1[4]:='4';tb0186_a1[5]:='5';tb0186_a1[6]:='6';
  tb0186_a1[7]:='7';tb0186_a1[8]:='8';tb0186_a1[9]:='9';
  tb0186_a1[10]:='0';tb0186_a1[11]:='1';
  tb0186_s:=Copy(tb0186_a1,1,10);
  if tb0186_s<>'1234567890' then halt(1);
  writeln('ok');
  end;
  {$pop}

  { Case tb0233.pas }
  {$push}

  begin
tb0233_chararray:='BUG?';
 tb0233_s:=tb0233_chararray;
 WriteLn(tb0233_s);         { * This is O.K. * }
 WriteLn(tb0233_chararray); { * GENERAL PROTECTION FAULT. * }
 if tb0233_chararray<>'BUG?' then
   begin
     Writeln('Error comparing charaay to constant string');
     Halt(1);
   end;
  end;
  {$pop}

  { Case tb0260.pas }
  {$push}

  begin
tb0260_test;
  end;
  {$pop}

  { Case tb0288.pas }
  {$push}
{$packenum 1}
  begin
tb0288_x := 0;
  writeln(ord(tb0288_arr[tb0288_x]),' ',ord(tb0288_arr[tb0288_x+1]),' ',ord(tb0288_arr[tb0288_x+2]),' ',ord(tb0288_arr[tb0288_x+3]),' ',ord(tb0288_arr[tb0288_x+4]));
  for tb0288_x:=0 to 4 do
   if ord(tb0288_arr[tb0288_x])<>tb0288_x then
    begin
      writeln('error in {$packenum 1}');
      halt(1);
    end;
  end;
  {$pop}

  { Case tb0321.pas }
  {$push}

  begin
tb0321_p1(tb0321_a);
   tb0321_p2;
   tb0321_p3;
  end;
  {$pop}

  { Case tb0327.pas }
  {$push}

  begin
tb0327_t(tb0327_a);
  end;
  {$pop}

  { Case tb0363.pas }
  {$push}

  begin
tb0363_l:=length(tb0363_a);
  writeln('length of a ',tb0363_l);
  if tb0363_l<>9 then
   halt(1);

  tb0363_p1(tb0363_a);
  end;
  {$pop}

  { Case tb0392.pas }
  {$push}

  begin
tb0392_l := 50;
  str(tb0392_l,tb0392_a);
  if tb0392_a <> '50' then
    begin
      writeln('error');
      halt(1);
    end;
  end;
  {$pop}

  { Case tb0418.pas }
  {$push}

  begin
tb0418_array_test(0,[12,33,45],0);
  end;
  {$pop}

  { Case tb0419.pas }
  {$push}

  begin
tb0419_nc:=5;
  tb0419_test_w:=$abcd;
  tb0419_array_test(0,[1,2,3,4],56);
  if (tb0419_nc<>56) or (tb0419_test_w<>3) then
    begin
      Writeln('Wrong code generated');
    end;
  end;
  {$pop}

  { Case tb0420.pas }
  {$push}

  begin
tb0420_array_test(0,tb0420_a,0);
  end;
  {$pop}

  { Case tb0446.pas }
  {$push}

  begin
tb0446_a:='1';
  if tb0446_a=nil then
   halt(1);
  tb0446_pc:=@tb0446_a;
  if tb0446_pc<>'1' then
   halt(1);
  writeln('OK')
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_default_run_03.pas }
  {$push}

begin
  { Case tb0494.pas }
  {$push}

  begin
tb0494_p1:=nil;
  if (tb0494_ca-tb0494_p1)=0 then
    halt(1);
  tb0494_p1:=tb0494_ca;
  end;
  {$pop}

  { Case tb0529.pas }
  {$push}

  begin
tb0529_s:=tb0529_dotest(['1', '2', '3']);
  if tb0529_s <> '123' then begin
    writeln('Test failed. S=', tb0529_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tb0541.pas }
  {$push}

  begin
Move(tb0541_teststr[1], tb0541_buf[0], (Length(tb0541_teststr) + 1)*SizeOf(widechar));
  tb0541_s:=tb0541_buf;
  writeln(tb0541_s);
  tb0541_buf[0]:=#0;
  tb0541_s:=tb0541_buf;
  end;
  {$pop}

  { Case tb0555.pas }
  {$push}

  begin
tb0555_s:=tb0555_dotest(['аб', 'вг', 'де']);
  if tb0555_s <> 'абвгде' then begin
    writeln('Test failed. S=', tb0555_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tb0708.pas }
  {$push}

  begin
tb0708_fillsomeqwords;
  end;
  {$pop}

  { Case tw0879.pas }
  {$push}

  begin
NEW(tw0879_aa);
   FOR tw0879_i:=LOW(tw0879_aa^) TO HIGH(tw0879_aa^) DO
     tw0879_aa^[tw0879_i]:=0;
  end;
  {$pop}

  { Case tw1275.pas }
  {$push}

  begin
tw1275_i:=1;
    tw1275_sizes[tw1275_i]:=tw1275_count();
    writeln(tw1275_sizes[tw1275_i]);
  end;
  {$pop}

  { Case tw14307.pas }
  {$push}

  begin
tw14307_buf[0]:='A';
  tw14307_buf[1]:='B';
  tw14307_buf[2]:='C';
  tw14307_buf[3]:=#0;

  tw14307_s:=Copy(tw14307_buf, 2, MaxInt);
  if tw14307_s = 'BC' then
    writeln('OK')
  else begin
    writeln('FAILED: ', tw14307_s);
    Halt(1);
  end;
  end;
  {$pop}

  { Case tw14812.pas }
  {$push}

  begin
tw14812_packstr('abc',tw14812_a);
  if (tw14812_a[5]<>'a') or
     (tw14812_a[6]<>'b') or
     (tw14812_a[7]<>'c') then
    halt(1);
  end;
  {$pop}

  { Case tw1567.pas }
  {$push}

  begin
tw1567_hallo([999,999,999]);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_default_run_04.pas }
  {$push}

begin
  { Case tw1938.pas }
  {$push}
{$inline on }
  begin
tw1938_a[0] := 1234;
  tw1938_a[1] := 5678;
  WriteLn(tw1938_f); { writes 1234 }
  if tw1938_f<>5678 then
   begin
     Writeln('ERROR!');
     Halt(1);
   end;
  end;
  {$pop}

  { Case tw2280.pas }
  {$push}

  begin
tw2280_a := nil;
 if tw2280_a = nil then;
  end;
  {$pop}

  { Case tw2525.pas }
  {$push}

  begin
tw2525_myproc(tw2525_ar);
  end;
  {$pop}

  { Case tw25349.pas }
  {$push}

  begin
tw25349_trashstack;
  tw25349_test;
  end;
  {$pop}

  { Case tw2561.pas }
  {$push}

  begin
tw2561_tralala(tw2561_q);
  tw2561_tralala(tw2561_w);
  end;
  {$pop}

  { Case tw2620.pas }
  {$push}

  begin
WriteLn( 'HIGH(cardinal) = ', HIGH(cardinal) );
        WriteLn( '4294967291 < HIGH(cardinal) ', (4294967291 < HIGH(cardinal)) , ' !?');
    if not(4294967291 < HIGH(cardinal)) then
      halt(1);
        WriteLn(tw2620_prime[4])
  end;
  {$pop}

  { Case tw2803.pas }
  {$push}
{$T+}
  begin
SetLength(tw2803_a,100);
  end;
  {$pop}

  { Case tw2876.pas }
  {$push}

  begin
tw2876_myexec('',['','']);
  end;
  {$pop}

  { Case tw2912.pas }
  {$push}

  begin
tw2912_setrowcount(10,2);
  end;
  {$pop}

  { Case tw3012.pas }
  {$push}

  begin
tw3012_c1:=#0#65;
  tw3012_c2:=#66#0;
  tw3012_st:=tw3012_c1+tw3012_c2;
  tw3012_writelength(tw3012_st,4);	{BP:4; FP:1}
  tw3012_writelength(tw3012_c1,2);	{BP:2; FP:0}
  tw3012_writelength(tw3012_c2,2);	{BP:2; FP:1}
  tw3012_writelength(tw3012_c1+tw3012_c2,4);	{BP:4; FP:1}
  tw3012_writelength(tw3012_c2+tw3012_c1,4);	{BP:4; FP:1}
  end;
  {$pop}

  { Case tw3113.pas }
  {$push}

  begin
tw3113_p(tw3113_a1);
 { When changed to P([A1]), works OK. }
  end;
  {$pop}

  { Case tw33004.pas }
  {$push}

  begin
for tw33004_c := Low(tw33004_inputs) to High(tw33004_inputs) do
  begin
    tw33004_x := tw33004_inputs[tw33004_c];
    tw33004_y := tw33004_x div QWord($8AC7230489E80000);
    WriteLn(tw33004_x, ' div 10,000,000,000,000,000,000 = ', tw33004_y);
  end;
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_arrays_default_run_05.pas }
  {$push}

begin
  { Case tw3320.pas }
  {$push}

  begin
setlength(tw3320_a,3);
  tw3320_a[0]:=1;
  tw3320_a[1]:=2;
  tw3320_a[2]:=3;
  tw3320_b:=tw3320_a;
  writeln('len b= ',length(tw3320_b)); // output is 3: OK
  if length(tw3320_b)<>3 then
    tw3320_err:=true;
  setlength(tw3320_a,0);
  writeln('len a= ',length(tw3320_a)); // output is 0: OK
  if length(tw3320_a)<>0 then
    tw3320_err:=true;
  for tw3320_i:=1 to length(tw3320_b) do writeln(tw3320_b[tw3320_i-1]); // output is 1: BAD
  writeln('len b= ',length(tw3320_b)); // output is 1: BAD, must be 3
  if length(tw3320_b)<>3 then
    tw3320_err:=true;
  if tw3320_err then
    halt(1);
  end;
  {$pop}

  { Case tw3612.pas }
  {$push}

  begin
tw3612_str:= 'abcdefgh';
  tw3612_w:= tw3612_str;
  tw3612_s:= tw3612_w;
  WriteLn(tw3612_s);
  tw3612_w:= tw3612_str + 2;
  tw3612_s:= tw3612_w;
  WriteLn(tw3612_s); // will output "bcdefgh" instead of "cdefgh"
  if tw3612_s<>'cdefgh' then
    halt(1);
  end;
  {$pop}

  { Case tw36157.pas }
  {$push}

  begin
if tw36157_gcbitpacksetarray2[0,0]<>[tb_arrays_default_run_01_EnVal3, tb_arrays_default_run_01_EnVal1] then
    halt(1);
  if tw36157_gcbitpacksetarray2[0,2]<>[tb_arrays_default_run_01_EnVal3] then
    halt(2);
  if tw36157_gcbitpacksetarray2[1,1]<>[tb_arrays_default_run_01_EnVal1,tb_arrays_default_run_01_EnVal2] then
    halt(3);
  end;
  {$pop}

  { Case tw39897.pas }
  {$push}

  begin
tw39897_b:=nil;
  SetLength(tw39897_a,5);
  tw39897_a[1]:=1234;
  DynArrayAssign(pointer(tw39897_b),pointer(tw39897_a),TypeInfo(tw39897_a));
  if (length(tw39897_b)<>5) or (tw39897_b[1]<>1234) then
    halt(1);
  end;
  {$pop}

  { Case tw4115.pas }
  {$push}

  begin
tw4115_a['a'] := 'b'; // Ok
  tw4115_w := 'c';

  tw4115_a[tw4115_w] := 'd';
  end;
  {$pop}

  { Case tw4496.pas }
  {$push}

  begin
tw4496_a[true] := 'a'; //ierror 99080501 here
  end;
  {$pop}

  { Case tw4616.pas }
  {$push}

  begin
//works as expected
  //t:='ab';

  //works as expected
  //t:=char(65)+'ab';

  //doesn't result in 'Aab' (result is 'A',#4190)
  //t:=widechar(65)+'ab';

  //this crashes the compiler
  tw4616_t:=widechar(65)+'abc';
  end;
  {$pop}

  { Case tw6960.pas }
  {$push}

  begin
tw6960_somefunc(tw6960_d); // Delphi accepts this, FPC does not
  tw6960_somefunc(tw6960_darr); // OK
  end;
  {$pop}

  { Case tw7143.pas }
  {$push}

  begin
for tw7143_i:=0 to 99 do tw7143_a[tw7143_i]:=tw7143_i;
tw7143_b:=tw7143_a;

writeln('The same:',comparedword(tw7143_a[0],tw7143_b[0],25));
writeln('All other results should be negative.');

for tw7143_i:=0 to 99 do
  begin
  tw7143_c:=tw7143_b[tw7143_i];
  tw7143_b[tw7143_i]:=200;
  writeln(tw7143_i:3,' ',comparedword(tw7143_a[0],tw7143_b[0],25));
  tw7143_b[tw7143_i]:=tw7143_c;
  end;
  end;
  {$pop}


end;
  {$pop}

end;
{$pop}

{ Case tw0859.pas }
{$push}

begin
  for tw0859_I:=0 to High(tw0859_A) do tw0859_A[tw0859_I]:=False;
  for tw0859_I:=0 to High(tw0859_B) do tw0859_B[tw0859_I]:=True;
  tw0859_OrBoolProc(tw0859_A, tw0859_B, SizeOf(tw0859_A));
  for tw0859_I:=0 to High(tw0859_A) do
    begin
      write(tw0859_A[tw0859_I], ' ');
      if not tw0859_A[tw0859_i] then
        tw0859_error:=true;
    end;
  writeln;
  if tw0859_error then
    Halt(1);

end;
{$pop}

{ Case tw15694.pas }
{$push}
{$R-}
{$R+}
begin
  tw15694_readmask
end;
{$pop}

{ Case tw24007.pas }
{$push}

begin
    tw24007_error := false;
    for tw24007_i := 1 to 6 do tw24007_str[tw24007_i] := chr(ord('a')+tw24007_i-1);

    for tw24007_i := 1 to 6 do begin
        write('str[i] = ''', tw24007_str[tw24007_i], '''; ord(str[2]) = ',ord(tw24007_str[tw24007_i]));
	tw24007_ch:=tw24007_str[tw24007_i]; {if we had used directly str[i] in the expression below, the correct value would have been read}
	if tw24007_ch <> chr(ord(tw24007_str[tw24007_i])) then
          begin
           write(' ==> Bug: chr(',ord(tw24007_ch),') read, excpected chr(',ord('a')+tw24007_i-1,')');
           tw24007_error:=true;
          end;
	writeln;
    end;
  CheckCaseExitCode(ord(tw24007_error));
end;
{$pop}

{ Case tw25956.pas }
{$push}
{$r+}
{$t+}
begin
  tw25956_i:=$1234;
  SetLength(tw25956_a,5);
  tw25956_a[0]:= 100;
  tw25956_a[1]:= 101;
  tw25956_foo(tw25956_a);
  if tw25956_i<>101 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw3210.pas }
{$push}

Begin
    fillchar(tw3210_count , sizeof(tw3210_count) , 0);
    for tw3210_i := 1 to tw3210_N do
      begin
          inc(tw3210_count[random(201)]);
      end;
    tw3210_tot := 0;
    for tw3210_i := 0 to 200 do inc(tw3210_tot , tw3210_count[tw3210_i]);
    if (tw3210_tot <> tw3210_N) then
      halt(1);
End;
{$pop}

{ Case tw38413.pas }
{$push}

begin
  tw38413_index:=133; // positive value, which is treated as negative
  tw38413_value:=tw38413_arr[tw38413_index]; // wrong value! Memory access outside array
  if tw38413_value<>4 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw3864.pas }
{$push}
{$R-}
begin
   tw3864_i:=0;
   tw3864_glBitmap(@tw3864_rasteriso[(255 - tw3864_i) * 16]); // Add a character to the current Display list
end;
{$pop}

{ Case tw40292.pas }
{$push}

begin
  tw40292_x:=12+random(0);
  setlength(tw40292_arr,13+random(0));
  if (tw40292_x < length(tw40292_arr)) <> (tw40292_x <= high(tw40292_arr)) then
    halt(1);

  if (length(tw40292_arr) > tw40292_x) <> (tw40292_x <= high(tw40292_arr)) then
    halt(2);

  tw40292_x:=13+random(0);
  if (tw40292_x >= length(tw40292_arr)) <> (tw40292_x > high(tw40292_arr)) then
    halt(3);

  if (length(tw40292_arr) <= tw40292_x) <> (tw40292_x > high(tw40292_arr)) then
    halt(4);
end;
{$pop}

{ Case tw4669.pas }
{$push}

begin
tw4669_b:=0;
for tw4669_j:=1 to 2 do
  begin
  tw4669_h:=
    tw4669_nul1[(tw4669_b=2) and (tw4669_b=tw4669_j)] or
    tw4669_nul1[(tw4669_b=6)or(tw4669_b=tw4669_j)];
  end;
end;
{$pop}

end.
