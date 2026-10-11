{ Unchecked Word decrement, small set layout and binary constants. }
{ Original case IDs and variable scopes are retained below. }

{$mode delphi}

{ Case tb0602.pp }
{$push}
{ This test explicity generates
  dec(w,2) with w=1 of unsigned type word,
  this generates range check error.
  Thus, we need an explicit $R- }
{$R-}
{$ifdef fpc}

{$endif}

procedure tb0602_test;
var
  tb0602_w: word;
  tb0602_arr: array[0..1] of word;
begin
  tb0602_arr[1]:=2;
  tb0602_w:=1;
  dec(tb0602_w,tb0602_arr[tb0602_w]);
  if cardinal(tb0602_w)<>$ffff then
    halt(1);
end;
{$pop}

{ Case tb0615.pp }
{$push}
var
  tb0615_s : set of 0..7;
{$pop}

{ Case tb0689.pp }
{$push}
{ Old file: tbf0326.pp }
{  }


const
    tb0689_anyconst = %11111;
{$pop}

begin
  { Case tb0602.pp }
  {$push}
{$R-}
begin
  tb0602_test;
end;
  {$pop}

  { Case tb0615.pp }
  {$push}
begin
  if sizeof(tb0615_s)<>1 then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0689.pp }
  {$push}
begin
end;
  {$pop}

end.
