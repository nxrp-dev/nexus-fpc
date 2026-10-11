{ Consolidated records regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case taligned1.pp }
{$push}
var
  taligned1_r1 : record
    dummy : byte;
    a,b : longint;
  end;


{$pop}

{ Case tpackrec.pp }
{$push}
{$packrecords 4}
type
  tpackrec_tr = record
    a,b : byte;
    l :longint
  end;

  tpackrec_SCSI_ADAPTER_BUS_INFO = record
    NumberOfBuses: char;
    BusData : array[0..0] of tpackrec_tr;
  end;

var
  tpackrec_p1,tpackrec_p2 : pchar;
  tpackrec_r : tpackrec_SCSI_ADAPTER_BUS_INFO;

{$pop}

{ Case tprec1.pp }
{$push}
{$bitpacking on}

type
  tprec1_tenum = (tprec1_ea,tprec1_eb,tprec1_ec,tprec1_ed,tprec1_ee,tprec1_ef,tprec1_eg,tprec1_eh);
  tprec1_tr = packed record
         a: 0..3;    // 2 bits
         w: word;    // 16 bits;
         b: 0..31;   // 5 bits;
         c: boolean; // 1 bit
         d: 0..31;   // 5 bits
         e: tprec1_tenum;   // 3 bits
       end;

procedure tprec1_t(var r2: tprec1_tr);
var
  tprec1_r: tprec1_tr;
begin
  tprec1_r.a := 2;
  tprec1_r.w := 32768;
  tprec1_r.b := 23;
  tprec1_r.c := true;
  tprec1_r.d := 5;
  tprec1_r.e := tprec1_ed;
  r2 := tprec1_r;
end;

var
  tprec1_r: tprec1_tr;


{$pop}

{ Case tprec14.pp }
{$push}
type
  tprec14_tr = bitpacked record
    l: longint;
  end;


{$pop}

{ Case tprec15.pp }
{$push}
type
  tprec15_tr = bitpacked record
    a,b,c: byte;
    d,e:0..15;
    f: byte;
    g: 0..$ffffff; { 3 bytes }
    h: byte;
  end;

procedure tprec15_p(var b: byte);
begin
  b := $12
end;

var
  tprec15_r: tprec15_tr;

{$pop}

{ Case tprec19.pp }
{$push}
type
  tprec19_pbyte = ^byte;

  tprec19_tr = bitpacked record
    a,b,c: byte;
    d,e:0..15;
    f: byte;
    g: 0..$ffffff; { 3 bytes }
    h: byte;
  end;

procedure tprec19_p(b: tprec19_pbyte);
begin
  b^ := $12
end;

var
  tprec19_r: tprec19_tr;

{$pop}

{ Case tprec2.pp }
{$push}
{$bitpacking on}

type
  tprec2_tenum = (tprec2_ea,tprec2_eb,tprec2_ec,tprec2_ed,tprec2_ee,tprec2_ef,tprec2_eg,tprec2_eh);
  tprec2_tr = packed record
         a: byte;    // 2 bits
         w: word;    // 16 bits;
         b: 0..31;   // 5 bits;
         e: tprec2_tenum;   // 3 bits
       end;

procedure tprec2_t(var r2: tprec2_tr);
var
  tprec2_r: tprec2_tr;
begin
  tprec2_r.a := 2;
  tprec2_r.w := 32768;
  tprec2_r.b := 23;
  tprec2_r.e := tprec2_ed;
  r2 := tprec2_r;
end;

var
  tprec2_r: tprec2_tr;


{$pop}

{ Case tprec25.pp }
{$push}
    type
      { bit types for bitfields                                                  }
      tprec25__62bits    = 0 .. $3FFFFFFFFFFFFFFF;
      tprec25__63bits    = 0 .. $7FFFFFFFFFFFFFFF;
      tprec25__64bits1    = 0 .. qword($8000000000000000);
      tprec25__64bits2    = -1 .. $7FFFFFFFFFFFFFFF;
      tprec25__64bits3    = -1 .. $7F00000000000000;

    var
      tprec25_v2: bitpacked record
        f1: tprec25__62bits;
        f2: tprec25__63bits;
        f3: tprec25__64bits1;
        f4: tprec25__64bits2;
        f5: tprec25__64bits3;
      end;

    
{$pop}

{ Case tprec3.pp }
{$push}
{$bitpacking on}

type
  tprec3_tenum = (tprec3_ea,tprec3_eb,tprec3_ec,tprec3_ed,tprec3_ee,tprec3_ef,tprec3_eg,tprec3_eh);
  tprec3_tr = packed record
         a: 0..3;    // 2 bits
         i: int64;
         c: boolean; // 1 bit
         d: 0..31;   // 5 bits
         e: tprec3_tenum;   // 3 bits
       end;

procedure tprec3_t(var r2: tprec3_tr);
var
  tprec3_r: tprec3_tr;
begin
  tprec3_r.a := 2;
  tprec3_r.i := 1234567890123456789;
  tprec3_r.c := true;
  tprec3_r.d := 5;
  tprec3_r.e := tprec3_ed;
  r2 := tprec3_r;
end;

var
  tprec3_r: tprec3_tr;


{$pop}

{ Case tprec4.pp }
{$push}
{$bitpacking on}

{ from the GPC test suite (sam9.pas) }



type
  tprec4_e1 = (
    tprec4_enum000,
    tprec4_enum001,
    tprec4_enum002,
    tprec4_enum003,
    tprec4_enum004,
    tprec4_enum005,
    tprec4_enum006,
    tprec4_enum007,
    tprec4_enum008,
    tprec4_enum009,
    tprec4_enum010,
    tprec4_enum011,
    tprec4_enum012,
    tprec4_enum013,
    tprec4_enum014,
    tprec4_enum015,
    tprec4_enum016,
    tprec4_enum017,
    tprec4_enum018,
    tprec4_enum019,
    tprec4_enum020,
    tprec4_enum021,
    tprec4_enum022,
    tprec4_enum023,
    tprec4_enum024,
    tprec4_enum025,
    tprec4_enum026,
    tprec4_enum027,
    tprec4_enum028,
    tprec4_enum029,
    tprec4_enum030,
    tprec4_enum031,
    tprec4_enum032,
    tprec4_enum033,
    tprec4_enum034,
    tprec4_enum035,
    tprec4_enum036,
    tprec4_enum037,
    tprec4_enum038,
    tprec4_enum039,
    tprec4_enum040,
    tprec4_enum041,
    tprec4_enum042,
    tprec4_enum043,
    tprec4_enum044,
    tprec4_enum045,
    tprec4_enum046,
    tprec4_enum047,
    tprec4_enum048,
    tprec4_enum049,
    tprec4_enum050,
    tprec4_enum051,
    tprec4_enum052,
    tprec4_enum053,
    tprec4_enum054,
    tprec4_enum055,
    tprec4_enum056,
    tprec4_enum057,
    tprec4_enum058,
    tprec4_enum059,
    tprec4_enum060,
    tprec4_enum061,
    tprec4_enum062,
    tprec4_enum063,
    tprec4_enum064,
    tprec4_enum065,
    tprec4_enum066,
    tprec4_enum067,
    tprec4_enum068,
    tprec4_enum069,
    tprec4_enum070,
    tprec4_enum071,
    tprec4_enum072,
    tprec4_enum073,
    tprec4_enum074,
    tprec4_enum075,
    tprec4_enum076,
    tprec4_enum077,
    tprec4_enum078,
    tprec4_enum079,
    tprec4_enum080,
    tprec4_enum081,
    tprec4_enum082,
    tprec4_enum083,
    tprec4_enum084,
    tprec4_enum085,
    tprec4_enum086,
    tprec4_enum087,
    tprec4_enum088,
    tprec4_enum089,
    tprec4_enum090,
    tprec4_enum091,
    tprec4_enum092,
    tprec4_enum093,
    tprec4_enum094,
    tprec4_enum095,
    tprec4_enum096,
    tprec4_enum097,
    tprec4_enum098,
    tprec4_enum099,
    tprec4_enum100,
    tprec4_enum101,
    tprec4_enum102,
    tprec4_enum103,
    tprec4_enum104,
    tprec4_enum105,
    tprec4_enum106,
    tprec4_enum107,
    tprec4_enum108,
    tprec4_enum109,
    tprec4_enum110,
    tprec4_enum111,
    tprec4_enum112,
    tprec4_enum113,
    tprec4_enum114,
    tprec4_enum115,
    tprec4_enum116,
    tprec4_enum117,
    tprec4_enum118,
    tprec4_enum119,
    tprec4_enum120,
    tprec4_enum121,
    tprec4_enum122,
    tprec4_enum123,
    tprec4_enum124,
    tprec4_enum125,
    tprec4_enum126,
    tprec4_enum127,
    tprec4_enum128 { Remove this and it works !}
  );

  tprec4_r1 = 0 .. 128;

  tprec4_t1 = packed record { has to be packed }
    case integer of
        1: (f1: tprec4_e1);
        2: (f2: tprec4_r1);
      end;

var
  tprec4_v1: tprec4_t1;

procedure tprec4_foo;
begin
  tprec4_v1.f1 := tprec4_enum000;
  tprec4_v1.f2 := 127;
  tprec4_v1.f2 := 128;
end;


{$pop}

{ Case tprec5.pp }
{$push}
{$bitpacking on}


{ from the gpc testsuite (sam8.pas) }

{
 Using a subrange type in a packed record seems to break passing the type
 by reference
}
type
  tprec5_t1 = 0..100; {Has to be subrange}

tprec5_r1 = packed record { Has to be packed }
  f1 : tprec5_t1;
end;

procedure tprec5_proc1(var tprec5_a1: tprec5_t1); { Has to be var }
begin
  if tprec5_a1 = 42 then writeln ('OK') else writeln ('failed')
end;

procedure tprec5_proc2(var tprec5_a1: tprec5_t1); { Also has to be var }
begin
tprec5_proc1(tprec5_a1);
end;

var tprec5_a1 : tprec5_t1;


{$pop}

{ Case tprec8.pp }
{$push}
{$bitpacking on}

type
  tprec8_tenum = (tprec8_ea,tprec8_eb,tprec8_ec,tprec8_ed,tprec8_ee,tprec8_ef,tprec8_eg,tprec8_eh);
  tprec8_tr = packed record
         a: 0..3;    // 2 bits
         i: int64;
         c: boolean; // 1 bit
         d: 0..31;   // 5 bits
         e: tprec8_tenum;   // 3 bits
         case byte of
           0: (g: 0..7);
           1: (h: 0..65536; k: boolean);
           2: (j: boolean);
       end;

procedure tprec8_t(var r2: tprec8_tr);
var
  tprec8_r: tprec8_tr;
begin
  tprec8_r.a := 2;
  tprec8_r.i := 1234567890123456789;
  tprec8_r.c := true;
  tprec8_r.d := 5;
  tprec8_r.e := tprec8_ed;
  r2 := tprec8_r;
end;

var
  tprec8_r: tprec8_tr;
  tprec8_b: byte;

{$pop}

{ Case tpushpop2.pp }
{$push}


type
{$PackRecords 1}
  tpushpop2_TTest1 = record
    b: Byte;
    l: LongInt;
  end;
{$Push}
{$PackRecords 4}
  tpushpop2_TTest2 = record
    b: Byte;
    l: LongInt;
  end;
{$Pop}
  tpushpop2_TTest3 = record
    b: Byte;
    l: LongInt;
  end;


{$pop}

{ Case trecreg.pp }
{$push}
type
  trecreg_u_char = byte;
  trecreg_u_short = word;
  trecreg_u_long = cardinal;

  trecreg_wrec = record
    w: word;
  end;

  trecreg_wrec2 = record
    b1,b2: byte;
  end;

  trecreg_SunB = record
    s_b1,
    s_b2,
    s_b3,
    s_b4: trecreg_u_char;
  end;

  trecreg_SunW = record
    s_w1: trecreg_wrec;
    s_w2: trecreg_wrec2;
  end;

  trecreg_in_addr =  record
    case Integer of
      0: (S_un_b: trecreg_SunB);
      1: (S_un_w: trecreg_SunW);
      2: (S_addr: trecreg_u_long);
  end;

procedure trecreg_t(trecreg_i: trecreg_in_addr);
begin
  if (trecreg_i.s_un_b.s_b1 <> $de) or
     (trecreg_i.s_un_b.s_b2 <> $ad) or
     (trecreg_i.s_un_b.s_b3 <> $be) or
     (trecreg_i.s_un_b.s_b4 <> $ef) then
    begin
      writeln('error1');
      halt(1);
    end;
end;

procedure trecreg_t2(trecreg_i: trecreg_in_addr);
begin
  if (trecreg_i.s_un_w.s_w1.w <> $cafe) or
     (trecreg_i.s_un_w.s_w2.b1 <> $ba) or
     (trecreg_i.s_un_w.s_w2.b2 <> $be) then
    begin
      writeln('error2');
      halt(2);
    end;
end;


var
  trecreg_i: trecreg_in_addr;

{$pop}

{ Case trecreg2.pp }
{$push}
type
  trecreg2_tr = record
    b1, b2, b3, b4: shortint;
  end;

procedure trecreg2_t;
var
  r: trecreg2_tr;
  l: longint;
begin
  r.b1 := 1;
  r.b2 := 2;
  r.b3 := 3;
  r.b4 := 4;
  l := -1;
  r.b2 := l;
  if (r.b1 <> 1) or
     (r.b2 <> -1) or
     (r.b3 <> 3) or
     (r.b4 <> 4) then
    begin
      writeln('error');
      halt(1);
    end;
end;


{$pop}

{ Case trecreg4.pp }
{$push}
{$bitpacking on}

type
  trecreg4_tr = packed record
    b1, b2, b3, b4: -129..127;
  end;

procedure trecreg4_t;
var
  r: trecreg4_tr;
  l: longint;
begin
  r.b4 := -5;
  r.b3 := -128;
  r.b2 := 127;
  r.b1 := -1;
  if (r.b1 <> -1) or
     (r.b2 <> 127) or
     (r.b3 <> -128) or
     (r.b4 <> -5) then
    begin
      writeln('error');
      halt(1);
    end;
end;


{$pop}

{ Case tset5a.pp }
{$push}
{$ifdef fpc}
{$packset 1}
{$endif fpc}
{$z1}

type
  tset5a_ta = set of 0..7;
  tset5a_tb = set of 0..15;
  tset5a_tc = set of 0..23;
  tset5a_td = set of 0..31;
  tset5a_te = set of 0..127;

var
  tset5a_r: packed record
    ve: tset5a_te;
    vd: tset5a_td;
    vc: tset5a_tc;
    vb: tset5a_tb;
    va: tset5a_ta;
    b1,b2,b3: byte;
  end;

{$pop}

{ Case tset7.pp }
{$push}
{ test for subsetreg sets }

{$packset 1}

type
  tset7_ta = 0..7;
  tset7_tr = record
    b: byte;
    a: set of tset7_ta;
    w: word;
  end;


procedure tset7_test(tset7_r: tset7_tr);
var
  b: tset7_ta;
begin
  b := 6;
  if (tset7_r.b<>101) or
     (tset7_r.w<>$abcd) or
     (5 in tset7_r.a) or
     (b in tset7_r.a) or
     not(7 in tset7_r.a) or
     ([1..3] * tset7_r.a <> [2..3]) then
    halt(1);
end;

var
  tset7_r: tset7_tr;

{$pop}

{ Case tunaligned1.pp }
{$push}
var
  tunaligned1_r1 : packed record
    dummy : byte;
    a,b : longint;
  end;


{$pop}

begin

{ Case taligned1.pp }
{$push}

begin
  taligned1_r1.a:=aligned(taligned1_r1.b)*2;
  aligned(taligned1_r1.a):=taligned1_r1.b*2;
  taligned1_r1.a:=taligned1_r1.b;
  taligned1_r1.a:=taligned1_r1.b div 10;
end;
{$pop}

{ Case tpackrec.pp }
{$push}
{$packrecords 4}
begin
  tpackrec_p1:=@tpackrec_r.NumberOfBuses;
  tpackrec_p2:=@tpackrec_r.BusData;
  writeln(tpackrec_p2-tpackrec_p1);
  if tpackrec_p2-tpackrec_p1<>4 then
    halt(1);
end;
{$pop}

{ Case tprec1.pp }
{$push}
{$bitpacking on}
begin
  tprec1_t(tprec1_r);
  if (tprec1_r.a <> 2) or
     (tprec1_r.w <> 32768) or
     (tprec1_r.b <> 23) or
     (not tprec1_r.c) or
     (tprec1_r.d <> 5) or
     (tprec1_r.e <> tprec1_ed) then
    halt(1);
end;
{$pop}

{ Case tprec14.pp }
{$push}

begin
  if bitsizeof(tprec14_tr) <> 32 then
    halt(1);
end;
{$pop}

{ Case tprec15.pp }
{$push}

begin
  fillchar(tprec15_r,sizeof(tprec15_r),0);
  tprec15_p(tprec15_r.a);
  if (tprec15_r.a<>$12) then
    halt(1);

  fillchar(tprec15_r,sizeof(tprec15_r),0);
  tprec15_p(tprec15_r.b);
  if (tprec15_r.b<>$12) then
    halt(1);

  fillchar(tprec15_r,sizeof(tprec15_r),0);
  tprec15_p(tprec15_r.c);
  if (tprec15_r.c<>$12) then
    halt(1);

  fillchar(tprec15_r,sizeof(tprec15_r),0);
  tprec15_p(tprec15_r.f);
  if (tprec15_r.f<>$12) then
    halt(1);

  fillchar(tprec15_r,sizeof(tprec15_r),0);
  tprec15_p(tprec15_r.h);
  if (tprec15_r.h<>$12) then
    halt(1);
end;
{$pop}

{ Case tprec19.pp }
{$push}

begin
  fillchar(tprec19_r,sizeof(tprec19_r),0);
  tprec19_p(@tprec19_r.a);
  if (tprec19_r.a<>$12) then
    halt(1);

  fillchar(tprec19_r,sizeof(tprec19_r),0);
  tprec19_p(@tprec19_r.b);
  if (tprec19_r.b<>$12) then
    halt(1);

  fillchar(tprec19_r,sizeof(tprec19_r),0);
  tprec19_p(@tprec19_r.c);
  if (tprec19_r.c<>$12) then
    halt(1);

  fillchar(tprec19_r,sizeof(tprec19_r),0);
  tprec19_p(@tprec19_r.f);
  if (tprec19_r.f<>$12) then
    halt(1);

  fillchar(tprec19_r,sizeof(tprec19_r),0);
  tprec19_p(@tprec19_r.h);
  if (tprec19_r.h<>$12) then
    halt(1);
end;
{$pop}

{ Case tprec2.pp }
{$push}
{$bitpacking on}
begin
  tprec2_t(tprec2_r);
  if (tprec2_r.a <> 2) or
     (tprec2_r.w <> 32768) or
     (tprec2_r.b <> 23) or
     (tprec2_r.e <> tprec2_ed) then
    halt(1);
end;
{$pop}

{ Case tprec25.pp }
{$push}

begin
      writeln('bitsizeof(_62bits): ',bitsizeof(tprec25_v2.f1));
      writeln('bitsizeof(_63bits): ',bitsizeof(tprec25_v2.f2));
      writeln('bitsizeof(_64bits1): ',bitsizeof(tprec25_v2.f3));
      writeln('bitsizeof(_64bits2): ',bitsizeof(tprec25_v2.f4));
      writeln('bitsizeof(_64bits3): ',bitsizeof(tprec25_v2.f5));

{$ifdef cpu64}
      if bitsizeof(tprec25_v2.f1)<>62 then
        halt(1);
      if bitsizeof(tprec25_v2.f2)<>63 then
        halt(1);
{$endif}
      if bitsizeof(tprec25_v2.f3)<>64 then
        halt(3);
      if bitsizeof(tprec25_v2.f3)<>64 then
        halt(4);
      if bitsizeof(tprec25_v2.f3)<>64 then
        halt(5);
    end;
{$pop}

{ Case tprec3.pp }
{$push}
{$bitpacking on}
begin
  tprec3_t(tprec3_r);
  if (tprec3_r.a <> 2) or
     (tprec3_r.i <> 1234567890123456789) or
     (not tprec3_r.c) or
     (tprec3_r.d <> 5) or
     (tprec3_r.e <> tprec3_ed) then
    halt(1);
end;
{$pop}

{ Case tprec4.pp }
{$push}
{$bitpacking on}
begin
  tprec4_foo;
  if tprec4_v1.f1 <> tprec4_enum128 then
    halt(1);
end;
{$pop}

{ Case tprec5.pp }
{$push}
{$bitpacking on}
begin
  tprec5_a1 := 42;
  tprec5_proc2 (tprec5_a1)
end;
{$pop}

{ Case tprec8.pp }
{$push}
{$bitpacking on}
begin
  tprec8_b := 0;
  tprec8_t(tprec8_r);
  if (tprec8_r.a <> 2) or
     (tprec8_r.i <> 1234567890123456789) or
     (not tprec8_r.c) or
     (tprec8_r.d <> 5) or
     (tprec8_r.e <> tprec8_ed) then
    halt(1);
  tprec8_r.g := 5;
  if (tprec8_r.g <> 5) then
    halt(2);
  tprec8_r.h := 65535;
  if (tprec8_r.h <> 65535) then
    halt(3);
  tprec8_r.k := true;
  if not (tprec8_r.k) then
    halt(4);
  tprec8_r.j := false;
  if tprec8_r.j then
    halt(5);
  if tprec8_b <> 0 then
    halt(6);
  if sizeof(tprec8_tr) <> 13 then
    halt(7);
end;
{$pop}

{ Case tpushpop2.pp }
{$push}
{$PackRecords 1}
{$Push}
{$PackRecords 4}
{$Pop}
begin
  if SizeOf(tpushpop2_TTest1) <> SizeOf(tpushpop2_TTest3) then
    Halt(1);
  if SizeOf(tpushpop2_TTest1) = SizeOf(tpushpop2_TTest2) then
    Halt(2);
  Writeln('ok');
end;
{$pop}

{ Case trecreg.pp }
{$push}

begin
  trecreg_i.s_un_b.s_b1 := $de;
  trecreg_i.s_un_b.s_b2 := $ad;
  trecreg_i.s_un_b.s_b3 := $be;
  trecreg_i.s_un_b.s_b4 := $ef;
  trecreg_t(trecreg_i);
  trecreg_i.s_un_w.s_w1.w := $cafe;
  trecreg_i.s_un_w.s_w2.b1 := $ba;
  trecreg_i.s_un_w.s_w2.b2 := $be;
  trecreg_t2(trecreg_i);
end;
{$pop}

{ Case trecreg2.pp }
{$push}

begin
  trecreg2_t;
end;
{$pop}

{ Case trecreg4.pp }
{$push}
{$bitpacking on}
begin
  trecreg4_t;
end;
{$pop}

{ Case tset5a.pp }
{$push}
{$ifdef fpc}
{$packset 1}
{$endif fpc}
{$z1}
begin
  tset5a_r.b1 := $ff;
  tset5a_r.b2 := $ff;
  tset5a_r.b3 := $ff;
  tset5a_r.va := [];
  tset5a_r.vb := [];
  tset5a_r.vc := [];
  tset5a_r.vd := [];
  tset5a_r.ve := [];

  tset5a_r.va := [3..4];
  tset5a_r.vb := tset5a_r.va;
  if tset5a_r.b1 <> $ff then
    halt(1);
  if tset5a_r.va <> [3..4] then
    halt(1);
  if tset5a_r.vb <> [3..4] then
    halt(1);
  if tset5a_r.vc <> [] then
    halt(1);
  if tset5a_r.vd <> [] then
    halt(1);
  if tset5a_r.ve <> [] then
    halt(1);
  tset5a_r.vc := tset5a_r.va;
  if tset5a_r.b1 <> $ff then
    halt(1);
  if tset5a_r.va <> [3..4] then
    halt(1);
  if tset5a_r.vb <> [3..4] then
    halt(1);
  if tset5a_r.vc <> [3..4] then
    halt(1);
  if tset5a_r.vd <> [] then
    halt(1);
  if tset5a_r.ve <> [] then
    halt(1);
  tset5a_r.vd := tset5a_r.va;
  if tset5a_r.b1 <> $ff then
    halt(1);
  if tset5a_r.va <> [3..4] then
    halt(1);
  if tset5a_r.vb <> [3..4] then
    halt(1);
  if tset5a_r.vc <> [3..4] then
    halt(1);
  if tset5a_r.vd <> [3..4] then
    halt(1);
  if tset5a_r.ve <> [] then
    halt(1);
  tset5a_r.ve := tset5a_r.va;
  if tset5a_r.b1 <> $ff then
    halt(1);
  if tset5a_r.va <> [3..4] then
    halt(1);
  if tset5a_r.vb <> [3..4] then
    halt(1);
  if tset5a_r.vc <> [3..4] then
    halt(1);
  if tset5a_r.vd <> [3..4] then
    halt(1);
  if tset5a_r.ve <> [3..4] then
    halt(1);

  tset5a_r.b1 := $ff;
  tset5a_r.b2 := $ff;
  tset5a_r.b3 := $ff;
  tset5a_r.va := [];
  tset5a_r.vb := [];
  tset5a_r.vc := [];
  tset5a_r.vd := [];
  tset5a_r.ve := [];

  tset5a_r.vb := [0,2,3];
  tset5a_r.va := tset5a_r.vb;
  if tset5a_r.b1 <> $ff then
    halt(2);
  if tset5a_r.va <> [0,2,3] then
    halt(2);
  if tset5a_r.vb <> [0,2,3] then
    halt(2);
  if tset5a_r.vc <> [] then
    halt(2);
  if tset5a_r.vd <> [] then
    halt(2);
  if tset5a_r.ve <> [] then
    halt(2);
  tset5a_r.vc := tset5a_r.vb;
  if tset5a_r.b1 <> $ff then
    halt(2);
  if tset5a_r.va <> [0,2,3] then
    halt(2);
  if tset5a_r.vb <> [0,2,3] then
    halt(2);
  if tset5a_r.vc <> [0,2,3] then
    halt(2);
  if tset5a_r.vd <> [] then
    halt(2);
  if tset5a_r.ve <> [] then
    halt(2);
  tset5a_r.vd := tset5a_r.vb;
  if tset5a_r.b1 <> $ff then
    halt(2);
  if tset5a_r.va <> [0,2,3] then
    halt(2);
  if tset5a_r.vb <> [0,2,3] then
    halt(2);
  if tset5a_r.vc <> [0,2,3] then
    halt(2);
  if tset5a_r.vd <> [0,2,3] then
    halt(2);
  if tset5a_r.ve <> [] then
    halt(2);
  tset5a_r.ve := tset5a_r.vb;
  if tset5a_r.va <> [0,2,3] then
    halt(2);
  if tset5a_r.vb <> [0,2,3] then
    halt(2);
  if tset5a_r.vc <> [0,2,3] then
    halt(2);
  if tset5a_r.vd <> [0,2,3] then
    halt(2);
  if tset5a_r.ve <> [0,2,3] then
    halt(2);


  tset5a_r.b1 := $ff;
  tset5a_r.b2 := $ff;
  tset5a_r.b3 := $ff;
  tset5a_r.va := [];
  tset5a_r.vb := [];
  tset5a_r.vc := [];
  tset5a_r.vd := [];
  tset5a_r.ve := [];

  tset5a_r.vc := [5,6,7];
  tset5a_r.va := tset5a_r.vc;
  if tset5a_r.b1 <> $ff then
    halt(3);
  if tset5a_r.va <> [5,6,7] then
    halt(3);
  if tset5a_r.vc <> [5,6,7] then
    halt(3);
  if tset5a_r.vb <> [] then
    halt(3);
  if tset5a_r.vd <> [] then
    halt(3);
  if tset5a_r.ve <> [] then
    halt(3);
  tset5a_r.vb := tset5a_r.vc;
  if tset5a_r.b1 <> $ff then
    halt(3);
  if tset5a_r.va <> [5,6,7] then
    halt(3);
  if tset5a_r.vb <> [5,6,7] then
    halt(3);
  if tset5a_r.vc <> [5,6,7] then
    halt(3);
  if tset5a_r.vd <> [] then
    halt(3);
  if tset5a_r.ve <> [] then
    halt(3);
  tset5a_r.vd := tset5a_r.vc;
  if tset5a_r.b1 <> $ff then
    halt(3);
  if tset5a_r.va <> [5,6,7] then
    halt(3);
  if tset5a_r.vb <> [5,6,7] then
    halt(3);
  if tset5a_r.vc <> [5,6,7] then
    halt(3);
  if tset5a_r.vd <> [5,6,7] then
    halt(3);
  if tset5a_r.ve <> [] then
    halt(3);
  tset5a_r.ve := tset5a_r.vc;
  if tset5a_r.b1 <> $ff then
    halt(3);
  if tset5a_r.va <> [5,6,7] then
    halt(3);
  if tset5a_r.vb <> [5,6,7] then
    halt(3);
  if tset5a_r.vc <> [5,6,7] then
    halt(3);
  if tset5a_r.vd <> [5,6,7] then
    halt(3);
  if tset5a_r.ve <> [5,6,7] then
    halt(3);


  tset5a_r.b1 := $ff;
  tset5a_r.b2 := $ff;
  tset5a_r.b3 := $ff;
  tset5a_r.va := [];
  tset5a_r.vb := [];
  tset5a_r.vc := [];
  tset5a_r.vd := [];
  tset5a_r.ve := [];

  tset5a_r.vd := [1,3,5];
  tset5a_r.va := tset5a_r.vd;
  if tset5a_r.b1 <> $ff then
    halt(4);
  if tset5a_r.va <> [1,3,5] then
    halt(4);
  if tset5a_r.vd <> [1,3,5] then
    halt(4);
  if tset5a_r.vc <> [] then
    halt(4);
  if tset5a_r.vb <> [] then
    halt(4);
  if tset5a_r.ve <> [] then
    halt(4);
  tset5a_r.vb := tset5a_r.vd;
  if tset5a_r.b1 <> $ff then
    halt(4);
  if tset5a_r.va <> [1,3,5] then
    halt(4);
  if tset5a_r.vb <> [1,3,5] then
    halt(4);
  if tset5a_r.vd <> [1,3,5] then
    halt(4);
  if tset5a_r.vc <> [] then
    halt(4);
  if tset5a_r.ve <> [] then
    halt(4);
  tset5a_r.vc := tset5a_r.vd;
  if tset5a_r.b1 <> $ff then
    halt(4);
  if tset5a_r.va <> [1,3,5] then
    halt(4);
  if tset5a_r.vb <> [1,3,5] then
    halt(4);
  if tset5a_r.vc <> [1,3,5] then
    halt(4);
  if tset5a_r.vd <> [1,3,5] then
    halt(4);
  if tset5a_r.ve <> [] then
    halt(4);
  tset5a_r.ve := tset5a_r.vd;
  if tset5a_r.b1 <> $ff then
    halt(4);
  if tset5a_r.va <> [1,3,5] then
    halt(4);
  if tset5a_r.vb <> [1,3,5] then
    halt(4);
  if tset5a_r.vc <> [1,3,5] then
    halt(4);
  if tset5a_r.vd <> [1,3,5] then
    halt(4);
  if tset5a_r.ve <> [1,3,5] then
    halt(4);


  tset5a_r.b1 := $ff;
  tset5a_r.b2 := $ff;
  tset5a_r.b3 := $ff;
  tset5a_r.va := [];
  tset5a_r.vb := [];
  tset5a_r.vc := [];
  tset5a_r.vd := [];
  tset5a_r.ve := [];

  tset5a_r.ve := [0,7];
  tset5a_r.va := tset5a_r.ve;
  if tset5a_r.b1 <> $ff then
    halt(5);
  if tset5a_r.va <> [0,7] then
    halt(5);
  if tset5a_r.ve <> [0,7] then
    halt(5);
  if tset5a_r.vc <> [] then
    halt(5);
  if tset5a_r.vd <> [] then
    halt(5);
  if tset5a_r.vb <> [] then
    halt(5);
  tset5a_r.vb := tset5a_r.ve;
  if tset5a_r.b1 <> $ff then
    halt(5);
  if tset5a_r.va <> [0,7] then
    halt(5);
  if tset5a_r.vb <> [0,7] then
    halt(5);
  if tset5a_r.ve <> [0,7] then
    halt(5);
  if tset5a_r.vd <> [] then
    halt(5);
  if tset5a_r.vc <> [] then
    halt(5);
  tset5a_r.vc := tset5a_r.ve;
  if tset5a_r.b1 <> $ff then
    halt(5);
  if tset5a_r.va <> [0,7] then
    halt(5);
  if tset5a_r.vb <> [0,7] then
    halt(5);
  if tset5a_r.vc <> [0,7] then
    halt(5);
  if tset5a_r.ve <> [0,7] then
    halt(5);
  if tset5a_r.vd <> [] then
    halt(5);
  tset5a_r.vd := tset5a_r.ve;
  if tset5a_r.b1 <> $ff then
    halt(5);
  if tset5a_r.va <> [0,7] then
    halt(5);
  if tset5a_r.vb <> [0,7] then
    halt(5);
  if tset5a_r.vc <> [0,7] then
    halt(5);
  if tset5a_r.vd <> [0,7] then
    halt(5);
  if tset5a_r.ve <> [0,7] then
    halt(5);

end;
{$pop}

{ Case tset7.pp }
{$push}
{$packset 1}
begin
  tset7_r.b:=101;
  tset7_r.w:=$abcd;
  tset7_r.a:=[2..3];
  include(tset7_r.a,7);
  tset7_test(tset7_r);
end;
{$pop}

{ Case tunaligned1.pp }
{$push}

begin
  tunaligned1_r1.a:=unaligned(tunaligned1_r1.b)*2;
  unaligned(tunaligned1_r1.a):=tunaligned1_r1.b*2;
  tunaligned1_r1.a:=tunaligned1_r1.b;
  tunaligned1_r1.a:=tunaligned1_r1.b div 10;
end;
{$pop}

end.
