{ Managed array copying and numeric formatting with explicit separators. }
{ Original case IDs and variable scopes are retained below. }

uses SysUtils;

{ Case tb0572.pp }
{$push}
{ test copy optimization of dyn. arrays }
var
  tb0572_a,tb0572_b,tb0572_c : array of ansistring;
  tb0572_i : longint;
{$pop}

{ Case tb0364.pp }
{$push}
{ comment by submitter:
  The following statement (which works in Delphi)
    result:=Format('%10.n', [ival*1.0]);
  generated an unhandled exception (and said: Missing argument in format "").
  Checking the Delphi documentation, it agrees with the fpc documentation
  (units.pdf), that a dot should be followed by a <prec> (but Delphi does
  not appear to explicitly state that prec should be an integer).
  It appears that Delphi is treating this like %10.0n, although it is
  potentially undefined behaviour.  The fpc documentation indicates I
  should get an EConversionError exception if there are problems.
  (Actually the documentation may be inconsistent, since it also says
  I may get an EConvertError exception.)

  If I change the format string to %10.0n, the program runs OK using
  fpc, however, my thousand separators do not appear.
}

var
   tb0364_s : string;
   tb0364_ival : integer;
{$pop}

begin
  { Case tb0572.pp }
  {$push}
begin
  SetLength(tb0572_a,1000);
  SetLength(tb0572_c,1000);
  for tb0572_i:=low(tb0572_a) to high(tb0572_a) do
    tb0572_a[tb0572_i]:=IntToStr(random(10000));
  tb0572_b:=copy(tb0572_a);
  tb0572_c:=copy(tb0572_a);
  tb0572_a:=nil;
  for tb0572_i:=low(tb0572_b) to high(tb0572_b) do
    if tb0572_b[tb0572_i]<>tb0572_c[tb0572_i] then
      halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0364.pp }
  {$push}
begin
   ThousandSeparator:='.';
   DecimalSeparator:=',';
   tb0364_ival:=1234;
   tb0364_s:=Format('%10.n', [tb0364_ival*1.0]);
   writeln('s: "',tb0364_s,'"');
   if tb0364_s<>'     1.234' then
     begin
        writeln('Problem with Format');
        halt(1);
     end;
end;
  {$pop}

end.
