{ Consolidated booleans regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0688.pp }
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

{ Case tw1755.pp }
{$push}
var
  tw1755_err : boolean;


{$pop}

{ Case tw19622.pp }
{$push}
var
  tw19622_c:boolean;

{$pop}

{ Case tw22502.pp }
{$push}
var
  tw22502_b: Boolean;

{$pop}

{ Case tw25255.pp }
{$push}

{$pop}

{ Case tw25255b.pp }
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

{ Case tw2767.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2767 }
{ Submitted by "Jakub Cernohorsky" on  2003-11-06 }
{ e-mail: cernoj@fit.vutbr.cz }
var tw2767_a:integer;
    tw2767_err:boolean;

{$pop}

{ Case tw40936.pp }
{$push}
var
  tw40936_b: boolean;
  tw40936_w: word;


{$pop}

{ Case tw40974.pp }
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

{ Case tw8144.pp }
{$push}

function tw8144_DoCheck(tw8144_Key:WideChar):boolean;
begin
 tw8144_DoCheck:=(tw8144_Key in [WideChar(#0), WideChar(#8), WideChar(#10),
    WideChar(#13), WideChar(#27)
{$IFNDEF OS2}
{ OS/2 Unicode support uses #127 as replacement character for translation
  of characters which do not exist in the current system codepage. }
                                , WideChar(#127)
{$ENDIF OS2}
                                                ]);
end;

var
  tw8144_Key:WideChar;
  tw8144_err : boolean;

{$pop}

begin

{ Case tb0688.pp }
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

{ Case tw1755.pp }
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

{ Case tw19622.pp }
{$push}

Begin
    tw19622_c:=18446744073709551615>=9223372036854775807;
    if not(tw19622_c) then
      halt(1);
End;
{$pop}

{ Case tw22502.pp }
{$push}

begin
 tw22502_b:=true;
 tw22502_b := longbool(tw22502_b = tw22502_b);
 if not tw22502_b then
   halt(1);
end;
{$pop}

{ Case tw25255.pp }
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

{ Case tw25255b.pp }
{$push}

begin
  tw25255b_qb:=qwordbool($8000000000000000);
  tw25255b_lb:=longbool($80000000);
  tw25255b_wb:=wordbool($8000);
  tw25255b_p;
  writeln('ok');
end;
{$pop}

{ Case tw2767.pp }
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

{ Case tw40936.pp }
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

{ Case tw40974.pp }
{$push}

begin
	tw40974_Test(128);
	tw40974_Test(16384);
	if tw40974_anythingWrong then halt(1);
end;
{$pop}

{ Case tw8144.pp }
{$push}
{$IFNDEF OS2}
{$ENDIF OS2}
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

end.
