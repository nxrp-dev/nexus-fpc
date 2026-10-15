{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw9039c.pas }
{$push}
{ the reason this compiles is that tdef.size and tabstractvarsym.getsize }
{ both return an aint, and then the size of ta is reported as low(aint)  }

type
  tw9039c_ta = array[1..high(ptrint)-4] of byte;
  tw9039c_tr = packed record
    l: longint;
    case byte of
      0: (x: longint);
      1: (e: tw9039c_ta);
  end;


{$pop}

{ Case tw9039d.pas }
{$push}
type
  tw9039d_ta = array[1..high(ptrint) div 8-1] of byte;
  tw9039d_tr = bitpacked record
    a: byte;
    case byte of
      0: (l: longint);
      1: (e: tw9039d_ta);
  end;


{$pop}

{ Case tincdec.pas }
{$push}
{ Program to test the system unit inc/dec routines }
{ By Carl Eric Codere Copyright (c) 2002           }


const
   tincdec_INCDEC_COUNT_SIMPLE = 8;
   tincdec_INCDEC_COUNT_COMPLEX = -12;

   tincdec_INIT_U8BIT = $0F;
   tincdec_INIT_U16BIT = $FF00;
   tincdec_INIT_U32BIT = $FF00FF00;

   tincdec_INIT_S8BIT = $0F;
   tincdec_INIT_S16BIT = -13333;
   tincdec_INIT_S32BIT = -2335754;
   tincdec_INIT_S64BIT = Low(longint);
var
 tincdec_global_s8bit : shortint;
 tincdec_global_s16bit : smallint;
 tincdec_global_s32bit :longint;
 tincdec_global_s64bit : int64;
 tincdec_global_u8bit : byte;
 tincdec_global_u16bit : word;
 tincdec_global_u32bit : longword;
 { the result must be calculated manually since
   FPC 1.0.x does not support adding directly 64-bit
   constants
 }
 tincdec_result_s64bit_complex : int64;

 procedure tincdec_init_globals;
   begin
    tincdec_global_s8bit := tincdec_INIT_S8BIT;
    tincdec_global_s16bit := tincdec_INIT_S16BIT;
    tincdec_global_s32bit := longint(tincdec_INIT_S32BIT);
    tincdec_global_s64bit := tincdec_INIT_S64BIT;
    tincdec_global_u8bit := tincdec_INIT_U8BIT;
    tincdec_global_u16bit := tincdec_INIT_U16BIT;
    tincdec_global_u32bit := tincdec_INIT_U32BIT;
    tincdec_result_s64bit_complex := tincdec_INIT_S64BIT;
    tincdec_result_s64bit_complex := tincdec_result_s64bit_complex + tincdec_INCDEC_COUNT_COMPLEX;
   end;



  procedure tincdec_fail;
    begin
      WriteLn('Failed!');
      Halt(1);
    end;

  function tincdec_getcomplex_count_s32 : longint;
   begin
     tincdec_getcomplex_count_s32 := tincdec_INCDEC_COUNT_COMPLEX;
   end;

  function tincdec_getcomplex_count_s8 :shortint;
   begin
     tincdec_getcomplex_count_s8 := tincdec_INCDEC_COUNT_COMPLEX;
   end;

  function tincdec_getcomplex_count_s64 : int64;
   begin
     tincdec_getcomplex_count_s64 := tincdec_INCDEC_COUNT_COMPLEX;
   end;

{***********************************************************************}
{                              INC                                      }
{***********************************************************************}

procedure tincdec_test_inc_s8;
   var
    b: smallint;
    _result : boolean;
 begin
   _result := true;
   Write('Inc() signed 8-bit tests...');

   tincdec_init_globals;
   Inc(tincdec_global_s8bit);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT+1) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_S8bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_S8BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_S8bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_S8BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   Inc(tincdec_global_S8bit, b);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_S8BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   Inc(tincdec_global_S8bit, b);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_S8BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_S8bit, tincdec_getcomplex_count_s32);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_S8BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_S8bit, tincdec_getcomplex_count_s8);
   if tincdec_global_S8bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_S8BIT) then
     _result := false;

   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;

procedure tincdec_test_inc_s16;
   var
    b: smallint;
    _result : boolean;
 begin
   _result := true;
   Write('Inc() signed 16-bit tests...');

   tincdec_init_globals;
   Inc(tincdec_global_s16bit);
   if tincdec_global_S16bit <> (tincdec_INIT_S16BIT+1) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s16bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_s16BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s16bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s16BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   Inc(tincdec_global_s16bit, b);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_s16BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   Inc(tincdec_global_s16bit, b);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s16BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s16bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s16BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s16bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s16bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s16BIT) then
     _result := false;

   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;

procedure tincdec_test_inc_s32;
   var
    b: smallint;
    _result : boolean;
 begin
    _result := true;
   Write('Inc() signed 32-bit tests...');

   tincdec_init_globals;
   Inc(tincdec_global_s32bit);
   if tincdec_global_S32bit <> (tincdec_INIT_S32BIT+1) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s32bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s32bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   Inc(tincdec_global_s32bit, b);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   Inc(tincdec_global_s32bit, b);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s32bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s32bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s32bit, tincdec_getcomplex_count_s64);
   if tincdec_global_s32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s32BIT) then
     _result := false;


   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
end;

procedure tincdec_test_inc_s64;
   var
    b: int64;
    _result : boolean;
 begin
   _result := true;
   Write('Inc() signed 64-bit tests...');

   tincdec_init_globals;
   Inc(tincdec_global_s64bit);
   if tincdec_global_S64bit <> (tincdec_result_s64bit_complex-tincdec_INCDEC_COUNT_COMPLEX+1) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s64bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s64bit <> (tincdec_result_s64bit_complex) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s64bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s64bit <> (tincdec_result_s64bit_complex) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   Inc(tincdec_global_s64bit, b);
   if tincdec_global_s64bit <> (tincdec_result_s64bit_complex) then
     _result := false;

{$ifndef ver1_0}
   tincdec_init_globals;
   Inc(tincdec_global_s64bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s64bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_S64BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_s64bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s64bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_s64BIT) then
     _result := false;


{$endif}
   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;


procedure tincdec_test_inc_u32;
   var
    b: smallint;
    _result : boolean;
 begin
    _result := true;
   Write('Inc() unsigned 32-bit tests...');

   tincdec_init_globals;
   Inc(tincdec_global_u32bit);
   if tincdec_global_u32bit <> (tincdec_INIT_U32BIT+1) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_u32bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_u32bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   Inc(tincdec_global_u32bit, b);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_SIMPLE+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   Inc(tincdec_global_u32bit, b);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_u32bit, tincdec_getcomplex_count_s32);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_u32bit, tincdec_getcomplex_count_s8);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_u32BIT) then
     _result := false;

   tincdec_init_globals;
   Inc(tincdec_global_u32bit, tincdec_getcomplex_count_s64);
   if tincdec_global_u32bit <> (tincdec_INCDEC_COUNT_COMPLEX+tincdec_INIT_u32BIT) then
     _result := false;


   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
end;

{***********************************************************************}
{                              DEC                                      }
{***********************************************************************}
procedure tincdec_test_dec_s8;
   var
    b: smallint;
    _result : boolean;
    l: byte;
 begin
   _result := true;
   Write('dec() signed 8-bit tests...');

   tincdec_init_globals;
   dec(tincdec_global_S8bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_S8bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_S8bit <>  (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   dec(tincdec_global_S8bit, b);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   dec(tincdec_global_S8bit, b);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_S8bit, tincdec_getcomplex_count_s32);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_S8bit, tincdec_getcomplex_count_s8);
   if tincdec_global_S8bit <> (tincdec_INIT_S8BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   { extra test for overflow checking }
   l:=byte(high(shortint));
   tincdec_global_s8bit := high(shortint);
   dec(tincdec_global_s8bit,l);
   if tincdec_global_s8bit <> 0 then
     _result := false;


   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;

procedure tincdec_test_dec_s16;
   var
    b: smallint;
    _result : boolean;
 begin
   _result := true;
   Write('dec() signed 16-bit tests...');

   tincdec_init_globals;
   dec(tincdec_global_s16bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s16bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   dec(tincdec_global_s16bit, b);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   dec(tincdec_global_s16bit, b);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s16bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s16bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s16bit <> (tincdec_INIT_S16BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;

procedure tincdec_test_dec_s32;
   var
    b: smallint;
    _result : boolean;
 begin
    _result := true;
   Write('dec() signed 32-bit tests...');

   tincdec_init_globals;
   dec(tincdec_global_s32bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s32bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   dec(tincdec_global_s32bit, b);
   if tincdec_global_s32bit <>  (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   dec(tincdec_global_s32bit, b);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s32bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s32bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s32bit, tincdec_getcomplex_count_s64);
   if tincdec_global_s32bit <> (tincdec_INIT_S32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;


   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
end;

procedure tincdec_test_dec_s64;
   var
    b: smallint;
    _result : boolean;
 begin
   _result := true;
   Write('dec() signed 64-bit tests...');


{$ifndef ver1_0}
   tincdec_init_globals;
   dec(tincdec_global_s64bit, tincdec_getcomplex_count_s8);
   if tincdec_global_s64bit <> (tincdec_INIT_S64BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_s64bit, tincdec_getcomplex_count_s32);
   if tincdec_global_s64bit <> (tincdec_INIT_S64BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;
{$endif}
   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;

procedure tincdec_test_dec_u32;
   var
    b: smallint;
    _result : boolean;
 begin
    _result := true;
   Write('dec() unsigned 32-bit tests...');

   tincdec_init_globals;
   dec(tincdec_global_u32bit, tincdec_INCDEC_COUNT_SIMPLE);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_u32bit, tincdec_INCDEC_COUNT_COMPLEX);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_SIMPLE;
   dec(tincdec_global_u32bit, b);
   if tincdec_global_u32bit <>  (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_SIMPLE) then
     _result := false;

   tincdec_init_globals;
   b:= tincdec_INCDEC_COUNT_COMPLEX;
   dec(tincdec_global_u32bit, b);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_u32bit, tincdec_getcomplex_count_s32);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_u32bit, tincdec_getcomplex_count_s8);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;

   tincdec_init_globals;
   dec(tincdec_global_u32bit, tincdec_getcomplex_count_s64);
   if tincdec_global_u32bit <> (tincdec_INIT_u32BIT-tincdec_INCDEC_COUNT_COMPLEX) then
     _result := false;



   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
end;


procedure tincdec_test_inc_ptr;
   type
     tstruct = packed record
      b: byte;
      w: word;
     end;
   const
      word_array : array[1..4] of word =
      ($0000,$FFFF,$F0F0,$F00F);
      struct_array : array[1..4] of tstruct = (
       (b:00;w:0001),
       (b:01;w:0102),
       (b:02;w:0203),
       (b:03;w:0304)
      );
   var
    _result : boolean;
    pw : ^word;
    podd : ^tstruct;
    i: integer;
    B : byte;
 begin
    _result := true;
   Write('Inc() pointer to word...');
   pw:=@word_array;
   for i:=1 to 4 do
     begin
        if (word_array[i] <> pw^) then
          _result := false;
        Inc(pw)
     end;

   pw:=@word_array;
   inc(pw,2);
   if pw^<>word_array[3] then
     _result := false;

   pw:=@word_array;
   b:=2;
   inc(pw,b);
   if pw^<>word_array[3] then
     _result := false;

   podd:=@struct_array;
   b:=3;
   inc(podd,b);
   if (podd^.b<>struct_array[4].b) and (podd^.w<>struct_array[4].w) then
     _result := false;

   podd:=@struct_array;
   inc(podd,3);
   if (podd^.b<>struct_array[4].b) and (podd^.w<>struct_array[4].w) then
     _result := false;

   if not _result then
      tincdec_fail
   else
     WriteLn('Success!');
 end;



{$pop}

begin

{ Case tw9039c.pas }
{$push}

begin
  writeln(sizeof(tw9039c_ta));
end;
{$pop}

{ Case tw9039d.pas }
{$push}

begin
  writeln(sizeof(tw9039d_ta));
end;
{$pop}

{ Case tincdec.pas }
{$push}
{$ifndef ver1_0}
{$endif}
{$ifndef ver1_0}
{$endif}
Begin
  tincdec_test_inc_s8;
  tincdec_test_inc_s16;
  tincdec_test_inc_s32;
  tincdec_test_inc_s64;
  tincdec_test_inc_u32;
  tincdec_test_inc_ptr;

  tincdec_test_dec_s8;
  tincdec_test_dec_s16;
  tincdec_test_dec_s32;
  tincdec_test_dec_s64;
  tincdec_test_dec_u32;
end;
{$pop}

end.
