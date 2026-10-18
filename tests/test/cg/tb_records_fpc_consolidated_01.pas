{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tbuserror.pas }
{$push}

{ This test was created to check
  a code generation problem on sparc CPU
  in which OS_32 LD/ST operations were
  used on memory not aligned on a 4-byte
  boundary, leading to BUS error at execution.
  The test execution also checks that the value
  parameter changes are not passed back
  to the original variable in calling code. }

type
  tbuserror_trec = record
    w1 : word;
    b1 : boolean;
    b2 : byte;
  end;

  tbuserror_trec2 = record
    b3 : boolean;
    rec : tbuserror_trec;
  end;

const
  tbuserror_const_b2 = 45;
  tbuserror_const_w1 = 23456;
  tbuserror_count : integer = 0;

procedure tbuserror_check_trec(tbuserror_tr : tbuserror_trec);

begin
  if not tbuserror_tr.b1 or (tbuserror_tr.b2<>tbuserror_const_b2) or (tbuserror_tr.w1<>tbuserror_const_w1) then
    begin
      writeln('Wrong value passed to check_trec');
      halt(1);
    end
  else
    begin
      writeln(tbuserror_count,': check_rec ok');
    end;
  inc(tbuserror_tr.b2);
  dec(tbuserror_tr.w1);
  inc(tbuserror_count);
end;

var
  tbuserror_tr : tbuserror_trec;
  tbuserror_tr2 : tbuserror_trec2;


{$pop}

{ Case tbytetypecast.pas }
{$push}
{ Test to check code generation problem for powerpc64 CPU } 
{ Related to commit 35604b0926 PM }

var
  tbytetypecast_HasError : boolean;
  tbytetypecast_ErrorCount : longint;

procedure tbytetypecast_error(i : longint);

begin
  writeln('Error at pos ',i);
  tbytetypecast_HasError:=true;
  inc(tbytetypecast_ErrorCount);
end;

type
  tbytetypecast_TRecord = record
    tbytetypecast_w1,tbytetypecast_w2,w3,w4 : word;
  end;

var
  tbytetypecast_w1, tbytetypecast_w2 : word;
  tbytetypecast_b1, tbytetypecast_b2 : byte;
  tbytetypecast_rec : tbytetypecast_TRecord;

function tbytetypecast_getrec : tbytetypecast_TRecord;
  begin
    tbytetypecast_getrec:=tbytetypecast_rec;
  end;


{$pop}

{ Case tm128.pas }
{$push}
{$ASSERTIONS ON}

type
  tm128_tm128 = record
    case byte of
      1 : (m128_f32 : array[0..3] of single;)
  end align 16;

type
  tm128_tm128_unaligned = record
    case byte of
      1 : (m128_f32 : array[0..3] of single;)
  end;


var
  tm128_tr1 : record
    b : byte;
    m128 : tm128_tm128;
  end;
  tm128_tr1_unaligned : record
    b : byte;
    m128_unaligned : tm128_tm128_unaligned;
  end;
  tm128_d : double;


{$pop}

{ Case tpara2.pas }
{$push}
type
  tpara2_sint16 = smallint;
  tpara2_uint16 = word;

        tpara2_Point = record
                case tpara2_SInt16 of
                0: (
                        v: tpara2_SInt16;
                        h: tpara2_SInt16;
                   );
                1: (
                        vh: array [0..1] of tpara2_SInt16;
                        );
        end;

        tpara2_Rect = record
                case tpara2_SInt16 of
                0: (
                        top: tpara2_SInt16;
                        left: tpara2_SInt16;
                        bottom: tpara2_SInt16;
                        right: tpara2_SInt16;
                   );
                1: (
                        topLeft: tpara2_Point;
                        botRight: tpara2_Point;
                   );
        end;

        tpara2_RGBColor = record
                red:                                    tpara2_UInt16;
                                                { magnitude of red component }
                green:                                  tpara2_UInt16;
                                                { magnitude of green component }
                blue:                                   tpara2_UInt16;
                                                { magnitude of blue component }
        end;

function tpara2_test(tpara2_r: tpara2_Rect; tpara2_c1, tpara2_c2: tpara2_RGBColor): tpara2_Rect;
begin
  tpara2_test:= tpara2_r;
end;

var
  tpara2_r: tpara2_rect;
  tpara2_c1,tpara2_c2: tpara2_rgbcolor;

{$pop}

{ Case tpara3.pas }
{$push}
type
  tpara3_TRec = record
    bbb: array[1..8] of byte;
    w: word;
  end;

  tpara3_TRec2 = packed record
    a: array[1..9] of char;
  end;

procedure tpara3_dotest(tpara3_p: tpara3_TRec);
var
  tpara3_i: longint;
begin
  for tpara3_i:=1 to 8 do
    write(tpara3_p.bbb[tpara3_i], ' ');
  writeln;
  if qword(tpara3_p.bbb)<>$0102030405060708 then begin
    writeln('Test FAILED.');
    Halt(1);
  end;
end;

procedure tpara3_dotest2(tpara3_p: tpara3_TRec);
var
  rr: tpara3_TRec2;
  pp: tpara3_TRec;
begin
  pp:=tpara3_p;
  tpara3_dotest(pp);
end;

var
  tpara3_b: byte;
  tpara3_p: tpara3_TRec;
  tpara3_i: longint;


{$pop}

{ Case tshlshr.pas }
{$push}
{***********************************************************}
{ CODE GENERATOR TEST SUITE                                *}
{***********************************************************}
{ NODE TESTED : secondshlshr()                             *}
{***********************************************************}
{ PRE-REQUISITES: secondload()                              }
{                 secondassign()                            }
{                 secondtypeconv()                          }
{                 secondinline() with strings only!         }
{                 secondadd() comparison                    }
{                 secondifn()                               }
{***********************************************************}
{ DEFINES  :  FPC if target is Free Pascal compiler         }
{***********************************************************}
{ REMARKS: None                                             }
{***********************************************************}


{----------------------------------------------------}
{ Cases to test:                                     }
{   RIGHT NODE (shift count value)                   }
{     - LOC_CREGISTER                                }
{     - LOC_REFERENCE / LOC_MEM                      }
{     - LOC_REGISTER                                 }
{     - numeric constant                             }
{   LEFT NODE (value to shift)                       }
{     - LOC_CREGISTER                                }
{     - LOC_REFERENCE / LOC_MEM                      }
{     - LOC_REGISTER                                 }
{----------------------------------------------------}
procedure tshlshr_test(value, required: {$ifndef fpc}longint{$else fpc}int64{$endif fpc});
begin
  if value <> required then
    begin
      writeln('Got ',value,' instead of ',required);
      halt(1);
    end
  else
    writeln('Passed!');
end;

type
tshlshr_tint64record = packed record
   lowval  : longint;
   highval : longint;
end;


var
 tshlshr_longres :  longint;
 tshlshr_longcnt : longint;
 tshlshr_bytecnt : shortint;
 tshlshr_byteres : shortint;
{$IFDEF FPC}
 tshlshr_int64res : int64;
 tshlshr_int64cnt : int64;
 tshlshr_int64rec : tshlshr_tint64record;
{$ENDIF}

{$pop}

{ Case tsmallrec.pas }
{$push}




type
  tsmallrec_rec1 = record
    c1 : char;
  end;

  tsmallrec_rec2 = record
    c1,c2 : char;
  end;

  tsmallrec_rec3 = record
    c1,c2,c3 : char;
  end;

  tsmallrec_rec4 = record
    c1,c2,c3,c4 : char;
  end;

  tsmallrec_rec5 = record
    c1,c2,c3,c4,c5 : char;
  end;

  tsmallrec_rec6 = record
    c1,c2,c3,c4,c5,c6 : char;
  end;

  tsmallrec_rec7 = record
    c1,c2,c3,c4,c5,c6,c7 : char;
  end;

  tsmallrec_rec8 = record
    c1,c2,c3,c4,c5,c6,c7,c8 : char;
  end;

const
  tsmallrec_r1 : tsmallrec_rec1 = ( c1 : 'a' );
  tsmallrec_r2 : tsmallrec_rec2 = ( c1 : 'a'; c2 : 'b' );
  tsmallrec_r3 : tsmallrec_rec3 = ( c1 : 'a'; c2 : 'b'; c3 : 'c' );
  tsmallrec_r4 : tsmallrec_rec4 = ( c1 : 'a'; c2 : 'b'; c3 : 'c'; c4 : 'd' );
  tsmallrec_r5 : tsmallrec_rec5 = ( c1 : 'a'; c2 : 'b'; c3 : 'c'; c4 : 'd'; c5 : 'e' );
  tsmallrec_r6 : tsmallrec_rec6 = ( c1 : 'a'; c2 : 'b'; c3 : 'c'; c4 : 'd'; c5 : 'e'; c6 : 'f' );
  tsmallrec_r7 : tsmallrec_rec7 = ( c1 : 'a'; c2 : 'b'; c3 : 'c'; c4 : 'd'; c5 : 'e'; c6 : 'f'; c7 : 'g' );
  tsmallrec_r8 : tsmallrec_rec8 = ( c1 : 'a'; c2 : 'b'; c3 : 'c'; c4 : 'd'; c5 : 'e'; c6 : 'f'; c7 : 'g'; c8 : 'h' );
  tsmallrec_haserrors : boolean = false;
procedure tsmallrec_seterror(size:byte);
begin
  writeln('Error for size ',size);
  tsmallrec_haserrors:=true;
end;

procedure tsmallrec_test_r1(r : tsmallrec_rec1);
begin
  if (r.c1<>tsmallrec_r1.c1) then
    tsmallrec_seterror(sizeof(tsmallrec_rec1));
end;

procedure tsmallrec_test_r2(r : tsmallrec_rec2);
begin
  if (r.c1<>tsmallrec_r2.c1) or (r.c2<>tsmallrec_r2.c2) then
    tsmallrec_seterror(sizeof(tsmallrec_rec2));
end;

procedure tsmallrec_test_r3(r : tsmallrec_rec3);
begin
  if (r.c1<>tsmallrec_r3.c1) or (r.c2<>tsmallrec_r3.c2) or (r.c3<>tsmallrec_r3.c3) then
    tsmallrec_seterror(sizeof(tsmallrec_rec3));
end;

procedure tsmallrec_test_r4(r : tsmallrec_rec4);
begin
  if (r.c1<>tsmallrec_r4.c1) or (r.c2<>tsmallrec_r4.c2) or (r.c3<>tsmallrec_r4.c3) or (r.c4<>tsmallrec_r4.c4) then
    tsmallrec_seterror(sizeof(tsmallrec_rec4));
end;

procedure tsmallrec_test_r5(r : tsmallrec_rec5);
begin
  if (r.c1<>tsmallrec_r5.c1) or (r.c2<>tsmallrec_r5.c2) or (r.c3<>tsmallrec_r5.c3) or (r.c4<>tsmallrec_r5.c4) or (r.c5<>tsmallrec_r5.c5) then
    tsmallrec_seterror(sizeof(tsmallrec_rec5));
end;

procedure tsmallrec_test_r6(r : tsmallrec_rec6);
begin
  if (r.c1<>tsmallrec_r6.c1) or (r.c2<>tsmallrec_r6.c2) or (r.c3<>tsmallrec_r6.c3) or (r.c4<>tsmallrec_r6.c4) or (r.c5<>tsmallrec_r6.c5) or (r.c6<>tsmallrec_r6.c6) then
    tsmallrec_seterror(sizeof(tsmallrec_rec6));
end;

procedure tsmallrec_test_r7(r : tsmallrec_rec7);
begin
  if (r.c1<>tsmallrec_r7.c1) or (r.c2<>tsmallrec_r7.c2) or (r.c3<>tsmallrec_r7.c3) or (r.c4<>tsmallrec_r7.c4) or (r.c5<>tsmallrec_r7.c5) or (r.c6<>tsmallrec_r7.c6) or (r.c7<>tsmallrec_r7.c7) then
    tsmallrec_seterror(sizeof(tsmallrec_rec7));
end;

procedure tsmallrec_test_r8(r : tsmallrec_rec8);
begin
  if (r.c1<>tsmallrec_r8.c1) or (r.c2<>tsmallrec_r8.c2) or (r.c3<>tsmallrec_r8.c3) or (r.c4<>tsmallrec_r8.c4) or (r.c5<>tsmallrec_r8.c5) or (r.c6<>tsmallrec_r8.c6) or (r.c7<>tsmallrec_r8.c7) or (r.c8<>tsmallrec_r8.c8) then
    tsmallrec_seterror(sizeof(tsmallrec_rec8));
end;

procedure tsmallrec_test_long_r1(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec1);
begin
  if (r.c1<>tsmallrec_r1.c1) then
    tsmallrec_seterror(sizeof(tsmallrec_rec1));
end;

procedure tsmallrec_test_long_r2(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec2);
begin
  if (r.c1<>tsmallrec_r2.c1) or (r.c2<>tsmallrec_r2.c2) then
    tsmallrec_seterror(sizeof(tsmallrec_rec2));
end;

procedure tsmallrec_test_long_r3(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec3);
begin
  if (r.c1<>tsmallrec_r3.c1) or (r.c2<>tsmallrec_r3.c2) or (r.c3<>tsmallrec_r3.c3) then
    tsmallrec_seterror(sizeof(tsmallrec_rec3));
end;

procedure tsmallrec_test_long_r4(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec4);
begin
  if (r.c1<>tsmallrec_r4.c1) or (r.c2<>tsmallrec_r4.c2) or (r.c3<>tsmallrec_r4.c3) or (r.c4<>tsmallrec_r4.c4) then
    tsmallrec_seterror(sizeof(tsmallrec_rec4));
end;

procedure tsmallrec_test_long_r5(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec5);
begin
  if (r.c1<>tsmallrec_r5.c1) or (r.c2<>tsmallrec_r5.c2) or (r.c3<>tsmallrec_r5.c3) or (r.c4<>tsmallrec_r5.c4) or (r.c5<>tsmallrec_r5.c5) then
    tsmallrec_seterror(sizeof(tsmallrec_rec5));
end;

procedure tsmallrec_test_long_r6(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec6);
begin
  if (r.c1<>tsmallrec_r6.c1) or (r.c2<>tsmallrec_r6.c2) or (r.c3<>tsmallrec_r6.c3) or (r.c4<>tsmallrec_r6.c4) or (r.c5<>tsmallrec_r6.c5) or (r.c6<>tsmallrec_r6.c6) then
    tsmallrec_seterror(sizeof(tsmallrec_rec6));
end;

procedure tsmallrec_test_long_r7(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec7);
begin
  if (r.c1<>tsmallrec_r7.c1) or (r.c2<>tsmallrec_r7.c2) or (r.c3<>tsmallrec_r7.c3) or (r.c4<>tsmallrec_r7.c4) or (r.c5<>tsmallrec_r7.c5) or (r.c6<>tsmallrec_r7.c6) or (r.c7<>tsmallrec_r7.c7) then
    tsmallrec_seterror(sizeof(tsmallrec_rec7));
end;

procedure tsmallrec_test_long_r8(r_1,r_2,r_3,r_4,r_5,r_6,r_7,r_8,r9,r10,r11,r12,r13,r14,r15,r16,r17,r18,r19,r20,r : tsmallrec_rec8);
begin
  if (r.c1<>tsmallrec_r8.c1) or (r.c2<>tsmallrec_r8.c2) or (r.c3<>tsmallrec_r8.c3) or (r.c4<>tsmallrec_r8.c4) or (r.c5<>tsmallrec_r8.c5) or (r.c6<>tsmallrec_r8.c6) or (r.c7<>tsmallrec_r8.c7) or (r.c8<>tsmallrec_r8.c8) then
    tsmallrec_seterror(sizeof(tsmallrec_rec8));
end;


{$pop}

begin

{ Case tbuserror.pas }
{$push}

begin
  tbuserror_tr.b1:=true;
  tbuserror_tr.b2:=tbuserror_const_b2;
  tbuserror_tr.w1:=tbuserror_const_w1;
  tbuserror_check_trec(tbuserror_tr);
  tbuserror_check_trec(tbuserror_tr);
  tbuserror_tr2.b3:=true;
  tbuserror_tr2.rec:=tbuserror_tr;
  tbuserror_check_trec(tbuserror_tr2.rec);
  tbuserror_check_trec(tbuserror_tr2.rec);
end;
{$pop}

{ Case tbytetypecast.pas }
{$push}

begin
  tbytetypecast_HasError:=false;
  tbytetypecast_ErrorCount:=0;
  tbytetypecast_b1:=$57;
  tbytetypecast_w1:=$2D57;
  tbytetypecast_b2:=$E3;
  tbytetypecast_w2:=$ABE3;
  if (byte(tbytetypecast_w1)<>tbytetypecast_b1) then
    tbytetypecast_error(1);
  if (byte(tbytetypecast_w2)<>tbytetypecast_b2) then
    tbytetypecast_error(2);
  tbytetypecast_rec.tbytetypecast_w1:=tbytetypecast_w1;

  if (byte(tbytetypecast_rec.tbytetypecast_w1)<>tbytetypecast_b1) then
    tbytetypecast_error(3);
  if (tbytetypecast_rec.tbytetypecast_w1=tbytetypecast_b1) then
    tbytetypecast_error(4);
  if (byte(tbytetypecast_getrec.tbytetypecast_w1)<>tbytetypecast_b1) then
    tbytetypecast_error(5);
  if (tbytetypecast_getrec.tbytetypecast_w1<>tbytetypecast_w1) then
    tbytetypecast_error(6);
  tbytetypecast_rec.tbytetypecast_w1:=$1234;
  tbytetypecast_rec.tbytetypecast_w2:=tbytetypecast_w2;
  tbytetypecast_rec.w3:=tbytetypecast_w1;
  if (byte(tbytetypecast_rec.tbytetypecast_w2)<>tbytetypecast_b2) then
    tbytetypecast_error(7);
  if (tbytetypecast_rec.tbytetypecast_w2=tbytetypecast_b2) then
    tbytetypecast_error(8);
  if (byte(tbytetypecast_getrec.tbytetypecast_w2)<>tbytetypecast_b2) then
    tbytetypecast_error(9);
  if (tbytetypecast_getrec.tbytetypecast_w2<>tbytetypecast_w2) then
    tbytetypecast_error(10);
  if (byte(tbytetypecast_rec.w3)<>tbytetypecast_b1) then
    tbytetypecast_error(11);
  if (tbytetypecast_rec.w3=tbytetypecast_b1) then
    tbytetypecast_error(12);
  if (byte(tbytetypecast_getrec.w3)<>tbytetypecast_b1) then
    tbytetypecast_error(13);
  if (tbytetypecast_getrec.w3<>tbytetypecast_w1) then
    tbytetypecast_error(14);
  if tbytetypecast_ErrorCount=0 then
    writeln('Test completed without error')
  else
    CheckCaseExitCode(tbytetypecast_ErrorCount);
end;
{$pop}

{ Case tm128.pas }
{$push}
{$ASSERTIONS ON}
begin
  assert((sizeof(tm128_tm128))=16);
  assert((ptruint(@tm128_tr1.m128) mod 16)=0);
  assert((ptruint(@tm128_tr1_unaligned.m128_unaligned)-ptruint(@tm128_tr1_unaligned.b))=4);
end;
{$pop}

{ Case tpara2.pas }
{$push}

begin
  tpara2_test(tpara2_r,tpara2_c1,tpara2_c2);
end;
{$pop}

{ Case tpara3.pas }
{$push}

begin
  qword(tpara3_p.bbb):=$0102030405060708;
  tpara3_dotest2(tpara3_p);
  writeln('Test OK.');
end;
{$pop}

{ Case tshlshr.pas }
{$push}
{$ifndef fpc}
{$else fpc}
{$endif fpc}
{$IFDEF FPC}
{$ENDIF}
Begin
   WriteLn('------------------------------ LONGINT --------------------------------');
   { left : LOC_REFERENCE     }
   { right : numeric constant }
   WriteLn('(left) : LOC_REFERENCE; (right) : ordinal constant');
   tshlshr_longres:=1;
   tshlshr_longres := tshlshr_longres shl 15;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_longres, 32768);

   tshlshr_longres:=-1;
   tshlshr_longres := tshlshr_longres shl 15;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_longres, -32768);

   tshlshr_longres:=1;
   tshlshr_longres := tshlshr_longres shl 33;
   Write('(SHL) Value should be 2...');
   tshlshr_test(tshlshr_longres, 2);

   tshlshr_longres:=$8000;
   tshlshr_longres := tshlshr_longres shr 15;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_longres, 1);

   tshlshr_longres:=-1;
   tshlshr_longres := tshlshr_longres shr 15;
   Write('(SHR) Value should be 131071...');
   tshlshr_test(tshlshr_longres, 131071);

   tshlshr_longres:=$FFFF;
   tshlshr_longres := tshlshr_longres shr 33;
   Write('(SHR) Value should be 32767...');
   tshlshr_test(tshlshr_longres, 32767);

   { left : LOC_REFERENCE }
   { right : LOC_REFERENCE }
   WriteLn('(left) : LOC_REFERENCE; (right) : LOC_REFERENCE');

{
   longres := 1;
   longcnt := -2;
   longres:=longres shl longcnt ;
   Write('(SHL) Value should be 1073741824...');
   test(longres, 1073741824);
}

   tshlshr_longres:=1;
   tshlshr_longcnt:=15;
   tshlshr_longres := tshlshr_longres shl tshlshr_longcnt;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_longres, 32768);

   tshlshr_longres:=-1;
   tshlshr_longcnt := 15;
   tshlshr_longres := tshlshr_longres shl tshlshr_longcnt;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_longres, -32768);

{
   longres := 1;
   longcnt := -2;
   longres:=longres shr longcnt ;
   Write('(SHR) Value should be 0...');
   test(longres, 0);
}

   tshlshr_longres:=32768;
   tshlshr_longcnt:=15;
   tshlshr_longres := tshlshr_longres shr tshlshr_longcnt;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_longres, 1);

   tshlshr_longres:=-1;
   tshlshr_longcnt := 15;
   tshlshr_longres := tshlshr_longres shl tshlshr_longcnt;
   Write('(SHR) Value should be -32768...');
   tshlshr_test(tshlshr_longres, -32768);

   { left : LOC_REFERENCE }
   { right : LOC_REGISRER }
{
   WriteLn('(left) : LOC_REFERENCE; (right) : LOC_REGISTER');
   longres := 1;
   bytecnt := -2;
   longres:=longres shl bytecnt ;
   Write('(SHL) Value should be 1073741824...');
   test(longres, 1073741824);
}

   tshlshr_longres:=1;
   tshlshr_bytecnt:=15;
   tshlshr_longres := tshlshr_longres shl tshlshr_bytecnt;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_longres, 32768);

   tshlshr_longres:=-1;
   tshlshr_bytecnt := 15;
   tshlshr_longres := tshlshr_longres shl tshlshr_bytecnt;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_longres, -32768);

{
   longres := 1;
   bytecnt := -2;
   longres:=longres shr bytecnt ;
   Write('(SHR) Value should be 0...');
   test(longres, 0);
}

   tshlshr_longres:=32768;
   tshlshr_bytecnt:=15;
   tshlshr_longres := tshlshr_longres shr tshlshr_bytecnt;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_longres, 1);

   tshlshr_longres:=-1;
   tshlshr_bytecnt := 15;
   tshlshr_longres := tshlshr_longres shr tshlshr_bytecnt;
   Write('(SHR) Value should be 131071...');
   tshlshr_test(tshlshr_longres, 131071);

   WriteLn('(left) : LOC_REGISTER; (right) : LOC_REGISTER');
   tshlshr_byteres := 1;
   tshlshr_bytecnt := 2;
   tshlshr_byteres := tshlshr_byteres shl tshlshr_bytecnt;
   Write('(SHL) Value should be 4...');
   tshlshr_test(tshlshr_byteres, 4);


   tshlshr_byteres := 4;
   tshlshr_bytecnt := 2;
   tshlshr_byteres := tshlshr_byteres shr tshlshr_bytecnt;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_byteres, 1);

{$IFDEF FPC}
   WriteLn('------------------------------  INT64  --------------------------------');
   { left : LOC_REFERENCE     }
   { right : numeric constant }
   WriteLn('(left) : LOC_REFERENCE; (right) : ordinal constant');
   tshlshr_int64res:=1;
   tshlshr_int64res := tshlshr_int64res shl 15;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_int64res, 32768);

   tshlshr_int64res:=-1;
   tshlshr_int64res := tshlshr_int64res shl 15;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_int64res, -32768);


   tshlshr_int64res:=1;
   tshlshr_int64res := tshlshr_int64res shl 65;
   Write('(SHL) Value should be 2...');
   tshlshr_test(tshlshr_int64res, 2);

   tshlshr_int64res:=$8000;
   tshlshr_int64res := tshlshr_int64res shr 15;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_int64res, 1);

   tshlshr_int64res:=$FFFF;
   tshlshr_int64res := tshlshr_int64res shr 65;
   Write('(SHR) Value should be 32767...');
   tshlshr_test(tshlshr_int64res, 32767);

   { left : LOC_REFERENCE }
   { right : LOC_REFERENCE }
{
   WriteLn('(left) : LOC_REFERENCE; (right) : LOC_REFERENCE');
   int64res := 1;
   int64cnt := -2;
   int64res:=int64res shl int64cnt ;
   Write('(SHL) Value should be 1073741824...');
   test(int64res, 1073741824);
}

   tshlshr_int64res:=1;
   tshlshr_int64cnt:=15;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_int64cnt;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_int64res, 32768);


   tshlshr_int64res:=-1;
   tshlshr_int64cnt := 15;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_int64cnt;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_int64res, -32768);

   tshlshr_int64res := 1;
   tshlshr_int64cnt := 33;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_int64cnt;
   Write('(SHL) Value should be 2 in high longint (85899345)...');
   move(tshlshr_int64res,tshlshr_int64rec, sizeof(int64));
   tshlshr_test(tshlshr_int64rec.highval, 2);
{   test(int64res, 8589934592);}


{
   int64res := 1;
   int64cnt := -2;
   int64res:=int64res shr int64cnt ;
   Write('(SHR) Value should be 0...');
   test(int64res and $FFFFFFFF, 0);
}
   tshlshr_int64res:=32768;
   tshlshr_int64cnt:=15;
   tshlshr_int64res := tshlshr_int64res shr tshlshr_int64cnt;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_int64res, 1);

   tshlshr_int64res:=-1;
   tshlshr_int64cnt := 15;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_int64cnt;
   Write('(SHR) Value should be -32768...');
   tshlshr_test(tshlshr_int64res, -32768);

   { left : LOC_REFERENCE }
   { right : LOC_REGISRER }
{
  WriteLn('(left) : LOC_REFERENCE; (right) : LOC_REGISTER');
   int64res := 1;
   bytecnt := -2;
   int64res:=int64res shl bytecnt ;
   Write('(SHL) Value should be 1073741824...');
   test(int64res, 1073741824);
}

   tshlshr_int64res:=1;
   tshlshr_bytecnt:=15;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_bytecnt;
   Write('(SHL) Value should be 32768...');
   tshlshr_test(tshlshr_int64res, 32768);


   tshlshr_int64res:=-1;
   tshlshr_bytecnt := 15;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_bytecnt;
   Write('(SHL) Value should be -32768...');
   tshlshr_test(tshlshr_int64res, -32768);

{
   int64res := 1;
   bytecnt := -2;
   int64res:=int64res shr bytecnt ;
   Write('(SHR) Value should be 0...');
   test(int64res and $FFFFFFFF, 0);
}

   tshlshr_int64res:=32768;
   tshlshr_bytecnt:=15;
   tshlshr_int64res := tshlshr_int64res shr tshlshr_bytecnt;
   Write('(SHR) Value should be 1...');
   tshlshr_test(tshlshr_int64res, 1);

   tshlshr_int64res := 1;
   tshlshr_bytecnt := 33;
   tshlshr_int64res := tshlshr_int64res shl tshlshr_bytecnt;
   Write('(SHL) Value should be 2 in high longint (85899345)...');
   move(tshlshr_int64res,tshlshr_int64rec, sizeof(int64));
   tshlshr_test(tshlshr_int64rec.highval, 2);

{   int64res:=-1;
   bytecnt := 15;
   int64res := int64res shr bytecnt;
   WriteLn('(SHR) Value should be 131071...',int64res);}

{$ENDIF}
end;
{$pop}

{ Case tsmallrec.pas }
{$push}

begin
  tsmallrec_test_r1(tsmallrec_r1);
  tsmallrec_test_r2(tsmallrec_r2);
  tsmallrec_test_r3(tsmallrec_r3);
  tsmallrec_test_r4(tsmallrec_r4);
  tsmallrec_test_r5(tsmallrec_r5);
  tsmallrec_test_r6(tsmallrec_r6);
  tsmallrec_test_r7(tsmallrec_r7);
  tsmallrec_test_r8(tsmallrec_r8);
  tsmallrec_test_long_r1(tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1,tsmallrec_r1);
  tsmallrec_test_long_r2(tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2,tsmallrec_r2);
  tsmallrec_test_long_r3(tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3,tsmallrec_r3);
  tsmallrec_test_long_r4(tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4,tsmallrec_r4);
  tsmallrec_test_long_r5(tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5,tsmallrec_r5);
  tsmallrec_test_long_r6(tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6,tsmallrec_r6);
  tsmallrec_test_long_r7(tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7,tsmallrec_r7);
  tsmallrec_test_long_r8(tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8,tsmallrec_r8);
  if not tsmallrec_haserrors then
    writeln('Test successful')
  else
    begin
      writeln('There are errors in the generated code');
      halt(1);
    end;
end;
{$pop}

end.
