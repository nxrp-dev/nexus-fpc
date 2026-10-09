{ Records regression cases; original case IDs are retained below. }

{ Case tw15357.pp }
{$push}
type
  tw15357_ttype = packed record
    tw15357_a: byte;
    tw15357_b: byte;
    tw15357_c: longword;
  end;

  tw15357_ttypecontainer = packed record
    tw15357_r: tw15357_ttype;
    tw15357_b1,tw15357_b2: byte;
  end;

function tw15357_make: tw15357_ttype;
begin
  tw15357_make.tw15357_a:=1;
  tw15357_make.tw15357_b:=2;
  tw15357_make.tw15357_c:=$12345678;
end;

var
  tw15357_id: tw15357_ttypecontainer;
{$pop}

{ Case tw1850.pp }
{$push}
{ Source provided for Free Pascal Bug Report 1850 }
{ Submitted by "Sebastian Günther" on  2002-03-06 }
{ e-mail: sg@freepascal.org }
type
  tw1850_tmyrecord = record
    tw1850_a, tw1850_b: Integer;
  end;
var
  tw1850_r: tw1850_tmyrecord;
{$pop}

{ Case tw1915.pp }
{$push}
{
    This program demonstrates a set inclusion test bug.
    (After two days passed to track down a very perverse program error....)
    (By Louis Jean-Ruichard)
}
TYPE
    tw1915_eattr   = ( e0, e1, e2, e3, e4, e5, e6, e7 );
    tw1915_entityp = ^tw1915_entity;
    tw1915_entity  =
            RECORD
                tw1915_attr    : SET OF tw1915_eattr;
            END;
VAR
    tw1915_ep  : tw1915_entityp;
    tw1915_e   : tw1915_entity;
{$pop}

{ Case tw2758.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2758 }
{ Submitted by "marco" on  2003-10-31 }
{ e-mail:  }
Type
  tw2758_sigcontextrec=record end;
  tw2758_signalhandler   = Procedure(Sig : Longint);cdecl;
  tw2758_psignalhandler  = ^tw2758_signalhandler;
  tw2758_tsigaction = procedure(Sig: Longint; tw2758_sigcontext: tw2758_sigcontextrec);cdecl;

tw2758_sigactionrec = packed record  // this is temporary for the migration
    tw2758_sa_handler : tw2758_signalhandler;
  end;

procedure tw2758_signaltorunerror(Sig: Longint; tw2758_sigcontext: tw2758_sigcontextrec);cdecl;
begin end;  // tsigaction style

var tw2758_r : tw2758_sigactionrec;
{$pop}

{ Case tw27634.pp }
{$push}
type
  tw27634_mbhelpptr = pointer;
  tw27634_menurecord = record end;
  tw27634_menuitemsptr = pointer;
  tw27634_menuiconhandle = pointer;
  tw27634_menuref = pointer;
  tw27634_int16 = word;
  tw27634_int32 = longint;
  tw27634_osstatus = tw27634_int32;
  tw27634_str255 = ShortString;

 function tw27634_macmenuadditeminternal
        ( var tw27634_themenurecord           : tw27634_menurecord;
              tw27634_themenuorsubmenuid      : tw27634_int32;
              tw27634_theoptbeforeitemindex   : tw27634_int32;
          var tw27634_themenuref              : tw27634_menuref;
          var tw27634_theitemsptr             : tw27634_menuitemsptr;
        const tw27634_theitemstr              : tw27634_str255;
              tw27634_theitemiconhandle       : tw27634_menuiconhandle;
              tw27634_theenableflag           : boolean;
              tw27634_thecheckflag            : boolean;
              tw27634_thecommandchar          : char;
              tw27634_thecommandmodifiers     : tw27634_int16;
              tw27634_theitemcmdid            : tw27634_int32;
        const tw27634_theitemappstr           : AnsiString;
          var tw27634_thenewitemindex         : tw27634_int32): tw27634_osstatus;
begin
end;

 function tw27634_mbmenuadditeminternal
        ( var tw27634_themenurecord           : tw27634_menurecord;
              tw27634_themenuorsubmenuid      : tw27634_int32;
              tw27634_theoptbeforeitemindex   : tw27634_int32;
          var tw27634_themenuref              : tw27634_menuref;
          var tw27634_theitemsptr             : tw27634_menuitemsptr;
        const tw27634_theitemstr              : tw27634_str255;
              tw27634_theitemiconhandle       : tw27634_menuiconhandle;
              tw27634_theenableflag           : boolean;
              tw27634_thecheckflag            : boolean;
              tw27634_thecommandchar          : char;
              tw27634_thecommandglyph         : tw27634_int16; { unused here }
              tw27634_thecommandmodifiers     : tw27634_int16;
              tw27634_theitemcmdid            : tw27634_int32;
        const tw27634_theitemappstr           : AnsiString;
              tw27634_theitemhelpptr          : tw27634_mbhelpptr; { unused here }
          var tw27634_thenewitemindex         : tw27634_int32): tw27634_osstatus;
      var
        tw27634_theerr                        : tw27634_osstatus;
    begin
      tw27634_theitemsptr                     := nil;
      tw27634_thenewitemindex                 := 0;
      tw27634_theerr                          := tw27634_macmenuadditeminternal
        ( tw27634_themenurecord, tw27634_themenuorsubmenuid, tw27634_theoptbeforeitemindex, tw27634_themenuref, tw27634_theitemsptr,
          tw27634_theitemstr, tw27634_theitemiconhandle, tw27634_theenableflag, tw27634_thecheckflag, tw27634_thecommandchar,
          tw27634_thecommandmodifiers, tw27634_theitemcmdid, tw27634_theitemappstr, tw27634_thenewitemindex);
      tw27634_mbmenuadditeminternal           := tw27634_theerr
    end;

var
  tw27634_themenurecord: tw27634_menurecord;
  tw27634_themenuref: tw27634_menuref;
  tw27634_theitemsptr: tw27634_menuitemsptr;
  tw27634_thenewitemindex: tw27634_int32;
{$pop}

{ Case tw28007.pp }
{$push}
type

  tw28007_tpackedbool = bitpacked record
    tw28007_b0: Boolean;
    tw28007_b1: Boolean;
    tw28007_b2: Boolean;
    tw28007_b3: Boolean;
    tw28007_b4: Boolean;
    tw28007_b5: Boolean;
    tw28007_b6: Boolean;
    tw28007_b7: Boolean;
  end;

var
  tw28007_b: ByteBool;
  tw28007_packedbool: tw28007_tpackedbool;
{$pop}

{ Case tw28927.pp }
{$push}
type
  tw28927_trecord1 = record
  end align 16;

  tw28927_trecord2 = record
  end align 8;

  tw28927_trecord3 = record
  end align 4;

  tw28927_trecord1outer = record
    tw28927_b : Byte;
    tw28927_record1 : tw28927_trecord1;
  end;

  tw28927_trecord2outer = record
    tw28927_b : Byte;
    tw28927_record2 : tw28927_trecord2;
  end;

  tw28927_trecord3outer = record
    tw28927_b : Byte;
    tw28927_record3 : tw28927_trecord3;
  end;

var
  tw28927_record1outer : tw28927_trecord1outer;
  tw28927_record2outer : tw28927_trecord2outer;
  tw28927_record3outer : tw28927_trecord3outer;
{$pop}

{ Case tw2976.pp }
{$push}
{ Source provided for Free Pascal Bug Report 2976 }
{ Submitted by "Soeren Haastrup" on  2004-02-17 }
{ e-mail: haastrupsoeren@hotmail.com }
Type tw2976_vector=array[1..2] of double;

     tw2976_pair=record
           tw2976_v1:double;
           tw2976_v2:tw2976_vector;
          end;

operator := (tw2976_x:shortint) r:tw2976_pair;
var tw2976_i:longint;
Begin
    r.tw2976_v1:=tw2976_x;
    for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=0;
End;

operator := (tw2976_x:double) r:tw2976_pair;
var tw2976_i:longint;
Begin
    r.tw2976_v1:=tw2976_x;
    for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=0;
End;

{
operator + (x:double;p:pair) r:pair; // Marked
var i:longint;
Begin
 r.v1:=x+p.v1;
 for i:=1 to 2 do r.v2[i]:=p.v2[i];
End;
}

operator + (p:tw2976_pair;tw2976_x:double) r:tw2976_pair;
var tw2976_i:longint;
Begin
 r.tw2976_v1:=p.tw2976_v1+tw2976_x;
 for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=p.tw2976_v2[tw2976_i];
End;

operator + (p1,p2:tw2976_pair) r:tw2976_pair;
var tw2976_i:longint;
Begin
 r.tw2976_v1:=p1.tw2976_v1+p2.tw2976_v1;
 for tw2976_i:=1 to 2 do r.tw2976_v2[tw2976_i]:=p1.tw2976_v2[tw2976_i]+p2.tw2976_v2[tw2976_i];
End;

var tw2976_a,tw2976_b:tw2976_pair;
{$pop}

{ Case tw30208.pp }
{$push}
var tw30208_r: bitpacked record
    tw30208_a, tw30208_b: boolean;
    end;
{$pop}

{ Case tw30240.pp }
{$push}
type
  tw30240_ttestcase = record
    tw30240_group: char;
    tw30240_dividend, tw30240_divider: int64;   // source
    tw30240_quotient, tw30240_remainder: int64; // expected result
  end;

const
  tw30240_test_cases: array [0..40] of tw30240_ttestcase =(
    // #30240
    ( tw30240_group:'-'; tw30240_dividend: 2000000000000; tw30240_divider: 2000000000001; tw30240_quotient: 0; tw30240_remainder: 2000000000000 ),
    //.Lbig_divisor (with carry at the end)
    ( tw30240_group:'a'; tw30240_dividend: 8375316585208858139; tw30240_divider:-7333902439715991;    tw30240_quotient:-1141;      tw30240_remainder: 7333901492912408 ),
    ( tw30240_group:'a'; tw30240_dividend: 7056323922322693051; tw30240_divider:-2740063521509;       tw30240_quotient:-2575240;   tw30240_remainder: 2739191855891 ),
    ( tw30240_group:'a'; tw30240_dividend: 8271196811549967915; tw30240_divider: 25285028838;         tw30240_quotient: 327118345; tw30240_remainder: 24786134805 ),
    ( tw30240_group:'a'; tw30240_dividend: 3431221233848454052; tw30240_divider:-3431221234088342633; tw30240_quotient: 0;         tw30240_remainder: 3431221233848454052 ),
    ( tw30240_group:'a'; tw30240_dividend:-8585295120939781742; tw30240_divider:-23751612046;         tw30240_quotient: 361461575; tw30240_remainder:-22003649292 ),
    ( tw30240_group:'a'; tw30240_dividend:-6683243686137656212; tw30240_divider: 40354827467772;      tw30240_quotient:-165611;    tw30240_remainder:-40354372467520 ),
    ( tw30240_group:'a'; tw30240_dividend:-6963003432881308676; tw30240_divider:-1740750858595018939; tw30240_quotient: 3;         tw30240_remainder:-1740750857096251859 ),
    ( tw30240_group:'a'; tw30240_dividend: 3589102502730131736; tw30240_divider: 2718092484398;       tw30240_quotient: 1320448;   tw30240_remainder: 2717891761432 ),
    ( tw30240_group:'a'; tw30240_dividend:-9069664486668623813; tw30240_divider:-177626955280;        tw30240_quotient: 51060180;  tw30240_remainder:-177219873413 ),
    ( tw30240_group:'a'; tw30240_dividend:-8708789282907437996; tw30240_divider:-280928686587236007;  tw30240_quotient: 30;        tw30240_remainder:-280928685290357786 ),
    //.Lbig_divisor (without carry)
    ( tw30240_group:'b'; tw30240_dividend:-5478163896315828857; tw30240_divider:-9281215814;          tw30240_quotient: 590242055; tw30240_remainder:-1361971087 ),
    ( tw30240_group:'b'; tw30240_dividend: 7101201960831283575; tw30240_divider: 9474016311;          tw30240_quotient: 749545042; tw30240_remainder: 7094103513 ),
    ( tw30240_group:'b'; tw30240_dividend: 3960011864586540874; tw30240_divider:-2123266079007095486; tw30240_quotient:-1;         tw30240_remainder: 1836745785579445388 ),
    ( tw30240_group:'b'; tw30240_dividend: 6707823169352057382; tw30240_divider:-7764081918;          tw30240_quotient:-863955743; tw30240_remainder: 7173502308 ),
    ( tw30240_group:'b'; tw30240_dividend: 5698168712416449358; tw30240_divider: 4542747269964;       tw30240_quotient: 1254344;   tw30240_remainder: 930820725742 ),
    ( tw30240_group:'b'; tw30240_dividend: 3759351913822964708; tw30240_divider:-56344208198167;      tw30240_quotient:-66721;     tw30240_remainder: 9998633064301 ),
    ( tw30240_group:'b'; tw30240_dividend:-7764588773457981677; tw30240_divider: 27146308080993374;   tw30240_quotient:-286;       tw30240_remainder:-744662293876713 ),
    ( tw30240_group:'b'; tw30240_dividend:-5098584499810065147; tw30240_divider:-1033450244405508;    tw30240_quotient: 4933;      tw30240_remainder:-574444157694183 ),
    ( tw30240_group:'b'; tw30240_dividend: 7767592121360637078; tw30240_divider:-2706907408679000905; tw30240_quotient:-2;         tw30240_remainder: 2353777304002635268 ),
    ( tw30240_group:'b'; tw30240_dividend: 3900260326859439920; tw30240_divider:-4529352981664096387; tw30240_quotient: 0;         tw30240_remainder: 3900260326859439920 ),
    //.Ltwo_divs
    ( tw30240_group:'c'; tw30240_dividend:-3189721586398362144; tw30240_divider:-477575983;  tw30240_quotient: 6678982402;    tw30240_remainder:-323510978 ),
    ( tw30240_group:'c'; tw30240_dividend:-6272627659376899240; tw30240_divider:-365611917;  tw30240_quotient: 17156518613;   tw30240_remainder:-231788119 ),
    ( tw30240_group:'c'; tw30240_dividend: 8347107135342446860; tw30240_divider: 1114829022; tw30240_quotient: 7487342875;    tw30240_remainder: 627528610 ),
    ( tw30240_group:'c'; tw30240_dividend: 7002068931434460610; tw30240_divider: 404820846;  tw30240_quotient: 17296710385;   tw30240_remainder: 361774900 ),
    ( tw30240_group:'c'; tw30240_dividend: 8293431318282107842; tw30240_divider:-718398042;  tw30240_quotient:-11544340092;   tw30240_remainder: 7207978 ),
    ( tw30240_group:'c'; tw30240_dividend:-6808260689000200821; tw30240_divider:-1501534265; tw30240_quotient: 4534202680;    tw30240_remainder:-525370621 ),
    ( tw30240_group:'c'; tw30240_dividend: 7674745939185655069; tw30240_divider:-1699384892; tw30240_quotient:-4516190520;    tw30240_remainder: 104031229 ),
    ( tw30240_group:'c'; tw30240_dividend: 6431190513421618316; tw30240_divider: 3333080;    tw30240_quotient: 1929503796315; tw30240_remainder: 18116 ),
    ( tw30240_group:'c'; tw30240_dividend: 2124140687535160173; tw30240_divider: 37711397;   tw30240_quotient: 56326226459;   tw30240_remainder: 27906950 ),
    ( tw30240_group:'c'; tw30240_dividend:-3811970536696094994; tw30240_divider:-43355849;   tw30240_quotient: 87922866801;   tw30240_remainder:-24825945 ),
    // one division
    ( tw30240_group:'d'; tw30240_dividend:-569298819287740717;  tw30240_divider: 623930358;  tw30240_quotient:-912439684;  tw30240_remainder:-596213845 ),
    ( tw30240_group:'d'; tw30240_dividend: 990400595808799715;  tw30240_divider:-1625588531; tw30240_quotient:-609256633;  tw30240_remainder: 768323592 ),
    ( tw30240_group:'d'; tw30240_dividend:-580252789917085737;  tw30240_divider:-354226044;  tw30240_quotient: 1638086187; tw30240_remainder:-165031509 ),
    ( tw30240_group:'d'; tw30240_dividend: 1933675428811294466; tw30240_divider: 1189844258; tw30240_quotient: 1625150027; tw30240_remainder: 796799500 ),
    ( tw30240_group:'d'; tw30240_dividend: 548675153951135484;  tw30240_divider:-335038546;  tw30240_quotient:-1637647848; tw30240_remainder: 97186476 ),
    ( tw30240_group:'d'; tw30240_dividend:-844891682720642266;  tw30240_divider: 1058118666; tw30240_quotient:-798484810;  tw30240_remainder:-742178806 ),
    ( tw30240_group:'d'; tw30240_dividend:-759434744728515761;  tw30240_divider:-733407613;  tw30240_quotient: 1035487948; tw30240_remainder:-495567637 ),
    ( tw30240_group:'d'; tw30240_dividend: 13655828961120164;   tw30240_divider: 15582697;   tw30240_quotient: 876345664;  tw30240_remainder: 11744356 ),
    ( tw30240_group:'d'; tw30240_dividend: 14609195521567996;   tw30240_divider:-38440672;   tw30240_quotient:-380045268;  tw30240_remainder: 29227900 ),
    ( tw30240_group:'d'; tw30240_dividend:-402022804788005296;  tw30240_divider:-254071284;  tw30240_quotient: 1582322875; tw30240_remainder:-234183796 )
  );

var
  tw30240_i, tw30240_errors: integer;
  tw30240_vq, tw30240_vr: int64;
{$pop}

{ Case tw3064.pp }
{$push}
type
  tw3064_r1 = packed record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

  tw3064_r2 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

 {$a-}
  tw3064_r3 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;

 {$a+}
  tw3064_r4 = record
    tw3064_b : byte;
    tw3064_l : longint;
  end;
{$pop}

{ Case tw32811.pp }
{$push}
type
  tw32811_pnode = ^tw32811_node;
  tw32811_node = record
    tw32811_i: integer;
    tw32811_left: tw32811_pnode;
    tw32811_right: tw32811_pnode;
  end;

procedure tw32811_insert(var t: tw32811_pnode; tw32811_i: integer);
begin
  if t = nil then
    begin
      new(t);
      t^.tw32811_i := tw32811_i;
      t^.tw32811_left := nil;
      t^.tw32811_right := nil;
    end
  else
    if tw32811_i < t^.tw32811_i
      then tw32811_insert(t^.tw32811_left, tw32811_i)
      else tw32811_insert(t^.tw32811_right, tw32811_i);
end;
{$pop}

begin
  { Case tw15357.pp }
  {$push}

  begin
tw15357_id.tw15357_b1:=123;
  tw15357_id.tw15357_b2:=234;
  tw15357_id.tw15357_r := tw15357_make();
  if tw15357_id.tw15357_r.tw15357_a<>1 then
    halt(1);
  if tw15357_id.tw15357_r.tw15357_b<>2 then
    halt(2);
  if tw15357_id.tw15357_r.tw15357_c<>$12345678 then
    halt(3);
  if tw15357_id.tw15357_b1<>123 then
    halt(4);
  if tw15357_id.tw15357_b2<>234 then
    halt(5);
  end;
  {$pop}

  { Case tw1850.pp }
  {$push}

  begin
with tw1850_r do;
  end;
  {$pop}

  { Case tw1915.pp }
  {$push}

  begin
tw1915_e.tw1915_attr:=[e2,e4,e7,e1,e0];
    WITH tw1915_e DO
            IF ([e1,e0] <= tw1915_attr)
            THEN Writeln('A1: [e1,e0] is included in attr')
    ;
    New(tw1915_ep);
    tw1915_ep^.tw1915_attr:=[e2,e4,e7,e1,e0];
    WITH tw1915_ep^ DO
            IF ([e1,e0] <= tw1915_attr)
            THEN Writeln('A2: [e1,e0] is included in attr')
            ELSE
             begin
              Writeln('A2 statement incorrectly executed');
              Halt(1);
             end;
    ;
  end;
  {$pop}

  { Case tw2758.pp }
  {$push}

  begin
tw2758_r.tw2758_sa_handler:=tw2758_signalhandler(@tw2758_signaltorunerror);
  end;
  {$pop}

  { Case tw27634.pp }
  {$push}

  begin
tw27634_mbmenuadditeminternal(tw27634_themenurecord,1,2,tw27634_themenuref,tw27634_theitemsptr,'abc',nil,true,false,'b',3,4,5,'def',nil,tw27634_thenewitemindex);
  end;
  {$pop}

  { Case tw28007.pp }
  {$push}

  begin
(*
    - OK on x86, x86_64 compiler
    - ERROR on cross arm compiler
    - OK on cross arm compiler if we do typecast:
        B := ByteBool(PackedBool.b0);
                                                    *)

  tw28007_b := tw28007_packedbool.tw28007_b0;
  end;
  {$pop}

  { Case tw28927.pp }
  {$push}

  begin
if PtrUInt(@tw28927_record1outer.tw28927_record1) mod 16<>0 then
    halt(1);
  if PtrUInt(@tw28927_record2outer.tw28927_record2) mod 8<>0 then
    halt(2);
  if PtrUInt(@tw28927_record3outer.tw28927_record3) mod 4<>0 then
    halt(3);
  writeln('ok');
  end;
  {$pop}

  { Case tw2976.pp }
  {$push}

  begin
//main

tw2976_a:=2;            //ok
tw2976_b:=tw2976_a+tw2976_a;          //ok
tw2976_a:=2+tw2976_b;          // ups?
  end;
  {$pop}

  { Case tw30208.pp }
  {$push}

  begin
tw30208_r.tw30208_a := true;
    tw30208_r.tw30208_b := false;
    if not tw30208_r.tw30208_b then
      writeln('ok')
    else
      halt(1);
  end;
  {$pop}

  { Case tw30240.pp }
  {$push}

  begin
tw30240_errors := 0;
  for tw30240_i := low(tw30240_test_cases) to high(tw30240_test_cases) do
    begin
      tw30240_vq := tw30240_test_cases[tw30240_i].tw30240_dividend div tw30240_test_cases[tw30240_i].tw30240_divider;
      tw30240_vr := tw30240_test_cases[tw30240_i].tw30240_dividend mod tw30240_test_cases[tw30240_i].tw30240_divider;
      if tw30240_vq*tw30240_test_cases[tw30240_i].tw30240_divider+tw30240_vr=tw30240_test_cases[tw30240_i].tw30240_dividend then
        if tw30240_vq=tw30240_test_cases[tw30240_i].tw30240_quotient then
          if tw30240_vr=tw30240_test_cases[tw30240_i].tw30240_remainder then
            continue;
      inc(tw30240_errors);
      writeln('Error [',tw30240_test_cases[tw30240_i].tw30240_group,']: ',tw30240_test_cases[tw30240_i].tw30240_dividend,'/',tw30240_test_cases[tw30240_i].tw30240_divider);
      writeln('  q=',tw30240_vq,' r=',tw30240_vr);
      writeln('  expected q=',tw30240_test_cases[tw30240_i].tw30240_quotient,' r=',tw30240_test_cases[tw30240_i].tw30240_remainder);
    end;
  if tw30240_errors=0 then
    writeln('Pass')
  else
    begin
      writeln('Fail (',tw30240_errors,' errors)');
      halt(1);
    end;
  end;
  {$pop}

  { Case tw3064.pp }
  {$push}
{$a-}
{$a+}
  begin
if (sizeof(tw3064_r1)<>sizeof(tw3064_r3)) or (sizeof(tw3064_r2)<>sizeof(tw3064_r4)) then
    halt(1);
  writeln('ok');
  end;
  {$pop}

end.
