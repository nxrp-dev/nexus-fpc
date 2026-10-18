{ Consolidated booleans regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb_booleans_fpc_consolidated_01.pas }
{$push}
{ Consolidated booleans regressions; original case IDs and assertions are retained. }



{ Case tb0688.pas }
{$push}


function tb0688_Test(var aArg: QWordBool): LongInt;
begin
  tb0688_Test := LongInt(aArg);
end;

function tb0688_Test(var aArg: Boolean64): LongInt;
begin
  tb0688_Test := LongInt(aArg);
end;

var
  tb0688_b64: Boolean64;
  tb0688_qb: QWordBool;

{$pop}

{ Case tw1755.pas }
{$push}
var
  tw1755_err : boolean;


{$pop}

{ Case tw19622.pas }
{$push}
var
  tw19622_c:boolean;

{$pop}

{ Case tw22502.pas }
{$push}
var
  tw22502_b: Boolean;

{$pop}

{ Case tw25255.pas }
{$push}

{$pop}

{ Case tw25255b.pas }
{$push}
var
  tw25255b_qb : qwordbool;
  tw25255b_lb : longbool;
  tw25255b_wb : wordbool;
procedure tw25255b_p;
begin
  if not(tw25255b_qb) then
    halt(1);
  if not(tw25255b_lb) then
    halt(1);
  if not(tw25255b_wb) then
    halt(1);
end;


{$pop}

{ Case tw2767.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2767 }
{ Submitted by "Jakub Cernohorsky" on  2003-11-06 }
{ e-mail: cernoj@fit.vutbr.cz }
var tw2767_a:integer;
    tw2767_err:boolean;

{$pop}

{ Case tw40936.pas }
{$push}
var
  tw40936_b: boolean;
  tw40936_w: word;


{$pop}

{ Case tw40974.pas }
{$push}
var
	tw40974_anythingWrong: boolean = false;

	procedure tw40974_Test(size: SizeUint);
	var
		p: pointer;
		memSizeResult, freeMemResult: SizeUint;
	begin
		p := GetMem(size);
		memSizeResult := MemSize(p);
		freeMemResult := FreeMem(p);
		if memSizeResult <> freeMemResult then
		begin
			writeln('GetMem(', size, '): MemSize returned ', memSizeResult, ', FreeMem returned ', freeMemResult, '.');
			tw40974_anythingWrong := true;
		end;
	end;


{$pop}

{ Case tw8144.pas }
{$push}

function tw8144_DoCheck(tw8144_Key:WideChar):boolean;
begin
 tw8144_DoCheck:=(tw8144_Key in [WideChar(#0), WideChar(#8), WideChar(#10),
    WideChar(#13), WideChar(#27)
                                , WideChar(#127)
                                                ]);
end;

var
  tw8144_Key:WideChar;
  tw8144_err : boolean;

{$pop}


{$pop}

{ Case taddreal3.pas }
{$push}
{****************************************************************}
{  CODE GENERATOR TEST PROGRAM                                   }
{****************************************************************}
{ NODE TESTED : secondadd() FPU cextended type code              }
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
procedure taddreal3_fail;
begin
  WriteLn('Failed!');
  halt(1);
end;


 Procedure taddreal3_RealTestSub;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 Begin
  Write('cextended - cextended test...');
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
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal3_RealTestAdd;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 Begin
   WriteLn('cextended + cextended test...');
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
    taddreal3_Fail
   else
    WriteLn('Success.');
 end;


 procedure taddreal3_realtestmul;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 begin
  WriteLn('cextended * cextended test...');
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
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;



 Procedure taddreal3_RealTestDiv;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 Begin
  result := true;
  WriteLn('cextended / cextended test...');
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
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;



{ Procedure RealTestComplex;
 var
  i : cextended;
 Begin
   Write('RESULT SHOULD BE 2.09 :');
   i := 4.4;
   WriteLn(Sqrt(i));
   Write('RESULT SHOULD BE PI :');
   WriteLn(Pi);
   Write('RESULT SHOULD BE 4.0 :');
   WriteLn(Round(3.6));
 end;}


 procedure taddreal3_realtestequal;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 begin
  result := true;
  Write('cextended = cextended test...');
  i := 1000.0;
  j := 1000.0;
  if not (trunc(i) = trunc(j)) then
    result := false;
  if not (trunc(i) = trunc(1000.0)) then
    result := false;
  if not result then
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal3_realtestnotequal;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 begin
  result := true;
  Write('cextended <> cextended test...');
  i := 1000.0;
  j := 1000.0;
  if (trunc(i) <> trunc(j)) then
    result := false;
  if (trunc(i) <> trunc(1000.0)) then
    result := false;
  if not result then
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;


 procedure taddreal3_realtestle;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 begin
  result := true;
  Write('cextended <= cextended test...');
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
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;

 procedure taddreal3_realtestge;
 var
  i : cextended;
  j : cextended;
  result : boolean;
 begin
  result := true;
  Write('cextended >= cextended test...');
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
    taddreal3_Fail
  else
    WriteLn('Success.');
 end;



{$pop}

{ Case tcaseopt1.pas }
{$push}
Procedure tcaseopt1_TestCaseBool;
Var
  L1, L2: LongWord;
  b : boolean;
begin
  b:=false;

  l1:=$deadbeef;
  case b of
    true:
      l1:=0;
    else
      l1:=1234;
  end;
  if l1<>1234 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false:
      l1:=1234;
    else
      l1:=0;
  end;
  if l1<>1234 then
    halt(1);

  l1:=$deadbeef;
  case b of
    true:
      l1:=0;
    false:
      l1:=1234;
  end;
  if l1<>1234 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false..true:
      l1:=1234;
    else
      l1:=0;
  end;
  if l1<>1234 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false..true:
      l1:=1234;
  end;
  if l1<>1234 then
    halt(1);


  { set b to true }
  b:=true;

  l1:=$deadbeef;
  case b of
    true:
      l1:=0;
    else
      l1:=1234;
  end;
  if l1<>0 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false:
      l1:=1234;
    else
      l1:=0;
  end;
  if l1<>0 then
    halt(1);

  l1:=$deadbeef;
  case b of
    true:
      l1:=0;
    false:
      l1:=1234;
  end;
  if l1<>0 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false..true:
      l1:=1234;
    else
      l1:=0;
  end;
  if l1<>1234 then
    halt(1);

  l1:=$deadbeef;
  case b of
    false..true:
      l1:=1234;
  end;
  if l1<>1234 then
    halt(1);
end;


{$pop}

{ Case tandorandnot1.pas }
{$push}
{ test (a and b) or (c and not(b)) into c xor ((c xor a) and b) optimization with random values }
procedure tandorandnot1_test_word;
  var
    i,a,b,c,_a,_b,_c : word;
  begin
    for i:=1 to 1000 do
      begin
        a:=random(65536);
        _a:=a;
        b:=random(65536);
        _b:=b;
        c:=random(65536);
        _c:=c;
        if (a and b) or (c and not(b))<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(1);
          end;
        if (a and b) or (not(b) and c)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(1);
          end;
        if (not(b) and c) or (a and b)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(1);
          end;
        if (not(b) and c) or (b and a)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(1);
          end;
      end;
  end;

procedure tandorandnot1_test_boolean;
  var
    i : word;
    a,b,c,_a,_b,_c : boolean;
  begin
    for i:=1 to 100 do
      begin
        a:=boolean(random(2));
        _a:=a;
        b:=boolean(random(2));
        _b:=b;
        c:=boolean(random(2));
        _c:=c;
        if (a and b) or (c and not(b))<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(11);
          end;
        if (a and b) or (not(b) and c)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(11);
          end;
        if (not(b) and c) or (a and b)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(11);
          end;
        if (not(b) and c) or (b and a)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a,'b=',b,'c=',c);
            halt(11);
          end;
      end;
  end;


procedure tandorandnot1_test_pboolean;
  var
    i : word;
    a,b,c : pboolean;
    _a,_b,_c : boolean;
  begin
    new(a);
    new(b);
    for i:=1 to 100 do
      begin
        a^:=true;
        _a:=a^;
        b^:=true;
        _b:=b^;
        c:=nil;
        { c should not matter in this case }
        _c:=boolean(random(2));
        if (a^ and b^) or (c^ and not(b^))<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a^,'b=',b^,'c=',c^);
            halt(21);
          end;
        if (a^ and b^) or (not(b^) and c^)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a^,'b=',b^,'c=',c^);
            halt(21);
          end;
        if (not(b^) and c^) or (a^ and b^)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a^,'b=',b^,'c=',c^);
            halt(21);
          end;
        if (not(b^) and c^) or (b^ and a^)<>_c xor ((_c xor _a) and _b) then
          begin
            writeln('Error: ','a=',a^,'b=',b^,'c=',c^);
            halt(21);
          end;
      end;
    dispose(a);
    dispose(b);
  end;



{$pop}

{ Case tassert1.pas }
{$push}
{$C+}


var
 tassert1_global_boolean : boolean;

const
  tassert1_RESULT_BOOLEAN = true;

function tassert1_get_boolean : boolean;
 begin
   tassert1_get_boolean := tassert1_RESULT_BOOLEAN;
 end;

procedure tassert1_test_assert_reference_global;
 begin
  tassert1_global_boolean:=tassert1_RESULT_BOOLEAN;
  assert(tassert1_global_boolean);
 end;

procedure tassert1_test_assert_reference_local;
 var
  b: boolean;
 begin
  b:=tassert1_RESULT_BOOLEAN;
  assert(b);
 end;


procedure tassert1_test_assert_register;
 var
  b: boolean;
 begin
  assert(tassert1_get_boolean);
 end;

procedure tassert1_test_assert_flags;
 var
  b: boolean;
  i,j : integer;
 begin
  i:=0;
  j:=-12;
  assert(i > j);
 end;

procedure tassert1_test_assert_constant;
  begin
    assert(tassert1_RESULT_BOOLEAN);
  end;




{$pop}

{ Case todd.pas }
{$push}
{ Part of System unit testsuit        }
{ Carl Eric Codere Copyright (c) 2002 }


const
  todd_RESULT_ONE = FALSE;
  todd_VALUE_ONE = -65536;
  todd_RESULT_CONST_ONE = odd(todd_VALUE_ONE);
  todd_RESULT_TWO = TRUE;
  todd_VALUE_TWO = 12345;
  todd_RESULT_CONST_TWO = odd(todd_VALUE_TWO);


procedure todd_fail;
 begin
  WriteLn('Failure!');
  halt(1);
 end;

var
 todd_r: longint;
 todd__success : boolean;
 todd_l: boolean;

{$pop}

begin

{ Case tb_booleans_fpc_consolidated_01.pas }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin

{ Case tb0688.pas }
{$push}

begin
  tb0688_b64 := True;
  if tb0688_Test(tb0688_b64) <> 1 then
    Halt(1);
  tb0688_b64 := False;
  if tb0688_Test(tb0688_b64) <> 0 then
    Halt(2);
  tb0688_qb := True;
  if tb0688_Test(tb0688_qb) <> -1 then
    Halt(3);
  tb0688_qb := False;
  if tb0688_Test(tb0688_qb) <> 0 then
    Halt(4);
  tb0688_qb := QWordBool($12341234);
  if tb0688_Test(tb0688_qb) <> $12341234 then
    Halt(5);
  tb0688_qb := QWordBool($100000000);
  if tb0688_Test(tb0688_qb) <> 0 then
    Halt(6);
end;
{$pop}

{ Case tw1755.pas }
{$push}

begin
  tw1755_err:=false;

  write('assigned(nil): ');
  if assigned(nil) then
   tw1755_err:=true
  else
   writeln('nil');
  write('assigned(pointer(0)): ');
  if assigned(pointer(0)) then
   tw1755_err:=true
  else
   writeln('nil');
  write('assigned(pointer(10000)): ');
  if assigned(pointer(10000)) then
   writeln('assigned')
  else
   tw1755_err:=true;

  if tw1755_err then
   begin
     writeln('err');
     halt(1);
   end;

end;
{$pop}

{ Case tw19622.pas }
{$push}

Begin
    tw19622_c:=18446744073709551615>=9223372036854775807;
    if not(tw19622_c) then
      halt(1);
End;
{$pop}

{ Case tw22502.pas }
{$push}

begin
 tw22502_b:=true;
 tw22502_b := longbool(tw22502_b = tw22502_b);
 if not tw22502_b then
   halt(1);
end;
{$pop}

{ Case tw25255.pas }
{$push}

begin
  if not(qwordbool($8000000000000000)) then
    halt(1);
  if not(longbool($80000000)) then
    halt(1);
  if not(wordbool($8000)) then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw25255b.pas }
{$push}

begin
  tw25255b_qb:=qwordbool($8000000000000000);
  tw25255b_lb:=longbool($80000000);
  tw25255b_wb:=wordbool($8000);
  tw25255b_p;
  writeln('ok');
end;
{$pop}

{ Case tw2767.pas }
{$push}

begin
  tw2767_a:=25;
  case tw2767_a of
    -10..0:writeln('-10..0');
    31:writeln('31');
    32..38:begin
             writeln('32-38');
             tw2767_err:=true;
           end;
    66:writeln('66');
  end;
  if tw2767_err then
    halt(1);
end;
{$pop}

{ Case tw40936.pas }
{$push}

begin
  tw40936_w := $2;
  tw40936_b := (tw40936_w shr 1) <> 0;
  tw40936_w := tw40936_w shl 1; // project1.lpr(7,3) Error: Asm: 16 or 32 bit references not supported
  if tw40936_b then tw40936_w := tw40936_w xor 1;
  if tw40936_w<>5 then
    halt(1);
end;
{$pop}

{ Case tw40974.pas }
{$push}

begin
	tw40974_Test(128);
	tw40974_Test(16384);
	if tw40974_anythingWrong then halt(1);
end;
{$pop}

{ Case tw8144.pas }
{$push}
begin
  for tw8144_Key:=WideChar(128) to WideChar(2048) do
   if tw8144_DoCheck(tw8144_Key) then
    begin
     writeln(word(tw8144_Key),' (',tw8144_Key,') in set');
     tw8144_err:=true;
    end;
  if tw8144_err then halt(1);
end;
{$pop}

end;
{$pop}

{ Case taddreal3.pas }
{$push}

Begin
 taddreal3_RealTestEqual;
 taddreal3_RealTestNotEqual;
 taddreal3_RealTestLE;
 taddreal3_RealTestGE;
 taddreal3_RealTestSub;
 taddreal3_RealTestAdd;
 taddreal3_RealTestDiv;
 taddreal3_RealTestMul;
{ RealTestComplex;}
end;
{$pop}

{ Case tcaseopt1.pas }
{$push}

begin
  tcaseopt1_TestCaseBool;
  writeln('ok');
end;
{$pop}

{ Case tandorandnot1.pas }
{$push}

begin
  tandorandnot1_test_word;
  tandorandnot1_test_boolean;
  tandorandnot1_test_pboolean;
end;
{$pop}

{ Case tassert1.pas }
{$push}
{$C+}
begin
  Write('Assert test (TRUE)...');
  tassert1_test_assert_reference_global;
  tassert1_test_assert_reference_local;
  tassert1_test_assert_register;
  tassert1_test_assert_flags;
  tassert1_test_assert_constant;
  WriteLn('Success!');
end;
{$pop}

{ Case todd.pas }
{$push}

Begin
 Write('Odd() testing...');
 todd__success := true;
 todd_r:=todd_VALUE_ONE;
 if odd(todd_r)<>todd_RESULT_ONE then
   todd__success:=false;
 if odd(todd_VALUE_ONE)<>todd_RESULT_ONE then
   todd__success:=false;
 todd_r:=todd_VALUE_ONE;
 if odd(todd_r)<>todd_RESULT_CONST_ONE then
   todd__success := false;
 todd_r:=todd_VALUE_ONE;
 todd_l:=odd(todd_r);
 if todd_l<>todd_RESULT_ONE then
   todd__success:=false;
 todd_l:=odd(todd_VALUE_ONE);
 if todd_l<>todd_RESULT_ONE then
   todd__success:=false;


 todd_r:=todd_VALUE_TWO;
 if odd(todd_r)<>todd_RESULT_TWO then
   todd__success:=false;
 if odd(todd_VALUE_TWO)<>todd_RESULT_TWO then
   todd__success:=false;
 todd_r:=todd_VALUE_TWO;
 if odd(todd_r)<>todd_RESULT_CONST_TWO then
   todd__success := false;
 todd_r:=todd_VALUE_TWO;
 todd_l:=odd(todd_r);
 if todd_l<>todd_RESULT_TWO then
   todd__success:=false;
 todd_l:=odd(todd_VALUE_TWO);
 if todd_l<>todd_RESULT_TWO then
   todd__success:=false;


 if not todd__success then
   todd_fail;
 WriteLn('Success!');
end;
{$pop}

end.
