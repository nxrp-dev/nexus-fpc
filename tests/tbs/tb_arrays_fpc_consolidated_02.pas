{ Consolidated arrays regressions; original case IDs and assertions are retained. }
{ %OPT=-O2 }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw13948b.pas }
{$push}


type
  tw13948b_tr = array[0..1] of longint;

function tw13948b_f: tw13948b_tr;
begin
  tw13948b_f[0]:=5;
  tw13948b_f[1]:=6;
end;

procedure tw13948b_test;
var
  r: tw13948b_tr;
begin
  r[0]:=1;
  r[1]:=2;
  r[0]:=tw13948b_f[0];
  writeln(r[0]);
  writeln(r[1]);
  if (r[0]<>5) then
    halt(1);
  if (r[1]<>2) then
    halt(2);
  r[0]:=tw13948b_f[1];
  writeln(r[0]);
  writeln(r[1]);
  if (r[0]<>6) then
    halt(1);
  if (r[1]<>2) then
    halt(2);
end;


{$pop}

{ Case tw1932.pas }
{$push}

{ Source provided for Free Pascal Bug Report 1932 }
{ Submitted by "Rob Kolstad" on  2002-04-15 }
{ e-mail: kolstad@ace.delos.com }

var
    tw1932_i, tw1932_ans:longint;
    tw1932_data:array[1..2,0..1] of longint;

{$pop}

{ Case tw39646.pas }
{$push}



function tw39646_NestedDivWithAnd(const num: UInt64): Integer;
  begin
    tw39646_NestedDivWithAnd := (num div 100000000) and $FF;
  end;

function tw39646_NestedModWithAnd(const num: UInt64): Integer;
  begin
    tw39646_NestedModWithAnd := (num mod 100000000) and $FF;
  end;

const
  tw39646_Input:     array[0..5] of UInt64  = (0, 1, 100000001, 4000000385, 5000000006, 25700000385);
  tw39646_ExpectedD: array[0..5] of Integer = (0, 0, 1,         40,         50,         1);
  tw39646_ExpectedM: array[0..5] of Integer = (0, 1, 1,         129,        6,          129);
var
  tw39646_Failed: Boolean;
  tw39646_X, tw39646_Output: Integer;

{$pop}

begin

{ Case tw13948b.pas }
{$push}

begin
  tw13948b_test;
end;
{$pop}

{ Case tw1932.pas }
{$push}

begin
    tw1932_data[1,0] := 2; tw1932_data[1,1] := 7;
    tw1932_data[2,0] := 6; tw1932_data[2,1] := 9;
    tw1932_i:= 1;
    tw1932_ans := 0;
    writeln ('calculated diff = ',tw1932_data[tw1932_i,1]-tw1932_data[tw1932_i+1,0]);
    if tw1932_data[tw1932_i,1]>tw1932_data[tw1932_i+1,0] then begin
        tw1932_ans := tw1932_data[tw1932_i,1]-tw1932_data[tw1932_i+1,0];
        // I think that data[i+1,0] is being evaluated to 0...RK
    end;
    // ans should be 1
    writeln('ans should = 1, but ans=', tw1932_ans);
    if tw1932_ans <> 1 then
      halt(1);
end;
{$pop}

{ Case tw39646.pas }
{$push}

begin
  WriteLn('Testing "(UInt64 div 100000000) and $FF" with implicit typecast to Integer:');
  tw39646_Failed := False;
  for tw39646_X := Low(tw39646_Input) to High(tw39646_Input) do
    begin
      Write('- Input = ', tw39646_Input[tw39646_X], ' ... ');
      tw39646_Output := tw39646_NestedDivWithAnd(tw39646_Input[tw39646_X]);
      if tw39646_Output = tw39646_ExpectedD[tw39646_X] then
        WriteLn('Passed')
      else
        begin
          WriteLn('FAILED! Got ', tw39646_Output, ', expected ', tw39646_ExpectedD[tw39646_X]);
          tw39646_Failed := True;
        end;
    end;

  WriteLn(#10'Testing "(UInt64 mod 100000000) and $FF" with implicit typecast to Integer:');
  for tw39646_X := Low(tw39646_Input) to High(tw39646_Input) do
    begin
      Write('- Input = ', tw39646_Input[tw39646_X], ' ... ');
      tw39646_Output := tw39646_NestedModWithAnd(tw39646_Input[tw39646_X]);
      if tw39646_Output = tw39646_ExpectedM[tw39646_X] then
        WriteLn('Passed')
      else
        begin
          WriteLn('FAILED! Got ', tw39646_Output, ', expected ', tw39646_ExpectedM[tw39646_X]);
          tw39646_Failed := True;
        end;
    end;

  if tw39646_Failed then
    Halt(1)
  else
    WriteLn('ok');
end;
{$pop}

end.
