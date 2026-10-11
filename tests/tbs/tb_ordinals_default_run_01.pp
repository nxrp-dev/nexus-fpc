{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_ordinals_default_run_01.pp }
{$push}

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

{ Case tb0715.pp }
{$push}
var
	tb0715_e: (ab, abcd);
	tb0715_code: int32;
{$pop}

{ Case tb0527.pp }
{$push}
type
{$z-}
  tb0527_te1 = (tb0527_a,tb0527_b,tb0527_c);
{$z+}
  tb0527_te2 = (tb0527_e,tb0527_f,tb0527_g);
{$pop}


{$pop}

{ Source group: tb_ordinal_types_default_run_01.pp }
{$push}

{ Case tb0132.pp }
{$push}
{ Old file: tbs0154.pp }
{ Subrange types give type mismatch when assigning to   OK 0.99.7 (PFV) }

type
  tb0132_week=(tb0132_mon,tb0132_tue,tb0132_wed);
Var
    tb0132_w : tb0132_week;
    tb0132_w1 : tb0132_mon..tb0132_tue;
{$pop}

{ Case tb0383.pp }
{$push}
type
  tb0383_enum1 = (tb0383_one,tb0383_two,tb0383_three);
  tb0383_enum2 = (tb0383_een,tb0383_twee,tb0383_drie);

procedure tb0383_p1(tb0383_e:tb0383_enum1);
begin
end;

var
  tb0383_e2 : tb0383_enum2;
{$pop}

{ Case tb0409.pp }
{$push}
type
   tb0409_myl = type longint;

var
   tb0409_i1,tb0409_i2,tb0409_i3 : tb0409_myl;
   tb0409_l : longint;

procedure tb0409_p(tb0409_i : tb0409_myl);overload;
begin
end;

procedure tb0409_p(tb0409_i : longint);overload;
begin
end;
{$pop}


{$pop}

{ Source group: tb_enum_bounds_default_run_01.pp }
{$push}

{ Case tw1310.pp }
{$push}
type
  tw1310_days     = (tw1310_mon, tw1310_tue, tw1310_wed, tw1310_thu, tw1310_fri, tw1310_sat, tw1310_sun);
  tw1310_weekdays = tw1310_mon..tw1310_fri;
  tw1310_weekend  = tw1310_sat..tw1310_sun;
{$pop}

{ Case tw11176.pp }
{$push}
type
  tw11176_tx = (one,two,three);

procedure tw11176_error(tw11176_number : longint);
begin
  writeln('error ', tw11176_number);
  halt(tw11176_number);
end;

var
  tw11176_a : tw11176_tx;
  tw11176_err : word;
{$pop}


{$pop}

{ Source group: tb_unsigned_default_run_01.pp }
{$push}

{ Case tb0081.pp }
{$push}
{ Old file: tbs0093.pp }
{ Two Cardinal type bugs                                0K 0.99.1 (FK/MvC) }

{ Two cardinal type bugs }
var
  tb0081_c : cardinal;
  tb0081_l : longint;
  tb0081_b : byte;
  tb0081_s : shortint;
  tb0081_w : word;
{$pop}

{ Case tb0088.pp }
{$push}
{ Old file: tbs0104.pp }
{ cardinal greater than $7fffffff aren't written        OK 0.99.1 (FK) }

{ Two cardinal type bugs }
var
  tb0088_c : cardinal;
{$pop}

{ Case tb0199.pp }
{$push}
{ Old file: tbs0235.pp }
{ Val(cardinal) bugs                                    OK 0.99.11 (JM) }

var tb0199_s:string;
    tb0199_w:cardinal;
    tb0199_code:word;
{$pop}

{ Case tb0204.pp }
{$push}
{ Old file: tbs0240.pp }
{ Problems with larges value is case statements        OK 0.99.11 (FK) }

var tb0204_curfilecrc32f : cardinal{Longint};
    tb0204_checkthis : String;
{$pop}

{ Case tb0447a.pp }
{$push}
var
  tb0447a_a : cardinal;
  tb0447a_b : longint;
{$pop}

{ Case tb0358.pp }
{$push}
type
  tb0358___u64 = 0..High(Int64); // Create unsigned Int64 (with 63 bits)
{$pop}


{$pop}

{ Source group: tb_integer_bits_default_run_01.pp }
{$push}

{ Case tb0431.pp }
{$push}
{ the smallest falling test I ever found PM }
{ the code generated a shll #0,%edx on i386
  which was bad but harmless...
  but on m68K it generated a asl.l #0,%d2
  which is not correct ... }

const
  tb0431_has_errors : boolean = false;
var
  tb0431_x : longint;
{$pop}

{ Case tb0473.pp }
{$push}
const
  tb0473_w = $5000;
{$pop}

{ Case tb0399.pp }
{$push}
procedure tb0399_error;
  begin
     writeln('Problem with octal constants');
     halt(1);
  end;
{$pop}

{ Case tw15015.pp }
{$push}
var
  tw15015_a, tw15015_b: LongWord;
{$pop}


{$pop}

begin
  { Source group: tb_ordinals_default_run_01.pp }
  {$push}


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

  { Case tb0715.pp }
  {$push}
begin
	val('ab'#4'd', tb0715_e, tb0715_code);
	if tb0715_code = 0 then writeln('matches ', tb0715_e) else writeln('matches nothing, code ', tb0715_code);
    if tb0715_code <> 3 then
      halt(1);
end;
  {$pop}

  { Case tb0527.pp }
  {$push}
begin
  if sizeof(tb0527_te1) <> 1 then
    halt(1);
  if sizeof(tb0527_te2) <> 4 then
    halt(2);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_ordinal_types_default_run_01.pp }
  {$push}


begin
  { Case tb0132.pp }
  {$push}
begin
  tb0132_w1:=tb0132_w;
end;
  {$pop}

  { Case tb0383.pp }
  {$push}
begin
  tb0383_e2:=tb0383_een;
  tb0383_p1(tb0383_enum1(tb0383_e2));
end;
  {$pop}

  { Case tb0409.pp }
  {$push}
begin
   tb0409_i1:=tb0409_i2+tb0409_i3;
   tb0409_l:=tb0409_i1+tb0409_l;
   inc(tb0409_i3);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_enum_bounds_default_run_01.pp }
  {$push}


begin
  { Case tw1310.pp }
  {$push}
begin
  WriteLn('Days     ', Ord(Low(tw1310_days))    , Ord(High(tw1310_days))    :2);
  WriteLn('Weekdays ', Ord(Low(tw1310_weekdays)), Ord(High(tw1310_weekdays)):2, ' should be 4!');
  WriteLn('Weekend  ', Ord(Low(tw1310_weekend)) , Ord(High(tw1310_weekend)) :2);
  if ord(high(tw1310_weekdays))<>4 then
   begin
     writeln('ERROR!');
     Halt(1);
   end;
end;
  {$pop}

  { Case tw11176.pp }
  {$push}
begin
  val('one', tw11176_a, tw11176_err);
  if (tw11176_err <> 0) or (tw11176_a <> one) then tw11176_error(1);
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_unsigned_default_run_01.pp }
  {$push}


begin
  { Case tb0081.pp }
  {$push}
begin
  tb0081_b:=123;
  tb0081_w:=tb0081_s;
  tb0081_l:=tb0081_b;
  tb0081_c:=tb0081_b;         {generates movzbl %eax,%edx instead of movzbl %al,%edx}

  tb0081_c:=123;
  writeln(tb0081_c);   {Shows '0' outline right! instead of '123' outlined left}
  tb0081_c:=$7fffffff;
  writeln(tb0081_c);   {Shows '0' outline right! instead of '123' outlined left}
end;
  {$pop}

  { Case tb0088.pp }
  {$push}
begin
  tb0088_c:=$80000000;
  writeln(tb0088_c);
  tb0088_c:=$80001234;
  writeln(tb0088_c);
  tb0088_c:=$ffffffff;
  writeln(tb0088_c);
end;
  {$pop}

  { Case tb0199.pp }
  {$push}
begin
    tb0199_s:='192';
    val(tb0199_s,tb0199_w,tb0199_code);
    if tb0199_code<>0 then
        begin
           writeln('Error');
           halt(1);
        end
    else
        writeln(tb0199_w);
end;
  {$pop}

  { Case tb0204.pp }
  {$push}
BEGIN
  tb0204_curfilecrc32f := $C5CAF43C;
  tb0204_checkthis := '';
  Case tb0204_curfilecrc32f of
    $F3DC2AF0 :  tb0204_checkthis := ' First ';
    $27BF798B :  tb0204_checkthis := ' Second ';
    $7BA5BB19 :  tb0204_checkthis := ' Third';
    $FA246A81 :  tb0204_checkthis := ' Forth';
    $8A00B508 :  tb0204_checkthis := ' Fifth';
    $C5CAF43C :  tb0204_checkthis := ' Sixth';
  End;
  Writeln( tb0204_checkthis );
  If tb0204_checkthis<>' Sixth' then halt(1);
END;
  {$pop}

  { Case tb0447a.pp }
  {$push}
begin
  tb0447a_a := 0;
  tb0447a_b := -1;
  if tb0447a_a > tb0447a_b then
    writeln ('OK')
  else
    halt(1);
end;
  {$pop}

  { Case tb0358.pp }
  {$push}
begin
end;
  {$pop}


end;
  {$pop}

  { Source group: tb_integer_bits_default_run_01.pp }
  {$push}


begin
  { Case tb0431.pp }
  {$push}
begin
  tb0431_x:=5;
  tb0431_x:=tb0431_x*1;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  tb0431_x:=5;
  tb0431_x:=tb0431_x shl 0;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  tb0431_x:=5;
  tb0431_x:=tb0431_x shr 0;
  if tb0431_x<>5 then
    tb0431_has_errors:=true;
  if tb0431_has_errors then
    halt(1);
end;
  {$pop}

  { Case tb0473.pp }
  {$push}
begin
  writeln(hi(tb0473_w));
  if hi(tb0473_w)<>$50 then
    begin
      writeln('Error!');
      halt(1);
    end;
end;
  {$pop}

  { Case tb0399.pp }
  {$push}
begin
   if 8<>&10 then
     tb0399_error;
   if 1<>&1 then
     tb0399_error;
   if 64<>&100 then
     tb0399_error;
   if 33<>&41 then
     tb0399_error;
   if 33<>&41 then
     tb0399_error;
   if 12345678<>&57060516 then
     tb0399_error;
end;
  {$pop}

  { Case tw15015.pp }
  {$push}
begin
  tw15015_a := 307;
  tw15015_b := 1 + ($FFFFFFFF mod (tw15015_a - 2));
  writeln(tw15015_b);
  if tw15015_b <> 301 then Halt(1);
  writeln(1 + $FFFFFFFF mod (tw15015_a - 2));
  if tw15015_b <> 301 then Halt(1);
end;
  {$pop}


end;
  {$pop}

end.
