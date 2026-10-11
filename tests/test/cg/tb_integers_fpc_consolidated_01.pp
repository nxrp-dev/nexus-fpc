{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Preserve terminal exit-status assertions while allowing later cases to run. }
procedure CheckCaseExitCode(AValue: LongInt);
begin
  if AValue <> 0 then Halt(AValue);
end;

{ Case taddbyte.pp }
{$push}
{ Program to test Code generator secondadd()                 }
{ with Byte values                                       }
{ FUNCTIONAL PRE-REQUISITES:                                 }
{   - assignments function correctly.                        }
{   - if statements function correctly.                      }
{   - subroutine calls function correctly.                   }

procedure taddbyte_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


procedure taddbyte_ByteTestAdd;
var
 i: Byte;
 j: Byte;
 result : boolean;
begin
 Write('Byte + Byte test...');
 result := true;
 i:=0;
 j:=0;
 i := i + 100;
 if i <> 100 then
  result := false;
 j := 32;
 i := i + j;
 if i <> 132 then
  result := false;
 i := i + j + 50;
 if i <> 214 then
  result := false;
 i:=0;
 j:=10;
 i:= i + j + j + i + j;
 if i <> 30 then
  result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;


procedure taddbyte_ByteTestSub;
var
 i, j, k : Byte;
 result : boolean;
begin
 Write('Byte - Byte test...');
 result := true;
 i:=100;
 j:=4;
 k:=6;
 i:= i - 10;
 if i <> 90 then
  result := false;
 i := i - j - k - 11;
 if i <> 69 then
  result := false;
 i:=10;
 j:=100;
 k:=10;
 i:= j - i - k;
 if i <> 80 then
  result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;


procedure taddbyte_ByteTestMul;
var
 i : Byte;
 j : Byte;
 k: Byte;
 result: boolean;
begin
 Write('Byte * Byte test...');
 result := true;
 i:=0;
 j:=0;
 i:=i * 32;
 if i <> 0 then
   result := false;
 i:=10;
 i:=i * 16;
 if i <> 160 then
    result := false;
 j:=10;
 i:=10;
 i:=i * j;
 if i <> 100 then
    result := false;
 i:=1;
 j:=10;
 k:=16;
 i := i * j * k;
 if i <> 160 then
    result := false;
 i := 1;
 j := 2;
 k := 4;
 i := i * 2 * j * i * j * 4 * k;
 if i <> 128 then
    result := false;
 i := 50;
 j := 5;
 i := i * j;
 if i <> 250 then
   result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;

procedure taddbyte_ByteTestXor;
var
 i, j : Byte;
 result : boolean;
begin
 Write('Byte XOR Byte test...');
 result := true;
 i := 0;
 j := 0;
 i := i xor $11;
 if i <> $11 then
   result := false;
 i:=0;
 j:=$11;
 i:=i xor j;
 if i <> $11 then
   result := false;

 i := 0;
 j := $55;
 i := i xor j xor $AA;
 if i <> $FF then
   result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;


procedure taddbyte_ByteTestOr;
var
 i,j : Byte;
 result : boolean;
Begin
 Write('Byte OR Byte test...');
 result := true;
 i := 0;
 j := 0;
 i := i or $11;
 if i <> $11 then
   result := false;
 i:=0;
 j:=$11;
 i:=i or j;
 if i <> $11 then
   result := false;

 i := 0;
 j := $55;
 i := i or j or $AA;
 if i <> $FF then
   result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;



procedure taddbyte_ByteTestAnd;
var
 i,j : Byte;
 result : boolean;
Begin
 Write('Byte AND Byte test...');
 result := true;
 i := $11;
 j := 0;
 i := i and $11;
 if i <> $11 then
   result := false;
 i:=0;
 j:=$11;
 i:=i and j;
 if i <> 0 then
   result := false;

 i := $FF;
 j := $55;
 i := i and j;
 if i <> $55 then
   result := false;
 i := $FF;
 i := i and $AA;
 if i <> $AA then
   result := false;

 i := 0;
 j := $55;
 i := i and j and $AA;
 if i <> 0 then
   result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;

procedure taddbyte_ByteTestEqual;
var
 i,j : Byte;
 result : boolean;
Begin
 Write('Byte = Byte test...');
 result := true;
 i := $11;
 j := 0;
 if i = 0 then
   result := false;
 if i = j then
  result := false;
 if j = i then
  result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;


procedure taddbyte_ByteTestNotEqual;
var
 i,j : Byte;
 result : boolean;
Begin
 Write('Byte <> Byte test...');
 result := true;
 i := $11;
 j := $11;
 if i <> $11 then
   result := false;
 if i <> j then
  result := false;
 if j <> i then
  result := false;
 if not result then
  taddbyte_Fail
 else
  WriteLn('Success.');
end;

procedure taddbyte_ByteTestLE;
var
 i, j: Byte;
 result : boolean;
begin
{$ifndef tp}
 Write('Byte <= Byte test...');
 result := true;
 i := $FF;
 j := $FE;
 if i <= j then
   result := false;
 i := $FE;
 j := $F;
 if i <= j then
   result := false;
 i := $FF;
 if i <= $FE then
    result := false;
 j := $FF;
 if i <= j then
  begin
    if result then
      WriteLn('Success.')
    else
      taddbyte_Fail;
  end
 else
  taddbyte_Fail;
{$endif}
end;


procedure taddbyte_ByteTestGE;
var
 i, j: Byte;
 result : boolean;
begin
{$ifndef tp}
 Write('Byte >= Byte test...');
 result := true;
 i := $FE;
 j := $FF;
 if i >= j then
   result := false;
 i := $FE;
 j := $FF;
 if i > j then
   result := false;
 i := $FE;
 if i > $FE then
    result := false;
 i := $FF;
 j := $FF;
 if i >= j then
  begin
    if result then
      WriteLn('Success.')
    else
      taddbyte_Fail;
  end
 else
  taddbyte_Fail;
{$endif}
end;



{$pop}

{ Case taddint.pp }
{$push}
var
  taddint_b: byte;
  taddint_s: shortint;
  taddint_l: longint;
  taddint_c: cardinal;
  taddint_i: int64;

{$pop}

{ Case taddlong.pp }
{$push}
{ Program to test Code generator secondadd()                 }
{ with longint values                                        }
{ FUNCTIONAL PRE-REQUISITES:                                 }
{   - assignments function correctly.                        }
{   - if statements function correctly.                      }
{   - subroutine calls function correctly.                   }

{$R-}
{$Q-}

procedure taddlong_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


procedure taddlong_LongintTestAdd;
var
 i: longint;
 j: longint;
 result : boolean;
begin
 Write('Longint + Longint test...');
 result := true;
 i:=0;
 j:=0;
 i := i + -10000;
 if i <> -10000 then
  result := false;
 j := 32767;
 i := i + j;
 if i <> 22767 then
  result := false;
 i := i + j + 50000;
 if i <> 105534 then
  result := false;
 i:=0;
 j:=10000;
 i:= i + j + j + i + j;
 if i <> 30000 then
  result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;


procedure taddlong_LongintTestSub;
var
 i, j, k : longint;
 result : boolean;
begin
 Write('Longint - Longint test...');
 result := true;
 i:=100000;
 j:=54;
 k:=56;
 i:= i - 100;
 if i <> 99900 then
  result := false;
 i := i - j - k - 100;
 if i <> 99690 then
  result := false;
 i:=100;
 j:=1000;
 k:=100;
 i:= j - i - k;
 if i <> 800 then
  result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;


procedure taddlong_LongintTestMul;
var
 i : longint;
 j : longint;
 k: longint;
 result: boolean;
begin
 Write('Longint * Longint test...');
 result := true;
 i:=0;
 j:=0;
 i:=i * 32;
 if i <> 0 then
   result := false;
 i:=10;
 i:=i * -16;
 if i <> -160 then
    result := false;
 j:=10000;
 i:=-10000;
 i:=i * j;
 if i <> -100000000 then
    result := false;
 i:=1;
 j:=10;
 k:=16;
 i := i * j * k;
 if i <> 160 then
    result := false;
 i := 1;
 j := 10;
 k := 16;
 i := i * 10 * j * i * j * 16 * k;
 if i <> 256000 then
    result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;

procedure taddlong_LongintTestXor;
var
 i, j : Longint;
 result : boolean;
begin
 Write('Longint XOR Longint test...');
 result := true;
 i := 0;
 j := 0;
 i := i xor $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i xor j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i xor j xor $AAAAAAAA;
 if i <> longint($FFFFFFFF) then
   result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;


procedure taddlong_LongintTestOr;
var
 i,j : Longint;
 result : boolean;
Begin
 Write('Longint OR Longint test...');
 result := true;
 i := 0;
 j := 0;
 i := i or $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i or j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i or j or longint($AAAAAAAA);
 if i <> longint($FFFFFFFF) then
   result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;



procedure taddlong_LongintTestAnd;
var
 i,j : Longint;
 result : boolean;
Begin
 Write('Longint AND Longint test...');
 result := true;
 i := $1000001;
 j := 0;
 i := i and $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i and j;
 if i <> 0 then
   result := false;

 i := longint($FFFFFFFF);
 j := $55555555;
 i := i and j;
 if i <> $55555555 then
   result := false;
 i := longint($FFFFFFFF);
 i := i and longint($AAAAAAAA);
 if i <> longint($AAAAAAAA) then
   result := false;

 i := 0;
 j := $55555555;
 i := i and j and longint($AAAAAAAA);
 if i <> 0 then
   result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;

procedure taddlong_LongintTestEqual;
var
 i,j : Longint;
 result : boolean;
Begin
 Write('Longint = Longint test...');
 result := true;
 i := $1000001;
 j := 0;
 if i = 0 then
   result := false;
 if i = j then
  result := false;
 if j = i then
  result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;


procedure taddlong_LongintTestNotEqual;
var
 i,j : Longint;
 result : boolean;
Begin
 Write('Longint <> Longint test...');
 result := true;
 i := $1000001;
 j := $1000001;
 if i <> $1000001 then
   result := false;
 if i <> j then
  result := false;
 if j <> i then
  result := false;
 if not result then
  taddlong_Fail
 else
  WriteLn('Success.');
end;

procedure taddlong_LongintTestLE;
var
 i, j: Longint;
 result : boolean;
begin
 Write('Longint <= Longint test...');
 result := true;
 i := -1;
 j := -2;
 if i <= j then
   result := false;
 i := -2;
 j := $FFFF;
 if i >= j then
   result := false;
 i := longint($FFFFFFFF);
 if i <= longint($FFFFFFFE) then
    result := false;
 j := longint($FFFFFFFF);
 if i <= j then
  begin
    if result then
      WriteLn('Success.')
    else
      taddlong_Fail;
  end
 else
  taddlong_Fail;
end;


procedure taddlong_LongintTestGE;
var
 i, j: Longint;
 result : boolean;
begin
 Write('Longint >= Longint test...');
 result := true;
 i := longint($FFFFFFFE);
 j := longint($FFFFFFFF);
 if i >= j then
   result := false;
 i := longint($FFFFFFFE);
 j := longint($FFFFFFFF);
 if i > j then
   result := false;
 i := longint($FFFFFFFE);
 if i > longint($FFFFFFFE) then
    result := false;
 i := longint($FFFFFFFF);
 j := longint($FFFFFFFF);
 if i >= j then
  begin
    if result then
      WriteLn('Success.')
    else
      taddlong_Fail;
  end
 else
  taddlong_Fail;
end;




{$pop}

{ Case tadint64.pp }
{$push}
{ Program to test Code generator secondadd()                 }
{ with int64 values                                        }
{ FUNCTIONAL PRE-REQUISITES:                                 }
{   - assignments function correctly.                        }
{   - if statements function correctly.                      }
{   - subroutine calls function correctly.                   }

procedure tadint64_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


procedure tadint64_int64TestAdd;
var
 i: int64;
 j: int64;
 result : boolean;
begin
 Write('int64 + int64 test...');
 result := true;
 i:=0;
 j:=0;
 i := i + -10000;
 if i <> -10000 then
  result := false;
 j := 32767;
 i := i + j;
 if i <> 22767 then
  result := false;
 i := i + j + 50000;
 if i <> 105534 then
  result := false;
 i:=0;
 j:=10000;
 i:= i + j + j + i + j;
 if i <> 30000 then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_int64TestSub;
var
 i, j, k : int64;
 result : boolean;
begin
 Write('int64 - int64 test...');
 result := true;
 i:=100000;
 j:=54;
 k:=56;
 i:= i - 100;
 if i <> 99900 then
  result := false;
 i := i - j - k - 100;
 if i <> 99690 then
  result := false;
 i:=100;
 j:=1000;
 k:=100;
 i:= j - i - k;
 if i <> 800 then
  result := false;
 j := 900 - i;
 if (j <> 100) then
   result := false;

 i := 1000000000;
 k := i;
 i := i * 10;
 j := 1000000000 - i;
 k := k - i;
 if j <> k then
   result := false;
 if j <> (1000000000-(int64(1000000000) * 10)) then
   result := false;
 j := (int64(1) shl 33);
 i := (int64(1) shl 34) - j;
 if (i <> (int64(1) shl 33)) then
   result := false;

 i := 1 - j;
 if (i <> (1-(int64(1) shl 33))) then
   result := false;

 i := 100000;
 i := i - 90000;
 if (i <> 10000) then
   result := false;

 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_int64TestMul;
var
 i : int64;
 j : int64;
 k: int64;
 result: boolean;
begin
 Write('int64 * int64 test...');
 result := true;
 i:=0;
 j:=0;
 i:=i * 32;
 if i <> 0 then
   result := false;
 i:=10;
 i:=i * -16;
 if i <> -160 then
    result := false;
 j:=10000;
 i:=-10000;
 i:=i * j;
 if i <> -100000000 then
    result := false;
 i:=1;
 j:=10;
 k:=16;
 i := i * j * k;
 if i <> 160 then
    result := false;
 i := 1;
 j := 10;
 k := 16;
 i := i * 10 * j * i * j * 16 * k;
 if i <> 256000 then
    result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_int64TestXor;
var
 i, j : int64;
 result : boolean;
begin
 Write('int64 XOR int64 test...');
 result := true;
 i := 0;
 j := 0;
 i := i xor $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i xor j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i xor j xor $AAAAAAAA;
 if i <> $FFFFFFFF then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_int64TestOr;
var
 i,j : int64;
 result : boolean;
Begin
 Write('int64 OR int64 test...');
 result := true;
 i := 0;
 j := 0;
 i := i or $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i or j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i or j or $AAAAAAAA;
 if i <> $FFFFFFFF then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;



procedure tadint64_int64TestAnd;
var
 i,j : int64;
 result : boolean;
Begin
 Write('int64 AND int64 test...');
 result := true;
 i := $1000001;
 j := 0;
 i := i and $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i and j;
 if i <> 0 then
   result := false;

 i := $FFFFFFFF;
 j := $55555555;
 i := i and j;
 if i <> $55555555 then
   result := false;
 i := $FFFFFFFF;
 i := i and $AAAAAAAA;
 if i <> $AAAAAAAA then
   result := false;

 i := 0;
 j := $55555555;
 i := i and j and $AAAAAAAA;
 if i <> 0 then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_int64TestEqual;
var
 i,j : int64;
 result : boolean;
Begin
 Write('int64 = int64 test...');
 result := true;
 i := $1000001;
 j := 0;
 if i = 0 then
   result := false;
 if i = j then
  result := false;
 if j = i then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_int64TestNotEqual;
var
 i,j : int64;
 result : boolean;
Begin
 Write('int64 <> int64 test...');
 result := true;
 i := $1000001;
 j := $1000001;
 if i <> $1000001 then
   result := false;
 if i <> j then
  result := false;
 if j <> i then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_int64TestLE;
var
 i, j: int64;
 result : boolean;
begin
 Write('int64 <= int64 test...');
 result := true;
 i := -1;
 j := -2;
 if i <= j then
   result := false;
 i := -2;
 j := $FFFF;
 if i >= j then
   result := false;
 i := $FFFFFFFF;
 if i <= $FFFFFFFE then
    result := false;
 j := $FFFFFFFF;
 if i <= j then
  begin
    if result then
      WriteLn('Success.')
    else
      tadint64_Fail;
  end
 else
  tadint64_Fail;
end;


procedure tadint64_int64TestGE;
var
 i, j: int64;
 result : boolean;
begin
 Write('int64 >= int64 test...');
 result := true;
 i := $FFFFFFFE;
 j := $FFFFFFFF;
 if i >= j then
   result := false;
 i := $FFFFFFFE;
 j := $FFFFFFFF;
 if i > j then
   result := false;
 i := $FFFFFFFE;
 if i > $FFFFFFFE then
    result := false;
 i := $FFFFFFFF;
 j := $FFFFFFFF;
 if i >= j then
  begin
    if result then
      WriteLn('Success.')
    else
      tadint64_Fail;
  end
 else
  tadint64_Fail;
end;

{ QWord testing }
procedure tadint64_qwordTestAdd;
var
 i: qword;
 j: qword;
 result : boolean;
begin
 Write('qword + qword test...');
 result := true;
 i:=0;
 j:=0;
 i := i + 10000;
 if i <> 10000 then
  result := false;
 j := 32767;
 i := i + j;
 if i <> 42767 then
  result := false;
 i := i + j + 50000;
 if i <> 125534 then
  result := false;
 i:=0;
 j:=10000;
 i:= i + j + j + i + j;
 if i <> 30000 then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_QwordTestSub;
var
 i, j, k : qword;
 result : boolean;
begin
 Write('qword - qword test...');
 result := true;
 i:=100000;
 j:=54;
 k:=56;
 i:= i - 100;
 if i <> 99900 then
  result := false;
 i := i - j - k - 100;
 if i <> 99690 then
  result := false;
 i:=100;
 j:=1000;
 k:=100;
 i:= j - i - k;
 if i <> 800 then
  result := false;
 j := 900 - i;
 if (j <> 100) then
   result := false;

 i := 1000000000;
 k := i;
 i := i * 10;
 { The next statement would create an overflow }
 {$Q-}
 j := 1000000000 - i;
 k := k - i;
 if j <> k then
   result := false;

 { Since qword variable<>negative constant is always false according to the
   compiler (allowing it to optimize the if away) we need to do a preventive
   typecast to qword.}
 if j <> qword(1000000000-(qword(1000000000) * 10)) then
   result := false;
 j := (qword(1) shl 33);
 i := (qword(1) shl 34) - j;
 if (i <> (qword(1) shl 33)) then
   result := false;

 i := 1 - j;
 { Since qword variable<>negative constant is always false according to the
   compiler (allowing it to optimize the if away) we need to do a preventive
   typecast to qword.}
 if i <> qword(1-(qword(1) shl 33)) then
   result := false;

 i := 100000;
 i := i - 90000;
 if (i <> 10000) then
   result := false;

 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_QwordTestMul;
var
 i : qword;
 j : qword;
 k: qword;
 result: boolean;
begin
 Write('qword * qword test...');
 result := true;
 i:=0;
 j:=0;
 i:=i * 32;
 if i <> 0 then
   result := false;
 i:=10;
 i:=i * 16;
 if i <> 160 then
    result := false;
 j:=10000;
 i:=10000;
 i:=i * j;
 if i <> 100000000 then
    result := false;
 i:=1;
 j:=10;
 k:=16;
 i := i * j * k;
 if i <> 160 then
    result := false;
 i := 1;
 j := 10;
 k := 16;
 i := i * 10 * j * i * j * 16 * k;
 if i <> 256000 then
    result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_QwordTestXor;
var
 i, j : qword;
 result : boolean;
begin
 Write('qword XOR qword test...');
 result := true;
 i := 0;
 j := 0;
 i := i xor $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i xor j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i xor j xor $AAAAAAAA;
 if i <> $FFFFFFFF then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_QwordTestOr;
var
 i,j : qword;
 result : boolean;
Begin
 Write('qword OR qword test...');
 result := true;
 i := 0;
 j := 0;
 i := i or $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i or j;
 if i <> $10000001 then
   result := false;

 i := 0;
 j := $55555555;
 i := i or j or $AAAAAAAA;
 if i <> $FFFFFFFF then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;



procedure tadint64_QwordTestAnd;
var
 i,j : qword;
 result : boolean;
Begin
 Write('qword AND qword test...');
 result := true;
 i := $1000001;
 j := 0;
 i := i and $1000001;
 if i <> $1000001 then
   result := false;
 i:=0;
 j:=$10000001;
 i:=i and j;
 if i <> 0 then
   result := false;

 i := $FFFFFFFF;
 j := $55555555;
 i := i and j;
 if i <> $55555555 then
   result := false;
 i := $FFFFFFFF;
 i := i and $AAAAAAAA;
 if i <> $AAAAAAAA then
   result := false;

 i := 0;
 j := $55555555;
 i := i and j and $AAAAAAAA;
 if i <> 0 then
   result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_QwordTestEqual;
var
 i,j : qword;
 result : boolean;
Begin
 Write('qword = qword test...');
 result := true;
 i := $1000001;
 j := 0;
 if i = 0 then
   result := false;
 if i = j then
  result := false;
 if j = i then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;


procedure tadint64_QwordTestNotEqual;
var
 i,j : qword;
 result : boolean;
Begin
 Write('qword <> qword test...');
 result := true;
 i := $1000001;
 j := $1000001;
 if i <> $1000001 then
   result := false;
 if i <> j then
  result := false;
 if j <> i then
  result := false;
 if not result then
  tadint64_Fail
 else
  WriteLn('Success.');
end;

procedure tadint64_QwordTestLE;
var
 i, j: qword;
 result : boolean;
begin
 Write('qword <= qword test...');
 result := true;
 i := 1;
 j := 2;
 if j <= i then
   result := false;
 i := 2;
 j := $FFFF;
 if i >= j then
   result := false;
 i := $FFFFFFFF;
 if i <= $FFFFFFFE then
    result := false;
 j := $FFFFFFFF;
 if i <= j then
  begin
    if result then
      WriteLn('Success.')
    else
      tadint64_Fail;
  end
 else
  tadint64_Fail;
end;


procedure tadint64_QwordTestGE;
var
 i, j: qword;
 result : boolean;
begin
 Write('qword >= qword test...');
 result := true;
 i := $FFFFFFFE;
 j := $FFFFFFFF;
 if i >= j then
   result := false;
 i := $FFFFFFFE;
 j := $FFFFFFFF;
 if i > j then
   result := false;
 i := $FFFFFFFE;
 if i > $FFFFFFFE then
    result := false;
 i := $FFFFFFFF;
 j := $FFFFFFFF;
 if i >= j then
  begin
    if result then
      WriteLn('Success.')
    else
      tadint64_Fail;
  end
 else
  tadint64_Fail;
end;



{$pop}

{ Case tcnvint5.pp }
{$push}

{ This test requires overflow and range check to be off }
{$R-}
{$Q-}

var
  tcnvint5_error: boolean;

procedure tcnvint5_test;
var
  b: byte;
  l: longint;
begin
  b := 254;
  inc(b,2);
  l := b;
  if (l <> 0) then
    begin
      writeln('overflow error with byte');
      tcnvint5_error := true;
    end;

  b :=1;
  dec(b,2);
  l := b;
  if (l <> 255) then
    begin
      writeln('underflow error with byte');
      tcnvint5_error := true;
    end;
end;


procedure tcnvint5_test2;
var
  b: shortint;
  l: longint;
begin
  b := -127;
  dec(b,2);
  l := b;
  if (l <> 127) then
    begin
      writeln('neg error with shortint');
      tcnvint5_error := true;
    end;

  b := 126;
  inc(b,2);
  l := b;
  if (l <> -128) then
    begin
      writeln('pos error with shortint');
      tcnvint5_error := true;
    end;
end;


procedure tcnvint5_test3;
var
  b: longint;
  l: int64;
begin
  b := low(longint)+1;
  dec(b,2);
  l := b;
  if (l <> high(longint)) then
    begin
      writeln('neg error with shortint');
      tcnvint5_error := true;
    end;

  b := high(longint)-1;
  inc(b,2);
  l := b;
  if (l <> low(longint)) then
    begin
      writeln('pos error with shortint');
      tcnvint5_error := true;
    end;
end;


{$pop}

{ Case tcnvint7.pp }
{$push}
function tcnvint7_f: qword;
begin
  tcnvint7_f:=$7111888800000001;
end;


{$pop}

{ Case tformfnc.pp }
{$push}
function tformfnc_f: longint;
begin
  tformfnc_f := 1;
end;

procedure tformfnc_t(const c);
begin
end;


{$pop}

{ Case tmanypar.pp }
{$push}
procedure tmanypar_t(a,b,c,d,e,f,g,h,i,j,k,l: cardinal);
begin
  if (a <> $deadbeef) then
    halt(1);
  if (b <> $cafebabe) then
    halt(2);
  if (c <> $BeC0ffee) then
    halt(3);
  if (d <> $C001D00D) then
    halt(4);
  if (e <> $feeb1e) then
    halt(5);
  if (f <> cardinal($abba-$ceedee)) then
    halt(6);
  if (g <> $feedface) then
    halt(7);
  if (h <> $badfade5) then
    halt(8);
  if (i <> $deafb00b) then
    halt(9);
  if (j <> $badc0c0a) then
    halt(10);
  if (k <> $2badf001) then
    halt(11);
  if (l <> $defaced) then
    halt(12);
end;


procedure tmanypar_t2;
var
  a,b,c,d,e,f,g: longint;
begin
  a := 1;
  b := 2;
  c := 3;
  d := 4;
  e := 5;
  f := 6;
  g := 7;
  tmanypar_t($deadbeef,$cafebabe,$BeC0ffee,$C001D00D,$feeb1e,cardinal($abba-$ceedee),
    $feedface,$badfade5,$deafb00b,$badc0c0a,$2badf001,$defaced);
  if a<>1 then
    halt(13);
  if b<>2 then
    halt(14);
  if c<>3 then
    halt(15);
  if d<>4 then
    halt(16);
  if e<>5 then
    halt(17);
  if f<>6 then
    halt(18);
  if g<>7 then
    halt(19);
end;


{$pop}

{ Case tmoddiv1.pp }
{$push}
var tmoddiv1_j,tmoddiv1_k : integer;


{$pop}

{ Case tmul3264.pp }
{$push}
var
  tmul3264_gl: longint;
  tmul3264_gc: cardinal;

procedure tmul3264_testsigned;
var
  l1, l2: longint;
  b1: byte;
  i: int64;
begin

  l1 := longint($80000000);
  tmul3264_gl := longint($80000000);
  l2 := $11;
  b1 := $11;

  i := int64(l1)*l2;
  if (i <> int64($fffffff780000000)) then
    halt(1);

  i := int64(l1)*$11;
  if (i <> int64($fffffff780000000)) then
    halt(2);

  i := int64(tmul3264_gl)*$11;
  if (i <> int64($fffffff780000000)) then
    halt(3);

  i := int64(tmul3264_gl)*b1;
  if (i <> int64($fffffff780000000)) then
    halt(4);
end;


procedure tmul3264_testunsigned;
var
  l1, l2: cardinal;
  b1: byte;
  i: qword;
begin

  l1 := $80000000;
  l2 := $11;
  tmul3264_gc := $80000000;
  b1 := $11;

  i := qword(l1)*l2;
  if (i <> $880000000) then
    halt(5);

  i := qword(l1)*$11;
  if (i <> $880000000) then
    halt(6);

  i := qword(tmul3264_gc)*$11;
  if (i <> $880000000) then
    halt(7);

  i := qword(tmul3264_gc)*b1;
  if (i <> $880000000) then
    halt(8);
end;



{$pop}

{ Case tpara1.pp }
{$push}
function tpara1_f(l1,l2,l3,l4,l5,l6,l7,l8,l9:longint):longint;
begin
  tpara1_f:=l1+l2+l3+l4+l5+l6+l7+l8+l9;
end;

var
  tpara1_l : longint;

{$pop}

begin

{ Case taddbyte.pp }
{$push}
{$ifndef tp}
{$endif}
{$ifndef tp}
{$endif}
Begin
  { These should be tested first, since if they do not }
  { work, they will false all other results.           }
  taddbyte_ByteTestEqual;
  taddbyte_ByteTestNotEqual;
  taddbyte_ByteTestAdd;
  taddbyte_ByteTestMul;
  taddbyte_ByteTestOr;
  taddbyte_ByteTestAnd;
  taddbyte_ByteTestXor;
  taddbyte_ByteTestLe;
  taddbyte_ByteTestGe;
  taddbyte_ByteTestSub;
end;
{$pop}

{ Case taddint.pp }
{$push}

begin
  taddint_b:=10;
  taddint_s:=-128;
  taddint_l:=taddint_b or taddint_s;
  writeln(taddint_l);
  if (taddint_l<>-118) then
    halt(1);
  taddint_l:=taddint_b xor taddint_s;
  writeln(taddint_l);
  if (taddint_l<>-118) then
    halt(2);
  taddint_b:=129;
  taddint_s:=-127;
  taddint_l:=taddint_b and taddint_s;
  writeln(taddint_l);
  if (taddint_l<>129) then
    halt(3);
  taddint_l:=taddint_s and taddint_b;
  writeln(taddint_l);
  if (taddint_l<>129) then
    halt(4);

  taddint_l:=-127;
  taddint_c:=129;
  taddint_i:=taddint_l and taddint_c;
  writeln(taddint_i);
end;
{$pop}

{ Case taddlong.pp }
{$push}
{$R-}
{$Q-}
Begin
  { These should be tested first, since if they do not }
  { work, they will false all other results.           }
  taddlong_LongintTestEqual;
  taddlong_LongintTestNotEqual;
  taddlong_LongintTestAdd;
  taddlong_LongintTestMul;
  taddlong_LongintTestOr;
  taddlong_LongintTestAnd;
  taddlong_LongintTestXor;
  taddlong_LongintTestLe;
  taddlong_LongintTestGe;
  taddlong_LongintTestSub;
end;
{$pop}

{ Case tadint64.pp }
{$push}
{$Q-}
Begin
  { These should be tested first, since if they do not }
  { work, they will false all other results.           }
  tadint64_Int64TestEqual;
  tadint64_Int64TestNotEqual;
  tadint64_Int64TestAdd;
  tadint64_Int64TestMul;
  tadint64_Int64TestOr;
  tadint64_Int64TestAnd;
  tadint64_Int64TestXor;
  tadint64_Int64TestLe;
  tadint64_Int64TestGe;
  tadint64_Int64TestSub;
  tadint64_QwordTestEqual;
  tadint64_QwordTestNotEqual;
  tadint64_QwordTestAdd;
  tadint64_QwordTestMul;
  tadint64_QwordTestOr;
  tadint64_QwordTestAnd;
  tadint64_QwordTestXor;
  tadint64_QwordTestLe;
  tadint64_QwordTestGe;
  tadint64_QwordTestSub;
end;
{$pop}

{ Case tcnvint5.pp }
{$push}
{$R-}
{$Q-}
begin
  tcnvint5_error := false;
  tcnvint5_test;
  tcnvint5_test2;
  tcnvint5_test3;
  CheckCaseExitCode(ord(tcnvint5_error));
end;
{$pop}

{ Case tcnvint7.pp }
{$push}

begin
  if qword(cardinal(tcnvint7_f))<>1 then
    halt(1);
  if qword(longint(tcnvint7_f))<>1 then
    halt(2);
  if int64(cardinal(tcnvint7_f))<>1 then
    halt(3);
  if int64(longint(tcnvint7_f))<>1 then
    halt(4);
end;
{$pop}

{ Case tformfnc.pp }
{$push}

begin
  tformfnc_t(tformfnc_f);
end;
{$pop}

{ Case tmanypar.pp }
{$push}

begin
  tmanypar_t2;
end;
{$pop}

{ Case tmoddiv1.pp }
{$push}

begin
     tmoddiv1_k:=4;
     if (tmoddiv1_k div 1 <> 4) then
       halt(1);
     tmoddiv1_j := tmoddiv1_k div 1;
     writeln(tmoddiv1_k div 1, ' ',tmoddiv1_j);
     if (tmoddiv1_k div 1 <> 4) or
        (tmoddiv1_j <> 4)  then
       halt(1);
     if (tmoddiv1_k mod 1) <> 0 then
       halt(2);
end;
{$pop}

{ Case tmul3264.pp }
{$push}

begin
  tmul3264_testsigned;
  tmul3264_testunsigned;
end;
{$pop}

{ Case tpara1.pp }
{$push}

begin
  tpara1_l:=tpara1_f(tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9),tpara1_f(1,2,3,4,5,6,7,8,9));
  writeln('Got ',tpara1_l,' expected ',9*(1+2+3+4+5+6+7+8+9));
  if tpara1_l<>9*(1+2+3+4+5+6+7+8+9) then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
{$pop}

end.
