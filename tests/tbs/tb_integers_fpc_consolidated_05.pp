{ Consolidated integers regressions; original case IDs and assertions are retained. }
program nexus_consolidated_tests;
{$mode fpc}

{ Case tb0147.pp }
{$push}
{ Old file: tbs0177.pp }
{ program.symbol not allowed (almost the same as bugs 176) OK 0.99.9 (PM) }


var
  tb0147_l : longint;

{$pop}

{ Case tb_integer_codegen_default_run_01.pp }
{$push}
{ Consolidated integer-codegen-default regression cases; original IDs and assertions are retained. }


{ Case tw0802.pp }
{$push}
function tw0802_testf (tw0802_a:byte;tw0802_b:integer;tw0802_c:char):char;
  begin
    tw0802_testf:=tw0802_c;
  end;
{$pop}

{ Case tw1046.pp }
{$push}
procedure tw1046_test2(tw1046_self : longint);
begin
 writeln(tw1046_self);
end;
{$pop}

{ Case tw10863.pp }
{$push}
function tw10863_f(tw10863_b,tw10863_c,tw10863_d : boolean) : longint;
 begin
   tw10863_f:=ord(tw10863_b);
 end;

procedure tw10863_test;
var
 tw10863_b,tw10863_c : boolean;

begin
 tw10863_b:=true;
 tw10863_c:=false;
 tw10863_b:=1<>tw10863_f(tw10863_b,not(tw10863_b),tw10863_c);
 tw10863_c:=true;
 if (tw10863_b) then
   halt(1);
 writeln(tw10863_c);
end;
{$pop}

{ Case tw12237.pp }
{$push}
function tw12237_f: longint; safecall;
begin
  tw12237_f:=-2;
end;
{$pop}

{ Case tw17458.pp }
{$push}
function tw17458_tailrecfibonacci(const tw17458_n: Byte): QWord;

  function tw17458_innerfibo(const tw17458_n: Byte; const tw17458_r1,tw17458_r2: QWord): QWord; inline;
  begin
    case tw17458_n of
      0: tw17458_innerfibo := tw17458_r1;
      1: tw17458_innerfibo := tw17458_r2;
      else tw17458_innerfibo := tw17458_innerfibo(tw17458_n - 1,tw17458_r2,tw17458_r1 + tw17458_r2);
    end;
  end;

begin
  tw17458_tailrecfibonacci := tw17458_innerfibo(tw17458_n,0,1);
end;
{$pop}

{ Case tw17836.pp }
{$push}
var
    tw17836_w,tw17836_w1: int64;
{$pop}

{ Case tw1936.pp }
{$push}
var
   tw1936_x,tw1936_y,tw1936_x1,tw1936_y1,tw1936_x2,tw1936_y2,tw1936_style: byte;
{$pop}

{ Case tw2028.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2028 }
{ Submitted by "Han Wentao" on  2002-07-04 }
{ e-mail: hanwentao@cnnb.net }
{$INLINE ON}
function tw2028_max(tw2028_a,tw2028_b:Byte):Byte; inline;
begin
  if tw2028_a>tw2028_b then
    tw2028_max:=tw2028_a
  else
    tw2028_max:=tw2028_b;
end;

var
 tw2028_l1,  tw2028_l2 : longint;
{$pop}

{ Case tw20821.pp }
{$push}
var
  tw20821_b : byte;
{$pop}

{ Case tw20998.pp }
{$push}
var
  tw20998_i : int64;
  tw20998_j, tw20998_k: longint;
{$pop}

{ Case tw21029.pp }
{$push}
{$r+}
{$inline on}

function tw21029_f(tw21029_y : byte) : byte; inline;
begin
  tw21029_f:=byte(not tw21029_y);
end;
{$pop}

{ Case tw28702.pp }
{$push}
var
  tw28702_l: longint;
{$pop}

{ Case tw26230.pp }
{$push}
const
    tw26230_c1 = 86400000000; //MCS in a day

var
    tw26230_ainput,
        tw26230_product : Int64;
{$pop}

{ Case tw18082.pp }
{$push}
var
  tw18082_l: longint;
{$ifdef cpu64}
  tw18082_i: int64;
{$endif}
{$pop}

{ Case tw2037.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2037 }
{ Submitted by "David Hagler" on  2002-07-11 }
{ e-mail: david@avimark.net }
{$R-}

const
  tw2037_file_flag_write_through = -2147483648;
  tw2037_file_attribute_normal = 128;

var
  tw2037_anattr : cardinal;
{$pop}

{ Case tw15633.pp }
{$push}
var tw15633_value : word;
    tw15633_code : Longint;
{$pop}

{ Case tw3774.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3774 }
{ Submitted by "Sergey@michint" on  2005-03-11 }
{ e-mail:  }
{$C+}

var
  tw3774_i, tw3774_ec: Integer;
{$pop}

{ Case tw39523.pp }
{$push}
var
  tw39523_w: Word;
  tw39523_code: Integer;
{$pop}

{ Case tw8177a.pp }
{$push}
var
  tw8177a_s : string;
  tw8177a_i : longint;
  tw8177a_err : word;
{$pop}


{$pop}

{ Case tb_integer_ranges_checked_run_01.pp }
{$push}
{ Integer conversions, alignment expressions and comparisons with range checking enabled. }
{ Original case IDs and variable scopes are retained below. }

{$R+}

{ Case tb0085.pp }
{$push}
{ Old file: tbs0099.pp }
{ wrong assembler code is genereatoed for range check   OK 0.99.1 (?) }


{$R+}
var tb0085_w:word;
    tb0085_s:Shortint;
{$pop}

{ Case tb0102.pp }
{$push}
{ Old file: tbs0121.pp }
{ cardinal -> byte conversion not work (and crashes)    OK 0.99.6 (FK) }

{$R+}
var

  tb0102_c : cardinal;
  tb0102_i : integer;
  tb0102_w : word;
  tb0102_b : byte;
  tb0102_si : shortint;
{$pop}

{ Case tb0343.pp }
{$push}
{$R+}
var
 tb0343_i : int64;
{$pop}

{ Case tb0362.pp }
{$push}
{$R+}

type
  tb0362_size_t = Cardinal;

function tb0362_cmsg_align(len: tb0362_size_t): tb0362_size_t;
begin
  tb0362_cmsg_align := (len + SizeOf(tb0362_size_t) - 1) and (not (SizeOf(tb0362_size_t) - 1));
end;
{$pop}

{ Case tb0447.pp }
{$push}
{$R+}
var
  tb0447_a : cardinal;
  tb0447_b : longint;
{$pop}

{ Case tb0533.pp }
{$push}
{$r+}

const
  tb0533_q: qword = 18446744073709551615;

var
  tb0533_i: int64;
  tb0533_code: longint;
{$pop}

{ Case tb0344.pp }
{$push}
{$R+}
var
  tb0344_s : string;
  tb0344_error : boolean;
{$pop}

{ Case tb0574.pp }
{$push}
{$r+}
{$q+}
var
  tb0574_i1,tb0574_i2 : int64;
{$pop}

{ Case tb0658.pp }
{$push}
{$r+,q+}

procedure tb0658_test(tb0658_i: int64);
begin
  if (tb0658_i>0) and (tb0658_i<$1fff) then
    halt(1);
end;
{$pop}

{ Case tw15304.pp }
{$push}
{$r+,q+}

var tw15304_a : LongWord;
{$pop}

{ Case tw14841.pp }
{$push}
{$r+,o+}
var
tw14841_b: byte;
tw14841_s: shortint;
{$pop}

{ Case tw10966.pp }
{$push}
{$r+}

const
  tw10966_ctnsneedjitparsing  = 1 shl 1;
type
  tw10966_tcodetreenodesubdesc = word;
var
  tw10966_subdesc: tw10966_tcodetreenodesubdesc;
  tw10966_l: longint;
//  c: cardinal;
{$pop}

{ Case tw11216.pp }
{$push}
{$R+}

var tw11216_li, tw11216_lj : Int64;
const tw11216_i = $7fffffffffffffff;
{$pop}


{$pop}

{ Case tb_integer_ranges_unchecked_run_01.pp }
{$push}
{ Integer narrowing, large literals and unsigned division with range checking disabled. }
{ Original case IDs and variable scopes are retained below. }

{$R-}

{ Case tb0077.pp }
{$push}
{ Old file: tbs0084.pp }
{  no more pascal type checking                          OK 0.99.1 (FK) }

{$R-}

{ Basic Pascal principles gone done the drain... !!!! }

var
 tb0077_v: word;
 tb0077_w: shortint;
 tb0077_z: byte;
 tb0077_y: integer;
{$pop}

{ Case tb0090.pp }
{$push}
{ Old file: tbs0106.pp }
{ typecasts are now ignored problem (NOT A bugs)         OK 0.99.1 }

{$R-}

{ I think this now occurs with most type casting... }
{ I think type casting is no longer considered??     }

Var
 tb0090_sel: Word;
 tb0090_sel2: byte;
{$pop}

{ Case tb0250.pp }
{$push}
{ Old file: tbs0290.pp }
{ problem with storing hex numbers in integers }

{ $R+ would give compile time errors }
{$R-}

var tb0250_i,tb0250_j : integer;
{$pop}

{ Case tb0598.pp }
{$push}
{$R-}

var
  tb0598_a: Cardinal;
  tb0598_b: QWord;
  tb0598_c1, tb0598_c2: QWord;
{$pop}

{ Case tb0336.pp }
{$push}
{ Explicitly disable overflow and range checks }
{$Q-}
{$R-}

var
   tb0336_l : longint;
   tb0336_d : dword;
   tb0336_s : string;
   tb0336_code : integer;

procedure tb0336_do_error(tb0336_l : longint);

  begin
     writeln('Error near number ',tb0336_l);
     halt(1);
  end;
{$pop}

{ Case tb0050.pp }
{$push}
{ Old file: tbs0056.pp }
{  shows a _very_ simple expression which generates     OK 0.99.1 (FK) }

(* This will compile
VAR N, E: Integer;*)

(* This will NOT compile*)
VAR tb0050_n, tb0050_e: LongInt;
{$pop}

{ Case tb0062.pp }
{$push}
{ Old file: tbs0068.pp }
{  Shows incorrect type of ofs()                        OK 0.99.1 (PFV and FK) }

{ As l is only a smallint, this
  test will almost always
  trigger a range check error,
  disable range check explicitly }
{$R-}
var
  tb0062_p : pointer;
  tb0062_l  : smallint;
{$pop}


{$pop}

{ Case tw0751.pp }
{$push}
var tw0751_x,tw0751_y:integer;

{$pop}

{ Case tw0784.pp }
{$push}
{$R-}
{ should compile if no range check on }


const
  tw0784_Limit   = 100000000; { Hundred millions }
  tw0784_One     =         1;

var
  tw0784_Huge: longint;


{$pop}

{ Case tw0918.pp }
{$push}


procedure tw0918_Test1;
var
  a: Integer;

    procedure Test2;
    begin
      a:= 0;
    end;
begin
end;


{$pop}

{ Case tw10233.pp }
{$push}
var
  tw10233_i: Byte;
  tw10233_w: word;
  tw10233_l: cardinal;
{$ifdef FPC}
  tw10233_g: qword;
{$endif FPC}

{$pop}

{ Case tw13281.pp }
{$push}
{$ifdef cpu64}
procedure tw13281_test64;
var
  tw13281_c: qword;
begin
  tw13281_c:=1;
  if interlockeddecrement64(tw13281_c)<>0 then
    halt(10);
  if interlockedincrement64(tw13281_c)<>1 then
    halt(20);
  if interlockedexchange64(tw13281_c,1234)<>1 then
    halt(30);
  if InterLockedExchangeAdd64(tw13281_c,5)<>1234 then
    halt(40);
  if InterlockedCompareExchange64(tw13281_c,qword($8000000000000035),1239)<>1239 then
    halt(50);
  if (tw13281_c<>qword($8000000000000035)) then
    halt(60);
end;
{$endif cpu64}

var
  tw13281_c: cardinal;

{$pop}

{ Case tw1699.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1699 }
{ Submitted by "SHADOW" on  2001-11-25 }
{ e-mail: mdikm@hotmail.com }
const
  tw1699_i : longint = 0;


procedure tw1699_nset(var d:byte;p,tw1699_c:byte;v:byte);
begin
  tw1699_i:=tw1699_i or 1;
end;

procedure tw1699_nset(var d:word;p,tw1699_c:byte;v:word);
begin
  tw1699_i:=tw1699_i or 2;
end;

procedure tw1699_nset(var d:cardinal;p,tw1699_c:byte;v:cardinal);
begin
  tw1699_i:=tw1699_i or 4;
end;

procedure tw1699_nset(var d:qword;p,tw1699_c:byte;v:qword);
begin
  tw1699_i:=tw1699_i or 8;
end;

var
  tw1699_b : byte;
  tw1699_w : word;
  tw1699_c : cardinal;
  tw1699_q : qword;

{$pop}

{ Case tw17342.pp }
{$push}
var
  tw17342_P1, tw17342_P2: PCardinal;
  tw17342_I: Integer;

{$pop}

{ Case tw17646.pp }
{$push}


var
  tw17646_i1: Word;
  tw17646_i2: LongWord;
  tw17646_i3: QWord;
  tw17646_cnt: longint;

{$pop}

{ Case tw18690.pp }
{$push}
Procedure tw18690_AllocFreeGiB;
  var
    p: pointer;
    RequestedSize: ptruint;
  Begin
    Writeln('-----------------------------');
    RequestedSize:=high(ptruint); // n GiB - 1
    Writeln('RequestedSize = ',RequestedSize,' bytes');
    getmem(p,RequestedSize);
    if (p<>nil) then
      halt(1);
  End;


{$pop}

{ Case tw1889.pp }
{$push}
var
    tw1889_t,tw1889_t1:int64;
    tw1889_tsclo,tw1889_tschi:cardinal;
    tw1889_f:int64;

{$pop}

{ Case tw1920.pp }
{$push}

VAR
        tw1920_X64     : Qword;

{$pop}

{ Case tw22326.pp }
{$push}
var
  tw22326_q1: QWord;

{$pop}

{ Case tw22331.pp }
{$push}
procedure tw22331_X;
var
  w, h: integer;
begin
  w:=1;
  h:=2;
  writeln(round(w / 2 - 0), round(h - 0));
  writeln(round(w / 2 - 138.809093), round(h - 661.165204));
  writeln(round(w / 2 - 138.683051), round(h - 661.003245));
  writeln(round(w / 2 - 138.556540), round(h - 660.840685));
  writeln(round(w / 2 - 138.429558), round(h - 660.677449));
  writeln(round(w / 2 - 138.302098), round(h - 660.513612));
  writeln(round(w / 2 - 138.174178), round(h - 660.349250));
  writeln(round(w / 2 - 138.045779), round(h - 660.184211));
  writeln(round(w / 2 - 137.916911), round(h - 660.018571));
  writeln(round(w / 2 - 137.787573), round(h - 659.852405));
  writeln(round(w / 2 - 137.657765), round(h - 659.685563));
  writeln(round(w / 2 - 137.527488), round(h - 659.518121));
  writeln(round(w / 2 - 137.396732), round(h - 659.350077));
  writeln(round(w / 2 - 137.265516), round(h - 659.181432));
  writeln(round(w / 2 - 137.133821), round(h - 659.012187));
  writeln(round(w / 2 - 137.001656), round(h - 658.842340));
  writeln(round(w / 2 - 136.869023), round(h - 658.671892));
  writeln(round(w / 2 - 136.735910), round(h - 658.500844));
  writeln(round(w / 2 - 136.602337), round(h - 658.329119));
  writeln(round(w / 2 - 136.468294), round(h - 658.156944));
  writeln(round(w / 2 - 136.333773), round(h - 657.984017));
  writeln(round(w / 2 - 136.198782), round(h - 657.810490));
  writeln(round(w / 2 - 136.063322), round(h - 657.636437));
  writeln(round(w / 2 - 135.927392), round(h - 657.461782));
  writeln(round(w / 2 - 135.790993), round(h - 657.286452));
  writeln(round(w / 2 - 135.654114), round(h - 657.110521));
  writeln(round(w / 2 - 135.516776), round(h - 656.933988));
  writeln(round(w / 2 - 135.378959), round(h - 656.756930));
  writeln(round(w / 2 - 135.240672), round(h - 656.579196));
  writeln(round(w / 2 - 135.101916), round(h - 656.400936));
  writeln(round(w / 2 - 134.962690), round(h - 656.222000));
  writeln(round(w / 2 - 134.822995), round(h - 656.042463));
  writeln(round(w / 2 - 134.682821), round(h - 655.862325));
  writeln(round(w / 2 - 134.542186), round(h - 655.681586));
  writeln(round(w / 2 - 134.147430), round(h - 655.174225));
  writeln(round(w / 2 - 134.006815), round(h - 654.993486));
  writeln(round(w / 2 - 133.866669), round(h - 654.813348));
  writeln(round(w / 2 - 133.727002), round(h - 654.633886));
  writeln(round(w / 2 - 133.607551), round(h - 654.480415));
  writeln(round(w / 2 - 133.488777), round(h - 654.287807));
  writeln(round(w / 2 - 133.370406), round(h - 654.095800));
  writeln(round(w / 2 - 133.252440), round(h - 653.904469));
  writeln(round(w / 2 - 133.134877), round(h - 653.713814));
  writeln(round(w / 2 - 133.017708), round(h - 653.523836));
  writeln(round(w / 2 - 132.900953), round(h - 653.334458));
  writeln(round(w / 2 - 132.784592), round(h - 653.145756));
  writeln(round(w / 2 - 132.668644), round(h - 652.957730));
  writeln(round(w / 2 - 132.553090), round(h - 652.770306));
  writeln(round(w / 2 - 132.437940), round(h - 652.583557));
  writeln(round(w / 2 - 132.323204), round(h - 652.397485));
  writeln(round(w / 2 - 132.208862), round(h - 652.212088));
  writeln(round(w / 2 - 132.094923), round(h - 652.027293));
  writeln(round(w / 2 - 131.981379), round(h - 651.843098));
  writeln(round(w / 2 - 131.868248), round(h - 651.659655));
  writeln(round(w / 2 - 131.755521), round(h - 651.476812));
  writeln(round(w / 2 - 131.643198), round(h - 651.294721));
  writeln(round(w / 2 - 131.531269), round(h - 651.113231));
  writeln(round(w / 2 - 131.419753), round(h - 650.932342));
  writeln(round(w / 2 - 131.308631), round(h - 650.752129));
  writeln(round(w / 2 - 131.197914), round(h - 650.572516));
  writeln(round(w / 2 - 131.087609), round(h - 650.393655));
  writeln(round(w / 2 - 130.977699), round(h - 650.215395));
  writeln(round(w / 2 - 130.868193), round(h - 650.037812));
  writeln(round(w / 2 - 130.759090), round(h - 649.860904));
  writeln(round(w / 2 - 130.650391), round(h - 649.684597));
  writeln(round(w / 2 - 130.542087), round(h - 649.508966));
  writeln(round(w / 2 - 130.434196), round(h - 649.334011));
  writeln(round(w / 2 - 130.326708), round(h - 649.159657));
  writeln(round(w / 2 - 130.219615), round(h - 648.985980));
  writeln(round(w / 2 - 130.112935), round(h - 648.813053));
  writeln(round(w / 2 - 130.006650), round(h - 648.640577));
  writeln(round(w / 2 - 129.900768), round(h - 648.468928));
  writeln(round(w / 2 - 129.795290), round(h - 648.297879));
  writeln(round(w / 2 - 129.690215), round(h - 648.127507));
  writeln(round(w / 2 - 129.585554), round(h - 647.957735));
  writeln(round(w / 2 - 129.481278), round(h - 647.788565));
  writeln(round(w / 2 - 129.377415), round(h - 647.620146));
  writeln(round(w / 2 - 129.273956), round(h - 647.452402));
  writeln(round(w / 2 - 129.170901), round(h - 647.285260));
  writeln(round(w / 2 - 129.068240), round(h - 647.118794));
  writeln(round(w / 2 - 128.965992), round(h - 646.952929));
  writeln(round(w / 2 - 128.864138), round(h - 646.787815));
  writeln(round(w / 2 - 128.762689), round(h - 646.623302));
  writeln(round(w / 2 - 128.661652), round(h - 646.459390));
  writeln(round(w / 2 - 128.561010), round(h - 646.296154));
  writeln(round(w / 2 - 128.460771), round(h - 646.133594));
  writeln(round(w / 2 - 128.360937), round(h - 645.971710));
  writeln(round(w / 2 - 128.261506), round(h - 645.810502));
  writeln(round(w / 2 - 128.162469), round(h - 645.649895));
  writeln(round(w / 2 - 128.063846), round(h - 645.489889));
  writeln(round(w / 2 - 127.965627), round(h - 645.330635));
  writeln(round(w / 2 - 127.894723), round(h - 645.215626));
  writeln(round(w / 2 - 127.808626), round(h - 645.050587));
  writeln(round(w / 2 - 127.722895), round(h - 644.886149));
  writeln(round(w / 2 - 127.637511), round(h - 644.722462));
  writeln(round(w / 2 - 127.552485), round(h - 644.559452));
  writeln(round(w / 2 - 127.467815), round(h - 644.397042));
  writeln(round(w / 2 - 127.383502), round(h - 644.235383));
  writeln(round(w / 2 - 127.299537), round(h - 644.074476));
  writeln(round(w / 2 - 127.215937), round(h - 643.914170));
  writeln(round(w / 2 - 127.132695), round(h - 643.754540));
  writeln(round(w / 2 - 127.049800), round(h - 643.595585));
  writeln(round(w / 2 - 126.967261), round(h - 643.437307));
  writeln(round(w / 2 - 126.885080), round(h - 643.279780));
  writeln(round(w / 2 - 126.803255), round(h - 643.122854));
  writeln(round(w / 2 - 126.721788), round(h - 642.966680));
  writeln(round(w / 2 - 126.640677), round(h - 642.811106));
  writeln(round(w / 2 - 126.559923), round(h - 642.656359));
  writeln(round(w / 2 - 126.479516), round(h - 642.502137));
  writeln(round(w / 2 - 126.399475), round(h - 642.348667));
  writeln(round(w / 2 - 126.319782), round(h - 642.195872));
  writeln(round(w / 2 - 126.240446), round(h - 642.043754));
  writeln(round(w / 2 - 126.161467), round(h - 641.892312));
  writeln(round(w / 2 - 126.082844), round(h - 641.741546));
  writeln(round(w / 2 - 126.004578), round(h - 641.591456));
  writeln(round(w / 2 - 125.926669), round(h - 641.442117));
  writeln(round(w / 2 - 125.849108), round(h - 641.293379));
  writeln(round(w / 2 - 125.771913), round(h - 641.145393));
  writeln(round(w / 2 - 125.695065), round(h - 640.998007));
  writeln(round(w / 2 - 125.618583), round(h - 640.851372));
  writeln(round(w / 2 - 125.542449), round(h - 640.705414));
  writeln(round(w / 2 - 125.466671), round(h - 640.560132));
  writeln(round(w / 2 - 125.391251), round(h - 640.415525));
  writeln(round(w / 2 - 125.316178), round(h - 640.271595));
  writeln(round(w / 2 - 125.241471), round(h - 640.128341));
  writeln(round(w / 2 - 125.167121), round(h - 639.985763));
  writeln(round(w / 2 - 125.093118), round(h - 639.843861));
  writeln(round(w / 2 - 125.019472), round(h - 639.702711));
  writeln(round(w / 2 - 124.873260), round(h - 639.422287));
end;

{$pop}

{ Case tw2897.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2897 }
{ Submitted by "C Western" on  2004-01-17 }
{ e-mail: mftq75@dsl.pipex.com }


{$S+}

procedure tw2897_Show(v: Integer);
begin
  WriteLn(v);
  if v<>27 then
    begin
      writeln('Error!');
      halt(1);
    end;
end;


{$pop}

{ Case tw2916.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2916 }
{ Submitted by "Ivo Steinmann" on  2004-01-24 }
{ e-mail: isteinmann@bluewin.ch }

var
  tw2916_x :longint;

{$pop}

{ Case tw30035.pp }
{$push}
var
  tw30035_i64: Int64;
  tw30035_qa, tw30035_qb: DWord;

{$pop}

{ Case tw30035a.pp }
{$push}
var
  tw30035a_i64: Int64;
  tw30035a_qa, tw30035a_qb: DWord;

{$pop}

{ Case tw34385a.pp }
{$push}
{$r+}


const
  tw34385a_w : longint = 123;
  tw34385a_n : longint = 48;
  tw34385a_m : longint = -5;
  tw34385a_k : longint = low(longint);

{$pop}

{ Case tw35878a.pp }
{$push}
var
  tw35878a_i, tw35878a_rand, tw35878a_val: int64;

{$pop}

{ Case tw36587.pp }
{$push}
{$R-}
{$Q-}

const
  tw36587_A1 = 1000000;
  tw36587_B1 = 60;
  tw36587_C1 = 6000000;
  tw36587_T1 = tw36587_A1*tw36587_B1;
  tw36587_T2 = tw36587_A1*tw36587_C1;

procedure tw36587_dotest(P: longint);
var
  i64: Int64;
begin
  i64 := 0;
  i64 := i64 + P * tw36587_B1 * int64(tw36587_A1);
  writeln(i64);
  if i64 <> P*int64(tw36587_T1) then
    Halt(1);

  i64 := 0;
  i64 := i64 + P * tw36587_B1 * tw36587_A1;
  writeln(i64);
  if i64 <> P*tw36587_T1 then
    Halt(2);

  i64 := 0;
  i64 := i64 + P * tw36587_C1 * tw36587_A1;
  writeln(i64);
{$ifdef CPUINT64}
  if i64 <> P*tw36587_T2 then
{$else CPUINT64}
  if i64 <> P*Longint(tw36587_T2) then
{$endif CPUINT64}
    Halt(3);
end;


{$pop}

{ Case tw36589.pp }
{$push}
var tw36589_k : longint;

{$pop}

{ Case tw37427.pp }
{$push}



{$Q+}

function tw37427_NativeGetHashBytes: Byte;
var
   LBitSize: Int64;
   bob: byte;
begin
  bob := LBitSize and $FF;
end;


{$pop}

{ Case tw39615a.pp }
{$push}
{ $define unsigned}
const
	tw39615a_Divisor = 17;
	tw39615a_TestRange = 3 * tw39615a_Divisor;
var
	tw39615a_i, tw39615a_x, tw39615a_r1, tw39615a_r2: {$ifdef unsigned} uint32 {$else} int32 {$endif};
	tw39615a_ok: boolean;

{$pop}

{ Case tw3967.pp }
{$push}
{ Source provided for Free Pascal Bug Report 3967 }
{ Submitted by "luoyonggang" on  2005-05-14 }
{ e-mail: luoyonggang@gmail.com }
var
  tw3967_i,tw3967_j,tw3967_n,tw3967_m,tw3967_k,tw3967_l:longint;
  tw3967_o,tw3967_p,tw3967_q,tw3967_s:int64;

{$pop}

{ Case tw4055.pp }
{$push}
{$WRITEABLECONST OFF}

procedure tw4055_TestBuf(const Buf; Size: Integer);
begin
end;

const tw4055_A : Byte = 1;


{$pop}

{ Case tw4058.pp }
{$push}
{$q+}


var tw4058_i, tw4058_j1, tw4058_j2 : LongInt;


{$pop}

{ Case tw4152.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4152 }
{ Submitted by "C Western" on  2005-07-03 }
{ e-mail: mftq75@dsl.pipex.com }
{R+}{Q+}
var
  tw4152_p:^Byte;
  tw4152_c:Byte;
  tw4152_d:Integer;
{$ifdef cpu64}
  tw4152_v : qword;
{$else}
  tw4152_v : cardinal;
{$endif}

{$pop}

{ Case tw4253.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4253 }
{ Submitted by "Gerhard" on  2005-08-03 }
{ e-mail: gs@g--s.de }


  var
//    Count : -high ( cardinal )..high ( cardinal ) ;
    tw4253_Count : int64 ;
    tw4253_long : longint ;

  
{$pop}

{ Case tw4308.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4308 }
{ Submitted by "Olle" on  2005-08-22 }
{ e-mail: olle.r@automagika.se }


	procedure tw4308_ZeroBlock (startAddr: PtrUInt; length: SizeUInt);

		var
			i: PtrUInt;

	begin
		for i := startAddr to startAddr + length - 1 do
			PByte(i)^ := 0;
	end;


{$pop}

{ Case tw4428.pp }
{$push}
procedure tw4428_p(i1,i2,i3,i4,i5,i6,i7,i8 : longint;i : int64);
  begin
    if (i+i <> 22222222222) then
      halt(1);
  end;


{$pop}

{ Case tw4537.pp }
{$push}
procedure tw4537_foo;
  begin
    exit();
  end;

function tw4537_bar: integer;
  begin
    exit(42);
  end;


{$pop}

{ Case tw4881.pp }
{$push}
{ Source provided for Free Pascal Bug Report 4881 }
{ Submitted by "Jasper Neumann" on  2006-03-07 }
{ e-mail: _-jane-_@web.de }
type
  tw4881_openstring=integer;

procedure tw4881_test(var tw4881_x:tw4881_openstring);
begin end;

var
  tw4881_x: tw4881_openstring;

{$pop}

{ Case tw6684.pp }
{$push}
Var
  tw6684_D : LongInt;
  tw6684_d1,tw6684_d2 : int64;


{$pop}

{ Case tw6742.pp }
{$push}
type
  tw6742_openstring=integer;

procedure tw6742_test(var tw6742_x:tw6742_openstring);
begin
  writeln(tw6742_x);
end;

var
  tw6742_x: tw6742_openstring;

{$pop}

{ Case tw8870.pp }
{$push}
{$q+}
{$r+}

type
   tw8870_range = 0..32;
var
   tw8870_a,tw8870_b : Cardinal;
   tw8870_one : tw8870_range;

{$pop}

{ Case tw8883.pp }
{$push}
procedure tw8883_DoTest;
var
  i, j, cnt: longint;
begin
  cnt:=0;
  j:=1;
  for i:=0 to j do
  begin
    Inc(cnt);
    Dec(j);
  end;

  writeln(cnt);
  if cnt <> 2 then
  begin
    writeln('Test failed!');
    Halt(1);
  end;
  writeln('Test OK.');
end;


{$pop}

{ Case tw9108.pp }
{$push}


function tw9108_Func(a:longint): longint;
begin
  if (a >= 0) then tw9108_Func:=Trunc(1.0*a) else tw9108_Func:=-Trunc(1.0*a);
end;


{$pop}

begin

{ Case tb0147.pp }
{$push}

begin
  nexus_consolidated_tests.tb0147_l:=1;
end;
{$pop}

{ Case tb_integer_codegen_default_run_01.pp }
{$push}

{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$INLINE ON}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$r+}
{$inline on}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
{$push}
{$ifdef cpu64}
{$endif}
{$pop}
{$push}
{$R-}
{$pop}
{$push}
{$pop}
{$push}
{$C+}
{$pop}
{$push}
{$pop}
{$push}
{$pop}
begin
  { Case tw0802.pp }
  {$push}

begin
  writeln('"',tw0802_testf(0,-1,'A'),'"');
end;
  {$pop}

  { Case tw1046.pp }
  {$push}

begin
  tw1046_test2(1);
end;
  {$pop}

  { Case tw10863.pp }
  {$push}

begin
  tw10863_test;
end;
  {$pop}

  { Case tw12237.pp }
  {$push}

begin
  if (tw12237_f<>-2) then
    halt(1);
end;
  {$pop}

  { Case tw17458.pp }
  {$push}

begin
  if tw17458_tailrecfibonacci(10)<>55 then
    halt(1);
end;
  {$pop}

  { Case tw17836.pp }
  {$push}

begin
    tw17836_w1:=-1;
    tw17836_w:=tw17836_w1 div (int64(1) shl 33);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(1);
    tw17836_w:=tw17836_w1 div (int64(1) shl 32);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(2);
    tw17836_w:=tw17836_w1 div (int64(1) shl 31);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(3);
    tw17836_w:=tw17836_w1 div (int64(1) shl 5);
    system.writeln(tw17836_w);
    if tw17836_w<>0 then
      halt(4);
    end;
  {$pop}

  { Case tw1936.pp }
  {$push}

begin
   tw1936_x := 4;
   tw1936_y := 5;
   tw1936_x1 := 3;
   tw1936_x2 := 5;
   tw1936_y1 := 4;
   tw1936_y2 := 6;
   tw1936_style := 7;

   if ((tw1936_style=0) and (tw1936_x in [tw1936_x1..tw1936_x2]) and (tw1936_y in [tw1936_y1..tw1936_y2]))
   or ((tw1936_style=6) and (tw1936_x in [succ(tw1936_x1)..pred(tw1936_x2)]) and (tw1936_y in [tw1936_y1+3..pred(tw1936_y2)]))
   or ((tw1936_style <> 0) and (tw1936_style <> 6) and  (tw1936_x in [succ(tw1936_x1)..pred(tw1936_x2)]) and (tw1936_y in [succ(tw1936_y1)..pred(tw1936_y2)]))
   then
   begin
      writeln ('OK');
   end
   else
   begin
     writeln('ERROR');
     halt(1);
   end;
end;
  {$pop}

  { Case tw2028.pp }
  {$push}
{$inline on}
begin
  tw2028_l1:=tw2028_max(1,2);
  tw2028_l2:=tw2028_max(2,1);
  if tw2028_l1 <> 2 then
   begin
     WriteLn('Error!');
     halt(1);
   end;
  if tw2028_l2 <> 2 then
   begin
     WriteLn('Error!');
     halt(1);
   end;
end;
  {$pop}

  { Case tw20821.pp }
  {$push}

begin
  tw20821_b:=170;
  if tw20821_b<>Byte(#%10101010) then
    halt(1);
  if tw20821_b<>Byte(%10101010) then
    halt(1);
  if tw20821_b<>%10101010 then
    halt(1);
  WriteLn('Ok');
end;
  {$pop}

  { Case tw20998.pp }
  {$push}

begin
  tw20998_k:=64;
  for tw20998_j:=6400 to 6464 do
    begin
      tw20998_i:=tw20998_j;
      if (tw20998_i div 64) <> (tw20998_i div tw20998_k) then
        halt(1);
    end;
  tw20998_i:=6500;
  tw20998_i:=tw20998_i div 65;
  if tw20998_i<>100 then
    halt(1);
  for tw20998_j:=-6400 downto -6464 do
    begin
      tw20998_i:=tw20998_j;
      if (tw20998_i div 64) <> (tw20998_i div tw20998_k) then
        halt(2);
    end;
  writeln('ok');
end;
  {$pop}

  { Case tw21029.pp }
  {$push}
{$R+}
{$inline on}
BEGIN
  if tw21029_f(1)<>254 then
    halt(1);
END;
  {$pop}

  { Case tw28702.pp }
  {$push}

begin
  tw28702_l:=5;
  { dummy random to prevent constant propagation }
  if ((tw28702_l+random(1))div -1)<>-5 then
    halt(1);
end;
  {$pop}

  { Case tw26230.pp }
  {$push}

begin
    tw26230_ainput := 1;
    //asm int3 end; //debug trap; `disassemble`
    tw26230_product := tw26230_ainput * tw26230_c1;
    WriteLn(tw26230_ainput, ' * ', tw26230_c1, ' = ', tw26230_product);
    if tw26230_product <> 86400000000 then
    begin
      Writeln('Error!');
      Halt(1);
    end
    else
      Writeln('Ok');
end;
  {$pop}

  { Case tw18082.pp }
  {$push}

begin
  tw18082_l:=-123;
  if interlockedcompareexchange(tw18082_l,-1,124)<>-123 then
    halt(1);
  if tw18082_l<>-123 then
    halt(2);
  if interlockedcompareexchange(tw18082_l,-1,-123)<>-123 then
    halt(3);
  if tw18082_l<>-1 then
    halt(4);

{$ifdef cpu64}
  tw18082_i:=-123;
  if interlockedcompareexchange64(tw18082_i,-1,124)<>-123 then
    halt(5);
  if tw18082_i<>-123 then
    halt(6);
  if interlockedcompareexchange64(tw18082_i,-1,-123)<>-123 then
    halt(7);
  if tw18082_i<>-1 then
    halt(8);
{$endif}
end;
  {$pop}

  { Case tw2037.pp }
  {$push}
{$R-}
begin
  tw2037_anattr := tw2037_file_flag_write_through or tw2037_file_attribute_normal;
end;
  {$pop}

  { Case tw15633.pp }
  {$push}

begin
  Val('4294901772', tw15633_value, tw15633_code);
  writeln(tw15633_code);
  if tw15633_code<>6 then
    halt(1);
end;
  {$pop}

  { Case tw3774.pp }
  {$push}
{$C+}
begin
  Val('0x123', tw3774_i, tw3774_ec);
  Assert(tw3774_ec=0);
  Assert(tw3774_i=$123);
  writeln('ok');
end;
  {$pop}

  { Case tw39523.pp }
  {$push}

begin
  Val('-1',tw39523_w,tw39523_code);
  writeln('Code: ',tw39523_code); //outputs: 2
  if tw39523_code<>1 then
    halt(1);
  Val('-0x1',tw39523_w,tw39523_code);
  writeln('Code: ',tw39523_code); //outputs: 4
  if tw39523_code<>1 then
    halt(2);
end;
  {$pop}

  { Case tw8177a.pp }
  {$push}

begin
  tw8177a_s:='';
  val(tw8177a_s,tw8177a_i,tw8177a_err);
  if tw8177a_err=0 then
    begin
      Writeln('Error: empty string is a valid input for val function');
      Halt(1);
    end
  else
    begin
      Writeln('Correct: empty string is a not valid input for val function');
    end;
  tw8177a_s:=#0;
  val(tw8177a_s,tw8177a_i,tw8177a_err);
  if tw8177a_err=0 then
    begin
      Writeln('Error: #0 string is a valid input for val function');
      Halt(1);
    end
  else
    begin
      Writeln('Correct: #0 string is a not valid input for val function');
    end;
end;
  {$pop}

end;
{$pop}

{ Case tb_integer_ranges_checked_run_01.pp }
{$push}
{$R+}
{$push}
{$R+}
{$pop}
{$push}
{$R+}
{$pop}
{$push}
{$R+}
{$pop}
{$push}
{$R+}
{$pop}
{$push}
{$R+}
{$pop}
{$push}
{$r+}
{$pop}
{$push}
{$R+}
{$pop}
{$push}
{$r+}
{$q+}
{$pop}
{$push}
{$r+,q+}
{$pop}
{$push}
{$r+,q+}
{$pop}
{$push}
{$r+,o+}
{$pop}
{$push}
{$r+}
{$pop}
{$push}
{$R+}
{$pop}
begin
  { Case tb0085.pp }
  {$push}
begin
  tb0085_w := tb0085_s;
end;
  {$pop}

  { Case tb0102.pp }
  {$push}
begin
  tb0102_w:=tb0102_c;
  tb0102_i:=tb0102_c;
  tb0102_b:=tb0102_c;
  tb0102_b:=tb0102_si;
end;
  {$pop}

  { Case tb0343.pp }
  {$push}
begin
  tb0343_i:=high(cardinal);
end;
  {$pop}

  { Case tb0362.pp }
  {$push}
begin
end;
  {$pop}

  { Case tb0447.pp }
  {$push}
begin
  tb0447_a := 0;
  tb0447_b := -1;
  if tb0447_a > tb0447_b then
    writeln ('OK')
  else
    halt(1);
end;
  {$pop}

  { Case tb0533.pp }
  {$push}
{$R+}
begin
  val('18446744073709551615',tb0533_i,tb0533_code);
  if (tb0533_code = 0) then
    halt(1);
  val('-9223372036854775808',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> low(int64)) then
    halt(2);
  val('9223372036854775807',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> high(int64)) then
    halt(3);
  val('$8000000000000000',tb0533_i,tb0533_code);
  if (tb0533_code <> 0) or
     (tb0533_i <> low(int64)) then
    halt(4);
end;
  {$pop}

  { Case tb0344.pp }
  {$push}
{$R+}
begin
  tb0344_error:=false;
  str(high(int64),tb0344_s);
  if tb0344_s<>'9223372036854775807' then
   begin
     writeln('high(int64) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
  str(low(int64),tb0344_s);
  if tb0344_s<>'-9223372036854775808' then
   begin
     writeln('low(int64) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
{$ifdef fpc}
  str(high(qword),tb0344_s);
  if tb0344_s<>'18446744073709551615' then
   begin
     writeln('high(qword) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
  str(low(qword),tb0344_s);
  if tb0344_s<>'0' then
   begin
     writeln('low(qword) error!: "',tb0344_s,'"');
     tb0344_error:=true;
   end;
{$endif}
  if tb0344_error then
   halt(1);
end;
  {$pop}

  { Case tb0574.pp }
  {$push}
{$R+,Q+}
begin
  tb0574_i1:=$100000000;
  tb0574_i2:=$800000000;
  inc(tb0574_i1,tb0574_i2);
  if tb0574_i1<>$900000000 then
    halt(1);
  writeln('ok');
end;
  {$pop}

  { Case tb0658.pp }
  {$push}
{$R+,Q+}
begin
  tb0658_test(0);
end;
  {$pop}

  { Case tw15304.pp }
  {$push}
{$R+,Q+}
begin
  tw15304_a := $0FFFFFFF;
  Inc(tw15304_a, LongWord($F0000000));
  // no runtime error if the above line is changed to:
  // A := A + LongWord($F0000000);
end;
  {$pop}

  { Case tw14841.pp }
  {$push}
{$R+,O+}
begin
  tw14841_b:=57;
  tw14841_s:=-1;
  inc(tw14841_b, tw14841_s);
  if tw14841_b<>56 then
    halt(1);
end;
  {$pop}

  { Case tw10966.pp }
  {$push}
{$R+}
begin
  tw10966_subdesc := 1;
// fails
//  SubDesc := not 2;
  tw10966_l := not(2);
// fails
//  c := not(2);
  tw10966_l := not tw10966_ctnsneedjitparsing;
// fails
//  c := not ctnsNeedJITParsing;
  tw10966_subdesc := tw10966_subdesc and (not 2);
  tw10966_subdesc := tw10966_subdesc and (not (1 shl 1));
  tw10966_subdesc := tw10966_subdesc and (not tw10966_ctnsneedjitparsing);
end;
  {$pop}

  { Case tw11216.pp }
  {$push}
{$R+}
begin
  if (1-tw11216_i)<>(-tw11216_i+1) then
    halt(1);

  writeln(1-tw11216_i);
  writeln(-tw11216_i+1);

  tw11216_li := 1-tw11216_i;
  tw11216_lj := -tw11216_i + 1;
  if tw11216_li<>tw11216_lj then
    halt(2);

  if (tw11216_li<>-9223372036854775806) then
    halt(3);
end;
  {$pop}

end;
{$pop}

{ Case tb_integer_ranges_unchecked_run_01.pp }
{$push}
{$R-}
{$push}
{$R-}
{$pop}
{$push}
{$R-}
{$pop}
{$push}
{$R-}
{$pop}
{$push}
{$R-}
{$pop}
{$push}
{$Q-}
{$R-}
{$pop}
{$push}
{$pop}
{$push}
{$R-}
{$pop}
begin
  { Case tb0077.pp }
  {$push}
Begin
 tb0077_y:=64000;
 tb0077_z:=32767;
 tb0077_w:=64000;
 tb0077_v:=-1;
end;
  {$pop}

  { Case tb0090.pp }
  {$push}
Begin
 tb0090_sel:=word($7fffffff);
 tb0090_sel2:=byte($7fff);
end;
  {$pop}

  { Case tb0250.pp }
  {$push}
begin
  { the following line gives a warning and $ffff is changed to $7fff!}
  tb0250_i := $ffff;
  if tb0250_i <> $ffff then
    begin
      Writeln('i:=$ffff loads ',tb0250_i,'$7fff if i is integer !');
    end;
  tb0250_j := 65535;
  if tb0250_j <> 65535 then
    begin
      Writeln('j:=65535 loads ',tb0250_j,' if j is integer !');
    end;
  if ($ffff=65535) and (tb0250_i<>tb0250_j) then
    begin
      Writeln('i and j are different !!!');
      Halt(1);
    end;
end;
  {$pop}

  { Case tb0598.pp }
  {$push}
begin
  tb0598_a := 1000000;
  tb0598_b := 10000000000000000000;
  tb0598_c1 := tb0598_b div tb0598_a;
  tb0598_c2 := 10000000000000000000 div tb0598_a;
  Write(tb0598_c1, ' = ', tb0598_c2, ': ');
  if (tb0598_c1 <> tb0598_c2) or (tb0598_c2 <> 10000000000000) then
  begin
    Writeln('FAIL');
    halt(1);
  end
  else
    Writeln('OK');
end;
  {$pop}

  { Case tb0336.pp }
  {$push}
{$Q-}
{$R-}
begin
   tb0336_s:='4294967295';
   val(tb0336_s,tb0336_d,tb0336_code);
   if tb0336_code<>0 then
     tb0336_do_error(1);

   tb0336_s:='4294967296';
   val(tb0336_s,tb0336_d,tb0336_code);
   if tb0336_code=0 then
     tb0336_do_error(1);

   tb0336_s:='2147483647';
   val(tb0336_s,tb0336_l,tb0336_code);
   if tb0336_code<>0 then
     tb0336_do_error(3);

   tb0336_s:='2147483648';
   val(tb0336_s,tb0336_l,tb0336_code);
   if tb0336_code=0 then
     tb0336_do_error(4);

   tb0336_s:='-2147483648';
   val(tb0336_s,tb0336_l,tb0336_code);
   if tb0336_code<>0 then
     tb0336_do_error(5);

   tb0336_s:='-2147483649';
   val(tb0336_s,tb0336_l,tb0336_code);
   if tb0336_code=0 then
     tb0336_do_error(6);
end;
  {$pop}

  { Case tb0050.pp }
  {$push}
BEGIN
   tb0050_e := 2;
   WriteLn(tb0050_e);
   tb0050_n := 44 - tb0050_e;
   WriteLn(tb0050_n);
END;
  {$pop}

  { Case tb0062.pp }
  {$push}
{$R-}
begin
  tb0062_l:=Ofs(tb0062_p); { Ofs returns a pointer type !? }

end;
  {$pop}

end;
{$pop}

{ Case tw0751.pp }
{$push}

begin

tw0751_y:=5;
for tw0751_x:=0 to 10 do if tw0751_x<tw0751_y then writeln(tw0751_x);
end;
{$pop}

{ Case tw0784.pp }
{$push}
{$R-}
begin
    tw0784_Huge := tw0784_Limit + tw0784_One;

    writeln(tw0784_One, ' is the lower bound');
    writeln(tw0784_Limit, ' is the upper bound');

    if tw0784_Limit in [tw0784_One .. tw0784_Limit] then
      writeln(tw0784_Limit, ' is within the range')
    else
      writeln(tw0784_Limit, ' is out of the range');

    if tw0784_Huge in [tw0784_One .. tw0784_Limit] then
      writeln(tw0784_Huge, ' is within the range')
    else
      writeln(tw0784_Huge, ' is out of the range')
end;
{$pop}

{ Case tw0918.pp }
{$push}

begin
end;
{$pop}

{ Case tw10233.pp }
{$push}
{$ifdef FPC}
{$endif FPC}
begin
  tw10233_i := $80;
  if Byte(ByteBool(tw10233_i))<>$80 then
    halt(1);
  if Word(WordBool(tw10233_i))<>$80 then
    halt(11);
  if LongInt(LongBool(tw10233_i))<>$80 then
    halt(12);
  tw10233_w := $8000;
  if Word(WordBool(tw10233_w))<>$8000 then
    halt(2);
  tw10233_l := $80000000;
  if Cardinal(LongBool(tw10233_l))<>$80000000 then
    halt(3);
{$ifdef FPC}
  tw10233_g := qword($8000000000000000);
  if qword(qwordBool(tw10233_g))<>qword($8000000000000000) then
    halt(4);
{$endif FPC}

  if Byte(ByteBool(WordBool(tw10233_w)))<>high(byte) then
    halt(5);
  if Byte(ByteBool(tw10233_w))<>0 then
    halt(51);
  if Word(WordBool(LongBool(tw10233_l)))<>high(word) then
    halt(6);
  if Word(WordBool(tw10233_l))<>0 then
    halt(61);
{$ifdef FPC}
  if Cardinal(LongBool(qwordBool(tw10233_g)))<>high(cardinal) then
    halt(7);
  if Cardinal(LongBool(tw10233_g))<>0 then
    halt(7);
{$endif FPC}
  writeln('Test OK.');
end;
{$pop}

{ Case tw13281.pp }
{$push}
{$ifdef cpu64}
{$endif cpu64}
begin
  tw13281_c:=1;
  if interlockeddecrement(tw13281_c)<>0 then
    halt(1);
  if (tw13281_c<>0) then
    halt(11);
  if interlockedincrement(tw13281_c)<>1 then
    halt(2);
  if (tw13281_c<>1) then
    halt(12);
  if interlockedexchange(tw13281_c,1234)<>1 then
    halt(3);
  if (tw13281_c<>1234) then
    halt(13);
  if InterLockedExchangeAdd(tw13281_c,5)<>1234 then
    halt(4);
  if (tw13281_c<>1239) then
    halt(14);
  if InterlockedCompareExchange(tw13281_c,$80000000,1239)<>1239 then
    halt(5);
  if (tw13281_c<>$80000000) then
    halt(6);
end;
{$pop}

{ Case tw1699.pp }
{$push}

begin
  tw1699_nset(tw1699_b,0,0,0);
  tw1699_nset(tw1699_w,0,0,0);
  tw1699_nset(tw1699_c,0,0,0);
  tw1699_nset(tw1699_q,0,0,0);
  if tw1699_i<>15 then
   begin
     Writeln('Error');
     halt(1);
   end;
end;
{$pop}

{ Case tw17342.pp }
{$push}

begin

  // random pointer
  tw17342_P1 := @tw17342_I;
  tw17342_P2 := tw17342_P1;

  Inc(tw17342_P1, 97);
  Inc(tw17342_P1, -97);

  if (tw17342_P1 <> tw17342_P2) then
    halt(1);
end;
{$pop}

{ Case tw17646.pp }
{$push}

begin
  tw17646_cnt:=0;
  for tw17646_i1 :=  High(tw17646_i1)-2 to High(tw17646_i1) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(1);

  tw17646_cnt:=0;
  for tw17646_i2 := high(tw17646_i2)-2 to High(tw17646_i2) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(2);

{$ifdef cpu64}
  tw17646_cnt:=0;
  for tw17646_i3 := high(tw17646_i3)-2 to High(tw17646_i3) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(3);
{$endif}

  tw17646_cnt:=0;
  for tw17646_i1 := high(word)-2 to High(Word) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(4);

  tw17646_cnt:=0;
  for tw17646_i2 := high(longword)-2 to High(LongWord) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(5);

{$ifdef cpu64}
  tw17646_cnt:=0;
  for tw17646_i3 := high(qword)-2 to High(QWord) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(6);
{$endif}

  tw17646_cnt:=0;
  for tw17646_i1 := word($ffff)-2 to Word($FFFF) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(7);

  tw17646_cnt:=0;
  for tw17646_i2 := longword($ffffffff)-2 to LongWord($FFFFFFFF) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(8);

{$ifdef cpu64}
  tw17646_cnt:=0;
  for tw17646_i3 := QWord($FFFFFFFFFFFFFFFF)-2 to QWord($FFFFFFFFFFFFFFFF) do
    inc(tw17646_cnt);
  if tw17646_cnt<>3 then
    halt(9);
{$endif}
end;
{$pop}

{ Case tw18690.pp }
{$push}

Begin
  ReturnNilIfGrowHeapFails:=true;
  tw18690_AllocFreeGiB;
End;
{$pop}

{ Case tw1889.pp }
{$push}

begin
  tw1889_tschi:=1;
  tw1889_tsclo:=0;
  tw1889_f:=1;
  tw1889_t1:=2;
  tw1889_t:=1;
  writeln(((Int64(tw1889_tscHi) shl 32 + tw1889_tscLo) / ((tw1889_T1-tw1889_T) / tw1889_F)));
end;
{$pop}

{ Case tw1920.pp }
{$push}

BEGIN
        tw1920_X64:=$123456789A;
END;
{$pop}

{ Case tw22326.pp }
{$push}

begin
  tw22326_q1:=$1020304050607080;
  if (tw22326_q1 shl 0) <> tw22326_q1 then
    halt(1);
  if (tw22326_q1 shr 0) <> tw22326_q1 then
    halt(2);
end;
{$pop}

{ Case tw22331.pp }
{$push}

begin
  tw22331_X
end;
{$pop}

{ Case tw2897.pp }
{$push}
{$S+}
begin
  tw2897_Show(27)
end;
{$pop}

{ Case tw2916.pp }
{$push}

begin
{$IF Defined(fpc)}
  writeln('do_foo');
  inc(tw2916_x);
{$ELSEIF Defined(fpc)}
  writeln('do_bar');
{$ELSEIF Defined(fpc)}
  writeln('fpc');
{$ELSE}
  writeln('else');
{$IFEND}

{$IF Defined(fpc1)}
  writeln('do_foo');
{$ELSEIF Defined(fpc)}
  writeln('do_bar');
  inc(tw2916_x);
{$ELSEIF Defined(fpc)}
  writeln('fpc');
{$ELSE}
  writeln('else');
{$IFEND}

{$IF Defined(fpc1)}
  writeln('do_foo');
{$ELSEIF Defined(fpc1)}
  writeln('do_bar');
{$ELSEIF Defined(fpc)}
  writeln('fpc');
  inc(tw2916_x);
{$ELSE}
  writeln('else');
{$IFEND}

{$IF Defined(fpc1)}
  writeln('do_foo');
{$ELSEIF Defined(fpc1)}
  writeln('do_bar');
{$ELSEIF Defined(fpc1)}
  writeln('fpc');
{$ELSE}
  writeln('else');
  inc(tw2916_x);
{$IFEND}

  if tw2916_x<>4 then
    writeln('ERROR!');
end;
{$pop}

{ Case tw30035.pp }
{$push}

begin
  tw30035_qa := 2147483648;
  tw30035_qb := 536870912;
{$R-}{$Q-}
  tw30035_i64 := int64(tw30035_qa) * int64(tw30035_qb);
  if tw30035_i64 <> 1152921504606846976 then
  begin
    Writeln('Error!');
    Halt(1);
  end;
end;
{$pop}

{ Case tw30035a.pp }
{$push}

begin
  tw30035a_qa := 2147483648;
  tw30035a_qb := 536870912;
{$R+}{$Q+}
  tw30035a_i64 := int64(tw30035a_qa) * int64(tw30035a_qb);
  if tw30035a_i64 <> 1152921504606846976 then
  begin
    Writeln('Error!');
    Halt(1);
  end;
end;
{$pop}

{ Case tw34385a.pp }
{$push}
{$r+}
begin
  if (tw34385a_w<=1) and (tw34385a_w>=10) then
    halt(1);

  if (tw34385a_w>=1) and (tw34385a_w<=1000) then
  else
    halt(2);

  if (tw34385a_n>44)and(tw34385a_n<48) then
    halt(3);

  if (tw34385a_m>=-4) and (tw34385a_m<=$7ffffffe) then
    halt(4);

  if (tw34385a_m>=-5) and (tw34385a_m<=$7ffffffe) then
  else
    halt(5);

  if (tw34385a_m>=-$7fffffff) and (tw34385a_m<=$7ffffffe) then
  else
    halt(6);

  if (tw34385a_k>=-$7fffffff) and (tw34385a_k<=$7ffffffe) then
    halt(7);
end;
{$pop}

{ Case tw35878a.pp }
{$push}

begin
  tw35878a_rand:=-5;
  tw35878a_i:=1;
  while tw35878a_i<=10000 do
    begin
      tw35878a_val:=random(tw35878a_rand);
      if (tw35878a_val<-5) or (tw35878a_val>0) then
        begin
          writeln('error: ', tw35878a_val);
          halt(1);
        end;
      Inc(tw35878a_i);
    end;
end;
{$pop}

{ Case tw36587.pp }
{$push}
{$R-}
{$Q-}
{$ifdef CPUINT64}
{$else CPUINT64}
{$endif CPUINT64}
begin
  tw36587_dotest(1000000);
  writeln('OK.');
end;
{$pop}

{ Case tw36589.pp }
{$push}

begin
     for tw36589_k:=1 downto 10 do
     begin
     end;
end;
{$pop}

{ Case tw37427.pp }
{$push}
{$Q+}
begin
end;
{$pop}

{ Case tw39615a.pp }
{$push}
{$ifdef unsigned}
{$else}
{$endif}
begin
	tw39615a_ok := true;
	for tw39615a_i := {$ifdef unsigned} 0 {$else} -2 * tw39615a_TestRange {$endif} to 2 * tw39615a_TestRange do
	begin
	{$ifndef unsigned}
		if tw39615a_i < -tw39615a_TestRange then
			tw39615a_x := Low(tw39615a_x) + (tw39615a_i - (-2 * tw39615a_TestRange)) // test [Low(x); Low(x) + TestRange)
		else
	{$endif}
		if tw39615a_i <= tw39615a_TestRange then tw39615a_x := tw39615a_i            // test [-TestRange; TestRange] or [0; TestRange]
		else tw39615a_x := High(tw39615a_x) - (tw39615a_i - tw39615a_TestRange - 1); // test (High(x) - TestRange; High(x)]

		tw39615a_r1 := tw39615a_x - tw39615a_x mod tw39615a_Divisor;
		tw39615a_r2 := tw39615a_x div tw39615a_Divisor * tw39615a_Divisor;

		if tw39615a_r1 <> tw39615a_r2 then
		begin
			writeln('FAIL: x=', tw39615a_x, ', x - x mod ', tw39615a_Divisor, ' = ', tw39615a_r1, ', x div ', tw39615a_Divisor, ' * ', tw39615a_Divisor, ' = ', tw39615a_r2);
			tw39615a_ok := false;
		end;
	end;
	if tw39615a_ok then
	  writeln('ok')
	else
	  halt(1);
end;
{$pop}

{ Case tw3967.pp }
{$push}

begin
  tw3967_s:=1; tw3967_p:=1;
  for tw3967_i:=3 downto 1 do begin
    if tw3967_s*(tw3967_i+2) mod tw3967_i=0 then tw3967_s:=tw3967_s*(tw3967_i+2) div tw3967_i else begin
      tw3967_s:=tw3967_s*(tw3967_i+2);
      tw3967_p:=tw3967_p*tw3967_i;
      {The error is here!If we swap the variable i and the variable p then the value of the variable p is right}
      {But now the value of the variable p is zero,you see,the value of the variable p must be 3}
      {The compiler was 1.98}
      if tw3967_p<>3 then
        halt(1);
    end
  end;
  if tw3967_p<>3 then
    halt(1);
  writeln('ok');
end;
{$pop}

{ Case tw4055.pp }
{$push}
{$WRITEABLECONST OFF}
begin
  tw4055_TestBuf(tw4055_A, 1);
end;
{$pop}

{ Case tw4058.pp }
{$push}
{$q+}
begin
	tw4058_i := 52000;
	tw4058_j1 := 1440 - round (tw4058_i/60);
	tw4058_j2 := -round (tw4058_i/60) + 1440;
        if (tw4058_j1 <> tw4058_j2) then
          halt(1);
end;
{$pop}

{ Case tw4152.pp }
{$push}
{$ifdef cpu64}
{$else}
{$endif}
begin
  tw4152_v:=100;
{$ifdef cpu32}
  { this gets translated into "v:=v+(-1)", and the compiler would require 128bit
    arithmetic to calculate this when v is a qword and range checking is on }
  inc(tw4152_v,-1);
{$endif cpu32}
  tw4152_p:=@tw4152_c;
  Inc(tw4152_p,-1);  // Gives compile time error: range check error while evaluating constants
  tw4152_d:=2;
  Inc(tw4152_d,-1);
  Inc(tw4152_p,tw4152_d); // This fails at run time
end;
{$pop}

{ Case tw4253.pp }
{$push}

begin
    tw4253_count := -1 ;
    writeln ( tw4253_count ) ;  // gives -1
    tw4253_long := 1 ;
    tw4253_count := -tw4253_long ;
    writeln ( tw4253_count ) ;  // gives 4294967295
   end;
{$pop}

{ Case tw4308.pp }
{$push}

begin
end;
{$pop}

{ Case tw4428.pp }
{$push}

begin
  tw4428_p(1,2,3,4,5,6,7,8,11111111111)
end;
{$pop}

{ Case tw4537.pp }
{$push}

begin
end;
{$pop}

{ Case tw4881.pp }
{$push}

begin
  tw4881_test(tw4881_x);
end;
{$pop}

{ Case tw6684.pp }
{$push}

Begin
  tw6684_D := -100;
  {$OVERFLOWCHECKS on}
  Writeln(2 * tw6684_D);
  tw6684_d1:=tw6684_d*2;
  {$OVERFLOWCHECKS off}
  Writeln(2 * tw6684_D);
  tw6684_d2:=tw6684_d*2;
  if tw6684_d1<>-200 then
    halt(1);
  if tw6684_d2<>-200 then
    halt(1);
  writeln('ok');
End;
{$pop}

{ Case tw6742.pp }
{$push}

begin
  tw6742_x:=1;
  tw6742_test(tw6742_x);
end;
{$pop}

{ Case tw8870.pp }
{$push}
{$q+}
{$r+}
begin
   tw8870_a := $80000000;
   tw8870_one := 1;
   tw8870_b := tw8870_a div tw8870_one;
   WriteLn(tw8870_b);
end;
{$pop}

{ Case tw8883.pp }
{$push}

begin
  tw8883_dotest;
end;
{$pop}

{ Case tw9108.pp }
{$push}

begin
  if tw9108_Func(100) <> 100 then
    halt(1);
end;
{$pop}

end.
