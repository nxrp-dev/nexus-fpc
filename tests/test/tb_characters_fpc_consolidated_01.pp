{ Consolidated characters regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tforin13.pp }
{$push}
{mode objfpc}
{$apptype console}
var
  tforin13_ch: Char;

{$pop}

{ Case tforin16.pp }
{$push}
{mode objfpc}
{$apptype console}
const tforin16_S = 'abc';
var tforin16_ch: Char;

{$pop}

{ Case tforin17.pp }
{$push}
{mode objfpc}
{$apptype console}
var tforin17_ch: Char;

{$pop}

begin

{ Case tforin13.pp }
{$push}
{$apptype console}
begin
  for tforin13_ch in ['a'..'c', '0'..'3', '_'] do
    Writeln(tforin13_ch);
end;
{$pop}

{ Case tforin16.pp }
{$push}
{$apptype console}
begin
  for tforin16_ch in tforin16_S do Writeln(tforin16_ch);
end;
{$pop}

{ Case tforin17.pp }
{$push}
{$apptype console}
begin
  for tforin17_ch in 'abc' do Writeln(tforin17_ch);
end;
{$pop}

end.
