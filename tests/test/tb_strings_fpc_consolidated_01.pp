{ Consolidated strings regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case taddstr1.pp }
{$push}
{ tests if '' is optimized properly in string concatenations }
var
  taddstr1_s1 : string;
  taddstr1_s2 : string;


{$pop}

{ Case tarray3.pp }
{$push}
{$j+}
{$P+}

type
   tarray3_CharA4 = array [1..4] of char;
   tarray3_CharA6 = array [1..6] of char;
   tarray3_String4 = String[4];
   tarray3_String5 = String[5];
   tarray3_String6 = String[6];
   tarray3_String8 = String[8];

const
   tarray3_car4_1 : tarray3_CharA4 = 'ABCD';
   tarray3_car4_2 : tarray3_CharA4 = 'abcd';
   tarray3_car6_1 : tarray3_CharA6 = 'EFGHIJ';
   tarray3_car6_2 : tarray3_CharA6 = 'efghij';
   tarray3_cst4_1 : tarray3_String4 = 'ABCD';
   tarray3_cst6_2 : tarray3_string6 = 'EFGHIJ';
   tarray3_cst8_1 : tarray3_string8 = 'abcd';
   tarray3_cst8_2 : tarray3_string8 = 'efghij';

var
  tarray3_ar4_1, tarray3_ar4_2 : tarray3_CharA4;
  tarray3_ar6_1, tarray3_ar6_2 : tarray3_CharA6;
  tarray3_st4_1, tarray3_st4_2 : tarray3_string4;
  tarray3_st5_1, tarray3_st5_2 : tarray3_string5;
  tarray3_st6_1, tarray3_st6_2 : tarray3_string6;
  tarray3_st8_1, tarray3_st8_2 : tarray3_string8;
  tarray3_pc : pchar;

const
  tarray3_has_errors : boolean = false;

  procedure tarray3_error(const st : string);
    begin
      Writeln('Error: ',st);
      tarray3_has_errors:=true;
    end;

  procedure tarray3_testvalueconv(st : tarray3_string4);
  begin
    Writeln('st=',st);
    Writeln('Length(st)=',Length(st));
    If Length(st)>4 then
      tarray3_Error('string length too big in calling value arg');
  end;

  procedure tarray3_testconstconv(const st : tarray3_string4);
  begin
    Writeln('st=',st);
    Writeln('Length(st)=',Length(st));
    If Length(st)>4 then
      tarray3_Error('string length too big in calling const arg');
  end;

  procedure tarray3_testvarconv(var st : tarray3_string4);
  begin
    Writeln('st=',st);
    Writeln('Length(st)=',Length(st));
    If Length(st)>4 then
      tarray3_Error('string length too big in calling var arg');
  end;

{ is global switch, can't turn off here }
{P-}
  procedure tarray3_testvarconv2(var st : tarray3_string4);
  begin
    Writeln('st=',st);
    Writeln('Length(st)=',Length(st));
    If Length(st)>4 then
      tarray3_Error('string length too big in calling var arg without openstring');
  end;


{$pop}

{ Case tcase12.pp }
{$push}
{ test for simple comparison }

{$H+}

var
  tcase12_my_str: string;
  tcase12_my_str_wide: widestring;
  tcase12_my_str_ansi: ansistring;
  tcase12_my_str_uni: unicodestring;
  tcase12_i: integer;


{$pop}

{ Case tcase13.pp }
{$push}
{ the last range should be converted to single case and give 'expected' value }

{$H+}
var
  tcase13_my_str: string;
  tcase13_my_str_wide: widestring;
  tcase13_my_str_ansi: ansistring;
  tcase13_my_str_uni: unicodestring;
  tcase13_i: integer;


{$pop}

{ Case tcase14.pp }
{$push}
{ comparison with empty string as bound of 'needed' range }

{$H+}
var
  tcase14_my_str: string;
  tcase14_my_str_wide: widestring;
  tcase14_my_str_ansi: ansistring;
  tcase14_my_str_uni: unicodestring;
  tcase14_i: integer;


{$pop}

{ Case tcase15.pp }
{$push}
{ comparison of one-symbol strings as ranges and single cases }

{$H+}
var
  tcase15_my_str: string;
  tcase15_my_str_wide: widestring;
  tcase15_my_str_ansi: ansistring;
  tcase15_my_str_uni: unicodestring;
  tcase15_i: integer;


{$pop}

{ Case tcase16.pp }
{$push}
{ comparison of one-symbol strings as ranges and single cases }

{$H+}
var
  tcase16_my_str: string;
  tcase16_my_str_wide: widestring;
  tcase16_my_str_ansi: ansistring;
  tcase16_my_str_uni: unicodestring;
  tcase16_i: integer;


{$pop}

{ Case tcase17.pp }
{$push}
{ comparison of empty string }

{$H+}
var
  tcase17_my_str: string;
  tcase17_my_str_wide: widestring;
  tcase17_my_str_ansi: ansistring;
  tcase17_my_str_uni: unicodestring;
  tcase17_i: integer;


{$pop}

{ Case tcase18.pp }
{$push}
{ comparison of empty string }

{$H+}
var
  tcase18_my_str: string;
  tcase18_my_str_wide: widestring;
  tcase18_my_str_ansi: ansistring;
  tcase18_my_str_uni: unicodestring;
  tcase18_i: integer;


{$pop}

{ Case tcase22.pp }
{$push}
{ comparison of one-symbol strings in ranges }

{$H+}
var
  tcase22_my_str: string;
  tcase22_my_str_wide: widestring;
  tcase22_my_str_ansi: ansistring;
  tcase22_my_str_uni: unicodestring;
  tcase22_i: integer;


{$pop}

{ Case tcase24.pp }
{$push}
{ simple test for range }

{$H+}
var
  tcase24_my_str: string;
  tcase24_my_str_wide: widestring;
  tcase24_my_str_ansi: ansistring;
  tcase24_my_str_uni: unicodestring;
  tcase24_i: integer;


{$pop}

{ Case tcase25.pp }
{$push}
{ test for range with one-symbol string as left bound }

{$H+}
var
  tcase25_my_str: string;
  tcase25_my_str_wide: widestring;
  tcase25_my_str_ansi: ansistring;
  tcase25_my_str_uni: unicodestring;
  tcase25_i: integer;


{$pop}

{ Case tcase28.pp }
{$push}
{ test for simple comparison }

{$H-}

var
  tcase28_my_str: string;
  tcase28_my_str_wide: widestring;
  tcase28_my_str_ansi: ansistring;
  tcase28_my_str_uni: unicodestring;
  tcase28_i: integer;


{$pop}

{ Case tcase29.pp }
{$push}
{ the last range should be converted to single case and give 'expected' value }

{$H-}
var
  tcase29_my_str: string;
  tcase29_my_str_wide: widestring;
  tcase29_my_str_ansi: ansistring;
  tcase29_my_str_uni: unicodestring;
  tcase29_i: integer;


{$pop}

{ Case tcase30.pp }
{$push}
{ comparison with empty string as bound of 'needed' range }

{$H-}
var
  tcase30_my_str: string;
  tcase30_my_str_wide: widestring;
  tcase30_my_str_ansi: ansistring;
  tcase30_my_str_uni: unicodestring;
  tcase30_i: integer;


{$pop}

{ Case tcase31.pp }
{$push}
{ comparison of one-symbol strings as ranges and single cases }

{$H-}
var
  tcase31_my_str: string;
  tcase31_my_str_wide: widestring;
  tcase31_my_str_ansi: ansistring;
  tcase31_my_str_uni: unicodestring;
  tcase31_i: integer;


{$pop}

{ Case tcase32.pp }
{$push}
{ comparison of one-symbol strings as ranges and single cases }

{$H-}
var
  tcase32_my_str: string;
  tcase32_my_str_wide: widestring;
  tcase32_my_str_ansi: ansistring;
  tcase32_my_str_uni: unicodestring;
  tcase32_i: integer;


{$pop}

{ Case tcase33.pp }
{$push}
{ comparison of empty string }

{$H-}
var
  tcase33_my_str: string;
  tcase33_my_str_wide: widestring;
  tcase33_my_str_ansi: ansistring;
  tcase33_my_str_uni: unicodestring;
  tcase33_i: integer;


{$pop}

{ Case tcase34.pp }
{$push}
{ comparison of empty string }

{$H-}
var
  tcase34_my_str: string;
  tcase34_my_str_wide: widestring;
  tcase34_my_str_ansi: ansistring;
  tcase34_my_str_uni: unicodestring;
  tcase34_i: integer;


{$pop}

{ Case tcase38.pp }
{$push}
{ comparison of one-symbol strings in ranges }

{$H-}
var
  tcase38_my_str: string;
  tcase38_my_str_wide: widestring;
  tcase38_my_str_ansi: ansistring;
  tcase38_my_str_uni: unicodestring;
  tcase38_i: integer;


{$pop}

{ Case tcase40.pp }
{$push}
{ simple test for range }

{$H-}
var
  tcase40_my_str: string;
  tcase40_my_str_wide: widestring;
  tcase40_my_str_ansi: ansistring;
  tcase40_my_str_uni: unicodestring;
  tcase40_i: integer;


{$pop}

{ Case tcase41.pp }
{$push}
{ test for range with one-symbol string as left bound }

{$H-}
var
  tcase41_my_str: string;
  tcase41_my_str_wide: widestring;
  tcase41_my_str_ansi: ansistring;
  tcase41_my_str_uni: unicodestring;
  tcase41_i: integer;


{$pop}

{ Case tcase44.pp }
{$push}
{ test for range with one-symbol string as left bound }
{ sequence of cases in cases                          }

{$H-}
var
  tcase44_my_str: string;
  tcase44_my_str_wide: widestring;
  tcase44_my_str_ansi: ansistring;
  tcase44_my_str_uni: unicodestring;
  tcase44_i: integer;


{$pop}

{ Case tcase5.pp }
{$push}
{ comparison of one-symbol strings in ranges }

{$H+}
var
  tcase5_my_str: string;
  tcase5_i: integer;


{$pop}

{ Case tcase7.pp }
{$push}
{ simple test for range }

{$H+}
var
  tcase7_my_str: string;
  tcase7_i: integer;


{$pop}

{ Case tcase8.pp }
{$push}
{ test for range with one-symbol string as left bound }

{$H+}
var
  tcase8_my_str: string;
  tcase8_i: integer;


{$pop}

{ Case tcmp0.pp }
{$push}


var tcmp0_str1 : pchar = 'test';
    tcmp0_str2 : pchar = 'test';
    tcmp0_str3 : pchar = 'testa';
    tcmp0_str4 : pchar = 'asdf';
    tcmp0_res : longint;

{$pop}

{ Case tcpstr11.pp }
{$push}

type
  tcpstr11_cp866 = type AnsiString(866);
var
  tcpstr11_A: tcpstr11_cp866;
  tcpstr11_c: array[0..5] of ansichar = 'привет';

{$pop}

{ Case tcpstr2.pp }
{$push}
procedure tcpstr2_p(const S : RawByteString); overload;
  begin
  end;

procedure tcpstr2_p(const S : UTF8String); overload;
  begin
  end;
var
  tcpstr2_s1 : RawByteString;

{$pop}

{ Case tcpstr2a.pp }
{$push}
procedure tcpstr2a_p(const S : RawByteString); overload;
  begin
    writeln(s,'AnsiString prefers RawByteString');
  end;

procedure tcpstr2a_p(const S : UTF8String); overload;
  begin
    writeln(s,'AnsiString prefers UTF8String');
    { This is not expected, so generate error }
    writeln('Unexpected, changed behavior!');
    halt(1);
  end;
var
  tcpstr2a_s1 : Ansistring;

{$pop}

{ Case tcpstr5.pp }
{$push}
procedure tcpstr5_pw(const S : RawByteString); overload;
  begin
    WriteLn('fail');
  end;

procedure tcpstr5_pw(const S : WideString); overload;
  begin
    WriteLn('ok');
  end;

procedure tcpstr5_pu(const S : RawByteString); overload;
  begin
    WriteLn('fail');
  end;

procedure tcpstr5_pu(const S : UnicodeString); overload;
  begin
    WriteLn('ok');
  end;

var
  tcpstr5_u : UnicodeString;
  tcpstr5_w : WideString;

{$pop}

{ Case tenum6.pp }
{$push}
var
  tenum6_b : boolean;
  tenum6_b8 : ByteBool;
  tenum6_b16 : WordBool;
  tenum6_b32 : LongBool;
  tenum6_b64 : QWordBool;
  tenum6_s : string;


{$pop}

{ Case tint641.pp }
{$push}

{$R-}
{$Q-}

const
   tint641_q2 : qword = 1234;
   tint641_i2 : int64 = -1234;

var
   tint641_q : qword;
   tint641_i : int64;
   tint641_l1,tint641_l2 : longint;
   tint641_s : string;

procedure tint641_p1(tint641_q : qword;tint641_i : int64);

  begin
  end;

function tint641_f1 : qword;

  begin
   tint641_f1:=1;
  end;

function tint641_f2 : int64;

  begin
   tint641_f2:=-1;
  end;

var
   tint641_q1,tint641_q3,tint641_q4 : qword;


{$pop}

{ Case tismngd2.pp }
{$push}


var
  tismngd2_l: LongInt;
  tismngd2_o: TObject;
  tismngd2__as: AnsiString;

{$pop}

{ Case tover1.pp }
{$push}


const
  tover1_RESULT_PCHAR = 'pchar parameter call';
  tover1_RESULT_ANSI  = 'ansistring parameter call';
  tover1_RESULT_SHORT = 'shortstring parameter call';
  tover1_RESULT_WIDE  = 'widestring parameter call';

{ This tests method overloads, to verify
  if they conform to correct type conversion
}
function tover1_test_string(tover1_s: shortstring): shortstring;
Begin
  tover1_test_string := tover1_RESULT_SHORT;
end;

{$ifndef ver1_0}
function tover1_test_string(tover1_s: widestring): shortstring;
Begin
  tover1_test_string := tover1_RESULT_WIDE;
end;
{$endif}


function tover1_test_string(tover1_s: ansistring): shortstring;
Begin
  tover1_test_string := tover1_RESULT_ANSI;
end;

function tover1_test_string(p:pchar): shortstring;
begin
  tover1_test_string := tover1_RESULT_PCHAR;
end;

procedure tover1_fail;
 begin
   writeln('Failure!');
   Halt(1);
 end;

var
  tover1_short_string : shortstring;
  tover1_ansi_string : ansistring;
{$ifndef ver1_0}
  tover1_wide_string : widestring;
{$endif}
  tover1_p_string : pchar;
  tover1_s: shortstring;

{$pop}

{ Case tparray24.pp }
{$push}
type
  tparray24_tstr = string[2];
  tparray24_tarr = bitpacked array[0..20] of tparray24_tstr;

procedure tparray24_p(var tparray24_a: tparray24_tstr);
begin
  tparray24_a := 'ab';
end;

var
  tparray24_a: tparray24_tarr;

{$pop}

{ Case tparray25.pp }
{$push}
type
  tparray25_tstr = string[2];
  tparray25_pstr = ^tparray25_tstr;
  tparray25_tarr = bitpacked array[0..20] of tparray25_tstr;

procedure tparray25_p(tparray25_a: tparray25_pstr);
begin
  tparray25_a^ := 'ab';
end;

var
  tparray25_a: tparray25_tarr;

{$pop}

{ Case trstr1.pp }
{$push}
var
  trstr1_s: ansistring;
  trstr1_i,trstr1_j: integer;
  trstr1_c1,trstr1_c2: char;

{$pop}

{ Case trstr2.pp }
{$push}
var
  trstr2_s: ansistring;
  trstr2_i,trstr2_j: integer;

{$pop}

{ Case trstr6.pp }
{$push}
{ from GPC test suite }


type trstr6_ii = integer;
     trstr6_tip = ^trstr6_ii;
var trstr6_ipv1, trstr6_ipv2, trstr6_ipv3 : trstr6_tip;
    trstr6_s : string[20];

function trstr6_ip1: trstr6_tip;
  var tmp : trstr6_tip;
begin
  trstr6_s := 'dead beef';
  tmp := trstr6_ipv2;
  trstr6_ipv2 := trstr6_ipv3;
  trstr6_ipv3 := tmp;
  trstr6_ip1 := trstr6_ipv1;
end;

{$pop}

{ Case tstring1.pp }
{$push}


function tstring1_TestOK:boolean;
Const
  TestStr: string[22]='HELLO, THIS IS A TEST ';
var
  I : INTEGER;
  U : STRING[1];
  Q : STRING[100];
  S : STRING[55];
  T : STRING[60];
  V : STRING;
begin
  tstring1_TestOk:=false;
  T:='THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG 1234567890';
  Insert (T, T, 1);
{Writeln(T);}
  Delete (T, 55, 54);
  S:=Copy (T, -5, 2);     {'TH'}
  U:=Copy (T, 7, 4);      {'I'}
  S:=S + U;               {'THI'}
  Q:=Copy (T, 32, 70);    {'THE LAZY DOG 1234567890'}
  Delete (Q, 2, 1);         {'TE LAZY DOG 1234567890'}
  Delete (Q, 100, 2);       {'TE LAZY DOG 1234567890'}
  Delete (Q, 3, -4);        {'TE LAZY DOG 1234567890'}
  Delete (Q, 3, 10);        {'TE1234567890'}
{  writeln('TE1234567890 - ',Q);}
  I:=Pos ('S', T);        {25}
  Insert(Copy(T,I,200),Q,3);{'TES OVER THE LAZY DOG 12345678901234567890'}
  Delete (Q, 4, 6);         {'TESTHE LAZY DOG 12345678901234567890}
  S:=S + T [25];          {'THIS'}
  S:=S + Copy (S, 3, -5) + Copy (S, 3, 2);  {'THISIS'}
  V:=T;                   {'THE QUICK BROWN FOX JUMPS OVER THE LAZY ..'}
  Delete (V, 1, 36);      {'AZY DOG 1234567890'}
  if (Copy (V, -7, -1)='') and (Pos ('DOG', V)=5) then {TRUE}
   Insert (V, S, 200);    {'THISISAZY DOG 1234567890'}
  U:=Copy (T, 44, 40);    {' '}
  Insert (U, S, 5);         {'THIS ISAZY DOG 1234567890'}
  I:=Pos ('ZY', S);       {9}
  Delete (S, I, -5);        {'THIS ISAZY DOG 1234567890'}
  Insert (Copy(S,5,1),S,8); {'THIS IS AZY DOG 1234567890'}
  Delete (S, 10, 16);       {'THIS IS A0'}
  if S [Length (S)]='0' then {TRUE}
   S:=S + Q;            {'THIS IS A0TESTHE LAZY DOG 123456789012345...'}
  V:=Copy (S, Length (S) - 19, 10); {'1234567890'}
  if V=Copy (S, Length (S) - 9, 10) then {TRUE}
   Delete (S, 15, 3 * Length (V)+2); {'THIS IS A0TEST'}
  Insert ('', S, 0);        {'THIS IS A0TEST'}
  Insert(Copy(S,5,1),S,11); {'THIS IS A0 TEST'}
  Insert ('HELLO', S, -4);  {'HELLOTHIS IS A0 TEST'}
  Insert (',', S, 6);       {'HELLO,THIS IS A0 TEST'}
  Delete (S, Pos ('TEST', S) - 2, 1); {'HELLO,THIS IS A TEST'}
  Delete (Q, 1, 32767);     {''}
  Q:=Q + ' ';             {' '}
  Insert (Q, S, 7);         {'HELLO, THIS IS A TEST'}
  Insert (Q, S, 255);       {'HELLO, THIS IS A TEST '}
  if (S=TestStr) and (Q=' ') and (V='1234567890') and
     (T='THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG 1234567890') then
   tstring1_TestOK:=true;
end;



{$pop}

{ Case tunistrcopy.pp }
{$push}
var
  tunistrcopy_a, tunistrcopy_b : UnicodeString;

{$pop}

{ Case tw29833.pp }
{$push}
var
  tw29833_aURI,tw29833_Server:rawbytestring;


{$pop}

{ Case twrstr2.pp }
{$push}
{ from GPC test suite }



Var
  twrstr2_Foo: String [3];


{$pop}

begin

{ Case taddstr1.pp }
{$push}

begin
  taddstr1_s1:='asdf';
  if taddstr1_s1+''<>taddstr1_s1 then
    halt(1);
  taddstr1_s1:='asdf';
  if ''+taddstr1_s1<>taddstr1_s1 then
    halt(1);

  if ''+taddstr1_s2+''+taddstr1_s1+''<>taddstr1_s2+taddstr1_s1 then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tarray3.pp }
{$push}
{$j+}
{$P+}
begin
  { compare array of char to constant strings }
  Writeln('Testing if "',tarray3_car4_1,'" is equal to "',tarray3_cst4_1,'"');
  if tarray3_car4_1<>tarray3_cst4_1 then
    tarray3_error('Comparison of array of char and string don''t work');
  Writeln('Testing if "',tarray3_car4_1,'" is equal to "ABCD"');
  if tarray3_car4_1<>'ABCD' then
    tarray3_error('Comparison of array of char and constat string don''t work');
  Writeln('Testing if "',tarray3_cst4_1,'" is equal to "ABCD"');
  if 'ABCD'<>tarray3_cst4_1 then
    tarray3_error('Comparison of string and constant string don''t work');
  tarray3_car4_1:='AB'#0'D';
  if tarray3_car4_1='AB' then
    Writeln('Anything beyond a #0 is ignored')
  else if tarray3_car4_1='AB'#0'D' then
    Writeln('Chars after #0 are not ignored')
  else
    tarray3_Error('problems if #0 in array of char');
{$ifdef FPC this is not allowed in BP !}
  tarray3_car4_1:=tarray3_cst4_1;
{ if it is allowed then it must also work correctly !! }
  Writeln('Testing if "',tarray3_car4_1,'" is equal to "',tarray3_cst4_1,'"');
  if tarray3_car4_1<>tarray3_cst4_1 then
    tarray3_error('Comparison of array of char and string don''t work');
{$ifdef test_known_problems}
  if tarray3_string4(tarray3_car6_2)<>'efgh' then
    tarray3_error('typcasting to shorter strings leads to problems');
{$endif}
  tarray3_ar4_2:='Test';
  tarray3_ar4_1:=tarray3_cst6_2;
  if tarray3_ar4_2<>'Test' then
    tarray3_error('overwriting beyond char array size');
  tarray3_ar6_1:='Test'#0'T';
  tarray3_st6_1:=tarray3_ar6_1;
  if (tarray3_st6_1<>tarray3_ar6_1) or (tarray3_st6_1='Test') then
    tarray3_error('problems with #0');
  tarray3_ar6_1:='AB';
  if tarray3_ar6_1='AB'#0't'#0'T' then
    tarray3_Error('assigning strings to array of char does not zero end of array if string is shorter');
  if tarray3_ar6_1='AB'#0#0#0#0 then
    writeln('assigning shorter strings to array of char does zero rest of array')
  else
    tarray3_error('assigning "AB" to ar6_1 gives '+tarray3_ar6_1);
{$endif}
  tarray3_cst8_1:=tarray3_car4_1;
{ if it is allowed then it must also work correctly !! }
  Writeln('Testing if "',tarray3_car4_1,'" is equal to "',tarray3_cst8_1,'"');
  if tarray3_car4_1<>tarray3_cst8_1 then
    tarray3_error('Comparison of array of char and string don''t work');
  tarray3_st4_2:='Test';
  tarray3_st4_1:=tarray3_car6_1;
  if (tarray3_st4_2<>'Test') or (tarray3_st4_1<>'EFGH') then
    tarray3_error('problems when copying long char array to shorter string');
  tarray3_testvalueconv('AB');
  tarray3_testvalueconv('ABCDEFG');
  tarray3_testvalueconv(tarray3_car4_1);
  tarray3_testvalueconv(tarray3_car6_1);
  getmem(tarray3_pc,256);
  tarray3_pc:='Long Test';
{$ifdef FPC this is not allowed in BP !}
  tarray3_testvalueconv(tarray3_pc);
{$endif def FPC this is not allowed in BP !}
  tarray3_testconstconv('AB');
{$ifdef test_known_problems}
  tarray3_testconstconv('ABCDEFG');
{$endif}
  tarray3_testconstconv(tarray3_st4_1);
{$ifdef test_known_problems}
  tarray3_testconstconv(tarray3_cst6_2);
{$endif}
{$ifdef FPC this is not allowed in BP !}
{$ifdef test_known_problems}
  tarray3_testconstconv(tarray3_pc);
{$endif}
{$endif def FPC this is not allowed in BP !}
  tarray3_testvarconv(tarray3_st4_2);
  tarray3_testvarconv(tarray3_cst4_1);
{$ifdef FPC this is not allowed in BP !}
{$ifdef test_known_problems}
  tarray3_testvarconv(tarray3_st6_1);
  tarray3_testvarconv(tarray3_cst8_1);
{$endif}
{$endif def FPC this is not allowed in BP !}
  { testvarconv(pc); this one fails at compilation }
  tarray3_testvarconv2(tarray3_st4_2);
  tarray3_testvarconv2(tarray3_cst4_1);
{$ifdef FPC this is not allowed in BP !}
{$ifdef test_known_problems}
  tarray3_testvarconv2(tarray3_st6_1);
  tarray3_testvarconv2(tarray3_cst8_1);
{$endif}
{$endif def FPC this is not allowed in BP !}
  if tarray3_has_errors then
    begin
      Writeln('There are still problems with arrays of char');
      Halt(1);
    end;
end;
{$pop}

{ Case tcase12.pp }
{$push}
{$H+}
begin
  tcase12_my_str := 'ababaca';
  tcase12_my_str_wide := 'ababaca';
  tcase12_my_str_ansi := 'ababaca';
  tcase12_my_str_uni := 'ababaca';
  tcase12_i := -1;

  case tcase12_my_str of
    'abba': tcase12_i := 1;
    'ababac': tcase12_i := 2;
    'ababacaa': tcase12_i := 3;
    'ababaca ': tcase12_i := 4;
    ' ababaca': tcase12_i := 5;
    ' ababac': tcase12_i := 6;
    'ababaca': tcase12_i := 7;
    else tcase12_i := 0;
  end;

  writeln(tcase12_i);
  if (tcase12_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase12_my_str_wide of
    'abba': tcase12_i := 1;
    'ababac': tcase12_i := 2;
    'ababacaa': tcase12_i := 3;
    'ababaca ': tcase12_i := 4;
    ' ababaca': tcase12_i := 5;
    ' ababac': tcase12_i := 6;
    'ababaca': tcase12_i := 7;
    else tcase12_i := 0;
  end;

  writeln(tcase12_i);
  if (tcase12_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase12_my_str_ansi of
    'abba': tcase12_i := 1;
    'ababac': tcase12_i := 2;
    'ababacaa': tcase12_i := 3;
    'ababaca ': tcase12_i := 4;
    ' ababaca': tcase12_i := 5;
    ' ababac': tcase12_i := 6;
    'ababaca': tcase12_i := 7;
    else tcase12_i := 0;
  end;

  writeln(tcase12_i);
  if (tcase12_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase12_my_str_uni of
    'abba': tcase12_i := 1;
    'ababac': tcase12_i := 2;
    'ababacaa': tcase12_i := 3;
    'ababaca ': tcase12_i := 4;
    ' ababaca': tcase12_i := 5;
    ' ababac': tcase12_i := 6;
    'ababaca': tcase12_i := 7;
    else tcase12_i := 0;
  end;

  writeln(tcase12_i);
  if (tcase12_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase13.pp }
{$push}
{$H+}
begin
  tcase13_my_str := 'cab';
  tcase13_my_str_wide := 'cab';
  tcase13_my_str_ansi := 'cab';
  tcase13_my_str_uni := 'cab';
  tcase13_i := -1;

  case tcase13_my_str of
    'a'..'b': tcase13_i := 1;
    'c'..'caa': tcase13_i := 2;
    'cab'..'cab': tcase13_i := 3;
    else tcase13_i := 0;
  end;

  if (tcase13_i <> 3) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase13_my_str_wide of
    'a'..'b': tcase13_i := 1;
    'c'..'caa': tcase13_i := 2;
    'cab'..'cab': tcase13_i := 3;
    else tcase13_i := 0;
  end;

  if (tcase13_i <> 3) then begin
    writeln('Error_wide ', tcase13_i);
    Halt(1);
  end;


  case tcase13_my_str_ansi of
    'a'..'b': tcase13_i := 1;
    'c'..'caa': tcase13_i := 2;
    'cab'..'cab': tcase13_i := 3;
    else tcase13_i := 0;
  end;

  if (tcase13_i <> 3) then begin
    writeln('Error_ansi');
    Halt(1);
  end;


  case tcase13_my_str_uni of
    'aa': tcase13_i := 1;
    'ca'..'caa': tcase13_i := 2;
    'cab': tcase13_i := 3;
    else tcase13_i := 0;
  end;

  if (tcase13_i <> 3) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase14.pp }
{$push}
{$H+}
begin
  tcase14_my_str := 'ababaca';
  tcase14_my_str_wide := 'ababaca';
  tcase14_my_str_ansi := 'ababaca';
  tcase14_my_str_uni := 'ababaca';
  tcase14_i := -1;

  case tcase14_my_str of
    ''..'ababaca': tcase14_i := 1;
    else tcase14_i := 0;
  end;

  if (tcase14_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase14_my_str_wide of
    ''..'ababaca': tcase14_i := 1;
    else tcase14_i := 0;
  end;

  if (tcase14_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase14_my_str_ansi of
    ''..'ababaca': tcase14_i := 1;
    else tcase14_i := 0;
  end;

  if (tcase14_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase14_my_str_uni of
    ''..'ababaca': tcase14_i := 1;
    else tcase14_i := 0;
  end;

  if (tcase14_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase15.pp }
{$push}
{$H+}
begin
  tcase15_my_str := 'c';
  tcase15_my_str_wide := 'c';
  tcase15_my_str_ansi := 'c';
  tcase15_my_str_uni := 'c';
  tcase15_i := -1;

  case tcase15_my_str of
    'a'..'b': tcase15_i := 1;
    'c': tcase15_i := 2;
    'd'..'eee': tcase15_i := 3;
    else tcase15_i := 0;
  end;

  if (tcase15_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase15_my_str_wide of
    'a'..'b': tcase15_i := 1;
    'c': tcase15_i := 2;
    'd'..'eee': tcase15_i := 3;
    else tcase15_i := 0;
  end;

  if (tcase15_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase15_my_str_ansi of
    'a'..'b': tcase15_i := 1;
    'c': tcase15_i := 2;
    'd'..'eee': tcase15_i := 3;
    else tcase15_i := 0;
  end;

  if (tcase15_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase15_my_str_uni of
    'a'..'b': tcase15_i := 1;
    'c': tcase15_i := 2;
    'd'..'eee': tcase15_i := 3;
    else tcase15_i := 0;
  end;

  if (tcase15_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase16.pp }
{$push}
{$H+}
begin
  tcase16_my_str := 'b';
  tcase16_my_str_wide := 'b';
  tcase16_my_str_ansi := 'b';
  tcase16_my_str_uni := 'b';
  tcase16_i := -1;

  case tcase16_my_str of
    'a'..'b': tcase16_i := 1;
    'c': tcase16_i := 2;
    'd'..'eee': tcase16_i := 3;
    else tcase16_i := 0;
  end;

  if (tcase16_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase16_my_str_wide of
    'a'..'b': tcase16_i := 1;
    'c': tcase16_i := 2;
    'd'..'eee': tcase16_i := 3;
    else tcase16_i := 0;
  end;

  if (tcase16_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase16_my_str_ansi of
    'a'..'b': tcase16_i := 1;
    'c': tcase16_i := 2;
    'd'..'eee': tcase16_i := 3;
    else tcase16_i := 0;
  end;

  if (tcase16_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase16_my_str_uni of
    'a'..'b': tcase16_i := 1;
    'c': tcase16_i := 2;
    'd'..'eee': tcase16_i := 3;
    else tcase16_i := 0;
  end;

  if (tcase16_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase17.pp }
{$push}
{$H+}
begin
  tcase17_my_str := '';
  tcase17_my_str_wide := '';
  tcase17_my_str_ansi := '';
  tcase17_my_str_uni := '';
  tcase17_i := -1;

  case tcase17_my_str of
    'a'..'b': tcase17_i := 1;
    'c': tcase17_i := 2;
    'd'..'eee': tcase17_i := 3;
    ''..'': tcase17_i := 4;
    else tcase17_i := 0;
  end;

  if (tcase17_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase17_my_str_wide of
    'a'..'b': tcase17_i := 1;
    'c': tcase17_i := 2;
    'd'..'eee': tcase17_i := 3;
    ''..'': tcase17_i := 4;
    else tcase17_i := 0;
  end;

  if (tcase17_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase17_my_str_ansi of
    'a'..'b': tcase17_i := 1;
    'c': tcase17_i := 2;
    'd'..'eee': tcase17_i := 3;
    ''..'': tcase17_i := 4;
    else tcase17_i := 0;
  end;

  if (tcase17_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase17_my_str_uni of
    'a'..'b': tcase17_i := 1;
    'c': tcase17_i := 2;
    'd'..'eee': tcase17_i := 3;
    ''..'': tcase17_i := 4;
    else tcase17_i := 0;
  end;

  if (tcase17_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase18.pp }
{$push}
{$H+}
begin
  tcase18_my_str := '';
  tcase18_my_str_wide := '';
  tcase18_my_str_ansi := '';
  tcase18_my_str_uni := '';
  tcase18_i := -1;

  case tcase18_my_str of
    'b'..'b': tcase18_i := 1;
    'c': tcase18_i := 2;
    'd'..'eee': tcase18_i := 3;
    ''..'a': tcase18_i := 4;
    else tcase18_i := 0;
  end;

  if (tcase18_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;

  case tcase18_my_str_wide of
    'b'..'b': tcase18_i := 1;
    'c': tcase18_i := 2;
    'd'..'eee': tcase18_i := 3;
    ''..'a': tcase18_i := 4;
    else tcase18_i := 0;
  end;

  if (tcase18_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;

  case tcase18_my_str_ansi of
    'b'..'b': tcase18_i := 1;
    'c': tcase18_i := 2;
    'd'..'eee': tcase18_i := 3;
    ''..'a': tcase18_i := 4;
    else tcase18_i := 0;
  end;

  if (tcase18_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;

  case tcase18_my_str_uni of
    'b'..'b': tcase18_i := 1;
    'c': tcase18_i := 2;
    'd'..'eee': tcase18_i := 3;
    ''..'a': tcase18_i := 4;
    else tcase18_i := 0;
  end;

  if (tcase18_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase22.pp }
{$push}
{$H+}
begin
  tcase22_my_str := 'c';
  tcase22_my_str_wide := 'c';
  tcase22_my_str_ansi := 'c';
  tcase22_my_str_uni := 'c';
  tcase22_i := -1;

  case tcase22_my_str of
    'a'..'b': tcase22_i := 1;
    'c'..'d': tcase22_i := 2;
    else tcase22_i := 0;
  end;

  if (tcase22_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase22_my_str_wide of
    'a'..'b': tcase22_i := 1;
    'c'..'d': tcase22_i := 2;
    else tcase22_i := 0;
  end;

  if (tcase22_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase22_my_str_ansi of
    'a'..'b': tcase22_i := 1;
    'c'..'d': tcase22_i := 2;
    else tcase22_i := 0;
  end;

  if (tcase22_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase22_my_str_uni of
    'a'..'b': tcase22_i := 1;
    'c'..'d': tcase22_i := 2;
    else tcase22_i := 0;
  end;

  if (tcase22_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase24.pp }
{$push}
{$H+}
begin
  tcase24_my_str := 'cab';
  tcase24_my_str_wide := 'cab';
  tcase24_my_str_ansi := 'cab';
  tcase24_my_str_uni := 'cab';
  tcase24_i := -1;

  case tcase24_my_str of
    'aba'..'daa': tcase24_i := 1;
    else tcase24_i := 0;
  end;

  if (tcase24_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase24_my_str_wide of
    'aba'..'daa': tcase24_i := 1;
    else tcase24_i := 0;
  end;

  if (tcase24_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase24_my_str_ansi of
    'aba'..'daa': tcase24_i := 1;
    else tcase24_i := 0;
  end;

  if (tcase24_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase24_my_str_uni of
    'aba'..'daa': tcase24_i := 1;
    else tcase24_i := 0;
  end;

  if (tcase24_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase25.pp }
{$push}
{$H+}
begin
  tcase25_my_str := 'cab';
  tcase25_my_str_wide := 'cab';
  tcase25_my_str_ansi := 'cab';
  tcase25_my_str_uni := 'cab';
  tcase25_i := -1;

  case tcase25_my_str of
    'a'..'daa': tcase25_i := 1;
    else tcase25_i := 0;
  end;

  if (tcase25_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase25_my_str_wide of
    'a'..'daa': tcase25_i := 1;
    else tcase25_i := 0;
  end;

  if (tcase25_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase25_my_str_ansi of
    'a'..'daa': tcase25_i := 1;
    else tcase25_i := 0;
  end;

  if (tcase25_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase25_my_str_uni of
    'a'..'daa': tcase25_i := 1;
    else tcase25_i := 0;
  end;

  if (tcase25_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase28.pp }
{$push}
{$H-}
begin
  tcase28_my_str := 'ababaca';
  tcase28_my_str_wide := 'ababaca';
  tcase28_my_str_ansi := 'ababaca';
  tcase28_my_str_uni := 'ababaca';
  tcase28_i := -1;

  case tcase28_my_str of
    'abba': tcase28_i := 1;
    'ababac': tcase28_i := 2;
    'ababacaa': tcase28_i := 3;
    'ababaca ': tcase28_i := 4;
    ' ababaca': tcase28_i := 5;
    ' ababac': tcase28_i := 6;
    'ababaca': tcase28_i := 7;
    else tcase28_i := 0;
  end;

  writeln(tcase28_i);
  if (tcase28_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase28_my_str_wide of
    'abba': tcase28_i := 1;
    'ababac': tcase28_i := 2;
    'ababacaa': tcase28_i := 3;
    'ababaca ': tcase28_i := 4;
    ' ababaca': tcase28_i := 5;
    ' ababac': tcase28_i := 6;
    'ababaca': tcase28_i := 7;
    else tcase28_i := 0;
  end;

  writeln(tcase28_i);
  if (tcase28_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase28_my_str_ansi of
    'abba': tcase28_i := 1;
    'ababac': tcase28_i := 2;
    'ababacaa': tcase28_i := 3;
    'ababaca ': tcase28_i := 4;
    ' ababaca': tcase28_i := 5;
    ' ababac': tcase28_i := 6;
    'ababaca': tcase28_i := 7;
    else tcase28_i := 0;
  end;

  writeln(tcase28_i);
  if (tcase28_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase28_my_str_uni of
    'abba': tcase28_i := 1;
    'ababac': tcase28_i := 2;
    'ababacaa': tcase28_i := 3;
    'ababaca ': tcase28_i := 4;
    ' ababaca': tcase28_i := 5;
    ' ababac': tcase28_i := 6;
    'ababaca': tcase28_i := 7;
    else tcase28_i := 0;
  end;

  writeln(tcase28_i);
  if (tcase28_i <> 7) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase29.pp }
{$push}
{$H-}
begin
  tcase29_my_str := 'cab';
  tcase29_my_str_wide := 'cab';
  tcase29_my_str_ansi := 'cab';
  tcase29_my_str_uni := 'cab';
  tcase29_i := -1;

  case tcase29_my_str of
    'a'..'b': tcase29_i := 1;
    'c'..'caa': tcase29_i := 2;
    'cab'..'cab': tcase29_i := 3;
    else tcase29_i := 0;
  end;

  if (tcase29_i <> 3) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase29_my_str_wide of
    'a'..'b': tcase29_i := 1;
    'c'..'caa': tcase29_i := 2;
    'cab'..'cab': tcase29_i := 3;
    else tcase29_i := 0;
  end;

  if (tcase29_i <> 3) then begin
    writeln('Error_wide ', tcase29_i);
    Halt(1);
  end;


  case tcase29_my_str_ansi of
    'a'..'b': tcase29_i := 1;
    'c'..'caa': tcase29_i := 2;
    'cab'..'cab': tcase29_i := 3;
    else tcase29_i := 0;
  end;

  if (tcase29_i <> 3) then begin
    writeln('Error_ansi');
    Halt(1);
  end;


  case tcase29_my_str_uni of
    'aa': tcase29_i := 1;
    'ca'..'caa': tcase29_i := 2;
    'cab': tcase29_i := 3;
    else tcase29_i := 0;
  end;

  if (tcase29_i <> 3) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase30.pp }
{$push}
{$H-}
begin
  tcase30_my_str := 'ababaca';
  tcase30_my_str_wide := 'ababaca';
  tcase30_my_str_ansi := 'ababaca';
  tcase30_my_str_uni := 'ababaca';
  tcase30_i := -1;

  case tcase30_my_str of
    ''..'ababaca': tcase30_i := 1;
    else tcase30_i := 0;
  end;

  if (tcase30_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase30_my_str_wide of
    ''..'ababaca': tcase30_i := 1;
    else tcase30_i := 0;
  end;

  if (tcase30_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase30_my_str_ansi of
    ''..'ababaca': tcase30_i := 1;
    else tcase30_i := 0;
  end;

  if (tcase30_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase30_my_str_uni of
    ''..'ababaca': tcase30_i := 1;
    else tcase30_i := 0;
  end;

  if (tcase30_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase31.pp }
{$push}
{$H-}
begin
  tcase31_my_str := 'c';
  tcase31_my_str_wide := 'c';
  tcase31_my_str_ansi := 'c';
  tcase31_my_str_uni := 'c';
  tcase31_i := -1;

  case tcase31_my_str of
    'a'..'b': tcase31_i := 1;
    'c': tcase31_i := 2;
    'd'..'eee': tcase31_i := 3;
    else tcase31_i := 0;
  end;

  if (tcase31_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase31_my_str_wide of
    'a'..'b': tcase31_i := 1;
    'c': tcase31_i := 2;
    'd'..'eee': tcase31_i := 3;
    else tcase31_i := 0;
  end;

  if (tcase31_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase31_my_str_ansi of
    'a'..'b': tcase31_i := 1;
    'c': tcase31_i := 2;
    'd'..'eee': tcase31_i := 3;
    else tcase31_i := 0;
  end;

  if (tcase31_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase31_my_str_uni of
    'a'..'b': tcase31_i := 1;
    'c': tcase31_i := 2;
    'd'..'eee': tcase31_i := 3;
    else tcase31_i := 0;
  end;

  if (tcase31_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase32.pp }
{$push}
{$H-}
begin
  tcase32_my_str := 'b';
  tcase32_my_str_wide := 'b';
  tcase32_my_str_ansi := 'b';
  tcase32_my_str_uni := 'b';
  tcase32_i := -1;

  case tcase32_my_str of
    'a'..'b': tcase32_i := 1;
    'c': tcase32_i := 2;
    'd'..'eee': tcase32_i := 3;
    else tcase32_i := 0;
  end;

  if (tcase32_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase32_my_str_wide of
    'a'..'b': tcase32_i := 1;
    'c': tcase32_i := 2;
    'd'..'eee': tcase32_i := 3;
    else tcase32_i := 0;
  end;

  if (tcase32_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase32_my_str_ansi of
    'a'..'b': tcase32_i := 1;
    'c': tcase32_i := 2;
    'd'..'eee': tcase32_i := 3;
    else tcase32_i := 0;
  end;

  if (tcase32_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase32_my_str_uni of
    'a'..'b': tcase32_i := 1;
    'c': tcase32_i := 2;
    'd'..'eee': tcase32_i := 3;
    else tcase32_i := 0;
  end;

  if (tcase32_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase33.pp }
{$push}
{$H-}
begin
  tcase33_my_str := '';
  tcase33_my_str_wide := '';
  tcase33_my_str_ansi := '';
  tcase33_my_str_uni := '';
  tcase33_i := -1;

  case tcase33_my_str of
    'a'..'b': tcase33_i := 1;
    'c': tcase33_i := 2;
    'd'..'eee': tcase33_i := 3;
    ''..'': tcase33_i := 4;
    else tcase33_i := 0;
  end;

  if (tcase33_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase33_my_str_wide of
    'a'..'b': tcase33_i := 1;
    'c': tcase33_i := 2;
    'd'..'eee': tcase33_i := 3;
    ''..'': tcase33_i := 4;
    else tcase33_i := 0;
  end;

  if (tcase33_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase33_my_str_ansi of
    'a'..'b': tcase33_i := 1;
    'c': tcase33_i := 2;
    'd'..'eee': tcase33_i := 3;
    ''..'': tcase33_i := 4;
    else tcase33_i := 0;
  end;

  if (tcase33_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase33_my_str_uni of
    'a'..'b': tcase33_i := 1;
    'c': tcase33_i := 2;
    'd'..'eee': tcase33_i := 3;
    ''..'': tcase33_i := 4;
    else tcase33_i := 0;
  end;

  if (tcase33_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase34.pp }
{$push}
{$H-}
begin
  tcase34_my_str := '';
  tcase34_my_str_wide := '';
  tcase34_my_str_ansi := '';
  tcase34_my_str_uni := '';
  tcase34_i := -1;

  case tcase34_my_str of
    'b'..'b': tcase34_i := 1;
    'c': tcase34_i := 2;
    'd'..'eee': tcase34_i := 3;
    ''..'a': tcase34_i := 4;
    else tcase34_i := 0;
  end;

  if (tcase34_i <> 4) then begin
    writeln('Error1');
    Halt(1);
  end;

  case tcase34_my_str_wide of
    'b'..'b': tcase34_i := 1;
    'c': tcase34_i := 2;
    'd'..'eee': tcase34_i := 3;
    ''..'a': tcase34_i := 4;
    else tcase34_i := 0;
  end;

  if (tcase34_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;

  case tcase34_my_str_ansi of
    'b'..'b': tcase34_i := 1;
    'c': tcase34_i := 2;
    'd'..'eee': tcase34_i := 3;
    ''..'a': tcase34_i := 4;
    else tcase34_i := 0;
  end;

  if (tcase34_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;

  case tcase34_my_str_uni of
    'b'..'b': tcase34_i := 1;
    'c': tcase34_i := 2;
    'd'..'eee': tcase34_i := 3;
    ''..'a': tcase34_i := 4;
    else tcase34_i := 0;
  end;

  if (tcase34_i <> 4) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase38.pp }
{$push}
{$H-}
begin
  tcase38_my_str := 'c';
  tcase38_my_str_wide := 'c';
  tcase38_my_str_ansi := 'c';
  tcase38_my_str_uni := 'c';
  tcase38_i := -1;

  case tcase38_my_str of
    'a'..'b': tcase38_i := 1;
    'c'..'d': tcase38_i := 2;
    else tcase38_i := 0;
  end;

  if (tcase38_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase38_my_str_wide of
    'a'..'b': tcase38_i := 1;
    'c'..'d': tcase38_i := 2;
    else tcase38_i := 0;
  end;

  if (tcase38_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase38_my_str_ansi of
    'a'..'b': tcase38_i := 1;
    'c'..'d': tcase38_i := 2;
    else tcase38_i := 0;
  end;

  if (tcase38_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase38_my_str_uni of
    'a'..'b': tcase38_i := 1;
    'c'..'d': tcase38_i := 2;
    else tcase38_i := 0;
  end;

  if (tcase38_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase40.pp }
{$push}
{$H-}
begin
  tcase40_my_str := 'cab';
  tcase40_my_str_wide := 'cab';
  tcase40_my_str_ansi := 'cab';
  tcase40_my_str_uni := 'cab';
  tcase40_i := -1;

  case tcase40_my_str of
    'aba'..'daa': tcase40_i := 1;
    else tcase40_i := 0;
  end;

  if (tcase40_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase40_my_str_wide of
    'aba'..'daa': tcase40_i := 1;
    else tcase40_i := 0;
  end;

  if (tcase40_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase40_my_str_ansi of
    'aba'..'daa': tcase40_i := 1;
    else tcase40_i := 0;
  end;

  if (tcase40_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase40_my_str_uni of
    'aba'..'daa': tcase40_i := 1;
    else tcase40_i := 0;
  end;

  if (tcase40_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase41.pp }
{$push}
{$H-}
begin
  tcase41_my_str := 'cab';
  tcase41_my_str_wide := 'cab';
  tcase41_my_str_ansi := 'cab';
  tcase41_my_str_uni := 'cab';
  tcase41_i := -1;

  case tcase41_my_str of
    'a'..'daa': tcase41_i := 1;
    else tcase41_i := 0;
  end;

  if (tcase41_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase41_my_str_wide of
    'a'..'daa': tcase41_i := 1;
    else tcase41_i := 0;
  end;

  if (tcase41_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase41_my_str_ansi of
    'a'..'daa': tcase41_i := 1;
    else tcase41_i := 0;
  end;

  if (tcase41_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase41_my_str_uni of
    'a'..'daa': tcase41_i := 1;
    else tcase41_i := 0;
  end;

  if (tcase41_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase44.pp }
{$push}
{$H-}
begin
  tcase44_my_str := 'cab';
  tcase44_my_str_wide := 'cab';
  tcase44_my_str_ansi := 'cab';
  tcase44_my_str_uni := 'cab';
  tcase44_i := -1;

  case tcase44_my_str of
    'a'..'daa':
      begin
        case tcase44_my_str[1] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 1;
        end;
        case tcase44_my_str[2] of
          'a' : tcase44_i := tcase44_i * 1;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 0;
        end;
        case tcase44_my_str[3] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := tcase44_i * 1;
          'c' : tcase44_i := 0;
        end;
      end;
    else tcase44_i := 0;
  end;

  if (tcase44_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase44_my_str_wide of
    'a'..'daa':
      begin
        case tcase44_my_str_wide[1] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 1;
        end;
        case tcase44_my_str_wide[2] of
          'a' : tcase44_i := tcase44_i * 1;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 0;
        end;
        case tcase44_my_str_wide[3] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := tcase44_i * 1;
          'c' : tcase44_i := 0;
        end;
      end;
    else tcase44_i := 0;
  end;

  if (tcase44_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase44_my_str_ansi of
    'a'..'daa':
      begin
        case tcase44_my_str_ansi[1] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 1;
        end;
        case tcase44_my_str_ansi[2] of
          'a' : tcase44_i := tcase44_i * 1;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 0;
        end;
        case tcase44_my_str_ansi[3] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := tcase44_i * 1;
          'c' : tcase44_i := 0;
        end;
      end;
    else tcase44_i := 0;
  end;

  if (tcase44_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;


  case tcase44_my_str_uni of
    'a'..'daa':
      begin
        case tcase44_my_str_uni[1] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 1;
        end;
        case tcase44_my_str_uni[2] of
          'a' : tcase44_i := tcase44_i * 1;
          'b' : tcase44_i := 0;
          'c' : tcase44_i := 0;
        end;
        case tcase44_my_str_uni[3] of
          'a' : tcase44_i := 0;
          'b' : tcase44_i := tcase44_i * 1;
          'c' : tcase44_i := 0;
        end;
      end;
    else tcase44_i := 0;
  end;

  if (tcase44_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;

  writeln('OK!');
end;
{$pop}

{ Case tcase5.pp }
{$push}
{$H+}
begin
  tcase5_my_str := 'c';
  tcase5_i := -1;

  case tcase5_my_str of
    'a'..'b': tcase5_i := 1;
    'c'..'d': tcase5_i := 2;
    else tcase5_i := 0;
  end;

  if (tcase5_i <> 2) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase7.pp }
{$push}
{$H+}
begin
  tcase7_my_str := 'cab';
  tcase7_i := -1;

  case tcase7_my_str of
    'aba'..'daa': tcase7_i := 1;
    else tcase7_i := 0;
  end;

  if (tcase7_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcase8.pp }
{$push}
{$H+}
begin
  tcase8_my_str := 'cab';
  tcase8_i := -1;

  case tcase8_my_str of
    'a'..'daa': tcase8_i := 1;
    else tcase8_i := 0;
  end;

  if (tcase8_i <> 1) then begin
    writeln('Error');
    Halt(1);
  end;
end;
{$pop}

{ Case tcmp0.pp }
{$push}

begin
  tcmp0_res:=CompareChar0(tcmp0_str1[0],tcmp0_str2[0],maxint);
  if tcmp0_res<>0 then
    halt(1);
  tcmp0_res:=CompareChar0(tcmp0_str1[0],tcmp0_str3[0],maxint);
  if tcmp0_res>=0 then
    halt(1);
  tcmp0_res:=CompareChar0(tcmp0_str4[0],tcmp0_str1[0],maxint);
  if tcmp0_res>=0 then
    halt(1);
  tcmp0_res:=CompareChar0(tcmp0_str1[0],tcmp0_str4[0],maxint);
  if tcmp0_res<=0 then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tcpstr11.pp }
{$push}

begin
  tcpstr11_A := tcpstr11_c;
  if StringCodePage(tcpstr11_A) <> 866 then
    halt(1);
end;
{$pop}

{ Case tcpstr2.pp }
{$push}

begin
  tcpstr2_p(tcpstr2_s1);
end;
{$pop}

{ Case tcpstr2a.pp }
{$push}

begin
  tcpstr2a_s1:='Test: ';
  tcpstr2a_p(tcpstr2a_s1);
end;
{$pop}

{ Case tcpstr5.pp }
{$push}

begin
  tcpstr5_pw(tcpstr5_u);
  tcpstr5_pu(tcpstr5_w);
end;
{$pop}

{ Case tenum6.pp }
{$push}

begin
  tenum6_b:=false;
  str(tenum6_b,tenum6_s);
  if tenum6_s<>'FALSE' then
    halt(1);

  tenum6_b8:=false;
  str(tenum6_b8,tenum6_s);
  if tenum6_s<>'FALSE' then
    halt(1);

  tenum6_b16:=false;
  str(tenum6_b16,tenum6_s);
  if tenum6_s<>'FALSE' then
    halt(1);

  tenum6_b32:=false;
  str(tenum6_b32,tenum6_s);
  if tenum6_s<>'FALSE' then
    halt(1);

  tenum6_b64:=false;
  str(tenum6_b64,tenum6_s);
  if tenum6_s<>'FALSE' then
    halt(1);

  writeln('ok');
end;
{$pop}

{ Case tint641.pp }
{$push}
{$R-}
{$Q-}
begin
   tint641_q1:=1;
   tint641_q3:=1;
   tint641_q4:=1;
   if not((tint641_q4 div tint641_q3) div (tint641_q2 div tint641_q1)<>(tint641_q2 div tint641_q1) div (tint641_q4 div tint641_q3)) then
     begin
       writeln('Error :(');
       halt(1);
     end;
   tint641_q:=tint641_q-tint641_q;
   tint641_q:=tint641_q-(tint641_q*tint641_q);
   tint641_q:=(tint641_q*tint641_q)-(tint641_q*tint641_q);
   { first test the comparison }
   tint641_i:=tint641_f2;
   if tint641_q<>tint641_q then
     begin
       writeln('Error :(');
       halt(2);
     end;

   if tint641_q>tint641_q then
     begin
       writeln('Error :(');
       halt(3);
     end;

   if tint641_i>tint641_f2 then
     begin
       writeln('Error :(');
       halt(4);
     end;
   if tint641_l1>tint641_l2 then
     begin
       writeln('Error :(');
       halt(5);
     end;
   tint641_p1(tint641_q,tint641_i);
   tint641_q:=tint641_f1;
   tint641_i:=tint641_f2;
   tint641_q:=tint641_q+tint641_q;
   tint641_i:=((tint641_i+tint641_i) xor (tint641_i+tint641_i)) or ((tint641_i+tint641_i) xor (tint641_i+tint641_i));
   tint641_q:=tint641_q shl tint641_l1;
   tint641_q:=tint641_q shr tint641_l1;
   tint641_q:=(tint641_q shl tint641_l1)+(tint641_q shl tint641_l1);

   tint641_q:=not(tint641_q);
   tint641_i:=not(tint641_i);
   tint641_q:=not(tint641_q xor tint641_q);
   tint641_i:=not(tint641_i or tint641_i);

   { unary minus }
   tint641_q:=-tint641_q;
   tint641_i:=-tint641_i;
   tint641_q:=-(tint641_q xor tint641_q);
   tint641_i:=-(tint641_i or tint641_i);

   { multiplication }
   // q:=3;
   tint641_q:=tint641_q*tint641_q;

   tint641_i:=tint641_i*tint641_i;

   tint641_q:=tint641_q*(tint641_q*tint641_q);
   tint641_i:=tint641_i*(tint641_i*tint641_i);

   tint641_q:=(tint641_q*tint641_q)*(tint641_q*tint641_q);
   tint641_q:=((tint641_q*tint641_q)*(tint641_q*tint641_q))*((tint641_q*tint641_q)*(tint641_q*tint641_q));

   writeln(tint641_q);
   writeln(tint641_i);
{ test can't be interactive (PFV)
   read(q);
   read(i); }
   str(tint641_q,tint641_s);
   str(tint641_i,tint641_s);
end;
{$pop}

{ Case tismngd2.pp }
{$push}

begin
  if IsManagedType(tismngd2_l) then
    Halt(1);
  if IsManagedType(tismngd2_o) then
    Halt(2);
  if not IsManagedType(tismngd2__as) then
    Halt(3);
  Writeln('Ok');
end;
{$pop}

{ Case tover1.pp }
{$push}
{$ifndef ver1_0}
{$endif}
{$ifndef ver1_0}
{$endif}
Begin
  tover1_p_string:=nil;
  tover1_ansi_string:='';
  tover1_short_string:='';
{$ifndef ver1_0}
  tover1_wide_string:='';
{$endif}
  Write('Test of overloaded call to string routines...');
  { test parameter call }
  tover1_s:=tover1_test_string(tover1_short_string);
  if tover1_s <> tover1_RESULT_SHORT then
    tover1_fail;
  tover1_s:=tover1_test_string(tover1_ansi_string);
  if tover1_s <> tover1_RESULT_ANSI then
    tover1_fail;
{$ifndef ver1_0}
  tover1_s:=tover1_test_string(tover1_wide_string);
  if tover1_s <> tover1_RESULT_WIDE then
    tover1_fail;
{$endif}
  tover1_s:=tover1_test_string(tover1_p_string);
  if tover1_s <> tover1_RESULT_PCHAR then
    tover1_fail;
  WriteLn('Success!');
end;
{$pop}

{ Case tparray24.pp }
{$push}

begin
  tparray24_a[0]:='gh';
  tparray24_p(tparray24_a[0]);
  if (tparray24_a[0]<>'ab') then
    halt(1);
end;
{$pop}

{ Case tparray25.pp }
{$push}

begin
  tparray25_a[0]:='gh';
  tparray25_p(@tparray25_a[0]);
  if (tparray25_a[0]<>'ab') then
    halt(1);
end;
{$pop}

{ Case trstr1.pp }
{$push}

begin
  trstr1_s := '15';
  { temp ansistring must be kept until read is finished }
  readstr(trstr1_s+' ,305',trstr1_i,trstr1_c1,trstr1_c2,trstr1_j);
  if (trstr1_i <> 15) or
     (trstr1_c1 <> ' ') or
     (trstr1_c2 <> ',') or
     (trstr1_j <> 305) then
    halt(1);
end;
{$pop}

{ Case trstr2.pp }
{$push}

begin
  trstr2_s := '15 305';
  readstr(trstr2_s,trstr2_i,trstr2_j);
  if (trstr2_i <> 15) or
     (trstr2_j <> 305) then
    halt(1);
end;
{$pop}

{ Case trstr6.pp }
{$push}

begin
    trstr6_s:='666 123';
    new(trstr6_ipv1);
    new(trstr6_ipv2);
    new(trstr6_ipv3);
    trstr6_ipv2^ := 155;
    readstr(trstr6_s, trstr6_ip1^, trstr6_ipv2^);
    if (trstr6_ipv1^ = 666) and (trstr6_ipv2^ = 123) and (trstr6_ipv3^ = 155) then
      writeln('OK')
    else
      halt(1);
end;
{$pop}

{ Case tstring1.pp }
{$push}

begin
  if tstring1_TestOK then
   WriteLn('Test OK')
  else
    begin
      WriteLn('Test Failure!');
      halt(1);
    end;
end;
{$pop}

{ Case tunistrcopy.pp }
{$push}

begin
  tunistrcopy_a := '12345';
  tunistrcopy_b := Copy(tunistrcopy_a,1,Length(tunistrcopy_a));
  if (tunistrcopy_a <> tunistrcopy_b) then
    Halt(1);
  WriteLn('ok');
end;
{$pop}

{ Case tw29833.pp }
{$push}

begin
  tw29833_aURI:='abcdefg';
  SetString(tw29833_Server,@tw29833_aURI[1],Length(tw29833_aURI));
  if stringcodepage(tw29833_server)=CP_NONE then
    halt(1);
end;
{$pop}

{ Case twrstr2.pp }
{$push}

begin
  WriteStr (twrstr2_Foo, 'abcdef');
  if twrstr2_Foo <> 'abc' then
    halt(1);
end;
{$pop}

end.
