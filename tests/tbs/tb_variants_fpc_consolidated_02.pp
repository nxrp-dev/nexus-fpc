{ Consolidated variants regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tw11139.pp }
{$push}
function tw11139_f(c: char): char; overload;
begin
  halt(1);
end;

function tw11139_f(const s: shortstring): shortstring; overload;
begin
  halt(3);
end;

function tw11139_f(const a: ansistring): ansistring; overload;
begin
  tw11139_f:=lowercase(a);
end;

Procedure tw11139_DoIt;
var avar:variant;
      txt:String;
Begin
avar:='Hello';
txt:=tw11139_f(avar);//this line causes the compilation error
if (txt<>'hello') then
  halt(4);
end;


{$pop}

{ Case tw3529.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3529 }
{ Submitted by "Alexey Barkovoy" on  2005-01-07 }
{ e-mail: clootie@ixbt.com }
var
  tw3529_v1, tw3529_v2: Variant;
  tw3529_S1, tw3529_S2: AnsiString;

{$pop}

{ Case tw4700.pp }
{$push}
var
  tw4700_a: Boolean;
  tw4700_b,tw4700_c,tw4700_d : Variant;
  tw4700_e : Integer;

{$pop}

{ Case tw8229.pp }
{$push}


procedure tw8229_Test;
var
  w: widestring;
  v: variant;
begin
  w := '';
  v := w;
  w := v;
  if w <> '' then
    halt(1);
end;


{$pop}

begin

{ Case tw11139.pp }
{$push}

begin
  tw11139_doit;
end;
{$pop}

{ Case tw3529.pp }
{$push}

begin
  tw3529_S1:= 'aa';
  tw3529_S2:= 'bb';
  tw3529_v1:= tw3529_S1;
  tw3529_v2:= tw3529_S2;
  if tw3529_v1 = tw3529_v2 then
    begin
      WriteLn('Equal');
      halt(1);
    end
  else
    writeln('not-equal');
end;
{$pop}

{ Case tw4700.pp }
{$push}

begin
  tw4700_b := 'abc';
  tw4700_c := null;
  tw4700_a := tw4700_b = tw4700_c;
  tw4700_a := tw4700_b <> tw4700_c;
  tw4700_d := tw4700_e - tw4700_c;
  tw4700_d := tw4700_e + tw4700_c;
end;
{$pop}

{ Case tw8229.pp }
{$push}

begin
  tw8229_Test;
end;
{$pop}

end.
