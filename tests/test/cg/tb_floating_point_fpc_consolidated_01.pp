{ Consolidated floating point regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case taddreal1.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondadd() FPU real type code                   }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}

{ Result is either LOC_FPU or LOC_REFERENCE                     }
{ LEFT NODE (operand) (left operator)                           }
{  LOC_REFERENCE / LOC_MEM                                      }
{  LOC_FPU                                                      }
{ RIGHT NODE (operand)                                          }
{  LOC_FPU                                                      }
{  LOC_REFERENCE / LOC_MEM                                      }

procedure taddreal1_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


 Procedure taddreal1_RealTestSub;
 var
  i : Real;
  j : Real;
  result : boolean;
 Begin
  Write('Real - Real test...');
  result := true;
  i:=99.9;
  j:=10.0;
  i:=i-j;
  if trunc(i) <> trunc(89.9) then
    result := false;
  WriteLn('Result (89.9) :',i,' trunc(i)=',trunc(i),' trunc(89.9)=',trunc(89.9));
  i:=j-i;
  if trunc(i) <> trunc(-79.9) then
    result := false;
  WriteLn('Result (-79.9) :',i,' trunc(i)=',trunc(i),' trunc(-79.9)=',trunc(-79.9));
  j:=j-10.0;
  if j <> 0.0 then
    result := false;
  WriteLn('Result (0.0) :',j);
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal1_RealTestAdd;
 var
  i : real;
  j : real;
  result : boolean;
 Begin
   WriteLn('Real + Real test...');
   result := true;
   i:= 9;
   i:=i+1.5;
   if trunc(i) <> trunc(10.5) then
     result := false;
   WriteLn('Result (10.5) :',i);
   i := 0.0;
   j := 100.0;
   i := i + j + j + 12.5;
   if trunc(i) <> trunc(212.5) then
     result := false;
   WriteLn('Result (212.5) :',i);
   if not result then
    taddreal1_Fail
   else
    WriteLn('Success.');
 end;


 procedure taddreal1_realtestmul;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  WriteLn('Real * Real test...');
  result := true;
  i:= 0;
  j:= 0;
  i := i * j * i;
  if trunc(i) <> trunc(0.0) then
    result := false;
  WriteLn('Result (0.0) :',i);
  i := 10.0;
  j := -12.0;
  i := i * j * 10.0;
  if trunc(i) <> trunc(-1200.0) then
    result := false;
  WriteLn('Result (-1200.0) :',i);
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;



 Procedure taddreal1_RealTestDiv;
 var
  i : Real;
  j : Real;
  result : boolean;
 Begin
  result := true;
  WriteLn('Real / Real test...');
  i:=-99.9;
  j:=10.0;
  i:=i / j;
  if trunc(i) <> trunc(-9.9) then
    result := false;
  WriteLn('Result (-9.9) :',i);
  i:=j / i;
  if trunc(i) <> trunc(-1.01) then
    result := false;
  WriteLN('Result (-1.01) :',i);
  j:=i / 10.0;
  if trunc(j) <> trunc(-0.1001) then
    result := false;
  WriteLn('Result (-0.1001) :',j);
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;



{ Procedure RealTestComplex;
 var
  i : real;
 Begin
   Write('RESULT SHOULD BE 2.09 :');
   i := 4.4;
   WriteLn(Sqrt(i));
   Write('RESULT SHOULD BE PI :');
   WriteLn(Pi);
   Write('RESULT SHOULD BE 4.0 :');
   WriteLn(Round(3.6));
 end;}


 procedure taddreal1_realtestequal;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real = Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (i=j) then
    result := false;
  if not (i=1000.0) then
    result := false;
  if not (trunc(i) = trunc(j)) then
    result := false;
  if not (trunc(i) = trunc(1000.0)) then
    result := false;
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal1_realtestnotequal;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real <> Real test...');
  i := 1000.0;
  j := 1000.0;
  if (i <> j) then
    result := false;
  if (i <> 1000.0) then
  if (trunc(i) <> trunc(j)) then
    result := false;
  if (trunc(i) <> trunc(1000.0)) then
    result := false;
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;


 procedure taddreal1_realtestle;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real <= Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (i <= j) then
    result := false;
  if not (i <= 1000.0) then
    result := false;
  if not (trunc(i) <= trunc(j)) then
    result := false;
  if not (trunc(i) <= trunc(1000.0)) then
    result := false;
  i := 10000.0;
  j := 999.0;
  if trunc(i) < trunc(j) then
    result := false;
  if trunc(i) < trunc(999.0) then
    result := false;
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal1_realtestge;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real >= Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (i >= j) then
    result := false;
  if not (i >= 1000.0) then
    result := false;
  if not (trunc(i) >= trunc(j)) then
    result := false;
  if not (trunc(i) >= trunc(1000.0)) then
    result := false;
  i := 999.0;
  j := 1000.0;
  if i > j then
    result := false;
  if i > 999.0 then
    result := false;
  if trunc(i) > trunc(j) then
    result := false;
  if trunc(i) > trunc(999.0) then
    result := false;
  if not result then
    taddreal1_Fail
  else
    WriteLn('Success.');
 end;



{$pop}

{ Case taddreal2.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondadd() FPU real type code                   }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}

{ Result is either LOC_FPU or LOC_REFERENCE                     }
{ LEFT NODE (operand) (left operator)                           }
{  LOC_REFERENCE / LOC_MEM                                      }
{  LOC_FPU                                                      }
{ RIGHT NODE (operand)                                          }
{  LOC_FPU                                                      }
{  LOC_REFERENCE / LOC_MEM                                      }
procedure taddreal2_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


 Procedure taddreal2_RealTestSub;
 var
  i : Real;
  j : Real;
  result : boolean;
 Begin
  Write('Real - Real test...');
  result := true;
  i:=99.9;
  j:=10.0;
  i:=i-j;
  if trunc(i) <> trunc(89.9) then
    result := false;
  WriteLn('Result (89.9) :',i);
  i:=j-i;
  if trunc(i) <> trunc(-79.9) then
    result := false;
  WriteLn('Result (-79.9) :',i);
  j:=j-10.0;
  if j <> 0.0 then
    result := false;
  WriteLn('Result (0.0) :',j);
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal2_RealTestAdd;
 var
  i : real;
  j : real;
  result : boolean;
 Begin
   WriteLn('Real + Real test...');
   result := true;
   i:= 9;
   i:=i+1.5;
   if trunc(i) <> trunc(10.5) then
     result := false;
   WriteLn('Result (10.5) :',i);
   i := 0.0;
   j := 100.0;
   i := i + j + j + 12.5;
   if trunc(i) <> trunc(212.5) then
     result := false;
   WriteLn('Result (212.5) :',i);
   if not result then
    taddreal2_Fail
   else
    WriteLn('Success.');
 end;


 procedure taddreal2_realtestmul;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  WriteLn('Real * Real test...');
  result := true;
  i:= 0;
  j:= 0;
  i := i * j * i;
  if trunc(i) <> trunc(0.0) then
    result := false;
  WriteLn('Result (0.0) :',i);
  i := 10.0;
  j := -12.0;
  i := i * j * 10.0;
  if trunc(i) <> trunc(-1200.0) then
    result := false;
  WriteLn('Result (-1200.0) :',i);
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;



 Procedure taddreal2_RealTestDiv;
 var
  i : Real;
  j : Real;
  result : boolean;
 Begin
  result := true;
  WriteLn('Real / Real test...');
  i:=-99.9;
  j:=10.0;
  i:=i / j;
  if trunc(i) <> trunc(-9.9) then
    result := false;
  WriteLn('Result (-9.9) :',i);
  i:=j / i;
  if trunc(i) <> trunc(-1.01) then
    result := false;
  WriteLN('Result (-1.01) :',i);
  j:=i / 10.0;
  if trunc(j) <> trunc(-0.1001) then
    result := false;
  WriteLn('Result (-0.1001) :',j);
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;



{ Procedure RealTestComplex;
 var
  i : real;
 Begin
   Write('RESULT SHOULD BE 2.09 :');
   i := 4.4;
   WriteLn(Sqrt(i));
   Write('RESULT SHOULD BE PI :');
   WriteLn(Pi);
   Write('RESULT SHOULD BE 4.0 :');
   WriteLn(Round(3.6));
 end;}


 procedure taddreal2_realtestequal;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real = Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (trunc(i) = trunc(j)) then
    result := false;
  if not (trunc(i) = trunc(1000.0)) then
    result := false;
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal2_realtestnotequal;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real <> Real test...');
  i := 1000.0;
  j := 1000.0;
  if (trunc(i) <> trunc(j)) then
    result := false;
  if (trunc(i) <> trunc(1000.0)) then
    result := false;
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;


 procedure taddreal2_realtestle;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real <= Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (trunc(i) <= trunc(j)) then
    result := false;
  if not (trunc(i) <= trunc(1000.0)) then
    result := false;
  i := 10000.0;
  j := 999.0;
  if trunc(i) < trunc(j) then
    result := false;
  if trunc(i) < trunc(999.0) then
    result := false;
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal2_realtestge;
 var
  i : real;
  j : real;
  result : boolean;
 begin
  result := true;
  Write('Real >= Real test...');
  i := 1000.0;
  j := 1000.0;
  if not (trunc(i) >= trunc(j)) then
    result := false;
  if not (trunc(i) >= trunc(1000.0)) then
    result := false;
  i := 999.0;
  j := 1000.0;
  if trunc(i) > trunc(j) then
    result := false;
  if trunc(i) > trunc(999.0) then
    result := false;
  if not result then
    taddreal2_Fail
  else
    WriteLn('Success.');
 end;



{$pop}

{ Case texit.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{  By Carl Eric Codere                                           }
{****************************************************************}
{ NODE TESTED : secondexitn()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{                 secondcalln()                                  }
{                 secondin()                                     }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}

procedure texit_fail;
begin
  WriteLn('Failure.');
  halt(1);
end;


function texit_simple_exit : longint;
 var
  z : longint;
 begin
  z:=0;
  exit;
  z:=12;
 end;


const
  texit_RET_S64BIT = $100000;
  texit_RET_S32BIT = -123456;
  texit_RET_U32BIT = 2000000;
  texit_RET_S16BIT = -30000;
  texit_RET_U16BIT = $5555;
  texit_RET_S8BIT  = -80;
  texit_RET_U8BIT = $AA;
{$ifndef FPUNONE}
  texit_RET_SINGLE = 57689.15;
  texit_RET_DOUBLE = 100012.345;
{$endif FPUNONE}
  texit_PCHAR_STRING: pchar = 'HELLO STRING';

type
  texit_t24bitarray = packed array[1..3] of byte;

var
 texit_global_var : longint;


 function texit_getu8bit : byte;
  begin
    texit_getu8bit := texit_RET_U8BIT;
  end;

 function texit_gets8bit : shortint;
  begin
    texit_gets8bit := texit_RET_S8BIT;
  end;


 function texit_getu16bit : word;
  begin
    texit_getu16bit := texit_RET_U16BIT;
  end;

 function texit_gets16bit : smallint;
  begin
    texit_gets16bit := texit_RET_S16BIT;
  end;


 function texit_getu32bit : cardinal;
  begin
    texit_getu32bit := texit_RET_U32BIT;
  end;

 function texit_gets32bit : longint;
  begin
    texit_gets32bit := texit_RET_S32BIT;
  end;


  function texit_gets64bit : int64;
   begin
     texit_gets64bit := texit_RET_S64BIT;
   end;

{$ifndef FPUNONE}
   function texit_gets32real : single;
    begin
     texit_gets32real := texit_RET_SINGLE;
    end;


   function texit_gets64real : double;
    begin
     texit_gets64real := texit_RET_DOUBLE;
    end;
{$endif FPUNONE}

   function texit_getpchar: pchar;
    begin
     texit_getpchar := texit_PCHAR_STRING;
    end;


function texit_exit_loc_mem_ordinal_1 : longint;
 var
  z : longint;
 begin
  texit_global_var:=0;
  texit_global_var:=texit_RET_S32BIT;
  exit(texit_global_var);
  texit_global_var:=texit_RET_S32BIT;
 end;


function texit_exit_loc_reg_pointerdef  : pchar;
 begin
  exit(texit_getpchar);
 end;

function texit_exit_loc_ref_pointerdef  : pchar;
 var
  p: pchar;
 begin
  p:=texit_PCHAR_STRING;
  exit(p);
 end;

function texit_exit_loc_reg_ordinal_s64bit  : int64;
 begin
  exit(texit_gets64bit);
 end;

function texit_exit_loc_reg_ordinal_s32bit  :longint;
 begin
  exit(texit_gets32bit);
 end;

function texit_exit_loc_reg_ordinal_u32bit  :cardinal;
 begin
  exit(texit_getu32bit);
 end;

function texit_exit_loc_reg_ordinal_s16bit  : smallint;
 begin
  exit(texit_gets16bit);
 end;

function texit_exit_loc_reg_ordinal_u16bit  :word;
 begin
  exit(texit_getu16bit)
 end;

function texit_exit_loc_reg_ordinal_s8bit  : shortint;
 begin
  exit(texit_gets8bit);
 end;

function texit_exit_loc_reg_ordinal_u8bit  : byte;
 begin
   exit(texit_getu8bit);
 end;




function texit_exit_loc_ref_constant : word;
 begin
  exit(texit_RET_U16BIT);
 end;



function texit_exit_loc_ref_ordinal_s64bit  : int64;
 var
   s : int64;
 begin
  s := texit_RET_S64BIT;
  exit(s);
 end;

function texit_exit_loc_ref_ordinal_s32bit  :longint;
 var
   s : longint;
 begin
  s := texit_RET_S32BIT;
  exit(s);
 end;

function texit_exit_loc_ref_ordinal_u32bit  :cardinal;
 var
  c: cardinal;
 begin
  c := texit_RET_U32BIT;
  exit(c);
 end;

function texit_exit_loc_ref_ordinal_s16bit  : smallint;
 var
  s : smallint;
 begin
  s := texit_RET_S16BIT;
  exit(s);
 end;

function texit_exit_loc_ref_ordinal_u16bit  :word;
 var
  w: word;
 begin
  w := texit_RET_U16BIT;
  exit(w);
 end;

function texit_exit_loc_ref_ordinal_s8bit  : shortint;
 var
  s : shortint;
 begin
  s := texit_RET_S8BIT;
  exit(s);
 end;

function texit_exit_loc_ref_ordinal_u8bit  : byte;
 var
  b: byte;
 begin
   b:=texit_RET_U8BIT;
   exit(b);
 end;


 function texit_exit_loc_ref_ordinal_24bit : texit_t24bitarray;
  var
   r : texit_t24bitarray;
  begin
    r[1]:=12;
    r[2]:=13;
    r[3]:=14;
    exit(r);
  end;


{$ifndef FPUNONE}
function texit_exit_loc_ref_float_s32real : single;
 var
  s: single;
 begin
   s:=texit_RET_SINGLE;
   exit(s);
 end;


function texit_exit_loc_ref_float_s64real : double;
 var
  s: double;
 begin
   s:=texit_RET_DOUBLE;
   exit(s);
 end;


function texit_exit_loc_reg_float_s32real : single;
 begin
   exit(texit_gets32real);
 end;


function texit_exit_loc_reg_float_s64real : double;
 begin
   exit(texit_gets64real);
 end;
{$endif FPUNONE}


function texit_exit_loc_flags : boolean;
 var
   c: char;
 begin
  c:='A';
  exit(c in ['a'..'z']);
 end;

function texit_exit_loc_jump : boolean;
 var
   b,c: boolean;
 begin
  b:=TRUE;
  c:=FALSE;
  exit(b and c);
 end;

{$ifdef FPC_HAS_FEATURE_ANSISTRINGS}
 function texit_exit_loc_ansi(w: word) : ansistring;
  var d: ansistring;
 begin
   str(w,d);
   exit(d);
 end;
{$endif FPC_HAS_FEATURE_ANSISTRINGS}

var
 texit_failed : boolean;
 texit_array_24bits : texit_t24bitarray;

{$pop}

{ Case tldparam.pp }
{$push}
{ This tests the passing of parameters of routines }
{ and how they are accessed.                       }
{ Tests secondload() and secondcallparan()         }

{ TO DO :                                         }
{   Add testing for complex parameters            }
{   such as string, arrays and sets               }


{ ***************************************************************** }
{                         SIMPLE TYPES                              }
{ ***************************************************************** }

  procedure tldparam_testvaluebyte(tldparam_b: byte);
   begin
     WriteLn(tldparam_b);
   end;


  procedure tldparam_testvalueword(tldparam_w: word);
   begin
     WriteLn(tldparam_w);
   end;


  procedure tldparam_testvaluelong(tldparam_l : longint);
   begin
     WriteLn(tldparam_l);
   end;


  procedure tldparam_testvarbyte(var tldparam_b: byte);
    begin
      WriteLn(tldparam_b);
    end;


  procedure tldparam_testvarword(var tldparam_w: word);
    begin
      writeln(tldparam_w);
    end;


  procedure tldparam_testvarlong(var tldparam_l : longint);
    begin
      writeln(tldparam_l);
    end;


  procedure tldparam_testvaluemixedbyte(tldparam_b: byte; tldparam_w: word; tldparam_l: longint);
    begin
      Writeln(tldparam_b);
      writeln(tldparam_w);
      writeln(tldparam_l);
    end;


  procedure tldparam_testvaluemixedlong(tldparam_l : longint; tldparam_w: word; tldparam_b: byte);
    begin
      Writeln(tldparam_l);
      writeln(tldparam_w);
      writeln(tldparam_b);
    end;


  procedure tldparam_testvaluemixedbytebyte(b1: byte; b2: byte; b3: byte);
    begin
      Writeln(b1);
      writeln(b2);
      writeln(b3);
    end;

{$ifdef fpc}
  procedure tldparam_testvalueint64(tldparam_i : int64);
    begin
      WriteLn(tldparam_i);
    end;

  procedure tldparam_testvarint64(var tldparam_i : int64);
   begin
     WriteLn(tldparam_i);
   end;

  procedure tldparam_testvaluemixedint64(b1: byte; tldparam_i: int64; b2: byte);
   begin
     WriteLn(b1);
     WriteLn(tldparam_i);
     WriteLn(b2);
   end;
{$endif}

   procedure tldparam_testvaluereal(tldparam_r: real);
    begin
      WriteLn(tldparam_r);
    end;

   procedure tldparam_testvaluesingle(s: single);
    begin
      WriteLn(s);
    end;

   procedure tldparam_testvaluedouble(d: double);
     begin
       WriteLn(d);
     end;


   procedure tldparam_testvaluemixedreal(b1: byte; tldparam_r: real; b2: byte);
    begin
      WriteLn(b1);
      WriteLn(tldparam_r);
      WriteLn(b2);
    end;

  procedure tldparam_testvarreal(var tldparam_r: real);
   begin
     WriteLn(tldparam_r);
   end;

   { only check assembler code }
   { cannot be called directly }
   { because will crash system }
   procedure tldparam_testint; interrupt;
    begin
    end;



{ ***************************************************************** }
{                        COMPLEX TYPES                              }
{ ***************************************************************** }



{ ***************************************************************** }
{                        RETURN TYPES                               }
{ ***************************************************************** }


   function tldparam_testretbyte: byte;
     begin
       Write('(byte) : Value should be 127...');
       tldparam_testretbyte:= 127;
     end;

   function tldparam_testretword: word;
     begin
       Write('(word) : Value should be 43690...');
       tldparam_testretword := 43690;
     end;

   function tldparam_testretlong : longint;
     begin
       Write('(long) : Value should be -1...');
       tldparam_testretlong := -1;
     end;

   function tldparam_testretstring: string;
     begin
       Write('(string) : Value should be ''HELLO WORLD''...');
       tldparam_testretstring := 'HELLO WORLD';
     end;

    function tldparam_testretreal : real;
      begin
        Write('(real) : Value should be 12.12...');
        tldparam_testretreal := 12.12;
      end;

    function tldparam_testretsingle : single;
      begin
        Write('(single) : Value should be 13.13...');
        tldparam_testretsingle := 13.13;
      end;

    function tldparam_testretdouble : double;
      begin
        Write('(double) : Value should be 14.14...');
        tldparam_testretdouble := 14.14;
      end;

    function tldparam_testretpchar: pchar;
    begin
       Write('(pchar) : Value should be  ...');
       tldparam_testretpchar := nil;
    end;

{$ifdef fpc}
    function tldparam_testretint64 : int64;
      begin
        Write('(int64) : Value should be -127...');
        tldparam_testretint64 := -127;
      end;

    function tldparam_testretansi: ansistring;
      begin
         Write('(ansi) : Value should be ''HELLO WORLD''...');
         tldparam_testretansi := 'HELLO WORLD';
      end;


{$ifdef fpc}

{$inline on}

   function tldparam_testretbyteinline: byte; inline;
     begin
       Write('(byte) : Value should be 126...');
       tldparam_testretbyteinline:= 126;
     end;

   function tldparam_testretwordinline: word; inline;
     begin
       Write('(word) : Value should be 43689...');
       tldparam_testretwordinline := 43689;
     end;

    function tldparam_testretint64inline : int64;inline;
      begin
        Write('(int64) : Value should be -128...');
        tldparam_testretint64inline := -128;
      end;

    function tldparam_testretrealinline : real; inline;
      begin
        Write('(real) : Value should be 110.110...');
        tldparam_testretrealinline := 110.110;
      end;

    function tldparam_testretdoubleinline : double; inline;
      begin
        Write('(double) : Value should be 130.130...');
        tldparam_testretdoubleinline := 130.130;
      end;


{$ifdef VER1_0}
   function tldparam_testretbyteregs: byte; saveregisters;
     begin
       Write('(byte) : Value should be 125...');
       tldparam_testretbyteregs:= 125;
     end;

   function tldparam_testretwordregs: word; saveregisters;
     begin
       Write('(word) : Value should be 43688...');
       tldparam_testretwordregs := 43688;
     end;

    function tldparam_testretint64regs : int64;saveregisters;
      begin
        Write('(int64) : Value should be -130...');
        tldparam_testretint64regs := -130;
      end;

    function tldparam_testretrealregs : real; saveregisters;
      begin
        Write('(real) : Value should be -55.55...');
        tldparam_testretrealregs := -55.55;
      end;

    function tldparam_testretdoubleregs : double; saveregisters;
      begin
        Write('(double) : Value should be -77.14...');
        tldparam_testretdoubleregs := -77.14;
      end;
{$endif VER1_0}

   function tldparam_testretbytecdecl: byte; cdecl;
     begin
       Write('(byte) : Value should be 125...');
       tldparam_testretbytecdecl:= 125;
     end;

   function tldparam_testretwordcdecl: word; cdecl;
     begin
       Write('(word) : Value should be 43688...');
       tldparam_testretwordcdecl := 43688;
     end;

    function tldparam_testretint64cdecl : int64; cdecl;
      begin
        Write('(int64) : Value should be -130...');
        tldparam_testretint64cdecl := -130;
      end;

    function tldparam_testretrealcdecl : real; cdecl;
      begin
        Write('(real) : Value should be -55.55...');
        tldparam_testretrealcdecl := -55.55;
      end;

    function tldparam_testretdoublecdecl : double; cdecl;
      begin
        Write('(double) : Value should be -77.14...');
        tldparam_testretdoublecdecl := -77.14;
      end;

{$endif}


{$endif}

var
 tldparam_b: byte;
 tldparam_w: word;
 tldparam_l: longint;
 tldparam_r: real;
{$ifdef fpc}
  tldparam_i: int64;
{$endif}

{$pop}

{ Case tneg.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondunaryminus()                               }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{            FPC     = Target is FreePascal compiler             }
{****************************************************************}
{ REMARKS:                                                       }
{                                                                }
{                                                                }
{                                                                }
{****************************************************************}



{----------------------------------------------------}
{ Cases to test:                                     }
{   CURRENT NODE (result value)                      }
{     - LOC_REGISTER                                 }
{     - LOC_FPU                                      }
{   LEFT NODE (value to negate)                      }
{     - LOC_CREGISTER                                }
{     - LOC_REFERENCE / LOC_MEM                      }
{     - LOC_REGISTER                                 }
{     - LOC_FPU                                      }
{----------------------------------------------------}

procedure tneg_test(value, required: longint);
begin
  if value <> required then
    begin
      writeln('Got ',value,' instead of ',required);
      halt(1);
    end
  else
    writeln('Passed!');
end;

procedure tneg_fail;
 begin
   writeln('Failure.');
   halt(1);
 end;


  function tneg_getreal: real;
   begin
     tneg_getreal := 1.0;
   end;

var
 tneg_longval :  longint;
 tneg_realval : real;
 tneg_byteval : longint;
{$IFDEF FPC}
 tneg_int64val : int64;
{$ENDIF}

{$pop}

begin

{ Case taddreal1.pp }
{$push}

Begin
 taddreal1_RealTestEqual;
 taddreal1_RealTestNotEqual;
 taddreal1_RealTestLE;
 taddreal1_RealTestGE;
 taddreal1_RealTestSub;
 taddreal1_RealTestAdd;
 taddreal1_RealTestDiv;
 taddreal1_RealTestMul;
{ RealTestComplex;}
end;
{$pop}

{ Case taddreal2.pp }
{$push}

Begin
 taddreal2_RealTestEqual;
 taddreal2_RealTestNotEqual;
 taddreal2_RealTestLE;
 taddreal2_RealTestGE;
 taddreal2_RealTestSub;
 taddreal2_RealTestAdd;
 taddreal2_RealTestDiv;
 taddreal2_RealTestMul;
{ RealTestComplex;}
end;
{$pop}

{ Case texit.pp }
{$push}
{$ifndef FPUNONE}
{$endif FPUNONE}
{$ifndef FPUNONE}
{$endif FPUNONE}
{$ifndef FPUNONE}
{$endif FPUNONE}
{$ifdef FPC_HAS_FEATURE_ANSISTRINGS}
{$endif FPC_HAS_FEATURE_ANSISTRINGS}
Begin

 { simple exit }
 write('Testing secondexitn() simple case...');
 texit_failed := false;
 texit_simple_exit;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

 write('Testing secondexitn() with reference (simple case)...');
 texit_failed := false;
 texit_array_24bits := texit_exit_loc_ref_ordinal_24bit;
 if (texit_array_24bits[1]<>12) or (texit_array_24bits[2]<>13) or (texit_array_24bits[3]<>14) then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

 write('secondexitn() LOC_CONSTANT case...');
 texit_failed := false;
 if texit_exit_loc_ref_constant <> texit_RET_U16BIT then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');



 write('secondexitn() LOC_MEM case...');
 texit_failed := false;
 if texit_exit_loc_mem_ordinal_1 <> texit_RET_S32BIT then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

 writeln('Testing secondexitn() LOC_REFERENCE case...');

 write('    ordinal/enumdef return value...');
 texit_failed := false;
 if texit_exit_loc_ref_ordinal_s64bit <> texit_RET_S64BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_s32bit <> texit_RET_S32BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_u32bit <> texit_RET_U32BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_s16bit <> texit_RET_S16BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_u16bit <> texit_RET_U16BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_s8bit <> texit_RET_S8BIT then
   texit_failed := true;
 if texit_exit_loc_ref_ordinal_u8bit <> texit_RET_U8BIT then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

{$ifndef FPUNONE}
 write('    floating point return value...');
 texit_failed := false;
 if (trunc(texit_exit_loc_ref_float_s32real) <>  trunc(texit_RET_SINGLE)) then
  texit_failed := true;
 if trunc(texit_exit_loc_ref_float_s64real) <> trunc(texit_RET_DOUBLE) then
  texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');
{$endif FPUNONE}

 { procvardef is not tested since it is the same as pointer return value...}
 write('    pointer/procedure variable return value...');
 texit_failed := false;
 { compare the actual pointer not the values inside the string ! }
 if (texit_exit_loc_ref_pointerdef  <> texit_PCHAR_STRING) then
   texit_failed:=true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');



 writeln('Testing secondexitn() LOC_REGISTER case...');

 write('    ordinal/enumdef return value...');
 texit_failed := false;
 if texit_exit_loc_reg_ordinal_s64bit <> texit_RET_S64BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_s32bit <> texit_RET_S32BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_u32bit <> texit_RET_U32BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_s16bit <> texit_RET_S16BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_u16bit <> texit_RET_U16BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_s8bit <> texit_RET_S8BIT then
   texit_failed := true;
 if texit_exit_loc_reg_ordinal_u8bit <> texit_RET_U8BIT then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

{$ifndef FPUNONE}
 write('    floating point return value...');
 texit_failed := false;
 if (trunc(texit_exit_loc_reg_float_s32real) <>  trunc(texit_RET_SINGLE)) then
  texit_failed := true;
 if trunc(texit_exit_loc_reg_float_s64real) <> trunc(texit_RET_DOUBLE) then
  texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');
{$endif FPUNONE}

 { procvardef is not tested since it is the same as pointer return value...}
 write('    pointer/procedure variable return value...');
 texit_failed := false;
 { compare the actual pointer not the values inside the string ! }
 if (texit_exit_loc_reg_pointerdef  <> texit_PCHAR_STRING) then
   texit_failed:=true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');


 write('Testing secondexitn() LOC_FLAGS case...');
 texit_failed := false;
 { check for false, since having zero in register is rarer   }
 { then having non-zero (just in case everything is corrupt) }
 if texit_exit_loc_flags then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

 write('Testing secondexitn() LOC_JUMP case...');
 texit_failed := false;
 { check for false, since having zero in register is rarer   }
 { then having non-zero (just in case everything is corrupt) }
 if texit_exit_loc_jump then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');

{$ifdef FPC_HAS_FEATURE_ANSISTRINGS}
 write('Testing secondexitn() ansistring case...');
 texit_failed := false;
 if texit_exit_loc_ansi(10) <> '10' then
   texit_failed := true;
 if texit_failed then
   texit_fail
 else
   writeln('Passed!');
{$endif FPC_HAS_FEATURE_ANSISTRINGS}

end;
{$pop}

{ Case tldparam.pp }
{$push}
{$ifdef fpc}
{$endif}
{$ifdef fpc}
{$ifdef fpc}
{$inline on}
{$ifdef VER1_0}
{$endif VER1_0}
{$endif}
{$endif}
{$ifdef fpc}
{$endif}
begin
  WriteLn('------------------------------------------------------');
  WriteLN('           TESTING NON-COMPLEX PARAMETERS             ');
  WriteLn('------------------------------------------------------');
{  testint;}
  { check value parameters }
  Write('(byte value param) : Value should be 85...');
  tldparam_testvaluebyte($55);
  Write('(word value param) : Value should be 43690...');
  tldparam_testvalueword($AAAA);
  Write('(long value param) : Value should be -1...');
  tldparam_testvaluelong(-1);
  { check variable parameters }
  tldparam_b:=$55;
  tldparam_w:=$AAAA;
  tldparam_l:=-1;
  Write('(byte var param) : Value should be 85...');
  tldparam_testvarbyte(tldparam_b);
  Write('(word var param) : Value should be 43690...');
  tldparam_testvarword(tldparam_w);
  Write('(long var param) : Value should be -1...');
  tldparam_testvarlong(tldparam_l);
{$ifdef fpc}
  Write('(int64 value param) : Value should be 43690...');
  tldparam_testvalueint64($AAAA);
  Write('(int64 var param) : Value should be appx. 187 00000000000...');
  tldparam_i:= $AAAA;
  tldparam_i:= tldparam_i shl 32;
  tldparam_testvarint64(tldparam_i);
{$endif}
  writeln('(mixed value params) : Values should 85,43690,-1...');
  tldparam_testvaluemixedbyte($55,$AAAA,-1);
  writeln('(mixed value params) : Values should be -1, 43690, 85...');
  tldparam_testvaluemixedlong(-1,$AAAA,$55);
  writeln('(mixed value params): Values should be 0, 127, 254...');
  tldparam_testvaluemixedbytebyte(0,127,254);
{$ifdef fpc}
  writeln('(mixed value params) : Value should be 0, -1, 254...');
  tldparam_testvaluemixedint64(0,-1,254);
{$endif}
  write('(real value param) : Value should be 1.1...');
  tldparam_testvaluereal(1.1);
  write('(single value param) : Value should be 2.2...');
  tldparam_testvaluesingle(2.2);
  write('(double value param) : Value should be 3.3...');
  tldparam_testvaluedouble(3.3);
  write('(real var param) : Value should be 7.7...');
  tldparam_r:=7.7;
  tldparam_testvarreal(tldparam_r);
  writeln('(mixed value params) : Values should be 0, 10.7, 254...');
  tldparam_testvaluemixedreal(0,10.7,254);

  WriteLn('------------------------------------------------------');
  WriteLN('              TESTING FUNCTION RESULTS                ');
  WriteLn('------------------------------------------------------');
  WriteLn('----------------------- NORMAL -----------------------');
  WriteLn(tldparam_testretbyte);
  WriteLn(tldparam_testretword);
  WriteLn(tldparam_testretlong);
  WriteLn(tldparam_testretstring);
  WriteLn(tldparam_testretreal);
  WriteLn(tldparam_testretsingle);
  WriteLn(tldparam_testretdouble);
  WriteLn(tldparam_testretpchar);
{$ifdef fpc}
  WriteLn(tldparam_testretint64);
  WriteLn(tldparam_testretansi);
  WriteLn('----------------------- INLINE -----------------------');
  WriteLn(tldparam_testretbyteinline);
  WriteLn(tldparam_testretwordinline);
  WriteLn(tldparam_testretint64inline);
  WriteLn(tldparam_testretrealinline);
  WriteLn(tldparam_testretdoubleinline);
{$ifdef VER1_0}
  WriteLn('---------------------- SAVEREGS ----------------------');
  WriteLn(tldparam_testretbyteregs);
  WriteLn(tldparam_testretwordregs);
  WriteLn(tldparam_testretint64regs);
  WriteLn(tldparam_testretrealregs);
  WriteLn(tldparam_testretdoubleregs);
{$endif VER1_0}
  WriteLn('------------------------ CDECL -----------------------');
  WriteLn(tldparam_testretbytecdecl);
  WriteLn(tldparam_testretwordcdecl);
  WriteLn(tldparam_testretint64cdecl);
  WriteLn(tldparam_testretrealcdecl);
  WriteLn(tldparam_testretdoublecdecl);
{$endif}
end;
{$pop}

{ Case tneg.pp }
{$push}
{$IFDEF FPC}
{$ENDIF}
Begin
   WriteLn('------------------------------ LONGINT --------------------------------');
   { CURRENT NODE: REGISTER }
   { LEFT NODE : REFERENCE  }
   tneg_longval := 1;
   tneg_longval := - tneg_longval;
   Write('Value should be -1...');
   tneg_test(tneg_longval, -1);

   { CURRENT NODE : REGISTER }
   { LEFT NODE: REGISTER     }
   tneg_byteval := 2;
   tneg_longval := - tneg_byteval;
   Write('Value should be -2...');
   tneg_test(tneg_longval, -2);

   { CURRENT NODE: LOC_FPU }
   { LEFT NODE : LOC_REFERENCE }
   tneg_realval := -1.0;
   tneg_realval := - tneg_realval;
   Write('Value should 1.0...');
   if tneg_realval - 1.0 = 0.0 then
      WriteLn('Passed!')
   else
      tneg_Fail;

   { LEFT NODE : LOC_FPU }
   { CURRENT NODE : LOC_FPU }
   tneg_realval := -1.0;
   tneg_realval := -(tneg_getreal*(tneg_realval));
   Write('Value should 1.0...');
   if tneg_realval - 1.0 = 0.0 then
      WriteLn('Passed!')
   else
      tneg_Fail;

{$IFDEF FPC}
   WriteLn('------------------------------  INT64  --------------------------------');
   { CURRENT NODE: REGISTER }
   { LEFT NODE : REFERENCE  }
   tneg_int64val := 1;
   tneg_int64val := - tneg_int64val;
   Write('Value should be -1...');

   { the following test give range check errors }
   {$R-}
   tneg_test(tneg_int64val and $FFFFFFFF, -1);

   { CURRENT NODE : REGISTER }
   { LEFT NODE: REGISTER     }
   tneg_byteval := 2;
   tneg_int64val := - tneg_byteval;
   Write('Value should be -2...');
   tneg_test(tneg_int64val and $FFFFFFFF, -2);
{$ENDIF}
end;
{$pop}

end.
