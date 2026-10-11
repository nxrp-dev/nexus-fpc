{ Consolidated arrays regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tarrconstr9.pp }
{$push}




var
  tarrconstr9_a: array[0..2] of integer;

{$pop}

{ Case tforin26.pp }
{$push}

Function tforin26_Write(Const Args: Array of const) : Integer;

Var
  V : TVarRec;
begin
  result:=0;
  For V in Args do
    begin
      if V.VType<>vtInteger then
        halt(1);
      inc(result);
    end;
end;


{$pop}

{ Case tforin27.pp }
{$push}

type
  tforin27_TIntegerDynArray = array of Integer;

Function tforin27_Write(Const Args: tforin27_TIntegerDynArray) : Integer;

function GetArgs : tforin27_TIntegerDynArray;
  begin
    GetArgs:=Args;
  end;

Var
  I : Integer;
begin
  result:=0;
  For I in GetArgs do
    begin
      inc(result,i);
      inc(result);
    end;
end;

var
  tforin27_IntegerDynArray : tforin27_TIntegerDynArray;


{$pop}

{ Case tslice1.pp }
{$push}


{$H+}

function tslice1_sumafter1(arr: Array of Integer): Integer;
var
  i: Integer;
begin
  Result:=0;
  for i in arr[1..High(arr)] do
    Result:=Result+i;
end;


{$pop}

{ Case tslice2.pp }
{$push}


{$H+}

type tslice2_TIntArray = array of Integer;
function tslice2_sumafter1(arr: tslice2_TIntArray): Integer;
var
  i: Integer;
begin
  Result:=0;
  for i in arr[1..High(arr)] do
    Result:=Result+i;
end;


{$pop}

begin

{ Case tarrconstr9.pp }
{$push}

begin
  tarrconstr9_a := [1,2,3];
end;
{$pop}

{ Case tforin26.pp }
{$push}

begin
  if tforin26_Write([1,2,3,4])<>4 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tforin27.pp }
{$push}

begin
  SetLength(tforin27_IntegerDynArray,4);
  if tforin27_Write(tforin27_IntegerDynArray)<>4 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tslice1.pp }
{$push}

{$H+}
begin
  if tslice1_sumafter1([1,2,3,4]) <> 2+3+4 then
    Halt(1);
  WriteLn('ok');
end;
{$pop}

{ Case tslice2.pp }
{$push}

{$H+}
begin
  if tslice2_sumafter1([1,2,3,4]) <> 2+3+4 then
    Halt(1);
  WriteLn('ok');
end;
{$pop}

end.
