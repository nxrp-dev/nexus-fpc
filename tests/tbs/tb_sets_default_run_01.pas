{ Consolidated feature cases; original case IDs and settings are retained below. }
{$mode fpc}


{ Source group: tb_sets_default_run_01.pas }
{$push}

{ Case tb0138.pas }
{$push}
{ Old file: tbs0163.pas }
{ missing <= and >= operators for sets.                 OK 0.99.11 (JM) }

{ shows missing <= and >= for sets }

Type
     tb0138_days = (Monday,tuesday,wednesday,thursday,friday,saturday,sunday);

Var
     tb0138_freedays,tb0138_weekend : set of tb0138_days;
{$pop}

{ Case tb0197.pas }
{$push}
{ Old file: tbs0233.pas }
{ Problem with enum sets in args                       OK 0.99.11 (PFV) }

type tb0197_byteset = set of byte;
     tb0197_enumset = set of (tb0197_zero,tb0197_one,tb0197_two,tb0197_three);

function tb0197_test(s : tb0197_byteset) : boolean;
begin
  tb0197_test:=false;
  if 0 in s then
    begin
       Writeln('Contains zero !');
       tb0197_test:=true;
    end;
end;

function tb0197_testenum(s : tb0197_enumset) : boolean;
begin
  tb0197_testenum:=false;

  if tb0197_zero in s then
    begin
       Writeln('Contains zero !');
       tb0197_testenum:=true;
    end;
end;
{$pop}

{ Case tb0311.pas }
{$push}
{ problem of conversion between
  smallsets and long sets }
type

{ Command sets }

  tb0311_pcommandset = ^tb0311_tcommandset;
  tb0311_tcommandset = set of Byte;

Const
  tb0311_cmvalid   = 0;
  tb0311_cmquit    = 1;
  tb0311_cmerror   = 2;
  tb0311_cmmenu    = 3;
  tb0311_cmclose   = 4;
  tb0311_cmzoom    = 5;
  tb0311_cmresize  = 6;
  tb0311_cmnext    = 7;
  tb0311_cmprev    = 8;
  tb0311_cmhelp    = 9;

{ Application command codes }

  tb0311_cmcut     = 20;
  tb0311_cmcopy    = 21;
  tb0311_cmpaste   = 22;
  tb0311_cmundo    = 23;
  tb0311_cmclear   = 24;
  tb0311_cmtile    = 25;
  tb0311_cmcascade = 26;

  tb0311_curcommandset: tb0311_tcommandset =
    [0..255] - [tb0311_cmzoom, tb0311_cmclose, tb0311_cmresize, tb0311_cmnext, tb0311_cmprev];
{$pop}

{ Case tb0318.pas }
{$push}
const
  tb0318_nl=#10;
type
  tb0318_cs=set of char;

function tb0318_p(c:tb0318_cs):boolean;
begin
  tb0318_p:=(#10 in c);
end;
{$pop}

{ Case tb0417.pas }
{$push}
{ Testing smallset + normset }
{ with respect to normset + smallset }

type
  tb0417_charset=set of char;

  var
     tb0417_err : byte;
     tb0417_tr,tb0417_tr2    : tb0417_charset;

  procedure tb0417_test(const k:tb0417_charset);

    begin
       tb0417_tr:=[#7..#10]+k;
       tb0417_tr2:=k+[#7..#10];
    end;
{$pop}

{ Case tb0428.pas }
{$push}
{ Testing smallset + normset }
{ with respect to normset + smallset }

type
  tb0428_charset=set of char;

  var
     tb0428_tr,tb0428_tr2    : tb0428_charset;

  procedure tb0428_test(const k:tb0428_charset);

    begin
       tb0428_tr:=[#7..#10]+k;
       tb0428_tr2:=k+[#7..#10];
     if (tb0428_tr<>tb0428_tr2) then
       begin
         Writeln('Bug in set handling');
         halt(1);
       end;
    end;
{$pop}

{ Case tb0530.pas }
{$push}
type
  tb0530_tset1 = set of 0..7;
  tb0530_tset2 = set of 0..15;

procedure tb0530_p(s : tb0530_tset1);overload;
  begin
  end;

procedure tb0530_p(s : tb0530_tset2);overload;
  begin
  end;
{$pop}

{ Case tw16861.pas }
{$push}
(*$packset 1 *)

var
  tw16861_s8: set of 0..7;
  tw16861_b: byte;
{$pop}

{ Case tw18013.pas }
{$push}
var
  tw18013_wa, tw18013_ws : set of 1..9;
{$pop}

{ Case tw2031.pas }
{$push}
const
  tw2031_size = 31;
var
  tw2031_testset : set of 0..tw2031_size;
  tw2031_i : integer;
{$pop}

{ Case tw2772.pas }
{$push}
{ Source provided for Free Pascal Bug Report 2772 }
{ Submitted by "Sergey Kosarevsky" on  2003-11-08 }
{ e-mail: netsurfer@au.ru }
Type tw2772_twriteflags=(WF_OVERWRITE,
                  WF_NOOVERWRITE,
                  WF_APPEND);

Type tw2772_tfilewritingflags=Set Of tw2772_twriteflags;

Var tw2772_a:tw2772_tfilewritingflags;
{$pop}

{ Case tw40358.pas }
{$push}
{$packset 1}

type
  tw40358_regval = 0..47;
  tw40358_regset = set of tw40358_regval;

procedure tw40358_print_regset(const tw40358_rs : tw40358_regset);
var
  tw40358_r : tw40358_regval;
begin
  Write('rs=[');
  for tw40358_r in tw40358_rs do
    begin
      Write(',',ord(tw40358_r));
      { 39 is not in the constant sets below
        but it is equal to 7+32 }
      if tw40358_r=39 then
        begin
          WriteLn('...');
          WriteLn('Wrong code generaed!');
          halt(1);
        end;
    end;
  WriteLn(']');
end;

var
  tw40358_rs : tw40358_regset;
{$pop}


{$pop}

{ Source group: tb_sets_default_run_02.pas }
{$push}

{ Case tw10033.pas }
{$push}
// tests writing of high()/low() of enumeration values, i.e.
// writing and reading of rtti for enums, both "dense" and
// "sparse" enumerations (different rtti is generated and
// different code used for generating and reading)
type
  // "dense" unnamed enumeration
  tw10033_txx = set of (_one, _two, _three);
  // "sparse" unnamed enumeration
  tw10033_tyy = set of (_zero := 0, _ten := 10, _twenty := 20);

  // "dense" enumeration
  tw10033_tx = (one,two,three);
  tw10033_txxx = set of tw10033_tx;
  // "sparse" enumeration
  tw10033_ty = (zero := 0, ten := 10, twenty := 20);
  tw10033_tyyy = set of tw10033_ty;

procedure tw10033_error(number : longint);
begin
  writeln('error ', number);
  halt(number);
end;

var
  tw10033_x : tw10033_txxx;
  tw10033_y : tw10033_tyyy;
  tw10033_err : word;

  tw10033__x : tw10033_txx;
  tw10033__y : tw10033_tyy;
{$pop}

{ Case tw4477.pas }
{$push}
{ Source provided for Free Pascal Bug Report 4477 }
{ Submitted by "Alexey Moiseitsev" on  2005-10-30 }
{ e-mail: himeraster@gmail.com }
var tw4477_f : set of boolean;
{$pop}

{ Case tw4606.pas }
{$push}
{$packset 1}
type
  tw4606_tlettersset=set of 'a'..'z';
{$pop}

{ Case tw6735.pas }
{$push}
type
  tw6735_t=packed set of 0..7;
{$pop}

{ Case tw9167.pas }
{$push}
type
  tw9167_tshiftstateenum = (ssShift, ssAlt, ssCtrl,
    ssLeft, ssRight, ssMiddle, ssDouble,
    // Extra additions
    ssMeta, ssSuper, ssHyper, ssAltGr, ssCaps, ssNum,
    ssScroll,ssTriple,ssQuad);

{$packset 1}
  tw9167_tshiftstate = set of tw9167_tshiftstateenum;
{$packset default}

var
  tw9167_s: tw9167_tshiftstate;
  tw9167_ss: tw9167_tshiftstateenum;
{$pop}


{$pop}

{ Source group: tb_set_expressions_default_run_01.pas }
{$push}

{ Case tb0173.pas }
{$push}
{ Old file: tbs0206.pas }
{ sets with variable ranges doesn't work                OK 0.99.11 (PFV) }

CONST tb0173_a:char='A';tb0173_z:char='Z';
VAR tb0173_s:set of char;tb0173_c:char;
{$pop}

{ Case tb0216.pas }
{$push}
{ Old file: tbs0255.pas }
{ internal error 10 with in and function calls         OK 0.99.12 (FK) }


function tb0216_a: char;
begin
  tb0216_a:='c';
end;
{$pop}

{ Case tb0017.pas }
{$push}
{ Old file: tbs0021.pas }
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

{ Case tb0154.pas }
{$push}
{ Old file: tbs0184.pas }
{ multiple copies of the same constant set are stored in executable OK 0.99.9 (PFV) }

{ multiple copies of the constant sets are stored in the assembler file when
  they are needed more than once}

Var tb0154_bset: Set of Byte;
    tb0154_sset: Set of 0..31;
    tb0154_b,tb0154_c: byte;
    tb0154_s: 0..31;
{$pop}

{ Case tb0041.pas }
{$push}
{ Old file: tbs0046.pas }
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


{$pop}

begin
  { Source group: tb_sets_default_run_01.pas }
  {$push}


begin
  { Case tb0138.pas }
  {$push}

  begin
tb0138_weekend := [saturday, sunday];
   tb0138_freedays := [friday, saturday, sunday];
   If (tb0138_weekend <= tb0138_freedays) then
       Writeln ('Free in weekend !');
  end;
  {$pop}

  { Case tb0197.pas }
  {$push}

  begin
if tb0197_test([1..5,8]) then halt(1);
  if not tb0197_test([0,8,15]) then halt(1);
  if not tb0197_testenum([tb0197_zero,tb0197_two]) then halt(1);
  end;
  {$pop}

  { Case tb0318.pas }
  {$push}

  begin
if tb0318_p([#1..#255]-[tb0318_nl]) then
   halt(1);
  end;
  {$pop}

  { Case tb0417.pas }
  {$push}

  begin
tb0417_err:=0;
     tb0417_test([#20..#32]);
     if not(#32 in tb0417_tr) then
      tb0417_err:=1;
     if ([#33..#255]*tb0417_tr <> []) then
      tb0417_err:=2;
     if (tb0417_tr<>[#7..#10,#20..#32]) then
      tb0417_err:=3;
     if (tb0417_tr<>tb0417_tr2) then
      tb0417_err:=4;
     if tb0417_err<>0 then
       begin
         Writeln('Bug in set handling, see err:=',tb0417_err);
         halt(1);
       end;
  end;
  {$pop}

  { Case tb0428.pas }
  {$push}

  begin
tb0428_test([#20..#32]);
     if not(#32 in tb0428_tr) or ([#33..#255]*tb0428_tr <> []) or
        (tb0428_tr<>[#7..#10,#20..#32]) or
        (tb0428_tr<>tb0428_tr2) then
       begin
         Writeln('Bug in set handling');
         halt(1);
       end;
  end;
  {$pop}

  { Case tw16861.pas }
  {$push}

  begin
tw16861_b:=17;
  tw16861_s8:=[];
  if tw16861_b in (tw16861_s8+[1]) then
    halt(1);
  tw16861_b:=5;
  if not(tw16861_b in (tw16861_s8+[5])) then
    halt(2);
  end;
  {$pop}

  { Case tw18013.pas }
  {$push}

  begin
tw18013_wa := [1..2];
  tw18013_ws := [1..3];
  if (tw18013_wa <= tw18013_ws) and (tw18013_wa <> tw18013_ws) then writeln('True') else begin writeln('False'); halt(1) end;
  if (tw18013_wa <= tw18013_ws) then
    if (tw18013_wa <> tw18013_ws) then writeln('True') else begin writeln('False'); halt(2); end
  else halt(3);
  if (tw18013_wa <= tw18013_ws) then writeln('True') else begin writeln('False'); halt(4); end;
  if (tw18013_wa <> tw18013_ws) then writeln('True') else begin writeln('False'); halt(5); end;
  end;
  {$pop}

  { Case tw2031.pas }
  {$push}

  begin
tw2031_testset := [];
  tw2031_testset := tw2031_testset + [0,1,2,3,4];
  if tw2031_testset <> [0,1,2,3,4] then
    begin
      writeln('add wrong');
      halt(1);
    end;
  tw2031_testset := tw2031_testset - [2];
  if tw2031_testset <> [0,1,3,4] then
    begin
      writeln('sub wrong');
      halt(1);
    end;
  end;
  {$pop}

  { Case tw2772.pas }
  {$push}

  begin
tw2772_a:=[WF_OVERWRITE,WF_NOOVERWRITE,WF_APPEND];
   WriteLn(WF_OVERWRITE In tw2772_a);
  end;
  {$pop}

  { Case tw40358.pas }
  {$push}
{$packset 1}
  begin
tw40358_rs:=[1,3,38,46];
  WriteLn('We should get [,1,3,38,46]');
  tw40358_print_regset(tw40358_rs);
  tw40358_rs:=[5,7,28];
  WriteLn('We should get [,5,7,28]');
  tw40358_print_regset(tw40358_rs);
  WriteLn('ok');
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_sets_default_run_02.pas }
  {$push}


begin
  { Case tw10033.pas }
  {$push}

  begin
writeln(low(tw10033__x));
  writeln(high(tw10033__x));

  writeln(low(tw10033__y));
  writeln(high(tw10033__y));

  writeln(low(tw10033_x));
  writeln(high(tw10033_x));

  writeln(low(tw10033_y));
  writeln(high(tw10033_y));
  end;
  {$pop}

  { Case tw4606.pas }
  {$push}
{$packset 1}
  begin
if sizeof(tw4606_tlettersset)<>4 then
    begin
      writeln(sizeof(tw4606_tlettersset));
      halt(1);
    end;
  end;
  {$pop}

  { Case tw9167.pas }
  {$push}
{$packset 1}
{$packset default}
  begin
tw9167_s := [];
  tw9167_ss:=ssShift;
  include(tw9167_s,tw9167_ss);
  include(tw9167_s,ssSuper);
  if not(ssShift in tw9167_s) or
     not(ssSuper in tw9167_s) then
    halt(1);
  if not(tw9167_ss in tw9167_s) then
    halt(2);
  end;
  {$pop}


end;
  {$pop}

  { Source group: tb_set_expressions_default_run_01.pas }
  {$push}


begin
  { Case tb0173.pas }
  {$push}
BEGIN
 tb0173_s:=[tb0173_a..tb0173_z];
 for tb0173_c:=#0 to #255 do
  if tb0173_c in tb0173_s then
   write(tb0173_c);
 writeln;
END;
  {$pop}

  { Case tb0216.pas }
  {$push}
begin
  if #12 in [tb0216_a, tb0216_a, tb0216_a, tb0216_a, tb0216_a] then ; { <--- }
end;
  {$pop}

  { Case tb0017.pas }
  {$push}
begin
   tb0017_a:=[byte(1)]+[byte(2)];
end;
  {$pop}

  { Case tb0154.pas }
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

  { Case tb0041.pas }
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


end;
  {$pop}

end.
