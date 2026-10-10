{ Enumeration declarations, ordinal constants and predecessor/successor operations. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0023.pp }
{$push}
{ Old file: tbs0027.pp }
{  tests type enumtype = (One, two, three, forty:=40, fifty);  OK 0.9.5 }

type tb0023_enumtype = (tb0023_one, tb0023_two, tb0023_three, tb0023_forty:=40, tb0023_fifty);
{$pop}

{ Case tb0024.pp }
{$push}
{ Old file: tbs0028.pp }
{  type enumtype = (a); writeln(ord(a)); }

type
   tb0024_enumtype = (tb0024_a);

var
   tb0024_e : tb0024_enumtype;
{$pop}

{ Case tb0101.pp }
{$push}
{ Old file: tbs0120.pp }
{ inc/dec(enumeration) doesn't work                     OK 0.99.6 (MVC) }

type
   tb0101_te = (tb0101_enum1,tb0101_enum2,tb0101_enum3);

var
   tb0101_e,tb0101_f : tb0101_te;
{$pop}

{ Case tb0116.pp }
{$push}
{ Old file: tbs0135.pp }
{ Unsupported subrange type construction.               OK 0.99.6 }

const
  tb0116_a = 0;
  tb0116_b = 1;
  tb0116_c = 2;

type tb0116_d = tb0116_a..tb0116_c;
{$pop}

{ Case tb0567.pp }
{$push}

{$pop}

{ Case tb0079.pp }
{$push}
{ Old file: tbs0091.pp }
{ missing standard functions in constant expressions    OK 0.99.7 (PFV) }

{ Page 22 of The Language Guide of Turbo Pascal }
var
 tb0079_t: byte;
const
  tb0079_a = Trunc(1.3);
  tb0079_b = Round(1.6);
  tb0079_c = abs(-5);
  tb0079_errstr = 'Hello!';
  tb0079_d = Length(tb0079_errstr);
  tb0079_e = Lo($1234);
  tb0079_f = Hi($1234);
  tb0079_g = Chr(34);
  tb0079_h = Odd(1);
  tb0079_i = Ord('3');
  tb0079_j = Pred(34);
  tb0079_l = Sizeof(tb0079_t);
  tb0079_m = Succ(9);
  tb0079_n = Swap($1234);
  tb0079_o = ptr(0,0);
{$pop}

begin
  { Case tb0023.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0024.pp }
  {$push}
begin
   writeln(ord(tb0024_e));
end;
  {$pop}

  { Case tb0101.pp }
  {$push}
begin
   tb0101_e:=tb0101_enum1;
   inc(tb0101_e);
   tb0101_f:=tb0101_enum3;
   dec(tb0101_f);
   if tb0101_e<>tb0101_f then
    halt(1);
end;
  {$pop}

  { Case tb0116.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0567.pp }
  {$push}
begin
  if (pred(-128)<>-129) or
     (succ(127)<>128) then
    halt(1);
  if (pred(0)<>-1) or
     (succ(255)<>256) then
    halt(2);
  if (pred(-32768)<>-32769) or
     (succ(32767)<>32768) then
    halt(3);
  if (succ(65535)<>65536) then
    halt(4);
  if (pred(-2147483648)<>-2147483649) or
     (succ(2147483647)<>2147483648) then
    halt(5);
  if (succ(4294967295)<>4294967296) then
    halt(6);

  if (pred(bytebool(false))<>bytebool(true)) then
    halt(7);
  if (succ(bytebool(true))<>bytebool(false)) then
    halt(8);
  if (pred(wordbool(false))<>wordbool(true)) then
    halt(9);
  if (succ(wordbool(true))<>wordbool(false)) then
    halt(10);
  if (pred(longbool(false))<>longbool(true)) then
    halt(11);
  if (succ(longbool(true))<>longbool(false)) then
    halt(12);
end;
  {$pop}

  { Case tb0079.pp }
  {$push}
Begin
end;
  {$pop}

end.
