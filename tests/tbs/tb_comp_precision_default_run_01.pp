{ Comp multiplication and division, and typed floating-point constant precision. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0281.pp }
{$push}
{ Old file: tbs0333.pp }
{  }

{$if (not(defined(CPUI386)) and not(defined(CPUX86_64))) or defined(FPC_COMP_IS_INT64)}
  {$define COMP_IS_INT64}
{$endif}


var
  tb0281_a,tb0281_b : comp;
  tb0281_s1,tb0281_s2 : string;
{$pop}

{ Case tb0621.pp }
{$push}
VAR tb0621_x1, tb0621_x2 : comp;

(* Dividing 8 / 2 doesn't work with fpc 3.0.0
   but works for example with fpc 2.6.4
   Markus Greim / 29.jun.2016 *)
{$pop}

{ Case tb0648.pp }
{$push}
{$excessprecision on}
const
  tb0648_d1: double = 1.0/3.0;
  tb0648_d2: double = 1/3;
  tb0648_x1: extended = 1.0/3.0;
  tb0648_x2: extended = 1/3;
  tb0648_s1: single   = 1.0/3.0;
  tb0648_s2: single   = 1/3;
{$pop}

begin
  { Case tb0281.pp }
  {$push}
begin
  tb0281_a:=11384563;
  tb0281_b:=tb0281_a*tb0281_a;
{$ifdef COMP_IS_INT64}
  str(tb0281_a*tb0281_a,tb0281_s1);
  str(tb0281_b,tb0281_s2);
{$else not COMP_IS_INT64}
  str(tb0281_a*tb0281_a:0:0,tb0281_s1);
  str(tb0281_b:0:0,tb0281_s2);
{$endif COMP_IS_INT64}
  writeln(tb0281_s1);
  writeln(tb0281_s2);
  if (tb0281_s1<>'129608274700969') or (tb0281_s2<>'129608274700969') then
   begin
     writeln('Error with comp type rounding');
     halt(1);
   end;
end;
  {$pop}

  { Case tb0621.pp }
  {$push}
BEGIN
{$ifdef FPC_COMP_IS_INT64}
tb0621_x1 := 8;
writeln('x1 : ',tb0621_x1);
tb0621_x2 := round(tb0621_x1 / 2);
writeln('x2 = x1/2 should be 4 but is : ', tb0621_x2);
if tb0621_x2<>4 then
  halt(1);
tb0621_x2 := round(tb0621_x1 / 4);
writeln('x2 = x1/4 should be 2 but is : ', tb0621_x2);
if tb0621_x2<>2 then
  halt(2);
tb0621_x2 := round(tb0621_x1 / 8);
writeln('x2 = x1/8 should be 1 and is : ', tb0621_x2);
if tb0621_x2<>1 then
  halt(3);
{$else FPC_COMP_IS_INT64}
tb0621_x1 := 8;
writeln('x1 : ',tb0621_x1);
tb0621_x2 := tb0621_x1 / 2;
writeln('x2 = x1/2 should be 4 but is : ', tb0621_x2);
if tb0621_x2<>4 then
  halt(1);
tb0621_x2 := tb0621_x1 / 4;
writeln('x2 = x1/4 should be 2 but is : ', tb0621_x2);
if tb0621_x2<>2 then
  halt(2);
tb0621_x2 := tb0621_x1 / 8;
writeln('x2 = x1/8 should be 1 and is : ', tb0621_x2);
if tb0621_x2<>1 then
  halt(3);
{$endif FPC_COMP_IS_INT64}


END;
  {$pop}

  { Case tb0648.pp }
  {$push}
{$excessprecision on}
begin
  writeln(tb0648_s1:30:10,  tb0648_s2:30:10);
  if tb0648_s1<>tb0648_s2 then
    halt(1);
  writeln(tb0648_d1:30:16,  tb0648_d2:30:16);
  if tb0648_d1<>tb0648_d2 then
    halt(1);
{$ifdef FPUX87}
  writeln(tb0648_x1:30:24,  tb0648_x2:30:24);
  if tb0648_x1<>tb0648_x2 then
    halt(1);
{$endif FPUX87}
  writeln('ok');
end;
  {$pop}

end.
