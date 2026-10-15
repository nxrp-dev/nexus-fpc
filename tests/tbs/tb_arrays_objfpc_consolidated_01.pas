{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tb0663.pas }
{$push}

{$PIC+}

{
  Test for proper initialization of GOT register.
}

const
  tb0663_BufSize = 128*1024;

var
  tb0663_gvar: longint;

procedure tb0663_check(c, e: longint);
begin
  if c <> e then begin
    writeln('ERROR. Result: ', c, '  Expected: ', e);
    Halt(1);
  end;
end;

function tb0663_test101(p1, p2: longint): longint;
begin
  result:=tb0663_gvar+p1+p2;
end;

function tb0663_test102(p1, p2: longint): longint;
var
  Buffer: array[0..tb0663_BufSize] of byte;
begin
  Buffer[0]:=0;
  result:=tb0663_gvar+p1+p2+Buffer[0];
end;

function tb0663_test103(p1, p2: longint): longint;
var
  a, j: longint;
begin
  a:=0;
  for j:=1 to 1 do begin
    a:=a + j;
    a:=a - j;
  end;
  result:=tb0663_gvar+p1+p2+a;
end;

function tb0663_test111(p1, p2: longint): longint;
var
  i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, i15: longint;
  a, j: longint;
begin
  i1:=1;i2:=2;i3:=3;i4:=4;i5:=5;i6:=6;i7:=7;i8:=8;i9:=9;i10:=10;i11:=11;i12:=12;i13:=13;i14:=14;i15:=15;
  a:=0;
  for j:=1 to 1 do begin
    a:=a + (i1+i2+i3+i4+i5+i6+i7+i8+i9+i10+i11+i12+i13+i14+i15);
    a:=a - (i1+i2+i3+i4+i5+i6+i7+i8+i9+i10+i11+i12+i13+i14+i15);
  end;
  result:=tb0663_gvar+p1+p2+a;
end;

function tb0663_test112(p1, p2: longint): longint;
var
  i1, i2, i3, i4, i5, i6, i7, i8, i9, i10, i11, i12, i13, i14, i15: longint;
  a, j: longint;
  Buffer: array[0..tb0663_BufSize] of byte;
begin
  i1:=1;i2:=2;i3:=3;i4:=4;i5:=5;i6:=6;i7:=7;i8:=8;i9:=9;i10:=10;i11:=11;i12:=12;i13:=13;i14:=14;i15:=15;
  a:=0;
  Buffer[0]:=0;
  for j:=1 to 1 do begin
    a:=a + (i1+i2+i3+i4+i5+i6+i7+i8+i9+i10+i11+i12+i13+i14+i15);
    a:=a - (i1+i2+i3+i4+i5+i6+i7+i8+i9+i10+i11+i12+i13+i14+i15);
    a:=a + Buffer[0];
  end;
  result:=tb0663_gvar+p1+p2+a;
end;


{$pop}

{ Case tw35224.pas }
{$push}

{$OPTIMIZATION LOOPUNROLL}

type tw35224_TList = array [0..3] of integer;

var tw35224_worklist, tw35224_tmplist : tw35224_TList;

function tw35224_flip (const list1: tw35224_TList; var list2: tw35224_TList): integer; inline;
var i: integer;
begin
  for i := 0 to 3 do list2[i] := list1[i];
end;


{$pop}

{ Case tw37554.pas }
{$push}


{$H+}

const
  tw37554_CmpArray: array[0..88] of Int64 = (
    -1, $FFFFFFFF, -3000000, -2147483648, -131073,

    $FFFFFFFFFFFF0000, $FFFFFFFF0000FFFF, $FFFF0000FFFFFFFF, $0000FFFFFFFFFFFF,

    $FFFFFFFFFFFFFFFE, $FFFFFFFFFFFFFFFD, $FFFFFFFFFFFFFFFB, $FFFFFFFFFFFFFFF7,
    $FFFFFFFFFFFFFFEF, $FFFFFFFFFFFFFFDF, $FFFFFFFFFFFFFFBF, $FFFFFFFFFFFFFF7F,
    $FFFFFFFFFFFFFEFF, $FFFFFFFFFFFFFDFF, $FFFFFFFFFFFFFBFF, $FFFFFFFFFFFFF7FF,
    $FFFFFFFFFFFFEFFF, $FFFFFFFFFFFFDFFF, $FFFFFFFFFFFFBFFF, $FFFFFFFFFFFF7FFF,
    $FFFFFFFFFFFEFFFF, $FFFFFFFFFFFDFFFF, $FFFFFFFFFFFBFFFF, $FFFFFFFFFFF7FFFF,
    $FFFFFFFFFFEFFFFF, $FFFFFFFFFFDFFFFF, $FFFFFFFFFFBFFFFF, $FFFFFFFFFF7FFFFF,
    $FFFFFFFFFEFFFFFF, $FFFFFFFFFDFFFFFF, $FFFFFFFFFBFFFFFF, $FFFFFFFFF7FFFFFF,
    $FFFFFFFFEFFFFFFF, $FFFFFFFFDFFFFFFF, $FFFFFFFFBFFFFFFF, $FFFFFFFF7FFFFFFF,
    $FFFFFFFEFFFFFFFF, $FFFFFFFDFFFFFFFF, $FFFFFFFBFFFFFFFF, $FFFFFFF7FFFFFFFF,
    $FFFFFFEFFFFFFFFF, $FFFFFFDFFFFFFFFF, $FFFFFFBFFFFFFFFF, $FFFFFF7FFFFFFFFF,
    $FFFFFEFFFFFFFFFF, $FFFFFDFFFFFFFFFF, $FFFFFBFFFFFFFFFF, $FFFFF7FFFFFFFFFF,
    $FFFFEFFFFFFFFFFF, $FFFFDFFFFFFFFFFF, $FFFFBFFFFFFFFFFF, $FFFF7FFFFFFFFFFF,
    $FFFEFFFFFFFFFFFF, $FFFDFFFFFFFFFFFF, $FFFBFFFFFFFFFFFF, $FFF7FFFFFFFFFFFF,
    $FFEFFFFFFFFFFFFF, $FFDFFFFFFFFFFFFF, $FFBFFFFFFFFFFFFF, $FF7FFFFFFFFFFFFF,
    $FEFFFFFFFFFFFFFF, $FDFFFFFFFFFFFFFF, $FBFFFFFFFFFFFFFF, $F7FFFFFFFFFFFFFF,
    $EFFFFFFFFFFFFFFF, $DFFFFFFFFFFFFFFF, $BFFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF,

    $FFFFFFFFFFFF1234, $FFFFFFFF1234FFFF, $FFFF1234FFFFFFFF, $1234FFFFFFFFFFFF,
    $FFFFFFFF12341234, $FFFF1234FFFF1234, $FFFF12341234FFFF, $FFFF123412341234,
    $FFFFFFFFFFFF0001, $FFFFFFFF0001FFFF, $FFFF0001FFFFFFFF, $0001FFFFFFFFFFFF,

    $0000000100000001, $0000000500000005, $0000AAAA0000AAAA, $0000FFFF0000FFFF
  );

var
  tw37554_Fail: Boolean;

procedure tw37554_CompareImmediate(CmpIndex: Integer; TestVal: Int64);
begin
  Write('Test ', CmpIndex, '; input constant: ', TestVal, '; comparing against: ', tw37554_CmpArray[CmpIndex], ' - ');
  if TestVal = tw37554_CmpArray[CmpIndex] then
    begin
      WriteLn('Pass');
      Exit;
    end;

  WriteLn('FAIL - expected ', tw37554_CmpArray[CmpIndex]);
  tw37554_Fail := True;
end;


{$pop}

begin

{ Case tb0663.pas }
{$push}

{$PIC+}
begin
  tb0663_gvar:=100;
  tb0663_check(tb0663_test101(10, 20), 130);
  tb0663_check(tb0663_test102(20, 30), 150);
  tb0663_check(tb0663_test103(30, 40), 170);
  tb0663_check(tb0663_test111(110, 20), 230);
  tb0663_check(tb0663_test112(120, 30), 250);
end;
{$pop}

{ Case tw35224.pas }
{$push}

{$OPTIMIZATION LOOPUNROLL}
begin
  tw35224_flip (tw35224_worklist, tw35224_tmplist);
end;
{$pop}

{ Case tw37554.pas }
{$push}

{$H+}
begin
  tw37554_Fail := False;

  tw37554_CompareImmediate(0, -1);
  tw37554_CompareImmediate(1, $FFFFFFFF);
  tw37554_CompareImmediate(2, -3000000);
  tw37554_CompareImmediate(3, -2147483648);
  tw37554_CompareImmediate(4, -131073);

  tw37554_CompareImmediate(5, $FFFFFFFFFFFF0000);
  tw37554_CompareImmediate(6, $FFFFFFFF0000FFFF);
  tw37554_CompareImmediate(7, $FFFF0000FFFFFFFF);
  tw37554_CompareImmediate(8, $0000FFFFFFFFFFFF);

  tw37554_CompareImmediate(9, $FFFFFFFFFFFFFFFE);
  tw37554_CompareImmediate(10, $FFFFFFFFFFFFFFFD);
  tw37554_CompareImmediate(11, $FFFFFFFFFFFFFFFB);
  tw37554_CompareImmediate(12, $FFFFFFFFFFFFFFF7);

  tw37554_CompareImmediate(13, $FFFFFFFFFFFFFFEF);
  tw37554_CompareImmediate(14, $FFFFFFFFFFFFFFDF);
  tw37554_CompareImmediate(15, $FFFFFFFFFFFFFFBF);
  tw37554_CompareImmediate(16, $FFFFFFFFFFFFFF7F);

  tw37554_CompareImmediate(17, $FFFFFFFFFFFFFEFF);
  tw37554_CompareImmediate(18, $FFFFFFFFFFFFFDFF);
  tw37554_CompareImmediate(19, $FFFFFFFFFFFFFBFF);
  tw37554_CompareImmediate(20, $FFFFFFFFFFFFF7FF);

  tw37554_CompareImmediate(21, $FFFFFFFFFFFFEFFF);
  tw37554_CompareImmediate(22, $FFFFFFFFFFFFDFFF);
  tw37554_CompareImmediate(23, $FFFFFFFFFFFFBFFF);
  tw37554_CompareImmediate(24, $FFFFFFFFFFFF7FFF);

  tw37554_CompareImmediate(25, $FFFFFFFFFFFEFFFF);
  tw37554_CompareImmediate(26, $FFFFFFFFFFFDFFFF);
  tw37554_CompareImmediate(27, $FFFFFFFFFFFBFFFF);
  tw37554_CompareImmediate(28, $FFFFFFFFFFF7FFFF);

  tw37554_CompareImmediate(29, $FFFFFFFFFFEFFFFF);
  tw37554_CompareImmediate(30, $FFFFFFFFFFDFFFFF);
  tw37554_CompareImmediate(31, $FFFFFFFFFFBFFFFF);
  tw37554_CompareImmediate(32, $FFFFFFFFFF7FFFFF);

  tw37554_CompareImmediate(33, $FFFFFFFFFEFFFFFF);
  tw37554_CompareImmediate(34, $FFFFFFFFFDFFFFFF);
  tw37554_CompareImmediate(35, $FFFFFFFFFBFFFFFF);
  tw37554_CompareImmediate(36, $FFFFFFFFF7FFFFFF);

  tw37554_CompareImmediate(37, $FFFFFFFFEFFFFFFF);
  tw37554_CompareImmediate(38, $FFFFFFFFDFFFFFFF);
  tw37554_CompareImmediate(39, $FFFFFFFFBFFFFFFF);
  tw37554_CompareImmediate(40, $FFFFFFFF7FFFFFFF);

  tw37554_CompareImmediate(41, $FFFFFFFEFFFFFFFF);
  tw37554_CompareImmediate(42, $FFFFFFFDFFFFFFFF);
  tw37554_CompareImmediate(43, $FFFFFFFBFFFFFFFF);
  tw37554_CompareImmediate(44, $FFFFFFF7FFFFFFFF);

  tw37554_CompareImmediate(45, $FFFFFFEFFFFFFFFF);
  tw37554_CompareImmediate(46, $FFFFFFDFFFFFFFFF);
  tw37554_CompareImmediate(47, $FFFFFFBFFFFFFFFF);
  tw37554_CompareImmediate(48, $FFFFFF7FFFFFFFFF);

  tw37554_CompareImmediate(49, $FFFFFEFFFFFFFFFF);
  tw37554_CompareImmediate(50, $FFFFFDFFFFFFFFFF);
  tw37554_CompareImmediate(51, $FFFFFBFFFFFFFFFF);
  tw37554_CompareImmediate(52, $FFFFF7FFFFFFFFFF);

  tw37554_CompareImmediate(53, $FFFFEFFFFFFFFFFF);
  tw37554_CompareImmediate(54, $FFFFDFFFFFFFFFFF);
  tw37554_CompareImmediate(55, $FFFFBFFFFFFFFFFF);
  tw37554_CompareImmediate(56, $FFFF7FFFFFFFFFFF);

  tw37554_CompareImmediate(57, $FFFEFFFFFFFFFFFF);
  tw37554_CompareImmediate(58, $FFFDFFFFFFFFFFFF);
  tw37554_CompareImmediate(59, $FFFBFFFFFFFFFFFF);
  tw37554_CompareImmediate(60, $FFF7FFFFFFFFFFFF);

  tw37554_CompareImmediate(61, $FFEFFFFFFFFFFFFF);
  tw37554_CompareImmediate(62, $FFDFFFFFFFFFFFFF);
  tw37554_CompareImmediate(63, $FFBFFFFFFFFFFFFF);
  tw37554_CompareImmediate(64, $FF7FFFFFFFFFFFFF);

  tw37554_CompareImmediate(65, $FEFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(66, $FDFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(67, $FBFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(68, $F7FFFFFFFFFFFFFF);

  tw37554_CompareImmediate(69, $EFFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(70, $DFFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(71, $BFFFFFFFFFFFFFFF);
  tw37554_CompareImmediate(72, $7FFFFFFFFFFFFFFF);

  tw37554_CompareImmediate(73, $FFFFFFFFFFFF1234);
  tw37554_CompareImmediate(74, $FFFFFFFF1234FFFF);
  tw37554_CompareImmediate(75, $FFFF1234FFFFFFFF);
  tw37554_CompareImmediate(76, $1234FFFFFFFFFFFF);

  tw37554_CompareImmediate(77, $FFFFFFFF12341234);
  tw37554_CompareImmediate(78, $FFFF1234FFFF1234);
  tw37554_CompareImmediate(79, $FFFF12341234FFFF);
  tw37554_CompareImmediate(80, $FFFF123412341234);

  tw37554_CompareImmediate(81, $FFFFFFFFFFFF0001);
  tw37554_CompareImmediate(82, $FFFFFFFF0001FFFF);
  tw37554_CompareImmediate(83, $FFFF0001FFFFFFFF);
  tw37554_CompareImmediate(84, $0001FFFFFFFFFFFF);

  tw37554_CompareImmediate(85, $0000000100000001);
  tw37554_CompareImmediate(86, $0000000500000005);
  tw37554_CompareImmediate(87, $0000AAAA0000AAAA);
  tw37554_CompareImmediate(88, $0000FFFF0000FFFF);

  { Spacing }
  WriteLn('');

  if tw37554_Fail then
    Halt(1)
  else
    WriteLn('ok');
end;
{$pop}

end.
