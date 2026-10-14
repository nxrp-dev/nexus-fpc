{ Consolidated currency regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}
uses sysutils;

{ Case tw12207.pas }
{$push}

var
  tw12207_s : string;

{$pop}

{ Case tw28749.pas }
{$push}

var
  tw28749_s: string;
  tw28749_c: currency;

{$pop}

{ Case tw4215.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4215 }
{ Submitted by "Tony Maro" on  2005-07-24 }
{ e-mail: tony@maro.net }

var
   tw4215_MyCurrency: Currency;

{$pop}

begin

{ Case tw12207.pas }
{$push}

begin
  str(currency(25.996):0:2,tw12207_s);
  if tw12207_s<>'26.00' then
    halt(1);
  str(currency(99.996):0:2,tw12207_s);
  if tw12207_s<>'100.00' then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw28749.pas }
{$push}

begin
  tw28749_c:=Currency(0.12) + Currency(0.14);
  tw28749_s:=CurrToStr(tw28749_c);
  tw28749_s:=StringReplace(tw28749_s, FormatSettings.DecimalSeparator, '.', []);
  writeln('s=', tw28749_s);
  if tw28749_s <> '0.26' then
    Halt(1);
  writeln('OK');
end;
{$pop}

{ Case tw4215.pas }
{$push}

begin
   CurrencyFormat := 0; // optional? It's my default anyway.
   tw4215_MyCurrency := 12.53;
   writeln(tw4215_MyCurrency); // this works
   writeln(format('%n',[tw4215_MyCurrency])); // this doesn't
end;
{$pop}

end.
