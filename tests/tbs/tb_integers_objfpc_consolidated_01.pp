{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case tb0627.pp }
{$push}


{ tests for correctness various simplifications, done by the compiler }



procedure tb0627_Check(i64, expected_value: Int64);
begin
  if i64<>expected_value then
  begin
    Writeln('Error!');
    Halt(1);
  end;
end;

procedure tb0627_Check(qw, expected_value: QWord);
begin
  if qw<>expected_value then
  begin
    Writeln('Error!');
    Halt(1);
  end;
end;

procedure tb0627_Check(b, expected_value: Boolean);
begin
  if b<>expected_value then
  begin
    Writeln('Error!');
    Halt(1);
  end;
end;

var
  tb0627_s8, tb0627_s8_2: ShortInt;
  tb0627_s16, tb0627_s16_2: SmallInt;
  tb0627_s32, tb0627_s32_2: LongInt;
  tb0627_s64, tb0627_s64_2: Int64;
  tb0627_u8, tb0627_u8_2: Byte;
  tb0627_u16, tb0627_u16_2: Word;
  tb0627_u32, tb0627_u32_2: LongWord;
  tb0627_u64, tb0627_u64_2: QWord;
  tb0627_I: Integer;

{$pop}

{ Case tb_integer_function_results_objfpc_run_01.pp }
{$push}
{ Integer result-width branches and nested access to Result and parent locals. }
{ Original case IDs and variable scopes are retained below. }



{ Case tb0605.pp }
{$push}
type
  tb0605_aint = longint;

function tb0605_getint64: int64;
begin
  Result := 64;
end;

function tb0605_getlongint: longint;
begin
  Result := 32;
end;

function tb0605_getword: word;
begin
  result := 16;
end;

function tb0605_getbyte: byte;
begin
  result := 8;
end;

function tb0605_getaint: longint;
begin
  result:=4;
  case sizeof(tb0605_aint) of
    8: result:=tb0605_getint64;
    4: result:=tb0605_getlongint;
    2: result:=smallint(tb0605_getword);
    1: result:=shortint(tb0605_getbyte);
  end;
end;
{$pop}

{ Case tb0622.pp }
{$push}
function tb0622_test: longint;

  var
    tb0622_l: longint;

  procedure tb0622_nest;
    begin
      if result<>111 then
        halt(1);
      if tb0622_l<>222 then
        halt(2);
      tb0622_l:=1231;
      result:=555;
    end;

begin
  result:=111;
  tb0622_l:=222;
  tb0622_nest;
  if tb0622_l<>1231 then
    halt(3);
  if result=555 then
    exit;
  result:=666;
end;
{$pop}


{$pop}

{ Case tw17838.pp }
{$push}


var
  tw17838_count: integer;
  tw17838_b : byte;
procedure tw17838_nop;
begin
  end;
function tw17838_f():cardinal;
begin
  inc(tw17838_count);
  result:=tw17838_count;
  end;

{$pop}

{ Case tw21505.pp }
{$push}
{$H+}

operator >< (A, B: Integer): Integer;
begin
  Result := A - B;
end;


{$pop}

{ Case tw22133.pp }
{$push}


{$H+}

type
  tw22133_uint64 = qword;

var
  tw22133_T64:tw22133_UInt64;

//force checking constants in compile-time
{$RANGECHECKS ON}

{$inline on}

function tw22133_testshift(a:tw22133_uint64; b: byte): tw22133_uint64; inline;
begin
  result:=a shl b;
end;


{$pop}

{ Case tw23963.pp }
{$push}


var
  tw23963_Dividend, tw23963_Divisor, tw23963_Quotient : QWord;

{$pop}

{ Case tw24189.pp }
{$push}

{$assertions on}

procedure tw24189_DivMod(a: Int64; b: Int64; out res, rem: Int64); inline;
begin
  res:=a div b; rem:=a-b*res;
end;

procedure tw24189_Test;
var
  res, rem: Int64;
begin
  res:=5; tw24189_DivMod(res {!}, 2, res {!}, rem);
  Assert(res=2); // OK
  Assert(rem=1); // "2-2*2 = -2" if inlined
end;


{$pop}

{ Case tw27665.pp }
{$push}


      function tw27665_UTF8CodePointLength(firstbyte: byte): SizeInt;
      var
        firstzerobit: SizeInt;
      begin
        result:=1;
        { bsr searches for the leftmost 1 bit. We are interested in the
          leftmost 0 bit, so first invert the value
        }
        firstzerobit:=BsrByte(not(firstbyte));
        { if there is no zero bit or the first zero bit is the rightmost bit
          (bit 0), this is an invalid UTF-8 byte ($ff cannot appear in an
          UTF-8-encoded string, and in the worst case bit 1 has to be zero)
        }
        if (firstzerobit=0) or (firstzerobit=255)  then
          exit;
        { the number of bytes belonging to this code point is
          7-(pos first 0-bit).
        }
        result:=7-firstzerobit;
      end;



{$pop}

{ Case tw29906.pp }
{$push}
{ This test explicity generates calculation with
  results outside tsub range, so range checks
  generate errors.
  Thus, we need an explicit $R- }
{$R-}



type
  tw29906_tsub = 1..19;

function tw29906_test(s: tw29906_tsub): longint;
begin
  { use different number of instructions for several cases so wrongly
    calculated jump table offsets are more likely to wreak havoc }
  case s of
    1:
     result:=1;
    2:
      begin
        writeln('two');
        result:=2;
      end;
    3:
      begin
        s:=4;
        result:=3;
      end;
    4:
      begin
        result:=4;
        s:=s*s+result;
      end;
    5:
      result:=5;
    6:
      result:=6;
    7:
      begin
        s:=s+s*s div s;
        result:=7;
      end;
    8:
      result:=8;
    9:
      result:=9;
    10:
      result:=10;
    11:
      result:=11;
    12:
      result:=12;
    13:
      result:=13;
    14:
      result:=14;
    15:
      result:=15;
    16:
      result:=16;
    17:
      result:=17;
    18:
      result:=18;
    19:
      result:=19;
  end;
end;

var
  tw29906_i: tw29906_tsub;

{$pop}

{ Case tw29912.pp }
{$push}


{$H+}
{$R+,Q+,S+,T+}

var
  tw29912_x,tw29912_y,tw29912_z:integer;

{$pop}

{ Case tw30889.pp }
{$push}
{$OVERFLOWCHECKS+}



var
  tw30889_c: Cardinal;
  tw30889_i: Integer;


{$pop}

{ Case tw32115.pp }
{$push}



function tw32115_CalcSmth(const AValue: LongInt): Integer;
begin
  case AValue of
    -9999999..-1000000: Result := 2;
      -999999..-100000: Result := 7;
        -99999..-10000: Result := 5;
          -9999..-1000: Result := 6;
            -999..-100: Result := 3;
              -99..-10: Result := 2;
                -9..-1: Result := 3;
                  0..9: Result := 5;
                10..99: Result := 2;
              100..999: Result := 3;
            1000..9999: Result := 1;
          10000..99999: Result := 5;
        100000..999999: Result := 8;
      1000000..9999999: Result := 6;
  end;
end;


{$pop}

{ Case tw37228.pp }
{$push}
 {$h+}
var
  tw37228_i: longint;

function tw37228_CreateString: pString;
begin
    if tw37228_i<>0 then
      halt(1);
    inc(tw37228_i);
    writeln('Creating a string');
    new(result);
end;


{$pop}

{ Case tw37878.pp }
{$push}

 var tw37878_i64: int64; tw37878_w: word;

{$pop}

{ Case tw41092.pp }
{$push}

{$H+}

var
  tw41092_A: QWord;
  tw41092_B: Pointer;


{$pop}

{ Case tw4150.pp }
{$push}
{$r+}{$q+}
var
tw4150_Prec:Cardinal;
tw4150_Bits:Word;

{$pop}

{ Case tw8525.pp }
{$push}
{$H+}

var
  tw8525_x, tw8525_y: integer;

{$pop}

{ Case tw9299.pp }
{$push}

{$R+}

function tw9299_GetShiftedCard(const c: Cardinal): Cardinal;
begin
  Result := c shl 24;
end;

function tw9299_GetShiftedByte(const c: Byte): Cardinal;
begin
  Result := c shl 24;
end;


{$pop}

begin

{ Case tb0627.pp }
{$push}

begin
  for tb0627_I := 1 to 100 do
  begin
    tb0627_u8 := Random(256);
    tb0627_s32 := LongInt(Random($ffffffff));

    { many of these are now optimized at various -O settings }
    tb0627_Check(tb0627_s32-tb0627_s32,0);
    tb0627_Check(tb0627_s32 xor tb0627_s32,0);
    tb0627_Check(tb0627_s32=tb0627_s32, True);
    tb0627_Check(tb0627_s32<=tb0627_s32, True);
    tb0627_Check(tb0627_s32>=tb0627_s32, True);
    tb0627_Check(tb0627_s32<>tb0627_s32, False);
    tb0627_Check(tb0627_s32<tb0627_s32, False);
    tb0627_Check(tb0627_s32>tb0627_s32, False);
    tb0627_Check(0*tb0627_s32, 0);
    tb0627_Check(tb0627_s32*0, 0);
    tb0627_Check(0 and tb0627_s32, 0);
    tb0627_Check(tb0627_s32 and 0, 0);
    tb0627_Check(0 shr tb0627_s32, 0);
    tb0627_Check(0 shl tb0627_s32, 0);
    tb0627_Check(SarShortInt(0, tb0627_u8), 0);
    tb0627_Check(SarShortInt(ShortInt($ff), tb0627_u8), -1);
    tb0627_Check(SarSmallInt(0, tb0627_u8), 0);
    tb0627_Check(SarSmallInt(SmallInt($ffff), tb0627_u8), -1);
    tb0627_Check(SarLongInt(0, tb0627_u8), 0);
    tb0627_Check(SarLongInt(LongInt($ffffffff), tb0627_u8), -1);
    tb0627_Check(SarInt64(0, tb0627_u8), 0);
    tb0627_Check(SarInt64(Int64($ffffffffffffffff), tb0627_u8), -1);
    tb0627_Check(RorByte(0, tb0627_u8), 0);
    tb0627_Check(RolByte(0, tb0627_u8), 0);
    tb0627_Check(RorWord(0, tb0627_u8), 0);
    tb0627_Check(RolWord(0, tb0627_u8), 0);
    tb0627_Check(RorDWord(0, tb0627_u8), 0);
    tb0627_Check(RolDWord(0, tb0627_u8), 0);
    tb0627_Check(RorQWord(0, tb0627_u8), 0);
    tb0627_Check(RolQWord(0, tb0627_u8), 0);
    tb0627_Check(RorByte($ff, tb0627_u8), $ff);
    tb0627_Check(RolByte($ff, tb0627_u8), $ff);
    tb0627_Check(RorWord($ffff, tb0627_u8), $ffff);
    tb0627_Check(RolWord($ffff, tb0627_u8), $ffff);
    tb0627_Check(RorDWord($ffffffff, tb0627_u8), $ffffffff);
    tb0627_Check(RolDWord($ffffffff, tb0627_u8), $ffffffff);
    tb0627_Check(RorQWord(QWord($ffffffffffffffff), tb0627_u8), QWord($ffffffffffffffff));
    tb0627_Check(RolQWord(QWord($ffffffffffffffff), tb0627_u8), QWord($ffffffffffffffff));
  end;
end;
{$pop}

{ Case tb_integer_function_results_objfpc_run_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0605.pp }
  {$push}
begin
  if tb0605_getaint <> 32 then
    Halt(1);
end;
  {$pop}

  { Case tb0622.pp }
  {$push}
begin
  if tb0622_test<>555 then
    halt(4);
end;
  {$pop}

end;
{$pop}

{ Case tw17838.pp }
{$push}

begin
  tw17838_count:=0;
  tw17838_b:=1;
  if tw17838_f()=1 then
    tw17838_nop;
  if tw17838_f()=-1 then
    tw17838_nop;
  if tw17838_f()=2 then
    tw17838_nop;
  if tw17838_f()<>-1 then
    tw17838_nop;
  if tw17838_b<-1 then
    tw17838_nop;
  if tw17838_count<>4 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw21505.pp }
{$push}

{$H+}
begin
  Writeln(2 >< 3);
  if (2 >< 3) <> -1 then
    halt(1);
end;
{$pop}

{ Case tw22133.pp }
{$push}

{$H+}
{$RANGECHECKS ON}
{$inline on}
begin
  tw22133_T64:=tw22133_UInt64(qword(1) shl 63);
  if tw22133_T64<>tw22133_uint64(high(int64)+1) then
    halt(1);
  tw22133_T64:=tw22133_UInt64(1) shl 63;
  if tw22133_T64<>tw22133_uint64(high(int64)+1) then
    halt(2);
  tw22133_T64:=tw22133_testshift(1,63);
  if tw22133_T64<>tw22133_uint64(high(int64)+1) then
    halt(3);
end;
{$pop}

{ Case tw23963.pp }
{$push}

begin
  tw23963_Dividend := QWord( $ffffffffffffffff );
  tw23963_Divisor := QWord( $100000003 );
  tw23963_Quotient := tw23963_dividend div tw23963_divisor;
  if tw23963_quotient <> $FFFFFFFD then
    Halt(1);
  tw23963_Quotient := tw23963_dividend mod tw23963_divisor;
  if tw23963_quotient <> 8 then
    Halt(2);
end;
{$pop}

{ Case tw24189.pp }
{$push}

{$assertions on}
begin
  tw24189_test;
end;
{$pop}

{ Case tw27665.pp }
{$push}

begin
  writeln(tw27665_UTF8CodePointLength(ord(' ')));
end;
{$pop}

{ Case tw29906.pp }
{$push}
{$R-}

begin
  for tw29906_i:=low(tw29906_tsub) to high(tw29906_tsub) do
    if tw29906_test(tw29906_i)<>tw29906_i then
      CheckCaseExitCode(tw29906_i);
end;
{$pop}

{ Case tw29912.pp }
{$push}

{$H+}
{$R+,Q+,S+,T+}
begin
  tw29912_x:=0;
  tw29912_z:=0;
  // all ok
  tw29912_y:=Int64(tw29912_x-1);
  writeln(tw29912_y);
  // all ok
  tw29912_y:=Int64(tw29912_z);
  writeln(tw29912_y);
  // arithmetic overflow
  tw29912_y:=Int64(tw29912_x-1)*Int64(tw29912_z);
  writeln(tw29912_y);
end;
{$pop}

{ Case tw30889.pp }
{$push}
{$OVERFLOWCHECKS+}

begin
  tw30889_i := 1;
  for tw30889_c := 0 to tw30889_i do
    WriteLn(tw30889_i);
end;
{$pop}

{ Case tw32115.pp }
{$push}

begin
  tw32115_CalcSmth(0);
end;
{$pop}

{ Case tw37228.pp }
{$push}

{$h+}
begin
    dispose(tw37228_CreateString); // prints “Creating a string” twice
    if tw37228_i<>1 then
      halt(2);
end;
{$pop}

{ Case tw37878.pp }
{$push}

begin
{$Q+}
tw37878_w := 4096;
tw37878_i64 := 8191;
tw37878_i64 := tw37878_i64 - 2*int64(tw37878_w);
end;
{$pop}

{ Case tw41092.pp }
{$push}

{$H+}
begin
  tw41092_A := QWord(tw41092_B);
end;
{$pop}

{ Case tw4150.pp }
{$push}

{$r+}
{$q+}
begin
  tw4150_Bits := 512;
  tw4150_Prec := 8;
  tw4150_Bits := tw4150_Bits shr (16-tw4150_Prec);
  WriteLn(tw4150_bits);
end;
{$pop}

{ Case tw8525.pp }
{$push}

{$H+}
begin
  tw8525_x:=1;
  tw8525_y := Round(tw8525_x);
  if tw8525_y<>1 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw9299.pp }
{$push}

{$R+}
begin
  WriteLn(tw9299_GetShiftedCard(200));

  WriteLn(tw9299_GetShiftedByte(200));

end;
{$pop}

end.
