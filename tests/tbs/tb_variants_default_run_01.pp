{ Variant scalar conversions, Boolean control flow and array creation. }
{ Original case IDs and variable scopes are retained below. }

uses variants;

{ Case tb0410.pp }
{$push}
procedure tb0410_p1(tb0410_f : single);
  begin
  end;

procedure tb0410_p2(tb0410_l : longint);
  begin
  end;

var
   tb0410_v : variant;
   tb0410_l : longint;
{$pop}

{ Case tb0487.pp }
{$push}
var
  tb0487_v : variant;
  tb0487_i : longint;
{$pop}

{ Case tb0492.pp }
{$push}
var
  tb0492_v: Variant;
{$pop}

begin
  { Case tb0410.pp }
  {$push}
begin
   tb0410_v:=1;
   tb0410_p1(tb0410_v);
   tb0410_p2(tb0410_v);
   tb0410_l:=tb0410_v;
end;
  {$pop}

  { Case tb0487.pp }
  {$push}
begin
  tb0487_v:=true;
  if not(tb0487_v) then
    halt(1);
  while not(tb0487_v) do
    halt(1);
  tb0487_i:=1;
  repeat
    if tb0487_i>1 then
      halt(1);
    inc(tb0487_i);
  until tb0487_v;
  writeln('ok');
end;
  {$pop}

  { Case tb0492.pp }
  {$push}
begin
  tb0492_v := VarArrayCreate([0, 1], varVariant);
end;
  {$pop}

end.
