{ Currency boundary formatting and Currency/Comp rounding. }

{ Case tb0460.pas }
const
  tb0460_MinCurrency : Currency = -922337203685477.5807;
  tb0460_MaxCurrency : Currency = 922337203685477.5807;
var
  tb0460_s : string;

{ Case tb0683.pas }
{$ifndef SKIP_CURRENCY_TEST}
var
  tb0683_c: currency;
  tb0683_co: comp;
  tb0683_i: int64;
{$endif}

{ Case tw10920.pas }
{$push}
//  If write/writeln parameter list includes any item FOLLOWING a
//     currency variable with format specs, the compiler throws
//     an Access violation exception.

var
  tw10920_v: currency;    // currency blows up,  all other real types are Ok
{$pop}

{ Case tw21091.pas }
{$push}
CONST tw21091_c : Currency = 100;
var
  tw21091_s : string;
{$pop}

{ Case tw28748.pas }
{$push}
var
  tw28748_d: Double;
  tw28748_c, tw28748_ce: Currency;
{$pop}

{ Case tw33439.pas }
{$push}
Var tw33439_cur : Currency ;
{$pop}

begin
  { Case tb0460.pas }
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

  { Case tb0683.pas }
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
  { Case tw10920.pas }
  {$push}
BEGIN
  tw10920_v := 34567;

  write( tw10920_v:0:2, 'x' );   // This form produces the error

  write( tw10920_v:0:2 );        // This equivalent form compiles Ok
  writeln( 'x' );

END;
  {$pop}

  { Case tw21091.pas }
  {$push}
begin
  str(tw21091_c:10:2,tw21091_s);
  if tw21091_s<>'    100.00' then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tw28748.pas }
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

  { Case tw33439.pas }
  {$push}
Begin
  tw33439_cur:=100000000000;
  tw33439_cur:=tw33439_cur * 7 ;
  if tw33439_cur<>700000000000 then
    halt(1);
  writeln('ok');
End;
  {$pop}

end.
