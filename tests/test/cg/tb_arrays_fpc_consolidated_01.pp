{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tderef.pp }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondderef()                                    }
{****************************************************************}
{ PRE-REQUISITES: secondload()                                   }
{                 secondassign()                                 }
{                 secondcalln()                                  }
{                 secondadd()                                    }
{                 secondtypeconv()                               }
{****************************************************************}
{ DEFINES:                                                       }
{****************************************************************}
{ REMARKS:                                                       }
{****************************************************************}


type
  tderef_plongint = ^longint;
  tderef_ttestarray = array[1..64] of byte;
  tderef_ptestarray = ^tderef_ttestarray;
  tderef_pbyte = ^byte;


procedure tderef_fail;
begin
  Writeln('Failed!');
  halt(1);
end;


var
 tderef_pl : tderef_plongint;
 tderef_parray : tderef_ptestarray;
 tderef_passed : boolean;
 tderef_ptr : tderef_pbyte;
 tderef_b: byte;

{$pop}

{ Case tmoddiv3.pp }
{$push}


const
  tmoddiv3_TestValues: array[0..9] of LongWord = (500, 1, 0, 995, $7FFFFFFF, $80000000, $80000001, $80000002, $FFFFFFFF, 1000000);

const
  tmoddiv3_ExpectedResults: array[0..9,1..16] of LongWord = (
    (0,500,500,0,166,2,0,500,0,500,0,500,0,500,0,500),
    (0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,1),
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,995,995,0,331,2,0,995,0,995,0,995,0,995,0,995),
    (2147483,647,2147483647,0,715827882,1,524287,4095,1,0,0,2147483647,0,2147483647,0,2147483647),
    (2147483,648,2147483648,0,715827882,2,524288,0,1,1,1,0,0,2147483648,0,2147483648),
    (2147483,649,2147483649,0,715827883,0,524288,1,1,2,1,1,1,0,0,2147483649),
    (2147483,650,2147483650,0,715827883,1,524288,2,1,3,1,2,1,1,0,2147483650),
    (4294967,295,4294967295,0,1431655765,0,1048575,4095,2,1,1,2147483647,1,2147483646,1,0),
    (1000,0,1000000,0,333333,1,244,576,0,1000000,0,1000000,0,1000000,0,1000000));

var
  tmoddiv3_X, tmoddiv3_Y, tmoddiv3_C, tmoddiv3_Col: LongWord;

procedure tmoddiv3_DoCheck;
  begin
    if tmoddiv3_Y<>tmoddiv3_ExpectedResults[tmoddiv3_C,tmoddiv3_Col] then
      begin
        writeln('Error at ',tmoddiv3_C,' ',tmoddiv3_Col);
        halt(1);
      end;
    Inc(tmoddiv3_Col);
  end;


{$pop}

{ Case tmoddiv4.pp }
{$push}


const
  tmoddiv4_TestValues: array[0..10] of QWord = (500, 1, 0, 995, $100000000, $100000001, $7FFFFFFFFFFFFFFF, QWord($8000000000000000), QWord($8000000000000001), QWord($8000000000000002), 1000000);

  { Divisors are only for the error reporting }
  tmoddiv4_Divisors: array[0..8] of QWord = (1000, 1, 3, $1000, $7FFFFFFF, $80000000, $7FFFFFFFFFFFFFFF, QWord($8000000000000000), QWord($8000000000000001));

const
  tmoddiv4_ExpectedResults: array[0..10,1..18] of QWord = (
    (0,500,500,0,166,2,0,500,0,500,0,500,0,500,0,500,0,500),
    (0,1,1,0,0,1,0,1,0,1,0,1,0,1,0,1,0,1),
    (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0),
    (0,995,995,0,331,2,0,995,0,995,0,995,0,995,0,995,0,995),
    (4294967,296,4294967296,0,1431655765,1,1048576,0,2,2,2,0,0,4294967296,0,4294967296,0,4294967296),
    (4294967,297,4294967297,0,1431655765,2,1048576,1,2,3,2,1,0,4294967297,0,4294967297,0,4294967297),
    (9223372036854775,807,9223372036854775807,0,3074457345618258602,1,2251799813685247,4095,4294967298,1,4294967295,2147483647,1,0,0,$7FFFFFFFFFFFFFFF,0,$7FFFFFFFFFFFFFFF),
    (9223372036854775,808,9223372036854775808,0,3074457345618258602,2,2251799813685248,0,4294967298,2,4294967296,0,1,1,1,0,0,QWord($8000000000000000)),
    (9223372036854775,809,9223372036854775809,0,3074457345618258603,0,2251799813685248,1,4294967298,3,4294967296,1,1,2,1,1,1,0),
    (9223372036854775,810,9223372036854775810,0,3074457345618258603,1,2251799813685248,2,4294967298,4,4294967296,2,1,3,1,2,1,1),
    (1000,0,1000000,0,333333,1,244,576,0,1000000,0,1000000,0,1000000,0,1000000,0,1000000));

var
  tmoddiv4_X, tmoddiv4_Y: QWord;
  tmoddiv4_C, tmoddiv4_Col: LongWord;

procedure tmoddiv4_DoCheck;
  begin
    if tmoddiv4_Y<>tmoddiv4_ExpectedResults[tmoddiv4_C,tmoddiv4_Col] then
      begin
        Write(#10'Error at ', tmoddiv4_C, ',', tmoddiv4_Col, ' - ', tmoddiv4_TestValues[tmoddiv4_C]);
        if (tmoddiv4_Col and $1) = 0 then
          Write(' mod ')
        else
          Write(' div ');
        WriteLn(tmoddiv4_Divisors[(tmoddiv4_Col - 1) shr 1], ' - expected ', tmoddiv4_ExpectedResults[tmoddiv4_C,tmoddiv4_Col], ' got ', tmoddiv4_Y);
        halt(1);
      end;
    Inc(tmoddiv4_Col);
  end;


{$pop}

{ Case tvec64cmp.pp }
{$push}
{ Small test to check correct handling of
  comparison of 64-bit values as boolean
  index of a vector, which lead
  to internal error for riscv32 cpu
  after commit #c83e6c34 }

const
  tvec64cmp_error_count : longint = 0;

procedure tvec64cmp_error(v : integer);
begin
  writeln('Error ',v);
  inc(tvec64cmp_error_count);
end;

const
  tvec64cmp_test_counter : longint = 0;

procedure tvec64cmp_check(b1,b2 : boolean);
begin
  inc(tvec64cmp_test_counter);
  if (b1<>b2) then
    tvec64cmp_error(tvec64cmp_test_counter);
end;

const
  tvec64cmp_Res : array[boolean] of boolean = (False,True);

var
  tvec64cmp_A,tvec64cmp_B : Int64;
  tvec64cmp_UA,tvec64cmp_UB : Qword;



{$pop}

begin

{ Case tderef.pp }
{$push}

Begin
 Write('secondderef() test...');
 tderef_passed := true;
 new(tderef_pl);
 new(tderef_parray);
 { left : LOC_REFERENCE }
 tderef_pl^:= $F0F0;
 if tderef_pl^ <> $F0F0 then
   tderef_passed := false;
 FillChar(tderef_parray^,sizeof(tderef_ttestarray),0);
 tderef_ptr:=tderef_pbyte((ptrint(tderef_parray)+32));
 tderef_ptr^ := $A0;
 if tderef_parray^[33] <> $A0 then
   tderef_passed := false;
 { left : LOC_REGISTER }
 tderef_b:=(tderef_pbyte((ptrint(tderef_parray)+32))^);
 if tderef_b <> $A0 then
  tderef_passed := false;
 dispose(tderef_pl);
 dispose(tderef_parray);
 if tderef_passed then
   WriteLn('Success.')
 else
   tderef_Fail;
end;
{$pop}

{ Case tmoddiv3.pp }
{$push}

begin
  for tmoddiv3_C := Low(tmoddiv3_TestValues) to High(tmoddiv3_TestValues) do
  begin
    tmoddiv3_X := tmoddiv3_TestValues[tmoddiv3_C];
    tmoddiv3_Col := 1;

    tmoddiv3_Y := tmoddiv3_X div 1000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod 1000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div 1;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod 1;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div 3;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod 3;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div $1000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod $1000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div $7FFFFFFF;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod $7FFFFFFF;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div $80000000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod $80000000;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div $80000001;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod $80000001;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X div $FFFFFFFF;
    Write(tmoddiv3_Y,',');
    tmoddiv3_DoCheck;

    tmoddiv3_Y := tmoddiv3_X mod $FFFFFFFF;
    Writeln(tmoddiv3_Y);
    tmoddiv3_DoCheck;
  end;
  writeln('ok');
end;
{$pop}

{ Case tmoddiv4.pp }
{$push}

begin
  for tmoddiv4_C := Low(tmoddiv4_TestValues) to High(tmoddiv4_TestValues) do
  begin
    tmoddiv4_X := tmoddiv4_TestValues[tmoddiv4_C];
    tmoddiv4_Col := 1;
    tmoddiv4_Y := QWord(tmoddiv4_X) div 1000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod 1000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div 1;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod 1;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div 3;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod 3;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div $1000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod $1000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div $7FFFFFFF;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod $7FFFFFFF;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div $80000000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod $80000000;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div $7FFFFFFFFFFFFFFF;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod $7FFFFFFFFFFFFFFF;
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    { Constants this large default to being made into Int64's, so typecast them }
    tmoddiv4_Y := QWord(tmoddiv4_X) div QWord($8000000000000000);
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod QWord($8000000000000000);
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) div QWord($8000000000000001);
    Write(tmoddiv4_Y,',');
    tmoddiv4_DoCheck;

    tmoddiv4_Y := QWord(tmoddiv4_X) mod QWord($8000000000000001);
    Writeln(tmoddiv4_Y);
    tmoddiv4_DoCheck;
  end;
  writeln('ok');
end;
{$pop}

{ Case tvec64cmp.pp }
{$push}

begin
  tvec64cmp_A:=1;
  tvec64cmp_B:=-1;
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A>tvec64cmp_B],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<=tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A>=tvec64cmp_B],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A=tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<>tvec64cmp_B],true);
  tvec64cmp_A:=$123456789;
  tvec64cmp_B:=-$ABCDEF12345;
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A>tvec64cmp_B],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<=tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A>=tvec64cmp_B],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A=tvec64cmp_B],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_A<>tvec64cmp_B],true);

  tvec64cmp_UA:=qword(1 shl 63) + qword(1 shl 36) + qword(1 shl 9);
  tvec64cmp_UB:=1;
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA<tvec64cmp_UB],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA>tvec64cmp_UB],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA<=tvec64cmp_UB],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA>=tvec64cmp_UB],true);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA=tvec64cmp_UB],false);
  tvec64cmp_check(tvec64cmp_Res[tvec64cmp_UA<>tvec64cmp_UB],true);

  if (tvec64cmp_error_count>0) then
    begin
      writeln('The test generated ',tvec64cmp_error_count,' failures');
      halt(1);
    end
  else
    writeln('Test completed without error');
end;
{$pop}

end.
