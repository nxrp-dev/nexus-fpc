{ Sets regression cases; original case IDs are retained below. }

{ Case tb0138.pp }
{$push}
{ Old file: tbs0163.pp }
{ missing <= and >= operators for sets.                 OK 0.99.11 (JM) }

{ shows missing <= and >= for sets }

Type
     tb0138_days = (Monday,tuesday,wednesday,thursday,friday,saturday,sunday);

Var
     tb0138_freedays,tb0138_weekend : set of tb0138_days;
{$pop}

{ Case tb0197.pp }
{$push}
{ Old file: tbs0233.pp }
{ Problem with enum sets in args                       OK 0.99.11 (PFV) }

type tb0197_byteset = set of byte;
     tb0197_enumset = set of (zero,one,two,three);

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

  if zero in s then
    begin
       Writeln('Contains zero !');
       tb0197_testenum:=true;
    end;
end;
{$pop}

{ Case tb0311.pp }
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

{ Case tb0318.pp }
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

{ Case tb0417.pp }
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

{ Case tb0428.pp }
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

{ Case tb0530.pp }
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

{ Case tw16861.pp }
{$push}
(*$packset 1 *)

var
  tw16861_s8: set of 0..7;
  tw16861_b: byte;
{$pop}

{ Case tw18013.pp }
{$push}
var
  tw18013_wa, tw18013_ws : set of 1..9;
{$pop}

{ Case tw2031.pp }
{$push}
const
  tw2031_size = 31;
var
  tw2031_testset : set of 0..tw2031_size;
  tw2031_i : integer;
{$pop}

{ Case tw2772.pp }
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

{ Case tw40358.pp }
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

begin
  { Case tb0138.pp }
  {$push}

  begin
tb0138_weekend := [saturday, sunday];
   tb0138_freedays := [friday, saturday, sunday];
   If (tb0138_weekend <= tb0138_freedays) then
       Writeln ('Free in weekend !');
  end;
  {$pop}

  { Case tb0197.pp }
  {$push}

  begin
if tb0197_test([1..5,8]) then halt(1);
  if not tb0197_test([0,8,15]) then halt(1);
  if not tb0197_testenum([zero,two]) then halt(1);
  end;
  {$pop}

  { Case tb0318.pp }
  {$push}

  begin
if tb0318_p([#1..#255]-[tb0318_nl]) then
   halt(1);
  end;
  {$pop}

  { Case tb0417.pp }
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

  { Case tb0428.pp }
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

  { Case tw16861.pp }
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

  { Case tw18013.pp }
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

  { Case tw2031.pp }
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

  { Case tw2772.pp }
  {$push}

  begin
tw2772_a:=[WF_OVERWRITE,WF_NOOVERWRITE,WF_APPEND];
   WriteLn(WF_OVERWRITE In tw2772_a);
  end;
  {$pop}

  { Case tw40358.pp }
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

end.
