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
end.
