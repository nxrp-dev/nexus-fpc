{ Consolidated currency regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb_currency_default_run_01.pp }
{$push}
{ Currency boundary formatting and Currency/Comp rounding. }

{ Case tb0460.pp }
const
  tb0460_MinCurrency : Currency = -922337203685477.5807;
  tb0460_MaxCurrency : Currency = 922337203685477.5807;
var
  tb0460_s : string;

{ Case tb0683.pp }
{$ifndef SKIP_CURRENCY_TEST}
var
  tb0683_c: currency;
  tb0683_co: comp;
  tb0683_i: int64;
{$endif}

{ Case tw10920.pp }
{$push}
//  If write/writeln parameter list includes any item FOLLOWING a
//     currency variable with format specs, the compiler throws
//     an Access violation exception.

var
  tw10920_v: currency;    // currency blows up,  all other real types are Ok
{$pop}

{ Case tw21091.pp }
{$push}
CONST tw21091_c : Currency = 100;
var
  tw21091_s : string;
{$pop}

{ Case tw28748.pp }
{$push}
var
  tw28748_d: Double;
  tw28748_c, tw28748_ce: Currency;
{$pop}

{ Case tw33439.pp }
{$push}
Var tw33439_cur : Currency ;
{$pop}


{$pop}

{ Case tcurrency1.pp }
{$push}


{ test basic mathematical operations (+,-,*,/) using currency data type }

var
  tcurrency1_c1, tcurrency1_c2: Currency;
  tcurrency1_d: Double;
  tcurrency1_i: Integer;
  tcurrency1_i64: int64;


{$pop}

{ Case tover2.pp }
{$push}
procedure tover2_pr(d:single);overload;
begin
  writeln('single');
end;

procedure tover2_pr(d:double);overload;
begin
  writeln('double');
end;

procedure tover2_pr(d:currency);overload;
begin
  writeln('currency');
end;


{$pop}

begin

{ Case tb_currency_default_run_01.pp }
{$push}
{$ifndef SKIP_CURRENCY_TEST}
{$endif}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tb0460.pp }
  str(tb0460_MinCurrency:0:4,tb0460_s);
  if tb0460_s<>'-922337203685477.5807' then
    begin
      writeln(tb0460_s);
      halt(1);
    end;
  str(tb0460_MaxCurrency:0:4,tb0460_s);
  if tb0460_s<>'922337203685477.5807' then
    begin
      writeln(tb0460_s);
      halt(1);
    end;

  { Case tb0683.pp }
{$ifndef SKIP_CURRENCY_TEST}
  tb0683_c:=10.25;
  tb0683_co:=12;
  tb0683_i:=trunc(tb0683_c);
  if tb0683_i<>10 then
    halt(1);
  tb0683_i:=trunc(tb0683_co);
  if tb0683_i<>12 then
    halt(2);
  tb0683_i:=round(tb0683_co);
  if tb0683_i<>12 then
    halt(3);
{$endif}
  { Case tw10920.pp }
  {$push}
BEGIN
  tw10920_v := 34567;

  write( tw10920_v:0:2, 'x' );   // This form produces the error

  write( tw10920_v:0:2 );        // This equivalent form compiles Ok
  writeln( 'x' );

END;
  {$pop}

  { Case tw21091.pp }
  {$push}
begin
  str(tw21091_c:10:2,tw21091_s);
  if tw21091_s<>'    100.00' then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tw28748.pp }
  {$push}
begin
  tw28748_d := 1;
  tw28748_c := 2;
  tw28748_ce := 3;
  tw28748_c:=tw28748_c + tw28748_d;
  writeln('c=', tw28748_c);
  if tw28748_c <> tw28748_ce then begin
    writeln('Invalid currency value. Expected: ', tw28748_ce);
    halt(1);
  end;
end;
  {$pop}

  { Case tw33439.pp }
  {$push}
Begin
  tw33439_cur:=100000000000;
  tw33439_cur:=tw33439_cur * 7 ;
  if tw33439_cur<>700000000000 then
    halt(1);
  writeln('ok');
End;
  {$pop}

end;
{$pop}

{ Case tcurrency1.pp }
{$push}

begin
  write('Currency and Double ...');
  // addition double
  tcurrency1_d := 1;
  tcurrency1_c1 := 2;
  tcurrency1_c2 := 3;
  if tcurrency1_c1+tcurrency1_d <> tcurrency1_c2 then begin
    writeln('Invalid currency+double=', tcurrency1_c1+tcurrency1_d, ', but expected ', tcurrency1_c2);
    halt(1);
  end;
  // subtraction double
  tcurrency1_d := 3;
  tcurrency1_c1 := 2;
  tcurrency1_c2 := -1;
  if tcurrency1_c1-tcurrency1_d <> tcurrency1_c2 then begin
    writeln('Invalid currency-double=', tcurrency1_c1-tcurrency1_d, ', but expected ', tcurrency1_c2);
    halt(1);
  end;
  // multiplication double
  tcurrency1_d := -100;
  tcurrency1_c1 := 12.34;
  tcurrency1_c2 := -1234;
  if tcurrency1_d*tcurrency1_c1 <> tcurrency1_c2 then begin
    writeln('Invalid currency*double=', tcurrency1_d*tcurrency1_c1, ', but expected ', tcurrency1_c2);
    halt(1);
  end;
  // division double
  tcurrency1_d := 100;
  tcurrency1_c1 := 12.34;
  tcurrency1_c2 := 0.1234;
  if tcurrency1_c1/tcurrency1_d <> tcurrency1_c2 then begin
    writeln('Invalid currency/double=', tcurrency1_c1/tcurrency1_d, ', but expected ', tcurrency1_c2);
    halt(1);
  end;
  writeln(' Passed');

  write('Currency and Integer ...');
  // addition integer
  tcurrency1_i := 1;
  tcurrency1_c1 := 2;
  tcurrency1_c2 := 3;
  if tcurrency1_c1+tcurrency1_i <> tcurrency1_c2 then begin
    writeln('Invalid currency+integer=', tcurrency1_c1+tcurrency1_i, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  // subtraction integer
  tcurrency1_i := 10;
  tcurrency1_c1 := -2;
  tcurrency1_c2 := -12;
  if tcurrency1_c1-tcurrency1_i <> tcurrency1_c2 then begin
    writeln('Invalid currency-integer=', tcurrency1_c1-tcurrency1_i, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  // multiplication integer
  tcurrency1_i := 100;
  tcurrency1_c1 := 12.34;
  tcurrency1_c2 := 1234;
  if tcurrency1_i*tcurrency1_c1 <> tcurrency1_c2 then begin
    writeln('Invalid currency*integer=', tcurrency1_i*tcurrency1_c1, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  tcurrency1_i:=10000;
  tcurrency1_c1:=92233720368.5477;
  tcurrency1_c2:=922337203685477;
  if tcurrency1_c1*tcurrency1_i <> tcurrency1_c2 then begin
    writeln('Invalid currency*integer=', tcurrency1_c1*tcurrency1_i, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  if tcurrency1_i*tcurrency1_c1 <> tcurrency1_c2 then begin
    writeln('Invalid integer*currency=', tcurrency1_i*tcurrency1_c1, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  // division integer
  tcurrency1_i := 1000;
  tcurrency1_c1 := 123.4;
  tcurrency1_c2 := 0.1234;
  if tcurrency1_c1/tcurrency1_i <> tcurrency1_c2 then begin
    writeln('Invalid currency/integer=', tcurrency1_c1/tcurrency1_i, ', but expected ', tcurrency1_c2);
    halt(2);
  end;
  writeln(' Passed');

  write('Currency and Int64 ...');
  // addition int64
  tcurrency1_i64 := 1;
  tcurrency1_c1 := 12.3456;
  tcurrency1_c2 := 13.3456;
  if tcurrency1_c1+tcurrency1_i64 <> tcurrency1_c2 then begin
    writeln('Invalid currency+int64=', tcurrency1_c1+tcurrency1_i64, ', but expected ', tcurrency1_c2);
    halt(3);
  end;
  // subtraction int64
  tcurrency1_i64 := 100;
  tcurrency1_c1 := 12.3456;
  tcurrency1_c2 := -87.6544;
  if tcurrency1_c1-tcurrency1_i64 <> tcurrency1_c2 then begin
    writeln('Invalid currency-int64=', tcurrency1_c1-tcurrency1_i64, ', but expected ', tcurrency1_c2);
    halt(3);
  end;
  // multiplication int64
  tcurrency1_i64 := -10000;
  tcurrency1_c1 := 12.3456;
  tcurrency1_c2 := -123456;
  if tcurrency1_i64*tcurrency1_c1 <> tcurrency1_c2 then begin
    writeln('Invalid currency*int64=', tcurrency1_i64*tcurrency1_c1, ', but expected ', tcurrency1_c2);
    halt(3);
  end;
  // division int64
  tcurrency1_i64 := -10000;
  tcurrency1_c1 := 123456;
  tcurrency1_c2 := -12.3456;
  if tcurrency1_c1/tcurrency1_i64 <> tcurrency1_c2 then begin
    writeln('Invalid currency/int64=', tcurrency1_c1/tcurrency1_i64, ', but expected ', tcurrency1_c2);
    halt(3);
  end;
  writeln(' Passed');
end;
{$pop}

{ Case tover2.pp }
{$push}

begin
  tover2_pr(1.0);
end;
{$pop}

end.
