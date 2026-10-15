{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tcase1.pas }
{$push}

function tcase1_case1(Val : byte) : char;
begin
  case Val of
    0..25 : tcase1_case1:=chr(Val + ord('A'));
    26..51: tcase1_case1:=chr(Val + ord('a') - 26);
    52..61: tcase1_case1:=chr(Val + ord('0') - 52);
    62    : tcase1_case1:='+';
    63    : tcase1_case1:='/';
  else
    tcase1_case1:='$';
  end;
end;

function tcase1_case2(Val : integer) : integer;
begin
  case Val of
    -1      : tcase1_case2:=1;
    32765..
    32767   : tcase1_case2:=2;
  else
    tcase1_case2:=-1;
  end;
end;

function tcase1_case3(Val : integer) : integer;
begin
  case Val of
    -32768..
    -32766 : tcase1_case3:=1;
    0..10  : tcase1_case3:=2;
  else
    tcase1_case3:=-1;
  end;
end;

var
  tcase1_error: boolean;


{$pop}

{ Case tendian2.pas }
{$push}


var
  tendian2_i16: Int16;
  tendian2_i32: Int32;
  tendian2_i64: Int64;
  tendian2_u16: UInt16;
  tendian2_u32: UInt32;
  tendian2_u64: UInt64;

{$pop}

{ Case tinivar.pas }
{$push}



procedure tinivar_p1;
var
  a : integer = 1;
begin
  writeln(a);
  if a<>1 then
    halt(1);
  inc(a);
end;


{$pop}

{ Case tinlin64.pas }
{$push}


{$inline on}

function tinlin64_add (tinlin64_a,tinlin64_b : int64) : int64;
begin
  tinlin64_add:=tinlin64_a+tinlin64_b;
end;

function tinlin64_inlineadd (tinlin64_a,tinlin64_b : int64) : int64; inline;
begin
  tinlin64_inlineadd:=tinlin64_a+tinlin64_b;
end;


var
  tinlin64_a, tinlin64_b, tinlin64_c, tinlin64_d : int64;


{$pop}

{ Case tinline1.pas }
{$push}


var
  tinline1_starti: longint;
  tinline1_i:longint;


{$INLINE ON}

procedure tinline1_kkainl(var c: longint); inline;
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  writeln('kka ',c);
  c:=c+1;
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
end;

procedure tinline1_kka(var c:longint);
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  writeln('kka ',c);
  c:=c+1;
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
end;

procedure tinline1_kkb(var c:longint);inline;
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  tinline1_kka(c);
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
  writeln('kkb ',c);
end;

procedure tinline1_kkb2(var c:longint);inline;
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  tinline1_kkainl(c);
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
  writeln('kkb ',c);
end;

procedure tinline1_kkc(var c: longint);
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  tinline1_kkb(c);
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
end;

procedure tinline1_kkcinl(var c: longint); inline;
begin
  if c <> tinline1_starti then
    begin
      writeln('bug');
      halt(1);
    end;
  tinline1_kkb2(c);
  if tinline1_i <> tinline1_starti+1 then
    begin
      writeln('bug');
      halt(1);
    end;
end;


{$pop}

{ Case tinline2.pas }
{$push}
{$inline on}
procedure tinline2_test(var tinline2_a : longint;tinline2_b : longint);inline;

begin
  tinline2_a:=32-tinline2_b;
end;

procedure tinline2_test2(var tinline2_a : longint;tinline2_b : longint);

begin
  tinline2_a:=32-tinline2_b;
end;

  var
    tinline2_a,tinline2_b : longint;

{$pop}

{ Case tinline3.pas }
{$push}
{$inline on}

var
  tinline3_err : boolean;
  tinline3_i : longint;

procedure tinline3_p1(b:byte);inline;
begin
  case b of
    1 :
      begin
        writeln('1');
        tinline3_i:=1;
      end;
    2 :
      begin
        if tinline3_i<>1 then
          tinline3_err:=true
        else
          writeln('2');
        tinline3_i:=2;
      end;
  end;
end;

procedure tinline3_p2(b:byte);inline;
begin
  case b of
    1 :
      tinline3_p1(b);
    2 :
      tinline3_p1(b);
  end;
end;


{$pop}

{ Case tinline7.pas }
{$push}
{$inline on}

function tinline7_f(const a,b: longint): longint; inline;
begin
  tinline7_f:=a*b;
end;


{$pop}

{ Case tinterrupt.pas }
{$push}




procedure tinterrupt_test1;interrupt;
begin
  Writeln('Test1 interrupt');
end;

procedure tinterrupt_test2(var a,b : longint);interrupt;
begin
  Writeln('Test2 interrupt');
  a:=1;
  b:=2;
end;

function tinterrupt_test3 : longint; interrupt;
begin
  Writeln('test3 called');
  tinterrupt_test3:=55;
end;

  var
    tinterrupt_x,tinterrupt_y : longint;


{$pop}

{ Case tmath1.pas }
{$push}



Procedure tmath1_TestDiv;
var
 bx,by: byte;
 ix,iy: integer;
 wx,wy: word;
 lx,ly: longint;
Begin
 { byte test }
 bx:=10;
 by:=5;
 bx:=bx div by;
 if bx = 2 then
  WriteLn('TEST_DIV(1): PASSED.')
 else
  WriteLn('TEST_DIV(1): FAILED.');
 bx:=20;
 bx:=bx div 10;
 if bx = 2 then
  WriteLn('TEST_DIV(2): PASSED.')
 else
  WriteLn('TEST_DIV(2): FAILED.');
 { integer test }
 ix:=-10;
 iy:=5;
 ix:=ix div iy;
 if ix = -2 then
  WriteLn('TEST_DIV(3): PASSED.')
 else
  WriteLn('TEST_DIV(3): FAILED.');
 ix:=-20;
 ix:=ix div 10;
 if ix = -2 then
  WriteLn('TEST_DIV(4): PASSED.')
 else
  WriteLn('TEST_DIV(4): FAILED.');
 { word test }
 wx:=64000;
 wy:=2;
 wx:=wx div wy;
 if wx = 32000 then
  WriteLn('TEST_DIV(5): PASSED.')
 else
  WriteLn('TEST_DIV(5): FAILED.');
 wx:=20;
 wx:=wx div 10;
 if wx = 2 then
  WriteLn('TEST_DIV(6): PASSED.')
 else
  WriteLn('TEST_DIV(6): FAILED.');
 { longint test }
 lx:=-1000000;
 ly:=2;
 lx:=lx div ly;
 if lx = -500000 then
  WriteLn('TEST_DIV(7): PASSED.')
 else
  WriteLn('TEST_DIV(7): FAILED.');
 lx:=-1000000;
 lx:=lx div 10;
 if lx = -100000 then
  WriteLn('TEST_DIV(8): PASSED.')
 else
  WriteLn('TEST_DIV(8): FAILED.')
end;





{$pop}

{ Case tmul1.pas }
{$push}
{ This test explicity generates overflow errors for 32-bit processors
  or range check errors for 64-bit processors.
  Thus, we need explicit $Q- and $R- }
{$Q-}
{$R-}

var
  tmul1_i : longint;


{$pop}

{ Case tpopcnt1.pas }
{$push}
var
  tpopcnt1_b : byte;
  tpopcnt1_si : shortint;
  tpopcnt1_w : word;
  tpopcnt1_i : integer;
  tpopcnt1_d : dword;
  tpopcnt1_li : longint;
  tpopcnt1_q : qword;
  tpopcnt1_i64 : int64;


{$pop}

{ Case tpopcnt2.pas }
{$push}

{$pop}

{ Case trange4.pas }
{$push}

var trange4_x : byte;
      trange4_y : longint;

procedure trange4_set_x;
begin
   trange4_y:=345;
  {$R-}
    trange4_x:=trange4_y;
  {$R+}
    Writeln('x = ',trange4_x);
  {$R-}
    trange4_x:=trange4_y
  {$R+}
end;
{ the bug comes from the fact that as there is no
semicolon after x:=y the parser must read up to end; statement
and thus change the range check mode before
the assign node is created !! }


{$pop}

{ Case trox1.pas }
{$push}
{$Q-}
{$R-}

procedure trox1_do_error(i : integer);
  begin
    writeln('Error: ',i);
    halt(1);
  end;

var
  trox1_b1,trox1_b2 : byte;
  trox1_w1 : word;
  trox1_d1 : dword;
  trox1_q1 : qword;

{$pop}

{ Case trox2.pas }
{$push}
{$Q-}
{$R-}

// tests whether the rol/ror operations properly mask out the shift count
procedure trox2_do_error(i : integer);
  begin
    writeln('Error: ',i);
    halt(1);
  end;

var
  trox2_b1,trox2_b2 : byte;
  trox2_w1 : word;
  trox2_d1 : dword;
  trox2_q1 : qword;

{$pop}

{ Case trox3.pas }
{$push}
{$Q-}
{$R-}

procedure trox3_do_error(i : integer);
  begin
    writeln('Error: ',i);
    halt(1);
  end;

var
  trox3_b1,trox3_b2 : byte;
  trox3_w1 : word;
  trox3_d1 : dword;
  trox3_q1 : qword;

{$pop}

{ Case trox4.pas }
{$push}
{$Q-}
{$R-}

// tests whether the rol/ror operations properly mask out the shift count
procedure trox4_do_error(i : integer);
  begin
    writeln('Error: ',i);
    halt(1);
  end;

var
  trox4_b1 : byte;
  trox4_w1 : word;
  trox4_d1 : dword;
  trox4_q1 : qword;

{$pop}

{ Case trox5.pas }
{$push}
{$r-}
var
  trox5_l : longint;

{$pop}

{ Case trtti2.pas }
{$push}
type
   trtti2_pbyte = ^byte;


{$pop}

{ Case ttpara2.pas }
{$push}
{ Alignment test for stack passed parameters }
procedure ttpara2_p1(b1,b2,b3,b4,b5,b6,b7,b8:byte);
begin
  if b1<>1 then
    halt(1);
  if b2<>2 then
    halt(2);
  if b3<>3 then
    halt(1);
  if b4<>4 then
    halt(1);
  if b5<>5 then
    halt(1);
  if b6<>6 then
    halt(1);
  if b7<>7 then
    halt(1);
  if b8<>8 then
    halt(1);
end;


{$pop}

begin

{ Case tcase1.pas }
{$push}

begin
  { The correct outputs should be:
    F $
    2 2
    1 2 2
  }
  tcase1_error := false;
  writeln(tcase1_case1(5), ' ', tcase1_case1(255),' (should be: F $)');
  tcase1_error := (tcase1_case1(5) <> 'F') or (tcase1_case1(255) <> '$');
  writeln(tcase1_case2(32765), ' ', tcase1_case2(32767),' (should be: 2 2)');
  tcase1_error := tcase1_error or (tcase1_case2(32765) <> 2) or (tcase1_case2(32767) <> 2);
  writeln(tcase1_case3(-32768),' ',tcase1_case3(0), ' ',tcase1_case3(5),' (should be: 1 2 2)');
  tcase1_error := tcase1_error or (tcase1_case3(-32768) <> 1) or (tcase1_case3(0) <> 2) or
           (tcase1_case3(5) <> 2);
  if tcase1_error then
    halt(1);
end;
{$pop}

{ Case tendian2.pas }
{$push}

begin
  tendian2_i16 := $1234;
  tendian2_i32 := $12345678;
  tendian2_i64 := $1234567843218765;
  tendian2_u16 := $1234;
  tendian2_u32 := $12345678;
  tendian2_u64 := $1234567843218765;

  if SwapEndian(tendian2_i16) <> $3412 then
    Halt(1);
  if SwapEndian(tendian2_i32) <> $78563412 then
    Halt(2);
  if SwapEndian(tendian2_i64) <> $6587214378563412 then
    Halt(3);

  if SwapEndian(tendian2_u16) <> $3412 then
    Halt(4);
  if SwapEndian(tendian2_u32) <> $78563412 then
    Halt(5);
  if SwapEndian(tendian2_u64) <> $6587214378563412 then
    Halt(6);
end;
{$pop}

{ Case tinivar.pas }
{$push}

begin
  tinivar_p1;
  tinivar_p1;
end;
{$pop}

{ Case tinlin64.pas }
{$push}
{$inline on}
begin
  tinlin64_a:=50;
  tinlin64_b:=78;
  tinlin64_d:= -45;
  writeln('a (',tinlin64_a,') + b (',tinlin64_b,') = ',tinlin64_a+tinlin64_b);
  writeln('Using add function');
  writeln('a (',tinlin64_a,') + b (',tinlin64_b,') = ',tinlin64_add(tinlin64_a+1,tinlin64_b-1));
  writeln('Using add function inlined');
  writeln('a (',tinlin64_a,') + b (',tinlin64_b,') = ',tinlin64_inlineadd(tinlin64_a+1,tinlin64_b-1));
  tinlin64_c:=tinlin64_inlineadd(tinlin64_a+tinlin64_d,tinlin64_b-tinlin64_d);
  writeln('a (',tinlin64_a,') + b (',tinlin64_b,') = ',tinlin64_c);
  if (tinlin64_a+tinlin64_b<>tinlin64_add(tinlin64_a-1,tinlin64_b+1)) then
    begin
      writeln('Error in function with int64 args');
      Halt(1);
    end;
  if (tinlin64_a+tinlin64_b<>tinlin64_inlineadd(tinlin64_a+1,tinlin64_b-1)) then
    begin
      writeln('Error in inlined function with int64 args');
      Halt(1);
    end;
end;
{$pop}

{ Case tinline1.pas }
{$push}
{$INLINE ON}
begin
  tinline1_i:=5;
  tinline1_starti := 5;
  tinline1_kkc(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kkc(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kkb(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kkb(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kka(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kkcinl(tinline1_i);
  tinline1_starti := tinline1_i;
  tinline1_kkb2(tinline1_i);
end;
{$pop}

{ Case tinline2.pas }
{$push}
{$inline on}
begin
  tinline2_test2(tinline2_a,16);
  Writeln('a=',tinline2_a,' should be 16');
  if (tinline2_a<>16) then halt(1);
  tinline2_test(tinline2_a,16);
  Writeln('a=',tinline2_a,' should be 16');
  if (tinline2_a<>16) then halt(1);
end;
{$pop}

{ Case tinline3.pas }
{$push}
{$inline on}
begin
  tinline3_p2(1);
  tinline3_p2(2);
  if tinline3_err then
    halt(1);
end;
{$pop}

{ Case tinline7.pas }
{$push}
{$inline on}
begin
  if (tinline7_f(tinline7_f(tinline7_f(2,5),3),4) <> 120) then
    halt(1);
end;
{$pop}

{ Case tinterrupt.pas }
{$push}

begin
  tinterrupt_x:=-1;
  tinterrupt_test1;
  tinterrupt_test2(tinterrupt_x,tinterrupt_y);
  if (tinterrupt_x<>1) or (tinterrupt_y<>2) then
    begin
      Writeln('Error with interrupt');
      Halt(1);
    end;
  if tinterrupt_test3<>55 then
    begin
      Writeln('Error with interrupt function');
      Halt(1);
    end;
end;
{$pop}

{ Case tmath1.pas }
{$push}

Begin
 tmath1_Testdiv;
end;
{$pop}

{ Case tmul1.pas }
{$push}
{$Q-}
{$R-}
begin
  tmul1_i:=5;
  tmul1_i:=tmul1_i*$80010;
  if tmul1_i<>2621520 then
    halt(1);

  tmul1_i:=5;
  tmul1_i:=tmul1_i*$18000010;
  if tmul1_i<>2013266000 then
    halt(1);

  tmul1_i:=5;
  tmul1_i:=tmul1_i*$18ffffef;
  if tmul1_i<>2097151915 then
    halt(1);

  tmul1_i:=5;
  tmul1_i:=tmul1_i*$7ffef;
  if tmul1_i<>2621355 then
    halt(1);

  tmul1_i:=5;
  tmul1_i:=tmul1_i*$6fffffcf;
  if tmul1_i<>805306123 then
    halt(1);

  tmul1_i:=5;
  tmul1_i:=tmul1_i*10;
  tmul1_i:=tmul1_i*62;
  tmul1_i:=tmul1_i*-10;
  tmul1_i:=tmul1_i*-62;
  tmul1_i:=tmul1_i*87;
  if tmul1_i<>167214000 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tpopcnt1.pas }
{$push}

begin
  { 8 Bit }

  tpopcnt1_b:=$a4;
  if popcnt(tpopcnt1_b)<>3 then
    halt(1);

  tpopcnt1_b:=$0;
  if popcnt(tpopcnt1_b)<>0 then
    halt(1);

  tpopcnt1_b:=$20;
  if popcnt(tpopcnt1_b)<>1 then
    halt(1);

  writeln('popcnt(<byte>); passed');

{
  si:=$54;
  if popcnt(si)<>3 then
    halt(1);

  si:=$0;
  if popcnt(si)<>0 then
    halt(1);

  si:=$20;
  if popcnt(si)<>1 then
    halt(1);
}

  { 16 Bit }

  tpopcnt1_w:=$a4a4;
  if popcnt(tpopcnt1_w)<>6 then
    halt(1);

  tpopcnt1_w:=$0;
  if popcnt(tpopcnt1_w)<>0 then
    halt(1);

  tpopcnt1_w:=$2020;
  if popcnt(tpopcnt1_w)<>2 then
    halt(1);

  writeln('popcnt(<word>); passed');

{
  i:=$5454;
  if popcnt(i)<>6 then
    halt(1);

  i:=$0;
  if popcnt(i)<>0 then
    halt(1);

  i:=$2020;
  if popcnt(i)<>2 then
    halt(1);
}

  { 32 Bit }

  tpopcnt1_d:=$a4a4a4a4;
  if popcnt(tpopcnt1_d)<>12 then
    halt(1);

  tpopcnt1_d:=$0;
  if popcnt(tpopcnt1_d)<>0 then
    halt(1);

  tpopcnt1_d:=$20402040;
  if popcnt(tpopcnt1_d)<>4 then
    halt(1);

  writeln('popcnt(<dword>); passed');

{
  li:=$54545454;
  if popcnt(li)<>12 then
    halt(1);

  li:=$0;
  if popcnt(li)<>0 then
    halt(1);

  li:=$20402080;
  if popcnt(li)<>4 then
    halt(1);
}

  { 64 Bit }

  tpopcnt1_q:=qword($a4a4a4a4a4a4a4a4);
  if popcnt(tpopcnt1_q)<>24 then
    halt(1);

  tpopcnt1_q:=$0;
  if popcnt(tpopcnt1_q)<>0 then
    halt(1);

  tpopcnt1_q:=$2040204080804001;
  if popcnt(tpopcnt1_q)<>8 then
    halt(1);

  tpopcnt1_q:=qword($a4a4a4a400000000);
  if popcnt(tpopcnt1_q)<>12 then
    halt(1);

  writeln('popcnt(<qword>); passed');

{
  i64:=$5454545454545454;
  if popcnt(i64)<>24 then
    halt(1);

  i64:=$0;
  if popcnt(i64)<>0 then
    halt(1);

  i64:=$2040208020402080;
  if popcnt(li)<>8 then
    halt(1);
}

  writeln('ok');
end;
{$pop}

{ Case tpopcnt2.pas }
{$push}

begin
  { 8 Bit }

  if popcnt(byte($a4))<>3 then
    halt(1);

  if popcnt(byte($0))<>0 then
    halt(1);

  if popcnt(byte($20))<>1 then
    halt(1);

  writeln('popcnt(<byte>); passed');

{
  if popcnt(shortint($54))<>3 then
    halt(1);

  if popcnt(shortint($0))<>0 then
    halt(1);

  if popcnt(shortint($20))<>1 then
    halt(1);
}

  { 16 Bit }

  if popcnt(word($a4a4))<>6 then
    halt(1);

  if popcnt(word($0))<>0 then
    halt(1);

  if popcnt(word($2020))<>2 then
    halt(1);

  writeln('popcnt(<word>); passed');

{
  if popcnt(integer($5454))<>6 then
    halt(1);

  if popcnt(integer($0))<>0 then
    halt(1);

  if popcnt(integer($2020))<>2 then
    halt(1);
}

  { 32 Bit }

  if popcnt(dword($a4a4a4a4))<>12 then
    halt(1);

  if popcnt(dword($0))<>0 then
    halt(1);

  if popcnt(dword($20402040))<>4 then
    halt(1);

  writeln('popcnt(<dword>); passed');

{
  if popcnt(longint($54545454))<>12 then
    halt(1);

  if popcnt(longint($0))<>0 then
    halt(1);

  if popcnt(longint($20402080))<>4 then
    halt(1);
}

  { 64 Bit }

  if popcnt(qword($a4a4a4a4a4a4a4a4))<>24 then
    halt(1);

  if popcnt(qword($0))<>0 then
    halt(1);

  if popcnt(qword($2040204080804001))<>8 then
    halt(1);

  if popcnt(qword($a4a4a4a400000000))<>12 then
    halt(1);

  writeln('popcnt(<qword>); passed');

{
  if popcnt(int64($5454545454545454))<>24 then
    halt(1);

  if popcnt(int64($0))<>0 then
    halt(1);

  if popcnt(int64($2040208020402080))<>8 then
    halt(1);
}

  writeln('ok');
end;
{$pop}

{ Case trange4.pas }
{$push}
{$R-}
{$R+}
{$R-}
{$R+}
begin
  trange4_set_x;
  Writeln('x = ',trange4_x);
end;
{$pop}

{ Case trox1.pas }
{$push}
{$Q-}
{$R-}
begin
  trox1_b1:=1;
  trox1_b2:=3;
  trox1_b1:=rorbyte(trox1_b1);
  trox1_b1:=rorbyte(trox1_b1,2);
  trox1_b1:=rorbyte(trox1_b1,trox1_b2);
  if trox1_b1<>4 then
    trox1_do_error(1000);

  trox1_w1:=1;
  trox1_b2:=3;
  trox1_w1:=rorword(trox1_w1);
  trox1_w1:=rorword(trox1_w1,2);
  trox1_w1:=rorword(trox1_w1,trox1_b2);
  if trox1_w1<>$400 then
    trox1_do_error(1001);

  trox1_d1:=1;
  trox1_b2:=3;
  trox1_d1:=rordword(trox1_d1);
  trox1_d1:=rordword(trox1_d1,2);
  trox1_d1:=rordword(trox1_d1,trox1_b2);
  if trox1_d1<>$4000000 then
    trox1_do_error(1002);

  trox1_q1:=1;
  trox1_b2:=3;
  trox1_q1:=rorqword(trox1_q1);
  trox1_q1:=rorqword(trox1_q1,2);
  trox1_q1:=rorqword(trox1_q1,trox1_b2);
  if trox1_q1<>$400000000000000 then
    trox1_do_error(1003);

  trox1_b1:=1;
  trox1_b2:=3;
  trox1_b1:=rolbyte(trox1_b1);
  trox1_b1:=rolbyte(trox1_b1,2);
  trox1_b1:=rolbyte(trox1_b1,trox1_b2);
  if trox1_b1<>$40 then
    trox1_do_error(2000);

  trox1_w1:=$8001;
  trox1_b2:=3;
  trox1_w1:=rolword(trox1_w1);
  trox1_w1:=rolword(trox1_w1,2);
  trox1_w1:=rolword(trox1_w1,trox1_b2);
  if trox1_w1<>$60 then
    trox1_do_error(2001);

  trox1_d1:=$80000001;
  trox1_b2:=3;
  trox1_d1:=roldword(trox1_d1);
  trox1_d1:=roldword(trox1_d1,2);
  trox1_d1:=roldword(trox1_d1,trox1_b2);
  if trox1_d1<>$60 then
    trox1_do_error(2002);

  trox1_q1:=$8000000000000001;
  trox1_b2:=3;
  trox1_q1:=rolqword(trox1_q1);
  trox1_q1:=rolqword(trox1_q1,2);
  trox1_q1:=rolqword(trox1_q1,trox1_b2);
  if trox1_q1<>$60 then
    trox1_do_error(2003);

  writeln('ok');
end;
{$pop}

{ Case trox2.pas }
{$push}
{$Q-}
{$R-}
begin
  trox2_b1:=2;
  trox2_b2:=15;
  trox2_b1:=rorbyte(trox2_b1,trox2_b2);
  if trox2_b1<>4 then
    trox2_do_error(1000);

  trox2_w1:=1;
  trox2_b2:=29;
  trox2_w1:=rorword(trox2_w1,trox2_b2);
  if trox2_w1<>$8 then
    trox2_do_error(1001);

  trox2_d1:=$400;
  trox2_b2:=60;
  trox2_d1:=rordword(trox2_d1,trox2_b2);
  if trox2_d1<>$4000 then
    trox2_do_error(1002);

  trox2_q1:=$80000000000;
  trox2_b2:=125;
  trox2_q1:=rorqword(trox2_q1,trox2_b2);
  if trox2_q1<>$400000000000 then
    trox2_do_error(1003);

  trox2_b1:=$81;
  trox2_b2:=14;
  trox2_b1 := rolbyte(trox2_b1, trox2_b2);
  if (trox2_b1 <> $60) then
    trox2_do_error(2000);


  trox2_w1:=$8001;
  trox2_b2:=22;
  trox2_w1:=rolword(trox2_w1,trox2_b2);
  if trox2_w1<>$60 then
    trox2_do_error(2001);

  trox2_d1:=$80000001;
  trox2_b2:=38;
  trox2_d1:=roldword(trox2_d1,trox2_b2);
  if trox2_d1<>$60 then
    trox2_do_error(2002);

  trox2_q1:=qword($8000000000000001);
  trox2_b2:=70;
  trox2_q1:=rolqword(trox2_q1,trox2_b2);
  if trox2_q1<>$60 then
    trox2_do_error(2003);

  writeln('ok');
end;
{$pop}

{ Case trox3.pas }
{$push}
{$Q-}
{$R-}
begin
  trox3_b1:=rorbyte(rorbyte(rorbyte(1),2),3);
  if trox3_b1<>4 then
    trox3_do_error(1000);

  trox3_w1:=rorword(rorword(rorword(1),2),3);
  if trox3_w1<>$400 then
    trox3_do_error(1001);

  trox3_d1:=rordword(rordword(rordword(1),2),3);
  if trox3_d1<>$4000000 then
    trox3_do_error(1002);

  trox3_q1:=rorqword(rorqword(rorqword(1),2),3);
  if trox3_q1<>$400000000000000 then
    trox3_do_error(1003);

  trox3_b1:=rolbyte(rolbyte(rolbyte(1),2),3);
  if trox3_b1<>$40 then
    trox3_do_error(2000);

  trox3_w1:=rolword(rolword(rolword($8001),2),3);
  if trox3_w1<>$60 then
    trox3_do_error(2001);

  trox3_d1:=roldword(roldword(roldword($80000001),2),3);
  if trox3_d1<>$60 then
    trox3_do_error(2002);

  trox3_q1:=rolqword(rolqword(rolqword($8000000000000001),2),3);
  if trox3_q1<>$60 then
    trox3_do_error(2003);

  writeln('ok');
end;
{$pop}

{ Case trox4.pas }
{$push}
{$Q-}
{$R-}
begin
  trox4_b1:=rorbyte(2,15);
  if trox4_b1<>4 then
    trox4_do_error(1000);

  trox4_w1:=rorword(1,29);
  if trox4_w1<>$8 then
    trox4_do_error(1001);

  trox4_d1:=rordword($400,60);
  if trox4_d1<>$4000 then
    trox4_do_error(1002);

  trox4_q1:=rorqword($80000000000,125);
  if trox4_q1<>$400000000000 then
    trox4_do_error(1003);

  trox4_b1 := rolbyte($81,14);
  if (trox4_b1 <> $60) then
    trox4_do_error(2000);

  trox4_w1:=rolword($8001,22);
  if trox4_w1<>$60 then
    trox4_do_error(2001);

  trox4_d1:=roldword($80000001,38);
  if trox4_d1<>$60 then
    trox4_do_error(2002);

  trox4_q1:=rolqword(qword($8000000000000001),70);
  if trox4_q1<>$60 then
    trox4_do_error(2003);

  writeln('ok');
end;
{$pop}

{ Case trox5.pas }
{$push}
{$r-}
begin
  trox5_l:=$ff;
  trox5_l:=RorByte(trox5_l);
  if trox5_l<>$ff then
    halt(1);
  trox5_l:=RolByte(trox5_l);
  if trox5_l<>$ff then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case trtti2.pas }
{$push}

begin
   if trtti2_pbyte(typeinfo(longint))^<>1 then
     halt(1);
end;
{$pop}

{ Case ttpara2.pas }
{$push}

begin
  ttpara2_p1(1,2,3,4,5,6,7,8);
end;
{$pop}

end.
