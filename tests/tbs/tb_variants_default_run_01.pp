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

{ Case tb0520.pp }
{$push}
var
  tb0520_w : widestring;
  tb0520_v : variant;
  tb0520_a : ansistring;
{$pop}

{ Case tb0536.pp }
{$push}
var tb0536_dt : TDateTime;
    tb0536_v : variant;
    tb0536_s : String;
{$pop}

{ Case tb0537.pp }
{$push}
var
  tb0537_d: array of variant;
  tb0537_v: variant;
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

  { Case tb0520.pp }
  {$push}
begin
  tb0520_a:='';
  tb0520_w:='';
  tb0520_v:='asdf';
  pos(tb0520_a,tb0520_v);
  pos(tb0520_w,tb0520_v);
  pos(tb0520_v,tb0520_v);
  pos(tb0520_v,tb0520_a);
  pos(tb0520_v,tb0520_w);
  pos(tb0520_v,tb0520_v);
end;
  {$pop}

  { Case tb0536.pp }
  {$push}
begin
  tb0536_dt := 40000;
  tb0536_v := tb0536_dt;
  tb0536_s := tb0536_v;
  // It should return the date, depending on the localisation settings
  if tb0536_s = '40000' then halt(1);
end;
  {$pop}

  { Case tb0537.pp }
  {$push}
begin
  tb0537_v:=tb0537_d;
  tb0537_d:=tb0537_v;
end;
  {$pop}

end.
