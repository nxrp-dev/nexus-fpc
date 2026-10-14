{ Consolidated strings regressions; original case IDs and assertions are retained. }
{ %OPT=-O3 }
program nexus_consolidated_tests;
{$mode objfpc}

{ Case tval1.pas }
{$push}






function tval1_TryStrToInt(const s: string; out i: Longint): boolean; inline;
var
  Error : word;
begin
  Val(s, i, Error);
  tval1_TryStrToInt:=(Error=0)
end;

procedure tval1_DoTest;
var
  Output: Longint;
begin
  if tval1_TryStrToInt('Invalid', Output) then
    Halt(1);

  if not tval1_TryStrToInt('2', Output) then
    Halt(2);

  if Output <> 2 then
    Halt(3);
end;


{$pop}

{ Case tval1a.pas }
{$push}






function tval1a_TryStrToInt(const s: string; out i: LongWord): boolean; inline;
var
  Error : word;
begin
  Val(s, i, Error);
  tval1a_TryStrToInt:=(Error=0)
end;

procedure tval1a_DoTest;
var
  Output: LongWord;
begin
  if tval1a_TryStrToInt('Invalid', Output) then
    Halt(1);

  if not tval1a_TryStrToInt('2', Output) then
    Halt(2);

  if Output <> 2 then
    Halt(3);
end;


{$pop}

{ Case tval2.pas }
{$push}






const
  tval2_SResStr = 'Invalid2';

function tval2_TryStrToInt(const s: string; out i: Longint): boolean; inline;
var
  Error : word;
begin
  Val(s, i, Error);
  tval2_TryStrToInt:=(Error=0)
end;

procedure tval2_DoTest;
var
  Output: Longint;
begin
  if tval2_TryStrToInt(tval2_SResStr, Output) then
    Halt(1);

  if not tval2_TryStrToInt(tval2_SResStr[8], Output) then
    Halt(2);

  if Output <> 2 then
    Halt(3);
end;


{$pop}

{ Case tval2a.pas }
{$push}






const
  tval2a_SResStr = 'Invalid2';

function tval2a_TryStrToInt(const s: string; out i: LongWord): boolean; inline;
var
  Error : word;
begin
  Val(s, i, Error);
  tval2a_TryStrToInt:=(Error=0)
end;

procedure tval2a_DoTest;
var
  Output: LongWord;
begin
  if tval2a_TryStrToInt(tval2a_SResStr, Output) then
    Halt(1);

  if not tval2a_TryStrToInt(tval2a_SResStr[8], Output) then
    Halt(2);

  if Output <> 2 then
    Halt(3);
end;


{$pop}

begin

{ Case tval1.pas }
{$push}

begin
  tval1_DoTest(); { This is so "Output" is a local variable rather than global }
  WriteLn('ok');
end;
{$pop}

{ Case tval1a.pas }
{$push}

begin
  tval1a_DoTest(); { This is so "Output" is a local variable rather than global }
  WriteLn('ok');
end;
{$pop}

{ Case tval2.pas }
{$push}

begin
  tval2_DoTest(); { This is so "Output" is a local variable rather than global }
  WriteLn('ok');
end;
{$pop}

{ Case tval2a.pas }
{$push}

begin
  tval2a_DoTest(); { This is so "Output" is a local variable rather than global }
  WriteLn('ok');
end;
{$pop}

end.
