{ Set constructors, constant storage, variable ranges and membership checks. }
{ Original case IDs and variable scopes are retained below. }

{ Case tb0173.pp }
{$push}
{ Old file: tbs0206.pp }
{ sets with variable ranges doesn't work                OK 0.99.11 (PFV) }

CONST tb0173_a:char='A';tb0173_z:char='Z';
VAR tb0173_s:set of char;tb0173_c:char;
{$pop}

{ Case tb0216.pp }
{$push}
{ Old file: tbs0255.pp }
{ internal error 10 with in and function calls         OK 0.99.12 (FK) }


function tb0216_a: char;
begin
  tb0216_a:='c';
end;
{$pop}

{ Case tb0017.pp }
{$push}
{ Old file: tbs0021.pp }
{  tests compatibility of empty sets with other set and the evaluation of constant sets                  OK 0.9.3 }

{ tests constant set evaluation }

var
   tb0017_a : set of byte;

const
   tb0017_b : set of byte = [0..255]+[9];

type
   tb0017_tcommandset = set of byte;

const
tb0017_cmzoom = 10;
tb0017_cmclose = 5;
tb0017_cmresize = 8;
tb0017_cmnext = 12;
tb0017_cmprev = 15;

CONST
   tb0017_curcommandset : tb0017_tcommandset = ([0..255] -
        [tb0017_cmzoom, tb0017_cmclose, tb0017_cmresize, tb0017_cmnext, tb0017_cmprev]);
   tb0017_commands : tb0017_tcommandset = [];

var
   tb0017_commandsetchanged : boolean;

PROCEDURE tb0017_disablecommands (tb0017_commands: tb0017_tcommandset);

   BEGIN
      {$IFNDEF PPC_FPK}                                  { FPK bug }
      tb0017_commandsetchanged := tb0017_commandsetchanged OR
        (tb0017_curcommandset * tb0017_commands <> []);                { Set changed flag }
      {$ENDIF}
      tb0017_curcommandset := tb0017_curcommandset - tb0017_commands;         { Update command set }
   END;
{$pop}

{ Case tb0154.pp }
{$push}
{ Old file: tbs0184.pp }
{ multiple copies of the same constant set are stored in executable OK 0.99.9 (PFV) }

{ multiple copies of the constant sets are stored in the assembler file when
  they are needed more than once}

Var tb0154_bset: Set of Byte;
    tb0154_sset: Set of 0..31;
    tb0154_b,tb0154_c: byte;
    tb0154_s: 0..31;
{$pop}

{ Case tb0041.pp }
{$push}
{ Old file: tbs0046.pp }
{  problems with sets with values over 128 due to sign extension (already fixed ) but also for SET_IN_BYTE }

{$R-}

type tb0041_byteset = set of byte;
     tb0041_bl = record tb0041_i,tb0041_j : longint;
          end;
const tb0041_set1 : tb0041_byteset = [1,50,220];
      tb0041_set2 : tb0041_byteset = [55];
var tb0041_i : longint;
    tb0041_b : tb0041_bl;

    function tb0041_bi : longint;

    begin
       tb0041_bi:=tb0041_b.tb0041_i;
    end;
{$pop}

begin
  { Case tb0173.pp }
  {$push}
BEGIN
 tb0173_s:=[tb0173_a..tb0173_z];
 for tb0173_c:=#0 to #255 do
  if tb0173_c in tb0173_s then
   write(tb0173_c);
 writeln;
END;
  {$pop}

  { Case tb0216.pp }
  {$push}
begin
  if #12 in [tb0216_a, tb0216_a, tb0216_a, tb0216_a, tb0216_a] then ; { <--- }
end;
  {$pop}

  { Case tb0017.pp }
  {$push}
begin
   tb0017_a:=[byte(1)]+[byte(2)];
end;
  {$pop}

  { Case tb0154.pp }
  {$push}
Begin
  tb0154_bset := tb0154_bset + [tb0154_b];  {creates a big, empty set}
  tb0154_bset := tb0154_bset + [tb0154_c];  {creates another one}
  tb0154_bset := tb0154_bset + [3];  {creates a big set with element three set}
  tb0154_bset := tb0154_bset + [3];  {and another one}

  tb0154_sset := tb0154_sset + [5];  {creates a small set containing 5}
  tb0154_sset := tb0154_sset + [tb0154_s];  {creates a small, empty set}
  tb0154_sset := tb0154_sset + [5];  {creates another small set containing 5}
  tb0154_sset := tb0154_sset + [tb0154_s];  {creates another small, empty set}

{BTW: small constant sets don't have to be stored separately in the
 executable, as they're simple 32 bit constants, like longints!}

End;
  {$pop}

  { Case tb0041.pp }
  {$push}
{$R-}
begin
tb0041_set1:=tb0041_set1+tb0041_set2;
writeln('set 1 = [1,50,55,220]');
tb0041_i:=50;
if tb0041_i in tb0041_set1 then
  writeln(tb0041_i,' is in set1');
tb0041_i:=220;
if tb0041_i in tb0041_set1 then
  writeln(tb0041_i,' is in set1');
tb0041_i:=$100+220;
if tb0041_i in tb0041_set1 then
  writeln(tb0041_i,' is in set1');
tb0041_i:=-35;
if tb0041_i in tb0041_set1 then
  writeln(tb0041_i,' is in set1');
tb0041_b.tb0041_i:=50;
tb0041_i:=$100+220;
if tb0041_i in [50,220] then
  writeln(tb0041_i,' is in [50,220]');
if tb0041_bi in [50,220] then
  writeln(tb0041_b.tb0041_i,' is in [50,220]');
tb0041_b.tb0041_i:=220;
if tb0041_bi in [50,220] then
  writeln(tb0041_b.tb0041_i,' is in [50,220]');
tb0041_b.tb0041_i:=-36;
if tb0041_bi in [50,220] then
  writeln(tb0041_b.tb0041_i,' is in [50,220]');
end;
  {$pop}

end.
